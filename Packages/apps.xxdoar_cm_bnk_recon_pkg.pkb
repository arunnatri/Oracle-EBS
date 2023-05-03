--
-- XXDOAR_CM_BNK_RECON_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAR_CM_BNK_RECON_PKG"
AS
    /*******************************************************************************
      * Program Name : XXDOAR_CM_BNK_RECON_PKG
      * Language     : PL/SQL
      * Description  : This package will update bank statement data in interface table from Receipts.
      *
      * History      :
      * Vsn     Change Date   Changed By            Change Description
      * -----   -----------   ------------------    ------------------------------------
      * 1.0     02-SEP-2016   Infosys Team          Initial Creation
      * 2.0     08-NOV-2018   Srinath Siricilla     Updated Program parameters as part
      *                                             of CCR0007490
      * 2.1     20-Aug-2019   Kranthi Bollam        CCR0008128 - Cash Management -
      *                                             Transactions not reconciling
      *                                             automatically.
      *
      * WHO                  VERSION  DESCRIPTION                         WHEN
      * ------------------------------------------------------------------------------------
      * Infosys Team         1.0      Initial Creation                    02-SEP-2016
      * Srinath Siricilla    2.0      Updated Program parameters as part  08-NOV-2018
      *                               of CCR0007490
      * Kranthi Bollam       2.1      CCR0008128 - Cash Management -      20-AUG-2019
      *                               Transactions not reconciling
      *                               automatically
      * Jayarajan A K        2.2      CCR0008730 - Cash Management -      09-DEC-2020
      *                               Transactions not matching
   *                               automatically
      * --------------------------------------------------------------------------- */


    g_num_user_id         NUMBER := fnd_global.user_id;
    g_num_login_id        NUMBER := fnd_global.login_id;
    g_dte_current_date    DATE := SYSDATE;
    gn_success   CONSTANT NUMBER := 0;                  --Added for change 2.1
    gn_warning   CONSTANT NUMBER := 1;                  --Added for change 2.1
    gn_error     CONSTANT NUMBER := 2;                  --Added for change 2.1

    --------------------------------------------------------------------------------------------------------------
    -- Procedure  : main
    -- Description: procedure to update bank transaction number in cash management interface table from Receipts.
    --------------------------------------------------------------------------------------------------------------

    -- Commented as part of CCR0007490
    --PROCEDURE main
    --
    --( errbuf      out varchar2
    --, retcode     out varchar2
    --)
    -- End of Change as part of CCR0007490
    PROCEDURE main (errbuf                OUT VARCHAR2,
                    retcode               OUT VARCHAR2,
                    p_bank_account     IN     NUMBER,
                    p_statement_from   IN     VARCHAR2,
                    p_statement_to     IN     VARCHAR2)
    AS
        -- Start of change for CCR0007490
        ------------------------------
        --Local Variable Declaration
        ------------------------------

        ln_count              NUMBER := 0;
        ln_init_count         NUMBER := 0;
        ln_init_count1        NUMBER := 0;
        ln_eli_count          NUMBER := 0;
        l_unprocessed_count   NUMBER := 0;

        --Changes as part of CCR0007490
        lv_receipt_number     VARCHAR2 (150);

        CURSOR c_bank_accounts IS
              SELECT cba.bank_account_id, cbau.bank_acct_use_id, cba.bank_account_num,
                     cba.bank_id
                FROM apps.ce_bank_accounts cba, ce_bank_acct_uses_all cbau
               WHERE     1 = 1
                     AND cba.bank_account_id = cbau.bank_account_id
                     AND cba.attribute1 = 'YES'
                     AND cba.bank_account_id =
                         NVL (p_bank_account, cba.bank_account_id)
                     AND EXISTS
                             (SELECT 1
                                FROM ce_statement_headers_int cshi
                               WHERE     1 = 1
                                     AND record_status_flag = 'N'
                                     AND cba.bank_account_num =
                                         cshi.bank_account_num
                                     AND statement_date >= SYSDATE - 90)
                     AND EXISTS
                             (SELECT 1
                                FROM AR_RECEIPT_METHOD_ACCOUNTS_all arma
                               WHERE     1 = 1
                                     AND arma.REMIT_BANK_ACCT_USE_ID =
                                         cbau.bank_acct_use_id)
            ORDER BY 1;

        CURSOR c_ce_stm_lines (p_bank_account_num VARCHAR2)
        IS
            SELECT csli.trx_date, csli.amount, csli.trx_code,
                   csli.bank_account_num, csli.statement_number, csli.line_number
              FROM apps.ce_statement_lines_interface csli, apps.ce_statement_headers_int cshi
             WHERE     1 = 1
                   AND cshi.bank_account_num = p_bank_account_num
                   AND NVL (cshi.record_status_flag, 'N') = 'N'
                   AND csli.attribute1 IS NULL
                   AND cshi.statement_number = csli.statement_number
                   AND cshi.bank_account_num = csli.bank_account_num -- Added New
                   AND csli.statement_number BETWEEN NVL (
                                                         p_statement_from,
                                                         csli.statement_number)
                                                 AND NVL (
                                                         p_statement_to,
                                                         csli.statement_number);


        CURSOR c_ar_cash_receipts (p_bank_id            NUMBER,
                                   p_bank_acct_use_id   NUMBER,
                                   p_stmt_number        VARCHAR2,
                                   p_trx_amount         NUMBER,
                                   p_trx_code           VARCHAR2)
        IS
            SELECT arca.receipt_number
              FROM ar_cash_receipts_all arca
             WHERE     1 = 1
                   AND arca.remit_bank_acct_use_id = p_bank_acct_use_id
                   AND arca.receipt_number LIKE '%-%-%'
                   AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                      1) =
                       TO_CHAR (TO_DATE (p_stmt_number, 'YYMMDD'), 'DDMMYY')
                   AND TO_CHAR (REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1
                                               , 2),
                                'FM9G999G999G999G999G999G999G999G990D00PT') =
                       TO_CHAR (p_trx_amount,
                                'FM9G999G999G999G999G999G999G999G990D00PT')
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                             WHERE     ffvs.flex_value_set_name =
                                       'XXD_CE_BAI_MT940_MAPPING_VS'
                                   AND ffvs.flex_Value_Set_id =
                                       ffv.flex_value_set_id
                                   AND p_trx_code = ffv.attribute2
                                   AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1
                                                      , 3) = ffv.attribute4
                                   AND SYSDATE BETWEEN NVL (
                                                           ffv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           ffv.end_date_active,
                                                           SYSDATE)
                                   AND ffv.enabled_flag = 'Y'
                                   AND (   ffv.attribute1 IS NULL
                                        OR ffv.attribute1 =
                                           (SELECT BankOrgProfile.home_country
                                              FROM apps.HZ_CODE_ASSIGNMENTS bankca, apps.HZ_ORGANIZATION_PROFILES BankOrgProfile
                                             WHERE     1 = 1
                                                   AND NVL (
                                                           BankOrgProfile.status,
                                                           'A') =
                                                       'A'
                                                   AND BankCA.CLASS_CATEGORY =
                                                       'BANK_INSTITUTION_TYPE'
                                                   AND BankCA.CLASS_CODE IN
                                                           ('BANK', 'CLEARINGHOUSE')
                                                   AND BankCA.OWNER_TABLE_NAME =
                                                       'HZ_PARTIES'
                                                   AND BankCA.OWNER_TABLE_ID =
                                                       BankOrgProfile.PARTY_ID
                                                   AND NVL (BankCA.STATUS,
                                                            'A') =
                                                       'A' /* 7827889 - Added outer join */
                                                   AND BankOrgProfile.PARTY_ID =
                                                       p_bank_id)));

        ---------------------------------------------------------------
        --Cursor to fetch cash receipts details that are to part of B2B (XXD_CE_BAI_MT940_MAPPING_VS)
        ---------------------------------------------------------------
        --      CURSOR c_b2b_cash_receipts
        --      IS
        --         SELECT csli.trx_date,
        --                csli.amount,
        --                csli.trx_code,
        --                csli.bank_account_num,
        --                csli.statement_number,
        --                arca.receipt_number
        --           --       ,bank_dff.trf_code
        --           FROM apps.CE_STATEMENT_LINES_INTERFACE csli,
        --                apps.CE_STATEMENT_headers_INT cshi,
        --                apps.ce_bank_accounts cba,
        --                ar_cash_receipts_all arca,
        --                ce_bank_acct_uses_all bank_use
        --          WHERE     1 = 1
        --                AND csli.attribute1 IS NULL
        --                AND cba.attribute1 = 'YES'
        --                AND csli.bank_account_num = cba.bank_account_num
        --                AND NVL (cshi.record_status_flag, 'N') = 'N'
        --                AND cshi.statement_number = CSLI.statement_number
        --                AND cshi.bank_account_num = csli.bank_account_num
        --                AND bank_use.bank_account_id = cba.bank_account_id
        --                AND arca.remit_bank_acct_use_id = bank_use.bank_acct_use_id
        --                AND REGEXP_SUBSTR (arca.receipt_number,
        --                                   '[^-]+',
        --                                   1,
        --                                   1) =
        --                       TO_CHAR (TO_DATE (csli.statement_number, 'YYMMDD'),
        --                                'DDMMYY')
        --                AND REGEXP_SUBSTR (arca.receipt_number,
        --                                   '[^-]+',
        --                                   1,
        --                                   2) = TO_CHAR (csli.amount)
        --                AND cba.bank_account_id =
        --                       NVL (p_bank_account, cba.bank_account_id)  -- Added New
        --                AND csli.statement_number BETWEEN NVL (p_statement_from,
        --                                                       csli.statement_number)
        --                                              AND NVL (p_statement_to,
        --                                                       csli.statement_number) -- Added new
        --                AND EXISTS
        --                       (SELECT 1
        --                          FROM apps.fnd_flex_value_sets ffvs,
        --                               apps.fnd_flex_values ffv
        --                         WHERE     ffvs.flex_value_set_name =
        --                                      'XXD_CE_BAI_MT940_MAPPING_VS'
        --                               AND ffvs.flex_Value_Set_id =
        --                                      ffv.flex_value_set_id
        --                               AND csli.trx_code = ffv.attribute2
        --                               AND REGEXP_SUBSTR (arca.receipt_number,
        --                                                  '[^-]+',
        --                                                  1,
        --                                                  3) = ffv.attribute4
        --                               AND SYSDATE BETWEEN NVL (
        --                                                      ffv.start_date_active,
        --                                                      SYSDATE)
        --                                               AND NVL (ffv.end_date_active,
        --                                                        SYSDATE)
        --                               AND ffv.enabled_flag = 'Y'
        --                               AND (   ffv.attribute1 IS NULL
        --                                    OR ffv.attribute1 =
        --                                          (SELECT BankOrgProfile.home_country
        --                                             FROM apps.HZ_CODE_ASSIGNMENTS bankca,
        --                                                  apps.HZ_ORGANIZATION_PROFILES BankOrgProfile
        --                                            WHERE     1 = 1
        --                                                  AND NVL (
        --                                                         BankOrgProfile.status,
        --                                                         'A') = 'A'
        --                                                  AND BankCA.CLASS_CATEGORY =
        --                                                         'BANK_INSTITUTION_TYPE'
        --                                                  AND BankCA.CLASS_CODE IN ('BANK',
        --                                                                            'CLEARINGHOUSE')
        --                                                  AND BankCA.OWNER_TABLE_NAME =
        --                                                         'HZ_PARTIES'
        --                                                  AND BankCA.OWNER_TABLE_ID =
        --                                                         BankOrgProfile.PARTY_ID
        --                                                  AND NVL (BankCA.STATUS,
        --                                                           'A') = 'A' /* 7827889 - Added outer join */
        --                                                  AND BankOrgProfile.PARTY_ID =
        --                                                         cba.bank_id)));

        -- End of change for CCR0007490

        CURSOR bank_cur IS
              SELECT cba.bank_account_id bank_account_id, remit_bank_acct_use_id remit_bank_acct_use_id, cba.bank_account_num bank_account_num
                FROM apps.ar_cash_receipts_all acra, apps.ce_bank_acct_uses_all bank_use, apps.ce_bank_accounts cba
               WHERE     1 = 1
                     AND bank_use.bank_account_id = cba.bank_account_id
                     AND acra.remit_bank_acct_use_id =
                         bank_use.bank_acct_use_id
                     AND cba.attribute1 = 'YES'
                     AND cba.bank_account_id =
                         NVL (p_bank_account, cba.bank_account_id) -- Added New
                     --added by ANM
                     AND EXISTS
                             (SELECT 1
                                FROM AR_RECEIPT_METHOD_ACCOUNTS_all arma
                               WHERE     1 = 1
                                     AND arma.REMIT_BANK_ACCT_USE_ID =
                                         bank_use.bank_acct_use_id)
            --   AND  csli.statement_number BETWEEN NVL(p_statement_from,csli.statement_number) AND NVL (p_statement_to,csli.statement_number) -- Added new
            GROUP BY cba.bank_account_id, remit_bank_acct_use_id, cba.bank_account_num;

        CURSOR display_cur (p_acct_site_id       IN NUMBER,
                            p_bank_account_num   IN VARCHAR2)
        IS
              SELECT REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                    3) swift_code,
                     csli.trx_code,
                     csli.bank_account_num,
                     COUNT (1) total
                FROM ar_cash_receipts_all arca, ce_statement_lines_interface csli, apps.ce_statement_headers_int csh
               WHERE     1 = 1
                     AND arca.remit_bank_acct_use_id = p_acct_site_id
                     AND csli.BANK_ACCOUNT_NUM = p_bank_account_num --'270599533001'
                     AND csh.statement_number = csli.statement_number
                     AND csh.bank_account_num = csli.bank_account_num
                     AND NVL (CSH.record_status_flag, 'N') = 'N'
                     AND csli.attribute1 IS NULL
                     --    and cba.bank_account_id = NVL(p_bank_account, cba.bank_account_id) -- Added New
                     AND csli.statement_number BETWEEN NVL (
                                                           p_statement_from,
                                                           csli.statement_number)
                                                   AND NVL (
                                                           p_statement_to,
                                                           csli.statement_number) -- Added new
                     AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                        1) =
                         TO_CHAR (TO_DATE (csli.statement_number, 'YYMMDD'),
                                  'DDMMYY')
                     AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                        2) = TO_CHAR (csli.amount)
                     AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                        3) IN
                             (SELECT DISTINCT CreditIdentifier3
                                FROM XXDO.XXDOAR_B2B_CASHAPP_STG)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                               WHERE     ffvs.flex_value_set_name =
                                         'XXD_CE_BAI_MT940_MAPPING_VS'
                                     AND ffvs.flex_Value_Set_id =
                                         ffv.flex_value_set_id
                                     AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1
                                                        , 3) = ffv.attribute4
                                     AND csli.trx_code = ffv.attribute2)
                     AND arca.creation_date > csli.trx_date - 4
            GROUP BY REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                    3),
                     csli.trx_code,
                     csli.bank_account_num;

        ---------------------------------------------------------------
        --Cursor to fetch cash receipts details
        ---------------------------------------------------------------
        CURSOR c_get_cash_receipts IS
              SELECT csli.trx_date, csli.amount, csli.trx_code,
                     csli.bank_account_num
                FROM CE_STATEMENT_LINES_INTERFACE CSLI,
                     apps.ce_bank_accounts cba,
                     (SELECT ffv.flex_value Bank_account_num
                        FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                       WHERE     ffvs.flex_value_set_name =
                                 'XXDO_AR_CE_BANK_RECIEPT_AUTORECON'
                             AND ffvs.flex_Value_Set_id = ffv.flex_value_set_id
                             AND ffv.enabled_flag = 'Y') Bank_account,
                     (SELECT ffv.flex_value trx_code
                        FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                       WHERE     ffvs.flex_value_set_name =
                                 'XXDO_AR_CE_TRXCODE_RECIEPT_AUTORECON'
                             AND ffvs.flex_Value_Set_id = ffv.flex_value_set_id
                             AND ffv.enabled_flag = 'Y') trx_code
               WHERE     csli.attribute1 IS NULL
                     AND csli.bank_account_num = bank_account.bank_account_num
                     AND csli.bank_account_num = cba.bank_account_num
                     AND csli.trx_code = trx_code.trx_code
                     AND cba.bank_account_id =
                         NVL (p_bank_account, cba.bank_account_id) -- Added New
                     AND csli.statement_number BETWEEN NVL (
                                                           p_statement_from,
                                                           csli.statement_number)
                                                   AND NVL (
                                                           p_statement_to,
                                                           csli.statement_number) -- Added new
            ORDER BY statement_number, line_number ASC;
    ---------------
    --Begin Block
    ---------------
    BEGIN
        -- Loop for count of eligiblie records for processing
        fnd_file.put_line (
            fnd_file.output,
            '                                                                                                                                ');
        fnd_file.put_line (
            fnd_file.output,
            '                               Transactions which needs mapping                                                                 ');
        fnd_file.put_line (
            fnd_file.output,
            '******************************************************************************************************************************* ');
        fnd_file.put_line (
            fnd_file.output,
               'Bank Account Number           '
            || CHR (9)
            || 'Swift Code                    '
            || CHR (9)
            || 'Transaction Code              '
            || CHR (9)
            || 'No. of Unprocessed Records    ');
        fnd_file.put_line (
            fnd_file.output,
            '******************************************************************************************************************************* ');
        fnd_file.put_line (
            fnd_file.output,
            '                                                                                                                                ');

        FOR rec IN c_bank_accounts
        LOOP
            FOR j IN display_cur (rec.bank_acct_use_id, rec.bank_account_num)
            LOOP
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (j.bank_account_num, 30)
                    || CHR (9)
                    || RPAD (j.swift_code, 30)
                    || CHR (9)
                    || RPAD (j.trx_code, 30)
                    || CHR (9)
                    || LPAD (j.total, 30));
            END LOOP;
        END LOOP;

        fnd_file.put_line (
            fnd_file.output,
            '                                                                                                                                ');
        fnd_file.put_line (
            fnd_file.output,
            '                               Summary Report                                                                 ');
        fnd_file.put_line (
            fnd_file.output,
            '******************************************************************************************************************************* ');
        fnd_file.put_line (
            fnd_file.output,
               'Bank Account Number           '
            || CHR (9)
            || 'Eligible Records              '
            || CHR (9)
            || 'Processed Records             '
            || CHR (9)
            || 'Unprocessed Records           ');
        fnd_file.put_line (
            fnd_file.output,
            '******************************************************************************************************************************* ');
        fnd_file.put_line (
            fnd_file.output,
            '                                                                                                                                ');

        FOR rec IN c_bank_accounts
        LOOP
            ln_eli_count          := 0;
            ln_init_count         := 0;
            ln_init_count1        := 0;



            SELECT COUNT (*)
              INTO ln_eli_count
              FROM apps.ce_statement_lines_interface csli, apps.ce_statement_headers_int cshi
             WHERE     csli.statement_number = cshi.statement_number
                   AND cshi.bank_account_num = csli.bank_account_num
                   AND NVL (cshi.record_status_flag, 'N') = 'N'
                   AND cshi.bank_account_num = rec.bank_account_num
                   AND csli.attribute1 IS NULL;


            -- Start of change as part of CCR0007490
            ------------------------------------------------------------------------------------------------------------
            --Loop for each receipts and cash management related data to check and update bank transaction number
            ------------------------------------------------------------------------------------------------------------
            FOR upd_cash_receipts IN c_ce_stm_lines (rec.bank_account_num)
            LOOP
                ln_init_count1      := 0;
                lv_receipt_number   := NULL;

                IF c_ar_cash_receipts%ISOPEN
                THEN
                    CLOSE c_ar_cash_receipts;
                END IF;

                OPEN c_ar_cash_receipts (rec.bank_id,
                                         rec.bank_acct_use_id,
                                         upd_cash_receipts.statement_number,
                                         upd_cash_receipts.amount,
                                         upd_cash_receipts.trx_code);

                FETCH c_ar_cash_receipts INTO lv_receipt_number;

                CLOSE c_ar_cash_receipts;

                --            fnd_file.put_line (fnd_file.LOG,
                --                               'lv_receipt_number - ' || lv_receipt_number);

                IF NVL (lv_receipt_number, '-999') != '-999'
                THEN
                    BEGIN
                        UPDATE CE_STATEMENT_LINES_INTERFACE csli
                           SET attribute1 = NVL (bank_trx_number, 'No Value'), --     bank_trx_number = to_char(upd_cash_receipts.trx_date,'ddmmyy')||'-'||trim(to_char(upd_cash_receipts.amount,'999999999990.99'))||'-'||trim(upd_cash_receipts.trf_code),
                                                                               --                   bank_trx_number = upd_cash_receipts.receipt_number,
                                                                               bank_trx_number = lv_receipt_number, last_update_date = SYSDATE,
                               last_updated_by = g_num_user_id
                         WHERE     trx_date = upd_cash_receipts.trx_date
                               AND amount = upd_cash_receipts.amount
                               AND trx_code = upd_cash_receipts.trx_code
                               AND bank_account_num =
                                   upd_cash_receipts.bank_account_num
                               AND csli.statement_number =
                                   upd_cash_receipts.statement_number
                               AND csli.line_number =
                                   upd_cash_receipts.line_number;

                        ln_init_count1   := SQL%ROWCOUNT;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ROLLBACK;
                    END;
                END IF;

                ln_init_count       := ln_init_count + ln_init_count1;
            --            fnd_file.put_line (fnd_file.LOG,
            --                               'ln_init_count ' || ln_init_count);
            --
            --            fnd_file.put_line (fnd_file.LOG,
            --                               'ln_init_count1 ' || ln_init_count1);
            END LOOP;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Number of Records updated in CE LINES INTERFACE Table for First Loop: '
                || ln_init_count);

            -- End of change as part of CCR0007490


            l_unprocessed_count   := 0;
            l_unprocessed_count   :=
                NVL (ln_eli_count, 0) - NVL (ln_init_count, 0);
            --         fnd_file.put_line (
            --            fnd_file.output,
            --            'For Bank Account Number : ' || rec.bank_account_num);
            --         fnd_file.put_line (
            --            fnd_file.output,
            --            '******************************************************************************************************************************* ');
            --         fnd_file.put_line (
            --            fnd_file.output,
            --               'Number of eligible transactions for Processing : '
            --            || NVL (ln_eli_count, 0));
            --         fnd_file.put_line (
            --            fnd_file.output,
            --            'Number of transactions processed : ' || NVL (ln_init_count, 0));
            --
            --         fnd_file.put_line (
            --            fnd_file.output,
            --            'Number of Unprocessed transactions : ' || l_unprocessed_count);

            fnd_file.put_line (
                fnd_file.output,
                   LPAD (rec.bank_account_num, 30)
                || CHR (9)
                || LPAD (ln_eli_count, 30)
                || CHR (9)
                || LPAD (ln_init_count, 30)
                || CHR (9)
                || LPAD (l_unprocessed_count, 30));
        END LOOP;

        ------------------------------------------------------------------------------------------------------------
        --Loop for each receipts and cash management related data to check and update bank transaction number
        ------------------------------------------------------------------------------------------------------------
        FOR r_get_cash_receipts IN c_get_cash_receipts
        LOOP
            ln_count   := ln_count + 1;

            BEGIN
                UPDATE CE_STATEMENT_LINES_INTERFACE
                   SET attribute1 = bank_trx_number, bank_trx_number = TO_CHAR (r_get_cash_receipts.trx_date, 'ddmmyy') || '-' || TRIM (TO_CHAR (r_get_cash_receipts.amount, '999999999990.99')), last_update_date = SYSDATE,
                       last_updated_by = g_num_user_id
                 WHERE     trx_date = r_get_cash_receipts.trx_date
                       AND attribute1 IS NULL
                       AND amount = r_get_cash_receipts.amount
                       AND trx_code = r_get_cash_receipts.trx_code
                       AND bank_account_num =
                           r_get_cash_receipts.bank_account_num;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
            END;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Number of Records updated in CE LINES INTERFACE Table: '
            || ln_count);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error when updating data' || SQLERRM);
            errbuf    := 'Error when updating data';
            retcode   := 2;
            RETURN;
    END;

    --Added below procedure for change 2.1
    PROCEDURE upd_main (pv_errbuf OUT VARCHAR2, pn_retcode OUT VARCHAR2, pn_bank_account_id IN NUMBER
                        , pv_statement_from IN VARCHAR2, pv_statement_to IN VARCHAR2, pn_offset_days IN NUMBER DEFAULT 7)
    IS
        --Cursors Declaration
        CURSOR c_bank_accounts IS
              SELECT cba.bank_account_id, cbau.bank_acct_use_id, cba.bank_account_num,
                     cba.bank_id
                FROM apps.ce_bank_accounts cba, apps.ce_bank_acct_uses_all cbau
               WHERE     1 = 1
                     AND cba.bank_account_id = cbau.bank_account_id
                     AND cba.attribute1 = 'YES' --Auto-Reconciliation Yes or No
                     AND cba.bank_account_id =
                         NVL (pn_bank_account_id, cba.bank_account_id)
                     --To Check if Bank has UNRECONCILED receipts or not
                     AND EXISTS
                             (SELECT 1
                                FROM apps.ce_statement_headers csh, apps.ce_statement_lines csl
                               WHERE     1 = 1
                                     AND csh.bank_account_id =
                                         cba.bank_account_id
                                     AND csh.statement_header_id =
                                         csl.statement_header_id
                                     AND csl.status = 'UNRECONCILED' --Unreconciled
                                     AND csl.trx_type IN
                                             ('MISC_CREDIT'   --'Misc Receipt'
                                                           , 'CREDIT' --'Receipt'
                                                                     ))
                     --To check receipt method of the Bank exists or not
                     AND EXISTS
                             (SELECT 1
                                FROM apps.ar_receipt_method_accounts_all arma
                               WHERE     1 = 1
                                     AND arma.remit_bank_acct_use_id =
                                         cbau.bank_acct_use_id)
            ORDER BY cba.bank_account_id;

        CURSOR display_cur (cn_bank_acct_use_id   IN NUMBER,
                            cn_bank_account_id    IN NUMBER)
        IS
              SELECT REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                    3) swift_code,
                     csl.trx_code,
                     cba.bank_account_num,
                     COUNT (1) total
                FROM apps.ar_cash_receipts_all arca, apps.ce_statement_headers csh, apps.ce_statement_lines csl,
                     apps.ce_bank_accounts cba
               WHERE     1 = 1
                     AND arca.remit_bank_acct_use_id = cn_bank_acct_use_id
                     AND arca.creation_date > csl.trx_date - pn_offset_days
                     AND csh.statement_header_id = csl.statement_header_id
                     AND csl.status = 'UNRECONCILED'            --Unreconciled
                     AND csl.trx_type IN ('MISC_CREDIT'       --'Misc Receipt'
                                                       , 'CREDIT'  --'Receipt'
                                                                 )
                     AND csh.bank_account_id = cn_bank_account_id
                     AND csh.bank_account_id = cba.bank_account_id
                     AND csh.statement_number BETWEEN NVL (
                                                          pv_statement_from,
                                                          csh.statement_number)
                                                  AND NVL (
                                                          pv_statement_to,
                                                          csh.statement_number)
                     AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                        1) =
                         TO_CHAR (TO_DATE (csh.statement_number, 'YYMMDD'),
                                  'DDMMYY')
                     AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                        2) = TO_CHAR (csl.amount)
                     AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                        3) IN
                             (SELECT DISTINCT CreditIdentifier3
                                FROM xxdo.xxdoar_b2b_cashapp_stg)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                               WHERE     1 = 1
                                     AND ffvs.flex_value_set_name =
                                         'XXD_CE_BAI_MT940_MAPPING_VS'
                                     AND ffvs.flex_value_set_id =
                                         ffv.flex_value_set_id
                                     AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1
                                                        , 3) = ffv.attribute4
                                     AND csl.trx_code = ffv.attribute2)
            GROUP BY REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                    3),
                     csl.trx_code,
                     cba.bank_account_num;

        CURSOR c_ce_stm_lines (cn_bank_account_id IN NUMBER)
        IS
            SELECT csl.trx_date, csl.amount, csl.trx_code,
                   cba.bank_account_id, cba.bank_account_num, csh.statement_number,
                   csH.statement_header_id, csl.statement_line_id, csl.line_number
              FROM apps.ce_statement_headers csh, apps.ce_bank_accounts cba, apps.ce_statement_lines csl
             WHERE     1 = 1
                   AND csh.bank_account_id = cn_bank_account_id
                   AND csh.bank_account_id = cba.bank_account_id
                   AND csh.statement_header_id = csl.statement_header_id
                   AND csl.status = 'UNRECONCILED'              --Unreconciled
                   AND csl.trx_type IN ('MISC_CREDIT'         --'Misc Receipt'
                                                     , 'CREDIT'    --'Receipt'
                                                               )
                   AND csh.statement_number BETWEEN NVL (
                                                        pv_statement_from,
                                                        csh.statement_number)
                                                AND NVL (
                                                        pv_statement_to,
                                                        csh.statement_number);

        CURSOR c_ar_cash_receipts (cn_bank_id NUMBER, cn_bank_account_id NUMBER, cn_bank_acct_use_id NUMBER
                                   , cv_stmt_number VARCHAR2, cn_trx_amount NUMBER, cv_trx_code VARCHAR2)
        IS
            SELECT arca.receipt_number
              FROM apps.ar_cash_receipts_all arca
             WHERE     1 = 1
                   AND arca.remit_bank_acct_use_id = cn_bank_acct_use_id
                   AND arca.receipt_number LIKE '%-%-%'
                   AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1,
                                      1) =
                       TO_CHAR (TO_DATE (cv_stmt_number, 'YYMMDD'), 'DDMMYY')
                   AND TO_CHAR (REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1
                                               , 2),
                                'FM9G999G999G999G999G999G999G999G990D00PT') =
                       TO_CHAR (cn_trx_amount,
                                'FM9G999G999G999G999G999G999G999G990D00PT')
                   --Ignore the receipt number if it is already assigned to a statement line
                   AND NOT EXISTS
                           (SELECT 1
                              FROM ce_statement_headers sh, ce_statement_lines sl
                             WHERE     1 = 1
                                   AND sh.statement_number = cv_stmt_number
                                   AND sh.bank_account_id =
                                       cn_bank_account_id
                                   AND sh.statement_header_id =
                                       sl.statement_header_id
                                   AND sl.bank_trx_number =
                                       arca.receipt_number)
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                             WHERE     1 = 1
                                   AND ffvs.flex_value_set_name =
                                       'XXD_CE_BAI_MT940_MAPPING_VS'
                                   AND ffvs.flex_value_set_id =
                                       ffv.flex_value_set_id
                                   AND cv_trx_code = ffv.attribute2
                                   AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1
                                                      , 3) = ffv.attribute4
                                   AND SYSDATE BETWEEN NVL (
                                                           ffv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           ffv.end_date_active,
                                                           SYSDATE)
                                   AND ffv.enabled_flag = 'Y'
                                   AND (   ffv.attribute1 IS NULL
                                        OR ffv.attribute1 =
                                           (SELECT bankorgprofile.home_country
                                              FROM apps.hz_code_assignments bankca, apps.hz_organization_profiles bankorgprofile
                                             WHERE     1 = 1
                                                   AND NVL (
                                                           bankorgprofile.status,
                                                           'A') =
                                                       'A'
                                                   AND bankca.class_category =
                                                       'BANK_INSTITUTION_TYPE'
                                                   AND bankca.class_code IN
                                                           ('BANK', 'CLEARINGHOUSE')
                                                   AND bankca.owner_table_name =
                                                       'HZ_PARTIES'
                                                   AND bankca.owner_table_id =
                                                       bankorgprofile.party_id
                                                   AND NVL (bankca.status,
                                                            'A') =
                                                       'A'
                                                   AND bankorgprofile.party_id =
                                                       cn_bank_id)));

        ---------------------------------------------------------------
        --Cursor to fetch cash receipts details
        ---------------------------------------------------------------
        CURSOR c_get_cash_receipts IS
              SELECT csl.trx_date, csl.amount, csl.trx_code,
                     cba.bank_account_num, cba.bank_account_id, csh.statement_header_id,
                     csl.statement_line_id
                FROM apps.ce_statement_headers csh,
                     apps.ce_statement_lines csl,
                     apps.ce_bank_accounts cba,
                     (SELECT ffv.flex_value bank_account_num
                        FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                       WHERE     1 = 1
                             AND ffvs.flex_value_set_name =
                                 'XXDO_AR_CE_BANK_RECIEPT_AUTORECON'
                             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                             AND ffv.enabled_flag = 'Y') bank_account,
                     (SELECT ffv.flex_value trx_code
                        FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                       WHERE     1 = 1
                             AND ffvs.flex_value_set_name =
                                 'XXDO_AR_CE_TRXCODE_RECIEPT_AUTORECON'
                             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                             AND ffv.enabled_flag = 'Y') trx_code
               WHERE     1 = 1
                     AND csh.statement_header_id = csl.statement_header_id
                     AND csh.bank_account_id = cba.bank_account_id
                     AND cba.bank_account_id =
                         NVL (pn_bank_account_id, cba.bank_account_id)
                     AND csl.attribute1 IS NULL
                     AND csl.status = 'UNRECONCILED'            --Unreconciled
                     AND csl.trx_type IN ('MISC_CREDIT'       --'Misc Receipt'
                                                       , 'CREDIT'  --'Receipt'
                                                                 )
                     AND csh.statement_number BETWEEN NVL (
                                                          pv_statement_from,
                                                          csh.statement_number)
                                                  AND NVL (
                                                          pv_statement_to,
                                                          csh.statement_number)
                     AND cba.bank_account_num = bank_account.bank_account_num
                     AND csl.trx_code = trx_code.trx_code
            ORDER BY statement_number, line_number ASC;

        --Local Variables Declaration
        lv_proc_name           VARCHAR2 (30) := 'UPD_MAIN';
        ln_count               NUMBER := 0;
        ln_init_count          NUMBER := 0;
        ln_init_count1         NUMBER := 0;
        ln_eli_count           NUMBER := 0;
        ln_unprocessed_count   NUMBER := 0;
        lv_receipt_number      VARCHAR2 (240) := NULL;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Program to Update Bank Trx Number Started. Timestamp: '
            || TO_CHAR ('DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               'Printing eligiblie records for processing in Output file. Timestamp: '
            || TO_CHAR ('DD-MON-RRRR HH24:MI:SS'));
        -- Loop for count of eligiblie records for processing
        fnd_file.put_line (
            fnd_file.output,
            '                                                                                                                                ');
        fnd_file.put_line (
            fnd_file.output,
            '                               Transactions which needs mapping                                                                 ');
        fnd_file.put_line (
            fnd_file.output,
            '******************************************************************************************************************************* ');
        fnd_file.put_line (
            fnd_file.output,
               'Bank Account Number           '
            || CHR (9)
            || 'Swift Code                    '
            || CHR (9)
            || 'Transaction Code              '
            || CHR (9)
            || 'No. of Unprocessed Records    ');
        fnd_file.put_line (
            fnd_file.output,
            '******************************************************************************************************************************* ');
        fnd_file.put_line (
            fnd_file.output,
            '                                                                                                                                ');

        FOR bank_accounts_rec IN c_bank_accounts
        LOOP
            FOR display_rec
                IN display_cur (
                       cn_bank_acct_use_id   =>
                           bank_accounts_rec.bank_acct_use_id,
                       cn_bank_account_id   =>
                           bank_accounts_rec.bank_account_id)
            LOOP
                fnd_file.put_line (
                    fnd_file.output,
                       RPAD (display_rec.bank_account_num, 30)
                    || CHR (9)
                    || RPAD (display_rec.swift_code, 30)
                    || CHR (9)
                    || RPAD (display_rec.trx_code, 30)
                    || CHR (9)
                    || LPAD (display_rec.total, 30));
            END LOOP;                                   --display_cur end loop
        END LOOP;                                   --c_bank_accounts end loop

        --Print Summary Report
        fnd_file.put_line (
            fnd_file.output,
            '                                                                                                                                ');
        fnd_file.put_line (
            fnd_file.output,
            '                               Summary Report                                                                 ');
        fnd_file.put_line (
            fnd_file.output,
            '******************************************************************************************************************************* ');
        fnd_file.put_line (
            fnd_file.output,
               'Bank Account Number           '
            || CHR (9)
            || 'Eligible Records              '
            || CHR (9)
            || 'Processed Records             '
            || CHR (9)
            || 'Unprocessed Records           ');
        fnd_file.put_line (
            fnd_file.output,
            '******************************************************************************************************************************* ');
        fnd_file.put_line (
            fnd_file.output,
            '                                                                                                                                ');

        FOR r_bank_accounts IN c_bank_accounts
        LOOP
            ln_eli_count           := 0;
            ln_init_count          := 0;
            ln_init_count1         := 0;

            SELECT COUNT (*)
              INTO ln_eli_count
              FROM apps.ce_statement_headers csh, apps.ce_statement_lines csl
             WHERE     1 = 1
                   AND csh.statement_header_id = csh.statement_header_id
                   AND csh.bank_account_id = r_bank_accounts.bank_account_id
                   AND csl.status = 'UNRECONCILED'              --Unreconciled
                   AND csl.trx_type IN ('MISC_CREDIT'         --'Misc Receipt'
                                                     , 'CREDIT'    --'Receipt'
                                                               );

            ------------------------------------------------------------------------------------------------------------
            --Loop for each receipts and cash management related data to check and update bank transaction number
            ------------------------------------------------------------------------------------------------------------
            FOR r_ce_stm_lines
                IN c_ce_stm_lines (
                       cn_bank_account_id => r_bank_accounts.bank_account_id)
            LOOP
                ln_init_count1      := 0;
                lv_receipt_number   := NULL;

                --Start changes v2.2 09-DEC-2020
                BEGIN
                    SELECT arca.receipt_number
                      INTO lv_receipt_number
                      FROM apps.ar_cash_receipts_all arca
                     WHERE     1 = 1
                           AND arca.remit_bank_acct_use_id =
                               r_bank_accounts.bank_acct_use_id
                           AND arca.receipt_number LIKE '%-%-%'
                           AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1
                                              , 1) =
                               TO_CHAR (
                                   TO_DATE (r_ce_stm_lines.statement_number,
                                            'YYMMDD'),
                                   'DDMMYY')
                           AND TO_CHAR (
                                   REPLACE (REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1
                                                           , 2),
                                            ',',
                                            ''),
                                   'FM9G999G999G999G999G999G999G999G990D00PT') =
                               TO_CHAR (
                                   r_ce_stm_lines.amount,
                                   'FM9G999G999G999G999G999G999G999G990D00PT')
                           --Ignore the receipt number if it is already assigned to a statement line
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM ce_statement_headers sh, ce_statement_lines sl
                                     WHERE     1 = 1
                                           AND sh.statement_number =
                                               r_ce_stm_lines.statement_number
                                           AND sh.bank_account_id =
                                               r_bank_accounts.bank_account_id
                                           AND sh.statement_header_id =
                                               sl.statement_header_id
                                           AND sl.bank_trx_number =
                                               arca.receipt_number)
                           AND EXISTS
                                   (SELECT 1
                                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                                     WHERE     1 = 1
                                           AND ffvs.flex_value_set_name =
                                               'XXD_CE_BAI_MT940_MAPPING_VS'
                                           AND ffvs.flex_value_set_id =
                                               ffv.flex_value_set_id
                                           AND r_ce_stm_lines.trx_code =
                                               ffv.attribute2
                                           AND REGEXP_SUBSTR (arca.receipt_number, '[^-]+', 1
                                                              , 3) =
                                               ffv.attribute4
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffv.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   ffv.end_date_active,
                                                                   SYSDATE)
                                           AND ffv.enabled_flag = 'Y'
                                           AND (   ffv.attribute1 IS NULL
                                                OR ffv.attribute1 =
                                                   (SELECT bankorgprofile.home_country
                                                      FROM apps.hz_code_assignments bankca, apps.hz_organization_profiles bankorgprofile
                                                     WHERE     1 = 1
                                                           AND NVL (
                                                                   bankorgprofile.status,
                                                                   'A') =
                                                               'A'
                                                           AND bankca.class_category =
                                                               'BANK_INSTITUTION_TYPE'
                                                           AND bankca.class_code IN
                                                                   ('BANK', 'CLEARINGHOUSE')
                                                           AND bankca.owner_table_name =
                                                               'HZ_PARTIES'
                                                           AND bankca.owner_table_id =
                                                               bankorgprofile.party_id
                                                           AND NVL (
                                                                   bankca.status,
                                                                   'A') =
                                                               'A'
                                                           AND bankorgprofile.party_id =
                                                               r_bank_accounts.bank_id)));
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        NULL;
                    WHEN OTHERS
                    THEN
                        pv_errbuf    :=
                            SUBSTR (
                                   'Error while fetching receipt_number for Account Num: '
                                || r_bank_accounts.bank_account_num
                                || ' :: Statement Num: '
                                || r_ce_stm_lines.statement_number
                                || ' :: Amount: '
                                || r_ce_stm_lines.amount
                                || '. The Error is: '
                                || SQLERRM,
                                1,
                                2000);
                        pn_retcode   := gn_warning; --Complete the program in warning
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END;



                /*
                IF c_ar_cash_receipts%ISOPEN
                THEN
                   CLOSE c_ar_cash_receipts;
                END IF;
                OPEN c_ar_cash_receipts (
                                          cn_bank_id            =>  r_bank_accounts.bank_id
                                         ,cn_bank_account_id    =>  r_bank_accounts.bank_account_id
                                         ,cn_bank_acct_use_id   =>  r_bank_accounts.bank_acct_use_id
                                         ,cv_stmt_number        =>  r_ce_stm_lines.statement_number
                                         ,cn_trx_amount         =>  r_ce_stm_lines.amount
                                         ,cv_trx_code           =>  r_ce_stm_lines.trx_code
                                        );
                FETCH c_ar_cash_receipts INTO lv_receipt_number;
                CLOSE c_ar_cash_receipts;
    */
                --End changes v2.2 09-DEC-2020

                --            fnd_file.put_line (fnd_file.LOG,
                --                               'lv_receipt_number - ' || lv_receipt_number);

                IF NVL (lv_receipt_number, '-999') != '-999'
                THEN
                    BEGIN
                        --Using direct update as there is no Public API available. Please refer to Oracle Note ID's 2089362.1 and 2363755.1
                        --R12:CE: Is There an API to Mass Update the Bank Statement Lines CE_STATEMENT_LINES Table and the Bank Statements CE_STATEMENT_HEADERS Table? (Doc ID 2089362.1)
                        --R12.1:CE: How To Update BANK_TRX_NUMBER Field In CE_STATEMENT_LINES Table? (Doc ID 2363755.1)
                        UPDATE ce_statement_lines csl
                           SET csl.attribute1 = NVL (csl.bank_trx_number, 'No Value'), csl.bank_trx_number = lv_receipt_number, csl.last_update_date = SYSDATE,
                               csl.last_updated_by = g_num_user_id
                         WHERE     1 = 1
                               AND csl.statement_line_id =
                                   r_ce_stm_lines.statement_line_id;

                        ln_init_count1   := SQL%ROWCOUNT;
                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while updating Bank Trx Number in CE STMT LINES Table for First Loop for Stmt Line Id: '
                                || r_ce_stm_lines.statement_line_id);
                            ROLLBACK;
                    END;
                END IF;

                ln_init_count       := ln_init_count + ln_init_count1;
            END LOOP;                                --c_ce_stm_lines end loop

            fnd_file.put_line (
                fnd_file.LOG,
                   'Number of Records updated in CE STMT LINES Table for First Loop: '
                || ln_init_count);
            ln_unprocessed_count   := 0;
            ln_unprocessed_count   :=
                NVL (ln_eli_count, 0) - NVL (ln_init_count, 0);

            fnd_file.put_line (
                fnd_file.output,
                   LPAD (r_bank_accounts.bank_account_num, 30)
                || CHR (9)
                || LPAD (ln_eli_count, 30)
                || CHR (9)
                || LPAD (ln_init_count, 30)
                || CHR (9)
                || LPAD (ln_unprocessed_count, 30));
        END LOOP;                                  --c_bank_account end loop 2

        ------------------------------------------------------------------------------------------------------------
        --Loop for each receipts and cash management related data to check and update bank transaction number
        ------------------------------------------------------------------------------------------------------------
        FOR r_get_cash_receipts IN c_get_cash_receipts
        LOOP
            ln_count   := ln_count + 1;

            BEGIN
                --Using direct update as there is no Public API available. Please refer to Oracle Note ID's 2089362.1 and 2363755.1
                --R12:CE: Is There an API to Mass Update the Bank Statement Lines CE_STATEMENT_LINES Table and the Bank Statements CE_STATEMENT_HEADERS Table? (Doc ID 2089362.1)
                --R12.1:CE: How To Update BANK_TRX_NUMBER Field In CE_STATEMENT_LINES Table? (Doc ID 2363755.1)
                UPDATE apps.ce_statement_lines csl
                   SET csl.attribute1 = NVL (csl.bank_trx_number, 'No Value') --csl.bank_trx_number
                                                                             , csl.bank_trx_number = TO_CHAR (r_get_cash_receipts.trx_date, 'ddmmyy') || '-' || TRIM (TO_CHAR (r_get_cash_receipts.amount, '999999999990.99')), csl.last_update_date = SYSDATE,
                       csl.last_updated_by = g_num_user_id
                 WHERE     1 = 1
                       AND csl.statement_line_id =
                           r_get_cash_receipts.statement_line_id
                       AND csl.attribute1 IS NULL;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while updating Bank Trx Number in CE STMT LINES Table for Second Loop for Stmt Line Id: '
                        || r_get_cash_receipts.statement_line_id);
                    ROLLBACK;
            END;
        END LOOP;                               --c_get_cash_receipts end loop

        fnd_file.put_line (
            fnd_file.LOG,
               'Number of Records updated in CE_STATEMENT_LINES Table: '
            || ln_count);
        fnd_file.put_line (
            fnd_file.LOG,
               'Program to Update Bank Trx Number Completed. Timestamp: '
            || TO_CHAR ('DD-MON-RRRR HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    :=
                SUBSTR (
                       'When Others Exception in '
                    || lv_proc_name
                    || ' Procedure. Error is '
                    || SQLERRM,
                    1,
                    2000);
            pn_retcode   := gn_error;          --Complete the program in error
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
    END upd_main;
END xxdoar_cm_bnk_recon_pkg;
/
