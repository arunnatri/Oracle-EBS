--
-- XXD_AR_BT_RECON_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:35 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_BT_RECON_RPT_PKG"
AS
    /*
    *********************************************************************************************
    **                                                                                          *
    **    Author          : Madhav Dhurjaty                                                     *
    **    Created         : 28-MAY-2018                                                         *
    **    Description     : This package is used to reconcile the BillTrust CashApp inbound data*
    **                      to the Oracle AR receipt batch and receipt information              *
    **                                                                                          *
    **History         :                                                                         *
    **------------------------------------------------------------------------------------------*
    **Date        Author                        Version Change Notes                            *
    **----------- --------- ------- ------------------------------------------------------------*
    **28-MAY-2018 Madhav Dhurjaty               1.0     Initial Version                         *
    *********************************************************************************************
    */
    PROCEDURE build_sql
    IS
        lv_region_where          VARCHAR2 (2000);
        lv_org_id_where          VARCHAR2 (2000);
        lv_dep_date_where1       VARCHAR2 (2000);
        lv_dep_date_where2       VARCHAR2 (2000);
        lv_cre_date_where1       VARCHAR2 (2000);
        lv_cre_date_where2       VARCHAR2 (2000);
        lv_batch_id_where        VARCHAR2 (2000);
        lv_batch_date_where1     VARCHAR2 (2000);
        lv_batch_date_where2     VARCHAR2 (2000);
        lv_batch_source_where    VARCHAR2 (2000);
        lv_receipt_class_where   VARCHAR2 (2000);
        lv_pay_method_where      VARCHAR2 (2000);
        lv_bank_id_where         VARCHAR2 (2000);
        lv_bank_account_where    VARCHAR2 (2000);
        lv_cust_account_where    VARCHAR2 (2000);
        lv_party_id_where        VARCHAR2 (2000);
        lv_sql_stmt              VARCHAR2 (4000);
        lv_select                VARCHAR2 (4000);
        lv_receipt_select        VARCHAR2 (2000);
        lv_batch_level_sql       VARCHAR2 (2000);
        lv_receipt_level_sql     VARCHAR2 (2000);
        lv_group_by              VARCHAR2 (2000);
        lv_order_by              VARCHAR2 (2000);


        CURSOR c_region_cur (p_region_code IN VARCHAR2)
        IS
            SELECT DISTINCT v.flex_value
              FROM apps.fnd_flex_value_sets s, apps.fnd_flex_values_vl v
             WHERE     1 = 1
                   AND s.flex_value_set_id = v.flex_value_set_id
                   AND s.flex_value_set_name = 'XXDOAR_B2B_OPERATING_UNITS'
                   AND v.enabled_flag = 'Y'
                   AND v.attribute1 = p_region_code;
    BEGIN
        DBMS_OUTPUT.PUT_LINE ('INSIDE PROCEDURE ');

        IF UPPER (P_REP_LEVEL) = 'BATCH'
        THEN
            lv_select     :=
                ' SELECT hou.name operating_unit, 
                                  aba.name batch_number, 
                                  TO_CHAR(aba.batch_date,''DD-MON-YYYY'') batch_date, 
                                  TO_CHAR(aba.gl_date,''DD-MON-YYYY'') gl_date, 
                                  TO_CHAR(stg.depositdate,''DD-MON-YYYY'') deposit_date, 
                                  absa.name batch_source, 
                                  aba.currency_code, 
                                  arc.name receipt_class, 
                                  arm.name payment_method, 
                                  cbv.bank_name, 
                                  cba.bank_account_num, 
                                  aba.comments, 
                                  aba.status, 
                                  aba.control_count, 
                                  aba.control_amount, 
                                  NULL receipt_number, 
                                  NULL amount, 
                                  NULL customer_name, 
                                  NULL customer_number 
                             FROM xxdo.xxdoar_b2b_cashapp_stg stg
                                , apps.ar_batches_all aba
                                , apps.hr_operating_units hou
                                , apps.ar_batch_sources_all absa
                                , apps.ar_receipt_classes arc
                                , apps.ar_receipt_methods arm
                                , apps.ar_receipt_method_accounts_all arma
                                , apps.ce_bank_acct_uses_all cbau
                                , apps.ce_banks_v cbv
                                , apps.ce_bank_accounts cba 
                            WHERE 1=1
                              AND stg.oracle_batch_id = aba.batch_id (+)
                              AND stg.org_id = hou.organization_id (+)
                              AND aba.batch_source_id = absa.batch_source_id (+)
                              AND aba.receipt_class_id = arc.receipt_class_id (+)
                              AND aba.receipt_method_id = arm.receipt_method_id (+)
                              AND arm.receipt_method_id = arma.receipt_method_id (+)
                              AND arma.remit_bank_acct_use_id = cbau.bank_acct_use_id (+)
                              AND cbau.bank_account_id = cba.bank_account_id (+)
                              AND cba.bank_id = cbv.bank_party_id (+) ';

            lv_group_by   := ' GROUP BY hou.name, 
                                      aba.name , 
                                      aba.batch_date, 
                                      aba.gl_date, 
                                      stg.depositdate , 
                                      absa.name , 
                                      aba.currency_code, 
                                      arc.name , 
                                      arm.name , 
                                      cbv.bank_name, 
                                      cba.bank_account_num, 
                                      aba.comments, 
                                      aba.status, 
                                      aba.control_count, 
                                      aba.control_amount ';

            lv_order_by   := ' ORDER BY  aba.batch_date, 
                                       hou.name, 
                                       to_number(aba.name) ';
        ELSE
            lv_select     :=
                ' SELECT hou.name operating_unit, 
                                  aba.name batch_number, 
                                  TO_CHAR(aba.batch_date,''DD-MON-YYYY'') batch_date, 
                                  TO_CHAR(aba.gl_date,''DD-MON-YYYY'') gl_date, 
                                  TO_CHAR(stg.depositdate,''DD-MON-YYYY'') deposit_date, 
                                  absa.name batch_source, 
                                  aba.currency_code, 
                                  arc.name receipt_class, 
                                  arm.name payment_method, 
                                  cbv.bank_name, 
                                  cba.bank_account_num, 
                                  aba.comments, 
                                  aba.status, 
                                  aba.control_count, 
                                  aba.control_amount,
                                  cr.receipt_number, 
                                  cr.amount, 
                                  hp.party_name customer_name, 
                                  hca.account_number customer_number 
                             FROM xxdo.xxdoar_b2b_cashapp_stg stg
                                , apps.ar_batches_all aba
                                , apps.hr_operating_units hou
                                , apps.ar_batch_sources_all absa
                                , apps.ar_receipt_classes arc
                                , apps.ar_receipt_methods arm
                                , apps.ar_receipt_method_accounts_all arma
                                , apps.ce_bank_acct_uses_all cbau
                                , apps.ce_banks_v cbv
                                , apps.ce_bank_accounts cba 
                                , apps.hz_cust_accounts hca
                                , apps.hz_parties hp
                                , apps.ar_cash_receipts_all cr
                            WHERE 1=1
                              AND stg.oracle_batch_id = aba.batch_id (+)
                              AND stg.org_id = hou.organization_id (+)
                              AND aba.batch_source_id = absa.batch_source_id (+)
                              AND aba.receipt_class_id = arc.receipt_class_id (+)
                              AND aba.receipt_method_id = arm.receipt_method_id (+)
                              AND arm.receipt_method_id = arma.receipt_method_id (+)
                              AND arma.remit_bank_acct_use_id = cbau.bank_acct_use_id (+)
                              AND cbau.bank_account_id = cba.bank_account_id (+)
                              AND cba.bank_id = cbv.bank_party_id (+)
                              AND stg.oracle_receipt_id = cr.cash_receipt_id (+)
                              AND cr.pay_from_customer = hca.cust_account_id (+)
                              AND hca.party_id = hp.party_id (+) ';

            lv_group_by   := ' GROUP BY hou.name, 
                                      aba.name , 
                                      aba.batch_date, 
                                      aba.gl_date, 
                                      stg.depositdate , 
                                      absa.name , 
                                      aba.currency_code, 
                                      arc.name , 
                                      arm.name , 
                                      cbv.bank_name, 
                                      cba.bank_account_num, 
                                      aba.comments, 
                                      aba.status, 
                                      aba.control_count, 
                                      aba.control_amount, 
                                      cr.receipt_number, 
                                      cr.amount, 
                                      hp.party_name, 
                                      hca.account_number ';

            lv_order_by   := ' ORDER BY  aba.batch_date, 
                                       hou.name, 
                                       to_number(aba.name) ';
        END IF;

        DBMS_OUTPUT.PUT_LINE ('lv_select=' || lv_select);

        --If region param is passed, get related enabled org_ids
        IF P_REGION IS NOT NULL
        THEN
            lv_region_where   := ' AND hou.organization_id IN (';

            FOR i IN c_region_cur (P_REGION)
            LOOP
                lv_region_where   := lv_region_where || i.flex_value || ',';
            END LOOP;

            lv_region_where   :=
                   SUBSTR (lv_region_where, 1, LENGTH (lv_region_where) - 1)
                || ') ';
        END IF;

        --Operating Unit
        IF P_ORG_ID IS NOT NULL
        THEN
            lv_org_id_where   := ' AND hou.organization_id = ' || P_ORG_ID;
        END IF;

        --Deposit Date From
        IF P_DEP_DATE_FROM IS NOT NULL
        THEN
            lv_dep_date_where1   :=
                   ' AND stg.depositdate >= '
                || 'TRUNC(fnd_date.canonical_to_date('''
                || P_DEP_DATE_FROM
                || '''))';
        END IF;

        --Deposit Date To
        IF P_DEP_DATE_TO IS NOT NULL
        THEN
            lv_dep_date_where2   :=
                   ' AND stg.depositdate < '
                || 'TRUNC(fnd_date.canonical_to_date('''
                || P_DEP_DATE_TO
                || ''')+1)';
        END IF;

        --Creation Date From
        IF P_CRE_DATE_FROM IS NOT NULL
        THEN
            lv_cre_date_where1   :=
                   ' AND aba.creation_date >= '
                || 'TRUNC(fnd_date.canonical_to_date('''
                || P_CRE_DATE_FROM
                || '''))';
        END IF;

        --Creation Date To
        IF P_CRE_DATE_TO IS NOT NULL
        THEN
            lv_cre_date_where2   :=
                   ' AND aba.creation_date < '
                || 'TRUNC(fnd_date.canonical_to_date('''
                || P_CRE_DATE_TO
                || ''')+1)';
        END IF;

        --Batch Number
        IF P_BATCH_ID IS NOT NULL
        THEN
            lv_batch_id_where   := ' AND aba.batch_id = ' || P_BATCH_ID;
        END IF;

        --Batch Date From
        IF P_BATCH_DATE_FROM IS NOT NULL
        THEN
            lv_batch_date_where1   :=
                   ' AND aba.batch_date >= '
                || 'TRUNC(fnd_date.canonical_to_date('''
                || P_BATCH_DATE_FROM
                || '''))';
        END IF;

        --Batch Date To
        IF P_BATCH_DATE_TO IS NOT NULL
        THEN
            lv_batch_date_where2   :=
                   ' AND aba.batch_date < '
                || 'TRUNC(fnd_date.canonical_to_date('''
                || P_BATCH_DATE_TO
                || ''')+1)';
        END IF;

        --Batch Source
        IF P_BATCH_SOURCE_ID IS NOT NULL
        THEN
            lv_batch_source_where   :=
                ' AND aba.batch_source_id = ' || P_BATCH_SOURCE_ID;
        END IF;

        --Receipt Class
        IF P_RECEIPT_CLASS_ID IS NOT NULL
        THEN
            lv_receipt_class_where   :=
                ' AND aba.receipt_class_id = ' || P_RECEIPT_CLASS_ID;
        END IF;

        --Receipt Method
        IF P_PAY_METHOD IS NOT NULL
        THEN
            lv_pay_method_where   :=
                ' AND aba.receipt_method_id = ' || P_PAY_METHOD;
        END IF;

        --Bank
        IF P_BANK_ID IS NOT NULL
        THEN
            lv_bank_id_where   := ' AND cbv.bank_party_id = ' || P_BANK_ID;
        END IF;

        --Bank Account
        IF P_BANK_ACCOUNT_ID IS NOT NULL
        THEN
            lv_bank_account_where   :=
                ' AND cba.bank_account_id = ' || P_BANK_ACCOUNT_ID;
        END IF;

        IF UPPER (P_REP_LEVEL) != 'BATCH'
        THEN
            --Customer Account
            IF P_CUST_ACCOUNT_ID IS NOT NULL
            THEN
                lv_cust_account_where   :=
                    ' AND hca.cust_account_id = ' || P_CUST_ACCOUNT_ID;
            END IF;

            --Party
            IF P_PARTY_ID IS NOT NULL
            THEN
                lv_party_id_where   := ' AND hp.party_id = ' || P_PARTY_ID;
            END IF;
        END IF;

        XXD_AR_BT_RECON_RPT_PKG.p_sql_stmt   :=
               lv_select
            || lv_region_where
            || lv_org_id_where
            || lv_dep_date_where1
            || lv_dep_date_where2
            || lv_cre_date_where1
            || lv_cre_date_where2
            || lv_batch_date_where1
            || lv_batch_date_where2
            || lv_batch_source_where
            || lv_receipt_class_where
            || lv_pay_method_where
            || lv_bank_id_where
            || lv_bank_account_where
            || lv_cust_account_where
            || lv_party_id_where
            || lv_group_by
            || lv_order_by;

        fnd_file.put_line (
            fnd_file.LOG,
            'p_sql_stmt=' || XXD_AR_BT_RECON_RPT_PKG.p_sql_stmt);

        DBMS_OUTPUT.PUT_LINE (
            'p_sql_stmt=' || XXD_AR_BT_RECON_RPT_PKG.p_sql_stmt);
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE ('Error in build_sql:' || SQLERRM);
            fnd_file.put_line (fnd_file.LOG,
                               'Error in build_sql:' || SQLERRM);
    END build_sql;

    ----
    ----
    FUNCTION before_report
        RETURN BOOLEAN
    IS
    BEGIN
        build_sql;
        fnd_file.put_line (fnd_file.LOG, p_sql_stmt);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in before_report:' || SQLERRM);
            RETURN FALSE;
    END before_report;

    ----
    ----
    FUNCTION after_report
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END after_report;
END XXD_AR_BT_RECON_RPT_PKG;
/
