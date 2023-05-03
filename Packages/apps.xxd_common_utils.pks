--
-- XXD_COMMON_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_COMMON_UTILS"
    AUTHID CURRENT_USER
AS
    /***************************************************************************************
      Program    : XXD_COMMON_UTILS
      Modifications:
      -------------------------------------------------------------------------------------
      Date           Version    Author               Description
      -------------------------------------------------------------------------------------
      05-Dec-2014    1.0        Ramya                Common Utilities
      10-Oct-2020    1.1        Viswanathan Pandian  Added file upload function for CCR0008786
    ***************************************************************************************/
    /* To fetch the organization id */
    FUNCTION get_org_id
        RETURN VARCHAR2;

    /* To fetch the session USER_ID */
    FUNCTION get_user_id
        RETURN VARCHAR2;

    /* To fetch the session USERNAME */
    FUNCTION get_username
        RETURN VARCHAR2;

    /* To fetch the session LOGIN_ID */
    FUNCTION get_login_id
        RETURN VARCHAR2;

    /* To fetch 12.2.3 code combination id */
    FUNCTION get_gl_code_combination (p_old_company IN VARCHAR2, p_old_cost_center IN VARCHAR2, p_old_natural_account IN VARCHAR2
                                      , p_old_product IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE record_error (p_module       IN VARCHAR2, --Oracle module short name
                            p_org_id       IN NUMBER,
                            p_program      IN VARCHAR2,
                            --Concurrent program, PLSQL procedure, etc..
                            p_error_msg    IN VARCHAR2,              --SQLERRM
                            p_error_line   IN VARCHAR2, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                            p_created_by   IN NUMBER,                --USER_ID
                            p_request_id   IN NUMBER DEFAULT NULL, -- concurrent request ID
                            p_more_info1   IN VARCHAR2 DEFAULT NULL,
                            --additional information for troubleshooting
                            p_more_info2   IN VARCHAR2 DEFAULT NULL,
                            p_more_info3   IN VARCHAR2 DEFAULT NULL,
                            p_more_info4   IN VARCHAR2 DEFAULT NULL);

    PROCEDURE get_mapping_value (p_lookup_type    IN     VARCHAR2, -- Lookup type for mapping
                                 px_lookup_code   IN OUT VARCHAR2,
                                 -- Would generally be id of 12.0.6. eg: org_id
                                 px_meaning       IN OUT VARCHAR2, -- internal name of old entity
                                 px_description   IN OUT VARCHAR2, -- name of the old entity
                                 x_attribute1        OUT VARCHAR2, -- corresponding new 12.2.3 value
                                 x_attribute2        OUT VARCHAR2,
                                 x_error_code        OUT VARCHAR2,
                                 x_error_msg         OUT VARCHAR2);

    -- Start changes for 1.1
    FUNCTION conv_to_clob (plob IN BLOB)
        RETURN CLOB;
-- End changes for 1.1
END xxd_common_utils;
/
