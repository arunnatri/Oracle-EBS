--
-- XXDOAP_CM_PAYMENT_RECON_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:30 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOAP_CM_PAYMENT_RECON_PKG"
AS
    /*******************************************************************************
     * Program Name : XXDOAP_CM_PAYMENT_RECON_PKG
     * Language     : PL/SQL
     * Description  : This package will update bank statement data in interface table from payments.
     *
     * History      :
     *
     * WHO                 Version      When           Description
     * ---------------------------------------------------------------------------------------------*
     * Infosys Team        1.0          15-SEP-2016                                                 *
     * Srinath Siricilla   1.1          04-FEB-2019    CCR0007797 - Enabling program to work if the *
     *                                                 Bank Account has multiple payment methods    *
     *----------------------------------------------------------------------------------------------*/


    g_num_user_id        NUMBER := fnd_global.user_id;
    g_num_login_id       NUMBER := fnd_global.login_id;
    g_dte_current_date   DATE := SYSDATE;

    --------------------------------------------------------------------------------------------------------------
    -- Procedure  : main
    -- Description: procedure to update bank transaction number in cash management interface table from payments.
    --------------------------------------------------------------------------------------------------------------
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    AS
        ------------------------------
        --Local Variable Declaration
        ------------------------------
        ln_check_count        NUMBER := 0;
        ln_trx_count          NUMBER := 0;
        lc_bank_account_num   CE_STATEMENT_LINES_INTERFACE.bank_account_num%TYPE;
        lc_check_num          AP_CHECKS_ALL.check_number%TYPE;
        ld_check_date         DATE;
        ln_check_amount       NUMBER;
        ld_trx_date           DATE;
        lc_trx_amount         NUMBER;
        lc_bank_trx_number    CE_STATEMENT_LINES_INTERFACE.bank_trx_number%TYPE;
        ld_trx_date_a         DATE;
        ln_trx_amount_a       NUMBER := 0;
        ln_count              NUMBER := 0;
        lc_num_days           VARCHAR2 (20);
        ln_count_a            NUMBER := 0;

        ---------------------------------------------------------------
        --Cursor to fetch cash managerment details
        ---------------------------------------------------------------
        -- Start of Change as per 1.1

        /*CURSOR c_get_cash_management_data
            IS
         SELECT  csli.bank_trx_number,
                 csli.bank_account_num,
                 csli.trx_date,
                 csli.amount trx_amount
          FROM CE_STATEMENT_LINES_INTERFACE CSLI,
          (select ffv.flex_value Bank_account_num , Ffv.Parent_Flex_Value_Low Payment_method,
                     ffv.attribute1 num_days
                    from fnd_flex_value_sets ffvs,
                               fnd_flex_values ffv
                   where ffvs.flex_value_set_name = 'CE_AP_BANK'
                   and ffvs.flex_Value_Set_id = ffv.flex_value_set_id) Bank_account
        WHERE csli.attribute1 IS NULL
          AND csli.bank_Account_num = bank_account.bank_account_num
          AND csli.bank_Account_num = '1894694734'
          AND csli.statement_number = '190123'
          --and bank_trx_number IN ('TESTWIRE8')
          ORDER BY csli.trx_date;*/

        CURSOR c_get_cash_management_data IS
              SELECT csli.bank_trx_number, csli.bank_account_num, csli.trx_date,
                     csli.amount trx_amount, csli.line_number
                FROM ce_statement_lines_interface CSLI, apps.ce_statement_headers_int cshi
               WHERE     csli.attribute1 IS NULL
                     AND NVL (cshi.record_status_flag, 'N') = 'N'
                     AND cshi.statement_number = csli.statement_number
                     AND cshi.bank_account_num = csli.bank_account_num
                     AND EXISTS
                             (SELECT 1
                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                               WHERE     ffvs.flex_value_set_name =
                                         'CE_AP_BANK'
                                     AND ffvs.flex_Value_Set_id =
                                         ffv.flex_value_set_id
                                     AND ffv.flex_value = csli.bank_account_num
                                     AND ffv.enabled_flag = 'Y'
                                     AND SYSDATE BETWEEN NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE)
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE))
            --  AND csli.bank_Account_num = '1894694734'
            --  AND csli.statement_number = '190123'
            --and bank_trx_number IN ('TESTWIRE8')
            ORDER BY csli.trx_date;

        -- End of Change as per 1.1

        ---------------------------------------------------------------
        --Cursor to fetch number of days details
        ---------------------------------------------------------------

        CURSOR get_days (p_bank_account_num VARCHAR2)
        IS
            SELECT ffv.attribute1 num_days
              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
             WHERE     ffvs.flex_value_set_name = 'CE_AP_BANK'
                   AND ffvs.flex_Value_Set_id = ffv.flex_value_set_id
                   -- Start of Change as per 1.1
                   AND ffv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                   AND NVL (ffv.end_date_active, SYSDATE)
                   -- End of Change as per 1.1
                   AND ffv.flex_value = p_bank_account_num;

        ---------------------------------------------------------------
        --Cursor to fetch payment det;ails
        ---------------------------------------------------------------

        -- Start of Change for 1.1

        /*
        CURSOR c_get_all_payments(p_trx_number VARCHAR2, p_bank_account_num VARCHAR2, p_trx_date DATE, p_amt NUMBER)
        IS
        SELECT           ac.check_number,
                         ac.amount,
                         ac.check_Date,
                         bank_account.bank_account_num
          FROM
               CE_BANK_ACCOUNTS CBA,
               CE_BANK_ACCT_USES_ALL CBAU,
               AP_CHECKS_ALL AC,
                iby_payment_methods_vl iby1,
                (select ffv.flex_value Bank_account_num , Ffv.Parent_Flex_Value_Low Payment_method,
                     ffv.attribute1 num_days
                    from fnd_flex_value_sets ffvs,
                               fnd_flex_values ffv
                   where ffvs.flex_value_set_name = 'CE_AP_BANK'
                   and ffvs.flex_Value_Set_id = ffv.flex_value_set_id) Bank_account
        WHERE AC.CE_BANK_ACCT_USE_ID       = CBAU.bank_acct_use_id
          AND CBAU.bank_account_id           = CBA.bank_account_id
          AND IBY1.PAYMENT_METHOD_CODE   = AC.PAYMENT_METHOD_CODE
          AND UPPER(IBY1.payment_method_name) = UPPER(bank_account.payment_method)
          and cba.bank_account_num = Bank_account.bank_account_num
          AND TO_CHAR(ac.check_number) != TO_CHAR(p_trx_number)
          --AND ac.check_number ='15462'
          and cba.bank_account_num = p_bank_account_num
          and ac.check_date = p_trx_date
          and ac.amount = p_amt;*/

        CURSOR c_get_all_payments (p_trx_number VARCHAR2, p_bank_account_num VARCHAR2, p_trx_date DATE
                                   , p_amt NUMBER)
        IS
            SELECT ac.check_number, ac.amount, ac.check_Date,
                   cba.bank_account_num
              FROM CE_BANK_ACCOUNTS CBA, CE_BANK_ACCT_USES_ALL CBAU, AP_CHECKS_ALL AC,
                   iby_payment_methods_vl iby1
             WHERE     1 = 1
                   AND AC.CE_BANK_ACCT_USE_ID = CBAU.bank_acct_use_id
                   AND CBAU.bank_account_id = CBA.bank_account_id
                   AND IBY1.PAYMENT_METHOD_CODE = AC.PAYMENT_METHOD_CODE
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                             WHERE     ffvs.flex_value_set_name =
                                       'CE_AP_BANK'
                                   AND ffvs.flex_Value_Set_id =
                                       ffv.flex_value_set_id
                                   AND ffv.flex_value = cba.bank_account_num
                                   AND UPPER (Ffv.Parent_Flex_Value_Low) =
                                       UPPER (IBY1.payment_method_name)
                                   AND ffv.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           ffv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           ffv.end_date_active,
                                                           SYSDATE))
                   --     AND TO_CHAR(ac.check_number) != TO_CHAR(p_trx_number) -- Commented for Change 1.1
                   --AND ac.check_number ='15462'
                   AND TO_CHAR (ac.check_number) !=
                       TO_CHAR (NVL (p_trx_number, 'ABC9999')) -- Added for Change 1.1
                   AND cba.bank_account_num = p_bank_account_num
                   AND ac.check_date = p_trx_date
                   AND ac.amount = p_amt;

        -- End of Change for 1.1

        ---------------------------------------------------------------
        --Cursor to fetch cash managerment details
        ---------------------------------------------------------------

        -- Start of Change for 1.1

        /* CURSOR c_get_ce_count(p_check_number VARCHAR2, p_bank_account_num VARCHAR2, p_trx_date DATE, p_amt NUMBER)
            IS
         SELECT  count(csli.bank_trx_number)
          FROM CE_STATEMENT_LINES_INTERFACE CSLI,
          (select ffv.flex_value Bank_account_num , Ffv.Parent_Flex_Value_Low Payment_method,
                     ffv.attribute1 num_days
                    from fnd_flex_value_sets ffvs,
                               fnd_flex_values ffv
                   where ffvs.flex_value_set_name = 'CE_AP_BANK'
                   and ffvs.flex_Value_Set_id = ffv.flex_value_set_id) Bank_account
        WHERE csli.attribute1 IS NULL
          AND csli.bank_Account_num = bank_account.bank_account_num
           AND TO_CHAR(csli.bank_trx_number) != TO_CHAR(p_check_number)
          and csli.bank_account_num = p_bank_account_num
          and csli.trx_date = p_trx_date
          and csli.amount = p_amt
          ORDER BY csli.trx_date; */

        CURSOR c_get_ce_count (p_check_number VARCHAR2, p_bank_account_num VARCHAR2, p_trx_date DATE
                               , p_amt NUMBER, p_line_number NUMBER)
        IS
              SELECT --COUNT(csli.bank_trx_number)   -- Commented for Change 1.1
                     COUNT (NVL (csli.bank_trx_number, 'ABC9999')) -- Added for Change 1.1
                FROM ce_statement_lines_interface csli, ce_statement_headers_int cshi
               WHERE     1 = 1
                     AND csli.attribute1 IS NULL
                     AND NVL (cshi.record_status_flag, 'N') = 'N'
                     AND cshi.statement_number = csli.statement_number
                     AND cshi.bank_account_num = csli.bank_account_num
                     AND csli.line_number = p_line_number
                     AND EXISTS
                             (SELECT 1
                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                               WHERE     1 = 1
                                     AND ffvs.flex_value_set_name =
                                         'CE_AP_BANK'
                                     AND ffvs.flex_Value_Set_id =
                                         ffv.flex_value_set_id
                                     AND ffv.flex_value = csli.bank_Account_num
                                     AND ffv.enabled_flag = 'Y'
                                     AND SYSDATE BETWEEN NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE)
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE))
                     --     AND TO_CHAR(csli.bank_trx_number) != TO_CHAR(p_check_number) -- Commented for Change 1.1
                     AND TO_CHAR (NVL (csli.bank_trx_number, 'ABC9999')) !=
                         TO_CHAR (p_check_number)      -- Added for Change 1.1
                     AND csli.bank_account_num = p_bank_account_num
                     AND csli.trx_date = p_trx_date
                     AND csli.amount = p_amt
            ORDER BY csli.trx_date;
    -- End of Change for 1.1

    ---------------
    --Begin Block
    ---------------
    BEGIN
        ------------------------------------------------------------------------------------------------------------
        --Loop for each payment and cash management related data to check and update bank transaction number
        ------------------------------------------------------------------------------------------------------------

        FOR r_get_cash_management_data IN c_get_cash_management_data
        LOOP
            ld_trx_date_a     := r_get_cash_management_data.trx_date;
            ln_trx_amount_a   := r_get_cash_management_data.trx_amount;
            ln_trx_count      := 0;
            ln_check_count    := 0;
            lc_check_num      := NULL;

            OPEN get_days (r_get_cash_management_data.bank_account_num);

            FETCH get_days INTO lc_num_days;

            CLOSE get_days;

            ------------------------------------------------------------------------------------------------------------
            --Loop for each day base on number of days for every single transaction.
            ------------------------------------------------------------------------------------------------------------
            FOR i IN 1 .. lc_num_days + 1
            LOOP
                fnd_file.put_line (fnd_file.LOG,
                                   'No. of days: ' || lc_num_days);

                ld_trx_date_a     := r_get_cash_management_data.trx_date;
                ln_trx_amount_a   := r_get_cash_management_data.trx_amount;
                ln_count_a        := lc_num_days;
                ld_trx_date_a     := ld_trx_date_a - ln_count_a;

                fnd_file.put_line (fnd_file.LOG,
                                   'Transaction Date: ' || ld_trx_date_a);

                fnd_file.put_line (fnd_file.LOG,
                                   'Transaction Amount: ' || ln_trx_amount_a);


                fnd_file.put_line (
                    fnd_file.LOG,
                       'Bank Trx: '
                    || NVL (r_get_cash_management_data.bank_trx_number,
                            'ABC9999'));
                --'Bank Trx: ' || r_get_cash_management_data.bank_trx_number);  -- Commented for Change 1.1


                ln_trx_count      := 0;


                OPEN c_get_all_payments (r_get_cash_management_data.bank_trx_number, r_get_cash_management_data.bank_account_num, ld_trx_date_a
                                         , ln_trx_amount_a);

                FETCH c_get_all_payments INTO lc_check_num, lc_trx_amount, ld_trx_date, lc_bank_account_num;

                CLOSE c_get_all_payments;

                OPEN c_get_ce_count (lc_check_num,
                                     lc_bank_account_num,
                                     ld_trx_date_a,
                                     ln_trx_amount_a,
                                     r_get_cash_management_data.line_number); -- Added for Change 1.1

                FETCH c_get_ce_count INTO ln_trx_count;

                CLOSE c_get_ce_count;

                IF ln_trx_count = 1
                THEN
                    ln_count   := ln_count + 1;

                    fnd_file.put_line (fnd_file.LOG,
                                       'Check Number: ' || lc_check_num);

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Bank Account Number: ' || lc_bank_account_num);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Transaction Date: ' || ld_trx_date);

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Transaction Amount: ' || lc_trx_amount);

                    UPDATE ce_statement_lines_interface csli
                       SET --csli.attribute1 = bank_trx_number, -- Commented for Change 1.1
                           csli.attribute1 = NVL (bank_trx_number, 'ABC9999'), -- Added for Change 1.1
                                                                               csli.bank_trx_number = lc_check_num, csli.last_update_date = SYSDATE,
                           csli.last_updated_by = g_num_user_id
                     WHERE     1 = 1
                           AND EXISTS
                                   -- Added for Change 1.1
                                   (SELECT 1
                                      FROM apps.ce_statement_headers_int cshi
                                     WHERE     NVL (cshi.record_status_flag,
                                                    'N') =
                                               'N'
                                           AND cshi.statement_number =
                                               csli.statement_number
                                           AND cshi.bank_account_num =
                                               csli.bank_account_num)
                           -- End of Change for 1.1
                           AND csli.bank_account_num = lc_bank_account_num
                           -- AND  csli.bank_trx_number = r_get_cash_management_data.bank_trx_number  -- Commented for Change 1.1
                           AND NVL (csli.bank_trx_number, 'ABC9999') =
                               NVL (
                                   r_get_cash_management_data.bank_trx_number,
                                   'ABC9999')          -- Added for Change 1.1
                           AND csli.line_number =
                               r_get_cash_management_data.line_number -- Added for Change 1.1
                           -- and trx_date = ld_trx_date
                           AND csli.amount = lc_trx_amount;

                    COMMIT;
                END IF;

                lc_num_days       := lc_num_days - 1;
                EXIT WHEN ln_count_a = 0;
            END LOOP;
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
END XXDOAP_CM_PAYMENT_RECON_PKG;
/
