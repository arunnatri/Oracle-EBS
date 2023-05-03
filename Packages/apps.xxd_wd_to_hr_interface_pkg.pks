--
-- XXD_WD_TO_HR_INTERFACE_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   XXD_WD_TO_HR_INTF_STG_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WD_TO_HR_INTERFACE_PKG"
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
    * --------------------------------------------------------------------------- */

    gc_new_status         CONSTANT VARCHAR2 (1) := 'N';
    gc_error_status       CONSTANT VARCHAR2 (1) := 'E';
    gc_reprocess_status   CONSTANT VARCHAR2 (1) := 'R';
    gc_valid_status       CONSTANT VARCHAR2 (1) := 'V';
    gc_processed_status   CONSTANT VARCHAR2 (1) := 'P';
    gn_request_id                  NUMBER := fnd_global.conc_request_id;
    gd_sysdate            CONSTANT DATE := SYSDATE;
    gn_user_id            CONSTANT NUMBER := fnd_global.user_id;
    gc_oracle_err         CONSTANT VARCHAR2 (20) := 'ORACLE';
    gc_workday_err        CONSTANT VARCHAR2 (20) := 'WORKDAY';
    gc_it_err             CONSTANT VARCHAR2 (20) := 'IT';

    --Table type declaration for staging tables
    TYPE lt_xxd_wdhr_intf_tbl_type
        IS TABLE OF xxd_wd_to_hr_intf_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    --Procedures/Functions
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT NUMBER);

    PROCEDURE create_update_employee (p_message    OUT VARCHAR2,
                                      p_ret_code   OUT NUMBER);

    PROCEDURE create_update_location (p_message    OUT VARCHAR2,
                                      p_ret_code   OUT NUMBER);

    PROCEDURE create_location (p_record_id IN NUMBER, p_location IN VARCHAR2, p_workday_location IN VARCHAR2, p_address_line_1 IN VARCHAR2, p_address_line_2 IN VARCHAR2, p_address_line_3 IN VARCHAR2, p_city IN VARCHAR2, p_zipcode IN VARCHAR2, p_country IN VARCHAR2, p_county IN VARCHAR2, p_state_province IN VARCHAR2, p_cost_center IN VARCHAR2
                               , p_company_code IN VARCHAR2);

    PROCEDURE update_location (p_record_id IN NUMBER, p_location_id IN NUMBER, p_object_version_number IN NUMBER, p_address_line_1 IN VARCHAR2, p_address_line_2 IN VARCHAR2, p_address_line_3 IN VARCHAR2, p_city IN VARCHAR2, p_zipcode IN VARCHAR2, p_country IN VARCHAR2, p_county IN VARCHAR2, p_state_province IN VARCHAR2, p_cost_center IN VARCHAR2
                               , p_company_code IN VARCHAR2);

    PROCEDURE create_employee (p_record_id IN NUMBER, p_legal_first_name IN VARCHAR2, p_legal_last_name IN VARCHAR2, p_employee_num IN VARCHAR2, p_email_address IN VARCHAR2, p_hire_date IN DATE
                               , p_business_group_id IN NUMBER);

    PROCEDURE update_employee (p_record_id IN NUMBER, p_person_id IN NUMBER, p_assignment_id IN NUMBER, p_legal_first_name IN VARCHAR2, p_legal_last_name IN VARCHAR2, p_emp_email_address IN VARCHAR2
                               , p_employment_start_date IN DATE, p_employee_num IN VARCHAR2, p_object_version_number IN NUMBER);

    PROCEDURE update_suppliers;

    PROCEDURE create_supplier (p_status OUT VARCHAR2, p_err_msg OUT VARCHAR2);

    PROCEDURE update_emp_assignments (p_message    OUT VARCHAR2,
                                      p_ret_code   OUT NUMBER);

    PROCEDURE end_date_employee (p_status    OUT VARCHAR2,
                                 p_err_msg   OUT VARCHAR2);

    PROCEDURE email_oracle_err_msg (p_from_emailaddress        VARCHAR2,
                                    p_override_email_address   VARCHAR2);

    PROCEDURE email_workday_err_msg (p_from_emailaddress        VARCHAR2,
                                     p_override_email_address   VARCHAR2);

    PROCEDURE email_it_err_msg (p_from_emailaddress        VARCHAR2,
                                p_override_email_address   VARCHAR2);

    PROCEDURE update_emp_start_date;
END xxd_wd_to_hr_interface_pkg;
/
