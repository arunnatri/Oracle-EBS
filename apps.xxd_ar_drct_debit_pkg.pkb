--
-- XXD_AR_DRCT_DEBIT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_DRCT_DEBIT_PKG"
AS
    /**********************************************************************************************
    * Package      : XXD_AR_DRCT_DEBIT_PKG
    * Design       : This package will be used to fetch the Transactions for Direct Debit
    * Notes        :
    * Modification :
    -- ===============================================================+++++++======================
    -- Date          Version#    Name                    Comments
    -- ============  =========   ======================  ====================++++==================
    -- 23-DEC-2020   1.0         Srinath Siricilla       Initial Version
    -- 03-NOV-2021   2.0         Srinath Siricilla       Added for CCR0009034
    ***********************************************************************************************/

    --Added for CCR0009034

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in WRITE_LOG Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;

    FUNCTION discount_date (p_customer_trx_id IN NUMBER, p_org_id IN NUMBER)
        RETURN DATE
    IS
        CURSOR discount_date_cur IS
            SELECT rcta.trx_date, rcta.term_due_date, hcasa.attribute13,
                   hcasa.attribute14
              FROM apps.hz_cust_acct_sites_all hcasa, apps.ra_customer_trx_all rcta
             WHERE     hcasa.attribute12 = 'YES'
                   AND hcasa.cust_account_id = rcta.bill_to_customer_id
                   AND rcta.customer_trx_id = p_customer_trx_id
                   AND rcta.org_id = p_org_id;
    BEGIN
        FOR l_discount IN discount_date_cur
        LOOP
            IF     l_discount.attribute13 IS NOT NULL
               AND l_discount.attribute14 IS NOT NULL
            THEN
                RETURN l_discount.trx_date;
            ELSE
                RETURN l_discount.term_due_date;
            END IF;
        END LOOP;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Un known Error  - ' || SUBSTR (SQLERRM, 1, 200));

            RETURN NULL;
    END discount_date;

    FUNCTION add_quotes (pv_string IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_string   VARCHAR2 (1000);
    BEGIN
        lv_string   := '"' || pv_string || '"';
        RETURN lv_string;
    END;

    FUNCTION discount_cal (p_customer_trx_id IN NUMBER)
        RETURN NUMBER
    IS
        l_discount_cal   NUMBER;
    BEGIN
          SELECT SUM (rctla.unit_selling_price - (rctla.unit_selling_price * TO_NUMBER (hcasa.attribute14) / 100))
            INTO l_discount_cal
            FROM apps.hz_cust_acct_sites_all hcasa, apps.ra_customer_trx_all rcta, apps.ra_customer_trx_lines_all rctla
           WHERE     hcasa.attribute12 = 'YES'
                 AND hcasa.attribute13 IS NOT NULL
                 AND hcasa.attribute14 IS NOT NULL
                 AND hcasa.cust_account_id = rcta.bill_to_customer_id
                 AND rcta.customer_trx_id = rctla.customer_trx_id
                 AND rcta.customer_trx_id = p_customer_trx_id
                 AND rcta.trx_date BETWEEN (SYSDATE - TO_NUMBER (hcasa.attribute13))
                                       AND SYSDATE
        GROUP BY rcta.customer_trx_id;

        RETURN l_discount_cal;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            write_log (
                   'No data found for the Discount Calculation for the customer trx id - '
                || p_customer_trx_id
                || ' and error is - '
                || SUBSTR (SQLERRM, 1, 200));

            RETURN NULL;
        WHEN OTHERS
        THEN
            write_log (
                   ' Exception Error for the Discount Calculation for the customer trx id - '
                || p_customer_trx_id
                || ' and error is - '
                || SUBSTR (SQLERRM, 1, 200));

            RETURN NULL;
    END discount_cal;

    PROCEDURE apply_mode_prc (pn_request_id IN NUMBER)
    IS
        ln_receipt_bal    NUMBER;
        ln_trxn_bal       NUMBER;
        lv_balance        VARCHAR2 (10);
        ln_trxn_balance   NUMBER;

        CURSOR get_receipts_tot_cur IS
              SELECT party_id, org_id, SUM (final_amount) amount --SUM (amount) amount
                --                party_id, org_id, SUM (amount) amount
                FROM xxdo.xxd_ar_drct_debit_t
               WHERE     1 = 1
                     AND trx_class IN ('PMT', 'CM')
                     AND process_record = 'Y'
                     AND request_id = gn_request_id
            GROUP BY party_id, org_id;

        CURSOR get_trxn_tot_cur (pn_party_id IN NUMBER, pn_org_id IN NUMBER)
        IS
              SELECT party_id, org_id, SUM (final_amount) amount --SUM (amount) amount
                --                party_id, org_id, SUM(amount) amount--SUM (amount) amount
                FROM xxdo.xxd_ar_drct_debit_t
               WHERE     1 = 1
                     AND trx_class IN ('INV', 'DM')
                     AND party_id = pn_party_id
                     AND process_record = 'Y'
                     AND request_id = gn_request_id
                     AND org_id = pn_org_id
            GROUP BY party_id, org_id;


        CURSOR get_trxn_cur (pn_party_id IN NUMBER, pn_org_id IN NUMBER)
        IS
              SELECT *
                FROM xxdo.xxd_ar_drct_debit_t
               WHERE     1 = 1
                     AND trx_class IN ('INV', 'DM')
                     AND party_id = pn_party_id
                     AND process_record = 'Y'
                     AND request_id = gn_request_id
                     AND org_id = pn_org_id
            ORDER BY trx_date ASC;
    BEGIN
        FOR rcpts_party IN get_receipts_tot_cur
        LOOP
            lv_balance       := NULL;

            ln_receipt_bal   := rcpts_party.amount; -- Sum of PMT and CM amounts

            write_log ('Total Receipts Balance is - ' || ln_receipt_bal);

            --            write_log(
            --                   'Total Receipts Amount is - '
            --                || ln_receipt_bal
            --                || ' for Party ID - '
            --                || rcpts_party.party_id);

            -- Now Apply the Transactions on to the receipt and

            FOR trx
                IN get_trxn_tot_cur (rcpts_party.party_id,
                                     rcpts_party.org_id)
            LOOP
                -- 100 := -10+90

                lv_balance    := NULL;

                ln_trxn_bal   := trx.amount;

                --                write_log (
                --                       'Total Trxn Amount is - '
                --                    || ln_trxn_bal
                --                    || ' for Party ID - '
                --                    || trx.party_id);

                IF ABS (ln_receipt_bal) >= ABS (ln_trxn_bal)
                THEN
                    --                    write_log( 'Receipt balances are more than Inv Balances, so update all the Trx balances as Zero and no need to show them in the Output');

                    UPDATE xxdo.xxd_ar_drct_debit_t
                       SET trx_balance = 0, last_updated_by = gn_user_id, last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND party_id = trx.party_id
                           --AND  trx_id = rcpts.trx_id
                           AND org_id = trx.org_id;

                    COMMIT;
                ELSE
                    --                    write_log( 'Receipt balances are less than Inv Balances, so deduct the Trx balances and show them in the Output with lv_balance - '
                    --                        || lv_balance);

                    lv_balance   := 'Y';
                END IF;

                --END LOOP;

                IF lv_balance = 'Y'
                THEN
                    NULL;

                    --                write_log(
                    --                       'Now update the balances in the Stg Table with lv_balance - '
                    --                    || lv_balance);

                    ln_trxn_balance   := NULL;

                    FOR trx_rec
                        IN get_trxn_cur (rcpts_party.party_id,
                                         rcpts_party.org_id)
                    LOOP
                        -- Fetched FIFO AR Transaction and applied the receipt amount

                        ln_trxn_balance   :=
                            ABS (trx_rec.final_amount) - ABS (ln_receipt_bal);

                        -- When ln_trxn_balance is -VE, tells Trxn amount is less than Total Receipt Amount

                        write_log (
                               'Initial trxn balances is - '
                            || ln_trxn_balance
                            || ' for trxn - '
                            || trx_rec.trx_id);

                        UPDATE xxdo.xxd_ar_drct_debit_t
                           SET trx_balance = DECODE (SIGN (ln_trxn_balance), -1, 0, ln_trxn_balance)
                         WHERE     1 = 1
                               AND party_id = trx_rec.party_id
                               AND trx_id = trx_rec.trx_id
                               AND org_id = trx_rec.org_id;

                        COMMIT;

                        -- Now, Reduce the receipt balance by Subtracting the Trxn Amount

                        ln_receipt_bal   :=
                            ABS (trx_rec.final_amount) - ABS (ln_receipt_bal);

                        write_log (
                            'Now the receipt balance is - ' || ln_receipt_bal);

                        IF ln_receipt_bal >= 0
                        THEN
                            --                        write_log (
                            --                               'Exit the loop when receipt balance is Zero - '
                            --                            || ln_receipt_bal);
                            EXIT;
                        END IF;
                    --                    write_log ('End of First Loop');
                    END LOOP;

                    lv_balance        := 'N';
                END IF;
            END LOOP;

            write_log ('End of Second Loop');
        END LOOP;
    END apply_mode_prc;

    PROCEDURE update_value_set (p_org_id IN NUMBER, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2, p_gl_date_from IN VARCHAR2, p_gl_date_to IN VARCHAR2, p_acct_num_from IN VARCHAR2, p_acct_num_to IN VARCHAR2, p_trx_num_from IN VARCHAR2, p_trx_num_to IN VARCHAR2
                                , p_override IN VARCHAR2, p_batch_source IN VARCHAR2, p_trx_type IN VARCHAR2)
    IS
        ln_actual_completion_date   DATE;
    -- Added for CCR0009034 for update current program reuest date in the Vlaue set
    BEGIN
        ln_actual_completion_date   := NULL;

        BEGIN
            SELECT REQUESTED_START_DATE
              INTO ln_actual_completion_date
              FROM apps.fnd_conc_req_summary_v
             WHERE     user_concurrent_program_name =
                       'Deckers Direct Debit Report'
                   AND request_id = gn_request_id; --apps.FND_GLOBAL.CONC_REQUEST_ID;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                write_log (
                    'Request ID - ' || apps.FND_GLOBAL.CONC_REQUEST_ID);
            --'No request ids found  - ' || SUBSTR (SQLERRM, 1, 200));
            WHEN OTHERS
            THEN
                write_log (
                    'Request Id Error  - ' || SUBSTR (SQLERRM, 1, 200));
        END;

        IF ln_actual_completion_date IS NOT NULL
        THEN
            IF     p_org_id IS NOT NULL
               AND p_trx_date_from IS NULL
               AND p_trx_date_to IS NULL
               AND p_gl_date_from IS NULL
               AND p_gl_date_to IS NULL
               AND p_acct_num_from IS NULL
               AND p_acct_num_to IS NULL
               AND p_trx_num_from IS NULL
               AND p_trx_num_to IS NULL
               AND NVL (p_override, 'N') = 'N'
               AND p_trx_type IS NULL
               AND p_batch_source IS NULL
            THEN
                BEGIN
                    UPDATE apps.fnd_flex_values
                       SET attribute4 = TO_CHAR (ln_actual_completion_date - 365, 'DD-MON-YYYY')
                     WHERE     value_category = 'XXD_AR_TRX_BATCH_OU_VS'
                           AND flex_value_set_id IN
                                   (SELECT flex_value_set_id
                                      FROM fnd_flex_value_sets
                                     WHERE flex_value_set_name =
                                           'XXD_AR_TRX_BATCH_OU_VS')
                           AND attribute1 = p_org_id
                           AND attribute3 = NVL (p_trx_type, attribute3);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log (
                               'Update Actual Completion date Error  - '
                            || SUBSTR (SQLERRM, 1, 200));
                END;

                COMMIT;
            END IF;
        END IF;
    END update_value_set;

    -- END of Change for CCR0009036

    --END for CCR0009034

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_as_of_date IN VARCHAR2, p_file_version IN VARCHAR2, p_trx_date_from IN VARCHAR2, p_trx_date_to IN VARCHAR2, p_gl_date_from IN VARCHAR2, p_gl_date_to IN VARCHAR2, p_acct_num_from IN VARCHAR2, p_acct_num_to IN VARCHAR2, p_trx_num_from IN VARCHAR2, p_trx_num_to IN VARCHAR2, p_override IN VARCHAR2, p_batch_source IN VARCHAR2, p_trx_type IN VARCHAR2, p_user_name IN VARCHAR2, p_filename IN VARCHAR2
                    , p_report_mode IN VARCHAR2     -- Added as per CCR0009034
                                               )
    IS
        l_include_style             VARCHAR2 (10) := 'Y';
        l_ret_val                   NUMBER := 0;
        l_from_date                 DATE;
        l_to_date                   DATE;
        l_show_land_cost            VARCHAR2 (30);
        l_custom_cost               VARCHAR2 (20);
        l_regions                   VARCHAR2 (20);
        l_region_ou                 VARCHAR2 (240);
        v_subject                   VARCHAR2 (100);
        l_style                     VARCHAR2 (240);
        l_style_code                VARCHAR2 (240);
        v_employee_order            VARCHAR2 (30);
        v_discount_code             VARCHAR2 (30);
        v_def_mail_recips           apps.do_mail_utils.tbl_recips;
        ex_no_recips                EXCEPTION;
        ex_no_sender                EXCEPTION;
        ex_no_data_found            EXCEPTION;
        ld_run_date                 DATE;
        ld_run_date1                DATE;
        lv_error_code               VARCHAR2 (4000) := NULL;
        ln_error_num                NUMBER;
        lv_error_msg                VARCHAR2 (4000) := NULL;
        lv_status                   VARCHAR2 (10) := 'S';

        -- Start of Change for CCR0009034

        CURSOR lines_data IS
            SELECT *
              FROM xxdo.xxd_ar_drct_debit_t
             WHERE     1 = 1
                   AND process_record = 'Y'
                   --       AND  trx_class in ('INV','DM')
                   AND request_id = gn_request_id;

        CURSOR lines_sum_data IS
              SELECT party_id, data_sent, SUM (amount) amount,
                     SUM (final_amount) final_amount, zipcode, address1,
                     address2, city, country,
                     account_num, cust_account_id, org_id
                FROM xxdo.xxd_ar_drct_debit_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     --AND  trx_class in ('INV','DM','PMT','CM')
                     AND process_record = 'Y'
            GROUP BY party_id, data_sent, zipcode,
                     address1, address2, city,
                     country, account_num, cust_account_id,
                     org_id;

        CURSOR lines_apply_data IS
            SELECT trx_number, trx_id, data_sent,
                   NVL (trx_balance, final_amount) final_amount, amount, zipcode,
                   address1, address2, city,
                   country, account_num, org_id,
                   party_id
              FROM xxdo.xxd_ar_drct_debit_t
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND process_record = 'Y'
                   AND trx_class IN ('INV', 'DM')
                   AND (trx_balance IS NULL OR NVL (trx_balance, 0) <> 0);


        CURSOR lines_cur (pd_run_date DATE)
        IS
            SELECT rcta.trx_number, rcta.customer_trx_id, hca.account_number acct_number,
                   hl_bill.address1 add1, hl_bill.address2 add2, hl_bill.city,
                   hl_bill.state, hl_bill.postal_code zipcode, hl_bill.country,
                   NVL (XXD_AR_DRCT_DEBIT_PKG.discount_cal (rcta.customer_trx_id), apsa.amount_due_original) amount, --               hca_bill.attribute14,                                 --added for CCR0009034
                                                                                                                     --               REPLACE (to_char(round(apsa.amount_due_remaining*(1-(nvl(hca_bill.attribute14,0)/100)),2),'fm99999999999999999999.90'),'.') final_amt,                          -- added for CCR0009034
                                                                                                                     ROUND (apsa.amount_due_remaining * (1 - (NVL (hca_bill.attribute14, 0) / 100)), 2) final_amt, apsa.gl_date,
                   rcta.trx_date, rcta.org_id, DECODE (rcta.global_attribute1, 'Y', 'RC', 'EC') attr1,
                   hp_bill.party_name, hp_bill.party_id, hca_bill.attribute12,
                   hca_bill.attribute13, hca_bill.attribute14, apsa.class,
                   hca.cust_account_id
              FROM hz_cust_site_uses_all hcs_bill, hz_cust_acct_sites_all hca_bill, hz_party_sites hps_bill,
                   hz_parties hp_bill, hz_locations hl_bill, hz_cust_accounts hca,
                   ar_payment_schedules_all apsa, ra_customer_trx_all rcta, apps.ra_cust_trx_types_all rctta
             WHERE     1 = 1
                   AND hcs_bill.cust_acct_site_id =
                       hca_bill.cust_acct_site_id
                   AND hca_bill.party_site_id = hps_bill.party_site_id
                   AND hps_bill.party_id = hp_bill.party_id
                   AND rcta.bill_to_site_use_id = hcs_bill.site_use_id
                   AND hps_bill.location_id = hl_bill.location_id
                   AND hca.cust_account_id = hca_bill.cust_account_id
                   AND rcta.bill_to_customer_id = hca.cust_account_id
                   AND hca.party_id = hp_bill.party_id
                   AND apsa.status = 'OP'
                   AND (CASE
                            WHEN     hca_bill.attribute13 IS NOT NULL
                                 AND hca_bill.attribute14 IS NOT NULL
                                 AND rctta.TYPE <> 'CM'
                            THEN
                                  rcta.trx_date
                                + TO_NUMBER (hca_bill.attribute13)
                            WHEN     rctta.TYPE = 'CM'
                                 AND rcta.trx_date <= pd_run_date - 1 --NVL(p_as_of_date,pd_run_date-1)--rcta.trx_date <= pd_run_date-1
                            THEN
                                pd_run_date - 1
                            ELSE
                                apsa.due_date
                        END BETWEEN (SELECT DISTINCT attribute4
                                       FROM apps.fnd_flex_values
                                      WHERE     flex_value_set_id IN
                                                    (SELECT flex_value_set_id
                                                       FROM fnd_flex_value_sets
                                                      WHERE flex_value_set_name =
                                                            'XXD_AR_TRX_BATCH_OU_VS')
                                            AND attribute1 = p_org_id
                                            AND attribute4 IS NOT NULL
                                            AND NVL (attribute2,
                                                     rcta.batch_source_id) =
                                                rcta.batch_source_id
                                            AND attribute3 =
                                                NVL (p_trx_type, rctta.TYPE))
                                AND pd_run_date - 1)
                   AND hca_bill.attribute12 = 'YES'                  --IS NULL
                   AND apsa.customer_trx_id = rcta.customer_trx_id
                   AND rcta.bill_to_customer_id = hca.cust_account_id
                   AND rctta.org_id = rcta.org_id
                   AND rctta.cust_trx_type_id = rcta.cust_trx_type_id
                   AND hca.cust_account_id = rcta.bill_to_customer_id
                   AND rcta.trx_number BETWEEN NVL (p_trx_num_from,
                                                    rcta.trx_number)
                                           AND NVL (p_trx_num_to,
                                                    rcta.trx_number)
                   AND rcta.org_id = p_org_id
                   AND rcta.batch_source_id =
                       NVL (p_batch_source, rcta.batch_source_id)
                   AND apsa.gl_date BETWEEN NVL (
                                                FND_DATE.CANONICAL_TO_DATE (
                                                    p_gl_date_from),
                                                apsa.gl_date)
                                        AND NVL (
                                                FND_DATE.CANONICAL_TO_DATE (
                                                    p_gl_date_to),
                                                apsa.gl_date)
                   AND rcta.trx_date BETWEEN NVL (
                                                 FND_DATE.CANONICAL_TO_DATE (
                                                     p_trx_date_from),
                                                 rcta.trx_date)
                                         AND NVL (
                                                 FND_DATE.CANONICAL_TO_DATE (
                                                     p_trx_date_to),
                                                 rcta.trx_date)
                   AND hca.cust_account_id BETWEEN NVL (p_acct_num_from,
                                                        hca.cust_account_id)
                                               AND NVL (p_acct_num_to,
                                                        hca.cust_account_id)
                   AND NVL (p_override, 'N') = 'N'
                   AND NVL (rcta.global_attribute1, 'N') = 'N'
                   AND rctta.TYPE = NVL (p_trx_type, rctta.TYPE)
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                             WHERE     ffvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND ffvs.flex_value_set_name =
                                       'XXD_AR_TRX_BATCH_OU_VS'
                                   AND ffvl.enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   ffvl.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   ffvl.end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                   AND ffvl.attribute1 = rcta.org_id
                                   AND NVL (ffvl.attribute2,
                                            rcta.batch_source_id) =
                                       rcta.batch_source_id
                                   AND ffvl.attribute3 =
                                       NVL (p_trx_type, rctta.TYPE))
            UNION ALL
            SELECT rcta.trx_number, rcta.customer_trx_id, hca.account_number acct_number,
                   hl_bill.address1 add1, hl_bill.address2 add2, hl_bill.city,
                   hl_bill.state, hl_bill.postal_code zipcode, hl_bill.country,
                   --apsa.amount_due_original amount,
                   --apsa.amount_due_original final_amt,
                   NVL (XXD_AR_DRCT_DEBIT_PKG.discount_cal (rcta.customer_trx_id), apsa.amount_due_original) amount, ROUND (apsa.amount_due_remaining * (1 - (NVL (hca_bill.attribute14, 0) / 100)), 2) final_amt, apsa.gl_date,
                   rcta.trx_date, rcta.org_id, DECODE (rcta.global_attribute1, 'Y', 'RC', 'EC') attr1,
                   hp_bill.party_name, hp_bill.party_id, hca_bill.attribute12,
                   hca_bill.attribute13, hca_bill.attribute14, apsa.class,
                   hca.cust_account_id
              FROM hz_cust_site_uses_all hcs_bill, hz_cust_acct_sites_all hca_bill, hz_party_sites hps_bill,
                   hz_parties hp_bill, hz_locations hl_bill --     , mtl_parameters mp
                                                           , hz_cust_accounts hca,
                   ar_payment_schedules_all apsa, ra_customer_trx_all rcta, apps.ra_cust_trx_types_all rctta
             WHERE     1 = 1
                   AND hcs_bill.cust_acct_site_id =
                       hca_bill.cust_acct_site_id
                   AND hca_bill.party_site_id = hps_bill.party_site_id
                   AND hps_bill.party_id = hp_bill.party_id
                   AND hps_bill.location_id = hl_bill.location_id
                   AND hca.cust_account_id = hca_bill.cust_account_id
                   AND rcta.bill_to_site_use_id = hcs_bill.site_use_id
                   AND hca.party_id = hp_bill.party_id
                   AND hca_bill.attribute12 = 'YES'                  --IS NULL
                   AND apsa.customer_trx_id = rcta.customer_trx_id
                   AND rcta.bill_to_customer_id = hca.cust_account_id
                   AND rctta.org_id = rcta.org_id
                   AND rctta.cust_trx_type_id = rcta.cust_trx_type_id
                   AND hca.cust_account_id = rcta.bill_to_customer_id
                   AND rcta.trx_number BETWEEN NVL (p_trx_num_from,
                                                    rcta.trx_number)
                                           AND NVL (p_trx_num_to,
                                                    rcta.trx_number)
                   AND rcta.org_id = p_org_id
                   AND rcta.batch_source_id =
                       NVL (p_batch_source, rcta.batch_source_id)
                   AND apsa.gl_date BETWEEN NVL (
                                                FND_DATE.CANONICAL_TO_DATE (
                                                    p_gl_date_from),
                                                apsa.gl_date)
                                        AND NVL (
                                                FND_DATE.CANONICAL_TO_DATE (
                                                    p_gl_date_to),
                                                apsa.gl_date)
                   AND rcta.trx_date BETWEEN NVL (
                                                 FND_DATE.CANONICAL_TO_DATE (
                                                     p_trx_date_from),
                                                 rcta.trx_date)
                                         AND NVL (
                                                 FND_DATE.CANONICAL_TO_DATE (
                                                     p_trx_date_to),
                                                 rcta.trx_date)
                   AND hca.cust_account_id BETWEEN NVL (p_acct_num_from,
                                                        hca.cust_account_id)
                                               AND NVL (p_acct_num_to,
                                                        hca.cust_account_id)
                   AND p_override = 'Y'
                   AND (CASE
                            WHEN     hca_bill.attribute13 IS NOT NULL
                                 AND hca_bill.attribute14 IS NOT NULL
                                 AND rctta.TYPE <> 'CM'
                            THEN
                                  rcta.trx_date
                                + TO_NUMBER (hca_bill.attribute13)
                            WHEN     rctta.TYPE = 'CM'
                                 AND rcta.trx_date <= pd_run_date - 1 --AND rcta.trx_date <= pd_run_date-1
                            THEN
                                pd_run_date - 1
                            ELSE
                                apsa.due_date
                        END BETWEEN (SELECT DISTINCT attribute4
                                       FROM apps.fnd_flex_values
                                      WHERE     flex_value_set_id IN
                                                    (SELECT flex_value_set_id
                                                       FROM fnd_flex_value_sets
                                                      WHERE flex_value_set_name =
                                                            'XXD_AR_TRX_BATCH_OU_VS')
                                            AND attribute1 = p_org_id
                                            AND attribute4 IS NOT NULL
                                            AND NVL (attribute2,
                                                     rcta.batch_source_id) =
                                                rcta.batch_source_id
                                            AND attribute3 =
                                                NVL (p_trx_type, rctta.TYPE))
                                AND pd_run_date - 1)
                   AND rctta.TYPE = NVL (p_trx_type, rctta.TYPE)
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                             WHERE     ffvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND ffvs.flex_value_set_name =
                                       'XXD_AR_TRX_BATCH_OU_VS'
                                   AND ffvl.enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   ffvl.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   ffvl.end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                   AND ffvl.attribute1 = rcta.org_id
                                   AND NVL (ffvl.attribute2,
                                            rcta.batch_source_id) =
                                       rcta.batch_source_id
                                   AND ffvl.attribute3 =
                                       NVL (p_trx_type, rctta.TYPE))
            UNION ALL
            -- Added for CCR0009034
            SELECT DISTINCT rcra.receipt_number trx_number, rcra.cash_receipt_id customer_trx_id, hca.account_number acct_number,
                            hl_bill.address1 add1, hl_bill.address2 add2, hl_bill.city,
                            hl_bill.state, hl_bill.postal_code zipcode, hl_bill.country,
                            apsa.amount_due_remaining amount, --               hca_bill.attribute14,
                                                              --               REPLACE (to_char(round(apsa.amount_due_remaining,2),'fm99999999999999999999.90'), '.')         final_amt,
                                                              ROUND (apsa.amount_due_remaining, 2) final_amt, apsa.gl_date,
                            rcra.receipt_date trx_date, rcra.org_id, DECODE (rcra.global_attribute1, 'Y', 'RC', 'EC') attr1,
                            hp_bill.party_name, hp_bill.party_id, hca_bill.attribute12,
                            hca_bill.attribute13, hca_bill.attribute14, apsa.class,
                            hca.cust_account_id
              FROM hz_cust_site_uses_all hcs_bill, hz_cust_acct_sites_all hca_bill, hz_party_sites hps_bill,
                   hz_parties hp_bill, hz_locations hl_bill, hz_cust_accounts hca,
                   ar_payment_schedules_all apsa, ar_cash_receipts_all rcra
             WHERE     1 = 1
                   AND hcs_bill.cust_acct_site_id =
                       hca_bill.cust_acct_site_id
                   AND hca_bill.party_site_id = hps_bill.party_site_id
                   AND hps_bill.party_id = hp_bill.party_id
                   AND hps_bill.status = 'A'
                   AND hca.status = 'A'
                   AND hp_bill.status = 'A'
                   AND hcs_bill.status = 'A'
                   AND hca_bill.status = 'A'
                   AND hcs_bill.site_use_code = 'BILL_TO'
                   AND hps_bill.location_id = hl_bill.location_id
                   AND hca.cust_account_id = hca_bill.cust_account_id
                   AND hcs_bill.primary_flag = 'Y'
                   AND hca.party_id = hp_bill.party_id
                   AND hca_bill.attribute12 = 'YES'
                   AND NVL (rcra.global_attribute1, 'N') = 'N'
                   AND apsa.cash_receipt_id = rcra.cash_receipt_id
                   AND class = 'PMT'
                   --               AND amount_due_remaining > 0
                   AND apsa.status = 'OP'
                   AND rcra.pay_from_customer = hca.cust_account_id -- Added New
                   AND rcra.receipt_number BETWEEN NVL (p_trx_num_from,
                                                        rcra.receipt_number)
                                               AND NVL (p_trx_num_to,
                                                        rcra.receipt_number)
                   AND rcra.org_id = p_org_id
                   AND apsa.gl_date BETWEEN NVL (
                                                FND_DATE.CANONICAL_TO_DATE (
                                                    p_gl_date_from),
                                                apsa.gl_date)
                                        AND NVL (
                                                FND_DATE.CANONICAL_TO_DATE (
                                                    p_gl_date_to),
                                                apsa.gl_date)
                   AND rcra.receipt_date BETWEEN NVL (
                                                     FND_DATE.CANONICAL_TO_DATE (
                                                         p_trx_date_from),
                                                     rcra.receipt_date)
                                             AND NVL (
                                                     FND_DATE.CANONICAL_TO_DATE (
                                                         p_trx_date_to),
                                                     rcra.receipt_date)
                   AND hca.cust_account_id BETWEEN NVL (p_acct_num_from,
                                                        hca.cust_account_id)
                                               AND NVL (p_acct_num_to,
                                                        hca.cust_account_id)
                   AND NVL (p_override, 'N') = 'N'
            --               AND EXISTS
            --                       (SELECT 1
            --                          FROM apps.fnd_flex_value_sets  ffvs,
            --                               apps.fnd_flex_values_vl   ffvl
            --                         WHERE     ffvs.flex_value_set_id =
            --                                   ffvl.flex_value_set_id
            --                               AND ffvs.flex_value_set_name =
            --                                   'XXD_AR_TRX_BATCH_OU_VS'
            --                               AND ffvl.enabled_flag = 'Y'
            --                               AND TRUNC (SYSDATE) BETWEEN NVL (
            --                                                               ffvl.start_date_active,
            --                                                               TRUNC (
            --                                                                   SYSDATE))
            --                                                       AND NVL (
            --                                                               ffvl.end_date_active,
            --                                                               TRUNC (
            --                                                                   SYSDATE))
            --                               AND ffvl.attribute1 = rcra.org_id
            --                               AND NVL (p_trx_type, ffvl.attribute3) =
            --                                   NVL (p_trx_type, rcra.TYPE))
            UNION ALL
            SELECT DISTINCT rcra.receipt_number trx_number, rcra.cash_receipt_id customer_trx_id, hca.account_number acct_number,
                            hl_bill.address1 add1, hl_bill.address2 add2, hl_bill.city,
                            hl_bill.state, hl_bill.postal_code zipcode, hl_bill.country,
                            apsa.amount_due_remaining amount, --               hca_bill.attribute14,
                                                              --               REPLACE (to_char(round(apsa.amount_due_remaining,2),'fm99999999999999999999.90'), '.')         final_amt,
                                                              ROUND (apsa.amount_due_remaining, 2) final_amt, apsa.gl_date,
                            rcra.receipt_date trx_date, rcra.org_id, DECODE (rcra.global_attribute1, 'Y', 'RC', 'EC') attr1,
                            hp_bill.party_name, hp_bill.party_id, hca_bill.attribute12,
                            hca_bill.attribute13, hca_bill.attribute14, apsa.class,
                            hca.cust_account_id
              FROM hz_cust_site_uses_all hcs_bill, hz_cust_acct_sites_all hca_bill, hz_party_sites hps_bill,
                   hz_parties hp_bill, hz_locations hl_bill, hz_cust_accounts hca,
                   ar_payment_schedules_all apsa, ar_cash_receipts_all rcra
             WHERE     1 = 1
                   AND hcs_bill.cust_acct_site_id =
                       hca_bill.cust_acct_site_id
                   AND hca_bill.party_site_id = hps_bill.party_site_id
                   AND hps_bill.party_id = hp_bill.party_id
                   AND hps_bill.status = 'A'
                   AND hca.status = 'A'
                   AND hp_bill.status = 'A'
                   AND hcs_bill.status = 'A'
                   AND hca_bill.status = 'A'
                   AND hcs_bill.site_use_code = 'BILL_TO'
                   AND hps_bill.location_id = hl_bill.location_id
                   AND hca.cust_account_id = hca_bill.cust_account_id
                   AND hcs_bill.primary_flag = 'Y'
                   AND hca.party_id = hp_bill.party_id
                   AND hca_bill.attribute12 = 'YES'
                   AND apsa.cash_receipt_id = rcra.cash_receipt_id
                   AND class = 'PMT'
                   --               AND amount_due_remaining > 0
                   AND apsa.status = 'OP'
                   AND rcra.pay_from_customer = hca.cust_account_id -- Added New
                   AND rcra.receipt_number BETWEEN NVL (p_trx_num_from,
                                                        rcra.receipt_number)
                                               AND NVL (p_trx_num_to,
                                                        rcra.receipt_number)
                   AND rcra.org_id = p_org_id
                   AND apsa.gl_date BETWEEN NVL (
                                                FND_DATE.CANONICAL_TO_DATE (
                                                    p_gl_date_from),
                                                apsa.gl_date)
                                        AND NVL (
                                                FND_DATE.CANONICAL_TO_DATE (
                                                    p_gl_date_to),
                                                apsa.gl_date)
                   AND rcra.receipt_date BETWEEN NVL (
                                                     FND_DATE.CANONICAL_TO_DATE (
                                                         p_trx_date_from),
                                                     rcra.receipt_date)
                                             AND NVL (
                                                     FND_DATE.CANONICAL_TO_DATE (
                                                         p_trx_date_to),
                                                     rcra.receipt_date)
                   AND hca.cust_account_id BETWEEN NVL (p_acct_num_from,
                                                        hca.cust_account_id)
                                               AND NVL (p_acct_num_to,
                                                        hca.cust_account_id)
                   AND p_override = 'Y'--               AND EXISTS
                                       --                       (SELECT 1
                                       --                          FROM apps.fnd_flex_value_sets  ffvs,
                                       --                               apps.fnd_flex_values_vl   ffvl
                                       --                         WHERE     ffvs.flex_value_set_id =
                                       --                                   ffvl.flex_value_set_id
                                       --                               AND ffvs.flex_value_set_name =
                                       --                                   'XXD_AR_TRX_BATCH_OU_VS'
                                       --                               AND ffvl.enabled_flag = 'Y'
                                       --                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                       --                                                               ffvl.start_date_active,
                                       --                                                               TRUNC (
                                       --                                                                   SYSDATE))
                                       --                                                       AND NVL (
                                       --                                                               ffvl.end_date_active,
                                       --                                                               TRUNC (
                                       --                                                                   SYSDATE))
                                       --                               AND ffvl.attribute1 = rcra.org_id
                                       --                               AND NVL (p_trx_type, ffvl.attribute3) =
                                       --                                   NVL (p_trx_type, rcra.TYPE))
                                       ;

        TYPE lines_cur_tab IS TABLE OF lines_cur%ROWTYPE;

        --INDEX BY BINARY_INTEGER;

        v_lines_cur_tab             lines_cur_tab;

        v_bulk_limit                NUMBER := 5000;
        le_bulk_inst_exe            EXCEPTION;
        PRAGMA EXCEPTION_INIT (le_bulk_inst_exe, -24381);
        l_msg                       VARCHAR2 (4000);
        l_idx                       NUMBER;
        l_error_count               NUMBER;

        lv_ver                      VARCHAR2 (32767) := NULL;
        lv_line                     VARCHAR2 (32767) := NULL;
        lv_output                   VARCHAR2 (360);
        lv_delimiter                VARCHAR2 (5) := CHR (9);
        lv_file_delimiter           VARCHAR2 (1) := ',';
        ln_count                    NUMBER;
        ln_flex_count               NUMBER;
        ln_record_count             NUMBER;
        ln_actual_completion_date   DATE;

        ln_det_rec_count            NUMBER;
        ln_sum_rec_count            NUMBER;
        ln_apply_rec_count          NUMBER;
    BEGIN
        IF p_as_of_date IS NOT NULL
        THEN
            ld_run_date   := FND_DATE.CANONICAL_TO_DATE (p_as_of_date) + 1;
        ELSE
            ld_run_date   := TRUNC (SYSDATE);
        END IF;

        --        IF TRUNC(ld_run_date) = TRUNC(SYSDATE)
        --        THEN
        --            ld_run_date := TRUNC(SYSDATE)-1;
        --            ld_run_date1 :=
        --        END IF;

        --        ld_run_date := trunc(sysdate);

        ln_flex_count     := 0;
        ln_count          := 0;
        ln_record_count   := 0;

        write_log (
            'Start Time: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        write_log ('Org ID is : ' || p_org_id);

        write_log ('As of Date is : ' || p_as_of_date);

        write_log ('File Version is : ' || p_file_version);

        write_log ('p_trx_date_from is : ' || p_trx_date_from);

        write_log ('p_trx_date_to is : ' || p_trx_date_to);

        write_log ('p_gl_date_from is : ' || p_gl_date_from);

        write_log ('p_trx_date_to is : ' || p_gl_date_to);

        write_log ('p_acct_num_from is : ' || p_acct_num_from);

        write_log ('p_acct_num_to is : ' || p_acct_num_to);

        write_log ('p_trx_num_from is : ' || p_trx_num_from);

        write_log ('p_trx_num_to is : ' || p_trx_num_to);

        write_log ('p_override is : ' || p_override);

        write_log ('p_trx_type is : ' || p_trx_type);

        write_log ('p_batch_source is : ' || p_batch_source);

        write_log ('p_user_name is : ' || p_user_name);

        write_log ('p_filename is : ' || p_filename);

        write_log ('p_report_mode is : ' || p_report_mode);

        --        xxv_debug_prc(' Start of the Program!!');

        BEGIN
            SELECT COUNT (1)
              INTO ln_flex_count
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
             WHERE     ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvs.flex_value_set_name = 'XXD_AR_TRX_BATCH_OU_VS'
                   AND ffvl.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (ffvl.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (ffvl.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND ffvl.attribute1 = p_org_id
                   AND NVL (ffvl.attribute2, 'ABC') =
                       NVL (p_batch_source, NVL (ffvl.attribute2, 'ABC'))
                   AND ffvl.attribute3 = NVL (p_trx_type, ffvl.attribute3);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_flex_count   := 0;
        END;

        IF ln_flex_count = 0
        THEN
            --            xxv_debug_prc(' Start of the Program with Flex Count - '||ln_flex_count);

            write_log (
                ' There are no records that match the OU to Transaction class, please check Valueset XXD_AR_TRX_BATCH_OU_VS for details');
        ELSIF ln_flex_count > 0
        THEN
            --            xxv_debug_prc(' Start of the Program with Flex Count - '||ln_flex_count);

            ln_record_count   := 0;

            BEGIN
                OPEN lines_cur (ld_run_date);

                LOOP
                    FETCH lines_cur
                        BULK COLLECT INTO v_lines_cur_tab
                        LIMIT v_bulk_limit;

                    ln_record_count   := v_lines_cur_tab.COUNT;

                    write_log (
                        ' Total record count is - ' || ln_record_count);

                    BEGIN
                        IF v_lines_cur_tab.COUNT > 0
                        THEN
                            FORALL i IN 1 .. v_lines_cur_tab.COUNT
                              SAVE EXCEPTIONS
                                INSERT INTO xxdo.xxd_ar_drct_debit_t (
                                                trx_number,
                                                trx_id,
                                                account_num,
                                                party_name,
                                                party_id,
                                                address1,
                                                address2,
                                                city,
                                                state,
                                                zipcode,
                                                country,
                                                amount,
                                                final_amount,
                                                gl_date,
                                                trx_date,
                                                org_id,
                                                direct_debit_customer,
                                                discount_days,
                                                discount_percent,
                                                data_sent,
                                                trx_class,
                                                cust_account_id,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_updated_by,
                                                last_update_date)
                                         VALUES (
                                                    v_lines_cur_tab (i).trx_number,
                                                    v_lines_cur_tab (i).customer_trx_id,
                                                    v_lines_cur_tab (i).acct_number,
                                                    v_lines_cur_tab (i).party_name,
                                                    v_lines_cur_tab (i).party_id,
                                                    v_lines_cur_tab (i).add1,
                                                    v_lines_cur_tab (i).add2,
                                                    v_lines_cur_tab (i).city,
                                                    v_lines_cur_tab (i).state,
                                                    v_lines_cur_tab (i).zipcode,
                                                    v_lines_cur_tab (i).country,
                                                    v_lines_cur_tab (i).amount,
                                                    v_lines_cur_tab (i).final_amt,
                                                    v_lines_cur_tab (i).gl_date,
                                                    v_lines_cur_tab (i).trx_date,
                                                    v_lines_cur_tab (i).org_id,
                                                    v_lines_cur_tab (i).attribute12,
                                                    v_lines_cur_tab (i).attribute13,
                                                    v_lines_cur_tab (i).attribute14,
                                                    v_lines_cur_tab (i).attr1,
                                                    v_lines_cur_tab (i).class,
                                                    v_lines_cur_tab (i).cust_account_id,
                                                    gn_request_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    gn_user_id,
                                                    SYSDATE);

                            COMMIT;
                        ELSE
                            NULL;
                        --                         xxv_debug_prc(' Else Insertion');

                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            --                    xxv_debug_prc(' Start of Other Exception');

                            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                            LOOP
                                ln_error_num   :=
                                    SQL%BULK_EXCEPTIONS (j).ERROR_INDEX;
                                lv_error_code   :=
                                    SQLERRM (
                                          -1
                                        * SQL%BULK_EXCEPTIONS (j).ERROR_CODE);
                                lv_error_msg   :=
                                    SUBSTR (
                                        (lv_error_msg || ' Error While Insert into Table ' || v_lines_cur_tab (ln_error_num).customer_trx_id || ' ' || lv_error_code || CHR (10)),
                                        1,
                                        4000);

                                write_log (lv_error_msg);
                            -- lv_status := 'E';

                            END LOOP;

                            --                     xxv_debug_prc(' End Loop and Raised Exception');

                            RAISE le_bulk_inst_exe;
                    END;

                    --                xxv_debug_prc(' Just Before End Loop and exit');

                    v_lines_cur_tab.delete;

                    EXIT WHEN v_lines_cur_tab.COUNT = 0;
                END LOOP;

                CLOSE lines_cur;
            EXCEPTION
                WHEN le_bulk_inst_exe
                THEN
                    --               xxv_debug_prc(' Bulk Exception');
                    write_log (
                        'Error While Inserting Into Table ' || SQLERRM);
                WHEN OTHERS
                THEN
                    --               xxv_debug_prc(' Bulk Others Exception');
                    write_log (
                        'Error While Inserting Into Table ' || SQLERRM);
            END;

            -- Uncomment after Testing - 01/19

            --            xxv_debug_prc(' Before Update Stmt');

            UPDATE xxdo.xxd_ar_drct_debit_t stg
               SET stg.process_record   = 'Y'
             WHERE     1 = 1
                   AND stg.account_num IN
                           (  SELECT stg1.account_num
                                FROM xxdo.xxd_ar_drct_debit_t stg1
                               WHERE     1 = 1
                                     AND stg1.request_id = stg.request_id
                                     AND stg.account_num = stg1.account_num
                            GROUP BY stg1.account_num
                              --HAVING  SUM(stg1.amount) > 0
                              HAVING SUM (stg1.final_amount) > 0)
                   AND stg.request_id = gn_request_id;

            COMMIT;
        END IF;

        IF p_report_mode = 'DETAIL'
        THEN
            ln_det_rec_count   := 0;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_det_rec_count
                  FROM xxdo.xxd_ar_drct_debit_t
                 WHERE     1 = 1
                       AND process_record = 'Y'
                       AND request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_det_rec_count   := 0;
            END;

            lv_delimiter       := CHR (9);
            lv_ver             :=
                   'H'
                || lv_delimiter
                || '1'
                || lv_delimiter
                || p_file_version
                || lv_delimiter
                || NVL (p_user_name, 'TVTACELOTTO001')
                || lv_delimiter
                || NVL (p_filename, TO_CHAR (SYSDATE, 'DDMMHH24MI'))
                || lv_delimiter
                || ln_det_rec_count
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || '';

            --Printing Output
            --            lv_output := '***Deckers Direct Debit Report***';
            --            apps.fnd_file.put_line (apps.fnd_file.output, lv_output);

            lv_ver             :=
                REPLACE (lv_ver, lv_delimiter, lv_file_delimiter);

            fnd_file.put_line (fnd_file.output, lv_ver);

            ln_count           := 0;

            /* LOOP THROUGH AR Tranactions */
            FOR i IN lines_data
            LOOP
                BEGIN
                    ln_count   := ln_count + 1;
                    lv_line    :=
                           REPLACE ('D', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (ln_count, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('O', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('AC', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.trx_number, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.data_sent, CHR (9), ' ')
                        || lv_delimiter
                        --|| REPLACE (i.final_amount, CHR (9), ' ')
                        || REPLACE (
                               TO_CHAR (i.final_amount,
                                        'fm99999999999999999999.90'),
                               '.')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.zipcode, CHR (9), ' ')
                        || lv_delimiter
                        || SUBSTR (
                               REPLACE (REPLACE (i.address1, ',', ' '),
                                        CHR (9),
                                        ' '),
                               1,
                               12)
                        || lv_delimiter
                        || SUBSTR (
                               REPLACE (REPLACE (i.address2, ',', ' '),
                                        CHR (9),
                                        ' '),
                               1,
                               12)
                        || lv_delimiter
                        || REPLACE (i.city, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.country, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.account_num, CHR (9), ' ');


                    --apps.fnd_file.put_line (apps.fnd_file.output, lv_line);


                    lv_line    :=
                        REPLACE (lv_line, lv_delimiter, lv_file_delimiter);

                    fnd_file.put_line (fnd_file.output, lv_line);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log ('Error is - ' || SUBSTR (SQLERRM, 1, 200));
                END;
            END LOOP;
        ELSIF p_report_mode = 'APPLY'
        THEN
            apply_mode_prc (gn_request_id);

            ln_apply_rec_count   := 0;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_apply_rec_count
                  FROM xxdo.xxd_ar_drct_debit_t
                 WHERE     1 = 1
                       AND request_id = gn_request_id
                       AND process_record = 'Y'
                       AND trx_class IN ('INV', 'DM')
                       AND (trx_balance IS NULL OR NVL (trx_balance, 0) <> 0);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_apply_rec_count   := 0;
            END;

            lv_delimiter         := CHR (9);
            lv_ver               :=
                   'H'
                || lv_delimiter
                || '1'
                || lv_delimiter
                || p_file_version
                || lv_delimiter
                || NVL (p_user_name, 'TVTACELOTTO001')
                || lv_delimiter
                || NVL (p_filename, TO_CHAR (SYSDATE, 'DDMMHH24MI'))
                || lv_delimiter
                || ln_apply_rec_count
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || '';

            --Printing Output
            --            lv_output := '***Deckers Direct Debit Report***';
            --            apps.fnd_file.put_line (apps.fnd_file.output, lv_output);

            lv_ver               :=
                REPLACE (lv_ver, lv_delimiter, lv_file_delimiter);

            fnd_file.put_line (fnd_file.output, lv_ver);

            ln_count             := 0;

            /* LOOP THROUGH AR Tranactions */
            FOR i IN lines_apply_data
            LOOP
                BEGIN
                    ln_count   := ln_count + 1;
                    lv_line    :=
                           REPLACE ('D', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (ln_count, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('O', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('AC', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.trx_number, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.data_sent, CHR (9), ' ')
                        || lv_delimiter
                        --|| REPLACE (i.final_amount, CHR (9), ' ')
                        || REPLACE (
                               TO_CHAR (i.final_amount,
                                        'fm99999999999999999999.90'),
                               '.')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.zipcode, CHR (9), ' ')
                        || lv_delimiter
                        || SUBSTR (
                               REPLACE (REPLACE (i.address1, ',', ' '),
                                        CHR (9),
                                        ' '),
                               1,
                               12)
                        || lv_delimiter
                        || SUBSTR (
                               REPLACE (REPLACE (i.address2, ',', ' '),
                                        CHR (9),
                                        ' '),
                               1,
                               12)
                        || lv_delimiter
                        || REPLACE (i.city, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.country, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.account_num, CHR (9), ' ');

                    --apps.fnd_file.put_line (apps.fnd_file.output, lv_line);

                    lv_line    :=
                        REPLACE (lv_line, lv_delimiter, lv_file_delimiter);

                    fnd_file.put_line (fnd_file.output, lv_line);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log ('Error is - ' || SUBSTR (SQLERRM, 1, 200));
                END;
            END LOOP;

            -- Uncomment after Testing - 01/19

            BEGIN
                UPDATE ra_customer_trx_all rcta
                   SET global_attribute1   = 'Y'
                 WHERE     org_id = p_org_id
                       --AND customer_trx_id = i.trx_id
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_ar_drct_debit_t debt
                                 WHERE     debt.trx_id = rcta.customer_trx_id
                                       AND debt.request_id = gn_request_id
                                       AND debt.org_id = rcta.org_id
                                       AND debt.trx_class IN ('INV', 'DM')
                                       AND debt.process_record = 'Y'
                                       AND NVL (debt.trx_balance, 1) = 0
                                       AND rcta.org_id = debt.org_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            BEGIN
                UPDATE ra_customer_trx_all rcta
                   SET global_attribute1   = 'Y'
                 WHERE     org_id = p_org_id
                       --AND customer_trx_id = i.trx_id
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_ar_drct_debit_t debt
                                 WHERE     debt.trx_id = rcta.customer_trx_id
                                       AND debt.request_id = gn_request_id
                                       AND debt.org_id = rcta.org_id
                                       AND debt.trx_class IN ('CM')
                                       AND debt.process_record = 'Y'
                                       AND rcta.org_id = debt.org_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            BEGIN
                UPDATE ar_cash_receipts_all arca
                   SET global_attribute1   = 'Y'
                 WHERE     org_id = p_org_id
                       --AND cash_receipt_id = i.trx_id
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_ar_drct_debit_t debt
                                 WHERE     debt.trx_id = arca.cash_receipt_id
                                       AND debt.trx_class IN ('PMT')
                                       AND debt.process_record = 'Y'
                                       AND arca.org_id = debt.org_id
                                       AND debt.request_id = gn_request_id
                                       AND debt.org_id = arca.org_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            update_value_set (p_org_id          => p_org_id,
                              p_trx_date_from   => p_trx_date_from,
                              p_trx_date_to     => p_trx_date_to,
                              p_gl_date_from    => p_gl_date_from,
                              p_gl_date_to      => p_gl_date_to,
                              p_acct_num_from   => p_acct_num_from,
                              p_acct_num_to     => p_acct_num_to,
                              p_trx_num_from    => p_trx_num_from,
                              p_trx_num_to      => p_trx_num_to,
                              p_override        => p_override,
                              p_batch_source    => p_batch_source,
                              p_trx_type        => p_trx_type);
        ELSIF p_report_mode = 'SUMMARY'
        THEN
            --apply_mode_prc(gn_request_id);

            ln_sum_rec_count   := 0;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_sum_rec_count
                  FROM (  SELECT party_id, data_sent, SUM (amount) amount,
                                 SUM (final_amount) final_amount, zipcode, address1,
                                 address2, city, country,
                                 account_num, cust_account_id, org_id
                            FROM xxdo.xxd_ar_drct_debit_t
                           WHERE     1 = 1
                                 AND request_id = gn_request_id
                                 --                           AND  trx_class in ('INV','DM')
                                 AND process_record = 'Y'
                        GROUP BY party_id, data_sent, zipcode,
                                 address1, address2, city,
                                 country, account_num, cust_account_id,
                                 org_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sum_rec_count   := 0;
            END;

            lv_delimiter       := CHR (9);
            lv_ver             :=
                   'H'
                || lv_delimiter
                || '1'
                || lv_delimiter
                || p_file_version
                || lv_delimiter
                || NVL (p_user_name, 'TVTACELOTTO001')
                || lv_delimiter
                || NVL (p_filename, TO_CHAR (SYSDATE, 'DDMMHH24MI'))
                || lv_delimiter
                || ln_sum_rec_count
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || ''
                || lv_delimiter
                || '';

            --Printing Output
            --            lv_output := '***Deckers Direct Debit Report***';
            --            apps.fnd_file.put_line (apps.fnd_file.output, lv_output);

            lv_ver             :=
                REPLACE (lv_ver, lv_delimiter, lv_file_delimiter);

            fnd_file.put_line (fnd_file.output, lv_ver);

            ln_count           := 0;

            /* LOOP THROUGH AR Tranactions */

            FOR i IN lines_sum_data
            LOOP
                BEGIN
                    ln_count   := ln_count + 1;

                    lv_line    :=
                           REPLACE ('D', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (ln_count, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('O', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('AC', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.Party_id, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.data_sent, CHR (9), ' ')
                        || lv_delimiter
                        --|| REPLACE (i.final_amount, CHR (9), ' ')
                        || REPLACE (
                               TO_CHAR (i.final_amount,
                                        'fm99999999999999999999.90'),
                               '.')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.zipcode, CHR (9), ' ')
                        || lv_delimiter
                        || SUBSTR (
                               REPLACE (REPLACE (i.address1, ',', ' '),
                                        CHR (9),
                                        ' '),
                               1,
                               12)
                        || lv_delimiter
                        || SUBSTR (
                               REPLACE (REPLACE (i.address2, ',', ' '),
                                        CHR (9),
                                        ' '),
                               1,
                               12)
                        || lv_delimiter
                        || REPLACE (i.city, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE ('', CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.country, CHR (9), ' ')
                        || lv_delimiter
                        || REPLACE (i.account_num, CHR (9), ' ');


                    --apps.fnd_file.put_line (apps.fnd_file.output, lv_line);

                    lv_line    :=
                        REPLACE (lv_line, lv_delimiter, lv_file_delimiter);

                    fnd_file.put_line (fnd_file.output, lv_line);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log ('Error is - ' || SUBSTR (SQLERRM, 1, 200));
                END;

                BEGIN
                    UPDATE ra_customer_trx_all rcta
                       SET global_attribute1   = 'Y'
                     WHERE     org_id = i.org_id
                           --AND customer_trx_id = i.trx_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxd_ar_drct_debit_t debt
                                     WHERE     debt.trx_id =
                                               rcta.customer_trx_id
                                           AND debt.request_id =
                                               gn_request_id);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                BEGIN
                    UPDATE ar_cash_receipts_all rcra
                       SET global_attribute1   = 'Y'
                     WHERE     org_id = i.org_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxd_ar_drct_debit_t debt
                                     WHERE     debt.trx_id =
                                               rcra.cash_receipt_id
                                           AND debt.request_id =
                                               gn_request_id
                                           AND debt.org_id = rcra.org_id
                                           AND debt.trx_class IN ('PMT'));

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END LOOP;

            update_value_set (p_org_id          => p_org_id,
                              p_trx_date_from   => p_trx_date_from,
                              p_trx_date_to     => p_trx_date_to,
                              p_gl_date_from    => p_gl_date_from,
                              p_gl_date_to      => p_gl_date_to,
                              p_acct_num_from   => p_acct_num_from,
                              p_acct_num_to     => p_acct_num_to,
                              p_trx_num_from    => p_trx_num_from,
                              p_trx_num_to      => p_trx_num_to,
                              p_override        => p_override,
                              p_batch_source    => p_batch_source,
                              p_trx_type        => p_trx_type);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                ' Main Exception Error is - ' || SUBSTR (SQLERRM, 1, 200));
    END;
END XXD_AR_DRCT_DEBIT_PKG;
/
