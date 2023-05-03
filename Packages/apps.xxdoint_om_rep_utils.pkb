--
-- XXDOINT_OM_REP_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINT_OM_REP_UTILS"
AS
    /****************************************************************************
     * PACKAGE Name    : XXDOINT_INV_PROD_CAT_UTILS
     *
     * Description       : The purpose of this package to capture the CDC
     *                     for Product and raise business for SOA.
     *
     * INPUT Parameters  :
     *
     * OUTPUT Parameters :
     *
     * DEVELOPMENT and MAINTENANCE HISTORY
     *
     * ======================================================================================
     * Date         Version#   Name                    Comments
     * ======================================================================================
     * 04-Apr-2016   1.0                                Initial Version
  * 03-Sep-2021   2.0        Shivanshu Talwar     Modified for 19C Upgrade CCR0009133
     ******************************************************************************************/
    g_pkg_name                  CONSTANT VARCHAR2 (40) := 'XXDOINT_OM_REP_UTILS';
    g_cdc_substription_name     CONSTANT VARCHAR2 (40)
                                             := 'XXDOINT_OM_SALESREP_SUB' ;
    g_rep_assign_update_event   CONSTANT VARCHAR2 (40)
        := 'oracle.apps.xxdo.rep_assign_update' ;

    gn_userid                            NUMBER := apps.fnd_global.user_id;
    gn_resp_id                           NUMBER := apps.fnd_global.resp_id;
    gn_app_id                            NUMBER
                                             := apps.fnd_global.prog_appl_id;
    gn_conc_request_id                   NUMBER
        := apps.fnd_global.conc_request_id;
    g_num_login_id                       NUMBER := fnd_global.login_id;

    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN NUMBER:= 10000)
    IS
    BEGIN
        apps.do_debug_tools.msg (p_msg           => p_message,
                                 p_debug_level   => p_debug_level);
    END;

    --Start Added as part of 2.0
    FUNCTION get_last_conc_req_run (pn_request_id IN NUMBER)
        RETURN DATE
    IS
        ld_last_start_date         DATE;
        ln_concurrent_program_id   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Get Last Conc Req Ren - Start');
        fnd_file.put_line (fnd_file.LOG, 'REQUEST ID:  ' || pn_request_id);

        --Get the Concurrent program for the current running request
        BEGIN
            SELECT concurrent_program_id
              INTO ln_concurrent_program_id
              FROM fnd_concurrent_requests
             WHERE request_id = pn_request_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            --No occurnace running just return NULL
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No program found');
                RETURN NULL;
        END;

        fnd_file.put_line (fnd_file.LOG, 'CC REQ ID : ' || pn_request_id);

        BEGIN
            --Find the last occurance of this request
            SELECT NVL (MAX (actual_start_date), SYSDATE - 1)
              INTO ld_last_start_date
              FROM fnd_concurrent_requests
             WHERE     concurrent_program_id = ln_concurrent_program_id
                   AND ARGUMENT1 IS NOT NULL
                   -- AND ARGUMENT5 IS NULL fixed for performance
                   AND STATUS_CODE = 'C' --Only count completed tasks to not limit data to any erroring out.
                   AND request_id != gn_conc_request_id; --Don't include the current active request
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No prior occurance found');
                ld_last_start_date   :=
                    TRUNC (TO_DATE (SYSDATE - 1, 'YYYY/MM/DD HH24:MI:SS'));
        END get_last_conc_req_run;                        --end as pert of 2.0

        RETURN ld_last_start_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
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
            SAVEPOINT before_rep_purge;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                msg (' ready to delete sales rep assignment batch records.');

                DELETE FROM xxdo.xxdoint_om_rep_assgn_upd_batch
                      WHERE batch_id = p_batch_id;


                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' sales rep assignment record(s) from the batch table.');
                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_rep_purge;
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
            SAVEPOINT before_rep_purge;

            IF p_hours_old IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A time threshhold was not specified.';
            ELSE
                msg (' ready to delete sales rep assignment batch records.');


                DELETE FROM xxdo.xxdoint_om_rep_assgn_upd_batch
                      WHERE batch_date < SYSDATE - (p_hours_old / 24);


                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' sales rep assignment record(s) from the batch table.');
                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_rep_purge;
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
        l_rundate            DATE := NULL;
        ld_rundate           DATE := NULL;
        ld_rundate2          DATE := NULL;
        ld_rundate1          VARCHAR2 (50);

        CURSOR c_batch_output IS
              SELECT upd_batch.brand, haou.NAME AS operating_unit_name, COUNT (DISTINCT customer_id) AS cust_count,
                     COUNT (DISTINCT site_use_id) AS site_count
                FROM xxdo.xxdoint_om_rep_assgn_upd_batch upd_batch
                     INNER JOIN hr.hr_all_organization_units haou
                         ON haou.organization_id = upd_batch.org_id
               WHERE upd_batch.batch_id = x_batch_id
            GROUP BY upd_batch.brand, haou.NAME
            ORDER BY upd_batch.brand, haou.NAME;
    BEGIN
        msg ('+' || l_proc_name);
        msg (' p_raise_event=' || p_raise_event);

        BEGIN
            x_ret_stat         := apps.fnd_api.g_ret_sts_success;
            x_error_messages   := NULL;

            SELECT xxdo.xxdoint_om_rep_assign_batch_s.NEXTVAL
              INTO x_batch_id
              FROM DUAL;

            /* --W.R.T Version 2.0
                     msg ('  obtained batch_id ' || x_batch_id);
                     dbms_cdc_subscribe.extend_window
                                             (subscription_name      => g_cdc_substription_name);
                     msg ('  extended CDC window');
                     */
            msg ('  beginning sales rep assignment inserts.');


            ld_rundate         := get_last_conc_req_run (gn_conc_request_id); --Added as part of 2.0
            ld_rundate1        :=
                TO_CHAR (ld_rundate, 'DD-MON-YYYY HH24:MI:SS'); --Added as part of 2.0

            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Rundate1 : ' || ld_rundate1);

            -- Sales Rep Assignments --
            /*
            INSERT INTO xxdo.xxdoint_om_rep_assgn_upd_batch (batch_id,
                                                             org_id,
                                                             brand,
                                                             site_use_id,
                                                             salesrep_id,
                                                             customer_id)
                  SELECT x_batch_id,
                         rep_assign.org_id,
                         rep_assign.brand,
                         rep_assign.site_use_id,
                         rep_assign.salesrep_id,
                         MAX (rep_assign.customer_id)     AS customer_id
                    FROM apps.rep_xxdoint_rep_assignment_v rep_assign
                   WHERE     NOT EXISTS
                                 (SELECT NULL
                                    FROM xxdo.xxdoint_om_rep_assgn_upd_batch
                                         btch
                                   WHERE     btch.batch_id = x_batch_id
                                         AND btch.org_id = rep_assign.org_id
                                         AND btch.brand = rep_assign.brand
                                         AND btch.site_use_id =
                                             rep_assign.site_use_id
                                         AND btch.salesrep_id =
                                             rep_assign.salesrep_id)
                         AND rep_assign.site_use_id IS NOT NULL --added by stabilization team on 11/08/2016
                         AND rep_assign.salesrep_id IS NOT NULL --added by stabilization team on 11/08/2016
                         AND rep_assign.org_id IS NOT NULL --added by stabilization team on 11/08/2016
                GROUP BY rep_assign.org_id,
                         rep_assign.brand,
                         rep_assign.site_use_id,
                         rep_assign.salesrep_id;
       */


            INSERT INTO xxdo.xxdoint_om_rep_assgn_upd_batch (batch_id,
                                                             org_id,
                                                             brand,
                                                             site_use_id,
                                                             salesrep_id,
                                                             customer_id)
                  SELECT x_batch_id, rep_assign.org_id, rep_assign.brand,
                         rep_assign.site_use_id, rep_assign.salesrep_id, MAX (rep_assign.customer_id) AS customer_id
                    FROM do_custom.do_rep_cust_assignment rep_assign
                   WHERE     NOT EXISTS
                                 (SELECT NULL
                                    FROM xxdo.xxdoint_om_rep_assgn_upd_batch btch
                                   WHERE     btch.batch_id = x_batch_id
                                         AND btch.org_id = rep_assign.org_id
                                         AND btch.brand = rep_assign.brand
                                         AND btch.site_use_id =
                                             rep_assign.site_use_id
                                         AND btch.salesrep_id =
                                             rep_assign.salesrep_id)
                         AND rep_assign.site_use_id IS NOT NULL --added by stabilization team on 11/08/2016
                         AND rep_assign.salesrep_id IS NOT NULL --added by stabilization team on 11/08/2016
                         AND rep_assign.org_id IS NOT NULL --added by stabilization team on 11/08/2016
                         AND rep_assign.last_update_Date >=
                             TO_DATE (ld_rundate1, 'DD-MON-YYYY HH24:MI:SS')
                GROUP BY rep_assign.org_id, rep_assign.brand, rep_assign.site_use_id,
                         rep_assign.salesrep_id;

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to DO_CUSTOM.DO_REP_CUST_ASSIGNMENT.');
            COMMIT;

            /* --W.r.t Version 2.0
            dbms_cdc_subscribe.purge_window
                                    (subscription_name      => g_cdc_substription_name);
            msg ('  purged CDC window');
            */

            IF l_tot_cnt = 0
            THEN
                msg (
                    '  no sales rep assignment changes were found.  skipping business event.');
                l_bus_event_result   := 'Not Needed';
            ELSIF NVL (p_raise_event, 'Y') = 'Y'
            THEN
                msg ('  raising sales rep assignment business event.');
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
                       RPAD ('Brand', 12, ' ')
                    || RPAD ('Operating Unit', 25, ' ')
                    || LPAD ('Customers', 13, ' ')
                    || LPAD ('Sites', 12, ' '));
                apps.fnd_file.put_line (apps.fnd_file.output,
                                        RPAD ('=', 62, '='));

                FOR c_output IN c_batch_output
                LOOP
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           RPAD (c_output.brand, 12, ' ')
                        || RPAD (c_output.operating_unit_name, 25, ' ')
                        || RPAD (c_output.cust_count, 13, ' ')
                        || LPAD (c_output.site_count, 12, ' '));
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
            apps.wf_event.RAISE (p_event_name => g_rep_assign_update_event, p_event_key => TO_CHAR (p_batch_id), p_event_data => NULL
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
                      apps.fnd_profile.VALUE ('XXDOINT_SALESREP_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (
                    apps.fnd_profile.VALUE ('XXDOINT_SALESREP_DEBUG_LEVEL')));
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
              SELECT batch_id, COUNT (DISTINCT customer_id) AS cust_count, COUNT (DISTINCT site_use_id) AS site_count
                FROM xxdo.xxdoint_om_rep_assgn_upd_batch
               WHERE batch_date < SYSDATE - (p_hours_old / 24)
            GROUP BY batch_id
            ORDER BY batch_id;
    BEGIN
        IF p_debug_level IS NOT NULL
        THEN
            apps.do_debug_tools.enable_conc_log (p_debug_level);
        ELSIF NVL (
                  TO_NUMBER (
                      apps.fnd_profile.VALUE ('XXDOINT_SALESREP_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (
                    apps.fnd_profile.VALUE ('XXDOINT_SALESREP_DEBUG_LEVEL')));
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
            || LPAD ('Customers', 13, ' ')
            || LPAD ('Sites', 12, ' ')
            || RPAD ('Result', 10, ' ')
            || RPAD ('Messages', 200, ' '));
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('=', 260, '='));

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
                || RPAD (c_batch.cust_count, 13, ' ')
                || LPAD (c_batch.site_count, 12, ' ')
                || RPAD (l_ret_txt, 10, ' ')
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


GRANT EXECUTE ON APPS.XXDOINT_OM_REP_UTILS TO SOA_INT
/
