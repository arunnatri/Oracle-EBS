--
-- XXD_AR_CONCESSIONS_TRX_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_CONCESSIONS_TRX_PKG"
AS
    --  ####################################################################################################
    --  Author(s)       : Kranthi Bollam (Suneratech Consultant)
    --  System          : Oracle Applications
    --  Subsystem       : EBS
    --  Change          : ENHC0013435(CCR0007174)
    --  Schema          : APPS
    --  Purpose         : Package is used to create AR transactions for the Concession Stores sales
    --  Dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  15-May-2018     Kranthi Bollam      1.0     NA              Initial Version
    --  06-Aug-2018     Kranthi Bollam      1.1     UAT Defect#13   Transactions to be created for Closed
    --                                                              period Dates records with current open
    --                                                              period date
    --  10-May-2020     Shivanshu Talwar    1.2     CCR0008619      interface_line_attribute6 Date format issue
    --  ####################################################################################################
    --Global Variables declaration
    gv_package_name      CONSTANT VARCHAR2 (30) := 'XXD_AR_CONCESSIONS_TRX_PKG.';
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    --gn_org_id               CONSTANT    NUMBER          :=  fnd_profile.value('ORG_ID');
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_conc_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    gc_sales_credits     CONSTANT VARCHAR2 (50) := 'Sales/Credits';
    gc_ancillary1        CONSTANT VARCHAR2 (50) := 'Ancillary1';
    gc_ancillary2        CONSTANT VARCHAR2 (50) := 'Ancillary2';
    gv_program_mode               VARCHAR2 (30) := NULL;
    gv_version                    VARCHAR2 (30) := NULL;
    gv_as_of_date                 VARCHAR2 (30) := NULL;
    gv_store_number               VARCHAR2 (15) := NULL;
    gn_store_number               NUMBER := NULL;
    gv_brand                      VARCHAR2 (30) := NULL;
    gd_as_of_date                 DATE := NULL;
    gv_trx_date_from              VARCHAR2 (30) := NULL;
    gv_trx_date_to                VARCHAR2 (30) := NULL;
    gd_trx_date_from              DATE := NULL;
    gd_trx_date_to                DATE := NULL;
    gv_reprocess_flag             VARCHAR2 (1) := NULL;
    gv_use_curr_per_dt            VARCHAR2 (1) := NULL;

    --Procedure to print messages into either log or output files
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print time or not. Default is no.
    --PV_FILE       Print to LOG or OUTPUT file. Default write it to LOG file
    PROCEDURE msg (pv_msg    IN VARCHAR2,
                   pv_time   IN VARCHAR2 DEFAULT 'N',
                   pv_file   IN VARCHAR2 DEFAULT 'LOG')
    IS
        --Local Variables
        lv_proc_name    VARCHAR2 (30) := 'MSG';
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

        IF UPPER (pv_file) = 'OUT'
        THEN
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.output, lv_msg);
            END IF;
        ELSE
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, lv_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In When Others exception in '
                || gv_package_name
                || '.'
                || lv_proc_name
                || ' procedure. Error is: '
                || SQLERRM);
    END msg;

    --Function to replace text for Amount basis logic
    FUNCTION replace_text (p_text    IN VARCHAR2,
                           p_parse   IN xxd_ar_conc_tbl_varchar2)
        RETURN VARCHAR2
    IS
        lv_text       VARCHAR2 (32767);
        ln_position   NUMBER;
        lv_value      VARCHAR2 (250);

        CURSOR param_cur (cn_position NUMBER)
        IS
            SELECT VAL
              FROM (SELECT VAL, ROWNUM AS RN
                      FROM (SELECT COLUMN_VALUE VAL FROM TABLE (p_parse)))
             WHERE RN = cn_position + 1;
    BEGIN
        lv_text   := p_text;

        FOR i IN 1 .. REGEXP_COUNT (p_text, '[{][0-9]+[}]')
        LOOP
            ln_position   :=
                TO_NUMBER (SUBSTR (REGEXP_SUBSTR (p_text, '[{][0-9]+[}]', 1,
                                                  i),
                                   2,
                                     LENGTH (REGEXP_SUBSTR (p_text, '[{][0-9]+[}]', 1
                                                            , i))
                                   - 2));

            OPEN param_cur (ln_position);

            FETCH param_cur INTO lv_value;

            IF param_cur%FOUND
            THEN
                lv_text   :=
                    REPLACE (lv_text,
                             REGEXP_SUBSTR (p_text, '[{][0-9]+[}]', 1,
                                            i),
                             lv_value);
            END IF;

            CLOSE param_cur;
        END LOOP;

        RETURN lv_text;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN p_text;
    END replace_text;

    PROCEDURE print_trxns (pn_request_id IN NUMBER)
    IS
        --Local Variables Declaration
        lv_proc_name         VARCHAR2 (30) := 'PRINT_TRXNS';
        lv_draft_trn_dtls    VARCHAR2 (4000) := NULL;
        ln_mode_amount       NUMBER := 0;
        lv_print_trxns_cnt   NUMBER := 0;


        CURSOR c_print_trxns IS
              SELECT gv_program_mode || '|' --               || sequence_id
                                            --               || '|'
                                            || brand || '|' || store_number || '|' || rms_tran_seq_no || '|' || transaction_date || '|' || retail_amount || '|' || discount_amount || '|' || paytotal_amount || '|' || tax_amount || '|' || NVL (DECODE (gv_program_mode,  gc_sales_credits, sales_cr_amount,  gc_ancillary1, ancillary1_mode_amount,  gc_ancillary2, ancillary2_mode_amount), 0) trxns_out_dtls
                FROM xxdo.xxd_ar_concession_store_trx_t stg
               WHERE 1 = 1 AND stg.request_id = pn_request_id
            ORDER BY stg.store_number, stg.brand, stg.transaction_date,
                     stg.sequence_id;
    BEGIN
        msg (
            'In Print Transactions procedure to display the calculated data in DRAFT Version.');

        SELECT COUNT (*)
          INTO lv_print_trxns_cnt
          FROM xxdo.xxd_ar_concession_store_trx_t stg
         WHERE 1 = 1 AND request_id = pn_request_id;

        IF lv_print_trxns_cnt > 0
        THEN
            msg (
                'Program Mode|Brand|Store Number|RMS Trx Seq Number|Transaction Date|Retail Amount|Discount Amount|Paytotal Amount|Tax Amount|Calculated Amount',
                'N',
                'OUT');

            FOR c_print_trxns_rec IN c_print_trxns
            LOOP
                lv_draft_trn_dtls   := c_print_trxns_rec.trxns_out_dtls;
                msg (lv_draft_trn_dtls, 'N', 'OUT');
            END LOOP;
        ELSE
            msg (
                'There are no records picked for this run in DRAFT Version.',
                'N',
                'OUT');
            msg (
                'There are no records picked for this run in DRAFT Version.',
                'N',
                'LOG');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unable to print transactions output in DRAFT Version'
                || SQLERRM);
    END print_trxns;

    PROCEDURE update_calc_amt_stg (pn_sequence_id   IN NUMBER,
                                   pn_amount        IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF gv_program_mode = gc_sales_credits
        THEN
            UPDATE xxd_ar_concession_store_trx_t
               SET sales_cr_amount = pn_amount, request_id = gn_conc_request_id, last_updated_by = gn_user_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE 1 = 1 AND sequence_id = pn_sequence_id;
        ELSIF gv_program_mode = gc_ancillary1
        THEN
            UPDATE xxd_ar_concession_store_trx_t
               SET ancillary1_mode_amount = pn_amount, request_id = gn_conc_request_id, last_updated_by = gn_user_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE 1 = 1 AND sequence_id = pn_sequence_id;
        ELSIF gv_program_mode = gc_ancillary2
        THEN
            UPDATE xxd_ar_concession_store_trx_t
               SET ancillary2_mode_amount = pn_amount, request_id = gn_conc_request_id, last_updated_by = gn_user_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE 1 = 1 AND sequence_id = pn_sequence_id;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END update_calc_amt_stg;

    FUNCTION get_amt_basis_formula (pn_amt_basis IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_func_name           VARCHAR2 (30) := 'GET_AMT_BASIS_FORMULA';
        lv_err_msg             VARCHAR2 (2000) := NULL;
        lv_amt_basis_formula   VARCHAR2 (30) := NULL;
    BEGIN
        SELECT REPLACE (REPLACE (REPLACE (RTRIM (LTRIM (ffvl.description)), CHR (13), ''), CHR (10), ''), CHR (9), '') amount_basis_formula
          INTO lv_amt_basis_formula
          FROM apps.fnd_flex_values_vl ffvl
         WHERE     1 = 1
               AND ffvl.flex_value_set_id =
                   (SELECT flex_value_set_id
                      FROM apps.fnd_flex_value_sets
                     WHERE flex_value_set_name = 'XXD_AR_AMOUNT_BASIS')
               AND TO_NUMBER (ffvl.flex_value) = pn_amt_basis;

        RETURN lv_amt_basis_formula;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg             :=
                SUBSTR (
                       'Error while getting amount basis formula in '
                    || gv_package_name
                    || lv_func_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
            lv_amt_basis_formula   := NULL;
            RETURN lv_amt_basis_formula;
    END get_amt_basis_formula;

    FUNCTION get_calculated_amt (pv_program_mode      IN VARCHAR2,
                                 pn_store_number      IN NUMBER,
                                 pv_brand             IN VARCHAR2,
                                 pn_org_id            IN NUMBER,
                                 pn_retail_amount     IN NUMBER,
                                 pn_discount_amount   IN NUMBER,
                                 pn_paytotal_amount   IN NUMBER,
                                 pn_tax_amount        IN NUMBER)
        RETURN NUMBER
    IS
        --Local Variables declaration
        ln_amt_basis_num           NUMBER := NULL;
        lv_text                    VARCHAR2 (240) := NULL;
        lv_final_text              VARCHAR2 (240) := NULL;
        lv_text_returned           VARCHAR2 (240) := NULL;
        lv_stmt                    VARCHAR2 (2000) := NULL;
        ln_return_amt              NUMBER := NULL;
        ln_ancillary1_percentage   NUMBER := NULL;
        ln_ancillary2_percentage   NUMBER := NULL;

        --Ref Cursor Declaration
        TYPE ref_cur IS REF CURSOR;

        c1                         ref_cur;

        --Cursors Declaration
        CURSOR get_amt_formula_cur (cn_amt_basis_num IN NUMBER)
        IS
            SELECT ffvl.flex_value amt_basis_num, ffvl.description amt_basis_logic
              FROM apps.fnd_flex_value_sets flvs, apps.fnd_flex_values_vl ffvl
             WHERE     1 = 1
                   AND flvs.flex_value_set_name = 'XXD_AR_AMOUNT_BASIS'
                   AND flvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.summary_flag = 'N'
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                                   AND NVL (ffvl.end_date_active,
                                            SYSDATE + 1)
                   AND TO_NUMBER (ffvl.flex_value) = cn_amt_basis_num;

        CURSOR get_amt_basis_cur IS
            SELECT xacs.sales_cr_amount_basis, xacs.ancillary1_percentage, xacs.ancillary1_amount_basis,
                   xacs.ancillary2_percentage, xacs.ancillary2_amount_basis
              FROM apps.xxd_ar_concession_stores_v xacs
             WHERE     1 = 1
                   AND xacs.store_number = pn_store_number
                   AND xacs.brand = pv_brand
                   AND xacs.operating_unit_id = pn_org_id;
    BEGIN
        FOR get_amt_basis_rec IN get_amt_basis_cur
        LOOP
            IF pv_program_mode = gc_sales_credits
            THEN
                ln_amt_basis_num   := get_amt_basis_rec.sales_cr_amount_basis;
            ELSIF pv_program_mode = gc_ancillary1
            THEN
                ln_amt_basis_num   :=
                    get_amt_basis_rec.ancillary1_amount_basis;
                ln_ancillary1_percentage   :=
                    TO_NUMBER (get_amt_basis_rec.ancillary1_percentage);
            ELSIF pv_program_mode = gc_ancillary2
            THEN
                ln_amt_basis_num   :=
                    get_amt_basis_rec.ancillary2_amount_basis;
                ln_ancillary2_percentage   :=
                    TO_NUMBER (get_amt_basis_rec.ancillary2_percentage);
            ELSE
                ln_amt_basis_num   := NULL;
            END IF;

            --msg('1-ln_amt_basis_num:'||ln_amt_basis_num);
            IF ln_amt_basis_num IS NOT NULL
            THEN
                FOR get_amt_formula_rec
                    IN get_amt_formula_cur (ln_amt_basis_num)
                LOOP
                    lv_text   := get_amt_formula_rec.amt_basis_logic; --'A+B+C-D';
                    --                  msg(lv_input_text);
                    lv_final_text   :=
                        REPLACE (
                            REPLACE (
                                REPLACE (REPLACE (lv_text, 'A', '{0}'),
                                         'B',
                                         '{1}'),
                                'C',
                                '{2}'),
                            'D',
                            '{3}');
                    lv_text_returned   :=
                        replace_text (
                            lv_final_text,
                            xxd_ar_conc_tbl_varchar2 (pn_retail_amount, pn_discount_amount, pn_paytotal_amount
                                                      , pn_tax_amount));
                --msg('lv_text_returned:'||lv_text_returned);
                END LOOP;

                lv_stmt   :=
                    'SELECT ' || lv_text_returned || ' new_val FROM DUAL';

                OPEN c1 FOR lv_stmt;

                FETCH c1 INTO ln_return_amt;

                CLOSE c1;
            --msg('ln_return_amt:'||ln_return_amt);
            ELSE
                ln_return_amt   := NULL;
            END IF;
        END LOOP;

        IF pv_program_mode = gc_sales_credits
        THEN
            ln_return_amt   := ln_return_amt;
        ELSIF pv_program_mode = gc_ancillary1
        THEN
            IF ln_ancillary1_percentage IS NOT NULL
            THEN
                ln_return_amt   :=
                    ln_return_amt * (ln_ancillary1_percentage / 100);
            ELSE
                ln_return_amt   := NULL;
            END IF;
        ELSIF pv_program_mode = gc_ancillary2
        THEN
            IF ln_ancillary2_percentage IS NOT NULL
            THEN
                ln_return_amt   :=
                    ln_return_amt * (ln_ancillary2_percentage / 100);
            ELSE
                ln_return_amt   := NULL;
            END IF;
        END IF;

        RETURN ln_return_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            CLOSE c1;

            msg ('When Others:' || SQLERRM);
            RETURN NULL;
    END get_calculated_amt;

    FUNCTION get_ar_terms (pn_org_id        IN NUMBER,
                           pn_site_use_id   IN NUMBER,
                           pn_customer_id   IN NUMBER)
        RETURN NUMBER
    IS
        lv_func_name   VARCHAR2 (30) := 'GET_AR_TERMS';
        lv_err_msg     VARCHAR2 (2000) := NULL;
        ln_term_id     NUMBER := NULL;
    BEGIN
        BEGIN
            --Get payment terms from BILL_TO Site
            SELECT hcsua.payment_term_id
              INTO ln_term_id
              FROM apps.hz_cust_site_uses_all hcsua
             WHERE     1 = 1
                   AND hcsua.site_use_code = 'BILL_TO'
                   AND hcsua.org_id = pn_org_id
                   AND hcsua.site_use_id = pn_site_use_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                --Get payment terms from Customer Site if BILL_TO site does not have it
                BEGIN
                    SELECT hca.payment_term_id
                      INTO ln_term_id
                      FROM apps.hz_cust_accounts hca
                     WHERE     1 = 1
                           AND NVL (hca.org_id, pn_org_id) = pn_org_id
                           AND hca.cust_account_id = pn_customer_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_term_id   := NULL;
                END;
            WHEN OTHERS
            THEN
                --Get payment terms from Customer Site if BILL_TO site Query completed in WHEN OTHERS exception
                BEGIN
                    SELECT hca.payment_term_id
                      INTO ln_term_id
                      FROM apps.hz_cust_accounts hca
                     WHERE     1 = 1
                           AND NVL (hca.org_id, pn_org_id) = pn_org_id
                           AND hca.cust_account_id = pn_customer_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_term_id   := NULL;
                END;
        END;

        RETURN ln_term_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR (
                       'Error while getting Payment Terms in '
                    || gv_package_name
                    || lv_func_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
            ln_term_id   := NULL;
            RETURN ln_term_id;
    END get_ar_terms;

    --Added for change 1.1
    FUNCTION get_period_status (pn_org_id            IN NUMBER,
                                pv_trx_period_name   IN VARCHAR2)
        RETURN NUMBER
    IS
        lv_func_name      VARCHAR2 (30) := 'GET_PERIOD_STATUS';
        lv_err_msg        VARCHAR2 (2000) := NULL;
        ln_per_open_cnt   NUMBER := 0;
    BEGIN
        SELECT COUNT (*)
          INTO ln_per_open_cnt
          FROM apps.hr_operating_units hou, apps.gl_period_statuses_v gps
         WHERE     1 = 1
               AND hou.organization_id = pn_org_id
               AND gps.application_id = 222       --Receivables Application ID
               AND gps.period_name = pv_trx_period_name
               AND gps.set_of_books_id = hou.set_of_books_id
               AND gps.show_status = 'Open';

        RETURN ln_per_open_cnt;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg        :=
                SUBSTR (
                       'Error while getting Payment Terms in '
                    || gv_package_name
                    || lv_func_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
            ln_per_open_cnt   := 0;
            RETURN ln_per_open_cnt;
    END get_period_status;

    --Added for change 1.1
    PROCEDURE get_next_open_period (pn_org_id                  IN     NUMBER,
                                    pd_trx_per_end_dt          IN     DATE,
                                    x_next_open_per_name          OUT VARCHAR2,
                                    x_next_open_per_start_dt      OUT DATE,
                                    x_next_open_per_end_dt        OUT DATE)
    IS
        --Local variables declaration
        lv_proc_name   VARCHAR2 (30) := 'GET_NEXT_OPEN_PERIOD';
        lv_err_msg     VARCHAR2 (2000) := NULL;
    BEGIN
        SELECT xx.period_name, xx.period_start_date, xx.period_end_date
          INTO x_next_open_per_name, x_next_open_per_start_dt, x_next_open_per_end_dt
          FROM (SELECT ROW_NUMBER () OVER (ORDER BY gps.start_date) AS row_num, gps.period_name, gps.start_date period_start_date,
                       gps.end_date period_end_date
                  FROM hr_operating_units hou, gl_period_statuses_v gps
                 WHERE     1 = 1
                       --   AND hou.name like 'Deckers France SAS OU'
                       AND hou.organization_id = pn_org_id
                       AND gps.application_id = 222 --Receivables Application ID
                       --   AND gps.period_name = :trx_period_name --'MAY-19'
                       AND gps.set_of_books_id = hou.set_of_books_id    --2026
                       AND gps.start_date > pd_trx_per_end_dt
                       AND gps.show_status = 'Open') xx
         WHERE 1 = 1 AND xx.row_num = 1;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_next_open_per_name       := NULL;
            x_next_open_per_start_dt   := NULL;
            x_next_open_per_end_dt     := NULL;
            lv_err_msg                 :=
                SUBSTR (
                       'Error while getting Next Open Period '
                    || gv_package_name
                    || lv_proc_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
    END get_next_open_period;

    --Procedure to get the AR Transactions created for this run and update the staging table
    --Parameters
    --pv_ret_msg        OUT     Return error message to the calling procedure
    --pn_ret_sts        OUT     Program return code to the calling procedure
    PROCEDURE upd_ar_trx_det_to_stg (pn_customer_trx_id IN NUMBER, x_ret_msg OUT VARCHAR2, x_ret_sts OUT NUMBER)
    IS
        --Local Variables Declaration
        lv_proc_name    VARCHAR2 (30) := NULL;
        lv_err_msg      VARCHAR2 (2000) := NULL;
        lv_trx_number   VARCHAR2 (30) := NULL;

        CURSOR trx_det_cur IS
            SELECT rctl.*
              FROM ra_customer_trx_lines_all rctl
             WHERE     1 = 1
                   AND rctl.customer_trx_id = pn_customer_trx_id
                   AND rctl.line_type = 'LINE'
                   AND TO_NUMBER (rctl.interface_line_attribute7) =
                       gn_conc_request_id;
    BEGIN
        BEGIN
            SELECT rct.trx_number
              INTO lv_trx_number
              FROM ra_customer_trx_all rct
             WHERE 1 = 1 AND rct.customer_trx_id = pn_customer_trx_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'Error while fetching AR trx details from ra_customer_trx_all for customer_trx_id = '
                        || pn_customer_trx_id
                        || '. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                msg (lv_err_msg);
        END;

        msg ('lv_trx_number:' || lv_trx_number);

        IF lv_trx_number IS NOT NULL
        THEN
            FOR trx_det_rec IN trx_det_cur
            LOOP
                IF gv_program_mode = gc_sales_credits
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                           SET xacs.sales_cr_mode_prc_flag = 'P', xacs.sales_cr_mode_error_msg = NULL, xacs.sales_cr_trx_num = lv_trx_number,
                               xacs.sales_cr_trx_line_num = trx_det_rec.line_number, xacs.sales_cr_trx_creation_date = SYSDATE, xacs.sales_cr_trx_created_by = gn_user_id,
                               xacs.sales_cr_trx_request_id = gn_conc_request_id, xacs.reprocess_flag = DECODE (xacs.reprocess_flag, 'R', 'Y', xacs.reprocess_flag)
                         WHERE     1 = 1
                               AND xacs.sequence_id =
                                   TO_NUMBER (
                                       trx_det_rec.interface_line_attribute1)
                               AND xacs.store_number =
                                   TO_NUMBER (
                                       trx_det_rec.interface_line_attribute3)
                               AND xacs.brand =
                                   trx_det_rec.interface_line_attribute4;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while Updating staging table with AR Transaction details. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;
                ELSIF gv_program_mode = gc_ancillary1
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                           SET xacs.ancillary1_mode_prc_flag = 'P', xacs.ancillary1_error_msg = NULL, xacs.ancillary1_trx_num = lv_trx_number,
                               xacs.ancillary1_trx_line_num = trx_det_rec.line_number, xacs.ancillary1_creation_date = SYSDATE, xacs.ancillary1_created_by = gn_user_id,
                               xacs.ancillary1_request_id = gn_conc_request_id, xacs.reprocess_flag = DECODE (xacs.reprocess_flag, 'R', 'Y', xacs.reprocess_flag)
                         WHERE     1 = 1
                               AND xacs.sequence_id =
                                   TO_NUMBER (
                                       trx_det_rec.interface_line_attribute1)
                               AND xacs.store_number =
                                   TO_NUMBER (
                                       trx_det_rec.interface_line_attribute3)
                               AND xacs.brand =
                                   trx_det_rec.interface_line_attribute4;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while Updating staging table with AR Transaction details. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;
                ELSIF gv_program_mode = gc_ancillary2
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                           SET xacs.ancillary2_mode_prc_flag = 'P', xacs.ancillary2_error_msg = NULL, xacs.ancillary2_trx_num = lv_trx_number,
                               xacs.ancillary2_trx_line_num = trx_det_rec.line_number, xacs.ancillary2_creation_date = SYSDATE, xacs.ancillary2_created_by = gn_user_id,
                               xacs.ancillary2_request_id = gn_conc_request_id, xacs.reprocess_flag = DECODE (xacs.reprocess_flag, 'R', 'Y', xacs.reprocess_flag)
                         WHERE     1 = 1
                               AND xacs.sequence_id =
                                   TO_NUMBER (
                                       trx_det_rec.interface_line_attribute1)
                               AND xacs.store_number =
                                   TO_NUMBER (
                                       trx_det_rec.interface_line_attribute3)
                               AND xacs.brand =
                                   trx_det_rec.interface_line_attribute4;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while Updating staging table with AR Transaction details. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;
                END IF;
            END LOOP;
        END IF;

        COMMIT;

        IF lv_err_msg IS NULL
        THEN
            x_ret_msg   := NULL;
            x_ret_sts   := gn_success;
        ELSE
            x_ret_msg   := lv_err_msg;
            x_ret_sts   := gn_error;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lv_err_msg   :=
                SUBSTR (
                       'Error while updating Transaction details to staging table in '
                    || gv_package_name
                    || lv_proc_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
            x_ret_msg   := lv_err_msg;
            x_ret_sts   := gn_error;
    END upd_ar_trx_det_to_stg;

    --Procedure to get the AR Interface Error back to the staging table
    --Parameters
    --pv_ret_msg        OUT     Return error message to the calling procedure
    --pn_ret_sts        OUT     Program return code to the calling procedure
    PROCEDURE upd_errors_to_stg (
        pn_int_hdr_id      IN     NUMBER,
        p_trx_lines_tbl    IN     ar_invoice_api_pub.trx_line_tbl_type,
        pv_error_message   IN     VARCHAR2,
        x_ret_msg             OUT VARCHAR2,
        x_ret_sts             OUT NUMBER)
    IS
        --Local Variables Declaration
        lv_proc_name    VARCHAR2 (30) := 'UPD_ERRORS_TO_STG';
        lv_err_msg      VARCHAR2 (2000) := NULL;
        lv_trx_number   VARCHAR2 (30) := NULL;
    BEGIN
        IF p_trx_lines_tbl.COUNT > 0
        THEN
            FOR i IN p_trx_lines_tbl.FIRST .. p_trx_lines_tbl.LAST
            LOOP
                IF gv_program_mode = gc_sales_credits
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                           SET xacs.sales_cr_mode_prc_flag = 'E', xacs.sales_cr_mode_error_msg = pv_error_message, xacs.sales_cr_trx_creation_date = SYSDATE,
                               xacs.sales_cr_trx_created_by = gn_user_id, xacs.sales_cr_trx_request_id = gn_conc_request_id
                         WHERE     1 = 1
                               AND xacs.sequence_id =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute1)
                               AND xacs.store_number =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute3)
                               AND xacs.brand =
                                   (p_trx_lines_tbl (i).interface_line_attribute4);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while Updating staging table with AR Trx creation errors details. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;
                ELSIF gv_program_mode = gc_ancillary1
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                           SET xacs.ancillary1_mode_prc_flag = 'E', xacs.ancillary1_error_msg = pv_error_message, xacs.ancillary1_creation_date = SYSDATE,
                               xacs.ancillary1_created_by = gn_user_id, xacs.ancillary1_request_id = gn_conc_request_id
                         WHERE     1 = 1
                               AND xacs.sequence_id =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute1)
                               AND xacs.store_number =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute3)
                               AND xacs.brand =
                                   (p_trx_lines_tbl (i).interface_line_attribute4);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while Updating staging table with AR Trx creation errors details. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;
                ELSIF gv_program_mode = gc_ancillary2
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                           SET xacs.ancillary2_mode_prc_flag = 'E', xacs.ancillary2_error_msg = pv_error_message, xacs.ancillary2_creation_date = SYSDATE,
                               xacs.ancillary2_created_by = gn_user_id, xacs.ancillary2_request_id = gn_conc_request_id
                         WHERE     1 = 1
                               AND xacs.sequence_id =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute1)
                               AND xacs.store_number =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute3)
                               AND xacs.brand =
                                   (p_trx_lines_tbl (i).interface_line_attribute4);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while Updating staging table with AR Trx creation errors details. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;
                END IF;
            END LOOP;
        END IF;

        COMMIT;

        IF lv_err_msg IS NULL
        THEN
            x_ret_msg   := NULL;
            x_ret_sts   := gn_success;
        ELSE
            x_ret_msg   := lv_err_msg;
            x_ret_sts   := gn_error;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lv_err_msg   :=
                SUBSTR (
                       'Error while updating Trx Creatioin Error details to staging table in '
                    || gv_package_name
                    || lv_proc_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
            x_ret_msg   := lv_err_msg;
            x_ret_sts   := gn_error;
    END upd_errors_to_stg;

    --Procedure to get the AR Interface Error back to the staging table
    --Parameters
    --pv_ret_msg        OUT     Return error message to the calling procedure
    --pn_ret_sts        OUT     Program return code to the calling procedure
    PROCEDURE upd_errors_to_stg (pn_sequence_id     IN NUMBER,
                                 pv_error_message   IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        --Local Variables Declaration
        lv_proc_name    VARCHAR2 (30) := 'UPD_ERRORS_TO_STG';
        lv_err_msg      VARCHAR2 (2000) := NULL;
        lv_trx_number   VARCHAR2 (30) := NULL;
    BEGIN
        IF gv_program_mode = gc_sales_credits
        THEN
            BEGIN
                UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                   SET xacs.sales_cr_mode_prc_flag = 'E', xacs.sales_cr_mode_error_msg = SUBSTR (pv_error_message || '.' || sales_cr_mode_error_msg, 1, 2000), xacs.sales_cr_trx_creation_date = SYSDATE,
                       xacs.sales_cr_trx_created_by = gn_user_id, xacs.sales_cr_trx_request_id = gn_conc_request_id
                 WHERE 1 = 1 AND xacs.sequence_id = pn_sequence_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        SUBSTR (
                               'Error while Updating staging table with AR Trx creation errors details. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    msg (lv_err_msg);
            END;
        ELSIF gv_program_mode = gc_ancillary1
        THEN
            BEGIN
                UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                   SET xacs.ancillary1_mode_prc_flag = 'E', xacs.ancillary1_error_msg = SUBSTR (pv_error_message || '.' || ancillary1_error_msg, 1, 2000), xacs.ancillary1_creation_date = SYSDATE,
                       xacs.ancillary1_created_by = gn_user_id, xacs.ancillary1_request_id = gn_conc_request_id
                 WHERE 1 = 1 AND xacs.sequence_id = pn_sequence_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        SUBSTR (
                               'Error while Updating staging table with AR Trx creation errors details. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    msg (lv_err_msg);
            END;
        ELSIF gv_program_mode = gc_ancillary2
        THEN
            BEGIN
                UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                   SET xacs.ancillary2_mode_prc_flag = 'E', xacs.ancillary2_error_msg = SUBSTR (pv_error_message || '.' || ancillary2_error_msg, 1, 2000), xacs.ancillary2_creation_date = SYSDATE,
                       xacs.ancillary2_created_by = gn_user_id, xacs.ancillary2_request_id = gn_conc_request_id
                 WHERE 1 = 1 AND xacs.sequence_id = pn_sequence_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        SUBSTR (
                               'Error while Updating staging table with AR Trx creation errors details. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    msg (lv_err_msg);
            END;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lv_err_msg   :=
                SUBSTR (
                       'Error while updating Trx Creatioin Error details to staging table in '
                    || gv_package_name
                    || lv_proc_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
    END upd_errors_to_stg;

    PROCEDURE validate_store_setup_data (pn_sequence_id    IN     NUMBER,
                                         pn_store_number   IN     NUMBER,
                                         pv_brand          IN     VARCHAR2,
                                         pn_org_id         IN     NUMBER,
                                         x_return_status      OUT NUMBER)
    IS
        --Local Variables Declaration
        lv_proc_name         VARCHAR2 (30) := 'VALIDATE_STORE_SETUP_DATA';
        lv_conc_store_rt     apps.xxd_ar_concession_stores_v%ROWTYPE := NULL;
        lv_error_message     VARCHAR2 (2000) := NULL;
        ln_period_open_cnt   NUMBER := 0;
        lv_period_err_msg    VARCHAR2 (1000) := NULL;
    BEGIN
        BEGIN
            SELECT st.*
              INTO lv_conc_store_rt
              FROM apps.xxd_ar_concession_stores_v st
             WHERE     1 = 1
                   AND st.store_number = pn_store_number
                   AND st.brand = pv_brand
                   AND st.operating_unit_id = pn_org_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_error_message   :=
                    SUBSTR (
                           'No DATA FOUND in '
                        || gv_package_name
                        || lv_proc_name
                        || 'while getting Config values for store = '
                        || pn_store_number
                        || ' and brand = '
                        || pv_brand,
                        1,
                        2000);
                msg (lv_error_message);
                x_return_status   := gn_error;
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    SUBSTR (
                           'When Others Exception in '
                        || gv_package_name
                        || lv_proc_name
                        || 'while getting Config values for store = '
                        || pn_store_number
                        || ' and brand = '
                        || pv_brand,
                        1,
                        2000);
                msg (lv_error_message);
                x_return_status   := gn_error;
        END;

        IF gv_program_mode = gc_ancillary1
        THEN
            IF lv_conc_store_rt.ancillary1_percentage IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY1_PERCENTAGE is Missing in Setup.';
            END IF;

            IF lv_conc_store_rt.ancillary1_memo_line_id IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY1_MEMO_LINE is Missing in Setup.';
            END IF;

            IF lv_conc_store_rt.ancillary1_amount_basis IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY1_AMOUNT_BASIS is Missing in Setup.';
            END IF;

            IF lv_conc_store_rt.ancillary1_inv_trx_type_id IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY1_INV_TRX_TYPE is Missing in Setup.';
            END IF;

            IF lv_conc_store_rt.ancillary1_cm_trx_type_id IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY1_CM_TRX_TYPE is Missing in Setup.';
            END IF;
        ELSIF gv_program_mode = gc_ancillary2
        THEN
            IF lv_conc_store_rt.ancillary2_percentage IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY2_PERCENTAGE is Missing in Setup.';
            END IF;

            IF lv_conc_store_rt.ancillary2_memo_line_id IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY2_MEMO_LINE is Missing in Setup.';
            END IF;

            IF lv_conc_store_rt.ancillary2_amount_basis IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY2_AMOUNT_BASIS is Missing in Setup.';
            END IF;

            IF lv_conc_store_rt.ancillary2_inv_trx_type_id IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY2_INV_TRX_TYPE is Missing in Setup.';
            END IF;

            IF lv_conc_store_rt.ancillary2_cm_trx_type_id IS NULL
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'ANCILLARY2_CM_TRX_TYPE is Missing in Setup.';
            END IF;
        END IF;

        --Added below if(gv_use_curr_per_dt = 'N') on top of period validation for change 1.1
        --Validate period
        ln_period_open_cnt   := 0;

        IF gv_use_curr_per_dt = 'N'
        THEN
            SELECT COUNT (*)
              INTO ln_period_open_cnt
              FROM xxdo.xxd_ar_concession_store_trx_t stg, hr_operating_units hou, gl_period_statuses_v gps
             WHERE     1 = 1
                   AND stg.sequence_id = pn_sequence_id
                   AND hou.organization_id = pn_org_id
                   AND gps.application_id = 222   --Receivables Application ID
                   AND gps.set_of_books_id = hou.set_of_books_id        --2026
                   AND gps.show_status = 'Open'
                   AND TRUNC (stg.transaction_date) BETWEEN gps.start_date
                                                        AND gps.end_date;

            IF ln_period_open_cnt <= 0
            THEN
                lv_period_err_msg   :=
                    ' Transaction Date Period is not OPEN.';
            END IF;
        END IF;                      --Added gv_use_curr_per_dt for change 1.1

        IF lv_error_message IS NOT NULL
        THEN
            x_return_status   := gn_error;
            upd_errors_to_stg (
                pn_sequence_id   => pn_sequence_id,
                pv_error_message   =>
                    SUBSTR (lv_error_message || lv_period_err_msg, 1, 2000));
        ELSE
            x_return_status   := gn_success;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := gn_error;
            msg (
                   'Error validating store setup data for sequence ID:'
                || pn_sequence_id
                || '. Error is :'
                || SQLERRM);
    END validate_store_setup_data;

    --Procedure to create AR Invoices/Credit Memo's
    PROCEDURE create_ar_trxns (pn_org_id IN NUMBER, p_batch_source_rec IN ar_invoice_api_pub.batch_source_rec_type, p_trx_header_tbl IN ar_invoice_api_pub.trx_header_tbl_type, p_trx_lines_tbl IN ar_invoice_api_pub.trx_line_tbl_type, p_trx_dist_tbl IN ar_invoice_api_pub.trx_dist_tbl_type, p_trx_salescredits_tbl IN ar_invoice_api_pub.trx_salescredits_tbl_type
                               , x_customer_trx_id OUT NUMBER, x_ret_sts OUT VARCHAR2, x_ret_msg OUT VARCHAR2)
    IS
        --Local Variables Declaration
        lv_proc_name          VARCHAR2 (30) := 'CREATE_AR_TRXNS';
        lv_err_msg            VARCHAR2 (2000) := NULL;
        lv_return_status      VARCHAR2 (1) := NULL;
        ln_msg_count          NUMBER := NULL;
        lv_msg_data           VARCHAR2 (2000) := NULL;
        ln_customer_trx_id    NUMBER := NULL;
        ln_out_msg_index      NUMBER := NULL;
        lv_append_msg_data    VARCHAR2 (2000) := NULL;
        ln_err_cnt            NUMBER := NULL;
        ln_resp_id            NUMBER := NULL;
        ln_resp_appl_id       NUMBER := NULL;
        lv_ar_trx_errors_gt   ar_trx_errors_gt%ROWTYPE;
    BEGIN
        msg ('In AR Transaction creation procedure - START', 'Y');

        ln_resp_id        := NULL;
        ln_resp_appl_id   := NULL;

        BEGIN
            --Getting the responsibility and application to initialize and set the context to create AR Invoice/Credit Memo
            --Making sure that the initialization is set for proper Receivables responsibility
            SELECT frv.responsibility_id, frv.application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                   apps.hr_organization_units hou
             WHERE     1 = 1
                   AND hou.organization_id = pn_org_id
                   AND fpov.profile_option_value =
                       TO_CHAR (hou.organization_id)
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpo.user_profile_option_name = 'MO: Operating Unit'
                   AND frv.responsibility_id = fpov.level_value
                   AND frv.application_id = 222                  --RECEIVABLES
                   AND frv.responsibility_name LIKE
                           'Deckers Receivables Super User%' --Receivables Responsibility
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (frv.start_date)
                                           AND TRUNC (
                                                   NVL (frv.end_date,
                                                        SYSDATE))
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Error getting the responsibility ID : ' || SQLERRM);
        END;

        --Apps Initialization and setting policy context
        fnd_global.apps_initialize (gn_user_id, ln_resp_id, ln_resp_appl_id);
        --fnd_global.apps_initialize(gn_user_id, gn_resp_id, gn_resp_appl_id);
        mo_global.set_policy_context ('S', pn_org_id);
        mo_global.init ('AR');

        BEGIN
            ar_invoice_api_pub.create_single_invoice (
                p_api_version            => 1.0,
                p_init_msg_list          => fnd_api.g_true,
                p_commit                 => fnd_api.g_true,
                p_batch_source_rec       => p_batch_source_rec,
                p_trx_header_tbl         => p_trx_header_tbl,
                p_trx_lines_tbl          => p_trx_lines_tbl,
                p_trx_dist_tbl           => p_trx_dist_tbl,
                p_trx_salescredits_tbl   => p_trx_salescredits_tbl,
                x_customer_trx_id        => ln_customer_trx_id,
                x_return_status          => lv_return_status,
                x_msg_count              => ln_msg_count,
                x_msg_data               => lv_msg_data);
            --msg('Msg : '||SUBSTR(lv_msg_data, 1, 225));
            msg ('API return Status ' || lv_return_status);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'Error in calling ar_invoice_api_pub.create_single_invoice API.'
                        || 'Error is : '
                        || SQLERRM,
                        1,
                        2000);
                msg (lv_err_msg);
                x_ret_sts   := gv_ret_error;
                x_ret_msg   := lv_err_msg;
        END;

        IF NVL (lv_return_status, 'X') <> fnd_api.g_ret_sts_success
        THEN
            IF ln_msg_count > 0
            THEN
                FOR i IN 1 .. ln_msg_count
                LOOP
                    lv_append_msg_data   := NULL;
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lv_append_msg_data
                                    , p_msg_index_out => ln_out_msg_index);
                    lv_msg_data          :=
                        lv_msg_data || CHR (10) || lv_append_msg_data;
                END LOOP;
            END IF;

            x_ret_sts   := NVL (lv_return_status, 'X');
            x_ret_msg   := lv_msg_data;
            msg ('API Return Error Message:' || lv_msg_data);
        ELSE
            x_customer_trx_id   := ln_customer_trx_id;
            x_ret_sts           := NVL (lv_return_status, 'X');
            x_ret_msg           := NULL;
            msg (
                   'AR Invoice/Credit Memo customer_trx_id : '
                || ln_customer_trx_id);
        END IF;

        --Get the count of Errors while creating AR Transaction
        SELECT COUNT (*)
          INTO ln_err_cnt
          FROM ar_trx_errors_gt
         WHERE 1 = 1 AND trx_header_id = p_trx_header_tbl (1).trx_header_id;

        IF ln_err_cnt > 0
        THEN
            FOR i IN p_trx_lines_tbl.FIRST .. p_trx_lines_tbl.LAST
            --                FOR err_rec IN (
            --                                SELECT *
            --                                  FROM ar_trx_errors_gt
            --                                 WHERE 1=1
            --                                   AND trx_header_id = p_trx_header_tbl(1).trx_header_id
            --                               )
            LOOP
                BEGIN
                    SELECT *
                      INTO lv_ar_trx_errors_gt
                      FROM ar_trx_errors_gt
                     WHERE     1 = 1
                           AND trx_header_id =
                               p_trx_header_tbl (1).trx_header_id
                           AND NVL (
                                   trx_line_id,
                                   NVL (p_trx_lines_tbl (i).trx_line_id, -1)) =
                               NVL (p_trx_lines_tbl (i).trx_line_id, -1);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                lv_err_msg   :=
                    SUBSTR (
                           'Trx Creation Error. Invalid value:'
                        || lv_ar_trx_errors_gt.invalid_value
                        || '. Error is : '
                        || lv_ar_trx_errors_gt.error_message,
                        1,
                        2000);
                msg (lv_err_msg);

                --x_ret_msg := lv_err_msg;
                --x_ret_sts := lv_return_status;
                --Updatating the staging table with error messages
                IF gv_program_mode = gc_sales_credits
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                           SET xacs.sales_cr_mode_prc_flag = 'E', xacs.sales_cr_mode_error_msg = lv_err_msg, xacs.sales_cr_trx_creation_date = SYSDATE,
                               xacs.sales_cr_trx_created_by = gn_user_id, xacs.sales_cr_trx_request_id = gn_conc_request_id
                         WHERE     1 = 1
                               AND xacs.sequence_id =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute1)
                               AND xacs.store_number =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute3)
                               AND xacs.brand =
                                   p_trx_lines_tbl (i).interface_line_attribute4;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while Updating staging table with AR Trx creation errors details. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;
                ELSIF gv_program_mode = gc_ancillary1
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                           SET xacs.ancillary1_mode_prc_flag = 'E', xacs.ancillary1_error_msg = lv_err_msg, xacs.ancillary1_creation_date = SYSDATE,
                               xacs.ancillary1_created_by = gn_user_id, xacs.ancillary1_request_id = gn_conc_request_id
                         WHERE     1 = 1
                               AND xacs.sequence_id =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute1)
                               AND xacs.store_number =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute3)
                               AND xacs.brand =
                                   p_trx_lines_tbl (i).interface_line_attribute4;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while Updating staging table with AR Trx creation errors details. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;
                ELSIF gv_program_mode = gc_ancillary2
                THEN
                    BEGIN
                        UPDATE xxdo.xxd_ar_concession_store_trx_t xacs
                           SET xacs.ancillary2_mode_prc_flag = 'E', xacs.ancillary2_error_msg = lv_err_msg, xacs.ancillary2_creation_date = SYSDATE,
                               xacs.ancillary2_created_by = gn_user_id, xacs.ancillary2_request_id = gn_conc_request_id
                         WHERE     1 = 1
                               AND xacs.sequence_id =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute1)
                               AND xacs.store_number =
                                   TO_NUMBER (
                                       p_trx_lines_tbl (i).interface_line_attribute3)
                               AND xacs.brand =
                                   p_trx_lines_tbl (i).interface_line_attribute4;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while Updating staging table with AR Trx creation errors details. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;
                END IF;
            END LOOP;

            COMMIT;
        END IF;

        msg ('In AR Transaction creation procedure - END', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR (
                       'Error while creating AR transactions. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
            x_ret_sts   := gv_ret_error;
            x_ret_msg   := lv_err_msg;
    END create_ar_trxns;

    PROCEDURE cons_yes_grp_by_yes (pn_store_number IN NUMBER, pv_brand IN VARCHAR2, pn_org_id IN NUMBER)
    IS
        --Local Variables Declaration
        --Scalar Variables
        lv_proc_name                VARCHAR2 (30) := 'CONS_YES_GRP_BY_YES';
        lv_err_msg                  VARCHAR2 (2000) := NULL;
        ln_batch_source_id          NUMBER := NULL;
        ln_customer_id              NUMBER := NULL;
        ln_bill_to_site_use_id      NUMBER := NULL;
        ld_trx_date                 DATE := NULL;
        ln_int_hdr_id               NUMBER := NULL;
        ln_int_line_id              NUMBER := NULL;
        ln_int_dist_id              NUMBER := NULL;
        ln_line_count               NUMBER := NULL;
        ln_terms_id                 NUMBER := NULL;
        lv_currency_code            VARCHAR2 (10) := NULL;
        ln_customer_trx_id          NUMBER := NULL;
        lv_ret_sts                  VARCHAR2 (1) := NULL;
        lv_ret_msg                  VARCHAR2 (2000) := NULL;
        ln_return_sts               NUMBER := NULL;
        lv_return_msg               VARCHAR2 (2000) := NULL;
        ln_amount                   NUMBER := NULL;
        ln_is_period_open_cnt       NUMBER := NULL;
        ln_valid_status             NUMBER := NULL;
        lv_next_open_per_name       VARCHAR2 (15) := NULL; --Added for change 1.1
        ld_next_open_per_start_dt   DATE := NULL;       --Added for change 1.1
        ld_next_open_per_end_dt     DATE := NULL;       --Added for change 1.1
        lv_trx_period_err_msg       VARCHAR2 (2000) := NULL; --Added for change 1.1
        --Non-Scalar Variables
        lv_conc_store_rt            apps.xxd_ar_concession_stores_v%ROWTYPE;
        l_trx_header_tbl            ar_invoice_api_pub.trx_header_tbl_type;
        l_trx_lines_tbl             ar_invoice_api_pub.trx_line_tbl_type;
        l_trx_dist_tbl              ar_invoice_api_pub.trx_dist_tbl_type;
        l_trx_salescredits_tbl      ar_invoice_api_pub.trx_salescredits_tbl_type;
        l_batch_source_rec          ar_invoice_api_pub.batch_source_rec_type;

        --Cursor to get distinct store, brand, and period information for grouping the data and creating transactions(INV/CM)
        CURSOR main_cur IS
              SELECT --               gp_cur.period_name current_period_name,  --Commented for change 1.1
                     gp.period_name trx_period_name, gp.period_year trx_period_year, gp.period_num trx_period_num,
                     gp.start_date trx_period_start_date, gp.end_date trx_period_end_date, stg.store_number,
                     stg.brand, MAX (stg.transaction_date) max_trx_date, SUM (stg.retail_amount) retail_amount,
                     SUM (stg.discount_amount) discount_amount, SUM (stg.paytotal_amount) paytotal_amount, SUM (stg.tax_amount) tax_amount
                FROM xxdo.xxd_ar_concession_store_trx_t stg, apps.gl_periods gp
               --              ,apps.gl_periods gp_cur  --Commented for change 1.1
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N' --To pick records inserted with NULL or 'N' status
                     --Commented below condition by Kranthi Bollam on 30OCT2018
                     --AND stg.transaction_date >= DECODE(gd_as_of_date, TRUNC(SYSDATE), stg.transaction_date, gd_as_of_date) --If date is current date, pull all records, else pull trxns with trx_date greater than or equal to ld_as_of_date
                     AND TRUNC (stg.transaction_date) <= gd_as_of_date --Added below condition by Kranthi Bollam on 30OCT2018
                     AND stg.store_number = pn_store_number
                     AND stg.brand = pv_brand
                     --This gives us the records which are are NEW or not processed if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                     AND (   (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'N'
                                  END)
                          OR --This below case gives us the Error Records if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                             (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'E'
                                  END))
                     --Added below the trx date from and to conditions to be considered only when reprocess flag parameter is YES
                     AND TRUNC (stg.transaction_date) BETWEEN (CASE
                                                                   WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                                                   THEN
                                                                       NVL (gd_trx_date_from, TRUNC (stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (stg.transaction_date)
                                                               END)
                                                          AND (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_to,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     AND TRUNC (stg.transaction_date) BETWEEN gp.start_date
                                                          AND gp.end_date
            --           AND gp_cur.period_set_name = 'DO_FY_CALENDAR'  --Commented for change 1.1
            --           AND TRUNC(SYSDATE) BETWEEN gp_cur.start_date and gp_cur.end_date  --Commented for change 1.1
            GROUP BY --gp_cur.period_name,  --Commented for change 1.1
                     gp.period_name, gp.period_year, gp.period_num,
                     gp.start_date, gp.end_date, stg.store_number,
                     stg.brand
            ORDER BY gp.period_year, gp.period_num;

        --Cursor to get data for store, brand, and period
        CURSOR data_cur (cv_period_name IN VARCHAR2)
        IS
              SELECT --               gp_cur.period_name current_period_name,  --Commented for change 1.1
                     gp.period_name
                         trx_period_name,
                     gp.period_year
                         trx_period_year,
                     gp.period_num
                         trx_period_num,
                     gp.start_date
                         trx_period_start_date,
                     gp.end_date
                         trx_period_end_date,
                     apps.xxd_ar_concessions_trx_pkg.get_calculated_amt (
                         pv_program_mode      => gv_program_mode,
                         pn_store_number      => stg.store_number,
                         pv_brand             => stg.brand,
                         pn_org_id            => pn_org_id,
                         pn_retail_amount     => NVL (stg.retail_amount, 0),
                         pn_discount_amount   => NVL (stg.discount_amount, 0),
                         pn_paytotal_amount   => NVL (stg.paytotal_amount, 0),
                         pn_tax_amount        => NVL (stg.tax_amount, 0))
                         calc_amount,
                     stg.*
                FROM xxdo.xxd_ar_concession_store_trx_t stg, apps.gl_periods gp
               --,apps.gl_periods gp_cur  --Commented for change 1.1
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N' --To pick records inserted with NULL or 'N' status
                     --Commented below condition by Kranthi Bollam on 30OCT2018
                     --AND stg.transaction_date >= DECODE(gd_as_of_date, TRUNC(SYSDATE), stg.transaction_date, gd_as_of_date) --If date is current date, pull all records, else pull trxns with trx_date greater than or equal to ld_as_of_date
                     AND TRUNC (stg.transaction_date) <= gd_as_of_date --Added below condition by Kranthi Bollam on 30OCT2018
                     AND stg.store_number = pn_store_number
                     AND stg.brand = pv_brand
                     --This gives us the records which are NEW or not processed if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                     AND (   (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'N'
                                  END)
                          OR --This below case gives us the Error Records if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                             (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'E'
                                  END))
                     --Added below the trx date from and to conditions to be considered only when reprocess flag parameter is YES
                     AND TRUNC (stg.transaction_date) BETWEEN (CASE
                                                                   WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                                                   THEN
                                                                       NVL (gd_trx_date_from, TRUNC (stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (stg.transaction_date)
                                                               END)
                                                          AND (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_to,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     AND TRUNC (stg.transaction_date) BETWEEN gp.start_date
                                                          AND gp.end_date
                     AND gp.period_name = cv_period_name
            --           AND gp_cur.period_set_name = 'DO_FY_CALENDAR'  --Commented for change 1.1
            --           AND TRUNC(SYSDATE) BETWEEN gp_cur.start_date and gp_cur.end_date  --Commented for change 1.1
            ORDER BY gp.period_year, gp.period_num, stg.rms_tran_seq_no;
    BEGIN
        msg (
            'Consolidated = YES and Group by Period = YES procedure - START',
            'Y');

        --Get the values from the stores setup for the store, brand and Operating unit combination
        --and assign it to lv_conc_store_rt variable
        BEGIN
            SELECT st.*
              INTO lv_conc_store_rt
              FROM apps.xxd_ar_concession_stores_v st
             WHERE     1 = 1
                   AND st.store_number = pn_store_number
                   AND st.brand = pv_brand
                   AND st.operating_unit_id = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'When Others Exception in '
                        || gv_package_name
                        || lv_proc_name
                        || 'while getting Sales/Credits Config values for store = '
                        || pn_store_number
                        || ' and brand = '
                        || pv_brand,
                        1,
                        2000);
                msg (lv_err_msg);
                msg ('Error is:' || SQLERRM);
        END;

        --Assigning Values to Variables
        ln_batch_source_id   := lv_conc_store_rt.batch_source_id;
        lv_currency_code     := lv_conc_store_rt.currency_code;

        IF lv_conc_store_rt.cust_account_id IS NOT NULL
        THEN
            ln_customer_id   := lv_conc_store_rt.cust_account_id;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Sales Credit Customer Number is NULL for Store#:'
                    || pn_store_number
                    || ' and brand:'
                    || pv_brand
                    || ' and operating unit ID:'
                    || pn_org_id,
                    1,
                    2000);
            msg (lv_err_msg);
        END IF;

        IF lv_conc_store_rt.cust_bill_to_site_use_id IS NOT NULL
        THEN
            ln_bill_to_site_use_id   :=
                lv_conc_store_rt.cust_bill_to_site_use_id;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Sales Credit Customer Bill to Site is NULL for Store#:'
                    || pn_store_number
                    || ' and brand:'
                    || pv_brand
                    || ' and operating unit ID:'
                    || pn_org_id,
                    1,
                    2000);
            msg (lv_err_msg);
        END IF;

        IF    lv_conc_store_rt.cust_bill_to_site_use_id IS NOT NULL
           OR lv_conc_store_rt.cust_account_id IS NOT NULL
        THEN
            ln_terms_id   :=
                get_ar_terms (
                    pn_org_id        => pn_org_id,
                    pn_site_use_id   =>
                        lv_conc_store_rt.cust_bill_to_site_use_id,
                    pn_customer_id   => lv_conc_store_rt.cust_account_id);
        END IF;

        --Process main cursor
        FOR main_rec IN main_cur
        LOOP
            lv_ret_sts           := NULL;
            lv_ret_msg           := NULL;
            ln_customer_trx_id   := NULL;

            --Check the program version and take action accordingly
            IF gv_version = 'FINAL'
            THEN
                --Check if period is open or not
                ln_is_period_open_cnt   := 0;
                ln_is_period_open_cnt   :=
                    get_period_status (
                        pn_org_id            => lv_conc_store_rt.operating_unit_id,
                        pv_trx_period_name   => main_rec.trx_period_name);

                --Modified the if condition for change 1.1 -- START
                IF (ln_is_period_open_cnt <= 0)
                THEN
                    --msg('Transaction Date Period : '||main_rec.trx_period_name||' is not OPEN.');
                    --Added below if condition for change 1.1 --START
                    IF gv_use_curr_per_dt = 'Y'
                    THEN
                        get_next_open_period (
                            pn_org_id              => lv_conc_store_rt.operating_unit_id,
                            pd_trx_per_end_dt      =>
                                main_rec.trx_period_end_date,
                            x_next_open_per_name   => lv_next_open_per_name,
                            x_next_open_per_start_dt   =>
                                ld_next_open_per_start_dt,
                            x_next_open_per_end_dt   =>
                                ld_next_open_per_end_dt);
                        msg (
                               ' Transaction Date Period :'
                            || main_rec.trx_period_name
                            || ' is not OPEN, and USE_CURRENT_PERIOD_DATE is YES, creating transactions on Start date of next OPEN Period : '
                            || lv_next_open_per_name);
                    --msg('Next Open Period is : '||lv_next_open_per_name);
                    ELSE
                        --msg(' Transaction Date Period :'||main_rec.trx_period_name||' is not OPEN, and also USE_CURRENT_PERIOD_DATE is NO, so not creating transactions');
                        lv_trx_period_err_msg   :=
                               ' Transaction Date Period :'
                            || main_rec.trx_period_name
                            || ' is not OPEN, and also USE_CURRENT_PERIOD_DATE is NO, so not creating transactions';
                        msg (lv_trx_period_err_msg);
                    END IF;
                --Added above if condition for change 1.1 --END
                END IF;

                --Modified the if condition for change 1.1 -- END
                --ELSE --Commented ELSE for change 1.1 and added below IF
                IF (ln_is_period_open_cnt > 0 OR gv_use_curr_per_dt = 'Y') --Added for change 1.1
                THEN
                    --Commented the below code to determine trx date for change 1.1 --START
                    /*
                    --Determining transaction date
                    --If current period and trx period are different then trx date is first day of the current trx period
                    --else trx date is the max trx date
                    --msg('main_rec.trx_period_name:'||main_rec.trx_period_name);
                    IF main_rec.current_period_name <> main_rec.trx_period_name
                    THEN
                        --ld_trx_date := main_rec.trx_period_end_date;
                        --msg('if current and trx periods are not same');
                        --msg('ld_trx_date:'||ld_trx_date);
                    ELSE
                        ld_trx_date := main_rec.max_trx_date;
                        --msg('if current and trx periods are same');
                        --msg('ld_trx_date:'||ld_trx_date);
                    END IF;
                    */
                    --Commented the above code to determine trx date for change 1.1 --END

                    --Added the below code to determine trx date for change 1.1 --START
                    --If the trx period is open, then trx date will be max trx date
                    IF ln_is_period_open_cnt > 0
                    THEN
                        ld_trx_date   := main_rec.max_trx_date;
                    --If trx period is not open and use current period is YES, then get the next open period start date and use it as trx date
                    ELSIF     ln_is_period_open_cnt <= 0
                          AND gv_use_curr_per_dt = 'Y'
                    THEN
                        ld_trx_date   := ld_next_open_per_start_dt;
                    END IF;

                    --Added the above code to determine trx date for change 1.1 --END

                    --Getting the interface header id to be passed to API
                    BEGIN
                        SELECT ra_customer_trx_s.NEXTVAL
                          INTO ln_int_hdr_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface header id from sequence RA_CUSTOMER_TRX_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Assigning values to API Batch Source Record table type variable
                    l_batch_source_rec.batch_source_id         :=
                        ln_batch_source_id;                           -- 12003
                    --Assigning values to API Header table type variable
                    l_trx_header_tbl (1).trx_header_id         := ln_int_hdr_id;

                    IF gv_program_mode = gc_sales_credits
                    THEN
                        l_trx_header_tbl (1).cust_trx_type_id   :=
                            lv_conc_store_rt.sales_cr_inv_trx_type_id;
                    ELSIF gv_program_mode = gc_ancillary1
                    THEN
                        l_trx_header_tbl (1).cust_trx_type_id   :=
                            lv_conc_store_rt.ancillary1_inv_trx_type_id;
                    ELSIF gv_program_mode = gc_ancillary2
                    THEN
                        l_trx_header_tbl (1).cust_trx_type_id   :=
                            lv_conc_store_rt.ancillary2_inv_trx_type_id;
                    END IF;

                    l_trx_header_tbl (1).bill_to_site_use_id   :=
                        ln_bill_to_site_use_id;
                    l_trx_header_tbl (1).trx_date              := ld_trx_date;
                    l_trx_header_tbl (1).bill_to_customer_id   :=
                        ln_customer_id;
                    l_trx_header_tbl (1).term_id               := ln_terms_id;
                    l_trx_header_tbl (1).attribute5            :=
                        lv_conc_store_rt.brand; --'UGG';--Mandatory at header level
                    l_trx_header_tbl (1).trx_currency          :=
                        lv_currency_code;
                END IF;                             --Period validation end if
            END IF;                                           --Version End IF

            --Setting line count variable to zero
            ln_line_count        := 0;

            --Process the data cursor
            FOR data_rec
                IN data_cur (cv_period_name => main_rec.trx_period_name)
            LOOP
                --Calling the procedure to update calculated amounts to the staging table
                update_calc_amt_stg (pn_sequence_id   => data_rec.sequence_id,
                                     pn_amount        => data_rec.calc_amount);

                --Call validation procedure to check the setup value and update the staging table with error
                --if there is any setup missing in XXD_AR_CONCESSION_STORES value set
                ln_valid_status   := 0;
                validate_store_setup_data (
                    pn_sequence_id    => data_rec.sequence_id,
                    pn_store_number   => pn_store_number,
                    pv_brand          => pv_brand,
                    pn_org_id         => pn_org_id,
                    x_return_status   => ln_valid_status);

                --Added below if condition for change 1.1 --START
                --Update the staging table if the transaction date period is not open and Use Current Period Date is NO
                IF ln_is_period_open_cnt <= 0 AND gv_use_curr_per_dt = 'N'
                THEN
                    upd_errors_to_stg (
                        pn_sequence_id     => data_rec.sequence_id,
                        pv_error_message   => lv_trx_period_err_msg);
                END IF;

                --Added above if condition for change 1.1 --END

                --If the program version is FINAL, data is valid and Period is Open or the variable USE_CURRENT_PERIOD_DATE is Yes
                --then proceed further
                IF (gv_version = 'FINAL' --AND ln_is_period_open_cnt > 0 --Commented for change 1.1
                                         AND (ln_is_period_open_cnt > 0 OR gv_use_curr_per_dt = 'Y') --Added for change 1.1
                                                                                                     AND ln_valid_status = 0)
                THEN
                    --Incrementing the line count for each line
                    ln_line_count                                       := ln_line_count + 1;

                    --Getting the interface line id to be passed to API
                    BEGIN
                        SELECT ra_customer_trx_lines_s.NEXTVAL
                          INTO ln_int_line_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface Line id from sequence RA_CUSTOMER_TRX_LINES_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Assigning the calculated amount to the ln_amount variable
                    ln_amount                                           := data_rec.calc_amount;

                    --Getting the interface Distribution id to be passed to API
                    BEGIN
                        SELECT ra_cust_trx_line_gl_dist_s.NEXTVAL
                          INTO ln_int_dist_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface Distribution id from sequence RA_CUST_TRX_LINE_GL_DIST_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Assiging values to API line table type variable
                    l_trx_lines_tbl (ln_line_count).trx_header_id       :=
                        ln_int_hdr_id;
                    l_trx_lines_tbl (ln_line_count).trx_line_id         :=
                        ln_int_line_id;
                    l_trx_lines_tbl (ln_line_count).line_number         :=
                        ln_line_count;

                    --If consolidation is YES, we can pass the positive and negative values for line amount as this trx type accepts both positive and negative sign amounts
                    l_trx_lines_tbl (ln_line_count).uom_code            := 'EA';
                    l_trx_lines_tbl (ln_line_count).quantity_invoiced   := 1;
                    l_trx_lines_tbl (ln_line_count).unit_selling_price   :=
                        ln_amount;
                    l_trx_lines_tbl (ln_line_count).line_type           :=
                        'LINE';

                    IF gv_program_mode = gc_sales_credits
                    THEN
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.sales_cr_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.sales_cr_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.sales_cr_memo_gl_id_rev;
                        --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.sales_cr_inv_trx_type; --Commented for change 1.1
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                               lv_conc_store_rt.sales_cr_inv_trx_type
                            || '-'
                            || gv_program_mode;         --Added for change 1.1
                    ELSIF gv_program_mode = gc_ancillary1
                    THEN
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.ancillary1_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.ancillary1_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.ancillary1_memo_gl_id_rev;
                        --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary1_inv_trx_type; --Commented for change 1.1
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                               lv_conc_store_rt.ancillary1_inv_trx_type
                            || '-'
                            || gv_program_mode;         --Added for change 1.1
                    ELSIF gv_program_mode = gc_ancillary2
                    THEN
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.ancillary2_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.ancillary2_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.ancillary2_memo_gl_id_rev;
                        --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary2_inv_trx_type; --Commented for change 1.1
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                               lv_conc_store_rt.ancillary2_inv_trx_type
                            || '-'
                            || gv_program_mode;         --Added for change 1.1
                    END IF;

                    l_trx_lines_tbl (ln_line_count).taxable_flag        :=
                        'N';                    --Tax should not be calculated
                    l_trx_lines_tbl (ln_line_count).amount_includes_tax_flag   :=
                        'N';                    --Tax should not be calculated
                    --Interface line Context
                    l_trx_lines_tbl (ln_line_count).interface_line_context   :=
                        'CONCESSIONS';                       --l_line_context;
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute1   :=
                        data_rec.sequence_id;
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute3   :=
                        lv_conc_store_rt.store_number;
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute4   :=
                        lv_conc_store_rt.brand;

                    IF gv_reprocess_flag = 'Y'
                    THEN
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute5   :=
                            'REPROCESSED';
                    ELSE
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute5   :=
                            'PROCESSED';
                    END IF;

                    -- l_trx_lines_tbl(ln_line_count).interface_line_attribute6    := TO_CHAR(SYSDATE, 'RRRR/MM/DD HH24:MI:SS'); --W.r.t Version 1.2
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute6   :=
                        TO_CHAR (SYSDATE, 'RRRRMMDDHH24MISS'); --W.r.t Version 1.2
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute7   :=
                        gn_conc_request_id;                            --'-1';

                    --Distributions
                    l_trx_dist_tbl (ln_line_count).trx_dist_id          :=
                        ln_int_dist_id;
                    l_trx_dist_tbl (ln_line_count).trx_line_id          :=
                        ln_int_line_id;
                    l_trx_dist_tbl (ln_line_count).account_class        :=
                        'REV';
                    l_trx_dist_tbl (ln_line_count).percent              :=
                        100;
                END IF;
            END LOOP;                                      --data_cur end loop

            --If the program version is FINAL, data is valid and Period is Open or the variable USE_CURRENT_PERIOD_DATE is Yes
            --then call Create AR Transactions Procedure
            IF (gv_version = 'FINAL' --AND ln_is_period_open_cnt > 0 --Commented for change 1.1
                                     AND (ln_is_period_open_cnt > 0 OR gv_use_curr_per_dt = 'Y') --Added for change 1.1
                                                                                                 AND ln_valid_status = 0)
            THEN
                --Added below IF Condition for change 1.1 --STARt
                --Call create AR transaction only if the header, line and distribution table type variables have data
                IF (l_trx_header_tbl.COUNT > 0 AND l_trx_lines_tbl.COUNT > 0 --Added for change 1.1
                                                                             AND l_trx_dist_tbl.COUNT > 0 --Added for change 1.1
                                                                                                         )
                THEN
                    --msg('Version is FINAL, so calling create_ar_trxns procedure - START', 'Y');
                    create_ar_trxns (
                        pn_org_id                => pn_org_id,
                        p_batch_source_rec       => l_batch_source_rec,
                        p_trx_header_tbl         => l_trx_header_tbl,
                        p_trx_lines_tbl          => l_trx_lines_tbl,
                        p_trx_dist_tbl           => l_trx_dist_tbl,
                        p_trx_salescredits_tbl   => l_trx_salescredits_tbl,
                        x_customer_trx_id        => ln_customer_trx_id,
                        x_ret_sts                => lv_ret_sts,
                        x_ret_msg                => lv_ret_msg);

                    IF    ln_customer_trx_id IS NULL
                       OR lv_ret_sts <> gv_ret_success
                    THEN
                        NULL;
                    ELSE
                        upd_ar_trx_det_to_stg (
                            pn_customer_trx_id   => ln_customer_trx_id,
                            x_ret_msg            => lv_return_msg,
                            x_ret_sts            => ln_return_sts);
                    END IF;
                ELSE
                    msg (
                        'Transaction header, line and distribution table type variables does not have any data. Please check.');
                END IF;                          --Table type variables end if
            --msg('Version is FINAL, so calling create_ar_trxns procedure - END', 'Y');
            END IF;                          --version and valid status end if
        END LOOP;                                          --main_cur end loop

        IF ln_valid_status <> 0
        THEN
            msg (
                   'Setup Details are missing for store#'
                || pn_store_number
                || ' in XXD_AR_CONCESSION_STORES lookup. Please Check.');
        END IF;

        msg ('Consolidated = YES and Group by Period = YES procedure - END',
             'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || gv_package_name
                    || lv_proc_name
                    || ' . Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
    END cons_yes_grp_by_yes;

    PROCEDURE cons_yes_grp_by_no (pn_store_number IN NUMBER, pv_brand IN VARCHAR2, pn_org_id IN NUMBER)
    IS
        --Local Variables Declaration
        --Scalar Variables
        lv_proc_name                VARCHAR2 (30) := 'CONS_YES_GRP_BY_NO';
        lv_err_msg                  VARCHAR2 (2000) := NULL;
        ln_batch_source_id          NUMBER := NULL;
        ln_customer_id              NUMBER := NULL;
        ln_bill_to_site_use_id      NUMBER := NULL;
        ld_trx_date                 DATE := NULL;
        ln_int_hdr_id               NUMBER := NULL;
        ln_int_line_id              NUMBER := NULL;
        ln_int_dist_id              NUMBER := NULL;
        ln_line_count               NUMBER := NULL;
        ln_terms_id                 NUMBER := NULL;
        lv_currency_code            VARCHAR2 (10) := NULL;
        ln_customer_trx_id          NUMBER := NULL;
        lv_ret_sts                  VARCHAR2 (1) := NULL;
        lv_ret_msg                  VARCHAR2 (2000) := NULL;
        ln_return_sts               NUMBER := NULL;
        lv_return_msg               VARCHAR2 (2000) := NULL;
        ln_amount                   NUMBER := NULL;
        ln_is_period_open_cnt       NUMBER := NULL;
        ln_valid_status             NUMBER := NULL;
        lv_next_open_per_name       VARCHAR2 (15) := NULL; --Added for change 1.1
        ld_next_open_per_start_dt   DATE := NULL;       --Added for change 1.1
        ld_next_open_per_end_dt     DATE := NULL;       --Added for change 1.1
        lv_trx_period_err_msg       VARCHAR2 (2000) := NULL; --Added for change 1.1
        --Non-Scalar Variables
        lv_conc_store_rt            apps.xxd_ar_concession_stores_v%ROWTYPE;
        l_trx_header_tbl            ar_invoice_api_pub.trx_header_tbl_type;
        l_trx_lines_tbl             ar_invoice_api_pub.trx_line_tbl_type;
        l_trx_dist_tbl              ar_invoice_api_pub.trx_dist_tbl_type;
        l_trx_salescredits_tbl      ar_invoice_api_pub.trx_salescredits_tbl_type;
        l_batch_source_rec          ar_invoice_api_pub.batch_source_rec_type;

        --Cursor to get distinct store, brand, and period information for grouping the data and creating transactions(INV/CM)
        CURSOR main_cur IS
              SELECT --gp_cur.period_name current_period_name, --Commented for change 1.1
                     gp.period_name trx_period_name, gp.period_year trx_period_year, gp.period_num trx_period_num,
                     gp.start_date trx_period_start_date, gp.end_date trx_period_end_date, stg.store_number,
                     stg.brand, MAX (transaction_date) max_trx_date
                FROM xxdo.xxd_ar_concession_store_trx_t stg, apps.gl_periods gp
               --,apps.gl_periods gp_cur
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N' --To pick records inserted with NULL or 'N' status
                     --AND (stg.reprocess_flag IS NULL OR stg.reprocess_flag <> 'R')--To pick all new records(Not the records which needs to be reprocessed)
                     --Commented below condition by Kranthi Bollam on 30OCT2018
                     --AND stg.transaction_date >= DECODE(gd_as_of_date, TRUNC(SYSDATE), stg.transaction_date, gd_as_of_date) --If date is current date, pull all records, else pull trxns with trx_date greater than or equal to ld_as_of_date
                     AND TRUNC (stg.transaction_date) <= gd_as_of_date --Added below condition by Kranthi Bollam on 30OCT2018
                     AND stg.store_number = pn_store_number
                     AND stg.brand = pv_brand
                     --This gives us the records which are are NEW or not processed if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                     AND (   (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'N'
                                  END)
                          OR --This below case gives us the Error Records if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                             (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'E'
                                  END))
                     --Added below the trx date from and to conditions to be considered only when reprocess flag parameter is YES
                     AND TRUNC (stg.transaction_date) BETWEEN (CASE
                                                                   WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                                                   THEN
                                                                       NVL (gd_trx_date_from, TRUNC (stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (stg.transaction_date)
                                                               END)
                                                          AND (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_to,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     AND TRUNC (stg.transaction_date) BETWEEN gp.start_date
                                                          AND gp.end_date
            --           AND gp_cur.period_set_name = 'DO_FY_CALENDAR'  --Commented for change 1.1
            --           AND TRUNC(SYSDATE) BETWEEN gp_cur.start_date and gp_cur.end_date --Commented for change 1.1
            GROUP BY --gp_cur.period_name,  --Commented for change 1.1
                     gp.period_name, gp.period_year, gp.period_num,
                     gp.start_date, gp.end_date, stg.store_number,
                     stg.brand
            ORDER BY gp.period_year, gp.period_num;

        --Cursor to get data for store, brand, and period
        CURSOR data_cur (cv_period_name IN VARCHAR2)
        IS
              SELECT --gp_cur.period_name current_period_name,  --Commented for change 1.1
                     gp.period_name
                         trx_period_name,
                     gp.period_year
                         trx_period_year,
                     gp.period_num
                         trx_period_num,
                     gp.start_date
                         trx_period_start_date,
                     gp.end_date
                         trx_period_end_date,
                     apps.xxd_ar_concessions_trx_pkg.get_calculated_amt (
                         pv_program_mode      => gv_program_mode,
                         pn_store_number      => stg.store_number,
                         pv_brand             => stg.brand,
                         pn_org_id            => pn_org_id,
                         pn_retail_amount     => NVL (stg.retail_amount, 0),
                         pn_discount_amount   => NVL (stg.discount_amount, 0),
                         pn_paytotal_amount   => NVL (stg.paytotal_amount, 0),
                         pn_tax_amount        => NVL (stg.tax_amount, 0))
                         calc_amount,
                     stg.*
                FROM xxdo.xxd_ar_concession_store_trx_t stg, apps.gl_periods gp
               --,apps.gl_periods gp_cur  --Commented for change 1.1
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N' --To pick records inserted with NULL or 'N' status
                     --AND (stg.reprocess_flag IS NULL OR stg.reprocess_flag <> 'R')--To pick all new records(Not the records which needs to be reprocessed)
                     --Commented below condition by Kranthi Bollam on 30OCT2018
                     --AND stg.transaction_date >= DECODE(gd_as_of_date, TRUNC(SYSDATE), stg.transaction_date, gd_as_of_date) --If date is current date, pull all records, else pull trxns with trx_date greater than or equal to ld_as_of_date
                     AND TRUNC (stg.transaction_date) <= gd_as_of_date --Added below condition by Kranthi Bollam on 30OCT2018
                     AND stg.store_number = pn_store_number
                     AND stg.brand = pv_brand
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     AND TRUNC (stg.transaction_date) BETWEEN gp.start_date
                                                          AND gp.end_date
                     --This gives us the records which are are NEW or not processed if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                     AND (   (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'N'
                                  END)
                          OR --This below case gives us the Error Records if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                             (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'E'
                                  END))
                     --Added below the trx date from and to conditions to be considered only when reprocess flag parameter is YES
                     AND TRUNC (stg.transaction_date) BETWEEN (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_from,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                                                          AND (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_to,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                     AND gp.period_name = cv_period_name
            --           AND gp_cur.period_set_name = 'DO_FY_CALENDAR'  --Commented for change 1.1
            --           AND TRUNC(SYSDATE) BETWEEN gp_cur.start_date and gp_cur.end_date  --Commented for change 1.1
            ORDER BY gp.period_year, gp.period_num, stg.rms_tran_seq_no;
    BEGIN
        msg ('Consolidated = YES and Group by Period = NO procedure - START',
             'Y');

        --Get the values from the stores setup for the store, brand and Operating unit combination
        --and assign it to lv_conc_store_rt variable
        BEGIN
            SELECT st.*
              INTO lv_conc_store_rt
              FROM apps.xxd_ar_concession_stores_v st
             WHERE     1 = 1
                   AND st.store_number = pn_store_number
                   AND st.brand = pv_brand
                   AND st.operating_unit_id = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'When Others Exception in '
                        || gv_package_name
                        || lv_proc_name
                        || 'while getting Sales/Credits Config values for store = '
                        || pn_store_number
                        || ' and brand = '
                        || pv_brand,
                        1,
                        2000);
                msg (lv_err_msg);
                msg ('Error is:' || SQLERRM);
        END;

        --Assigning Values to Variables
        ln_batch_source_id   := lv_conc_store_rt.batch_source_id;
        lv_currency_code     := lv_conc_store_rt.currency_code;

        IF lv_conc_store_rt.cust_account_id IS NOT NULL
        THEN
            ln_customer_id   := lv_conc_store_rt.cust_account_id;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Sales Credit Customer Number is NULL for Store#:'
                    || pn_store_number
                    || ' and brand:'
                    || pv_brand
                    || ' and operating unit ID:'
                    || pn_org_id,
                    1,
                    2000);
            msg (lv_err_msg);
        END IF;

        IF lv_conc_store_rt.cust_bill_to_site_use_id IS NOT NULL
        THEN
            ln_bill_to_site_use_id   :=
                lv_conc_store_rt.cust_bill_to_site_use_id;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Sales Credit Customer Bill to Site is NULL for Store#:'
                    || pn_store_number
                    || ' and brand:'
                    || pv_brand
                    || ' and operating unit ID:'
                    || pn_org_id,
                    1,
                    2000);
            msg (lv_err_msg);
        END IF;

        IF    lv_conc_store_rt.cust_bill_to_site_use_id IS NOT NULL
           OR lv_conc_store_rt.cust_account_id IS NOT NULL
        THEN
            ln_terms_id   :=
                get_ar_terms (
                    pn_org_id        => pn_org_id,
                    pn_site_use_id   =>
                        lv_conc_store_rt.cust_bill_to_site_use_id --ln_bill_to_site_use_id
                                                                 ,
                    pn_customer_id   => lv_conc_store_rt.cust_account_id --ln_customer_id
                                                                        );
        END IF;

        --Process main cursor
        FOR main_rec IN main_cur
        LOOP
            ln_line_count        := 0;
            lv_ret_sts           := NULL;
            lv_ret_msg           := NULL;
            ln_customer_trx_id   := NULL;

            --Process data cursor
            FOR data_rec
                IN data_cur (cv_period_name => main_rec.trx_period_name)
            LOOP
                --Calling the procedure to update calculated amounts to the staging table
                update_calc_amt_stg (pn_sequence_id   => data_rec.sequence_id,
                                     pn_amount        => data_rec.calc_amount);

                --msg('Calling validate store setup data procedure - START', 'Y');
                ln_valid_status         := 0;
                validate_store_setup_data (
                    pn_sequence_id    => data_rec.sequence_id,
                    pn_store_number   => pn_store_number,
                    pv_brand          => pv_brand,
                    pn_org_id         => pn_org_id,
                    x_return_status   => ln_valid_status);
                --msg('Calling validate store setup data procedure - END', 'Y');

                --Check if period is open or not
                ln_is_period_open_cnt   := 0;
                ln_is_period_open_cnt   :=
                    get_period_status (
                        pn_org_id            => lv_conc_store_rt.operating_unit_id,
                        pv_trx_period_name   => main_rec.trx_period_name);

                IF ln_is_period_open_cnt <= 0
                THEN
                    --msg(' Transaction Date Period :'||main_rec.trx_period_name||' is not OPEN.');
                    --Added below if condition for change 1.1 --START
                    IF gv_use_curr_per_dt = 'Y'
                    THEN
                        --msg('Calling GET_NEXT_OPEN_PERIOD to get the next open period for trx date period : '||main_rec.trx_period_name);
                        get_next_open_period (
                            pn_org_id              => lv_conc_store_rt.operating_unit_id,
                            pd_trx_per_end_dt      =>
                                main_rec.trx_period_end_date,
                            x_next_open_per_name   => lv_next_open_per_name,
                            x_next_open_per_start_dt   =>
                                ld_next_open_per_start_dt,
                            x_next_open_per_end_dt   =>
                                ld_next_open_per_end_dt);
                        msg (
                               ' Transaction Date Period :'
                            || main_rec.trx_period_name
                            || ' is not OPEN, and USE_CURRENT_PERIOD_DATE is YES, creating transactions on Start date of next OPEN Period : '
                            || lv_next_open_per_name);
                    --msg('Next Open Period is : '||lv_next_open_per_name);
                    ELSE
                        --msg(' Transaction Date Period :'||main_rec.trx_period_name||' is not OPEN, and also USE_CURRENT_PERIOD_DATE is NO, so not creating transactions');
                        lv_trx_period_err_msg   :=
                               ' Transaction Date Period :'
                            || main_rec.trx_period_name
                            || ' is not OPEN, and also USE_CURRENT_PERIOD_DATE is NO, so not creating transactions';
                        msg (lv_trx_period_err_msg);
                        upd_errors_to_stg (
                            pn_sequence_id     => data_rec.sequence_id,
                            pv_error_message   => lv_trx_period_err_msg);
                    END IF;
                --Added above if condition for change 1.1 --END
                END IF;

                --If the program version is FINAL, data is valid and Period is Open or the variable USE_CURRENT_PERIOD_DATE is Yes
                --then proceed further
                IF (gv_version = 'FINAL' --AND ln_is_period_open_cnt > 0 --Commented for change 1.1
                                         AND (ln_is_period_open_cnt > 0 OR gv_use_curr_per_dt = 'Y') --Added for change 1.1
                                                                                                     AND ln_valid_status = 0)
                THEN
                    ln_line_count                                       := 0;
                    ln_line_count                                       := ln_line_count + 1;

                    --Commented the above code to determine trx date for change 1.1 --START
                    /*
                    --Determining transaction date
                    --If current period and trx period are different then trx date is last day of the trx period
                    --else trx date is the max trx date
                    IF data_rec.current_period_name <> data_rec.trx_period_name
                    THEN
                        ld_trx_date := data_rec.trx_period_end_date;
                    ELSE
                        ld_trx_date := data_rec.transaction_date;
                    END IF;
                    */
                    --Commented the above code to determine trx date for change 1.1 --END

                    --Added the below code to determine trx date for change 1.1 --START
                    --If the trx period is open, then trx date will be trx date
                    IF ln_is_period_open_cnt > 0
                    THEN
                        ld_trx_date   := data_rec.transaction_date;
                    --If trx period is not open and use current period is YES, then get the next open period start date and use it as trx date
                    ELSIF     ln_is_period_open_cnt <= 0
                          AND gv_use_curr_per_dt = 'Y'
                    THEN
                        ld_trx_date   := ld_next_open_per_start_dt;
                    END IF;

                    --Added the above code to determine trx date for change 1.1 --END

                    ln_amount                                           := data_rec.calc_amount; --Calculate amount

                    --Getting the interface header id to be passed to API
                    BEGIN
                        SELECT ra_customer_trx_s.NEXTVAL
                          INTO ln_int_hdr_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface header id from sequence RA_CUSTOMER_TRX_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Assigning values to API Batch Source Record table type variable
                    l_batch_source_rec.batch_source_id                  :=
                        ln_batch_source_id;                           -- 12003
                    --Assigning values to API Header table type variable
                    l_trx_header_tbl (1).trx_header_id                  := ln_int_hdr_id;

                    IF gv_program_mode = gc_sales_credits
                    THEN
                        l_trx_header_tbl (1).cust_trx_type_id   :=
                            lv_conc_store_rt.sales_cr_inv_trx_type_id;
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.sales_cr_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.sales_cr_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.sales_cr_memo_gl_id_rev;
                    ELSIF gv_program_mode = gc_ancillary1
                    THEN
                        l_trx_header_tbl (1).cust_trx_type_id   :=
                            lv_conc_store_rt.ancillary1_inv_trx_type_id;
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.ancillary1_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.ancillary1_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.ancillary1_memo_gl_id_rev;
                    ELSIF gv_program_mode = gc_ancillary2
                    THEN
                        l_trx_header_tbl (1).cust_trx_type_id   :=
                            lv_conc_store_rt.ancillary2_inv_trx_type_id;
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.ancillary2_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.ancillary2_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.ancillary2_memo_gl_id_rev;
                    END IF;

                    l_trx_header_tbl (1).bill_to_site_use_id            :=
                        ln_bill_to_site_use_id;
                    l_trx_header_tbl (1).trx_date                       := ld_trx_date;
                    l_trx_header_tbl (1).bill_to_customer_id            :=
                        ln_customer_id;
                    l_trx_header_tbl (1).term_id                        := ln_terms_id;
                    l_trx_header_tbl (1).attribute5                     :=
                        lv_conc_store_rt.brand;    --Mandatory at header level
                    l_trx_header_tbl (1).trx_currency                   :=
                        lv_currency_code;

                    --Getting the interface line id to be passed to API
                    BEGIN
                        SELECT ra_customer_trx_lines_s.NEXTVAL
                          INTO ln_int_line_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface Line id from sequence RA_CUSTOMER_TRX_LINES_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Getting the interface Distribution id to be passed to API
                    BEGIN
                        SELECT ra_cust_trx_line_gl_dist_s.NEXTVAL
                          INTO ln_int_dist_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface Distribution id from sequence RA_CUST_TRX_LINE_GL_DIST_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Assiging values to API line table type variable
                    l_trx_lines_tbl (ln_line_count).trx_header_id       :=
                        ln_int_hdr_id;
                    l_trx_lines_tbl (ln_line_count).trx_line_id         :=
                        ln_int_line_id;
                    l_trx_lines_tbl (ln_line_count).line_number         :=
                        ln_line_count;

                    --If consolidation is YES, we can pass the positive and negative values for line amount as this trx type accepts both positive and negative sign amounts
                    l_trx_lines_tbl (ln_line_count).uom_code            := 'EA';
                    l_trx_lines_tbl (ln_line_count).quantity_invoiced   := 1;
                    l_trx_lines_tbl (ln_line_count).unit_selling_price   :=
                        ln_amount;
                    l_trx_lines_tbl (ln_line_count).line_type           :=
                        'LINE';
                    l_trx_lines_tbl (ln_line_count).taxable_flag        :=
                        'N';                    --Tax should not be calculated
                    l_trx_lines_tbl (ln_line_count).amount_includes_tax_flag   :=
                        'N';                    --Tax should not be calculated

                    --Interface line Context
                    l_trx_lines_tbl (ln_line_count).interface_line_context   :=
                        'CONCESSIONS';
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute1   :=
                        data_rec.sequence_id;
                    --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.sales_cr_inv_trx_type; --Commented for change 1.1
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                           lv_conc_store_rt.sales_cr_inv_trx_type
                        || '-'
                        || gv_program_mode;             --Added for change 1.1
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute3   :=
                        lv_conc_store_rt.store_number;
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute4   :=
                        lv_conc_store_rt.brand;

                    IF gv_reprocess_flag = 'Y'
                    THEN
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute5   :=
                            'REPROCESSED';
                    ELSE
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute5   :=
                            'PROCESSED';
                    END IF;

                    --  l_trx_lines_tbl(ln_line_count).interface_line_attribute6    := TO_CHAR(SYSDATE, 'RRRR/MM/DD HH24:MI:SS'); --w.r.t Version 1.2
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute6   :=
                        TO_CHAR (SYSDATE, 'RRRRMMDDHH24MISS'); --w.r.t Version 1.2
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute7   :=
                        gn_conc_request_id;

                    --Distributions
                    l_trx_dist_tbl (ln_line_count).trx_dist_id          :=
                        ln_int_dist_id;
                    l_trx_dist_tbl (ln_line_count).trx_line_id          :=
                        ln_int_line_id;
                    l_trx_dist_tbl (ln_line_count).account_class        :=
                        'REV';
                    l_trx_dist_tbl (ln_line_count).percent              :=
                        100;

                    --Added below IF Condition for change 1.1 --STARt
                    --Call create AR transaction only if the header, line and distribution table type variables have data
                    IF (l_trx_header_tbl.COUNT > 0 AND l_trx_lines_tbl.COUNT > 0 --Added for change 1.1
                                                                                 AND l_trx_dist_tbl.COUNT > 0 --Added for change 1.1
                                                                                                             )
                    THEN
                        --Call AR Transactions creation procedure
                        create_ar_trxns (
                            pn_org_id                => pn_org_id,
                            p_batch_source_rec       => l_batch_source_rec,
                            p_trx_header_tbl         => l_trx_header_tbl,
                            p_trx_lines_tbl          => l_trx_lines_tbl,
                            p_trx_dist_tbl           => l_trx_dist_tbl,
                            p_trx_salescredits_tbl   => l_trx_salescredits_tbl,
                            x_customer_trx_id        => ln_customer_trx_id,
                            x_ret_sts                => lv_ret_sts,
                            x_ret_msg                => lv_ret_msg);

                        IF    ln_customer_trx_id IS NULL
                           OR lv_ret_sts <> gv_ret_success
                        THEN
                            NULL;
                        ELSE
                            upd_ar_trx_det_to_stg (
                                pn_customer_trx_id   => ln_customer_trx_id,
                                x_ret_msg            => lv_return_msg,
                                x_ret_sts            => ln_return_sts);
                        END IF;
                    ELSE
                        --msg('Transaction header, line and distribution table type variables does not have any data. Please check.');
                        lv_err_msg   :=
                            'Transaction header, line and distribution table type variables does not have any data. Please Check.';
                        upd_errors_to_stg (
                            pn_sequence_id     => data_rec.sequence_id,
                            pv_error_message   => lv_err_msg);
                    END IF;                      --Table type variables end if
                END IF;                    --gv_version and period open end if
            END LOOP;                                      --data_cur end loop
        END LOOP;                                          --main_cur end loop

        IF ln_valid_status <> 0
        THEN
            msg (
                   'Setup Details are missing for store#'
                || pn_store_number
                || ' in XXD_AR_CONCESSION_STORES lookup. Please Check.');
        END IF;

        msg ('Consolidated = YES and Group by Period = NO procedure - END',
             'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || gv_package_name
                    || lv_proc_name
                    || ' . Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
    END cons_yes_grp_by_no;

    PROCEDURE cons_no_grp_by_yes (pn_store_number IN NUMBER, pv_brand IN VARCHAR2, pn_org_id IN NUMBER)
    IS
        --Local Variables Declaration
        --Scalar Variables
        lv_proc_name                VARCHAR2 (30) := 'CONS_NO_GRP_BY_YES';
        lv_err_msg                  VARCHAR2 (2000) := NULL;
        ln_batch_source_id          NUMBER := NULL;
        ln_customer_id              NUMBER := NULL;
        ln_bill_to_site_use_id      NUMBER := NULL;
        ld_trx_date                 DATE := NULL;
        ln_int_hdr_id               NUMBER := NULL;
        ln_int_line_id              NUMBER := NULL;
        ln_int_dist_id              NUMBER := NULL;
        ln_line_count               NUMBER := NULL;
        ln_terms_id                 NUMBER := NULL;
        lv_currency_code            VARCHAR2 (10) := NULL;
        ln_customer_trx_id          NUMBER := NULL;
        lv_ret_sts                  VARCHAR2 (1) := NULL;
        lv_ret_msg                  VARCHAR2 (2000) := NULL;
        ln_return_sts               NUMBER := NULL;
        lv_return_msg               VARCHAR2 (2000) := NULL;
        ln_amount                   NUMBER := NULL;
        ln_is_period_open_cnt       NUMBER := NULL;
        ln_valid_status             NUMBER := NULL;
        lv_next_open_per_name       VARCHAR2 (15) := NULL; --Added for change 1.1
        ld_next_open_per_start_dt   DATE := NULL;       --Added for change 1.1
        ld_next_open_per_end_dt     DATE := NULL;       --Added for change 1.1
        lv_trx_period_err_msg       VARCHAR2 (2000) := NULL; --Added for change 1.1
        --Non-Scalar Variables
        lv_conc_store_rt            apps.xxd_ar_concession_stores_v%ROWTYPE;
        l_trx_header_tbl            ar_invoice_api_pub.trx_header_tbl_type;
        l_trx_lines_tbl             ar_invoice_api_pub.trx_line_tbl_type;
        l_trx_dist_tbl              ar_invoice_api_pub.trx_dist_tbl_type;
        l_trx_salescredits_tbl      ar_invoice_api_pub.trx_salescredits_tbl_type;
        l_batch_source_rec          ar_invoice_api_pub.batch_source_rec_type;

        --Cursor to get distinct store, brand, and period information for grouping the data and creating transactions(INV/CM)
        CURSOR main_cur IS
              SELECT --gp_cur.period_name current_period_name,  --Commented for change 1.1
                     gp.period_name
                         trx_period_name,
                     gp.period_year
                         trx_period_year,
                     gp.period_num
                         trx_period_num,
                     gp.start_date
                         trx_period_start_date,
                     gp.end_date
                         trx_period_end_date,
                     stg.store_number,
                     stg.brand,
                     SIGN (apps.xxd_ar_concessions_trx_pkg.get_calculated_amt (
                               pv_program_mode    => gv_program_mode,
                               pn_store_number    => stg.store_number,
                               pv_brand           => stg.brand,
                               pn_org_id          => pn_org_id,
                               pn_retail_amount   => NVL (stg.retail_amount, 0),
                               pn_discount_amount   =>
                                   NVL (stg.discount_amount, 0),
                               pn_paytotal_amount   =>
                                   NVL (stg.paytotal_amount, 0),
                               pn_tax_amount      => NVL (stg.tax_amount, 0)))
                         calc_amount_sign,
                     MAX (stg.transaction_date)
                         max_trx_date
                FROM xxdo.xxd_ar_concession_store_trx_t stg, apps.gl_periods gp
               --,apps.gl_periods gp_cur  --Commented for change 1.1
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N' --To pick records inserted with NULL or 'N' status
                     --Commented below condition by Kranthi Bollam on 30OCT2018
                     --AND stg.transaction_date >= DECODE(gd_as_of_date, TRUNC(SYSDATE), stg.transaction_date, gd_as_of_date) --If date is current date, pull all records, else pull trxns with trx_date greater than or equal to ld_as_of_date
                     AND TRUNC (stg.transaction_date) <= gd_as_of_date --Added below condition by Kranthi Bollam on 30OCT2018
                     AND stg.store_number = pn_store_number
                     AND stg.brand = pv_brand
                     --This gives us the records which are are NEW or not processed if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                     AND (   (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'N'
                                  END)
                          OR --This below case gives us the Error Records if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                             (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'E'
                                  END))
                     --Added below the trx date from and to conditions to be considered only when reprocess flag parameter is YES
                     AND TRUNC (stg.transaction_date) BETWEEN (CASE
                                                                   WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                                                   THEN
                                                                       NVL (gd_trx_date_from, TRUNC (stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (stg.transaction_date)
                                                               END)
                                                          AND (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_to,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     AND TRUNC (stg.transaction_date) BETWEEN gp.start_date
                                                          AND gp.end_date
            --           AND gp_cur.period_set_name = 'DO_FY_CALENDAR'  --Commented for change 1.1
            --           AND TRUNC(SYSDATE) BETWEEN gp_cur.start_date and gp_cur.end_date  --Commented for change 1.1
            GROUP BY --gp_cur.period_name,  --Commented for change 1.1
                     gp.period_name,
                     gp.period_year,
                     gp.period_num,
                     gp.start_date,
                     gp.end_date,
                     stg.store_number,
                     stg.brand,
                     SIGN (apps.xxd_ar_concessions_trx_pkg.get_calculated_amt (
                               pv_program_mode   => gv_program_mode,
                               pn_store_number   => stg.store_number,
                               pv_brand          => stg.brand,
                               pn_org_id         => pn_org_id,
                               pn_retail_amount   =>
                                   NVL (stg.retail_amount, 0),
                               pn_discount_amount   =>
                                   NVL (stg.discount_amount, 0),
                               pn_paytotal_amount   =>
                                   NVL (stg.paytotal_amount, 0),
                               pn_tax_amount     => NVL (stg.tax_amount, 0)))
            ORDER BY gp.period_year, gp.period_num;

        --Cursor to get data for store, brand, and period
        CURSOR data_cur (cv_period_name     IN VARCHAR2,
                         cv_calc_amt_sign   IN NUMBER)
        IS
              SELECT --gp_cur.period_name current_period_name,  --Commented for change 1.1
                     gp.period_name
                         trx_period_name,
                     gp.period_year
                         trx_period_year,
                     gp.period_num
                         trx_period_num,
                     gp.start_date
                         trx_period_start_date,
                     gp.end_date
                         trx_period_end_date,
                     apps.xxd_ar_concessions_trx_pkg.get_calculated_amt (
                         pv_program_mode      => gv_program_mode,
                         pn_store_number      => stg.store_number,
                         pv_brand             => stg.brand,
                         pn_org_id            => pn_org_id,
                         pn_retail_amount     => NVL (stg.retail_amount, 0),
                         pn_discount_amount   => NVL (stg.discount_amount, 0),
                         pn_paytotal_amount   => NVL (stg.paytotal_amount, 0),
                         pn_tax_amount        => NVL (stg.tax_amount, 0))
                         calc_amount,
                     stg.*
                FROM xxdo.xxd_ar_concession_store_trx_t stg, apps.gl_periods gp
               --,apps.gl_periods gp_cur  --Commented for change 1.1
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N' --To pick records inserted with NULL or 'N' status
                     --AND (stg.reprocess_flag IS NULL OR stg.reprocess_flag <> 'R')--To pick all new records(Not the records which needs to be reprocessed)
                     --Commented below condition by Kranthi Bollam on 30OCT2018
                     --AND stg.transaction_date >= DECODE(gd_as_of_date, TRUNC(SYSDATE), stg.transaction_date, gd_as_of_date) --If date is current date, pull all records, else pull trxns with trx_date greater than or equal to ld_as_of_date
                     AND TRUNC (stg.transaction_date) <= gd_as_of_date --Added below condition by Kranthi Bollam on 30OCT2018
                     AND stg.store_number = pn_store_number
                     AND stg.brand = pv_brand
                     --This gives us the records which are are NEW or not processed if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                     AND (   (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'N'
                                  END)
                          OR --This below case gives us the Error Records if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                             (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'E'
                                  END))
                     --Added below the trx date from and to conditions to be considered only when reprocess flag parameter is YES
                     AND TRUNC (stg.transaction_date) BETWEEN (CASE
                                                                   WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                                                   THEN
                                                                       NVL (gd_trx_date_from, TRUNC (stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (stg.transaction_date)
                                                               END)
                                                          AND (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_to,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     AND TRUNC (stg.transaction_date) BETWEEN gp.start_date
                                                          AND gp.end_date
                     AND gp.period_name = cv_period_name
                     --           AND gp_cur.period_set_name = 'DO_FY_CALENDAR'  --Commented for change 1.1
                     --           AND TRUNC(SYSDATE) BETWEEN gp_cur.start_date and gp_cur.end_date  --Commented for change 1.1
                     AND NVL (SIGN (apps.xxd_ar_concessions_trx_pkg.get_calculated_amt (
                                        pv_program_mode   => gv_program_mode,
                                        pn_store_number   => stg.store_number,
                                        pv_brand          => stg.brand,
                                        pn_org_id         => pn_org_id,
                                        pn_retail_amount   =>
                                            NVL (stg.retail_amount, 0),
                                        pn_discount_amount   =>
                                            NVL (stg.discount_amount, 0),
                                        pn_paytotal_amount   =>
                                            NVL (stg.paytotal_amount, 0),
                                        pn_tax_amount     =>
                                            NVL (stg.tax_amount, 0))),
                              9) = NVL (cv_calc_amt_sign, 9) --Added NVL on both sides for change 1.1
            ORDER BY gp.period_year, gp.period_num, stg.rms_tran_seq_no;
    BEGIN
        msg ('Consolidated = NO and Group by Period = YES procedure - START',
             'Y');

        --Get the values from the stores setup for the store, brand and Operating unit combination
        --and assign it to lv_conc_store_rt variable
        BEGIN
            SELECT st.*
              INTO lv_conc_store_rt
              FROM apps.xxd_ar_concession_stores_v st
             WHERE     1 = 1
                   AND st.store_number = pn_store_number
                   AND st.brand = pv_brand
                   AND st.operating_unit_id = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'When Others Exception in '
                        || gv_package_name
                        || lv_proc_name
                        || 'while getting Sales/Credits Config values for store = '
                        || pn_store_number
                        || ' and brand = '
                        || pv_brand,
                        1,
                        2000);
                msg (lv_err_msg);
                msg ('Error is:' || SQLERRM);
        END;

        --Assigning Values to Variables
        ln_batch_source_id   := lv_conc_store_rt.batch_source_id;
        lv_currency_code     := lv_conc_store_rt.currency_code;

        IF lv_conc_store_rt.cust_account_id IS NOT NULL
        THEN
            ln_customer_id   := lv_conc_store_rt.cust_account_id;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Sales Credit Customer Number is NULL for Store#:'
                    || pn_store_number
                    || ' and brand:'
                    || pv_brand
                    || ' and operating unit ID:'
                    || pn_org_id,
                    1,
                    2000);
            msg (lv_err_msg);
        END IF;

        IF lv_conc_store_rt.cust_bill_to_site_use_id IS NOT NULL
        THEN
            ln_bill_to_site_use_id   :=
                lv_conc_store_rt.cust_bill_to_site_use_id;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Sales Credit Customer Bill to Site is NULL for Store#:'
                    || pn_store_number
                    || ' and brand:'
                    || pv_brand
                    || ' and operating unit ID:'
                    || pn_org_id,
                    1,
                    2000);
            msg (lv_err_msg);
        END IF;

        IF ln_bill_to_site_use_id IS NOT NULL OR ln_customer_id IS NOT NULL
        THEN
            ln_terms_id   :=
                get_ar_terms (pn_org_id        => pn_org_id,
                              pn_site_use_id   => ln_bill_to_site_use_id,
                              pn_customer_id   => ln_customer_id);
        END IF;

        --Process main cursor
        FOR main_rec IN main_cur
        LOOP
            IF gv_version = 'FINAL'
            THEN
                lv_ret_sts              := NULL;
                lv_ret_msg              := NULL;
                ln_customer_trx_id      := NULL;
                ln_line_count           := 0;

                --Check if period is open or not
                ln_is_period_open_cnt   := 0;
                ln_is_period_open_cnt   :=
                    get_period_status (
                        pn_org_id            => lv_conc_store_rt.operating_unit_id,
                        pv_trx_period_name   => main_rec.trx_period_name);

                IF ln_is_period_open_cnt <= 0
                THEN
                    -- msg('Transaction Date Period :'||main_rec.trx_period_name||' is not OPEN.');
                    --Added below if condition for change 1.1 --START
                    IF gv_use_curr_per_dt = 'Y'
                    THEN
                        get_next_open_period (
                            pn_org_id              => lv_conc_store_rt.operating_unit_id,
                            pd_trx_per_end_dt      =>
                                main_rec.trx_period_end_date,
                            x_next_open_per_name   => lv_next_open_per_name,
                            x_next_open_per_start_dt   =>
                                ld_next_open_per_start_dt,
                            x_next_open_per_end_dt   =>
                                ld_next_open_per_end_dt);
                        msg (
                               ' Transaction Date Period :'
                            || main_rec.trx_period_name
                            || ' is not OPEN, and USE_CURRENT_PERIOD_DATE is YES, creating transactions on Start date of next OPEN Period : '
                            || lv_next_open_per_name);
                    --msg('Next Open Period is : '||lv_next_open_per_name);
                    ELSE
                        --msg(' Transaction Date Period :'||main_rec.trx_period_name||' is not OPEN, and also USE_CURRENT_PERIOD_DATE is NO, so not creating transactions');
                        lv_trx_period_err_msg   :=
                               ' Transaction Date Period :'
                            || main_rec.trx_period_name
                            || ' is not OPEN, and also USE_CURRENT_PERIOD_DATE is NO, so not creating transactions';
                        msg (lv_trx_period_err_msg);
                    END IF;
                --Added above if condition for change 1.1 --END
                END IF;                                 --Added for change 1.1

                --ELSE --Commented for change 1.1
                IF (ln_is_period_open_cnt > 0 OR gv_use_curr_per_dt = 'Y') --Added for change 1.1
                THEN
                    --Commented the above code to determine trx date for change 1.1 --START
                    /*
                    --Determining transaction date
                    --If current period and trx period are different then trx date is last day of trx period
                    --else trx date is the max trx date
                    IF main_rec.current_period_name <> main_rec.trx_period_name
                    THEN
                        --ld_trx_date := main_rec.trx_period_end_date;
                    ELSE
                        ld_trx_date := main_rec.max_trx_date;
                    END IF;
                    */
                    --Commented the above code to determine trx date for change 1.1 --END

                    --Added the below code to determine trx date for change 1.1 --START
                    --If the trx period is open, then trx date will be max trx date
                    IF ln_is_period_open_cnt > 0
                    THEN
                        ld_trx_date   := main_rec.max_trx_date;
                    --If trx period is not open and use current period is YES, then get the next open period start date and use it as trx date
                    ELSIF     ln_is_period_open_cnt <= 0
                          AND gv_use_curr_per_dt = 'Y'
                    THEN
                        ld_trx_date   := ld_next_open_per_start_dt;
                    END IF;

                    --Added the above code to determine trx date for change 1.1 --END

                    --Getting the interface header id to be passed to API
                    BEGIN
                        SELECT ra_customer_trx_s.NEXTVAL
                          INTO ln_int_hdr_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface header id from sequence RA_CUSTOMER_TRX_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Assigning values to API Batch Source Record table type variable
                    l_batch_source_rec.batch_source_id         :=
                        ln_batch_source_id;
                    --Assigning values to API Header table type variable
                    l_trx_header_tbl (1).trx_header_id         := ln_int_hdr_id;
                    l_trx_header_tbl (1).bill_to_site_use_id   :=
                        ln_bill_to_site_use_id;
                    l_trx_header_tbl (1).trx_date              := ld_trx_date;
                    l_trx_header_tbl (1).bill_to_customer_id   :=
                        ln_customer_id;
                    l_trx_header_tbl (1).attribute5            :=
                        lv_conc_store_rt.brand;    --Mandatory at header level
                    l_trx_header_tbl (1).trx_currency          :=
                        lv_currency_code;
                END IF;                         --ln_is_period_open_cnt end if
            END IF;                                           --version end if

            --Process data cursor
            FOR data_rec
                IN data_cur (cv_period_name     => main_rec.trx_period_name,
                             cv_calc_amt_sign   => main_rec.calc_amount_sign)
            LOOP
                update_calc_amt_stg (pn_sequence_id   => data_rec.sequence_id,
                                     pn_amount        => data_rec.calc_amount);

                --msg('Calling validate store setup data procedure - START', 'Y');
                ln_valid_status   := 0;
                validate_store_setup_data (
                    pn_sequence_id    => data_rec.sequence_id,
                    pn_store_number   => pn_store_number,
                    pv_brand          => pv_brand,
                    pn_org_id         => pn_org_id,
                    x_return_status   => ln_valid_status);

                --msg('Calling validate store setup data procedure - END', 'Y');

                --Added below if condition for change 1.1 --START
                --Update the staging table if the transaction date period is not open and Use Current Period Date is NO
                IF ln_is_period_open_cnt <= 0 AND gv_use_curr_per_dt = 'N'
                THEN
                    upd_errors_to_stg (
                        pn_sequence_id     => data_rec.sequence_id,
                        pv_error_message   => lv_trx_period_err_msg);
                END IF;

                --Added above if condition for change 1.1 --END

                --Check the program version and take action accordingly
                IF (gv_version = 'FINAL' --AND ln_is_period_open_cnt > 0--Commented for change 1.1
                                         AND (ln_is_period_open_cnt > 0 OR gv_use_curr_per_dt = 'Y') --Added for change 1.1
                                                                                                     AND ln_valid_status = 0)
                THEN
                    --ln_line_count := 0;
                    ln_line_count                                   := ln_line_count + 1;
                    ln_amount                                       := data_rec.calc_amount;

                    IF SIGN (ln_amount) = 1
                    THEN
                        l_trx_header_tbl (1).term_id   := ln_terms_id;

                        IF gv_program_mode = gc_sales_credits
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.sales_cr_inv_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2     := lv_conc_store_rt.sales_cr_inv_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.sales_cr_inv_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        ELSIF gv_program_mode = gc_ancillary1
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.ancillary1_inv_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary1_inv_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.ancillary1_inv_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        ELSIF gv_program_mode = gc_ancillary2
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.ancillary2_inv_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary2_inv_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.ancillary2_inv_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        END IF;
                    ELSIF SIGN (ln_amount) = -1
                    THEN
                        l_trx_header_tbl (1).term_id   := NULL;

                        IF gv_program_mode = gc_sales_credits
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.sales_cr_cm_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2     := lv_conc_store_rt.sales_cr_cm_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.sales_cr_cm_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        ELSIF gv_program_mode = gc_ancillary1
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.ancillary1_cm_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary1_cm_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.ancillary1_cm_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        ELSIF gv_program_mode = gc_ancillary2
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.ancillary2_cm_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary2_cm_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.ancillary2_cm_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        END IF;
                    ELSE
                        l_trx_header_tbl (1).cust_trx_type_id   := NULL;
                    END IF;

                    IF gv_program_mode = gc_sales_credits
                    THEN
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.sales_cr_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.sales_cr_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.sales_cr_memo_gl_id_rev;
                    ELSIF gv_program_mode = gc_ancillary1
                    THEN
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.ancillary1_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.ancillary1_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.ancillary1_memo_gl_id_rev;
                    ELSIF gv_program_mode = gc_ancillary2
                    THEN
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.ancillary2_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.ancillary2_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.ancillary2_memo_gl_id_rev;
                    END IF;

                    --Getting the interface line id to be passed to API
                    BEGIN
                        SELECT ra_customer_trx_lines_s.NEXTVAL
                          INTO ln_int_line_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface Line id from sequence RA_CUSTOMER_TRX_LINES_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Getting the interface Distribution id to be passed to API
                    BEGIN
                        SELECT ra_cust_trx_line_gl_dist_s.NEXTVAL
                          INTO ln_int_dist_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface Distribution id from sequence RA_CUST_TRX_LINE_GL_DIST_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Assiging values to API line table type variable
                    l_trx_lines_tbl (ln_line_count).trx_header_id   :=
                        ln_int_hdr_id;
                    l_trx_lines_tbl (ln_line_count).trx_line_id     :=
                        ln_int_line_id;
                    l_trx_lines_tbl (ln_line_count).line_number     :=
                        ln_line_count;

                    IF SIGN (ln_amount) = 1
                    THEN
                        l_trx_lines_tbl (ln_line_count).uom_code   := 'EA';
                        l_trx_lines_tbl (ln_line_count).quantity_invoiced   :=
                            1;
                        l_trx_lines_tbl (ln_line_count).unit_selling_price   :=
                            ln_amount;
                    ELSIF SIGN (ln_amount) = -1
                    THEN
                        l_trx_lines_tbl (ln_line_count).uom_code   := NULL;
                        l_trx_lines_tbl (ln_line_count).quantity_invoiced   :=
                            1;
                        l_trx_lines_tbl (ln_line_count).unit_selling_price   :=
                            ln_amount;
                    ELSE
                        l_trx_lines_tbl (ln_line_count).uom_code   := NULL;
                        l_trx_lines_tbl (ln_line_count).quantity_invoiced   :=
                            NULL;
                        l_trx_lines_tbl (ln_line_count).unit_selling_price   :=
                            NULL;
                    END IF;

                    l_trx_lines_tbl (ln_line_count).line_type       := 'LINE';
                    l_trx_lines_tbl (ln_line_count).taxable_flag    := 'N'; --Tax should not be calculated
                    l_trx_lines_tbl (ln_line_count).amount_includes_tax_flag   :=
                        'N';                    --Tax should not be calculated

                    --Interface line Context
                    l_trx_lines_tbl (ln_line_count).interface_line_context   :=
                        'CONCESSIONS';
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute1   :=
                        data_rec.sequence_id;
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute3   :=
                        lv_conc_store_rt.store_number;
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute4   :=
                        lv_conc_store_rt.brand;

                    IF gv_reprocess_flag = 'Y'
                    THEN
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute5   :=
                            'REPROCESSED';
                    ELSE
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute5   :=
                            'PROCESSED';
                    END IF;

                    -- l_trx_lines_tbl(ln_line_count).interface_line_attribute6    := TO_CHAR(SYSDATE, 'RRRR/MM/DD HH24:MI:SS'); --w.r.t Version 1.2
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute6   :=
                        TO_CHAR (SYSDATE, 'RRRRMMDDHH24MISS'); --w.r.t Version 1.2
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute7   :=
                        gn_conc_request_id;

                    --Distributions
                    l_trx_dist_tbl (ln_line_count).trx_dist_id      :=
                        ln_int_dist_id;
                    l_trx_dist_tbl (ln_line_count).trx_line_id      :=
                        ln_int_line_id;
                    l_trx_dist_tbl (ln_line_count).account_class    := 'REV';
                    l_trx_dist_tbl (ln_line_count).percent          := 100;
                END IF;                                    --gv_version end if
            END LOOP;                                      --data_cur end loop

            --Check the program version and take action accordingly
            IF (gv_version = 'FINAL' --AND ln_is_period_open_cnt > 0 --Commented for change 1.1
                                     AND (ln_is_period_open_cnt > 0 OR gv_use_curr_per_dt = 'Y') --Added for change 1.1
                                                                                                 AND ln_valid_status = 0)
            THEN
                --Added below IF Condition for change 1.1 --STARt
                --Call create AR transaction only if the header, line and distribution table type variables have data
                IF (l_trx_header_tbl.COUNT > 0 AND l_trx_lines_tbl.COUNT > 0 --Added for change 1.1
                                                                             AND l_trx_dist_tbl.COUNT > 0 --Added for change 1.1
                                                                                                         )
                THEN
                    --msg('Version is FINAL, so calling create_ar_trxns procedure - START', 'Y');
                    create_ar_trxns (
                        pn_org_id                => pn_org_id,
                        p_batch_source_rec       => l_batch_source_rec,
                        p_trx_header_tbl         => l_trx_header_tbl,
                        p_trx_lines_tbl          => l_trx_lines_tbl,
                        p_trx_dist_tbl           => l_trx_dist_tbl,
                        p_trx_salescredits_tbl   => l_trx_salescredits_tbl,
                        x_customer_trx_id        => ln_customer_trx_id,
                        x_ret_sts                => lv_ret_sts,
                        x_ret_msg                => lv_ret_msg);

                    IF    ln_customer_trx_id IS NULL
                       OR lv_ret_sts <> gv_ret_success
                    THEN
                        NULL;
                    ELSE
                        upd_ar_trx_det_to_stg (
                            pn_customer_trx_id   => ln_customer_trx_id,
                            x_ret_msg            => lv_return_msg,
                            x_ret_sts            => ln_return_sts);
                    END IF;
                ELSE
                    msg (
                        'Transaction header, line and distribution table type variables does not have any data. Please check.');
                END IF;                          --Table type variables end if
            END IF;
        END LOOP;                                          --main_cur end loop

        IF ln_valid_status <> 0
        THEN
            --lv_err_msg := lv_err_msg || 'Transaction Date Period :'||main_rec.trx_period_name||' is not OPEN.';
            msg (
                   'Setup Details are missing for store#'
                || pn_store_number
                || ' in XXD_AR_CONCESSION_STORES lookup. Please Check.');
        END IF;

        msg ('Consolidated = NO and Group by Period = YES procedure - END',
             'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || gv_package_name
                    || lv_proc_name
                    || ' . Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
    END cons_no_grp_by_yes;

    PROCEDURE cons_no_grp_by_no (pn_store_number IN NUMBER, pv_brand IN VARCHAR2, pn_org_id IN NUMBER)
    IS
        --Local Variables Declaration
        lv_proc_name                VARCHAR2 (30) := 'CONS_NO_GRP_BY_NO';
        lv_err_msg                  VARCHAR2 (2000) := NULL;
        ln_batch_source_id          NUMBER := NULL;
        ln_customer_id              NUMBER := NULL;
        ln_bill_to_site_use_id      NUMBER := NULL;
        ld_trx_date                 DATE := NULL;
        ln_int_hdr_id               NUMBER := NULL;
        ln_int_line_id              NUMBER := NULL;
        ln_int_dist_id              NUMBER := NULL;
        ln_line_count               NUMBER := NULL;
        ln_terms_id                 NUMBER := NULL;
        lv_currency_code            VARCHAR2 (10) := NULL;
        ln_customer_trx_id          NUMBER := NULL;
        lv_ret_sts                  VARCHAR2 (1) := NULL;
        lv_ret_msg                  VARCHAR2 (2000) := NULL;
        ln_return_sts               NUMBER := NULL;
        lv_return_msg               VARCHAR2 (2000) := NULL;
        ln_amount                   NUMBER := NULL;
        ln_is_period_open_cnt       NUMBER := NULL;
        ln_valid_status             NUMBER := NULL;
        lv_next_open_per_name       VARCHAR2 (15) := NULL; --Added for change 1.1
        ld_next_open_per_start_dt   DATE := NULL;       --Added for change 1.1
        ld_next_open_per_end_dt     DATE := NULL;       --Added for change 1.1
        lv_trx_period_err_msg       VARCHAR2 (2000) := NULL; --Added for change 1.1
        --Non-Scalar Variables
        lv_conc_store_rt            apps.xxd_ar_concession_stores_v%ROWTYPE;
        l_trx_header_tbl            ar_invoice_api_pub.trx_header_tbl_type;
        l_trx_lines_tbl             ar_invoice_api_pub.trx_line_tbl_type;
        l_trx_dist_tbl              ar_invoice_api_pub.trx_dist_tbl_type;
        l_trx_salescredits_tbl      ar_invoice_api_pub.trx_salescredits_tbl_type;
        l_batch_source_rec          ar_invoice_api_pub.batch_source_rec_type;

        --Cursor to get distinct store, brand, and period information for grouping the data and creating transactions(INV/CM)
        CURSOR main_cur IS
              SELECT --gp_cur.period_name current_period_name,  --Commented for change 1.1
                     gp.period_name trx_period_name, gp.period_year trx_period_year, gp.period_num trx_period_num,
                     gp.start_date trx_period_start_date, gp.end_date trx_period_end_date, stg.store_number,
                     stg.brand, MAX (stg.transaction_date) max_trx_date
                FROM xxdo.xxd_ar_concession_store_trx_t stg, apps.gl_periods gp
               --,apps.gl_periods gp_cur  --Commented for change 1.1
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N' --To pick records inserted with NULL or 'N' status
                     --Commented below condition by Kranthi Bollam on 30OCT2018
                     --AND stg.transaction_date >= DECODE(gd_as_of_date, TRUNC(SYSDATE), stg.transaction_date, gd_as_of_date) --If date is current date, pull all records, else pull trxns with trx_date greater than or equal to ld_as_of_date
                     AND TRUNC (stg.transaction_date) <= gd_as_of_date --Added below condition by Kranthi Bollam on 30OCT2018
                     AND stg.store_number = pn_store_number
                     AND stg.brand = pv_brand
                     --Added below case stmt on 10Jun2018 by Kranthi Bollam
                     --This gives us the records which are are NEW or not processed if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                     AND (   (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'N'
                                  END)
                          OR --This below case gives us the Error Records if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                             (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'E'
                                  END))
                     --Added trx date from and to on 10Jun2018 by Kranthi Bollam
                     --Added below the trx date from and to conditions to be considered only when reprocess flag parameter is YES
                     AND TRUNC (stg.transaction_date) BETWEEN (CASE
                                                                   WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                                                   THEN
                                                                       NVL (gd_trx_date_from, TRUNC (stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (stg.transaction_date)
                                                               END)
                                                          AND (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_to,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     AND TRUNC (stg.transaction_date) BETWEEN gp.start_date
                                                          AND gp.end_date
            --           AND gp_cur.period_set_name = 'DO_FY_CALENDAR'  --Commented for change 1.1
            --           AND TRUNC(SYSDATE) BETWEEN gp_cur.start_date and gp_cur.end_date  --Commented for change 1.1
            GROUP BY --gp_cur.period_name,  --Commented for change 1.1
                     gp.period_name, gp.period_year, gp.period_num,
                     gp.start_date, gp.end_date, stg.store_number,
                     stg.brand
            ORDER BY gp.period_year, gp.period_num;

        --Cursor to get data for store, brand, and period
        CURSOR data_cur (cv_period_name IN VARCHAR2)
        IS
              SELECT --gp_cur.period_name current_period_name,  --Commented for change 1.1
                     gp.period_name
                         trx_period_name,
                     gp.period_year
                         trx_period_year,
                     gp.period_num
                         trx_period_num,
                     gp.start_date
                         trx_period_start_date,
                     gp.end_date
                         trx_period_end_date,
                     apps.xxd_ar_concessions_trx_pkg.get_calculated_amt (
                         pv_program_mode      => gv_program_mode,
                         pn_store_number      => stg.store_number,
                         pv_brand             => stg.brand,
                         pn_org_id            => pn_org_id,
                         pn_retail_amount     => NVL (stg.retail_amount, 0),
                         pn_discount_amount   => NVL (stg.discount_amount, 0),
                         pn_paytotal_amount   => NVL (stg.paytotal_amount, 0),
                         pn_tax_amount        => NVL (stg.tax_amount, 0))
                         calc_amount,
                     stg.*
                FROM xxdo.xxd_ar_concession_store_trx_t stg, apps.gl_periods gp
               --,apps.gl_periods gp_cur  --Commented for change 1.1
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N' --To pick records inserted with NULL or 'N' status
                     --Commented below condition by Kranthi Bollam on 30OCT2018
                     --AND stg.transaction_date >= DECODE(gd_as_of_date, TRUNC(SYSDATE), stg.transaction_date, gd_as_of_date) --If date is current date, pull all records, else pull trxns with trx_date greater than or equal to ld_as_of_date
                     AND TRUNC (stg.transaction_date) <= gd_as_of_date --Added below condition by Kranthi Bollam on 30OCT2018
                     AND stg.store_number = pn_store_number
                     AND stg.brand = pv_brand
                     --This gives us the records which are are NEW or not processed if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                     AND (   (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'N'
                                  END)
                          OR --This below case gives us the Error Records if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                             (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'E'
                                  END))
                     --Added below the trx date from and to conditions to be considered only when reprocess flag parameter is YES
                     AND TRUNC (stg.transaction_date) BETWEEN (CASE
                                                                   WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                                                   THEN
                                                                       NVL (gd_trx_date_from, TRUNC (stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (stg.transaction_date)
                                                               END)
                                                          AND (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_to,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     AND TRUNC (stg.transaction_date) BETWEEN gp.start_date
                                                          AND gp.end_date
                     AND gp.period_name = cv_period_name
            --           AND gp_cur.period_set_name = 'DO_FY_CALENDAR'
            --           AND TRUNC(SYSDATE) BETWEEN gp_cur.start_date and gp_cur.end_date
            ORDER BY gp.period_year, gp.period_num, stg.rms_tran_seq_no;
    BEGIN
        msg ('Consolidated = NO and Group by Period = NO procedure - START',
             'Y');

        --Get the values from the stores setup for the store, brand and Operating unit combination
        --and assign it to lv_conc_store_rt variable
        BEGIN
            SELECT st.*
              INTO lv_conc_store_rt
              FROM apps.xxd_ar_concession_stores_v st
             WHERE     1 = 1
                   AND st.store_number = pn_store_number
                   AND st.brand = pv_brand
                   AND st.operating_unit_id = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'When Others Exception in '
                        || gv_package_name
                        || lv_proc_name
                        || 'while getting Config values for store = '
                        || pn_store_number
                        || ' and brand = '
                        || pv_brand,
                        1,
                        2000);
                msg (lv_err_msg);
                msg ('Error is:' || SQLERRM);
        END;

        --Assigning Values to Variables
        ln_batch_source_id   := lv_conc_store_rt.batch_source_id;
        lv_currency_code     := lv_conc_store_rt.currency_code;

        IF lv_conc_store_rt.cust_account_id IS NOT NULL
        THEN
            ln_customer_id   := lv_conc_store_rt.cust_account_id;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Customer Number is NULL for Store#:'
                    || pn_store_number
                    || ' and brand:'
                    || pv_brand
                    || ' and operating unit ID:'
                    || pn_org_id,
                    1,
                    2000);
            msg (lv_err_msg);
        END IF;

        IF lv_conc_store_rt.cust_bill_to_site_use_id IS NOT NULL
        THEN
            ln_bill_to_site_use_id   :=
                lv_conc_store_rt.cust_bill_to_site_use_id;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Customer Bill to Site is NULL for Store#:'
                    || pn_store_number
                    || ' and brand:'
                    || pv_brand
                    || ' and operating unit ID:'
                    || pn_org_id,
                    1,
                    2000);
            msg (lv_err_msg);
        END IF;

        IF ln_bill_to_site_use_id IS NOT NULL OR ln_customer_id IS NOT NULL
        THEN
            ln_terms_id   :=
                get_ar_terms (pn_org_id        => pn_org_id,
                              pn_site_use_id   => ln_bill_to_site_use_id,
                              pn_customer_id   => ln_customer_id);
        END IF;

        --Process main cursor
        FOR main_rec IN main_cur
        LOOP
            ln_line_count        := 0;
            lv_ret_sts           := NULL;
            lv_ret_msg           := NULL;
            ln_customer_trx_id   := NULL;

            --Process data cursor
            FOR data_rec
                IN data_cur (cv_period_name => main_rec.trx_period_name)
            LOOP
                update_calc_amt_stg (pn_sequence_id   => data_rec.sequence_id,
                                     pn_amount        => data_rec.calc_amount);

                --msg('Calling validate store setup data procedure - START', 'Y');
                ln_valid_status         := 0;
                validate_store_setup_data (
                    pn_sequence_id    => data_rec.sequence_id,
                    pn_store_number   => pn_store_number,
                    pv_brand          => pv_brand,
                    pn_org_id         => pn_org_id,
                    x_return_status   => ln_valid_status);
                --msg('Calling validate store setup data procedure - END', 'Y');

                --Check if period is open or not
                ln_is_period_open_cnt   := 0;
                ln_is_period_open_cnt   :=
                    get_period_status (
                        pn_org_id            => lv_conc_store_rt.operating_unit_id,
                        pv_trx_period_name   => data_rec.trx_period_name);

                IF ln_is_period_open_cnt <= 0
                THEN
                    --msg('Transaction Date Period :'||data_rec.trx_period_name||' is not OPEN.');
                    --Added below if condition for change 1.1 --START
                    IF gv_use_curr_per_dt = 'Y'
                    THEN
                        get_next_open_period (
                            pn_org_id              => lv_conc_store_rt.operating_unit_id,
                            pd_trx_per_end_dt      =>
                                main_rec.trx_period_end_date,
                            x_next_open_per_name   => lv_next_open_per_name,
                            x_next_open_per_start_dt   =>
                                ld_next_open_per_start_dt,
                            x_next_open_per_end_dt   =>
                                ld_next_open_per_end_dt);
                        msg (
                               ' Transaction Date Period :'
                            || main_rec.trx_period_name
                            || ' is not OPEN, and USE_CURRENT_PERIOD_DATE is YES, creating transactions on Start date of next OPEN Period : '
                            || lv_next_open_per_name);
                    ELSE
                        --msg(' Transaction Date Period :'||main_rec.trx_period_name||' is not OPEN, and also USE_CURRENT_PERIOD_DATE is NO, so not creating transactions');
                        lv_trx_period_err_msg   :=
                               ' Transaction Date Period :'
                            || main_rec.trx_period_name
                            || ' is not OPEN, and also USE_CURRENT_PERIOD_DATE is NO, so not creating transactions';
                        msg (lv_trx_period_err_msg);
                        upd_errors_to_stg (
                            pn_sequence_id     => data_rec.sequence_id,
                            pv_error_message   => lv_trx_period_err_msg);
                    END IF;
                --Added above if condition for change 1.1 --END
                END IF;

                ln_amount               := data_rec.calc_amount;

                --Check the program version and take action accordingly
                IF (gv_version = 'FINAL' --AND ln_is_period_open_cnt > 0 --Commented for change 1.1
                                         AND (ln_is_period_open_cnt > 0 OR gv_use_curr_per_dt = 'Y') --Added for change 1.1
                                                                                                     AND ln_valid_status = 0)
                THEN
                    ln_line_count                                   := 0;
                    ln_line_count                                   := ln_line_count + 1;
                    --Reset the variables as this procedure creates individual transaction for each line
                    lv_ret_sts                                      := NULL;
                    lv_ret_msg                                      := NULL;
                    ln_customer_trx_id                              := NULL;

                    --Getting the interface header id to be passed to API
                    BEGIN
                        SELECT ra_customer_trx_s.NEXTVAL
                          INTO ln_int_hdr_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface header id from sequence RA_CUSTOMER_TRX_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Commented the above code to determine trx date for change 1.1 --START
                    /*
                    --Determining transaction date
                    --If current period and trx period are different then trx date is first day of the current trx period
                    --else trx date is the trx date
                    IF data_rec.current_period_name <> data_rec.trx_period_name
                    THEN
                        --ld_trx_date := data_rec.trx_period_end_date; --Commented for change 1.1
                    ELSE
                        ld_trx_date := data_rec.transaction_date;
                    END IF;
                    */
                    --Commented the above code to determine trx date for change 1.1 --END

                    --Added the below code to determine trx date for change 1.1 --START
                    --If the trx period is open, then trx date will be trx date
                    IF ln_is_period_open_cnt > 0
                    THEN
                        ld_trx_date   := data_rec.transaction_date;
                    --If trx period is not open and use current period is YES, then get the next open period start date and use it as trx date
                    ELSIF     ln_is_period_open_cnt <= 0
                          AND gv_use_curr_per_dt = 'Y'
                    THEN
                        ld_trx_date   := ld_next_open_per_start_dt;
                    END IF;

                    --Added the above code to determine trx date for change 1.1 --END

                    --Assigning values to API Batch Source Record table type variable
                    l_batch_source_rec.batch_source_id              :=
                        ln_batch_source_id;
                    --Assigning values to API Header table type variable
                    l_trx_header_tbl (1).trx_header_id              := ln_int_hdr_id;
                    l_trx_header_tbl (1).bill_to_site_use_id        :=
                        ln_bill_to_site_use_id;
                    l_trx_header_tbl (1).trx_date                   := ld_trx_date;
                    l_trx_header_tbl (1).bill_to_customer_id        :=
                        ln_customer_id;
                    l_trx_header_tbl (1).attribute5                 :=
                        lv_conc_store_rt.brand;    --Mandatory at header level
                    l_trx_header_tbl (1).trx_currency               :=
                        lv_currency_code;

                    IF SIGN (ln_amount) = 1
                    THEN
                        l_trx_header_tbl (1).term_id   := ln_terms_id;

                        IF gv_program_mode = gc_sales_credits
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.sales_cr_inv_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2     := lv_conc_store_rt.sales_cr_inv_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.sales_cr_inv_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        ELSIF gv_program_mode = gc_ancillary1
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.ancillary1_inv_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary1_inv_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.ancillary1_inv_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        ELSIF gv_program_mode = gc_ancillary2
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.ancillary2_inv_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary2_inv_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.ancillary2_inv_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        END IF;
                    ELSIF SIGN (ln_amount) = -1
                    THEN
                        l_trx_header_tbl (1).term_id   := NULL;

                        IF gv_program_mode = gc_sales_credits
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.sales_cr_cm_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2     := lv_conc_store_rt.sales_cr_cm_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.sales_cr_cm_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        ELSIF gv_program_mode = gc_ancillary1
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.ancillary1_cm_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary1_cm_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.ancillary1_cm_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        ELSIF gv_program_mode = gc_ancillary2
                        THEN
                            l_trx_header_tbl (1).cust_trx_type_id   :=
                                lv_conc_store_rt.ancillary2_cm_trx_type_id;
                            --l_trx_lines_tbl(ln_line_count).interface_line_attribute2    := lv_conc_store_rt.ancillary2_cm_trx_type; --Commented for change 1.1
                            l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                                   lv_conc_store_rt.ancillary2_cm_trx_type
                                || '-'
                                || gv_program_mode;     --Added for change 1.1
                        END IF;
                    ELSE
                        l_trx_header_tbl (1).cust_trx_type_id   := NULL;
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute2   :=
                            NULL;
                    END IF;

                    ln_amount                                       :=
                        data_rec.calc_amount;

                    --Getting the interface line id to be passed to API
                    BEGIN
                        SELECT ra_customer_trx_lines_s.NEXTVAL
                          INTO ln_int_line_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface Line id from sequence RA_CUSTOMER_TRX_LINES_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Getting the interface Distribution id to be passed to API
                    BEGIN
                        SELECT ra_cust_trx_line_gl_dist_s.NEXTVAL
                          INTO ln_int_dist_id
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   :=
                                SUBSTR (
                                       'Error while getting interface Distribution id from sequence RA_CUST_TRX_LINE_GL_DIST_S for Store# = '
                                    || pn_store_number
                                    || ' and Brand = '
                                    || pv_brand
                                    || '. Error is : '
                                    || SQLERRM,
                                    1,
                                    2000);
                            msg (lv_err_msg);
                    END;

                    --Assiging values to API line table type variable
                    l_trx_lines_tbl (ln_line_count).trx_header_id   :=
                        ln_int_hdr_id;
                    l_trx_lines_tbl (ln_line_count).trx_line_id     :=
                        ln_int_line_id;
                    l_trx_lines_tbl (ln_line_count).line_number     :=
                        ln_line_count;

                    IF gv_program_mode = gc_sales_credits
                    THEN
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.sales_cr_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.sales_cr_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.sales_cr_memo_gl_id_rev;
                    ELSIF gv_program_mode = gc_ancillary1
                    THEN
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.ancillary1_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.ancillary1_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.ancillary1_memo_gl_id_rev;
                    ELSIF gv_program_mode = gc_ancillary2
                    THEN
                        l_trx_lines_tbl (ln_line_count).memo_line_id   :=
                            lv_conc_store_rt.ancillary2_memo_line_id;
                        l_trx_lines_tbl (ln_line_count).description   :=
                            lv_conc_store_rt.ancillary2_memo_line_name;
                        l_trx_dist_tbl (ln_line_count).code_combination_id   :=
                            lv_conc_store_rt.ancillary2_memo_gl_id_rev;
                    END IF;

                    IF SIGN (ln_amount) = 1
                    THEN
                        l_trx_lines_tbl (ln_line_count).uom_code   := 'EA';
                        l_trx_lines_tbl (ln_line_count).quantity_invoiced   :=
                            1;
                        l_trx_lines_tbl (ln_line_count).unit_selling_price   :=
                            ln_amount;
                    ELSIF SIGN (ln_amount) = -1
                    THEN
                        l_trx_lines_tbl (ln_line_count).uom_code   := NULL;
                        l_trx_lines_tbl (ln_line_count).quantity_invoiced   :=
                            1;
                        l_trx_lines_tbl (ln_line_count).unit_selling_price   :=
                            ln_amount;
                    ELSE
                        l_trx_lines_tbl (ln_line_count).uom_code   := NULL;
                        l_trx_lines_tbl (ln_line_count).quantity_invoiced   :=
                            NULL;
                        l_trx_lines_tbl (ln_line_count).unit_selling_price   :=
                            NULL;
                    END IF;

                    l_trx_lines_tbl (ln_line_count).line_type       := 'LINE';
                    l_trx_lines_tbl (ln_line_count).taxable_flag    := 'N'; --Tax should not be calculated
                    l_trx_lines_tbl (ln_line_count).amount_includes_tax_flag   :=
                        'N';                    --Tax should not be calculated

                    --Interface line Context
                    l_trx_lines_tbl (ln_line_count).interface_line_context   :=
                        'CONCESSIONS';
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute1   :=
                        data_rec.sequence_id;
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute3   :=
                        lv_conc_store_rt.store_number;
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute4   :=
                        lv_conc_store_rt.brand;

                    IF gv_reprocess_flag = 'Y'
                    THEN
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute5   :=
                            'REPROCESSED';
                    ELSE
                        l_trx_lines_tbl (ln_line_count).interface_line_attribute5   :=
                            'PROCESSED';
                    END IF;

                    --    l_trx_lines_tbl(ln_line_count).interface_line_attribute6    := TO_CHAR(SYSDATE, 'RRRR/MM/DD HH24:MI:SS'); --W.r.t Version 1.2
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute6   :=
                        TO_CHAR (SYSDATE, 'RRRRMMDDHH24MISS'); --W.r.t Version 1.2
                    l_trx_lines_tbl (ln_line_count).interface_line_attribute7   :=
                        gn_conc_request_id;

                    --Distributions
                    l_trx_dist_tbl (ln_line_count).trx_dist_id      :=
                        ln_int_dist_id;
                    l_trx_dist_tbl (ln_line_count).trx_line_id      :=
                        ln_int_line_id;
                    l_trx_dist_tbl (ln_line_count).account_class    := 'REV';
                    l_trx_dist_tbl (ln_line_count).percent          := 100;

                    --Added below IF Condition for change 1.1 --STARt
                    --Call create AR transaction only if the header, line and distribution table type variables have data
                    IF (l_trx_header_tbl.COUNT > 0 AND l_trx_lines_tbl.COUNT > 0 --Added for change 1.1
                                                                                 AND l_trx_dist_tbl.COUNT > 0 --Added for change 1.1
                                                                                                             )
                    THEN
                        --Call AR Transactions creation procedure
                        create_ar_trxns (
                            pn_org_id                => pn_org_id,
                            p_batch_source_rec       => l_batch_source_rec,
                            p_trx_header_tbl         => l_trx_header_tbl,
                            p_trx_lines_tbl          => l_trx_lines_tbl,
                            p_trx_dist_tbl           => l_trx_dist_tbl,
                            p_trx_salescredits_tbl   => l_trx_salescredits_tbl,
                            x_customer_trx_id        => ln_customer_trx_id,
                            x_ret_sts                => lv_ret_sts,
                            x_ret_msg                => lv_ret_msg);

                        IF    ln_customer_trx_id IS NULL
                           OR lv_ret_sts <> gv_ret_success
                        THEN
                            NULL;
                        ELSE
                            upd_ar_trx_det_to_stg (
                                pn_customer_trx_id   => ln_customer_trx_id,
                                x_ret_msg            => lv_return_msg,
                                x_ret_sts            => ln_return_sts);
                        END IF;
                    ELSE
                        --msg('Transaction header, line and distribution table type variables does not have any data. Please check.');
                        lv_err_msg   :=
                            'Transaction header, line and distribution table type variables does not have any data. Please Check.';
                        upd_errors_to_stg (
                            pn_sequence_id     => data_rec.sequence_id,
                            pv_error_message   => lv_err_msg);
                    END IF;                      --Table type variables end if
                END IF;                                    --gv_version end if
            END LOOP;                                      --data_cur end loop
        END LOOP;                                          --main_cur end loop

        IF ln_valid_status <> 0
        THEN
            --lv_err_msg := lv_err_msg || 'Transaction Date Period :'||main_rec.trx_period_name||' is not OPEN.';
            msg (
                   'Setup Details are missing for store#'
                || pn_store_number
                || ' in XXD_AR_CONCESSION_STORES lookup. Please Check.');
        END IF;

        msg ('Consolidated = NO and Group by Period = NO procedure - END',
             'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR (
                       'Exception in '
                    || gv_package_name
                    || lv_proc_name
                    || ' . Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);
    END cons_no_grp_by_no;

    PROCEDURE process_concession_trxns
    IS
        --Local Variables Declaration
        lv_proc_name         VARCHAR2 (30) := 'PROCESS_CONCESSION_TRXNS';
        lv_err_msg           VARCHAR2 (2000) := NULL;
        lv_consolidated      VARCHAR2 (1) := NULL;
        lv_group_by_period   VARCHAR2 (1) := NULL;

        --Cursors Declaration
        --To get distinct store numbers which are yet to processed
        CURSOR stores_cur IS
              SELECT stg.store_number, stg.brand
                FROM xxdo.xxd_ar_concession_store_trx_t stg
               WHERE     1 = 1
                     AND NVL (stg.status, 'N') = 'N' --To pick records inserted with NULL or 'N' status
                     --Commented below condition by Kranthi Bollam on 30OCT2018
                     --AND stg.transaction_date >= DECODE(gd_as_of_date, TRUNC(SYSDATE), stg.transaction_date, gd_as_of_date) --If date is current date, pull all records, else pull trxns with trx_date greater than or equal to ld_as_of_date
                     AND TRUNC (stg.transaction_date) <= gd_as_of_date --Added below condition by Kranthi Bollam on 30OCT2018
                     AND stg.store_number =
                         NVL (gn_store_number, stg.store_number)
                     AND stg.brand = NVL (gv_brand, stg.brand)
                     --Added below case stmt on 10Jun2018 by Kranthi Bollam
                     --This gives us the records which are NEW or not processed if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                     AND (   (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'N'
                                  END)
                          OR --This below case gives us the Error Records if reprocess flag parameter is NO, else gives the records to be reprocessed(Reprocess_flag='R')
                             (CASE
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_sales_credits
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (sales_cr_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary1
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary1_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') <> 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'N'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                                  WHEN     gv_program_mode = gc_ancillary2
                                       AND NVL (gv_reprocess_flag, 'N') = 'Y'
                                       AND NVL (reprocess_flag, 'N') = 'R'
                                  THEN
                                      NVL (ancillary2_mode_prc_flag, 'N')
                              END) IN
                                 (CASE
                                      WHEN NVL (gv_reprocess_flag, 'N') = 'Y'
                                      THEN
                                          'P'
                                      WHEN NVL (gv_reprocess_flag, 'N') <> 'Y'
                                      THEN
                                          'E'
                                  END))
                     --Added below the trx date from and to conditions to be considered only when reprocess flag parameter is YES
                     AND TRUNC (stg.transaction_date) BETWEEN (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_from,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
                                                          AND (CASE
                                                                   WHEN NVL (
                                                                            gv_reprocess_flag,
                                                                            'N') =
                                                                        'Y'
                                                                   THEN
                                                                       NVL (
                                                                           gd_trx_date_to,
                                                                           TRUNC (
                                                                               stg.transaction_date))
                                                                   ELSE
                                                                       TRUNC (
                                                                           stg.transaction_date)
                                                               END)
            GROUP BY stg.store_number, stg.brand
            ORDER BY stg.store_number, stg.brand;

        --Get the values configured in XXD_AR_CONCESSION_STORES value set for the store, brand and operating unit
        CURSOR config_cur (cn_store_number IN NUMBER, cv_brand IN VARCHAR2)
        IS
            SELECT xacs.*
              FROM apps.xxd_ar_concession_stores_v xacs
             WHERE     1 = 1
                   AND xacs.store_number = cn_store_number
                   AND xacs.brand = cv_brand;
    BEGIN
        msg ('In PROCESS_CONCESSION_TRXNS procedure - START', 'Y');

        FOR stores_rec IN stores_cur
        LOOP
            FOR config_rec
                IN config_cur (cn_store_number   => stores_rec.store_number,
                               cv_brand          => stores_rec.brand)
            LOOP
                msg (
                    '----------------------------------------------------------------------------------------------------------');
                msg (
                       'Running for Store: '
                    || stores_rec.store_number
                    || ' , Brand: '
                    || stores_rec.brand
                    || ' and Operating unit ID: '
                    || config_rec.operating_unit_id);
                msg (
                    '----------------------------------------------------------------------------------------------------------');

                IF gv_program_mode = gc_sales_credits
                THEN
                    lv_consolidated   :=
                        NVL (config_rec.sales_cr_consolidated, 'N');
                    lv_group_by_period   :=
                        NVL (config_rec.sales_cr_grp_by_period, 'N');
                ELSIF gv_program_mode = gc_ancillary1
                THEN
                    lv_consolidated   :=
                        NVL (config_rec.ancillary1_consolidated, 'N');
                    lv_group_by_period   :=
                        NVL (config_rec.ancillary1_grp_by_period, 'N');
                ELSIF gv_program_mode = gc_ancillary2
                THEN
                    lv_consolidated   :=
                        NVL (config_rec.ancillary2_consolidated, 'N');
                    lv_group_by_period   :=
                        NVL (config_rec.ancillary2_grp_by_period, 'N');
                END IF;

                IF lv_consolidated = 'Y'
                THEN
                    IF lv_group_by_period = 'Y'
                    THEN
                        cons_yes_grp_by_yes (
                            pn_store_number   => stores_rec.store_number,
                            pv_brand          => stores_rec.brand,
                            pn_org_id         => config_rec.operating_unit_id);
                    ELSE
                        cons_yes_grp_by_no (
                            pn_store_number   => stores_rec.store_number,
                            pv_brand          => stores_rec.brand,
                            pn_org_id         => config_rec.operating_unit_id);
                    END IF;
                ELSE
                    IF lv_group_by_period = 'Y'
                    THEN
                        cons_no_grp_by_yes (
                            pn_store_number   => stores_rec.store_number,
                            pv_brand          => stores_rec.brand,
                            pn_org_id         => config_rec.operating_unit_id);
                    ELSE
                        cons_no_grp_by_no (
                            pn_store_number   => stores_rec.store_number,
                            pv_brand          => stores_rec.brand,
                            pn_org_id         => config_rec.operating_unit_id);
                    END IF;
                END IF;
            END LOOP;                                         --config_cur end
        END LOOP;                                       --store_cur cursor end

        msg (
            '----------------------------------------------------------------------------------------------------------');
        msg ('In PROCESS_CONCESSION_TRXNS procedure - END', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR (
                       'When others exception in '
                    || gv_package_name
                    || lv_proc_name
                    || '. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            msg (lv_err_msg);            --Print the error message to log file
    END process_concession_trxns;

    PROCEDURE proc_process_stg_data (x_ret_msg   OUT VARCHAR2,
                                     x_ret_sts   OUT NUMBER)
    IS
        --Local Variables Declaration
        lv_proc_name   VARCHAR2 (30) := 'PROC_PROCESS_STG_DATA';
        lv_err_msg     VARCHAR2 (2000) := NULL;
        lv_ret_msg     VARCHAR2 (2000) := NULL;
        ln_ret_sts     NUMBER := NULL;
    BEGIN
        msg ('In Processing staging table data - START', 'Y');
        process_concession_trxns;
        msg ('In Processing staging table data - END', 'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR ('When others exception. Error is : ' || SQLERRM,
                        1,
                        2000);
            msg (lv_err_msg);            --Print the error message to log file
            x_ret_msg   := lv_err_msg;
            x_ret_sts   := gn_error;
    END proc_process_stg_data;

    --Main Procedure called by the concurrent program
    --Parameters
    --pv_errbuf         OUT     Program error message returned to the concurrent program
    --pn_retcode        OUT     Program return code
    PROCEDURE proc_ar_trx_main (
        pv_errbuf               OUT VARCHAR2,
        pn_retcode              OUT NUMBER,
        pv_mode              IN     VARCHAR2,
        pv_version           IN     VARCHAR2,
        pv_as_of_date        IN     VARCHAR2,
        pv_store_number      IN     VARCHAR2,
        pv_brand             IN     VARCHAR2,
        pv_trx_date_from     IN     VARCHAR2,
        pv_trx_date_to       IN     VARCHAR2,
        pv_reprocess_flag    IN     VARCHAR2 DEFAULT 'N',
        pv_use_curr_per_dt   IN     VARCHAR2 DEFAULT 'N' --Added for change 1.1
                                                        )
    IS
        --Local Variables Declaration
        lv_proc_name       VARCHAR2 (30) := 'PROC_AR_TRX_MAIN';
        lv_err_msg         VARCHAR2 (2000) := NULL;
        lv_ret_msg         VARCHAR2 (2000) := NULL;
        ln_ret_sts         NUMBER := NULL;
        ld_as_of_date      DATE := NULL;
        ln_store_number    NUMBER := NULL;
        ld_trx_date_from   DATE := NULL;
        ld_trx_date_to     DATE := NULL;
    BEGIN
        msg (
            'AR Transactions creation for Concession stores - Deckers Started',
            'Y');
        msg ('Printing Parameters');
        msg ('------------------------------------------------');
        msg ('Program Mode            :   ' || pv_mode);
        msg ('Version                 :   ' || pv_version);
        msg ('As of Date              :   ' || pv_as_of_date);
        msg ('Store Number            :   ' || pv_store_number);
        msg ('Brand                   :   ' || pv_brand);
        msg ('Trx Date From           :   ' || pv_trx_date_from);
        msg ('Trx Date To             :   ' || pv_trx_date_to);
        msg ('Reprocess Flag          :   ' || pv_reprocess_flag);
        msg ('Use Current Period Date :   ' || pv_use_curr_per_dt); --Added for change 1.1
        msg ('------------------------------------------------');

        --Assigning Parameters to global variables
        gv_program_mode      := pv_mode;
        gv_version           := UPPER (pv_version);
        gv_as_of_date        := pv_as_of_date;
        gv_store_number      := pv_store_number;
        gv_brand             := pv_brand;
        gv_reprocess_flag    := pv_reprocess_flag;
        gv_use_curr_per_dt   := pv_use_curr_per_dt;     --Added for change 1.1

        IF pv_as_of_date IS NOT NULL
        THEN
            gd_as_of_date   :=
                TRUNC (TO_DATE (pv_as_of_date, 'RRRR/MM/DD HH24:MI:SS'));
        ELSE
            gd_as_of_date   := TRUNC (SYSDATE);
        END IF;

        IF pv_store_number IS NOT NULL
        THEN
            gn_store_number   := TO_NUMBER (pv_store_number);
        ELSE
            gn_store_number   := NULL;
        END IF;

        IF pv_trx_date_from IS NOT NULL
        THEN
            gd_trx_date_from   :=
                TRUNC (TO_DATE (pv_trx_date_from, 'RRRR/MM/DD HH24:MI:SS'));
        END IF;

        IF pv_trx_date_to IS NOT NULL
        THEN
            gd_trx_date_to   :=
                TRUNC (TO_DATE (pv_trx_date_to, 'RRRR/MM/DD HH24:MI:SS'));
        END IF;

        --Setting variable values
        lv_ret_msg           := NULL;
        ln_ret_sts           := NULL;
        msg (
            'Calling procedure PROC_PROCESS_STG_DATA to process data in staging table - START',
            'Y');
        proc_process_stg_data (x_ret_msg   => lv_ret_msg,
                               x_ret_sts   => ln_ret_sts);
        msg (
            'Calling procedure PROC_PROCESS_STG_DATA to process data in staging table - END',
            'Y');

        IF ln_ret_sts <> gn_success
        THEN
            msg ('PROC_PROCESS_STG_DATA Return Message:' || lv_ret_msg);
            msg ('PROC_PROCESS_STG_DATA Return Status:' || ln_ret_sts);
            pn_retcode   := ln_ret_sts;
            pv_errbuf    := lv_ret_msg;
        END IF;

        --If the program is run in draft mode then display the calculated amounts in Output of the program
        IF gv_version = 'DRAFT'
        THEN
            msg (
                'Printing the calculations to OUTPUT file as the version is DRAFT - START',
                'Y');
            print_trxns (pn_request_id => gn_conc_request_id);
            msg (
                'Printing the calculations to OUTPUT file as the version is DRAFT - END',
                'Y');
        END IF;

        --This below code is for debugging in test environments
        /*
        BEGIN
            EXECUTE IMMEDIATE 'drop table xxdo.xxd_ar_trx_errors_gt';
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
        BEGIN
            EXECUTE IMMEDIATE 'create table xxdo.xxd_ar_trx_errors_gt as select * from ar_trx_errors_gt';
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
        */

        msg (
            'AR Transactions creation for Concession stores - Deckers Completed',
            'Y');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   :=
                SUBSTR ('When others exception. Error is : ' || SQLERRM,
                        1,
                        2000);
            msg (lv_err_msg);            --Print the error message to log file
            pv_errbuf    := lv_err_msg;
            pn_retcode   := gn_error;
    END proc_ar_trx_main;
END xxd_ar_concessions_trx_pkg;
/
