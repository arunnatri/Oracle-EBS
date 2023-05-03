--
-- XXD_IR_ISO_ALERT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_IR_ISO_ALERT_PKG"
/****************************************************************************************
* Package : XXD_IR_ISO_ALERT_PKG
* Author : BT Technology Team
* Created : 23-APR-2016
* Program Name : Deckers Alert For IR ISO Alert
*
* Modification :
*----------------------------------------------------------------------------------------
* Date    Developer    Version Description
*----------------------------------------------------------------------------------------
* 23-APR-2016  BT Technology Team  1.0  Created package script
* 06-Jan-2023   Aravind Kannuri     1.1     Updated for CCR0009817 - HK Wholesale Changes
*****************************************************************************************/
AS
    --------------------------------------------------------------------------------------
    -- Procedure to log messages
    --------------------------------------------------------------------------------------
    PROCEDURE print_log_prc (p_msg IN VARCHAR2)
    IS
    BEGIN
        IF p_msg IS NOT NULL
        THEN
            --DBMS_OUTPUT.put_line ('Msg :' || p_msg);
            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;

        RETURN;
    END print_log_prc;

    --------------------------------------------------------------------------------------
    -- Main Procedure to send email
    --------------------------------------------------------------------------------------
    PROCEDURE main (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2)
    IS
        lc_db_name             VARCHAR2 (50);
        lc_override_email_id   VARCHAR2 (1996);
        --      lc_connection          UTL_SMTP.connection;
        --      lc_error_status        VARCHAR2 (1) := 'E';
        --      lc_success_status      VARCHAR2 (1) := 'S';
        --      lc_port                NUMBER := 25;
        --Smtp Domain name derived from profile
        --      lc_host                VARCHAR2 (256)
        --                                := fnd_profile.VALUE ('FND_SMTP_HOST');
        --      lc_from_address        VARCHAR2 (100);
        --      lc_email_address       VARCHAR2 (100) := NULL;
        --      le_mail_exception      EXCEPTION;
        lc_email_body_hdr      VARCHAR2 (2000) := NULL;
        lc_program_run_date    VARCHAR2 (30)
            := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS');
        lc_subject             VARCHAR2 (1000) := NULL;
        lc_body                VARCHAR2 (32767) := NULL;

        CURSOR ir_iso_date_cur IS
              SELECT /*+ PARALLEL(8) */
                     prh.segment1 req_number, prl.line_num req_line_num, ola.actual_shipment_date,
                     ola.schedule_ship_date, poh.segment1 po_number, pol.line_num po_line_num,
                     TRUNC (plla.promised_date) promised_date, rsh.expected_receipt_date exp_receipt_date, rsh.shipment_num ir_shipment_num,
                     po_rsh.expected_receipt_date po_exp_receipt_date, po_rsh.shipment_num po_shipment_num, ola.request_date,
                     ood.organization_code destination_org, ood2.organization_code ship_to_org
                FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.rcv_shipment_lines po_rsl,
                     apps.rcv_shipment_headers po_rsh, apps.mtl_material_transactions mmt, apps.po_requisition_lines_all prl,
                     apps.po_requisition_headers_all prh, apps.wsh_delivery_details wdd, apps.wsh_new_deliveries wnd,
                     apps.wsh_delivery_assignments wda, apps.oe_order_lines_all ola, apps.oe_order_headers_all oha,
                     apps.po_line_locations_all plla, apps.po_lines_all pol, apps.hr_operating_units hou,
                     apps.po_headers_all poh, apps.org_organization_definitions ood, apps.org_organization_definitions ood2
               WHERE     1 = 1
                     AND prl.requisition_line_id = rsl.requisition_line_id
                     AND rsh.shipment_header_id = rsl.shipment_header_id
                     AND mmt.transaction_id = rsl.mmt_transaction_id
                     AND wdd.delivery_detail_id = mmt.picking_line_id
                     AND mmt.source_line_id = wdd.source_line_id
                     AND prl.requisition_header_id = prh.requisition_header_id
                     AND ola.source_document_line_id = prl.requisition_line_id
                     AND ola.header_id = oha.header_id
                     AND wdd.source_header_id = ola.header_id
                     AND wdd.source_line_id = ola.line_id
                     AND wda.delivery_detail_id = wdd.delivery_detail_id
                     AND wda.delivery_id = wnd.delivery_id
                     AND wdd.source_code = 'OE'
                     --and ola.header_id =2788338
                     AND ola.attribute16 = plla.line_location_id
                     AND poh.po_header_id = plla.po_header_id
                     AND pol.po_header_id = poh.po_header_id
                     AND pol.po_line_id = plla.po_line_id
                     AND poh.authorization_status IN ('APPROVED')
                     AND hou.organization_id = poh.org_id
                     AND hou.NAME LIKE 'Deckers Macau OU'
                     AND po_rsl.po_line_id = pol.po_line_id
                     AND po_rsh.shipment_header_id = po_rsl.shipment_header_id
                     AND TRUNC (po_rsh.creation_date) =
                         TRUNC (rsh.shipped_date)
                     AND TRUNC (rsh.expected_receipt_date) =
                         TRUNC (rsh.shipped_date)
                     AND prl.destination_organization_id = ood.organization_id
                     AND plla.ship_to_organization_id = ood2.organization_id
                     --Added APB Organization for 1.1
                     AND prl.destination_organization_id IN (121, 122, 116,
                                                             117, 281, 124,
                                                             126, 133)
            --AND ROWNUM <= 3
            ORDER BY prh.segment1;
    BEGIN
        print_log_prc ('Begin main procedure ' || lc_program_run_date);

        BEGIN
            SELECT SYS_CONTEXT ('userenv', 'db_name')
              INTO lc_db_name
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_log_prc ('Error deriving DB name:' || SQLERRM);
        END;

        print_log_prc ('Database name: ' || lc_db_name);
        lc_email_body_hdr   :=
               '<html><body>'
            || 'The following Internal Requisition ASN contains incorrect Expected Receipt Dates.  Please update the the Internal Requisition ASN Expected Receipt Dates based on the associated Macau Factory ASN Expected Receipt Date. '
            || ' <br>'
            || '<table border="1" width="99%">'
            || '<tr><b>'
            || '<td width="8%" bgcolor="#cfe0f1" align="center" valign="middle">IR Number</td>'
            || '<td width="4%" bgcolor="#cfe0f1" align="center" valign="middle">IR Line #</td>'
            || '<td width="9%" bgcolor="#cfe0f1" align="center" valign="middle">IR ASN #</td>'
            || '<td width="9%" bgcolor="#cfe0f1" align="center" valign="middle">IR ASN Exp Receipt Date</td>'
            || '<td width="4%" bgcolor="#cfe0f1" align="center" valign="middle">IR ASN Org</td>'
            || '<td width="9%" bgcolor="#cfe0f1" align="center" valign="middle">ISO Request Date</td>'
            || '<td width="9%" bgcolor="#cfe0f1" align="center" valign="middle">ISO Sch Ship Date</td>'
            || '<td width="6%" bgcolor="#cfe0f1" align="center" valign="middle">Macau PO #</td>'
            || '<td width="4%" bgcolor="#cfe0f1" align="center" valign="middle">Macau PO Line #</td>'
            || '<td width="9%" bgcolor="#cfe0f1" align="center" valign="middle">Macau PO Promised Date</td>'
            || '<td width="4%" bgcolor="#cfe0f1" align="center" valign="middle">PO Ship to Org</td>'
            || '<td width="14%" bgcolor="#cfe0f1" align="center" valign="middle">PO ASN #</td>'
            || '<td width="9%" bgcolor="#cfe0f1" align="center" valign="middle">PO ASN Exp Receipt Date</td>'
            || '</b></tr>';
        fnd_file.put_line (fnd_file.output, lc_email_body_hdr);

        FOR ir_iso_date_rec IN ir_iso_date_cur
        LOOP
            --         lv_je_source := posted_journal_rec.je_source;
            --         lv_je_name := posted_journal_rec.name;
            --         lv_email := posted_journal_rec.email;
            --         lv_amount := posted_journal_rec.amount;
            --         lv_currency := posted_journal_rec.currency_code;
            --         lv_batch_name := posted_journal_rec.batch_name;
            --         lv_updated_by := posted_journal_rec.last_updated_by;
            --         lv_created_by := posted_journal_rec.created_by;

            -- temp commented
            --         IF ir_iso_date_rec.schedule_ship_date =
            --               ir_iso_date_rec.exp_receipt_date
            --         THEN
            --         lc_subject :=
            --            'Alert for IR/ISO are having same ASN expected receipt date and Shipped Date ';
            --         lc_body :=
            --               'Req Number '
            --            || ir_iso_date_rec.req_number
            --            || ' Requisition line num '
            --            || ir_iso_date_rec.req_line_num
            --            || ' PO# '
            --            || ir_iso_date_rec.po_number
            --            || ' PO Line # '
            --            || ir_iso_date_rec.po_line_num
            --            || ' Exp receipt date '
            --            || ir_iso_date_rec.exp_receipt_date
            --            || ' without having any control account.';
            lc_body   :=
                   '<tr valign="middle">'
                || '<td width="8%"  align="right">'
                || ir_iso_date_rec.req_number
                || '</td>'
                || '<td width="4%"   align="right">'
                || ir_iso_date_rec.req_line_num
                || '</td>'
                || '<td width="9%"   align="right">'
                || ir_iso_date_rec.ir_shipment_num
                || '</td>'
                || '<td width="9%"   align="right">'
                || ir_iso_date_rec.exp_receipt_date
                || '</td>'
                || '<td width="4%" align="right">'
                || ir_iso_date_rec.destination_org
                || '</td>'
                || '<td width="9%" align="right">'
                || ir_iso_date_rec.request_date
                || '</td>'
                || '<td width="9%" align="right">'
                || ir_iso_date_rec.schedule_ship_date
                || '</td>'
                || '<td width="6%"   align="right">'
                || ir_iso_date_rec.po_number
                || '</td>'
                || '<td width="4%" align="right">'
                || ir_iso_date_rec.po_line_num
                || '</td>'
                || '<td width="9%" align="right">'
                || ir_iso_date_rec.promised_date
                || '</td>'
                || '<td width="4%" align="right">'
                || ir_iso_date_rec.ship_to_org
                || '</td>'
                || '<td width="14%" align="right">'
                || ir_iso_date_rec.po_shipment_num
                || '</td>'
                || '<td width="9%" align="right">'
                || ir_iso_date_rec.po_exp_receipt_date
                || '</td>'
                || '</tr>';
            fnd_file.put_line (fnd_file.output, lc_body);
        --send_email (lv_recepient, lv_subject, lv_body);
        /****Begin Send Email****/
        --            print_log_prc ('Send email for Journal: ' || lv_je_name);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := '2';
            x_errbuf    := 'Error: ' || SQLERRM;

            IF (ir_iso_date_cur%ISOPEN)
            THEN
                CLOSE ir_iso_date_cur;
            END IF;
    END;
END xxd_ir_iso_alert_pkg;
/
