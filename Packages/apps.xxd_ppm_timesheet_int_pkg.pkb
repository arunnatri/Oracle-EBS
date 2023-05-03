--
-- XXD_PPM_TIMESHEET_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PPM_TIMESHEET_INT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_PPM_TIMESHEET_INT_PKG
    * Design       : This package is used for timesheet interface
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 04-Jan-2022  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    gn_user_id      NUMBER := fnd_global.user_id;
    gn_request_id   NUMBER := fnd_global.conc_request_id;
    gd_sysdate      DATE := SYSDATE;
    gc_recipients   VARCHAR2 (1000);

    -- ===============================================================================
    -- To print debug messages
    -- ===============================================================================
    PROCEDURE msg (p_msg IN VARCHAR2)
    AS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, p_msg);
        DBMS_OUTPUT.put_line (p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Exception in MSG: ' || SQLERRM);
    END msg;

    -- ===============================================================================
    -- Truncate all Prior Tables to start data loading
    -- ===============================================================================
    PROCEDURE truncate_prior_tables
    AS
    BEGIN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_custom_data_prior_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_daily_tr_prior_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_ip_user_prior_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_resources_prior_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_structure_prior_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_criteria_prior_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_plan_entity_prior_t';
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Unable to truncate current tables: ' || SQLERRM);
    END truncate_prior_tables;

    -- ===============================================================================
    -- When data load is success, copy the data into prior tables from current tables
    -- ===============================================================================
    PROCEDURE copy_prior_tables
    AS
    BEGIN
        truncate_prior_tables;

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_custom_data_prior_t SELECT * FROM xxdo.xxd_ppm_custom_data_current_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_daily_tr_prior_t SELECT * FROM xxdo.xxd_ppm_daily_tr_current_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_ip_user_prior_t SELECT * FROM xxdo.xxd_ppm_ip_user_current_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_resources_prior_t SELECT * FROM xxdo.xxd_ppm_resources_current_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_structure_prior_t SELECT * FROM xxdo.xxd_ppm_structure_current_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_criteria_prior_t SELECT * FROM xxdo.xxd_ppm_criteria_current_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_plan_entity_prior_t SELECT * FROM xxdo.xxd_ppm_plan_entity_current_t';

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Unable to restore prior tables: ' || SQLERRM);
    END copy_prior_tables;

    -- ===============================================================================
    -- Get Open GL Date for the current Exp Item Date
    -- ===============================================================================
    FUNCTION open_gl_date (p_exp_item_date IN DATE, p_org_id IN NUMBER)
        RETURN DATE
    IS
        ld_open_date   DATE;
    BEGIN
        SELECT MIN (p_exp_item_date)
          INTO ld_open_date
          FROM pa_implementations_all pia, gl_period_statuses gps_gl, gl_period_statuses gps_proj
         WHERE     pia.org_id = p_org_id
               AND gps_gl.set_of_books_id = pia.set_of_books_id
               AND gps_gl.application_id = 101
               AND gps_gl.closing_status = 'O'
               AND NVL (gps_gl.adjustment_period_flag, 'N') = 'N'
               AND TRUNC (p_exp_item_date) BETWEEN TRUNC (gps_gl.start_date)
                                               AND TRUNC (gps_gl.end_date)
               AND gps_proj.set_of_books_id = pia.set_of_books_id
               AND gps_proj.application_id = 8721
               AND gps_proj.closing_status = 'O'
               AND NVL (gps_proj.adjustment_period_flag, 'N') = 'N'
               AND TRUNC (p_exp_item_date) BETWEEN TRUNC (
                                                       gps_proj.start_date)
                                               AND TRUNC (gps_proj.end_date)
               AND gps_proj.period_name = gps_gl.period_name;

        IF (ld_open_date IS NULL)
        THEN
            SELECT MAX (gps_proj.end_date)
              INTO ld_open_date
              FROM pa_implementations_all pia, gl_period_statuses gps_gl, gl_period_statuses gps_proj
             WHERE     pia.org_id = p_org_id
                   AND gps_gl.set_of_books_id = pia.set_of_books_id
                   AND gps_gl.application_id = 101
                   AND gps_gl.closing_status = 'O'
                   AND NVL (gps_gl.adjustment_period_flag, 'N') = 'N'
                   AND TRUNC (p_exp_item_date) >= gps_gl.start_date
                   AND gps_proj.set_of_books_id = pia.set_of_books_id
                   AND gps_proj.application_id = 8721
                   AND gps_proj.closing_status = 'O'
                   AND NVL (gps_proj.adjustment_period_flag, 'N') = 'N'
                   AND TRUNC (p_exp_item_date) >= gps_proj.start_date
                   AND gps_proj.period_name = gps_gl.period_name;
        END IF;

        IF ld_open_date IS NULL
        THEN
            SELECT MIN (gps_proj.start_date)
              INTO ld_open_date
              FROM pa_implementations_all pia, gl_period_statuses gps_gl, gl_period_statuses gps_proj
             WHERE     pia.org_id = p_org_id
                   AND gps_gl.set_of_books_id = pia.set_of_books_id
                   AND gps_gl.application_id = 101
                   AND gps_gl.closing_status = 'O'
                   AND NVL (gps_gl.adjustment_period_flag, 'N') = 'N'
                   AND TRUNC (p_exp_item_date) <= gps_gl.end_date
                   AND gps_proj.set_of_books_id = pia.set_of_books_id
                   AND gps_proj.application_id = 8721
                   AND gps_proj.closing_status = 'O'
                   AND NVL (gps_proj.adjustment_period_flag, 'N') = 'N'
                   AND TRUNC (p_exp_item_date) <= gps_proj.end_date
                   AND gps_proj.period_name = gps_gl.period_name;
        END IF;

        IF ld_open_date IS NULL
        THEN
            ld_open_date   := p_exp_item_date;
        END IF;

        RETURN ld_open_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            msg ('Exception in OPEN_GL_DATE: ' || SQLERRM);
            RETURN p_exp_item_date;
    END open_gl_date;

    -- ===============================================================================
    -- Insert Into Timesheet Staging Table
    -- ===============================================================================
    PROCEDURE insert_stg (x_status OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    AS
        lc_status      VARCHAR2 (1);
        lc_err_msg     VARCHAR2 (4000);
        ln_row_count   NUMBER := 0;
    BEGIN
        msg ('Start of INSERT_STG');

        INSERT INTO xxdo.xxd_ppm_timesheet_stg_t (record_id,
                                                  transaction_source,
                                                  employee_number,
                                                  employee_email,
                                                  organization_name,
                                                  expenditure_item_date,
                                                  project_number,
                                                  expenditure_type,
                                                  quantity,
                                                  transaction_status_code,
                                                  attribute_category,
                                                  attribute2,
                                                  attribute8,
                                                  attribute9,
                                                  system_linkage,
                                                  request_id,
                                                  status,
                                                  created_by,
                                                  creation_date,
                                                  last_updated_by,
                                                  last_update_date)
            SELECT xxdo.xxd_ppm_timesheet_stg_s.NEXTVAL
                       record_id,
                   'XXDO_ATTASK_TIMECARD'
                       transaction_source,
                   xpiu.user_name
                       employee_number,
                   xpiu.e_mail
                       employee_email,
                   'IT - General'
                       organization_name,
                   xpdt.day_date
                       expenditure_item_date,
                   (SELECT xpcd.deck_idoracle
                      FROM xxdo.xxd_ppm_custom_data_current_t xpcd, xxdo.xxd_ppm_plan_entity_current_t xppe
                     WHERE     1 = 1
                           AND xppe.ppl_code = xpcd.planning_code
                           AND xppe.planning_code = xpdt.activity_code)
                       project_number,
                   'Employee Time - CAPEX'
                       expenditure_type,
                   ROUND (((xpdt.daily_effort / 1000) / 60), 2)
                       quantity,
                   'P'
                       transaction_status_code,
                   'AtTask Time Card Information'
                       attribute_category,
                   SUBSTR (xps.description, 1, 150)
                       attribute2,
                   ROUND (((xpdt.daily_effort / 1000) / 60), 2)
                       attribute8,
                   xpdt.day_date
                       attribute9,
                   'ST'
                       system_linkage,
                   gn_request_id
                       request_id,
                   'N'
                       status,
                   gn_user_id
                       created_by,
                   gd_sysdate
                       creation_date,
                   gn_user_id
                       last_updated_by,
                   gd_sysdate
                       last_update_date
              FROM xxdo.xxd_ppm_daily_tr_v xpdt, xxdo.xxd_ppm_resources_current_t xpr, xxdo.xxd_ppm_ip_user_current_t xpiu,
                   xxdo.xxd_ppm_structure_current_t xps
             WHERE     1 = 1
                   AND xpdt.resource_code = xpr.resource_code
                   AND xpr.logon_id = xpiu.user_name
                   AND xps.structure_code = xpdt.activity_code
                   -- Approved Timesheets
                   AND xpdt.integrate_status = 'R'
                   -- Integrate Flag
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_ppm_criteria_current_t xpc, xxdo.xxd_ppm_structure_current_t xps1
                             WHERE     1 = 1
                                   AND xpc.resource_code = xpdt.resource_code
                                   AND xpc.father_code = xps1.structure_code
                                   AND xpc.structure_name = 'Obs32'
                                   AND NVL (xps1.description, 'No') = 'Yes')
                   -- CapEx Flag
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_ppm_plan_entity_current_t xppe
                             WHERE     1 = 1
                                   AND xppe.planning_code =
                                       xpdt.activity_code
                                   AND NVL (xppe.code5, '-1') = '2625');

        ln_row_count   := SQL%ROWCOUNT;

        msg ('Staging Table Record Count: ' || ln_row_count);

        IF ln_row_count = 0
        THEN
            lc_err_msg   := 'No Records to Process';
            x_status     := 'E';
            x_err_msg    := lc_err_msg;
        ELSE
            COMMIT;
            x_status   := 'S';
        END IF;

        msg ('End of INSERT_STG');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_err_msg   := 'Exception in INSERT_STG: ' || SQLERRM;
            x_status     := 'E';
            x_err_msg    := lc_err_msg;
            msg (lc_err_msg);
    END insert_stg;

    -- ===============================================================================
    -- Prorate the time with the cap of 40 hours
    -- ===============================================================================
    PROCEDURE prorate_time
    IS
        ln_hard_time        NUMBER;
        ln_remaining_time   NUMBER;
        ln_multiplier       NUMBER;
        ln_soft_time        NUMBER;
        lc_err_msg          VARCHAR2 (4000);
    BEGIN
        msg ('Start of PRORATE_TIME');

        FOR i
            IN (  SELECT person_id, employee_number, batch_name,
                         expenditure_ending_date, SUM (quantity) quantity, GREATEST (LEAST (1, 40 / SUM (TO_NUMBER (attribute8))), 0) prorate
                    FROM xxdo.xxd_ppm_timesheet_stg_t
                   WHERE request_id = gn_request_id AND status <> 'E'
                GROUP BY person_id, employee_number, batch_name,
                         expenditure_ending_date
                  HAVING     GREATEST (
                                 LEAST (1, 40 / SUM (TO_NUMBER (attribute8))),
                                 0) <>
                             0
                         AND GREATEST (
                                 LEAST (1, 40 / SUM (TO_NUMBER (attribute8))),
                                 0) <>
                             1)
        LOOP
            UPDATE xxdo.xxd_ppm_timesheet_stg_t
               SET quantity   = i.prorate * TO_NUMBER (attribute8)
             WHERE     employee_number = i.employee_number
                   AND batch_name = i.batch_name
                   AND expenditure_ending_date = i.expenditure_ending_date
                   AND request_id = gn_request_id
                   AND status <> 'E';
        END LOOP;

        msg ('End of PRORATE_TIME');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_err_msg   := 'Exception in PRORATE_TIME: ' || SQLERRM;

            UPDATE xxdo.xxd_ppm_timesheet_stg_t
               SET status = 'E', error_message = lc_err_msg
             WHERE request_id = gn_request_id AND status <> 'E';

            msg (lc_err_msg);
    END prorate_time;

    -- ===============================================================================
    -- Validate Staging Table Data
    -- ===============================================================================
    PROCEDURE validate_stg (x_status OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    AS
        lc_status        VARCHAR2 (1);
        lc_err_msg       VARCHAR2 (4000);
        ln_person_id     per_all_people_f.person_id%TYPE;
        ln_org_id        xxdo.xxd_ppm_timesheet_stg_t.org_id%TYPE;
        lc_task_number   xxdo.xxd_ppm_timesheet_stg_t.task_number%TYPE;
    BEGIN
        msg ('Start of VALIDATE_STG');

        -- Update Trx Reference
        UPDATE xxdo.xxd_ppm_timesheet_stg_t
           SET orig_transaction_reference = 'XXD_PPM_TIMSHEET_' || record_id
         WHERE request_id = gn_request_id;

        msg ('Completed Trx Reference Update');

        -- Project Number Validation
        UPDATE xxdo.xxd_ppm_timesheet_stg_t
           SET status = 'E', error_message = 'Project Number is mandatory for processing.'
         WHERE project_number IS NULL AND request_id = gn_request_id;

        msg ('Completed Project Number Update');

        -- Derive employee details from employee number
        FOR i IN (SELECT DISTINCT employee_number
                    FROM xxdo.xxd_ppm_timesheet_stg_t
                   WHERE request_id = gn_request_id AND status <> 'E')
        LOOP
            lc_status      := 'V';
            lc_err_msg     := NULL;
            ln_person_id   := NULL;

            BEGIN
                SELECT person_id
                  INTO ln_person_id
                  FROM per_all_people_f
                 WHERE     employee_number = i.employee_number
                       AND SYSDATE BETWEEN effective_start_date
                                       AND effective_end_date;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_status   := 'E';
                    lc_err_msg   :=
                        'Unable to derive Employee Details from Employee Number.';
                WHEN TOO_MANY_ROWS
                THEN
                    lc_status   := 'E';
                    lc_err_msg   :=
                        'Too many records found for this Employee Number.';
            END;

            UPDATE xxdo.xxd_ppm_timesheet_stg_t
               SET person_id = ln_person_id, status = lc_status, error_message = lc_err_msg
             WHERE     employee_number = i.employee_number
                   AND request_id = gn_request_id;
        END LOOP;

        msg ('Completed Employee Details Update');

        -- derive org id and task number from project number
        FOR i IN (SELECT DISTINCT project_number
                    FROM xxdo.xxd_ppm_timesheet_stg_t
                   WHERE request_id = gn_request_id AND status <> 'E')
        LOOP
            ln_org_id        := NULL;
            lc_task_number   := NULL;
            lc_status        := 'V';
            lc_err_msg       := NULL;

            -- org id
            BEGIN
                SELECT org_id
                  INTO ln_org_id
                  FROM pa_projects_all
                 WHERE segment1 = i.project_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_status   := 'E';
                    lc_err_msg   :=
                        'Unable to derive Ord ID from Project Number.';
                WHEN TOO_MANY_ROWS
                THEN
                    lc_status   := 'E';
                    lc_err_msg   :=
                        'Too many records found for this Project Number.';
            END;

            -- task number
            BEGIN
                SELECT task_number
                  INTO lc_task_number
                  FROM apps.pa_projects_all ppa, apps.pa_tasks pt
                 WHERE     ppa.segment1 = i.project_number
                       AND pt.project_id = ppa.project_id
                       AND UPPER (task_name) LIKE '%EMP%TIME%CAPEX%';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_status   := 'E';
                    lc_err_msg   :=
                        'Unable to derive Task Number from Project Number.';
                WHEN TOO_MANY_ROWS
                THEN
                    lc_status   := 'E';
                    lc_err_msg   :=
                        'Too many records found for this Project Number.';
            END;

            UPDATE xxdo.xxd_ppm_timesheet_stg_t
               SET org_id = ln_org_id, task_number = lc_task_number, status = lc_status,
                   error_message = lc_err_msg
             WHERE     project_number = i.project_number
                   AND request_id = gn_request_id;
        END LOOP;

        msg ('Completed Org ID and Task Number Update');

        -- update exp item date
        UPDATE xxdo.xxd_ppm_timesheet_stg_t
           SET expenditure_item_date = open_gl_date (expenditure_item_date, org_id)
         WHERE request_id = gn_request_id AND status <> 'E';

        msg ('Completed Exp Item Date Update');

        -- update exp ending date
        UPDATE xxdo.xxd_ppm_timesheet_stg_t
           SET expenditure_ending_date = DECODE (TO_CHAR (expenditure_item_date, 'DAY'), 'SATURDAY ', expenditure_item_date, NEXT_DAY (expenditure_item_date, 'SATURDAY'))
         WHERE request_id = gn_request_id AND status <> 'E';

        msg ('Completed Exp Ending Date Update');

        -- update batch name
        UPDATE xxdo.xxd_ppm_timesheet_stg_t
           SET batch_name = 'ATTASKTIMEINTERFACE-' || TO_CHAR (expenditure_ending_date, 'YYYYMMDD') || '-' || org_id, status = 'S'
         WHERE request_id = gn_request_id AND status = 'V';

        msg ('Completed Batch Name Update');

        -- Update as Error if timesheets are already processed
        UPDATE xxdo.xxd_ppm_timesheet_stg_t xpts
           SET status = 'E', error_message = 'The timesheet for the employee has already been processed.'
         WHERE     request_id = gn_request_id
               AND (SELECT NVL (SUM (peia.quantity), 0)
                      FROM pa_expenditures_all pea, pa_expenditure_items_all peia
                     WHERE     pea.incurred_by_person_id = xpts.person_id
                           AND peia.attribute9 = xpts.attribute9
                           AND peia.expenditure_id = pea.expenditure_id
                           AND peia.expenditure_type =
                               'Employee Time - CAPEX') >
                   0;

        -- Prorate Time
        prorate_time;

        x_status   := 'S';
        msg ('End of VALIDATE_STG');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_err_msg   := 'Exception in VALIDATE_STG: ' || SQLERRM;
            x_status     := 'E';
            x_err_msg    := lc_err_msg;
            msg (lc_err_msg);
    END validate_stg;

    -- ===============================================================================
    -- Insert into Projects Interface Table
    -- ===============================================================================
    PROCEDURE insert_interface (x_status    OUT VARCHAR2,
                                x_err_msg   OUT VARCHAR2)
    AS
        lc_status    VARCHAR2 (1);
        lc_err_msg   VARCHAR2 (4000);
    BEGIN
        msg ('Start of INSERT_INTERFACE');

        INSERT INTO pa_transaction_interface_all (transaction_source, batch_name, employee_number, organization_name, expenditure_item_date, expenditure_ending_date, project_number, task_number, expenditure_type, quantity, transaction_status_code, orig_transaction_reference, attribute_category, attribute2, attribute8, attribute9, system_linkage, org_id, created_by, creation_date, last_updated_by
                                                  , last_update_date)
            SELECT transaction_source, batch_name, employee_number,
                   organization_name, expenditure_item_date, expenditure_ending_date,
                   project_number, task_number, expenditure_type,
                   quantity, transaction_status_code, orig_transaction_reference,
                   attribute_category, attribute2, attribute8,
                   attribute9, system_linkage, org_id,
                   created_by, creation_date, last_updated_by,
                   last_update_date
              FROM xxdo.xxd_ppm_timesheet_stg_t
             WHERE request_id = gn_request_id AND status = 'S';

        msg ('Interface Table Record Count: ' || SQL%ROWCOUNT);

        x_status   := 'S';
        COMMIT;
        -- Process Current Data as Prior Data
        copy_prior_tables ();
        msg ('End of INSERT_INTERFACE');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_err_msg   := 'Exception in INSERT_INTERFACE: ' || SQLERRM;
            x_status     := 'E';
            x_err_msg    := lc_err_msg;
            msg (lc_err_msg);
    END insert_interface;

    -- ===============================================================================
    -- To send email to target auidence with the progress status
    -- ===============================================================================
    PROCEDURE send_email
    AS
        lc_result            VARCHAR2 (2000);
        lc_result_msg        VARCHAR2 (2000);
        lc_subject           VARCHAR2 (100);
        lc_message           VARCHAR2 (30000);
        lc_result_set        VARCHAR2 (3000);
        lc_attachment_file   VARCHAR2 (30);
        lc_db_name           VARCHAR2 (30);
        lc_exists            VARCHAR2 (1) := 'N';
    BEGIN
        msg ('Start of SEND_EMAIL');

        -- Derive Instance Name
        BEGIN
            SELECT name INTO lc_db_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_db_name   := 'TEST';
        END;

        lc_result_set   :=
               RPAD ('Status', 18, ' ')
            || 'Count'
            || CHR (10)
            || RPAD ('=', 25, '=')
            || CHR (10);

        FOR i IN (  SELECT DECODE (status,  'N', 'New',  'V', 'Valid',  'S', 'Success',  'R', 'Reprocess',  'E', 'Error',  'Other') status, COUNT (1) cnt
                      FROM xxdo.xxd_ppm_timesheet_stg_t a
                     WHERE request_id = gn_request_id
                  GROUP BY status
                  ORDER BY 1)
        LOOP
            lc_exists   := 'Y';
            lc_result_set   :=
                   lc_result_set
                || RPAD (i.status, 18, ' ')
                || i.cnt
                || CHR (10);
        END LOOP;

        IF lc_exists = 'N'
        THEN
            lc_result_set   :=
                'No Records to Process. Please review the timesheet data files.';
        END IF;

        lc_subject   := 'Planview Timesheet Processing Status';
        lc_message   :=
               'Hello Team,'
            || CHR (10)
            || CHR (10)
            || 'All Planview data files were processed and below are the details. '
            || CHR (10)
            || CHR (10)
            || lc_result_set
            || CHR (10)
            || 'Regards,'
            || CHR (10)
            || 'SYSADMIN';
        xxdo_mail_pkg.send_mail (
            pv_sender         => 'erp@deckers.com',
            pv_recipients     => gc_recipients,
            pv_ccrecipients   => NULL,
            pv_subject        => lc_db_name || ' - ' || lc_subject,
            pv_message        => lc_message,
            pv_attachments    => lc_attachment_file,
            xv_result         => lc_result,
            xv_result_msg     => lc_result_msg);
        msg ('Send Email Status: ' || lc_result);
        msg ('End of SEND_EMAIL');
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Exception in SEND_EMAIL: ' || SQLERRM);
    END send_email;

    -- ===============================================================================
    -- Main Procedure that will be called from the Concurrent Program
    -- ===============================================================================
    PROCEDURE main (retcode OUT VARCHAR2, errbuff OUT VARCHAR2, p_recipients IN VARCHAR2
                    , p_reprocess IN VARCHAR2)
    AS
        lc_status    VARCHAR2 (1);
        lc_err_msg   VARCHAR2 (4000);
    BEGIN
        msg ('Start of MAIN');
        gc_recipients   := p_recipients;

        IF p_reprocess = 'N'
        THEN
            msg (RPAD ('=', 100, '='));
            msg ('File Processing Begins');

            -- Process the Data Files
            xxd_ppm_timesheet_file_pkg.process_file (
                p_recipients   => p_recipients,
                x_status       => lc_status,
                x_err_msg      => lc_err_msg);
            msg (RPAD ('=', 100, '='));
        END IF;

        IF lc_status = 'S'
        THEN
            IF p_reprocess = 'N'
            THEN
                -- Insert Data into Staging Table
                insert_stg (x_status => lc_status, x_err_msg => lc_err_msg);
            ELSE
                -- Expectation is that the staging table data should be
                -- updated as Status = R (to reprocess)
                UPDATE xxdo.xxd_ppm_timesheet_stg_t
                   SET status = 'N', request_id = gn_request_id
                 WHERE status = 'R';

                COMMIT;
                lc_status   := 'S';
            END IF;

            IF lc_status = 'S'
            THEN
                validate_stg (x_status => lc_status, x_err_msg => lc_err_msg);

                IF lc_status = 'S'
                THEN
                    -- Insert Data into Interface Table
                    insert_interface (x_status    => lc_status,
                                      x_err_msg   => lc_err_msg);
                END IF;
            END IF;
        END IF;

        send_email;
        msg ('End of MAIN');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_err_msg   := 'Exception in MAIN: ' || SQLERRM;
            retcode      := '2';
            msg ('Exception in MAIN: ' || lc_err_msg);
    END main;
END xxd_ppm_timesheet_int_pkg;
/
