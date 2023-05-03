--
-- XXD_COMMON_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_COMMON_UTILS"
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
    /*+==========================================================================+
        | Function name                                                              |
        |     GET_ORG_ID                                                       |
        |                                                                            |
        | DESCRIPTION                                                                |
        |     function to fetch the session ORG_ID                    |
       +===========================================================================*/

    FUNCTION get_org_id
        RETURN VARCHAR2
    IS
        retvalue   VARCHAR2 (255);
    BEGIN
        RETURN mo_global.get_current_org_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'No Data Exist,Please provide valid ORG ID  '
                || SQLCODE
                || ' - '
                || SQLERRM (100));
            RETURN NULL;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error While retrieving the ORG ID  '
                || SQLCODE
                || ' - '
                || SQLERRM (100));
            RETURN NULL;
    END get_org_id;

    /*  To fetch the session USER ID */
    /*+==========================================================================+
    | Function name                                                              |
    |     GET_USER_ID                                                      |
    |                                                                            |
    | DESCRIPTION                                                                |
    |     function to fetch the session USER ID                   |
    +===========================================================================*/

    FUNCTION get_user_id
        RETURN VARCHAR2
    IS
        retvalue   VARCHAR2 (255);
    BEGIN
        SELECT fnd_profile.VALUE ('USER_ID') INTO retvalue FROM DUAL;

        RETURN retvalue;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'No Data Exist,Please provide valid USER ID  '
                || SQLCODE
                || ' - '
                || SQLERRM (100));
            RETURN NULL;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error While retrieving the USER ID  '
                || SQLCODE
                || ' - '
                || SQLERRM (100));
            RETURN NULL;
    END get_user_id;

    /*  To fetch the session USERNAME */
    /*+==========================================================================+
    | Function name                                                              |
    |     GET_USERNAME                                                        |
    |                                                                            |
    | DESCRIPTION                                                                |
    |     function to fetch the session USERNAME                  |
    +===========================================================================*/

    FUNCTION get_username
        RETURN VARCHAR2
    IS
        retvalue   VARCHAR2 (255);
    BEGIN
        SELECT fnd_profile.VALUE ('USERNAME') INTO retvalue FROM DUAL;

        RETURN retvalue;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'No Data Exist,Please provide valid USERNAME  '
                || SQLCODE
                || ' - '
                || SQLERRM (100));
            RETURN NULL;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error While retrieving the USERNAME  '
                || SQLCODE
                || ' - '
                || SQLERRM (100));
            RETURN NULL;
    END get_username;

    /*  To fetch the session LOGIN_ID */

    FUNCTION get_login_id
        RETURN VARCHAR2
    IS
        retvalue   VARCHAR2 (255);
    BEGIN
        SELECT fnd_profile.VALUE ('LOGIN_ID') INTO retvalue FROM DUAL;

        RETURN retvalue;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'No Data Exist,Please provide valid LOGIN_ID  '
                || SQLCODE
                || ' - '
                || SQLERRM (100));
            RETURN NULL;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error While retrieving the LOGIN_ID  '
                || SQLCODE
                || ' - '
                || SQLERRM (100));
            RETURN NULL;
    END get_login_id;

    /*+==========================================================================+
    | Procedure name                                                             |
    |     RECORD_ERROR                                                  |
    |                                                                            |
    | DESCRIPTION                                                                |
    |     Deckers Standard Error Handling Procedure                     |
    +===========================================================================*/

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
                            p_more_info4   IN VARCHAR2 DEFAULT NULL)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        v_module       VARCHAR2 (5);
        v_org_id       NUMBER;
        v_program      VARCHAR2 (100);
        v_error_msg    VARCHAR2 (4000);
        v_error_line   VARCHAR2 (4000);
        v_error_date   DATE;
        v_created_by   NUMBER;
        v_request_id   NUMBER;
        v_more_info1   VARCHAR2 (4000);
        v_more_info2   VARCHAR2 (4000);
        v_more_info3   VARCHAR2 (4000);
        v_more_info4   VARCHAR2 (4000);
    BEGIN
        v_module       := p_module;
        v_org_id       := p_org_id;
        v_program      := p_program;
        v_error_msg    := p_error_msg;
        v_error_line   := p_error_line;
        v_created_by   := p_created_by;
        v_request_id   := p_request_id;
        v_more_info1   := p_more_info1;
        v_more_info2   := p_more_info2;
        v_more_info3   := p_more_info3;
        v_more_info4   := p_more_info4;

        INSERT INTO xxd_conv.xxd_error_log_t (seq, module, org_id,
                                              object_name, error_message, error_line, creation_date, created_by, request_id, useful_info1, useful_info2, useful_info3
                                              , useful_info4)
             VALUES (xxd_error_log_seq.NEXTVAL, v_module, v_org_id,
                     v_program, v_error_msg, v_error_line,
                     SYSDATE, v_created_by, v_request_id,
                     v_more_info1, v_more_info2, v_more_info3,
                     v_more_info4);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_error_msg   := SQLERRM;

            INSERT INTO xxd_conv.xxd_error_log_t (seq, module, org_id,
                                                  object_name, error_message, error_line, creation_date, created_by, request_id
                                                  , useful_info1)
                 VALUES (xxd_error_log_seq.NEXTVAL, 'CCBL', 81,
                         'Comcast Error Handling Procedure', v_error_msg, DBMS_UTILITY.format_error_backtrace, SYSDATE, 1143, v_request_id
                         , 'Unhandled exception');

            COMMIT;
    END record_error;

    /*+==========================================================================+
        | Function name                                                              |
        |     get_gl_code_combination                                                |
        |                                                                            |
        | DESCRIPTION                                                                |
        |     Procedure to derive 12.2.3 gl_code_combination value for 12.0.6        |
        | Parameters : p_old_company, p_old_cost_center,                             |
        |              p_old_natural_account, p_old_product                          |
        +===========================================================================*/

    FUNCTION get_gl_code_combination (p_old_company IN VARCHAR2, p_old_cost_center IN VARCHAR2, p_old_natural_account IN VARCHAR2
                                      , p_old_product IN VARCHAR2)
        RETURN VARCHAR2
    AS
        ln_new_concat_segment   VARCHAR2 (311) := 0;
    BEGIN
        SELECT new_company || '.' || new_brand || '.' || new_geo || '.' || new_channel || '.' || new_cost_center || '.' || new_natural_account || '.' || new_intercompany || '.' || new_future_use
          INTO ln_new_concat_segment
          FROM xxdo.xxd_gl_coa_mapping_t
         WHERE     old_company = p_old_company
               AND old_cost_center = p_old_cost_center
               AND old_natural_account = p_old_natural_account
               AND old_product = p_old_product
               AND NVL (enabled_flag, 'Y') = 'Y';

        RETURN ln_new_concat_segment;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_new_concat_segment   := NULL;
            RETURN ln_new_concat_segment;
    END get_gl_code_combination;

    /*+==========================================================================+
       | Procedure name                                                             |
       |     get_mapping_value                                                |
       |                                                                            |
       | DESCRIPTION                                                                |
       |     Procedure to derive 12.2.3 mapping value for an entoty of 12.0.6       |
       +===========================================================================*/

    PROCEDURE get_mapping_value (p_lookup_type    IN     VARCHAR2, -- Lookup type for mapping
                                 px_lookup_code   IN OUT VARCHAR2,
                                 -- Would generally be id of 12.0.6. eg: org_id
                                 px_meaning       IN OUT VARCHAR2, -- internal name of old entity
                                 px_description   IN OUT VARCHAR2, -- name of the old entity
                                 x_attribute1        OUT VARCHAR2, -- corresponding new 12.2.3 value
                                 x_attribute2        OUT VARCHAR2,
                                 x_error_code        OUT VARCHAR2,
                                 x_error_msg         OUT VARCHAR2)
    AS
    BEGIN
        x_error_code   := NULL;
        x_error_msg    := NULL;

        IF (px_lookup_code IS NOT NULL)
        THEN
            SELECT flv.meaning, flv.description, flv.attribute1,
                   flv.attribute2
              INTO px_meaning, px_description, x_attribute1, x_attribute2
              FROM fnd_lookup_values flv
             WHERE     lookup_type = p_lookup_type
                   AND lookup_code = px_lookup_code
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1);
        ELSIF (px_meaning IS NOT NULL)
        THEN
            SELECT flv.lookup_code, flv.description, flv.attribute1,
                   flv.attribute2
              INTO px_lookup_code, px_description, x_attribute1, x_attribute2
              FROM fnd_lookup_values flv
             WHERE     lookup_type = p_lookup_type
                   AND meaning = px_meaning
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1);
        ELSIF (px_description IS NOT NULL)
        THEN
            SELECT flv.lookup_code, flv.meaning, flv.attribute1,
                   flv.attribute2
              INTO px_lookup_code, px_meaning, x_attribute1, x_attribute2
              FROM fnd_lookup_values flv
             WHERE     lookup_type = p_lookup_type
                   AND description = px_description
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error_code   := 'E';
            x_error_msg    := SQLERRM;
    END get_mapping_value;

    FUNCTION conv_to_clob (plob IN BLOB)
        RETURN CLOB
    IS
        lclob_Result     CLOB := 'X';
        l_dest_offsset   INTEGER := 1;
        l_src_offsset    INTEGER := 1;
        l_lang_context   INTEGER := DBMS_LOB.default_lang_ctx;
        l_warning        INTEGER;
    BEGIN
        IF plob IS NOT NULL AND LENGTH (plob) > 0
        THEN
            DBMS_LOB.converttoclob (dest_lob       => lclob_Result,
                                    src_blob       => plob,
                                    amount         => DBMS_LOB.lobmaxsize,
                                    dest_offset    => l_dest_offsset,
                                    src_offset     => l_src_offsset,
                                    blob_csid      => DBMS_LOB.default_csid,
                                    lang_context   => l_lang_context,
                                    warning        => l_warning);

            IF l_warning != 0
            THEN
                RETURN NULL;
            END IF;

            RETURN (lclob_Result);
        ELSE
            RETURN NULL;
        END IF;
    END conv_to_clob;
END xxd_common_utils;
/
