--
-- XXDOINT_AR_TRX_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoint_ar_trx_utils
AS
    g_pkg_name                CONSTANT VARCHAR2 (40) := 'XXDOINT_AR_TRX_UTILS';
    g_cdc_substription_name   CONSTANT VARCHAR2 (40) := 'XXDOINT_AR_TRX_SUB';
    g_artrx_update_event      CONSTANT VARCHAR2 (40)
        := 'oracle.apps.xxdo.ar_trx_update' ;

    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN NUMBER:= 10000)
    IS
    BEGIN
        apps.do_debug_tools.msg (p_msg           => p_message,
                                 p_debug_level   => p_debug_level);
    END;

    FUNCTION in_conc_request
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN apps.fnd_global.conc_request_id != -1;
    END;

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.purge_batch';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            SAVEPOINT before_artrx_purge;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                msg (' ready to delete batch records.');

                DELETE FROM xxdo.xxdoint_ar_trx_upd_batch
                      WHERE batch_id = p_batch_id;

                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' record(s) from the A/R transaction header batch table.');
                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_artrx_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.purge_old_batches';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_hours_old=' || p_hours_old);

        BEGIN
            SAVEPOINT before_artrx_purge;

            IF p_hours_old IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A time threshhold was not specified.';
            ELSE
                msg (' ready to delete batch records.');

                DELETE FROM xxdo.xxdoint_ar_trx_upd_batch
                      WHERE batch_date < SYSDATE - (p_hours_old / 24);

                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' record(s) from the A/R transaction header batch table.');
                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_artrx_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE process_update_batch (p_raise_event IN VARCHAR2:= 'Y', x_batch_id OUT NUMBER, x_ret_stat OUT VARCHAR2
                                    , x_error_messages OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_proc_name          VARCHAR2 (80) := g_pkg_name || '.process_update_batch';
        l_bus_event_result   VARCHAR2 (20);
        l_cnt                NUMBER;
        l_tot_cnt            NUMBER;

        CURSOR c_batch_output IS
              SELECT haou.NAME AS operating_unit_name, COUNT (1) AS order_count
                FROM xxdo.xxdoint_ar_trx_upd_batch upd_btch
                     INNER JOIN ar.ra_customer_trx_all rcta
                         ON rcta.customer_trx_id = upd_btch.customer_trx_id
                     INNER JOIN hr.hr_all_organization_units haou
                         ON haou.organization_id = rcta.org_id
               WHERE upd_btch.batch_id = x_batch_id
            GROUP BY haou.NAME
            ORDER BY haou.NAME;
    BEGIN
        msg ('+' || l_proc_name);
        msg (' p_raise_event=' || p_raise_event);

        BEGIN
            x_ret_stat         := apps.fnd_api.g_ret_sts_success;
            x_error_messages   := NULL;

            SELECT xxdo.xxdoint_ar_trx_upd_btch_s.NEXTVAL
              INTO x_batch_id
              FROM DUAL;

            msg ('  obtained batch_id ' || x_batch_id);
            DBMS_CDC_SUBSCRIBE.extend_window (
                subscription_name => g_cdc_substription_name);
            msg ('  extended CDC window');
            msg ('  beginning inserts.');

            -- A/R Transaction Headers --
            INSERT INTO xxdo.xxdoint_ar_trx_upd_batch (batch_id,
                                                       customer_trx_id)
                SELECT DISTINCT x_batch_id, customer_trx_id
                  FROM (  SELECT cscn$, customer_trx_id
                            FROM apps.ar_xxdoint_ra_customer_trx_v
                           WHERE interface_header_context = 'ORDER ENTRY'
                        GROUP BY cscn$, customer_trx_id
                          HAVING    DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        cust_trx_type_id),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        bill_to_customer_id),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (TO_CHAR (term_id), ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        ship_to_site_use_id),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        bill_to_site_use_id),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        primary_salesrep_id),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    interface_header_context,
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (TO_CHAR (trx_date), ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        ship_date_actual),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (trx_number, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    interface_header_attribute1,
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (purchase_order, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (attribute5, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (invoice_currency_code,
                                                     ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (ship_via, ' '))) >
                                    1) alpha
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_trx_upd_batch btch
                             WHERE     btch.batch_id = x_batch_id
                                   AND btch.customer_trx_id =
                                       alpha.customer_trx_id);

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to RA_CUSTOMER_TRX_ALL.');

            -- A/R Payment Schedules --
            INSERT INTO xxdo.xxdoint_ar_trx_upd_batch (batch_id,
                                                       customer_trx_id)
                SELECT DISTINCT x_batch_id, customer_trx_id
                  FROM (  SELECT v.cscn$, v.customer_trx_id
                            FROM apps.ar_xxdoint_ar_pay_sched_v v
                                 INNER JOIN ar.ra_customer_trx_all rcta
                                     ON     rcta.customer_trx_id =
                                            v.customer_trx_id
                                        AND rcta.interface_header_context =
                                            'ORDER ENTRY'
                        GROUP BY v.cscn$, v.customer_trx_id
                          HAVING    DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        v.amount_due_remaining),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (TO_CHAR (v.due_date),
                                                     ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (v.status, ' '))) >
                                    1) alpha
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_trx_upd_batch btch
                             WHERE     btch.batch_id = x_batch_id
                                   AND btch.customer_trx_id =
                                       alpha.customer_trx_id);

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to AR_PAYMENT_SCHEDDULES_ALL.');

            -- A/R Transaction Lines --
            INSERT INTO xxdo.xxdoint_ar_trx_upd_batch (batch_id,
                                                       customer_trx_id)
                SELECT DISTINCT x_batch_id, customer_trx_id
                  FROM (  SELECT v.cscn$, v.customer_trx_id
                            FROM apps.ar_xxdoint_ra_cust_trx_line_v v
                                 INNER JOIN ar.ra_customer_trx_all rcta
                                     ON     rcta.customer_trx_id =
                                            v.customer_trx_id
                                        AND rcta.interface_header_context =
                                            'ORDER ENTRY'
                        GROUP BY v.cscn$, v.customer_trx_id
                          HAVING    DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    v.interface_line_attribute10,
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        v.inventory_item_id),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (v.line_type, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (v.reason_code, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    v.interface_line_attribute11,
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        v.quantity_credited),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        v.quantity_invoiced),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        v.extended_amount),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (v.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    v.interface_line_attribute6,
                                                    ' '))) >
                                    1) alpha
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_trx_upd_batch btch
                             WHERE     btch.batch_id = x_batch_id
                                   AND btch.customer_trx_id =
                                       alpha.customer_trx_id);

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to RA_CUSTOMER_TRX_LINES_ALL.');
            COMMIT;
            DBMS_CDC_SUBSCRIBE.purge_window (
                subscription_name => g_cdc_substription_name);
            msg ('  purged CDC window');

            IF l_tot_cnt = 0
            THEN
                msg (
                    '  no A/R transaction changes were found.  skipping business event.');
                l_bus_event_result   := 'Not Needed';
            ELSIF NVL (p_raise_event, 'Y') = 'Y'
            THEN
                msg ('  raising business event.');
                raise_business_event (p_batch_id         => x_batch_id,
                                      x_ret_stat         => x_ret_stat,
                                      x_error_messages   => x_error_messages);

                IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                   apps.fnd_api.g_ret_sts_success
                THEN
                    l_bus_event_result   := 'Failed';
                ELSE
                    l_bus_event_result   := 'Raised';
                END IF;
            ELSE
                l_bus_event_result   := 'Skipped';
            END IF;

            IF in_conc_request
            THEN
                apps.fnd_file.put_line (apps.fnd_file.output,
                                        'Batch ID: ' || x_batch_id);
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                    'Business Event: ' || l_bus_event_result);
                apps.fnd_file.put_line (apps.fnd_file.output, ' ');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       RPAD ('Operating Unit', 25, ' ')
                    || LPAD ('Transactions', 15, ' '));
                apps.fnd_file.put_line (apps.fnd_file.output,
                                        RPAD ('=', 40, '='));

                FOR c_output IN c_batch_output
                LOOP
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           RPAD (c_output.operating_unit_name, 25, ' ')
                        || RPAD (c_output.order_count, 15, ' '));
                END LOOP;
            END IF;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                x_batch_id         := NULL;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg (
               'x_batch_id='
            || x_batch_id
            || ', x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || l_proc_name);
    END;

    PROCEDURE raise_business_event (p_batch_id IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.raise_business_event';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            apps.wf_event.RAISE (p_event_name => g_artrx_update_event, p_event_key => TO_CHAR (p_batch_id), p_event_data => NULL
                                 , p_parameters => NULL);
            x_ret_stat         := apps.fnd_api.g_ret_sts_success;
            x_error_messages   := NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg (
               'x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || l_proc_name);
    END;

    PROCEDURE process_update_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_raise_event IN VARCHAR2:= 'Y'
                                         , p_debug_level IN NUMBER:= NULL)
    IS
        l_proc_name   VARCHAR2 (80)
                          := g_pkg_name || '.process_update_batch_conc';
        l_batch_id    NUMBER;
        l_ret         VARCHAR2 (1);
        l_err         VARCHAR2 (2000);
    BEGIN
        IF p_debug_level IS NOT NULL
        THEN
            apps.do_debug_tools.enable_conc_log (p_debug_level);
        ELSIF NVL (
                  TO_NUMBER (
                      apps.fnd_profile.VALUE ('XXDOINT_ARTRX_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (
                    apps.fnd_profile.VALUE ('XXDOINT_ARTRX_DEBUG_LEVEL')));
        END IF;

        msg ('+' || l_proc_name);
        msg (
               'p_raise_event='
            || p_raise_event
            || ', p_debug_level='
            || p_debug_level);
        process_update_batch (p_raise_event => p_raise_event, x_batch_id => l_batch_id, x_ret_stat => l_ret
                              , x_error_messages => l_err);

        IF NVL (l_ret, apps.fnd_api.g_ret_sts_error) =
           apps.fnd_api.g_ret_sts_success
        THEN
            perrproc   := 0;
            psqlstat   := NULL;
        ELSE
            perrproc   := 2;
            psqlstat   := l_err;
        END IF;

        msg ('-' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXCEPTION: ' || SQLERRM);
            perrproc   := 2;
            psqlstat   := SQLERRM;
    END;

    PROCEDURE reprocess_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_hours_old IN NUMBER
                                    , p_debug_level IN NUMBER:= NULL)
    IS
        l_proc_name   VARCHAR2 (80) := g_pkg_name || '.reprocess_batch_conc';
        l_ret         VARCHAR2 (1);
        l_err         VARCHAR2 (2000);
        l_ret_txt     VARCHAR2 (10);

        CURSOR c_batches IS
              SELECT batch_id, COUNT (1) AS trx_count
                FROM xxdo.xxdoint_ar_trx_upd_batch upd_btch
               WHERE batch_date < SYSDATE - (p_hours_old / 24)
            GROUP BY batch_id
            ORDER BY batch_id;
    BEGIN
        IF p_debug_level IS NOT NULL
        THEN
            apps.do_debug_tools.enable_conc_log (p_debug_level);
        ELSIF NVL (
                  TO_NUMBER (
                      apps.fnd_profile.VALUE ('XXDOINT_ARTRX_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (
                    apps.fnd_profile.VALUE ('XXDOINT_ARTRX_DEBUG_LEVEL')));
        END IF;

        msg ('+' || l_proc_name);
        msg (
               'p_hours_old='
            || p_hours_old
            || ', p_debug_level='
            || p_debug_level);
        perrproc   := 0;
        psqlstat   := NULL;
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Hours Back: ' || p_hours_old);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Batch ID', 15, ' ')
            || LPAD ('Transactions', 15, ' ')
            || RPAD ('Messages', 200, ' '));
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('=', 230, '='));

        FOR c_batch IN c_batches
        LOOP
            raise_business_event (p_batch_id         => c_batch.batch_id,
                                  x_ret_stat         => l_ret,
                                  x_error_messages   => l_err);

            IF NVL (l_ret, apps.fnd_api.g_ret_sts_error) !=
               apps.fnd_api.g_ret_sts_success
            THEN
                l_ret_txt   := 'Error';
                perrproc    := 1;
                psqlstat    := 'At least one batch failed to process.';
            ELSE
                l_ret_txt   := 'Success';
            END IF;

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD (c_batch.batch_id, 15, ' ')
                || RPAD (c_batch.trx_count, 15, ' ')
                || RPAD (l_err, 200, ' '));
        END LOOP;

        msg ('-' || l_proc_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('EXCEPTION: ' || SQLERRM);
            perrproc   := 2;
            psqlstat   := SQLERRM;
    END;
END;
/


GRANT EXECUTE ON APPS.XXDOINT_AR_TRX_UTILS TO SOA_INT
/
