--
-- XXD_ONT_PM_PARSE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_PM_PARSE_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_PM_PARSE_PKG
    -- Design       : This package will be used to parse json data from UI
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 24-MAR-2021    Infosys              1.0    Initial Version
    -- 26-May-2021 Infosys              1.1    Created a procedure to fetch username and id
    -- 09-Jun-2021 Infosys              1.2    modified for brand query fix
    -- #########################################################################################################################

    PROCEDURE fetch_batch_id (p_out_batch_id OUT NUMBER)
    IS
    BEGIN
        SELECT xxdo.xxd_product_move_batch_id_s.NEXTVAL
          INTO p_out_batch_id
          FROM DUAL;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_batch_id   := 9999999999;
    END fetch_batch_id;

    PROCEDURE parse_data (p_input_data     IN     CLOB,
                          p_out_err_msg       OUT VARCHAR2,
                          p_out_batch_id      OUT NUMBER)
    IS
        l_input_data_tab       PM_TBL_TYPE;
        ln_count               NUMBER;
        ln_user_id             NUMBER;
        ln_org_id              NUMBER;
        ln_batch_id            NUMBER;
        /************Start modification for version 1.1 ****************/
        lv_user_name           VARCHAR2 (100);
        lv_email               VARCHAR2 (100);
        lv_display_name        VARCHAR2 (100);
        /************End modification for version 1.1 ****************/
        lv_org                 VARCHAR2 (10);
        lv_style_color         VARCHAR2 (240);
        lv_brand               VARCHAR2 (50);
        lv_brand_user_access   VARCHAR2 (10);
        lv_wh_user_access      VARCHAR2 (10);
        lv_instance_name       VARCHAR2 (10);
        lv_exception           EXCEPTION;
        lv_access_exception    EXCEPTION;
    BEGIN
        APEX_JSON.parse (p_input_data);

        lv_org             := APEX_JSON.get_varchar2 (p_path => 'warehouse');
        ln_batch_id        := APEX_JSON.get_number (p_path => 'batch_id');
        ln_user_id         := APEX_JSON.get_varchar2 (p_path => 'user_id');
        lv_style_color     := APEX_JSON.get_varchar2 (p_path => 'style_color');
        lv_instance_name   := APEX_JSON.get_varchar2 (p_path => 'instance');

        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'ln_user_id' || ln_user_id,
            'XXD_ONT_PM_PARSE_PKG.parse_data');
        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'lv_org' || lv_org,
            'XXD_ONT_PM_PARSE_PKG.parse_data');
        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'ln_batch_id' || ln_batch_id,
            'XXD_ONT_PM_PARSE_PKG.parse_data');
        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'lv_style_color' || lv_style_color,
            'XXD_ONT_PM_PARSE_PKG.parse_data');
        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'lv_instance_name' || lv_instance_name,
            'XXD_ONT_PM_PARSE_PKG.parse_data');

        /************Start modification for version 1.1 ****************/
        BEGIN
            XXD_ONT_PRODUCT_MV_PKG.fetch_ad_user_email (
                p_in_user_id         => ln_user_id,
                p_out_user_name      => lv_user_name,
                p_out_display_name   => lv_display_name,
                p_out_email_id       => lv_email);
        EXCEPTION
            WHEN OTHERS
            THEN
                XXD_ONT_PRODUCT_MV_PKG.write_to_table (
                       'Unexpected error while fetching user id for the input user '
                    || ln_user_id,
                    'XXD_ONT_PM_PARSE_PKG.parse_data');
        END;

        /************End modification for version 1.1 ****************/
        BEGIN
            SELECT mc.segment1
              INTO lv_brand
              FROM mtl_categories_b mc
             WHERE     mc.attribute7 =
                       SUBSTR (lv_style_color,
                               1,
                               INSTR (lv_style_color, '-', 1) - 1)
                   AND mc.attribute8 =
                       SUBSTR (lv_style_color,
                               INSTR (lv_style_color, '-', 1) + 1)
                   AND mc.disable_date IS NULL
                   /************Start modification for version 1.2 ****************/
                   AND EXISTS
                           (SELECT 1
                              FROM mtl_item_categories mic
                             WHERE mic.category_id = mc.category_id);
        /************End modification for version 1.2 ****************/
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RAISE lv_exception;
            WHEN OTHERS
            THEN
                RAISE lv_exception;
        END;

        lv_brand_user_access   :=
            XXD_ONT_PRODUCT_MV_PKG.user_access (
                lv_user_name,
                'BRAND',
                lv_brand,
                NVL (lv_instance_name, 'DEV'));
        lv_wh_user_access   :=
            XXD_ONT_PRODUCT_MV_PKG.user_access (
                lv_user_name,
                'WAREHOUSE',
                lv_org,
                NVL (lv_instance_name, 'DEV'));

        IF lv_brand_user_access = 'N' OR lv_wh_user_access = 'N'
        THEN
            RAISE lv_access_exception;
        END IF;

        IF ln_batch_id IS NULL
        THEN
            BEGIN
                SELECT xxdo.xxd_product_move_batch_id_s.NEXTVAL
                  INTO ln_batch_id
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_batch_id   := 9999999999;
            END fetch_batch_id;
        END IF;

        BEGIN
            SELECT organization_id
              INTO ln_org_id
              FROM mtl_parameters
             WHERE organization_code = lv_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                XXD_ONT_PRODUCT_MV_PKG.write_to_table (
                       'Unexpected error while fetching organization_id for warehouse '
                    || lv_org,
                    'XXD_ONT_PM_PARSE_PKG.parse_data');
        END;

        ln_count           := APEX_JSON.get_count (p_path => 'productmove');
        l_input_data_tab   := PM_TBL_TYPE ();

        FOR i IN 1 .. ln_count
        LOOP
            l_input_data_tab.EXTEND;
            l_input_data_tab (i)   :=
                PM_REC_TYPE (NULL, NULL, NULL,
                             NULL, NULL, NULL,
                             NULL, NULL, NULL,
                             NULL);

            l_input_data_tab (i).attribute1   :=
                APEX_JSON.get_varchar2 (p_path   => 'productmove[%d].type',
                                        p0       => i);
            l_input_data_tab (i).attribute2   :=
                APEX_JSON.get_varchar2 (
                    p_path   => 'productmove[%d].batch_mode',
                    p0       => i);
            l_input_data_tab (i).attribute6   :=
                APEX_JSON.get_number (p_path   => 'productmove[%d].header_id',
                                      p0       => i);
            l_input_data_tab (i).attribute7   :=
                APEX_JSON.get_number (p_path   => 'productmove[%d].line_id',
                                      p0       => i);
            l_input_data_tab (i).attribute8   :=
                APEX_JSON.get_number (
                    p_path   => 'productmove[%d].inventory_item_id',
                    p0       => i);
            l_input_data_tab (i).attribute3   :=
                APEX_JSON.get_varchar2 (p_path   => 'productmove[%d].action',
                                        p0       => i);
        END LOOP;

        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'calling insert_stg_data for user  ' || lv_display_name,
            'XXD_ONT_PM_PARSE_PKG.parse_data');

        XXD_ONT_PRODUCT_MV_PKG.insert_stg_data (ln_user_id,
                                                ln_org_id,
                                                ln_batch_id,
                                                lv_style_color,
                                                l_input_data_tab,
                                                p_out_err_msg);

        XXD_ONT_PRODUCT_MV_PKG.write_to_table (
            'After calling insert_stg_data:' || p_out_err_msg,
            'XXD_ONT_PM_PARSE_PKG.parse_data');

        p_out_err_msg      := p_out_err_msg || SQLERRM;
        p_out_batch_id     := ln_batch_id;
    EXCEPTION
        WHEN lv_access_exception
        THEN
            p_out_err_msg   :=
                   'User '
                || lv_display_name
                || ' doesnt have access to warehouse '
                || lv_org
                || ' or brand '
                || lv_brand;
            XXD_ONT_PRODUCT_MV_PKG.write_to_table (
                   'User '
                || lv_display_name
                || ' doesnt have access to warehouse or brand',
                'XXD_ONT_PM_PARSE_PKG.parse_data');
        WHEN lv_exception
        THEN
            p_out_err_msg   :=
                   'Style-Color combination/warehouse is not received or brand is not fetched for user '
                || lv_display_name;
            XXD_ONT_PRODUCT_MV_PKG.write_to_table (
                   'Style-Color combination/warehouse is not received or brand is not fetched for user  '
                || lv_display_name,
                'XXD_ONT_PM_PARSE_PKG.parse_data');
        WHEN OTHERS
        THEN
            p_out_err_msg   := 'ERROR' || SQLERRM;
            XXD_ONT_PRODUCT_MV_PKG.write_to_table (
                'Unexpected error while parsing data' || SQLERRM,
                'XXD_ONT_PM_PARSE_PKG.parse_data');
    END parse_data;
END XXD_ONT_PM_PARSE_PKG;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_PM_PARSE_PKG TO XXORDS
/
