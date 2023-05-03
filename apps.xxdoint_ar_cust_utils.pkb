--
-- XXDOINT_AR_CUST_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINT_AR_CUST_UTILS"
AS
    /****************************************************************************
       Modification history:
    *****************************************************************************
        NAME:        xxdoint_ar_cust_utils
        PURPOSE:      MIAN PROCEDURE CONTROL_PROC

        REVISIONS:
        Version        Date        Author           Description
        ---------  ----------  ---------------  ------------------------------------
        1.0         10/14/2015                   1. Created this package body.
        1.1         10/09/2017     INFOSYS       2. Modified for CCR CCR0006627
        2.0         08/01/2021     Shivanshu     3. Modified for 19C Upgrade CCR0009133
        2.1         08/01/2022     Shivanshu     4. Modified for CCR0010087
   *****************************************************************************/


    G_PKG_NAME                CONSTANT VARCHAR2 (40) := 'XXDOINT_AR_CUST_UTILS';
    G_CDC_SUBSTRIPTION_NAME   CONSTANT VARCHAR2 (40)
                                           := 'XXDOINT_AR_CUSTOMER_SUB' ;
    G_CUST_UPDATE_EVENT       CONSTANT VARCHAR2 (40)
        := 'oracle.apps.xxdo.customer_update' ;

    G_EVENT_TYPE_CUST         CONSTANT VARCHAR2 (20) := 'CUSTOMER';
    G_EVENT_TYPE_SITE         CONSTANT VARCHAR2 (20) := 'SITE';
    gn_userid                          NUMBER := apps.fnd_global.user_id;
    gn_resp_id                         NUMBER := apps.fnd_global.resp_id;
    gn_app_id                          NUMBER := apps.fnd_global.prog_appl_id;
    gn_conc_request_id                 NUMBER
                                           := apps.fnd_global.conc_request_id;
    g_num_login_id                     NUMBER := fnd_global.login_id;


    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN NUMBER:= 10000)
    IS
    BEGIN
        IF p_debug_level > 1
        THEN
            apps.fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;

        apps.do_debug_tools.msg (p_msg           => p_message,
                                 p_debug_level   => p_debug_level);
    END;

    FUNCTION in_conc_request
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN apps.fnd_global.conc_request_id != -1;
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

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := G_PKG_NAME || '.purge_batch';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_batch_id=' || p_batch_id);

        BEGIN
            SAVEPOINT before_cust_purge;

            IF p_batch_id IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A batch identifier was not specified.';
            ELSE
                msg (' ready to delete customer batch records.');

                BEGIN                                       --w.r.t CCR0005911
                    INSERT INTO xxdo.xxdoint_ar_cust_upd_batch_img img
                        (SELECT *
                           FROM xxdo.xxdoint_ar_cust_upd_batch
                          WHERE     1 = 1
                                AND TRUNC (BATCH_DATE) = TRUNC (SYSDATE - 1));

                    --w.r.t CCR0005911
                    DELETE FROM
                        xxdo.xxdoint_ar_cust_upd_batch
                          WHERE     1 = 1
                                AND TRUNC (BATCH_DATE) < TRUNC (SYSDATE - 1);


                    DELETE FROM
                        xxdo.xxdoint_ar_cust_upd_batch_img img
                          WHERE batch_date <
                                  SYSDATE
                                - NVL (
                                      fnd_profile.VALUE (
                                          'XXD_CUST_BATCH_PURG_DAYS'),
                                      30);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               ' Purge failed for xxdoint_ar_cust_upd_batch'
                            || SQLERRM);
                END;



                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' customer record(s) from the batch table.');


                msg (' ready to delete customer site batch records.');

                BEGIN                                       --w.r.t CCR0005911
                    INSERT INTO xxdo.xxdoint_ar_cust_site_batch_img
                        (SELECT *
                           FROM xxdo.xxdoint_ar_cust_site_upd_batch
                          WHERE     1 = 1
                                AND TRUNC (BATCH_DATE) = TRUNC (SYSDATE - 1));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                DELETE FROM
                    xxdo.xxdoint_ar_cust_site_upd_batch
                      WHERE     1 = 1
                            AND TRUNC (BATCH_DATE) < TRUNC (SYSDATE - 1)
                            AND NVL (STATUS, 'NV') = 'NV';

                DELETE FROM
                    xxdo.xxdoint_ar_cust_site_upd_batch
                      WHERE batch_date <
                              SYSDATE
                            - NVL (
                                  fnd_profile.VALUE (
                                      'XXD_CUST_BATCH_PURG_DAYS'),
                                  30);

                BEGIN                                       --w.r.t CCR0005911
                    DELETE FROM
                        xxdo.xxdoint_ar_cust_site_batch_img
                          WHERE batch_date <
                                  SYSDATE
                                - NVL (
                                      fnd_profile.VALUE (
                                          'XXD_CUST_BATCH_PURG_DAYS'),
                                      30);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               ' Purge failed for xxdoint_ar_cust_site_upd_batch '
                            || SQLERRM);
                END;

                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' customer site record(s) from the batch table.');


                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_cust_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;

    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := G_PKG_NAME || '.purge_old_batches';
    BEGIN
        msg ('+' || l_proc_name);
        msg ('p_hours_old=' || p_hours_old);

        BEGIN
            SAVEPOINT before_cust_purge;

            IF p_hours_old IS NULL
            THEN
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := 'A time threshhold was not specified.';
            ELSE
                msg (' ready to delete customer batch records.');

                DELETE FROM xxdo.xxdoint_ar_cust_upd_batch
                      WHERE batch_date < SYSDATE - (p_hours_old / 24);

                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' customer record(s) from the batch table.');

                msg (' ready to delete customer site batch records.');

                DELETE FROM xxdo.xxdoint_ar_cust_site_upd_batch
                      WHERE batch_date < SYSDATE - (p_hours_old / 24);

                msg (
                       ' deleted '
                    || SQL%ROWCOUNT
                    || ' customer site record(s) from the batch table.');

                x_ret_stat         := apps.fnd_api.g_ret_sts_success;
                x_error_messages   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK TO before_cust_purge;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg ('-' || l_proc_name);
    END;



    PROCEDURE process_update_batch (p_raise_event      IN     VARCHAR2 := 'Y',
                                    x_cust_batch_id       OUT NUMBER,
                                    x_site_batch_id       OUT NUMBER,
                                    x_ret_stat            OUT VARCHAR2,
                                    x_error_messages      OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_proc_name          VARCHAR2 (80) := G_PKG_NAME || '.process_update_batch';
        l_bus_event_result   VARCHAR2 (20);
        l_cnt                NUMBER;
        l_tot_cnt            NUMBER;
        ln_site_batch_cnt    NUMBER := 0;
        l_rundate            DATE := NULL;
        ld_rundate           DATE := NULL;
        ld_rundate2          DATE := NULL;
        ld_rundate1          VARCHAR2 (50);

        CURSOR c_batch_output IS
              SELECT haou.name AS operating_unit_name, SUM (cust_count) AS cust_count, SUM (site_count) AS site_count
                FROM (  SELECT org_id, COUNT (1) AS cust_count, 0 AS site_count
                          FROM xxdo.xxdoint_ar_cust_upd_batch
                         WHERE batch_id = x_cust_batch_id
                      GROUP BY org_id
                      UNION ALL
                        SELECT org_id, 0 AS cust_count, COUNT (1) AS site_count
                          FROM xxdo.xxdoint_ar_cust_site_upd_batch
                         WHERE batch_id = x_site_batch_id
                      GROUP BY org_id) batch_cnts
                     INNER JOIN hr.hr_all_organization_units haou
                         ON haou.organization_id = batch_cnts.org_id
            GROUP BY haou.name
            ORDER BY haou.name;
    BEGIN
        msg ('+' || l_proc_name);
        msg (' p_raise_event=' || p_raise_event);

        BEGIN
            x_ret_stat         := apps.fnd_api.g_ret_sts_success;
            x_error_messages   := NULL;

            SELECT xxdo.xxdoint_ar_cust_batch_s.NEXTVAL
              INTO x_cust_batch_id
              FROM DUAL;

            SELECT xxdo.xxdoint_ar_cust_batch_s.NEXTVAL
              INTO x_site_batch_id
              FROM DUAL;

            msg (
                   '  obtained customer batch_id '
                || x_cust_batch_id
                || ', site batch_id '
                || x_site_batch_id);

            ld_rundate         := get_last_conc_req_run (gn_conc_request_id); --Added as part of 2.0
            ld_rundate1        :=
                TO_CHAR (ld_rundate, 'DD-MON-YYYY HH24:MI:SS'); --Added as part of 2.0

            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Rundate1 : ' || ld_rundate1);

            --   DBMS_CDC_SUBSCRIBE.EXTEND_WINDOW ( subscription_name => G_CDC_SUBSTRIPTION_NAME); --completed as part of 2.0
            msg ('  extended CDC window');


            msg ('  beginning customer inserts.');

            -- Customers --
            /*
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
               SELECT DISTINCT x_cust_batch_id, alpha.customer_id, hcasa.org_id
                 FROM (  SELECT cust.cscn$, cust.cust_account_id AS customer_id
                           FROM apps.CUST_XXDOINT_HZ_CUST_ACCOUNT_V cust
                       GROUP BY cust.cscn$, cust.cust_account_id
                         HAVING    DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.account_name, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (DISTINCT NVL (cust.status, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.attribute2, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.attribute5, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.attribute6, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.attribute7, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.attribute8, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.attribute10, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.attribute12, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.attribute17, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.attribute18, ' '))) >
                                      1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (cust.sales_channel_code,
                                                       ' '))) > 1
                                OR DECODE (
                                      MAX (cust.operation$),
                                      'I ', 2,
                                      'D ', 2,
                                      COUNT (
                                         DISTINCT NVL (TO_CHAR (cust.party_id),
                                                       ' '))) > 1) alpha
                      INNER JOIN
                      ar.hz_cust_acct_sites_all hcasa
                         ON     hcasa.cust_account_id = alpha.customer_id
                            AND hcasa.status = 'A'
                WHERE NOT EXISTS
                             (SELECT NULL
                                FROM xxdo.xxdoint_ar_cust_upd_batch btch
                               WHERE     btch.batch_id = x_cust_batch_id
                                     AND btch.customer_id = alpha.customer_id
                                     AND btch.org_id = hcasa.org_id);*/



            --START Added as part of 2.0
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT x_cust_batch_id, customer_id, org_id
                  FROM (SELECT cust.cust_account_id AS customer_id, hcasa.org_id org_id
                          FROM hz_cust_accounts cust, ar.hz_cust_acct_sites_all hcasa
                         WHERE     hcasa.cust_account_id =
                                   cust.cust_account_id
                               AND hcasa.status = 'A'
                               AND cust.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_cust_batch_id
                                               AND btch.customer_id =
                                                   cust.cust_account_id
                                               AND btch.org_id = hcasa.org_id));

            --END Added as part of 2.0


            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to HZ_CUST_ACCOUNTS.');

            -- Parties --
            /*
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT
                       x_cust_batch_id, hca.cust_account_id, hcasa.org_id
                  FROM (  SELECT party.cscn$, party.party_id
                            FROM apps.CUST_XXDOINT_HZ_PARTIES_V party
                        GROUP BY party.cscn$, party.party_id
                          HAVING DECODE (
                                     MAX (party.operation$),
                                     'I ', 2,
                                     'D ', 2,
                                     COUNT (
                                         DISTINCT NVL (party.party_name, ' '))) >
                                 1) alpha
                       INNER JOIN ar.hz_cust_accounts hca
                           ON hca.party_id = alpha.party_id
                       INNER JOIN ar.hz_cust_acct_sites_all hcasa
                           ON     hcasa.cust_account_id = hca.cust_account_id
                              AND hcasa.status = 'A'
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_cust_upd_batch btch
                             WHERE     btch.batch_id = x_cust_batch_id
                                   AND btch.customer_id = hca.cust_account_id
                                   AND btch.org_id = hcasa.org_id);*/

            --START Added as part of 2.0
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT x_cust_batch_id, cust_account_id, org_id
                  FROM (SELECT party.party_id, hca.cust_account_id, hcasa.org_id
                          FROM apps.hz_parties party, ar.hz_cust_accounts hca, ar.hz_cust_acct_sites_all hcasa
                         WHERE     hca.party_id = party.party_id
                               AND hcasa.cust_account_id =
                                   hca.cust_account_id
                               AND hcasa.status = 'A'
                               AND party.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_cust_batch_id
                                               AND btch.customer_id =
                                                   hca.cust_account_id
                                               AND btch.org_id = hcasa.org_id));

            --END Added as part of 2.0

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to HZ_PARTIES.');

            -- Customer Profiles --
            /*
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT
                       x_cust_batch_id, alpha.customer_id, hcasa.org_id
                  FROM (  SELECT prof.cscn$,
                                 prof.cust_account_id     AS customer_id
                            FROM apps.CUST_XXDOINT_HZ_CUST_PROF_V prof
                           WHERE prof.site_use_id IS NULL
                        GROUP BY prof.cscn$, prof.cust_account_id
                          HAVING    DECODE (
                                        MAX (prof.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (
                                                        profile_class_id),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (prof.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (TO_CHAR (collector_id),
                                                     ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (prof.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (credit_checking, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (prof.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (
                                                    TO_CHAR (standard_terms),
                                                    ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (prof.operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (status, ' '))) >
                                    1) alpha
                       INNER JOIN ar.hz_cust_acct_sites_all hcasa
                           ON     hcasa.cust_account_id = alpha.customer_id
                              AND hcasa.status = 'A'
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_cust_upd_batch btch
                             WHERE     btch.batch_id = x_cust_batch_id
                                   AND btch.customer_id = alpha.customer_id
                                   AND btch.org_id = hcasa.org_id);
           */

            --START Added as part of 2.0
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT x_cust_batch_id, customer_id, org_id
                  FROM (SELECT hcasa.org_id, prof.cust_account_id AS customer_id
                          FROM ar.hz_customer_profiles prof, ar.hz_cust_acct_sites_all hcasa
                         WHERE     prof.site_use_id IS NULL
                               AND hcasa.cust_account_id =
                                   prof.cust_account_id
                               AND hcasa.status = 'A'
                               AND prof.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_cust_batch_id
                                               AND btch.customer_id =
                                                   prof.cust_account_id
                                               AND btch.org_id = hcasa.org_id));

            --END Added as part of 2.0
            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to HZ_CUSTOMER_PROFILES.');

            -- Customer Profile Classes --f
            /*
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT
                       x_cust_batch_id, hcp.cust_account_id, hcasa.org_id
                  FROM (  SELECT cscn$, profile_class_id
                            FROM apps.CUST_XXDOINT_HZ_CUST_PRF_CLS_V
                        GROUP BY cscn$, profile_class_id
                          HAVING DECODE (MAX (operation$),
                                         'I ', 2,
                                         'D ', 2,
                                         COUNT (DISTINCT NVL (name, ' '))) >
                                 1) alpha
                       INNER JOIN ar.hz_customer_profiles hcp
                           ON     hcp.profile_class_id =
                                  alpha.profile_class_id
                              AND hcp.status = 'A'
                       INNER JOIN ar.hz_cust_acct_sites_all hcasa
                           ON     hcasa.cust_account_id = hcp.cust_account_id
                              AND hcasa.status = 'A'
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_cust_upd_batch btch
                             WHERE     btch.batch_id = x_cust_batch_id
                                   AND btch.customer_id = hcp.cust_account_id
                                   AND btch.org_id = hcasa.org_id); */

            --START Added as part of 2.0
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT x_cust_batch_id, cust_account_id, org_id
                  FROM (SELECT hcpc.profile_class_id, hcp.cust_account_id, org_id
                          FROM ar.hz_cust_profile_classes hcpc, ar.hz_customer_profiles hcp, ar.hz_cust_acct_sites_all hcasa
                         WHERE     hcp.status = 'A'
                               AND hcasa.cust_account_id =
                                   hcp.cust_account_id
                               AND hcasa.status = 'A'
                               AND hcp.profile_class_id =
                                   hcpc.profile_class_id
                               AND hcpc.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_cust_batch_id
                                               AND btch.customer_id =
                                                   hcp.cust_account_id
                                               AND btch.org_id = hcasa.org_id));

            --END Added as part of 2.0

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to HZ_CUST_PROFILE_CLASSES.');

            -- Collectors --
            /*
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT
                       x_cust_batch_id, hcp.cust_account_id, hcasa.org_id
                  FROM (  SELECT cscn$, collector_id
                            FROM apps.CUST_XXDOINT_AR_COLLECTORS_V
                        GROUP BY cscn$, collector_id
                          HAVING DECODE (MAX (operation$),
                                         'I ', 2,
                                         'D ', 2,
                                         COUNT (DISTINCT NVL (name, ' '))) >
                                 1) alpha
                       INNER JOIN ar.hz_customer_profiles hcp
                           ON     hcp.collector_id = alpha.collector_id
                              AND hcp.status = 'A'
                       INNER JOIN ar.hz_cust_acct_sites_all hcasa
                           ON     hcasa.cust_account_id = hcp.cust_account_id
                              AND hcasa.status = 'A'
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_cust_upd_batch btch
                             WHERE     btch.batch_id = x_cust_batch_id
                                   AND btch.customer_id = hcp.cust_account_id
                                   AND btch.org_id = hcasa.org_id);
           */

            --START Added as part of 2.0
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT x_cust_batch_id, cust_account_id, org_id
                  FROM (SELECT ac.collector_id, hcp.cust_account_id, hcasa.org_id
                          FROM apps.ar_collectors ac, ar.hz_customer_profiles hcp, ar.hz_cust_acct_sites_all hcasa
                         WHERE     hcp.collector_id = ac.collector_id
                               AND hcp.status = 'A'
                               AND hcasa.cust_account_id =
                                   hcp.cust_account_id
                               AND hcasa.status = 'A'
                               AND ac.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_cust_batch_id
                                               AND btch.customer_id =
                                                   hcp.cust_account_id
                                               AND btch.org_id = hcasa.org_id));

            --END Added as part of 2.0

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to AR_COLLECTORS.');

            msg ('  beginning customer site inserts.');

            -- Customer Site Use --
            /*
            INSERT INTO xxdo.xxdoint_ar_cust_site_upd_batch (batch_id,
                                                             site_use_id,
                                                             org_id)
                SELECT DISTINCT x_site_batch_id, site_use_id, org_id
                  FROM (  SELECT cscn$, site_use_id, org_id
                            FROM apps.CUST_XXDOINT_HZ_SITE_USE_V
                           WHERE site_use_code IN
                                     ('BILL_TO', 'SHIP_TO', 'DELIVER_TO')
                        GROUP BY cscn$, site_use_id, org_id
                          HAVING    DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (location, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (primary_flag, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (status, ' '))) >
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
                                        COUNT (DISTINCT NVL (tax_code, ' '))) >
                                    1) alpha
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_cust_site_upd_batch btch
                             WHERE     btch.batch_id = x_site_batch_id
                                   AND btch.site_use_id = alpha.site_use_id
                                   AND btch.org_id = alpha.org_id);
           */

            --START Added as part of 2.0
            INSERT INTO xxdo.xxdoint_ar_cust_site_upd_batch (batch_id,
                                                             site_use_id,
                                                             org_id)
                SELECT DISTINCT x_site_batch_id, site_use_id, org_id
                  FROM (SELECT site_use_id, org_id
                          FROM HZ_CUST_SITE_USES_ALL hcsua
                         WHERE     site_use_code IN
                                       ('BILL_TO', 'SHIP_TO', 'DELIVER_TO')
                               AND hcsua.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_site_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_site_batch_id
                                               AND btch.site_use_id =
                                                   hcsua.site_use_id
                                               AND btch.org_id = hcsua.org_id));

            --END Added as part of 2.0


            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to HZ_CUST_SITE_USES.');


            -- Customer Account Sites --
            /*
            INSERT INTO xxdo.xxdoint_ar_cust_site_upd_batch (batch_id,
                                                             site_use_id,
                                                             org_id)
                SELECT DISTINCT
                       x_site_batch_id, hcsua.site_use_id, hcsua.org_id
                  FROM (  SELECT cscn$, cust_acct_site_id
                            FROM apps.CUST_XXDOINT_HZ_ACCT_SITES_V
                        GROUP BY cscn$, cust_acct_site_id
                          HAVING    DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (TO_CHAR (party_site_id),
                                                     ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (status, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (attribute1, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (attribute2, ' '))) >
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
                                            DISTINCT NVL (attribute6, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (attribute7, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (attribute8, ' '))) >
                                    1) alpha
                       INNER JOIN ar.hz_cust_site_uses_all hcsua
                           ON     hcsua.cust_acct_site_id =
                                  alpha.cust_acct_site_id
                              AND hcsua.site_use_code IN
                                      ('BILL_TO', 'SHIP_TO', 'DELIVER_TO')
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_cust_site_upd_batch btch
                             WHERE     btch.batch_id = x_site_batch_id
                                   AND btch.site_use_id = hcsua.site_use_id
                                   AND btch.org_id = hcsua.org_id);
           */

            INSERT INTO xxdo.xxdoint_ar_cust_site_upd_batch (batch_id,
                                                             site_use_id,
                                                             org_id)
                SELECT DISTINCT x_site_batch_id, site_use_id, org_id
                  FROM (SELECT hcsa.cust_acct_site_id, hcsua.site_use_id, hcsua.org_id
                          FROM hz_cust_acct_sites_all hcsa, ar.hz_cust_site_uses_all hcsua
                         WHERE     hcsua.cust_acct_site_id =
                                   hcsa.cust_acct_site_id
                               AND hcsua.site_use_code IN
                                       ('BILL_TO', 'SHIP_TO', 'DELIVER_TO')
                               AND hcsa.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_site_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_site_batch_id
                                               AND btch.site_use_id =
                                                   hcsua.site_use_id
                                               AND btch.org_id = hcsua.org_id));

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to HZ_CUST_ACCT_SITES_ALL.');

            -- Party Sites --
            /*
            INSERT INTO xxdo.xxdoint_ar_cust_site_upd_batch (batch_id,
                                                             site_use_id,
                                                             org_id)
                SELECT DISTINCT
                       x_site_batch_id, hcsua.site_use_id, hcsua.org_id
                  FROM (  SELECT cscn$, party_site_id
                            FROM apps.CUST_XXDOINT_HZ_PARTY_SITES_V
                        GROUP BY cscn$, party_site_id
                          HAVING DECODE (
                                     MAX (operation$),
                                     'I ', 2,
                                     'D ', 2,
                                     COUNT (
                                         DISTINCT
                                             NVL (TO_CHAR (location_id), ' '))) >
                                 1) alpha
                       INNER JOIN ar.hz_cust_acct_sites_all hcasa
                           ON hcasa.party_site_id = alpha.party_site_id
                       INNER JOIN ar.hz_cust_site_uses_all hcsua
                           ON     hcsua.cust_acct_site_id =
                                  hcasa.cust_acct_site_id
                              AND hcsua.site_use_code IN
                                      ('BILL_TO', 'SHIP_TO', 'DELIVER_TO')
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_cust_site_upd_batch btch
                             WHERE     btch.batch_id = x_site_batch_id
                                   AND btch.site_use_id = hcsua.site_use_id
                                   AND btch.org_id = hcsua.org_id);
           */

            INSERT INTO xxdo.xxdoint_ar_cust_site_upd_batch (batch_id,
                                                             site_use_id,
                                                             org_id)
                SELECT DISTINCT x_site_batch_id, site_use_id, org_id
                  FROM (SELECT hps.party_site_id, hcsua.site_use_id, hcsua.org_id
                          FROM HZ_PARTY_SITES hps, ar.hz_cust_acct_sites_all hcasa, ar.hz_cust_site_uses_all hcsua
                         WHERE     hcasa.party_site_id = hps.party_site_id
                               AND hcsua.cust_acct_site_id =
                                   hcasa.cust_acct_site_id
                               AND hcsua.site_use_code IN
                                       ('BILL_TO', 'SHIP_TO', 'DELIVER_TO')
                               AND hps.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_site_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_site_batch_id
                                               AND btch.site_use_id =
                                                   hcsua.site_use_id
                                               AND btch.org_id = hcsua.org_id));

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to HZ_PARTY_SITES.');

            -- Locations --
            /*
            INSERT INTO xxdo.xxdoint_ar_cust_site_upd_batch (batch_id,
                                                             site_use_id,
                                                             org_id)
                SELECT DISTINCT
                       x_site_batch_id, hcsua.site_use_id, hcsua.org_id
                  FROM (  SELECT cscn$, location_id
                            FROM apps.CUST_XXDOINT_HZ_LOCATIONS_V
                        GROUP BY cscn$, location_id
                          HAVING    DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (address_style, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (address1, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (address2, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (address3, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (address4, ' '))) >
                                    1
                                 OR DECODE (MAX (operation$),
                                            'I ', 2,
                                            'D ', 2,
                                            COUNT (DISTINCT NVL (city, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (state, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (province, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT NVL (postal_code, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (county, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (DISTINCT NVL (country, ' '))) >
                                    1
                                 OR DECODE (
                                        MAX (operation$),
                                        'I ', 2,
                                        'D ', 2,
                                        COUNT (
                                            DISTINCT
                                                NVL (TO_CHAR (timezone_id),
                                                     ' '))) >
                                    1) alpha
                       INNER JOIN ar.hz_party_sites hps
                           ON hps.location_id = alpha.location_id
                       INNER JOIN ar.hz_cust_acct_sites_all hcasa
                           ON hcasa.party_site_id = hps.party_site_id
                       INNER JOIN ar.hz_cust_site_uses_all hcsua
                           ON     hcsua.cust_acct_site_id =
                                  hcasa.cust_acct_site_id
                              AND hcsua.site_use_code IN
                                      ('BILL_TO', 'SHIP_TO', 'DELIVER_TO')
                 WHERE NOT EXISTS
                           (SELECT NULL
                              FROM xxdo.xxdoint_ar_cust_site_upd_batch btch
                             WHERE     btch.batch_id = x_site_batch_id
                                   AND btch.site_use_id = hcsua.site_use_id
                                   AND btch.org_id = hcsua.org_id);
           */

            INSERT INTO xxdo.xxdoint_ar_cust_site_upd_batch (batch_id,
                                                             site_use_id,
                                                             org_id)
                SELECT DISTINCT x_site_batch_id, site_use_id, org_id
                  FROM (SELECT hl.location_id, hcsua.site_use_id, hcsua.org_id
                          FROM hz_locations hl, ar.hz_party_sites hps, ar.hz_cust_acct_sites_all hcasa,
                               ar.hz_cust_site_uses_all hcsua
                         WHERE     hcsua.cust_acct_site_id =
                                   hcasa.cust_acct_site_id
                               AND hcasa.party_site_id = hps.party_site_id
                               AND hps.location_id = hl.location_id
                               AND hcsua.site_use_code IN
                                       ('BILL_TO', 'SHIP_TO', 'DELIVER_TO')
                               AND hl.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_site_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_site_batch_id
                                               AND btch.site_use_id =
                                                   hcsua.site_use_id
                                               AND btch.org_id = hcsua.org_id));

            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to HZ_LOCATIONS.');



            --START Added as part of 2.1
            INSERT INTO xxdo.xxdoint_ar_cust_upd_batch (batch_id,
                                                        customer_id,
                                                        org_id)
                SELECT DISTINCT x_cust_batch_id, customer_id, org_id
                  FROM (SELECT DISTINCT cust.cust_account_id AS customer_id, hcasa.org_id org_id
                          FROM hz_cust_accounts cust, ar.hz_cust_acct_sites_all hcasa, apps.fnd_lookup_values_vl flv
                         WHERE     hcasa.cust_account_id =
                                   cust.cust_account_id
                               AND hcasa.status = 'A'
                               AND flv.meaning = cust.account_number
                               AND lookup_type =
                                   'XXD_ONT_SHARED_BULK_CUSTOMER'
                               AND flv.enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (
                                                       flv.start_date_active,
                                                       SYSDATE - 1)
                                               AND NVL (flv.end_date_active,
                                                        SYSDATE + 1)
                               AND flv.last_update_Date >=
                                   TO_DATE (ld_rundate1,
                                            'DD-MON-YYYY HH24:MI:SS')
                               AND NOT EXISTS
                                       (SELECT NULL
                                          FROM xxdo.xxdoint_ar_cust_upd_batch btch
                                         WHERE     btch.batch_id =
                                                   x_cust_batch_id
                                               AND btch.customer_id =
                                                   cust.cust_account_id
                                               AND btch.org_id = hcasa.org_id));

            --END Added as part of 2.1


            l_cnt              := SQL%ROWCOUNT;
            l_tot_cnt          := l_tot_cnt + l_cnt;
            msg (
                   '  inserted '
                || l_cnt
                || ' record(s) into the batch table for changes to HZ_CUST_ACCOUNTS.');

            --W.r.t Version 1.1 CCR0006627


            BEGIN
                UPDATE xxdo.xxdoint_ar_cust_site_upd_batch bat
                   SET status = 'NR', batch_id = gn_conc_request_id, last_update_by = 'CDC',
                       last_updated_date = SYSDATE
                 WHERE     1 = 1
                       AND batch_id = x_site_batch_id
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM hz_cust_acct_relate_all rel, hz_cust_site_uses_all hs, hz_cust_acct_sites_all hc
                                 WHERE     hc.cust_acct_site_id =
                                           hs.cust_acct_site_id
                                       AND related_cust_account_id =
                                           hc.cust_account_id
                                       AND hs.site_use_code IN
                                               ('BILL_TO', 'SHIP_TO')
                                       AND bat.site_use_id = hs.site_use_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg ('  failed in updatinng records to NR.');
            END;


            BEGIN
                UPDATE xxdo.xxdoint_ar_cust_site_upd_batch bat
                   SET status = 'NV', batch_id = gn_conc_request_id, last_update_by = 'CDC',
                       last_updated_date = SYSDATE
                 WHERE     1 = 1
                       AND batch_id = x_site_batch_id
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM fnd_lookup_values
                                 WHERE     TO_NUMBER (description) = org_id
                                       AND lookup_type = 'XXD_CFG_HBS_SITES'
                                       AND language = 'US');
            EXCEPTION
                WHEN OTHERS
                THEN
                    msg ('  failed in updatinng records to NV.');
            END;

            --End W.r.t Version 1.1 CCR0006627

            COMMIT;

            BEGIN                             ----W.r.t Version 1.1 CCR0006627
                SELECT COUNT (1)
                  INTO ln_site_batch_cnt
                  FROM xxdo.xxdoint_ar_cust_site_upd_batch
                 WHERE BATCH_ID = x_site_batch_id AND STATUS IS NULL;
            END;

            --  DBMS_CDC_SUBSCRIBE.PURGE_WINDOW (subscription_name => G_CDC_SUBSTRIPTION_NAME); --commented as part of 2.0
            msg ('  purged CDC window');

            IF l_tot_cnt = 0
            THEN
                msg (
                    '  no customer changes were found.  skipping business event.');
                l_bus_event_result   := 'Not Needed';
            ELSIF NVL (p_raise_event, 'Y') = 'Y'
            THEN
                msg ('  raising customer business event.');
                raise_business_event (p_batch_id => x_cust_batch_id, p_event_type => G_EVENT_TYPE_CUST, x_ret_stat => x_ret_stat
                                      , x_error_messages => x_error_messages);


                IF ln_site_batch_cnt > 0        --W.r.t Version 1.1 CCR0006627
                THEN
                    IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                       apps.fnd_api.g_ret_sts_success
                    THEN
                        l_bus_event_result   := 'Failed';
                    ELSE
                        DBMS_LOCK.sleep (60);
                        msg ('  raising site business event.');
                        raise_business_event (
                            p_batch_id         => x_site_batch_id,
                            p_event_type       => G_EVENT_TYPE_SITE,
                            x_ret_stat         => x_ret_stat,
                            x_error_messages   => x_error_messages);

                        IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
                           apps.fnd_api.g_ret_sts_success
                        THEN
                            l_bus_event_result   := 'Failed';
                        ELSE
                            l_bus_event_result   := 'Raised';
                        END IF;
                    END IF;
                END IF;                                                     --
            ELSE
                l_bus_event_result   := 'Skipped';
            END IF;

            IF in_conc_request
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                    'Customer Batch ID: ' || x_cust_batch_id);
                apps.fnd_file.put_line (apps.fnd_file.output,
                                        'Site Batch ID: ' || x_site_batch_id);
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                    'Business Event: ' || l_bus_event_result);
                apps.fnd_file.put_line (apps.fnd_file.output, ' ');
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       RPAD ('Operating Unit', 25, ' ')
                    || LPAD ('Customers', 13, ' ')
                    || LPAD ('Sites', 12, ' '));
                apps.fnd_file.put_line (apps.fnd_file.output,
                                        RPAD ('=', 50, '='));

                FOR c_output IN c_batch_output
                LOOP
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           RPAD (c_output.operating_unit_name, 25, ' ')
                        || RPAD (c_output.cust_count, 13, ' ')
                        || LPAD (c_output.site_count, 12, ' '));
                END LOOP;
            END IF;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                ROLLBACK;
                x_cust_batch_id    := NULL;
                x_site_batch_id    := NULL;
                x_ret_stat         := apps.fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
                msg ('  EXCEPTION: ' || SQLERRM);
        END;

        msg (
               'x_cust_batch_id='
            || x_cust_batch_id
            || ', x_site_batch_id='
            || x_site_batch_id
            || ', x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        msg ('-' || l_proc_name);
    END;


    PROCEDURE raise_business_event (p_batch_id IN NUMBER, p_event_type IN VARCHAR2, x_ret_stat OUT VARCHAR2
                                    , x_error_messages OUT VARCHAR2)
    IS
        l_proc_name   VARCHAR2 (80) := G_PKG_NAME || '.raise_business_event';
    BEGIN
        msg ('+' || l_proc_name);
        msg (
            'p_batch_id=' || p_batch_id || ', p_event_type=' || p_event_type);

        BEGIN
            apps.wf_event.raise (p_event_name => G_CUST_UPDATE_EVENT, p_event_key => TO_CHAR (p_batch_id), p_event_data => p_event_type
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
        l_proc_name       VARCHAR2 (80)
                              := G_PKG_NAME || '.process_update_batch_conc';
        l_cust_batch_id   NUMBER;
        l_site_batch_id   NUMBER;
        l_ret             VARCHAR2 (1);
        l_err             VARCHAR2 (2000);
    BEGIN
        IF p_debug_level IS NOT NULL
        THEN
            apps.do_debug_tools.enable_conc_log (p_debug_level);
        ELSIF NVL (
                  TO_NUMBER (
                      apps.fnd_profile.VALUE ('XXDOINT_CUST_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (
                    apps.fnd_profile.VALUE ('XXDOINT_CUST_DEBUG_LEVEL')));
        END IF;

        msg ('+' || l_proc_name);
        msg (
               'p_raise_event='
            || p_raise_event
            || ', p_debug_level='
            || p_debug_level);
        process_update_batch (p_raise_event => p_raise_event, x_cust_batch_id => l_cust_batch_id, x_site_batch_id => l_site_batch_id
                              , x_ret_stat => l_ret, x_error_messages => l_err);

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

    --start W.r.t Version 1.1 CCR0006627
    PROCEDURE process_relationship_batch (
        psqlstat               OUT VARCHAR2,
        perrproc               OUT VARCHAR2,
        pv_reprocess_type   IN     VARCHAR2,
        pn_batch_id         IN     NUMBER,
        pn_num_days         IN     NUMBER)
    IS
        l_proc_name           VARCHAR2 (80)
                                  := G_PKG_NAME || '.process_relationship_batch';
        l_ret                 VARCHAR2 (1);
        x_error_messages      VARCHAR2 (2000);
        l_ret_txt             VARCHAR2 (10);
        x_ret_stat            VARCHAR2 (2000);
        lv_status             VARCHAR2 (10);
        lv_bus_event_result   VARCHAR2 (100);
        ln_records            NUMBER := 0;
        ln_del_records        NUMBER := 0;
    BEGIN
        IF pv_reprocess_type = 'CUST RELATIONSHIP'
        THEN
            lv_status    := 'NR';

            UPDATE xxdo.xxdoint_ar_cust_site_upd_batch bat
               SET status = NULL, batch_id = gn_conc_request_id, last_update_by = gn_userid,
                   last_updated_date = SYSDATE
             WHERE     1 = 1
                   AND NVL (status, 'X') = lv_status
                   AND TRUNC (batch_date) >
                       TRUNC (SYSDATE) - NVL (pn_num_days, 10)
                   AND EXISTS
                           (SELECT 1
                              FROM hz_cust_acct_relate_all rel, hz_cust_site_uses_all hs, hz_cust_acct_sites_all hc
                             WHERE     hc.cust_acct_site_id =
                                       hs.cust_acct_site_id
                                   AND related_cust_account_id =
                                       hc.cust_account_id
                                   AND bat.site_use_id = hs.site_use_id);

            ln_records   := SQL%ROWCOUNT;
        ELSIF pv_reprocess_type = 'PORTAL EXCEPTION'
        THEN
            lv_status    := 'E';


            BEGIN
                DELETE FROM
                    xxdo.xxdoint_ar_cust_site_upd_batch A
                      WHERE a.ROWID >
                            ANY (SELECT B.ROWID
                                   FROM xxdo.xxdoint_ar_cust_site_upd_batch B
                                  WHERE A.SITE_USE_ID = B.SITE_USE_ID);

                ln_del_records   := SQL%ROWCOUNT;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'duplicate records deleted ' || ln_del_records);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            UPDATE xxdo.xxdoint_ar_cust_site_upd_batch bat
               SET status = NULL, batch_id = gn_conc_request_id, last_update_by = gn_userid,
                   last_updated_date = SYSDATE
             WHERE     1 = 1
                   AND NVL (status, 'X') = lv_status
                   AND TRUNC (batch_date) >
                       TRUNC (SYSDATE) - NVL (pn_num_days, 10)
                   AND EXISTS
                           (SELECT 1
                              FROM hz_cust_acct_relate_all rel, hz_cust_site_uses_all hs, hz_cust_acct_sites_all hc
                             WHERE     hc.cust_acct_site_id =
                                       hs.cust_acct_site_id
                                   AND related_cust_account_id =
                                       hc.cust_account_id
                                   AND bat.site_use_id = hs.site_use_id);

            ln_records   := SQL%ROWCOUNT;
        ELSIF pv_reprocess_type = 'BATCH'
        THEN
            UPDATE xxdo.xxdoint_ar_cust_site_upd_batch bat
               SET status = NULL, batch_id = gn_conc_request_id, last_update_by = gn_userid,
                   last_updated_date = SYSDATE
             WHERE     1 = 1
                   -- AND NVL (status, 'X') IN ('E', 'NR')
                   AND TRUNC (batch_date) >
                       TRUNC (SYSDATE) - NVL (pn_num_days, 10)
                   AND batch_id = pn_batch_id
                   AND EXISTS
                           (SELECT 1
                              FROM hz_cust_acct_relate_all rel, hz_cust_site_uses_all hs, hz_cust_acct_sites_all hc
                             WHERE     hc.cust_acct_site_id =
                                       hs.cust_acct_site_id
                                   AND related_cust_account_id =
                                       hc.cust_account_id
                                   AND bat.site_use_id = hs.site_use_id);

            ln_records   := SQL%ROWCOUNT;
        ELSIF pv_reprocess_type = 'PURGE'
        THEN
            purge_batch (p_batch_id         => gn_conc_request_id,
                         x_ret_stat         => x_ret_stat,
                         x_error_messages   => x_error_messages);
        END IF;

        COMMIT;
        msg (
               ' updated '
            || ln_records
            || ' customer record(s) from the current batch.');



        IF ln_records > 0
        THEN
            msg ('  raising customer business event.');
            raise_business_event (p_batch_id => gn_conc_request_id, p_event_type => G_EVENT_TYPE_SITE, x_ret_stat => x_ret_stat
                                  , x_error_messages => x_error_messages);

            IF NVL (x_ret_stat, apps.fnd_api.g_ret_sts_error) !=
               apps.fnd_api.g_ret_sts_success
            THEN
                lv_bus_event_result   := 'Failed';
            ELSE
                lv_bus_event_result   := 'Raised';
            END IF;
        END IF;


        IF x_error_messages IS NOT NULL
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Erorr ' || x_error_messages || ' x_ret_stat ' || x_ret_stat);
        END IF;


        fnd_file.put_line (
            fnd_file.LOG,
               ' Business Event '
            || lv_bus_event_result
            || ' for batch '
            || gn_conc_request_id);
    END;                                        --W.r.t Version 1.1 CCR0006627

    PROCEDURE reprocess_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_hours_old IN NUMBER
                                    , p_debug_level IN NUMBER:= NULL)
    IS
        l_proc_name   VARCHAR2 (80) := G_PKG_NAME || '.reprocess_batch_conc';
        l_ret         VARCHAR2 (1);
        l_err         VARCHAR2 (2000);
        l_ret_txt     VARCHAR2 (10);

        CURSOR c_batches IS
              SELECT batch_id, event_type, SUM (cust_count) AS cust_count,
                     SUM (site_count) AS site_count
                FROM (  SELECT batch_id, G_EVENT_TYPE_CUST AS event_type, COUNT (1) AS cust_count,
                               0 AS site_count
                          FROM xxdo.xxdoint_ar_cust_upd_batch
                         WHERE batch_date < SYSDATE - (p_hours_old / 24)
                      GROUP BY batch_id
                      UNION ALL
                        SELECT batch_id, G_EVENT_TYPE_SITE AS event_type, 0 AS cust_count,
                               COUNT (1) AS site_count
                          FROM xxdo.xxdoint_ar_cust_site_upd_batch
                         WHERE batch_date < SYSDATE - (p_hours_old / 24)
                      GROUP BY batch_id)
            GROUP BY batch_id, event_type
            ORDER BY batch_id, event_type;
    BEGIN
        IF p_debug_level IS NOT NULL
        THEN
            apps.do_debug_tools.enable_conc_log (p_debug_level);
        ELSIF NVL (
                  TO_NUMBER (
                      apps.fnd_profile.VALUE ('XXDOINT_CUST_DEBUG_LEVEL')),
                  0) >
              0
        THEN
            apps.do_debug_tools.enable_conc_log (
                TO_NUMBER (
                    apps.fnd_profile.VALUE ('XXDOINT_CUST_DEBUG_LEVEL')));
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
            raise_business_event (p_batch_id => c_batch.batch_id, p_event_type => c_batch.event_type, x_ret_stat => l_ret
                                  , x_error_messages => l_err);

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

    FUNCTION get_primary_bill_to_code (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL)
        RETURN VARCHAR2
    IS
        l_id     NUMBER;
        l_code   VARCHAR2 (30);
        l_name   ar.hz_cust_site_uses_all.location%TYPE;
    BEGIN
        get_primary_bill_to_attrs (p_customer_id   => p_customer_id,
                                   p_org_id        => p_org_id,
                                   p_brand         => p_brand,
                                   x_site_use_id   => l_id,
                                   x_code          => l_code,
                                   x_name          => l_name);

        RETURN l_code;
    END;

    FUNCTION get_primary_bill_to_name (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL)
        RETURN VARCHAR2
    IS
        l_id     NUMBER;
        l_code   VARCHAR2 (30);
        l_name   ar.hz_cust_site_uses_all.location%TYPE;
    BEGIN
        get_primary_bill_to_attrs (p_customer_id   => p_customer_id,
                                   p_org_id        => p_org_id,
                                   p_brand         => p_brand,
                                   x_site_use_id   => l_id,
                                   x_code          => l_code,
                                   x_name          => l_name);

        RETURN l_name;
    END;

    FUNCTION get_primary_bill_to_id (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL)
        RETURN NUMBER
    IS
        l_id     NUMBER;
        l_code   VARCHAR2 (30);
        l_name   ar.hz_cust_site_uses_all.location%TYPE;
    BEGIN
        get_primary_bill_to_attrs (p_customer_id   => p_customer_id,
                                   p_org_id        => p_org_id,
                                   p_brand         => p_brand,
                                   x_site_use_id   => l_id,
                                   x_code          => l_code,
                                   x_name          => l_name);

        RETURN l_id;
    END;


    PROCEDURE get_primary_bill_to_attrs (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL
                                         , x_site_use_id OUT NUMBER, x_code OUT VARCHAR2, x_name OUT VARCHAR2)
    IS
    BEGIN
        IF NVL (p_brand, 'NONE') = 'SANUK'
        THEN
            BEGIN
                SELECT hcsua.site_use_id, 'ERP:' || TO_CHAR (hcsua.site_use_id), hcsua.location
                  INTO x_site_use_id, x_code, x_name
                  FROM ar.hz_cust_acct_sites_all hcasa
                       INNER JOIN ar.hz_cust_site_uses_all hcsua
                           ON     hcsua.cust_acct_site_id =
                                  hcasa.cust_acct_site_id
                              AND hcsua.site_use_code = 'BILL_TO'
                              AND hcsua.location LIKE UPPER (p_brand) || '%'
                              AND hcsua.status = 'A'
                              AND hcsua.org_id = hcasa.org_id
                 WHERE     hcasa.cust_account_id = p_customer_id
                       AND hcasa.status = 'A'
                       AND hcasa.org_id = p_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            END;

            /*
            if x_site_use_id is not null then
                return;
            end if;
            */
            RETURN;
        END IF;

        SELECT hcsua.site_use_id, 'ERP:' || TO_CHAR (hcsua.site_use_id), hcsua.location
          INTO x_site_use_id, x_code, x_name
          FROM ar.hz_cust_acct_sites_all hcasa
               INNER JOIN ar.hz_cust_site_uses_all hcsua
                   ON     hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                      AND hcsua.site_use_code = 'BILL_TO'
                      AND hcsua.primary_flag = 'Y'
                      AND hcsua.status = 'A'
         WHERE     hcasa.cust_account_id = p_customer_id
               AND hcasa.bill_to_flag = 'P'
               AND hcasa.status = 'A'
               AND hcasa.org_id = p_org_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_site_use_id   := NULL;
            x_code          := NULL;
            x_name          := NULL;
        WHEN TOO_MANY_ROWS
        THEN
            x_site_use_id   := NULL;
            x_code          := NULL;
            x_name          := NULL;
    END;


    PROCEDURE get_primary_bill_to_address (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL, p_bill_to_code IN VARCHAR2:= NULL, x_street1 OUT VARCHAR2, x_street2 OUT VARCHAR2, x_city OUT VARCHAR2, x_state OUT VARCHAR2, x_country OUT VARCHAR2
                                           , x_postal_code OUT VARCHAR2, x_code OUT VARCHAR2, x_name OUT VARCHAR2)
    IS
        l_id     NUMBER;
        l_code   VARCHAR2 (30);
        l_name   ar.hz_cust_site_uses_all.location%TYPE;
    BEGIN
        IF NVL (p_brand, 'NONE') = 'SANUK'
        THEN
            get_primary_bill_to_attrs (p_customer_id   => p_customer_id,
                                       p_org_id        => p_org_id,
                                       p_brand         => p_brand,
                                       x_site_use_id   => l_id,
                                       x_code          => l_code,
                                       x_name          => l_name);

            IF l_code IS NULL
            THEN
                IF p_bill_to_code IS NULL
                THEN              -- get primary bill to using non SANUK logic
                    get_primary_bill_to_attrs (
                        p_customer_id   => p_customer_id,
                        p_org_id        => p_org_id,
                        p_brand         => NULL,
                        x_site_use_id   => l_id,
                        x_code          => l_code,
                        x_name          => l_name);
                END IF;
            END IF;
        ELSE
            IF p_bill_to_code IS NULL
            THEN
                get_primary_bill_to_attrs (p_customer_id   => p_customer_id,
                                           p_org_id        => p_org_id,
                                           p_brand         => p_brand,
                                           x_site_use_id   => l_id,
                                           x_code          => l_code,
                                           x_name          => l_name);
            ELSE
                l_code   := p_bill_to_code;
            END IF;
        END IF;

        x_code   := l_code;

        SELECT site_name, address1, address2,
               city, state, country_code,
               postal_code
          INTO x_name, x_street1, x_street2, x_city,
                     x_state, x_country, x_postal_code
          FROM XXDO.xxdoint_ar_cust_unified_v
         WHERE     customer_id = p_customer_id
               AND operating_unit_id = p_org_id
               AND site_code = l_code;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_street1       := NULL;
            x_street2       := NULL;
            x_city          := NULL;
            x_state         := NULL;
            x_country       := NULL;
            x_postal_code   := NULL;
        WHEN TOO_MANY_ROWS
        THEN
            x_street1       := NULL;
            x_street2       := NULL;
            x_city          := NULL;
            x_state         := NULL;
            x_country       := NULL;
            x_postal_code   := NULL;
    END;

    FUNCTION get_site_code (p_site_use_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ret   VARCHAR2 (30);
    BEGIN
        SELECT 'ERP:' || TO_CHAR (hcsua.site_use_id)
          INTO l_ret
          FROM ar.hz_cust_site_uses_all hcsua
         WHERE site_use_id = p_site_use_id;

        RETURN l_ret;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_site_name (p_site_use_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_ret   ar.hz_cust_site_uses_all.location%TYPE;
    BEGIN
        SELECT location
          INTO l_ret
          FROM ar.hz_cust_site_uses_all hcsua
         WHERE site_use_id = p_site_use_id;

        RETURN l_ret;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_shipping_instructions (p_customer_id   IN NUMBER,
                                        p_brand         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_ret   do_custom.do_customer_lookups.attribute_large%TYPE;
    BEGIN
        SELECT attribute_large
          INTO l_ret
          FROM (  SELECT attribute_large
                    FROM do_custom.do_customer_lookups
                   WHERE     lookup_type = 'DO_DEF_SHIPPING_INSTRUCTS'
                         AND brand IN ('ALL', p_brand)
                         AND customer_id = p_customer_id
                         AND enabled_flag = 'Y'
                ORDER BY DECODE (brand, 'ALL', 1, 0))
         WHERE ROWNUM = 1;

        RETURN l_ret;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_packing_instructions (p_customer_id   IN NUMBER,
                                       p_brand         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_ret   do_custom.do_customer_lookups.attribute_large%TYPE;
    BEGIN
        SELECT attribute_large
          INTO l_ret
          FROM (  SELECT attribute_large
                    FROM do_custom.do_customer_lookups
                   WHERE     lookup_type = 'DO_DEF_PACKING_INSTRUCTS'
                         AND brand IN ('ALL', p_brand)
                         AND customer_id = p_customer_id
                         AND enabled_flag = 'Y'
                ORDER BY DECODE (brand, 'ALL', 1, 0))
         WHERE ROWNUM = 1;

        RETURN l_ret;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN NULL;
    END;
END XXDOINT_AR_CUST_UTILS;
/


GRANT EXECUTE ON APPS.XXDOINT_AR_CUST_UTILS TO SOA_INT
/

GRANT EXECUTE ON APPS.XXDOINT_AR_CUST_UTILS TO XXDO
/
