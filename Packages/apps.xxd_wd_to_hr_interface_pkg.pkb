--
-- XXD_WD_TO_HR_INTERFACE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WD_TO_HR_INTERFACE_PKG"
AS
    /*******************************************************************************
    * Program      : Workday to HR Interface - Deckers
    * File Name    : XXD_WD_TO_HR_INTERFACE_PKG
    * Language     : PL/SQL
    * Description  : This package is for Workday to HR Interface Program
    * History      :
    *
    * WHO                  Version  When         Desc
    * --------------------------------------------------------------------------
    * BT Technology Team   1.0      20-FEB-2015  Initial Creation
    * BT Technology Team   1.1      05-MAY-2015  Changed org id access
    * BT Technology Team   1.2      05-MAY-2015  Added NVL
    * BT Technology Team   1.3      23-JUL-2015  Changed Address for China for
    *                                            Defect# 2791
    * Bala Murugesan       1.4      24-JUN-2016  Successful records are marked as P;
    *                                            Identified by MARK_SUCCESS
    * Infosys              1.5      23-Aug-2016  INC0311558 - Employee Start Date should be equal to Sysdate
    *                                            Identified by INC0311558
    * Infosys              1.6      06-Oct-2016  INC0319071 - Employee Start Date should be less than or equal to Sysdate
    *                                            Identified by INC0319071
    * Infosys              1.7      18-Oct-2016  INC0319071 - Marking Record status to Reprocess when Employee Start Date is greater than Sysdate
    *                                            so that the record can be picked and can be reprocessed. Identified by INC0319071
    * GJensen              1.8      21-Jul-2017  CCR0006280
    * Viswanathan Pandian  1.9      09-Aug-2017  Fix for defect 695 for CCR0006280
    * Infosys     2.0      17-Nov-2017  CCR0006796 - Error records of Inactive employees  being sent from Workday to HR Interface without cost center
    * GJensen              2.1      15-Nov-2018  CCR0007631 - Add local name to the integration
    * --------------------------------------------------------------------------- */

    --------------------------------------------------------------------------------------
    -- Procedure to log messages in log file
    --------------------------------------------------------------------------------------
    --begin CCR0006280
    g_paygroup_lookup       CONSTANT VARCHAR2 (50) := 'XXD_WD_EMP_INT_PAY_GROUP';
    g_emp_currency_lookup   CONSTANT VARCHAR2 (50)
                                         := 'XXD_WD_EMP_INT_CURRENCY' ;
    g_view_app_id_purch     CONSTANT NUMBER := 201;

    --end CCR0006280

    PROCEDURE print_log_prc (p_msg IN VARCHAR2)
    IS
    BEGIN
        IF p_msg IS NOT NULL
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
        --DBMS_OUTPUT.put_line (p_msg);
        END IF;

        RETURN;
    END print_log_prc;

    --------------------------------------------------------------------------------------
    -- Procedure to print to output file
    --------------------------------------------------------------------------------------
    PROCEDURE print_output_prc (p_msg IN VARCHAR2)
    IS
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.output, p_msg);
    --DBMS_OUTPUT.put_line (p_msg);
    END print_output_prc;

    --------------------------------------------------------------------------------------
    -- Procedure to log error messages
    --------------------------------------------------------------------------------------
    PROCEDURE log_error_msg (p_record_id IN NUMBER, p_err_type IN VARCHAR2 DEFAULT gc_it_err, p_err_msg IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF p_err_type = gc_workday_err
        THEN
            UPDATE xxdo.xxd_wd_to_hr_intf_stg_t
               SET workday_err_msg = SUBSTR (workday_err_msg || p_err_msg, 1, 4000), last_update_date = gd_sysdate, last_updated_by = gn_user_id,
                   record_status = DECODE (record_status, gc_reprocess_status, gc_reprocess_status, gc_error_status)
             WHERE record_id = p_record_id;
        ELSIF p_err_type = gc_oracle_err
        THEN
            UPDATE xxdo.xxd_wd_to_hr_intf_stg_t
               SET oracle_err_msg = SUBSTR (oracle_err_msg || p_err_msg, 1, 4000), last_update_date = gd_sysdate, last_updated_by = gn_user_id,
                   record_status = gc_reprocess_status
             WHERE record_id = p_record_id;
        ELSE
            UPDATE xxdo.xxd_wd_to_hr_intf_stg_t
               SET it_err_msg = SUBSTR (it_err_msg || p_err_msg, 1, 4000), last_update_date = gd_sysdate, last_updated_by = gn_user_id,
                   record_status = DECODE (record_status, gc_reprocess_status, gc_reprocess_status, gc_error_status)
             WHERE record_id = p_record_id;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log_prc (
                   'Error updating IT error for record id: '
                || p_record_id
                || ' - '
                || SQLERRM);
    END;

    --------------------------------------------------------------------------------------
    -- Procedure to log success messages
    --------------------------------------------------------------------------------------
    PROCEDURE log_success_msg (p_record_id IN NUMBER, p_msg IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxdo.xxd_wd_to_hr_intf_stg_t
           SET success_message = SUBSTR (success_message || p_msg, 1, 4000), last_update_date = gd_sysdate, last_updated_by = gn_user_id,
               record_status = DECODE (record_status, gc_new_status, gc_processed_status, record_status)
         WHERE record_id = p_record_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log_prc (
                   'Error updating success message for record id: '
                || p_record_id
                || ' - '
                || SQLERRM);
    END;


    FUNCTION get_sob_id (p_cost_center VARCHAR2)
        RETURN NUMBER
    IS
        lv_company_code   VARCHAR2 (25);
        ln_sob_id         NUMBER;
    BEGIN
        BEGIN
            SELECT SUBSTR (p_cost_center, 1, INSTR (p_cost_center, '.') - 1)
              INTO lv_company_code
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_company_code   := NULL;
        END;

        -- ln_sob_id derivation
        IF lv_company_code IS NOT NULL
        THEN
            BEGIN
                SELECT glsv.ledger_id
                  INTO ln_sob_id
                  FROM gl_ledger_segment_values glsv, gl_ledgers gl
                 WHERE     gl.ledger_id = glsv.ledger_id
                       AND gl.ledger_category_code = 'PRIMARY'
                       AND gl.name != 'Deckers Group Consolidation'
                       AND glsv.segment_value = lv_company_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sob_id   := NULL;
            END;
        ELSE
            ln_sob_id   := NULL;
        END IF;

        RETURN ln_sob_id;
    END;

    FUNCTION get_ledger_currency (p_sob_id VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_currency_code   VARCHAR2 (25);
    BEGIN
        SELECT currency_code
          INTO lv_currency_code
          FROM gl_sets_of_books
         WHERE set_of_books_id = p_sob_id;


        RETURN lv_currency_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_currency_code   := NULL;
            RETURN lv_currency_code;
    END;

    --------------------------------------------------------------------------------------
    -- Main Procedure called by program
    --------------------------------------------------------------------------------------
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        -- Local Variables
        -- Local Variables for Submitting Custom Import Program
        ln_request_id           NUMBER;
        lb_wait                 BOOLEAN;
        lc_phase                VARCHAR2 (30);
        lc_status               VARCHAR2 (30);
        lc_dev_phase            VARCHAR2 (30);
        lc_dev_status           VARCHAR2 (30);
        ln_import_check         NUMBER;
        lc_message              VARCHAR2 (100);
        lv_import_prog_status   VARCHAR2 (100);
        lv_ret_code             VARCHAR2 (1);
        lv_message              VARCHAR2 (4000);
        lc_db_name              VARCHAR2 (50);
        lc_override_email_id    VARCHAR2 (1996);
        lc_from_address         VARCHAR2 (1996);
        le_mail_exception       EXCEPTION;
    BEGIN
        print_log_prc (
            'Begin Main Program with Request ID: ' || gn_request_id);

        UPDATE xxd_wd_to_hr_intf_stg_t wd_stg
           SET request_id = gn_request_id, wd_stg.record_status = gc_new_status, wd_stg.oracle_err_msg = NULL,
               wd_stg.workday_err_msg = NULL, wd_stg.it_err_msg = NULL, wd_stg.success_message = NULL,
               last_update_date = gd_sysdate, last_updated_by = gn_user_id
         WHERE NVL (wd_stg.record_status, gc_new_status) IN
                   (gc_new_status, gc_reprocess_status);


        print_log_prc ('Updated request_id for records:' || SQL%ROWCOUNT);
        COMMIT;

        DELETE xxd_wd_to_hr_intf_stg_t wd_stg_del
         WHERE     wd_stg_del.record_status <> gc_new_status
               AND EXISTS
                       (SELECT 1
                          FROM xxd_wd_to_hr_intf_stg_t wd_stg_new
                         WHERE     wd_stg_del.employee_id =
                                   wd_stg_new.employee_id
                               AND wd_stg_new.record_status = gc_new_status);

        print_log_prc ('Deleted duplicate records count:' || SQL%ROWCOUNT);
        COMMIT;


        print_log_prc ('Calling create_update_employee');
        -- Call to create/update Employee
        create_update_employee (lv_message, lv_ret_code);
        COMMIT;

        IF (lv_ret_code <> 0)
        THEN
            retcode   := lv_ret_code;
            errbuf    := lv_message;
            RETURN;
        END IF;

        print_log_prc ('Calling update_emp_start_date');
        update_emp_start_date;
        COMMIT;

        print_log_prc ('Calling create_update_location');
        -- Call procedure to create/ update Location
        create_update_location (lv_message, lv_ret_code);
        COMMIT;

        IF (lv_ret_code <> 0)
        THEN
            retcode   := lv_ret_code;
            errbuf    := lv_message;
            RETURN;
        END IF;

        print_log_prc ('Calling update_emp_assignments');
        -- Call procedure to update employee assignments
        update_emp_assignments (lv_message, lv_ret_code);
        COMMIT;

        IF (lv_ret_code <> 0)
        THEN
            retcode   := lv_ret_code;
            errbuf    := lv_message;
            RETURN;
        END IF;

        print_log_prc ('Calling create_supplier');
        -- Call procedure to create Supplier and site
        create_supplier (lv_message, lv_ret_code);
        COMMIT;

        IF (lv_ret_code <> 0)
        THEN
            retcode   := lv_ret_code;
            errbuf    := lv_message;
            RETURN;
        END IF;

        print_log_prc ('Calling update_suppliers');
        -- Call procedure to create Supplier and site
        update_suppliers;
        COMMIT;

        print_log_prc ('Calling end_date_employee');
        -- Call procedure to end date employee, supplier, site
        end_date_employee (lv_message, lv_ret_code);
        COMMIT;

        IF (lv_ret_code <> '0')
        THEN
            retcode   := lv_ret_code;
            errbuf    := lv_message;
            RETURN;
        ELSE
            -- MARK_SUCCESS - Start

            UPDATE xxd_wd_to_hr_intf_stg_t wd_stg
               SET wd_stg.record_status = 'P', last_update_date = gd_sysdate, last_updated_by = gn_user_id
             WHERE     wd_stg.record_status = gc_new_status
                   AND request_id = gn_request_id;

            COMMIT;
        -- MARK_SUCCESS - End

        END IF;


        -- Derive from and to email address if the instance is non prod
        BEGIN
            SELECT SYS_CONTEXT ('userenv', 'db_name')
              INTO lc_db_name
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_log_prc ('Error deriving DB name:' || SQLERRM);
                RAISE le_mail_exception;
        END;

        IF LOWER (lc_db_name) NOT LIKE '%prod%'
        THEN
            BEGIN
                --Fetch override email address for Non Prod Instances
                SELECT fscpv.parameter_value
                  INTO lc_override_email_id
                  FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
                 WHERE     fscpt.parameter_id = fscpv.parameter_id
                       AND fscpv.component_id = fsc.component_id
                       AND fscpt.display_name = 'Test Address'
                       AND fsc.component_name =
                           'Workflow Notification Mailer';
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log_prc (
                        'Error deriving OVERRIDE email address:' || SQLERRM);
                    RAISE le_mail_exception;
            END;

            IF lc_override_email_id IS NULL
            THEN
                print_log_prc ('Override email address cannot be null');
                RAISE le_mail_exception;
            END IF;
        END IF;

        print_log_prc ('lc_override_email_id: ' || lc_override_email_id);

        --Get From Email Address
        BEGIN
            SELECT fscpv.parameter_value
              INTO lc_from_address
              FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
             WHERE     fscpt.parameter_id = fscpv.parameter_id
                   AND fscpv.component_id = fsc.component_id
                   AND fscpt.display_name = 'Reply-to Address'
                   AND fsc.component_name = 'Workflow Notification Mailer';
        EXCEPTION
            WHEN OTHERS
            THEN
                print_log_prc (
                    'Error deriving FROM email address:' || SQLERRM);
                RAISE le_mail_exception;
        END;

        IF lc_from_address IS NULL
        THEN
            print_log_prc ('From email address cannot be null');
            RAISE le_mail_exception;
        END IF;

        print_log_prc ('lc_override_email_id: ' || lc_override_email_id);
        print_log_prc ('lc_from_address: ' || lc_from_address);
        email_oracle_err_msg (
            p_from_emailaddress        => lc_from_address,
            p_override_email_address   => lc_override_email_id);

        email_workday_err_msg (
            p_from_emailaddress        => lc_from_address,
            p_override_email_address   => lc_override_email_id);

        email_it_err_msg (p_from_emailaddress        => lc_from_address,
                          p_override_email_address   => lc_override_email_id);
    EXCEPTION
        WHEN le_mail_exception
        THEN
            print_log_prc ('Mail not sent');
        WHEN OTHERS
        THEN
            print_log_prc ('Error in Main Program  :' || SQLERRM);
    END main;

    --begin CCR0006280
    FUNCTION get_paygroup_lookup (p_ou        IN NUMBER,
                                  p_default   IN VARCHAR2 := NULL)
        RETURN VARCHAR
    IS
        l_tag   VARCHAR2 (150);
    BEGIN
        SELECT tag
          INTO l_tag
          FROM apps.fnd_lookup_values lkv, hr_all_organization_units hr
         WHERE     lkv.lookup_type = g_paygroup_lookup
               AND lkv.view_application_id = g_view_app_id_purch
               AND lkv.enabled_flag = 'Y'
               AND lkv.language = 'US'
               AND NVL (lkv.end_date_active, SYSDATE + 1) > SYSDATE
               AND hr.name = lkv.description
               AND hr.organization_id = p_ou;

        RETURN l_tag;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN p_default;
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_inv_currency_lookup (p_ou        IN NUMBER,
                                      p_default   IN VARCHAR2 := NULL)
        RETURN VARCHAR
    IS
        l_tag   VARCHAR2 (150);
    BEGIN
        SELECT tag
          INTO l_tag
          FROM apps.fnd_lookup_values lkv, hr_all_organization_units hr
         WHERE     lkv.lookup_type = g_emp_currency_lookup
               AND lkv.view_application_id = g_view_app_id_purch
               AND lkv.enabled_flag = 'Y'
               AND lkv.language = 'US'
               AND NVL (lkv.end_date_active, SYSDATE + 1) > SYSDATE
               AND hr.name = lkv.description
               AND hr.organization_id = p_ou;

        RETURN l_tag;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN p_default;
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --end CCR0006280

    --------------------------------------------------------------------------------------
    -- Procedure to create / update employee
    --------------------------------------------------------------------------------------
    PROCEDURE create_update_employee (p_message    OUT VARCHAR2,
                                      p_ret_code   OUT NUMBER)
    IS
        ln_business_group_id   NUMBER;
        lv_err_msg             VARCHAR2 (4000);
        ln_record_count        NUMBER;


        CURSOR update_emp_stg_cur IS
            SELECT wd_stg.record_id, wd_stg.legal_first_name, wd_stg.legal_last_name,
                   wd_stg.employee_email_address, ppf.effective_start_date employee_start_date, --wd_stg.employee_start_date, v1.2
                                                                                                ppf.person_id,
                   ppf.employee_number, ppf.object_version_number, paf.assignment_id
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg, per_all_people_f ppf, per_assignments_f paf
             WHERE     wd_stg.request_id = gn_request_id
                   AND ppf.employee_number = TO_CHAR (wd_stg.employee_id)
                   AND paf.person_id = ppf.person_id
                   AND NVL (ppf.effective_end_date, SYSDATE + 1) > SYSDATE
                   AND NVL (paf.effective_end_date, SYSDATE + 1) > SYSDATE
                   --Added NVL by BT Technology Team  v 1.2 on 19-MAY-2015
                   AND (NVL (wd_stg.legal_first_name, 'X') <> NVL (ppf.first_name, 'X') OR NVL (wd_stg.legal_last_name, 'X') <> NVL (ppf.last_name, 'X') OR NVL (wd_stg.employee_email_address, 'X') <> NVL (ppf.email_address, 'X'));

        CURSOR create_emp_stg_cur IS
            SELECT record_id, legal_first_name, legal_last_name,
                   employee_id, emp_type, employee_email_address,
                   employee_start_date, employment_end_date, management_level
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg
             WHERE     request_id = gn_request_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM per_all_people_f ppf
                             WHERE ppf.employee_number =
                                   TO_CHAR (wd_stg.employee_id));
    BEGIN
        print_log_prc ('Begin create_update_employee');


        print_log_prc ('Begin update employee');
        ln_record_count   := 0;

        FOR update_emp_stg_rec IN update_emp_stg_cur
        LOOP
            ln_record_count   := ln_record_count + 1;
            update_employee (
                p_record_id          => update_emp_stg_rec.record_id,
                p_person_id          => update_emp_stg_rec.person_id,
                p_assignment_id      => update_emp_stg_rec.assignment_id,
                p_legal_first_name   => update_emp_stg_rec.legal_first_name,
                p_legal_last_name    => update_emp_stg_rec.legal_last_name,
                p_emp_email_address   =>
                    update_emp_stg_rec.employee_email_address,
                p_employment_start_date   =>
                    update_emp_stg_rec.employee_start_date,
                p_employee_num       => update_emp_stg_rec.employee_number,
                p_object_version_number   =>
                    update_emp_stg_rec.object_version_number);
        END LOOP;

        COMMIT;
        print_log_prc (
               'No. of records retrieved for update employee '
            || ln_record_count);

        BEGIN
            SELECT business_group_id
              INTO ln_business_group_id
              FROM per_business_groups
             WHERE UPPER (name) = UPPER ('Setup Business Group');

            print_log_prc ('Business Group ID: ' || ln_business_group_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_business_group_id   := NULL;
                lv_err_msg             := 'Business group not defined. ';

                UPDATE xxdo.xxd_wd_to_hr_intf_stg_t
                   SET it_err_msg = it_err_msg || lv_err_msg, -- Check businees group
                                                              record_status = DECODE (record_status, gc_reprocess_status, gc_reprocess_status, gc_error_status), last_update_date = gd_sysdate,
                       last_updated_by = gn_user_id
                 WHERE request_id = gn_request_id;

                COMMIT;
        END;


        print_log_prc ('Begin create employee');
        ln_record_count   := 0;

        IF ln_business_group_id IS NOT NULL
        THEN
            FOR create_emp_stg_rec IN create_emp_stg_cur
            LOOP
                IF TRUNC (create_emp_stg_rec.employee_start_date) <=
                   TRUNC (SYSDATE) --Added If as part of INC0311558,INC0319071
                THEN
                    ln_record_count   := ln_record_count + 1;
                    create_employee (
                        p_record_id           => create_emp_stg_rec.record_id,
                        p_legal_first_name    =>
                            create_emp_stg_rec.legal_first_name,
                        p_legal_last_name     =>
                            create_emp_stg_rec.legal_last_name,
                        p_employee_num        => create_emp_stg_rec.employee_id,
                        p_email_address       =>
                            create_emp_stg_rec.employee_email_address,
                        p_hire_date           =>
                            create_emp_stg_rec.employee_start_date,
                        p_business_group_id   => ln_business_group_id);
                ELSE
                    print_log_prc (
                           'Employee Start Date is greater than Sysdate :: '
                        || create_emp_stg_rec.employee_id);

                    lv_err_msg   :=
                        'Employee Start Date is greater than Sysdate, Hence Employee record cannot be created';

                    UPDATE xxdo.xxd_wd_to_hr_intf_stg_t
                       SET it_err_msg = it_err_msg || lv_err_msg, -- Check businees group
                                                                  record_status = gc_reprocess_status, -- Modified for 1.7
                                                                                                       /*DECODE (record_status,
                                                                                                               gc_reprocess_status, gc_reprocess_status,
                                                                                                               gc_error_status),*/
                                                                                                       last_update_date = gd_sysdate,
                           last_updated_by = gn_user_id
                     WHERE     request_id = gn_request_id
                           AND employee_id = create_emp_stg_rec.employee_id;

                    COMMIT;
                END IF;                      -- End of If Condition INC0311558
            END LOOP;
        END IF;

        COMMIT;
        print_log_prc (
               'No. of records retrieved for creating employee '
            || ln_record_count);

        p_ret_code        := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_message    := 'Error in create_update_employee : ' || SQLERRM;
            p_ret_code   := 2;
            print_log_prc (p_message);
    END;

    --------------------------------------------------------------------------------------
    -- Procedure to create / update location
    --------------------------------------------------------------------------------------
    PROCEDURE create_update_location (p_message    OUT VARCHAR2,
                                      p_ret_code   OUT NUMBER)
    IS
        lv_err_msg                  VARCHAR2 (4000);
        lv_company_code             VARCHAR2 (25);
        ln_record_id                NUMBER;
        lv_cost_center              xxd_wd_to_hr_intf_stg_t.cost_center%TYPE;
        lv_location_name            hr_locations.location_code%TYPE;
        ln_location_id              NUMBER;
        ln_object_version_number    NUMBER;
        lv_attribute4               VARCHAR2 (150);
        lv_loc_attribute_category   VARCHAR2 (30);

        lv_iso_country_code         VARCHAR2 (30);
        lv_country                  VARCHAR2 (50);
        lv_state                    VARCHAR2 (30);
        lv_address_line2            VARCHAR2 (240);
        lv_city                     VARCHAR2 (30);


        CURSOR location_cur IS
              SELECT record_id, employee_id, location_name,
                     address_line_1, address_line_2, address_line_3,
                     city, zipcode, country,
                     county, state_province, cost_center
                FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg
               WHERE     request_id = gn_request_id
                     --Start Exists Condition INC0311558
                     AND EXISTS
                             (SELECT 1
                                FROM apps.per_all_people_f
                               WHERE employee_number =
                                     TO_CHAR (wd_stg.employee_id))
            --End Exists Condition INC0311558
            ORDER BY location_name;
    BEGIN
        print_log_prc ('Begin create_update_location');

        FOR location_rec IN location_cur
        LOOP
            ln_record_id                := location_rec.record_id;
            lv_cost_center              := location_rec.cost_center;
            lv_location_name            := NULL;
            ln_location_id              := NULL;
            ln_object_version_number    := NULL;
            lv_attribute4               := NULL;
            lv_loc_attribute_category   := NULL;
            lv_iso_country_code         := NULL;
            lv_country                  := NULL;
            lv_address_line2            := location_rec.address_line_2;
            lv_city                     := location_rec.city;
            lv_state                    := NULL;

            IF lv_cost_center IS NULL
            THEN
                lv_err_msg   :=
                       'Cost center is null for EmployeeID '
                    || location_rec.employee_id
                    || '. ';

                log_error_msg (p_record_id   => ln_record_id,
                               p_err_type    => gc_workday_err,
                               p_err_msg     => lv_err_msg);
            ELSIF location_rec.country IS NULL
            THEN
                lv_err_msg   :=
                       'Country is null for EmployeeID '
                    || location_rec.employee_id
                    || '. ';

                log_error_msg (p_record_id   => ln_record_id,
                               p_err_type    => gc_workday_err,
                               p_err_msg     => lv_err_msg);
            ELSIF location_rec.address_line_1 IS NULL
            THEN
                lv_err_msg   := 'Address Line1 cannot be null. ';

                log_error_msg (p_record_id   => ln_record_id,
                               p_err_type    => gc_workday_err,
                               p_err_msg     => lv_err_msg);
            ELSE
                -- Deriving the Company code from the 5segmentCostcenter(from CSV).
                BEGIN
                    SELECT SUBSTR (lv_cost_center, 1, INSTR (lv_cost_center, '.') - 1)
                      INTO lv_company_code
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_company_code   := NULL;
                        lv_err_msg        :=
                               'Error retrieving company code. '
                            || SQLERRM
                            || '. ';
                        log_error_msg (p_record_id   => ln_record_id,
                                       p_err_msg     => lv_err_msg);
                END;

                IF lv_company_code IS NULL
                THEN
                    lv_err_msg   := 'Company Code cannot be null. '; --Workday error
                    log_error_msg (p_record_id   => ln_record_id,
                                   p_err_msg     => lv_err_msg);
                ELSE
                    lv_location_name   :=
                           'E'
                        || lv_company_code
                        || '-'
                        || location_rec.location_name;

                    BEGIN
                        SELECT location_id, attribute4, attribute_category,
                               object_version_number
                          INTO ln_location_id, lv_attribute4, lv_loc_attribute_category, ln_object_version_number
                          FROM hr_locations
                         WHERE location_code = lv_location_name;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_location_id   := NULL;
                        WHEN OTHERS
                        THEN
                            ln_location_id   := NULL;
                            lv_err_msg       :=
                                   'Error retrieving location id. '
                                || SQLERRM
                                || '. ';
                            log_error_msg (p_record_id   => ln_record_id,
                                           p_err_msg     => lv_err_msg);
                    END;

                    IF location_rec.country IS NOT NULL
                    THEN
                        -- Deriving the Country Name using the Country ISO Code

                        BEGIN
                            -- Ignoring the Trailing commas (E.g. USA,,,)


                            IF (INSTR (location_rec.country, ',', 1)) > 0
                            THEN
                                lv_iso_country_code   :=
                                    SUBSTR (
                                        location_rec.country,
                                        1,
                                          INSTR (location_rec.country,
                                                 ',',
                                                 1)
                                        - 1);
                            ELSE
                                lv_iso_country_code   := location_rec.country;
                            END IF;


                            SELECT territory_code
                              INTO lv_country
                              FROM fnd_territories_vl
                             WHERE iso_territory_code = lv_iso_country_code;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_err_msg   :=
                                       lv_iso_country_code
                                    || ' is invalid country code. ';

                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                        END;
                    END IF;


                    IF     lv_country = 'US'
                       AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM fnd_common_lookups
                             WHERE     lookup_type LIKE 'US_STATE'
                                   AND meaning = location_rec.state_province
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF     lv_country = 'AU'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM fnd_common_lookups
                             WHERE     lookup_type LIKE 'AU_STATE'
                                   AND meaning = location_rec.state_province
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF     lv_country = 'IN'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM hr_lookups
                             WHERE     lookup_type LIKE 'IN_STATES'
                                   AND meaning = location_rec.state_province
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF     lv_country = 'MX'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM fnd_common_lookups
                             WHERE     lookup_type LIKE 'MX_STATE'
                                   AND meaning = location_rec.state_province
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF     lv_country = 'MY'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM fnd_common_lookups
                             WHERE     lookup_type LIKE 'MY_STATE'
                                   AND meaning = location_rec.state_province
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF lv_country = 'CN'
                    THEN
                        --Start Modification by BT Technology Team v1.3 on 23-JUL-2015 for Defect# 2791
                        IF location_rec.state_province IS NULL
                        THEN
                            lv_city   := location_rec.city;
                        ELSE
                            lv_city   :=
                                   location_rec.city
                                || ', '
                                || location_rec.state_province;
                        END IF;
                    /*lv_address_line2 := lv_address_line2 || location_rec.city;
                    lv_state := NULL;

                    IF location_rec.state_province IS NOT NULL
                    THEN
                       BEGIN
                          SELECT lookup_code
                            INTO lv_city
                            FROM hr_lookups
                           WHERE     lookup_type LIKE 'CN_PROVINCE'
                                 AND UPPER (meaning) LIKE
                                           UPPER (location_rec.state_province)
                                        || '%'
                                 AND NVL (end_date_active, SYSDATE + 1) >
                                        SYSDATE
                                 AND enabled_flag = 'Y';
                       EXCEPTION
                          WHEN NO_DATA_FOUND
                          THEN
                             lv_state := NULL;

                             lv_err_msg :=
                                   location_rec.state_province
                                || ' is invalid State . ';
                             log_error_msg (p_record_id   => ln_record_id,
                                            p_err_type    => gc_workday_err,
                                            p_err_msg     => lv_err_msg);
                          WHEN OTHERS
                          THEN
                             lv_state := NULL;
                             lv_err_msg :=
                                'Error retrieving state. ' || SQLERRM || '. ';
                             log_error_msg (p_record_id   => ln_record_id,
                                            p_err_msg     => lv_err_msg);
                       END;
                    ELSE
                       lv_state := NULL;
                    END IF;*/
                    --End Modification by BT Technology Team v1.3 on 23-JUL-2015 for Defect# 2791
                    ELSIF     lv_country = 'AT'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM hr_lookups
                             WHERE     lookup_type LIKE 'AT_PROVINCE'
                                   AND UPPER (meaning) LIKE
                                              UPPER (
                                                  location_rec.state_province)
                                           || '%'
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF     lv_country = 'CA'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM hr_lookups
                             WHERE     lookup_type LIKE 'CA_PROVINCE'
                                   AND UPPER (meaning) LIKE
                                              UPPER (
                                                  location_rec.state_province)
                                           || '%'
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF     lv_country = 'ES'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM hr_lookups
                             WHERE     lookup_type LIKE 'ES_PROVINCE'
                                   AND UPPER (meaning) LIKE
                                              UPPER (
                                                  location_rec.state_province)
                                           || '%'
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF     lv_country = 'IT'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM hr_lookups
                             WHERE     lookup_type LIKE 'IT_PROVINCE'
                                   AND UPPER (meaning) LIKE
                                              UPPER (
                                                  location_rec.state_province)
                                           || '%'
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF     lv_country = 'PL'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM hr_lookups
                             WHERE     lookup_type LIKE 'PL_PROVINCE'
                                   AND UPPER (meaning) LIKE
                                              UPPER (
                                                  location_rec.state_province)
                                           || '%'
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSIF     lv_country = 'ZA'
                          AND location_rec.state_province IS NOT NULL
                    THEN
                        BEGIN
                            SELECT lookup_code
                              INTO lv_state
                              FROM hr_lookups
                             WHERE     lookup_type LIKE 'ZA_PROVINCE'
                                   AND UPPER (meaning) LIKE
                                              UPPER (
                                                  location_rec.state_province)
                                           || '%'
                                   AND NVL (end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lv_state   := NULL;

                                lv_err_msg   :=
                                       location_rec.state_province
                                    || ' is invalid State . ';
                                log_error_msg (
                                    p_record_id   => ln_record_id,
                                    p_err_type    => gc_workday_err,
                                    p_err_msg     => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                lv_state   := NULL;
                                lv_err_msg   :=
                                       'Error retrieving state. '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (p_record_id   => ln_record_id,
                                               p_err_msg     => lv_err_msg);
                        END;
                    ELSE
                        lv_state   := location_rec.state_province;
                    END IF;


                    IF ln_location_id IS NULL
                    THEN
                        create_location (p_record_id => ln_record_id, p_location => lv_location_name, p_workday_location => location_rec.location_name, p_address_line_1 => location_rec.address_line_1, p_address_line_2 => lv_address_line2, p_address_line_3 => location_rec.address_line_3, p_city => lv_city, p_zipcode => location_rec.zipcode, p_country => lv_country, p_county => location_rec.county, p_state_province => lv_state, p_cost_center => location_rec.cost_center
                                         , p_company_code => lv_company_code);
                    ELSE
                        IF (lv_loc_attribute_category = 'Workday Location' AND lv_attribute4 = 'Y')
                        THEN
                            --update location
                            update_location (
                                p_record_id        => ln_record_id,
                                p_location_id      => ln_location_id,
                                p_object_version_number   =>
                                    ln_object_version_number,
                                p_address_line_1   =>
                                    location_rec.address_line_1,
                                p_address_line_2   => lv_address_line2,
                                p_address_line_3   =>
                                    location_rec.address_line_3,
                                p_city             => lv_city,
                                p_zipcode          => location_rec.zipcode,
                                p_country          => lv_country,
                                p_county           => location_rec.county,
                                p_state_province   => lv_state,
                                p_cost_center      => location_rec.cost_center,
                                p_company_code     => lv_company_code);
                        ELSE
                            lv_err_msg   :=
                                'Cannot update location. Not a Workday Location. ';
                            log_error_msg (p_record_id   => ln_record_id,
                                           p_err_msg     => lv_err_msg);
                        END IF;
                    END IF;
                END IF;
            END IF;
        END LOOP;

        print_log_prc ('End create_update_location');
        p_ret_code   := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_message    := 'Error in create_update_location : ' || SQLERRM;
            p_ret_code   := 2;
            print_log_prc (p_message);
    END create_update_location;

    --------------------------------------------------------------------------------------
    -- Procedure to create location
    --------------------------------------------------------------------------------------
    PROCEDURE create_location (p_record_id IN NUMBER, p_location IN VARCHAR2, p_workday_location IN VARCHAR2, p_address_line_1 IN VARCHAR2, p_address_line_2 IN VARCHAR2, p_address_line_3 IN VARCHAR2, p_city IN VARCHAR2, p_zipcode IN VARCHAR2, p_country IN VARCHAR2, p_county IN VARCHAR2, p_state_province IN VARCHAR2, p_cost_center IN VARCHAR2
                               , p_company_code IN VARCHAR2)
    IS
        -- Local Variables
        ln_location_id             NUMBER;
        ln_object_version_number   NUMBER;

        lv_address_style           VARCHAR2 (100);
        lv_address_style_code      VARCHAR2 (50);
        ln_inv_org_id              NUMBER;
        lv_style                   VARCHAR2 (30);
        lv_region1                 VARCHAR2 (120);
        lv_region2                 VARCHAR2 (120);
        lv_state_region            VARCHAR2 (30);
        lv_county_region           VARCHAR2 (30);
        lv_status                  VARCHAR2 (1);
        lv_msg                     VARCHAR2 (240);
        lv_err_msg                 VARCHAR2 (2000);
        lv_workday_err_msg         VARCHAR2 (2000);
        lv_iso_country_code        VARCHAR2 (30);
    BEGIN
        lv_status    := 'S';

        -- print_log_prc ('Begin create_location');



        lv_err_msg   := 'Location not created due to -';

        -- Deriving the Address Style Code
        BEGIN
            SELECT ood.organization_id
              INTO ln_inv_org_id
              FROM fnd_lookup_values flv, org_organization_definitions ood
             WHERE     flv.lookup_type = 'XXDO_COMPANY_INV_ORG'
                   AND flv.language = USERENV ('LANG')
                   AND ood.organization_name = flv.description
                   AND flv.lookup_code = p_company_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_status   := 'E';
                lv_err_msg   :=
                       lv_err_msg
                    || 'Inventory Org definition incorrect in lookup. ';
        END;


        BEGIN
            SELECT iso_territory_code
              INTO lv_iso_country_code
              FROM fnd_territories_vl
             WHERE territory_code = p_country;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_iso_country_code   := NULL;
            WHEN OTHERS
            THEN
                lv_status   := 'E';
                lv_err_msg   :=
                    lv_err_msg || 'Unable to derive iso country code. ';
        END;

        -- Deriving the Address Style from the Mapping Lookup
        BEGIN
            SELECT tl.descriptive_flex_context_code
              INTO lv_address_style_code
              FROM fnd_lookup_values flv, fnd_descr_flex_contexts_tl tl
             WHERE     flv.lookup_type = 'XXDO_ADDSTYLE'
                   AND flv.language = USERENV ('LANG')
                   AND tl.descriptive_flexfield_name = 'Address Location'
                   AND tl.language = USERENV ('LANG')
                   AND tl.descriptive_flex_context_name = flv.description
                   AND flv.lookup_code = lv_iso_country_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_status   := 'E';
                lv_err_msg   :=
                       lv_err_msg
                    || 'Address Style definition incorrect in lookup. ';
        END;


        IF p_state_province IS NOT NULL
        THEN
            BEGIN
                SELECT application_column_name
                  INTO lv_state_region
                  FROM fnd_descr_flex_col_usage_vl
                 WHERE     descriptive_flexfield_name = 'Address Location'
                       AND descriptive_flex_context_code =
                           lv_address_style_code
                       AND UPPER (end_user_column_name) IN
                               ('STATE', 'PROVINCE');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_state_region   := NULL;
                WHEN OTHERS
                THEN
                    lv_state_region   := NULL;
                    lv_status         := 'E';
                    lv_err_msg        :=
                        lv_err_msg || 'Error deriving province column. ';
            END;

            IF lv_state_region = 'REGION_1'
            THEN
                lv_region1   := p_state_province;
            ELSE
                IF lv_state_region = 'REGION_2'
                THEN
                    lv_region2   := p_state_province;
                END IF;
            END IF;
        END IF;

        IF p_county IS NOT NULL
        THEN
            BEGIN
                SELECT application_column_name
                  INTO lv_county_region
                  FROM fnd_descr_flex_col_usage_vl
                 WHERE     descriptive_flexfield_name = 'Address Location'
                       AND descriptive_flex_context_code =
                           lv_address_style_code
                       AND UPPER (end_user_column_name) IN ('COUNTY');
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_county_region   := NULL;
                    lv_status          := 'E';
                    lv_err_msg         :=
                        lv_err_msg || 'County Not Available In DFF.';
            END;
        END IF;

        IF lv_county_region = 'REGION_1'
        THEN
            lv_region1   := p_county;
        ELSE
            IF lv_county_region = 'REGION_2'
            THEN
                lv_region2   := p_county;
            END IF;
        END IF;

        IF lv_status <> 'E'
        THEN
            -- ln_inv_org_id := 160;
            -- lv_address_style_code := NULL;

            BEGIN
                hr_location_api.create_location (
                    p_validate                    => FALSE,
                    p_effective_date              => SYSDATE,
                    p_location_code               => p_location,
                    p_description                 => p_location,
                    p_timezone_code               => NULL,
                    p_tp_header_id                => NULL,
                    p_ece_tp_location_code        => NULL,
                    p_style                       => lv_address_style_code, -- Mapping lookup
                    p_address_line_1              => p_address_line_1,
                    p_address_line_2              => p_address_line_2,
                    p_address_line_3              => p_address_line_3,
                    p_town_or_city                => p_city,
                    p_region_1                    => lv_region1,   --p_county,
                    p_region_2                    => lv_region2, --p_state_province,
                    p_region_3                    => NULL,
                    p_country                     => p_country,
                    p_postal_code                 => p_zipcode,
                    p_bill_to_site_flag           => 'Y',
                    p_designated_receiver_id      => NULL,
                    p_in_organization_flag        => 'Y',
                    p_inactive_date               => NULL,
                    p_operating_unit_id           => NULL,
                    p_inventory_organization_id   => ln_inv_org_id, -- Mapping lookup
                    p_office_site_flag            => 'Y',
                    p_receiving_site_flag         => 'Y',
                    p_ship_to_location_id         => NULL,   -- Mapping lookup
                    p_ship_to_site_flag           => 'Y',
                    p_attribute_category          => 'Workday Location',
                    p_attribute4                  => 'Y', --p_workday_location,
                    p_location_id                 => ln_location_id,
                    p_object_version_number       => ln_object_version_number);


                IF ln_location_id IS NOT NULL
                THEN
                    lv_msg   :=
                           'Location Created with location id:'
                        || ln_location_id
                        || '. ';

                    log_success_msg (p_record_id   => p_record_id,
                                     p_msg         => lv_msg);

                    print_log_prc (lv_msg);
                ELSE
                    lv_err_msg   := 'Location not created. ';
                    log_error_msg (p_record_id   => p_record_id,
                                   p_err_msg     => lv_err_msg);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        'Api Error creating location ' || SQLERRM || '. ';


                    log_error_msg (p_record_id   => p_record_id,
                                   p_err_type    => gc_workday_err,
                                   p_err_msg     => lv_err_msg);

                    print_log_prc (
                        'Location Api didnot create a record - ' || SQLERRM);
            END;
        ELSE
            log_error_msg (p_record_id => p_record_id, p_err_msg => lv_err_msg);
        END IF;
    --print_log_prc ('End create_location');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_status    := 'E';
            lv_err_msg   := 'Location Not Created. ' || SQLERRM || '. ';


            log_error_msg (p_record_id => p_record_id, p_err_msg => lv_err_msg);
            print_log_prc (
                   'Exception in Creating Location...'
                || SQLERRM
                || '. for record_id'
                || p_record_id);
    END create_location;


    --------------------------------------------------------------------------------------
    -- Procedure to update location
    --------------------------------------------------------------------------------------
    PROCEDURE update_location (p_record_id IN NUMBER, p_location_id IN NUMBER, p_object_version_number IN NUMBER, p_address_line_1 IN VARCHAR2, p_address_line_2 IN VARCHAR2, p_address_line_3 IN VARCHAR2, p_city IN VARCHAR2, p_zipcode IN VARCHAR2, p_country IN VARCHAR2, p_county IN VARCHAR2, p_state_province IN VARCHAR2, p_cost_center IN VARCHAR2
                               , p_company_code IN VARCHAR2)
    IS
        -- Local Variables
        ln_object_version_number   NUMBER;

        lv_address_style           VARCHAR2 (100);
        lv_address_style_code      VARCHAR2 (50);
        ln_inv_org_id              NUMBER;
        lv_style                   VARCHAR2 (30);
        lv_region1                 VARCHAR2 (120);
        lv_region2                 VARCHAR2 (120);
        lv_state_region            VARCHAR2 (30);
        lv_county_region           VARCHAR2 (30);
        lv_status                  VARCHAR2 (1);
        lv_msg                     VARCHAR2 (240);
        lv_err_msg                 VARCHAR2 (2000);
        lv_iso_country_code        VARCHAR2 (30);
        ln_update_count            NUMBER;
    BEGIN
        lv_status                  := 'S';
        ln_object_version_number   := p_object_version_number;


        lv_err_msg                 := 'Location not updated due to -';

        -- Deriving the Address Style Code
        BEGIN
            SELECT ood.organization_id
              INTO ln_inv_org_id
              FROM fnd_lookup_values flv, org_organization_definitions ood
             WHERE     flv.lookup_type = 'XXDO_COMPANY_INV_ORG'
                   AND flv.language = USERENV ('LANG')
                   AND ood.organization_name = flv.description
                   AND flv.lookup_code = p_company_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_status   := 'E';
                lv_err_msg   :=
                       lv_err_msg
                    || 'InventoryOrg definition incorrect in lookup. ';
        END;


        BEGIN
            SELECT iso_territory_code
              INTO lv_iso_country_code
              FROM fnd_territories_vl
             WHERE territory_code = p_country;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_iso_country_code   := NULL;
            WHEN OTHERS
            THEN
                lv_status   := 'E';
                lv_err_msg   :=
                    lv_err_msg || 'Unable to derive iso country code. ';
        END;

        -- Deriving the Address Style from the Mapping Lookup
        BEGIN
            SELECT tl.descriptive_flex_context_code
              INTO lv_address_style_code
              FROM fnd_lookup_values flv, fnd_descr_flex_contexts_tl tl
             WHERE     flv.lookup_type = 'XXDO_ADDSTYLE'
                   AND flv.language = USERENV ('LANG')
                   AND tl.descriptive_flexfield_name = 'Address Location'
                   AND tl.language = USERENV ('LANG')
                   AND tl.descriptive_flex_context_name = flv.description
                   AND flv.lookup_code = lv_iso_country_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_status   := 'E';
                lv_err_msg   :=
                       lv_err_msg
                    || 'AddressStyle definition incorrect in lookup. ';
        END;

        --print_log_prc ('Validated Creating Location..calling API .. : ' || lv_status);

        IF p_state_province IS NOT NULL
        THEN
            BEGIN
                SELECT application_column_name
                  INTO lv_state_region
                  FROM fnd_descr_flex_col_usage_vl
                 WHERE     descriptive_flexfield_name = 'Address Location'
                       AND descriptive_flex_context_code =
                           lv_address_style_code
                       AND UPPER (end_user_column_name) IN
                               ('STATE', 'PROVINCE');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_state_region   := NULL;
                WHEN OTHERS
                THEN
                    lv_state_region   := NULL;
                    lv_status         := 'E';
                    lv_err_msg        :=
                        lv_err_msg || 'Error deriving province column. ';
            END;

            IF lv_state_region = 'REGION_1'
            THEN
                lv_region1   := p_state_province;
            ELSE
                IF lv_state_region = 'REGION_2'
                THEN
                    lv_region2   := p_state_province;
                END IF;
            END IF;
        END IF;

        IF p_county IS NOT NULL
        THEN
            BEGIN
                SELECT application_column_name
                  INTO lv_county_region
                  FROM fnd_descr_flex_col_usage_vl
                 WHERE     descriptive_flexfield_name = 'Address Location'
                       AND descriptive_flex_context_code =
                           lv_address_style_code
                       AND UPPER (end_user_column_name) IN ('COUNTY');
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_county_region   := NULL;
                    lv_status          := 'E';
                    lv_err_msg         :=
                        lv_err_msg || 'County Not Available In DFF.';
            END;
        END IF;

        IF lv_county_region = 'REGION_1'
        THEN
            lv_region1   := p_county;
        ELSE
            IF lv_county_region = 'REGION_2'
            THEN
                lv_region2   := p_county;
            END IF;
        END IF;

        IF lv_status <> 'E'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_update_count
                  FROM hr_locations
                 WHERE     address_line_1 = p_address_line_1
                       AND NVL (address_line_2, 'X') =
                           NVL (p_address_line_2, 'X')
                       AND NVL (address_line_3, 'X') =
                           NVL (p_address_line_3, 'X')
                       AND NVL (country, 'X') = NVL (p_country, 'X')
                       AND NVL (inventory_organization_id, 0) =
                           NVL (ln_inv_org_id, 0)
                       AND NVL (postal_code, 'X') = NVL (p_zipcode, 'X')
                       AND NVL (region_1, 'X') = NVL (lv_region1, 'X')
                       AND NVL (region_2, 'X') = NVL (lv_region2, 'X')
                       AND NVL (style, 'X') =
                           NVL (lv_address_style_code, 'X')
                       AND NVL (town_or_city, 'X') = NVL (p_city, 'X')
                       AND NVL (style, 'X') =
                           NVL (lv_address_style_code, 'X');
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_update_count   := 0;
                WHEN OTHERS
                THEN
                    ln_update_count   := 1;
                    lv_err_msg        := 'Error :' || SQLERRM;
                    log_error_msg (p_record_id   => p_record_id,
                                   p_err_msg     => lv_err_msg);
            END;

            IF ln_update_count = 0
            THEN
                BEGIN
                    hr_location_api.update_location (
                        p_validate                    => FALSE,
                        p_effective_date              => SYSDATE,
                        p_location_id                 => p_location_id,
                        p_address_line_1              => p_address_line_1,
                        p_address_line_2              => p_address_line_2,
                        p_address_line_3              => p_address_line_3,
                        p_bill_to_site_flag           => 'Y',
                        p_country                     => p_country,
                        p_in_organization_flag        => 'Y',
                        p_operating_unit_id           => NULL,
                        p_inventory_organization_id   => ln_inv_org_id,
                        p_office_site_flag            => 'Y',
                        p_postal_code                 => p_zipcode,
                        p_receiving_site_flag         => 'Y',
                        p_region_1                    => lv_region1,
                        p_region_2                    => lv_region2,
                        p_ship_to_site_flag           => 'Y',
                        p_style                       => lv_address_style_code -- Mapping lookup
                                                                              ,
                        p_town_or_city                => p_city,
                        p_object_version_number       =>
                            ln_object_version_number);

                    lv_msg   := 'Location Updated. ';
                    log_success_msg (p_record_id   => p_record_id,
                                     p_msg         => lv_msg);
                --print_log_prc (lv_msg);

                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_err_msg   :=
                            'Location not updated. ' || SQLERRM || '. ';
                        log_error_msg (p_record_id   => p_record_id,
                                       p_err_msg     => lv_err_msg);
                        print_log_prc (
                               'Location Api didnot create a record - '
                            || SQLERRM);
                END;
            END IF;
        ELSE
            log_error_msg (p_record_id => p_record_id, p_err_msg => lv_err_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_status   := 'E';
            lv_err_msg   :=
                lv_err_msg || 'Location not updated ' || SQLERRM || '. ';

            log_error_msg (p_record_id => p_record_id, p_err_msg => lv_err_msg);


            print_log_prc ('Exception in Updating Location...' || SQLERRM);
    END update_location;

    --------------------------------------------------------------------------------------
    -- Procedure to create employee
    --------------------------------------------------------------------------------------
    PROCEDURE create_employee (p_record_id IN NUMBER, p_legal_first_name IN VARCHAR2, p_legal_last_name IN VARCHAR2, p_employee_num IN VARCHAR2, p_email_address IN VARCHAR2, p_hire_date IN DATE
                               , p_business_group_id IN NUMBER)
    IS
        -- Local Variables
        -- ---------------------------------
        lv_err_msg                 VARCHAR2 (240);
        lv_msg                     VARCHAR2 (240);
        -- Out Variables for Create Employee
        -- ---------------------------------
        ln_person_id               NUMBER;
        ln_assignment_id           NUMBER;
        ln_per_obj_ver_number      NUMBER;
        ln_assign_obj_ver_number   NUMBER;
        ld_eff_start_date          DATE;
        ld_eff_end_date            DATE;
        lv_full_name               VARCHAR2 (240);
        ln_comment_id              NUMBER;
        ln_assign_seq              NUMBER;
        lv_assign_number           VARCHAR2 (30);
        lb_name_comb_warn          BOOLEAN;
        lb_assign_payroll_warn     BOOLEAN;
        ln_employee_number         VARCHAR2 (30);
    BEGIN
        --print_log_prc ('Begin create_employee');

        ln_employee_number   := p_employee_num;

        hr_employee_api.create_employee (
            p_validate                       => FALSE,
            p_hire_date                      => p_hire_date,
            p_business_group_id              => p_business_group_id,
            p_last_name                      => p_legal_last_name,
            p_sex                            => 'M',                    --'U',
            p_person_type_id                 => NULL,
            p_date_of_birth                  => NULL,
            p_email_address                  => p_email_address,
            p_employee_number                => ln_employee_number,
            p_first_name                     => p_legal_first_name,
            p_expense_check_send_to_addres   => 'O',
            /************Output parameters*******************/
            p_person_id                      => ln_person_id,
            p_assignment_id                  => ln_assignment_id,
            p_per_object_version_number      => ln_per_obj_ver_number,
            p_asg_object_version_number      => ln_assign_obj_ver_number,
            p_per_effective_start_date       => ld_eff_start_date,
            p_per_effective_end_date         => ld_eff_end_date,
            p_full_name                      => lv_full_name,
            p_per_comment_id                 => ln_comment_id,
            p_assignment_sequence            => ln_assign_seq,
            p_assignment_number              => lv_assign_number,
            p_name_combination_warning       => lb_name_comb_warn,
            p_assign_payroll_warning         => lb_assign_payroll_warn);


        IF ln_person_id IS NOT NULL
        THEN
            lv_msg   := 'Oracle Employee ID ' || ln_person_id || ' created. ';
            log_success_msg (p_record_id => p_record_id, p_msg => lv_msg);
        ELSE
            lv_err_msg   := 'Employee not created. ';

            log_error_msg (p_record_id => p_record_id, p_err_msg => lv_err_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg   := 'Error Creating Employee-' || SQLERRM || '. ';

            log_error_msg (p_record_id => p_record_id, p_err_msg => lv_err_msg);

            print_log_prc (
                   'Exception in Creating Employee :'
                || SQLERRM
                || '. for record_id '
                || p_record_id);
    END create_employee;

    --------------------------------------------------------------------------------------
    -- Procedure to update employee
    --------------------------------------------------------------------------------------
    PROCEDURE update_employee (p_record_id IN NUMBER, p_person_id IN NUMBER, p_assignment_id IN NUMBER, p_legal_first_name IN VARCHAR2, p_legal_last_name IN VARCHAR2, p_emp_email_address IN VARCHAR2
                               , p_employment_start_date IN DATE, p_employee_num IN VARCHAR2, p_object_version_number IN NUMBER)
    IS
        ln_employee_number            VARCHAR2 (30);
        ln_object_version_number      NUMBER;
        ln_person_id                  NUMBER;
        lc_dt_ud_mode                 VARCHAR2 (100) := NULL;
        lv_msg                        VARCHAR2 (2000);

        -- Out Variables for Find Date Track Mode API
        -- ----------------------------------------------------------------
        lb_correction                 BOOLEAN;
        lb_update                     BOOLEAN;
        lb_update_override            BOOLEAN;
        lb_update_change_insert       BOOLEAN;

        -- Out Variables for Update Employee API
        -- -----------------------------------------------------------
        ld_effective_start_date       DATE;
        ld_effective_end_date         DATE;
        lv_full_name                  per_all_people_f.full_name%TYPE;
        ln_comment_id                 per_all_people_f.comment_id%TYPE;
        lb_name_combination_warning   BOOLEAN;
        lb_assign_payroll_warning     BOOLEAN;
        lb_orig_hire_warning          BOOLEAN;
    BEGIN
        ln_employee_number         := p_employee_num;
        ln_object_version_number   := p_object_version_number;
        ln_person_id               := p_person_id;



        /* Commented for v1.2
        -- Find Date Track Mode
        -- --------------------------------
        dt_api.find_dt_upd_modes (                        -- Input Data Elements
           -- ------------------------------
           p_effective_date         => TRUNC (SYSDATE),
           p_base_table_name        => 'PER_ALL_ASSIGNMENTS_F',
           p_base_key_column        => 'ASSIGNMENT_ID',
           p_base_key_value         => p_assignment_id,
           -- Output data elements
           -- -------------------------------
           p_correction             => lb_correction,
           p_update                 => lb_update,
           p_update_override        => lb_update_override,
           p_update_change_insert   => lb_update_change_insert);

        IF (lb_update_override = TRUE OR lb_update_change_insert = TRUE)
        THEN
           -- UPDATE_OVERRIDE
           -- ---------------------------------
           lc_dt_ud_mode := 'UPDATE_OVERRIDE';
        END IF;



        IF (lb_correction = TRUE)
        THEN
           -- CORRECTION
           -- ----------------------
           lc_dt_ud_mode := 'CORRECTION';
        END IF;

        IF (lb_update = TRUE)
        THEN
           -- UPDATE
           -- --------------
           lc_dt_ud_mode := 'UPDATE';
        END IF;*/

        -- Update Employee API
        -- ---------------------------------
        hr_person_api.update_person (
            p_validate                       => FALSE,
            p_effective_date                 => TRUNC (p_employment_start_date), --TRUNC (SYSDATE),
            p_datetrack_update_mode          => 'CORRECTION', --lc_dt_ud_mode,
            p_person_id                      => ln_person_id,
            p_last_name                      => p_legal_last_name,
            p_email_address                  => p_emp_email_address,
            p_object_version_number          => ln_object_version_number,
            p_original_date_of_hire          => p_employment_start_date,
            p_expense_check_send_to_addres   => 'O',
            -- IN OUT parameters
            p_first_name                     => p_legal_first_name,
            p_employee_number                => ln_employee_number,
            -- OUT parameters
            p_effective_start_date           => ld_effective_start_date,
            p_effective_end_date             => ld_effective_end_date,
            p_full_name                      => lv_full_name,
            p_comment_id                     => ln_comment_id,
            p_name_combination_warning       => lb_name_combination_warning,
            p_assign_payroll_warning         => lb_assign_payroll_warning,
            p_orig_hire_warning              => lb_orig_hire_warning);

        lv_msg                     := 'Employee updated. ';

        log_success_msg (p_record_id => p_record_id, p_msg => lv_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   := 'Error Updating Employee-' || SQLERRM || '. ';


            log_error_msg (p_record_id => p_record_id, p_err_msg => lv_msg);

            print_log_prc (
                   'Exception in Updating Employee :'
                || SQLERRM
                || '. for record_id '
                || p_record_id);
    END;


    -- Begin CCR0007631
    PROCEDURE update_suppliers
    IS
        CURSOR update_supplier_cur IS
            SELECT DISTINCT wd_stg.record_id, aps.vendor_id, wd_stg.local_name,
                            wd_stg.employee_id
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg, ap_suppliers aps, per_all_people_f ppf
             WHERE     wd_stg.request_id = gn_request_id
                   AND ppf.employee_number = wd_stg.employee_id
                   AND aps.employee_id = ppf.person_id
                   AND NVL (aps.vendor_name_alt, 'X') !=
                       NVL (wd_stg.local_name, 'X');

        -- Local Variables
        -- ---------------------------------
        lv_err_msg   VARCHAR2 (240);
        lv_msg       VARCHAR2 (240);
    BEGIN
        FOR vendor_rec IN update_supplier_cur
        LOOP
            BEGIN
                UPDATE ap_suppliers aps
                   SET vendor_name_alt = vendor_rec.local_name, last_update_date = SYSDATE, last_updated_by = gn_user_id
                 WHERE aps.vendor_id = vendor_rec.vendor_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --End CCR0007631
                    lv_msg   := 'Error Updating Supplier-' || SQLERRM || '. ';


                    log_error_msg (p_record_id   => vendor_rec.record_id,
                                   p_err_msg     => lv_msg);

                    print_log_prc (
                           'Exception in Updating Supplier :'
                        || SQLERRM
                        || '. for record_id '
                        || vendor_rec.record_id);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   := 'Cannot update suppliers. ' || SQLERRM || '. ';
            print_log_prc (lv_msg);
    END;

    -- End CCR0007631

    --------------------------------------------------------------------------------------
    -- Procedure to create supplier and supplier site
    --------------------------------------------------------------------------------------
    PROCEDURE create_supplier (p_status OUT VARCHAR2, p_err_msg OUT VARCHAR2)
    IS
        lv_status                VARCHAR2 (1);
        lv_err_msg               VARCHAR2 (2000);
        lv_msg                   VARCHAR2 (2000);

        lv_return_status         VARCHAR2 (4000);
        ln_msg_count             NUMBER;
        lv_msg_data              VARCHAR2 (4000);
        ln_vendor_site_id        NUMBER;
        ln_party_site_id         NUMBER;
        ln_location_id           NUMBER;
        ln_party_id              NUMBER;
        lv_data                  VARCHAR2 (2000);
        ln_msg_index_out         NUMBER;
        -- Local Variables
        --      ln_object_version_number   NUMBER;
        lv_country               VARCHAR2 (50);
        lv_region1               VARCHAR2 (120);
        lv_region2               VARCHAR2 (120);
        lv_state                 VARCHAR2 (30);
        lv_county                VARCHAR2 (30);


        ln_set_of_books_id       NUMBER;
        lv_currency_code         VARCHAR2 (30);

        --Changed Pay Group
        lv_pay_group             VARCHAR2 (30) := 'CONCUR_OFFSET'; --'EMPLOYEE';
        --Changed Payment terms
        lv_terms_name            VARCHAR2 (30) := 'DUE UPON RECEIPT'; --'IMMEDIATE';
        lv_vendor_site_code      VARCHAR2 (30) := 'OFFICE';
        lv_vendor_type           VARCHAR2 (30) := 'EMPLOYEE';
        lv_payment_method        VARCHAR2 (30) := 'Electronic';
        lv_payment_method_code   VARCHAR2 (30);

        ln_term_id               NUMBER;
        lv_company_code          VARCHAR2 (25);
        ln_vendor_id             NUMBER;
        p_vendor_site_rec        apps.ap_vendor_pub_pkg.r_vendor_site_rec_type;
        p_vendor_rec             apps.ap_vendor_pub_pkg.r_vendor_rec_type;
        lv_address_line1         hr_locations.address_line_1%TYPE;
        lv_address_line2         hr_locations.address_line_2%TYPE;
        lv_address_line3         hr_locations.address_line_3%TYPE;
        lv_city                  hr_locations.town_or_city%TYPE;

        lv_zip                   hr_locations.postal_code%TYPE;
        lv_style                 hr_locations.style%TYPE;

        ln_org_id                NUMBER;

        CURSOR create_supplier_cur IS
            SELECT record_id, ppf.person_id employee_id, wd_stg.employee_id workday_employee_id,
                   ppf.last_name || ', ' || ppf.first_name vendor_name, paf.location_id, wd_stg.cost_center,
                   wd_stg.county, wd_stg.state_province, wd_stg.employee_email_address email_address,
                   ppf.effective_start_date emp_start_date, wd_stg.local_name --CCR0007631
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg, per_all_people_f ppf, per_assignments_f paf
             WHERE     wd_stg.request_id = gn_request_id
                   AND ppf.employee_number = TO_CHAR (wd_stg.employee_id)
                   AND paf.person_id = ppf.person_id
                   AND NVL (ppf.effective_end_date, SYSDATE + 1) > SYSDATE
                   AND NVL (paf.effective_end_date, SYSDATE + 1) > SYSDATE
                   AND NOT EXISTS
                           (SELECT 1
                              FROM ap_suppliers ap
                             WHERE ap.employee_id = ppf.person_id);
    --Start Modification by BT Technology Team v1.1 on 05-MAY-2015
    /*CURSOR set_org_cur (
       p_org_id NUMBER)
    IS
       SELECT po.profile_option_name,
              rsp.responsibility_id,
              rsp.application_id
         FROM apps.fnd_profile_options_vl po,
              apps.fnd_profile_option_values pov,
              apps.fnd_responsibility rsp
        WHERE     1 = 1
              AND pov.profile_option_id = po.profile_option_id
              AND rsp.application_id(+) = pov.level_value_application_id
              AND rsp.responsibility_id(+) = pov.level_value
              AND pov.level_id = '10003'         -- For Responsibility Level
              AND pov.profile_option_value = TO_CHAR (p_org_id)    -- Org Id
              AND po.user_profile_option_name LIKE 'MO: Operating Unit'
              AND ROWNUM = 1;*/
    --End Modification by BT Technology Team v1.1 on 05-MAY-2015
    BEGIN
        lv_status   := 'S';
        print_log_prc ('Begin create_supplier');

        BEGIN
            SELECT term_id
              INTO ln_term_id
              FROM ap_terms_tl
             WHERE     UPPER (name) = lv_terms_name
                   AND language = USERENV ('LANG')
                   AND NVL (end_date_active, SYSDATE + 1) > SYSDATE;

            print_log_prc ('Term ID :' || ln_term_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_status   := 'E';
                p_status    := '2';
                p_err_msg   :=
                       'Error deriving Terms Id for terms: '
                    || lv_terms_name
                    || '. ';
        END;

        BEGIN
            SELECT payment_method_code
              INTO lv_payment_method_code
              FROM iby_payment_methods_vl
             WHERE     payment_method_name = lv_payment_method
                   AND NVL (inactive_date, SYSDATE + 1) > SYSDATE;

            print_log_prc ('Payment Method :' || lv_payment_method_code);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_status   := 'E';
                p_status    := '2';
                p_err_msg   := 'Error deriving Payment Method. ';
        END;

        IF lv_status <> 'E'
        THEN
            FOR create_supplier_rec IN create_supplier_cur
            LOOP
                lv_status            := 'S';

                lv_err_msg           := NULL;
                lv_msg               := NULL;

                lv_return_status     := NULL;
                ln_msg_count         := NULL;
                lv_msg_data          := NULL;
                ln_vendor_site_id    := NULL;
                ln_party_site_id     := NULL;
                ln_location_id       := NULL;
                ln_party_id          := NULL;
                lv_data              := NULL;
                ln_msg_index_out     := NULL;

                lv_country           := NULL;
                lv_region1           := NULL;
                lv_region2           := NULL;
                lv_state             := NULL;
                lv_county            := NULL;

                ln_set_of_books_id   := NULL;
                lv_currency_code     := NULL;

                lv_company_code      := NULL;
                ln_vendor_id         := NULL;
                p_vendor_site_rec    := NULL;
                p_vendor_rec         := NULL;
                lv_address_line1     := NULL;
                lv_address_line2     := NULL;
                lv_address_line3     := NULL;
                lv_city              := NULL;
                lv_zip               := NULL;
                lv_style             := NULL;
                ln_org_id            := NULL;

                BEGIN
                    --Start Modification by BT Technology Team v1.3 on 23-JUL-2015 for Defect# 2791
                    --Changed OU derivation logic as the other query returned multiple rows
                    SELECT hou.organization_id
                      INTO ln_org_id
                      FROM fnd_lookup_values flv, hr_operating_units hou
                     WHERE     flv.lookup_type = 'XXD_COMPANY_OU_MAPPING'
                           AND flv.enabled_flag = 'Y'
                           AND flv.language = 'US'
                           AND NVL (flv.end_date_active, SYSDATE + 1) >
                               SYSDATE
                           AND flv.view_application_id = 200
                           AND UPPER (flv.meaning) = UPPER (hou.name)
                           AND flv.lookup_code =
                               SUBSTR (
                                   create_supplier_rec.cost_center,
                                   1,
                                     INSTR (create_supplier_rec.cost_center,
                                            '.',
                                            1)
                                   - 1);
                /*SELECT DISTINCT hroutl_ou.organization_id org_id
                  INTO ln_org_id
                  FROM xle_entity_profiles lep,
                       xle_registrations reg,
                       hr_locations_all hrl,
                       hz_parties hzp,
                       fnd_territories_vl ter,
                       hr_operating_units hro,
                       hr_all_organization_units_tl hroutl_bg,
                       hr_all_organization_units_tl hroutl_ou,
                       hr_organization_units hou,
                       gl_legal_entities_bsvs glev
                 WHERE     lep.transacting_entity_flag = 'Y'
                       AND lep.party_id = hzp.party_id
                       AND lep.legal_entity_id = reg.source_id
                       AND reg.source_table =
                              'XLE_ENTITY_PROFILES'
                       AND hrl.location_id = reg.location_id
                       AND reg.identifying_flag = 'Y'
                       AND ter.territory_code = hrl.country
                       AND lep.legal_entity_id =
                              hro.default_legal_context_id
                       AND hou.organization_id =
                              hro.organization_id
                       AND hroutl_bg.organization_id =
                              hro.business_group_id
                       AND hroutl_ou.organization_id =
                              hro.organization_id
                       AND glev.legal_entity_id =
                              lep.legal_entity_id
                       AND flex_segment_value =
                              SUBSTR (
                                 create_supplier_rec.cost_center,
                                 1,
                                   INSTR (
                                      create_supplier_rec.cost_center,
                                      '.',
                                      1)
                                 - 1);*/
                --End Modification by BT Technology Team v1.3 on 23-JUL-2015 for Defect# 2791
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lv_status   := 'E';
                        lv_err_msg   :=
                            'OU not found for creating supplier site. ';

                        log_error_msg (
                            p_record_id   => create_supplier_rec.record_id,
                            p_err_msg     => lv_err_msg);
                    WHEN OTHERS
                    THEN
                        lv_status   := 'E';
                        lv_err_msg   :=
                               'Unable to derive OU for creating supplier site'
                            || SQLERRM
                            || '. ';

                        log_error_msg (
                            p_record_id   => create_supplier_rec.record_id,
                            p_err_msg     => lv_err_msg);
                END;

                IF TRUNC (create_supplier_rec.emp_start_date) >
                   TRUNC (SYSDATE)
                THEN
                    lv_err_msg   :=
                           'Employee start date -'
                        || create_supplier_rec.emp_start_date
                        || ' is in future, cannont create supplier. ';
                    log_error_msg (
                        p_record_id   => create_supplier_rec.record_id,
                        p_err_type    => gc_oracle_err,
                        p_err_msg     => lv_err_msg);
                ELSE
                    ln_set_of_books_id                     :=
                        get_sob_id (create_supplier_rec.cost_center);

                    lv_currency_code                       :=
                        get_ledger_currency (ln_set_of_books_id);

                    p_vendor_rec.vendor_name               :=
                        create_supplier_rec.vendor_name;

                    p_vendor_rec.enabled_flag              := 'Y';
                    p_vendor_rec.vendor_type_lookup_code   := lv_vendor_type;

                    p_vendor_rec.terms_id                  := ln_term_id;
                    p_vendor_rec.set_of_books_id           :=
                        ln_set_of_books_id;
                    p_vendor_rec.pay_group_lookup_code     :=
                        get_paygroup_lookup (ln_org_id, lv_pay_group); --CCR0006280

                    p_vendor_rec.invoice_currency_code     :=
                        get_inv_currency_lookup (ln_org_id, lv_currency_code); --CCR0006280
                    p_vendor_rec.payment_currency_code     :=
                        get_inv_currency_lookup (ln_org_id, lv_currency_code); --CCR0006280
                    p_vendor_rec.start_date_active         := SYSDATE;
                    p_vendor_rec.attribute11               :=
                        create_supplier_rec.workday_employee_id;
                    p_vendor_rec.employee_id               :=
                        create_supplier_rec.employee_id;
                    p_vendor_rec.attribute_category        :=
                        'Supplier Data Elements';
                    p_vendor_rec.ext_payee_rec.default_pmt_method   :=
                        lv_payment_method_code;
                    --Start changes for defect 695 for V1.9
                    p_vendor_rec.remittance_email          :=
                        create_supplier_rec.email_address;
                    p_vendor_rec.supplier_notif_method     :=
                        'EMAIL';

                    --End changes for defect 695 for V1.9

                    IF lv_status <> 'E'
                    THEN
                        -- print_log_prc ('Creating Supplier');

                        BEGIN
                            ap_vendor_pub_pkg.create_vendor (
                                p_api_version        => '1.0',
                                p_init_msg_list      => fnd_api.g_true,
                                p_commit             => fnd_api.g_false,
                                p_validation_level   =>
                                    fnd_api.g_valid_level_full,
                                p_vendor_rec         => p_vendor_rec,
                                ---Out parameters
                                x_return_status      => lv_return_status,
                                x_msg_count          => ln_msg_count,
                                x_msg_data           => lv_msg_data,
                                x_vendor_id          => ln_vendor_id,
                                x_party_id           => ln_party_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_err_msg   :=
                                       'Error creating supplier '
                                    || SQLERRM
                                    || '. ';

                                log_error_msg (
                                    p_record_id   =>
                                        create_supplier_rec.record_id,
                                    p_err_msg   => lv_err_msg);
                        END;

                        IF ln_msg_count > 0
                        THEN
                            lv_err_msg   := NULL;

                            FOR k IN 1 .. ln_msg_count
                            LOOP
                                lv_data   := NULL;

                                apps.fnd_msg_pub.get (
                                    p_msg_index       => k,
                                    p_encoded         => 'F',
                                    p_data            => lv_data,
                                    p_msg_index_out   => ln_msg_index_out);
                                lv_err_msg   :=
                                    SUBSTR (lv_err_msg, 1, 256) || lv_data;


                                print_log_prc (
                                    'Supplier error : ' || lv_err_msg);
                            END LOOP;

                            log_error_msg (
                                p_record_id   => create_supplier_rec.record_id,
                                p_err_msg     => lv_err_msg);
                        ELSE
                            --Begin CCR0007631
                            --API call does not set this value in AP suppliers. We are updating after confirm that supplier was created.
                            IF create_supplier_rec.local_name IS NOT NULL
                            THEN
                                UPDATE ap_suppliers
                                   SET vendor_name_alt = create_supplier_rec.local_name
                                 WHERE vendor_id = ln_vendor_id;
                            END IF;

                            --End CCR0007631

                            p_vendor_site_rec.vendor_id   := ln_vendor_id;
                            p_vendor_site_rec.vendor_site_code   :=
                                lv_vendor_site_code;

                            IF create_supplier_rec.location_id IS NOT NULL
                            THEN
                                BEGIN
                                    SELECT address_line_1, address_line_2, address_line_3,
                                           town_or_city, country, postal_code,
                                           region_1, region_2, style,
                                           location_id
                                      INTO lv_address_line1, lv_address_line2, lv_address_line3, lv_city,
                                                           lv_country, lv_zip, lv_region1,
                                                           lv_region2, lv_style, ln_location_id
                                      FROM hr_locations
                                     WHERE location_id =
                                           create_supplier_rec.location_id;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        lv_status   := 'E';
                                        lv_err_msg   :=
                                            'Location not available to create site. ';

                                        log_error_msg (
                                            p_record_id   =>
                                                create_supplier_rec.record_id,
                                            p_err_msg   => lv_err_msg);
                                    WHEN OTHERS
                                    THEN
                                        lv_status   := 'E';
                                        lv_err_msg   :=
                                               'Error retireving location '
                                            || SQLERRM
                                            || '. ';
                                        log_error_msg (
                                            p_record_id   =>
                                                create_supplier_rec.record_id,
                                            p_err_msg   => lv_err_msg);
                                END;
                            END IF;

                            IF lv_status <> 'E'
                            THEN
                                --lv_county := create_supplier_rec.county;
                                --lv_state := create_supplier_rec.state_province;



                                --p_vendor_site_rec.address_line1 := lv_address_line1;
                                --p_vendor_site_rec.address_line2 := lv_address_line2;
                                --p_vendor_site_rec.address_line3 := lv_address_line3;
                                --p_vendor_site_rec.city := lv_city;
                                --p_vendor_site_rec.state := lv_state;
                                --p_vendor_site_rec.zip := lv_zip;
                                --p_vendor_site_rec.country := lv_country;
                                --p_vendor_site_rec.address_style := lv_style;
                                --p_vendor_site_rec.county := lv_county;
                                p_vendor_site_rec.ship_to_location_id   :=
                                    ln_location_id;
                                p_vendor_site_rec.bill_to_location_id   :=
                                    ln_location_id;
                                p_vendor_site_rec.pay_group_lookup_code   :=
                                    get_paygroup_lookup (ln_org_id,
                                                         lv_pay_group); --CCR0006280
                                p_vendor_site_rec.terms_id   := ln_term_id;
                                p_vendor_site_rec.invoice_currency_code   :=
                                    get_inv_currency_lookup (
                                        ln_org_id,
                                        lv_currency_code);        --CCR0006280
                                p_vendor_site_rec.payment_currency_code   :=
                                    get_inv_currency_lookup (
                                        ln_org_id,
                                        lv_currency_code);        --CCR0006280
                                p_vendor_site_rec.org_id     :=
                                    ln_org_id;

                                p_vendor_site_rec.email_address   :=
                                    create_supplier_rec.email_address;
                                --Added below Remittance Email mapping for defect 695 for V1.9
                                p_vendor_site_rec.remittance_email   :=
                                    create_supplier_rec.email_address;
                                p_vendor_site_rec.remit_advice_delivery_method   :=
                                    'EMAIL';                      --CCR0006280
                                --Start Modification by BT Technology Team v1.1 on 05-MAY-2015
                                /*FOR set_org_rec IN set_org_cur (ln_org_id)
                                LOOP
                                   fnd_global.apps_initialize (
                                      fnd_global.user_id,
                                      set_org_rec.responsibility_id,
                                      set_org_rec.application_id,
                                      NULL,
                                      NULL);
                                END LOOP;*/
                                mo_global.set_policy_context ('S', ln_org_id);

                                --End Modification by BT Technology Team v1.1 on 05-MAY-2015

                                BEGIN
                                    ap_vendor_pub_pkg.create_vendor_site (
                                        p_api_version     => '1.0',
                                        p_init_msg_list   => fnd_api.g_true,
                                        p_commit          => fnd_api.g_false,
                                        p_validation_level   =>
                                            fnd_api.g_valid_level_full,
                                        p_vendor_site_rec   =>
                                            p_vendor_site_rec,
                                        x_return_status   => lv_return_status,
                                        x_msg_count       => ln_msg_count,
                                        x_msg_data        => lv_msg_data,
                                        x_vendor_site_id   =>
                                            ln_vendor_site_id,
                                        x_party_site_id   => ln_party_site_id,
                                        x_location_id     => ln_location_id);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_err_msg   :=
                                               'Error creating supplier site '
                                            || SQLERRM
                                            || '. ';
                                        log_error_msg (
                                            p_record_id   =>
                                                create_supplier_rec.record_id,
                                            p_err_msg   => lv_err_msg);
                                END;

                                IF ln_msg_count > 0
                                THEN
                                    lv_err_msg   := NULL;

                                    FOR k IN 1 .. ln_msg_count
                                    LOOP
                                        lv_data   := NULL;

                                        apps.fnd_msg_pub.get (
                                            p_msg_index   => k,
                                            p_encoded     => 'F',
                                            p_data        => lv_data,
                                            p_msg_index_out   =>
                                                ln_msg_index_out);
                                        lv_err_msg   :=
                                               SUBSTR (lv_err_msg, 1, 256)
                                            || lv_data;


                                        print_log_prc (
                                               ' Supplier site error  : '
                                            || lv_err_msg);
                                    END LOOP;

                                    log_error_msg (
                                        p_record_id   =>
                                            create_supplier_rec.record_id,
                                        p_err_msg   => lv_err_msg);
                                ELSE
                                    print_log_prc (
                                        'Supplier Site Created ..  ');

                                    lv_msg   := 'Supplier and Site Created. ';



                                    log_success_msg (
                                        p_record_id   =>
                                            create_supplier_rec.record_id,
                                        p_msg   => lv_msg);
                                    COMMIT;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status    := 'E';
            p_err_msg   := p_err_msg || 'Supplier and site not created';
            print_log_prc ('Exception in Creating Supplier...' || SQLERRM);
    END create_supplier;

    --------------------------------------------------------------------------------------
    -- Procedure to update employee assignments
    --------------------------------------------------------------------------------------
    PROCEDURE update_emp_assignments (p_message    OUT VARCHAR2,
                                      p_ret_code   OUT NUMBER)
    IS
        ln_upd_asg_count                 NUMBER;
        ln_supervisor_emp_id             NUMBER;
        ln_job_id                        NUMBER;
        lv_cost_center                   gl_code_combinations_kfv.concatenated_segments%TYPE;
        lv_segment1                      VARCHAR2 (30);
        lv_segment8                      VARCHAR2 (30);
        lv_segment6                      VARCHAR2 (30) := '67325';     --68510
        lv_fivesegments                  VARCHAR2 (30);
        ln_expense_ccid                  NUMBER;
        ln_location_id                   NUMBER;

        ln_object_version_number         NUMBER;
        ln_sob_id                        NUMBER;
        lv_company_code                  VARCHAR2 (25);

        lv_err_msg                       VARCHAR2 (2000);

        ---------out params
        ln_cagr_grade_def_id             NUMBER;                      --in out
        lv_cagr_concatenated_segments    VARCHAR2 (2000);
        lv_concatenated_segments         hr_soft_coding_keyflex.concatenated_segments%TYPE;
        ln_soft_coding_keyflex_id        NUMBER;                      --in out
        ln_comment_id                    NUMBER;
        ld_effective_start_date          DATE;
        ld_effective_end_date            DATE;
        lb_no_managers_warning           BOOLEAN;
        lb_other_manager_warning         BOOLEAN;
        lb_hourly_salaried_warning       BOOLEAN;
        lv_gsp_post_process_warning      VARCHAR2 (2000);
        lc_dt_ud_mode                    VARCHAR2 (20);


        -- Out Variables for Find Date Track Mode API
        -- -----------------------------------------------------------------
        lb_correction                    BOOLEAN;
        lb_update                        BOOLEAN;
        lb_update_override               BOOLEAN;
        lb_update_change_insert          BOOLEAN;


        ln_org_id                        NUMBER := 0;
        -- In out
        ln_special_ceiling_step_id       NUMBER;
        ln_people_group_id               NUMBER;

        -- Out Params
        lv_group_name                    VARCHAR2 (100);
        lb_org_now_no_manager_warning    BOOLEAN;
        lb_spp_delete_warning            BOOLEAN;
        lv_entries_changed_warning       VARCHAR2 (1);
        lb_taxdistrict_changed_warning   BOOLEAN;



        --lv_datetrack_update_mode := CORRECTION
        CURSOR update_emp_asg_cur IS
            SELECT *
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg
             WHERE     request_id = gn_request_id
                   AND EXISTS
                           (SELECT 1
                              FROM per_all_people_f ppf
                             WHERE ppf.employee_number =
                                   TO_CHAR (wd_stg.employee_id));

        CURSOR get_assignments_cur (p_employee_number VARCHAR2)
        IS
            SELECT paf.assignment_id, paf.object_version_number, paf.assignment_number,
                   paf.assignment_status_type_id, paf.date_probation_end, paf.default_code_comb_id,
                   paf.supervisor_id, paf.effective_start_date
              FROM per_all_people_f ppf, per_assignments_f paf
             WHERE     ppf.employee_number = TO_CHAR (p_employee_number)
                   AND paf.person_id = ppf.person_id
                   AND NVL (ppf.effective_end_date, SYSDATE + 1) > SYSDATE
                   AND NVL (paf.effective_end_date, SYSDATE + 1) > SYSDATE;
    BEGIN
        print_log_prc ('Begin update_emp_assignments');

        BEGIN
            SELECT people_group_id
              INTO ln_people_group_id
              FROM pay_people_groups
             WHERE group_name = 'DO';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_people_group_id   := NULL;
                lv_err_msg           := 'People Group "DO" not defined. ';

                UPDATE xxdo.xxd_wd_to_hr_intf_stg_t
                   SET it_err_msg = it_err_msg || lv_err_msg, -- Check People group
                                                              record_status = DECODE (record_status, gc_reprocess_status, gc_reprocess_status, gc_error_status), last_update_date = gd_sysdate,
                       last_updated_by = gn_user_id
                 WHERE request_id = gn_request_id;

                COMMIT;
            WHEN OTHERS
            THEN
                ln_people_group_id   := NULL;
                lv_err_msg           :=
                    'Error deriving People Group Id for group "DO". ';

                UPDATE xxdo.xxd_wd_to_hr_intf_stg_t
                   SET it_err_msg = it_err_msg || lv_err_msg, -- Check People group
                                                              record_status = DECODE (record_status, gc_reprocess_status, gc_reprocess_status, gc_error_status), last_update_date = gd_sysdate,
                       last_updated_by = gn_user_id
                 WHERE request_id = gn_request_id;

                COMMIT;
        END;

        --lv_err_msg := NULL;

        IF lv_err_msg IS NULL
        THEN
            FOR update_emp_asg_rec IN update_emp_asg_cur
            LOOP
                ln_upd_asg_count           := NULL;
                ln_supervisor_emp_id       := NULL;
                ln_job_id                  := NULL;
                lv_cost_center             := NULL;
                lv_segment1                := NULL;
                lv_segment8                := NULL;
                lv_fivesegments            := NULL;
                ln_expense_ccid            := NULL;
                ln_location_id             := NULL;
                ln_object_version_number   := NULL;
                ln_sob_id                  := NULL;
                lv_company_code            := NULL;

                IF update_emp_asg_rec.supervisor_emp_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT person_id
                          INTO ln_supervisor_emp_id
                          FROM per_all_people_f ppf
                         WHERE     ppf.employee_number =
                                   TO_CHAR (
                                       update_emp_asg_rec.supervisor_emp_id)
                               AND NVL (ppf.effective_end_date, SYSDATE + 1) >
                                   SYSDATE;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_supervisor_emp_id   := NULL;
                            lv_err_msg             :=
                                   update_emp_asg_rec.supervisor_emp_id
                                || ' - Supervisor id doesnot exists in oracle. ';

                            log_error_msg (
                                p_record_id   => update_emp_asg_rec.record_id,
                                p_err_msg     => lv_err_msg);
                        WHEN OTHERS
                        THEN
                            ln_supervisor_emp_id   := NULL;
                            lv_err_msg             :=
                                   'Error deriving Supervisor. '
                                || SQLERRM
                                || '. ';

                            log_error_msg (
                                p_record_id   => update_emp_asg_rec.record_id,
                                p_err_msg     => lv_err_msg);
                    END;
                ELSE
                    ln_supervisor_emp_id   := NULL;
                END IF;



                IF update_emp_asg_rec.management_level IS NOT NULL
                THEN
                    BEGIN
                        SELECT job_id
                          INTO ln_job_id
                          FROM per_jobs pj
                         WHERE     pj.name LIKE
                                          update_emp_asg_rec.management_level
                                       || '%'
                               AND NVL (pj.date_to, SYSDATE + 1) > SYSDATE;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_job_id   := NULL;
                            lv_err_msg   :=
                                   update_emp_asg_rec.management_level
                                || ' - Job doesnot exists in Oracle. ';

                            log_error_msg (
                                p_record_id   => update_emp_asg_rec.record_id,
                                p_err_type    => gc_oracle_err,
                                p_err_msg     => lv_err_msg);
                        WHEN OTHERS
                        THEN
                            ln_job_id   := NULL;
                            lv_err_msg   :=
                                   'Error deriving Job id for job '
                                || update_emp_asg_rec.management_level
                                || ' - '
                                || SQLERRM
                                || '. ';

                            log_error_msg (
                                p_record_id   => update_emp_asg_rec.record_id,
                                p_err_type    => gc_oracle_err,
                                p_err_msg     => lv_err_msg);
                    END;
                ELSE
                    ln_job_id   := NULL;
                END IF;

                IF update_emp_asg_rec.cost_center IS NULL
                THEN
                    lv_cost_center   := NULL;
                ELSE
                    lv_cost_center   := update_emp_asg_rec.cost_center;

                    BEGIN
                        SELECT SUBSTR (lv_cost_center,
                                       1,
                                       INSTR (lv_cost_center, '.', 1) - 1)
                                   segment1,
                               SUBSTR (lv_cost_center,
                                       1,
                                         INSTR (lv_cost_center, '.', 1,
                                                5)
                                       - 1)
                                   fivesegments,
                               SUBSTR (lv_cost_center,
                                         INSTR (lv_cost_center, '.', 1,
                                                6                          --5
                                                 )
                                       + 1,
                                       LENGTH (lv_cost_center))
                                   segment8
                          INTO lv_segment1, lv_fivesegments, lv_segment8
                          FROM DUAL;

                        lv_cost_center   :=
                               lv_fivesegments
                            || '.'
                            || lv_segment6
                            || '.'
                            || lv_segment1
                            || '.'
                            || lv_segment8;

                        BEGIN
                            SELECT code_combination_id
                              INTO ln_expense_ccid
                              FROM gl_code_combinations_kfv
                             WHERE concatenated_segments = lv_cost_center;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_expense_ccid   := NULL;
                                lv_err_msg        :=
                                       update_emp_asg_rec.cost_center
                                    || ' - Cost Center does not exists in Oracle. ';

                                log_error_msg (
                                    p_record_id   =>
                                        update_emp_asg_rec.record_id,
                                    p_err_type   => gc_workday_err,
                                    p_err_msg    => lv_err_msg);
                            WHEN OTHERS
                            THEN
                                ln_expense_ccid   := NULL;
                                lv_err_msg        :=
                                       'For Cost Center '
                                    || update_emp_asg_rec.cost_center
                                    || ' error deriving Expense Account. '
                                    || SQLERRM
                                    || '. ';

                                log_error_msg (
                                    p_record_id   =>
                                        update_emp_asg_rec.record_id,
                                    p_err_type   => gc_workday_err,
                                    p_err_msg    => lv_err_msg);
                        END;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_cost_center   := NULL;
                            lv_err_msg       :=
                                   'Error deriving expense accout segments. '
                                || SQLERRM
                                || '. ';

                            log_error_msg (
                                p_record_id   => update_emp_asg_rec.record_id,
                                p_err_msg     => lv_err_msg);
                    END;
                END IF;

                IF update_emp_asg_rec.location_name IS NOT NULL
                THEN
                    BEGIN
                        SELECT location_id
                          INTO ln_location_id
                          FROM hr_locations
                         WHERE location_code =
                                  'E'
                               || lv_segment1
                               || '-'
                               || update_emp_asg_rec.location_name;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_location_id   := NULL;
                            lv_err_msg       :=
                                   'E'
                                || lv_segment1
                                || '-'
                                || update_emp_asg_rec.location_name
                                || ' - Location Name doesnot exists in Oracle. ';
                            log_error_msg (
                                p_record_id   => update_emp_asg_rec.record_id,
                                p_err_msg     => lv_err_msg);
                        WHEN OTHERS
                        THEN
                            ln_location_id   := NULL;
                            lv_err_msg       :=
                                   'Error deriving Location Id. '
                                || SQLERRM
                                || '. ';
                            log_error_msg (
                                p_record_id   => update_emp_asg_rec.record_id,
                                p_err_msg     => lv_err_msg);
                    END;
                ELSE
                    ln_location_id   := NULL;
                END IF;



                ----------ln_sob_id derivation
                ln_sob_id                  :=
                    get_sob_id (update_emp_asg_rec.cost_center);



                -- Check if updating assignment is needed.
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_upd_asg_count
                      FROM per_all_people_f ppf, per_assignments_f paf
                     WHERE     ppf.employee_number =
                               TO_CHAR (update_emp_asg_rec.employee_id)
                           AND paf.person_id = ppf.person_id
                           --Added NVL by BT Technology Team  v 1.2 on 19-MAY-2015
                           AND NVL (paf.supervisor_id, 0) =
                               NVL (ln_supervisor_emp_id, 0)
                           AND NVL (paf.job_id, 0) = NVL (ln_job_id, 0)
                           AND NVL (paf.location_id, 0) =
                               NVL (ln_location_id, 0)
                           AND NVL (paf.default_code_comb_id, 0) =
                               NVL (ln_expense_ccid, 0)
                           AND NVL (paf.set_of_books_id, 0) =
                               NVL (ln_sob_id, 0)
                           AND NVL (ppf.effective_end_date, SYSDATE + 1) >
                               SYSDATE
                           AND NVL (paf.effective_end_date, SYSDATE + 1) >
                               SYSDATE;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_upd_asg_count   := 0;
                    WHEN OTHERS
                    THEN
                        ln_upd_asg_count   := 1;
                        lv_err_msg         := 'Error:' || SQLERRM;
                        log_error_msg (
                            p_record_id   => update_emp_asg_rec.record_id,
                            p_err_msg     => lv_err_msg);
                END;

                IF ln_upd_asg_count = 0
                THEN
                    FOR get_assignments_rec
                        IN get_assignments_cur (
                               update_emp_asg_rec.employee_id)
                    LOOP
                        lv_err_msg   := NULL;
                        ln_object_version_number   :=
                            get_assignments_rec.object_version_number;

                        /* Commented for v1.2
                        -- Find Date Track Mode
                        -- --------------------------------
                        dt_api.find_dt_upd_modes (
                           p_effective_date         => TRUNC (SYSDATE),
                           p_base_table_name        => 'PER_ALL_ASSIGNMENTS_F',
                           p_base_key_column        => 'ASSIGNMENT_ID',
                           p_base_key_value         => get_assignments_rec.assignment_id,
                           -- Output data elements
                           -- --------------------------------
                           p_correction             => lb_correction,
                           p_update                 => lb_update,
                           p_update_override        => lb_update_override,
                           p_update_change_insert   => lb_update_change_insert);



                        IF (   lb_update_override = TRUE
                            OR lb_update_change_insert = TRUE)
                        THEN
                           -- UPDATE_OVERRIDE
                           -- ---------------------------------
                           lc_dt_ud_mode := 'UPDATE_OVERRIDE';
                        END IF;



                        IF (lb_correction = TRUE)
                        THEN
                           -- CORRECTION
                           -- ----------------------
                           lc_dt_ud_mode := 'CORRECTION';
                        END IF;



                        IF (lb_update = TRUE)
                        THEN
                           -- UPDATE
                           -- --------------
                           lc_dt_ud_mode := 'UPDATE';
                        END IF;*/

                        BEGIN
                            hr_assignment_api.update_emp_asg (
                                p_validate                => FALSE,
                                p_effective_date          =>
                                    TRUNC (
                                        get_assignments_rec.effective_start_date), --SYSDATE,
                                p_datetrack_update_mode   => 'CORRECTION', --lc_dt_ud_mode,
                                p_assignment_id           =>
                                    get_assignments_rec.assignment_id,
                                p_object_version_number   =>
                                    ln_object_version_number          --in out
                                                            ,
                                p_supervisor_id           =>
                                    NVL (ln_supervisor_emp_id,
                                         get_assignments_rec.supervisor_id),
                                p_assignment_number       =>
                                    get_assignments_rec.assignment_number,
                                p_change_reason           => hr_api.g_varchar2,
                                p_assignment_status_type_id   =>
                                    get_assignments_rec.assignment_status_type_id,
                                p_comments                => hr_api.g_varchar2,
                                p_date_probation_end      =>
                                    get_assignments_rec.date_probation_end,
                                p_default_code_comb_id    =>
                                    NVL (
                                        ln_expense_ccid,
                                        get_assignments_rec.default_code_comb_id),
                                p_cagr_concatenated_segments   =>
                                    lv_cagr_concatenated_segments,
                                p_concatenated_segments   =>
                                    lv_concatenated_segments,
                                p_set_of_books_id         => ln_sob_id,
                                -- In out params
                                p_cagr_grade_def_id       =>
                                    ln_cagr_grade_def_id,
                                p_soft_coding_keyflex_id   =>
                                    ln_soft_coding_keyflex_id,
                                -- Out params
                                p_comment_id              => ln_comment_id,
                                p_effective_start_date    =>
                                    ld_effective_start_date,
                                p_effective_end_date      =>
                                    ld_effective_end_date,
                                p_no_managers_warning     =>
                                    lb_no_managers_warning,
                                p_other_manager_warning   =>
                                    lb_other_manager_warning,
                                p_hourly_salaried_warning   =>
                                    lb_hourly_salaried_warning,
                                p_gsp_post_process_warning   =>
                                    lv_gsp_post_process_warning);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_err_msg   :=
                                       'Error updating assignment '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (
                                    p_record_id   =>
                                        update_emp_asg_rec.record_id,
                                    p_err_msg   => lv_err_msg);
                        END;

                        /* Commented for v1.2
                        -- Find Date Track Mode for Second API
                        -- ------------------------------------------------------
                        dt_api.find_dt_upd_modes (
                           p_effective_date         => TRUNC (SYSDATE),
                           p_base_table_name        => 'PER_ALL_ASSIGNMENTS_F',
                           p_base_key_column        => 'ASSIGNMENT_ID',
                           p_base_key_value         => get_assignments_rec.assignment_id,
                           -- Output data elements
                           -- -------------------------------
                           p_correction             => lb_correction,
                           p_update                 => lb_update,
                           p_update_override        => lb_update_override,
                           p_update_change_insert   => lb_update_change_insert);



                        IF (   lb_update_override = TRUE
                            OR lb_update_change_insert = TRUE)
                        THEN
                           -- UPDATE_OVERRIDE
                           -- --------------------------------
                           lc_dt_ud_mode := 'UPDATE_OVERRIDE';
                        END IF;



                        IF (lb_correction = TRUE)
                        THEN
                           -- CORRECTION
                           -- ----------------------
                           lc_dt_ud_mode := 'CORRECTION';
                        END IF;



                        IF (lb_update = TRUE)
                        THEN
                           -- UPDATE
                           -- --------------
                           lc_dt_ud_mode := 'UPDATE';
                        END IF;*/

                        BEGIN
                            hr_assignment_api.update_emp_asg_criteria (
                                p_effective_date            =>
                                    TRUNC (
                                        get_assignments_rec.effective_start_date), --SYSDATE,
                                p_datetrack_update_mode     => 'CORRECTION', --lc_dt_ud_mode,
                                p_assignment_id             =>
                                    get_assignments_rec.assignment_id,
                                p_validate                  => FALSE,
                                p_called_from_mass_update   => FALSE,
                                p_grade_id                  => hr_api.g_number,
                                p_position_id               => hr_api.g_number,
                                p_job_id                    => ln_job_id,
                                p_payroll_id                => hr_api.g_number,
                                p_location_id               => ln_location_id,
                                p_organization_id           => ln_org_id,
                                p_create_salary_proposal    => 'N',
                                -- IN OUT PARAMS
                                p_object_version_number     =>
                                    ln_object_version_number,
                                p_special_ceiling_step_id   =>
                                    ln_special_ceiling_step_id,
                                p_people_group_id           =>
                                    ln_people_group_id,
                                p_soft_coding_keyflex_id    =>
                                    ln_soft_coding_keyflex_id,
                                -- OUT PARAMS
                                p_group_name                => lv_group_name,
                                p_effective_start_date      =>
                                    ld_effective_start_date,
                                p_effective_end_date        =>
                                    ld_effective_end_date,
                                p_org_now_no_manager_warning   =>
                                    lb_org_now_no_manager_warning,
                                p_other_manager_warning     =>
                                    lb_other_manager_warning,
                                p_spp_delete_warning        =>
                                    lb_spp_delete_warning,
                                p_entries_changed_warning   =>
                                    lv_entries_changed_warning,
                                p_tax_district_changed_warning   =>
                                    lb_taxdistrict_changed_warning,
                                p_concatenated_segments     =>
                                    lv_concatenated_segments,
                                p_gsp_post_process_warning   =>
                                    lv_gsp_post_process_warning);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_err_msg   :=
                                       'Error updating assignment - '
                                    || SQLERRM
                                    || '. ';
                                log_error_msg (
                                    p_record_id   =>
                                        update_emp_asg_rec.record_id,
                                    p_err_msg   => lv_err_msg);
                        END;

                        IF lv_err_msg IS NULL
                        THEN
                            log_success_msg (
                                p_record_id   => update_emp_asg_rec.record_id,
                                p_msg         => 'Assignment updated. ');
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;

        print_log_prc ('End update_emp_assignments');
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log_prc ('Error in update_emp_assignments :' || SQLERRM);
    END update_emp_assignments;

    --------------------------------------------------------------------------------------
    -- Procedure to end date employee, supplier and supplier site
    --------------------------------------------------------------------------------------
    PROCEDURE end_date_employee (p_status    OUT VARCHAR2,
                                 p_err_msg   OUT VARCHAR2)
    IS
        ln_object_version_number        NUMBER;
        ld_last_standard_process_date   DATE;
        --Out params
        lb_supervisor_warning           BOOLEAN;
        lb_event_warning                BOOLEAN;
        lb_interview_warning            BOOLEAN;
        lb_review_warning               BOOLEAN;
        lb_recruiter_warning            BOOLEAN;
        lb_asg_future_changes_warning   BOOLEAN;
        lb_pay_proposal_warning         BOOLEAN;
        lb_dod_warning                  BOOLEAN;
        lv_alu_change_warning           VARCHAR2 (1);
        lv_entries_changed_warning      VARCHAR2 (1);
        ln_vendor_id                    NUMBER;
        ln_vendor_site_id               NUMBER;
        lv_vendor_site_code             ap_supplier_sites_all.vendor_site_code%TYPE
            := 'OFFICE';
        l_vendor_site_rec               apps.ap_vendor_pub_pkg.r_vendor_site_rec_type;
        l_vendor_rec                    apps.ap_vendor_pub_pkg.r_vendor_rec_type;


        lv_data                         VARCHAR2 (2000);
        ln_msg_index_out                NUMBER;
        lv_err_msg                      VARCHAR2 (2000);
        lv_return_status                VARCHAR2 (2000);
        ln_msg_count                    NUMBER;



        lv_msg                          VARCHAR2 (240);

        CURSOR end_date_employee_cur IS
            SELECT record_id, ppf.person_id employee_id, --paf.period_of_service_id,
                                                         --ppf.object_version_number,
                                                         pos.period_of_service_id,
                   pos.object_version_number, wd_stg.employment_end_date
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg, per_all_people_f ppf, --per_assignments_f paf
                                                                              per_periods_of_service pos
             WHERE     wd_stg.request_id = gn_request_id
                   AND ppf.employee_number = TO_CHAR (wd_stg.employee_id)
                   --AND paf.person_id = ppf.person_id
                   AND pos.person_id = ppf.person_id
                   AND NVL (ppf.effective_end_date, SYSDATE + 1) > SYSDATE
                   AND ppf.person_type_id =
                       (SELECT person_type_id
                          FROM per_person_types_tl
                         WHERE     language = USERENV ('LANG')
                               AND user_person_type = 'Employee')
                   --AND NVL (paf.effective_end_date, SYSDATE + 1) > SYSDATE
                   AND ppf.effective_start_date < wd_stg.employment_end_date;
    BEGIN
        p_status   := '0';                                     -- MARK_SUCCESS

        FOR end_date_employee_rec IN end_date_employee_cur
        LOOP
            ln_vendor_id        := NULL;

            ln_vendor_site_id   := NULL;

            l_vendor_site_rec   := NULL;
            l_vendor_rec        := NULL;


            ln_object_version_number   :=
                end_date_employee_rec.object_version_number;
            ld_last_standard_process_date   :=
                end_date_employee_rec.employment_end_date + 1;

            BEGIN
                hr_ex_employee_api.actual_termination_emp (
                    p_validate                  => FALSE,
                    p_effective_date            => SYSDATE,
                    p_period_of_service_id      =>
                        end_date_employee_rec.period_of_service_id,
                    p_actual_termination_date   =>
                        end_date_employee_rec.employment_end_date,
                    --IN OUT Parameters
                    p_object_version_number     => ln_object_version_number,
                    p_last_standard_process_date   =>
                        ld_last_standard_process_date,
                    --OUT Parameters
                    p_supervisor_warning        => lb_supervisor_warning,
                    p_event_warning             => lb_event_warning,
                    p_interview_warning         => lb_interview_warning,
                    p_review_warning            => lb_review_warning,
                    p_recruiter_warning         => lb_recruiter_warning,
                    p_asg_future_changes_warning   =>
                        lb_asg_future_changes_warning,
                    p_pay_proposal_warning      => lb_pay_proposal_warning,
                    p_dod_warning               => lb_dod_warning,
                    p_alu_change_warning        => lv_alu_change_warning,
                    p_entries_changed_warning   => lv_entries_changed_warning);

                lv_msg   := 'Employee inactivated. ';


                log_success_msg (
                    p_record_id   => end_date_employee_rec.record_id,
                    p_msg         => lv_msg);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                        'Error end dating employee: ' || SQLERRM || '. ';

                    log_error_msg (
                        p_record_id   => end_date_employee_rec.record_id,
                        p_err_msg     => lv_err_msg);
            END;

            BEGIN
                SELECT vendor_id
                  INTO ln_vendor_id
                  FROM ap_suppliers ap
                 WHERE ap.employee_id = end_date_employee_rec.employee_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_vendor_id   := NULL;
                    lv_err_msg     :=
                        'Supplier is not available to end date. ';

                    log_error_msg (
                        p_record_id   => end_date_employee_rec.record_id,
                        p_err_msg     => lv_err_msg);
                WHEN OTHERS
                THEN
                    ln_vendor_id   := NULL;
                    lv_err_msg     :=
                        'Error deriving supplier: ' || SQLERRM || '. ';

                    log_error_msg (
                        p_record_id   => end_date_employee_rec.record_id,
                        p_err_msg     => lv_err_msg);
            END;



            IF ln_vendor_id IS NOT NULL
            THEN
                l_vendor_rec.vendor_id   := ln_vendor_id;
                l_vendor_rec.end_date_active   :=
                    end_date_employee_rec.employment_end_date;

                ap_vendor_pub_pkg.update_vendor (
                    p_api_version        => '1.0',
                    p_init_msg_list      => fnd_api.g_true,
                    p_commit             => fnd_api.g_false,
                    p_validation_level   => fnd_api.g_valid_level_full,
                    p_vendor_rec         => l_vendor_rec,
                    p_vendor_id          => ln_vendor_id,
                    x_return_status      => lv_return_status,
                    x_msg_count          => ln_msg_count,
                    x_msg_data           => lv_data);


                IF ln_msg_count > 0
                THEN
                    FOR k IN 1 .. ln_msg_count
                    LOOP
                        lv_data   := NULL;

                        apps.fnd_msg_pub.get (
                            p_msg_index       => k,
                            p_encoded         => 'F',
                            p_data            => lv_data,
                            p_msg_index_out   => ln_msg_index_out);
                        lv_err_msg   :=
                            SUBSTR (lv_err_msg, 1, 256) || lv_data;


                        print_log_prc (' lv_err_msg  : ' || lv_err_msg);
                    END LOOP;

                    lv_err_msg   :=
                        'Error inactivating supplier:' || lv_err_msg || ' .';

                    log_error_msg (
                        p_record_id   => end_date_employee_rec.record_id,
                        p_err_msg     => lv_err_msg);
                ELSE
                    --print_log_prc ('Supplier inactivate');

                    lv_msg   := 'Supplier inactivated. ';


                    log_success_msg (
                        p_record_id   => end_date_employee_rec.record_id,
                        p_msg         => lv_msg);

                    COMMIT;
                END IF;


                BEGIN
                    SELECT vendor_site_id
                      INTO ln_vendor_site_id
                      FROM ap_supplier_sites_all ap
                     WHERE     vendor_id = ln_vendor_id
                           AND vendor_site_code = lv_vendor_site_code;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_vendor_site_id   := NULL;
                        lv_err_msg          :=
                            'Supplier is not available to end date. ';

                        log_error_msg (
                            p_record_id   => end_date_employee_rec.record_id,
                            p_err_msg     => lv_err_msg);
                    WHEN OTHERS
                    THEN
                        ln_vendor_site_id   := NULL;
                        lv_err_msg          :=
                            'Error deriving supplier: ' || SQLERRM || '. ';

                        log_error_msg (
                            p_record_id   => end_date_employee_rec.record_id,
                            p_err_msg     => lv_err_msg);
                END;

                IF ln_vendor_site_id IS NOT NULL
                THEN
                    l_vendor_site_rec.vendor_id   := ln_vendor_id;

                    l_vendor_site_rec.inactive_date   :=
                        end_date_employee_rec.employment_end_date;
                    print_log_prc ('Supplier site inactivate ');
                    --  l_vendor_site_rec.vendor_site_code := lv_vendor_site_code;
                    ap_vendor_pub_pkg.update_vendor_site (
                        p_api_version        => '1.0',
                        p_init_msg_list      => fnd_api.g_true,
                        p_commit             => fnd_api.g_false,
                        p_validation_level   => fnd_api.g_valid_level_full,
                        p_vendor_site_rec    => l_vendor_site_rec,
                        p_vendor_site_id     => ln_vendor_site_id,
                        p_calling_prog       => 'WORKDAY UPDATE',
                        x_return_status      => lv_return_status,
                        x_msg_count          => ln_msg_count,
                        x_msg_data           => lv_data);

                    IF ln_msg_count > 0
                    THEN
                        FOR k IN 1 .. ln_msg_count
                        LOOP
                            lv_data   := NULL;

                            apps.fnd_msg_pub.get (
                                p_msg_index       => k,
                                p_encoded         => 'F',
                                p_data            => lv_data,
                                p_msg_index_out   => ln_msg_index_out);
                            lv_err_msg   :=
                                SUBSTR (lv_err_msg, 1, 256) || lv_data;


                            print_log_prc (' lv_err_msg  : ' || lv_err_msg);
                        END LOOP;

                        lv_err_msg   :=
                               'Error inactivating supplier site:'
                            || lv_err_msg
                            || ' .';

                        log_error_msg (
                            p_record_id   => end_date_employee_rec.record_id,
                            p_err_msg     => lv_err_msg);
                    ELSE
                        lv_msg   := 'Supplier site inactivated. ';


                        log_success_msg (
                            p_record_id   => end_date_employee_rec.record_id,
                            p_msg         => lv_msg);
                        COMMIT;
                    END IF;
                END IF;
            END IF;
        END LOOP;
    END;

    --------------------------------------------------------------------------------------
    -- Procedure to email oracle error messages
    --------------------------------------------------------------------------------------
    PROCEDURE email_oracle_err_msg (p_from_emailaddress        VARCHAR2,
                                    p_override_email_address   VARCHAR2)
    IS
        CURSOR send_oracle_err_msg IS
            SELECT wd_stg.legal_first_name, wd_stg.legal_last_name, wd_stg.employee_id,
                   wd_stg.oracle_err_msg error_message
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg
             WHERE     wd_stg.oracle_err_msg IS NOT NULL
                   AND wd_stg.request_id = gn_request_id;


        CURSOR c_recips (cp_lookup_type IN VARCHAR2)
        IS
            SELECT lookup_code, meaning, description
              FROM fnd_lookup_values
             WHERE     lookup_type = cp_lookup_type
                   AND enabled_flag = 'Y'
                   AND language = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);


        l_ret_val           NUMBER := 0;
        v_def_mail_recips   do_mail_utils.tbl_recips;
        ex_no_recips        EXCEPTION;
        ex_no_sender        EXCEPTION;
        ex_no_data_found    EXCEPTION;
        cnt                 NUMBER;
        lv_subject          VARCHAR2 (1000);
        lv_header           VARCHAR2 (1000);
        lv_line             VARCHAR2 (1000);
    BEGIN
        v_def_mail_recips.delete;

        FOR c_recip IN c_recips ('XXDO_EMP_INBOUND_ORACLE_EMAIL') --- Lookup for list of Email Recipients..
        LOOP
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                c_recip.meaning;
            print_log_prc ('Oracle email recipient ' || c_recip.meaning);
        END LOOP;

        IF p_override_email_address IS NOT NULL
        THEN
            v_def_mail_recips.delete;
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                p_override_email_address;
        END IF;

        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        lv_subject   :=
               'Workday to HR Interface Errors for Oracle Request ID: '
            || gn_request_id
            || ' - '
            || TO_CHAR (SYSDATE, 'MM/DD/YYYY');
        print_output_prc (lv_subject);
        do_mail_utils.send_mail_header (p_from_emailaddress, -- Profile Option for Default Sender Email ID
                                                             v_def_mail_recips, lv_subject
                                        , l_ret_val);
        do_mail_utils.send_mail_line ('', l_ret_val);

        FOR intf_rec IN send_oracle_err_msg
        LOOP
            IF NVL (cnt, 0) = 0
            THEN
                lv_header   :=
                       RPAD ('First Name, Last Name', 30, ' ')
                    || ' '
                    || RPAD ('EmployeeId', 10, ' ')     -- Workday Employee_Id
                    || ' '
                    || RPAD ('Error Message', 50, ' ');
                print_output_prc (lv_header);
                do_mail_utils.send_mail_line (lv_header, l_ret_val);

                lv_header   :=
                       RPAD ('---', 30, '-')
                    || ' '
                    || RPAD ('---', 10, '-')
                    || ' '
                    || RPAD ('---', 30, '-');
                print_output_prc (lv_header);
                do_mail_utils.send_mail_line (lv_header, l_ret_val);
            END IF;

            lv_line   :=
                   RPAD (
                       intf_rec.legal_first_name || ',' || intf_rec.legal_last_name,
                       30,
                       ' ')
                || ' '
                || RPAD (intf_rec.employee_id, 10, ' ')
                || ' '
                || RPAD (intf_rec.error_message, 500, ' ');
            print_output_prc (lv_line);
            do_mail_utils.send_mail_line (lv_line, l_ret_val);
            cnt   := NVL (cnt, 0) + 1;
        END LOOP;

        print_output_prc (' ');

        IF cnt = 0
        THEN
            do_mail_utils.send_mail_line (
                'No Errors for the request_id Run - ' || gn_request_id,
                l_ret_val);
        END IF;

        do_mail_utils.send_mail_close (l_ret_val);
    EXCEPTION
        WHEN ex_no_recips
        THEN
            DBMS_OUTPUT.put_line ('No Recipients list found for Oracle');
            do_mail_utils.send_mail_close (l_ret_val);               --Be Safe
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (l_ret_val);
    END;

    --------------------------------------------------------------------------------------
    -- Procedure to email workday error messages
    --------------------------------------------------------------------------------------
    PROCEDURE email_workday_err_msg (p_from_emailaddress        VARCHAR2,
                                     p_override_email_address   VARCHAR2)
    IS
        CURSOR send_workday_err_msg IS
            SELECT wd_stg.legal_first_name, wd_stg.legal_last_name, wd_stg.employee_id,
                   wd_stg.workday_err_msg error_message
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg, per_all_people_f pf -- Added for CCR0006796
             WHERE     wd_stg.workday_err_msg IS NOT NULL
                   AND record_status = gc_error_status           -- CCR0006280
                   --         AND wd_stg.request_id = gn_request_id; CCR0006280: Show all errors
                   AND Pf.Employee_Number = Wd_Stg.Employee_Id --Start  Added for CCR0006796
                   AND pf.PERSON_TYPE_ID = 6
                   AND Pf.Effective_End_Date >= SYSDATE; -- End Added for CCR0006796


        CURSOR c_recips (cp_lookup_type IN VARCHAR2)
        IS
            SELECT lookup_code, meaning, description
              FROM fnd_lookup_values
             WHERE     lookup_type = cp_lookup_type
                   AND enabled_flag = 'Y'
                   AND language = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);


        l_ret_val           NUMBER := 0;
        v_def_mail_recips   do_mail_utils.tbl_recips;
        ex_no_recips        EXCEPTION;
        ex_no_sender        EXCEPTION;
        ex_no_data_found    EXCEPTION;
        cnt                 NUMBER;
        lv_subject          VARCHAR2 (1000);
        lv_header           VARCHAR2 (1000);
        lv_line             VARCHAR2 (1000);
    BEGIN
        v_def_mail_recips.delete;

        FOR c_recip IN c_recips ('XXDO_EMP_INBOUND_WORKDAY_EMAIL') --- Lookup for list of Email Recipients..
        LOOP
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                c_recip.meaning;
            print_log_prc ('Workday email recipient ' || c_recip.meaning);
        END LOOP;

        IF p_override_email_address IS NOT NULL
        THEN
            v_def_mail_recips.delete;
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                p_override_email_address;
        END IF;

        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        lv_subject   :=
               'Workday to HR Interface Errors for Workday Request ID: '
            || gn_request_id
            || ' - '
            || TO_CHAR (SYSDATE, 'MM/DD/YYYY');
        print_output_prc (lv_subject);

        do_mail_utils.send_mail_header (p_from_emailaddress, -- Profile Option for Default Sender Email ID
                                                             v_def_mail_recips, lv_subject
                                        , l_ret_val);
        do_mail_utils.send_mail_line ('', l_ret_val);

        FOR intf_rec IN send_workday_err_msg
        LOOP
            IF NVL (cnt, 0) = 0
            THEN
                lv_header   :=
                       RPAD ('First Name, Last Name', 30, ' ')
                    || ' '
                    || RPAD ('EmployeeId', 10, ' ')     -- Workday Employee_Id
                    || ' '
                    || RPAD ('Error Message', 50, ' ');
                print_output_prc (lv_header);
                do_mail_utils.send_mail_line (lv_header, l_ret_val);

                lv_header   :=
                       RPAD ('---', 30, '-')
                    || ' '
                    || RPAD ('---', 10, '-')
                    || ' '
                    || RPAD ('---', 30, '-');
                print_output_prc (lv_header);

                do_mail_utils.send_mail_line (lv_header, l_ret_val);
            END IF;

            lv_line   :=
                   RPAD (
                       intf_rec.legal_first_name || ',' || intf_rec.legal_last_name,
                       30,
                       ' ')
                || ' '
                || RPAD (intf_rec.employee_id, 10, ' ')
                || ' '
                || RPAD (intf_rec.error_message, 500, ' ');
            print_output_prc (lv_line);

            do_mail_utils.send_mail_line (lv_line, l_ret_val);
            cnt   := NVL (cnt, 0) + 1;
        END LOOP;

        print_output_prc (' ');

        IF cnt = 0
        THEN
            do_mail_utils.send_mail_line (
                'No Errors for the request_id Run - ' || gn_request_id,
                l_ret_val);
        END IF;

        do_mail_utils.send_mail_close (l_ret_val);
    EXCEPTION
        WHEN ex_no_recips
        THEN
            DBMS_OUTPUT.put_line ('No Recipients list found for Workday');
            do_mail_utils.send_mail_close (l_ret_val);               --Be Safe
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (l_ret_val);
    END;

    --------------------------------------------------------------------------------------
    -- Procedure to email IT error messages
    --------------------------------------------------------------------------------------
    PROCEDURE email_it_err_msg (p_from_emailaddress        VARCHAR2,
                                p_override_email_address   VARCHAR2)
    IS
        CURSOR send_it_err_msg IS
            SELECT wd_stg.legal_first_name, wd_stg.legal_last_name, wd_stg.employee_id,
                   wd_stg.it_err_msg error_message
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg
             WHERE     wd_stg.it_err_msg IS NOT NULL
                   AND wd_stg.request_id = gn_request_id;

        CURSOR c_recips (cp_lookup_type IN VARCHAR2)
        IS
            SELECT lookup_code, meaning, description
              FROM fnd_lookup_values
             WHERE     lookup_type = cp_lookup_type
                   AND enabled_flag = 'Y'
                   AND language = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);


        l_ret_val           NUMBER := 0;
        v_def_mail_recips   do_mail_utils.tbl_recips;
        ex_no_recips        EXCEPTION;
        ex_no_sender        EXCEPTION;
        ex_no_data_found    EXCEPTION;
        cnt                 NUMBER;
        lv_subject          VARCHAR2 (1000);
        lv_header           VARCHAR2 (1000);
        lv_line             VARCHAR2 (1000);
    BEGIN
        v_def_mail_recips.delete;

        FOR c_recip IN c_recips ('XXDO_EMP_INBOUND_IT_EMAIL') --- Lookup for list of Email Recipients..
        LOOP
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                c_recip.meaning;
            print_log_prc ('IT email recipient ' || c_recip.meaning);
        END LOOP;

        IF p_override_email_address IS NOT NULL
        THEN
            v_def_mail_recips.delete;
            v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                p_override_email_address;
        END IF;

        IF v_def_mail_recips.COUNT < 1
        THEN
            RAISE ex_no_recips;
        END IF;

        lv_subject   :=
               'Workday to HR Interface Errors for IT Request ID: '
            || gn_request_id
            || ' - '
            || TO_CHAR (SYSDATE, 'MM/DD/YYYY');
        print_output_prc (lv_subject);
        do_mail_utils.send_mail_header (p_from_emailaddress, -- Profile Option for Default Sender Email ID
                                                             v_def_mail_recips, lv_subject
                                        , l_ret_val);
        do_mail_utils.send_mail_line ('', l_ret_val);


        FOR intf_rec IN send_it_err_msg
        LOOP
            IF NVL (cnt, 0) = 0
            THEN
                lv_header   :=
                       RPAD ('First Name, Last Name', 30, ' ')
                    || ' '
                    || RPAD ('EmployeeId', 10, ' ')     -- Workday Employee_Id
                    || ' '
                    || RPAD ('Error Message', 50, ' ');
                print_output_prc (lv_header);
                do_mail_utils.send_mail_line (lv_header, l_ret_val);

                lv_header   :=
                       RPAD ('---', 30, '-')
                    || ' '
                    || RPAD ('---', 10, '-')
                    || ' '
                    || RPAD ('---', 30, '-');
                print_output_prc (lv_header);

                do_mail_utils.send_mail_line (lv_header, l_ret_val);
            END IF;

            lv_line   :=
                   RPAD (
                       intf_rec.legal_first_name || ',' || intf_rec.legal_last_name,
                       30,
                       ' ')
                || ' '
                || RPAD (intf_rec.employee_id, 10, ' ')
                || ' '
                || RPAD (intf_rec.error_message, 500, ' ');
            print_output_prc (lv_line);
            do_mail_utils.send_mail_line (lv_line, l_ret_val);
            cnt   := NVL (cnt, 0) + 1;
        END LOOP;

        print_output_prc (' ');

        IF cnt = 0
        THEN
            do_mail_utils.send_mail_line (
                'No Errors for the request_id Run - ' || gn_request_id,
                l_ret_val);
        END IF;

        do_mail_utils.send_mail_close (l_ret_val);
    EXCEPTION
        WHEN ex_no_recips
        THEN
            DBMS_OUTPUT.put_line ('No Recipients list found for IT');
            do_mail_utils.send_mail_close (l_ret_val);               --Be Safe
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (l_ret_val);
    END;

    PROCEDURE update_emp_start_date
    IS
        lv_warn   VARCHAR2 (10);
        lv_msg    VARCHAR2 (4000);

        CURSOR update_emp_start_date_cur IS
            SELECT wd_stg.record_id, ppf.person_id, pds.date_start old_start_date,
                   ppf.applicant_number, wd_stg.employee_start_date new_start_date
              FROM xxdo.xxd_wd_to_hr_intf_stg_t wd_stg, per_all_people_f ppf, per_periods_of_service pds
             WHERE     wd_stg.request_id = gn_request_id
                   AND ppf.employee_number = TO_CHAR (wd_stg.employee_id)
                   AND NVL (ppf.effective_end_date, SYSDATE + 1) > SYSDATE
                   AND pds.person_id = ppf.person_id
                   AND ppf.effective_start_date <> wd_stg.employee_start_date;
    BEGIN
        print_log_prc ('Update employee start date');

        FOR update_emp_start_date_rec IN update_emp_start_date_cur
        LOOP
            BEGIN
                hr_change_start_date_api.update_start_date (
                    p_validate           => FALSE,
                    p_person_id          => update_emp_start_date_rec.person_id,
                    p_old_start_date     =>
                        update_emp_start_date_rec.old_start_date,
                    p_new_start_date     =>
                        update_emp_start_date_rec.new_start_date,
                    p_update_type        => 'E',
                    p_applicant_number   =>
                        update_emp_start_date_rec.applicant_number,
                    p_warn_ee            => lv_warn);
                lv_msg   := 'Employee start date updated. ';
                log_success_msg (
                    p_record_id   => update_emp_start_date_rec.record_id,
                    p_msg         => lv_msg);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_msg   :=
                           'Cannot update Employee start date. '
                        || SQLERRM
                        || '. ';
                    log_error_msg (
                        p_record_id   => update_emp_start_date_rec.record_id,
                        p_err_msg     => lv_msg);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   :=
                'Cannot update Employee start date. ' || SQLERRM || '. ';
            print_log_prc (lv_msg);
    END;
END xxd_wd_to_hr_interface_pkg;
/
