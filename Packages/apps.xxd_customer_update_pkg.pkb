--
-- XXD_CUSTOMER_UPDATE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_customer_update_pkg
AS
    /*******************************************************************************
     * Program Name : XXD_CUSTOMER_UPDATE_PKG
     * Language     : PL/SQL
     * Description  : This package will update party, Customer, location, site,
     *                uses, contacts, account.
     *
     * History      :
     *
     * WHO                  WHAT              DESC                       WHEN
     * -------------- ---------------------------------------------- ---------------
     * BT Technology Team   1.0              Initial Version          27-MAY-2015
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

    gn_api_version_number            NUMBER := 1.0;
    gc_commit                        VARCHAR2 (10) := fnd_api.g_false;
    gc_init_msg_list                 VARCHAR2 (10) := fnd_api.g_false;

    TYPE xxd_ar_cust_int_tab IS TABLE OF xxd_ar_customer_upd_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_int_tab              xxd_ar_cust_int_tab;

    TYPE xxd_ar_cust_site_int_tab
        IS TABLE OF xxd_ar_cust_sites_upd_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_site_int_tab         xxd_ar_cust_site_int_tab;

    TYPE xxd_ar_cust_site_use_tab
        IS TABLE OF xxd_ar_cust_siteuse_upd_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_site_use_int_tab     xxd_ar_cust_site_use_tab;

    TYPE xxd_ar_cust_cont_int_tab
        IS TABLE OF xxd_ar_contact_upd_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_cont_int_tab         xxd_ar_cust_cont_int_tab;

    TYPE xxd_ar_cust_cont_pt_int_tab
        IS TABLE OF xxd_ar_cont_point_upd_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_cont_point_int_tab   xxd_ar_cust_cont_pt_int_tab;

    TYPE xxd_ar_cust_prof_int_tab
        IS TABLE OF xxd_ar_cust_prof_upd_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_prof_int_tab         xxd_ar_cust_prof_int_tab;

    TYPE xxd_ar_cust_profamt_upd_tab
        IS TABLE OF xxd_ar_cust_profamt_upd_stg_t%ROWTYPE
        INDEX BY BINARY_INTEGER;

    gtt_ar_cust_prof_amt_int_tab     xxd_ar_cust_profamt_upd_tab;

    -- +===================================================================+
    -- | Name  : log_records                                               |
    -- | Description      : This procedure will log records in log file    |
    -- |                                                                   |
    -- | Parameters : p_debug                                              |
    -- |              p_message                                            |
    -- |                                                                   |
    -- +===================================================================+
    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    -- +===================================================================+
    -- | Name  : get_targetorg_id                                          |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name                                           |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+

    FUNCTION get_targetorg_id (p_org_name IN VARCHAR2)
        RETURN NUMBER
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
                'Decker Customer Conversion Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_targetorg_id;

    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_org_name                                           |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+
    FUNCTION get_org_id (p_org_name IN VARCHAR2)
        RETURN NUMBER
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
            p_lookup_type    => 'XXD_1206_OU_MAPPING' -- Lookup type for mapping
                                                     ,
            px_lookup_code   => px_lookup_code -- Would generally be id of 12.0.6. eg: org_id
                                              ,
            px_meaning       => px_meaning      -- internal name of old entity
                                          ,
            px_description   => px_description       -- name of the old entity
                                              ,
            x_attribute1     => x_attribute1 -- corresponding new 12.2.3 value
                                            ,
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
                'Decker Customer Conversion Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_org_name,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_org_id;

    -- +===================================================================+
    -- | Name  : GET_ORG_ID                                                |
    -- | Description      : This procedure  is used to get                 |
    -- |                    org id from EBS                                |
    -- |                                                                   |
    -- | Parameters : p_1206_org_id                                        |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns : x_org_id                                                |
    -- |                                                                   |
    -- +===================================================================+

    FUNCTION get_org_id (p_1206_org_id IN NUMBER)
        RETURN NUMBER
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
            p_lookup_type    => 'XXD_1206_OU_MAPPING' -- Lookup type for mapping
                                                     ,
            px_lookup_code   => px_lookup_code -- Would generally be id of 12.0.6. eg: org_id
                                              ,
            px_meaning       => px_meaning      -- internal name of old entity
                                          ,
            px_description   => px_description       -- name of the old entity
                                              ,
            x_attribute1     => x_attribute1 -- corresponding new 12.2.3 value
                                            ,
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
                'Decker Customer Conversion Program',
                SQLERRM,
                DBMS_UTILITY.format_error_backtrace,
                gn_user_id,
                gn_conc_request_id,
                'GET_ORG_ID',
                p_1206_org_id,
                'Exception to GET_ORG_ID Procedure' || SQLERRM);
            --       write_log( 'Exception to GET_ORG_ID Procedure' || SQLERRM);
            RETURN NULL;
    END get_org_id;

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


    /*****************************************************************************************
     *  Procedure Name :   VALIDATE_CUSTOMER                                                 *
     *                                                                                       *
     *  Description    :   This Procedure will validate the customer table                   *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE validate_customer (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_customer IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_customer_upd_stg_t
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_customer_typ IS TABLE OF cur_customer%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_customer_data     lt_customer_typ;

        lc_cust_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count             NUMBER := 0;
        ln_cust_account_id   NUMBER;
        ln_party_id          NUMBER;
        lc_error_message     VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'validate_customer');

        OPEN cur_customer;

        LOOP
            FETCH cur_customer BULK COLLECT INTO lt_customer_data LIMIT 1000;

            IF lt_customer_data.COUNT > 0
            THEN
                FOR xc_customer_idx IN lt_customer_data.FIRST ..
                                       lt_customer_data.LAST
                LOOP
                    log_records (gc_debug_flag,
                                 '*****************************************');

                    log_records (
                        gc_debug_flag,
                           'customer_name : '
                        || lt_customer_data (xc_customer_idx).customer_name);
                    log_records (
                        gc_debug_flag,
                           'customer_id : '
                        || lt_customer_data (xc_customer_idx).customer_id);
                    -- Check the customer already in the 12 2 3 system

                    lc_cust_valid_data   := gc_yes_flag;
                    lc_error_message     := NULL;

                    /*SELECT COUNT ( 1 )
                      INTO ln_count
                      FROM xxd_conv.xx_exclude_legacy
                     WHERE cust_number = lt_customer_data ( xc_customer_idx ).customer_number;

                    IF ln_count > 0
                    THEN
                      SELECT COUNT ( * )
                        INTO ln_count
                        FROM xxd_cust_gl_acc_segment_map_t
                       WHERE customer_number = lt_customer_data ( xc_customer_idx ).customer_number;

                      IF ln_count = 0
                      THEN
                        SELECT COUNT ( * )
                          INTO ln_count
                          FROM xxd_ret_n_int_cust_map
                         WHERE customer_number = lt_customer_data ( xc_customer_idx ).customer_number;
                      END IF;

                      IF ln_count = 0
                      THEN
                        lc_cust_valid_data   := gc_no_flag;
                        log_records ( gc_debug_flag
                                    ,  'Account mapping validation failed' );
                        lc_error_message      :=
                          SUBSTR (    lc_error_message
                                   || 'Account Mapping not found for the customer-account '
                                   || lt_customer_data ( xc_customer_idx ).customer_number
                                   || '; '
                                 ,  1
                                 ,  4000 );
                        xxd_common_utils.record_error ( p_module    => 'AR'
                                                      ,  p_org_id    => gn_org_id
                                                      ,  p_program   => 'Deckers AR Customer Update Program'
                                                      ,  p_error_msg =>    'Account Mapping not found for the customer-account '
                                                                        || lt_customer_data ( xc_customer_idx ).customer_number
                                                      ,  p_error_line => DBMS_UTILITY.format_error_backtrace
                                                      ,  p_created_by => gn_user_id
                                                      ,  p_request_id => gn_conc_request_id
                                                      ,  p_more_info1 => 'validate_customer'
                                                      ,  p_more_info2 => lt_customer_data ( xc_customer_idx ).customer_number
                                                      ,  p_more_info3 => 'ACCOUNT_TYPE'
                                                      ,  p_more_info4 => NULL );
                      END IF;
                    END IF;*/

                    IF lt_customer_data (xc_customer_idx).orig_system_party_ref
                           IS NULL
                    THEN
                        lc_cust_valid_data   := gc_no_flag;
                        log_records (gc_debug_flag,
                                     'Party reference validation failed');
                        lc_error_message     :=
                            SUBSTR (
                                   lc_error_message
                                || 'Party reference is NULL; ',
                                1,
                                4000);

                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Update Program',
                            p_error_msg    =>
                                'Exception Raised in ORIG_SYSTEM_PARTY_REF Validation',
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_customer',
                            p_more_info2   => 'ORIG_SYSTEM_PARTY_REF',
                            p_more_info3   =>
                                lt_customer_data (xc_customer_idx).customer_number,
                            p_more_info4   => NULL);
                    END IF;

                    IF lt_customer_data (xc_customer_idx).customer_status NOT IN
                           ('A', 'I')
                    THEN
                        lc_cust_valid_data   := gc_no_flag;
                        log_records (gc_debug_flag,
                                     'Customer status validation failed');
                        lc_error_message     :=
                            SUBSTR (
                                   lc_error_message
                                || 'Customer status is invalid; ',
                                1,
                                4000);

                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Update Program',
                            p_error_msg    =>
                                'Exception Raised in CUSTOMER_STATUS Validation',
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_customer',
                            p_more_info2   => 'CUSTOMER_STATUS',
                            p_more_info3   =>
                                lt_customer_data (xc_customer_idx).customer_number,
                            p_more_info4   => NULL);
                    END IF;

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
                            log_records (
                                gc_debug_flag,
                                'Customer type validation failed ' || SQLERRM);
                            lc_error_message     :=
                                SUBSTR (
                                       lc_error_message
                                    || 'Customer type is invalid; ',
                                    1,
                                    4000);

                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Update Program',
                                p_error_msg    =>
                                       'Exception Raised in CUSTOMER_TYPE Validation '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_customer',
                                p_more_info2   => 'CUSTOMER_TYPE',
                                p_more_info3   =>
                                    lt_customer_data (xc_customer_idx).customer_number,
                                p_more_info4   => NULL);
                        WHEN OTHERS
                        THEN
                            lc_cust_valid_data   := gc_no_flag;
                            log_records (
                                gc_debug_flag,
                                'Customer type validation failed ' || SQLERRM);
                            lc_error_message     :=
                                SUBSTR (
                                       lc_error_message
                                    || 'Customer type is invalid; ',
                                    1,
                                    4000);

                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Update Program',
                                p_error_msg    =>
                                       'Exception Raised in CUSTOMER_TYPE Validation '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_customer',
                                p_more_info2   => 'CUSTOMER_TYPE',
                                p_more_info3   =>
                                    lt_customer_data (xc_customer_idx).customer_number,
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
                                log_records (
                                    gc_debug_flag,
                                       'Customer category validation failed '
                                    || SQLERRM);
                                lc_error_message     :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer category is invalid; ',
                                        1,
                                        4000);

                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Exception Raised in CUSTOMER_CATEGORY Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CUSTOMER_CATEGORY',
                                    p_more_info3   =>
                                        lt_customer_data (xc_customer_idx).customer_number,
                                    p_more_info4   => NULL);
                            WHEN OTHERS
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer category validation failed '
                                    || SQLERRM);
                                lc_error_message     :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer category is invalid; ',
                                        1,
                                        4000);

                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Exception Raised in CUSTOMER_CATEGORY Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CUSTOMER_CATEGORY',
                                    p_more_info3   =>
                                        lt_customer_data (xc_customer_idx).customer_number,
                                    p_more_info4   => NULL);
                        END;
                    END IF;

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
                                log_records (
                                    gc_debug_flag,
                                       'Customer Class validation failed '
                                    || SQLERRM);
                                lc_error_message     :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer class code is invalid; ',
                                        1,
                                        4000);

                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Exception Raised in CUSTOMER CLASS Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CUSTOMER CLASS',
                                    p_more_info3   =>
                                        lt_customer_data (xc_customer_idx).customer_number,
                                    p_more_info4   => NULL);
                            WHEN OTHERS
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Class validation failed '
                                    || SQLERRM);
                                lc_error_message     :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer class code is invalid; ',
                                        1,
                                        4000);

                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Exception Raised in CUSTOMER CLASS Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CUSTOMER CLASS',
                                    p_more_info3   =>
                                        lt_customer_data (xc_customer_idx).customer_number,
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
                                       'Contact title validation failed '
                                    || SQLERRM);

                                lc_error_message     :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Contact title is invalid; ',
                                        1,
                                        4000);

                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Exception Raised in CONTACT_TITLE Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CONTACT_TITLE',
                                    p_more_info3   =>
                                        lt_customer_data (xc_customer_idx).customer_number,
                                    p_more_info4   =>
                                        lt_customer_data (xc_customer_idx).person_pre_name_adjunct);
                            WHEN OTHERS
                            THEN
                                lc_cust_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Contact title validation failed '
                                    || SQLERRM);
                                lc_error_message     :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Contact title is invalid; ',
                                        1,
                                        4000);

                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Exception Raised in CONTACT_TITLE Validation '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_customer',
                                    p_more_info2   => 'CONTACT_TITLE',
                                    p_more_info3   =>
                                        lt_customer_data (xc_customer_idx).customer_number,
                                    p_more_info4   =>
                                        lt_customer_data (xc_customer_idx).person_pre_name_adjunct);
                        END;
                    END IF;

                    BEGIN
                        ln_cust_account_id   := NULL;
                        ln_party_id          := NULL;

                        SELECT hp.party_id, hca.cust_account_id
                          INTO ln_party_id, ln_cust_account_id
                          FROM hz_parties hp, hz_cust_accounts hca
                         WHERE     hp.party_id = hca.party_id
                               AND hp.party_type =
                                   lt_customer_data (xc_customer_idx).party_type
                               AND hca.orig_system_reference =
                                   TO_CHAR (
                                       lt_customer_data (xc_customer_idx).customer_id)
                               AND hp.orig_system_reference =
                                   TO_CHAR (
                                       lt_customer_data (xc_customer_idx).orig_system_party_ref);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_cust_valid_data   := gc_no_flag;
                            log_records (
                                gc_debug_flag,
                                   'Customer check validation failed '
                                || SQLERRM);

                            lc_error_message     :=
                                SUBSTR (
                                       lc_error_message
                                    || 'Customer derivation failed; ',
                                    1,
                                    4000);

                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Update Program',
                                p_error_msg    =>
                                       'Customer derivation failed : '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_customer',
                                p_more_info2   => 'DERIVE_CUSTOMER',
                                p_more_info3   =>
                                    lt_customer_data (xc_customer_idx).customer_number,
                                p_more_info4   =>
                                    lt_customer_data (xc_customer_idx).customer_id);
                        WHEN OTHERS
                        THEN
                            lc_cust_valid_data   := gc_no_flag;
                            log_records (
                                gc_debug_flag,
                                   'Customer check validation failed '
                                || SQLERRM);

                            lc_error_message     :=
                                SUBSTR (
                                       lc_error_message
                                    || 'Customer is not available in system; ',
                                    1,
                                    4000);

                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Update Program',
                                p_error_msg    =>
                                       'Customer derivation failed : '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_customer',
                                p_more_info2   => 'DERIVE_CUSTOMER',
                                p_more_info3   =>
                                    lt_customer_data (xc_customer_idx).customer_number,
                                p_more_info4   =>
                                    lt_customer_data (xc_customer_idx).customer_id);
                    END;


                    IF lc_cust_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_customer_upd_stg_t
                           SET record_status = gc_validate_status, error_message = NULL, request_id = gn_conc_request_id
                         WHERE customer_id =
                               lt_customer_data (xc_customer_idx).customer_id;
                    ELSE
                        UPDATE xxd_ar_customer_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message, request_id = gn_conc_request_id
                         WHERE customer_id =
                               lt_customer_data (xc_customer_idx).customer_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_customer%NOTFOUND;
        END LOOP;

        CLOSE cur_customer;

        COMMIT;
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
     *  Procedure Name :   VALIDATE_CUST_SITES                                               *
     *                                                                                       *
     *  Description    :   This Procedure will validate the customer site table              *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE validate_cust_sites (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_cust_site IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_sites_upd_stg_t xcs
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_cust_site_typ IS TABLE OF cur_cust_site%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_site_data         lt_cust_site_typ;

        lc_cust_site_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lr_cust_site_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_target_org_id          NUMBER := 0;
        ln_count                  NUMBER := 0;
        lc_error_message          VARCHAR2 (4000);
        ln_cust_acct_site_id      NUMBER;
    BEGIN
        log_records (p_debug, 'validate_cust_sites');

        OPEN cur_cust_site;

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
                    log_records (gc_debug_flag,
                                 '************************************');
                    log_records (
                        gc_debug_flag,
                           'customer_id : '
                        || lt_cust_site_data (xc_site_idx).customer_id);
                    log_records (
                        gc_debug_flag,
                           'address_id : '
                        || lt_cust_site_data (xc_site_idx).address_id);
                    log_records (
                        gc_debug_flag,
                           'target_org : '
                        || lt_cust_site_data (xc_site_idx).target_org);

                    lc_cust_site_valid_data   := gc_yes_flag;
                    lc_error_message          := NULL;

                    IF lt_cust_site_data (xc_site_idx).address1 IS NULL
                    THEN
                        lc_cust_site_valid_data   := gc_no_flag;
                        lc_error_message          :=
                            SUBSTR (
                                lc_error_message || 'Site address1 is NULL; ',
                                1,
                                4000);

                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Update Program',
                            p_error_msg    =>
                                'Exception Raised in ADDRESS1 Validation ',
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_cust_sites',
                            p_more_info2   => 'ADDRESS1',
                            p_more_info3   =>
                                lt_cust_site_data (xc_site_idx).customer_id,
                            p_more_info4   =>
                                lt_cust_site_data (xc_site_idx).address_id);
                    END IF;

                    ln_target_org_id          :=
                        get_org_id (
                            p_1206_org_id   =>
                                lt_cust_site_data (xc_site_idx).source_org_id);

                    IF ln_target_org_id IS NULL
                    THEN
                        lc_cust_site_valid_data   := gc_no_flag;
                        lc_error_message          :=
                            SUBSTR (
                                   lc_error_message
                                || 'Target Org ID derivation failed; ',
                                1,
                                4000);
                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Update Program',
                            p_error_msg    =>
                                   'Exception Raised in TARGET_ORG Validation  Mapping not defined for the Organization =>'
                                || lt_cust_site_data (xc_site_idx).source_org_name,
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_cust_sites',
                            p_more_info2   => 'TARGET_ORG',
                            p_more_info3   =>
                                lt_cust_site_data (xc_site_idx).customer_id,
                            p_more_info4   =>
                                lt_cust_site_data (xc_site_idx).address_id);
                    ELSE
                        BEGIN
                            ln_cust_acct_site_id   := NULL;

                            SELECT hcas.cust_acct_site_id
                              INTO ln_cust_acct_site_id
                              FROM hz_cust_acct_sites_all hcas, hz_party_sites hps, hz_locations hl,
                                   hz_parties hp, hz_cust_accounts hca
                             WHERE     hp.party_id = hca.party_id
                                   AND hp.party_id = hps.party_id
                                   AND hps.location_id = hl.location_id
                                   AND hcas.cust_account_id =
                                       hca.cust_account_id
                                   AND hcas.party_site_id = hps.party_site_id
                                   AND hca.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_site_data (xc_site_idx).customer_id)
                                   AND hcas.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_site_data (xc_site_idx).address_id)
                                   AND hcas.org_id = ln_target_org_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_site_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Site derivation failed '
                                    || SQLERRM);
                                lc_error_message          :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Site derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Site derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_sites',
                                    p_more_info2   => 'DERIVE_SITE',
                                    p_more_info3   =>
                                        lt_cust_site_data (xc_site_idx).customer_id,
                                    p_more_info4   =>
                                        lt_cust_site_data (xc_site_idx).address_id);
                            WHEN OTHERS
                            THEN
                                lc_cust_site_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Site derivation failed '
                                    || SQLERRM);
                                lc_error_message          :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Site derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Site derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_sites',
                                    p_more_info2   => 'DERIVE_SITE',
                                    p_more_info3   =>
                                        lt_cust_site_data (xc_site_idx).customer_id,
                                    p_more_info4   =>
                                        lt_cust_site_data (xc_site_idx).address_id);
                        END;
                    END IF;

                    IF lc_cust_site_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cust_sites_upd_stg_t
                           SET record_status = gc_validate_status, error_message = NULL, target_org = ln_target_org_id
                         WHERE     customer_id =
                                   lt_cust_site_data (xc_site_idx).customer_id
                               AND address_id =
                                   lt_cust_site_data (xc_site_idx).address_id;
                    ELSE
                        UPDATE xxd_ar_cust_sites_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
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

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ROLLBACK;
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_cust_sites;

    /*****************************************************************************************
     *  Procedure Name :   VALIDATE_CUST_SITES_USE                                           *
     *                                                                                       *
     *  Description    :   This Procedure will validate the customer site use table          *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE validate_cust_sites_use (
        p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_cust_site_use IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_siteuse_upd_stg_t xcsu
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_cust_site_use_typ IS TABLE OF cur_cust_site_use%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_site_use_data      lt_cust_site_use_typ;

        lc_site_use_valid_data     VARCHAR2 (1) := gc_yes_flag;
        lx_site_use_valid_data     VARCHAR2 (1) := gc_yes_flag;
        ln_count                   NUMBER := 0;
        ln_target_org_id           NUMBER := 0;
        ln_target_org              VARCHAR2 (250);
        ln_cust_acct_site_use_id   NUMBER;
        lc_error_message           VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'validate_cust_sites_use');

        OPEN cur_cust_site_use;

        LOOP
            FETCH cur_cust_site_use
                BULK COLLECT INTO lt_cust_site_use_data
                LIMIT 1000;

            IF lt_cust_site_use_data.COUNT > 0
            THEN
                FOR xc_site_use_idx IN lt_cust_site_use_data.FIRST ..
                                       lt_cust_site_use_data.LAST
                LOOP
                    log_records (gc_debug_flag,
                                 '************************************');
                    log_records (
                        gc_debug_flag,
                           'customer_id : '
                        || lt_cust_site_use_data (xc_site_use_idx).customer_id);
                    log_records (
                        gc_debug_flag,
                           'cust_acct_site_id : '
                        || lt_cust_site_use_data (xc_site_use_idx).cust_acct_site_id);
                    log_records (
                        gc_debug_flag,
                           'site_use_id : '
                        || lt_cust_site_use_data (xc_site_use_idx).site_use_id);
                    log_records (
                        gc_debug_flag,
                           'target_org : '
                        || lt_cust_site_use_data (xc_site_use_idx).target_org);

                    --log_records (p_debug,'Start validation for Site Address' || lt_cust_site_use_data (xc_site_use_idx).ADDRESS1);
                    lc_site_use_valid_data   := gc_yes_flag;
                    lc_error_message         := NULL;

                    ln_target_org_id         :=
                        get_org_id (
                            p_1206_org_id   =>
                                lt_cust_site_use_data (xc_site_use_idx).source_org_id);

                    IF ln_target_org_id IS NULL
                    THEN
                        lc_site_use_valid_data   := gc_no_flag;
                        lc_error_message         :=
                            SUBSTR (
                                   lc_error_message
                                || 'Target Org ID derivation failed; ',
                                1,
                                4000);
                        xxd_common_utils.record_error (
                            p_module       => 'AR',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers AR Customer Update Program',
                            p_error_msg    =>
                                   'Exception Raised in TARGET_ORG Validation  Mapping not defined for the Organization =>'
                                || lt_cust_site_use_data (xc_site_use_idx).source_org_id,
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   => gn_conc_request_id,
                            p_more_info1   => 'validate_cust_sites_use',
                            p_more_info2   => 'TARGET_ORG',
                            p_more_info3   =>
                                lt_cust_site_use_data (xc_site_use_idx).customer_id,
                            p_more_info4   =>
                                lt_cust_site_use_data (xc_site_use_idx).site_use_id);
                    ELSE
                        BEGIN
                            ln_cust_acct_site_use_id   := NULL;

                            SELECT hcsu.site_use_id
                              INTO ln_cust_acct_site_use_id
                              FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas, hz_cust_accounts hca
                             WHERE     hcas.cust_account_id =
                                       hca.cust_account_id
                                   AND hcas.cust_acct_site_id =
                                       hcsu.cust_acct_site_id
                                   AND hca.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_site_use_data (
                                               xc_site_use_idx).customer_id)
                                   AND hcas.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_site_use_data (
                                               xc_site_use_idx).cust_acct_site_id)
                                   AND hcsu.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_site_use_data (
                                               xc_site_use_idx).site_use_id)
                                   AND hcas.org_id = ln_target_org_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_site_use_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Site Use derivation failed '
                                    || SQLERRM);
                                lc_error_message         :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Site Use derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Site Use derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        'validate_cust_sites_use',
                                    p_more_info2   => 'DERIVE_SITE_USE',
                                    p_more_info3   =>
                                        lt_cust_site_use_data (
                                            xc_site_use_idx).customer_id,
                                    p_more_info4   =>
                                        lt_cust_site_use_data (
                                            xc_site_use_idx).site_use_id);
                            WHEN OTHERS
                            THEN
                                lc_site_use_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Site Use derivation failed '
                                    || SQLERRM);
                                lc_error_message         :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Site Use derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Site Use derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   =>
                                        'validate_cust_sites_use',
                                    p_more_info2   => 'DERIVE_SITE_USE',
                                    p_more_info3   =>
                                        lt_cust_site_use_data (
                                            xc_site_use_idx).customer_id,
                                    p_more_info4   =>
                                        lt_cust_site_use_data (
                                            xc_site_use_idx).site_use_id);
                        END;
                    END IF;

                    IF lc_site_use_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cust_siteuse_upd_stg_t
                           SET record_status = gc_validate_status, target_org = ln_target_org_id, error_message = NULL
                         WHERE     customer_id =
                                   lt_cust_site_use_data (xc_site_use_idx).customer_id
                               AND cust_acct_site_id =
                                   lt_cust_site_use_data (xc_site_use_idx).cust_acct_site_id
                               AND site_use_id =
                                   lt_cust_site_use_data (xc_site_use_idx).site_use_id;
                    ELSE
                        UPDATE xxd_ar_cust_siteuse_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     customer_id =
                                   lt_cust_site_use_data (xc_site_use_idx).customer_id
                               AND cust_acct_site_id =
                                   lt_cust_site_use_data (xc_site_use_idx).cust_acct_site_id
                               AND site_use_id =
                                   lt_cust_site_use_data (xc_site_use_idx).site_use_id;
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
     *  Procedure Name :   VALIDATE_CUST_PROFILE                                             *
     *                                                                                       *
     *  Description    :   This Procedure will validate the customer profile table           *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE validate_cust_profile (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_cust_profile IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_prof_upd_stg_t xcp
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_cust_profile_typ IS TABLE OF cur_cust_profile%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_profile_data          lt_cust_profile_typ;

        CURSOR cur_cust_profile_amt IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_profamt_upd_stg_t xcp
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_cust_profile_amt_typ IS TABLE OF cur_cust_profile_amt%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_profile_amt_data      lt_cust_profile_amt_typ;

        lc_cust_profile_valid_data    VARCHAR2 (1) := gc_yes_flag;
        lc_cust_prof_amt_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                      NUMBER := 0;
        ln_cust_account_profile_id    NUMBER;
        ln_cust_acct_profile_amt_id   NUMBER;
        lc_error_message              VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'validate_cust_profile');

        OPEN cur_cust_profile;

        LOOP
            FETCH cur_cust_profile
                BULK COLLECT INTO lt_cust_profile_data
                LIMIT 1000;

            IF lt_cust_profile_data.COUNT > 0
            THEN
                FOR xc_cust_profile_idx IN lt_cust_profile_data.FIRST ..
                                           lt_cust_profile_data.LAST
                LOOP
                    log_records (gc_debug_flag,
                                 '************************************');
                    log_records (
                        gc_debug_flag,
                           'customer_id : '
                        || lt_cust_profile_data (xc_cust_profile_idx).orig_system_customer_ref);
                    log_records (
                        gc_debug_flag,
                           'address_id : '
                        || lt_cust_profile_data (xc_cust_profile_idx).orig_system_address_ref);
                    log_records (
                        gc_debug_flag,
                           'site_use_id : '
                        || lt_cust_profile_data (xc_cust_profile_idx).site_use_id);

                    lc_cust_profile_valid_data   := gc_yes_flag;
                    lc_error_message             := NULL;

                    IF lt_cust_profile_data (xc_cust_profile_idx).site_use_id
                           IS NULL
                    THEN
                        BEGIN
                            ln_cust_account_profile_id   := NULL;

                            SELECT hcp.cust_account_profile_id
                              INTO ln_cust_account_profile_id
                              FROM hz_cust_accounts hca, hz_customer_profiles hcp
                             WHERE     hca.cust_account_id =
                                       hcp.cust_account_id
                                   AND hcp.site_use_id IS NULL
                                   AND hca.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_profile_data (
                                               xc_cust_profile_idx).orig_system_customer_ref);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_profile_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Profile derivation failed '
                                    || SQLERRM);
                                lc_error_message             :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Profile derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Profile derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_profile',
                                    p_more_info2   => 'DERIVE_CUST_PROFILE',
                                    p_more_info3   =>
                                        lt_cust_profile_data (
                                            xc_cust_profile_idx).orig_system_customer_ref,
                                    p_more_info4   =>
                                        lt_cust_profile_data (
                                            xc_cust_profile_idx).customer_profile_id);
                            WHEN OTHERS
                            THEN
                                lc_cust_profile_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Profile derivation failed '
                                    || SQLERRM);
                                lc_error_message             :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Profile derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Profile derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_profile',
                                    p_more_info2   => 'DERIVE_CUST_PROFILE',
                                    p_more_info3   =>
                                        lt_cust_profile_data (
                                            xc_cust_profile_idx).orig_system_customer_ref,
                                    p_more_info4   =>
                                        lt_cust_profile_data (
                                            xc_cust_profile_idx).customer_profile_id);
                        END;
                    ELSE
                        BEGIN
                            ln_cust_account_profile_id   := NULL;

                            SELECT hcp.cust_account_profile_id
                              INTO ln_cust_account_profile_id
                              FROM hz_customer_profiles hcp, hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas,
                                   hz_cust_accounts hca
                             WHERE     hcas.cust_account_id =
                                       hca.cust_account_id
                                   AND hcas.cust_acct_site_id =
                                       hcsu.cust_acct_site_id
                                   AND hca.cust_account_id =
                                       hcp.cust_account_id
                                   AND hcp.site_use_id = hcsu.site_use_id
                                   AND hca.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_profile_data (
                                               xc_cust_profile_idx).orig_system_customer_ref)
                                   AND hcas.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_profile_data (
                                               xc_cust_profile_idx).orig_system_address_ref)
                                   AND hcsu.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_profile_data (
                                               xc_cust_profile_idx).site_use_id);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_profile_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Profile derivation failed '
                                    || SQLERRM);
                                lc_error_message             :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Profile derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Profile derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_profile',
                                    p_more_info2   => 'DERIVE_CUST_PROFILE',
                                    p_more_info3   =>
                                        lt_cust_profile_data (
                                            xc_cust_profile_idx).orig_system_customer_ref,
                                    p_more_info4   =>
                                        lt_cust_profile_data (
                                            xc_cust_profile_idx).customer_profile_id);
                            WHEN OTHERS
                            THEN
                                lc_cust_profile_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Profile derivation failed '
                                    || SQLERRM);
                                lc_error_message             :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Profile derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Profile derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_profile',
                                    p_more_info2   => 'DERIVE_CUST_PROFILE',
                                    p_more_info3   =>
                                        lt_cust_profile_data (
                                            xc_cust_profile_idx).orig_system_customer_ref,
                                    p_more_info4   =>
                                        lt_cust_profile_data (
                                            xc_cust_profile_idx).customer_profile_id);
                        END;
                    END IF;

                    IF lc_cust_profile_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cust_prof_upd_stg_t
                           SET record_status = gc_validate_status, error_message = NULL
                         WHERE     orig_system_customer_ref =
                                   lt_cust_profile_data (xc_cust_profile_idx).orig_system_customer_ref
                               AND customer_profile_id =
                                   lt_cust_profile_data (xc_cust_profile_idx).customer_profile_id;
                    ELSE
                        UPDATE xxd_ar_cust_prof_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     orig_system_customer_ref =
                                   lt_cust_profile_data (xc_cust_profile_idx).orig_system_customer_ref
                               AND customer_profile_id =
                                   lt_cust_profile_data (xc_cust_profile_idx).customer_profile_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_cust_profile%NOTFOUND;
        END LOOP;

        CLOSE cur_cust_profile;

        COMMIT;

        log_records (p_debug, 'validate_cust_profile_amt');

        OPEN cur_cust_profile_amt;

        LOOP
            FETCH cur_cust_profile_amt
                BULK COLLECT INTO lt_cust_profile_amt_data
                LIMIT 1000;

            IF lt_cust_profile_amt_data.COUNT > 0
            THEN
                FOR xc_cust_profile_idx IN lt_cust_profile_amt_data.FIRST ..
                                           lt_cust_profile_amt_data.LAST
                LOOP
                    log_records (gc_debug_flag,
                                 '************************************');
                    log_records (
                        gc_debug_flag,
                           'customer_id : '
                        || lt_cust_profile_amt_data (xc_cust_profile_idx).customer_id);
                    log_records (
                        gc_debug_flag,
                           'site_use_id : '
                        || lt_cust_profile_amt_data (xc_cust_profile_idx).site_use_id);
                    log_records (
                        gc_debug_flag,
                           'currency_code : '
                        || lt_cust_profile_amt_data (xc_cust_profile_idx).currency_code);

                    lc_cust_prof_amt_valid_data   := gc_yes_flag;
                    lc_error_message              := NULL;

                    IF lt_cust_profile_amt_data (xc_cust_profile_idx).site_use_id
                           IS NULL
                    THEN
                        BEGIN
                            ln_cust_acct_profile_amt_id   := NULL;

                            SELECT hcpa.cust_acct_profile_amt_id
                              INTO ln_cust_acct_profile_amt_id
                              FROM hz_cust_accounts hca, hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                             WHERE     hca.cust_account_id =
                                       hcp.cust_account_id
                                   AND hcp.cust_account_profile_id =
                                       hcpa.cust_account_profile_id
                                   AND hcp.site_use_id IS NULL
                                   AND hca.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_profile_amt_data (
                                               xc_cust_profile_idx).customer_id)
                                   AND currency_code =
                                       lt_cust_profile_amt_data (
                                           xc_cust_profile_idx).currency_code;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_prof_amt_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Profile Amount derivation failed '
                                    || SQLERRM);
                                lc_error_message              :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Profile Amount derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Profile Amount derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_profile',
                                    p_more_info2   =>
                                        'DERIVE_CUST_PROFILE_AMT',
                                    p_more_info3   =>
                                        lt_cust_profile_amt_data (
                                            xc_cust_profile_idx).customer_id,
                                    p_more_info4   =>
                                        lt_cust_profile_amt_data (
                                            xc_cust_profile_idx).cust_account_profile_id);
                            WHEN OTHERS
                            THEN
                                lc_cust_prof_amt_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Profile Amount derivation failed '
                                    || SQLERRM);
                                lc_error_message              :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Profile Amount derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Profile Amount derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_profile',
                                    p_more_info2   =>
                                        'DERIVE_CUST_PROFILE_AMT',
                                    p_more_info3   =>
                                        lt_cust_profile_amt_data (
                                            xc_cust_profile_idx).customer_id,
                                    p_more_info4   =>
                                        lt_cust_profile_amt_data (
                                            xc_cust_profile_idx).cust_account_profile_id);
                        END;
                    ELSE
                        BEGIN
                            ln_cust_acct_profile_amt_id   := NULL;

                            SELECT hcpa.cust_acct_profile_amt_id
                              INTO ln_cust_acct_profile_amt_id
                              FROM hz_cust_profile_amts hcpa, hz_customer_profiles hcp, hz_cust_site_uses_all hcsu,
                                   hz_cust_acct_sites_all hcas, hz_cust_accounts hca
                             WHERE     hcas.cust_account_id =
                                       hca.cust_account_id
                                   AND hcas.cust_acct_site_id =
                                       hcsu.cust_acct_site_id
                                   AND hca.cust_account_id =
                                       hcp.cust_account_id
                                   AND hcp.site_use_id = hcsu.site_use_id
                                   AND hcp.cust_account_profile_id =
                                       hcpa.cust_account_profile_id
                                   AND hca.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_profile_amt_data (
                                               xc_cust_profile_idx).customer_id)
                                   AND hcsu.orig_system_reference =
                                       TO_CHAR (
                                           lt_cust_profile_amt_data (
                                               xc_cust_profile_idx).site_use_id)
                                   AND currency_code =
                                       lt_cust_profile_amt_data (
                                           xc_cust_profile_idx).currency_code;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_cust_prof_amt_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Profile Amount derivation failed '
                                    || SQLERRM);
                                lc_error_message              :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Profile Amount derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Profile Amount derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_profile',
                                    p_more_info2   =>
                                        'DERIVE_CUST_PROFILE_AMT',
                                    p_more_info3   =>
                                        lt_cust_profile_amt_data (
                                            xc_cust_profile_idx).customer_id,
                                    p_more_info4   =>
                                        lt_cust_profile_amt_data (
                                            xc_cust_profile_idx).cust_account_profile_id);
                            WHEN OTHERS
                            THEN
                                lc_cust_prof_amt_valid_data   := gc_no_flag;
                                log_records (
                                    gc_debug_flag,
                                       'Customer Profile Amount derivation failed '
                                    || SQLERRM);
                                lc_error_message              :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Customer Profile Amount derivation failed; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
                                    p_error_msg    =>
                                           'Customer Profile Amount derivation failed : '
                                        || SQLERRM,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'validate_cust_profile',
                                    p_more_info2   =>
                                        'DERIVE_CUST_PROFILE_AMT',
                                    p_more_info3   =>
                                        lt_cust_profile_amt_data (
                                            xc_cust_profile_idx).customer_id,
                                    p_more_info4   =>
                                        lt_cust_profile_amt_data (
                                            xc_cust_profile_idx).cust_account_profile_id);
                        END;
                    END IF;

                    IF lc_cust_prof_amt_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cust_profamt_upd_stg_t
                           SET record_status = gc_validate_status, error_message = NULL
                         WHERE     customer_id =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).customer_id
                               AND cust_account_profile_id =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).cust_account_profile_id
                               AND currency_code =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).currency_code;
                    ELSE
                        UPDATE xxd_ar_cust_profamt_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     customer_id =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).customer_id
                               AND cust_account_profile_id =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).cust_account_profile_id
                               AND currency_code =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).currency_code;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_cust_profile_amt%NOTFOUND;
        END LOOP;

        CLOSE cur_cust_profile_amt;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ROLLBACK;
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_cust_profile;

    /*****************************************************************************************
     *  Procedure Name :   VALIDATE_CUST_CONTACTS                                            *
     *                                                                                       *
     *  Description    :   This Procedure will validate the customer contact table           *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE validate_cust_contacts (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_contacts IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_contact_upd_stg_t xcp
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_contacts_typ IS TABLE OF cur_contacts%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_contacts_data         lt_contacts_typ;

        lc_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lx_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                 NUMBER := 0;
        ln_org_contact_id        NUMBER;
        lc_error_message         VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'validate_cust_contacts');

        OPEN cur_contacts;

        LOOP
            FETCH cur_contacts BULK COLLECT INTO lt_contacts_data LIMIT 1000;

            IF lt_contacts_data.COUNT > 0
            THEN
                FOR xc_contacts_idx IN lt_contacts_data.FIRST ..
                                       lt_contacts_data.LAST
                LOOP
                    log_records (gc_debug_flag,
                                 '************************************');
                    log_records (
                        gc_debug_flag,
                           'customer_id : '
                        || lt_contacts_data (xc_contacts_idx).orig_system_customer_ref);
                    log_records (
                        gc_debug_flag,
                           'contact_id : '
                        || lt_contacts_data (xc_contacts_idx).orig_system_contact_ref);

                    lc_contacts_valid_data   := gc_yes_flag;
                    lc_error_message         := NULL;

                    BEGIN
                        ln_org_contact_id   := NULL;

                        SELECT org_contact_id
                          INTO ln_org_contact_id
                          FROM (SELECT hoc.org_contact_id
                                  FROM hz_parties hp, hz_relationships hr, hz_parties h_contact,
                                       hz_parties hp1, hz_cust_accounts cust, hz_org_contacts hoc,
                                       hz_cust_account_roles hcar
                                 WHERE     hr.subject_id = h_contact.party_id
                                       AND hr.object_id = hp.party_id
                                       AND cust.party_id = hp.party_id
                                       AND hoc.party_relationship_id =
                                           hr.relationship_id
                                       AND hp1.party_id = hr.party_id
                                       AND hr.subject_type = 'PERSON'
                                       AND hcar.party_id = hr.party_id
                                       AND hcar.cust_account_id =
                                           cust.cust_account_id
                                       AND hcar.role_type = 'CONTACT'
                                       AND cust.orig_system_reference =
                                           TO_CHAR (
                                               lt_contacts_data (
                                                   xc_contacts_idx).orig_system_customer_ref)
                                       AND hoc.orig_system_reference =
                                           TO_CHAR (
                                               lt_contacts_data (
                                                   xc_contacts_idx).orig_system_contact_ref)
                                UNION
                                SELECT hoc.org_contact_id
                                  FROM hz_parties hp, hz_relationships hr, hz_parties h_contact,
                                       hz_parties hp1, hz_cust_accounts cust, hz_cust_acct_sites_all hcas,
                                       hz_org_contacts hoc, hz_cust_account_roles hcar
                                 WHERE     hr.subject_id = h_contact.party_id
                                       AND hr.object_id = hp.party_id
                                       AND cust.party_id = hp.party_id
                                       AND hoc.party_relationship_id =
                                           hr.relationship_id
                                       AND hp1.party_id = hr.party_id
                                       AND hr.subject_type = 'PERSON'
                                       AND cust.cust_account_id =
                                           hcas.cust_account_id
                                       AND hcar.party_id = hr.party_id
                                       AND hcar.cust_account_id =
                                           cust.cust_account_id
                                       AND hcar.cust_acct_site_id =
                                           hcas.cust_acct_site_id
                                       AND hcar.role_type = 'CONTACT'
                                       AND cust.orig_system_reference =
                                           TO_CHAR (
                                               lt_contacts_data (
                                                   xc_contacts_idx).orig_system_customer_ref)
                                       AND hcas.orig_system_reference =
                                           TO_CHAR (
                                               lt_contacts_data (
                                                   xc_contacts_idx).orig_system_address_ref)
                                       AND hoc.orig_system_reference =
                                           TO_CHAR (
                                               lt_contacts_data (
                                                   xc_contacts_idx).orig_system_contact_ref))
                         WHERE ROWNUM = 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_contacts_valid_data   := gc_no_flag;
                            log_records (
                                gc_debug_flag,
                                   'Customer Contact derivation failed '
                                || SQLERRM);
                            lc_error_message         :=
                                SUBSTR (
                                       lc_error_message
                                    || 'Customer Contact derivation failed; ',
                                    1,
                                    4000);
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Update Program',
                                p_error_msg    =>
                                       'Customer Contact derivation failed : '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_cust_contacts',
                                p_more_info2   => 'DERIVE_CUST_CONTACTS',
                                p_more_info3   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_customer_ref,
                                p_more_info4   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_contact_ref);
                        WHEN OTHERS
                        THEN
                            lc_contacts_valid_data   := gc_no_flag;
                            log_records (
                                gc_debug_flag,
                                   'Customer Contact derivation failed '
                                || SQLERRM);
                            lc_error_message         :=
                                SUBSTR (
                                       lc_error_message
                                    || 'Customer Contact derivation failed; ',
                                    1,
                                    4000);
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Update Program',
                                p_error_msg    =>
                                       'Customer Contact derivation failed : '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_cust_contacts',
                                p_more_info2   => 'DERIVE_CUST_CONTACTS',
                                p_more_info3   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_customer_ref,
                                p_more_info4   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_contact_ref);
                    END;

                    IF lc_contacts_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_contact_upd_stg_t
                           SET record_status = gc_validate_status, error_message = NULL
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref
                               AND orig_system_contact_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_contact_ref;
                    ELSE
                        UPDATE xxd_ar_contact_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref
                               AND orig_system_contact_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_contact_ref;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_contacts%NOTFOUND;
        END LOOP;

        CLOSE cur_contacts;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ROLLBACK;
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_cust_contacts;

    /*****************************************************************************************
     *  Procedure Name :   VALIDATE_CONTACT_POINTS                                           *
     *                                                                                       *
     *  Description    :   This Procedure will validate the customer contact point table     *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE validate_contact_points (
        p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR cur_contacts IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cont_point_upd_stg_t xcp
             WHERE record_status IN (gc_new_status, gc_error_status);

        TYPE lt_contacts_typ IS TABLE OF cur_contacts%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_contacts_data         lt_contacts_typ;

        lc_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        lx_contacts_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                 NUMBER := 0;
        ln_contact_point_id      NUMBER;
        lc_error_message         VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'validate_contact_points');

        OPEN cur_contacts;

        LOOP
            FETCH cur_contacts BULK COLLECT INTO lt_contacts_data LIMIT 1000;

            IF lt_contacts_data.COUNT > 0
            THEN
                FOR xc_contacts_idx IN lt_contacts_data.FIRST ..
                                       lt_contacts_data.LAST
                LOOP
                    log_records (gc_debug_flag,
                                 '************************************');
                    log_records (
                        gc_debug_flag,
                           'customer_id : '
                        || lt_contacts_data (xc_contacts_idx).orig_system_customer_ref);
                    log_records (
                        gc_debug_flag,
                           'contact_id : '
                        || lt_contacts_data (xc_contacts_idx).orig_system_contact_ref);
                    log_records (
                        gc_debug_flag,
                           'address_id : '
                        || lt_contacts_data (xc_contacts_idx).orig_system_address_ref);
                    log_records (
                        gc_debug_flag,
                           'phone_id : '
                        || lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref);

                    lc_contacts_valid_data   := gc_yes_flag;
                    lc_error_message         := NULL;

                    IF lt_contacts_data (xc_contacts_idx).orig_system_contact_ref
                           IS NOT NULL
                    THEN
                        IF (lt_contacts_data (xc_contacts_idx).contact_first_name IS NULL AND lt_contacts_data (xc_contacts_idx).contact_last_name IS NULL)
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Update Program',
                                p_error_msg    =>
                                    'Exception Raised in CONTACT_FIRST_NAME and CONTACT_LAST_NAME are null  validation',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'CONTACT_FIRST_NAME',
                                p_more_info2   => 'CONTACT_LAST_NAME',
                                p_more_info3   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_customer_ref,
                                p_more_info4   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref);
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
                                lc_error_message         :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Telephone type is invalid; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
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
                                    p_more_info3   =>
                                        lt_contacts_data (xc_contacts_idx).orig_system_customer_ref,
                                    p_more_info4   =>
                                        lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref);
                            WHEN OTHERS
                            THEN
                                lc_contacts_valid_data   := gc_no_flag;
                                lc_error_message         :=
                                    SUBSTR (
                                           lc_error_message
                                        || 'Telephone type is invalid; ',
                                        1,
                                        4000);
                                xxd_common_utils.record_error (
                                    p_module       => 'AR',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'Deckers AR Customer Update Program',
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
                                    p_more_info3   =>
                                        lt_contacts_data (xc_contacts_idx).orig_system_customer_ref,
                                    p_more_info4   =>
                                        lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref);
                        END;
                    END IF;

                    BEGIN
                        ln_contact_point_id   := NULL;

                        IF     lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref
                                   IS NOT NULL
                           AND lt_contacts_data (xc_contacts_idx).orig_system_customer_ref
                                   IS NOT NULL
                        THEN
                            SELECT contact_point_id
                              INTO ln_contact_point_id
                              FROM (SELECT hcp.contact_point_id
                                      FROM hz_parties hp, hz_relationships hr, hz_contact_points hcp,
                                           hz_parties h_contact, hz_cust_accounts cust, hz_org_contacts hoc
                                     WHERE     hr.subject_id =
                                               h_contact.party_id
                                           AND hr.object_id = hp.party_id
                                           AND cust.party_id = hp.party_id
                                           AND hoc.party_relationship_id =
                                               hr.relationship_id
                                           AND hr.subject_type = 'PERSON'
                                           AND hcp.owner_table_id =
                                               hr.party_id
                                           AND hcp.owner_table_name =
                                               'HZ_PARTIES'
                                           AND cust.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_customer_ref)
                                           AND hoc.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_contact_ref)
                                           AND hcp.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_telephone_ref)
                                    UNION
                                    SELECT hcp.contact_point_id
                                      FROM hz_parties hp, hz_contact_points hcp, hz_cust_accounts cust
                                     WHERE     cust.party_id = hp.party_id
                                           AND hcp.owner_table_id =
                                               hp.party_id
                                           AND hcp.owner_table_name =
                                               'HZ_PARTIES'
                                           AND cust.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_customer_ref)
                                           AND hcp.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_telephone_ref)
                                    UNION
                                    SELECT hcp.contact_point_id
                                      FROM hz_parties hp, hz_contact_points hcp, hz_cust_accounts cust,
                                           hz_cust_acct_sites_all hcas, hz_party_sites hps
                                     WHERE     cust.party_id = hp.party_id
                                           AND hp.party_id = hps.party_id
                                           AND hcas.party_site_id =
                                               hps.party_site_id
                                           AND cust.cust_account_id =
                                               hcas.cust_account_id
                                           AND hcp.owner_table_name =
                                               'HZ_PARTY_SITES'
                                           AND hcp.owner_table_id =
                                               hps.party_site_id
                                           AND cust.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_customer_ref)
                                           AND hcas.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_address_ref)
                                           AND hcp.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_telephone_ref)
                                    UNION
                                    SELECT hcp.contact_point_id
                                      FROM hz_parties hp, hz_contact_points hcp, hz_cust_accounts cust,
                                           hz_cust_acct_sites_all hcas, hz_party_sites hps
                                     WHERE     cust.party_id = hp.party_id
                                           AND hp.party_id = hps.party_id
                                           AND hcas.party_site_id =
                                               hps.party_site_id
                                           AND cust.cust_account_id =
                                               hcas.cust_account_id
                                           AND hcp.owner_table_name =
                                               'HZ_PARTY_SITES'
                                           AND hcp.owner_table_id =
                                               hps.party_site_id
                                           AND cust.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_customer_ref)
                                           AND hcp.orig_system_reference =
                                               TO_CHAR (
                                                   lt_contacts_data (
                                                       xc_contacts_idx).orig_system_telephone_ref))
                             WHERE ROWNUM = 1;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_contacts_valid_data   := gc_no_flag;
                            log_records (
                                gc_debug_flag,
                                   'Customer Contact Point derivation failed '
                                || SQLERRM);
                            lc_error_message         :=
                                SUBSTR (
                                       lc_error_message
                                    || 'Customer Contact Point derivation failed; ',
                                    1,
                                    4000);
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Update Program',
                                p_error_msg    =>
                                       'Customer Contact Point derivation failed : '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_contact_points',
                                p_more_info2   => 'DERIVE_CUST_CONTACT_POINTS',
                                p_more_info3   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_customer_ref,
                                p_more_info4   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_contact_ref);
                        WHEN OTHERS
                        THEN
                            lc_contacts_valid_data   := gc_no_flag;
                            log_records (
                                gc_debug_flag,
                                   'Customer Contact Point derivation failed '
                                || SQLERRM);
                            lc_error_message         :=
                                SUBSTR (
                                       lc_error_message
                                    || 'Customer Contact Point derivation failed; ',
                                    1,
                                    4000);
                            xxd_common_utils.record_error (
                                p_module       => 'AR',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers AR Customer Update Program',
                                p_error_msg    =>
                                       'Customer Contact Point derivation failed : '
                                    || SQLERRM,
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'validate_contact_points',
                                p_more_info2   => 'DERIVE_CUST_CONTACT_POINTS',
                                p_more_info3   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_customer_ref,
                                p_more_info4   =>
                                    lt_contacts_data (xc_contacts_idx).orig_system_contact_ref);
                    END;

                    IF lc_contacts_valid_data = gc_yes_flag
                    THEN
                        UPDATE xxd_ar_cont_point_upd_stg_t
                           SET record_status = gc_validate_status, error_message = NULL
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref
                               AND orig_system_telephone_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref;
                    ELSE
                        UPDATE xxd_ar_cont_point_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref
                               AND orig_system_telephone_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
            EXIT WHEN cur_contacts%NOTFOUND;
        END LOOP;

        CLOSE cur_contacts;

        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ROLLBACK;
        WHEN OTHERS
        THEN
            ROLLBACK;
    END validate_contact_points;


    /*****************************************************************************************
     *  Procedure Name :   UPDATE_CUSTOMER                                                   *
     *                                                                                       *
     *  Description    :   This Procedure will update the customer data                      *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE update_customer (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        CURSOR cur_customer IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_customer_upd_stg_t
             WHERE record_status = gc_validate_status;

        CURSOR lcu_cust_class_code (p_cust_class_code VARCHAR2)
        IS
            SELECT lookup_code
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'CUSTOMER CLASS'
                   AND UPPER (lookup_code) = UPPER (p_cust_class_code)
                   AND enabled_flag = 'Y'
                   AND language = 'US';

        -- Cursor to fetch Order type id from R12
        CURSOR lcur_order_type_id (p_order_type_name VARCHAR2)
        IS
            SELECT ottt12.transaction_type_id order_type_id
              FROM oe_transaction_types_tl ottt12, xxd_1206_order_type_map_t xtt
             WHERE     ottt12.name = xtt.new_12_2_3_name
                   AND legacy_12_0_6_name = p_order_type_name
                   AND language = 'US';

        CURSOR cur_brand_customer (p_customer_id VARCHAR2)
        IS
            SELECT hca.orig_system_reference, hca.cust_account_id, hca.object_version_number
              FROM hz_cust_accounts_all hca, hz_cust_acct_relate_all hcar, hz_cust_accounts_all hca1
             WHERE     hca.cust_account_id = hcar.cust_account_id
                   AND hca1.cust_account_id = hcar.related_cust_account_id
                   AND TO_CHAR (p_customer_id) = hca1.orig_system_reference;

        TYPE lt_customer_typ IS TABLE OF cur_customer%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_customer_data      lt_customer_typ;
        lr_party_rec          hz_party_v2pub.party_rec_type;
        lr_cust_account_rec   hz_cust_account_v2pub.cust_account_rec_type;
        lr_organization_rec   hz_party_v2pub.organization_rec_type;
        lr_person_rec         hz_party_v2pub.person_rec_type;
        ln_party_id           NUMBER := 0;
        ln_cust_account_id    NUMBER := 0;
        ln_party_ovn          NUMBER;
        ln_cust_account_ovn   NUMBER;
        ln_profile_id         NUMBER;
        lc_account_name       VARCHAR2 (300);
        lc_return_status      VARCHAR2 (10);
        ln_msg_count          NUMBER;
        ln_msg_index_num      NUMBER;
        lc_msg_data           VARCHAR2 (4000);
        lc_data               VARCHAR2 (4000);
        lc_error_message      VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'update_customer');

        OPEN cur_customer;

        LOOP
            --      SAVEPOINT INSERT_TABLE2;
            FETCH cur_customer BULK COLLECT INTO lt_customer_data LIMIT 50;

            EXIT WHEN lt_customer_data.COUNT = 0;

            FOR xc_customer_idx IN lt_customer_data.FIRST ..
                                   lt_customer_data.LAST
            LOOP
                lc_account_name       := NULL;
                ln_cust_account_id    := NULL;
                ln_party_id           := NULL;
                ln_party_ovn          := NULL;
                ln_cust_account_ovn   := NULL;
                ln_profile_id         := NULL;
                lr_party_rec          := NULL;
                lr_cust_account_rec   := NULL;
                lr_organization_rec   := NULL;
                lr_person_rec         := NULL;

                log_records (gc_debug_flag,
                             '*****************************************');

                log_records (
                    gc_debug_flag,
                       'customer_name : '
                    || lt_customer_data (xc_customer_idx).customer_name);
                log_records (
                    gc_debug_flag,
                       'customer_id : '
                    || lt_customer_data (xc_customer_idx).customer_id);

                BEGIN
                    SELECT hp.party_id, hp.object_version_number, hca.cust_account_id,
                           hca.object_version_number
                      INTO ln_party_id, ln_party_ovn, ln_cust_account_id, ln_cust_account_ovn
                      FROM hz_parties hp, hz_cust_accounts hca
                     WHERE     hp.party_id = hca.party_id
                           AND hp.party_type =
                               lt_customer_data (xc_customer_idx).party_type
                           AND hca.orig_system_reference =
                               TO_CHAR (
                                   lt_customer_data (xc_customer_idx).customer_id)
                           AND hp.orig_system_reference =
                               TO_CHAR (
                                   lt_customer_data (xc_customer_idx).orig_system_party_ref);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_party_id          := 0;
                        ln_cust_account_id   := 0;
                        log_records (
                            gc_debug_flag,
                               lt_customer_data (xc_customer_idx).customer_name
                            || ' Customer not found in DB ');
                        lc_return_status     := 'E';
                    WHEN OTHERS
                    THEN
                        ln_party_id          := 0;
                        ln_cust_account_id   := 0;
                        log_records (
                            gc_debug_flag,
                               lt_customer_data (xc_customer_idx).customer_name
                            || ' Customer not found in DB ');
                        lc_return_status     := 'E';
                END;

                IF ln_party_id > 0
                THEN
                    IF lt_customer_data (xc_customer_idx).party_type =
                       'ORGANIZATION'
                    THEN
                        BEGIN
                            SELECT alias_name
                              INTO lc_account_name
                              FROM xxd_conv.xxd_apac_customer_mapping_t xac
                             WHERE xac.customer_number =
                                   lt_customer_data (xc_customer_idx).customer_number;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_account_name   :=
                                    lt_customer_data (xc_customer_idx).customer_name;
                            WHEN OTHERS
                            THEN
                                lc_account_name   :=
                                    lt_customer_data (xc_customer_idx).customer_name;
                        END;

                        lr_party_rec.party_id   := ln_party_id;
                        lr_party_rec.status     :=
                            lt_customer_data (xc_customer_idx).party_status;
                        lr_party_rec.category_code   :=
                            lt_customer_data (xc_customer_idx).customer_prospect_code;
                        lr_organization_rec.organization_name   :=
                            lt_customer_data (xc_customer_idx).customer_name;
                        lr_organization_rec.duns_number_c   :=
                            lt_customer_data (xc_customer_idx).duns_number_c;
                        lr_organization_rec.party_rec   :=
                            lr_party_rec;

                        ln_msg_count            := 0;
                        lc_msg_data             := NULL;
                        lc_return_status        := NULL;
                        lc_data                 := NULL;
                        lc_error_message        := NULL;

                        fnd_msg_pub.initialize;

                        log_records (gc_debug_flag,
                                     'Call update_organization API');

                        hz_party_v2pub.update_organization (
                            p_init_msg_list                 => gc_init_msg_list,
                            p_organization_rec              => lr_organization_rec,
                            p_party_object_version_number   => ln_party_ovn,
                            x_profile_id                    => ln_profile_id,
                            x_return_status                 =>
                                lc_return_status,
                            x_msg_count                     => ln_msg_count,
                            x_msg_data                      => lc_msg_data);

                        log_records (gc_debug_flag,
                                     'Return Status : ' || lc_return_status);

                        IF lc_return_status <> 'S'
                        THEN
                            IF ln_msg_count > 0
                            THEN
                                log_records (
                                    gc_debug_flag,
                                    'update_organization API failed');

                                FOR i IN 1 .. ln_msg_count
                                LOOP
                                    fnd_msg_pub.get (
                                        p_msg_index       => i,
                                        p_encoded         => 'F',
                                        p_data            => lc_data,
                                        p_msg_index_out   => ln_msg_index_num);
                                    log_records (gc_debug_flag,
                                                 'lc_data: ' || lc_data);

                                    lc_error_message   :=
                                        SUBSTR (
                                               lc_error_message
                                            || i
                                            || '. '
                                            || lc_data
                                            || '; ',
                                            1,
                                            4000);
                                END LOOP;
                            END IF;
                        END IF;
                    ELSIF lt_customer_data (xc_customer_idx).party_type =
                          'PERSON'
                    THEN
                        lr_party_rec.party_id                   := ln_party_id;
                        lr_party_rec.status                     :=
                            lt_customer_data (xc_customer_idx).party_status;
                        lr_party_rec.category_code              :=
                            lt_customer_data (xc_customer_idx).customer_prospect_code;
                        lr_person_rec.person_pre_name_adjunct   :=
                            lt_customer_data (xc_customer_idx).person_pre_name_adjunct;
                        lr_person_rec.person_first_name         :=
                            INITCAP (
                                lt_customer_data (xc_customer_idx).person_first_name);
                        lr_person_rec.person_middle_name        :=
                            INITCAP (
                                lt_customer_data (xc_customer_idx).person_middle_name);
                        lr_person_rec.person_last_name          :=
                            INITCAP (
                                lt_customer_data (xc_customer_idx).person_last_name);
                        lr_person_rec.party_rec                 :=
                            lr_party_rec;

                        ln_msg_count                            := 0;
                        lc_msg_data                             := NULL;
                        lc_return_status                        := NULL;
                        lc_data                                 := NULL;
                        lc_error_message                        := NULL;

                        fnd_msg_pub.initialize;
                        log_records (gc_debug_flag, 'Call update_person API');

                        hz_party_v2pub.update_person (
                            p_init_msg_list                 => gc_init_msg_list,
                            p_person_rec                    => lr_person_rec,
                            p_party_object_version_number   => ln_party_ovn,
                            x_profile_id                    => ln_profile_id,
                            x_return_status                 =>
                                lc_return_status,
                            x_msg_count                     => ln_msg_count,
                            x_msg_data                      => lc_msg_data);

                        log_records (gc_debug_flag,
                                     'Return Status : ' || lc_return_status);

                        IF lc_return_status <> 'S'
                        THEN
                            IF ln_msg_count > 0
                            THEN
                                log_records (gc_debug_flag,
                                             'update_person API failed');

                                FOR i IN 1 .. ln_msg_count
                                LOOP
                                    fnd_msg_pub.get (
                                        p_msg_index       => i,
                                        p_encoded         => 'F',
                                        p_data            => lc_data,
                                        p_msg_index_out   => ln_msg_index_num);
                                    log_records (gc_debug_flag,
                                                 'lc_data: ' || lc_data);

                                    lc_error_message   :=
                                        SUBSTR (
                                               lc_error_message
                                            || i
                                            || '. '
                                            || lc_data
                                            || '; ',
                                            1,
                                            4000);
                                END LOOP;
                            END IF;
                        END IF;
                    END IF;
                END IF;

                IF ln_cust_account_id > 0
                THEN
                    lr_cust_account_rec.cust_account_id   :=
                        ln_cust_account_id;
                    lr_cust_account_rec.account_name   :=
                        NVL (
                            lc_account_name,
                            lt_customer_data (xc_customer_idx).customer_name);
                    lr_cust_account_rec.status   :=
                        lt_customer_data (xc_customer_idx).cust_acct_status;
                    lr_cust_account_rec.customer_type   :=
                        lt_customer_data (xc_customer_idx).customer_type;

                    IF lt_customer_data (xc_customer_idx).party_type =
                       'ORGANIZATION'
                    THEN
                        lr_cust_account_rec.attribute2   :=
                            lt_customer_data (xc_customer_idx).customer_attribute2;
                        lr_cust_account_rec.attribute5   :=
                            NVL (
                                lt_customer_data (xc_customer_idx).customer_attribute5,
                                'N');
                        lr_cust_account_rec.attribute6   :=
                            lt_customer_data (xc_customer_idx).customer_attribute6;
                        lr_cust_account_rec.attribute8   :=
                            lt_customer_data (xc_customer_idx).customer_attribute8;
                        lr_cust_account_rec.attribute9   :=
                            lt_customer_data (xc_customer_idx).customer_attribute9;
                        lr_cust_account_rec.attribute17   :=
                            lt_customer_data (xc_customer_idx).customer_attribute17;
                        lr_cust_account_rec.attribute18   :=
                            lt_customer_data (xc_customer_idx).customer_attribute18;

                        OPEN lcu_cust_class_code (
                            p_cust_class_code   =>
                                lt_customer_data (xc_customer_idx).customer_class_code);

                        FETCH lcu_cust_class_code
                            INTO lr_cust_account_rec.customer_class_code;

                        CLOSE lcu_cust_class_code;

                        OPEN lcur_order_type_id (
                            p_order_type_name   =>
                                lt_customer_data (xc_customer_idx).cust_order_type_name);

                        FETCH lcur_order_type_id
                            INTO lr_cust_account_rec.order_type_id;

                        CLOSE lcur_order_type_id;
                    ELSIF lt_customer_data (xc_customer_idx).party_type =
                          'PERSON'
                    THEN
                        IF     UPPER (
                                   lt_customer_data (xc_customer_idx).customer_attr_category) =
                               'PERSON'
                           AND lt_customer_data (xc_customer_idx).customer_attribute18
                                   IS NOT NULL
                        THEN
                            lr_cust_account_rec.attribute2   :=
                                lt_customer_data (xc_customer_idx).customer_attribute2;
                            lr_cust_account_rec.attribute5   :=
                                lt_customer_data (xc_customer_idx).customer_attribute5;
                            lr_cust_account_rec.attribute6   :=
                                lt_customer_data (xc_customer_idx).customer_attribute6;
                            lr_cust_account_rec.attribute8   :=
                                lt_customer_data (xc_customer_idx).customer_attribute8;
                            lr_cust_account_rec.attribute9   :=
                                lt_customer_data (xc_customer_idx).customer_attribute9;
                            lr_cust_account_rec.attribute17   :=
                                lt_customer_data (xc_customer_idx).customer_attribute17;
                            lr_cust_account_rec.attribute18   :=
                                lt_customer_data (xc_customer_idx).customer_attribute18;
                            lr_cust_account_rec.attribute19   :=
                                lt_customer_data (xc_customer_idx).customer_attribute19;
                            lr_cust_account_rec.attribute20   :=
                                lt_customer_data (xc_customer_idx).customer_attribute20;
                        ELSE
                            lr_cust_account_rec.attribute2   :=
                                lt_customer_data (xc_customer_idx).customer_attribute2;
                            lr_cust_account_rec.attribute5   :=
                                NVL (
                                    lt_customer_data (xc_customer_idx).customer_attribute5,
                                    'N');
                            lr_cust_account_rec.attribute6   :=
                                lt_customer_data (xc_customer_idx).customer_attribute6;
                            lr_cust_account_rec.attribute8   :=
                                lt_customer_data (xc_customer_idx).customer_attribute8;
                            lr_cust_account_rec.attribute9   :=
                                lt_customer_data (xc_customer_idx).customer_attribute9;
                            lr_cust_account_rec.attribute17   :=
                                lt_customer_data (xc_customer_idx).customer_attribute17;
                            lr_cust_account_rec.attribute18   :=
                                lt_customer_data (xc_customer_idx).customer_attribute18;
                        END IF;
                    END IF;

                    ln_msg_count       := 0;
                    lc_msg_data        := NULL;
                    lc_return_status   := NULL;
                    lc_data            := NULL;
                    lc_error_message   := NULL;

                    fnd_msg_pub.initialize;
                    log_records (gc_debug_flag,
                                 'Call update_cust_account API');

                    hz_cust_account_v2pub.update_cust_account (
                        p_init_msg_list           => gc_init_msg_list,
                        p_cust_account_rec        => lr_cust_account_rec,
                        p_object_version_number   => ln_cust_account_ovn,
                        x_return_status           => lc_return_status,
                        x_msg_count               => ln_msg_count,
                        x_msg_data                => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (gc_debug_flag,
                                         'update_cust_account API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_customer_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message, request_id = gn_conc_request_id
                         WHERE customer_id =
                               lt_customer_data (xc_customer_idx).customer_id;
                    ELSE
                        IF lt_customer_data (xc_customer_idx).cust_acct_status =
                           'I'
                        THEN
                            FOR lcu_brand_customer_rec
                                IN cur_brand_customer (
                                       lt_customer_data (xc_customer_idx).customer_id)
                            LOOP
                                log_records (
                                    gc_debug_flag,
                                       'Update Brand Customer : '
                                    || lcu_brand_customer_rec.orig_system_reference);

                                lr_cust_account_rec                   := NULL;

                                lr_cust_account_rec.cust_account_id   :=
                                    lcu_brand_customer_rec.cust_account_id;
                                lr_cust_account_rec.status            :=
                                    lt_customer_data (xc_customer_idx).cust_acct_status;
                                ln_cust_account_ovn                   :=
                                    lcu_brand_customer_rec.object_version_number;

                                ln_msg_count                          := 0;
                                lc_msg_data                           := NULL;
                                lc_return_status                      := NULL;
                                lc_data                               := NULL;
                                lc_error_message                      := NULL;

                                fnd_msg_pub.initialize;
                                log_records (gc_debug_flag,
                                             'Call update_cust_account API');

                                hz_cust_account_v2pub.update_cust_account (
                                    p_init_msg_list   => gc_init_msg_list,
                                    p_cust_account_rec   =>
                                        lr_cust_account_rec,
                                    p_object_version_number   =>
                                        ln_cust_account_ovn,
                                    x_return_status   => lc_return_status,
                                    x_msg_count       => ln_msg_count,
                                    x_msg_data        => lc_msg_data);

                                log_records (
                                    gc_debug_flag,
                                    'Return Status : ' || lc_return_status);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_customer_upd_stg_t
                           SET record_status = gc_process_status, request_id = gn_conc_request_id
                         WHERE customer_id =
                               lt_customer_data (xc_customer_idx).customer_id;
                    END IF;
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;

        CLOSE cur_customer;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Un-expecetd Error in  update_customer => ' || SQLERRM);
            ROLLBACK;
    END update_customer;

    /*****************************************************************************************
     *  Procedure Name :   UPDATE_CUST_SITES                                                 *
     *                                                                                       *
     *  Description    :   This Procedure will update the customer site data                 *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE update_cust_sites (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        CURSOR cur_cust_site IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_sites_upd_stg_t xcs
             WHERE record_status = gc_validate_status;

        CURSOR cur_brand_cust_site (p_customer_id   VARCHAR2,
                                    p_address_id    VARCHAR2)
        IS
            SELECT hcas.orig_system_reference, hcas.cust_acct_site_id, hcas.object_version_number
              FROM hz_cust_accounts_all hca, hz_cust_acct_relate_all hcar, hz_cust_accounts_all hca1,
                   hz_cust_acct_sites_all hcas
             WHERE     hca.cust_account_id = hcar.cust_account_id
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hca1.cust_account_id = hcar.related_cust_account_id
                   AND TO_CHAR (p_customer_id) = hca1.orig_system_reference
                   AND TO_CHAR (p_address_id) || '-' || hca.attribute1 =
                       hcas.orig_system_reference;

        TYPE lt_cust_site_typ IS TABLE OF cur_cust_site%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_site_data       lt_cust_site_typ;
        ln_cust_acct_site_id    NUMBER;
        ln_party_site_id        NUMBER;
        ln_location_id          NUMBER;
        ln_cust_acct_site_ovn   NUMBER;
        ln_party_site_ovn       NUMBER;
        ln_location_ovn         NUMBER;
        lr_location_rec         hz_location_v2pub.location_rec_type;
        lr_party_site_rec       hz_party_site_v2pub.party_site_rec_type;
        lr_cust_acct_site_rec   hz_cust_account_site_v2pub.cust_acct_site_rec_type;
        lc_return_status        VARCHAR2 (10);
        ln_msg_count            NUMBER;
        ln_msg_index_num        NUMBER;
        lc_msg_data             VARCHAR2 (4000);
        lc_data                 VARCHAR2 (4000);
        lc_error_message        VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'update_cust_sites');

        OPEN cur_cust_site;

        LOOP
            FETCH cur_cust_site BULK COLLECT INTO lt_cust_site_data LIMIT 50;

            EXIT WHEN lt_cust_site_data.COUNT = 0;

            FOR xc_site_idx IN lt_cust_site_data.FIRST ..
                               lt_cust_site_data.LAST
            LOOP
                log_records (gc_debug_flag,
                             '************************************');
                log_records (
                    gc_debug_flag,
                       'customer_id : '
                    || lt_cust_site_data (xc_site_idx).customer_id);
                log_records (
                    gc_debug_flag,
                       'address_id : '
                    || lt_cust_site_data (xc_site_idx).address_id);
                log_records (
                    gc_debug_flag,
                       'target_org : '
                    || lt_cust_site_data (xc_site_idx).target_org);

                mo_global.init ('AR');
                mo_global.set_policy_context (
                    'S',
                    lt_cust_site_data (xc_site_idx).target_org);

                ln_cust_acct_site_id    := NULL;
                ln_party_site_id        := NULL;
                ln_location_id          := NULL;
                ln_cust_acct_site_ovn   := NULL;
                ln_party_site_ovn       := NULL;
                ln_location_ovn         := NULL;
                lr_location_rec         := NULL;
                lr_party_site_rec       := NULL;
                lr_cust_acct_site_rec   := NULL;

                BEGIN
                    SELECT hcas.cust_acct_site_id, hps.party_site_id, hl.location_id,
                           hcas.object_version_number, hps.object_version_number, hl.object_version_number
                      INTO ln_cust_acct_site_id, ln_party_site_id, ln_location_id, ln_cust_acct_site_ovn,
                                               ln_party_site_ovn, ln_location_ovn
                      FROM hz_cust_acct_sites_all hcas, hz_party_sites hps, hz_locations hl,
                           hz_parties hp, hz_cust_accounts hca
                     WHERE     hp.party_id = hca.party_id
                           AND hp.party_id = hps.party_id
                           AND hps.location_id = hl.location_id
                           AND hcas.cust_account_id = hca.cust_account_id
                           AND hcas.party_site_id = hps.party_site_id
                           AND hca.orig_system_reference =
                               TO_CHAR (
                                   lt_cust_site_data (xc_site_idx).customer_id)
                           AND hcas.orig_system_reference =
                               TO_CHAR (
                                   lt_cust_site_data (xc_site_idx).address_id)
                           AND hcas.org_id =
                               lt_cust_site_data (xc_site_idx).target_org;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cust_acct_site_id   := 0;
                        ln_party_site_id       := 0;
                        ln_location_id         := 0;
                        log_records (gc_debug_flag,
                                     'Customer Site not found in DB ');
                        lc_return_status       := 'E';
                    WHEN OTHERS
                    THEN
                        ln_cust_acct_site_id   := 0;
                        ln_party_site_id       := 0;
                        ln_location_id         := 0;
                        log_records (gc_debug_flag,
                                     'Customer Site not found in DB ');
                        lc_return_status       := 'E';
                END;

                IF ln_location_id > 0
                THEN
                    lr_location_rec.location_id   := ln_location_id;
                    lr_location_rec.address1      :=
                        lt_cust_site_data (xc_site_idx).address1;
                    lr_location_rec.address2      :=
                        lt_cust_site_data (xc_site_idx).address2;
                    lr_location_rec.address3      :=
                        lt_cust_site_data (xc_site_idx).address3;
                    lr_location_rec.address4      :=
                        lt_cust_site_data (xc_site_idx).address4;
                    lr_location_rec.city          :=
                        lt_cust_site_data (xc_site_idx).city;
                    lr_location_rec.state         :=
                        lt_cust_site_data (xc_site_idx).state;
                    lr_location_rec.country       :=
                        CASE
                            WHEN lt_cust_site_data (xc_site_idx).country =
                                 'AN'
                            THEN
                                'NL'
                            ELSE
                                lt_cust_site_data (xc_site_idx).country
                        END;
                    lr_location_rec.postal_code   :=
                        lt_cust_site_data (xc_site_idx).postal_code;
                    lr_location_rec.county        :=
                        lt_cust_site_data (xc_site_idx).county;
                    lr_location_rec.province      :=
                        lt_cust_site_data (xc_site_idx).province;
                    lr_location_rec.attribute1    :=
                        lt_cust_site_data (xc_site_idx).address_attribute1;
                    lr_location_rec.attribute2    :=
                        lt_cust_site_data (xc_site_idx).address_attribute2;
                    lr_location_rec.attribute3    :=
                        lt_cust_site_data (xc_site_idx).address_attribute3;
                    lr_location_rec.attribute4    :=
                        lt_cust_site_data (xc_site_idx).address_attribute4;
                    lr_location_rec.attribute5    :=
                        lt_cust_site_data (xc_site_idx).address_attribute5;
                    lr_location_rec.attribute6    :=
                        lt_cust_site_data (xc_site_idx).address_attribute6;
                    lr_location_rec.attribute7    :=
                        lt_cust_site_data (xc_site_idx).address_attribute7;
                    lr_location_rec.attribute8    :=
                        lt_cust_site_data (xc_site_idx).address_attribute8;

                    ln_msg_count                  := 0;
                    lc_msg_data                   := NULL;
                    lc_return_status              := NULL;
                    lc_data                       := NULL;
                    lc_error_message              := NULL;

                    fnd_msg_pub.initialize;

                    log_records (gc_debug_flag, 'Call update_location API');

                    hz_location_v2pub.update_location (
                        p_init_msg_list           => gc_init_msg_list,
                        p_location_rec            => lr_location_rec,
                        p_object_version_number   => ln_location_ovn,
                        x_return_status           => lc_return_status,
                        x_msg_count               => ln_msg_count,
                        x_msg_data                => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (gc_debug_flag,
                                         'update_location API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;
                    END IF;
                END IF;

                IF ln_party_site_id > 0
                THEN
                    lr_party_site_rec.party_site_id              := ln_party_site_id;
                    lr_party_site_rec.status                     :=
                        lt_cust_site_data (xc_site_idx).party_site_status;
                    lr_party_site_rec.identifying_address_flag   :=
                        lt_cust_site_data (xc_site_idx).identifying_address_flag;
                    lr_party_site_rec.attribute_category         :=
                        lt_cust_site_data (xc_site_idx).party_site_attr_category;
                    lr_party_site_rec.attribute1                 :=
                        lt_cust_site_data (xc_site_idx).party_site_attribute1;
                    lr_party_site_rec.attribute2                 :=
                        lt_cust_site_data (xc_site_idx).party_site_attribute2;
                    lr_party_site_rec.attribute3                 :=
                        lt_cust_site_data (xc_site_idx).party_site_attribute3;
                    lr_party_site_rec.attribute4                 :=
                        lt_cust_site_data (xc_site_idx).party_site_attribute4;
                    lr_party_site_rec.attribute5                 :=
                        lt_cust_site_data (xc_site_idx).party_site_attribute5;

                    ln_msg_count                                 := 0;
                    lc_msg_data                                  := NULL;
                    lc_return_status                             := NULL;
                    lc_data                                      := NULL;
                    lc_error_message                             := NULL;

                    fnd_msg_pub.initialize;

                    log_records (gc_debug_flag, 'Call update_party_site API');

                    hz_party_site_v2pub.update_party_site (
                        p_init_msg_list           => gc_init_msg_list,
                        p_party_site_rec          => lr_party_site_rec,
                        p_object_version_number   => ln_party_site_ovn,
                        x_return_status           => lc_return_status,
                        x_msg_count               => ln_msg_count,
                        x_msg_data                => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (gc_debug_flag,
                                         'update_party_site API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;
                    END IF;
                END IF;

                IF ln_cust_acct_site_id > 0
                THEN
                    lr_cust_acct_site_rec.cust_acct_site_id   :=
                        ln_cust_acct_site_id;
                    lr_cust_acct_site_rec.status   :=
                        lt_cust_site_data (xc_site_idx).cust_site_status;
                    lr_cust_acct_site_rec.org_id   :=
                        lt_cust_site_data (xc_site_idx).target_org;
                    lr_cust_acct_site_rec.attribute_category   :=
                        lt_cust_site_data (xc_site_idx).cust_site_attr_category;
                    lr_cust_acct_site_rec.attribute1   :=
                        lt_cust_site_data (xc_site_idx).cust_site_attribute1;
                    lr_cust_acct_site_rec.attribute2   :=
                        lt_cust_site_data (xc_site_idx).cust_site_attribute2;
                    lr_cust_acct_site_rec.attribute3   :=
                        lt_cust_site_data (xc_site_idx).cust_site_attribute3;
                    lr_cust_acct_site_rec.attribute4   :=
                        lt_cust_site_data (xc_site_idx).cust_site_attribute4;
                    lr_cust_acct_site_rec.attribute5   :=
                        lt_cust_site_data (xc_site_idx).cust_site_attribute5;
                    lr_cust_acct_site_rec.attribute6   :=
                        lt_cust_site_data (xc_site_idx).cust_site_attribute6;
                    lr_cust_acct_site_rec.attribute7   :=
                        lt_cust_site_data (xc_site_idx).cust_site_attribute7;
                    lr_cust_acct_site_rec.attribute8   :=
                        lt_cust_site_data (xc_site_idx).cust_site_attribute8;

                    ln_msg_count       := 0;
                    lc_msg_data        := NULL;
                    lc_return_status   := NULL;
                    lc_data            := NULL;
                    lc_error_message   := NULL;

                    fnd_msg_pub.initialize;

                    log_records (gc_debug_flag,
                                 'Call update_cust_acct_site API');

                    hz_cust_account_site_v2pub.update_cust_acct_site (
                        p_init_msg_list           => gc_init_msg_list,
                        p_cust_acct_site_rec      => lr_cust_acct_site_rec,
                        p_object_version_number   => ln_cust_acct_site_ovn,
                        x_return_status           => lc_return_status,
                        x_msg_count               => ln_msg_count,
                        x_msg_data                => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (gc_debug_flag,
                                         'update_cust_acct_site API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_cust_sites_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     customer_id =
                                   lt_cust_site_data (xc_site_idx).customer_id
                               AND address_id =
                                   lt_cust_site_data (xc_site_idx).address_id;
                    ELSE
                        IF lt_cust_site_data (xc_site_idx).cust_site_status =
                           'I'
                        THEN
                            FOR lcu_brand_cust_site_rec
                                IN cur_brand_cust_site (
                                       lt_cust_site_data (xc_site_idx).customer_id,
                                       lt_cust_site_data (xc_site_idx).address_id)
                            LOOP
                                log_records (
                                    gc_debug_flag,
                                       'Update Brand Customer Site : '
                                    || lcu_brand_cust_site_rec.orig_system_reference);

                                lr_cust_acct_site_rec   := NULL;
                                lr_cust_acct_site_rec.cust_acct_site_id   :=
                                    lcu_brand_cust_site_rec.cust_acct_site_id;
                                lr_cust_acct_site_rec.status   :=
                                    lt_cust_site_data (xc_site_idx).cust_site_status;
                                lr_cust_acct_site_rec.org_id   :=
                                    lt_cust_site_data (xc_site_idx).target_org;
                                ln_cust_acct_site_ovn   :=
                                    lcu_brand_cust_site_rec.object_version_number;

                                ln_msg_count            :=
                                    0;
                                lc_msg_data             :=
                                    NULL;
                                lc_return_status        :=
                                    NULL;
                                lc_data                 :=
                                    NULL;
                                lc_error_message        :=
                                    NULL;

                                fnd_msg_pub.initialize;

                                log_records (
                                    gc_debug_flag,
                                    'Call update_cust_acct_site API');

                                hz_cust_account_site_v2pub.update_cust_acct_site (
                                    p_init_msg_list   => gc_init_msg_list,
                                    p_cust_acct_site_rec   =>
                                        lr_cust_acct_site_rec,
                                    p_object_version_number   =>
                                        ln_cust_acct_site_ovn,
                                    x_return_status   => lc_return_status,
                                    x_msg_count       => ln_msg_count,
                                    x_msg_data        => lc_msg_data);

                                log_records (
                                    gc_debug_flag,
                                    'Return Status : ' || lc_return_status);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_cust_sites_upd_stg_t
                           SET record_status   = gc_process_status
                         WHERE     customer_id =
                                   lt_cust_site_data (xc_site_idx).customer_id
                               AND address_id =
                                   lt_cust_site_data (xc_site_idx).address_id;
                    END IF;
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;

        CLOSE cur_cust_site;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                    'Un-expecetd Error in  update_cust_sites => ' || SQLERRM);
            ROLLBACK;
    END update_cust_sites;


    /*****************************************************************************************
     *  Procedure Name :   UPDATE_CUST_SITES_USE                                             *
     *                                                                                       *
     *  Description    :   This Procedure will update the customer site use data             *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE update_cust_sites_use (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        CURSOR cur_cust_site_use IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_siteuse_upd_stg_t xcsu
             WHERE record_status = gc_validate_status;

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

        CURSOR lcu_get_ship_via (p_ship_via VARCHAR2)
        IS
            SELECT wcs.ship_method_code
              FROM xxd_conv.xxd_1206_ship_methods_map_t lsm, wsh_carrier_ship_methods wcs
             WHERE     old_ship_method_code = p_ship_via
                   AND ship_method_code = new_ship_method_code
                   AND ROWNUM = 1;

        -- Cursor to fetch Order type id from R12
        CURSOR lcur_order_type_id (p_order_type_name VARCHAR2)
        IS
            SELECT ottt12.transaction_type_id order_type_id
              FROM oe_transaction_types_tl ottt12, xxd_1206_order_type_map_t xtt
             WHERE     ottt12.name = xtt.new_12_2_3_name
                   AND legacy_12_0_6_name = p_order_type_name
                   AND language = 'US';

        -- Cursor to fetch Price List id from R12
        CURSOR lcu_get_price_list_id (p_price_list_name VARCHAR2)
        IS
            SELECT oeplr12.price_list_id price_list_id
              FROM oe_price_lists_vl oeplr12, xxd_1206_price_list_map_t xqph
             WHERE     1 = 1
                   AND oeplr12.name = xqph.pricelist_new_name
                   AND legacy_pricelist_name = p_price_list_name;

        CURSOR cur_brand_cust_site_use (p_customer_id VARCHAR2, p_address_id VARCHAR2, p_site_use_id VARCHAR2)
        IS
            SELECT hcsu.orig_system_reference, hcsu.cust_acct_site_id, hcsu.site_use_id,
                   hcsu.object_version_number
              FROM hz_cust_accounts_all hca, hz_cust_acct_relate_all hcar, hz_cust_accounts_all hca1,
                   hz_cust_acct_sites_all hcas, hz_cust_site_uses_all hcsu
             WHERE     hca.cust_account_id = hcar.cust_account_id
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hca1.cust_account_id = hcar.related_cust_account_id
                   AND TO_CHAR (p_customer_id) = hca1.orig_system_reference
                   AND TO_CHAR (p_address_id) || '-' || hca.attribute1 =
                       hcas.orig_system_reference
                   AND TO_CHAR (p_site_use_id) || '-' || hca.attribute1 =
                       hcsu.orig_system_reference;

        TYPE lt_cust_site_use_typ IS TABLE OF cur_cust_site_use%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_site_use_data       lt_cust_site_use_typ;
        ln_cust_acct_site_id        NUMBER;
        ln_cust_acct_site_use_id    NUMBER;
        ln_cust_acct_site_use_ovn   NUMBER;
        lr_cust_site_use_rec        hz_cust_account_site_v2pub.cust_site_use_rec_type;
        ln_billto_site_use_id       NUMBER;
        lc_return_status            VARCHAR2 (10);
        ln_msg_count                NUMBER;
        ln_msg_index_num            NUMBER;
        lc_msg_data                 VARCHAR2 (4000);
        lc_data                     VARCHAR2 (4000);
        lc_error_message            VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'update_cust_sites_use');

        OPEN cur_cust_site_use;

        LOOP
            FETCH cur_cust_site_use
                BULK COLLECT INTO lt_cust_site_use_data
                LIMIT 1000;

            EXIT WHEN lt_cust_site_use_data.COUNT = 0;

            FOR xc_site_use_idx IN lt_cust_site_use_data.FIRST ..
                                   lt_cust_site_use_data.LAST
            LOOP
                log_records (gc_debug_flag,
                             '************************************');
                log_records (
                    gc_debug_flag,
                       'customer_id : '
                    || lt_cust_site_use_data (xc_site_use_idx).customer_id);
                log_records (
                    gc_debug_flag,
                       'cust_acct_site_id : '
                    || lt_cust_site_use_data (xc_site_use_idx).cust_acct_site_id);
                log_records (
                    gc_debug_flag,
                       'site_use_id : '
                    || lt_cust_site_use_data (xc_site_use_idx).site_use_id);
                log_records (
                    gc_debug_flag,
                       'target_org : '
                    || lt_cust_site_use_data (xc_site_use_idx).target_org);

                mo_global.init ('AR');
                mo_global.set_policy_context (
                    'S',
                    lt_cust_site_use_data (xc_site_use_idx).target_org);

                ln_cust_acct_site_id        := NULL;
                ln_cust_acct_site_use_id    := NULL;
                ln_cust_acct_site_use_ovn   := NULL;
                ln_billto_site_use_id       := NULL;
                lr_cust_site_use_rec        := NULL;

                BEGIN
                    SELECT hcsu.cust_acct_site_id, hcsu.site_use_id, hcsu.object_version_number
                      INTO ln_cust_acct_site_id, ln_cust_acct_site_use_id, ln_cust_acct_site_use_ovn
                      FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas, hz_cust_accounts hca
                     WHERE     hcas.cust_account_id = hca.cust_account_id
                           AND hcas.cust_acct_site_id =
                               hcsu.cust_acct_site_id
                           AND hca.orig_system_reference =
                               TO_CHAR (
                                   lt_cust_site_use_data (xc_site_use_idx).customer_id)
                           AND hcas.orig_system_reference =
                               TO_CHAR (
                                   lt_cust_site_use_data (xc_site_use_idx).cust_acct_site_id)
                           AND hcsu.orig_system_reference =
                               TO_CHAR (
                                   lt_cust_site_use_data (xc_site_use_idx).site_use_id)
                           AND hcas.org_id =
                               lt_cust_site_use_data (xc_site_use_idx).target_org;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cust_acct_site_use_id   := 0;
                        log_records (gc_debug_flag,
                                     'Customer Site Use not found in DB ');
                        lc_return_status           := 'E';
                    WHEN OTHERS
                    THEN
                        ln_cust_acct_site_use_id   := 0;
                        log_records (gc_debug_flag,
                                     'Customer Site Use not found in DB ');
                        lc_return_status           := 'E';
                END;

                IF ln_cust_acct_site_use_id > 0
                THEN
                    mo_global.init ('AR');
                    mo_global.set_policy_context (
                        'S',
                        lt_cust_site_use_data (xc_site_use_idx).target_org);

                    lr_cust_site_use_rec.site_use_id   :=
                        ln_cust_acct_site_use_id;
                    lr_cust_site_use_rec.cust_acct_site_id   :=
                        ln_cust_acct_site_id;
                    lr_cust_site_use_rec.status   :=
                        lt_cust_site_use_data (xc_site_use_idx).site_use_status;
                    lr_cust_site_use_rec.primary_flag   :=
                        lt_cust_site_use_data (xc_site_use_idx).primary_flag;
                    lr_cust_site_use_rec.location   :=
                        lt_cust_site_use_data (xc_site_use_idx).location;
                    lr_cust_site_use_rec.org_id   :=
                        lt_cust_site_use_data (xc_site_use_idx).target_org;

                    --lr_cust_site_use_rec.site_use_code       := lt_cust_site_use_data ( xc_site_use_idx ).site_use_code;

                    OPEN lcu_get_ship_via (
                        p_ship_via   =>
                            lt_cust_site_use_data (xc_site_use_idx).ship_via);

                    FETCH lcu_get_ship_via INTO lr_cust_site_use_rec.ship_via;

                    CLOSE lcu_get_ship_via;

                    OPEN lcur_order_type_id (
                        p_order_type_name   =>
                            lt_cust_site_use_data (xc_site_use_idx).order_type_name);

                    FETCH lcur_order_type_id
                        INTO lr_cust_site_use_rec.order_type_id;

                    CLOSE lcur_order_type_id;

                    OPEN lcu_get_price_list_id (
                        p_price_list_name   =>
                            lt_cust_site_use_data (xc_site_use_idx).price_list_name);

                    FETCH lcu_get_price_list_id
                        INTO lr_cust_site_use_rec.price_list_id;

                    CLOSE lcu_get_price_list_id;

                    IF lt_cust_site_use_data (xc_site_use_idx).bill_to_site_use_id
                           IS NOT NULL
                    THEN
                        OPEN lcu_bto_site_use_id (
                            lt_cust_site_use_data (xc_site_use_idx).customer_id,
                            lt_cust_site_use_data (xc_site_use_idx).bill_to_site_use_id);

                        FETCH lcu_bto_site_use_id INTO ln_billto_site_use_id;

                        CLOSE lcu_bto_site_use_id;

                        lr_cust_site_use_rec.bill_to_site_use_id   :=
                            ln_billto_site_use_id;
                    END IF;

                    ln_msg_count       := 0;
                    lc_msg_data        := NULL;
                    lc_return_status   := NULL;
                    lc_data            := NULL;
                    lc_error_message   := NULL;

                    fnd_msg_pub.initialize;

                    log_records (gc_debug_flag,
                                 'Call update_cust_site_use API');

                    hz_cust_account_site_v2pub.update_cust_site_use (
                        p_init_msg_list           => gc_init_msg_list,
                        p_cust_site_use_rec       => lr_cust_site_use_rec,
                        p_object_version_number   => ln_cust_acct_site_use_ovn,
                        x_return_status           => lc_return_status,
                        x_msg_count               => ln_msg_count,
                        x_msg_data                => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (gc_debug_flag,
                                         'update_cust_site_use API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_cust_siteuse_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     customer_id =
                                   lt_cust_site_use_data (xc_site_use_idx).customer_id
                               AND cust_acct_site_id =
                                   lt_cust_site_use_data (xc_site_use_idx).cust_acct_site_id
                               AND site_use_id =
                                   lt_cust_site_use_data (xc_site_use_idx).site_use_id;
                    ELSE
                        IF lt_cust_site_use_data (xc_site_use_idx).site_use_status =
                           'I'
                        THEN
                            FOR lcu_brand_cust_site_use_rec
                                IN cur_brand_cust_site_use (
                                       lt_cust_site_use_data (
                                           xc_site_use_idx).customer_id,
                                       lt_cust_site_use_data (
                                           xc_site_use_idx).cust_acct_site_id,
                                       lt_cust_site_use_data (
                                           xc_site_use_idx).site_use_id)
                            LOOP
                                log_records (
                                    gc_debug_flag,
                                       'Update Brand Customer Site Use : '
                                    || lcu_brand_cust_site_use_rec.orig_system_reference);

                                lr_cust_site_use_rec                     := NULL;
                                lr_cust_site_use_rec.site_use_id         :=
                                    lcu_brand_cust_site_use_rec.site_use_id;
                                lr_cust_site_use_rec.cust_acct_site_id   :=
                                    lcu_brand_cust_site_use_rec.cust_acct_site_id;
                                lr_cust_site_use_rec.status              :=
                                    lt_cust_site_use_data (xc_site_use_idx).site_use_status;
                                ln_cust_acct_site_use_ovn                :=
                                    lcu_brand_cust_site_use_rec.object_version_number;

                                ln_msg_count                             := 0;
                                lc_msg_data                              :=
                                    NULL;
                                lc_return_status                         :=
                                    NULL;
                                lc_data                                  :=
                                    NULL;
                                lc_error_message                         :=
                                    NULL;

                                fnd_msg_pub.initialize;

                                log_records (gc_debug_flag,
                                             'Call update_cust_site_use API');

                                hz_cust_account_site_v2pub.update_cust_site_use (
                                    p_init_msg_list   => gc_init_msg_list,
                                    p_cust_site_use_rec   =>
                                        lr_cust_site_use_rec,
                                    p_object_version_number   =>
                                        ln_cust_acct_site_use_ovn,
                                    x_return_status   => lc_return_status,
                                    x_msg_count       => ln_msg_count,
                                    x_msg_data        => lc_msg_data);

                                log_records (
                                    gc_debug_flag,
                                    'Return Status : ' || lc_return_status);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_cust_siteuse_upd_stg_t
                           SET record_status   = gc_process_status
                         WHERE     customer_id =
                                   lt_cust_site_use_data (xc_site_use_idx).customer_id
                               AND cust_acct_site_id =
                                   lt_cust_site_use_data (xc_site_use_idx).cust_acct_site_id
                               AND site_use_id =
                                   lt_cust_site_use_data (xc_site_use_idx).site_use_id;
                    END IF;
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;

        CLOSE cur_cust_site_use;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Un-expecetd Error in  update_cust_sites_use => '
                    || SQLERRM);
            ROLLBACK;
    END update_cust_sites_use;


    /*****************************************************************************************
     *  Procedure Name :   UPDATE_CUST_PROFILE                                               *
     *                                                                                       *
     *  Description    :   This Procedure will update the customer profile data              *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE update_cust_profile (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        CURSOR cur_cust_profile IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_prof_upd_stg_t xcp
             WHERE record_status = gc_validate_status;

        -- Cursor to fetch collector_id for collector_name
        CURSOR lcu_fetch_collector_id (p_collector_name VARCHAR2)
        IS
            SELECT ac.collector_id
              FROM ar_collectors ac
             WHERE     ac.status = 'A'
                   AND UPPER (ac.name) = UPPER (p_collector_name);

        CURSOR lcu_dunning_letter_set_id (p_dunning_letter_set_name VARCHAR2)
        IS
            SELECT dunning_letter_set_id
              FROM ar_dunning_letter_sets
             WHERE 1 = 1 AND UPPER (name) = UPPER (p_dunning_letter_set_name);

        CURSOR lcu_statement_cycle_id (p_statement_cycle_name VARCHAR2)
        IS
            SELECT statement_cycle_id
              FROM ar_statement_cycles
             WHERE name = p_statement_cycle_name;

        CURSOR lcu_grouping_rule_id (p_grouping_rule_name VARCHAR2)
        IS
            SELECT grouping_rule_id
              FROM ra_grouping_rules
             WHERE 1 = 1 AND UPPER (name) = UPPER (p_grouping_rule_name);


        CURSOR lcu_get_standard_terms_id (p_standard_terms_name VARCHAR2)
        IS
            SELECT rt.term_id payment_term_id
              FROM ra_terms rt, xxd_1206_payment_term_map_t xpt
             WHERE     1 = 1
                   AND UPPER (rt.name) = UPPER (xpt.new_term_name)
                   AND UPPER (xpt.old_term_name) =
                       UPPER (p_standard_terms_name);

        TYPE lt_cust_profile_typ IS TABLE OF cur_cust_profile%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_profile_data          lt_cust_profile_typ;
        ln_cust_account_profile_id    NUMBER;
        ln_cust_account_profile_ovn   NUMBER;
        ln_site_use_org_id            NUMBER;
        ln_collector_id               NUMBER;
        ln_stmt_cycle_id              NUMBER;
        ln_dunning_letter_set_id      NUMBER;
        ln_statement_cycle_id         NUMBER;
        ln_grouping_rule_id           NUMBER;
        ln_standard_terms_id          NUMBER;
        lr_customer_profile_rec       hz_customer_profile_v2pub.customer_profile_rec_type;
        lc_return_status              VARCHAR2 (10);
        ln_msg_count                  NUMBER;
        ln_msg_index_num              NUMBER;
        lc_msg_data                   VARCHAR2 (4000);
        lc_data                       VARCHAR2 (4000);
        lc_error_message              VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'update_cust_profile');

        OPEN cur_cust_profile;

        LOOP
            FETCH cur_cust_profile
                BULK COLLECT INTO lt_cust_profile_data
                LIMIT 1000;

            EXIT WHEN lt_cust_profile_data.COUNT = 0;

            FOR xc_cust_profile_idx IN lt_cust_profile_data.FIRST ..
                                       lt_cust_profile_data.LAST
            LOOP
                ln_cust_account_profile_id    := NULL;
                ln_cust_account_profile_ovn   := NULL;
                ln_site_use_org_id            := NULL;
                ln_collector_id               := NULL;
                ln_stmt_cycle_id              := NULL;
                ln_dunning_letter_set_id      := NULL;
                ln_statement_cycle_id         := NULL;
                ln_grouping_rule_id           := NULL;
                ln_standard_terms_id          := NULL;
                lr_customer_profile_rec       := NULL;

                log_records (gc_debug_flag,
                             '************************************');
                log_records (
                    gc_debug_flag,
                       'customer_id : '
                    || lt_cust_profile_data (xc_cust_profile_idx).orig_system_customer_ref);
                log_records (
                    gc_debug_flag,
                       'address_id : '
                    || lt_cust_profile_data (xc_cust_profile_idx).orig_system_address_ref);
                log_records (
                    gc_debug_flag,
                       'site_use_id : '
                    || lt_cust_profile_data (xc_cust_profile_idx).site_use_id);


                IF lt_cust_profile_data (xc_cust_profile_idx).site_use_id
                       IS NULL
                THEN
                    BEGIN
                        SELECT hcp.cust_account_profile_id, hcp.object_version_number
                          INTO ln_cust_account_profile_id, ln_cust_account_profile_ovn
                          FROM hz_cust_accounts hca, hz_customer_profiles hcp
                         WHERE     hca.cust_account_id = hcp.cust_account_id
                               AND hcp.site_use_id IS NULL
                               AND hca.orig_system_reference =
                                   TO_CHAR (
                                       lt_cust_profile_data (
                                           xc_cust_profile_idx).orig_system_customer_ref);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_cust_account_profile_id   := 0;
                            log_records (gc_debug_flag,
                                         'Customer Profile not found in DB ');
                            lc_return_status             := 'E';
                        WHEN OTHERS
                        THEN
                            ln_cust_account_profile_id   := 0;
                            log_records (gc_debug_flag,
                                         'Customer Profile not found in DB ');
                            lc_return_status             := 'E';
                    END;
                ELSE
                    BEGIN
                        SELECT hcp.cust_account_profile_id, hcp.object_version_number, hcsu.org_id
                          INTO ln_cust_account_profile_id, ln_cust_account_profile_ovn, ln_site_use_org_id
                          FROM hz_customer_profiles hcp, hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas,
                               hz_cust_accounts hca
                         WHERE     hcas.cust_account_id = hca.cust_account_id
                               AND hcas.cust_acct_site_id =
                                   hcsu.cust_acct_site_id
                               AND hca.cust_account_id = hcp.cust_account_id
                               AND hcp.site_use_id = hcsu.site_use_id
                               AND hca.orig_system_reference =
                                   TO_CHAR (
                                       lt_cust_profile_data (
                                           xc_cust_profile_idx).orig_system_customer_ref)
                               AND hcas.orig_system_reference =
                                   TO_CHAR (
                                       lt_cust_profile_data (
                                           xc_cust_profile_idx).orig_system_address_ref)
                               AND hcsu.orig_system_reference =
                                   TO_CHAR (
                                       lt_cust_profile_data (
                                           xc_cust_profile_idx).site_use_id);

                        mo_global.init ('AR');
                        mo_global.set_policy_context ('S',
                                                      ln_site_use_org_id);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_cust_account_profile_id   := 0;
                            log_records (
                                gc_debug_flag,
                                'Customer Site Profile not found in DB ');
                            lc_return_status             := 'E';
                        WHEN OTHERS
                        THEN
                            ln_cust_account_profile_id   := 0;
                            log_records (
                                gc_debug_flag,
                                'Customer Site Profile not found in DB ');
                            lc_return_status             := 'E';
                    END;
                END IF;

                IF ln_cust_account_profile_id > 0
                THEN
                    IF lt_cust_profile_data (xc_cust_profile_idx).collector_name
                           IS NOT NULL
                    THEN
                        OPEN lcu_fetch_collector_id (
                            lt_cust_profile_data (xc_cust_profile_idx).collector_name);

                        FETCH lcu_fetch_collector_id INTO ln_collector_id;

                        CLOSE lcu_fetch_collector_id;
                    END IF;

                    IF lt_cust_profile_data (xc_cust_profile_idx).dunning_letter_set_name
                           IS NOT NULL
                    THEN
                        OPEN lcu_dunning_letter_set_id (
                            lt_cust_profile_data (xc_cust_profile_idx).dunning_letter_set_name);

                        FETCH lcu_dunning_letter_set_id
                            INTO ln_dunning_letter_set_id;

                        CLOSE lcu_dunning_letter_set_id;
                    END IF;

                    IF lt_cust_profile_data (xc_cust_profile_idx).statement_cycle_name
                           IS NOT NULL
                    THEN
                        OPEN lcu_statement_cycle_id (
                            lt_cust_profile_data (xc_cust_profile_idx).statement_cycle_name);

                        FETCH lcu_statement_cycle_id
                            INTO ln_statement_cycle_id;

                        CLOSE lcu_statement_cycle_id;
                    END IF;

                    IF lt_cust_profile_data (xc_cust_profile_idx).grouping_rule_name
                           IS NOT NULL
                    THEN
                        OPEN lcu_grouping_rule_id (
                            lt_cust_profile_data (xc_cust_profile_idx).grouping_rule_name);

                        FETCH lcu_grouping_rule_id INTO ln_grouping_rule_id;

                        CLOSE lcu_grouping_rule_id;
                    END IF;


                    IF lt_cust_profile_data (xc_cust_profile_idx).standard_terms_name
                           IS NOT NULL
                    THEN
                        OPEN lcu_get_standard_terms_id (
                            lt_cust_profile_data (xc_cust_profile_idx).standard_terms_name);

                        FETCH lcu_get_standard_terms_id
                            INTO ln_standard_terms_id;

                        CLOSE lcu_get_standard_terms_id;
                    END IF;

                    lr_customer_profile_rec.cust_account_profile_id   :=
                        ln_cust_account_profile_id;
                    lr_customer_profile_rec.status         :=
                        lt_cust_profile_data (xc_cust_profile_idx).prof_status;
                    lr_customer_profile_rec.collector_id   := ln_collector_id;
                    lr_customer_profile_rec.account_status   :=
                        lt_cust_profile_data (xc_cust_profile_idx).account_status;
                    lr_customer_profile_rec.auto_rec_incl_disputed_flag   :=
                        lt_cust_profile_data (xc_cust_profile_idx).auto_rec_incl_disputed_flag;
                    lr_customer_profile_rec.charge_on_finance_charge_flag   :=
                        lt_cust_profile_data (xc_cust_profile_idx).charge_on_finance_charge_flag;
                    lr_customer_profile_rec.clearing_days   :=
                        lt_cust_profile_data (xc_cust_profile_idx).clearing_days;
                    lr_customer_profile_rec.credit_balance_statements   :=
                        lt_cust_profile_data (xc_cust_profile_idx).credit_balance_statements;
                    lr_customer_profile_rec.credit_checking   :=
                        lt_cust_profile_data (xc_cust_profile_idx).credit_checking;

                    IF lt_cust_profile_data (xc_cust_profile_idx).cons_inv_flag =
                       'Y'
                    THEN
                        lr_customer_profile_rec.cons_inv_flag   :=
                            lt_cust_profile_data (xc_cust_profile_idx).cons_inv_flag;
                        lr_customer_profile_rec.cons_inv_type   :=
                            lt_cust_profile_data (xc_cust_profile_idx).cons_inv_type;
                        lr_customer_profile_rec.cons_bill_level   :=
                            lt_cust_profile_data (xc_cust_profile_idx).cons_bill_level;
                    END IF;

                    lr_customer_profile_rec.tolerance      :=
                        lt_cust_profile_data (xc_cust_profile_idx).tolerance;
                    lr_customer_profile_rec.payment_grace_days   :=
                        lt_cust_profile_data (xc_cust_profile_idx).payment_grace_days;
                    lr_customer_profile_rec.attribute1     :=
                        lt_cust_profile_data (xc_cust_profile_idx).attribute1;
                    lr_customer_profile_rec.attribute2     :=
                        lt_cust_profile_data (xc_cust_profile_idx).attribute2;
                    lr_customer_profile_rec.credit_hold    :=
                        lt_cust_profile_data (xc_cust_profile_idx).credit_hold;
                    lr_customer_profile_rec.credit_rating   :=
                        lt_cust_profile_data (xc_cust_profile_idx).credit_rating;
                    lr_customer_profile_rec.dunning_letters   :=
                        lt_cust_profile_data (xc_cust_profile_idx).dunning_letters;
                    lr_customer_profile_rec.dunning_letter_set_id   :=
                        ln_dunning_letter_set_id;
                    lr_customer_profile_rec.grouping_rule_id   :=
                        ln_grouping_rule_id;
                    lr_customer_profile_rec.interest_period_days   :=
                        lt_cust_profile_data (xc_cust_profile_idx).interest_period_days;
                    lr_customer_profile_rec.lockbox_matching_option   :=
                        lt_cust_profile_data (xc_cust_profile_idx).lockbox_matching_option;
                    lr_customer_profile_rec.interest_charges   :=
                        lt_cust_profile_data (xc_cust_profile_idx).interest_charges;
                    lr_customer_profile_rec.discount_terms   :=
                        lt_cust_profile_data (xc_cust_profile_idx).discount_terms;

                    IF lt_cust_profile_data (xc_cust_profile_idx).discount_terms =
                       'N'
                    THEN
                        lr_customer_profile_rec.discount_grace_days   :=
                            fnd_api.g_miss_num;
                    ELSE
                        lr_customer_profile_rec.discount_grace_days   :=
                            lt_cust_profile_data (xc_cust_profile_idx).discount_grace_days;
                    END IF;

                    lr_customer_profile_rec.override_terms   :=
                        lt_cust_profile_data (xc_cust_profile_idx).override_terms;
                    lr_customer_profile_rec.tax_printing_option   :=
                        lt_cust_profile_data (xc_cust_profile_idx).tax_printing_option;
                    lr_customer_profile_rec.send_statements   :=
                        lt_cust_profile_data (xc_cust_profile_idx).statements;

                    IF lt_cust_profile_data (xc_cust_profile_idx).statements =
                       'N'
                    THEN
                        lr_customer_profile_rec.statement_cycle_id   :=
                            fnd_api.g_miss_num;
                    ELSE
                        lr_customer_profile_rec.statement_cycle_id   :=
                            ln_statement_cycle_id;
                    END IF;

                    lr_customer_profile_rec.standard_terms   :=
                        ln_standard_terms_id;
                    lr_customer_profile_rec.credit_classification   :=
                        lt_cust_profile_data (xc_cust_profile_idx).credit_classification;

                    ln_msg_count                           :=
                        0;
                    lc_msg_data                            :=
                        NULL;
                    lc_return_status                       :=
                        NULL;
                    lc_data                                :=
                        NULL;
                    lc_error_message                       :=
                        NULL;

                    fnd_msg_pub.initialize;

                    log_records (gc_debug_flag,
                                 'Call update_customer_profile API');

                    hz_customer_profile_v2pub.update_customer_profile (
                        p_init_msg_list           => gc_init_msg_list,
                        p_customer_profile_rec    => lr_customer_profile_rec,
                        p_object_version_number   =>
                            ln_cust_account_profile_ovn,
                        x_return_status           => lc_return_status,
                        x_msg_count               => ln_msg_count,
                        x_msg_data                => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (
                                gc_debug_flag,
                                'update_customer_profile API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_cust_prof_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     orig_system_customer_ref =
                                   lt_cust_profile_data (xc_cust_profile_idx).orig_system_customer_ref
                               AND customer_profile_id =
                                   lt_cust_profile_data (xc_cust_profile_idx).customer_profile_id;
                    ELSE
                        UPDATE xxd_ar_cust_prof_upd_stg_t
                           SET record_status   = gc_process_status
                         WHERE     orig_system_customer_ref =
                                   lt_cust_profile_data (xc_cust_profile_idx).orig_system_customer_ref
                               AND customer_profile_id =
                                   lt_cust_profile_data (xc_cust_profile_idx).customer_profile_id;
                    END IF;
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;

        CLOSE cur_cust_profile;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Un-expecetd Error in  update_cust_profile => '
                    || SQLERRM);
            ROLLBACK;
    END update_cust_profile;


    /*****************************************************************************************
     *  Procedure Name :   UPDATE_CUST_PROFILE_AMT                                           *
     *                                                                                       *
     *  Description    :   This Procedure will update the customer profile amount data       *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE update_cust_profile_amt (
        p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        CURSOR cur_cust_profile_amt IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cust_profamt_upd_stg_t xcp
             WHERE record_status = gc_validate_status;

        TYPE lt_cust_profile_amt_typ IS TABLE OF cur_cust_profile_amt%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_cust_profile_amt_data       lt_cust_profile_amt_typ;
        ln_cust_acct_profile_amt_id    NUMBER;
        ln_cust_acct_profile_amt_ovn   NUMBER;
        lr_cust_profile_amt_rec        hz_customer_profile_v2pub.cust_profile_amt_rec_type;
        ln_count                       NUMBER;
        lc_distribution_channel        VARCHAR2 (240);
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        ln_msg_index_num               NUMBER;
        lc_msg_data                    VARCHAR2 (4000);
        lc_data                        VARCHAR2 (4000);
        lc_error_message               VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'update_cust_profile_amt');

        OPEN cur_cust_profile_amt;

        LOOP
            FETCH cur_cust_profile_amt
                BULK COLLECT INTO lt_cust_profile_amt_data
                LIMIT 1000;

            EXIT WHEN lt_cust_profile_amt_data.COUNT = 0;

            FOR xc_cust_profile_idx IN lt_cust_profile_amt_data.FIRST ..
                                       lt_cust_profile_amt_data.LAST
            LOOP
                ln_cust_acct_profile_amt_id    := NULL;
                ln_cust_acct_profile_amt_ovn   := NULL;
                lr_cust_profile_amt_rec        := NULL;
                lc_distribution_channel        := NULL;

                log_records (gc_debug_flag,
                             '************************************');
                log_records (
                    gc_debug_flag,
                       'customer_id : '
                    || lt_cust_profile_amt_data (xc_cust_profile_idx).customer_id);
                log_records (
                    gc_debug_flag,
                       'site_use_id : '
                    || lt_cust_profile_amt_data (xc_cust_profile_idx).site_use_id);
                log_records (
                    gc_debug_flag,
                       'currency_code : '
                    || lt_cust_profile_amt_data (xc_cust_profile_idx).currency_code);

                IF lt_cust_profile_amt_data (xc_cust_profile_idx).site_use_id
                       IS NULL
                THEN
                    BEGIN
                        SELECT hcpa.cust_acct_profile_amt_id, hcpa.object_version_number, hca.attribute3
                          INTO ln_cust_acct_profile_amt_id, ln_cust_acct_profile_amt_ovn, lc_distribution_channel
                          FROM hz_cust_accounts hca, hz_customer_profiles hcp, hz_cust_profile_amts hcpa
                         WHERE     hca.cust_account_id = hcp.cust_account_id
                               AND hcp.cust_account_profile_id =
                                   hcpa.cust_account_profile_id
                               AND hcp.site_use_id IS NULL
                               AND hca.orig_system_reference =
                                   TO_CHAR (
                                       lt_cust_profile_amt_data (
                                           xc_cust_profile_idx).customer_id)
                               AND currency_code =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).currency_code;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_cust_acct_profile_amt_id   := 0;
                            log_records (
                                gc_debug_flag,
                                'Customer Site Profile amount not found in DB ');
                            lc_return_status              := 'E';
                        WHEN OTHERS
                        THEN
                            ln_cust_acct_profile_amt_id   := 0;
                            log_records (
                                gc_debug_flag,
                                'Customer Site Profile amount not found in DB ');
                            lc_return_status              := 'E';
                    END;
                ELSE
                    BEGIN
                        ln_cust_acct_profile_amt_id   := NULL;

                        SELECT hcpa.cust_acct_profile_amt_id, hcpa.object_version_number, hca.attribute3
                          INTO ln_cust_acct_profile_amt_id, ln_cust_acct_profile_amt_ovn, lc_distribution_channel
                          FROM hz_cust_profile_amts hcpa, hz_customer_profiles hcp, hz_cust_site_uses_all hcsu,
                               hz_cust_acct_sites_all hcas, hz_cust_accounts hca
                         WHERE     hcas.cust_account_id = hca.cust_account_id
                               AND hcas.cust_acct_site_id =
                                   hcsu.cust_acct_site_id
                               AND hca.cust_account_id = hcp.cust_account_id
                               AND hcp.site_use_id = hcsu.site_use_id
                               AND hcp.cust_account_profile_id =
                                   hcpa.cust_account_profile_id
                               AND hca.orig_system_reference =
                                   TO_CHAR (
                                       lt_cust_profile_amt_data (
                                           xc_cust_profile_idx).customer_id)
                               AND hcsu.orig_system_reference =
                                   TO_CHAR (
                                       lt_cust_profile_amt_data (
                                           xc_cust_profile_idx).site_use_id)
                               AND currency_code =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).currency_code;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_cust_acct_profile_amt_id   := 0;
                            log_records (
                                gc_debug_flag,
                                'Customer Site Profile amount not found in DB ');
                            lc_return_status              := 'E';
                        WHEN OTHERS
                        THEN
                            ln_cust_acct_profile_amt_id   := 0;
                            log_records (
                                gc_debug_flag,
                                'Customer Site Profile amount not found in DB ');
                            lc_return_status              := 'E';
                    END;
                END IF;

                IF ln_cust_acct_profile_amt_id > 0
                THEN
                    SELECT COUNT (*)
                      INTO ln_count
                      FROM xxd_conv.xx_exclude_legacy xxel, hz_cust_accounts hca
                     WHERE     xxel.cust_number = hca.account_number
                           AND hca.orig_system_reference =
                               TO_CHAR (
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).customer_id);

                    IF ln_count = 0
                    THEN
                        lr_cust_profile_amt_rec.cust_acct_profile_amt_id   :=
                            ln_cust_acct_profile_amt_id;
                        --lr_cust_profile_amt_rec.trx_credit_limit             := 1;
                        --lr_cust_profile_amt_rec.overall_credit_limit         := 1;
                        lr_cust_profile_amt_rec.min_dunning_amount   := NULL;
                        lr_cust_profile_amt_rec.min_dunning_invoice_amount   :=
                            NULL;
                        lr_cust_profile_amt_rec.min_statement_amount   :=
                            NULL;
                        lr_cust_profile_amt_rec.interest_type        :=
                            'FIXED_RATE';
                        lr_cust_profile_amt_rec.interest_rate        :=
                            NVL (
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).interest_rate,
                                0);
                        lr_cust_profile_amt_rec.min_fc_balance_amount   :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).min_fc_balance_amount;
                        lr_cust_profile_amt_rec.min_fc_balance_overdue_type   :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).min_fc_balance_overdue_type;
                        lr_cust_profile_amt_rec.attribute_category   :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute_category;
                        lr_cust_profile_amt_rec.attribute1           :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute1;
                        lr_cust_profile_amt_rec.attribute2           :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute2;
                        lr_cust_profile_amt_rec.attribute3           :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute3;
                        lr_cust_profile_amt_rec.attribute4           :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute4;
                        lr_cust_profile_amt_rec.attribute5           :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute5;
                        lr_cust_profile_amt_rec.attribute6           :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute6;
                        lr_cust_profile_amt_rec.attribute7           :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute7;
                        lr_cust_profile_amt_rec.attribute8           :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute8;
                        lr_cust_profile_amt_rec.attribute9           :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute9;
                        lr_cust_profile_amt_rec.attribute10          :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute10;
                        lr_cust_profile_amt_rec.attribute11          :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute11;
                        lr_cust_profile_amt_rec.attribute12          :=
                            lt_cust_profile_amt_data (xc_cust_profile_idx).attribute12;
                    ELSE
                        IF lt_cust_profile_amt_data (xc_cust_profile_idx).site_use_id
                               IS NULL
                        THEN
                            lr_cust_profile_amt_rec.cust_acct_profile_amt_id   :=
                                ln_cust_acct_profile_amt_id;

                            /*IF UPPER ( lc_distribution_channel ) <> 'RETAIL'
                            THEN
                              lr_cust_profile_amt_rec.trx_credit_limit      :=
                                lt_cust_profile_amt_data ( xc_cust_profile_idx ).trx_credit_limit;
                              lr_cust_profile_amt_rec.overall_credit_limit      :=
                                lt_cust_profile_amt_data ( xc_cust_profile_idx ).overall_credit_limit;
                            END IF;*/

                            lr_cust_profile_amt_rec.min_dunning_amount   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_dunning_amount;
                            lr_cust_profile_amt_rec.min_dunning_invoice_amount   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_dunning_invoice_amount;
                            lr_cust_profile_amt_rec.min_statement_amount   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_statement_amount;
                            lr_cust_profile_amt_rec.interest_type   :=
                                'FIXED_RATE';
                            lr_cust_profile_amt_rec.interest_rate   :=
                                NVL (
                                    lt_cust_profile_amt_data (
                                        xc_cust_profile_idx).interest_rate,
                                    0);
                            lr_cust_profile_amt_rec.min_fc_balance_amount   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_fc_balance_amount;
                            lr_cust_profile_amt_rec.min_fc_balance_overdue_type   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_fc_balance_overdue_type;
                            lr_cust_profile_amt_rec.attribute_category   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute_category;
                            lr_cust_profile_amt_rec.attribute1   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute1;
                            lr_cust_profile_amt_rec.attribute2   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute2;
                            lr_cust_profile_amt_rec.attribute3   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute3;
                            lr_cust_profile_amt_rec.attribute4   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute4;
                            lr_cust_profile_amt_rec.attribute5   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute5;
                            lr_cust_profile_amt_rec.attribute6   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute6;
                            lr_cust_profile_amt_rec.attribute7   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute7;
                            lr_cust_profile_amt_rec.attribute8   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute8;
                            lr_cust_profile_amt_rec.attribute9   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute9;
                            lr_cust_profile_amt_rec.attribute10   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute10;
                            lr_cust_profile_amt_rec.attribute11   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute11;
                            lr_cust_profile_amt_rec.attribute12   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute12;
                        ELSE
                            lr_cust_profile_amt_rec.cust_acct_profile_amt_id   :=
                                ln_cust_acct_profile_amt_id;
                            /*lr_cust_profile_amt_rec.trx_credit_limit             :=
                              lt_cust_profile_amt_data ( xc_cust_profile_idx ).trx_credit_limit;
                            lr_cust_profile_amt_rec.overall_credit_limit         :=
                              lt_cust_profile_amt_data ( xc_cust_profile_idx ).overall_credit_limit;*/
                            lr_cust_profile_amt_rec.min_dunning_amount   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_dunning_amount;
                            lr_cust_profile_amt_rec.min_dunning_invoice_amount   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_dunning_invoice_amount;
                            lr_cust_profile_amt_rec.min_statement_amount   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_statement_amount;
                            lr_cust_profile_amt_rec.interest_type   :=
                                'FIXED_RATE';
                            lr_cust_profile_amt_rec.interest_rate   :=
                                NVL (
                                    lt_cust_profile_amt_data (
                                        xc_cust_profile_idx).interest_rate,
                                    0);
                            lr_cust_profile_amt_rec.min_fc_balance_amount   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_fc_balance_amount;
                            lr_cust_profile_amt_rec.min_fc_balance_overdue_type   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).min_fc_balance_overdue_type;
                            lr_cust_profile_amt_rec.attribute_category   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute_category;
                            lr_cust_profile_amt_rec.attribute1   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute1;
                            lr_cust_profile_amt_rec.attribute2   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute2;
                            lr_cust_profile_amt_rec.attribute3   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute3;
                            lr_cust_profile_amt_rec.attribute4   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute4;
                            lr_cust_profile_amt_rec.attribute5   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute5;
                            lr_cust_profile_amt_rec.attribute6   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute6;
                            lr_cust_profile_amt_rec.attribute7   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute7;
                            lr_cust_profile_amt_rec.attribute8   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute8;
                            lr_cust_profile_amt_rec.attribute9   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute9;
                            lr_cust_profile_amt_rec.attribute10   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute10;
                            lr_cust_profile_amt_rec.attribute11   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute11;
                            lr_cust_profile_amt_rec.attribute12   :=
                                lt_cust_profile_amt_data (
                                    xc_cust_profile_idx).attribute12;
                        END IF;
                    END IF;

                    ln_msg_count       := 0;
                    lc_msg_data        := NULL;
                    lc_return_status   := NULL;
                    lc_data            := NULL;
                    lc_error_message   := NULL;

                    fnd_msg_pub.initialize;

                    log_records (gc_debug_flag,
                                 'Call update_cust_profile_amt API');

                    hz_customer_profile_v2pub.update_cust_profile_amt (
                        p_init_msg_list           => gc_init_msg_list,
                        p_cust_profile_amt_rec    => lr_cust_profile_amt_rec,
                        p_object_version_number   =>
                            ln_cust_acct_profile_amt_ovn,
                        x_return_status           => lc_return_status,
                        x_msg_count               => ln_msg_count,
                        x_msg_data                => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (
                                gc_debug_flag,
                                'update_cust_profile_amt API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_cust_profamt_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     customer_id =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).customer_id
                               AND cust_account_profile_id =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).cust_account_profile_id
                               AND currency_code =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).currency_code;
                    ELSE
                        UPDATE xxd_ar_cust_profamt_upd_stg_t
                           SET record_status   = gc_process_status
                         WHERE     customer_id =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).customer_id
                               AND cust_account_profile_id =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).cust_account_profile_id
                               AND currency_code =
                                   lt_cust_profile_amt_data (
                                       xc_cust_profile_idx).currency_code;
                    END IF;
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;

        CLOSE cur_cust_profile_amt;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Un-expecetd Error in  update_cust_profile_amt => '
                    || SQLERRM);
            ROLLBACK;
    END update_cust_profile_amt;


    /*****************************************************************************************
     *  Procedure Name :   UPDATE_CUST_CONTACTS                                              *
     *                                                                                       *
     *  Description    :   This Procedure will update the customer contact data              *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE update_cust_contacts (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        CURSOR cur_contacts IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_contact_upd_stg_t xcp
             WHERE record_status = gc_validate_status;

        CURSOR cur_contact_roles (p_orig_system_customer_ref VARCHAR2, p_orig_system_address_ref VARCHAR2, p_orig_system_contact_ref VARCHAR2)
        IS
            SELECT hoc.org_contact_id org_contact_id, hoc.object_version_number org_contact_ovn, hr.object_version_number rel_ovn,
                   hp1.object_version_number party_ovn, h_contact.party_id contact_person_id, h_contact.object_version_number contact_person_ovn,
                   hcar.cust_account_role_id cust_account_role_id, hcar.object_version_number cust_account_role_ovn
              FROM hz_parties hp, hz_relationships hr, hz_parties h_contact,
                   hz_parties hp1, hz_cust_accounts cust, hz_org_contacts hoc,
                   hz_cust_account_roles hcar
             WHERE     hr.subject_id = h_contact.party_id
                   AND hr.object_id = hp.party_id
                   AND cust.party_id = hp.party_id
                   AND hoc.party_relationship_id = hr.relationship_id
                   AND hp1.party_id = hr.party_id
                   AND hr.subject_type = 'PERSON'
                   AND hcar.party_id = hr.party_id
                   AND hcar.cust_account_id = cust.cust_account_id
                   AND hcar.role_type = 'CONTACT'
                   AND cust.orig_system_reference =
                       TO_CHAR (p_orig_system_customer_ref)
                   AND hoc.orig_system_reference =
                       TO_CHAR (p_orig_system_contact_ref)
            UNION
            SELECT hoc.org_contact_id org_contact_id, hoc.object_version_number org_contact_ovn, hr.object_version_number rel_ovn,
                   hp1.object_version_number party_ovn, h_contact.party_id contact_person_id, h_contact.object_version_number contact_person_ovn,
                   hcar.cust_account_role_id cust_account_role_id, hcar.object_version_number cust_account_role_ovn
              FROM hz_parties hp, hz_relationships hr, hz_parties h_contact,
                   hz_parties hp1, hz_cust_accounts cust, hz_cust_acct_sites_all hcas,
                   hz_org_contacts hoc, hz_cust_account_roles hcar
             WHERE     hr.subject_id = h_contact.party_id
                   AND hr.object_id = hp.party_id
                   AND cust.party_id = hp.party_id
                   AND hoc.party_relationship_id = hr.relationship_id
                   AND hp1.party_id = hr.party_id
                   AND hr.subject_type = 'PERSON'
                   AND cust.cust_account_id = hcas.cust_account_id
                   AND hcar.party_id = hr.party_id
                   AND hcar.cust_account_id = cust.cust_account_id
                   AND hcar.cust_acct_site_id = hcas.cust_acct_site_id
                   AND hcar.role_type = 'CONTACT'
                   AND cust.orig_system_reference =
                       TO_CHAR (p_orig_system_customer_ref)
                   AND hcas.orig_system_reference =
                       TO_CHAR (p_orig_system_address_ref)
                   AND hoc.orig_system_reference =
                       TO_CHAR (p_orig_system_contact_ref);

        TYPE lt_contacts_typ IS TABLE OF cur_contacts%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_contacts_data           lt_contacts_typ;
        ln_org_contact_ovn         NUMBER;
        ln_rel_ovn                 NUMBER;
        ln_party_ovn               NUMBER;
        ln_contact_person_ovn      NUMBER;
        ln_profile_id              NUMBER;
        ln_cust_account_role_ovn   NUMBER;
        lr_party_rec               hz_party_v2pub.party_rec_type;
        lr_person_rec              hz_party_v2pub.person_rec_type;
        lr_org_contact_rec         hz_party_contact_v2pub.org_contact_rec_type;
        lr_cust_account_role_rec   hz_cust_account_role_v2pub.cust_account_role_rec_type;
        lc_return_status           VARCHAR2 (10);
        ln_msg_count               NUMBER;
        ln_msg_index_num           NUMBER;
        lc_msg_data                VARCHAR2 (4000);
        lc_data                    VARCHAR2 (4000);
        lc_error_message           VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'update_cust_contacts');

        OPEN cur_contacts;

        LOOP
            FETCH cur_contacts BULK COLLECT INTO lt_contacts_data LIMIT 1000;

            EXIT WHEN lt_contacts_data.COUNT = 0;

            FOR xc_contacts_idx IN lt_contacts_data.FIRST ..
                                   lt_contacts_data.LAST
            LOOP
                log_records (gc_debug_flag,
                             '************************************');
                log_records (
                    gc_debug_flag,
                       'customer_id : '
                    || lt_contacts_data (xc_contacts_idx).orig_system_customer_ref);
                log_records (
                    gc_debug_flag,
                       'contact_id : '
                    || lt_contacts_data (xc_contacts_idx).orig_system_contact_ref);

                FOR lcu_contact_roles
                    IN cur_contact_roles (
                           p_orig_system_customer_ref   =>
                               lt_contacts_data (xc_contacts_idx).orig_system_customer_ref,
                           p_orig_system_address_ref   =>
                               lt_contacts_data (xc_contacts_idx).orig_system_address_ref,
                           p_orig_system_contact_ref   =>
                               lt_contacts_data (xc_contacts_idx).orig_system_contact_ref)
                LOOP
                    ln_profile_id                                   := NULL;
                    lr_person_rec                                   := NULL;
                    lr_party_rec                                    := NULL;
                    lr_org_contact_rec                              := NULL;
                    lr_cust_account_role_rec                        := NULL;
                    ln_org_contact_ovn                              :=
                        lcu_contact_roles.org_contact_ovn;
                    ln_rel_ovn                                      := lcu_contact_roles.rel_ovn;
                    ln_party_ovn                                    := lcu_contact_roles.party_ovn;
                    ln_contact_person_ovn                           :=
                        lcu_contact_roles.contact_person_ovn;
                    ln_cust_account_role_ovn                        :=
                        lcu_contact_roles.cust_account_role_ovn;

                    lr_party_rec.party_id                           :=
                        lcu_contact_roles.contact_person_id;
                    lr_person_rec.person_pre_name_adjunct           :=
                        lt_contacts_data (xc_contacts_idx).contact_title;
                    lr_person_rec.person_first_name                 :=
                        INITCAP (
                            lt_contacts_data (xc_contacts_idx).contact_first_name);
                    lr_person_rec.person_last_name                  :=
                        INITCAP (
                            lt_contacts_data (xc_contacts_idx).contact_last_name);
                    lr_person_rec.party_rec                         := lr_party_rec;

                    ln_msg_count                                    := 0;
                    lc_msg_data                                     := NULL;
                    lc_return_status                                := NULL;
                    lc_data                                         := NULL;
                    lc_error_message                                := NULL;

                    fnd_msg_pub.initialize;
                    log_records (gc_debug_flag, 'Call update_person API');

                    hz_party_v2pub.update_person (p_init_msg_list => gc_init_msg_list, p_person_rec => lr_person_rec, p_party_object_version_number => ln_contact_person_ovn, x_profile_id => ln_profile_id, x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                                  , x_msg_data => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (gc_debug_flag,
                                         'update_person API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;
                    END IF;


                    lr_org_contact_rec.org_contact_id               :=
                        lcu_contact_roles.org_contact_id;
                    lr_org_contact_rec.attribute_category           :=
                        lt_contacts_data (xc_contacts_idx).contact_attribute_category;
                    lr_org_contact_rec.job_title                    :=
                        lt_contacts_data (xc_contacts_idx).job_title;

                    ln_msg_count                                    := 0;
                    lc_msg_data                                     := NULL;
                    lc_return_status                                := NULL;
                    lc_data                                         := NULL;
                    lc_error_message                                := NULL;

                    fnd_msg_pub.initialize;
                    log_records (gc_debug_flag,
                                 'Call update_org_contact API');

                    hz_party_contact_v2pub.update_org_contact (
                        p_init_msg_list                 => gc_init_msg_list,
                        p_org_contact_rec               => lr_org_contact_rec,
                        p_cont_object_version_number    => ln_org_contact_ovn,
                        p_rel_object_version_number     => ln_rel_ovn,
                        p_party_object_version_number   => ln_party_ovn,
                        x_return_status                 => lc_return_status,
                        x_msg_count                     => ln_msg_count,
                        x_msg_data                      => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (gc_debug_flag,
                                         'update_org_contact API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;
                    END IF;

                    lr_cust_account_role_rec.cust_account_role_id   :=
                        lcu_contact_roles.cust_account_role_id;
                    lr_cust_account_role_rec.status                 :=
                        lt_contacts_data (xc_contacts_idx).cont_status;

                    ln_msg_count                                    := 0;
                    lc_msg_data                                     := NULL;
                    lc_return_status                                := NULL;
                    lc_data                                         := NULL;
                    lc_error_message                                := NULL;

                    fnd_msg_pub.initialize;
                    log_records (gc_debug_flag,
                                 'Call update_cust_account_role API');

                    hz_cust_account_role_v2pub.update_cust_account_role (
                        p_init_msg_list           => gc_init_msg_list,
                        p_cust_account_role_rec   => lr_cust_account_role_rec,
                        p_object_version_number   => ln_cust_account_role_ovn,
                        x_return_status           => lc_return_status,
                        x_msg_count               => ln_msg_count,
                        x_msg_data                => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (
                                gc_debug_flag,
                                'update_cust_account_role API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_contact_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref
                               AND orig_system_contact_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_contact_ref;
                    ELSE
                        UPDATE xxd_ar_contact_upd_stg_t
                           SET record_status   = gc_process_status
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref
                               AND orig_system_contact_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_contact_ref;
                    END IF;
                END LOOP;
            END LOOP;

            COMMIT;
        END LOOP;

        CLOSE cur_contacts;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Un-expecetd Error in  update_cust_contacts => '
                    || SQLERRM);
            ROLLBACK;
    END update_cust_contacts;

    /*****************************************************************************************
     *  Procedure Name :   UPDATE_CONTACT_POINTS                                             *
     *                                                                                       *
     *  Description    :   This Procedure will update the customer contact point data        *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_debug                  IN       Debug Y/N                                          *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/
    PROCEDURE update_contact_points (p_debug IN VARCHAR2 DEFAULT gc_no_flag)
    AS
        CURSOR cur_contacts IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_ar_cont_point_upd_stg_t xcp
             WHERE record_status = gc_validate_status;

        CURSOR cur_contact_points (p_orig_system_customer_ref VARCHAR2, p_orig_system_address_ref VARCHAR2, p_orig_system_contact_ref VARCHAR2
                                   , p_orig_system_telephone_ref VARCHAR2)
        IS
            SELECT hcp.contact_point_id, hcp.object_version_number
              FROM hz_parties hp, hz_relationships hr, hz_contact_points hcp,
                   hz_parties h_contact, hz_cust_accounts cust, hz_org_contacts hoc
             WHERE     hr.subject_id = h_contact.party_id
                   AND hr.object_id = hp.party_id
                   AND cust.party_id = hp.party_id
                   AND hoc.party_relationship_id = hr.relationship_id
                   AND hr.subject_type = 'PERSON'
                   AND hcp.owner_table_id = hr.party_id
                   AND hcp.owner_table_name = 'HZ_PARTIES'
                   AND cust.orig_system_reference =
                       TO_CHAR (p_orig_system_customer_ref)
                   AND hoc.orig_system_reference =
                       TO_CHAR (p_orig_system_contact_ref)
                   AND hcp.orig_system_reference =
                       TO_CHAR (p_orig_system_telephone_ref)
            UNION
            SELECT hcp.contact_point_id, hcp.object_version_number
              FROM hz_parties hp, hz_contact_points hcp, hz_cust_accounts cust
             WHERE     cust.party_id = hp.party_id
                   AND hcp.owner_table_id = hp.party_id
                   AND hcp.owner_table_name = 'HZ_PARTIES'
                   AND cust.orig_system_reference =
                       TO_CHAR (p_orig_system_customer_ref)
                   AND hcp.orig_system_reference =
                       TO_CHAR (p_orig_system_telephone_ref)
            UNION
            SELECT hcp.contact_point_id, hcp.object_version_number
              FROM hz_parties hp, hz_contact_points hcp, hz_cust_accounts cust,
                   hz_cust_acct_sites_all hcas, hz_party_sites hps
             WHERE     cust.party_id = hp.party_id
                   AND hp.party_id = hps.party_id
                   AND hcas.party_site_id = hps.party_site_id
                   AND cust.cust_account_id = hcas.cust_account_id
                   AND hcp.owner_table_name = 'HZ_PARTY_SITES'
                   AND hcp.owner_table_id = hps.party_site_id
                   AND cust.orig_system_reference =
                       TO_CHAR (p_orig_system_customer_ref)
                   AND hcas.orig_system_reference =
                       TO_CHAR (p_orig_system_address_ref)
                   AND hcp.orig_system_reference =
                       TO_CHAR (p_orig_system_telephone_ref)
            UNION
            SELECT hcp.contact_point_id, hcp.object_version_number
              FROM hz_parties hp, hz_contact_points hcp, hz_cust_accounts cust,
                   hz_cust_acct_sites_all hcas, hz_party_sites hps
             WHERE     cust.party_id = hp.party_id
                   AND hp.party_id = hps.party_id
                   AND hcas.party_site_id = hps.party_site_id
                   AND cust.cust_account_id = hcas.cust_account_id
                   AND hcp.owner_table_name = 'HZ_PARTY_SITES'
                   AND hcp.owner_table_id = hps.party_site_id
                   AND cust.orig_system_reference =
                       TO_CHAR (p_orig_system_customer_ref)
                   AND hcp.orig_system_reference =
                       TO_CHAR (p_orig_system_telephone_ref);

        TYPE lt_contacts_typ IS TABLE OF cur_contacts%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_contacts_data       lt_contacts_typ;

        ln_contact_point_ovn   NUMBER;
        lr_contact_point_rec   hz_contact_point_v2pub.contact_point_rec_type;
        lr_edi_rec             hz_contact_point_v2pub.edi_rec_type;
        lr_phone_rec           hz_contact_point_v2pub.phone_rec_type;
        lr_email_rec           hz_contact_point_v2pub.email_rec_type;
        lr_telex_rec           hz_contact_point_v2pub.telex_rec_type;
        lr_web_rec             hz_contact_point_v2pub.web_rec_type;
        lc_return_status       VARCHAR2 (10);
        ln_msg_count           NUMBER;
        ln_msg_index_num       NUMBER;
        lc_msg_data            VARCHAR2 (4000);
        lc_data                VARCHAR2 (4000);
        lc_error_message       VARCHAR2 (4000);
    BEGIN
        log_records (p_debug, 'update_contact_points');

        OPEN cur_contacts;

        LOOP
            FETCH cur_contacts BULK COLLECT INTO lt_contacts_data LIMIT 1000;

            EXIT WHEN lt_contacts_data.COUNT = 0;

            FOR xc_contacts_idx IN lt_contacts_data.FIRST ..
                                   lt_contacts_data.LAST
            LOOP
                log_records (gc_debug_flag,
                             '************************************');
                log_records (
                    gc_debug_flag,
                       'customer_id : '
                    || lt_contacts_data (xc_contacts_idx).orig_system_customer_ref);
                log_records (
                    gc_debug_flag,
                       'contact_id : '
                    || lt_contacts_data (xc_contacts_idx).orig_system_contact_ref);
                log_records (
                    gc_debug_flag,
                       'address_id : '
                    || lt_contacts_data (xc_contacts_idx).orig_system_address_ref);
                log_records (
                    gc_debug_flag,
                       'phone_id : '
                    || lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref);

                FOR lcu_contact_points
                    IN cur_contact_points (
                           p_orig_system_customer_ref   =>
                               lt_contacts_data (xc_contacts_idx).orig_system_customer_ref,
                           p_orig_system_address_ref   =>
                               lt_contacts_data (xc_contacts_idx).orig_system_address_ref,
                           p_orig_system_contact_ref   =>
                               lt_contacts_data (xc_contacts_idx).orig_system_contact_ref,
                           p_orig_system_telephone_ref   =>
                               lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref)
                LOOP
                    ln_contact_point_ovn                         := NULL;
                    lr_contact_point_rec                         := NULL;
                    lr_phone_rec                                 := NULL;
                    lr_email_rec                                 := NULL;
                    lr_web_rec                                   := NULL;
                    lr_edi_rec                                   := NULL;
                    lr_telex_rec                                 := NULL;

                    ln_contact_point_ovn                         :=
                        lcu_contact_points.object_version_number;
                    lr_contact_point_rec.contact_point_id        :=
                        lcu_contact_points.contact_point_id;
                    lr_contact_point_rec.contact_point_type      :=
                        lt_contacts_data (xc_contacts_idx).contact_point_type;
                    lr_contact_point_rec.primary_by_purpose      :=
                        lt_contacts_data (xc_contacts_idx).primary_by_purpose;
                    lr_contact_point_rec.contact_point_purpose   :=
                        lt_contacts_data (xc_contacts_idx).contact_point_purpose;
                    lr_contact_point_rec.status                  :=
                        lt_contacts_data (xc_contacts_idx).cont_point_status;
                    lr_email_rec.email_format                    :=
                        lt_contacts_data (xc_contacts_idx).email_format;
                    lr_email_rec.email_address                   :=
                        lt_contacts_data (xc_contacts_idx).email_address;
                    lr_phone_rec.phone_number                    :=
                        lt_contacts_data (xc_contacts_idx).telephone;
                    lr_phone_rec.phone_line_type                 :=
                        lt_contacts_data (xc_contacts_idx).telephone_type;
                    lr_phone_rec.phone_area_code                 :=
                        lt_contacts_data (xc_contacts_idx).telephone_area_code;
                    lr_phone_rec.phone_country_code              :=
                        lt_contacts_data (xc_contacts_idx).phone_country_code;
                    lr_phone_rec.phone_extension                 :=
                        lt_contacts_data (xc_contacts_idx).telephone_extension;

                    IF lt_contacts_data (xc_contacts_idx).url IS NOT NULL
                    THEN
                        lr_web_rec.web_type   := 'HTTP';
                        lr_web_rec.url        :=
                            lt_contacts_data (xc_contacts_idx).url;
                    ELSE
                        lr_web_rec.web_type   := NULL;
                        lr_web_rec.url        := NULL;
                    END IF;

                    ln_msg_count                                 := 0;
                    lc_msg_data                                  := NULL;
                    lc_return_status                             := NULL;
                    lc_data                                      := NULL;
                    lc_error_message                             := NULL;

                    fnd_msg_pub.initialize;
                    log_records (gc_debug_flag,
                                 'Call update_contact_point API');

                    hz_contact_point_v2pub.update_contact_point (
                        p_init_msg_list           => gc_init_msg_list,
                        p_contact_point_rec       => lr_contact_point_rec,
                        p_edi_rec                 => lr_edi_rec,
                        p_email_rec               => lr_email_rec,
                        p_phone_rec               => lr_phone_rec,
                        p_telex_rec               => lr_telex_rec,
                        p_web_rec                 => lr_web_rec,
                        p_object_version_number   => ln_contact_point_ovn,
                        x_return_status           => lc_return_status,
                        x_msg_count               => ln_msg_count,
                        x_msg_data                => lc_msg_data);

                    log_records (gc_debug_flag,
                                 'Return Status : ' || lc_return_status);

                    IF lc_return_status <> 'S'
                    THEN
                        IF ln_msg_count > 0
                        THEN
                            log_records (gc_debug_flag,
                                         'update_contact_point API failed');

                            FOR i IN 1 .. ln_msg_count
                            LOOP
                                fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => 'F',
                                    p_data            => lc_data,
                                    p_msg_index_out   => ln_msg_index_num);
                                log_records (gc_debug_flag,
                                             'lc_data: ' || lc_data);

                                lc_error_message   :=
                                    SUBSTR (
                                           lc_error_message
                                        || i
                                        || '. '
                                        || lc_data
                                        || '; ',
                                        1,
                                        4000);
                            END LOOP;
                        END IF;

                        UPDATE xxd_ar_cont_point_upd_stg_t
                           SET record_status = gc_error_status, error_message = lc_error_message
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref
                               AND orig_system_telephone_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref;
                    ELSE
                        UPDATE xxd_ar_cont_point_upd_stg_t
                           SET record_status   = gc_process_status
                         WHERE     orig_system_customer_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_customer_ref
                               AND orig_system_telephone_ref =
                                   lt_contacts_data (xc_contacts_idx).orig_system_telephone_ref;
                    END IF;
                END LOOP;
            END LOOP;

            COMMIT;
        END LOOP;

        CLOSE cur_contacts;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            log_records (
                p_debug   => gc_debug_flag,
                p_message   =>
                       'Un-expecetd Error in  update_contact_points => '
                    || SQLERRM);
            ROLLBACK;
    END update_contact_points;

    /*****************************************************************************************
     *  Procedure Name :   CUSTOMER_VALIDATION_MAIN                                          *
     *                                                                                       *
     *  Description    :   Procedure to validate the customer data in the staging table      *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/

    PROCEDURE customer_validation_main (x_retcode   OUT NUMBER,
                                        x_errbuf    OUT VARCHAR2)
    AS
        ln_count          NUMBER := 0;
        l_target_org_id   NUMBER := 0;
    BEGIN
        x_retcode   := NULL;
        x_errbuf    := NULL;

        log_records (gc_debug_flag, 'validate Customer');
        validate_customer (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'validate Customer Sites');
        validate_cust_sites (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'validate Customer Site uses');
        validate_cust_sites_use (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'validate Customer contacts');
        validate_cust_contacts (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'validate Customer contact points');
        validate_contact_points (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'validate Customer profile');
        validate_cust_profile (p_debug => gc_debug_flag);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_retcode   := 1;
            x_errbuf    := x_errbuf || SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Raised During Customer Validation Program');
            x_retcode   := 1;
            x_errbuf    := x_errbuf || SQLERRM;
    END customer_validation_main;


    /*****************************************************************************************
     *  Procedure Name :   CUSTOMER_UPDATE_MAIN                                              *
     *                                                                                       *
     *  Description    :   Procedure to update the customer data in the base table           *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
     *****************************************************************************************/

    PROCEDURE customer_update_main (x_retcode   OUT NUMBER,
                                    x_errbuf    OUT VARCHAR2)
    AS
        ln_count   NUMBER := 0;
    BEGIN
        x_retcode   := NULL;
        x_errbuf    := NULL;

        log_records (gc_debug_flag, 'Update Customer');
        update_customer (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'Update Customer Sites');
        update_cust_sites (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'Update Customer Site uses');
        update_cust_sites_use (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'Update Customer profile');
        update_cust_profile (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'Update Customer profile amount');
        update_cust_profile_amt (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'Update Customer contacts');
        update_cust_contacts (p_debug => gc_debug_flag);

        log_records (gc_debug_flag, 'Update Customer contact points');
        update_contact_points (p_debug => gc_debug_flag);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_retcode   := 1;
            x_errbuf    := x_errbuf || SQLERRM;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception Raised During Customer Update Program');
            x_retcode   := 1;
            x_errbuf    := x_errbuf || SQLERRM;
    END customer_update_main;

    PROCEDURE extract_1206_data (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
        procedure_name   CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage            VARCHAR2 (50) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;

        CURSOR lcu_extract_count IS
            SELECT COUNT (*)
              FROM xxd_ar_customer_upd_stg_t
             WHERE record_status = gc_new_status;

        CURSOR lcu_customer_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_customer_1206_upd_t xaci;

        CURSOR lcu_cust_site_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_cust_sites_1206_upd_t xacs;

        CURSOR lcu_cust_site_use_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_site_use_1206_upd_t xcsu;

        CURSOR lcu_cust_cont_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_contact_1206_upd_t xcc;

        CURSOR lcu_cust_cont_point_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   *
              FROM xxd_conv.xxd_ar_cont_point_1206_upd_t xcc;

        CURSOR lcu_cust_prof_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   acpv.*
              FROM xxd_conv.xxd_ar_cust_prof_1206_upd_t acpv;

        CURSOR lcu_cust_prof_amt_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   xcpa.*
              FROM xxd_conv.xxd_ar_cust_profamt_1206_upd_t xcpa;
    BEGIN
        gtt_ar_cust_int_tab.delete;
        gtt_ar_cust_site_int_tab.delete;
        gtt_ar_cust_site_use_int_tab.delete;
        gtt_ar_cust_prof_int_tab.delete;
        gtt_ar_cust_prof_amt_int_tab.delete;
        gtt_ar_cust_cont_int_tab.delete;
        gtt_ar_cust_cont_point_int_tab.delete;


        --Inserting Customer Data
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
                gtt_ar_cust_int_tab (cust_idx).target_org   :=
                    get_org_id (
                        gtt_ar_cust_int_tab (cust_idx).source_org_name);
            END LOOP;

            FORALL i IN 1 .. gtt_ar_cust_int_tab.COUNT
                INSERT INTO xxd_ar_customer_upd_stg_t
                     VALUES gtt_ar_cust_int_tab (i);

            gtt_ar_cust_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_customer_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_customer_data;

        --Inserting Customer Site Data
        OPEN lcu_cust_site_data;

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
                INSERT INTO xxd_ar_cust_sites_upd_stg_t
                     VALUES gtt_ar_cust_site_int_tab (i);

            COMMIT;
            EXIT WHEN lcu_cust_site_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_site_data;

        --Inserting Customer Site Use Data
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
                INSERT INTO xxd_conv.xxd_ar_cust_siteuse_upd_stg_t
                     VALUES gtt_ar_cust_site_use_int_tab (i);

            gtt_ar_cust_site_use_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_site_use_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_site_use_data;

        --Inserting Customer Profiles Data
        OPEN lcu_cust_prof_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Profiles Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_prof_int_tab.delete;

            FETCH lcu_cust_prof_data
                BULK COLLECT INTO gtt_ar_cust_prof_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_ar_cust_prof_int_tab.COUNT
                INSERT INTO xxd_ar_cust_prof_upd_stg_t
                     VALUES gtt_ar_cust_prof_int_tab (i);

            gtt_ar_cust_prof_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_prof_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_prof_data;

        --Inserting Customer Profiles Amount Data
        OPEN lcu_cust_prof_amt_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Profiles Amount Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_prof_amt_int_tab.delete;

            FETCH lcu_cust_prof_amt_data
                BULK COLLECT INTO gtt_ar_cust_prof_amt_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_ar_cust_prof_amt_int_tab.COUNT
                INSERT INTO xxd_ar_cust_profamt_upd_stg_t
                     VALUES gtt_ar_cust_prof_amt_int_tab (i);

            gtt_ar_cust_prof_amt_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_prof_amt_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_prof_amt_data;

        --Inserting Customer Contact Data
        OPEN lcu_cust_cont_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Contact Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_cont_int_tab.delete;

            FETCH lcu_cust_cont_data
                BULK COLLECT INTO gtt_ar_cust_cont_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_ar_cust_cont_int_tab.COUNT
                INSERT INTO xxd_ar_contact_upd_stg_t
                     VALUES gtt_ar_cust_cont_int_tab (i);

            gtt_ar_cust_cont_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_cont_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_cont_data;

        --Inserting Customer Contact Point Data
        OPEN lcu_cust_cont_point_data;

        LOOP
            lv_error_stage   := 'Inserting Customer Contact Point Data';
            fnd_file.put_line (fnd_file.LOG, lv_error_stage);
            gtt_ar_cust_cont_point_int_tab.delete;

            FETCH lcu_cust_cont_point_data
                BULK COLLECT INTO gtt_ar_cust_cont_point_int_tab
                LIMIT 5000;

            FORALL i IN 1 .. gtt_ar_cust_cont_point_int_tab.COUNT
                INSERT INTO xxd_ar_cont_point_upd_stg_t
                     VALUES gtt_ar_cust_cont_point_int_tab (i);

            gtt_ar_cust_cont_point_int_tab.delete;
            COMMIT;
            EXIT WHEN lcu_cust_cont_point_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_cust_cont_point_data;

        BEGIN
            fnd_stats.gather_table_stats (
                UPPER ('XXD_CONV'),
                UPPER ('XXD_AR_CUSTOMER_UPD_STG_T'));
            fnd_stats.gather_table_stats (
                UPPER ('XXD_CONV'),
                UPPER ('XXD_AR_CUST_SITES_UPD_STG_T'));
            fnd_stats.gather_table_stats (
                UPPER ('XXD_CONV'),
                UPPER ('XXD_AR_CUST_SITEUSE_UPD_STG_T'));
            fnd_stats.gather_table_stats (
                UPPER ('XXD_CONV'),
                UPPER ('XXD_AR_CUST_PROF_UPD_STG_T'));
            fnd_stats.gather_table_stats (
                UPPER ('XXD_CONV'),
                UPPER ('XXD_AR_CUST_PROFAMT_UPD_STG_T'));
            fnd_stats.gather_table_stats (UPPER ('XXD_CONV'),
                                          UPPER ('XXD_AR_CONTACT_UPD_STG_T'));
            fnd_stats.gather_table_stats (
                UPPER ('XXD_CONV'),
                UPPER ('XXD_AR_CONT_POINT_UPD_STG_T'));
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;
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

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUSTOMER_UPD_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUST_SITES_UPD_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUST_SITEUSE_UPD_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUST_PROF_UPD_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CUST_PROFAMT_UPD_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CONTACT_UPD_STG_T';

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_AR_CONT_POINT_UPD_STG_T';

        fnd_file.put_line (fnd_file.LOG, 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_mesg   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Truncate Stage Table Exception t' || x_return_mesg);
            xxd_common_utils.record_error ('AR', gn_org_id, 'Deckers AR Customer Update Program', SQLERRM, DBMS_UTILITY.format_error_backtrace, gn_user_id, gn_conc_request_id, 'truncte_stage_tables', NULL
                                           , x_return_mesg);
    END truncte_stage_tables;

    /*****************************************************************************************
     * Procedure: main_prc
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
     *****************************************************************************************/

    PROCEDURE main_prc (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                        , p_debug_flag IN VARCHAR2)
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

            truncte_stage_tables (x_ret_code      => x_retcode,
                                  x_return_mesg   => x_errbuf);
            extract_1206_data (x_errbuf => x_errbuf, x_retcode => x_retcode);
        ELSIF p_process = gc_validate_only
        THEN
            customer_validation_main (x_errbuf    => x_errbuf,
                                      x_retcode   => x_retcode);
        ELSIF p_process = gc_load_only
        THEN
            customer_update_main (x_errbuf => x_errbuf, x_retcode => x_retcode);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Code Pointer: ' || gc_code_pointer);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in customer_update_main_prc '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 1;
            x_errbuf    :=
                'Error Message main_prc ' || SUBSTR (SQLERRM, 1, 250);
    END main_prc;
END xxd_customer_update_pkg;
/
