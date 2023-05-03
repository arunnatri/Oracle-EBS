--
-- XXD_AP_PAY_RECON_BL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_PAY_RECON_BL_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_AP_PAY_RECON_BL_PKG
    * Design       : This package is used for fecthing the payment data and send to Black Line
                     for Reconciliation.
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date          Version#    Name                        Comments
    -- ===============================================================================
    -- 12-OCT-2020   1.0         Tejaswi Gangumalla          Initial Version
    -- 07-JUL-2021   2.0         Srinath Siricilla           CCR0009433
    ******************************************************************************************/
    gv_package_name   CONSTANT VARCHAR (30) := 'XXD_AP_PAY_RECON_BL_PKG';
    gv_time_stamp              VARCHAR2 (40)
                                   := TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
    gv_file_time_stamp         VARCHAR2 (40)
                                   := TO_CHAR (SYSDATE, 'MMDDYY_HH24MISS');
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_conc_request_id         NUMBER := fnd_global.conc_request_id;
    p_file_name                VARCHAR2 (100);
    p_path                     VARCHAR2 (100);
    ln_max_id                  NUMBER;

    -----
    -----
    --Write messages into LOG file
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print timestamp or not. Default is NO.
    PROCEDURE print_log (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_LOG';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.LOG, lv_msg || SQLERRM);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print log' || SQLERRM);
    END print_log;

    ----
    ----
    --Write messages into output file
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print timestamp or not. Default is NO.
    PROCEDURE print_out (pv_msg IN VARCHAR2, pv_time IN VARCHAR2 DEFAULT 'N')
    IS
        lv_proc_name    VARCHAR2 (30) := 'PRINT_OUT';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (lv_msg);
        ELSE
            fnd_file.put_line (fnd_file.output, lv_msg);
        END IF;
    --fnd_file.put_line (fnd_file.output, msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Unable to print output:' || SQLERRM);
    END print_out;

    FUNCTION directory_path_fnc
        RETURN VARCHAR2
    IS
        --lv_path   VARCHAR2 (100);
        lv_dir_path   dba_directories.directory_path%TYPE; -- Added as per CCR0009433
    BEGIN
        IF p_dir_name IS NOT NULL
        THEN
            BEGIN
                SELECT directory_name, directory_path
                  INTO p_path, lv_dir_path
                  FROM dba_directories
                 WHERE directory_name = p_dir_name;

                RETURN p_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log (
                           'Unable to get the file path for directory - '
                        || p_dir_name);
                    RETURN NULL;
            END;
        END IF;

        RETURN p_path;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Unable to get the file path for directory');
            RETURN NULL;
    END directory_path_fnc;

    FUNCTION file_name_fnc
        RETURN VARCHAR2
    IS
    BEGIN
        IF p_path IS NOT NULL
        THEN
            p_file_name   :=
                'AP_Payments_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        END IF;

        RETURN p_file_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Error in file_name -' || SQLERRM);
            RETURN NULL;
    END file_name_fnc;

    -----------------------------------------------
    --Fetch Last Run Criteria ID which exists in VS
    -----------------------------------------------
    FUNCTION get_vs_criteria_id (pn_org_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_vs_criteria_id   NUMBER := NULL;
    BEGIN
        SELECT flv.attribute2
          INTO ln_vs_criteria_id
          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl flv
         WHERE     fvs.flex_value_set_id = flv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXD_AP_PAY_RECON_HIST_ID_VS'
               AND SYSDATE BETWEEN NVL (TRUNC (flv.start_date_active),
                                        SYSDATE)
                               AND NVL (TRUNC (flv.end_date_active),
                                        SYSDATE + 1)
               AND flv.enabled_flag = 'Y'
               AND flv.attribute1 = pn_org_id
               AND flv.attribute1 IS NOT NULL;

        --AND flv.summary_flag = 'N';
        RETURN ln_vs_criteria_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_vs_criteria_id   := NULL;
            RETURN ln_vs_criteria_id;
    END get_vs_criteria_id;

    -- Added for CCR0009433

    FUNCTION remove_junk (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END remove_junk;

    PROCEDURE MAIN
    IS
        lv_sql_stmt   LONG;
        lv_msg        VARCHAR2 (2000);
    BEGIN
        lv_sql_stmt   :=
               'INSERT INTO XXDO.XXD_AP_PAY_RECON_BL_T 
               (OPERATING_UNIT       
                ,SUPPLIER_NAME        
                ,SUPPLIER_NUM         
                ,SUPPLIER_SITE        
                ,PAYMENT_NUMBER       
                ,PAYMENT_DATE         
                ,PAYMENT_AMOUNT       
                ,PAYMENT_CURRENCY_CODE
                ,PAYMENT_STATUS       
                ,GL_DATE              
                ,GL_DATE_PARA           
                ,PAYMENT_METHOD_CODE  
                ,PAY_GROUP_LOOKUP_CODE
                ,BANK_ACCOUNT_NAME    
                ,BANK_ACCOUNT_ID      
                ,BANK_CURRENCY        
                ,BANK_CURRENCY_AMOUNT 
                ,PAYMENT_ID     -- Added as per CCR0009433
                )
                (SELECT * FROM  (
                            SELECT   hou.NAME operating_unit, supp.vendor_name supplier_name,
                 supp.segment1 supplier_num,
                 supp_site.vendor_site_code supplier_site,
                 iba.payment_reference_number payment_number,
                 TO_CHAR (iba.payment_date, ''DD-MON-RRRR'') payment_date,
                 SUM (aipa.amount) payment_amount, aia.payment_currency_code,
                 iba.payment_status,
                 (SELECT TO_CHAR (MAX (TRUNC (aeh.accounting_date)),
                                  ''DD-MON-RRRR''
                                 )
                    FROM xla_ae_headers aeh
                   WHERE xlt.entity_id = aeh.entity_id
                     AND xlt.application_id = aeh.application_id
                     AND aeh.ledger_id =
                            (SELECT ledger_id
                               FROM gl_ledgers
                              WHERE NAME =
                                         mo_utils.get_ledger_name (aia.org_id)))
                                                                      gl_date
                                                                             --xla_aeh_headers account_date
                 ,
                 (SELECT TO_CHAR
                               (MAX (TRUNC (aeh.accounting_date)),
                                ''DD-MON-RRRR''
                               )
                    FROM xla_ae_headers aeh
                   WHERE xlt.entity_id = aeh.entity_id
                     AND xlt.application_id = aeh.application_id
                     AND aeh.ledger_id =
                            (SELECT ledger_id
                               FROM gl_ledgers
                              WHERE NAME =
                                         mo_utils.get_ledger_name (aia.org_id)))
                                                                 gl_date_para
                                                                             --xla_aeh_headers account_date
                 ,
                 aia.payment_method_code, aia.pay_group_lookup_code,
                 aca.bank_account_name, cba.bank_account_num,
                 cba.currency_code bank_currency,
                   NVL
                      ((SELECT conversion_rate
                          FROM apps.gl_daily_rates
                         WHERE conversion_type = ''Corporate''
                           AND from_currency = aia.payment_currency_code
                           AND to_currency = cba.currency_code
                           AND conversion_date = TRUNC (iba.creation_date)),
                       1
                      )
                 * SUM (aipa.amount) bank_currency_amount,
                 iba.payment_id -- Added as per CCR0009433
			FROM ap_invoices_all aia,
                 ap_invoice_payments_all aipa,
                 ap_checks_all aca,
                 ap_suppliers supp,
                 ap_supplier_sites_all supp_site,
                 iby_payments_all iba,
                 hr_operating_units hou,
                 ce_bank_accounts cba,
                 xla_transaction_entities_upg xlt
           WHERE 1 = 1
             AND aia.invoice_id = aipa.invoice_id
             AND aia.org_id = aipa.org_id
             AND aia.vendor_id = supp.vendor_id
             AND aia.vendor_site_id = supp_site.vendor_site_id
             AND aia.org_id = supp_site.org_id
             AND supp.vendor_id = supp_site.vendor_id
             AND aca.check_id = aipa.check_id
             AND iba.payment_id = aca.payment_id
             AND hou.organization_id = aia.org_id             
             AND supp.enabled_flag = ''Y''
             AND iba.payments_complete_flag = ''Y''
             AND NVL (supp.start_date_active, SYSDATE) <= SYSDATE
             AND NVL (supp.end_date_active, SYSDATE) >= SYSDATE
             AND NVL (supp_site.inactive_date, SYSDATE) >= SYSDATE
             AND cba.bank_account_name = aca.bank_account_name
             AND xlt.application_id = 200
             AND xlt.entity_code = ''AP_PAYMENTS''
             AND xlt.source_id_int_1 = aipa.check_id
             AND EXISTS (
                    SELECT flv.attribute1
                      FROM apps.fnd_flex_value_sets fs,
                           apps.fnd_flex_values_vl flv
                     WHERE fs.flex_value_set_id = flv.flex_value_set_id
                       AND TO_NUMBER (flv.attribute1) = cba.bank_account_id
                       AND fs.flex_value_set_name =
                                                 ''XXD_AP_BNK_ACCT_TO_BLKLN_VS''
                       AND NVL (flv.enabled_flag, ''N'') = ''Y''
                       AND hou.organization_id =
                              DECODE (flv.attribute2,
                                      '''', hou.organization_id,
                                      flv.attribute2
                                     )
                       AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                        TRUNC (SYSDATE)
                                                       )
                                               AND NVL (flv.end_date_active,
                                                        TRUNC (SYSDATE)
                                                       ))
              AND EXISTS (
                    SELECT 1
                      FROM apps.fnd_flex_value_sets fs,
                           apps.fnd_flex_values_vl flv
                     WHERE fs.flex_value_set_id = flv.flex_value_set_id
                       AND flv.flex_value = iba.payment_status
                       AND fs.flex_value_set_name = ''XXD_AP_RECEIPT_STATUS_VS''
                       AND NVL (flv.enabled_flag, ''N'') = ''Y''
                       AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                        TRUNC (SYSDATE)
                                                       )
                                               AND NVL (flv.end_date_active,
                                                        TRUNC (SYSDATE)
                                                       ))
                                                       
             -- Commented and Added as per CCR0009433  
              AND ((NVL('
            || ''''
            || P_OVERRIDE_EVENT_ID
            || ''''
            || ',''N'') = ''Y''
              AND NVL (TRUNC (iba.void_date), TRUNC (iba.payment_date) + 1) <>
                                                     TRUNC (iba.payment_date)) 
              OR  (NVL('
            || ''''
            || P_OVERRIDE_EVENT_ID
            || ''''
            || ',''N'') = ''N''  
                    AND ((NVL(iba.attribute1,''N'') = ''N''
                            AND NVL(iba.attribute1,''NN'') <> ''YY'' AND iba.void_date IS NULL ) OR  (iba.void_date IS NOT NULL AND NVL(iba.attribute1,''NN'')<> ''YY'' AND aipa.amount < 0))))                                       
               /*OR  (NVL('
            || ''''
            || P_OVERRIDE_EVENT_ID
            || ''''
            || ',''N'') = ''N''  
                    AND ((NVL(iba.attribute1,''N'') = ''N''
                            AND NVL(iba.attribute1,''NN'') <> ''YY'') OR  (iba.void_date IS NOT NULL AND NVL (TRUNC (iba.void_date), TRUNC (iba.payment_date) + 1) <> TRUNC (iba.payment_date) 
                                                        AND NVL(iba.attribute1,''NN'')<> ''YY''))))*/                                                                                                                         
             /*AND EXISTS (
                    SELECT 1
                      FROM xla_ae_headers aeh
                     WHERE aeh.entity_id = xlt.entity_id
                       AND aeh.application_id = xlt.application_id
                       AND aeh.ledger_id =
                              (SELECT ledger_id
                                 FROM gl_ledgers
                                WHERE NAME =
                                         mo_utils.get_ledger_name (aia.org_id))            
                       AND aeh.event_id >
                             DECODE('
            || ''''
            || P_OVERRIDE_EVENT_ID
            || ''''
            || ',''Y'',NVL( '
            || ''''
            || P_HISTORY_ID
            || ''''
            || ',(aeh.event_id-1)),  (SELECT attribute2
                                 FROM apps.fnd_flex_value_sets fs,
                                      apps.fnd_flex_values_vl flv
                                WHERE fs.flex_value_set_id =
                                                         flv.flex_value_set_id
                                  AND flv.attribute1 =  '
            || ''''
            || p_operating_unit
            || ''''
            || 'AND fs.flex_value_set_name =
                                                 ''XXD_AP_PAY_RECON_HIST_ID_VS''
                                  AND NVL (flv.enabled_flag, ''N'') = ''Y''
                                  AND TRUNC (SYSDATE)
                                         BETWEEN NVL (flv.start_date_active,
                                                      TRUNC (SYSDATE)
                                                     )
                                             AND NVL (flv.end_date_active,
                                                      TRUNC (SYSDATE)
                                                     ))))*/                                        
             AND hou.organization_id = '
            || ''''
            || p_operating_unit
            || ''''
            || 'AND cba.bank_account_id =
                                   NVL ('
            || ''''
            || p_bank_acct_num
            || ''''
            || ', cba.bank_account_id)
             AND iba.payment_reference_number
                    BETWEEN NVL ('
            || ''''
            || p_pay_num_from
            || ''''
            || ',
                                 iba.payment_reference_number)
                        AND NVL ('
            || ''''
            || p_pay_num_to
            || ''''
            || ', iba.payment_reference_number)
             AND iba.payment_date
                    BETWEEN NVL (fnd_date.canonical_to_date ('
            || ''''
            || p_pay_date_from
            || ''''
            || '),iba.payment_date)
                        AND NVL (fnd_date.canonical_to_date ('
            || ''''
            || p_pay_date_to
            || ''''
            || '),iba.payment_date
                                )
             AND aipa.creation_date
                    BETWEEN NVL(fnd_date.canonical_to_date ('
            || ''''
            || p_pay_cr_date_from
            || ''''
            || '),aipa.creation_date)
                        AND NVL (fnd_date.canonical_to_date ('
            || ''''
            || p_pay_cr_date_to
            || ''''
            || '),aipa.creation_date)
        GROUP BY hou.NAME,
                 supp.vendor_name,
                 supp.segment1,
                 supp_site.vendor_site_code,
                 iba.payment_reference_number,
                 TO_CHAR (iba.payment_date, ''DD-MON-RRRR''),
                 aia.payment_currency_code,
                 iba.payment_status,
                 aia.payment_method_code,
                 aia.pay_group_lookup_code,
                 aca.bank_account_name,
                 cba.bank_account_num,
                 cba.currency_code,
                 xlt.entity_id,
                 xlt.application_id,
                 aia.org_id,
                 iba.payment_id -- Added as per CCR0009433
                 ,iba.creation_date)
                where gl_date_para   BETWEEN NVL
                              (fnd_date.canonical_to_date ('
            || ''''
            || P_GL_DATE_from
            || ''''
            || '),gl_date_para)
                        AND NVL (fnd_date.canonical_to_date ('
            || ''''
            || P_GL_DATE_to
            || ''''
            || '),gl_date_para))';

        --        print_log (lv_sql_stmt);\
        fnd_file.put_line (fnd_file.LOG, 'lv_sql_stmt = ' || lv_sql_stmt);

        --        dbms_output.put_line(lv_sql_stmt);

        EXECUTE IMMEDIATE lv_sql_stmt;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   := SQLERRM;
            print_log ('Exception in insert_data: ' || lv_msg);
    END main;

    -- End of Change for CCR0009433

    FUNCTION before_report
        RETURN BOOLEAN
    IS
    BEGIN
        -- Start of Change for CCR0009443
        MAIN;

        UPDATE xxdo.xxd_ap_pay_recon_bl_t
           SET creation_date = SYSDATE, created_by = gn_user_id, last_update_date = SYSDATE,
               last_updated_by = gn_user_id, request_id = gn_conc_request_id, last_update_login = gn_login_id
         WHERE 1 = 1;

        COMMIT;

        SELECT COUNT (*)
          INTO ln_max_id
          FROM xxdo.xxd_ap_pay_recon_bl_t
         WHERE request_id = gn_conc_request_id;


        -- Commented for CCR0009443

        /*BEGIN
           SELECT MAX (event_id)
             INTO ln_max_id
             FROM (SELECT (SELECT TO_CHAR
                                     (MAX (TRUNC (aeh.accounting_date)),
                                      'DD-MON-RRRR'
                                     )
                             FROM xla_ae_headers aeh
                            WHERE xlt.entity_id = aeh.entity_id
                              AND xlt.application_id = aeh.application_id
                              AND aeh.ledger_id =
                                     (SELECT ledger_id
                                        FROM gl_ledgers
                                       WHERE NAME =
                                                mo_utils.get_ledger_name
                                                                     (aia.org_id)))
                                                                   gl_date_para,
                          aeh.event_id
                     FROM ap_invoices_all aia,
                          ap_invoice_payments_all aipa,
                          ap_checks_all aca,
                          ap_suppliers supp,
                          ap_supplier_sites_all supp_site,
                          iby_payments_all iba,
                          hr_operating_units hou,
                          ce_bank_accounts cba,
                          xla_transaction_entities_upg xlt,
                          xla_ae_headers aeh
                    WHERE 1 = 1
                      AND aia.invoice_id = aipa.invoice_id
                      AND aia.org_id = aipa.org_id
                      AND aia.vendor_id = supp.vendor_id
                      AND aia.vendor_site_id = supp_site.vendor_site_id
                      AND aia.org_id = supp_site.org_id
                      AND supp.vendor_id = supp_site.vendor_id
                      AND aca.check_id = aipa.check_id
                      AND iba.payment_id = aca.payment_id
                      AND hou.organization_id = aia.org_id
                      AND supp.enabled_flag = 'Y'
                      AND iba.payments_complete_flag = 'Y'
                      AND NVL (TRUNC (iba.void_date),
                               TRUNC (iba.payment_date) + 1
                              ) <> TRUNC (iba.payment_date)
                      AND NVL (supp.start_date_active, SYSDATE) <= SYSDATE
                      AND NVL (supp.end_date_active, SYSDATE) >= SYSDATE
                      AND NVL (supp_site.inactive_date, SYSDATE) >= SYSDATE
                      AND cba.bank_account_name = aca.bank_account_name
                      AND xlt.application_id = 200
                      AND xlt.entity_code = 'AP_PAYMENTS'
                      AND xlt.source_id_int_1 = aipa.check_id
                      AND xlt.entity_id = aeh.entity_id
                      AND xlt.application_id = aeh.application_id
                      AND aeh.ledger_id =
                             (SELECT ledger_id
                                FROM gl_ledgers
                               WHERE NAME =
                                           mo_utils.get_ledger_name (aia.org_id))
                      AND EXISTS (
                             SELECT flv.attribute1
                               FROM apps.fnd_flex_value_sets fs,
                                    apps.fnd_flex_values_vl flv
                              WHERE fs.flex_value_set_id = flv.flex_value_set_id
                                AND TO_NUMBER (flv.attribute1) =
                                                             cba.bank_account_id
                                AND fs.flex_value_set_name =
                                                   'XXD_AP_BNK_ACCT_TO_BLKLN_VS'
                                AND NVL (flv.enabled_flag, 'N') = 'Y'
                                AND hou.organization_id =
                                       DECODE (flv.attribute2,
                                               '', hou.organization_id,
                                               flv.attribute2
                                              )
                                AND TRUNC (SYSDATE)
                                       BETWEEN NVL (flv.start_date_active,
                                                    TRUNC (SYSDATE)
                                                   )
                                           AND NVL (flv.end_date_active,
                                                    TRUNC (SYSDATE)
                                                   ))
                      AND EXISTS (
                             SELECT 1
                               FROM apps.fnd_flex_value_sets fs,
                                    apps.fnd_flex_values_vl flv
                              WHERE fs.flex_value_set_id = flv.flex_value_set_id
                                AND flv.flex_value = iba.payment_status
                                AND fs.flex_value_set_name =
                                                      'XXD_AP_RECEIPT_STATUS_VS'
                                AND NVL (flv.enabled_flag, 'N') = 'Y'
                                AND TRUNC (SYSDATE)
                                       BETWEEN NVL (flv.start_date_active,
                                                    TRUNC (SYSDATE)
                                                   )
                                           AND NVL (flv.end_date_active,
                                                    TRUNC (SYSDATE)
                                                   ))
                      AND EXISTS (
                             SELECT 1
                               FROM xla_ae_headers aeh
                              WHERE aeh.entity_id = xlt.entity_id
                                AND aeh.application_id = xlt.application_id
                                AND aeh.ledger_id =
                                       (SELECT ledger_id
                                          FROM gl_ledgers
                                         WHERE NAME =
                                                  mo_utils.get_ledger_name
                                                                     (aia.org_id))
                                AND aeh.event_id >
                                       DECODE
                                          (p_override_event_id,'Y', NVL (p_history_id,(aeh.event_id - 1)),
                                           (SELECT attribute2
                                              FROM apps.fnd_flex_value_sets fs,
                                                   apps.fnd_flex_values_vl flv
                                             WHERE fs.flex_value_set_id =
                                                           flv.flex_value_set_id
                                               AND flv.attribute1 =
                                                                p_operating_unit
                                               AND fs.flex_value_set_name =
                                                      'XXD_AP_PAY_RECON_HIST_ID_VS'
                                               AND NVL (flv.enabled_flag, 'N') =
                                                                             'Y'
                                               AND TRUNC (SYSDATE)
                                                      BETWEEN NVL
                                                                (flv.start_date_active,
                                                                 TRUNC (SYSDATE)
                                                                )
                                                          AND NVL
                                                                (flv.end_date_active,
                                                                 TRUNC (SYSDATE)
                                                                ))
                                          ))
                      AND hou.organization_id = p_operating_unit
                      AND cba.bank_account_id =
                                      NVL (p_bank_acct_num, cba.bank_account_id)
                      AND iba.payment_reference_number
                             BETWEEN NVL (p_pay_num_from,
                                          iba.payment_reference_number
                                         )
                                 AND NVL (p_pay_num_to,
                                          iba.payment_reference_number
                                         )
                      AND iba.payment_date
                             BETWEEN NVL
                                       (fnd_date.canonical_to_date
                                                                (p_pay_date_from),
                                        iba.payment_date
                                       )
                                 AND NVL
                                       (fnd_date.canonical_to_date
                                                                  (p_pay_date_to),
                                        iba.payment_date
                                       )
                      AND aipa.creation_date
                             BETWEEN NVL
                                       (fnd_date.canonical_to_date
                                                             (p_pay_cr_date_from),
                                        aipa.creation_date
                                       )
                                 AND NVL
                                       (fnd_date.canonical_to_date
                                                               (p_pay_cr_date_to),
                                        aipa.creation_date
                                       ))
            WHERE gl_date_para
                     BETWEEN NVL (fnd_date.canonical_to_date (p_gl_date_from),
                                  gl_date_para
                                 )
                         AND NVL (fnd_date.canonical_to_date (p_gl_date_to),
                                  gl_date_para
                                 );
        EXCEPTION
           WHEN OTHERS
           THEN
              ln_max_id := 0;
              RETURN TRUE;
        END;*/

        -- End of Change

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log ('Exception in Before report' || SQLERRM);

            RETURN TRUE;
    END before_report;

    FUNCTION submit_bursting_fnc
        RETURN BOOLEAN
    AS
        --      lb_result        BOOLEAN        := TRUE;
        --      ln_req_id        NUMBER;
        --      ln_req_id1       NUMBER;
        lc_flag             VARCHAR2 (2);
        lv_dir_path         VARCHAR2 (100);
        ln_count            NUMBER := 0;
        ln_criteria_id      NUMBER;
        lv_status_code      VARCHAR2 (10);
        ln_folder_val       VARCHAR2 (50);

        -- Start of Change for CCR0009443

        l_req_id            NUMBER;
        ex_no_recips        EXCEPTION;
        ex_no_sender        EXCEPTION;
        ex_no_data_found    EXCEPTION;
        l_start_date        DATE;
        l_end_date          DATE;
        lv_output_file      UTL_FILE.file_type;

        lv_ver              VARCHAR2 (32767) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_delimiter        VARCHAR2 (5) := '|';
        lv_file_delimiter   VARCHAR2 (1) := '|';

        CURSOR C1 IS
            SELECT *
              FROM xxdo.xxd_ap_pay_recon_bl_t
             WHERE 1 = 1 AND request_id = gn_conc_request_id;
    BEGIN
        lv_status_code   := NULL;
        lv_dir_path      := NULL;
        ln_count         := 0;

        --      ln_req_id := NULL;

        IF NVL (p_send_bl, 'N') = 'Y'
        THEN
            BEGIN
                SELECT tag
                  INTO ln_folder_val
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXD_AP_PAY_FOLDER_VAL'
                       AND meaning = 'Deckers AP Payments To Blackline'
                       AND enabled_flag = 'Y'
                       AND LANGUAGE = USERENV ('Lang')
                       AND TRUNC (SYSDATE) BETWEEN NVL (start_date_active,
                                                        TRUNC (SYSDATE))
                                               AND NVL (end_date_active,
                                                        TRUNC (SYSDATE));
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_folder_val   := NULL;
            END;

            IF ln_folder_val = p_dir_name
            THEN
                BEGIN
                    SELECT directory_path_fnc INTO lv_dir_path FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_dir_path   := NULL;
                        print_log (
                               ' Directory is not found with error msg - '
                            || SUBSTR (SQLERRM, 1, 200));
                END;
            END IF;
        END IF;

        IF lv_dir_path IS NOT NULL AND NVL (ln_max_id, 0) <> 0
        THEN
            -- Start of Chnage for CCR0009433

            --lv_delimiter := '|';
            lv_ver   :=
                   'Operating Unit'
                || lv_delimiter
                || 'Supplier Name'
                || lv_delimiter
                || 'Supplier Number'
                || lv_delimiter
                || 'Supplier Site'
                || lv_delimiter
                || 'Payment Number'
                || lv_delimiter
                || 'Payment Date'
                || lv_delimiter
                || 'Payment Amount'
                || lv_delimiter
                || 'Payment Currency'
                || lv_delimiter
                || 'Payment Status'
                || lv_delimiter
                || 'GL Date'
                || lv_delimiter
                || 'Payment Method'
                || lv_delimiter
                || 'Pay Group'
                || lv_delimiter
                || 'Bank Account Name'
                || lv_delimiter
                || 'Bank Account Number'
                || lv_delimiter
                || 'Bank Currency'
                || lv_delimiter
                || 'Bank Currency Amount';

            --Writing into a file
            IF NVL (p_send_bl, 'N') = 'Y'
            THEN
                lv_output_file   :=
                    UTL_FILE.fopen (p_path, p_file_name || '.tmp', 'W' --opening the file in write mode
                                                                      ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    lv_ver   :=
                        REPLACE (lv_ver, lv_delimiter, lv_file_delimiter);
                    UTL_FILE.put_line (lv_output_file, lv_ver);
                END IF;
            END IF;

            FOR i IN c1
            LOOP
                BEGIN
                    --lv_delimiter := '||';
                    --                        lv_delimiter := '|';
                    lv_line   :=
                           remove_junk (i.OPERATING_UNIT)
                        || lv_delimiter
                        || remove_junk (i.SUPPLIER_NAME)
                        || lv_delimiter
                        || remove_junk (i.SUPPLIER_NUM)
                        || lv_delimiter
                        || remove_junk (i.SUPPLIER_SITE)
                        || lv_delimiter
                        || remove_junk (i.PAYMENT_NUMBER)
                        || lv_delimiter
                        || remove_junk (i.PAYMENT_DATE)
                        || lv_delimiter
                        || remove_junk (i.PAYMENT_AMOUNT)
                        || lv_delimiter
                        || remove_junk (i.PAYMENT_CURRENCY_CODE)
                        || lv_delimiter
                        || remove_junk (i.PAYMENT_STATUS)
                        || lv_delimiter
                        || remove_junk (i.GL_DATE)
                        || lv_delimiter
                        || remove_junk (i.PAYMENT_METHOD_CODE)
                        || lv_delimiter
                        || remove_junk (i.PAY_GROUP_LOOKUP_CODE)
                        || lv_delimiter
                        || remove_junk (i.BANK_ACCOUNT_NAME)
                        || lv_delimiter
                        || remove_junk (i.BANK_ACCOUNT_ID)
                        || lv_delimiter
                        || remove_junk (i.BANK_CURRENCY)
                        || lv_delimiter
                        || remove_junk (i.BANK_CURRENCY_AMOUNT);

                    IF NVL (p_send_bl, 'N') = 'Y'
                    THEN
                        IF UTL_FILE.is_open (lv_output_file)
                        THEN
                            lv_line   :=
                                REPLACE (lv_line,
                                         lv_delimiter,
                                         lv_file_delimiter);
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM || 'Account Number :' || i.bank_account_id
                                                   , l_debug_level => 1);
                END;
            END LOOP;

            IF NVL (p_send_bl, 'N') = 'Y'
            THEN
                UTL_FILE.fclose (lv_output_file);
                UTL_FILE.frename (src_location    => p_path,
                                  src_filename    => p_file_name || '.tmp',
                                  dest_location   => p_path,
                                  dest_filename   => p_file_name || '.csv',
                                  overwrite       => TRUE);

                BEGIN
                    UPDATE apps.iby_payments_all ipa
                       SET ipa.attribute1   = 'Y'
                     WHERE     1 = 1
                           AND EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxd_ap_pay_recon_bl_t stg
                                     WHERE     1 = 1
                                           AND stg.payment_id =
                                               ipa.payment_id
                                           AND stg.request_id =
                                               gn_conc_request_id);

                    COMMIT;

                    UPDATE apps.iby_payments_all ipa
                       SET ipa.attribute1   = 'YY'
                     WHERE     1 = 1
                           AND void_date IS NOT NULL
                           AND attribute1 = 'Y'
                           AND EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxd_ap_pay_recon_bl_t stg
                                     WHERE     1 = 1
                                           AND stg.payment_id =
                                               ipa.payment_id
                                           AND stg.request_id =
                                               gn_conc_request_id);

                    COMMIT;

                    --Update Latest Cashflow Id
                    /*UPDATE apps.fnd_flex_values_vl    flv
                        SET flv.attribute1 = ln_max_id
                        WHERE 1 = 1
                            AND flv.flex_value_set_id IN
                                    (SELECT flex_value_set_id
                                        FROM apps.fnd_flex_value_sets
                                        WHERE flex_value_set_name = 'XXD_CE_LATEST_CASHFLOW_ID_VS')
                            AND flv.enabled_flag = 'Y'
                            AND SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1)
                                            AND nvl(flv.end_date_active, SYSDATE + 1);
                        COMMIT;*/
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Updated the Attribute in Payments table ');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error While Updating the Attribute in Payments table '
                            || SQLERRM);
                END;
            END IF;

            -- Commented as per CCR0009433

            /*ln_req_id :=
               fnd_request.submit_request
                                       (application      => 'XDO',
                                        program          => 'XDOBURSTREP',
                                        description      =>    'Bursting - Placing '
                                                            || p_file_name
                                                            || ' under '
                                                            || p_path,
                                        argument1        => 'Y',
                                        argument2        => fnd_global.conc_request_id,
                                        argument3        => 'Y'
                                       );
            --COMMIT;
            ln_req_id1 :=
               fnd_request.submit_request
                  (application      => 'XXDO',
                   program          => 'XXD_AP_PAY_RECON_UPDATE_VS',
                   description      => 'Deckers AP Payments To Blackline Update ValueSet',
                   argument1        => 'AP',
                   argument2        => ln_req_id,
                   argument3        => p_operating_unit,
                   argument4        => ln_max_id
                  );*/
            --COMMIT;



            RETURN TRUE;
        ELSE
            print_log (
                ' Please check the BL flag and Valid directory; Skipping Bursting Program');
            RETURN TRUE;
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_PATH: File location or filename was invalid.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_MODE: The open_mode parameter in FOPEN was invalid.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_FILEHANDLE: The file handle was invalid.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_OPERATION: The file could not be opened or operated on as requested.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'READ_ERROR: An operating system error occurred during the read operation.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'WRITE_ERROR: An operating system error occurred during the write operation.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'INTERNAL_ERROR: An unspecified error in PL/SQL.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_FILENAME: The filename parameter is invalid.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN ex_no_data_found
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'There is no data for the specified month.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN ex_no_recips
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN ex_no_sender
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AP_PAY_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , l_debug_level => 1);

            RETURN FALSE;
    -- End of Change for CCR0009433
    END submit_bursting_fnc;
END XXD_AP_PAY_RECON_BL_PKG;
/
