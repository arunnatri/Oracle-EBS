--
-- XXD_AR_RCPT_RECON_BL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_RCPT_RECON_BL_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_AR_RCPT_RECON_BL_PKG
    * Design       : This package is used for fecthing the receipts data and send to Black Line
                     for Reconciliation.
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 02-OCT-2020  1.0       Srinath Siricilla        Initial Version
    -- 07-JUL-2021  2.0       Srinath Siricilla        CCR0009433
    -- 05-OCT-2022  2.1       Srinath Siricilla        CCR0010243
    ******************************************************************************************/
    gv_package_name   CONSTANT VARCHAR (30) := 'XXD_AR_RCPT_RECON_BL_PKG';
    gv_time_stamp              VARCHAR2 (40)
                                   := TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
    gv_file_time_stamp         VARCHAR2 (40)
                                   := TO_CHAR (SYSDATE, 'MMDDYY_HH24MISS');
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.user_id;
    gn_conc_request_id         NUMBER := fnd_global.conc_request_id;

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
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unable to get the file path for directory - '
                        || p_dir_name);

                    RETURN NULL;
            END;
        END IF;

        RETURN p_path;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to get the file path for directory');
            RETURN NULL;
    END directory_path_fnc;

    FUNCTION file_name_fnc
        RETURN VARCHAR2
    IS
    BEGIN
        IF p_path IS NOT NULL
        THEN
            P_FILE_NAME   :=
                'AR_Receipts_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        END IF;

        RETURN P_FILE_NAME;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in file_name -' || SQLERRM);
    END file_name_fnc;

    FUNCTION get_date_fnc
        RETURN VARCHAR2
    IS
        lv_sysdate   VARCHAR2 (100);
    BEGIN
        SELECT TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SSSSS')
          INTO lv_sysdate
          FROM DUAL;

        RETURN lv_sysdate;
    END;

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
               AND fvs.flex_value_set_name = 'XXD_AR_RCPT_RECON_HIST_ID_VS'
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

    ---------------------------------------------
    --Fetch MAX Cash Receipt History ID to update Criteria ID
    ---------------------------------------------
    FUNCTION get_criteria_id (pn_operating_unit IN NUMBER)
        RETURN NUMBER
    IS
        ln_criteria_id   NUMBER := NULL;
    BEGIN
        IF (p_operating_unit IS NOT NULL)
        THEN
            --To fetch CF History ID if Bank Account Num is NOT NULL
            BEGIN
                SELECT MAX (archa.cash_receipt_history_id)
                  INTO ln_criteria_id
                  FROM apps.ar_cash_receipts_all arca, apps.ar_cash_receipt_history_all archa, ce_bank_acct_uses_all remit_bank
                 WHERE     1 = 1
                       AND archa.cash_receipt_id(+) = arca.cash_receipt_id
                       AND archa.org_id(+) = arca.org_id
                       AND archa.first_posted_record_flag(+) = 'Y'
                       AND remit_bank.bank_acct_use_id(+) =
                           arca.remit_bank_acct_use_id
                       AND remit_bank.org_id(+) = arca.org_id
                       AND arca.org_id = NVL (p_operating_unit, arca.org_id)
                       AND remit_bank.bank_account_id =
                           NVL (p_bank_acct_num, remit_bank.bank_account_id)
                       AND EXISTS
                               (SELECT 1
                                  FROM apps.fnd_flex_value_sets fs, apps.fnd_flex_values_vl flv
                                 WHERE     fs.flex_value_set_id =
                                           flv.flex_value_set_id
                                       AND flv.flex_value = archa.status
                                       AND fs.flex_value_set_name =
                                           'XXD_AR_RECEIPT_STATUS_VS'
                                       AND NVL (flv.enabled_flag, 'N') = 'Y'
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       flv.start_date_active,
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       flv.end_date_active,
                                                                       TRUNC (
                                                                           SYSDATE)))
                       AND EXISTS
                               (SELECT flv.attribute1
                                  FROM apps.fnd_flex_value_sets fs, apps.fnd_flex_values_vl flv
                                 WHERE     fs.flex_value_set_id =
                                           flv.flex_value_set_id
                                       AND TO_NUMBER (flv.attribute1) =
                                           remit_bank.bank_account_id
                                       AND fs.flex_value_set_name =
                                           'XXD_CE_AR_BNK_ACCT_TO_BLKLN_VS'
                                       AND NVL (flv.enabled_flag, 'N') = 'Y'
                                       AND arca.org_id =
                                           DECODE (flv.attribute2,
                                                   '', arca.org_id,
                                                   flv.attribute2)
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       flv.start_date_active,
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       flv.end_date_active,
                                                                       TRUNC (
                                                                           SYSDATE)))
                       AND arca.creation_date BETWEEN NVL (
                                                          fnd_date.canonical_to_date (
                                                              p_rcpt_cr_date_from),
                                                          arca.creation_date)
                                                  AND NVL (
                                                          fnd_date.canonical_to_date (
                                                              p_rcpt_cr_date_to),
                                                          arca.creation_date)
                       AND arca.receipt_date BETWEEN NVL (
                                                         fnd_date.canonical_to_date (
                                                             p_rcpt_date_from),
                                                         arca.receipt_date)
                                                 AND NVL (
                                                         fnd_date.canonical_to_date (
                                                             p_rcpt_date_to),
                                                         arca.receipt_date);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_criteria_id   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exp- Error to fetch CR History ID when p_operating_unit is NOT NULL :'
                        || SQLERRM);
            END;
        ELSE
            NULL;
        --To fetch CF History ID
        --        BEGIN
        --            SELECT
        --                MAX(cash_receipt_history_id)
        --            INTO
        --                ln_criteria_id
        --            FROM
        --                ar_cash_receipt_history_all
        --            WHERE
        --                1 = 1;
        --        EXCEPTION
        --            WHEN OTHERS
        --                THEN
        --                ln_criteria_id := NULL;
        --                print_log('Exp- Error to fetch CF History ID :'||SQLERRM);
        --        END;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Latest CR History ID is  : ' || ln_criteria_id);
        RETURN ln_criteria_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_criteria_id   := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                'Exp-Main Error to fetch CR History ID :' || SQLERRM);
            RETURN ln_criteria_id;
    END get_criteria_id;

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
               'INSERT INTO xxdo.xxd_ar_rcpt_recon_bl_t 
               (operating_unit            
                ,customer_name             
                ,account_number            
                ,receipt_number            
                ,receipt_date              
                ,receipt_amount            
                ,currency_code             
                ,bal_status                
                ,gl_date                   
                ,receipt_state               
                ,batch_source              
                ,batch_number              
                ,receipt_method            
                ,receipt_class             
                ,bank_account_num          
                ,remit_bank_name           
                ,remittance_bank_branch_id 
                ,remit_bank_branch         
                ,remit_bank_currency       
                ,bank_amount               
                ,bank_date_bt 
                ,cash_receipt_history_id
                )
                SELECT hrou.name,
                party.party_name,
                cust.account_number,
                arca.receipt_number,
                to_date(arca.receipt_date,''DD-MON-RRRR''),
                DECODE(archa.status,''REVERSED'',-1*arca.amount,arca.amount) amount,
                arca.currency_code,
                arca.status,
                to_date(archa.gl_date,''DD-MON-RRRR''),
                archa.status,
                bs.name,
                Bat.NAME,
                rec_method.name,
                rc.name,
                cba.bank_account_num,
                bb.bank_name remit_bank_name,
                bb.branch_party_id,
                bb.bank_branch_name,
                cba.currency_code,
                -- Commented and added as per CCR0010243 
