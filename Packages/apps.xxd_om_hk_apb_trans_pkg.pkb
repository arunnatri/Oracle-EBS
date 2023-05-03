--
-- XXD_OM_HK_APB_TRANS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OM_HK_APB_TRANS_PKG"
AS
    /*****************************************************************************************
      * Package         : XXD_OM_HK_APB_TRANS_PKG
      * Description     : Package is used for APB to HK Transactional Value Report – Deckers
      * Notes           :
      * Modification    :
      *-------------------------------------------------------------------------------------
      * Date         Version#      Name                       Description
      *-------------------------------------------------------------------------------------
      * 10-JAN-2023  1.0           Aravind Kannuri            Initial Version for CCR0009817
      *
      ****************************************************************************************/

    FUNCTION get_email_id
        RETURN VARCHAR2
    IS
        l_return   VARCHAR2 (1000);
    BEGIN
        BEGIN
            SELECT LISTAGG (flv.description, ';') WITHIN GROUP (ORDER BY flv.description)
              INTO l_return
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_OM_HK_APB_EMAIL_LKP'
                   AND enabled_flag = 'Y'
                   AND language = 'US'
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_return   := NULL;
        END;

        RETURN l_return;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_email_id;

    --Get ship to address
    FUNCTION get_ship_to_address (
        p_site_use_id IN hz_cust_site_uses_all.site_use_id%TYPE)
        RETURN VARCHAR2
    IS
        CURSOR c_get_location_dtls IS
            SELECT hl.location_id,
                   hl.address1,
                   hl.address2,
                   hl.address3,
                   hl.address4,
                   hl.city,
                   hl.state,
                   hl.postal_code,
                   (SELECT territory_short_name country
                      FROM fnd_territories_vl
                     WHERE territory_code = hl.country) country
              FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas, hz_party_sites hps,
                   hz_locations hl
             WHERE     hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                   AND hcas.party_site_id = hps.party_site_id
                   AND hps.location_id = hl.location_id
                   AND hcsu.site_use_id = p_site_use_id;

        lx_shipto_formatted_address   VARCHAR2 (4000) := NULL;
    BEGIN
        FOR c_rec IN c_get_location_dtls
        LOOP
            IF c_rec.address1 IS NOT NULL
            THEN
                lx_shipto_formatted_address   := c_rec.address1;
            END IF;

            IF c_rec.address2 IS NOT NULL
            THEN
                lx_shipto_formatted_address   :=
                    lx_shipto_formatted_address || ', ' || c_rec.address2;
            END IF;

            IF c_rec.address3 IS NOT NULL
            THEN
                lx_shipto_formatted_address   :=
                    lx_shipto_formatted_address || ', ' || c_rec.address3;
            END IF;

            IF c_rec.address4 IS NOT NULL
            THEN
                lx_shipto_formatted_address   :=
                    lx_shipto_formatted_address || ', ' || c_rec.address4;
            END IF;

            IF c_rec.city IS NOT NULL
            THEN
                lx_shipto_formatted_address   :=
                    lx_shipto_formatted_address || ', ' || c_rec.city;
            END IF;

            IF c_rec.country IS NOT NULL
            THEN
                lx_shipto_formatted_address   :=
                    lx_shipto_formatted_address || ', ' || c_rec.country;
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'lx_shipto_formatted_address :' || lx_shipto_formatted_address);

        RETURN lx_shipto_formatted_address;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in ship_to_address: ' || SQLERRM);
            RETURN NULL;
    END get_ship_to_address;

    PROCEDURE generate_exception_report_prc (
        pv_directory_path   IN     VARCHAR2,
        pv_exc_file_name       OUT VARCHAR2)
    IS
        CURSOR c_cur IS
            SELECT item_number, item_style, item_color,
                   asn_po_exists_flag, item_exists_lkp
              FROM xxdo.xxd_om_hk_apb_tran_gt
             WHERE     request_id = gn_request_id
                   AND (NVL (asn_po_exists_flag, 'N') = 'Y' OR NVL (item_exists_lkp, 'N') = 'Y');

        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_directory_path   VARCHAR2 (2000);
        lv_file_name        VARCHAR2 (4000);
        l_line              VARCHAR2 (4000);
        lv_result           VARCHAR2 (1000);
        lv_line             VARCHAR2 (32767) := NULL;
    BEGIN
        lv_outbound_file    :=
               gn_request_id
            || '_Exception_HK_APB_Transactional_Value_RPT_'
            || TO_CHAR (SYSDATE, 'YYYYMMDD')
            || '.xls';

        lv_directory_path   := pv_directory_path;
        lv_output_file      :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                            32767);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            lv_line   :=
                   'Item Number'
                || CHR (9)
                || 'Item Style'
                || CHR (9)
                || 'Item Color'
                || CHR (9)
                || 'ASN/PO Not Exists in APB'
                || CHR (9)
                || 'Item Style Missing in Lookup';

            UTL_FILE.put_line (lv_output_file, lv_line);

            FOR c_rec IN c_cur
            LOOP
                lv_line   :=
                       NVL (c_rec.item_number, '')
                    || CHR (9)
                    || NVL (c_rec.item_style, '')
                    || CHR (9)
                    || NVL (c_rec.item_color, '')
                    || CHR (9)
                    || NVL (c_rec.asn_po_exists_flag, '')
                    || CHR (9)
                    || NVL (c_rec.item_exists_lkp, '');

                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Error in Opening the data file for writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file);
        pv_exc_file_name    := lv_outbound_file;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            raise_application_error (-20109, lv_err_msg);
    END generate_exception_report_prc;

    FUNCTION populate_data_main (p_order_number IN VARCHAR2, p_pick_ticket IN VARCHAR2, p_date_from IN VARCHAR2
                                 , p_date_to IN VARCHAR2)
        RETURN BOOLEAN
    IS
        l_return               VARCHAR2 (1000);
        l_last_run_date        VARCHAR2 (1000);
        l_run_date             VARCHAR2 (1000);
        l_folder_loc           VARCHAR2 (1000);
        l_email_id             VARCHAR2 (1000);
        l_file_name            VARCHAR2 (1000);
        l_date                 VARCHAR2 (1000);
        l_cur_qry              VARCHAR2 (4000);
        l_cur                  SYS_REFCURSOR;
        l_rec                  item_rec;
        l_price                NUMBER;
        l_asn_po_exists_flag   VARCHAR2 (1);
        l_item_exists_lkp      VARCHAR2 (1);
        l_item_id              NUMBER := -1;
        l_organization_id      NUMBER;
    BEGIN
        l_cur_qry     :=
            'SELECT ola.inventory_item_id, mp.organization_id, oha.order_number,                     
					 hca.account_number customer_number,hp.party_name customer_name,
					 XXD_OM_HK_APB_TRANS_PKG.get_ship_to_address (oha.ship_to_org_id) ship_to_address,
                     wda.delivery_id pick_ticket_number, oha.cust_po_number, wdd.shipped_quantity
        FROM apps.oe_order_headers_all oha,
             apps.oe_order_lines_all ola,
             apps.wsh_delivery_details wdd,
			 apps.wsh_delivery_assignments wda,
			 apps.hz_cust_accounts hca,
             apps.hz_parties hp,
             apps.mtl_parameters mp
        WHERE oha.header_id = ola.header_id
              AND oha.header_id = wdd.source_header_id
              AND ola.line_id = wdd.source_line_id		  
			  AND wdd.delivery_detail_id = wda.delivery_detail_id
			  AND hca.cust_account_id = oha.sold_to_org_id
              AND hca.party_id = hp.party_id
			  AND wdd.source_code = ''OE''
              AND wdd.shipped_quantity > 0
              AND oha.booked_flag = ''Y''
              AND   ola.cancelled_flag <> ''Y''
             AND ( ola.ship_from_org_id = mp.organization_id   OR oha.ship_from_org_id = mp.organization_id ) 
             and mp.organization_code=''APB''  ';

        IF p_date_from IS NULL AND p_date_to IS NULL
        THEN
            BEGIN
                SELECT NVL (description, TO_CHAR (SYSDATE - 1, 'YYYY/MM/DD hh24:MI:SS')), TO_CHAR (SYSDATE, 'YYYY/MM/DD hh24:MI:SS')
                  INTO l_last_run_date, l_run_date
                  FROM fnd_lookup_values flv
                 WHERE     lookup_type = 'XXD_OM_HK_APB_LAST_RUN_LKP'
                       AND enabled_flag = 'Y'
                       AND lookup_code = 'RUN_DATE'
                       AND language = 'US'
                       AND SYSDATE BETWEEN TRUNC (
                                               NVL (start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                                 NVL (end_date_active,
                                                      SYSDATE)
                                               + 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_last_run_date   :=
                        TO_CHAR (SYSDATE - 1, 'YYYY/MM/DD hh24:MI:SS');
                    l_run_date   :=
                        TO_CHAR (SYSDATE, 'YYYY/MM/DD hh24:MI:SS');
            END;
        ELSE
            l_last_run_date   := NULL;
        END IF;

        IF l_last_run_date IS NOT NULL
        THEN
            IF (p_order_number IS NULL AND p_pick_ticket IS NULL)
            THEN
                l_cur_qry   :=
                       l_cur_qry
                    || ' AND wdd.last_update_date >= TO_DATE('''
                    || l_last_run_date
                    || ''', ''YYYY/MM/DD HH24:MI:SS'') ';
            END IF;
        END IF;

        IF p_date_from IS NOT NULL
        THEN
            l_cur_qry   :=
                   l_cur_qry
                || ' AND wdd.last_update_date >= TO_DATE('''
                || p_date_from
                || ''', ''YYYY/MM/DD HH24:MI:SS'') ';
        END IF;

        IF p_date_to IS NOT NULL
        THEN
            l_cur_qry   :=
                   l_cur_qry
                || ' AND wdd.last_update_date <= TO_DATE('''
                || p_date_to
                || ''', ''YYYY/MM/DD HH24:MI:SS'') ';
        END IF;

        IF p_order_number IS NOT NULL
        THEN
            l_cur_qry   :=
                   l_cur_qry
                || ' AND oha.order_number = '''
                || p_order_number
                || '''';
        END IF;

        IF p_pick_ticket IS NOT NULL
        THEN
            l_cur_qry   :=
                   l_cur_qry
                || ' AND wda.delivery_id = '''
                || p_pick_ticket
                || '''';
        END IF;

        l_cur_qry     := l_cur_qry || ' order by  ola.inventory_item_id ';
        l_email_id    := xxd_om_hk_apb_trans_pkg.get_email_id;

        l_file_name   := 'Global_Trade_Report_APB_' || l_date || '.xls';

        fnd_file.put_line (fnd_file.LOG, 'l_cur_qry :' || l_cur_qry);
        fnd_file.put_line (fnd_file.LOG, 'gn_request_id : ' || gn_request_id);

        BEGIN
            OPEN l_cur FOR l_cur_qry;

            LOOP
                FETCH l_cur INTO l_rec;

                EXIT WHEN l_cur%NOTFOUND;

                l_item_id           := l_rec.inventory_item_id;
                l_organization_id   := l_rec.organization_id;

                --Calculate Item cost by using standalone Function
                BEGIN
                    l_price   :=
                        APPS.XXD_GET_ITEM_PRICE_FNC (
                            p_inventory_item_id   => l_item_id,
                            p_organization_id     => l_organization_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_price   := NULL;
                END;

                BEGIN
                    INSERT INTO xxdo.xxd_om_hk_apb_tran_gt (request_id, order_number, customer_number, customer_name, ship_to_address, pick_ticket_number, cust_po_number, inventory_item_id, price, item_style, item_color, item_size, shipping_unit, shipping_org, item_number, asn_po_exists_flag, item_exists_lkp, email_id
                                                            , file_name)
                         VALUES (gn_request_id, l_rec.order_number, l_rec.customer_number, l_rec.customer_name, l_rec.ship_to_address, l_rec.pick_ticket_number, l_rec.cust_po_number, l_rec.inventory_item_id, l_price, NULL, NULL, NULL, l_rec.shipped_quantity, 'APB', NULL, l_asn_po_exists_flag, l_item_exists_lkp, l_email_id
                                 , l_file_name);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'EXP- OTHERS: INSERT INTO xxdo.xxd_om_hk_apb_tran_gt'
                            || SQLERRM);
                        NULL;
                END;
            END LOOP;

            CLOSE l_cur;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'EXP- OTHERS: CLOSE l_cur :' || SQLERRM);

                CLOSE l_cur;
        END;

        UPDATE xxdo.xxd_om_hk_apb_tran_gt gt
           SET (item_style, item_color, item_size,
                item_number)   =
                   (SELECT xci.style_number, xci.color_code, xci.item_size,
                           xci.item_number
                      FROM xxd_common_items_v xci, mtl_parameters mp
                     WHERE     xci.inventory_item_id = gt.inventory_item_id
                           AND xci.organization_id = mp.organization_id
                           AND mp.organization_code = 'APB'            --'US7'
                                                           );

        BEGIN
            SELECT TO_CHAR (SYSDATE, 'YYYYMMDD') INTO l_date FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_date   := NULL;
        END;


        IF p_date_from IS NULL AND p_date_to IS NULL
        THEN
            BEGIN
                UPDATE fnd_lookup_values flv
                   SET description   = l_run_date
                 WHERE     lookup_type = 'XXD_OM_HK_APB_LAST_RUN_LKP'
                       AND lookup_code = 'RUN_DATE';
            END;
        END IF;

        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'sqlerrm:' || SQLERRM);
            RETURN (TRUE);
    END populate_data_main;

    FUNCTION after_report_main (p_order_number IN VARCHAR2, p_pick_ticket IN VARCHAR2, p_date_from IN VARCHAR2
                                , p_date_to IN VARCHAR2)
        RETURN BOOLEAN
    IS
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        lv_message              VARCHAR2 (32000);
        lv_recipients           VARCHAR2 (4000);
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        l_cnt                   NUMBER;
        ln_request_id           NUMBER;
        ln_burst_req_id         NUMBER;
        l_target_file_name      VARCHAR2 (1000);
        l_target_file_path      VARCHAR2 (1000);
        l_bur_cnt               NUMBER;
    BEGIN
        BEGIN
            SELECT COUNT (*)
              INTO l_cnt
              FROM xxdo.xxd_om_hk_apb_tran_gt
             WHERE     request_id = gn_request_id
                   AND order_number = NVL (p_order_number, order_number)
                   AND (NVL (asn_po_exists_flag, 'N') = 'Y' OR NVL (item_exists_lkp, 'N') = 'Y');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_cnt   := 0;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO l_bur_cnt
              FROM xxdo.xxd_om_hk_apb_tran_gt
             WHERE request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_bur_cnt   := 0;
        END;

        BEGIN
            lv_exc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_exc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_ONT_REPORT_OUT_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_exc_directory_path   := NULL;
        END;

        lv_recipients   := xxd_om_hk_apb_trans_pkg.get_email_id;

        IF lv_recipients IS NOT NULL AND NVL (l_bur_cnt, 0) > 0
        THEN
            ln_burst_req_id   :=
                fnd_request.submit_request (
                    application   => 'XDO',
                    program       => 'XDOBURSTREP',
                    description   => 'XML Publisher Report Bursting Program',
                    argument1     => 'Y',
                    argument2     => gn_request_id,
                    argument3     => 'Y');

            fnd_file.put_line (fnd_file.LOG,
                               'Bursting Request ID  - ' || ln_burst_req_id);

            IF ln_burst_req_id <= 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Failed to submit Bursting XML Publisher Request for Request ID = '
                    || ln_request_id);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Submitted Bursting XML Publisher Request Request ID = '
                    || ln_burst_req_id);
            END IF;
        END IF;

        IF l_cnt > 0
        THEN
            lv_exc_file_name   := NULL;
            generate_exception_report_prc (lv_exc_directory_path,
                                           lv_exc_file_name);
            lv_exc_file_name   :=
                   lv_exc_directory_path
                || lv_mail_delimiter
                || lv_exc_file_name;
            lv_message         :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please Find the Attached HK to APB Transactional Value Report - Deckers Exception Report. '
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN.'
                || CHR (10)
                || CHR (10)
                || 'Note: This is auto generated mail, please donot reply.';

            xxdo_mail_pkg.send_mail (
                pv_sender         => 'erp@deckers.com',
                pv_recipients     => lv_recipients,
                pv_ccrecipients   => NULL,
                pv_subject        =>
                    'HK to APB Transactional Value Report - Deckers Exception Report',
                pv_message        => lv_message,
                pv_attachments    => lv_exc_file_name,
                xv_result         => lv_result,
                xv_result_msg     => lv_result_msg);

            BEGIN
                UTL_FILE.fremove (lv_exc_directory_path, lv_exc_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'send_exception_rpt sqlerrm:' || SQLERRM);
            RETURN TRUE;
    END;
END XXD_OM_HK_APB_TRANS_PKG;
/
