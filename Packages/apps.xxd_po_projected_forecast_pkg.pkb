--
-- XXD_PO_PROJECTED_FORECAST_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_PROJECTED_FORECAST_PKG"
IS
      /****************************************************************************************************************
 NAME           : XXD_PO_SUPPLY_FORECAST_PKG
 REPORT NAME    : Deckers PO Supply Forecast Report

 REVISIONS:
 Date           Author             Version  Description
 ----------     ----------         -------  -------------------------------------------------------------------------
 30-NOV-2021    Damodara Gupta     1.0      This is the PO Supply Forecast Report. Report should fetch all Direct,
                                            Intercompany, JP TQ Open PO's and Open ASN's for given date/period range
 06-MAY-2022    Srinath Siricilla  2.0      CCR0009989
******************************************************************************************************************/
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
-- PROCEDURE expected_receipt_dt_fnc
-- PURPOSE: This Procedure write the log messages
*****************************************************/
    FUNCTION expected_receipt_dt_fnc (acd IN DATE, pd IN DATE, cxf IN DATE)
        RETURN DATE
    IS
        erd   DATE;
    BEGIN
        erd   := ((acd + (pd - cxf)) + (gn_delay_delivery_days));
        RETURN erd;
    END expected_receipt_dt_fnc;

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

      /***************************************************************************
-- PROCEDURE pfr_rep_send_mail_prc
-- PURPOSE: This Procedure sends PO Forecast report to the Team
***************************************************************************/
    PROCEDURE pfr_rep_send_mail_prc (pv_rep_file_name IN VARCHAR2)
    IS
        lv_rep_file_name    VARCHAR2 (4000);
        lv_message          VARCHAR2 (4000);
        lv_directory_path   VARCHAR2 (100);
        lv_mail_delimiter   VARCHAR2 (1) := '/';
        lv_recipients       VARCHAR2 (1000);
        lv_ccrecipients     VARCHAR2 (1000);
        lv_result           VARCHAR2 (4000);
        lv_result_msg       VARCHAR2 (4000);
        lv_message1         VARCHAR2 (4000);
    BEGIN
        write_log_prc (
               'Procedure pfr_rep_send_mail_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

        -- Derive the directory Path

        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_PO_FORECAST_REP_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        lv_rep_file_name   :=
            lv_directory_path || lv_mail_delimiter || pv_rep_file_name;
        write_log_prc (
            'PO Forecast Report File Name is - ' || lv_rep_file_name);

        lv_message1   :=
               'Hello Team,'
            || CHR (10)
            || CHR (10)
            || 'Please Find the Attached Deckers PO Projected Supply Forecast Report. '
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
               AND fvs.flex_value_set_name = 'XXD_PO_FORECAST_EMAIL_VS'
               AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                   TRUNC (SYSDATE)
               AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE)
               AND ffvl.enabled_flag = 'Y';

        xxdo_mail_pkg.send_mail (
            pv_sender         => 'erp@deckers.com',
            pv_recipients     => lv_recipients,
            pv_ccrecipients   => lv_ccrecipients,
            pv_subject        => 'Deckers PO Projected Supply Forecast Report',
            pv_message        => lv_message1,
            pv_attachments    => lv_rep_file_name,
            xv_result         => lv_result,
            xv_result_msg     => lv_result_msg);

        write_log_prc (lv_result);
        write_log_prc (lv_result_msg);
        write_log_prc (
               'Procedure pfr_rep_send_mail_prc Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Error in Procedure pfr_rep_send_mail_prc:' || SQLERRM);
    END pfr_rep_send_mail_prc;

      /***************************************************************************
-- PROCEDURE write_rev_ins_output_prc
-- PURPOSE: This Procedure generates the output in CSV format
***************************************************************************/
    PROCEDURE write_rev_ins_output_prc (
        v_report_date             IN VARCHAR2,
        pv_run_mode               IN VARCHAR2,
        pv_po_model               IN VARCHAR2                         -- Added
                                             ,
        pv_override               IN VARCHAR2,
        pv_from_period            IN VARCHAR2,
        pv_to_period              IN VARCHAR2,
        pn_incld_past_due_days    IN NUMBER,
        pn_delay_delivery_days    IN NUMBER,                          -- Added
        pn_delay_Intransit_days   IN NUMBER,        -- Added as per CCR0009989
        pv_from_promised_date     IN DATE,
        pv_to_promised_date       IN DATE,
        pv_from_xf_date           IN DATE,
        pv_to_xf_date             IN DATE,
        pv_source_org             IN VARCHAR2,
        pv_destination_org        IN VARCHAR2,
        pv_rate_date              IN VARCHAR2,
        pv_rate_type              IN VARCHAR2)
    IS
        CURSOR rev_ins_data_cur IS
              SELECT brand, department, item_category,
                     item_sku, from_period_identifier, to_period_identifier,
                     source_org, requested_xf_date, orig_confirmed_xf_date,
                     confirmed_xf_date, asn_creation_date, xf_shipment_date -- Added
                                                                           ,
                     promised_date, expected_receipt_date, original_promise_date,
                     intransit_receipt_date, orig_intransit_receipt_date -- Added
                                                                        , destination_org,
                     promise_expected_receipt_date   -- ,original_promise_date
                                                  -- ,intransit_receipt_date
                                                  -- ,orig_intransit_receipt_date
                                                  , SUM (fob_value) fob_value, SUM (quantity) quantity,
                     ship_method, po_currency, SUM (fob_value_in_usd) fob_value_in_usd,
                     DECODE (pv_run_mode, 'Review', NULL, calculated_flag) calculated_flag, DECODE (pv_run_mode, 'Review', NULL, override_status) override_status, source
                FROM xxdo.xxd_po_proj_fc_rev_stg_t
               WHERE 1 = 1 AND request_id = gn_request_id
            GROUP BY brand, department, item_category,
                     item_sku, from_period_identifier, to_period_identifier,
                     source_org, requested_xf_date, orig_confirmed_xf_date,
                     confirmed_xf_date, asn_creation_date, xf_shipment_date -- Added
                                                                           ,
                     promised_date, expected_receipt_date, original_promise_date,
                     intransit_receipt_date, orig_intransit_receipt_date -- Added
                                                                        , destination_org,
                     promise_expected_receipt_date   -- ,original_promise_date
                                                  -- ,intransit_receipt_date
                                                  -- ,orig_intransit_receipt_date
                                                                  --,fob_value
                     , ship_method, po_currency            --,fob_value_in_usd
                                               ,
                     calculated_flag, override_status, source
            ORDER BY promise_expected_receipt_date;

        lv_rev_ins_pfr_file       VARCHAR2 (1000);
        lv_rev_ins_pfr_file_zip   VARCHAR2 (1000);
        lv_file_path              VARCHAR2 (1000);
        lv_hdr_line               VARCHAR2 (1000);
        buffer_size      CONSTANT INTEGER := 32767;
        lv_line                   VARCHAR2 (32000);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (1000);
        x_ret_code                VARCHAR2 (100);
        lv_err_msg                VARCHAR2 (1000);
        x_ret_message             VARCHAR2 (1000);
    BEGIN
        write_log_prc (
               'Procedure write_rev_ins_output_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        lv_rev_ins_pfr_file   :=
            gn_request_id || '_DeckersPOSupplyForecast.csv';

        -- Derive the directory Path

        BEGIN
            SELECT directory_path
              INTO lv_file_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_PO_FORECAST_REP_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_file_path   := NULL;
        END;

        lv_hdr_line   :=
               'Brand'
            || gv_delim_comma
            || 'Department'
            || gv_delim_comma
            || 'Item Category'
            || gv_delim_comma
            || 'Item Number'
            || gv_delim_comma
            || 'From Period Identifier'
            || gv_delim_comma
            || 'To Period Identifier'
            || gv_delim_comma
            || 'Source Org'
            || gv_delim_comma
            || 'Requested XF Date'
            || gv_delim_comma
            || 'Original Confirmed XF Date'
            || gv_delim_comma
            || 'Confirmed XF Date'
            || gv_delim_comma
            || 'ASN Creation Date'
            || gv_delim_comma
            || 'XF Shipment Date'
            || gv_delim_comma
            -- Added
            || 'Promised Date'
            || gv_delim_comma
            || 'Expected Receipt Date'
            || gv_delim_comma
            || 'Original Promise Date'
            || gv_delim_comma
            || 'Intransit Receipt Date'
            || gv_delim_comma
            || 'Orig Intransit Receipt Date'
            || gv_delim_comma
            -- Added
            || 'Destination Org'
            || gv_delim_comma
            || 'Promise/Expected Receipt Date'
            || gv_delim_comma
            || 'FOB Value'
            || gv_delim_comma
            || 'Open Quantity'
            || gv_delim_comma
            || 'Ship Method'
            || gv_delim_comma
            || 'PO Currency'
            || gv_delim_comma
            || 'FOB Value in USD'
            || gv_delim_comma
            || 'Calculated Flag'
            || gv_delim_comma
            || 'OVERRIDE Status'
            || gv_delim_comma
            || 'Source';

        -- WRITE INTO FOLDER
        write_log_prc (
            'DeckersPOSupplyForecast File Name is - ' || lv_rev_ins_pfr_file);

        lv_output_file   :=
            UTL_FILE.fopen (lv_file_path, lv_rev_ins_pfr_file, 'W' --opening the file in write mode
                                                                  ,
                            buffer_size);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            lv_line   :=
                   'DECKERS CORPORATION'
                || CHR (10)
                || 'Report Name :Deckers PO Projected Supply Forecast Report'
                || CHR (10)
                || 'Report Date - :'
                || v_report_date
                || CHR (10)
                || 'Run Mode is :'
                || pv_run_mode
                || CHR (10)
                -- Added
                || 'PO Model is :'
                || pv_po_model
                || CHR (10)
                -- Added
                || 'OVERRIDE is :'
                || pv_override
                || CHR (10)
                || 'Starting Period is :'
                || pv_from_period
                || CHR (10)
                || 'Ending Period is :'
                || pv_to_period
                || CHR (10)
                || 'Include Past Due Days is :'
                || pn_incld_past_due_days
                || CHR (10)
                -- Added
                || 'Delay Delivery Days and Intransit Days are : '
                || pn_delay_delivery_days
                || ' and '
                || pn_delay_intransit_days
                || CHR (10)
                -- Added
                || 'Starting Promised Date is :'
                || pv_from_promised_date
                || CHR (10)
                || 'Ending Promised Date is :'
                || pv_to_promised_date
                || CHR (10)
                || 'Starting XF Date is :'
                || pv_from_xf_date
                || CHR (10)
                || 'Ending XF Date is :'
                || pv_to_xf_date
                || CHR (10)
                || 'Source Organization is :'
                || pv_source_org
                || CHR (10)
                || 'Destination Organization is :'
                || pv_destination_org
                || CHR (10)
                || 'Rate Date is :'
                || TO_DATE (pv_rate_date, 'RRRR/MM/DD HH24:MI:SS')
                || CHR (10)
                || 'Rate Type is :'
                || pv_rate_type
                || CHR (10);

            -- write_log_prc  ('Parameters:'||lv_line);

            UTL_FILE.put_line (lv_output_file, lv_line);

            lv_line   := lv_hdr_line;

            -- write_log_prc  ('Header:'||lv_line);

            UTL_FILE.put_line (lv_output_file, lv_line);

            FOR i IN rev_ins_data_cur
            LOOP
                lv_line   :=
                       i.brand
                    || gv_delim_comma
                    || i.department
                    || gv_delim_comma
                    || i.item_category
                    || gv_delim_comma
                    || i.item_sku
                    || gv_delim_comma
                    || ' '
                    || i.from_period_identifier
                    || gv_delim_comma
                    || ' '
                    || i.to_period_identifier
                    || gv_delim_comma
                    || i.source_org
                    || gv_delim_comma
                    || i.requested_xf_date
                    || gv_delim_comma
                    || i.orig_confirmed_xf_date
                    || gv_delim_comma
                    || i.confirmed_xf_date
                    || gv_delim_comma
                    || i.asn_creation_date
                    || gv_delim_comma
                    || i.xf_shipment_date
                    || gv_delim_comma
                    -- Added
                    || i.promised_date
                    || gv_delim_comma
                    || i.expected_receipt_date
                    || gv_delim_comma
                    || i.original_promise_date
                    || gv_delim_comma
                    || i.intransit_receipt_date
                    || gv_delim_comma
                    || i.orig_intransit_receipt_date
                    || gv_delim_comma
                    -- Added
                    || i.destination_org
                    || gv_delim_comma
                    || i.promise_expected_receipt_date
                    || gv_delim_comma
                    -- ||i.original_promise_date
                    -- ||gv_delim_comma
                    -- ||i.intransit_receipt_date
                    -- ||gv_delim_comma
                    -- ||i.orig_intransit_receipt_date
                    -- ||gv_delim_comma
                    || i.fob_value
                    || gv_delim_comma
                    || i.quantity
                    || gv_delim_comma
                    || i.ship_method
                    || gv_delim_comma
                    || i.po_currency
                    || gv_delim_comma
                    || i.fob_value_in_usd
                    || gv_delim_comma
                    || i.calculated_flag
                    || gv_delim_comma
                    || i.override_status
                    || gv_delim_comma
                    || i.source;

                -- write_log_prc  ('Data:'||lv_line);

                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
        ELSE
            lv_err_msg      :=
                SUBSTR (
                       'Error in Opening the Forecast data file for writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file);

        lv_rev_ins_pfr_file_zip   :=
               SUBSTR (lv_rev_ins_pfr_file,
                       1,
                       (INSTR (lv_rev_ins_pfr_file, '.', -1) - 1))
            || '.zip';
        write_log_prc (
            'PO Forecast Report File Name is - ' || lv_rev_ins_pfr_file);
        write_log_prc (
               'PO Forecast Report ZIP File Name is - '
            || lv_rev_ins_pfr_file_zip);

        create_final_zip_prc (
            pv_directory_name   => 'XXD_PO_FORECAST_REP_DIR',
            pv_file_name        => lv_rev_ins_pfr_file,
            pv_zip_file_name    => lv_rev_ins_pfr_file_zip);

        pfr_rep_send_mail_prc (lv_rev_ins_pfr_file_zip);

        write_log_prc (
               'Procedure write_rev_ins_output_prc Ends...'
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
    END write_rev_ins_output_prc;

      /***************************************************************************
-- PROCEDURE write_rep_output_prc
-- PURPOSE: This Procedure generates the output in CSV format for Report Mode
***************************************************************************/
    PROCEDURE write_rep_output_prc (v_report_date IN VARCHAR2, pv_run_mode IN VARCHAR2, pv_po_model IN VARCHAR2 -- Added
                                                                                                               , pv_override IN VARCHAR2, pv_from_period IN VARCHAR2, pv_to_period IN VARCHAR2, pn_incld_past_due_days IN NUMBER, pn_delay_delivery_days IN NUMBER, -- Added
                                                                                                                                                                                                                                                                    pn_delay_intransit_days IN NUMBER, -- Added as per CCR0009989                                  ,
                                                                                                                                                                                                                                                                                                       pv_from_promised_date IN DATE, pv_to_promised_date IN DATE, pv_from_xf_date IN DATE, pv_to_xf_date IN DATE, pv_source_org IN VARCHAR2, pv_destination_org IN VARCHAR2, pv_rate_date IN VARCHAR2, pv_rate_type IN VARCHAR2, pv_from_period_date IN DATE
                                    , pv_to_period_date IN DATE, pv_src_org IN VARCHAR2, pv_dest_org IN VARCHAR2)
    IS
        CURSOR rep_data_cur /*(pv_from_promised_date     DATE
                            ,pv_to_promised_date       DATE
                            ,pv_source_org             VARCHAR2
                            ,pv_destination_org        VARCHAR2)*/
                            IS
              SELECT brand, department, item_category,
                     item_sku, from_period_identifier, to_period_identifier,
                     source_org, requested_xf_date, orig_confirmed_xf_date,
                     confirmed_xf_date, asn_creation_date, xf_shipment_date -- Added
                                                                           ,
                     promised_date, expected_receipt_date, original_promise_date,
                     intransit_receipt_date, orig_intransit_receipt_date -- Added
                                                                        , destination_org,
                     promise_expected_receipt_date, SUM (fob_value) fob_value, SUM (quantity) quantity,
                     ship_method, po_currency, SUM (fob_value_in_usd) fob_value_in_usd,
                     calculated_flag, override_status, source
                FROM xxdo.xxd_po_proj_forecast_stg_t
                   /*WHERE (promise_expected_receipt_date BETWEEN pv_from_promised_date AND pv_to_promised_date
     OR original_promise_date BETWEEN pv_from_promised_date AND pv_to_promised_date)
AND source_org = NVL (pv_source_org, source_org)
AND destination_org = NVL (pv_destination_org, destination_org)*/
               WHERE     (promise_expected_receipt_date BETWEEN pv_from_period_date AND pv_to_period_date OR original_promise_date BETWEEN pv_from_period_date AND pv_to_period_date)
                     AND source_org = NVL (pv_src_org, source_org)
                     AND destination_org = NVL (pv_dest_org, destination_org)
            GROUP BY brand, department, item_category,
                     item_sku, from_period_identifier, to_period_identifier,
                     source_org, requested_xf_date, orig_confirmed_xf_date,
                     confirmed_xf_date, asn_creation_date, xf_shipment_date -- Added
                                                                           ,
                     promised_date, expected_receipt_date, original_promise_date,
                     intransit_receipt_date, orig_intransit_receipt_date -- Added
                                                                        , destination_org,
                     promise_expected_receipt_date   -- ,original_promise_date
                                                  -- ,intransit_receipt_date
                                                  -- ,orig_intransit_receipt_date
                                                                  --,fob_value
                     , ship_method, po_currency            --,fob_value_in_usd
                                               ,
                     calculated_flag, override_status, source
            ORDER BY promise_expected_receipt_date;

        lv_rep_pfr_file        VARCHAR2 (1000);
        lv_rep_pfr_file_zip    VARCHAR2 (1000);
        lv_file_path           VARCHAR2 (100);
        lv_hdr_line            VARCHAR2 (1000);
        buffer_size   CONSTANT INTEGER := 32767;
        lv_line                VARCHAR2 (32000);
        lv_output_file         UTL_FILE.file_type;
        lv_outbound_file       VARCHAR2 (1000);
        x_ret_code             VARCHAR2 (100);
        lv_err_msg             VARCHAR2 (100);
        x_ret_message          VARCHAR2 (100);
    BEGIN
        write_log_prc (
               'Procedure write_rep_output_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        lv_rep_pfr_file   :=
            gn_request_id || '_DeckersPOSupplyForecastReport.csv';

        -- Derive the directory Path

        BEGIN
            SELECT directory_path
              INTO lv_file_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_PO_FORECAST_REP_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_file_path   := NULL;
        END;

        lv_hdr_line   :=
               'Brand'
            || gv_delim_comma
            || 'Department'
            || gv_delim_comma
            || 'Item Category'
            || gv_delim_comma
            || 'Item Number'
            || gv_delim_comma
            || 'From Period Identifier'
            || gv_delim_comma
            || 'To Period Identifier'
            || gv_delim_comma
            || 'Source Org'
            || gv_delim_comma
            || 'Requested XF Date'
            || gv_delim_comma
            || 'Original Confirmed XF Date'
            || gv_delim_comma
            || 'Confirmed XF Date'
            || gv_delim_comma
            || 'ASN Creation Date'
            || gv_delim_comma
            || 'XF Shipment Date'
            || gv_delim_comma
            -- Added
            || 'Promised Date'
            || gv_delim_comma
            || 'Expected Receipt Date'
            || gv_delim_comma
            || 'Original Promise Date'
            || gv_delim_comma
            || 'Intransit Receipt Date'
            || gv_delim_comma
            || 'Orig Intransit Receipt Date'
            || gv_delim_comma
            -- Added
            || 'Destination Org'
            || gv_delim_comma
            || 'Promise/Expected Receipt Date'
            || gv_delim_comma
            -- ||'Original Promise Date'
            -- ||gv_delim_comma
            -- ||'Intransit Receipt Date'
            -- ||gv_delim_comma
            -- ||'Orig Intransit Receipt Date'
            -- ||gv_delim_comma
            || 'FOB Value'
            || gv_delim_comma
            || 'Open Quantity'
            || gv_delim_comma
            || 'Ship Method'
            || gv_delim_comma
            || 'PO Currency'
            || gv_delim_comma
            || 'FOB Value in USD'
            || gv_delim_comma
            || 'Calculated Flag'
            || gv_delim_comma
            || 'OVERRIDE Status'
            || gv_delim_comma
            || 'Source';

        -- WRITE INTO FOLDER
        write_log_prc (
            'DeckersPOSupplyForecast File Name is - ' || lv_rep_pfr_file);

        lv_output_file   :=
            UTL_FILE.fopen (lv_file_path, lv_rep_pfr_file, 'W' --opening the file in write mode
                                                              ,
                            buffer_size);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            lv_line   :=
                   'DECKERS CORPORATION'
                || CHR (10)
                || 'Report Name :Deckers PO Projected Supply Forecast Report'
                || CHR (10)
                || 'Report Date - :'
                || v_report_date
                || CHR (10)
                || 'Run Mode is :'
                || pv_run_mode
                || CHR (10)
                -- Added
                || 'PO Model is :'
                || pv_po_model
                || CHR (10)
                -- Added
                || 'OVERRIDE is :'
                || pv_override
                || CHR (10)
                || 'Starting Period is :'
                || pv_from_period
                || CHR (10)
                || 'Ending Period is :'
                || pv_to_period
                || CHR (10)
                || 'Include Past Due Days is :'
                || pn_incld_past_due_days
                || CHR (10)
                -- Added
                || 'Delay Delivery Days and Intransit Days are : '
                || pn_delay_delivery_days
                || ' and '
                || pn_delay_intransit_days
                || CHR (10)
                -- Added
                || 'Starting Promised Date is :'
                || pv_from_promised_date
                || CHR (10)
                || 'Ending Promised Date is :'
                || pv_to_promised_date
                || CHR (10)
                || 'Starting XF Date is :'
                || pv_from_xf_date
                || CHR (10)
                || 'Ending XF Date is :'
                || pv_to_xf_date
                || CHR (10)
                || 'Source Organization is :'
                || pv_source_org
                || CHR (10)
                || 'Destination Organization is :'
                || pv_destination_org
                || CHR (10)
                || 'Rate Date is :'
                || TO_DATE (pv_rate_date, 'RRRR/MM/DD HH24:MI:SS')
                || CHR (10)
                || 'Rate Type is :'
                || pv_rate_type
                || CHR (10);

            UTL_FILE.put_line (lv_output_file, lv_line);

            lv_line   := lv_hdr_line;
            UTL_FILE.put_line (lv_output_file, lv_line);

            FOR i IN rep_data_cur      /*(pv_from_period_date
,pv_to_period_date
,pv_src_org
,pv_dest_org)*/
            LOOP
                lv_line   :=
                       i.brand
                    || gv_delim_comma
                    || i.department
                    || gv_delim_comma
                    || i.item_category
                    || gv_delim_comma
                    || i.item_sku
                    || gv_delim_comma
                    || ' '
                    || i.from_period_identifier
                    || gv_delim_comma
                    || ' '
                    || i.to_period_identifier
                    || gv_delim_comma
                    || i.source_org
                    || gv_delim_comma
                    || i.requested_xf_date
                    || gv_delim_comma
                    || i.orig_confirmed_xf_date
                    || gv_delim_comma
                    || i.confirmed_xf_date
                    || gv_delim_comma
                    || i.asn_creation_date
                    || gv_delim_comma
                    || i.xf_shipment_date
                    || gv_delim_comma
                    -- Added
                    || i.promised_date
                    || gv_delim_comma
                    || i.expected_receipt_date
                    || gv_delim_comma
                    || i.original_promise_date
                    || gv_delim_comma
                    || i.intransit_receipt_date
                    || gv_delim_comma
                    || i.orig_intransit_receipt_date
                    || gv_delim_comma
                    -- Added
                    || i.destination_org
                    || gv_delim_comma
                    || i.promise_expected_receipt_date
                    || gv_delim_comma
                    -- ||i.original_promise_date
                    -- ||gv_delim_comma
                    -- ||i.intransit_receipt_date
                    -- ||gv_delim_comma
                    -- ||i.orig_intransit_receipt_date
                    -- ||gv_delim_comma
                    || i.fob_value
                    || gv_delim_comma
                    || i.quantity
                    || gv_delim_comma
                    || i.ship_method
                    || gv_delim_comma
                    || i.po_currency
                    || gv_delim_comma
                    || i.fob_value_in_usd
                    || gv_delim_comma
                    || i.calculated_flag
                    || gv_delim_comma
                    || i.override_status
                    || gv_delim_comma
                    || i.source;

                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
        ELSE
            lv_err_msg      :=
                SUBSTR (
                       'Error in Opening the Forecast data file for writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log_prc (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file);

        lv_rep_pfr_file_zip   :=
               SUBSTR (lv_rep_pfr_file,
                       1,
                       (INSTR (lv_rep_pfr_file, '.', -1) - 1))
            || '.zip';
        write_log_prc (
            'PO Forecast Report File Name is - ' || lv_rep_pfr_file);
        write_log_prc (
            'PO Forecast Report ZIP File Name is - ' || lv_rep_pfr_file_zip);

        create_final_zip_prc (
            pv_directory_name   => 'XXD_PO_FORECAST_REP_DIR',
            pv_file_name        => lv_rep_pfr_file,
            pv_zip_file_name    => lv_rep_pfr_file_zip);

        pfr_rep_send_mail_prc (lv_rep_pfr_file_zip);

        write_log_prc (
               'Procedure write_rep_output_prc Ends...'
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
    END write_rep_output_prc;

      /***************************************************************************
-- PROCEDURE main_prc
-- PURPOSE: This Procedure is Concurrent Program.
****************************************************************************/

    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_run_mode IN VARCHAR2, pv_po_model IN VARCHAR2, -- Added
                                                                                                                                   pv_dummy IN VARCHAR2, pv_override IN VARCHAR2, pv_dummy1 IN VARCHAR2, pv_from_period IN VARCHAR2, pv_to_period IN VARCHAR2, pn_incld_past_due_days IN NUMBER, pn_delay_delivery_days IN NUMBER, -- Added
                                                                                                                                                                                                                                                                                                                                   pn_delay_Intransit_days IN NUMBER, -- Added as per CCR0009989
                                                                                                                                                                                                                                                                                                                                                                      pv_from_promised_date IN DATE, pv_to_promised_date IN DATE, pv_from_xf_date IN DATE, pv_to_xf_date IN DATE, pv_source_org IN VARCHAR2, pv_destination_org IN VARCHAR2
                        , pv_rate_date IN VARCHAR2, pv_rate_type IN VARCHAR2)
    IS
        CURSOR get_po_details_cur (pv_from_period_date DATE, pv_to_period_date DATE, pv_from_promised_date DATE, pv_to_promised_date DATE, pv_from_xf_date DATE, pv_to_xf_date DATE, pv_asn_from_promised_date DATE, pv_asn_from_xf_date DATE, lv_source_org VARCHAR2
                                   , lv_destination_org VARCHAR2)
        IS
              SELECT run_date, po_type, subtype,
                     req_number, requisition_header_id, requisition_line_id,
                     oe_line_id, po_number, po_header_id,
                     po_line_id, po_line_location_id, shipment_number,
                     shipment_header_id, shipment_line_id, brand,
                     department, item_category, item_sku,
                     from_period_identifier, to_period_identifier, from_period_date,
                     to_period_date, source_org, requested_xf_date,
                     orig_confirmed_xf_date, confirmed_xf_date, TRUNC (asn_creation_date) asn_creation_date,
                     xf_shipment_date, destination_org, need_by_date,
                     promised_date, -- Commented and added as per CCR0009989
                                    --                     expected_receipt_date expected_receipt_date,,
                                    (expected_receipt_date + gn_delay_Intransit_days) expected_receipt_date, -- End of Change as per CCR0009989
                                                                                                             promise_expected_receipt_date,
                     original_promise_date, intransit_receipt_date, orig_intransit_receipt_date,
                     asn_type, fob_value, quantity,
                     ship_method, po_currency, fob_value_in_usd,
                     calculated_flag, override_status, source
                FROM (                                     -- Direct OPEN PO's
                      SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                                 run_date -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                         ,
                             'STANDARD'
                                 po_type,
                             'PO'
                                 subtype,
                             NULL
                                 req_number,
                             NULL
                                 requisition_header_id,
                             NULL
                                 requisition_line_id,
                             NULL
                                 oe_line_id,
                             pha.segment1
                                 po_number,
                             pha.po_header_id
                                 po_header_id,
                             pla.po_line_id
                                 po_line_id,
                             plla.line_location_id
                                 po_line_location_id,
                             NULL
                                 shipment_number,
                             NULL
                                 shipment_header_id,
                             NULL
                                 shipment_line_id,
                             pla.attribute1
                                 brand,
                             pla.attribute2
                                 department,
                             mck.concatenated_segments
                                 item_category,
                             msib.segment1
                                 item_sku,
                             pv_from_period
                                 from_period_identifier,
                             pv_to_period
                                 to_period_identifier,
                             pv_from_period_date
                                 from_period_date,
                             pv_to_period_date
                                 to_period_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     plla.ship_to_organization_id)
                                 source_org,
                             plla.attribute4
                                 requested_xf_date,
                             plla.attribute8
                                 orig_confirmed_xf_date,
                             plla.attribute5
                                 confirmed_xf_date,
                             NULL
                                 asn_creation_date,
                             NVL (plla.attribute5, plla.attribute4)
                                 xf_shipment_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     plla.ship_to_organization_id)
                                 destination_org,
                             NULL
                                 need_by_date,
                             plla.promised_date
                                 promised_date,
                             NULL
                                 expected_receipt_date,
                             NULL
                                 promise_expected_receipt_date,
                             NULL
                                 original_promise_date,
                             NULL
                                 intransit_receipt_date,
                             NULL
                                 orig_intransit_receipt_date,
                             NULL
                                 asn_type,
                             NVL (pla.attribute11, pla.unit_price)
                                 fob_value,
                               (plla.quantity - NVL (plla.quantity_cancelled, 0))
                             - NVL (plla.quantity_received, 0)
                                 quantity,
                             plla.attribute10
                                 ship_method,
                             pha.currency_code
                                 po_currency,
                             NULL
                                 fob_value_in_usd,
                             'N'
                                 calculated_flag,
                             'NEW'
                                 override_status,
                             'EBS'
                                 source
                        FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                             mtl_system_items_b msib, mtl_categories_kfv mck, fnd_lookup_values flv
                       WHERE     1 = 1
                             AND pha.po_header_id = pla.po_header_id
                             AND pla.po_line_id = plla.po_line_id
                             AND pha.authorization_status NOT IN
                                     ('CANCELLED', 'INCOMPLETE')
                             AND pla.item_id = msib.inventory_item_id
                             AND pla.category_id = mck.category_id
                             AND plla.ship_to_organization_id =
                                 msib.organization_id
                             AND NVL (pha.closed_code, 'OPEN') = 'OPEN'
                             AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                             AND NVL (plla.closed_code, 'OPEN') IN
                                     ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                             -- AND pha.attribute10 = 'STANDARD'                                                           -- Commented Parameter Logic
                             AND NVL (pla.cancel_flag, 'N') = 'N'
                             AND NVL (plla.cancel_flag, 'N') = 'N'
                             AND plla.ship_to_organization_id <> 126
                             -- AND plla.promised_date BETWEEN pv_from_period_date AND pv_to_period_date
                             -- AND plla.promised_date BETWEEN NVL (pv_from_promised_date, plla.promised_date) AND NVL (pv_to_promised_date, plla.promised_date)
                             AND expected_receipt_dt_fnc (
                                     NVL (
                                         pv_from_promised_date,
                                         NVL (
                                             TO_DATE (plla.attribute5,
                                                      'YYYY/MM/DD HH24:MI:SS'),
                                             NVL (
                                                 TO_DATE (
                                                     plla.attribute4,
                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                 pv_to_period_date + 1))),
                                     plla.promised_date,
                                     NVL (
                                         TO_DATE (plla.attribute5,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                         NVL (
                                             TO_DATE (plla.attribute4,
                                                      'YYYY/MM/DD HH24:MI:SS'),
                                             pv_to_period_date))) BETWEEN NVL (
                                                                                pv_from_promised_date
                                                                              + (CASE
                                                                                     WHEN gn_delay_delivery_days <
                                                                                          0
                                                                                     THEN
                                                                                         gn_delay_delivery_days
                                                                                     ELSE
                                                                                         0
                                                                                 END),
                                                                              -- Added Case as per CCR0009989
                                                                              plla.promised_date)
                                                                      AND NVL (
                                                                              pv_to_promised_date,
                                                                              plla.promised_date)
                             AND plla.promised_date > pv_asn_from_promised_date
                             AND plla.promised_date <=
                                 NVL (pv_to_promised_date, plla.promised_date)
                             AND NVL (
                                     TO_DATE (plla.attribute5,
                                              'YYYY/MM/DD HH24:MI:SS'),
                                     NVL (
                                         TO_DATE (plla.attribute4,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                         TO_DATE ('01-JAN-2000', 'DD-MON-YYYY'))) BETWEEN NVL (
                                                                                              pv_from_xf_date,
                                                                                              NVL (
                                                                                                  TO_DATE (
                                                                                                      plla.attribute5,
                                                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                                                  NVL (
                                                                                                      TO_DATE (
                                                                                                          plla.attribute4,
                                                                                                          'YYYY/MM/DD HH24:MI:SS'),
                                                                                                      TO_DATE (
                                                                                                          '01-JAN-2000',
                                                                                                          'DD-MON-YYYY'))))
                                                                                      AND NVL (
                                                                                              pv_to_xf_date,
                                                                                              NVL (
                                                                                                  TO_DATE (
                                                                                                      plla.attribute5,
                                                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                                                  NVL (
                                                                                                      TO_DATE (
                                                                                                          plla.attribute4,
                                                                                                          'YYYY/MM/DD HH24:MI:SS'),
                                                                                                      TO_DATE (
                                                                                                          '01-JAN-2000',
                                                                                                          'DD-MON-YYYY'))))
                             AND flv.lookup_code = plla.ship_to_organization_id
                             AND flv.meaning <> 'ME2'
                             AND flv.lookup_type = 'XXD_PO_FORECAST_ORGS'
                             AND flv.language = 'US'
                             -- Begin Parameter Logic
                             -- AND flv.tag = 'DP'
                             -- AND flv.tag IN ('DP', 'DI')
                             AND ((pv_po_model = 'All' AND ((flv.tag = 'DP') OR (flv.tag = 'DD' AND pha.attribute10 = 'INTL_DIST'))) OR (pv_po_model = 'Direct' AND (flv.tag IN ('DP', 'DD', 'DI'))))
                             -- ALL - DP, DD (INTL_DIST)
                             -- DIRECT - DP, DI, DD (NO ATTRIBUTE10)
                             -- End Parameter Logic
                             AND flv.enabled_flag = 'Y'
                             AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                      SYSDATE - 1)
                                             AND NVL (flv.end_date_active,
                                                      SYSDATE + 1)
                             AND plla.ship_to_organization_id =
                                 NVL (pv_source_org,
                                      plla.ship_to_organization_id)
                             AND plla.ship_to_organization_id =
                                 NVL (pv_destination_org,
                                      plla.ship_to_organization_id)
                             AND NOT EXISTS
                                     (SELECT 1
                                        FROM rcv_shipment_lines rsl
                                       WHERE     1 = 1
                                             AND rsl.po_header_id =
                                                 pha.po_header_id
                                             AND rsl.po_line_id =
                                                 pla.po_line_id
                                             AND rsl.po_line_location_id =
                                                 plla.line_location_id
                                             AND rsl.item_id =
                                                 msib.inventory_item_id
                                             AND rsl.to_organization_id =
                                                 msib.organization_id
                                             AND rsl.shipment_line_status_code IN
                                                     ('PARTIALLY RECEIVED', 'EXPECTED', 'CANCELLED'))
                      UNION
                      SELECT run_date, po_type, subtype,
                             req_number, requisition_header_id, requisition_line_id,
                             oe_line_id, po_number, open_qty.po_header_id,
                             open_qty.po_line_id, po_line_location_id, shipment_number,
                             shipment_header_id, shipment_line_id, brand,
                             department, item_category, item_sku,
                             from_period_identifier, to_period_identifier, from_period_date,
                             to_period_date, source_org, requested_xf_date,
                             orig_confirmed_xf_date, confirmed_xf_date, asn_creation_date,
                             xf_shipment_date, destination_org, open_qty.need_by_date,
                             open_qty.promised_date, expected_receipt_date, promise_expected_receipt_date,
                             original_promise_date, intransit_receipt_date, orig_intransit_receipt_date,
                             asn_type, fob_value, (plla.quantity - NVL (plla.quantity_cancelled, 0)) - NVL (plla.quantity_received, 0) - open_qty.quantity quantity,
                             ship_method, po_currency, fob_value_in_usd,
                             calculated_flag, override_status, source
                        FROM (  SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                                           run_date -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                                   ,
                                       'STANDARD'
                                           po_type,
                                       'PO'
                                           subtype,
                                       NULL
                                           req_number,
                                       NULL
                                           requisition_header_id,
                                       NULL
                                           requisition_line_id,
                                       NULL
                                           oe_line_id,
                                       pha.segment1
                                           po_number,
                                       pha.po_header_id
                                           po_header_id,
                                       pla.po_line_id
                                           po_line_id,
                                       plla.line_location_id
                                           po_line_location_id,
                                       NULL
                                           shipment_number,
                                       NULL
                                           shipment_header_id,
                                       NULL
                                           shipment_line_id,
                                       pla.attribute1
                                           brand,
                                       pla.attribute2
                                           department,
                                       mck.concatenated_segments
                                           item_category,
                                       msib.segment1
                                           item_sku,
                                       pv_from_period
                                           from_period_identifier,
                                       pv_to_period
                                           to_period_identifier,
                                       pv_from_period_date
                                           from_period_date,
                                       pv_to_period_date
                                           to_period_date,
                                       (SELECT ood.organization_name
                                          FROM apps.org_organization_definitions ood
                                         WHERE ood.organization_id =
                                               plla.ship_to_organization_id)
                                           source_org,
                                       plla.attribute4
                                           requested_xf_date,
                                       plla.attribute8
                                           orig_confirmed_xf_date,
                                       plla.attribute5
                                           confirmed_xf_date,
                                       NULL
                                           asn_creation_date,
                                       NVL (plla.attribute5, plla.attribute4)
                                           xf_shipment_date,
                                       (SELECT ood.organization_name
                                          FROM apps.org_organization_definitions ood
                                         WHERE ood.organization_id =
                                               plla.ship_to_organization_id)
                                           destination_org,
                                       NULL
                                           need_by_date,
                                       plla.promised_date
                                           promised_date,
                                       NULL
                                           expected_receipt_date,
                                       NULL
                                           promise_expected_receipt_date,
                                       NULL
                                           original_promise_date,
                                       NULL
                                           intransit_receipt_date,
                                       NULL
                                           orig_intransit_receipt_date,
                                       NULL
                                           asn_type,
                                       NVL (pla.attribute11, pla.unit_price)
                                           fob_value,
                                       SUM (
                                           rsl.quantity_shipped - rsl.quantity_received)
                                           quantity,
                                       plla.attribute10
                                           ship_method,
                                       pha.currency_code
                                           po_currency,
                                       NULL
                                           fob_value_in_usd,
                                       'N'
                                           calculated_flag,
                                       'NEW'
                                           override_status,
                                       'EBS'
                                           source
                                  FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                                       mtl_system_items_b msib, mtl_categories_kfv mck, rcv_shipment_headers rsh,
                                       rcv_shipment_lines rsl, fnd_lookup_values flv
                                 WHERE     1 = 1
                                       AND pha.po_header_id = pla.po_header_id
                                       AND pla.po_line_id = plla.po_line_id
                                       AND pha.authorization_status NOT IN
                                               ('CANCELLED', 'INCOMPLETE')
                                       AND pla.item_id = msib.inventory_item_id
                                       AND pla.category_id = mck.category_id
                                       AND plla.ship_to_organization_id =
                                           msib.organization_id
                                       AND NVL (pha.closed_code, 'OPEN') = 'OPEN'
                                       AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                                       AND NVL (plla.closed_code, 'OPEN') IN
                                               ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                                       -- AND pha.attribute10 = 'STANDARD'
                                       AND NVL (pla.cancel_flag, 'N') = 'N'
                                       AND NVL (plla.cancel_flag, 'N') = 'N'
                                       AND rsh.shipment_header_id =
                                           rsl.shipment_header_id
                                       AND rsh.receipt_source_code = 'VENDOR'
                                       AND rsl.po_header_id = pha.po_header_id
                                       AND rsl.po_line_id = pla.po_line_id
                                       AND rsl.po_line_location_id =
                                           plla.line_location_id
                                       AND rsl.source_document_code = 'PO'
                                       AND rsl.shipment_line_status_code IN
                                               ('PARTIALLY RECEIVED', 'EXPECTED')
                                       AND rsl.item_id = msib.inventory_item_id
                                       AND rsl.to_organization_id =
                                           msib.organization_id
                                       AND rsl.to_organization_id != 126
                                       -- AND plla.promised_date BETWEEN pv_from_period_date AND pv_to_period_date
                                       -- AND plla.promised_date BETWEEN NVL (pv_from_promised_date, plla.promised_date) AND NVL (pv_to_promised_date, plla.promised_date)
                                       AND expected_receipt_dt_fnc (
                                               NVL (
                                                   pv_from_promised_date,
                                                   NVL (
                                                       TO_DATE (
                                                           plla.attribute5,
                                                           'YYYY/MM/DD HH24:MI:SS'),
                                                       NVL (
                                                           TO_DATE (
                                                               plla.attribute4,
                                                               'YYYY/MM/DD HH24:MI:SS'),
                                                           pv_to_period_date + 1))),
                                               plla.promised_date,
                                               NVL (
                                                   TO_DATE (
                                                       plla.attribute5,
                                                       'YYYY/MM/DD HH24:MI:SS'),
                                                   NVL (
                                                       TO_DATE (
                                                           plla.attribute4,
                                                           'YYYY/MM/DD HH24:MI:SS'),
                                                       pv_to_period_date))) BETWEEN NVL (
                                                                                          pv_from_promised_date
                                                                                        + (CASE
                                                                                               WHEN gn_delay_delivery_days <
                                                                                                    0
                                                                                               THEN
                                                                                                   gn_delay_delivery_days
                                                                                               ELSE
                                                                                                   0
                                                                                           END),
                                                                                        -- Added Case as per CCR0009989
                                                                                        plla.promised_date)
                                                                                AND NVL (
                                                                                        pv_to_promised_date,
                                                                                        plla.promised_date)
                                       AND plla.promised_date >
                                           pv_asn_from_promised_date
                                       AND plla.promised_date <=
                                           NVL (pv_to_promised_date,
                                                plla.promised_date)
                                       AND NVL (
                                               TO_DATE (plla.attribute5,
                                                        'YYYY/MM/DD HH24:MI:SS'),
                                               NVL (
                                                   TO_DATE (
                                                       plla.attribute4,
                                                       'YYYY/MM/DD HH24:MI:SS'),
                                                   TO_DATE ('01-JAN-2000',
                                                            'DD-MON-YYYY'))) BETWEEN NVL (
                                                                                         pv_from_xf_date,
                                                                                         NVL (
                                                                                             TO_DATE (
                                                                                                 plla.attribute5,
                                                                                                 'YYYY/MM/DD HH24:MI:SS'),
                                                                                             NVL (
                                                                                                 TO_DATE (
                                                                                                     plla.attribute4,
                                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                                 TO_DATE (
                                                                                                     '01-JAN-2000',
                                                                                                     'DD-MON-YYYY'))))
                                                                                 AND NVL (
                                                                                         pv_to_xf_date,
                                                                                         NVL (
                                                                                             TO_DATE (
                                                                                                 plla.attribute5,
                                                                                                 'YYYY/MM/DD HH24:MI:SS'),
                                                                                             NVL (
                                                                                                 TO_DATE (
                                                                                                     plla.attribute4,
                                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                                 TO_DATE (
                                                                                                     '01-JAN-2000',
                                                                                                     'DD-MON-YYYY'))))
                                       AND flv.lookup_code =
                                           plla.ship_to_organization_id
                                       AND flv.meaning <> 'ME2'
                                       AND flv.lookup_type =
                                           'XXD_PO_FORECAST_ORGS'
                                       AND flv.language = 'US'
                                       -- Begin Parameter Logic
                                       -- AND flv.tag = 'DP'
                                       -- AND flv.tag IN ('DP', 'DI')
                                       AND ((pv_po_model = 'All' AND ((flv.tag = 'DP') OR (flv.tag = 'DD' AND pha.attribute10 = 'INTL_DIST'))) OR (pv_po_model = 'Direct' AND (flv.tag IN ('DP', 'DD', 'DI'))))
                                       -- ALL - DP, DD (INTL_DIST)
                                       -- DIRECT - DP, DI, DD (NO ATTRIBUTE10)
                                       -- End Parameter Logic
                                       AND flv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               flv.start_date_active,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               flv.end_date_active,
                                                               SYSDATE + 1)
                                       AND plla.ship_to_organization_id =
                                           NVL (pv_source_org,
                                                plla.ship_to_organization_id)
                                       AND plla.ship_to_organization_id =
                                           NVL (pv_destination_org,
                                                plla.ship_to_organization_id)
                              GROUP BY TO_CHAR (SYSDATE, 'DD-MON-YYYY'), xxd_po_get_po_type (pha.po_header_id), 'PO',
                                       pha.segment1, pha.po_header_id, pla.po_line_id,
                                       plla.line_location_id, pla.attribute1, pla.attribute2,
                                       mck.concatenated_segments, msib.segment1, pv_from_period,
                                       pv_to_period, pv_from_period_date, pv_to_period_date,
                                       plla.attribute4, plla.attribute8, plla.attribute5,
                                       NVL (plla.attribute5, plla.attribute4), plla.ship_to_organization_id, plla.promised_date,
                                       NVL (pla.attribute11, pla.unit_price), plla.attribute10, pha.currency_code,
                                       'N', 'NEW', 'EBS') open_qty,
                             po_line_locations_all plla
                       WHERE     open_qty.po_line_location_id =
                                 plla.line_location_id
                             AND   (plla.quantity - NVL (plla.quantity_cancelled, 0))
                                 - NVL (plla.quantity_received, 0)
                                 - open_qty.quantity >
                                 0
                      UNION
                      -- Direct OPEN ASN's
                      SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                                 run_date -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                         ,
                             'STANDARD'
                                 po_type,
                             'ASN'
                                 subtype,
                             NULL
                                 req_number,
                             NULL
                                 requisition_header_id,
                             NULL
                                 requisition_line_id,
                             NULL
                                 oe_line_id,
                             pha.segment1
                                 po_number,
                             pha.po_header_id
                                 po_header_id,
                             pla.po_line_id
                                 po_line_id,
                             plla.line_location_id
                                 po_line_location_id,
                             rsh.shipment_num
                                 shipment_number,
                             rsh.shipment_header_id
                                 shipment_header_id,
                             rsl.shipment_line_id
                                 shipment_line_id,
                             pla.attribute1
                                 brand,
                             pla.attribute2
                                 department,
                             mck.concatenated_segments
                                 item_category,
                             msib.segment1
                                 item_sku,
                             pv_from_period
                                 from_period_identifier,
                             pv_to_period
                                 to_period_identifier,
                             pv_from_period_date
                                 from_period_date,
                             pv_to_period_date
                                 to_period_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     plla.ship_to_organization_id)
                                 source_org,
                             plla.attribute4
                                 requested_xf_date,
                             plla.attribute8
                                 orig_confirmed_xf_date,
                             plla.attribute5
                                 confirmed_xf_date,
                             rsh.creation_date
                                 asn_creation_date,
                             NVL (plla.attribute5, plla.attribute4)
                                 xf_shipment_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     plla.ship_to_organization_id)
                                 destination_org,
                             NULL
                                 need_by_date,
                             plla.promised_date
                                 promised_date,
                             rsh.expected_receipt_date
                                 expected_receipt_date,
                             NULL
                                 promise_expected_receipt_date,
                             NULL
                                 original_promise_date,
                             NULL
                                 intransit_receipt_date,
                             NULL
                                 orig_intransit_receipt_date,
                             rsh.asn_type
                                 asn_type,
                             NVL (pla.attribute11, pla.unit_price)
                                 fob_value,
                             (rsl.quantity_shipped - rsl.quantity_received)
                                 quantity,
                             plla.attribute10
                                 ship_method,
                             pha.currency_code
                                 po_currency,
                             NULL
                                 fob_value_in_usd,
                             'N'
                                 calculated_flag,
                             'NEW'
                                 override_status,
                             'EBS'
                                 source
                        FROM po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                             mtl_system_items_b msib, mtl_categories_kfv mck, rcv_shipment_headers rsh,
                             rcv_shipment_lines rsl, fnd_lookup_values flv
                       WHERE     1 = 1
                             AND pha.po_header_id = pla.po_header_id
                             AND pla.po_line_id = plla.po_line_id
                             AND pha.authorization_status NOT IN
                                     ('CANCELLED', 'INCOMPLETE')
                             AND pla.item_id = msib.inventory_item_id
                             AND pla.category_id = mck.category_id
                             AND plla.ship_to_organization_id =
                                 msib.organization_id
                             AND NVL (pha.closed_code, 'OPEN') = 'OPEN'
                             AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                             AND NVL (plla.closed_code, 'OPEN') IN
                                     ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                             -- AND pha.attribute10 = 'STANDARD'
                             AND NVL (pla.cancel_flag, 'N') = 'N'
                             AND NVL (plla.cancel_flag, 'N') = 'N'
                             AND rsh.shipment_header_id =
                                 rsl.shipment_header_id
                             AND rsh.receipt_source_code = 'VENDOR'
                             AND rsl.po_header_id = pha.po_header_id
                             AND rsl.po_line_id = pla.po_line_id
                             AND rsl.po_line_location_id =
                                 plla.line_location_id
                             AND rsl.source_document_code = 'PO'
                             AND rsl.shipment_line_status_code IN
                                     ('PARTIALLY RECEIVED', 'EXPECTED')
                             AND rsl.item_id = msib.inventory_item_id
                             AND rsl.to_organization_id = msib.organization_id
                             AND rsl.to_organization_id != 126
                             -- AND plla.promised_date BETWEEN pv_from_period_date AND pv_to_period_date
                             -- AND plla.promised_date BETWEEN NVL (pv_from_promised_date, plla.promised_date) AND NVL (pv_to_promised_date, plla.promised_date)
                             -- AND expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS'))
                             -- BETWEEN     NVL (pv_from_promised_date, TO_DATE('01-JAN-2000','DD-MON-YYYY'))
                             -- AND NVL (pv_to_promised_date, TO_DATE('31-DEC-2999','DD-MON-YYYY'))
                             -- Commented and Added as per CCR0009989
                             --AND expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'),pv_to_promised_date)))
                             -- <= NVL (pv_to_promised_date, pv_to_period_date)
                             AND (rsh.expected_receipt_date + gn_delay_Intransit_days) <=
                                 NVL (pv_to_promised_date, pv_to_period_date)
                             -- End of Change as per CCR0009989
                             -- AND NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'), TO_DATE('01-JAN-2000','DD-MON-YYYY')))
                             -- BETWEEN    NVL (pv_from_xf_date, NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'),TO_DATE('01-JAN-2000','DD-MON-YYYY'))))
                             -- AND NVL (pv_to_xf_date,NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'),TO_DATE('01-JAN-2000','DD-MON-YYYY'))))
                             AND rsh.creation_date BETWEEN NVL (
                                                               pv_from_xf_date,
                                                               rsh.creation_date)
                                                       AND NVL (
                                                               pv_to_xf_date,
                                                               rsh.creation_date)
                             AND flv.lookup_code = plla.ship_to_organization_id
                             AND flv.meaning <> 'ME2'
                             AND flv.lookup_type = 'XXD_PO_FORECAST_ORGS'
                             AND flv.language = 'US'
                             -- Begin Parameter Logic
                             -- AND flv.tag = 'DP'
                             -- AND flv.tag IN ('DP', 'DI')
                             AND ((pv_po_model = 'All' AND ((flv.tag = 'DP') OR (flv.tag = 'DD' AND pha.attribute10 = 'INTL_DIST'))) OR (pv_po_model = 'Direct' AND (flv.tag IN ('DP', 'DD', 'DI'))))
                             -- ALL - DP, DD (INTL_DIST)
                             -- DIRECT - DP, DI, DD (NO ATTRIBUTE10)
                             -- End Parameter Logic
                             AND flv.enabled_flag = 'Y'
                             AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                      SYSDATE - 1)
                                             AND NVL (flv.end_date_active,
                                                      SYSDATE + 1)
                             AND plla.ship_to_organization_id =
                                 NVL (pv_source_org,
                                      plla.ship_to_organization_id)
                             AND plla.ship_to_organization_id =
                                 NVL (pv_destination_org,
                                      plla.ship_to_organization_id)
                                /*UNION
              -- Direct ERD (Incld past Due)
              SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY') run_date
                    -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                    ,'STANDARD' po_type
                    ,'ASN' subtype
                    ,NULL req_number
                    ,NULL requisition_header_id
                    ,NULL requisition_line_id
                    ,NULL oe_line_id
                    ,pha.segment1 po_number
                    ,pha.po_header_id po_header_id
                    ,pla.po_line_id po_line_id
                    ,plla.line_location_id po_line_location_id
                    ,rsh.shipment_num shipment_number
                    ,rsh.shipment_header_id shipment_header_id
                    ,rsl.shipment_line_id shipment_line_id
                    ,pla.attribute1 brand
                    ,pla.attribute2 department
                    ,mck.concatenated_segments item_category
                    ,msib.segment1 item_sku
                    ,pv_from_period from_period_identifier
                    ,pv_to_period to_period_identifier
                    ,pv_from_period_date from_period_date
                    ,pv_to_period_date to_period_date
                    ,(SELECT ood.organization_name
                        FROM apps.org_organization_definitions ood
                       WHERE ood.organization_id = plla.ship_to_organization_id) source_org
                    ,plla.attribute4 requested_xf_date
                    ,plla.attribute8 orig_confirmed_xf_date
                    ,plla.attribute5 confirmed_xf_date
                    ,rsh.creation_date asn_creation_date
                    ,NVL (plla.attribute5, plla.attribute4) xf_shipment_date
                    ,(SELECT ood.organization_name
                        FROM apps.org_organization_definitions ood
                       WHERE ood.organization_id = plla.ship_to_organization_id) destination_org
                    ,NULL need_by_date
                    ,plla.promised_date promised_date
                    ,rsh.expected_receipt_date expected_receipt_date
                    ,NULL promise_expected_receipt_date
                    ,NULL original_promise_date
                    ,NULL intransit_receipt_date
                    ,NULL orig_intransit_receipt_date
                    ,rsh.asn_type asn_type
                    ,NVL(pla.attribute11, pla.unit_price) fob_value
                    --,(plla.quantity - NVL (plla.quantity_cancelled, 0)) - NVL (plla.quantity_received,0) quantity
                    ,(rsl.quantity_shipped - rsl.quantity_received) quantity
                    ,plla.attribute10 ship_method
                    ,pha.currency_code po_currency
                    ,NULL fob_value_in_usd
                    ,'N' calculated_flag
                    ,'NEW' override_status
                    ,'EBS' source
                FROM po_headers_all pha
                    ,po_lines_all pla
                    ,po_line_locations_all plla
                    ,mtl_system_items_b msib
                    ,mtl_categories_kfv mck
                    ,rcv_shipment_headers rsh
                    ,rcv_shipment_lines rsl
                    ,fnd_lookup_values flv
               WHERE 1 = 1
                 AND pha.po_header_id = pla.po_header_id
                 AND pla.po_line_id = plla.po_line_id
                 AND pha.authorization_status NOT IN ('CANCELLED', 'INCOMPLETE')
                 AND pla.item_id = msib.inventory_item_id
                 AND pla.category_id = mck.category_id
                 AND plla.ship_to_organization_id = msib.organization_id
                 AND NVL (pha.closed_code, 'OPEN') = 'OPEN'
                 AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                 AND NVL (plla.closed_code,'OPEN') IN ('OPEN','CLOSED FOR INVOICE','CLOSED FOR RECEIVING')
                 -- AND pha.attribute10 = 'STANDARD'
                 AND NVL (pla.cancel_flag, 'N') = 'N'
                 AND NVL (plla.cancel_flag, 'N') = 'N'
                 AND rsh.shipment_header_id = rsl.shipment_header_id
                 AND rsh.receipt_source_code = 'VENDOR'
                 AND rsl.po_header_id = pha.po_header_id
                 AND rsl.po_line_id = pla.po_line_id
                 AND rsl.po_line_location_id = plla.line_location_id
                 AND rsl.source_document_code = 'PO'
                 AND rsl.shipment_line_status_code IN ('PARTIALLY RECEIVED','EXPECTED')
                 AND rsl.item_id = msib.inventory_item_id
                 AND rsl.to_organization_id = msib.organization_id
                 AND rsl.to_organization_id !=126
                 -- AND (rsh.expected_receipt_date >= pv_asn_from_promised_date AND rsh.expected_receipt_date < NVL (pv_from_promised_date, pv_from_period_date))
                 AND rsh.creation_date >= pv_from_period_date - 365
                 AND expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS'))
                     < NVL (pv_from_promised_date, expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS')))
                 AND flv.lookup_code = plla.ship_to_organization_id
                 AND flv.meaning <> 'ME2'
                 AND flv.lookup_type = 'XXD_PO_FORECAST_ORGS'
                 AND flv.language = 'US'
-- Begin Parameter Logic
                 -- AND flv.tag = 'DP'
                 -- AND flv.tag IN ('DP', 'DI')
                 AND (  (pv_po_model = 'All' AND ((flv.tag = 'DP') OR (flv.tag ='DD' AND pha.attribute10 = 'INTL_DIST')))
                      OR (pv_po_model = 'Direct' AND (flv.tag IN ('DP', 'DD', 'DI'))))
                 -- ALL - DP, DD (INTL_DIST)
                 -- DIRECT - DP, DI, DD (NO ATTRIBUTE10)
-- End Parameter Logic
                 AND flv.enabled_flag = 'Y'
                 AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1) AND NVL (flv.end_date_active, SYSDATE + 1)
                 AND plla.ship_to_organization_id = NVL (pv_source_org, plla.ship_to_organization_id)
                 AND plla.ship_to_organization_id = NVL (pv_destination_org, plla.ship_to_organization_id)*/
                      UNION
                      -- Interco Open IR's
                      SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                                 run_date -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                         ,
                             'INTERCO'
                                 po_type,
                             'REQ'
                                 subtype,
                             prha.segment1
                                 req_number,
                             prha.requisition_header_id
                                 requisition_header_id,
                             prla.requisition_line_id
                                 requisition_line_id --,oola.line_id oe_line_id
                                                    ,
                             NULL
                                 oe_line_id,
                             pha.segment1
                                 po_number,
                             pha.po_header_id
                                 po_header_id,
                             pla.po_line_id
                                 po_line_id,
                             plla.line_location_id
                                 po_line_location_id,
                             NULL
                                 shipment_number,
                             NULL
                                 shipment_header_id,
                             NULL
                                 shipment_line_id,
                             pla.attribute1
                                 brand,
                             pla.attribute2
                                 department,
                             mck.concatenated_segments
                                 item_category,
                             msib.segment1
                                 item_sku,
                             pv_from_period
                                 from_period_identifier,
                             pv_to_period
                                 to_period_identifier,
                             pv_from_period_date
                                 from_period_date,
                             pv_to_period_date
                                 to_period_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     prla.source_organization_id)
                                 source_org,
                             plla.attribute4
                                 requested_xf_date,
                             plla.attribute8
                                 orig_confirmed_xf_date,
                             plla.attribute5
                                 confirmed_xf_date,
                             NULL
                                 asn_creation_date,
                             NVL (plla.attribute5, plla.attribute4)
                                 xf_shipment_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     prla.destination_organization_id)
                                 destination_org,
                             prla.need_by_date
                                 need_by_date,
                             plla.promised_date
                                 promised_date,
                             NULL
                                 expected_receipt_date,
                             NULL
                                 promise_expected_receipt_date,
                             NULL
                                 original_promise_date,
                             NULL
                                 intransit_receipt_date,
                             NULL
                                 orig_intransit_receipt_date,
                             NULL
                                 asn_type,
                             NVL (pla.attribute11, pla.unit_price)
                                 fob_value,
                               (prla.quantity - NVL (prla.quantity_received, 0))
                             - NVL (prla.quantity_cancelled, 0)
                                 quantity --,(oola.ordered_quantity- NVL (oola.shipped_quantity,0)) - NVL (oola.cancelled_quantity,0) quantity
                                         --,(oola.ordered_quantity- NVL (oola.shipped_quantity,0)) quantity
                                         ,
                             plla.attribute10
                                 ship_method,
                             pha.currency_code
                                 po_currency,
                             NULL
                                 fob_value_in_usd,
                             'N'
                                 calculated_flag,
                             'NEW'
                                 override_status,
                             'EBS'
                                 source
                        FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prda,
                             oe_order_lines_all oola, po_headers_all pha, po_lines_all pla,
                             po_line_locations_all plla, mtl_system_items_b msib, mtl_categories_kfv mck,
                             fnd_lookup_values flv
                       WHERE     1 = 1
                             AND prha.requisition_header_id =
                                 prla.requisition_header_id
                             AND prla.requisition_line_id =
                                 prda.requisition_line_id
                             AND prha.authorization_status NOT IN
                                     ('CANCELLED', 'INCOMPLETE', 'REJECTED')
                             AND NVL (prla.closed_code, 'OPEN') ! =
                                 'FINALLY CLOSED'
                             AND prla.requisition_header_id =
                                 oola.source_document_id
                             AND prla.requisition_line_id =
                                 oola.source_document_line_id
                             AND NVL (prla.cancel_flag, 'N') = 'N'
                             AND oola.source_type_code = 'INTERNAL'
                             AND oola.order_source_id = 10
                             AND oola.cancelled_flag = 'N'
                             AND oola.attribute16 =
                                 TO_CHAR (plla.line_location_id)
                             AND plla.po_line_id = pla.po_line_id
                             AND pla.po_header_id = pha.po_header_id
                             AND pha.attribute10 = 'STANDARD'
                             AND NVL (prla.cancel_flag, 'N') = 'N'
                             AND NVL (pla.cancel_flag, 'N') = 'N'
                             AND NVL (plla.cancel_flag, 'N') = 'N'
                             AND prla.item_id = msib.inventory_item_id
                             AND prla.destination_organization_id =
                                 msib.organization_id
                             AND prla.category_id = mck.category_id
                             -- AND prla.need_by_date BETWEEN pv_from_period_date AND pv_to_period_date
                             -- AND prla.need_by_date BETWEEN NVL (pv_from_promised_date, prla.need_by_date) AND NVL (pv_to_promised_date, prla.need_by_date)
                             AND expected_receipt_dt_fnc (
                                     NVL (
                                         pv_from_promised_date,
                                         NVL (
                                             TO_DATE (plla.attribute5,
                                                      'YYYY/MM/DD HH24:MI:SS'),
                                             NVL (
                                                 TO_DATE (
                                                     plla.attribute4,
                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                 pv_to_period_date + 1))),
                                     prla.need_by_date,
                                     NVL (
                                         TO_DATE (plla.attribute5,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                         NVL (
                                             TO_DATE (plla.attribute4,
                                                      'YYYY/MM/DD HH24:MI:SS'),
                                             pv_to_period_date))) BETWEEN NVL (
                                                                                pv_from_promised_date
                                                                              + (CASE
                                                                                     WHEN gn_delay_delivery_days <
                                                                                          0
                                                                                     THEN
                                                                                         gn_delay_delivery_days
                                                                                     ELSE
                                                                                         0
                                                                                 END),
                                                                              -- Added Case as per CCR0009989
                                                                              prla.need_by_date)
                                                                      AND NVL (
                                                                              pv_to_promised_date,
                                                                              prla.need_by_date)
                             AND prla.need_by_date > pv_asn_from_promised_date
                             AND prla.need_by_date <=
                                 NVL (pv_to_promised_date, prla.need_by_date)
                             AND NVL (
                                     TO_DATE (plla.attribute5,
                                              'YYYY/MM/DD HH24:MI:SS'),
                                     NVL (
                                         TO_DATE (plla.attribute4,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                         TO_DATE ('01-JAN-2000', 'DD-MON-YYYY'))) BETWEEN NVL (
                                                                                              pv_from_xf_date,
                                                                                              NVL (
                                                                                                  TO_DATE (
                                                                                                      plla.attribute5,
                                                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                                                  NVL (
                                                                                                      TO_DATE (
                                                                                                          plla.attribute4,
                                                                                                          'YYYY/MM/DD HH24:MI:SS'),
                                                                                                      TO_DATE (
                                                                                                          '01-JAN-2000',
                                                                                                          'DD-MON-YYYY'))))
                                                                                      AND NVL (
                                                                                              pv_to_xf_date,
                                                                                              NVL (
                                                                                                  TO_DATE (
                                                                                                      plla.attribute5,
                                                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                                                  NVL (
                                                                                                      TO_DATE (
                                                                                                          plla.attribute4,
                                                                                                          'YYYY/MM/DD HH24:MI:SS'),
                                                                                                      TO_DATE (
                                                                                                          '01-JAN-2000',
                                                                                                          'DD-MON-YYYY'))))
                             AND flv.lookup_code =
                                 prla.destination_organization_id
                             AND flv.lookup_type = 'XXD_PO_FORECAST_ORGS'
                             AND flv.language = 'US'
                             -- Begin Parameter Logic
                             -- AND flv.tag = 'IC'
                             -- AND flv.tag IN ('DI', 'IC')
                             AND (flv.tag IN ('DI', 'IC') AND (pv_po_model = 'All' OR pv_po_model = 'Non Direct'))
                             -- ALL - DI, IC
                             -- NOT DIRECT -- DI, IC
                             -- End Parameter Logic
                             AND flv.enabled_flag = 'Y'
                             AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                      SYSDATE - 1)
                                             AND NVL (flv.end_date_active,
                                                      SYSDATE + 1)
                             -- AND plla.ship_to_organization_id = NVL (pv_source_org, plla.ship_to_organization_id)
                             -- AND prla.source_organization_id = NVL (pv_source_org, prla.source_organization_id)
                             -- AND prla.destination_organization_id = NVL (pv_destination_org, prla.destination_organization_id)
                             -- AND prla.source_organization_id = DECODE (pv_source_org, NULL, prla.source_organization_id, pv_source_org)
                             -- AND prla.destination_organization_id = DECODE (pv_destination_org, NULL, prla.destination_organization_id, pv_destination_org)
                             -- AND prla.source_organization_id = NVL (pv_source_org, 129)
                             AND prla.source_organization_id IN
                                     (SELECT lookup_code
                                        FROM fnd_lookup_values
                                       WHERE     lookup_type =
                                                 'XXD_PO_FORECAST_ORGS'
                                             AND language = 'US'
                                             -- AND tag = 'VO'
                                             AND tag = 'DI'
                                             AND enabled_flag = 'Y'
                                             AND lookup_code =
                                                 NVL (
                                                     pv_source_org,
                                                     prla.source_organization_id)
                                             AND SYSDATE BETWEEN NVL (
                                                                     flv.start_date_active,
                                                                       SYSDATE
                                                                     - 1)
                                                             AND NVL (
                                                                     flv.end_date_active,
                                                                       SYSDATE
                                                                     + 1))
                             AND prla.destination_organization_id IN
                                     (SELECT lookup_code
                                        FROM fnd_lookup_values
                                       WHERE     lookup_type =
                                                 'XXD_PO_FORECAST_ORGS'
                                             AND language = 'US'
                                             AND tag = 'IC'
                                             AND enabled_flag = 'Y'
                                             AND lookup_code =
                                                 NVL (
                                                     pv_destination_org,
                                                     prla.destination_organization_id)
                                             AND SYSDATE BETWEEN NVL (
                                                                     flv.start_date_active,
                                                                       SYSDATE
                                                                     - 1)
                                                             AND NVL (
                                                                     flv.end_date_active,
                                                                       SYSDATE
                                                                     + 1))
                             AND NOT EXISTS
                                     (SELECT 1
                                        FROM rcv_shipment_lines rsl
                                       WHERE     1 = 1
                                             AND rsl.requisition_line_id =
                                                 prla.requisition_line_id
                                             AND rsl.req_distribution_id =
                                                 prda.distribution_id
                                             AND rsl.item_id =
                                                 msib.inventory_item_id
                                             AND rsl.to_organization_id =
                                                 msib.organization_id
                                             AND rsl.shipment_line_status_code IN
                                                     ('PARTIALLY RECEIVED', 'EXPECTED', 'CANCELLED'))
                      UNION
                      SELECT run_date, po_type, subtype,
                             req_number, open_qty.requisition_header_id, open_qty.requisition_line_id,
                             oe_line_id, po_number, open_qty.po_header_id,
                             open_qty.po_line_id, po_line_location_id, shipment_number,
                             shipment_header_id, shipment_line_id, brand,
                             department, item_category, item_sku,
                             from_period_identifier, to_period_identifier, from_period_date,
                             to_period_date, source_org, requested_xf_date,
                             orig_confirmed_xf_date, confirmed_xf_date, asn_creation_date,
                             xf_shipment_date, destination_org, open_qty.need_by_date,
                             open_qty.promised_date, expected_receipt_date, promise_expected_receipt_date,
                             original_promise_date, intransit_receipt_date, orig_intransit_receipt_date,
                             asn_type, fob_value, (prla.quantity - NVL (prla.quantity_received, 0)) - open_qty.quantity quantity,
                             open_qty.ship_method, po_currency, fob_value_in_usd,
                             calculated_flag, override_status, source
                        FROM (  SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                                           run_date -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                                   ,
                                       'INTERCO'
                                           po_type,
                                       'REQ'
                                           subtype,
                                       prha.segment1
                                           req_number,
                                       prha.requisition_header_id
                                           requisition_header_id,
                                       prla.requisition_line_id
                                           requisition_line_id --,oola.line_id oe_line_id
                                                              ,
                                       NULL
                                           oe_line_id,
                                       pha.segment1
                                           po_number,
                                       pha.po_header_id
                                           po_header_id,
                                       pla.po_line_id
                                           po_line_id,
                                       plla.line_location_id
                                           po_line_location_id,
                                       NULL
                                           shipment_number,
                                       NULL
                                           shipment_header_id,
                                       NULL
                                           shipment_line_id,
                                       pla.attribute1
                                           brand,
                                       pla.attribute2
                                           department,
                                       mck.concatenated_segments
                                           item_category,
                                       msib.segment1
                                           item_sku,
                                       pv_from_period
                                           from_period_identifier,
                                       pv_to_period
                                           to_period_identifier,
                                       pv_from_period_date
                                           from_period_date,
                                       pv_to_period_date
                                           to_period_date,
                                       (SELECT ood.organization_name
                                          FROM apps.org_organization_definitions ood
                                         WHERE ood.organization_id =
                                               prla.source_organization_id)
                                           source_org,
                                       plla.attribute4
                                           requested_xf_date,
                                       plla.attribute8
                                           orig_confirmed_xf_date,
                                       plla.attribute5
                                           confirmed_xf_date,
                                       NULL
                                           asn_creation_date,
                                       NVL (plla.attribute5, plla.attribute4)
                                           xf_shipment_date,
                                       (SELECT ood.organization_name
                                          FROM apps.org_organization_definitions ood
                                         WHERE ood.organization_id =
                                               prla.destination_organization_id)
                                           destination_org,
                                       prla.need_by_date
                                           need_by_date,
                                       plla.promised_date
                                           promised_date,
                                       NULL
                                           expected_receipt_date,
                                       NULL
                                           promise_expected_receipt_date,
                                       NULL
                                           original_promise_date,
                                       NULL
                                           intransit_receipt_date,
                                       NULL
                                           orig_intransit_receipt_date,
                                       NULL
                                           asn_type,
                                       NVL (pla.attribute11, pla.unit_price)
                                           fob_value,
                                       SUM (
                                           rsl.quantity_shipped - rsl.quantity_received)
                                           quantity,
                                       plla.attribute10
                                           ship_method,
                                       pha.currency_code
                                           po_currency,
                                       NULL
                                           fob_value_in_usd,
                                       'N'
                                           calculated_flag,
                                       'NEW'
                                           override_status,
                                       'EBS'
                                           source
                                  FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prda,
                                       oe_order_lines_all oola, po_headers_all pha, po_lines_all pla,
                                       po_line_locations_all plla, mtl_system_items_b msib, mtl_categories_kfv mck,
                                       rcv_shipment_headers rsh, rcv_shipment_lines rsl, mtl_material_transactions mmt,
                                       wsh_delivery_details wdd, fnd_lookup_values flv
                                 WHERE     1 = 1
                                       AND prha.requisition_header_id =
                                           prla.requisition_header_id
                                       AND prla.requisition_line_id =
                                           prda.requisition_line_id
                                       AND prha.authorization_status NOT IN
                                               ('CANCELLED', 'INCOMPLETE', 'REJECTED')
                                       AND NVL (prla.closed_code, 'OPEN') ! =
                                           'FINALLY CLOSED'
                                       AND prla.requisition_header_id =
                                           oola.source_document_id
                                       AND prla.requisition_line_id =
                                           oola.source_document_line_id
                                       AND NVL (prla.cancel_flag, 'N') = 'N'
                                       AND oola.source_type_code = 'INTERNAL'
                                       AND oola.order_source_id = 10
                                       AND oola.cancelled_flag = 'N'
                                       AND oola.attribute16 =
                                           TO_CHAR (plla.line_location_id)
                                       AND plla.po_line_id = pla.po_line_id
                                       AND pla.po_header_id = pha.po_header_id
                                       AND pha.attribute10 = 'STANDARD'
                                       AND NVL (prla.cancel_flag, 'N') = 'N'
                                       AND NVL (pla.cancel_flag, 'N') = 'N'
                                       AND NVL (plla.cancel_flag, 'N') = 'N'
                                       AND prla.item_id = msib.inventory_item_id
                                       AND prla.destination_organization_id =
                                           msib.organization_id
                                       AND prla.category_id = mck.category_id
                                       AND prla.requisition_line_id =
                                           rsl.requisition_line_id
                                       AND prda.distribution_id =
                                           rsl.req_distribution_id
                                       AND rsl.source_document_code = 'REQ'
                                       AND rsl.shipment_header_id =
                                           rsh.shipment_header_id
                                       AND rsh.receipt_source_code =
                                           'INTERNAL ORDER'
                                       AND rsl.shipment_line_status_code IN
                                               ('PARTIALLY RECEIVED', 'EXPECTED')
                                       AND rsl.item_id = msib.inventory_item_id
                                       AND rsl.to_organization_id =
                                           msib.organization_id
                                       AND rsl.mmt_transaction_id =
                                           mmt.transaction_id
                                       AND mmt.picking_line_id =
                                           wdd.delivery_detail_id
                                       AND wdd.source_line_id = oola.line_id
                                       -- AND prla.need_by_date BETWEEN pv_from_period_date AND pv_to_period_date
                                       -- AND prla.need_by_date BETWEEN NVL (pv_from_promised_date, prla.need_by_date) AND NVL (pv_to_promised_date, prla.need_by_date)
                                       AND expected_receipt_dt_fnc (
                                               NVL (
                                                   pv_from_promised_date,
                                                   NVL (
                                                       TO_DATE (
                                                           plla.attribute5,
                                                           'YYYY/MM/DD HH24:MI:SS'),
                                                       NVL (
                                                           TO_DATE (
                                                               plla.attribute4,
                                                               'YYYY/MM/DD HH24:MI:SS'),
                                                           pv_to_period_date + 1))),
                                               prla.need_by_date,
                                               NVL (
                                                   TO_DATE (
                                                       plla.attribute5,
                                                       'YYYY/MM/DD HH24:MI:SS'),
                                                   NVL (
                                                       TO_DATE (
                                                           plla.attribute4,
                                                           'YYYY/MM/DD HH24:MI:SS'),
                                                       pv_to_period_date))) BETWEEN NVL (
                                                                                          pv_from_promised_date
                                                                                        + (CASE
                                                                                               WHEN gn_delay_delivery_days <
                                                                                                    0
                                                                                               THEN
                                                                                                   gn_delay_delivery_days
                                                                                               ELSE
                                                                                                   0
                                                                                           END),
                                                                                        -- Added Case as per CCR0009989
                                                                                        prla.need_by_date)
                                                                                AND NVL (
                                                                                        pv_to_promised_date,
                                                                                        prla.need_by_date)
                                       AND prla.need_by_date >
                                           pv_asn_from_promised_date
                                       AND prla.need_by_date <=
                                           NVL (pv_to_promised_date,
                                                prla.need_by_date)
                                       AND NVL (
                                               TO_DATE (plla.attribute5,
                                                        'YYYY/MM/DD HH24:MI:SS'),
                                               NVL (
                                                   TO_DATE (
                                                       plla.attribute4,
                                                       'YYYY/MM/DD HH24:MI:SS'),
                                                   TO_DATE ('01-JAN-2000',
                                                            'DD-MON-YYYY'))) BETWEEN NVL (
                                                                                         pv_from_xf_date,
                                                                                         NVL (
                                                                                             TO_DATE (
                                                                                                 plla.attribute5,
                                                                                                 'YYYY/MM/DD HH24:MI:SS'),
                                                                                             NVL (
                                                                                                 TO_DATE (
                                                                                                     plla.attribute4,
                                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                                 TO_DATE (
                                                                                                     '01-JAN-2000',
                                                                                                     'DD-MON-YYYY'))))
                                                                                 AND NVL (
                                                                                         pv_to_xf_date,
                                                                                         NVL (
                                                                                             TO_DATE (
                                                                                                 plla.attribute5,
                                                                                                 'YYYY/MM/DD HH24:MI:SS'),
                                                                                             NVL (
                                                                                                 TO_DATE (
                                                                                                     plla.attribute4,
                                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                                 TO_DATE (
                                                                                                     '01-JAN-2000',
                                                                                                     'DD-MON-YYYY'))))
                                       AND flv.lookup_code =
                                           prla.destination_organization_id
                                       AND flv.lookup_type =
                                           'XXD_PO_FORECAST_ORGS'
                                       AND flv.language = 'US'
                                       -- Begin Parameter Logic
                                       -- AND flv.tag = 'IC'
                                       -- AND flv.tag IN ('DI', 'IC')
                                       AND (flv.tag IN ('DI', 'IC') AND (pv_po_model = 'All' OR pv_po_model = 'Non Direct'))
                                       -- ALL - DI, IC
                                       -- NOT DIRECT -- DI, IC
                                       -- End Parameter Logic
                                       AND flv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               flv.start_date_active,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               flv.end_date_active,
                                                               SYSDATE + 1)
                                       -- AND plla.ship_to_organization_id = NVL (pv_source_org, plla.ship_to_organization_id)
                                       -- AND prla.source_organization_id = NVL (pv_source_org, prla.source_organization_id)
                                       -- AND prla.destination_organization_id = NVL (pv_destination_org, prla.destination_organization_id)
                                       -- AND prla.source_organization_id = DECODE (pv_source_org, NULL, prla.source_organization_id, pv_source_org)
                                       -- AND prla.destination_organization_id = DECODE (pv_destination_org, NULL, prla.destination_organization_id, pv_destination_org)
                                       -- AND prla.source_organization_id = NVL (pv_source_org, 129)
                                       AND prla.source_organization_id IN
                                               (SELECT lookup_code
                                                  FROM fnd_lookup_values
                                                 WHERE     lookup_type =
                                                           'XXD_PO_FORECAST_ORGS'
                                                       AND language = 'US'
                                                       -- AND tag = 'VO'
                                                       AND tag = 'DI'
                                                       AND enabled_flag = 'Y'
                                                       AND lookup_code =
                                                           NVL (
                                                               pv_source_org,
                                                               prla.source_organization_id)
                                                       AND SYSDATE BETWEEN NVL (
                                                                               flv.start_date_active,
                                                                                 SYSDATE
                                                                               - 1)
                                                                       AND NVL (
                                                                               flv.end_date_active,
                                                                                 SYSDATE
                                                                               + 1))
                                       AND prla.destination_organization_id IN
                                               (SELECT lookup_code
                                                  FROM fnd_lookup_values
                                                 WHERE     lookup_type =
                                                           'XXD_PO_FORECAST_ORGS'
                                                       AND language = 'US'
                                                       AND tag = 'IC'
                                                       AND enabled_flag = 'Y'
                                                       AND lookup_code =
                                                           NVL (
                                                               pv_destination_org,
                                                               prla.destination_organization_id)
                                                       AND SYSDATE BETWEEN NVL (
                                                                               flv.start_date_active,
                                                                                 SYSDATE
                                                                               - 1)
                                                                       AND NVL (
                                                                               flv.end_date_active,
                                                                                 SYSDATE
                                                                               + 1))
                              GROUP BY TO_CHAR (SYSDATE, 'DD-MON-YYYY'), xxd_po_get_po_type (pha.po_header_id), 'REQ',
                                       prha.segment1, prha.requisition_header_id, prla.requisition_line_id --,oola.line_id
                                                                                                          ,
                                       pha.segment1, pha.po_header_id, pla.po_line_id,
                                       plla.line_location_id, pla.attribute1, pla.attribute2,
                                       mck.concatenated_segments, msib.segment1, pv_from_period,
                                       pv_to_period, pv_from_period_date, pv_to_period_date,
                                       prla.source_organization_id, plla.attribute4, plla.attribute8,
                                       plla.attribute5, NVL (plla.attribute5, plla.attribute4), prla.destination_organization_id,
                                       prla.need_by_date, plla.promised_date, NVL (pla.attribute11, pla.unit_price),
                                       plla.attribute10, pha.currency_code, 'N',
                                       'NEW', 'EBS') open_qty,
                             po_requisition_lines_all prla
                       WHERE     open_qty.requisition_line_id =
                                 prla.requisition_line_id
                             AND   ((prla.quantity - NVL (prla.quantity_received, 0)) - NVL (prla.quantity_cancelled, 0))
                                 - open_qty.quantity >
                                 0
                      UNION
                      -- Interco Open ASN's
                      SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                                 run_date -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                         ,
                             'INTERCO'
                                 po_type,
                             'ASN'
                                 subtype,
                             prha.segment1
                                 req_number,
                             prha.requisition_header_id
                                 requisition_header_id,
                             prla.requisition_line_id
                                 requisition_line_id --,oola.line_id oe_line_id
                                                    ,
                             NULL
                                 oe_line_id,
                             pha.segment1
                                 po_number,
                             pha.po_header_id
                                 po_header_id,
                             pla.po_line_id
                                 po_line_id,
                             plla.line_location_id
                                 po_line_location_id,
                             rsh.shipment_num
                                 shipment_number,
                             rsh.shipment_header_id
                                 shipment_header_id,
                             rsl.shipment_line_id
                                 shipment_line_id,
                             pla.attribute1
                                 brand,
                             pla.attribute2
                                 department,
                             mck.concatenated_segments
                                 item_category,
                             msib.segment1
                                 item_sku,
                             pv_from_period
                                 from_period_identifier,
                             pv_to_period
                                 to_period_identifier,
                             pv_from_period_date
                                 from_period_date,
                             pv_to_period_date
                                 to_period_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     prla.source_organization_id)
                                 source_org,
                             plla.attribute4
                                 requested_xf_date,
                             plla.attribute8
                                 orig_confirmed_xf_date,
                             plla.attribute5
                                 confirmed_xf_date,
                             rsh.creation_date
                                 asn_creation_date,
                             NVL (plla.attribute5, plla.attribute4)
                                 xf_shipment_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     prla.destination_organization_id)
                                 destination_org,
                             prla.need_by_date
                                 need_by_date,
                             plla.promised_date
                                 promised_date,
                             rsh.expected_receipt_date
                                 expected_receipt_date,
                             NULL
                                 promise_expected_receipt_date,
                             NULL
                                 original_promise_date,
                             NULL
                                 intransit_receipt_date,
                             NULL
                                 orig_intransit_receipt_date,
                             rsh.asn_type
                                 asn_type,
                             NVL (pla.attribute11, pla.unit_price)
                                 fob_value,
                             (rsl.quantity_shipped - rsl.quantity_received)
                                 quantity,
                             plla.attribute10
                                 ship_method,
                             pha.currency_code
                                 po_currency,
                             NULL
                                 fob_value_in_usd,
                             'N'
                                 calculated_flag,
                             'NEW'
                                 override_status,
                             'EBS'
                                 source
                        FROM po_requisition_headers_all prha, po_requisition_lines_all prla, po_req_distributions_all prda,
                             oe_order_lines_all oola, po_headers_all pha, po_lines_all pla,
                             po_line_locations_all plla, mtl_system_items_b msib, mtl_categories_kfv mck,
                             rcv_shipment_headers rsh, rcv_shipment_lines rsl, mtl_material_transactions mmt,
                             wsh_delivery_details wdd, fnd_lookup_values flv
                       WHERE     1 = 1
                             AND prha.requisition_header_id =
                                 prla.requisition_header_id
                             AND prla.requisition_line_id =
                                 prda.requisition_line_id
                             AND prha.authorization_status NOT IN
                                     ('CANCELLED', 'INCOMPLETE', 'REJECTED')
                             AND NVL (prla.closed_code, 'OPEN') ! =
                                 'FINALLY CLOSED'
                             AND prla.requisition_header_id =
                                 oola.source_document_id
                             AND prla.requisition_line_id =
                                 oola.source_document_line_id
                             AND NVL (prla.cancel_flag, 'N') = 'N'
                             AND oola.source_type_code = 'INTERNAL'
                             AND oola.order_source_id = 10
                             AND oola.cancelled_flag = 'N'
                             AND oola.attribute16 =
                                 TO_CHAR (plla.line_location_id)
                             AND plla.po_line_id = pla.po_line_id
                             AND pla.po_header_id = pha.po_header_id
                             AND pha.attribute10 = 'STANDARD'
                             AND NVL (prla.cancel_flag, 'N') = 'N'
                             AND NVL (pla.cancel_flag, 'N') = 'N'
                             AND NVL (plla.cancel_flag, 'N') = 'N'
                             AND prla.item_id = msib.inventory_item_id
                             AND prla.destination_organization_id =
                                 msib.organization_id
                             AND prla.category_id = mck.category_id
                             AND prla.requisition_line_id =
                                 rsl.requisition_line_id
                             AND prda.distribution_id = rsl.req_distribution_id
                             AND rsl.source_document_code = 'REQ'
                             AND rsl.shipment_header_id =
                                 rsh.shipment_header_id
                             AND rsh.receipt_source_code = 'INTERNAL ORDER'
                             AND rsl.shipment_line_status_code IN
                                     ('PARTIALLY RECEIVED', 'EXPECTED')
                             AND rsl.item_id = msib.inventory_item_id
                             AND rsl.to_organization_id = msib.organization_id
                             AND rsl.mmt_transaction_id = mmt.transaction_id
                             AND mmt.picking_line_id = wdd.delivery_detail_id
                             AND wdd.source_line_id = oola.line_id
                             -- AND prla.need_by_date BETWEEN pv_from_period_date AND pv_to_period_date
                             -- AND prla.need_by_date BETWEEN NVL (pv_from_promised_date, prla.need_by_date) AND NVL (pv_to_promised_date, prla.need_by_date)
                             -- AND expected_receipt_dt_fnc (rsh.creation_date, prla.need_by_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS'))
                             -- BETWEEN     NVL (pv_from_promised_date, TO_DATE('01-JAN-2000','DD-MON-YYYY'))
                             -- AND NVL (pv_to_promised_date, TO_DATE('31-DEC-2999','DD-MON-YYYY'))
                             -- AND NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'), TO_DATE('01-JAN-2000','DD-MON-YYYY')))
                             -- BETWEEN    NVL (pv_from_xf_date, NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'),TO_DATE('01-JAN-2000','DD-MON-YYYY'))))
                             -- AND NVL (pv_to_xf_date,NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'),TO_DATE('01-JAN-2000','DD-MON-YYYY'))))
                             -- Commented and Added as per CCR0009989
                             --                             AND expected_receipt_dt_fnc (rsh.creation_date, prla.need_by_date, NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'),pv_to_promised_date)))
                             --                              <= NVL (pv_to_promised_date, pv_to_period_date)
                             AND (rsh.expected_receipt_date + gn_delay_Intransit_days) <=
                                 NVL (pv_to_promised_date, pv_to_period_date)
                             -- End of Change as per CCR0009989
                             AND rsh.creation_date BETWEEN NVL (
                                                               pv_from_xf_date,
                                                               rsh.creation_date)
                                                       AND NVL (
                                                               pv_to_xf_date,
                                                               rsh.creation_date)
                             AND flv.lookup_code =
                                 prla.destination_organization_id
                             AND flv.lookup_type = 'XXD_PO_FORECAST_ORGS'
                             AND flv.language = 'US'
                             -- Begin Parameter Logic
                             -- AND flv.tag = 'IC'
                             -- AND flv.tag IN ('DI', 'IC')
                             AND (flv.tag IN ('DI', 'IC') AND (pv_po_model = 'All' OR pv_po_model = 'Non Direct'))
                             -- ALL - DI, IC
                             -- NOT DIRECT -- DI, IC
                             -- End Parameter Logic
                             AND flv.enabled_flag = 'Y'
                             AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                      SYSDATE - 1)
                                             AND NVL (flv.end_date_active,
                                                      SYSDATE + 1)
                             -- AND plla.ship_to_organization_id = NVL (pv_source_org, plla.ship_to_organization_id)
                             -- AND prla.source_organization_id = NVL (pv_source_org, prla.source_organization_id)
                             -- AND prla.destination_organization_id = NVL (pv_destination_org, prla.destination_organization_id)
                             -- AND prla.source_organization_id = DECODE (pv_source_org, NULL, prla.source_organization_id, pv_source_org)
                             -- AND prla.destination_organization_id = DECODE (pv_destination_org, NULL, prla.destination_organization_id, pv_destination_org)
                             -- AND prla.source_organization_id = NVL (pv_source_org, 129)
                             AND prla.source_organization_id IN
                                     (SELECT lookup_code
                                        FROM fnd_lookup_values
                                       WHERE     lookup_type =
                                                 'XXD_PO_FORECAST_ORGS'
                                             AND language = 'US'
                                             -- AND tag = 'VO'
                                             AND tag = 'DI'
                                             AND enabled_flag = 'Y'
                                             AND lookup_code =
                                                 NVL (
                                                     pv_source_org,
                                                     prla.source_organization_id)
                                             AND SYSDATE BETWEEN NVL (
                                                                     flv.start_date_active,
                                                                       SYSDATE
                                                                     - 1)
                                                             AND NVL (
                                                                     flv.end_date_active,
                                                                       SYSDATE
                                                                     + 1))
                             AND prla.destination_organization_id IN
                                     (SELECT lookup_code
                                        FROM fnd_lookup_values
                                       WHERE     lookup_type =
                                                 'XXD_PO_FORECAST_ORGS'
                                             AND language = 'US'
                                             AND tag = 'IC'
                                             AND enabled_flag = 'Y'
                                             AND lookup_code =
                                                 NVL (
                                                     pv_destination_org,
                                                     prla.destination_organization_id)
                                             AND SYSDATE BETWEEN NVL (
                                                                     flv.start_date_active,
                                                                       SYSDATE
                                                                     - 1)
                                                             AND NVL (
                                                                     flv.end_date_active,
                                                                       SYSDATE
                                                                     + 1))
                                /*UNION
              -- Interco ERD Incld Past Due
              SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY') run_date
                    -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                    ,'INTERCO' po_type
                    ,'ASN' subtype
                    ,prha.segment1 req_number
                    ,prha.requisition_header_id requisition_header_id
                    ,prla.requisition_line_id requisition_line_id
                    --,oola.line_id oe_line_id
                    ,NULL oe_line_id
                    ,pha.segment1 po_number
                    ,pha.po_header_id po_header_id
                    ,pla.po_line_id po_line_id
                    ,plla.line_location_id po_line_location_id
                    ,rsh.shipment_num shipment_number
                    ,rsh.shipment_header_id shipment_header_id
                    ,rsl.shipment_line_id shipment_line_id
                    ,pla.attribute1 brand
                    ,pla.attribute2 department
                    ,mck.concatenated_segments item_category
                    ,msib.segment1 item_sku
                    ,pv_from_period from_period_identifier
                    ,pv_to_period to_period_identifier
                    ,pv_from_period_date from_period_date
                    ,pv_to_period_date to_period_date
                    ,(SELECT ood.organization_name
                        FROM apps.org_organization_definitions ood
                       WHERE ood.organization_id = prla.source_organization_id) source_org
                    ,plla.attribute4 requested_xf_date
                    ,plla.attribute8 orig_confirmed_xf_date
                    ,plla.attribute5 confirmed_xf_date
                    ,rsh.creation_date asn_creation_date
                    ,NVL (plla.attribute5, plla.attribute4) xf_shipment_date
                    ,(SELECT ood.organization_name
                        FROM apps.org_organization_definitions ood
                       WHERE ood.organization_id = prla.destination_organization_id ) destination_org
                    ,prla.need_by_date need_by_date
                    ,plla.promised_date promised_date
                    ,rsh.expected_receipt_date expected_receipt_date
                    ,NULL promise_expected_receipt_date
                    ,NULL original_promise_date
                    ,NULL intransit_receipt_date
                    ,NULL orig_intransit_receipt_date
                    ,rsh.asn_type asn_type
                    ,NVL (pla.attribute11, pla.unit_price) fob_value
                    ,(rsl.quantity_shipped - rsl.quantity_received) quantity
                    ,plla.attribute10 ship_method
                    ,pha.currency_code po_currency
                    ,NULL fob_value_in_usd
                    ,'N' calculated_flag
                    ,'NEW' override_status
                    ,'EBS' source
                FROM po_requisition_headers_all prha
                    ,po_requisition_lines_all prla
                    ,po_req_distributions_all prda
                    ,oe_order_lines_all oola
                    ,po_headers_all pha
                    ,po_lines_all pla
                    ,po_line_locations_all plla
                    ,mtl_system_items_b msib
                    ,mtl_categories_kfv mck
                    ,rcv_shipment_headers rsh
                    ,rcv_shipment_lines rsl
                    ,mtl_material_transactions mmt
                    ,wsh_delivery_details wdd
                    ,fnd_lookup_values flv
               WHERE 1 = 1
                 AND prha.requisition_header_id = prla.requisition_header_id
                 AND prla.requisition_line_id = prda.requisition_line_id
                 AND prha.authorization_status NOT IN ('CANCELLED', 'INCOMPLETE', 'REJECTED')
                 AND NVL (prla.closed_code, 'OPEN') ! = 'FINALLY CLOSED'
                 AND prla.requisition_header_id = oola.source_document_id
                 AND prla.requisition_line_id = oola.source_document_line_id
                 AND NVL (prla.cancel_flag,'N') = 'N'
                 AND oola.source_type_code = 'INTERNAL'
                 AND oola.order_source_id = 10
                 AND oola.cancelled_flag = 'N'
                 AND oola.attribute16 = TO_CHAR (plla.line_location_id)
                 AND plla.po_line_id = pla.po_line_id
                 AND pla.po_header_id = pha.po_header_id
                 AND pha.attribute10 = 'STANDARD'
                 AND NVL (prla.cancel_flag, 'N') = 'N'
                 AND NVL (pla.cancel_flag, 'N') = 'N'
                 AND NVL (plla.cancel_flag, 'N') = 'N'
                 AND prla.item_id = msib.inventory_item_id
                 AND prla.destination_organization_id = msib.organization_id
                 AND prla.category_id = mck.category_id
                 AND prla.requisition_line_id = rsl.requisition_line_id
                 AND prda.distribution_id = rsl.req_distribution_id
                 AND rsl.source_document_code = 'REQ'
                 AND rsl.shipment_header_id = rsh.shipment_header_id
                 AND rsh.receipt_source_code = 'INTERNAL ORDER'
                 AND rsl.shipment_line_status_code IN ('PARTIALLY RECEIVED','EXPECTED')
                 AND rsl.item_id = msib.inventory_item_id
                 AND rsl.to_organization_id = msib.organization_id
                 AND rsl.mmt_transaction_id = mmt.transaction_id
                 AND mmt.picking_line_id = wdd.delivery_detail_id
                 AND wdd.source_line_id = oola.line_id
                 -- AND (rsh.expected_receipt_date >= pv_asn_from_promised_date AND rsh.expected_receipt_date < NVL (pv_from_promised_date, pv_from_period_date))
                 AND rsh.creation_date >= pv_from_period_date - 365
                 AND expected_receipt_dt_fnc (rsh.creation_date, prla.need_by_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS'))
                     < NVL (pv_from_promised_date, expected_receipt_dt_fnc (rsh.creation_date, prla.need_by_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS')))
                 AND flv.lookup_code = prla.destination_organization_id
                 AND flv.lookup_type = 'XXD_PO_FORECAST_ORGS'
                 AND flv.language = 'US'
-- Begin Parameter Logic
                 -- AND flv.tag = 'IC'
                 -- AND flv.tag IN ('DI', 'IC')
                 AND (flv.tag IN ('DI', 'IC') AND (pv_po_model = 'All' OR pv_po_model = 'Non Direct'))
                 -- ALL - DI, IC
                 -- NOT DIRECT -- DI, IC
-- End Parameter Logic
                 AND flv.enabled_flag = 'Y'
                 AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1) AND NVL (flv.end_date_active, SYSDATE + 1)
                 -- AND plla.ship_to_organization_id = NVL (pv_source_org, plla.ship_to_organization_id)
                 -- AND prla.destination_organization_id = NVL (pv_destination_org, prla.destination_organization_id)
                 -- AND prla.source_organization_id = DECODE (pv_source_org, NULL, prla.source_organization_id, pv_source_org))
                 -- AND prla.destination_organization_id = DECODE (pv_destination_org, NULL, prla.destination_organization_id, pv_destination_org)
                 -- AND prla.source_organization_id = NVL (pv_source_org, 129)
                 AND prla.source_organization_id IN (SELECT lookup_code
                                                       FROM fnd_lookup_values
                                                      WHERE lookup_type = 'XXD_PO_FORECAST_ORGS'
                                                        AND language = 'US'
                                                        -- AND tag = 'VO'
                                                        AND tag = 'DI'
                                                        AND enabled_flag = 'Y'
                                                        AND lookup_code = NVL (pv_source_org, prla.source_organization_id)
                                                        AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1) AND NVL (flv.end_date_active, SYSDATE + 1))
                 AND prla.destination_organization_id IN (SELECT lookup_code
                                                            FROM fnd_lookup_values
                                                           WHERE lookup_type = 'XXD_PO_FORECAST_ORGS'
                                                             AND language = 'US'
                                                             AND tag = 'IC'
                                                             AND enabled_flag = 'Y'
                                                             AND lookup_code = NVL (pv_destination_org, prla.destination_organization_id)
                                                             AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1) AND NVL (flv.end_date_active, SYSDATE + 1))*/
                      UNION
                      -- JP TQ OPEN PO'S
                      SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                                 run_date -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                         ,
                             'JAPAN_TQ'
                                 po_type,
                             'PO'
                                 subtype,
                             NULL
                                 req_number,
                             NULL
                                 requisition_header_id,
                             NULL
                                 requisition_line_id,
                             NULL
                                 oe_line_id,
                             pha.segment1
                                 po_number,
                             pha.po_header_id
                                 po_header_id,
                             pla.po_line_id
                                 po_line_id,
                             plla.line_location_id
                                 po_line_location_id,
                             NULL
                                 shipment_number,
                             NULL
                                 shipment_header_id,
                             NULL
                                 shipment_line_id,
                             pla.attribute1
                                 brand,
                             pla.attribute2
                                 department,
                             mck.concatenated_segments
                                 item_category,
                             msib.segment1
                                 item_sku,
                             pv_from_period
                                 from_period_identifier,
                             pv_to_period
                                 to_period_identifier,
                             pv_from_period_date
                                 from_period_date,
                             pv_to_period_date
                                 to_period_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     plla.ship_to_organization_id)
                                 source_org,
                             plla.attribute4
                                 requested_xf_date,
                             plla.attribute8
                                 orig_confirmed_xf_date,
                             plla.attribute5
                                 confirmed_xf_date,
                             NULL
                                 asn_creation_date,
                             NVL (plla.attribute5, plla.attribute4)
                                 xf_shipment_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     plla.ship_to_organization_id)
                                 destination_org,
                             NULL
                                 need_by_date,
                             plla.promised_date
                                 promised_date,
                             NULL
                                 expected_receipt_date,
                             NULL
                                 promise_expected_receipt_date,
                             NULL
                                 original_promise_date,
                             NULL
                                 intransit_receipt_date,
                             NULL
                                 orig_intransit_receipt_date,
                             NULL
                                 asn_type,
                             NVL (pla.attribute11, pla.unit_price)
                                 fob_value,
                               (plla.quantity - NVL (plla.quantity_cancelled, 0))
                             - NVL (plla.quantity_received, 0)
                                 quantity,
                             plla.attribute10
                                 ship_method,
                             pha.currency_code
                                 po_currency,
                             NULL
                                 fob_value_in_usd,
                             'N'
                                 calculated_flag,
                             'NEW'
                                 override_status,
                             'EBS'
                                 source
                        FROM ap_suppliers aps, fnd_lookup_values flv, po_headers_all pha,
                             po_lines_all pla, po_line_locations_all plla, mtl_system_items_b msib,
                             mtl_categories_kfv mck
                       WHERE     1 = 1
                             AND aps.vendor_id = flv.lookup_code
                             AND flv.lookup_type =
                                 'XXD_PO_TQ_PRICE_RULE_VENDORS'
                             AND flv.language = 'US'
                             AND flv.enabled_flag = 'Y'
                             AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                      SYSDATE - 1)
                                             AND NVL (flv.end_date_active,
                                                      SYSDATE + 1)
                             AND aps.vendor_id = pha.vendor_id
                             AND pha.po_header_id = pla.po_header_id
                             AND pla.po_line_id = plla.po_line_id
                             AND NVL (pha.closed_code, 'OPEN') = 'OPEN'
                             AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                             AND NVL (plla.closed_code, 'OPEN') IN
                                     ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                             AND pha.attribute10 = 'STANDARD'
                             AND NVL (pla.cancel_flag, 'N') = 'N'
                             AND NVL (plla.cancel_flag, 'N') = 'N'
                             AND pha.authorization_status NOT IN
                                     ('CANCELLED', 'INCOMPLETE')
                             AND pla.item_id = msib.inventory_item_id
                             AND pla.category_id = mck.category_id
                             AND plla.ship_to_organization_id =
                                 msib.organization_id
                             AND plla.ship_to_organization_id = 126
                             -- AND plla.promised_date BETWEEN pv_from_period_date AND pv_to_period_date
                             -- AND plla.promised_date BETWEEN NVL (pv_from_promised_date, plla.promised_date) AND NVL (pv_to_promised_date, plla.promised_date)
                             AND expected_receipt_dt_fnc (
                                     NVL (
                                         pv_from_promised_date,
                                         NVL (
                                             TO_DATE (plla.attribute5,
                                                      'YYYY/MM/DD HH24:MI:SS'),
                                             NVL (
                                                 TO_DATE (
                                                     plla.attribute4,
                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                 pv_to_period_date + 1))),
                                     plla.promised_date,
                                     NVL (
                                         TO_DATE (plla.attribute5,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                         NVL (
                                             TO_DATE (plla.attribute4,
                                                      'YYYY/MM/DD HH24:MI:SS'),
                                             pv_to_period_date))) BETWEEN NVL (
                                                                                pv_from_promised_date
                                                                              + (CASE
                                                                                     WHEN gn_delay_delivery_days <
                                                                                          0
                                                                                     THEN
                                                                                         gn_delay_delivery_days
                                                                                     ELSE
                                                                                         0
                                                                                 END),
                                                                              -- Added Case as per CCR0009989
                                                                              plla.promised_date)
                                                                      AND NVL (
                                                                              pv_to_promised_date,
                                                                              plla.promised_date)
                             AND plla.promised_date > pv_asn_from_promised_date
                             AND plla.promised_date <=
                                 NVL (pv_to_promised_date, plla.promised_date)
                             AND NVL (
                                     TO_DATE (plla.attribute5,
                                              'YYYY/MM/DD HH24:MI:SS'),
                                     NVL (
                                         TO_DATE (plla.attribute4,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                         TO_DATE ('01-JAN-2000', 'DD-MON-YYYY'))) BETWEEN NVL (
                                                                                              pv_from_xf_date,
                                                                                              NVL (
                                                                                                  TO_DATE (
                                                                                                      plla.attribute5,
                                                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                                                  NVL (
                                                                                                      TO_DATE (
                                                                                                          plla.attribute4,
                                                                                                          'YYYY/MM/DD HH24:MI:SS'),
                                                                                                      TO_DATE (
                                                                                                          '01-JAN-2000',
                                                                                                          'DD-MON-YYYY'))))
                                                                                      AND NVL (
                                                                                              pv_to_xf_date,
                                                                                              NVL (
                                                                                                  TO_DATE (
                                                                                                      plla.attribute5,
                                                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                                                  NVL (
                                                                                                      TO_DATE (
                                                                                                          plla.attribute4,
                                                                                                          'YYYY/MM/DD HH24:MI:SS'),
                                                                                                      TO_DATE (
                                                                                                          '01-JAN-2000',
                                                                                                          'DD-MON-YYYY'))))
                             -- Begin Parameter Logic
                             AND (pv_po_model = 'All' OR pv_po_model = 'Non Direct')
                             -- ALL
                             -- NOT DIRECT
                             -- End Parameter Logic
                             AND plla.ship_to_organization_id =
                                 NVL (pv_source_org,
                                      plla.ship_to_organization_id)
                             AND plla.ship_to_organization_id =
                                 NVL (pv_destination_org,
                                      plla.ship_to_organization_id)
                             AND NOT EXISTS
                                     (SELECT 1
                                        FROM rcv_shipment_lines rsl
                                       WHERE     1 = 1
                                             AND rsl.po_header_id =
                                                 pha.po_header_id
                                             AND rsl.po_line_id =
                                                 pla.po_line_id
                                             AND rsl.po_line_location_id =
                                                 plla.line_location_id
                                             AND rsl.item_id =
                                                 msib.inventory_item_id
                                             AND rsl.to_organization_id =
                                                 msib.organization_id
                                             AND rsl.shipment_line_status_code IN
                                                     ('PARTIALLY RECEIVED', 'EXPECTED', 'CANCELLED'))
                      UNION
                      SELECT run_date, po_type, subtype,
                             req_number, requisition_header_id, requisition_line_id,
                             oe_line_id, po_number, open_qty.po_header_id,
                             open_qty.po_line_id, po_line_location_id, shipment_number,
                             shipment_header_id, shipment_line_id, brand,
                             department, item_category, item_sku,
                             from_period_identifier, to_period_identifier, from_period_date,
                             to_period_date, source_org, requested_xf_date,
                             orig_confirmed_xf_date, confirmed_xf_date, asn_creation_date,
                             xf_shipment_date, destination_org, open_qty.need_by_date,
                             open_qty.promised_date, expected_receipt_date, promise_expected_receipt_date,
                             original_promise_date, intransit_receipt_date, orig_intransit_receipt_date,
                             asn_type, fob_value, (plla.quantity - NVL (plla.quantity_cancelled, 0)) - NVL (plla.quantity_received, 0) - open_qty.quantity quantity,
                             ship_method, po_currency, fob_value_in_usd,
                             calculated_flag, override_status, source
                        FROM (  SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                                           run_date -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                                   ,
                                       'JAPAN_TQ'
                                           po_type,
                                       'PO'
                                           subtype,
                                       NULL
                                           req_number,
                                       NULL
                                           requisition_header_id,
                                       NULL
                                           requisition_line_id,
                                       NULL
                                           oe_line_id,
                                       pha.segment1
                                           po_number,
                                       pha.po_header_id
                                           po_header_id,
                                       pla.po_line_id
                                           po_line_id,
                                       plla.line_location_id
                                           po_line_location_id,
                                       NULL
                                           shipment_number,
                                       NULL
                                           shipment_header_id,
                                       NULL
                                           shipment_line_id,
                                       pla.attribute1
                                           brand,
                                       pla.attribute2
                                           department,
                                       mck.concatenated_segments
                                           item_category,
                                       msib.segment1
                                           item_sku,
                                       pv_from_period
                                           from_period_identifier,
                                       pv_to_period
                                           to_period_identifier,
                                       pv_from_period_date
                                           from_period_date,
                                       pv_to_period_date
                                           to_period_date,
                                       (SELECT ood.organization_name
                                          FROM apps.org_organization_definitions ood
                                         WHERE ood.organization_id =
                                               plla.ship_to_organization_id)
                                           source_org,
                                       plla.attribute4
                                           requested_xf_date,
                                       plla.attribute8
                                           orig_confirmed_xf_date,
                                       plla.attribute5
                                           confirmed_xf_date,
                                       NULL
                                           asn_creation_date,
                                       NVL (plla.attribute5, plla.attribute4)
                                           xf_shipment_date,
                                       (SELECT ood.organization_name
                                          FROM apps.org_organization_definitions ood
                                         WHERE ood.organization_id =
                                               plla.ship_to_organization_id)
                                           destination_org,
                                       NULL
                                           need_by_date,
                                       plla.promised_date
                                           promised_date,
                                       NULL
                                           expected_receipt_date,
                                       NULL
                                           promise_expected_receipt_date,
                                       NULL
                                           original_promise_date,
                                       NULL
                                           intransit_receipt_date,
                                       NULL
                                           orig_intransit_receipt_date,
                                       NULL
                                           asn_type,
                                       NVL (pla.attribute11, pla.unit_price)
                                           fob_value --,(plla.quantity - NVL (plla.quantity_cancelled,0)) - NVL (plla.quantity_received,0) quantity
                                                    ,
                                       SUM (
                                           rsl.quantity_shipped - rsl.quantity_received)
                                           quantity,
                                       plla.attribute10
                                           ship_method,
                                       pha.currency_code
                                           po_currency,
                                       NULL
                                           fob_value_in_usd,
                                       'N'
                                           calculated_flag,
                                       'NEW'
                                           override_status,
                                       'EBS'
                                           source
                                  FROM ap_suppliers aps, fnd_lookup_values flv, po_headers_all pha,
                                       po_lines_all pla, po_line_locations_all plla, mtl_system_items_b msib,
                                       mtl_categories_kfv mck, rcv_shipment_headers rsh, rcv_shipment_lines rsl
                                 WHERE     1 = 1
                                       AND aps.vendor_id = flv.lookup_code
                                       AND flv.lookup_type =
                                           'XXD_PO_TQ_PRICE_RULE_VENDORS'
                                       AND flv.language = 'US'
                                       AND flv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               flv.start_date_active,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               flv.end_date_active,
                                                               SYSDATE + 1)
                                       AND aps.vendor_id = pha.vendor_id
                                       AND pha.po_header_id = pla.po_header_id
                                       AND pla.po_line_id = plla.po_line_id
                                       AND pla.item_id = msib.inventory_item_id
                                       AND pla.category_id = mck.category_id
                                       AND plla.ship_to_organization_id =
                                           msib.organization_id
                                       AND NVL (pha.closed_code, 'OPEN') = 'OPEN'
                                       AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                                       AND NVL (plla.closed_code, 'OPEN') IN
                                               ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                                       AND pha.attribute10 = 'STANDARD'
                                       AND NVL (pla.cancel_flag, 'N') = 'N'
                                       AND NVL (plla.cancel_flag, 'N') = 'N'
                                       AND pha.authorization_status NOT IN
                                               ('CANCELLED', 'INCOMPLETE')
                                       AND rsh.shipment_header_id =
                                           rsl.shipment_header_id
                                       AND rsh.receipt_source_code = 'VENDOR'
                                       AND rsl.from_organization_id IS NULL
                                       AND rsl.to_organization_id = 126
                                       AND rsl.po_header_id = pha.po_header_id
                                       AND rsl.po_line_id = pla.po_line_id
                                       AND rsl.po_line_location_id =
                                           plla.line_location_id
                                       AND rsl.source_document_code = 'PO'
                                       AND rsl.shipment_line_status_code IN
                                               ('PARTIALLY RECEIVED', 'EXPECTED')
                                       AND rsl.item_id = msib.inventory_item_id
                                       AND rsl.to_organization_id =
                                           msib.organization_id
                                       -- AND plla.promised_date BETWEEN pv_from_period_date AND pv_to_period_date
                                       -- AND plla.promised_date BETWEEN NVL (pv_from_promised_date, plla.promised_date) AND NVL (pv_to_promised_date, plla.promised_date)
                                       AND expected_receipt_dt_fnc (
                                               NVL (
                                                   pv_from_promised_date,
                                                   NVL (
                                                       TO_DATE (
                                                           plla.attribute5,
                                                           'YYYY/MM/DD HH24:MI:SS'),
                                                       NVL (
                                                           TO_DATE (
                                                               plla.attribute4,
                                                               'YYYY/MM/DD HH24:MI:SS'),
                                                           pv_to_period_date + 1))),
                                               plla.promised_date,
                                               NVL (
                                                   TO_DATE (
                                                       plla.attribute5,
                                                       'YYYY/MM/DD HH24:MI:SS'),
                                                   NVL (
                                                       TO_DATE (
                                                           plla.attribute4,
                                                           'YYYY/MM/DD HH24:MI:SS'),
                                                       pv_to_period_date))) BETWEEN NVL (
                                                                                          pv_from_promised_date
                                                                                        + (CASE
                                                                                               WHEN gn_delay_delivery_days <
                                                                                                    0
                                                                                               THEN
                                                                                                   gn_delay_delivery_days
                                                                                               ELSE
                                                                                                   0
                                                                                           END),
                                                                                        -- Added Case as per CCR0009989
                                                                                        plla.promised_date)
                                                                                AND NVL (
                                                                                        pv_to_promised_date,
                                                                                        plla.promised_date)
                                       AND plla.promised_date >
                                           pv_asn_from_promised_date
                                       AND plla.promised_date <=
                                           NVL (pv_to_promised_date,
                                                plla.promised_date)
                                       AND NVL (
                                               TO_DATE (plla.attribute5,
                                                        'YYYY/MM/DD HH24:MI:SS'),
                                               NVL (
                                                   TO_DATE (
                                                       plla.attribute4,
                                                       'YYYY/MM/DD HH24:MI:SS'),
                                                   TO_DATE ('01-JAN-2000',
                                                            'DD-MON-YYYY'))) BETWEEN NVL (
                                                                                         pv_from_xf_date,
                                                                                         NVL (
                                                                                             TO_DATE (
                                                                                                 plla.attribute5,
                                                                                                 'YYYY/MM/DD HH24:MI:SS'),
                                                                                             NVL (
                                                                                                 TO_DATE (
                                                                                                     plla.attribute4,
                                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                                 TO_DATE (
                                                                                                     '01-JAN-2000',
                                                                                                     'DD-MON-YYYY'))))
                                                                                 AND NVL (
                                                                                         pv_to_xf_date,
                                                                                         NVL (
                                                                                             TO_DATE (
                                                                                                 plla.attribute5,
                                                                                                 'YYYY/MM/DD HH24:MI:SS'),
                                                                                             NVL (
                                                                                                 TO_DATE (
                                                                                                     plla.attribute4,
                                                                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                                                                 TO_DATE (
                                                                                                     '01-JAN-2000',
                                                                                                     'DD-MON-YYYY'))))
                                       -- Begin Parameter Logic
                                       AND (pv_po_model = 'All' OR pv_po_model = 'Non Direct')
                                       -- ALL
                                       -- NOT DIRECT
                                       -- End Parameter Logic
                                       AND plla.ship_to_organization_id =
                                           NVL (pv_source_org,
                                                plla.ship_to_organization_id)
                                       AND plla.ship_to_organization_id =
                                           NVL (pv_destination_org,
                                                plla.ship_to_organization_id)
                              GROUP BY TO_CHAR (SYSDATE, 'DD-MON-YYYY'), xxd_po_get_po_type (pha.po_header_id), 'PO',
                                       pha.segment1, pha.po_header_id, pla.po_line_id,
                                       plla.line_location_id, pla.attribute1, pla.attribute2,
                                       mck.concatenated_segments, msib.segment1, pv_from_period,
                                       pv_to_period, pv_from_period_date, pv_to_period_date,
                                       plla.attribute4, plla.attribute8, plla.attribute5,
                                       NVL (plla.attribute5, plla.attribute4), plla.ship_to_organization_id, plla.promised_date,
                                       NVL (pla.attribute11, pla.unit_price), plla.attribute10, pha.currency_code,
                                       'N', 'NEW', 'EBS') open_qty,
                             po_line_locations_all plla
                       WHERE     open_qty.po_line_location_id =
                                 plla.line_location_id
                             AND   (plla.quantity - NVL (plla.quantity_cancelled, 0))
                                 - NVL (plla.quantity_received, 0)
                                 - open_qty.quantity >
                                 0
                      UNION
                      -- JP TQ OPEN ASN'S
                      SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                                 run_date -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                         ,
                             'JAPAN_TQ'
                                 po_type,
                             'ASN'
                                 subtype,
                             NULL
                                 req_number,
                             NULL
                                 requisition_header_id,
                             NULL
                                 requisition_line_id,
                             NULL
                                 oe_line_id,
                             pha.segment1
                                 po_number,
                             pha.po_header_id
                                 po_header_id,
                             pla.po_line_id
                                 po_line_id,
                             plla.line_location_id
                                 po_line_location_id,
                             rsh.shipment_num
                                 shipment_number,
                             rsh.shipment_header_id
                                 shipment_header_id,
                             rsl.shipment_line_id
                                 shipment_line_id,
                             pla.attribute1
                                 brand,
                             pla.attribute2
                                 department,
                             mck.concatenated_segments
                                 item_category,
                             msib.segment1
                                 item_sku,
                             pv_from_period
                                 from_period_identifier,
                             pv_to_period
                                 to_period_identifier,
                             pv_from_period_date
                                 from_period_date,
                             pv_to_period_date
                                 to_period_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     plla.ship_to_organization_id)
                                 source_org,
                             plla.attribute4
                                 requested_xf_date,
                             plla.attribute8
                                 orig_confirmed_xf_date,
                             plla.attribute5
                                 confirmed_xf_date,
                             rsh.creation_date
                                 asn_creation_date,
                             NVL (plla.attribute5, plla.attribute4)
                                 xf_shipment_date,
                             (SELECT ood.organization_name
                                FROM apps.org_organization_definitions ood
                               WHERE ood.organization_id =
                                     plla.ship_to_organization_id)
                                 destination_org,
                             NULL
                                 need_by_date,
                             plla.promised_date
                                 promised_date,
                             rsh.expected_receipt_date
                                 expected_receipt_date,
                             NULL
                                 promise_expected_receipt_date,
                             NULL
                                 original_promise_date,
                             NULL
                                 intransit_receipt_date,
                             NULL
                                 orig_intransit_receipt_date,
                             rsh.asn_type
                                 asn_type,
                             NVL (pla.attribute11, pla.unit_price)
                                 fob_value --,(plla.quantity - NVL (plla.quantity_cancelled,0)) - NVL (plla.quantity_received,0) quantity
                                          ,
                             (rsl.quantity_shipped - rsl.quantity_received)
                                 quantity,
                             plla.attribute10
                                 ship_method,
                             pha.currency_code
                                 po_currency,
                             NULL
                                 fob_value_in_usd,
                             'N'
                                 calculated_flag,
                             'NEW'
                                 override_status,
                             'EBS'
                                 source
                        FROM ap_suppliers aps, fnd_lookup_values flv, po_headers_all pha,
                             po_lines_all pla, po_line_locations_all plla, mtl_system_items_b msib,
                             mtl_categories_kfv mck, rcv_shipment_headers rsh, rcv_shipment_lines rsl
                       WHERE     1 = 1
                             AND aps.vendor_id = flv.lookup_code
                             AND flv.lookup_type =
                                 'XXD_PO_TQ_PRICE_RULE_VENDORS'
                             AND flv.language = 'US'
                             AND flv.enabled_flag = 'Y'
                             AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                      SYSDATE - 1)
                                             AND NVL (flv.end_date_active,
                                                      SYSDATE + 1)
                             AND aps.vendor_id = pha.vendor_id
                             AND pha.po_header_id = pla.po_header_id
                             AND pla.po_line_id = plla.po_line_id
                             AND pla.item_id = msib.inventory_item_id
                             AND pla.category_id = mck.category_id
                             AND plla.ship_to_organization_id =
                                 msib.organization_id
                             AND NVL (pha.closed_code, 'OPEN') = 'OPEN'
                             AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                             AND NVL (plla.closed_code, 'OPEN') IN
                                     ('OPEN', 'CLOSED FOR INVOICE', 'CLOSED FOR RECEIVING')
                             AND pha.attribute10 = 'STANDARD'
                             AND NVL (pla.cancel_flag, 'N') = 'N'
                             AND NVL (plla.cancel_flag, 'N') = 'N'
                             AND pha.authorization_status NOT IN
                                     ('CANCELLED', 'INCOMPLETE')
                             AND rsh.shipment_header_id =
                                 rsl.shipment_header_id
                             AND rsh.receipt_source_code = 'VENDOR'
                             AND rsl.from_organization_id IS NULL
                             AND rsl.to_organization_id = 126
                             AND rsl.po_header_id = pha.po_header_id
                             AND rsl.po_line_id = pla.po_line_id
                             AND rsl.po_line_location_id =
                                 plla.line_location_id
                             AND rsl.source_document_code = 'PO'
                             AND rsl.shipment_line_status_code IN
                                     ('PARTIALLY RECEIVED', 'EXPECTED')
                             AND rsl.item_id = msib.inventory_item_id
                             AND rsl.to_organization_id = msib.organization_id
                             -- AND plla.promised_date BETWEEN pv_from_period_date AND pv_to_period_date
                             -- AND plla.promised_date BETWEEN NVL (pv_from_promised_date, plla.promised_date) AND NVL (pv_to_promised_date, plla.promised_date)
                             -- AND expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS'))
                             -- BETWEEN     NVL (pv_from_promised_date, expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS')))
                             -- AND NVL (pv_to_promised_date, expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS')))
                             -- AND NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'), TO_DATE('01-JAN-2000','DD-MON-YYYY')))
                             -- BETWEEN    NVL (pv_from_xf_date, NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'),TO_DATE('01-JAN-2000','DD-MON-YYYY'))))
                             -- AND NVL (pv_to_xf_date,NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'),TO_DATE('01-JAN-2000','DD-MON-YYYY'))))
                             -- Start of Change for CCR0009989
                             -- AND expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, NVL (TO_DATE (plla.attribute5,'YYYY/MM/DD HH24:MI:SS'), NVL (TO_DATE (plla.attribute4,'YYYY/MM/DD HH24:MI:SS'),pv_to_promised_date)))
                             -- <= NVL (pv_to_promised_date, pv_to_period_date)
                             AND (rsh.expected_receipt_date + gn_delay_Intransit_days) <=
                                 NVL (pv_to_promised_date, pv_to_period_date)
                             -- End of Change for CCR0009989
                             AND rsh.creation_date BETWEEN NVL (
                                                               pv_from_xf_date,
                                                               rsh.creation_date)
                                                       AND NVL (
                                                               pv_to_xf_date,
                                                               rsh.creation_date)
                             -- Begin Parameter Logic
                             AND (pv_po_model = 'All' OR pv_po_model = 'Non Direct')
                             -- ALL
                             -- NOT DIRECT
                             -- End Parameter Logic
                             AND plla.ship_to_organization_id =
                                 NVL (pv_source_org,
                                      plla.ship_to_organization_id)
                             AND plla.ship_to_organization_id =
                                 NVL (pv_destination_org,
                                      plla.ship_to_organization_id) /*UNION
                                                  -- JP TQ ERD Incl Due Days
                                                  SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY') run_date
                                                        -- ,xxd_po_get_po_type (pha.po_header_id) po_type
                                                        ,'JAPAN_TQ' po_type
                                                        ,'ASN' subtype
                                                        ,NULL req_number
                                                        ,NULL requisition_header_id
                                                        ,NULL requisition_line_id
                                                        ,NULL oe_line_id
                                                        ,pha.segment1 po_number
                                                        ,pha.po_header_id po_header_id
                                                        ,pla.po_line_id po_line_id
                                                        ,plla.line_location_id po_line_location_id
                                                        ,rsh.shipment_num shipment_number
                                                        ,rsh.shipment_header_id shipment_header_id
                                                        ,rsl.shipment_line_id shipment_line_id
                                                        ,pla.attribute1 brand
                                                        ,pla.attribute2 department
                                                        ,mck.concatenated_segments item_category
                                                        ,msib.segment1 item_sku
                                                        ,pv_from_period from_period_identifier
                                                        ,pv_to_period to_period_identifier
                                                        ,pv_from_period_date from_period_date
                                                        ,pv_to_period_date to_period_date
                                                        ,(SELECT ood.organization_name
                                                            FROM apps.org_organization_definitions ood
                                                           WHERE ood.organization_id = plla.ship_to_organization_id) source_org
                                                        ,plla.attribute4 requested_xf_date
                                                        ,plla.attribute8 orig_confirmed_xf_date
                                                        ,plla.attribute5 confirmed_xf_date
                                                        ,rsh.creation_date asn_creation_date
                                                        ,NVL(plla.attribute5, plla.attribute4) xf_shipment_date
                                                        ,(SELECT ood.organization_name
                                                            FROM apps.org_organization_definitions ood
                                                           WHERE ood.organization_id = plla.ship_to_organization_id) destination_org
                                                        ,NULL need_by_date
                                                        ,plla.promised_date promised_date
                                                        ,rsh.expected_receipt_date expected_receipt_date
                                                        ,NULL promise_expected_receipt_date
                                                        ,NULL original_promise_date
                                                        ,NULL intransit_receipt_date
                                                        ,NULL orig_intransit_receipt_date
                                                        ,rsh.asn_type asn_type
                                                        ,NVL(pla.attribute11, pla.unit_price) fob_value
                                                        --,(plla.quantity - NVL (plla.quantity_cancelled,0)) - NVL (plla.quantity_received,0) quantity
                                                        ,(rsl.quantity_shipped - rsl.quantity_received) quantity
                                                        ,plla.attribute10 ship_method
                                                        ,pha.currency_code po_currency
                                                        ,NULL fob_value_in_usd
                                                        ,'N' calculated_flag
                                                        ,'NEW' override_status
                                                        ,'EBS' source
                                                    FROM ap_suppliers aps
                                                        ,fnd_lookup_values flv
                                                        ,po_headers_all pha
                                                        ,po_lines_all pla
                                                        ,po_line_locations_all plla
                                                        ,mtl_system_items_b msib
                                                        ,mtl_categories_kfv mck
                                                        ,rcv_shipment_headers rsh
                                                        ,rcv_shipment_lines rsl
                                                   WHERE 1 = 1
                                                     AND aps.vendor_id = flv.lookup_code
                                                     AND flv.lookup_type = 'XXD_PO_TQ_PRICE_RULE_VENDORS'
                                                     AND flv.language = 'US'
                                                     AND flv.enabled_flag = 'Y'
                                                     AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE - 1) AND NVL (flv.end_date_active, SYSDATE + 1)
                                                     AND aps.vendor_id = pha.vendor_id
                                                     AND pha.po_header_id = pla.po_header_id
                                                     AND pla.po_line_id = plla.po_line_id
                                                     AND pla.item_id = msib.inventory_item_id
                                                     AND pla.category_id = mck.category_id
                                                     AND plla.ship_to_organization_id = msib.organization_id
                                                     AND NVL (pha.closed_code, 'OPEN') = 'OPEN'
                                                     AND NVL (pla.closed_code, 'OPEN') = 'OPEN'
                                                     AND NVL (plla.closed_code,'OPEN') IN ('OPEN','CLOSED FOR INVOICE','CLOSED FOR RECEIVING')
                                                     AND pha.attribute10 = 'STANDARD'
                                                     AND NVL (pla.cancel_flag, 'N') = 'N'
                                                     AND NVL (plla.cancel_flag, 'N') = 'N'
                                                     AND pha.authorization_status NOT IN ('CANCELLED', 'INCOMPLETE')
                                                     AND rsh.shipment_header_id = rsl.shipment_header_id
                                                     AND rsh.receipt_source_code = 'VENDOR'
                                                     AND rsl.from_organization_id IS NULL
                                                     AND rsl.to_organization_id = 126
                                                     AND rsl.po_header_id = pha.po_header_id
                                                     AND rsl.po_line_id = pla.po_line_id
                                                     AND rsl.po_line_location_id = plla.line_location_id
                                                     AND rsl.source_document_code = 'PO'
                                                     AND rsl.shipment_line_status_code IN ('PARTIALLY RECEIVED','EXPECTED')
                                                     AND rsl.item_id = msib.inventory_item_id
                                                     AND rsl.to_organization_id = msib.organization_id
                                                     -- AND (rsh.expected_receipt_date >= pv_asn_from_promised_date AND rsh.expected_receipt_date < NVL (pv_from_promised_date, pv_from_period_date))
                                                     AND rsh.creation_date >= pv_from_period_date - 365
                                                     AND expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS'))
                                                         < NVL (pv_from_promised_date, expected_receipt_dt_fnc (rsh.creation_date, plla.promised_date, TO_DATE (plla.attribute5,'RRRR/MM/DD HH24:MI:SS')))
                                    -- Begin Parameter Logic
                                                     AND (pv_po_model = 'All' OR pv_po_model = 'Non Direct')
                                                     -- ALL
                                                     -- NOT DIRECT
                                    -- End Parameter Logic
                                                     AND plla.ship_to_organization_id = NVL (pv_source_org, plla.ship_to_organization_id)
                                                     AND plla.ship_to_organization_id = NVL (pv_destination_org, plla.ship_to_organization_id)*/
                                                                   )
               WHERE quantity > 0
            ORDER BY po_header_id, po_line_id, po_line_location_id;

        TYPE xxd_po_rec_type IS TABLE OF get_po_details_cur%ROWTYPE;

        v_po_rec                    xxd_po_rec_type := xxd_po_rec_type ();

        CURSOR rev_brand_cur IS
            SELECT DISTINCT brand
              FROM xxdo.xxd_po_proj_fc_rev_stg_t
             WHERE request_id = gn_request_id;

        CURSOR rev_data_cur (pv_brand VARCHAR2)
        IS
              SELECT brand, department, item_category,
                     item_sku, from_period_identifier, to_period_identifier,
                     source_org, requested_xf_date, orig_confirmed_xf_date,
                     confirmed_xf_date, asn_creation_date, xf_shipment_date -- Added
                                                                           ,
                     promised_date, expected_receipt_date, original_promise_date,
                     intransit_receipt_date, orig_intransit_receipt_date -- Added
                                                                        , destination_org,
                     promise_expected_receipt_date   -- ,original_promise_date
                                                  -- ,intransit_receipt_date
                                                  -- ,orig_intransit_receipt_date
                                                  , SUM (fob_value) fob_value, SUM (quantity) quantity,
                     ship_method, po_currency, SUM (fob_value_in_usd) fob_value_in_usd,
                     calculated_flag, override_status, source
                FROM xxdo.xxd_po_proj_fc_rev_stg_t
               WHERE 1 = 1 AND request_id = gn_request_id AND brand = pv_brand
            GROUP BY brand, department, item_category,
                     item_sku, from_period_identifier, to_period_identifier,
                     source_org, requested_xf_date, orig_confirmed_xf_date,
                     confirmed_xf_date, asn_creation_date, xf_shipment_date,
                     destination_org                                  -- Added
                                    , promised_date, expected_receipt_date,
                     original_promise_date, intransit_receipt_date, orig_intransit_receipt_date -- Added
                                                                                               ,
                     promise_expected_receipt_date   -- ,original_promise_date
                                                  -- ,intransit_receipt_date
                                                  -- ,orig_intransit_receipt_date
                                                                  --,fob_value
                     , ship_method, po_currency            --,fob_value_in_usd
                                               ,
                     calculated_flag, override_status, source;

        rev_output_row              rev_data_cur%ROWTYPE;

        CURSOR rep_brand_cur (pv_from_promised_date DATE, pv_to_promised_date DATE, pv_source_org VARCHAR2
                              , pv_destination_org VARCHAR2)
        IS
            SELECT DISTINCT brand
              FROM xxdo.xxd_po_proj_forecast_stg_t
             WHERE     (promise_expected_receipt_date BETWEEN pv_from_promised_date AND pv_to_promised_date OR original_promise_date BETWEEN pv_from_promised_date AND pv_to_promised_date)
                   AND source_org = NVL (pv_source_org, source_org)
                   AND destination_org =
                       NVL (pv_destination_org, destination_org);

        CURSOR rep_data_cur (pv_from_promised_date   DATE,
                             pv_to_promised_date     DATE,
                             pv_source_org           VARCHAR2,
                             pv_destination_org      VARCHAR2,
                             pv_brand                VARCHAR2)
        IS
              SELECT brand, department, item_category,
                     item_sku, from_period_identifier, to_period_identifier,
                     source_org, requested_xf_date, orig_confirmed_xf_date,
                     confirmed_xf_date, asn_creation_date, xf_shipment_date,
                     destination_org                                  -- Added
                                    , promised_date, expected_receipt_date,
                     original_promise_date, intransit_receipt_date, orig_intransit_receipt_date -- Added
                                                                                               ,
                     promise_expected_receipt_date   -- ,original_promise_date
                                                  -- ,intransit_receipt_date
                                                  -- ,orig_intransit_receipt_date
                                                  , SUM (fob_value) fob_value, SUM (quantity) quantity,
                     ship_method, po_currency, SUM (fob_value_in_usd) fob_value_in_usd,
                     calculated_flag, override_status, source
                FROM xxdo.xxd_po_proj_forecast_stg_t
               WHERE     (promise_expected_receipt_date BETWEEN pv_from_promised_date AND pv_to_promised_date OR original_promise_date BETWEEN pv_from_promised_date AND pv_to_promised_date)
                     AND source_org = NVL (pv_source_org, source_org)
                     AND destination_org =
                         NVL (pv_destination_org, destination_org)
                     AND brand = pv_brand
            GROUP BY brand, department, item_category,
                     item_sku, from_period_identifier, to_period_identifier,
                     source_org, requested_xf_date, orig_confirmed_xf_date,
                     confirmed_xf_date, asn_creation_date, xf_shipment_date -- Added
                                                                           ,
                     promised_date, expected_receipt_date, original_promise_date,
                     intransit_receipt_date, orig_intransit_receipt_date -- Added
                                                                        , destination_org,
                     promise_expected_receipt_date   -- ,original_promise_date
                                                  -- ,intransit_receipt_date
                                                  -- ,orig_intransit_receipt_date
                                                                  --,fob_value
                     , ship_method, po_currency            --,fob_value_in_usd
                                               ,
                     calculated_flag, override_status, source;

        rep_output_row              rep_data_cur%ROWTYPE;

        CURSOR dest_org_cur IS
            SELECT lookup_code organization_id
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_PO_FORECAST_ORGS'
                   AND language = 'US'
                   AND enabled_flag = 'Y'
                   AND lookup_code = NVL (pv_source_org, lookup_code)
                   AND lookup_code = NVL (pv_destination_org, lookup_code)
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND meaning <> 'ME2';

           /*SELECT organization_id
 FROM apps.org_organization_definitions
WHERE organization_name = IN (SELECT DISTINCT destination_org
                              FROM xxdo.xxd_po_proj_forecast_stg_t
                             WHERE 1 = 1
                               AND request_id = gn_request_id);*/

        CURSOR ic_org_cur IS
            SELECT lookup_code organization_id
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXD_PO_FORECAST_ORGS'
                   AND language = 'US'
                   AND enabled_flag = 'Y'
                   AND lookup_code = NVL (pv_destination_org, lookup_code)
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND meaning <> 'ME2'
                   AND tag = 'IC';


        lv_from_period_date         DATE;
        lv_to_period_date           DATE;
        lv_from_promised_date       DATE;
        lv_to_promised_date         DATE;
        lv_asn_from_promised_date   DATE;
        lv_asn_to_promised_date     DATE;
        lv_from_xf_date             DATE;
        lv_to_xf_date               DATE;
        lv_asn_from_xf_date         DATE;
        lv_asn_to_xf_date           DATE;
        lv_error_code               VARCHAR2 (4000) := NULL;
        ln_error_num                NUMBER;
        lv_error_msg                VARCHAR2 (4000) := NULL;
        lv_calculated_flag          VARCHAR2 (1);
        lv_exists                   VARCHAR2 (1);
        lv_conversion_rate          NUMBER;
        v_report_date               VARCHAR2 (100);
        lv_src_org                  VARCHAR2 (100);
        lv_dest_org                 VARCHAR2 (100);
        lv_destination_org          VARCHAR2 (1000);
        lv_source_org               VARCHAR2 (1000);
        ln_from_period_num          NUMBER;
        ln_to_period_num            NUMBER;
        ln_from_period_year         NUMBER;
        ln_to_period_year           NUMBER;
        lv_file_path                VARCHAR2 (100);
        ln_req_id                   NUMBER;
        ln_layout                   BOOLEAN;
        lv_vo_org                   VARCHAR2 (100);
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Report Process starts...'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        BEGIN
            SELECT directory_path
              INTO lv_file_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_PO_FORECAST_REP_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_file_path   := NULL;
        END;

        apps.fnd_file.put_line (apps.fnd_file.LOG, '');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Deckers PO Projected Supply Forecast Report Path:-'
            || lv_file_path);
        apps.fnd_file.put_line (apps.fnd_file.LOG, '');
        apps.fnd_file.put_line (apps.fnd_file.LOG, '');
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Run Mode is :' || pv_run_mode);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'PO Model is :' || pv_po_model);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'OVERRIDE is :' || pv_override);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Starting Period is :' || pv_from_period);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Ending Period is :' || pv_to_period);
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Include Past Due Days is :' || pn_incld_past_due_days);
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Delay Delivery Days is :' || pn_delay_delivery_days);
        -- Added as per CCR0009989
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Delay Intransit Days is :' || pn_delay_intransit_days);
        -- End of Change CCR0009989
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Starting Promised Date is :' || pv_from_promised_date);
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Ending Promised Date is :' || pv_to_promised_date);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Starting XF Date is :' || pv_from_xf_date);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Ending XF Date is :' || pv_to_xf_date);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Source Organization is :' || pv_source_org);
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Destination Organization is :' || pv_destination_org);
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Rate Date is :'
            || TO_DATE (pv_rate_date, 'RRRR/MM/DD HH24:MI:SS'));
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Rate Type is :' || pv_rate_type);
        apps.fnd_file.put_line (apps.fnd_file.LOG, '');

        gn_delay_delivery_days    := NVL (pn_delay_delivery_days, 0);

        gn_delay_Intransit_days   := NVL (pn_delay_Intransit_days, 0); -- Added as per CCR0009989


        fnd_file.put_line (fnd_file.LOG, 'Derive Period Start Date');

        BEGIN
            SELECT start_date
              INTO lv_from_period_date
              FROM gl_periods
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND period_name = pv_from_period;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_from_period_date   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       SQLERRM
                    || ' Failed to Retrive Period Start Date for the Period: '
                    || pv_from_period);
        END;

        BEGIN
            fnd_file.put_line (fnd_file.LOG, 'Derive Period End Date');

            SELECT end_date
              INTO lv_to_period_date
              FROM gl_periods
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND period_name = pv_to_period;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_to_period_date   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       SQLERRM
                    || ' Failed to Retrive Period Start Date for the Period: '
                    || pv_to_period);
        END;

        IF pv_run_mode = 'Review' OR pv_run_mode = 'Insert'
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Derive Report Dates Based on the Given Parameters');

            IF pv_from_promised_date IS NULL
            THEN
                lv_from_promised_date   := lv_from_period_date;
                lv_asn_from_promised_date   :=
                    lv_from_period_date - pn_incld_past_due_days;
            ELSIF pv_from_promised_date IS NOT NULL
            THEN
                lv_from_promised_date   := pv_from_promised_date;
                lv_asn_from_promised_date   :=
                    pv_from_promised_date - pn_incld_past_due_days;
            END IF;

            IF pv_to_promised_date IS NULL
            THEN
                lv_to_promised_date   := lv_to_period_date;
            -- lv_asn_to_promised_date := lv_to_period_date - pn_incld_past_due_days;
            ELSIF pv_to_promised_date IS NOT NULL
            THEN
                lv_to_promised_date   := pv_to_promised_date;
            -- lv_asn_to_promised_date := pv_to_promised_date - pn_incld_past_due_days;
            END IF;

            IF pv_from_xf_date IS NULL
            THEN
                lv_from_xf_date   := pv_from_xf_date;
                lv_asn_from_xf_date   :=
                    lv_from_period_date - pn_incld_past_due_days;
            ELSIF pv_from_xf_date IS NOT NULL
            THEN
                lv_from_xf_date   := pv_from_xf_date;
                lv_asn_from_xf_date   :=
                    pv_from_xf_date - pn_incld_past_due_days;
            END IF;

            IF pv_to_xf_date IS NULL
            THEN
                lv_to_xf_date   := pv_to_xf_date;
            -- lv_asn_to_xf_date := sysdate - pn_incld_past_due_days;
            ELSIF pv_to_xf_date IS NOT NULL
            THEN
                lv_to_xf_date   := pv_to_xf_date;
            -- lv_asn_to_xf_date := pv_to_xf_date - pn_incld_past_due_days;
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'From Period: ' || pv_from_period);
            fnd_file.put_line (fnd_file.LOG, 'To Period: ' || pv_to_period);
            fnd_file.put_line (fnd_file.LOG,
                               'From Period Date: ' || lv_from_period_date);
            fnd_file.put_line (fnd_file.LOG,
                               'To Period Date: ' || lv_to_period_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'From Promised Date : ' || pv_from_promised_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'From Promised Date:(if null) ' || lv_from_promised_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'From ASN Promised Date : ' || lv_asn_from_promised_date);
            fnd_file.put_line (fnd_file.LOG,
                               'To Promised Date : ' || pv_to_promised_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'To Promised Date:(if null) ' || lv_to_promised_date);
            -- fnd_file.put_line (fnd_file.log, 'To ASN Promised Date : '||lv_asn_to_promise_date);
            fnd_file.put_line (fnd_file.LOG,
                               'From XF Date : ' || pv_from_xf_date);
            fnd_file.put_line (fnd_file.LOG,
                               'From XF Date:(if null) ' || lv_from_xf_date);
            fnd_file.put_line (fnd_file.LOG,
                               'From ASN XF Date : ' || lv_asn_from_xf_date);
            fnd_file.put_line (fnd_file.LOG,
                               'To XF Date : ' || pv_to_xf_date);
            fnd_file.put_line (fnd_file.LOG,
                               'To XF Date:(if null) ' || lv_to_xf_date);
            -- fnd_file.put_line (fnd_file.log, 'To ASN XF Date : '||lv_asn_to_xf_date);
            apps.fnd_file.put_line (apps.fnd_file.LOG, '');
            apps.fnd_file.put_line (apps.fnd_file.LOG, '');

            OPEN get_po_details_cur (lv_from_period_date, lv_to_period_date, lv_from_promised_date, lv_to_promised_date, lv_from_xf_date, lv_to_xf_date, lv_asn_from_promised_date, lv_asn_from_xf_date, lv_source_org
                                     , lv_destination_org);

            v_po_rec.delete;

            LOOP                                                     -- Cursor
                FETCH get_po_details_cur
                    BULK COLLECT INTO v_po_rec
                    LIMIT 20000;

                IF (v_po_rec.COUNT > 0)                   -- IF v_po_rec.COUNT
                THEN
                    BEGIN
                        FOR i IN 1 .. v_po_rec.COUNT
                        LOOP
                            -- fnd_file.put_line (fnd_file.log,'Line Location ID:'||v_po_rec(i).po_line_location_id||'Promised Date:'||v_po_rec(i).promised_date||'-'||
                            -- 'Period From Date'||lv_from_period_date||'-'||
                            -- 'Expected Receipt Date'||v_po_rec(i).expected_receipt_date||'-'||
                            -- 'ASN Creation Date'||v_po_rec(i).asn_creation_date||'-'||
                            -- 'Confirmed XF Date'||v_po_rec(i).confirmed_xf_date||'-'||
                            -- 'Need By Date'||v_po_rec(i).need_by_date||'-'||
                            -- 'Promised Expected Receipt Date'||v_po_rec(i).promise_expected_receipt_date||'-'||
                            -- 'Original Promise Date'||v_po_rec(i).original_promise_date);

                            IF     (v_po_rec (i).po_type = 'STANDARD' OR v_po_rec (i).po_type = 'JAPAN_TQ')
                               AND v_po_rec (i).subtype = 'PO'
                            THEN
                                -- IF v_po_rec(i).promised_date >= lv_from_period_date
                                IF v_po_rec (i).promised_date >=
                                   NVL (lv_from_promised_date,
                                        lv_from_period_date)
                                THEN
                                    v_po_rec (i).promise_expected_receipt_date   :=
                                        v_po_rec (i).promised_date;
                                    -- Original Promised Date
                                    v_po_rec (i).original_promise_date   :=
                                        NULL;
                                -- ELSIF v_po_rec(i).promised_date < lv_from_period_date
                                ELSIF v_po_rec (i).promised_date <
                                      NVL (lv_from_promised_date,
                                           lv_from_period_date)
                                THEN
                                    -- v_po_rec(i).promise_expected_receipt_date := TO_CHAR (ADD_MONTHS (TRUNC (TO_DATE (v_po_rec(i).run_date,'DD-MON-YY'),'MONTH'),1),'DD-MON-YY');
                                    v_po_rec (i).promise_expected_receipt_date   :=
                                        NVL (lv_from_promised_date,
                                             lv_from_period_date);
                                    -- Original Promised Date
                                    v_po_rec (i).original_promise_date   :=
                                        v_po_rec (i).promised_date;
                                END IF;
                            ELSIF     (v_po_rec (i).po_type = 'STANDARD' OR v_po_rec (i).po_type = 'JAPAN_TQ')
                                  AND (v_po_rec (i).subtype = 'ASN' OR v_po_rec (i).subtype = 'ERD')
                            THEN
                                -- IF v_po_rec(i).expected_receipt_date >= lv_from_period_date
                                -- IF v_po_rec(i).expected_receipt_date >= NVL (lv_from_xf_date, lv_from_period_date)
                                IF v_po_rec (i).expected_receipt_date >=
                                   lv_from_period_date
                                THEN
                                    -- IF TRUNC (v_po_rec(i).asn_creation_date) <> TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS')
                                    -- THEN

                                    -- Start of Change for CCR0009989
                                    /*IF (v_po_rec(i).asn_creation_date + (v_po_rec(i).promised_date - NVL (TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS'),TO_DATE (v_po_rec(i).requested_xf_date,'YYYY/MM/DD HH24:MI:SS')))) < lv_from_period_date
                                    THEN
                                        v_po_rec(i).promise_expected_receipt_date := v_po_rec(i).expected_receipt_date;
                                    ELSE
                                        v_po_rec(i).promise_expected_receipt_date := (v_po_rec(i).asn_creation_date + (v_po_rec(i).promised_date - NVL (TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS'), TO_DATE (v_po_rec(i).requested_xf_date,'YYYY/MM/DD HH24:MI:SS'))));

                                    -- ELSIF TRUNC (v_po_rec(i).asn_creation_date) = TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS')
                                    -- THEN
                                    END IF;
                                    */
                                    v_po_rec (i).promise_expected_receipt_date   :=
                                        v_po_rec (i).expected_receipt_date;
                                    -- End of Change for CCR0009989

                                    -- Original Promised Date
                                    v_po_rec (i).original_promise_date   :=
                                        NULL;
                                -- ELSIF v_po_rec(i).expected_receipt_date < lv_from_period_date
                                -- ELS
                                -- IF v_po_rec(i).expected_receipt_date < NVL (lv_from_xf_date, lv_from_period_date)
                                ELSIF v_po_rec (i).expected_receipt_date <
                                      lv_from_period_date
                                THEN
                                    -- v_po_rec(i).promise_expected_receipt_date := TO_CHAR (ADD_MONTHS (TRUNC (TO_DATE (v_po_rec(i).run_date,'DD-MON-YY'),'MONTH'),1),'DD-MON-YY');
                                    v_po_rec (i).promise_expected_receipt_date   :=
                                        lv_from_period_date;

                                    IF TRUNC (v_po_rec (i).asn_creation_date) <>
                                       NVL (
                                           TO_DATE (
                                               v_po_rec (i).confirmed_xf_date,
                                               'YYYY/MM/DD HH24:MI:SS'),
                                           TO_DATE (
                                               v_po_rec (i).requested_xf_date,
                                               'YYYY/MM/DD HH24:MI:SS'))
                                    THEN
                                        -- v_po_rec(i).original_promise_date := v_po_rec(i).asn_creation_date + (v_po_rec(i).promised_date - TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS'));
                                        v_po_rec (i).original_promise_date   :=
                                            v_po_rec (i).expected_receipt_date;
                                    ELSIF TRUNC (
                                              v_po_rec (i).asn_creation_date) =
                                          NVL (
                                              TO_DATE (
                                                  v_po_rec (i).confirmed_xf_date,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                              TO_DATE (
                                                  v_po_rec (i).requested_xf_date,
                                                  'YYYY/MM/DD HH24:MI:SS'))
                                    THEN
                                        v_po_rec (i).original_promise_date   :=
                                            v_po_rec (i).expected_receipt_date;
                                    END IF;
                                END IF;
                            ELSIF     v_po_rec (i).po_type = 'INTERCO'
                                  AND v_po_rec (i).subtype = 'REQ'
                            THEN
                                -- IF v_po_rec(i).need_by_date >= lv_from_period_date
                                IF v_po_rec (i).need_by_date >=
                                   NVL (lv_from_promised_date,
                                        lv_from_period_date)
                                THEN
                                    v_po_rec (i).promise_expected_receipt_date   :=
                                        v_po_rec (i).need_by_date;
                                    -- Original Promised Date
                                    v_po_rec (i).original_promise_date   :=
                                        NULL;
                                -- ELSIF v_po_rec(i).need_by_date < lv_from_period_date
                                ELSIF v_po_rec (i).need_by_date <
                                      NVL (lv_from_promised_date,
                                           lv_from_period_date)
                                THEN
                                    -- v_po_rec(i).promise_expected_receipt_date := TO_CHAR (ADD_MONTHS (TRUNC (TO_DATE (v_po_rec(i).run_date,'DD-MON-YY'),'MONTH'),1),'DD-MON-YY');
                                    v_po_rec (i).promise_expected_receipt_date   :=
                                        NVL (lv_from_promised_date,
                                             lv_from_period_date);
                                    -- Original Promised Date
                                    v_po_rec (i).original_promise_date   :=
                                        v_po_rec (i).need_by_date;
                                END IF;
                            ELSIF     v_po_rec (i).po_type = 'INTERCO'
                                  AND (v_po_rec (i).subtype = 'ASN' OR v_po_rec (i).subtype = 'ERD')
                            THEN
                                -- IF v_po_rec(i).expected_receipt_date >= lv_from_period_date
                                IF v_po_rec (i).expected_receipt_date >=
                                   NVL (lv_from_xf_date, lv_from_period_date)
                                THEN
                                    -- Start of Change for CCR0009989

                                    /*--SS   IF TRUNC (v_po_rec(i).asn_creation_date) <> NVL (TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS'), TO_DATE (v_po_rec(i).requested_xf_date,'YYYY/MM/DD HH24:MI:SS'))
                                             THEN
                                                 v_po_rec(i).promise_expected_receipt_date := v_po_rec(i).asn_creation_date + (v_po_rec(i).promised_date - NVL (TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS'), TO_DATE (v_po_rec(i).requested_xf_date,'YYYY/MM/DD HH24:MI:SS')));

                                             ELSIF TRUNC (v_po_rec(i).asn_creation_date) = NVL (TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS'), TO_DATE (v_po_rec(i).requested_xf_date,'YYYY/MM/DD HH24:MI:SS'))
                                             THEN
                                        v_po_rec(i).promise_expected_receipt_date := v_po_rec(i).expected_receipt_date;
                                             END IF; */

                                    v_po_rec (i).promise_expected_receipt_date   :=
                                        v_po_rec (i).expected_receipt_date;

                                    -- End of Change for CCR0009989

                                    -- Original Promised Date
                                    v_po_rec (i).original_promise_date   :=
                                        NULL;
                                -- ELSIF v_po_rec(i).expected_receipt_date < lv_from_period_date
                                ELSIF v_po_rec (i).expected_receipt_date <
                                      NVL (lv_from_xf_date,
                                           lv_from_period_date)
                                THEN
                                    -- v_po_rec(i).promise_expected_receipt_date := TO_CHAR (ADD_MONTHS (TRUNC (TO_DATE (v_po_rec(i).run_date,'DD-MON-YY'),'MONTH'),1),'DD-MON-YY');
                                    v_po_rec (i).promise_expected_receipt_date   :=
                                        NVL (lv_from_xf_date,
                                             lv_from_period_date);

                                    IF TRUNC (v_po_rec (i).asn_creation_date) <>
                                       NVL (
                                           TO_DATE (
                                               v_po_rec (i).confirmed_xf_date,
                                               'YYYY/MM/DD HH24:MI:SS'),
                                           TO_DATE (
                                               v_po_rec (i).requested_xf_date,
                                               'YYYY/MM/DD HH24:MI:SS'))
                                    THEN
                                        v_po_rec (i).original_promise_date   :=
                                              v_po_rec (i).asn_creation_date
                                            + (v_po_rec (i).promised_date - NVL (TO_DATE (v_po_rec (i).confirmed_xf_date, 'YYYY/MM/DD HH24:MI:SS'), TO_DATE (v_po_rec (i).requested_xf_date, 'YYYY/MM/DD HH24:MI:SS')));
                                    ELSIF TRUNC (
                                              v_po_rec (i).asn_creation_date) =
                                          NVL (
                                              TO_DATE (
                                                  v_po_rec (i).confirmed_xf_date,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                              TO_DATE (
                                                  v_po_rec (i).requested_xf_date,
                                                  'YYYY/MM/DD HH24:MI:SS'))
                                    THEN
                                        v_po_rec (i).original_promise_date   :=
                                            v_po_rec (i).expected_receipt_date;
                                    END IF;
                                END IF;
                            END IF;

                            -- Derive Intransit Receipt Date, Original Intransit Receipt Date

                            -- IF v_po_rec(i).expected_receipt_date >= lv_from_period_date
                            IF v_po_rec (i).expected_receipt_date >=
                               NVL (lv_from_xf_date, lv_from_period_date)
                            THEN
                                IF     (v_po_rec (i).po_type = 'STANDARD' OR v_po_rec (i).po_type = 'JAPAN_TQ' OR v_po_rec (i).po_type = 'INTERCO')
                                   AND (v_po_rec (i).subtype = 'ASN' OR v_po_rec (i).subtype = 'ERD')
                                THEN
                                    -- Start of Change for CCR0009989

                                    /* IF TRUNC (v_po_rec(i).asn_creation_date) <> TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS')
                                       THEN
                                           v_po_rec(i).intransit_receipt_date := v_po_rec(i).asn_creation_date + (v_po_rec(i).promised_date - TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS'));

                                       ELSIF TRUNC (v_po_rec(i).asn_creation_date) = TO_DATE (v_po_rec(i).confirmed_xf_date,'YYYY/MM/DD HH24:MI:SS')
                                       THEN

                                           v_po_rec(i).intransit_receipt_date := v_po_rec(i).expected_receipt_date;

                                       END IF;
                                       */

                                    v_po_rec (i).intransit_receipt_date   :=
                                        v_po_rec (i).expected_receipt_date;

                                    -- End of Change for CCR0009989

                                    -- Original Intransit Receipt Date
                                    v_po_rec (i).orig_intransit_receipt_date   :=
                                        NULL;
                                END IF;
                            -- ELSIF v_po_rec(i).expected_receipt_date < lv_from_period_date
                            ELSIF v_po_rec (i).expected_receipt_date <
                                  NVL (lv_from_xf_date, lv_from_period_date)
                            THEN
                                -- v_po_rec(i).intransit_receipt_date := TO_CHAR (ADD_MONTHS (TRUNC (TO_DATE (v_po_rec(i).run_date,'DD-MON-YY'),'MONTH'),1),'DD-MON-YY');
                                v_po_rec (i).intransit_receipt_date   :=
                                    NVL (lv_from_promised_date,
                                         lv_from_period_date);

                                IF     (v_po_rec (i).po_type = 'STANDARD' OR v_po_rec (i).po_type = 'JAPAN_TQ' OR v_po_rec (i).po_type = 'INTERCO')
                                   AND (v_po_rec (i).subtype = 'ASN' OR v_po_rec (i).subtype = 'ERD')
                                THEN
                                    -- Original Intransit Receipt Date
                                    IF TRUNC (v_po_rec (i).asn_creation_date) <>
                                       TO_DATE (
                                           v_po_rec (i).confirmed_xf_date,
                                           'YYYY/MM/DD HH24:MI:SS')
                                    THEN
                                        v_po_rec (i).orig_intransit_receipt_date   :=
                                              v_po_rec (i).asn_creation_date
                                            + (v_po_rec (i).promised_date - TO_DATE (v_po_rec (i).confirmed_xf_date, 'YYYY/MM/DD HH24:MI:SS'));
                                    ELSIF TRUNC (
                                              v_po_rec (i).asn_creation_date) =
                                          TO_DATE (
                                              v_po_rec (i).confirmed_xf_date,
                                              'YYYY/MM/DD HH24:MI:SS')
                                    THEN
                                        v_po_rec (i).orig_intransit_receipt_date   :=
                                            v_po_rec (i).expected_receipt_date;
                                    END IF;
                                END IF;
                            END IF;

                            v_po_rec (i).fob_value   :=
                                  v_po_rec (i).fob_value
                                * v_po_rec (i).quantity;

                            BEGIN
                                lv_conversion_rate   := NULL;

                                SELECT conversion_rate
                                  INTO lv_conversion_rate
                                  FROM gl_daily_rates
                                 WHERE     from_currency =
                                           v_po_rec (i).po_currency
                                       AND to_currency = 'USD'
                                       AND conversion_type = pv_rate_type
                                       AND TRUNC (conversion_date) =
                                           NVL (
                                               TRUNC (
                                                   TO_DATE (
                                                       pv_rate_date,
                                                       'RRRR/MM/DD HH24:MI:SS')),
                                               TRUNC (SYSDATE));
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    -- fnd_file.put_line (fnd_file.log,'Exception Occurred while retriving Conversion Rate');
                                    lv_conversion_rate   := 1;
                            END;

                            -- fnd_file.put_line (fnd_file.log,lv_conversion_rate);
                            -- v_po_rec(i).fob_value_in_usd := v_po_rec(i).fob_value * ROUND (lv_conversion_rate, 2);

                            v_po_rec (i).fob_value_in_usd   :=
                                ROUND (
                                    (v_po_rec (i).fob_value * lv_conversion_rate),
                                    2);
                        -- fnd_file.put_line (fnd_file.log,'Line Location ID:'||v_po_rec(i).po_line_location_id||'Promised Date:'||v_po_rec(i).promised_date||'-'||
                        -- 'Period From Date'||lv_from_period_date||'-'||
                        -- 'Expected Receipt Date'||v_po_rec(i).expected_receipt_date||'-'||
                        -- 'ASN Creation Date'||v_po_rec(i).asn_creation_date||'-'||
                        -- 'Confirmed XF Date'||v_po_rec(i).confirmed_xf_date||'-'||
                        -- 'Need By Date'||v_po_rec(i).need_by_date||'-'||
                        -- 'Promised Expected Receipt Date'||v_po_rec(i).promise_expected_receipt_date||'-'||
                        -- 'Original Promise Date'||v_po_rec(i).original_promise_date);

                        END LOOP;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   SQLERRM
                                || ' Exception Occurred while Deriving the Values');
                    END;
                END IF;                                   -- IF v_po_rec.COUNT

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Derivation Complted...'
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                IF pv_run_mode = 'Review' OR pv_run_mode = 'Insert'
                THEN
                    BEGIN
                        FORALL i IN v_po_rec.FIRST .. v_po_rec.LAST
                          SAVE EXCEPTIONS
                            INSERT INTO xxdo.xxd_po_proj_fc_rev_stg_t (
                                            run_date,
                                            po_type,
                                            subtype,
                                            req_number,
                                            requisition_header_id,
                                            requisition_line_id,
                                            oe_line_id,
                                            po_number,
                                            po_header_id,
                                            po_line_id,
                                            po_line_location_id,
                                            shipment_number,
                                            shipment_header_id,
                                            shipment_line_id,
                                            brand,
                                            department,
                                            item_category,
                                            item_sku,
                                            from_period_identifier,
                                            to_period_identifier,
                                            from_period_date,
                                            to_period_date,
                                            source_org,
                                            requested_xf_date,
                                            orig_confirmed_xf_date,
                                            confirmed_xf_date,
                                            asn_creation_date,
                                            xf_shipment_date,
                                            destination_org,
                                            need_by_date,
                                            promised_date,
                                            expected_receipt_date,
                                            promise_expected_receipt_date,
                                            original_promise_date,
                                            intransit_receipt_date,
                                            orig_intransit_receipt_date,
                                            asn_type,
                                            fob_value,
                                            quantity,
                                            ship_method,
                                            po_currency,
                                            fob_value_in_usd,
                                            calculated_flag,
                                            override_status,
                                            source,
                                            rec_status,
                                            created_by,
                                            creation_date,
                                            last_updated_by,
                                            last_update_date,
                                            request_id)
                                     VALUES (
                                                v_po_rec (i).run_date,
                                                v_po_rec (i).po_type,
                                                v_po_rec (i).subtype,
                                                v_po_rec (i).req_number,
                                                v_po_rec (i).requisition_header_id,
                                                v_po_rec (i).requisition_line_id,
                                                v_po_rec (i).oe_line_id,
                                                v_po_rec (i).po_number,
                                                v_po_rec (i).po_header_id,
                                                v_po_rec (i).po_line_id,
                                                v_po_rec (i).po_line_location_id,
                                                v_po_rec (i).shipment_number,
                                                v_po_rec (i).shipment_header_id,
                                                v_po_rec (i).shipment_line_id,
                                                v_po_rec (i).brand,
                                                v_po_rec (i).department,
                                                v_po_rec (i).item_category,
                                                v_po_rec (i).item_sku,
                                                v_po_rec (i).from_period_identifier,
                                                v_po_rec (i).to_period_identifier,
                                                v_po_rec (i).from_period_date,
                                                v_po_rec (i).to_period_date,
                                                v_po_rec (i).source_org,
                                                TO_DATE (
                                                    v_po_rec (i).requested_xf_date,
                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                TO_DATE (
                                                    v_po_rec (i).orig_confirmed_xf_date,
                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                TO_DATE (
                                                    v_po_rec (i).confirmed_xf_date,
                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                v_po_rec (i).asn_creation_date,
                                                TO_DATE (
                                                    v_po_rec (i).xf_shipment_date,
                                                    'YYYY/MM/DD HH24:MI:SS'),
                                                v_po_rec (i).destination_org,
                                                v_po_rec (i).need_by_date,
                                                v_po_rec (i).promised_date,
                                                v_po_rec (i).expected_receipt_date,
                                                v_po_rec (i).promise_expected_receipt_date,
                                                v_po_rec (i).original_promise_date,
                                                v_po_rec (i).intransit_receipt_date,
                                                v_po_rec (i).orig_intransit_receipt_date,
                                                v_po_rec (i).asn_type,
                                                v_po_rec (i).fob_value,
                                                v_po_rec (i).quantity,
                                                v_po_rec (i).ship_method,
                                                v_po_rec (i).po_currency,
                                                v_po_rec (i).fob_value_in_usd,
                                                v_po_rec (i).calculated_flag,
                                                v_po_rec (i).override_status,
                                                v_po_rec (i).source,
                                                'N',
                                                gn_user_id,
                                                SYSDATE,
                                                gn_user_id,
                                                SYSDATE,
                                                gn_request_id);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Insert into Table ' || v_po_rec (ln_error_num).po_line_location_id || ' ' || lv_error_code || CHR (10)),
                                        1,
                                        4000);

                                fnd_file.put_line (fnd_file.LOG,
                                                   lv_error_msg);
                            END LOOP;
                    END;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Review-Insertion Completed'
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                END IF;

                IF pv_run_mode = 'Insert'
                THEN
                    FOR i IN 1 .. v_po_rec.COUNT
                    LOOP
                        BEGIN
                            SELECT 'Y', calculated_flag
                              INTO lv_exists, lv_calculated_flag
                              FROM xxdo.xxd_po_proj_forecast_stg_t
                             WHERE     po_line_id = v_po_rec (i).po_line_id
                                   AND po_line_location_id =
                                       v_po_rec (i).po_line_location_id
                                   AND NVL (requisition_line_id, 000) =
                                       NVL (v_po_rec (i).requisition_line_id,
                                            000)
                                   AND NVL (shipment_line_id, 000) =
                                       NVL (v_po_rec (i).shipment_line_id,
                                            000)
                                   AND override_status = 'NEW';

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'PO already Exists in STG table :PO_line_id-'
                                || v_po_rec (i).po_line_id
                                || '-'
                                || 'PO_line_location_id-'
                                || v_po_rec (i).po_line_location_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_exists   := 'N';
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       SQLERRM
                                    || 'PO does not exists in STG table :PO_line_id-'
                                    || v_po_rec (i).po_line_id
                                    || '-'
                                    || 'PO_line_location_id-'
                                    || v_po_rec (i).po_line_location_id
                                    || v_po_rec (i).requested_xf_date
                                    || '-'
                                    || v_po_rec (i).orig_confirmed_xf_date
                                    || '-'
                                    || v_po_rec (i).confirmed_xf_date
                                    || '-'
                                    || v_po_rec (i).asn_creation_date
                                    || '-'
                                    || v_po_rec (i).xf_shipment_date);
                        END;

                        IF lv_exists = 'N'
                        THEN
                            BEGIN
                                INSERT INTO xxdo.xxd_po_proj_forecast_stg_t (
                                                run_date,
                                                po_type,
                                                subtype,
                                                req_number,
                                                requisition_header_id,
                                                requisition_line_id,
                                                oe_line_id,
                                                po_number,
                                                po_header_id,
                                                po_line_id,
                                                po_line_location_id,
                                                shipment_number,
                                                shipment_header_id,
                                                shipment_line_id,
                                                brand,
                                                department,
                                                item_category,
                                                item_sku,
                                                from_period_identifier,
                                                to_period_identifier,
                                                from_period_date,
                                                to_period_date,
                                                source_org,
                                                requested_xf_date,
                                                orig_confirmed_xf_date,
                                                confirmed_xf_date,
                                                asn_creation_date,
                                                xf_shipment_date,
                                                destination_org,
                                                need_by_date,
                                                promised_date,
                                                expected_receipt_date,
                                                promise_expected_receipt_date,
                                                original_promise_date,
                                                intransit_receipt_date,
                                                orig_intransit_receipt_date,
                                                asn_type,
                                                fob_value,
                                                quantity,
                                                ship_method,
                                                po_currency,
                                                fob_value_in_usd,
                                                calculated_flag,
                                                override_status,
                                                source,
                                                rec_status,
                                                created_by,
                                                creation_date,
                                                last_updated_by,
                                                last_update_date,
                                                request_id)
                                         VALUES (
                                                    v_po_rec (i).run_date,
                                                    v_po_rec (i).po_type,
                                                    v_po_rec (i).subtype,
                                                    v_po_rec (i).req_number,
                                                    v_po_rec (i).requisition_header_id,
                                                    v_po_rec (i).requisition_line_id,
                                                    v_po_rec (i).oe_line_id,
                                                    v_po_rec (i).po_number,
                                                    v_po_rec (i).po_header_id,
                                                    v_po_rec (i).po_line_id,
                                                    v_po_rec (i).po_line_location_id,
                                                    v_po_rec (i).shipment_number,
                                                    v_po_rec (i).shipment_header_id,
                                                    v_po_rec (i).shipment_line_id,
                                                    v_po_rec (i).brand,
                                                    v_po_rec (i).department,
                                                    v_po_rec (i).item_category,
                                                    v_po_rec (i).item_sku,
                                                    v_po_rec (i).from_period_identifier,
                                                    v_po_rec (i).to_period_identifier,
                                                    v_po_rec (i).from_period_date,
                                                    v_po_rec (i).to_period_date,
                                                    v_po_rec (i).source_org,
                                                    TO_DATE (
                                                        v_po_rec (i).requested_xf_date,
                                                        'YYYY/MM/DD HH24:MI:SS'),
                                                    TO_DATE (
                                                        v_po_rec (i).orig_confirmed_xf_date,
                                                        'YYYY/MM/DD HH24:MI:SS'),
                                                    TO_DATE (
                                                        v_po_rec (i).confirmed_xf_date,
                                                        'YYYY/MM/DD HH24:MI:SS'),
                                                    v_po_rec (i).asn_creation_date,
                                                    TO_DATE (
                                                        v_po_rec (i).xf_shipment_date,
                                                        'YYYY/MM/DD HH24:MI:SS'),
                                                    v_po_rec (i).destination_org,
                                                    v_po_rec (i).need_by_date,
                                                    v_po_rec (i).promised_date,
                                                    v_po_rec (i).expected_receipt_date,
                                                    v_po_rec (i).promise_expected_receipt_date,
                                                    v_po_rec (i).original_promise_date,
                                                    v_po_rec (i).intransit_receipt_date,
                                                    v_po_rec (i).orig_intransit_receipt_date,
                                                    v_po_rec (i).asn_type,
                                                    v_po_rec (i).fob_value,
                                                    v_po_rec (i).quantity,
                                                    v_po_rec (i).ship_method,
                                                    v_po_rec (i).po_currency,
                                                    v_po_rec (i).fob_value_in_usd,
                                                    v_po_rec (i).calculated_flag,
                                                    v_po_rec (i).override_status,
                                                    v_po_rec (i).source,
                                                    'N',
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_request_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           SQLERRM
                                        || ' Exception occurred while inserting into the STG table-Override N and lv_exists N');
                            END;
                        ELSIF lv_exists = 'Y' AND pv_override = 'Yes'
                        THEN
                            IF lv_calculated_flag = 'N'
                            THEN
                                BEGIN
                                    INSERT INTO xxdo.xxd_po_proj_forecast_stg_bkp_t (
                                                    run_date,
                                                    po_type,
                                                    subtype,
                                                    req_number,
                                                    requisition_header_id,
                                                    requisition_line_id,
                                                    oe_line_id,
                                                    po_number,
                                                    po_header_id,
                                                    po_line_id,
                                                    po_line_location_id,
                                                    shipment_number,
                                                    shipment_header_id,
                                                    shipment_line_id,
                                                    brand,
                                                    department,
                                                    item_category,
                                                    item_sku,
                                                    from_period_identifier,
                                                    to_period_identifier,
                                                    from_period_date,
                                                    to_period_date,
                                                    source_org,
                                                    requested_xf_date,
                                                    orig_confirmed_xf_date,
                                                    confirmed_xf_date,
                                                    asn_creation_date,
                                                    xf_shipment_date,
                                                    destination_org,
                                                    need_by_date,
                                                    promised_date,
                                                    expected_receipt_date,
                                                    promise_expected_receipt_date,
                                                    original_promise_date,
                                                    intransit_receipt_date,
                                                    orig_intransit_receipt_date,
                                                    asn_type,
                                                    fob_value,
                                                    quantity,
                                                    ship_method,
                                                    po_currency,
                                                    fob_value_in_usd,
                                                    calculated_flag,
                                                    override_status,
                                                    source,
                                                    rec_status,
                                                    created_by,
                                                    creation_date,
                                                    last_updated_by,
                                                    last_update_date,
                                                    request_id)
                                        SELECT run_date, po_type, subtype,
                                               req_number, requisition_header_id, requisition_line_id,
                                               oe_line_id, po_number, po_header_id,
                                               po_line_id, po_line_location_id, shipment_number,
                                               shipment_header_id, shipment_line_id, brand,
                                               department, item_category, item_sku,
                                               from_period_identifier, to_period_identifier, from_period_date,
                                               to_period_date, source_org, requested_xf_date,
                                               orig_confirmed_xf_date, confirmed_xf_date, asn_creation_date,
                                               xf_shipment_date, destination_org, need_by_date,
                                               promised_date, expected_receipt_date, promise_expected_receipt_date,
                                               original_promise_date, intransit_receipt_date, orig_intransit_receipt_date,
                                               asn_type, fob_value, quantity,
                                               ship_method, po_currency, fob_value_in_usd,
                                               calculated_flag, override_status, source,
                                               rec_status, created_by, creation_date,
                                               last_updated_by, last_update_date, request_id
                                          FROM xxdo.xxd_po_proj_forecast_stg_t
                                         WHERE     po_line_id =
                                                   v_po_rec (i).po_line_id
                                               AND po_line_location_id =
                                                   v_po_rec (i).po_line_location_id
                                               AND NVL (requisition_line_id,
                                                        000) =
                                                   NVL (
                                                       v_po_rec (i).requisition_line_id,
                                                       000)
                                               AND NVL (shipment_line_id,
                                                        000) =
                                                   NVL (
                                                       v_po_rec (i).shipment_line_id,
                                                       000)
                                               AND override_status = 'NEW';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               SQLERRM
                                            || ' Exception occurred while backup the STG table Data');
                                END;

                                BEGIN
                                    DELETE xxdo.xxd_po_proj_forecast_stg_t
                                     WHERE     po_line_id =
                                               v_po_rec (i).po_line_id
                                           AND po_line_location_id =
                                               v_po_rec (i).po_line_location_id
                                           AND NVL (requisition_line_id, 000) =
                                               NVL (
                                                   v_po_rec (i).requisition_line_id,
                                                   000)
                                           AND NVL (shipment_line_id, 000) =
                                               NVL (
                                                   v_po_rec (i).shipment_line_id,
                                                   000)
                                           AND override_status = 'NEW';

                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           SQL%ROWCOUNT
                                        || ' Record Deleted for PO Line ID'
                                        || v_po_rec (i).po_line_id
                                        || 'PO Line Location ID'
                                        || v_po_rec (i).po_line_location_id);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               SQLERRM
                                            || ' Exception Occurred while Delete data from STG table');
                                END;

                                BEGIN
                                    INSERT INTO xxdo.xxd_po_proj_forecast_stg_t (
                                                    run_date,
                                                    po_type,
                                                    subtype,
                                                    req_number,
                                                    requisition_header_id,
                                                    requisition_line_id,
                                                    oe_line_id,
                                                    po_number,
                                                    po_header_id,
                                                    po_line_id,
                                                    po_line_location_id,
                                                    shipment_number,
                                                    shipment_header_id,
                                                    shipment_line_id,
                                                    brand,
                                                    department,
                                                    item_category,
                                                    item_sku,
                                                    from_period_identifier,
                                                    to_period_identifier,
                                                    from_period_date,
                                                    to_period_date,
                                                    source_org,
                                                    requested_xf_date,
                                                    orig_confirmed_xf_date,
                                                    confirmed_xf_date,
                                                    asn_creation_date,
                                                    xf_shipment_date,
                                                    destination_org,
                                                    need_by_date,
                                                    promised_date,
                                                    expected_receipt_date,
                                                    promise_expected_receipt_date,
                                                    original_promise_date,
                                                    intransit_receipt_date,
                                                    orig_intransit_receipt_date,
                                                    asn_type,
                                                    fob_value,
                                                    quantity,
                                                    ship_method,
                                                    po_currency,
                                                    fob_value_in_usd,
                                                    calculated_flag,
                                                    override_status,
                                                    source,
                                                    rec_status,
                                                    created_by,
                                                    creation_date,
                                                    last_updated_by,
                                                    last_update_date,
                                                    request_id)
                                             VALUES (
                                                        v_po_rec (i).run_date,
                                                        v_po_rec (i).po_type,
                                                        v_po_rec (i).subtype,
                                                        v_po_rec (i).req_number,
                                                        v_po_rec (i).requisition_header_id,
                                                        v_po_rec (i).requisition_line_id,
                                                        v_po_rec (i).oe_line_id,
                                                        v_po_rec (i).po_number,
                                                        v_po_rec (i).po_header_id,
                                                        v_po_rec (i).po_line_id,
                                                        v_po_rec (i).po_line_location_id,
                                                        v_po_rec (i).shipment_number,
                                                        v_po_rec (i).shipment_header_id,
                                                        v_po_rec (i).shipment_line_id,
                                                        v_po_rec (i).brand,
                                                        v_po_rec (i).department,
                                                        v_po_rec (i).item_category,
                                                        v_po_rec (i).item_sku,
                                                        v_po_rec (i).from_period_identifier,
                                                        v_po_rec (i).to_period_identifier,
                                                        v_po_rec (i).from_period_date,
                                                        v_po_rec (i).to_period_date,
                                                        v_po_rec (i).source_org,
                                                        TO_DATE (
                                                            v_po_rec (i).requested_xf_date,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        TO_DATE (
                                                            v_po_rec (i).orig_confirmed_xf_date,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        TO_DATE (
                                                            v_po_rec (i).confirmed_xf_date,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        v_po_rec (i).asn_creation_date,
                                                        TO_DATE (
                                                            v_po_rec (i).xf_shipment_date,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        v_po_rec (i).destination_org,
                                                        v_po_rec (i).need_by_date,
                                                        v_po_rec (i).promised_date,
                                                        v_po_rec (i).expected_receipt_date,
                                                        v_po_rec (i).promise_expected_receipt_date,
                                                        v_po_rec (i).original_promise_date,
                                                        v_po_rec (i).intransit_receipt_date,
                                                        v_po_rec (i).orig_intransit_receipt_date,
                                                        v_po_rec (i).asn_type,
                                                        v_po_rec (i).fob_value,
                                                        v_po_rec (i).quantity,
                                                        v_po_rec (i).ship_method,
                                                        v_po_rec (i).po_currency,
                                                        v_po_rec (i).fob_value_in_usd,
                                                        v_po_rec (i).calculated_flag,
                                                        v_po_rec (i).override_status,
                                                        v_po_rec (i).source,
                                                        'N',
                                                        gn_user_id,
                                                        SYSDATE,
                                                        gn_user_id,
                                                        SYSDATE,
                                                        gn_request_id);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               SQLERRM
                                            || ' Exception occurred while inserting into the STG table-Calculated Flag N');
                                END;
                            ELSIF lv_calculated_flag = 'Y'
                            THEN
                                BEGIN
                                    UPDATE xxdo.xxd_po_proj_forecast_stg_t
                                       SET override_status   = 'OVERRIDE'
                                     WHERE     po_line_id =
                                               v_po_rec (i).po_line_id
                                           AND po_line_location_id =
                                               v_po_rec (i).po_line_location_id
                                           AND NVL (requisition_line_id, 000) =
                                               NVL (
                                                   v_po_rec (i).requisition_line_id,
                                                   000)
                                           AND NVL (shipment_line_id, 000) =
                                               NVL (
                                                   v_po_rec (i).shipment_line_id,
                                                   000)
                                           AND override_status = 'NEW';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               SQLERRM
                                            || ' Exception Occurred while Update the STG Table OVERRIDE');
                                END;

                                BEGIN
                                    INSERT INTO xxdo.xxd_po_proj_forecast_stg_t (
                                                    run_date,
                                                    po_type,
                                                    subtype,
                                                    req_number,
                                                    requisition_header_id,
                                                    requisition_line_id,
                                                    oe_line_id,
                                                    po_number,
                                                    po_header_id,
                                                    po_line_id,
                                                    po_line_location_id,
                                                    shipment_number,
                                                    shipment_header_id,
                                                    shipment_line_id,
                                                    brand,
                                                    department,
                                                    item_category,
                                                    item_sku,
                                                    from_period_identifier,
                                                    to_period_identifier,
                                                    from_period_date,
                                                    to_period_date,
                                                    source_org,
                                                    requested_xf_date,
                                                    orig_confirmed_xf_date,
                                                    confirmed_xf_date,
                                                    asn_creation_date,
                                                    xf_shipment_date,
                                                    destination_org,
                                                    need_by_date,
                                                    promised_date,
                                                    expected_receipt_date,
                                                    promise_expected_receipt_date,
                                                    original_promise_date,
                                                    intransit_receipt_date,
                                                    orig_intransit_receipt_date,
                                                    asn_type,
                                                    fob_value,
                                                    quantity,
                                                    ship_method,
                                                    po_currency,
                                                    fob_value_in_usd,
                                                    calculated_flag,
                                                    override_status,
                                                    source,
                                                    rec_status,
                                                    created_by,
                                                    creation_date,
                                                    last_updated_by,
                                                    last_update_date,
                                                    request_id)
                                             VALUES (
                                                        v_po_rec (i).run_date,
                                                        v_po_rec (i).po_type,
                                                        v_po_rec (i).subtype,
                                                        v_po_rec (i).req_number,
                                                        v_po_rec (i).requisition_header_id,
                                                        v_po_rec (i).requisition_line_id,
                                                        v_po_rec (i).oe_line_id,
                                                        v_po_rec (i).po_number,
                                                        v_po_rec (i).po_header_id,
                                                        v_po_rec (i).po_line_id,
                                                        v_po_rec (i).po_line_location_id,
                                                        v_po_rec (i).shipment_number,
                                                        v_po_rec (i).shipment_header_id,
                                                        v_po_rec (i).shipment_line_id,
                                                        v_po_rec (i).brand,
                                                        v_po_rec (i).department,
                                                        v_po_rec (i).item_category,
                                                        v_po_rec (i).item_sku,
                                                        v_po_rec (i).from_period_identifier,
                                                        v_po_rec (i).to_period_identifier,
                                                        v_po_rec (i).from_period_date,
                                                        v_po_rec (i).to_period_date,
                                                        v_po_rec (i).source_org,
                                                        TO_DATE (
                                                            v_po_rec (i).requested_xf_date,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        TO_DATE (
                                                            v_po_rec (i).orig_confirmed_xf_date,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        TO_DATE (
                                                            v_po_rec (i).confirmed_xf_date,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        v_po_rec (i).asn_creation_date,
                                                        TO_DATE (
                                                            v_po_rec (i).xf_shipment_date,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        v_po_rec (i).destination_org,
                                                        v_po_rec (i).need_by_date,
                                                        v_po_rec (i).promised_date,
                                                        v_po_rec (i).expected_receipt_date,
                                                        v_po_rec (i).promise_expected_receipt_date,
                                                        v_po_rec (i).original_promise_date,
                                                        v_po_rec (i).intransit_receipt_date,
                                                        v_po_rec (i).orig_intransit_receipt_date,
                                                        v_po_rec (i).asn_type,
                                                        v_po_rec (i).fob_value,
                                                        v_po_rec (i).quantity,
                                                        v_po_rec (i).ship_method,
                                                        v_po_rec (i).po_currency,
                                                        v_po_rec (i).fob_value_in_usd,
                                                        v_po_rec (i).calculated_flag,
                                                        v_po_rec (i).override_status,
                                                        v_po_rec (i).source,
                                                        'N',
                                                        gn_user_id,
                                                        SYSDATE,
                                                        gn_user_id,
                                                        SYSDATE,
                                                        gn_request_id);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               SQLERRM
                                            || ' Exception occurred while inserting into the STG table-Calculated Flag Y');
                                END;
                            END IF;                         -- Calculated Flag
                        END IF;                               -- Override Flag
                    END LOOP;                            -- pv_run_mode Insert

                    COMMIT;
                END IF;                                  -- pv_run_mode Review

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Insert - Insertion Completed'
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                EXIT WHEN get_po_details_cur%NOTFOUND;
            END LOOP;                                                -- Cursor

            CLOSE get_po_details_cur;
        END IF;                                -- pv_run_mode Review OR Insert

        COMMIT;

        -- Generate XML output for run mode : Report, Review
        fnd_file.put_line (
            fnd_file.LOG,
               'XML Output starts'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        BEGIN
            BEGIN
                SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                  INTO v_report_date
                  FROM sys.DUAL;
            END;

            apps.fnd_file.put_line (
                fnd_file.output,
                '<?xml version="1.0" encoding="US-ASCII"?>');
            apps.fnd_file.put_line (apps.fnd_file.output, '<MAIN>');
            apps.fnd_file.put_line (fnd_file.output, '<OUTPUT>');

            IF pv_run_mode = 'Report'
            THEN
                BEGIN
                    SELECT organization_name
                      INTO lv_src_org
                      FROM apps.org_organization_definitions
                     WHERE organization_id = pv_source_org;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Unable to retrive Source Org');
                END;


                BEGIN
                    SELECT organization_name
                      INTO lv_dest_org
                      FROM apps.org_organization_definitions
                     WHERE organization_id = pv_destination_org;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Unable to retrive Destination Org');
                END;

                FOR i IN rep_brand_cur (lv_from_period_date, lv_to_period_date, lv_src_org
                                        , lv_dest_org)
                LOOP
                    apps.fnd_file.put_line (fnd_file.output, '<PBRAND>');
                    apps.fnd_file.put_line (apps.fnd_file.output,
                                            '<PARAMGRP>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<DC>'
                        || DBMS_XMLGEN.CONVERT ('DECKERS CORPORATION')
                        || '</DC>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RN>'
                        || DBMS_XMLGEN.CONVERT (
                               'Report Name :Deckers PO Projected Supply Forecast Report')
                        || '</RN>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RD>'
                        || DBMS_XMLGEN.CONVERT (
                               'Report Date - :' || v_report_date)
                        || '</RD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RM>'
                        || DBMS_XMLGEN.CONVERT (
                               'Run Mode is :' || pv_run_mode)
                        || '</RM>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<PM>'
                        || DBMS_XMLGEN.CONVERT (
                               'PO Model is :' || pv_po_model)
                        || '</PM>');                                  -- Added
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<OR>'
                        || DBMS_XMLGEN.CONVERT (
                               'OVERRIDE is :' || pv_override)
                        || '</OR>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<FP>'
                        || DBMS_XMLGEN.CONVERT (
                               'Starting Period is :' || pv_from_period)
                        || '</FP>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<TP>'
                        || DBMS_XMLGEN.CONVERT (
                               'Ending Period is :' || pv_to_period)
                        || '</TP>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<IPDD>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Include Past Due Days is :'
                               || pn_incld_past_due_days)
                        || '</IPDD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<DDD>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Delay Delivery Days and Intransit Days are : '
                               || pn_delay_delivery_days
                               || ' and '
                               || pn_delay_intransit_days)
                        || '</DDD>');                                 -- Added
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<FPD>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Starting Promised Date is :'
                               || pv_from_promised_date)
                        || '</FPD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<TPD>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Ending Promised Date is :'
                               || pv_to_promised_date)
                        || '</TPD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<FXD>'
                        || DBMS_XMLGEN.CONVERT (
                               'Starting XF Date is :' || pv_from_xf_date)
                        || '</FXD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<TXD>'
                        || DBMS_XMLGEN.CONVERT (
                               'Ending XF Date is :' || pv_to_xf_date)
                        || '</TXD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<SO>'
                        || DBMS_XMLGEN.CONVERT (
                               'Source Organization is :' || pv_source_org)
                        || '</SO>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<DO>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Destination Organization is :'
                               || pv_destination_org)
                        || '</DO>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RDT>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Rate Date is :'
                               || TO_DATE (pv_rate_date,
                                           'RRRR/MM/DD HH24:MI:SS'))
                        || '</RDT>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RT>'
                        || DBMS_XMLGEN.CONVERT (
                               'Rate Type is :' || pv_rate_type)
                        || '</RT>');
                    apps.fnd_file.put_line (apps.fnd_file.output,
                                            '</PARAMGRP>');
                    fnd_file.put_line (
                        fnd_file.output,
                        '<BND>' || DBMS_XMLGEN.CONVERT (i.brand) || '</BND>');

                    OPEN rep_data_cur (lv_from_period_date, lv_to_period_date, lv_src_org
                                       , lv_dest_org, i.brand);

                    LOOP
                        FETCH rep_data_cur INTO rep_output_row;

                        EXIT WHEN rep_data_cur%NOTFOUND;

                        fnd_file.put_line (fnd_file.output, '<ROW>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<BRAND>'
                            || DBMS_XMLGEN.CONVERT (rep_output_row.brand)
                            || '</BRAND>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<DEPT>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.department)
                            || '</DEPT>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<IC>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.item_category)
                            || '</IC>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<IS>'
                            || DBMS_XMLGEN.CONVERT (rep_output_row.item_sku)
                            || '</IS>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<FPI>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.from_period_identifier)
                            || '</FPI>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<TPI>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.to_period_identifier)
                            || '</TPI>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<DSO>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.source_org)
                            || '</DSO>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<RXD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.requested_xf_date)
                            || '</RXD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<OCXD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.orig_confirmed_xf_date)
                            || '</OCXD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<CXD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.confirmed_xf_date)
                            || '</CXD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<ACD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.asn_creation_date)
                            || '</ACD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<XSD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.xf_shipment_date)
                            || '</XSD>');
                        -- Added
                        fnd_file.put_line (
                            fnd_file.output,
                               '<PD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.promised_date)
                            || '</PD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<ERD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.expected_receipt_date)
                            || '</ERD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<OPD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.original_promise_date)
                            || '</OPD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<IRD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.intransit_receipt_date)
                            || '</IRD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<OIRD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.orig_intransit_receipt_date)
                            || '</OIRD>');
                        -- Added
                        fnd_file.put_line (
                            fnd_file.output,
                               '<DDO>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.destination_org)
                            || '</DDO>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<PERD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.promise_expected_receipt_date)
                            || '</PERD>');
                        -- fnd_file.put_line(fnd_file.output,'<OPD>'||dbms_xmlgen.convert(rep_output_row.original_promise_date)||'</OPD>');
                        -- fnd_file.put_line(fnd_file.output,'<IRD>'||dbms_xmlgen.convert(rep_output_row.intransit_receipt_date)||'</IRD>');
                        -- fnd_file.put_line(fnd_file.output,'<OIRD>'||dbms_xmlgen.convert(rep_output_row.orig_intransit_receipt_date)||'</OIRD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<FV>'
                            || DBMS_XMLGEN.CONVERT (rep_output_row.fob_value)
                            || '</FV>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<QTY>'
                            || DBMS_XMLGEN.CONVERT (rep_output_row.quantity)
                            || '</QTY>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<SM>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.ship_method)
                            || '</SM>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<PC>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.po_currency)
                            || '</PC>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<FVIU>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.fob_value_in_usd)
                            || '</FVIU>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<CF>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.calculated_flag)
                            || '</CF>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<OS>'
                            || DBMS_XMLGEN.CONVERT (
                                   rep_output_row.override_status)
                            || '</OS>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<SRC>'
                            || DBMS_XMLGEN.CONVERT (rep_output_row.source)
                            || '</SRC>');
                        fnd_file.put_line (fnd_file.output, '</ROW>');
                    END LOOP;

                    CLOSE rep_data_cur;

                    fnd_file.put_line (fnd_file.output, '</PBRAND>');
                END LOOP;
            END IF;

            IF pv_run_mode = 'Review' OR pv_run_mode = 'Insert'
            THEN
                FOR i IN rev_brand_cur
                LOOP
                    apps.fnd_file.put_line (fnd_file.output, '<PBRAND>');
                    apps.fnd_file.put_line (apps.fnd_file.output,
                                            '<PARAMGRP>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<DC>'
                        || DBMS_XMLGEN.CONVERT ('DECKERS CORPORATION')
                        || '</DC>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RN>'
                        || DBMS_XMLGEN.CONVERT (
                               'Report Name :Deckers PO Projected Supply Forecast Report')
                        || '</RN>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RD>'
                        || DBMS_XMLGEN.CONVERT (
                               'Report Date - :' || v_report_date)
                        || '</RD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RM>'
                        || DBMS_XMLGEN.CONVERT (
                               'Run Mode is :' || pv_run_mode)
                        || '</RM>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<PM>'
                        || DBMS_XMLGEN.CONVERT (
                               'PO Model is :' || pv_po_model)
                        || '</PM>');                                  -- Added
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<OR>'
                        || DBMS_XMLGEN.CONVERT (
                               'OVERRIDE is :' || pv_override)
                        || '</OR>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<FP>'
                        || DBMS_XMLGEN.CONVERT (
                               'Starting Period is :' || pv_from_period)
                        || '</FP>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<TP>'
                        || DBMS_XMLGEN.CONVERT (
                               'Ending Period is :' || pv_to_period)
                        || '</TP>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<IPDD>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Include Past Due Days is :'
                               || pn_incld_past_due_days)
                        || '</IPDD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<DDD>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Delay Delivery Days and Intransit Days are : '
                               || pn_delay_delivery_days
                               || ' and '
                               || pn_delay_intransit_days)
                        || '</DDD>');                                 -- Added
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<FPD>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Starting Promised Date is :'
                               || pv_from_promised_date)
                        || '</FPD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<TPD>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Ending Promised Date is :'
                               || pv_to_promised_date)
                        || '</TPD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<FXD>'
                        || DBMS_XMLGEN.CONVERT (
                               'Starting XF Date is :' || pv_from_xf_date)
                        || '</FXD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<TXD>'
                        || DBMS_XMLGEN.CONVERT (
                               'Ending XF Date is :' || pv_to_xf_date)
                        || '</TXD>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<SO>'
                        || DBMS_XMLGEN.CONVERT (
                               'Source Organization is :' || pv_source_org)
                        || '</SO>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<DO>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Destination Organization is :'
                               || pv_destination_org)
                        || '</DO>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RDT>'
                        || DBMS_XMLGEN.CONVERT (
                                  'Rate Date is :'
                               || TO_DATE (pv_rate_date,
                                           'RRRR/MM/DD HH24:MI:SS'))
                        || '</RDT>');
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           '<RT>'
                        || DBMS_XMLGEN.CONVERT (
                               'Rate Type is :' || pv_rate_type)
                        || '</RT>');
                    apps.fnd_file.put_line (apps.fnd_file.output,
                                            '</PARAMGRP>');
                    fnd_file.put_line (
                        fnd_file.output,
                        '<BND>' || DBMS_XMLGEN.CONVERT (i.brand) || '</BND>');

                    OPEN rev_data_cur (i.brand);

                    LOOP
                        FETCH rev_data_cur INTO rev_output_row;

                        EXIT WHEN rev_data_cur%NOTFOUND;

                        fnd_file.put_line (fnd_file.output, '<ROW>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<BRAND>'
                            || DBMS_XMLGEN.CONVERT (rev_output_row.brand)
                            || '</BRAND>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<DEPT>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.department)
                            || '</DEPT>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<IC>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.item_category)
                            || '</IC>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<IS>'
                            || DBMS_XMLGEN.CONVERT (rev_output_row.item_sku)
                            || '</IS>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<FPI>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.from_period_identifier)
                            || '</FPI>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<TPI>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.to_period_identifier)
                            || '</TPI>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<DSO>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.source_org)
                            || '</DSO>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<RXD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.requested_xf_date)
                            || '</RXD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<OCXD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.orig_confirmed_xf_date)
                            || '</OCXD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<CXD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.confirmed_xf_date)
                            || '</CXD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<ACD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.asn_creation_date)
                            || '</ACD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<XSD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.xf_shipment_date)
                            || '</XSD>');
                        -- Added
                        fnd_file.put_line (
                            fnd_file.output,
                               '<PD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.promised_date)
                            || '</PD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<ERD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.expected_receipt_date)
                            || '</ERD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<OPD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.original_promise_date)
                            || '</OPD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<IRD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.intransit_receipt_date)
                            || '</IRD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<OIRD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.orig_intransit_receipt_date)
                            || '</OIRD>');
                        -- Added
                        fnd_file.put_line (
                            fnd_file.output,
                               '<DDO>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.destination_org)
                            || '</DDO>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<PERD>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.promise_expected_receipt_date)
                            || '</PERD>');
                        -- fnd_file.put_line(fnd_file.output,'<OPD>'||dbms_xmlgen.convert(rev_output_row.original_promise_date)||'</OPD>');
                        -- fnd_file.put_line(fnd_file.output,'<IRD>'||dbms_xmlgen.convert(rev_output_row.intransit_receipt_date)||'</IRD>');
                        -- fnd_file.put_line(fnd_file.output,'<OIRD>'||dbms_xmlgen.convert(rev_output_row.orig_intransit_receipt_date)||'</OIRD>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<FV>'
                            || DBMS_XMLGEN.CONVERT (rev_output_row.fob_value)
                            || '</FV>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<QTY>'
                            || DBMS_XMLGEN.CONVERT (rev_output_row.quantity)
                            || '</QTY>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<SM>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.ship_method)
                            || '</SM>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<PC>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.po_currency)
                            || '</PC>');
                        fnd_file.put_line (
                            fnd_file.output,
                               '<FVIU>'
                            || DBMS_XMLGEN.CONVERT (
                                   rev_output_row.fob_value_in_usd)
                            || '</FVIU>');

                        IF pv_run_mode = 'Review'
                        THEN
                            fnd_file.put_line (
                                fnd_file.output,
                                '<CF>' || DBMS_XMLGEN.CONVERT ('') || '</CF>');
                            fnd_file.put_line (
                                fnd_file.output,
                                '<OS>' || DBMS_XMLGEN.CONVERT ('') || '</OS>');
                        ELSIF pv_run_mode = 'Insert'
                        THEN
                            fnd_file.put_line (
                                fnd_file.output,
                                   '<CF>'
                                || DBMS_XMLGEN.CONVERT (
                                       rev_output_row.calculated_flag)
                                || '</CF>');
                            fnd_file.put_line (
                                fnd_file.output,
                                   '<OS>'
                                || DBMS_XMLGEN.CONVERT (
                                       rev_output_row.override_status)
                                || '</OS>');
                        END IF;

                        fnd_file.put_line (
                            fnd_file.output,
                               '<SRC>'
                            || DBMS_XMLGEN.CONVERT (rev_output_row.source)
                            || '</SRC>');
                        fnd_file.put_line (fnd_file.output, '</ROW>');
                    END LOOP;

                    CLOSE rev_data_cur;

                    fnd_file.put_line (fnd_file.output, '</PBRAND>');
                END LOOP;
            END IF;

            fnd_file.put_line (fnd_file.output, '</OUTPUT>');
            fnd_file.put_line (fnd_file.output, '</MAIN>');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Exception while generate the XML:' || SQLERRM);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'XML Output Ends' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

        BEGIN
            BEGIN
                SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                  INTO v_report_date
                  FROM sys.DUAL;
            END;

            IF pv_run_mode = 'Review' OR pv_run_mode = 'Insert'
            THEN
                write_rev_ins_output_prc (v_report_date, pv_run_mode, pv_po_model -- Added
                                                                                 , pv_override, pv_from_period, pv_to_period, pn_incld_past_due_days, pn_delay_delivery_days, -- Added
                                                                                                                                                                              pn_delay_intransit_days, -- Added as per CCR0009989
                                                                                                                                                                                                       pv_from_promised_date, pv_to_promised_date, pv_from_xf_date, pv_to_xf_date, pv_source_org, pv_destination_org
                                          , pv_rate_date, pv_rate_type);
            -- fnd_file.put_line(fnd_file.log, 'Review - Data Removed for the Request ID'||gn_request_id);

            -- EXECUTE IMMEDIATE 'DELETE xxdo.xxd_po_proj_fc_rev_stg_t
            -- WHERE request_id = '||gn_request_id;

            ELSIF pv_run_mode = 'Report'
            THEN
                BEGIN
                    SELECT organization_name
                      INTO lv_src_org
                      FROM apps.org_organization_definitions
                     WHERE organization_id = pv_source_org;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_src_org   := NULL;
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Unable to retrive Source Org');
                END;


                BEGIN
                    SELECT organization_name
                      INTO lv_dest_org
                      FROM apps.org_organization_definitions
                     WHERE organization_id = pv_destination_org;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_dest_org   := NULL;
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Unable to retrive Destination Org');
                END;


                write_rep_output_prc (v_report_date,
                                      pv_run_mode,
                                      pv_override,
                                      pv_po_model,                    -- Added
                                      pv_from_period,
                                      pv_to_period,
                                      pn_incld_past_due_days,
                                      pn_delay_delivery_days,         -- Added
                                      pn_delay_intransit_days, -- Added as per CCR0009989
                                      pv_from_promised_date,
                                      pv_to_promised_date,
                                      pv_from_xf_date,
                                      pv_to_xf_date,
                                      pv_source_org,
                                      pv_destination_org,
                                      pv_rate_date,
                                      pv_rate_type,
                                      lv_from_period_date,
                                      lv_to_period_date,
                                      lv_src_org,
                                      lv_dest_org);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Exception while generate the output files:' || SQLERRM);
        END;

        IF pv_run_mode = 'Insert'
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Deckers In-Transit Program Stats...');

            BEGIN
                lv_vo_org   := NULL;

                SELECT lookup_code
                  INTO lv_vo_org
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXD_PO_FORECAST_ORGS'
                       AND language = 'US'
                       AND tag = 'VO'
                       AND enabled_flag = 'Y'
                       AND lookup_code = NVL (pv_source_org, lookup_code)
                       AND SYSDATE BETWEEN NVL (start_date_active,
                                                SYSDATE - 1)
                                       AND NVL (end_date_active, SYSDATE + 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vo_org   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unable to retrive Org ID for the source org'
                        || pv_source_org);
            END;


            IF pv_source_org = lv_vo_org
            THEN
                BEGIN
                    FOR i IN ic_org_cur
                    LOOP
                        ln_layout   := NULL;
                        ln_req_id   := NULL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Calling In-Transit Forecast Report for the Organization'
                            || i.organization_id);

                        ln_layout   :=
                            fnd_request.add_layout (
                                template_appl_name   => 'XXDO',
                                template_code        =>
                                    'XXD_INTRANSIT_FORECAST_RPT',
                                template_language    => 'en',
                                template_territory   => 'US',
                                output_format        => 'EXCEL');

                        ln_req_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDO',
                                program       => 'XXD_INTRANSIT_FORECAST_RPT',
                                argument1     => i.organization_id,
                                argument2     => NULL,
                                argument3     => NULL,
                                argument4     => NULL,
                                argument5     => NULL,
                                argument6     => 'Y',
                                argument7     => NULL,
                                argument8     => 'Y',
                                argument9     => NULL,
                                argument10    => NULL,
                                argument11    => NULL,
                                start_time    => SYSDATE,
                                sub_request   => FALSE);
                        COMMIT;

                        IF ln_req_id = 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Request Not Submitted due to "'
                                || fnd_message.get
                                || '".');
                        ELSE
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Deckers In-Transit Forecast Report submitted successfully – Request id :'
                                || ln_req_id);
                        END IF;
                    END LOOP;
                END;
            ELSE
                BEGIN
                    FOR i IN dest_org_cur
                    LOOP
                        ln_layout   := NULL;
                        ln_req_id   := NULL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Calling In-Transit Forecast Report for the Organization'
                            || i.organization_id);

                        ln_layout   :=
                            fnd_request.add_layout (
                                template_appl_name   => 'XXDO',
                                template_code        =>
                                    'XXD_INTRANSIT_FORECAST_RPT',
                                template_language    => 'en',
                                template_territory   => 'US',
                                output_format        => 'EXCEL');

                        ln_req_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDO',
                                program       => 'XXD_INTRANSIT_FORECAST_RPT',
                                argument1     => i.organization_id,
                                argument2     => NULL,
                                argument3     => NULL,
                                argument4     => NULL,
                                argument5     => NULL,
                                argument6     => 'Y',
                                argument7     => NULL,
                                argument8     => 'Y',
                                argument9     => NULL,
                                argument10    => NULL,
                                argument11    => NULL,
                                start_time    => SYSDATE,
                                sub_request   => FALSE);
                        COMMIT;

                        IF ln_req_id = 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Request Not Submitted due to "'
                                || fnd_message.get
                                || '".');
                        ELSE
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Deckers In-Transit Forecast Report submitted successfully – Request id :'
                                || ln_req_id);
                        END IF;
                    END LOOP;
                END;
            END IF;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Report Process Ends - Main Prc Ends'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Main PRC - sqlerrm:' || SQLERRM);
            retcode   := 2;
    END main_prc;
END xxd_po_projected_forecast_pkg;
/
