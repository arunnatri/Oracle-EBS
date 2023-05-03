--
-- XXD_PA_EXP_INTERFACE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_PA_EXP_INTERFACE_PKG
AS
    /*******************************************************************************
    * Program Name    : XXD_PA_EXP_INTERFACE_PKG
    * Language        : PL/SQL
    * Description     : This package will is an Interfaces Inter LE CIP Costs
    * History :
    *
    *         WHO             Version        when            Desc
    * --------------------------------------------------------------------------
    * BT Technology Team      1.0          21/Jan/2015        Interface Prog
    * --------------------------------------------------------------------------- */
    gc_source_out   CONSTANT VARCHAR2 (30) := 'XXDO_PROJECT_TRANSFER_OUT';
    gc_source_in    CONSTANT VARCHAR2 (30) := 'XXDO_PROJECT_TRANSFER_IN';
    gn_user_id               NUMBER := fnd_profile.VALUE ('USER_ID');
    gd_sysdate               DATE := SYSDATE;
    gn_batch_seq             NUMBER;

    PROCEDURE insert_negative_line (p_transfer_id IN VARCHAR2, p_status OUT VARCHAR2, p_error_msg OUT VARCHAR2)
    IS
        -- Local Variables
        lt_xxdo_exp_cip_neg_tbl   lt_xxd_exp_cip_tbl_type;
        lv_trx_source             VARCHAR2 (5);
        ld_weekending_date        DATE;
        lv_src_project_num        VARCHAR2 (30);
        lv_src_task_num           VARCHAR2 (30);
        lv_src_exp_type           VARCHAR2 (30);
        ln_row_count              NUMBER;
        lv_exp_org_name           hr_all_organization_units.NAME%TYPE;
        lv_src_org_id             NUMBER;

        CURSOR cur_get_exp_dtls (cp_transfer_id IN VARCHAR2)
        IS
            SELECT xect.*
              FROM xxd_exp_cip_transfer xect
             WHERE xect.transfer_id = cp_transfer_id;
    BEGIN
        DBMS_OUTPUT.put_line (
            'Inserting Negative Line for ' || p_transfer_id);
        lt_xxdo_exp_cip_neg_tbl.DELETE;
        pa_moac_utils.initialize ('PA');

        OPEN cur_get_exp_dtls (p_transfer_id);

        FETCH cur_get_exp_dtls BULK COLLECT INTO lt_xxdo_exp_cip_neg_tbl;

        CLOSE cur_get_exp_dtls;

        ln_row_count   := lt_xxdo_exp_cip_neg_tbl.COUNT ();

        FOR i IN 1 .. ln_row_count
        LOOP
            -- Week ending Date Calculation
            BEGIN
                SELECT TRUNC (
                           NEXT_DAY (
                               lt_xxdo_exp_cip_neg_tbl (i).to_expenditure_date,
                               (SELECT CASE exp_cycle_start_day_code
                                           WHEN '1' THEN 'SATURDAY'
                                           WHEN '2' THEN 'SUNDAY'
                                           WHEN '3' THEN 'MONDAY'
                                           WHEN '4' THEN 'TUESDAY'
                                           WHEN '5' THEN 'WEDNESDAY'
                                           WHEN '6' THEN 'THURSDAY'
                                           WHEN '7' THEN 'FRIDAY'
                                       END
                                  FROM pa_implementations_all
                                 WHERE org_id =
                                       lt_xxdo_exp_cip_neg_tbl (i).to_org_id)))
                  INTO ld_weekending_date
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DBMS_OUTPUT.put_line (
                           'Error occured while deriving Week End Date : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
                    raise_application_error (
                        -20001,
                           'Error occured while deriving Week End Date : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
            END;

            -- Get the Source Project/Task Details/Expenditure organization_name
            BEGIN
                SELECT project_number, task_number, expenditure_organization_name,
                       org_id, expenditure_type
                  INTO lv_src_project_num, lv_src_task_num, lv_exp_org_name, lv_src_org_id,
                                         lv_src_exp_type
                  FROM apps.pa_expend_items_adjust2_v pev
                 WHERE pev.expenditure_item_id =
                       lt_xxdo_exp_cip_neg_tbl (i).orig_exp_item_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DBMS_OUTPUT.put_line (
                           'Error occured deriving Source Project/Task Number : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
                    raise_application_error (
                        -20001,
                           'Error occured deriving Source Project/Task Number : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
            END;

            INSERT INTO pa_transaction_interface_all (
                            transaction_source,
                            orig_transaction_reference,
                            batch_name,
                            expenditure_ending_date,
                            expenditure_item_date,
                            project_number,
                            task_number,
                            expenditure_type,
                            quantity,
                            raw_cost,
                            denom_raw_cost,
                            acct_raw_cost,
                            transaction_status_code,
                            created_by,
                            creation_date,
                            last_updated_by,
                            last_update_date,
                            org_id,
                            organization_name,
                            attribute3                     -- ORIG_EXP_ITEM_ID
                                      ,
                            attribute4                      -- TRANSFER_REF_NO
                                      ,
                            attribute5  -- DESTINATION_ORG_ID FOR NEGATIVELINE
                                      ,
                            attribute10                         -- TRANSFER_ID
                                       ,
                            expenditure_comment)
                     VALUES (
                                gc_source_out,
                                   lt_xxdo_exp_cip_neg_tbl (i).transfer_id
                                || '_'
                                || 1,
                                   TO_CHAR (ld_weekending_date, 'YYYYMMDD')
                                || '-'
                                || lt_xxdo_exp_cip_neg_tbl (i).transfer_ref_no
                                || '-'
                                || gn_batch_seq,
                                ld_weekending_date,
                                lt_xxdo_exp_cip_neg_tbl (i).to_expenditure_date,
                                lv_src_project_num,
                                lv_src_task_num,
                                lv_src_exp_type,
                                1,
                                (lt_xxdo_exp_cip_neg_tbl (i).amt_to_transfer_src_cur * -1),
                                (lt_xxdo_exp_cip_neg_tbl (i).amt_to_transfer_src_cur * -1),
                                (lt_xxdo_exp_cip_neg_tbl (i).amt_to_transfer_src_cur * -1),
                                'P'                                 -- Pending
                                   ,
                                gn_user_id,
                                gd_sysdate,
                                gn_user_id,
                                gd_sysdate,
                                lv_src_org_id,
                                lv_exp_org_name,
                                lt_xxdo_exp_cip_neg_tbl (i).orig_exp_item_id,
                                lt_xxdo_exp_cip_neg_tbl (i).transfer_ref_no,
                                lt_xxdo_exp_cip_neg_tbl (i).to_org_id-- Destination_Org_Id for NegativeLine
                                                                     ,
                                lt_xxdo_exp_cip_neg_tbl (i).transfer_id,
                                lt_xxdo_exp_cip_neg_tbl (i).col1);

            DBMS_OUTPUT.put_line (SQL%ROWCOUNT);
        END LOOP;

        p_status       := 'S';
        p_error_msg    := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_get_exp_dtls%ISOPEN
            THEN
                CLOSE cur_get_exp_dtls;
            END IF;

            p_status      := 'E';
            p_error_msg   := SQLERRM || '-' || SQLCODE;
            DBMS_OUTPUT.put_line (
                   'Error occured in Negative Block : '
                || SQLERRM
                || '-'
                || SQLCODE);
            raise_application_error (
                -20001,
                   'Error occured in Negative Block : '
                || SQLERRM
                || '-'
                || SQLCODE);
    END insert_negative_line;

    ------------------------------------------------------------------------------------------------------------------------------------
    PROCEDURE insert_positive_line (p_transfer_id IN VARCHAR2, p_status OUT VARCHAR2, p_error_msg OUT VARCHAR2)
    IS
        --  Local Variables
        lt_xxdo_exp_cip_gt_tbl   lt_xxd_exp_cip_tbl_type;
        lv_trx_source            VARCHAR2 (5);
        ld_weekending_date       DATE;
        lv_des_project_num       VARCHAR2 (30);
        lv_des_task_num          VARCHAR2 (30);
        ln_row_count             NUMBER;
        lv_exp_org_name          hr_all_organization_units.NAME%TYPE;
        lv_src_org_id            NUMBER;

        CURSOR cur_get_exp_dtls (cp_transfer_id IN VARCHAR2)
        IS
            SELECT xect.*
              FROM xxd_exp_cip_transfer xect
             WHERE xect.transfer_id = cp_transfer_id;
    BEGIN
        DBMS_OUTPUT.put_line (
            'Inserting Positive Line for ' || p_transfer_id);
        lt_xxdo_exp_cip_gt_tbl.DELETE;

        OPEN cur_get_exp_dtls (p_transfer_id);

        FETCH cur_get_exp_dtls BULK COLLECT INTO lt_xxdo_exp_cip_gt_tbl;

        CLOSE cur_get_exp_dtls;

        ln_row_count   := lt_xxdo_exp_cip_gt_tbl.COUNT ();

        FOR i IN 1 .. ln_row_count
        LOOP
            -- Week ending Date Calculation
            BEGIN
                SELECT TRUNC (
                           NEXT_DAY (
                               lt_xxdo_exp_cip_gt_tbl (i).to_expenditure_date,
                               (SELECT CASE exp_cycle_start_day_code
                                           WHEN '1' THEN 'SATURDAY'
                                           WHEN '2' THEN 'SUNDAY'
                                           WHEN '3' THEN 'MONDAY'
                                           WHEN '4' THEN 'TUESDAY'
                                           WHEN '5' THEN 'WEDNESDAY'
                                           WHEN '6' THEN 'THURSDAY'
                                           WHEN '7' THEN 'FRIDAY'
                                       END
                                  FROM pa_implementations_all
                                 WHERE org_id =
                                       lt_xxdo_exp_cip_gt_tbl (i).to_org_id)))
                  INTO ld_weekending_date
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DBMS_OUTPUT.put_line (
                           'Error occured while deriving Week End Date : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
                    raise_application_error (
                        -20001,
                           'Error occured while deriving Week End Date : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
            END;

            -- Get the Expenditure organization_name,Source Organization Name
            BEGIN
                --Changes By BT Technology Team on 10-APR-2015
                SELECT NAME
                  INTO lv_exp_org_name
                  FROM hr.hr_all_organization_units
                 WHERE organization_id =
                       lt_xxdo_exp_cip_gt_tbl (i).to_expenditure_org_id;

                SELECT org_id
                  INTO lv_src_org_id
                  FROM apps.pa_expend_items_adjust2_v pev
                 WHERE pev.expenditure_item_id =
                       lt_xxdo_exp_cip_gt_tbl (i).orig_exp_item_id;
            -- Disabled By BT Technology Team on 10-APR-2015
            /*SELECT    expenditure_organization_name
            ,         org_id
            INTO      lv_exp_org_name
            ,         lv_src_org_id
            FROM      apps.PA_EXPEND_ITEMS_ADJUST2_V pev
            WHERE     pev.expenditure_item_id = lt_xxdo_exp_cip_gt_tbl(i).ORIG_EXP_ITEM_ID;*/
            EXCEPTION
                WHEN OTHERS
                THEN
                    DBMS_OUTPUT.put_line (
                           'Error occured deriving EXPENDITURE_ORGANIZATION_NAME : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
                    raise_application_error (
                        -20001,
                           'Error occured deriving EXPENDITURE_ORGANIZATION_NAME : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
            END;

            -- Get the Project/Task Details
            BEGIN
                SELECT ppa.segment1, pt.task_number
                  INTO lv_des_project_num, lv_des_task_num
                  FROM pa_projects_all ppa, pa_tasks pt, xxd_exp_cip_transfer xec
                 WHERE     xec.to_project_id = ppa.project_id
                       AND xec.to_org_id = ppa.org_id
                       AND xec.to_task_id = pt.task_id
                       AND pt.project_id = ppa.project_id
                       AND xec.transfer_id =
                           lt_xxdo_exp_cip_gt_tbl (i).transfer_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DBMS_OUTPUT.put_line (
                           'Error occured deriving Destination Project/Task Number : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
                    raise_application_error (
                        -20001,
                           'Error occured deriving Destination Project/Task Number : '
                        || SQLERRM
                        || '-'
                        || SQLCODE);
            END;

            INSERT INTO pa_transaction_interface_all (
                            transaction_source,
                            orig_transaction_reference,
                            batch_name,
                            expenditure_ending_date,
                            expenditure_item_date,
                            project_number,
                            task_number,
                            expenditure_type,
                            quantity,
                            raw_cost,
                            denom_raw_cost,
                            acct_raw_cost,
                            transaction_status_code,
                            created_by,
                            creation_date,
                            last_updated_by,
                            last_update_date,
                            org_id,
                            organization_name,
                            attribute3                     -- ORIG_EXP_ITEM_ID
                                      ,
                            attribute4                      -- TRANSFER_REF_NO
                                      ,
                            attribute5         -- SOURCEORGID FOR POSITIVELINE
                                      ,
                            attribute10                         -- TRANSFER_ID
                                       ,
                            expenditure_comment)
                     VALUES (
                                gc_source_in,
                                   lt_xxdo_exp_cip_gt_tbl (i).transfer_id
                                || '_'
                                || 2,
                                   TO_CHAR (ld_weekending_date, 'YYYYMMDD')
                                || '-'
                                || lt_xxdo_exp_cip_gt_tbl (i).transfer_ref_no
                                || '-'
                                || gn_batch_seq,
                                ld_weekending_date,
                                lt_xxdo_exp_cip_gt_tbl (i).to_expenditure_date,
                                lv_des_project_num,
                                lv_des_task_num,
                                lt_xxdo_exp_cip_gt_tbl (i).to_expenditure_type,
                                1,
                                lt_xxdo_exp_cip_gt_tbl (i).amt_to_transfer_to_cur,
                                lt_xxdo_exp_cip_gt_tbl (i).amt_to_transfer_to_cur,
                                lt_xxdo_exp_cip_gt_tbl (i).amt_to_transfer_to_cur,
                                'P'                                 -- Pending
                                   ,
                                gn_user_id,
                                gd_sysdate,
                                gn_user_id,
                                gd_sysdate,
                                lt_xxdo_exp_cip_gt_tbl (i).to_org_id,
                                lv_exp_org_name,
                                lt_xxdo_exp_cip_gt_tbl (i).orig_exp_item_id,
                                lt_xxdo_exp_cip_gt_tbl (i).transfer_ref_no,
                                lv_src_org_id,
                                lt_xxdo_exp_cip_gt_tbl (i).transfer_id,
                                lt_xxdo_exp_cip_gt_tbl (i).col1);

            DBMS_OUTPUT.put_line (SQL%ROWCOUNT);
        END LOOP;

        p_status       := 'S';
        p_error_msg    := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_get_exp_dtls%ISOPEN
            THEN
                CLOSE cur_get_exp_dtls;
            END IF;

            p_status      := 'E';
            p_error_msg   := SQLERRM || '-' || SQLCODE;
            DBMS_OUTPUT.put_line (
                   'Error occured in Positive Block : '
                || SQLERRM
                || '-'
                || SQLCODE);
            raise_application_error (
                -20001,
                   'Error occured in Positive Block : '
                || SQLERRM
                || '-'
                || SQLCODE);
    END insert_positive_line;

    ---------------------------------------------------------------------------------------------------------------
    PROCEDURE main_interface (p_transfer_ref_no   IN     VARCHAR2,
                              p_errorred             OUT VARCHAR2)
    IS
        CURSOR cur_get_trnsfr_dtls (cp_transfer_ref_no IN VARCHAR2)
        IS
            SELECT xect.*
              FROM xxd_exp_cip_transfer xect
             WHERE xect.transfer_ref_no = cp_transfer_ref_no;

        --Local Variables
        lt_xxdo_exp_cip_trn_tbl   lt_xxd_exp_cip_tbl_type;
        lv_status_insertion       VARCHAR2 (1);
        lv_error_msg              VARCHAR2 (50);
        when_insertion_failed     EXCEPTION;
        ln_fault_transfer_id      NUMBER;
        ln_row_count              NUMBER;
        -- Local Variables for Submitting Custom Import Program
        ln_request_id             NUMBER;
        lb_wait                   BOOLEAN;
        lc_phase                  VARCHAR2 (30);
        lc_status                 VARCHAR2 (30);
        lc_dev_phase              VARCHAR2 (30);
        lc_dev_status             VARCHAR2 (30);
        ln_import_check           NUMBER;
        lc_message                VARCHAR2 (100);
        lv_import_prog_status     VARCHAR2 (100);
    BEGIN
        lt_xxdo_exp_cip_trn_tbl.DELETE;
        p_errorred     := 'N';
        pa_moac_utils.initialize ('PA');

        OPEN cur_get_trnsfr_dtls (p_transfer_ref_no);

        FETCH cur_get_trnsfr_dtls BULK COLLECT INTO lt_xxdo_exp_cip_trn_tbl;

        CLOSE cur_get_trnsfr_dtls;

        ln_row_count   := lt_xxdo_exp_cip_trn_tbl.COUNT ();
        gn_batch_seq   := xxd_cip_transfer_batch_seq.NEXTVAL;

        -- INSERT NEGATIVE LINES
        FOR i IN 1 .. ln_row_count
        LOOP
            IF stage1_clear (
                   lt_xxdo_exp_cip_trn_tbl (i).transfer_id || '_' || 1) =
               'N'
            THEN
                insert_negative_line (
                    lt_xxdo_exp_cip_trn_tbl (i).transfer_id,
                    lv_status_insertion,
                    lv_error_msg);
            END IF;

            IF lv_status_insertion <> 'S'
            THEN
                ln_fault_transfer_id   :=
                    lt_xxdo_exp_cip_trn_tbl (i).transfer_id;
                ROLLBACK;
                p_errorred   := 'Y';
                RAISE when_insertion_failed;
            END IF;
        END LOOP;

        gn_batch_seq   := xxd_cip_transfer_batch_seq.NEXTVAL;

        -- INSERT POSITIVE LINE
        FOR i IN 1 .. ln_row_count
        LOOP
            IF stage1_clear (
                   lt_xxdo_exp_cip_trn_tbl (i).transfer_id || '_' || 2) =
               'N'
            THEN
                insert_positive_line (
                    lt_xxdo_exp_cip_trn_tbl (i).transfer_id,
                    lv_status_insertion,
                    lv_error_msg);
            END IF;

            IF lv_status_insertion <> 'S'
            THEN
                ln_fault_transfer_id   :=
                    lt_xxdo_exp_cip_trn_tbl (i).transfer_id;
                ROLLBACK;
                p_errorred   := 'Y';
                RAISE when_insertion_failed;
            END IF;
        END LOOP;

        -- If the Insertion in Interface Table is Successful then Marked for Process
        FOR i IN 1 .. ln_row_count
        LOOP
            UPDATE xxd_exp_cip_transfer
               SET status = 'M', error_stage = '', error_message = '',
                   comments = ''
             WHERE transfer_id = lt_xxdo_exp_cip_trn_tbl (i).transfer_id;
        END LOOP;

        COMMIT;
        DBMS_OUTPUT.put_line ('Commit Executed');
        -- Call for Submitting the Custom Import Program // XXD Inter LE CIP Transaction Import
        fnd_global.apps_initialize (fnd_profile.VALUE ('USER_ID'),
                                    fnd_profile.VALUE ('RESP_ID'),
                                    fnd_profile.VALUE ('RESP_APPL_ID'));
        ln_request_id   :=
            fnd_request.submit_request ('XXDO',                 -- application
                                                'XXDLECIPTRXIMP', -- program short name
                                                                  '', -- description
                                        SYSDATE,                 -- start time
                                                 FALSE,         -- sub request
                                                        p_transfer_ref_no -- p_transfer_ref_no
                                                                         );

        IF ln_request_id <= 0
        THEN
            ROLLBACK;
            lv_import_prog_status   := 'Import Prog Not Submitted';
        ELSE
            lv_import_prog_status   :=
                'Import Prog Submitted ' || ln_request_id;
            COMMIT;
            lb_wait   :=
                fnd_concurrent.wait_for_request (
                    request_id   => ln_request_id,
                    INTERVAL     => 1,
                    max_wait     => 1,
                    phase        => lc_phase,
                    status       => lc_status,
                    dev_phase    => lc_dev_phase,
                    dev_status   => lc_dev_status,
                    MESSAGE      => lc_message);

            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
            THEN
                lv_import_prog_status   :=
                    'Import Prog Completed ' || ln_request_id;
            ELSE
                lv_import_prog_status   :=
                       'Import Prog Status '
                    || ln_request_id
                    || ' : '
                    || lc_phase
                    || '-'
                    || lc_status;
            END IF;
        END IF;
    EXCEPTION
        WHEN when_insertion_failed
        THEN
            IF cur_get_trnsfr_dtls%ISOPEN
            THEN
                CLOSE cur_get_trnsfr_dtls;
            END IF;

            ROLLBACK;
            p_errorred   := 'Y';

            UPDATE xxd_exp_cip_transfer
               SET status = 'E', error_stage = 'Stage1', error_message = 'Failed during Inserting Interface Line',
                   comments = 'Check the Transfer #' || ln_fault_transfer_id
             WHERE transfer_id = ln_fault_transfer_id;

            COMMIT;
            DBMS_OUTPUT.put_line (
                   'While Inserting transfers for '
                || p_transfer_ref_no
                || ',Error : '
                || lv_error_msg);
            raise_application_error (
                -20001,
                   SQLERRM
                || 'While Inserting transfers failed for '
                || p_transfer_ref_no
                || ',Error : '
                || lv_error_msg);
        WHEN OTHERS
        THEN
            IF cur_get_trnsfr_dtls%ISOPEN
            THEN
                CLOSE cur_get_trnsfr_dtls;
            END IF;

            p_errorred   := 'Y';
            DBMS_OUTPUT.put_line (
                   'While Inserting transfers for '
                || p_transfer_ref_no
                || ',Error in Main Block');
            raise_application_error (
                -20001,
                   SQLERRM
                || 'While Inserting transfers others for '
                || p_transfer_ref_no
                || ',Error in Main Block');
    END main_interface;

    ---------------------------------------------------------------------------------------------------------------------------
    PROCEDURE submit_import_prog (errbuf                 OUT VARCHAR2,
                                  retcode                OUT NUMBER,
                                  p_transfer_ref_no   IN     VARCHAR2)
    IS
        CURSOR cur_get_intf_dtls (cp_transfer_ref_no IN VARCHAR2)
        IS
            SELECT pti.*
              FROM pa_transaction_interface_all pti
             WHERE pti.attribute4 = cp_transfer_ref_no;

        -- Local Variables
        ln_request_id     NUMBER;
        c_rec             cur_get_intf_dtls%ROWTYPE;
        lb_wait           BOOLEAN;
        lc_phase          VARCHAR2 (30);
        lc_status         VARCHAR2 (30);
        lc_dev_phase      VARCHAR2 (30);
        lc_dev_status     VARCHAR2 (30);
        ln_import_check   NUMBER;
        lc_message        VARCHAR2 (100);
        l_req_id          request_table;
        i                 NUMBER := 0;
    BEGIN
        --Initializing the Environment
        fnd_global.apps_initialize (fnd_profile.VALUE ('USER_ID'),
                                    fnd_profile.VALUE ('RESP_ID'),
                                    fnd_profile.VALUE ('RESP_APPL_ID'));
        fnd_file.put_line (fnd_file.LOG,
                           'Submit_import_prog has been submitted..');
        fnd_file.put_line (fnd_file.LOG,
                           'Transfer no : ' || p_transfer_ref_no);
        fnd_file.put_line (
            fnd_file.LOG,
               fnd_profile.VALUE ('USER_ID')
            || '-'
            || fnd_profile.VALUE ('RESP_ID')
            || '-'
            || fnd_profile.VALUE ('RESP_APPL_ID'));

        FOR rec IN cur_get_intf_dtls (p_transfer_ref_no)
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                '--------------------------------------------------');
            fnd_file.put_line (fnd_file.LOG,
                               'Setting the Oganization : ' || rec.org_id);
            fnd_request.set_org_id (rec.org_id);

            UPDATE pa_transaction_interface_all pti
               SET transaction_status_code   = 'P'
             WHERE pti.txn_interface_id = rec.txn_interface_id;

            fnd_file.put_line (
                fnd_file.LOG,
                'Submitting PRC Transaction Source for.......');
            fnd_file.put_line (
                fnd_file.LOG,
                'Transaction_source : ' || rec.transaction_source);
            fnd_file.put_line (fnd_file.LOG,
                               'Batch name : ' || rec.batch_name);
            ln_request_id   :=
                fnd_request.submit_request ('PA',               -- application
                                                  'PAXTRTRX', -- program short name
                                                              'Transaction Import', -- description
                                                                                    SYSDATE, -- start time
                                                                                             FALSE, -- sub request
                                                                                                    rec.transaction_source
                                            , -- P_TRX_SOURCE,
                                              rec.batch_name  -- P_BATCH_NAME,
                                                            );

            IF ln_request_id <= 0
            THEN
                ROLLBACK;
                fnd_file.put_line (fnd_file.LOG,
                                   'Concurrent request failed to submit');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Submitted concurrent Request  : ' || ln_request_id);
                l_req_id (i)   := ln_request_id;
                i              := i + 1;
                COMMIT;
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            '--------------------------------------------------');

        FOR rec IN l_req_id.FIRST .. l_req_id.LAST
        LOOP
            IF l_req_id (rec) > 0
            THEN
                LOOP
                    lc_dev_phase    := NULL;
                    lc_dev_status   := NULL;
                    lb_wait         :=
                        fnd_concurrent.wait_for_request (
                            request_id   => l_req_id (rec)--ln_concurrent_request_id
                                                          ,
                            INTERVAL     => 1,
                            max_wait     => 1,
                            phase        => lc_phase,
                            status       => lc_status,
                            dev_phase    => lc_dev_phase,
                            dev_status   => lc_dev_status,
                            MESSAGE      => lc_message);

                    IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Concurrent request '
                            || l_req_id (rec)
                            || ' : Completed');
                        EXIT;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Concurrent request '
                            || l_req_id (rec)
                            || ' : '
                            || lc_phase
                            || '-'
                            || lc_status);
                    END IF;
                END LOOP;
            END IF;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'End of Submit_import_prog');
        fnd_file.put_line (
            fnd_file.LOG,
            '--------------------------------------------------');
        fnd_file.put_line (fnd_file.LOG, 'Start of call for Stage3');
        update_stage3 (p_transfer_ref_no);
        fnd_file.put_line (fnd_file.LOG, 'End of Stage3 !! ');
        fnd_file.put_line (
            fnd_file.LOG,
            '--------------------------------------------------');
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_get_intf_dtls%ISOPEN
            THEN
                CLOSE cur_get_intf_dtls;
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Occured while running the Transaction Import Program');
            fnd_file.put_line (
                fnd_file.LOG,
                'ERROR Details :' || SQLERRM || '-' || SQLCODE);
    END submit_import_prog;

    ---------------------------------------------------------------------------------------------------------------------------
    PROCEDURE update_stage3 (p_transfer_ref_no IN VARCHAR2)
    IS
        CURSOR cur_base_details (cp_transfer_ref_no IN VARCHAR2)
        IS
            SELECT pei.*
              FROM pa_expenditure_items_all pei
             WHERE attribute4 = cp_transfer_ref_no;

        CURSOR cur_intf_details (cp_transfer_ref_no IN VARCHAR2)
        IS
            SELECT pti.*
              FROM pa_transaction_interface_all pti
             WHERE attribute4 = cp_transfer_ref_no;

        ln_request_id      NUMBER;
        lv_processed_ids   VARCHAR2 (200);
        lv_error_ids       VARCHAR2 (200);
    BEGIN
        FOR rec1 IN cur_base_details (p_transfer_ref_no)
        LOOP
            BEGIN
                --                UPDATE  apps.pa_expenditure_items_all
                --                SET     adjusted_expenditure_item_id  = rec1.expenditure_item_id    --<new_exp_item_id>
                --                WHERE   expenditure_item_id           = rec1.attribute3            --<orig_exp_item_id>
                --                AND     org_id                        = rec1.org_id;---Added by BT Technology Team on 22APR2015
                UPDATE xxd_exp_cip_transfer
                   SET status = 'P', error_stage = '', error_message = '',
                       comments = 'Processed Completely'
                 WHERE transfer_id = rec1.attribute10;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;

                    UPDATE xxd_exp_cip_transfer
                       SET status = 'E', error_stage = 'Stage3', error_message = 'Updating Transfer_id ' || rec1.attribute10 || 'Details Failed',
                           comments = 'Original Exp item '
                     WHERE transfer_id = rec1.attribute10;

                    COMMIT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Updating Transfer_id '
                        || rec1.attribute10
                        || 'Details Failed in Stage3');

                    IF cur_base_details%ISOPEN
                    THEN
                        CLOSE cur_base_details;
                    END IF;
            END;

            lv_processed_ids   := lv_processed_ids || rec1.attribute10;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Transfer Id Processed  :'
            || NVL (lv_processed_ids || ',', 'No Record has been Processed'));

        FOR rec2 IN cur_intf_details (p_transfer_ref_no)
        LOOP
            UPDATE xxd_exp_cip_transfer
               SET status = 'E', error_stage = 'Stage2', comments = 'Error in Project - ' || rec2.project_number || ',Batch - ' || rec2.batch_name,
                   error_message = rec2.transaction_rejection_code
             WHERE transfer_id = rec2.attribute10;

            COMMIT;
            lv_error_ids   := lv_error_ids || rec2.attribute10;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Transfer Id Errored  :'
            || NVL (lv_error_ids, 'No Record has been Errored'));
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF cur_base_details%ISOPEN
            THEN
                CLOSE cur_base_details;
            END IF;

            IF cur_intf_details%ISOPEN
            THEN
                CLOSE cur_intf_details;
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Occured while running the Updating Status in Tables #Stage3');
            fnd_file.put_line (fnd_file.LOG,
                               'Transfer Ref No :' || p_transfer_ref_no);
            fnd_file.put_line (
                fnd_file.LOG,
                'ERROR Details :' || SQLERRM || '-' || SQLCODE);
            ROLLBACK;
    END update_stage3;

    ---------------------------------------------------------------------------------------------------------------------------
    FUNCTION stage1_clear (p_orig_trx_ref IN VARCHAR2)
        RETURN VARCHAR2
    IS
        --Local Variables
        ln_orig_trx_ref      VARCHAR2 (30);
        ln_interface_count   NUMBER;
        ln_base_count        NUMBER;
    BEGIN
        ln_orig_trx_ref   := p_orig_trx_ref;

        -- Original Trx Reference is a combination of TransferId and the type of line(Negative(1)/Positive(2))
        SELECT COUNT (*)
          INTO ln_base_count
          FROM pa_expenditure_items_all pei
         WHERE orig_transaction_reference = ln_orig_trx_ref;

        SELECT COUNT (*)
          INTO ln_interface_count
          FROM pa_transaction_interface_all pei
         WHERE orig_transaction_reference = ln_orig_trx_ref;

        IF ln_base_count > 0 OR ln_interface_count > 0
        THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END stage1_clear;
---------------------------------------------------------------------------------------------------------------------------
END xxd_pa_exp_interface_pkg;
/
