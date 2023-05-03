--
-- XXD_CE_CASHFLOW_STMT_EXT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_CE_CASHFLOW_STMT_EXT_PKG" -- XXD_CE_CASHFLOW_STMT_EXT_PKG
AS
    /*************************************************************************************
   * Package         : XXD_CE_CASHFLOW_STMT_EXT_PKG
   * Description     : This package is used for Cashflow Statements Error Report
   * Notes           :
   * Modification    :
   *-------------------------------------------------------------------------------------
   * Date         Version#      Name                       Description
   *-------------------------------------------------------------------------------------
   * 17-AUG-2020  1.0           Aravind Kannuri            Initial Version for CCR0008759
   * 07-JUL-2021  2.0           Srinath Siricilla          CCR0009433
   * 13-JUN-2022  2.1           Aravind Kannuri            CCR0010032
   ***************************************************************************************/

    gn_conc_request_id   NUMBER := fnd_global.conc_request_id;
    gn_user_id           NUMBER := fnd_global.user_id;
    gn_login_id          NUMBER := fnd_global.login_id;

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, MESSAGE);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN;
    END msg;

    -- Start of Change for CCR0009433

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
        lv_msg        VARCHAR2 (4000);
    BEGIN
        --Issue not displaying all banks so Added trunc for dates(statement\creation\gl_date) as part of v2.1
        lv_sql_stmt   :=
               'INSERT INTO xxdo.xxd_ce_cashflow_stmt_ext_t  (
                            SELECT
				cba.bank_account_num,
				csh.statement_number,
				cc.cashflow_id,
				cc.cashflow_direction,
				cc.cashflow_currency_code,
				TO_CHAR (cc.cashflow_date, ''DD/MM/YYYY HH24:MI:SS''),
				cc.cashflow_amount,
				cc.description,
				csl.line_number,
				lkp.meaning,
				csl.trx_code,
				csl.bank_trx_number,
				TO_CHAR (csl.trx_date, ''DD/MM/YYYY HH24:MI:SS''),
				TO_CHAR (csl.effective_date, ''DD/MM/YYYY HH24:MI:SS''),
				csl.amount,
				csl.status,
				csl.currency_code,
				csl.exchange_rate_type,
				csl.exchange_rate,
				csl.exchange_rate_date,
				csl.customer_text,
				csl.bank_account_text,
				csl.invoice_text,
				csl.trx_text,
				--Rererence fields
				csh.bank_account_id,
				csh.statement_header_id,
				csl.statement_line_id,
				cc.cashflow_id,
				csl.trx_code_id,
				csh.statement_date,
				csh.creation_date,
				csh.gl_date,
				cba.account_owner_org_id,
				'
            || ''''
            || SYSDATE
            || ''''
            || '   last_update_date,
                '
            || gn_user_id
            || ' last_updated_by,
                '
            || ''''
            || SYSDATE
            || ''''
            || ' creation_date,
                '
            || gn_user_id
            || ' created_by,
                '
            || gn_login_id
            || ' last_update_login,
                '
            || gn_conc_request_id
            || ' request_id
			FROM
				ce_cashflows           cc,
				ce_cashflow_acct_h     ccah,
				ce_statement_headers   csh,
				ce_statement_lines     csl,
				ce_bank_accounts       cba,
				ce_lookups             lkp
			WHERE
				1 = 1
				AND cc.cashflow_id = ccah.cashflow_id
				AND cc.cashflow_id = csl.cashflow_id
				AND cc.statement_line_id = csl.statement_line_id
				AND csl.statement_header_id = csh.statement_header_id
				AND csh.bank_account_id = cba.bank_account_id
				AND SYSDATE BETWEEN NVL(cba.start_date,SYSDATE) 
									AND NVL(cba.end_date,SYSDATE)
				--AND cc.cashflow_status_code = ''RECONCILED''
				AND ccah.status_code = ''ACCOUNTED''
				AND ccah.current_record_flag = ''Y''
				AND cba.bank_account_id = NVL('
            || ''''
            || p_bank_acct_num
            || ''''
            || ', cba.bank_account_id)		
                --Exclusion of Bank Account Number which exists in VS		
				AND NOT EXISTS (
					SELECT to_number(flv.attribute1)
                        FROM
                            apps.fnd_flex_value_sets   fs,
                            apps.fnd_flex_values_vl    flv
                        WHERE
                            fs.flex_value_set_id = flv.flex_value_set_id
                            AND to_number(flv.attribute1) = cba.bank_account_id   
                            AND fs.flex_value_set_name = ''XXD_CE_CASHFLW_X_BANK_ACCTS_VS''
                AND flv.enabled_flag = ''Y''
                AND flv.summary_flag = ''N''
               --AND TO_NUMBER (flv.attribute2) = cba.account_owner_org_id    
               AND trunc(SYSDATE) BETWEEN nvl(flv.start_date_active, trunc(SYSDATE)) 
														AND nvl(flv.end_date_active, trunc(SYSDATE)))
				--Picking lastest CF History ID based on Parameter Baseline_Sent and Update_CF_History_ID
				AND ((NVL('
            || ''''
            || p_update_criteria_id
            || ''''
            || ',''N'') = ''Y'' AND 1=1)
                     OR  (NVL('
            || ''''
            || p_update_criteria_id
            || ''''
            || ',''N'') = ''N''
                            AND NOT EXISTS (SELECT  1
                                              FROM  xxdo.xxd_ce_cashflow_data_t ccd
                                             WHERE  ccd.cashflow_id = cc.cashflow_id)
--                            AND cc.cashflow_id > (SELECT MAX (cashflow_id)
--                                                FROM xxdo.xxd_ce_cashflow_data_t) 
							AND NVL('
            || ''''
            || p_offset_days
            || ''''
            || ',1) = 1
						  )
					  OR  (NVL('
            || ''''
            || p_update_criteria_id
            || ''''
            || ',''N'') = ''N''
							AND nvl(trunc(csh.creation_date), SYSDATE) > TRUNC(SYSDATE -NVL('
            || ''''
            || p_offset_days
            || ''''
            || ',1))
							AND NVL('
            || ''''
            || p_offset_days
            || ''''
            || ',1) > 1
							AND NOT EXISTS (SELECT  1
                                              FROM  xxdo.xxd_ce_cashflow_data_t ccd
                                             WHERE  ccd.cashflow_id = cc.cashflow_id)
						  )	  
                    )
			AND nvl(trunc(csh.statement_date), SYSDATE)>= nvl(trunc(fnd_date.canonical_to_date('
            || ''''
            || p_stmt_dt_from
            || ''''
            || ')),nvl(trunc(csh.statement_date), SYSDATE ))
			AND nvl(trunc(csh.statement_date), SYSDATE)<= nvl(trunc(fnd_date.canonical_to_date('
            || ''''
            || p_stmt_dt_to
            || ''''
            || ')),nvl(trunc(csh.statement_date), SYSDATE ))
		    AND nvl(trunc(csh.creation_date), SYSDATE) >= nvl(trunc(fnd_date.canonical_to_date('
            || ''''
            || p_cr_dt_from
            || ''''
            || ')),nvl(trunc(csh.creation_date), SYSDATE ))
			AND nvl(trunc(csh.creation_date), SYSDATE) <= nvl(trunc(fnd_date.canonical_to_date('
            || ''''
            || p_cr_dt_to
            || ''''
            || ')),nvl(trunc(csh.creation_date), SYSDATE ))
			AND trunc(csh.gl_date) = nvl(trunc(fnd_date.canonical_to_date ( '
            || ''''
            || p_gl_date
            || ''''
            || ')),nvl(trunc(csh.gl_date), SYSDATE ))
		    AND lkp.lookup_code = csl.trx_type
			AND lkp.lookup_type = ''BANK_TRX_TYPE'')';

        --msg (lv_sql_stmt);

        fnd_file.put_line (fnd_file.LOG, lv_sql_stmt);

        DBMS_OUTPUT.put_line (lv_sql_stmt);

        EXECUTE IMMEDIATE lv_sql_stmt;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   := SQLERRM;
            msg ('Exception in insert_data: ' || lv_msg);
    END MAIN;

    --- End of Change as per CCR0009433

    ----------------------------------------
    --Validate Parameters to pass in Package
    ----------------------------------------
    FUNCTION before_report
        RETURN BOOLEAN
    IS
        lb_result   BOOLEAN;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Calling function- before_report');

        IF (p_blackline_sent = 'N' OR p_blackline_path IS NULL)
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Either Blackline_Sent is ''No'' OR Blackline Path is Null, Skipped to send mail');
        END IF;

        --calling insert_data to insert eligible records into staging table

        MAIN;                                       -- Added as per CCR0009433

        --COMMIT;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exp- Error in before_report :' || SQLERRM);
            RETURN FALSE;
    END before_report;

    ----------------------
    --Fetch Directory File Path from Backline Path
    ----------------------
    FUNCTION directory_path
        RETURN VARCHAR2
    IS
        lv_dir_path   dba_directories.directory_path%TYPE; -- Added as per CCR0009433
    BEGIN
        lv_dir_path   := NULL;                      -- Added as per CCR0009433

        -- Now param p_file_path is coming with complete path in parameter 'p_blackline_path'. validate and return the same
        IF (p_blackline_sent = 'Y' AND p_blackline_path IS NOT NULL)
        THEN
            BEGIN
                SELECT directory_name, directory_path
                  INTO p_file_path, lv_dir_path
                  FROM dba_directories
                 WHERE directory_name = TRIM (p_blackline_path);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Provided Backline Path is Invalid\Not Exists - '
                        || lv_dir_path);

                    p_file_path   := NULL;
                    lv_dir_path   := NULL;          -- Added as per CCR0009433
            END;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Validated directory_path - ' || p_file_path);
        RETURN p_file_path;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exp- Error to fetch directory_path :' || SQLERRM);
            p_file_path   := NULL;
            RETURN p_file_path;
    END directory_path;

    ------------------
    --Fetch File Name
    ------------------
    FUNCTION file_name
        RETURN VARCHAR2
    IS
    BEGIN
        IF p_file_path IS NOT NULL
        THEN
            p_file_name   :=
                'CE_CF_Statements_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        END IF;

        RETURN p_file_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exp- Error to fetch file_name :' || SQLERRM);
            RETURN NULL;
    END file_name;

    ------------------
    --Fetch Email Id
    ------------------
    FUNCTION get_email_id
        RETURN VARCHAR2
    IS
        lv_email_address   VARCHAR2 (200) := NULL;
    BEGIN
        SELECT LISTAGG (flv.flex_value, ',') WITHIN GROUP (ORDER BY flv.flex_value_set_id)
          INTO lv_email_address
          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl flv
         WHERE     fvs.flex_value_set_id = flv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXD_CE_CASHFLOW_USERS_EMAIL'
               AND SYSDATE BETWEEN NVL (TRUNC (flv.start_date_active),
                                        SYSDATE - 1)
                               AND NVL (TRUNC (flv.end_date_active),
                                        SYSDATE + 1)
               AND flv.enabled_flag = 'Y'
               AND flv.summary_flag = 'N';

        RETURN lv_email_address;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_email_address   := NULL;
            RETURN lv_email_address;
    END get_email_id;

    -----------------------------------------------
    --Fetch Last Run Criteria ID which exists in VS
    -----------------------------------------------
    FUNCTION get_vs_criteria_id
        RETURN NUMBER
    IS
        ln_vs_criteria_id   NUMBER := NULL;
    BEGIN
        SELECT flv.attribute1
          INTO ln_vs_criteria_id
          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl flv
         WHERE     fvs.flex_value_set_id = flv.flex_value_set_id
               AND fvs.flex_value_set_name = 'XXD_CE_LATEST_CASHFLOW_ID_VS'
               AND SYSDATE BETWEEN NVL (TRUNC (flv.start_date_active),
                                        SYSDATE - 1)
                               AND NVL (TRUNC (flv.end_date_active),
                                        SYSDATE + 1)
               AND flv.enabled_flag = 'Y'
               AND flv.attribute1 IS NOT NULL
               AND flv.summary_flag = 'N';

        RETURN ln_vs_criteria_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_vs_criteria_id   := NULL;
            RETURN ln_vs_criteria_id;
    END get_vs_criteria_id;

    ---------------------------------------------
    --Fetch MAX Cashflow ID to update Criteria ID
    ---------------------------------------------
    FUNCTION get_criteria_id
        RETURN NUMBER
    IS
        ln_criteria_id   NUMBER := NULL;
    BEGIN
        IF (p_bank_acct_num IS NOT NULL AND p_blackline_sent = 'Y' AND p_update_criteria_id = 'Y')
        THEN
            --To fetch CF History ID if Bank Account Num is NOT NULL
            BEGIN
                  SELECT MAX (cc.cashflow_id)
                    INTO ln_criteria_id
                    FROM ce_cashflows cc, ce_cashflow_acct_h ccah, ce_statement_headers csh,
                         ce_statement_lines csl, ce_bank_accounts cba, ce_lookups l
                   WHERE     1 = 1
                         AND cc.cashflow_id = ccah.cashflow_id
                         AND cc.cashflow_id = csl.cashflow_id
                         AND cc.statement_line_id = csl.statement_line_id
                         AND csl.statement_header_id = csh.statement_header_id
                         AND csh.bank_account_id = cba.bank_account_id
                         AND SYSDATE BETWEEN NVL (cba.start_date, SYSDATE - 1)
                                         AND NVL (cba.end_date, SYSDATE + 1)
                         AND cc.cashflow_status_code = 'RECONCILED'
                         AND ccah.status_code = 'ACCOUNTED'
                         AND ccah.current_record_flag = 'Y'
                         AND cba.bank_account_id = p_bank_acct_num
                GROUP BY cba.bank_account_num;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_criteria_id   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exp- Error to fetch CF History ID if p_bank_acct_num is NOTNULL :'
                        || SQLERRM);
            END;
        ELSE
            --To fetch CF History ID
            BEGIN
                SELECT MAX (cc.cashflow_id)
                  INTO ln_criteria_id
                  FROM ce_cashflows cc, ce_cashflow_acct_h ccah
                 WHERE     1 = 1
                       AND cc.cashflow_id = ccah.cashflow_id
                       AND cc.cashflow_status_code = 'RECONCILED'
                       AND ccah.status_code = 'ACCOUNTED'
                       AND ccah.current_record_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_criteria_id   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exp- Error to fetch CF History ID :' || SQLERRM);
            END;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'Latest CF History ID is updated in VS : ' || ln_criteria_id);
        RETURN ln_criteria_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_criteria_id   := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                'Exp-Main Error to fetch CF History ID :' || SQLERRM);
            RETURN ln_criteria_id;
    END get_criteria_id;

    --------------------------
    --Bursting Program Extract
    --------------------------
    FUNCTION after_report
        RETURN BOOLEAN
    IS
        --        lb_result           BOOLEAN;
        --        ln_req_id           NUMBER;
        --        ln_req_id1          NUMBER;

        ln_count            NUMBER := 0;
        ln_criteria_id      NUMBER;

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
              FROM xxdo.xxd_ce_cashflow_stmt_ext_t
             WHERE 1 = 1 AND request_id = gn_conc_request_id;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Calling function- after_report');

        --Fetch XML Main Query records count
        BEGIN
            SELECT COUNT (*)
              INTO ln_count
              FROM xxdo.xxd_ce_cashflow_stmt_ext_t
             WHERE request_id = gn_conc_request_id;
        -- End of Change for CCR0009443

        -- Commented for Change CCR0009443

        --              SELECT COUNT (cba.bank_account_num)
        --                INTO ln_count
        --                FROM ce_cashflows        cc,
        --                     ce_cashflow_acct_h  ccah,
        --                     ce_statement_headers csh,
        --                     ce_statement_lines  csl,
        --                     ce_bank_accounts    cba,
        --                     ce_lookups          lkp
        --               WHERE     1 = 1
        --                     AND cc.cashflow_id = ccah.cashflow_id
        --                     AND cc.cashflow_id = csl.cashflow_id
        --                     AND cc.statement_line_id = csl.statement_line_id
        --                     AND csl.statement_header_id = csh.statement_header_id
        --                     AND csh.bank_account_id = cba.bank_account_id
        --                     AND SYSDATE BETWEEN NVL (cba.start_date, SYSDATE)
        --                                     AND NVL (cba.end_date, SYSDATE)
        --                     AND cc.cashflow_status_code = 'RECONCILED'
        --                     AND ccah.status_code = 'ACCOUNTED'
        --                     AND ccah.current_record_flag = 'Y'
        --                     AND cba.bank_account_id =
        --                         NVL (p_bank_acct_num, cba.bank_account_id)
        --                     --Exclusion of Bank Account Number which exists in VS
        --                     AND NOT EXISTS
        --                             (SELECT TO_NUMBER (flv.attribute1)
        --                                FROM apps.fnd_flex_value_sets fs,
        --                                     apps.fnd_flex_values_vl flv
        --                               WHERE     fs.flex_value_set_id =
        --                                         flv.flex_value_set_id
        --                                     AND TO_NUMBER (flv.attribute1) =
        --                                         cba.bank_account_id
        --                                     AND fs.flex_value_set_name =
        --                                         'XXD_CE_CASHFLW_X_BANK_ACCTS_VS'
        --                                     AND NVL (flv.enabled_flag, 'N') = 'Y'
        --                                     AND flv.summary_flag = 'N'
        --                                     --AND TO_NUMBER (flv.attribute2) = cba.account_owner_org_id
        --                                     AND TRUNC (SYSDATE) BETWEEN NVL (
        --                                                                     flv.start_date_active,
        --                                                                     TRUNC (
        --                                                                         SYSDATE))
        --                                                             AND NVL (
        --                                                                     flv.end_date_active,
        --                                                                     TRUNC (
        --                                                                         SYSDATE)))
        --                     --Picking lastest CF History ID based on Parameter Baseline_Sent and Update_CF_History_ID
        --                     AND (   (    NVL (p_blackline_sent, 'N') = 'Y'
        --                              AND NVL (p_update_criteria_id, 'N') = 'Y'
        --                              AND NVL (p_offset_days, 1) = 1
        --                              AND cc.cashflow_id >
        --                                  (NVL (
        --                                       p_criteria_id,
        --                                       (SELECT DISTINCT flv.attribute1
        --                                          FROM apps.fnd_flex_value_sets fs,
        --                                               apps.fnd_flex_values_vl flv
        --                                         WHERE     1 = 1
        --                                               AND fs.flex_value_set_id =
        --                                                   flv.flex_value_set_id
        --                                               AND fs.flex_value_set_name =
        --                                                   'XXD_CE_LATEST_CASHFLOW_ID_VS'
        --                                               AND flv.enabled_flag = 'Y'
        --                                               AND SYSDATE BETWEEN NVL (
        --                                                                       flv.start_date_active,
        --                                                                       SYSDATE)
        --                                                               AND NVL (
        --                                                                       flv.end_date_active,
        --                                                                       SYSDATE)))))
        --                          OR (   (    NVL (p_blackline_sent, 'N') = 'Y'
        --                                  AND NVL (p_update_criteria_id, 'N') = 'Y'
        --                                  AND NVL (p_offset_days, 1) > 1
        --                                  AND cc.cashflow_id >
        --                                      (NVL (
        --                                           p_criteria_id,
        --                                           (SELECT DISTINCT flv.attribute1
        --                                              FROM apps.fnd_flex_value_sets fs,
        --                                                   apps.fnd_flex_values_vl flv
        --                                             WHERE     1 = 1
        --                                                   AND fs.flex_value_set_id =
        --                                                       flv.flex_value_set_id
        --                                                   AND fs.flex_value_set_name =
        --                                                       'XXD_CE_LATEST_CASHFLOW_ID_VS'
        --                                                   AND flv.enabled_flag = 'Y'
        --                                                   AND SYSDATE BETWEEN NVL (
        --                                                                           flv.start_date_active,
        --                                                                           SYSDATE)
        --                                                                   AND NVL (
        --                                                                           flv.end_date_active,
        --                                                                           SYSDATE)))))
        --                              OR NVL (TRUNC (csh.creation_date), SYSDATE) >
        --                                 TRUNC (SYSDATE - NVL (p_offset_days, 1)))
        --                          OR (    (   NVL (p_blackline_sent, 'N') = 'N'
        --                                   OR NVL (p_update_criteria_id, 'N') = 'N')
        --                              AND cc.cashflow_id >
        --                                  (NVL (
        --                                       p_criteria_id,
        --                                       (SELECT DISTINCT flv.attribute1
        --                                          FROM apps.fnd_flex_value_sets fs,
        --                                               apps.fnd_flex_values_vl flv
        --                                         WHERE     1 = 1
        --                                               AND fs.flex_value_set_id =
        --                                                   flv.flex_value_set_id
        --                                               AND fs.flex_value_set_name =
        --                                                   'XXD_CE_LATEST_CASHFLOW_ID_VS'
        --                                               AND flv.enabled_flag = 'Y'
        --                                               AND SYSDATE BETWEEN NVL (
        --                                                                       flv.start_date_active,
        --                                                                       SYSDATE)
        --                                                               AND NVL (
        --                                                                       flv.end_date_active,
        --                                                                       SYSDATE))))
        --                              AND 1 = 1))
        --                     AND NVL (TRUNC (csh.statement_date), SYSDATE) >=
        --                         NVL (fnd_date.canonical_to_date (p_stmt_dt_from),
        --                              NVL (TRUNC (csh.statement_date), SYSDATE))
        --                     AND NVL (TRUNC (csh.statement_date), SYSDATE) <=
        --                         NVL (fnd_date.canonical_to_date (p_stmt_dt_to),
        --                              NVL (TRUNC (csh.statement_date), SYSDATE))
        --                     AND NVL (TRUNC (csh.creation_date), SYSDATE) >=
        --                         NVL (fnd_date.canonical_to_date (p_cr_dt_from),
        --                              NVL (TRUNC (csh.creation_date), SYSDATE))
        --                     AND NVL (TRUNC (csh.creation_date), SYSDATE) <=
        --                         NVL (fnd_date.canonical_to_date (p_cr_dt_to),
        --                              NVL (TRUNC (csh.creation_date), SYSDATE))
        --                     AND csh.gl_date =
        --                         NVL (fnd_date.canonical_to_date (p_gl_date),
        --                              NVL (TRUNC (csh.gl_date), SYSDATE))
        --                     AND lkp.lookup_code = csl.trx_type
        --                     AND lkp.lookup_type = 'BANK_TRX_TYPE'
        --            ORDER BY cba.bank_account_num, csh.statement_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_count   := 0;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exp- Error to fetch XML Main Query records count :'
                    || SQLERRM);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'XML Main Query- Fetch Records Count :' || ln_count);

        IF (p_blackline_sent = 'Y' --AND p_update_criteria_id = 'Y'
                                   AND p_file_path IS NOT NULL)
        THEN
            --Fetch Latest Cashflow ID
            --ln_criteria_id := get_criteria_id; -- Commented as per CCR0009433

            --IF (ln_criteria_id IS NOT NULL AND NVL (ln_count, 0) > 0)
            --THEN

            -- Start of Change for CCR0009443

            IF NVL (ln_count, 0) > 0
            THEN
                lv_delimiter   := '|';
                lv_ver         :=
                       'Bank Account Number'
                    || lv_delimiter
                    || 'Statement Number'
                    || lv_delimiter
                    || 'Cashflow Number'
                    || lv_delimiter
                    || 'Cashflow Direction'
                    || lv_delimiter
                    || 'Cashflow Currency Code'
                    || lv_delimiter
                    || 'Cashflow Date'
                    || lv_delimiter
                    || 'Cashflow Amount'
                    || lv_delimiter
                    || 'Cashflow Description'
                    || lv_delimiter
                    || 'Line Number'
                    || lv_delimiter
                    || 'Meaning'
                    || lv_delimiter
                    || 'Trx Code'
                    || lv_delimiter
                    || 'Bank Trx Number'
                    || lv_delimiter
                    || 'Trx Date'
                    || lv_delimiter
                    || 'Value Date'
                    || lv_delimiter
                    || 'Amount'
                    || lv_delimiter
                    || 'Status'
                    || lv_delimiter
                    || 'Currency Code'
                    || lv_delimiter
                    || 'Exchange Rate Type'
                    || lv_delimiter
                    || 'Exchange Rate'
                    || lv_delimiter
                    || 'Exchange Rate Date'
                    || lv_delimiter
                    || 'Agent'
                    || lv_delimiter
                    || 'Agent Bank Account'
                    || lv_delimiter
                    || 'Invoice'
                    || lv_delimiter
                    || 'Trx Text';

                --Writing into a file
                IF NVL (p_blackline_sent, 'N') = 'Y'
                THEN
                    lv_output_file   :=
                        UTL_FILE.fopen (p_file_path, p_file_name || '.tmp', 'W' --opening the file in write mode
                                        , 32767);

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
                        lv_delimiter   := '|';
                        lv_line        :=
                               remove_junk (i.bank_account_num)
                            || lv_delimiter
                            || remove_junk (i.statement_number)
                            || lv_delimiter
                            || remove_junk (i.cashflow_number)
                            || lv_delimiter
                            || remove_junk (i.cashflow_direction)
                            || lv_delimiter
                            || remove_junk (i.cashflow_currency_code)
                            || lv_delimiter
                            || remove_junk (i.cashflow_date)
                            || lv_delimiter
                            || remove_junk (i.cashflow_amount)
                            || lv_delimiter
                            || remove_junk (i.cashflow_description)
                            || lv_delimiter
                            || remove_junk (i.line_number)
                            || lv_delimiter
                            || remove_junk (i.meaning)
                            || lv_delimiter
                            || remove_junk (i.trx_code)
                            || lv_delimiter
                            || remove_junk (i.bank_trx_number)
                            || lv_delimiter
                            || remove_junk (i.trx_date)
                            || lv_delimiter
                            || remove_junk (i.value_date)
                            || lv_delimiter
                            || remove_junk (i.amount)
                            || lv_delimiter
                            || remove_junk (i.status)
                            || lv_delimiter
                            || remove_junk (i.currency_code)
                            || lv_delimiter
                            || remove_junk (i.exchange_rate_type)
                            || lv_delimiter
                            || remove_junk (i.exchange_rate)
                            || lv_delimiter
                            || remove_junk (i.exchange_rate_date)
                            || lv_delimiter
                            || remove_junk (i.agent)
                            || lv_delimiter
                            || remove_junk (i.agent_bank_account)
                            || lv_delimiter
                            || remove_junk (i.invoice)
                            || lv_delimiter
                            || remove_junk (i.trx_text);

                        IF NVL (p_blackline_sent, 'N') = 'Y'
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
                            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM || 'Account Number :' || i.bank_account_num
                                                       , l_debug_level => 1);
                    END;
                END LOOP;

                IF NVL (p_blackline_sent, 'N') = 'Y'
                THEN
                    UTL_FILE.fclose (lv_output_file);
                    UTL_FILE.frename (
                        src_location    => p_file_path,
                        src_filename    => p_file_name || '.tmp',
                        dest_location   => p_file_path,
                        dest_filename   => p_file_name || '.csv',
                        overwrite       => TRUE);

                    BEGIN
                        INSERT INTO xxdo.xxd_ce_cashflow_data_t
                            (SELECT cashflow_id, request_id, w_creation_date,
                                    w_created_by, w_last_update_date, w_last_updated_by
                               FROM xxdo.xxd_ce_cashflow_stmt_ext_t
                              WHERE request_id = gn_conc_request_id);

                        --Update Latest Cashflow Id
                        --                        UPDATE apps.fnd_flex_values_vl    flv
                        --                            SET flv.attribute1 = ln_criteria_id
                        --                            WHERE 1 = 1
                        --                                AND flv.flex_value_set_id IN
                        --                                        (SELECT flex_value_set_id
                        --                                            FROM apps.fnd_flex_value_sets
                        --                                            WHERE flex_value_set_name = 'XXD_CE_LATEST_CASHFLOW_ID_VS')
                        --                                AND flv.enabled_flag = 'Y'
                        --                                AND SYSDATE BETWEEN nvl(flv.start_date_active, SYSDATE - 1)
                        --                                                AND nvl(flv.end_date_active, SYSDATE + 1);

                        COMMIT;
                    --                        fnd_file.put_line (fnd_file.LOG, 'Valueset updated - Criteria ID =>' || ln_criteria_id );

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error While Inserting data into table -  xxdo.xxd_ce_cashflow_data_t'
                                || SQLERRM);
                    END;
                END IF;

                -- Commented for Change CCR0009433

                /*
                 --    --Calling Bursting Program
                 --    ln_req_id :=
                 --      fnd_request.submit_request
                 --         (
                 --         application  => 'XDO',
                 --         program      => 'XDOBURSTREP',
                 --         description  => 'Bursting - Placing '||p_file_name||' under '||p_file_path,
                 --         start_time   => SYSDATE,
                 --         sub_request  => FALSE,
                 --         argument1    => 'Y',
                 --         argument2    => fnd_global.conc_request_id,
                 --         argument3    => 'Y'
                 --           );
 --                ln_req_id1 :=
 --                    fnd_request.submit_request (
 --                        application   => 'XXDO',
 --                        program       => 'XXD_CE_CASHFLOW_UPD_VS',
 --                        description   => 'Deckers CE Cashflow Statement Update ValueSet',
 --                        argument1     => 'CE',
 --                        argument2     => ln_req_id,
 --                        argument3     => ln_criteria_id); */
                COMMIT;
                RETURN TRUE;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No Records fetch in XML Main Query, Skipped Bursting Program');
                RETURN TRUE;
            END IF;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Parameter Blackline\Update Criteria ID is Invalid, Skipped Bursting Program');
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

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_PATH: File location or filename was invalid.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_MODE: The open_mode parameter in FOPEN was invalid.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_FILEHANDLE: The file handle was invalid.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_OPERATION: The file could not be opened or operated on as requested.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'READ_ERROR: An operating system error occurred during the read operation.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'WRITE_ERROR: An operating system error occurred during the write operation.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'INTERNAL_ERROR: An unspecified error in PL/SQL.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_FILENAME: The filename parameter is invalid.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN ex_no_data_found
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'There is no data for the specified month.'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN ex_no_recips
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN ex_no_sender
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , l_debug_level => 1);
            RETURN FALSE;
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_CE_CASHFLOW_STMT_EXT_PKG.MAIN', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , l_debug_level => 1);

            RETURN FALSE;
    -- End of Change for CCR0009433

    END after_report;
END XXD_CE_CASHFLOW_STMT_EXT_PKG;
/
