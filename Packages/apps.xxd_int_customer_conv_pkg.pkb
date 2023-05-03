--
-- XXD_INT_CUSTOMER_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INT_CUSTOMER_CONV_PKG"
AS
    /*******************************************************************************
      * Program Name : XXD_INT_CUSTOMER_CONV_PKG
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

    TYPE xxd_ar_cust_int_tab IS TABLE OF xxd_ar_cust_int_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_int_tab              xxd_ar_cust_int_tab;

    TYPE xxd_ar_cust_site_int_tab IS TABLE OF xxd_ar_cust_sites_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_site_int_tab         xxd_ar_cust_site_int_tab;

    TYPE xxd_ar_cust_site_use_tab
        IS TABLE OF xxd_ar_cust_site_uses_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_site_use_int_tab     xxd_ar_cust_site_use_tab;

    TYPE xxd_ar_cust_cont_int_tab
        IS TABLE OF xxd_ar_cust_contacts_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_cont_int_tab         xxd_ar_cust_cont_int_tab;

    TYPE xxd_ar_cust_cont_pt_int_tab
        IS TABLE OF xxd_ar_cust_cont_point_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_cont_point_int_tab   xxd_ar_cust_cont_pt_int_tab;

    /*TYPE XXD_AR_CUST_REL_INT_TAB is TABLE OF XXD_AR_CUST_REL_INT%ROWTYPE INDEX BY BINARY_INTEGER;
    gtt_ar_cust_rel_int_tab XXD_AR_CUST_REL_INT_TAB;

    TYPE XXD_AR_PARTY_REL_INT_TAB is TABLE OF XXD_AR_PARTY_REL_INT%ROWTYPE INDEX BY BINARY_INTEGER;
    gtt_ar_party_rel_int_tab XXD_AR_PARTY_REL_INT_TAB;
*/
    TYPE xxd_ar_cust_prof_int_tab IS TABLE OF xxd_ar_cust_prof_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_prof_int_tab         xxd_ar_cust_prof_int_tab;

    TYPE xxd_ar_cust_prof_amt_int_tab
        IS TABLE OF xxd_ar_cust_prof_amt_int_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_prof_amt_int_tab     xxd_ar_cust_prof_amt_int_tab;

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
        ELSIF p_table_name = 'XXD_AR_CUST_SITE_USES_STG_T'
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

            xxd_common_utils.record_error ('ARCST', xxd_common_utils.get_org_id, 'Deckers AR Customer Conversion Program', --SQLCODE,
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
                'Deckers AR Customer Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
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
        x_error_msg      VARCHAR2 (250);
        x_org_id         NUMBER;
    BEGIN
        px_meaning   := p_org_name;

        --      apps.xxd_common_utils.get_mapping_value (
        --         p_lookup_type    => 'XXD_1206_OU_MAPPING', -- Lookup type for mapping
        --         px_lookup_code   => px_lookup_code,
        --         -- Would generally be id of 12.0.6. eg: org_id
        --         px_meaning       => px_meaning,        -- internal name of old entity
        --         px_description   => px_description,         -- name of the old entity
        --         x_attribute1     => x_attribute1,   -- corresponding new 12.2.3 value
        --         x_attribute2     => x_attribute2,
        --         x_error_code     => x_error_code,
        --         x_error_msg      => x_error_msg);

        SELECT organization_id
          INTO x_org_id
          FROM hr_operating_units
         WHERE UPPER (name) = UPPER (px_meaning);

        RETURN x_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                'AR',
                gn_org_id,
                'Deckers AR Customer Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
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
            px_lookup_code   => px_lookup_code,
            -- Would generally be id of 12.0.6. eg: org_id
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
                'Deckers AR Customer Conversion Program',
                --      SQLCODE,
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                --   DBMS_UTILITY.format_call_stack,
                --    SYSDATE,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_1206_org_id,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_org_id;

    /* PROCEDURE get_customer_profile_values (p_organization_name        IN     VARCHAR2,
                                         p_customer_name            IN     VARCHAR2,
                                           p_customer_num            IN     VARCHAR2 ,
                                         p_brand                              IN OUT     VARCHAR2 ,
                                         p_customer_classification       OUT VARCHAR2 ,
                                         p_demand_class                  OUT VARCHAR2 ,
                                         p_sales_channel                 OUT VARCHAR2 ,
                                         p_customer_account_profile      OUT VARCHAR2 ,
                                         p_price_list                    OUT VARCHAR2 ,
                                         p_order_type                    OUT VARCHAR2 ,
                                         p_payment_terms                 OUT VARCHAR2 ,
                                         p_sales_person                  OUT VARCHAR2 ,
                                         p_auto_email_order_ack          OUT VARCHAR2  ,
                                         p_auto_email_invoice            OUT VARCHAR2 ,
                                         p_auto_email_soa                OUT VARCHAR2 ,
                                         p_auto_generate_asn             OUT VARCHAR2 ,
                                         p_preauthorized_cc_limit        OUT NUMBER ,
                                         p_posd_date_check_limit         OUT NUMBER ,
                                         p_recourse_limit                OUT NUMBER ,
                                         p_payment_plan                  OUT VARCHAR2 ,
                                         p_payment_exp_date              OUT DATE ,
                                         p_put_on_past_cancel_hold       OUT VARCHAR2 ,
                                         p_edi_print_flag                OUT VARCHAR2 )
  AS
  ln_cnt NUMBER := 0;
  lc_customer_name VARCHAR2 (250);
  lc_customer_num   VARCHAR2 (250);
  BEGIN

                     p_customer_classification       := NULL;
                      p_demand_class                   := NULL;
                      p_sales_channel                  := NULL;
                      p_customer_account_profile       := NULL;
                      p_price_list                     := NULL;
                      p_order_type                     := NULL;
                      p_payment_terms                  := NULL;
                      p_sales_person                   := NULL;
  --                    p_brand                          := NULL;
                      p_auto_email_order_ack           := NULL;
                      p_auto_email_invoice             := NULL;
                      p_auto_email_soa                 := NULL;
                      p_auto_generate_asn              := NULL;
                      p_preauthorized_cc_limit         := NULL;
                      p_posd_date_check_limit          := NULL;
                      p_recourse_limit                 := NULL;
                      p_payment_plan                   := NULL;
                      p_payment_exp_date               := NULL;
                      p_put_on_past_cancel_hold        := NULL;
                      p_edi_print_flag      := NULL;

                      SELECT COUNT(1)
                      INTO  ln_cnt
                      FROM XXD_CUST_ACCOUNT_MAPPING_T
                   WHERE customer_name = p_customer_name
                         AND operating_unit =  p_organization_name;

                         IF ln_cnt > 0 THEN
                         lc_customer_name := p_customer_name ;
                         lc_customer_num  := p_customer_num;
                         ELSE
                        lc_customer_name :=   'ALL BRAND';
                        lc_customer_num  := '0000';
                         END IF;
     SELECT CUSTOMER_CLASSIFICATION    ,
                     DEMAND_CLASS            ,
                     SALES_CHANNEL           ,
                     CUSTOMER_ACCOUNT_PROFILE,
                     PRICE_LIST              ,
                     ORDER_TYPE              ,
                     PAYMENT_TERMS           ,
                     SALES_PERSON            ,
                     BRAND                   ,
                     AUTO_EMAIL_ORDER_ACK    ,
                     AUTO_EMAIL_INVOICE      ,
                     AUTO_EMAIL_SOA          ,
                     AUTO_GENERATE_ASN       ,
                     PREAUTHORIZED_CC_LIMIT  ,
                     POSD_DATE_CHECK_LIMIT   ,
                     RECOURSE_LIMIT          ,
                     PAYMENT_PLAN            ,
                     PAYMENT_EXP_DATE        ,
                     PUT_ON_PAST_CANCEL_HOLD ,
                     EDI_PRINT_FLAG
                     INTO
                      p_customer_classification       ,
                      p_demand_class                  ,
                      p_sales_channel                 ,
                      p_customer_account_profile      ,
                      p_price_list                    ,
                      p_order_type                    ,
                      p_payment_terms                 ,
                      p_sales_person                  ,
                      p_brand                         ,
                      p_auto_email_order_ack          ,
                      p_auto_email_invoice            ,
                      p_auto_email_soa                ,
                      p_auto_generate_asn             ,
                      p_preauthorized_cc_limit        ,
                      p_posd_date_check_limit         ,
                      p_recourse_limit                ,
                      p_payment_plan                  ,
                      p_payment_exp_date              ,
                      p_put_on_past_cancel_hold       ,
                      p_edi_print_flag
  FROM XXD_CUST_ACCOUNT_MAPPING_T
     WHERE customer_name = lc_customer_name
     AND operating_unit =  p_organization_name
     AND  brand = nvl(p_brand, 'ALL BRAND')
     AND nvl(customer_account,'0000') = lc_customer_num;
  EXCEPTION
     WHEN NO_DATA_FOUND
     THEN
        NULL;
     WHEN OTHERS
     THEN
        NULL;
  END get_customer_profile_values;*/
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                            'Deckers AR Customer Conversion Program',
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                            'Deckers AR Customer Conversion Program',
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
        --p_cpamt_rec.cust_account_profile_id := v_cust_account_profile_id;
        --p_cpamt_rec.currency_code := 'USD'; --<< Currency Code
        --p_cpamt_rec.created_by_module := 'TCAPI_EXAMPLE';
        --p_cpamt_rec.overall_credit_limit := 1000000;
        --p_cpamt_rec.cust_account_id := 7744;  --<<value for cust_account_id from step 2a

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
            xxd_common_utils.record_error (
                p_module       => 'AR',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers AR Customer Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => 'create_cust_profile_amt',
                --                                     p_more_info2 => p_cust_account_rec.account_name,
                --                                     p_more_info3 =>p_cust_account_rec.account_number,
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
                    xxd_common_utils.record_error (
                        p_module       => 'AR',
                        p_org_id       => gn_org_id,
                        p_program      =>
                            'Deckers AR Customer Conversion Program',
                        p_error_msg    => x_msg_data,
                        p_error_line   => DBMS_UTILITY.format_error_backtrace,
                        p_created_by   => gn_user_id,
                        p_request_id   => gn_conc_request_id,
                        p_more_info1   => 'create_cust_profile_amt',
                        --                                     p_more_info2 => p_cust_account_rec.account_name,
                        --                                     p_more_info3 =>p_cust_account_rec.account_number,
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                            'Deckers AR Customer Conversion Program',
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
        --Viswa
        IF p_customer_profile_rec.site_use_id IS NOT NULL
        THEN
            lc_true_false   := fnd_api.g_true;
        END IF;

        --Viswa
        --    g_process := 'create_cust_site_use';
        hz_cust_account_site_v2pub.create_cust_site_use (
            'T',
            p_cust_site_use_rec,
            p_customer_profile_rec,
            lc_true_false,                                       --Viswa added
            lc_true_false,                                       --Viswa added
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
    PROCEDURE create_org_contact (p_org_contact_rec hz_party_contact_v2pub.org_contact_rec_type, v_rel_party_id OUT NUMBER, v_org_party_id OUT NUMBER)
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
            v_rel_party_id   := x_party_rel_id;
            v_org_party_id   := x_party_id;
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
        -- v_cust_acct_relate_rec.cust_account_id := 52185;
        --<< Leasing comp Cust account id
        -- v_cust_acct_relate_rec.related_cust_account_id := 52183;
        --<< Client 1 cust accoutn id
        -- v_cust_acct_relate_rec.relationship_type := 'ALL';
        -- p_cust_acct_relate_rec.created_by_module := 'TCAPI_EXAMPLE';
        -- v_cust_acct_relate_rec.comments := 'test API';
        -- if you need to use BILL_TO_FLAG or SHIP_TO_FLAG do
        --   v_cust_acct_relate_rec.bill_to_flag := 'Y';
        -- Use p_cust_acct_relate_rec.SHIP_TO_FLAG = 'Y';
        --    g_process := 'create_cust_acct_relate';

        --p_cust_acct_relate_rec.cust_account_id := 219010;
        --p_cust_acct_relate_rec.related_cust_account_id := 127920;
        --p_cust_acct_relate_rec.relationship_type := 'Reciprocal';
        --p_cust_acct_relate_rec.created_by_module := 'HZ_RM';
        --p_cust_acct_relate_rec.CUSTOMER_RECIPROCAL_FLAG := 'Y';

        -- if you need to use BILL_TO_FLAG or SHIP_TO_FLAG do
        -- Use p_cust_acct_relate_rec.BILL_TO_FLAG = 'Y';
        -- Use p_cust_acct_relate_rec.SHIP_TO_FLAG = 'Y';

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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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
        --    g_process := 'create_relationship';
        -- p_relationship_rec_type.subject_id := 150607;    -- Client1 party Id
        -- p_relationship_rec_type.subject_table_name := 'HZ_PARTIES';
        -- p_relationship_rec_type.subject_type := 'ORGANIZATION';
        -- p_relationship_rec_type.object_id := 150606; --Leasing COmp Party Id
        -- p_relationship_rec_type.object_table_name := 'HZ_PARTIES';
        -- p_relationship_rec_type.object_type := 'ORGANIZATION';
        -- p_relationship_rec_type.relationship_type := 'PAYTO';
        -- p_relationship_rec_type.relationship_code := 'PAYTO_OF';
        -- p_relationship_rec_type.start_date := SYSDATE;
        -- p_relationship_rec_type.created_by_module := 'TCAPI_EXAMPLE';
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
                p_program      => 'Deckers AR Customer Conversion Program',
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
                    p_program      => 'Deckers AR Customer Conversion Program',
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



    FUNCTION get_gl_ccid (p_code_combination VARCHAR2)
        RETURN NUMBER
    IS
        ln_ccid     NUMBER := NULL;
        ln_coa_id   NUMBER := NULL;
    BEGIN
        log_records (gc_debug_flag, p_code_combination);

        --SELECT CHART_OF_ACCOUNTS_ID
        -- INTO ln_coa_id
        -- FROM gl_sets_of_books
        --WHERE set_of_books_id = fnd_profile.VALUE ('GL_SET_OF_BKS_ID');

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
        log_records (gc_debug_flag, ln_ccid);

        IF ln_ccid > 0
        THEN
            RETURN ln_ccid;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            log_records (gc_debug_flag, SQLERRM);
            RETURN NULL;
        WHEN OTHERS
        THEN
            log_records (gc_debug_flag, SQLERRM);
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

    PROCEDURE create_cust_site_use (p_action IN VARCHAR2, p_customer_id IN NUMBER, p_party_type IN VARCHAR2, p_site_revenue_account IN VARCHAR2, p_site_freight_account IN VARCHAR2, p_site_tax_account IN VARCHAR2
                                    , p_site_unearn_rev_account IN VARCHAR2)
    AS
        CURSOR site_use IS
              SELECT *
                FROM xxd_ar_int_cust_site_use_stg_t
               WHERE customer_id = p_customer_id AND record_status = p_action
            ORDER BY site_use_code;            -- To create Bill to site first

        l_cust_site_use_rec        hz_cust_account_site_v2pub.cust_site_use_rec_type;
        lr_customer_profile_rec    hz_customer_profile_v2pub.customer_profile_rec_type;
        ln_location_id             NUMBER := NULL;
        ln_party_site_id           NUMBER := NULL;
        ln_cust_acct_site_id       NUMBER := NULL;
        ln_cust_acct_site_use_id   NUMBER := NULL;
        ln_bto_site_use_id         NUMBER := NULL;
        lc_site_account            VARCHAR2 (2000) := NULL;

        -- Cursor to fetch the bill to site use id from R12
        CURSOR lcu_bto_site_use_id (p_bto_site_use_id VARCHAR2)
        IS
            SELECT hcsu.site_use_id
              FROM hz_cust_site_uses_all hcsu
             WHERE hcsu.location = TO_CHAR (p_bto_site_use_id);



        -- Cursor to fetch collector_id for collector_name
        CURSOR lcu_fetch_collector_id (p_collector_name VARCHAR2)
        IS
            SELECT ac.collector_id
              FROM ar_collectors ac
             WHERE     ac.status = 'A'
                   AND UPPER (ac.name) = UPPER (p_collector_name);



        -- Cursor to fetch collector_id for collector_name
        CURSOR lcu_fetch_warehouse_id (p_warehouse_name VARCHAR2)
        IS
            SELECT mp.ORGANIZATION_ID
              FROM org_organization_definitions ood, mtl_parameters mp
             WHERE     ood.organization_id = mp.organization_id
                   AND mp.organization_code = p_warehouse_name;


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

        ln_statement_cycle_id      NUMBER;

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

        ln_standard_terms_id       VARCHAR2 (1000);

        -- Cursor to fetch grouping_rule_id from R12 using 11i grouping_rule_id
        CURSOR lcu_grouping_rule_id (p_grouping_rule_name VARCHAR2)
        IS
            SELECT grouping_rule_id
              FROM ra_grouping_rules
             WHERE 1 = 1 AND UPPER (name) = UPPER (p_grouping_rule_name);

        ln_grouping_rule_id        NUMBER;


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
              FROM ra_terms rt
             WHERE 1 = 1 AND UPPER (rt.name) = UPPER (pv_term_name);

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
              FROM oe_transaction_types_tl ottt12
             WHERE ottt12.name = p_order_type_name AND language = 'US';

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
              FROM oe_price_lists_vl oeplr12
             WHERE 1 = 1 AND oeplr12.name = p_price_list_name;

        lr_get_price_list          lcu_get_price_list_id%ROWTYPE;

        CURSOR lcu_get_ship_via (p_ship_via VARCHAR2)
        IS
            SELECT wcs.ship_method_code
              FROM xxd_conv.xxd_1206_ship_methods_map_t lsm, wsh_carrier_ship_methods wcs
             WHERE     old_ship_method_code = p_ship_via
                   AND ship_method_code = new_ship_method_code
                   AND ROWNUM = 1;

        --Viswa
        CURSOR get_price_list_id (
            p_price_list_name IN oe_price_lists_vl.name%TYPE)
        IS
            SELECT oplv.price_list_id price_list_id
              FROM oe_price_lists_vl oplv
             WHERE oplv.name = p_price_list_name;

        --Viswa

        TYPE lt_site_use_typ IS TABLE OF site_use%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_site_use_data           lt_site_use_typ;

        ln_collector_id            NUMBER;
        ln_profile_class_id        NUMBER;
        lx_profile_id              NUMBER;
        ln_stmt_cycle_id           NUMBER;
        ln_dunning_letter_set_id   NUMBER;
        --Viswa
        l_cpamt_rec                hz_customer_profile_v2pub.cust_profile_amt_rec_type;
        ln_cnt                     NUMBER := 0;
        --Viswa
        lc_distribution_channel    VARCHAR2 (250);
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
                    ln_location_id        := NULL;
                    l_cust_site_use_rec   := NULL;
                    lc_site_account       := NULL;

                    --                :=
                    SELECT DECODE (lt_site_use_data (xc_site_use_idx).site_use_code, 'Ship To', 'SHIP_TO', 'BILL_TO')
                      INTO gc_cust_site_use
                      FROM DUAL;

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
                               AND cust_account_id = p_customer_id
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

                    IF (ln_cust_acct_site_id <> 0)
                    THEN
                        BEGIN
                            ln_cust_acct_site_use_id   := 0;

                            SELECT hc.site_use_id
                              INTO ln_cust_acct_site_use_id
                              FROM hz_cust_site_uses_all hc
                             WHERE     hc.cust_acct_site_id =
                                       ln_cust_acct_site_id
                                   AND hc.site_use_code = gc_cust_site_use; --lt_site_use_data (xc_site_use_idx).site_use_code;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                --                dbms_output.put_line(SQLERRM);
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


                            --                    OPEN lcu_fetch_warehouse_id ( p_warehouse_name => lt_site_use_data (xc_site_use_idx).INTERNAL_ORGANIZATION) ;
                            --
                            --                     FETCH lcu_fetch_warehouse_id
                            --                     INTO l_cust_site_use_rec.warehouse_id;
                            --
                            --                     CLOSE lcu_fetch_warehouse_id;


                            OPEN lcu_get_salesrep (pv_org_id => gn_org_id);


                            FETCH lcu_get_salesrep
                                INTO l_cust_site_use_rec.PRIMARY_SALESREP_ID;

                            CLOSE lcu_get_salesrep;

                            --                           -- lt_site_use_data(xc_site_use_idx).site_order_type_id;
                            l_cust_site_use_rec.location       :=
                                lt_site_use_data (xc_site_use_idx).location;
                            l_cust_site_use_rec.org_id         :=
                                lt_site_use_data (xc_site_use_idx).target_org;

                            OPEN lcu_get_ship_via (
                                p_ship_via   =>
                                    lt_site_use_data (xc_site_use_idx).ship_via);

                            FETCH lcu_get_ship_via
                                INTO l_cust_site_use_rec.ship_via;

                            CLOSE lcu_get_ship_via;


                            OPEN lcu_get_term_id (
                                pv_term_name   =>
                                    lt_site_use_data (xc_site_use_idx).PAYMENT_TERM_NAME);

                            FETCH lcu_get_term_id
                                INTO l_cust_site_use_rec.PAYMENT_TERM_ID;

                            CLOSE lcu_get_term_id;

                            l_cust_site_use_rec.FREIGHT_TERM   := 'COLLECT';
                            l_cust_site_use_rec.FOB_POINT      :=
                                'SHIP POINT';

                            --<<value for cust_acct_site_id from step 5>
                            l_cust_site_use_rec.site_use_code   :=
                                gc_cust_site_use;
                            --                        lt_site_use_data (xc_site_use_idx).site_use_code;
                            l_cust_site_use_rec.orig_system_reference   :=
                                lt_site_use_data (xc_site_use_idx).site_use_id;
                            --Viswa
                            l_cust_site_use_rec.primary_flag   :=
                                lt_site_use_data (xc_site_use_idx).primary_flag;

                            IF gc_cust_site_use = 'BILL_TO'
                            THEN
                                l_cust_site_use_rec.gl_id_rev   :=
                                    get_gl_ccid (
                                        p_code_combination   =>
                                            lt_site_use_data (
                                                xc_site_use_idx).REVENUE);
                                l_cust_site_use_rec.gl_id_unearned   :=
                                    get_gl_ccid (
                                        p_code_combination   =>
                                            lt_site_use_data (
                                                xc_site_use_idx).UNEARNEDREVENUE);
                                l_cust_site_use_rec.gl_id_rec   :=
                                    get_gl_ccid (
                                        p_code_combination   =>
                                            lt_site_use_data (
                                                xc_site_use_idx).RECEIVABLE);
                            ELSE
                                l_cust_site_use_rec.date_type_preference   :=
                                    'ARRIVAL';
                            END IF;

                            --v_cust_site_use_rec.attribute_category := 'XXQST_LECTAG_SALESREP';
                            --v_cust_site_use_rec.attribute10        := g_orig_system_custacct_ref;
                            --v_cust_site_use_rec.attribute11        := NULL;
                            l_cust_site_use_rec.created_by_module   :=
                                'TCA_V1_API';

                            log_records (
                                p_debug   => gc_debug_flag,
                                p_message   =>
                                       ' SITE lc_distribution_channel => '
                                    || lc_distribution_channel);

                            ln_bto_site_use_id                 :=
                                NULL;                                  --Viswa

                            IF lt_site_use_data (xc_site_use_idx).BILL_TO_LOCATION
                                   IS NOT NULL
                            THEN
                                OPEN lcu_bto_site_use_id (
                                    lt_site_use_data (xc_site_use_idx).BILL_TO_LOCATION);

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
                            --Viswa
                            /*ELSE
                               l_cust_site_use_rec.bill_to_site_use_id := NULL;*/
                            END IF;


                            -- lr_cust_profile_rec.site_use_id IS NULL
                            lr_customer_profile_rec            :=
                                NULL;

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
                        --
                        --                     IF sites_dtl.site_use_code  = 'BILL_TO'  AND sites_dtl.primary_flag = 'Y'        THEN
                        --                            BEGIN
                        --                            log_records (p_debug => gc_debug_flag, p_message => 'Calling create_brand_cust_site for sites_dtl.customer_id => '|| sites_dtl.customer_id );
                        --                                create_brand_cust_site(sites_dtl.customer_id,ln_party_site_id );
                        --                            EXCEPTION
                        --                                  WHEN OTHERS THEN
                        --                                    log_records (p_debug => gc_debug_flag, p_message => 'Un-expecetd Error in create_brand_cust_site for sites_dtl.customer_id => '||SQLERRM );
                        --                                  END ;
                        --                     END IF;
                        END IF;
                    END IF;

                    IF (ln_cust_acct_site_use_id > 0)
                    THEN
                        IF lt_site_use_data (xc_site_use_idx).INTERNAL_LOCATION
                               IS NOT NULL
                        THEN
                            DECLARE
                                x_return_status      VARCHAR2 (250);
                                x_msg_count          NUMBER;
                                x_msg_data           VARCHAR2 (2000);
                                ln_inv_location_id   NUMBER;
                                ln_inv_org_id        NUMBER;
                            BEGIN
                                --                        mo_global.init ('AR');
                                --                        mo_global.set_policy_context ('S', 95);
                                SELECT LOCATION_ID, INVENTORY_ORGANIZATION_ID
                                  INTO ln_inv_location_id, ln_inv_org_id
                                  FROM hr_locations
                                 WHERE LOCATION_CODE =
                                       lt_site_use_data (xc_site_use_idx).INTERNAL_LOCATION;

                                ARP_CLAS_PKG.insert_po_loc_associations (
                                    p_inventory_location_id   =>
                                        ln_inv_location_id,
                                    p_inventory_organization_id   =>
                                        ln_inv_org_id,
                                    p_customer_id     => p_customer_id,
                                    p_address_id      => ln_cust_acct_site_id,
                                    p_site_use_id     =>
                                        ln_cust_acct_site_use_id,
                                    x_return_status   => x_return_status,
                                    x_msg_count       => x_msg_count,
                                    x_msg_data        => x_msg_data);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    xxd_common_utils.record_error (
                                        'AR',
                                        gn_org_id,
                                        'Deckers AR Customer Conversion Program',
                                        --      SQLCODE,
                                        SQLERRM,
                                        DBMS_UTILITY.format_error_backtrace,
                                        --   DBMS_UTILITY.format_call_stack,
                                        --    SYSDATE,
                                        gn_user_id,
                                        gn_conc_request_id,
                                        'CUST_ACCT_SITE_USE_ID',
                                        ln_cust_acct_site_use_id,
                                           'Exception to GET_ORG_ID Procedure'
                                        || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    xxd_common_utils.record_error (
                                        'AR',
                                        gn_org_id,
                                        'Deckers AR Customer Conversion Program',
                                        --      SQLCODE,
                                        SQLERRM,
                                        DBMS_UTILITY.format_error_backtrace,
                                        --   DBMS_UTILITY.format_call_stack,
                                        --    SYSDATE,
                                        gn_user_id,
                                        gn_conc_request_id,
                                        'CUST_ACCT_SITE_USE_ID',
                                        ln_cust_acct_site_use_id,
                                           'Exception to GET_ORG_ID Procedure'
                                        || SQLERRM);
                            END;
                        END IF;

                        UPDATE XXD_AR_INT_CUST_SITE_USE_STG_T
                           SET record_status   = gc_process_status
                         WHERE     customer_id =
                                   lt_site_use_data (xc_site_use_idx).customer_id
                               AND cust_acct_site_id =
                                   lt_site_use_data (xc_site_use_idx).cust_acct_site_id;
                    ELSE
                        UPDATE XXD_AR_INT_CUST_SITE_USE_STG_T
                           SET record_status   = gc_error_status
                         WHERE     customer_id =
                                   lt_site_use_data (xc_site_use_idx).customer_id
                               AND cust_acct_site_id =
                                   lt_site_use_data (xc_site_use_idx).cust_acct_site_id;
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


    PROCEDURE create_cust_address (p_action IN VARCHAR2, p_customer_id IN NUMBER, p_new_party_id IN NUMBER
                                   , p_cust_account_id IN NUMBER)
    AS
        CURSOR address IS
            SELECT *
              FROM XXD_AR_INT_CUST_SITES_STG_T
             WHERE customer_id = p_customer_id;

        l_location_rec         hz_location_v2pub.location_rec_type;
        l_party_site_rec       hz_party_site_v2pub.party_site_rec_type;
        l_cust_acct_site_rec   hz_cust_account_site_v2pub.cust_acct_site_rec_type;
        ln_location_id         NUMBER := NULL;
        ln_party_site_id       NUMBER := NULL;
        ln_cust_acct_site_id   NUMBER := NULL;
        lc_address_id          VARCHAR2 (250) := NULL;
        lc_cust_acct_site_id   VARCHAR2 (250) := NULL;
    BEGIN
        --    g_process               := 'create_billing_address';
        FOR location_dtl IN address
        LOOP
            ln_location_id   := NULL;

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

                SELECT l.location_id, l.orig_system_reference
                  INTO ln_location_id, lc_address_id
                  FROM hz_locations l, hz_party_sites hps, hz_cust_acct_sites_all hcas
                 WHERE     l.location_id = hps.location_id
                       AND hps.PARTY_SITE_ID = hcas.PARTY_SITE_ID
                       AND UPPER (address1) = UPPER (location_dtl.address1)
                       AND UPPER (city) = UPPER (location_dtl.city)
                       AND UPPER (country) = UPPER (location_dtl.country)
                       AND hcas.cust_account_id = p_customer_id
                       AND hcas.org_id = location_dtl.target_org;
            ----                                  AND upper(county) = upper(location_dtl.county)
            --                                  AND upper(nvl(state,'X')) = upper(nvl(location_dtl.state,'X'))
            --                                  AND upper(postal_code) = upper(location_dtl.postal_code);
            --                   AND orig_system_reference = TO_CHAR (location_dtl.address_id);
            --AND address_key = location_dtl.address_key ;

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

            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Location id is found for the address  '
                    || location_dtl.address1
                    || 'ln_location_id => '
                    || ln_location_id);

            IF (ln_location_id = 0)
            THEN
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'Create New Location with the address  '
                        || location_dtl.address1);
                ln_location_id                                := NULL;
                l_location_rec.location_id                    := ln_location_id;
                l_location_rec.orig_system_reference          :=
                    location_dtl.address_id;
                l_location_rec.orig_system                    := NULL;

                l_location_rec.address1                       :=
                    location_dtl.address1;
                l_location_rec.address2                       :=
                    location_dtl.address2;
                l_location_rec.address3                       :=
                    location_dtl.address3;
                l_location_rec.address4                       :=
                    location_dtl.address4;
                l_location_rec.city                           := location_dtl.city;
                l_location_rec.state                          := location_dtl.state;
                --Viswa Revert after modifying extract
                l_location_rec.country                        :=
                    CASE
                        WHEN location_dtl.country = 'AN' THEN 'NL'
                        ELSE location_dtl.country
                    END;
                --Viswa Revert after modifying extract
                l_location_rec.postal_code                    :=
                    location_dtl.postal_code;
                l_location_rec.county                         := location_dtl.county;
                l_location_rec.province                       :=
                    location_dtl.province;
                --l_location_rec.address_key           :=              location_dtl.ADDRESS_KEY    ;
                l_location_rec.address_style                  := NULL;
                l_location_rec.validated_flag                 := NULL;
                l_location_rec.address_lines_phonetic         := NULL;
                l_location_rec.po_box_number                  := NULL;
                l_location_rec.house_number                   := NULL;
                l_location_rec.street_suffix                  := NULL;
                l_location_rec.street                         := NULL;
                l_location_rec.street_number                  := NULL;
                l_location_rec.FLOOR                          := NULL;
                l_location_rec.suite                          := NULL;
                l_location_rec.postal_plus4_code              := NULL;
                l_location_rec.position                       := NULL;
                l_location_rec.location_directions            := NULL;
                l_location_rec.address_effective_date         := NULL;
                l_location_rec.address_expiration_date        := NULL;
                l_location_rec.clli_code                      := NULL;
                l_location_rec.language                       := NULL;
                l_location_rec.short_description              := NULL;
                l_location_rec.description                    := NULL;
                l_location_rec.geometry                       := NULL;
                l_location_rec.geometry_status_code           := NULL;
                l_location_rec.loc_hierarchy_id               := NULL;
                l_location_rec.sales_tax_geocode              := NULL;
                l_location_rec.sales_tax_inside_city_limits   := NULL;
                l_location_rec.fa_location_id                 := NULL;
                l_location_rec.content_source_type            := NULL;
                l_location_rec.attribute_category             := NULL;
                l_location_rec.attribute1                     :=
                    location_dtl.address_attribute1;
                l_location_rec.attribute2                     :=
                    location_dtl.address_attribute2;
                l_location_rec.attribute3                     :=
                    location_dtl.address_attribute3;
                l_location_rec.attribute4                     :=
                    location_dtl.address_attribute4;
                l_location_rec.attribute5                     :=
                    location_dtl.address_attribute5;
                l_location_rec.attribute6                     :=
                    location_dtl.address_attribute6;
                l_location_rec.attribute7                     :=
                    location_dtl.address_attribute7;
                l_location_rec.attribute8                     :=
                    location_dtl.address_attribute8;
                l_location_rec.attribute9                     := NULL;
                l_location_rec.attribute10                    := NULL;
                l_location_rec.attribute11                    := NULL;
                l_location_rec.attribute12                    := NULL;
                l_location_rec.attribute13                    := NULL;
                l_location_rec.attribute14                    := NULL;
                l_location_rec.attribute15                    := NULL;
                l_location_rec.attribute16                    := NULL;
                l_location_rec.attribute17                    := NULL;
                l_location_rec.attribute18                    := NULL;
                l_location_rec.attribute19                    := NULL;
                l_location_rec.attribute20                    := NULL;
                l_location_rec.timezone_id                    := NULL;
                l_location_rec.created_by_module              := 'TCA_V1_API';
                l_location_rec.application_id                 := NULL;
                l_location_rec.actual_content_source          := NULL;
                l_location_rec.delivery_point_code            := NULL;
                create_location (p_location_rec   => l_location_rec,
                                 v_location_id    => ln_location_id);
                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           ' New Location  created ln_location_id=> '
                        || ln_location_id
                        || ' with the address  '
                        || location_dtl.address1);
            END IF;                                          --create_location

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

                IF (ln_party_site_id = 0)
                THEN
                    l_party_site_rec.party_id                   := p_new_party_id;
                    --<<value for party_id from step 2>
                    l_party_site_rec.location_id                := ln_location_id;
                    --<<value for location_id from step 3>
                    --          l_party_site_rec.party_site_number   :=  location_dtl.PARTY_SITE_ID;
                    l_party_site_rec.identifying_address_flag   := 'Y';
                    --                  location_dtl.identifying_address_flag;
                    l_party_site_rec.attribute_category         :=
                        location_dtl.party_site_attr_category;
                    l_party_site_rec.attribute1                 := '00';
                    --                  location_dtl.party_site_attribute1;
                    l_party_site_rec.attribute2                 := '00';
                    --                  location_dtl.party_site_attribute2;
                    l_party_site_rec.attribute3                 := '00';
                    --                  location_dtl.party_site_attribute3;
                    l_party_site_rec.attribute4                 := 'N';
                    --                  location_dtl.party_site_attribute4;
                    l_party_site_rec.attribute6                 := '0';
                    --                  location_dtl.party_site_attribute5;
                    l_party_site_rec.created_by_module          :=
                        'TCA_V1_API';
                    log_records (p_debug     => gc_debug_flag,
                                 p_message   => ' Create new  Party Site ');
                    create_party_site (p_party_site_rec   => l_party_site_rec,
                                       x_party_site_id    => ln_party_site_id);
                    log_records (
                        p_debug   => gc_debug_flag,
                        p_message   =>
                               ' Party Site created with id=> '
                            || ln_party_site_id);
                END IF;                                    --create_party_site

                IF (ln_party_site_id <> 0 AND p_cust_account_id <> 0)
                THEN
                    BEGIN
                        SELECT hc.cust_acct_site_id
                          INTO ln_cust_acct_site_id
                          FROM hz_cust_acct_sites_all hc
                         WHERE     cust_account_id = p_cust_account_id
                               AND party_site_id = ln_party_site_id
                               AND org_id = location_dtl.target_org;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_cust_acct_site_id   := 0;
                            log_records (
                                p_debug     => gc_debug_flag,
                                p_message   => ' Cust Site account Not found');
                    -- previously it was vCustAccountId
                    END;

                    IF (ln_cust_acct_site_id = 0)
                    THEN
                        l_cust_acct_site_rec.cust_account_id   :=
                            p_cust_account_id;
                        --<<value for cust_account_id you get from step 2>
                        l_cust_acct_site_rec.party_site_id   :=
                            ln_party_site_id;
                        l_cust_acct_site_rec.org_id   :=
                            location_dtl.target_org;
                        l_cust_acct_site_rec.attribute_category   :=
                            location_dtl.cust_site_attr_category;

                        l_cust_acct_site_rec.attribute1   :=
                            location_dtl.cust_site_attribute1;
                        l_cust_acct_site_rec.attribute2   :=
                            location_dtl.cust_site_attribute2;
                        l_cust_acct_site_rec.attribute3   :=
                            location_dtl.cust_site_attribute3;
                        l_cust_acct_site_rec.attribute4   :=
                            location_dtl.cust_site_attribute4;
                        l_cust_acct_site_rec.attribute5   :=
                            location_dtl.cust_site_attribute5;
                        l_cust_acct_site_rec.attribute6   :=
                            location_dtl.cust_site_attribute6;
                        l_cust_acct_site_rec.attribute7   :=
                            location_dtl.cust_site_attribute7;
                        l_cust_acct_site_rec.attribute8   :=
                            location_dtl.cust_site_attribute8;
                        --                  l_cust_acct_site_rec.orig_system_reference := location_dtl.address_id;
                        --<<value for party_site_id from step 4>
                        --l_cust_acct_site_rec.LANGUAGE          := 'US';
                        l_cust_acct_site_rec.created_by_module   :=
                            'TCA_V1_API';
                        log_records (
                            p_debug     => gc_debug_flag,
                            p_message   => 'Create new Cust Site account');
                        create_cust_acct_site (
                            p_cust_acct_site_rec   => l_cust_acct_site_rec,
                            x_cust_acct_site_id    => ln_cust_acct_site_id);
                        log_records (
                            p_debug   => gc_debug_flag,
                            p_message   =>
                                   'Create new Cust Site account created with =>'
                                || ln_cust_acct_site_id);
                    END IF;                          ----create_cust_acct_site
                END IF;   --(ln_party_site_id <> 0 AND p_cust_account_id <> 0)
            END IF;              --p_new_party_id <> 0 AND ln_location_id <> 0

            IF ln_cust_acct_site_id > 0
            THEN
                BEGIN
                    SELECT l.orig_system_reference, hcas.orig_system_reference
                      INTO lc_address_id, lc_cust_acct_site_id
                      FROM hz_locations l, hz_party_sites hps, hz_cust_acct_sites_all hcas
                     WHERE     l.location_id = hps.location_id
                           AND hps.PARTY_SITE_ID = hcas.PARTY_SITE_ID
                           AND l.location_id = ln_location_id
                           AND hcas.org_id = location_dtl.target_org;
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

                log_records (
                    p_debug   => gc_debug_flag,
                    p_message   =>
                           'lc_cust_acct_site_id is  for the address   '
                        || lc_cust_acct_site_id);

                UPDATE XXD_AR_INT_CUST_SITES_STG_T
                   SET record_status = gc_process_status, address_id = lc_address_id
                 WHERE     customer_id = location_dtl.customer_id
                       AND LOCATION = location_dtl.LOCATION
                       AND SOURCE_ORG_NAME = location_dtl.SOURCE_ORG_NAME;

                UPDATE XXD_AR_INT_CUST_SITE_USE_STG_T
                   SET cust_acct_site_id   = TO_NUMBER (lc_cust_acct_site_id)
                 WHERE     customer_id = location_dtl.customer_id
                       AND address = location_dtl.LOCATION
                       AND SOURCE_ORG_NAME = location_dtl.SOURCE_ORG_NAME;
            ELSE
                UPDATE XXD_AR_INT_CUST_SITES_STG_T
                   SET record_status   = gc_error_status
                 WHERE     customer_id = location_dtl.customer_id
                       AND LOCATION = location_dtl.LOCATION
                       AND SOURCE_ORG_NAME = location_dtl.SOURCE_ORG_NAME;
            END IF;

            COMMIT;
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

    --    PROCEDURE create_cust_site_use(  p_action               IN     VARCHAR2,
    --                                     p_customer_id          IN      NUMBER
    --                                                                ) AS



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

    --Viswa

    PROCEDURE create_customer (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_action IN VARCHAR2
                               , p_operating_unit IN VARCHAR2, p_target_org_id IN NUMBER, p_batch_id IN NUMBER)
    AS
        CURSOR cur_customer (p_party_type VARCHAR2)
        IS
            (SELECT *
               FROM XXD_AR_INT_CUSTOMER_STG_T cust
              WHERE     party_type = p_party_type
                    AND record_status = p_action
                    AND batch_number = p_batch_id);

        --
        --                 AND EXISTS
        --                        (SELECT 1
        --                           FROM xxd_ar_cust_sites_stg_t site
        --                          WHERE     cust.customer_id = site.customer_id
        --                                AND target_org = p_target_org_id));



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
        ln_stmt_cycle_id              NUMBER;
        ln_cnt                        NUMBER := 0;

        x_return_status               VARCHAR2 (10);
        lc_salesrep                   VARCHAR2 (250);
        lc_profile_class              VARCHAR2 (250);
        lc_price_list                 VARCHAR2 (250);
        lc_sales_channel_code         VARCHAR2 (250);
        lc_distribution_channel       VARCHAR2 (250);
        gc_account_name               VARCHAR2 (300);                  --Viswa
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
                    gc_account_name         := NULL;                   --Viswa

                    IF (lt_customer_data (xc_customer_idx).account_name IS NOT NULL)
                    THEN
                        log_records (
                            gc_debug_flag,
                               'create_customer  Working on the customer '
                            || lt_customer_data (xc_customer_idx).account_name);

                        BEGIN
                            SELECT hzc.cust_account_id, hp.party_id
                              INTO lx_cust_account_id, lx_org_party_id
                              FROM hz_parties hp, hz_cust_accounts hzc
                             WHERE     hp.party_id = hzc.party_id
                                   AND hp.party_type = 'ORGANIZATION'
                                   AND UPPER (hp.party_name) =
                                       UPPER (
                                           lt_customer_data (xc_customer_idx).ORGANIZATION_NAME)
                                   AND UPPER (account_name) =
                                       UPPER (
                                           lt_customer_data (xc_customer_idx).account_name)
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
                                       lt_customer_data (xc_customer_idx).account_name
                                    || ' Customer not found in DB ');
                                x_return_status      := 'E';
                            WHEN OTHERS
                            THEN
                                lx_org_party_id   := NULL;
                                lx_org_party_id   := NULL;
                                log_records (
                                    gc_debug_flag,
                                       'create_customer : '
                                    || lt_customer_data (xc_customer_idx).account_name
                                    || ' '
                                    || SQLERRM);
                                x_return_status   := 'E';
                        END;

                        IF (lx_org_party_id = 0)
                        THEN
                            --v_party_rec_type.party_id              := lx_org_party_id;

                            l_party_rec_type.party_id                :=
                                lt_customer_data (xc_customer_idx).party_id;
                            --            l_party_rec_type.party_number                                   :=  lt_customer_data(xc_customer_idx).party_number;
                            --You cannot pass the party number because the profile option HZ:Generate Party Number is either Null or is set to Yes.
                            l_party_rec_type.validated_flag          := NULL;
                            --                     l_party_rec_type.orig_system_reference := lt_customer_data (xc_customer_idx).orig_system_party_ref;
                            l_party_rec_type.orig_system             := NULL;
                            l_party_rec_type.status                  :=
                                lt_customer_data (xc_customer_idx).customer_status;
                            l_party_rec_type.category_code           :=
                                lt_customer_data (xc_customer_idx).customer_prospect_code;
                            l_party_rec_type.salutation              := NULL;

                            l_organization_rec.organization_name     :=
                                lt_customer_data (xc_customer_idx).organization_name;
                            l_organization_rec.duns_number_c         :=
                                lt_customer_data (xc_customer_idx).duns_number_c;
                            l_organization_rec.enquiry_duns          := NULL;
                            l_organization_rec.ceo_name              := NULL;
                            l_organization_rec.ceo_title             := NULL;
                            l_organization_rec.principal_name        := NULL;
                            l_organization_rec.principal_title       := NULL;
                            l_organization_rec.legal_status          := NULL;
                            l_organization_rec.control_yr            := NULL;
                            l_organization_rec.employees_total       := NULL;
                            l_organization_rec.hq_branch_ind         := NULL;
                            l_organization_rec.branch_flag           := NULL;
                            l_organization_rec.oob_ind               := NULL;
                            l_organization_rec.line_of_business      := NULL;
                            l_organization_rec.cong_dist_code        := NULL;
                            l_organization_rec.sic_code              := NULL;
                            l_organization_rec.import_ind            := NULL;
                            l_organization_rec.export_ind            := NULL;
                            l_organization_rec.labor_surplus_ind     := NULL;
                            l_organization_rec.debarment_ind         := NULL;
                            l_organization_rec.minority_owned_ind    := NULL;
                            l_organization_rec.minority_owned_type   := NULL;
                            l_organization_rec.woman_owned_ind       := NULL;
                            l_organization_rec.disadv_8a_ind         := NULL;
                            l_organization_rec.small_bus_ind         := NULL;
                            l_organization_rec.rent_own_ind          := NULL;
                            l_organization_rec.debarments_count      := NULL;
                            l_organization_rec.debarments_date       := NULL;
                            l_organization_rec.failure_score         := NULL;
                            l_organization_rec.failure_score_natnl_percentile   :=
                                NULL;
                            l_organization_rec.failure_score_override_code   :=
                                NULL;
                            l_organization_rec.failure_score_commentary   :=
                                NULL;
                            l_organization_rec.global_failure_score   :=
                                NULL;
                            l_organization_rec.db_rating             :=
                                NULL;
                            l_organization_rec.credit_score          :=
                                NULL;
                            l_organization_rec.credit_score_commentary   :=
                                NULL;
                            l_organization_rec.paydex_score          :=
                                NULL;
                            l_organization_rec.paydex_three_months_ago   :=
                                NULL;
                            l_organization_rec.paydex_norm           :=
                                NULL;
                            l_organization_rec.best_time_contact_begin   :=
                                NULL;
                            l_organization_rec.best_time_contact_end   :=
                                NULL;
                            l_organization_rec.organization_name_phonetic   :=
                                NULL;
                            l_organization_rec.tax_reference         :=
                                NULL;
                            l_organization_rec.gsa_indicator_flag    :=
                                NULL;
                            l_organization_rec.jgzz_fiscal_code      :=
                                NULL;
                            l_organization_rec.analysis_fy           :=
                                NULL;
                            l_organization_rec.fiscal_yearend_month   :=
                                NULL;
                            l_organization_rec.curr_fy_potential_revenue   :=
                                NULL;
                            l_organization_rec.next_fy_potential_revenue   :=
                                NULL;
                            l_organization_rec.year_established      :=
                                NULL;
                            l_organization_rec.mission_statement     :=
                                NULL;
                            l_organization_rec.organization_type     :=
                                NULL;
                            l_organization_rec.business_scope        :=
                                NULL;
                            l_organization_rec.corporation_class     :=
                                NULL;
                            l_organization_rec.known_as              :=
                                NULL;
                            l_organization_rec.known_as2             :=
                                NULL;
                            l_organization_rec.known_as3             :=
                                NULL;
                            l_organization_rec.known_as4             :=
                                NULL;
                            l_organization_rec.known_as5             :=
                                NULL;
                            l_organization_rec.local_bus_iden_type   :=
                                NULL;
                            l_organization_rec.local_bus_identifier   :=
                                NULL;
                            l_organization_rec.pref_functional_currency   :=
                                NULL;
                            l_organization_rec.registration_type     :=
                                NULL;
                            l_organization_rec.total_employees_text   :=
                                NULL;
                            l_organization_rec.total_employees_ind   :=
                                NULL;
                            l_organization_rec.total_emp_est_ind     :=
                                NULL;
                            l_organization_rec.total_emp_min_ind     :=
                                NULL;
                            l_organization_rec.parent_sub_ind        :=
                                NULL;
                            l_organization_rec.incorp_year           :=
                                NULL;
                            l_organization_rec.sic_code_type         :=
                                NULL;
                            l_organization_rec.public_private_ownership_flag   :=
                                NULL;
                            l_organization_rec.internal_flag         :=
                                NULL;
                            l_organization_rec.local_activity_code_type   :=
                                NULL;
                            l_organization_rec.local_activity_code   :=
                                NULL;
                            l_organization_rec.emp_at_primary_adr    :=
                                NULL;
                            l_organization_rec.emp_at_primary_adr_text   :=
                                NULL;
                            l_organization_rec.emp_at_primary_adr_est_ind   :=
                                NULL;
                            l_organization_rec.emp_at_primary_adr_min_ind   :=
                                NULL;
                            l_organization_rec.high_credit           :=
                                NULL;
                            l_organization_rec.avg_high_credit       :=
                                NULL;
                            l_organization_rec.total_payments        :=
                                NULL;
                            l_organization_rec.credit_score_class    :=
                                NULL;
                            l_organization_rec.credit_score_natl_percentile   :=
                                NULL;
                            l_organization_rec.credit_score_incd_default   :=
                                NULL;
                            l_organization_rec.credit_score_age      :=
                                NULL;
                            l_organization_rec.credit_score_date     :=
                                NULL;
                            l_organization_rec.credit_score_commentary2   :=
                                NULL;
                            l_organization_rec.credit_score_commentary3   :=
                                NULL;
                            l_organization_rec.credit_score_commentary4   :=
                                NULL;
                            l_organization_rec.credit_score_commentary5   :=
                                NULL;
                            l_organization_rec.credit_score_commentary6   :=
                                NULL;
                            l_organization_rec.credit_score_commentary7   :=
                                NULL;
                            l_organization_rec.credit_score_commentary8   :=
                                NULL;
                            l_organization_rec.credit_score_commentary9   :=
                                NULL;
                            l_organization_rec.credit_score_commentary10   :=
                                NULL;
                            l_organization_rec.failure_score_class   :=
                                NULL;
                            l_organization_rec.failure_score_incd_default   :=
                                NULL;
                            l_organization_rec.failure_score_age     :=
                                NULL;
                            l_organization_rec.failure_score_date    :=
                                NULL;
                            l_organization_rec.failure_score_commentary2   :=
                                NULL;
                            l_organization_rec.failure_score_commentary3   :=
                                NULL;
                            l_organization_rec.failure_score_commentary4   :=
                                NULL;
                            l_organization_rec.failure_score_commentary5   :=
                                NULL;
                            l_organization_rec.failure_score_commentary6   :=
                                NULL;
                            l_organization_rec.failure_score_commentary7   :=
                                NULL;
                            l_organization_rec.failure_score_commentary8   :=
                                NULL;
                            l_organization_rec.failure_score_commentary9   :=
                                NULL;
                            l_organization_rec.failure_score_commentary10   :=
                                NULL;
                            l_organization_rec.maximum_credit_recommendation   :=
                                NULL;
                            l_organization_rec.maximum_credit_currency_code   :=
                                NULL;
                            l_organization_rec.displayed_duns_party_id   :=
                                NULL;
                            l_organization_rec.content_source_type   :=
                                NULL;
                            l_organization_rec.content_source_number   :=
                                NULL;
                            l_organization_rec.attribute_category    :=
                                NULL;
                            l_organization_rec.application_id        :=
                                NULL;
                            l_organization_rec.do_not_confuse_with   :=
                                NULL;
                            l_organization_rec.actual_content_source   :=
                                NULL;
                            l_organization_rec.home_country          :=
                                NULL;
                            l_organization_rec.party_rec             :=
                                l_party_rec_type;
                            l_organization_rec.created_by_module     :=
                                'TCA_V1_API';
                            log_records (
                                gc_debug_flag,
                                   ' Calling create_organization to create customer '
                                || lt_customer_data (xc_customer_idx).organization_name);
                            create_organization (
                                p_organization_rec   => l_organization_rec,
                                v_org_party_id       => lx_org_party_id);
                        END IF;

                        IF (lx_cust_account_id = 0 AND NVL (lx_org_party_id, 0) > 0)
                        THEN
                            l_organization_rec.party_rec.party_id   :=
                                lx_org_party_id;
                            l_cust_account_rec.account_name   :=
                                lt_customer_data (xc_customer_idx).account_name;
                            l_cust_account_rec.cust_account_id   :=
                                lt_customer_data (xc_customer_idx).customer_id;

                            IF gc_generate_customer_number = gc_no_flag
                            THEN
                                l_cust_account_rec.account_number   :=
                                    lt_customer_data (xc_customer_idx).account_number;
                            ELSE
                                l_cust_account_rec.account_number   := NULL;
                            END IF;

                            --You cannot pass the account number because account number auto-generation is enabled.
                            --             l_cust_account_rec.customer_type           :=            lt_customer_data(xc_customer_idx).customer_prospect_code    ;
                            l_cust_account_rec.status        :=
                                lt_customer_data (xc_customer_idx).customer_status;
                            l_cust_account_rec.account_name   :=
                                lt_customer_data (xc_customer_idx).account_name;
                            l_cust_account_rec.customer_type   :=
                                lt_customer_data (xc_customer_idx).customer_type;

                            l_cust_account_rec.attribute_category   :=
                                lt_customer_data (xc_customer_idx).customer_attr_category;
                            l_cust_account_rec.attribute1    := 'ALL BRAND';
                            l_cust_account_rec.attribute2    :=
                                lt_customer_data (xc_customer_idx).customer_attribute2;
                            l_cust_account_rec.attribute3    := 'OTHER'; --lt_customer_data(xc_customer_idx).customer_attribute3    ;
                            l_cust_account_rec.attribute4    := NULL; --lt_customer_data(xc_customer_idx).customer_attribute4    ;
                            l_cust_account_rec.attribute5    :=
                                NVL (
                                    lt_customer_data (xc_customer_idx).customer_attribute5,
                                    'N');
                            l_cust_account_rec.attribute6    := 'N';
                            l_cust_account_rec.attribute7    := '0'; --NVL(lt_customer_data(xc_customer_idx).customer_attribute7,'0')    ;
                            l_cust_account_rec.attribute8    :=
                                lt_customer_data (xc_customer_idx).customer_attribute8;
                            l_cust_account_rec.attribute9    := '00';
                            l_cust_account_rec.attribute10   := NULL;
                            l_cust_account_rec.attribute11   := NULL;
                            --             l_cust_account_rec.attribute12                      :=            lt_customer_data(xc_customer_idx).customer_attribute12   ;
                            l_cust_account_rec.attribute13   := 'NON-BRAND'; --NVL(lt_customer_data(xc_customer_idx).customer_attribute13,'NON-BRAND')   ;
                            l_cust_account_rec.attribute14   := 'N'; --NVL(lt_customer_data(xc_customer_idx).customer_attribute14,'N')   ;
                            --             l_cust_account_rec.attribute15                      :=            lt_customer_data(xc_customer_idx).customer_attribute15   ;
                            --             l_cust_account_rec.attribute16                      :=            lt_customer_data(xc_customer_idx).customer_attribute16      ;
                            l_cust_account_rec.attribute17   :=
                                lt_customer_data (xc_customer_idx).customer_attribute17;
                            l_cust_account_rec.attribute18   :=
                                lt_customer_data (xc_customer_idx).customer_attribute18;
                            --             l_cust_account_rec.attribute19                      :=            lt_customer_data(xc_customer_idx).customer_attribute19  ;
                            --             l_cust_account_rec.attribute20                      :=            lt_customer_data(xc_customer_idx).customer_attribute20  ;
                            l_cust_account_rec.orig_system_reference   :=
                                lt_customer_data (xc_customer_idx).customer_id;
                            l_cust_account_rec.orig_system   :=
                                NULL;
                            l_cust_account_rec.sales_channel_code   :=
                                'OTHER'; -- lt_customer_data(xc_customer_idx).SALES_CHANNEL_CODE    ;


                            l_cust_account_rec.tax_code      :=
                                NULL;
                            l_cust_account_rec.fob_point     :=
                                NULL;
                            l_cust_account_rec.freight_term   :=
                                NULL;
                            l_cust_account_rec.ship_partial   :=
                                NULL;
                            l_cust_account_rec.ship_via      :=
                                NULL;
                            l_cust_account_rec.warehouse_id   :=
                                NULL;
                            l_cust_account_rec.tax_header_level_flag   :=
                                NULL;
                            l_cust_account_rec.tax_rounding_rule   :=
                                NULL;
                            l_cust_account_rec.coterminate_day_month   :=
                                NULL;
                            l_cust_account_rec.primary_specialist_id   :=
                                NULL;
                            l_cust_account_rec.secondary_specialist_id   :=
                                NULL;
                            l_cust_account_rec.account_liable_flag   :=
                                NULL;
                            l_cust_account_rec.current_balance   :=
                                NULL;
                            l_cust_account_rec.account_established_date   :=
                                NULL;
                            l_cust_account_rec.account_termination_date   :=
                                NULL;
                            l_cust_account_rec.account_activation_date   :=
                                NULL;
                            l_cust_account_rec.department    :=
                                NULL;
                            l_cust_account_rec.held_bill_expiration_date   :=
                                NULL;
                            l_cust_account_rec.hold_bill_flag   :=
                                NULL;
                            l_cust_account_rec.realtime_rate_flag   :=
                                NULL;
                            l_cust_account_rec.acct_life_cycle_status   :=
                                NULL;
                            l_cust_account_rec.deposit_refund_method   :=
                                NULL;
                            l_cust_account_rec.dormant_account_flag   :=
                                NULL;
                            l_cust_account_rec.npa_number    :=
                                NULL;
                            l_cust_account_rec.suspension_date   :=
                                NULL;
                            l_cust_account_rec.source_code   :=
                                NULL;
                            l_cust_account_rec.comments      :=
                                NULL;
                            l_cust_account_rec.dates_negative_tolerance   :=
                                NULL;
                            l_cust_account_rec.dates_positive_tolerance   :=
                                NULL;
                            l_cust_account_rec.date_type_preference   :=
                                NULL;
                            l_cust_account_rec.over_shipment_tolerance   :=
                                NULL;
                            l_cust_account_rec.under_shipment_tolerance   :=
                                NULL;
                            l_cust_account_rec.over_return_tolerance   :=
                                NULL;
                            l_cust_account_rec.under_return_tolerance   :=
                                NULL;
                            l_cust_account_rec.item_cross_ref_pref   :=
                                NULL;
                            l_cust_account_rec.ship_sets_include_lines_flag   :=
                                NULL;
                            l_cust_account_rec.arrivalsets_include_lines_flag   :=
                                NULL;
                            l_cust_account_rec.sched_date_push_flag   :=
                                NULL;
                            l_cust_account_rec.invoice_quantity_rule   :=
                                NULL;
                            l_cust_account_rec.pricing_event   :=
                                NULL;
                            l_cust_account_rec.status_update_date   :=
                                NULL;
                            l_cust_account_rec.autopay_flag   :=
                                NULL;
                            l_cust_account_rec.notify_flag   :=
                                NULL;
                            l_cust_account_rec.last_batch_id   :=
                                NULL;
                            l_cust_account_rec.selling_party_id   :=
                                NULL;
                            l_cust_account_rec.created_by_module   :=
                                'TCA_V1_API';
                            l_organization_rec.created_by_module   :=
                                'TCA_V1_API';
                            ln_profile_class_id              :=
                                NULL;                                  --Viswa



                            lr_customer_profile_rec          :=
                                NULL;



                            log_records (
                                gc_debug_flag,
                                   ' Calling create_cust_account to create customer  '
                                || lt_customer_data (xc_customer_idx).account_name);
                            create_cust_account (
                                p_cust_account_rec   => l_cust_account_rec,
                                p_organization_rec   => l_organization_rec,
                                p_customer_profile_rec   =>
                                    lr_customer_profile_rec,
                                v_cust_account_id    => lx_cust_account_id,
                                v_profile_id         => lx_profile_id,
                                --                                v_cust_account_profile_id  => lx_cust_account_profile_id,
                                x_return_status      => x_return_status);
                        END IF;

                        -- step1

                        IF    x_return_status = 'S'
                           OR (NVL (lx_org_party_id, 0) > 0 AND NVL (lx_cust_account_id, 0) > 0)
                        THEN
                            UPDATE XXD_AR_INT_CUSTOMER_STG_T
                               SET record_status = gc_process_status, request_id = gn_conc_request_id
                             WHERE customer_id =
                                   lt_customer_data (xc_customer_idx).customer_id;
                        ELSE
                            UPDATE XXD_AR_INT_CUSTOMER_STG_T
                               SET record_status = gc_error_status, request_id = gn_conc_request_id
                             WHERE customer_id =
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
                                || lt_customer_data (xc_customer_idx).account_name);
                            create_cust_address (
                                p_action            => p_action,
                                p_customer_id       =>
                                    lt_customer_data (xc_customer_idx).customer_id,
                                p_new_party_id      => lx_org_party_id,
                                p_cust_account_id   => lx_cust_account_id);

                            log_records (
                                gc_debug_flag,
                                   ' Calling create_cust_site_use to for customer '
                                || lt_customer_data (xc_customer_idx).account_name);
                            --         create_cust_site_use(  p_action                 =>       p_action,
                            --                                p_customer_id            =>       lt_customer_data(xc_customer_idx).customer_id
                            --                             );

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
                    --Create_brand_account;
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
    PROCEDURE validate_cust_sites_use (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_customer_id IN NUMBER
                                       , p_cust_acct_number IN NUMBER)
    AS
        --  PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_cust_site_use (p_action VARCHAR2)
        IS
              SELECT /*+ FIRST_ROWS(10) */
                     DISTINCT source_org_name, customer_id, address,
                              SITE_USE_CODE
                FROM xxd_ar_int_cust_site_use_stg_t xcsu
               WHERE     record_status IN (gc_new_status, gc_error_status)
                     AND customer_id = p_customer_id
            ORDER BY address, SITE_USE_CODE;

        --              AND  site_use_id =  p_site_use_id;

        TYPE lt_cust_site_use_typ IS TABLE OF cur_cust_site_use%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_site_use_data    lt_cust_site_use_typ;

        lc_site_use_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lx_site_use_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                 NUMBER := 0;
        ln_target_org_id         NUMBER := 0;
        ln_target_org            VARCHAR2 (250);
        ln_bill_seq_no           NUMBER;
        ln_ship_seq_no           NUMBER;
        lc_location              VARCHAR2 (250);
        lc_bill_to_location      VARCHAR2 (250);
    BEGIN
        log_records (p_debug, 'validate_cust_sites_use');

        OPEN cur_cust_site_use (p_action => p_action);

        ln_bill_seq_no   := 0;
        ln_ship_seq_no   := 0;

        LOOP
            FETCH cur_cust_site_use
                BULK COLLECT INTO lt_cust_site_use_data
                LIMIT 1000;

            IF lt_cust_site_use_data.COUNT > 0
            THEN
                FOR xc_site_use_idx IN lt_cust_site_use_data.FIRST ..
                                       lt_cust_site_use_data.LAST
                LOOP
                    --log_records (p_debug,'Start validation for Site Address' || lt_cust_site_use_data (xc_site_use_idx).ADDRESS1);
                    lc_site_use_valid_data   := gc_yes_flag;
                    --            gc_cust_site_use :=  lt_cust_site_use_data (xc_site_use_idx).site_use_code;
                    --              get_org_id (
                    --                                  p_org_name                 =>       lt_cust_site_use_data(xc_site_use_idx).source_org_name
                    --                                 ,x_org_id                   => ln_target_org );

                    ln_target_org_id         :=
                        get_org_id (
                            p_org_name   =>
                                lt_cust_site_use_data (xc_site_use_idx).source_org_name);

                    --
                    --                   IF lt_cust_site_data (xc_site_idx).TARGET_ORG IS NULL THEN
                    IF ln_target_org_id IS NULL
                    THEN
                        lc_site_use_valid_data   := gc_no_flag;
                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Conversion Program',
                            p_error_msg    =>
                                   'Exception Raised in TARGET_ORG Validation  Mapping not defined for the Organization =>'
                                || lt_cust_site_use_data (xc_site_use_idx).source_org_name,
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_cust_sites',
                            p_more_info2   => 'TARGET_ORG',
                            p_more_info3   => gc_customer_name,
                            p_more_info4   => gc_cust_address);
                    END IF;

                    ---- LOCATION BILL TO
                    lc_bill_to_location      := NULL;

                    IF lt_cust_site_use_data (xc_site_use_idx).SITE_USE_CODE =
                       'Bill To'
                    THEN
                        ln_bill_seq_no   := ln_bill_seq_no + 1;
                        lc_location      :=
                               'BT'
                            || ln_bill_seq_no
                            || '_'
                            || p_cust_acct_number;
                    ELSE
                        ln_ship_seq_no   := ln_ship_seq_no + 1;
                        lc_location      :=
                               'ST'
                            || ln_ship_seq_no
                            || '_'
                            || p_cust_acct_number;

                        --                  lc_bill_to_location := NULL ;

                        BEGIN
                            SELECT LOCATION
                              INTO lc_bill_to_location
                              FROM xxd_ar_int_cust_site_use_stg_t
                             WHERE     address =
                                       lt_cust_site_use_data (
                                           xc_site_use_idx).address
                                   AND SITE_USE_CODE = 'Bill To'
                                   AND customer_id =
                                       lt_cust_site_use_data (
                                           xc_site_use_idx).customer_id
                                   AND SOURCE_ORG_NAME =
                                       lt_cust_site_use_data (
                                           xc_site_use_idx).SOURCE_ORG_NAME;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_bill_to_location   := NULL;
                            WHEN OTHERS
                            THEN
                                lc_bill_to_location      := NULL;
                                lc_site_use_valid_data   := gc_no_flag;
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Conversion Program',
                                    p_error_msg    =>
                                           'Exception Raised in lc_bill_to_location Validation   =>'
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_sites',
                                    p_more_info2   => 'BILL_TO_LOCATION',
                                    p_more_info3   => gc_customer_name,
                                    p_more_info4   => gc_cust_address);
                        END;
                    END IF;

                    IF lc_site_use_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_int_cust_site_use_stg_t
                           SET record_status = gc_validate_status, target_org = ln_target_org_id, location = lc_location,
                               bill_to_location = lc_bill_to_location
                         WHERE     source_org_name =
                                   lt_cust_site_use_data (xc_site_use_idx).source_org_name
                               AND record_status = gc_new_status
                               AND customer_id =
                                   lt_cust_site_use_data (xc_site_use_idx).customer_id
                               AND address =
                                   lt_cust_site_use_data (xc_site_use_idx).address
                               AND SITE_USE_CODE =
                                   lt_cust_site_use_data (xc_site_use_idx).SITE_USE_CODE;
                    --                         AND  site_use_id = lt_cust_site_use_data (xc_site_use_idx).site_use_id;-- update site use table with VALID status
                    ELSE
                        UPDATE xxd_ar_int_cust_site_use_stg_t
                           SET record_status = gc_error_status, location = lc_location
                         WHERE     source_org_name =
                                   lt_cust_site_use_data (xc_site_use_idx).source_org_name
                               AND record_status = gc_new_status
                               AND customer_id =
                                   lt_cust_site_use_data (xc_site_use_idx).customer_id
                               AND address =
                                   lt_cust_site_use_data (xc_site_use_idx).address
                               AND SITE_USE_CODE =
                                   lt_cust_site_use_data (xc_site_use_idx).SITE_USE_CODE;
                    --                    WHERE customer_id =     lt_cust_site_use_data (xc_site_use_idx).customer_id
                    --                          AND  site_use_id = lt_cust_site_use_data (xc_site_use_idx).site_use_id;-- update site use table with VALID status
                    END IF;
                END LOOP;
            END IF;

            -- COMMIT;
            EXIT WHEN cur_cust_site_use%NOTFOUND;
        END LOOP;

        CLOSE cur_cust_site_use;
    --
    --            UPDATE XXD_AR_CUST_SITE_USES_STG_T
    --                      SET  RECORD_STATUS = gc_validate_status;
    --                    -- update site use table with VALID status
    --
    -- COMMIT;
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
    PROCEDURE validate_cust_sites (p_debug IN VARCHAR2 DEFAULT gc_no_flag, p_action IN VARCHAR2, p_customer_id IN NUMBER
                                   , p_cust_acct_number IN NUMBER)
    AS
        --   PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_cust_site (p_action VARCHAR2)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   DISTINCT hr.LOCATION_CODE, NVL (hr.ADDRESS_LINE_1, hr.ADDRESS_LINE_2) ADDRESS_LINE_1, DECODE (hr.ADDRESS_LINE_1, NULL, hr.ADDRESS_LINE_3, ADDRESS_LINE_2) ADDRESS_LINE_2,
                            DECODE (hr.ADDRESS_LINE_1, NULL, NULL, ADDRESS_LINE_3) ADDRESS_LINE_3, hr.TOWN_OR_CITY, hr.COUNTRY,
                            hr.POSTAL_CODE, hr.REGION_1 county, hr.REGION_2 state,
                            xcs.source_org_name, xcs.address_id, xcs.customer_id,
                            xcsu.ORGANIZATION_NAME, xcsu.ACCOUNT_DESCRIPTION, xcs.address,
                            INVENTORY_ORGANIZATION_ID, site_use_code
              FROM hr_locations hr, mtl_parameters mp, xxd_ar_int_cust_site_use_stg_t xcsu,
                   XXD_AR_INT_CUST_SITES_STG_T xcs
             WHERE     xcsu.ORGANIZATION_NAME = xcs.ORGANIZATION_NAME
                   AND xcsu.ACCOUNT_DESCRIPTION = xcs.ACCOUNT_DESCRIPTION
                   AND xcsu.address = xcs.address
                   AND xcsu.customer_id = xcs.customer_id
                   AND INVENTORY_ORGANIZATION_ID = ORGANIZATION_ID
                   AND ORGANIZATION_CODE = INTERNAL_ORGANIZATION
                   AND xcsu.record_status IN (gc_new_status, gc_error_status)
                   AND xcsu.customer_id = p_customer_id;

        TYPE lt_cust_site_typ IS TABLE OF cur_cust_site%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_site_data         lt_cust_site_typ;

        lc_cust_site_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lr_cust_site_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_target_org_id          NUMBER := 0;
        ln_count                  NUMBER := 0;
        ln_address_id             NUMBER := 0;
    BEGIN
        log_records (p_debug, 'validate_cust_sites');

        OPEN cur_cust_site (p_action => p_action);

        LOOP
            FETCH cur_cust_site
                BULK COLLECT INTO lt_cust_site_data
                LIMIT 1000;

            --CLOSE cur_cust_site;
            ln_target_org_id   := NULL;

            IF lt_cust_site_data.COUNT > 0
            THEN
                FOR xc_site_idx IN lt_cust_site_data.FIRST ..
                                   lt_cust_site_data.LAST
                LOOP
                    log_records (
                        p_debug,
                           'Start validation for Site Address'
                        || lt_cust_site_data (xc_site_idx).ADDRESS_LINE_1);
                    lc_cust_site_valid_data   := gc_yes_flag;

                    gc_cust_address           :=
                        lt_cust_site_data (xc_site_idx).ADDRESS_LINE_1;


                    BEGIN
                        SELECT location_id
                          INTO ln_address_id
                          FROM hz_locations
                         WHERE     ADDRESS1 =
                                   lt_cust_site_data (xc_site_idx).ADDRESS_LINE_1
                               --                       and ADDRESS2 =  lt_cust_site_data (xc_site_idx).ADDRESS_LINE_2
                               --                       and  ADDRESS3 =  lt_cust_site_data (xc_site_idx).ADDRESS_LINE_3
                               AND CITY =
                                   lt_cust_site_data (xc_site_idx).TOWN_OR_CITY
                               AND COUNTRY =
                                   lt_cust_site_data (xc_site_idx).COUNTRY
                               AND POSTAL_CODE =
                                   lt_cust_site_data (xc_site_idx).POSTAL_CODE
                               AND county =
                                   lt_cust_site_data (xc_site_idx).county
                               AND STATE =
                                   lt_cust_site_data (xc_site_idx).state;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_address_id   := NULL; -- hr_locations_s.nextval;
                        WHEN OTHERS
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Conversion Program',
                                p_error_msg    =>
                                       'Exception Raised in LN_ADDRESS_ID Validation  Mapping not defined for the Organization =>'
                                    || lt_cust_site_data (xc_site_idx).source_org_name,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_cust_sites',
                                p_more_info2   => 'LN_ADDRESS_ID',
                                p_more_info3   => gc_customer_name,
                                p_more_info4   => gc_cust_address);
                    END;


                    ln_target_org_id          :=
                        get_org_id (
                            p_org_name   =>
                                lt_cust_site_data (xc_site_idx).source_org_name);

                    --
                    --                   IF lt_cust_site_data (xc_site_idx).TARGET_ORG IS NULL THEN
                    IF ln_target_org_id IS NULL
                    THEN
                        lc_cust_site_valid_data   := gc_no_flag;
                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Conversion Program',
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

                    --         IF lt_cust_site_data (xc_site_idx).COUNTRY IS NULL THEN
                    --                              lc_cust_site_valid_data := gc_no_flag;
                    --         END IF;

                    IF lc_cust_site_valid_data = gc_yes_flag
                    THEN
                        --
                        --               CUSTOMER_ID,

                        UPDATE XXD_AR_INT_CUST_SITES_STG_T
                           SET record_status = gc_validate_status, target_org = ln_target_org_id, address_id = ln_address_id,
                               location = lt_cust_site_data (xc_site_idx).address, address1 = lt_cust_site_data (xc_site_idx).ADDRESS_LINE_1, address2 = lt_cust_site_data (xc_site_idx).ADDRESS_LINE_2,
                               address3 = lt_cust_site_data (xc_site_idx).ADDRESS_LINE_3, address4 = NULL, city = lt_cust_site_data (xc_site_idx).TOWN_OR_CITY,
                               country = lt_cust_site_data (xc_site_idx).COUNTRY, county = lt_cust_site_data (xc_site_idx).county, postal_code = lt_cust_site_data (xc_site_idx).POSTAL_CODE,
                               state = lt_cust_site_data (xc_site_idx).state
                         WHERE     customer_id =
                                   lt_cust_site_data (xc_site_idx).customer_id
                               AND ORGANIZATION_NAME =
                                   lt_cust_site_data (xc_site_idx).ORGANIZATION_NAME
                               AND ACCOUNT_DESCRIPTION =
                                   lt_cust_site_data (xc_site_idx).ACCOUNT_DESCRIPTION
                               AND address =
                                   lt_cust_site_data (xc_site_idx).address
                               AND source_org_name =
                                   lt_cust_site_data (xc_site_idx).source_org_name; -- update site table with VALID status
                    ELSE
                        UPDATE XXD_AR_INT_CUST_SITES_STG_T
                           SET record_status   = gc_error_status
                         WHERE     customer_id =
                                   lt_cust_site_data (xc_site_idx).customer_id
                               AND ORGANIZATION_NAME =
                                   lt_cust_site_data (xc_site_idx).ORGANIZATION_NAME
                               AND ACCOUNT_DESCRIPTION =
                                   lt_cust_site_data (xc_site_idx).ACCOUNT_DESCRIPTION
                               AND address =
                                   lt_cust_site_data (xc_site_idx).address
                               AND source_org_name =
                                   lt_cust_site_data (xc_site_idx).source_org_name;
                    END IF;

                    validate_cust_sites_use (
                        p_debug              => p_debug,
                        p_action             => p_action,
                        p_customer_id        => p_customer_id,
                        p_cust_acct_number   => p_cust_acct_number);
                END LOOP;
            END IF;

            --  COMMIT;
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
              FROM XXD_AR_INT_CUSTOMER_STG_T
             WHERE record_status = p_action AND BATCH_NUMBER = p_batch_id;

        TYPE lt_customer_typ IS TABLE OF cur_customer%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_customer_data     lt_customer_typ;

        lc_cust_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count             NUMBER := 0;
        lc_customer_type     VARCHAR2 (1);
        ln_party_id          NUMBER;
        ln_customer_id       NUMBER;
        ln_customer_number   NUMBER;
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
                        || lt_customer_data (xc_customer_idx).organization_name);
                    -- Check the customer already in the 12 2 3 system
                    ln_party_id          := NULL;
                    ln_customer_id       := NULL;
                    ln_customer_number   := NULL;

                    IF lt_customer_data (xc_customer_idx).organization_name
                           IS NOT NULL
                    THEN
                        BEGIN
                            SELECT hp.PARTY_ID, hca.cust_account_id, hca.account_number
                              INTO ln_party_id, ln_customer_id, ln_customer_number
                              FROM hz_parties hp, hz_cust_accounts_all hca
                             WHERE     hp.party_id = hca.party_id
                                   AND party_name =
                                       lt_customer_data (xc_customer_idx).organization_name;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_valid_data   := gc_yes_flag;

                                ln_party_id          := hz_parties_s.NEXTVAL;
                                ln_customer_id       :=
                                    hz_cust_accounts_s.NEXTVAL;
                                ln_customer_number   :=
                                    HZ_ACCOUNT_NUM_S.NEXTVAL;
                            WHEN OTHERS
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Internal Conversion Program',
                                    p_error_msg    =>
                                           'Exception Raised in ORGANIZATION_NAME validation =>'
                                        || lt_customer_data (xc_customer_idx).organization_name,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'ORGANIZATION_NAME',
                                    p_more_info2   =>
                                        lt_customer_data (xc_customer_idx).organization_name,
                                    p_more_info3   => gc_customer_name,
                                    p_more_info4   => gc_cust_address);
                        END;
                    END IF;


                    --               lc_cust_valid_data := gc_yes_flag;
                    IF lc_cust_valid_data = gc_yes_flag
                    THEN
                        UPDATE XXD_AR_INT_CUSTOMER_STG_T
                           SET record_status = gc_validate_status, request_id = gn_conc_request_id, party_id = ln_party_id,
                               customer_id = ln_customer_id, cust_account_id = ln_customer_id, Account_number = ln_customer_number,
                               CUSTOMER_PROSPECT_CODE = 'CUSTOMER', CUSTOMER_TYPE = 'I', CUSTOMER_STATUS = 'A',
                               PARTY_TYPE = 'ORGANIZATION', SALES_CHANNEL_CODE = 'OTHER'
                         WHERE     organization_name =
                                   lt_customer_data (xc_customer_idx).organization_name
                               AND ACCOUNT_NAME =
                                   lt_customer_data (xc_customer_idx).ACCOUNT_NAME; -- update customer table with VALID status

                        UPDATE XXD_AR_INT_CUST_SITES_STG_T
                           SET          -- record_status = gc_validate_status,
                               customer_id   = ln_customer_id
                         WHERE     organization_name =
                                   lt_customer_data (xc_customer_idx).organization_name
                               AND account_description =
                                   lt_customer_data (xc_customer_idx).ACCOUNT_NAME;


                        UPDATE XXD_AR_INT_CUST_SITE_USE_STG_T
                           SET           --record_status = gc_validate_status,
                               customer_id   = ln_customer_id
                         WHERE     organization_name =
                                   lt_customer_data (xc_customer_idx).organization_name
                               AND account_description =
                                   lt_customer_data (xc_customer_idx).ACCOUNT_NAME;
                    ELSE
                        UPDATE XXD_AR_INT_CUSTOMER_STG_T
                           SET record_status = gc_error_status, request_id = gn_conc_request_id, party_id = ln_party_id,
                               customer_id = ln_customer_id, cust_account_id = ln_customer_id, Account_number = ln_customer_number,
                               CUSTOMER_PROSPECT_CODE = 'CUSTOMER', CUSTOMER_TYPE = 'I', CUSTOMER_STATUS = 'A',
                               PARTY_TYPE = 'ORGANIZATION', SALES_CHANNEL_CODE = 'OTHER'
                         WHERE     organization_name =
                                   lt_customer_data (xc_customer_idx).organization_name
                               AND ACCOUNT_NAME =
                                   lt_customer_data (xc_customer_idx).ACCOUNT_NAME;

                        UPDATE XXD_AR_INT_CUST_SITES_STG_T
                           SET record_status   = gc_error_status
                         WHERE     organization_name =
                                   lt_customer_data (xc_customer_idx).organization_name
                               AND account_description =
                                   lt_customer_data (xc_customer_idx).ACCOUNT_NAME;

                        UPDATE XXD_AR_INT_CUST_SITE_USE_STG_T
                           SET record_status   = gc_error_status
                         WHERE     organization_name =
                                   lt_customer_data (xc_customer_idx).organization_name
                               AND account_description =
                                   lt_customer_data (xc_customer_idx).ACCOUNT_NAME;
                    END IF;

                    validate_cust_sites (
                        p_debug              => p_debug,
                        p_action             => p_action,
                        p_customer_id        => ln_customer_id,
                        p_cust_acct_number   => ln_customer_number);
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

    /****************************************************************************************
      *  Procedure Name :   customer_validation                                              *
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

    PROCEDURE customer_validation (errbuf          OUT VARCHAR2,
                                   retcode         OUT VARCHAR2,
                                   p_action     IN     VARCHAR2,
                                   p_org_name   IN     VARCHAR2,
                                   p_batch_id   IN     NUMBER)
    AS
        ln_count          NUMBER := 0;
        l_target_org_id   NUMBER := 0;
    BEGIN
        retcode   := NULL;
        errbuf    := NULL;
        log_records (gc_debug_flag,
                     'validate Customer p_action =.  ' || p_action);

        --      IF p_validation_level = 'CUSTOMER'
        --      THEN
        validate_customer (p_debug      => gc_debug_flag,
                           p_action     => p_action,
                           p_batch_id   => p_batch_id);
    --      ELSIF p_validation_level = 'SITE'
    --      THEN
    --         validate_cust_sites (p_debug      => gc_debug_flag,
    --                              p_action     => p_action,
    --                              p_batch_id   => p_batch_id);
    --      ELSIF p_validation_level = 'SITEUSE'
    --      THEN
    --         validate_cust_sites_use (p_debug      => gc_debug_flag,
    --                                  p_action     => p_action,
    --                                  p_batch_id   => p_batch_id);
    --
    --      END IF;
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
                                  , p_org_name IN VARCHAR2, -- p_customer_classification   IN     VARCHAR2,
                                                            p_debug_flag IN VARCHAR2, p_no_of_process IN NUMBER)
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


            log_records (
                gc_debug_flag,
                'Woking on extract the data for the OU ' || p_org_name);
        ELSIF p_process = gc_validate_only
        THEN
            UPDATE XXD_AR_INT_CUSTOMER_STG_T
               SET batch_number = NULL, record_status = gc_new_status
             WHERE record_status = gc_new_status; -- IN( gc_new_status,gc_error_status);

            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM XXD_AR_INT_CUSTOMER_STG_T
             WHERE batch_number IS NULL AND record_status = gc_new_status;

            --write_log ('Creating Batch id and update  XXD_AR_CUST_INT_STG_T');

            -- Create batches of records and assign batch id

            --         lc_hdr_customer_proc_t (1) := 'CUSTOMER';
            --         lc_hdr_customer_proc_t (2) := 'PROFILE';
            --         lc_hdr_customer_proc_t (3) := 'SITE';
            --         lc_hdr_customer_proc_t (4) := 'SITEUSE';
            --         lc_hdr_customer_proc_t (5) := 'CONTACT';
            --         lc_hdr_customer_proc_t (6) := 'CONTACTPOINT';

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

                UPDATE XXD_AR_INT_CUSTOMER_STG_T
                   SET batch_number = ln_hdr_batch_id (i), request_id = ln_parent_request_id
                 WHERE     batch_number IS NULL
                       AND ROWNUM <=
                           CEIL (ln_valid_rec_cnt / p_no_of_process)
                       AND record_status = gc_new_status;

                COMMIT;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_AR_INT_CUSTOMER_STG_T');

            FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM XXD_AR_INT_CUSTOMER_STG_T
                 WHERE     record_status = gc_new_status
                       AND batch_number = ln_hdr_batch_id (i);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                'XXDCONV',
                                'XXD_INT_CUSTOMER_CONV_CHILD',
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
                                   'Calling WAIT FOR REQUEST XXD_AR_INT_CUST_CHILD_CONV error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_AR_INT_CUST_CHILD_CONV error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;
        --validate_cust_proc (x_errcode, x_errmsg, lc_debug_flag);
        ELSIF p_process = gc_load_only
        THEN
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_AR_INT_CUSTOMER_STG_T stage to call worker process');
            ln_cntr   := 0;

            FOR i
                IN (SELECT DISTINCT batch_number
                      FROM XXD_AR_INT_CUSTOMER_STG_T
                     WHERE     batch_number IS NOT NULL
                           AND record_status = gc_validate_status)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_number;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_AR_INT_CUSTOMER_STG_T');

            COMMIT;

            IF ln_hdr_batch_id.COUNT > 0
            THEN
                log_records (
                    gc_debug_flag,
                       'Calling XXD_INT_CUSTOMER_CONV_CHILD in batch '
                    || ln_hdr_batch_id.COUNT);

                FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
                LOOP
                    SELECT COUNT (*)
                      INTO ln_cntr
                      FROM XXD_AR_INT_CUSTOMER_STG_T
                     WHERE batch_number = ln_hdr_batch_id (i);

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
                                    'XXD_INT_CUSTOMER_CONV_CHILD',
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
                                       'Calling WAIT FOR REQUEST XXD_AR_INT_CUST_CHILD_CONV error'
                                    || SQLERRM);
                            WHEN OTHERS
                            THEN
                                x_retcode   := 2;
                                x_errbuf    := x_errbuf || SQLERRM;
                                log_records (
                                    gc_debug_flag,
                                       'Calling WAIT FOR REQUEST XXD_AR_INT_CUST_CHILD_CONV error'
                                    || SQLERRM);
                        END;
                    END IF;
                END LOOP;
            END IF;

            log_records (
                gc_debug_flag,
                   'Calling XXD_AR_INT_CUST_CHILD_CONV in batch '
                || ln_hdr_batch_id.COUNT);
            log_records (
                gc_debug_flag,
                'Calling WAIT FOR REQUEST XXD_AR_INT_CUST_CHILD_CONV to complete');

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
    PROCEDURE customer_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, p_org_name IN VARCHAR2, p_batch_id IN NUMBER
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
        l_target_org_id      := get_targetorg_id (p_org_name => p_org_name);
        gn_org_id            := NVL (l_target_org_id, gn_org_id);

        IF p_action = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling customer_validation :');

            customer_validation (errbuf       => errbuf,
                                 retcode      => retcode,
                                 p_action     => gc_new_status,
                                 p_org_name   => p_org_name,
                                 p_batch_id   => p_batch_id--                              p_validation_level   => p_validation_level
                                                           );
        ELSIF p_action = gc_load_only
        THEN
            l_target_org_id   := get_targetorg_id (p_org_name => p_org_name);

            BEGIN
                --fnd_global.apps_initialize(1643,20678,222);
                mo_global.init ('AR');
                mo_global.set_policy_context ('S', l_target_org_id);

                SELECT generate_customer_number
                  INTO gc_generate_customer_number
                  FROM ar_system_parameters_all
                 WHERE org_id = l_target_org_id;

                IF gc_generate_customer_number = gc_yes_flag
                THEN                 --gc_auto_site_numbering = gc_yes_flag OR
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

            /*IF fnd_profile.value('HZ_GENERATE_PARTY_NUMBER') IS NULL OR fnd_profile.value('HZ_GENERATE_PARTY_NUMBER') = 'Y'   THEN
              fnd_file.put_line (fnd_file.output, 'HZ: Generate Party Number is set to NULL or Yes');
              fnd_file.put_line (fnd_file.log, 'HZ: Generate Party Number is set to NULL or Yes');
             RAISE NO_DATA_FOUND;
            END IF;*/
            log_records (gc_debug_flag, 'Calling create_customer +');
            create_customer (x_errbuf           => errbuf,
                             x_retcode          => retcode,
                             p_action           => gc_validate_status,
                             p_operating_unit   => p_org_name,
                             p_target_org_id    => l_target_org_id,
                             p_batch_id         => p_batch_id);
        --         create_person (x_errbuf           => errbuf,
        --                        x_retcode          => retcode,
        --                        p_action           => gc_validate_status,
        --                        p_operating_unit   => p_org_name,
        --                        p_target_org_id    => l_target_org_id,
        --                        p_batch_id         => p_batch_id);
        --      ELSIF p_action = 'VALIDATE AND LOAD'
        --      THEN
        --         NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.output,
                               'Exception Raised During Customer Program');
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END customer_child;
END XXD_INT_CUSTOMER_CONV_PKG;
/
