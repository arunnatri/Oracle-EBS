--
-- XXD_QP_PRICELISTCNV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_QP_PRICELISTCNV_PKG"
AS
    /***********************************************************************************
      * Authors:
      * Date:
      * Last Update Date
      *
      * Description:   Price list Conversion API
      *
      * File Name  :
      * Object Name:
      *
      * History:
      *
      * Rev    Date           Author           Description
      * ---  ----------     -------------    -------------------------------------------
      1.0                                       Initial Draft
    ************************************************************************************/
    TYPE gtab_qp_lines_iface IS TABLE OF XXD_QP_LIST_LINES_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    PROCEDURE write_log (p_message IN VARCHAR2)
    -- +===================================================================+
    -- | Name  : WRITE_LOG                                                 |
    -- |                                                                   |
    -- | Description:       This Procedure shall write to the concurrent   |
    -- |                    program log file                               |
    -- +===================================================================+
    IS
    BEGIN
        IF gc_debug_flag = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END write_log;


    /*****************************************************************************************
     *  Function Name :   Get_Product_Value                                                  *
     *                                                                                       *
     *  Description    :   This Function shall Returns the Item or item category details     *
     *                                                                                       *
     *                                                                                       *
     *                                                                                       *
     *  Called From    :   Concurrent Program                                                *
     *                                                                                       *
     *  Parameters             Type       Description                                        *
     *  -----------------------------------------------------------------------------        *
     *  p_FlexField_Name          IN      Constant 'QP_ATTR_DEFNS_PRICING'                   *
     *  p_Context_Name            IN      Constant 'ITEM'                                    *
     *  p_attribute_name          IN      PRICING_ATTRIBUTE1,PRICING_ATTRIBUTE2              *
     *  p_attr_value              IN      ID from the 1206 system                            *
     *  x_item_name               IN      Item Segment1 from the 1206 system                 *
     *  x_category_name           IN      Category Name from the 1206 system                 *
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
      *****************************************************************************************/

    FUNCTION Get_Product_Value (p_FlexField_Name IN VARCHAR2, p_Context_Name IN VARCHAR2, p_attribute_name IN VARCHAR2
                                , p_attr_value IN VARCHAR2--                               x_item_name           OUT VARCHAR2,
                                                          --                               x_category_name       OUT VARCHAR2
                                                          )
        RETURN VARCHAR2
    IS
        l_item_id           NUMBER := NULL;
        l_category_id       NUMBER := NULL;
        l_segment_name      VARCHAR2 (240) := NULL;
        l_organization_id   VARCHAR2 (30)
                                := TO_CHAR (QP_UTIL.Get_Item_Validation_Org);
    BEGIN
        write_log ('p_attr_value  => ' || p_attr_value);

        --    x_category_name := p_attr_value;
        --    write_log ('x_category_name  => ' || x_category_name );


        IF ((p_FlexField_Name = 'QP_ATTR_DEFNS_PRICING') AND (p_Context_Name = 'ITEM'))
        THEN
            IF (p_attribute_name = 'PRICING_ATTRIBUTE1')
            THEN
                --changed the code to use G_ORGANIZATION_ID for performance problem on modifiers
                --        select concatenated_segments
                --        into x_item_name
                --        from mtl_system_items_vl@BT_READ_1206
                --        where CONCATENATED_SEGMENTS =  p_attr_value
                --        --and organization_id = l_organization_id
                --        and rownum=1;

                --            x_item_name := p_attr_value;
                --
                SELECT inventory_item_id
                  INTO l_item_id
                  FROM mtl_system_items_vl
                 WHERE concatenated_segments = p_attr_value --            and organization_id = l_organization_id
                                                            AND ROWNUM = 1;


                SELECT MAX (mic.inventory_item_id)
                  INTO l_item_id
                  FROM mtl_item_categories mic, mtl_categories_b mc, MTL_CATEGORY_SETS mcs
                 WHERE     mic.category_id = mc.category_id
                       AND mcs.structure_id = mc.structure_id
                       AND mcs.category_set_id = mic.category_set_id
                       AND mic.inventory_item_id = l_item_id
                       --           and mic.category_id = p_category
                       AND mcs.category_set_name = 'OM Sales Category';

                write_log ('l_item_id  => ' || l_item_id);

                RETURN l_item_id;
            ELSIF (p_attribute_name = 'PRICING_ATTRIBUTE2')
            THEN
                --                  x_category_name   := p_attr_value;
                --              select category_name
                --                    into x_category_name
                --                    from qp_item_categories_v@BT_READ_1206
                --                    where category_id = to_number(p_attr_value) and rownum=1;


                BEGIN
                    write_log (
                        'l_category_id x => ' || LENGTH (p_attr_value));

                    SELECT category_id
                      INTO l_category_id
                      FROM qp_item_categories_v
                     WHERE category_name = TRIM (p_attr_value) AND ROWNUM = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        write_log ('l_category_id 1 => ' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        write_log ('l_category_id  2=> ' || SQLERRM);
                END;


                write_log ('l_category_id  => ' || l_category_id);
                RETURN l_category_id;
            --
            ELSE
                l_segment_name   :=
                    QP_PRICE_LIST_LINE_UTIL.Get_Segment_Name (
                        p_FlexField_Name,
                        p_Context_Name,
                        p_attribute_name);

                RETURN (QP_PRICE_LIST_LINE_UTIL.Get_Attribute_Value (
                            p_FlexField_Name,
                            p_Context_Name,
                            l_segment_name,
                            p_attr_value));
            --
            END IF;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('l_category_id  => ' || SQLERRM);
            RETURN NULL;
    END Get_Product_Value;


    PROCEDURE create_pricelist (p_price_list_rec IN qp_price_list_pub.price_list_rec_type, p_price_list_line_tbl IN qp_price_list_pub.price_list_line_tbl_type, p_qualifiers_tbl IN qp_qualifier_rules_pub.qualifiers_tbl_type
                                , p_pricing_attr_tbl IN qp_price_list_pub.pricing_attr_tbl_type, x_return_status OUT VARCHAR2)
    /****************************************************************************************
      *  Procedure Name :   create_pricelist                                                  *
      *                                                                                       *
      *  Description    :   To Call price list API to create/update price list                *
      *                                                                                       *
      *                                                                                       *
      *  Called From    :   Concurrent Program                                                *
      *                                                                                       *
      *  Parameters             Type       Description                                        *
      *  -----------------------------------------------------------------------------        *
      *  p_price_list_rec               IN          qp_price_list_pub.price_list_rec_type     *
      *  p_price_list_line_tbl          IN          qp_price_list_pub.price_list_line_tbl_type*
      *  p_qualifiers_tbl               IN          qp_qualifier_rules_pub.qualifiers_tbl_type*
      *  p_pricing_attr_tbl             IN          qp_price_list_pub.pricing_attr_tbl_type   *
      *  x_return_status               OUT          VARCHAR2                                  *
      *                                                                                       *
      * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
      *                                                                                       *
       *****************************************************************************************/
    IS
        x_msg_count                 NUMBER := 0;
        x_msg_data                  VARCHAR2 (2000);

        l_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
        l_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
        l_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        l_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
        x_price_list_rec            qp_price_list_pub.price_list_rec_type;
        x_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
    BEGIN
        x_msg_count   := NULL;
        x_msg_data    := NULL;
        Write_log (
            'Calling qp_price_list_pub.process_price_list API to Define List Price For a Item');
        Write_log (
            '*********************************************************************************');
        oe_debug_pub.initialize;
        --oe_debug_pub.setdebuglevel(5);
        oe_msg_pub.initialize;
        qp_price_list_pub.process_price_list (
            p_api_version_number        => 1,
            p_init_msg_list             => fnd_api.g_true,
            p_return_values             => fnd_api.g_false,
            p_commit                    => fnd_api.g_false,
            x_return_status             => x_return_status,
            x_msg_count                 => x_msg_count,
            x_msg_data                  => x_msg_data,
            p_price_list_rec            => p_price_list_rec,
            p_price_list_line_tbl       => p_price_list_line_tbl,
            p_pricing_attr_tbl          => p_pricing_attr_tbl,
            p_qualifiers_tbl            => p_qualifiers_tbl,
            x_price_list_rec            => x_price_list_rec,
            x_price_list_val_rec        => x_price_list_val_rec,
            x_price_list_line_tbl       => x_price_list_line_tbl,
            x_qualifiers_tbl            => x_qualifiers_tbl,
            x_qualifiers_val_tbl        => x_qualifiers_val_tbl,
            x_pricing_attr_tbl          => x_pricing_attr_tbl,
            x_pricing_attr_val_tbl      => x_pricing_attr_val_tbl,
            x_price_list_line_val_tbl   => x_price_list_line_val_tbl);



        IF x_return_status = fnd_api.g_ret_sts_success
        THEN
            Write_log ('Item loaded successfully into the price list');
        ELSE
            --         ROLLBACK;
            x_return_status   := 'E';
            Write_log ('Error While Loading Item in Ptice List ');

            FOR k IN 1 .. x_msg_count
            LOOP
                x_msg_data   :=
                    oe_msg_pub.get (p_msg_index => k, p_encoded => 'F');
                Write_log (
                       'Error While Loading Item in Ptice List => '
                    || x_msg_data);
                xxd_common_utils.record_error (
                    p_module       => 'QP',
                    p_org_id       => gn_org_id,
                    p_program      => 'XXD QP  Price List Conversion Program',
                    p_error_msg    => x_msg_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => x_price_list_rec.name,
                    p_more_info2   => 'PRODUCT_ATTR_VALUE',
                    p_more_info3   =>
                        x_pricing_attr_tbl (1).product_attr_value);
            END LOOP;

            x_return_status   := 'E';
            Write_log (
                   'Error While Loading Item in Ptice List x_return_status => '
                || x_return_status);
            xxd_common_utils.record_error (
                p_module       => 'QP',
                p_org_id       => gn_org_id,
                p_program      => 'XXD QP  Price List Conversion Program',
                p_error_msg    => x_msg_data,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => x_price_list_rec.name,
                p_more_info2   => 'PRODUCT_ATTR_VALUE',
                p_more_info3   => x_pricing_attr_tbl (1).product_attr_value);
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            Write_log (
                'Error While Loading Item in Ptice List => ' || SQLERRM);
    END create_pricelist;


    PROCEDURE get_brand_style (p_category IN VARCHAR2, p_item_type IN VARCHAR2, l_brand OUT VARCHAR2
                               , l_season_num OUT VARCHAR2)
    IS
        l_inv_item_id   NUMBER;
        lc_err_msg      VARCHAR2 (2000);
    BEGIN
        l_brand         := NULL;
        l_season_num    := NULL;
        l_inv_item_id   := NULL;

        IF p_item_type = 'PRICING_ATTRIBUTE2'
        THEN
            --         SELECT MAX (mic.inventory_item_id)
            --           INTO l_inv_item_id
            --           FROM mtl_item_categories mic,
            --                mtl_categories_b mc,
            --                MTL_CATEGORY_SETS mcs
            --          WHERE     mic.category_id = mc.category_id
            --                AND mcs.structure_id = mc.structure_id
            --                AND mcs.category_set_id = mic.category_set_id
            --                AND mc.segment1 = p_category
            --                --           and mic.category_id = p_category
            --                AND mcs.category_set_name = 'OM Sales Category';


            SELECT BRAND, CURR_ACTIVE_SEASON
              INTO l_brand, l_season_num
              FROM XXD_COMMON_ITEMS_V
             WHERE style_desc = p_category AND ROWNUM < 2;
        ELSIF p_item_type = 'PRICING_ATTRIBUTE1'
        THEN
            SELECT BRAND, CURR_ACTIVE_SEASON
              INTO l_brand, l_season_num
              FROM XXD_COMMON_ITEMS_V
             WHERE ITEM_NUMBER = p_category AND ROWNUM < 2;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_err_msg   :=
                   'No Brand exist for this Category - '
                || SUBSTR (SQLERRM, 1, 250);
            write_log (
                   'check_price_lists_exists: '
                || lc_err_msg
                || 'p_category '
                || p_category);
    END get_brand_style;

    PROCEDURE pricelist_validation (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_action IN VARCHAR2
                                    , p_batch_id IN NUMBER)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;
        lt_qp_lines_data         gtab_qp_lines_iface;

        CURSOR cur_qp_lines (p_action VARCHAR2)
        IS
            SELECT *
              FROM XXD_QP_LIST_LINES_STG_T
             WHERE RECORD_STATUS = p_action AND batch_id = p_batch_id;

        lc_qp_lines_valid_data   VARCHAR2 (1) := gc_yes_flag;
        ln_count                 NUMBER := 0;
        x_Product_Value          VARCHAR2 (250);
        x_item_name              VARCHAR2 (250);
        lx_item_name             VARCHAR2 (240) := NULL;
        lx_category_name         VARCHAR2 (240) := NULL;
        l_brand                  VARCHAR2 (240) := NULL;
        l_season_num             VARCHAR2 (240) := NULL;

        lc_new_list_name         VARCHAR2 (240) := NULL;
        lc_item_level            VARCHAR2 (240) := NULL;
        lc_product_attr_value    VARCHAR2 (800) := NULL;
        lc_product_attribute     VARCHAR2 (240) := NULL;
        lc_product_attr_item     NUMBER;
    BEGIN
        WRITE_LOG ('VALIDATE_QP_LINES');

        OPEN cur_qp_lines (p_action => p_action);

        LOOP
            FETCH cur_qp_lines BULK COLLECT INTO lt_qp_lines_data LIMIT 100;

            EXIT WHEN lt_qp_lines_data.COUNT = 0;
            write_log (
                   'Validation Rec count lt_qp_lines_data.COUNT =>'
                || lt_qp_lines_data.COUNT);

            IF lt_qp_lines_data.COUNT > 0
            THEN
                FOR xc_qp_lines_rec IN lt_qp_lines_data.FIRST ..
                                       lt_qp_lines_data.LAST
                LOOP
                    -- LIST_LINE_TYPE_CODE
                    write_log ('LIST_LINE_TYPE_CODE Validation');
                    lc_qp_lines_valid_data   := gc_yes_flag;

                    BEGIN
                        SELECT DISTINCT 1
                          INTO ln_count
                          FROM qp_lookups
                         WHERE     lookup_type = 'LIST_LINE_TYPE_CODE'
                               AND LOOKUP_CODE =
                                   lt_qp_lines_data (xc_qp_lines_rec).list_line_type_code
                               AND enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (start_date_active,
                                                        SYSDATE)
                                               AND NVL (end_date_active,
                                                        SYSDATE);
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_qp_lines_valid_data   := gc_no_flag;
                            write_log (
                                   'Exception Raised in QP list_line_type_code Validation'
                                || SQLERRM);
                            xxd_common_utils.record_error (
                                'QP',
                                gn_org_id,
                                'XXD QP  Price List Conversion Program',
                                --          SQLCODE,
                                SQLERRM,
                                DBMS_UTILITY.format_error_backtrace,
                                --   DBMS_UTILITY.format_call_stack,
                                --   SYSDATE,
                                gn_user_id,
                                gn_conc_request_id --                                                   ,p_orig_sys_header_ref
     --                                                   ,p_orig_sys_line_ref
                                ,
                                   'Validation Failed when validating  LIST_LINE_TYPE_CODE '
                                || lt_qp_lines_data (xc_qp_lines_rec).list_line_type_code);
                        WHEN OTHERS
                        THEN
                            lc_qp_lines_valid_data   := gc_no_flag;
                            write_log (
                                   'Exception Raised in QP list_line_type_code Validation'
                                || SQLERRM);
                            xxd_common_utils.record_error (
                                'QP',
                                gn_org_id,
                                'XXD QP  Price List Conversion Program',
                                --      SQLCODE,
                                SQLERRM,
                                DBMS_UTILITY.format_error_backtrace,
                                --   DBMS_UTILITY.format_call_stack,
                                --   SYSDATE,
                                gn_user_id,
                                gn_conc_request_id --                                                   ,p_orig_sys_header_ref
     --                                                   ,p_orig_sys_line_ref
                                ,
                                   'Validation Failed when validating  LIST_LINE_TYPE_CODE '
                                || lt_qp_lines_data (xc_qp_lines_rec).list_line_type_code);
                    END;

                    --            --ARITHMETIC_OPERATOR
                    --            write_log ('ARITHMETIC_OPERATOR Validation');
                    --
                    --            IF lt_qp_lines_data (xc_qp_lines_rec).ARITHMETIC_OPERATOR IS NULL
                    --            THEN
                    --               lc_qp_lines_valid_data   := gc_no_flag;
                    --               xxd_common_utils.record_error
                    --                                                  ('QP',
                    --                                                   gn_org_id,
                    --                                                   'XXD QP  Price List Conversion Program',
                    --                                             --      SQLCODE,
                    --                                                   'ARITHMETIC_OPERATOR Can not be NULL',
                    --                                                   DBMS_UTILITY.format_error_backtrace,
                    --                                                --   DBMS_UTILITY.format_call_stack,
                    --                                                --   SYSDATE,
                    --                                                  gn_user_id,
                    --                                                   gn_conc_request_id
                    ----                                                   ,p_orig_sys_header_ref
                    ----                                                   ,p_orig_sys_line_ref
                    --                                                   ,lt_qp_lines_data (xc_qp_lines_rec).ARITHMETIC_OPERATOR
                    --                                                  );
                    --            END IF;


                    --ATTRIBUTE_GROUPING_NO
                    --            IF lt_qp_lines_data (xc_qp_lines_rec).ATTRIBUTE_GROUPING_NO IS NULL
                    --            THEN
                    --               lc_qp_lines_valid_data   := gc_no_flag;
                    --                        xxd_common_utils.record_error
                    --                                                  ('QP',
                    --                                                   gn_org_id,
                    --                                                   'XXD QP  Price List Conversion Program',
                    --                                        --           SQLCODE,
                    --                                                   'ATTRIBUTE_GROUPING_NO Can not be NULL',
                    --                                                   DBMS_UTILITY.format_error_backtrace,
                    --                                                --   DBMS_UTILITY.format_call_stack,
                    --                                                --   SYSDATE,
                    --                                                  gn_user_id,
                    --                                                   gn_conc_request_id
                    ----                                                   ,p_orig_sys_header_ref
                    ----                                                   ,p_orig_sys_line_ref
                    ----                                                   ,p_orig_sys_pricing_attr_ref
                    --                                                  );
                    --            END IF;

                    BEGIN
                        SELECT NEW_PRICELIST_NAME, item_level
                          --,order_source
                          -- ,conversion
                          INTO lc_new_list_name            --  ,v_order_source
                                                             --  ,v_conversion
                               , lc_item_level
                          FROM XXD_CONV.XXD_QP_SEASON_PRICE_MAP_TBL
                         WHERE CURRENT_PRICELIST_NAME =
                               lt_qp_lines_data (xc_qp_lines_rec).PRICELIST_NAME_1206;

                        write_log ('lc_item_level :' || lc_item_level);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_new_list_name         := NULL;
                            lc_qp_lines_valid_data   := gc_no_flag;
                            write_log (
                                   'NO MAPPING DATA WHILE FETCHING PRICE LIST NAME:'
                                || SQLERRM);

                            xxd_common_utils.record_error (
                                p_module       => 'QP',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'XXD QP  Price List Conversion Program',
                                p_error_msg    =>
                                    'NO MAPPING DATA WHILE FETCHING PRICE LIST NAME',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   => 'PRICELIST_NAME',
                                p_more_info2   => lc_new_list_name);
                    END;



                    IF lc_new_list_name IS NOT NULL AND lc_item_level = 'SKU'
                    THEN
                        IF lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE =
                           'PRICING_ATTRIBUTE1'
                        THEN
                            -- Get Item value from 1223
                            BEGIN
                                SELECT TRIM (segment1), inventory_item_id
                                  INTO lc_product_attr_value, lc_product_attr_item
                                  FROM mtl_system_items_b
                                 WHERE     inventory_item_id =
                                           lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTR_ITEM
                                       AND organization_id =
                                           (SELECT organization_id
                                              FROM mtl_parameters
                                             WHERE organization_code = 'MST');

                                lc_product_attribute   :=
                                    'PRICING_ATTRIBUTE1';
                                write_log (
                                       'PRODUCT_VALUE when  v_item_level is SKU :'
                                    || lc_product_attr_value);


                                lc_product_attr_item   :=
                                    Get_Product_Value (
                                        p_FlexField_Name   =>
                                            'QP_ATTR_DEFNS_PRICING',
                                        p_Context_Name   => 'ITEM',
                                        p_attribute_name   =>
                                            lc_product_attribute,
                                        p_attr_value     =>
                                            lc_product_attr_value);

                                IF lc_product_attr_item IS NULL
                                THEN
                                    RAISE NO_DATA_FOUND;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lc_product_attr_value    :=
                                        lt_qp_lines_data (xc_qp_lines_rec).product_attr_value;
                                    lc_product_attribute     :=
                                        lt_qp_lines_data (xc_qp_lines_rec).product_attribute;
                                    lc_product_attr_item     :=
                                        lt_qp_lines_data (xc_qp_lines_rec).product_attr_item;
                                    lc_qp_lines_valid_data   := gc_no_flag;
                                    write_log (
                                           ' SKU should be validated against Inventory extract and/or item existence in mtl_system_items_b.'
                                        || lc_product_attr_value);

                                    xxd_common_utils.record_error (
                                        p_module       => 'QP',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'XXD QP  Price List Conversion Program',
                                        p_error_msg    =>
                                               'Item id ('
                                            || lt_qp_lines_data (
                                                   xc_qp_lines_rec).PRODUCT_ATTR_ITEM
                                            || ') is not Defined in the system or not defind the valid Category',
                                        p_error_line   =>
                                            DBMS_UTILITY.format_error_backtrace,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   => 'PRICELIST_NAME',
                                        p_more_info2   =>
                                            lt_qp_lines_data (
                                                xc_qp_lines_rec).NAME,
                                        p_more_info3   =>
                                            lt_qp_lines_data (
                                                xc_qp_lines_rec).PRODUCT_ATTRIBUTE,
                                        p_more_info4   =>
                                            lt_qp_lines_data (
                                                xc_qp_lines_rec).PRODUCT_ATTR_ITEM);
                            END;
                        ELSE
                            IF lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE =
                               'PRICING_ATTRIBUTE2'
                            THEN
                                lc_qp_lines_valid_data   := gc_no_flag;
                                lc_product_attribute     :=
                                    'PRICING_ATTRIBUTE2';
                                xxd_common_utils.record_error (
                                    p_module       => 'QP',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'XXD QP  Price List Conversion Program',
                                    p_error_msg    =>
                                           'Item Category ('
                                        || lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_1206_VALUE
                                        || ') Can not be added for SKU Price List',
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => 'PRICELIST_NAME',
                                    p_more_info2   =>
                                        lt_qp_lines_data (xc_qp_lines_rec).NAME,
                                    p_more_info3   =>
                                        lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE,
                                    p_more_info4   =>
                                        lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTR_ITEM);
                            END IF;
                        END IF;                     -- SKU  PRICING_ATTRIBUTE1
                    ELSIF     lc_new_list_name IS NOT NULL
                          AND lc_item_level = 'CATEGORY'
                    THEN
                        IF lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE =
                           'PRICING_ATTRIBUTE2'
                        THEN
                            -- get  style value from categories 1223
                            BEGIN
                                SELECT DISTINCT TRIM (style_desc)
                                  INTO lc_product_attr_value
                                  FROM xxd_common_items_v /*xxd_conv.XXD_PLM_ATTR_STG_T*/
                                 WHERE     style_number =
                                           lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_1206_VALUE
                                       AND organization_id =
                                           (SELECT organization_id
                                              FROM mtl_parameters
                                             WHERE organization_code = 'MST');

                                lc_product_attribute   :=
                                    'PRICING_ATTRIBUTE2';

                                lc_product_attr_item   :=
                                    Get_Product_Value (
                                        p_FlexField_Name   =>
                                            'QP_ATTR_DEFNS_PRICING',
                                        p_Context_Name   => 'ITEM',
                                        p_attribute_name   =>
                                            lc_product_attribute,
                                        p_attr_value     =>
                                            lc_product_attr_value);


                                write_log (
                                       'PRODUCT_VALUE when  v_item_level is CATEGORY :'
                                    || lc_product_attr_value);

                                IF lc_product_attr_item IS NULL
                                THEN
                                    RAISE NO_DATA_FOUND;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lc_product_attr_value    :=
                                        lt_qp_lines_data (xc_qp_lines_rec).product_attr_value;
                                    lc_product_attribute     :=
                                        lt_qp_lines_data (xc_qp_lines_rec).product_attribute;
                                    lc_product_attr_item     :=
                                        lt_qp_lines_data (xc_qp_lines_rec).product_attr_item;
                                    lc_qp_lines_valid_data   := gc_no_flag;
                                    write_log (
                                           'NO MAPPING DATA WHILE FETCHING PRODUCT VALUE(CATEGORY) for :'
                                        || lc_product_attr_value
                                        || SQLERRM);

                                    xxd_common_utils.record_error (
                                        p_module       => 'QP',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'XXD QP  Price List Conversion Program',
                                        p_error_msg    =>
                                               'Category  '
                                            || lt_qp_lines_data (
                                                   xc_qp_lines_rec).PRODUCT_1206_VALUE
                                            || ' is not defind in qp_item_categories_v',
                                        p_error_line   =>
                                            DBMS_UTILITY.format_error_backtrace,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   => 'PRICELIST_NAME',
                                        p_more_info2   =>
                                            lt_qp_lines_data (
                                                xc_qp_lines_rec).NAME,
                                        p_more_info3   =>
                                            lt_qp_lines_data (
                                                xc_qp_lines_rec).PRODUCT_ATTRIBUTE,
                                        p_more_info4   =>
                                            lt_qp_lines_data (
                                                xc_qp_lines_rec).PRODUCT_1206_VALUE);
                            END;
                        ELSIF lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE =
                              'PRICING_ATTRIBUTE1'
                        THEN
                            lc_product_attribute   := 'PRICING_ATTRIBUTE2';

                            BEGIN
                                SELECT DISTINCT TRIM (style_desc)
                                  INTO lc_product_attr_value
                                  FROM xxd_common_items_v xmb /*xxd_conv.XXD_PLM_ATTR_STG_T*/
                                 WHERE     organization_id =
                                           (SELECT organization_id
                                              FROM mtl_parameters
                                             WHERE organization_code = 'MST')
                                       AND inventory_item_id =
                                           lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTR_ITEM;

                                --                           (SELECT MAX(inventory_item_id)
                                --                                                       FROM mtl_system_items_b msb
                                --                                                      WHERE msb.inventory_item_id = xmb.inventory_item_id
                                --                          AND TO_CHAR (segment1) = lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_1206_VALUE)    ;


                                lc_product_attr_item   :=
                                    Get_Product_Value (
                                        p_FlexField_Name   =>
                                            'QP_ATTR_DEFNS_PRICING',
                                        p_Context_Name   => 'ITEM',
                                        p_attribute_name   =>
                                            lc_product_attribute,
                                        p_attr_value     =>
                                            lc_product_attr_value);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lc_product_attr_value    :=
                                        lt_qp_lines_data (xc_qp_lines_rec).product_attr_value;
                                    lc_product_attribute     :=
                                        lt_qp_lines_data (xc_qp_lines_rec).product_attribute;
                                    lc_product_attr_item     :=
                                        lt_qp_lines_data (xc_qp_lines_rec).product_attr_item;

                                    lc_qp_lines_valid_data   := gc_no_flag;
                                    write_log (
                                           'NO MAPPING DATA WHILE FETCHING PRODUCT VALUE(CATEGORY) 2 for :'
                                        || lc_product_attr_value
                                        || SQLERRM);

                                    xxd_common_utils.record_error (
                                        p_module       => 'QP',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'XXD QP  Price List Conversion Program',
                                        p_error_msg    =>
                                            'No product_attr_value found at SKU Level 2',
                                        p_error_line   =>
                                            DBMS_UTILITY.format_error_backtrace,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   => 'PRICELIST_NAME',
                                        p_more_info2   =>
                                            lt_qp_lines_data (
                                                xc_qp_lines_rec).NAME,
                                        p_more_info3   =>
                                            lt_qp_lines_data (
                                                xc_qp_lines_rec).PRODUCT_ATTRIBUTE,
                                        p_more_info4   =>
                                            lt_qp_lines_data (
                                                xc_qp_lines_rec).PRODUCT_1206_VALUE);
                            END;
                        END IF;
                    END IF;

                    IF lc_qp_lines_valid_data = gc_yes_flag
                    THEN
                        write_log (
                               'Before calling barnd and style prc lc_product_attr_value =>'
                            || lc_product_attr_value);
                        write_log (
                               'Before calling barnd and style prc lc_product_attribute =>'
                            || lc_product_attribute);
                        l_brand        := NULL;
                        l_season_num   := NULL;

                        IF lc_new_list_name IS NOT NULL
                        THEN
                            IF     lc_product_attr_value IS NOT NULL
                               AND lc_product_attribute =
                                   'PRICING_ATTRIBUTE1'
                            THEN
                                get_brand_style (
                                    p_category     => lc_product_attr_value,
                                    p_item_type    => 'PRICING_ATTRIBUTE1',
                                    l_brand        => l_brand,
                                    l_season_num   => l_season_num);
                            ELSIF     lc_product_attr_value IS NOT NULL
                                  AND lc_product_attribute =
                                      'PRICING_ATTRIBUTE2'
                            THEN
                                get_brand_style (
                                    p_category     => lc_product_attr_value,
                                    p_item_type    => 'PRICING_ATTRIBUTE2',
                                    l_brand        => l_brand,
                                    l_season_num   => l_season_num);
                            END IF;


                            IF l_brand IS NULL
                            THEN
                                lc_qp_lines_valid_data   := gc_no_flag;
                                xxd_common_utils.record_error (
                                    p_module       => 'QP',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'XXD QP  Price List Conversion Program',
                                    p_error_msg    =>
                                           'BRAND  is not defined in OM Sales Category for '
                                        || lc_product_attr_value,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => lc_new_list_name,
                                    p_more_info2   => 'BRAND',
                                    p_more_info3   => lc_product_attribute,
                                    p_more_info4   => lc_product_attr_value);
                            END IF;

                            IF l_season_num IS NULL
                            THEN
                                lc_qp_lines_valid_data   := gc_no_flag;
                                xxd_common_utils.record_error (
                                    p_module       => 'QP',
                                    p_org_id       => gn_org_id,
                                    p_program      =>
                                        'XXD QP  Price List Conversion Program',
                                    p_error_msg    =>
                                           'SEASON  is not defined in OM Sales Category for  '
                                        || lc_product_attr_value,
                                    p_error_line   =>
                                        DBMS_UTILITY.format_error_backtrace,
                                    p_created_by   => gn_user_id,
                                    p_request_id   => gn_conc_request_id,
                                    p_more_info1   => lc_new_list_name,
                                    p_more_info2   => 'SEASON',
                                    p_more_info3   => lc_product_attribute,
                                    p_more_info4   => lc_product_attr_value);
                            END IF;
                        END IF;
                    END IF;

                    /*               --PRODUCT_ATTRIBUTE_CONTEXT
                                   IF    lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE_CONTEXT <>
                                            'ITEM'
                                      OR lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE_CONTEXT
                                            IS NULL
                                   THEN
                                      lc_qp_lines_valid_data := gc_no_flag;
                                      xxd_common_utils.record_error (
                                         'QP',
                                         gn_org_id,
                                         'XXD QP  Price List Conversion Program',
                                         --    SQLCODE,
                                         'Validation faild for PRODUCT_ATTRIBUTE_CONTEXTand PRODUCT_ATTRIBUTE_CONTEXT ',
                                         DBMS_UTILITY.format_error_backtrace,
                                         --   DBMS_UTILITY.format_call_stack,
                                         --   SYSDATE,
                                         gn_user_id,
                                         gn_conc_request_id--                                             ,p_orig_sys_header_ref
                                                           --                                             ,p_orig_sys_line_ref
                                                           --                                             ,p_orig_sys_pricing_attr_ref
                                         );
                                   END IF;


                                   write_log (
                                         'lt_qp_lines_data (xc_qp_lines_rec).product_attr_value => '
                                      || lt_qp_lines_data (xc_qp_lines_rec).product_attr_value);
                                   write_log (
                                         'lt_qp_lines_data (xc_qp_lines_rec).product_attribute => '
                                      || lt_qp_lines_data (xc_qp_lines_rec).product_attribute);

                                   IF lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE_CONTEXT = 'ITEM'
                                   THEN
                                      x_Product_Value :=
                                                         Get_Product_Value (
                                                            'QP_ATTR_DEFNS_PRICING',
                                                            'ITEM',
                                                            lt_qp_lines_data (xc_qp_lines_rec).product_attribute,
                                                            lt_qp_lines_data (xc_qp_lines_rec).product_attr_value,
                                                            lx_item_name,
                                                            lx_category_name);
                                      write_log (
                                            'lt_qp_lines_data (xc_qp_lines_rec).lx_item_name => '
                                         || lx_item_name);
                                      write_log (
                                            'lt_qp_lines_data (xc_qp_lines_rec).lx_category_name => '
                                         || lx_category_name);
                                      write_log (
                                            'lt_qp_lines_data (xc_qp_lines_rec).x_Product_Value => '
                                         || x_Product_Value);

                                      IF     x_Product_Value IS NULL
                                         AND lt_qp_lines_data (xc_qp_lines_rec).product_attribute =
                                                'PRICING_ATTRIBUTE1'
                                      THEN
                                         lc_qp_lines_valid_data := gc_no_flag;
                                         xxd_common_utils.record_error (
                                            'QP',
                                            gn_org_id,
                                            'XXD QP  Price List Conversion Program',
                                            --  SQLCODE,
                                            'Validatoin Faild for the Item ' || lx_item_name,
                                            DBMS_UTILITY.format_error_backtrace,
                                            --   DBMS_UTILITY.format_call_stack,
                                            --  SYSDATE,
                                            gn_user_id,
                                            gn_conc_request_id,
                                            lt_qp_lines_data (xc_qp_lines_rec).name,
                                            lt_qp_lines_data (xc_qp_lines_rec).product_attr_value--                                   ,p_orig_sys_pricing_attr_ref
                                            );
                                         x_item_name := lx_item_name;
                                      ELSIF     x_Product_Value IS NULL
                                            AND lt_qp_lines_data (xc_qp_lines_rec).product_attribute =
                                                   'PRICING_ATTRIBUTE2'
                                      THEN
                                         lc_qp_lines_valid_data := gc_no_flag;
                                         x_item_name := lx_category_name;
                                         xxd_common_utils.record_error (
                                            'QP',
                                            gn_org_id,
                                            'XXD QP  Price List Conversion Program',
                                               --  SQLCODE,
                                               'Validatoin Faild for the Category '
                                            || lt_qp_lines_data (xc_qp_lines_rec).product_attr_value,
                                            DBMS_UTILITY.format_error_backtrace,
                                            --   DBMS_UTILITY.format_call_stack,
                                            --  SYSDATE,
                                            gn_user_id,
                                            gn_conc_request_id,
                                            lt_qp_lines_data (xc_qp_lines_rec).name,
                                            lt_qp_lines_data (xc_qp_lines_rec).product_attr_value--                                   ,p_orig_sys_pricing_attr_ref
                                            );
                                      ELSIF     x_Product_Value IS NULL
                                            AND lt_qp_lines_data (xc_qp_lines_rec).product_attribute =
                                                   'PRICING_ATTRIBUTE3'
                                      THEN
                                         lc_qp_lines_valid_data := gc_no_flag;
                                         xxd_common_utils.record_error (
                                            'QP',
                                            gn_org_id,
                                            'XXD QP  Price List Conversion Program',
                                            --  SQLCODE,
                                            'Validatoin Faild for the ALL_ITEMS ',
                                            DBMS_UTILITY.format_error_backtrace,
                                            --   DBMS_UTILITY.format_call_stack,
                                            --  SYSDATE,
                                            gn_user_id,
                                            gn_conc_request_id--                                   ,p_orig_sys_header_ref
                                                              --                                   ,p_orig_sys_line_ref
                                                              --                                   ,p_orig_sys_pricing_attr_ref
                                            );

                                      END IF;

                    */

                    --               END IF;


                    write_log (
                        'validate_priceattribs :' || lc_qp_lines_valid_data);


                    IF lc_qp_lines_valid_data = gc_no_flag
                    THEN
                        UPDATE XXD_QP_LIST_LINES_STG_T
                           SET RECORD_STATUS = gc_error_status, PRODUCT_ATTR_ITEM = NVL (lc_product_attr_item, PRODUCT_ATTR_ITEM), PRODUCT_ATTR_VALUE = NVL (lc_product_attr_value, PRODUCT_ATTR_VALUE),
                               name = lc_new_list_name, PRODUCT_ATTRIBUTE = NVL (lc_product_attribute, PRODUCT_ATTRIBUTE), REQUEST_ID = gn_conc_request_id
                         WHERE record_id =
                               lt_qp_lines_data (xc_qp_lines_rec).RECORD_ID;
                    ELSE
                        UPDATE XXD_QP_LIST_LINES_STG_T
                           SET RECORD_STATUS = gc_validate_status, PRODUCT_ATTR_ITEM = lc_product_attr_item, PRODUCT_ATTR_VALUE = lc_product_attr_value,
                               name = lc_new_list_name, PRODUCT_ATTRIBUTE = lc_product_attribute, REQUEST_ID = gn_conc_request_id,
                               BRAND = l_brand, SEASON = l_season_num
                         WHERE record_id =
                               lt_qp_lines_data (xc_qp_lines_rec).record_id;
                    END IF;
                END LOOP;
            END IF;

            COMMIT;
        END LOOP;

        CLOSE cur_qp_lines;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            lc_qp_lines_valid_data   := gc_no_flag;

            xxd_common_utils.record_error ('QP', gn_org_id, 'XXD QP  Price List Conversion Program', --  SQLCODE,
                                                                                                     'Exception in validate_qp_priceattribs ' || SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                                               --  SYSDATE,
                                                                                                                                                                                               gn_user_id
                                           , gn_conc_request_id --                       ,p_orig_sys_header_ref
                                 --                       ,p_orig_sys_line_ref
                         --                       ,p_orig_sys_pricing_attr_ref
                                           );
            ROLLBACK;
        WHEN OTHERS
        THEN
            lc_qp_lines_valid_data   := gc_no_flag;
            xxd_common_utils.record_error ('QP', gn_org_id, 'XXD QP  Price List Conversion Program', --     SQLCODE,
                                                                                                     'Exception in validate_qp_priceattribs ' || SQLERRM, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                                               --    SYSDATE,
                                                                                                                                                                                               gn_user_id
                                           , gn_conc_request_id --                       ,p_orig_sys_header_ref
                                 --                       ,p_orig_sys_line_ref
                         --                       ,p_orig_sys_pricing_attr_ref
                                           );
            ROLLBACK;
    END pricelist_validation;

    FUNCTION check_price_lists_exists (p_pricelist_name IN VARCHAR2)
        RETURN BOOLEAN
    -- +========================================================================+
    -- | Name        :  CHECK_PRICE_LISTS_EXISTS                                |
    -- |                                                                        |
    -- | Description :  function will validate the existance of the pricelist in|
    -- |                EBS.                                                    |
    -- |                                                                        |
    -- | Parameters  :                                                          |
    -- |                p_pricelist_name IN VARCHAR2                            |
    -- +========================================================================+

    IS
        lc_err_msg         VARCHAR2 (2000);
        ln_pr_list_count   PLS_INTEGER;
    BEGIN
        SELECT COUNT (1)
          INTO ln_pr_list_count
          FROM DUAL
         WHERE EXISTS
                   (SELECT 1
                      FROM apps.qp_list_headers_b QLH, apps.qp_list_headers_tl QLHT
                     WHERE     UPPER (qlht.name) = UPPER (p_pricelist_name)
                           AND qlht.LANGUAGE = USERENV ('LANG')
                           AND qlh.list_header_id = qlht.list_header_id);

        write_log (
            'check_price_lists_exists: IN ' || UPPER (p_pricelist_name));

        IF ln_pr_list_count > 0
        THEN
            write_log (
                'check_price_lists_exists: TRUE ' || UPPER (p_pricelist_name));
            RETURN TRUE;
        ELSE
            write_log (
                   'check_price_lists_exists: FALSE '
                || UPPER (p_pricelist_name));
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_err_msg   := 'Unexpected error - ' || SUBSTR (SQLERRM, 1, 250);
            write_log ('check_price_lists_exists: ' || lc_err_msg);

            RETURN FALSE;
    END check_price_lists_exists;

    ------Start of adding the Extract Procedure on 21-Apr-2015
    PROCEDURE extract_1206_pricelist_data (x_errbuf    OUT VARCHAR2,
                                           x_retcode   OUT NUMBER)
    AS
        lv_error_stage            VARCHAR2 (50) := NULL;
        ln_record_count           NUMBER := 0;
        lv_string                 LONG;
        v_order_source            VARCHAR2 (50) := NULL;
        v_conversion              VARCHAR2 (1) := NULL;
        v_item_level              VARCHAR2 (50) := NULL;
        gc_new_status             VARCHAR2 (10) := 'NEW';

        CURSOR cu_extract_count IS
            SELECT COUNT (*)
              FROM XXD_QP_LIST_LINES_STG_T
             WHERE record_status = gc_new_status;

        --AND    source_org    = p_source_org_id;


        CURSOR lcu_price_list_data IS
            SELECT /*+ FIRST_ROWS(10) */
                                                         --'NEW' RECORD_STATUS
                  NULL BATCH_ID, 'NEW' RECORD_STATUS, XXD_QP_LIST_RECORD_ID_S.NEXTVAL "RECORD_ID",
                  PRICELIST_NAME_1223 NAME, NULL LIST_HEADER_ID, NULL LIST_LINE_NO,
                  'PLL' LIST_LINE_TYPE_CODE, START_DATE_ACTIVE, END_DATE_ACTIVE,
                  ARITHMETIC_OPERATOR, NULL "OPERATION", OPERAND,
                  ORGANIZATION_CODE, NULL PROCESS_FLAG, NULL PRICING_ATTRIBUTE_ID,
                  PRODUCT_ATTRIBUTE_CONTEXT, PRODUCT_ATTRIBUTE, NULL PRODUCT_ATTR_VALUE,
                  PRODUCT_ATTR_VALUE PRODUCT_ATTR_ITEM, PRODUCT_UOM_CODE, EXCLUDER_FLAG,
                  ATTRIBUTE_GROUPING_NO, NULL PRICE_LIST_LINE_INDEX, NULL BRAND,
                  NULL SEASON, NULL ERROR_MESSAGE, gn_conc_request_id REQUEST_ID,
                  SYSDATE CREATION_DATE, NULL CREATED_BY, NULL LAST_UPDATE_DATE,
                  NULL LAST_UPDATED_BY, PRICELIST_NAME_1206, DECODE (PRODUCT_ATTRIBUTE, 'PRICING_ATTRIBUTE1', PRODUCT_ATTR_VALUE, ITEM_1206) PRODUCT_1206_VALUE
             FROM XXD_1206_PRICE_LIST_EXTRACT_T XACI
            WHERE EXISTS
                      (SELECT 1
                         FROM XXD_CONV.XXD_QP_SEASON_PRICE_MAP_TBL
                        WHERE     PRICELIST_NAME_1206 =
                                  CURRENT_PRICELIST_NAME
                              AND SEASON IS NULL--             AND   NEW_PRICELIST_NAME ='TQ Pricelist- JPY'
                                                );

        --            WHERE PRICELIST_NAME_1206 ='Retail Canada Replenishment - DC3'
        --IN ('Ex EMEA Distributors','Retail China Replenishment','S15 Ex EMEA Distributors')



        --         AND  EXISTS(SELECT 1
        --                       FROM  MTL_SYSTEM_ITEMS_B MSB
        --                       WHERE MSB.segment1 = XACI.ITEM_NUMBER
        --                       ) ;
        --
        --              ,cst_item_costs_for_gl_view@bt_read_1206 cst
        --       WHERE cst.organization_id = XACI.INVENTORY_ORG
        --         AND cst.inventory_item_id = XACI.INVENTORY_ITEM_ID(+)
        --        WHERE

        --where customer_id   in ( 2020,1453,2002,2079,2255)     ;
        --AND   HSUA.org_id            = p_source_org_id)        ;
        --TYPE XXD_1206_PRICE_LIST_TAB is TABLE OF XXD_QP_LIST_LINES_STG_T%ROWTYPE INDEX BY BINARY_INTEGER;
        --gtt_cur_1206_price_list_tab XXD_1206_PRICE_LIST_TAB;

        --TYPE XXD_QP_PRICE_LIST_TAB is TABLE OF XXD_QP_PRICE_LIST_STG_T%ROWTYPE INDEX BY BINARY_INTEGER;
        --gtt_qp_price_list_tab XXD_QP_PRICE_LIST_TAB;
        TYPE XXD_QP_PRICE_LIST_TAB IS TABLE OF lcu_price_list_data%ROWTYPE
            INDEX BY BINARY_INTEGER;

        gtt_1206_price_list_tab   XXD_QP_PRICE_LIST_TAB;
    BEGIN
        gtt_1206_price_list_tab.delete;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_QP_LIST_LINES_STG_T';

        OPEN lcu_price_list_data;

        LOOP
            lv_error_stage   := 'Inserting Price list Data';
            write_log (lv_error_stage);

            --gtt_1206_price_list_tab.delete;

            FETCH lcu_price_list_data
                BULK COLLECT INTO gtt_1206_price_list_tab
                LIMIT 500;

            FOR i IN 1 .. gtt_1206_price_list_tab.COUNT
            LOOP
                write_log ('COUNT :' || gtt_1206_price_list_tab.COUNT);

                BEGIN
                    SELECT NEW_PRICELIST_NAME, item_level
                      --,order_source
                      -- ,conversion
                      INTO gtt_1206_price_list_tab (i).NAME --  ,v_order_source
                                                             --  ,v_conversion
                           , v_item_level
                      FROM XXD_CONV.XXD_QP_SEASON_PRICE_MAP_TBL
                     WHERE CURRENT_PRICELIST_NAME =
                           gtt_1206_price_list_tab (i).PRICELIST_NAME_1206;

                    -- AND conversion='x';
                    write_log (
                           'PRICELIST_NAME_1206 :'
                        || gtt_1206_price_list_tab (i).PRICELIST_NAME_1206);
                    write_log (
                           'PRICELIST_NAME_1223 :'
                        || gtt_1206_price_list_tab (i).NAME);
                    --write_log(,'v_order_source :' ||v_order_source);
                    --write_log(,'v_conversion :'||v_conversion);
                    write_log ('v_item_level :' || v_item_level);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        gtt_1206_price_list_tab (i).NAME   := NULL;
                        write_log (
                               'NO MAPPING DATA WHILE FETCHING PRICE LIST NAME:'
                            || SQLERRM);
                END;


                --END LOOP;
                --            IF     gtt_1206_price_list_tab (i).NAME IS NOT NULL
                --               AND gtt_1206_price_list_tab (i).PRODUCT_ATTR_VALUE IS NOT NULL
                --            THEN
                --  INSERT INTO XXD_QP_PRICE_LIST_STG_T VALUES gtt_1206_price_list_tab(i);
                --              gtt_1206_price_list_tab (i).RECORD_STATUS := gc_error_status;
                INSERT INTO XXD_QP_LIST_LINES_STG_T
                     VALUES gtt_1206_price_list_tab (i);
            --             ELSIF gtt_1206_price_list_tab (i).PRODUCT_ATTR_VALUE IS NOT NULL  THEN
            --
            --              gtt_1206_price_list_tab (i).record_status := gc_error_status;
            --
            --              INSERT INTO XXD_QP_LIST_LINES_STG_T
            --                    VALUES gtt_1206_price_list_tab (i);
            --
            --            END IF;


            --gtt_1206_price_list_tab.delete;

            --EXIT WHEN lcu_price_list_data%NOTFOUND;
            END LOOP;

            COMMIT;
            EXIT WHEN lcu_price_list_data%NOTFOUND;
        END LOOP;

        -- Delete the items which are not in - Price list extract should be based on Inventory extract table.

        DELETE /*+ Parallel(xqpl) */
               XXD_QP_LIST_LINES_STG_T xqpl
         WHERE     PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE1'
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxd_conv.XXD_ITEM_1206_EXTRACT
                         WHERE INVENTORY_ITEM_ID = PRODUCT_1206_VALUE);

        -- Delete the Categories  which are not in - Price list extract should be based on Inventory extract table.

        DELETE /*+ Parallel(xqpl) */
               XXD_QP_LIST_LINES_STG_T xqpl
         WHERE     PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE2'
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxd_conv.XXD_ITEM_1206_EXTRACT
                         WHERE segment1 = PRODUCT_1206_VALUE);



        -- Ability to reprocess price list fallouts once remaining item fallouts has been processed.

        DELETE /*+ Parallel(xqpl) */
               XXD_QP_LIST_LINES_STG_T xqpl
         WHERE     PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE1'
               AND EXISTS
                       (SELECT 1
                          FROM QP_PRICING_ATTRIBUTES qpa, qp_list_headers_all qlh
                         WHERE     qpa.list_header_id = qlh.list_header_id
                               AND qlh.name = xqpl.NAME
                               AND PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE1'
                               AND qpa.PRODUCT_ATTR_VALUE =
                                   xqpl.PRODUCT_1206_VALUE);

        -- Ability to reprocess price list fallouts once remaining item fallouts has been processed.
        DELETE /*+ Parallel(xqpl) */
               XXD_QP_LIST_LINES_STG_T xqpl
         WHERE     PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE2'
               AND EXISTS
                       (SELECT 1
                          FROM QP_PRICING_ATTRIBUTES qpa, qp_list_headers_all qlh
                         WHERE     qpa.list_header_id = qlh.list_header_id
                               AND qlh.name = xqpl.name
                               AND PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE2'
                               AND qpa.PRODUCT_ATTR_VALUE =
                                   xqpl.PRODUCT_1206_VALUE);

        -- Ability to reprocess price list fallouts once remaining item fallouts has been processed.
        DELETE /*+ Parallel(10) */
               FROM
            XXD_QP_LIST_LINES_STG_T xqpl
              WHERE     PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE2'
                    AND EXISTS
                            (SELECT /*+ Parallel(10) */
                                    1
                               FROM QP_PRICING_ATTRIBUTES qpa,
                                    qp_list_headers_all qlh,
                                    (SELECT /*+ Parallel(10) */
                                            DISTINCT STYLE_DESC, STYLE_NUMBER
                                       FROM XXD_COMMON_ITEMS_V msb, mtl_parameters mp
                                      WHERE     msb.organization_id =
                                                mp.organization_id
                                            AND mp.organization_code = 'MST')
                                    item_cat,
                                    qp_item_categories_v qic
                              WHERE     qpa.list_header_id =
                                        qlh.list_header_id
                                    AND TO_CHAR (qpa.PRODUCT_ATTR_VALUE) =
                                        TO_CHAR (qic.CATEGORY_ID)
                                    AND item_cat.STYLE_DESC =
                                        qic.CATEGORY_NAME
                                    AND xqpl.PRODUCT_1206_VALUE =
                                        item_cat.STYLE_NUMBER
                                    AND qlh.name = xqpl.name
                                    AND PRODUCT_ATTRIBUTE =
                                        'PRICING_ATTRIBUTE2');

        COMMIT;

        CLOSE lcu_price_list_data;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            write_log (
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            write_log (
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            write_log ('Exception ' || SQLERRM);
    END extract_1206_pricelist_data;

    ------End of adding the Extract Procedure on 21-Apr-2015


    PROCEDURE iface_price_list (ERRBUF OUT NOCOPY VARCHAR2, RETCODE OUT NOCOPY NUMBER, p_action IN VARCHAR2
                                , p_batch_id IN NUMBER --p_lst_name             IN       VARCHAR2
                                                      )
    /****************************************************************************************
    *  Procedure Name :   iface_price_list                                                  *
    *                                                                                       *
    *  Description    :   To validate the data in staging table and load into oracle apps   *
    *                     tables.                                                           *
    *                                                                                       *
    *  Called From    :   Concurrent Program                                                *
    *                                                                                       *
    *  Parameters             Type       Description                                        *
    *  -----------------------------------------------------------------------------        *
    *  p_batch_id               IN       Batch Number to fetch the data from header stage   *
    *  p_action                 IN       Action (VALIDATE OR PROCESSED)                     *
    *                                                                                       *
    *                                                                                       *
    * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
    *                                                                                       *
     *****************************************************************************************/
    IS
        CURSOR cur_list_hdr (p_batch_id IN NUMBER, p_action IN VARCHAR2)
        --,p_lst_name IN VARCHAR2)
        IS
            (SELECT DISTINCT NAME
               FROM XXD_QP_LIST_LINES_STG_T XQLHT
              WHERE     XQLHT.RECORD_STATUS = p_action
                    AND XQLHT.batch_id = p_batch_id --           AND RECORD_ID = 2527501
                                                   );

        CURSOR cur_list_lines (p_action IN VARCHAR2, p_list_name IN VARCHAR2)
        IS
            (  /*SELECT distinct NAME ,LIST_LINE_TYPE_CODE,START_DATE_ACTIVE,ARITHMETIC_OPERATOR,OPERAND
                           ,PRODUCT_ATTRIBUTE_CONTEXT,PRODUCT_ATTRIBUTE,PRODUCT_ATTR_VALUE,PRODUCT_ATTR_ITEM,PRODUCT_UOM_CODE,EXCLUDER_FLAG
                           ,ATTRIBUTE_GROUPING_NO,PRICE_LIST_LINE_INDEX,BRAND ,SEASON
                  FROM XXD_QP_LIST_LINES_STG_T XQLLT
                 WHERE XQLLT.RECORD_STATUS = p_action AND XQLLT.name = p_list_name
                 and PRODUCT_ATTR_VALUE is not null--          AND RECORD_ID = 2527501*/

               SELECT COUNT (*), NAME, LIST_LINE_TYPE_CODE,
                      START_DATE_ACTIVE, ARITHMETIC_OPERATOR, OPERAND,
                      PRODUCT_ATTRIBUTE_CONTEXT, PRODUCT_ATTRIBUTE, PRODUCT_ATTR_VALUE,
                      PRODUCT_ATTR_ITEM, PRODUCT_UOM_CODE, EXCLUDER_FLAG,
                      ATTRIBUTE_GROUPING_NO, PRICE_LIST_LINE_INDEX, BRAND,
                      SEASON
                 FROM XXD_QP_LIST_LINES_STG_T XQLLT
                WHERE     XQLLT.RECORD_STATUS = p_action
                      AND XQLLT.name = p_list_name
                      AND PRODUCT_ATTR_VALUE IS NOT NULL
             GROUP BY NAME, LIST_LINE_TYPE_CODE, START_DATE_ACTIVE,
                      ARITHMETIC_OPERATOR, OPERAND, PRODUCT_ATTRIBUTE_CONTEXT,
                      PRODUCT_ATTRIBUTE, PRODUCT_ATTR_VALUE, PRODUCT_ATTR_ITEM,
                      PRODUCT_UOM_CODE, EXCLUDER_FLAG, ATTRIBUTE_GROUPING_NO,
                      PRICE_LIST_LINE_INDEX, BRAND, SEASON
               HAVING COUNT (*) = 1
             UNION
               SELECT COUNT (*), NAME, LIST_LINE_TYPE_CODE,
                      START_DATE_ACTIVE, ARITHMETIC_OPERATOR, OPERAND,
                      PRODUCT_ATTRIBUTE_CONTEXT, PRODUCT_ATTRIBUTE, PRODUCT_ATTR_VALUE,
                      PRODUCT_ATTR_ITEM, PRODUCT_UOM_CODE, EXCLUDER_FLAG,
                      ATTRIBUTE_GROUPING_NO, PRICE_LIST_LINE_INDEX, BRAND,
                      SEASON
                 FROM XXD_QP_LIST_LINES_STG_T XQLLT
                WHERE     XQLLT.RECORD_STATUS = p_action
                      AND XQLLT.name = p_list_name
                      AND PRODUCT_ATTR_VALUE IS NOT NULL
             GROUP BY NAME, LIST_LINE_TYPE_CODE, START_DATE_ACTIVE,
                      ARITHMETIC_OPERATOR, OPERAND, PRODUCT_ATTRIBUTE_CONTEXT,
                      PRODUCT_ATTRIBUTE, PRODUCT_ATTR_VALUE, PRODUCT_ATTR_ITEM,
                      PRODUCT_UOM_CODE, EXCLUDER_FLAG, ATTRIBUTE_GROUPING_NO,
                      PRICE_LIST_LINE_INDEX, BRAND, SEASON
               HAVING COUNT (*) > 1);

        --      ltab_qp_lines_iface      cur_list_lines%ROWTYPE;
        ln_request_id               NUMBER := 0;
        lc_cnt                      NUMBER := 0;
        lc_phase                    VARCHAR2 (200);
        lc_status                   VARCHAR2 (200);
        lc_delc_phase               VARCHAR2 (200);
        lc_delc_status              VARCHAR2 (200);
        lc_message                  VARCHAR2 (200);
        lb_wait                     BOOLEAN;

        lb_lst_exist                BOOLEAN;
        lc_insert_update            VARCHAR2 (50);
        l_orig_org_id               NUMBER;



        TYPE ltab_qp_lines_iface IS TABLE OF cur_list_lines%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_list_line_data           ltab_qp_lines_iface;
        lc_rounding_factor          qp_currency_lists_vl.base_rounding_factor%TYPE;

        x_return_status             VARCHAR2 (1) := NULL;
        x_msg_count                 NUMBER := 0;
        x_msg_data                  VARCHAR2 (2000);

        lx_list_line_exists         BOOLEAN := FALSE;
        lx_list_line_id             NUMBER;

        ln_price_attr_idx           NUMBER := 0;
        ln_qualifiers_idx           NUMBER := 0;
        ln_line_idx                 NUMBER := 0;

        lx_category                 VARCHAR2 (100);
        lx_brand                    VARCHAR2 (50);
        lx_style_num                NUMBER;

        l_price_list_rec            qp_price_list_pub.price_list_rec_type;
        l_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
        l_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
        l_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
        l_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
        l_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        l_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
        l_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
        x_price_list_rec            qp_price_list_pub.price_list_rec_type;
        x_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
    BEGIN
        write_log ('IN insert_pricelist   :');

        FOR xc_list_rec
            IN cur_list_hdr (p_batch_id => p_batch_id, p_action => p_action)
        --,p_lst_name => p_lst_name)
        LOOP
            BEGIN
                lb_lst_exist                 :=
                    check_price_lists_exists (
                        p_pricelist_name => xc_list_rec.NAME);

                IF lb_lst_exist = TRUE
                THEN
                    lc_insert_update                  := qp_globals.g_opr_update;
                    l_price_list_rec.list_header_id   := fnd_api.g_miss_num;

                    BEGIN
                        SELECT list_header_id
                          INTO l_price_list_rec.list_header_id
                          FROM qp_list_headers_all
                         WHERE NAME = xc_list_rec.name;

                        --l_price_list_rec.list_header_id                                                    := qp_pricing_attributes_s.currval;
                        l_price_list_rec.operation   :=
                            qp_globals.g_opr_update;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            NULL;
                    END;
                ELSE
                    lc_insert_update   := qp_globals.g_opr_create;
                    l_price_list_rec.list_header_id   :=
                        qp_list_headers_b_s.NEXTVAL;
                END IF;

                ---Assign List Header values
                x_return_status              := NULL;
                x_msg_count                  := NULL;
                x_msg_data                   := NULL;
                l_price_list_rec.operation   := lc_insert_update;
                l_price_list_rec.name        := xc_list_rec.name;


                OPEN cur_list_lines (p_action      => p_action,
                                     p_list_name   => xc_list_rec.name);

                LOOP
                    FETCH cur_list_lines
                        BULK COLLECT INTO lt_list_line_data
                        LIMIT 50;

                    EXIT WHEN lt_list_line_data.COUNT = 0;

                    IF lt_list_line_data.COUNT > 0
                    THEN
                        FOR xc_list_line_rec IN lt_list_line_data.FIRST ..
                                                lt_list_line_data.LAST
                        LOOP
                            --                        IF lt_qp_lines_data (xc_qp_lines_rec).product_attribute = 'PRICING_ATTRIBUTE1' THEN
                            lx_category   :=
                                lt_list_line_data (xc_list_line_rec).PRODUCT_ATTR_ITEM;
                            write_log ('IN insert_pricelist   12:');


                            BEGIN
                                write_log ('IN insert_pricelist   23:');
                                --                         gn_list_line_ins     :=  gn_list_line_ins +1;
                                ln_line_idx       := ln_line_idx + 1;

                                l_price_list_line_tbl (ln_line_idx).list_header_id   :=
                                    l_price_list_rec.list_header_id; --  lt_list_line_data(xc_list_line_rec).list_header_id                    ;
                                --                        lx_list_line_exists:=  check_list_line_exists(
                                --                                                                                                    p_list_header_id =>  lt_list_line_data(xc_list_line_rec).orig_sys_header_ref
                                --                                                                                                   ,p_list_line_id      =>  lt_list_line_data(xc_list_line_rec).orig_sys_line_ref
                                --                                                                                                   ,x_list_line_id       => lx_list_line_id
                                --                                                                                                )  ;
                                lx_list_line_id   := qp_list_lines_s.NEXTVAL;
                                l_price_list_line_tbl (ln_line_idx).list_line_id   :=
                                    lx_list_line_id; -- lt_list_line_data(xc_list_line_rec).list_line_id                      ;
                                l_price_list_line_tbl (ln_line_idx).operation   :=
                                    qp_globals.g_opr_create; --lt_list_line_data(xc_list_line_rec).operation                         ;
                                l_price_list_line_tbl (ln_line_idx).list_line_type_code   :=
                                    'PLL';
                                l_price_list_line_tbl (ln_line_idx).operand   :=
                                    lt_list_line_data (xc_list_line_rec).operand;
                                l_price_list_line_tbl (ln_line_idx).organization_id   :=
                                    NULL;
                                l_price_list_line_tbl (ln_line_idx).arithmetic_operator   :=
                                    lt_list_line_data (xc_list_line_rec).arithmetic_operator;

                                l_price_list_line_tbl (ln_line_idx).attribute1   :=
                                    lt_list_line_data (xc_list_line_rec).brand;
                                l_price_list_line_tbl (ln_line_idx).attribute2   :=
                                    lt_list_line_data (xc_list_line_rec).season;
                                write_log ('IN insert_pricelist   : 45');

                                l_pricing_attr_tbl (ln_line_idx).pricing_attribute_id   :=
                                    fnd_api.g_miss_num;
                                l_pricing_attr_tbl (ln_line_idx).list_line_id   :=
                                    lx_list_line_id;
                                l_pricing_attr_tbl (ln_line_idx).product_attribute_context   :=
                                    lt_list_line_data (xc_list_line_rec).product_attribute_context;
                                l_pricing_attr_tbl (ln_line_idx).product_attribute   :=
                                    lt_list_line_data (xc_list_line_rec).product_attribute;
                                l_pricing_attr_tbl (ln_line_idx).product_attr_value   :=
                                    lt_list_line_data (xc_list_line_rec).PRODUCT_ATTR_ITEM;
                                l_pricing_attr_tbl (ln_line_idx).product_uom_code   :=
                                    lt_list_line_data (xc_list_line_rec).product_uom_code;
                                l_pricing_attr_tbl (ln_line_idx).excluder_flag   :=
                                    'N';
                                --                          l_pricing_attr_tbl(ln_line_idx).product_attribute_datatype:=  FND_API.G_MISS_NUM;
                                --                          l_pricing_attr_tbl(ln_line_idx).attribute_grouping_no := 1;--lt_list_line_data(xc_list_line_rec).attribute_grouping_no;
                                l_pricing_attr_tbl (ln_line_idx).price_list_line_index   :=
                                    ln_line_idx;
                                l_pricing_attr_tbl (ln_line_idx).operation   :=
                                    qp_globals.g_opr_create;

                                --                          Error While Loading Item in Ptice List => Please enter required information - Excluder Flag.
                                --Error While Loading Item in Ptice List => Please enter required information - Product Attribute Value.
                                --Error While Loading Item in Ptice List => Please enter required information - Product Attribute Datatype.
                                --Error While Loading Item in Ptice List => Please enter required information - Attribute Grouping No.
                                IF l_price_list_rec.list_header_id > 0
                                THEN
                                    create_pricelist (
                                        p_price_list_rec   => l_price_list_rec,
                                        p_price_list_line_tbl   =>
                                            l_price_list_line_tbl,
                                        p_qualifiers_tbl   => l_qualifiers_tbl,
                                        p_pricing_attr_tbl   =>
                                            l_pricing_attr_tbl,
                                        x_return_status    => x_return_status);
                                    --l_price_list_rec.operation          :=        qp_globals.g_opr_update;
                                    ln_line_idx         := 0;
                                    ln_price_attr_idx   := 0;
                                    l_price_list_line_tbl.delete;
                                    l_pricing_attr_tbl.delete;
                                END IF;

                                IF x_return_status = 'S'
                                THEN
                                    UPDATE XXD_QP_LIST_LINES_STG_T
                                       SET RECORD_STATUS = gc_process_status
                                     WHERE     NAME =
                                               lt_list_line_data (
                                                   xc_list_line_rec).name
                                           AND PRODUCT_ATTRIBUTE_CONTEXT =
                                               lt_list_line_data (
                                                   xc_list_line_rec).PRODUCT_ATTRIBUTE_CONTEXT
                                           AND PRODUCT_ATTR_VALUE =
                                               lt_list_line_data (
                                                   xc_list_line_rec).PRODUCT_ATTR_VALUE
                                           AND PRODUCT_ATTR_ITEM =
                                               lt_list_line_data (
                                                   xc_list_line_rec).PRODUCT_ATTR_ITEM
                                           AND PRODUCT_UOM_CODE =
                                               lt_list_line_data (
                                                   xc_list_line_rec).PRODUCT_UOM_CODE
                                           AND RECORD_STATUS = p_action;
                                --                            record_id =
                                --                                     lt_list_line_data (xc_list_line_rec).RECORD_ID;
                                ELSE
                                    --                           UPDATE XXD_QP_LIST_LINES_STG_T
                                    --                              SET RECORD_STATUS = gc_error_status
                                    --                            WHERE record_id =
                                    --                                     lt_list_line_data (xc_list_line_rec).RECORD_ID;
                                    --
                                    UPDATE XXD_QP_LIST_LINES_STG_T
                                       SET RECORD_STATUS   = gc_error_status
                                     WHERE     NAME =
                                               lt_list_line_data (
                                                   xc_list_line_rec).name
                                           AND PRODUCT_ATTRIBUTE_CONTEXT =
                                               lt_list_line_data (
                                                   xc_list_line_rec).PRODUCT_ATTRIBUTE_CONTEXT
                                           AND PRODUCT_ATTR_VALUE =
                                               lt_list_line_data (
                                                   xc_list_line_rec).PRODUCT_ATTR_VALUE
                                           AND PRODUCT_ATTR_ITEM =
                                               lt_list_line_data (
                                                   xc_list_line_rec).PRODUCT_ATTR_ITEM
                                           AND PRODUCT_UOM_CODE =
                                               lt_list_line_data (
                                                   xc_list_line_rec).PRODUCT_UOM_CODE
                                           AND RECORD_STATUS = p_action;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    --lc_price_valid_data := gc_no_flag;
                                    write_log (
                                           '1 .Error while inserting data into QP_INTERFACE_LIST_LINES '
                                        || SQLERRM);
                                    RETCODE   := 2;
                                    ERRBUF    := ERRBUF || SQLERRM;

                                    xxd_common_utils.record_error ('QP', gn_org_id, 'XXD QP  Price List Conversion Program', --     SQLCODE,
                                                                                                                             'Error while inserting data into QP_INTERFACE_LIST_LINES ' || ERRBUF, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                                                                                        --    SYSDATE,
                                                                                                                                                                                                                                        gn_user_id
                                                                   , gn_conc_request_id --                       ,p_orig_sys_header_ref
                                 --                       ,p_orig_sys_line_ref
                         --                       ,p_orig_sys_pricing_attr_ref
                                                                   );
                            END;
                        END LOOP;
                    END IF;

                    COMMIT;
                END LOOP;

                CLOSE cur_list_lines;

                --update list qualifiers for the lines

                COMMIT;

                write_log (
                    ' create_pricelist  start Stauts ' || x_return_status);
                l_price_list_line_tbl.delete;
                l_qualifiers_tbl.delete;
                l_pricing_attr_tbl.delete;
            --    l_price_list_rec := NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --lc_price_valid_data := gc_no_flag;
                    write_log (
                           '2 .Error while inserting data into QP_INTERFACE_LIST_LINES '
                        || SQLERRM);
                    RETCODE   := 2;
                    ERRBUF    := ERRBUF || SQLERRM;
            END;
        END LOOP;
    -- qp List Headers


    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETCODE   := 2;
            ERRBUF    := ERRBUF || SQLERRM;
        WHEN OTHERS
        THEN
            RETCODE   := 2;
            ERRBUF    := ERRBUF || SQLERRM;
    END iface_price_list;

    PROCEDURE pricelist_child (errbuf                   OUT VARCHAR2,
                               retcode                  OUT VARCHAR2,
                               p_debug_flag          IN     VARCHAR2 DEFAULT 'N',
                               p_action              IN     VARCHAR2,
                               p_batch_id            IN     NUMBER,
                               p_parent_request_id   IN     NUMBER)
    AS
        le_invalid_param            EXCEPTION;
        ln_new_ou_id                hr_operating_units.organization_id%TYPE; --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12

        ln_request_id               NUMBER := 0;
        lc_username                 fnd_user.user_name%TYPE;
        lc_operating_unit           hr_operating_units.NAME%TYPE;
        lc_cust_num                 VARCHAR2 (5);
        lc_pri_flag                 VARCHAR2 (1);
        ld_start_date               DATE;
        ln_ins                      NUMBER := 0;
        ln_organization_id          NUMBER := 0;
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
    BEGIN
        gc_debug_flag        := p_debug_flag;
        gn_conc_request_id   := p_parent_request_id;

        --g_err_tbl_type.delete;
        BEGIN
            SELECT user_name
              INTO lc_username
              FROM fnd_user
             WHERE user_id = fnd_global.USER_ID;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_username   := NULL;
        END;

        BEGIN
            SELECT NAME
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;

        BEGIN
            fnd_client_info.set_org_context (fnd_profile.VALUE ('ORG_ID'));
            mo_global.set_policy_context ('S', fnd_profile.VALUE ('ORG_ID'));
            COMMIT;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                NULL;
            WHEN OTHERS
            THEN
                NULL;
        END;

        -- Validation Process for Price List Import
        write_log (
            '*************************************************************************** ');
        write_log (
               '***************     '
            || lc_operating_unit
            || '***************** ');
        write_log (
            '*************************************************************************** ');
        write_log (
               '                                         Busines Unit:'
            || lc_operating_unit);
        write_log (
               '                                         Run By      :'
            || lc_username);
        write_log (
               '                                         Run Date    :'
            || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        write_log (
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        write_log (
               '                                         Batch ID    :'
            || p_batch_id);
        --      fnd_file.new_line (, 1);
        write_log (
            '**********      QP Price List Validate/Import Program     ********** ');
        --      fnd_file.new_line (, 1);
        --      fnd_file.new_line (, 1);
        write_log (
            '+---------------------------------------------------------------------------+');
        write_log ('******** START of QP Price List Import Program ******');
        write_log (
            '+---------------------------------------------------------------------------+');


        IF p_action = gc_validate_only
        THEN
            write_log ('Calling pricelist_validation :');

            IF QP_UTIL.Get_Item_Validation_Org IS NULL
            THEN
                write_log (
                    'QP: Item Validation Organization Profile value not set');
                RAISE NO_DATA_FOUND;
            END IF;

            pricelist_validation (errbuf => errbuf, retcode => retcode, p_action => gc_new_status
                                  , p_batch_id => p_batch_id);
        ELSIF p_action = gc_load_only
        THEN
            iface_price_list (ERRBUF => errbuf, RETCODE => retcode, p_action => gc_validate_status
                              , p_batch_id => p_batch_id --p_lst_name   => list.name
                                                        );
        END IF;
    --      ELSIF p_action = 'VALIDATE AND LOAD'
    --      THEN
    --         NULL;
    --      END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            NULL;
        WHEN OTHERS
        THEN
            NULL;
    END pricelist_child;


    -- +===================================================================+
    -- | Name  : PRICELIST_MAIN                                            |
    -- | Description      : This is the main procedure  which will extract |
    -- |                    the data from 1206 to stage table and launch   |
    -- |                    child programs to validate and load Price lists|
    -- |                                                                   |
    -- |                                                                   |
    -- | Parameters : p_action, p_batch_size, p_debug, p_batch_cnt         |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :   x_errbuf, x_retcode                                   |
    -- |                                                                   |
    -- +===================================================================+
    --XXDQPPRICECONVERSION            XXD QP Price List Conversion
    PROCEDURE pricelist_main (
        errbuf           OUT NOCOPY VARCHAR2,
        retcode          OUT NOCOPY NUMBER,
        p_action      IN            VARCHAR2,
        p_batch_cnt   IN            NUMBER,
        -- p_batch_size     IN        NUMBER,
        p_debug       IN            VARCHAR2 DEFAULT NULL)
    IS
        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id        hdr_batch_id_t;
        lc_conlc_status        VARCHAR2 (150);
        ln_request_id          NUMBER := 0;
        lc_phase               VARCHAR2 (200);
        lc_status              VARCHAR2 (200);
        lc_dev_phase           VARCHAR2 (200);
        lc_dev_status          VARCHAR2 (200);
        lc_message             VARCHAR2 (200);
        ln_ret_code            NUMBER;
        lc_err_buff            VARCHAR2 (1000);
        ln_count               NUMBER;
        ln_cntr                NUMBER := 0;
        --      ln_batch_cnt          NUMBER                                   := 0;
        ln_parent_request_id   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
        lb_wait                BOOLEAN;
        lx_return_mesg         VARCHAR2 (2000);
        ln_valid_rec_cnt       NUMBER;
        l_total_rec            NUMBER;
        l_retcode              NUMBER;
        l_cp_cnt               NUMBER;
        l_errbuf               VARCHAR2 (2000);


        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id               request_table;
    BEGIN
        errbuf               := NULL;
        retcode              := 0;
        gc_debug_flag        := p_debug;
        gn_conc_request_id   := ln_parent_request_id;

        write_log ('p_action           =>           ' || p_action);
        write_log ('p_batch_cnt        =>           ' || p_batch_cnt);
        --write_log (, 'p_batch_size       =>           ' || p_batch_size);
        write_log ('Debug              =>           ' || gc_debug_flag);

        IF p_action = gc_extract_only
        THEN
            Write_log ('Truncate stage table Start');
            --truncate stage tables before extract from 1206
            --  truncte_stage_tables (x_ret_code => retcode, x_return_mesg => lx_return_mesg);
            write_log ('Truncate stage table End');
            --- extract 1206 priceing data to stage
            write_log ('Extract stage table from 1206 Start');
            --  extract_qp_1206_records (x_ret_code => retcode, x_return_mesg => lx_return_mesg);
            extract_1206_pricelist_data (x_errbuf    => l_errbuf,
                                         x_retcode   => l_retcode);
            write_log ('Extract stage table from 1206 End');
        ELSIF p_action = gc_validate_only
        THEN
            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM XXD_QP_LIST_LINES_STG_T
             WHERE RECORD_STATUS IN (gc_new_status, gc_error_status);

            --  AND name IN( 'Partner Retail CHN' );

            UPDATE XXD_QP_LIST_LINES_STG_T
               SET batch_id   = NULL                                    --NULL
             WHERE RECORD_STATUS IN (gc_new_status, gc_error_status);

            -- AND name IN( 'Partner Retail CHN' );

            write_log (
                'Creating Batch id and update  XXD_QP_LIST_LINES_STG_T');

            -- Create batches of records and assign batch id
            FOR i IN 1 .. p_batch_cnt
            LOOP
                BEGIN
                    SELECT XXD_QP_LIST_BATCH_ID_S.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    write_log (
                        'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                write_log (' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                write_log (
                       'ceil( ln_valid_rec_cnt/p_batch_cnt) := '
                    || CEIL (ln_valid_rec_cnt / p_batch_cnt));

                UPDATE XXD_QP_LIST_LINES_STG_T
                   SET batch_id = ln_hdr_batch_id (i), REQUEST_ID = ln_parent_request_id
                 WHERE     ROWNUM <= CEIL (ln_valid_rec_cnt / p_batch_cnt)
                       AND batch_id IS NULL
                       AND RECORD_STATUS IN (gc_new_status, gc_error_status);
            --AND name IN( 'Partner Retail CHN' ) ;
            END LOOP;

            write_log (
                'completed updating Batch id in  XXD_QP_LIST_HEADERS_STG_T');
        ELSIF p_action = gc_load_only
        THEN
            write_log (
                'Fetching batch id from XXD_QP_LIST_HEADERS_STG_T stage to call worker process');
            ln_cntr            := 0;

            /* FOR I
                IN (SELECT DISTINCT batch_id
                      FROM XXD_QP_LIST_LINES_STG_T
                     WHERE     batch_id IS NOT NULL
                           AND RECORD_STATUS = gc_validate_status)
             --AND name IN( 'Partner Retail CHN'))
             LOOP
                ln_cntr := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr) := i.batch_id;
             END LOOP;*/
            ln_valid_rec_cnt   := 0;

            FOR I
                IN (SELECT DISTINCT NAME
                      FROM XXD_QP_LIST_LINES_STG_T
                     WHERE     batch_id IS NOT NULL
                           AND RECORD_STATUS = gc_validate_status)
            --AND name IN( 'Partner Retail CHN'))
            LOOP
                BEGIN
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;

                    SELECT XXD_QP_LIST_BATCH_ID_S.NEXTVAL
                      INTO ln_hdr_batch_id (ln_valid_rec_cnt)
                      FROM DUAL;

                    write_log (
                           'ln_hdr_batch_id(i) := '
                        || ln_hdr_batch_id (ln_valid_rec_cnt));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (ln_valid_rec_cnt + 1)   :=
                            ln_hdr_batch_id (ln_valid_rec_cnt) + 1;
                END;

                --            write_log (' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                --            write_log (
                --                  'ceil( ln_valid_rec_cnt/p_batch_cnt) := '
                --               || CEIL (ln_valid_rec_cnt / p_batch_cnt));

                UPDATE XXD_QP_LIST_LINES_STG_T
                   SET batch_id = ln_hdr_batch_id (ln_valid_rec_cnt), REQUEST_ID = ln_parent_request_id
                 WHERE NAME = i.NAME --ROWNUM <= CEIL (ln_valid_rec_cnt / p_batch_cnt)
                                     --   AND batch_id IS NULL
                                     AND RECORD_STATUS = gc_validate_status;
            END LOOP;
        END IF;

        COMMIT;

        IF ln_hdr_batch_id.COUNT > 0
        THEN
            write_log (
                   'Calling XXDQPPRICECONVERSIONCHILD in batch '
                || ln_hdr_batch_id.COUNT);

            FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM XXD_QP_LIST_LINES_STG_T
                 WHERE batch_id = ln_hdr_batch_id (i);


                IF ln_cntr > 0
                THEN
                    BEGIN
                        write_log (
                               'Calling Worker process for batch id ln_hdr_batch_id(i) := '
                            || ln_hdr_batch_id (i));
                        ln_request_id   :=
                            apps.fnd_request.submit_request (
                                gc_xxdo,
                                'XXDQPPRICECONVERSIONCHILD',
                                '',
                                '',
                                FALSE,
                                p_debug,
                                p_action,
                                ln_hdr_batch_id (i),
                                ln_parent_request_id);
                        write_log ('v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (i)   := ln_request_id;
                            l_cp_cnt       := l_cp_cnt + 1;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            RETCODE   := 2;
                            ERRBUF    := ERRBUF || SQLERRM;
                            write_log (
                                   'Calling WAIT FOR REQUEST XXDQPPRICECONVERSIONCHILD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            RETCODE   := 2;
                            ERRBUF    := ERRBUF || SQLERRM;
                            write_log (
                                   'Calling WAIT FOR REQUEST XXDQPPRICECONVERSIONCHILD error'
                                || SQLERRM);
                    END;
                END IF;

                IF l_cp_cnt = p_batch_cnt
                THEN
                    IF l_req_id.COUNT > 0
                    THEN
                        write_log (
                               'Calling XXDQPPRICECONVERSIONCHILD in batch '
                            || ln_hdr_batch_id.COUNT);
                        write_log (
                            'Calling WAIT FOR REQUEST XXDQPPRICECONVERSIONCHILD to complete');

                        FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                        LOOP
                            IF l_req_id (rec) IS NOT NULL
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

                    ln_count   := 0;
                END IF;
            END LOOP;

            IF l_req_id.COUNT > 0
            THEN
                write_log (
                       'Calling XXDQPPRICECONVERSIONCHILD in batch '
                    || ln_hdr_batch_id.COUNT);
                write_log (
                    'Calling WAIT FOR REQUEST XXDQPPRICECONVERSIONCHILD to complete');

                FOR rec IN l_req_id.FIRST .. l_req_id.LAST
                LOOP
                    IF l_req_id (rec) IS NOT NULL
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
        END IF;
    --      print_processing_summary (  x_ret_code                 => retcode );
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (SQLERRM);
            errbuf    := SQLERRM;
            retcode   := 2;
            write_log ('Error in Price List Main' || SQLERRM);
    END pricelist_main;
END XXD_QP_PRICELISTCNV_PKG;
/
