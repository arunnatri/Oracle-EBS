--
-- XXDO_ERROR_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ERROR_PKG"
    AUTHID CURRENT_USER
AS
    -------------------------------------------------------------------------
    -- Declare global variables to store exception code and message string --
    -------------------------------------------------------------------------
    gv_exception_code   VARCHAR2 (2000);
    gv_msg_string       VARCHAR2 (2000);


    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : set_exception_token                                    --
    -- PARAMETERS  : pv_exception_code - Exception Code for which token is  --
    --                                   to be set                          --
    --           pv_token_name - Token Name to be set                   --
    --           pv_token_value - Token value to be set                 --
    -- PURPOSE     : This procedure will be used to set token for error     --
    --               message                                                --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE set_exception_token (pv_exception_code IN VARCHAR2, pv_token_name IN VARCHAR2, pv_token_value IN VARCHAR2);

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : log_exception                                          --
    -- PARAMETERS  : pv_exception_code  - Exception code as in exception    --
    --                                    master                            --
    --           pv_component_name  - Component Name. If it is not       --
    --                    given for a concurrent program    --
    --                    it will be derived             --
    --           pv_application_code - Application Code. If it is not   --
    --                    given for a concurrent program    --
    --                    it will be derived             --
    --               pv_subprogram_code - package.procedure with in the     --
    --                                    program                           --
    --           pv_operation_code  - Operation Name in the program     --
    --           pv_operation_key   - Primary key to identify the record--
    --               pv_log_flag        - Flag to log the message in log    --
    --                                    file                              --
    --               pv_to_mailing_list - To mailing list              --
    --           pv_cc_mailing_list - CC mailing list              --
    --           pv_subject         - Subject                  --
    --           pv_body          - Body                  --
    --           pv_token_name1     - Token Name 1              --
    --           pv_token_value1    - Token Value 1              --
    --           pv_token_name2     - Token Name 2              --
    --           pv_token_value2    - Token Value 2              --
    --           pv_token_name3     - Token Name 3              --
    --           pv_token_value3    - Token Value 3              --
    --           pv_token_name4     - Token Name 4              --
    --           pv_token_value4    - Token Value 4              --
    --           pv_token_name5     - Token Name 5              --
    --           pv_token_value5    - Token Value 5              --
    --           pv_attribute1 - Additional Information in errors table --
    --           pv_attribute2 - Additional Information in errors table --
    --           pv_attribute3 - Additional Information in errors table --
    --           pv_attribute4 - Additional Information in errors table --
    --           pv_attribute5 - Additional Information in errors table --
    -- PURPOSE     : This procedure will be used to insert data into errors --
    --               table                                                  --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE log_exception (pv_exception_code     IN VARCHAR2,
                             pv_component_name     IN VARCHAR2 DEFAULT NULL,
                             pv_application_code   IN VARCHAR2 DEFAULT NULL,
                             pv_subprogram_code    IN VARCHAR2 DEFAULT NULL,
                             pv_operation_code     IN VARCHAR2 DEFAULT NULL,
                             pv_operation_key      IN VARCHAR2 DEFAULT NULL,
                             pv_log_flag           IN VARCHAR2 DEFAULT 'Y',
                             pv_to_mailing_list    IN VARCHAR2 DEFAULT NULL,
                             pv_cc_mailing_list    IN VARCHAR2 DEFAULT NULL,
                             pv_subject            IN VARCHAR2 DEFAULT NULL,
                             pv_body               IN VARCHAR2 DEFAULT NULL,
                             pv_token_name1        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value1       IN VARCHAR2 DEFAULT NULL,
                             pv_token_name2        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value2       IN VARCHAR2 DEFAULT NULL,
                             pv_token_name3        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value3       IN VARCHAR2 DEFAULT NULL,
                             pv_token_name4        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value4       IN VARCHAR2 DEFAULT NULL,
                             pv_token_name5        IN VARCHAR2 DEFAULT NULL,
                             pv_token_value5       IN VARCHAR2 DEFAULT NULL,
                             pv_attribute1         IN VARCHAR2 DEFAULT NULL,
                             pv_attribute2         IN VARCHAR2 DEFAULT NULL,
                             pv_attribute3         IN VARCHAR2 DEFAULT NULL,
                             pv_attribute4         IN VARCHAR2 DEFAULT NULL,
                             pv_attribute5         IN VARCHAR2 DEFAULT NULL);

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : log_message                                            --
    -- PARAMETERS  : pv_message      - Message to be logged                 --
    --               pv_destination  - Flag to log the message in log/output--
    --                                 /dbms_output                         --
    --           pv_component_name - Component Name. If it is not       --
    --                       given for a concurrent program     --
    --                       it will be derived             --
    -- PURPOSE     : This procedure will be used to log messages for debug  --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE log_message (pv_message IN VARCHAR2, pv_destination IN VARCHAR2 DEFAULT NULL, pv_component_name IN VARCHAR2 DEFAULT NULL);
END xxdo_error_pkg;
/
