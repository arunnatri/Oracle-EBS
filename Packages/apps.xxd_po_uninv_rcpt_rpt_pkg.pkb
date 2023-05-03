--
-- XXD_PO_UNINV_RCPT_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_UNINV_RCPT_RPT_PKG"
AS
    --  ###################################################################################################
    --  Package      : XXD_PO_UNINV_RCPT_RPT_PKG
    --  Design       : This package provides XML extract for Deckers Uninvoiced Receipts Report to BL
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                          Comments
    --  ======================================================================================
    --  15-APR-2021     1.0       Srinath Siricilla               Intial Version 1.0
    --  18-JAN-2022     1.1       Aravind Kannuri                 Updated for CCR0009783
    --  ###################################################################################################

    gn_user_id            CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id           CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id             CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id            CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id       CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id         CONSTANT NUMBER := fnd_global.conc_request_id;
    gd_date               CONSTANT DATE := SYSDATE;

    g_pkg_name            CONSTANT VARCHAR2 (30) := 'XXD_PO_UNINV_RCPT_RPT_PKG';
    g_log_level           CONSTANT NUMBER := FND_LOG.G_CURRENT_RUNTIME_LEVEL;
    gv_delimeter                   VARCHAR2 (1) := '|';

    g_gl_application_id   CONSTANT NUMBER := 101;
    g_po_application_id   CONSTANT NUMBER := 201;

    PROCEDURE print_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, lv_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print log:' || SQLERRM);
    END print_log;

    PROCEDURE write_uninv_recon_file (p_file_path IN VARCHAR2, p_file_name IN VARCHAR2, --p_count         IN     NUMBER,
                                                                                        x_ret_code OUT VARCHAR2
                                      , x_ret_message OUT VARCHAR2)
    IS
        CURSOR uninv_reconcilation IS
              SELECT (entity_uniq_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (Period_End_Date, 'MM/DD/RRRR') || CHR (9) || Subledr_Rep_Bal || CHR (9) || Subledr_alt_Bal || CHR (9) || SUM (Subledr_Acc_Bal)) line
                FROM xxdo.xxd_po_uninv_rcpt_t
               WHERE 1 = 1 AND request_id = gn_request_id
            GROUP BY entity_uniq_identifier, Account_Number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10, Period_End_Date, Subledr_Rep_Bal,
                     Subledr_alt_Bal;

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
        FOR i IN uninv_reconcilation
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
                       AND ffvl.description = 'UNINVOICED'
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
                    FOR i IN uninv_reconcilation
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
    END write_uninv_recon_file;



    PROCEDURE write_op_file (p_file_path IN VARCHAR2, p_file_name IN VARCHAR2, p_operating_unit IN NUMBER
                             , p_period_name IN VARCHAR2, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2)
    IS
        --Added 2 fields (USD_Balances, Age) in Cursor for 1.1
        CURSOR op_file_uninv IS
              SELECT line
                FROM (SELECT 1 AS seq, po_number || gv_delimeter || release_num || gv_delimeter || line_type || gv_delimeter || line_num || gv_delimeter || item_name || gv_delimeter || category || gv_delimeter || item_desc || gv_delimeter || vendor_name || gv_delimeter || preparer || gv_delimeter || last_receipt_receiver || gv_delimeter || acc_currency || gv_delimeter || shipment_num || gv_delimeter || qty_received || gv_delimeter || qty_billed || gv_delimeter || po_unit_price || gv_delimeter || func_unit_price || gv_delimeter || uom || gv_delimeter || dist_num || gv_delimeter || qty_received || gv_delimeter || charge_account || gv_delimeter || acc_account || gv_delimeter || acc_amount || gv_delimeter || func_acc_amount || gv_delimeter || usd_balances || gv_delimeter || age line
                        FROM xxdo.xxd_po_uninv_rcpt_t
                       WHERE 1 = 1 AND request_id = gn_request_id
                      UNION
                      SELECT 2 AS seq, 'PO_Number' || gv_delimeter || 'Release' || gv_delimeter || 'Line_Type' || gv_delimeter || 'Line' || gv_delimeter || 'Item' || gv_delimeter || 'Category' || gv_delimeter || 'Item_Description' || gv_delimeter || 'Vendor' || gv_delimeter || 'Preparer' || gv_delimeter || 'Receipt_Receiver' || gv_delimeter || 'Accrual_Currency' || gv_delimeter || 'Shipment#' || gv_delimeter || 'Quantity_Or_Amount_received' || gv_delimeter || 'Quantity_Or_Amount_Billed' || gv_delimeter || 'PO_Unit_Price' || gv_delimeter || 'PO_Functional_Unit_Price' || gv_delimeter || 'Unit_of_measure' || gv_delimeter || 'Distribution_Num' || gv_delimeter || 'Dist_Quantity_Or_Amount_received' || gv_delimeter || 'Charge_Account' || gv_delimeter || 'Accrual_Account' || gv_delimeter || 'Accrual_Amount' || gv_delimeter || 'Functional_Accrual_Amount' || gv_delimeter || 'USD_Accrual_Amount' || gv_delimeter || 'Age'
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
                       AND ffvl.description = 'UNINVOICED'
                       AND ffvl.flex_value = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'Period Name here is - ' || p_period_name);

            IF p_period_name IS NOT NULL
            THEN
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND period_name = p_period_name;
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
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND TRUNC (SYSDATE) BETWEEN start_date
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
                           AND ffvl.attribute1 = p_operating_unit;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ou_short_name   := NULL;
                END;

                lv_file_dir   := lv_vs_file_path;
                lv_file_name   :=
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

                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                  ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN op_file_uninv
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


    PROCEDURE update_attributes (x_ret_message OUT VARCHAR2)
    IS
        l_last_date   VARCHAR2 (50);

        CURSOR c_get_data IS
            SELECT a.ROWID, c.segment1 entity_uniq_ident, c.segment6 account_number,
                   a.charge_brand key3, c.segment3 key4, c.segment4 key5,
                   c.segment5 key6, c.segment7 key7, NULL key8,
                   NULL key9, NULL key10, func_acc_amount sub_acct_balance
              FROM xxdo.xxd_po_uninv_rcpt_t a, gl_code_combinations_kfv c
             WHERE     1 = 1
                   AND a.request_id = gn_request_id
                   AND a.acc_account = c.concatenated_segments;
    BEGIN
        -- Period end date of the as of date
        --SELECT LAST_DAY (SYSDATE) INTO l_last_date FROM DUAL;

        FOR i IN c_get_data
        LOOP
            UPDATE xxdo.xxd_po_uninv_rcpt_t
               SET entity_uniq_identifier = i.entity_uniq_ident, Account_Number = i.account_number, Key3 = i.Key3,
                   Key4 = i.Key4, Key5 = i.Key5, Key6 = i.Key6,
                   Key7 = i.Key7, Key8 = i.Key8, Key9 = i.Key9,
                   Key10 = i.Key10, --Period_End_Date = l_last_date,
                                    Subledr_Rep_Bal = NULL, Subledr_alt_Bal = NULL,
                   Subledr_Acc_Bal = i.sub_acct_balance
             WHERE ROWID = i.ROWID AND request_id = gn_request_id;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := SQLERRM;
    END update_attributes;



    FUNCTION get_qty_precision (qty_precision IN NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_count OUT NOCOPY NUMBER
                                , x_msg_data OUT NOCOPY VARCHAR2)
        RETURN VARCHAR2
    IS
    BEGIN
        x_return_status   := fnd_api.g_ret_sts_success;

        IF qty_precision = 0
        THEN
            RETURN ('999G999G999G990');
        ELSIF qty_precision = 1
        THEN
            RETURN ('999G999G999G990D0');
        ELSIF qty_precision = 2
        THEN
            RETURN ('999G999G999G990D00');
        ELSIF qty_precision = 3
        THEN
            RETURN ('999G999G999G990D000');
        ELSIF qty_precision = 4
        THEN
            RETURN ('999G999G999G990D0000');
        ELSIF qty_precision = 5
        THEN
            RETURN ('999G999G999G990D00000');
        ELSIF qty_precision = 6
        THEN
            RETURN ('999G999G999G990D000000');
        ELSIF qty_precision = 7
        THEN
            RETURN ('999G999G999G990D0000000');
        ELSIF qty_precision = 8
        THEN
            RETURN ('999G999G999G990D00000000');
        ELSIF qty_precision = 9
        THEN
            RETURN ('999G999G999G990D000000000');
        ELSIF qty_precision = 10
        THEN
            RETURN ('999G999G999G990D0000000000');
        ELSIF qty_precision = 11
        THEN
            RETURN ('999G999G999G990D00000000000');
        ELSIF qty_precision = 12
        THEN
            RETURN ('999G999G999G990D000000000000');
        ELSIF qty_precision = 13
        THEN
            RETURN ('999G999G999G990D0000000000000');
        ELSE
            RETURN ('999G999G999G990D00');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := FND_API.g_ret_sts_unexp_error;
            x_msg_data        := SQLERRM;
            FND_MSG_PUB.count_and_get (p_count   => x_msg_count,
                                       p_data    => x_msg_data);
            fnd_file.put_line (
                FND_FILE.LOG,
                'Error in: XXD_PO_UNINV_RCPT_RPT_PKG.get_qty_precision()');
    END get_qty_precision;

    --Start Addded for 1.1
    --Get USD Conversion per Spotrate
    FUNCTION get_usd_conversion (p_currency IN VARCHAR2, p_cutoff_date IN VARCHAR2, p_accrual_amount IN NUMBER)
        RETURN NUMBER
    IS
        lv_currency              VARCHAR2 (50) := p_currency;
        ld_cutoff_date           DATE
            := NVL (fnd_date.canonical_to_date (p_cutoff_date), SYSDATE);
        ln_func_curr_spot_rate   NUMBER;
        ln_func_usd_amt          NUMBER;
    BEGIN
        DBMS_OUTPUT.put_line ('p_currency :' || p_currency);
        DBMS_OUTPUT.put_line ('p_cutoff_date :' || p_cutoff_date);
        DBMS_OUTPUT.put_line ('ld_cutoff_date :' || ld_cutoff_date);
        DBMS_OUTPUT.put_line ('p_accrual_amount :' || p_accrual_amount);

        BEGIN
            SELECT conversion_rate
              INTO ln_func_curr_spot_rate
              FROM gl_daily_rates
             WHERE     from_currency = lv_currency
                   AND to_currency = 'USD'
                   AND TRUNC (conversion_date) = TRUNC (ld_cutoff_date)
                   AND conversion_type = 'Spot';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_func_curr_spot_rate   := NULL;
        END;

        DBMS_OUTPUT.put_line (
            'ln_func_curr_spot_rate :' || ln_func_curr_spot_rate);

        IF NVL (lv_currency, 'USD') <> 'USD'
        THEN
            IF NVL (ln_func_curr_spot_rate, 0) = 0
            THEN
                ln_func_usd_amt   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'GL Daily Rates are not defined for Conversion Date :'
                    || TRUNC (ld_cutoff_date));
            ELSE
                ln_func_usd_amt   :=
                    p_accrual_amount * NVL (ln_func_curr_spot_rate, 1);
            END IF;
        ELSE
            ln_func_usd_amt   := p_accrual_amount;
        END IF;

        --fnd_file.put_line (fnd_file.log, 'ln_func_usd_amount :'||ROUND(ln_func_usd_amt,2));
        RETURN ROUND (ln_func_usd_amt, 2);
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_func_usd_amt   := NULL;
            fnd_file.put_line (fnd_file.LOG,
                               'Exp-ln_func_usd_amount :' || ln_func_usd_amt);
            RETURN ln_func_usd_amt;
    END get_usd_conversion;

    --Get Invoice Age for MAX Receipt based on PO
    FUNCTION get_invoice_age (p_po_header_id IN NUMBER, p_po_line_id IN NUMBER, p_cutoff_date IN VARCHAR2)
        RETURN NUMBER
    IS
        ld_max_receipt_date   DATE;
        ln_invoice_age        NUMBER;
        ld_cutoff_date        DATE
            := NVL (fnd_date.canonical_to_date (p_cutoff_date), SYSDATE);
    BEGIN
        BEGIN
            SELECT MAX (rt.transaction_date)
              INTO ld_max_receipt_date
              FROM rcv_shipment_lines rsl, rcv_transactions rt
             WHERE     rsl.po_header_id = p_po_header_id
                   AND rsl.po_line_id = p_po_line_id
                   AND rsl.shipment_header_id = rt.shipment_header_id
                   AND rsl.shipment_line_id = rt.shipment_line_id
                   AND rt.transaction_type = 'RECEIVE';
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_max_receipt_date   := NULL;
        END;

        IF ld_max_receipt_date IS NOT NULL
        THEN
            ln_invoice_age   :=
                ABS (ROUND ((ld_max_receipt_date - ld_cutoff_date), 0));
        ELSE
            ln_invoice_age   := 1;
        END IF;

        --fnd_file.put_line (fnd_file.log, 'ln_invoice_age :'||ln_invoice_age);
        RETURN ln_invoice_age;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_invoice_age   := -1;
            fnd_file.put_line (fnd_file.LOG,
                               'Exp-ln_invoice_age :' || ln_invoice_age);
            RETURN ln_invoice_age;
    END get_invoice_age;

    --Get Preparer for PO
    FUNCTION get_po_preparer (p_po_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_preparer   VARCHAR2 (240);
    BEGIN
        SELECT DISTINCT ppf.full_name
          INTO lv_preparer
          FROM po_requisition_headers_all prh, po_requisition_lines_all prl, po_req_distributions_all prd,
               per_all_people_f ppf, po_headers_all poh, po_distributions_all pda
         WHERE     prh.requisition_header_id = prl.requisition_header_id
               AND ppf.person_id = prh.preparer_id
               AND prh.type_lookup_code = 'PURCHASE'
               AND prd.requisition_line_id = prl.requisition_line_id
               AND pda.req_distribution_id = prd.distribution_id
               AND pda.po_header_id = poh.po_header_id
               AND poh.po_header_id = p_po_header_id;                  --17047

        --AND prd.distribution_id = p_po_distribution_id; --184005

        --fnd_file.put_line (fnd_file.log, 'PO Preparer :'||lv_preparer);
        RETURN lv_preparer;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_preparer   := NULL;
            fnd_file.put_line (fnd_file.LOG,
                               'Exp - PO Preparer :' || SQLERRM);
            RETURN lv_preparer;
    END get_po_preparer;

    --Get Last Receipt Receiver for PO
    FUNCTION get_rcpt_receiver (p_po_header_id   IN NUMBER,
                                p_po_line_id     IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_receiver   VARCHAR2 (240);
    BEGIN
        SELECT DISTINCT papf.full_name
          INTO lv_receiver
          FROM rcv_shipment_lines rsl, rcv_transactions rt, per_all_people_f papf
         WHERE     rsl.po_header_id = p_po_header_id
               AND rsl.po_line_id = p_po_line_id
               AND rsl.shipment_header_id = rt.shipment_header_id
               AND rsl.shipment_line_id = rt.shipment_line_id
               AND rt.employee_id = papf.person_id
               AND rt.transaction_type = 'RECEIVE'
               AND rt.transaction_date =
                   (SELECT MAX (rt1.transaction_date)
                      FROM rcv_shipment_lines rsl1, rcv_transactions rt1
                     WHERE     rsl1.po_header_id = p_po_header_id
                           AND rsl1.po_line_id = p_po_line_id
                           AND rsl1.shipment_header_id =
                               rt1.shipment_header_id
                           AND rsl1.shipment_line_id = rt1.shipment_line_id
                           AND rt1.transaction_type = 'RECEIVE');

        --fnd_file.put_line (fnd_file.log, 'Last Receipt Receiver :'||lv_receiver);
        RETURN lv_receiver;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_receiver   := NULL;
            fnd_file.put_line (fnd_file.LOG,
                               'Exp - Last Receipt Receiver :' || SQLERRM);
            RETURN lv_receiver;
    END get_rcpt_receiver;

    --End Addded for 1.1

    PROCEDURE main (errbuf                     OUT NOCOPY VARCHAR2,
                    retcode                    OUT NOCOPY NUMBER,
                    p_title                 IN            VARCHAR2,
                    p_accrued_receipts      IN            VARCHAR2,
                    p_inc_online_accruals   IN            VARCHAR2,
                    p_inc_closed_pos        IN            VARCHAR2,
                    p_struct_num            IN            NUMBER,
                    p_category_from         IN            VARCHAR2,
                    p_category_to           IN            VARCHAR2,
                    p_min_accrual_amount    IN            NUMBER,
                    p_period_name           IN            VARCHAR2,
                    p_vendor_from           IN            VARCHAR2,
                    p_vendor_to             IN            VARCHAR2,
                    p_orderby               IN            VARCHAR2,
                    p_file_path             IN            VARCHAR2,
                    p_age_greater_then      IN            VARCHAR2, --Added for 1.1
                    p_cut_off_date          IN            VARCHAR2) --Added for 1.1
    IS
        p_qty_precision          NUMBER := 2;

        CURSOR cur_inv (pn_sob_id NUMBER, pv_age_type VARCHAR2)
        IS
              SELECT NVL (poh.clm_document_number, poh.segment1) po_number, --Changed as a part of CLM
                                                                            porl.release_num po_release_number, poh.po_header_id po_header_id,
                     pol.po_line_id po_line_id, SUM (ROUND (NVL (cpea.quantity_received, 0), p_qty_precision)) OVER (PARTITION BY pol.po_line_id) tot_rcv, SUM (ROUND (NVL (cpea.quantity_billed, 0), p_qty_precision)) OVER (PARTITION BY pol.po_line_id) tot_billed,
                     cpea.shipment_id po_shipment_id, cpea.distribution_id po_distribution_id, plt.line_type line_type,
                     NVL (POL.LINE_NUM_DISPLAY, TO_CHAR (POL.LINE_NUM)) line_num, --Changed as a part of CLM
                                                                                  msi.concatenated_segments item_name, mca.concatenated_segments category,
                     pol.item_description item_description, pov.vendor_name vendor_name, fnc2.currency_code accrual_currency_code,
                     poll.shipment_num shipment_number, poll.unit_meas_lookup_code uom_code, pod.distribution_num distribution_num,
                     ROUND (NVL (cpea.quantity_received, 0), p_qty_precision) quantity_received, ROUND (NVL (cpea.quantity_billed, 0), p_qty_precision) quantity_billed, ROUND (NVL (cpea.accrual_quantity, 0), p_qty_precision) quantity_accrued,
                     ROUND (cpea.unit_price, NVL (fnc2.extended_precision, 2)) po_unit_price, cpea.currency_code po_currency_code, ROUND (DECODE (NVL (fnc1.minimum_accountable_unit, 0), 0, cpea.unit_price * cpea.currency_conversion_rate, (cpea.unit_price / fnc1.minimum_accountable_unit) * cpea.currency_conversion_rate * fnc1.minimum_accountable_unit), NVL (fnc1.extended_precision, 2)) func_unit_price,
                     gcc1.concatenated_segments charge_account, gcc1.segment2 charge_brand, gcc2.concatenated_segments accrual_account,
                     gcc2.code_combination_id accrual_ccid, cpea.accrual_amount accrual_amount, ROUND (DECODE (NVL (fnc1.minimum_accountable_unit, 0), 0, cpea.accrual_amount * cpea.currency_conversion_rate, (cpea.accrual_amount / fnc1.minimum_accountable_unit) * cpea.currency_conversion_rate * fnc1.minimum_accountable_unit), NVL (fnc1.precision, 2)) * -1 func_accrual_amount,
                     NVL (fnc2.extended_precision, 2) PO_PRECISION, NVL (fnc1.extended_precision, 2) PO_FUNC_PRECISION, NVL (fnc1.precision, 2) ACCR_PRECISION,
                     --Start Added for 1.1
                     get_invoice_age (pol.po_header_id, pol.po_line_id, p_cut_off_date) age, get_usd_conversion (cpea.currency_code, --fnc2.currency_code,
                                                                                                                                     p_cut_off_date, cpea.accrual_amount) usd_accrual_amount, --usd_balances,
                                                                                                                                                                                              get_po_preparer (pol.po_header_id) preparer,
                     get_rcpt_receiver (pol.po_header_id, pol.po_line_id) receipt_receiver
                --End Added for 1.1
                FROM cst_per_end_accruals_temp cpea, po_headers_all poh, po_lines_all pol,
                     po_line_locations_all poll, po_distributions_all pod, ap_suppliers pov,
                     po_line_types plt, po_releases_all porl, mtl_system_items_kfv msi,
                     fnd_currencies fnc1, fnd_currencies fnc2, mtl_categories_kfv mca,
                     gl_code_combinations_kfv gcc1, gl_code_combinations_kfv gcc2, gl_ledgers sob
               WHERE     pod.po_distribution_id = cpea.distribution_id
                     AND poh.po_header_id = pol.po_header_id
                     AND pol.po_line_id = poll.po_line_id
                     AND poll.line_location_id = pod.line_location_id
                     AND pol.line_type_id = plt.line_type_id
                     AND porl.po_release_id(+) = poll.po_release_id
                     AND poh.vendor_id = pov.vendor_id
                     AND msi.inventory_item_id(+) = pol.item_id
                     AND (msi.organization_id IS NULL OR (msi.organization_id = poll.ship_to_organization_id AND msi.organization_id IS NOT NULL))
                     AND fnc1.currency_code = cpea.currency_code
                     AND fnc2.currency_code = sob.currency_code
                     AND cpea.category_id = mca.category_id(+)
                     AND gcc1.code_combination_id = pod.code_combination_id
                     AND gcc2.code_combination_id = pod.accrual_account_id
                     AND sob.ledger_id = pn_sob_id
                     --Start Added for 1.1
                     AND ((pv_age_type = 'GREATER_THEN' AND get_invoice_age (pol.po_header_id, pol.po_line_id, p_cut_off_date) > ABS (p_age_greater_then)) OR (pv_age_type = 'LESS_THEN' AND get_invoice_age (pol.po_header_id, pol.po_line_id, p_cut_off_date) < ABS (p_age_greater_then)) OR (pv_age_type = 'ZERO' AND 1 = 1))
            --End Added for 1.1
            ORDER BY DECODE (p_orderby,  'Category', mca.concatenated_segments,  'vendor', pov.vendor_name,  NVL (poh.CLM_DOCUMENT_NUMBER, poh.SEGMENT1)), NVL (poh.CLM_DOCUMENT_NUMBER, poh.SEGMENT1), NVL (POL.LINE_NUM_DISPLAY, TO_CHAR (POL.LINE_NUM)),
                     poll.shipment_num, pod.distribution_num;

        l_api_name      CONSTANT VARCHAR2 (30) := 'generate_data';
        l_api_version   CONSTANT NUMBER := 1.0;
        l_return_status          VARCHAR2 (1);

        l_full_name     CONSTANT VARCHAR2 (60)
                                     := G_PKG_NAME || '.' || l_api_name ;
        l_module        CONSTANT VARCHAR2 (60) := 'cst.plsql.' || l_full_name;


        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (240);

        l_header_ref_cur         SYS_REFCURSOR;
        l_body_ref_cur           SYS_REFCURSOR;
        l_row_tag                VARCHAR2 (100);
        l_row_set_tag            VARCHAR2 (100);
        l_xml_header             CLOB;
        l_xml_body               CLOB;
        l_xml_report             CLOB;

        l_conc_status            BOOLEAN;
        l_return                 BOOLEAN;
        l_status                 VARCHAR2 (1);
        l_industry               VARCHAR2 (1);
        l_schema                 VARCHAR2 (30);
        l_application_id         NUMBER;
        l_legal_entity           NUMBER;
        l_end_date               DATE;
        l_sob_id                 NUMBER;
        l_order_by               VARCHAR2 (50);
        l_multi_org_flag         VARCHAR2 (1);
        l_accrued_receipts       VARCHAR2 (20);
        l_inc_online_accruals    VARCHAR2 (20);
        l_inc_closed_pos         VARCHAR2 (20);

        l_stmt_num               NUMBER;
        l_row_count              NUMBER;

        l_qty_precision          VARCHAR2 (50);
        lv_ret_message           VARCHAR2 (2000) := NULL;
        l_file_name              VARCHAR2 (100);

        TYPE tb_rec_inv IS TABLE OF cur_inv%ROWTYPE;

        v_tb_rec_inv             tb_rec_inv;
        --v_tb_rec_cust    tb_rec_cust;
        l_count                  NUMBER;
        lv_ret_code              VARCHAR2 (30) := NULL;

        v_bulk_limit             NUMBER := 500;

        ld_end_date              DATE := NULL;

        --Added for 1.1
        lv_age_type              VARCHAR2 (50) := NULL;
        ln_age                   NUMBER := 0;
    BEGIN
        EXECUTE IMMEDIATE 'ALTER SESSION SET NLS_NUMERIC_CHARACTERS=''.,''';

        l_stmt_num        := 0;

        mo_global.set_policy_context ('S', fnd_global.org_id);
        fnd_global.apps_initialize (user_id        => fnd_global.user_id,
                                    resp_id        => fnd_global.resp_id,
                                    resp_appl_id   => fnd_global.resp_appl_id);

        -- Initialize message list if p_init_msg_list is set to TRUE.
        FND_MSG_PUB.initialize;

        --  Initialize API return status to success
        l_return_status   := FND_API.G_RET_STS_SUCCESS;

        -- Check whether GL is installed
        l_stmt_num        := 10;
        l_return          :=
            FND_INSTALLATION.GET_APP_INFO ('SQLGL', l_status, l_industry,
                                           l_schema);

        apps.fnd_file.put_line (
            fnd_file.LOG,
            'The value of fnd_global.org_id is - ' || fnd_global.org_id);

        apps.fnd_file.put_line (fnd_file.LOG,
                                'Period Name Passed is - ' || p_period_name);

        IF (l_status = 'I')
        THEN
            l_application_id   := G_GL_APPLICATION_ID;
        ELSE
            l_application_id   := G_PO_APPLICATION_ID;
        END IF;

        -- Convert Accrual Cutoff date from Legal entity timezone to
        -- Server timezone
        l_stmt_num        := 20;

        SELECT set_of_books_id
          INTO l_sob_id
          FROM financials_system_parameters;

        SELECT TO_NUMBER (org_information2)
          INTO l_legal_entity
          FROM hr_organization_information
         WHERE     organization_id = MO_GLOBAL.GET_CURRENT_ORG_ID
               AND org_information_context = 'Operating Unit Information';

        apps.fnd_file.put_line (
            fnd_file.LOG,
            'The value of MO_GLOBAL.GET_CURRENT_ORG_ID is - ' || MO_GLOBAL.GET_CURRENT_ORG_ID);

        l_stmt_num        := 30;

        SELECT INV_LE_TIMEZONE_PUB.GET_SERVER_DAY_TIME_FOR_LE (gps.end_date, l_legal_entity)
          INTO l_end_date
          FROM gl_period_statuses gps
         WHERE     gps.application_id = l_application_id
               AND gps.set_of_books_id = l_sob_id
               AND gps.period_name =
                   NVL (
                       p_period_name,
                       (SELECT gp.period_name
                          FROM gl_periods gp, gl_ledgers sob --Updated CCR0006335
                         WHERE     sob.ledger_id = l_sob_id
                               AND sob.period_set_name = gp.period_set_name
                               AND sob.accounted_period_type = gp.period_type
                               AND gp.ADJUSTMENT_PERIOD_FLAG = 'N'
                               AND gp.start_date <= TRUNC (SYSDATE)
                               AND gp.end_date >= TRUNC (SYSDATE)));

        ---------------------------------------------------------------------
        -- Call the common API CST_PerEndAccruals_PVT.Create_PerEndAccruals
        -- This API creates period end accrual entries in the temporary
        -- table CST_PER_END_ACCRUALS_TEMP.
        ---------------------------------------------------------------------
        l_stmt_num        := 60;
        CST_PerEndAccruals_PVT.Create_PerEndAccruals (
            p_api_version          => 1.0,
            p_init_msg_list        => FND_API.G_FALSE,
            p_commit               => FND_API.G_FALSE,
            p_validation_level     => FND_API.G_VALID_LEVEL_FULL,
            x_return_status        => l_return_status,
            x_msg_count            => l_msg_count,
            x_msg_data             => l_msg_data,
            p_min_accrual_amount   => p_min_accrual_amount,
            p_vendor_from          => p_vendor_from,
            p_vendor_to            => p_vendor_to,
            p_category_from        => p_category_from,
            p_category_to          => p_category_to,
            p_end_date             => l_end_date,
            p_accrued_receipt      => NVL (p_accrued_receipts, 'N'),
            p_online_accruals      => NVL (p_inc_online_accruals, 'N'),
            p_closed_pos           => NVL (p_inc_closed_pos, 'N'),
            p_calling_api          =>
                CST_PerEndAccruals_PVT.G_UNINVOICED_RECEIPT_REPORT);

        -- If return status is not success, add message to the log
        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            l_msg_data   :=
                'Failed generating Period End Accrual information';
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        l_stmt_num        := 100;

        SELECT COUNT ('X')
          INTO l_row_count
          FROM CST_PER_END_ACCRUALS_TEMP
         WHERE ROWNUM = 1;

        l_stmt_num        := 101;

        l_order_by        := p_orderby;

        l_stmt_num        := 102;

        IF (p_accrued_receipts = 'Y' OR p_accrued_receipts = 'N')
        THEN
            SELECT meaning
              INTO l_accrued_receipts
              FROM fnd_lookups
             WHERE     lookup_type = 'YES_NO'
                   AND lookup_code = p_accrued_receipts;
        ELSE
            l_accrued_receipts   := ' ';
        END IF;

        l_stmt_num        := 103;

        IF (p_inc_online_accruals = 'Y' OR p_inc_online_accruals = 'N')
        THEN
            SELECT meaning
              INTO l_inc_online_accruals
              FROM fnd_lookups
             WHERE     lookup_type = 'YES_NO'
                   AND lookup_code = p_inc_online_accruals;
        ELSE
            l_inc_online_accruals   := ' ';
        END IF;

        l_stmt_num        := 104;

        IF (p_inc_closed_pos = 'Y' OR p_inc_closed_pos = 'N')
        THEN
            SELECT meaning
              INTO l_inc_closed_pos
              FROM fnd_lookups
             WHERE lookup_type = 'YES_NO' AND lookup_code = p_inc_closed_pos;
        ELSE
            l_inc_closed_pos   := ' ';
        END IF;

        -------------------------------------------------------------------------
        -- Open reference cursor for fetching data related to report header
        -------------------------------------------------------------------------
        l_stmt_num        := 105;
        l_qty_precision   :=
            get_qty_precision (qty_precision => p_qty_precision, x_return_status => l_return_status, x_msg_count => l_msg_count
                               , x_msg_data => l_msg_data);

        IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
        THEN
            l_msg_data   := 'Failed getting qty precision';
            RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
        END IF;

        -- Get Period End Date using Period Name

        ld_end_date       := NULL;

        IF p_period_name IS NOT NULL
        THEN
            BEGIN
                SELECT end_date
                  INTO ld_end_date
                  FROM apps.gl_periods
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND period_name = p_period_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_end_date   := NULL;
            END;
        ELSE
            BEGIN
                SELECT end_date
                  INTO ld_end_date
                  FROM apps.gl_periods
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND TRUNC (SYSDATE) BETWEEN start_date AND end_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_end_date   := NULL;
            END;
        END IF;

        --Start Added for 1.1
        IF NVL (p_age_greater_then, 0) IN (60, 180)
        THEN
            lv_age_type   := 'GREATER_THEN';
        ELSIF NVL (p_age_greater_then, 0) IN (-60, -180)
        THEN
            lv_age_type   := 'LESS_THEN';
        ELSE
            lv_age_type   := 'ZERO';              --p_age_greater_then IS NULL
        END IF;

        --End Added for 1.1

        OPEN cur_inv (l_sob_id, lv_age_type);

        LOOP
            FETCH cur_inv BULK COLLECT INTO v_tb_rec_inv LIMIT v_bulk_limit;


            BEGIN
                FORALL i IN 1 .. v_tb_rec_inv.COUNT
                    INSERT INTO xxdo.xxd_po_uninv_rcpt_t (
                                    request_id,
                                    po_number,
                                    release_num,
                                    line_type,
                                    line_num,
                                    category,
                                    item_name,
                                    item_desc,
                                    vendor_name,
                                    acc_currency,
                                    shipment_num,
                                    qty_received,
                                    qty_billed,
                                    po_unit_price,
                                    uom,
                                    dist_num,
                                    charge_account,
                                    acc_account,
                                    acc_ccid,
                                    acc_amount,
                                    func_acc_amount,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    charge_brand,
                                    period_end_date,
                                    usd_balances,              --Added for 1.1
                                    age,                       --Added for 1.1
                                    preparer,                  --Added for 1.1
                                    last_receipt_receiver      --Added for 1.1
                                                         )
                         VALUES (gn_request_id, v_tb_rec_inv (i).po_number, v_tb_rec_inv (i).po_release_number, v_tb_rec_inv (i).line_type, v_tb_rec_inv (i).line_num, v_tb_rec_inv (i).Category, v_tb_rec_inv (i).item_name, v_tb_rec_inv (i).item_description, v_tb_rec_inv (i).vendor_name, v_tb_rec_inv (i).po_currency_code, --accrual_currency_code,
                                                                                                                                                                                                                                                                                                                                  v_tb_rec_inv (i).shipment_number, v_tb_rec_inv (i).quantity_received, v_tb_rec_inv (i).quantity_billed, v_tb_rec_inv (i).po_unit_price, v_tb_rec_inv (i).uom_code, v_tb_rec_inv (i).distribution_num, v_tb_rec_inv (i).charge_account, --
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         v_tb_rec_inv (i).accrual_account, -- acc account
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           v_tb_rec_inv (i).accrual_ccid, v_tb_rec_inv (i).accrual_amount, v_tb_rec_inv (i).func_accrual_amount, gd_date, gn_user_id, gd_date, gn_user_id, v_tb_rec_inv (i).charge_brand, ld_end_date, v_tb_rec_inv (i).usd_accrual_amount, --Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            v_tb_rec_inv (i).age, --Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  v_tb_rec_inv (i).preparer
                                 ,                             --Added for 1.1
                                   v_tb_rec_inv (i).receipt_receiver --Added for 1.1
                                                                    );
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

        write_op_file (p_file_path, l_file_name, fnd_global.org_id,
                       p_period_name, lv_ret_code, lv_ret_message);

        update_attributes (lv_ret_message);

        write_uninv_recon_file (p_file_path, l_file_name, --l_count,
                                                          lv_ret_code,
                                lv_ret_message);
    END main;
END XXD_PO_UNINV_RCPT_RPT_PKG;
/
