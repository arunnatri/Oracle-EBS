--
-- XXDOAP009_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAP009_REP_PKG"
AS
    /******************************************************************************
       NAME: XXDOAP009_REP_PKG
       REP NAME:AP Parked Invoices - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       03/07/2011     Shibu        1. Created this package for XXDOAP009_REP_PKG Report
       2.0       17/01/2017     Infosys      2. Pick parked invoices even if appover is NULL -INC0337684
    ******************************************************************************/
    PROCEDURE parked_invoices (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_org_id NUMBER
                               , pn_vendor_id NUMBER, pv_pgrp_id VARCHAR2)
    IS
        CURSOR c_main (pn_org_id NUMBER, pn_vendor_id NUMBER)
        IS
            SELECT hou.NAME operating_unit,
                   hou.organization_id,
                   aia.pay_group_lookup_code,
                   asa.vendor_name,
                   asa.segment1 vendor_num,
                   assa.vendor_site_code,
                   aia.invoice_num invoice_number,
                   aia.invoice_currency_code entered_currency_code--added by murali 07/02
                                                                  ,
                   TO_CHAR (aia.invoice_date, 'DD-MON-YYYY') invoice_date-- added by Venkatesh_Sunera(ENHC0011007)
                                                                         ,
                   aia.invoice_amount invoice_header_amount-- , aia.approval_status approval_status
                                                           ,
                   aia.attribute4 approver,
                   aia.attribute2 date_sent_to_approver,
                   aia.attribute3 miscnotes,
                   DECODE (apps.ap_invoices_pkg.get_approval_status (
                               aia.invoice_id,
                               aia.invoice_amount,
                               aia.payment_status_flag,
                               aia.invoice_type_lookup_code),
                           'NEVER APPROVED', 'NEVER VALIDATED',
                           'NEEDS REAPPROVAL', 'NEEDS REVALIDATION',
                           'Other') invoice_status,
                   aia.doc_sequence_value voucher_num
              FROM apps.ap_invoices_all aia, apps.hr_operating_units hou, apps.ap_suppliers asa,
                   apps.ap_supplier_sites_all assa
             WHERE     aia.org_id = hou.organization_id
                   AND aia.vendor_id = asa.vendor_id
                   AND aia.vendor_id = assa.vendor_id
                   AND aia.vendor_site_id = assa.vendor_site_id
                   --AND hou.organization_id = pv_org_id
                   --AND aia.attribute4 IS NOT NULL      --Commented as part of change for Ver 2.0
                   AND DECODE (apps.ap_invoices_pkg.get_approval_status (
                                   aia.invoice_id,
                                   aia.invoice_amount,
                                   aia.payment_status_flag,
                                   aia.invoice_type_lookup_code),
                               'NEVER APPROVED', 'NEVER VALIDATED',
                               'NEEDS REAPPROVAL', 'NEEDS REVALIDATION',
                               'Other') IN
                           ('NEVER VALIDATED', 'NEEDS REVALIDATION')
                   AND hou.organization_id =
                       NVL (pn_org_id, hou.organization_id)
                   AND asa.vendor_id = NVL (pn_vendor_id, asa.vendor_id)
                   AND NVL (aia.pay_group_lookup_code, 'XXDO') =
                       NVL (pv_pgrp_id,
                            NVL (aia.pay_group_lookup_code, 'XXDO'));

        lv_detils   VARCHAR2 (32000);
    BEGIN
        -- Set Header Line
        lv_detils   :=
               'Operating Unit'
            || CHR (9)
            || 'PAY_GROUP_LOOKUP_CODE'
            || CHR (9)
            || 'Vendor Name'
            || CHR (9)
            || 'Vendor Number'
            || CHR (9)
            || 'Vendor Site Code'
            || CHR (9)
            || 'Invoice_Number'
            || CHR (9)
            || 'Invoice_Date'
            || CHR (9)
            || 'Voucher_Num'
            || CHR (9)
            || 'Approver'
            || CHR (9)
            || 'Date_Sent_to_Approver'
            || CHR (9)
            || 'Misc_Notes'
            || CHR (9)
            || 'Invoice_Status'
            || CHR (9)
            || 'ENTERED_CURRENCY_CODE'
            || CHR (9)                                 --added by murali 07/02
            || 'Invoice_Amount';
        apps.fnd_file.put_line (apps.fnd_file.output, lv_detils);

        FOR i IN c_main (pn_org_id, pn_vendor_id)
        LOOP
            -- Set Detail Line
            lv_detils   :=
                   i.operating_unit
                || CHR (9)
                || i.pay_group_lookup_code
                || CHR (9)
                || i.vendor_name
                || CHR (9)
                || i.vendor_num
                || CHR (9)
                || i.vendor_site_code
                || CHR (9)
                || i.invoice_number
                || CHR (9)
                || i.invoice_date
                || CHR (9)
                || i.voucher_num
                || CHR (9)
                || i.approver
                || CHR (9)
                || i.date_sent_to_approver
                || CHR (9)
                || i.miscnotes
                || CHR (9)
                || i.invoice_status
                || CHR (9)
                || i.entered_currency_code
                || CHR (9)                             --added by murali 07/02
                || i.invoice_header_amount;
            -- Write Detail Line
            apps.fnd_file.put_line (apps.fnd_file.output, lv_detils);
        END LOOP;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --DBMS_OUTPUT.PUT_LINE('NO DATA FOUND'|| SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'NO_DATA_FOUND');
            pv_errbuf    := 'No Data Found' || SQLCODE || SQLERRM;
            pv_retcode   := -1;
        WHEN INVALID_CURSOR
        THEN
            -- DBMS_OUTPUT.PUT_LINE('INVALID CURSOR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'INVALID_CURSOR');
            pv_errbuf    := 'Invalid Cursor' || SQLCODE || SQLERRM;
            pv_retcode   := -2;
        WHEN TOO_MANY_ROWS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('TOO MANY ROWS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'TOO_MANY_ROWS');
            pv_errbuf    := 'Too Many Rows' || SQLCODE || SQLERRM;
            pv_retcode   := -3;
        WHEN PROGRAM_ERROR
        THEN
            --    DBMS_OUTPUT.PUT_LINE('PROGRAM ERROR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'PROGRAM_ERROR');
            pv_errbuf    := 'Program Error' || SQLCODE || SQLERRM;
            pv_retcode   := -4;
        WHEN OTHERS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'OTHERS');
            pv_errbuf    := 'Unhandled Error' || SQLCODE || SQLERRM;
            pv_retcode   := -5;
    END parked_invoices;
END xxdoap009_rep_pkg;
/
