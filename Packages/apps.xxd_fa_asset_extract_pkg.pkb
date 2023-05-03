--
-- XXD_FA_ASSET_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FA_ASSET_EXTRACT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_FA_ASSET_EXTRACT_PKG
    * Design       : This package will be used to fetch the asset details and send to blackline
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 18-May-2021  1.0        Showkath Ali            Initial Version
    ******************************************************************************************/
    -- AAR Changes start
    gn_request_id   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    gn_user_id      NUMBER := FND_GLOBAL.USER_ID;
    gn_error        NUMBER := 1;

    PROCEDURE write_asset_file (p_file_path IN VARCHAR2, p_request_id IN NUMBER, x_ret_code OUT VARCHAR2
                                , x_ret_message OUT VARCHAR2)
    IS
        CURSOR write_ap_extract IS
              SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || period_end_date || CHR (9) || subledger_rep_bal || CHR (9) || subledger_alt_bal || CHR (9) || ROUND (SUM (subledger_acc_bal), 2) line
                FROM xXDO.xxd_fa_asset_val_ext_t
               WHERE request_id = p_request_id
            GROUP BY entity_unique_identifier, account_number, key3,
                     key, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledger_rep_bal,
                     subledger_alt_bal;

        --DEFINE VARIABLES

        lv_file_path              VARCHAR2 (360);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        ln_request_id             NUMBER := fnd_global.conc_request_id;
    BEGIN
        -- WRITE INTO FND LOGS
        FOR i IN write_ap_extract
        LOOP
            lv_line   := i.line;
            fnd_file.put_line (fnd_file.output, lv_line);
        END LOOP;

        IF p_file_path IS NOT NULL
        THEN
            -- WRITE INTO BL FOLDER
            --showkath

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
                       AND ffvl.description = 'ASSET'
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

                lv_outbound_file   :=
                       lv_vs_file_name
                    || '_'
                    || ln_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';

                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                       ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN write_ap_extract
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the asset extract data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    x_ret_code      := gn_error;
                    x_ret_message   := lv_err_msg;
                    RETURN;
                --END IF;
                END IF;
            END IF;

            UTL_FILE.fclose (lv_output_file);

            -- update value set,

            BEGIN
                UPDATE apps.fnd_flex_values ffvl
                   SET ffvl.attribute5   =
                           (SELECT user_name
                              FROM fnd_user
                             WHERE user_id = gn_user_id),
                       ffvl.attribute6   =
                           TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS')
                 WHERE     1 = 1
                       AND ffvl.flex_value_set_id =
                           (SELECT flex_value_set_id
                              FROM apps.fnd_flex_value_sets
                             WHERE flex_value_set_name =
                                   'XXD_GL_AAR_FILE_DETAILS_VS')
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.flex_value = p_file_path;

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
    END write_asset_file;


    PROCEDURE write_asset_output (p_request_id IN NUMBER, p_file_path IN VARCHAR2, p_book IN VARCHAR2
                                  , p_period IN VARCHAR2, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2)
    IS
        CURSOR write_asset_output_cur IS
            SELECT ASSET_CATEGORY || '|' || ASSET_COST_ACCOUNT || '|' || ASSET_NUMBER || '|' || ASSET_DESCRIPTION || '|' || ASSET_SERIAL_NUMBER || '|' || CUSTODIAN || '|' || DATE_PLACED_IN_SERVICE || '|' || LIFE_YRS_MO || '|' || DEPRN_METHOD || '|' || COST || '|' || BEGIN_YEAR_DEPR_RESERVE || '|' || CURRENT_PERIOD_DEPRECIATION || '|' || YTD_DEPRECIATION || '|' || ' ' || '|' || ENDING_DEPR_RESERVE || '|' || NET_BOOK_VALUE || '|' || DEPRECIATION_ACCOUNT || '|' || LOCATION_FLEXFIELD || '|' || ASSET_TAG_NUMBER || '|' || SUPPLIER || '|' || ASSET_TYPE || '|' || ASSET_RESERVE_ACCOUNT || '|' || PROJECT_NUMBER line
              FROM xxdo.xxd_fa_asset_val_ext_t
             WHERE request_id = p_request_id AND line_type = 'Cost';

        lv_file_name       VARCHAR2 (360);
        lv_file_dir        VARCHAR2 (1000);
        lv_output_file     UTL_FILE.file_type;
        lv_output_file1    UTL_FILE.file_type;
        lv_err_msg         VARCHAR2 (2000) := NULL;
        lv_line            VARCHAR2 (32767) := NULL;
        lv_vs_file_path    VARCHAR2 (100);
        lv_vs_file_name    VARCHAR2 (100);
        lv_ou_short_name   VARCHAR2 (100);
        ln_request_id      NUMBER := fnd_global.conc_request_id;
        lv_period_name     VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Program file generation starts here...');

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
                       AND ffvl.description = 'ASSET'
                       AND ffvl.flex_value = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

            IF     lv_vs_file_path IS NOT NULL
               AND NVL (lv_vs_file_path, 'X') <> 'NA'
               AND lv_vs_file_name IS NOT NULL
            THEN
                /*BEGIN
             SELECT
             ffvl. attribute2
          INTO lv_ou_short_name
         FROM
             apps.fnd_flex_value_sets   fvs,
             apps.fnd_flex_values_vl    ffvl
         WHERE
             fvs.flex_value_set_id = ffvl.flex_value_set_id
             AND fvs.flex_value_set_name = 'XXD_GL_AAR_OU_SHORTNAME_VS'
             AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
             AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
             AND ffvl.enabled_flag = 'Y';
             --AND ffvl.attribute1 = p_operating_unit;

             EXCEPTION WHEN OTHERS THEN
             lv_ou_short_name:=NULL;
             END;*/

                -- query to fetch period name

                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND period_name = p_period;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_period_name   := NULL;
                END;

                lv_file_dir   := lv_vs_file_path;
                lv_file_name   :=
                       lv_vs_file_name
                    || '_'
                    || lv_period_name
                    || '_'
                    || p_book
                    || '_'
                    || ln_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';
                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                  ,
                                    32767);   --opening the file in write mode

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    lv_line   :=
                           'Asset Category (Maajor.Minor.Brand)'
                        || '|'
                        || 'Assert Cost Account'
                        || '|'
                        || 'Asset Number'
                        || '|'
                        || 'Asset Description'
                        || '|'
                        || 'Serial number'
                        || '|'
                        || 'Custodian'
                        || '|'
                        || 'Date Placed In Service'
                        || '|'
                        || 'Life Yr.Mo'
                        || '|'
                        || 'Deprn Method'
                        || '|'
                        || 'Cost'
                        || '|'
                        || 'Begin of year Depr Reserve'
                        || '|'
                        || 'Current Period Depreciation'
                        || '|'
                        || 'Yeat-To-Date Depreciation'
                        || '|'
                        || 'Current Period Impairment'
                        || '|'
                        || 'Ending Depr. Reserve'
                        || '|'
                        || 'Net Book Value'
                        || '|'
                        || 'Depreciation Account'
                        || '|'
                        || 'Location Flexfield'
                        || '|'
                        || 'Tag Number'
                        || '|'
                        || 'Supplier'
                        || '|'
                        || 'Asset Type'
                        || '|'
                        || 'Asset Reserve Account'
                        || '|'
                        || 'Project#';
                    UTL_FILE.put_line (lv_output_file, lv_line);

                    FOR i IN write_asset_output_cur
                    LOOP
                        lv_line   := NULL;
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;

                    UTL_FILE.fclose (lv_output_file);
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the AP extract data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    x_ret_code      := gn_error;
                    x_ret_message   := lv_err_msg;
                    RETURN;
                END IF;
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
    END;

    PROCEDURE insert_asset_records (P_BOOK IN VARCHAR2, P_PERIOD IN VARCHAR2, P_COST_CENTER IN VARCHAR2, P_MAJOR_CATEGORY IN VARCHAR2, P_MINOR_CATEGORY IN VARCHAR2, P_ASSET_COST_GROUP IN VARCHAR2, P_GRAND_TOTAL_BY IN VARCHAR2, P_CURRENCY IN NUMBER, P_PROJECT_TYPE IN VARCHAR2
                                    ,                            -- CCR0008086
                                      p_file_path IN VARCHAR2, p_ERRBUF IN VARCHAR2, P_retcode IN NUMBER)
    AS
        CURSOR insert_asset_records_cur IS
              SELECT xyz.book,
                     xyz.period,
                     xyz.asset_category,
                     xyz.asset_type,
                     xyz.asset_cost_account,
                     xyz.asset_number,
                     xyz.asset_description,
                     xyz.supplier,
                     xyz.custodian,
                     xyz.date_placed_in_service,
                     xyz.deprn_method,
                     xyz.life_yr_mo,
                     xyz.COST,
                     xyz.begin_year_depr_reserve,
                     xyz.current_period_depreciation,
                     xyz.ytd_depreciation,
                     CASE
                         WHEN     xyz.COST = 0
                              AND (SELECT COUNT (1)
                                     FROM fa_adjustments
                                    WHERE     asset_id =
                                              (SELECT asset_id
                                                 FROM FA_ADDITIONS_B
                                                WHERE asset_number =
                                                      xyz.asset_number)
                                          AND source_type_code = 'RETIREMENT') >
                                  0
                         THEN
                             0
                         ELSE
                             (xyz.COST - (xyz.net_book_value - xyz.impairment_amount))
                     END ending_depr_reserve,
                     CASE
                         WHEN     xyz.COST = 0
                              AND (SELECT COUNT (1)
                                     FROM fa_adjustments
                                    WHERE     asset_id =
                                              (SELECT asset_id
                                                 FROM FA_ADDITIONS_B
                                                WHERE asset_number =
                                                      xyz.asset_number)
                                          AND source_type_code = 'RETIREMENT') >
                                  0
                         THEN
                             0
                         ELSE
                             (xyz.net_book_value - xyz.impairment_amount)
                     END net_book_value,
                     --End of change for CCR0006997
                     xyz.depreciation_account,
                     xyz.location_flexfield,
                     xyz.asset_tag_number,
                     xyz.asset_serial_number,
                     xyz.asset_reserve_account,
                     xyz.project_number,
                     xyz.cost_center,
                     xyz.asset_acct,
                     xyz.brand,
                     xyz.major_category,
                     xyz.impairment_amount,
                     NVL (xyz.current_impairment_amount, 0) current_impairment_amount
                FROM (SELECT abc.book,
                             abc.period,
                             abc.asset_category,
                             abc.asset_type,
                             abc.asset_cost_account,
                             abc.asset_number,
                             abc.asset_description,
                             abc.supplier,
                             abc.custodian,
                             abc.date_placed_in_service,
                             abc.deprn_method,
                             abc.life_yr_mo,
                             abc.COST,
                             abc.begin_year_depr_reserve,
                             abc.current_period_depreciation,
                             abc.ytd_depreciation,
                             abc.ending_depr_reserve,
                             abc.net_book_value,
                             abc.depreciation_account,
                             abc.location_flexfield,
                             abc.asset_tag_number,
                             abc.asset_serial_number,
                             abc.asset_reserve_account,
                             abc.project_number,
                             abc.cost_center,
                             abc.asset_acct,
                             abc.brand,
                             abc.major_category,
                             --Start of change for CCR0006997
                             DECODE (
                                 (SELECT DISTINCT gcckfv.concatenated_segments
                                    FROM fa_distribution_history fadh, FA_ADDITIONS_B fab, fa_deprn_periods fadp,
                                         fa_locations fal, gl_code_combinations_kfv gcckfv
                                   WHERE     fadh.asset_id = fab.asset_id
                                         AND fab.asset_number =
                                             abc.asset_number
                                         AND fadp.book_type_code =
                                             fadh.book_type_code
                                         AND gcckfv.code_combination_id =
                                             fadh.code_combination_id
                                         AND fadp.period_name = abc.period
                                         AND fadh.book_type_code = abc.book
                                         AND fadh.location_id = fal.location_id
                                         AND    fal.SEGMENT1
                                             || '.'
                                             || fal.SEGMENT2
                                             || '.'
                                             || fal.SEGMENT3
                                             || '.'
                                             || fal.SEGMENT4
                                             || '.'
                                             || fal.SEGMENT5 =
                                             NVL (
                                                 abc.location_flexfield,
                                                    fal.SEGMENT1
                                                 || '.'
                                                 || fal.SEGMENT2
                                                 || '.'
                                                 || fal.SEGMENT3
                                                 || '.'
                                                 || fal.SEGMENT4
                                                 || '.'
                                                 || fal.SEGMENT5)
                                         AND FADP.CALENDAR_PERIOD_CLOSE_DATE BETWEEN date_effective
                                                                                 AND NVL (
                                                                                         DATE_INEFFECTIVE,
                                                                                         FADP.CALENDAR_PERIOD_CLOSE_DATE)),
                                 abc.depreciation_account, NVL (
                                                               --Start of Change for CCR0007573
                                                               (SELECT NVL (fds.impairment_reserve, 0)
                                                                  FROM fa_deprn_summary fds, fa_additions_b ad
                                                                 WHERE     fds.asset_id =
                                                                           ad.asset_id
                                                                       AND fds.book_type_code =
                                                                           abc.book
                                                                       AND ad.asset_number =
                                                                           abc.asset_number
                                                                       AND fds.period_counter IN
                                                                               (  SELECT MAX (period_counter)
                                                                                    FROM fa_deprn_summary
                                                                                   WHERE     book_type_code =
                                                                                             abc.book
                                                                                         AND asset_id =
                                                                                             ad.asset_id
                                                                                GROUP BY book_type_code, asset_id)--End of Change for CCR0007573
                                                                                                                  ),
                                                               0),
                                 0) impairment_amount,
                             ---- ADDED FOR CCR CCR0008443  -- begin
                             (SELECT NVL (SUM (impairmentseo.impairment_amount), 0) -- as per Arun comment
                                FROM fa_impairments impairmentseo, fa_cash_gen_units fcgu, gl_sets_of_books gsob,
                                     fa_additions_b fad, fa_lookups_tl flt, fa_book_controls bc,
                                     fa_deprn_periods fdp
                               WHERE     impairmentseo.cash_generating_unit_id =
                                         fcgu.cash_generating_unit_id(+)
                                     AND impairmentseo.book_type_code =
                                         bc.book_type_code
                                     AND bc.set_of_books_id =
                                         gsob.set_of_books_id
                                     AND impairmentseo.asset_id =
                                         fad.asset_id(+)
                                     AND impairmentseo.status =
                                         flt.lookup_code(+)
                                     AND flt.lookup_type(+) = 'MASS_TRX_STATUS'
                                     AND flt.language(+) = USERENV ('LANG')
                                     AND impairmentseo.book_type_code =
                                         abc.book
                                     AND fad.asset_NUMBER = abc.asset_number
                                     AND impairmentseo.status = 'POSTED'
                                     AND fdp.period_name = abc.period
                                     AND FDP.book_type_code = abc.book
                                     AND IMPAIRMENT_DATE BETWEEN fdp.PERIOD_OPEN_DATE
                                                             AND NVL (
                                                                     fdp.PERIOD_CLOSE_DATE,
                                                                       IMPAIRMENT_DATE
                                                                     + 1)) current_impairment_amount
                        ---- ADDED FOR CCR CCR0008443  -- End
                        --End of change for CCR0006997
                        FROM (  SELECT t.book, t.period, t.asset_category,
                                       t.asset_type, t.asset_cost_account, t.asset_number,
                                       t.asset_description, t.supplier, t.custodian,
                                       t.date_placed_in_service, t.deprn_method, t.life_yr_mo,
                                       SUM (t.COST) COST, SUM (t.begin_year_depr_reserve) begin_year_depr_reserve, SUM (t.current_period_depreciation) current_period_depreciation,
                                       SUM (t.ytd_depreciation) ytd_depreciation, SUM (t.ending_depr_reserve) ending_depr_reserve, SUM (t.net_book_value) net_book_value,
                                       t.depreciation_account depreciation_account, t.location_flexfield, t.asset_tag_number,
                                       t.asset_serial_number, t.asset_reserve_account, t.project_number,
                                       t.cost_center, t.asset_acct, t.brand,
                                       t.major_category
                                  FROM (SELECT book, period, asset_category_type asset_category,
                                               asset_type asset_type, asset_account asset_cost_account, TO_CHAR (asset_number) asset_number,
                                               asset_description asset_description, supplier supplier, custodian custodian,
                                               date_placed_in_service date_placed_in_service, deprn_method deprn_method, life_yr_mo life_yr_mo,
                                               NVL (COST, 0) COST, NVL (begin_year_depr_reserve, 0) begin_year_depr_reserve, NVL (current_period_depreciation, 0) current_period_depreciation,
                                               NVL (ytd_depreciation, 0) ytd_depreciation, NVL (ending_depr_reserve, 0) ending_depr_reserve, NVL (net_book_value, 0) net_book_value,
                                               depreciation_account depreciation_account, location_flexfield location_flexfield, asset_tag_number,
                                               asset_serial_number, asset_reserve_account, project_number,
                                               /*asset_cc*/
                                               gcc.segment5 cost_center, /*asset_acct*/
                                                                         gcc.segment6 asset_acct, asset_brand brand,
                                               SUBSTR (asset_category_type, 1, INSTR (asset_category_type, '.') - 1) major_category
                                          FROM xxdo.xxdo_fa_reserve_location_rep_x x, gl_code_combinations_kfv gcc
                                         WHERE     x.asset_account =
                                                   gcc.concatenated_segments(+)
                                               AND NVL (gcc.segment5, 'X') =
                                                   NVL (p_cost_center,
                                                        NVL (gcc.segment5, 'X'))
                                               --Start of change for CCR0006997
                                               AND NOT EXISTS
                                                       (SELECT 1
                                                          FROM fa_adjustments faa
                                                         WHERE     faa.asset_id =
                                                                   (SELECT fab.asset_id
                                                                      FROM FA_ADDITIONS_B fab
                                                                     WHERE fab.asset_number =
                                                                           x.asset_number)
                                                               AND faa.source_type_code =
                                                                   'RETIREMENT'
                                                               AND X.COST = 0
                                                               AND PERIOD_COUNTER_ADJUSTED <
                                                                   (SELECT PERIOD_COUNTER
                                                                      FROM fa_deprn_periods fadp
                                                                     WHERE     fadp.period_name =
                                                                               P_PERIOD
                                                                           AND fadp.book_type_code =
                                                                               P_BOOK))--End of change for CCR0006997
                                                                                       )
                                       t
                              GROUP BY t.book, t.period, t.asset_category,
                                       t.asset_type, t.asset_cost_account, t.asset_number,
                                       t.asset_description, t.supplier, t.custodian,
                                       t.date_placed_in_service, t.deprn_method, t.life_yr_mo,
                                       t.depreciation_account, t.location_flexfield, t.asset_tag_number,
                                       t.asset_serial_number, t.asset_reserve_account, t.project_number,
                                       t.cost_center, t.asset_acct, t.brand,
                                       t.major_category) abc) xyz
            ORDER BY xyz.brand, xyz.cost_center, xyz.asset_acct,
                     xyz.asset_number;

        lv_cost_segment1     gl_code_combinations_kfv.segment1%TYPE;
        lv_cost_segment2     gl_code_combinations_kfv.segment2%TYPE;
        lv_cost_segment3     gl_code_combinations_kfv.segment3%TYPE;
        lv_cost_segment4     gl_code_combinations_kfv.segment4%TYPE;
        lv_cost_segment5     gl_code_combinations_kfv.segment5%TYPE;
        lv_cost_segment6     gl_code_combinations_kfv.segment6%TYPE;
        lv_cost_segment7     gl_code_combinations_kfv.segment7%TYPE;
        lv_cost_segment8     gl_code_combinations_kfv.segment8%TYPE;
        lv_resv_segment1     gl_code_combinations_kfv.segment1%TYPE;
        lv_resv_segment2     gl_code_combinations_kfv.segment2%TYPE;
        lv_resv_segment3     gl_code_combinations_kfv.segment3%TYPE;
        lv_resv_segment4     gl_code_combinations_kfv.segment4%TYPE;
        lv_resv_segment5     gl_code_combinations_kfv.segment5%TYPE;
        lv_resv_segment6     gl_code_combinations_kfv.segment6%TYPE;
        lv_resv_segment7     gl_code_combinations_kfv.segment7%TYPE;
        lv_resv_segment8     gl_code_combinations_kfv.segment8%TYPE;
        lv_period_end_date   VARCHAR2 (100);
        ln_record_count      NUMBER;
        ln_retcode           NUMBER;
        lv_errbuf            VARCHAR2 (4000);
    BEGIN
        -- query to fetch period end date
        BEGIN
            SELECT TO_CHAR (calendar_period_close_date, 'MM/DD/YYYY')
              INTO lv_period_end_date
              FROM FA_DEPRN_PERIODS
             WHERE period_name = p_period AND book_type_code = p_book;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_period_end_date   := NULL;
        END;

        FOR i IN insert_asset_records_cur
        LOOP
            ln_record_count   := ln_record_count + 1;

            -- query to fetch asset cost account segments
            BEGIN
                SELECT gcc.segment1, gcc.segment2, gcc.segment3,
                       gcc.segment4, gcc.segment5, gcc.segment6,
                       gcc.segment7, gcc.segment8
                  INTO lv_cost_segment1, lv_cost_segment2, lv_cost_segment3, lv_cost_segment4,
                                       lv_cost_segment5, lv_cost_segment6, lv_cost_segment7,
                                       lv_cost_segment8
                  FROM gl_code_combinations_kfv gcc
                 WHERE concatenated_segments = i.asset_cost_account;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_cost_segment1   := NULL;
                    lv_cost_segment2   := NULL;
                    lv_cost_segment3   := NULL;
                    lv_cost_segment4   := NULL;
                    lv_cost_segment5   := NULL;
                    lv_cost_segment6   := NULL;
                    lv_cost_segment7   := NULL;
                    lv_cost_segment8   := NULL;
            END;

            -- query to fetch asset reserve account segments
            BEGIN
                SELECT gcc.segment1, gcc.segment2, gcc.segment3,
                       gcc.segment4, gcc.segment5, gcc.segment6,
                       gcc.segment7, gcc.segment8
                  INTO lv_resv_segment1, lv_resv_segment2, lv_resv_segment3, lv_resv_segment4,
                                       lv_resv_segment5, lv_resv_segment6, lv_resv_segment7,
                                       lv_resv_segment8
                  FROM gl_code_combinations_kfv gcc
                 WHERE concatenated_segments = i.asset_reserve_account;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_cost_segment1   := NULL;
                    lv_resv_segment2   := NULL;
                    lv_resv_segment3   := NULL;
                    lv_resv_segment4   := NULL;
                    lv_resv_segment5   := NULL;
                    lv_resv_segment6   := NULL;
                    lv_resv_segment7   := NULL;
                    lv_resv_segment8   := NULL;
            END;



            -- Insert the asset cost records in custom table
            BEGIN
                INSERT INTO XXDO.xxd_fa_asset_val_ext_t
                     VALUES (i.asset_category, i.asset_cost_account, i.asset_number, i.asset_description, i.asset_serial_number, i.custodian, i.date_placed_in_service, i.life_yr_mo, i.deprn_method, i.COST, i.begin_year_depr_reserve, i.current_period_depreciation, i.ytd_depreciation, i.ending_depr_reserve, i.net_book_value, i.depreciation_account, i.location_flexfield, i.asset_tag_number, i.supplier, i.asset_type, i.asset_reserve_account, i.project_number, i.impairment_amount, i.cost_center, i.brand, i.major_category, i.current_impairment_amount, lv_cost_segment1, lv_cost_segment6, lv_cost_segment2, lv_cost_segment3, lv_cost_segment4, lv_cost_segment5, lv_cost_segment7, NULL, NULL, NULL, lv_period_end_date, NULL, NULL, i.cost, gn_user_id, SYSDATE, gn_user_id, SYSDATE
                             , gn_request_id, 'Cost', i.book);

                IF MOD (ln_record_count, 500) = 0
                THEN
                    COMMIT;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Failed to insert into the custom table:' || SQLERRM);
            END;

            --
            -- Insert the asset reservr records in custom table
            BEGIN
                INSERT INTO XXDO.xxd_fa_asset_val_ext_t
                     VALUES (i.asset_category, i.asset_cost_account, i.asset_number, i.asset_description, i.asset_serial_number, i.custodian, i.date_placed_in_service, i.life_yr_mo, i.deprn_method, i.COST, i.begin_year_depr_reserve, i.current_period_depreciation, i.ytd_depreciation, i.ending_depr_reserve, i.net_book_value, i.depreciation_account, i.location_flexfield, i.asset_tag_number, i.supplier, i.asset_type, i.asset_reserve_account, i.project_number, i.impairment_amount, i.cost_center, i.brand, i.major_category, i.current_impairment_amount, lv_cost_segment1, lv_resv_segment6, lv_cost_segment2, lv_cost_segment3, lv_cost_segment4, lv_cost_segment5, lv_cost_segment7, NULL, NULL, NULL, lv_period_end_date, NULL, NULL, (-1) * (i.ending_depr_reserve), gn_user_id, SYSDATE, gn_user_id, SYSDATE
                             , gn_request_id, 'Reserve', i.book);

                IF MOD (ln_record_count, 500) = 0
                THEN
                    COMMIT;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'Failed to insert into the custom table:' || SQLERRM);
            END;
        END LOOP;

        write_asset_output (gn_request_id, p_file_path, p_book,
                            p_period, ln_retcode, lv_errbuf);
        write_asset_file (p_file_path, gn_request_id, ln_retcode,
                          lv_errbuf);
    END insert_asset_records;

    -- AAR Changes end
    PROCEDURE asset_main (p_ERRBUF                OUT VARCHAR2,
                          p_RETCODE               OUT NUMBER,
                          P_BOOK               IN     VARCHAR2,
                          P_PERIOD             IN     VARCHAR2,
                          P_COST_CENTER        IN     VARCHAR2,
                          P_MAJOR_CATEGORY     IN     VARCHAR2,
                          P_MINOR_CATEGORY     IN     VARCHAR2,
                          P_ASSET_COST_GROUP   IN     VARCHAR2,
                          P_GRAND_TOTAL_BY     IN     VARCHAR2,
                          P_CURRENCY           IN     NUMBER,
                          P_PROJECT_TYPE       IN     VARCHAR2,  -- CCR0008086
                          p_file_path          IN     VARCHAR2)
    AS
        V_NUM                           NUMBER;
        V_SUPPLIER                      VARCHAR2 (100);
        V_PROJECT_ID                    NUMBER;
        V_PROJECT_NUMBER                VARCHAR2 (25);
        V_COST                          NUMBER;
        V_CURRENT_PERIOD_DEPRECIATION   NUMBER;
        V_ENDING_DPERECIATION_RESERVE   NUMBER;
        V_NET_BOOK_VALUE                NUMBER;
        V_REPORT_DATE                   VARCHAR2 (30);
        V_ASSET_COUNT                   NUMBER;
        V_PRIOR_YEAR                    NUMBER;
        V_BEGINING_YR_DEPRN             NUMBER;
        V_YTD_DEPRN_TRANSFER            NUMBER;
        V_YTD_DEPRN                     NUMBER;
        V_COST_TOTAL                    NUMBER;
        V_CURRENT_PERIOD_DEPRN_TOTAL    NUMBER;
        V_YTD_DEPRN_TOTAL               NUMBER;
        V_ENDING_DEPRN_RESERVE_TOTAL    NUMBER;
        V_NET_BOOK_VALUE_TOTAL          NUMBER;
        V_BEGIN_YR_DEPRN_TOTAL          NUMBER;
        V_ENDING_TOTAL                  NUMBER;
        V_CUSTODIAN                     VARCHAR2 (50);
        V_LOCATION_ID                   NUMBER;
        V_LOCATION_FLEXFIELD            VARCHAR2 (200);
        V_DEPRECIATION_ACCOUNT          VARCHAR2 (100);
        V_NULL_COUNT                    NUMBER := 0;
        --V_ASSET_NUM                     NUMBER;
        V_ASSET_NUM                     VARCHAR2 (100);
        -- ADDED BY BT TECHNOLOGY TEAM
        V_PERIOD_FROM                   VARCHAR2 (20);
        V_USER_ENV                      VARCHAR2 (100);
        V_STRING                        VARCHAR2 (50);
        V_SET_USER_ENV                  VARCHAR2 (300);
        --      V_IMPAIRMENT_AMOUNT             NUMBER;
        V_ASSET_RESERVE_ACCOUNT         VARCHAR2 (50);
        V_ASSET_ACCOUNT                 VARCHAR2 (50);
        V_ASSET_RSV_ACCOUNT_NULL        VARCHAR2 (50); --for Defect 701,Dt 04-Dec-15,By BT Technology Team,V1.4
        V_ENDING_DEPR_RESERVE           NUMBER;
        V_DEPRECIATION_ACCOUNT_NEW      VARCHAR2 (100);
        V_ASSET_CATEGORY                VARCHAR2 (200);
        ln_asset_id                     NUMBER;

        -- p_file_path varchar2(100);

        CURSOR C_HEADER (CP_BOOK IN VARCHAR2, -- P_PERIOD           IN  VARCHAR2,
                                              P_CURRENCY IN VARCHAR2, P_ASSET_COST_GROUP IN VARCHAR2, P_MAJOR_CATEGORY IN VARCHAR2, P_MINOR_CATEGORY IN VARCHAR2, P_COST_CENTER IN VARCHAR2
                         , P_PROJECT_TYPE IN VARCHAR2)
        IS
            SELECT ASSET_CATEGORY_ATTRIB1 BRAND, ASSET_COST_SEGMENT2, ASSET_COST_SEGMENT4,
                   ASSET_COST_GROUP, ASSET_CATEGORY_COST_GROUP, ASSET_COST_SEGMENT3,
                   ASSET_CATEGORY, ASSET_TYPE, TO_CHAR (START_DATE, 'DD-MON-YYYY') DATE_PLACED_IN_SERVICE,
                   ASSET_NUMBER, NVL (T_TYPE, 'A') T_TYPE, DESCRIPTION,
                   ASSET_EXP_DEPT, ASSET_COST_ACCOUNT ASSET_ACCOUNT, ASSET_EXP_ACCOUNT DEPRECIATION_ACCOUNT,
                   BOOK_TYPE_CODE, METHOD DEPRN_METHOD, TRUNC (LIFE / 12) || '.' || TRUNC (MOD (LIFE, 12)) LIFE_YR,
                   /* ROUND (LIFE / 12, 2) LIFE_YR, */
                            --LOGIC CHANGE ON 19JUNE2015 BY BT TECHNOLOGY TEAM
                   ADJ_RATE, BONUS_RATE, PROD,
                   COST, BEGIN_YEAR_DEPRECIATION, DEPRN_AMOUNT CURRENT_PERIOD_DEPRECIATION,
                   YTD_DEPRN, DEPRN_RESERVE ENDING_DPERECIATION_RESERVE, NET_BOOK_VALUE,
                   PERCENT, CCID, T_TYPE_A,
                   ASSET_TAG_NUMBER, ASSET_SERIAL_NUMBER, ASSET_RESERVE_ACCOUNT,
                   ASSET_CC, ASSET_ACCT, ASSET_BRAND
              FROM (  SELECT FC.ATTRIBUTE1 ASSET_CATEGORY_ATTRIB1, CC_COST.SEGMENT2 ASSET_COST_SEGMENT2, CC_COST.SEGMENT4 ASSET_COST_SEGMENT4,
                             FC.SEGMENT1 || '.' || FC.SEGMENT2 || '.' || FC.SEGMENT3 ASSET_COST_GROUP, CC_COST.SEGMENT2 || '.' || CC_COST.SEGMENT4 || '.' || ' ' || FC.SEGMENT3 ASSET_CATEGORY_COST_GROUP, CC_COST.SEGMENT3 ASSET_COST_SEGMENT3,
                             FC.SEGMENT1 ASSET_CATEGORY, AD.ASSET_TYPE ASSET_TYPE, DATE_PLACED_IN_SERVICE START_DATE,
                             AD.ASSET_NUMBER, RSV.TRANSACTION_TYPE T_TYPE, AD.DESCRIPTION,
                             (CC.SEGMENT2 || '.' || CC.SEGMENT4) ASSET_EXP_DEPT, CC_COST.CONCATENATED_SEGMENTS ASSET_COST_ACCOUNT, CC.CONCATENATED_SEGMENTS ASSET_EXP_ACCOUNT,
                             DS.BOOK_TYPE_CODE BOOK_TYPE_CODE, METHOD_CODE METHOD, RSV.LIFE LIFE,
                             RSV.RATE ADJ_RATE, DS.BONUS_RATE BONUS_RATE, RSV.CAPACITY PROD,
                             SUM (DECODE (RSV.TRANSACTION_TYPE, 'B', NULL, COST)) COST, NVL (SUM (RSV.DEPRN_RESERVE), 0) - NVL (SUM (RSV.YTD_DEPRN), 0) BEGIN_YEAR_DEPRECIATION, SUM (RSV.DEPRN_AMOUNT) DEPRN_AMOUNT,
                             SUM (RSV.YTD_DEPRN) YTD_DEPRN, SUM (RSV.DEPRN_RESERVE) DEPRN_RESERVE, SUM (DECODE (RSV.TRANSACTION_TYPE, 'B', NULL, COST)) - SUM (RSV.DEPRN_RESERVE) NET_BOOK_VALUE,
                             SUM (DECODE (RSV.TRANSACTION_TYPE, 'B', NULL, NVL (PERCENT, 0))) PERCENT, RSV.DH_CCID CCID, DECODE (RSV.TRANSACTION_TYPE, '', 'Y', 'N') T_TYPE_A,
                             AD.TAG_NUMBER ASSET_TAG_NUMBER, AD.SERIAL_NUMBER ASSET_SERIAL_NUMBER, CC_RESERVE.CONCATENATED_SEGMENTS ASSET_RESERVE_ACCOUNT,
                             CC_COST.SEGMENT5 ASSET_CC, CC_COST.SEGMENT6 ASSET_ACCT, FC.SEGMENT3 ASSET_BRAND
                        FROM XXDO.XXDO_FA_RESERVE_LEDGER_GT RSV, --Start modificaion for Defect 701,Dt 30-Nov-15,By BT Technology Team,V1.2
                                                                 FA_TRANSACTION_HISTORY_TRX_V FTHT, FA_TRANSACTION_HEADERS FTH,
                             --End modificaion for Defect 701,Dt 30-Nov-15,By BT Technology Team,V1.2
                             FA_ADDITIONS AD, FA_CATEGORIES FC, FA_CATEGORY_BOOKS FCB,
                             GL_CODE_COMBINATIONS_KFV CC, GL_CODE_COMBINATIONS_KFV CC_COST, FA_DEPRN_SUMMARY DS,
                             GL_CODE_COMBINATIONS_KFV CC_RESERVE
                       WHERE     --Start modificaion for Defect 701,Dt 30-Nov-15,By BT Technology Team,V1.2
                                 --RSV.ASSET_ID = AD.ASSET_ID
                                 -- AND AD.ASSET_CATEGORY_ID = FC.CATEGORY_ID
                                 RSV.ASSET_ID = ftht.ASSET_ID
                             AND fth.transaction_header_id =
                                 ftht.transaction_header_id
                             AND fth.transaction_header_id IN
                                     (SELECT MAX (ftht.transaction_header_id)
                                        FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                                                                                            fa_adjustments fa,
                                             --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                             xla_events xe
                                       WHERE     ftht.period_counter <=
                                                 (SELECT fdp.period_counter
                                                    FROM fa_deprn_periods fdp
                                                   WHERE     fdp.book_type_code =
                                                             p_book
                                                         AND fdp.period_name =
                                                             p_period)
                                             AND fth.transaction_header_id =
                                                 ftht.transaction_header_id
                                             --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                             AND fth.transaction_header_id =
                                                 fa.transaction_header_id
                                             AND fa.adjustment_type = 'COST'
                                             --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                             AND fth.event_id IS NOT NULL
                                             AND xe.event_id = fth.event_id
                                             AND xe.EVENT_STATUS_CODE <> 'N'
                                             AND ftht.asset_id = AD.asset_id)
                             AND ftht.CATEGORY_ID = FC.CATEGORY_ID
                             --End modificaion for Defect 701,Dt 30-Nov-15,By BT Technology Team,V1.2
                             AND FC.CATEGORY_ID = FCB.CATEGORY_ID
                             AND FCB.BOOK_TYPE_CODE = DS.BOOK_TYPE_CODE
                             AND FCB.ASSET_COST_ACCOUNT_CCID =
                                 CC_COST.CODE_COMBINATION_ID(+)
                             AND FCB.RESERVE_ACCOUNT_CCID =
                                 CC_RESERVE.CODE_COMBINATION_ID(+)
                             AND RSV.DH_CCID = CC.CODE_COMBINATION_ID
                             AND DS.PERIOD_COUNTER(+) = RSV.PERIOD_COUNTER
                             AND DS.BOOK_TYPE_CODE(+) = P_BOOK
                             AND DS.ASSET_ID(+) = RSV.ASSET_ID
                             AND FC.SEGMENT3 =
                                 NVL (P_ASSET_COST_GROUP, FC.SEGMENT3)
                             AND FC.SEGMENT1 =
                                 NVL (P_MAJOR_CATEGORY, FC.SEGMENT1)
                             AND FC.SEGMENT2 =
                                 NVL (P_MINOR_CATEGORY, FC.SEGMENT2)
                             AND ((fc.attribute2 = p_project_type) OR (fc.attribute2 IS NULL AND p_project_type = 'Non Special') OR (1 = 1 AND NVL (p_project_type, 'All') = 'All')) --CCR0008086
                    --                      AND CC_COST.SEGMENT5 =
                    --                                         NVL (P_COST_CENTER, CC_COST.SEGMENT5)----REMOVED BY BT TECHNOLOGY ON 06-FEB-2015 AND LOGIC HANDELED IN XML
                    GROUP BY FC.ATTRIBUTE1, CC_COST.SEGMENT2, CC_COST.SEGMENT4,
                             FC.SEGMENT1, FC.SEGMENT2, FC.SEGMENT3,
                             CC_COST.SEGMENT3, FC.SEGMENT1, AD.ASSET_TYPE,
                             CC_COST.SEGMENT2 || '.' || CC_COST.SEGMENT4 || '.' || ' ' || FC.SEGMENT3, DATE_PLACED_IN_SERVICE, AD.ASSET_NUMBER,
                             RSV.TRANSACTION_TYPE, (CC.SEGMENT2 || '.' || CC.SEGMENT4), CC.CONCATENATED_SEGMENTS,
                             CC_COST.CONCATENATED_SEGMENTS, DS.BOOK_TYPE_CODE, AD.DESCRIPTION,
                             RSV.METHOD_CODE, RSV.LIFE, RSV.RATE,
                             RSV.CAPACITY, DS.BONUS_RATE, RSV.DH_CCID,
                             RSV.TRANSACTION_TYPE, AD.TAG_NUMBER, AD.SERIAL_NUMBER,
                             CC_RESERVE.CONCATENATED_SEGMENTS, CC_COST.SEGMENT5, CC_COST.SEGMENT6
                    ORDER BY 1, 2, 3,
                             4, 5, 6,
                             7, 8, 9,
                             10, 11)
             WHERE ((NVL (COST, 0) <> 0 OR NVL (DEPRN_AMOUNT, 0) <> 0 OR NVL (YTD_DEPRN, 0) <> 0) OR T_TYPE = 'F');

        CURSOR C_OUTPUT IS
              SELECT BOOK, PERIOD, ASSET_CATEGORY_TYPE,
                     ASSET_CATEGORY_COST_GROUP, ASSET_TYPE, ASSET_ACCOUNT,
                     ASSET_NUMBER, ASSET_DESCRIPTION, SUPPLIER,
                     CUSTODIAN, DATE_PLACED_IN_SERVICE, DEPRN_METHOD,
                     LIFE_YR_MO, SUM (COST) COST, SUM (BEGIN_YEAR_DEPR_RESERVE) BEGIN_YEAR_DEPR_RESERVE,
                     SUM (CURRENT_PERIOD_DEPRECIATION) CURRENT_PERIOD_DEPRECIATION, SUM (YTD_DEPRECIATION) YTD_DEPRECIATION, SUM (ENDING_DEPR_RESERVE) ENDING_DEPR_RESERVE,
                     SUM (NET_BOOK_VALUE) NET_BOOK_VALUE, DEPRECIATION_ACCOUNT, LOCATION_FLEXFIELD,
                     T_TYPE_A, ASSET_TAG_NUMBER, ASSET_SERIAL_NUMBER,
                     ASSET_RESERVE_ACCOUNT, PROJECT_NUMBER, ASSET_CC,
                     ASSET_ACCT, ASSET_BRAND
                FROM XXDO.XXDO_FA_RESERVE_LOCATION_REP
            GROUP BY BOOK, PERIOD, ASSET_CATEGORY_TYPE,
                     ASSET_CATEGORY_COST_GROUP, ASSET_TYPE, ASSET_ACCOUNT,
                     ASSET_NUMBER, ASSET_DESCRIPTION, SUPPLIER,
                     CUSTODIAN, DATE_PLACED_IN_SERVICE, DEPRN_METHOD,
                     LIFE_YR_MO, DEPRECIATION_ACCOUNT, LOCATION_FLEXFIELD,
                     T_TYPE_A, ASSET_TAG_NUMBER, ASSET_SERIAL_NUMBER,
                     ASSET_RESERVE_ACCOUNT, PROJECT_NUMBER, ASSET_CC,
                     ASSET_ACCT, ASSET_BRAND
            ORDER BY ASSET_NUMBER ASC;
    BEGIN
        --      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXDO_FA_RESERVE_LOCATION_REP';

        --      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXDO_FA_RESERVE_LOCATION_REP_X';
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_book:' || P_BOOK);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_period:' || P_PERIOD);
        --START CHANGES BY BT TECHNOLOGY TEAM ON 28-OCT-2014 - V1.1
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'p_currency:' || P_CURRENCY);

        SELECT USERENV ('CLIENT_INFO') INTO V_USER_ENV FROM DUAL;

        SELECT SUBSTR (V_USER_ENV, 0, 44) INTO V_STRING FROM DUAL;

        V_SET_USER_ENV   := V_STRING || P_CURRENCY;
        --       SELECT SUBSTR(V_USER_ENV,55) INTO V_STRING FROM DUAL;
        --
        --       V_SET_USER_ENV := V_SET_USER_ENV || V_STRING;
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'v_set_user_env:' || V_SET_USER_ENV);
        DBMS_APPLICATION_INFO.SET_CLIENT_INFO (V_SET_USER_ENV);

        SELECT TO_NUMBER (SUBSTR (USERENV ('CLIENT_INFO'), 45, 10))
          INTO V_STRING
          FROM DUAL;

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'v_string:' || V_STRING);
        --END CHANGES BY BT TECHNOLOGY TEAM ON 28-OCT-2014 - V1.1
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'before call fa_rsvldg_proc');
        /*RUN FA_RSVLDG_PROC*/
        XXDO_FA_ASSET_RSV_PKG.FA_RSVLDG_PROC (P_BOOK, P_PERIOD);
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.LOG,
            'after call fa_rsvldg_proc insert xxdo_fa_reserve_ledger_gt');

        BEGIN
            SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
              INTO V_REPORT_DATE
              FROM SYS.DUAL;
        END;

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'v_report_date ' || V_REPORT_DATE);

        --      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXDO_FA_BALANCES_REPORT_GT';
        SELECT PERIOD_NAME
          INTO V_PERIOD_FROM
          FROM FA_DEPRN_PERIODS
         WHERE     BOOK_TYPE_CODE = P_BOOK
               AND FISCAL_YEAR =
                   (SELECT FISCAL_YEAR
                      FROM FA_DEPRN_PERIODS
                     WHERE BOOK_TYPE_CODE = P_BOOK AND PERIOD_NAME = P_PERIOD)
               AND PERIOD_NUM = (SELECT MIN (PERIOD_NUM)
                                   FROM FA_DEPRN_PERIODS
                                  WHERE BOOK_TYPE_CODE = P_BOOK);

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'v_period_from ' || V_PERIOD_FROM);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'before call of insert_info ');
        INSERT_INFO (BOOK => P_BOOK, START_PERIOD_NAME => V_PERIOD_FROM, END_PERIOD_NAME => P_PERIOD
                     , REPORT_TYPE => 'RESERVE');
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'after call of insert_info ');
        V_NULL_COUNT     := 0;

        FOR CREC IN C_HEADER (CP_BOOK => P_BOOK, -- P_PERIOD           IN  VARCHAR2,
                                                 P_CURRENCY => P_CURRENCY, P_ASSET_COST_GROUP => P_ASSET_COST_GROUP, P_MAJOR_CATEGORY => P_MAJOR_CATEGORY, P_MINOR_CATEGORY => P_MINOR_CATEGORY, P_COST_CENTER => P_COST_CENTER
                              , P_PROJECT_TYPE => P_PROJECT_TYPE)
        LOOP
            V_PROJECT_ID             := NULL;
            V_PROJECT_NUMBER         := NULL;
            V_SUPPLIER               := NULL;
            V_CUSTODIAN              := NULL;
            V_LOCATION_ID            := NULL;
            V_LOCATION_FLEXFIELD     := NULL;
            V_DEPRECIATION_ACCOUNT   := NULL;

            BEGIN
                --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                /*SELECT PER.GLOBAL_NAME CUSTODIAN, LOC.LOCATION_ID,
                          LOC.SEGMENT1
                       || '.'
                       || LOC.SEGMENT2
                       || '.'
                       || LOC.SEGMENT3
                       || '.'
                       || LOC.SEGMENT4
                       || '.'
                       || LOC.SEGMENT5 LOCATION_FLEXFIELD,
    --                       GCC.SEGMENT1
    --                   || '.'
    --                   || GCC.SEGMENT2
    --                   || '.'
    --                   || GCC.SEGMENT3
    --                   || '.'
    --                   || GCC.SEGMENT4
    --                      DEPRECIATION_ACCOUNT
                       GCC.CONCATENATED_SEGMENTS DEPRECIATION_ACCOUNT
                  --MODIFIED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                INTO   V_CUSTODIAN, V_LOCATION_ID,
                       V_LOCATION_FLEXFIELD,
                       V_DEPRECIATION_ACCOUNT
                  FROM APPS.FA_DISTRIBUTION_HISTORY DH,
                       APPS.GL_CODE_COMBINATIONS_KFV GCC,
                       APPS.PER_PEOPLE_F PER,
                       APPS.FA_LOCATIONS LOC,
                       APPS.FA_ADDITIONS FAD
                                     --ADDED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
    --             WHERE     DH.ASSET_ID = CREC.ASSET_NUMBER----CODE DISABLE BY BT TECHNOLOGY TEAM ON 12-JAN-2015
    --START CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                WHERE  DH.ASSET_ID = FAD.ASSET_ID
                   AND FAD.ASSET_NUMBER = CREC.ASSET_NUMBER
    --END CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                   AND DH.BOOK_TYPE_CODE = P_BOOK
                   AND LOC.LOCATION_ID = DH.LOCATION_ID
                   AND DH.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                   -- AND GCC.CODE_COMBINATION_ID = CREC.CCID-- REMOVED BY BT TECHNOLOGY TEAM ON  15-JAN-2015
                   AND DH.DATE_INEFFECTIVE IS NULL
                   AND DH.ASSIGNED_TO = PER.PERSON_ID(+)
                   AND TRUNC (SYSDATE) BETWEEN NVL (PER.EFFECTIVE_START_DATE,
                                                    TRUNC (SYSDATE)
                                                   )
                                           AND NVL (PER.EFFECTIVE_END_DATE,
                                                    TRUNC (SYSDATE)
                                                   )
                   AND ROWNUM = 1;*/
                SELECT asset_id
                  INTO ln_asset_id
                  FROM fa_additions
                 WHERE asset_number = CREC.ASSET_NUMBER;

                SELECT PER.GLOBAL_NAME CUSTODIAN, LOC.LOCATION_ID, LOC.SEGMENT1 || '.' || LOC.SEGMENT2 || '.' || LOC.SEGMENT3 || '.' || LOC.SEGMENT4 || '.' || LOC.SEGMENT5 LOCATION_FLEXFIELD,
                       GCC.CONCATENATED_SEGMENTS DEPRECIATION_ACCOUNT
                  INTO V_CUSTODIAN, V_LOCATION_ID, V_LOCATION_FLEXFIELD, V_DEPRECIATION_ACCOUNT
                  FROM fa_distribution_history fdh, GL_CODE_COMBINATIONS_KFV GCC, PER_PEOPLE_F PER,
                       FA_LOCATIONS LOC
                 WHERE     loc.location_id = fdh.location_id
                       AND fdh.code_combination_id = gcc.code_combination_id
                       AND fdh.assigned_to = per.person_id(+)
                       /*Start Change as part of Version 1.7*/
                       AND fdh.code_combination_id = CREC.CCID
                       /*Begin Modification for CCR0007352, as part of Version 1.9*/
                       AND fdh.transaction_header_id_in =
                           (SELECT MAX (ftht.transaction_header_id)
                              --  AND fdh.transaction_header_id_in =
                              --         (SELECT ftht.transaction_header_id
                              /*End Modification for CCR0007352, as part of Version 1.9*/
                              /*End Change as part of Version 1.7*/
                              FROM fa_transaction_history_trx_v ftht
                             WHERE     ftht.period_counter <=
                                       (SELECT fdp.period_counter
                                          FROM fa_deprn_periods fdp
                                         WHERE     fdp.book_type_code =
                                                   P_BOOK
                                               AND fdp.period_name = P_PERIOD)
                                   AND ftht.transaction_header_id IN
                                           (SELECT fth1.transaction_header_id
                                              FROM FA_TRANSACTION_HEADERS fth1, fa_distribution_history fdh
                                             WHERE     fth1.transaction_header_id =
                                                       fdh.transaction_header_id_in
                                                   AND fdh.code_combination_id =
                                                       CREC.CCID -- Added as part of Ver 1.7
                                                   AND fdh.asset_id =
                                                       ln_asset_id))
                       AND ROWNUM < 2 --Added this condition for CCR0007352, as part of Version 1.9
                                     ;
            --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    V_CUSTODIAN              := NULL;
                    V_LOCATION_ID            := NULL;
                    V_LOCATION_FLEXFIELD     := NULL;
                    V_DEPRECIATION_ACCOUNT   := NULL;
                WHEN OTHERS
                THEN
                    V_CUSTODIAN              := NULL;
                    V_LOCATION_ID            := NULL;
                    V_LOCATION_FLEXFIELD     := NULL;
                    V_DEPRECIATION_ACCOUNT   := NULL;
            END;

            /* GET SUPPLIER*/
            BEGIN
                ---DISABLED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                --         SELECT VENDOR_NAME, PROJECT_ID
                --              INTO V_SUPPLIER, V_PROJECT_ID
                --              FROM FA_INVOICE_DETAILS_V
                --             WHERE ASSET_ID = CREC.ASSET_NUMBER
                --             AND INVOICE_LINE_NUMBER = 1;

                --START CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                SELECT FAV.VENDOR_NAME, FAV.PROJECT_ID
                  INTO V_SUPPLIER, V_PROJECT_ID
                  FROM FA_INVOICE_DETAILS_V FAV, APPS.FA_ADDITIONS FAD, FA_BOOKS FAB
                 WHERE     FAV.ASSET_ID = FAD.ASSET_ID
                       AND FAD.ASSET_ID = FAB.ASSET_ID
                       AND FAB.BOOK_TYPE_CODE = P_BOOK
                       AND FAD.ASSET_NUMBER = CREC.ASSET_NUMBER
                       AND INVOICE_LINE_NUMBER = 1
                       AND ROWNUM = 1;
            --END CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    V_SUPPLIER     := NULL;
                    V_PROJECT_ID   := NULL;
                WHEN OTHERS
                THEN
                    V_SUPPLIER     := NULL;
                    V_PROJECT_ID   := NULL;
            END;

            IF V_PROJECT_ID IS NOT NULL
            THEN
                BEGIN
                    SELECT SEGMENT1
                      INTO V_PROJECT_NUMBER
                      FROM PA_PROJECTS_ALL
                     WHERE PROJECT_ID = V_PROJECT_ID;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        V_PROJECT_NUMBER   := NULL;
                    WHEN OTHERS
                    THEN
                        V_PROJECT_NUMBER   := NULL;
                END;
            END IF;

            BEGIN
                INSERT INTO XXDO.XXDO_FA_RESERVE_LOCATION_REP (
                                BOOK,
                                PERIOD,
                                ASSET_CATEGORY_TYPE,
                                ASSET_CATEGORY_COST_GROUP,
                                ASSET_TYPE,
                                ASSET_ACCOUNT,
                                ASSET_NUMBER,
                                ASSET_DESCRIPTION,
                                SUPPLIER,
                                CUSTODIAN,
                                DATE_PLACED_IN_SERVICE,
                                DEPRN_METHOD,
                                LIFE_YR_MO,
                                COST,
                                BEGIN_YEAR_DEPR_RESERVE,
                                CURRENT_PERIOD_DEPRECIATION,
                                YTD_DEPRECIATION,
                                ENDING_DEPR_RESERVE,
                                NET_BOOK_VALUE,
                                DEPRECIATION_ACCOUNT,
                                LOCATION_FLEXFIELD,
                                TRANSACTION_TYPE,
                                T_TYPE_A,
                                ASSET_TAG_NUMBER,
                                ASSET_SERIAL_NUMBER,
                                PROJECT_NUMBER,
                                ASSET_RESERVE_ACCOUNT,
                                ASSET_CC,
                                ASSET_ACCT,
                                ASSET_BRAND)
                         VALUES (P_BOOK,
                                 P_PERIOD,
                                 CREC.ASSET_COST_GROUP,
                                 CREC.ASSET_CATEGORY_COST_GROUP,
                                 CREC.ASSET_TYPE,
                                 CREC.ASSET_ACCOUNT,
                                 CREC.ASSET_NUMBER,
                                 CREC.DESCRIPTION,
                                 V_SUPPLIER,
                                 V_CUSTODIAN,
                                 CREC.DATE_PLACED_IN_SERVICE,
                                 CREC.DEPRN_METHOD,
                                 CREC.LIFE_YR,
                                 CREC.COST,
                                 CREC.BEGIN_YEAR_DEPRECIATION,
                                 CREC.CURRENT_PERIOD_DEPRECIATION,
                                 CREC.YTD_DEPRN,
                                 CREC.ENDING_DPERECIATION_RESERVE,
                                 CREC.NET_BOOK_VALUE,
                                 CREC.DEPRECIATION_ACCOUNT,
                                 V_LOCATION_FLEXFIELD,
                                 CREC.T_TYPE,
                                 CREC.T_TYPE_A,
                                 CREC.ASSET_TAG_NUMBER,
                                 CREC.ASSET_SERIAL_NUMBER,
                                 V_PROJECT_NUMBER,
                                 CREC.ASSET_RESERVE_ACCOUNT,
                                 CREC.ASSET_CC,
                                 CREC.ASSET_ACCT,
                                 CREC.ASSET_BRAND);
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Error while inserting into XXDO_FA_RESERVE_LOCATION_REP'
                        || SQLERRM);
            END;
        -- COMMIT;---1
        END LOOP;

        UPDATE XXDO.XXDO_FA_RESERVE_LOCATION_REP A
           SET T_TYPE_A   = 'Y'
         WHERE     1 = 1
               AND EXISTS
                       (SELECT NULL
                          FROM XXDO.XXDO_FA_RESERVE_LOCATION_REP B
                         WHERE     A.ASSET_NUMBER = B.ASSET_NUMBER
                               AND B.T_TYPE_A = 'Y');

        FOR I IN C_OUTPUT
        LOOP
            --         V_IMPAIRMENT_AMOUNT := 0;
            V_ASSET_RESERVE_ACCOUNT      := NULL;
            V_ASSET_ACCOUNT              := NULL;
            V_ENDING_DEPR_RESERVE        := 0;
            V_DEPRECIATION_ACCOUNT_NEW   := NULL;

            BEGIN
                --DISABLED  BY BT TECHNOLOGY TEAM ON  12-JAN-2015

                --            SELECT SUM (AMOUNT)
                --              INTO V_ENDING_TOTAL
                --              FROM XXDO.XXDO_FA_BALANCES_REPORT_GT
                --             WHERE ASSET_ID = I.ASSET_NUMBER AND SOURCE_TYPE_CODE = 'END';

                --START CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                SELECT NVL (SUM (NVL (XGT.AMOUNT, 0)), 0)
                  INTO V_ENDING_TOTAL
                  FROM XXDO.XXDO_FA_BALANCES_REPORT_GT XGT, APPS.FA_ADDITIONS FAD, FA_BOOKS FAB
                 --             WHERE ASSET_ID = I.ASSET_NUMBER
                 WHERE     XGT.ASSET_ID = FAD.ASSET_ID
                       AND FAD.ASSET_ID = FAB.ASSET_ID
                       AND FAB.BOOK_TYPE_CODE = P_BOOK
                       AND FAD.ASSET_NUMBER = I.ASSET_NUMBER
                       AND XGT.SOURCE_TYPE_CODE = 'END';
            --END CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    V_ENDING_TOTAL   := NULL;
                WHEN OTHERS
                THEN
                    V_ENDING_TOTAL   := NULL;
            END;

            BEGIN
                SELECT SUM (NVL (COST, 0)), --SUM(CURRENT_PERIOD_DEPRECIATION),
                                            SUM (NVL (ENDING_DEPR_RESERVE, 0)), SUM (NVL (NET_BOOK_VALUE, 0)),
                       SUM (NVL (YTD_DEPRECIATION, 0))
                  --,SUM(ENDING_DEPR_RESERVE)-SUM(YTD_DEPRECIATION)   /*MODIFIED BY MURALI 07/29*/
                  INTO V_COST_TOTAL, V_ENDING_DEPRN_RESERVE_TOTAL, V_NET_BOOK_VALUE_TOTAL, V_YTD_DEPRN_TOTAL
                  FROM XXDO.XXDO_FA_RESERVE_LOCATION_REP
                 WHERE ASSET_NUMBER = I.ASSET_NUMBER;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    V_COST_TOTAL                   := NULL;
                    V_ENDING_DEPRN_RESERVE_TOTAL   := NULL;
                    V_NET_BOOK_VALUE_TOTAL         := NULL;
                    V_YTD_DEPRN_TOTAL              := NULL;
                WHEN OTHERS
                THEN
                    V_COST_TOTAL                   := NULL;
                    V_ENDING_DEPRN_RESERVE_TOTAL   := NULL;
                    V_NET_BOOK_VALUE_TOTAL         := NULL;
                    V_YTD_DEPRN_TOTAL              := NULL;
            END;

            SELECT FISCAL_YEAR - 1
              INTO V_PRIOR_YEAR
              FROM FA_DEPRN_PERIODS
             WHERE     PERIOD_NAME = P_PERIOD
                   AND BOOK_TYPE_CODE = P_BOOK
                   AND ROWNUM = 1;

            BEGIN
                --DISABLED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                --            SELECT SUM (AMOUNT)
                --              INTO V_BEGIN_YR_DEPRN_TOTAL
                --              FROM XXDO.XXDO_FA_BALANCES_REPORT_GT
                --             WHERE ASSET_ID = I.ASSET_NUMBER AND SOURCE_TYPE_CODE = 'BEGIN';

                --START CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                SELECT NVL (SUM (NVL (XGT.AMOUNT, 0)), 0)
                  INTO V_BEGIN_YR_DEPRN_TOTAL
                  FROM XXDO.XXDO_FA_BALANCES_REPORT_GT XGT, APPS.FA_ADDITIONS FAD, FA_BOOKS FAB
                 --             WHERE ASSET_ID = I.ASSET_NUMBER
                 WHERE     XGT.ASSET_ID = FAD.ASSET_ID
                       AND FAD.ASSET_ID = FAB.ASSET_ID
                       AND FAB.BOOK_TYPE_CODE = P_BOOK
                       AND FAD.ASSET_NUMBER = I.ASSET_NUMBER
                       AND FAB.DATE_INEFFECTIVE IS NULL -- Added for 1.5 by Infosys team. 02-Jun-2016.
                       AND XGT.SOURCE_TYPE_CODE = 'BEGIN';

                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'begin value 700:'
                    || I.ASSET_NUMBER
                    || ':'
                    || V_BEGIN_YR_DEPRN_TOTAL);
            --END CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
            EXCEPTION
                WHEN OTHERS
                THEN
                    SELECT SUM (NVL (FV.TOTAL_DEPRN_AMOUNT, 0))
                      INTO V_BEGIN_YR_DEPRN_TOTAL
                      FROM FA_FINANCIAL_INQUIRY_DEPRN_V FV, FA_DEPRN_PERIODS FDP
                     --                WHERE FV.ASSET_ID = I.ASSET_NUMBER--DISABLED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                     WHERE     FV.ASSET_NUMBER = I.ASSET_NUMBER
                           --ADDED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                           AND FDP.BOOK_TYPE_CODE = FV.BOOK_TYPE_CODE
                           AND FV.BOOK_TYPE_CODE = P_BOOK
                           AND FV.PERIOD_ENTERED = FDP.PERIOD_NAME
                           AND FDP.FISCAL_YEAR = V_PRIOR_YEAR;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'begin value 720' || V_BEGIN_YR_DEPRN_TOTAL);
            END;

            IF I.T_TYPE_A = 'Y'
            THEN
                IF V_ASSET_NUM IS NULL
                THEN
                    V_ASSET_NUM   := I.ASSET_NUMBER;
                ELSE
                    IF V_ASSET_NUM = I.ASSET_NUMBER
                    THEN
                        V_COST_TOTAL                   := 0;
                        V_ENDING_DEPRN_RESERVE_TOTAL   := 0;
                        V_NET_BOOK_VALUE_TOTAL         := 0;
                        V_YTD_DEPRN_TOTAL              := 0;
                        V_BEGIN_YR_DEPRN_TOTAL         := 0;
                        V_ENDING_TOTAL                 := 0;
                    ELSE
                        V_ASSET_NUM   := I.ASSET_NUMBER;
                    END IF;
                END IF;
            ELSIF I.T_TYPE_A = 'N'
            THEN
                IF V_ASSET_NUM IS NULL
                THEN
                    V_ASSET_NUM   := I.ASSET_NUMBER;
                ELSE
                    IF V_ASSET_NUM = I.ASSET_NUMBER
                    THEN
                        V_COST_TOTAL                   := 0;
                        V_ENDING_DEPRN_RESERVE_TOTAL   := 0;
                        V_NET_BOOK_VALUE_TOTAL         := 0;
                        V_YTD_DEPRN_TOTAL              := 0;
                        V_BEGIN_YR_DEPRN_TOTAL         := 0;
                        V_ENDING_TOTAL                 := 0;
                    ELSE
                        V_ASSET_NUM   := I.ASSET_NUMBER;
                    END IF;
                END IF;
            END IF;

            --START CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015--
            /*"IMPAIRMENT RESERVE", FETCH*/
            -- DISABLE BY BT TECHNOLOGY TEAM ON  16-JAN-2015--HANDELED IN XML
            --         BEGIN
            --            SELECT NVL (SUM (NVL (IMP.IMPAIRMENT_AMOUNT, 0)), 0)
            --              INTO V_IMPAIRMENT_AMOUNT
            --              FROM FA_IMPAIRMENTS IMP, FA_ADDITIONS_B AD
            --             WHERE IMP.ASSET_ID = AD.ASSET_ID
            --               AND IMP.BOOK_TYPE_CODE = P_BOOK
            --               AND AD.ASSET_NUMBER = I.ASSET_NUMBER
            --               AND IMP.PERIOD_COUNTER_IMPAIRED <=
            --                      (SELECT PERIOD_COUNTER
            --                         FROM FA_DEPRN_PERIODS
            --                        WHERE BOOK_TYPE_CODE = P_BOOK
            --                          AND PERIOD_NAME = P_PERIOD);
            --         EXCEPTION
            --            WHEN OTHERS
            --            THEN
            --               V_IMPAIRMENT_AMOUNT := 0;
            --         END;

            --          V_ENDING_DEPR_RESERVE :=       NVL (V_BEGIN_YR_DEPRN_TOTAL, 0)
            --                 + NVL (I.YTD_DEPRECIATION, 0);
            IF     NVL (V_NET_BOOK_VALUE_TOTAL, 0) <> 0
               AND NVL (V_COST_TOTAL, 0) <> 0
            THEN
                V_ENDING_DEPR_RESERVE   :=
                    NVL (V_COST_TOTAL, 0) - NVL (V_NET_BOOK_VALUE_TOTAL, 0);
            ELSE
                IF     NVL (V_NET_BOOK_VALUE_TOTAL, 0) = 0
                   AND NVL (V_COST_TOTAL, 0) <> 0
                THEN
                    V_ENDING_DEPR_RESERVE   := NVL (V_COST_TOTAL, 0);
                ELSE
                    V_ENDING_DEPR_RESERVE   := NVL (I.YTD_DEPRECIATION, 0);
                END IF;
            END IF;

            BEGIN
                --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                /*  SELECT GCC.CONCATENATED_SEGMENTS
                    INTO V_DEPRECIATION_ACCOUNT_NEW
                    FROM FA_DISTRIBUTION_HISTORY FDH,
                         FA_TRANSACTION_HEADERS FTH,
                         GL_CODE_COMBINATIONS_KFV GCC,
                         FA_ADDITIONS FAD
                   WHERE FTH.ASSET_ID = FAD.ASSET_ID
                     AND FDH.TRANSACTION_HEADER_ID_IN = FTH.TRANSACTION_HEADER_ID
                     AND FDH.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
                     AND FTH.TRANSACTION_TYPE_CODE = 'TRANSFER IN'
                     AND FAD.ASSET_NUMBER = I.ASSET_NUMBER
                     AND ROWNUM = 1;*/

                SELECT asset_id
                  INTO ln_asset_id
                  FROM fa_additions
                 WHERE asset_number = I.ASSET_NUMBER;

                SELECT GCC.CONCATENATED_SEGMENTS DEPRECIATION_ACCOUNT
                  INTO V_DEPRECIATION_ACCOUNT_NEW
                  FROM -- FA_TRANSACTION_HEADERS fth1,   --  Commented for 1.6.
                       fa_distribution_history fdh, GL_CODE_COMBINATIONS_KFV GCC
                 WHERE     fdh.code_combination_id = gcc.code_combination_id
                       AND fdh.asset_id = ln_asset_id
                       AND fdh.book_type_code = P_BOOK
                       AND gcc.concatenated_segments = I.DEPRECIATION_ACCOUNT -- Added as part of Version 1.7
                       AND fdh.transaction_header_id_in =
                           /*Start Change as part of Version 1.7*/
                           --               (SELECT MAX (ftht.transaction_header_id)
                           (SELECT ftht.transaction_header_id
                              /*End Change as part of Version 1.7*/
                              FROM fa_transaction_history_trx_v ftht
                             WHERE     ftht.period_counter <=
                                       (SELECT fdp.period_counter
                                          FROM fa_deprn_periods fdp
                                         WHERE     fdp.book_type_code =
                                                   P_BOOK
                                               AND fdp.period_name = P_PERIOD)
                                   AND ftht.transaction_header_id IN
                                           (SELECT fth1.transaction_header_id
                                              FROM FA_TRANSACTION_HEADERS fth1, fa_distribution_history fdh, GL_CODE_COMBINATIONS_KFV GCC1 -- Added as part of Version 1.7
                                             WHERE     fth1.transaction_header_id =
                                                       fdh.transaction_header_id_in
                                                   /*Start Change as part of Version 1.7*/
                                                   AND fdh.code_combination_id =
                                                       gcc1.code_combination_id
                                                   AND gcc1.concatenated_segments =
                                                       I.DEPRECIATION_ACCOUNT
                                                   /*End Change as part of Version 1.7*/
                                                   AND fdh.asset_id =
                                                       ln_asset_id));
            --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    V_DEPRECIATION_ACCOUNT_NEW   := I.DEPRECIATION_ACCOUNT;
                WHEN OTHERS
                THEN
                    V_DEPRECIATION_ACCOUNT_NEW   := I.DEPRECIATION_ACCOUNT;
            END;

            --         IF V_NET_BOOK_VALUE_TOTAL <> 0
            --         THEN
            --            V_NET_BOOK_VALUE_TOTAL :=
            --                NVL (V_NET_BOOK_VALUE_TOTAL, 0)
            --                - NVL (V_IMPAIRMENT_AMOUNT, 0);
            --         END IF;

            --END CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015

            --START CHANGES BY BT TECHNOLOGY TEAM ON  15-JAN-2015--
            --Start modification for Defect 701,Dt 04-Dec-15,By BT Technology Team,V1.4
            V_ASSET_RSV_ACCOUNT_NULL     :=
                ASSET_RSV_ACCOUNT_NULL_FN (P_BOOK, I.ASSET_NUMBER, P_CURRENCY
                                           , P_PERIOD);
            --End modification for Defect 701,Dt 04-Dec-15,By BT Technology Team,V1.4
            /* ASSET ACCOUNT AND ASSET RESERVE ACCOUNT FUNCTION CALL*/
            V_ASSET_ACCOUNT              :=
                NVL (ASSET_ACCOUNT_FN (P_BOOK, I.ASSET_NUMBER, P_CURRENCY,
                                       P_PERIOD),
                     NULL);

            /*Start Change as part of Version 1.7*/
            IF V_ASSET_ACCOUNT IS NULL
            THEN
                BEGIN
                    SELECT DISTINCT (gcck.concatenated_segments)
                      INTO V_ASSET_ACCOUNT
                      FROM FA_ADJUSTMENTS fa, fa_transaction_headers fth, xla_ae_headers xah,
                           xla_ae_lines xal, gl_ledgers gll, xla_distribution_links xdl,
                           gl_code_combinations_kfv gcck
                     WHERE     fa.transaction_header_id =
                               fth.transaction_header_id
                           AND xah.event_id = fth.event_id
                           AND xah.ledger_id = gll.ledger_id
                           AND xdl.event_id = xah.event_id
                           AND xdl.ae_header_id = xah.ae_header_id
                           AND xal.ae_header_id = xdl.ae_header_id
                           AND xah.ae_header_id = xal.ae_header_id
                           AND xdl.source_distribution_id_num_2 =
                               fa.adjustment_line_id
                           AND xdl.ae_line_num = xal.ae_line_num
                           AND xal.code_combination_id =
                               gcck.code_combination_id
                           AND SUBSTR (gcck.concatenated_segments, 18, 4) =
                               SUBSTR (V_DEPRECIATION_ACCOUNT_NEW, 18, 4)
                           AND fth.transaction_header_id =
                               (SELECT MAX (ftht.transaction_header_id)
                                  FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, xla_events xe,
                                       fa_adjustments fa
                                 WHERE     ftht.period_counter <=
                                           (SELECT fdp.period_counter
                                              FROM fa_deprn_periods fdp
                                             WHERE     fdp.book_type_code =
                                                       P_BOOK
                                                   AND fdp.period_name =
                                                       P_PERIOD)
                                       AND fth.transaction_header_id =
                                           ftht.transaction_header_id
                                       AND fth.transaction_header_id =
                                           fa.transaction_header_id
                                       AND fa.adjustment_type = 'COST'
                                       AND xe.event_id = fth.event_id
                                       AND xe.EVENT_STATUS_CODE <> 'N'
                                       AND fth.event_id IS NOT NULL
                                       AND ftht.asset_id = I.ASSET_NUMBER)
                           AND fa.adjustment_type = 'COST'
                           AND NVL (fa.source_dest_code, 'DEST') = 'DEST'
                           AND gll.ledger_id = P_CURRENCY;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        BEGIN
                            SELECT DISTINCT (gcck.concatenated_segments)
                              INTO V_ASSET_ACCOUNT
                              FROM FA_ADJUSTMENTS fa, fa_transaction_headers fth, xla_ae_headers xah,
                                   xla_ae_lines xal, gl_ledgers gll, xla_distribution_links xdl,
                                   gl_code_combinations_kfv gcck
                             WHERE     fa.transaction_header_id =
                                       fth.transaction_header_id
                                   AND xah.event_id = fth.event_id
                                   AND xah.ledger_id = gll.ledger_id
                                   AND xdl.event_id = xah.event_id
                                   AND xdl.ae_header_id = xah.ae_header_id
                                   AND xal.ae_header_id = xdl.ae_header_id
                                   AND xah.ae_header_id = xal.ae_header_id
                                   AND xdl.source_distribution_id_num_2 =
                                       fa.adjustment_line_id
                                   AND xdl.ae_line_num = xal.ae_line_num
                                   AND xal.code_combination_id =
                                       gcck.code_combination_id
                                   AND SUBSTR (gcck.concatenated_segments,
                                               18,
                                               4) =
                                       SUBSTR (V_DEPRECIATION_ACCOUNT_NEW,
                                               18,
                                               4)
                                   AND fth.transaction_header_id =
                                       (SELECT MAX (ftht.transaction_header_id)
                                          FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, xla_events xe,
                                               fa_adjustments fa, fa_distribution_history fdh, -- Anjana
                                                                                               GL_CODE_COMBINATIONS_KFV GCC1 -- Anjana
                                         WHERE     ftht.period_counter <=
                                                   (SELECT fdp.period_counter
                                                      FROM fa_deprn_periods fdp
                                                     WHERE     fdp.book_type_code =
                                                               P_BOOK
                                                           AND fdp.period_name =
                                                               P_PERIOD)
                                               AND fth.transaction_header_id =
                                                   ftht.transaction_header_id
                                               AND fth.transaction_header_id =
                                                   fa.transaction_header_id
                                               AND fth.transaction_header_id =
                                                   fdh.transaction_header_id_in -- Anjana
                                               AND fdh.code_combination_id =
                                                   gcc1.code_combination_id
                                               AND SUBSTR (
                                                       gcc1.concatenated_segments,
                                                       18,
                                                       4) =
                                                   SUBSTR (
                                                       V_DEPRECIATION_ACCOUNT_NEW,
                                                       18,
                                                       4)            -- Anjana
                                               AND fa.adjustment_type =
                                                   'COST'
                                               AND xe.event_id = fth.event_id
                                               AND xe.EVENT_STATUS_CODE <>
                                                   'N'
                                               AND fth.event_id IS NOT NULL
                                               AND ftht.asset_id =
                                                   I.ASSET_NUMBER)
                                   AND fa.adjustment_type = 'COST'
                                   AND NVL (fa.source_dest_code, 'DEST') =
                                       'DEST'
                                   AND gll.ledger_id = P_CURRENCY;
                        EXCEPTION                  -- Added by Infosys for 1.8
                            WHEN NO_DATA_FOUND
                            THEN
                                V_ASSET_ACCOUNT   := NULL;
                                APPS.FND_FILE.PUT_LINE (
                                    APPS.FND_FILE.LOG,
                                       'Asset Account does not exist for Asset Number:'
                                    || I.ASSET_NUMBER);
                            WHEN OTHERS
                            THEN
                                V_ASSET_ACCOUNT   := NULL;
                                APPS.FND_FILE.PUT_LINE (
                                    APPS.FND_FILE.LOG,
                                       'Error while fecthing Asset Account for Asset Number:'
                                    || I.ASSET_NUMBER
                                    || ':'
                                    || SQLERRM);
                        END;
                    WHEN OTHERS
                    THEN
                        V_ASSET_ACCOUNT   := NULL;
                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                               'Error while fecthing Asset Account for Asset Number:'
                            || I.ASSET_NUMBER
                            || ':'
                            || SQLERRM);
                END;
            END IF;

            /*End Change as part of Version 1.7*/
            V_ASSET_RESERVE_ACCOUNT      :=
                NVL (
                    ASSET_RESERVE_ACCOUNT_FN (P_BOOK, P_PERIOD, I.ASSET_NUMBER
                                              , P_CURRENCY),
                       --Start modification for Defect 701,Dt 04-Dec-15,By BT Technology Team,V1.4
                       SUBSTR (V_ASSET_ACCOUNT, 1, 22)
                    || V_ASSET_RSV_ACCOUNT_NULL
                    || SUBSTR (V_ASSET_ACCOUNT, 28, 9));
            --End modification for Defect 701,Dt 04-Dec-15,By BT Technology Team,V1.4

            --END CHANGES BY BT TECHNOLOGY TEAM ON  15-JAN-2015

            --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
            V_ASSET_CATEGORY             :=
                NVL (ASSET_CATEGORY_FN (P_BOOK, P_PERIOD, I.ASSET_NUMBER),
                     NULL);

            --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1

            BEGIN
                INSERT INTO XXDO.XXDO_FA_RESERVE_LOCATION_REP_X (
                                BOOK,
                                PERIOD,
                                ASSET_CATEGORY_TYPE,
                                ASSET_TYPE,
                                ASSET_ACCOUNT,
                                ASSET_NUMBER,
                                ASSET_DESCRIPTION,
                                SUPPLIER,
                                CUSTODIAN,
                                DATE_PLACED_IN_SERVICE,
                                DEPRN_METHOD,
                                LIFE_YR_MO,
                                COST,
                                BEGIN_YEAR_DEPR_RESERVE,
                                CURRENT_PERIOD_DEPRECIATION,
                                YTD_DEPRECIATION,
                                ENDING_DEPR_RESERVE,
                                NET_BOOK_VALUE,
                                DEPRECIATION_ACCOUNT,
                                LOCATION_FLEXFIELD,
                                ASSET_TAG_NUMBER,
                                ASSET_SERIAL_NUMBER,
                                PROJECT_NUMBER,
                                ASSET_RESERVE_ACCOUNT,
                                ASSET_CC,
                                ASSET_ACCT,
                                ASSET_BRAND--                         ,
                                           --                         IMPAIRMENT_AMOUNT
                                           )
                     VALUES (P_BOOK, P_PERIOD, --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                               -- I.ASSET_CATEGORY_TYPE,
                                               V_ASSET_CATEGORY,
                             --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                             I.ASSET_TYPE, V_ASSET_ACCOUNT, --I.ASSET_ACCOUNT,-- MODIFIED BY BT TECHNOLOGY TEAM ON  15-JAN-2015
                                                            I.ASSET_NUMBER,
                             I.ASSET_DESCRIPTION, I.SUPPLIER, I.CUSTODIAN,
                             I.DATE_PLACED_IN_SERVICE, I.DEPRN_METHOD, I.LIFE_YR_MO, -- NVL (V_COST_TOTAL, 0), -- Modified for v1.7
                                                                                     NVL (I.COST, 0), NVL (V_BEGIN_YR_DEPRN_TOTAL, 0), -- NVL (I.BEGIN_YEAR_DEPR_RESERVE, 0),
                                                                                                                                       NVL (I.CURRENT_PERIOD_DEPRECIATION, 0), NVL (I.YTD_DEPRECIATION, 0), --                           NVL (V_ENDING_TOTAL,
                                                                                                                                                                                                            --                                NVL (V_ENDING_DEPRN_RESERVE_TOTAL, 0)
                                                                                                                                                                                                            --                               ),---LOGIC NOT PICKING CURRECT VALUE
                                                                                                                                                                                                            --       V_ENDING_DEPR_RESERVE, -- modified for V1.7
                                                                                                                                                                                                            NVL (I.ENDING_DEPR_RESERVE, 0), -- MODIFIED BY BT TECHNOLOGY TEAM ON  16-JAN-2015
                                                                                                                                                                                                                                            -- NVL (V_NET_BOOK_VALUE_TOTAL, 0), -- modified for V1.7
                                                                                                                                                                                                                                            NVL (I.NET_BOOK_VALUE, 0), --                         I.DEPRECIATION_ACCOUNT,
                                                                                                                                                                                                                                                                       V_DEPRECIATION_ACCOUNT_NEW, -- ADDED BY BT TECHNOLOGY TEAM ON  17-JAN-2015
                                                                                                                                                                                                                                                                                                   I.LOCATION_FLEXFIELD, I.ASSET_TAG_NUMBER, I.ASSET_SERIAL_NUMBER, I.PROJECT_NUMBER, V_ASSET_RESERVE_ACCOUNT
                             , -- I.ASSET_RESERVE_ACCOUNT,-- MODIFIED BY BT TECHNOLOGY TEAM ON  15-JAN-2015
                               I.ASSET_CC, I.ASSET_ACCT, I.ASSET_BRAND--                         ,
                                                                      --                         NVL (V_IMPAIRMENT_AMOUNT, 0)
                                                                      );
            --            COMMIT;--2
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Error while inserting into XXDO_FA_RESERVE_LOCATION_REP_X'
                        || SQLERRM);
            END;
        END LOOP;

        insert_asset_records (P_BOOK, P_PERIOD, P_COST_CENTER,
                              P_MAJOR_CATEGORY, P_MINOR_CATEGORY, P_ASSET_COST_GROUP, P_GRAND_TOTAL_BY, P_CURRENCY, P_PROJECT_TYPE
                              ,                                  -- CCR0008086
                                p_file_path, p_errbuf, p_retcode);
    -- RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'sqlerrm:' || SQLERRM);
    --  RETURN (TRUE);
    END asset_main;

    PROCEDURE MAIN (ERRBUF                  OUT VARCHAR2,
                    RETCODE                 OUT NUMBER,
                    P_BOOK               IN     VARCHAR2,
                    P_PERIOD             IN     VARCHAR2,
                    P_CURRENCY           IN     VARCHAR2,
                    P_ASSET_COST_GROUP   IN     VARCHAR2)
    AS
        V_NUM                           NUMBER;
        V_SUPPLIER                      VARCHAR2 (100);
        V_PROJECT_ID                    NUMBER;
        -- ADDED BY BT TECHNOLOGY TEAM ON 9-OCT-2014
        V_PROJECT_NUMBER                VARCHAR2 (25);
        -- ADDED BY BT TECHNOLOGY TEAM ON 9-OCT-2014
        V_COST                          NUMBER;
        V_CURRENT_PERIOD_DEPRECIATION   NUMBER;
        V_ENDING_DPERECIATION_RESERVE   NUMBER;
        V_NET_BOOK_VALUE                NUMBER;
        V_REPORT_DATE                   VARCHAR2 (30);
        V_ASSET_COUNT                   NUMBER;
        V_PRIOR_YEAR                    NUMBER;
        --V_COST_TOTAL NUMBER;
        V_BEGINING_YR_DEPRN             NUMBER;
        --   V_CURRENT_PERIOD_DEPRN_TOTAL NUMBER;
        --   V_YTD_DEPRN_TOTAL NUMBER;
        --   V_ENDING_DEPRN_RESERVE_TOTAL NUMBER;
        --    V_NET_BOOK_VALUE_TOTAL NUMBER;
        V_YTD_DEPRN_TRANSFER            NUMBER;
        V_YTD_DEPRN                     NUMBER;
        V_COST_TOTAL                    NUMBER;
        V_CURRENT_PERIOD_DEPRN_TOTAL    NUMBER;
        V_YTD_DEPRN_TOTAL               NUMBER;
        V_ENDING_DEPRN_RESERVE_TOTAL    NUMBER;
        V_NET_BOOK_VALUE_TOTAL          NUMBER;
        V_BEGIN_YR_DEPRN_TOTAL          NUMBER;
        V_ENDING_TOTAL                  NUMBER;
        V_CUSTODIAN                     VARCHAR2 (50);
        V_LOCATION_ID                   NUMBER;
        V_LOCATION_FLEXFIELD            VARCHAR2 (100);
        V_DEPRECIATION_ACCOUNT          VARCHAR2 (100);
        V_NULL_COUNT                    NUMBER := 0;
        --V_ASSET_NUM                     NUMBER;
        V_ASSET_NUM                     VARCHAR2 (100);
        V_PERIOD_FROM                   VARCHAR2 (20);
        ln_asset_id                     NUMBER;

        CURSOR C_HEADER (CP_BOOK              IN VARCHAR2,
                         -- P_PERIOD           IN  VARCHAR2,
                         P_CURRENCY           IN VARCHAR2,
                         P_ASSET_COST_GROUP   IN VARCHAR2)
        IS
            SELECT                                              --  COMP_CODE,
                   ASSET_CATEGORY_ATTRIB1 BRAND, ASSET_COST_SEGMENT2, ASSET_COST_SEGMENT4,
                   ASSET_COST_GROUP, ASSET_CATEGORY_COST_GROUP, ASSET_COST_SEGMENT3,
                   ASSET_CATEGORY, ASSET_TYPE, TO_CHAR (START_DATE, 'DD-MON-YYYY') DATE_PLACED_IN_SERVICE,
                   ASSET_NUMBER, NVL (T_TYPE, 'A') T_TYPE, DESCRIPTION,
                   ASSET_EXP_DEPT, ASSET_COST_ACCOUNT ASSET_ACCOUNT, ASSET_EXP_ACCOUNT DEPRECIATION_ACCOUNT,
                   BOOK_TYPE_CODE, METHOD DEPRN_METHOD, TRUNC (LIFE / 12) || '.' || TRUNC (MOD (LIFE, 12)) LIFE_YR,
                   /* ROUND (LIFE / 12, 2) LIFE_YR, */
                            --LOGIC CHANGE ON 19JUNE2015 BY BT TECHNOLOGY TEAM
                   ADJ_RATE, BONUS_RATE, PROD,
                   COST, BEGIN_YEAR_DEPRECIATION, DEPRN_AMOUNT CURRENT_PERIOD_DEPRECIATION,
                   YTD_DEPRN, DEPRN_RESERVE ENDING_DPERECIATION_RESERVE, NET_BOOK_VALUE,
                   PERCENT, CCID, T_TYPE_A,
                   -- START CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                   ASSET_TAG_NUMBER, ASSET_SERIAL_NUMBER, ASSET_RESERVE_ACCOUNT
              -- END CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
              FROM (  SELECT               --  ACCT_FLEX_BAL_SEG    COMP_CODE,
                             FC.ATTRIBUTE1 ASSET_CATEGORY_ATTRIB1, CC_COST.SEGMENT2 ASSET_COST_SEGMENT2, CC_COST.SEGMENT4 ASSET_COST_SEGMENT4,
                             -- DECODE (FC.SEGMENT3, 'CORP', 'CORPORATE', 'BRAND')
                             FC.SEGMENT1 || '.' || FC.SEGMENT2 || '.' || FC.SEGMENT3 ASSET_COST_GROUP, CC_COST.SEGMENT2 || '.' || CC_COST.SEGMENT4 || '.' || ' ' || FC.SEGMENT3 ASSET_CATEGORY_COST_GROUP, CC_COST.SEGMENT3 ASSET_COST_SEGMENT3,
                             FC.SEGMENT1 ASSET_CATEGORY, AD.ASSET_TYPE ASSET_TYPE, DATE_PLACED_IN_SERVICE START_DATE,
                             AD.ASSET_NUMBER, RSV.TRANSACTION_TYPE T_TYPE, AD.DESCRIPTION,
                             (CC.SEGMENT2 || '.' || CC.SEGMENT4) ASSET_EXP_DEPT, CC_COST.CONCATENATED_SEGMENTS ASSET_COST_ACCOUNT, CC.CONCATENATED_SEGMENTS ASSET_EXP_ACCOUNT,
                             DS.BOOK_TYPE_CODE BOOK_TYPE_CODE, METHOD_CODE METHOD, RSV.LIFE LIFE,
                             RSV.RATE ADJ_RATE, DS.BONUS_RATE BONUS_RATE, RSV.CAPACITY PROD,
                             SUM (DECODE (RSV.TRANSACTION_TYPE, 'B', NULL, COST)) COST, NVL (SUM (RSV.DEPRN_RESERVE), 0) - NVL (SUM (RSV.YTD_DEPRN), 0) BEGIN_YEAR_DEPRECIATION, SUM (RSV.DEPRN_AMOUNT) DEPRN_AMOUNT,
                             SUM (RSV.YTD_DEPRN) YTD_DEPRN, SUM (RSV.DEPRN_RESERVE) DEPRN_RESERVE, SUM (DECODE (RSV.TRANSACTION_TYPE, 'B', NULL, COST)) - SUM (RSV.DEPRN_RESERVE) NET_BOOK_VALUE,
                             SUM (DECODE (RSV.TRANSACTION_TYPE, 'B', NULL, NVL (PERCENT, 0))) PERCENT, RSV.DH_CCID CCID, DECODE (RSV.TRANSACTION_TYPE, '', 'Y', 'N') T_TYPE_A,
                             -- START CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                             AD.TAG_NUMBER ASSET_TAG_NUMBER, AD.SERIAL_NUMBER ASSET_SERIAL_NUMBER, CC_RESERVE.CONCATENATED_SEGMENTS ASSET_RESERVE_ACCOUNT
                        --END CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                        FROM XXDO.XXDO_FA_RESERVE_LEDGER_GT RSV, --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                                                 FA_TRANSACTION_HISTORY_TRX_V FTHT, FA_TRANSACTION_HEADERS FTH,
                             --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                             FA_ADDITIONS AD, FA_CATEGORIES FC, FA_CATEGORY_BOOKS FCB,
                             GL_CODE_COMBINATIONS_KFV CC, GL_CODE_COMBINATIONS_KFV CC_COST, -- LP_FA_DEPRN_SUMMARY        DS
                                                                                            FA_DEPRN_SUMMARY DS,
                             GL_CODE_COMBINATIONS_KFV CC_RESERVE
                       WHERE     --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                 --RSV.ASSET_ID = AD.ASSET_ID
                                 -- AND AD.ASSET_CATEGORY_ID = FC.CATEGORY_ID
                                 RSV.ASSET_ID = ftht.ASSET_ID
                             AND fth.transaction_header_id =
                                 ftht.transaction_header_id
                             AND fth.transaction_header_id IN
                                     (SELECT MAX (ftht.transaction_header_id)
                                        FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                                                                                            fa_adjustments fa,
                                             --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                             xla_events xe
                                       WHERE     ftht.period_counter <=
                                                 (SELECT fdp.period_counter
                                                    FROM fa_deprn_periods fdp
                                                   WHERE     fdp.book_type_code =
                                                             p_book
                                                         AND fdp.period_name =
                                                             p_period)
                                             AND fth.transaction_header_id =
                                                 ftht.transaction_header_id
                                             --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                             AND fth.transaction_header_id =
                                                 fa.transaction_header_id
                                             AND fa.adjustment_type = 'COST'
                                             --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                             AND fth.event_id IS NOT NULL
                                             AND xe.event_id = fth.event_id
                                             AND xe.EVENT_STATUS_CODE <> 'N'
                                             AND ftht.asset_id = AD.asset_id)
                             AND ftht.CATEGORY_ID = FC.CATEGORY_ID
                             --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                             AND FC.CATEGORY_ID = FCB.CATEGORY_ID
                             AND FCB.BOOK_TYPE_CODE = DS.BOOK_TYPE_CODE
                             AND FCB.ASSET_COST_ACCOUNT_CCID =
                                 CC_COST.CODE_COMBINATION_ID(+)
                             -- ADDED BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                             AND FCB.RESERVE_ACCOUNT_CCID =
                                 CC_RESERVE.CODE_COMBINATION_ID(+)
                             AND RSV.DH_CCID = CC.CODE_COMBINATION_ID
                             AND DS.PERIOD_COUNTER(+) = RSV.PERIOD_COUNTER
                             AND DS.BOOK_TYPE_CODE(+) = P_BOOK
                             AND DS.ASSET_ID(+) = RSV.ASSET_ID
                             --AND    AD.ASSET_NUMBER='10409'
                             AND FC.SEGMENT3 =
                                 NVL (P_ASSET_COST_GROUP, FC.SEGMENT3)
                    --AND    (RSV.TRANSACTION_TYPE<>'T' OR RSV.TRANSACTION_TYPE IS NULL)
                    --LP_ASSET_COST_GROUP
                    GROUP BY FC.ATTRIBUTE1, CC_COST.SEGMENT2, CC_COST.SEGMENT4,
                             FC.SEGMENT1, FC.SEGMENT2, FC.SEGMENT3,
                             CC_COST.SEGMENT3, FC.SEGMENT1, AD.ASSET_TYPE,
                             CC_COST.SEGMENT2 || '.' || CC_COST.SEGMENT4 || '.' || ' ' || FC.SEGMENT3, DATE_PLACED_IN_SERVICE, AD.ASSET_NUMBER,
                             RSV.TRANSACTION_TYPE, (CC.SEGMENT2 || '.' || CC.SEGMENT4), CC.CONCATENATED_SEGMENTS,
                             CC_COST.CONCATENATED_SEGMENTS, DS.BOOK_TYPE_CODE, AD.DESCRIPTION,
                             RSV.METHOD_CODE, RSV.LIFE, RSV.RATE,
                             RSV.CAPACITY, DS.BONUS_RATE, RSV.DH_CCID,
                             RSV.TRANSACTION_TYPE, -- START CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                                                   AD.TAG_NUMBER, AD.SERIAL_NUMBER,
                             CC_RESERVE.CONCATENATED_SEGMENTS
                    -- END CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                    ORDER BY 1, 2, 3,
                             4, 5, 6,
                             7, 8, 9,
                             10, 11)
             WHERE ((NVL (COST, 0) <> 0 OR NVL (DEPRN_AMOUNT, 0) <> 0 OR NVL (YTD_DEPRN, 0) <> 0) OR T_TYPE = 'F');

        CURSOR C_OUTPUT IS
              SELECT BOOK, PERIOD, ASSET_CATEGORY_TYPE,
                     ASSET_CATEGORY_COST_GROUP, ASSET_TYPE, ASSET_ACCOUNT,
                     ASSET_NUMBER, ASSET_DESCRIPTION, SUPPLIER,
                     CUSTODIAN, DATE_PLACED_IN_SERVICE, DEPRN_METHOD,
                     LIFE_YR_MO, SUM (COST) COST, SUM (BEGIN_YEAR_DEPR_RESERVE) BEGIN_YEAR_DEPR_RESERVE,
                     SUM (CURRENT_PERIOD_DEPRECIATION) CURRENT_PERIOD_DEPRECIATION, SUM (YTD_DEPRECIATION) YTD_DEPRECIATION, SUM (ENDING_DEPR_RESERVE) ENDING_DEPR_RESERVE,
                     SUM (NET_BOOK_VALUE) NET_BOOK_VALUE, DEPRECIATION_ACCOUNT, LOCATION_FLEXFIELD,
                     --   TRANSACTION_TYPE,
                     T_TYPE_A, ASSET_TAG_NUMBER, ASSET_SERIAL_NUMBER,
                     ASSET_RESERVE_ACCOUNT, PROJECT_NUMBER
                FROM XXDO.XXDO_FA_RESERVE_LOCATION_REP
            GROUP BY BOOK, PERIOD, ASSET_CATEGORY_TYPE,
                     ASSET_CATEGORY_COST_GROUP, ASSET_TYPE, ASSET_ACCOUNT,
                     ASSET_NUMBER, ASSET_DESCRIPTION, SUPPLIER,
                     CUSTODIAN, DATE_PLACED_IN_SERVICE, DEPRN_METHOD,
                     LIFE_YR_MO, DEPRECIATION_ACCOUNT, LOCATION_FLEXFIELD,
                     --  TRANSACTION_TYPE,
                     T_TYPE_A, ASSET_TAG_NUMBER, ASSET_SERIAL_NUMBER,
                     ASSET_RESERVE_ACCOUNT, PROJECT_NUMBER
            ORDER BY ASSET_NUMBER ASC;
    BEGIN
        --      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXDO_FA_RESERVE_LOCATION_REP';
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_book:' || P_BOOK);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'p_period:' || P_PERIOD);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'before call fa_rsvldg_proc');
        /*RUN FA_RSVLDG_PROC*/
        XXDO_FA_ASSET_RSV_PKG.FA_RSVLDG_PROC (P_BOOK, P_PERIOD);
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.LOG,
            'after call fa_rsvldg_proc insert xxdo_fa_reserve_ledger_gt');

        BEGIN
            SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
              INTO V_REPORT_DATE
              FROM SYS.DUAL;
        END;

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'v_report_date ' || V_REPORT_DATE);

        --      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXDO_FA_BALANCES_REPORT_GT';
        SELECT PERIOD_NAME
          INTO V_PERIOD_FROM
          FROM FA_DEPRN_PERIODS
         WHERE     BOOK_TYPE_CODE = P_BOOK                      --'DECKERS US'
               AND FISCAL_YEAR =
                   (SELECT FISCAL_YEAR
                      FROM FA_DEPRN_PERIODS
                     WHERE BOOK_TYPE_CODE = P_BOOK              --'DECKERS US'
                                                   AND PERIOD_NAME = P_PERIOD --'MAY-13'
                                                                             )
               --START CHANGES BY BT TECHNOLOGY TEAM ON 7-OCT-2014
               --AND PERIOD_NUM = 1;
               AND PERIOD_NUM = (SELECT MIN (PERIOD_NUM)
                                   FROM FA_DEPRN_PERIODS
                                  WHERE BOOK_TYPE_CODE = P_BOOK);

        -- END CHANGES  BY BT TECHNOLOGY TEAM ON 7-OCT-2014
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'v_period_from ' || V_PERIOD_FROM);
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'before call of insert_info ');
        INSERT_INFO (BOOK => P_BOOK, START_PERIOD_NAME => V_PERIOD_FROM, END_PERIOD_NAME => P_PERIOD
                     , REPORT_TYPE => 'RESERVE');
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'after call of insert_info ');
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT, 'DECKERS CORPORATION');
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
            'Report Name :Asset Reserve Detail Extended Location - Deckers');
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.OUTPUT,
                                'Report Date - :' || V_REPORT_DATE);
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.OUTPUT,
               'Book'
            || CHR (9)
            || 'Period'
            || CHR (9)
            || 'Asset Category Type'
            || CHR (9)
            || 'Asset Category Cost Group'
            || CHR (9)
            || 'Asset Type'
            || CHR (9)
            || 'Asset Account'
            || CHR (9)
            || 'Asset Number'
            || CHR (9)
            || 'Asset Description'
            || CHR (9)
            || 'Supplier'
            || CHR (9)
            || 'Custodian'
            || CHR (9)
            || 'Date Placed In Service'
            || CHR (9)
            || 'Deprn Method'
            || CHR (9)
            || 'Life Yr.Mo'
            || CHR (9)
            || 'Cost'
            || CHR (9)
            || 'Begin of Year Depr Reserve'
            || CHR (9)
            || 'Current Period Depreciation'
            || CHR (9)
            || 'Year-To-Date Depreciation'
            || CHR (9)
            || 'Ending Depr. Reserve'
            || CHR (9)
            || 'Net Book Value'
            || CHR (9)
            || 'Depreciation Account'
            || CHR (9)
            || 'Location Flexfield'
            || CHR (9)
            --START CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
            || 'Asset Tag Number'
            || CHR (9)
            || 'Asset Serial Number'
            || CHR (9)
            || 'Asset Reserve account'
            || CHR (9)
            || 'Project Number');
        V_NULL_COUNT   := 0;

        FOR CREC
            IN C_HEADER (CP_BOOK              => P_BOOK,
                         -- P_PERIOD           IN  VARCHAR2,
                         P_CURRENCY           => P_CURRENCY,
                         P_ASSET_COST_GROUP   => P_ASSET_COST_GROUP)
        LOOP
            /*
              V_COST_TOTAL:=NULL;
              V_BEGIN_YR_DEPRN_TOTAL:=NULL;
              V_CURRENT_PERIOD_DEPRN_TOTAL:=NULL;
              V_YTD_DEPRN_TOTAL:=NULL;
              V_ENDING_DEPRN_RESERVE_TOTAL:=NULL;
              V_NET_BOOK_VALUE_TOTAL:=NULL;
              */
            V_PROJECT_ID       := NULL;
            V_PROJECT_NUMBER   := NULL;
            V_SUPPLIER         := NULL;
            ln_asset_id        := 0;

            BEGIN
                --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                /*  SELECT PER.GLOBAL_NAME CUSTODIAN, LOC.LOCATION_ID,
                            LOC.SEGMENT1
                         || '.'
                         || LOC.SEGMENT2
                         || '.'
                         || LOC.SEGMENT3
                         || '.'
                         || LOC.SEGMENT4
                         || '.'
                         || LOC.SEGMENT5 LOCATION_FLEXFIELD,
      --                      GCC.SEGMENT1
      --                   || '.'
      --                   || GCC.SEGMENT2
      --                   || '.'
      --                   || GCC.SEGMENT3
      --                   || '.'
      --                   || GCC.SEGMENT4
      --                   || '.'
      --                   || GCC.SEGMENT4
                         GCC.CONCATENATED_SEGMENTS DEPRECIATION_ACCOUNT
                                   ---MODIFIED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                    --,GCC.CODE_COMBINATION_ID
                  INTO   V_CUSTODIAN, V_LOCATION_ID,
                         V_LOCATION_FLEXFIELD,
                         V_DEPRECIATION_ACCOUNT                            --,V_CCID
                    FROM APPS.FA_DISTRIBUTION_HISTORY DH,
                         APPS.GL_CODE_COMBINATIONS_KFV GCC,
                         APPS.PER_PEOPLE_F PER,
                         APPS.FA_LOCATIONS LOC,
                         APPS.FA_ADDITIONS FAD
      --              WHERE     DH.ASSET_ID = CREC.ASSET_NUMBER --REMOVED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
      --START CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                  WHERE  DH.ASSET_ID = FAD.ASSET_ID
                     AND FAD.ASSET_NUMBER = CREC.ASSET_NUMBER
                     --END CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                     AND DH.BOOK_TYPE_CODE = P_BOOK
                     AND LOC.LOCATION_ID = DH.LOCATION_ID
                     AND DH.CODE_COMBINATION_ID = GCC.CODE_COMBINATION_ID
      --               AND GCC.CODE_COMBINATION_ID = CREC.CCID--REMOVED BY BT TECHNOLOGY TEAM ON  15-JAN-2015
                     AND DH.DATE_INEFFECTIVE IS NULL
                     AND DH.ASSIGNED_TO = PER.PERSON_ID(+)
                     AND TRUNC (SYSDATE) BETWEEN NVL (PER.EFFECTIVE_START_DATE,
                                                      TRUNC (SYSDATE)
                                                     )
                                             AND NVL (PER.EFFECTIVE_END_DATE,
                                                      TRUNC (SYSDATE)
                                                     )
                     AND ROWNUM = 1; */

                SELECT asset_id
                  INTO ln_asset_id
                  FROM fa_additions
                 WHERE asset_number = CREC.ASSET_NUMBER;

                SELECT PER.GLOBAL_NAME CUSTODIAN, LOC.LOCATION_ID, LOC.SEGMENT1 || '.' || LOC.SEGMENT2 || '.' || LOC.SEGMENT3 || '.' || LOC.SEGMENT4 || '.' || LOC.SEGMENT5 LOCATION_FLEXFIELD,
                       GCC.CONCATENATED_SEGMENTS DEPRECIATION_ACCOUNT
                  INTO V_CUSTODIAN, V_LOCATION_ID, V_LOCATION_FLEXFIELD, V_DEPRECIATION_ACCOUNT
                  FROM FA_TRANSACTION_HEADERS fth1, fa_distribution_history fdh, GL_CODE_COMBINATIONS_KFV GCC,
                       PER_PEOPLE_F PER, FA_LOCATIONS LOC
                 WHERE     fth1.transaction_header_id =
                           fdh.transaction_header_id_in
                       AND fdh.asset_id = ln_asset_id
                       AND fdh.book_type_code = P_BOOK
                       AND loc.location_id = fdh.location_id
                       AND fdh.code_combination_id = gcc.code_combination_id
                       AND fdh.assigned_to = per.person_id(+)
                       AND fth1.transaction_header_id IN
                               (SELECT MAX (ftht.transaction_header_id)
                                  FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth
                                 WHERE     ftht.period_counter <=
                                           (SELECT fdp.period_counter
                                              FROM fa_deprn_periods fdp
                                             WHERE     fdp.book_type_code =
                                                       P_BOOK
                                                   AND fdp.period_name =
                                                       P_PERIOD)
                                       AND fth.transaction_header_id =
                                           ftht.transaction_header_id
                                       AND FTH.TRANSACTION_TYPE_CODE NOT LIKE
                                               'ADJUST%'
                                       AND ftht.ASSET_ID = ln_asset_id);
            --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_CUSTODIAN              := NULL;
                    V_LOCATION_ID            := NULL;
                    V_LOCATION_FLEXFIELD     := NULL;
                    V_DEPRECIATION_ACCOUNT   := NULL;
            END;

            /* GET SUPPLIER*/
            BEGIN
                --         SELECT VENDOR_NAME, PROJECT_ID
                --              INTO V_SUPPLIER, V_PROJECT_ID
                --              FROM FA_INVOICE_DETAILS_V
                --             WHERE ASSET_ID = CREC.ASSET_NUMBER
                --             AND INVOICE_LINE_NUMBER = 1;

                --START CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                SELECT FAV.VENDOR_NAME, FAV.PROJECT_ID
                  INTO V_SUPPLIER, V_PROJECT_ID
                  FROM FA_INVOICE_DETAILS_V FAV, APPS.FA_ADDITIONS FAD, FA_BOOKS FAB
                 WHERE     FAV.ASSET_ID = FAD.ASSET_ID
                       AND FAD.ASSET_ID = FAB.ASSET_ID
                       AND FAB.BOOK_TYPE_CODE = P_BOOK
                       AND FAD.ASSET_NUMBER = CREC.ASSET_NUMBER
                       AND INVOICE_LINE_NUMBER = 1
                       AND ROWNUM = 1;
            --END CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    V_SUPPLIER     := NULL;
                    V_PROJECT_ID   := NULL;
                -- ADDED BY BT TECHNOLOGY TEAM ON 9 -OCT-2014
                WHEN OTHERS
                THEN
                    V_SUPPLIER     := NULL;
                    V_PROJECT_ID   := NULL;
            -- ADDED BY BT TECHNOLOGY TEAM ON 9 -OCT-2014
            END;

            /* GET PROJECT - ADDED BY BT TECHNOLOGY TEAM ON 9-OCT-2014*/
            IF V_PROJECT_ID IS NOT NULL
            THEN
                BEGIN
                    SELECT SEGMENT1
                      INTO V_PROJECT_NUMBER
                      FROM PA_PROJECTS_ALL
                     WHERE PROJECT_ID = V_PROJECT_ID;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        V_PROJECT_NUMBER   := NULL;
                    WHEN OTHERS
                    THEN
                        V_PROJECT_NUMBER   := NULL;
                END;
            END IF;

            INSERT INTO XXDO.XXDO_FA_RESERVE_LOCATION_REP (
                            BOOK,
                            PERIOD,
                            ASSET_CATEGORY_TYPE,
                            ASSET_CATEGORY_COST_GROUP,
                            ASSET_TYPE,
                            ASSET_ACCOUNT,
                            ASSET_NUMBER,
                            ASSET_DESCRIPTION,
                            SUPPLIER,
                            CUSTODIAN,
                            DATE_PLACED_IN_SERVICE,
                            DEPRN_METHOD,
                            LIFE_YR_MO,
                            COST,
                            BEGIN_YEAR_DEPR_RESERVE,
                            CURRENT_PERIOD_DEPRECIATION,
                            YTD_DEPRECIATION,
                            ENDING_DEPR_RESERVE,
                            NET_BOOK_VALUE,
                            DEPRECIATION_ACCOUNT,
                            LOCATION_FLEXFIELD,
                            TRANSACTION_TYPE,
                            T_TYPE_A,
                            -- START CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                            ASSET_TAG_NUMBER,
                            ASSET_SERIAL_NUMBER,
                            PROJECT_NUMBER,
                            ASSET_RESERVE_ACCOUNT-- END CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                                                 )
                     VALUES (P_BOOK,
                             P_PERIOD,
                             CREC.ASSET_COST_GROUP,             -- CREC.BRAND,
                             CREC.ASSET_CATEGORY_COST_GROUP,
                             CREC.ASSET_TYPE,
                             CREC.ASSET_ACCOUNT,
                             CREC.ASSET_NUMBER,
                             CREC.DESCRIPTION,
                             V_SUPPLIER,
                             V_CUSTODIAN,
                             CREC.DATE_PLACED_IN_SERVICE,
                             CREC.DEPRN_METHOD,
                             CREC.LIFE_YR,
                             CREC.COST,
                             CREC.BEGIN_YEAR_DEPRECIATION,
                             CREC.CURRENT_PERIOD_DEPRECIATION,
                             CREC.YTD_DEPRN,
                             CREC.ENDING_DPERECIATION_RESERVE,
                             CREC.NET_BOOK_VALUE,
                             CREC.DEPRECIATION_ACCOUNT,
                             V_LOCATION_FLEXFIELD,
                             CREC.T_TYPE,
                             CREC.T_TYPE_A,
                             -- START CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                             CREC.ASSET_TAG_NUMBER,
                             CREC.ASSET_SERIAL_NUMBER,
                             V_PROJECT_NUMBER,
                             CREC.ASSET_RESERVE_ACCOUNT-- END CHANGES BY BT TECHNOLOGY TEAM ON 9-OCT-2014
                                                       );
        --         COMMIT;--3
        END LOOP;

        UPDATE XXDO.XXDO_FA_RESERVE_LOCATION_REP A
           SET T_TYPE_A   = 'Y'
         WHERE     1 = 1
               AND EXISTS
                       (SELECT NULL
                          FROM XXDO.XXDO_FA_RESERVE_LOCATION_REP B
                         WHERE     A.ASSET_NUMBER = B.ASSET_NUMBER
                               AND B.T_TYPE_A = 'Y');

        FOR I IN C_OUTPUT
        LOOP
            BEGIN
                --DISABLED  BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                --            SELECT SUM (AMOUNT)
                --              INTO V_ENDING_TOTAL
                --              FROM XXDO.XXDO_FA_BALANCES_REPORT_GT
                --             WHERE ASSET_ID = I.ASSET_NUMBER AND SOURCE_TYPE_CODE = 'END';

                --START CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                SELECT NVL (SUM (NVL (XGT.AMOUNT, 0)), 0)
                  INTO V_ENDING_TOTAL
                  FROM XXDO.XXDO_FA_BALANCES_REPORT_GT XGT, APPS.FA_ADDITIONS FAD, FA_BOOKS FAB
                 --             WHERE ASSET_ID = I.ASSET_NUMBER
                 WHERE     XGT.ASSET_ID = FAD.ASSET_ID
                       AND FAD.ASSET_ID = FAB.ASSET_ID
                       AND FAB.BOOK_TYPE_CODE = P_BOOK
                       AND FAD.ASSET_NUMBER = I.ASSET_NUMBER
                       AND XGT.SOURCE_TYPE_CODE = 'END';
            --END CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_ENDING_TOTAL   := NULL;
            END;

            SELECT SUM (COST),             --SUM(CURRENT_PERIOD_DEPRECIATION),
                               SUM (ENDING_DEPR_RESERVE), SUM (NET_BOOK_VALUE),
                   SUM (YTD_DEPRECIATION)
              --,SUM(ENDING_DEPR_RESERVE)-SUM(YTD_DEPRECIATION)   /*MODIFIED BY MURALI 07/29*/
              INTO V_COST_TOTAL, V_ENDING_DEPRN_RESERVE_TOTAL, V_NET_BOOK_VALUE_TOTAL, V_YTD_DEPRN_TOTAL --,V_BEGIN_YR_DEPRN_TOTAL
              FROM XXDO.XXDO_FA_RESERVE_LOCATION_REP
             WHERE ASSET_NUMBER = I.ASSET_NUMBER;

            SELECT FISCAL_YEAR - 1
              INTO V_PRIOR_YEAR
              FROM FA_DEPRN_PERIODS
             WHERE PERIOD_NAME = P_PERIOD AND BOOK_TYPE_CODE = P_BOOK;

            BEGIN
                --DISABLED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                --            SELECT SUM (AMOUNT)
                --              INTO V_BEGIN_YR_DEPRN_TOTAL
                --              FROM XXDO.XXDO_FA_BALANCES_REPORT_GT
                --             WHERE ASSET_ID = I.ASSET_NUMBER AND SOURCE_TYPE_CODE = 'BEGIN';

                --START CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                SELECT NVL (SUM (NVL (XGT.AMOUNT, 0)), 0)
                  INTO V_BEGIN_YR_DEPRN_TOTAL
                  FROM XXDO.XXDO_FA_BALANCES_REPORT_GT XGT, APPS.FA_ADDITIONS FAD, FA_BOOKS FAB
                 --             WHERE ASSET_ID = I.ASSET_NUMBER
                 WHERE     XGT.ASSET_ID = FAD.ASSET_ID
                       AND FAD.ASSET_ID = FAB.ASSET_ID
                       AND FAB.BOOK_TYPE_CODE = P_BOOK
                       AND FAD.ASSET_NUMBER = I.ASSET_NUMBER
                       AND XGT.SOURCE_TYPE_CODE = 'BEGIN';

                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'begin value 1751' || V_BEGIN_YR_DEPRN_TOTAL);
            --END CHANGES BY BT TECHNOLOGY TEAM ON  12-JAN-2015
            EXCEPTION
                WHEN OTHERS
                THEN
                    SELECT SUM (NVL (FV.TOTAL_DEPRN_AMOUNT, 0))
                      INTO V_BEGIN_YR_DEPRN_TOTAL
                      FROM FA_FINANCIAL_INQUIRY_DEPRN_V FV, FA_DEPRN_PERIODS FDP
                     --                WHERE FV.ASSET_ID = I.ASSET_NUMBER   --7549--8955--6989--10293
                     WHERE     FV.ASSET_NUMBER = I.ASSET_NUMBER
                           ---ADDED BY BT TECHNOLOGY TEAM ON  12-JAN-2015
                           AND FDP.BOOK_TYPE_CODE = FV.BOOK_TYPE_CODE
                           AND FV.BOOK_TYPE_CODE = P_BOOK       --'DECKERS US'
                           AND FV.PERIOD_ENTERED = FDP.PERIOD_NAME
                           AND FDP.FISCAL_YEAR = V_PRIOR_YEAR;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                        'begin value 1770' || V_BEGIN_YR_DEPRN_TOTAL);
            END;

            /*  V_COST_TOTAL,
                V_CURRENT_PERIOD_DEPRN_TOTAL,
                V_YTD_DEPRN_TOTAL,
                V_ENDING_DEPRN_RESERVE_TOTAL,
                V_NET_BOOK_VALUE_TOTAL ,
                V_BEGIN_YR_DEPRN_TOTAL
             */
            IF I.T_TYPE_A = 'Y'
            THEN
                IF V_ASSET_NUM IS NULL
                THEN
                    V_ASSET_NUM   := I.ASSET_NUMBER;
                ELSE
                    IF V_ASSET_NUM = I.ASSET_NUMBER
                    THEN
                        /*I.COST:=0;
                        I.BEGIN_YEAR_DEPR_RESERVE:=0;
                        I.CURRENT_PERIOD_DEPRECIATION:=0;
                        I.YTD_DEPRECIATION:=0;
                        I.ENDING_DEPR_RESERVE:=0;
                        I.NET_BOOK_VALUE:=0;
                         */
                        V_COST_TOTAL                   := 0;
                        V_ENDING_DEPRN_RESERVE_TOTAL   := 0;
                        V_NET_BOOK_VALUE_TOTAL         := 0;
                        V_YTD_DEPRN_TOTAL              := 0;
                        V_BEGIN_YR_DEPRN_TOTAL         := 0;
                        V_ENDING_TOTAL                 := 0;
                    ELSE
                        V_ASSET_NUM   := I.ASSET_NUMBER;
                    END IF;
                END IF;
            ELSIF I.T_TYPE_A = 'N'
            THEN
                IF V_ASSET_NUM IS NULL
                THEN
                    V_ASSET_NUM   := I.ASSET_NUMBER;
                ELSE
                    IF V_ASSET_NUM = I.ASSET_NUMBER
                    THEN
                        /*I.COST:=0;
                        I.BEGIN_YEAR_DEPR_RESERVE:=0;
                        I.CURRENT_PERIOD_DEPRECIATION:=0;
                        I.YTD_DEPRECIATION:=0;
                        I.ENDING_DEPR_RESERVE:=0;
                        I.NET_BOOK_VALUE:=0;
                         */
                        V_COST_TOTAL                   := 0;
                        V_ENDING_DEPRN_RESERVE_TOTAL   := 0;
                        V_NET_BOOK_VALUE_TOTAL         := 0;
                        V_YTD_DEPRN_TOTAL              := 0;
                        V_BEGIN_YR_DEPRN_TOTAL         := 0;
                        V_ENDING_TOTAL                 := 0;
                    ELSE
                        V_ASSET_NUM   := I.ASSET_NUMBER;
                    END IF;
                END IF;
            END IF;

            APPS.FND_FILE.PUT_LINE (
                APPS.FND_FILE.OUTPUT,
                   P_BOOK
                || CHR (9)
                || P_PERIOD
                || CHR (9)
                || I.ASSET_CATEGORY_TYPE
                || CHR (9)
                || I.ASSET_CATEGORY_COST_GROUP
                || CHR (9)
                || I.ASSET_TYPE
                || CHR (9)
                || I.ASSET_ACCOUNT
                || CHR (9)
                || I.ASSET_NUMBER
                || CHR (9)
                || I.ASSET_DESCRIPTION
                || CHR (9)
                || I.SUPPLIER
                || CHR (9)
                ||                                                  --SUPPLIER
                   I.CUSTODIAN
                || CHR (9)
                ||                                                 --CUSTODIAN
                   I.DATE_PLACED_IN_SERVICE
                || CHR (9)
                || I.DEPRN_METHOD
                || CHR (9)
                || I.LIFE_YR_MO
                || CHR (9)
                || NVL (V_COST_TOTAL, 0)                  -- modified for V1.7
                -- || NVL (I.COST, 0)
                || CHR (9)
                ||                                                 --CREC.COST
                   NVL (V_BEGIN_YR_DEPRN_TOTAL, 0)        -- modified for V1.7
                -- NVL (I.BEGIN_YEAR_DEPR_RESERVE, 0)
                || CHR (9)
                || NVL (I.CURRENT_PERIOD_DEPRECIATION, 0)
                || CHR (9)
                || NVL (I.YTD_DEPRECIATION, 0)
                || CHR (9)
                || NVL (V_ENDING_TOTAL,
                        NVL (V_ENDING_DEPRN_RESERVE_TOTAL, 0)) -- Modified for v1.7
                -- || NVL (I.ENDING_DEPR_RESERVE, 0)
                || CHR (9)
                || NVL (V_NET_BOOK_VALUE_TOTAL, 0)         -- Modified for 1.7
                -- || NVL (I.NET_BOOK_VALUE, 0)
                || CHR (9)
                ||                                      --DEPRECIATION ACCOUNT
                   I.DEPRECIATION_ACCOUNT
                || CHR (9)
                || I.LOCATION_FLEXFIELD
                || CHR (9)                                --LOCATION FLEXFIELD
                || I.ASSET_SERIAL_NUMBER
                || CHR (9)
                || I.ASSET_TAG_NUMBER
                || CHR (9)
                || I.ASSET_RESERVE_ACCOUNT
                || CHR (9)
                || I.PROJECT_NUMBER);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'sqlerrm:' || SQLERRM);
    END;

    PROCEDURE ASSET_RSV_REP (P_BOOK       IN VARCHAR2,
                             P_PERIOD     IN VARCHAR2,
                             P_CURRENCY   IN NUMBER)
    IS
        V_NUM                           NUMBER;
        V_SUPPLIER                      VARCHAR2 (100);
        V_COST                          NUMBER;
        V_CURRENT_PERIOD_DEPRECIATION   NUMBER;
        V_ENDING_DPERECIATION_RESERVE   NUMBER;
        V_NET_BOOK_VALUE                NUMBER;
        V_REPORT_DATE                   VARCHAR2 (30);
        V_ASSET_COUNT                   NUMBER;
        V_PRIOR_YEAR                    NUMBER;
        --V_COST_TOTAL NUMBER;
        V_BEGINING_YR_DEPRN             NUMBER;
        --   V_CURRENT_PERIOD_DEPRN_TOTAL NUMBER;
        --   V_YTD_DEPRN_TOTAL NUMBER;
        --   V_ENDING_DEPRN_RESERVE_TOTAL NUMBER;
        --    V_NET_BOOK_VALUE_TOTAL NUMBER;
        V_YTD_DEPRN_TRANSFER            NUMBER;
        V_YTD_DEPRN                     NUMBER;
        V_COST_TOTAL                    NUMBER;
        V_CURRENT_PERIOD_DEPRN_TOTAL    NUMBER;
        V_YTD_DEPRN_TOTAL               NUMBER;
        V_ENDING_DEPRN_RESERVE_TOTAL    NUMBER;
        V_NET_BOOK_VALUE_TOTAL          NUMBER;
        V_BEGIN_YR_DEPRN_TOTAL          NUMBER;
        V_ENDING_TOTAL                  NUMBER;
        V_CUSTODIAN                     VARCHAR2 (50);
        V_LOCATION_ID                   NUMBER;
        V_LOCATION_FLEXFIELD            VARCHAR2 (100);
        V_DEPRECIATION_ACCOUNT          VARCHAR2 (100);
        V_NULL_COUNT                    NUMBER := 0;
        V_ASSET_ID                      NUMBER;
        V_PERIOD_FROM                   VARCHAR2 (20);
        V_USER_ENV                      VARCHAR2 (100);
        V_STRING                        VARCHAR2 (50);
        V_SET_USER_ENV                  VARCHAR2 (300);
        V_ASSET_ACCOUNT                 VARCHAR2 (50);
        V_ASSET_ACCOUNT_ID              NUMBER;
        V_ASSET_NUMBER                  VARCHAR2 (50 BYTE);
        ln_asset_category_id            NUMBER;

        CURSOR C_HEADER IS
              SELECT ASSET_ID, DH_CCID, DATE_PLACED_IN_SERVICE,
                     METHOD_CODE, LIFE, RATE,
                     CAPACITY, COST, DEPRN_AMOUNT,
                     YTD_DEPRN, PERCENT, NVL (TRANSACTION_TYPE, 'A') TRANSACTION_TYPE,
                     DEPRN_RESERVE, PERIOD_COUNTER, DATE_EFFECTIVE,
                     DEPRN_RESERVE_ACCT, RESERVE_ACCT, DISTRIBUTION_ID,
                     --        BEGIN_YEAR_DEPR_RESERVE,
                     DECODE (TRANSACTION_TYPE, '', 'Y', 'N') T_TYPE_A
                FROM XXDO.XXDO_FA_RESERVE_LEDGER_GT
               WHERE                                      -- ASSET_ID=9059 AND
                     ((NVL (COST, 0) <> 0 OR NVL (DEPRN_AMOUNT, 0) <> 0 OR NVL (YTD_DEPRN, 0) <> 0) OR TRANSACTION_TYPE = 'F')
            ORDER BY ASSET_ID;

        CURSOR C_OUTPUT IS
              SELECT ASSET_ID, DH_CCID, DATE_PLACED_IN_SERVICE,
                     METHOD_CODE, LIFE, RATE,
                     CAPACITY, COST, DEPRN_AMOUNT,
                     YTD_DEPRN, PERCENT, TRANSACTION_TYPE,
                     DEPRN_RESERVE, PERIOD_COUNTER, DATE_EFFECTIVE,
                     DEPRN_RESERVE_ACCT, RESERVE_ACCT, DISTRIBUTION_ID,
                     BEGIN_YEAR_DEPR_RESERVE, T_TYPE_A
                FROM XXDO.XXDO_FA_RESERVE_LEDGER_EXT
            ORDER BY ASSET_ID;
    BEGIN
        --      EXECUTE IMMEDIATE 'TRUNCATE TABLE  XXDO.XXDO_FA_RESERVE_LEDGER_EXT';

        --      EXECUTE IMMEDIATE 'TRUNCATE TABLE  XXDO.XXDO_FA_RESERVE_LEDGER_EXT_REP';

        --START CHANGES BY BT TECHNOLOGY TEAM ON 28-OCT-2014 - V1.1
        SELECT USERENV ('CLIENT_INFO') INTO V_USER_ENV FROM DUAL;

        SELECT SUBSTR (V_USER_ENV, 0, 44) INTO V_STRING FROM DUAL;

        V_SET_USER_ENV   := V_STRING || P_CURRENCY;
        --       SELECT SUBSTR(V_USER_ENV,55) INTO V_STRING FROM DUAL;
        --
        --       V_SET_USER_ENV := V_SET_USER_ENV || V_STRING;
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'v_set_user_env:' || V_SET_USER_ENV);
        DBMS_APPLICATION_INFO.SET_CLIENT_INFO (V_SET_USER_ENV);

        SELECT TO_NUMBER (SUBSTR (USERENV ('CLIENT_INFO'), 45, 10))
          INTO V_STRING
          FROM DUAL;

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG, 'v_string:' || V_STRING);
        --END CHANGES BY BT TECHNOLOGY TEAM ON 28-OCT-2014 - V1.1
        /*RUN FA_RSVLDG_PROC*/
        XXDO_FA_ASSET_RSV_PKG.FA_RSVLDG_PROC (P_BOOK, P_PERIOD);

        --      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXDO_FA_BALANCES_REPORT_GT';
        SELECT PERIOD_NAME
          INTO V_PERIOD_FROM
          FROM FA_DEPRN_PERIODS
         WHERE     BOOK_TYPE_CODE = P_BOOK                      --'DECKERS US'
               AND FISCAL_YEAR =
                   (SELECT FISCAL_YEAR
                      FROM FA_DEPRN_PERIODS
                     WHERE BOOK_TYPE_CODE = P_BOOK              --'DECKERS US'
                                                   AND PERIOD_NAME = P_PERIOD --'MAY-13'
                                                                             )
               --START CHANGES BY BT TECHNOLOGY TEAM ON 7-OCT-2014
               --AND PERIOD_NUM = 1;
               AND PERIOD_NUM = (SELECT MIN (PERIOD_NUM)
                                   FROM FA_DEPRN_PERIODS
                                  WHERE BOOK_TYPE_CODE = P_BOOK);

        -- END CHANGES  BY BT TECHNOLOGY TEAM ON 7-OCT-2014
        XXDO_FA_ASSET_RSV_PKG.INSERT_INFO (BOOK => P_BOOK, START_PERIOD_NAME => V_PERIOD_FROM, END_PERIOD_NAME => P_PERIOD
                                           , REPORT_TYPE => 'RESERVE');
        V_NULL_COUNT     := 0;

        FOR CREC IN C_HEADER
        LOOP
            INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_EXT (
                            ASSET_ID,
                            DH_CCID,
                            DATE_PLACED_IN_SERVICE,
                            METHOD_CODE,
                            LIFE,
                            RATE,
                            CAPACITY,
                            COST,
                            DEPRN_AMOUNT,
                            YTD_DEPRN,
                            PERCENT,
                            TRANSACTION_TYPE,
                            DEPRN_RESERVE,
                            PERIOD_COUNTER,
                            DATE_EFFECTIVE,
                            DEPRN_RESERVE_ACCT,
                            RESERVE_ACCT,
                            DISTRIBUTION_ID,
                            BEGIN_YEAR_DEPR_RESERVE,
                            T_TYPE_A)
                 VALUES (CREC.ASSET_ID, CREC.DH_CCID, CREC.DATE_PLACED_IN_SERVICE, CREC.METHOD_CODE, CREC.LIFE, CREC.RATE, CREC.CAPACITY, CREC.COST, CREC.DEPRN_AMOUNT, CREC.YTD_DEPRN, CREC.PERCENT, CREC.TRANSACTION_TYPE, CREC.DEPRN_RESERVE, CREC.PERIOD_COUNTER, CREC.DATE_EFFECTIVE, CREC.DEPRN_RESERVE_ACCT, CREC.RESERVE_ACCT, CREC.DISTRIBUTION_ID
                         , NULL, CREC.T_TYPE_A);
        --         COMMIT; --4
        END LOOP;

        UPDATE XXDO.XXDO_FA_RESERVE_LEDGER_EXT A
           SET A.T_TYPE_A   = 'Y'
         WHERE     1 = 1
               AND EXISTS
                       (SELECT NULL
                          FROM XXDO.XXDO_FA_RESERVE_LEDGER_EXT B
                         WHERE A.ASSET_ID = B.ASSET_ID AND B.T_TYPE_A = 'Y');

        FOR I IN C_OUTPUT
        LOOP
            V_ASSET_ACCOUNT      := NULL;
            V_ASSET_ACCOUNT_ID   := NULL;
            V_ASSET_NUMBER       := NULL;
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'before asset_id:' || I.ASSET_ID);
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'before v_begin_yr_deprn_total:' || V_BEGIN_YR_DEPRN_TOTAL);
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'before v_ending_total:' || V_ENDING_TOTAL);

            BEGIN
                SELECT SUM (AMOUNT)
                  INTO V_ENDING_TOTAL
                  FROM XXDO.XXDO_FA_BALANCES_REPORT_GT
                 WHERE ASSET_ID = I.ASSET_ID AND SOURCE_TYPE_CODE = 'END';
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_ENDING_TOTAL   := NULL;
            END;

            SELECT FISCAL_YEAR - 1
              INTO V_PRIOR_YEAR
              FROM FA_DEPRN_PERIODS
             WHERE PERIOD_NAME = P_PERIOD AND BOOK_TYPE_CODE = P_BOOK;

            BEGIN
                SELECT SUM (AMOUNT)
                  INTO V_BEGIN_YR_DEPRN_TOTAL
                  FROM XXDO.XXDO_FA_BALANCES_REPORT_GT
                 WHERE ASSET_ID = I.ASSET_ID AND SOURCE_TYPE_CODE = 'BEGIN';

                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'begin value 2101' || V_BEGIN_YR_DEPRN_TOTAL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_BEGIN_YR_DEPRN_TOTAL   := 0;
            END;

            IF I.T_TYPE_A = 'Y'
            THEN
                IF V_ASSET_ID IS NULL
                THEN
                    V_ASSET_ID   := I.ASSET_ID;
                    FND_FILE.PUT_LINE (FND_FILE.LOG, '1');
                ELSE
                    IF V_ASSET_ID = I.ASSET_ID
                    THEN
                        FND_FILE.PUT_LINE (FND_FILE.LOG, '2');
                        V_ENDING_DEPRN_RESERVE_TOTAL   := 0;
                        V_BEGIN_YR_DEPRN_TOTAL         := 0;
                        V_ENDING_TOTAL                 := 0;
                    ELSE
                        V_ASSET_ID   := I.ASSET_ID;
                        FND_FILE.PUT_LINE (FND_FILE.LOG, '3');
                    END IF;
                END IF;
            ELSIF I.T_TYPE_A = 'N'
            THEN
                IF V_ASSET_ID IS NULL
                THEN
                    V_ASSET_ID   := I.ASSET_ID;
                    FND_FILE.PUT_LINE (FND_FILE.LOG, '4');
                ELSE
                    IF V_ASSET_ID = I.ASSET_ID
                    THEN
                        FND_FILE.PUT_LINE (FND_FILE.LOG, '5');
                        V_ENDING_DEPRN_RESERVE_TOTAL   := 0;
                        V_BEGIN_YR_DEPRN_TOTAL         := 0;
                        V_ENDING_TOTAL                 := 0;
                    ELSE
                        V_ASSET_ID   := I.ASSET_ID;
                        FND_FILE.PUT_LINE (FND_FILE.LOG, '6');
                    END IF;
                END IF;
            END IF;

            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'after asset_id :' || I.ASSET_ID);
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'after v_begin_yr_deprn_total:' || V_BEGIN_YR_DEPRN_TOTAL);
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'after v_ending_total:' || V_ENDING_TOTAL);

            --START CHANGES BY BT TECHNOLOGY TEAM ON  15-JAN-2015
            SELECT ASSET_NUMBER
              INTO V_ASSET_NUMBER
              FROM FA_ADDITIONS
             WHERE ASSET_ID = I.ASSET_ID;

            V_ASSET_ACCOUNT      :=
                NVL (ASSET_ACCOUNT_FN (P_BOOK, V_ASSET_NUMBER, P_CURRENCY,
                                       P_PERIOD),
                     NULL);

            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'after V_ASSET_ACCOUNT:' || V_ASSET_ACCOUNT);

            BEGIN
                SELECT CODE_COMBINATION_ID
                  INTO V_ASSET_ACCOUNT_ID
                  FROM GL_CODE_COMBINATIONS_KFV
                 WHERE CONCATENATED_SEGMENTS = V_ASSET_ACCOUNT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_ASSET_ACCOUNT_ID   := NULL;
            END;

            --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
            BEGIN
                SELECT ftht.category_id
                  INTO ln_asset_category_id
                  FROM fa_transaction_headers fth, fa_transaction_history_trx_v ftht
                 WHERE     fth.transaction_header_id =
                           ftht.transaction_header_id
                       AND fth.transaction_header_id IN
                               (SELECT MAX (ftht.transaction_header_id)
                                  FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                                                                                      fa_adjustments fa,
                                       --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                       xla_events xe
                                 WHERE     ftht.period_counter <=
                                           (SELECT fdp.period_counter
                                              FROM fa_deprn_periods fdp
                                             WHERE     fdp.book_type_code =
                                                       p_book
                                                   AND fdp.period_name =
                                                       p_period)
                                       AND fth.transaction_header_id =
                                           ftht.transaction_header_id
                                       --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                       AND fth.transaction_header_id =
                                           fa.transaction_header_id
                                       AND fa.adjustment_type = 'COST'
                                       --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                       AND fth.event_id IS NOT NULL
                                       AND xe.event_id = fth.event_id
                                       AND xe.EVENT_STATUS_CODE <> 'N'
                                       AND ftht.asset_id = I.ASSET_ID);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_asset_category_id   := NULL;
            END;

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'after ln_asset_category_id :' || ln_asset_category_id);

            --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1

            --END CHANGES BY BT TECHNOLOGY TEAM ON  15-JAN-2015
            INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_EXT_REP (
                            ASSET_ID,
                            DH_CCID,
                            DATE_PLACED_IN_SERVICE,
                            METHOD_CODE,
                            LIFE,
                            RATE,
                            CAPACITY,
                            COST,
                            DEPRN_AMOUNT,
                            YTD_DEPRN,
                            PERCENT,
                            TRANSACTION_TYPE,
                            DEPRN_RESERVE,
                            PERIOD_COUNTER,
                            DATE_EFFECTIVE,
                            DEPRN_RESERVE_ACCT,
                            RESERVE_ACCT,
                            DISTRIBUTION_ID,
                            BEGIN_YEAR_DEPR_RESERVE,
                            T_TYPE_A,
                            ASSET_COST_ACCOUNT_CCID,
                            --ADDED BY BT TECHNOLOGY TEAM ON  15-JAN-2015
                            --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                            ASSET_CATEGORY_ID,
                            BOOK_TYPE_CODE--End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                          )
                 VALUES (i.asset_id, i.dh_ccid, i.date_placed_in_service,
                         i.method_code, i.life, i.rate,
                         i.capacity, i.cost, i.deprn_amount,
                         i.ytd_deprn, i.percent, i.transaction_type,
                         NVL (v_ending_total, 0), i.period_counter, i.date_effective, i.deprn_reserve_acct, i.reserve_acct, i.distribution_id, NVL (v_begin_yr_deprn_total, 0), i.t_type_a, v_asset_account_id
                         , --added by bt technology team on  15-jan-2015
                           --start modificaion for defect 701,dt 23-nov-15,by bt technology team,v1.1
                           ln_asset_category_id, p_book--end modificaion for defect 701,dt 23-nov-15,by bt technology team,v1.1
                                                       );
        END LOOP;
    --      COMMIT;--5
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'sqlerrm:' || SQLERRM);
    END;

    PROCEDURE FA_RSVLDG_PROC (BOOK IN VARCHAR2, PERIOD IN VARCHAR2)
    --   ERRBUF          OUT VARCHAR2,
    --  RETCODE         OUT NUMBER)
    IS
        OPERATION           VARCHAR2 (200);
        DIST_BOOK           VARCHAR2 (15);
        UCD                 DATE;
        UPC                 NUMBER;
        TOD                 DATE;
        TPC                 NUMBER;
        H_SET_OF_BOOKS_ID   NUMBER;
        H_REPORTING_FLAG    VARCHAR2 (1);
        H_TEST              VARCHAR2 (1000);
    BEGIN
        /* NOT NEEDED WITH GLOBAL TEMP FIX
               OPERATION := 'DELETING FROM FA_RESERVE_LEDGER';
               DELETE FROM FA_RESERVE_LEDGER;

               IF (SQL%ROWCOUNT > 0) THEN
                    OPERATION := 'COMMITTING DELETE';
                    COMMIT;
               ELSE
                    OPERATION := 'ROLLING BACK DELETE';
                    ROLLBACK;
               END IF;
        */

        -- GET MRC RELATED INFO
        --      EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXDO_FA_RESERVE_LEDGER_GT';
        SELECT TO_NUMBER (SUBSTR (USERENV ('CLIENT_INFO'), 45, 10))
          INTO H_SET_OF_BOOKS_ID
          FROM DUAL;

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'h_set_of_books_id:' || H_SET_OF_BOOKS_ID);

        IF (H_SET_OF_BOOKS_ID IS NOT NULL)
        THEN
            IF NOT FA_CACHE_PKG.FAZCSOB (
                       X_SET_OF_BOOKS_ID     => H_SET_OF_BOOKS_ID,
                       X_MRC_SOB_TYPE_CODE   => H_REPORTING_FLAG)
            THEN
                RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
            END IF;
        ELSE
            H_REPORTING_FLAG   := 'P';
        END IF;

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'h_reporting_flag:' || H_REPORTING_FLAG);
        OPERATION   := 'Selecting Book and Period information';

        IF (H_REPORTING_FLAG = 'R')
        THEN
              SELECT BC.DISTRIBUTION_SOURCE_BOOK DBK, NVL (DP.PERIOD_CLOSE_DATE, SYSDATE) UCD, DP.PERIOD_COUNTER UPC,
                     MIN (DP_FY.PERIOD_OPEN_DATE) TOD, MIN (DP_FY.PERIOD_COUNTER) TPC
                INTO DIST_BOOK, UCD, UPC, TOD,
                              TPC
                FROM FA_DEPRN_PERIODS_MRC_V DP, FA_DEPRN_PERIODS_MRC_V DP_FY, FA_BOOK_CONTROLS_MRC_V BC
               WHERE     DP.BOOK_TYPE_CODE = BOOK
                     AND DP.PERIOD_NAME = PERIOD
                     AND DP_FY.BOOK_TYPE_CODE = BOOK
                     AND DP_FY.FISCAL_YEAR = DP.FISCAL_YEAR
                     AND BC.BOOK_TYPE_CODE = BOOK
            GROUP BY BC.DISTRIBUTION_SOURCE_BOOK, DP.PERIOD_CLOSE_DATE, DP.PERIOD_COUNTER;
        ELSE
              SELECT BC.DISTRIBUTION_SOURCE_BOOK DBK, NVL (DP.PERIOD_CLOSE_DATE, SYSDATE) UCD, DP.PERIOD_COUNTER UPC,
                     MIN (DP_FY.PERIOD_OPEN_DATE) TOD, MIN (DP_FY.PERIOD_COUNTER) TPC
                INTO DIST_BOOK, UCD, UPC, TOD,
                              TPC
                FROM FA_DEPRN_PERIODS DP, FA_DEPRN_PERIODS DP_FY, FA_BOOK_CONTROLS BC
               WHERE     DP.BOOK_TYPE_CODE = BOOK
                     AND DP.PERIOD_NAME = PERIOD
                     AND DP_FY.BOOK_TYPE_CODE = BOOK
                     AND DP_FY.FISCAL_YEAR = DP.FISCAL_YEAR
                     AND BC.BOOK_TYPE_CODE = BOOK
            GROUP BY BC.DISTRIBUTION_SOURCE_BOOK, DP.PERIOD_CLOSE_DATE, DP.PERIOD_COUNTER;

            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'in else dist_book :' || DIST_BOOK);
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'in else ucd:' || UCD);
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'in else upc:' || UPC);
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'in else tod:' || TOD);
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'in else tpc:' || TPC);
        END IF;

        OPERATION   := 'Inserting into FA.FA_RESERVE_LEDGER_GT';

        -- RUN ONLY IF CRL NOT INSTALLED
        IF (NVL (FND_PROFILE.VALUE ('CRL-FA ENABLED'), 'N') = 'N')
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Inside profile CRL-FA ENABLED is null :');

            IF (H_REPORTING_FLAG = 'R')
            THEN
                INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_GT (
                                ASSET_ID,
                                DH_CCID,
                                DEPRN_RESERVE_ACCT,
                                DATE_PLACED_IN_SERVICE,
                                METHOD_CODE,
                                LIFE,
                                RATE,
                                CAPACITY,
                                COST,
                                DEPRN_AMOUNT,
                                YTD_DEPRN,
                                DEPRN_RESERVE,
                                PERCENT,
                                TRANSACTION_TYPE,
                                PERIOD_COUNTER,
                                DATE_EFFECTIVE,
                                RESERVE_ACCT)
                    SELECT DH.ASSET_ID ASSET_ID, DH.CODE_COMBINATION_ID DH_CCID, CB.DEPRN_RESERVE_ACCT RSV_ACCOUNT,
                           BOOKS.DATE_PLACED_IN_SERVICE START_DATE, BOOKS.DEPRN_METHOD_CODE METHOD, BOOKS.LIFE_IN_MONTHS LIFE,
                           BOOKS.ADJUSTED_RATE RATE, BOOKS.PRODUCTION_CAPACITY CAPACITY, DD_BONUS.COST COST,
                           DECODE (DD_BONUS.PERIOD_COUNTER, UPC, DD_BONUS.DEPRN_AMOUNT - DD_BONUS.BONUS_DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD_BONUS.PERIOD_COUNTER), 1, 0, DD_BONUS.YTD_DEPRN - DD_BONUS.BONUS_YTD_DEPRN) YTD_DEPRN, DD_BONUS.DEPRN_RESERVE - DD_BONUS.BONUS_DEPRN_RESERVE DEPRN_RESERVE,
                           DECODE (TH.TRANSACTION_TYPE_CODE, NULL, DH.UNITS_ASSIGNED / AH.UNITS * 100) PERCENT, DECODE (TH.TRANSACTION_TYPE_CODE,  NULL, DECODE (TH_RT.TRANSACTION_TYPE_CODE, 'FULL RETIREMENT', 'F', DECODE (BOOKS.DEPRECIATE_FLAG, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') T_TYPE, DD_BONUS.PERIOD_COUNTER,
                           NVL (TH.DATE_EFFECTIVE, UCD), ''
                      FROM FA_DEPRN_DETAIL_MRC_V DD_BONUS, FA_ASSET_HISTORY AH, FA_TRANSACTION_HEADERS TH,
                           FA_TRANSACTION_HEADERS TH_RT, FA_BOOKS_MRC_V BOOKS, FA_DISTRIBUTION_HISTORY DH,
                           FA_CATEGORY_BOOKS CB
                     WHERE     CB.BOOK_TYPE_CODE = BOOK
                           AND CB.CATEGORY_ID = AH.CATEGORY_ID
                           AND AH.ASSET_ID = DH.ASSET_ID
                           AND AH.DATE_EFFECTIVE <
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (AH.DATE_INEFFECTIVE, SYSDATE) >=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND AH.ASSET_TYPE = 'CAPITALIZED'
                           AND DD_BONUS.BOOK_TYPE_CODE = BOOK
                           AND DD_BONUS.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                           AND DD_BONUS.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL_MRC_V DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID = DH.ASSET_ID
                                       AND DD_SUB.DISTRIBUTION_ID =
                                           DH.DISTRIBUTION_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND TH_RT.BOOK_TYPE_CODE = BOOK
                           AND TH_RT.TRANSACTION_HEADER_ID =
                               BOOKS.TRANSACTION_HEADER_ID_IN
                           AND BOOKS.BOOK_TYPE_CODE = BOOK
                           AND BOOKS.ASSET_ID = DH.ASSET_ID
                           AND NVL (BOOKS.PERIOD_COUNTER_FULLY_RETIRED, UPC) >=
                               TPC
                           AND BOOKS.DATE_EFFECTIVE <=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (BOOKS.DATE_INEFFECTIVE, SYSDATE + 1) >
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND TH.BOOK_TYPE_CODE(+) = DIST_BOOK
                           AND TH.TRANSACTION_HEADER_ID(+) =
                               DH.TRANSACTION_HEADER_ID_OUT
                           AND TH.DATE_EFFECTIVE(+) BETWEEN TOD AND UCD
                           AND DH.BOOK_TYPE_CODE = DIST_BOOK
                           AND DH.DATE_EFFECTIVE <= UCD
                           AND NVL (DH.DATE_INEFFECTIVE, SYSDATE) > TOD
                    UNION ALL
                    SELECT DH.ASSET_ID ASSET_ID, DH.CODE_COMBINATION_ID DH_CCID, CB.BONUS_DEPRN_RESERVE_ACCT RSV_ACCOUNT,
                           BOOKS.DATE_PLACED_IN_SERVICE START_DATE, BOOKS.DEPRN_METHOD_CODE METHOD, BOOKS.LIFE_IN_MONTHS LIFE,
                           BOOKS.ADJUSTED_RATE RATE, BOOKS.PRODUCTION_CAPACITY CAPACITY, 0 COST,
                           DECODE (DD.PERIOD_COUNTER, UPC, DD.BONUS_DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD.PERIOD_COUNTER), 1, 0, DD.BONUS_YTD_DEPRN) YTD_DEPRN, DD.BONUS_DEPRN_RESERVE DEPRN_RESERVE,
                           0 PERCENT, 'B' T_TYPE, DD.PERIOD_COUNTER,
                           NVL (TH.DATE_EFFECTIVE, UCD), CB.BONUS_DEPRN_EXPENSE_ACCT
                      FROM FA_DEPRN_DETAIL_MRC_V DD, FA_ASSET_HISTORY AH, FA_TRANSACTION_HEADERS TH,
                           FA_TRANSACTION_HEADERS TH_RT, FA_BOOKS_MRC_V BOOKS, FA_DISTRIBUTION_HISTORY DH,
                           FA_CATEGORY_BOOKS CB
                     WHERE     CB.BOOK_TYPE_CODE = BOOK
                           AND CB.CATEGORY_ID = AH.CATEGORY_ID
                           AND AH.ASSET_ID = DH.ASSET_ID
                           AND AH.DATE_EFFECTIVE <
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (AH.DATE_INEFFECTIVE, SYSDATE) >=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND AH.ASSET_TYPE = 'CAPITALIZED'
                           AND DD.BOOK_TYPE_CODE = BOOK
                           AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                           AND DD.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL_MRC_V DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID = DH.ASSET_ID
                                       AND DD_SUB.DISTRIBUTION_ID =
                                           DH.DISTRIBUTION_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND TH_RT.BOOK_TYPE_CODE = BOOK
                           AND TH_RT.TRANSACTION_HEADER_ID =
                               BOOKS.TRANSACTION_HEADER_ID_IN
                           AND BOOKS.BOOK_TYPE_CODE = BOOK
                           AND BOOKS.ASSET_ID = DH.ASSET_ID
                           AND NVL (BOOKS.PERIOD_COUNTER_FULLY_RETIRED, UPC) >=
                               TPC
                           AND BOOKS.DATE_EFFECTIVE <=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (BOOKS.DATE_INEFFECTIVE, SYSDATE + 1) >
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND BOOKS.BONUS_RULE IS NOT NULL
                           AND TH.BOOK_TYPE_CODE(+) = DIST_BOOK
                           AND TH.TRANSACTION_HEADER_ID(+) =
                               DH.TRANSACTION_HEADER_ID_OUT
                           AND TH.DATE_EFFECTIVE(+) BETWEEN TOD AND UCD
                           AND DH.BOOK_TYPE_CODE = DIST_BOOK
                           AND DH.DATE_EFFECTIVE <= UCD
                           AND NVL (DH.DATE_INEFFECTIVE, SYSDATE) > TOD;
            ELSE
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'in else for insert xxdo_fa_reserve_ledger_gt 1:');

                INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_GT (
                                ASSET_ID,
                                DH_CCID,
                                DEPRN_RESERVE_ACCT,
                                DATE_PLACED_IN_SERVICE,
                                METHOD_CODE,
                                LIFE,
                                RATE,
                                CAPACITY,
                                COST,
                                DEPRN_AMOUNT,
                                YTD_DEPRN,
                                DEPRN_RESERVE,
                                PERCENT,
                                TRANSACTION_TYPE,
                                PERIOD_COUNTER,
                                DATE_EFFECTIVE,
                                RESERVE_ACCT)
                    SELECT DH.ASSET_ID ASSET_ID, DH.CODE_COMBINATION_ID DH_CCID, CB.DEPRN_RESERVE_ACCT RSV_ACCOUNT,
                           BOOKS.DATE_PLACED_IN_SERVICE START_DATE, BOOKS.DEPRN_METHOD_CODE METHOD, BOOKS.LIFE_IN_MONTHS LIFE,
                           BOOKS.ADJUSTED_RATE RATE, BOOKS.PRODUCTION_CAPACITY CAPACITY, DD_BONUS.COST COST,
                           DECODE (DD_BONUS.PERIOD_COUNTER, UPC, DD_BONUS.DEPRN_AMOUNT - DD_BONUS.BONUS_DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD_BONUS.PERIOD_COUNTER), 1, 0, DD_BONUS.YTD_DEPRN - DD_BONUS.BONUS_YTD_DEPRN) YTD_DEPRN, DD_BONUS.DEPRN_RESERVE - DD_BONUS.BONUS_DEPRN_RESERVE DEPRN_RESERVE,
                           DECODE (TH.TRANSACTION_TYPE_CODE, NULL, DH.UNITS_ASSIGNED / AH.UNITS * 100) PERCENT, DECODE (TH.TRANSACTION_TYPE_CODE,  NULL, DECODE (TH_RT.TRANSACTION_TYPE_CODE, 'FULL RETIREMENT', 'F', DECODE (BOOKS.DEPRECIATE_FLAG, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') T_TYPE, DD_BONUS.PERIOD_COUNTER,
                           NVL (TH.DATE_EFFECTIVE, UCD), ''
                      FROM FA_DEPRN_DETAIL DD_BONUS, FA_ASSET_HISTORY AH, FA_TRANSACTION_HEADERS TH,
                           FA_TRANSACTION_HEADERS TH_RT, FA_BOOKS BOOKS, FA_DISTRIBUTION_HISTORY DH,
                           FA_CATEGORY_BOOKS CB
                     WHERE     CB.BOOK_TYPE_CODE = BOOK
                           AND CB.CATEGORY_ID = AH.CATEGORY_ID
                           AND AH.ASSET_ID = DH.ASSET_ID
                           AND AH.DATE_EFFECTIVE <
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (AH.DATE_INEFFECTIVE, SYSDATE) >=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND AH.ASSET_TYPE = 'CAPITALIZED'
                           AND DD_BONUS.BOOK_TYPE_CODE = BOOK
                           AND DD_BONUS.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                           AND DD_BONUS.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID = DH.ASSET_ID
                                       AND DD_SUB.DISTRIBUTION_ID =
                                           DH.DISTRIBUTION_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND TH_RT.BOOK_TYPE_CODE = BOOK
                           AND TH_RT.TRANSACTION_HEADER_ID =
                               BOOKS.TRANSACTION_HEADER_ID_IN
                           AND BOOKS.BOOK_TYPE_CODE = BOOK
                           AND BOOKS.ASSET_ID = DH.ASSET_ID
                           AND NVL (BOOKS.PERIOD_COUNTER_FULLY_RETIRED, UPC) >=
                               TPC
                           AND BOOKS.DATE_EFFECTIVE <=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (BOOKS.DATE_INEFFECTIVE, SYSDATE + 1) >
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND TH.BOOK_TYPE_CODE(+) = DIST_BOOK
                           AND TH.TRANSACTION_HEADER_ID(+) =
                               DH.TRANSACTION_HEADER_ID_OUT
                           AND TH.DATE_EFFECTIVE(+) BETWEEN TOD AND UCD
                           AND DH.BOOK_TYPE_CODE = DIST_BOOK
                           AND DH.DATE_EFFECTIVE <= UCD
                           AND NVL (DH.DATE_INEFFECTIVE, SYSDATE) > TOD
                    UNION ALL
                    SELECT DH.ASSET_ID ASSET_ID, DH.CODE_COMBINATION_ID DH_CCID, CB.BONUS_DEPRN_RESERVE_ACCT RSV_ACCOUNT,
                           BOOKS.DATE_PLACED_IN_SERVICE START_DATE, BOOKS.DEPRN_METHOD_CODE METHOD, BOOKS.LIFE_IN_MONTHS LIFE,
                           BOOKS.ADJUSTED_RATE RATE, BOOKS.PRODUCTION_CAPACITY CAPACITY, 0 COST,
                           DECODE (DD.PERIOD_COUNTER, UPC, DD.BONUS_DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD.PERIOD_COUNTER), 1, 0, DD.BONUS_YTD_DEPRN) YTD_DEPRN, DD.BONUS_DEPRN_RESERVE DEPRN_RESERVE,
                           0 PERCENT, 'B' T_TYPE, DD.PERIOD_COUNTER,
                           NVL (TH.DATE_EFFECTIVE, UCD), CB.BONUS_DEPRN_EXPENSE_ACCT
                      FROM FA_DEPRN_DETAIL DD, FA_ASSET_HISTORY AH, FA_TRANSACTION_HEADERS TH,
                           FA_TRANSACTION_HEADERS TH_RT, FA_BOOKS BOOKS, FA_DISTRIBUTION_HISTORY DH,
                           FA_CATEGORY_BOOKS CB
                     WHERE     CB.BOOK_TYPE_CODE = BOOK
                           AND CB.CATEGORY_ID = AH.CATEGORY_ID
                           AND AH.ASSET_ID = DH.ASSET_ID
                           AND AH.DATE_EFFECTIVE <
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (AH.DATE_INEFFECTIVE, SYSDATE) >=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND AH.ASSET_TYPE = 'CAPITALIZED'
                           AND DD.BOOK_TYPE_CODE = BOOK
                           AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                           AND DD.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID = DH.ASSET_ID
                                       AND DD_SUB.DISTRIBUTION_ID =
                                           DH.DISTRIBUTION_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND TH_RT.BOOK_TYPE_CODE = BOOK
                           AND TH_RT.TRANSACTION_HEADER_ID =
                               BOOKS.TRANSACTION_HEADER_ID_IN
                           AND BOOKS.BOOK_TYPE_CODE = BOOK
                           AND BOOKS.ASSET_ID = DH.ASSET_ID
                           AND NVL (BOOKS.PERIOD_COUNTER_FULLY_RETIRED, UPC) >=
                               TPC
                           AND BOOKS.DATE_EFFECTIVE <=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (BOOKS.DATE_INEFFECTIVE, SYSDATE + 1) >
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND BOOKS.BONUS_RULE IS NOT NULL
                           AND TH.BOOK_TYPE_CODE(+) = DIST_BOOK
                           AND TH.TRANSACTION_HEADER_ID(+) =
                               DH.TRANSACTION_HEADER_ID_OUT
                           AND TH.DATE_EFFECTIVE(+) BETWEEN TOD AND UCD
                           AND DH.BOOK_TYPE_CODE = DIST_BOOK
                           AND DH.DATE_EFFECTIVE <= UCD
                           AND NVL (DH.DATE_INEFFECTIVE, SYSDATE) > TOD;
            END IF;
        --         COMMIT; --6
        -- RUN ONLY IF CRL INSTALLED
        ELSIF (NVL (FND_PROFILE.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            -- INSERT NON-GROUP DETAILS
            IF (H_REPORTING_FLAG = 'R')
            THEN
                INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_GT (ASSET_ID, DH_CCID, DEPRN_RESERVE_ACCT, DATE_PLACED_IN_SERVICE, METHOD_CODE, LIFE, RATE, CAPACITY, COST, DEPRN_AMOUNT, YTD_DEPRN, DEPRN_RESERVE, PERCENT, TRANSACTION_TYPE, PERIOD_COUNTER
                                                            , DATE_EFFECTIVE)
                    SELECT DH.ASSET_ID ASSET_ID, DH.CODE_COMBINATION_ID DH_CCID, CB.DEPRN_RESERVE_ACCT RSV_ACCOUNT,
                           BOOKS.DATE_PLACED_IN_SERVICE START_DATE, BOOKS.DEPRN_METHOD_CODE METHOD, BOOKS.LIFE_IN_MONTHS LIFE,
                           BOOKS.ADJUSTED_RATE RATE, BOOKS.PRODUCTION_CAPACITY CAPACITY, DD.COST COST,
                           DECODE (DD.PERIOD_COUNTER, UPC, DD.DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD.PERIOD_COUNTER), 1, 0, DD.YTD_DEPRN) YTD_DEPRN, DD.DEPRN_RESERVE DEPRN_RESERVE,
                           DECODE (TH.TRANSACTION_TYPE_CODE, NULL, DH.UNITS_ASSIGNED / AH.UNITS * 100) PERCENT, DECODE (TH.TRANSACTION_TYPE_CODE,  NULL, DECODE (TH_RT.TRANSACTION_TYPE_CODE, 'FULL RETIREMENT', 'F', DECODE (BOOKS.DEPRECIATE_FLAG, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') T_TYPE, DD.PERIOD_COUNTER,
                           NVL (TH.DATE_EFFECTIVE, UCD)
                      FROM FA_DEPRN_DETAIL_MRC_V DD, FA_ASSET_HISTORY AH, FA_TRANSACTION_HEADERS TH,
                           FA_TRANSACTION_HEADERS TH_RT, FA_BOOKS_MRC_V BOOKS, FA_DISTRIBUTION_HISTORY DH,
                           FA_CATEGORY_BOOKS CB
                     WHERE            -- START CUA  - EXCLUDE THE GROUP ASSETS
                               BOOKS.GROUP_ASSET_ID IS NULL
                           AND                                      -- END CUA
                               CB.BOOK_TYPE_CODE = BOOK
                           AND CB.CATEGORY_ID = AH.CATEGORY_ID
                           AND AH.ASSET_ID = DH.ASSET_ID
                           AND AH.DATE_EFFECTIVE <
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (AH.DATE_INEFFECTIVE, SYSDATE) >=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND AH.ASSET_TYPE = 'CAPITALIZED'
                           AND DD.BOOK_TYPE_CODE = BOOK
                           AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                           AND DD.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL_MRC_V DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID = DH.ASSET_ID
                                       AND DD_SUB.DISTRIBUTION_ID =
                                           DH.DISTRIBUTION_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND TH_RT.BOOK_TYPE_CODE = BOOK
                           AND TH_RT.TRANSACTION_HEADER_ID =
                               BOOKS.TRANSACTION_HEADER_ID_IN
                           AND BOOKS.BOOK_TYPE_CODE = BOOK
                           AND BOOKS.ASSET_ID = DH.ASSET_ID
                           AND NVL (BOOKS.PERIOD_COUNTER_FULLY_RETIRED, UPC) >=
                               TPC
                           AND BOOKS.DATE_EFFECTIVE <=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (BOOKS.DATE_INEFFECTIVE, SYSDATE + 1) >
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND TH.BOOK_TYPE_CODE(+) = DIST_BOOK
                           AND TH.TRANSACTION_HEADER_ID(+) =
                               DH.TRANSACTION_HEADER_ID_OUT
                           AND TH.DATE_EFFECTIVE(+) BETWEEN TOD AND UCD
                           AND DH.BOOK_TYPE_CODE = DIST_BOOK
                           AND DH.DATE_EFFECTIVE <= UCD
                           AND NVL (DH.DATE_INEFFECTIVE, SYSDATE) > TOD
                           AND        -- START CUA  - EXCLUDE THE GROUP ASSETS
                               BOOKS.GROUP_ASSET_ID IS NULL;
            ELSE
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'in else for insert xxdo_fa_reserve_ledger_gt 2:');

                INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_GT (ASSET_ID, DH_CCID, DEPRN_RESERVE_ACCT, DATE_PLACED_IN_SERVICE, METHOD_CODE, LIFE, RATE, CAPACITY, COST, DEPRN_AMOUNT, YTD_DEPRN, DEPRN_RESERVE, PERCENT, TRANSACTION_TYPE, PERIOD_COUNTER
                                                            , DATE_EFFECTIVE)
                    SELECT DH.ASSET_ID ASSET_ID, DH.CODE_COMBINATION_ID DH_CCID, CB.DEPRN_RESERVE_ACCT RSV_ACCOUNT,
                           BOOKS.DATE_PLACED_IN_SERVICE START_DATE, BOOKS.DEPRN_METHOD_CODE METHOD, BOOKS.LIFE_IN_MONTHS LIFE,
                           BOOKS.ADJUSTED_RATE RATE, BOOKS.PRODUCTION_CAPACITY CAPACITY, DD.COST COST,
                           DECODE (DD.PERIOD_COUNTER, UPC, DD.DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD.PERIOD_COUNTER), 1, 0, DD.YTD_DEPRN) YTD_DEPRN, DD.DEPRN_RESERVE DEPRN_RESERVE,
                           DECODE (TH.TRANSACTION_TYPE_CODE, NULL, DH.UNITS_ASSIGNED / AH.UNITS * 100) PERCENT, DECODE (TH.TRANSACTION_TYPE_CODE,  NULL, DECODE (TH_RT.TRANSACTION_TYPE_CODE, 'FULL RETIREMENT', 'F', DECODE (BOOKS.DEPRECIATE_FLAG, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') T_TYPE, DD.PERIOD_COUNTER,
                           NVL (TH.DATE_EFFECTIVE, UCD)
                      FROM FA_DEPRN_DETAIL DD, FA_ASSET_HISTORY AH, FA_TRANSACTION_HEADERS TH,
                           FA_TRANSACTION_HEADERS TH_RT, FA_BOOKS BOOKS, FA_DISTRIBUTION_HISTORY DH,
                           FA_CATEGORY_BOOKS CB
                     WHERE            -- START CUA  - EXCLUDE THE GROUP ASSETS
                               BOOKS.GROUP_ASSET_ID IS NULL
                           AND                                      -- END CUA
                               CB.BOOK_TYPE_CODE = BOOK
                           AND CB.CATEGORY_ID = AH.CATEGORY_ID
                           AND AH.ASSET_ID = DH.ASSET_ID
                           AND AH.DATE_EFFECTIVE <
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (AH.DATE_INEFFECTIVE, SYSDATE) >=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND AH.ASSET_TYPE = 'CAPITALIZED'
                           AND DD.BOOK_TYPE_CODE = BOOK
                           AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                           AND DD.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID = DH.ASSET_ID
                                       AND DD_SUB.DISTRIBUTION_ID =
                                           DH.DISTRIBUTION_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND TH_RT.BOOK_TYPE_CODE = BOOK
                           AND TH_RT.TRANSACTION_HEADER_ID =
                               BOOKS.TRANSACTION_HEADER_ID_IN
                           AND BOOKS.BOOK_TYPE_CODE = BOOK
                           AND BOOKS.ASSET_ID = DH.ASSET_ID
                           AND NVL (BOOKS.PERIOD_COUNTER_FULLY_RETIRED, UPC) >=
                               TPC
                           AND BOOKS.DATE_EFFECTIVE <=
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND NVL (BOOKS.DATE_INEFFECTIVE, SYSDATE + 1) >
                               NVL (TH.DATE_EFFECTIVE, UCD)
                           AND TH.BOOK_TYPE_CODE(+) = DIST_BOOK
                           AND TH.TRANSACTION_HEADER_ID(+) =
                               DH.TRANSACTION_HEADER_ID_OUT
                           AND TH.DATE_EFFECTIVE(+) BETWEEN TOD AND UCD
                           AND DH.BOOK_TYPE_CODE = DIST_BOOK
                           AND DH.DATE_EFFECTIVE <= UCD
                           AND NVL (DH.DATE_INEFFECTIVE, SYSDATE) > TOD
                           AND        -- START CUA  - EXCLUDE THE GROUP ASSETS
                               BOOKS.GROUP_ASSET_ID IS NULL;
            END IF;

            -- END CUA

            -- INSERT THE GROUP DEPRECIATION DETAILS
            IF (H_REPORTING_FLAG = 'R')
            THEN
                INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_GT (ASSET_ID, DH_CCID, DEPRN_RESERVE_ACCT, DATE_PLACED_IN_SERVICE, METHOD_CODE, LIFE, RATE, CAPACITY, COST, DEPRN_AMOUNT, YTD_DEPRN, DEPRN_RESERVE, PERCENT, TRANSACTION_TYPE, PERIOD_COUNTER
                                                            , DATE_EFFECTIVE)
                    SELECT GAR.GROUP_ASSET_ID ASSET_ID, GAD.DEPRN_EXPENSE_ACCT_CCID CH_CCID, GAD.DEPRN_RESERVE_ACCT_CCID RSV_ACCOUNT,
                           GAR.DEPRN_START_DATE START_DATE, GAR.DEPRN_METHOD_CODE METHOD, GAR.LIFE_IN_MONTHS LIFE,
                           GAR.ADJUSTED_RATE RATE, GAR.PRODUCTION_CAPACITY CAPACITY, DD.ADJUSTED_COST COST,
                           DECODE (DD.PERIOD_COUNTER, UPC, DD.DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD.PERIOD_COUNTER), 1, 0, DD.YTD_DEPRN) YTD_DEPRN, DD.DEPRN_RESERVE DEPRN_RESERVE,
                           /* ROUND (DECODE (TH.TRANSACTION_TYPE_CODE, NULL,
                                DH.UNITS_ASSIGNED / AH.UNITS * 100),2)
                                                    PERCENT,
                            DECODE (TH.TRANSACTION_TYPE_CODE, NULL,
                            DECODE (TH_RT.TRANSACTION_TYPE_CODE,
                                'FULL RETIREMENT', 'F',
                                DECODE (BOOKS.DEPRECIATE_FLAG, 'NO', 'N')),
                                    'TRANSFER', 'T',
                                    'TRANSFER OUT', 'P',
                            'RECLASS', 'R')                    T_TYPE,
                            DD.PERIOD_COUNTER,
                            NVL(TH.DATE_EFFECTIVE, UCD) */
                           100 PERCENT, 'G' T_TYPE, DD.PERIOD_COUNTER,
                           UCD
                      FROM FA_DEPRN_SUMMARY_MRC_V DD, FA_GROUP_ASSET_RULES GAR, FA_GROUP_ASSET_DEFAULT GAD,
                           FA_DEPRN_PERIODS_MRC_V DP
                     WHERE     DD.BOOK_TYPE_CODE = BOOK
                           AND DD.ASSET_ID = GAR.GROUP_ASSET_ID
                           AND GAD.SUPER_GROUP_ID IS NULL           -- MPOWELL
                           AND GAR.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                           AND GAD.BOOK_TYPE_CODE = GAR.BOOK_TYPE_CODE
                           AND GAD.GROUP_ASSET_ID = GAR.GROUP_ASSET_ID
                           AND DD.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL_MRC_V DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID =
                                           GAR.GROUP_ASSET_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND DD.PERIOD_COUNTER = DP.PERIOD_COUNTER
                           AND DD.BOOK_TYPE_CODE = DP.BOOK_TYPE_CODE
                           AND GAR.DATE_EFFECTIVE <=
                               DP.CALENDAR_PERIOD_CLOSE_DATE
                           -- MWOODWAR
                           AND NVL (GAR.DATE_INEFFECTIVE,
                                    (DP.CALENDAR_PERIOD_CLOSE_DATE + 1)) >
                               DP.CALENDAR_PERIOD_CLOSE_DATE;      -- MWOODWAR
            ELSE
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'in else for insert xxdo_fa_reserve_ledger_gt 3:');

                INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_GT (ASSET_ID, DH_CCID, DEPRN_RESERVE_ACCT, DATE_PLACED_IN_SERVICE, METHOD_CODE, LIFE, RATE, CAPACITY, COST, DEPRN_AMOUNT, YTD_DEPRN, DEPRN_RESERVE, PERCENT, TRANSACTION_TYPE, PERIOD_COUNTER
                                                            , DATE_EFFECTIVE)
                    SELECT GAR.GROUP_ASSET_ID ASSET_ID, GAD.DEPRN_EXPENSE_ACCT_CCID CH_CCID, GAD.DEPRN_RESERVE_ACCT_CCID RSV_ACCOUNT,
                           GAR.DEPRN_START_DATE START_DATE, GAR.DEPRN_METHOD_CODE METHOD, GAR.LIFE_IN_MONTHS LIFE,
                           GAR.ADJUSTED_RATE RATE, GAR.PRODUCTION_CAPACITY CAPACITY, DD.ADJUSTED_COST COST,
                           DECODE (DD.PERIOD_COUNTER, UPC, DD.DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD.PERIOD_COUNTER), 1, 0, DD.YTD_DEPRN) YTD_DEPRN, DD.DEPRN_RESERVE DEPRN_RESERVE,
                           /* ROUND (DECODE (TH.TRANSACTION_TYPE_CODE, NULL,
                                DH.UNITS_ASSIGNED / AH.UNITS * 100),2)
                                                    PERCENT,
                            DECODE (TH.TRANSACTION_TYPE_CODE, NULL,
                            DECODE (TH_RT.TRANSACTION_TYPE_CODE,
                                'FULL RETIREMENT', 'F',
                                DECODE (BOOKS.DEPRECIATE_FLAG, 'NO', 'N')),
                                    'TRANSFER', 'T',
                                    'TRANSFER OUT', 'P',
                            'RECLASS', 'R')                    T_TYPE,
                            DD.PERIOD_COUNTER,
                            NVL(TH.DATE_EFFECTIVE, UCD) */
                           100 PERCENT, 'G' T_TYPE, DD.PERIOD_COUNTER,
                           UCD
                      FROM FA_DEPRN_SUMMARY DD, FA_GROUP_ASSET_RULES GAR, FA_GROUP_ASSET_DEFAULT GAD,
                           FA_DEPRN_PERIODS DP
                     WHERE     DD.BOOK_TYPE_CODE = BOOK
                           AND DD.ASSET_ID = GAR.GROUP_ASSET_ID
                           AND GAD.SUPER_GROUP_ID IS NULL           -- MPOWELL
                           AND GAR.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                           AND GAD.BOOK_TYPE_CODE = GAR.BOOK_TYPE_CODE
                           AND GAD.GROUP_ASSET_ID = GAR.GROUP_ASSET_ID
                           AND DD.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID =
                                           GAR.GROUP_ASSET_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND DD.PERIOD_COUNTER = DP.PERIOD_COUNTER
                           AND DD.BOOK_TYPE_CODE = DP.BOOK_TYPE_CODE
                           AND GAR.DATE_EFFECTIVE <=
                               DP.CALENDAR_PERIOD_CLOSE_DATE
                           -- MWOODWAR
                           AND NVL (GAR.DATE_INEFFECTIVE,
                                    (DP.CALENDAR_PERIOD_CLOSE_DATE + 1)) >
                               DP.CALENDAR_PERIOD_CLOSE_DATE;      -- MWOODWAR
            END IF;

            -- INSERT THE SUPERGROUP DEPRECIATION DETAILS    MPOWELL
            IF (H_REPORTING_FLAG = 'R')
            THEN
                INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_GT (ASSET_ID, DH_CCID, DEPRN_RESERVE_ACCT, DATE_PLACED_IN_SERVICE, METHOD_CODE, LIFE, RATE, CAPACITY, COST, DEPRN_AMOUNT, YTD_DEPRN, DEPRN_RESERVE, PERCENT, TRANSACTION_TYPE, PERIOD_COUNTER
                                                            , DATE_EFFECTIVE)
                    SELECT GAR.GROUP_ASSET_ID ASSET_ID, GAD.DEPRN_EXPENSE_ACCT_CCID DH_CCID, GAD.DEPRN_RESERVE_ACCT_CCID RSV_ACCOUNT,
                           GAR.DEPRN_START_DATE START_DATE, SGR.DEPRN_METHOD_CODE METHOD, -- MPOWELL
                                                                                          GAR.LIFE_IN_MONTHS LIFE,
                           SGR.ADJUSTED_RATE RATE,                  -- MPOWELL
                                                   GAR.PRODUCTION_CAPACITY CAPACITY, DD.ADJUSTED_COST COST,
                           DECODE (DD.PERIOD_COUNTER, UPC, DD.DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD.PERIOD_COUNTER), 1, 0, DD.YTD_DEPRN) YTD_DEPRN, DD.DEPRN_RESERVE DEPRN_RESERVE,
                           100 PERCENT, 'G' T_TYPE, DD.PERIOD_COUNTER,
                           UCD
                      FROM FA_DEPRN_SUMMARY_MRC_V DD, FA_GROUP_ASSET_RULES GAR, FA_GROUP_ASSET_DEFAULT GAD,
                           FA_SUPER_GROUP_RULES SGR, FA_DEPRN_PERIODS_MRC_V DP
                     WHERE     DD.BOOK_TYPE_CODE = BOOK
                           AND DD.ASSET_ID = GAR.GROUP_ASSET_ID
                           AND GAR.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                           AND GAD.SUPER_GROUP_ID = SGR.SUPER_GROUP_ID -- MPOWELL
                           AND GAD.BOOK_TYPE_CODE = SGR.BOOK_TYPE_CODE -- MPOWELL
                           AND GAD.BOOK_TYPE_CODE = GAR.BOOK_TYPE_CODE
                           AND GAD.GROUP_ASSET_ID = GAR.GROUP_ASSET_ID
                           AND DD.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL_MRC_V DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID =
                                           GAR.GROUP_ASSET_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND DD.PERIOD_COUNTER = DP.PERIOD_COUNTER
                           AND DD.BOOK_TYPE_CODE = DP.BOOK_TYPE_CODE
                           AND GAR.DATE_EFFECTIVE <=
                               DP.CALENDAR_PERIOD_CLOSE_DATE
                           AND NVL (GAR.DATE_INEFFECTIVE,
                                    (DP.CALENDAR_PERIOD_CLOSE_DATE + 1)) >
                               DP.CALENDAR_PERIOD_CLOSE_DATE
                           AND SGR.DATE_EFFECTIVE <=
                               DP.CALENDAR_PERIOD_CLOSE_DATE
                           AND NVL (SGR.DATE_INEFFECTIVE,
                                    (DP.CALENDAR_PERIOD_CLOSE_DATE + 1)) >
                               DP.CALENDAR_PERIOD_CLOSE_DATE;
            ELSE
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'in else for insert xxdo_fa_reserve_ledger_gt 4:');

                INSERT INTO XXDO.XXDO_FA_RESERVE_LEDGER_GT (ASSET_ID, DH_CCID, DEPRN_RESERVE_ACCT, DATE_PLACED_IN_SERVICE, METHOD_CODE, LIFE, RATE, CAPACITY, COST, DEPRN_AMOUNT, YTD_DEPRN, DEPRN_RESERVE, PERCENT, TRANSACTION_TYPE, PERIOD_COUNTER
                                                            , DATE_EFFECTIVE)
                    SELECT GAR.GROUP_ASSET_ID ASSET_ID, GAD.DEPRN_EXPENSE_ACCT_CCID DH_CCID, GAD.DEPRN_RESERVE_ACCT_CCID RSV_ACCOUNT,
                           GAR.DEPRN_START_DATE START_DATE, SGR.DEPRN_METHOD_CODE METHOD, -- MPOWELL
                                                                                          GAR.LIFE_IN_MONTHS LIFE,
                           SGR.ADJUSTED_RATE RATE,                  -- MPOWELL
                                                   GAR.PRODUCTION_CAPACITY CAPACITY, DD.ADJUSTED_COST COST,
                           DECODE (DD.PERIOD_COUNTER, UPC, DD.DEPRN_AMOUNT, 0) DEPRN_AMOUNT, DECODE (SIGN (TPC - DD.PERIOD_COUNTER), 1, 0, DD.YTD_DEPRN) YTD_DEPRN, DD.DEPRN_RESERVE DEPRN_RESERVE,
                           100 PERCENT, 'G' T_TYPE, DD.PERIOD_COUNTER,
                           UCD
                      FROM FA_DEPRN_SUMMARY DD, FA_GROUP_ASSET_RULES GAR, FA_GROUP_ASSET_DEFAULT GAD,
                           FA_SUPER_GROUP_RULES SGR, FA_DEPRN_PERIODS DP
                     WHERE     DD.BOOK_TYPE_CODE = BOOK
                           AND DD.ASSET_ID = GAR.GROUP_ASSET_ID
                           AND GAR.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                           AND GAD.SUPER_GROUP_ID = SGR.SUPER_GROUP_ID -- MPOWELL
                           AND GAD.BOOK_TYPE_CODE = SGR.BOOK_TYPE_CODE -- MPOWELL
                           AND GAD.BOOK_TYPE_CODE = GAR.BOOK_TYPE_CODE
                           AND GAD.GROUP_ASSET_ID = GAR.GROUP_ASSET_ID
                           AND DD.PERIOD_COUNTER =
                               (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                  FROM FA_DEPRN_DETAIL DD_SUB
                                 WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                       AND DD_SUB.ASSET_ID =
                                           GAR.GROUP_ASSET_ID
                                       AND DD_SUB.PERIOD_COUNTER <= UPC)
                           AND DD.PERIOD_COUNTER = DP.PERIOD_COUNTER
                           AND DD.BOOK_TYPE_CODE = DP.BOOK_TYPE_CODE
                           AND GAR.DATE_EFFECTIVE <=
                               DP.CALENDAR_PERIOD_CLOSE_DATE
                           AND NVL (GAR.DATE_INEFFECTIVE,
                                    (DP.CALENDAR_PERIOD_CLOSE_DATE + 1)) >
                               DP.CALENDAR_PERIOD_CLOSE_DATE
                           AND SGR.DATE_EFFECTIVE <=
                               DP.CALENDAR_PERIOD_CLOSE_DATE
                           AND NVL (SGR.DATE_INEFFECTIVE,
                                    (DP.CALENDAR_PERIOD_CLOSE_DATE + 1)) >
                               DP.CALENDAR_PERIOD_CLOSE_DATE;
            END IF;
        END IF;                                             --END OF CRL CHECK
    --      COMMIT;--7
    EXCEPTION
        WHEN OTHERS
        THEN
            -- RETCODE := SQLCODE;
            --  ERRBUF := SQLERRM;
            DBMS_OUTPUT.PUT_LINE (SQLERRM);
    --SRW.MESSAGE (1000, ERRBUF);
    --SRW.MESSAGE (1000, OPERATION);
    END FA_RSVLDG_PROC;

    PROCEDURE INSERT_INFO (BOOK IN VARCHAR2, START_PERIOD_NAME IN VARCHAR2, END_PERIOD_NAME IN VARCHAR2
                           , REPORT_TYPE IN VARCHAR2)
    --  ADJ_MODE        IN    VARCHAR2)
    IS
        PERIOD1_PC                 NUMBER;
        PERIOD1_POD                DATE;
        PERIOD1_PCD                DATE;
        PERIOD2_PC                 NUMBER;
        PERIOD2_PCD                DATE;
        DISTRIBUTION_SOURCE_BOOK   VARCHAR2 (15);
        BALANCE_TYPE               VARCHAR2 (2);
        H_SET_OF_BOOKS_ID          NUMBER;
        H_REPORTING_FLAG           VARCHAR2 (1);
        H_TEST                     VARCHAR2 (100);
    BEGIN
        -- GET MRC RELATED INFO
        BEGIN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'insert_info proc start_period_name:' || START_PERIOD_NAME);
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'insert_info proc end_period_name:' || END_PERIOD_NAME);
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'insert_info proc report_type:' || REPORT_TYPE);

            SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
              INTO H_SET_OF_BOOKS_ID
              FROM DUAL;

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'insert_info proc h_set_of_books_id:' || H_SET_OF_BOOKS_ID);
        EXCEPTION
            WHEN OTHERS
            THEN
                H_SET_OF_BOOKS_ID   := NULL;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'insert_info proc in exception sqlerrm:' || SQLERRM);
        END;

        IF (H_SET_OF_BOOKS_ID IS NOT NULL)
        THEN
            IF NOT FA_CACHE_PKG.FAZCSOB (
                       X_SET_OF_BOOKS_ID     => H_SET_OF_BOOKS_ID,
                       X_MRC_SOB_TYPE_CODE   => H_REPORTING_FLAG)
            THEN
                RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
            END IF;
        ELSE
            H_REPORTING_FLAG   := 'P';
        END IF;

        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'insert_info proc h_reporting_flag:' || H_REPORTING_FLAG);

        IF (H_REPORTING_FLAG = 'R')
        THEN
            SELECT P1.PERIOD_COUNTER, P1.PERIOD_OPEN_DATE, NVL (P1.PERIOD_CLOSE_DATE, SYSDATE),
                   P2.PERIOD_COUNTER, NVL (P2.PERIOD_CLOSE_DATE, SYSDATE), BC.DISTRIBUTION_SOURCE_BOOK
              INTO PERIOD1_PC, PERIOD1_POD, PERIOD1_PCD, PERIOD2_PC,
                             PERIOD2_PCD, DISTRIBUTION_SOURCE_BOOK
              FROM FA_DEPRN_PERIODS_MRC_V P1, FA_DEPRN_PERIODS_MRC_V P2, FA_BOOK_CONTROLS_MRC_V BC
             WHERE     BC.BOOK_TYPE_CODE = BOOK
                   AND P1.BOOK_TYPE_CODE = BOOK
                   AND P1.PERIOD_NAME = START_PERIOD_NAME
                   AND P2.BOOK_TYPE_CODE = BOOK
                   AND P2.PERIOD_NAME = END_PERIOD_NAME;
        ELSE
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'insert_info proc else:');

            SELECT P1.PERIOD_COUNTER, P1.PERIOD_OPEN_DATE, NVL (P1.PERIOD_CLOSE_DATE, SYSDATE),
                   P2.PERIOD_COUNTER, NVL (P2.PERIOD_CLOSE_DATE, SYSDATE), BC.DISTRIBUTION_SOURCE_BOOK
              INTO PERIOD1_PC, PERIOD1_POD, PERIOD1_PCD, PERIOD2_PC,
                             PERIOD2_PCD, DISTRIBUTION_SOURCE_BOOK
              FROM FA_DEPRN_PERIODS P1, FA_DEPRN_PERIODS P2, FA_BOOK_CONTROLS BC
             WHERE     BC.BOOK_TYPE_CODE = BOOK
                   AND P1.BOOK_TYPE_CODE = BOOK
                   AND P1.PERIOD_NAME = START_PERIOD_NAME
                   AND P2.BOOK_TYPE_CODE = BOOK
                   AND P2.PERIOD_NAME = END_PERIOD_NAME;
        END IF;

        IF (REPORT_TYPE = 'RESERVE' OR REPORT_TYPE = 'REVAL RESERVE')
        THEN
            BALANCE_TYPE   := 'CR';
        ELSE
            BALANCE_TYPE   := 'DR';
        END IF;

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'insert_info proc balance_type: ' || BALANCE_TYPE);
        /* DELETE FROM XXDO.XXDO_FA_BALANCES_REPORT_GT; */

        /*THIS SECTION OF CODE NEEDS TO BE REPLACED DUE TO THE FACT THAT IN 11.5 THE
        FA_LOOKUPS TABLE HAS BEEN SPLIT INTO TWO TABLES: FA_LOOKUPS_B AND
        FA_LOOKUPS_TL . FA_LOOKUPS IS A SYNONYM FOR A VIEW OF A JOIN OF THESE TWO
        TABLES. SO INSERTS AND DELETES WONT WORK ON FA_LOOKUPS, AND INSTEAD MUST BE
        PERFORMED ON BOTH TABLES. CHANGES MADE BY CBACHAND, 5/25/99
           DELETE FROM FA_LOOKUPS
           WHERE LOOKUP_TYPE = 'REPORT TYPE';

           INSERT INTO FA_LOOKUPS
           (LOOKUP_TYPE,
            LOOKUP_CODE,
            LAST_UPDATED_BY,
            LAST_UPDATE_DATE,
            MEANING,
            ENABLED_FLAG)
            VALUES
           ('REPORT TYPE',
            REPORT_TYPE,
            1,
            SYSDATE,
            REPORT_TYPE,
            'Y');                */
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'insert_info proc b4 delete ');

        DELETE FROM FA_LOOKUPS_B
              WHERE LOOKUP_TYPE = 'REPORT TYPE' AND LOOKUP_CODE = REPORT_TYPE;

        DELETE FROM FA_LOOKUPS_TL
              WHERE LOOKUP_TYPE = 'REPORT TYPE' AND LOOKUP_CODE = REPORT_TYPE;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'insert_info proc aftr delete ');

        INSERT INTO FA_LOOKUPS_B (LOOKUP_TYPE, LOOKUP_CODE, LAST_UPDATED_BY,
                                  LAST_UPDATE_DATE, ENABLED_FLAG)
             VALUES ('REPORT TYPE', REPORT_TYPE, 1,
                     SYSDATE, 'Y');

        INSERT INTO FA_LOOKUPS_TL (LOOKUP_TYPE, LOOKUP_CODE, MEANING,
                                   LAST_UPDATE_DATE, LAST_UPDATED_BY, LANGUAGE
                                   , SOURCE_LANG)
            SELECT 'REPORT TYPE', REPORT_TYPE, REPORT_TYPE,
                   SYSDATE, 1, L.LANGUAGE_CODE,
                   USERENV ('LANG')
              FROM FND_LANGUAGES L
             WHERE     L.INSTALLED_FLAG IN ('I', 'B')
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM FA_LOOKUPS_TL T
                             WHERE     T.LOOKUP_TYPE = 'REPORT TYPE'
                                   AND T.LOOKUP_CODE = REPORT_TYPE
                                   AND T.LANGUAGE = L.LANGUAGE_CODE);

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'insert_info proc aftr insert ');
        /* GET BEGINNING BALANCE */
        /* USE PERIOD1_PC-1, TO GET BALANCE AS OF END OF PERIOD IMMEDIATELY
           PRECEDING PERIOD1_PC */
        GET_BALANCE (BOOK, DISTRIBUTION_SOURCE_BOOK, PERIOD1_PC - 1,
                     PERIOD1_PC - 1, PERIOD1_POD, PERIOD1_PCD,
                     REPORT_TYPE, BALANCE_TYPE, 'BEGIN');

        -- RUN ONLY IF CRL INSTALLED
        IF (NVL (FND_PROFILE.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            GET_BALANCE_GROUP_BEGIN (BOOK, DISTRIBUTION_SOURCE_BOOK, PERIOD1_PC - 1, PERIOD1_PC - 1, PERIOD1_POD, PERIOD1_PCD
                                     , REPORT_TYPE, BALANCE_TYPE, 'BEGIN');
        END IF;

        /* GET ENDING BALANCE */
        GET_BALANCE (BOOK, DISTRIBUTION_SOURCE_BOOK, PERIOD2_PC,
                     PERIOD1_PC - 1, PERIOD2_PCD, PERIOD2_PCD,
                     REPORT_TYPE, BALANCE_TYPE, 'END');

        -- RUN ONLY IF CRL INSTALLED
        IF (NVL (FND_PROFILE.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            GET_BALANCE_GROUP_END (BOOK, DISTRIBUTION_SOURCE_BOOK, PERIOD2_PC, PERIOD1_PC - 1, PERIOD2_PCD, PERIOD2_PCD
                                   , REPORT_TYPE, BALANCE_TYPE, 'END');
        END IF;
    --      COMMIT;--8
    /*   GET_ADJUSTMENTS (BOOK, DISTRIBUTION_SOURCE_BOOK,
                PERIOD1_PC, PERIOD2_PC,
                REPORT_TYPE, BALANCE_TYPE);

        -- RUN ONLY IF CRL INSTALLED
        IF ( NVL(FND_PROFILE.VALUE('CRL-FA ENABLED'), 'N') = 'Y') THEN
           GET_ADJUSTMENTS_FOR_GROUP (BOOK, DISTRIBUTION_SOURCE_BOOK,
                PERIOD1_PC, PERIOD2_PC,
                REPORT_TYPE, BALANCE_TYPE);
        END IF;

       IF (REPORT_TYPE = 'RESERVE' OR REPORT_TYPE = 'REVAL RESERVE') THEN
       GET_DEPRN_EFFECTS (BOOK, DISTRIBUTION_SOURCE_BOOK,
                  PERIOD1_PC, PERIOD2_PC,
                  REPORT_TYPE);
       END IF;
   */
    END INSERT_INFO;

    PROCEDURE GET_BALANCE (BOOK IN VARCHAR2, DISTRIBUTION_SOURCE_BOOK IN VARCHAR2, PERIOD_PC IN NUMBER, EARLIEST_PC IN NUMBER, PERIOD_DATE IN DATE, ADDITIONS_DATE IN DATE
                           , REPORT_TYPE IN VARCHAR2, BALANCE_TYPE IN VARCHAR2, BEGIN_OR_END IN VARCHAR2)
    IS
        P_DATE              DATE := PERIOD_DATE;
        A_DATE              DATE := ADDITIONS_DATE;
        H_SET_OF_BOOKS_ID   NUMBER;
        H_REPORTING_FLAG    VARCHAR2 (1);
    BEGIN
        -- GET MRC RELATED INFO
        BEGIN
            SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
              INTO H_SET_OF_BOOKS_ID
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                H_SET_OF_BOOKS_ID   := NULL;
        END;

        IF (H_SET_OF_BOOKS_ID IS NOT NULL)
        THEN
            IF NOT FA_CACHE_PKG.FAZCSOB (
                       X_SET_OF_BOOKS_ID     => H_SET_OF_BOOKS_ID,
                       X_MRC_SOB_TYPE_CODE   => H_REPORTING_FLAG)
            THEN
                RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
            END IF;
        ELSE
            H_REPORTING_FLAG   := 'P';
        END IF;

        -- FIX FOR BUG #1892406.  RUN ONLY IF CRL NOT INSTALLED.
        IF (NVL (FND_PROFILE.VALUE ('CRL-FA ENABLED'), 'N') = 'N')
        THEN
            IF (H_REPORTING_FLAG = 'R')
            THEN
                INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                ASSET_ID,
                                DISTRIBUTION_CCID,
                                ADJUSTMENT_CCID,
                                CATEGORY_BOOKS_ACCOUNT,
                                SOURCE_TYPE_CODE,
                                AMOUNT)
                    SELECT DH.ASSET_ID, DH.CODE_COMBINATION_ID, NULL,
                           DECODE (REPORT_TYPE,  'COST', CB.ASSET_COST_ACCT,  'CIP COST', CB.CIP_COST_ACCT,  'RESERVE', CB.DEPRN_RESERVE_ACCT,  'REVAL RESERVE', CB.REVAL_RESERVE_ACCT), DECODE (REPORT_TYPE,  'RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  'REVAL RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  BEGIN_OR_END), DECODE (REPORT_TYPE,  'COST', DD.COST,  'CIP COST', DD.COST,  'RESERVE', DD.DEPRN_RESERVE,  'REVAL RESERVE', DD.REVAL_RESERVE)
                      FROM FA_DISTRIBUTION_HISTORY DH, FA_DEPRN_DETAIL_MRC_V DD, FA_ASSET_HISTORY AH,
                           FA_CATEGORY_BOOKS CB, FA_BOOKS_MRC_V BK
                     WHERE     DH.BOOK_TYPE_CODE = DISTRIBUTION_SOURCE_BOOK
                           AND DECODE (DD.DEPRN_SOURCE_CODE,
                                       'D', P_DATE,
                                       A_DATE) BETWEEN DH.DATE_EFFECTIVE
                                                   AND NVL (
                                                           DH.DATE_INEFFECTIVE,
                                                           SYSDATE)
                           AND DD.ASSET_ID = DH.ASSET_ID
                           AND DD.BOOK_TYPE_CODE = BOOK
                           AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                           AND DD.PERIOD_COUNTER <= PERIOD_PC
                           AND -- BUG FIX 5076193 (CIP ASSETS DONT APPEAR IN CIP DETAIL REPORT)
                               DECODE (
                                   REPORT_TYPE,
                                   'CIP COST', DD.DEPRN_SOURCE_CODE,
                                   DECODE (BEGIN_OR_END,
                                           'BEGIN', DD.DEPRN_SOURCE_CODE,
                                           'D')) =
                               DD.DEPRN_SOURCE_CODE
                           AND /*        DECODE(BEGIN_OR_END,
                                               'BEGIN', DD.DEPRN_SOURCE_CODE, 'D') =
                                                       DD.DEPRN_SOURCE_CODE AND */
                                                        -- END BUG FIX 5076193
                            DD.PERIOD_COUNTER =
                            (SELECT MAX (SUB_DD.PERIOD_COUNTER)
                               FROM FA_DEPRN_DETAIL_MRC_V SUB_DD
                              WHERE     SUB_DD.BOOK_TYPE_CODE = BOOK
                                    AND SUB_DD.DISTRIBUTION_ID =
                                        DH.DISTRIBUTION_ID
                                    AND DH.DISTRIBUTION_ID =
                                        DD.DISTRIBUTION_ID
                                    AND SUB_DD.PERIOD_COUNTER <= PERIOD_PC)
                           AND AH.ASSET_ID = DH.ASSET_ID
                           AND ((AH.ASSET_TYPE != 'EXPENSED' AND REPORT_TYPE IN ('COST', 'CIP COST')) OR (AH.ASSET_TYPE IN ('CAPITALIZED', 'CIP') AND REPORT_TYPE IN ('RESERVE', 'REVAL RESERVE')))
                           AND DECODE (DD.DEPRN_SOURCE_CODE,
                                       'D', P_DATE,
                                       A_DATE) BETWEEN AH.DATE_EFFECTIVE
                                                   AND NVL (
                                                           AH.DATE_INEFFECTIVE,
                                                           SYSDATE)
                           AND CB.CATEGORY_ID = AH.CATEGORY_ID
                           AND CB.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                           -- CHANGED FROM BOOK VAR TO COLUMN
                           AND BK.BOOK_TYPE_CODE = CB.BOOK_TYPE_CODE
                           AND              -- CHANGED FROM BOOK VAR TO COLUMN
                               BK.ASSET_ID = DD.ASSET_ID
                           AND DECODE (DD.DEPRN_SOURCE_CODE,
                                       'D', P_DATE,
                                       A_DATE) BETWEEN BK.DATE_EFFECTIVE
                                                   AND NVL (
                                                           BK.DATE_INEFFECTIVE,
                                                           SYSDATE)
                           AND NVL (BK.PERIOD_COUNTER_FULLY_RETIRED,
                                    PERIOD_PC + 1) >
                               EARLIEST_PC
                           AND DECODE (
                                   REPORT_TYPE,
                                   'COST', DECODE (
                                               AH.ASSET_TYPE,
                                               'CAPITALIZED', CB.ASSET_COST_ACCT,
                                               NULL),
                                   'CIP COST', DECODE (
                                                   AH.ASSET_TYPE,
                                                   'CIP', CB.CIP_COST_ACCT,
                                                   NULL),
                                   'RESERVE', CB.DEPRN_RESERVE_ACCT,
                                   'REVAL RESERVE', CB.REVAL_RESERVE_ACCT)
                                   IS NOT NULL;
            ELSE
                -- SPLIT FOR 'COST','CIP COST' AND 'RESERVE','REVAL RESERVE' FOR BETTER PERFORMANCE.
                IF REPORT_TYPE IN ('COST', 'CIP COST')
                THEN
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT DH.ASSET_ID, DH.CODE_COMBINATION_ID, NULL,
                               DECODE (REPORT_TYPE,  'COST', CB.ASSET_COST_ACCT,  'CIP COST', CB.CIP_COST_ACCT,  'RESERVE', CB.DEPRN_RESERVE_ACCT,  'REVAL RESERVE', CB.REVAL_RESERVE_ACCT), DECODE (REPORT_TYPE,  'RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  'REVAL RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  BEGIN_OR_END), DECODE (REPORT_TYPE,  'COST', DD.COST,  'CIP COST', DD.COST,  'RESERVE', DD.DEPRN_RESERVE,  'REVAL RESERVE', DD.REVAL_RESERVE)
                          FROM FA_DISTRIBUTION_HISTORY DH, FA_DEPRN_DETAIL DD, FA_ASSET_HISTORY AH,
                               FA_CATEGORY_BOOKS CB, FA_BOOKS BK
                         WHERE     DH.BOOK_TYPE_CODE =
                                   DISTRIBUTION_SOURCE_BOOK
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN DH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               DH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND DD.ASSET_ID = DH.ASSET_ID
                               AND DD.BOOK_TYPE_CODE = BOOK
                               AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                               AND DD.PERIOD_COUNTER <= PERIOD_PC
                               AND -- BUG FIX 5076193 (CIP ASSETS DONT APPEAR IN CIP DETAIL REPORT)
                                   DECODE (
                                       REPORT_TYPE,
                                       'CIP COST', DD.DEPRN_SOURCE_CODE,
                                       DECODE (BEGIN_OR_END,
                                               'BEGIN', DD.DEPRN_SOURCE_CODE,
                                               'D')) =
                                   DD.DEPRN_SOURCE_CODE
                               AND /*        DECODE(BEGIN_OR_END,
                                                   'BEGIN', DD.DEPRN_SOURCE_CODE, 'D') =
                                                           DD.DEPRN_SOURCE_CODE AND  */
                                                        -- END BUG FIX 5076193
                                DD.PERIOD_COUNTER =
                                (SELECT MAX (SUB_DD.PERIOD_COUNTER)
                                   FROM FA_DEPRN_DETAIL SUB_DD
                                  WHERE     SUB_DD.BOOK_TYPE_CODE = BOOK
                                        AND SUB_DD.DISTRIBUTION_ID =
                                            DH.DISTRIBUTION_ID
                                        AND DH.DISTRIBUTION_ID =
                                            DD.DISTRIBUTION_ID
                                        AND SUB_DD.PERIOD_COUNTER <=
                                            PERIOD_PC)
                               AND AH.ASSET_ID = DH.ASSET_ID
                               AND AH.ASSET_TYPE != 'EXPENSED'
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN AH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               AH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND CB.CATEGORY_ID = AH.CATEGORY_ID
                               AND CB.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                               -- CHANGED FROM BOOK VAR TO COLUMN
                               AND BK.BOOK_TYPE_CODE = CB.BOOK_TYPE_CODE
                               AND          -- CHANGED FROM BOOK VAR TO COLUMN
                                   BK.ASSET_ID = DD.ASSET_ID
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN BK.DATE_EFFECTIVE
                                                       AND NVL (
                                                               BK.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND NVL (BK.PERIOD_COUNTER_FULLY_RETIRED,
                                        PERIOD_PC + 1) >
                                   EARLIEST_PC
                               AND DECODE (
                                       REPORT_TYPE,
                                       'COST', DECODE (
                                                   AH.ASSET_TYPE,
                                                   'CAPITALIZED', CB.ASSET_COST_ACCT,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       AH.ASSET_TYPE,
                                                       'CIP', CB.CIP_COST_ACCT,
                                                       NULL),
                                       'RESERVE', CB.DEPRN_RESERVE_ACCT,
                                       'REVAL RESERVE', CB.REVAL_RESERVE_ACCT)
                                       IS NOT NULL;
                ELSE             -- REPORT_TYPE IN ('RESERVE','REVAL RESERVE')
                    /* BUG 6998035 */
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT /*+ ORDERED */
                               DH.ASSET_ID, DH.CODE_COMBINATION_ID, NULL,
                               DECODE (REPORT_TYPE,  'COST', CB.ASSET_COST_ACCT,  'CIP COST', CB.CIP_COST_ACCT,  'RESERVE', CB.DEPRN_RESERVE_ACCT,  'REVAL RESERVE', CB.REVAL_RESERVE_ACCT), DECODE (REPORT_TYPE,  'RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  'REVAL RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  BEGIN_OR_END), DECODE (REPORT_TYPE,  'COST', DD.COST,  'CIP COST', DD.COST,  'RESERVE', DD.DEPRN_RESERVE,  'REVAL RESERVE', DD.REVAL_RESERVE)
                          FROM FA_DEPRN_DETAIL DD, FA_DISTRIBUTION_HISTORY DH, FA_ASSET_HISTORY AH,
                               FA_CATEGORY_BOOKS CB, FA_BOOKS BK
                         WHERE     DH.BOOK_TYPE_CODE =
                                   DISTRIBUTION_SOURCE_BOOK
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN DH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               DH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND DD.ASSET_ID = DH.ASSET_ID
                               AND DD.BOOK_TYPE_CODE = BOOK
                               AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                               AND DD.PERIOD_COUNTER <= PERIOD_PC
                               AND DECODE (BEGIN_OR_END,
                                           'BEGIN', DD.DEPRN_SOURCE_CODE,
                                           'D') =
                                   DD.DEPRN_SOURCE_CODE
                               AND DD.PERIOD_COUNTER =
                                   (SELECT MAX (SUB_DD.PERIOD_COUNTER)
                                      FROM FA_DEPRN_DETAIL SUB_DD
                                     WHERE     SUB_DD.BOOK_TYPE_CODE = BOOK
                                           AND SUB_DD.DISTRIBUTION_ID =
                                               DH.DISTRIBUTION_ID
                                           AND DH.DISTRIBUTION_ID =
                                               DD.DISTRIBUTION_ID
                                           AND SUB_DD.PERIOD_COUNTER <=
                                               PERIOD_PC)
                               AND AH.ASSET_ID = DH.ASSET_ID
                               AND AH.ASSET_TYPE IN ('CAPITALIZED', 'CIP')
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN AH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               AH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND CB.CATEGORY_ID = AH.CATEGORY_ID
                               AND CB.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                               -- CHANGED FROM BOOK VAR TO COLUMN
                               AND BK.BOOK_TYPE_CODE = CB.BOOK_TYPE_CODE
                               AND          -- CHANGED FROM BOOK VAR TO COLUMN
                                   BK.ASSET_ID = DD.ASSET_ID
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN BK.DATE_EFFECTIVE
                                                       AND NVL (
                                                               BK.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND NVL (BK.PERIOD_COUNTER_FULLY_RETIRED,
                                        PERIOD_PC + 1) >
                                   EARLIEST_PC
                               AND DECODE (
                                       REPORT_TYPE,
                                       'COST', DECODE (
                                                   AH.ASSET_TYPE,
                                                   'CAPITALIZED', CB.ASSET_COST_ACCT,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       AH.ASSET_TYPE,
                                                       'CIP', CB.CIP_COST_ACCT,
                                                       NULL),
                                       'RESERVE', CB.DEPRN_RESERVE_ACCT,
                                       'REVAL RESERVE', CB.REVAL_RESERVE_ACCT)
                                       IS NOT NULL;
                END IF;
            END IF;
        -- FIX FOR BUG #1892406.  RUN ONLY IF CRL INSTALLED.
        ELSIF (NVL (FND_PROFILE.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            IF (H_REPORTING_FLAG = 'R')
            THEN
                INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                ASSET_ID,
                                DISTRIBUTION_CCID,
                                ADJUSTMENT_CCID,
                                CATEGORY_BOOKS_ACCOUNT,
                                SOURCE_TYPE_CODE,
                                AMOUNT)
                    SELECT DH.ASSET_ID, DH.CODE_COMBINATION_ID, NULL,
                           DECODE (REPORT_TYPE,  'COST', CB.ASSET_COST_ACCT,  'CIP COST', CB.CIP_COST_ACCT,  'RESERVE', CB.DEPRN_RESERVE_ACCT,  'REVAL RESERVE', CB.REVAL_RESERVE_ACCT), DECODE (REPORT_TYPE,  'RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  'REVAL RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  BEGIN_OR_END), DECODE (REPORT_TYPE,  'COST', DD.COST,  'CIP COST', DD.COST,  'RESERVE', DD.DEPRN_RESERVE,  'REVAL RESERVE', DD.REVAL_RESERVE)
                      FROM FA_DISTRIBUTION_HISTORY DH, FA_DEPRN_DETAIL_MRC_V DD, FA_ASSET_HISTORY AH,
                           FA_CATEGORY_BOOKS CB, FA_BOOKS_MRC_V BK
                     WHERE     DH.BOOK_TYPE_CODE = DISTRIBUTION_SOURCE_BOOK
                           AND DECODE (DD.DEPRN_SOURCE_CODE,
                                       'D', P_DATE,
                                       A_DATE) BETWEEN DH.DATE_EFFECTIVE
                                                   AND NVL (
                                                           DH.DATE_INEFFECTIVE,
                                                           SYSDATE)
                           AND DD.ASSET_ID = DH.ASSET_ID
                           AND DD.BOOK_TYPE_CODE = BOOK
                           AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                           AND DD.PERIOD_COUNTER <= PERIOD_PC
                           AND -- BUG FIX 5076193 (CIP ASSETS DONT APPEAR IN CIP DETAIL REPORT)
                               DECODE (
                                   REPORT_TYPE,
                                   'CIP COST', DD.DEPRN_SOURCE_CODE,
                                   DECODE (BEGIN_OR_END,
                                           'BEGIN', DD.DEPRN_SOURCE_CODE,
                                           'D')) =
                               DD.DEPRN_SOURCE_CODE
                           AND /*    DECODE(BEGIN_OR_END,
                                       'BEGIN', DD.DEPRN_SOURCE_CODE, 'D') =
                                           DD.DEPRN_SOURCE_CODE AND  */
                                                        -- END BUG FIX 5076193
                            DD.PERIOD_COUNTER =
                            (SELECT MAX (SUB_DD.PERIOD_COUNTER)
                               FROM FA_DEPRN_DETAIL_MRC_V SUB_DD
                              WHERE     SUB_DD.BOOK_TYPE_CODE = BOOK
                                    AND SUB_DD.DISTRIBUTION_ID =
                                        DH.DISTRIBUTION_ID
                                    AND DH.DISTRIBUTION_ID =
                                        DD.DISTRIBUTION_ID
                                    AND SUB_DD.PERIOD_COUNTER <= PERIOD_PC)
                           AND AH.ASSET_ID = DH.ASSET_ID
                           AND ((AH.ASSET_TYPE != 'EXPENSED' AND REPORT_TYPE IN ('COST', 'CIP COST')) OR (AH.ASSET_TYPE IN ('CAPITALIZED', 'CIP') AND REPORT_TYPE IN ('RESERVE', 'REVAL RESERVE')))
                           AND DECODE (DD.DEPRN_SOURCE_CODE,
                                       'D', P_DATE,
                                       A_DATE) BETWEEN AH.DATE_EFFECTIVE
                                                   AND NVL (
                                                           AH.DATE_INEFFECTIVE,
                                                           SYSDATE)
                           AND CB.CATEGORY_ID = AH.CATEGORY_ID
                           AND CB.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                           -- CHANGED FROM BOOK VAR TO COLUMN
                           AND BK.BOOK_TYPE_CODE = CB.BOOK_TYPE_CODE
                           AND              -- CHANGED FROM BOOK VAR TO COLUMN
                               BK.ASSET_ID = DD.ASSET_ID
                           AND DECODE (DD.DEPRN_SOURCE_CODE,
                                       'D', P_DATE,
                                       A_DATE) BETWEEN BK.DATE_EFFECTIVE
                                                   AND NVL (
                                                           BK.DATE_INEFFECTIVE,
                                                           SYSDATE)
                           AND NVL (BK.PERIOD_COUNTER_FULLY_RETIRED,
                                    PERIOD_PC + 1) >
                               EARLIEST_PC
                           AND DECODE (
                                   REPORT_TYPE,
                                   'COST', DECODE (
                                               AH.ASSET_TYPE,
                                               'CAPITALIZED', CB.ASSET_COST_ACCT,
                                               NULL),
                                   'CIP COST', DECODE (
                                                   AH.ASSET_TYPE,
                                                   'CIP', CB.CIP_COST_ACCT,
                                                   NULL),
                                   'RESERVE', CB.DEPRN_RESERVE_ACCT,
                                   'REVAL RESERVE', CB.REVAL_RESERVE_ACCT)
                                   IS NOT NULL
                           -- START OF CUA - THIS IS TO EXCLUDE THE GROUP ASSET MEMBERS
                           AND BK.GROUP_ASSET_ID IS NULL;
            ELSE
                INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                ASSET_ID,
                                DISTRIBUTION_CCID,
                                ADJUSTMENT_CCID,
                                CATEGORY_BOOKS_ACCOUNT,
                                SOURCE_TYPE_CODE,
                                AMOUNT)
                    SELECT DH.ASSET_ID, DH.CODE_COMBINATION_ID, NULL,
                           DECODE (REPORT_TYPE,  'COST', CB.ASSET_COST_ACCT,  'CIP COST', CB.CIP_COST_ACCT,  'RESERVE', CB.DEPRN_RESERVE_ACCT,  'REVAL RESERVE', CB.REVAL_RESERVE_ACCT), DECODE (REPORT_TYPE,  'RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  'REVAL RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  BEGIN_OR_END), DECODE (REPORT_TYPE,  'COST', DD.COST,  'CIP COST', DD.COST,  'RESERVE', DD.DEPRN_RESERVE,  'REVAL RESERVE', DD.REVAL_RESERVE)
                      FROM FA_DISTRIBUTION_HISTORY DH, FA_DEPRN_DETAIL DD, FA_ASSET_HISTORY AH,
                           FA_CATEGORY_BOOKS CB, FA_BOOKS BK
                     WHERE     DH.BOOK_TYPE_CODE = DISTRIBUTION_SOURCE_BOOK
                           AND DECODE (DD.DEPRN_SOURCE_CODE,
                                       'D', P_DATE,
                                       A_DATE) BETWEEN DH.DATE_EFFECTIVE
                                                   AND NVL (
                                                           DH.DATE_INEFFECTIVE,
                                                           SYSDATE)
                           AND DD.ASSET_ID = DH.ASSET_ID
                           AND DD.BOOK_TYPE_CODE = BOOK
                           AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                           AND DD.PERIOD_COUNTER <= PERIOD_PC
                           AND -- BUG FIX 5076193 (CIP ASSETS DONT APPEAR IN CIP DETAIL REPORT)
                               DECODE (
                                   REPORT_TYPE,
                                   'CIP COST', DD.DEPRN_SOURCE_CODE,
                                   DECODE (BEGIN_OR_END,
                                           'BEGIN', DD.DEPRN_SOURCE_CODE,
                                           'D')) =
                               DD.DEPRN_SOURCE_CODE
                           AND /*    DECODE(BEGIN_OR_END,
                                       'BEGIN', DD.DEPRN_SOURCE_CODE, 'D') =
                                           DD.DEPRN_SOURCE_CODE AND  */
                                                        -- END BUG FIX 5076193
                            DD.PERIOD_COUNTER =
                            (SELECT MAX (SUB_DD.PERIOD_COUNTER)
                               FROM FA_DEPRN_DETAIL SUB_DD
                              WHERE     SUB_DD.BOOK_TYPE_CODE = BOOK
                                    AND SUB_DD.DISTRIBUTION_ID =
                                        DH.DISTRIBUTION_ID
                                    AND DH.DISTRIBUTION_ID =
                                        DD.DISTRIBUTION_ID
                                    AND SUB_DD.PERIOD_COUNTER <= PERIOD_PC)
                           AND AH.ASSET_ID = DH.ASSET_ID
                           AND ((AH.ASSET_TYPE != 'EXPENSED' AND REPORT_TYPE IN ('COST', 'CIP COST')) OR (AH.ASSET_TYPE IN ('CAPITALIZED', 'CIP') AND REPORT_TYPE IN ('RESERVE', 'REVAL RESERVE')))
                           AND DECODE (DD.DEPRN_SOURCE_CODE,
                                       'D', P_DATE,
                                       A_DATE) BETWEEN AH.DATE_EFFECTIVE
                                                   AND NVL (
                                                           AH.DATE_INEFFECTIVE,
                                                           SYSDATE)
                           AND CB.CATEGORY_ID = AH.CATEGORY_ID
                           AND CB.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                           -- CHANGED FROM BOOK VAR TO COLUMN
                           AND BK.BOOK_TYPE_CODE = CB.BOOK_TYPE_CODE
                           AND              -- CHANGED FROM BOOK VAR TO COLUMN
                               BK.ASSET_ID = DD.ASSET_ID
                           AND DECODE (DD.DEPRN_SOURCE_CODE,
                                       'D', P_DATE,
                                       A_DATE) BETWEEN BK.DATE_EFFECTIVE
                                                   AND NVL (
                                                           BK.DATE_INEFFECTIVE,
                                                           SYSDATE)
                           AND NVL (BK.PERIOD_COUNTER_FULLY_RETIRED,
                                    PERIOD_PC + 1) >
                               EARLIEST_PC
                           AND DECODE (
                                   REPORT_TYPE,
                                   'COST', DECODE (
                                               AH.ASSET_TYPE,
                                               'CAPITALIZED', CB.ASSET_COST_ACCT,
                                               NULL),
                                   'CIP COST', DECODE (
                                                   AH.ASSET_TYPE,
                                                   'CIP', CB.CIP_COST_ACCT,
                                                   NULL),
                                   'RESERVE', CB.DEPRN_RESERVE_ACCT,
                                   'REVAL RESERVE', CB.REVAL_RESERVE_ACCT)
                                   IS NOT NULL
                           -- START OF CUA - THIS IS TO EXCLUDE THE GROUP ASSET MEMBERS
                           AND BK.GROUP_ASSET_ID IS NULL;
            END IF;
        -- END OF CUA
        END IF;
    END GET_BALANCE;

    PROCEDURE GET_BALANCE_GROUP_BEGIN (BOOK IN VARCHAR2, DISTRIBUTION_SOURCE_BOOK IN VARCHAR2, PERIOD_PC IN NUMBER, EARLIEST_PC IN NUMBER, PERIOD_DATE IN DATE, ADDITIONS_DATE IN DATE
                                       , REPORT_TYPE IN VARCHAR2, BALANCE_TYPE IN VARCHAR2, BEGIN_OR_END IN VARCHAR2)
    IS
        P_DATE              DATE := PERIOD_DATE;
        A_DATE              DATE := ADDITIONS_DATE;
        H_SET_OF_BOOKS_ID   NUMBER;
        H_REPORTING_FLAG    VARCHAR2 (1);
    BEGIN
        -- GET MRC RELATED INFO
        BEGIN
            SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
              INTO H_SET_OF_BOOKS_ID
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                H_SET_OF_BOOKS_ID   := NULL;
        END;

        IF (H_SET_OF_BOOKS_ID IS NOT NULL)
        THEN
            IF NOT FA_CACHE_PKG.FAZCSOB (
                       X_SET_OF_BOOKS_ID     => H_SET_OF_BOOKS_ID,
                       X_MRC_SOB_TYPE_CODE   => H_REPORTING_FLAG)
            THEN
                RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
            END IF;
        ELSE
            H_REPORTING_FLAG   := 'P';
        END IF;

        -- RUN ONLY IF CRL INSTALLED
        IF (NVL (FND_PROFILE.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            IF (REPORT_TYPE NOT IN ('RESERVE'))
            THEN
                IF (H_REPORTING_FLAG = 'R')
                THEN
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT DH.ASSET_ID, --DH.CODE_COMBINATION_ID,
                                            NVL (GAD.DEPRN_EXPENSE_ACCT_CCID, DH.CODE_COMBINATION_ID), -- CHANGED FOR BMA1
                                                                                                       -- NVL(GAD.ASSET_COST_ACCT_CCID,1127),
                                                                                                       GAD.ASSET_COST_ACCT_CCID,
                               NULL, DECODE (REPORT_TYPE,  'RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  'REVAL RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  BEGIN_OR_END), DECODE (REPORT_TYPE,  -- COMMENTED BY PRABAKAR
                                                                                                                                                                                                                                                          'COST', DECODE (NVL (BK.GROUP_ASSET_ID, -2), -2, DD.COST, BK.COST),  --             'COST', DD.COST,
                                                                                                                                                                                                                                                                                                                               'CIP COST', DD.COST,  'RESERVE', DD.DEPRN_RESERVE,  'REVAL RESERVE', DD.REVAL_RESERVE)
                          FROM FA_BOOKS_MRC_V BK, FA_CATEGORY_BOOKS CB, FA_ASSET_HISTORY AH,
                               FA_DEPRN_DETAIL_MRC_V DD, FA_DISTRIBUTION_HISTORY DH, -- COMMENTED BY PRABAKAR
                                                                                     FA_GROUP_ASSET_DEFAULT GAD
                         WHERE                        -- COMMENTED BY PRABAKAR
                                   GAD.BOOK_TYPE_CODE = BK.BOOK_TYPE_CODE
                               AND GAD.GROUP_ASSET_ID = BK.GROUP_ASSET_ID
                               AND -- THIS IS TO INCLUDE ONLY THE GROUP ASSET MEMBERS
                                   BK.GROUP_ASSET_ID IS NOT NULL
                               AND DH.BOOK_TYPE_CODE =
                                   DISTRIBUTION_SOURCE_BOOK
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN DH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               DH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND DD.ASSET_ID = DH.ASSET_ID
                               AND DD.BOOK_TYPE_CODE = BOOK
                               AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                               AND DD.PERIOD_COUNTER <= PERIOD_PC
                               AND DECODE (BEGIN_OR_END,
                                           'BEGIN', DD.DEPRN_SOURCE_CODE,
                                           'D') =
                                   DD.DEPRN_SOURCE_CODE
                               AND DD.PERIOD_COUNTER =
                                   (SELECT MAX (SUB_DD.PERIOD_COUNTER)
                                      FROM FA_DEPRN_DETAIL_MRC_V SUB_DD
                                     WHERE     SUB_DD.BOOK_TYPE_CODE = BOOK
                                           AND SUB_DD.DISTRIBUTION_ID =
                                               DH.DISTRIBUTION_ID
                                           AND SUB_DD.PERIOD_COUNTER <=
                                               PERIOD_PC)
                               AND AH.ASSET_ID = DH.ASSET_ID
                               AND ((AH.ASSET_TYPE != 'EXPENSED' AND REPORT_TYPE IN ('COST', 'CIP COST')) OR (AH.ASSET_TYPE IN ('CAPITALIZED', 'CIP') AND REPORT_TYPE IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN AH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               AH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND CB.CATEGORY_ID = AH.CATEGORY_ID
                               AND CB.BOOK_TYPE_CODE = BOOK
                               AND BK.BOOK_TYPE_CODE = BOOK
                               AND BK.ASSET_ID = DD.ASSET_ID
                               AND                    -- COMMENTED BY PRABAKAR
                                   (BK.TRANSACTION_HEADER_ID_IN =
                                    (SELECT MIN (FAB.TRANSACTION_HEADER_ID_IN)
                                       FROM FA_BOOKS_GROUPS_MRC_V BG, FA_BOOKS_MRC_V FAB
                                      WHERE     BG.GROUP_ASSET_ID =
                                                NVL (BK.GROUP_ASSET_ID, -2)
                                            AND BG.BOOK_TYPE_CODE =
                                                FAB.BOOK_TYPE_CODE
                                            AND FAB.TRANSACTION_HEADER_ID_IN <=
                                                BG.TRANSACTION_HEADER_ID_IN
                                            AND NVL (
                                                    FAB.TRANSACTION_HEADER_ID_OUT,
                                                    BG.TRANSACTION_HEADER_ID_IN) >=
                                                BG.TRANSACTION_HEADER_ID_IN
                                            AND BG.PERIOD_COUNTER =
                                                PERIOD_PC + 1
                                            AND FAB.ASSET_ID = BK.ASSET_ID
                                            AND FAB.BOOK_TYPE_CODE =
                                                BK.BOOK_TYPE_CODE
                                            AND BG.BEGINNING_BALANCE_FLAG
                                                    IS NOT NULL))
                               AND DECODE (
                                       REPORT_TYPE,
                                       'COST', DECODE (
                                                   AH.ASSET_TYPE,
                                                   'CAPITALIZED', CB.ASSET_COST_ACCT,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       AH.ASSET_TYPE,
                                                       'CIP', CB.CIP_COST_ACCT,
                                                       NULL),
                                       'RESERVE', CB.DEPRN_RESERVE_ACCT,
                                       'REVAL RESERVE', CB.REVAL_RESERVE_ACCT)
                                       IS NOT NULL;
                ELSE
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT DH.ASSET_ID, --DH.CODE_COMBINATION_ID,
                                            NVL (GAD.DEPRN_EXPENSE_ACCT_CCID, DH.CODE_COMBINATION_ID), -- CHANGED FOR BMA1
                                                                                                       -- NVL(GAD.ASSET_COST_ACCT_CCID,1127),
                                                                                                       GAD.ASSET_COST_ACCT_CCID,
                               NULL, DECODE (REPORT_TYPE,  'RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  'REVAL RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  BEGIN_OR_END), DECODE (REPORT_TYPE,  -- COMMENTED BY PRABAKAR
                                                                                                                                                                                                                                                          'COST', DECODE (NVL (BK.GROUP_ASSET_ID, -2), -2, DD.COST, BK.COST),  --             'COST', DD.COST,
                                                                                                                                                                                                                                                                                                                               'CIP COST', DD.COST,  'RESERVE', DD.DEPRN_RESERVE,  'REVAL RESERVE', DD.REVAL_RESERVE)
                          FROM FA_BOOKS BK, FA_CATEGORY_BOOKS CB, FA_ASSET_HISTORY AH,
                               FA_DEPRN_DETAIL DD, FA_DISTRIBUTION_HISTORY DH, -- COMMENTED BY PRABAKAR
                                                                               FA_GROUP_ASSET_DEFAULT GAD
                         WHERE                        -- COMMENTED BY PRABAKAR
                                   GAD.BOOK_TYPE_CODE = BK.BOOK_TYPE_CODE
                               AND GAD.GROUP_ASSET_ID = BK.GROUP_ASSET_ID
                               AND -- THIS IS TO INCLUDE ONLY THE GROUP ASSET MEMBERS
                                   BK.GROUP_ASSET_ID IS NOT NULL
                               AND DH.BOOK_TYPE_CODE =
                                   DISTRIBUTION_SOURCE_BOOK
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN DH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               DH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND DD.ASSET_ID = DH.ASSET_ID
                               AND DD.BOOK_TYPE_CODE = BOOK
                               AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                               AND DD.PERIOD_COUNTER <= PERIOD_PC
                               AND DECODE (BEGIN_OR_END,
                                           'BEGIN', DD.DEPRN_SOURCE_CODE,
                                           'D') =
                                   DD.DEPRN_SOURCE_CODE
                               AND DD.PERIOD_COUNTER =
                                   (SELECT MAX (SUB_DD.PERIOD_COUNTER)
                                      FROM FA_DEPRN_DETAIL SUB_DD
                                     WHERE     SUB_DD.BOOK_TYPE_CODE = BOOK
                                           AND SUB_DD.DISTRIBUTION_ID =
                                               DH.DISTRIBUTION_ID
                                           AND SUB_DD.PERIOD_COUNTER <=
                                               PERIOD_PC)
                               AND AH.ASSET_ID = DH.ASSET_ID
                               AND ((AH.ASSET_TYPE != 'EXPENSED' AND REPORT_TYPE IN ('COST', 'CIP COST')) OR (AH.ASSET_TYPE IN ('CAPITALIZED', 'CIP') AND REPORT_TYPE IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN AH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               AH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND CB.CATEGORY_ID = AH.CATEGORY_ID
                               AND CB.BOOK_TYPE_CODE = BOOK
                               AND BK.BOOK_TYPE_CODE = BOOK
                               AND BK.ASSET_ID = DD.ASSET_ID
                               AND                    -- COMMENTED BY PRABAKAR
                                   (BK.TRANSACTION_HEADER_ID_IN =
                                    (SELECT MIN (FAB.TRANSACTION_HEADER_ID_IN)
                                       FROM FA_BOOKS_GROUPS BG, FA_BOOKS FAB
                                      WHERE     BG.GROUP_ASSET_ID =
                                                NVL (BK.GROUP_ASSET_ID, -2)
                                            AND BG.BOOK_TYPE_CODE =
                                                FAB.BOOK_TYPE_CODE
                                            AND FAB.TRANSACTION_HEADER_ID_IN <=
                                                BG.TRANSACTION_HEADER_ID_IN
                                            AND NVL (
                                                    FAB.TRANSACTION_HEADER_ID_OUT,
                                                    BG.TRANSACTION_HEADER_ID_IN) >=
                                                BG.TRANSACTION_HEADER_ID_IN
                                            AND BG.PERIOD_COUNTER =
                                                PERIOD_PC + 1
                                            AND FAB.ASSET_ID = BK.ASSET_ID
                                            AND FAB.BOOK_TYPE_CODE =
                                                BK.BOOK_TYPE_CODE
                                            AND BG.BEGINNING_BALANCE_FLAG
                                                    IS NOT NULL))
                               AND DECODE (
                                       REPORT_TYPE,
                                       'COST', DECODE (
                                                   AH.ASSET_TYPE,
                                                   'CAPITALIZED', CB.ASSET_COST_ACCT,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       AH.ASSET_TYPE,
                                                       'CIP', CB.CIP_COST_ACCT,
                                                       NULL),
                                       'RESERVE', CB.DEPRN_RESERVE_ACCT,
                                       'REVAL RESERVE', CB.REVAL_RESERVE_ACCT)
                                       IS NOT NULL;
                END IF;
            ELSE
                -- GET THE DEPRECIATION RESERVE BEGIN BALANCE
                IF (H_REPORTING_FLAG = 'R')
                THEN
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT GAR.GROUP_ASSET_ID ASSET_ID, GAD.DEPRN_EXPENSE_ACCT_CCID, GAD.DEPRN_RESERVE_ACCT_CCID,
                               NULL, /* DECODE(REPORT_TYPE,
                                     'RESERVE', DECODE(DD.DEPRN_SOURCE_CODE,
                                         'D', BEGIN_OR_END, 'ADDITION'),
                                     'REVAL RESERVE',
                                 DECODE(DD.DEPRN_SOURCE_CODE,
                                         'D', BEGIN_OR_END, 'ADDITION'),
                                     BEGIN_OR_END),
                                     */
                                     'BEGIN', DD.DEPRN_RESERVE
                          FROM FA_DEPRN_SUMMARY_MRC_V DD, FA_GROUP_ASSET_RULES GAR, FA_GROUP_ASSET_DEFAULT GAD
                         WHERE     DD.BOOK_TYPE_CODE = BOOK
                               AND DD.ASSET_ID = GAR.GROUP_ASSET_ID
                               AND GAR.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                               AND GAD.BOOK_TYPE_CODE = GAR.BOOK_TYPE_CODE
                               AND GAD.GROUP_ASSET_ID = GAR.GROUP_ASSET_ID
                               AND DD.PERIOD_COUNTER =
                                   (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                      FROM FA_DEPRN_DETAIL_MRC_V DD_SUB
                                     WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                           AND DD_SUB.ASSET_ID =
                                               GAR.GROUP_ASSET_ID
                                           AND DD_SUB.PERIOD_COUNTER <=
                                               PERIOD_PC);
                ELSE
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT GAR.GROUP_ASSET_ID ASSET_ID, GAD.DEPRN_EXPENSE_ACCT_CCID, GAD.DEPRN_RESERVE_ACCT_CCID,
                               NULL, /* DECODE(REPORT_TYPE,
                                     'RESERVE', DECODE(DD.DEPRN_SOURCE_CODE,
                                         'D', BEGIN_OR_END, 'ADDITION'),
                                     'REVAL RESERVE',
                                 DECODE(DD.DEPRN_SOURCE_CODE,
                                         'D', BEGIN_OR_END, 'ADDITION'),
                                     BEGIN_OR_END),
                                     */
                                     'BEGIN', DD.DEPRN_RESERVE
                          FROM FA_DEPRN_SUMMARY DD, FA_GROUP_ASSET_RULES GAR, FA_GROUP_ASSET_DEFAULT GAD
                         WHERE     DD.BOOK_TYPE_CODE = BOOK
                               AND DD.ASSET_ID = GAR.GROUP_ASSET_ID
                               AND GAR.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                               AND GAD.BOOK_TYPE_CODE = GAR.BOOK_TYPE_CODE
                               AND GAD.GROUP_ASSET_ID = GAR.GROUP_ASSET_ID
                               AND DD.PERIOD_COUNTER =
                                   (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                      FROM FA_DEPRN_DETAIL DD_SUB
                                     WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                           AND DD_SUB.ASSET_ID =
                                               GAR.GROUP_ASSET_ID
                                           AND DD_SUB.PERIOD_COUNTER <=
                                               PERIOD_PC);
                END IF;
            --NULL;
            END IF;
        END IF;                                             --END OF CRL CHECK
    END GET_BALANCE_GROUP_BEGIN;

    PROCEDURE GET_BALANCE_GROUP_END (BOOK IN VARCHAR2, DISTRIBUTION_SOURCE_BOOK IN VARCHAR2, PERIOD_PC IN NUMBER, EARLIEST_PC IN NUMBER, PERIOD_DATE IN DATE, ADDITIONS_DATE IN DATE
                                     , REPORT_TYPE IN VARCHAR2, BALANCE_TYPE IN VARCHAR2, BEGIN_OR_END IN VARCHAR2)
    IS
        P_DATE              DATE := PERIOD_DATE;
        A_DATE              DATE := ADDITIONS_DATE;
        H_SET_OF_BOOKS_ID   NUMBER;
        H_REPORTING_FLAG    VARCHAR2 (1);
    BEGIN
        -- GET MRC RELATED INFO
        BEGIN
            H_SET_OF_BOOKS_ID   :=
                TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10));
        EXCEPTION
            WHEN OTHERS
            THEN
                H_SET_OF_BOOKS_ID   := NULL;
        END;

        IF (H_SET_OF_BOOKS_ID IS NOT NULL)
        THEN
            IF NOT FA_CACHE_PKG.FAZCSOB (
                       X_SET_OF_BOOKS_ID     => H_SET_OF_BOOKS_ID,
                       X_MRC_SOB_TYPE_CODE   => H_REPORTING_FLAG)
            THEN
                RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
            END IF;
        ELSE
            H_REPORTING_FLAG   := 'P';
        END IF;

        -- RUN ONLY IF CRL INSTALLED
        IF (NVL (FND_PROFILE.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            IF REPORT_TYPE NOT IN ('RESERVE')
            THEN
                IF (H_REPORTING_FLAG = 'R')
                THEN
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT DH.ASSET_ID, -- DH.CODE_COMBINATION_ID,
                                            NVL (GAD.DEPRN_EXPENSE_ACCT_CCID, DH.CODE_COMBINATION_ID), -- CHANGED FOR BMA1
                                                                                                       -- NVL(GAD.ASSET_COST_ACCT_CCID,1127),
                                                                                                       GAD.ASSET_COST_ACCT_CCID,
                               NULL, DECODE (REPORT_TYPE,  'RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  'REVAL RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  BEGIN_OR_END), DECODE (REPORT_TYPE,  'COST', DECODE (NVL (BK.GROUP_ASSET_ID, -2), -2, DD.COST, BK.COST),  'CIP COST', DD.COST,  'RESERVE', DD.DEPRN_RESERVE,  'REVAL RESERVE', DD.REVAL_RESERVE)
                          FROM FA_BOOKS_MRC_V BK, FA_CATEGORY_BOOKS CB, FA_ASSET_HISTORY AH,
                               FA_DEPRN_DETAIL_MRC_V DD, FA_DISTRIBUTION_HISTORY DH, -- COMMENTED BY PRABAKAR
                                                                                     FA_GROUP_ASSET_DEFAULT GAD
                         WHERE                        -- COMMENTED BY PRABAKAR
                                   GAD.BOOK_TYPE_CODE = BK.BOOK_TYPE_CODE
                               AND GAD.GROUP_ASSET_ID = BK.GROUP_ASSET_ID
                               -- THIS IS TO INCLUDE ONLY THE GROUP ASSET MEMBERS
                               AND BK.GROUP_ASSET_ID IS NOT NULL
                               AND DH.BOOK_TYPE_CODE =
                                   DISTRIBUTION_SOURCE_BOOK
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN DH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               DH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND DD.ASSET_ID = DH.ASSET_ID
                               AND DD.BOOK_TYPE_CODE = BOOK
                               AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                               AND DD.PERIOD_COUNTER <= PERIOD_PC
                               AND DECODE (BEGIN_OR_END,
                                           'BEGIN', DD.DEPRN_SOURCE_CODE,
                                           'D') =
                                   DD.DEPRN_SOURCE_CODE
                               AND DD.PERIOD_COUNTER =
                                   (SELECT MAX (SUB_DD.PERIOD_COUNTER)
                                      FROM FA_DEPRN_DETAIL_MRC_V SUB_DD
                                     WHERE     SUB_DD.BOOK_TYPE_CODE = BOOK
                                           AND SUB_DD.DISTRIBUTION_ID =
                                               DH.DISTRIBUTION_ID
                                           AND SUB_DD.PERIOD_COUNTER <=
                                               PERIOD_PC)
                               AND AH.ASSET_ID = DH.ASSET_ID
                               AND ((AH.ASSET_TYPE != 'EXPENSED' AND REPORT_TYPE IN ('COST', 'CIP COST')) OR (AH.ASSET_TYPE IN ('CAPITALIZED', 'CIP') AND REPORT_TYPE IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN AH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               AH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND CB.CATEGORY_ID = AH.CATEGORY_ID
                               AND CB.BOOK_TYPE_CODE = BOOK
                               AND BK.BOOK_TYPE_CODE = BOOK
                               AND BK.ASSET_ID = DD.ASSET_ID
                               AND                    -- COMMENTED BY PRABAKAR
                                   (BK.TRANSACTION_HEADER_ID_IN =
                                    (SELECT MIN (FAB.TRANSACTION_HEADER_ID_IN)
                                       FROM FA_BOOKS_GROUPS_MRC_V BG, FA_BOOKS_MRC_V FAB
                                      WHERE     BG.GROUP_ASSET_ID =
                                                NVL (BK.GROUP_ASSET_ID, -2)
                                            AND BG.BOOK_TYPE_CODE =
                                                FAB.BOOK_TYPE_CODE
                                            AND FAB.TRANSACTION_HEADER_ID_IN <=
                                                BG.TRANSACTION_HEADER_ID_IN
                                            AND NVL (
                                                    FAB.TRANSACTION_HEADER_ID_OUT,
                                                    BG.TRANSACTION_HEADER_ID_IN) >=
                                                BG.TRANSACTION_HEADER_ID_IN
                                            AND BG.PERIOD_COUNTER =
                                                PERIOD_PC + 1
                                            AND FAB.ASSET_ID = BK.ASSET_ID
                                            AND FAB.BOOK_TYPE_CODE =
                                                BK.BOOK_TYPE_CODE
                                            AND BG.BEGINNING_BALANCE_FLAG
                                                    IS NOT NULL))
                               AND DECODE (
                                       REPORT_TYPE,
                                       'COST', DECODE (
                                                   AH.ASSET_TYPE,
                                                   'CAPITALIZED', CB.ASSET_COST_ACCT,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       AH.ASSET_TYPE,
                                                       'CIP', CB.CIP_COST_ACCT,
                                                       NULL),
                                       'RESERVE', CB.DEPRN_RESERVE_ACCT,
                                       'REVAL RESERVE', CB.REVAL_RESERVE_ACCT)
                                       IS NOT NULL;
                ELSE
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT DH.ASSET_ID, -- DH.CODE_COMBINATION_ID,
                                            NVL (GAD.DEPRN_EXPENSE_ACCT_CCID, DH.CODE_COMBINATION_ID), -- CHANGED FOR BMA1
                                                                                                       -- NVL(GAD.ASSET_COST_ACCT_CCID,1127),
                                                                                                       GAD.ASSET_COST_ACCT_CCID,
                               NULL, DECODE (REPORT_TYPE,  'RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  'REVAL RESERVE', DECODE (DD.DEPRN_SOURCE_CODE, 'D', BEGIN_OR_END, 'ADDITION'),  BEGIN_OR_END), DECODE (REPORT_TYPE,  'COST', DECODE (NVL (BK.GROUP_ASSET_ID, -2), -2, DD.COST, BK.COST),  'CIP COST', DD.COST,  'RESERVE', DD.DEPRN_RESERVE,  'REVAL RESERVE', DD.REVAL_RESERVE)
                          FROM FA_BOOKS BK, FA_CATEGORY_BOOKS CB, FA_ASSET_HISTORY AH,
                               FA_DEPRN_DETAIL DD, FA_DISTRIBUTION_HISTORY DH, -- COMMENTED BY PRABAKAR
                                                                               FA_GROUP_ASSET_DEFAULT GAD
                         WHERE                        -- COMMENTED BY PRABAKAR
                                   GAD.BOOK_TYPE_CODE = BK.BOOK_TYPE_CODE
                               AND GAD.GROUP_ASSET_ID = BK.GROUP_ASSET_ID
                               -- THIS IS TO INCLUDE ONLY THE GROUP ASSET MEMBERS
                               AND BK.GROUP_ASSET_ID IS NOT NULL
                               AND DH.BOOK_TYPE_CODE =
                                   DISTRIBUTION_SOURCE_BOOK
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN DH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               DH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND DD.ASSET_ID = DH.ASSET_ID
                               AND DD.BOOK_TYPE_CODE = BOOK
                               AND DD.DISTRIBUTION_ID = DH.DISTRIBUTION_ID
                               AND DD.PERIOD_COUNTER <= PERIOD_PC
                               AND DECODE (BEGIN_OR_END,
                                           'BEGIN', DD.DEPRN_SOURCE_CODE,
                                           'D') =
                                   DD.DEPRN_SOURCE_CODE
                               AND DD.PERIOD_COUNTER =
                                   (SELECT MAX (SUB_DD.PERIOD_COUNTER)
                                      FROM FA_DEPRN_DETAIL SUB_DD
                                     WHERE     SUB_DD.BOOK_TYPE_CODE = BOOK
                                           AND SUB_DD.DISTRIBUTION_ID =
                                               DH.DISTRIBUTION_ID
                                           AND SUB_DD.PERIOD_COUNTER <=
                                               PERIOD_PC)
                               AND AH.ASSET_ID = DH.ASSET_ID
                               AND ((AH.ASSET_TYPE != 'EXPENSED' AND REPORT_TYPE IN ('COST', 'CIP COST')) OR (AH.ASSET_TYPE IN ('CAPITALIZED', 'CIP') AND REPORT_TYPE IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (DD.DEPRN_SOURCE_CODE,
                                           'D', P_DATE,
                                           A_DATE) BETWEEN AH.DATE_EFFECTIVE
                                                       AND NVL (
                                                               AH.DATE_INEFFECTIVE,
                                                               SYSDATE)
                               AND CB.CATEGORY_ID = AH.CATEGORY_ID
                               AND CB.BOOK_TYPE_CODE = BOOK
                               AND BK.BOOK_TYPE_CODE = BOOK
                               AND BK.ASSET_ID = DD.ASSET_ID
                               AND                    -- COMMENTED BY PRABAKAR
                                   (BK.TRANSACTION_HEADER_ID_IN =
                                    (SELECT MIN (FAB.TRANSACTION_HEADER_ID_IN)
                                       FROM FA_BOOKS_GROUPS BG, FA_BOOKS FAB
                                      WHERE     BG.GROUP_ASSET_ID =
                                                NVL (BK.GROUP_ASSET_ID, -2)
                                            AND BG.BOOK_TYPE_CODE =
                                                FAB.BOOK_TYPE_CODE
                                            AND FAB.TRANSACTION_HEADER_ID_IN <=
                                                BG.TRANSACTION_HEADER_ID_IN
                                            AND NVL (
                                                    FAB.TRANSACTION_HEADER_ID_OUT,
                                                    BG.TRANSACTION_HEADER_ID_IN) >=
                                                BG.TRANSACTION_HEADER_ID_IN
                                            AND BG.PERIOD_COUNTER =
                                                PERIOD_PC + 1
                                            AND FAB.ASSET_ID = BK.ASSET_ID
                                            AND FAB.BOOK_TYPE_CODE =
                                                BK.BOOK_TYPE_CODE
                                            AND BG.BEGINNING_BALANCE_FLAG
                                                    IS NOT NULL))
                               AND DECODE (
                                       REPORT_TYPE,
                                       'COST', DECODE (
                                                   AH.ASSET_TYPE,
                                                   'CAPITALIZED', CB.ASSET_COST_ACCT,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       AH.ASSET_TYPE,
                                                       'CIP', CB.CIP_COST_ACCT,
                                                       NULL),
                                       'RESERVE', CB.DEPRN_RESERVE_ACCT,
                                       'REVAL RESERVE', CB.REVAL_RESERVE_ACCT)
                                       IS NOT NULL;
                END IF;
            ELSE
                IF (H_REPORTING_FLAG = 'R')
                THEN
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT GAR.GROUP_ASSET_ID ASSET_ID, GAD.DEPRN_EXPENSE_ACCT_CCID, GAD.DEPRN_RESERVE_ACCT_CCID,
                               NULL, /* DECODE(REPORT_TYPE,
                                     'RESERVE', DECODE(DD.DEPRN_SOURCE_CODE,
                                         'D', BEGIN_OR_END, 'ADDITION'),
                                     'REVAL RESERVE',
                                 DECODE(DD.DEPRN_SOURCE_CODE,
                                         'D', BEGIN_OR_END, 'ADDITION'),
                                     BEGIN_OR_END),*/
                                     'END', DD.DEPRN_RESERVE
                          FROM FA_DEPRN_SUMMARY_MRC_V DD, FA_GROUP_ASSET_RULES GAR, FA_GROUP_ASSET_DEFAULT GAD
                         WHERE     DD.BOOK_TYPE_CODE = BOOK
                               AND DD.ASSET_ID = GAR.GROUP_ASSET_ID
                               AND GAR.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                               AND GAD.BOOK_TYPE_CODE = GAR.BOOK_TYPE_CODE
                               AND GAD.GROUP_ASSET_ID = GAR.GROUP_ASSET_ID
                               AND DD.PERIOD_COUNTER =
                                   (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                      FROM FA_DEPRN_DETAIL_MRC_V DD_SUB
                                     WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                           AND DD_SUB.ASSET_ID =
                                               GAR.GROUP_ASSET_ID
                                           AND DD_SUB.PERIOD_COUNTER <=
                                               PERIOD_PC);
                ELSE
                    INSERT INTO XXDO.XXDO_FA_BALANCES_REPORT_GT (
                                    ASSET_ID,
                                    DISTRIBUTION_CCID,
                                    ADJUSTMENT_CCID,
                                    CATEGORY_BOOKS_ACCOUNT,
                                    SOURCE_TYPE_CODE,
                                    AMOUNT)
                        SELECT GAR.GROUP_ASSET_ID ASSET_ID, GAD.DEPRN_EXPENSE_ACCT_CCID, GAD.DEPRN_RESERVE_ACCT_CCID,
                               NULL, /* DECODE(REPORT_TYPE,
                                     'RESERVE', DECODE(DD.DEPRN_SOURCE_CODE,
                                         'D', BEGIN_OR_END, 'ADDITION'),
                                     'REVAL RESERVE',
                                 DECODE(DD.DEPRN_SOURCE_CODE,
                                         'D', BEGIN_OR_END, 'ADDITION'),
                                     BEGIN_OR_END),*/
                                     'END', DD.DEPRN_RESERVE
                          FROM FA_DEPRN_SUMMARY DD, FA_GROUP_ASSET_RULES GAR, FA_GROUP_ASSET_DEFAULT GAD
                         WHERE     DD.BOOK_TYPE_CODE = BOOK
                               AND DD.ASSET_ID = GAR.GROUP_ASSET_ID
                               AND GAR.BOOK_TYPE_CODE = DD.BOOK_TYPE_CODE
                               AND GAD.BOOK_TYPE_CODE = GAR.BOOK_TYPE_CODE
                               AND GAD.GROUP_ASSET_ID = GAR.GROUP_ASSET_ID
                               AND DD.PERIOD_COUNTER =
                                   (SELECT MAX (DD_SUB.PERIOD_COUNTER)
                                      FROM FA_DEPRN_DETAIL DD_SUB
                                     WHERE     DD_SUB.BOOK_TYPE_CODE = BOOK
                                           AND DD_SUB.ASSET_ID =
                                               GAR.GROUP_ASSET_ID
                                           AND DD_SUB.PERIOD_COUNTER <=
                                               PERIOD_PC);
                END IF;
            END IF;
        END IF;                                            -- END OF CRL CHECK
    END GET_BALANCE_GROUP_END;

    FUNCTION ASSET_ACCOUNT_FN (P_BOOK IN VARCHAR2, P_ASSET_NUMBER IN VARCHAR2, --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                                                               -- P_CURRENCY       IN   NUMBER
                                                                               P_SOB_ID IN NUMBER
                               , P_PERIOD IN VARCHAR2)
        --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
        RETURN VARCHAR2
    IS
        V_EVENT_ID                NUMBER;
        V_AE_HEADER_ID            NUMBER;
        V_CONCATENATED_SEGMENTS   VARCHAR2 (207 BYTE);
        V_ASSET_ID                NUMBER;
        V_TRANSACTION_TYPE_CODE   VARCHAR2 (20 BYTE);
        L_CURRENCY_CODE           VARCHAR2 (15 BYTE);
        --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
        V_TRANSACTION_HEADER_ID   NUMBER;
    --End  modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
    BEGIN
        V_EVENT_ID                := NULL;
        V_CONCATENATED_SEGMENTS   := NULL;

        SELECT asset_id
          INTO v_asset_id
          FROM fa_additions
         WHERE asset_number = p_asset_number;

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'FUNC-Asset_ID:' || v_asset_id);        -- LAK

        SELECT currency_code
          INTO l_currency_code
          FROM gl_sets_of_books
         WHERE set_of_books_id = p_sob_id;

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'FUNC-Currency_Code:' || l_currency_code); -- LAK

        --         SELECT NVL (EVENT_ID, NULL), TRANSACTION_TYPE_CODE
        --           INTO V_EVENT_ID, V_TRANSACTION_TYPE_CODE
        --           FROM FA_TRANSACTION_HEADERS
        --          WHERE ASSET_ID = V_ASSET_ID
        --            AND TRANSACTION_HEADER_ID IN (
        --                          SELECT MAX (TRANSACTION_HEADER_ID)
        --                            FROM FA_TRANSACTION_HEADERS
        --                           WHERE ASSET_ID = V_ASSET_ID
        --                                 AND EVENT_ID IS NOT NULL);

        --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1

        BEGIN                                        --Added as per CCR0008486
            SELECT NVL (EVENT_ID, NULL), TRANSACTION_TYPE_CODE
              INTO V_EVENT_ID, V_TRANSACTION_TYPE_CODE
              FROM FA_TRANSACTION_HEADERS
             WHERE     ASSET_ID = V_ASSET_ID
                   AND TRANSACTION_HEADER_ID IN
                           (SELECT MAX (TRANSACTION_HEADER_ID)
                              FROM FA_TRANSACTION_HEADERS FTH, XLA_EVENTS XE
                             WHERE     FTH.EVENT_ID = XE.EVENT_ID
                                   AND XE.EVENT_STATUS_CODE <> 'N'
                                   AND FTH.EVENT_ID IS NOT NULL
                                   AND FTH.TRANSACTION_TYPE_CODE NOT LIKE
                                           'ADJUST%'
                                   AND FTH.ASSET_ID = V_ASSET_ID);
        --START Added as per CCR0008486
        EXCEPTION
            WHEN OTHERS
            THEN
                V_EVENT_ID                := NULL;
                V_TRANSACTION_TYPE_CODE   := NULL;
        END;

        --END Added as per CCR0008486

        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'FUNC-Event_ID:' || V_EVENT_ID);        -- LAK
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.LOG,
            'FUNC-TRANSACTION_TYPE_CODE:' || V_TRANSACTION_TYPE_CODE);  -- LAK

        BEGIN
            SELECT NVL (fth.event_id, NULL), fth.transaction_header_id, fth.transaction_type_code
              INTO V_EVENT_ID, V_TRANSACTION_HEADER_ID, V_TRANSACTION_TYPE_CODE
              FROM fa_transaction_headers fth
             WHERE fth.transaction_header_id IN
                       (SELECT MAX (ftht.transaction_header_id)
                          FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, xla_events xe,
                               --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                               fa_adjustments fa
                         --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                         WHERE     ftht.period_counter <=
                                   (SELECT fdp.period_counter
                                      FROM fa_deprn_periods fdp
                                     WHERE     fdp.book_type_code = p_book
                                           AND fdp.period_name = p_period)
                               AND fth.transaction_header_id =
                                   ftht.transaction_header_id
                               --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                               AND fth.transaction_header_id =
                                   fa.transaction_header_id
                               AND fa.adjustment_type = 'COST'
                               --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                               AND xe.event_id = fth.event_id
                               AND xe.event_status_code <> 'N'
                               AND fth.event_id IS NOT NULL
                               AND ftht.ASSET_ID = v_asset_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                V_EVENT_ID                := NULL;
                V_TRANSACTION_TYPE_CODE   := NULL;
                V_TRANSACTION_HEADER_ID   := NULL;
        END;

        --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
        APPS.FND_FILE.PUT_LINE (APPS.FND_FILE.LOG,
                                'FUNC-V_EVENT_ID:' || V_EVENT_ID);      -- LAK
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.LOG,
            'FUNC-V_TRANSACTION_HEADER_ID:' || V_TRANSACTION_HEADER_ID); -- LAK
        APPS.FND_FILE.PUT_LINE (
            APPS.FND_FILE.LOG,
            'FUNC-V_TRANSACTION_TYPE_CODE:' || V_TRANSACTION_TYPE_CODE); -- LAK

        IF V_EVENT_ID IS NOT NULL
        THEN
            V_AE_HEADER_ID   := NULL;

            BEGIN
                SELECT NVL (xah.ae_header_id, NULL)
                  INTO v_ae_header_id
                  FROM xla_ae_headers xah, gl_ledgers gll
                 WHERE     xah.event_id = v_event_id
                       AND xah.ledger_id = gll.ledger_id
                       --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                       --AND GLL.CURRENCY_CODE = L_CURRENCY_CODE;
                       AND gll.ledger_id = p_sob_id;

                --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                APPS.FND_FILE.PUT_LINE (
                    APPS.FND_FILE.LOG,
                    'FUNC-v_ae_header_id:' || v_ae_header_id);          -- LAK
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_AE_HEADER_ID   := NULL;
            END;

            IF V_AE_HEADER_ID IS NOT NULL
            THEN
                IF V_TRANSACTION_TYPE_CODE LIKE '%RETIR%'
                THEN
                    ---FOR  RETIREMET CASE
                    BEGIN
                        SELECT gcc.concatenated_segments
                          INTO v_concatenated_segments
                          FROM xla_ae_lines xla, gl_code_combinations_kfv gcc
                         WHERE     xla.ae_header_id = v_ae_header_id
                               AND xla.code_combination_id =
                                   gcc.code_combination_id
                               AND xla.accounting_class_code = 'ASSET'
                               AND xla.entered_cr IS NOT NULL
                               AND gcc.segment6 IN
                                       (SELECT cc_cst.segment6
                                          FROM fa_additions ad, fa_categories fc, fa_category_books fcb,
                                               gl_code_combinations_kfv cc_cst, --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                                                                fa_transaction_history_trx_v ftht
                                         --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                         WHERE     ftht.category_id =
                                                   fc.category_id
                                               --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                               AND ad.asset_id =
                                                   ftht.asset_id
                                               --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                               AND fc.category_id =
                                                   fcb.category_id
                                               AND fcb.book_type_code =
                                                   p_book
                                               AND fcb.asset_cost_account_ccid =
                                                   cc_cst.code_combination_id
                                               AND ad.asset_id = v_asset_id
                                               --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                               AND ftht.transaction_header_id =
                                                   v_transaction_header_id);
                    --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            v_concatenated_segments   := NULL;
                    END;
                ELSE
                    ---FOR NOT RETIREMENT CASE
                    APPS.FND_FILE.PUT_LINE (
                        APPS.FND_FILE.LOG,
                        'FUNC-inside not retirement case');             -- LAK

                    BEGIN
                        /*   SELECT gcc.concatenated_segments
                             INTO v_concatenated_segments
                             FROM xla_ae_lines xla, gl_code_combinations_kfv gcc
                            WHERE xla.ae_header_id = v_ae_header_id
                              AND xla.code_combination_id = gcc.code_combination_id
                              AND xla.accounting_class_code = 'ASSET'
                              AND xla.entered_dr IS NOT NULL
                              AND gcc.segment6 IN (
                                     SELECT cc_cst.segment6
                                       FROM fa_additions ad,
                                            fa_categories fc,
                                            fa_category_books fcb,
                                            gl_code_combinations_kfv cc_cst,
                                             --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                             fa_transaction_history_trx_v ftht
                                             --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                      WHERE ftht.category_id = fc.category_id
                                      --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                       AND ad.asset_id = ftht.asset_id
                                       --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                        AND fc.category_id = fcb.category_id
                                        AND fcb.book_type_code = p_book
                                        AND fcb.asset_cost_account_ccid = cc_cst.code_combination_id
                                        AND ad.asset_id = v_asset_id
                                        --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                        AND ftht.transaction_header_id = v_transaction_header_id);
                                        --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1 */

                        --   SELECT gcck.concatenated_segments
                        SELECT DISTINCT (gcck.concatenated_segments) -- Modified for 1.6.
                          INTO v_concatenated_segments
                          FROM FA_ADJUSTMENTS fa, fa_transaction_headers fth, xla_ae_headers xah,
                               xla_ae_lines xal, gl_ledgers gll, xla_distribution_links xdl,
                               gl_code_combinations_kfv gcck
                         WHERE     fa.transaction_header_id =
                                   fth.transaction_header_id
                               AND xah.event_id = fth.event_id
                               AND xah.ledger_id = gll.ledger_id
                               AND xdl.event_id = xah.event_id
                               AND xdl.ae_header_id = xah.ae_header_id
                               AND xal.ae_header_id = xdl.ae_header_id
                               AND xah.ae_header_id = xal.ae_header_id
                               AND xdl.source_distribution_id_num_2 =
                                   fa.adjustment_line_id
                               AND xdl.ae_line_num = xal.ae_line_num
                               AND xal.code_combination_id =
                                   gcck.code_combination_id
                               AND fth.transaction_header_id =
                                   (SELECT MAX (ftht.transaction_header_id)
                                      FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, xla_events xe,
                                           fa_adjustments fa
                                     WHERE     ftht.period_counter <=
                                               (SELECT fdp.period_counter
                                                  FROM fa_deprn_periods fdp
                                                 WHERE     fdp.book_type_code =
                                                           p_book
                                                       AND fdp.period_name =
                                                           p_period)
                                           AND fth.transaction_header_id =
                                               ftht.transaction_header_id
                                           AND fth.transaction_header_id =
                                               fa.transaction_header_id
                                           AND fa.adjustment_type = 'COST'
                                           AND xe.event_id = fth.event_id
                                           AND xe.EVENT_STATUS_CODE <> 'N'
                                           AND fth.event_id IS NOT NULL
                                           AND ftht.asset_id = v_asset_id)
                               AND fa.adjustment_type = 'COST'
                               AND NVL (fa.source_dest_code, 'DEST') = 'DEST'
                               AND gll.ledger_id = p_sob_id;


                        APPS.FND_FILE.PUT_LINE (
                            APPS.FND_FILE.LOG,
                               'v_concatenated_segments'
                            || v_concatenated_segments);
                    EXCEPTION
                        -- START : Added for 1.6.
                        WHEN NO_DATA_FOUND
                        THEN
                            SELECT DISTINCT (gcck.concatenated_segments)
                              INTO v_concatenated_segments
                              FROM FA_ADJUSTMENTS fa, fa_transaction_headers fth, xla_ae_headers xah,
                                   xla_ae_lines xal, gl_ledgers gll, xla_distribution_links xdl,
                                   gl_code_combinations_kfv gcck
                             WHERE     fa.transaction_header_id =
                                       fth.transaction_header_id
                                   AND xah.event_id = fth.event_id
                                   AND xah.ledger_id = gll.ledger_id
                                   AND xdl.event_id = xah.event_id
                                   AND xdl.ae_header_id = xah.ae_header_id
                                   AND xal.ae_header_id = xdl.ae_header_id
                                   AND xah.ae_header_id = xal.ae_header_id
                                   AND xdl.source_distribution_id_num_2 =
                                       fa.adjustment_line_id
                                   AND xdl.ae_line_num = xal.ae_line_num
                                   AND xal.code_combination_id =
                                       gcck.code_combination_id
                                   AND fth.transaction_header_id =
                                       (SELECT MAX (ftht.transaction_header_id)
                                          FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, xla_events xe,
                                               fa_adjustments fa
                                         WHERE     ftht.period_counter <=
                                                   (SELECT fdp.period_counter
                                                      FROM fa_deprn_periods fdp
                                                     WHERE     fdp.book_type_code =
                                                               p_book
                                                           AND fdp.period_name =
                                                               p_period)
                                               AND fth.transaction_header_id =
                                                   ftht.transaction_header_id
                                               AND fth.transaction_header_id =
                                                   fa.transaction_header_id
                                               AND fa.adjustment_type =
                                                   'COST'
                                               AND xe.event_id = fth.event_id
                                               AND xe.EVENT_STATUS_CODE <>
                                                   'N'
                                               AND fth.event_id IS NOT NULL
                                               AND ftht.asset_id = v_asset_id)
                                   AND fa.adjustment_type = 'COST'
                                   AND NVL (fa.source_dest_code, 'SOURCE') =
                                       'SOURCE'
                                   AND gll.ledger_id = p_sob_id;

                            APPS.FND_FILE.PUT_LINE (
                                APPS.FND_FILE.LOG,
                                   'v_concatenated_segments (from NO_DATA_FOUND) : '
                                || v_concatenated_segments);
                        -- END : Added for 1.6.
                        WHEN OTHERS
                        THEN
                            v_concatenated_segments   := NULL;
                    END;
                END IF;
            END IF;
        END IF;

        V_CONCATENATED_SEGMENTS   := NVL (V_CONCATENATED_SEGMENTS, NULL);
        RETURN V_CONCATENATED_SEGMENTS;
    END;

    FUNCTION ASSET_RESERVE_ACCOUNT_FN (P_BOOK IN VARCHAR2, P_PERIOD IN VARCHAR2, P_ASSET_NUMBER IN VARCHAR2
                                       , --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                         --P_CURRENCY       IN   NUMBER
                                         P_SOB_ID IN NUMBER--End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                                           )
        RETURN VARCHAR2
    IS
        V_EVENT_ID                NUMBER;
        V_AE_HEADER_ID            NUMBER;
        V_CONCATENATED_SEGMENTS   VARCHAR2 (207 BYTE);
        V_ASSET_ID                NUMBER;
        V_TRANSACTION_TYPE_CODE   VARCHAR2 (20 BYTE);
        L_CURRENCY_CODE           VARCHAR2 (15 BYTE);
        --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
        V_TRANSACTION_HEADER_ID   NUMBER;
    --End  modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1

    BEGIN
        V_EVENT_ID                := NULL;
        V_CONCATENATED_SEGMENTS   := NULL;
        V_TRANSACTION_TYPE_CODE   := NULL;

        SELECT asset_id
          INTO v_asset_id
          FROM fa_additions
         WHERE asset_number = p_asset_number;

        SELECT currency_code
          INTO l_currency_code
          FROM gl_sets_of_books
         WHERE set_of_books_id = p_sob_id;

        BEGIN
            SELECT DISTINCT NVL (event_id, NULL)
              INTO v_event_id
              FROM fa_deprn_detail
             WHERE     asset_id = v_asset_id
                   AND period_counter IN
                           (SELECT period_counter
                              FROM fa_deprn_periods
                             WHERE     book_type_code = p_book
                                   AND period_name = p_period)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                V_EVENT_ID   := NULL;
        END;

        /*IF EVENT ID IS NOT FOUND FOR A PERTICULAR PERIOD THEN BELOW LOGIC*/
        /*  IF V_EVENT_ID IS NULL
          THEN
             BEGIN
                SELECT DISTINCT NVL (EVENT_ID, NULL)
                           INTO V_EVENT_ID
                           FROM FA_DEPRN_DETAIL
                          WHERE ASSET_ID = V_ASSET_ID
                            AND PERIOD_COUNTER IN (
                                   SELECT MAX (FDP.PERIOD_COUNTER)
                                     FROM FA_DEPRN_PERIODS FDP, FA_DEPRN_DETAIL FDD
                                    WHERE FDP.BOOK_TYPE_CODE = P_BOOK
                                      AND FDD.PERIOD_COUNTER = FDP.PERIOD_COUNTER
                                      AND FDD.ASSET_ID = V_ASSET_ID
                                      AND FDD.EVENT_ID IS NOT NULL)
                            AND ROWNUM = 1;
             EXCEPTION
                WHEN OTHERS
                THEN
                   V_EVENT_ID := NULL;
             END;
          END IF;*/
        IF V_EVENT_ID IS NOT NULL
        THEN
            V_AE_HEADER_ID   := NULL;

            BEGIN
                SELECT NVL (xah.ae_header_id, NULL)
                  INTO v_ae_header_id
                  FROM xla_ae_headers xah, gl_ledgers gll
                 WHERE     xah.event_id = v_event_id
                       AND xah.ledger_id = gll.ledger_id
                       --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                       --AND GLL.CURRENCY_CODE = L_CURRENCY_CODE;
                       AND gll.ledger_id = p_sob_id;
            --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_AE_HEADER_ID   := NULL;
            END;

            IF V_AE_HEADER_ID IS NOT NULL
            THEN
                BEGIN
                    SELECT gcc.concatenated_segments
                      INTO v_concatenated_segments
                      FROM xla_ae_lines xla, gl_code_combinations_kfv gcc
                     WHERE     xla.ae_header_id = v_ae_header_id
                           AND xla.code_combination_id =
                               gcc.code_combination_id
                           AND xla.accounting_class_code = 'ASSET'
                           AND xla.entered_cr IS NOT NULL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        V_CONCATENATED_SEGMENTS   := NULL;
                END;
            END IF;
        END IF;

        --Asset is Retired
        IF V_CONCATENATED_SEGMENTS IS NULL
        THEN
            BEGIN
                --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                SELECT NVL (fth1.event_id, NULL), fth1.transaction_header_id, fth1.transaction_type_code
                  INTO v_event_id, v_transaction_header_id, v_transaction_type_code
                  FROM fa_transaction_headers fth1
                 WHERE fth1.transaction_header_id IN
                           (SELECT MAX (ftht.transaction_header_id)
                              FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, xla_events xe,
                                   --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                   fa_adjustments fa
                             --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                             WHERE     ftht.period_counter <=
                                       (SELECT fdp.period_counter
                                          FROM fa_deprn_periods fdp
                                         WHERE     fdp.book_type_code =
                                                   p_book
                                               AND fdp.period_name = p_period)
                                   AND fth.transaction_header_id =
                                       ftht.transaction_header_id
                                   --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                   AND fth.transaction_header_id =
                                       fa.transaction_header_id
                                   AND fa.adjustment_type = 'COST'
                                   --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                   AND xe.event_id = fth.event_id
                                   AND xe.EVENT_STATUS_CODE <> 'N'
                                   AND fth.event_id IS NOT NULL
                                   AND ftht.asset_id = v_asset_id);
            --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
            EXCEPTION
                WHEN OTHERS
                THEN
                    V_EVENT_ID                := NULL;
                    V_TRANSACTION_TYPE_CODE   := NULL;
                    v_transaction_header_id   := NULL;
            END;

            IF V_EVENT_ID IS NOT NULL
            THEN
                V_AE_HEADER_ID   := NULL;

                BEGIN
                    SELECT NVL (xah.ae_header_id, NULL)
                      INTO v_ae_header_id
                      FROM xla_ae_headers xah, gl_ledgers gll
                     WHERE     xah.event_id = v_event_id
                           AND xah.ledger_id = gll.ledger_id
                           --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                           --AND GLL.CURRENCY_CODE = L_CURRENCY_CODE;
                           AND gll.ledger_id = p_sob_id;
                --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        V_AE_HEADER_ID   := NULL;
                END;

                IF V_AE_HEADER_ID IS NOT NULL
                THEN
                    BEGIN
                        SELECT gcc.concatenated_segments
                          INTO v_concatenated_segments
                          FROM xla_ae_lines xla, gl_code_combinations_kfv gcc
                         WHERE     xla.ae_header_id = v_ae_header_id
                               AND xla.code_combination_id =
                                   gcc.code_combination_id
                               AND xla.accounting_class_code = 'ASSET'
                               AND xla.entered_dr IS NOT NULL
                               AND gcc.segment6 IN
                                       (SELECT cc_cst.segment6
                                          FROM fa_additions ad, fa_categories fc, fa_category_books fcb,
                                               gl_code_combinations_kfv cc_cst, --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                                                                fa_transaction_history_trx_v ftht
                                         WHERE     ftht.category_id =
                                                   fc.category_id
                                               AND ad.asset_id =
                                                   ftht.asset_id
                                               --End modificaion for defect 701,dt 23-nov-15,By BT Technology Team,V1.1
                                               AND ad.asset_category_id =
                                                   fc.category_id
                                               AND fc.category_id =
                                                   fcb.category_id
                                               AND fcb.book_type_code =
                                                   p_book
                                               AND fcb.deprn_reserve_acct =
                                                   cc_cst.segment6
                                               ----accumulated depreciation account
                                               AND ad.asset_id = v_asset_id
                                               AND ROWNUM = 1);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            V_CONCATENATED_SEGMENTS   := NULL;
                    END;
                END IF;
            END IF;
        END IF;

        V_CONCATENATED_SEGMENTS   := NVL (V_CONCATENATED_SEGMENTS, NULL);
        RETURN V_CONCATENATED_SEGMENTS;
    END;

    --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
    FUNCTION ASSET_CATEGORY_FN (P_BOOK           IN VARCHAR2,
                                P_PERIOD         IN VARCHAR2,
                                P_ASSET_NUMBER   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        V_ASSET_ID            NUMBER;
        v_asset_cost_group    VARCHAR2 (350);
        v_asset_category_id   NUMBER;
    BEGIN
        SELECT asset_id
          INTO v_asset_id
          FROM fa_additions
         WHERE asset_number = p_asset_number;


        BEGIN
            SELECT ftht.category_id
              INTO v_asset_category_id
              FROM fa_transaction_headers fth, fa_transaction_history_trx_v ftht
             WHERE     fth.transaction_header_id = ftht.transaction_header_id
                   AND fth.transaction_header_id IN
                           (SELECT MAX (ftht.transaction_header_id)
                              FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                                                                                  fa_adjustments fa,
                                   --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                   xla_events xe
                             WHERE     ftht.period_counter <=
                                       (SELECT fdp.period_counter
                                          FROM fa_deprn_periods fdp
                                         WHERE     fdp.book_type_code =
                                                   p_book
                                               AND fdp.period_name = p_period)
                                   AND fth.transaction_header_id =
                                       ftht.transaction_header_id
                                   --Start modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                   AND fth.transaction_header_id =
                                       fa.transaction_header_id
                                   AND fa.adjustment_type = 'COST'
                                   --End modificaion for Defect 701,Dt 2-Dec-15,By BT Technology Team,V1.3
                                   AND fth.event_id IS NOT NULL
                                   AND xe.event_id = fth.event_id
                                   AND xe.EVENT_STATUS_CODE <> 'N'
                                   AND ftht.asset_id = v_asset_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                v_asset_category_id   := NULL;
        END;

        BEGIN
            SELECT fc.segment1 || '.' || fc.segment2 || '.' || fc.segment3 asset_cost_group
              INTO v_asset_cost_group
              FROM fa_categories fc
             WHERE category_id = v_asset_category_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                v_asset_cost_group   := NULL;
        END;

        RETURN v_asset_cost_group;
    END;

    --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1

    --Start modification for Defect 701,Dt 04-Dec-15,By BT Technology Team,V1.4
    FUNCTION ASSET_RSV_ACCOUNT_NULL_FN (P_BOOK IN VARCHAR2, P_ASSET_NUMBER IN VARCHAR2, P_SOB_ID IN NUMBER
                                        , P_PERIOD IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_segment6            VARCHAR2 (25);
        ln_asset_id            NUMBER;
        ln_asset_category_id   NUMBER;
    BEGIN
        BEGIN
            SELECT asset_id
              INTO ln_asset_id
              FROM fa_additions
             WHERE asset_number = p_asset_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_asset_id   := 0;
        END;

        BEGIN
            SELECT ftht.category_id
              INTO ln_asset_category_id
              FROM fa_transaction_headers fth, fa_transaction_history_trx_v ftht
             WHERE     fth.transaction_header_id = ftht.transaction_header_id
                   AND fth.transaction_header_id =
                       (SELECT MAX (ftht.transaction_header_id)
                          FROM fa_transaction_history_trx_v ftht, fa_transaction_headers fth, fa_adjustments fa,
                               xla_events xe
                         WHERE     ftht.period_counter <=
                                   (SELECT fdp.period_counter
                                      FROM fa_deprn_periods fdp
                                     WHERE     fdp.book_type_code = p_book
                                           AND fdp.period_name = p_period)
                               AND fth.transaction_header_id =
                                   ftht.transaction_header_id
                               AND fth.transaction_header_id =
                                   fa.transaction_header_id
                               AND fa.adjustment_type = 'COST'
                               AND fth.event_id IS NOT NULL
                               AND xe.event_id = fth.event_id
                               AND xe.event_status_code <> 'N'
                               AND ftht.asset_id = ln_asset_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_asset_category_id   := 0;
        END;

        BEGIN
            SELECT deprn_reserve_acct
              INTO lv_segment6
              FROM fa_category_books
             WHERE     category_id = ln_asset_category_id
                   AND book_type_code = p_book;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_segment6   := 0;
        END;

        RETURN lv_segment6;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_segment6   := NULL;
            RETURN lv_segment6;
    END;
--End modificaion for Defect 701,Dt 04-Dec-15,By BT Technology Team,V1.4
END XXD_FA_ASSET_EXTRACT_PKG;
/
