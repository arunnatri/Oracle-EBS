--
-- XXDOAP_INV_ONHOLD_NOTIF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAP_INV_ONHOLD_NOTIF_PKG"
AS
    /******************************************************************************************************
    * Package Name  : xxdoap_inv_onhold_notif_pkg
    * CCR           : CCR0006018 -  Add a notification for invoices on hold
    * Description   : This Package contains procedures pull the AP Invoices on hold and send emails
    *                 to preparers and also send a summary email to Director of Payables
    *
    *
    * Maintenance History
    * -------------------
    * Date          Author            Version          Change Description
    * -----------   ------            ---------------  ------------------------------
    * 22-Mar-2017   Kranthi Bollam    NA               Initial Version
    * 13-Apr-2017   Kranthi Bollam    1.1              Added operating Unit and Quantity Billed Columns as
    *                                                  requested by users
    * 22-May-2018   Aravind Kannuri   1.2              CCR0007257 - Added 3 Columns for Invoice on-hold report
    * 20-Dec-2020   Showkath Ali   1.3              CCR0009059 - Invoices on hold notification detail
    * 13-Jul-2022   Ramesh BR    1.4      CCR0009845 - Added 3 new columns Preparer, Approver and Requester
    ********************************************************************************************************/

    gn_batch_id            NUMBER;
    gn_created_by          NUMBER := FND_GLOBAL.user_id;
    gn_last_updated_by     NUMBER := FND_GLOBAL.user_id;
    gn_last_update_login   NUMBER := FND_GLOBAL.login_id;
    gn_request_id          NUMBER := FND_GLOBAL.conc_request_id;
    gn_conc_login_id       NUMBER := FND_GLOBAL.conc_login_id;
    ex_no_recips           EXCEPTION;
    v_def_mail_recips      do_mail_utils.tbl_recips;

    PROCEDURE msg (pv_msg IN VARCHAR2, pv_file IN VARCHAR2 DEFAULT 'LOG')
    AS
    BEGIN
        IF UPPER (pv_file) = 'OUT'
        THEN
            fnd_file.put_line (fnd_file.output, pv_msg);
        ELSE
            fnd_file.put_line (fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In When Others exception in msg procedure. Error is: '
                || SQLERRM);
    END;

    FUNCTION get_email_recips (pv_lookup_type VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR recips_cur IS
            SELECT flv.lookup_code, flv.meaning, flv.description
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = pv_lookup_type
                   AND flv.enabled_flag = 'Y'
                   AND flv.language = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (flv.start_date_active,
                                                SYSDATE))
                                   AND TRUNC (
                                             NVL (flv.end_date_active,
                                                  SYSDATE)
                                           + 1);
    BEGIN
        v_def_mail_recips.DELETE;

        FOR recips_rec IN recips_cur
        LOOP
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                recips_rec.meaning;
        END LOOP;

        RETURN v_def_mail_recips;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_def_mail_recips (1)   := '';
            RETURN v_def_mail_recips;
            msg (
                   'When Others exception in get_email_recips procedure. Error is: '
                || SQLERRM,
                'LOG');
    END get_email_recips;

    PROCEDURE driving_proc (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_org_id IN NUMBER
                            , pn_rentention_days IN NUMBER DEFAULT 30, pv_test_email_id IN VARCHAR2, pv_send_email IN VARCHAR2 --1.3
                                                                                                                              )
    AS
        CURSOR inv_onhold_cur IS
              SELECT ai.invoice_num,
                     --Start changes as per version CCR0007257
                     ai.invoice_date,
                     TO_DATE (ai.creation_date, 'DD-MM-RRRR')
                         invoice_create_date,
                     (  SELECT aps.due_date
                          FROM ap_payment_schedules_all aps, ap_invoices_all aia
                         WHERE     aps.invoice_id = aia.invoice_id
                               AND aps.org_id = aia.org_id
                               AND aps.invoice_id = ai.invoice_id
                      GROUP BY aps.due_date)
                         invoice_due_date,
                     --End changes as per version CCR0007257
                     ai.invoice_amount,
                     ail.line_number
                         invoice_line_number,
                     ail.line_type_lookup_code
                         line_type,
                     ail.description
                         inv_line_desc,
                     ail.amount
                         invoice_line_amount,
                     ail.quantity_invoiced,
                     ail.unit_price
                         invoice_line_unit_price,
                     ail.unit_meas_lookup_code
                         uom,
                     sup.vendor_name,
                     ss.vendor_site_code
                         vendor_site,
                     aha.hold_lookup_code
                         hold_code,
                     aha.hold_reason,
                     ph.segment1
                         po_number,
                     pl.line_num
                         po_line_number,
                     pl.quantity
                         po_line_quantity,
                     pl.unit_price
                         po_line_unit_price,
                     pl.unit_price * pl.quantity
                         po_line_amount,
                     DECODE (plt.matching_basis,
                             'QUANTITY', pll.quantity,
                             'AMOUNT', pll.amount)
                         shipment_ordered,
                     DECODE (plt.matching_basis,
                             'QUANTITY', pll.quantity_billed,
                             'AMOUNT', pll.amount_billed)
                         shipment_billed,
                     DECODE (plt.matching_basis,
                             'QUANTITY', pll.quantity_received,
                             'AMOUNT', pll.amount_received)
                         shipment_received,
                     (DECODE (plt.matching_basis,  'QUANTITY', pll.quantity_received,  'AMOUNT', pll.amount_received) * pl.unit_price)
                         receipt_total,
                     ph.agent_id,
                     aha.org_id,
                     prha.preparer_id,
                     --Start changes as per CCR0009845
                     (SELECT full_name
                        FROM per_all_people_f pap
                       WHERE     pap.person_id = prha.preparer_id
                             AND TRUNC (SYSDATE) BETWEEN pap.effective_start_date
                                                     AND pap.effective_end_date)
                         preparer_name,
                     por_view_reqs_pkg.get_requester (
                         prha.requisition_header_id)
                         requester_name,
                     (SELECT approver
                        FROM por_approval_status_lines_v
                       WHERE     document_id = prha.requisition_header_id
                             AND approval_status = 'APPROVE'
                             AND sequence_num =
                                 (SELECT MAX (sequence_num)
                                    FROM por_approval_status_lines_v
                                   WHERE document_id =
                                         prha.requisition_header_id))
                         approver_name
                -- End changes as per CCR0009845
                FROM apps.ap_holds_all aha, apps.po_line_locations_all pll, apps.po_lines_all pl,
                     apps.po_headers_all ph, apps.po_distributions_all pda, apps.po_req_distributions_all prda,
                     apps.po_requisition_lines_all prla, apps.po_requisition_headers_all prha--              ,apps.ap_invoice_distributions_all aida
                                                                                             , apps.ap_invoice_lines_all ail,
                     apps.ap_invoices_all ai, apps.ap_suppliers sup, apps.ap_supplier_sites_all ss,
                     apps.po_line_types plt
               WHERE     1 = 1
                     AND aha.org_id = NVL (pn_org_id, aha.org_id) --OU Parameter
                     AND aha.release_lookup_code IS NULL   --Hold Not Released
                     AND aha.line_location_id = pll.line_location_id
                     AND pll.po_line_id = pl.po_line_id
                     AND pl.po_header_id = ph.po_header_id
                     AND pll.line_location_id = pda.line_location_id
                     AND pll.po_line_id = pda.po_line_id
                     AND pll.po_header_id = pda.po_header_id
                     AND pda.req_distribution_id = prda.distribution_id
                     AND prda.requisition_line_id = prla.requisition_line_id
                     AND prla.requisition_header_id =
                         prha.requisition_header_id
                     --           AND pda.po_distribution_id = aida.po_distribution_id
                     --           AND aida.line_type_lookup_code = 'ITEM'
                     --           AND aida.reversal_flag = 'N'
                     --           AND NVL(aida.cancellation_flag, 'N') = 'N'
                     --           AND aida.invoice_id = aha.invoice_id
                     --           AND aida.invoice_line_number = ail.line_number
                     AND aha.invoice_id = ail.invoice_id
                     AND aha.line_location_id = ail.po_line_location_id
                     AND ail.line_type_lookup_code = 'ITEM'
                     AND ail.discarded_flag = 'N' --Invoice Line Should not be Discarded
                     AND ail.cancelled_flag = 'N' --Invoice Line Should not be Cancelled
                     AND ail.amount > '0' --Invoice Amount should be greater than Zero
                     AND ail.invoice_id = ai.invoice_id
                     AND sup.vendor_id = ai.vendor_id
                     AND sup.vendor_id = ss.vendor_id
                     AND ss.vendor_site_id = ai.vendor_site_id
                     AND pl.line_type_id = plt.line_type_id
                     --AND ai.invoice_num = 'BP20161130T'
                     AND EXISTS
                             (/*SELECT '1'
                                FROM apps.fnd_lookup_values flv
                               WHERE 1 = 1
                                 AND flv.lookup_type = 'XXDOAP_HOLD_CODES_FOR_NOTIF'
                                 AND flv.language = USERENV('LANG')
                                 AND flv.enabled_flag = 'Y'
                                 AND TRUNC(SYSDATE) BETWEEN TRUNC(flv.start_date_active) AND TRUNC(NVL(flv.end_date_active, SYSDATE))
                                 AND flv.lookup_code = aha.hold_lookup_code*/
                              --1.3
                              SELECT 1
                                FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                               WHERE     fvs.flex_value_set_id =
                                         ffvl.flex_value_set_id
                                     AND fvs.flex_value_set_name =
                                         'XXDO_AP_INV_HOLD_NTF_HOLDS'
                                     AND NVL (TRUNC (ffvl.start_date_active),
                                              TRUNC (SYSDATE)) <=
                                         TRUNC (SYSDATE)
                                     AND NVL (TRUNC (ffvl.end_date_active),
                                              TRUNC (SYSDATE)) >=
                                         TRUNC (SYSDATE)
                                     AND ffvl.enabled_flag = 'Y'
                                     AND ffvl.flex_value = aha.hold_lookup_code --1.3
                                                                               )
            ORDER BY prha.preparer_id, ai.invoice_date, ai.invoice_num,
                     invoice_line_number, po_line_number;


        ln_commit   NUMBER := 500;
    BEGIN
        --fnd_file.put_line(fnd_file.log, 'Operating Unit ID: '||pn_org_id);

        msg (
               'Program started at : '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');
        msg ('Parameter1 : Operating Unit ID: ' || pn_org_id, 'LOG');
        msg ('Parameter2 : Purge Retention Days: ' || pn_rentention_days,
             'LOG');
        msg (
               'Parameter3 : Default Email Id for preparer if the instance is Non Production: '
            || pv_test_email_id,
            'LOG');
        msg ('Parameter4 : Send Email (Yes/No): ' || pv_send_email, 'LOG'); --1.3
        msg (
               'Calling Purge Procedure to delete the temp table data older than '
            || NVL (pn_rentention_days, 30)
            || ' days.',
            'LOG');
        msg (
               'Purge Procedure started at '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');
        --Calling purge program
        purge_data (pn_rentention_days);

        msg (
               'Purge Procedure completed at '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');

        --Getting the Batch ID
        BEGIN
            SELECT xxdo.xxdoap_inv_onhold_batch_id_s.NEXTVAL
              INTO gn_batch_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg (
                       'Error while getting Batch ID sequence number: '
                    || SQLERRM,
                    'LOG');
        END;

        msg ('Batch ID for this program run is : ' || gn_batch_id, 'LOG');
        msg (
               'Opening the main cursor and inserting the data into temp table at :'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');

        --Opening the Invoices onhold cursor for processing
        FOR inv_onhold_rec IN inv_onhold_cur
        LOOP
            --Inserting all the hold invoice details into a temp or staging table which will be the source for entire program
            INSERT INTO xxdo.xxdoap_inv_onhold_notif_temp (
                            batch_id,
                            invoice_num--Start changes as per version CCR0007257
                                       ,
                            invoice_date,
                            invoice_create_date,
                            invoice_due_date--End changes as per version CCR0007257
                                            ,
                            invoice_amount,
                            invoice_line_number,
                            line_type,
                            inv_line_desc,
                            invoice_line_amount,
                            quantity_invoiced,
                            invoice_line_unit_price,
                            uom,
                            vendor_name,
                            vendor_site,
                            hold_code,
                            hold_reason,
                            po_number,
                            po_line_number,
                            po_line_quantity,
                            po_line_unit_price,
                            po_line_amount,
                            shipment_ordered,
                            shipment_billed,
                            shipment_received,
                            receipt_total,
                            org_id,
                            agent_id,
                            preparer_id,
                            creation_date,
                            created_by,
                            last_update_date,
                            last_updated_by,
                            last_update_login,
                            request_id,
                            preparer_name            --Added as per CCR0009845
                                         ,
                            requester_name           --Added as per CCR0009845
                                          ,
                            approver_name            --Added as per CCR0009845
                                         )
                     VALUES (
                                gn_batch_id,
                                REGEXP_REPLACE (
                                    inv_onhold_rec.invoice_num,
                                    '[ ' || CHR (13) || CHR (10) || ']+',
                                    '') --Added REGEXP_REPLACE function to remove special characters as per CCR0009845
                                       --Start changes as per version CCR0007257
                                       ,
                                inv_onhold_rec.invoice_date,
                                inv_onhold_rec.invoice_create_date,
                                inv_onhold_rec.invoice_due_date--End changes as per version CCR0007257
                                                               ,
                                inv_onhold_rec.invoice_amount,
                                inv_onhold_rec.invoice_line_number,
                                inv_onhold_rec.line_type,
                                inv_onhold_rec.inv_line_desc,
                                inv_onhold_rec.invoice_line_amount,
                                inv_onhold_rec.quantity_invoiced,
                                inv_onhold_rec.invoice_line_unit_price,
                                inv_onhold_rec.uom,
                                inv_onhold_rec.vendor_name,
                                inv_onhold_rec.vendor_site,
                                inv_onhold_rec.hold_code,
                                inv_onhold_rec.hold_reason,
                                inv_onhold_rec.po_number,
                                inv_onhold_rec.po_line_number,
                                inv_onhold_rec.po_line_quantity,
                                inv_onhold_rec.po_line_unit_price,
                                inv_onhold_rec.po_line_amount,
                                inv_onhold_rec.shipment_ordered,
                                inv_onhold_rec.shipment_billed,
                                inv_onhold_rec.shipment_received,
                                inv_onhold_rec.receipt_total,
                                inv_onhold_rec.org_id,
                                inv_onhold_rec.agent_id,
                                inv_onhold_rec.preparer_id,
                                SYSDATE,
                                gn_created_by,
                                SYSDATE,
                                gn_last_updated_by,
                                gn_last_update_login,
                                gn_request_id,
                                inv_onhold_rec.preparer_name --Added as per CCR0009845
                                                            ,
                                inv_onhold_rec.requester_name --Added as per CCR0009845
                                                             ,
                                inv_onhold_rec.approver_name --Added as per CCR0009845
                                                            );

            --Committing for every ln_commit records
            IF MOD (SQL%ROWCOUNT, ln_commit) = 0
            THEN
                COMMIT;
            END IF;
        END LOOP;

        COMMIT;
        msg (
               'inserting the data into temp table completed at :'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');
        msg (
               'Now calling the email_to_preparers procedure to send emails to preparers at : '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');
        --Calling procedure to send email to Preparers of PO's
        email_to_preparers (gn_batch_id, pv_test_email_id, pv_send_email --1.3
                                                                        );

        msg (
               'email_to_preparers procedure completed at : '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');
        msg (
               'Now calling the email_to_dir_payables procedure to send emails to payables director at : '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');
        --Calling procedure to send email to Director of Payables
        email_to_dir_payables (gn_batch_id, pv_send_email,               --1.3
                                                           pv_test_email_id --1.3
                                                                           );
        msg (
               'email_to_dir_payables procedure completed at : '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');
        msg (
               'Program completed successfully at : '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'),
            'LOG');
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'In When others exception in driving_proc procedure. Error is: '
                || SQLERRM,
                'LOG');
            pv_retcode   := 2;                 --Complete the program in error
            pv_errbuf    :=
                   'In When others exception in driving_proc procedure. Error is: '
                || SQLERRM;
    END driving_proc;

    --Procedure to send email to Preparers of PO's
    PROCEDURE email_to_preparers (pn_batch_id IN NUMBER, pv_test_email_id IN VARCHAR2, pv_send_email IN VARCHAR2 -- 1.3
                                                                                                                )
    AS
        CURSOR prep_cur IS
              SELECT tmp.batch_id, tmp.preparer_id, fu.email_address prep_email_address,
                     COUNT (*) count_of_invoices_on_hold
                FROM xxdo.xxdoap_inv_onhold_notif_temp tmp, apps.fnd_user fu
               WHERE     1 = 1
                     AND tmp.batch_id = pn_batch_id
                     AND tmp.preparer_id = fu.employee_id
                     AND NVL (fu.end_date, SYSDATE) >= SYSDATE
            GROUP BY tmp.batch_id, tmp.preparer_id, fu.email_address
            ORDER BY prep_email_address;

        CURSOR inv_det_cur (cn_batch_id IN NUMBER, cn_preparer_id IN NUMBER)
        IS
              SELECT hou.name operating_unit,           --Added for change 1.1
                                              xiot.*
                FROM xxdo.xxdoap_inv_onhold_notif_temp xiot, apps.hr_operating_units hou --Added for change 1.1
               WHERE     1 = 1
                     AND xiot.batch_id = cn_batch_id
                     AND xiot.preparer_id = cn_preparer_id
                     AND xiot.org_id = hou.organization_id --Added for change 1.1
            ORDER BY operating_unit,                    --Added for change 1.1
                                     xiot.invoice_date, xiot.invoice_num,
                     xiot.invoice_line_number;

        lv_inst_name   VARCHAR2 (20);
        lv_out_line    VARCHAR2 (4000);
        ln_ret_val     NUMBER := 0;
    BEGIN
        msg ('In sending email to preparers procedure', 'LOG');

        BEGIN
            SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') applications_system_name
              INTO lv_inst_name
              FROM fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inst_name   := '';
                msg (
                       'Error getting the instance name in email_to_preparers procedure: '
                    || SQLERRM,
                    'LOG');
        END;

        IF pv_send_email = 'Y'
        THEN                                                            -- 1.3
            FOR prep_rec IN prep_cur
            LOOP
                v_def_mail_recips (1)   := '';           --Resetting the value

                IF lv_inst_name = 'PRODUCTION'
                THEN
                    v_def_mail_recips (1)   := prep_rec.prep_email_address;
                ELSE
                    v_def_mail_recips (1)   := pv_test_email_id; --'kranthi.bollam@deckers.com';--'madhav.dhurjaty@deckers.com';
                END IF;


                apps.do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), v_def_mail_recips, 'Invoices on Hold - Please take action! ' || ' - Email from ' || lv_inst_name || ' instance'
                                                     , ln_ret_val);

                do_mail_utils.send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);         --Added
                do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);         --Added
                --            do_mail_utils.send_mail_line ('Content-Type: text/plain', ln_ret_val); --Not Required
                --            do_mail_utils.send_mail_line ('', ln_ret_val); --Not Required
                do_mail_utils.send_mail_line (
                    'Please see attached invoices that are on Hold and need attention for Accounts Payables to process.',
                    ln_ret_val);
                do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
                do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                              ln_ret_val);
                do_mail_utils.send_mail_line (
                       'Content-Disposition: attachment; filename="Invoices_On_Hold_'
                    || TO_CHAR (SYSDATE, 'RRRRMMDD')
                    || '.xls"',
                    ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);

                apps.do_mail_utils.send_mail_line (
                       'Operating Unit'                 --Added for change 1.1
                    || CHR (9)
                    || 'Invoice Number'
                    || CHR (9)
                    || 'Vendor Name'
                    || CHR (9)
                    || 'Site'
                    || CHR (9)
                    || 'Invoice Amount'
                    || CHR (9)
                    || 'Line Num'
                    || CHR (9)
                    || 'Line Type'
                    || CHR (9)
                    || 'Description'
                    || CHR (9)
                    || 'PO Number'
                    || CHR (9)
                    || 'Preparer'                    --Added as per CCR0009845
                    || CHR (9)
                    || 'Requester'                   --Added as per CCR0009845
                    || CHR (9)
                    || 'Approver'                    --Added as per CCR0009845
                    || CHR (9)
                    || 'Hold Type'
                    || CHR (9)
                    || 'Hold Reason'
                    || CHR (9)
                    || 'PO Quantity Ordered'
                    || CHR (9)
                    || 'Quantity Billed'                --Added for change 1.1
                    || CHR (9)
                    || 'PO Quantity Received'
                    || CHR (9)
                    || 'Quantity Invoiced'
                    || CHR (9)
                    || 'UOM'
                    || CHR (9)
                    || 'Invoice line Unit Price'
                    || CHR (9)
                    || 'Invoice Line Amount'
                    || CHR (9)
                    || 'PO Line Unit Price'
                    || CHR (9)
                    || 'PO Line Total'
                    || CHR (9)
                    || 'Receipt Total'
                    --Start changes as per version CCR0007257
                    || CHR (9)
                    || 'Invoice Date'
                    || CHR (9)
                    || 'Invoice Create Date'
                    || CHR (9)
                    || 'Invoice Due Date'
                    --End changes as per version CCR0007257
                    || CHR (9),
                    ln_ret_val);

                FOR inv_det_rec
                    IN inv_det_cur (pn_batch_id, prep_rec.preparer_id)
                LOOP
                    lv_out_line   := NULL;
                    lv_out_line   :=
                           inv_det_rec.operating_unit --Operating Unit  --Added for change 1.1
                        || CHR (9)
                        || inv_det_rec.Invoice_num            --Invoice Number
                        || CHR (9)
                        || inv_det_rec.Vendor_name               --Vendor Name
                        || CHR (9)
                        || inv_det_rec.Vendor_site                      --Site
                        || CHR (9)
                        || inv_det_rec.invoice_amount         --Invoice Amount
                        || CHR (9)
                        || inv_det_rec.invoice_line_number          --Line Num
                        || CHR (9)
                        || inv_det_rec.line_type                   --Line Type
                        || CHR (9)
                        || inv_det_rec.inv_line_desc             --Description
                        || CHR (9)
                        || inv_det_rec.po_number                   --PO Number
                        || CHR (9)
                        || inv_det_rec.preparer_name --Preparer  --Added as per CCR0009845
                        || CHR (9)
                        || inv_det_rec.requester_name --Requester --Added as per CCR0009845
                        || CHR (9)
                        || inv_det_rec.approver_name --Approver  --Added as per CCR0009845
                        || CHR (9)
                        || inv_det_rec.hold_code                   --Hold Type
                        || CHR (9)
                        || inv_det_rec.hold_reason               --Hold Reason
                        || CHR (9)
                        || inv_det_rec.po_line_quantity  --PO Quantity Ordered
                        || CHR (9)
                        || inv_det_rec.shipment_billed --Quantity Billed  --Added for change 1.1
                        || CHR (9)
                        || inv_det_rec.shipment_received --PO Quantity Received
                        || CHR (9)
                        || inv_det_rec.quantity_invoiced   --Quantity Invoiced
                        || CHR (9)
                        || inv_det_rec.uom                               --UOM
                        || CHR (9)
                        || inv_det_rec.invoice_line_unit_price --Invoice line Unit Price
                        || CHR (9)
                        || inv_det_rec.invoice_line_amount --Invoice Line Amount
                        || CHR (9)
                        || inv_det_rec.po_line_unit_price --PO Line Unit Price
                        || CHR (9)
                        || inv_det_rec.po_line_amount          --PO Line Total
                        || CHR (9)
                        || inv_det_rec.receipt_total           --Receipt Total
                        --Start changes as per version CCR0007257
                        || CHR (9)
                        || inv_det_rec.invoice_date             --Invoice Date
                        || CHR (9)
                        || inv_det_rec.invoice_create_date --Invoice Creation Date
                        || CHR (9)
                        || inv_det_rec.invoice_due_date --Invoice Schedule Due Date
                        --End changes as per version CCR0007257
                        || CHR (9);

                    apps.do_mail_utils.send_mail_line (lv_out_line,
                                                       ln_ret_val);
                END LOOP;

                apps.do_mail_utils.send_mail_close (ln_ret_val);
            END LOOP;                                           --prep_cur end
        ELSE                                                             --1.3
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Send Email parameter is selected as N, Skipping sending the email to preparers');
        END IF;                                                          --1.3
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.do_mail_utils.send_mail_close (ln_ret_val);
            msg (
                   'In When others exception in email_to_preparers procedure. Error is: '
                || SQLERRM,
                'LOG');
            RETURN;                               --stop the program execution
    END email_to_preparers;

    --Procedure to send email to Director Of Payables
    PROCEDURE email_to_dir_payables (pn_batch_id IN NUMBER, pv_send_email IN VARCHAR2, --1.3
                                                                                       pv_test_email_id IN VARCHAR2 --1.3
                                                                                                                   )
    AS
        CURSOR inv_by_prep_cur IS
              SELECT tmp.batch_id, tmp.preparer_id, NVL (ppx.full_name, fu.description) preparer_name,
                     NVL (ppx.email_address, fu.email_address) email_sent_to, COUNT (DISTINCT invoice_num) count_of_invoices_on_hold
                FROM xxdo.xxdoap_inv_onhold_notif_temp tmp, apps.fnd_user fu, apps.per_people_x ppx
               WHERE     1 = 1
                     AND tmp.batch_id = pn_batch_id
                     AND tmp.preparer_id = fu.employee_id
                     AND tmp.preparer_id = ppx.person_id
                     AND NVL (fu.end_date, SYSDATE) >= SYSDATE
            GROUP BY tmp.batch_id, tmp.preparer_id, --               fu.email_address,
                                                    --               ppx.email_address,
                                                    NVL (ppx.email_address, fu.email_address),
                     NVL (ppx.full_name, fu.description)
            ORDER BY email_sent_to;

        -- 1.3 changes start
        CURSOR inv_det_cur (pn_batch_id IN NUMBER)
        IS
              SELECT hou.name operating_unit, ppx.full_name preparer, xiot.*
                FROM xxdo.xxdoap_inv_onhold_notif_temp xiot, apps.hr_operating_units hou, apps.fnd_user fu,
                     apps.per_people_x ppx
               WHERE     1 = 1
                     AND xiot.batch_id = pn_batch_id
                     AND xiot.org_id = hou.organization_id
                     AND xiot.preparer_id = fu.employee_id
                     AND xiot.preparer_id = ppx.person_id
                     AND NVL (fu.end_date, SYSDATE) >= SYSDATE
            ORDER BY operating_unit, xiot.invoice_date, xiot.invoice_num,
                     xiot.invoice_line_number;

        --1.3 changes end

        ln_ret_val          NUMBER := 0;
        v_def_mail_recips   do_mail_utils.tbl_recips;
        ex_no_recips        EXCEPTION;
        ex_no_sender        EXCEPTION;
        ex_no_data_found    EXCEPTION;
        ln_cnt              NUMBER := 0;
        lv_out_line         VARCHAR2 (4000);                             --1.3



        lv_disp_flag        VARCHAR2 (1) := 'N';
        lv_inst_name        VARCHAR2 (20);
    --        lv_msg              VARCHAR2(32000);

    BEGIN
        msg ('In sending Summary email to Director of payables procedure',
             'LOG');

        BEGIN
            SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') applications_system_name
              INTO lv_inst_name
              FROM fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inst_name   := '';
                msg (
                       'Error getting the instance name in email_to_dir_payables procedure: '
                    || SQLERRM,
                    'LOG');
        END;

        --msg('Summary Report', 'OUT'); --1.3
        --msg('--------------', 'OUT'); --1.3
        --        msg('Email Sent To                               Count of Invoices on hold', 'OUT');
        --        msg('---------------                             --------------------------', 'OUT');

        --Writing to the Output File --START
        /*  FOR inv_by_prep_rec IN inv_by_prep_cur
          LOOP

              IF lv_disp_flag = 'N'
              THEN

                  msg('Email Sent To                               Count of Invoices on hold', 'OUT');
                  msg('---------------                             --------------------------', 'OUT');

              END IF;

              msg(RPAD(inv_by_prep_rec.email_sent_to,45,' ')||LPAD(inv_by_prep_rec.count_of_invoices_on_hold,25,' '), 'OUT');

              lv_disp_flag := 'Y';


          END LOOP;*/


        --1.3 changes start

        lv_disp_flag   := 'N';

        FOR inv_det_rec IN inv_det_cur (pn_batch_id)
        LOOP
            IF lv_disp_flag = 'N'
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       'Operating Unit'                 --Added for change 1.1
                    || CHR (9)
                    || 'Invoice Number'
                    || CHR (9)
                    || 'Vendor Name'
                    || CHR (9)
                    || 'Site'
                    || CHR (9)
                    || 'Invoice Amount'
                    || CHR (9)
                    || 'Line Num'
                    || CHR (9)
                    || 'Line Type'
                    || CHR (9)
                    || 'Description'
                    || CHR (9)
                    || 'PO Number'
                    || CHR (9)
                    || 'Preparer'                    --Added as per CCR0009845
                    || CHR (9)
                    || 'Requester'                   --Added as per CCR0009845
                    || CHR (9)
                    || 'Approver'                    --Added as per CCR0009845
                    || CHR (9)
                    || 'Hold Type'
                    || CHR (9)
                    || 'Hold Reason'
                    || CHR (9)
                    || 'PO Quantity Ordered'
                    || CHR (9)
                    || 'Quantity Billed'                --Added for change 1.1
                    || CHR (9)
                    || 'PO Quantity Received'
                    || CHR (9)
                    || 'Quantity Invoiced'
                    || CHR (9)
                    || 'UOM'
                    || CHR (9)
                    || 'Invoice line Unit Price'
                    || CHR (9)
                    || 'Invoice Line Amount'
                    || CHR (9)
                    || 'PO Line Unit Price'
                    || CHR (9)
                    || 'PO Line Total'
                    || CHR (9)
                    || 'Receipt Total'
                    --Start changes as per version CCR0007257
                    || CHR (9)
                    || 'Invoice Date'
                    || CHR (9)
                    || 'Invoice Create Date'
                    || CHR (9)
                    || 'Invoice Due Date'
                    || CHR (9)
                    || 'Preparer'
                    --End changes as per version CCR0007257
                    || CHR (9));
            END IF;


            FND_FILE.PUT_LINE (
                FND_FILE.OUTPUT,
                   inv_det_rec.operating_unit --Operating Unit  --Added for change 1.1
                || CHR (9)
                || inv_det_rec.Invoice_num                    --Invoice Number
                || CHR (9)
                || inv_det_rec.Vendor_name                       --Vendor Name
                || CHR (9)
                || inv_det_rec.Vendor_site                              --Site
                || CHR (9)
                || inv_det_rec.invoice_amount                 --Invoice Amount
                || CHR (9)
                || inv_det_rec.invoice_line_number                  --Line Num
                || CHR (9)
                || inv_det_rec.line_type                           --Line Type
                || CHR (9)
                || inv_det_rec.inv_line_desc                     --Description
                || CHR (9)
                || inv_det_rec.po_number                           --PO Number
                || CHR (9)
                || inv_det_rec.preparer_name --Preparer  --Added as per CCR0009845
                || CHR (9)
                || inv_det_rec.requester_name --Requester --Added as per CCR0009845
                || CHR (9)
                || inv_det_rec.approver_name --Approver  --Added as per CCR0009845
                || CHR (9)
                || inv_det_rec.hold_code                           --Hold Type
                || CHR (9)
                || inv_det_rec.hold_reason                       --Hold Reason
                || CHR (9)
                || inv_det_rec.po_line_quantity          --PO Quantity Ordered
                || CHR (9)
                || inv_det_rec.shipment_billed --Quantity Billed  --Added for change 1.1
                || CHR (9)
                || inv_det_rec.shipment_received        --PO Quantity Received
                || CHR (9)
                || inv_det_rec.quantity_invoiced           --Quantity Invoiced
                || CHR (9)
                || inv_det_rec.uom                                       --UOM
                || CHR (9)
                || inv_det_rec.invoice_line_unit_price --Invoice line Unit Price
                || CHR (9)
                || inv_det_rec.invoice_line_amount       --Invoice Line Amount
                || CHR (9)
                || inv_det_rec.po_line_unit_price         --PO Line Unit Price
                || CHR (9)
                || inv_det_rec.po_line_amount                  --PO Line Total
                || CHR (9)
                || inv_det_rec.receipt_total                   --Receipt Total
                --Start changes as per version CCR0007257
                || CHR (9)
                || inv_det_rec.invoice_date                     --Invoice Date
                || CHR (9)
                || inv_det_rec.invoice_create_date     --Invoice Creation Date
                || CHR (9)
                || inv_det_rec.invoice_due_date    --Invoice Schedule Due Date
                || CHR (9)
                || inv_det_rec.preparer
                --End changes as per version CCR0007257
                || CHR (9));

            lv_disp_flag   := 'Y';
        END LOOP;

        --1.3 changes end

        IF lv_disp_flag = 'N'
        THEN
            msg ('No Invoices onhold. Emails not sent to Preparers', 'OUT');
        END IF;

        --Writing to the Output File --END

        IF pv_send_email = 'Y'
        THEN                                                            -- 1.3
            --Getting the email ID's to which the Summary Email has to be sent

            v_def_mail_recips   :=
                get_email_recips ('XXDOAP_HOLD_NOTIF_DIST_LIST');


            IF v_def_mail_recips.COUNT < 1
            THEN
                RAISE ex_no_recips;
            END IF;

            do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), --Sender Email ID
                                                                                       v_def_mail_recips, --Recipient Email ID's
                                                                                                          -- 'Invoices on hold notification summary - '|| TO_CHAR (SYSDATE, 'MM/DD/YYYY') || ' from '||lv_inst_name||' instance',  --Subject of Email--1.3
                                                                                                          'Invoices on hold notification Summary/Detail - ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY') || ' from ' || lv_inst_name || ' instance'
                                            ,          --Subject of Email--1.3
                                              ln_ret_val        --Return Value
                                                        );
            -- do_mail_utils.send_mail_line ('Content-Type: text/plain', ln_ret_val);--1.3
            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);                                             --1.3
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);             --Added

            --            do_mail_utils.send_mail_line ('Content-Type: text/plain', ln_ret_val); --Not Required

            --Opening the cursor to send Summary email
            FOR inv_by_prep_rec IN inv_by_prep_cur
            LOOP
                IF NVL (ln_cnt, 0) = 0
                THEN
                    --do_mail_utils.send_mail_line ('Email Sent To                               Count of Invoices on hold', ln_ret_val);
                    --do_mail_utils.send_mail_line ('---------------                             --------------------------', ln_ret_val);
                    --do_mail_utils.send_mail_line (RPAD ('Email Sent To', 45, ' ') || RPAD ('Count of Invoices on hold', 25, ' '), ln_ret_val);
                    --do_mail_utils.send_mail_line (RPAD ('---------------------', 45, ' ') || RPAD ('-------------------------', 25, ' '), ln_ret_val);

                    do_mail_utils.send_mail_line (
                           'Email Sent To'
                        || CHR (9)
                        || CHR (9)
                        || CHR (9)
                        || CHR (9)
                        || 'Count of Invoices on hold',
                        ln_ret_val);
                    do_mail_utils.send_mail_line (
                           '-----------------'
                        || CHR (9)
                        || CHR (9)
                        || CHR (9)
                        || CHR (9)
                        || '--------------------------------',
                        ln_ret_val);
                END IF;

                --lv_msg := RPAD(inv_by_prep_rec.email_sent_to,45,' ')||LPAD(inv_by_prep_rec.count_of_invoices_on_hold,25,' ') || CHR(10) || lv_msg;
                --do_mail_utils.send_mail_line (RPAD(inv_by_prep_rec.email_sent_to,45,' ')||LPAD(inv_by_prep_rec.count_of_invoices_on_hold,25,' '), ln_ret_val);
                do_mail_utils.send_mail_line (
                       inv_by_prep_rec.email_sent_to
                    || CHR (9)
                    || CHR (9)
                    || CHR (9)
                    || CHR (9)
                    || CHR (9)
                    || inv_by_prep_rec.count_of_invoices_on_hold,
                    ln_ret_val);
                --            do_mail_utils.send_mail_line (inv_by_prep_rec.email_sent_to||CHR(9)||CHR(9)||CHR(9)||CHR(9)||CHR(9)||inv_by_prep_rec.count_of_invoices_on_hold, ln_ret_val);

                ln_cnt   := NVL (ln_cnt, 0) + 1;
            END LOOP;

            --1.3 chnges strt
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Invoices_On_Hold_'
                || TO_CHAR (SYSDATE, 'RRRRMMDD')
                || '.xls"',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);

            apps.do_mail_utils.send_mail_line (
                   'Operating Unit'                     --Added for change 1.1
                || CHR (9)
                || 'Invoice Number'
                || CHR (9)
                || 'Vendor Name'
                || CHR (9)
                || 'Site'
                || CHR (9)
                || 'Invoice Amount'
                || CHR (9)
                || 'Line Num'
                || CHR (9)
                || 'Line Type'
                || CHR (9)
                || 'Description'
                || CHR (9)
                || 'PO Number'
                || CHR (9)
                || 'Preparer'                        --Added as per CCR0009845
                || CHR (9)
                || 'Requester'                       --Added as per CCR0009845
                || CHR (9)
                || 'Approver'                        --Added as per CCR0009845
                || CHR (9)
                || 'Hold Type'
                || CHR (9)
                || 'Hold Reason'
                || CHR (9)
                || 'PO Quantity Ordered'
                || CHR (9)
                || 'Quantity Billed'                    --Added for change 1.1
                || CHR (9)
                || 'PO Quantity Received'
                || CHR (9)
                || 'Quantity Invoiced'
                || CHR (9)
                || 'UOM'
                || CHR (9)
                || 'Invoice line Unit Price'
                || CHR (9)
                || 'Invoice Line Amount'
                || CHR (9)
                || 'PO Line Unit Price'
                || CHR (9)
                || 'PO Line Total'
                || CHR (9)
                || 'Receipt Total'
                --Start changes as per version CCR0007257
                || CHR (9)
                || 'Invoice Date'
                || CHR (9)
                || 'Invoice Create Date'
                || CHR (9)
                || 'Invoice Due Date'
                --End changes as per version CCR0007257
                || CHR (9),
                ln_ret_val);

            FOR inv_det_rec IN inv_det_cur (pn_batch_id)
            LOOP
                lv_out_line   := NULL;
                lv_out_line   :=
                       inv_det_rec.operating_unit --Operating Unit  --Added for change 1.1
                    || CHR (9)
                    || inv_det_rec.Invoice_num                --Invoice Number
                    || CHR (9)
                    || inv_det_rec.Vendor_name                   --Vendor Name
                    || CHR (9)
                    || inv_det_rec.Vendor_site                          --Site
                    || CHR (9)
                    || inv_det_rec.invoice_amount             --Invoice Amount
                    || CHR (9)
                    || inv_det_rec.invoice_line_number              --Line Num
                    || CHR (9)
                    || inv_det_rec.line_type                       --Line Type
                    || CHR (9)
                    || inv_det_rec.inv_line_desc                 --Description
                    || CHR (9)
                    || inv_det_rec.po_number                       --PO Number
                    || CHR (9)
                    || inv_det_rec.preparer_name --Preparer  --Added as per CCR0009845
                    || CHR (9)
                    || inv_det_rec.requester_name --Requester --Added as per CCR0009845
                    || CHR (9)
                    || inv_det_rec.approver_name --Approver  --Added as per CCR0009845
                    || CHR (9)
                    || inv_det_rec.hold_code                       --Hold Type
                    || CHR (9)
                    || inv_det_rec.hold_reason                   --Hold Reason
                    || CHR (9)
                    || inv_det_rec.po_line_quantity      --PO Quantity Ordered
                    || CHR (9)
                    || inv_det_rec.shipment_billed --Quantity Billed  --Added for change 1.1
                    || CHR (9)
                    || inv_det_rec.shipment_received    --PO Quantity Received
                    || CHR (9)
                    || inv_det_rec.quantity_invoiced       --Quantity Invoiced
                    || CHR (9)
                    || inv_det_rec.uom                                   --UOM
                    || CHR (9)
                    || inv_det_rec.invoice_line_unit_price --Invoice line Unit Price
                    || CHR (9)
                    || inv_det_rec.invoice_line_amount   --Invoice Line Amount
                    || CHR (9)
                    || inv_det_rec.po_line_unit_price     --PO Line Unit Price
                    || CHR (9)
                    || inv_det_rec.po_line_amount              --PO Line Total
                    || CHR (9)
                    || inv_det_rec.receipt_total               --Receipt Total
                    --Start changes as per version CCR0007257
                    || CHR (9)
                    || inv_det_rec.invoice_date                 --Invoice Date
                    || CHR (9)
                    || inv_det_rec.invoice_create_date --Invoice Creation Date
                    || CHR (9)
                    || inv_det_rec.invoice_due_date --Invoice Schedule Due Date
                    --End changes as per version CCR0007257
                    || CHR (9);

                apps.do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
            END LOOP;

            -- 1.3 changes end

            IF ln_cnt = 0
            THEN
                do_mail_utils.send_mail_line (
                    'No Invoices on Hold. Emails not sent to Preparers ',
                    ln_ret_val);
            END IF;

            --msg(lv_msg, 'LOG');
            --do_mail_utils.send_mail_line (lv_msg, ln_ret_val);
            do_mail_utils.send_mail_close (ln_ret_val);
        ELSE                                                             --1.3
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Send Email parameter is selected as N, Skipping sending the email to Track Leads');
        END IF;                                                          --1.3
    EXCEPTION
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            msg (
                   'In When others exception in email_to_dir_payables procedure. Error is: '
                || SQLERRM,
                'LOG');
            RETURN;                               --stop the program execution
    END email_to_dir_payables;

    --Procedure to purge data in temp or staging table
    PROCEDURE purge_data (pn_rentention_days IN NUMBER DEFAULT 30)
    AS
    BEGIN
        DELETE FROM
            xxdo.xxdoap_inv_onhold_notif_temp
              WHERE     1 = 1
                    AND TRUNC (creation_date) <
                        TRUNC (creation_date - pn_rentention_days);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Error while purging data from temp table xxdo.xxdoap_inv_onhold_notif_temp is: '
                || SQLERRM,
                'LOG');
    END purge_data;
END XXDOAP_INV_ONHOLD_NOTIF_PKG;
/
