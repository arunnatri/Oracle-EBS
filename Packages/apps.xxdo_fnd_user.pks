--
-- XXDO_FND_USER  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdo_fnd_user
AS
    -- =============================================
    -- Deckers- Business Transformation
    -- Description:
    -- This package is used to create FND user and assign responsibility
    -- Run concurrent program 'Synchronize WF LOCAL tables'; Parameter: ALL, 0, NOLOGGING, , Y
    -- Run concurrent program 'Workflow Directory Services User/Role Validation' after this to create WF_ROLES
    -- Parameters: 10000, , , Y, Y, Y
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

    -- Define package global variables
    g_default_password            VARCHAR2 (30) := 'Welcome101';
    g_default_start_date          DATE := SYSDATE;
    g_default_password_lifespan   NUMBER := 90;                           -- 0
    g_security_group              VARCHAR2 (20) := 'STANDARD';
    g_new_status                  VARCHAR2 (100) := 'NEW';
    g_user_creation_success       VARCHAR2 (100) := 'USER CREATED';
    g_user_creation_error         VARCHAR2 (100) := 'USER CREATION ERROR';
    g_resp_assign_success         VARCHAR2 (100) := 'RESP ASSIGNED';
    g_resp_valid_error            VARCHAR2 (100) := 'RESP VALIDATION ERROR';
    g_resp_assign_error           VARCHAR2 (100) := 'RESP ASSIGN ERROR';
    g_emp_assign_success          VARCHAR2 (100) := 'EMP ASSIGNED';
    g_emp_assign_error            VARCHAR2 (100) := 'EMP ASSIGN ERROR';

    -- Define Program Units
    -- Main procedure which does validation and calls API wrapper procs if needed
    PROCEDURE main_proc (p_generate_password VARCHAR2 DEFAULT 'N', p_randomize VARCHAR2 DEFAULT 'N', p_create_user VARCHAR2, p_assign_resp VARCHAR2, p_assign_emp VARCHAR2, p_resp_start_date DATE DEFAULT SYSDATE
                         , p_emp_assign_date DATE DEFAULT SYSDATE);

    -- Generate random password
    PROCEDURE generate_password (p_randomize VARCHAR2);

    -- Wrapper program which invokes standard API to create user
    PROCEDURE create_user;

    -- Wrapper program which invokes standard API to assign responsibilities
    PROCEDURE assign_responsibilities (p_resp_start_date DATE);

    -- Wrapper program which invokes standard API to assign responsibilities
    PROCEDURE assign_employees (p_emp_assign_date DATE);

    PROCEDURE print_message (ip_text VARCHAR2);
END xxdo_fnd_user;
/
