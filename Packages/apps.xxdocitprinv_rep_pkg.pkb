--
-- XXDOCITPRINV_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdocitprinv_rep_pkg
AS
    PROCEDURE submit_ftp (p_source_path   IN     VARCHAR2,
                          p_file_name     IN     VARCHAR2,
                          p_file_server   IN     VARCHAR2,
                          p_phase            OUT VARCHAR2,
                          p_status           OUT VARCHAR2,
                          p_out_req_id       OUT NUMBER)
    IS
        xml_layout            BOOLEAN;
        ln_request_id         NUMBER;
        lv_returnmsg          VARCHAR2 (3000);
        lv_phasecode          VARCHAR2 (3000);
        lv_statuscode         VARCHAR2 (3000);
        lv_concreqcallstat1   BOOLEAN := FALSE;
        lv_phasecode1         VARCHAR2 (100) := NULL;
        lv_statuscode1        VARCHAR2 (100) := NULL;
        lv_devphase1          VARCHAR2 (100) := NULL;
        lv_devstatus1         VARCHAR2 (100) := NULL;
        lv_returnmsg1         VARCHAR2 (200) := NULL;
        lv_concreqcallstat2   BOOLEAN := FALSE;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        ln_request_id   :=
            apps.fnd_request.submit_request (application => 'XXDO', program => 'XXDOOM005B', description => '', start_time => TO_CHAR (SYSDATE, 'DD-MON-YY'), sub_request => FALSE, argument1 => p_source_path, argument2 => 'XXDOAR0211', argument3 => p_file_name, argument4 => p_file_server
                                             , argument5 => 'data.DI');
        lv_phasecode    := NULL;
        lv_statuscode   := NULL;
        lv_returnmsg    := NULL;
        COMMIT;
        lv_concreqcallstat1   :=
            apps.fnd_concurrent.wait_for_request (ln_request_id, 5 -- wait 5 seconds between db checks
                                                                  , 60,
                                                  lv_phasecode, lv_statuscode, p_phase
                                                  , p_status, lv_returnmsg);
        COMMIT;
        lv_concreqcallstat2   :=
            apps.fnd_concurrent.get_request_status (ln_request_id,
                                                    NULL,
                                                    NULL,
                                                    lv_phasecode1,
                                                    lv_statuscode1,
                                                    lv_devphase1,
                                                    lv_devstatus1,
                                                    lv_returnmsg1);

        WHILE lv_devphase1 != 'COMPLETE'
        LOOP
            lv_phasecode1    := NULL;
            lv_statuscode1   := NULL;
            lv_devphase1     := NULL;
            lv_devstatus1    := NULL;
            lv_returnmsg1    := NULL;
            lv_concreqcallstat2   :=
                apps.fnd_concurrent.get_request_status (ln_request_id,
                                                        NULL,
                                                        NULL,
                                                        lv_phasecode1,
                                                        lv_statuscode1,
                                                        lv_devphase1,
                                                        lv_devstatus1,
                                                        lv_returnmsg1);
            EXIT WHEN lv_devphase1 IN ('COMPLETE', 'ERROR', 'WARNING');
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'ftp lv_devstatus1:' || lv_devphase1);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Exception while submiting FTP program ' || SQLERRM);
    END submit_ftp;

    PROCEDURE submit_report (pn_org_id      IN     NUMBER,
                             p_request_id   IN     NUMBER,
                             p_file_name    IN     VARCHAR2,
                             p_source       IN     VARCHAR2,
                             p_iden_rec     IN     VARCHAR2,
                             p_sent_yn      IN     VARCHAR2,
                             p_phase           OUT VARCHAR2,
                             p_status          OUT VARCHAR2,
                             p_out_req_id      OUT NUMBER)
    IS
        xml_layout            BOOLEAN;
        ln_request_id         NUMBER;
        lv_returnmsg          VARCHAR2 (3000);
        lv_phasecode          VARCHAR2 (3000);
        lv_statuscode         VARCHAR2 (3000);
        lv_concreqcallstat1   BOOLEAN := FALSE;
        lv_phasecode1         VARCHAR2 (100) := NULL;
        lv_statuscode1        VARCHAR2 (100) := NULL;
        lv_devphase1          VARCHAR2 (100) := NULL;
        lv_devstatus1         VARCHAR2 (100) := NULL;
        lv_returnmsg1         VARCHAR2 (200) := NULL;
        lv_concreqcallstat2   BOOLEAN := FALSE;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        xml_layout   :=
            fnd_request.add_layout ('XXDO', 'XXDOAR0211', 'en',
                                    'US', 'ETEXT');
        -- Calling the report to generate the output
        p_out_req_id   :=
            apps.fnd_request.submit_request (
                application   => 'XXDO',
                program       => 'XXDOAR0211',
                description   => '',
                start_time    => TO_CHAR (SYSDATE, 'DD-MON-YY'),
                sub_request   => FALSE,
                argument1     => pn_org_id,
                argument2     => p_request_id,
                argument3     => p_file_name,
                argument4     => p_source,
                argument5     => p_iden_rec,
                argument6     => p_sent_yn);
        COMMIT;
        lv_concreqcallstat1   :=
            apps.fnd_concurrent.wait_for_request (p_out_req_id, 5 -- wait 5 seconds between db checks
                                                                 , 60,
                                                  lv_phasecode, lv_statuscode, p_phase
                                                  , p_status, lv_returnmsg);
        COMMIT;
        fnd_file.put_line (fnd_file.LOG, 'Rpt p_out_req_id:' || p_out_req_id);
        fnd_file.put_line (fnd_file.LOG, 'Rpt lv_phasecode:' || lv_phasecode);
        fnd_file.put_line (fnd_file.LOG,
                           'Rpt lv_statuscode:' || lv_statuscode);
        fnd_file.put_line (fnd_file.LOG, 'Rpt p_phase:' || p_phase);
        fnd_file.put_line (fnd_file.LOG, 'Rpt p_status:' || p_status);
        lv_concreqcallstat2   :=
            apps.fnd_concurrent.get_request_status (p_out_req_id,
                                                    NULL,
                                                    NULL,
                                                    lv_phasecode1,
                                                    lv_statuscode1,
                                                    lv_devphase1,
                                                    lv_devstatus1,
                                                    lv_returnmsg1);
        fnd_file.put_line (fnd_file.LOG, 'Rpt lv_devphase1:' || lv_devphase1);

        WHILE lv_devphase1 != 'COMPLETE'
        LOOP
            fnd_file.put_line (fnd_file.LOG,
                               'lv_devstatus1' || lv_devstatus1);
            lv_phasecode1    := NULL;
            lv_statuscode1   := NULL;
            lv_devphase1     := NULL;
            lv_devstatus1    := NULL;
            lv_returnmsg1    := NULL;
            lv_concreqcallstat2   :=
                apps.fnd_concurrent.get_request_status (p_out_req_id,
                                                        NULL,
                                                        NULL,
                                                        lv_phasecode1,
                                                        lv_statuscode1,
                                                        lv_devphase1,
                                                        lv_devstatus1,
                                                        lv_returnmsg1);
            EXIT WHEN lv_devphase1 IN ('COMPLETE', 'ERROR', 'WARNING');
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'Report lv_devphase1:' || lv_devphase1);
        fnd_file.put_line (fnd_file.LOG,
                           'Report lv_devstatus1:' || lv_devstatus1);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Exception while submiting concurrent program ' || SQLERRM);
    END submit_report;

    PROCEDURE update_data_stg_t (p_type IN VARCHAR2, p_negative_line_adjustment_id IN NUMBER, p_negative_tax_adjustment_id IN NUMBER, p_negative_freight_adjust_id IN NUMBER, p_negative_charges_adjust_id IN NUMBER, p_request_id IN NUMBER
                                 , p_customer_trx_id IN NUMBER, p_status IN VARCHAR2, p_error_message IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF p_type = 'CUST'
        THEN
            UPDATE xxd_cit_data_stg_t
               SET status = p_status, negative_line_adjustment_id = NVL (p_negative_line_adjustment_id, negative_line_adjustment_id), negative_tax_adjustment_id = NVL (p_negative_tax_adjustment_id, negative_tax_adjustment_id),
                   negative_freight_adjustment_id = NVL (p_negative_freight_adjust_id, negative_freight_adjustment_id), negative_charges_adjustment_id = NVL (p_negative_charges_adjust_id, negative_charges_adjustment_id), batch_id = NVL (p_request_id, batch_id),
                   error_msg = p_error_message
             WHERE customer_trx_id = p_customer_trx_id;
        ELSIF p_type = 'BATCH'
        THEN
            UPDATE xxd_cit_data_stg_t
               SET status = p_status, error_msg = p_error_message
             WHERE batch_id = p_request_id AND status <> 'E';
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'UPDATED DATA');
        COMMIT;
    END;

    PROCEDURE update_ctl_stg_t (p_request_id IN NUMBER, p_ftp_status IN VARCHAR2, p_file_name IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxd_cit_ctl_stg_t
           SET ftp_status = p_ftp_status, file_name = p_file_name
         WHERE batch_id = NVL (p_request_id, batch_id);

        fnd_file.put_line (fnd_file.LOG, 'UPDATED CTL');
        COMMIT;
    END;

    PROCEDURE insert_ctl_stg_t (p_request_id IN NUMBER, p_file_name IN VARCHAR2, p_ftp_status IN VARCHAR2
                                , p_cust_count IN NUMBER, p_invoice_count IN NUMBER, p_tot_inv_amt IN NUMBER)
    IS
        l_name   VARCHAR2 (10) := TO_CHAR (SYSDATE, 'DDMM');
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO xxd_cit_ctl_stg_t (batch_id,
                                       file_name,
                                       ftp_status,
                                       cust_count,
                                       invoice_count,
                                       tot_inv_amt,
                                       batch_date,
                                       NAME,
                                       created_by,
                                       creation_date,
                                       last_updated_by,
                                       last_updated_date)
                 VALUES (p_request_id,
                         p_file_name,
                         p_ftp_status,
                         p_cust_count,
                         p_invoice_count,
                         p_tot_inv_amt,
                         SYSDATE,
                         l_name,
                         fnd_profile.VALUE ('USER_ID'),
                         TRUNC (SYSDATE),
                         fnd_profile.VALUE ('USER_ID'),
                         TRUNC (SYSDATE));

        fnd_file.put_line (fnd_file.LOG, 'Insert CTL');
        COMMIT;
    END;

    PROCEDURE prog_main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_org_id IN NUMBER, p_type_extract IN VARCHAR2, pd_from_date IN VARCHAR2, pd_to_date IN VARCHAR2, p_file_name IN VARCHAR2, p_source IN VARCHAR2, p_iden_rec IN VARCHAR2
                         , p_sent_yn IN VARCHAR2)
    AS
        v_adj_rec                       ar_adjustments%ROWTYPE;
        v_msg_data                      VARCHAR2 (1000);
        l_msg_count                     NUMBER := 0;
        l_ret_status                    VARCHAR2 (10) := NULL;
        v_called_from                   VARCHAR2 (25) := 'ADJ-API';
        v_init_msg_list                 VARCHAR2 (1000);
        l_new_adjust_number             ar_adjustments.adjustment_number%TYPE;
        l_new_adjust_id                 ar_adjustments.adjustment_id%TYPE;
        v_old_adjust_id                 ar_adjustments.adjustment_id%TYPE;
        v_commit_flag                   VARCHAR2 (5) := 'F';
        v_validation_level              NUMBER (4) := fnd_api.g_valid_level_full;
        v_chk_approval_limits           VARCHAR2 (5) := 'F';
        v_check_amount                  VARCHAR2 (5) := 'F';
        v_move_deferred_tax             VARCHAR2 (1) := 'Y';
        x_status_flag                   VARCHAR2 (5);
        l_receivables_trx_id            VARCHAR2 (20);
        ln_request_id                   NUMBER := 0;
        xml_layout                      BOOLEAN;
        lv_concreqcallstat1             BOOLEAN := FALSE;
        p_batch_id                      NUMBER := NULL;
        lv_phasecode                    VARCHAR2 (100) := NULL;
        lv_statuscode                   VARCHAR2 (100) := NULL;
        lv_devphase                     VARCHAR2 (100) := NULL;
        lv_devstatus                    VARCHAR2 (100) := NULL;
        lv_returnmsg                    VARCHAR2 (200) := NULL;
        l_request_id                    fnd_concurrent_requests.request_id%TYPE;
        lv_source_path                  VARCHAR2 (5000);
        lv_fileserver                   VARCHAR2 (50);
        lv_filename                     VARCHAR2 (60);
        lv_phasecode1                   VARCHAR2 (100) := NULL;
        lv_statuscode1                  VARCHAR2 (100) := NULL;
        lv_devphase1                    VARCHAR2 (100) := NULL;
        lv_devstatus1                   VARCHAR2 (100) := NULL;
        lv_returnmsg1                   VARCHAR2 (200) := NULL;
        ln_request_id1                  NUMBER := 0;
        lv_concreqcallstat              BOOLEAN := FALSE;
        lv_concreqcallstat2             BOOLEAN := FALSE;
        ex_batch_bal                    EXCEPTION;
        l_invoice_count                 NUMBER := 0;
        l_cust_count                    NUMBER := 0;
        l_tot_inv_amt                   NUMBER := 0;
        l_status                        VARCHAR2 (100) := NULL;
        l_negative_line_adjustment_id   NUMBER := NULL;
        l_negative_tax_adjustment_id    NUMBER := NULL;
        l_negative_freight_adjust_id    NUMBER := NULL;
        l_negative_charges_adjust_id    NUMBER := NULL;

        CURSOR stg_cur (pn_batch_id IN NUMBER)
        IS
            SELECT xstg.trx_number, xstg.brand, cust.account_number,
                   xstg.error_msg
              FROM apps.xxd_cit_data_stg_t xstg, hz_cust_accounts_all cust
             WHERE     cust.cust_account_id = xstg.bill_to_customer_id
                   AND batch_id = pn_batch_id;

        CURSOR data_cur IS
            SELECT *
              FROM xxd_cit_data_stg_t
             WHERE status = p_type_extract;

        CURSOR pay_schedule_rec_cur (p_cust_trx_id IN NUMBER)
        IS
            SELECT amount_due_remaining, amount_line_items_remaining, tax_remaining,
                   freight_remaining
              FROM ar_payment_schedules_all
             WHERE customer_trx_id = p_cust_trx_id;

        l_err_cust_trx_id               NUMBER;

        TYPE rec_c1 IS TABLE OF data_cur%ROWTYPE;

        lv_rec_c1                       rec_c1;
        lv_pay_rec                      pay_schedule_rec_cur%ROWTYPE;
    BEGIN
        l_request_id   := fnd_global.conc_request_id;
        fnd_file.put_line (fnd_file.LOG, 'l_request_id:' || l_request_id);

        IF p_type_extract != 'E'
        THEN
            INSERT INTO xxdo.xxd_cit_data_stg_t
                SELECT l_request_id batch_id,                   --ps.trx_date,
                                              ps.customer_trx_id, ps.trx_number,
                       hzc.attribute1, trx.bill_to_customer_id, trx.ship_to_customer_id,
                       ps.amount_due_remaining, ps.payment_schedule_id, 'N' status,
                       'New' error_msg, ps.trx_date, NULL negative_line_adjustment_id,
                       NULL negative_tax_adjustment_id, NULL negative_freight_adjustment_id, NULL positive_adjustment_id,
                       NULL negative_charges_adjustment_id, ps.receivables_charges_remaining, ps.amount_line_items_remaining,
                       ps.tax_remaining, ps.freight_remaining, fnd_profile.VALUE ('USER_ID') created_by,
                       TRUNC (SYSDATE) creation_date, fnd_profile.VALUE ('USER_ID') last_updated_by, TRUNC (SYSDATE) last_updated_date
                  FROM apps.ar_payment_schedules_all ps, apps.ra_customer_trx_all trx, apps.hz_cust_accounts hzc,
                       apps.ra_terms rt
                 WHERE     ps.customer_trx_id = trx.customer_trx_id
                       AND trx.bill_to_customer_id = hzc.cust_account_id
                       AND trx.term_id = rt.term_id
                       AND ps.status = 'OP'
                       AND ps.amount_due_remaining > 0
                       AND NVL (ps.amount_in_dispute, 0) = 0
                       AND ps.trx_date BETWEEN TO_DATE (
                                                   fnd_conc_date.string_to_date (
                                                       pd_from_date))
                                           AND TO_DATE (
                                                   fnd_conc_date.string_to_date (
                                                       pd_to_date))
                       AND ps.CLASS = 'INV'
                       AND trx.interface_header_context = 'ORDER ENTRY'
                       AND ps.org_id = pn_org_id
                       AND rt.NAME NOT IN ('CREDIT CARD', 'PREPAY', 'COD')
                       AND 'Y' =
                           xxdoom_cit_int_pkg.is_fact_cust_f (
                               interface_header_attribute1,
                               ps.customer_id,
                               ps.customer_site_use_id)
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM xxd_cit_data_stg_t
                                 WHERE customer_trx_id = ps.customer_trx_id);
        ELSE
            FOR c_err_rec IN data_cur
            LOOP
                OPEN pay_schedule_rec_cur (c_err_rec.customer_trx_id);

                FETCH pay_schedule_rec_cur INTO lv_pay_rec;

                CLOSE pay_schedule_rec_cur;

                UPDATE xxd_cit_data_stg_t
                   SET amount_due_remaining = lv_pay_rec.amount_due_remaining, amount_line_items_remaining = lv_pay_rec.amount_line_items_remaining, tax_remaining = lv_pay_rec.tax_remaining,
                       freight_remaining = lv_pay_rec.freight_remaining, negative_line_adjustment_id = NULL, negative_tax_adjustment_id = NULL,
                       negative_freight_adjustment_id = NULL
                 WHERE customer_trx_id = c_err_rec.customer_trx_id;
            END LOOP;
        END IF;

        COMMIT;
        fnd_file.put_line (fnd_file.LOG, 'Inserted');

        BEGIN
            fnd_file.put_line (fnd_file.LOG, 'Initialize');
            fnd_global.apps_initialize (
                user_id        => fnd_global.user_id,
                --2066 ,
                resp_id        => fnd_global.resp_id,
                --50712,
                resp_appl_id   => fnd_global.resp_appl_id--222
                                                         );
            mo_global.init ('AR');
            mo_global.set_policy_context ('S', pn_org_id);
            fnd_file.put_line (fnd_file.LOG, 'cursor open');

            OPEN data_cur;

            FETCH data_cur BULK COLLECT INTO lv_rec_c1;

            fnd_file.put_line (fnd_file.LOG, 'fetch');

            CLOSE data_cur;

            fnd_file.put_line (fnd_file.LOG,
                               'cursor close' || lv_rec_c1.COUNT);

            FOR j IN 1 .. lv_rec_c1.COUNT
            LOOP
                fnd_file.put_line (fnd_file.LOG, 'loop');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'l_receivables_trx_id1: ' || l_receivables_trx_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'lv_rec_c1 (j).brand: ' || lv_rec_c1 (j).brand);

                BEGIN
                    SELECT receivables_trx_id
                      INTO l_receivables_trx_id
                      FROM ar_receivables_trx_all
                     WHERE NAME =
                              lv_rec_c1 (j).brand
                           || '-'
                           || fnd_profile.VALUE (
                                  'XXDO: ACTIVITY FOR CIT DEBT TRANSFER');

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'l_receivables_trx_id2: ' || l_receivables_trx_id);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Activity Name not found for ":'
                            || lv_rec_c1 (j).brand
                            || '-'
                            || fnd_profile.VALUE (
                                   'XXDO: ACTIVITY FOR CIT DEBT TRANSFER')
                            || '"');
                        update_data_stg_t (
                            'BATCH',
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            l_request_id,
                            NULL,
                            'E',
                               'Activity Name not found for ":'
                            || lv_rec_c1 (j).brand
                            || '-'
                            || fnd_profile.VALUE (
                                   'XXDO: ACTIVITY FOR CIT DEBT TRANSFER')
                            || '"');
                        update_data_stg_t (
                            'CUST',
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            l_request_id,
                            lv_rec_c1 (j).customer_trx_id,
                            'E',
                            'Error found in other transaction of this batch');
                        ROLLBACK;
                        RETURN;
                END;

                --Populate v_adj_rec record
                v_adj_rec.customer_trx_id       := lv_rec_c1 (j).customer_trx_id;
                v_adj_rec.TYPE                  := 'LINE';
                v_adj_rec.gl_date               := TRUNC (SYSDATE);
                v_adj_rec.apply_date            := TRUNC (SYSDATE);
                v_adj_rec.amount                :=
                    lv_rec_c1 (j).amount_line_items_remaining * -1;
                v_adj_rec.payment_schedule_id   :=
                    lv_rec_c1 (j).payment_schedule_id;
                v_adj_rec.created_from          := 'ADJ-API';
                v_adj_rec.receivables_trx_id    := l_receivables_trx_id;

                BEGIN
                    fnd_file.put_line (fnd_file.LOG, 'API Start');
                    ar_adjust_pub.create_adjustment (
                        p_api_name              => 'AR_ADJUST_PUB',
                        p_api_version           => 1.0,
                        p_init_msg_list         => fnd_api.g_true,
                        p_commit_flag           => fnd_api.g_false,
                        p_validation_level      => fnd_api.g_valid_level_full,
                        p_msg_count             => l_msg_count,
                        p_msg_data              => v_msg_data,
                        p_return_status         => l_ret_status,
                        p_adj_rec               => v_adj_rec,
                        p_chk_approval_limits   => fnd_api.g_false,
                        p_check_amount          => fnd_api.g_false,
                        p_move_deferred_tax     => NULL,
                        p_new_adjust_number     => l_new_adjust_number,
                        p_new_adjust_id         =>
                            l_negative_line_adjustment_id,
                        p_called_from           => v_called_from,
                        p_old_adjust_id         => v_old_adjust_id,
                        p_org_id                => pn_org_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'IN Exception while creating LINE Adjusment:'
                            || lv_rec_c1 (j).trx_number);
                        fnd_file.put_line (fnd_file.LOG, SQLERRM);
                        update_data_stg_t (
                            'BATCH',
                            l_negative_line_adjustment_id,
                            NULL,
                            NULL,
                            NULL,
                            l_request_id,
                            NULL,
                            'E',
                               'IN Exception while creating LINE Adjusment:'
                            || lv_rec_c1 (j).trx_number);
                        update_data_stg_t (
                            'CUST',
                            l_negative_line_adjustment_id,
                            NULL,
                            NULL,
                            NULL,
                            l_request_id,
                            lv_rec_c1 (j).customer_trx_id,
                            'E',
                            'Error found in other transaction of this batch');
                        ROLLBACK;
                        RETURN;
                END;

                IF l_negative_line_adjustment_id IS NULL
                THEN
                    ROLLBACK;
                END IF;

                --            IF l_ret_status = fnd_api.g_ret_sts_success
                --            THEN
                ----               COMMIT;
                fnd_file.put_line (fnd_file.LOG,
                                   'l_ret_status' || l_ret_status);
                --            END IF;
                x_status_flag                   := l_ret_status;

                IF l_ret_status <> fnd_api.g_ret_sts_success
                THEN
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        v_msg_data   :=
                            fnd_msg_pub.get (p_msg_index   => i,
                                             p_encoded     => 'F');
                        fnd_file.put_line (fnd_file.LOG,
                                           'v_msg_data:' || v_msg_data);
                    END LOOP;

                    update_data_stg_t ('BATCH', NULL, NULL,
                                       NULL, NULL, l_request_id,
                                       NULL, 'E', v_msg_data);
                    update_data_stg_t (
                        'CUST',
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        l_request_id,
                        lv_rec_c1 (j).customer_trx_id,
                        'E',
                        'Error found in other transaction of this batch');
                    ROLLBACK;
                    RETURN;
                ELSE
                    --Added
                    update_data_stg_t ('CUST',
                                       l_negative_line_adjustment_id,
                                       l_negative_tax_adjustment_id,
                                       l_negative_freight_adjust_id,
                                       l_negative_charges_adjust_id,
                                       l_request_id,
                                       lv_rec_c1 (j).customer_trx_id,
                                       NULL,
                                       NULL);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'l_negative_line_adjustment_id1:'
                        || l_negative_line_adjustment_id);
                END IF;

                -- Create Tax adjustment
                IF x_status_flag = 'S' AND lv_rec_c1 (j).tax_remaining > 0
                THEN
                    v_adj_rec.customer_trx_id       :=
                        lv_rec_c1 (j).customer_trx_id;
                    v_adj_rec.TYPE                  := 'TAX';
                    v_adj_rec.gl_date               := TRUNC (SYSDATE);
                    v_adj_rec.apply_date            := TRUNC (SYSDATE);
                    v_adj_rec.amount                :=
                        lv_rec_c1 (j).tax_remaining * -1;
                    v_adj_rec.payment_schedule_id   :=
                        lv_rec_c1 (j).payment_schedule_id;
                    v_adj_rec.created_from          := 'ADJ-API';
                    v_adj_rec.receivables_trx_id    := l_receivables_trx_id;

                    BEGIN
                        fnd_file.put_line (fnd_file.LOG, 'API Start');
                        ar_adjust_pub.create_adjustment (
                            p_api_name              => 'AR_ADJUST_PUB',
                            p_api_version           => 1.0,
                            p_init_msg_list         => fnd_api.g_true,
                            p_commit_flag           => fnd_api.g_false,
                            p_validation_level      => fnd_api.g_valid_level_full,
                            p_msg_count             => l_msg_count,
                            p_msg_data              => v_msg_data,
                            p_return_status         => l_ret_status,
                            p_adj_rec               => v_adj_rec,
                            p_chk_approval_limits   => fnd_api.g_false,
                            p_check_amount          => fnd_api.g_false,
                            p_move_deferred_tax     => NULL,
                            p_new_adjust_number     => l_new_adjust_number,
                            p_new_adjust_id         =>
                                l_negative_tax_adjustment_id,
                            p_called_from           => v_called_from,
                            p_old_adjust_id         => v_old_adjust_id,
                            p_org_id                => pn_org_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'IN Exception while creating TAX Adjusment:'
                                || lv_rec_c1 (j).trx_number);
                            fnd_file.put_line (fnd_file.LOG, SQLERRM);
                            ROLLBACK;
                    END;

                    IF l_negative_tax_adjustment_id IS NULL
                    THEN
                        ROLLBACK;
                    END IF;

                    --            IF  fnd_api.g_ret_sts_success <> 'S'
                    --            THEN
                    ----               COMMIT;
                    --               ROLLBACK;
                    fnd_file.put_line (fnd_file.LOG,
                                       'l_ret_status' || l_ret_status);
                    --            END IF;
                    x_status_flag                   := l_ret_status;

                    IF l_ret_status <> fnd_api.g_ret_sts_success
                    THEN
                        FOR i IN 1 .. l_msg_count
                        LOOP
                            v_msg_data   :=
                                fnd_msg_pub.get (p_msg_index   => i,
                                                 p_encoded     => 'F');
                            fnd_file.put_line (fnd_file.LOG,
                                               'v_msg_data:' || v_msg_data);
                        END LOOP;

                        update_data_stg_t ('BATCH', NULL, l_negative_tax_adjustment_id, NULL, NULL, l_request_id
                                           , NULL, 'E', v_msg_data);
                        update_data_stg_t (
                            'CUST',
                            NULL,
                            l_negative_tax_adjustment_id,
                            NULL,
                            NULL,
                            l_request_id,
                            lv_rec_c1 (j).customer_trx_id,
                            'E',
                            'Error found in other transaction of this batch');
                        ROLLBACK;
                        RETURN;
                    ELSE
                        --Added
                        update_data_stg_t ('CUST',
                                           l_negative_line_adjustment_id,
                                           l_negative_tax_adjustment_id,
                                           l_negative_freight_adjust_id,
                                           l_negative_charges_adjust_id,
                                           l_request_id,
                                           lv_rec_c1 (j).customer_trx_id,
                                           NULL,
                                           NULL);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'l_negative_tax_adjustment_id1:'
                            || l_negative_tax_adjustment_id);
                    END IF;
                END IF;

                -- Create Freight adjustment
                IF     x_status_flag = 'S'
                   AND lv_rec_c1 (j).freight_remaining > 0
                THEN
                    v_adj_rec.customer_trx_id       :=
                        lv_rec_c1 (j).customer_trx_id;
                    v_adj_rec.TYPE                  := 'FREIGHT';
                    v_adj_rec.gl_date               := TRUNC (SYSDATE);
                    v_adj_rec.apply_date            := TRUNC (SYSDATE);
                    v_adj_rec.amount                :=
                        lv_rec_c1 (j).freight_remaining * -1;
                    v_adj_rec.payment_schedule_id   :=
                        lv_rec_c1 (j).payment_schedule_id;
                    v_adj_rec.created_from          := 'ADJ-API';
                    v_adj_rec.receivables_trx_id    := l_receivables_trx_id;

                    BEGIN
                        fnd_file.put_line (fnd_file.LOG, 'API Start');
                        ar_adjust_pub.create_adjustment (
                            p_api_name              => 'AR_ADJUST_PUB',
                            p_api_version           => 1.0,
                            p_init_msg_list         => fnd_api.g_true,
                            p_commit_flag           => fnd_api.g_false,
                            p_validation_level      => fnd_api.g_valid_level_full,
                            p_msg_count             => l_msg_count,
                            p_msg_data              => v_msg_data,
                            p_return_status         => l_ret_status,
                            p_adj_rec               => v_adj_rec,
                            p_chk_approval_limits   => fnd_api.g_false,
                            p_check_amount          => fnd_api.g_false,
                            p_move_deferred_tax     => NULL,
                            p_new_adjust_number     => l_new_adjust_number,
                            p_new_adjust_id         =>
                                l_negative_freight_adjust_id,
                            p_called_from           => v_called_from,
                            p_old_adjust_id         => v_old_adjust_id,
                            p_org_id                => pn_org_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'IN Exception while creating FREIGHT Adjusment:'
                                || lv_rec_c1 (j).trx_number);
                            fnd_file.put_line (fnd_file.LOG, SQLERRM);
                            update_data_stg_t (
                                'BATCH',
                                NULL,
                                NULL,
                                l_negative_freight_adjust_id,
                                NULL,
                                l_request_id,
                                NULL,
                                'E',
                                   'IN Exception while creating FREIGHT Adjusment:'
                                || lv_rec_c1 (j).trx_number);
                            update_data_stg_t (
                                'CUST',
                                NULL,
                                NULL,
                                l_negative_freight_adjust_id,
                                NULL,
                                l_request_id,
                                lv_rec_c1 (j).customer_trx_id,
                                'E',
                                'Error found in other transaction of this batch');
                            ROLLBACK;
                            RETURN;
                    END;

                    IF l_negative_freight_adjust_id IS NULL
                    THEN
                        ROLLBACK;
                    END IF;

                    --            IF l_ret_status = fnd_api.g_ret_sts_success
                    --            THEN
                    ----               COMMIT;
                    fnd_file.put_line (fnd_file.LOG,
                                       'l_ret_status' || l_ret_status);
                    --            END IF;
                    x_status_flag                   := l_ret_status;

                    IF l_ret_status <> fnd_api.g_ret_sts_success
                    THEN
                        FOR i IN 1 .. l_msg_count
                        LOOP
                            v_msg_data   :=
                                fnd_msg_pub.get (p_msg_index   => i,
                                                 p_encoded     => 'F');
                            fnd_file.put_line (fnd_file.LOG,
                                               'v_msg_data:' || v_msg_data);
                        END LOOP;

                        update_data_stg_t ('BATCH', NULL, NULL,
                                           NULL, NULL, l_request_id,
                                           NULL, 'E', v_msg_data);
                        update_data_stg_t (
                            'CUST',
                            NULL,
                            NULL,
                            NULL,
                            NULL,
                            l_request_id,
                            lv_rec_c1 (j).customer_trx_id,
                            'E',
                            'Error found in other transaction of this batch');
                        ROLLBACK;
                        RETURN;
                    ELSE
                        --Added
                        update_data_stg_t ('CUST',
                                           l_negative_line_adjustment_id,
                                           l_negative_tax_adjustment_id,
                                           l_negative_freight_adjust_id,
                                           l_negative_charges_adjust_id,
                                           l_request_id,
                                           lv_rec_c1 (j).customer_trx_id,
                                           NULL,
                                           NULL);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'l_negative_freight_adjust_id1:'
                            || l_negative_freight_adjust_id);
                    END IF;
                END IF;

                -- Create charges adjustment  (added 0n 05-05-2015)
                IF     x_status_flag = 'S'
                   AND lv_rec_c1 (j).receivables_charges_remaining > 0
                THEN
                    v_adj_rec.customer_trx_id       :=
                        lv_rec_c1 (j).customer_trx_id;
                    v_adj_rec.TYPE                  := 'CHARGES';
                    v_adj_rec.gl_date               := TRUNC (SYSDATE);
                    v_adj_rec.apply_date            := TRUNC (SYSDATE);
                    v_adj_rec.amount                :=
                        lv_rec_c1 (j).receivables_charges_remaining * -1;
                    v_adj_rec.payment_schedule_id   :=
                        lv_rec_c1 (j).payment_schedule_id;
                    v_adj_rec.created_from          := 'ADJ-API';
                    v_adj_rec.receivables_trx_id    := l_receivables_trx_id;

                    BEGIN
                        fnd_file.put_line (fnd_file.LOG, 'API Start');
                        ar_adjust_pub.create_adjustment (
                            p_api_name              => 'AR_ADJUST_PUB',
                            p_api_version           => 1.0,
                            p_init_msg_list         => fnd_api.g_true,
                            p_commit_flag           => fnd_api.g_false,
                            p_validation_level      => fnd_api.g_valid_level_full,
                            p_msg_count             => l_msg_count,
                            p_msg_data              => v_msg_data,
                            p_return_status         => l_ret_status,
                            p_adj_rec               => v_adj_rec,
                            p_chk_approval_limits   => fnd_api.g_false,
                            p_check_amount          => fnd_api.g_false,
                            p_move_deferred_tax     => NULL,
                            p_new_adjust_number     => l_new_adjust_number,
                            p_new_adjust_id         =>
                                l_negative_charges_adjust_id,
                            p_called_from           => v_called_from,
                            p_old_adjust_id         => v_old_adjust_id,
                            p_org_id                => pn_org_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'IN Exception while creating CHARGES Adjustment:'
                                || lv_rec_c1 (j).trx_number);
                            fnd_file.put_line (fnd_file.LOG, SQLERRM);
                            ROLLBACK;
                    END;

                    IF l_negative_charges_adjust_id IS NULL
                    THEN
                        ROLLBACK;
                    END IF;

                    --            IF  fnd_api.g_ret_sts_success <> 'S'
                    --            THEN
                    ----               COMMIT;
                    --               ROLLBACK;
                    fnd_file.put_line (fnd_file.LOG,
                                       'l_ret_status' || l_ret_status);
                    --            END IF;
                    x_status_flag                   := l_ret_status;

                    IF l_ret_status <> fnd_api.g_ret_sts_success
                    THEN
                        FOR i IN 1 .. l_msg_count
                        LOOP
                            v_msg_data   :=
                                fnd_msg_pub.get (p_msg_index   => i,
                                                 p_encoded     => 'F');
                            fnd_file.put_line (fnd_file.LOG,
                                               'v_msg_data:' || v_msg_data);
                        END LOOP;

                        update_data_stg_t ('BATCH', NULL, NULL,
                                           NULL, l_negative_charges_adjust_id, l_request_id
                                           , NULL, 'E', v_msg_data);
                        update_data_stg_t (
                            'CUST',
                            NULL,
                            NULL,
                            NULL,
                            l_negative_charges_adjust_id,
                            l_request_id,
                            lv_rec_c1 (j).customer_trx_id,
                            'E',
                            'Error found in other transaction of this batch');
                        ROLLBACK;
                        RETURN;
                    ELSE
                        --Added
                        update_data_stg_t ('CUST',
                                           l_negative_line_adjustment_id,
                                           l_negative_tax_adjustment_id,
                                           l_negative_freight_adjust_id,
                                           l_negative_charges_adjust_id,
                                           l_request_id,
                                           lv_rec_c1 (j).customer_trx_id,
                                           NULL,
                                           NULL);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'l_negative_charges_adjust_id1:'
                            || l_negative_charges_adjust_id);
                    END IF;
                END IF;

                --end added by 05-05-2015
                IF x_status_flag = 'S'
                THEN
                    update_data_stg_t ('CUST',
                                       l_negative_line_adjustment_id,
                                       l_negative_tax_adjustment_id,
                                       l_negative_freight_adjust_id,
                                       l_negative_charges_adjust_id,
                                       l_request_id,
                                       lv_rec_c1 (j).customer_trx_id,
                                       'DBC',
                                       'Debt successfully transferred');
                ELSIF x_status_flag <> 'S'
                THEN
                    ROLLBACK;
                    update_data_stg_t ('BATCH', NULL, NULL,
                                       NULL, NULL, l_request_id,
                                       NULL, 'E', v_msg_data);
                    update_data_stg_t (
                        'CUST',
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        l_request_id,
                        lv_rec_c1 (j).customer_trx_id,
                        'E',
                        'Error found in other transaction of this batch');
                    ROLLBACK;
                    RETURN;
                END IF;

                --            COMMIT;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'l_negative_line_adjustment_id:'
                    || l_negative_line_adjustment_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'l_negative_tax_adjustment_id:'
                    || l_negative_tax_adjustment_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'l_negative_freight_adjust_id:'
                    || l_negative_freight_adjust_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'l_negative_charges_adjust_id:'
                    || l_negative_charges_adjust_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'v_init_msg_list:' || v_init_msg_list);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_ret_status:' || l_ret_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_msg_count:' || l_msg_count);
            --------
            -- <<ENDLOOP>>
            END LOOP;

            fnd_file.put_line (fnd_file.LOG, 'after loop');

            BEGIN
                SELECT COUNT (DISTINCT (bill_to_customer_id))
                  INTO l_cust_count
                  FROM xxd_cit_data_stg_t
                 WHERE status = 'DBC' AND batch_id = l_request_id;

                SELECT COUNT (trx_number), SUM (amount_due_remaining)
                  INTO l_invoice_count, l_tot_inv_amt
                  FROM xxd_cit_data_stg_t
                 WHERE status = 'DBC' AND batch_id = l_request_id;

                fnd_file.put_line (fnd_file.LOG,
                                   'l_invoice_count ' || l_invoice_count);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_tot_inv_amt ' || l_tot_inv_amt);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_cust_count ' || l_cust_count);
                fnd_file.put_line (fnd_file.LOG, 'before insert');
                insert_ctl_stg_t (l_request_id,
                                  lv_filename,
                                  NULL,
                                  l_cust_count,
                                  l_invoice_count,
                                  l_tot_inv_amt);
                fnd_file.put_line (fnd_file.LOG, 'after insert');
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'after adjustment creation ' || SQLERRM);
                    update_data_stg_t (
                        'BATCH',
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        l_request_id,
                        NULL,
                        'E',
                        'After adjustment creation' || SQLERRM);
                    ROLLBACK;
                    RETURN;
            END;

            BEGIN
                fnd_file.put_line (fnd_file.LOG, 'pn_org_id:' || pn_org_id);
                fnd_file.put_line (fnd_file.LOG, 'p_batch_id:' || p_batch_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Responsible id is:' || apps.fnd_global.resp_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'Request id is:' || ln_request_id);
                -- template  assigning.
                /*           xml_layout :=
                              fnd_request.add_layout ('XXDO',
                                                      'XXDOAR0211',
                                                      'en',
                                                      'US',
                                                      'ETEXT'
                                                     );
                           -- Calling the report to generate the output
                           fnd_file.put_line (apps.fnd_file.LOG, 'Before submitting program');
                           ln_request_id :=
                              apps.fnd_request.submit_request
                                                         (application      => 'XXDO',
                                                          program          => 'XXDOAR0211',
                                                          description      => '',
                                                          start_time       => TO_CHAR
                                                                                 (SYSDATE,
                                                                                  'DD-MON-YY'
                                                                                 ),
                                                          sub_request      => FALSE,
                                                          argument1        => pn_org_id,
                                                          argument2        => l_request_id,
                                                          argument3        => p_file_name,
                                                          argument4        => p_source,
                                                          argument5        => p_iden_rec,
                                                          argument6        => p_sent_yn
                                                         );
                           COMMIT;
                           lv_concreqcallstat1 :=
                              apps.fnd_concurrent.wait_for_request
                                                       (ln_request_id,
                                                        5 -- wait 5 seconds between db checks
                                                         ,
                                                        0,
                                                        lv_phasecode,
                                                        lv_statuscode,
                                                        lv_devphase,
                                                        lv_devstatus,
                                                        lv_returnmsg
                                                       );
               --            COMMIT;*/
                submit_report (pn_org_id      => pn_org_id,
                               p_request_id   => l_request_id,
                               p_file_name    => p_file_name,
                               p_source       => p_source,
                               p_iden_rec     => p_iden_rec,
                               p_sent_yn      => p_sent_yn,
                               p_phase        => lv_devphase,
                               p_status       => lv_devstatus,
                               p_out_req_id   => ln_request_id);
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'lv_PhaseCode1 is ' || lv_phasecode1);
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'lv_StatusCode1 is ' || lv_statuscode1);
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'lv_DevPhase1 is ' || lv_devphase1);
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'lv_DevStatus1 is ' || lv_devstatus1);
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'p_sent_yn ' || p_sent_yn);
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Request id is: ' || ln_request_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Program Status:' || lv_devstatus || lv_devphase);
            END;

            BEGIN
                IF lv_devphase = 'COMPLETE' AND lv_devstatus = 'NORMAL'
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Request ID1: ' || ln_request_id);
                    update_data_stg_t ('BATCH', NULL, NULL,
                                       NULL, NULL, l_request_id,
                                       NULL, 'SE', 'Successfully Extracted');
                ELSIF lv_devstatus <> 'NORMAL'
                THEN
                    update_data_stg_t ('BATCH', NULL, NULL,
                                       NULL, NULL, l_request_id,
                                       NULL, 'E', 'Extraction Failed');
                    ROLLBACK;
                    RETURN;
                    pv_retcode   := 2;
                END IF;
            END;

            /* getting the Source Path */
            BEGIN
                SELECT SUBSTR (outfile_name, 1, INSTR (outfile_name, 'out') + 2)
                  INTO lv_source_path
                  FROM apps.fnd_concurrent_requests
                 WHERE request_id = ln_request_id;

                fnd_file.put_line (fnd_file.LOG,
                                   'lv_source_path: ' || lv_source_path);
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Concurrent Request id path is still  not available erroring out ');
                    update_data_stg_t (
                        'BATCH',
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        l_request_id,
                        NULL,
                        'E',
                        'Concurrent Request id path is still  not available erroring out');
                    ROLLBACK;
                    RETURN;
                    --               COMMIT;
                    pv_retcode   := 2;
            --                EXIT;
            END;

            /* Retrieving the File Server Name */
            BEGIN
                SELECT DECODE (applications_system_name, 'PROD', apps.fnd_profile.VALUE ('DO CIT: FTP Address'), apps.fnd_profile.VALUE ('DO CIT: Test FTP Address')) file_server_name
                  INTO lv_fileserver
                  FROM apps.fnd_product_groups;

                fnd_file.put_line (fnd_file.LOG,
                                   'lv_fileserver: ' || lv_fileserver);
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Unable to fetch the File server name');
                    update_data_stg_t (
                        'BATCH',
                        NULL,
                        NULL,
                        NULL,
                        NULL,
                        l_request_id,
                        NULL,
                        'E',
                        'Unable to fetch the File server name');
                    pv_retcode   := 2;
                    ROLLBACK;
                    RETURN;
            --                EXIT;
            END;

            lv_filename   := 'XXDOAR0211_' || ln_request_id || '_1.ETEXT';

            -- Checking the report status
            /*lv_concreqcallstat2 :=
               apps.fnd_concurrent.get_request_status (ln_request_id,
                                                       NULL,
                                                       NULL,
                                                       lv_phasecode1,
                                                       lv_statuscode1,
                                                       lv_devphase1,
                                                       lv_devstatus1,
                                                       lv_returnmsg1
                                                      );

            WHILE lv_devphase1 != 'COMPLETE'
            LOOP
               lv_phasecode1 := NULL;
               lv_statuscode1 := NULL;
               lv_devphase1 := NULL;
               lv_devstatus1 := NULL;
               lv_returnmsg1 := NULL;
               lv_concreqcallstat2 :=
                  apps.fnd_concurrent.get_request_status (ln_request_id,
                                                          NULL,
                                                          NULL,
                                                          lv_phasecode1,
                                                          lv_statuscode1,
                                                          lv_devphase1,
                                                          lv_devstatus1,
                                                          lv_returnmsg1
                                                         );
               EXIT WHEN lv_devphase1 IN ('COMPLETE', 'ERROR', 'WARNING');
            END LOOP;

            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'lv_PhaseCode1 is ' || lv_phasecode1
                                   );
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'lv_StatusCode1 is ' || lv_statuscode1
                                   );
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'lv_DevPhase1 is ' || lv_devphase1
                                   );
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'lv_DevStatus1 is ' || lv_devstatus1
                                   );
            apps.fnd_file.put_line (apps.fnd_file.LOG, 'p_sent_yn ' || p_sent_yn);*/
            IF p_sent_yn = 'Y'
            -- AND lv_devphase1 = 'COMPLETE'
            --  AND lv_devstatus1 = 'NORMAL'
            THEN
                BEGIN
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'FTP Program Start');
                    /*     ln_request_id1 :=
                            apps.fnd_request.submit_request
                                                   (application      => 'XXDO',
                                                    program          => 'XXDOOM005B',
                                                    description      => '',
                                                    start_time       => TO_CHAR
                                                                            (SYSDATE,
                                                                             'DD-MON-YY'
                                                                            ),
                                                    sub_request      => FALSE,
                                                    argument1        => lv_source_path,
                                                    argument2        => 'XXDOAR0211',
                                                    argument3        => lv_filename,
                                                    argument4        => lv_fileserver,
                                                    argument5        => 'data.DI'
                                                   --filetype=data.DI for invoice, data.CO for Orders
                                                   );
                         apps.fnd_file.put_line (apps.fnd_file.LOG, 'FTP Program end');
                         apps.fnd_file.put_line (apps.fnd_file.LOG,
                                                 'ln_request_id1: ' || ln_request_id1
                                                );
                         lv_phasecode := NULL;
                         lv_statuscode := NULL;
                         lv_devphase := NULL;
                         lv_devstatus := NULL;
                         lv_returnmsg := NULL;
                         COMMIT;
                         lv_concreqcallstat :=
                            apps.fnd_concurrent.wait_for_request
                                                  (ln_request_id1,
                                                   5 -- wait 5 seconds between db checks
                                                    ,
                                                   0,
                                                   lv_phasecode,
                                                   lv_statuscode,
                                                   lv_devphase,
                                                   lv_devstatus,
                                                   lv_returnmsg
                                                  );
                         fnd_file.put_line (fnd_file.LOG,
                                               'Program Status2:'
                                            || lv_devstatus
                                            || lv_devphase
                                           );*/
                    submit_ftp (p_source_path   => lv_source_path,
                                p_file_name     => lv_filename,
                                p_file_server   => lv_fileserver,
                                p_phase         => lv_devphase,
                                p_status        => lv_devstatus,
                                p_out_req_id    => ln_request_id1);

                    IF lv_devphase = 'COMPLETE' AND lv_devstatus = 'NORMAL'
                    THEN
                        fnd_file.put_line (fnd_file.LOG,
                                           'Request ID1: ' || ln_request_id1);

                        IF p_type_extract = 'E'
                        THEN
                            update_data_stg_t ('BATCH',
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL,
                                               l_request_id,
                                               NULL,
                                               'RPF',
                                               'Successfully Transmitted');
                        ELSE
                            update_data_stg_t ('BATCH',
                                               NULL,
                                               NULL,
                                               NULL,
                                               NULL,
                                               l_request_id,
                                               NULL,
                                               'SF',
                                               'Successfully Transmitted');
                        END IF;

                        update_ctl_stg_t (l_request_id,
                                          'FTP SUCCESSFUL',
                                          lv_filename);
                    ELSIF lv_devstatus <> 'NORMAL'
                    THEN
                        ROLLBACK;
                        update_data_stg_t ('BATCH', NULL, NULL,
                                           NULL, NULL, l_request_id,
                                           NULL, 'EF', 'Error during FTP');
                        update_ctl_stg_t (l_request_id, 'FTP Failed', NULL);
                        ROLLBACK;
                        RETURN;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                               'Exception occured while running ftp program'
                            || SQLERRM);
                        pv_retcode   := 2;
                        ROLLBACK;
                        RETURN;
                END;
            END IF;

            COMMIT;
        END;

        BEGIN
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD ('TRX NUMBER', 10, ' ')
                || CHR (9)
                || RPAD ('BRAND', 10, ' ')
                || CHR (9)
                || RPAD ('ACCOUNT NUMBER', 15, ' ')
                || CHR (9)
                || RPAD ('ERROR MSG', 100, ' '));
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD ('==========', 10, ' ')
                || CHR (9)
                || RPAD ('======', 10, ' ')
                || CHR (9)
                || RPAD ('==============', 15, ' ')
                || CHR (9)
                || RPAD ('=========', 100, ' '));

            FOR v_cur1 IN stg_cur (l_request_id)
            LOOP
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       RPAD (v_cur1.trx_number, 10, ' ')
                    || CHR (9)
                    || RPAD (v_cur1.brand, 10, ' ')
                    || CHR (9)
                    || RPAD (v_cur1.account_number, 15, ' ')
                    || CHR (9)
                    || RPAD (v_cur1.error_msg, 100, ' '));
            END LOOP;
        END;
    END;

    FUNCTION adj_amount_sum (pn_customer_trx_id      NUMBER,
                             pn_receivables_trx_id   NUMBER)
        RETURN NUMBER
    IS
        ln_amount   NUMBER;
    BEGIN
        SELECT SUM (amount)
          INTO ln_amount
          FROM AR_ADJUSTMENTS_ALL
         WHERE     CUSTOMER_TRX_ID = pn_customer_trx_id
               AND RECEIVABLES_TRX_ID = pn_receivables_trx_id;

        RETURN ln_amount;
    END;
END;
/
