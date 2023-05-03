--
-- XXDOAR014_REP_SUM_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR014_REP_SUM_PKG"
AS
    /******************************************************************************
     NAME: XXDO.XXDOAR014_REP_SUM_PKG
     REP NAME:Commerce Receipts Report Details - Deckers

     REVISIONS:
     Ver Date Author Description
     --------- ---------- --------------- ------------------------------------
     1.0  14-Mar-2018  Infosys     Initial Creation
     1.1  06-Apr-2020  Aravind Kannuri     Changes as per CCR0007884
                                                Retrofit with Detail Report
    ******************************************************************************/

    FUNCTION before_report
        RETURN BOOLEAN
    IS
        l_receipt_where1   VARCHAR2 (2000);
        l_receipt_where2   VARCHAR2 (2000);
        l_path             VARCHAR2 (240);   --Added by Madhav for ENHC0013063

        --Begin Modifcation for Change Number : CCR0006749
        l_receipt_where3   VARCHAR2 (2000) := NULL;
        l_receipt_where4   VARCHAR2 (2000) := NULL;
    --End Modifcation for Change Number : CCR0006749

    BEGIN
        --l_trx_date_low := FND_DATE.CANONICAL_TO_DATE(argument11);
        --l_trx_date_high := FND_DATE.CANONICAL_TO_DATE(argument12);

        IF P_RECEIPT_TYPE IS NOT NULL
        THEN
            l_receipt_where1   :=
                   ' '
                || 'and rm.ATTRIBUTE2= NVL(:P_RECEIPT_TYPE,rm.ATTRIBUTE2)'
                || ' ';
            l_receipt_where2   :=
                   ' '
                || 'and art.ATTRIBUTE2= NVL(:P_RECEIPT_TYPE,art.ATTRIBUTE2)'
                || ' ';
        END IF;

        IF P_GL_ACCT IS NOT NULL
        THEN
            l_receipt_where1   :=
                   l_receipt_where1
                || 'and bank_acct.gl_cash_account = :P_GL_ACCT'
                || ' ';
            l_receipt_where2   :=
                   l_receipt_where2
                || 'and gcc.concatenated_segments = :P_GL_ACCT'
                || ' ';
        END IF;

        IF P_RECEIPT_TYPE IS NULL AND P_GL_ACCT IS NULL
        THEN
            l_receipt_where1   := NULL;
            l_receipt_where2   := NULL;
        END IF;

        --Begin Modifcation for Change Number : CCR0006749
        IF P_CREAT_DATE_FROM IS NOT NULL OR P_CREAT_DATE_TO IS NOT NULL
        THEN
            l_receipt_where3   :=
                   ' '
                || ' AND TRUNC(cr.creation_date) BETWEEN 
												TRUNC(NVL(TO_DATE(:P_CREAT_DATE_FROM, '
                || '''YYYY/MM/DD HH24:MI:SS'''
                || '),cr.creation_date)) '
                || ' AND TRUNC(NVL(TO_DATE(:P_CREAT_DATE_TO, '
                || '''YYYY/MM/DD HH24:MI:SS'''
                || '),cr.creation_date)) '
                || ' ';
            l_receipt_where4   :=
                   ' '
                || ' AND TRUNC(adj.creation_date) BETWEEN 
												TRUNC(NVL(TO_DATE(:P_CREAT_DATE_FROM, '
                || '''YYYY/MM/DD HH24:MI:SS'''
                || '),adj.creation_date)) '
                || ' AND TRUNC(NVL(TO_DATE(:P_CREAT_DATE_TO, '
                || '''YYYY/MM/DD HH24:MI:SS'''
                || '),adj.creation_date)) '
                || ' ';
        END IF;

        --End Modifcation for Change Number : CCR0006749

        P_SQL_STMT   :=
               ' SELECT org_name,
	  gl_cash_account,
	  trx_date_disp,
	  SUM(amount) amount,
	  receipt_method,
	  payment_tender_type
	FROM
	  (SELECT o.name org_name
     ,bank_acct.gl_cash_account
	 ,TRUNC(cr.receipt_date) trx_date
     ,TO_CHAR(cr.receipt_date, ''DD-MON-RRRR'') trx_date_disp 
     ,DECODE(NVL(app_cr.amount_applied,0), 0, cr.amount, app_cr.amount_applied) amount    
     --START Changes as per CCR0007884
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y''
           THEN NVL(xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => cr.cash_receipt_id, pn_customer_trx_id => app_cr.customer_trx_id)
                    ,rm.attribute2 || DECODE(rm.attribute1, NULL, NULL, '' ''||rm.attribute1))
            ELSE rm.attribute2 || DECODE(rm.attribute1, NULL, NULL, '' ''||rm.attribute1)
        END receipt_method 
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y'' THEN xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => cr.cash_receipt_id, pn_customer_trx_id => app_cr.customer_trx_id)
           ELSE DECODE(rm.attribute2, ''CA'', ''CA'',''PP'',''PP'',''GC'',''GC'',''RM'',''RM'',''RC'',''RC'',''COD'',''COD'',cr.attribute14) 
		END payment_tender_type
	 --END Changes as per CCR0007884  
     FROM apps.ar_cash_receipts_all cr
     ,apps.oe_order_headers_all oeh
     ,apps.ar_receipt_methods rm, apps.ar_payment_schedules_all apsa
     ,(SELECT o.name, o.organization_id FROM apps.hr_all_organization_units o WHERE o.type = ''ECOMM'' AND (o.organization_id = :p_org_id OR NVL(o.attribute1, -999) = :p_org_id)) o
     ,apps.ra_customers c
     ,(SELECT app.cash_receipt_id, app.gl_date, app.status, app.amount_applied, rct.trx_number, oeh.order_number, oeh.cust_po_number, oeh.orig_sys_document_ref
             ,rct.customer_trx_id --Added for change 8.1
             ,oos.name order_source --Added for change 8.1
         FROM apps.ar_receivable_applications_all app, apps.ra_customer_trx_all rct, apps.oe_order_headers_all oeh
             ,apps.oe_order_sources oos --Added for change 8.1
        WHERE app.applied_customer_trx_id = rct.customer_trx_id(+)
          AND DECODE (rct.interface_header_context, ''ORDER ENTRY'', rct.interface_header_attribute1, '''') = oeh.order_number(+)
          AND rct.org_id = oeh.org_id(+)
          AND app.display = ''Y''
          AND oeh.order_source_id = oos.order_source_id(+) --Added for change 8.1
      ) app_cr
     ,(SELECT rm.remit_bank_acct_use_id, rm.receipt_method_id, gcc.concatenated_segments gl_cash_account
         FROM apps.ar_receipt_method_accounts_all rm, apps.gl_code_combinations_kfv gcc
        WHERE rm.cash_ccid = gcc.code_combination_id) bank_acct
    WHERE cr.org_id = o.organization_id
     AND oeh.header_id(+) = cr.attribute15
     AND cr.pay_from_customer = c.customer_id(+) -- Added to fetch UnIdentified Receipts
     AND cr.currency_code = NVL(:p_currency_code, cr.currency_code)
     AND cr.cash_receipt_id = app_cr.cash_receipt_id(+)
     AND cr.remit_bank_acct_use_id = bank_acct.remit_bank_acct_use_id(+)
     AND cr.receipt_method_id = bank_acct.receipt_method_id(+)
     AND cr.receipt_method_id = rm.receipt_method_id(+)
     AND apsa.gl_date BETWEEN TO_DATE(:p_from_date, ''YYYY/MM/DD HH24:MI:SS'') AND TO_DATE(:p_to_date, ''YYYY/MM/DD HH24:MI:SS'')
     and apsa.cash_receipt_id = cr.cash_receipt_id '
            || l_receipt_where1
            || l_receipt_where3
            ||                    --Added date condition as part of CCR0006749
               ' UNION ALL
     SELECT o.name org_name
     ,bank_acct.gl_cash_account
	 ,TRUNC(cr.receipt_date) trx_date
     ,TO_CHAR(cr.receipt_date, ''DD-MON-RRRR'') trx_date_disp     
     ,apsa.amount_due_remaining*-1 amount    
     --START Changes as per CCR0007884
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y''
           THEN NVL(xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => cr.cash_receipt_id, pn_customer_trx_id => NULL)
                   ,rm.attribute2 || DECODE(rm.attribute1, NULL, NULL, '' ''||rm.attribute1))
           ELSE rm.attribute2 || DECODE(rm.attribute1, NULL, NULL, '' ''||rm.attribute1)
       END receipt_method    
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y'' THEN xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => cr.cash_receipt_id, pn_customer_trx_id => NULL)
           ELSE DECODE(rm.attribute2, ''CA'', ''CA'',''PP'',''PP'',''GC'',''GC'',''RM'',''RM'',''RC'',''RC'',''COD'',''COD'',cr.attribute14) 
		END payment_tender_type
	 --END Changes as per CCR0007884
     FROM apps.ar_cash_receipts_all cr
     ,apps.oe_order_headers_all oeh -- added by naresh dasari INC0168588
     ,apps.ar_receipt_methods rm
     ,apps.ar_payment_schedules_all apsa
     ,(SELECT o.name, o.organization_id FROM apps.hr_all_organization_units o WHERE o.TYPE = ''ECOMM'' AND (o.organization_id = :p_org_id OR NVL(o.attribute1, -999) = :p_org_id)) o
     ,apps.ra_customers c
     ,(SELECT rm.remit_bank_acct_use_id, rm.receipt_method_id, gcc.concatenated_segments gl_cash_account
         FROM apps.ar_receipt_method_accounts_all rm, apps.gl_code_combinations_kfv gcc
        WHERE rm.cash_ccid = gcc.code_combination_id) bank_acct
     ,apps.oe_order_sources oos --Added for change 8.1
    WHERE cr.org_id = o.organization_id
     AND oeh.header_id(+) = cr.attribute15 -- Added by naresh dasari INC0168588
     AND oeh.order_source_id = oos.order_source_id(+) --Added for change 8.1
     AND cr.pay_from_customer = c.customer_id(+) -- Added to fetch UnIdentified Receipts
     AND cr.currency_code = NVL(:p_currency_code, cr.currency_code)
     AND cr.cash_receipt_id = apsa.cash_receipt_id 
     AND cr.remit_bank_acct_use_id = bank_acct.remit_bank_acct_use_id(+)
     AND cr.receipt_method_id = bank_acct.receipt_method_id(+)
     AND cr.receipt_method_id = rm.receipt_method_id(+)
     AND apsa.gl_date BETWEEN TO_DATE(:p_from_date, ''YYYY/MM/DD HH24:MI:SS'') AND TO_DATE (:p_to_date, ''YYYY/MM/DD HH24:MI:SS'')
     AND ABS(apsa.amount_due_original - apsa.amount_due_remaining) < ABS(apsa.amount_due_original)
     AND apsa.amount_due_remaining <> 0
     AND NVL(apsa.amount_applied,0) <> 0 '
            -- commented by naresh dasari INC0168588
            || l_receipt_where1
            || l_receipt_where3
            ||                    --Added date condition as part of CCR0006749
               ' UNION ALL
     SELECT o.name org_name
     ,bank_acct.gl_cash_account
	 ,TRUNC(cr.reversal_date) trx_date
     ,TO_CHAR(cr.reversal_date, ''DD-MON-RRRR'') trx_date_disp    
     ,cr.amount * -1 amount     
     --START Changes as per CCR0007884
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y''
           THEN NVL(xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => cr.cash_receipt_id, pn_customer_trx_id => app_cr.customer_trx_id)
                   ,rm.attribute2 || DECODE(rm.attribute1, NULL, NULL, '' ''||rm.attribute1))
           ELSE rm.attribute2 || DECODE(rm.attribute1, NULL, NULL, '' ''||rm.attribute1)
       END receipt_method     
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y'' THEN xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => cr.cash_receipt_id, pn_customer_trx_id => app_cr.customer_trx_id)
           ELSE DECODE(rm.attribute2, ''CA'', ''CA'',''PP'',''PP'',''GC'',''GC'',''RM'',''RM'',''RC'',''RC'',''COD'',''COD'',cr.attribute14) 
	   END payment_tender_type
	 --END Changes as per CCR0007884
     FROM apps.ar_cash_receipts_all cr
     ,apps.oe_order_headers_all oeh
     ,apps.ar_receipt_methods rm
     ,(SELECT o.name, o.organization_id FROM apps.hr_all_organization_units o WHERE o.type = ''ECOMM'' AND (o.organization_id = :p_org_id OR NVL (o.attribute1, -999) = :p_org_id)) o
     ,apps.ra_customers c
     ,(SELECT app.cash_receipt_id, rct.trx_number, oeh.order_number, oeh.cust_po_number, oeh.orig_sys_document_ref
             ,rct.customer_trx_id --Added for change 8.1
             ,oos.name order_source --Added for change 8.1
         FROM apps.ar_receivable_applications_all app, apps.ra_customer_trx_all rct, apps.oe_order_headers_all oeh
             ,apps.oe_order_sources oos --Added for change 8.1
        WHERE app.applied_customer_trx_id = rct.customer_trx_id
          AND DECODE (rct.interface_header_context, ''ORDER ENTRY'', rct.interface_header_attribute1, '''') = oeh.order_number(+)
          AND rct.org_id = oeh.org_id(+)
          AND app.display = ''Y''
          AND oeh.order_source_id = oos.order_source_id(+) --Added for change 8.1
          ) app_cr
     ,(SELECT rm.remit_bank_acct_use_id, rm.receipt_method_id, gcc.concatenated_segments gl_cash_account
         FROM apps.ar_receipt_method_accounts_all rm, apps.gl_code_combinations_kfv gcc
        WHERE rm.cash_ccid = gcc.code_combination_id) bank_acct
    WHERE cr.org_id = o.organization_id
     AND oeh.header_id(+) = cr.attribute15
     AND cr.pay_from_customer = c.customer_id(+) -- Added to fetch UnIdentified Receipts
     AND cr.currency_code = NVL(:p_currency_code, cr.currency_code)
     AND cr.cash_receipt_id = app_cr.cash_receipt_id(+)
     AND cr.remit_bank_acct_use_id = bank_acct.remit_bank_acct_use_id(+)
     AND cr.receipt_method_id = bank_acct.receipt_method_id(+)
     AND cr.receipt_method_id = rm.receipt_method_id(+)
     AND UPPER(cr.status) LIKE ''%REV%''
     AND cr.reversal_date BETWEEN TO_DATE(:p_from_date, ''YYYY/MM/DD HH24:MI:SS'') AND TO_DATE(:p_to_date, ''YYYY/MM/DD HH24:MI:SS'') '
            || l_receipt_where1
            || l_receipt_where3
            ||                    --Added date condition as part of CCR0006749
               ' UNION ALL
     SELECT o.name org_name
     ,gcc.concatenated_segments gl_cash_account     
	 ,TRUNC(adj.gl_date) trx_date
     ,TO_CHAR(adj.gl_date, ''DD-MON-RRRR'') trx_date_disp
     ,(adj.amount * -1) amount
     --START Changes as per CCR0007884
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y''
           THEN NVL(xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => NULL, pn_customer_trx_id => t.customer_trx_id)
                    ,art.attribute2|| DECODE(art.attribute3, NULL, NULL,'' ''||art.attribute3))
           ELSE art.attribute2|| DECODE(art.attribute3, NULL, NULL,'' ''||art.attribute3)
       END receipt_method     
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y'' THEN xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => NULL, pn_customer_trx_id => t.customer_trx_id)
           ELSE DECODE(art.attribute2, ''CA'', ''CA'',''PP'',''PP'',''GC'',''GC'',''RM'',''RM'',''RC'',''RC'',''COD'',''COD'',NVL((SELECT MAX(payment_tender_type) FROM apps.xxdoec_order_payment_details 
     WHERE header_id = oeh.header_id and payment_type = art.attribute2 ),adj.attribute1)) 
	   END payment_tender_type
     --END Changes as per CCR0007884
     FROM apps.ar_adjustments_all adj
     ,(SELECT o.name, o.organization_id FROM apps.hr_all_organization_units o WHERE o.type = ''ECOMM'' AND (o.organization_id = :p_org_id OR NVL (o.attribute1, -999) = :p_org_id)) o
     ,apps.ra_customer_trx_all t
     ,apps.ra_customers c
     ,apps.ar_receivables_trx_all art
     ,apps.oe_order_headers_all oeh
     ,apps.gl_code_combinations_kfv gcc
     ,apps.ar_receipt_methods rm --Added for change 8.1
     ,apps.oe_order_sources oos --Added for change 8.1
     WHERE adj.org_id = o.organization_id
     AND adj.customer_trx_id = t.customer_trx_id
     AND t.bill_to_customer_id = c.customer_id
     AND DECODE(t.interface_header_context, ''ORDER ENTRY'', t.interface_header_attribute1, '''') = oeh.order_number(+)
     AND t.org_id = oeh.org_id(+)
     AND oeh.order_source_id = oos.order_source_id(+)
     AND adj.receivables_trx_id = art.receivables_trx_id
     AND adj.org_id = art.org_id
     --AND art.code_combination_id = gcc.code_combination_id --commented by Venkatesh R(DFCT0010410)
     AND adj.code_combination_id = gcc.code_combination_id-- --added by Venkatesh R(DFCT0010410)
     AND adj.gl_date BETWEEN TO_DATE (:p_from_date, ''YYYY/MM/DD HH24:MI:SS'') AND TO_DATE (:p_to_date, ''YYYY/MM/DD HH24:MI:SS'')
     AND (UPPER(art.name) LIKE ''%REFUND% ADJ%'' OR UPPER(art.name) LIKE ''%REJECT% ADJ%'')
     AND t.invoice_currency_code = NVL(:p_currency_code, t.invoice_currency_code)
     AND art.attribute4 = rm.receipt_method_id(+) --Added for change 8.1
     AND adj.status=''A'' '
            -- added by Sarita
            || l_receipt_where2
            || l_receipt_where4
            ||                    --Added date condition as part of CCR0006749
               ' UNION ALL
     SELECT o.name org_name
     ,gcc.concatenated_segments gl_cash_account    
	 ,TRUNC(app.gl_date) trx_date
     ,TO_CHAR(app.gl_date, ''DD-MON-RRRR'') trx_date_disp     
     ,(app.amount_applied * -1) amount  
	 --START Changes as per CCR0007884
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y''
           THEN NVL(xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => cr.cash_receipt_id, pn_customer_trx_id => NULL)
                   ,rm.attribute2 || DECODE(rm.attribute1, NULL, NULL, '' ''||rm.attribute1))
           ELSE rm.attribute2 || DECODE(rm.attribute1, NULL, NULL, '' ''||rm.attribute1)
       END receipt_method
     ,CASE WHEN NVL(rm.attribute6, ''N'') = ''Y'' THEN xxdoar014_rep_pkg.get_receipt_method(pn_cash_receipt_id => cr.cash_receipt_id, pn_customer_trx_id => NULL)
           ELSE DECODE(rm.attribute2, ''CA'', ''CA'',''PP'',''PP'',''GC'',''GC'',''RM'',''RM'',''RC'',''RC'',''COD'',''COD'',cr.attribute14) 
	   END payment_tender_type
     --END Changes as per CCR0007884
     FROM apps.ar_receivable_applications_all app
     ,apps.ar_cash_receipts_all cr
     ,apps.ar_receivables_trx_all art
     ,apps.gl_code_combinations_kfv gcc
     ,apps.ar_receipt_methods rm
     ,(SELECT o.name, o.organization_id FROM apps.hr_all_organization_units o WHERE o.TYPE = ''ECOMM'' AND (o.organization_id = :p_org_id OR NVL (o.attribute1, -999) = :p_org_id)) o
     ,apps.ra_customers c
     ,(SELECT rm.remit_bank_acct_use_id, rm.receipt_method_id, gcc.concatenated_segments gl_cash_account
         FROM apps.ar_receipt_method_accounts_all rm, apps.gl_code_combinations_kfv gcc
        WHERE rm.cash_ccid = gcc.code_combination_id) bank_acct
    WHERE app.display = ''Y''
     AND app.cash_receipt_id = cr.cash_receipt_id
     AND app.receivables_trx_id = art.receivables_trx_id
     AND app.status = ''ACTIVITY'' --??
     AND app.code_combination_id = gcc.code_combination_id
     AND cr.receipt_method_id = rm.receipt_method_id(+)
     AND cr.org_id = o.organization_id
     AND cr.pay_from_customer = c.customer_id
     AND cr.remit_bank_acct_use_id = bank_acct.remit_bank_acct_use_id(+)
     AND cr.receipt_method_id = bank_acct.receipt_method_id(+)
     AND app.gl_date BETWEEN TO_DATE(:p_from_date, ''YYYY/MM/DD HH24:MI:SS'') AND TO_DATE(:p_to_date, ''YYYY/MM/DD HH24:MI:SS'')
     AND cr.currency_code = NVL(:p_currency_code, cr.currency_code) '
            || l_receipt_where2
            || l_receipt_where3
            ||                    --Added date condition as part of CCR0006749
               ' ORDER BY org_name,gl_cash_account, trx_date, receipt_method )
	GROUP BY org_name,
	  gl_cash_account,
	  trx_date_disp,
	  receipt_method,
	  payment_tender_type
	ORDER BY org_name,   --Added Order By as per CCR0007884
	  trx_date_disp,
	  receipt_method  ';
        apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, p_sql_stmt);
        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in before_report -' || SQLERRM);
    END before_report;

    FUNCTION directory_path                --Added by Madhav D for ENHC0013063
        RETURN VARCHAR2
    IS
    BEGIN
        IF p_file_path IS NOT NULL
        THEN
            BEGIN
                SELECT directory_path
                  INTO p_path
                  FROM dba_directories
                 WHERE directory_name = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.Fnd_File.PUT_LINE (
                        apps.Fnd_File.LOG,
                           'Unable to get the file path for directory - '
                        || p_file_path);
            END;
        END IF;

        RETURN p_path;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in directory_path -' || SQLERRM);
    END directory_path;

    FUNCTION file_name                     --Added by Madhav D for ENHC0013063
        RETURN VARCHAR2
    IS
    BEGIN
        IF p_path IS NOT NULL
        THEN
            P_FILE_NAME   :=
                'ecom' || P_ORG_ID || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        END IF;

        RETURN P_FILE_NAME;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in file_name -' || SQLERRM);
    END file_name;

    FUNCTION after_report                  --Added by Madhav D for ENHC0013063
        RETURN BOOLEAN
    IS
        l_req_id   NUMBER;
    BEGIN
        --RETURN FALSE;
        apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'inside after_report');

        IF P_FILE_PATH IS NOT NULL
        THEN
            l_req_id   :=
                FND_REQUEST.SUBMIT_REQUEST (
                    application   => 'XDO',
                    program       => 'XDOBURSTREP',
                    description   =>
                           'Bursting - Placing '
                        || P_FILE_NAME
                        || ' under '
                        || P_PATH,
                    start_time    => SYSDATE,
                    sub_request   => FALSE,
                    argument1     => 'Y',
                    argument2     => APPS.FND_GLOBAL.CONC_REQUEST_ID,
                    argument3     => 'Y');

            IF NVL (l_req_id, 0) = 0
            THEN
                apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'Bursting Failed');
            END IF;
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in after_report -' || SQLERRM);
    END after_report;

    --START Added function to Sync Detail Report for change 1.1
    --Return the Receipt Method from Order line attribute6 if exists else return NULL
    FUNCTION get_receipt_method (pn_cash_receipt_id   IN NUMBER,
                                 pn_customer_trx_id   IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_receipt_method   VARCHAR2 (120) := NULL;

        --Cursor to get receipt method from order line DFF attribute6
        --If CASH_RECEIPT_ID and CUSTOMER_TRX_ID are passed
        CURSOR rcpt_cur IS
            SELECT DISTINCT
                   NVL (pm.receipt_method, oola.attribute6) receipt_method
              FROM ar.ar_receivable_applications_all ara,
                   ar.ra_customer_trx_all rct,
                   ar.ra_customer_trx_lines_all rctl,
                   ont.oe_order_lines_all oola,
                   (SELECT UPPER (ffvl.attribute1) third_party_payment_method, ffvl.attribute2 receipt_method, ffvl.*
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     ffvs.flex_value_set_name =
                               'XXD_AR_PAYMENT_METHOD_MAP'
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND ffvl.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                    SYSDATE)
                                           AND NVL (ffvl.end_date_active,
                                                    SYSDATE + 1)) pm
             WHERE     1 = 1
                   AND ara.cash_receipt_id = pn_cash_receipt_id     --13628549
                   AND ara.display = 'Y'
                   AND ara.applied_customer_trx_id = rct.customer_trx_id
                   AND rct.customer_trx_id = pn_customer_trx_id     --15679604
                   AND rct.customer_trx_id = rctl.customer_trx_id
                   AND rctl.interface_line_context = 'ORDER ENTRY'
                   AND TO_NUMBER (rctl.interface_line_attribute6) =
                       oola.line_id
                   AND rctl.line_type = 'LINE'
                   AND oola.attribute6 IS NOT NULL
                   AND oola.attribute6 = pm.third_party_payment_method(+);

        --Cursor to get receipt method from order line DFF attribute6
        --If only CASH_RECEIPT_ID is passed
        CURSOR rcpt_cur_1 IS
            SELECT DISTINCT
                   NVL (pm.receipt_method, oola.attribute6) receipt_method
              FROM ar.ar_receivable_applications_all ara,
                   ar.ra_customer_trx_all rct,
                   ar.ra_customer_trx_lines_all rctl,
                   ont.oe_order_lines_all oola,
                   (SELECT UPPER (ffvl.attribute1) third_party_payment_method, ffvl.attribute2 receipt_method, ffvl.*
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     ffvs.flex_value_set_name =
                               'XXD_AR_PAYMENT_METHOD_MAP'
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND ffvl.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                    SYSDATE)
                                           AND NVL (ffvl.end_date_active,
                                                    SYSDATE + 1)) pm
             WHERE     1 = 1
                   AND ara.cash_receipt_id = pn_cash_receipt_id     --13628549
                   AND ara.display = 'Y'
                   AND ara.applied_customer_trx_id = rct.customer_trx_id
                   AND rct.customer_trx_id = rctl.customer_trx_id
                   AND rctl.interface_line_context = 'ORDER ENTRY'
                   AND rctl.line_type = 'LINE'
                   AND TO_NUMBER (rctl.interface_line_attribute6) =
                       oola.line_id
                   AND oola.attribute6 IS NOT NULL
                   AND oola.attribute6 = pm.third_party_payment_method(+);

        --Cursor to get receipt method from order line DFF attribute6
        --If only CUSTOMER_TRX_ID is passed
        CURSOR rcpt_cur_2 IS
            SELECT DISTINCT
                   NVL (pm.receipt_method, oola.attribute6) receipt_method
              FROM ar.ra_customer_trx_all rct,
                   ar.ra_customer_trx_lines_all rctl,
                   ont.oe_order_lines_all oola,
                   (SELECT UPPER (ffvl.attribute1) third_party_payment_method, ffvl.attribute2 receipt_method, ffvl.*
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     ffvs.flex_value_set_name =
                               'XXD_AR_PAYMENT_METHOD_MAP'
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND ffvl.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                    SYSDATE)
                                           AND NVL (ffvl.end_date_active,
                                                    SYSDATE + 1)) pm
             WHERE     1 = 1
                   AND rct.customer_trx_id = pn_customer_trx_id
                   AND rct.customer_trx_id = rctl.customer_trx_id
                   AND rctl.interface_line_context = 'ORDER ENTRY'
                   AND rctl.line_type = 'LINE'
                   AND TO_NUMBER (rctl.interface_line_attribute6) =
                       oola.line_id
                   AND oola.attribute6 IS NOT NULL
                   AND oola.attribute6 = pm.third_party_payment_method(+);
    BEGIN
        --If both CASH_RECEIPT_ID and CUSTOMER_TRX_ID are passed
        IF (pn_cash_receipt_id IS NOT NULL AND pn_customer_trx_id IS NOT NULL)
        THEN
            FOR rcpt_rec IN rcpt_cur
            LOOP
                lv_receipt_method   :=
                    SUBSTR (
                        lv_receipt_method || ',' || rcpt_rec.receipt_method,
                        1,
                        120);
            END LOOP;
        --If CASH_RECEIPT_ID only is passed
        ELSIF (pn_cash_receipt_id IS NOT NULL AND pn_customer_trx_id IS NULL)
        THEN
            FOR rcpt_rec_1 IN rcpt_cur_1
            LOOP
                lv_receipt_method   :=
                    SUBSTR (
                        lv_receipt_method || ',' || rcpt_rec_1.receipt_method,
                        1,
                        120);
            END LOOP;
        --If CUSTOMER_TRX_ID only is passed
        ELSIF (pn_cash_receipt_id IS NULL AND pn_customer_trx_id IS NOT NULL)
        THEN
            FOR rcpt_rec_2 IN rcpt_cur_2
            LOOP
                lv_receipt_method   :=
                    SUBSTR (
                        lv_receipt_method || ',' || rcpt_rec_2.receipt_method,
                        1,
                        120);
            END LOOP;
        END IF;

        --If lv_receipt_method has a value then remove the COMMA from it which is position 1.
        IF lv_receipt_method IS NOT NULL
        THEN
            lv_receipt_method   := SUBSTR (lv_receipt_method, 2);
        END IF;

        --Return Receipt Method
        RETURN lv_receipt_method;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_receipt_method   := NULL;
            --Return Receipt Method as NULL if any issue
            RETURN lv_receipt_method;
    END get_receipt_method;
--END Added function to Sync Detail Report for change 1.1

END XXDOAR014_REP_SUM_PKG;
/
