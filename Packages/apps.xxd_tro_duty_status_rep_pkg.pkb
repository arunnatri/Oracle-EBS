--
-- XXD_TRO_DUTY_STATUS_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_TRO_DUTY_STATUS_REP_PKG"
AS
    /***********************************************************************************
    *$header :                                                                        *
    *                                                                                 *
    * AUTHORS : ANM                                                                   *
    *                                                                                 *
    * PURPOSE : Used for Duty Platform Status Report                                  *
    *                                                                                 *
    * PARAMETERS :                                                                    *
    *                                                                                 *
    * DATE : 01-Jan-2022                                                              *
    *                                                                                 *
    * Assumptions:                                                                    *
    *                                                                                 *
    *                                                                                 *
    * History                                                                         *
    * Vsn   Change Date Changed By           Change Description                       *
    * ----- ----------- -------------------  -------------------------------------    *
    * 1.0   01-Jan-2022   ANM    Initial Creation                                     *
    **********************************************************************************/
    PROCEDURE write_log_prc (pv_msg IN VARCHAR2)
    IS
        /****************************************************
        -- PROCEDURE write_log_prc
        -- PURPOSE: This Procedure write the log messages
        *****************************************************/
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in write_log_prc Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in write_log_prc Procedure -' || SQLERRM);
    END write_log_prc;

    /****************************************************
    -- PROCEDURE print_output
    -- PURPOSE: This Procedure write the messages in output
    *****************************************************/

    PROCEDURE print_output (pv_msgtxt_in IN VARCHAR2)
    IS
    -- PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        -- IF pv_debug = 'Y'
        -- THEN
        IF fnd_global.conc_login_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msgtxt_in);
        -- fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
        ELSE
            fnd_file.put_line (fnd_file.OUTPUT, pv_msgtxt_in);
        END IF;
    -- END IF;
    END print_output;

    /***************************************************************************
    -- PROCEDURE create_final_zip_prc
    -- PURPOSE: This Procedure Converts the file to zip file
    ***************************************************************************/

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

        t_fh   := UTL_FILE.fopen (pv_dir, pv_zip_file_name, 'wb');

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

        fnd_file.put_line (fnd_file.LOG, pv_directory_name || pv_file_name);

        fnd_file.put_line (fnd_file.LOG, ' Start of add_file PROC ');

        APEX_200200.WWV_FLOW_ZIP.add_file (lb_zip, pv_file_name, lb_file);

        fnd_file.put_line (fnd_file.LOG, ' Start of finish PROC ');

        APEX_200200.wwv_flow_zip.finish (lb_zip);

        fnd_file.put_line (fnd_file.LOG, ' Start of Saving ZIP File PROC ');

        save_zip_prc (lb_zip, pv_directory_name, pv_zip_file_name);
    END create_final_zip_prc;


    PROCEDURE main_detail (errbuf            OUT VARCHAR2,
                           retcode           OUT NUMBER,
                           pv_file_name   IN     VARCHAR2,
                           pv_from_date   IN     VARCHAR2,
                           pv_to_date     IN     VARCHAR2,
                           pv_coo         IN     VARCHAR2,
                           pv_COD         IN     VARCHAR2,
                           pv_status      IN     VARCHAR2,
                           pv_sku_level   IN     VARCHAR2)
    AS
        CURSOR cur_duty IS
              SELECT NVL (tab1.country_of_origin, tab1.country_of_origin) country_of_origin, NVL (tab1.destination_country, tab1.destination_country) destination_country, NULL organization_code,
                     DECODE (pv_sku_level, 'Y', tab1.style_number, tab1.style_number) style_or_sku, b.brand, b.division,
                     b.department, b.style_desc, -- b.color_code,
                                                 tab1.hts_code,
                     NVL (tab1.effective_start_date, tab1.effective_start_date) effective_start_date, NVL (tab1.effective_end_date, tab1.effective_end_date) effective_end_date, NULL primary_duty_flag,
                     DECODE (tab1.PREFERENTIAL_DUTY_FLAG, 'Y', tab1.PR_START_DATE, tab1.Effective_start_date) duty_start_date, DECODE (tab1.PREFERENTIAL_DUTY_FLAG, 'Y', tab1.PR_END_DATE, tab1.Effective_end_date) duty_end_date, NVL (tab1.coo_preference_flag, tab1.coo_preference_flag) coo_preference_flag,
                     tab1.error_msg error_msg1, NULL error_msg2, DECODE (tab1.PREFERENTIAL_DUTY_FLAG, 'Y', tab1.default_duty_rate, tab1.duty_rate) duty,
                     NULL freight, NULL freight_duty, NULL oh_duty,
                     NULL oh_nonduty, 'NA' item_status, tab1.filename
                FROM apps.xxd_common_items_v b, xxdo.xxd_cst_duty_ele_inb_stg_tr_t tab1
               WHERE     1 = 1
                     AND tab1.style_number = b.style_number(+)
                     AND b.organization_id(+) = 106
                     --AND tab1.filename = tab1.filename (+)
                     --AND tab1.style_number = tab1.style_number (+)
                     --AND tab1.country_of_origin = tab1.country_of_origin (+)
                     --AND tab1.destination_country = tab1.destination_country (+)
                     AND tab1.active_flag = 'Y'
                     AND tab1.rec_status =
                         DECODE (pv_status,
                                 'All', tab1.rec_status,
                                 'Error', 'E',
                                 'Processed', 'P')
                     AND tab1.filename = NVL (pv_file_name, tab1.filename)
                     AND tab1.country_of_origin =
                         NVL (pv_coo, tab1.country_of_origin)
                     AND tab1.destination_country =
                         NVL (pv_COD, tab1.destination_country)
                     AND tab1.creation_date BETWEEN NVL (
                                                        fnd_date.canonical_to_date (
                                                            pv_from_date),
                                                        tab1.creation_date)
                                                AND NVL (
                                                        fnd_date.canonical_to_date (
                                                            pv_to_date),
                                                        SYSDATE + 1)
                     AND UPPER (b.inventory_item_status_code(+)) <> 'INACTIVE'
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxd_cst_duty_ele_upld_stg_t tab2
                               WHERE     1 = 1
                                     AND tab1.country_of_origin =
                                         tab2.country_of_origin
                                     AND tab1.destination_country =
                                         tab2.destination_country
                                     AND tab1.style_number = tab2.style_number)
            GROUP BY NVL (tab1.country_of_origin, tab1.country_of_origin), NVL (tab1.destination_country, tab1.destination_country), DECODE (pv_sku_level, 'Y', tab1.style_number, tab1.style_number),
                     b.brand, b.division, b.department,
                     b.style_desc, -- b.color_code,
                                   tab1.hts_code, NVL (tab1.effective_start_date, tab1.effective_start_date),
                     NVL (tab1.effective_end_date, tab1.effective_end_date), DECODE (tab1.PREFERENTIAL_DUTY_FLAG, 'Y', tab1.PR_START_DATE, tab1.Effective_start_date), DECODE (tab1.PREFERENTIAL_DUTY_FLAG, 'Y', tab1.PR_END_DATE, tab1.Effective_end_date),
                     NVL (tab1.coo_preference_flag, tab1.coo_preference_flag), tab1.error_msg, DECODE (tab1.PREFERENTIAL_DUTY_FLAG, 'Y', tab1.default_duty_rate, tab1.duty_rate),
                     tab1.filename
            UNION ALL
              SELECT NVL (tab2.country_of_origin, tab1.country_of_origin) country_of_origin, NVL (tab2.destination_country, tab1.destination_country) destination_country, tab2.organization_code,
                     DECODE (pv_sku_level, 'Y', tab2.item_number, tab2.style_number) style_or_sku, b.brand, b.division,
                     b.department, b.style_desc, -- b.color_code,
                                                 tab1.hts_code,
                     NVL (tab2.effective_start_date, tab1.effective_start_date) effective_start_date, NVL (tab2.effective_end_date, tab1.effective_end_date) effective_end_date, tab2.primary_duty_flag,
                     tab2.duty_start_date, tab2.duty_end_date, NVL (tab2.coo_preference_flag, tab1.coo_preference_flag) coo_preference_flag,
                     tab1.error_msg error_msg1, tab2.error_msg error_msg2, MAX (duty) duty,
                     MAX (freight) freight, MAX (freight_duty) freight_duty, MAX (oh_duty) oh_duty,
                     MAX (oh_nonduty) oh_nonduty, b.inventory_item_status_code item_status, tab1.filename
                FROM xxdo.xxd_cst_duty_ele_upld_stg_t tab2, apps.xxd_common_items_v b, xxdo.xxd_cst_duty_ele_inb_stg_tr_t tab1
               WHERE     1 = 1
                     AND tab2.inventory_item_id = b.inventory_item_id(+)
                     AND tab2.inventory_org_id = b.organization_id(+)
                     AND tab1.filename = tab2.filename
                     AND tab1.style_number = tab2.style_number
                     AND tab1.country_of_origin = tab2.country_of_origin
                     AND tab1.destination_country = tab2.destination_country
                     AND tab1.country_of_origin =
                         NVL (pv_coo, tab1.country_of_origin)
                     AND tab1.destination_country =
                         NVL (pv_COD, tab1.destination_country)
                     AND tab2.active_flag = 'Y'
                     AND tab1.rec_status =
                         DECODE (pv_status,
                                 'All', tab1.rec_status,
                                 'Error', 'E',
                                 'Processed', 'P')
                     AND tab2.filename = NVL (pv_file_name, tab2.filename)
                     AND tab2.creation_date BETWEEN NVL (
                                                        fnd_date.canonical_to_date (
                                                            pv_from_date),
                                                        tab2.creation_date)
                                                AND NVL (
                                                        fnd_date.canonical_to_date (
                                                            pv_to_date),
                                                        SYSDATE + 1)
                     AND UPPER (b.inventory_item_status_code(+)) <> 'INACTIVE'
            GROUP BY NVL (tab2.country_of_origin, tab1.country_of_origin), NVL (tab2.destination_country, tab1.destination_country), tab2.organization_code,
                     DECODE (pv_sku_level, 'Y', tab2.item_number, tab2.style_number), b.brand, b.division,
                     b.department, b.style_desc, -- b.color_code,
                                                 tab1.hts_code,
                     NVL (tab2.effective_start_date, tab1.effective_start_date), NVL (tab2.effective_end_date, tab1.effective_end_date), tab2.primary_duty_flag,
                     tab2.duty_start_date, tab2.duty_end_date, NVL (tab2.coo_preference_flag, tab1.coo_preference_flag),
                     tab1.error_msg, tab2.error_msg, b.inventory_item_status_code,
                     tab1.filename
            ORDER BY 4, 3, 2;

        --     SELECT NVL (tab2.country_of_origin, tab1.country_of_origin) country_of_origin,
        --            NVL (tab2.destination_country, tab1.destination_country) destination_country,
        --            tab2.organization_code,
        --            DECODE (pv_sku_level, 'Y', tab2.item_number, tab2.style_number) style_or_sku,
        --            b.brand,
        --            b.division,
        --            b.department,
        --            b.style_desc,
        --           -- b.color_code,
        --            tab1.hts_code,
        --            NVL (tab2.effective_start_date, tab1.effective_start_date) effective_start_date,
        --            NVL (tab2.effective_end_date, tab1.effective_end_date) effective_end_date,
        --            tab2.primary_duty_flag,
        --            tab2.duty_start_date,
        --            tab2.duty_end_date,
        --            NVL (tab2.coo_preference_flag, tab1.coo_preference_flag) coo_preference_flag,
        --            tab1.error_msg error_msg1,
        --            tab2.error_msg error_msg2,
        --            MAX (duty) duty,
        --            MAX (freight) freight,
        --            MAX (freight_duty) freight_duty,
        --            MAX (oh_duty) oh_duty,
        --            MAX (oh_nonduty) oh_nonduty,
        --            b.inventory_item_status_code item_status
        --       FROM xxdo.xxd_cst_duty_ele_upld_stg_t    tab2,
        --            apps.xxd_common_items_v             b,
        --            xxdo.xxd_cst_duty_ele_inb_stg_tr_t  tab1
        --      WHERE 1 = 1
        --        AND tab2.inventory_item_id (+) = b.inventory_item_id
        --        AND tab2.inventory_org_id (+) = b.organization_id
        --        AND tab1.filename = tab2.filename (+)
        --        AND tab1.style_number = tab2.style_number (+)
        --        AND tab1.country_of_origin = tab2.country_of_origin (+)
        --        AND tab1.destination_country = tab2.destination_country (+)
        --        AND tab2.active_flag = 'Y'
        --        AND tab1.rec_status = DECODE (pv_status, 'All', tab1.rec_status, 'Error', 'E', 'Processed', 'P')
        --        AND tab2.filename = NVL (pv_file_name, tab2.filename)
        --        AND tab2.creation_date BETWEEN NVL (fnd_date.canonical_to_date(pv_from_date),tab2.creation_date) AND NVL(fnd_date.canonical_to_date(pv_to_date), SYSDATE + 1)
        --        AND UPPER (b.inventory_item_status_code) <> 'INACTIVE'
        --   GROUP BY NVL (tab2.country_of_origin, tab1.country_of_origin),
        --            NVL (tab2.destination_country, tab1.destination_country),
        --            tab2.organization_code,
        --            DECODE (pv_sku_level, 'Y', tab2.item_number, tab2.style_number),
        --            b.brand,
        --            b.division,
        --            b.department,
        --            b.style_desc,
        --           -- b.color_code,
        --            tab1.hts_code,
        --            NVL (tab2.effective_start_date, tab1.effective_start_date),
        --            NVL (tab2.effective_end_date, tab1.effective_end_date),
        --            tab2.primary_duty_flag,
        --            tab2.duty_start_date,
        --            tab2.duty_end_date,
        --            NVL (tab2.coo_preference_flag, tab1.coo_preference_flag),
        --            tab1.error_msg,
        --            tab2.error_msg,
        --            b.inventory_item_status_code
        --   ORDER BY 4,3,2;

        x_ret_code             VARCHAR2 (100);
        x_ret_message          VARCHAR2 (100);
        lv_rep_file            VARCHAR2 (1000);
        lv_rep_file_zip        VARCHAR2 (1000);
        lv_file_path           VARCHAR2 (100);
        lv_hdr_line            VARCHAR2 (1000);
        lv_err_msg             VARCHAR2 (100);
        lv_output_file         UTL_FILE.file_type;
        buffer_size   CONSTANT INTEGER := 32767;
        lv_outbound_file       VARCHAR2 (1000);
        lv_line                VARCHAR2 (32000);
        lv_mail_delimiter      VARCHAR2 (1) := '/';
        lv_recipients          VARCHAR2 (1000);
        lv_ccrecipients        VARCHAR2 (1000);
        lv_result              VARCHAR2 (4000);
        lv_result_msg          VARCHAR2 (4000);
        lv_message1            VARCHAR2 (32000);
        lv_style_or_sku        VARCHAR2 (1000);
    BEGIN
        write_log_prc (
               'Procedure main_detail Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        lv_rep_file       :=
            gn_request_id || '_Deckers TRO Duty Status Report.csv';

        write_log_prc (
               CHR (10)
            || '**************Parameters*************'
            || CHR (10)
            || 'pv_file_name - '
            || pv_file_name
            || CHR (9)
            || pv_from_date
            || CHR (9)
            || 'pv_to_date - '
            || pv_to_date
            || CHR (9)
            || 'pv_coo - '
            || pv_coo
            || CHR (9)
            || 'pv_COD - '
            || pv_COD
            || CHR (9)
            || 'pv_status - '
            || pv_status
            || CHR (9)
            || 'pv_sku_level - '
            || pv_sku_level);

        -- Derive the directory Path

        BEGIN
            SELECT directory_path
              INTO lv_file_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_CST_DUTY_ELE_REP_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_file_path   := NULL;
        END;

        write_log_prc (
            'TRO Duty Status Report File Name is - ' || lv_rep_file);

        lv_style_or_sku   := NULL;

        IF NVL (pv_sku_level, 'N') = 'Y'
        THEN
            lv_style_or_sku   := 'Item Number';
        ELSE
            lv_style_or_sku   := 'Style Number';
        END IF;

        lv_hdr_line       :=
               'Country Of Origin'
            || gv_delim_pipe
            || 'Destination Country'
            || gv_delim_pipe
            || 'Organization Code'
            || gv_delim_pipe
            || lv_style_or_sku
            || gv_delim_pipe
            || 'Brand'
            || gv_delim_pipe
            || 'Division'
            || gv_delim_pipe
            || 'Department'
            || gv_delim_pipe
            || 'Style Desc'
            || gv_delim_pipe
            || 'Hts Code'
            || gv_delim_pipe
            || 'Effective Start Date'
            || gv_delim_pipe
            || 'Effective EndDate'
            || gv_delim_pipe
            || 'Primary Duty Flag'
            || gv_delim_pipe
            || 'Duty Start Date'
            || gv_delim_pipe
            || 'Duty End Date'
            || gv_delim_pipe
            || 'Coo Preference Flag'
            || gv_delim_pipe
            || 'Error Msg1'
            || gv_delim_pipe
            || 'Error Msg2'
            || gv_delim_pipe
            || 'Duty'
            || gv_delim_pipe
            || 'Freight'
            || gv_delim_pipe
            || 'Freight Duty'
            || gv_delim_pipe
            || 'OH Duty'
            || gv_delim_pipe
            || 'OH Nonduty'
            || gv_delim_pipe
            || 'Item Status'
            || gv_delim_pipe
            || 'File Name';

        lv_line           := lv_hdr_line;
        apps.fnd_file.put_line (apps.fnd_file.OUTPUT, lv_line);
        lv_output_file    :=
            UTL_FILE.fopen (lv_file_path, lv_rep_file, 'W' --opening the file in write mode
                                                          ,
                            buffer_size);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            UTL_FILE.put_line (lv_output_file, lv_line);

            FOR i IN cur_duty
            LOOP
                lv_line   :=
                       i.country_of_origin
                    || gv_delim_pipe
                    || i.destination_country
                    || gv_delim_pipe
                    || i.organization_code
                    || gv_delim_pipe
                    || i.style_or_sku
                    || gv_delim_pipe
                    || i.brand
                    || gv_delim_pipe
                    || i.division
                    || gv_delim_pipe
                    || i.department
                    || gv_delim_pipe
                    || i.style_desc
                    || gv_delim_pipe
                    || i.hts_code
                    || gv_delim_pipe
                    || i.effective_start_date
                    || gv_delim_pipe
                    || i.effective_end_date
                    || gv_delim_pipe
                    || i.primary_duty_flag
                    || gv_delim_pipe
                    || i.duty_start_date
                    || gv_delim_pipe
                    || i.duty_end_date
                    || gv_delim_pipe
                    || i.coo_preference_flag
                    || gv_delim_pipe
                    || i.error_msg1
                    || gv_delim_pipe
                    || i.error_msg2
                    || gv_delim_pipe
                    || i.duty
                    || gv_delim_pipe
                    || i.freight
                    || gv_delim_pipe
                    || i.freight_duty
                    || gv_delim_pipe
                    || i.oh_duty
                    || gv_delim_pipe
                    || i.oh_nonduty
                    || gv_delim_pipe
                    || i.item_status
                    || gv_delim_pipe
                    || i.filename;

                UTL_FILE.put_line (lv_output_file, lv_line);
                apps.fnd_file.put_line (apps.fnd_file.OUTPUT, lv_line);
            END LOOP;
        ELSE
            lv_err_msg      :=
                SUBSTR (
                       'Error in Opening the Duty Elements data file for writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;

            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file);

        lv_rep_file_zip   :=
               SUBSTR (lv_rep_file, 1, (INSTR (lv_rep_file, '.', -1) - 1))
            || '.zip';
        write_log_prc (
            'Deckers TRO Duty Status Report File Name is - ' || lv_rep_file);
        write_log_prc (
               'Deckers TRO Duty Status Report ZIP File Name is - '
            || lv_rep_file_zip);

        create_final_zip_prc (
            pv_directory_name   => 'XXD_CST_DUTY_ELE_REP_DIR',
            pv_file_name        => lv_rep_file,
            pv_zip_file_name    => lv_rep_file_zip);

        lv_rep_file_zip   :=
            lv_file_path || lv_mail_delimiter || lv_rep_file_zip;
        write_log_prc (
               'Deckers TRO Duty Status Report File Name is - '
            || lv_rep_file_zip);

        lv_message1       :=
               'Hello Team,'
            || CHR (10)
            || CHR (10)
            || 'Please Find the Attached Deckers TRO Duty Status Report. '
            || CHR (10)
            || CHR (10)
            || 'Regards,'
            || CHR (10)
            || 'SYSADMIN.'
            || CHR (10)
            || CHR (10)
            || 'Note: This is auto generated mail, please donot reply.';

        SELECT LISTAGG (ffvl.description, ';') WITHIN GROUP (ORDER BY ffvl.description)
          INTO lv_recipients
          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND fvs.flex_value_set_id = ffvl.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXD_TRO_DUTY_STATUS_EMAIL_VS'
               AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                   TRUNC (SYSDATE)
               AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE)
               AND ffvl.enabled_flag = 'Y';

        xxdo_mail_pkg.send_mail (
            pv_sender         => 'erp@deckers.com',
            pv_recipients     => lv_recipients,
            pv_ccrecipients   => lv_ccrecipients,
            pv_subject        => 'Deckers TRO Duty Status Report',
            pv_message        => lv_message1,
            pv_attachments    => lv_rep_file_zip,
            xv_result         => lv_result,
            xv_result_msg     => lv_result_msg);

        write_log_prc (lv_result);
        write_log_prc (lv_result_msg);

        write_log_prc (
               'Procedure main_detail Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log_prc (lv_err_msg);
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
            write_log_prc (lv_err_msg);
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
            write_log_prc (lv_err_msg);
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
            write_log_prc (lv_err_msg);
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
            write_log_prc (lv_err_msg);
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
            write_log_prc (lv_err_msg);
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
            write_log_prc (lv_err_msg);
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
            write_log_prc (lv_err_msg);
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
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END main_detail;
END xxd_tro_duty_status_rep_pkg;
/
