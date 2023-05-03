--
-- XXDO_FND_USER  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdo_fnd_user
AS
    -- =============================================
    -- Deckers- Business Transformation
    -- Description:
    -- This package is used to create FND user and assign responsibility
    -- =============================================
    -------------------------------------------------
    -------------------------------------------------
    --Author:
    /******************************************************************************
    1.Components: main_proc
       Purpose:  Loop through distinct users in the staging table and invoke user creation wrapper.



       Execution Method:

       Note:

    2.Components: create_user
       Purpose:  Wrapper procedure to create FND users


       Execution Method:

       Note:

    3.Components: update_user
       Purpose:  Wrapper proc


       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        3/6/2015             1.
    ******************************************************************************/

    -- Define Program Units
    -- Main procedure which does validation and calls API wrapper procs if needed
    PROCEDURE main_proc (p_generate_password VARCHAR2 DEFAULT 'N', p_randomize VARCHAR2 DEFAULT 'N', p_create_user VARCHAR2, p_assign_resp VARCHAR2, p_assign_emp VARCHAR2, p_resp_start_date DATE DEFAULT SYSDATE
                         , p_emp_assign_date DATE DEFAULT SYSDATE)
    IS
    BEGIN
        --==========================================================
        -- Handle password generation first
        IF NVL (p_generate_password, 'N') = 'Y'
        THEN
            print_message ('Generating password..');
            generate_password (p_randomize => p_randomize);
            print_message ('End generating password..');
        ELSIF NVL (p_generate_password, 'N') = 'N'
        THEN
            print_message ('Not generating password..');
        ELSE
            print_message (
                   'Valid values for p_generate_password are Y or N. Value provided: '
                || p_generate_password);
        END IF;

        --==========================================================
        --==========================================================
        -- Handle user creation
        IF NVL (p_create_user, 'N') = 'Y'
        THEN
            print_message ('Creating users..');
            create_user;
            print_message ('End creating user..');
        ELSIF NVL (p_create_user, 'N') = 'N'
        THEN
            print_message ('Not creating users..');
        ELSE
            print_message (
                   'Valid values for p_create_user are Y or N. Value provided: '
                || p_create_user);
        END IF;

        --==========================================================

        --==========================================================
        -- Handle user to resp assignment
        IF NVL (p_assign_resp, 'N') = 'Y'
        THEN
            print_message ('Creating users to resp assignment..');
            assign_responsibilities (p_resp_start_date => p_resp_start_date);
            print_message ('End assigning resp to users..');
        ELSIF NVL (p_assign_resp, 'N') = 'N'
        THEN
            print_message ('Not creating user to resp assignment..');
        ELSE
            print_message (
                   'Valid values for p_assign_resp are Y or N. Value provided: '
                || p_assign_resp);
        END IF;

        --==========================================================

        --==========================================================
        -- Handle employee assignment
        IF NVL (p_assign_emp, 'N') = 'Y'
        THEN
            print_message ('Creating employee assignment..');
            assign_employees (p_emp_assign_date => p_emp_assign_date);
            print_message ('End assigning employee to users..');
        ELSIF NVL (p_assign_emp, 'N') = 'N'
        THEN
            print_message ('Not creating employee assignment..');
        ELSE
            print_message (
                   'Valid values for p_assign_emp are Y or N. Value provided: '
                || p_assign_emp);
        END IF;

        --==========================================================

        COMMIT;
    END main_proc;

    -- Generate random password

    PROCEDURE generate_password (p_randomize VARCHAR2)
    IS
        v_password   VARCHAR2 (10);

        CURSOR c_users IS
            SELECT DISTINCT user_name
              FROM xxd_user_responsibility_t
             WHERE     password IS NULL
                   AND NVL (user_status, g_new_status) IN
                           (g_new_status, g_user_creation_error);
    BEGIN
        -- Loop through all distinct username records in the stage table
        -- Which does not already have a password
        FOR c IN c_users
        LOOP
            -- Reset
            v_password   := NULL;

            IF NVL (p_randomize, 'N') = 'Y'
            THEN
                -- Generate random password
                -- 7 character total - 5 alpha characters and 2 numbers
                SELECT DBMS_RANDOM.STRING ('a', 5) || SUBSTR (ABS (DBMS_RANDOM.random), 0, 2)
                  INTO v_password
                  FROM DUAL;
            ELSE
                v_password   := g_default_password;
            END IF;

            UPDATE XXD_USER_RESPONSIBILITY_T
               SET password   = v_password
             WHERE     user_name = c.user_name
                   AND password IS NULL
                   AND NVL (user_status, g_new_status) IN
                           (g_new_status, g_user_creation_error);
        END LOOP;

        COMMIT;
    END generate_password;

    -- Wrapper program which invokes standard API to create user

    PROCEDURE create_user
    IS
        -- Define variable
        v_count     NUMBER;
        v_message   VARCHAR2 (4000);

        -- Cursor to go through unique user records in new or error status
        CURSOR c_user IS
              SELECT user_name, start_date, end_date,
                     description, email, password
                FROM xxd_user_responsibility_t
               WHERE NVL (user_status, g_new_status) IN
                         (g_new_status, g_user_creation_error)
            GROUP BY user_name, start_date, end_date,
                     description, email, password;
    BEGIN
        FOR cr_user IN c_user
        LOOP
            -- Reset Variables
            v_message   := NULL;
            v_count     := NULL;

            -- Check if this user exists
            SELECT COUNT (user_id)
              INTO v_count
              FROM fnd_user
             WHERE user_name = UPPER (cr_user.user_name);

            IF v_count = 0
            THEN
                -- User not in system, proceed with creation
                --Create user
                BEGIN
                    -- Call API
                    fnd_user_pkg.createuser (
                        x_user_name                =>
                            LTRIM (RTRIM (UPPER (cr_user.user_name))),
                        x_owner                    => NULL,
                        x_unencrypted_password     =>
                            NVL (cr_user.password, g_default_password),
                        x_start_date               =>
                            NVL (cr_user.start_date, g_default_start_date),
                        x_description              =>
                            NVL (cr_user.description, cr_user.user_name),
                        x_end_date                 => cr_user.end_date,
                        x_password_date            => NULL,
                        x_password_lifespan_days   =>
                            g_default_password_lifespan,
                        x_employee_id              => NULL,
                        x_email_address            => cr_user.email);

                    -- All is well
                    print_message ('User created: ' || cr_user.user_name);

                    UPDATE xxd_user_responsibility_t
                       SET user_status = g_user_creation_success, creation_date = SYSDATE
                     WHERE     user_name = cr_user.user_name
                           AND NVL (user_status, g_new_status) IN
                                   (g_new_status, g_user_creation_error);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_message   :=
                               'User creation error for '
                            || cr_user.user_name
                            || '. Error - '
                            || SUBSTR (SQLERRM, 1, 200);

                        print_message (v_message);

                        UPDATE xxd_user_responsibility_t
                           SET user_status = g_user_creation_error, user_message = v_message
                         WHERE     user_name = cr_user.user_name
                               AND NVL (user_status, g_new_status) IN
                                       (g_new_status, g_user_creation_error);
                END;
            ELSE
                v_message   := 'User already exists - ' || cr_user.user_name;

                -- User already created
                print_message (v_message);

                UPDATE xxd_user_responsibility_t
                   SET user_status = g_user_creation_success, user_message = v_message
                 WHERE     user_name = cr_user.user_name
                       AND NVL (user_status, g_new_status) IN
                               (g_new_status, g_user_creation_error);
            END IF;

            COMMIT;
        END LOOP;
    END create_user;

    -- Wrapper program which invokes standard API to assign responsibilities

    PROCEDURE assign_responsibilities (p_resp_start_date DATE)
    IS
        -- Define variable
        v_count               NUMBER;
        v_message             VARCHAR2 (4000);
        v_status              VARCHAR2 (100);
        v_resp_key            fnd_responsibility.responsibility_key%TYPE;
        v_responsibility_id   NUMBER;
        v_user_id             NUMBER;
        v_application_id      NUMBER;
        v_assign_count        NUMBER;
        v_app_short_name      fnd_application.application_short_name%TYPE;

        -- Cursor to go through unique resp records in new or error status
        CURSOR c_resp IS
              SELECT responsibility_name
                FROM xxd_user_responsibility_t
               WHERE NVL (resp_status, g_new_status) IN
                         (g_new_status, g_resp_valid_error)
            GROUP BY responsibility_name;

        -- Cursor to go through unique user and resp  records in new status
        CURSOR c_user IS
              SELECT user_name
                FROM xxd_user_responsibility_t
               WHERE NVL (resp_status, g_new_status) IN
                         (g_new_status, g_resp_valid_error)
            GROUP BY user_name;

        -- Cursor to go through unique user and resp  records in new status
        CURSOR c_user_resp IS
              SELECT user_name, responsibility_id, responsibility_name,
                     responsibility_key, application_short_name
                FROM xxd_user_responsibility_t
               WHERE NVL (resp_status, g_new_status) IN
                         (g_new_status, g_resp_assign_error)
            GROUP BY user_name, responsibility_id, responsibility_name,
                     responsibility_key, application_short_name;
    BEGIN
        -- Validate responsibilities first
        FOR c IN c_resp
        LOOP
            -- Reset Variable
            v_responsibility_id   := NULL;
            v_resp_key            := NULL;
            v_app_short_name      := NULL;

            -- Validate Responsibility for given start date
            BEGIN
                SELECT frv.responsibility_id, frv.responsibility_key, fa.application_short_name
                  INTO v_responsibility_id, v_resp_key, v_app_short_name
                  FROM fnd_responsibility_vl frv, fnd_application fa
                 WHERE     LTRIM (RTRIM (UPPER (frv.responsibility_name))) =
                           LTRIM (RTRIM (UPPER (c.responsibility_name)))
                       AND frv.application_id = fa.application_id
                       AND NVL (p_resp_start_date, SYSDATE) BETWEEN frv.start_date
                                                                AND NVL (
                                                                        frv.end_date,
                                                                        DECODE (
                                                                            p_resp_start_date,
                                                                            NULL,   SYSDATE
                                                                                  + 1,
                                                                              p_resp_start_date
                                                                            + 1));


                -- Get responsibility_key and app short name
                UPDATE xxd_user_responsibility_t
                   SET resp_status = NULL, resp_message = NULL, responsibility_id = v_responsibility_id,
                       responsibility_key = v_resp_key, application_short_name = v_app_short_name
                 WHERE     responsibility_name = c.responsibility_name
                       AND NVL (resp_status, g_new_status) IN
                               (g_new_status, g_resp_valid_error);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_message   :=
                           'Active responsibility does not exists - '
                        || c.responsibility_name;

                    -- Update error status and message
                    UPDATE xxd_user_responsibility_t
                       SET resp_status = g_resp_valid_error, resp_message = v_message
                     WHERE     responsibility_name = c.responsibility_name
                           AND NVL (resp_status, g_new_status) IN
                                   (g_new_status, g_resp_valid_error);
                WHEN OTHERS
                THEN
                    v_message   :=
                           'Error in validating resp ~ '
                        || SUBSTR (SQLERRM, 1, 100);

                    -- Update error status and message
                    UPDATE xxd_user_responsibility_t
                       SET resp_status = g_resp_valid_error, resp_message = v_message
                     WHERE     responsibility_name = c.responsibility_name
                           AND NVL (resp_status, g_new_status) IN
                                   (g_new_status, g_resp_valid_error);
            END;

            COMMIT;
        END LOOP;

        -- End Validating responsibilities, Now go through users
        FOR c IN c_user
        LOOP
            -- Reset Users
            v_user_id   := NULL;
            v_message   := NULL;

            -- Start validation of users
            BEGIN
                SELECT user_id
                  INTO v_user_id
                  FROM fnd_user fu
                 WHERE     UPPER (user_name) =
                           LTRIM (RTRIM (UPPER (c.user_name)))
                       AND NVL (p_resp_start_date, SYSDATE) BETWEEN fu.start_date
                                                                AND NVL (
                                                                        fu.end_date,
                                                                        DECODE (
                                                                            p_resp_start_date,
                                                                            NULL,   SYSDATE
                                                                                  + 1,
                                                                              p_resp_start_date
                                                                            + 1));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    -- No active user found, problem!
                    v_message   :=
                           'User does not exists -.'
                        || c.user_name
                        || ' on given date '
                        || NVL (p_resp_start_date, SYSDATE);

                    -- Update error status and message
                    UPDATE xxd_user_responsibility_t
                       SET resp_status = g_resp_valid_error, resp_message = v_message
                     WHERE     user_name = c.user_name
                           AND NVL (resp_status, g_new_status) IN
                                   (g_new_status, g_resp_valid_error);
            END;

            COMMIT;
        END LOOP;

        -- Now go through user and resp assignment
        FOR c IN c_user_resp
        LOOP
            -- Reset variable
            v_assign_count   := NULL;
            v_message        := NULL;

            -- See if this responsibility is already assigned to the user
            BEGIN
                SELECT COUNT (*)
                  INTO v_assign_count
                  FROM FND_USER_RESP_GROUPS_ALL ur, fnd_user fu
                 WHERE     LTRIM (RTRIM (UPPER (fu.user_name))) =
                           LTRIM (RTRIM (UPPER (c.user_name)))
                       AND ur.user_id = fu.user_id
                       AND responsibility_id = c.responsibility_id
                       AND NVL (p_resp_start_date, SYSDATE) BETWEEN ur.start_date
                                                                AND NVL (
                                                                        ur.end_date,
                                                                        DECODE (
                                                                            p_resp_start_date,
                                                                            NULL,   SYSDATE
                                                                                  + 1,
                                                                              p_resp_start_date
                                                                            + 1));

                IF v_assign_count > 0
                THEN
                    v_message   :=
                           'Responsibility - '
                        || c.responsibility_name
                        || ', already assigned to user - '
                        || c.user_name;

                    -- Update error status and message
                    UPDATE xxd_user_responsibility_t
                       SET resp_status = g_resp_assign_success, resp_message = v_message
                     WHERE     user_name = c.user_name
                           AND responsibility_name = c.responsibility_name
                           AND NVL (resp_status, g_new_status) IN
                                   (g_new_status, g_resp_assign_error);
                ELSE
                    -- Passed all validation, assign resp now
                    -- Call API
                    BEGIN
                        fnd_user_pkg.addresp (username => LTRIM (RTRIM (UPPER (c.user_name))), resp_app => c.application_short_name, resp_key => c.responsibility_key, security_group => 'STANDARD', description => NULL, start_date => p_resp_start_date
                                              , end_date => NULL);

                        -- Update status in stage
                        UPDATE xxd_user_responsibility_t
                           SET resp_status = g_resp_assign_success, resp_message = NULL
                         WHERE     user_name = c.user_name
                               AND responsibility_name =
                                   c.responsibility_name
                               AND NVL (resp_status, g_new_status) IN
                                       (g_new_status, g_resp_assign_error);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            v_message   :=
                                   'API Error in assigning resp to user. '
                                || SUBSTR (SQLERRM, 1, 100);

                            -- Update error status and message
                            UPDATE xxd_user_responsibility_t
                               SET resp_status = g_resp_assign_error, resp_message = v_message
                             WHERE     user_name = c.user_name
                                   AND responsibility_name =
                                       c.responsibility_name
                                   AND NVL (resp_status, g_new_status) IN
                                           (g_new_status, g_resp_assign_error);
                    END;
                END IF;
            END;

            COMMIT;
        END LOOP;
    END assign_responsibilities;

    -- Wrapper program which invokes standard API to assign responsibilities

    PROCEDURE assign_employees (p_emp_assign_date DATE)
    IS
        v_message          VARCHAR2 (4000);
        v_employee_id      NUMBER;
        v_employee_valid   BOOLEAN;

        CURSOR c_emp IS
              SELECT user_name, employee_no
                FROM xxd_user_responsibility_t
               WHERE     NVL (emp_status, g_new_status) IN
                             (g_new_status, g_emp_assign_error)
                     AND employee_no IS NOT NULL
            GROUP BY user_name, employee_no;
    BEGIN
        FOR c IN c_emp
        LOOP
            v_employee_id      := NULL;
            v_employee_valid   := TRUE;
            v_message          := NULL;

            -- Validate employee
            BEGIN
                -- Check employee for given full name which is valid as on user start date
                SELECT person_id
                  INTO v_employee_id
                  FROM per_all_people_f
                 WHERE     employee_number = c.employee_no
                       AND NVL (p_emp_assign_date, SYSDATE) BETWEEN effective_start_date
                                                                AND NVL (
                                                                        effective_end_date,
                                                                          SYSDATE
                                                                        + 1);
            -- Employee found, thats good!
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_employee_valid   := FALSE;
                    v_message          :=
                        'Employee not found - ' || c.employee_no;
            END;


            IF v_employee_valid
            THEN
                BEGIN
                    -- Call API
                    fnd_user_pkg.updateuser (
                        x_user_name     => LTRIM (RTRIM (UPPER (c.user_name))),
                        x_owner         => NULL,
                        x_employee_id   => v_employee_id);

                    -- Update status
                    UPDATE xxd_user_responsibility_t
                       SET emp_status = g_emp_assign_success, emp_message = NULL
                     WHERE     user_name = c.user_name
                           AND employee_no = c.employee_no;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_message   :=
                               'API Error in assigning resp to user. '
                            || SUBSTR (SQLERRM, 1, 100);

                        -- Update error status and message
                        UPDATE xxd_user_responsibility_t
                           SET emp_status = g_emp_assign_error, emp_message = v_message
                         WHERE     user_name = c.user_name
                               AND employee_no = c.employee_no;
                END;
            ELSE
                -- Update error status and message
                UPDATE xxd_user_responsibility_t
                   SET emp_status = g_emp_assign_error, emp_message = v_message
                 WHERE     user_name = c.user_name
                       AND employee_no = c.employee_no;
            END IF;

            COMMIT;
        END LOOP;
    END assign_employees;

    -- Print given message on DBMS output and FND Log

    PROCEDURE print_message (ip_text VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (ip_text);
        fnd_file.put_line (fnd_file.LOG, ip_text);
    END print_message;
END xxdo_fnd_user;
/
