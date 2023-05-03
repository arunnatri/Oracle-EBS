--
-- XXD_PO_CLOSE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_CLOSE_PKG"
AS
    /***********************************************************************************
     *$header :                                                                        *
     *                                                                                 *
     * AUTHORS : Srinath Siricilla                                                     *
     *                                                                                 *
     * PURPOSE : Deckers iProc  Finally Close PO Lines                                 *
     *                                                                                 *
     * PARAMETERS :                                                                    *
     *                                                                                 *
     * DATE : 03-JUN-2022                                                              *
     *                                                                                 *
     * Assumptions:                                                                    *
     *                                                                                 *
     *                                                                                 *
     * History                                                                         *
     * Vsn   Change Date Changed By          Change      Description                   *
     * ----- ----------- ------------------- ----------  ---------------------------   *
     * 1.0   03-JUN-2022 Srinath Siricilla   CCR0009986  Initial Creation              *
     **********************************************************************************/
    gn_success       CONSTANT NUMBER := 0;
    gn_warning       CONSTANT NUMBER := 1;
    gn_error         CONSTANT NUMBER := 2;
    gn_limit_rec     CONSTANT NUMBER := 100;
    gn_commit_rows   CONSTANT NUMBER := 1000;
    gv_delimeter              VARCHAR2 (1) := ',';
    gv_def_mail_recips        do_mail_utils.tbl_recips;

    -- gn_user_id        NUMBER := FND_GLOBAL.USER_ID;

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
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
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;

    --
    /***********************************************************************************************
    **************************** Function to get email ids for error report ************************
    ************************************************************************************************/

    FUNCTION get_email_ids (pv_set_name VARCHAR2, pv_inst_name VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR recips_cur IS
            SELECT xx.email_id
              FROM (SELECT ffvl.description email_id
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     1 = 1
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND ffvs.flex_value_set_name = pv_set_name
                           AND ffvl.enabled_flag = 'Y'
                           --AND ffvl.language = userenv('LANG')
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                           NVL (
                                                               ffvl.start_date_active,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               ffvl.end_date_active,
                                                               SYSDATE))) xx
             WHERE xx.email_id IS NOT NULL;

        CURSOR submitted_by_cur IS
            SELECT (fu.email_address) email_id
              FROM fnd_user fu
             WHERE     1 = 1
                   AND fu.user_id = gn_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE));
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Value Set Name:' || pv_set_name);
        v_def_mail_recips.DELETE;

        IF pv_inst_name = 'PRODUCTION'
        THEN
            FOR recips_rec IN recips_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    recips_rec.email_id;
            END LOOP;

            --FND_FILE.PUT_LINE(FND_FILE.LOG,'Email Recipents:'||v_def_mail_recips);

            RETURN v_def_mail_recips;
        ELSE
            FOR submitted_by_rec IN submitted_by_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    submitted_by_rec.email_id;
            END LOOP;

            RETURN v_def_mail_recips;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_def_mail_recips (1)   := '';
            fnd_file.put_line (fnd_file.LOG,
                               'Failed to fetch email receipents');
            RETURN v_def_mail_recips;
    END get_email_ids;

    --
    PROCEDURE generate_report_prc
    IS
        CURSOR rec_msgs_cur IS
              SELECT tbl.po_number,
                     --                     tbl.invoice_num,
                     tbl.vendor_name,
                     tbl.vendor_number,
                     tbl.process_status,
                     tbl.Error_msg,
                     (SELECT DISTINCT closed_code
                        FROM apps.po_headers_all pha
                       WHERE 1 = 1 AND pha.po_header_id = tbl.po_header_id) Closed_Code
                FROM xxdo.xxd_po_close_tbl tbl
               WHERE     tbl.request_id = gn_request_id
                     AND NVL (process_status, 'A') <> g_ignore --tbl.invoice_num IS NOT NULL
            GROUP BY tbl.po_number, --                     tbl.invoice_num,
                                    tbl.vendor_name, tbl.vendor_number,
                     tbl.process_status, tbl.Error_msg, tbl.po_header_id;

        --  AND document_subtype <> 'DELIVERY_SUCCESS';
        --
        ln_rec_fail             NUMBER;
        ln_rec_total            NUMBER;
        ln_rec_success          NUMBER;
        lv_message              VARCHAR2 (32000);
        lv_recipients           VARCHAR2 (4000);
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        lv_inst_name            VARCHAR2 (30) := NULL;
        lv_msg                  VARCHAR2 (4000) := NULL;
        ln_ret_val              NUMBER := 0;
        lv_out_line             VARCHAR2 (4000);
        lv_error_message        VARCHAR2 (240);
        lv_error_reason         VARCHAR2 (240);
        lv_breif_err_resol      VARCHAR2 (240);
        lv_comments             VARCHAR2 (240);
        ln_counter              NUMBER;
        lv_invoice_type         VARCHAR2 (20);
        lv_rpt_header           VARCHAR2 (4000);
    BEGIN
        ln_rec_fail      := 0;
        ln_rec_total     := 0;
        ln_rec_success   := 0;

        BEGIN
            SELECT COUNT (1)
              INTO ln_rec_total
              FROM xxdo.xxd_po_close_tbl
             WHERE request_id = gn_request_id;
        --   AND document_subtype <> 'DELIVERY_SUCCESS'; -- commented as per ramesh testing

        EXCEPTION
            WHEN OTHERS
            THEN
                ln_rec_total   := 0;
        END;

        IF ln_rec_total <= 0
        THEN
            write_log ('There is nothing to Process...No Errors Exists.');
        ELSE
            BEGIN
                SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') applications_system_name
                  INTO lv_inst_name
                  FROM fnd_product_groups;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_inst_name   := '';
                    lv_msg         :=
                           'Error getting the instance name in send_email_proc procedure. Error is '
                        || SQLERRM;
                    raise_application_error (-20010, lv_msg);
            END;

            gv_def_mail_recips   :=
                get_email_ids ('XXD_IPROC_FINALLY_CLOSE_POS_VS',
                               lv_inst_name);
            apps.do_mail_utils.send_mail_header ('erp@deckers.com', gv_def_mail_recips, 'Deckers PO Close Details ' || ' Email generated from ' || lv_inst_name || ' instance'
                                                 , ln_ret_val);

            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('Hello Team', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Please see attached Deckers PO Close Details success/failed/error/reject Report.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Note: This is auto generated mail, please donot reply.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers_Closed_PO_Report'
                || TO_CHAR (SYSDATE, 'RRRRMMDD_HH24MISS')
                || '.xls"',
                ln_ret_val);
            -- mail attachement
            apps.do_mail_utils.send_mail_line ('  ', ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Detail Report', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'SR. NO'
                || CHR (9)
                || 'PO Number'
                || CHR (9)
                --                || 'AP Invoice Number'
                --                || CHR (9)
                || 'Vendor Number'
                || CHR (9)
                || 'Vendor Name'
                || CHR (9)
                || 'Closed Code'
                || CHR (9)
                || 'Process Status'
                || CHR (9)
                || 'Error Message'
                || CHR (9),
                ln_ret_val);

            ln_counter   := 1;


            lv_rpt_header   :=
                   'SR. NO'
                || CHR (9)
                || 'PO Number'
                || CHR (9)
                || 'Vendor Number'
                || CHR (9)
                || 'Vendor Name'
                || CHR (9)
                || 'Closed Code'
                || CHR (9)
                || 'Process Status'
                || CHR (9)
                || 'Error Message';

            fnd_file.put_line (fnd_file.output, lv_rpt_header);

            FOR r_line IN rec_msgs_cur
            LOOP
                ln_counter   := ln_counter + 1;
                apps.do_mail_utils.send_mail_line (
                       ln_counter
                    || CHR (9)
                    || r_line.po_number
                    || CHR (9)
                    --                    || r_line.invoice_num
                    --                    || CHR (9)
                    || r_line.vendor_number
                    || CHR (9)
                    || r_line.vendor_name
                    || CHR (9)
                    || r_line.closed_code
                    || CHR (9)
                    || r_line.process_status
                    || CHR (9)
                    || r_line.error_msg
                    || CHR (9),
                    ln_ret_val);
                --apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);

                fnd_file.put_line (
                    fnd_file.output,
                       ln_counter
                    || CHR (9)
                    || r_line.po_number
                    || CHR (9)
                    || r_line.vendor_number
                    || CHR (9)
                    || r_line.vendor_name
                    || CHR (9)
                    || r_line.closed_code
                    || CHR (9)
                    || r_line.process_status
                    || CHR (9)
                    || r_line.error_msg);
            END LOOP;

            apps.do_mail_utils.send_mail_close (ln_ret_val);
        ----write_log('lvresult is - ' || lv_result);
        --write_log('lv_result_msg is - ' || lv_result_msg);
        END IF;
    END generate_report_prc;

    PROCEDURE insert_data_into_tbl
    IS
        CURSOR data_selection_cur IS
            SELECT argument6 || ',' || argument7 || ',' || argument8 || ',' || argument9 || ',' || argument10 || ',' || argument11 || ',' || argument12 || ',' || argument13 || ',' || argument14 || ',' || argument15 po_number_listing
              FROM apps.fnd_concurrent_requests
             WHERE request_id = gn_request_id;

        l_vc_arr2      APEX_APPLICATION_GLOBAL.VC_ARR2;

        lv_po_number   VARCHAR2 (4000); --data_selection_cur.po_number_listing%TYPE;
    BEGIN
        NULL;

        OPEN data_selection_cur;

        FETCH data_selection_cur INTO lv_po_number;

        CLOSE data_selection_cur;

        lv_po_number   := TRIM (',' FROM lv_po_number);

        fnd_file.put_line (fnd_file.LOG, 'Testing here');

        l_vc_arr2      := APEX_UTIL.STRING_TO_TABLE (lv_po_number, ',');

        FOR i IN 1 .. l_vc_arr2.COUNT
        LOOP
            INSERT INTO xxdo.xxd_po_close_tbl (ID, po_number, request_id)
                     VALUES (xxdo.xxd_po_close_seq.NEXTVAL,
                             l_vc_arr2 (i),
                             gn_request_id);
        END LOOP;

        COMMIT;
    END insert_data_into_tbl;

    FUNCTION validate_po_fnc (p_po_number          IN     VARCHAR2,
                              p_org_id             IN     NUMBER,
                              x_po_header_id          OUT NUMBER,
                              x_auth_status           OUT VARCHAR2,
                              x_closed_code           OUT VARCHAR2,
                              x_vendor_id             OUT VARCHAR2,
                              x_type_lookup_code      OUT VARCHAR2,
                              x_err_msg               OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_count   NUMBER;
    BEGIN
        BEGIN
            SELECT po_header_id, authorization_status, closed_code,
                   type_lookup_code, vendor_id
              INTO x_po_header_id, x_auth_status, x_closed_code, x_type_lookup_code,
                                 x_vendor_id
              FROM apps.po_headers_all
             WHERE segment1 = p_po_number AND org_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_po_header_id       := NULL;
                x_auth_status        := NULL;
                x_closed_code        := NULL;
                x_type_lookup_code   := NULL;
                x_vendor_id          := NULL;
                x_err_msg            :=
                    'Check the PO Error Msg - ' || SUBSTR (SQLERRM, 1, 200);
        END;

        IF x_po_header_id IS NOT NULL
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END validate_po_fnc;

    FUNCTION get_invoice (p_po_header_id IN NUMBER, p_po_line_id IN NUMBER, p_line_loc_id IN NUMBER, p_dist_id IN NUMBER, x_inv_line_amt OUT NUMBER, x_inv_line_num OUT NUMBER
                          , x_inv_num OUT VARCHAR2, x_err_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT SUM (aila.amount)                           --aila.line_number,
          --                        aia.invoice_num
          INTO x_inv_line_amt                              --, x_inv_line_num,
          --                     x_inv_num
          FROM apps.ap_invoice_lines_all aila, apps.ap_invoices_all aia, apps.ap_invoice_distributions_all aida
         WHERE     aila.po_header_id = p_po_header_id
               AND aila.po_line_id = p_po_line_id
               AND aia.invoice_id = aila.invoice_id
               AND aida.invoice_id = aila.invoice_id
               AND aida.invoice_line_number = aila.line_number
               AND aida.po_distribution_id = p_dist_id;

        --GROUP BY aia.invoice_num;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_inv_line_amt   := NULL;
            x_inv_line_num   := NULL;
            x_inv_num        := NULL;
            x_err_msg        :=
                   'Please Check the PO and its lines for Assocaited Invoice and Error Msg - '
                || SUBSTR (SQLERRM, 1, 200);
            RETURN FALSE;
    END get_invoice;

    FUNCTION check_inv_fnc (p_po_header_id IN NUMBER, x_invoice_num OUT VARCHAR2, x_invoice_amt OUT NUMBER
                            , x_err_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT invoice_num, invoice_amount
          INTO x_invoice_num, x_invoice_amt
          FROM apps.ap_invoices_all aia
         WHERE     1 = 1
               AND EXISTS
                       (SELECT 1
                          FROM apps.ap_invoice_distributions_all aida, apps.po_distributions_all pda
                         WHERE     1 = 1
                               AND aida.po_distribution_id =
                                   pda.po_distribution_id
                               AND aia.invoice_id = aida.invoice_id
                               AND pda.po_header_id = p_po_header_id);

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_invoice_num   := NULL;
            x_invoice_amt   := NULL;
            x_err_msg       :=
                   'Check the Invoice and related PO and Error Msg - '
                || SUBSTR (SQLERRM, 1, 200);

            RETURN FALSE;
    END check_inv_fnc;

    FUNCTION get_po_amt (pn_po_header_id IN NUMBER, pn_po_org_id IN NUMBER, x_po_amt OUT VARCHAR2
                         , x_err_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT SUM (unit_price * quantity)
          INTO x_po_amt
          FROM apps.po_lines_all
         WHERE     1 = 1
               AND po_header_id = pn_po_header_id
               AND org_id = pn_po_org_id;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_po_amt   := NULL;
            x_err_msg   :=
                'PO Amount is Invalid - ' || SUBSTR (SQLERRM, 1, 200);

            RETURN FALSE;
    END get_po_amt;

    PROCEDURE validate_staging_prc (pn_org_id          IN NUMBER,
                                    pv_update_status   IN VARCHAR2)
    IS
        CURSOR data_cur IS
            SELECT *
              FROM xxdo.xxd_po_close_tbl
             WHERE 1 = 1 AND request_id = gn_request_id;

        CURSOR data_line_cur (pn_po_header_id NUMBER)
        IS
              SELECT pla.po_header_Id, pla.po_line_id, pla.line_num,
                     pla.quantity * pla.unit_price amount, plla.line_location_id, pda.po_distribution_id,
                     aps.segment1 Vendor_num, aps.vendor_name, mcb.segment1 category_name,
                     pla.category_id, aps.vendor_id
                FROM apps.po_lines_all pla, apps.po_line_locations_all plla, apps.po_distributions_all pda,
                     apps.ap_suppliers aps, apps.po_headers_all pha, apps.mtl_categories_b mcb
               WHERE     pla.po_header_id = pn_po_header_id
                     AND pla.org_id = pn_org_id
                     AND pla.po_line_id = plla.po_line_id
                     AND aps.vendor_id = pha.vendor_id
                     AND pha.po_header_id = pla.po_header_id
                     AND plla.line_location_id = pda.line_location_id
                     AND pda.po_line_id = pla.po_line_id
                     AND mcb.category_id = pla.category_id
            ORDER BY pha.po_header_id;


        l_boolean              BOOLEAN;
        l_ret_msg              VARCHAR2 (4000);
        l_msg                  VARCHAR2 (4000);
        ln_po_header_id        NUMBER;
        ln_vendor_id           NUMBER;
        lv_inv_num             VARCHAR2 (240);
        ln_inv_amt             NUMBER;
        ln_po_amt              NUMBER;
        l_status               VARCHAR2 (1);
        lv_auth_status         VARCHAR2 (100);
        lv_closed_code         VARCHAR2 (100);
        lv_type_lookup_code    VARCHAR2 (100);
        ln_seq                 NUMBER;
        ln_inv_line_num        NUMBER;
        ln_inv_line_amt        NUMBER;
        ln_po_total_received   NUMBER;
        ln_po_total_invoiced   NUMBER;
        ln_vendor_number       NUMBER;
        lv_vendor_name         VARCHAR2 (360);
    BEGIN
        l_msg       := NULL;
        l_status    := g_validated;
        ln_seq      := NULL;
        l_boolean   := NULL;
        l_ret_msg   := NULL;

        -- Validate the PO Number

        FOR i IN data_cur
        LOOP
            l_boolean              := NULL;
            l_ret_msg              := NULL;
            l_status               := g_validated;
            ln_po_header_id        := NULL;
            lv_auth_status         := NULL;
            lv_type_lookup_code    := NULL;
            lv_closed_code         := NULL;
            l_msg                  := NULL;
            ln_po_total_received   := NULL;
            ln_po_total_invoiced   := NULL;
            ln_vendor_id           := NULL;
            ln_vendor_number       := NULL;
            lv_vendor_name         := NULL;

            -- Validate PO Number

            l_boolean              :=
                validate_po_fnc (p_po_number          => i.po_number,
                                 p_org_id             => pn_org_id,
                                 x_po_header_id       => ln_po_header_id,
                                 x_auth_status        => lv_auth_status,
                                 x_closed_code        => lv_closed_code,
                                 x_vendor_id          => ln_vendor_id,
                                 x_type_lookup_code   => lv_type_lookup_code,
                                 x_err_msg            => l_ret_msg);

            IF l_boolean = FALSE OR l_ret_msg IS NOT NULL
            THEN
                l_status   := G_ERRORED;
                l_msg      := SUBSTR (l_msg || ' - ' || l_ret_msg, 1, 4000);
            END IF;

            -- Insert PO lines for that PO

            --            write_log('Start of Inside Insert Staging Table Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

            IF ln_po_header_id IS NOT NULL
            THEN
                -- Get the Vendor Number and Name

                IF ln_vendor_id IS NOT NULL
                THEN
                    ln_vendor_number   := NULL;
                    lv_vendor_name     := NULL;

                    BEGIN
                        SELECT Segment1, vendor_name
                          INTO ln_vendor_number, lv_vendor_name
                          FROM apps.ap_suppliers
                         WHERE 1 = 1 AND vendor_id = ln_vendor_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_vendor_number   := NULL;
                            lv_vendor_name     := NULL;
                    END;
                END IF;



                ln_po_total_received   := NULL;
                ln_po_total_invoiced   := NULL;
                l_ret_msg              := NULL;

                -- Then get the PO Total received

                IF pv_update_status = 'FINALLY CLOSE'
                THEN
                    BEGIN
                        SELECT POS_TOTALS_PO_SV.get_po_total_received (ln_po_header_id, NULL, NULL)
                          INTO ln_po_total_received
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_po_total_received   := 0;
                    END;

                    BEGIN
                        SELECT POS_TOTALS_PO_SV.get_po_total_invoiced (ln_po_header_id, NULL, NULL)
                          INTO ln_po_total_invoiced
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_po_total_invoiced   := 0;
                    END;

                    IF     ln_po_total_received = 0
                       AND ln_po_total_invoiced = 0
                       AND pv_update_status IN ('CLOSE', 'FINALLY CLOSE')
                    THEN
                        l_status   := G_ERRORED;
                        l_ret_msg   :=
                            'PO received amount should be Equal to Invoice amount for Close or Finally Close';
                        l_msg      :=
                            SUBSTR (l_msg || ' - ' || l_ret_msg, 1, 4000);
                    ELSIF     NVL (ln_po_total_received, 1) <>
                              NVL (ln_po_total_invoiced, 1)
                          AND pv_update_status IN ('CLOSE', 'FINALLY CLOSE')
                    THEN
                        l_status   := G_ERRORED;
                        l_ret_msg   :=
                            'PO received amount should be Equal to Invoice amount for Close or Finally Close';
                        l_msg      :=
                            SUBSTR (l_msg || ' - ' || l_ret_msg, 1, 4000);
                    END IF;
                ELSE
                    l_status   := 'V';
                END IF;
            END IF;

            --            write_log('End of Inside Insert Staging Table Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));



            UPDATE xxdo.xxd_po_close_tbl
               SET process_status = NVL (l_status, g_validated), error_msg = SUBSTR (l_msg, 1, 4000), po_header_id = ln_po_header_id,
                   vendor_name = lv_vendor_name, vendor_number = ln_vendor_number, --                   invoice_amt  = ln_inv_amt,
                                                                                   --                   invoice_num  = lv_inv_num,
                                                                                   po_amt = ln_po_total_received,
                   invoice_amt = ln_po_total_invoiced, authorization_status = lv_auth_status, closed_code = lv_closed_code,
                   type_lookup_code = lv_type_lookup_code
             WHERE 1 = 1 AND id = i.id AND request_id = gn_request_id;

            COMMIT;
        END LOOP;

        --
        FOR cat IN Data_cur
        LOOP
            UPDATE xxdo.xxd_po_close_tbl xx
               SET process_status = g_errored, error_msg = SUBSTR (error_msg || ' - ' || xx.category_name || ' - Category Doesnot exists in XXD_PO_CATEGORY_TYPES_VS Value set ', 1, 3800)
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND id = cat.id
                   AND xx.po_header_id = cat.po_header_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.po_lines_all pla, apps.mtl_categories_b mcb
                             WHERE     1 = 1
                                   AND xx.po_header_id = pla.po_header_id
                                   AND mcb.category_id = pla.category_id
                                   AND EXISTS
                                           (SELECT ffvl.description
                                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                             WHERE     1 = 1
                                                   AND ffvs.flex_value_set_id =
                                                       ffvl.flex_value_set_id
                                                   AND ffvs.flex_value_set_name =
                                                       'XXD_PO_CATEGORY_TYPES_VS'
                                                   AND ffvl.enabled_flag =
                                                       'Y'
                                                   AND mcb.segment1 =
                                                       ffvl.description
                                                   AND SYSDATE BETWEEN NVL (
                                                                           ffvl.start_date_active,
                                                                           SYSDATE)
                                                                   AND NVL (
                                                                           ffvl.end_date_active,
                                                                             SYSDATE
                                                                           + 1)));
        END LOOP;

        --        UPDATE xxdo.xxd_po_close_tbl xx
        --           SET error_msg =
        --                      'These records are not eligible for Validation as this record is for reference only.',
        --               process_status = g_ignore
        --
        --         WHERE     1 = 1
        --               AND request_id = gn_request_id
        --               AND po_line_id IS NULL;

        COMMIT;
    END validate_staging_prc;

    PROCEDURE main_prc (pv_err_buf OUT VARCHAR2, pv_ret_code OUT VARCHAR2, pn_org_id IN NUMBER, pv_update_status IN VARCHAR2, pv_dummy1 IN VARCHAR2, pd_cutoff_date IN VARCHAR2, --  pd_start_date      IN     VARCHAR2,
                                                                                                                                                                                 --    pd_end_date        IN     VARCHAR2,
                                                                                                                                                                                 --    pv_vendor          IN     NUMBER,
                                                                                                                                                                                 pv_dummy2 IN VARCHAR2, pv_po_list1 IN VARCHAR2, pv_po_list2 IN VARCHAR2, pv_po_list3 IN VARCHAR2, pv_po_list4 IN VARCHAR2, pv_po_list5 IN VARCHAR2, pv_po_list6 IN VARCHAR2, pv_po_list7 IN VARCHAR2, pv_po_list8 IN VARCHAR2
                        , pv_po_list9 IN VARCHAR2, pv_po_list10 IN VARCHAR2)
    IS
        -- Fetch the records the Closed PO's and then Insert into Table.
        -- Will use it for validation

        CURSOR po_fclose_data_cur IS
              SELECT pdt.document_subtype, pdt.document_type_code, pha.po_header_id,
                     pha.segment1 po_num, aps.segment1 vendor_number, aps.vendor_name,
                     aps.vendor_id
                --            pha.po_amt
                --            xx.invoice_num,
                --            SUM(xx.invoice_line_amt) invoice_amt
                FROM apps.po_headers_all pha, apps.po_lines_all pla, apps.mtl_categories mc,
                     apps.mtl_category_sets mcs, apps.po_document_types_all pdt, apps.ap_suppliers aps
               WHERE     1 = 1
                     AND NVL (pha.closed_code, 'OPEN') = 'CLOSED'
                     AND pha.type_lookup_code = pdt.document_subtype
                     AND pdt.org_id = pn_org_id
                     AND pha.org_id = pdt.org_id
                     AND pdt.document_type_code = 'PO'
                     AND pha.vendor_id = aps.vendor_id
                     AND pv_update_status = 'FINALLY CLOSE'
                     --   AND pha.vendor_id = NVL(pv_vendor,pha.vendor_id)
                     AND pla.category_id = mc.category_id
                     AND pha.po_header_id = pla.po_header_id
                     AND mcs.structure_id = mc.structure_id
                     AND mcs.category_set_name = 'PO Item Category'
                     AND EXISTS
                             (SELECT 1
                                FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                               WHERE     1 = 1
                                     AND ffvs.flex_value_set_id =
                                         ffvl.flex_value_set_id
                                     AND ffvs.flex_value_set_name =
                                         'XXD_PO_CATEGORY_TYPES_VS'
                                     AND ffvl.enabled_flag = 'Y'
                                     AND mc.segment1 = ffvl.description
                                     AND SYSDATE BETWEEN NVL (
                                                             ffvl.start_date_active,
                                                             SYSDATE)
                                                     AND NVL (
                                                             ffvl.end_date_active,
                                                             SYSDATE + 1))
                     AND pha.last_update_date <=
                         TO_DATE (pd_cutoff_date, 'DD-MON-RRRR')
            /*AND pha.last_update_date BETWEEN NVL (
                                                 TO_DATE (
                                                     pd_start_date,
                                                     'DD-MON-RRRR'),
                                                 pha.last_update_date)
                                         AND NVL (
                                                 TO_DATE (
                                                     pd_end_date,
                                                     'DD-MON-RRRR'),
                                                 pha.last_update_date)*/
            GROUP BY pdt.document_subtype, pdt.document_type_code, pha.po_header_id,
                     pha.segment1, aps.segment1, aps.vendor_name,
                     aps.vendor_id;

        -- Fetch the records the Closed PO's and then Open them

        CURSOR po_open_close_data_cur IS
            SELECT pdt.document_subtype, pdt.document_type_code, xx.po_header_id,
                   xx.po_amt, invoice_amt
              --                     xx.invoice_num,
              --                     SUM (xx.invoice_line_amt)     invoice_amt
              FROM xxdo.xxd_po_close_tbl xx, apps.po_document_types_all pdt
             WHERE     1 = 1
                   AND xx.request_id = gn_request_id
                   AND xx.process_status = g_validated
                   AND NVL (xx.closed_code, 'CLOSED') IN ('OPEN', 'CLOSED')
                   AND xx.type_lookup_code = pdt.document_subtype
                   AND pv_update_status IN ('OPEN', 'CLOSED')
                   AND pdt.org_id = pn_org_id
                   AND pdt.document_type_code = 'PO';

        --                     AND xx.po_line_id IS NOT NULL
        --AND xx.invoice_num IS NOT NULL
        --            GROUP BY pdt.document_subtype,
        --                     pdt.document_type_code,
        --                     xx.po_header_id;
        --                     xx.po_amt;
        --                     xx.invoice_num;

        -- Fetch the records the Open PO's and then Close them

        CURSOR po_fclosed_data_cur IS
            SELECT pdt.document_subtype, pdt.document_type_code, xx.po_header_id,
                   xx.po_amt, invoice_amt
              --                     xx.invoice_num,
              --                     SUM (xx.invoice_line_amt)     invoice_amt
              FROM xxdo.xxd_po_close_tbl xx, apps.po_document_types_all pdt
             WHERE     1 = 1
                   AND xx.request_id = gn_request_id
                   AND xx.process_status = g_validated
                   AND NVL (xx.closed_code, 'FC') = 'CLOSED'
                   AND xx.type_lookup_code = pdt.document_subtype
                   AND pdt.org_id = pn_org_id
                   AND pv_update_status IN
                           ('FINALLY CLOSE', 'FINALLY CLOSE-FORCED')
                   AND pdt.document_type_code = 'PO';

        --                     AND xx.po_line_id IS NOT NULL;
        --                     AND xx.invoice_num IS NOT NULL
        --            GROUP BY pdt.document_subtype,
        --                     pdt.document_type_code,
        --                     xx.po_header_id,
        --                     xx.po_amt;
        --                     xx.invoice_num;

        x_calling_mode   CONSTANT VARCHAR2 (2) := 'PO';
        x_conc_flag      CONSTANT VARCHAR2 (1) := 'N';
        x_return_code_h           VARCHAR2 (100);
        x_auto_close     CONSTANT VARCHAR2 (1) := 'N';
        x_origin_doc_id           NUMBER;
        x_returned                BOOLEAN;
        lv_status                 VARCHAR2 (10);
        lv_error_message          VARCHAR2 (32767);
        ln_ven_count              NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Start of the Program');
        fnd_file.put_line (fnd_file.LOG, '====================');
        fnd_file.put_line (fnd_file.LOG, 'Operating Unit   : ' || pn_org_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Update Status    : ' || pv_update_status);
        fnd_file.put_line (fnd_file.LOG,
                           'Cut Off Date     : ' || pd_cutoff_date);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List1  : ' || pv_po_list1);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List2  : ' || pv_po_list2);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List3  : ' || pv_po_list3);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List4  : ' || pv_po_list4);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List5  : ' || pv_po_list5);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List6  : ' || pv_po_list6);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List7  : ' || pv_po_list7);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List8  : ' || pv_po_list8);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List9  : ' || pv_po_list9);
        fnd_file.put_line (fnd_file.LOG,
                           'PO Number List10  : ' || pv_po_list10);


        IF pv_update_status IN ('OPEN', 'CLOSED', 'FINALLY CLOSE-FORCED')
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               ' Start of the Program for open or close ');

            insert_data_into_tbl;
        ELSIF pv_update_status IN ('FINALLY CLOSE')
        THEN
            --            write_log('Start of Table Insertion - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));
            FOR i IN po_fclose_data_cur
            LOOP
                INSERT INTO xxdo.xxd_po_close_tbl (ID,
                                                   po_number,
                                                   request_id,
                                                   vendor_name,
                                                   vendor_number,
                                                   vendor_id)
                     VALUES (xxdo.xxd_po_close_seq.NEXTVAL, i.po_num, gn_request_id
                             , i.vendor_name, i.vendor_number, i.vendor_id);
            END LOOP;

            COMMIT;
        --            write_log('End of Table Insertion - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

        END IF;

        --        write_log('Start of Staging Table Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));


        validate_staging_prc (pn_org_id          => pn_org_id,
                              pv_update_status   => pv_update_status);

        --        write_log('End of Staging Table Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));
        --
        --        -- With this Validation, Open/Closed and Finally Closed PO's are validated.
        --
        IF pv_update_status = 'CLOSED'                   -- po_closed_data_cur
        THEN
            UPDATE xxdo.xxd_po_close_tbl
               SET error_msg = SUBSTR (error_msg || ' PO are in closed state, So no need to close again ', 1, 4000), process_status = g_errored
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND process_status = g_validated
                   AND closed_code = 'CLOSED';

            COMMIT;

            UPDATE xxdo.xxd_po_close_tbl
               SET error_msg = SUBSTR (error_msg || ' We cannot perform this action , since the PO is in Finally Closed state ', 1, 4000), process_status = g_errored
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND process_status = g_validated
                   AND closed_code = 'FINALLY CLOSED';

            COMMIT;

            --            write_log('Start of Close Status API Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

            BEGIN
                fnd_global.apps_initialize (user_id        => gn_user_id,
                                            resp_id        => gn_resp_id,
                                            resp_appl_id   => gn_resp_appl_id);
            END;

            FOR open_close_po_data IN po_open_close_data_cur
            LOOP
                mo_global.init (open_close_po_data.document_type_code);
                mo_global.set_policy_context ('S', pn_org_id);

                fnd_file.put_line (fnd_file.LOG,
                                   'Entered here to close the PO');
                x_returned   :=
                    po_actions.close_po (p_docid => open_close_po_data.po_header_id, p_doctyp => open_close_po_data.document_type_code, p_docsubtyp => open_close_po_data.document_subtype, p_lineid => NULL, p_shipid => NULL, p_action => 'CLOSE', p_reason => NULL, p_calling_mode => x_calling_mode, p_conc_flag => x_conc_flag, p_return_code => x_return_code_h, p_auto_close => x_auto_close, p_action_date => SYSDATE
                                         , p_origin_doc_id => NULL);

                IF x_returned = TRUE
                THEN
                    lv_status   := g_processed;

                    --error_msg := error_msg;
                    UPDATE xxdo.xxd_po_close_tbl
                       SET process_status   = lv_status
                     WHERE     1 = 1
                           AND po_header_id = open_close_po_data.po_header_id
                           --AND invoice_num = open_close_po_data.invoice_num
                           AND request_id = gn_request_id
                           AND process_status = g_validated;
                ELSE
                    UPDATE xxdo.xxd_po_close_tbl
                       SET process_status = g_errored, error_msg = SUBSTR (error_msg || ' - API Failed to Close the Purchase Order', 1, 4000)
                     WHERE     1 = 1
                           AND po_header_id = open_close_po_data.po_header_id
                           --                           AND invoice_num = open_close_po_data.invoice_num
                           AND process_status = g_validated
                           AND request_id = gn_request_id;
                END IF;

                COMMIT;
            END LOOP;
        --            write_log('Start of Close Status Loop API Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

        END IF;

        IF pv_update_status = 'OPEN'
        THEN
            UPDATE xxdo.xxd_po_close_tbl
               SET error_msg = SUBSTR (error_msg || ' PO are in open state, So no need to open again ', 1, 4000), process_status = g_errored
             WHERE     1 = 1
                   AND process_status = g_validated
                   AND closed_code = 'OPEN'
                   AND request_id = gn_request_id;

            COMMIT;

            UPDATE xxdo.xxd_po_close_tbl
               SET error_msg = SUBSTR (error_msg || ' We cannot perform this action , since the PO is in Finally Closed state ', 1, 4000), process_status = g_errored
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND process_status = g_validated
                   AND closed_code = 'FINALLY CLOSED';

            COMMIT;

            --            write_log('Start of Open Status Loop API Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => gn_resp_id,
                                        resp_appl_id   => gn_resp_appl_id);


            FOR open_close_po_data IN po_open_close_data_cur
            LOOP
                mo_global.init (open_close_po_data.document_type_code);
                mo_global.set_policy_context ('S', pn_org_id);

                x_returned   :=
                    po_actions.close_po (p_docid => open_close_po_data.po_header_id, p_doctyp => open_close_po_data.document_type_code, p_docsubtyp => open_close_po_data.document_subtype, p_lineid => NULL, p_shipid => NULL, p_action => pv_update_status, p_reason => NULL, p_calling_mode => x_calling_mode, p_conc_flag => x_conc_flag, p_return_code => x_return_code_h, p_auto_close => x_auto_close, p_action_date => SYSDATE
                                         , p_origin_doc_id => NULL);

                IF x_returned = TRUE
                THEN
                    lv_status   := g_processed;

                    --error_msg := error_msg;
                    UPDATE xxdo.xxd_po_close_tbl
                       SET process_status   = lv_status
                     WHERE     1 = 1
                           AND po_header_id = open_close_po_data.po_header_id
                           --                           AND invoice_num = open_close_po_data.invoice_num
                           AND process_status = g_validated
                           AND request_id = gn_request_id;
                ELSE
                    UPDATE xxdo.xxd_po_close_tbl
                       SET process_status = g_errored, error_msg = SUBSTR (error_msg || ' - API Failed to Open the Purchase Order', 1, 4000)
                     WHERE     1 = 1
                           AND po_header_id = open_close_po_data.po_header_id
                           --                           AND invoice_num = open_close_po_data.invoice_num
                           AND process_status = g_validated
                           AND request_id = gn_request_id;
                END IF;

                COMMIT;
            END LOOP;
        --            write_log('End of Open Status Loop API Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

        END IF;

        --- Finally Close the PO's

        IF pv_update_status IN ('FINALLY CLOSE', 'FINALLY CLOSE-FORCED')
        THEN
            UPDATE xxdo.xxd_po_close_tbl
               SET error_msg = SUBSTR (error_msg || ' PO are in Finally Closed state, No further action can be performed on this PO ', 1, 4000), process_status = g_errored
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND process_status = g_validated
                   AND closed_code = 'FINALLY CLOSED';

            COMMIT;

            UPDATE xxdo.xxd_po_close_tbl
               SET error_msg = SUBSTR (error_msg || ' PO should be in Closed state, before they can be finally closed ', 1, 4000), process_status = g_errored
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND process_status = g_validated
                   AND closed_code = 'OPEN';

            COMMIT;

            -- Lets close the PO headers and Lines as applicable

            --            write_log('Start of FC Status Loop API Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

            fnd_global.apps_initialize (user_id        => gn_user_id,
                                        resp_id        => gn_resp_id,
                                        resp_appl_id   => gn_resp_appl_id);


            FOR fclosed_po_data IN po_fclosed_data_cur
            LOOP
                mo_global.init (fclosed_po_data.document_type_code);
                mo_global.set_policy_context ('S', pn_org_id);

                x_returned   :=
                    po_actions.close_po (p_docid => fclosed_po_data.po_header_id, p_doctyp => fclosed_po_data.document_type_code, p_docsubtyp => fclosed_po_data.document_subtype, p_lineid => NULL, p_shipid => NULL, p_action => 'FINALLY CLOSE', p_reason => NULL, p_calling_mode => x_calling_mode, p_conc_flag => x_conc_flag, p_return_code => x_return_code_h, p_auto_close => x_auto_close, p_action_date => SYSDATE
                                         , p_origin_doc_id => NULL);

                IF x_returned = TRUE
                THEN
                    lv_status   := g_processed;

                    --error_msg := error_msg;
                    UPDATE xxdo.xxd_po_close_tbl
                       SET process_status   = g_processed
                     WHERE     1 = 1
                           AND po_header_id = fclosed_po_data.po_header_id
                           --                           AND invoice_num = fclosed_po_data.invoice_num
                           AND process_status = g_validated
                           AND request_id = gn_request_id;
                ELSE
                    UPDATE xxdo.xxd_po_close_tbl
                       SET process_status = g_errored, error_msg = SUBSTR (error_msg || ' - API Failed to Finally Close the Purchase Order', 1, 4000)
                     WHERE     1 = 1
                           AND po_header_id = fclosed_po_data.po_header_id
                           --                           AND invoice_num = fclosed_po_data.invoice_num
                           AND process_status = g_validated
                           AND request_id = gn_request_id;
                END IF;

                COMMIT;
            END LOOP;
        --            write_log('End of FC Status Loop API Validation - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

        END IF;

        --        write_log('Start of Email Procedure - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

        generate_report_prc;
    --        write_log('End of Email Procedure - '||TO_CHAR(SYSDATE,'RRRRMMDDHH24MISS'));

    END main_prc;
END XXD_PO_CLOSE_PKG;
/
