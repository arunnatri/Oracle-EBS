--
-- XXD_AP_CH_TAX_INT  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_CH_TAX_INT"
IS
    --  ###################################################################################################
    --  Author(s)       : Tejaswi Gangumalla (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Schema          : APPS
    --  Purpose         : Oracle Localization  of Co170 ,190 and 510 for Tax Audit Purpose
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  20-Nov-2017     Tejaswi Gsngumalla   1.0     NA              Initial Version
    --  ####################################################################################################
    gn_user_id      CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;

    PROCEDURE MAIN_PROC (pv_errbuf OUT NOCOPY VARCHAR2, pn_retcode OUT NOCOPY NUMBER, pn_primary_ledger_id IN NUMBER, pn_secondary_ledger_id IN NUMBER, pn_entity_id IN NUMBER, pv_from_period IN VARCHAR2, pv_to_period IN VARCHAR2, pv_directory_name IN VARCHAR2, pv_temp IN VARCHAR2
                         , pv_over_write IN VARCHAR2)
    IS
        ld_from_date                     DATE := fnd_date.canonical_to_date (pv_from_period);
        ld_to_date                       DATE := fnd_date.canonical_to_date (pv_to_period);
        lv_primary_calender              VARCHAR2 (20);
        lv_secondary_calender            VARCHAR2 (20);
        lv_primary_start_period_name     VARCHAR2 (20);
        lv_primary_end_period_name       VARCHAR2 (20);
        lv_secondary_start_period_name   VARCHAR2 (20);
        lv_secondary_end_period_name     VARCHAR2 (20);
        ld_primary_period_start_date     DATE;
        ld_primary_period_end_date       DATE;
        ld_secondary_period_start_date   DATE;
        ld_secondary_period_end_date     DATE;
        -- lv_outbound_dir         CONSTANT VARCHAR2 (100)  := 'XXD_AP_CH_TAX_INT';
        -- :='/f01/EBSDEV1'; --
        lv_ob_file_timestamp             VARCHAR2 (20)
            := TO_CHAR (SYSDATE, 'DDMONYYHH24MISS');
        lv_outbound_file                 VARCHAR2 (100);
        lv_output_file                   UTL_FILE.file_type;
        lv_err_msg                       VARCHAR2 (2000);
        lv_line                          VARCHAR2 (4000);
        ln_cnt                           NUMBER := 0;
        lv_status                        VARCHAR2 (2);

        -- ln_secondary_ledger_id           NUMBER;
        --  ln_entity_id                     NUMBER;

        CURSOR xxd_data_primary_cur IS
            SELECT 'Period Name' || '|' || 'Source' || '|' || 'Category' || '|' || 'Currency_Code' || '|' || 'Journal Name' || '|' || 'Account_Combination' || '|' || 'Entered Dr' || '|' || 'Entered cr' || '|' || 'JE_Entered_Amount' || '|' || 'GL line num' || '|' || 'Accounted Dr' || '|' || 'Accounted Cr' || '|' || 'JE_Accounted_Amount' || '|' || 'Description' || '|' || 'User_Name' || '|' || 'Document Number' || '|' || 'Ledger Name' || '|' || 'GL Date' data_record
              FROM DUAL
            UNION ALL
            SELECT REPLACE (xx.default_period_name, '|', '') || '|' || REPLACE (xx.user_je_source_name, '|', '') || '|' || REPLACE (xx.user_je_category_name, '|', '') || '|' || REPLACE (xx.currency_code, '|', '') || '|' || REPLACE (xx.journal_name, '|', '') || '|' || REPLACE (xx.concatenated_segments, '|', '') || '|' || REPLACE (xx.entered_dr, '|', '') || '|' || REPLACE (xx.entered_cr, '|', '') || '|' || REPLACE (ROUND (+NVL (xx.entered_dr, 0) - NVL (xx.entered_cr, 0), 2), '|', '') || '|' || REPLACE (xx.je_line_num, '|', '') || '|' || REPLACE (xx.accounted_dr, '|', '') || '|' || REPLACE (xx.accounted_cr, '|', '') || '|' || REPLACE (ROUND (+NVL (xx.accounted_dr, 0) - NVL (xx.accounted_cr, 0), 2), '|', '') || '|' || REPLACE (xx.description, '|', '') || '|' || REPLACE (xx.user_name, '|', '') || '|' || REPLACE (xx.je_header_id, '|', '') || '|' || REPLACE (xx.ledger_name, '|', '') || '|' || REPLACE (xx.default_effective_date, '|', '')
              FROM (  SELECT gjb.default_period_name, --gjh.je_source,
                                                      --gjc.je_category_name,
                                                      gjs.user_je_source_name, gjc.user_je_category_name,
                             gjh.currency_code, gjh.NAME journal_name, gcc.concatenated_segments,
                             gjl.entered_dr, gjl.entered_cr, ROUND (+NVL (gjl.entered_dr, 0) - NVL (gjl.entered_cr, 0), 2),
                             gjl.je_line_num, gjl.accounted_dr, gjl.accounted_cr,
                             ROUND (+NVL (gjl.accounted_dr, 0) - NVL (gjl.accounted_cr, 0), 2), gjl.description, u.user_name,
                             --gjh.doc_sequence_value,
                             gjh.je_header_id, gld.NAME ledger_name, gjh.default_effective_date
                        FROM apps.gl_je_batches gjb, apps.gl_je_headers gjh, apps.gl_je_sources_tl gjs,
                             apps.gl_je_lines gjl, apps.gl_je_categories gjc, apps.gl_code_combinations_kfv gcc,
                             apps.fnd_user u, apps.gl_ledgers gld
                       WHERE     gjb.je_batch_id = gjh.je_batch_id
                             AND u.user_id = gjl.created_by
                             AND gjh.je_header_id = gjl.je_header_id
                             AND gjh.je_source = gjs.je_source_name
                             AND gjh.je_category = gjc.je_category_name
                             AND gjh.ledger_id = gld.ledger_id
                             AND gjl.code_combination_id =
                                 gcc.code_combination_id
                             AND gcc.segment1 =
                                 NVL (pn_entity_id, gcc.segment1)
                             AND gjh.ledger_id = pn_primary_ledger_id --IN (2024) -- (Put the correct ledger id based on the first step, currently 2024 is for the current EBS production)
                             AND gjs.LANGUAGE = 'US'
                             AND UPPER (gjs.user_je_source_name) = 'PAYABLES'
                             AND gjh.default_effective_date >=
                                 ld_primary_period_start_date
                             AND gjh.default_effective_date <=
                                 ld_primary_period_end_date
                    --   AND gjh.je_header_id='620542'
                    ORDER BY gjb.default_period_name, gjh.je_header_id, gjh.NAME,
                             gjl.je_line_num) xx
            UNION ALL
            SELECT REPLACE (xx.default_period_name, '|', '') || '|' || REPLACE (xx.user_je_source_name, '|', '') || '|' || REPLACE (xx.user_je_category_name, '|', '') || '|' || REPLACE (xx.currency_code, '|', '') || '|' || REPLACE (xx.journal_name, '|', '') || '|' || REPLACE (xx.concatenated_segments, '|', '') || '|' || REPLACE (xx.entered_dr, '|', '') || '|' || REPLACE (xx.entered_cr, '|', '') || '|' || REPLACE (ROUND (+NVL (xx.entered_dr, 0) - NVL (xx.entered_cr, 0), 2), '|', '') || '|' || REPLACE (xx.je_line_num, '|', '') || '|' || REPLACE (xx.accounted_dr, '|', '') || '|' || REPLACE (xx.accounted_cr, '|', '') || '|' || REPLACE (ROUND (+NVL (xx.accounted_dr, 0) - NVL (xx.accounted_cr, 0), 2), '|', '') || '|' || REPLACE (xx.description, '|', '') || '|' || REPLACE (xx.user_name, '|', '') || '|' || REPLACE (xx.je_header_id, '|', '') || '|' || REPLACE (xx.ledger_name, '|', '') || '|' || REPLACE (xx.default_effective_date, '|', '')
              FROM (  SELECT gjb.default_period_name, --gjh.je_source ""JE Source"",
                                                      --gjc.je_category_name ""JE Category"",
                                                      gjs.user_je_source_name, gjc.user_je_category_name,
                             gjh.currency_code, gjh.NAME journal_name, gcc.concatenated_segments,
                             gjl.entered_dr, gjl.entered_cr, ROUND (+NVL (gjl.entered_dr, 0) - NVL (gjl.entered_cr, 0), 2),
                             gjl.je_line_num, gjl.accounted_dr, gjl.accounted_cr,
                             ROUND (+NVL (gjl.accounted_dr, 0) - NVL (gjl.accounted_cr, 0), 2), gjl.description, u.user_name,
                             --gjh.doc_sequence_value ""Document Number"",
                             gjh.je_header_id, gld.NAME ledger_name, gjh.default_effective_date
                        FROM apps.gl_je_batches gjb, apps.gl_je_headers gjh, apps.gl_je_sources_tl gjs,
                             apps.gl_je_lines gjl, apps.gl_je_categories gjc, apps.gl_code_combinations_kfv gcc,
                             apps.fnd_user u, apps.gl_ledgers gld
                       WHERE     gjb.je_batch_id = gjh.je_batch_id
                             AND u.user_id = gjl.created_by
                             AND gjh.je_header_id = gjl.je_header_id
                             AND gjh.je_source = gjs.je_source_name
                             AND gjh.je_category = gjc.je_category_name
                             AND gjh.ledger_id = gld.ledger_id
                             AND gjl.code_combination_id =
                                 gcc.code_combination_id
                             AND gcc.segment1 =
                                 NVL (pn_entity_id, gcc.segment1)
                             AND gjh.ledger_id = pn_secondary_ledger_id --IN (2047)
                             AND gjs.LANGUAGE = 'US'
                             AND UPPER (gjs.user_je_source_name) <> 'PAYABLES'
                             AND gjh.default_effective_date >=
                                 ld_secondary_period_start_date
                             AND gjh.default_effective_date <=
                                 ld_secondary_period_end_date
                    ORDER BY gjb.default_period_name, gjh.je_header_id, gjh.NAME,
                             gjl.je_line_num) xx;
    BEGIN
        --Inserting parameters into staging table xxdo.xxd_ap_ch_tax_int_stg
        BEGIN
            INSERT INTO xxd_ap_ch_tax_int_stg (request_id,
                                               parameter_primary_ledger,
                                               parameter_secondary_ledger,
                                               parameter_legal_entity_id,
                                               parameter_from_date,
                                               parameter_to_date,
                                               parameter_directory,
                                               parameter_over_write,
                                               request_start_date,
                                               request_end_date,
                                               created_by,
                                               created_date,
                                               last_updated_by,
                                               last_updated_date)
                 VALUES (gn_request_id, pn_primary_ledger_id, pn_secondary_ledger_id, pn_entity_id, pv_from_period, pv_to_period, pv_directory_name, pv_over_write, SYSDATE, NULL, gn_user_id, SYSDATE
                         , gn_user_id, SYSDATE);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'Error in inserting data into staging table: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
        END;



        -- Getting primary calender name
        BEGIN
            SELECT period_set_name
              INTO lv_primary_calender
              FROM gl_ledgers
             WHERE ledger_id = pn_primary_ledger_id;
        -- fnd_file.put_line (fnd_file.LOG, lv_primary_calender);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'Error in getting calender name for primary ledger: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                pn_retcode   := gn_error;
        END;

        --Getting primary starting period name
        BEGIN
            SELECT period_name
              INTO lv_primary_start_period_name
              FROM gl_periods
             WHERE     period_set_name = lv_primary_calender
                   AND ld_from_date BETWEEN start_date AND end_date;
        --   fnd_file.put_line (fnd_file.LOG, lv_primary_start_period_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'Error in getting period start for primary ledger: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                pn_retcode   := gn_error;
        END;

        --Getting primary ending period name
        BEGIN
            SELECT period_name
              INTO lv_primary_end_period_name
              FROM gl_periods
             WHERE     period_set_name = lv_primary_calender
                   AND ld_to_date BETWEEN start_date AND end_date;
        --   fnd_file.put_line (fnd_file.LOG, lv_primary_end_period_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'Error in getting period end for primary ledger: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                pn_retcode   := gn_error;
        END;

        --Getting Primary start date
        BEGIN
            SELECT start_date
              INTO ld_primary_period_start_date
              FROM gl_periods
             WHERE     period_set_name = lv_primary_calender
                   AND period_name = lv_primary_start_period_name;
        --   fnd_file.put_line (fnd_file.LOG, ld_primary_period_start_date);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'Error in getting start date of period for primary ledger: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                pn_retcode   := gn_error;
        END;

        --Getting Primary end date
        BEGIN
            SELECT end_date
              INTO ld_primary_period_end_date
              FROM gl_periods
             WHERE     period_set_name = lv_primary_calender
                   AND period_name = lv_primary_end_period_name;
        -- fnd_file.put_line (fnd_file.LOG, ld_primary_period_end_date);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'Error in getting end date of period for primary ledger: '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                pn_retcode   := gn_error;
        END;

        IF pn_secondary_ledger_id IS NOT NULL
        THEN
            -- Getting secondary calender name
            BEGIN
                SELECT period_set_name
                  INTO lv_secondary_calender
                  FROM gl_ledgers
                 WHERE ledger_id = pn_secondary_ledger_id;
            -- fnd_file.put_line (fnd_file.LOG, lv_secondary_calender);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in getting calender name for secondary ledger: '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    pn_retcode   := gn_error;
            END;

            --Getting secondary starting period name
            BEGIN
                SELECT period_name
                  INTO lv_secondary_start_period_name
                  FROM gl_periods
                 WHERE     period_set_name = lv_secondary_calender
                       AND ld_from_date BETWEEN start_date AND end_date;
            --   fnd_file.put_line (fnd_file.LOG, lv_primary_start_period_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in getting period start for secondary ledger: '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    pn_retcode   := gn_error;
            END;

            --Getting secondary ending period name
            BEGIN
                SELECT period_name
                  INTO lv_secondary_end_period_name
                  FROM gl_periods
                 WHERE     period_set_name = lv_secondary_calender
                       AND ld_to_date BETWEEN start_date AND end_date;
            --   fnd_file.put_line (fnd_file.LOG, lv_primary_end_period_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in getting period end for secondary ledger: '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    pn_retcode   := gn_error;
            END;

            --Getting Secondary start date
            BEGIN
                SELECT start_date
                  INTO ld_secondary_period_start_date
                  FROM gl_periods
                 WHERE     period_set_name = lv_secondary_calender
                       AND period_name = lv_secondary_start_period_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in getting start date of period for secondary ledger: '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    pn_retcode   := gn_error;
            END;

            --Getting Secondary end date
            BEGIN
                SELECT end_date
                  INTO ld_secondary_period_end_date
                  FROM gl_periods
                 WHERE     period_set_name = lv_secondary_calender
                       AND period_name = lv_secondary_end_period_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in getting end date of period for secondary ledger: '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    pn_retcode   := gn_error;
            END;
        END IF;


        IF     pv_directory_name IS NOT NULL
           AND NVL (pv_over_write, 'Yes') = 'Yes'
        THEN
            IF pn_entity_id IS NOT NULL
            THEN
                lv_outbound_file   :=
                       'Journal_Extract_'
                    || pn_entity_id
                    || '_From_'
                    || ld_from_date
                    || '_To_'
                    || ld_to_date
                    || '.txt';
            ELSE
                lv_outbound_file   :=
                       'Journal_Extract_From_'
                    || ld_from_date
                    || '_To_'
                    || ld_to_date
                    || '.txt';
            END IF;

            BEGIN
                lv_output_file   :=
                    UTL_FILE.fopen (pv_directory_name, lv_outbound_file, 'W' --opening the file in write mode
                                                                            );

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR xxd_data_primary_rec IN xxd_data_primary_cur
                    LOOP
                        lv_line   := xxd_data_primary_rec.data_record;
                        UTL_FILE.PUT (lv_output_file, CHR (15711167)); --Creating file in UTF8
                        UTL_FILE.put_line (lv_output_file, lv_line);
                        ln_cnt    := ln_cnt + 1;
                        fnd_file.put_line (fnd_file.output,
                                           xxd_data_primary_rec.data_record);
                    END LOOP;
                ELSE
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in Opening the GL_DATA_Primary file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    pn_retcode   := gn_error;
                    RETURN;
                END IF;

                UTL_FILE.fclose (lv_output_file);
            EXCEPTION
                WHEN UTL_FILE.invalid_path
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_PATH: File location or filename was invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    lv_status   := 'E';
                    raise_application_error (-20001, lv_err_msg);
                WHEN UTL_FILE.invalid_mode
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    lv_status   := 'E';
                    raise_application_error (-20002, lv_err_msg);
                WHEN UTL_FILE.invalid_filehandle
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_FILEHANDLE: The file handle was invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    lv_status   := 'E';
                    raise_application_error (-20003, lv_err_msg);
                WHEN UTL_FILE.invalid_operation
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_OPERATION: The file could not be opened or operated on as requested.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    lv_status   := 'E';
                    raise_application_error (-20004, lv_err_msg);
                WHEN UTL_FILE.read_error
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'READ_ERROR: An operating system error occurred during the read operation.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    lv_status   := 'E';
                    raise_application_error (-20005, lv_err_msg);
                WHEN UTL_FILE.write_error
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'WRITE_ERROR: An operating system error occurred during the write operation.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    lv_status   := 'E';
                    raise_application_error (-20006, lv_err_msg);
                WHEN UTL_FILE.internal_error
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INTERNAL_ERROR: An unspecified error in PL/SQL.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    lv_status   := 'E';
                    raise_application_error (-20007, lv_err_msg);
                WHEN UTL_FILE.invalid_filename
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_FILENAME: The filename parameter is invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    lv_status   := 'E';
                    raise_application_error (-20008, lv_err_msg);
                WHEN OTHERS
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'Error while creating or writing the data into the file.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    lv_status   := 'E';
                    raise_application_error (-20009, lv_err_msg);
            END;
        ELSE
            FOR xxd_data_primary_rec IN xxd_data_primary_cur
            LOOP
                fnd_file.put_line (fnd_file.output,
                                   xxd_data_primary_rec.data_record);
            END LOOP;
        END IF;

        BEGIN
            IF lv_status = 'E' OR pn_retcode = gn_error
            THEN
                UPDATE xxd_ap_ch_tax_int_stg
                   SET request_end_date = SYSDATE, status = 'E', last_updated_date = SYSDATE
                 WHERE request_id = gn_request_id;

                COMMIT;
            ELSE
                UPDATE xxd_ap_ch_tax_int_stg
                   SET request_end_date = SYSDATE, status = 'S', last_updated_date = SYSDATE
                 WHERE request_id = gn_request_id;

                COMMIT;
            END IF;
        END;
    END main_proc;
END xxd_ap_ch_tax_int;
/
