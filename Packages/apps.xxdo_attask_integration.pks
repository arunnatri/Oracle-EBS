--
-- XXDO_ATTASK_INTEGRATION  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ATTASK_INTEGRATION"
AS
    PROCEDURE insert_line (p_project_number VARCHAR2, p_username VARCHAR2, p_task_name VARCHAR2, p_hours_id VARCHAR2, p_hours_date DATE, p_hours NUMBER
                           , p_expenditure_organization VARCHAR2, x_ret_Stat OUT VARCHAR2, x_message OUT VARCHAR2);

    FUNCTION open_gl_Date (p_exp_item_date       IN DATE,
                           p_operating_unit_id      NUMBER)
        RETURN DATE;
END xxdo_attask_integration;
/


GRANT EXECUTE ON APPS.XXDO_ATTASK_INTEGRATION TO SOA_INT
/
