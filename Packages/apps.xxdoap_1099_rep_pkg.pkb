--
-- XXDOAP_1099_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoap_1099_rep_pkg
AS
    /******************************************************************************
       NAME:       XXDOAP_1099_REP_PKG
       PURPOSE:

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        7/28/2008     Shibu        1. Created this package for AP 1099
       1.1      7/6/2015    BT Technology  Modified for CR 65
    ******************************************************************************/

    /*  This fUNCTION is used to get the  CONTRACT DATE AND AMOUNT FOR 1099 REPORT*/
    FUNCTION f_get_contract_dt_amt (p_vendor_id NUMBER, p_org_id NUMBER, p_start_date VARCHAR2
                                    , p_end_date VARCHAR2, p_col VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR c_main (p_vendor_id NUMBER, p_org_id NUMBER, p_start_date VARCHAR2
                       , p_end_date VARCHAR2)
        IS
              SELECT i.invoice_id, c.check_date, SUM (ID.amount) amount
                FROM apps.ap_invoices_all i, apps.ap_invoice_distributions_all ID, apps.ap_checks_all c,
                     apps.ap_invoice_payments_all ip, apps.po_vendors p
               WHERE     i.invoice_id = ip.invoice_id
                     AND i.invoice_id = ID.invoice_id
                     AND c.check_id = ip.check_id
                     --Start modification by BT Technology Team for CR 65 on 6-JUL-15
                     --AND ip.accounting_date BETWEEN  TO_DATE(P_START_DATE,'YYYY/MM/DD HH24:MI:SS') AND TO_DATE(P_END_DATE,'YYYY/MM/DD HH24:MI:SS')
                     AND ip.accounting_date BETWEEN NVL (
                                                        p_start_date,
                                                        TO_CHAR (
                                                            TRUNC (SYSDATE,
                                                                   'YYYY'),
                                                            'DD-MON-YYYY'))
                                                AND p_end_date
                     --End modification by BT Technology Team for CR 65 on 6-JUL-15
                     AND c.org_id = p_org_id
                     AND c.status_lookup_code <> 'VOIDED'
                     AND ID.type_1099 IS NOT NULL
                     AND ID.type_1099 <> 'MISC4'
                     AND p.vendor_id = p_vendor_id
                     AND i.vendor_id = p.vendor_id
            GROUP BY i.invoice_id, c.check_date
            ORDER BY c.check_date;

        ln_amount   VARCHAR2 (20) := 0;
        lv_date     VARCHAR2 (20);
        l_return    VARCHAR2 (20);
    BEGIN
        FOR i IN c_main (p_vendor_id, p_org_id, p_start_date,
                         p_end_date)
        LOOP
            ln_amount   := ln_amount + i.amount;

            IF ln_amount >= 600
            THEN
                lv_date   := i.check_date;

                EXIT;
            END IF;
        END LOOP;

        IF p_col = 'DT'
        THEN
            l_return   := lv_date;
        ELSIF p_col = 'AMT'
        THEN
            l_return   := ln_amount;
        END IF;

        RETURN l_return;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --DBMS_OUTPUT.PUT_LINE('NO DATA FOUND'|| SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'NO_DATA_FOUND');
            RETURN NULL;
        WHEN INVALID_CURSOR
        THEN
            -- DBMS_OUTPUT.PUT_LINE('INVALID CURSOR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'INVALID_CURSOR');
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('TOO MANY ROWS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'TOO_MANY_ROWS');
            RETURN NULL;
        WHEN PROGRAM_ERROR
        THEN
            --    DBMS_OUTPUT.PUT_LINE('PROGRAM ERROR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'PROGRAM_ERROR');
            RETURN NULL;
        WHEN OTHERS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'OTHERS');
            RETURN NULL;
    END f_get_contract_dt_amt;

    FUNCTION f_insert_valid_vendors (p_start_date VARCHAR2, p_end_date VARCHAR2, p_fed_reportable VARCHAR2, p_query_driver VARCHAR2, p_tax_entity_id NUMBER, c_chart_accts_id NUMBER, p_rep_start_dt VARCHAR2, p_rep_end_dt VARCHAR2, p_taxid_disp VARCHAR2
                                     , p_org_id NUMBER)
        RETURN BOOLEAN
    IS
        l_count_vendors   NUMBER;

        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG, 'p_org_id :' || p_org_id);

        mo_global.init ('S');
        mo_global.set_policy_context ('S', p_org_id);

        DELETE FROM ap_1099_tape_data_all;


        c_app_column_name   := 'SEGMENT1';

        INSERT INTO ap_1099_tape_data (vendor_id, region_code, org_id)
              SELECT /*+ ordered */
                     p.vendor_id, '', i.org_id
                FROM ap_invoice_payments ip, ap_checks c, ce_bank_accounts aba,
                     ce_bank_acct_uses bau, ap_invoices i, po_vendors p,
                     ap_invoice_distributions ID, gl_code_combinations cc, ap_reporting_entity_lines rel
               WHERE     p.vendor_id = i.vendor_id
                     AND ((p_fed_reportable = 'Y' AND p.federal_reportable_flag = 'Y') OR (p_fed_reportable = 'N' OR p_fed_reportable IS NULL))
                     AND i.invoice_id = ip.invoice_id
                     AND i.invoice_id = ID.invoice_id
                     AND c.void_date IS NULL
                     --Start modification by BT Technology Team for CR 65 on 6-JUL-15
                     /* AND to_date(ip.accounting_date,'YYYY/MM/DD HH24:MI:SS') BETWEEN TO_DATE (p_start_date,
                                                                           'YYYY/MM/DD HH24:MI:SS'
                                                                          )
                                                              AND TO_DATE (p_end_date,
                                                                           'YYYY/MM/DD HH24:MI:SS'
                                                                          )*/
                     --AND Trunc(ip.accounting_date) BETWEEN (Trunc(:p_start_date)) AND (Trunc(:p_end_date))
                     AND ip.accounting_date BETWEEN (TO_CHAR (TO_DATE (P_START_DATE, 'YYYY/MM/DD HH24:MI:SS'), 'DD-MON-YY'))
                                                AND (TO_CHAR (TO_DATE (P_END_DATE, 'YYYY/MM/DD HH24:MI:SS'), 'DD-MON-YY'))
                     --End modification by BT Technology Team for CR 65 on 6-JUL-15
                     AND ID.type_1099 IS NOT NULL
                     AND aba.asset_code_combination_id = cc.code_combination_id
                     AND c.ce_bank_acct_use_id = bau.bank_acct_use_id
                     AND bau.bank_account_id = aba.bank_account_id
                     AND c.org_id = p_org_id --Added  by BT Technology Team for CR 65 on 6-JUL-15
                     AND c.check_id = ip.check_id
                     AND rel.tax_entity_id = p_tax_entity_id
                     AND cc.chart_of_accounts_id = c_chart_accts_id
                     AND DECODE (c_app_column_name,
                                 'SEGMENT1', cc.segment1,
                                 'SEGMENT2', cc.segment2,
                                 'SEGMENT3', cc.segment3,
                                 'SEGMENT4', cc.segment4,
                                 'SEGMENT5', cc.segment5,
                                 'SEGMENT6', cc.segment6,
                                 'SEGMENT7', cc.segment7,
                                 'SEGMENT8', cc.segment8,
                                 'SEGMENT9', cc.segment9,
                                 'SEGMENT10', cc.segment10,
                                 'SEGMENT11', cc.segment11,
                                 'SEGMENT12', cc.segment12,
                                 'SEGMENT13', cc.segment13,
                                 'SEGMENT14', cc.segment14,
                                 'SEGMENT15', cc.segment15,
                                 'SEGMENT16', cc.segment16,
                                 'SEGMENT17', cc.segment17,
                                 'SEGMENT18', cc.segment18,
                                 'SEGMENT19', cc.segment19,
                                 'SEGMENT20', cc.segment20,
                                 'SEGMENT21', cc.segment21,
                                 'SEGMENT22', cc.segment22,
                                 'SEGMENT23', cc.segment23,
                                 'SEGMENT24', cc.segment24,
                                 'SEGMENT25', cc.segment25,
                                 'SEGMENT26', cc.segment26,
                                 'SEGMENT27', cc.segment27,
                                 'SEGMENT28', cc.segment28,
                                 'SEGMENT29', cc.segment29,
                                 'SEGMENT30', cc.segment30) =
                         rel.balancing_segment_value
            GROUP BY p.vendor_id, i.org_id
              HAVING    p_min_report_flag = 'N'
                     OR (SUM (DECODE (ID.type_1099, 'MISC1', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) + SUM (DECODE (ID.type_1099, 'MISC3', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) + SUM (DECODE (ID.type_1099, 'MISC6', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) + SUM (DECODE (ID.type_1099, 'MISC7', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) + SUM (DECODE (ID.type_1099, 'MISC9', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) + SUM (DECODE (ID.type_1099, 'MISC10', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) >= 600 OR SUM (DECODE (ID.type_1099, 'MISC2', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) >= 10 OR SUM (DECODE (ID.type_1099, 'MISC8', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) >= 10 OR SUM (DECODE (ID.type_1099, 'MISC15a T', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) + SUM (DECODE (ID.type_1099, 'MISC15a NT', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) >= 600 OR SUM (DECODE (ID.type_1099, 'MISC13', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) + SUM (DECODE (ID.type_1099, 'MISC14', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) + SUM (DECODE (ID.type_1099, 'MISC5', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) > 0 OR SUM (DECODE (ID.type_1099, 'MISC15b', (DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount, NULL, 0, DECODE (GREATEST (ID.accounting_date, TO_DATE (p_end_date, 'YYYY/MM/DD HH24:MI:SS') + 1), ID.accounting_date, 0, DECODE (LEAST (ID.accounting_date, TO_DATE (p_start_date, 'YYYY/MM/DD HH24:MI:SS') - 1), ID.accounting_date, 0, ABS (ID.amount)))), ID.amount) / DECODE (i.invoice_amount, 0, DECODE (i.cancelled_amount,  NULL, 1,  0, 1,  i.cancelled_amount), DECODE (ap_utilities_pkg.net_invoice_amount (i.invoice_id), 0, 1, ap_utilities_pkg.net_invoice_amount (i.invoice_id))) * ip.amount), 0)) > 0);

        COMMIT;              --Added by BT Technology Team on 01-JUL-2015 v1.2

        SELECT COUNT (DISTINCT (vendor_id))
          INTO l_count_vendors
          FROM ap_1099_tape_data_all;

        IF l_count_vendors > 0
        THEN
            fnd_file.put_line (
                apps.fnd_file.LOG,
                'Total Supplier Inserted  ' || l_count_vendors);
            COMMIT;
        ELSE
            fnd_file.put_line (apps.fnd_file.LOG,
                               'Insert into ap_1099_tape_data_all failed');
        END IF;

        RETURN (TRUE);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --DBMS_OUTPUT.PUT_LINE('NO DATA FOUND'|| SQLERRM);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'F_INSERT_VALID_VENDORS   Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'NO_DATA_FOUND');
            RETURN FALSE;
        WHEN INVALID_CURSOR
        THEN
            -- DBMS_OUTPUT.PUT_LINE('INVALID CURSOR' || SQLERRM);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'F_INSERT_VALID_VENDORS  Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'INVALID_CURSOR');
            RETURN FALSE;
        WHEN TOO_MANY_ROWS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('TOO MANY ROWS' || SQLERRM);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'F_INSERT_VALID_VENDORS  Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'TOO_MANY_ROWS');
            RETURN FALSE;
        WHEN PROGRAM_ERROR
        THEN
            --    DBMS_OUTPUT.PUT_LINE('PROGRAM ERROR' || SQLERRM);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'F_INSERT_VALID_VENDORS  Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'PROGRAM_ERROR');
            RETURN FALSE;
        WHEN OTHERS
        THEN
            --    DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'F_INSERT_VALID_VENDORS  Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'OTHERS' || SQLERRM);
            RETURN FALSE;
    END f_insert_valid_vendors;
END xxdoap_1099_rep_pkg;
/
