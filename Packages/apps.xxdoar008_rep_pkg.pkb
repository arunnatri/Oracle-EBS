--
-- XXDOAR008_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoar008_rep_pkg
AS
    /******************************************************************************
       NAME: XXDOAR008_REP_PKG
       PURPOSE:Adjustment Register Report - Deckers

       REVISIONS:
       Ver        Date        Author                   Description
       ---------  ----------  ---------------         ------------------------------------
       1.0        11/17/2010     Shibu                 1. Created this package for AR XXDOAR008 Report

       2.0        30/12/2014     BT TECHNOLOGY TEAM    Retrofit for BT project
    ******************************************************************************/
    co_seg_where          VARCHAR2 (500);
    accounting_method     VARCHAR2 (30);
    l_accounting_method   VARCHAR2 (30);

    --
    -- Main AR Adjustments RX Report function
    --
    PROCEDURE ar_adj_rep (p_reporting_level      IN            NUMBER,
                          p_reporting_entity     IN            NUMBER,
                          p_sob_id               IN            NUMBER,
                          p_coa_id               IN            NUMBER,
                          p_co_seg_low           IN            VARCHAR2,
                          p_co_seg_high          IN            VARCHAR2,
                          p_gl_date_low          IN            DATE,
                          p_gl_date_high         IN            DATE,
                          p_currency_code_low    IN            VARCHAR2,
                          p_currency_code_high   IN            VARCHAR2,
                          p_trx_date_low         IN            DATE,
                          p_trx_date_high        IN            DATE,
                          p_due_date_low         IN            DATE,
                          p_due_date_high        IN            DATE,
                          p_invoice_type_low     IN            VARCHAR2,
                          p_invoice_type_high    IN            VARCHAR2,
                          p_adj_type_low         IN            VARCHAR2,
                          p_adj_type_high        IN            VARCHAR2,
                          p_doc_seq_name         IN            VARCHAR2,
                          p_doc_seq_low          IN            NUMBER,
                          p_doc_seq_high         IN            NUMBER,
                          retcode                   OUT NOCOPY NUMBER,
                          errbuf                    OUT NOCOPY VARCHAR2)
    IS
        currency_code_where          VARCHAR2 (500);
        invoice_type_where           VARCHAR2 (500);
        due_date_where               VARCHAR2 (500);
        trx_date_where               VARCHAR2 (500);
        adj_type_where               VARCHAR2 (500);
        gl_date_where                VARCHAR2 (500);
        rec_balancing_where          VARCHAR2 (500);
        adj_acct_where               VARCHAR2 (800);
        seq_name_where               VARCHAR2 (100);
        seq_number_where             VARCHAR2 (100);
        oper                         VARCHAR2 (10);
        op1                          VARCHAR2 (25);
        op2                          VARCHAR2 (25);
        sortby_decode                VARCHAR2 (300);
        d_or_i_decode                VARCHAR2 (200);
        adj_class_decode             VARCHAR2 (200);
        postable_decode              VARCHAR2 (100);
        balancing_order_by           VARCHAR2 (100);
        show_bill_where              VARCHAR2 (100);
        show_bill_from               VARCHAR2 (100);
        bill_flag                    VARCHAR2 (1);
        l_cust_org_where             VARCHAR2 (500);
        l_pay_org_where              VARCHAR2 (500);
        l_adj_org_where              VARCHAR2 (500);
        l_ci_org_where               VARCHAR2 (500);
        l_trx_org_where              VARCHAR2 (500);
        l_sysparam_org_where         VARCHAR2 (500);
        acct_stmt                    VARCHAR2 (600);
        l_bill_flag                  VARCHAR2 (5000);
        l_from_table                 VARCHAR2 (5000);
        l_select                     VARCHAR2 (5000);
        l_from                       VARCHAR2 (5000);
        l_where_clause               VARCHAR2 (5000);
        l_order_by_clause            VARCHAR2 (5000);
        l_books_id                   NUMBER;
        l_chart_of_accounts_id       NUMBER;
        l_organization_name          VARCHAR2 (50);
        l_currency_code              VARCHAR2 (20);
        l_functional_currency_code   VARCHAR2 (20);
        l_reporting_level            NUMBER;
        l_reporting_entity_id        NUMBER;
        l_sob_id                     NUMBER;
        lc_sob_where                 VARCHAR2 (200); -- Added by BT Tech Team on 03-Feb-2015
        l_coa_id                     NUMBER;
        l_co_seg_low                 VARCHAR2 (100);
        l_co_seg_high                VARCHAR2 (100);
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG, 'Begin');
        -- Asssign parameters to global variable
        -- These values will be used within the before_report trigger
        l_reporting_level           := p_reporting_level;
        l_reporting_entity_id       := p_reporting_entity;
        var.p_reporting_level       := p_reporting_level;
        var.p_reporting_entity_id   := p_reporting_entity;
        var.p_sob_id                := p_sob_id;
        var.p_coa_id                := p_coa_id;
        var.p_gl_date_low           := p_gl_date_low;
        var.p_gl_date_high          := p_gl_date_high;
        var.p_trx_date_low          := p_trx_date_low;
        var.p_trx_date_high         := p_trx_date_high;
        var.p_due_date_low          := p_due_date_low;
        var.p_due_date_high         := p_due_date_high;
        var.p_invoice_type_low      := p_invoice_type_low;
        var.p_invoice_type_high     := p_invoice_type_high;
        var.p_adj_type_low          := p_adj_type_low;
        var.p_adj_type_high         := p_adj_type_high;
        var.p_currency_code_low     := p_currency_code_low;
        var.p_currency_code_high    := p_currency_code_high;
        var.p_co_seg_low            := p_co_seg_low;
        var.p_co_seg_high           := p_co_seg_high;
        var.p_doc_seq_name          := p_doc_seq_name;
        var.p_doc_seq_low           := p_doc_seq_low;
        var.p_doc_seq_high          := p_doc_seq_high;

        --

        /* Bug 5244313 Setting the SOB based on the Reporting context */
        IF p_reporting_level = 1000
        THEN
            var.books_id   := p_reporting_entity;
            lc_sob_where   :=
                ' and adj.set_of_books_id = ' || p_reporting_entity; -- Added by BT Tech Team on 03-Feb-2015
            apps.mo_global.init ('AR');
            apps.mo_global.set_policy_context ('M', NULL);
        ELSIF p_reporting_level = 3000
        THEN
            SELECT set_of_books_id
              INTO var.books_id
              FROM apps.ar_system_parameters_all
             WHERE org_id = p_reporting_entity;

            apps.mo_global.init ('AR');
            apps.mo_global.set_policy_context ('S', p_reporting_entity);
        END IF;

        BEGIN
            SELECT chart_of_accounts_id, currency_code, NAME
              INTO var.chart_of_accounts_id, var.functional_currency_code, var.organization_name
              FROM apps.gl_sets_of_books
             WHERE set_of_books_id = var.books_id;

            l_chart_of_accounts_id   := var.chart_of_accounts_id;
        END;

        apps.xla_mo_reporting_api.initialize (var.p_reporting_level,
                                              var.p_reporting_entity_id,
                                              'AUTO');
        --        L_CUST_ORG_WHERE   := apps.XLA_MO_REPORTING_API.Get_Predicate('CUST',NULL);
        --        L_PAY_ORG_WHERE    := apps.XLA_MO_REPORTING_API.Get_Predicate('PAY',NULL);
        --        L_ADJ_ORG_WHERE    := apps.XLA_MO_REPORTING_API.Get_Predicate('ADJ',NULL);
        --        L_TRX_ORG_WHERE    := apps.XLA_MO_REPORTING_API.Get_Predicate('TRX',NULL);

        --Bug fix 5595083 starts
        l_sysparam_org_where        :=
            apps.xla_mo_reporting_api.get_predicate ('SYSPARAM', NULL);
        acct_stmt                   :=
               'select distinct ACCOUNTING_METHOD FROM  apps.ar_system_parameters_all SYSPARAM  where ACCOUNTING_METHOD is not null '
            || l_sysparam_org_where;

        IF var.p_reporting_level = 3000
        THEN
            IF var.p_reporting_entity_id IS NOT NULL
            THEN
                EXECUTE IMMEDIATE acct_stmt
                    INTO accounting_method
                    USING var.p_reporting_entity_id, var.p_reporting_entity_id;

                l_adj_org_where   :=
                       'AND NVL(ADJ.ORG_ID,  '
                    || l_reporting_entity_id
                    || ' ) =  '
                    || l_reporting_entity_id
                    || '  ';
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'OU:- ' || acct_stmt);
            END IF;
        ELSE
            EXECUTE IMMEDIATE acct_stmt
                INTO accounting_method;
        END IF;

        l_accounting_method         := '''' || accounting_method || '''';

        --apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Accrual:- '|| acct_stmt);
        --
        --CURRENCY_CODE where clause
        --
        IF     var.p_currency_code_low IS NULL
           AND var.p_currency_code_high IS NULL
        THEN
            currency_code_where   := NULL;
        ELSIF var.p_currency_code_low IS NULL
        THEN
            currency_code_where   :=
                   ' AND TRX.INVOICE_CURRENCY_CODE <= '
                || ''''
                || p_currency_code_high
                || '''';
        ELSIF var.p_currency_code_high IS NULL
        THEN
            currency_code_where   :=
                   ' AND TRX.INVOICE_CURRENCY_CODE >= '
                || ''''
                || p_currency_code_low
                || '''';
        ELSE
            currency_code_where   :=
                   ' AND TRX.INVOICE_CURRENCY_CODE BETWEEN '
                || ' '
                || ''''
                || p_currency_code_low
                || ''''
                || ' '
                || 'AND'
                || ' '
                || ''''
                || p_currency_code_high
                || '''';
        END IF;

        --
        -- INVOICE_TYPE where clause
        --
        IF var.p_invoice_type_low IS NULL AND var.p_invoice_type_high IS NULL
        THEN
            invoice_type_where   := NULL;
        ELSIF var.p_invoice_type_low IS NULL
        THEN
            invoice_type_where   :=
                   ' AND apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''NAME'',trx.org_id) <= '
                || ''''
                || p_invoice_type_high
                || '''';
        ELSIF var.p_invoice_type_high IS NULL
        THEN
            invoice_type_where   :=
                   ' AND apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''NAME'', trx.org_id) >= '
                || ''''
                || p_invoice_type_high
                || '''';
        ELSE
            invoice_type_where   :=
                   ' AND  apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''NAME'',trx.org_id) '
                || ' BETWEEN '
                || ' '
                || ''''
                || p_invoice_type_high
                || ''''
                || ' '
                || 'AND'
                || ' '
                || ''''
                || p_invoice_type_high
                || '''';
        END IF;

        --
        -- TRX date where clause--
        --
        IF var.p_trx_date_low IS NULL AND var.p_trx_date_high IS NULL
        THEN
            trx_date_where   := NULL;
        ELSIF var.p_trx_date_low IS NULL
        THEN
            trx_date_where   :=
                ' AND TRX.TRX_DATE <= ' || '''' || p_trx_date_high || '''';
        ELSIF var.p_trx_date_high IS NULL
        THEN
            trx_date_where   :=
                ' AND TRX.TRX_DATE >= ' || '''' || p_trx_date_low || '''';
        ELSE
            trx_date_where   :=
                   ' AND TRX.TRX_DATE BETWEEN '
                || ' '
                || ''''
                || p_trx_date_low
                || ''''
                || ' '
                || 'AND'
                || ' '
                || ''''
                || p_trx_date_high
                || '''';
        END IF;

        --
        -- DUE_DATE where clause
        --
        IF var.p_due_date_low IS NULL AND var.p_due_date_high IS NULL
        THEN
            due_date_where   := NULL;
        ELSIF var.p_due_date_low IS NULL
        THEN
            due_date_where   :=
                   ' AND PAY.DUE_DATE <='
                || ' '
                || ''''
                || p_due_date_high
                || '''';
        ELSIF var.p_due_date_high IS NULL
        THEN
            due_date_where   :=
                   ' AND PAY.DUE_DATE >='
                || ' '
                || ''''
                || p_due_date_low
                || '''';
        ELSE
            due_date_where   :=
                   ' AND PAY.DUE_DATE BETWEEN '
                || ' '
                || ''''
                || p_due_date_low
                || ''''
                || ' '
                || 'AND'
                || ' '
                || ''''
                || p_due_date_high
                || '''';
        END IF;

        IF p_co_seg_low IS NULL AND p_co_seg_high IS NULL
        THEN
            oper   := NULL;
        ELSIF var.p_co_seg_low IS NULL
        THEN
            oper   := '<=';
            op1    := var.p_co_seg_high;
            op2    := NULL;
        ELSIF var.p_co_seg_high IS NULL
        THEN
            oper   := '>=';
            op1    := var.p_co_seg_low;
            op2    := NULL;
        ELSE
            oper   := 'BETWEEN';
            op1    := var.p_co_seg_low;
            op2    := var.p_co_seg_high;
        END IF;

        IF oper IS NULL
        THEN
            co_seg_where   := NULL;
        ELSE
            co_seg_where   :=
                   ' AND '
                || apps.fa_rx_flex_pkg.flex_sql (
                       p_application_id   => 101,
                       p_id_flex_code     => 'GL#',
                       p_id_flex_num      => l_chart_of_accounts_id,
                       p_table_alias      => 'glc',
                       p_mode             => 'WHERE',
                       p_qualifier        => 'GL_BALANCING',
                       p_function         => oper,
                       p_operand1         => op1,
                       p_operand2         => op2);
        END IF;

        --
        -- ADJ_TYPE_WHERE clause
        --
        IF p_adj_type_low IS NULL AND p_adj_type_high IS NULL
        THEN
            adj_type_where   := NULL;
        ELSIF p_adj_type_low IS NULL
        THEN
            adj_type_where   :=
                ' AND ADJ.TYPE <= ' || '''' || p_adj_type_high || '''';
        ELSIF p_adj_type_high IS NULL
        THEN
            adj_type_where   :=
                ' AND ADJ.TYPE >= ' || '''' || p_adj_type_low || '''';
        ELSE
            adj_type_where   :=
                   ' AND ADJ.TYPE BETWEEN '
                || ' '
                || ''''
                || p_adj_type_low
                || ''''
                || ' '
                || ' AND '
                || ' '
                || ''''
                || p_adj_type_high
                || '''';
        END IF;

        --
        -- GL_DATE_WHERE clause
        --
        IF p_gl_date_low IS NULL AND p_gl_date_high IS NULL
        THEN
            gl_date_where   := NULL;
        ELSIF p_gl_date_low IS NULL
        THEN
            gl_date_where   :=
                   ' AND ADJ.GL_DATE <= '
                || ' '
                || ''''
                || p_gl_date_high
                || '''';
        ELSIF p_gl_date_high IS NULL
        THEN
            gl_date_where   :=
                   ' AND ADJ.GL_DATE >= '
                || ' '
                || ''''
                || p_gl_date_high
                || '''';
        ELSE
            gl_date_where   :=
                   ' AND ADJ.GL_DATE BETWEEN'
                || ' '
                || ''''
                || p_gl_date_low
                || ''''
                || ' '
                || 'AND'
                || ' '
                || ''''
                || p_gl_date_high
                || '''';
        END IF;

        --
        -- Doc Name Where
        --
        IF p_doc_seq_name IS NOT NULL
        THEN
            seq_name_where   :=
                   ' AND adj.doc_sequence_id = '
                || ''''
                || p_doc_seq_name
                || '''';
        ELSE
            seq_name_where   := NULL;
        END IF;

        --
        -- Doc Number Where
        --
        IF p_doc_seq_low IS NOT NULL AND p_doc_seq_high IS NOT NULL
        THEN
            seq_number_where   :=
                   ' AND adj.doc_sequence_value BETWEEN '
                || ' '
                || ''''
                || p_doc_seq_low
                || ''''
                || ' '
                || 'AND'
                || ' '
                || ''''
                || p_doc_seq_high
                || '''';
        ELSIF p_doc_seq_low IS NOT NULL
        THEN
            seq_number_where   :=
                   ' AND adj.doc_sequence_value >= '
                || ''''
                || p_doc_seq_low
                || '''';
        ELSIF var.p_doc_seq_high IS NOT NULL
        THEN
            seq_number_where   :=
                   ' AND adj.doc_sequence_value <= '
                || ''''
                || p_doc_seq_high
                || '''';
        ELSE
            seq_number_where   := NULL;
        END IF;

        -- Bug 2099632
        -- SHOW_BILL_WHERE

        -- Bug 2209444 Changed fnd_profile to ar_setup procedure
        apps.ar_setup.get (NAME => 'AR_SHOW_BILLING_NUMBER', val => bill_flag);

        IF (bill_flag = 'Y')
        THEN
            show_bill_where   := 'AND pay.cons_inv_id = ci.cons_inv_id(+)';
            show_bill_from    := ', apps.ar_cons_inv_all ci ';
            l_ci_org_where    :=
                apps.xla_mo_reporting_api.get_predicate ('CI', NULL);
        ELSE
            show_bill_where   := NULL;
            show_bill_from    := NULL;
            l_ci_org_where    := NULL;
        END IF;

        --apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'BILL_FLAG:- '|| BILL_FLAG);
        --
        -- Define DECODE statements
        --
        /*bug5968198*/
        sortby_decode               :=
            'decode(upper(:p_order_by),''CUSTOMER'', decode(UPPER(party.party_type), ''ORGANIZATION'', org.organization_name,
                            ''PERSON'', per.person_name, party.party_name),''INVOICE NUMBER'', trx.trx_number,trx.trx_number)';
        d_or_i_decode               :=
            'decode(adj.adjustment_type,''C'',decode( apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''TYPE'',trx.org_id), ''GUAR'', ''I'', ''D''),'''')';
        --POSTABLE_DECODE  := 'decode(adj.postable, ''Y'', :c_Yes, :c_No)';
        adj_class_decode            :=
            'decode(adj.adjustment_type, ''C'', look.meaning,decode(apps.arpt_sql_func_util.get_rec_trx_type(adj.receivables_trx_id), ''FINCHRG'',''Finance'',''Adjustment''))';

        --
        --  Assign SELECT list
        --
        -->>SELECT_START<<--
        IF (bill_flag = 'Y')
        THEN
            l_bill_flag   :=
                'decode(ci.cons_billing_number, null, trx.trx_number, SUBSTRB(trx.trx_number||''/''||rtrim(ci.cons_billing_number),1,36))  TRX_NUMBER';
        ELSE
            l_bill_flag   := 'trx.trx_number     TRX_NUMBER';
        END IF;

        IF accounting_method = 'CASH'
        THEN
            l_from_table   := ',apps.gl_code_combinations glc ';
        ELSIF accounting_method = 'ACCRUAL' AND co_seg_where IS NOT NULL
        THEN
            --accounting_method = 'ACCRUAL'  THEN
            l_from_table   :=
                ',apps.gl_code_combinations glc , apps.ar_distributions dist_all';
        ELSIF accounting_method = 'ACCRUAL'
        THEN
            l_from_table   := ',apps.gl_code_combinations glc ';
        END IF;

        l_select                    :=
               'Select
                       decode(adj.postable, ''Y'',''Yes'',''N0'') POSTABLE_DECODE,
                       trx.trx_number     TRX_NUMBER,
                      ---trx.attribute5 brand,                      --commented by BT Technology Team on 30-12-2014,
                        --- cust.ATTRIBUTE1 brand,
                       cust.ATTRIBUTE1   BRAND,       --Added by BT Technology Team on 30-12-2014,
                       (select NAME from apps.hr_operating_units where ORGANIZATION_ID = trx.org_id) OU_NAME,
                        XXDO.XXDOAR_COMMON_PKG.get_payment_det(trx.primary_salesrep_id,trx.org_id,''SNUM'')  SALESREP_NUMBER,
                        XXDO.XXDOAR_COMMON_PKG.get_payment_det(trx.primary_salesrep_id,trx.org_id,''SNAME'') SALESREP_NAME,
                       trx.invoice_currency_code,
                       apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''NAME'',trx.org_id) ADJ_NAME,
                       decode(adj.adjustment_type,''C'',decode( apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''TYPE'',trx.org_id), ''GUAR'', ''I'', ''D''),'''')                    D_OR_I,
                       to_char(pay.due_date,''MM/DD/RRRR'' )     DUE_DATE,
                       to_char(adj.gl_date,''MM/DD/RRRR'' )      GL_DATE,
                       adj.adjustment_number            ADJ_NUMBER,
                       decode(adj.adjustment_type, ''C'', look.meaning,decode(apps.arpt_sql_func_util.get_rec_trx_type(adj.receivables_trx_id), ''FINCHRG'',''Finance'',''Adjustment''))        ADJ_CLASS,
                       adj.type                         ADJ_TYPE_CODE,
                       ladjtype.meaning                 ADJ_TYPE_MEANING,
                       substrb(decode(UPPER(party.party_type), ''ORGANIZATION'', org.organization_name, ''PERSON'',per.person_name, party.party_name) ,1,50)        CUSTOMER_NAME,
                       cust.account_number              CUSTOMER_NUMBER,
                       cust.cust_account_id             CUSTOMER_ID,
                       to_char(trx.trx_date,''MM/DD/RRRR'' )   TRX_DATE,
                       decode('
            || l_accounting_method
            || ',''ACCRUAL'',apps.arrx_adj.dist_details(adj.adjustment_id,'
            || l_chart_of_accounts_id
            || ','
            || l_reporting_entity_id
            || ' ,''ENTERED''),round(adj.amount,2)) ADJ_AMOUNT,
                       decode('
            || l_accounting_method
            || ',''ACCRUAL'',apps.arrx_adj.dist_details(adj.adjustment_id,'
            || l_chart_of_accounts_id
            || ','
            || l_reporting_entity_id
            || ',''ACCTD''),adj.acctd_amount) ACCTD_ADJ_AMOUNT,
                     --  decode('
            || l_accounting_method
            || ',''ACCRUAL'',apps.arrx_adj.dist_ccid(adj.adjustment_id,'
            || l_chart_of_accounts_id
            || ','
            || l_reporting_entity_id
            || ' ),glc.code_combination_id) ACCOUNT_CODE_COMBINATION_ID,
                       nvl(adj.doc_sequence_value,'''')     DOC_SEQUENCE_VALUE,
                       adj.COMMENTS COMMENTS,
                       adj.REASON_CODE REASON_CODE,
                       rt.NAME  ACTIVITY_NAME,
		      -- Start Changes by BT Technology Team on 30-12-2014
                      -- glc.SEGMENT1||''.''||glc.SEGMENT2||''.''||glc.SEGMENT3||''.''||glc.SEGMENT4 ACCOUNT_CODE,
		      glc.SEGMENT1||''.''||glc.SEGMENT2||''.''||glc.SEGMENT3||''.''||glc.SEGMENT4||''.''|| glc.SEGMENT5||''.''||glc.SEGMENT6||''.''||glc.SEGMENT7||''.''||glc.SEGMENT8  ACCOUNT_CODE,
      		      -- End Changes by BT Technology Team on 30-12-2014
                       apps.XXDOAR008_REP_PKG.get_trx_requestor(trx.CUSTOMER_TRX_ID,''REQ'') REQUESTOR
                       From
                       apps.hz_cust_accounts_all        cust,
                       apps.hz_parties        party,
                       apps.ar_lookups               ladjtype,
                       apps.ar_payment_schedules_all    pay,
                       apps.ra_customer_trx_all      trx,
                       apps.ar_adjustments_all       adj,
                       apps.ar_receivables_trx_all  rt,
                       apps.ar_lookups        look,
                       apps.hz_organization_profiles org,
                       apps.hz_person_profiles  per '
            || show_bill_from
            || ' '
            || l_from_table;
        l_where_clause              :=
               'trx.complete_flag = ''Y''
                and cust.cust_account_id = trx.bill_to_customer_id
                    and cust.party_id = party.party_id
               -- and trx.set_of_books_id = 1 --:set_of_books_id
                and trx.customer_trx_id =   pay.customer_trx_id
                and pay.payment_schedule_id = adj.payment_schedule_id
                and nvl(adj.status, ''A'') = ''A''
                and apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''TYPE'',trx.org_id)
                                    in (''INV'',''DEP'',''GUAR'',''CM'',''DM'',''CB'')
                and look.lookup_type = ''INV/CM''
                and look.lookup_code = apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''TYPE'',trx.org_id)
                and adj.receivables_trx_id = rt.receivables_trx_id
                AND adj.org_id = rt.org_id
                AND rt.receivables_trx_id <> -15
                and adj.adjustment_id > 0
                and adj.receivables_trx_id is not null
                                and adj.receivables_trx_id <> -15
                and adj.type = ladjtype.lookup_code
                and ladjtype.lookup_type = ''ADJUSTMENT_TYPE''
                and party.party_id = org.party_id(+)
                and party.party_id = per.party_id(+)
                and (trx.trx_date between NVL(org.effective_start_date, trx.trx_date)
                    and NVL(org.effective_end_date, trx.trx_date)
                  OR (trx.trx_date < (select min(org1.effective_start_date) from
                     apps.hz_organization_profiles org1 where org1.party_id = party.party_id)
                    AND trx.creation_date between NVL(org.effective_start_date,
                     trx.creation_date) and NVL(org.effective_end_date, trx.creation_date))
                  OR (trx.creation_date < (select min(org1.effective_start_date)
                     from apps.hz_organization_profiles org1 where org1.party_id = party.party_id)
                    AND org.effective_end_date is NULL))
                and (trx.trx_date between NVL(per.effective_start_date, trx.trx_date)
                    and NVL(per.effective_end_date, trx.trx_date)
                  OR (trx.trx_date < (select min(per1.effective_start_date) from
                     apps.hz_person_profiles per1 where per1.party_id = party.party_id)
                    AND trx.creation_date between NVL(per.effective_start_date,
                     trx.creation_date) and NVL(per.effective_end_date, trx.creation_date))
                  OR (trx.creation_date < (select min(per1.effective_start_date)
                     from apps.hz_person_profiles per1 where per1.party_id = party.party_id)
                    AND per.effective_end_date is NULL)) '
            || currency_code_where
            || ' '
            || invoice_type_where
            || ' '
            || due_date_where
            || ' '
            || trx_date_where
            || ' '
            || adj_type_where
            || ' '
            || gl_date_where
            || ' '
            || adj_acct_where
            || ' '
            || seq_name_where
            || ' '
            || seq_number_where
            || ' '
            || show_bill_where
            || ' '
            || lc_sob_where            -- Added by BT Tech Team on 03-Feb-2015
            || ' '                     -- Added by BT Tech Team on 03-Feb-2015
            || --                    L_CUST_ORG_WHERE  || ' ' ||
               --                    L_PAY_ORG_WHERE || ' ' ||
               l_adj_org_where
            || ' ';

        --                    L_TRX_ORG_WHERE;
        IF accounting_method = 'CASH'
        THEN
            l_where_clause   :=
                   l_where_clause
                || ' and adj.code_combination_id = glc.code_combination_id
                   and glc.chart_of_accounts_id = :p_coa_id '
                || co_seg_where;
        ELSIF accounting_method = 'ACCRUAL' AND co_seg_where IS NOT NULL
        THEN
            l_where_clause   :=
                   l_where_clause
                || 'and glc.code_combination_id = dist_all.code_combination_id
                                and glc.chart_of_accounts_id = :p_coa_id
                                and dist_all.source_id = adj.adjustment_id
                                and dist_all.source_table = ''ADJ''
                                and dist_all.source_type in ( ''REC'') '
                || ' '
                || co_seg_where;
        ELSIF accounting_method = 'ACCRUAL'
        THEN
            l_where_clause   :=
                   l_where_clause
                || ' and adj.code_combination_id = glc.code_combination_id
                     and glc.chart_of_accounts_id = :p_coa_id '
                || co_seg_where;
        END IF;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Where:- ' || l_where_clause);
        l_order_by_clause           :=
            ' apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''POST'',trx.org_id) ,
                     apps.arpt_sql_func_util.get_trx_type_details(trx.cust_trx_type_id,''NAME'',trx.org_id),
                    trx.trx_number,
                     pay.due_date,
                     adj.adjustment_number';
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Order:- ' || l_order_by_clause);
        p_sql_stmt                  :=
               l_select
            || ' '
            || 'Where'
            || ' '
            || l_where_clause
            || ' '
            || 'Order By'
            || ' '
            || l_order_by_clause;
        var.sql_stmt                := p_sql_stmt;
        errbuf                      := errbuf || ' + ' || p_sql_stmt;
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Query is' || CHR (10) || p_sql_stmt);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END ar_adj_rep;

    FUNCTION before_report
        RETURN BOOLEAN
    IS
        l_retcode         NUMBER;
        l_errbuf          VARCHAR2 (32000);
        l_gl_date_low     DATE;
        l_gl_date_high    DATE;
        l_trx_date_low    DATE;
        l_trx_date_high   DATE;
        l_due_date_low    DATE;
        l_due_date_high   DATE;
    BEGIN
        l_gl_date_low    := apps.fnd_date.canonical_to_date (p_gl_date_low);
        l_gl_date_high   := apps.fnd_date.canonical_to_date (p_gl_date_high);
        ar_adj_rep (p_reporting_level => p_reporting_level, p_reporting_entity => p_reporting_entity, p_sob_id => p_sob_id, p_coa_id => p_coa_id, p_co_seg_low => p_co_seg_low, p_co_seg_high => p_co_seg_high, p_gl_date_low => l_gl_date_low, p_gl_date_high => l_gl_date_high, p_currency_code_low => p_currency_code_low, p_currency_code_high => p_currency_code_high, p_trx_date_low => l_trx_date_low, p_trx_date_high => l_trx_date_high, p_due_date_low => l_due_date_low, p_due_date_high => l_due_date_high, p_invoice_type_low => p_invoice_type_low, p_invoice_type_high => p_invoice_type_high, p_adj_type_low => p_adj_type_low, p_adj_type_high => p_adj_type_high, p_doc_seq_name => p_doc_seq_name, p_doc_seq_low => p_doc_seq_low, p_doc_seq_high => p_doc_seq_high
                    , retcode => l_retcode, errbuf => l_errbuf);
        --ar_adj_rep (
        --            P_REPORTING_LEVEL,
        --            P_REPORTING_ENTITY,
        --            P_SOB_ID,
        --            P_COA_ID,
        --            P_CO_SEG_LOW,
        --            P_CO_SEG_HIGH,
        --            l_gl_date_low,
        --            l_gl_date_high,
        --            P_CURRENCY_CODE_LOW,
        --            P_CURRENCY_CODE_HIGH,
        --            P_TRX_DATE_LOW,
        --            P_TRX_DATE_HIGH,
        --            P_DUE_DATE_LOW,
        --            P_DUE_DATE_HIGH,
        --            P_INVOICE_TYPE_LOW,
        --            P_INVOICE_TYPE_HIGH,
        --            P_ADJ_TYPE_LOW,
        --            P_ADJ_TYPE_HIGH,
        --            P_DOC_SEQ_NAME,
        --            P_DOC_SEQ_LOW,
        --            P_DOC_SEQ_HIGH,
        --            l_retcode,
        --            l_errbuf);

        --P_SQL_STMT := var.sql_stmt;
        apps.fnd_file.put_line (apps.fnd_file.LOG, l_errbuf);
        RETURN TRUE;
    END;

    FUNCTION get_trx_requestor (p_trx_id NUMBER, p_col VARCHAR2)
        RETURN VARCHAR2
    IS
        l_return   VARCHAR2 (150);
    BEGIN
        SELECT attribute13
          INTO l_return
          FROM apps.ra_customer_trx_all
         WHERE customer_trx_id = p_trx_id AND LENGTH (attribute13) > 1;

        RETURN (l_return);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_trx_requestor;
END xxdoar008_rep_pkg;
/
