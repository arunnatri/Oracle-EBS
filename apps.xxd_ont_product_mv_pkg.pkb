--
-- XXD_ONT_PRODUCT_MV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_PRODUCT_MV_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_PRODUCT_MV_PKG
    -- Design       : This package will be used to fetch values required for LOV
    --                in the product move tool. This package will also  search
    --                for order details based on user entered data.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name               Ver    Description
    -- ----------      --------------    -----  ------------------
    -- 23-Feb-2021   Infosys              1.0    Initial Version
    -- 26-May-2021   Infosys              1.1    Created a procedure to fetch username and id
    -- 03-Jun-2021   Infosys              1.2    modified for cancel date
    -- 04-Jun-2021   Infosys              1.3    modified for source type and order type exclusion
    -- 09-Jun-2021   Infosys              1.4    modified for brand query fix
    -- 18-Jun-2021   Infosys              1.5    modified for internal source readonly and lock issue
    -- 21-Jun-2021   Infosys              1.6    modified for parallel_processing, order by,lock at batch level
    -- #########################################################################################################################

    PROCEDURE write_to_table (msg VARCHAR2, app VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO custom.do_debug (created_by, application_id, debug_text,
                                     session_id, call_stack)
                 VALUES (NVL (fnd_global.user_id, -1),
                         app,
                         msg,
                         USERENV ('SESSIONID'),
                         SUBSTR (DBMS_UTILITY.format_call_stack, 1, 2000));

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END write_to_table;

    PROCEDURE fetch_user_name (p_in_user_email_id   IN     VARCHAR2,
                               p_out_user_name         OUT VARCHAR2)
    IS
        lv_user_name   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT fu.user_name
              INTO lv_user_name
              FROM per_people_f hr, fnd_user fu
             WHERE     fu.employee_id = hr.person_id
                   AND UPPER (hr.email_address) = UPPER (p_in_user_email_id)
                   AND NVL (hr.effective_start_date, SYSDATE - 1) < SYSDATE
                   AND NVL (hr.effective_end_date, SYSDATE + 1) > SYSDATE
                   AND NVL (fu.start_date, SYSDATE - 1) < SYSDATE
                   AND NVL (fu.end_date, SYSDATE + 1) > SYSDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_user_name   := NULL;
                write_to_table (
                       'User '
                    || p_in_user_email_id
                    || ' does not exist in Oracle',
                    'XXD_ONT_PRODUCT_MV_PKG.fetch_user_name');
            WHEN TOO_MANY_ROWS
            THEN
                lv_user_name   := NULL;
                write_to_table (
                    'More than one user name exists for the email id',
                    'XXD_ONT_PRODUCT_MV_PKG.fetch_user_name');
            WHEN OTHERS
            THEN
                lv_user_name   := NULL;
                write_to_table ('User validation failed',
                                'XXD_ONT_PRODUCT_MV_PKG.fetch_user_name');
        END;

        IF lv_user_name IS NULL
        THEN
            BEGIN
                SELECT fu.user_name
                  INTO lv_user_name
                  FROM fnd_user fu
                 WHERE     UPPER (fu.email_address) =
                           UPPER (p_in_user_email_id)
                       AND NVL (fu.start_date, SYSDATE - 1) < SYSDATE
                       AND NVL (fu.end_date, SYSDATE + 1) > SYSDATE;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_user_name   := NULL;
                    write_to_table (
                           'User '
                        || p_in_user_email_id
                        || ' does not exist in Oracle',
                        'XXD_ONT_PRODUCT_MV_PKG.fetch_user_name');
                WHEN TOO_MANY_ROWS
                THEN
                    lv_user_name   := NULL;
                    write_to_table (
                        'More than one user name exists for the email id',
                        'XXD_ONT_PRODUCT_MV_PKG.fetch_user_name');
                WHEN OTHERS
                THEN
                    lv_user_name   := NULL;
                    write_to_table ('User validation failed',
                                    'XXD_ONT_PRODUCT_MV_PKG.fetch_user_name');
            END;
        END IF;

        p_out_user_name   := lv_user_name;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            p_out_user_name   := NULL;
            write_to_table (
                'User ' || p_in_user_email_id || ' does not exist in Oracle',
                'XXD_ONT_PRODUCT_MV_PKG.fetch_user_name');
        WHEN OTHERS
        THEN
            p_out_user_name   := NULL;
            write_to_table ('User validation failed',
                            'XXD_ONT_PRODUCT_MV_PKG.fetch_user_name');
    END fetch_user_name;

    PROCEDURE fetch_user_id (p_in_user_name   IN     VARCHAR2,
                             p_out_user_id       OUT NUMBER)
    IS
    BEGIN
        SELECT fu.user_id
          INTO p_out_user_id
          FROM fnd_user fu
         WHERE     UPPER (fu.user_name) = UPPER (p_in_user_name)
               AND NVL (fu.start_date, SYSDATE - 1) < SYSDATE
               AND NVL (fu.end_date, SYSDATE + 1) > SYSDATE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            p_out_user_id   := NULL;
            write_to_table (
                'User ' || p_in_user_name || ' does not exist in Oracle',
                'XXD_ONT_PRODUCT_MV_PKG.fetch_user_id');
        WHEN OTHERS
        THEN
            p_out_user_id   := NULL;
            write_to_table ('User validation failed',
                            'XXD_ONT_PRODUCT_MV_PKG.fetch_user_id');
    END fetch_user_id;

    /************Start modification for version 1.1 ****************/
    /*FUNCTION fetch_ad_user_name (p_in_user_email IN VARCHAR2)
        RETURN VARCHAR2
    IS
     lv_query   VARCHAR2(2000);
     lv_user_name   VARCHAR2(100);

    BEGIN
      lv_query := 'SELECT val
         FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(mail='||p_in_user_email||'))'')) a
           WHERE UPPER(a.attr) = UPPER(''sAMAccountName'')';

      EXECUTE IMMEDIATE lv_query INTO lv_user_name;
         RETURN lv_user_name;
    EXCEPTION
    WHEN NO_DATA_FOUND
    THEN
       lv_user_name:='';
       RETURN lv_user_name;
    WHEN OTHERS
    THEN
       lv_user_name:='';
       RETURN lv_user_name;
    END fetch_ad_user_name;*/

    PROCEDURE fetch_ad_user_name (p_in_user_email IN VARCHAR2, p_out_user_name OUT VARCHAR2, p_out_user_id OUT NUMBER)
    IS
        lv_query            VARCHAR2 (2000);
        lv_query1           VARCHAR2 (2000);
        lv_user_name        VARCHAR2 (100);
        lv_disp_name        VARCHAR2 (100);
        ln_user_id          NUMBER;
        lv_user_exception   EXCEPTION;
    BEGIN
        lv_query          :=
               'SELECT val  
					FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(mail='
            || p_in_user_email
            || '))'')) a  
				   WHERE UPPER(a.attr) = UPPER(''displayName'')';

        EXECUTE IMMEDIATE lv_query
            INTO lv_disp_name;

        lv_query1         :=
               'SELECT val  
					FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(mail='
            || p_in_user_email
            || '))'')) a  
				   WHERE UPPER(a.attr) = UPPER(''sAMAccountName'')';

        EXECUTE IMMEDIATE lv_query1
            INTO lv_user_name;

        BEGIN
            fetch_user_id (p_in_user_name   => lv_user_name,
                           p_out_user_id    => ln_user_id);

            IF ln_user_id IS NULL
            THEN
                RAISE lv_user_exception;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE lv_user_exception;
        END;

        p_out_user_id     := ln_user_id;
        p_out_user_name   := lv_disp_name;
    EXCEPTION
        WHEN lv_user_exception
        THEN
            -- lv_user_name:='';
            ln_user_id   := NULL;
        WHEN NO_DATA_FOUND
        THEN
            lv_user_name   := '';
            ln_user_id     := NULL;
        WHEN OTHERS
        THEN
            lv_user_name   := '';
            ln_user_id     := NULL;
    END fetch_ad_user_name;

    PROCEDURE fetch_ad_user_email (p_in_user_id IN VARCHAR2, p_out_user_name OUT VARCHAR2, p_out_display_name OUT VARCHAR2
                                   , p_out_email_id OUT VARCHAR2)
    IS
        lv_query          VARCHAR2 (2000);
        lv_query1         VARCHAR2 (2000);
        lv_user_name      VARCHAR2 (100);
        lv_display_name   VARCHAR2 (100);
        lv_email          VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT fu.user_name
              INTO lv_user_name
              FROM fnd_user fu
             WHERE     UPPER (fu.user_id) = UPPER (p_in_user_id)
                   AND NVL (fu.start_date, SYSDATE - 1) < SYSDATE
                   AND NVL (fu.end_date, SYSDATE + 1) > SYSDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_user_name   := NULL;
                write_to_table (
                    'User ' || p_in_user_id || ' does not exist in Oracle',
                    'XXD_ONT_PRODUCT_MV_PKG.fetch_ad_user_email');
            WHEN TOO_MANY_ROWS
            THEN
                lv_user_name   := NULL;
                write_to_table (
                    'More than one user name exists for the email id',
                    'XXD_ONT_PRODUCT_MV_PKG.fetch_ad_user_email');
            WHEN OTHERS
            THEN
                lv_user_name   := NULL;
                write_to_table ('User validation failed',
                                'XXD_ONT_PRODUCT_MV_PKG.fetch_ad_user_email');
        END;

        IF lv_user_name IS NOT NULL
        THEN
            lv_query   :=
                   'SELECT val  
						FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(sAMAccountName='
                || lv_user_name
                || '))'')) a  
					   WHERE UPPER(a.attr) = UPPER(''mail'')';

            EXECUTE IMMEDIATE lv_query
                INTO lv_email;

            lv_query1   :=
                   'SELECT val  
						FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(sAMAccountName='
                || lv_user_name
                || '))'')) a  
					   WHERE UPPER(a.attr) = UPPER(''displayName'')';

            EXECUTE IMMEDIATE lv_query1
                INTO lv_display_name;
        END IF;

        p_out_email_id       := lv_email;
        p_out_user_name      := lv_user_name;
        p_out_display_name   := lv_display_name;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lv_user_name   := '';
        WHEN OTHERS
        THEN
            lv_user_name   := '';
    END fetch_ad_user_email;

    /************End modification for version 1.1 ****************/

    FUNCTION user_access (p_in_user_name IN VARCHAR2, p_in_segment_name IN VARCHAR2, p_in_segment_value IN VARCHAR2
                          , p_in_instance_name IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_user_access   VARCHAR2 (10);
        lv_query         VARCHAR2 (2000);
    BEGIN
        lv_query   :=
               'SELECT ''Y''  
					FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(sAMAccountName='
            || p_in_user_name
            || '))'')) a 
					CROSS JOIN TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(sAMAccountName='
            || p_in_user_name
            || '))'')) b 
					,xxdo.XXD_LDAP_SECURITY_MASTER_T xopsmt
					WHERE UPPER(a.attr) = UPPER(''sAMAccountName'')
					AND UPPER(b.attr) = UPPER(''memberOf'')
					AND UPPER(b.val) LIKE UPPER(''%ORA_PMT_%'')
					AND xopsmt.AD_SECURITY_OBJ_NAME = SUBSTR(b.val,4,INSTR(b.val,''OU'',1,1)-5)
					AND AD_SECURITY_SEG_NAME ='''
            || p_in_segment_name
            || ''' AND instance_name ='''
            || p_in_instance_name
            || ''' AND AD_SECURITY_SEG_VALUE ='''
            || p_in_segment_value
            || '''';


        EXECUTE IMMEDIATE lv_query
            INTO lv_user_access;

        RETURN lv_user_access;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lv_user_access   := 'N';
            RETURN lv_user_access;
        WHEN OTHERS
        THEN
            lv_user_access   := 'N';
            RETURN lv_user_access;
    END user_access;

    PROCEDURE search_results (p_in_user_id IN NUMBER, p_in_warehouse IN VARCHAR2, p_in_style_color IN VARCHAR2, p_in_instance_name IN VARCHAR2, p_out_results OUT SYS_REFCURSOR, p_out_size OUT SYS_REFCURSOR
                              , p_out_err_msg OUT VARCHAR2)
    IS
        ln_org_id              NUMBER;
        ln_plan_id             NUMBER;
        ld_plan_date           VARCHAR2 (50);
        lv_brand               VARCHAR2 (50);
        lv_us_user_access      VARCHAR2 (10);
        lv_vo_user_access      VARCHAR2 (10);
        lv_mang_user_access    VARCHAR2 (10);
        lv_ws_channel          VARCHAR2 (10);
        lv_ecomm_channel       VARCHAR2 (10);
        lv_retail_channel      VARCHAR2 (10);
        lv_brand_user_access   VARCHAR2 (10);
        lv_wh_user_access      VARCHAR2 (10);
        lv_user_name           VARCHAR2 (100);
        lv_email               VARCHAR2 (100);
        lv_display_name        VARCHAR2 (100);
        lv_exception           EXCEPTION;
        lv_access_exception    EXCEPTION;
        lv_user_exception      EXCEPTION;
    BEGIN
        write_to_table (
               'in search_results: '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'XXD_ONT_PRODUCT_MV_PKG.search_results');
        write_to_table (
               'in search_results p_in_user_id '
            || p_in_style_color
            || ': '
            || p_in_user_id,
            'XXD_ONT_PRODUCT_MV_PKG.search_results');
        write_to_table (
               'in search_results p_in_warehouse '
            || p_in_style_color
            || ': '
            || p_in_warehouse,
            'XXD_ONT_PRODUCT_MV_PKG.search_results');
        write_to_table (
            'in search_results p_in_style_color ' || p_in_style_color,
            'XXD_ONT_PRODUCT_MV_PKG.search_results');
        write_to_table (
               'in search_results p_in_instance_name '
            || p_in_style_color
            || ': '
            || p_in_instance_name,
            'XXD_ONT_PRODUCT_MV_PKG.search_results');

        /************Start modification for version 1.1 ****************/
        BEGIN
            fetch_ad_user_email (p_in_user_id => p_in_user_id, p_out_user_name => lv_user_name, p_out_display_name => lv_display_name
                                 , p_out_email_id => lv_email);

            IF lv_user_name IS NULL OR lv_user_name = ''
            THEN
                RAISE lv_user_exception;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE lv_user_exception;
        END;

        /************End modification for version 1.1 ****************/
        IF    p_in_style_color IS NULL
           OR p_in_style_color = ''
           OR p_in_warehouse IS NULL
           OR p_in_warehouse = ''
        THEN
            RAISE lv_exception;
        END IF;

        BEGIN
            SELECT mc.segment1
              INTO lv_brand
              FROM mtl_categories_b mc
             WHERE     mc.attribute7 =
                       SUBSTR (p_in_style_color,
                               1,
                               INSTR (p_in_style_color, '-', 1) - 1)
                   AND mc.attribute8 =
                       SUBSTR (p_in_style_color,
                               INSTR (p_in_style_color, '-', 1) + 1)
                   AND mc.disable_date IS NULL
                   /************Start modification for version 1.4 ****************/
                   AND EXISTS
                           (SELECT 1
                              FROM mtl_item_categories mic
                             WHERE mic.category_id = mc.category_id);
        /************End modification for version 1.4 ****************/
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RAISE lv_exception;
            WHEN OTHERS
            THEN
                RAISE lv_exception;
        END;

        lv_brand_user_access   :=
            user_access (lv_user_name, 'BRAND', lv_brand,
                         NVL (p_in_instance_name, 'DEV'));
        lv_wh_user_access   :=
            user_access (lv_user_name, 'WAREHOUSE', p_in_warehouse,
                         NVL (p_in_instance_name, 'DEV'));

        IF lv_brand_user_access = 'N' OR lv_wh_user_access = 'N'
        THEN
            RAISE lv_access_exception;
        END IF;

        BEGIN
            SELECT organization_id
              INTO ln_org_id
              FROM mtl_parameters
             WHERE organization_code = p_in_warehouse;
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table (
                       'Unexpected error while fetching organization_id for warehouse '
                    || p_in_warehouse,
                    'XXD_ONT_PRODUCT_MV_PKG.search_results');
        END;

        lv_us_user_access   :=
            user_access (lv_user_name, 'ACCESS_TYPE', 'USER',
                         NVL (p_in_instance_name, 'DEV'));

        lv_vo_user_access   :=
            user_access (lv_user_name, 'ACCESS_TYPE', 'VIEW_ONLY',
                         NVL (p_in_instance_name, 'DEV'));

        lv_mang_user_access   :=
            user_access (lv_user_name, 'ACCESS_TYPE', 'MANAGER',
                         NVL (p_in_instance_name, 'DEV'));

        lv_ws_channel   :=
            user_access (lv_user_name, 'CHANNEL', 'Wholesale',
                         NVL (p_in_instance_name, 'DEV'));

        lv_ecomm_channel   :=
            user_access (lv_user_name, 'CHANNEL', 'E-Commerce',
                         NVL (p_in_instance_name, 'DEV'));

        lv_retail_channel   :=
            user_access (lv_user_name, 'CHANNEL', 'Retail',
                         NVL (p_in_instance_name, 'DEV'));

        BEGIN
            SELECT mp.plan_id, TO_CHAR (mp.curr_start_date, 'DD-MON-YYYY') plan_date
              INTO ln_plan_id, ld_plan_date
              FROM msc_plans@bt_ebs_to_ascp mp
             WHERE 1 = 1 AND mp.compile_designator = 'ATP';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_to_table (
                    'Unexpected error while fetching plan id and plan date ',
                    'XXD_ONT_PRODUCT_MV_PKG.search_results');
        END;


        OPEN p_out_size FOR   SELECT SUBSTR (segment1,
                                               INSTR (segment1, '-', 1,
                                                      2)
                                             + 1) item_size
                                FROM mtl_system_items_b msib
                               WHERE     SUBSTR (msib.segment1,
                                                 1,
                                                   INSTR (msib.segment1, '-', 1
                                                          , 2)
                                                 - 1) = p_in_style_color
                                     AND organization_id = ln_org_id
                                     AND SUBSTR (segment1,
                                                   INSTR (segment1, '-', 1,
                                                          2)
                                                 + 1) NOT IN ('ALL')
                            ORDER BY TO_NUMBER (msib.attribute10);

        write_to_table (
               'before p_out_results: '
            || p_in_style_color
            || ': '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'XXD_ONT_PRODUCT_MV_PKG.search_results');


        OPEN p_out_results FOR
              SELECT TYPE,
                     order_type,
                     operating_unit,
                     order_number,
                     po_num,
                     line_number,
                     item_name,
                     order_quantity_uom,
                     item_size,
                     tot_demand,
                     tot_supply,
                     unsch_qty,
                     line_type,
                     quantity,
                     poh,
                     MIN (poh)
                         OVER (
                             PARTITION BY inventory_item_id
                             ORDER BY
                                 NVL (schedule_ship_date, request_date) DESC)
                         atp,
                     TRUNC (request_date)
                         request_date,
                     TRUNC (schedule_ship_date)
                         schedule_ship_date,
                     TRUNC (cancel_date)
                         cancel_date,
                     TRUNC (latest_acceptable_date)
                         latest_acceptable_date,
                     status,
                     sold_to_org_id,
                     channel,
                     order_source,
                     cust_name,
                     cust_number,
                     inventory_item_id,
                     header_id,
                     line_id,
                     previous_batch_id,
                     previous_batch_status,
                     color,
                     style_number,
                     brand,
                     warehouse,
                     reservation_flag,
                     CASE
                         WHEN TYPE = 'Supply' THEN 1
                         ELSE 2
                     END
                         AS sort_order,
                     CASE
                         WHEN TYPE = 'Supply'
                         THEN
                             'Y'
                         /************Start modification for version 1.5 ****************/
                         WHEN order_source_id = 10
                         THEN
                             'Y'
                         /************End modification for version 1.5 ****************/
                         WHEN line_type = 'PL'
                         THEN
                             'Y'
                         WHEN lv_vo_user_access = 'Y'
                         THEN
                             'Y'
                         WHEN lv_mang_user_access = 'Y'
                         THEN
                             'N'
                         WHEN lv_us_user_access = 'Y'
                         THEN
                             DECODE (
                                 channel,
                                 'Wholesale', DECODE (lv_ws_channel,
                                                      'Y', 'N',
                                                      'Y'),
                                 'E-Commerce', DECODE (lv_ecomm_channel,
                                                       'Y', 'N',
                                                       'Y'),
                                 'Retail', DECODE (lv_retail_channel,
                                                   'Y', 'N',
                                                   'Y'),
                                 'Y')
                     END
                         AS read_only,
                     CASE
                         WHEN lv_vo_user_access = 'Y'
                         THEN
                             'N'
                         WHEN lv_mang_user_access = 'Y'
                         THEN
                             DECODE (
                                 channel,
                                 'Wholesale', DECODE (lv_ws_channel,
                                                      'Y', 'N',
                                                      'Y'),
                                 'E-Commerce', DECODE (lv_ecomm_channel,
                                                       'Y', 'N',
                                                       'Y'),
                                 'Retail', DECODE (lv_retail_channel,
                                                   'Y', 'N',
                                                   'Y'),
                                 'Y')
                         WHEN lv_us_user_access = 'Y'
                         THEN
                             'N'
                     END
                         AS cross_channel_flag
                FROM (SELECT TYPE,
                             order_type,
                             operating_unit,
                             order_number,
                             po_num,
                             line_number,
                             item_name,
                             order_quantity_uom,
                             SUBSTR (item_name,
                                       INSTR (item_name, '-', 1,
                                              2)
                                     + 1)
                                 item_size,
                             tot_demand,
                             tot_supply,
                             unsch_qty,
                             CASE
                                 WHEN reservation_flag = 'Y'
                                 THEN
                                     'PL'
                                 ELSE
                                     CASE
                                         WHEN type1 = 'SO' THEN 'SO'
                                         WHEN type1 = 'SUPPLY' THEN 'SUPPLY'
                                         WHEN type1 = 'UNSCH' THEN 'UNSCH'
                                     END
                             END
                                 AS line_type,
                             DECODE (type1,
                                     'SO', tot_demand,
                                     'SUPPLY', tot_supply,
                                     'UNSCH', unsch_qty)
                                 quantity,
                             SUM (tot_supply - tot_demand)
                                 OVER (
                                     PARTITION BY inventory_item_id
                                     ORDER BY inventory_item_id, NVL (schedule_ship_date, request_date))
                                 poh,
                             request_date,
                             schedule_ship_date,
                             cancel_date,
                             latest_acceptable_date,
                             status,
                             sold_to_org_id,
                             channel,
                             order_source,
                             /************Start modification for version 1.5 ****************/
                             order_source_id,
                             /************End modification for version 1.5 ****************/
                             CASE
                                 WHEN channel = 'E-Commerce'
                                 THEN
                                     'Ecommerce Customer'
                                 ELSE
                                     cust_name
                             END
                                 AS cust_name,
                             CASE
                                 WHEN channel = 'E-Commerce'
                                 THEN
                                     'Ecommerce Customer'
                                 ELSE
                                     cust_number
                             END
                                 AS cust_number,
                             inventory_item_id,
                             header_id,
                             line_id,
                             previous_batch_id,
                             previous_batch_status,
                             (SELECT SUBSTR (p_in_style_color, INSTR (p_in_style_color, '-', 1) + 1) FROM DUAL)
                                 color,
                             (SELECT SUBSTR (p_in_style_color, 1, INSTR (p_in_style_color, '-', 1) - 1) FROM DUAL)
                                 style_number,
                             (SELECT mc.segment1
                                FROM mtl_categories_b mc
                               WHERE     mc.attribute7 =
                                         SUBSTR (
                                             p_in_style_color,
                                             1,
                                               INSTR (p_in_style_color, '-', 1)
                                             - 1)
                                     AND mc.attribute8 =
                                         SUBSTR (
                                             p_in_style_color,
                                               INSTR (p_in_style_color, '-', 1)
                                             + 1)
                                     AND mc.disable_date IS NULL
                                     /************Start modification for version 1.4 ****************/
                                     AND EXISTS
                                             (SELECT 1
                                                FROM mtl_item_categories mic
                                               WHERE mic.category_id =
                                                     mc.category_id) /************End modification for version 1.4 ****************/
                                                                    )
                                 brand,
                             (SELECT organization_code
                                FROM mtl_parameters
                               WHERE organization_code = p_in_warehouse)
                                 warehouse,
                             NVL (reservation_flag, 'N')
                                 reservation_flag
                        FROM (SELECT 'SO'
                                         type1,
                                     /************Start modification for version 1.1 ****************/
                                     DECODE (
                                         SUBSTR (ottt.name,
                                                 1,
                                                 INSTR (ottt.name, ' ', 1) - 1),
                                         'Bulk', 'Bulk Order',
                                         'Sales Order')
                                         TYPE,
                                     ottt.name
                                         order_type,
                                     hou.name
                                         operating_unit,
                                     /************End modification for version 1.1 ****************/
                                     ooha.sold_to_org_id,
                                     ooha.header_id,
                                     TO_CHAR (ooha.order_number)
                                         order_number,
                                     /************Start modification for version 1.1 ****************/
                                     oos.name
                                         order_source,
                                     /************End modification for version 1.1 ****************/
                                     /************Start modification for version 1.5 ****************/
                                     oos.order_source_id,
                                     /************End modification for version 1.5 ****************/
                                     (SELECT flv.description
                                        FROM fnd_lookup_values flv
                                       WHERE     flv.lookup_type =
                                                 'XXD_ONT_PMT_CHANNEL_LKP'
                                             AND flv.language = 'US'
                                             AND flv.lookup_code =
                                                 NVL (ooha.sales_channel_code,
                                                      'DEFAULT'))
                                         channel,
                                     (SELECT 'Y'
                                        FROM apps.mtl_reservations
                                       WHERE     1 = 1
                                             AND ln_org_id = organization_id
                                             AND demand_source_line_id =
                                                 oola.line_id)
                                         reservation_flag,
                                     (SELECT hp_bill.party_name
                                        FROM hz_parties hp_bill, hz_cust_accounts hca
                                       WHERE     ooha.sold_to_org_id =
                                                 hca.cust_account_id
                                             AND hp_bill.party_id =
                                                 hca.party_id)
                                         cust_name,
                                     (SELECT hca.account_number
                                        FROM hz_cust_accounts hca
                                       WHERE ooha.sold_to_org_id =
                                             hca.cust_account_id)
                                         cust_number,
                                     (SELECT MAX (batch_id)
                                        FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd
                                       WHERE     xpmd.inventory_item_id =
                                                 oola.inventory_item_id
                                             AND xpmd.line_id = oola.line_id)
                                         previous_batch_id,
                                     (SELECT status
                                        FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd
                                       WHERE     xpmd.inventory_item_id =
                                                 oola.inventory_item_id
                                             AND xpmd.line_id = oola.line_id
                                             AND batch_id =
                                                 (SELECT MAX (batch_id)
                                                    FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd1
                                                   WHERE     xpmd1.inventory_item_id =
                                                             xpmd.inventory_item_id
                                                         AND xpmd.line_id =
                                                             xpmd.line_id)
                                             AND ROWNUM = 1)
                                         previous_batch_status,
                                     ooha.cust_po_number
                                         po_num,
                                        oola.line_number
                                     || '.'
                                     || oola.shipment_number
                                         line_number,
                                     oola.ordered_item
                                         item_name,
                                     oola.order_quantity_uom,
                                     xx.tot_demand
                                         tot_demand,
                                     xx.tot_supply,
                                     0
                                         unsch_qty,
                                     oola.request_date
                                         request_date,
                                     alloc_date
                                         schedule_ship_date,
                                     /************Start modification for version 1.2 ****************/
                                     NVL (
                                         TO_DATE (oola.attribute1,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                         TO_DATE (ooha.attribute1,
                                                  'YYYY/MM/DD HH24:MI:SS'))
                                         cancel_date,
                                     /************End modification for version 1.2 ****************/
                                     oola.latest_acceptable_date,
                                     oola.flow_status_code
                                         status,
                                     oola.line_id
                                         line_id,
                                     sr_inventory_item_id
                                         inventory_item_id
                                FROM (  SELECT alloc_date, msi.sr_inventory_item_id, sales_order_line_id,
                                               SUM (tot_demand) tot_demand, SUM (tot_supply) tot_supply, x.organization_id
                                          FROM (  SELECT alloc_date alloc_date, 0 tot_supply, SUM (demand) tot_demand,
                                                         inventory_item_id, sales_order_line_id, organization_id
                                                    FROM (SELECT DECODE (SIGN (TRUNC (schedule_ship_date) - TRUNC (TO_DATE (ld_plan_date, 'DD-MON-YYYY'))), 1, TRUNC (schedule_ship_date), TRUNC (TO_DATE (ld_plan_date, 'DD-MON-YYYY'))) alloc_date, 0 supply, using_requirement_quantity demand,
                                                                 inventory_item_id, sales_order_line_id, organization_id
                                                            FROM msc_demands@bt_ebs_to_ascp
                                                           WHERE     plan_id =
                                                                     ln_plan_id
                                                                 AND organization_id =
                                                                     ln_org_id
                                                                 AND schedule_ship_date
                                                                         IS NOT NULL
                                                                 AND using_requirement_quantity >
                                                                     0)
                                                GROUP BY inventory_item_id, alloc_date, sales_order_line_id,
                                                         organization_id) x,
                                               msc_system_items@bt_ebs_to_ascp
                                               msi
                                         WHERE     x.inventory_item_id =
                                                   msi.inventory_item_id
                                               AND msi.plan_id = ln_plan_id
                                               AND msi.organization_id =
                                                   ln_org_id
                                               AND SUBSTR (msi.item_name,
                                                           1,
                                                             INSTR (msi.item_name, '-', 1
                                                                    , 2)
                                                           - 1) =
                                                   p_in_style_color
                                      GROUP BY sr_inventory_item_id, alloc_date, sales_order_line_id,
                                               x.organization_id
                                      ORDER BY alloc_date, msi.sr_inventory_item_id, sales_order_line_id,
                                               x.organization_id) xx,
                                     oe_order_lines_all oola,
                                     oe_order_headers_all ooha,
                                     /************Start modification for version 1.1 ****************/
                                     oe_transaction_types_tl ottt,
                                     hr_operating_units hou,
                                     oe_order_sources oos
                               /************End modification for version 1.1 ****************/
                               WHERE     oola.line_id = xx.sales_order_line_id
                                     AND oola.inventory_item_id =
                                         xx.sr_inventory_item_id
                                     AND ooha.header_id = oola.header_id
                                     AND oola.schedule_ship_date IS NOT NULL
                                     AND oola.ordered_quantity > 0
                                     AND oola.open_flag = 'Y'
                                     AND oola.booked_flag = 'Y'
                                     AND oola.line_category_code = 'ORDER'
                                     AND ln_org_id = oola.ship_from_org_id
                                     /************Start modification for version 1.1 ****************/
                                     AND ooha.order_type_id =
                                         ottt.transaction_type_id
                                     AND ottt.language = 'US'
                                     AND hou.organization_id = ooha.org_id
                                     AND oos.order_source_id =
                                         ooha.order_source_id
                                     /************End modification for version 1.1 ****************/
                                     /************Start modification for version 1.3 ****************/
                                     AND oola.source_type_code <> 'EXTERNAL'
                                     AND ooha.order_type_id NOT IN
                                             (SELECT flv.lookup_code
                                                FROM fnd_lookup_values flv
                                               WHERE     flv.lookup_type =
                                                         'XXD_ONT_PMT_OT_EXC_LKP'
                                                     AND flv.language = 'US'
                                                     AND flv.enabled_flag = 'Y'
                                                     AND SYSDATE BETWEEN NVL (
                                                                             flv.start_date_active,
                                                                             SYSDATE)
                                                                     AND NVL (
                                                                             flv.end_date_active,
                                                                               SYSDATE
                                                                             + 1))
                              /************End modification for version 1.3 ****************/
                              UNION ALL
                              SELECT 'SUPPLY'
                                         type1,
                                     'Supply'
                                         TYPE,
                                     (SELECT meaning
                                        FROM mfg_lookups
                                       WHERE     lookup_type = 'MRP_ORDER_TYPE'
                                             AND xx.order_type = lookup_code)
                                         order_type,
                                     ''
                                         operating_unit,
                                     NULL
                                         sold_to_org_id,
                                     NULL
                                         header_id,
                                     DECODE (xx.order_type,
                                             5, TO_CHAR (xx.transaction_id),
                                             xx.order_number)
                                         order_number,
                                     ''
                                         order_source,
                                     /************Start modification for version 1.5 ****************/
                                     NULL
                                         order_source_id,
                                     /************End modification for version 1.5 ****************/
                                     ''
                                         channel,
                                     ''
                                         reservation_flag,
                                     ''
                                         cust_name,
                                     ''
                                         cust_number,
                                     NULL
                                         previous_batch_id,
                                     ''
                                         previous_batch_status,
                                     ''
                                         po_num,
                                     NULL
                                         line_number,
                                     item_name,
                                     ''
                                         order_quantity_uom,
                                     tot_demand,
                                     xx.tot_supply
                                         tot_supply,
                                     0
                                         unsch_qty,
                                     NULL
                                         request_date,
                                     alloc_date
                                         schedule_ship_date,
                                     NULL
                                         cancel_date,
                                     NULL
                                         latest_acceptable_date,
                                     ''
                                         status,
                                     NULL
                                         line_id,
                                     sr_inventory_item_id
                                         inventory_item_id
                                FROM (  SELECT alloc_date, msi.sr_inventory_item_id, msi.item_name,
                                               SUM (tot_demand) tot_demand, x.transaction_id, SUM (tot_supply) tot_supply,
                                               x.organization_id, x.order_number, x.order_type
                                          FROM (  SELECT alloc_date alloc_date, SUM (supply) tot_supply, 0 tot_demand,
                                                         transaction_id, inventory_item_id, organization_id,
                                                         order_number, order_type
                                                    FROM (SELECT TRUNC (new_schedule_date) alloc_date, new_order_quantity supply, 0 demand,
                                                                 transaction_id, inventory_item_id, organization_id,
                                                                 order_number, order_type
                                                            FROM msc_supplies@bt_ebs_to_ascp
                                                           WHERE     plan_id =
                                                                     ln_plan_id
                                                                 AND organization_id =
                                                                     ln_org_id)
                                                GROUP BY inventory_item_id, alloc_date, organization_id,
                                                         order_number, order_type, transaction_id)
                                               x,
                                               msc_system_items@bt_ebs_to_ascp
                                               msi
                                         WHERE     x.inventory_item_id =
                                                   msi.inventory_item_id
                                               AND msi.plan_id = ln_plan_id
                                               AND msi.organization_id =
                                                   ln_org_id
                                               AND SUBSTR (msi.item_name,
                                                           1,
                                                             INSTR (msi.item_name, '-', 1
                                                                    , 2)
                                                           - 1) =
                                                   p_in_style_color
                                      GROUP BY sr_inventory_item_id, msi.item_name, alloc_date,
                                               x.organization_id, x.order_number, x.order_type,
                                               transaction_id
                                      ORDER BY alloc_date, msi.sr_inventory_item_id, x.organization_id,
                                               msi.item_name) xx
                              UNION ALL
                              SELECT 'UNSCH'
                                         type1,
                                     /************Start modification for version 1.1 ****************/
                                     DECODE (
                                         SUBSTR (ottt.name,
                                                 1,
                                                 INSTR (ottt.name, ' ', 1) - 1),
                                         'Bulk', 'Bulk Order',
                                         'Sales Order')
                                         TYPE,
                                     ottt.name
                                         order_type,
                                     hou.name
                                         operating_unit,
                                     /************End modification for version 1.1 ****************/
                                     ooha.sold_to_org_id,
                                     ooha.header_id,
                                     TO_CHAR (ooha.order_number)
                                         order_number,
                                     /************Start modification for version 1.1 ****************/
                                     oos.name
                                         order_source,
                                     /************End modification for version 1.1 ****************/
                                     /************Start modification for version 1.5 ****************/
                                     oos.order_source_id,
                                     /************End modification for version 1.5 ****************/
                                     (SELECT flv.description
                                        FROM fnd_lookup_values flv
                                       WHERE     flv.lookup_type =
                                                 'XXD_ONT_PMT_CHANNEL_LKP'
                                             AND flv.language = 'US'
                                             AND flv.lookup_code =
                                                 NVL (ooha.sales_channel_code,
                                                      'DEFAULT'))
                                         channel,
                                     (SELECT 'Y'
                                        FROM apps.mtl_reservations
                                       WHERE     1 = 1
                                             AND demand_source_line_id =
                                                 oola.line_id
                                             AND ln_org_id = organization_id)
                                         reservation_flag,
                                     (SELECT hp_bill.party_name
                                        FROM hz_parties hp_bill, hz_cust_accounts hca
                                       WHERE     ooha.sold_to_org_id =
                                                 hca.cust_account_id
                                             AND hp_bill.party_id =
                                                 hca.party_id)
                                         cust_name,
                                     (SELECT hca.account_number
                                        FROM hz_cust_accounts hca
                                       WHERE ooha.sold_to_org_id =
                                             hca.cust_account_id)
                                         cust_number,
                                     (SELECT MAX (batch_id)
                                        FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd
                                       WHERE     xpmd.inventory_item_id =
                                                 oola.inventory_item_id
                                             AND xpmd.line_id = oola.line_id)
                                         previous_batch_id,
                                     (SELECT status
                                        FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd
                                       WHERE     xpmd.inventory_item_id =
                                                 oola.inventory_item_id
                                             AND xpmd.line_id = oola.line_id
                                             AND batch_id =
                                                 (SELECT MAX (batch_id)
                                                    FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd1
                                                   WHERE     xpmd1.inventory_item_id =
                                                             xpmd.inventory_item_id
                                                         AND xpmd.line_id =
                                                             xpmd.line_id)
                                             AND ROWNUM = 1)
                                         previous_batch_status,
                                     ooha.cust_po_number
                                         po_num,
                                        oola.line_number
                                     || '.'
                                     || oola.shipment_number
                                         line_number,
                                     oola.ordered_item
                                         item_name,
                                     oola.order_quantity_uom,
                                     0
                                         tot_demand,
                                     0
                                         tot_supply,
                                     oola.ordered_quantity
                                         unsch_qty,
                                     oola.request_date
                                         request_date,
                                     oola.schedule_ship_date,
                                     /************Start modification for version 1.2 ****************/
                                     NVL (
                                         TO_DATE (oola.attribute1,
                                                  'YYYY/MM/DD HH24:MI:SS'),
                                         TO_DATE (ooha.attribute1,
                                                  'YYYY/MM/DD HH24:MI:SS'))
                                         cancel_date,
                                     /************End modification for version 1.2 ****************/
                                     oola.latest_acceptable_date,
                                     oola.flow_status_code
                                         status,
                                     oola.line_id
                                         line_id,
                                     oola.inventory_item_id
                                FROM oe_order_lines_all oola, oe_order_headers_all ooha, mtl_system_items_b msib,
                                     /************Start modification for version 1.1 ****************/
                                     oe_transaction_types_tl ottt, hr_operating_units hou, oe_order_sources oos
                               /************End modification for version 1.1 ****************/
                               WHERE     oola.inventory_item_id =
                                         msib.inventory_item_id
                                     AND ooha.header_id = oola.header_id
                                     AND oola.schedule_ship_date IS NULL
                                     AND oola.ordered_quantity > 0
                                     AND oola.open_flag = 'Y'
                                     AND oola.booked_flag = 'Y'
                                     AND oola.line_category_code = 'ORDER'
                                     AND msib.organization_id =
                                         oola.ship_from_org_id
                                     AND oola.ship_from_org_id = ln_org_id
                                     AND SUBSTR (msib.segment1,
                                                 1,
                                                   INSTR (msib.segment1, '-', 1
                                                          , 2)
                                                 - 1) = p_in_style_color
                                     /************Start modification for version 1.1 ****************/
                                     AND ooha.order_type_id =
                                         ottt.transaction_type_id
                                     AND ottt.language = 'US'
                                     AND hou.organization_id = ooha.org_id
                                     AND oos.order_source_id =
                                         ooha.order_source_id
                                     /************End modification for version 1.1 ****************/
                                     /************Start modification for version 1.3 ****************/
                                     AND oola.source_type_code <> 'EXTERNAL'
                                     AND ooha.order_type_id NOT IN
                                             (SELECT flv.lookup_code
                                                FROM fnd_lookup_values flv
                                               WHERE     flv.lookup_type =
                                                         'XXD_ONT_PMT_OT_EXC_LKP'
                                                     AND flv.language = 'US'
                                                     AND flv.enabled_flag = 'Y'
                                                     AND SYSDATE BETWEEN NVL (
                                                                             flv.start_date_active,
                                                                             SYSDATE)
                                                                     AND NVL (
                                                                             flv.end_date_active,
                                                                               SYSDATE
                                                                             + 1)) /************End modification for version 1.3 ****************/
                                                                                  ))
            ORDER BY inventory_item_id, NVL (schedule_ship_date, request_date), sort_order,
                     request_date;

        write_to_table (
               'after p_out_results: '
            || p_in_style_color
            || ': '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'XXD_ONT_PRODUCT_MV_PKG.search_results');
    EXCEPTION
        WHEN lv_user_exception
        THEN
            p_out_err_msg   := 'User does not have valid oracle access';
            write_to_table ('User does not have valid oracle access',
                            'XXD_ONT_PRODUCT_MV_PKG.search_results');
        WHEN lv_access_exception
        THEN
            p_out_err_msg   :=
                   'User '
                || lv_display_name
                || ' does not have access to warehouse '
                || p_in_warehouse
                || ' or brand '
                || lv_brand;
            write_to_table (
                   'User '
                || lv_display_name
                || ' does not have access to warehouse or brand',
                'XXD_ONT_PRODUCT_MV_PKG.search_results');
        WHEN lv_exception
        THEN
            p_out_err_msg   :=
                   'Style-Color combination/warehouse is not received or brand is not fetched for user '
                || lv_display_name;
            write_to_table (
                   'Style-Color combination/warehouse is not received or brand is not fetched for user '
                || lv_display_name,
                'XXD_ONT_PRODUCT_MV_PKG.search_results');
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                   'Unexpected error in search results for user '
                || lv_display_name;
            write_to_table (
                   'Unexpected error in search results for user '
                || lv_display_name,
                'XXD_ONT_PRODUCT_MV_PKG.search_results');
    END search_results;

    PROCEDURE insert_stg_data (p_in_user_id IN NUMBER, p_in_org_id IN NUMBER, p_in_batch_id IN NUMBER
                               , p_in_style_color IN VARCHAR2, p_input_data IN pm_tbl_type, p_out_err_msg OUT VARCHAR2)
    IS
        lv_account_number       hz_cust_accounts.account_number%TYPE;
        lv_style                VARCHAR2 (50);
        lv_color                VARCHAR2 (10);
        lv_brand                VARCHAR2 (50);
        lv_channel              VARCHAR2 (50);
        lv_channel_code         VARCHAR2 (30);
        lv_size                 VARCHAR2 (30);
        lv_item_name            VARCHAR2 (2000);
        lv_err_msg              VARCHAR2 (2000);
        ld_schedule_ship_date   DATE;
        ln_sold_to_org_id       NUMBER;
        ln_order_number         NUMBER;
        ln_line_number          NUMBER;
        ln_exists               NUMBER;
        ln_order_source_id      NUMBER;
        ln_quantity             NUMBER;
        ln_count                NUMBER := 0;
        /************Start modification for version 1.5 ****************/
        ln_exists_h             NUMBER := 0;
    /************End modification for version 1.5 ****************/
    BEGIN
        /************Start modification for version 1.5 ****************/
        BEGIN
            SELECT 1
              INTO ln_exists_h
              FROM xxdo.xxd_ont_product_move_hdr_stg_t
             WHERE batch_id = p_in_batch_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_exists_h   := 0;
            WHEN OTHERS
            THEN
                ln_exists_h   := 0;
        END;

        IF ln_exists_h = 0
        THEN
            /************End modification for version 1.5 ****************/
            SELECT SUBSTR (p_in_style_color, INSTR (p_in_style_color, '-', 1) + 1)
              INTO lv_color
              FROM DUAL;

            SELECT SUBSTR (p_in_style_color, 1, INSTR (p_in_style_color, '-', 1) - 1)
              INTO lv_style
              FROM DUAL;

            write_to_table (
                   'in procedure insert_stg_data to insert data to staging tables for user id '
                || p_in_user_id,
                'XXD_ONT_PRODUCT_MV_PKG.insert_stg_data');

            FOR i IN 1 .. p_input_data.COUNT
            LOOP
                BEGIN
                    SELECT mc.segment1
                      INTO lv_brand
                      FROM mtl_categories_b mc
                     WHERE     mc.attribute7 = lv_style                --style
                           AND mc.attribute8 = lv_color
                           AND mc.disable_date IS NULL
                           /************Start modification for version 1.4 ****************/
                           AND EXISTS
                                   (SELECT 1
                                      FROM mtl_item_categories mic
                                     WHERE mic.category_id = mc.category_id);
                /************End modification for version 1.4 ****************/
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_brand   := '';
                END;

                --fetch order number
                BEGIN
                    SELECT ooha.order_number, ooha.order_source_id, ooha.sold_to_org_id,
                           ooha.sales_channel_code
                      INTO ln_order_number, ln_order_source_id, ln_sold_to_org_id, lv_channel_code
                      FROM oe_order_headers_all ooha
                     WHERE ooha.header_id = p_input_data (i).attribute6;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_order_number      := NULL;
                        ln_order_source_id   := NULL;
                        ln_sold_to_org_id    := NULL;
                END;

                BEGIN
                    SELECT flv.description
                      INTO lv_channel
                      FROM fnd_lookup_values flv
                     WHERE     flv.lookup_type = 'XXD_ONT_PMT_CHANNEL_LKP'
                           AND flv.language = 'US'
                           AND flv.lookup_code =
                               NVL (lv_channel_code, 'DEFAULT');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_channel   := '';
                END;

                --fetch order line details
                BEGIN
                    SELECT oola.line_number || '.' || oola.shipment_number line_number, oola.ordered_item, oola.schedule_ship_date,
                           oola.ordered_quantity
                      INTO ln_line_number, lv_item_name, ld_schedule_ship_date, ln_quantity
                      FROM oe_order_lines_all oola
                     WHERE oola.line_id = p_input_data (i).attribute7;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_line_number          := NULL;
                        lv_item_name            := '';
                        ld_schedule_ship_date   := NULL;
                        ln_quantity             := NULL;
                END;

                --fetching size
                SELECT SUBSTR (lv_item_name,
                                 INSTR (lv_item_name, '-', 1,
                                        2)
                               + 1)
                  INTO lv_size
                  FROM DUAL;

                --fetch account number
                BEGIN
                    SELECT hca.account_number
                      INTO lv_account_number
                      FROM hz_cust_accounts hca
                     WHERE ln_sold_to_org_id = hca.cust_account_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_account_number   := NULL;
                END;

                BEGIN
                    SELECT 1
                      INTO ln_exists
                      FROM xxdo.xxd_ont_product_move_hdr_stg_t
                     WHERE batch_id = p_in_batch_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_exists   := 0;
                    WHEN OTHERS
                    THEN
                        ln_exists   := 0;
                END;

                IF ln_exists = 0
                THEN
                    INSERT INTO xxdo.xxd_ont_product_move_hdr_stg_t (
                                    batch_id,
                                    organization_id,
                                    brand,
                                    style,
                                    color,
                                    status,
                                    created_by,
                                    last_updated_by,
                                    creation_date,
                                    last_update_date,
                                    batch_mode,
                                    sku)
                             VALUES (p_in_batch_id,
                                     p_in_org_id,
                                     lv_brand,
                                     lv_style,
                                     lv_color,
                                     'NEW',
                                     p_in_user_id,
                                     p_in_user_id,
                                     SYSDATE,
                                     SYSDATE,
                                     p_input_data (i).attribute2,
                                     lv_item_name);
                END IF;

                INSERT INTO xxdo.xxd_ont_pdt_move_dtls_stg_t (
                                batch_id,
                                rec_type,
                                inventory_item_id,
                                organization_id,
                                header_id,
                                line_id,
                                order_number,
                                item_number,
                                account_number,
                                brand,
                                style,
                                color,
                                itm_size,
                                orig_qty,
                                orig_ship_date,
                                channel,
                                action,
                                status,
                                created_by,
                                last_updated_by,
                                creation_date,
                                last_update_date,
                                batch_mode,
                                error_message)
                     VALUES (p_in_batch_id, p_input_data (i).attribute1, p_input_data (i).attribute8, p_in_org_id, p_input_data (i).attribute6, p_input_data (i).attribute7, ln_order_number, lv_item_name, lv_account_number, lv_brand, lv_style, lv_color, lv_size, ln_quantity, ld_schedule_ship_date, lv_channel, p_input_data (i).attribute3, 'NEW', p_in_user_id, p_in_user_id, SYSDATE
                             , SYSDATE, p_input_data (i).attribute2, NULL);

                COMMIT;
            END LOOP;

            schedule_order (p_in_batch_id, p_out_err_msg);
        /************Start modification for version 1.5 ****************/
        END IF;
    /************End modification for version 1.5 ****************/
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                SUBSTR (
                       p_out_err_msg
                    || '-'
                    || 'Error while inserting records to table XXD_ONT_PDT_MOVE_DTLS_STG_T'
                    || SQLERRM,
                    1,
                    4000);

            write_to_table (
                SUBSTR (
                       p_out_err_msg
                    || '-'
                    || 'Error while inserting records to table XXD_ONT_PDT_MOVE_DTLS_STG_T'
                    || SQLERRM,
                    1,
                    4000),
                'XXD_ONT_PRODUCT_MV_PKG.insert_stg_data');
    END insert_stg_data;



    PROCEDURE process_order_api_p (p_in_batch_id IN NUMBER)
    IS
        lv_plan_run         VARCHAR2 (10);
        lv_batch_commit     VARCHAR2 (5) := 'Y';
        lv_err_msg          VARCHAR2 (2000);
        lv_err_flag         VARCHAR2 (5);
        ln_line_id          NUMBER;
        lv_exception        EXCEPTION;
        lv_loop_exception   EXCEPTION;
        /************Start modification for version 1.6 ****************/
        lc_lock_status      VARCHAR2 (1) := 'N';

        lv_lock_exception   EXCEPTION;

        CURSOR get_order_lock IS
                SELECT oola.line_id
                  FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd, oe_order_lines_all oola
                 WHERE     oola.line_id = xpmd.line_id
                       AND xpmd.batch_id = p_in_batch_id
            FOR UPDATE NOWAIT;

        /************End modification for version 1.6 ****************/

        CURSOR fetch_unsch_ord_dtls_cur IS
              SELECT xpmd.header_id, xpmd.line_id, xpmd.action,
                     oola.org_id, oola.schedule_ship_date, /************Start modification for version 1.6 ****************/
                                                           oola.request_date,
                     /************End modification for version 1.6 ****************/
                     xpmd.created_by
                FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd, --oe_order_headers_all              ooha,
                                                            oe_order_lines_all oola
               WHERE     oola.header_id = xpmd.header_id
                     --AND oola.header_id = ooha.header_id
                     AND oola.line_id = xpmd.line_id
                     AND xpmd.batch_id = p_in_batch_id
                     AND xpmd.action = 'UNSCHEDULE'
            /************Start modification for version 1.6 ****************/
            ORDER BY request_date;

        /************End modification for version 1.6 ****************/
        CURSOR fetch_sch_ord_dtls_cur IS
              SELECT xpmd.header_id, xpmd.line_id, xpmd.action,
                     oola.org_id, oola.schedule_ship_date, /************Start modification for version 1.6 ****************/
                                                           oola.request_date
                /************End modification for version 1.6 ****************/
                FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd, -- oe_order_headers_all              ooha,
                                                            oe_order_lines_all oola
               WHERE     oola.header_id = xpmd.header_id
                     -- AND oola.header_id = ooha.header_id
                     AND oola.line_id = xpmd.line_id
                     AND xpmd.batch_id = p_in_batch_id
                     AND xpmd.action = 'SCHEDULE'
            /************Start modification for version 1.6 ****************/
            ORDER BY request_date;

        /************End modification for version 1.6 ****************/
        l_order_rec         get_order_lock%ROWTYPE;
    BEGIN
        /************Start modification for version 1.6 ****************/
        -- Verify all source orders and lock them
        write_to_table ('before lock batch:' || p_in_batch_id,
                        'XXD_ONT_PRODUCT_MV_PKG.process_order_api_p');

        BEGIN
            OPEN get_order_lock;

            FETCH get_order_lock INTO l_order_rec;

            CLOSE get_order_lock;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_lock_status   := 'Y';
        END;

        IF lc_lock_status = 'N'
        THEN
            write_to_table ('batch locked:' || p_in_batch_id,
                            'XXD_ONT_PRODUCT_MV_PKG.process_order_api_p');

            /************End modification for version 1.6 ****************/
            BEGIN
                SELECT fpov.profile_option_value
                  INTO lv_batch_commit
                  FROM fnd_profile_options fpo, fnd_profile_option_values fpov
                 WHERE     fpo.profile_option_name =
                           'XXD_ONT_PMT_BATCH_PROCESSING'
                       AND fpo.profile_option_id = fpov.profile_option_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_batch_commit   := 'Y';
            END;

            write_to_table (
                'in process_order_api_p p_in_batch_id: ' || p_in_batch_id,
                'XXD_ONT_PRODUCT_MV_PKG.process_order_api_p');

            lv_plan_run   := xxd_ont_check_plan_run_fnc ();
            write_to_table ('lv_plan_run: ' || lv_plan_run,
                            'XXD_ONT_PRODUCT_MV_PKG.process_order_api_p');
            ROLLBACK;

            IF lv_plan_run = 'N'
            THEN
                fnd_profile.put ('ONT_ATP_CALL_AUTONOMOUS', 'N'); ---should comment before code delivery??
                fnd_profile.put ('MRP_ATP_CALC_SD', 'N');

                FOR fetch_unsch_ord_dtls_rec IN fetch_unsch_ord_dtls_cur
                LOOP
                    submit_order_p (p_in_batch_id, fetch_unsch_ord_dtls_rec.org_id, fetch_unsch_ord_dtls_rec.header_id, fetch_unsch_ord_dtls_rec.line_id, 'UNSCHEDULE', NVL (lv_batch_commit, 'Y')
                                    , lv_err_msg, lv_err_flag);

                    IF lv_err_flag = 'Y'
                    THEN
                        ln_line_id   := fetch_unsch_ord_dtls_rec.line_id;
                        RAISE lv_loop_exception;
                    END IF;
                END LOOP;

                write_to_table ('Before loop fetch_sch_ord_dtls_rec ',
                                'XXD_ONT_PRODUCT_MV_PKG.process_order_api_p');

                FOR fetch_sch_ord_dtls_rec IN fetch_sch_ord_dtls_cur
                LOOP
                    submit_order_p (p_in_batch_id, fetch_sch_ord_dtls_rec.org_id, fetch_sch_ord_dtls_rec.header_id, fetch_sch_ord_dtls_rec.line_id, 'SCHEDULE', NVL (lv_batch_commit, 'Y')
                                    , lv_err_msg, lv_err_flag);

                    IF lv_err_flag = 'Y'
                    THEN
                        ln_line_id   := fetch_sch_ord_dtls_rec.line_id;

                        RAISE lv_loop_exception;
                    END IF;
                END LOOP;

                IF lv_batch_commit = 'Y'
                THEN
                    COMMIT;
                END IF;
            ELSE
                RAISE lv_exception;
            END IF;
        /************Start modification for version 1.6 ****************/
        ELSE
            write_to_table ('Another user is modifying the record:',
                            'XXD_ONT_PRODUCT_MV_PKG.process_order_api_p');
            RAISE lv_lock_exception;
        END IF;
    /************End modification for version 1.6 ****************/
    EXCEPTION
        /************Start modification for version 1.6 ****************/
        WHEN lv_lock_exception
        THEN
            write_to_table (
                'in lv_lock_exception Another user is modifying the record:',
                'XXD_ONT_PRODUCT_MV_PKG.process_order_api_p');

            UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
               SET status = 'ERROR', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            UPDATE xxdo.XXD_ONT_PDT_MOVE_DTLS_STG_T
               SET status = 'ERROR', error_message = 'One or more lines locked by another user', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            COMMIT;
        /************End modification for version 1.6 ****************/
        WHEN lv_loop_exception
        THEN
            ROLLBACK;

            UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
               SET status = 'ERROR', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            UPDATE xxdo.xxd_ont_pdt_move_dtls_stg_t
               SET status = 'ERROR', error_message = lv_err_msg, last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id AND line_id = ln_line_id;

            UPDATE xxdo.xxd_ont_pdt_move_dtls_stg_t
               SET status = 'ERROR', error_message = 'Error in one of the lines of the batch while processing', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id AND error_message IS NULL;

            COMMIT;
        WHEN lv_exception
        THEN
            UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
               SET status = 'ERROR', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            UPDATE xxdo.xxd_ont_pdt_move_dtls_stg_t
               SET status = 'ERROR', error_message = 'Plan is running, no operation is permitted during plan run', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            COMMIT;
            write_to_table (
                'Plan is running, no operation is permitted during plan run ',
                'XXD_ONT_PRODUCT_MV_PKG.process_order_api_p');
        WHEN OTHERS
        THEN
            UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
               SET status   = 'ERROR'
             WHERE batch_id = p_in_batch_id;

            UPDATE xxdo.xxd_ont_pdt_move_dtls_stg_t
               SET status = 'ERROR', error_message = 'Unexpected error in  process_order_api_p', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            COMMIT;
            write_to_table (
                'Unexpected error in  process_order_api_p' || SQLERRM,
                'XXD_ONT_PRODUCT_MV_PKG.process_order_api_p');
    END process_order_api_p;

    PROCEDURE submit_order_p (p_in_batch_id               IN     NUMBER,
                              p_in_org_id                 IN     NUMBER,
                              p_in_header_id              IN     NUMBER,
                              p_in_line_id                IN     NUMBER,
                              p_in_schedule_action_code   IN     VARCHAR2,
                              p_in_batch_commit           IN     VARCHAR2,
                              p_out_err_msg                  OUT VARCHAR2,
                              p_out_err_flag                 OUT VARCHAR2)
    IS
        l_header_rec               oe_order_pub.header_rec_type;
        l_line_tbl                 oe_order_pub.line_tbl_type;
        l_header_rec_x             oe_order_pub.header_rec_type;
        l_line_tbl_x               oe_order_pub.line_tbl_type;
        l_action_request_tbl       oe_order_pub.request_tbl_type;
        l_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        l_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        l_header_scr_tbl           oe_order_pub.header_scredit_tbl_type;
        l_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        l_request_rec              oe_order_pub.request_rec_type;
        l_return_status            VARCHAR2 (1000);
        l_msg_count                NUMBER;
        l_msg_data                 VARCHAR2 (1000);
        ld_sch_ship_date           DATE;
        l_line_tbl_index           NUMBER;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        l_msg_index_out            NUMBER (10);
        l_message_data             VARCHAR2 (2000);
        ln_resp_id                 NUMBER := 0;
        ln_resp_appl_id            NUMBER := 0;
        lc_lock_status             VARCHAR2 (1);
        ln_quantity                NUMBER;
        lv_exception               EXCEPTION;
        lv_api_exception           EXCEPTION;
        ln_user_id                 NUMBER;
        /************Start modification for version 1.1 ****************/
        lv_user_name               VARCHAR2 (100);
        lv_email                   VARCHAR2 (100);
        lv_display_name            VARCHAR2 (100);
        lv_user_exception          EXCEPTION;
        /************End modification for version 1.1 ****************/
        /************Start modification for version 1.5 ****************/
        lv_lock_exception          EXCEPTION;
        l_x_line_rec               oe_order_pub.line_rec_type;
    /************End modification for version 1.5 ****************/
    BEGIN
        p_out_err_flag                                       := 'N';
        l_return_status                                      := NULL;
        l_msg_data                                           := NULL;
        l_message_data                                       := NULL;
        ln_resp_id                                           := NULL;
        ln_resp_appl_id                                      := NULL;

        write_to_table (
               'batch_id: '
            || p_in_batch_id
            || 'and header_id: '
            || p_in_header_id
            || 'and line_id: '
            || p_in_line_id,
            'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');

        BEGIN
            SELECT created_by
              INTO ln_user_id
              FROM xxdo.xxd_ont_product_move_hdr_stg_t
             WHERE batch_id = p_in_batch_id AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_user_id   := NULL;
                write_to_table ('User Id fetch error',
                                'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
                RAISE lv_exception;
        END;

        /************Start modification for version 1.1 ****************/
        BEGIN
            fetch_ad_user_email (p_in_user_id => ln_user_id, p_out_user_name => lv_user_name, p_out_display_name => lv_display_name
                                 , p_out_email_id => lv_email);

            IF lv_user_name IS NULL OR lv_user_name = ''
            THEN
                RAISE lv_user_exception;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE lv_user_exception;
        END;

        /************End modification for version 1.1 ****************/
        BEGIN
            --Getting the responsibility and application to initialize and set the context to reschedule order lines
            --Making sure that the initialization is set for proper OM responsibility
            SELECT frv.responsibility_id, frv.application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM apps.fnd_profile_options_vl fpo, apps.fnd_responsibility_vl frv, apps.fnd_profile_option_values fpov,
                   apps.hr_organization_units hou
             WHERE     1 = 1
                   AND hou.organization_id = p_in_org_id
                   AND fpov.profile_option_value =
                       TO_CHAR (hou.organization_id)
                   AND fpo.profile_option_id = fpov.profile_option_id
                   AND fpo.user_profile_option_name = 'MO: Operating Unit'
                   AND frv.responsibility_id = fpov.level_value
                   AND frv.application_id = 660                          --ONT
                   AND frv.responsibility_name LIKE
                           'Deckers Order Management User%' --OM Responsibility
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (frv.start_date)
                                           AND TRUNC (
                                                   NVL (frv.end_date,
                                                        SYSDATE))
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE lv_exception;
        END;

        --write_to_table ('before lock row:',
        --           'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');

        -- Try locking all lines in the order
        /*oe_line_util.lock_rows (p_header_id       => p_in_header_id,
                                x_line_tbl        => l_line_tbl,
                                x_return_status   => lc_lock_status);*/
        /************Start modification for version 1.6 ****************/
        /*oe_line_util.lock_row
       (p_line_id => p_in_line_id,
       p_x_line_rec => l_x_line_rec,
       x_return_status => lc_lock_status
       );

        IF lc_lock_status = 'S'
        THEN*/
        /************End modification for version 1.6 ****************/
        -- write_to_table ('lock row success:',
        --         'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
        fnd_global.apps_initialize (user_id        => ln_user_id,
                                    resp_id        => ln_resp_id, --Deckers Order Management User - US
                                    resp_appl_id   => ln_resp_appl_id); --Order Management
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', p_in_org_id);
        write_to_table ('set_policy_context:',
                        'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
        l_line_tbl_index                                     := 1;
        /************Start modification for version 1.5 ****************/
        l_line_tbl (l_line_tbl_index)                        := oe_order_pub.g_miss_line_rec;
        /************End modification for version 1.5 ****************/
        l_line_tbl (l_line_tbl_index).operation              := oe_globals.g_opr_update;
        l_line_tbl (l_line_tbl_index).org_id                 := p_in_org_id; --org_id;
        l_line_tbl (l_line_tbl_index).header_id              := p_in_header_id; --header_id;
        l_line_tbl (l_line_tbl_index).line_id                := p_in_line_id; --line_id;
        l_line_tbl (l_line_tbl_index).schedule_action_code   :=
            p_in_schedule_action_code;                     --scheduling Action
        write_to_table ('gc_no_unconsumption:' || p_in_schedule_action_code,
                        'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
        XXD_ONT_BULK_CALLOFF_PKG.gc_no_unconsumption         := 'Y';
        write_to_table ('Calling process_order',
                        'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_true,
            p_return_values            => fnd_api.g_true,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => l_return_status,
            x_msg_count                => l_msg_count,
            x_msg_data                 => l_msg_data,
            p_header_rec               => l_header_rec,
            p_line_tbl                 => l_line_tbl,
            p_action_request_tbl       => l_action_request_tbl,
            x_header_rec               => l_header_rec_x,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => x_header_adj_tbl,
            x_header_adj_val_tbl       => x_header_adj_val_tbl,
            x_header_price_att_tbl     => x_header_price_att_tbl,
            x_header_adj_att_tbl       => x_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
            x_header_scredit_tbl       => x_header_scredit_tbl,
            x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
            x_line_tbl                 => l_line_tbl_x,
            x_line_val_tbl             => x_line_val_tbl,
            x_line_adj_tbl             => x_line_adj_tbl,
            x_line_adj_val_tbl         => x_line_adj_val_tbl,
            x_line_price_att_tbl       => x_line_price_att_tbl,
            x_line_adj_att_tbl         => x_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
            x_line_scredit_tbl         => x_line_scredit_tbl,
            x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
            x_lot_serial_tbl           => x_lot_serial_tbl,
            x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
            x_action_request_tbl       => l_action_request_tbl);
        write_to_table ('after call process_order:' || l_return_status,
                        'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');

        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            IF p_in_schedule_action_code = 'SCHEDULE'
            THEN
                write_to_table (
                       'Order update SCHEDULE in success for user '
                    || lv_display_name,
                    'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');

                IF TO_CHAR (
                       l_line_tbl_x (l_line_tbl_index).schedule_ship_date,
                       'DD-MON-RRRR')
                       IS NOT NULL
                THEN
                    write_to_table (
                        'Order update success for user ' || lv_display_name,
                        'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
                END IF;
            ELSE
                write_to_table (
                    'Order update success for user' || lv_display_name,
                    'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
            END IF;
        ELSE
            FOR i IN 1 .. l_msg_count
            LOOP
                oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                , p_msg_index_out => l_msg_index_out);

                l_message_data   :=
                    SUBSTR (l_message_data || l_msg_data, 1, 2000);
                write_to_table (
                    SUBSTR (
                           'API err for line id:'
                        || p_in_line_id
                        || ' msg:'
                        || l_message_data,
                        1,
                        2000),
                    'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
            END LOOP;
        /*IF p_in_batch_commit = 'Y'
     THEN
      --do we need to raise exception to stop further processing??
      ROLLBACK;
     END IF;*/
        END IF;

        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            IF p_in_schedule_action_code = 'SCHEDULE'
            THEN
                IF TO_CHAR (
                       l_line_tbl_x (l_line_tbl_index).schedule_ship_date,
                       'DD-MON-RRRR')
                       IS NOT NULL
                THEN
                    UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
                       SET status = 'SUCCESS', last_update_date = SYSDATE
                     WHERE batch_id = p_in_batch_id;

                    UPDATE xxdo.xxd_ont_pdt_move_dtls_stg_t
                       SET status = 'SUCCESS', last_update_date = SYSDATE
                     WHERE     batch_id = p_in_batch_id
                           AND line_id = p_in_line_id;

                    IF p_in_batch_commit = 'N'
                    THEN
                        COMMIT;
                    END IF;
                ELSE
                    write_to_table (
                        SUBSTR (
                               'API err for line id:'
                            || p_in_line_id
                            || ' msg:'
                            || l_message_data,
                            1,
                            2000),
                        'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
                    RAISE lv_api_exception;
                END IF;
            ELSE
                UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
                   SET status = 'SUCCESS', last_update_date = SYSDATE
                 WHERE batch_id = p_in_batch_id;

                UPDATE xxdo.xxd_ont_pdt_move_dtls_stg_t
                   SET status = 'SUCCESS', last_update_date = SYSDATE
                 WHERE batch_id = p_in_batch_id AND line_id = p_in_line_id;

                IF p_in_batch_commit = 'N'
                THEN
                    COMMIT;
                END IF;
            END IF;
        ELSE
            write_to_table (
                SUBSTR (
                       'API err for line id:'
                    || p_in_line_id
                    || ' msg:'
                    || l_message_data,
                    1,
                    2000),
                'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
            RAISE lv_api_exception;
        END IF;
    /************Start modification for version 1.6 ****************/
    /************Start modification for version 1.5 ****************/
    -- ELSE
    --  write_to_table ('Another user is modifying the record:'||p_in_line_id ,'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
    -- RAISE lv_lock_exception;
    /************End modification for version 1.5 ****************/
    -- END IF;
    /************End modification for version 1.6 ****************/
    EXCEPTION
        /************Start modification for version 1.6 ****************/
        /************Start modification for version 1.5 ****************/
        /*WHEN lv_lock_exception
         THEN
            write_to_table ('in lv_lock_exception Another user is modifying the record:'||p_in_line_id,'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
            UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
            SET status ='ERROR',
             last_update_date = SYSDATE
          WHERE batch_id = p_in_batch_id;

          UPDATE xxdo.XXD_ONT_PDT_MOVE_DTLS_STG_T
             SET status ='ERROR',
              error_message='Another user is modifying the record',
              last_update_date = SYSDATE
           WHERE batch_id = p_in_batch_id
           AND line_id = p_in_line_id;
         IF p_in_batch_commit = 'Y'
         THEN
                 write_to_table ('batch commit Y and another user is modifying the record','XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
           p_out_err_flag:='Y';
           p_out_err_msg:= 'Another user is modifying the record';
         ELSE
          COMMIT;
         END IF;*/
        /************End modification for version 1.5 ****************/
        /************End modification for version 1.6 ****************/
        /************Start modification for version 1.1 ****************/
        WHEN lv_user_exception
        THEN
            p_out_err_msg   := 'User does not have valid oracle access';
            write_to_table ('User does not have valid oracle access',
                            'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
        /************End modification for version 1.1 ****************/
        WHEN lv_api_exception
        THEN
            UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
               SET status = 'ERROR', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            UPDATE xxdo.xxd_ont_pdt_move_dtls_stg_t
               SET status = 'ERROR', error_message = SUBSTR (NVL (l_message_data, 'API did not process the line for user ' || lv_display_name), 1, 2000), last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id AND line_id = p_in_line_id;

            IF p_in_batch_commit = 'Y'
            THEN
                write_to_table (
                       'batch commit Y l_message_data:'
                    || SUBSTR (l_message_data, 1, 2000),
                    'XXD_ONT_PRODUCT_MV_PKG.submit_order_p');
                p_out_err_flag   := 'Y';
                p_out_err_msg    :=
                    SUBSTR (
                        NVL (l_message_data, 'API did not process the line'),
                        1,
                        2000);
            ELSE
                COMMIT;
            END IF;
        WHEN lv_exception
        THEN
            UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
               SET status = 'ERROR', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id;

            UPDATE xxdo.xxd_ont_pdt_move_dtls_stg_t
               SET status = 'ERROR', error_message = 'Error while fetching responsibility or user id ', last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id AND line_id = p_in_line_id;

            IF p_in_batch_commit = 'Y'
            THEN
                p_out_err_flag   := 'Y';
                p_out_err_msg    :=
                    'Error while fetching responsibility or user id ';
            END IF;
        WHEN OTHERS
        THEN
            UPDATE xxdo.xxd_ont_product_move_hdr_stg_t
               SET status   = 'ERROR'
             WHERE batch_id = p_in_batch_id;

            UPDATE xxdo.xxd_ont_pdt_move_dtls_stg_t
               SET status = 'ERROR', error_message = 'Unxpected error while processing order data for user ' || lv_display_name, last_update_date = SYSDATE
             WHERE batch_id = p_in_batch_id AND line_id = p_in_line_id;

            IF p_in_batch_commit = 'Y'
            THEN
                p_out_err_flag   := 'Y';
                p_out_err_msg    :=
                       'Unxpected error while processing order data for user '
                    || lv_display_name;
            END IF;
    END submit_order_p;

    PROCEDURE fetch_stg_hdr_data (p_in_user_id IN NUMBER, p_out_hdr OUT SYS_REFCURSOR, p_out_err_msg OUT VARCHAR2)
    IS
        /************Start modification for version 1.1 ****************/
        lv_user_name        VARCHAR2 (100);
        lv_email            VARCHAR2 (100);
        lv_display_name     VARCHAR2 (100);
        lv_user_exception   EXCEPTION;
        /************End modification for version 1.1 ****************/
        lv_exception        EXCEPTION;
    BEGIN
        /************Start modification for version 1.1 ****************/
        BEGIN
            fetch_ad_user_email (p_in_user_id => p_in_user_id, p_out_user_name => lv_user_name, p_out_display_name => lv_display_name
                                 , p_out_email_id => lv_email);

            IF lv_user_name IS NULL OR lv_user_name = ''
            THEN
                RAISE lv_user_exception;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE lv_user_exception;
        END;

        /************End modification for version 1.1 ****************/
        BEGIN
            OPEN p_out_hdr FOR
                  SELECT xpmh.batch_id, mp.organization_code warehouse, xpmh.style,
                         xpmh.color, xpmh.creation_date saved_date, xpmh.status,
                         xpmh.batch_mode, xpmh.sku
                    FROM xxdo.xxd_ont_product_move_hdr_stg_t xpmh, mtl_parameters mp
                   WHERE     xpmh.organization_id = mp.organization_id
                         AND xpmh.created_by = p_in_user_id
                ORDER BY xpmh.batch_id DESC;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_err_msg   :=
                       'Error while fetching history header details for user '
                    || lv_display_name;
                write_to_table (
                       'Error while fetching history header details for user '
                    || lv_display_name,
                    'XXD_ONT_PRODUCT_MV_PKG.fetch_stg_hdr_data');
        END;
    EXCEPTION
        /************Start modification for version 1.1 ****************/
        WHEN lv_user_exception
        THEN
            p_out_err_msg   := 'User does not have valid oracle access';
            write_to_table ('User does not have valid oracle access',
                            'XXD_ONT_PRODUCT_MV_PKG.fetch_stg_hdr_data');
        /************End modification for version 1.1 ****************/
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                'Error in fetch_stg_hdr_data for user ' || lv_display_name;
            write_to_table (
                'Error in fetch_stg_hdr_data for user ' || lv_display_name,
                'XXD_ONT_PRODUCT_MV_PKG.fetch_stg_hdr_data');
    END fetch_stg_hdr_data;

    PROCEDURE fetch_stg_line_data (p_in_user_id IN NUMBER, p_in_batch_id IN NUMBER, p_out_line OUT SYS_REFCURSOR
                                   , p_out_err_msg OUT VARCHAR2)
    IS
        ln_plan_id          NUMBER;
        ld_plan_date        DATE;
        /************Start modification for version 1.1 ****************/
        lv_user_name        VARCHAR2 (100);
        lv_email            VARCHAR2 (100);
        lv_display_name     VARCHAR2 (100);
        lv_user_exception   EXCEPTION;
        /************End modification for version 1.1 ****************/
        lv_exception        EXCEPTION;
    BEGIN
        /************Start modification for version 1.1 ****************/
        BEGIN
            fetch_ad_user_email (p_in_user_id => p_in_user_id, p_out_user_name => lv_user_name, p_out_display_name => lv_display_name
                                 , p_out_email_id => lv_email);

            IF lv_user_name IS NULL OR lv_user_name = ''
            THEN
                RAISE lv_user_exception;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE lv_user_exception;
        END;

        /************End modification for version 1.1 ****************/
        BEGIN
            OPEN p_out_line FOR
                  SELECT ooha.order_number, ooha.cust_po_number, oola.line_number || '.' || oola.shipment_number line_number,
                         oola.ordered_item, oola.ordered_quantity, TRUNC (oola.request_date) request_date,
                         TRUNC (oola.schedule_ship_date) schedule_ship_date, xpmd.action, xpmd.status,
                         xpmd.rec_type, xpmd.error_message
                    FROM xxdo.xxd_ont_pdt_move_dtls_stg_t xpmd, oe_order_lines_all oola, oe_order_headers_all ooha
                   WHERE     oola.line_id = xpmd.line_id
                         AND ooha.header_id = oola.header_id
                         AND xpmd.header_id = ooha.header_id
                         AND xpmd.batch_id = p_in_batch_id
                         AND xpmd.created_by = p_in_user_id
                ORDER BY xpmd.batch_id DESC;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_err_msg   :=
                       'Error while fetching history details for user '
                    || lv_display_name;
                write_to_table (
                       'Error while fetching history details for user'
                    || lv_display_name,
                    'XXD_ONT_PRODUCT_MV_PKG.fetch_stg_line_data');
        END;
    EXCEPTION
        /************Start modification for version 1.1 ****************/
        WHEN lv_user_exception
        THEN
            p_out_err_msg   := 'User does not have valid oracle access';
            write_to_table ('User does not have valid oracle access',
                            'XXD_ONT_PRODUCT_MV_PKG.fetch_stg_line_data');
        /************End modification for version 1.1 ****************/
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                'Error in fetch_stg_line_data for user' || lv_display_name;
            write_to_table (
                'Error in fetch_stg_line_data for user' || lv_display_name,
                'XXD_ONT_PRODUCT_MV_PKG.fetch_stg_line_data');
    END fetch_stg_line_data;

    PROCEDURE schedule_order (p_in_batch_id   IN     NUMBER,
                              p_out_err_msg      OUT VARCHAR2)
    IS
        ln_job   NUMBER;
    BEGIN
        --set the value for scheduler job
        --DBMS_SCHEDULER.set_job_argument_value (
        --  job_name            => 'apps.process_order_job',
        --  argument_position   => 1,
        --  argument_value      => p_in_batch_id);

        --run the scheduler job
        -- DBMS_SCHEDULER.run_job (job_name              => 'apps.process_order_job',
        /************Start modification for version 1.5 ****************/
        --                         use_current_session   => TRUE);
        /************End modification for version 1.5 ****************/
        /************Start modification for version 1.6 ****************/
        DBMS_JOB.SUBMIT (
            ln_job,
               ' 
    begin
      apps.xxd_ont_product_mv_pkg.process_order_api_p('''
            || p_in_batch_id
            || '''); end; ');
        COMMIT;
    /************End modification for version 1.6 ****************/
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_err_msg   :=
                SUBSTR ('Error in schedule_order proc' || SQLERRM, 1, 4000);

            write_to_table (
                SUBSTR ('Error in schedule_order proc' || SQLERRM, 1, 4000),
                'XXD_ONT_PRODUCT_MV_PKG.schedule_order');
    END schedule_order;
END xxd_ont_product_mv_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_PRODUCT_MV_PKG TO XXORDS
/
