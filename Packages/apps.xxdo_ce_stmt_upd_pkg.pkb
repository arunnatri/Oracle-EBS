--
-- XXDO_CE_STMT_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_CE_STMT_UPD_PKG"
AS
    /*******************************************************************************
    * Program Name : XXDO_CE_STMT_UPD_PKG
    * Language     : PL/SQL
    * Description  : This package will update bank statement data in interface table
    *
    * History      :
    *
    * WHO                  DESCRIPTION                         WHEN
    * ------------------------------------------------------------------------------------
    * BT Technology Team   1.0                                 27-AUG-2015
    * --------------------------------------------------------------------------- */
    gn_user_id        NUMBER := fnd_global.user_id;
    gn_resp_id        NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   NUMBER := fnd_global.resp_appl_id;
    gn_req_id         NUMBER := fnd_global.conc_request_id;
    gn_login_id       NUMBER := fnd_global.login_id;
    gd_sysdate        DATE := SYSDATE;
    gn_org_id         NUMBER;
    gc_code_pointer   VARCHAR2 (500);

    /****************************************************************************************
          * Procedure : PRINT_LOG_PRC
          * Synopsis  : This Procedure shall write to the concurrent program log file
          * Design    : Program input debug flag is 'Y' then the procedure shall write the message
          *             input to concurrent program log file
          * Notes     :
          * Return Values: None
          * Modification :
          * Date          Developer     Version    Description
          *--------------------------------------------------------------------------------------
          * 15-MAY-2015    BT Technology Team        1.00       Created
          ****************************************************************************************/
    PROCEDURE print_log_prc (p_message IN VARCHAR2)
    AS
    BEGIN
        fnd_file.put_line (apps.fnd_file.LOG, p_message);
    END print_log_prc;

    PROCEDURE main_prc (errbuf                       OUT VARCHAR2,
                        retcode                      OUT VARCHAR2,
                        p_branch_id               IN     NUMBER,
                        p_bank_account_id         IN     NUMBER,
                        p_statement_number_from   IN     VARCHAR2,
                        p_statement_number_to     IN     VARCHAR2,
                        p_statement_date_from     IN     VARCHAR2,
                        p_statement_date_to       IN     VARCHAR2)
    IS
        ln_count          NUMBER;

        CURSOR get_stmt_dtls IS
              SELECT aba.bank_account_name, aba.bank_account_num, BranchParty.PARTY_NAME Bank_Branch_Name,
                     BankOrgProfile.ORGANIZATION_NAME Bank_Name, aba.bank_account_id, aba.bank_id,
                     aba.bank_branch_id, tc.trx_type TYPE, l1.meaning type_dsp,
                     tc.transaction_code_id, tc.trx_code trx_code, tc.description,
                     lin.statement_number, lin.line_number, lin.trx_date,
                     lin.trx_text, lin.amount, lin.bank_trx_number
                FROM HZ_ORGANIZATION_PROFILES BankOrgProfile, HZ_RELATIONSHIPS BRRel, HZ_PARTIES BranchParty,
                     ce_bank_accounts aba, ar_receipt_methods rm, ce_lookups l1,
                     ce_transaction_codes tc, ce_statement_headers_int hdr, ce_statement_lines_interface lin
               WHERE     aba.bank_account_id = tc.bank_account_id
                     AND rm.receipt_method_id(+) = tc.receipt_method_id
                     AND l1.lookup_type = 'BANK_TRX_TYPE'
                     AND l1.lookup_code = tc.trx_type
                     AND hdr.bank_account_num = aba.bank_account_num
                     AND hdr.bank_branch_name = BranchParty.PARTY_NAME
                     AND hdr.bank_name = BankOrgProfile.ORGANIZATION_NAME
                     AND BranchParty.PARTY_ID = aba.bank_branch_id
                     AND BankOrgProfile.PARTY_ID = BRRel.OBJECT_ID
                     AND SYSDATE BETWEEN TRUNC (
                                             BankOrgProfile.effective_start_date)
                                     AND NVL (
                                             TRUNC (
                                                 BankOrgProfile.effective_end_date),
                                             SYSDATE + 1)
                     AND BRRel.RELATIONSHIP_TYPE = 'BANK_AND_BRANCH'
                     AND BRRel.RELATIONSHIP_CODE = 'BRANCH_OF'
                     AND BRRel.STATUS = 'A'
                     AND BRRel.SUBJECT_TABLE_NAME = 'HZ_PARTIES'
                     AND BRRel.SUBJECT_TYPE = 'ORGANIZATION'
                     AND BRRel.OBJECT_TABLE_NAME = 'HZ_PARTIES'
                     AND BRRel.OBJECT_TYPE = 'ORGANIZATION'
                     AND BRRel.SUBJECT_ID = BranchParty.PARTY_ID
                     AND BranchParty.PARTY_TYPE = 'ORGANIZATION'
                     AND BranchParty.status = 'A'
                     AND l1.meaning = 'Receipt'
                     AND tc.description = 'Lockbox Deposit'
                     --AND hdr.record_status_flag   = 'N'
                     AND hdr.bank_account_num = lin.bank_account_num
                     AND hdr.statement_number = lin.statement_number
                     AND tc.trx_code = lin.trx_code
                     AND aba.bank_branch_id = p_branch_id
                     AND aba.bank_account_id = p_bank_account_id
                     AND hdr.statement_number BETWEEN NVL (
                                                          p_statement_number_from,
                                                          hdr.statement_number)
                                                  AND NVL (
                                                          p_statement_number_to,
                                                          hdr.statement_number)
                     AND hdr.statement_date BETWEEN NVL (
                                                        fnd_date.canonical_to_date (
                                                            p_statement_date_from),
                                                        hdr.statement_date)
                                                AND NVL (
                                                        fnd_date.canonical_to_date (
                                                            p_statement_date_to),
                                                        hdr.statement_date)
            ORDER BY lin.statement_number, lin.line_number;


        CURSOR get_remit_batch_dtls IS
              SELECT b.name batch_number, b.batch_date trx_date, SUM (catv.amount) trx_amount
                FROM CE_BANK_ACCOUNTS BA, CE_BANK_ACCT_USES_ALL BAU, AR_BATCHES_ALL B,
                     ar_batches_all remit_batch, AR_CASH_RECEIPT_HISTORY_ALL catv, ar_cash_receipt_history_ALL crh2
               WHERE     catv.cash_receipt_id = crh2.cash_receipt_id
                     AND catv.ORG_ID = crh2.ORG_ID
                     AND catv.cash_receipt_history_id =
                         DECODE (catv.batch_id,
                                 NULL, crh2.REVERSAL_CASH_RECEIPT_HIST_ID,
                                 crh2.CASH_RECEIPT_HISTORY_ID)
                     AND b.batch_id = crh2.batch_id
                     --AND NVL ( catv.status, 'REMITTED' ) <> 'REVERSED'
                     AND catv.status = 'REMITTED'
                     AND remit_batch.org_id = b.org_id
                     AND remit_batch.batch_id = b.batch_id
                     AND BAU.BANK_ACCOUNT_ID = BA.BANK_ACCOUNT_ID
                     AND BAU.AR_USE_ENABLE_FLAG = 'Y'
                     AND B.REMIT_BANK_ACCT_USE_ID = BAU.BANK_ACCT_USE_ID
                     AND BA.bank_branch_id = p_branch_id
                     AND BA.bank_account_id = p_bank_Account_id
                     AND catv.trx_date BETWEEN NVL (
                                                   fnd_date.canonical_to_date (
                                                       p_statement_date_from),
                                                   catv.trx_date)
                                           AND NVL (
                                                   fnd_date.canonical_to_date (
                                                       p_statement_date_to),
                                                   catv.trx_date)
                     AND EXISTS
                             (SELECT 1
                                FROM ar_batches_all lockbox_batch, ar_cash_receipt_history_all crh, ar_lockboxes_all al
                               WHERE     lockbox_batch.org_id = crh.org_id
                                     AND lockbox_batch.batch_id = crh.batch_id
                                     AND lockbox_batch.receipt_method_id(+) =
                                         remit_batch.receipt_method_id
                                     AND lockbox_batch.receipt_class_id(+) =
                                         remit_batch.receipt_class_id
                                     AND lockbox_batch.remit_bank_acct_use_id(+) =
                                         remit_batch.remit_bank_acct_use_id
                                     AND catv.org_id = crh.org_id
                                     AND catv.cash_receipt_id =
                                         crh.cash_receipt_id
                                     AND crh.status IN ('CLEARED', 'CONFIRMED')
                                     AND crh.first_posted_record_flag = 'Y'
                                     AND lockbox_batch.lockbox_id =
                                         al.lockbox_id(+)) -- Modified (+) on 13-Sep-2016
                     AND NOT EXISTS
                             (SELECT 1
                                FROM ce_statement_reconcils_all cre
                               WHERE     cre.reference_type = 'RECEIPT'
                                     AND cre.reference_id =
                                         catv.CASH_RECEIPT_HISTORY_ID
                                     AND cre.org_id = catv.org_id)
            GROUP BY b.name, b.batch_date;


        CURSOR chk_intf_rec (p_bank_trx_number VARCHAR2)
        IS
            SELECT 'Y'
              FROM HZ_ORGANIZATION_PROFILES BankOrgProfile, HZ_RELATIONSHIPS BRRel, HZ_PARTIES BranchParty,
                   ce_bank_accounts aba, ar_receipt_methods rm, ce_lookups l1,
                   ce_transaction_codes tc, ce_statement_headers_int hdr, ce_statement_lines_interface lin
             WHERE     aba.bank_account_id = tc.bank_account_id
                   AND rm.receipt_method_id(+) = tc.receipt_method_id
                   AND l1.lookup_type = 'BANK_TRX_TYPE'
                   AND l1.lookup_code = tc.trx_type
                   AND hdr.bank_account_num = aba.bank_account_num
                   AND hdr.bank_branch_name = BranchParty.PARTY_NAME
                   AND hdr.bank_name = BankOrgProfile.ORGANIZATION_NAME
                   AND BranchParty.PARTY_ID = aba.bank_branch_id
                   AND BankOrgProfile.PARTY_ID = BRRel.OBJECT_ID
                   AND SYSDATE BETWEEN TRUNC (
                                           BankOrgProfile.effective_start_date)
                                   AND NVL (
                                           TRUNC (
                                               BankOrgProfile.effective_end_date),
                                           SYSDATE + 1)
                   AND BRRel.RELATIONSHIP_TYPE = 'BANK_AND_BRANCH'
                   AND BRRel.RELATIONSHIP_CODE = 'BRANCH_OF'
                   AND BRRel.STATUS = 'A'
                   AND BRRel.SUBJECT_TABLE_NAME = 'HZ_PARTIES'
                   AND BRRel.SUBJECT_TYPE = 'ORGANIZATION'
                   AND BRRel.OBJECT_TABLE_NAME = 'HZ_PARTIES'
                   AND BRRel.OBJECT_TYPE = 'ORGANIZATION'
                   AND BRRel.SUBJECT_ID = BranchParty.PARTY_ID
                   AND BranchParty.PARTY_TYPE = 'ORGANIZATION'
                   AND BranchParty.status = 'A'
                   AND l1.meaning = 'Receipt'
                   AND tc.description = 'Lockbox Deposit'
                   AND hdr.record_status_flag = 'N'
                   AND hdr.bank_account_num = lin.bank_account_num
                   AND hdr.statement_number = lin.statement_number
                   AND tc.trx_code = lin.trx_code
                   AND lin.bank_trx_number = p_bank_trx_number
                   AND aba.bank_branch_id = p_branch_id
                   AND aba.bank_account_id = p_bank_account_id;

        lc_intf_rec_chk   VARCHAR2 (10);
    BEGIN
        cep_standard.init_security ();
        print_log_prc ('***************************');
        print_log_prc ('Parameters');
        print_log_prc ('p_branch_id : ' || p_branch_id);
        print_log_prc ('p_bank_account_id : ' || p_bank_account_id);
        print_log_prc (
            'p_statement_number_from : ' || p_statement_number_from);
        print_log_prc ('p_statement_number_to : ' || p_statement_number_to);
        print_log_prc ('p_statement_date_from : ' || p_statement_date_from);
        print_log_prc ('p_statement_date_to : ' || p_statement_date_to);

       <<statement_loop>>
        FOR lcu_stmt_dtls_rec IN get_stmt_dtls
        LOOP
            print_log_prc ('***************************');
            print_log_prc (
                'Bank Account Number : ' || lcu_stmt_dtls_rec.bank_account_num);
            print_log_prc (
                'Statement Number : ' || lcu_stmt_dtls_rec.statement_number);
            print_log_prc (
                'Statement Line Number : ' || lcu_stmt_dtls_rec.line_number);
            print_log_prc (
                'Statement Line Amount : ' || lcu_stmt_dtls_rec.amount);
            print_log_prc ('Statement Date : ' || lcu_stmt_dtls_rec.trx_date);
            print_log_prc (
                'Transaction Code : ' || lcu_stmt_dtls_rec.trx_code);


            ln_count   := 0;

            FOR lcu_remit_batch_dtls_cnt IN get_remit_batch_dtls
            LOOP
                ln_count   := 0 + 1;
            END LOOP;

           <<remit_loop>>
            FOR lcu_remit_batch_dtls_rec IN get_remit_batch_dtls
            LOOP
                lc_intf_rec_chk   := NULL;

                OPEN chk_intf_rec (lcu_remit_batch_dtls_rec.batch_number);

                FETCH chk_intf_rec INTO lc_intf_rec_chk;

                CLOSE chk_intf_rec;


                print_log_prc (
                    'Remittance Batch : ' || lcu_remit_batch_dtls_rec.batch_number);
                print_log_prc (
                    'Remittance Amount : ' || lcu_remit_batch_dtls_rec.trx_amount);
                print_log_prc (
                    'Remittance Date : ' || lcu_remit_batch_dtls_rec.trx_date);
                print_log_prc ('Interface Check Flag : ' || lc_intf_rec_chk);

                IF     NVL (lc_intf_rec_chk, 'N') = 'N'
                   --AND lcu_stmt_dtls_rec.amount = lcu_remit_batch_dtls_rec.trx_amount
                   AND lcu_stmt_dtls_rec.trx_date =
                       lcu_remit_batch_dtls_rec.trx_date
                   AND ln_count < 2
                   AND lcu_stmt_dtls_rec.bank_trx_number !=
                       lcu_remit_batch_dtls_rec.batch_number
                THEN
                    print_log_prc (
                        'Updating : ' || lcu_remit_batch_dtls_rec.trx_amount);

                    UPDATE ce_statement_lines_interface
                       SET bank_trx_number = lcu_remit_batch_dtls_rec.batch_number
                     WHERE     bank_account_num =
                               lcu_stmt_dtls_rec.bank_account_num
                           AND statement_number =
                               lcu_stmt_dtls_rec.statement_number
                           AND trx_code = lcu_stmt_dtls_rec.trx_code
                           AND line_number = lcu_stmt_dtls_rec.line_number;

                    print_log_prc ('Update Success');
                    COMMIT;

                    EXIT remit_loop;
                END IF;
            END LOOP;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            gc_code_pointer   := 'Program Exception - ';
            print_log_prc (gc_code_pointer || SQLCODE || ' : ' || SQLERRM);
    END main_prc;
END;
/
