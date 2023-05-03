--
-- XXD_OM_ODC_US_TRAN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OM_ODC_US_TRAN_PKG"
AS
    /******************************************************************************************
    NAME           : XXD_OM_ODC_US_TRAN_PKG
    REPORT NAME    : DIRECTSHIP – ODC TO US TRANSACTIONAL VALUE

    REVISIONS:
    Date            Author                  Version     Description
    ----------      ----------              -------     ---------------------------------------------------
    10-JUN-2022     Laltu Sah                 1.0         Intitial Version
    10-FEB-2023     Laltu Sah                 1.1         CCR0010402
    *********************************************************************************************/

    FUNCTION get_email_id
        RETURN VARCHAR2
    IS
        l_return   VARCHAR2 (1000);
    BEGIN
        BEGIN
            SELECT LISTAGG (flv.description, ';') WITHIN GROUP (ORDER BY flv.description)
              INTO l_return
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_OM_ODC_US_EMAIL_LKP'
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

    PROCEDURE get_item_details (p_inventory_item_id NUMBER, o_commercial_invoice OUT VARCHAR2, o_po_number OUT VARCHAR2, o_price OUT NUMBER, o_po_receipt_date OUT DATE, o_po_received_location OUT VARCHAR2, o_units_received OUT NUMBER, o_asn_po_exists_flag OUT VARCHAR2, o_item_exists_lkp OUT VARCHAR2
                                , o_tot_po_qty OUT NUMBER)
    IS
        l_commercial_invoice     VARCHAR2 (25);
        l_po_number              VARCHAR2 (140);
        l_price                  NUMBER;
        l_po_receipt_date        DATE;
        l_po_received_location   VARCHAR2 (100);
        l_units_received         NUMBER;
        l_item_style             VARCHAR2 (240);
        l_item_color             VARCHAR2 (240);
        l_asn_po_exists_flag     VARCHAR2 (1);
        l_item_exists_lkp        VARCHAR2 (1);
        l_item_size              VARCHAR2 (240);
        l_po_header_id           NUMBER;
        l_po_qty                 NUMBER;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        BEGIN
            SELECT commercial_invoice, po_number, unit_price,
                   transaction_date, organization_code, units_received,
                   style_number, color_code, item_size,
                   po_header_id
              INTO l_commercial_invoice, l_po_number, l_price, l_po_receipt_date,
                                       l_po_received_location, l_units_received, l_item_style,
                                       l_item_color, l_item_size, l_po_header_id
              FROM (  SELECT rsl.packing_slip commercial_invoice, pha.segment1 po_number, pha.po_header_id,
                             pla.unit_price, rt.transaction_date, mp.organization_code,
                             rt.primary_quantity units_received, xci.style_number, xci.color_code,
                             xci.item_size
                        FROM rcv_transactions rt, po_headers_all pha, po_lines_all pla,
                             rcv_shipment_lines rsl, mtl_parameters mp, xxd_common_items_v xci
                       WHERE     rt.po_line_id = pla.po_line_id
                             AND rt.po_header_id = pha.po_header_id
                             AND rt.shipment_line_id = rsl.shipment_line_id
                             AND rt.transaction_type = 'RECEIVE'
                             AND mp.organization_id = rt.organization_id
                             AND mp.organization_code IN ('US1', 'US6')
                             AND rsl.item_id = xci.inventory_item_id
                             AND mp.organization_id = xci.organization_id
                             AND rsl.item_id = p_inventory_item_id
                             AND rt.transaction_date >= SYSDATE - 365 -- Added for 1.1
                    ORDER BY rt.transaction_date DESC)
             WHERE ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    l_asn_po_exists_flag   := 'Y';

                    SELECT description, tag
                      INTO l_item_style, l_price
                      FROM fnd_lookup_values flv
                     WHERE     flv.lookup_type LIKE
                                   'XXD_DS_IMPORT_STYLE_PRICE_LKP'
                           AND flv.enabled_flag = 'Y'
                           AND NVL (flv.end_date_active, SYSDATE + 1) >
                               SYSDATE
                           AND flv.language = USERENV ('LANG')
                           AND EXISTS
                                   (SELECT 1
                                      FROM xxd_common_items_v xci
                                     WHERE     xci.inventory_item_id =
                                               p_inventory_item_id
                                           AND xci.style_number = flv.meaning);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        BEGIN
                            l_item_exists_lkp   := 'Y';

                            SELECT commercial_invoice, po_number, unit_price,
                                   transaction_date, organization_code, units_received,
                                   style_number, color_code, item_size,
                                   po_header_id
                              INTO l_commercial_invoice, l_po_number, l_price, l_po_receipt_date,
                                                       l_po_received_location, l_units_received, l_item_style,
                                                       l_item_color, l_item_size, l_po_header_id
                              FROM (  SELECT rsl.packing_slip commercial_invoice, pha.segment1 po_number, pla.unit_price,
                                             rt.transaction_date, mp.organization_code, rt.primary_quantity units_received,
                                             xci.style_number, xci.color_code, xci.item_size,
                                             pha.po_header_id
                                        FROM rcv_transactions rt, po_headers_all pha, po_lines_all pla,
                                             rcv_shipment_lines rsl, mtl_parameters mp, xxd_common_items_v xci
                                       WHERE     rt.po_line_id = pla.po_line_id
                                             AND rt.po_header_id =
                                                 pha.po_header_id
                                             AND rt.shipment_line_id =
                                                 rsl.shipment_line_id
                                             AND rt.transaction_type =
                                                 'RECEIVE'
                                             AND mp.organization_id =
                                                 rt.organization_id
                                             AND mp.organization_code IN
                                                     ('US7')
                                             AND rsl.item_id =
                                                 xci.inventory_item_id
                                             AND mp.organization_id =
                                                 xci.organization_id
                                             AND rsl.item_id =
                                                 p_inventory_item_id
                                    ORDER BY rt.transaction_date DESC)
                             WHERE ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            SELECT SUM (pda.quantity_ordered - pda.quantity_cancelled)
              INTO l_po_qty
              FROM po_distributions_all pda, po_lines_all pla
             WHERE     pda.po_line_id = pla.po_line_id
                   AND pla.po_header_id = l_po_header_id
                   AND pla.item_id = p_inventory_item_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_po_qty   := NULL;
        END;

        o_commercial_invoice     := l_commercial_invoice;
        o_po_number              := l_po_number;
        o_price                  := l_price;
        o_po_receipt_date        := l_po_receipt_date;
        o_po_received_location   := l_po_received_location;
        o_units_received         := l_units_received;
        o_asn_po_exists_flag     := l_asn_po_exists_flag;
        o_item_exists_lkp        := l_item_exists_lkp;
        o_tot_po_qty             := l_po_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END get_item_details;

    PROCEDURE generate_exception_report_prc (
        pv_directory_path   IN     VARCHAR2,
        pv_exc_file_name       OUT VARCHAR2)
    IS
        CURSOR c_cur IS
            SELECT item_number, item_style, item_color,
                   asn_po_exists_flag, item_exists_lkp
              FROM xxdo.xxd_om_odc_us_tran_gt
             WHERE     request_id = gn_request_id
                   AND (asn_po_exists_flag = 'Y' OR item_exists_lkp = 'Y');

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
            || '_Exception_ODC_US_Transactional_Value_RPT_'
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
                || 'ASN/PO Not Exists in (US1 & US6)'
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

    FUNCTION get_po_receipt_det (p_inventory_item_id   IN VARCHAR2,
                                 p_type                   VARCHAR2)
        RETURN VARCHAR2
    IS
        l_check                  NUMBER;
        l_commercial_invoice     VARCHAR2 (25);
        l_po_number              VARCHAR2 (140);
        l_price                  NUMBER;
        l_po_receipt_date        DATE;
        l_po_received_location   VARCHAR2 (100);
        l_units_received         NUMBER;
        l_type                   VARCHAR2 (20);
    BEGIN
        BEGIN
            SELECT COUNT (*)
              INTO l_check
              FROM xxdo.xxd_om_odc_us_tran_gt
             WHERE     inventory_item_id = p_inventory_item_id
                   AND request_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_check   := 0;
        END;

        IF l_check = 0
        THEN
            NULL;
        END IF;

        BEGIN
            SELECT commercial_invoice, po_number, price,
                   po_receipt_date, po_received_location, units_received
              INTO l_commercial_invoice, l_po_number, l_price, l_po_receipt_date,
                                       l_po_received_location, l_units_received
              FROM xxdo.xxd_om_odc_us_tran_gt
             WHERE inventory_item_id = p_inventory_item_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        l_type   := UPPER (p_type);

        IF l_type = 'COM_INV'
        THEN
            RETURN l_commercial_invoice;
        END IF;

        IF l_type = 'PO_NUM'
        THEN
            RETURN l_po_number;
        END IF;

        IF l_type = 'PO_PRICE'
        THEN
            RETURN TO_CHAR (l_price);
        END IF;

        IF l_type = 'PO_RCPT_DATE'
        THEN
            RETURN TO_CHAR (l_po_receipt_date);
        END IF;

        IF l_type = 'PO_RCV_LOC'
        THEN
            RETURN l_po_received_location;
        END IF;

        IF l_type = 'PO_RCV_UNIT'
        THEN
            RETURN TO_CHAR (l_units_received);
        END IF;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_po_receipt_det;

    FUNCTION populate_data_main (p_order_number IN VARCHAR2, p_date_from VARCHAR2, p_date_to VARCHAR2)
        RETURN BOOLEAN
    IS
        l_return                 VARCHAR2 (1000);
        l_last_run_date          VARCHAR2 (1000);
        l_run_date               VARCHAR2 (1000);
        l_folder_loc             VARCHAR2 (1000);
        l_email_id               VARCHAR2 (1000);
        l_file_name              VARCHAR2 (1000);
        l_date                   VARCHAR2 (1000);
        l_cur_qry                VARCHAR2 (4000);
        l_cur                    SYS_REFCURSOR;
        l_rec                    item_rec;
        l_commercial_invoice     VARCHAR2 (25);
        l_po_number              VARCHAR2 (140);
        l_price                  NUMBER;
        l_po_receipt_date        DATE;
        l_po_received_location   VARCHAR2 (100);
        l_units_received         NUMBER;
        l_asn_po_exists_flag     VARCHAR2 (1);
        l_item_exists_lkp        VARCHAR2 (1);
        l_tot_po_qty             NUMBER;
        l_item_id                NUMBER := -1;
    BEGIN
        l_cur_qry     :=
            'SELECT ola.inventory_item_id, oha.order_number,
                     oha.cust_po_number,wdd.shipped_quantity
        FROM apps.oe_order_headers_all oha,
             apps.oe_order_lines_all ola,
             apps.wsh_delivery_details wdd,
             mtl_parameters mp
        WHERE oha.header_id = ola.header_id
              AND oha.header_id = wdd.source_header_id
              AND ola.line_id = wdd.source_line_id
              AND wdd.shipped_quantity > 0
              AND oha.booked_flag = ''Y''
              AND   ola.cancelled_flag <> ''Y''
             AND ( ola.ship_from_org_id = mp.organization_id   OR oha.ship_from_org_id = mp.organization_id ) 
             and mp.organization_code=''US7''  ';

        IF p_date_from IS NULL AND p_date_to IS NULL
        THEN
            BEGIN
                SELECT NVL (description, TO_CHAR (SYSDATE - 1, 'YYYY/MM/DD hh24:MI:SS')), TO_CHAR (SYSDATE, 'YYYY/MM/DD hh24:MI:SS')
                  INTO l_last_run_date, l_run_date
                  FROM fnd_lookup_values flv
                 WHERE     lookup_type = 'XXD_OM_ODC_US_LAST_RUN_LKP'
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
            l_cur_qry   :=
                   l_cur_qry
                || ' AND wdd.last_update_date >= TO_DATE('''
                || l_last_run_date
                || ''', ''YYYY/MM/DD HH24:MI:SS'') ';
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
                l_cur_qry || ' AND oha.order_number =  ' || p_order_number;
        END IF;

        l_cur_qry     := l_cur_qry || ' order by  ola.inventory_item_id ';
        l_email_id    := xxd_om_odc_us_tran_pkg.get_email_id;
        l_file_name   := 'Global_Trade_Report_US7_' || l_date || '.xls';

        BEGIN
            OPEN l_cur FOR l_cur_qry;

            DBMS_OUTPUT.put_line ('1');

            LOOP
                FETCH l_cur INTO l_rec;

                EXIT WHEN l_cur%NOTFOUND;

                IF l_item_id <> l_rec.inventory_item_id
                THEN
                    get_item_details (p_inventory_item_id => l_rec.inventory_item_id, o_commercial_invoice => l_commercial_invoice, o_po_number => l_po_number, o_price => l_price, o_po_receipt_date => l_po_receipt_date, o_po_received_location => l_po_received_location, o_units_received => l_units_received, o_asn_po_exists_flag => l_asn_po_exists_flag, o_item_exists_lkp => l_item_exists_lkp
                                      , o_tot_po_qty => l_tot_po_qty);

                    DBMS_OUTPUT.put_line ('3');
                END IF;

                l_item_id   := l_rec.inventory_item_id;

                BEGIN
                    INSERT INTO xxdo.xxd_om_odc_us_tran_gt (
                                    request_id,
                                    inventory_item_id,
                                    commercial_invoice,
                                    po_number,
                                    price,
                                    po_receipt_date,
                                    po_received_location,
                                    units_received,
                                    item_style,
                                    order_number,
                                    item_color,
                                    cust_po_number,
                                    shipping_unit,
                                    shipping_org,
                                    item_number,
                                    asn_po_exists_flag,
                                    item_exists_lkp,
                                    email_id,
                                    file_name,
                                    item_size,
                                    tot_po_qty)
                         VALUES (gn_request_id, l_rec.inventory_item_id, l_commercial_invoice, l_po_number, l_price, l_po_receipt_date, l_po_received_location, l_units_received, NULL, l_rec.order_number, NULL, l_rec.cust_po_number, l_rec.shipped_quantity, 'US7', NULL, l_asn_po_exists_flag, l_item_exists_lkp, l_email_id
                                 , l_file_name, NULL, l_tot_po_qty);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END LOOP;

            CLOSE l_cur;
        EXCEPTION
            WHEN OTHERS
            THEN
                CLOSE l_cur;
        END;

        UPDATE xxdo.xxd_om_odc_us_tran_gt gt
           SET (item_style, item_color, item_size,
                item_number)   =
                   (SELECT xci.style_number, xci.color_code, xci.item_size,
                           xci.item_number
                      FROM xxd_common_items_v xci, mtl_parameters mp
                     WHERE     xci.inventory_item_id = gt.inventory_item_id
                           AND xci.organization_id = mp.organization_id
                           AND mp.organization_code = 'US7');

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
                 WHERE     lookup_type = 'XXD_OM_ODC_US_LAST_RUN_LKP'
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

    FUNCTION after_report_main (p_order_number IN VARCHAR2, p_date_from VARCHAR2, p_date_to VARCHAR2)
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
              FROM xxdo.xxd_om_odc_us_tran_gt
             WHERE     request_id = gn_request_id
                   AND order_number = NVL (p_order_number, order_number)
                   AND (asn_po_exists_flag = 'Y' OR item_exists_lkp = 'Y');
        EXCEPTION
            WHEN OTHERS
            THEN
                l_cnt   := 0;
        END;

        BEGIN
            SELECT COUNT (*)
              INTO l_bur_cnt
              FROM xxdo.xxd_om_odc_us_tran_gt
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

        lv_recipients   := xxd_om_odc_us_tran_pkg.get_email_id;

        IF lv_recipients IS NOT NULL AND l_bur_cnt > 0        -- Added for 1.1
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
                || 'Please Find the Attached ODC to US Transactional Value Report - Deckers Exception Report. '
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
                    'ODC to US Transactional Value Report - Deckers Exception Report',
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
END xxd_om_odc_us_tran_pkg;
/
