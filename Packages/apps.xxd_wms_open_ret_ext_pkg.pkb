--
-- XXD_WMS_OPEN_RET_EXT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_OPEN_RET_EXT_PKG"
AS
    --  #########################################################################################
    --  Package      : XXD_WMS_OPEN_RET_EXT_PKG
    --  Design       : This package provides Text extract for Open Retail Returns Extract to BL
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                          Comments
    --  ======================================================================================
    --  09-JUN-2021     1.0        Aravind Kannuri               CCR0009315
    --  #########################################################################################

    gn_user_id            CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id           CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id             CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id            CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id       CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id         CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_conc_program_id    CONSTANT NUMBER := fnd_global.conc_program_id;
    gd_date               CONSTANT DATE := SYSDATE;

    g_pkg_name            CONSTANT VARCHAR2 (30) := 'XXD_WMS_OPEN_RET_EXT_PKG';
    g_log_level           CONSTANT NUMBER := FND_LOG.G_CURRENT_RUNTIME_LEVEL;
    gv_delimeter                   VARCHAR2 (1) := '|';

    g_gl_application_id   CONSTANT NUMBER := 101;
    g_po_application_id   CONSTANT NUMBER := 201;

    PROCEDURE print_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, lv_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print log:' || SQLERRM);
    END print_log;


    PROCEDURE write_orr_recon_file (p_file_path IN VARCHAR2, p_file_name IN VARCHAR2, x_ret_code OUT VARCHAR2
                                    , x_ret_message OUT VARCHAR2)
    IS
        CURSOR orr_reconcilation IS
              SELECT (entity_uniq_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (period_end_date, 'MM/DD/RRRR') || CHR (9) || Subledr_Rep_Bal || CHR (9) || subledr_alt_bal || CHR (9) || SUM (subledr_acc_bal)) line
                FROM xxdo.xxd_wms_open_ret_ext_t
               WHERE 1 = 1 AND request_id = gn_request_id
            GROUP BY entity_uniq_identifier, account_number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledr_rep_bal,
                     subledr_alt_bal;

        --DEFINE VARIABLES
        lv_file_path              VARCHAR2 (360);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        l_line                    VARCHAR2 (4000);
    BEGIN
        FOR i IN orr_reconcilation
        LOOP
            l_line   := i.line;
            fnd_file.put_line (fnd_file.output, l_line);
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
                       AND ffvl.description = 'OPENRETAIL'
                       AND ffvl.flex_value = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

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

                    lv_file_path   := lv_vs_default_file_path;
                END IF;


                -- WRITE INTO BL FOLDER
                lv_outbound_file   :=
                       lv_vs_file_name
                    || '_'
                    || gn_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';

                fnd_file.put_line (fnd_file.LOG,
                                   'BL File Name is - ' || lv_outbound_file);

                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                       ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN orr_reconcilation
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the Account Balance data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_orr_recon_file;

    --For Parameter Additional Report 'YES'
    PROCEDURE write_orr_recon_link_file (p_file_path         IN     VARCHAR2,
                                         p_file_name         IN     VARCHAR2,
                                         p_period_end_date   IN     VARCHAR2,
                                         x_ret_code             OUT VARCHAR2,
                                         x_ret_message          OUT VARCHAR2)
    IS
        CURSOR orr_reconcilation (p_bl_link           IN VARCHAR2,
                                  p_period_end_date   IN VARCHAR2)
        IS
              SELECT (entity_uniq_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (period_end_date, 'MM/DD/RRRR') || CHR (9) || Subledr_Rep_Bal || CHR (9) || subledr_alt_bal || CHR (9) || SUM (subledr_acc_bal)) line
                FROM xxdo.xxd_gl_bl_report_link_ext_t
               WHERE     1 = 1
                     AND period_end_date = p_period_end_date
                     AND bl_link = p_bl_link
            GROUP BY entity_uniq_identifier, account_number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledr_rep_bal,
                     subledr_alt_bal;

        --DEFINE VARIABLES
        lv_file_path              VARCHAR2 (360);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        l_line                    VARCHAR2 (4000);
        lv_last_date              VARCHAR2 (50);
        lv_bl_link                VARCHAR2 (50);
        lv_prog_name              VARCHAR2 (150);
    BEGIN
        -- Period end date of the as of date
        SELECT LAST_DAY (TO_DATE (p_period_end_date, 'RRRR/MM/DD HH24:MI:SS'))
          INTO lv_last_date
          FROM DUAL;

        --To fetch BL Report Link
        BEGIN
            SELECT ffvl.flex_value, ffvl.description
              INTO lv_prog_name, lv_bl_link
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'XXD_GL_BL_REPORT_LINK'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.flex_value =
                       'Deckers Open Retail Returns Extract to BL';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_prog_name   := NULL;
                lv_bl_link     := NULL;
        END;

        FOR i IN orr_reconcilation (lv_bl_link, lv_last_date)
        LOOP
            l_line   := i.line;
            fnd_file.put_line (fnd_file.output, l_line);
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
                       AND ffvl.description = 'OPENRETAIL'
                       AND ffvl.flex_value = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

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

                    lv_file_path   := lv_vs_default_file_path;
                END IF;


                -- WRITE INTO BL FOLDER
                lv_outbound_file   :=
                       lv_vs_file_name
                    || '_'
                    || gn_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';

                fnd_file.put_line (fnd_file.LOG,
                                   'BL File Name is - ' || lv_outbound_file);

                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                       ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN orr_reconcilation (lv_bl_link, lv_last_date)
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the Account Balance data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_orr_recon_link_file;

    PROCEDURE write_op_file (p_file_path         IN     VARCHAR2,
                             p_file_name         IN     VARCHAR2,
                             p_period_end_date   IN     VARCHAR2,
                             p_org_id            IN     NUMBER,
                             x_ret_code             OUT VARCHAR2,
                             x_ret_message          OUT VARCHAR2)
    IS
        CURSOR op_file_orr IS
              SELECT line
                FROM (SELECT 1 AS seq, ra_nbr || gv_delimeter || store_location || gv_delimeter || created || gv_delimeter || style || gv_delimeter || color_code || gv_delimeter || size_code || gv_delimeter || original_quantity || gv_delimeter || received_quantity || gv_delimeter || cancelled_quantity || gv_delimeter || open_quantity || gv_delimeter || extd_price || gv_delimeter || currency || gv_delimeter || warehouse || gv_delimeter || brand line
                        FROM xxdo.xxd_wms_open_ret_ext_t
                       WHERE 1 = 1 AND request_id = gn_request_id
                      UNION
                      SELECT 2 AS seq, 'Ra_Nbr' || gv_delimeter || 'Store_Location' || gv_delimeter || 'Created' || gv_delimeter || 'Style' || gv_delimeter || 'Color_Code' || gv_delimeter || 'Size_Code' || gv_delimeter || 'Original_Quantity' || gv_delimeter || 'Received_Quantity' || gv_delimeter || 'Cancelled_Quantity' || gv_delimeter || 'Open_Quantity' || gv_delimeter || 'Extd_Price' || gv_delimeter || 'Currency' || gv_delimeter || 'Warehouse' || gv_delimeter || 'Brand'
                        FROM DUAL)
            ORDER BY 1 DESC;


        --DEFINE VARIABLES
        lv_file_path              VARCHAR2 (360);           -- := p_file_path;
        lv_file_name              VARCHAR2 (360);
        lv_file_dir               VARCHAR2 (1000);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);           -- := p_file_name;
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        lv_ou_short_name          VARCHAR2 (100);
        lv_period_name            VARCHAR2 (50);
    BEGIN
        -- WRITE INTO BL FOLDER

        IF p_file_path IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1, ffvl.attribute3
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
                       AND ffvl.description = 'OPENRETAIL'
                       AND ffvl.flex_value = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;


            IF p_period_end_date IS NULL
            THEN
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND TRUNC (SYSDATE) BETWEEN start_date
                                                   AND end_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_period_name   := NULL;
                END;
            ELSE
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_CY_CALENDAR'
                           AND TO_DATE (p_period_end_date,
                                        'YYYY/MM/DD HH24:MI:SS') BETWEEN start_date
                                                                     AND end_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_period_name   := NULL;
                END;
            END IF;



            IF     lv_vs_file_path IS NOT NULL
               AND NVL (lv_vs_file_path, 'X') <> 'NA'
               AND lv_vs_file_name IS NOT NULL
            THEN
                BEGIN
                    SELECT ffvl.attribute2
                      INTO lv_ou_short_name
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_GL_AAR_OU_SHORTNAME_VS'
                           AND NVL (TRUNC (ffvl.start_date_active),
                                    TRUNC (SYSDATE)) <=
                               TRUNC (SYSDATE)
                           AND NVL (TRUNC (ffvl.end_date_active),
                                    TRUNC (SYSDATE)) >=
                               TRUNC (SYSDATE)
                           AND ffvl.enabled_flag = 'Y'
                           AND TO_NUMBER (ffvl.attribute1) = p_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ou_short_name   := NULL;
                END;

                lv_file_dir        := lv_vs_file_path;
                lv_ou_short_name   := NULL;
                lv_file_name       :=
                       lv_vs_file_name
                    || '_'
                    || lv_period_name
                    || '_'
                    || lv_ou_short_name
                    || '_'
                    || gn_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';


                fnd_file.put_line (
                    fnd_file.LOG,
                    'Supporting File Name is - ' || lv_file_name);

                lv_output_file     :=
                    UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                  ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN op_file_orr
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the  data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_op_file;

    PROCEDURE update_attributes (x_ret_message OUT VARCHAR2, p_org_id IN NUMBER, p_period_end_date IN VARCHAR2)
    IS
        lv_last_date         VARCHAR2 (50);
        lv_natural_acct_vs   VARCHAR2 (50);

        CURSOR c_get_data IS
            SELECT xorr.ROWID,
                   --ffvl.attribute3  entity_uniq_ident,--
                   NVL (ffvl.attribute21, ffvl.attribute3) entity_uniq_ident, --
                   NULL account_number,
                   DECODE (
                       xorr.brand,
                       'ALL BRAND', '1000',
                       (SELECT flex_value
                          FROM fnd_flex_values_vl
                         WHERE     flex_value_set_id = 1015912
                               AND UPPER (description) = xorr.brand)) key3,
                   ffvl.attribute4 key4,
                   str.store_name3 key5,
                   str.store_name_secondary key6,
                   --ffvl.attribute5  key7,
                   NVL (ffvl.attribute21, ffvl.attribute5) key7,
                   NULL key8,
                   NULL key9,
                   NULL key10,
                   xorr.extd_price sub_acct_balance,
                   str.org_unit_id
              FROM hz_parties hp, hz_cust_accounts_all hca, apps.fnd_lookup_values flv,
                   store@xxdo_retail_rms.us.oracle.com str, xxdo.xxd_wms_open_ret_ext_t xorr, apps.fnd_flex_value_sets ffvs,
                   apps.fnd_flex_values_vl ffvl
             WHERE     1 = 1
                   AND hp.party_id = hca.party_id
                   AND hca.cust_account_id = flv.attribute1
                   AND flv.lookup_type = 'XXD_RETAIL_STORES'
                   AND flv.language = 'US'
                   AND str.store = flv.attribute6
                   --AND UPPER(xorr.store_location) = UPPER(hp.party_name)
                   AND xorr.cust_acct_num = hca.account_number
                   AND hp.status = 'A'
                   AND hca.status = 'A'
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                                   AND NVL (ffvl.end_date_active,
                                            SYSDATE + 1)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.attribute1 = str.org_unit_id
                   AND ffvs.flex_value_set_name =
                       'XXD_GL_AAR_OU_SHORTNAME_VS';
    BEGIN
        lv_natural_acct_vs   := NULL;

        -- Period end date of the as of date
        SELECT LAST_DAY (TO_DATE (p_period_end_date, 'RRRR/MM/DD HH24:MI:SS'))
          INTO lv_last_date
          FROM DUAL;


        FOR i IN c_get_data
        LOOP
            lv_natural_acct_vs   := NULL;

            BEGIN
                SELECT ffvl.attribute10
                  INTO lv_natural_acct_vs
                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                 WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND fvs.flex_value_set_name =
                           'XXD_GL_AAR_OU_SHORTNAME_VS'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND TO_NUMBER (ffvl.attribute1) =
                           NVL (p_org_id, i.org_unit_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_natural_acct_vs   := NULL;
            END;

            UPDATE xxdo.xxd_wms_open_ret_ext_t
               SET entity_uniq_identifier = i.entity_uniq_ident, account_number = NVL (lv_natural_acct_vs, i.account_number), key3 = i.key3,
                   key4 = i.key4, key5 = i.key5, key6 = i.key6,
                   key7 = i.key7, key8 = i.key8, key9 = i.key9,
                   key10 = i.key10, period_end_date = lv_last_date, subledr_rep_bal = NULL,
                   subledr_alt_bal = NULL, subledr_acc_bal = i.sub_acct_balance
             WHERE ROWID = i.ROWID AND request_id = gn_request_id;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := SQLERRM;
    END update_attributes;

    --For Parameter Additional Report 'YES'
    PROCEDURE insert_bl_link_details (x_ret_message          OUT VARCHAR2,
                                      p_period_end_date   IN     VARCHAR2)
    IS
        lv_last_date   VARCHAR2 (50);
        ln_exists      NUMBER;
        lv_bl_link     VARCHAR2 (50);
        lv_prog_name   VARCHAR2 (150);

        CURSOR c_get_data IS
              SELECT entity_uniq_identifier, account_number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10, SUM (extd_price) sub_acct_balance
                FROM xxdo.xxd_wms_open_ret_ext_t xorr
               WHERE 1 = 1 AND xorr.request_id = gn_request_id
            GROUP BY entity_uniq_identifier, account_number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10;
    BEGIN
        -- Period end date of the as of date
        SELECT LAST_DAY (TO_DATE (p_period_end_date, 'RRRR/MM/DD HH24:MI:SS'))
          INTO lv_last_date
          FROM DUAL;

        --To fetch BL Report Link
        BEGIN
            SELECT ffvl.flex_value, ffvl.description
              INTO lv_prog_name, lv_bl_link
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'XXD_GL_BL_REPORT_LINK'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.flex_value =
                       (SELECT user_concurrent_program_name
                          FROM fnd_concurrent_programs_tl
                         WHERE     concurrent_program_id = gn_conc_program_id
                               AND language = USERENV ('LANG'));
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_prog_name   := NULL;
                lv_bl_link     := NULL;
        END;


        FOR i IN c_get_data
        LOOP
            --Validate BL Link Account details exists
            BEGIN
                SELECT COUNT (1)
                  INTO ln_exists
                  FROM xxdo.xxd_gl_bl_report_link_ext_t
                 WHERE     1 = 1
                       AND entity_uniq_identifier = i.entity_uniq_identifier
                       AND account_number = i.account_number
                       AND NVL (key3, -1) = NVL (i.key3, -1)
                       AND NVL (key4, -1) = NVL (i.key4, -1)
                       AND NVL (key5, -1) = NVL (i.key5, -1)
                       AND NVL (key6, -1) = NVL (i.key6, -1)
                       AND NVL (key7, -1) = NVL (i.key7, -1)
                       AND NVL (key8, -1) = NVL (i.key8, -1)
                       AND NVL (key9, -1) = NVL (i.key9, -1)
                       AND NVL (key10, -1) = NVL (i.key10, -1)
                       AND bl_link = lv_bl_link
                       AND entity_name = lv_prog_name
                       AND period_end_date = lv_last_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_exists   := 0;
            END;

            IF NVL (ln_exists, 0) > 0
            THEN
                --Update BL Linkage Table
                BEGIN
                    UPDATE xxdo.xxd_gl_bl_report_link_ext_t
                       SET subledr_acc_bal = i.sub_acct_balance, request_id = gn_request_id, last_update_date = gd_date,
                           last_updated_by = gn_user_id
                     WHERE     1 = 1
                           --AND request_id = gn_request_id
                           AND entity_uniq_identifier =
                               i.entity_uniq_identifier
                           AND account_number = i.account_number
                           AND NVL (key3, -1) = NVL (i.key3, -1)
                           AND NVL (key4, -1) = NVL (i.key4, -1)
                           AND NVL (key5, -1) = NVL (i.key5, -1)
                           AND NVL (key6, -1) = NVL (i.key6, -1)
                           AND NVL (key7, -1) = NVL (i.key7, -1)
                           AND NVL (key8, -1) = NVL (i.key8, -1)
                           AND NVL (key9, -1) = NVL (i.key9, -1)
                           AND NVL (key10, -1) = NVL (i.key10, -1)
                           AND bl_link = lv_bl_link
                           AND entity_name = lv_prog_name
                           AND period_end_date = lv_last_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Updation failed for BL Linkage Table' || SQLERRM);
                END;
            ELSE
                --Insert into BL Linkage Table
                BEGIN
                    INSERT INTO xxdo.xxd_gl_bl_report_link_ext_t (
                                    request_id,
                                    bl_link,
                                    entity_name,
                                    entity_uniq_identifier,
                                    account_number,
                                    key3,
                                    key4,
                                    key5,
                                    key6,
                                    key7,
                                    key8,
                                    key9,
                                    key10,
                                    period_end_date,
                                    subledr_rep_bal,
                                    subledr_alt_bal,
                                    subledr_acc_bal,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by)
                         VALUES (gn_request_id, lv_bl_link, lv_prog_name,
                                 i.entity_uniq_identifier, i.account_number, i.key3, i.key4, i.key5, i.key6, i.key7, i.key8, i.key9, i.key10, lv_last_date, NULL, NULL, i.sub_acct_balance, gd_date
                                 , gn_user_id, gd_date, gn_user_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Insertion failed for BL Linkage Table'
                            || SQLERRM);
                END;
            END IF;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := SQLERRM;
    END insert_bl_link_details;

    PROCEDURE update_valueset_prc (p_file_path IN VARCHAR2)
    IS
        lv_user_name      VARCHAR2 (100);
        lv_request_info   VARCHAR2 (100);
    BEGIN
        lv_user_name      := NULL;
        lv_request_info   := NULL;

        BEGIN
            SELECT fu.user_name, TO_CHAR (fcr.actual_start_date, 'MM/DD/RRRR HH24:MI:SS')
              INTO lv_user_name, lv_request_info
              FROM apps.fnd_concurrent_requests fcr, apps.fnd_user fu
             WHERE request_id = gn_request_id AND requested_by = fu.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_user_name      := NULL;
                lv_request_info   := NULL;
        END;

        UPDATE apps.fnd_flex_values_vl ffvl
           SET ffvl.attribute5 = lv_user_name, ffvl.attribute6 = lv_request_info
         WHERE     NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                   TRUNC (SYSDATE)
               AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE)
               AND ffvl.enabled_flag = 'Y'
               AND ffvl.description = 'OPENRETAIL'
               AND ffvl.flex_value = p_file_path
               AND ffvl.flex_value_set_id IN
                       (SELECT flex_value_set_id
                          FROM apps.fnd_flex_value_sets
                         WHERE flex_value_set_name =
                               'XXD_GL_AAR_FILE_DETAILS_VS');

        COMMIT;
    END update_valueset_prc;

    PROCEDURE main (errbuf                 OUT NOCOPY VARCHAR2,
                    retcode                OUT NOCOPY NUMBER,
                    p_period_end_date   IN            VARCHAR2,
                    p_org_id            IN            NUMBER,
                    p_addl_report       IN            VARCHAR2,
                    p_file_path         IN            VARCHAR2)
    IS
        p_qty_precision          NUMBER := 2;

        CURSOR cur_inv IS
            SELECT ra_nbr, store_location, created,
                   style, color_code, size_code,
                   original_quantity, received_quantity, cancelled_quantity,
                   open_quantity, extd_price, currency,
                   warehouse, brand, account_number
              FROM (  SELECT ooha.order_number ra_nbr, oola.ordered_item order_item, xciv.style_number style,
                             xciv.color_code color_code, xciv.item_size size_code, REPLACE (hp.party_name, CHR (9), '') store_location,
                             TO_CHAR (ooha.creation_date, 'DD-MON-YYYY') created, SUM (oola.ordered_quantity) + SUM (oola.cancelled_quantity) original_quantity, SUM (NVL (oola.shipped_quantity, 0)) received_quantity,
                             SUM (oola.cancelled_quantity) cancelled_quantity, SUM (oola.ordered_quantity) - SUM (NVL (oola.shipped_quantity, 0)) open_quantity, ROUND (SUM ((oola.ordered_quantity - NVL (oola.shipped_quantity, 0)) * oola.unit_selling_price), 2) extd_price,
                             ooha.transactional_curr_code currency, mp.organization_code warehouse, ooha.attribute5 brand,
                             hca.account_number
                        -- ,flv.description email_addr
                        FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.hz_cust_accounts hca,
                             apps.hz_parties hp, apps.mtl_parameters mp, apps.fnd_lookup_values flv,
                             apps.xxd_common_items_v xciv
                       WHERE     ooha.order_source_id =
                                 (SELECT order_source_id
                                    FROM apps.oe_order_sources
                                   WHERE name = 'Retail')
                             AND ooha.header_id = oola.header_id
                             AND ooha.open_flag = 'Y'
                             AND EXISTS
                                     (SELECT NULL
                                        FROM apps.oe_order_lines_all
                                       WHERE     header_id = ooha.header_id
                                             AND line_category_code = 'RETURN'
                                             AND open_flag = 'Y'
                                             AND ROWNUM = 1)
                             AND oola.line_category_code = 'RETURN'
                             AND hca.cust_account_id = ooha.sold_to_org_id
                             AND hca.party_id = hp.party_id
                             AND hca.status = 'A'
                             AND hp.status = 'A'
                             AND mp.organization_id = oola.ship_from_org_id
                             AND xciv.inventory_item_id =
                                 oola.inventory_item_id
                             AND xciv.organization_id = oola.ship_from_org_id
                             AND flv.lookup_type = 'XXDO_RETAIL_RETURNS_ALERT'
                             AND flv.lookup_code = mp.organization_code
                             AND flv.enabled_flag = 'Y'
                             AND flv.language = USERENV ('LANG')
                             AND NVL (flv.end_date_active, SYSDATE + 1) >
                                 SYSDATE
                             AND ooha.org_id = NVL (p_org_id, ooha.org_id)
                    GROUP BY ooha.order_number, ooha.attribute5, hp.party_name,
                             TO_CHAR (ooha.creation_date, 'DD-MON-YYYY'), mp.organization_code, -- flv.description,
                                                                                                ooha.transactional_curr_code,
                             oola.ordered_item, xciv.style_number, xciv.color_code,
                             xciv.item_size, hca.account_number
                    ORDER BY mp.organization_code, hp.party_name, ooha.order_number);

        l_api_name      CONSTANT VARCHAR2 (30) := 'generate_data';
        l_api_version   CONSTANT NUMBER := 1.0;
        l_return_status          VARCHAR2 (1);

        l_full_name     CONSTANT VARCHAR2 (60)
                                     := G_PKG_NAME || '.' || l_api_name ;
        l_module        CONSTANT VARCHAR2 (60) := 'cst.plsql.' || l_full_name;


        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (240);

        lv_ret_message           VARCHAR2 (2000) := NULL;
        l_file_name              VARCHAR2 (100);

        TYPE tb_rec_inv IS TABLE OF cur_inv%ROWTYPE;

        v_tb_rec_inv             tb_rec_inv;
        l_count                  NUMBER;
        lv_ret_code              VARCHAR2 (30) := NULL;

        v_bulk_limit             NUMBER := 500;
    BEGIN
        OPEN cur_inv;

        LOOP
            FETCH cur_inv BULK COLLECT INTO v_tb_rec_inv LIMIT v_bulk_limit;


            BEGIN
                FORALL i IN 1 .. v_tb_rec_inv.COUNT
                    INSERT INTO xxdo.xxd_wms_open_ret_ext_t (
                                    request_id,
                                    ra_nbr,
                                    store_location,
                                    created,
                                    style,
                                    color_code,
                                    size_code,
                                    original_quantity,
                                    received_quantity,
                                    cancelled_quantity,
                                    open_quantity,
                                    extd_price,
                                    currency,
                                    warehouse,
                                    brand,
                                    cust_acct_num,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by)
                         VALUES (gn_request_id, v_tb_rec_inv (i).ra_nbr, v_tb_rec_inv (i).store_location, v_tb_rec_inv (i).created, v_tb_rec_inv (i).style, v_tb_rec_inv (i).color_code, v_tb_rec_inv (i).size_code, v_tb_rec_inv (i).original_quantity, v_tb_rec_inv (i).received_quantity, v_tb_rec_inv (i).cancelled_quantity, v_tb_rec_inv (i).open_quantity, v_tb_rec_inv (i).extd_price, v_tb_rec_inv (i).currency, v_tb_rec_inv (i).warehouse, v_tb_rec_inv (i).brand, v_tb_rec_inv (i).account_number, gd_date, gn_user_id
                                 , gd_date, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'insertion failed for  Table' || SQLERRM);
            END;

            COMMIT;
            EXIT WHEN CUR_INV%NOTFOUND;
        END LOOP;

        write_op_file (p_file_path, l_file_name, p_period_end_date,
                       p_org_id, lv_ret_code, lv_ret_message);

        update_attributes (lv_ret_message, p_org_id, p_period_end_date);

        IF NVL (p_addl_report, 'N') = 'Y'
        THEN
            insert_bl_link_details (lv_ret_message, p_period_end_date);

            write_orr_recon_link_file (p_file_path, l_file_name, p_period_end_date
                                       , lv_ret_code, lv_ret_message);
        ELSE
            write_orr_recon_file (p_file_path, l_file_name, lv_ret_code,
                                  lv_ret_message);
        END IF;

        update_valueset_prc (p_file_path);
    END main;
END;
/
