--
-- XXD_QP_SEASON_PRICE_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:20 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_QP_SEASON_PRICE_CONV_PKG
AS
    g_dbg_mode               VARCHAR2 (10) := 'CONC';
    g_log_file               UTL_FILE.file_type;
    g_status                 VARCHAR2 (10);
    g_temp                   BOOLEAN;
    g_freight_param          VARCHAR2 (1);
    g_duty_param             VARCHAR2 (1);
    g_dutiable_oh_param      VARCHAR2 (1);
    g_nondutiable_oh_param   VARCHAR2 (1);
    g_precision              NUMBER;
    g_markup                 NUMBER;
    g_ex_rate                NUMBER;

    -- -------------------------------------------------------------------------------------------
    -- Ver No     Developer                 Date                           Description
    --
    -- -------------------------------------------------------------------------------------------
    -- 1.0       BT Technology Team        27-APR-2015                     Base Version
    --                                                           Season Price List Conversion
    -- *******************************************************************************************

    PROCEDURE print_log (p_msg VARCHAR2)
    IS
    BEGIN
        IF gc_debug_flag = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
            DBMS_OUTPUT.put_line (p_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'error While writing into log file ');
    END print_log;

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
     *                                                                                       *
     * Tables Accessed : (I - Insert, S - Select, U - Update, D - Delete )                   *
     *                                                                                       *
      *****************************************************************************************/

    FUNCTION Get_Product_Value (p_FlexField_Name IN VARCHAR2, p_Context_Name IN VARCHAR2, p_attribute_name IN VARCHAR2
                                , p_attr_value IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_item_id           NUMBER := NULL;
        l_category_id       NUMBER := NULL;
        l_segment_name      VARCHAR2 (240) := NULL;
        l_organization_id   VARCHAR2 (30)
                                := TO_CHAR (QP_UTIL.Get_Item_Validation_Org);
    BEGIN
        IF ((p_FlexField_Name = 'QP_ATTR_DEFNS_PRICING') AND (p_Context_Name = 'ITEM'))
        THEN
            IF (p_attribute_name = 'PRICING_ATTRIBUTE1')
            THEN
                SELECT inventory_item_id
                  INTO l_item_id
                  FROM mtl_system_items_vl
                 WHERE concatenated_segments = p_attr_value --            and organization_id = l_organization_id
                                                            AND ROWNUM = 1;


                RETURN l_item_id;
            ELSIF (p_attribute_name = 'PRICING_ATTRIBUTE2')
            THEN
                --              select category_name
                --                    into x_category_name
                --                    from qp_item_categories_v@BT_READ_1206
                --                    where category_id = to_number(p_attr_value) and rownum=1;


                BEGIN
                    SELECT category_id
                      INTO l_category_id
                      FROM qp_item_categories_v
                     WHERE category_name = TRIM (p_attr_value) AND ROWNUM = 1;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        NULL;
                    WHEN OTHERS
                    THEN
                        NULL;
                END;


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
            RETURN NULL;
    END Get_Product_Value;

    FUNCTION Get_1206_Product_Value (p_FlexField_Name IN VARCHAR2, p_Context_Name IN VARCHAR2, p_attribute_name IN VARCHAR2
                                     , p_attr_value IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_item_id           NUMBER := NULL;
        l_category_id       NUMBER := NULL;
        l_segment_name      VARCHAR2 (240) := NULL;
        x_category_name     VARCHAR2 (240) := NULL;
        l_organization_id   VARCHAR2 (30)
                                := TO_CHAR (QP_UTIL.Get_Item_Validation_Org);
    BEGIN
        IF ((p_FlexField_Name = 'QP_ATTR_DEFNS_PRICING') AND (p_Context_Name = 'ITEM'))
        THEN
            IF (p_attribute_name = 'PRICING_ATTRIBUTE1')
            THEN
                SELECT segment1
                  INTO x_category_name
                  FROM mtl_system_items_b
                 WHERE inventory_item_id = p_attr_value --and organization_id = l_organization_id
                                                        AND ROWNUM = 1;


                RETURN x_category_name;
            ELSIF (p_attribute_name = 'PRICING_ATTRIBUTE2')
            THEN
                SELECT DISTINCT category_name
                  INTO x_category_name
                  FROM qp_item_categories_v@BT_READ_1206
                 WHERE category_id = TO_NUMBER (p_attr_value) AND ROWNUM = 1;

                --           RETURN x_category_name;
                BEGIN
                    --               SELECT mc.segment1
                    --                 INTO x_category_name
                    --                 FROM mtl_categories_b mc, MTL_CATEGORY_SETS mcs
                    --                WHERE     mcs.structure_id = mc.structure_id
                    --                      AND segment1 LIKE x_category_name || '%'
                    --                      AND mcs.category_set_name = 'OM Sales Category';

                    SELECT DISTINCT style_desc
                      INTO x_category_name
                      FROM xxd_common_items_v
                     WHERE style_number = x_category_name;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        RAISE;
                    WHEN OTHERS
                    THEN
                        RAISE;
                END;


                RETURN x_category_name;
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
            RETURN NULL;
    END Get_1206_Product_Value;


    PROCEDURE write_out (p_in IN VARCHAR2 DEFAULT ' ')
    IS
    BEGIN
        IF (g_dbg_mode = 'CONC')
        THEN
            -- write to the concurrent request output file
            fnd_file.put_line (fnd_file.output, p_in);
        ELSIF (g_dbg_mode = 'FILE')
        THEN
            UTL_FILE.put_line (g_log_file, p_in);
            UTL_FILE.fflush (g_log_file);
        ELSE
            print_log (p_in);    -- Added by BT Technology Team on 27-Oct-2014
        END IF;
    END write_out;

    -- Start Changes by BT Technology Team on 27-Oct-2014


    PROCEDURE print_out (p_msg VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.output, p_msg);
        DBMS_OUTPUT.put_line (p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'error While writing into log file ');
    END print_out;

    PROCEDURE insert_price_list (
        p_price_list_rec        IN     apps.qp_price_list_pub.price_list_rec_type,
        p_price_list_line_tbl   IN     apps.qp_price_list_pub.price_list_line_tbl_type,
        p_pricing_attr_tbl      IN     apps.qp_price_list_pub.pricing_attr_tbl_type,
        x_return_status            OUT VARCHAR2,
        x_error_message            OUT VARCHAR2)
    IS
        c_return_status             VARCHAR2 (20000);
        c_error_data                VARCHAR2 (20000);
        n_msg_count                 NUMBER;
        c_msg_data                  VARCHAR2 (20000);
        n_err_count                 NUMBER;
        l_qualifiers_tbl            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_price_list_rec            apps.qp_price_list_pub.price_list_rec_type;
        l_price_list_val_rec        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_val_rec        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl       apps.qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        l_price_list_line_val_tbl   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        l_qualifiers_val_tbl        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl          apps.qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl      apps.qp_price_list_pub.pricing_attr_val_tbl_type;
        l_pricing_attr_val_tbl      apps.qp_price_list_pub.pricing_attr_val_tbl_type;
    BEGIN
        x_error_message   := NULL;
        oe_msg_pub.Initialize;

        --g_process_ind := 11;
        qp_price_list_pub.process_price_list (
            p_api_version_number        => 1.0,
            p_init_msg_list             => fnd_api.g_false,
            p_return_values             => fnd_api.g_false,
            p_commit                    => fnd_api.g_false,
            x_return_status             => c_return_status,
            x_msg_count                 => n_msg_count,
            x_msg_data                  => c_msg_data,
            p_price_list_rec            => p_price_list_rec,
            p_price_list_val_rec        => l_price_list_val_rec,
            p_price_list_line_tbl       => p_price_list_line_tbl,
            p_price_list_line_val_tbl   => l_price_list_line_val_tbl,
            p_qualifiers_tbl            => l_qualifiers_tbl,
            p_qualifiers_val_tbl        => l_qualifiers_val_tbl,
            p_pricing_attr_tbl          => p_pricing_attr_tbl,
            p_pricing_attr_val_tbl      => l_pricing_attr_val_tbl,
            x_price_list_rec            => x_price_list_rec,
            x_price_list_val_rec        => x_price_list_val_rec,
            x_price_list_line_tbl       => x_price_list_line_tbl,
            x_price_list_line_val_tbl   => x_price_list_line_val_tbl,
            x_qualifiers_tbl            => x_qualifiers_tbl,
            x_qualifiers_val_tbl        => x_qualifiers_val_tbl,
            x_pricing_attr_tbl          => x_pricing_attr_tbl,
            x_pricing_attr_val_tbl      => x_pricing_attr_val_tbl);

        x_return_status   := c_return_status;

        IF (c_return_status <> fnd_api.g_ret_sts_success)
        THEN
            ROLLBACK;
            oe_msg_pub.count_and_get (p_count   => n_err_count,
                                      p_data    => c_error_data);
            c_error_data   := NULL;

            FOR i IN 1 .. n_err_count
            LOOP
                c_msg_data   :=
                    oe_msg_pub.get (p_msg_index   => oe_msg_pub.g_next,
                                    p_encoded     => fnd_api.g_false);
                c_error_data   :=
                    SUBSTR (c_error_data || c_msg_data, 1, 2000);
                xxd_common_utils.record_error (
                    p_module       => 'QP',
                    p_org_id       => gn_org_id,
                    p_program      => 'Deckers QP Seasons Price List Conversion',
                    p_error_msg    => c_error_data,
                    p_error_line   => DBMS_UTILITY.format_error_backtrace,
                    p_created_by   => gn_user_id,
                    p_request_id   => gn_conc_request_id,
                    p_more_info1   => p_price_list_rec.list_header_id,
                    p_more_info2   => p_pricing_attr_tbl (1).list_line_id,
                    p_more_info3   =>
                        p_pricing_attr_tbl (1).product_attr_value,
                    p_more_info4   => p_pricing_attr_tbl (1).product_attribute);
            END LOOP;

            x_error_message   :=
                'Error in Prepare_end_date_prc :' || c_error_data;
        ELSE
            COMMIT;
        END IF;
    END insert_price_list;


    FUNCTION get_brand_style (p_category    IN VARCHAR2,
                              p_item_type   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_inv_item_id   NUMBER;
        lc_err_msg      VARCHAR2 (2000);
        l_brand         VARCHAR2 (200);
    BEGIN
        l_brand         := NULL;

        l_inv_item_id   := NULL;

        IF p_item_type = 'PRICING_ATTRIBUTE2'
        THEN
            SELECT BRAND
              INTO l_brand
              FROM XXD_COMMON_ITEMS_V
             WHERE style_desc = p_category AND ROWNUM < 2;
        ELSIF p_item_type = 'PRICING_ATTRIBUTE1'
        THEN
            SELECT BRAND
              INTO l_brand
              FROM XXD_COMMON_ITEMS_V
             WHERE ITEM_NUMBER = p_category AND ROWNUM < 2;
        END IF;

        RETURN l_brand;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_err_msg   :=
                   'No Brand exist for this Category - '
                || SUBSTR (SQLERRM, 1, 250);
            print_log (
                   'check_price_lists_exists: '
                || lc_err_msg
                || 'p_category '
                || p_category);

            RETURN NULL;
    END get_brand_style;


    PROCEDURE pricelist_validation (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_action IN VARCHAR2
                                    , p_batch_id IN NUMBER)
    AS
        PRAGMA AUTONOMOUS_TRANSACTION;


        CURSOR cur_qp_lines (p_action VARCHAR2)
        IS
            SELECT *
              FROM XXD_QP_SEASON_PRICE_CONV_TBL
             WHERE STATUS = 'N' AND batch_id = p_batch_id;

        TYPE t_price_list_add_rec IS TABLE OF cur_qp_lines%ROWTYPE
            INDEX BY PLS_INTEGER;


        lt_qp_lines_data         t_price_list_add_rec;

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
        print_log ('VALIDATE_QP_LINES');

        OPEN cur_qp_lines (p_action => p_action);

        LOOP
            FETCH cur_qp_lines BULK COLLECT INTO lt_qp_lines_data LIMIT 100;

            EXIT WHEN lt_qp_lines_data.COUNT = 0;
            print_log (
                   'Validation Rec count lt_qp_lines_data.COUNT =>'
                || lt_qp_lines_data.COUNT);

            IF lt_qp_lines_data.COUNT > 0
            THEN
                FOR xc_qp_lines_rec IN lt_qp_lines_data.FIRST ..
                                       lt_qp_lines_data.LAST
                LOOP
                    -- LIST_LINE_TYPE_CODE
                    print_log (' Validation');
                    lc_qp_lines_valid_data   := gc_yes_flag;

                    lc_product_attr_value    :=
                        Get_Product_Value (
                            p_FlexField_Name   => 'QP_ATTR_DEFNS_PRICING',
                            p_Context_Name     => 'ITEM',
                            p_attribute_name   =>
                                lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE,
                            p_attr_value       =>
                                lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_VALUE);

                    print_log (
                        'validate_priceattribs :' || lc_qp_lines_valid_data);

                    IF lc_product_attr_value IS NULL
                    THEN
                        lc_qp_lines_valid_data   := gc_no_flag;
                        xxd_common_utils.record_error (
                            p_module       => 'QP',
                            p_org_id       => gn_org_id,
                            p_program      =>
                                'Deckers QP Seasons Price List Conversion',
                            p_error_msg    =>
                                'Error to get the Pricing Attribute values',
                            p_error_line   =>
                                DBMS_UTILITY.format_error_backtrace,
                            p_created_by   => gn_user_id,
                            p_request_id   =>
                                lt_qp_lines_data (xc_qp_lines_rec).REQUEST_ID,
                            p_more_info1   =>
                                lt_qp_lines_data (xc_qp_lines_rec).PRICE_LIST_NAME,
                            p_more_info2   =>
                                lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_CONTEXT,
                            p_more_info3   =>
                                lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_ATTRIBUTE,
                            p_more_info4   =>
                                lt_qp_lines_data (xc_qp_lines_rec).PRODUCT_VALUE);
                    END IF;

                    IF lc_qp_lines_valid_data = gc_no_flag
                    THEN
                        UPDATE XXD_QP_SEASON_PRICE_CONV_TBL
                           SET STATUS = gc_error_status, PRODUCT_ATTR_VALUE = lc_product_attr_value, ERROR_MESSAGE = 'Error to get the Pricing Attribute values'
                         WHERE     SEQUENCE_ID =
                                   lt_qp_lines_data (xc_qp_lines_rec).SEQUENCE_ID
                               AND batch_id = p_batch_id;
                    ELSE
                        UPDATE XXD_QP_SEASON_PRICE_CONV_TBL
                           SET STATUS = gc_validate_status, PRODUCT_ATTR_VALUE = lc_product_attr_value
                         WHERE     SEQUENCE_ID =
                                   lt_qp_lines_data (xc_qp_lines_rec).SEQUENCE_ID
                               AND batch_id = p_batch_id;
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

    PROCEDURE UPDATE_STATUS (p_status IN VARCHAR2, p_error_message IN VARCHAR2, p_price_list_name IN VARCHAR2
                             , p_product_context IN VARCHAR2, p_product_attribute IN VARCHAR2, p_product_value IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        UPDATE xxd_qp_season_price_conv_tbl xpap
           SET status = p_status, error_message = p_error_message
         WHERE     xpap.price_list_name = p_price_list_name
               AND xpap.product_context = p_product_context
               AND xpap.product_attribute = p_product_attribute
               AND xpap.product_value = p_product_value;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxd_common_utils.record_error (
                p_module       => 'QP',
                p_org_id       => gn_org_id,
                p_program      => 'Deckers QP Seasons Price List Conversion',
                p_error_msg    => p_error_message,
                p_error_line   => DBMS_UTILITY.format_error_backtrace,
                p_created_by   => gn_user_id,
                p_request_id   => gn_conc_request_id,
                p_more_info1   => p_price_list_name,
                p_more_info2   => p_product_context,
                p_more_info3   => p_product_attribute,
                p_more_info4   => p_product_value);
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'exception while updating status' || SQLERRM);
    END UPDATE_STATUS;

    ------Start of adding the Extract Procedure on 21-Apr-2015
    PROCEDURE extract_1206_pricelist_data (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_price_list_type IN VARCHAR2
                                           , p_season IN VARCHAR2)
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
              FROM XXD_QP_SEASON_PRICE_CONV_TBL
             WHERE record_status = gc_new_status;

        --AND    source_org    = p_source_org_id;


        CURSOR lcu_price_list_data IS
            SELECT /*+ FIRST_ROWS(10) */
                   NULL
                       BATCH_ID,                         --'NEW' RECORD_STATUS
                   xxd_conv.XXD_QP_SEASON_PRICE_S.NEXTVAL
                       SEQUENCE_ID,
                   NEW_PRICELIST_NAME
                       PRICE_LIST_NAME,
                   PRODUCT_ATTRIBUTE_CONTEXT
                       PRODUCT_CONTEXT,
                   PRODUCT_ATTRIBUTE,
                   XXD_QP_SEASON_PRICE_CONV_PKG.Get_1206_Product_Value (
                       p_FlexField_Name   => 'QP_ATTR_DEFNS_PRICING',
                       p_Context_Name     => 'ITEM',
                       p_attribute_name   => PRODUCT_ATTRIBUTE,
                       p_attr_value       => PRODUCT_ATTR_VALUE)
                       PRODUCT_VALUE,
                   NULL
                       PRODUCT_ATTR_VALUE,
                   qpa.PRODUCT_UOM_CODE
                       UOM,
                   OPERAND
                       PRICE,
                   NULL
                       BRAND,
                   SEASON,
                   SEASON_START_DATE
                       VALID_FROM_DATE,
                   SEASON_END_DATE
                       VALID_TO_DATE,
                   'ADD'
                       RECORD_STATUS,
                   gn_conc_request_id
                       REQUEST_ID,
                   NULL
                       IMPORT_FLAG,
                   NULL
                       EXPORT_FLAG,
                   SYSDATE
                       CREATION_DATE,
                   -1
                       CREATED_BY,
                   SYSDATE
                       UPDATE_DATE,
                   -1
                       LAST_UPDATE_BY,
                   NULL
                       APPLICATION_METHOD,
                   'N'
                       STATUS,
                   NULL
                       ERROR_MESSAGE
              FROM qp_list_headers_all@bt_read_1206 qph, qp_list_lines@bt_read_1206 qll, qp_pricing_attributes@bt_read_1206 qpa,
                   xxd_conv.xxd_qp_season_price_map_tbl qsp
             WHERE     UPPER (qph.name) = UPPER (qsp.current_pricelist_name)
                   AND qll.list_header_id = qph.list_header_id
                   AND qll.list_header_id = qpa.list_header_id
                   AND qll.list_line_id = qpa.list_line_id
                   AND qsp.TYPE = p_price_list_type
                   AND qsp.SEASON = p_season
                   AND qsp.SEASON IS NOT NULL;

        TYPE XXD_QP_PRICE_LIST_TAB IS TABLE OF lcu_price_list_data%ROWTYPE
            INDEX BY BINARY_INTEGER;

        gtt_1206_price_list_tab   XXD_QP_PRICE_LIST_TAB;
    BEGIN
        gtt_1206_price_list_tab.delete;

        EXECUTE IMMEDIATE   'CREATE TABLE XXD_CONV.XXD_QP_SEASON_'
                         || gn_conc_request_id
                         || ' AS SELECT * FROM XXD_CONV.XXD_QP_SEASON_PRICE_CONV_TBL';

        COMMIT;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXD_CONV.XXD_QP_SEASON_PRICE_CONV_TBL';

        OPEN lcu_price_list_data;

        LOOP
            lv_error_stage   := 'Inserting Price list Data';
            print_log (lv_error_stage);

            --gtt_1206_price_list_tab.delete;

            FETCH lcu_price_list_data
                BULK COLLECT INTO gtt_1206_price_list_tab
                LIMIT 500;

            FOR i IN 1 .. gtt_1206_price_list_tab.COUNT
            LOOP
                print_log ('COUNT :' || gtt_1206_price_list_tab.COUNT);

                IF gtt_1206_price_list_tab (i).PRODUCT_VALUE IS NOT NULL
                THEN
                    BEGIN
                        gtt_1206_price_list_tab (i).brand   :=
                            get_brand_style (
                                p_category   =>
                                    gtt_1206_price_list_tab (i).PRODUCT_VALUE,
                                p_item_type   =>
                                    gtt_1206_price_list_tab (i).PRODUCT_ATTRIBUTE);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            xxd_common_utils.record_error (
                                p_module       => 'QP',
                                p_org_id       => gn_org_id,
                                p_program      =>
                                    'Deckers QP Seasons Price List Conversion',
                                p_error_msg    => 'Error to get the Brand Name',
                                p_error_line   =>
                                    DBMS_UTILITY.format_error_backtrace,
                                p_created_by   => gn_user_id,
                                p_request_id   => gn_conc_request_id,
                                p_more_info1   =>
                                    gtt_1206_price_list_tab (i).PRICE_LIST_NAME,
                                p_more_info2   =>
                                    gtt_1206_price_list_tab (i).PRODUCT_CONTEXT,
                                p_more_info3   =>
                                    gtt_1206_price_list_tab (i).PRODUCT_ATTRIBUTE,
                                p_more_info4   =>
                                    gtt_1206_price_list_tab (i).PRODUCT_VALUE);
                    END;

                    INSERT INTO XXD_QP_SEASON_PRICE_CONV_TBL
                         VALUES gtt_1206_price_list_tab (i);
                END IF;
            END LOOP;

            COMMIT;
            EXIT WHEN lcu_price_list_data%NOTFOUND;
        END LOOP;

        CLOSE lcu_price_list_data;

        IF p_price_list_type = 'Wholesale'
        THEN
            DELETE XXD_QP_SEASON_PRICE_CONV_TBL xqpl
             WHERE PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE1';
        ELSE
            DELETE XXD_QP_SEASON_PRICE_CONV_TBL xqpl
             WHERE PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE2';
        END IF;

        DELETE XXD_QP_SEASON_PRICE_CONV_TBL xqpl
         WHERE     PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE1'
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxd_conv.XXD_ITEM_1206_EXTRACT
                         WHERE ITEM_NUMBER = PRODUCT_VALUE);

        -- Delete the Categories which are not in - Price list extract should be based on Inventory extract table.

        DELETE /*+ Parallel(xqpl) */
               XXD_QP_SEASON_PRICE_CONV_TBL xqpl
         WHERE     PRODUCT_ATTRIBUTE = 'PRICING_ATTRIBUTE2'
               AND NOT EXISTS
                       (SELECT 1
                          FROM qp_item_categories_v
                         WHERE CATEGORY_NAME = PRODUCT_VALUE);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            print_log (
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            print_log (
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            print_log ('Exception ' || SQLERRM);
    END extract_1206_pricelist_data;

    -- End Changes by BT Technology Team on 27-Oct-2014
    PROCEDURE xxdoqp_populate_pricelist (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_batch_id IN VARCHAR2, p_action IN VARCHAR2, p_season IN VARCHAR2, p_price_list_type IN VARCHAR2
                                         , p_debug IN VARCHAR2)
    IS
        nrec                         qp_list_lines%ROWTYPE;
        new_list_line_number         NUMBER;
        attr_group_no                NUMBER;
        l_currency_precision         NUMBER;
        -- Start changes by BT Technology Team on 27-Oct-2014
        l_price_list_rec             qp_price_list_pub.price_list_rec_type;
        l_price_list_line_tbl        qp_price_list_pub.price_list_line_tbl_type;
        l_qualifiers_tbl             qp_qualifier_rules_pub.qualifiers_tbl_type;
        l_pricing_attr_tbl           qp_price_list_pub.pricing_attr_tbl_type;
        k                            NUMBER := 1;
        l_return_status              VARCHAR2 (4000) := NULL;
        l_msg_data                   VARCHAR2 (20000);
        l_price_list_rec1            apps.qp_price_list_pub.price_list_rec_type;
        l_price_list_line_tbl1       apps.qp_price_list_pub.price_list_line_tbl_type;
        l_pricing_attr_tbl1          apps.qp_price_list_pub.pricing_attr_tbl_type;
        x_price_list_rec1            apps.qp_price_list_pub.price_list_rec_type;
        x_price_list_val_rec1        apps.qp_price_list_pub.price_list_val_rec_type;
        x_price_list_line_tbl1       apps.qp_price_list_pub.price_list_line_tbl_type;
        x_price_list_line_val_tbl1   apps.qp_price_list_pub.price_list_line_val_tbl_type;
        x_qualifiers_tbl1            apps.qp_qualifier_rules_pub.qualifiers_tbl_type;
        x_qualifiers_val_tbl1        apps.qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        x_pricing_attr_tbl1          apps.qp_price_list_pub.pricing_attr_tbl_type;
        x_pricing_attr_val_tbl1      apps.qp_price_list_pub.pricing_attr_val_tbl_type;
        q                            NUMBER := 1;
        l_return_status1             VARCHAR2 (20000) := NULL;
        l_msg_data1                  VARCHAR2 (20000);
        s                            NUMBER := 1;
        t                            NUMBER := 1;
        l_return_status2             VARCHAR2 (1) := NULL;
        l_msg_count2                 NUMBER := 0;
        l_msg_data2                  VARCHAR2 (4000);
        l_product_value              VARCHAR2 (100);

        --      lc_price_list_type           VARCHAR2(100);

        CURSOR cur_price_list_add_new IS
            SELECT qph.list_header_id, xpap.*
              FROM QP_LIST_HEADERS_all QPH, XXD_QP_SEASON_PRICE_CONV_TBL xpap
             WHERE     qph.name = xpap.price_list_name
                   AND xpap.status = 'V'
                   AND xpap.batch_id = p_batch_id
                   AND NVL (UPPER (xpap.record_status), 'UPDATE') = 'ADD'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM qp_list_lines qll, QP_PRICING_ATTRIBUTES qpa
                             WHERE     qph.list_header_id =
                                       qll.list_header_id
                                   AND qpa.list_header_id =
                                       qll.list_header_id
                                   AND qpa.list_line_id = qll.list_line_id
                                   AND xpap.uom = qll.product_uom_code
                                   AND qpa.product_attribute_context =
                                       xpap.product_context
                                   AND qpa.product_attribute =
                                       xpap.product_attribute
                                   AND qpa.PRODUCT_ATTR_VALUE =
                                       TO_CHAR (xpap.PRODUCT_ATTR_VALUE)
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   qll.start_date_active,
                                                                     SYSDATE
                                                                   - 1)
                                                           AND NVL (
                                                                   qll.end_date_active,
                                                                     SYSDATE
                                                                   + 1));

        CURSOR cur_price_list_add IS
            SELECT xpap.request_id, qph.name, qph.list_header_id,
                   qll.list_line_id, xpap.valid_from_date, xpap.valid_to_date,
                   xpap.price, xpap.uom, xpap.brand,
                   xpap.season, qll.attribute2 spr_season, xpap.record_status,
                   xpap.product_context, xpap.product_attribute, qll.product_attribute_datatype,
                   xpap.price_list_name, XPAP.product_value product_val, qll.product_attr_value product_value
              FROM qp_list_lines_v qll, QP_LIST_HEADERS_all QPH, XXD_QP_SEASON_PRICE_CONV_TBL xpap
             WHERE     qph.list_header_id = qll.list_header_id
                   AND qll.list_line_type_code = 'PLL'
                   AND qph.name = xpap.price_list_name
                   AND xpap.status = 'V'
                   AND NVL (UPPER (xpap.record_status), 'UPDATE') = 'ADD'
                   AND xpap.uom = qll.product_uom_code
                   AND qll.product_attribute_context = xpap.product_context
                   AND qll.product_attribute = xpap.product_attribute
                   AND xpap.batch_id = p_batch_id
                   AND qll.product_attr_value =
                       TO_CHAR (xpap.PRODUCT_ATTR_VALUE)
                   --                get_product_value ('QP_ATTR_DEFNS_PRICING',
                   --                                                                 xpap.product_context,
                   --                                                                 xpap.product_attribute,
                   --                                                                 xpap.product_value)
                   --                                   and qll.operand = xpap.price
                   AND TRUNC (SYSDATE) BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE + 1);


        TYPE t_price_list_add_rec IS TABLE OF cur_price_list_add%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_price_list_add_rec         t_price_list_add_rec;


        TYPE t_price_list_add_new_rec
            IS TABLE OF cur_price_list_add_new%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_price_list_add_new_rec     t_price_list_add_new_rec;

        lc_season                    VARCHAR2 (250);
    BEGIN
        print_log ('Price list header id is ' || p_action);
        gc_debug_flag   := p_debug;
        mo_global.set_policy_context (
            'S',
            NVL (mo_global.get_current_org_id, mo_utils.get_default_org_id));

        IF p_action = gc_validate_only
        THEN
            pricelist_validation (errbuf => errbuf, retcode => retcode, p_action => p_action
                                  , p_batch_id => p_batch_id);
        ELSE
            print_log ('Price list p_action BEGIN ' || p_action);

            IF p_season LIKE 'SPRING%'
            THEN
                SELECT 'FALL ' || TO_CHAR (REPLACE (p_season, 'SPRING', '') - 1)
                  INTO lc_season
                  FROM DUAL;
            --     ELSE
            --        SELECT  REPLACE (p_season, 'SPRING', 'FALL')
            --         INTO lc_season
            --          FROM DUAL ;
            END IF;

            print_log (
                   'Price list p_action cur_price_list_add prev lc_season =>'
                || lc_season);

            IF p_season LIKE 'FALL%' OR p_price_list_type = 'Wholesale'
            THEN
                OPEN cur_price_list_add;

                print_log (
                       'Price list p_action cur_price_list_add p_batch_id =>'
                    || p_batch_id);

                LOOP
                    FETCH cur_price_list_add
                        BULK COLLECT INTO l_price_list_add_rec
                        LIMIT 100;

                    EXIT WHEN l_price_list_add_rec.COUNT = 0;

                    print_log (
                           'l_price_list_add_rec.COUNT => '
                        || l_price_list_add_rec.COUNT);

                    FOR l_add IN 1 .. l_price_list_add_rec.COUNT
                    LOOP
                        l_return_status1                   := NULL;
                        l_msg_data1                        := NULL;



                        IF l_price_list_add_rec (l_add).list_header_id
                               IS NOT NULL
                        THEN
                            print_log (
                                   'l_price_list_add_rec(l_add).list_header_id  => '
                                || l_price_list_add_rec (l_add).list_header_id);
                            k                                  := 1;

                            l_price_list_rec1.list_header_id   :=
                                l_price_list_add_rec (l_add).list_header_id;
                            l_price_list_rec1.list_type_code   := 'PRL';
                            l_price_list_rec1.operation        :=
                                qp_globals.g_opr_update;
                            l_price_list_line_tbl1 (k).list_header_id   :=
                                l_price_list_add_rec (l_add).list_header_id;
                            l_price_list_line_tbl1 (k).list_line_id   :=
                                l_price_list_add_rec (l_add).list_line_id;
                            l_price_list_line_tbl1 (k).operation   :=
                                qp_globals.g_opr_update;

                            --                     l_price_list_line_tbl1 (k).start_date_active := NULL; --l_price_list_add_rec(l_add).valid_from_date ; Commented by BT Team on 5/11/2015
                            l_price_list_line_tbl1 (k).end_date_active   :=
                                NULL;

                            BEGIN                     -- Ram *** To be changed
                                print_log (
                                    'SEASON_END_DATE season =>' || lc_season);
                                print_log (
                                       'SEASON_END_DATE name =>'
                                    || l_price_list_add_rec (l_add).name);

                                SELECT SEASON_END_DATE
                                  INTO l_price_list_line_tbl1 (k).end_date_active
                                  FROM XXD_CONV.XXD_QP_SEASON_PRICE_MAP_TBL
                                 WHERE     season = lc_season --l_price_list_add_rec(l_add).spr_season
                                       AND NEW_PRICELIST_NAME =
                                           l_price_list_add_rec (l_add).name;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    print_log (
                                        'SEASON_END_DATE is not Found in the mapping table');
                                    l_price_list_line_tbl1 (k).end_date_active   :=
                                        NULL;
                                    xxd_common_utils.record_error (
                                        p_module       => 'QP',
                                        p_org_id       => gn_org_id,
                                        p_program      =>
                                            'Deckers QP Seasons Price List Conversion',
                                        p_error_msg    =>
                                            'SEASON_END_DATE is not Found in the mapping table',
                                        p_error_line   =>
                                            DBMS_UTILITY.format_error_backtrace,
                                        p_created_by   => gn_user_id,
                                        p_request_id   => gn_conc_request_id,
                                        p_more_info1   =>
                                            l_price_list_add_rec (l_add).name,
                                        p_more_info2   =>
                                            l_price_list_add_rec (l_add).spr_season,
                                        p_more_info3   => NULL,
                                        p_more_info4   => NULL);
                                WHEN OTHERS
                                THEN
                                    l_price_list_line_tbl1 (k).end_date_active   :=
                                        NULL;
                            END;

                            print_log (
                                   'l_price_list_line_tbl1 (k).end_date_active => '
                                || l_price_list_line_tbl1 (k).end_date_active);
                            print_log (
                                   'l_price_list_line_tbl1 (k).valid_from_date => '
                                || l_price_list_add_rec (l_add).valid_from_date);

                            IF l_price_list_line_tbl1 (k).end_date_active
                                   IS NULL
                            THEN
                                l_price_list_line_tbl1 (k).end_date_active   :=
                                      l_price_list_add_rec (l_add).valid_from_date
                                    - 1;
                            --                        l_price_list_line_tbl1 (k).attribute2 := lc_season; -- ***Commented by BT Team on 5/11/2015
                            END IF;

                            print_log (
                                   'l_price_list_line_tbl1 (k).end_date_activ f => '
                                || l_price_list_line_tbl1 (k).end_date_active);
                            --            l_price_list_line_tbl1 (k).end_date_active       := l_price_list_add_rec(l_add).valid_from_date - 1 ;
                            --l_price_list_add_rec(l_add).valid_to_date ;
                            print_log (
                                   'Calling insert_price_list1 => '
                                || l_return_status1);

                            BEGIN
                                insert_price_list (
                                    p_price_list_rec     => l_price_list_rec1,
                                    p_price_list_line_tbl   =>
                                        l_price_list_line_tbl1,
                                    p_pricing_attr_tbl   =>
                                        l_pricing_attr_tbl1,
                                    x_return_status      => l_return_status1,
                                    x_error_message      => l_msg_data1);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    print_log (
                                        l_return_status1 || '  ' || SQLERRM);
                            END;

                            --            COMMIT;
                            print_log (
                                   'Calling insert_price_list1 w=> '
                                || l_return_status1);

                            IF l_return_status1 <>
                               apps.fnd_api.g_ret_sts_success
                            THEN
                                print_log ('Error is ' || l_msg_data1);
                                UPDATE_STATUS (
                                    p_status   => 'E',
                                    p_error_message   =>
                                        SUBSTR (l_msg_data1, 1, 1000),
                                    p_price_list_name   =>
                                        l_price_list_add_rec (l_add).price_list_name,
                                    p_product_context   =>
                                        l_price_list_add_rec (l_add).product_context,
                                    p_product_attribute   =>
                                        l_price_list_add_rec (l_add).product_attribute,
                                    p_product_value   =>
                                        l_price_list_add_rec (l_add).product_val);
                            ELSE
                                print_log (
                                    'Else to create new price list line');
                                l_price_list_rec1.list_header_id   := NULL;
                                l_price_list_rec1.list_type_code   := NULL;
                                l_price_list_line_tbl1.delete;
                                l_pricing_attr_tbl1.delete;

                                s                                  := 1;
                                l_price_list_rec1.list_header_id   :=
                                    l_price_list_add_rec (l_add).list_header_id;
                                l_price_list_rec1.list_type_code   := 'PRL';
                                l_price_list_rec1.operation        :=
                                    qp_globals.g_opr_update;
                                l_price_list_line_tbl1 (s).list_header_id   :=
                                    l_price_list_add_rec (l_add).list_header_id;
                                l_price_list_line_tbl1 (s).list_line_id   :=
                                    qp_list_lines_s.NEXTVAL;
                                l_price_list_line_tbl1 (s).list_line_type_code   :=
                                    'PLL';
                                l_price_list_line_tbl1 (s).operation   :=
                                    qp_globals.g_opr_create;
                                l_price_list_line_tbl1 (s).operand   :=
                                    l_price_list_add_rec (l_add).price;
                                l_price_list_line_tbl1 (s).attribute1   :=
                                    l_price_list_add_rec (l_add).brand;
                                l_price_list_line_tbl1 (s).attribute2   :=
                                    l_price_list_add_rec (l_add).season;
                                l_price_list_line_tbl1 (s).arithmetic_operator   :=
                                    'UNIT_PRICE';
                                --                        l_price_list_line_tbl1 (s).start_date_active :=
                                --                           l_price_list_add_rec (l_add).valid_from_date;
                                --                        l_price_list_line_tbl1 (s).end_date_active := NULL;

                                l_price_list_line_tbl1 (s).start_date_active   :=
                                    l_price_list_add_rec (l_add).valid_from_date;
                                l_price_list_line_tbl1 (s).end_date_active   :=
                                    NULL;

                                t                                  :=
                                    1;
                                print_log (
                                       'l_price_list_line_tbl1 (s).start_date_active => '
                                    || l_price_list_line_tbl1 (s).start_date_active);

                                SELECT apps.qp_pricing_attr_group_no_s.NEXTVAL
                                  INTO attr_group_no
                                  FROM DUAL;


                                l_pricing_attr_tbl1 (t).list_line_id   :=
                                    l_price_list_line_tbl1 (s).list_line_id;
                                l_pricing_attr_tbl1 (t).product_attribute_context   :=
                                    l_price_list_add_rec (l_add).product_context; --'ITEM';
                                l_pricing_attr_tbl1 (t).product_attribute   :=
                                    l_price_list_add_rec (l_add).product_attribute; -- 'PRICING_ATTRIBUTE1';
                                l_pricing_attr_tbl1 (t).product_attribute_datatype   :=
                                    l_price_list_add_rec (l_add).product_attribute_datatype;
                                l_pricing_attr_tbl1 (t).product_attr_value   :=
                                    l_price_list_add_rec (l_add).product_value;
                                l_pricing_attr_tbl1 (t).product_uom_code   :=
                                    l_price_list_add_rec (l_add).uom;
                                l_pricing_attr_tbl1 (t).excluder_flag   :=
                                    'N';
                                l_pricing_attr_tbl1 (t).attribute_grouping_no   :=
                                    attr_group_no;
                                l_pricing_attr_tbl1 (t).operation   :=
                                    qp_globals.g_opr_create;

                                BEGIN
                                    insert_price_list (
                                        p_price_list_rec   =>
                                            l_price_list_rec1,
                                        p_price_list_line_tbl   =>
                                            l_price_list_line_tbl1,
                                        p_pricing_attr_tbl   =>
                                            l_pricing_attr_tbl1,
                                        x_return_status   => l_return_status1,
                                        x_error_message   => l_msg_data1);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        print_log (
                                               l_return_status1
                                            || '  '
                                            || SQLERRM);
                                END;

                                print_log (
                                       'Else to create new price list line l_return_status1 => '
                                    || l_return_status1);

                                IF l_return_status1 <>
                                   apps.fnd_api.g_ret_sts_success
                                THEN
                                    UPDATE_STATUS (
                                        p_status   => 'E',
                                        p_error_message   =>
                                            SUBSTR (l_msg_data1, 1, 1000),
                                        p_price_list_name   =>
                                            l_price_list_add_rec (l_add).price_list_name,
                                        p_product_context   =>
                                            l_price_list_add_rec (l_add).product_context,
                                        p_product_attribute   =>
                                            l_price_list_add_rec (l_add).product_attribute,
                                        p_product_value   =>
                                            l_price_list_add_rec (l_add).product_val);
                                ELSE
                                    UPDATE_STATUS (
                                        p_status          => 'S',
                                        p_error_message   => NULL,
                                        p_price_list_name   =>
                                            l_price_list_add_rec (l_add).price_list_name,
                                        p_product_context   =>
                                            l_price_list_add_rec (l_add).product_context,
                                        p_product_attribute   =>
                                            l_price_list_add_rec (l_add).product_attribute,
                                        p_product_value   =>
                                            l_price_list_add_rec (l_add).product_val);
                                END IF;
                            END IF;
                        END IF;

                        l_price_list_rec1.list_header_id   := NULL;
                        l_price_list_rec1.list_type_code   := NULL;
                        l_price_list_line_tbl1.delete;
                        l_pricing_attr_tbl1.delete;
                    END LOOP;

                    COMMIT;
                END LOOP;

                CLOSE cur_price_list_add;
            END IF;                         -- IF p_season like 'SPRING%' THEN

            OPEN cur_price_list_add_new;

            LOOP
                FETCH cur_price_list_add_new
                    BULK COLLECT INTO l_price_list_add_new_rec
                    LIMIT 100;

                EXIT WHEN l_price_list_add_new_rec.COUNT = 0;

                FOR l_add_new IN 1 .. l_price_list_add_new_rec.COUNT
                LOOP
                    l_return_status1                   := NULL;
                    l_msg_data1                        := NULL;

                    print_log (
                           'Price list header id is '
                        || l_price_list_add_new_rec (l_add_new).list_header_id);

                    -- Start changes by BT Technology Team on 27-Oct-2014
                    --IF nRec IS NOT NULL
                    IF l_price_list_add_new_rec (l_add_new).list_header_id
                           IS NOT NULL
                    THEN
                        l_price_list_rec1.list_header_id                 := NULL;
                        l_price_list_rec1.list_type_code                 := NULL;
                        l_price_list_line_tbl1.delete;
                        l_pricing_attr_tbl1.delete;

                        s                                                := 1;
                        l_price_list_rec1.list_header_id                 :=
                            l_price_list_add_new_rec (l_add_new).list_header_id;
                        l_price_list_rec1.list_type_code                 := 'PRL';
                        l_price_list_rec1.operation                      :=
                            qp_globals.g_opr_update;
                        l_price_list_line_tbl1 (s).list_header_id        :=
                            l_price_list_add_new_rec (l_add_new).list_header_id;
                        l_price_list_line_tbl1 (s).list_line_id          :=
                            qp_list_lines_s.NEXTVAL;
                        l_price_list_line_tbl1 (s).list_line_type_code   :=
                            'PLL';
                        l_price_list_line_tbl1 (s).operation             :=
                            qp_globals.g_opr_create;
                        l_price_list_line_tbl1 (s).operand               :=
                            l_price_list_add_new_rec (l_add_new).price;
                        l_price_list_line_tbl1 (s).attribute1            :=
                            l_price_list_add_new_rec (l_add_new).brand;
                        l_price_list_line_tbl1 (s).attribute2            :=
                            l_price_list_add_new_rec (l_add_new).season;
                        l_price_list_line_tbl1 (s).arithmetic_operator   :=
                            'UNIT_PRICE';

                        IF p_price_list_type = 'Wholesale'
                        THEN
                            l_price_list_line_tbl1 (s).start_date_active   :=
                                l_price_list_add_new_rec (l_add_new).valid_from_date;
                            l_price_list_line_tbl1 (s).end_date_active   :=
                                NULL;
                        ELSE
                            l_price_list_line_tbl1 (s).start_date_active   :=
                                NULL;
                            l_price_list_line_tbl1 (s).end_date_active   :=
                                NULL;
                        END IF;

                        t                                                := 1;

                        SELECT apps.qp_pricing_attr_group_no_s.NEXTVAL
                          INTO attr_group_no
                          FROM DUAL;

                        --           l_product_value := Get_Product_Value ('QP_ATTR_DEFNS_PRICING',
                        --                                                  l_price_list_add_new_rec(l_add_new).product_context,
                        --                                                  l_price_list_add_new_rec(l_add_new).product_attribute,
                        --                                                  l_price_list_add_new_rec(l_add_new).product_value);


                        l_pricing_attr_tbl1 (t).list_line_id             :=
                            l_price_list_line_tbl1 (s).list_line_id;
                        l_pricing_attr_tbl1 (t).product_attribute_context   :=
                            l_price_list_add_new_rec (l_add_new).product_context; --'ITEM';
                        l_pricing_attr_tbl1 (t).product_attribute        :=
                            l_price_list_add_new_rec (l_add_new).product_attribute; -- 'PRICING_ATTRIBUTE1';
                        l_pricing_attr_tbl1 (t).product_attribute_datatype   :=
                            'C';
                        l_pricing_attr_tbl1 (t).product_attr_value       :=
                            l_price_list_add_new_rec (l_add_new).PRODUCT_ATTR_VALUE;
                        l_pricing_attr_tbl1 (t).product_uom_code         :=
                            l_price_list_add_new_rec (l_add_new).uom;
                        l_pricing_attr_tbl1 (t).excluder_flag            :=
                            'N';
                        l_pricing_attr_tbl1 (t).attribute_grouping_no    :=
                            attr_group_no;
                        l_pricing_attr_tbl1 (t).operation                :=
                            qp_globals.g_opr_create;

                        IF l_price_list_add_new_rec (l_add_new).PRODUCT_ATTR_VALUE
                               IS NOT NULL
                        THEN
                            BEGIN
                                print_log (
                                       'PRODUCT_ATTR_VALUE => '
                                    || l_price_list_add_new_rec (l_add_new).PRODUCT_ATTR_VALUE);
                                insert_price_list (
                                    p_price_list_rec     => l_price_list_rec1,
                                    p_price_list_line_tbl   =>
                                        l_price_list_line_tbl1,
                                    p_pricing_attr_tbl   =>
                                        l_pricing_attr_tbl1,
                                    x_return_status      => l_return_status1,
                                    x_error_message      => l_msg_data1);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    print_log (
                                        l_return_status1 || '  ' || SQLERRM);
                            END;
                        ELSE
                            print_log (l_return_status1 || '  ' || SQLERRM);
                        END IF;


                        IF l_return_status1 <> apps.fnd_api.g_ret_sts_success
                        THEN
                            print_log ('Error is ' || l_msg_data1);
                            UPDATE_STATUS (
                                p_status   => 'E',
                                p_error_message   =>
                                    SUBSTR (l_msg_data1, 1, 2500),
                                p_price_list_name   =>
                                    l_price_list_add_new_rec (l_add_new).price_list_name,
                                p_product_context   =>
                                    l_price_list_add_new_rec (l_add_new).product_context,
                                p_product_attribute   =>
                                    l_price_list_add_new_rec (l_add_new).product_attribute,
                                p_product_value   =>
                                    l_price_list_add_new_rec (l_add_new).product_value);
                        ELSE
                            UPDATE_STATUS (
                                p_status          => 'S',
                                p_error_message   => NULL,
                                p_price_list_name   =>
                                    l_price_list_add_new_rec (l_add_new).price_list_name,
                                p_product_context   =>
                                    l_price_list_add_new_rec (l_add_new).product_context,
                                p_product_attribute   =>
                                    l_price_list_add_new_rec (l_add_new).product_attribute,
                                p_product_value   =>
                                    l_price_list_add_new_rec (l_add_new).product_value);
                        END IF;
                    END IF;

                    l_price_list_rec1.list_header_id   := NULL;
                    l_price_list_rec1.list_type_code   := NULL;
                    l_price_list_line_tbl1.delete;
                    l_pricing_attr_tbl1.delete;
                END LOOP;

                COMMIT;
            END LOOP;

            CLOSE cur_price_list_add_new;
        END IF;

        -- End Changes by BT Technology Team on 27-Oct-014

        print_log ('program completed successfully');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_out (
                   'Unexpected Error Encountered : '
                || SQLCODE
                || '-'
                || SQLERRM);

            print_log (
                   'Unexpected Error Encountered : '
                || SQLCODE
                || '-'
                || SQLERRM);     -- Added by BT Technology Team on 27-Oct-2014
            errbuf    := 'Request completed with warning';
            retcode   := '1';
            g_temp    := fnd_concurrent.set_completion_status ('WARNING', '');
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
            ROLLBACK;
    END xxdoqp_populate_pricelist;



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
    PROCEDURE pricelist_main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_action IN VARCHAR2
                              , p_price_list_type IN VARCHAR2, p_season IN VARCHAR2, -- p_batch_size     IN        NUMBER,
                                                                                     p_debug IN VARCHAR2 DEFAULT NULL)
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
        ln_valid_rec_cnt       NUMBER := 0;
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

        print_log ('p_action           =>           ' || p_action);
        --print_log (, 'p_batch_size       =>           ' || p_batch_size);
        print_log ('Debug              =>           ' || gc_debug_flag);

        IF p_action = gc_extract_only
        THEN
            print_log ('Truncate stage table Start');
            --truncate stage tables before extract from 1206
            --  truncte_stage_tables (x_ret_code => retcode, x_return_mesg => lx_return_mesg);
            print_log ('Truncate stage table End');
            --- extract 1206 priceing data to stage
            print_log ('Extract stage table from 1206 Start');
            --  extract_qp_1206_records (x_ret_code => retcode, x_return_mesg => lx_return_mesg);
            extract_1206_pricelist_data (x_errbuf => l_errbuf, x_retcode => l_retcode, p_price_list_type => p_price_list_type
                                         , p_season => p_season);
            print_log ('Extract stage table from 1206 End');
        ELSIF p_action = gc_validate_only
        THEN
            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM XXD_QP_SEASON_PRICE_CONV_TBL
             WHERE     STATUS IN (gc_new_status, gc_error_status)
                   AND season = p_season;

            --  AND name IN( 'Partner Retail CHN' );

            UPDATE XXD_QP_SEASON_PRICE_CONV_TBL
               SET batch_id   = NULL                                    --NULL
             WHERE     STATUS IN (gc_new_status, gc_error_status)
                   AND season = p_season;

            -- AND name IN( 'Partner Retail CHN' );

            print_log (
                'Creating Batch id and update  XXD_QP_SEASON_PRICE_CONV_TBL');

            -- Create batches of records and assign batch id
            FOR i IN 1 .. 6
            LOOP
                BEGIN
                    SELECT XXD_QP_LIST_BATCH_ID_S.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    print_log (
                        'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                print_log (' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                print_log (
                       'ceil( ln_valid_rec_cnt/6) := '
                    || CEIL (ln_valid_rec_cnt / 6));

                UPDATE XXD_QP_SEASON_PRICE_CONV_TBL
                   SET batch_id = ln_hdr_batch_id (i), REQUEST_ID = ln_parent_request_id
                 WHERE     ROWNUM <= CEIL (ln_valid_rec_cnt / 6)
                       AND batch_id IS NULL
                       AND season = p_season
                       AND STATUS IN (gc_new_status, gc_error_status);
            --AND name IN( 'Partner Retail CHN' ) ;
            END LOOP;

            print_log (
                'completed updating Batch id in  XXD_QP_LIST_HEADERS_STG_T');
        ELSIF p_action = gc_load_only
        THEN
            print_log (
                'completed updating Batch id in  XXD_QP_SEASON_PRICE_CONV_TBL');

            FOR I
                IN (SELECT DISTINCT price_list_name
                      FROM XXD_QP_SEASON_PRICE_CONV_TBL
                     WHERE     batch_id IS NOT NULL
                           AND STATUS = 'V'
                           AND SEASON = p_season)        --gc_validate_status)
            --AND name IN( 'Partner Retail CHN'))
            LOOP
                BEGIN
                    ln_valid_rec_cnt   := ln_valid_rec_cnt + 1;

                    SELECT XXD_QP_LIST_BATCH_ID_S.NEXTVAL
                      INTO ln_hdr_batch_id (ln_valid_rec_cnt)
                      FROM DUAL;

                    print_log (
                           'ln_hdr_batch_id(i) := '
                        || ln_hdr_batch_id (ln_valid_rec_cnt));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (ln_valid_rec_cnt + 1)   :=
                            ln_hdr_batch_id (ln_valid_rec_cnt) + 1;
                END;

                --            print_log (' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                --            print_log (
                --                  'ceil( ln_valid_rec_cnt/p_batch_cnt) := '
                --               || CEIL (ln_valid_rec_cnt / p_batch_cnt));

                UPDATE XXD_QP_SEASON_PRICE_CONV_TBL
                   SET batch_id = ln_hdr_batch_id (ln_valid_rec_cnt), REQUEST_ID = ln_parent_request_id
                 WHERE price_list_name = i.price_list_name --ROWNUM <= CEIL (ln_valid_rec_cnt / p_batch_cnt)
                                                     --   AND batch_id IS NULL
                        AND STATUS = 'V' AND season = p_season;
            END LOOP;
        END IF;

        COMMIT;

        IF ln_hdr_batch_id.COUNT > 0
        THEN
            print_log (
                   'Calling XXDQPSEASONPRICECONVCHLD in batch '
                || ln_hdr_batch_id.COUNT);

            FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM XXD_QP_SEASON_PRICE_CONV_TBL
                 WHERE batch_id = ln_hdr_batch_id (i);


                IF ln_cntr > 0
                THEN
                    BEGIN
                        print_log (
                               'Calling Worker process for batch id ln_hdr_batch_id(i) := '
                            || ln_hdr_batch_id (i));
                        ln_request_id   :=
                            apps.fnd_request.submit_request (gc_xxdo, 'XXDQPSEASONPRICECONVCHLD', '', '', FALSE, ln_hdr_batch_id (i), p_action, p_season, p_price_list_type
                                                             , p_debug);
                        print_log ('v_request_id := ' || ln_request_id);

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
                            RETCODE   := 2;
                            ERRBUF    := ERRBUF || SQLERRM;
                            print_log (
                                   'Calling WAIT FOR REQUEST XXDQPSEASONPRICECONVCHLD error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            RETCODE   := 2;
                            ERRBUF    := ERRBUF || SQLERRM;
                            print_log (
                                   'Calling WAIT FOR REQUEST XXDQPSEASONPRICECONVCHLD error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;

            IF l_req_id.COUNT > 0
            THEN
                print_log (
                       'Calling XXDQPSEASONPRICECONVCHLD in batch '
                    || ln_hdr_batch_id.COUNT);
                print_log (
                    'Calling WAIT FOR REQUEST XXDQPSEASONPRICECONVCHLD to complete');

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
            print_log (SQLERRM);
            errbuf    := SQLERRM;
            retcode   := 2;
            print_log ('Error in Price List Main' || SQLERRM);
    END pricelist_main;
END XXD_QP_SEASON_PRICE_CONV_PKG;
/
