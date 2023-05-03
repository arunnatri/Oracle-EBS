--
-- XXD_AP_PREPAY_BAL_EXT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_PREPAY_BAL_EXT_PKG"
AS
    --  ########################################################################################
    --  Package      : XXD_AP_PREPAY_BAL_EXT_PKG
    --  Design       : This package provides Text extract for AP Prepayment Balances to BL
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                          Comments
    --  ======================================================================================
    --  22-JUN-2021     1.0        Aravind Kannuri               CCR0009318
    --  27-APR-2022     2.0        Srinath Siricilla             CCR0009909
    --  ########################################################################################

    gn_user_id            CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id           CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id             CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id            CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id       CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id         CONSTANT NUMBER := fnd_global.conc_request_id;
    gd_date               CONSTANT DATE := SYSDATE;

    g_pkg_name            CONSTANT VARCHAR2 (30) := 'XXD_AP_PREPAY_BAL_EXT_PKG';
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
            SELECT line
              FROM (  SELECT (entity_uniq_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (period_end_date, 'MM/DD/RRRR') || CHR (9) || Subledr_Rep_Bal || CHR (9) || subledr_alt_bal || CHR (9) || SUM (subledr_acc_bal)) line, SUM (subledr_acc_bal) tot_subledr_acc_bal
                        FROM xxdo.xxd_ap_prepay_bal_ext_t
                       WHERE 1 = 1 AND request_id = gn_request_id
                    GROUP BY entity_uniq_identifier, account_number, key3,
                             key4, key5, key6,
                             key7, key8, key9,
                             key10, period_end_date, subledr_rep_bal,
                             subledr_alt_bal)
             WHERE NVL (tot_subledr_acc_bal, 0) <> 0;

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
                       AND ffvl.description = 'PREPAYMENT'
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

    PROCEDURE write_op_file (p_file_path         IN     VARCHAR2,
                             p_file_name         IN     VARCHAR2,
                             p_period_end_date   IN     VARCHAR2,
                             p_org_id            IN     NUMBER,
                             x_ret_code             OUT VARCHAR2,
                             x_ret_message          OUT VARCHAR2)
    IS
        CURSOR op_file_orr IS
              SELECT line
                FROM (SELECT 1 AS seq, operating_unit || gv_delimeter || source || gv_delimeter || supplier_number || gv_delimeter || supplier_name || gv_delimeter || invoice_num || gv_delimeter || invoice_currency_code || gv_delimeter || description || gv_delimeter || invoice_date || gv_delimeter || invoice_amount || gv_delimeter || amount_paid || gv_delimeter || amount_applied || gv_delimeter || orig_prepay_amount_remaining -- Added as per CCR0009909
                                                                                                                                                                                                                                                                                                                                                                                                                                              || gv_delimeter || prepay_amount_remaining line
                        FROM xxdo.xxd_ap_prepay_bal_ext_t
                       WHERE 1 = 1 AND request_id = gn_request_id
                      UNION
                      SELECT 2 AS Seq, 'Operating_Unit' || gv_delimeter || 'Source' || gv_delimeter || 'Supplier_Number' || gv_delimeter || 'Supplier_Name' || gv_delimeter || 'Invoice_Num' || gv_delimeter || 'Invoice_Currency_Code' || gv_delimeter || 'Description' || gv_delimeter || 'Invoice_Date' || gv_delimeter || 'Invoice_Amount' || gv_delimeter || 'Amount_Paid' || gv_delimeter || 'Amount_Applied' || gv_delimeter || 'Original_Prepay_Amount_Remaining' -- Added as per CCR0009909
                                                                                                                                                                                                                                                                                                                                                                                                                                                                          || gv_delimeter || 'Prepay_Amount_Remaining_FC'
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
                       AND ffvl.description = 'PREPAYMENT'
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
               AND ffvl.description = 'PREPAYMENT'
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
                    p_region            IN            VARCHAR2,
                    p_org_id            IN            NUMBER,
                    p_file_path         IN            VARCHAR2)
    IS
        p_qty_precision          NUMBER := 2;
        ld_period_end_dt         DATE;
        lv_last_date             VARCHAR2 (50);

        CURSOR cur_inv (p_period_end_date VARCHAR2)
        IS
              SELECT *
                FROM (  SELECT hou.name
                                   operating_unit,
                               aia.source,
                               asa.segment1
                                   supplier_number,
                               asa.vendor_name
                                   supplier_name,
                               aia.invoice_num,
                               aia.invoice_currency_code,
                               aia.payment_currency_code,
                               aia.description,
                               aia.invoice_date,
                               aia.invoice_amount,
                               aia.amount_paid,
                               -- Added and Commented as per CCR0009909
                               SUM (
                                     aida.total_dist_amount
                                   - NVL (aida.prepay_amount_remaining,
                                          aida.total_dist_amount))
                                   amount_applied,
                               Aia.Invoice_Amount - det.amount
                                   prepay_amount_remaining_nfc,
                               ROUND (
                                   DECODE (
                                       aia.invoice_currency_code,
                                       'CNY', Aia.Invoice_Amount - det.amount,
                                         (Aia.Invoice_Amount - det.amount)
                                       * NVL (
                                             (SELECT conversion_rate
                                                FROM apps.gl_daily_rates
                                               WHERE     conversion_type = 'Spot'
                                                     AND from_currency =
                                                         aia.invoice_currency_code
                                                     AND to_currency =
                                                         (SELECT gs.currency_code
                                                            FROM apps.gl_sets_of_books gs, apps.financials_system_params_all os
                                                           WHERE     1 = 1
                                                                 AND os.set_of_books_id =
                                                                     gs.set_of_books_id
                                                                 AND hou.organization_id =
                                                                     os.org_id)
                                                     AND conversion_date =
                                                         TRUNC (
                                                             LAST_DAY (
                                                                 fnd_date.canonical_to_date (
                                                                     p_period_end_date)))),
                                             1)),
                                   2)
                                   prepay_amount_remaining_fc,
                               --       ( aia.invoice_amount - (aida.total_dist_amount - nvl(aida.prepay_amount_remaining, aida.total_dist_amount)) ) prepay_amount_remaining_nfc,
                               --                            ( aia.invoice_amount - (aida.total_dist_amount - nvl(aida.prepay_amount_remaining, aida.total_dist_amount)) )
                               --             * NVL ((SELECT conversion_rate
                               --                 FROM apps.gl_daily_rates
                               --                WHERE     conversion_type = 'Corporate'
                               --                   AND from_currency = aia.invoice_currency_code
                               --                   AND to_currency = aia.payment_currency_code
                               --                   AND conversion_date = TRUNC (aia.invoice_date)),
                               --                 1)  prepay_amount_remaining_fc,
                               -- End of Change for CCR0009909
                               gcc.segment1
                                   entity_uniq_identifier,
                               gcc.segment6
                                   account_number,
                               gcc.segment2
                                   key3,
                               gcc.segment3
                                   key4,
                               gcc.segment4
                                   key5,
                               gcc.segment5
                                   key6,
                               gcc.segment7
                                   key7,
                               NULL
                                   Key8,
                               NULL
                                   key9,
                               NULL
                                   key10
                          --       gcc.segment8    key8,
                          --       gcc.segment9    key9,
                          --       gcc.segment10   key10
                          FROM apps.ap_invoices_all aia,
                               apps.ap_invoice_distributions_all aida,
                               apps.hr_operating_units hou,
                               apps.ap_suppliers asa,
                               -- Added as per CCR0009909
                               apps.xla_events xe,
                               apps.xla_ae_headers xah,
                               apps.xla_ae_lines xal,
                               apps.gl_code_combinations gcc,
                               -- Commented as per CCR0009909
                               /*xla.xla_transaction_entities   xte,
          xla.xla_events                 xev,
          xla.xla_ae_headers             xah,
          xla.xla_ae_lines               xal,
          gl_import_references           gir,
          gl_je_headers                  gjh,
          gl_je_lines                    gjl*/
                               (  SELECT SUM (total_dist_amount - NVL (prepay_amount_remaining, total_dist_amount)) amount, invoice_id, org_id
                                    FROM apps.ap_invoice_distributions_all
                                GROUP BY invoice_id, org_id) det
                         -- End of Change as per CCR0009909
                         WHERE     1 = 1
                               AND aia.invoice_id = aida.invoice_id
                               AND det.org_id = aia.org_id
                               AND det.invoice_id = aida.invoice_id
                               AND aia.vendor_id = asa.vendor_id
                               AND aia.invoice_type_lookup_code = 'PREPAYMENT'
                               -- Added as per CCR0009909
                               AND xe.event_id = aida.accounting_event_id
                               AND xe.event_id = xah.event_id
                               AND xe.entity_id = xah.entity_id
                               AND xah.ledger_id = aia.set_of_books_id
                               AND xah.ae_header_id = xal.ae_header_id
                               AND xal.accounting_class_code = 'PREPAID_EXPENSE'
                               AND hou.organization_id = aia.org_id
                               AND xal.code_combination_id =
                                   gcc.code_combination_id
                               -- End of Change as per CCR0009909
                               -- Commented as per CCR0009909
                               /*
          AND aia.invoice_id = NVL(xte.source_id_int_1, -99)
                               AND aia.set_of_books_id  = xte.ledger_id
                               AND xte.entity_id = xev.entity_id
          AND xte.entity_id = xah.entity_id
          AND xah.event_id = xev.event_id
          AND xev.event_id = aida.accounting_event_id
          AND xah.ae_header_id = xal.ae_header_id
          AND xal.gl_sl_link_id = gir.gl_sl_link_id
          AND gir.gl_sl_link_table = xal.gl_sl_link_table
          AND gjl.je_header_id = gjh.je_header_id
          AND gjh.je_header_id = gir.je_header_id
          AND gjl.je_header_id = gir.je_header_id
          AND gir.je_line_num = gjl.je_line_num
          AND hou.organization_id = aia.org_id
          AND aida.dist_code_combination_id = gcc.code_combination_id
          */
                               AND NVL (reversal_flag, 'N') <> 'Y'
                               AND (   (p_org_id IS NOT NULL AND hou.organization_id = p_org_id)
                                    OR (    p_org_id IS NULL
                                        AND hou.organization_id IN
                                                (SELECT TO_NUMBER (ffvl.attribute1)
                                                   FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                                                  WHERE     fvs.flex_value_set_id =
                                                            ffvl.flex_value_set_id
                                                        AND fvs.flex_value_set_name =
                                                            'XXD_GL_AAR_OU_SHORTNAME_VS'
                                                        AND NVL (
                                                                TRUNC (
                                                                    ffvl.start_date_active),
                                                                TRUNC (SYSDATE)) <=
                                                            TRUNC (SYSDATE)
                                                        AND NVL (
                                                                TRUNC (
                                                                    ffvl.end_date_active),
                                                                TRUNC (SYSDATE)) >=
                                                            TRUNC (SYSDATE)
                                                        AND ffvl.enabled_flag =
                                                            'Y'
                                                        AND NVL (ffvl.attribute9,
                                                                 'NA') =
                                                            p_region)))
                               AND NVL (TRUNC (aia.invoice_date), SYSDATE) <=
                                   NVL (
                                       fnd_date.canonical_to_date (
                                           p_period_end_date),
                                       NVL (TRUNC (aia.invoice_date), SYSDATE))
                               AND aia.invoice_amount <> 0
                      GROUP BY hou.name, aia.source, asa.segment1,
                               asa.vendor_name, aia.invoice_num, aia.invoice_date,
                               aia.invoice_amount, aia.amount_paid, aia.invoice_currency_code,
                               aia.payment_currency_code, aia.description, hou.organization_id, -- Added as per CCR0009909
                               aia.exchange_rate,   -- Added as per CCR0009909
                                                  gcc.segment1, gcc.segment6,
                               gcc.segment2, gcc.segment3, gcc.segment4,
                               gcc.segment5, gcc.segment7, gcc.segment8,
                               gcc.segment9, gcc.segment10, det.amount)
               WHERE 1 = 1 AND NVL (prepay_amount_remaining_nfc, 0) <> 0
            ORDER BY operating_unit, source, invoice_num;

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
        ln_ou_id                 NUMBER;
    BEGIN
        -- Period end date for as of date
        SELECT LAST_DAY (TO_DATE (p_period_end_date, 'RRRR/MM/DD HH24:MI:SS'))
          INTO lv_last_date
          FROM DUAL;

        OPEN cur_inv (p_period_end_date);

        LOOP
            FETCH cur_inv BULK COLLECT INTO v_tb_rec_inv LIMIT v_bulk_limit;


            BEGIN
                FORALL i IN 1 .. v_tb_rec_inv.COUNT
                    INSERT INTO xxdo.xxd_ap_prepay_bal_ext_t (
                                    request_id,
                                    operating_unit,
                                    source,
                                    supplier_number,
                                    supplier_name,
                                    invoice_num,
                                    invoice_currency_code,
                                    description,
                                    invoice_date,
                                    invoice_amount,
                                    amount_paid,
                                    amount_applied,
                                    prepay_amount_remaining,
                                    orig_prepay_amount_remaining, -- -- Added as per CCR0009909
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
                         VALUES (gn_request_id, v_tb_rec_inv (i).operating_unit, v_tb_rec_inv (i).source, v_tb_rec_inv (i).supplier_number, v_tb_rec_inv (i).supplier_name, v_tb_rec_inv (i).invoice_num, v_tb_rec_inv (i).invoice_currency_code, v_tb_rec_inv (i).description, v_tb_rec_inv (i).invoice_date, v_tb_rec_inv (i).invoice_amount, v_tb_rec_inv (i).amount_paid, v_tb_rec_inv (i).amount_applied, v_tb_rec_inv (i).prepay_amount_remaining_fc, v_tb_rec_inv (i).prepay_amount_remaining_nfc, -- -- Added as per CCR0009909
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          v_tb_rec_inv (i).entity_uniq_identifier, v_tb_rec_inv (i).account_number, v_tb_rec_inv (i).key3, v_tb_rec_inv (i).key4, v_tb_rec_inv (i).key5, v_tb_rec_inv (i).key6, v_tb_rec_inv (i).key7, v_tb_rec_inv (i).key8, v_tb_rec_inv (i).key9, v_tb_rec_inv (i).key10, lv_last_date, NULL, NULL, v_tb_rec_inv (i).prepay_amount_remaining_fc, gd_date, gn_user_id
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

        write_orr_recon_file (p_file_path, l_file_name, lv_ret_code,
                              lv_ret_message);

        update_valueset_prc (p_file_path);
    END main;
END;
/
