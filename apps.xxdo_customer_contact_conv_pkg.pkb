--
-- XXDO_CUSTOMER_CONTACT_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDO_CUSTOMER_CONTACT_CONV_PKG
AS
    /*******************************************************************************
    * Program Name : XXDO_CUSTOMER_CONTACT_CONV_PKG
    * Language     : PL/SQL
    * Description  : This package will convert customer contact.
    *
    * History      :
    *
    * WHO                  WHAT              DESC                       WHEN
    * -------------- ---------------------------------------------- ---------------
    *                      1.0              Initial Version          14-MAY-2015
    *******************************************************************************/
    gc_recordvalidation           VARCHAR2 (40);
    gc_err_msg                    VARCHAR2 (2000);
    gn_cust_ins                   NUMBER := 0;
    gn_prof_ins                   NUMBER := 0;
    gn_cont_ins                   NUMBER := 0;
    gn_cust_val                   NUMBER := 0;
    gn_cust_site_val              NUMBER := 0;
    gn_site_use_val               NUMBER := 0;
    gn_prof_val                   NUMBER := 0;
    gn_cont_val                   NUMBER := 0;
    gn_cont_point_val             NUMBER := 0;
    gn_cust_val_err               NUMBER := 0;
    gn_cust_site_err              NUMBER := 0;
    gn_site_use_err               NUMBER := 0;
    gn_prof_err                   NUMBER := 0;
    gn_cont_val_err               NUMBER := 0;
    gn_cont_point_err             NUMBER := 0;
    gn_cust_sucuess               NUMBER := 0;
    gn_prof_sucuess               NUMBER := 0;
    gn_cont_sucuess               NUMBER := 0;
    gn_err_cnt                    NUMBER := 0;
    gc_customer_name              VARCHAR2 (250);
    gc_cust_address               VARCHAR2 (250);
    gc_cust_site_use              VARCHAR2 (250);
    gc_cust_contact               VARCHAR2 (250);
    gc_cust_contact_point         VARCHAR2 (250);

    gc_auto_site_numbering        VARCHAR2 (25);
    gc_generate_customer_number   VARCHAR2 (25);

    --
    --  TYPE xxd_ar_cust_cont_int_tab IS TABLE OF xxdo_ar_cust_contacts_stg_t%ROWTYPE
    --                                     INDEX BY BINARY_INTEGER;
    --
    --  gtt_ar_cust_cont_int_tab         xxd_ar_cust_cont_int_tab;


    --End of adding prc by BT Technology team on 25-May-2015
    /******************************************************
    * Procedure: log_recordss
    *
    * Synopsis: This procedure will call we be called by the concurrent program
     * Design:
     *
     * Notes:
     *
     * PARAMETERS:
     *   IN    : p_debug    Varchar2
     *   IN    : p_message  Varchar2
     *
     * Return Values:
     * Modifications:
     *
     ******************************************************/
    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    -----25-May-2015---
    FUNCTION get_targetorg_id (p_org_name IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : get_targetorg_id                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name             |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        x_org_id   NUMBER;
    BEGIN
        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (name) = UPPER (p_org_name);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'AR',
                gn_org_id,
                'Decker Customer Conversion Program',         --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_targetorg_id;

    FUNCTION get_org_id (p_org_name IN VARCHAR2)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
        x_org_id         NUMBER;
    BEGIN
        px_meaning   := p_org_name;
        apps.xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code, -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (name) = UPPER (x_attribute1);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'AR',
                gn_org_id,
                'Decker Customer Conversion Program',         --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_org_id;

    FUNCTION get_org_id (p_1206_org_id IN NUMBER)
        RETURN NUMBER
    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name,p_request_id,p_inter_head_id              |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    IS
        px_lookup_code   VARCHAR2 (250);
        px_meaning       VARCHAR2 (250);        -- internal name of old entity
        px_description   VARCHAR2 (250);             -- name of the old entity
        x_attribute1     VARCHAR2 (250);     -- corresponding new 12.2.3 value
        x_attribute2     VARCHAR2 (250);
        x_error_code     VARCHAR2 (250);
        x_error_msg      VARCHAR (250);
        x_org_id         NUMBER;
    BEGIN
        --         px_meaning := p_org_name;
        px_lookup_code   := p_1206_org_id;
        apps.xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
            px_lookup_code   => px_lookup_code, -- Would generally be id of 12.0.6. eg: org_id
            px_meaning       => px_meaning,     -- internal name of old entity
            px_description   => px_description,      -- name of the old entity
            x_attribute1     => x_attribute1, -- corresponding new 12.2.3 value
            x_attribute2     => x_attribute2,
            x_error_code     => x_error_code,
            x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (name) = UPPER (x_attribute1);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'AR',
                gn_org_id,
                'Decker Customer Conversion Program',         --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_1206_org_id,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_org_id;

    -----25-May-2015--------------------


    --Use this routine to create a role responsibility. This API creates records in the
    --HZ_ROLE_RESPONSIBILITY table.

    PROCEDURE create_role_contact (
        p_role_responsibility_rec   hz_cust_account_role_v2pub.role_responsibility_rec_type)
    IS
        x_responsibility_id   NUMBER;
        x_return_status       VARCHAR2 (2000);
        x_msg_count           NUMBER;
        x_msg_data            VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_role_contact';
        hz_cust_account_role_v2pub.create_role_responsibility (
            'T',
            p_role_responsibility_rec,
            x_responsibility_id,
            x_return_status,
            x_msg_count,
            x_msg_data);

        IF (x_return_status = 'S')
        THEN
            log_records (
                gc_debug_flag,
                   'Contact role is created successfully : x_responsibility_id= '
                || x_responsibility_id
                || ' Role type= '
                || p_role_responsibility_rec.responsibility_type);
        ELSE
            log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);

            IF x_msg_count > 0
            THEN
                FOR i IN 1 .. x_msg_count
                LOOP
                    x_msg_data   :=
                        SUBSTR (
                            fnd_msg_pub.get (p_encoded => fnd_api.g_false),
                            1,
                            255);
                    log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                    --          error_log(I||'. '||SubStr(FND_MSG_PUB.Get(p_encoded => FND_API.G_FALSE ), 1, 255));
                    xxd_common_utils.record_error (
                        p_module       => 'AR',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers AR Customer Conversion Program',
                        p_error_msg    => x_msg_data,
                        p_error_line   => DBMS_UTILITY.format_error_backtrace,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => 'create_role_contact',
                        p_more_info2   => gc_customer_name,
                        p_more_info3   => gc_cust_address,
                        p_more_info4   => gc_cust_contact);
                END LOOP;
            END IF;
        END IF;
    END create_role_contact;

    ------------------------------------
    -- 9. Create a contact using party_id you get in step 8 and cust_account_id from step 2
    ------------------------------------
    PROCEDURE create_cust_account_role (p_cr_cust_acc_role_rec hz_cust_account_role_v2pub.cust_account_role_rec_type, x_cust_account_role_id OUT NUMBER)
    AS
        --      x_cust_account_role_id   NUMBER;
        x_return_status   VARCHAR2 (2000);
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_cust_account_role';
        -- NOTE:
        -- must be unique CUST_ACCOUNT_ID, PARTY_ID,ROLE_TYPE
        -- must be unique CUST_ACCT_SITE_ID, PARTY_ID,ROLE_TYPE
        hz_cust_account_role_v2pub.create_cust_account_role (
            'T',
            p_cr_cust_acc_role_rec,
            x_cust_account_role_id,
            x_return_status,
            x_msg_count,
            x_msg_data);

        IF (x_return_status = 'S')
        THEN
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_cust_account_role_id: '
                || x_cust_account_role_id
                || CHR (10)
                || 'x_return_status: '
                || x_return_status
                || CHR (10)
                || 'x_msg_count: '
                || x_msg_count
                || CHR (10)
                || 'x_msg_data: '
                || x_msg_data
                || CHR (10)
                || '***************************');
        ELSE
            log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_cust_account_role',
                p_more_info2   => gc_customer_name,
                p_more_info3   => gc_cust_address,
                p_more_info4   => gc_cust_contact);

            FOR i IN 1 .. x_msg_count
            LOOP
                fnd_msg_pub.get (p_encoded         => fnd_api.g_false,
                                 p_data            => x_msg_data,
                                 p_msg_index_out   => x_msg_count);
                log_records (
                    gc_debug_flag,
                       '***************************'
                    || CHR (10)
                    || 'Output information ....'
                    || CHR (10)
                    || 'x_cust_account_role_id: '
                    || x_cust_account_role_id
                    || CHR (10)
                    || 'x_return_status: '
                    || x_return_status
                    || CHR (10)
                    || 'x_msg_count: '
                    || x_msg_count
                    || CHR (10)
                    || 'x_msg_data: '
                    || x_msg_data
                    || CHR (10)
                    || '***************************');
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                xxd_common_utils.record_error (
                    p_module       => 'AR',
                    p_org_id       => gn_org_id,
                    p_program      => 'Deckers AR Customer Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_cust_account_role',
                    p_more_info2   => gc_customer_name,
                    p_more_info3   => gc_cust_address,
                    p_more_info4   => gc_cust_contact);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Exception in create_cust_account_role ' || SQLERRM);
    END create_cust_account_role;

    -- 8. Create a relation cont-org using party_id from step 7 and party_id from step 2
    ------------------------------------


    PROCEDURE create_org_contact (p_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type, v_org_contact_id OUT NUMBER, v_rel_party_id OUT NUMBER
                                  , v_org_party_id OUT NUMBER)
    AS
        x_org_contact_id   NUMBER;
        x_party_rel_id     NUMBER;
        x_party_id         NUMBER;
        x_party_number     VARCHAR2 (2000);
        x_return_status    VARCHAR2 (2000);
        x_msg_count        NUMBER;
        x_msg_data         VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_org_contact';
        --p_org_contact_rec.department_code := 'ACCOUNTING';
        --p_org_contact_rec.job_title := 'ACCOUNTS OFFICER';
        --p_org_contact_rec.decision_maker_flag := 'Y';
        --p_org_contact_rec.job_title_code := 'APC';
        hz_party_contact_v2pub.create_org_contact ('T',
                                                   p_org_contact_rec,
                                                   x_org_contact_id,
                                                   x_party_rel_id,
                                                   x_party_id,
                                                   x_party_number,
                                                   x_return_status,
                                                   x_msg_count,
                                                   x_msg_data);

        IF (x_return_status = 'S')
        THEN
            v_rel_party_id     := x_party_rel_id;
            v_org_party_id     := x_party_id;
            v_org_contact_id   := x_org_contact_id;
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_org_contact_id: '
                || x_org_contact_id
                || CHR (10)
                || 'x_party_rel_id: '
                || x_party_rel_id
                || CHR (10)
                || 'x_party_id: '
                || x_party_id
                || CHR (10)
                || 'x_party_number: '
                || x_party_number
                || CHR (10)
                || 'x_return_status: '
                || x_return_status
                || CHR (10)
                || 'x_msg_count: '
                || x_msg_count
                || CHR (10)
                || 'x_msg_data: '
                || x_msg_data
                || CHR (10)
                || '***************************');
        ELSE
            log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);

            /* XXD_COMMON_UTILS.RECORD_ERROR(P_MODULE     => 'AR',
             P_ORG_ID     => GN_ORG_ID,
             P_PROGRAM    => 'Deckers AR Customer Conversion Program',
             P_ERROR_MSG  => X_MSG_DATA,
             P_ERROR_LINE => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
             P_CREATED_BY => GN_USER_ID,
             P_REQUEST_ID => GN_CONC_REQUEST_ID,
             P_MORE_INFO1 => 'create_org_contact',
             P_MORE_INFO2 => GC_CUSTOMER_NAME,
             P_MORE_INFO3 => NULL,
             P_MORE_INFO4 => NULL);
           */
            FOR i IN 1 .. x_msg_count
            LOOP
                fnd_msg_pub.get (p_encoded         => fnd_api.g_false,
                                 p_data            => x_msg_data,
                                 p_msg_index_out   => x_msg_count);
                log_records (
                    gc_debug_flag,
                       '***************************'
                    || CHR (10)
                    || 'Output information ....'
                    || CHR (10)
                    || 'x_org_contact_id: '
                    || x_org_contact_id
                    || CHR (10)
                    || 'x_party_rel_id: '
                    || x_party_rel_id
                    || CHR (10)
                    || 'x_party_id: '
                    || x_party_id
                    || CHR (10)
                    || 'x_party_number: '
                    || x_party_number
                    || CHR (10)
                    || 'x_return_status: '
                    || x_return_status
                    || CHR (10)
                    || 'x_msg_count: '
                    || x_msg_count
                    || CHR (10)
                    || 'x_msg_data: '
                    || x_msg_data
                    || CHR (10)
                    || '***************************');
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                xxd_common_utils.record_error (
                    p_module       => 'AR',
                    p_org_id       => gn_org_id,
                    p_program      => 'Deckers AR Customer Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_org_contact',
                    p_more_info2   => gc_customer_name,
                    p_more_info3   => gc_cust_address,
                    p_more_info4   => gc_cust_contact);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_org_contact ' || SQLERRM);
    END create_org_contact;

    PROCEDURE create_contact_point (
        p_contact_point_rec       hz_contact_point_v2pub.contact_point_rec_type,
        p_phone_rec               hz_contact_point_v2pub.phone_rec_type,
        p_edi_rec_type            hz_contact_point_v2pub.edi_rec_type,
        p_email_rec_type          hz_contact_point_v2pub.email_rec_type,
        p_telex_rec_type          hz_contact_point_v2pub.telex_rec_type,
        p_web_rec_type            hz_contact_point_v2pub.web_rec_type,
        x_return_status       OUT VARCHAR2,
        x_contact_point_id    OUT NUMBER)
    AS
        --    x_return_status    VARCHAR2(2000);
        x_msg_count   NUMBER;
        x_msg_data    VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_contact_point';
        hz_contact_point_v2pub.create_contact_point ('T',
                                                     p_contact_point_rec,
                                                     p_edi_rec_type,
                                                     p_email_rec_type,
                                                     p_phone_rec,
                                                     p_telex_rec_type,
                                                     p_web_rec_type,
                                                     x_contact_point_id,
                                                     x_return_status,
                                                     x_msg_count,
                                                     x_msg_data);

        IF (x_return_status = 'S')
        THEN
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_contact_point_id: '
                || x_contact_point_id
                || CHR (10)
                || 'x_return_status: '
                || x_return_status
                || CHR (10)
                || 'x_msg_count: '
                || x_msg_count
                || CHR (10)
                || 'x_msg_data: '
                || x_msg_data
                || CHR (10)
                || '***************************');
        ELSE
            log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_contact_point ' || gc_customer_name,
                p_more_info2   => gc_cust_address,
                p_more_info3   => gc_cust_contact,
                p_more_info4   => gc_cust_contact_point);

            FOR i IN 1 .. x_msg_count
            LOOP
                fnd_msg_pub.get (p_encoded         => fnd_api.g_false,
                                 p_data            => x_msg_data,
                                 p_msg_index_out   => x_msg_count);
                log_records (
                    gc_debug_flag,
                       '***************************'
                    || CHR (10)
                    || 'Output information ....'
                    || CHR (10)
                    || 'x_contact_point_id: '
                    || x_contact_point_id
                    || CHR (10)
                    || 'x_return_status: '
                    || x_return_status
                    || CHR (10)
                    || 'x_msg_count: '
                    || x_msg_count
                    || CHR (10)
                    || 'x_msg_data: '
                    || x_msg_data
                    || CHR (10)
                    || '***************************');
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                --      IF x_msg_data IS NOT NULL THEN
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                xxd_common_utils.record_error (
                    p_module       => 'AR',
                    p_org_id       => gn_org_id,
                    p_program      => 'Deckers AR Customer Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_contact_point ',
                    p_more_info2   => gc_customer_name,
                    p_more_info3   => gc_cust_address,
                    p_more_info4   => gc_cust_contact);
            --           END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_contact_point ' || SQLERRM);
    END create_contact_point;

    /* BEGIN contact to an organization */
    ------------------------------------
    -- 7. Create a definition contact
    ------------------------------------
    PROCEDURE create_person (p_create_person_rec hz_party_v2pub.person_rec_type, v_contact_party_id OUT NUMBER)
    AS
        x_party_id        NUMBER;
        x_party_number    VARCHAR2 (2000);
        x_profile_id      NUMBER;
        x_return_status   VARCHAR2 (2000);
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_person';
        hz_party_v2pub.create_person ('T', p_create_person_rec, x_party_id,
                                      x_party_number, x_profile_id, x_return_status
                                      , x_msg_count, x_msg_data);

        IF (x_return_status = 'S')
        THEN
            v_contact_party_id   := x_party_id;
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_party_id: '
                || x_party_id
                || CHR (10)
                || 'x_party_number: '
                || x_party_number
                || CHR (10)
                || 'x_profile_id: '
                || x_profile_id
                || CHR (10)
                || 'x_return_status: '
                || x_return_status
                || CHR (10)
                || 'x_msg_count: '
                || x_msg_count
                || CHR (10)
                || 'x_msg_data: '
                || x_msg_data
                || CHR (10)
                || '***************************');
        ELSE
            log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);

            /*XXD_COMMON_UTILS.RECORD_ERROR(P_MODULE     => 'AR',
            P_ORG_ID     => GN_ORG_ID,
            P_PROGRAM    => 'Deckers AR Customer Conversion Program',
            P_ERROR_MSG  => X_MSG_DATA,
            P_ERROR_LINE => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
            P_CREATED_BY => GN_USER_ID,
            P_REQUEST_ID => GN_CONC_REQUEST_ID,
            P_MORE_INFO1 => 'create_person',
            P_MORE_INFO2 => GC_CUSTOMER_NAME,
            P_MORE_INFO3 => NULL,
            P_MORE_INFO4 => NULL);*/

            FOR i IN 1 .. x_msg_count
            LOOP
                fnd_msg_pub.get (p_encoded         => fnd_api.g_false,
                                 p_data            => x_msg_data,
                                 p_msg_index_out   => x_msg_count);
                log_records (
                    gc_debug_flag,
                       '***************************'
                    || CHR (10)
                    || 'Output information ....'
                    || CHR (10)
                    || 'x_party_id: '
                    || x_party_id
                    || CHR (10)
                    || 'x_party_number: '
                    || x_party_number
                    || CHR (10)
                    || 'x_profile_id: '
                    || x_profile_id
                    || CHR (10)
                    || 'x_return_status: '
                    || x_return_status
                    || CHR (10)
                    || 'x_msg_count: '
                    || x_msg_count
                    || CHR (10)
                    || 'x_msg_data: '
                    || x_msg_data
                    || CHR (10)
                    || '***************************');
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                xxd_common_utils.record_error (
                    p_module       => 'AR',
                    p_org_id       => gn_org_id,
                    p_program      => 'Deckers AR Customer Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_person',
                    p_more_info2   => gc_customer_name,
                    p_more_info3   => gc_cust_address,
                    p_more_info4   => gc_cust_contact);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_person ' || SQLERRM);
    END create_person;

    --+------------------------------------------------------------------------------
    --| Name        : CREATE_CONTACTS_RECORDS
    --| Description : Customer Contacts Records
    --+------------------------------------------------------------------------------
    --+------------------------------------------------------------------------------
    --| Name        : CREATE_CONTACTS_RECORDS
    --| Description : Customer Contacts Records
    --+------------------------------------------------------------------------------
    PROCEDURE create_contacts_records (p_debug IN VARCHAR2, p_action IN VARCHAR2, p_batch_id IN VARCHAR2)
    --   (pn_customer_id        IN NUMBER,
    --                                      p_party_id            IN NUMBER,
    --                                      p_address_id          IN NUMBER,
    --                                      p_party_site_id       IN NUMBER,
    --                                      p_cust_account_id     IN NUMBER,
    --                                      p_cust_acct_site_id   IN NUMBER --                                     ,x_ret_code              OUT NUMBER
    --                                     ,x_err_msg               OUT VARCHAR
    --                                      )
    IS
        --gc_validate_status  VARCHAR2 (250);
        --Customer Contacts
        CURSOR lcu_cust_contact IS
            -- Customer Contacts
            SELECT hca.cust_account_id, hca.party_id, NVL (brand, hca.attribute1) brand,
                   record_type, acv.contact_attribute_category, acv.contact_first_name,
                   acv.contact_key, acv.contact_last_name, acv.contact_point_type,
                   acv.contact_title, acv.created_by, acv.creation_date,
                   acv.email_address, acv.insert_update_flag, acv.job_title,
                   acv.job_title_code, acv.last_update_date, acv.last_update_login,
                   acv.last_updated_by, acv.mail_stop, acv.org_id,
                   acv.orig_system_address_ref, NVL (acv.orig_system_contact_ref, contact_id) orig_system_contact_ref, acv.orig_system_customer_ref,
                   acv.orig_system_telephone_ref, acv.phone_country_code, acv.telephone,
                   acv.telephone_area_code, acv.telephone_extension, acv.telephone_type, --                validated_flag,
                   acv.contact_id, acv.party_number, NULL cust_acct_site_id,
                   NULL party_site_id, role
              FROM xxdo_ar_cust_contacts_stg_t acv, hz_cust_accounts_all hca, --                hz_cust_acct_sites_all hcas,
                                                                              hz_cust_acct_relate_all hcar,
                   hz_cust_accounts_all hca1
             WHERE     1 = 1
                   --AND acv.orig_system_address_ref IS NULL
                   AND acv.orig_system_customer_ref = related_cust_account_id
                   AND hca.cust_account_id = hcar.cust_account_id
                   AND hca1.cust_account_id = hcar.related_cust_account_id
                   AND hca.party_id = hca1.party_id
                   --          AND hca.CUST_ACCOUNT_ID = hcas.CUST_ACCOUNT_ID
                   AND (hca.attribute1 = brand OR brand IS NULL)
                   AND batch_number = p_batch_id
                   AND acv.record_status = gc_validate_status;

        /*  UNION
          -- Customer Addresses Contacts
          SELECT hca.cust_account_id
               ,  hca.party_id
               ,  brand
               ,  record_type
               ,  acv.contact_attribute_category
               ,  acv.contact_first_name
               ,  acv.contact_key
               ,  acv.contact_last_name
               ,  acv.contact_point_type
               ,  acv.contact_title
               ,  acv.created_by
               ,  acv.creation_date
               ,  acv.email_address
               ,  acv.insert_update_flag
               ,  acv.job_title
               ,  acv.job_title_code
               ,  acv.last_update_date
               ,  acv.last_update_login
               ,  acv.last_updated_by
               ,  acv.mail_stop
               ,  acv.org_id
               ,  acv.orig_system_address_ref
               ,  acv.orig_system_contact_ref
               ,  acv.orig_system_customer_ref
               ,  acv.orig_system_telephone_ref
               ,  acv.phone_country_code
               ,  acv.telephone
               ,  acv.telephone_area_code
               ,  acv.telephone_extension
               ,  acv.telephone_type
               ,                                                                           --                validated_flag,
                acv.contact_id
               ,  acv.party_number
               ,  cust_acct_site_id
               ,  party_site_id
               ,  role
            FROM xxdo_ar_cust_contacts_stg_t acv
               ,  hz_cust_accounts_all hca
               ,  hz_cust_acct_sites_all hcas
               ,  hz_cust_acct_relate_all hcar
           WHERE 1 = 1
             AND acv.orig_system_address_ref IS NOT NULL
             --                AND acv.orig_system_customer_ref = TO_CHAR (pn_customer_id) --Customer Id of the Customer
             AND acv.orig_system_customer_ref = related_cust_account_id
             AND hca.cust_account_id = hcar.cust_account_id
             AND hca.cust_account_id = hcas.cust_account_id
             AND hca.attribute1 = brand
             AND batch_number = p_batch_id
             AND acv.record_status = gc_validate_status;*/

        --                AND acv.record_status = gc_validate_status;

        -- Phones at customer and address level
        CURSOR lcu_cust_phones (pn_customer_id NUMBER, p_address_id NUMBER)
        IS
            -- Customer Phones
            SELECT record_type, contact_attribute_category, contact_first_name,
                   contact_key, contact_last_name, contact_point_type,
                   contact_title, created_by, creation_date,
                   email_address, insert_update_flag, last_update_date,
                   last_update_login, last_updated_by, mail_stop,
                   org_id, orig_system_address_ref, orig_system_contact_ref,
                   orig_system_customer_ref, orig_system_telephone_ref, phone_country_code,
                   telephone, telephone_area_code, telephone_extension,
                   telephone_type, contact_point_purpose, primary_by_purpose,
                   NULL url, email_format, brand
              FROM xxdo_ar_cust_contacts_stg_t apv
             WHERE     apv.orig_system_customer_ref =
                       TO_CHAR (pn_customer_id) --        AND      p_address_id                              IS NULL
                   AND apv.orig_system_address_ref IS NULL
                   AND apv.record_status = gc_validate_status
            UNION
            -- Customer Addresses Phones
            SELECT record_type, contact_attribute_category, contact_first_name,
                   contact_key, contact_last_name, contact_point_type,
                   contact_title, created_by, creation_date,
                   email_address, insert_update_flag, last_update_date,
                   last_update_login, last_updated_by, mail_stop,
                   org_id, orig_system_address_ref, orig_system_contact_ref,
                   orig_system_customer_ref, orig_system_telephone_ref, phone_country_code,
                   telephone, telephone_area_code, telephone_extension,
                   telephone_type, contact_point_purpose, primary_by_purpose,
                   NULL url, email_format, brand
              FROM xxdo_ar_cust_contacts_stg_t apv
             WHERE     apv.orig_system_address_ref = NVL (p_address_id, -1)
                   AND apv.orig_system_customer_ref =
                       TO_CHAR (pn_customer_id)
                   AND apv.record_status = gc_validate_status;

        -- Phones at customer contact and address contact level
        CURSOR lcu_cust_cont_phones (pn_customer_id NUMBER, p_address_id NUMBER, p_contact_id NUMBER
                                     , p_brand VARCHAR2)
        IS
            -- Customer Contacts Phones
            SELECT record_type, contact_attribute_category, contact_first_name,
                   contact_key, contact_last_name, contact_point_type,
                   contact_title, created_by, creation_date,
                   email_address, insert_update_flag, last_update_date,
                   last_update_login, last_updated_by, mail_stop,
                   org_id, orig_system_address_ref, NVL (orig_system_contact_ref, contact_id) orig_system_contact_ref,
                   orig_system_customer_ref, orig_system_telephone_ref, phone_country_code,
                   telephone, telephone_area_code, telephone_extension,
                   telephone_type, contact_point_purpose, primary_by_purpose,
                   NULL url, email_format
              FROM xxdo_ar_cust_contacts_stg_t apv
             WHERE     apv.orig_system_address_ref IS NULL
                   AND apv.orig_system_customer_ref = pn_customer_id
                   AND NVL (apv.orig_system_contact_ref, contact_id) =
                       NVL (p_contact_id, -1)
                   AND NVL (apv.brand, 'X') = NVL (p_brand, 'X')
            --        AND       p_address_id                             IS NULL
            --         AND record_status = gc_validate_status
            UNION
            -- Customer Addresses Contacts Phones
            SELECT record_type, contact_attribute_category, contact_first_name,
                   contact_key, contact_last_name, contact_point_type,
                   contact_title, created_by, creation_date,
                   email_address, insert_update_flag, last_update_date,
                   last_update_login, last_updated_by, mail_stop,
                   org_id, orig_system_address_ref, NVL (orig_system_contact_ref, contact_id) orig_system_contact_ref,
                   orig_system_customer_ref, orig_system_telephone_ref, phone_country_code,
                   telephone, telephone_area_code, telephone_extension,
                   telephone_type, contact_point_purpose, primary_by_purpose,
                   NULL url, email_format
              FROM xxdo_ar_cust_contacts_stg_t apv
             WHERE     apv.orig_system_address_ref IS NOT NULL
                   AND apv.orig_system_customer_ref = pn_customer_id
                   AND NVL (apv.orig_system_address_ref, -1) =
                       NVL (p_address_id, -1)
                   AND NVL (apv.orig_system_contact_ref, contact_id) =
                       NVL (p_contact_id, -1)
                   AND NVL (apv.brand, 'X') = NVL (p_brand, 'X')
            --         AND apv.record_status = gc_validate_status
            -- Contact for customers without brand information in data file
            UNION
            SELECT record_type, contact_attribute_category, contact_first_name,
                   contact_key, contact_last_name, contact_point_type,
                   contact_title, created_by, creation_date,
                   email_address, insert_update_flag, last_update_date,
                   last_update_login, last_updated_by, mail_stop,
                   org_id, orig_system_address_ref, NVL (orig_system_contact_ref, contact_id) orig_system_contact_ref,
                   orig_system_customer_ref, orig_system_telephone_ref, phone_country_code,
                   telephone, telephone_area_code, telephone_extension,
                   telephone_type, contact_point_purpose, primary_by_purpose,
                   NULL url, email_format
              FROM xxdo_ar_cust_contacts_stg_t apv
             WHERE     apv.orig_system_customer_ref = pn_customer_id
                   AND NVL (apv.orig_system_contact_ref, contact_id) =
                       NVL (p_contact_id, -1)
                   AND apv.brand IS NULL;

        -- Check if Contact already exists
        CURSOR lcu_check_contact (p_orig_system_ref IN VARCHAR2)
        IS
            SELECT hrel.subject_id, hoc.org_contact_id
              FROM hz_org_contacts hoc, hz_relationships hrel
             WHERE     hoc.party_relationship_id = hrel.relationship_id
                   AND hrel.subject_type = 'PERSON'
                   AND hoc.orig_system_reference = p_orig_system_ref;

        -- Deriving relationship id
        CURSOR lcu_rel_id (p_party_id NUMBER, p_person_id NUMBER)
        IS
            SELECT rel.party_id
              FROM hz_relationships rel
             WHERE     rel.object_id = p_party_id
                   AND rel.object_type = 'ORGANIZATION'
                   AND rel.subject_id = p_person_id
                   AND rel.subject_type = 'PERSON'
                   AND NVL (rel.end_date, SYSDATE + 1) > SYSDATE
                   AND rel.status = 'A';

        -- Deriving relationship party id
        CURSOR lcu_rel_party_id (p_org_contact_id NUMBER)
        IS
            SELECT hrel.party_id
              FROM hz_relationships hrel, hz_org_contacts hoc
             WHERE     hrel.relationship_id = hoc.party_relationship_id
                   AND hoc.org_contact_id = p_org_contact_id
                   AND object_type = 'PERSON';

        --cursor to get responsibility type from R12
        CURSOR lcu_role_resp_type (p_responsibility_type VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values_vl
             WHERE     1 = 1
                   AND lookup_type = 'SITE_USE_CODE'
                   AND enabled_flag = 'Y'
                   AND UPPER (meaning) = UPPER (TRIM (p_responsibility_type));

        ln_role_resp_type           VARCHAR2 (1000);

        -- Cursor to fetch contact title from R12
        CURSOR lcu_get_contact_title (p_title VARCHAR2)
        IS
            SELECT flv.lookup_code title
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'CONTACT_TITLE'
                   AND flv.enabled_flag = 'Y'
                   AND UPPER (flv.meaning) = UPPER (p_title);

        lc_title                    VARCHAR2 (100);

        --cursor to get job title code type from R12
        CURSOR lcu_job_title_code (p_job_title_code VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'RESPONSIBILITY'
                   AND enabled_flag = 'Y'
                   AND UPPER (lookup_code) = UPPER (p_job_title_code);

        lc_job_title_code           VARCHAR2 (1000);

        --Cusrsor to Check contact point already
        CURSOR lcu_contact_point_val (p_contact_point_id VARCHAR2, p_owner_table_name VARCHAR2, p_owner_table_id NUMBER)
        IS
            SELECT contact_point_id
              FROM hz_contact_points
             WHERE     1 = 1
                   AND orig_system_reference = p_contact_point_id
                   AND owner_table_name = p_owner_table_name
                   AND owner_table_id = p_owner_table_id;

        CURSOR lcu_party_type (p_r12_party_id NUMBER)
        IS
            SELECT party_type
              FROM hz_parties
             WHERE party_id = p_r12_party_id;

        ln_contact_party_id         NUMBER := 0;
        ln_cont_point_id            NUMBER;
        ln_subject_id               NUMBER;
        ln_org_contact_id           NUMBER;
        ln_rel_party_id             NUMBER;
        lc_party_type               VARCHAR2 (250);
        ln_org_party_id             NUMBER;
        lx_contact_point_id         NUMBER;
        lx_msg                      VARCHAR2 (2000);
        lx_return_status            VARCHAR2 (10);
        pn_customer_id              NUMBER;
        p_party_id                  NUMBER;
        p_address_id                NUMBER;
        p_cust_acct_site_id         NUMBER;
        p_party_site_id             NUMBER;
        lx_cust_account_role_id     NUMBER;
        lc_dun_flag                 VARCHAR2 (3);
        ln_role_cnt                 NUMBER := 0;

        lc_person_rec               hz_party_v2pub.person_rec_type;
        lc_org_contact_rec          hz_party_contact_v2pub.org_contact_rec_type;
        lc_cust_acct_role_rec       hz_cust_account_role_v2pub.cust_account_role_rec_type;
        lc_contactpt                hz_contact_point_v2pub.contact_point_rec_type;
        lc_phone_rec                hz_contact_point_v2pub.phone_rec_type;
        lc_email_rec                hz_contact_point_v2pub.email_rec_type;
        lc_web_rec                  hz_contact_point_v2pub.web_rec_type;
        l_role_responsibility_rec   hz_cust_account_role_v2pub.role_responsibility_rec_type;

        l_tab                       DBMS_UTILITY.uncl_array;
        l_tablen                    NUMBER;
    BEGIN
        FOR lrec_cust_contact IN lcu_cust_contact --(pn_customer_id, p_address_id)
        LOOP
            ln_subject_id         := NULL;
            ln_org_contact_id     := NULL;
            --         lc_cust_cont_role_rec := NULL;
            pn_customer_id        := lrec_cust_contact.orig_system_customer_ref;
            p_party_id            := lrec_cust_contact.party_id;
            p_address_id          := lrec_cust_contact.orig_system_address_ref;
            p_cust_acct_site_id   := lrec_cust_contact.cust_acct_site_id;
            p_party_site_id       := lrec_cust_contact.party_site_id;

            gc_customer_name      := lrec_cust_contact.contact_first_name;
            gc_cust_address       := lrec_cust_contact.contact_last_name;
            gc_cust_contact       :=
                lrec_cust_contact.orig_system_contact_ref;

            log_records (p_debug     => gc_debug_flag,
                         p_message   => 'create_contacts_records ');
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => pn_customer_id || ' <=pn_customer_id ');
            log_records (p_debug     => gc_debug_flag,
                         p_message   => p_address_id || ' <=p_address_id ');


            gc_cust_contact       :=
                   INITCAP (lrec_cust_contact.contact_first_name)
                || ' '
                || INITCAP (lrec_cust_contact.contact_last_name);
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    '   -- Creating lcu_cust_contact(pn_customer_id,p_address_id) ');
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       '   --  lrec_cust_contact.orig_system_contact_ref  =>'
                    || lrec_cust_contact.orig_system_contact_ref);
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       ' lrec_cust_contact name => '
                    || INITCAP (lrec_cust_contact.contact_first_name)
                    || ' '
                    || INITCAP (lrec_cust_contact.contact_last_name));

            OPEN lcu_check_contact (
                   lrec_cust_contact.orig_system_contact_ref
                || '-'
                || lrec_cust_contact.brand);

            FETCH lcu_check_contact INTO ln_subject_id, ln_org_contact_id;

            CLOSE lcu_check_contact;

            log_records (p_debug     => gc_debug_flag,
                         p_message   => ' ln_subject_id => ' || ln_subject_id);
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => ' ln_org_contact_id => ' || ln_org_contact_id);

            IF ln_subject_id IS NULL
            THEN
                lc_person_rec                                         := NULL;
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' lrec_cust_contact.contact_first_name => '
                        || lrec_cust_contact.contact_first_name);
                lc_person_rec.person_first_name                       :=
                    INITCAP (lrec_cust_contact.contact_first_name);
                lc_person_rec.person_last_name                        :=
                    INITCAP (lrec_cust_contact.contact_last_name);
                lc_person_rec.person_pre_name_adjunct                 :=
                    lrec_cust_contact.contact_title;

                lc_person_rec.created_by_module                       := 'TCA_V1_API';
                --                    lc_person_rec.party_rec.party_number  :=  lrec_cust_contact.PARTY_NUMBER ; --orig_system_contact_ref;  ---party_number
                log_records (p_debug     => gc_debug_flag,
                             p_message   => ' Calling create_person => ');
                create_person (p_create_person_rec   => lc_person_rec,
                               v_contact_party_id    => ln_contact_party_id);
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' Calling v_contact_party_id  => '
                        || ln_contact_party_id);
                --                END IF; -- Creatre person

                --                IF ln_subject_id IS NOT NULL THEN -- Create org contact
                lc_party_type                                         := NULL;
                lc_org_contact_rec                                    := NULL;

                OPEN lcu_party_type (p_party_id);

                FETCH lcu_party_type INTO lc_party_type;

                CLOSE lcu_party_type;

                --lc_org_contact_rec.title                          := lrec_cust_contact.contact_title;
                lc_org_contact_rec.created_by_module                  := 'TCA_V1_API';
                lc_org_contact_rec.party_rel_rec.subject_id           :=
                    ln_contact_party_id;
                lc_org_contact_rec.party_rel_rec.subject_type         := 'PERSON';
                lc_org_contact_rec.party_rel_rec.subject_table_name   :=
                    'HZ_PARTIES';

                lc_org_contact_rec.party_rel_rec.object_id            :=
                    p_party_id;
                lc_org_contact_rec.party_rel_rec.object_type          :=
                    lc_party_type;
                lc_org_contact_rec.party_rel_rec.object_table_name    :=
                    'HZ_PARTIES';

                lc_org_contact_rec.party_rel_rec.relationship_code    :=
                    'CONTACT_OF';
                lc_org_contact_rec.party_rel_rec.relationship_type    :=
                    'CONTACT';
                lc_org_contact_rec.party_rel_rec.start_date           :=
                    SYSDATE;
                lc_org_contact_rec.orig_system_reference              :=
                       lrec_cust_contact.orig_system_contact_ref
                    || '-'
                    || lrec_cust_contact.brand;
                lc_org_contact_rec.attribute_category                 :=
                    lrec_cust_contact.contact_attribute_category;
                lc_org_contact_rec.job_title_code                     :=
                    lc_job_title_code;
                lc_org_contact_rec.job_title                          :=
                    lrec_cust_contact.job_title;
                lc_org_contact_rec.party_site_id                      :=
                    p_party_site_id;

                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' Calling create_org_contact  => '
                        || p_party_id
                        || ' lc_party_type => '
                        || lc_party_type);
                create_org_contact (p_org_contact_rec => lc_org_contact_rec, v_org_contact_id => ln_org_contact_id, v_rel_party_id => ln_rel_party_id
                                    , v_org_party_id => ln_org_party_id);

                lc_cust_acct_role_rec                                 := NULL;
                lc_cust_acct_role_rec.party_id                        :=
                    ln_org_party_id;
                lc_cust_acct_role_rec.cust_account_id                 :=
                    lrec_cust_contact.cust_account_id;    --p_cust_account_id;
                lc_cust_acct_role_rec.cust_acct_site_id               :=
                    p_cust_acct_site_id;
                lc_cust_acct_role_rec.role_type                       :=
                    'CONTACT';
                lc_cust_acct_role_rec.status                          := 'A';
                lc_cust_acct_role_rec.created_by_module               :=
                    'TCA_V1_API';
                create_cust_account_role (
                    p_cr_cust_acc_role_rec   => lc_cust_acct_role_rec,
                    x_cust_account_role_id   => lx_cust_account_role_id);

                BEGIN
                    --         dbms_utility.comma_to_table(lrec_cust_contact.role, l_tablen, l_tab);
                    lc_dun_flag     := 'N';
                    ln_role_cnt     := 0;

                    FOR contact
                        IN (    SELECT REGEXP_SUBSTR (lrec_cust_contact.role, '[^;/]+', 1
                                                      , LEVEL) role
                                  FROM DUAL
                            CONNECT BY LEVEL <=
                                         REGEXP_COUNT (
                                             lrec_cust_contact.role,
                                             '[;/]')
                                       + 1)
                    LOOP
                        IF contact.role IS NOT NULL
                        THEN
                            log_records (p_debug     => gc_debug_flag,
                                         p_message   => contact.role);
                            l_role_responsibility_rec   := NULL;
                            l_role_responsibility_rec.cust_account_role_id   :=
                                lx_cust_account_role_id;

                            OPEN lcu_role_resp_type (contact.role);

                            FETCH lcu_role_resp_type
                                INTO l_role_responsibility_rec.responsibility_type;

                            CLOSE lcu_role_resp_type;

                            l_role_responsibility_rec.created_by_module   :=
                                'TCA_V1_API';

                            IF l_role_responsibility_rec.responsibility_type =
                               'DUN'
                            THEN
                                lc_dun_flag   := 'Y';
                            END IF;

                            create_role_contact (
                                p_role_responsibility_rec   =>
                                    l_role_responsibility_rec);
                            ln_role_cnt                 :=
                                ln_role_cnt + 1;
                        END IF;
                    END LOOP;

                    IF lc_dun_flag = 'N' AND ln_role_cnt > 0
                    THEN
                        l_role_responsibility_rec   := NULL;
                        l_role_responsibility_rec.cust_account_role_id   :=
                            lx_cust_account_role_id;
                        l_role_responsibility_rec.responsibility_type   :=
                            'DUN';                             --contact.role;

                        l_role_responsibility_rec.created_by_module   :=
                            'TCA_V1_API';
                        create_role_contact (
                            p_role_responsibility_rec   =>
                                l_role_responsibility_rec);
                    END IF;

                    IF ln_role_cnt = 0
                    THEN
                        FOR role
                            IN (SELECT lookup_code, meaning
                                  FROM fnd_lookup_values_vl
                                 WHERE     1 = 1
                                       AND lookup_type = 'SITE_USE_CODE'
                                       AND enabled_flag = 'Y')
                        LOOP
                            l_role_responsibility_rec   := NULL;
                            l_role_responsibility_rec.cust_account_role_id   :=
                                lx_cust_account_role_id;
                            l_role_responsibility_rec.responsibility_type   :=
                                role.lookup_code;              --contact.role;

                            l_role_responsibility_rec.created_by_module   :=
                                'TCA_V1_API';
                            create_role_contact (
                                p_role_responsibility_rec   =>
                                    l_role_responsibility_rec);
                        END LOOP;
                    END IF;

                    ln_subject_id   := ln_contact_party_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        NULL;
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;

            log_records (p_debug     => gc_debug_flag,
                         p_message   => ' Calling lcu_cust_cont_phones');

            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       '   -- Creating customer and address contact phones 1.11 '
                    || p_party_site_id);
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       '   -- Creating customer and address contact phones 1.11 pn_customer_id '
                    || pn_customer_id);
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       '   -- Creating customer and address contact phones 1.11 p_address_id '
                    || p_address_id);
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       '   -- Creating customer and address contact phones 1.11 lrec_cust_contact.orig_system_contact_ref '
                    || lrec_cust_contact.orig_system_contact_ref);


            -- Creating customer and address contact phones
            FOR lrec_cust_cont_phones
                IN lcu_cust_cont_phones (pn_customer_id, p_address_id, NVL (lrec_cust_contact.orig_system_contact_ref, lrec_cust_contact.contact_id)
                                         , lrec_cust_contact.brand)
            LOOP
                log_records (p_debug     => gc_debug_flag,
                             p_message   => ' open lcu_cust_cont_phones');
                ln_rel_party_id                 := NULL;
                lc_contactpt                    := NULL;
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' open lcu_cust_cont_phones p_party_site_id => '
                        || p_party_site_id);

                IF p_party_site_id IS NULL
                THEN
                    -- Deriving relationship id
                    OPEN lcu_rel_id (p_party_id--,  ln_contact_party_id
                                               , ln_subject_id);

                    FETCH lcu_rel_id INTO ln_rel_party_id;

                    CLOSE lcu_rel_id;
                ELSE
                    -- Deriving relationship party id
                    OPEN lcu_rel_party_id (ln_org_contact_id);

                    FETCH lcu_rel_party_id INTO ln_rel_party_id;

                    CLOSE lcu_rel_party_id;
                END IF;

                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' open lcu_cust_cont_phones ln_rel_party_id => '
                        || ln_rel_party_id);
                lc_contactpt.owner_table_name   := 'HZ_PARTIES';
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' Calling  lrec_cust_cont_phones.orig_system_telephone_ref => '
                        || lrec_cust_cont_phones.orig_system_telephone_ref);

                --to check cotact point already exists for contact person
                IF lrec_cust_cont_phones.orig_system_telephone_ref
                       IS NOT NULL
                THEN
                    ln_cont_point_id      := NULL;

                    OPEN lcu_contact_point_val (
                           lrec_cust_cont_phones.orig_system_telephone_ref
                        || '-'
                        || lrec_cust_contact.brand,
                        lc_contactpt.owner_table_name,
                        ln_rel_party_id);

                    FETCH lcu_contact_point_val INTO ln_cont_point_id;

                    CLOSE lcu_contact_point_val;

                    lx_contact_point_id   := ln_cont_point_id;

                    IF     ln_cont_point_id IS NULL
                       AND ln_rel_party_id IS NOT NULL
                    THEN
                        lc_contactpt.owner_table_id          := ln_rel_party_id;
                        lc_contactpt.owner_table_name        := 'HZ_PARTIES';
                        lc_contactpt.created_by_module       := 'TCA_V1_API';
                        lc_contactpt.contact_point_type      :=
                            lrec_cust_cont_phones.contact_point_type;
                        lc_contactpt.primary_by_purpose      :=
                            lrec_cust_cont_phones.primary_by_purpose;
                        lc_contactpt.contact_point_purpose   :=
                            lrec_cust_cont_phones.contact_point_purpose;
                        lc_email_rec.email_format            :=
                            lrec_cust_cont_phones.email_format;
                        lc_email_rec.email_address           :=
                            lrec_cust_cont_phones.email_address;
                        lc_phone_rec.phone_number            :=
                            lrec_cust_cont_phones.telephone;
                        lc_phone_rec.phone_line_type         :=
                            lrec_cust_cont_phones.telephone_type;
                        lc_contactpt.status                  := 'A';
                        lc_phone_rec.phone_area_code         :=
                            lrec_cust_cont_phones.telephone_area_code;
                        lc_phone_rec.phone_country_code      :=
                            lrec_cust_cont_phones.phone_country_code;
                        lc_phone_rec.phone_extension         :=
                            lrec_cust_cont_phones.telephone_extension;

                        IF lrec_cust_cont_phones.url IS NOT NULL
                        THEN
                            lc_web_rec.web_type   := 'HTTP';
                            lc_web_rec.url        :=
                                lrec_cust_cont_phones.url;
                        ELSE
                            lc_web_rec.web_type   := NULL;
                            lc_web_rec.url        := NULL;
                        END IF;

                        gc_cust_contact_point                :=
                            lrec_cust_cont_phones.contact_point_type;
                        --
                        lc_contactpt.orig_system_reference   :=
                               lrec_cust_cont_phones.orig_system_telephone_ref
                            || '-'
                            || lrec_cust_contact.brand;
                        log_records (
                            p_debug     => gc_debug_flag,
                            p_message   => ' Calling  create_contact_point ');
                        lx_return_status                     := 'S';
                        lx_contact_point_id                  := NULL;
                        -- Calling API for creating Email Contact points
                        create_contact_point (
                            p_contact_point_rec   => lc_contactpt,
                            p_phone_rec           => lc_phone_rec,
                            p_edi_rec_type        => NULL,
                            p_email_rec_type      => lc_email_rec,
                            p_telex_rec_type      => NULL,
                            p_web_rec_type        => lc_web_rec,
                            x_return_status       => lx_return_status,
                            x_contact_point_id    => lx_contact_point_id);
                    END IF;
                END IF;

                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' Calling  lx_contact_point_id =>  '
                        || lx_contact_point_id);

                IF     NVL (lx_contact_point_id, 0) > 0
                   AND lx_return_status = 'S'
                THEN
                    log_records (
                        p_debug     => gc_debug_flag,
                        p_message   => ' upadte  XXDO_AR_CUST_CONTACTS_STG_T');
                /*UPDATE xxdo_ar_cust_contacts_stg_t
                   SET record_status   = gc_process_status
                 WHERE NVL ( orig_system_address_ref, -1 ) = NVL ( p_address_id, -1 )
                   AND orig_system_customer_ref = pn_customer_id
                   AND orig_system_telephone_ref = TO_NUMBER ( lrec_cust_cont_phones.orig_system_telephone_ref );*/
                ELSE
                    log_records (
                        p_debug     => gc_debug_flag,
                        p_message   => 'Update XXDO_AR_CUST_CONTACTS_STG_T 2');
                /*UPDATE xxdo_ar_cust_contacts_stg_t
                   SET record_status   = gc_error_status
                 WHERE NVL ( orig_system_address_ref, -1 ) = NVL ( p_address_id, -1 )
                   AND orig_system_customer_ref = pn_customer_id
                   AND orig_system_telephone_ref = TO_NUMBER ( lrec_cust_cont_phones.orig_system_telephone_ref );*/
                END IF;
            END LOOP;

            log_records (
                p_debug     => gc_debug_flag,
                p_message   => '   -- Creating customer and address phones 1 ');

            IF NVL (ln_subject_id, 0) > 0 AND NVL (ln_org_contact_id, 0) > 0
            THEN
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Update xxdo_ar_cust_contacts_stg_t 1 ***'
                        || lrec_cust_contact.orig_system_customer_ref
                        || '*******');
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Update xxdo_ar_cust_contacts_stg_t 1 ***'
                        || lrec_cust_contact.orig_system_address_ref
                        || '*******');
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Update xxdo_ar_cust_contacts_stg_t 1 ***'
                        || lrec_cust_contact.orig_system_contact_ref
                        || '*******');

                UPDATE xxdo_ar_cust_contacts_stg_t
                   SET record_status   = gc_process_status
                 WHERE     orig_system_customer_ref =
                           lrec_cust_contact.orig_system_customer_ref
                       AND NVL (brand, 'X') =
                           NVL (lrec_cust_contact.brand, 'X')
                       AND NVL (orig_system_address_ref, -1) =
                           NVL (lrec_cust_contact.orig_system_address_ref,
                                -1)
                       AND NVL (orig_system_telephone_ref, -1) =
                           NVL (lrec_cust_contact.orig_system_telephone_ref,
                                -1)
                       AND NVL (orig_system_contact_ref, contact_id) =
                           NVL (lrec_cust_contact.orig_system_contact_ref,
                                -1);

                log_records (
                    p_debug     => gc_debug_flag,
                    p_message   => SQL%ROWCOUNT || ' records updated');
            ELSE
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Update xxdo_ar_cust_contacts_stg_t 2 ***'
                        || lrec_cust_contact.orig_system_customer_ref
                        || '*******');
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Update xxdo_ar_cust_contacts_stg_t 2 ***'
                        || lrec_cust_contact.orig_system_address_ref
                        || '*******');
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Update xxdo_ar_cust_contacts_stg_t 2 ***'
                        || lrec_cust_contact.orig_system_contact_ref
                        || '*******');

                UPDATE xxdo_ar_cust_contacts_stg_t
                   SET record_status   = gc_error_status
                 WHERE     orig_system_customer_ref =
                           lrec_cust_contact.orig_system_customer_ref
                       AND NVL (brand, 'X') =
                           NVL (lrec_cust_contact.brand, 'X')
                       AND NVL (orig_system_address_ref, -1) =
                           NVL (lrec_cust_contact.orig_system_address_ref,
                                -1)
                       AND NVL (orig_system_telephone_ref, -1) =
                           NVL (lrec_cust_contact.orig_system_telephone_ref,
                                -1)
                       AND NVL (orig_system_contact_ref, contact_id) =
                           NVL (lrec_cust_contact.orig_system_contact_ref,
                                -1);

                log_records (
                    p_debug     => gc_debug_flag,
                    p_message   => SQL%ROWCOUNT || ' records updated');
            END IF;

            COMMIT;
        END LOOP;

        COMMIT;                                            -- Customer Contact

        -- Creating customer and address phones
        log_records (
            p_debug   => gc_debug_flag,
            p_message   =>
                   '   -- Creating customer and address phones  2'
                || p_party_site_id);

        FOR lrec_cust_phones
            IN lcu_cust_phones (pn_customer_id, p_address_id)
        LOOP
            BEGIN
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'create_contact_point p_party_site_id  '
                        || p_party_site_id);
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                        'create_contact_point p_party_id  ' || p_party_id);
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                        'create_contact_point p_address_id  ' || p_address_id);

                IF p_address_id IS NOT NULL
                THEN
                    lc_contactpt.owner_table_name   := 'HZ_PARTY_SITES';
                    lc_contactpt.owner_table_id     := p_party_site_id;
                ELSE
                    lc_contactpt.owner_table_name   := 'HZ_PARTIES';
                    lc_contactpt.owner_table_id     := p_party_id;
                END IF;

                --to check cotact point already exists for contact person
                IF lrec_cust_phones.orig_system_telephone_ref IS NOT NULL
                THEN
                    ln_cont_point_id   := NULL;

                    OPEN lcu_contact_point_val (
                           lrec_cust_phones.orig_system_telephone_ref
                        || '-'
                        || lrec_cust_phones.brand,
                        lc_contactpt.owner_table_name,
                        lc_contactpt.owner_table_id);

                    FETCH lcu_contact_point_val INTO ln_cont_point_id;

                    CLOSE lcu_contact_point_val;

                    log_records (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               'create_contact_point ln_cont_point_id  is null create new'
                            || ln_cont_point_id);

                    IF ln_cont_point_id IS NULL
                    THEN
                        lc_contactpt.created_by_module       := 'TCA_V1_API';
                        lc_contactpt.contact_point_type      :=
                            lrec_cust_phones.contact_point_type;
                        lc_contactpt.primary_by_purpose      :=
                            lrec_cust_phones.primary_by_purpose;
                        lc_contactpt.contact_point_purpose   :=
                            lrec_cust_phones.contact_point_purpose;
                        lc_email_rec.email_format            :=
                            lrec_cust_phones.email_format;
                        lc_email_rec.email_address           :=
                            lrec_cust_phones.email_address;
                        lc_phone_rec.phone_number            :=
                            lrec_cust_phones.telephone;
                        lc_phone_rec.phone_line_type         :=
                            lrec_cust_phones.telephone_type;
                        lc_contactpt.status                  := 'A';
                        lc_phone_rec.phone_area_code         :=
                            lrec_cust_phones.telephone_area_code;
                        lc_phone_rec.phone_country_code      :=
                            lrec_cust_phones.phone_country_code;
                        lc_phone_rec.phone_extension         :=
                            lrec_cust_phones.telephone_extension;

                        IF lrec_cust_phones.url IS NOT NULL
                        THEN
                            lc_web_rec.web_type   := 'HTTP';
                            lc_web_rec.url        := lrec_cust_phones.url;
                        ELSE
                            lc_web_rec.web_type   := NULL;
                            lc_web_rec.url        := NULL;
                        END IF;

                        --
                        lc_contactpt.orig_system_reference   :=
                               lrec_cust_phones.orig_system_telephone_ref
                            || '-'
                            || lrec_cust_phones.brand;

                        -- Calling API for creating Email Contact points
                        gc_cust_contact_point                :=
                            lrec_cust_phones.contact_point_type;
                        lx_return_status                     := 'S';
                        create_contact_point (
                            p_contact_point_rec   => lc_contactpt,
                            p_phone_rec           => lc_phone_rec,
                            p_edi_rec_type        => NULL,
                            p_email_rec_type      => lc_email_rec,
                            p_telex_rec_type      => NULL,
                            p_web_rec_type        => lc_web_rec,
                            x_return_status       => lx_return_status,
                            x_contact_point_id    => lx_contact_point_id);
                    END IF;

                    IF     NVL (lx_contact_point_id, 0) > 0
                       AND lx_return_status = 'S'
                    THEN
                        log_records (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                'Update XXDO_AR_CUST_CONTACTS_STG_T 3');

                        UPDATE xxdo_ar_cust_contacts_stg_t
                           SET record_status   = gc_process_status
                         WHERE     orig_system_customer_ref =
                                   lrec_cust_phones.orig_system_customer_ref
                               AND NVL (brand, 'X') =
                                   NVL (lrec_cust_phones.brand, 'X')
                               AND NVL (orig_system_address_ref, -1) =
                                   NVL (
                                       lrec_cust_phones.orig_system_address_ref,
                                       -1)
                               AND NVL (orig_system_telephone_ref, -1) =
                                   NVL (
                                       lrec_cust_phones.orig_system_telephone_ref,
                                       -1)
                               AND NVL (orig_system_contact_ref, contact_id) =
                                   NVL (
                                       lrec_cust_phones.orig_system_contact_ref,
                                       -1);
                    ELSE
                        log_records (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                'Update XXDO_AR_CUST_CONTACTS_STG_T 4');

                        UPDATE xxdo_ar_cust_contacts_stg_t
                           SET record_status   = gc_error_status
                         WHERE     orig_system_customer_ref =
                                   lrec_cust_phones.orig_system_customer_ref
                               AND NVL (brand, 'X') =
                                   NVL (lrec_cust_phones.brand, 'X')
                               AND NVL (orig_system_address_ref, -1) =
                                   NVL (
                                       lrec_cust_phones.orig_system_address_ref,
                                       -1)
                               AND NVL (orig_system_telephone_ref, -1) =
                                   NVL (
                                       lrec_cust_phones.orig_system_telephone_ref,
                                       -1)
                               AND NVL (orig_system_contact_ref, contact_id) =
                                   NVL (
                                       lrec_cust_phones.orig_system_contact_ref,
                                       -1);
                    END IF;
                END IF;
            /*         IF   ln_subject_id >0 AND  ln_org_contact_id > 0 THEN
                     log_records (p_debug => gc_debug_flag, p_message => 'Update xxdo_ar_cust_contacts_stg_t 1 ***'||lrec_cust_contact.orig_system_contact_ref || '*******');
                      log_records (p_debug => gc_debug_flag, p_message => 'Update xxdo_ar_cust_contacts_stg_t 1 ***'||p_address_id || '*******');

                                 UPDATE xxdo_ar_cust_contacts_stg_t SET
                                          RECORD_STATUS = gc_process_status
                           WHERE  orig_system_customer_ref  =   pn_customer_id
                                 AND   nvl(orig_system_address_ref ,-1)   =   nvl(p_address_id,-1)
                                 AND   orig_system_contact_ref    = to_number(lrec_cust_contact.orig_system_contact_ref) ;

                                 ELSE
                                  log_records (p_debug => gc_debug_flag, p_message => 'Update xxdo_ar_cust_contacts_stg_t 2');
                              UPDATE xxdo_ar_cust_contacts_stg_t SET
                                              RECORD_STATUS = gc_error_status
                           WHERE  orig_system_customer_ref  =   pn_customer_id
                                  AND   nvl(orig_system_address_ref ,-1)   =   nvl(p_address_id,-1)
                                 AND   orig_system_contact_ref    = lrec_cust_contact.orig_system_contact_ref ;
                          END IF;    */
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        gc_debug_flag,
                           ' Unexpected error: '
                        || SQLERRM
                        || ' While processing Contact for Customer Id: '
                        || pn_customer_id);
            --x_ret_code := 1;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                gc_debug_flag,
                   ' Unexpected error: '
                || SQLERRM
                || ' in procedure create_contacts_records');
    --x_ret_code := 1;
    END create_contacts_records;

    /*****************************************************************************************
    *  Procedure Name :   VALIDATE_CONTACT_POINTS                                            *
    *                                                                                        *
    *  Description    :   This Procedure shall validates the customer tables                 *
    *                                                                                        *
    *                                                                                        *
    *                                                                                        *
    *  Called From    :   Concurrent Program                                                 *
    *                                                                                        *
    *  Parameters             Type       Description                                         *
    *  -----------------------------------------------------------------------------         *
    *  p_debug                  IN       Debug Y/N                                           *
    *  p_action                 IN       Action (VALIDATE OR PROCESSED)                      *
    *  p_customer_id    IN       Header Stage table ref orig_sys_header_ref                  *
    *                                                                                        *
    * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                    *
    *                                                                                        *
     *****************************************************************************************/
    --  PROCEDURE VALIDATE_CONTACT_POINTS(P_DEBUG    IN VARCHAR2 DEFAULT GC_NO_FLAG,
    --                                    P_ACTION   IN VARCHAR2,
    --                                    P_BATCH_ID IN NUMBER) AS
    --    PRAGMA AUTONOMOUS_TRANSACTION;
    --
    --    CURSOR CUR_CONTACTS(P_ACTION VARCHAR2) IS
    --      SELECT /*+ FIRST_ROWS(10) */
    --       *
    --        FROM XXDO_AR_CUST_CONT_POINT_STG_T XCP
    --       WHERE RECORD_STATUS IN (GC_NEW_STATUS, GC_ERROR_STATUS);
    --
    --    TYPE LT_CONTACTS_TYP IS TABLE OF CUR_CONTACTS%ROWTYPE INDEX BY BINARY_INTEGER;
    --
    --    LT_CONTACTS_DATA LT_CONTACTS_TYP;
    --
    --    LC_CONTACTS_VALID_DATA VARCHAR2(1) := GC_YES_FLAG;
    --    LX_CONTACTS_VALID_DATA VARCHAR2(1) := GC_YES_FLAG;
    --    LN_COUNT               NUMBER := 0;
    --  BEGIN
    --
    --    OPEN CUR_CONTACTS(P_ACTION => P_ACTION);
    --
    --    LOOP
    --      FETCH CUR_CONTACTS BULK COLLECT
    --        INTO LT_CONTACTS_DATA LIMIT 1000;
    --
    --      IF LT_CONTACTS_DATA.COUNT > 0 THEN
    --        FOR XC_CONTACTS_IDX IN LT_CONTACTS_DATA.FIRST .. LT_CONTACTS_DATA.LAST LOOP
    --          --log_records (p_debug,'Start validation for Site Address' || lt_cust_site_use_data (xc_site_use_idx).ADDRESS1);
    --
    --          LC_CONTACTS_VALID_DATA := GC_YES_FLAG;
    --          GC_CUST_CONTACT_POINT  := LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --                                    .TELEPHONE_TYPE;
    --
    --          IF LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --           .ORIG_SYSTEM_CONTACT_REF IS NOT NULL THEN
    --            IF (LT_CONTACTS_DATA(XC_CONTACTS_IDX).CONTACT_FIRST_NAME IS NULL AND LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --               .CONTACT_LAST_NAME IS NULL) THEN
    --              NULL;
    --              /*XXD_COMMON_UTILS.RECORD_ERROR(P_MODULE     => 'AR',
    --              P_ORG_ID     => GN_ORG_ID,
    --              P_PROGRAM    => 'Deckers AR Customer Conversion Program',
    --              P_ERROR_MSG  => 'Exception Raised in CONTACT_FIRST_NAME and CONTACT_LAST_NAME are null  validation',
    --              P_ERROR_LINE => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
    --              P_CREATED_BY => GN_USER_ID,
    --              P_REQUEST_ID => GN_CONC_REQUEST_ID,
    --              P_MORE_INFO1 => 'CONTACT_FIRST_NAME',
    --              P_MORE_INFO2 => 'CONTACT_LAST_NAME',
    --              P_MORE_INFO3 => GC_CUSTOMER_NAME,
    --              P_MORE_INFO4 => GC_CUST_ADDRESS);*/
    --            END IF;
    --          END IF;
    --
    --          IF LT_CONTACTS_DATA(XC_CONTACTS_IDX).TELEPHONE_TYPE IS NOT NULL AND LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --             .TELEPHONE_TYPE <> 'EMAIL' THEN
    --            BEGIN
    --              SELECT 1
    --                INTO LN_COUNT
    --                FROM AR_LOOKUPS -- fnd_lookup_values_vl
    --               WHERE LOOKUP_TYPE = 'PHONE_LINE_TYPE'
    --                 AND LOOKUP_CODE = LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --                    .TELEPHONE_TYPE;
    --            EXCEPTION
    --              WHEN NO_DATA_FOUND THEN
    --                LC_CONTACTS_VALID_DATA := GC_NO_FLAG;
    --                NULL;
    --                /*XXD_COMMON_UTILS.RECORD_ERROR(P_MODULE     => 'AR',
    --                P_ORG_ID     => GN_ORG_ID,
    --                P_PROGRAM    => 'Deckers AR Customer Conversion Program',
    --                P_ERROR_MSG  => 'Exception Raised in PHONE_LINE_TYPE validation =>' || LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --                               .TELEPHONE_TYPE,
    --                P_ERROR_LINE => DBMS_UTILITY.FORMAT_ERROR_BACKTRACE,
    --                P_CREATED_BY => GN_USER_ID,
    --                P_REQUEST_ID => GN_CONC_REQUEST_ID,
    --                P_MORE_INFO1 => 'TELEPHONE_TYPE',
    --                P_MORE_INFO2 => LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --                                .TELEPHONE_TYPE,
    --                P_MORE_INFO3 => GC_CUSTOMER_NAME,
    --                P_MORE_INFO4 => GC_CUST_ADDRESS);*/
    --              WHEN OTHERS THEN
    --                LC_CONTACTS_VALID_DATA := GC_NO_FLAG;
    --            END;
    --          END IF;
    --
    --          IF LC_CONTACTS_VALID_DATA = GC_YES_FLAG THEN
    --            UPDATE XXDO_AR_CUST_CONT_POINT_STG_T
    --               SET RECORD_STATUS = GC_VALIDATE_STATUS
    --             WHERE ORIG_SYSTEM_CUSTOMER_REF = LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --                  .ORIG_SYSTEM_CUSTOMER_REF -- need to add conct ref also in where
    --               AND ORIG_SYSTEM_TELEPHONE_REF = LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --                  .ORIG_SYSTEM_TELEPHONE_REF; -- update contact_ponit table with VALID status
    --          ELSE
    --            UPDATE XXDO_AR_CUST_CONT_POINT_STG_T
    --               SET RECORD_STATUS = GC_ERROR_STATUS
    --             WHERE ORIG_SYSTEM_CUSTOMER_REF = LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --                  .ORIG_SYSTEM_CUSTOMER_REF -- need to add conct ref also in where
    --               AND ORIG_SYSTEM_TELEPHONE_REF = LT_CONTACTS_DATA(XC_CONTACTS_IDX)
    --                  .ORIG_SYSTEM_TELEPHONE_REF; -- update contact_ponit table with VALID status
    --          END IF;
    --        END LOOP;
    --      END IF;
    --
    --      COMMIT;
    --      EXIT WHEN CUR_CONTACTS%NOTFOUND;
    --    END LOOP;
    --
    --    CLOSE CUR_CONTACTS;
    --  EXCEPTION
    --    WHEN NO_DATA_FOUND THEN
    --      ROLLBACK;
    --    WHEN OTHERS THEN
    --      ROLLBACK;
    --  END VALIDATE_CONTACT_POINTS;

    /*****************************************************************************************
    *  Procedure Name :   VALIDATE_CUST_CONTACTS                                             *
    *                                                                                        *
    *  Description    :   This Procedure shall validates the customer tables                 *
    *                                                                                        *
    *                                                                                        *
    *                                                                                        *
    *  Called From    :   Concurrent Program                                                 *
    *                                                                                        *
    *  Parameters             Type       Description                                         *
    *  -----------------------------------------------------------------------------         *
    *  p_debug                  IN       Debug Y/N                                           *
    *  p_action                 IN       Action (VALIDATE OR PROCESSED)                      *
    *  p_customer_id    IN       Header Stage table ref orig_sys_header_ref                  *
    *                                                                                        *
    * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                    *
    *                                                                                        *
     *****************************************************************************************/
    PROCEDURE validate_cust_contacts (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_batch_id IN NUMBER)
    --                                                         ,p_address_id    IN NUMBER)

    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_contacts (p_action VARCHAR2)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxdo_ar_cust_contacts_stg_t xcp
             WHERE     record_status IN (gc_new_status, gc_error_status)
                   AND batch_number = p_batch_id;

        TYPE lt_contacts_typ IS TABLE OF cur_contacts%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_contacts_data         lt_contacts_typ;

        lc_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lx_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                 NUMBER := 0;
        lc_customer_chk          VARCHAR2 (1);
        lc_error_message         VARCHAR2 (2000);
    BEGIN
        log_records (p_debug, 'Start validation for contacts ');

        OPEN cur_contacts (p_action => p_action);

        LOOP
            FETCH cur_contacts BULK COLLECT INTO lt_contacts_data LIMIT 1000;

            log_records (
                p_debug,
                   'Start validation for contacts lt_contacts_data.COUNT => '
                || lt_contacts_data.COUNT);

            IF lt_contacts_data.COUNT > 0
            THEN
                FOR xc_contacts_idx IN lt_contacts_data.FIRST ..
                                       lt_contacts_data.LAST
                LOOP
                    lc_contacts_valid_data   := gc_yes_flag;
                    lc_error_message         := NULL;
                    lc_customer_chk          := NULL;
                    gc_cust_contact          :=
                        lt_contacts_data (xc_contacts_idx).contact_first_name;

                    BEGIN
                        IF lt_contacts_data (xc_contacts_idx).brand IS NULL
                        THEN
                            SELECT gc_yes_flag
                              INTO lc_customer_chk
                              FROM hz_cust_accounts
                             WHERE TO_CHAR (account_number) =
                                   TO_CHAR (
                                       lt_contacts_data (xc_contacts_idx).customer_number);
                        ELSE
                            SELECT gc_yes_flag
                              INTO lc_customer_chk
                              FROM hz_cust_accounts
                             WHERE account_number =
                                      lt_contacts_data (xc_contacts_idx).customer_number
                                   || '-'
                                   || lt_contacts_data (xc_contacts_idx).brand;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_contacts_valid_data   := gc_no_flag;
                            lc_error_message         :=
                                'Customer not found in system';
                        WHEN OTHERS
                        THEN
                            lc_contacts_valid_data   := gc_no_flag;
                            lc_error_message         :=
                                   'Validation Error - '
                                || SQLCODE
                                || ' : '
                                || SQLERRM;
                    END;

                    IF lc_contacts_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxdo_ar_cust_contacts_stg_t
                           SET record_status   = gc_validate_status
                         WHERE     customer_number =
                                   lt_contacts_data (xc_contacts_idx).customer_number
                               AND NVL (brand, 'X') =
                                   NVL (
                                       lt_contacts_data (xc_contacts_idx).brand,
                                       'X')
                               AND batch_number = p_batch_id;
                    ELSE
                        --gc_error_status
                        UPDATE xxdo_ar_cust_contacts_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     customer_number =
                                   lt_contacts_data (xc_contacts_idx).customer_number
                               AND NVL (brand, 'X') =
                                   NVL (
                                       lt_contacts_data (xc_contacts_idx).brand,
                                       'X')
                               AND batch_number = p_batch_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_contacts%NOTFOUND;
        END LOOP;

        CLOSE cur_contacts;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ROLLBACK;
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_cust_contacts;

    PROCEDURE extract_1206_data (p_source_org_id IN VARCHAR2, p_target_org_name IN VARCHAR2, x_total_rec OUT NUMBER
                                 , x_validrec_cnt OUT NUMBER, x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
        procedure_name    CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage             VARCHAR2 (50) := NULL;
        ln_record_count            NUMBER := 0;
        lv_string                  LONG;

        CURSOR lcu_extract_count IS
            SELECT COUNT (*)
              FROM xxdo_ar_cust_contacts_stg_t
             WHERE record_status = 'NEW';

        --AND    source_org    = p_source_org_id;



        CURSOR lcu_cust_cont_data (p_org_id NUMBER, p_old_org_name VARCHAR)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   DISTINCT contact.RECORD_TYPE, contact.CONTACT_ATTRIBUTE_CATEGORY, p_old_org_name OPERATING_UNIT,
                            brandt.LEGACY_CUSTOMER_ACCOUNT CUSTOMER_NUMBER, brandt.BRAND, brandt.CUSTOMER_NAME,
                            contact.CONTACT_FIRST_NAME, contact.CONTACT_KEY, contact.CONTACT_LAST_NAME,
                            point.CONTACT_POINT_TYPE, contact.CONTACT_TITLE, NULL CREATED_BY,
                            NULL CREATION_DATE, point.EMAIL_ADDRESS, contact.INSERT_UPDATE_FLAG,
                            NULL LAST_UPDATE_DATE, NULL LAST_UPDATE_LOGIN, NULL LAST_UPDATED_BY,
                            point.MAIL_STOP, NULL ORG_ID, contact.ORIG_SYSTEM_ADDRESS_REF,
                            contact.ORIG_SYSTEM_CONTACT_REF, contact.ORIG_SYSTEM_CUSTOMER_REF, point.ORIG_SYSTEM_TELEPHONE_REF,
                            point.PHONE_COUNTRY_CODE, point.TELEPHONE, point.TELEPHONE_AREA_CODE,
                            point.TELEPHONE_EXTENSION, point.TELEPHONE_TYPE, CONTACT_POINT_PURPOSE,
                            PRIMARY_BY_PURPOSE, EMAIL_FORMAT, JOB_TITLE,
                            JOB_TITLE_CODE, 'NEW' RECORD_STATUS, NULL ERROR_MESSAGE,
                            SOURCE_ORG_ID, CONTACT_ID, NULL PARTY_NUMBER,
                            NULL ROLE, NULL BATCH_NUMBER, NULL REQUEST_ID
              FROM XXD_AR_CUST_CONTACTS_1206_T contact, XXD_AR_CUST_CONT_POINT_1206_T point, hz_cust_accounts_all hca,
                   xxd_ar_brand_cust_stg_t brandt
             WHERE     contact.ORIG_SYSTEM_CUSTOMER_REF =
                       point.ORIG_SYSTEM_CUSTOMER_REF
                   AND point.ORIG_SYSTEM_CONTACT_REF =
                       contact.ORIG_SYSTEM_CONTACT_REF
                   AND hca.cust_account_id = contact.ORIG_SYSTEM_CUSTOMER_REF
                   AND point.RECORD_TYPE = 'Customer Contact Communication'
                   AND hca.cust_account_id = point.ORIG_SYSTEM_CUSTOMER_REF
                   AND hca.attribute18 IS NULL
                   AND contact.ORIG_SYSTEM_ADDRESS_REF IS NULL
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo_ar_cust_contacts_stg_t stg
                             WHERE TO_CHAR (stg.ORIG_SYSTEM_CUSTOMER_REF) =
                                   TO_CHAR (contact.ORIG_SYSTEM_CUSTOMER_REF))
                   AND hca.account_number = brandt.LEGACY_CUSTOMER_ACCOUNT
                   AND EXISTS
                           (SELECT 1
                              FROM HZ_CUST_ACCT_SITES_ALL hcs
                             WHERE     hca.cust_account_id =
                                       hcs.cust_account_id
                                   AND org_id = p_org_id);

        TYPE xxd_ar_cust_cont_int_tab IS TABLE OF lcu_cust_cont_data%ROWTYPE
            INDEX BY BINARY_INTEGER;

        gtt_ar_cust_cont_int_tab   xxd_ar_cust_cont_int_tab;
    BEGIN
        gtt_ar_cust_cont_int_tab.delete;
        lv_error_stage   := 'Inserting Customer contacts Data';
        log_records (gc_debug_flag, lv_error_stage);

        FOR lc_org
            IN (SELECT DISTINCT hou.organization_id, flv.meaning old_org_name --
                  FROM apps.fnd_lookup_values flv, hr_operating_units hou
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND language = 'US'
                       AND hou.name = flv.attribute1
                       AND attribute1 = p_target_org_name)
        LOOP
            log_records (gc_debug_flag,
                         'lookup_code => ' || lc_org.organization_id);

            OPEN lcu_cust_cont_data (lc_org.organization_id,
                                     lc_org.old_org_name);

            LOOP
                log_records (gc_debug_flag,
                             'lookup_code 2 => ' || lc_org.organization_id);
                gtt_ar_cust_cont_int_tab.delete;

                FETCH lcu_cust_cont_data
                    BULK COLLECT INTO gtt_ar_cust_cont_int_tab
                    LIMIT 5000;

                log_records (
                    gc_debug_flag,
                    'lookup_code => Inserting' || gtt_ar_cust_cont_int_tab.COUNT);

                FORALL i IN 1 .. gtt_ar_cust_cont_int_tab.COUNT
                    INSERT INTO xxdo_ar_cust_contacts_stg_t
                         VALUES gtt_ar_cust_cont_int_tab (i);

                COMMIT;

                EXIT WHEN lcu_cust_cont_data%NOTFOUND;
            END LOOP;

            CLOSE lcu_cust_cont_data;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            --         x_errbuf := SQLERRM;
            --         x_retcode := 1;
            log_records (
                gc_debug_flag,
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            log_records (gc_debug_flag, 'Exception ' || SQLERRM);
    END extract_1206_data;


    --Start of adding prc by BT Technology team on 25-May-2015--
    /******************************************************
     * Procedure: Customer_main_proc
     *
     * Synopsis: This procedure will call we be called by the concurrent program
     * Design:
     *
     * Notes:
     *
     * PARAMETERS:
     *   IN OUT: x_errbuf   Varchar2
     *   IN OUT: x_retcode  Varchar2
     *   IN    : p_process  varchar2
     *
     * Return Values:
     * Modifications:
     *
     ******************************************************/

    PROCEDURE customer_main_proc (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2, p_org_name IN VARCHAR2, p_customer_classification IN VARCHAR2, p_debug_flag IN VARCHAR2
                                  , p_no_of_process IN NUMBER)
    IS
        x_errcode                VARCHAR2 (500);
        x_errmsg                 VARCHAR2 (500);
        lc_debug_flag            VARCHAR2 (1);
        ln_process               NUMBER;
        ln_ret                   NUMBER;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id          hdr_batch_id_t;

        TYPE hdr_customer_process_t IS TABLE OF VARCHAR2 (250)
            INDEX BY BINARY_INTEGER;

        lc_hdr_customer_proc_t   hdr_customer_process_t;

        lc_conlc_status          VARCHAR2 (150);
        ln_request_id            NUMBER := 0;
        lc_phase                 VARCHAR2 (200);
        lc_status                VARCHAR2 (200);
        lc_dev_phase             VARCHAR2 (200);
        lc_dev_status            VARCHAR2 (200);
        lc_message               VARCHAR2 (200);
        ln_ret_code              NUMBER;
        lc_err_buff              VARCHAR2 (1000);
        ln_count                 NUMBER;
        ln_cntr                  NUMBER := 0;
        --      ln_batch_cnt          NUMBER                                   := 0;
        ln_parent_request_id     NUMBER := fnd_global.conc_request_id;
        lb_wait                  BOOLEAN;
        lx_return_mesg           VARCHAR2 (2000);
        ln_valid_rec_cnt         NUMBER;
        x_total_rec              NUMBER;
        x_validrec_cnt           NUMBER;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id                 request_table;
    BEGIN
        gc_debug_flag   := p_debug_flag;

        IF p_process = gc_extract_only
        THEN
            IF p_debug_flag = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;

            --         truncte_stage_tables (x_ret_code      => x_retcode,
            --                               x_return_mesg   => x_errbuf);
            --         --         extract_cust_proc (x_errcode,
            --                            x_errmsg,
            --                            p_no_of_process,
            --                            lc_debug_flag);
            log_records (
                gc_debug_flag,
                'Woking on extract the data for the OU ' || p_org_name);
            extract_1206_data (p_source_org_id     => NULL   --p_source_org_id
                                                          ,
                               p_target_org_name   => p_org_name --p_target_org_id
                                                                ,
                               x_total_rec         => x_total_rec,
                               x_validrec_cnt      => x_validrec_cnt,
                               x_errbuf            => x_errbuf,
                               x_retcode           => x_retcode);
            log_records (
                gc_debug_flag,
                'Woking on extract the data for the OU ' || p_org_name);
        --         extract_1206_data (p_source_org_id     => NULL      --p_source_org_id
        --                                                       ,
        --                            p_target_org_name   => p_org_name --p_target_org_id
        --                                                             ,
        --                            x_total_rec         => x_total_rec,
        --                            x_validrec_cnt      => x_validrec_cnt,
        --                            x_errbuf            => x_errbuf,
        --                            x_retcode           => x_retcode);
        ELSIF p_process = gc_validate_only
        THEN
            UPDATE xxdo_ar_cust_contacts_stg_t
               SET batch_number = NULL, record_status = gc_new_status
             WHERE     record_status = gc_new_status
                   AND operating_unit IN
                           (SELECT meaning
                              FROM fnd_lookup_values
                             WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                                   AND attribute1 = p_org_name
                                   AND language = 'US'); -- IN( gc_new_status,gc_error_status);

            --      SELECT COUNT ( * )
            --        INTO ln_valid_rec_cnt
            --        FROM xxdo_ar_cust_contacts_stg_t
            --       WHERE batch_number IS NULL
            --         AND record_status = gc_new_status
            --              AND operating_unit IN
            --               (SELECT meaning
            --                  FROM fnd_lookup_values
            --                 WHERE lookup_type = 'XXD_1206_OU_MAPPING' AND attribute1 = p_org_name AND language = 'US');

            --write_log ('Creating Batch id and update  XXD_AR_CUST_INT_STG_T');

            -- Create batches of records and assign batch id



            --      FOR i IN 1 .. p_no_of_process
            --      LOOP
            --        BEGIN
            --          SELECT xxd_ar_cust_batch_id_s.NEXTVAL INTO ln_hdr_batch_id ( i ) FROM DUAL;
            --
            --          log_records ( gc_debug_flag
            --                      ,  'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id ( i ) );
            --        EXCEPTION
            --          WHEN OTHERS
            --          THEN
            --            ln_hdr_batch_id ( i + 1 )   := ln_hdr_batch_id ( i ) + 1;
            --        END;
            --
            --        log_records ( gc_debug_flag
            --                    ,  ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt );
            --        log_records ( gc_debug_flag
            --                    ,  'ceil( ln_valid_rec_cnt/p_no_of_process) := ' || CEIL ( ln_valid_rec_cnt / p_no_of_process ) );
            --
            --        UPDATE xxdo_ar_cust_contacts_stg_t
            --           SET batch_number   = ln_hdr_batch_id ( i )
            --             ,  request_id     = ln_parent_request_id
            --         WHERE batch_number IS NULL
            --           AND ROWNUM <= CEIL ( ln_valid_rec_cnt / p_no_of_process )
            --           AND record_status = gc_new_status
            --                    AND operating_unit IN
            --                 (SELECT meaning
            --                    FROM fnd_lookup_values
            --                   WHERE lookup_type = 'XXD_1206_OU_MAPPING' AND attribute1 = p_org_name AND language = 'US');
            --
            --
            --        COMMIT;
            --      END LOOP;

            ln_valid_rec_cnt   := 0;

            FOR I
                IN (  SELECT MIN (CUSTOMER_NUMBER) AS Starting_Value, MAX (CUSTOMER_NUMBER) AS Ending_Value, COUNT (*) AS Total_Records,
                             grp_nbr AS Group_Nbr
                        FROM (SELECT CUSTOMER_NUMBER, NTILE (p_no_of_process) OVER (ORDER BY CUSTOMER_NUMBER) grp_nbr
                                FROM XXD_CONV.xxdo_ar_cust_contacts_stg_t
                               WHERE     batch_number IS NULL
                                     AND record_status = gc_new_status
                                     AND operating_unit IN
                                             (SELECT meaning
                                                FROM fnd_lookup_values
                                               WHERE     lookup_type =
                                                         'XXD_1206_OU_MAPPING'
                                                     AND attribute1 =
                                                         p_org_name
                                                     AND language = 'US'))
                    GROUP BY grp_nbr)
            LOOP
                BEGIN
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;

                    SELECT xxd_ar_cust_batch_id_s.NEXTVAL
                      INTO ln_hdr_batch_id (ln_valid_rec_cnt)
                      FROM DUAL;

                    log_records (
                        gc_debug_flag,
                           'ln_hdr_batch_id(ln_valid_rec_cnt) := '
                        || ln_hdr_batch_id (ln_valid_rec_cnt));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (ln_valid_rec_cnt)   :=
                            ln_hdr_batch_id (ln_valid_rec_cnt) + 1;
                END;

                UPDATE xxdo_ar_cust_contacts_stg_t
                   SET batch_number = ln_hdr_batch_id (ln_valid_rec_cnt), request_id = ln_parent_request_id
                 WHERE     batch_number IS NULL
                       AND record_status = gc_new_status
                       AND TO_NUMBER (CUSTOMER_NUMBER) BETWEEN i.Starting_Value
                                                           AND i.Ending_Value
                       AND operating_unit IN
                               (SELECT meaning
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_1206_OU_MAPPING'
                                       AND attribute1 = p_org_name
                                       AND language = 'US');
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXDO_AR_CUST_CONTACTS_STG_T');
        --validate_cust_proc (x_errcode, x_errmsg, lc_debug_flag);
        ELSIF p_process = gc_load_only
        THEN
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXDO_AR_CUST_CONTACTS_STG_T stage to call worker process');
            ln_cntr   := 0;

            FOR i
                IN (SELECT DISTINCT batch_number
                      FROM xxdo_ar_cust_contacts_stg_t
                     WHERE     batch_number IS NOT NULL
                           AND record_status = gc_validate_status
                           AND operating_unit IN
                                   (SELECT meaning
                                      FROM fnd_lookup_values
                                     WHERE     lookup_type =
                                               'XXD_1206_OU_MAPPING'
                                           AND attribute1 = p_org_name
                                           AND language = 'US'))
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_number;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXDO_AR_CUST_CONTACTS_STG_T');

            COMMIT;
        END IF;

        IF ln_hdr_batch_id.COUNT > 0
        THEN
            log_records (
                gc_debug_flag,
                'Calling XXD_AR_CUST_CONT_CHILD in batch ' || ln_hdr_batch_id.COUNT);

            FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxdo_ar_cust_contacts_stg_t
                 WHERE     batch_number = ln_hdr_batch_id (i)
                       AND operating_unit IN
                               (SELECT meaning
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_1206_OU_MAPPING'
                                       AND attribute1 = p_org_name
                                       AND language = 'US');

                IF ln_cntr > 0
                THEN
                    BEGIN
                        log_records (
                            gc_debug_flag,
                               'Calling Worker process for batch id ln_hdr_batch_id(i) := '
                            || ln_hdr_batch_id (i));
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_AR_CUST_CONT_CHILD',
                                '',
                                '',
                                FALSE,
                                p_debug_flag,
                                p_process,
                                p_org_name,
                                ln_hdr_batch_id (i),
                                ln_parent_request_id);
                        log_records (gc_debug_flag,
                                     'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (i)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_AR_CUST_CONT_CHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_AR_CUST_CONT_CHILD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        END IF;

        log_records (
            gc_debug_flag,
            'Calling XXD_AR_CUST_CONT_CHILD in batch ' || ln_hdr_batch_id.COUNT);
        log_records (
            gc_debug_flag,
            'Calling WAIT FOR REQUEST XXD_AR_CUST_CONT_CHILD to complete');

        IF l_req_id.COUNT > 0
        THEN
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec) > 0
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec) --ln_concurrent_request_id
                                                              ,
                                interval     => 1,
                                max_wait     => 1,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);

                        IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    :=
                   'Error Message Customer_main_proc '
                || SUBSTR (SQLERRM, 1, 250);
    END customer_main_proc;

    --+=====================================================================================+
    -- |Procedure  :  customer_child                                                       |
    -- |                                                                                    |
    -- |Description:  This procedure is the Child Process which will validate and create the|
    -- |              Price list in QP 1223 instance                                        |
    -- |                                                                                    |
    -- | Parameters : p_batch_id, p_action                                                  |
    -- |              p_debug_flag, p_parent_req_id                                         |
    -- |                                                                                    |
    -- |                                                                                    |
    -- | Returns :     x_errbuf,  x_retcode                                                 |
    -- |                                                                                    |
    --+=====================================================================================+

    --Deckers AR Customer Conversion Program (Worker)
    PROCEDURE customer_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, p_org_name IN VARCHAR2, -- p_validation_level    IN     VARCHAR2,
                                                                                                                                                             p_batch_id IN NUMBER
                              , p_parent_request_id IN NUMBER)
    AS
        le_invalid_param            EXCEPTION;
        ln_new_ou_id                hr_operating_units.organization_id%TYPE; --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12

        ln_request_id               NUMBER := 0;
        lc_username                 fnd_user.user_name%TYPE;
        lc_operating_unit           hr_operating_units.name%TYPE;
        lc_cust_num                 VARCHAR2 (5);
        lc_pri_flag                 VARCHAR2 (1);
        ld_start_date               DATE;
        ln_ins                      NUMBER := 0;
        lc_create_reciprocal_flag   VARCHAR2 (1) := gc_no_flag;
        --ln_request_id             NUMBER                     := 0;
        lc_phase                    VARCHAR2 (200);
        lc_status                   VARCHAR2 (200);
        lc_delc_phase               VARCHAR2 (200);
        lc_delc_status              VARCHAR2 (200);
        lc_message                  VARCHAR2 (200);
        ln_ret_code                 NUMBER;
        lc_err_buff                 VARCHAR2 (1000);
        ln_count                    NUMBER;
        l_target_org_id             NUMBER;
    BEGIN
        gc_debug_flag        := p_debug_flag;
        gn_conc_request_id   := p_parent_request_id;

        --g_err_tbl_type.delete;
        BEGIN
            SELECT user_name
              INTO lc_username
              FROM fnd_user
             WHERE user_id = fnd_global.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_username   := NULL;
        END;

        BEGIN
            SELECT name
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;

        -- Validation Process for Price List Import
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '***************     '
            || lc_operating_unit
            || '***************** ');
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Busines Unit:'
            || lc_operating_unit);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run By      :'
            || lc_username);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run Date    :'
            || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Batch ID    :'
            || p_batch_id);
        fnd_file.new_line (fnd_file.LOG, 1);

        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        log_records (gc_debug_flag,
                     '******** START of Customer Import Program ******');
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');

        gc_debug_flag        := p_debug_flag;
        --      l_target_org_id := get_targetorg_id (p_org_name => p_org_name);
        gn_org_id            := NVL (l_target_org_id, gn_org_id);

        IF p_action = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling customer_validation :');



            validate_cust_contacts (p_debug      => gc_debug_flag,
                                    p_action     => gc_new_status,
                                    p_batch_id   => p_batch_id);
        ELSIF p_action = gc_load_only
        THEN
            l_target_org_id   := get_targetorg_id (p_org_name => p_org_name);

            --         BEGIN
            --fnd_global.apps_initialize(1643,20678,222);
            mo_global.init ('AR');
            mo_global.set_policy_context ('S', l_target_org_id);

            --            SELECT generate_customer_number
            --              INTO gc_generate_customer_number
            --              FROM ar_system_parameters_all
            --             WHERE org_id = l_target_org_id;

            /*   IF gc_generate_customer_number = gc_yes_flag
               THEN                     --gc_auto_site_numbering = gc_yes_flag OR
                  fnd_file.put_line (
                     fnd_file.output,
                        'AUTO_SITE_NUMBERING OR GENERATE_CUSTOMER_NUMBER is not diasbled  in the System Options for the organization '
                     || p_org_name);
                  fnd_file.put_line (
                     fnd_file.LOG,
                        'AUTO_SITE_NUMBERING OR GENERATE_CUSTOMER_NUMBER is not diasbled  in the System Options for the organization '
                     || p_org_name);
                  RAISE NO_DATA_FOUND;
               END IF;
            END;
   */
            /*IF fnd_profile.value('HZ_GENERATE_PARTY_NUMBER') IS NULL OR fnd_profile.value('HZ_GENERATE_PARTY_NUMBER') = 'Y'   THEN
              fnd_file.put_line (fnd_file.output, 'HZ: Generate Party Number is set to NULL or Yes');
              fnd_file.put_line (fnd_file.log, 'HZ: Generate Party Number is set to NULL or Yes');
             RAISE NO_DATA_FOUND;
            END IF;*/
            log_records (gc_debug_flag, 'Calling create_customer +');
            --         create_customer (x_errbuf           => errbuf,
            --                          x_retcode          => retcode,
            --                          p_action           => gc_validate_status,
            --                          p_operating_unit   => p_org_name,
            --                          p_target_org_id    => l_target_org_id,
            --                          p_batch_id         => p_batch_id);
            --
            --         create_person (x_errbuf           => errbuf,
            --                        x_retcode          => retcode,
            --                        p_action           => gc_validate_status,
            --                        p_operating_unit   => p_org_name,
            --                        p_target_org_id    => l_target_org_id,
            --                        p_batch_id         => p_batch_id);
            --      ELSIF p_action = 'VALIDATE AND LOAD'
            --      THEN
            --         NULL;

            create_contacts_records (p_debug      => gc_debug_flag,
                                     p_action     => gc_new_status,
                                     p_batch_id   => p_batch_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.output,
                               'Exception Raised During Customer Program');
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END customer_child;
END XXDO_CUSTOMER_CONTACT_CONV_PKG;
/
