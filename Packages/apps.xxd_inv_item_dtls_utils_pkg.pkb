--
-- XXD_INV_ITEM_DTLS_UTILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_ITEM_DTLS_UTILS_PKG"
AS
    -- ####################################################################################################################
    -- Package      : xxd_inv_item_dtls_utils_pkg
    -- Design       : This package will be used to fetch values required for LOV
    --                in the product move tool. This package will also  search
    --                for order details based on user entered data.
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 23-Feb-2021    Infosys              1.0    Initial Version
    -- 24-Aug-2021    Infosys              1.1    Modified to add request to date condtion
    -- 01-Sep-2021    Jayarajan A K        1.2    Modified to fetch only PROD Item Types
    -- 01-Sep-2021    Infosys              1.3    Modified customer search
    -- 25-Nov-2021 Infosys     2.0 Modified to fetch super user parameter
    --14-Feb-2022     Infosys              3.0 HOKA changes
    -- 06-May-2022    Infosys              4.0    Modified to include search page
    -- 20-Jun-2022    Jayarajan A K        4.1    Modified for Genesis CCR
    --29-Aug-2022     Infosys              4.2 Customer search performance fix
    -- 07-Oct-2022 Infosys              5.0 Sales manager email id in loopkup
    -- #########################################################################################################################
    --start v4.0
    PROCEDURE get_pmt_warehouse (p_in_user_name IN VARCHAR2, p_in_instance_name IN VARCHAR2, p_out_warehouse OUT CLOB)
    IS
        l_out_warehouse       SYS_REFCURSOR;
        lv_query              VARCHAR2 (2000);
        lv_nodata_exception   EXCEPTION;

        TYPE so_line_rec_type IS RECORD
        (
            warehouse    VARCHAR2 (10)
        );

        TYPE so_line_type IS TABLE OF so_line_rec_type
            INDEX BY BINARY_INTEGER;

        so_line_rec           so_line_type;

        TYPE so_line_typ IS REF CURSOR;

        so_line_cur           so_line_typ;
    BEGIN
        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
               'get_pmt_warehouse start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'get_pmt_warehouse p_in_user_name:' || p_in_user_name,
            'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
        /*OPEN p_out_warehouse FOR
   SELECT DISTINCT  AD_SECURITY_SEG_VALUE
      FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata('(&(objectClass=user)(displayName=p_in_user_name))')) a
      CROSS JOIN TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata('(&(objectClass=user)(displayName=p_in_user_name))')) b
      ,xxdo.XXD_LDAP_SECURITY_MASTER_T xopsmt
      WHERE UPPER(a.attr) = UPPER('displayName')
      AND UPPER(b.attr) = UPPER('memberOf')
      AND UPPER(b.val) LIKE UPPER('%ORA_PMT_%')
      AND xopsmt.AD_SECURITY_OBJ_NAME = SUBSTR(b.val,4,INSTR(b.val,'OU',1,1)-5)
       AND AD_SECURITY_SEG_NAME ='WAREHOUSE'
        AND instance_name ='DEV'; */

        lv_query          :=
               'SELECT AD_SECURITY_SEG_VALUE  warehouse
						FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(displayName='
            || p_in_user_name
            || '))'')) a 
						CROSS JOIN TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(displayName='
            || p_in_user_name
            || '))'')) b 
						,xxdo.XXD_LDAP_SECURITY_MASTER_T xopsmt
						WHERE UPPER(a.attr) = UPPER(''displayName'')
						AND UPPER(b.attr) = UPPER(''memberOf'')
						AND UPPER(b.val) LIKE UPPER(''%ORA_PMT_%'')
						AND xopsmt.AD_SECURITY_OBJ_NAME = SUBSTR(b.val,4,INSTR(b.val,''OU'',1,1)-5)
						AND AD_SECURITY_SEG_NAME =''WAREHOUSE''
						  AND instance_name ='''
            || p_in_instance_name
            || '''';

        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'lv_query:' || lv_query,
            'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');

        OPEN so_line_cur FOR lv_query;

        FETCH so_line_cur BULK COLLECT INTO so_line_rec;

        CLOSE so_line_cur;

        --BEGIN
        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'before write output: ',
            'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
        --ln_pre_headerid:=-1;
        APEX_JSON.initialize_clob_output;
        --APEX_JSON.open_object('warehouse'); -- {
        APEX_JSON.open_array;
        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'open header array: ',
            'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');

        BEGIN
            FOR i IN so_line_rec.FIRST .. so_line_rec.LAST
            LOOP
                XXD_ONT_PRODUCT_MV_PKG.write_to_table (
                    'in loop warehouse: ' || so_line_rec (i).warehouse,
                    'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');


                APEX_JSON.write (so_line_rec (i).warehouse);
            --ln_pre_headerid:= so_line_rec(i).header_id;
            END LOOP;

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                   'end loop: '
                || ': '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
                'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RAISE lv_nodata_exception;
            WHEN OTHERS
            THEN
                RAISE lv_nodata_exception;
        END;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'b4 close: '
            || ': '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
        --APEX_JSON.close_object;
        APEX_JSON.close_array;
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'after close: '
            || ': '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
        p_out_warehouse   := APEX_JSON.get_clob_output;
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'after print output: '
            || ': '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
        APEX_JSON.free_output;
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'end get_pmt_warehouse: '
            || ': '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
    --p_out_warehouse:=l_out_warehouse;
    EXCEPTION
        WHEN lv_nodata_exception
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'No data fetched for the search criteria  ',
                'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
        WHEN OTHERS
        THEN
            XXD_ONT_PRODUCT_MV_PKG.write_to_table (
                'Unexpected error while fetching pmt warehouse',
                'xxd_inv_item_dtls_utils_pkg.get_pmt_warehouse');
    END get_pmt_warehouse;

    --End v4.0
    PROCEDURE user_validation (p_in_user_email     IN     VARCHAR2,
                               p_out_user_name        OUT VARCHAR2,
                               p_out_brand            OUT VARCHAR2,
                               p_out_ou_id            OUT NUMBER,
                               p_out_salesrep_id      OUT NUMBER,
                               p_out_user_id          OUT NUMBER,
                               --Start changes v1.1
                               p_out_threshold        OUT NUMBER,
                               --End changes v1.1
                               --Start changes v2.0
                               p_out_super_user       OUT VARCHAR2,
                               p_out_ou_name          OUT VARCHAR2,
                               --End changes v2.0
                               --Start changes v5.0
                               p_out_sales_mgr        OUT VARCHAR2,
                               --End changes v5.0
                               p_out_err_msg          OUT VARCHAR2)
    IS
        lv_query             VARCHAR2 (2000);
        lv_query1            VARCHAR2 (2000);
        lv_user_name         VARCHAR2 (100);
        lv_disp_name         VARCHAR2 (100);
        lv_salerep_name      VARCHAR2 (100);
        lv_brand             VARCHAR2 (100);
        --Start changes v2.0
        lv_super_user        VARCHAR2 (10);
        lv_ou_name           VARCHAR2 (50);
        --End changes v2.0
        --Start changes v5.0
        lv_sales_manager     VARCHAR2 (250);
        --Start changes v5.0
        ln_ou_id             NUMBER;
        ln_salesrep_id       NUMBER;
        ln_user_id           NUMBER;
        --Start changes v1.1
        ln_rq_dt_threshold   NUMBER;
        --End changes v1.1
        lv_user_exception    EXCEPTION;
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in start user_validation'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.user_validation');
        lv_query            :=
               'SELECT val  
					FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(mail='
            || p_in_user_email
            || '))'')) a  
				   WHERE UPPER(a.attr) = UPPER(''displayName'')';

        EXECUTE IMMEDIATE lv_query
            INTO lv_disp_name;

        BEGIN
            SELECT flv1.attribute1, flv1.attribute2, flv1.attribute3,
                   flv1.attribute4--Start changes v2.0
                                  , flv1.attribute5--End changes v2.0
                                                   --Start changes v5.0
                                                   , flv1.attribute6
              --End changes v5.0
              INTO ln_salesrep_id, lv_brand, ln_ou_id, ln_user_id--Start changes v2.0
                                                                 ,
                                 lv_super_user--End changes v2.0
                                              --Start changes v5.0
                                              , lv_sales_manager
              --End changes v5.0
              FROM fnd_lookup_values flv1
             WHERE     1 = 1
                   AND flv1.lookup_type = 'XXD_ONT_GENESIS_SALESREP_LKP'
                   AND flv1.enabled_flag = 'Y'
                   AND flv1.LANGUAGE = USERENV ('LANG')
                   --Start v2.0
                   AND SYSDATE BETWEEN NVL (flv1.start_date_active, SYSDATE)
                                   AND NVL (flv1.end_date_active,
                                            SYSDATE + 1)
                   --End v2.0
                   AND flv1.meaning = lv_disp_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE lv_user_exception;
        END;

        --Start v2.0
        BEGIN
            SELECT flv.tag
              INTO lv_ou_name
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_ONT_GENESIS_EMAIL_REG_LKP'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = ln_ou_id
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1);

            p_out_ou_name   := lv_ou_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_ou_name   := '';
        END;

        --End v2.0
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'ln_ou_id' || ln_ou_id,
            'xxd_inv_item_dtls_utils_pkg.user_validation');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'ln_salesrep_id' || ln_salesrep_id,
            'xxd_inv_item_dtls_utils_pkg.user_validation');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_brand' || lv_brand,
            'xxd_inv_item_dtls_utils_pkg.user_validation');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'ln_user_id' || ln_user_id,
            'xxd_inv_item_dtls_utils_pkg.user_validation');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_disp_name' || lv_disp_name,
            'xxd_inv_item_dtls_utils_pkg.user_validation');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_super_user' || lv_super_user,
            'xxd_inv_item_dtls_utils_pkg.user_validation');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'p_out_ou_name' || p_out_ou_name,
            'xxd_inv_item_dtls_utils_pkg.user_validation');
        --Start changes v5.0
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_sales_manager' || lv_sales_manager,
            'xxd_inv_item_dtls_utils_pkg.user_validation');
        --Start changes v5.0
        --Start changes v3.0
        --Start changes v1.1
        --xxd_ont_genesis_main_pkg.fetch_req_dt_threshold(ln_rq_dt_threshold);
        xxd_ont_genesis_main_pkg.fetch_req_dt_threshold (
            p_in_brand        => lv_brand,
            p_in_ou_id        => ln_ou_id,
            p_out_threshold   => ln_rq_dt_threshold);
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in search_results ln_rq_dt_threshold: ' || ln_rq_dt_threshold,
            'xxd_ont_genesis_main_pkg.search_results');
        --End changes v1.1
        --End changes v3.0

        p_out_ou_id         := ln_ou_id;
        p_out_salesrep_id   := ln_salesrep_id;
        p_out_brand         := lv_brand;
        p_out_user_id       := ln_user_id;
        p_out_user_name     := lv_disp_name;
        p_out_threshold     := ln_rq_dt_threshold;
        --Start changes v2.0
        p_out_super_user    := lv_super_user;
        --End changes v2.0
        --Start changes v5.0
        p_out_sales_mgr     := lv_sales_manager;
        --End changes v5.0

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in end user_validation'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.user_validation');
    EXCEPTION
        WHEN lv_user_exception
        THEN
            p_out_user_name     := lv_disp_name;
            p_out_brand         := '';
            p_out_salesrep_id   := NULL;
            p_out_ou_id         := NULL;
            p_out_user_id       := NULL;
            p_out_err_msg       := 'User validation failed';
            p_out_super_user    := '';
            --Start changes v5.0
            p_out_sales_mgr     := '';
        --End changes v5.0

        WHEN NO_DATA_FOUND
        THEN
            p_out_user_name   := lv_disp_name;
        WHEN OTHERS
        THEN
            p_out_user_name   := lv_disp_name;
            p_out_err_msg     :=
                'Unexpected error occured in user_validation';
    END user_validation;

    --Start changes v2.0
    PROCEDURE user_email_valid (p_in_user_email IN VARCHAR2, p_in_email_groups IN VARCHAR2, p_out_valid_email OUT VARCHAR2)
    IS
        lv_query         VARCHAR2 (2000);
        lv_query1        VARCHAR2 (2000);
        lv_memberof      VARCHAR2 (100);
        lv_valid_email   VARCHAR2 (10) := 'N';
        lv_email         VARCHAR2 (100);
        --lv_memberof_typ  memberof_typ;
        lv_string        LONG DEFAULT p_in_email_groups || ',';
        lv_email_list    email_tbl_type := email_tbl_type ();
        ln_count         NUMBER;

        TYPE memberof_typ IS TABLE OF VARCHAR2 (32767)
            INDEX BY BINARY_INTEGER;

        memberof_rec     memberof_typ;

        TYPE so_member_typ IS REF CURSOR;

        so_member_cur    so_member_typ;
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in start user_email_valid'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.user_email_valid');

        LOOP
            EXIT WHEN lv_string IS NULL;
            ln_count   := INSTR (lv_string, ',');
            lv_email_list.EXTEND;
            lv_email_list (lv_email_list.COUNT)   :=
                LTRIM (RTRIM (SUBSTR (lv_string, 1, ln_count - 1)));
            lv_string   :=
                SUBSTR (lv_string, ln_count + 1);
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'lv_email_list' || lv_email_list (lv_email_list.COUNT),
                'xxd_inv_item_dtls_utils_pkg.user_email_valid');
        END LOOP;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'p_in_user_email' || p_in_user_email,
            'xxd_inv_item_dtls_utils_pkg.user_email_valid');
        lv_query   :=
               'SELECT substr(a.val,1,INSTR(a.val,'','')-1)   
					FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&(objectClass=user)(mail='
            || p_in_user_email
            || '))'')) a  
				   WHERE UPPER(a.attr) = UPPER(''memberOf'')';
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_query' || lv_query,
            'xxd_inv_item_dtls_utils_pkg.user_email_valid');

        -- EXECUTE IMMEDIATE lv_query
        --INTO lv_memberof_typ;
        OPEN so_member_cur FOR lv_query;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'in bulk collect',
            'xxd_inv_item_dtls_utils_pkg.user_email_valid');

        FETCH so_member_cur BULK COLLECT INTO memberof_rec;

        CLOSE so_member_cur;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'close bulk collect',
            'xxd_inv_item_dtls_utils_pkg.user_email_valid');

        FOR i IN 1 .. memberof_rec.COUNT
        LOOP
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'lv_memberof_typ:' || memberof_rec (i),
                'xxd_inv_item_dtls_utils_pkg.user_email_valid');
            lv_query1   :=
                   'SELECT val
				FROM TABLE(XXD_ONT_LDAP_UTILS_PKG.get_userdata(''(&('
                || memberof_rec (i)
                || '))'')) b
			  where UPPER(b.attr) = UPPER(''mail'')';
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'lv_query1:' || lv_query1,
                'xxd_inv_item_dtls_utils_pkg.user_email_valid');

            BEGIN
                EXECUTE IMMEDIATE lv_query1
                    INTO lv_email;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_email   := NULL;
            END;

            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'lv_email:' || lv_email,
                'xxd_inv_item_dtls_utils_pkg.user_email_valid');

            IF lv_email IS NOT NULL
            THEN
                xxd_ont_genesis_proc_ord_pkg.write_to_table (
                    'lv_email not null:',
                    'xxd_inv_item_dtls_utils_pkg.user_email_valid');

                FOR j IN 1 .. lv_email_list.COUNT
                LOOP
                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                        'in lv_email_list loop:',
                        'xxd_inv_item_dtls_utils_pkg.user_email_valid');
                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                        'lv_email_list:' || lv_email_list (j),
                        'xxd_inv_item_dtls_utils_pkg.user_email_valid');
                    xxd_ont_genesis_proc_ord_pkg.write_to_table (
                        'lv_email:' || lv_email,
                        'xxd_inv_item_dtls_utils_pkg.user_email_valid');

                    IF p_in_user_email = lv_email_list (j)
                    THEN
                        lv_valid_email   := 'Y';
                        EXIT;
                    ELSIF lv_email = lv_email_list (j)
                    THEN
                        lv_valid_email   := 'Y';
                        EXIT;
                    ELSE
                        lv_valid_email   := 'N';
                    END IF;
                END LOOP;

                IF lv_valid_email = 'Y'
                THEN
                    --p_out_valid_email:='Y';
                    EXIT;
                END IF;
            END IF;
        END LOOP;

        IF lv_valid_email = 'Y'
        THEN
            p_out_valid_email   := 'Y';
        ELSE
            p_out_valid_email   := 'N';
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_valid_email' || lv_valid_email,
            'xxd_inv_item_dtls_utils_pkg.user_email_valid');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'lv_email' || lv_email,
            'xxd_inv_item_dtls_utils_pkg.user_email_valid');


        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in end user_email_valid'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.user_email_valid');
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            p_out_valid_email   := 'N';
        WHEN OTHERS
        THEN
            p_out_valid_email   := 'N';
    END user_email_valid;

    --End changes v2.0

    PROCEDURE get_brand (p_out_brand OUT SYS_REFCURSOR)
    IS
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'get_brand start' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_brand');

        OPEN p_out_brand FOR
            SELECT flv.lookup_code
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_INV_ITEM_BRAND'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1);

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'get_brand end' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_brand');
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'Unexpected error while fetching brand',
                'xxd_inv_item_dtls_utils_pkg.get_brand');
    END get_brand;

    PROCEDURE get_warehouse (p_in_ou_id        IN     NUMBER,
                             p_out_warehouse      OUT SYS_REFCURSOR)
    IS
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'get_warehouse start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_warehouse');

        OPEN p_out_warehouse FOR
            SELECT organization_code warehouse, organization_name, organization_id
              FROM org_organization_definitions
             WHERE organization_id IN
                       (SELECT attribute2
                          FROM apps.fnd_lookup_values
                         WHERE     lookup_type = 'XXDO_OU_WAREHOUSE_DEFAULTS'
                               AND language = USERENV ('LANG')
                               AND enabled_flag = 'Y'
                               AND NVL (end_date_active, SYSDATE + 1) >
                                   SYSDATE
                               AND attribute1 = p_in_ou_id);

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'get_warehouse end'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_warehouse');
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'Unexpected error while fetching warehouse',
                'xxd_inv_item_dtls_utils_pkg.get_warehouse');
    END get_warehouse;

    --start ver 4.1
    PROCEDURE styl_col_with_brand (p_in_brand IN VARCHAR2, p_in_warehouse IN VARCHAR2, p_in_style IN VARCHAR2
                                   , p_out_style_clr OUT SYS_REFCURSOR)
    IS
        ln_org_id   NUMBER;
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'styl_col_with_brand start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.styl_col_with_brand');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'p_in_style:'
            || p_in_style
            || ';'
            || 'p_in_brand:'
            || p_in_brand
            || ';'
            || 'p_in_warehouse:'
            || p_in_warehouse,
            'xxd_inv_item_dtls_utils_pkg.styl_col_with_brand');

        SELECT organization_id
          INTO ln_org_id
          FROM mtl_parameters mp
         WHERE organization_code = p_in_warehouse;

        OPEN p_out_style_clr FOR
            SELECT DISTINCT mc.attribute7 || '-' || mc.attribute8 style_color, msib.description item_desc
              FROM mtl_item_categories mic, mtl_categories_b mc, mtl_system_items_b msib
             WHERE     mic.category_id = mc.category_id
                   AND mic.category_set_id = 1
                   AND mc.structure_id = 101
                   AND mic.organization_id = ln_org_id
                   AND mc.segment1 = p_in_brand
                   AND msib.inventory_item_id = mic.inventory_item_id
                   AND msib.organization_id = mic.organization_id
                   AND msib.attribute28 = 'PROD'
                   AND mc.disable_date IS NULL
                   AND mc.attribute7 || '-' || mc.attribute8 LIKE
                           p_in_style || '%'
            UNION
            SELECT DISTINCT mc.attribute7 || '-' || mc.attribute8 style_color, msib.description item_desc
              FROM mtl_item_categories mic, mtl_categories_b mc, mtl_system_items_b msib
             WHERE     mic.category_id = mc.category_id
                   AND mic.category_set_id = 1
                   AND mc.structure_id = 101
                   AND mic.organization_id = ln_org_id
                   AND mc.segment1 = p_in_brand
                   AND msib.inventory_item_id = mic.inventory_item_id
                   AND msib.organization_id = mic.organization_id
                   AND msib.attribute28 = 'PROD'
                   AND mc.disable_date IS NULL
                   AND UPPER (msib.description) LIKE '%' || p_in_style || '%';

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'styl_col_with_brand end'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.styl_col_with_brand');
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'Unexpected error while fetching style-color',
                'xxd_inv_item_dtls_utils_pkg.styl_col_with_brand');
    END styl_col_with_brand;

    --End v4.1

    PROCEDURE get_style_color (p_in_brand IN VARCHAR2, p_in_warehouse IN VARCHAR2, p_in_style IN VARCHAR2
                               , p_out_style_clr OUT SYS_REFCURSOR)
    IS
        ln_org_id   NUMBER;
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'get_style_color start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_style_color');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'p_in_style:'
            || p_in_style
            || ';'
            || 'p_in_brand:'
            || p_in_brand
            || ';'
            || 'p_in_warehouse:'
            || p_in_warehouse,
            'xxd_inv_item_dtls_utils_pkg.get_style_color');

        SELECT organization_id
          INTO ln_org_id
          FROM mtl_parameters mp
         WHERE organization_code = p_in_warehouse;

        --not using input brand since brand value is not expected
        OPEN p_out_style_clr FOR
            SELECT DISTINCT mc.attribute7 || '-' || mc.attribute8 style_color, msib.description item_desc
              FROM mtl_item_categories mic, -- mtl_category_sets mcs,
                                            mtl_categories_b mc, mtl_system_items_b msib
             WHERE     1 = 1 --mic.category_set_id     = mcs.category_set_id--ver4.1
                   AND mic.category_id = mc.category_id
                   --AND mc.structure_id         = mcs.structure_id--ver4.1
                   --AND mcs.category_set_name   = 'Inventory' --ver4.1
                   AND mic.category_set_id = 1                        --ver4.1
                   AND mc.structure_id = 101                          --ver4.1
                   AND mic.organization_id = ln_org_id
                   --Start v4.0
                   --AND mc.segment1               = p_in_brand
                   --Start v4.1
                   --AND mc.segment1               = NVL(p_in_brand,mc.segment1)
                   --End v4.1
                   --End v4.0
                   AND msib.inventory_item_id = mic.inventory_item_id
                   AND msib.organization_id = mic.organization_id
                   AND msib.attribute28 = 'PROD'                        --v1.2
                   AND mc.disable_date IS NULL
                   --AND upper(mc.attribute7)||'-'||upper(mc.attribute8)    LIKE p_in_style||'%'
                   AND mc.attribute7 || '-' || mc.attribute8 LIKE
                           p_in_style || '%'                            --v4.1
            UNION
            --start ver4.1
            /*SELECT  distinct mc.attribute7||'-'||mc.attribute8 style_color,msib.description item_desc
         FROM mtl_item_categories mic,
             mtl_category_sets mcs,
        mtl_categories_b mc ,
                 mtl_system_items_b msib
      WHERE mic.category_set_id       = mcs.category_set_id
        AND mic.category_id           = mc.category_id
        AND mc.structure_id           = mcs.structure_id
        AND mcs.category_set_name     = 'Inventory'
        AND mic.organization_id       = ln_org_id
         --Start v4.0
        --AND mc.segment1               = p_in_brand
        AND mc.segment1               = NVL(p_in_brand,mc.segment1)
        --End v4.0
           AND msib.inventory_item_id    = mic.inventory_item_id
        AND msib.organization_id      = mic.organization_id
           AND msib.attribute28 = 'PROD' --v1.2
           AND mc.disable_date          IS NULL
        AND upper(msib.description)  LIKE '%'||p_in_style||'%';*/
            SELECT DISTINCT SUBSTR (msib.segment1,
                                    1,
                                      INSTR (msib.segment1, '-', 1,
                                             2)
                                    - 1) style_color,
                            msib.description item_desc
              FROM mtl_system_items_b msib
             WHERE     msib.organization_id = ln_org_id
                   AND msib.attribute28 = 'PROD'
                   AND UPPER (msib.description) LIKE '%' || p_in_style || '%';

        --End ver4.1
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'get_style_color end'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_style_color');
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'Unexpected error while fetching style-color',
                'xxd_inv_item_dtls_utils_pkg.get_style_color');
    END get_style_color;

    PROCEDURE get_so_details (p_in_brand IN VARCHAR2, p_in_so_num IN VARCHAR2, p_in_so_cust_num IN VARCHAR2
                              , p_in_so_num_b2b IN VARCHAR2, p_in_ou_id IN NUMBER, p_out_so_dtls OUT SYS_REFCURSOR)
    IS
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'get_so_details start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_so_details');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'p_in_so_num:'
            || p_in_so_num
            || ';'
            || 'p_in_brand:'
            || p_in_brand
            || ';'
            || 'p_in_so_cust_num:'
            || p_in_so_cust_num
            || ';'
            || 'p_in_so_num_b2b:'
            || p_in_so_num_b2b
            || ';'
            || 'p_in_ou_id:'
            || p_in_ou_id,
            'xxd_inv_item_dtls_utils_pkg.get_customer');

        IF p_in_so_num IS NOT NULL
        THEN
            OPEN p_out_so_dtls FOR
                SELECT ooha.order_number, ooha.cust_po_number, ooha.orig_sys_document_ref B2B_order_number
                  FROM oe_order_headers_all ooha, fnd_lookup_values flv
                 WHERE     ooha.order_source_id = TO_NUMBER (flv.description)
                       AND ooha.order_number LIKE p_in_so_num || '%'
                       AND flv.lookup_type = 'XXD_ONT_GENESIS_ORD_SRC_LKP'
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                SYSDATE)
                                       AND NVL (flv.end_date_active,
                                                SYSDATE + 1)
                       AND ooha.attribute5 = p_in_brand
                       AND ooha.open_flag = 'Y'
                       AND ooha.booked_flag = 'Y'
                       AND ooha.org_id = p_in_ou_id
                       AND ooha.order_type_id IN
                               (SELECT TO_NUMBER (flv1.description)
                                  FROM fnd_lookup_values flv1
                                 WHERE     flv1.lookup_type =
                                           'XXD_ONT_GENESIS_ORD_TYPE_LKP'
                                       AND flv1.language = USERENV ('LANG')
                                       AND flv1.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               flv1.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               flv1.end_date_active,
                                                               SYSDATE + 1));
        ELSIF p_in_so_cust_num IS NOT NULL
        THEN
            OPEN p_out_so_dtls FOR
                SELECT ooha.order_number, ooha.cust_po_number, ooha.orig_sys_document_ref B2B_order_number
                  FROM oe_order_headers_all ooha, fnd_lookup_values flv
                 WHERE     ooha.order_source_id = TO_NUMBER (flv.description)
                       AND UPPER (ooha.cust_po_number) LIKE
                               p_in_so_cust_num || '%'
                       AND flv.lookup_type = 'XXD_ONT_GENESIS_ORD_SRC_LKP'
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                SYSDATE)
                                       AND NVL (flv.end_date_active,
                                                SYSDATE + 1)
                       AND ooha.attribute5 = p_in_brand
                       AND ooha.open_flag = 'Y'
                       AND ooha.booked_flag = 'Y'
                       AND ooha.org_id = p_in_ou_id
                       AND ooha.order_type_id IN
                               (SELECT TO_NUMBER (flv1.description)
                                  FROM fnd_lookup_values flv1
                                 WHERE     flv1.lookup_type =
                                           'XXD_ONT_GENESIS_ORD_TYPE_LKP'
                                       AND flv1.language = USERENV ('LANG')
                                       AND flv1.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               flv1.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               flv1.end_date_active,
                                                               SYSDATE + 1));
        ELSIF p_in_so_num_b2b IS NOT NULL
        THEN
            OPEN p_out_so_dtls FOR
                SELECT ooha.order_number, ooha.cust_po_number, ooha.orig_sys_document_ref B2B_order_number
                  FROM oe_order_headers_all ooha, fnd_lookup_values flv
                 WHERE     ooha.order_source_id = TO_NUMBER (flv.description)
                       AND UPPER (ooha.orig_sys_document_ref) LIKE
                               p_in_so_num_b2b || '%'
                       AND flv.lookup_type = 'XXD_ONT_GENESIS_ORD_SRC_LKP'
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                SYSDATE)
                                       AND NVL (flv.end_date_active,
                                                SYSDATE + 1)
                       AND ooha.attribute5 = p_in_brand
                       AND ooha.open_flag = 'Y'
                       AND ooha.booked_flag = 'Y'
                       AND ooha.org_id = p_in_ou_id
                       AND ooha.order_type_id IN
                               (SELECT TO_NUMBER (flv1.description)
                                  FROM fnd_lookup_values flv1
                                 WHERE     flv1.lookup_type =
                                           'XXD_ONT_GENESIS_ORD_TYPE_LKP'
                                       AND flv1.language = USERENV ('LANG')
                                       AND flv1.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               flv1.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               flv1.end_date_active,
                                                               SYSDATE + 1));
        END IF;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'get_so_details end'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_so_details');
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'Unexpected error while fetching order number',
                'xxd_inv_item_dtls_utils_pkg.get_so_number');
    END get_so_details;

    PROCEDURE get_customer (p_in_cus_name_num IN VARCHAR2, p_in_brand IN VARCHAR2, p_out_customer OUT SYS_REFCURSOR)
    IS
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'get_customer start'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_customer');
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'p_in_cus_name_num:'
            || p_in_cus_name_num
            || ';'
            || 'p_in_brand:'
            || p_in_brand,
            'xxd_inv_item_dtls_utils_pkg.get_customer');

        OPEN p_out_customer FOR
            SELECT hp.party_name customer_name, hca.account_number customer_number
              FROM hz_cust_accounts hca, hz_parties hp
             WHERE     hca.party_id = hp.party_id
                   --Start changes v1.3
                   /*AND (UPPER(hca.account_name) LIKE p_in_cus_name_num||'%'||p_in_brand
                    OR hca.account_number LIKE p_in_cus_name_num||'%'||p_in_brand)*/
                   AND (UPPER (hca.account_name) LIKE p_in_cus_name_num || '%' OR hca.account_number LIKE p_in_cus_name_num || '%')
                   --AND hca.account_number LIKE '%'||p_in_brand--ver4.2
                   AND hca.attribute1 = p_in_brand                    --ver4.2
                   --End changes v1.3
                   AND hca.attribute18 IS NULL;              --ecomm customers

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
            'get_customer end' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_customer');
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'Unexpected error while fetching customer',
                'xxd_inv_item_dtls_utils_pkg.get_customer');
    END get_customer;

    --Start changes v2.0
    PROCEDURE get_salesrep_name (p_in_salesrep_id      IN     NUMBER,
                                 p_out_salesrep_name      OUT VARCHAR2)
    IS
    BEGIN
        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in start get_salesrep_name'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_salesrep_name');

        SELECT jrrev.resource_name
          INTO p_out_salesrep_name
          FROM jtf_rs_salesreps jrs, jtf_rs_resource_extns_vl jrrev
         WHERE     jrs.salesrep_id = p_in_salesrep_id
               AND jrrev.resource_id = jrs.resource_id
               AND NVL (jrrev.start_date_active, SYSDATE - 1) < SYSDATE
               AND NVL (jrrev.end_date_active, SYSDATE + 1) > SYSDATE
               AND NVL (jrs.start_date_active, SYSDATE - 1) < SYSDATE
               AND NVL (jrs.end_date_active, SYSDATE + 1) > SYSDATE;

        xxd_ont_genesis_proc_ord_pkg.write_to_table (
               'in end get_salesrep_name'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'),
            'xxd_inv_item_dtls_utils_pkg.get_salesrep_name');
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_ont_genesis_proc_ord_pkg.write_to_table (
                'Unexpected error while fetching salesrep name',
                'xxd_inv_item_dtls_utils_pkg.get_salesrep_name');
    END get_salesrep_name;
--End changes v2.0

END xxd_inv_item_dtls_utils_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_INV_ITEM_DTLS_UTILS_PKG TO XXORDS
/
