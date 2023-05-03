--
-- XXDO_ATTASK_INTEGRATION  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ATTASK_INTEGRATION"
AS
    /*****************************************************************************************
      * Program Name : XXDO_ATTASK_INTEGRATION
      * Language     : PL/SQL
      * Description  :
      *
      * History      :
      *
      * WHO                  Version       DATE                    Desc
      * -------------- ---------------------------------------------- -----------------------
      * BT Technology Team    1.0
      * Infosys               1.1         22/08/2016                CCR0005402
      * Infosys               1.2         22/01/2018                CCR0006962
      * Development Team      1.3         08/05/2020                CCR0008610
      * --------------------------------------------------------------------------- */
    PROCEDURE prorate_time (p_employee_number IN NUMBER, p_person_id IN NUMBER, p_expenditure_end_date IN DATE, p_batch_name IN VARCHAR2, p_hours_booked IN OUT NUMBER, x_ret_Stat OUT VARCHAR2
                            , x_message OUT VARCHAR2)
    IS
        l_hard_time        NUMBER;
        l_remaining_time   NUMBER;
        l_multiplier       NUMBER;
        l_soft_time        NUMBER;
    BEGIN
        x_ret_stat         := 'S';

        SELECT NVL (SUM (peia.quantity), 0)
          INTO l_hard_time
          FROM pa_expenditures_all pea, pa_expenditure_items_all peia
         WHERE     pea.incurred_By_person_id = p_person_id
               AND DECODE (TO_CHAR (TO_DATE (peia.attribute9), 'DAY'),
                           'SATURDAY ', TO_DATE (peia.attribute9),
                           NEXT_DAY (TO_DATE (peia.attribute9), 'SATURDAY')) =
                   TO_CHAR (p_expenditure_end_date)
               AND peia.expenditure_id = pea.expenditure_id
               AND peia.expenditure_type = 'Employee Time - CAPEX';

        l_remaining_time   := 40 - l_hard_time;

        BEGIN
            SELECT NVL (SUM (TO_NUMBER (attribute8)), 0)
              INTO l_soft_time
              FROM apps.pa_transaction_interface_all peia
             WHERE     employee_number = p_employee_number
                   AND batch_name = p_batch_name
                   AND DECODE (
                           TO_CHAR (TO_DATE (peia.attribute9), 'DAY'),
                           'SATURDAY ', TO_DATE (peia.attribute9),
                           NEXT_DAY (TO_DATE (peia.attribute9), 'SATURDAY')) =
                       TO_CHAR (p_expenditure_end_date)
                   AND transaction_status_code = 'P';
        EXCEPTION
            WHEN OTHERS
            THEN
                x_ret_Stat   := 'E';
                x_message    :=
                    'Potential corruption in integration - ' || SQLERRM;
        END;

        l_soft_time        := l_soft_time + p_hours_booked;
        l_multiplier       :=
            GREATEST (LEAST (1, l_remaining_time / l_soft_time), 0);

        IF l_multiplier < 1 AND l_multiplier >= 0
        THEN
            p_hours_booked   :=
                TRUNC (NVL (p_hours_booked * l_multiplier, 0), 2);

            UPDATE apps.pa_transaction_interface_all peia
               SET quantity = TRUNC (NVL (TO_NUMBER (attribute8) * l_multiplier, 0), 2)
             WHERE     employee_number = p_employee_number
                   AND batch_name = p_batch_name
                   AND DECODE (
                           TO_CHAR (TO_DATE (peia.attribute9), 'DAY'),
                           'SATURDAY ', TO_DATE (peia.attribute9),
                           NEXT_DAY (TO_DATE (peia.attribute9), 'SATURDAY')) =
                       TO_CHAR (p_expenditure_end_date)
                   AND transaction_status_code = 'P';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := 'U';
            x_message    := 'Exception in prorate_time (' || SQLERRM || ')';
    END;

    FUNCTION open_gl_Date (p_exp_item_date       IN DATE,
                           p_operating_unit_id      NUMBER)
        RETURN DATE
    IS
        open_date   DATE;
    BEGIN
        SELECT MIN (p_exp_item_date)
          INTO open_date
          FROM pa_implementations_all pia, gl_period_statuses gps_gl, gl_period_statuses gps_proj
         WHERE     pia.org_id = p_operating_unit_id
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

        IF (open_date IS NULL)
        THEN
            SELECT MAX (gps_proj.end_date)
              INTO open_date
              FROM pa_implementations_all pia, gl_period_statuses gps_gl, gl_period_statuses gps_proj
             WHERE     pia.org_id = p_operating_unit_id
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

        IF open_date IS NULL
        THEN
            SELECT MIN (gps_proj.start_date)
              INTO open_date
              FROM pa_implementations_all pia, gl_period_statuses gps_gl, gl_period_statuses gps_proj
             WHERE     pia.org_id = p_operating_unit_id
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

        IF open_date IS NULL
        THEN
            open_date   := p_exp_item_date;
        END IF;

        RETURN open_date;
    END;

    PROCEDURE insert_line (p_project_number VARCHAR2, p_username VARCHAR2, p_task_name VARCHAR2, p_hours_id VARCHAR2, p_hours_date DATE, p_hours NUMBER
                           , p_expenditure_organization VARCHAR2, x_ret_Stat OUT VARCHAR2, x_message OUT VARCHAR2)
    IS
        l_line           apps.pa_transaction_interface_all%ROWTYPE;
        l_person_id      NUMBER;
        l_prorate_date   DATE;
    BEGIN
        do_debug_tools.enable_table (100000);
        do_debug_tools.msg ('Begin xxdo_attask_integration.insert_line');
        x_ret_Stat                          := 'U';
        l_line.quantity                     := p_hours;
        l_line.expenditure_item_date        := p_hours_date;

        SELECT DECODE (TO_CHAR (p_hours_date, 'DAY'), 'SATURDAY ', p_hours_date, NEXT_DAY (p_hours_date, 'SATURDAY'))
          INTO l_line.expenditure_ending_date
          FROM DUAL;

        l_prorate_date                      := l_line.expenditure_ending_date;
        l_line.attribute_category           := 'AtTask Time Card Information';
        l_line.attribute2                   := SUBSTR (p_task_name, 1, 150); --W.r.t version 1.2
        l_line.attribute8                   := p_hours;
        l_line.attribute9                   := TO_CHAR (p_hours_date);
        l_line.orig_transaction_reference   := p_hours_id;
        l_line.project_number               := p_project_number;
        --l_line.employee_number := p_username;  W.r.t version 1.1 CCR0005402?
        l_line.transaction_source           := 'XXDO_ATTASK_TIMECARD';
        l_line.expenditure_type             := 'Employee Time - CAPEX';
        l_line.transaction_status_code      := 'P';
        l_line.system_linkage               := 'ST';
        do_debug_tools.msg ('Made it here');

        BEGIN
            SELECT org_id
              INTO l_line.org_id
              FROM pa_projects_all
             WHERE segment1 = p_project_number;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_ret_Stat   := 'E';
                x_message    :=
                    'Unable to find project (' || p_project_number || ')';
                RETURN;
            WHEN TOO_MANY_ROWS
            THEN
                x_ret_Stat   := 'E';
                x_message    :=
                       'Too many records found when looking for project ('
                    || p_project_number
                    || ')';
                RETURN;
        END;

        mo_global.set_policy_context ('S', l_line.org_id);

        BEGIN
            SELECT task_number
              INTO l_line.task_number
              FROM apps.pa_projects_all ppa, apps.pa_tasks pt
             WHERE     ppa.segment1 = p_project_number
                   AND pt.project_id = ppa.project_id
                   AND UPPER (task_name) LIKE '%EMP%TIME%CAPEX%';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_ret_Stat   := 'E';
                x_message    :=
                       'Unable to find Employee time capex task number for project ('
                    || p_project_number
                    || ')';
                do_debug_tools.msg ('Return error: ' || x_ret_Stat);
                RETURN;
            WHEN TOO_MANY_ROWS
            THEN
                x_ret_Stat   := 'E';
                x_message    :=
                       'Too many records found when looking for Employee time capex task number for project ('
                    || p_project_number
                    || ')';
                do_debug_tools.msg ('Return error: ' || x_ret_Stat);
                RETURN;
        END;

        l_line.organization_name            := p_expenditure_organization;

        --  begin
        --    select max(segment_value_lookup), count(*)
        --      into l_line.organization_name
        --      from apps.pa_segment_value_lookup_Sets pss
        --         , apps.pa_segment_value_lookups psv
        --         , apps.gl_code_combinations gcc
        --         , apps.per_all_people_f ppf
        --         , apps.per_all_assignments_f paaf
        --      where psv.segment_value_lookup_set_id = pss.segment_value_lookup_set_id
        --        and ppf.person_id = paaf.person_id
        --        and segment_value_lookup_set_name = 'DO_EXP_ORG_COST_CENTER'
        --        and segment_value = gcc.segment5
        --        and paaf.default_code_comb_id = gcc.code_combination_id
        --        and ppf.attribute3 = p_username
        --        and sysdate between ppf.effective_start_Date and ppf.effective_end_Date
        --        and sysdate between paaf.effective_start_date and paaf.effective_end_date
        --        and rownum = 1;
        --  exception
        --    when no_Data_found then
        --      x_ret_Stat := 'E';
        --      x_message := 'Unable to find organization name for employee ('||p_username||') on project ('||p_project_number||')';
        --      return;
        --    when too_many_rows then
        --      x_ret_Stat := 'E';
        --      x_message := 'Too many records found when looking for organization name for employee ('||p_username||') on project ('||p_project_number||')';
        --      return;
        --  end;



        BEGIN
            SELECT employee_number, person_id
              INTO l_line.employee_number, l_person_id
              FROM apps.per_all_people_f ppf
             WHERE     ppf.email_address = p_username
                   AND SYSDATE BETWEEN ppf.effective_start_Date
                                   AND ppf.effective_end_Date;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_ret_Stat   := 'E';
                x_message    :=
                       'Unable to find organization name for employee ('
                    || p_username
                    || ') on project ('
                    || p_project_number
                    || ')';
                do_debug_tools.msg ('Return error: ' || x_ret_Stat);
                RETURN;
            WHEN TOO_MANY_ROWS
            THEN
                BEGIN                               -- Start W.r.t version 1.3
                    SELECT employee_number, person_id
                      INTO l_line.employee_number, l_person_id
                      FROM apps.per_all_people_f ppf
                     WHERE     ppf.email_address = p_username
                           AND SYSDATE BETWEEN ppf.effective_start_Date
                                           AND ppf.effective_end_Date
                           AND ppf.current_employee_flag = 'Y';
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        x_ret_Stat   := 'E';
                        x_message    :=
                               'Unable to find organization name for employee flag=Y ('
                            || p_username
                            || ') on project ('
                            || p_project_number
                            || ')';
                        do_debug_tools.msg ('Return error: ' || x_ret_Stat);
                        RETURN;
                    WHEN TOO_MANY_ROWS
                    THEN
                        x_ret_Stat   := 'E';
                        x_message    :=
                               'Too many records found when looking for organization name for current employee flag=Y ('
                            || p_username
                            || ') on project ('
                            || p_project_number
                            || ')';
                        do_debug_tools.msg ('Return error: ' || x_ret_Stat);
                        RETURN;
                END;                                  -- END W.r.t version 1.3
        END;



        l_line.expenditure_item_date        :=
            open_gl_date (l_line.expenditure_item_date, l_line.org_id);

        SELECT DECODE (TO_CHAR (l_line.expenditure_item_date, 'DAY'), 'SATURDAY ', l_line.expenditure_item_date, NEXT_DAY (l_line.expenditure_item_date, 'SATURDAY'))
          INTO l_line.expenditure_ending_date
          FROM DUAL;

        l_line.batch_name                   :=
               'ATTASKTIMEINTERFACE-'
            || TO_CHAR (l_line.expenditure_ending_date, 'YYYYMMDD')
            || '-'
            || l_line.org_id;
        l_line.last_update_Date             := SYSDATE;
        l_line.last_updated_by              := NVL (fnd_global.user_id, 1157);
        l_line.creation_date                := SYSDATE;
        l_line.created_by                   := NVL (fnd_global.user_id, 1157);
        prorate_time (p_employee_number => l_line.employee_number, p_person_id => l_person_id, p_expenditure_end_date => l_prorate_date, p_batch_name => l_line.batch_name, p_hours_booked => l_line.quantity, x_ret_Stat => x_ret_stat
                      , x_message => x_message);

        IF x_ret_Stat != 'S'
        THEN
            do_debug_tools.msg ('Return error: ' || x_ret_Stat);
            RETURN;
        END IF;

        do_debug_tools.msg (
            'Inserting into apps.pa_transaction_interface_all');

        INSERT INTO apps.pa_transaction_interface_all
             VALUES l_line;

        x_ret_stat                          := 'S';
        x_message                           := 'Successful completion';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_Stat   := 'U';
            x_message    := SQLERRM;
    END;
END xxdo_attask_integration;
/


GRANT EXECUTE ON APPS.XXDO_ATTASK_INTEGRATION TO SOA_INT
/
