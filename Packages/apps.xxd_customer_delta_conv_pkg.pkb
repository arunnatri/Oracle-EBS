--
-- XXD_CUSTOMER_DELTA_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_customer_delta_conv_pkg
AS
    /*******************************************************************************
      * Program Name : XXD_CUSTOMER_DELTA_CONV_PKG
      * Language     : PL/SQL
      * Description  : This package will convert party, Customer, location, site,
      *                uses, contacts, account.
      *
      * History      :
      *
      * WHO                  WHAT              DESC                       WHEN
      * -------------- ---------------------------------------------- ---------------
      * BT Technology Team   1.0              Initial Version          17-JUN-2014
      *******************************************************************************/
    gc_recordvalidation              VARCHAR2 (40);
    gc_err_msg                       VARCHAR2 (2000);
    gn_cust_ins                      NUMBER := 0;
    gn_prof_ins                      NUMBER := 0;
    gn_cont_ins                      NUMBER := 0;
    gn_cust_val                      NUMBER := 0;
    gn_cust_site_val                 NUMBER := 0;
    gn_site_use_val                  NUMBER := 0;
    gn_prof_val                      NUMBER := 0;
    gn_cont_val                      NUMBER := 0;
    gn_cont_point_val                NUMBER := 0;
    gn_cust_val_err                  NUMBER := 0;
    gn_cust_site_err                 NUMBER := 0;
    gn_site_use_err                  NUMBER := 0;
    gn_prof_err                      NUMBER := 0;
    gn_cont_val_err                  NUMBER := 0;
    gn_cont_point_err                NUMBER := 0;
    gn_cust_sucuess                  NUMBER := 0;
    gn_prof_sucuess                  NUMBER := 0;
    gn_cont_sucuess                  NUMBER := 0;
    gn_err_cnt                       NUMBER := 0;
    gc_customer_name                 VARCHAR2 (250);
    gc_cust_address                  VARCHAR2 (250);
    gc_cust_site_use                 VARCHAR2 (250);
    gc_cust_contact                  VARCHAR2 (250);
    gc_cust_contact_point            VARCHAR2 (250);

    gc_auto_site_numbering           VARCHAR2 (25);
    gc_generate_customer_number      VARCHAR2 (25);

    TYPE xxd_ar_cust_int_tab IS TABLE OF xxd_ar_customer_dlt_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_int_tab              xxd_ar_cust_int_tab;

    TYPE xxd_ar_cust_site_int_tab
        IS TABLE OF xxd_ar_cust_sites_dlt_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_site_int_tab         xxd_ar_cust_site_int_tab;

    TYPE xxd_ar_cust_site_use_tab
        IS TABLE OF xxd_ar_cust_siteuse_dlt_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_site_use_int_tab     xxd_ar_cust_site_use_tab;

    TYPE xxd_ar_cust_cont_int_tab
        IS TABLE OF xxd_ar_contact_dlt_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_cont_int_tab         xxd_ar_cust_cont_int_tab;

    TYPE xxd_ar_cust_cont_pt_int_tab
        IS TABLE OF xxd_ar_cont_point_dlt_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_cont_point_int_tab   xxd_ar_cust_cont_pt_int_tab;

    TYPE xxd_ar_cust_prof_int_tab
        IS TABLE OF xxd_ar_cust_prof_dlt_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_prof_int_tab         xxd_ar_cust_prof_int_tab;

    TYPE xxd_ar_profamt_dlt_stg_tab
        IS TABLE OF xxd_ar_cust_profamt_dlt_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_prof_amt_int_tab     xxd_ar_profamt_dlt_stg_tab;

    -- +============================================================================================+
    -- | Name  : update_stg_errors                                                                  |
    -- | Description      : Procedure to update the errors information in the stage                 |
    -- |                                                                                            |
    -- | Parameters :  i_cust_ref, i_addr_ref  ,i_phone_ref  ,i_site_code  ,i_err_msg,i_err_code    |
    -- |                                                                                            |
    -- |                                                                                            |
    -- |                                                                                            |
    -- +============================================================================================+
    -- Procedure to update the Staging table error status if any error occurs in the validation

    /****************************************************************
    * Procedure: update_stg_tables_autonomous
    *
    * Synopsis: This procedure updates the stage tables using autonomous transaction
    * Design:
    *
    * Notes:
    *
    * PARAMETERS:
    *   IN:  p_table_name  VARCHAR2
    *   IN:  p_err_msg     VARCHAR2
    *   IN:  p_record_id   Number
    *   IN:  p_flag        VARCHAR2
    *   OUT: x_succ        VARCHAR2
    *   OUT: x_err_msg     VARCHAR2
    *
    * Return Values:
    *
    * Modifications:
    *
    ****************************************************************/
    PROCEDURE update_stg_tables_autonomous (p_table_name IN VARCHAR2, p_err_msg IN VARCHAR2, p_flag IN VARCHAR2
                                            , p_record_id IN NUMBER, x_succ OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        ld_date1   DATE;
    BEGIN
        ld_date1    := SYSDATE;

        IF p_table_name = 'XXD_AR_CUSTOMER_CONV_STG_T'
        THEN
            EXECUTE IMMEDIATE   'update '
                             || p_table_name
                             || ' set ERROR_MESSAGE = :p_err_msg1 , RECORD_STATUS= :p_flag1 , REQUEST_ID = :gn_req_id ,          LAST_UPDATED_BY = :gn_us_id , LAST_UPDATE_LOGIN= :gn_log_id , LAST_UPDATE_DATE=

:ld_date where customer_id= :p_sq_no '
                USING p_err_msg, p_flag, gn_request_id,
                      gn_user_id, gn_login_id, ld_date1,
                      p_record_id;
        ELSIF p_table_name = 'XXD_AR_CUST_ADDR_CONV_STG_T'
        THEN
            EXECUTE IMMEDIATE   'update '
                             || p_table_name
                             || '  set ERROR_MESSAGE =  :p_err_msg1, RECORD_STATUS= :p_flag1 , REQUEST_ID = :gn_req_id ,          LAST_UPDATED_BY = :gn_us_id , LAST_UPDATE_LOGIN= :gn_log_id , LAST_UPDATE_DATE=

:ld_date where address_id= :p_sq_no '
                USING p_err_msg, p_flag, gn_request_id,
                      gn_user_id, gn_login_id, ld_date1,
                      p_record_id;
        ELSIF p_table_name = 'XXD_AR_CUST_SITEUSE_DLT_STG_T'
        THEN
            EXECUTE IMMEDIATE   'update '
                             || p_table_name
                             || ' set ERROR_MESSAGE =  :p_err_msg1 , RECORD_STATUS= :p_flag1 , REQUEST_ID = :gn_req_id ,          LAST_UPDATED_BY = :gn_us_id , LAST_UPDATE_LOGIN= :gn_log_id , LAST_UPDATE_DATE=

:ld_date where site_use_id= :p_sq_no '
                USING p_err_msg, p_flag, gn_request_id,
                      gn_user_id, gn_login_id, ld_date1,
                      p_record_id;
        END IF;

        COMMIT;
        x_succ      := gc_yesflag;
        x_err_msg   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_err_msg   :=
                   'Unexpected error occured in the procedure update_stg_tables_autonomous while processing :'
                || SUBSTR (SQLERRM, 1, 250);
            x_succ   := gc_noflag;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception occured in update_stg_tables_autonomous: '
                || x_err_msg);

            xxd_common_utils.record_error ('ARCST', xxd_common_utils.get_org_id, 'Deckers AR Customer Delta Conversion Program', --SQLCODE,
                                                                                                                                 x_err_msg, DBMS_UTILITY.format_error_backtrace, --SUBSTR (DBMS_UTILITY.format_call_stack, 1, 299),
                                                                                                                                                                                 --SYSDATE,
                                                                                                                                                                                 fnd_profile.VALUE ('USER_ID')
                                           , fnd_global.conc_request_id);
    END update_stg_tables_autonomous;

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
                'Deckers AR Customer Delta Conversion Program', --      SQLCODE,
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
                'Deckers AR Customer Delta Conversion Program', --      SQLCODE,
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
                'Deckers AR Customer Delta Conversion Program', --      SQLCODE,
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

    PROCEDURE create_organization (p_organization_rec IN hz_party_v2pub.organization_rec_type, v_org_party_id OUT NUMBER)
    IS
        x_party_id        NUMBER;
        x_party_number    VARCHAR2 (2000);
        x_profile_id      NUMBER;
        x_return_status   VARCHAR2 (2000);
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
    BEGIN
        --g_process := 'create_Organization';

        hz_party_v2pub.create_organization (
            p_init_msg_list      => fnd_api.g_true,
            p_organization_rec   => p_organization_rec,
            x_party_id           => x_party_id,
            x_party_number       => x_party_number,
            x_profile_id         => x_profile_id,
            x_return_status      => x_return_status,
            x_msg_count          => x_msg_count,
            x_msg_data           => x_msg_data);

        IF x_return_status != 'S'
        THEN
            --vCustProfileId  := xCustProfileId;
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
                || '***************************');
            log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);

            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_organization',
                p_more_info2   => p_organization_rec.organization_name,
                p_more_info3   => NULL,
                p_more_info4   => NULL);

            FOR i IN 1 .. x_msg_count
            LOOP
                fnd_msg_pub.get (p_encoded         => fnd_api.g_false,
                                 p_data            => x_msg_data,
                                 p_msg_index_out   => x_msg_count);

                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                xxd_common_utils.record_error (
                    p_module       => 'AR',
                    p_org_id       => gn_org_id,
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_organization',
                    p_more_info2   => p_organization_rec.organization_name,
                    p_more_info3   => NULL,
                    p_more_info4   => NULL);
            END LOOP;
        ELSE
            --COMMIT;
            v_org_party_id   := x_party_id;
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
                || '***************************');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_organization ' || SQLERRM);
    END create_organization;

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
            log_records (
                gc_debug_flag,
                   'Error in create_role_contact for '
                || p_role_responsibility_rec.cust_account_role_id
                || ' and type  '
                || p_role_responsibility_rec.responsibility_type
                || ' Error '
                || x_msg_data);
            log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_role_contact=> ' || gc_customer_name,
                p_more_info2   => gc_cust_address,
                p_more_info3   => gc_cust_contact,
                p_more_info4   => gc_cust_contact_point);

            IF x_msg_count > 0
            THEN
                FOR i IN 1 .. x_msg_count
                LOOP
                    x_msg_data   :=
                        fnd_msg_pub.get (p_encoded => fnd_api.g_false);
                    log_records (gc_debug_flag,
                                 i || '. ' || SUBSTR (x_msg_data, 1, 255));
                    xxd_common_utils.record_error (
                        p_module       => 'AR',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers AR Customer Delta Conversion Program',
                        p_error_msg    => x_msg_data,
                        p_error_line   => DBMS_UTILITY.format_error_backtrace,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   =>
                            'create_role_contact=> ' || gc_customer_name,
                        p_more_info2   => gc_cust_address,
                        p_more_info3   => gc_cust_contact,
                        p_more_info4   => gc_cust_contact_point);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_role_contact ' || SQLERRM);
    END create_role_contact;

    PROCEDURE create_cust_account (p_cust_account_rec IN hz_cust_account_v2pub.cust_account_rec_type, p_organization_rec IN hz_party_v2pub.organization_rec_type, p_customer_profile_rec IN hz_customer_profile_v2pub.customer_profile_rec_type
                                   , v_cust_account_id OUT NUMBER, v_profile_id OUT NUMBER, x_return_status OUT VARCHAR2)
    IS
        ------------------------------------
        -- 2. Create a party and an account
        ------------------------------------
        x_cust_account_id   NUMBER;
        x_account_number    VARCHAR2 (2000);
        x_party_id          NUMBER;
        x_party_number      VARCHAR2 (2000);
        x_profile_id        NUMBER;
        --    x_return_status   VARCHAR2(10);
        x_msg_count         NUMBER;
        x_msg_data          VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_cust_account';
        hz_cust_account_v2pub.create_cust_account ('T', p_cust_account_rec, p_organization_rec, p_customer_profile_rec, 'F', x_cust_account_id, x_account_number, x_party_id, x_party_number, x_profile_id, x_return_status, x_msg_count
                                                   , x_msg_data);

        IF (x_return_status = 'S')
        THEN
            v_cust_account_id   := x_cust_account_id;
            v_profile_id        := x_profile_id;
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_cust_account_id: '
                || x_cust_account_id
                || CHR (10)
                || 'x_account_number: '
                || x_account_number
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
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_cust_account',
                p_more_info2   => p_cust_account_rec.account_name,
                p_more_info3   => p_cust_account_rec.account_number,
                p_more_info4   => NULL);

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
                    || 'x_cust_account_id: '
                    || x_cust_account_id
                    || CHR (10)
                    || 'x_account_number: '
                    || x_account_number
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
                    || '***************************');
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);

                IF x_msg_data IS NOT NULL
                THEN
                    log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                    xxd_common_utils.record_error (
                        p_module       => 'AR',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers AR Customer Delta Conversion Program',
                        p_error_msg    => x_msg_data,
                        p_error_line   => DBMS_UTILITY.format_error_backtrace,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => 'create_cust_account',
                        p_more_info2   => p_cust_account_rec.account_name,
                        p_more_info3   => p_cust_account_rec.account_number,
                        p_more_info4   => NULL);
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_cust_account ' || SQLERRM);
    END create_cust_account;

    PROCEDURE create_cust_profile (p_customer_profile_rec IN hz_customer_profile_v2pub.customer_profile_rec_type, v_profile_id OUT NUMBER, x_return_status OUT VARCHAR2)
    IS
        ------------------------------------
        --  Create a customer profile
        ------------------------------------
        x_profile_id   NUMBER;
        --    x_return_status   VARCHAR2(10);
        x_msg_count    NUMBER;
        x_msg_data     VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_cust_account';
        hz_customer_profile_v2pub.create_customer_profile ('T', p_customer_profile_rec, 'F', x_profile_id, x_return_status, x_msg_count
                                                           , x_msg_data);

        IF (x_return_status = 'S')
        THEN
            v_profile_id   := x_profile_id;
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
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
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_customer_profile',
                p_more_info2   => p_customer_profile_rec.cust_account_id,
                p_more_info3   => p_customer_profile_rec.site_use_id,
                p_more_info4   => NULL);

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
                    || 'x_profile_id: '
                    || x_profile_id
                    || CHR (10)
                    || 'x_return_status: '
                    || x_return_status
                    || CHR (10)
                    || 'x_msg_count: '
                    || x_msg_count
                    || CHR (10)
                    || '***************************');
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);

                IF x_msg_data IS NOT NULL
                THEN
                    log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                    xxd_common_utils.record_error (
                        p_module       => 'AR',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers AR Customer Delta Conversion Program',
                        p_error_msg    => x_msg_data,
                        p_error_line   => DBMS_UTILITY.format_error_backtrace,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => 'create_customer_profile',
                        p_more_info2   =>
                            p_customer_profile_rec.cust_account_id,
                        p_more_info3   => p_customer_profile_rec.site_use_id,
                        p_more_info4   => NULL);
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Exception in create_customer_profile ' || SQLERRM);
    END create_cust_profile;

    PROCEDURE create_cust_profile_amt (
        p_cpamt_rec IN hz_customer_profile_v2pub.cust_profile_amt_rec_type --                                ,p_cust_acct_profile_amt_id  IN NUMBER
                                                                          )
    IS
        v_cust_account_profile_id    NUMBER;
        x_return_status              VARCHAR2 (2000);
        x_msg_count                  NUMBER;
        x_msg_data                   VARCHAR2 (2000);
        x_cust_acct_profile_amt_id   NUMBER;
    BEGIN
        hz_customer_profile_v2pub.create_cust_profile_amt ('T', 'T', p_cpamt_rec, x_cust_acct_profile_amt_id, x_return_status, x_msg_count
                                                           , x_msg_data);

        IF (x_return_status = 'S')
        THEN
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_cust_acct_profile_amt_id: '
                || x_cust_acct_profile_amt_id
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
            xxd_common_utils.record_error (p_module => 'AR', p_org_id => gn_org_id, p_program => 'Deckers AR Customer Delta Conversion Program', p_error_msg => x_msg_data, p_error_line => DBMS_UTILITY.format_error_backtrace, p_created_by => gn_user_id
                                           , p_request_id => gn_conc_request_id, p_more_info1 => 'create_cust_profile_amt', --                                     p_more_info2 => p_cust_account_rec.account_name,
 --                                     p_more_info3 =>p_cust_account_rec.account_number,
                                            p_more_info4 => NULL);

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
                    || 'x_cust_acct_profile_amt_id: '
                    || x_cust_acct_profile_amt_id
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

                IF x_msg_data IS NOT NULL
                THEN
                    log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                    xxd_common_utils.record_error (p_module => 'AR', p_org_id => gn_org_id, p_program => 'Deckers AR Customer Delta Conversion Program', p_error_msg => x_msg_data, p_error_line => DBMS_UTILITY.format_error_backtrace, p_created_by => gn_user_id
                                                   , p_request_id => gn_conc_request_id, p_more_info1 => 'create_cust_profile_amt', --                                     p_more_info2 => p_cust_account_rec.account_name,
 --                                     p_more_info3 =>p_cust_account_rec.account_number,
                                                    p_more_info4 => NULL);
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Exception in create_cust_profile_amt ' || SQLERRM);
    END create_cust_profile_amt;

    PROCEDURE create_cust_account (p_cust_account_rec IN hz_cust_account_v2pub.cust_account_rec_type, p_person_rec IN hz_party_v2pub.person_rec_type, p_customer_profile_rec IN hz_customer_profile_v2pub.customer_profile_rec_type
                                   , v_cust_account_id OUT NUMBER, v_profile_id OUT NUMBER, v_contact_party_id OUT NUMBER)
    IS
        ------------------------------------
        -- 2. Create a party and an account
        ------------------------------------
        x_cust_account_id   NUMBER;
        x_account_number    VARCHAR2 (2000);
        x_party_id          NUMBER;
        x_party_number      VARCHAR2 (2000);
        x_profile_id        NUMBER;
        x_return_status     VARCHAR2 (2000);
        x_msg_count         NUMBER;
        x_msg_data          VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_cust_account';
        hz_cust_account_v2pub.create_cust_account ('T', p_cust_account_rec, p_person_rec, p_customer_profile_rec, 'F', x_cust_account_id, x_account_number, x_party_id, x_party_number, x_profile_id, x_return_status, x_msg_count
                                                   , x_msg_data);

        IF (x_return_status = 'S')
        THEN
            v_cust_account_id    := x_cust_account_id;
            v_contact_party_id   := x_party_id;
            v_profile_id         := x_profile_id;
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_cust_account_id: '
                || x_cust_account_id
                || CHR (10)
                || 'x_account_number: '
                || x_account_number
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
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_cust_account',
                p_more_info2   => p_cust_account_rec.account_name,
                p_more_info3   => p_cust_account_rec.account_number,
                p_more_info4   => NULL);

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
                    || 'x_cust_account_id: '
                    || x_cust_account_id
                    || CHR (10)
                    || 'x_account_number: '
                    || x_account_number
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
                    || '***************************');
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);

                IF x_msg_data IS NOT NULL
                THEN
                    xxd_common_utils.record_error (
                        p_module       => 'AR',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers AR Customer Delta Conversion Program',
                        p_error_msg    => x_msg_data,
                        p_error_line   => DBMS_UTILITY.format_error_backtrace,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => 'create_cust_account',
                        p_more_info2   => p_cust_account_rec.account_name,
                        p_more_info3   => p_cust_account_rec.account_number,
                        p_more_info4   => NULL);
                END IF;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_cust_account ' || SQLERRM);
    END create_cust_account;

    PROCEDURE create_location (p_location_rec IN hz_location_v2pub.location_rec_type, v_location_id OUT NUMBER)
    IS
        /* BEGIN address  */
        ------------------------------------
        -- 3. Create a physical location
        ------------------------------------
        x_location_id     NUMBER;
        x_return_status   VARCHAR2 (2000);
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
    BEGIN
        --g_process := 'create_location';
        hz_location_v2pub.create_location ('T',
                                           p_location_rec,
                                           x_location_id,
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
                || 'x_location_id: '
                || x_location_id
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
            v_location_id   := x_location_id;
        ELSE
            log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_location',
                p_more_info2   => p_location_rec.address1,
                p_more_info3   => p_location_rec.city,
                p_more_info4   => NULL);

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
                    || 'x_location_id: '
                    || x_location_id
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
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                xxd_common_utils.record_error (
                    p_module       => 'AR',
                    p_org_id       => gn_org_id,
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_location',
                    p_more_info2   => p_location_rec.address1,
                    p_more_info3   => p_location_rec.city,
                    p_more_info4   => NULL);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_location ' || SQLERRM);
    END create_location;

    PROCEDURE create_party_site (p_party_site_rec IN hz_party_site_v2pub.party_site_rec_type, x_party_site_id OUT NUMBER)
    AS
        ------------------------------------
        -- 4. Create a party site using party_id from step 2 and location_id from step 3
        ------------------------------------
        -- p_party_site_rec      hz_party_site_v2pub.party_site_rec_type;
        --x_party_site_id     NUMBER;
        x_party_site_number   VARCHAR2 (2000);
        x_return_status       VARCHAR2 (2000);
        x_msg_count           NUMBER;
        x_msg_data            VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_party_site';
        x_party_site_id   := NULL;
        hz_party_site_v2pub.create_party_site ('T', p_party_site_rec, x_party_site_id, x_party_site_number, x_return_status, x_msg_count
                                               , x_msg_data);

        IF (x_return_status = 'S')
        THEN
            --x_party_site_id     := x_party_site_id;
            --      v_party_site_number := x_party_site_number;

            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_party_site_id: '
                || x_party_site_id
                || CHR (10)
                || 'x_party_site_number: '
                || x_party_site_number
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
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_party_site ' || gc_customer_name,
                p_more_info2   => gc_cust_address,
                p_more_info3   => gc_cust_site_use,
                p_more_info4   => NULL);

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
                    || 'x_party_site_id: '
                    || x_party_site_id
                    || CHR (10)
                    || 'x_party_site_number: '
                    || x_party_site_number
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
                log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
                xxd_common_utils.record_error (
                    p_module       => 'AR',
                    p_org_id       => gn_org_id,
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_party_site ' || gc_customer_name,
                    p_more_info2   => gc_cust_address,
                    p_more_info3   => gc_cust_site_use,
                    p_more_info4   => NULL);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_party_site ' || SQLERRM);
    END create_party_site;

    PROCEDURE create_cust_acct_site (p_cust_acct_site_rec hz_cust_account_site_v2pub.cust_acct_site_rec_type, x_cust_acct_site_id OUT NUMBER)
    AS
        ------------------------------------
        -- 5. Create an account site using cust_account_id from step 2 and party_site_id from step 4.
        ------------------------------------
        x_return_status   VARCHAR2 (2000);
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
        --x_cust_acct_site_id NUMBER;
        x_retmsg          VARCHAR2 (1000);
        x_retcode         VARCHAR2 (100);
        l_sate_resion     VARCHAR2 (100);
    BEGIN
        --    g_process := 'create_cust_acct_site';
        hz_cust_account_site_v2pub.create_cust_acct_site (
            'T',
            p_cust_acct_site_rec,
            x_cust_acct_site_id,
            x_return_status,
            x_msg_count,
            x_msg_data);

        IF (x_return_status = 'S')
        THEN
            --x_cust_acct_site_id := x_cust_acct_site_id;
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_cust_acct_site_id: '
                || x_cust_acct_site_id
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
        --      g_process := 'xxqst_tarcd_processor.validate_sites';

        ELSE
            log_records (gc_debug_flag, 'x_msg_data: ' || x_msg_data);
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_cust_acct_site ' || gc_customer_name,
                p_more_info2   => gc_cust_address,
                p_more_info3   => gc_cust_site_use,
                p_more_info4   => NULL);

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
                    || 'x_cust_acct_site_id: '
                    || x_cust_acct_site_id
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
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   =>
                        'create_cust_acct_site ' || gc_customer_name,
                    p_more_info2   => gc_cust_address,
                    p_more_info3   => gc_cust_site_use,
                    p_more_info4   => NULL);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Exception in create_cust_acct_site ' || SQLERRM);
    END create_cust_acct_site;

    ------------------------------------
    -- 6. Create an account site use using cust_acct_site_id from step 5 and site_use_code='BILL_TO'
    ------------------------------------
    PROCEDURE create_cust_site_use (p_cust_site_use_rec hz_cust_account_site_v2pub.cust_site_use_rec_type, p_customer_profile_rec hz_customer_profile_v2pub.customer_profile_rec_type, v_cust_acct_site_use_id OUT NUMBER)
    AS
        x_site_use_id     NUMBER;
        x_return_status   VARCHAR2 (2000);
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
        lc_true_false     VARCHAR2 (1) := fnd_api.g_false;
    BEGIN
        IF p_customer_profile_rec.site_use_id IS NOT NULL
        THEN
            lc_true_false   := fnd_api.g_true;
        END IF;

        --    g_process := 'create_cust_site_use';
        hz_cust_account_site_v2pub.create_cust_site_use (
            'T',
            p_cust_site_use_rec,
            p_customer_profile_rec,
            lc_true_false,
            lc_true_false,
            x_site_use_id,
            x_return_status,
            x_msg_count,
            x_msg_data);

        IF (x_return_status = 'S')
        THEN
            --COMMIT;
            v_cust_acct_site_use_id   := x_site_use_id;
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_site_use_id: '
                || x_site_use_id
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
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_cust_site_use ' || gc_customer_name,
                p_more_info2   => gc_cust_address,
                p_more_info3   => gc_cust_site_use,
                p_more_info4   => NULL);

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
                    || 'x_site_use_id: '
                    || x_site_use_id
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
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   =>
                        'create_cust_site_use ' || gc_customer_name,
                    p_more_info2   => gc_cust_address,
                    p_more_info3   => gc_cust_site_use,
                    p_more_info4   => NULL);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_cust_site_use ' || SQLERRM);
    END create_cust_site_use;

    ------------------------------------
    -- 6. Create an account site use using cust_acct_site_id from step 5 and site_use_code='BILL_TO'
    ------------------------------------
    PROCEDURE update_cust_site_use (p_cust_site_use_rec hz_cust_account_site_v2pub.cust_site_use_rec_type, xio_p_object_version IN OUT NUMBER, v_cust_acct_site_use_id OUT NUMBER)
    AS
        x_site_use_id     NUMBER;
        x_return_status   VARCHAR2 (2000);
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
    BEGIN
        --    g_process := 'create_cust_site_use';
        hz_cust_account_site_v2pub.update_cust_site_use (
            'T',
            p_cust_site_use_rec,
            xio_p_object_version,
            x_return_status,
            x_msg_count,
            x_msg_data);

        IF (x_return_status = 'S')
        THEN
            --COMMIT;
            v_cust_acct_site_use_id   := x_site_use_id;
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'x_site_use_id: '
                || x_site_use_id
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
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'update_cust_site_use ' || gc_customer_name,
                p_more_info2   => gc_cust_address,
                p_more_info3   => gc_cust_site_use,
                p_more_info4   => NULL);

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
                    || 'x_site_use_id: '
                    || x_site_use_id
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
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   =>
                        'update_cust_site_use ' || gc_customer_name,
                    p_more_info2   => gc_cust_address,
                    p_more_info3   => gc_cust_site_use,
                    p_more_info4   => NULL);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in update_cust_site_use ' || SQLERRM);
    END update_cust_site_use;

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
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_person',
                p_more_info2   => gc_customer_name,
                p_more_info3   => NULL,
                p_more_info4   => NULL);

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
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_person',
                    p_more_info2   => gc_customer_name,
                    p_more_info3   => NULL,
                    p_more_info4   => NULL);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_person ' || SQLERRM);
    END create_person;

    ------------------------------------
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
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_org_contact',
                p_more_info2   => gc_customer_name,
                p_more_info3   => NULL,
                p_more_info4   => NULL);

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
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_org_contact',
                    p_more_info2   => gc_customer_name,
                    p_more_info3   => NULL,
                    p_more_info4   => NULL);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_org_contact ' || SQLERRM);
    END create_org_contact;

    ------------------------------------
    -- 9. Create a contact using party_id you get in step 8 and cust_account_id from step 2
    ------------------------------------
    PROCEDURE create_cust_account_role (
        p_cr_cust_acc_role_rec   hz_cust_account_role_v2pub.cust_account_role_rec_type)
    AS
        x_cust_account_role_id   NUMBER;
        x_return_status          VARCHAR2 (2000);
        x_msg_count              NUMBER;
        x_msg_data               VARCHAR2 (2000);
    BEGIN
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
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_cust_account_role',
                p_more_info2   => gc_customer_name,
                p_more_info3   => NULL,
                p_more_info4   => NULL);

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
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => 'create_cust_account_role',
                    p_more_info2   => gc_customer_name,
                    p_more_info3   => NULL,
                    p_more_info4   => NULL);
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

    /* Begin phone */
    ------------------------------------------------------
    -- 10. Create phon using party_id you get in atep 8
    ------------------------------------------------------
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
                p_program      => 'Deckers AR Customer Delta Conversion Program',
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
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   =>
                        'create_contact_point ' || gc_customer_name,
                    p_more_info2   => gc_cust_address,
                    p_more_info3   => gc_cust_contact,
                    p_more_info4   => gc_cust_contact_point);
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

    /*For Step 3: Create Cust Account relationship in such a way that ?Client1? is a related customer to ?Leasing Comp?
    */
    PROCEDURE create_cust_acct_relate (
        p_cust_acct_relate_rec   hz_cust_account_v2pub.cust_acct_relate_rec_type)
    AS
        x_return_status   VARCHAR2 (2000);
        x_msg_count       NUMBER;
        x_msg_data        VARCHAR2 (2000);
    BEGIN
        hz_cust_account_v2pub.create_cust_acct_relate (
            'T',
            p_cust_acct_relate_rec,
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
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   =>
                    'create_cust_acct_relate ' || gc_customer_name,
                p_more_info2   => gc_cust_address,
                p_more_info3   => gc_cust_site_use,
                p_more_info4   => NULL);

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
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   =>
                        'create_cust_acct_relate ' || gc_customer_name,
                    p_more_info2   => gc_cust_address,
                    p_more_info3   => gc_cust_site_use,
                    p_more_info4   => NULL);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Exception in create_cust_acct_relate ' || SQLERRM);
    END create_cust_acct_relate;

    PROCEDURE create_relationship (
        p_relationship_rec_type hz_relationship_v2pub.relationship_rec_type)
    AS
        x_relationship_id   NUMBER;
        x_party_id          NUMBER;
        x_party_number      VARCHAR2 (2000);
        x_return_status     VARCHAR2 (2000);
        x_msg_count         NUMBER;
        x_msg_data          VARCHAR2 (2000);
    BEGIN
        hz_relationship_v2pub.create_relationship ('T', p_relationship_rec_type, x_relationship_id, x_party_id, x_party_number, x_return_status
                                                   , x_msg_count, x_msg_data);

        IF (x_return_status = 'S')
        THEN
            log_records (
                gc_debug_flag,
                   '***************************'
                || CHR (10)
                || 'Output information ....'
                || CHR (10)
                || 'Relationship Id ='
                || TO_CHAR (x_relationship_id)
                || 'Party Number = '
                || x_party_number
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
                p_program      => 'Deckers AR Customer Delta Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_relationship ' || gc_customer_name,
                p_more_info2   => gc_cust_address,
                p_more_info3   => gc_cust_site_use,
                p_more_info4   => NULL);

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
                    p_program      =>
                        'Deckers AR Customer Delta Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   =>
                        'create_relationship ' || gc_customer_name,
                    p_more_info2   => gc_cust_address,
                    p_more_info3   => gc_cust_site_use,
                    p_more_info4   => NULL);
            END LOOP;
        END IF;

        IF x_msg_count > 1
        THEN
            FOR i IN 1 .. x_msg_count
            LOOP
                log_records (
                    gc_debug_flag,
                       i
                    || '.'
                    || SUBSTR (fnd_msg_pub.get (p_encoded => fnd_api.g_false),
                               1,
                               255));
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug     => gc_debug_flag,
                p_message   => 'Exception in create_relationship ' || SQLERRM);
    END create_relationship;

    --+------------------------------------------------------------------------------
    --| Name        : CREATE_CONTACTS_RECORDS
    --| Description : Customer Contacts Records
    --+------------------------------------------------------------------------------
    PROCEDURE create_contacts_records (pn_customer_id IN NUMBER, p_party_id IN NUMBER, p_address_id IN NUMBER
                                       , p_party_site_id IN NUMBER, p_cust_account_id IN NUMBER, p_cust_acct_site_id IN NUMBER --                                     ,x_ret_code              OUT NUMBER
                                                                                                                              --                                     ,x_err_msg               OUT VARCHAR
                                                                                                                              )
    IS
        --Customer Contacts
        CURSOR lcu_cust_contact (pn_customer_id NUMBER, p_address_id NUMBER)
        IS
            -- Customer Contacts
            SELECT record_type, contact_attribute_category, contact_first_name,
                   contact_key, contact_last_name, contact_point_type,
                   contact_title, created_by, creation_date,
                   email_address, insert_update_flag, job_title,
                   job_title_code, last_update_date, last_update_login,
                   last_updated_by, mail_stop, org_id,
                   orig_system_address_ref, orig_system_contact_ref, orig_system_customer_ref,
                   orig_system_telephone_ref, phone_country_code, telephone,
                   telephone_area_code, telephone_extension, telephone_type,
                   validated_flag, contact_id, party_number
              FROM xxd_ar_contact_dlt_stg_t acv
             WHERE     1 = 1
                   AND acv.orig_system_address_ref IS NULL
                   AND acv.orig_system_customer_ref =
                       TO_CHAR (pn_customer_id)  --Customer Id of the Customer
                   AND p_address_id IS NULL
                   AND acv.record_status = gc_validate_status
            UNION
            -- Customer Addresses Contacts
            SELECT record_type, contact_attribute_category, contact_first_name,
                   contact_key, contact_last_name, contact_point_type,
                   contact_title, created_by, creation_date,
                   email_address, insert_update_flag, job_title,
                   job_title_code, last_update_date, last_update_login,
                   last_updated_by, mail_stop, org_id,
                   orig_system_address_ref, orig_system_contact_ref, orig_system_customer_ref,
                   orig_system_telephone_ref, phone_country_code, telephone,
                   telephone_area_code, telephone_extension, telephone_type,
                   validated_flag, contact_id, party_number
              FROM xxd_ar_contact_dlt_stg_t acv
             WHERE     1 = 1
                   AND acv.orig_system_address_ref = NVL (p_address_id, -1)
                   AND acv.orig_system_customer_ref =
                       TO_CHAR (pn_customer_id)  --Customer Id of the Customer
                   AND acv.record_status = gc_validate_status;

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
                   url, email_format
              FROM xxd_ar_cont_point_dlt_stg_t apv
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
                   url, email_format
              FROM xxd_ar_cont_point_dlt_stg_t apv
             WHERE     apv.orig_system_address_ref = NVL (p_address_id, -1)
                   AND apv.orig_system_customer_ref =
                       TO_CHAR (pn_customer_id)
                   AND apv.record_status = gc_validate_status;

        -- Phones at customer contact and address contact level
        CURSOR lcu_cust_cont_phones (pn_customer_id NUMBER, p_address_id NUMBER, p_contact_id NUMBER)
        IS
            -- Customer Contacts Phones
            SELECT record_type, contact_attribute_category, contact_first_name,
                   contact_key, contact_last_name, contact_point_type,
                   contact_title, created_by, creation_date,
                   email_address, insert_update_flag, last_update_date,
                   last_update_login, last_updated_by, mail_stop,
                   org_id, orig_system_address_ref, orig_system_contact_ref,
                   orig_system_customer_ref, orig_system_telephone_ref, phone_country_code,
                   telephone, telephone_area_code, telephone_extension,
                   telephone_type, contact_point_purpose, primary_by_purpose,
                   url, email_format
              FROM xxd_ar_cont_point_dlt_stg_t apv
             WHERE     apv.orig_system_address_ref IS NULL
                   AND apv.orig_system_customer_ref = pn_customer_id
                   AND NVL (apv.orig_system_contact_ref, -1) =
                       NVL (p_contact_id, -1)
                   --        AND       p_address_id                             IS NULL
                   AND record_status = gc_validate_status
            UNION
            -- Customer Addresses Contacts Phones
            SELECT record_type, contact_attribute_category, contact_first_name,
                   contact_key, contact_last_name, contact_point_type,
                   contact_title, created_by, creation_date,
                   email_address, insert_update_flag, last_update_date,
                   last_update_login, last_updated_by, mail_stop,
                   org_id, orig_system_address_ref, orig_system_contact_ref,
                   orig_system_customer_ref, orig_system_telephone_ref, phone_country_code,
                   telephone, telephone_area_code, telephone_extension,
                   telephone_type, contact_point_purpose, primary_by_purpose,
                   url, email_format
              FROM xxd_ar_cont_point_dlt_stg_t apv
             WHERE     NVL (apv.orig_system_contact_ref, -1) =
                       NVL (p_contact_id, -1)
                   AND apv.orig_system_customer_ref = pn_customer_id
                   AND apv.orig_system_address_ref = NVL (p_address_id, -1)
                   AND apv.record_status = gc_validate_status;

        -- Check if Contact already exists
        CURSOR lcu_check_contact (p_orig_system_ref IN VARCHAR2)
        IS
            SELECT hrel.subject_id, hoc.org_contact_id
              FROM hz_org_contacts hoc, hz_relationships hrel
             WHERE     hoc.party_relationship_id = hrel.relationship_id
                   AND hrel.subject_type = 'PERSON'
                   AND hoc.orig_system_reference =
                       TO_CHAR (p_orig_system_ref);

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
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'SITE_USE_CODE'
                   AND enabled_flag = 'Y'
                   AND UPPER (lookup_code) = UPPER (p_responsibility_type);

        ln_role_resp_type       VARCHAR2 (1000);

        -- Cursor to fetch contact title from R12
        CURSOR lcu_get_contact_title (p_title VARCHAR2)
        IS
            SELECT flv.lookup_code title
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'CONTACT_TITLE'
                   AND flv.enabled_flag = 'Y'
                   AND UPPER (flv.meaning) = UPPER (p_title);

        lc_title                VARCHAR2 (100);

        --cursor to get job title code type from R12
        CURSOR lcu_job_title_code (p_job_title_code VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'RESPONSIBILITY'
                   AND enabled_flag = 'Y'
                   AND UPPER (lookup_code) = UPPER (p_job_title_code);

        lc_job_title_code       VARCHAR2 (1000);

        --Cusrsor to Check contact point already
        CURSOR lcu_contact_point_val (p_contact_point_id VARCHAR2, p_owner_table_name VARCHAR2, p_owner_table_id NUMBER)
        IS
            SELECT contact_point_id
              FROM hz_contact_points
             WHERE     1 = 1
                   AND orig_system_reference = TO_CHAR (p_contact_point_id)
                   AND owner_table_name = p_owner_table_name
                   AND owner_table_id = p_owner_table_id;

        CURSOR lcu_party_type (p_r12_party_id NUMBER)
        IS
            SELECT party_type
              FROM hz_parties
             WHERE party_id = p_r12_party_id;

        ln_contact_party_id     NUMBER := 0;
        ln_cont_point_id        NUMBER;
        ln_subject_id           NUMBER;
        ln_org_contact_id       NUMBER;
        ln_rel_party_id         NUMBER;
        lc_party_type           VARCHAR2 (250);
        ln_org_party_id         NUMBER;
        lx_contact_point_id     NUMBER;
        lx_msg                  VARCHAR2 (2000);
        lx_return_status        VARCHAR2 (10);

        lc_person_rec           hz_party_v2pub.person_rec_type;
        lc_org_contact_rec      hz_party_contact_v2pub.org_contact_rec_type;
        lc_cust_acct_role_rec   hz_cust_account_role_v2pub.cust_account_role_rec_type;
        lc_contactpt            hz_contact_point_v2pub.contact_point_rec_type;
        lc_phone_rec            hz_contact_point_v2pub.phone_rec_type;
        lc_email_rec            hz_contact_point_v2pub.email_rec_type;
        lc_web_rec              hz_contact_point_v2pub.web_rec_type;
    BEGIN
        log_records (p_debug     => gc_debug_flag,
                     p_message   => 'create_contacts_records ');
        log_records (p_debug     => gc_debug_flag,
                     p_message   => pn_customer_id || ' <=pn_customer_id ');
        log_records (p_debug     => gc_debug_flag,
                     p_message   => p_address_id || ' <=p_address_id ');

        FOR lrec_cust_contact
            IN lcu_cust_contact (pn_customer_id, p_address_id)
        LOOP
            ln_subject_id       := NULL;
            ln_org_contact_id   := NULL;
            gc_cust_contact     :=
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
                lrec_cust_contact.orig_system_contact_ref);

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
                    lrec_cust_contact.orig_system_contact_ref;
                lc_org_contact_rec.attribute_category                 :=
                    lrec_cust_contact.contact_attribute_category;
                lc_org_contact_rec.job_title_code                     :=
                    lc_job_title_code;
                lc_org_contact_rec.job_title                          :=
                    lrec_cust_contact.job_title;
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
                    p_cust_account_id;
                lc_cust_acct_role_rec.cust_acct_site_id               :=
                    p_cust_acct_site_id;
                lc_cust_acct_role_rec.role_type                       :=
                    'CONTACT';
                lc_cust_acct_role_rec.status                          := 'A';
                lc_cust_acct_role_rec.created_by_module               :=
                    'TCA_V1_API';
                create_cust_account_role (
                    p_cr_cust_acc_role_rec => lc_cust_acct_role_rec);

                ln_subject_id                                         :=
                    ln_contact_party_id;
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
                IN lcu_cust_cont_phones (
                       pn_customer_id,
                       p_address_id,
                       lrec_cust_contact.orig_system_contact_ref)
            LOOP
                log_records (p_debug     => gc_debug_flag,
                             p_message   => ' open lcu_cust_cont_phones');
                ln_rel_party_id                 := NULL;
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
                    ln_cont_point_id   := NULL;

                    OPEN lcu_contact_point_val (
                        lrec_cust_cont_phones.orig_system_telephone_ref,
                        lc_contactpt.owner_table_name,
                        ln_rel_party_id);

                    FETCH lcu_contact_point_val INTO ln_cont_point_id;

                    CLOSE lcu_contact_point_val;

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
                            lrec_cust_cont_phones.orig_system_telephone_ref;
                        log_records (
                            p_debug     => gc_debug_flag,
                            p_message   => ' Calling  create_contact_point ');
                        lx_return_status                     := 'S';
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
                    ELSE
                        lx_contact_point_id   := ln_cont_point_id;
                        lx_return_status      := 'S';
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
                        p_message   => ' upadte  XXD_AR_CONT_POINT_DLT_STG_T');

                    UPDATE xxd_ar_cont_point_dlt_stg_t
                       SET record_status   = gc_process_status
                     WHERE     NVL (orig_system_address_ref, -1) =
                               NVL (p_address_id, -1)
                           AND orig_system_customer_ref = pn_customer_id
                           AND orig_system_telephone_ref =
                               TO_NUMBER (
                                   lrec_cust_cont_phones.orig_system_telephone_ref);
                ELSE
                    log_records (
                        p_debug     => gc_debug_flag,
                        p_message   => 'Update XXD_AR_CONT_POINT_DLT_STG_T 2');

                    UPDATE xxd_ar_cont_point_dlt_stg_t
                       SET record_status   = gc_error_status
                     WHERE     NVL (orig_system_address_ref, -1) =
                               NVL (p_address_id, -1)
                           AND orig_system_customer_ref = pn_customer_id
                           AND orig_system_telephone_ref =
                               TO_NUMBER (
                                   lrec_cust_cont_phones.orig_system_telephone_ref);
                END IF;
            END LOOP;

            log_records (
                p_debug     => gc_debug_flag,
                p_message   => '   -- Creating customer and address phones 1 ');

            -- Creating customer and address contact phones
            FOR lrec_cust_cont_phones
                IN lcu_cust_cont_phones (pn_customer_id,
                                         p_address_id,
                                         lrec_cust_contact.contact_id)
            LOOP
                ln_rel_party_id                 := NULL;

                IF p_party_site_id IS NULL
                THEN
                    -- Deriving relationship id
                    OPEN lcu_rel_id (p_party_id, ln_contact_party_id);

                    FETCH lcu_rel_id INTO ln_rel_party_id;

                    CLOSE lcu_rel_id;
                ELSE
                    -- Deriving relationship party id
                    OPEN lcu_rel_party_id (ln_org_contact_id);

                    FETCH lcu_rel_party_id INTO ln_rel_party_id;

                    CLOSE lcu_rel_party_id;
                END IF;

                lc_contactpt.owner_table_name   := 'HZ_PARTIES';

                --to check cotact point already exists for contact person
                IF lrec_cust_cont_phones.orig_system_telephone_ref
                       IS NOT NULL
                THEN
                    ln_cont_point_id   := NULL;

                    OPEN lcu_contact_point_val (
                        lrec_cust_cont_phones.orig_system_telephone_ref,
                        lc_contactpt.owner_table_name,
                        ln_rel_party_id);

                    FETCH lcu_contact_point_val INTO ln_cont_point_id;

                    CLOSE lcu_contact_point_val;

                    IF ln_cont_point_id IS NULL
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
                        END IF;                                             --

                        lc_contactpt.orig_system_reference   :=
                            lrec_cust_cont_phones.orig_system_telephone_ref;
                        -- Calling API for creating Email Contact points
                        gc_cust_contact_point                :=
                            lrec_cust_cont_phones.contact_point_type;
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
                    ELSE
                        lx_contact_point_id   := ln_cont_point_id;
                        lx_return_status      := 'S';
                    END IF;
                END IF;

                IF     NVL (lx_contact_point_id, 0) > 0
                   AND lx_return_status = 'S'
                THEN
                    log_records (
                        p_debug     => gc_debug_flag,
                        p_message   => 'Update XXD_AR_CONT_POINT_DLT_STG_T 3');

                    UPDATE xxd_ar_cont_point_dlt_stg_t
                       SET record_status   = gc_process_status
                     WHERE     NVL (orig_system_address_ref, -1) =
                               NVL (p_address_id, -1)
                           AND orig_system_customer_ref = pn_customer_id
                           AND orig_system_telephone_ref =
                               lrec_cust_cont_phones.orig_system_telephone_ref;
                ELSE
                    log_records (
                        p_debug     => gc_debug_flag,
                        p_message   => 'Update XXD_AR_CONT_POINT_DLT_STG_T 4');

                    UPDATE xxd_ar_cont_point_dlt_stg_t
                       SET record_status   = gc_error_status
                     WHERE     NVL (orig_system_address_ref, -1) =
                               NVL (p_address_id, -1)
                           AND orig_system_customer_ref = pn_customer_id
                           AND orig_system_telephone_ref =
                               lrec_cust_cont_phones.orig_system_telephone_ref;
                END IF;
            END LOOP;

            IF NVL (ln_subject_id, 0) > 0 AND NVL (ln_org_contact_id, 0) > 0
            THEN
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Update XXD_AR_CONTACT_DLT_STG_T 1 ***'
                        || lrec_cust_contact.orig_system_contact_ref
                        || '*******');
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Update XXD_AR_CONTACT_DLT_STG_T 1 ***'
                        || p_address_id
                        || '*******');

                UPDATE xxd_ar_contact_dlt_stg_t
                   SET record_status   = gc_process_status
                 WHERE     orig_system_customer_ref = pn_customer_id
                       AND NVL (orig_system_address_ref, -1) =
                           NVL (p_address_id, -1)
                       AND orig_system_contact_ref =
                           TO_NUMBER (
                               lrec_cust_contact.orig_system_contact_ref);
            ELSE
                log_records (
                    p_debug     => gc_debug_flag,
                    p_message   => 'Update XXD_AR_CONTACT_DLT_STG_T 2');

                UPDATE xxd_ar_contact_dlt_stg_t
                   SET record_status   = gc_error_status
                 WHERE     orig_system_customer_ref = pn_customer_id
                       AND NVL (orig_system_address_ref, -1) =
                           NVL (p_address_id, -1)
                       AND orig_system_contact_ref =
                           lrec_cust_contact.orig_system_contact_ref;
            END IF;
        END LOOP;                                          -- Customer Contact

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
                        lrec_cust_phones.orig_system_telephone_ref,
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
                            lrec_cust_phones.orig_system_telephone_ref;

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
                    ELSE
                        lx_contact_point_id   := ln_cont_point_id;
                        lx_return_status      := 'S';
                    END IF;

                    IF     NVL (lx_contact_point_id, 0) > 0
                       AND lx_return_status = 'S'
                    THEN
                        log_records (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                'Update XXD_AR_CONT_POINT_DLT_STG_T 3');

                        UPDATE xxd_ar_cont_point_dlt_stg_t
                           SET record_status   = gc_process_status
                         WHERE     NVL (orig_system_address_ref, -1) =
                                   NVL (p_address_id, -1)
                               AND orig_system_customer_ref = pn_customer_id
                               AND orig_system_telephone_ref =
                                   lrec_cust_phones.orig_system_telephone_ref;
                    ELSE
                        log_records (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                'Update XXD_AR_CONT_POINT_DLT_STG_T 4');

                        UPDATE xxd_ar_cont_point_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE     NVL (orig_system_address_ref, -1) =
                                   NVL (p_address_id, -1)
                               AND orig_system_customer_ref = pn_customer_id
                               AND orig_system_telephone_ref =
                                   lrec_cust_phones.orig_system_telephone_ref;
                    END IF;
                END IF;
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

    FUNCTION get_gl_ccid (p_code_combination VARCHAR2)
        RETURN NUMBER
    IS
        ln_ccid     NUMBER := NULL;
        ln_coa_id   NUMBER := NULL;
    BEGIN
        log_records ('Y', p_code_combination);

        SELECT chart_of_accounts_id
          INTO ln_coa_id
          FROM gl_sets_of_books gcob, hr_operating_units hou
         WHERE     gcob.set_of_books_id = hou.set_of_books_id
               AND organization_id = gn_org_id;

        ln_ccid   :=
            fnd_flex_ext.get_ccid ('SQLGL',
                                   'GL#',
                                   ln_coa_id,
                                   TO_CHAR (SYSDATE, 'DD-MON-YYYY'),
                                   p_code_combination);
        log_records ('Y', ln_ccid);

        IF ln_ccid > 0
        THEN
            RETURN ln_ccid;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            log_records ('Y', SQLERRM);
            RETURN NULL;
        WHEN OTHERS
        THEN
            log_records ('Y', SQLERRM);
            RETURN NULL;
    END get_gl_ccid;

    PROCEDURE get_conc_code_combn (p_company VARCHAR2, p_brand_acc VARCHAR2, p_geo VARCHAR2, p_channel VARCHAR2, p_cost_center VARCHAR2, p_account VARCHAR2
                                   , p_intercompany VARCHAR2, p_future VARCHAR2, x_new_combination OUT VARCHAR2)
    IS
        lc_conc_code_combn   VARCHAR2 (100);
        l_n_segments         NUMBER := 8;
        l_delim              VARCHAR2 (1) := '.';
        l_segment_array      fnd_flex_ext.segmentarray;
        ln_coa_id            NUMBER;
        l_concat_segs        VARCHAR2 (32000);
    BEGIN
        l_segment_array (1)   := p_company;
        l_segment_array (2)   := p_brand_acc;
        l_segment_array (3)   := p_geo;
        l_segment_array (4)   := p_channel;
        l_segment_array (5)   := p_cost_center;
        l_segment_array (6)   := p_account;
        l_segment_array (7)   := p_intercompany;
        l_segment_array (8)   := p_future;

        x_new_combination     :=
            fnd_flex_ext.concatenate_segments (l_n_segments,
                                               l_segment_array,
                                               l_delim);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_new_combination   := NULL;
        WHEN OTHERS
        THEN
            x_new_combination   := NULL;
    END get_conc_code_combn;


    PROCEDURE create_cust_address (p_action IN VARCHAR2, p_customer_id IN NUMBER, p_new_party_id IN NUMBER
                                   , p_cust_account_id IN NUMBER)
    AS
        CURSOR address IS
            SELECT *
              FROM xxd_ar_cust_sites_dlt_stg_t
             WHERE customer_id = p_customer_id;

        l_location_rec         hz_location_v2pub.location_rec_type;
        l_party_site_rec       hz_party_site_v2pub.party_site_rec_type;
        l_cust_acct_site_rec   hz_cust_account_site_v2pub.cust_acct_site_rec_type;
        ln_location_id         NUMBER := NULL;
        ln_party_site_id       NUMBER := NULL;
        ln_cust_acct_site_id   NUMBER := NULL;
    BEGIN
        --    g_process               := 'create_billing_address';
        FOR location_dtl IN address
        LOOP
            ln_location_id         := NULL;
            ln_party_site_id       := NULL;
            ln_cust_acct_site_id   := NULL;

            BEGIN
                mo_global.init ('AR');
                --fnd_client_info.set_org_context (location_dtl.TARGET_ORG);
                mo_global.set_policy_context ('S', location_dtl.target_org);
                gn_org_id   := location_dtl.target_org;
            END;

            BEGIN
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Location id is  for the address  '
                        || UPPER (location_dtl.address1));
                gc_cust_address   := UPPER (location_dtl.address1);

                SELECT l.location_id
                  INTO ln_location_id
                  FROM hz_locations l
                 WHERE orig_system_reference =
                       TO_CHAR (location_dtl.address_id);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_location_id   := 0;
                    log_records (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               'Location id is not found for the address  '
                            || location_dtl.address1);
                WHEN OTHERS
                THEN
                    ln_location_id   := -1;
            END;

            IF (p_new_party_id > 0 AND ln_location_id > 0)
            THEN
                BEGIN
                    SELECT hzp.party_site_id
                      INTO ln_party_site_id
                      FROM hz_party_sites hzp
                     WHERE     hzp.location_id = ln_location_id
                           AND hzp.party_id = p_new_party_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_party_site_id   := 0;
                        log_records (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                ' hz_party_sites Party Site not found');
                END;

                IF (ln_party_site_id <> 0 AND p_cust_account_id <> 0)
                THEN
                    BEGIN
                        SELECT hc.cust_acct_site_id
                          INTO ln_cust_acct_site_id
                          FROM hz_cust_acct_sites_all hc
                         WHERE     cust_account_id = p_cust_account_id
                               AND party_site_id = ln_party_site_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_cust_acct_site_id   := 0;
                            log_records (
                                p_debug     => gc_debug_flag,
                                p_message   => ' Cust Site account Not found');
                    END;
                END IF;
            END IF;

            IF ln_cust_acct_site_id > 0
            THEN
                UPDATE xxd_ar_cust_sites_dlt_stg_t
                   SET record_status   = gc_process_status
                 WHERE     customer_id = location_dtl.customer_id
                       AND address_id = location_dtl.address_id;
            ELSE
                UPDATE xxd_ar_cust_sites_dlt_stg_t
                   SET record_status   = gc_error_status
                 WHERE     customer_id = location_dtl.customer_id
                       AND address_id = location_dtl.address_id;
            END IF;

            COMMIT;
            log_records (
                gc_debug_flag,
                ' Calling create_contacts_records for the address contacts  ');
            create_contacts_records (
                pn_customer_id        => p_customer_id,
                p_party_id            => p_new_party_id,
                p_address_id          => location_dtl.address_id,
                p_party_site_id       => ln_party_site_id,
                p_cust_account_id     => p_cust_account_id,
                p_cust_acct_site_id   => ln_cust_acct_site_id);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Exception in  create_cust_address procedure =>'
                    || SQLERRM);
    END create_cust_address;


    PROCEDURE create_cust_site_use (p_action IN VARCHAR2, p_customer_id IN NUMBER, p_party_type IN VARCHAR2, p_site_revenue_account IN VARCHAR2, p_site_freight_account IN VARCHAR2, p_site_tax_account IN VARCHAR2
                                    , p_site_unearn_rev_account IN VARCHAR2)
    AS
        CURSOR site_use IS
              SELECT *
                FROM xxd_ar_cust_siteuse_dlt_stg_t
               WHERE customer_id = p_customer_id AND record_status = p_action
            ORDER BY site_use_code;            -- To create Bill to site first

        l_cust_site_use_rec           hz_cust_account_site_v2pub.cust_site_use_rec_type;
        lr_customer_profile_rec       hz_customer_profile_v2pub.customer_profile_rec_type;
        ln_location_id                NUMBER := NULL;
        ln_party_site_id              NUMBER := NULL;
        ln_cust_acct_site_id          NUMBER := NULL;
        ln_cust_acct_site_use_id      NUMBER := NULL;
        ln_bto_site_use_id            NUMBER := NULL;
        lc_site_account               VARCHAR2 (2000) := NULL;

        -- Cursor to fetch the bill to site use id from R12
        CURSOR lcu_bto_site_use_id (p_customer_id       VARCHAR2,
                                    p_bto_site_use_id   VARCHAR2)
        IS
            /*SELECT hcsu.site_use_id
              FROM hz_cust_site_uses_all hcsu
             WHERE hcsu.orig_system_reference = TO_CHAR ( p_bto_site_use_id );*/
            SELECT hcsu.site_use_id
              FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas, hz_cust_accounts hca
             WHERE     hcas.cust_account_id = hca.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hca.orig_system_reference = p_customer_id
                   AND hcsu.orig_system_reference = p_bto_site_use_id
                   AND hca.status = 'A'
                   AND hcas.status = 'A'
                   AND hcsu.status = 'A';


        CURSOR lcu_cust_profile (pn_customer_id   NUMBER,
                                 pn_site_use_id   NUMBER)
        IS
            SELECT account_status, autocash_hierarchy_name, autocash_hierarchy_id,
                   autocash_hierarchy_name_adr, autocash_hierarchy_id_for_adr, auto_rec_incl_disputed_flag,
                   charge_on_finance_charge_flag, clearing_days, collector_name,
                   cons_inv_flag, cons_inv_type, site_use_id,
                   cons_bill_level, tolerance, discount_grace_days,
                   payment_grace_days, attribute1, attribute2,
                   created_by, creation_date, credit_rating,
                   credit_balance_statements, credit_checking, credit_hold,
                   customer_profile_class_name, discount_terms, dunning_letters,
                   dunning_letter_set_name, dunning_letter_set_id, grouping_rule_name,
                   grouping_rule_id, interest_charges, interest_period_days,
                   lockbox_matching_option, org_id, override_terms,
                   standard_terms_name, statements, statement_cycle_name,
                   tax_printing_option, insert_update_flag, last_updated_by,
                   last_update_date, last_update_login, orig_system_address_ref,
                   orig_system_customer_ref, customer_profile_id, credit_classification
              FROM xxd_ar_cust_prof_dlt_stg_t acpv
             WHERE     acpv.orig_system_customer_ref = pn_customer_id
                   AND acpv.site_use_id = pn_site_use_id
                   AND record_status = gc_validate_status
                   AND site_use_id IS NOT NULL;


        lr_cust_profile_rec           lcu_cust_profile%ROWTYPE;

        -- Cursor to fetch collector_id for collector_name
        CURSOR lcu_fetch_collector_id (p_collector_name VARCHAR2)
        IS
            SELECT ac.collector_id
              FROM ar_collectors ac
             WHERE     ac.status = 'A'
                   AND UPPER (ac.name) = UPPER (p_collector_name);

        -- Cursor for fetching profile_class_id
        CURSOR lcu_fetch_profile_class_id (
            p_prof_class_code hz_cust_profile_classes.name%TYPE)
        IS
            SELECT hcpc.profile_class_id
              FROM hz_cust_profile_classes hcpc
             WHERE hcpc.name = p_prof_class_code;

        CURSOR lcu_dunning_letter_set_id (p_dunning_letter_set_name VARCHAR2)
        IS
            SELECT dunning_letter_set_id
              FROM ar_dunning_letter_sets
             WHERE 1 = 1 AND UPPER (name) = UPPER (p_dunning_letter_set_name);

        --Cursor to get the statement cycle name
        CURSOR lcu_statement_cycle_id (p_statement_cycle_name VARCHAR2)
        IS
            SELECT statement_cycle_id
              FROM ar_statement_cycles
             WHERE name = p_statement_cycle_name;

        ln_statement_cycle_id         NUMBER;

        --cursor to get standard_terms_name from ra_customers attribute1
        CURSOR lcu_get_standard_terms_id (p_standard_terms_name VARCHAR2)
        IS
            --        SELECT  term_id    standard_terms_id
            --        FROM    ra_terms
            --        WHERE   UPPER(name)    = UPPER(p_standard_terms_name)
            SELECT rt.term_id payment_term_id
              FROM ra_terms rt, xxd_1206_payment_term_map_t xpt
             WHERE     1 = 1
                   AND UPPER (rt.name) = UPPER (xpt.new_term_name)
                   AND UPPER (xpt.old_term_name) =
                       UPPER (p_standard_terms_name);

        ln_standard_terms_id          VARCHAR2 (1000);

        -- Cursor to fetch grouping_rule_id from R12 using 11i grouping_rule_id
        CURSOR lcu_grouping_rule_id (p_grouping_rule_name VARCHAR2)
        IS
            SELECT grouping_rule_id
              FROM ra_grouping_rules
             WHERE 1 = 1 AND UPPER (name) = UPPER (p_grouping_rule_name);

        ln_grouping_rule_id           NUMBER;

        -- Cursor for fetching profile amounts
        CURSOR lcu_fetch_profile_amounts (p_cust_account_id   NUMBER,
                                          p_site_use_id       NUMBER)
        IS
            SELECT currency_code, trx_credit_limit, overall_credit_limit,
                   min_dunning_amount, min_dunning_invoice_amount, min_statement_amount,
                   site_use_id, interest_rate, min_fc_balance_amount,
                   min_fc_balance_overdue_type, attribute_category, attribute1,
                   attribute2, attribute3, attribute4,
                   attribute5, attribute6, attribute7,
                   attribute8, attribute9, attribute10,
                   attribute11, attribute12
              FROM xxd_ar_cust_profamt_dlt_stg_t
             WHERE     customer_id = p_cust_account_id
                   AND site_use_id = p_site_use_id;

        -- Cursor to fetch sales rep id from R12 using sales rep name
        CURSOR lcu_get_salesrep (pv_org_id NUMBER)
        IS
            SELECT jrs.salesrep_id salesrep_id
              FROM jtf_rs_salesreps jrs
             WHERE     1 = 1
                   AND jrs.name = 'No Sales Credit'
                   AND jrs.org_id = pv_org_id;

        -- Cursor to fetch Payment Term id from R12 using term name
        CURSOR lcu_get_term_id (pv_term_name VARCHAR2)
        IS
            --        SELECT RT.term_id      payment_term_id
            --        FROM   ra_terms  RT
            --        WHERE  1=1
            --        AND    UPPER(RT.name)     = UPPER(pv_term_name)
            SELECT rt.term_id payment_term_id
              FROM ra_terms rt, xxd_1206_payment_term_map_t xpt
             WHERE     1 = 1
                   AND UPPER (rt.name) = UPPER (xpt.new_term_name)
                   AND UPPER (xpt.old_term_name) = UPPER (pv_term_name);

        -- Cursor to fetch Price List id from R12
        --        CURSOR lcu_get_price_list_id( p_price_list_name VARCHAR2)
        --        IS
        --        SELECT OEPLR12.price_list_id      price_list_id
        --        FROM   oe_price_lists_vl          OEPLR12
        --        WHERE  1=1
        --        AND    OEPLR12.name         =  p_price_list_name
        --        ;

        -- Cursor to fetch Order type id from R12
        CURSOR lcur_order_type_id (p_order_type_name VARCHAR2)
        IS
            SELECT ottt12.transaction_type_id order_type_id
              FROM oe_transaction_types_tl ottt12, xxd_1206_order_type_map_t xtt
             WHERE     ottt12.name = xtt.new_12_2_3_name
                   AND legacy_12_0_6_name = p_order_type_name
                   AND language = 'US';

        -- Cursor to fetch Price List id from R12
        --        CURSOR lcu_get_price_list_id( p_price_list_name VARCHAR2)
        --        IS
        --        SELECT OEPLR12.price_list_id      price_list_id
        --        FROM   oe_price_lists_vl          OEPLR12
        --        WHERE  1=1
        --        AND    OEPLR12.name         =  p_price_list_name
        --        ;
        CURSOR lcu_get_price_list_id (p_price_list_name VARCHAR2)
        IS
            SELECT oeplr12.price_list_id price_list_id
              --              ,OEPLR12.name               price_list_name
              FROM oe_price_lists_vl oeplr12, xxd_1206_price_list_map_t xqph
             WHERE     1 = 1
                   AND oeplr12.name = xqph.pricelist_new_name
                   AND legacy_pricelist_name = p_price_list_name;

        lr_get_price_list             lcu_get_price_list_id%ROWTYPE;

        CURSOR lcu_get_ship_via (p_ship_via VARCHAR2)
        IS
            SELECT wcs.ship_method_code
              FROM xxd_conv.xxd_1206_ship_methods_map_t lsm, wsh_carrier_ship_methods wcs
             WHERE     old_ship_method_code = p_ship_via
                   AND ship_method_code = new_ship_method_code
                   AND ROWNUM = 1;

        CURSOR get_price_list_id (
            p_price_list_name IN oe_price_lists_vl.name%TYPE)
        IS
            SELECT oplv.price_list_id price_list_id
              FROM oe_price_lists_vl oplv
             WHERE oplv.name = p_price_list_name;


        TYPE lt_site_use_typ IS TABLE OF site_use%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_site_use_data              lt_site_use_typ;

        ln_collector_id               NUMBER;
        ln_profile_class_id           NUMBER;
        lx_profile_id                 NUMBER;
        ln_cust_acct_profile_amt_id   NUMBER;
        ln_stmt_cycle_id              NUMBER;
        ln_dunning_letter_set_id      NUMBER;
        l_cpamt_rec                   hz_customer_profile_v2pub.cust_profile_amt_rec_type;
        ln_cnt                        NUMBER := 0;
        lc_distribution_channel       VARCHAR2 (250);
        x_return_status               VARCHAR2 (10);
    BEGIN
        log_records (p_debug     => gc_debug_flag,
                     p_message   => 'Calling create_cust_site_use');

        -- FOR sites_dtl IN site_use LOOP
        OPEN site_use;

        LOOP
            --      SAVEPOINT INSERT_TABLE2;
            FETCH site_use BULK COLLECT INTO lt_site_use_data LIMIT 50;

            EXIT WHEN lt_site_use_data.COUNT = 0;

            IF lt_site_use_data.COUNT > 0
            THEN
                FOR xc_site_use_idx IN lt_site_use_data.FIRST ..
                                       lt_site_use_data.LAST
                LOOP
                    ln_location_id             := NULL;
                    l_cust_site_use_rec        := NULL;
                    lc_site_account            := NULL;
                    gc_cust_site_use           :=
                        lt_site_use_data (xc_site_use_idx).site_use_code;

                    BEGIN
                        mo_global.init ('AR');
                        --fnd_client_info.set_org_context (location_dtl.TARGET_ORG);
                        mo_global.set_policy_context (
                            'S',
                            lt_site_use_data (xc_site_use_idx).target_org);
                        gn_org_id   :=
                            lt_site_use_data (xc_site_use_idx).target_org;
                    END;

                    log_records (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               ' cust acccount site use for  lt_site_use_data(xc_site_use_idx).cust_acct_site_id => '
                            || TO_CHAR (
                                   lt_site_use_data (xc_site_use_idx).cust_acct_site_id));

                    BEGIN
                        ln_cust_acct_site_id   := 0;

                        SELECT hc.cust_acct_site_id, party_site_id
                          INTO ln_cust_acct_site_id, ln_party_site_id
                          FROM hz_cust_acct_sites_all hc
                         WHERE     hc.orig_system_reference =
                                   TO_CHAR (
                                       lt_site_use_data (xc_site_use_idx).cust_acct_site_id)
                               AND created_by_module = 'TCA_V1_API';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_cust_acct_site_id   := 0;
                            log_records (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       ' cust acccount site use not found'
                                    || SQLERRM);
                    END;

                    log_records (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               ' cust acccount site use for  ln_cust_acct_site_id => '
                            || ln_cust_acct_site_id);

                    ln_cust_acct_site_use_id   := 0;

                    IF (ln_cust_acct_site_id <> 0)
                    THEN
                        BEGIN
                            SELECT hc.site_use_id
                              INTO ln_cust_acct_site_use_id
                              FROM hz_cust_site_uses_all hc
                             WHERE     hc.cust_acct_site_id =
                                       ln_cust_acct_site_id
                                   AND hc.site_use_code =
                                       lt_site_use_data (xc_site_use_idx).site_use_code;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                        'Site use not found ' || SQLERRM);
                                ln_cust_acct_site_use_id   := 0;
                        END;

                        log_records (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                   ' cust acccount site use for  ln_cust_acct_site_use_id => '
                                || ln_cust_acct_site_use_id);

                        IF (ln_cust_acct_site_use_id = 0)
                        THEN
                            l_cust_site_use_rec.cust_acct_site_id   :=
                                ln_cust_acct_site_id;

                            OPEN lcur_order_type_id (
                                p_order_type_name   =>
                                    lt_site_use_data (xc_site_use_idx).order_type_name);

                            FETCH lcur_order_type_id
                                INTO l_cust_site_use_rec.order_type_id;

                            CLOSE lcur_order_type_id;

                            OPEN lcu_get_price_list_id (
                                p_price_list_name   =>
                                    lt_site_use_data (xc_site_use_idx).price_list_name);

                            FETCH lcu_get_price_list_id
                                INTO l_cust_site_use_rec.price_list_id;

                            CLOSE lcu_get_price_list_id;

                            l_cust_site_use_rec.location   :=
                                lt_site_use_data (xc_site_use_idx).location;
                            l_cust_site_use_rec.org_id   :=
                                lt_site_use_data (xc_site_use_idx).target_org;

                            OPEN lcu_get_ship_via (
                                p_ship_via   =>
                                    lt_site_use_data (xc_site_use_idx).ship_via);

                            FETCH lcu_get_ship_via
                                INTO l_cust_site_use_rec.ship_via;

                            CLOSE lcu_get_ship_via;

                            --<<value for cust_acct_site_id from step 5>
                            l_cust_site_use_rec.site_use_code   :=
                                lt_site_use_data (xc_site_use_idx).site_use_code;
                            l_cust_site_use_rec.orig_system_reference   :=
                                lt_site_use_data (xc_site_use_idx).site_use_id;

                            IF     lt_site_use_data (xc_site_use_idx).site_use_code =
                                   'BILL_TO'
                               AND p_party_type = 'ECOMMERCE'
                            THEN
                                l_cust_site_use_rec.gl_id_rev   :=
                                    get_gl_ccid (
                                        p_code_combination   =>
                                            p_site_revenue_account);
                                l_cust_site_use_rec.gl_id_unearned   :=
                                    get_gl_ccid (
                                        p_code_combination   =>
                                            p_site_unearn_rev_account);
                                l_cust_site_use_rec.gl_id_tax   :=
                                    get_gl_ccid (
                                        p_code_combination   =>
                                            p_site_tax_account);
                                l_cust_site_use_rec.gl_id_freight   :=
                                    get_gl_ccid (
                                        p_code_combination   =>
                                            p_site_freight_account);
                            ELSE
                                IF     lt_site_use_data (xc_site_use_idx).site_use_code =
                                       'BILL_TO'
                                   AND NVL (p_party_type, 'XXXX') <>
                                       'ECOMMERCE'
                                THEN
                                    IF NVL (
                                           lt_site_use_data (xc_site_use_idx).primary_flag,
                                           'N') =
                                       'Y'
                                    THEN
                                        l_cust_site_use_rec.primary_flag   :=
                                            lt_site_use_data (
                                                xc_site_use_idx).primary_flag;
                                    END IF;


                                    FOR lc_acc
                                        IN (SELECT account_type, company, brand_acc,
                                                   geo, channel, cost_center,
                                                   account, intercompany, future
                                              FROM xxd_cust_gl_acc_segment_map_t xga, hz_cust_accounts_all hca
                                             WHERE     xga.customer_number =
                                                       hca.account_number
                                                   AND hca.cust_account_id =
                                                       p_customer_id)
                                    LOOP
                                        BEGIN
                                            get_conc_code_combn (
                                                p_company   => lc_acc.company,
                                                p_brand_acc   =>
                                                    lc_acc.brand_acc,
                                                p_geo       => lc_acc.geo,
                                                p_channel   => lc_acc.channel,
                                                p_cost_center   =>
                                                    lc_acc.cost_center,
                                                p_account   => lc_acc.account,
                                                p_intercompany   =>
                                                    lc_acc.intercompany,
                                                p_future    => lc_acc.future,
                                                x_new_combination   =>
                                                    lc_site_account);

                                            IF lc_site_account IS NOT NULL
                                            THEN
                                                IF lc_acc.account_type =
                                                   'Receivables'
                                                THEN
                                                    l_cust_site_use_rec.gl_id_rec   :=
                                                        get_gl_ccid (
                                                            p_code_combination   =>
                                                                lc_site_account);
                                                ELSIF lc_acc.account_type =
                                                      'Revenue'
                                                THEN
                                                    l_cust_site_use_rec.gl_id_rev   :=
                                                        get_gl_ccid (
                                                            p_code_combination   =>
                                                                lc_site_account);
                                                ELSIF lc_acc.account_type =
                                                      'Unearned Revenue'
                                                THEN
                                                    l_cust_site_use_rec.gl_id_unearned   :=
                                                        get_gl_ccid (
                                                            p_code_combination   =>
                                                                lc_site_account);
                                                END IF;
                                            END IF;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                lc_site_account   := NULL;
                                                l_cust_site_use_rec.gl_id_rev   :=
                                                    NULL;
                                                l_cust_site_use_rec.gl_id_rec   :=
                                                    NULL;
                                                l_cust_site_use_rec.gl_id_unearned   :=
                                                    NULL;
                                        END;
                                    END LOOP;

                                    FOR lc_acc
                                        IN (SELECT rev_company, rev_brand, rev_geo,
                                                   rev_channel, rev_cost_center, rev_account,
                                                   rev_intercompany, rev_future, rec_company,
                                                   rec_brand, rec_geo, rec_channel,
                                                   rec_cost_center, rec_account, rec_intercompany,
                                                   rec_future, distribution_channel, rsa.salesrep_id,
                                                   price_list
                                              FROM xxd_ret_n_int_cust_map xga, hz_cust_accounts_all hca, ra_salesreps_all rsa,
                                                   hr_operating_units hou
                                             WHERE     xga.customer_number =
                                                       hca.account_number
                                                   AND rsa.name(+) =
                                                       xga.salesrep
                                                   AND rsa.org_id(+) =
                                                       lt_site_use_data (
                                                           xc_site_use_idx).target_org
                                                   AND xga.organization_name =
                                                       hou.name
                                                   AND hou.organization_id =
                                                       lt_site_use_data (
                                                           xc_site_use_idx).target_org
                                                   AND hca.cust_account_id =
                                                       p_customer_id)
                                    LOOP
                                        lc_distribution_channel   :=
                                            lc_acc.distribution_channel;

                                        BEGIN
                                            get_conc_code_combn (
                                                p_company   =>
                                                    lc_acc.rev_company,
                                                p_brand_acc   =>
                                                    lc_acc.rev_brand,
                                                p_geo   => lc_acc.rev_geo,
                                                p_channel   =>
                                                    lc_acc.rev_channel,
                                                p_cost_center   =>
                                                    lc_acc.rev_cost_center,
                                                p_account   =>
                                                    lc_acc.rev_account,
                                                p_intercompany   =>
                                                    lc_acc.rev_intercompany,
                                                p_future   =>
                                                    lc_acc.rev_future,
                                                x_new_combination   =>
                                                    lc_site_account);

                                            IF lc_site_account IS NOT NULL
                                            THEN
                                                l_cust_site_use_rec.gl_id_rev   :=
                                                    get_gl_ccid (
                                                        p_code_combination   =>
                                                            lc_site_account);
                                            END IF;

                                            get_conc_code_combn (
                                                p_company   =>
                                                    lc_acc.rec_company,
                                                p_brand_acc   =>
                                                    lc_acc.rec_brand,
                                                p_geo   => lc_acc.rec_geo,
                                                p_channel   =>
                                                    lc_acc.rec_channel,
                                                p_cost_center   =>
                                                    lc_acc.rec_cost_center,
                                                p_account   =>
                                                    lc_acc.rec_account,
                                                p_intercompany   =>
                                                    lc_acc.rec_intercompany,
                                                p_future   =>
                                                    lc_acc.rec_future,
                                                x_new_combination   =>
                                                    lc_site_account);

                                            IF lc_site_account IS NOT NULL
                                            THEN
                                                l_cust_site_use_rec.gl_id_rec   :=
                                                    get_gl_ccid (
                                                        p_code_combination   =>
                                                            lc_site_account);
                                            END IF;

                                            l_cust_site_use_rec.gl_id_unearned   :=
                                                l_cust_site_use_rec.gl_id_rev;
                                            l_cust_site_use_rec.primary_salesrep_id   :=
                                                lc_acc.salesrep_id;

                                            IF lc_acc.price_list IS NOT NULL
                                            THEN
                                                OPEN get_price_list_id (
                                                    lc_acc.price_list);

                                                FETCH get_price_list_id
                                                    INTO l_cust_site_use_rec.price_list_id;

                                                CLOSE get_price_list_id;
                                            END IF;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                lc_site_account   := NULL;
                                                l_cust_site_use_rec.gl_id_rev   :=
                                                    NULL;
                                                l_cust_site_use_rec.gl_id_rec   :=
                                                    NULL;
                                                l_cust_site_use_rec.gl_id_unearned   :=
                                                    NULL;

                                                log_records (
                                                    p_debug   => gc_debug_flag,
                                                    p_message   =>
                                                           ' SITE lc_distribution_channel => '
                                                        || SQLERRM);
                                        END;
                                    END LOOP;

                                    l_cust_site_use_rec.gl_id_tax   := NULL;
                                    l_cust_site_use_rec.gl_id_freight   :=
                                        NULL;
                                END IF;
                            END IF;

                            l_cust_site_use_rec.created_by_module   :=
                                'TCA_V1_API';

                            log_records (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       ' SITE lc_distribution_channel => '
                                    || lc_distribution_channel);

                            IF lt_site_use_data (xc_site_use_idx).bill_to_site_use_id
                                   IS NOT NULL
                            --AND ( NVL ( p_party_type, 'XXXX' ) = 'ECOMMERCE' OR lc_distribution_channel = 'RETAIL' )
                            THEN
                                ln_bto_site_use_id   := NULL;

                                OPEN lcu_bto_site_use_id (
                                    lt_site_use_data (xc_site_use_idx).customer_id,
                                    lt_site_use_data (xc_site_use_idx).bill_to_site_use_id);

                                FETCH lcu_bto_site_use_id
                                    INTO ln_bto_site_use_id;

                                CLOSE lcu_bto_site_use_id;

                                log_records (
                                    p_debug   => gc_debug_flag,
                                    p_message   =>
                                           ' SITE ln_bto_site_use_id => '
                                        || ln_bto_site_use_id);

                                l_cust_site_use_rec.bill_to_site_use_id   :=
                                    ln_bto_site_use_id;

                                IF l_cust_site_use_rec.bill_to_site_use_id
                                       IS NULL
                                THEN
                                    log_records (
                                        p_debug   => gc_debug_flag,
                                        p_message   =>
                                               ' Unable to derive bill to site used Id from R12 for 11i bill to site use id '
                                            || lt_site_use_data (
                                                   xc_site_use_idx).bill_to_site_use_id);
                                END IF;
                            ELSE
                                l_cust_site_use_rec.bill_to_site_use_id   :=
                                    NULL;
                            END IF;

                            -----------------------profiles--------------------
                            IF gc_cust_site_use = 'BILL_TO'
                            THEN
                                OPEN lcu_cust_profile (
                                    lt_site_use_data (xc_site_use_idx).customer_id,
                                    lt_site_use_data (xc_site_use_idx).site_use_id);

                                FETCH lcu_cust_profile
                                    INTO lr_cust_profile_rec;

                                CLOSE lcu_cust_profile;

                                IF lr_cust_profile_rec.site_use_id
                                       IS NOT NULL
                                THEN
                                    --Fetching profile class id
                                    OPEN lcu_fetch_profile_class_id (
                                        lr_cust_profile_rec.customer_profile_class_name);

                                    FETCH lcu_fetch_profile_class_id
                                        INTO ln_profile_class_id;

                                    CLOSE lcu_fetch_profile_class_id;

                                    IF ln_profile_class_id IS NULL
                                    THEN
                                        NULL;                    -- validation
                                    END IF;

                                    lr_customer_profile_rec   := NULL;
                                    lr_customer_profile_rec.profile_class_id   :=
                                        ln_profile_class_id;

                                    lr_customer_profile_rec   := NULL;

                                    IF lr_cust_profile_rec.customer_profile_id
                                           IS NOT NULL
                                    THEN
                                        ln_collector_id            := NULL;

                                        IF lr_cust_profile_rec.collector_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_fetch_collector_id (
                                                lr_cust_profile_rec.collector_name);

                                            FETCH lcu_fetch_collector_id
                                                INTO ln_collector_id;

                                            CLOSE lcu_fetch_collector_id;

                                            IF ln_collector_id IS NULL
                                            THEN
                                                log_records (
                                                    gc_debug_flag,
                                                       ' Collector Name (Site level) '
                                                    || lr_cust_profile_rec.collector_name
                                                    || ' not setup in R12 ');
                                            END IF;
                                        END IF;

                                        ln_dunning_letter_set_id   := NULL;

                                        IF lr_cust_profile_rec.dunning_letter_set_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_dunning_letter_set_id (
                                                lr_cust_profile_rec.dunning_letter_set_name);

                                            FETCH lcu_dunning_letter_set_id
                                                INTO ln_dunning_letter_set_id;

                                            CLOSE lcu_dunning_letter_set_id;

                                            IF ln_dunning_letter_set_id
                                                   IS NULL
                                            THEN
                                                NULL; --ln_dunning_letter_set_id validation
                                            END IF;
                                        END IF;

                                        ln_statement_cycle_id      := NULL;

                                        IF lr_cust_profile_rec.statement_cycle_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_statement_cycle_id (
                                                lr_cust_profile_rec.statement_cycle_name);

                                            FETCH lcu_statement_cycle_id
                                                INTO ln_statement_cycle_id;

                                            CLOSE lcu_statement_cycle_id;

                                            IF ln_statement_cycle_id IS NULL
                                            THEN
                                                NULL;
                                            END IF;
                                        END IF;

                                        ln_grouping_rule_id        := NULL;

                                        IF lr_cust_profile_rec.grouping_rule_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_grouping_rule_id (
                                                lr_cust_profile_rec.grouping_rule_name);

                                            FETCH lcu_grouping_rule_id
                                                INTO ln_grouping_rule_id;

                                            CLOSE lcu_grouping_rule_id;

                                            IF ln_grouping_rule_id IS NULL
                                            THEN
                                                NULL;
                                            END IF;
                                        END IF;

                                        ln_standard_terms_id       := NULL;

                                        IF lr_cust_profile_rec.standard_terms_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_get_standard_terms_id (
                                                lr_cust_profile_rec.standard_terms_name);

                                            FETCH lcu_get_standard_terms_id
                                                INTO ln_standard_terms_id;

                                            CLOSE lcu_get_standard_terms_id;

                                            IF ln_standard_terms_id IS NULL
                                            THEN
                                                NULL;        --raise the error
                                            END IF;
                                        END IF;

                                        lr_customer_profile_rec.profile_class_id   :=
                                            ln_profile_class_id;
                                        lr_customer_profile_rec.cust_account_id   :=
                                            lt_site_use_data (
                                                xc_site_use_idx).customer_id;
                                        lr_customer_profile_rec.site_use_id   :=
                                            lt_site_use_data (
                                                xc_site_use_idx).site_use_id;
                                        lr_customer_profile_rec.collector_id   :=
                                            ln_collector_id;
                                        lr_customer_profile_rec.account_status   :=
                                            lr_cust_profile_rec.account_status;
                                        lr_customer_profile_rec.auto_rec_incl_disputed_flag   :=
                                            lr_cust_profile_rec.auto_rec_incl_disputed_flag;
                                        lr_customer_profile_rec.charge_on_finance_charge_flag   :=
                                            lr_cust_profile_rec.charge_on_finance_charge_flag;
                                        lr_customer_profile_rec.clearing_days   :=
                                            lr_cust_profile_rec.clearing_days;
                                        lr_customer_profile_rec.credit_balance_statements   :=
                                            lr_cust_profile_rec.credit_balance_statements;
                                        lr_customer_profile_rec.credit_checking   :=
                                            lr_cust_profile_rec.credit_checking;

                                        IF lr_cust_profile_rec.cons_inv_flag =
                                           'Y'
                                        THEN
                                            lr_customer_profile_rec.cons_inv_flag   :=
                                                lr_cust_profile_rec.cons_inv_flag;
                                            lr_customer_profile_rec.cons_inv_type   :=
                                                lr_cust_profile_rec.cons_inv_type;
                                            lr_customer_profile_rec.cons_bill_level   :=
                                                lr_cust_profile_rec.cons_bill_level;
                                        ELSE
                                            lr_customer_profile_rec.cons_inv_flag   :=
                                                NULL;
                                            lr_customer_profile_rec.cons_inv_type   :=
                                                NULL;
                                            lr_customer_profile_rec.cons_bill_level   :=
                                                NULL;
                                        END IF;

                                        lr_customer_profile_rec.tolerance   :=
                                            lr_cust_profile_rec.tolerance;
                                        lr_customer_profile_rec.discount_grace_days   :=
                                            lr_cust_profile_rec.discount_grace_days;
                                        lr_customer_profile_rec.payment_grace_days   :=
                                            lr_cust_profile_rec.payment_grace_days;
                                        lr_customer_profile_rec.attribute1   :=
                                            lr_cust_profile_rec.attribute1;
                                        lr_customer_profile_rec.attribute2   :=
                                            lr_cust_profile_rec.attribute2;
                                        lr_customer_profile_rec.credit_hold   :=
                                            lr_cust_profile_rec.credit_hold;
                                        lr_customer_profile_rec.credit_rating   :=
                                            lr_cust_profile_rec.credit_rating;
                                        lr_customer_profile_rec.dunning_letters   :=
                                            lr_cust_profile_rec.dunning_letters;
                                        lr_customer_profile_rec.dunning_letter_set_id   :=
                                            ln_dunning_letter_set_id;
                                        lr_customer_profile_rec.grouping_rule_id   :=
                                            ln_grouping_rule_id;
                                        lr_customer_profile_rec.interest_period_days   :=
                                            lr_cust_profile_rec.interest_period_days;
                                        lr_customer_profile_rec.lockbox_matching_option   :=
                                            lr_cust_profile_rec.lockbox_matching_option;
                                        lr_customer_profile_rec.interest_charges   :=
                                            lr_cust_profile_rec.interest_charges;
                                        lr_customer_profile_rec.discount_terms   :=
                                            lr_cust_profile_rec.discount_terms;
                                        lr_customer_profile_rec.override_terms   :=
                                            lr_cust_profile_rec.override_terms;
                                        lr_customer_profile_rec.tax_printing_option   :=
                                            lr_cust_profile_rec.tax_printing_option;
                                        lr_customer_profile_rec.send_statements   :=
                                            lr_cust_profile_rec.statements;
                                        lr_customer_profile_rec.statement_cycle_id   :=
                                            ln_statement_cycle_id;
                                        lr_customer_profile_rec.standard_terms   :=
                                            ln_standard_terms_id;
                                        lr_customer_profile_rec.credit_classification   :=
                                            lr_cust_profile_rec.credit_classification;
                                        lr_customer_profile_rec.created_by_module   :=
                                            'TCA_V1_API';
                                    END IF;
                                END IF;         --gc_cust_site_use = 'BILL_TO'
                            ELSE
                                -- lr_cust_profile_rec.site_use_id IS NULL
                                lr_customer_profile_rec   := NULL;
                            END IF; -- lr_cust_profile_rec.site_use_id IS NOT NULL

                            log_records (
                                p_debug     => gc_debug_flag,
                                p_message   => 'Calling create_cust_site_use');
                            create_cust_site_use (
                                p_cust_site_use_rec   => l_cust_site_use_rec,
                                p_customer_profile_rec   =>
                                    lr_customer_profile_rec,
                                v_cust_acct_site_use_id   =>
                                    ln_cust_acct_site_use_id);
                            log_records (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       'Site use created create_cust_site_use=> '
                                    || ln_cust_acct_site_use_id);
                        ELSE
                            BEGIN
                                SELECT cust_account_profile_id
                                  INTO lx_profile_id
                                  FROM hz_customer_profiles
                                 WHERE     cust_account_id = p_customer_id
                                       AND site_use_id =
                                           ln_cust_acct_site_use_id
                                       AND status = 'A';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lx_profile_id   := 0;
                            END;

                            IF     gc_cust_site_use = 'BILL_TO'
                               AND lx_profile_id = 0
                            THEN
                                OPEN lcu_cust_profile (
                                    lt_site_use_data (xc_site_use_idx).customer_id,
                                    lt_site_use_data (xc_site_use_idx).site_use_id);

                                FETCH lcu_cust_profile
                                    INTO lr_cust_profile_rec;

                                CLOSE lcu_cust_profile;

                                IF lr_cust_profile_rec.site_use_id
                                       IS NOT NULL
                                THEN
                                    --Fetching profile class id
                                    OPEN lcu_fetch_profile_class_id (
                                        lr_cust_profile_rec.customer_profile_class_name);

                                    FETCH lcu_fetch_profile_class_id
                                        INTO ln_profile_class_id;

                                    CLOSE lcu_fetch_profile_class_id;

                                    IF ln_profile_class_id IS NULL
                                    THEN
                                        NULL;                    -- validation
                                    END IF;

                                    lr_customer_profile_rec   := NULL;

                                    IF lr_cust_profile_rec.customer_profile_id
                                           IS NOT NULL
                                    THEN
                                        ln_collector_id            := NULL;

                                        IF lr_cust_profile_rec.collector_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_fetch_collector_id (
                                                lr_cust_profile_rec.collector_name);

                                            FETCH lcu_fetch_collector_id
                                                INTO ln_collector_id;

                                            CLOSE lcu_fetch_collector_id;

                                            IF ln_collector_id IS NULL
                                            THEN
                                                log_records (
                                                    gc_debug_flag,
                                                       ' Collector Name (Site level) '
                                                    || lr_cust_profile_rec.collector_name
                                                    || ' not setup in R12 ');
                                            END IF;
                                        END IF;

                                        ln_dunning_letter_set_id   := NULL;

                                        IF lr_cust_profile_rec.dunning_letter_set_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_dunning_letter_set_id (
                                                lr_cust_profile_rec.dunning_letter_set_name);

                                            FETCH lcu_dunning_letter_set_id
                                                INTO ln_dunning_letter_set_id;

                                            CLOSE lcu_dunning_letter_set_id;

                                            IF ln_dunning_letter_set_id
                                                   IS NULL
                                            THEN
                                                NULL; --ln_dunning_letter_set_id validation
                                            END IF;
                                        END IF;

                                        ln_statement_cycle_id      := NULL;

                                        IF lr_cust_profile_rec.statement_cycle_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_statement_cycle_id (
                                                lr_cust_profile_rec.statement_cycle_name);

                                            FETCH lcu_statement_cycle_id
                                                INTO ln_statement_cycle_id;

                                            CLOSE lcu_statement_cycle_id;

                                            IF ln_statement_cycle_id IS NULL
                                            THEN
                                                NULL;
                                            END IF;
                                        END IF;

                                        ln_grouping_rule_id        := NULL;

                                        IF lr_cust_profile_rec.grouping_rule_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_grouping_rule_id (
                                                lr_cust_profile_rec.grouping_rule_name);

                                            FETCH lcu_grouping_rule_id
                                                INTO ln_grouping_rule_id;

                                            CLOSE lcu_grouping_rule_id;

                                            IF ln_grouping_rule_id IS NULL
                                            THEN
                                                NULL;
                                            END IF;
                                        END IF;

                                        ln_standard_terms_id       := NULL;

                                        IF lr_cust_profile_rec.standard_terms_name
                                               IS NOT NULL
                                        THEN
                                            OPEN lcu_get_standard_terms_id (
                                                lr_cust_profile_rec.standard_terms_name);

                                            FETCH lcu_get_standard_terms_id
                                                INTO ln_standard_terms_id;

                                            CLOSE lcu_get_standard_terms_id;

                                            IF ln_standard_terms_id IS NULL
                                            THEN
                                                NULL;        --raise the error
                                            END IF;
                                        END IF;

                                        lr_customer_profile_rec.profile_class_id   :=
                                            ln_profile_class_id;
                                        lr_customer_profile_rec.cust_account_id   :=
                                            p_customer_id;
                                        lr_customer_profile_rec.site_use_id   :=
                                            ln_cust_acct_site_use_id;
                                        lr_customer_profile_rec.collector_id   :=
                                            ln_collector_id;
                                        lr_customer_profile_rec.account_status   :=
                                            lr_cust_profile_rec.account_status;
                                        lr_customer_profile_rec.auto_rec_incl_disputed_flag   :=
                                            lr_cust_profile_rec.auto_rec_incl_disputed_flag;
                                        lr_customer_profile_rec.charge_on_finance_charge_flag   :=
                                            lr_cust_profile_rec.charge_on_finance_charge_flag;
                                        lr_customer_profile_rec.clearing_days   :=
                                            lr_cust_profile_rec.clearing_days;
                                        lr_customer_profile_rec.credit_balance_statements   :=
                                            lr_cust_profile_rec.credit_balance_statements;
                                        lr_customer_profile_rec.credit_checking   :=
                                            lr_cust_profile_rec.credit_checking;

                                        IF lr_cust_profile_rec.cons_inv_flag =
                                           'Y'
                                        THEN
                                            lr_customer_profile_rec.cons_inv_flag   :=
                                                lr_cust_profile_rec.cons_inv_flag;
                                            lr_customer_profile_rec.cons_inv_type   :=
                                                lr_cust_profile_rec.cons_inv_type;
                                            lr_customer_profile_rec.cons_bill_level   :=
                                                lr_cust_profile_rec.cons_bill_level;
                                        ELSE
                                            lr_customer_profile_rec.cons_inv_flag   :=
                                                NULL;
                                            lr_customer_profile_rec.cons_inv_type   :=
                                                NULL;
                                            lr_customer_profile_rec.cons_bill_level   :=
                                                NULL;
                                        END IF;

                                        lr_customer_profile_rec.tolerance   :=
                                            lr_cust_profile_rec.tolerance;
                                        lr_customer_profile_rec.discount_grace_days   :=
                                            lr_cust_profile_rec.discount_grace_days;
                                        lr_customer_profile_rec.payment_grace_days   :=
                                            lr_cust_profile_rec.payment_grace_days;
                                        lr_customer_profile_rec.attribute1   :=
                                            lr_cust_profile_rec.attribute1;
                                        lr_customer_profile_rec.attribute2   :=
                                            lr_cust_profile_rec.attribute2;
                                        lr_customer_profile_rec.credit_hold   :=
                                            lr_cust_profile_rec.credit_hold;
                                        lr_customer_profile_rec.credit_rating   :=
                                            lr_cust_profile_rec.credit_rating;
                                        lr_customer_profile_rec.dunning_letters   :=
                                            lr_cust_profile_rec.dunning_letters;
                                        lr_customer_profile_rec.dunning_letter_set_id   :=
                                            ln_dunning_letter_set_id;
                                        lr_customer_profile_rec.grouping_rule_id   :=
                                            ln_grouping_rule_id;
                                        lr_customer_profile_rec.interest_period_days   :=
                                            lr_cust_profile_rec.interest_period_days;
                                        lr_customer_profile_rec.lockbox_matching_option   :=
                                            lr_cust_profile_rec.lockbox_matching_option;
                                        lr_customer_profile_rec.interest_charges   :=
                                            lr_cust_profile_rec.interest_charges;
                                        lr_customer_profile_rec.discount_terms   :=
                                            lr_cust_profile_rec.discount_terms;
                                        lr_customer_profile_rec.override_terms   :=
                                            lr_cust_profile_rec.override_terms;
                                        lr_customer_profile_rec.tax_printing_option   :=
                                            lr_cust_profile_rec.tax_printing_option;
                                        lr_customer_profile_rec.send_statements   :=
                                            lr_cust_profile_rec.statements;
                                        lr_customer_profile_rec.statement_cycle_id   :=
                                            ln_statement_cycle_id;
                                        lr_customer_profile_rec.standard_terms   :=
                                            ln_standard_terms_id;
                                        lr_customer_profile_rec.credit_classification   :=
                                            lr_cust_profile_rec.credit_classification;
                                        lr_customer_profile_rec.created_by_module   :=
                                            'TCA_V1_API';

                                        log_records (
                                            p_debug   => gc_debug_flag,
                                            p_message   =>
                                                'Calling create_cust_profile');
                                    /*create_cust_profile ( lr_customer_profile_rec
                                                        ,  lx_profile_id
                                                        ,  x_return_status );*/
                                    END IF;
                                END IF;         --gc_cust_site_use = 'BILL_TO'
                            END IF;
                        END IF;
                    END IF;


                    IF (ln_cust_acct_site_use_id > 0 AND lx_profile_id > 0)
                    THEN
                        ---------------------------Profile Amounts for Sites---------------------------
                        IF gc_cust_site_use = 'BILL_TO'
                        THEN
                            FOR c_profile_amt
                                IN lcu_fetch_profile_amounts (
                                       lt_site_use_data (xc_site_use_idx).customer_id,
                                       lt_site_use_data (xc_site_use_idx).site_use_id)
                            LOOP
                                IF c_profile_amt.site_use_id IS NOT NULL
                                THEN
                                    BEGIN
                                        SELECT hcpa.cust_acct_profile_amt_id
                                          INTO ln_cust_acct_profile_amt_id
                                          FROM hz_cust_profile_amts hcpa
                                         WHERE     hcpa.cust_account_profile_id =
                                                   lx_profile_id
                                               AND currency_code =
                                                   c_profile_amt.currency_code;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_cust_acct_profile_amt_id   :=
                                                0;
                                    END;

                                    IF ln_cust_acct_profile_amt_id = 0
                                    THEN
                                        SELECT COUNT (*)
                                          INTO ln_cnt
                                          FROM xxd_conv.xx_exclude_legacy xxel, xxd_ar_customer_dlt_stg_t xac
                                         WHERE     xxel.cust_number =
                                                   xac.customer_number
                                               AND xac.customer_id =
                                                   lt_site_use_data (
                                                       xc_site_use_idx).customer_id;

                                        IF ln_cnt = 0
                                        THEN
                                            l_cpamt_rec.cust_account_profile_id   :=
                                                lx_profile_id;
                                            l_cpamt_rec.currency_code   :=
                                                c_profile_amt.currency_code; --<< Currency Code
                                            l_cpamt_rec.created_by_module   :=
                                                'TCA_V1_API';
                                            l_cpamt_rec.trx_credit_limit   :=
                                                1; --c_profile_amt.trx_credit_limit;
                                            l_cpamt_rec.overall_credit_limit   :=
                                                1; --c_profile_amt.overall_credit_limit;
                                            l_cpamt_rec.min_dunning_amount   :=
                                                NULL; --c_profile_amt.min_dunning_amount;
                                            l_cpamt_rec.min_dunning_invoice_amount   :=
                                                NULL; --c_profile_amt.min_dunning_invoice_amount;
                                            l_cpamt_rec.min_statement_amount   :=
                                                NULL; --c_profile_amt.min_statement_amount;
                                            l_cpamt_rec.interest_type   :=
                                                'FIXED_RATE';
                                            l_cpamt_rec.interest_rate   :=
                                                NVL (
                                                    c_profile_amt.interest_rate,
                                                    0);
                                            l_cpamt_rec.min_fc_balance_amount   :=
                                                c_profile_amt.min_fc_balance_amount;
                                            l_cpamt_rec.min_fc_balance_overdue_type   :=
                                                c_profile_amt.min_fc_balance_overdue_type;
                                            l_cpamt_rec.attribute_category   :=
                                                c_profile_amt.attribute_category;
                                            l_cpamt_rec.attribute1   :=
                                                c_profile_amt.attribute1;
                                            l_cpamt_rec.attribute2   :=
                                                c_profile_amt.attribute2;
                                            l_cpamt_rec.attribute3   :=
                                                c_profile_amt.attribute3;
                                            l_cpamt_rec.attribute4   :=
                                                c_profile_amt.attribute4;
                                            l_cpamt_rec.attribute5   :=
                                                c_profile_amt.attribute5;
                                            l_cpamt_rec.attribute6   :=
                                                c_profile_amt.attribute6;
                                            l_cpamt_rec.attribute7   :=
                                                c_profile_amt.attribute7;
                                            l_cpamt_rec.attribute8   :=
                                                c_profile_amt.attribute8;
                                            l_cpamt_rec.attribute9   :=
                                                c_profile_amt.attribute9;
                                            l_cpamt_rec.attribute10   :=
                                                c_profile_amt.attribute10;
                                            l_cpamt_rec.attribute11   :=
                                                c_profile_amt.attribute11;
                                            l_cpamt_rec.attribute12   :=
                                                c_profile_amt.attribute12;
                                            l_cpamt_rec.cust_account_id   :=
                                                lt_site_use_data (
                                                    xc_site_use_idx).customer_id;
                                            l_cpamt_rec.site_use_id   :=
                                                lt_site_use_data (
                                                    xc_site_use_idx).site_use_id;
                                            create_cust_profile_amt (
                                                p_cpamt_rec => l_cpamt_rec);
                                        ELSE
                                            l_cpamt_rec.cust_account_profile_id   :=
                                                lx_profile_id;
                                            l_cpamt_rec.currency_code   :=
                                                c_profile_amt.currency_code; --<< Currency Code
                                            l_cpamt_rec.created_by_module   :=
                                                'TCA_V1_API';
                                            l_cpamt_rec.trx_credit_limit   :=
                                                c_profile_amt.trx_credit_limit;
                                            l_cpamt_rec.overall_credit_limit   :=
                                                c_profile_amt.overall_credit_limit;
                                            l_cpamt_rec.min_dunning_amount   :=
                                                c_profile_amt.min_dunning_amount;
                                            l_cpamt_rec.min_dunning_invoice_amount   :=
                                                c_profile_amt.min_dunning_invoice_amount;
                                            l_cpamt_rec.min_statement_amount   :=
                                                c_profile_amt.min_statement_amount;
                                            l_cpamt_rec.interest_type   :=
                                                'FIXED_RATE';
                                            l_cpamt_rec.interest_rate   :=
                                                NVL (
                                                    c_profile_amt.interest_rate,
                                                    0);
                                            l_cpamt_rec.min_fc_balance_amount   :=
                                                c_profile_amt.min_fc_balance_amount;
                                            l_cpamt_rec.min_fc_balance_overdue_type   :=
                                                c_profile_amt.min_fc_balance_overdue_type;
                                            l_cpamt_rec.attribute_category   :=
                                                c_profile_amt.attribute_category;
                                            l_cpamt_rec.attribute1   :=
                                                c_profile_amt.attribute1;
                                            l_cpamt_rec.attribute2   :=
                                                c_profile_amt.attribute2;
                                            l_cpamt_rec.attribute3   :=
                                                c_profile_amt.attribute3;
                                            l_cpamt_rec.attribute4   :=
                                                c_profile_amt.attribute4;
                                            l_cpamt_rec.attribute5   :=
                                                c_profile_amt.attribute5;
                                            l_cpamt_rec.attribute6   :=
                                                c_profile_amt.attribute6;
                                            l_cpamt_rec.attribute7   :=
                                                c_profile_amt.attribute7;
                                            l_cpamt_rec.attribute8   :=
                                                c_profile_amt.attribute8;
                                            l_cpamt_rec.attribute9   :=
                                                c_profile_amt.attribute9;
                                            l_cpamt_rec.attribute10   :=
                                                c_profile_amt.attribute10;
                                            l_cpamt_rec.attribute11   :=
                                                c_profile_amt.attribute11;
                                            l_cpamt_rec.attribute12   :=
                                                c_profile_amt.attribute12;
                                            l_cpamt_rec.cust_account_id   :=
                                                lt_site_use_data (
                                                    xc_site_use_idx).customer_id;
                                            l_cpamt_rec.site_use_id   :=
                                                lt_site_use_data (
                                                    xc_site_use_idx).site_use_id;
                                            create_cust_profile_amt (
                                                p_cpamt_rec => l_cpamt_rec);
                                        END IF;
                                    END IF;
                                END IF; -- c_profile_amt.site_use_id IS NOT NULL
                            END LOOP;
                        END IF;                -- gc_cust_site_use = 'BILL_TO'
                    END IF;

                    IF ln_cust_acct_site_use_id > 0
                    THEN
                        UPDATE xxd_ar_cust_siteuse_dlt_stg_t
                           SET record_status   = gc_process_status
                         WHERE     site_use_id =
                                   lt_site_use_data (xc_site_use_idx).site_use_id
                               AND customer_id =
                                   lt_site_use_data (xc_site_use_idx).customer_id;

                        UPDATE xxd_ar_cust_prof_dlt_stg_t
                           SET record_status   = gc_process_status
                         WHERE     site_use_id =
                                   lt_site_use_data (xc_site_use_idx).site_use_id
                               AND orig_system_customer_ref =
                                   lt_site_use_data (xc_site_use_idx).customer_id;

                        UPDATE xxd_ar_cust_profamt_dlt_stg_t
                           SET record_status   = gc_process_status
                         WHERE     site_use_id =
                                   lt_site_use_data (xc_site_use_idx).site_use_id
                               AND customer_id =
                                   lt_site_use_data (xc_site_use_idx).customer_id;
                    ELSE
                        UPDATE xxd_ar_cust_siteuse_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE     site_use_id =
                                   lt_site_use_data (xc_site_use_idx).site_use_id
                               AND customer_id =
                                   lt_site_use_data (xc_site_use_idx).customer_id;

                        UPDATE xxd_ar_cust_prof_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE     site_use_id =
                                   lt_site_use_data (xc_site_use_idx).site_use_id
                               AND orig_system_customer_ref =
                                   lt_site_use_data (xc_site_use_idx).customer_id;

                        UPDATE xxd_ar_cust_profamt_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE     site_use_id =
                                   lt_site_use_data (xc_site_use_idx).site_use_id
                               AND customer_id =
                                   lt_site_use_data (xc_site_use_idx).customer_id;
                    END IF;
                END LOOP;

                COMMIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Un-expecetd Error in  create_cust_site_use => '
                    || SQLERRM);
    END create_cust_site_use;

    FUNCTION get_resource_id_fnc (
        p_resource_name IN jtf_rs_resource_extns_vl.resource_name%TYPE)
        RETURN NUMBER
    IS
        ln_resource_id   jtf_rs_resource_extns_vl.resource_id%TYPE;
    BEGIN
        SELECT resource_id
          INTO ln_resource_id
          FROM jtf_rs_resource_extns_vl
         WHERE     TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (end_date_active, SYSDATE))
               AND resource_name = p_resource_name
               AND category IN ('EMPLOYEE', 'PARTNER', 'PARTY');

        RETURN ln_resource_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_resource_id_fnc;


    PROCEDURE create_customer (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_action IN VARCHAR2
                               , p_target_org_id IN NUMBER, p_batch_id IN NUMBER, p_operating_unit IN VARCHAR2)
    AS
        CURSOR cur_customer (p_party_type VARCHAR2)
        IS
            SELECT *
              FROM xxd_ar_customer_dlt_stg_t cust
             WHERE     party_type = p_party_type
                   AND record_status = p_action
                   AND batch_number = p_batch_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_ar_cust_sites_dlt_stg_t site
                             WHERE     cust.customer_id = site.customer_id
                                   AND target_org = p_target_org_id);

        CURSOR lcu_cust_profile (pn_customer_id   NUMBER,
                                 pn_site_use_id   NUMBER)
        IS
            SELECT account_status, autocash_hierarchy_name, autocash_hierarchy_id,
                   autocash_hierarchy_name_adr, autocash_hierarchy_id_for_adr, auto_rec_incl_disputed_flag,
                   charge_on_finance_charge_flag, clearing_days, collector_name,
                   cons_inv_flag, cons_inv_type, cons_bill_level,
                   tolerance, discount_grace_days, payment_grace_days,
                   attribute1, attribute2, created_by,
                   creation_date, credit_rating, credit_balance_statements,
                   credit_checking, credit_hold, customer_profile_class_name,
                   discount_terms, dunning_letters, dunning_letter_set_name,
                   dunning_letter_set_id, grouping_rule_name, grouping_rule_id,
                   interest_charges, interest_period_days, lockbox_matching_option,
                   org_id, override_terms, standard_terms_name,
                   statements, statement_cycle_name, tax_printing_option,
                   insert_update_flag, last_updated_by, last_update_date,
                   last_update_login, orig_system_address_ref, orig_system_customer_ref,
                   customer_profile_id, credit_classification
              FROM xxd_ar_cust_prof_dlt_stg_t acpv
             WHERE     acpv.orig_system_customer_ref = pn_customer_id
                   AND ((acpv.site_use_id = pn_site_use_id) OR (pn_site_use_id IS NULL AND acpv.site_use_id IS NULL))
                   AND record_status = gc_validate_status
                   AND site_use_id IS NULL;


        lr_cust_profile_rec           lcu_cust_profile%ROWTYPE;

        -- Cursor to fetch collector_id for collector_name
        CURSOR lcu_fetch_collector_id (p_collector_name VARCHAR2)
        IS
            SELECT ac.collector_id
              FROM ar_collectors ac
             WHERE     ac.status = 'A'
                   AND UPPER (ac.name) = UPPER (p_collector_name);

        -- Cursor for fetching profile_class_id
        CURSOR lcu_fetch_profile_class_id (
            p_prof_class_code hz_cust_profile_classes.name%TYPE)
        IS
            SELECT hcpc.profile_class_id
              FROM hz_cust_profile_classes hcpc
             WHERE hcpc.name = p_prof_class_code;

        -- Cursor for fetching profile amounts
        CURSOR lcu_fetch_profile_amounts (p_cust_account_id NUMBER)
        IS
            SELECT currency_code, trx_credit_limit, overall_credit_limit,
                   min_dunning_amount, min_dunning_invoice_amount, min_statement_amount,
                   interest_rate, min_fc_balance_amount, min_fc_balance_overdue_type,
                   attribute_category, attribute1, attribute2,
                   attribute3, attribute4, attribute5,
                   attribute6, attribute7, attribute8,
                   attribute9, attribute10, attribute11,
                   attribute12
              FROM xxd_ar_cust_profamt_dlt_stg_t
             WHERE customer_id = p_cust_account_id AND site_use_id IS NULL;

        -- Cursor to fetch sales rep id from R12 using sales rep name
        CURSOR lcu_get_salesrep (p_sales_rep_name VARCHAR2)
        IS
            SELECT jrs.salesrep_id salesrep_id
              FROM jtf_rs_salesreps jrs
             WHERE 1 = 1 AND jrs.name = p_sales_rep_name;

        --                AND jrs.org_id = pv_org_id;

        -- Cursor to fetch Payment Term id from R12 using term name
        CURSOR lcu_get_term_id (pv_term_name VARCHAR2)
        IS
            --        SELECT RT.term_id      payment_term_id
            --        FROM   ra_terms  RT
            --        WHERE  1=1
            --        AND    UPPER(RT.name)     = UPPER(pv_term_name)
            SELECT rt.term_id payment_term_id
              FROM ra_terms rt, xxd_1206_payment_term_map_t xpt
             WHERE     1 = 1
                   AND UPPER (rt.name) = UPPER (xpt.new_term_name)
                   AND UPPER (xpt.old_term_name) = UPPER (pv_term_name);

        CURSOR lcu_get_price_list_id (p_price_list_name VARCHAR2)
        IS
            SELECT oeplr12.price_list_id price_list_id
              --              ,OEPLR12.name               price_list_name
              FROM oe_price_lists_vl oeplr12, xxd_1206_price_list_map_t xqph
             WHERE     1 = 1
                   AND oeplr12.name = xqph.pricelist_new_name
                   AND legacy_pricelist_name = p_price_list_name;

        lr_get_price_list             lcu_get_price_list_id%ROWTYPE;

        CURSOR lcu_get_price_list_id2 (p_price_list_name VARCHAR2)
        IS
            SELECT oeplr12.price_list_id price_list_id
              --              ,OEPLR12.name               price_list_name
              FROM oe_price_lists_vl oeplr12
             WHERE 1 = 1 AND oeplr12.name = p_price_list_name;

        CURSOR lcu_get_sales_channel_code (p_customer_number VARCHAR2)
        IS
            SELECT UPPER (xqph.sales_channel)
              --              ,OEPLR12.name               price_list_name
              FROM xxd_1206_sales_channel_map_t xqph
             WHERE 1 = 1 AND customer_number = p_customer_number;

        -- Cursor to fetch Order type id from R12
        CURSOR lcur_order_type_id (p_order_type_name VARCHAR2)
        IS
            SELECT ottt12.transaction_type_id order_type_id
              FROM oe_transaction_types_tl ottt12, xxd_1206_order_type_map_t xtt
             WHERE     ottt12.name = xtt.new_12_2_3_name
                   AND legacy_12_0_6_name = p_order_type_name
                   AND language = 'US';

        ln_order_type_id              NUMBER;

        -- Cursor to fetch Territory id from R12
        CURSOR lcu_get_territory_id (p_territory_name VARCHAR2)
        IS
            SELECT rtr12.territory_id territory_id
              FROM ra_territories rtr12
             WHERE 1 = 1 AND rtr12.name = p_territory_name;

        ln_territory_id               NUMBER;

        -- Cursor to fetch dunning_letter_set_id from R12 using 11i dunning_letter_set_id
        CURSOR lcu_dunning_letter_set_id (p_dunning_letter_set_name VARCHAR2)
        IS
            SELECT dunning_letter_set_id
              FROM ar_dunning_letter_sets
             WHERE 1 = 1 AND UPPER (name) = UPPER (p_dunning_letter_set_name);

        ln_dunning_letter_set_id      NUMBER;

        -- Cursor to fetch grouping_rule_id from R12 using 11i grouping_rule_id
        CURSOR lcu_grouping_rule_id (p_grouping_rule_name VARCHAR2)
        IS
            SELECT grouping_rule_id
              FROM ra_grouping_rules
             WHERE 1 = 1 AND UPPER (name) = UPPER (p_grouping_rule_name);

        ln_grouping_rule_id           NUMBER;

        --cursor to get standard_terms_name from ra_customers attribute1
        CURSOR lcu_get_standard_terms_id (p_standard_terms_name VARCHAR2)
        IS
            SELECT rt.term_id payment_term_id
              FROM ra_terms rt, xxd_1206_payment_term_map_t xpt
             WHERE     1 = 1
                   AND UPPER (rt.name) = UPPER (xpt.new_term_name)
                   AND UPPER (xpt.old_term_name) =
                       UPPER (p_standard_terms_name);

        ln_standard_terms_id          VARCHAR2 (1000);

        --Cursor to get the statement cycle name
        CURSOR lcu_statement_cycle_id (p_statement_cycle_name VARCHAR2)
        IS
            SELECT statement_cycle_id
              FROM ar_statement_cycles
             WHERE name = p_statement_cycle_name;

        ln_statement_cycle_id         NUMBER;

        --Cursor to get FOB point from R12 using 11i value
        CURSOR lcu_get_fob (p_fob_point VARCHAR2)
        IS
            SELECT flv12.lookup_code fob_point
              FROM fnd_lookup_values flv12
             WHERE     1 = 1
                   AND flv12.lookup_type = 'FOB'
                   AND flv12.enabled_flag = 'Y'
                   AND flv12.lookup_code = p_fob_point;

        lc_fob_point                  VARCHAR2 (1000);

        --cursor to get Customer category code
        CURSOR lcu_get_cust_category_code (p_cust_category_code VARCHAR2)
        IS
            SELECT flv12.lookup_code cust_category_code
              FROM fnd_lookup_values flv12
             WHERE     1 = 1
                   AND flv12.lookup_type = 'CUSTOMER_CATEGORY'
                   AND flv12.enabled_flag = 'Y'
                   AND flv12.lookup_code = p_cust_category_code;

        lc_cust_category_code         VARCHAR2 (500);

        --Cursor to derive freight_terms from r12 lookups
        CURSOR lcu_freight_terms (p_freight_terms VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'FREIGHT_TERMS'
                   AND UPPER (lookup_code) = UPPER (p_freight_terms)
                   AND enabled_flag = 'Y';

        lc_freight_terms              VARCHAR2 (500);

        --Cursor to derive customer claass code froom r12 lookups
        CURSOR lcu_cust_class_code (p_cust_class_code VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'CUSTOMER CLASS'
                   AND UPPER (lookup_code) = UPPER (p_cust_class_code)
                   AND enabled_flag = 'Y'
                   AND language = 'US';

        lc_cust_class_code            VARCHAR2 (500);

        --cursor to get Customer DEMAND_CLASS code
        CURSOR lcu_get_cust_category_code (p_demand_class VARCHAR2)
        IS
            SELECT flv12.lookup_code cust_category_code
              FROM fnd_lookup_values flv12
             WHERE     1 = 1
                   AND flv12.lookup_type = 'DEMAND_CLASS'
                   AND flv12.enabled_flag = 'Y'
                   AND flv12.lookup_code = p_demand_class;

        TYPE lt_customer_typ IS TABLE OF cur_customer%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_customer_data              lt_customer_typ;
        l_party_rec_type              hz_party_v2pub.party_rec_type;
        l_customer_profile_rec_type   hz_customer_profile_v2pub.customer_profile_rec_type;
        l_cust_account_rec            hz_cust_account_v2pub.cust_account_rec_type;
        l_organization_rec            hz_party_v2pub.organization_rec_type;
        lr_customer_profile_rec       hz_customer_profile_v2pub.customer_profile_rec_type;
        l_cust_acct_relate_rec        hz_cust_account_v2pub.cust_acct_relate_rec_type;
        l_cpamt_rec                   hz_customer_profile_v2pub.cust_profile_amt_rec_type;

        lx_org_party_id               NUMBER := 0;
        lx_cust_account_id            NUMBER := 0;
        lx_child_account_id           NUMBER := 0;
        ln_collector_id               NUMBER;
        ln_profile_class_id           NUMBER;
        lx_profile_id                 NUMBER;
        ln_cust_acct_profile_amt_id   NUMBER;
        ln_stmt_cycle_id              NUMBER;
        ln_cnt                        NUMBER := 0;
        x_return_status               VARCHAR2 (10);
        lc_salesrep                   VARCHAR2 (250);
        lc_profile_class              VARCHAR2 (250);
        lc_price_list                 VARCHAR2 (250);
        lc_sales_channel_code         VARCHAR2 (250);
        lc_distribution_channel       VARCHAR2 (250);
        gc_account_name               VARCHAR2 (300);
        ln_trx_credit_limit           NUMBER;
        ln_overall_credit_limit       NUMBER;
    BEGIN
        log_records (gc_debug_flag, 'Inside create_customer +');

        OPEN cur_customer (p_party_type => 'ORGANIZATION');

        LOOP
            --      SAVEPOINT INSERT_TABLE2;
            FETCH cur_customer BULK COLLECT INTO lt_customer_data LIMIT 50;

            EXIT WHEN lt_customer_data.COUNT = 0;

            IF lt_customer_data.COUNT > 0
            THEN
                FOR xc_customer_idx IN lt_customer_data.FIRST ..
                                       lt_customer_data.LAST
                LOOP
                    gc_customer_name        := NULL;
                    gc_cust_address         := NULL;
                    gc_cust_site_use        := NULL;
                    gc_cust_contact         := NULL;
                    gc_cust_contact_point   := NULL;
                    gc_account_name         := NULL;

                    IF (lt_customer_data (xc_customer_idx).customer_name IS NOT NULL)
                    THEN
                        log_records (
                            gc_debug_flag,
                               'create_customer  Working on the customer '
                            || lt_customer_data (xc_customer_idx).customer_name);

                        BEGIN
                            SELECT alias_name
                              INTO gc_account_name
                              FROM xxd_conv.xxd_apac_customer_mapping_t xac
                             WHERE xac.customer_number =
                                   lt_customer_data (xc_customer_idx).customer_number;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                gc_account_name   :=
                                    lt_customer_data (xc_customer_idx).customer_name;
                            WHEN OTHERS
                            THEN
                                gc_account_name   :=
                                    lt_customer_data (xc_customer_idx).customer_name;
                        END;


                        BEGIN
                            SELECT hzc.cust_account_id, hp.party_id
                              INTO lx_cust_account_id, lx_org_party_id
                              FROM hz_parties hp, hz_cust_accounts hzc
                             WHERE     hp.party_id = hzc.party_id
                                   AND hp.party_type = 'ORGANIZATION'
                                   AND hzc.orig_system_reference =
                                       TO_CHAR (
                                           lt_customer_data (xc_customer_idx).customer_id);

                            x_return_status   := 'S';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lx_org_party_id      := 0;
                                lx_cust_account_id   := 0;
                                log_records (
                                    gc_debug_flag,
                                       lt_customer_data (xc_customer_idx).customer_name
                                    || ' Customer not found in DB ');
                                x_return_status      := 'E';
                            WHEN OTHERS
                            THEN
                                lx_org_party_id   := 0;
                                lx_org_party_id   := 0;
                                log_records (
                                    gc_debug_flag,
                                       'create_customer : '
                                    || lt_customer_data (xc_customer_idx).customer_name
                                    || ' '
                                    || SQLERRM);
                                x_return_status   := 'E';
                        END;


                        IF x_return_status = 'S' AND lx_cust_account_id > 0
                        THEN
                            BEGIN
                                SELECT cust_account_profile_id
                                  INTO lx_profile_id
                                  FROM hz_customer_profiles
                                 WHERE     cust_account_id =
                                           lx_cust_account_id
                                       AND site_use_id IS NULL;

                                x_return_status   := 'S';
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lx_profile_id   := 0;
                            END;

                            IF lx_profile_id = 0
                            THEN
                                OPEN lcu_cust_profile (
                                    lt_customer_data (xc_customer_idx).customer_id,
                                    NULL);

                                FETCH lcu_cust_profile
                                    INTO lr_cust_profile_rec;

                                CLOSE lcu_cust_profile;

                                BEGIN
                                    lc_profile_class   := NULL;

                                    SELECT profile_class
                                      INTO lc_profile_class
                                      FROM xxd_ret_n_int_cust_map
                                     WHERE     customer_number =
                                               lt_customer_data (
                                                   xc_customer_idx).customer_number
                                           AND organization_name =
                                               p_operating_unit;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                ln_profile_class_id       := NULL;

                                IF lc_profile_class IS NOT NULL
                                THEN
                                    OPEN lcu_fetch_profile_class_id (
                                        lc_profile_class);

                                    FETCH lcu_fetch_profile_class_id
                                        INTO ln_profile_class_id;

                                    CLOSE lcu_fetch_profile_class_id;
                                END IF;

                                IF ln_profile_class_id IS NULL
                                THEN
                                    --Fetching profile class id
                                    OPEN lcu_fetch_profile_class_id (
                                        lr_cust_profile_rec.customer_profile_class_name);

                                    --                        OPEN  lcu_fetch_profile_class_id (lc_customer_account_profile);
                                    FETCH lcu_fetch_profile_class_id
                                        INTO ln_profile_class_id;

                                    CLOSE lcu_fetch_profile_class_id;
                                -- validation
                                END IF;

                                lr_customer_profile_rec   := NULL;

                                IF lr_cust_profile_rec.customer_profile_id
                                       IS NOT NULL
                                THEN
                                    ln_collector_id            := NULL;

                                    IF lr_cust_profile_rec.collector_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_fetch_collector_id (
                                            lr_cust_profile_rec.collector_name);

                                        FETCH lcu_fetch_collector_id
                                            INTO ln_collector_id;

                                        CLOSE lcu_fetch_collector_id;

                                        IF ln_collector_id IS NULL
                                        THEN
                                            log_records (
                                                gc_debug_flag,
                                                   ' Collector Name (Site level) '
                                                || lr_cust_profile_rec.collector_name
                                                || ' not setup in R12 ');
                                        END IF;
                                    END IF;

                                    ln_dunning_letter_set_id   := NULL;

                                    IF lr_cust_profile_rec.dunning_letter_set_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_dunning_letter_set_id (
                                            lr_cust_profile_rec.dunning_letter_set_name);

                                        FETCH lcu_dunning_letter_set_id
                                            INTO ln_dunning_letter_set_id;

                                        CLOSE lcu_dunning_letter_set_id;

                                        IF ln_dunning_letter_set_id IS NULL
                                        THEN
                                            NULL; --ln_dunning_letter_set_id validation
                                        END IF;
                                    END IF;

                                    ln_statement_cycle_id      := NULL;

                                    IF lr_cust_profile_rec.statement_cycle_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_statement_cycle_id (
                                            lr_cust_profile_rec.statement_cycle_name);

                                        FETCH lcu_statement_cycle_id
                                            INTO ln_statement_cycle_id;

                                        CLOSE lcu_statement_cycle_id;

                                        IF ln_statement_cycle_id IS NULL
                                        THEN
                                            NULL;
                                        END IF;
                                    END IF;

                                    ln_grouping_rule_id        := NULL;

                                    IF lr_cust_profile_rec.grouping_rule_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_grouping_rule_id (
                                            lr_cust_profile_rec.grouping_rule_name);

                                        FETCH lcu_grouping_rule_id
                                            INTO ln_grouping_rule_id;

                                        CLOSE lcu_grouping_rule_id;

                                        IF ln_grouping_rule_id IS NULL
                                        THEN
                                            NULL;
                                        END IF;
                                    END IF;

                                    ln_standard_terms_id       := NULL;

                                    IF lr_cust_profile_rec.standard_terms_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_get_standard_terms_id (
                                            lr_cust_profile_rec.standard_terms_name);

                                        FETCH lcu_get_standard_terms_id
                                            INTO ln_standard_terms_id;

                                        CLOSE lcu_get_standard_terms_id;

                                        IF ln_standard_terms_id IS NULL
                                        THEN
                                            NULL;            --raise the error
                                        END IF;
                                    END IF;

                                    lr_customer_profile_rec    := NULL;
                                    lr_customer_profile_rec.cust_account_id   :=
                                        lx_cust_account_id;
                                    lr_customer_profile_rec.profile_class_id   :=
                                        ln_profile_class_id;
                                    lr_customer_profile_rec.collector_id   :=
                                        ln_collector_id;
                                    lr_customer_profile_rec.account_status   :=
                                        lr_cust_profile_rec.account_status;
                                    lr_customer_profile_rec.auto_rec_incl_disputed_flag   :=
                                        lr_cust_profile_rec.auto_rec_incl_disputed_flag;
                                    lr_customer_profile_rec.charge_on_finance_charge_flag   :=
                                        lr_cust_profile_rec.charge_on_finance_charge_flag;
                                    lr_customer_profile_rec.clearing_days   :=
                                        lr_cust_profile_rec.clearing_days;
                                    lr_customer_profile_rec.credit_balance_statements   :=
                                        lr_cust_profile_rec.credit_balance_statements;
                                    lr_customer_profile_rec.credit_checking   :=
                                        lr_cust_profile_rec.credit_checking;

                                    IF lr_cust_profile_rec.cons_inv_flag =
                                       'Y'
                                    THEN
                                        lr_customer_profile_rec.cons_inv_flag   :=
                                            lr_cust_profile_rec.cons_inv_flag;
                                        lr_customer_profile_rec.cons_inv_type   :=
                                            lr_cust_profile_rec.cons_inv_type;
                                        lr_customer_profile_rec.cons_bill_level   :=
                                            lr_cust_profile_rec.cons_bill_level;
                                    END IF;

                                    lr_customer_profile_rec.tolerance   :=
                                        lr_cust_profile_rec.tolerance;
                                    lr_customer_profile_rec.discount_grace_days   :=
                                        lr_cust_profile_rec.discount_grace_days;
                                    lr_customer_profile_rec.payment_grace_days   :=
                                        lr_cust_profile_rec.payment_grace_days;
                                    lr_customer_profile_rec.attribute1   :=
                                        lr_cust_profile_rec.attribute1;
                                    lr_customer_profile_rec.attribute2   :=
                                        lr_cust_profile_rec.attribute2;
                                    lr_customer_profile_rec.credit_hold   :=
                                        lr_cust_profile_rec.credit_hold;
                                    lr_customer_profile_rec.credit_rating   :=
                                        lr_cust_profile_rec.credit_rating;
                                    lr_customer_profile_rec.dunning_letters   :=
                                        lr_cust_profile_rec.dunning_letters;
                                    lr_customer_profile_rec.dunning_letter_set_id   :=
                                        ln_dunning_letter_set_id;
                                    lr_customer_profile_rec.grouping_rule_id   :=
                                        ln_grouping_rule_id;
                                    lr_customer_profile_rec.interest_period_days   :=
                                        lr_cust_profile_rec.interest_period_days;
                                    lr_customer_profile_rec.lockbox_matching_option   :=
                                        lr_cust_profile_rec.lockbox_matching_option;
                                    lr_customer_profile_rec.interest_charges   :=
                                        lr_cust_profile_rec.interest_charges;
                                    lr_customer_profile_rec.discount_terms   :=
                                        lr_cust_profile_rec.discount_terms;
                                    lr_customer_profile_rec.override_terms   :=
                                        lr_cust_profile_rec.override_terms;
                                    lr_customer_profile_rec.tax_printing_option   :=
                                        lr_cust_profile_rec.tax_printing_option;
                                    lr_customer_profile_rec.send_statements   :=
                                        lr_cust_profile_rec.statements;
                                    lr_customer_profile_rec.statement_cycle_id   :=
                                        ln_statement_cycle_id;
                                    lr_customer_profile_rec.standard_terms   :=
                                        ln_standard_terms_id;
                                    lr_customer_profile_rec.credit_classification   :=
                                        lr_cust_profile_rec.credit_classification;

                                    create_cust_profile (
                                        lr_customer_profile_rec,
                                        lx_profile_id,
                                        x_return_status);
                                END IF;
                            END IF;
                        END IF;

                        IF     x_return_status = 'S'
                           AND lx_cust_account_id > 0
                           AND lx_profile_id > 0
                        THEN
                            lc_distribution_channel   := NULL;
                            ln_trx_credit_limit       := NULL;
                            ln_overall_credit_limit   := NULL;

                            BEGIN
                                SELECT distribution_channel, trx_credit_limit, overall_credit_limit
                                  INTO lc_distribution_channel, ln_trx_credit_limit, ln_overall_credit_limit
                                  FROM xxd_ret_n_int_cust_map
                                 WHERE     customer_number =
                                           lt_customer_data (xc_customer_idx).customer_number
                                       AND organization_name =
                                           p_operating_unit;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;

                            l_cpamt_rec.cust_account_profile_id   :=
                                lx_profile_id;

                            FOR c_profile_amt
                                IN lcu_fetch_profile_amounts (
                                       p_cust_account_id   =>
                                           lt_customer_data (xc_customer_idx).customer_id)
                            LOOP
                                BEGIN
                                    SELECT hcpa.cust_acct_profile_amt_id
                                      INTO ln_cust_acct_profile_amt_id
                                      FROM hz_cust_profile_amts hcpa
                                     WHERE     hcpa.cust_account_profile_id =
                                               lx_profile_id
                                           AND currency_code =
                                               c_profile_amt.currency_code;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_cust_acct_profile_amt_id   := 0;
                                END;

                                IF ln_cust_acct_profile_amt_id = 0
                                THEN
                                    SELECT COUNT (*)
                                      INTO ln_cnt
                                      FROM xxd_conv.xx_exclude_legacy
                                     WHERE cust_number =
                                           lt_customer_data (xc_customer_idx).customer_number;

                                    IF ln_cnt = 0
                                    THEN
                                        l_cpamt_rec.currency_code      :=
                                            c_profile_amt.currency_code; --<< Currency Code
                                        l_cpamt_rec.created_by_module   :=
                                            'TCA_V1_API';
                                        l_cpamt_rec.trx_credit_limit   := 1; --c_profile_amt.trx_credit_limit;
                                        l_cpamt_rec.overall_credit_limit   :=
                                            1; --c_profile_amt.overall_credit_limit;
                                        l_cpamt_rec.min_dunning_amount   :=
                                            NULL; --c_profile_amt.min_dunning_amount;
                                        l_cpamt_rec.min_dunning_invoice_amount   :=
                                            NULL; --c_profile_amt.min_dunning_invoice_amount;
                                        l_cpamt_rec.min_statement_amount   :=
                                            NULL; --c_profile_amt.min_statement_amount;
                                        l_cpamt_rec.interest_type      :=
                                            'FIXED_RATE';
                                        l_cpamt_rec.interest_rate      :=
                                            NVL (c_profile_amt.interest_rate,
                                                 0);
                                        l_cpamt_rec.min_fc_balance_amount   :=
                                            c_profile_amt.min_fc_balance_amount;
                                        l_cpamt_rec.min_fc_balance_overdue_type   :=
                                            c_profile_amt.min_fc_balance_overdue_type;
                                        l_cpamt_rec.attribute_category   :=
                                            c_profile_amt.attribute_category;
                                        l_cpamt_rec.attribute1         :=
                                            c_profile_amt.attribute1;
                                        l_cpamt_rec.attribute2         :=
                                            c_profile_amt.attribute2;
                                        l_cpamt_rec.attribute3         :=
                                            c_profile_amt.attribute3;
                                        l_cpamt_rec.attribute4         :=
                                            c_profile_amt.attribute4;
                                        l_cpamt_rec.attribute5         :=
                                            c_profile_amt.attribute5;
                                        l_cpamt_rec.attribute6         :=
                                            c_profile_amt.attribute6;
                                        l_cpamt_rec.attribute7         :=
                                            c_profile_amt.attribute7;
                                        l_cpamt_rec.attribute8         :=
                                            c_profile_amt.attribute8;
                                        l_cpamt_rec.attribute9         :=
                                            c_profile_amt.attribute9;
                                        l_cpamt_rec.attribute10        :=
                                            c_profile_amt.attribute10;
                                        l_cpamt_rec.attribute11        :=
                                            c_profile_amt.attribute11;
                                        l_cpamt_rec.attribute12        :=
                                            c_profile_amt.attribute12;
                                        l_cpamt_rec.cust_account_id    :=
                                            lx_cust_account_id; --<<value for cust_account_id from step 2a
                                        create_cust_profile_amt (
                                            p_cpamt_rec => l_cpamt_rec);
                                    ELSE
                                        l_cpamt_rec.currency_code   :=
                                            c_profile_amt.currency_code; --<< Currency Code
                                        l_cpamt_rec.created_by_module   :=
                                            'TCA_V1_API';

                                        IF lc_distribution_channel = 'Retail'
                                        THEN
                                            l_cpamt_rec.trx_credit_limit   :=
                                                ln_trx_credit_limit;
                                            l_cpamt_rec.overall_credit_limit   :=
                                                ln_overall_credit_limit;
                                        ELSE
                                            l_cpamt_rec.trx_credit_limit   :=
                                                c_profile_amt.trx_credit_limit;
                                            l_cpamt_rec.overall_credit_limit   :=
                                                c_profile_amt.overall_credit_limit;
                                        END IF;

                                        l_cpamt_rec.min_dunning_amount   :=
                                            c_profile_amt.min_dunning_amount;
                                        l_cpamt_rec.min_dunning_invoice_amount   :=
                                            c_profile_amt.min_dunning_invoice_amount;
                                        l_cpamt_rec.min_statement_amount   :=
                                            c_profile_amt.min_statement_amount;
                                        l_cpamt_rec.interest_type   :=
                                            'FIXED_RATE';
                                        l_cpamt_rec.interest_rate   :=
                                            NVL (c_profile_amt.interest_rate,
                                                 0);
                                        l_cpamt_rec.min_fc_balance_amount   :=
                                            c_profile_amt.min_fc_balance_amount;
                                        l_cpamt_rec.min_fc_balance_overdue_type   :=
                                            c_profile_amt.min_fc_balance_overdue_type;
                                        l_cpamt_rec.attribute_category   :=
                                            c_profile_amt.attribute_category;
                                        l_cpamt_rec.attribute1   :=
                                            c_profile_amt.attribute1;
                                        l_cpamt_rec.attribute2   :=
                                            c_profile_amt.attribute2;
                                        l_cpamt_rec.attribute3   :=
                                            c_profile_amt.attribute3;
                                        l_cpamt_rec.attribute4   :=
                                            c_profile_amt.attribute4;
                                        l_cpamt_rec.attribute5   :=
                                            c_profile_amt.attribute5;
                                        l_cpamt_rec.attribute6   :=
                                            c_profile_amt.attribute6;
                                        l_cpamt_rec.attribute7   :=
                                            c_profile_amt.attribute7;
                                        l_cpamt_rec.attribute8   :=
                                            c_profile_amt.attribute8;
                                        l_cpamt_rec.attribute9   :=
                                            c_profile_amt.attribute9;
                                        l_cpamt_rec.attribute10   :=
                                            c_profile_amt.attribute10;
                                        l_cpamt_rec.attribute11   :=
                                            c_profile_amt.attribute11;
                                        l_cpamt_rec.attribute12   :=
                                            c_profile_amt.attribute12;
                                        l_cpamt_rec.cust_account_id   :=
                                            lx_cust_account_id; --<<value for cust_account_id from step 2a
                                        create_cust_profile_amt (
                                            p_cpamt_rec => l_cpamt_rec);
                                    END IF;
                                END IF;
                            END LOOP;
                        END IF;

                        log_records (
                            gc_debug_flag,
                            ' Calling create_contacts_records for the customer  ');

                        IF (lx_cust_account_id > 0 AND lx_org_party_id > 0)
                        THEN
                            create_contacts_records (
                                pn_customer_id        =>
                                    lt_customer_data (xc_customer_idx).customer_id,
                                p_party_id            => lx_org_party_id,
                                p_address_id          => NULL,
                                p_party_site_id       => NULL,
                                p_cust_account_id     => lx_cust_account_id,
                                p_cust_acct_site_id   => NULL);
                        END IF;

                        IF    x_return_status = 'S'
                           OR (NVL (lx_org_party_id, 0) > 0 AND NVL (lx_cust_account_id, 0) > 0)
                        THEN
                            UPDATE xxd_ar_customer_dlt_stg_t
                               SET record_status = gc_process_status, request_id = gn_conc_request_id
                             WHERE customer_id =
                                   lt_customer_data (xc_customer_idx).customer_id;

                            UPDATE xxd_ar_cust_prof_dlt_stg_t
                               SET record_status   = gc_process_status
                             WHERE     site_use_id IS NULL
                                   AND orig_system_customer_ref =
                                       lt_customer_data (xc_customer_idx).customer_id;

                            UPDATE xxd_ar_cust_profamt_dlt_stg_t
                               SET record_status   = gc_process_status
                             WHERE     site_use_id IS NULL
                                   AND customer_id =
                                       lt_customer_data (xc_customer_idx).customer_id;
                        ELSE
                            UPDATE xxd_ar_customer_dlt_stg_t
                               SET record_status = gc_error_status, request_id = gn_conc_request_id
                             WHERE customer_id =
                                   lt_customer_data (xc_customer_idx).customer_id;

                            UPDATE xxd_ar_cust_prof_dlt_stg_t
                               SET record_status   = gc_error_status
                             WHERE     site_use_id IS NULL
                                   AND orig_system_customer_ref =
                                       lt_customer_data (xc_customer_idx).customer_id;

                            UPDATE xxd_ar_cust_profamt_dlt_stg_t
                               SET record_status   = gc_error_status
                             WHERE     site_use_id IS NULL
                                   AND customer_id =
                                       lt_customer_data (xc_customer_idx).customer_id;

                            lx_org_party_id      := 0;
                            lx_cust_account_id   := 0;
                        END IF;

                        COMMIT;

                        IF lx_org_party_id > 0 AND lx_cust_account_id > 0
                        THEN
                            log_records (
                                gc_debug_flag,
                                   ' Calling create_cust_address to for customer '
                                || lt_customer_data (xc_customer_idx).customer_name);
                            create_cust_address (
                                p_action            => p_action,
                                p_customer_id       =>
                                    lt_customer_data (xc_customer_idx).customer_id,
                                p_new_party_id      => lx_org_party_id,
                                p_cust_account_id   => lx_cust_account_id);

                            log_records (
                                gc_debug_flag,
                                   ' Calling create_cust_site_use to for customer '
                                || lt_customer_data (xc_customer_idx).customer_name);

                            create_cust_site_use (
                                p_action                    => p_action,
                                p_customer_id               =>
                                    lt_customer_data (xc_customer_idx).customer_id,
                                p_party_type                => 'XXXX',
                                p_site_revenue_account      => NULL,
                                p_site_freight_account      => NULL,
                                p_site_tax_account          => NULL,
                                p_site_unearn_rev_account   => NULL);
                        END IF;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Un-expecetd Error in  create_customer => ' || SQLERRM);
            ROLLBACK;
    END create_customer;

    PROCEDURE create_person (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_action IN VARCHAR2
                             , p_target_org_id IN NUMBER, p_batch_id IN NUMBER, p_operating_unit IN VARCHAR2)
    AS
        CURSOR cur_customer (p_party_type VARCHAR2)
        IS
            SELECT *
              FROM xxd_ar_customer_dlt_stg_t person
             WHERE     party_type = p_party_type
                   AND record_status = p_action
                   AND batch_number = p_batch_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_ar_cust_sites_dlt_stg_t site
                             WHERE     person.customer_id = site.customer_id
                                   AND target_org = p_target_org_id);


        CURSOR lcu_cust_profile (pn_customer_id   NUMBER,
                                 pn_site_use_id   NUMBER)
        IS
            SELECT account_status, autocash_hierarchy_name, autocash_hierarchy_id,
                   autocash_hierarchy_name_adr, autocash_hierarchy_id_for_adr, auto_rec_incl_disputed_flag,
                   charge_on_finance_charge_flag, clearing_days, collector_name,
                   cons_inv_flag, cons_inv_type, cons_bill_level,
                   tolerance, discount_grace_days, payment_grace_days,
                   attribute1, attribute2, created_by,
                   creation_date, credit_rating, credit_balance_statements,
                   credit_checking, credit_hold, customer_profile_class_name,
                   discount_terms, dunning_letters, dunning_letter_set_name,
                   dunning_letter_set_id, grouping_rule_name, grouping_rule_id,
                   interest_charges, interest_period_days, lockbox_matching_option,
                   org_id, override_terms, standard_terms_name,
                   statements, statement_cycle_name, tax_printing_option,
                   insert_update_flag, last_updated_by, last_update_date,
                   last_update_login, orig_system_address_ref, orig_system_customer_ref,
                   customer_profile_id, credit_classification
              FROM xxd_ar_cust_prof_dlt_stg_t acpv
             WHERE     acpv.orig_system_customer_ref = pn_customer_id
                   AND acpv.site_use_id IS NULL
                   AND record_status = gc_new_status;


        lr_cust_profile_rec           lcu_cust_profile%ROWTYPE;

        -- Cursor for fetching profile amounts
        CURSOR lcu_fetch_profile_amounts (p_cust_account_id NUMBER)
        IS
            SELECT currency_code, trx_credit_limit, overall_credit_limit,
                   min_dunning_amount, min_dunning_invoice_amount, min_statement_amount,
                   interest_rate, min_fc_balance_amount, min_fc_balance_overdue_type,
                   attribute_category, attribute1, attribute2,
                   attribute3, attribute4, attribute5,
                   attribute6, attribute7, attribute8,
                   attribute9, attribute10, attribute11,
                   attribute12
              FROM xxd_ar_cust_profamt_dlt_stg_t
             WHERE customer_id = p_cust_account_id AND site_use_id IS NULL;

        -- Cursor to fetch collector_id for collector_name
        CURSOR lcu_fetch_collector_id (p_collector_name VARCHAR2)
        IS
            SELECT ac.collector_id
              FROM ar_collectors ac
             WHERE     ac.status = 'A'
                   AND UPPER (ac.name) = UPPER (p_collector_name);

        -- Cursor for fetching profile_class_id
        CURSOR lcu_fetch_profile_class_id (
            p_prof_class_code hz_cust_profile_classes.name%TYPE)
        IS
            SELECT hcpc.profile_class_id
              FROM hz_cust_profile_classes hcpc
             WHERE hcpc.name = p_prof_class_code;

        -- Cursor to fetch sales rep id from R12 using sales rep name
        CURSOR lcu_get_salesrep (pv_org_id NUMBER)
        IS
            SELECT jrs.salesrep_id salesrep_id
              FROM jtf_rs_salesreps jrs
             WHERE     1 = 1
                   AND jrs.name = 'No Sales Credit'
                   AND jrs.org_id = pv_org_id;

        -- Cursor to fetch Payment Term id from R12 using term name
        CURSOR lcu_get_term_id (pv_term_name VARCHAR2)
        IS
            SELECT rt.term_id payment_term_id
              FROM ra_terms rt, xxd_1206_payment_term_map_t xpt
             WHERE     1 = 1
                   AND UPPER (rt.name) = UPPER (xpt.new_term_name)
                   AND UPPER (xpt.old_term_name) = UPPER (pv_term_name);

        -- Cursor to fetch Price List id from R12
        CURSOR lcu_get_price_list_id (p_price_list_name VARCHAR2)
        IS
            SELECT oeplr12.price_list_id price_list_id, oeplr12.name price_list_name
              FROM oe_price_lists_vl oeplr12, xxd_1206_price_list_map_t xqph
             WHERE     1 = 1
                   AND oeplr12.name = xqph.pricelist_new_name
                   AND legacy_pricelist_name = p_price_list_name;

        lr_get_price_list             lcu_get_price_list_id%ROWTYPE;

        -- Cursor to fetch Order type id from R12
        CURSOR lcur_order_type_id (p_order_type_name VARCHAR2)
        IS
            SELECT ottt12.transaction_type_id order_type_id
              FROM oe_transaction_types_tl ottt12, xxd_1206_order_type_map_t xtt
             WHERE     ottt12.name = xtt.new_12_2_3_name
                   AND legacy_12_0_6_name = p_order_type_name
                   AND language = 'US';

        ln_order_type_id              NUMBER;

        -- Cursor to fetch Territory id from R12
        CURSOR lcu_get_territory_id (p_territory_name VARCHAR2)
        IS
            SELECT rtr12.territory_id territory_id
              FROM ra_territories rtr12
             WHERE 1 = 1 AND rtr12.name = p_territory_name;

        ln_territory_id               NUMBER;

        -- Cursor to fetch dunning_letter_set_id from R12 using 11i dunning_letter_set_id
        CURSOR lcu_dunning_letter_set_id (p_dunning_letter_set_name VARCHAR2)
        IS
            SELECT dunning_letter_set_id
              FROM ar_dunning_letter_sets
             WHERE 1 = 1 AND UPPER (name) = UPPER (p_dunning_letter_set_name);

        ln_dunning_letter_set_id      NUMBER;

        -- Cursor to fetch grouping_rule_id from R12 using 11i grouping_rule_id
        CURSOR lcu_grouping_rule_id (p_grouping_rule_name VARCHAR2)
        IS
            SELECT grouping_rule_id
              FROM ra_grouping_rules
             WHERE 1 = 1 AND UPPER (name) = UPPER (p_grouping_rule_name);

        ln_grouping_rule_id           NUMBER;

        --cursor to get standard_terms_name from ra_customers attribute1
        CURSOR lcu_get_standard_terms_id (p_standard_terms_name VARCHAR2)
        IS
            SELECT rt.term_id standard_terms_id
              FROM ra_terms rt, xxd_1206_payment_term_map_t xrt
             WHERE     UPPER (rt.name) = UPPER (xrt.new_term_name)
                   AND UPPER (old_term_name) = UPPER (p_standard_terms_name);

        ln_standard_terms_id          VARCHAR2 (1000);

        --Cursor to get the statement cycle name
        CURSOR lcu_statement_cycle_id (p_statement_cycle_name VARCHAR2)
        IS
            SELECT statement_cycle_id
              FROM ar_statement_cycles
             WHERE name = p_statement_cycle_name;

        ln_statement_cycle_id         NUMBER;

        --Cursor to get FOB point from R12 using 11i value
        CURSOR lcu_get_fob (p_fob_point VARCHAR2)
        IS
            SELECT flv12.lookup_code fob_point
              FROM fnd_lookup_values flv12
             WHERE     1 = 1
                   AND flv12.lookup_type = 'FOB'
                   AND flv12.enabled_flag = 'Y'
                   AND flv12.lookup_code = p_fob_point;

        lc_fob_point                  VARCHAR2 (1000);

        --cursor to get Customer category code
        CURSOR lcu_get_cust_category_code (p_cust_category_code VARCHAR2)
        IS
            SELECT flv12.lookup_code cust_category_code
              FROM fnd_lookup_values flv12
             WHERE     1 = 1
                   AND flv12.lookup_type = 'CUSTOMER_CATEGORY'
                   AND flv12.enabled_flag = 'Y'
                   AND flv12.lookup_code = p_cust_category_code;

        lc_cust_category_code         VARCHAR2 (500);

        --Cursor to derive freight_terms from r12 lookups
        CURSOR lcu_freight_terms (p_freight_terms VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'FREIGHT_TERMS'
                   AND UPPER (lookup_code) = UPPER (p_freight_terms)
                   AND enabled_flag = 'Y';

        lc_freight_terms              VARCHAR2 (500);

        --Cursor to derive customer claass code froom r12 lookups
        CURSOR lcu_cust_class_code (p_cust_class_code VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'CUSTOMER CLASS'
                   AND UPPER (lookup_code) = UPPER (p_cust_class_code)
                   AND enabled_flag = 'Y';

        lc_cust_class_code            VARCHAR2 (500);

        TYPE lt_customer_typ IS TABLE OF cur_customer%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_customer_data              lt_customer_typ;
        l_party_rec_type              hz_party_v2pub.party_rec_type;
        l_customer_profile_rec_type   hz_customer_profile_v2pub.customer_profile_rec_type;
        l_cust_account_rec            hz_cust_account_v2pub.cust_account_rec_type;
        --l_organization_rec                            HZ_PARTY_V2PUB.organization_rec_type;
        lr_person_rec                 hz_party_v2pub.person_rec_type;
        lr_customer_profile_rec       hz_customer_profile_v2pub.customer_profile_rec_type;
        l_cpamt_rec                   hz_customer_profile_v2pub.cust_profile_amt_rec_type;
        lx_org_party_id               NUMBER := 0;
        lx_cust_account_id            NUMBER := 0;
        lx_profile_id                 NUMBER := 0;
        ln_cust_acct_profile_amt_id   NUMBER;
        ln_collector_id               NUMBER;
        ln_profile_class_id           NUMBER;
        ln_stmt_cycle_id              NUMBER;
        lc_profile_class              VARCHAR2 (250);
        lc_customer_classification    VARCHAR2 (250);
        lc_demand_class               VARCHAR2 (250);
        lc_brand                      VARCHAR2 (250) := NULL;
        lc_sales_channel              VARCHAR2 (250);
        lc_customer_account_profile   VARCHAR2 (250);
        lc_price_list                 VARCHAR2 (250);
        lc_order_type                 VARCHAR2 (250);
        lc_payment_terms              VARCHAR2 (250);
        lc_sales_person               VARCHAR2 (250);
        lc_auto_email_order_ack       VARCHAR2 (250);
        lc_auto_email_invoice         VARCHAR2 (250);
        lc_auto_email_soa             VARCHAR2 (250);
        lc_auto_generate_asn          VARCHAR2 (250);
        lc_preauthorized_cc_limit     NUMBER;
        lc_posd_date_check_limit      NUMBER;
        lc_recourse_limit             NUMBER;
        lc_payment_plan               VARCHAR2 (250);
        lc_payment_exp_date           DATE;
        lc_put_on_past_cancel_hold    VARCHAR2 (250);
        lc_edi_print_flag             VARCHAR2 (250);
        x_return_status               VARCHAR2 (250);

        --Site account values
        lc_site_revenue_account       VARCHAR2 (250);
        lc_site_freight_account       VARCHAR2 (250);
        lc_site_tax_account           VARCHAR2 (250);
        lc_site_unearn_rev_account    VARCHAR2 (250);
        lc_party_type                 VARCHAR2 (250);
        ln_cnt                        NUMBER;
    BEGIN
        --    fnd_client_info.set_org_context('84');
        --    g_process := 'create_customer';
        OPEN cur_customer (p_party_type => 'PERSON');

        LOOP
            --      SAVEPOINT INSERT_TABLE2;
            FETCH cur_customer BULK COLLECT INTO lt_customer_data LIMIT 50;

            EXIT WHEN lt_customer_data.COUNT = 0;

            IF lt_customer_data.COUNT > 0
            THEN
                FOR xc_customer_idx IN lt_customer_data.FIRST ..
                                       lt_customer_data.LAST
                LOOP
                    IF (lt_customer_data (xc_customer_idx).customer_name IS NOT NULL)
                    THEN
                        log_records (
                            gc_debug_flag,
                               'create_customer  Working on the customer '
                            || lt_customer_data (xc_customer_idx).customer_name);
                        gc_customer_name   :=
                            lt_customer_data (xc_customer_idx).customer_name;

                        BEGIN
                            SELECT hp.party_id, hzc.cust_account_id
                              INTO lx_org_party_id, lx_cust_account_id
                              FROM hz_parties hp, hz_cust_accounts hzc
                             WHERE     hp.party_id = hzc.party_id
                                   AND hp.party_type = 'PERSON'
                                   AND hzc.orig_system_reference =
                                       TO_CHAR (
                                           lt_customer_data (xc_customer_idx).customer_id);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lx_org_party_id      := 0;
                                lx_cust_account_id   := 0;
                                log_records (
                                    gc_debug_flag,
                                       lt_customer_data (xc_customer_idx).customer_name
                                    || ' Customer not found in DB ');
                            WHEN OTHERS
                            THEN
                                lx_org_party_id   := 0;
                                lx_org_party_id   := 0;
                                log_records (
                                    gc_debug_flag,
                                       'create_customer : '
                                    || lt_customer_data (xc_customer_idx).customer_name
                                    || ' '
                                    || SQLERRM);
                        END;

                        IF lx_cust_account_id > 0
                        THEN
                            BEGIN
                                SELECT cust_account_profile_id
                                  INTO lx_profile_id
                                  FROM hz_customer_profiles
                                 WHERE     cust_account_id =
                                           lx_cust_account_id
                                       AND site_use_id IS NULL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lx_profile_id   := 0;
                            END;

                            IF lx_profile_id = 0
                            THEN
                                OPEN lcu_cust_profile (
                                    lt_customer_data (xc_customer_idx).customer_id,
                                    NULL);

                                FETCH lcu_cust_profile
                                    INTO lr_cust_profile_rec;

                                CLOSE lcu_cust_profile;

                                BEGIN
                                    lc_profile_class   := NULL;

                                    SELECT profile_class
                                      INTO lc_profile_class
                                      FROM xxd_ret_n_int_cust_map
                                     WHERE     customer_number =
                                               lt_customer_data (
                                                   xc_customer_idx).customer_number
                                           AND organization_name =
                                               p_operating_unit;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;

                                ln_profile_class_id       := NULL;

                                IF lc_profile_class IS NOT NULL
                                THEN
                                    OPEN lcu_fetch_profile_class_id (
                                        lc_profile_class);

                                    FETCH lcu_fetch_profile_class_id
                                        INTO ln_profile_class_id;

                                    CLOSE lcu_fetch_profile_class_id;
                                END IF;

                                IF ln_profile_class_id IS NULL
                                THEN
                                    --Fetching profile class id
                                    OPEN lcu_fetch_profile_class_id (
                                        lr_cust_profile_rec.customer_profile_class_name);

                                    --                        OPEN  lcu_fetch_profile_class_id (lc_customer_account_profile);
                                    FETCH lcu_fetch_profile_class_id
                                        INTO ln_profile_class_id;

                                    CLOSE lcu_fetch_profile_class_id;
                                -- validation
                                END IF;

                                lr_customer_profile_rec   := NULL;

                                IF lr_cust_profile_rec.customer_profile_id
                                       IS NOT NULL
                                THEN
                                    ln_collector_id            := NULL;

                                    IF lr_cust_profile_rec.collector_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_fetch_collector_id (
                                            lr_cust_profile_rec.collector_name);

                                        FETCH lcu_fetch_collector_id
                                            INTO ln_collector_id;

                                        CLOSE lcu_fetch_collector_id;

                                        IF ln_collector_id IS NULL
                                        THEN
                                            log_records (
                                                gc_debug_flag,
                                                   ' Collector Name (Site level) '
                                                || lr_cust_profile_rec.collector_name
                                                || ' not setup in R12 ');
                                        END IF;
                                    END IF;

                                    ln_dunning_letter_set_id   := NULL;

                                    IF lr_cust_profile_rec.dunning_letter_set_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_dunning_letter_set_id (
                                            lr_cust_profile_rec.dunning_letter_set_name);

                                        FETCH lcu_dunning_letter_set_id
                                            INTO ln_dunning_letter_set_id;

                                        CLOSE lcu_dunning_letter_set_id;

                                        IF ln_dunning_letter_set_id IS NULL
                                        THEN
                                            NULL; --ln_dunning_letter_set_id validation
                                        END IF;
                                    END IF;

                                    ln_statement_cycle_id      := NULL;

                                    IF lr_cust_profile_rec.statement_cycle_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_statement_cycle_id (
                                            lr_cust_profile_rec.statement_cycle_name);

                                        FETCH lcu_statement_cycle_id
                                            INTO ln_statement_cycle_id;

                                        CLOSE lcu_statement_cycle_id;

                                        IF ln_statement_cycle_id IS NULL
                                        THEN
                                            NULL;
                                        END IF;
                                    END IF;

                                    ln_grouping_rule_id        := NULL;

                                    IF lr_cust_profile_rec.grouping_rule_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_grouping_rule_id (
                                            lr_cust_profile_rec.grouping_rule_name);

                                        FETCH lcu_grouping_rule_id
                                            INTO ln_grouping_rule_id;

                                        CLOSE lcu_grouping_rule_id;

                                        IF ln_grouping_rule_id IS NULL
                                        THEN
                                            NULL;
                                        END IF;
                                    END IF;

                                    ln_standard_terms_id       := NULL;

                                    IF lr_cust_profile_rec.standard_terms_name
                                           IS NOT NULL
                                    THEN
                                        OPEN lcu_get_standard_terms_id (
                                            lr_cust_profile_rec.standard_terms_name);

                                        FETCH lcu_get_standard_terms_id
                                            INTO ln_standard_terms_id;

                                        CLOSE lcu_get_standard_terms_id;

                                        IF ln_standard_terms_id IS NULL
                                        THEN
                                            NULL;            --raise the error
                                        END IF;
                                    END IF;

                                    lr_customer_profile_rec    := NULL;
                                    lr_customer_profile_rec.cust_account_id   :=
                                        lx_cust_account_id;
                                    lr_customer_profile_rec.profile_class_id   :=
                                        ln_profile_class_id;
                                    lr_customer_profile_rec.collector_id   :=
                                        ln_collector_id;
                                    lr_customer_profile_rec.account_status   :=
                                        lr_cust_profile_rec.account_status;
                                    lr_customer_profile_rec.auto_rec_incl_disputed_flag   :=
                                        lr_cust_profile_rec.auto_rec_incl_disputed_flag;
                                    lr_customer_profile_rec.charge_on_finance_charge_flag   :=
                                        lr_cust_profile_rec.charge_on_finance_charge_flag;
                                    lr_customer_profile_rec.clearing_days   :=
                                        lr_cust_profile_rec.clearing_days;
                                    lr_customer_profile_rec.credit_balance_statements   :=
                                        lr_cust_profile_rec.credit_balance_statements;
                                    lr_customer_profile_rec.credit_checking   :=
                                        lr_cust_profile_rec.credit_checking;

                                    IF lr_cust_profile_rec.cons_inv_flag =
                                       'Y'
                                    THEN
                                        lr_customer_profile_rec.cons_inv_flag   :=
                                            lr_cust_profile_rec.cons_inv_flag;
                                        lr_customer_profile_rec.cons_inv_type   :=
                                            lr_cust_profile_rec.cons_inv_type;
                                        lr_customer_profile_rec.cons_bill_level   :=
                                            lr_cust_profile_rec.cons_bill_level;
                                    END IF;

                                    lr_customer_profile_rec.tolerance   :=
                                        lr_cust_profile_rec.tolerance;
                                    lr_customer_profile_rec.discount_grace_days   :=
                                        lr_cust_profile_rec.discount_grace_days;
                                    lr_customer_profile_rec.payment_grace_days   :=
                                        lr_cust_profile_rec.payment_grace_days;
                                    lr_customer_profile_rec.attribute1   :=
                                        lr_cust_profile_rec.attribute1;
                                    lr_customer_profile_rec.attribute2   :=
                                        lr_cust_profile_rec.attribute2;
                                    lr_customer_profile_rec.credit_hold   :=
                                        lr_cust_profile_rec.credit_hold;
                                    lr_customer_profile_rec.credit_rating   :=
                                        lr_cust_profile_rec.credit_rating;
                                    lr_customer_profile_rec.dunning_letters   :=
                                        lr_cust_profile_rec.dunning_letters;
                                    lr_customer_profile_rec.dunning_letter_set_id   :=
                                        ln_dunning_letter_set_id;
                                    lr_customer_profile_rec.grouping_rule_id   :=
                                        ln_grouping_rule_id;
                                    lr_customer_profile_rec.interest_period_days   :=
                                        lr_cust_profile_rec.interest_period_days;
                                    lr_customer_profile_rec.lockbox_matching_option   :=
                                        lr_cust_profile_rec.lockbox_matching_option;
                                    lr_customer_profile_rec.interest_charges   :=
                                        lr_cust_profile_rec.interest_charges;
                                    lr_customer_profile_rec.discount_terms   :=
                                        lr_cust_profile_rec.discount_terms;
                                    lr_customer_profile_rec.override_terms   :=
                                        lr_cust_profile_rec.override_terms;
                                    lr_customer_profile_rec.tax_printing_option   :=
                                        lr_cust_profile_rec.tax_printing_option;
                                    lr_customer_profile_rec.send_statements   :=
                                        lr_cust_profile_rec.statements;
                                    lr_customer_profile_rec.statement_cycle_id   :=
                                        ln_statement_cycle_id;
                                    lr_customer_profile_rec.standard_terms   :=
                                        ln_standard_terms_id;
                                    lr_customer_profile_rec.credit_classification   :=
                                        lr_cust_profile_rec.credit_classification;

                                    create_cust_profile (
                                        lr_customer_profile_rec,
                                        lx_profile_id,
                                        x_return_status);
                                END IF;
                            END IF;
                        END IF;

                        IF lx_cust_account_id > 0 AND lx_profile_id > 0
                        THEN
                            l_cpamt_rec.cust_account_profile_id   :=
                                lx_profile_id;

                            FOR c_profile_amt
                                IN lcu_fetch_profile_amounts (
                                       p_cust_account_id   =>
                                           lt_customer_data (xc_customer_idx).customer_id)
                            LOOP
                                BEGIN
                                    SELECT hcpa.cust_acct_profile_amt_id
                                      INTO ln_cust_acct_profile_amt_id
                                      FROM hz_cust_profile_amts hcpa
                                     WHERE     hcpa.cust_account_profile_id =
                                               lx_profile_id
                                           AND currency_code =
                                               c_profile_amt.currency_code;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_cust_acct_profile_amt_id   := 0;
                                END;

                                IF ln_cust_acct_profile_amt_id = 0
                                THEN
                                    ln_cnt   := NULL;

                                    SELECT COUNT (*)
                                      INTO ln_cnt
                                      FROM xxd_conv.xx_exclude_legacy
                                     WHERE cust_number =
                                           lt_customer_data (xc_customer_idx).customer_number;

                                    IF ln_cnt = 0
                                    THEN
                                        l_cpamt_rec.currency_code      :=
                                            c_profile_amt.currency_code; --<< Currency Code
                                        l_cpamt_rec.created_by_module   :=
                                            'TCA_V1_API';
                                        l_cpamt_rec.trx_credit_limit   := 1; --c_profile_amt.trx_credit_limit;
                                        l_cpamt_rec.overall_credit_limit   :=
                                            1; --c_profile_amt.overall_credit_limit;

                                        l_cpamt_rec.min_dunning_amount   :=
                                            NULL; --c_profile_amt.min_dunning_amount;
                                        l_cpamt_rec.min_dunning_invoice_amount   :=
                                            NULL; --c_profile_amt.min_dunning_invoice_amount;
                                        l_cpamt_rec.min_statement_amount   :=
                                            NULL; --c_profile_amt.min_statement_amount;
                                        l_cpamt_rec.interest_type      :=
                                            'FIXED_RATE';
                                        l_cpamt_rec.interest_rate      :=
                                            NVL (c_profile_amt.interest_rate,
                                                 0);
                                        l_cpamt_rec.min_fc_balance_amount   :=
                                            c_profile_amt.min_fc_balance_amount;
                                        l_cpamt_rec.min_fc_balance_overdue_type   :=
                                            c_profile_amt.min_fc_balance_overdue_type;
                                        l_cpamt_rec.attribute_category   :=
                                            c_profile_amt.attribute_category;
                                        l_cpamt_rec.attribute1         :=
                                            c_profile_amt.attribute1;
                                        l_cpamt_rec.attribute2         :=
                                            c_profile_amt.attribute2;
                                        l_cpamt_rec.attribute3         :=
                                            c_profile_amt.attribute3;
                                        l_cpamt_rec.attribute4         :=
                                            c_profile_amt.attribute4;
                                        l_cpamt_rec.attribute5         :=
                                            c_profile_amt.attribute5;
                                        l_cpamt_rec.attribute6         :=
                                            c_profile_amt.attribute6;
                                        l_cpamt_rec.attribute7         :=
                                            c_profile_amt.attribute7;
                                        l_cpamt_rec.attribute8         :=
                                            c_profile_amt.attribute8;
                                        l_cpamt_rec.attribute9         :=
                                            c_profile_amt.attribute9;
                                        l_cpamt_rec.attribute10        :=
                                            c_profile_amt.attribute10;
                                        l_cpamt_rec.attribute11        :=
                                            c_profile_amt.attribute11;
                                        l_cpamt_rec.attribute12        :=
                                            c_profile_amt.attribute12;
                                        l_cpamt_rec.cust_account_id    :=
                                            lx_cust_account_id; --<<value for cust_account_id from step 2a
                                        create_cust_profile_amt (
                                            p_cpamt_rec => l_cpamt_rec);
                                    ELSE
                                        l_cpamt_rec.currency_code   :=
                                            c_profile_amt.currency_code; --<< Currency Code
                                        l_cpamt_rec.created_by_module   :=
                                            'TCA_V1_API';
                                        l_cpamt_rec.trx_credit_limit   :=
                                            c_profile_amt.trx_credit_limit;
                                        l_cpamt_rec.overall_credit_limit   :=
                                            c_profile_amt.overall_credit_limit;
                                        l_cpamt_rec.min_dunning_amount   :=
                                            c_profile_amt.min_dunning_amount;
                                        l_cpamt_rec.min_dunning_invoice_amount   :=
                                            c_profile_amt.min_dunning_invoice_amount;
                                        l_cpamt_rec.min_statement_amount   :=
                                            c_profile_amt.min_statement_amount;
                                        l_cpamt_rec.interest_type   :=
                                            'FIXED_RATE';
                                        l_cpamt_rec.interest_rate   :=
                                            NVL (c_profile_amt.interest_rate,
                                                 0);
                                        l_cpamt_rec.min_fc_balance_amount   :=
                                            c_profile_amt.min_fc_balance_amount;
                                        l_cpamt_rec.min_fc_balance_overdue_type   :=
                                            c_profile_amt.min_fc_balance_overdue_type;
                                        l_cpamt_rec.attribute_category   :=
                                            c_profile_amt.attribute_category;
                                        l_cpamt_rec.attribute1   :=
                                            c_profile_amt.attribute1;
                                        l_cpamt_rec.attribute2   :=
                                            c_profile_amt.attribute2;
                                        l_cpamt_rec.attribute3   :=
                                            c_profile_amt.attribute3;
                                        l_cpamt_rec.attribute4   :=
                                            c_profile_amt.attribute4;
                                        l_cpamt_rec.attribute5   :=
                                            c_profile_amt.attribute5;
                                        l_cpamt_rec.attribute6   :=
                                            c_profile_amt.attribute6;
                                        l_cpamt_rec.attribute7   :=
                                            c_profile_amt.attribute7;
                                        l_cpamt_rec.attribute8   :=
                                            c_profile_amt.attribute8;
                                        l_cpamt_rec.attribute9   :=
                                            c_profile_amt.attribute9;
                                        l_cpamt_rec.attribute10   :=
                                            c_profile_amt.attribute10;
                                        l_cpamt_rec.attribute11   :=
                                            c_profile_amt.attribute11;
                                        l_cpamt_rec.attribute12   :=
                                            c_profile_amt.attribute12;
                                        l_cpamt_rec.cust_account_id   :=
                                            lx_cust_account_id; --<<value for cust_account_id from step 2a
                                        create_cust_profile_amt (
                                            p_cpamt_rec => l_cpamt_rec);
                                    END IF;
                                END IF;
                            END LOOP;
                        END IF;

                        log_records (
                            gc_debug_flag,
                            ' Calling create_contacts_records for the customer  ');

                        IF (lx_cust_account_id > 0 AND lx_org_party_id > 0)
                        THEN
                            create_contacts_records (
                                pn_customer_id        =>
                                    lt_customer_data (xc_customer_idx).customer_id,
                                p_party_id            => lx_org_party_id,
                                p_address_id          => NULL,
                                p_party_site_id       => NULL,
                                p_cust_account_id     => lx_cust_account_id,
                                p_cust_acct_site_id   => NULL);
                        END IF;

                        IF lx_org_party_id > 0 AND lx_cust_account_id > 0
                        THEN
                            UPDATE xxd_ar_customer_dlt_stg_t
                               SET record_status = gc_process_status, request_id = gn_conc_request_id
                             WHERE customer_id =
                                   lt_customer_data (xc_customer_idx).customer_id;

                            UPDATE xxd_ar_cust_prof_dlt_stg_t
                               SET record_status   = gc_process_status
                             WHERE     site_use_id IS NULL
                                   AND orig_system_customer_ref =
                                       lt_customer_data (xc_customer_idx).customer_id;

                            UPDATE xxd_ar_cust_profamt_dlt_stg_t
                               SET record_status   = gc_process_status
                             WHERE     site_use_id IS NULL
                                   AND customer_id =
                                       lt_customer_data (xc_customer_idx).customer_id;
                        ELSE
                            UPDATE xxd_ar_customer_dlt_stg_t
                               SET record_status = gc_error_status, request_id = gn_conc_request_id
                             WHERE customer_id =
                                   lt_customer_data (xc_customer_idx).customer_id;

                            UPDATE xxd_ar_cust_prof_dlt_stg_t
                               SET record_status   = gc_error_status
                             WHERE     site_use_id IS NULL
                                   AND orig_system_customer_ref =
                                       lt_customer_data (xc_customer_idx).customer_id;

                            UPDATE xxd_ar_cust_profamt_dlt_stg_t
                               SET record_status   = gc_error_status
                             WHERE     site_use_id IS NULL
                                   AND customer_id =
                                       lt_customer_data (xc_customer_idx).customer_id;

                            lx_org_party_id      := 0;
                            lx_cust_account_id   := 0;
                        END IF;

                        COMMIT;
                        log_records (
                            gc_debug_flag,
                               ' Calling create_cust_address to for customer '
                            || lt_customer_data (xc_customer_idx).customer_name);

                        IF lx_org_party_id > 0 AND lx_cust_account_id > 0
                        THEN
                            create_cust_address (
                                p_action            => p_action,
                                p_customer_id       =>
                                    lt_customer_data (xc_customer_idx).customer_id,
                                p_new_party_id      => lx_org_party_id,
                                p_cust_account_id   => lx_cust_account_id);

                            log_records (
                                gc_debug_flag,
                                   ' Calling create_cust_site_use to for customer '
                                || lt_customer_data (xc_customer_idx).customer_name);

                            IF     UPPER (
                                       lt_customer_data (xc_customer_idx).customer_attr_category) =
                                   'PERSON'
                               AND lt_customer_data (xc_customer_idx).customer_attribute18
                                       IS NOT NULL
                            THEN
                                lc_site_revenue_account      := NULL;
                                lc_site_freight_account      := NULL;
                                lc_site_tax_account          := NULL;
                                lc_site_unearn_rev_account   := NULL;
                                lc_party_type                := 'ECOMMERCE';

                                BEGIN
                                    SELECT attribute3, attribute4, attribute5,
                                           attribute6
                                      INTO lc_site_revenue_account, lc_site_freight_account, lc_site_tax_account, lc_site_unearn_rev_account
                                      FROM fnd_flex_value_sets ffs, fnd_flex_values ffv
                                     WHERE     flex_value_set_name =
                                               'XXDO_ECOMM_WEB_SITES'
                                           AND ffs.flex_value_set_id =
                                               ffv.flex_value_set_id
                                           AND flex_value =
                                               lt_customer_data (
                                                   xc_customer_idx).customer_attribute18;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        NULL;
                                    WHEN OTHERS
                                    THEN
                                        NULL;
                                END;
                            END IF;

                            create_cust_site_use (
                                p_action             => p_action,
                                p_customer_id        =>
                                    lt_customer_data (xc_customer_idx).customer_id,
                                p_party_type         => lc_party_type,
                                p_site_revenue_account   =>
                                    lc_site_revenue_account,
                                p_site_freight_account   =>
                                    lc_site_freight_account,
                                p_site_tax_account   => lc_site_tax_account,
                                p_site_unearn_rev_account   =>
                                    lc_site_unearn_rev_account);
                        END IF;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Un-expecetd Error in  create_customer => ' || SQLERRM);
            ROLLBACK;
    END create_person;

    /*****************************************************************************************
     *  Procedure Name :   VALIDATE_CUSTOMERS                                               *
     *                                                                                       *
     *  Description    :   This Procedure shall validates the customer tables      *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
     *  p_customer_id    IN       Header Stage table ref orig_sys_header_ref         *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
      *****************************************************************************************/
    PROCEDURE validate_customer (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_batch_id IN NUMBER)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_customer (p_action VARCHAR2)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_customer_dlt_stg_t
             WHERE record_status = p_action;

        --AND BATCH_NUMBER  = p_batch_id;

        TYPE lt_customer_typ IS TABLE OF cur_customer%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_customer_data     lt_customer_typ;

        lc_cust_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count             NUMBER := 0;
    BEGIN
        log_records (p_debug, 'validate_customer');

        OPEN cur_customer (p_action => p_action);

        LOOP
            FETCH cur_customer BULK COLLECT INTO lt_customer_data LIMIT 1000;

            IF lt_customer_data.COUNT > 0
            THEN
                FOR xc_customer_idx IN lt_customer_data.FIRST ..
                                       lt_customer_data.LAST
                LOOP
                    log_records (
                        p_debug,
                           'Start validation for Custoemr'
                        || lt_customer_data (xc_customer_idx).customer_name);
                    -- Check the customer already in the 12 2 3 system

                    lc_cust_valid_data   := gc_yes_flag;

                    SELECT COUNT (1)
                      INTO ln_count
                      FROM xxd_conv.xx_exclude_legacy
                     WHERE cust_number =
                           lt_customer_data (xc_customer_idx).customer_number;

                    IF ln_count > 0
                    THEN
                        SELECT COUNT (*)
                          INTO ln_count
                          FROM xxd_cust_gl_acc_segment_map_t
                         WHERE customer_number =
                               lt_customer_data (xc_customer_idx).customer_number;

                        IF ln_count = 0
                        THEN
                            SELECT COUNT (*)
                              INTO ln_count
                              FROM xxd_ret_n_int_cust_map
                             WHERE customer_number =
                                   lt_customer_data (xc_customer_idx).customer_number;
                        END IF;

                        IF ln_count = 0
                        THEN
                            lc_cust_valid_data   := gc_no_flag;
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Delta Conversion Program',
                                p_error_msg    =>
                                       'Account Mapping not found for the customer-account '
                                    || lt_customer_data (xc_customer_idx).customer_number,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_customer',
                                p_more_info2   => gc_customer_name,
                                p_more_info3   => 'ACCOUNT_TYPE',
                                p_more_info4   => NULL);
                        END IF;
                    END IF;

                    IF lt_customer_data (xc_customer_idx).orig_system_party_ref
                           IS NULL
                    THEN
                        lc_cust_valid_data   := gc_no_flag;

                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Delta Conversion Program',
                            p_error_msg    =>
                                'Exception Raised in ORIG_SYSTEM_PARTY_REF Validation',
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_customer',
                            p_more_info2   => 'ORIG_SYSTEM_PARTY_REF',
                            p_more_info3   => gc_customer_name,
                            p_more_info4   => NULL);
                    END IF;                          --- ORIG_SYSTEM_PARTY_REF

                    IF lt_customer_data (xc_customer_idx).customer_status NOT IN
                           ('A', 'I')
                    THEN
                        lc_cust_valid_data   := gc_no_flag;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Exception Raised in CUSTOMER_STATUS Validation');
                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Delta Conversion Program',
                            p_error_msg    =>
                                'Exception Raised in CUSTOMER_STATUS Validation',
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_customer',
                            p_more_info2   => 'CUSTOMER_STATUS',
                            p_more_info3   => gc_customer_name,
                            p_more_info4   => NULL);
                    END IF;                                  --CUSTOMER_STATUS


                    --CUSTOMER_TYPE Validation
                    BEGIN
                        SELECT DISTINCT 1
                          INTO ln_count
                          FROM ar_lookups
                         WHERE     lookup_code =
                                   NVL (
                                       lt_customer_data (xc_customer_idx).customer_type,
                                       'R')
                               AND lookup_type = 'CUSTOMER_TYPE';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_cust_valid_data   := gc_no_flag;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Exception Raised in CUSTOMER_TYPE Validation');
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Delta Conversion Program',
                                p_error_msg    =>
                                       'Exception Raised in CUSTOMER_TYPE Validation '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_customer',
                                p_more_info2   => 'CUSTOMER_TYPE',
                                p_more_info3   => gc_customer_name,
                                p_more_info4   => NULL);
                        WHEN OTHERS
                        THEN
                            lc_cust_valid_data   := gc_no_flag;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Exception Raised in CUSTOMER_TYPE Validation');
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Delta Conversion Program',
                                p_error_msg    =>
                                       'Exception Raised in CUSTOMER_TYPE Validation '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_customer',
                                p_more_info2   => 'CUSTOMER_TYPE',
                                p_more_info3   => gc_customer_name,
                                p_more_info4   => NULL);
                    END;

                    -- CUSTOMER_CATEGORY Validation
                    IF lt_customer_data (xc_customer_idx).customer_category_code
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT DISTINCT 1
                              INTO ln_count
                              FROM ar_lookups
                             WHERE     lookup_code =
                                       lt_customer_data (xc_customer_idx).customer_category_code
                                   AND lookup_type = 'CUSTOMER_CATEGORY';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception Raised in CUSTOMER_CATEGORY Validation');
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Delta Conversion Program',
                                    p_error_msg    =>
                                           'Exception Raised in CUSTOMER_CATEGORY Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CUSTOMER_CATEGORY',
                                    p_more_info3   => gc_customer_name,
                                    p_more_info4   => NULL);
                            WHEN OTHERS
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception Raised in CUSTOMER_CATEGORY Validation');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception Raised in CUSTOMER_CATEGORY Validation');
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Delta Conversion Program',
                                    p_error_msg    =>
                                           'Exception Raised in CUSTOMER_CATEGORY Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CUSTOMER_CATEGORY',
                                    p_more_info3   => gc_customer_name,
                                    p_more_info4   => NULL);
                        END;
                    END IF;

                    log_records (gc_debug_flag, 'validate CUSTOMER_CLASS');

                    --CUSTOMER CLASS Validation
                    IF lt_customer_data (xc_customer_idx).customer_class_code
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT DISTINCT 1
                              INTO ln_count
                              FROM ar_lookups
                             WHERE     lookup_code =
                                       lt_customer_data (xc_customer_idx).customer_class_code
                                   AND lookup_type = 'CUSTOMER CLASS';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception Raised in CUSTOMER CLASS Validation');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception Raised in CUSTOMER CLASS Validation');
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Delta Conversion Program',
                                    p_error_msg    =>
                                           'Exception Raised in CUSTOMER CLASS Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CUSTOMER CLASS',
                                    p_more_info3   => gc_customer_name,
                                    p_more_info4   => NULL);
                            WHEN OTHERS
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception Raised in CUSTOMER CLASS Validation');
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Delta Conversion Program',
                                    p_error_msg    =>
                                           'Exception Raised in CUSTOMER CLASS Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CUSTOMER CLASS',
                                    p_more_info3   => gc_customer_name,
                                    p_more_info4   => NULL);
                        END;
                    END IF;

                    IF lt_customer_data (xc_customer_idx).person_pre_name_adjunct
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT DISTINCT 1
                              INTO ln_count
                              FROM ar_lookups
                             WHERE     lookup_code =
                                       lt_customer_data (xc_customer_idx).person_pre_name_adjunct
                                   AND lookup_type = 'CONTACT_TITLE';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                    'Exception Raised in CONTACT_TITLE  Validation');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exception Raised in CONTACT_TITLE  Validation');
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Delta Conversion Program',
                                    p_error_msg    =>
                                           'Exception Raised in CONTACT_TITLE Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CONTACT_TITLE',
                                    p_more_info3   => gc_customer_name,
                                    p_more_info4   =>
                                        lt_customer_data (xc_customer_idx).person_pre_name_adjunct);
                            WHEN OTHERS
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                    'Exception Raised in CONTACT_TITLE Validation');
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Delta Conversion Program',
                                    p_error_msg    =>
                                           'Exception Raised in CONTACT_TITLE Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CONTACT_TITLE',
                                    p_more_info3   => gc_customer_name,
                                    p_more_info4   =>
                                        lt_customer_data (xc_customer_idx).person_pre_name_adjunct);
                        END;
                    END IF;

                    IF lc_cust_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_customer_dlt_stg_t
                           SET record_status = gc_validate_status, request_id = gn_conc_request_id
                         WHERE customer_id =
                               lt_customer_data (xc_customer_idx).customer_id; -- update customer table with VALID status
                    ELSE
                        UPDATE xxd_ar_customer_dlt_stg_t
                           SET record_status = gc_error_status, request_id = gn_conc_request_id
                         WHERE customer_id =
                               lt_customer_data (xc_customer_idx).customer_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_customer%NOTFOUND;
        END LOOP;

        CLOSE cur_customer;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lc_cust_valid_data   := gc_no_flag;
            ROLLBACK;
        WHEN OTHERS
        THEN
            lc_cust_valid_data   := gc_no_flag;
            ROLLBACK;
    END validate_customer;

    /*****************************************************************************************
*  Procedure Name :   validate_cust_profile                                               *
*                                                                                       *
*  Description    :   This Procedure shall validates the customer tables      *
*                                                                                       *
*                                                                                       *
*                                                                                       *
*  Called From    :   Concurrent Program                                                *
*                                                                                       *
*  Parameters             Type       Description                                        *
*  -----------------------------------------------------------------------------        *
*  p_debug                  IN       Debug Y/N                                          *
*  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
*  p_customer_id    IN       Header Stage table ref orig_sys_header_ref         *
*                                                                                       *
* Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
*                                                                                       *
 *****************************************************************************************/
    PROCEDURE validate_cust_profile (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_batch_id IN NUMBER)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_cust_profile (p_action VARCHAR2)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_prof_dlt_stg_t xcp
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_cust_profile_typ IS TABLE OF cur_cust_profile%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_profile_data          lt_cust_profile_typ;

        CURSOR cur_cust_profile_amt (p_action VARCHAR2)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_profamt_dlt_stg_t xcp
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_cust_profile_amt_typ IS TABLE OF cur_cust_profile_amt%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_profile_amt_data      lt_cust_profile_amt_typ;

        lc_cust_profile_valid_data    VARCHAR2 (1) := gc_yes_flag;
        lc_cust_prof_amt_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                      NUMBER := 0;
    BEGIN
        log_records (p_debug, 'validate_cust_sites');

        OPEN cur_cust_profile (p_action => p_action);

        LOOP
            FETCH cur_cust_profile
                BULK COLLECT INTO lt_cust_profile_data
                LIMIT 1000;

            IF lt_cust_profile_data.COUNT > 0
            THEN
                FOR xc_cust_profile_idx IN lt_cust_profile_data.FIRST ..
                                           lt_cust_profile_data.LAST
                LOOP
                    --log_records (p_debug,'Start validation for Site Address' || lt_cust_site_use_data (xc_site_use_idx).ADDRESS1);

                    lc_cust_profile_valid_data   := gc_yes_flag;

                    IF lc_cust_profile_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cust_prof_dlt_stg_t
                           SET record_status   = gc_validate_status
                         WHERE orig_system_customer_ref =
                               lt_cust_profile_data (xc_cust_profile_idx).orig_system_customer_ref; -- update customer table with VALID status
                    ELSE
                        UPDATE xxd_ar_cust_prof_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE orig_system_customer_ref =
                               lt_cust_profile_data (xc_cust_profile_idx).orig_system_customer_ref;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_cust_profile%NOTFOUND;
        END LOOP;

        CLOSE cur_cust_profile;

        OPEN cur_cust_profile_amt (p_action => p_action);

        LOOP
            FETCH cur_cust_profile_amt
                BULK COLLECT INTO lt_cust_profile_amt_data
                LIMIT 1000;

            IF lt_cust_profile_amt_data.COUNT > 0
            THEN
                FOR xc_cust_profile_idx IN lt_cust_profile_amt_data.FIRST ..
                                           lt_cust_profile_amt_data.LAST
                LOOP
                    --log_records (p_debug,'Start validation for Site Address' || lt_cust_site_use_data (xc_site_use_idx).ADDRESS1);

                    lc_cust_prof_amt_valid_data   := gc_yes_flag;

                    IF lc_cust_prof_amt_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cust_profamt_dlt_stg_t
                           SET record_status   = gc_validate_status
                         WHERE customer_id =
                               lt_cust_profile_amt_data (xc_cust_profile_idx).customer_id; -- update customer table with VALID status
                    ELSE
                        UPDATE xxd_ar_cust_profamt_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE customer_id =
                               lt_cust_profile_amt_data (xc_cust_profile_idx).customer_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_cust_profile_amt%NOTFOUND;
        END LOOP;

        CLOSE cur_cust_profile_amt;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ROLLBACK;
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_cust_profile;

    /*****************************************************************************************
*  Procedure Name :   validate_cust_sites_use                                               *
*                                                                                       *
*  Description    :   This Procedure shall validates the customer tables      *
*                                                                                       *
*                                                                                       *
*                                                                                       *
*  Called From    :   Concurrent Program                                                *
*                                                                                       *
*  Parameters             Type       Description                                        *
*  -----------------------------------------------------------------------------        *
*  p_debug                  IN       Debug Y/N                                          *
*  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
*  p_customer_id    IN       Header Stage table ref orig_sys_header_ref         *
*                                                                                       *
* Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
*                                                                                       *
 *****************************************************************************************/
    PROCEDURE validate_contact_points (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_batch_id IN NUMBER)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_contacts (p_action VARCHAR2)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cont_point_dlt_stg_t xcp
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_contacts_typ IS TABLE OF cur_contacts%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_contacts_data         lt_contacts_typ;

        lc_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lx_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                 NUMBER := 0;
    BEGIN
        log_records (p_debug, 'validate_cust_sites');

        OPEN cur_contacts (p_action => p_action);

        LOOP
            FETCH cur_contacts BULK COLLECT INTO lt_contacts_data LIMIT 1000;

            IF lt_contacts_data.COUNT > 0
            THEN
                FOR xc_contacts_idx IN lt_contacts_data.FIRST ..
                                       lt_contacts_data.LAST
                LOOP
                    --log_records (p_debug,'Start validation for Site Address' || lt_cust_site_use_data (xc_site_use_idx).ADDRESS1);

                    lc_contacts_valid_data   := gc_yes_flag;
                    gc_cust_contact_point    :=
                        lt_contacts_data (xc_contacts_idx).telephone_type;

                    IF lt_contacts_data (xc_contacts_idx).orig_system_contact_ref
                           IS NOT NULL
                    THEN
                        IF (lt_contacts_data (xc_contacts_idx).contact_first_name IS NULL AND lt_contacts_data (xc_contacts_idx).contact_last_name IS NULL)
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Delta Conversion Program',
                                p_error_msg    =>
                                    'Exception Raised in CONTACT_FIRST_NAME and CONTACT_LAST_NAME are null  validation',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'CONTACT_FIRST_NAME',
                                p_more_info2   => 'CONTACT_LAST_NAME',
                                p_more_info3   => gc_customer_name,
                                p_more_info4   => gc_cust_address);
                        END IF;
                    END IF;

                    IF     lt_contacts_data (xc_contacts_idx).telephone_type
                               IS NOT NULL
                       AND lt_contacts_data (xc_contacts_idx).telephone_type <>
                           'EMAIL'
                    THEN
                        BEGIN
                            SELECT 1
                              INTO ln_count
                              FROM ar_lookups          -- fnd_lookup_values_vl
                             WHERE     lookup_type = 'PHONE_LINE_TYPE'
                                   AND lookup_code =
                                       lt_contacts_data (xc_contacts_idx).telephone_type;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_contacts_valid_data   := gc_no_flag;
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Delta Conversion Program',
                                    p_error_msg    =>
                                           'Exception Raised in PHONE_LINE_TYPE validation =>'
                                        || lt_contacts_data (xc_contacts_idx).telephone_type,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'TELEPHONE_TYPE',
                                    p_more_info2   =>
                                        lt_contacts_data (xc_contacts_idx).telephone_type,
                                    p_more_info3   => gc_customer_name,
                                    p_more_info4   => gc_cust_address);
                            WHEN OTHERS
                            THEN
                                lc_contacts_valid_data   := gc_no_flag;
                        END;
                    END IF;

                    IF lc_contacts_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cont_point_dlt_stg_t
                           SET record_status   = gc_validate_status
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref -- need to add conct ref also in where
                               AND orig_system_telephone_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref; -- update contact_ponit table with VALID status
                    ELSE
                        UPDATE xxd_ar_cont_point_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref -- need to add conct ref also in where
                               AND orig_system_telephone_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref; -- update contact_ponit table with VALID status
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
    END validate_contact_points;

    /*****************************************************************************************
   *  Procedure Name :   validate_cust_sites_use                                               *
   *                                                                                       *
   *  Description    :   This Procedure shall validates the customer tables      *
   *                                                                                       *
   *                                                                                       *
   *                                                                                       *
   *  Called From    :   Concurrent Program                                                *
   *                                                                                       *
   *  Parameters             Type       Description                                        *
   *  -----------------------------------------------------------------------------        *
   *  p_debug                  IN       Debug Y/N                                          *
   *  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
   *  p_customer_id    IN       Header Stage table ref orig_sys_header_ref         *
   *                                                                                       *
   * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
   *                                                                                       *
    *****************************************************************************************/
    PROCEDURE validate_cust_contacts (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_batch_id IN NUMBER)
    --                                                         ,p_address_id    IN NUMBER)

    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_contacts (p_action VARCHAR2)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_contact_dlt_stg_t xcp
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_contacts_typ IS TABLE OF cur_contacts%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_contacts_data         lt_contacts_typ;

        lc_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lx_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                 NUMBER := 0;
    BEGIN
        log_records (p_debug, 'validate_cust_sites');

        OPEN cur_contacts (p_action => p_action);

        LOOP
            FETCH cur_contacts BULK COLLECT INTO lt_contacts_data LIMIT 1000;

            IF lt_contacts_data.COUNT > 0
            THEN
                FOR xc_contacts_idx IN lt_contacts_data.FIRST ..
                                       lt_contacts_data.LAST
                LOOP
                    lc_contacts_valid_data   := gc_yes_flag;
                    gc_cust_contact          :=
                        lt_contacts_data (xc_contacts_idx).contact_first_name;

                    IF lc_contacts_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_contact_dlt_stg_t
                           SET record_status   = gc_validate_status
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref -- need to add conct ref also in where
                               AND orig_system_contact_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_contact_ref; -- update contacts table with VALID status
                    ELSE                                     --gc_error_status
                        UPDATE xxd_ar_contact_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref -- need to add conct ref also in where
                               AND orig_system_contact_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_contact_ref; -- update contacts table with VALID status
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

    /*****************************************************************************************
   *  Procedure Name :   validate_cust_sites_use                                               *
   *                                                                                       *
   *  Description    :   This Procedure shall validates the customer tables      *
   *                                                                                       *
   *                                                                                       *
   *                                                                                       *
   *  Called From    :   Concurrent Program                                                *
   *                                                                                       *
   *  Parameters             Type       Description                                        *
   *  -----------------------------------------------------------------------------        *
   *  p_debug                  IN       Debug Y/N                                          *
   *  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
   *  p_customer_id    IN       Header Stage table ref orig_sys_header_ref         *
   *                                                                                       *
   * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
   *                                                                                       *
    *****************************************************************************************/
    PROCEDURE validate_cust_sites_use (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_batch_id IN NUMBER)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_cust_site_use (p_action VARCHAR2)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   DISTINCT source_org_id
              FROM xxd_ar_cust_siteuse_dlt_stg_t xcsu
             WHERE record_status IN (gc_new_status, gc_error_status);

        --AND customer_id = p_customer_id;
        --              AND  site_use_id =  p_site_use_id;

        TYPE lt_cust_site_use_typ IS TABLE OF cur_cust_site_use%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_site_use_data    lt_cust_site_use_typ;

        lc_site_use_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lx_site_use_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                 NUMBER := 0;
        ln_target_org_id         NUMBER := 0;
        ln_target_org            VARCHAR2 (250);
    BEGIN
        log_records (p_debug, 'validate_cust_sites_use');

        OPEN cur_cust_site_use (p_action => p_action);

        LOOP
            FETCH cur_cust_site_use
                BULK COLLECT INTO lt_cust_site_use_data
                LIMIT 1000;

            IF lt_cust_site_use_data.COUNT > 0
            THEN
                FOR xc_site_use_idx IN lt_cust_site_use_data.FIRST ..
                                       lt_cust_site_use_data.LAST
                LOOP
                    lc_site_use_valid_data   := gc_yes_flag;

                    ln_target_org_id         :=
                        get_org_id (
                            p_1206_org_id   =>
                                lt_cust_site_use_data (xc_site_use_idx).source_org_id);

                    --
                    --                   IF lt_cust_site_data (xc_site_idx).TARGET_ORG IS NULL THEN
                    IF ln_target_org_id IS NULL
                    THEN
                        lc_site_use_valid_data   := gc_no_flag;
                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Delta Conversion Program',
                            p_error_msg    =>
                                   'Exception Raised in TARGET_ORG Validation  Mapping not defined for the Organization =>'
                                || lt_cust_site_use_data (xc_site_use_idx).source_org_id,
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_cust_sites',
                            p_more_info2   => 'TARGET_ORG',
                            p_more_info3   => gc_customer_name,
                            p_more_info4   => gc_cust_address);
                    END IF;

                    IF lc_site_use_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cust_siteuse_dlt_stg_t
                           SET record_status = gc_validate_status, target_org = ln_target_org_id
                         WHERE     source_org_id =
                                   lt_cust_site_use_data (xc_site_use_idx).source_org_id
                               AND record_status = gc_new_status;
                    --                    WHERE customer_id =     lt_cust_site_use_data (xc_site_use_idx).customer_id
                    --                          AND  site_use_id = lt_cust_site_use_data (xc_site_use_idx).site_use_id;-- update site use table with VALID status
                    ELSE
                        UPDATE xxd_ar_cust_siteuse_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE     source_org_id =
                                   lt_cust_site_use_data (xc_site_use_idx).source_org_id
                               AND record_status = gc_new_status;
                    --                    WHERE customer_id =     lt_cust_site_use_data (xc_site_use_idx).customer_id
                    --                          AND  site_use_id = lt_cust_site_use_data (xc_site_use_idx).site_use_id;-- update site use table with VALID status
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_cust_site_use%NOTFOUND;
        END LOOP;

        CLOSE cur_cust_site_use;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            log_records (p_debug, 'validate_cust_sites_use' || SQLERRM);
            ROLLBACK;
        WHEN OTHERS
        THEN
            log_records (p_debug, 'validate_cust_sites_use' || SQLERRM);
            ROLLBACK;
    END validate_cust_sites_use;

    /*****************************************************************************************
   *  Procedure Name :   validate_cust_sites                                               *
   *                                                                                       *
   *  Description    :   This Procedure shall validates the customer tables      *
   *                                                                                       *
   *                                                                                       *
   *                                                                                       *
   *  Called From    :   Concurrent Program                                                *
   *                                                                                       *
   *  Parameters             Type       Description                                        *
   *  -----------------------------------------------------------------------------        *
   *  p_debug                  IN       Debug Y/N                                          *
   *  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
   *  p_customer_id    IN       Header Stage table ref orig_sys_header_ref         *
   *                                                                                       *
   * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
   *                                                                                       *
    *****************************************************************************************/
    PROCEDURE validate_cust_sites (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_batch_id IN NUMBER)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_cust_site (p_action VARCHAR2)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_sites_dlt_stg_t xcs
             WHERE record_status IN (gc_new_status, gc_error_status);

        --              AND address_id = p_address_id;

        TYPE lt_cust_site_typ IS TABLE OF cur_cust_site%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_site_data         lt_cust_site_typ;

        lc_cust_site_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lr_cust_site_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_target_org_id          NUMBER := 0;
        ln_count                  NUMBER := 0;
    BEGIN
        log_records (p_debug, 'validate_cust_sites');

        OPEN cur_cust_site (p_action => p_action);

        LOOP
            FETCH cur_cust_site
                BULK COLLECT INTO lt_cust_site_data
                LIMIT 1000;

            --CLOSE cur_cust_site;

            IF lt_cust_site_data.COUNT > 0
            THEN
                FOR xc_site_idx IN lt_cust_site_data.FIRST ..
                                   lt_cust_site_data.LAST
                LOOP
                    log_records (
                        p_debug,
                           'Start validation for Site Address'
                        || lt_cust_site_data (xc_site_idx).address1);
                    lc_cust_site_valid_data   := gc_yes_flag;

                    gc_cust_address           :=
                        lt_cust_site_data (xc_site_idx).address1;

                    IF lt_cust_site_data (xc_site_idx).address1 IS NULL
                    THEN
                        lc_cust_site_valid_data   := gc_no_flag;
                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Delta Conversion Program',
                            p_error_msg    =>
                                'Exception Raised in ADDRESS1 Validation ',
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_cust_sites',
                            p_more_info2   => 'ADDRESS1',
                            p_more_info3   => gc_customer_name,
                            p_more_info4   => gc_cust_address);
                    END IF;


                    ln_target_org_id          :=
                        get_org_id (
                            p_1206_org_id   =>
                                lt_cust_site_data (xc_site_idx).source_org_id);

                    IF ln_target_org_id IS NULL
                    THEN
                        lc_cust_site_valid_data   := gc_no_flag;
                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Delta Conversion Program',
                            p_error_msg    =>
                                   'Exception Raised in TARGET_ORG Validation  Mapping not defined for the Organization =>'
                                || lt_cust_site_data (xc_site_idx).source_org_name,
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_cust_sites',
                            p_more_info2   => 'TARGET_ORG',
                            p_more_info3   => gc_customer_name,
                            p_more_info4   => gc_cust_address);
                    END IF;

                    IF lc_cust_site_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cust_sites_dlt_stg_t
                           SET record_status = gc_validate_status, target_org = ln_target_org_id
                         WHERE     customer_id =
                                   lt_cust_site_data (xc_site_idx).customer_id
                               AND address_id =
                                   lt_cust_site_data (xc_site_idx).address_id; -- update site table with VALID status
                    ELSE
                        UPDATE xxd_ar_cust_sites_dlt_stg_t
                           SET record_status   = gc_error_status
                         WHERE     customer_id =
                                   lt_cust_site_data (xc_site_idx).customer_id
                               AND address_id =
                                   lt_cust_site_data (xc_site_idx).address_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_cust_site%NOTFOUND;
        END LOOP;

        CLOSE cur_cust_site;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ROLLBACK;
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_cust_sites;

    /****************************************************************************************
      *  Procedure Name :   pricelist_validation                                              *
      *                                                                                       *
      *  Description    :   Procedure to validate the Price lists in the stag                 *
      *                                                                                       *
      *                                                                                       *
      *  Called From    :   Concurrent Program                                                *
      *                                                                                       *
      *  Parameters             Type       Description                                        *
      *  -----------------------------------------------------------------------------        *
      *  errbuf                  OUT       Standard errbuf                                    *
      *  retcode                 OUT       Standard retcode                                   *
      *  p_batch_id               IN       Batch Number to fetch the data from header stage   *
      *  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
      *                                                                                       *
      * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
      *                                                                                       *
       *****************************************************************************************/

    PROCEDURE customer_validation (errbuf                  OUT VARCHAR2,
                                   retcode                 OUT VARCHAR2,
                                   p_action             IN     VARCHAR2,
                                   p_batch_id           IN     NUMBER,
                                   p_validation_level   IN     VARCHAR2)
    AS
        ln_count          NUMBER := 0;
        l_target_org_id   NUMBER := 0;
    BEGIN
        retcode   := NULL;
        errbuf    := NULL;
        log_records (gc_debug_flag,
                     'validate Customer p_action =.  ' || p_action);

        IF p_validation_level = 'CUSTOMER'
        THEN
            validate_customer (p_debug      => gc_debug_flag,
                               p_action     => p_action,
                               p_batch_id   => p_batch_id);
        ELSIF p_validation_level = 'SITE'
        THEN
            validate_cust_sites (p_debug      => gc_debug_flag,
                                 p_action     => p_action,
                                 p_batch_id   => p_batch_id);
        ELSIF p_validation_level = 'SITEUSE'
        THEN
            validate_cust_sites_use (p_debug      => gc_debug_flag,
                                     p_action     => p_action,
                                     p_batch_id   => p_batch_id);
        ELSIF p_validation_level = 'CONTACT'
        THEN
            validate_cust_contacts (p_debug      => gc_debug_flag,
                                    p_action     => p_action,
                                    p_batch_id   => p_batch_id);
        ELSIF p_validation_level = 'CONTACTPOINT'
        THEN
            validate_contact_points (p_debug      => gc_debug_flag,
                                     p_action     => p_action,
                                     p_batch_id   => p_batch_id);
        ELSIF p_validation_level = 'PROFILE'
        THEN
            validate_cust_profile (p_debug      => gc_debug_flag,
                                   p_action     => p_action,
                                   p_batch_id   => p_batch_id);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Raised During Price List Validation Program');
            --  ROLLBACK;
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END customer_validation;

    PROCEDURE extract_1206_data (p_source_org_id IN VARCHAR2, p_target_org_name IN VARCHAR2, x_total_rec OUT NUMBER
                                 , x_validrec_cnt OUT NUMBER, x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage            VARCHAR2 (50) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;

        CURSOR lcu_extract_count IS
            SELECT COUNT (*)
              FROM xxd_ar_customer_dlt_stg_t
             WHERE record_status = gc_new_status;

        --AND    source_org    = p_source_org_id;

        CURSOR lcu_customer_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_customer_1206_dlt_t xac
             WHERE EXISTS
                       (SELECT 1
                          FROM xxd_ar_cust_sites_dlt_stg_t xacs
                         WHERE     xacs.customer_id = xac.customer_id
                               AND xacs.record_status = gc_new_status);

        CURSOR lcu_cust_site_data (p_org_id NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_cust_sites_1206_dlt_t xacs
             WHERE     xacs.source_org_id = p_org_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_conv.xxd_ar_customer_1206_dlt_t xac
                             WHERE xacs.customer_id = xac.customer_id);

        CURSOR lcu_cust_site_use_data                      --(p_org_id NUMBER)
                                      IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_site_use_1206_dlt_t xcsu
             WHERE EXISTS
                       (SELECT 1
                          FROM xxd_ar_cust_sites_dlt_stg_t xaci
                         WHERE     xaci.customer_id = xcsu.customer_id
                               AND xaci.record_status = gc_new_status
                               AND xcsu.source_org_id = xaci.source_org_id);

        CURSOR lcu_cust_cont_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_contact_1206_dlt_t xcc
             WHERE EXISTS
                       (SELECT 1
                          FROM xxd_ar_customer_dlt_stg_t xaci
                         WHERE     xaci.customer_id =
                                   xcc.orig_system_customer_ref
                               AND xaci.customer_attribute18 IS NOT NULL
                               AND xaci.record_status = gc_new_status)
            UNION
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_contact_1206_dlt_t xcc
             WHERE EXISTS
                       (SELECT 1
                          FROM xxd_ar_customer_dlt_stg_t xaci, xxd_ret_n_int_cust_map ret
                         WHERE     xaci.customer_id =
                                   xcc.orig_system_customer_ref
                               AND xaci.customer_attribute18 IS NULL
                               AND ret.customer_number = xaci.customer_number
                               AND xaci.record_status = gc_new_status);

        CURSOR lcu_cust_cont_point_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_cont_point_1206_dlt_t xcc
             WHERE EXISTS
                       (SELECT 1
                          FROM xxd_ar_customer_dlt_stg_t xaci
                         WHERE     xaci.customer_id =
                                   xcc.orig_system_customer_ref
                               AND xaci.customer_attribute18 IS NOT NULL
                               AND xaci.record_status = gc_new_status)
            UNION
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_cont_point_1206_dlt_t xcc
             WHERE EXISTS
                       (SELECT 1
                          FROM xxd_ar_customer_dlt_stg_t xaci, xxd_ret_n_int_cust_map ret
                         WHERE     xaci.customer_id =
                                   xcc.orig_system_customer_ref
                               AND xaci.customer_attribute18 IS NULL
                               AND ret.customer_number = xaci.customer_number
                               AND xaci.record_status = gc_new_status);

        CURSOR lcu_cust_prof_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   acpv.*
              FROM xxd_conv.xxd_ar_cust_prof_1206_dlt_t acpv
             WHERE     EXISTS
                           (SELECT 1
                              FROM xxd_ar_customer_dlt_stg_t xai
                             WHERE     acpv.orig_system_customer_ref =
                                       xai.customer_id
                                   AND record_status = gc_new_status)
                   AND acpv.site_use_id IS NULL
            UNION
            SELECT /*+ FIRST_ROWS(10) */
                   acpv.*
              FROM xxd_conv.xxd_ar_cust_prof_1206_dlt_t acpv
             WHERE     EXISTS
                           (SELECT 1
                              FROM xxd_ar_cust_siteuse_dlt_stg_t xai
                             WHERE     acpv.orig_system_customer_ref =
                                       xai.customer_id
                                   AND acpv.site_use_id = xai.site_use_id
                                   AND record_status = gc_new_status)
                   AND acpv.site_use_id IS NOT NULL;

        CURSOR lcu_cust_prof_amt_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   xcpa.*
              FROM xxd_conv.xxd_ar_cust_profamt_1206_dlt_t xcpa
             WHERE     EXISTS
                           (SELECT 1
                              FROM xxd_ar_customer_dlt_stg_t xai
                             WHERE     xcpa.customer_id = xai.customer_id
                                   AND record_status = gc_new_status)
                   AND xcpa.site_use_id IS NULL
            UNION
            SELECT /*+ FIRST_ROWS(10) */
                   xcpa.*
              FROM xxd_conv.xxd_ar_cust_profamt_1206_dlt_t xcpa
             WHERE     EXISTS
                           (SELECT 1
                              FROM xxd_ar_cust_siteuse_dlt_stg_t xai
                             WHERE     xcpa.customer_id = xai.customer_id
                                   AND xcpa.site_use_id = xai.site_use_id
                                   AND record_status = gc_new_status)
                   AND xcpa.site_use_id IS NOT NULL;
    BEGIN
        gtt_ar_cust_int_tab.delete;
        gtt_ar_cust_site_int_tab.delete;
        gtt_ar_cust_site_use_int_tab.delete;
        gtt_ar_cust_cont_int_tab.delete;
        gtt_ar_cust_cont_point_int_tab.delete;
        gtt_ar_cust_prof_int_tab.delete;
        gtt_ar_cust_prof_amt_int_tab.delete;

        FOR lc_org
            IN (SELECT lookup_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXD_1206_OU_MAPPING'
                       AND language = 'US'
                       AND attribute1 = p_target_org_name)
        LOOP
            OPEN lcu_cust_site_data (TO_NUMBER (lc_org.lookup_code));

            LOOP
                lv_error_stage   := 'Inserting Customer Site Data';
                fnd_file.put_line (fnd_file.LOG, lv_error_stage);
                gtt_ar_cust_site_int_tab.delete;

                FETCH lcu_cust_site_data
                    BULK COLLECT INTO gtt_ar_cust_site_int_tab
                    LIMIT 5000;

                FOR site_idx IN 1 .. gtt_ar_cust_site_int_tab.COUNT
                LOOP
                    gtt_ar_cust_site_int_tab (site_idx).target_org   :=
                        get_org_id (
                            gtt_ar_cust_site_int_tab (site_idx).source_org_name);
                END LOOP;

                FORALL i IN 1 .. gtt_ar_cust_site_int_tab.COUNT
                    INSERT INTO xxd_ar_cust_sites_dlt_stg_t
                         VALUES gtt_ar_cust_site_int_tab (i);

                COMMIT;
                EXIT WHEN lcu_cust_site_data%NOTFOUND;
            END LOOP;

            CLOSE lcu_cust_site_data;
        END LOOP;

        OPEN lcu_customer_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_int_tab.delete;

            FETCH lcu_customer_data
                BULK COLLECT INTO gtt_ar_cust_int_tab
                LIMIT 5000;

            FOR cust_idx IN 1 .. gtt_ar_cust_int_tab.COUNT
            LOOP
                IF gtt_ar_cust_int_tab (cust_idx).source_org_name IS NOT NULL
                THEN
                    gtt_ar_cust_int_tab (cust_idx).target_org   :=
                        get_org_id (
                            gtt_ar_cust_int_tab (cust_idx).source_org_name);
                END IF;
            END LOOP;

            FORALL i IN 1 .. gtt_ar_cust_int_tab.COUNT
                INSERT INTO xxd_ar_customer_dlt_stg_t
                     VALUES gtt_ar_cust_int_tab (i);

            gtt_ar_cust_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_customer_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_customer_data;

        OPEN lcu_cust_site_use_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Site Use Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_site_use_int_tab.delete;

            FETCH lcu_cust_site_use_data
                BULK COLLECT INTO gtt_ar_cust_site_use_int_tab
                LIMIT 5000;

            FOR site_use_idx IN 1 .. gtt_ar_cust_site_use_int_tab.COUNT
            LOOP
                gtt_ar_cust_site_use_int_tab (site_use_idx).target_org   :=
                    get_org_id (
                        gtt_ar_cust_site_use_int_tab (site_use_idx).source_org_name);
            END LOOP;

            FORALL i IN 1 .. gtt_ar_cust_site_use_int_tab.COUNT
                INSERT INTO xxd_conv.xxd_ar_cust_siteuse_dlt_stg_t
                     VALUES gtt_ar_cust_site_use_int_tab (i);

            gtt_ar_cust_site_use_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_site_use_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_site_use_data;

        OPEN lcu_cust_cont_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Contact Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_cont_int_tab.delete;

            FETCH lcu_cust_cont_data
                BULK COLLECT INTO gtt_ar_cust_cont_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_ar_cust_cont_int_tab.COUNT
                INSERT INTO xxd_ar_contact_dlt_stg_t
                     VALUES gtt_ar_cust_cont_int_tab (i);

            gtt_ar_cust_cont_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_cont_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_cont_data;

        OPEN lcu_cust_cont_point_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Contact Point Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_cont_point_int_tab.delete;

            FETCH lcu_cust_cont_point_data
                BULK COLLECT INTO gtt_ar_cust_cont_point_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_ar_cust_cont_point_int_tab.COUNT
                INSERT INTO xxd_ar_cont_point_dlt_stg_t
                     VALUES gtt_ar_cust_cont_point_int_tab (i);

            gtt_ar_cust_cont_point_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_cont_point_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_cont_point_data;

        gtt_ar_cust_cont_point_int_tab.delete;

        OPEN lcu_cust_prof_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Profiles Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_prof_int_tab.delete;

            FETCH lcu_cust_prof_data
                BULK COLLECT INTO gtt_ar_cust_prof_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_ar_cust_prof_int_tab.COUNT
                INSERT INTO xxd_ar_cust_prof_dlt_stg_t
                     VALUES gtt_ar_cust_prof_int_tab (i);

            gtt_ar_cust_prof_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_prof_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_prof_data;

        OPEN lcu_cust_prof_amt_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Profiles Amount Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_prof_amt_int_tab.delete;

            FETCH lcu_cust_prof_amt_data
                BULK COLLECT INTO gtt_ar_cust_prof_amt_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_ar_cust_prof_amt_int_tab.COUNT
                INSERT INTO xxd_ar_cust_profamt_dlt_stg_t
                     VALUES gtt_ar_cust_prof_amt_int_tab (i);

            gtt_ar_cust_prof_amt_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_prof_amt_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_prof_amt_data;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END extract_1206_data;

    --truncte_stage_tables
    PROCEDURE truncte_stage_tables (x_ret_code      OUT VARCHAR2,
                                    x_return_mesg   OUT VARCHAR2)
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        --x_ret_code   := gn_suc_const;
        fnd_file.put_line (
            fnd_file.LOG,
            'Working on truncte_stage_tables to purge the data');

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUSTOMER_DLT_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUST_SITES_DLT_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUST_SITEUSE_DLT_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CONTACT_DLT_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CONT_POINT_DLT_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUST_PROF_DLT_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUST_PROFAMT_DLT_STG_T';

        fnd_file.put_line (fnd_file.LOG, 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            --x_ret_code      := gn_err_const;
            x_return_mesg   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Truncate Stage Table Exception t' || x_return_mesg);
            xxd_common_utils.record_error ('AR', gn_org_id, 'Deckers AR Customer Delta Conversion Program', --  SQLCODE,
                                                                                                            SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                          --   SYSDATE,
                                                                                                                                                          gn_user_id, gn_conc_request_id, 'truncte_stage_tables', NULL
                                           , x_return_mesg);
    END truncte_stage_tables;

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

    PROCEDURE customer_main_proc (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                                  , p_debug_flag IN VARCHAR2, p_no_of_process IN NUMBER, p_org_name IN VARCHAR2)
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


        TYPE request_record IS RECORD
        (
            request_id    NUMBER
        );

        TYPE request_table IS TABLE OF request_record
            INDEX BY BINARY_INTEGER;

        l_req_id                 request_table;
    BEGIN
        gc_debug_flag   := p_debug_flag;
        l_req_id.delete;

        IF p_process = gc_extract_only
        THEN
            IF p_debug_flag = 'Y'
            THEN
                gc_code_pointer   := 'Calling Extract process  ';
                fnd_file.put_line (fnd_file.LOG,
                                   'Code Pointer: ' || gc_code_pointer);
            END IF;

            truncte_stage_tables (x_ret_code      => x_retcode,
                                  x_return_mesg   => x_errbuf);
            extract_1206_data (p_source_org_id     => NULL,
                               p_target_org_name   => p_org_name,
                               x_total_rec         => x_total_rec,
                               x_validrec_cnt      => x_validrec_cnt,
                               x_errbuf            => x_errbuf,
                               x_retcode           => x_retcode);
        ELSIF p_process = gc_validate_only
        THEN
            BEGIN
                UPDATE xxd_ar_customer_dlt_stg_t
                   SET batch_number = NULL, record_status = gc_new_status
                 WHERE record_status IN (gc_new_status, gc_error_status);

                UPDATE xxd_ar_cust_sites_dlt_stg_t
                   SET record_status   = gc_new_status
                 WHERE record_status IN (gc_new_status, gc_error_status);

                UPDATE xxd_ar_cust_siteuse_dlt_stg_t
                   SET record_status   = gc_new_status
                 WHERE record_status IN (gc_new_status, gc_error_status);

                UPDATE xxd_ar_cust_prof_dlt_stg_t
                   SET record_status   = gc_new_status
                 WHERE record_status IN (gc_new_status, gc_error_status);

                UPDATE xxd_ar_cust_profamt_dlt_stg_t
                   SET record_status   = gc_new_status
                 WHERE record_status IN (gc_new_status, gc_error_status);

                UPDATE xxd_ar_contact_dlt_stg_t
                   SET record_status   = gc_new_status
                 WHERE record_status IN (gc_new_status, gc_error_status);

                UPDATE xxd_ar_cont_point_dlt_stg_t
                   SET record_status   = gc_new_status
                 WHERE record_status IN (gc_new_status, gc_error_status);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM xxd_ar_customer_dlt_stg_t
             WHERE batch_number IS NULL AND record_status = gc_new_status;

            --write_log ('Creating Batch id and update  XXD_AR_CUSTOMER_DLT_STG_T');

            -- Create batches of records and assign batch id

            lc_hdr_customer_proc_t (1)   := 'CUSTOMER';
            lc_hdr_customer_proc_t (2)   := 'PROFILE';
            lc_hdr_customer_proc_t (3)   := 'SITE';
            lc_hdr_customer_proc_t (4)   := 'SITEUSE';
            lc_hdr_customer_proc_t (5)   := 'CONTACT';
            lc_hdr_customer_proc_t (6)   := 'CONTACTPOINT';

            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT xxd_ar_cust_batch_id_s.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    log_records (
                        gc_debug_flag,
                        'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                log_records (gc_debug_flag,
                             ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                log_records (
                    gc_debug_flag,
                       'ceil( ln_valid_rec_cnt/p_no_of_process) := '
                    || CEIL (ln_valid_rec_cnt / p_no_of_process));

                UPDATE xxd_ar_customer_dlt_stg_t
                   SET batch_number = ln_hdr_batch_id (i), request_id = ln_parent_request_id
                 WHERE     batch_number IS NULL
                       AND ROWNUM <=
                           CEIL (ln_valid_rec_cnt / p_no_of_process)
                       AND record_status = gc_new_status;

                COMMIT;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_AR_CUSTOMER_DLT_STG_T');

            FOR l IN 1 .. lc_hdr_customer_proc_t.COUNT
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxd_ar_customer_dlt_stg_t
                 WHERE record_status = gc_new_status;

                l_req_id.delete;

                IF ln_cntr > 0
                THEN
                    BEGIN
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_AR_CUST_DELTA_CONV_CHILD',
                                '',
                                '',
                                FALSE,
                                p_debug_flag,
                                p_process,
                                lc_hdr_customer_proc_t (l),
                                NULL,
                                ln_parent_request_id,
                                p_org_name);
                        log_records (gc_debug_flag,
                                     'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (l).request_id   := ln_request_id;
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
                                   'Calling WAIT FOR REQUEST XXD_AR_CUST_CHILD_CONV error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_AR_CUST_CHILD_CONV error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;

            log_records (
                gc_debug_flag,
                'Calling WAIT FOR REQUEST XXD_AR_CUST_CHILD_CONV to complete');

           <<request_loop>>
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec).request_id > 0
                THEN
                   <<wait_loop>>
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec).request_id --ln_concurrent_request_id
                                                                         ,
                                interval     => 5,
                                max_wait     => 15,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);

                        IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                        THEN
                            EXIT wait_loop;
                        END IF;
                    END LOOP wait_loop;
                END IF;
            END LOOP request_loop;
        ELSIF p_process = gc_load_only
        THEN
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_AR_CUSTOMER_DLT_STG_T stage to call worker process');
            ln_cntr   := 0;

            FOR i
                IN (SELECT DISTINCT batch_number
                      FROM xxd_ar_customer_dlt_stg_t
                     WHERE     batch_number IS NOT NULL
                           AND record_status = gc_validate_status)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_number;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_AR_CUSTOMER_DLT_STG_T');

            COMMIT;

            IF ln_hdr_batch_id.COUNT > 0
            THEN
                log_records (
                    gc_debug_flag,
                       'Calling XXD_AR_CUST_CHILD_CONV in batch '
                    || ln_hdr_batch_id.COUNT);

                FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
                LOOP
                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM xxd_ar_customer_dlt_stg_t
                     WHERE batch_number = ln_hdr_batch_id (i);

                    l_req_id.delete;

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
                                    'XXD_AR_CUST_DELTA_CONV_CHILD',
                                    '',
                                    '',
                                    FALSE,
                                    p_debug_flag,
                                    p_process,
                                    NULL,
                                    ln_hdr_batch_id (i),
                                    ln_parent_request_id,
                                    p_org_name);
                            log_records (gc_debug_flag,
                                         'v_request_id := ' || ln_request_id);

                            IF ln_request_id > 0
                            THEN
                                l_req_id (i).request_id   := ln_request_id;
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
                                       'Calling WAIT FOR REQUEST XXD_AR_CUST_CHILD_CONV error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                x_retcode   := 2;
                                x_errbuf    := x_errbuf || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_AR_CUST_CHILD_CONV error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END IF;

            log_records (
                gc_debug_flag,
                'Calling XXD_AR_CUST_CHILD_CONV in batch ' || ln_hdr_batch_id.COUNT);

            log_records (
                gc_debug_flag,
                'Calling WAIT FOR REQUEST XXD_AR_CUST_CHILD_CONV to complete');

           <<request_loop>>
            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec).request_id > 0
                THEN
                   <<wait_loop>>
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec).request_id --ln_concurrent_request_id
                                                                         ,
                                interval     => 5,
                                max_wait     => 15,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);

                        IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                        THEN
                            EXIT wait_loop;
                        END IF;
                    END LOOP wait_loop;
                END IF;
            END LOOP request_loop;
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

    --Deckers AR Customer Delta Conversion Program (Worker)
    PROCEDURE customer_child (errbuf                   OUT VARCHAR2,
                              retcode                  OUT VARCHAR2,
                              p_debug_flag          IN     VARCHAR2 DEFAULT 'N',
                              p_action              IN     VARCHAR2,
                              p_validation_level    IN     VARCHAR2,
                              p_batch_id            IN     NUMBER,
                              p_parent_request_id   IN     NUMBER,
                              p_org_name            IN     VARCHAR2)
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

        IF p_action = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling customer_validation :');

            customer_validation (errbuf               => errbuf,
                                 retcode              => retcode,
                                 p_action             => gc_new_status,
                                 p_batch_id           => p_batch_id,
                                 p_validation_level   => p_validation_level);
        ELSIF p_action = gc_load_only
        THEN
            l_target_org_id   := get_targetorg_id (p_org_name => p_org_name);

            log_records (gc_debug_flag, 'Calling create_customer +');
            create_customer (x_errbuf           => errbuf,
                             x_retcode          => retcode,
                             p_action           => gc_validate_status,
                             p_target_org_id    => l_target_org_id,
                             p_batch_id         => p_batch_id,
                             p_operating_unit   => p_org_name);

            create_person (x_errbuf           => errbuf,
                           x_retcode          => retcode,
                           p_action           => gc_validate_status,
                           p_target_org_id    => l_target_org_id,
                           p_batch_id         => p_batch_id,
                           p_operating_unit   => p_org_name);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.output,
                               'Exception Raised During Customer Program');
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END customer_child;
END xxd_customer_delta_conv_pkg;
/