--                DECODE (
--                   cba.currency_code,
--                   arca.currency_code, arca.amount,
--                     arca.amount
--                   * (SELECT conversion_rate
--                        FROM gl_daily_rates
--                       WHERE     conversion_type = ''CORPORATE''
--                             AND from_currency = arca.currency_code
--                             AND to_currency = cba.currency_code
--                             AND conversion_date = arca.receipt_date))
                DECODE(archa.status,''REVERSED'',-1*DECODE (
                   cba.currency_code,
                   arca.currency_code, arca.amount,
                     arca.amount
                   * (SELECT conversion_rate
                        FROM gl_daily_rates
                       WHERE     conversion_type = ''CORPORATE''
                             AND from_currency = arca.currency_code
                             AND to_currency = cba.currency_code
                             AND conversion_date = arca.receipt_date)),
                --- End of Change as per CCR0010243             
                DECODE (
                   cba.currency_code,
                   arca.currency_code, arca.amount,
                     arca.amount
                   * (SELECT conversion_rate
                        FROM gl_daily_rates
                       WHERE     conversion_type = ''CORPORATE''
                             AND from_currency = arca.currency_code
                             AND to_currency = cba.currency_code
                             AND conversion_date = arca.receipt_date)))
                   ,new_stg.bank_date_bt
                ,
                archa.cash_receipt_history_id   
           FROM apps.hr_operating_units hrou,
                apps.hz_parties party,
                apps.ar_cash_receipts_all arca,
                apps.hz_cust_accounts cust,
                apps.ar_cash_receipt_history_all archa,
                ar_batches_all bat,
                ar_receipt_methods rec_method,
                ar_receipt_classes rc,
                hz_cust_site_uses_all site_uses,
                --ar_receivables_trx_all rec_trx,
                ce_bank_acct_uses_all remit_bank,
                ce_bank_branches_v bb,
                ce_bank_accounts cba,
                ar_batch_sources_all bs,
                (SELECT max(depositdate) BANK_DATE_BT,
                        oracle_receipt_id 
                   FROM xxdo.XXDOAR_B2B_CASHAPP_STG 
               GROUP BY oracle_receipt_id) new_stg
          WHERE     1 = 1
                AND arca.org_id = hrou.organization_id
                AND archa.batch_id = bat.batch_id(+)
                AND archa.org_id = bat.org_id(+)
                AND archa.cash_receipt_id(+) = arca.cash_receipt_id
                AND archa.org_id(+) = arca.org_id
                AND new_stg.oracle_receipt_id(+) = arca.cash_receipt_id
                --AND archa.first_posted_record_flag(+) = ''Y''
                AND arca.pay_from_customer = cust.cust_account_id(+)
                AND cust.party_id = party.party_id(+)
                AND arca.receipt_method_id = rec_method.receipt_method_id
                AND rec_method.receipt_class_id = rc.receipt_class_id
                AND arca.customer_site_use_id = site_uses.site_use_id(+)
                AND arca.org_id = site_uses.org_id(+)
                AND remit_bank.bank_acct_use_id(+) =
                       arca.remit_bank_acct_use_id
                AND remit_bank.org_id(+) = arca.org_id
				AND remit_bank.bank_account_id = cba.bank_account_id(+)
                AND bb.branch_party_id(+) = cba.bank_branch_id
                AND bs.batch_source_id(+) = bat.batch_source_id
                AND bs.org_id(+) = bat.org_id
                AND hrou.organization_id = NVL('
            || ''''
            || p_operating_unit
            || ''''
            || ',hrou.organization_id)
                AND cba.bank_account_id =
                       NVL ('
            || ''''
            || p_bank_acct_num
            || ''''
            || ', cba.bank_account_id)
				AND EXISTS (SELECT 1
                        FROM
                            apps.fnd_flex_value_sets   fs,
                            apps.fnd_flex_values_vl    flv
                        WHERE
                            fs.flex_value_set_id = flv.flex_value_set_id
                            AND flv.flex_value = archa.status   
                            AND fs.flex_value_set_name = ''XXD_AR_RECEIPT_STATUS_VS''
                            AND nvl(flv.enabled_flag, ''N'') = ''Y''
                            AND trunc(SYSDATE) BETWEEN nvl(flv.start_date_active, trunc(SYSDATE)) 
                                                        AND nvl(flv.end_date_active, trunc(SYSDATE)))
                    /* Commented and added as per CCR0010243*/                                    
--                  AND ((NVL('
            || ''''
            || P_UPDATE_HIST_ID
            || ''''
            || ',''N'') = ''Y''
--                    AND 1=1)
--                    OR (NVL('
            || ''''
            || P_UPDATE_HIST_ID
            || ''''
            || ',''N'') = ''N''
--                        AND 1=1
--                        AND NVL(archa.attribute1,''N'') <> ''Y'' ))                                        
                  AND ((NVL('
            || ''''
            || P_UPDATE_HIST_ID
            || ''''
            || ',''N'') = ''Y''
                    AND 1=1)
                    OR ((NVL('
            || ''''
            || P_UPDATE_HIST_ID
            || ''''
            || ',''N'') = ''N''
                        AND 1=1
                        AND NVL(archa.attribute1,''N'') <> ''Y'' )
                    OR (NVL('
            || ''''
            || P_UPDATE_HIST_ID
            || ''''
            || ',''N'') = ''N''
                        AND 1=1
                        AND NVL(archa.attribute1,''N'') <> ''YY'' )
                        AND  archa.status = ''REVERSED'')    )                         
                  -- End of Change for CCR0010243                                           
                  AND arca.creation_date BETWEEN nvl(fnd_date.canonical_to_date('
            || ''''
            || p_rcpt_cr_date_from
            || ''''
            || '),arca.creation_date) 
                                                AND nvl(fnd_date.canonical_to_date('
            || ''''
            || p_rcpt_cr_date_to
            || ''''
            || '),arca.creation_date)
                  AND arca.receipt_date BETWEEN nvl(fnd_date.canonical_to_date('
            || ''''
            || p_rcpt_date_from
            || ''''
            || '),arca.receipt_date) 
                                                AND nvl(fnd_date.canonical_to_date('
            || ''''
            || p_rcpt_date_to
            || ''''
            || '),arca.receipt_date)';

        fnd_file.put_line (fnd_file.LOG, lv_sql_stmt);

        DBMS_OUTPUT.put_line (lv_sql_stmt);

        --        print_log ('TEST PRINT');

        EXECUTE IMMEDIATE lv_sql_stmt;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   := SQLERRM;
            print_log ('Exception in insert_data: ' || lv_msg);
    END MAIN;

    -- End of Change for CCR0009433

    --   FUNCTION main_fnc (pn_org_id IN NUMBER)
    --      RETURN BOOLEAN
    FUNCTION main_fnc
        RETURN BOOLEAN
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Printing the Program Parameters');

        fnd_file.put_line (fnd_file.LOG, '---------------------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'p_operating_unit - ' || p_operating_unit);
        fnd_file.put_line (fnd_file.LOG,
                           'p_bank_acct_num - ' || p_bank_acct_num);
        fnd_file.put_line (fnd_file.LOG,
                           'p_rcpt_cr_date_from - ' || p_rcpt_cr_date_from);
        fnd_file.put_line (fnd_file.LOG,
                           'p_rcpt_cr_date_to - ' || p_rcpt_cr_date_to);
        fnd_file.put_line (fnd_file.LOG,
                           'p_rcpt_date_from - ' || p_rcpt_date_from);
        fnd_file.put_line (fnd_file.LOG,
                           'p_rcpt_date_to - ' || p_rcpt_date_to);
        fnd_file.put_line (fnd_file.LOG, 'p_send_bl - ' || p_send_bl);
        fnd_file.put_line (fnd_file.LOG, 'p_dir_name - ' || p_dir_name);
        fnd_file.put_line (fnd_file.LOG, 'Test Again - ');

        -- Start of Change for CCR0009443
        MAIN;

        UPDATE xxdo.xxd_ar_rcpt_recon_bl_t
           SET creation_date = SYSDATE, created_by = gn_user_id, last_update_date = SYSDATE,
               last_updated_by = gn_user_id, request_id = gn_conc_request_id, last_update_login = gn_login_id;

        COMMIT;

        --      BEGIN
        --
        --         SELECT get_criteria_id (pn_org_id) INTO p_max_receipt_id FROM DUAL;
        --
        --      EXCEPTION
        --         WHEN OTHERS
        --         THEN
        --            p_max_receipt_id := NULL;
        --      END;

        --ln_max_receipt_id := get_criteria_id (pn_org_id);
        --      fnd_file.put_line (fnd_file.LOG,
        --                         'Max of CR History ID :' || p_max_receipt_id);
        --      fnd_file.put_line (fnd_file.LOG, 'SQL Exception - ' || SQLERRM);
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exp- Error in before_report :' || SQLERRM);
            RETURN FALSE;
    END main_fnc;

    FUNCTION submit_bursting_fnc
        RETURN BOOLEAN
    AS
        --      lb_result              BOOLEAN := TRUE;
        --      ln_req_id              NUMBER;
        --      lc_flag                VARCHAR2 (2);
        lv_dir_path         VARCHAR2 (100);
        ln_count            NUMBER := 0;
        ln_criteria_id      NUMBER;
        --      lv_status_code         VARCHAR2 (10);
        --      lc_phase               VARCHAR2 (50);
        --      lv_req_phase           VARCHAR2 (50);
        --      lv_req_status          VARCHAR2 (50);
        --      lv_req_dev_phase       VARCHAR2 (50);
        --      lv_req_dev_status      VARCHAR2 (50);
        --      lv_req_message         VARCHAR2 (1000);
        --      lv_req_return_status   BOOLEAN;

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
              FROM xxdo.xxd_ar_rcpt_recon_bl_t
             WHERE 1 = 1 AND request_id = gn_conc_request_id;
    BEGIN
        --      lv_status_code := NULL;
        --      lv_dir_path := NULL;
        ln_count   := 0;

        --      ln_req_id := NULL;
        --      lb_result := NULL;
        --      lv_req_phase := NULL;
        --      lv_req_status := NULL;
        --      lv_req_dev_phase := NULL;
        --      lv_req_dev_status := NULL;
        --      lv_req_message := NULL;

        BEGIN
            SELECT directory_path_fnc INTO lv_dir_path FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_dir_path   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' Directory is not found with error msg - '
                    || SUBSTR (SQLERRM, 1, 200));
        --    lb_result := FALSE;
        END;

        --Fetch XML Main Query records count
        BEGIN
            SELECT COUNT (*) INTO ln_count FROM xxdo.xxd_ar_rcpt_recon_bl_t;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_count   := 0;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exp- Error to fetch XML Main Query records count :'
                    || SQLERRM);
        END;

        IF p_send_bl = 'Y' AND lv_dir_path IS NOT NULL AND ln_count > 0
        THEN
            -- Start of chnage CCR0009433

            lv_ver   :=
                   'Operating Unit'
                || lv_delimiter
                || 'Customer Name'
                || lv_delimiter
                || 'Account Number'
                || lv_delimiter
                || 'Receipt Number'
                || lv_delimiter
                || 'Receipt Date'
                || lv_delimiter
                || 'Receipt Amount'
                || lv_delimiter
                || 'Receipt Currency'
                || lv_delimiter
                || 'Receipt Status'
                || lv_delimiter
                || 'GL Date'
                || lv_delimiter
                || 'Batch Number'
                || lv_delimiter
                || 'Batch Source'
                || lv_delimiter
                || 'Receipt Method'
                || lv_delimiter
                || 'Payment Type'
                || lv_delimiter
                || 'Bank Account Name'
                || lv_delimiter
                || 'Bank Account Number'
                || lv_delimiter
                || 'Bank Currency'
                || lv_delimiter
                || 'Bank Currency Amount'
                || lv_delimiter
                || 'Bank Date From Bill Trust';

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

            fnd_file.put_line (
                fnd_file.LOG,
                   'Before Start of loop - '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR hh24:MI:SS'));

            FOR i IN c1
            LOOP
                BEGIN
                    --lv_delimiter := '||';
                    --                        lv_delimiter := '|';
                    lv_line   :=
                           remove_junk (i.OPERATING_UNIT)
                        || lv_delimiter
                        || remove_junk (i.CUSTOMER_NAME)
                        || lv_delimiter
                        || remove_junk (i.ACCOUNT_NUMBER)
                        || lv_delimiter
                        || remove_junk (i.RECEIPT_NUMBER)
                        || lv_delimiter
                        || remove_junk (i.RECEIPT_DATE)
                        || lv_delimiter
                        || remove_junk (i.RECEIPT_AMOUNT)
                        || lv_delimiter
                        || remove_junk (i.CURRENCY_CODE)
                        || lv_delimiter
                        || remove_junk (i.BAL_STATUS)
                        || lv_delimiter
                        || remove_junk (i.GL_DATE)
                        || lv_delimiter
                        || remove_junk (i.BATCH_NUMBER)
                        || lv_delimiter
                        || remove_junk (i.BATCH_SOURCE)
                        || lv_delimiter
                        || remove_junk (i.RECEIPT_METHOD)
                        || lv_delimiter
                        || remove_junk (i.RECEIPT_CLASS)
                        || lv_delimiter
                        || remove_junk (i.REMIT_BANK_NAME)
                        || lv_delimiter
                        || remove_junk (i.BANK_ACCOUNT_NUM)
                        || lv_delimiter
                        || remove_junk (i.REMIT_BANK_CURRENCY)
                        || lv_delimiter
                        || remove_junk (i.BANK_AMOUNT)
                        || lv_delimiter
                        || remove_junk (i.BANK_DATE_BT);

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
                        apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_AR_RCPT_RECON_BL_PKG.MAIN', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM || 'Account Number :' || i.bank_account_num
                                                   , l_debug_level => 1);
                END;
            END LOOP;

            fnd_file.put_line (
                fnd_file.LOG,
                   'End of loop - '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR hh24:MI:SS'));

            IF NVL (p_send_bl, 'N') = 'Y'
            THEN
                UTL_FILE.fclose (lv_output_file);
                UTL_FILE.frename (src_location    => p_path,
                                  src_filename    => p_file_name || '.tmp',
                                  dest_location   => p_path,
                                  dest_filename   => p_file_name || '.csv',
                                  overwrite       => TRUE);

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before update - '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR hh24:MI:SS'));

                BEGIN
                    -- Commented and added as per CCR0010243

                    --                        UPDATE  apps.ar_cash_receipt_history_all archa
                    --                           SET  archa.attribute1 = 'Y'
                    --                         WHERE  1=1
                    --                           AND  EXISTS (SELECT  1
                    --                                          FROM  xxdo.xxd_ar_rcpt_recon_bl_t stg
                    --                                         WHERE  1 = 1
                    --                                           AND  stg.cash_receipt_history_id = archa.cash_receipt_history_id
                    --                                           AND  stg.request_id = gn_conc_request_id);

                    UPDATE apps.ar_cash_receipt_history_all archa
                       SET archa.attribute1   = 'Y'
                     WHERE     1 = 1
                           AND status <> 'REVERSED'
                           AND archa.cash_receipt_history_id IN
                                   (SELECT stg.cash_receipt_history_id
                                      FROM xxdo.xxd_ar_rcpt_recon_bl_t stg
                                     WHERE     1 = 1
                                           --                                           AND  stg.cash_receipt_history_id = archa.cash_receipt_history_id
                                           AND stg.request_id =
                                               gn_conc_request_id);

                    UPDATE apps.ar_cash_receipt_history_all archa
                       SET archa.attribute1   = 'YY'
                     WHERE     1 = 1
                           AND status = 'REVERSED'
                           AND archa.cash_receipt_history_id IN
                                   (SELECT stg.cash_receipt_history_id
                                      FROM xxdo.xxd_ar_rcpt_recon_bl_t stg
                                     WHERE     1 = 1
                                           --                                           AND  stg.cash_receipt_history_id = archa.cash_receipt_history_id
                                           AND stg.request_id =
                                               gn_conc_request_id);

                    COMMIT;

                    -- End of Change as per CCR0010243

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'After update - '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR hh24:MI:SS'));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error While Updating Cash Receipt History All Table'
                            || SQLERRM);
                END;
            END IF;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                ' Please check the BL flag and Valid directory; Skipping Bursting Program');
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in SUBMIT_BURSTING: '
                || SUBSTR (SQLERRM, 1, 200));
            RETURN TRUE;
    END submit_bursting_fnc;
END XXD_AR_RCPT_RECON_BL_PKG;
/
