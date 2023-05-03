--
-- XXD_AR_WO_ADJUSTMENTS  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_WO_ADJUSTMENTS"
AS
    --  #########################################################################################
    --  Author(s)       : Tejaswi Gangumala
    --  System          : Oracle Applications
    --  Subsystem       :
    --  Change          : ecom records with "WO", needs adjustments in EBS
    --  Schema          : APPS
    --  Purpose         : This package is used to make adjutments to transactions
    --  Dependency      : N
    --  Change History
    --  --------------
    --  Date            Name                    Ver     Change                  Description
    --  ----------      --------------          -----   --------------------    ---------------------
    --  25-May-2019     Tejaswi Gangumalla       1.0     NA                      Initial Version
    --
    --  #########################################################################################
    PROCEDURE msg (pv_message VARCHAR2)
    IS
        lv_error_msg   VARCHAR2 (2000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, pv_message);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            lv_error_msg   := SQLERRM;
            msg ('Error In MSG procedure ' || lv_error_msg);
    END msg;

    PROCEDURE get_default_activity (pn_org_id IN NUMBER, pv_brand IN VARCHAR2, pv_activity_name OUT VARCHAR2
                                    , pv_error_flag OUT VARCHAR2)
    AS
        lv_error_msg          VARCHAR2 (2000);
        lv_default_act_name   VARCHAR2 (2000);
    BEGIN
        BEGIN
            SELECT ffv.attribute2
              INTO lv_default_act_name
              FROM fnd_flex_value_sets fvs, fnd_flex_values ffv
             WHERE     fvs.flex_value_set_name =
                       'XXD_AR_DEF_RECV_ACTIVITY_VS'
                   AND fvs.flex_value_set_id = ffv.flex_value_set_id
                   AND ffv.value_category = 'XXD_AR_DEF_RECV_ACTIVITY_VS'
                   AND ffv.attribute1 = pn_org_id
                   AND ffv.enabled_flag = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_msg    := SQLERRM;
                msg (
                    'Error While Fetching Default Activity: ' || lv_error_msg);
                pv_error_flag   := 'Y';
        END;

        BEGIN
            SELECT art.name
              INTO pv_activity_name
              FROM ar_receivables_trx_all art
             WHERE     UPPER (name) =
                       UPPER (lv_default_act_name || '-' || pv_brand)
                   AND SYSDATE BETWEEN NVL (art.start_date_active, SYSDATE)
                                   AND NVL (art.end_date_active, SYSDATE);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_msg    := SQLERRM;
                msg (
                       'Error While Fetching Default Activity For Brand: '
                    || lv_error_msg);
                pv_error_flag   := 'Y';
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg    := SQLERRM;
            msg ('Error While Fetching Default Activity: ' || lv_error_msg);
            pv_error_flag   := 'Y';
    END get_default_activity;

    PROCEDURE get_receipt_activity_name (pn_org_id IN NUMBER, pn_cust_trx_id IN NUMBER, pv_trx_type IN VARCHAR2
                                         , pv_brand IN VARCHAR2, pv_activity_name OUT VARCHAR2, pv_error_flag OUT VARCHAR2)
    AS
        lv_currency_code       VARCHAR2 (50);
        ln_recipt_class_id     NUMBER;
        lv_website_id          VARCHAR2 (5);
        ln_receipt_method_id   NUMBER;
        lv_activity_id         NUMBER;
        lv_default_flag        VARCHAR2 (2);
        lv_error_msg           VARCHAR2 (2000);
    BEGIN
        IF pv_trx_type = 'INV'
        THEN
            BEGIN
                SELECT DISTINCT art1.NAME
                  INTO pv_activity_name
                  FROM ar_receivable_applications_all ara, ar_cash_receipts_all acr, ar_receipt_methods arm,
                       ar_receivables_trx_all art, ar_receivables_trx_all art1
                 WHERE     applied_customer_trx_id = TRIM (pn_cust_trx_id)
                       AND acr.cash_receipt_id = ara.cash_receipt_id
                       AND ara.status = 'APP'
                       AND acr.receipt_method_id = arm.receipt_method_id
                       AND art.receivables_trx_id = arm.attribute5
                       AND SYSDATE BETWEEN NVL (art.start_date_active,
                                                SYSDATE)
                                       AND NVL (art.end_date_active, SYSDATE)
                       AND UPPER (art1.name) =
                           UPPER (art.name || '-' || pv_brand)
                       AND SYSDATE BETWEEN NVL (art1.start_date_active,
                                                SYSDATE)
                                       AND NVL (art1.end_date_active,
                                                SYSDATE);
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    lv_default_flag   := 'Y';
                WHEN OTHERS
                THEN
                    lv_default_flag    := 'Y';
                    lv_error_msg       := SQLERRM;
                    msg (
                           'Error While Getting Receipt Activity For Partial Invoice: '
                        || lv_error_msg);
                    pv_activity_name   := NULL;
            END;
        END IF;

        IF pv_trx_type = 'CM'
        THEN
            BEGIN
                SELECT DISTINCT art1.name
                  INTO pv_activity_name
                  FROM ar_adjustments_all adj, ar_receivables_trx_all art, ar_receivables_trx_all art1
                 WHERE     adj.customer_trx_id = TRIM (pn_cust_trx_id)
                       AND adj.receivables_trx_id = art.receivables_trx_id
                       AND SYSDATE BETWEEN NVL (art.start_date_active,
                                                SYSDATE)
                                       AND NVL (art.end_date_active, SYSDATE)
                       AND UPPER (art1.name) =
                           UPPER (art.attribute5 || '-' || pv_brand)
                       AND SYSDATE BETWEEN NVL (art1.start_date_active,
                                                SYSDATE)
                                       AND NVL (art1.end_date_active,
                                                SYSDATE);
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    lv_default_flag   := 'Y';
                WHEN OTHERS
                THEN
                    lv_default_flag    := 'Y';
                    lv_error_msg       := SQLERRM;
                    msg (
                           'Error While Getting Adjustment Activity For Credit Memo: '
                        || lv_error_msg);
                    pv_activity_name   := NULL;
            END;
        END IF;

        IF pv_activity_name IS NULL
        THEN
            lv_default_flag   := 'Y';
        END IF;

        --Query to get default activity_name
        IF NVL (lv_default_flag, 'N') = 'Y'
        THEN
            get_default_activity (pn_org_id, pv_brand, pv_activity_name,
                                  pv_error_flag);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_msg    := SQLERRM;
            msg ('Error While Getting Adjsutment Activity ' || lv_error_msg);
            pv_error_flag   := 'Y';
    END get_receipt_activity_name;

    PROCEDURE create_adjustment (pn_cust_trx_id    IN     NUMBER,
                                 pv_adj_activity   IN     VARCHAR2,
                                 pv_adj_type       IN     VARCHAR2,
                                 pn_adj_amount     IN     VARCHAR2,
                                 pn_org_id         IN     NUMBER,
                                 pn_adj_id            OUT NUMBER,
                                 pn_adj_num           OUT NUMBER,
                                 pv_err_msg           OUT VARCHAR2)
    AS
        ln_set_org_id         NUMBER;
        l_org_return_status   VARCHAR2 (1);
        ln_org_id             NUMBER;
    BEGIN
        mo_global.set_policy_context ('S', pn_org_id);
        ln_org_id   := pn_org_id;
        ar_mo_cache_utils.set_org_context_in_api (
            p_org_id          => ln_org_id,
            p_return_status   => l_org_return_status);
        do_ar_utils.create_adjustment_trans (
            p_customer_trx_id   => TRIM (pn_cust_trx_id),
            p_activity_name     => pv_adj_activity,
            p_type              => pv_adj_type,
            p_amount            => pn_adj_amount,
            p_reason_code       => 'WRITE OFF',
            p_gl_date           => SYSDATE,
            p_adj_date          => SYSDATE,
            p_comments          => 'Adjustment',
            p_auto_commit       => 'N',
            x_adj_id            => pn_adj_id,
            x_adj_number        => pn_adj_num,
            x_error_msg         => pv_err_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_err_msg   := SQLERRM;
            msg ('Error While Calling Adjustment Procedure ' || pv_err_msg);
    END create_adjustment;

    PROCEDURE main (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER, pn_org_id IN NUMBER, pv_trx_class IN VARCHAR2, pv_trx_type IN VARCHAR2, pv_cust_trx_id IN NUMBER
                    , pv_reprocess IN VARCHAR2)
    AS
        CURSOR wo_records_cur (cv_status IN VARCHAR2)
        IS
            SELECT xxd.*, rtl.status_trx, rac.TYPE,
                   rtl.org_id, rtl.attribute5 brand
              FROM ra_customer_trx_all rtl, xxdoec_order_payment_details xxd, ra_cust_trx_types_all rac
             WHERE     1 = 1
                   AND xxd.pg_reference_num = rtl.customer_trx_id
                   AND xxd.status = cv_status
                   AND xxd.payment_type = 'WO'
                   AND rtl.org_id = NVL (pn_org_id, rtl.org_id)
                   AND rtl.customer_trx_id =
                       NVL (pv_cust_trx_id, rtl.customer_trx_id)
                   AND rac.NAME = NVL (pv_trx_class, rac.NAME)
                   AND rac.cust_trx_type_id = rtl.cust_trx_type_id
                   AND rac.TYPE = NVL (pv_trx_type, rac.TYPE);

        lv_trx_status             VARCHAR2 (20);
        lv_error_flag             VARCHAR2 (1);
        lv_status                 VARCHAR2 (5);
        ln_partial_count          NUMBER;
        lv_activity_name          VARCHAR2 (500);
        ln_amount_due_original    NUMBER;
        ln_amount_due_remaining   NUMBER;
        lv_adj_type               VARCHAR2 (50);
        ln_adj_id                 NUMBER;
        ln_adj_number             NUMBER;
        lv_err_msg                VARCHAR2 (2000);
        ln_err_count              NUMBER := 0;
        lv_adj_amount             NUMBER;
        ln_adj_count              NUMBER;
        ln_temp                   NUMBER;
    BEGIN
        IF NVL (pv_reprocess, 'N') = 'Y'
        THEN
            lv_status   := 'ER';
        ELSE
            lv_status   := 'OP';
        END IF;

        FOR wo_rec IN wo_records_cur (lv_status)
        LOOP
            lv_error_flag             := 'N';
            ln_amount_due_original    := NULL;
            ln_amount_due_remaining   := NULL;
            lv_activity_name          := NULL;
            lv_adj_type               := NULL;
            ln_adj_count              := NULL;

            --Check if transaction is open
            IF wo_rec.status_trx <> 'OP'
            THEN
                msg (
                       'Transaction: '
                    || wo_rec.pg_reference_num
                    || ' cannot be processed as it is not open');
                lv_error_flag   := 'Y';
            ELSIF wo_rec.status_trx = 'OP'
            THEN
                --Check if transaction type and pg_action type are same
                IF wo_rec.TYPE = 'INV' AND wo_rec.pg_action = 'PGC'
                THEN
                    --Check if transaction is partially invoiced
                    BEGIN
                        --Get amount due for the transaction
                        SELECT amount_due_remaining
                          INTO ln_amount_due_remaining
                          FROM ar_payment_schedules_all
                         WHERE     status = 'OP'
                               AND CLASS = 'INV'
                               AND customer_trx_id = wo_rec.pg_reference_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_amount_due_remaining   := 0;
                            lv_err_msg                := SQLERRM;
                            msg (
                                   'Error While Getting Amount Due Remaining For Transaction: '
                                || wo_rec.pg_reference_num
                                || ' Error: '
                                || lv_err_msg);
                    END;

                    BEGIN
                        --Get total amount of the transaction
                        SELECT SUM (extended_amount)
                          INTO ln_amount_due_original
                          FROM ra_customer_trx_lines_all
                         WHERE customer_trx_id = wo_rec.pg_reference_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_amount_due_original   := 0;
                            lv_err_msg               := SQLERRM;
                            msg (
                                   'Error While Getting Amount Due Orginal For Transaction: '
                                || wo_rec.pg_reference_num
                                || ' Error: '
                                || lv_err_msg);
                    END;

                    --If amount due is less than total transaction amount its partial invoice
                    --In this case case get the activity from partail invoice
                    IF     ln_amount_due_remaining <> 0
                       AND ln_amount_due_remaining < ln_amount_due_original
                    THEN
                        get_receipt_activity_name (wo_rec.org_id,
                                                   wo_rec.pg_reference_num,
                                                   wo_rec.TYPE,
                                                   wo_rec.brand,
                                                   lv_activity_name,
                                                   lv_error_flag);
                    ELSE
                        --If it is not partial invoice get the activity from value set
                        get_default_activity (wo_rec.org_id, wo_rec.brand, lv_activity_name
                                              , lv_error_flag);
                    END IF;

                    IF wo_rec.payment_amount = ln_amount_due_remaining
                    THEN
                        --if payment amount is equal to amount due remaining adjustment type is Invoice
                        lv_adj_type   := 'INVOICE';
                    ELSIF wo_rec.payment_amount < ln_amount_due_remaining
                    THEN
                        --if payment amount is less than amount due remaining adjustment type is Line
                        lv_adj_type   := 'LINE';
                    ELSE
                        --if payment amount is greater than amount due remainingdo not process
                        msg (
                               'Cannot process write off for transaction: '
                            || wo_rec.pg_reference_num
                            || ' as write off amount is greater than amount due');
                        lv_error_flag   := 'Y';
                    END IF;

                    --As it is invoice adjustment amount must be in negative
                    lv_adj_amount   := -1 * (wo_rec.payment_amount);
                ELSIF wo_rec.TYPE = 'CM' AND wo_rec.pg_action = 'CHB'
                THEN
                    --Check if adjustment exists
                    BEGIN
                        SELECT COUNT (*)
                          INTO ln_adj_count
                          FROM ar_adjustments_all
                         WHERE customer_trx_id = wo_rec.pg_reference_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_adj_count   := 0;
                            lv_err_msg     := SQLERRM;
                            msg (
                                   'Error While Getting Existing Adjustment For Credit Memom: '
                                || wo_rec.pg_reference_num
                                || ' Error: '
                                || lv_err_msg);
                    END;

                    BEGIN
                        --Get amount due reamining
                        SELECT amount_due_remaining
                          INTO ln_amount_due_remaining
                          FROM ar_payment_schedules_all
                         WHERE     status = 'OP'
                               AND CLASS = 'CM'
                               AND customer_trx_id = wo_rec.pg_reference_num;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_amount_due_remaining   := 0;
                            lv_err_msg                := SQLERRM;
                            msg (
                                   'Error While Getting Amount Due Remaining For Transaction: '
                                || wo_rec.pg_reference_num
                                || ' Error: '
                                || lv_err_msg);
                    END;

                    --If adjustment exists get activity from adjustment
                    IF ln_adj_count > 0
                    THEN
                        get_receipt_activity_name (wo_rec.org_id,
                                                   wo_rec.pg_reference_num,
                                                   wo_rec.TYPE,
                                                   wo_rec.brand,
                                                   lv_activity_name,
                                                   lv_error_flag);
                    ELSE
                        --If adjustment does not exist get activity from value set
                        get_default_activity (wo_rec.org_id, wo_rec.brand, lv_activity_name
                                              , lv_error_flag);
                    END IF;

                    ln_temp         := -1 * (wo_rec.payment_amount);

                    IF -1 * (wo_rec.payment_amount) = ln_amount_due_remaining
                    THEN
                        --if payment amount is equal to amount due remaining adjustment type is Invoice
                        lv_adj_type   := 'INVOICE';
                    ELSIF -1 * (wo_rec.payment_amount) >
                          ln_amount_due_remaining
                    THEN
                        --if payment amount is less than amount due remaining adjustment type is Line
                        lv_adj_type   := 'LINE';
                    ELSE
                        --if payment amount is greater than amount due remaining do not process
                        msg (
                               'Cannot process write off for transaction: '
                            || wo_rec.pg_reference_num
                            || ' as write off amount is greater than amount due');
                        lv_error_flag   := 'Y';
                    END IF;

                    --As it is Credit memom adjustment amount will be in positive
                    lv_adj_amount   := wo_rec.payment_amount;
                ELSE
                    msg (
                           'Transaction: '
                        || wo_rec.pg_reference_num
                        || 'as pg_action is not valid');
                    lv_error_flag   := 'Y';
                END IF;
            END IF;

            IF NVL (lv_error_flag, 'N') = 'N'
            THEN
                --If there are no errors call adjustment ap1
                create_adjustment (wo_rec.pg_reference_num, lv_activity_name, lv_adj_type, lv_adj_amount, wo_rec.org_id, ln_adj_id
                                   , ln_adj_number, lv_err_msg);

                IF lv_err_msg IS NOT NULL
                THEN
                    msg (
                           'Error While Creating Adjustment For Transaction: '
                        || wo_rec.pg_reference_num
                        || ' Error Message: '
                        || lv_err_msg);
                    lv_error_flag   := 'Y';
                END IF;
            END IF;

            --Update Table
            IF NVL (lv_error_flag, 'N') = 'N' AND ln_adj_id IS NOT NULL
            THEN
                --If adjustment is created update staging table status to CL
                UPDATE xxdoec_order_payment_details
                   SET status   = 'CL'
                 WHERE     pg_reference_num = wo_rec.pg_reference_num
                       AND status = lv_status
                       AND payment_type = wo_rec.payment_type;
            ELSE
                --If adjustment is not created update staging table status to ER
                UPDATE xxdoec_order_payment_details
                   SET status   = 'ER'
                 WHERE     pg_reference_num = wo_rec.pg_reference_num
                       AND status = lv_status
                       AND payment_type = wo_rec.payment_type
                       AND payment_id = wo_rec.payment_id;

                ln_err_count   := ln_err_count + 1;
            END IF;
        END LOOP;

        COMMIT;

        IF ln_err_count > 0
        THEN
            --If any one record fails complete concurrent program in warning
            pv_retcode   := 1;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   := SQLERRM;
            msg ('Main error ' || lv_err_msg);
    END main;
END xxd_ar_wo_adjustments;
/
