--
-- XXD_QP_PRICE_LIST_UPLOAD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_QP_PRICE_LIST_UPLOAD_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_QP_PRICE_LIST_UPLOAD_PKG
    * Design       : This package is used for Price List WebADI upload
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 14-Feb-2017  1.0        Viswanathan Pandian     Initial Version
    -- 16-Jan-2023  1.1        Pardeep Rohilla         Changes for CCR0010303
    ******************************************************************************************/
    PROCEDURE validate_prc (
        p_price_list        IN qp_list_headers_v.name%TYPE,
        p_attribute_name    IN qp_list_lines_v.product_attribute%TYPE,
        p_attribute_value   IN qp_list_lines_v.product_attr_value%TYPE,
        p_uom_code          IN qp_list_lines_v.product_uom_code%TYPE,
        p_list_price        IN qp_list_lines_v.list_price%TYPE,
        p_start_date        IN qp_list_lines_v.start_date_active%TYPE,
        p_end_date          IN qp_list_lines_v.end_date_active%TYPE,
        p_list_line_id      IN qp_list_lines_v.list_line_id%TYPE,
        p_brand             IN qp_list_lines_v.attribute1%TYPE,
        p_season            IN qp_list_lines_v.attribute2%TYPE,
        p_mdm_notes         IN qp_list_lines_v.attribute3%TYPE)
    AS
        CURSOR get_uom_code IS
            SELECT DISTINCT primary_uom_code
              FROM xxd_common_items_v
             WHERE     master_org_flag = 'Y'
                   AND ((item_number = p_attribute_value AND UPPER (p_attribute_name) = 'SKU') OR (style_number = p_attribute_value AND UPPER (p_attribute_name) = 'STYLE'));

        CURSOR get_category_c IS
              SELECT price_cat.category_id, COUNT (DISTINCT price_cat.category_id) category_count
                FROM mtl_categories_v item_cat, mtl_categories_v price_cat
               WHERE     item_cat.structure_name = 'Item Categories'
                     AND price_cat.structure_name = 'PriceList Item Categories'
                     AND item_cat.segment7 = price_cat.segment1
                     AND TRUNC (NVL (price_cat.disable_date, SYSDATE)) >=
                         TRUNC (SYSDATE)
                     AND item_cat.attribute7 = p_attribute_value
            GROUP BY price_cat.category_id;

        --- Added for CCR0010303
        CURSOR get_style_color_data_c IS
            SELECT DISTINCT p_price_list, 'PRICING_ATTRIBUTE1' adi_attribute_name, p_attribute_name,
                            a.item_number adi_attribute_value, p_attribute_value, p_uom_code,
                            p_list_price, p_start_date, p_end_date,
                            p_list_line_id, p_brand, p_season,
                            p_mdm_notes
              FROM xxd_common_items_v a
             WHERE     a.master_org_flag = 'Y'
                   AND a.STYLE_NUMBER = REGEXP_SUBSTR (p_attribute_value, '[^-]+', 1
                                                       , 1)
                   AND a.Color_code = REGEXP_SUBSTR (p_attribute_value, '[^-]+', 1
                                                     , 2);

        --- Added for CCR0010303
        CURSOR get_uom_for_sty_col_c IS
            SELECT DISTINCT b.primary_uom_code
              FROM xxd_common_items_v b
             WHERE     b.master_org_flag = 'Y'
                   AND b.STYLE_NUMBER = REGEXP_SUBSTR (p_attribute_value, '[^-]+', 1
                                                       , 1)
                   AND b.Color_code = REGEXP_SUBSTR (p_attribute_value, '[^-]+', 1
                                                     , 2)
                   AND UPPER (p_attribute_name) = 'STYLE-COLOR';



        le_webadi_exception          EXCEPTION;
        lc_brand                     xxd_common_items_v.brand%TYPE;
        ln_list_header_id            qp_list_headers_v.list_header_id%TYPE;
        ln_inventory_item_id         xxd_common_items_v.inventory_item_id%TYPE;
        ln_category_id               xxd_common_items_v.category_id%TYPE;
        lc_product_attribute         qp_list_lines_v.product_attribute%TYPE;
        lc_uom_code                  qp_list_lines_v.product_uom_code%TYPE;
        ln_max_list_line_id          qp_list_lines_v.list_line_id%TYPE;
        ln_precedence                qp_list_lines_v.product_precedence%TYPE;
        lc_product_attr_value        qp_list_lines_v.product_attr_value%TYPE;
        lc_product_attr_val_disp     qp_list_lines_v.product_attr_val_disp%TYPE;
        lc_current_mdm_notes         qp_list_lines_v.attribute3%TYPE;
        ln_pricing_attribute_id      qp_list_lines_v.pricing_attribute_id%TYPE;
        lcu_uom_code                 get_uom_code%ROWTYPE;
        lcu_category                 get_category_c%ROWTYPE;
        lcu_k                        get_uom_for_sty_col_c%ROWTYPE; --- Added for CCR0010303
        lc_return_status             VARCHAR2 (4000);
        lc_msg_data                  VARCHAR2 (4000);
        lc_err_message               VARCHAR2 (4000);
        ln_msg_count                 NUMBER;
        ln_list_line_seq             NUMBER;
        ln_attr_group_no_seq         NUMBER;
        ln_dummy                     NUMBER := 0;
        ln_array                     NUMBER := 0;
        lc_start_date                DATE;
        lx_price_list_rec            qp_price_list_pub.price_list_rec_type;
        l_price_list_rec             qp_price_list_pub.price_list_rec_type;
        l_price_list_val_rec         qp_price_list_pub.price_list_val_rec_type;
        lx_price_list_val_rec        qp_price_list_pub.price_list_val_rec_type;
        l_price_list_line_tbl        qp_price_list_pub.price_list_line_tbl_type;
        lx_price_list_line_tbl       qp_price_list_pub.price_list_line_tbl_type;
        lx_price_list_line_val_tbl   qp_price_list_pub.price_list_line_val_tbl_type;
        l_price_list_line_val_tbl    qp_price_list_pub.price_list_line_val_tbl_type;
        lx_qualifiers_tbl            qp_qualifier_rules_pub.qualifiers_tbl_type;
        l_qualifiers_tbl             qp_qualifier_rules_pub.qualifiers_tbl_type;
        lx_qualifiers_val_tbl        qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        l_qualifiers_val_tbl         qp_qualifier_rules_pub.qualifiers_val_tbl_type;
        lx_pricing_attr_tbl          qp_price_list_pub.pricing_attr_tbl_type;
        l_pricing_attr_tbl           qp_price_list_pub.pricing_attr_tbl_type;
        lx_pricing_attr_val_tbl      qp_price_list_pub.pricing_attr_val_tbl_type;
        l_pricing_attr_val_tbl       qp_price_list_pub.pricing_attr_val_tbl_type;
        ln_count                     NUMBER := 0;      -- Added for CCR0010303
    BEGIN
        --- Changes for CCR0010303 Started
        IF (UPPER (p_attribute_name) = ('STYLE-COLOR') AND p_list_line_id IS NOT NULL)
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Style-color level is just applied in ADD mode, not applicable in UPDATE mode. ';

            IF lc_err_message IS NOT NULL
            THEN
                RAISE le_webadi_exception;
            END IF;
        ELSIF (UPPER (p_attribute_name) = ('STYLE-COLOR') AND p_list_line_id IS NULL)
        THEN
            BEGIN
                SELECT COUNT (*)
                  INTO ln_count
                  FROM xxd_common_items_v a
                 WHERE     a.master_org_flag = 'Y'
                       AND a.STYLE_NUMBER = REGEXP_SUBSTR (p_attribute_value, '[^-]+', 1
                                                           , 1)
                       AND a.Color_code = REGEXP_SUBSTR (p_attribute_value, '[^-]+', 1
                                                         , 2);

                IF ln_count = 0
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Unable to derive data for the Style-Color# entered. ';
                END IF;

                IF lc_err_message IS NOT NULL
                THEN
                    RAISE le_webadi_exception;
                END IF;

                IF ln_count != 0
                THEN
                    FOR lcu_i IN get_style_color_data_c
                    LOOP
                        BEGIN
                            ln_dummy   := 0;
                            ln_array   := 0;

                            -- Derive Price List Header ID
                            BEGIN
                                SELECT list_header_id
                                  INTO ln_list_header_id
                                  FROM qp_list_headers_v
                                 WHERE name = lcu_i.p_price_list;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lc_err_message   :=
                                           lc_err_message
                                        || 'Unable to derive List Header ID. ';
                            END;

                            -- Validate Attribute Name
                            IF     lcu_i.p_attribute_name IS NOT NULL
                               AND UPPER (lcu_i.p_attribute_name) NOT IN
                                       ('SKU', 'STYLE', 'STYLE-COLOR')
                               AND lcu_i.p_list_line_id IS NULL
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'Please specify SKU or STYLE or STYLE-COLOR only. ';
                            ELSIF     lcu_i.p_attribute_name IS NULL
                                  AND lcu_i.p_list_line_id IS NULL
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'Please specify SKU or STYLE or STYLE-COLOR for ADD mode. ';
                            END IF;

                            -- Attribute Value is Mandatory for ADD
                            IF     lcu_i.p_list_line_id IS NULL
                               AND lcu_i.p_attribute_name IS NOT NULL
                               AND lcu_i.p_attribute_value IS NULL
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'Please specify SKU# or STYLE# or STYLE-COLOR# for ADD mode. ';
                            END IF;

                            -- Validate Attribute Value
                            IF     lcu_i.p_attribute_name IS NOT NULL
                               AND lcu_i.p_attribute_value IS NOT NULL
                            THEN
                                -- Validate STYLE-COLOR#
                                IF UPPER (lcu_i.p_attribute_name) =
                                   'STYLE-COLOR'
                                THEN
                                    FOR i
                                        IN (  SELECT inventory_item_id, brand, COUNT (DISTINCT item_number) item_count
                                                FROM xxd_common_items_v
                                               WHERE     master_org_flag = 'Y'
                                                     AND item_number =
                                                         lcu_i.adi_attribute_value
                                            GROUP BY inventory_item_id, brand)
                                    LOOP
                                        lc_brand   := i.brand;
                                        ln_dummy   := i.item_count;
                                        ln_inventory_item_id   :=
                                            i.inventory_item_id;
                                        lc_product_attribute   :=
                                            'PRICING_ATTRIBUTE1';
                                    END LOOP;

                                    -- dbms_output.put_line('Inventory_item_id- '||ln_inventory_item_id);
                                    -- dbms_output.put_line('Erro msg - '||lc_err_message);

                                    IF NVL (ln_dummy, 0) = 0
                                    THEN
                                        lc_err_message   :=
                                               lc_err_message
                                            || 'Invalid STYLE-COLOR#. ';
                                    END IF;
                                END IF;
                            END IF;

                            -- Assign Product Attr Value
                            IF lcu_i.p_list_line_id IS NULL
                            THEN
                                SELECT ln_inventory_item_id
                                  INTO lc_product_attr_value
                                  FROM DUAL;
                            END IF;

                            -- Validate UOM Code
                            IF     lcu_i.p_uom_code IS NULL
                               AND lcu_i.p_list_line_id IS NULL
                               AND lc_product_attr_value IS NOT NULL
                            THEN
                                IF UPPER (lcu_i.p_attribute_name) IN
                                       ('SKU', 'STYLE', 'STYLE-COLOR')
                                THEN
                                    OPEN get_uom_for_sty_col_c;

                                    LOOP
                                        FETCH get_uom_for_sty_col_c
                                            INTO lcu_k;

                                        EXIT WHEN get_uom_for_sty_col_c%NOTFOUND;
                                    END LOOP;

                                    IF get_uom_for_sty_col_c%ROWCOUNT = 0
                                    THEN
                                        lc_err_message   :=
                                               lc_err_message
                                            || 'Unable to derive UOM Code for the SKU# Or Style# or Style-Color# entered. ';
                                    ELSIF get_uom_for_sty_col_c%ROWCOUNT > 1
                                    THEN
                                        lc_err_message   :=
                                               lc_err_message
                                            || 'UOM Code is not unique for the SKU# Or Style# Or Style-Color# entered. ';
                                    ELSE
                                        lc_uom_code   :=
                                            lcu_k.primary_uom_code;
                                    END IF;

                                    CLOSE get_uom_for_sty_col_c;
                                END IF;
                            ELSIF     lcu_i.p_uom_code IS NOT NULL
                                  AND lcu_i.p_list_line_id IS NULL
                                  AND lc_product_attr_value IS NOT NULL
                            THEN
                                SELECT COUNT (DISTINCT b.primary_uom_code)
                                  INTO ln_dummy
                                  FROM xxd_common_items_v b
                                 WHERE     b.master_org_flag = 'Y'
                                       AND b.item_number =
                                           lcu_i.adi_attribute_value
                                       AND UPPER (lcu_i.p_attribute_name) =
                                           'STYLE-COLOR'
                                       AND b.primary_uom_code =
                                           lcu_i.p_uom_code;

                                IF ln_dummy = 0
                                THEN
                                    lc_err_message   :=
                                           lc_err_message
                                        || 'Invalid UOM or entered UOM Code is not assigned to the SKU# Or Style# Or Style-Color# entered. ';
                                ELSIF ln_dummy > 1
                                THEN
                                    lc_err_message   :=
                                           lc_err_message
                                        || 'UOM Code is not unique for the SKU# Or Style# Or Style-Color# entered. ';
                                ELSE
                                    lc_uom_code   := lcu_i.p_uom_code;
                                END IF;
                            END IF;

                            -- Validate List Price
                            IF     lcu_i.p_list_price IS NULL
                               AND lcu_i.p_list_line_id IS NULL
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'Please specify List Price for ADD mode. ';
                            ELSIF lcu_i.p_list_price IS NOT NULL
                            THEN
                                IF SIGN (lcu_i.p_list_price) < 0
                                THEN
                                    lc_err_message   :=
                                           lc_err_message
                                        || 'List Price should be a positive number. ';
                                ELSE
                                    BEGIN
                                        SELECT TO_NUMBER (lcu_i.p_list_price, '9999999.99')
                                          INTO ln_dummy
                                          FROM DUAL;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            lc_err_message   :=
                                                   lc_err_message
                                                || 'List Price should have only two decimals. ';
                                    END;
                                END IF;
                            END IF;


                            -- Validate Start Date
                            IF     lcu_i.p_start_date IS NULL
                               AND lcu_i.p_list_line_id IS NULL
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'Please specify Start Date for ADD mode. ';
                            END IF;

                            -- Validate End Date
                            IF     lcu_i.p_start_date IS NOT NULL
                               AND lcu_i.p_end_date IS NOT NULL
                               AND lcu_i.p_end_date < lcu_i.p_start_date
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'End Date should be less or equal to Start Date. ';
                            END IF;


                            -- Validate Brand
                            IF     lcu_i.p_list_line_id IS NULL
                               AND lcu_i.p_brand IS NULL
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'Please specify Brand for ADD mode. ';
                            ELSIF     lcu_i.p_list_line_id IS NULL
                                  AND lcu_i.p_brand IS NOT NULL
                                  AND lcu_i.p_brand <> lc_brand
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'Brand Provided is different from the Brand in SKU# or Style# or Style-Color#. ';
                            END IF;

                            -- Validate Season
                            IF     lcu_i.p_list_line_id IS NULL
                               AND lcu_i.p_season IS NULL
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'Please specify Season for ADD mode. ';
                            END IF;


                            mo_global.init ('QP');
                            oe_msg_pub.initialize;
                            l_price_list_line_tbl.delete;
                            l_pricing_attr_tbl.delete;

                            -- ADD mode
                            IF     lcu_i.p_list_line_id IS NULL
                               AND lc_err_message IS NULL
                            THEN
                                BEGIN
                                    SELECT qsv.user_precedence
                                      INTO ln_precedence
                                      FROM qp_prc_contexts_v qpc, qp_segments_v qsv
                                     WHERE     qsv.prc_context_id =
                                               qpc.prc_context_id
                                           AND prc_context_type = 'PRODUCT'
                                           AND prc_context_code = 'ITEM'
                                           AND segment_code =
                                               'INVENTORY_ITEM_ID';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lc_err_message   :=
                                               lc_err_message
                                            || 'Unable to derive User Preference. ';
                                END;

                                BEGIN
                                    SELECT MAX (qllv.list_line_id)
                                      INTO ln_max_list_line_id
                                      FROM qp_list_headers_v qlhv, qp_list_lines_v qllv
                                     WHERE     qlhv.list_header_id =
                                               qllv.list_header_id
                                           AND product_attribute_context =
                                               'ITEM'
                                           AND product_attr_value =
                                               lc_product_attr_value
                                           AND qllv.product_uom_code =
                                               lc_uom_code
                                           AND qlhv.name = lcu_i.p_price_list;
                                EXCEPTION
                                    -- First Time Entry
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        ln_max_list_line_id   := NULL;
                                    WHEN OTHERS
                                    THEN
                                        lc_err_message   :=
                                               lc_err_message
                                            || SUBSTR (SQLERRM, 1, 2000);
                                END;

                                l_price_list_rec.list_header_id   :=
                                    ln_list_header_id;
                                l_price_list_rec.list_type_code   := 'PRL';
                                l_price_list_rec.operation        :=
                                    qp_globals.g_opr_update;

                                -- End Date the Previous MAX Line
                                IF ln_max_list_line_id IS NOT NULL
                                THEN
                                    ln_array   := ln_array + 1;
                                    l_price_list_line_tbl (ln_array).list_header_id   :=
                                        ln_list_header_id;
                                    l_price_list_line_tbl (ln_array).list_line_id   :=
                                        ln_max_list_line_id;
                                    l_price_list_line_tbl (ln_array).operation   :=
                                        qp_globals.g_opr_update;
                                    l_price_list_line_tbl (ln_array).end_date_active   :=
                                        lcu_i.p_start_date - 1;
                                    l_pricing_attr_tbl (ln_array).product_uom_code   :=
                                        lc_uom_code;
                                END IF;

                                -- Create a New Line
                                SELECT qp_list_lines_s.NEXTVAL
                                  INTO ln_list_line_seq
                                  FROM DUAL;

                                SELECT NVL2 (ln_max_list_line_id, lcu_i.p_start_date, NULL)
                                  INTO lc_start_date
                                  FROM DUAL;

                                ln_array                          :=
                                    ln_array + 1;

                                l_price_list_line_tbl (ln_array).list_header_id   :=
                                    ln_list_header_id;
                                l_price_list_line_tbl (ln_array).list_line_id   :=
                                    ln_list_line_seq;
                                l_price_list_line_tbl (ln_array).list_line_type_code   :=
                                    'PLL';
                                l_price_list_line_tbl (ln_array).operation   :=
                                    qp_globals.g_opr_create;
                                l_price_list_line_tbl (ln_array).operand   :=
                                    lcu_i.p_list_price;
                                l_price_list_line_tbl (ln_array).product_precedence   :=
                                    ln_precedence;
                                l_price_list_line_tbl (ln_array).attribute1   :=
                                    lcu_i.p_brand;
                                l_price_list_line_tbl (ln_array).attribute2   :=
                                    lcu_i.p_season;
                                l_price_list_line_tbl (ln_array).attribute3   :=
                                    lcu_i.p_mdm_notes;
                                l_price_list_line_tbl (ln_array).arithmetic_operator   :=
                                    'UNIT_PRICE';
                                l_price_list_line_tbl (ln_array).start_date_active   :=
                                    lc_start_date;
                                l_price_list_line_tbl (ln_array).end_date_active   :=
                                    NULL;

                                SELECT qp_pricing_attr_group_no_s.NEXTVAL
                                  INTO ln_attr_group_no_seq
                                  FROM DUAL;

                                l_pricing_attr_tbl (ln_array).operation   :=
                                    qp_globals.g_opr_create;
                                l_pricing_attr_tbl (ln_array).list_line_id   :=
                                    ln_list_line_seq;
                                l_pricing_attr_tbl (ln_array).product_attribute_context   :=
                                    'ITEM';
                                l_pricing_attr_tbl (ln_array).product_attribute   :=
                                    lc_product_attribute;
                                l_pricing_attr_tbl (ln_array).product_attribute_datatype   :=
                                    'C';
                                l_pricing_attr_tbl (ln_array).product_attr_value   :=
                                    lc_product_attr_value;
                                l_pricing_attr_tbl (ln_array).product_uom_code   :=
                                    lc_uom_code;
                                l_pricing_attr_tbl (ln_array).excluder_flag   :=
                                    'N';
                                l_pricing_attr_tbl (ln_array).attribute_grouping_no   :=
                                    ln_attr_group_no_seq;


                                qp_price_list_pub.process_price_list (
                                    p_api_version_number   => 1.0,
                                    p_init_msg_list        => fnd_api.g_false,
                                    p_return_values        => fnd_api.g_false,
                                    p_commit               => fnd_api.g_false,
                                    x_return_status        => lc_return_status,
                                    x_msg_count            => ln_msg_count,
                                    x_msg_data             => lc_msg_data,
                                    p_price_list_rec       => l_price_list_rec,
                                    p_price_list_val_rec   =>
                                        l_price_list_val_rec,
                                    p_price_list_line_tbl   =>
                                        l_price_list_line_tbl,
                                    p_price_list_line_val_tbl   =>
                                        l_price_list_line_val_tbl,
                                    p_qualifiers_tbl       => l_qualifiers_tbl,
                                    p_qualifiers_val_tbl   =>
                                        l_qualifiers_val_tbl,
                                    p_pricing_attr_tbl     =>
                                        l_pricing_attr_tbl,
                                    p_pricing_attr_val_tbl   =>
                                        l_pricing_attr_val_tbl,
                                    x_price_list_rec       =>
                                        lx_price_list_rec,
                                    x_price_list_val_rec   =>
                                        lx_price_list_val_rec,
                                    x_price_list_line_tbl   =>
                                        lx_price_list_line_tbl,
                                    x_price_list_line_val_tbl   =>
                                        lx_price_list_line_val_tbl,
                                    x_qualifiers_tbl       =>
                                        lx_qualifiers_tbl,
                                    x_qualifiers_val_tbl   =>
                                        lx_qualifiers_val_tbl,
                                    x_pricing_attr_tbl     =>
                                        lx_pricing_attr_tbl,
                                    x_pricing_attr_val_tbl   =>
                                        lx_pricing_attr_val_tbl);

                                IF (lc_return_status <> fnd_api.g_ret_sts_success)
                                THEN
                                    FOR i IN 1 .. ln_msg_count
                                    LOOP
                                        lc_msg_data   :=
                                            oe_msg_pub.get (
                                                p_msg_index   =>
                                                    oe_msg_pub.g_next,
                                                p_encoded   => fnd_api.g_false);
                                        lc_err_message   :=
                                               lc_err_message
                                            || SUBSTR (lc_msg_data, 1, 2000);
                                    END LOOP;
                                END IF;
                            END IF;

                            -- Insert into Custom Table
                            IF lc_err_message IS NOT NULL
                            THEN
                                RAISE le_webadi_exception;
                            ELSE
                                INSERT INTO xxd_qp_price_list_upload_t (
                                                list_header_id,
                                                price_list_name,
                                                upload_mode,
                                                product_attribute_context,
                                                product_attribute,
                                                product_attr_value,
                                                product_attr_value_disp,
                                                product_uom_code,
                                                list_price,
                                                start_date_active,
                                                end_date_active,
                                                list_line_id,
                                                brand,
                                                season,
                                                mdm_notes,
                                                record_status,
                                                error_message,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by,
                                                last_update_login,
                                                request_id)
                                     VALUES (ln_list_header_id, lcu_i.p_price_list, NVL2 (lcu_i.p_list_line_id, 'UPDATE', 'ADD'), 'ITEM', lc_product_attribute, lc_product_attr_value, NVL (lcu_i.adi_attribute_value, lc_product_attr_val_disp), lc_uom_code, lcu_i.p_list_price, lcu_i.p_start_date, lcu_i.p_end_date, lcu_i.p_list_line_id, lcu_i.p_brand, lcu_i.p_season, lcu_i.p_mdm_notes, NVL (lc_return_status, 'S'), lc_err_message, SYSDATE, fnd_global.user_id, SYSDATE, fnd_global.user_id
                                             , -1, -1);
                            END IF;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                lc_err_message   :=
                                       lc_err_message
                                    || 'Unable to derive data for the Style-Color# entered. ';
                        END;
                    END LOOP;

                    IF lc_err_message IS NOT NULL
                    THEN
                        RAISE le_webadi_exception;
                    END IF;
                END IF;
            END;
        ELSE
            --- Changes for CCR0010303 Ends

            -------------------------------------------------------------------------------------------------
            -- Derive Price List Header ID
            BEGIN
                SELECT list_header_id
                  INTO ln_list_header_id
                  FROM qp_list_headers_v
                 WHERE name = p_price_list;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Unable to derive List Header ID. ';
            END;

            -- Validate Attribute Name
            IF     p_attribute_name IS NOT NULL
               AND UPPER (p_attribute_name) NOT IN ('SKU', 'STYLE')
               AND p_list_line_id IS NULL
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Please specify SKU or STYLE or STYLE-COLOR only. '; --Updated for CCR0010303
            ELSIF p_attribute_name IS NULL AND p_list_line_id IS NULL
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Please specify SKU or STYLE or STYLE-COLOR for ADD mode. '; --Updated for CCR0010303
            END IF;

            -- Attribute Value is Mandatory for ADD
            IF     p_list_line_id IS NULL
               AND p_attribute_name IS NOT NULL
               AND p_attribute_value IS NULL
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Please specify SKU# or STYLE# or STYLE-COLOR# for ADD mode. '; --Updated for CCR0010303
            END IF;

            -- Validate Attribute Value
            IF p_attribute_name IS NOT NULL AND p_attribute_value IS NOT NULL
            THEN
                -- Validate SKU#
                IF UPPER (p_attribute_name) = 'SKU'
                THEN
                    FOR i
                        IN (  SELECT inventory_item_id, brand, COUNT (DISTINCT item_number) item_count
                                FROM xxd_common_items_v
                               WHERE     master_org_flag = 'Y'
                                     AND item_number = p_attribute_value
                            GROUP BY inventory_item_id, brand)
                    LOOP
                        lc_brand               := i.brand;
                        ln_dummy               := i.item_count;
                        ln_inventory_item_id   := i.inventory_item_id;
                        lc_product_attribute   := 'PRICING_ATTRIBUTE1';
                    END LOOP;

                    IF NVL (ln_dummy, 0) = 0
                    THEN
                        lc_err_message   :=
                            lc_err_message || 'Invalid SKU#. ';
                    END IF;

                    ln_dummy   := 0;
                -- Validate Style#
                ELSIF UPPER (p_attribute_name) = 'STYLE'
                THEN
                    FOR i
                        IN (  SELECT brand, COUNT (DISTINCT style_number) style_count
                                FROM xxd_common_items_v
                               WHERE     master_org_flag = 'Y'
                                     AND style_number = p_attribute_value
                            GROUP BY brand)
                    LOOP
                        lc_brand               := i.brand;
                        ln_dummy               := i.style_count;
                        lc_product_attribute   := 'PRICING_ATTRIBUTE2';
                    END LOOP;

                    IF NVL (ln_dummy, 0) = 0
                    THEN
                        lc_err_message   :=
                            lc_err_message || 'Invalid Style#. ';
                    -- Validate PriceList Item Category
                    ELSE
                        OPEN get_category_c;

                        LOOP
                            FETCH get_category_c INTO lcu_category;

                            EXIT WHEN get_category_c%NOTFOUND;
                        END LOOP;

                        IF get_category_c%ROWCOUNT = 0
                        THEN
                            lc_err_message   :=
                                   lc_err_message
                                || 'Unable to derive PriceList Item Category for the Style# entered. ';
                        ELSIF get_category_c%ROWCOUNT > 1
                        THEN
                            lc_err_message   :=
                                   lc_err_message
                                || 'More than one PriceList Item Category found for the Style# entered. ';
                        ELSE
                            ln_category_id   := lcu_category.category_id;
                        END IF;

                        CLOSE get_category_c;
                    END IF;
                END IF;
            END IF;

            -- Assign Product Attr Value
            IF p_list_line_id IS NULL
            THEN
                SELECT NVL2 (ln_inventory_item_id, ln_inventory_item_id, ln_category_id)
                  INTO lc_product_attr_value
                  FROM DUAL;
            END IF;

            -- Validate UOM Code
            IF     p_uom_code IS NULL
               AND p_list_line_id IS NULL
               AND lc_product_attr_value IS NOT NULL
            THEN
                IF UPPER (p_attribute_name) IN ('SKU', 'STYLE')
                THEN
                    OPEN get_uom_code;

                    LOOP
                        FETCH get_uom_code INTO lcu_uom_code;

                        EXIT WHEN get_uom_code%NOTFOUND;
                    END LOOP;

                    IF get_uom_code%ROWCOUNT = 0
                    THEN
                        lc_err_message   :=
                               lc_err_message
                            || 'Unable to derive UOM Code for the SKU Or Style# Or Style-Color# entered. '; --Updated for CCR0010303
                    ELSIF get_uom_code%ROWCOUNT > 1
                    THEN
                        lc_err_message   :=
                               lc_err_message
                            || 'UOM Code is not unique for the SKU Or Style# Or Style-Color# entered. '; --Updated for CCR0010303
                    ELSE
                        lc_uom_code   := lcu_uom_code.primary_uom_code;
                    END IF;

                    CLOSE get_uom_code;
                END IF;
            ELSIF     p_uom_code IS NOT NULL
                  AND p_list_line_id IS NULL
                  AND lc_product_attr_value IS NOT NULL
            THEN
                SELECT COUNT (DISTINCT primary_uom_code)
                  INTO ln_dummy
                  FROM xxd_common_items_v
                 WHERE     master_org_flag = 'Y'
                       AND ((item_number = p_attribute_value AND UPPER (p_attribute_name) = 'SKU') OR (style_number = p_attribute_value AND UPPER (p_attribute_name) = 'STYLE'))
                       AND primary_uom_code = p_uom_code;

                IF ln_dummy = 0
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Invalid UOM or entered UOM Code is not assigned to the SKU# Or Style# Or Style-Color# entered. '; --Updated for CCR0010303
                ELSIF ln_dummy > 1
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'UOM Code is not unique for the SKU# Or Style# Or Style-Color# entered. '; --Updated for CCR0010303
                ELSE
                    lc_uom_code   := p_uom_code;
                END IF;
            ELSIF p_uom_code IS NOT NULL AND p_list_line_id IS NOT NULL
            THEN
                SELECT COUNT (DISTINCT primary_uom_code)
                  INTO ln_dummy
                  FROM xxd_common_items_v xciv, qp_list_lines_v qllv
                 WHERE     master_org_flag = 'Y'
                       AND ((qllv.product_attribute = 'PRICING_ATTRIBUTE1' AND TO_CHAR (xciv.inventory_item_id) = qllv.product_attr_value) OR (qllv.product_attribute = 'PRICING_ATTRIBUTE2' AND xciv.style_desc = qllv.product_attr_val_disp))
                       AND xciv.primary_uom_code = p_uom_code
                       AND qllv.list_line_id = p_list_line_id;

                IF ln_dummy = 0
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Invalid UOM or entered UOM Code is not assigned to the SKU# Or Style# Or Style-Color# entered. '; --Updated for CCR0010303
                ELSIF ln_dummy > 1
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'UOM Code is not unique for the SKU# Or Style# Or Style-Color# entered. '; --Updated for CCR0010303
                END IF;
            END IF;

            -- Validate List Price
            IF p_list_price IS NULL AND p_list_line_id IS NULL
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Please specify List Price for ADD mode. ';
            ELSIF p_list_price IS NOT NULL
            THEN
                IF SIGN (p_list_price) < 0
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'List Price should be a positive number. ';
                ELSE
                    BEGIN
                        SELECT TO_NUMBER (p_list_price, '9999999.99')
                          INTO ln_dummy
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_err_message   :=
                                   lc_err_message
                                || 'List Price should have only two decimals. ';
                    END;
                END IF;
            END IF;

            -- Validate Start Date
            IF p_start_date IS NULL AND p_list_line_id IS NULL
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Please specify Start Date for ADD mode. ';
            END IF;

            -- Validate End Date
            IF     p_start_date IS NOT NULL
               AND p_end_date IS NOT NULL
               AND p_end_date < p_start_date
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'End Date should be less or equal to Start Date. ';
            END IF;

            -- Validate List Line ID
            IF p_list_line_id IS NOT NULL
            THEN
                BEGIN
                    SELECT qllv.product_attribute,
                           qllv.product_attr_value,
                           qllv.product_attr_val_disp,
                           CASE
                               WHEN     p_mdm_notes IS NOT NULL
                                    AND qllv.attribute3 IS NOT NULL
                               THEN
                                   qllv.attribute3 || '.' || p_mdm_notes
                               WHEN     p_mdm_notes IS NOT NULL
                                    AND qllv.attribute3 IS NULL
                               THEN
                                   p_mdm_notes
                           END,
                           qllv.product_uom_code,
                           qllv.pricing_attribute_id
                      INTO lc_product_attribute, lc_product_attr_value, lc_product_attr_val_disp, lc_current_mdm_notes,
                                               lc_uom_code, ln_pricing_attribute_id
                      FROM qp_list_lines_v qllv
                     WHERE     qllv.list_line_id = p_list_line_id
                           AND qllv.list_header_id = ln_list_header_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_err_message   :=
                            lc_err_message || 'Invalid List Line ID. ';
                END;
            END IF;

            -- Validate Brand
            IF p_list_line_id IS NULL AND p_brand IS NULL
            THEN
                lc_err_message   :=
                    lc_err_message || 'Please specify Brand for ADD mode. ';
            ELSIF     p_list_line_id IS NULL
                  AND p_brand IS NOT NULL
                  AND p_brand <> lc_brand
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Brand Provided is different from the Brand in SKU# or Style# Or Style-Color#. '; --Updated for CCR0010303
            END IF;

            -- Validate Season
            IF p_list_line_id IS NULL AND p_season IS NULL
            THEN
                lc_err_message   :=
                    lc_err_message || 'Please specify Season for ADD mode. ';
            END IF;

            -- Validate Data Combination for UPDATE mode
            IF     p_list_line_id IS NOT NULL
               AND (p_uom_code IS NULL AND p_list_price IS NULL AND p_start_date IS NULL AND p_end_date IS NULL)
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'For UPDATE mode, either UOM, Price, Start Date or End Date should entered. ';
            END IF;

            mo_global.init ('QP');
            oe_msg_pub.initialize;
            l_price_list_line_tbl.delete;
            l_pricing_attr_tbl.delete;

            -- ADD mode
            IF p_list_line_id IS NULL AND lc_err_message IS NULL
            THEN
                BEGIN
                    SELECT qsv.user_precedence
                      INTO ln_precedence
                      FROM qp_prc_contexts_v qpc, qp_segments_v qsv
                     WHERE     qsv.prc_context_id = qpc.prc_context_id
                           AND prc_context_type = 'PRODUCT'
                           AND prc_context_code = 'ITEM'
                           AND segment_code =
                               DECODE (UPPER (p_attribute_name),
                                       'SKU', 'INVENTORY_ITEM_ID',
                                       'ITEM_CATEGORY');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_err_message   :=
                               lc_err_message
                            || 'Unable to derive User Preference. ';
                END;

                BEGIN
                    SELECT MAX (qllv.list_line_id)
                      INTO ln_max_list_line_id
                      FROM qp_list_headers_v qlhv, qp_list_lines_v qllv
                     WHERE     qlhv.list_header_id = qllv.list_header_id
                           AND product_attribute_context = 'ITEM'
                           AND product_attr_value = lc_product_attr_value
                           AND qllv.product_uom_code = lc_uom_code
                           AND qlhv.name = p_price_list;
                EXCEPTION
                    -- First Time Entry
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_max_list_line_id   := NULL;
                    WHEN OTHERS
                    THEN
                        lc_err_message   :=
                            lc_err_message || SUBSTR (SQLERRM, 1, 2000);
                END;

                l_price_list_rec.list_header_id   := ln_list_header_id;
                l_price_list_rec.list_type_code   := 'PRL';
                l_price_list_rec.operation        := qp_globals.g_opr_update;

                -- End Date the Previous MAX Line
                IF ln_max_list_line_id IS NOT NULL
                THEN
                    ln_array   := ln_array + 1;
                    l_price_list_line_tbl (ln_array).list_header_id   :=
                        ln_list_header_id;
                    l_price_list_line_tbl (ln_array).list_line_id   :=
                        ln_max_list_line_id;
                    l_price_list_line_tbl (ln_array).operation   :=
                        qp_globals.g_opr_update;
                    l_price_list_line_tbl (ln_array).end_date_active   :=
                        p_start_date - 1;
                    l_pricing_attr_tbl (ln_array).product_uom_code   :=
                        lc_uom_code;
                END IF;

                -- Create a New Line
                SELECT qp_list_lines_s.NEXTVAL
                  INTO ln_list_line_seq
                  FROM DUAL;

                SELECT NVL2 (ln_max_list_line_id, p_start_date, NULL)
                  INTO lc_start_date
                  FROM DUAL;

                ln_array                          := ln_array + 1;

                l_price_list_line_tbl (ln_array).list_header_id   :=
                    ln_list_header_id;
                l_price_list_line_tbl (ln_array).list_line_id   :=
                    ln_list_line_seq;
                l_price_list_line_tbl (ln_array).list_line_type_code   :=
                    'PLL';
                l_price_list_line_tbl (ln_array).operation   :=
                    qp_globals.g_opr_create;
                l_price_list_line_tbl (ln_array).operand   :=
                    p_list_price;
                l_price_list_line_tbl (ln_array).product_precedence   :=
                    ln_precedence;
                l_price_list_line_tbl (ln_array).attribute1   :=
                    p_brand;
                l_price_list_line_tbl (ln_array).attribute2   :=
                    p_season;
                l_price_list_line_tbl (ln_array).attribute3   :=
                    p_mdm_notes;
                l_price_list_line_tbl (ln_array).arithmetic_operator   :=
                    'UNIT_PRICE';
                l_price_list_line_tbl (ln_array).start_date_active   :=
                    lc_start_date;
                l_price_list_line_tbl (ln_array).end_date_active   :=
                    NULL;

                SELECT qp_pricing_attr_group_no_s.NEXTVAL
                  INTO ln_attr_group_no_seq
                  FROM DUAL;

                l_pricing_attr_tbl (ln_array).operation   :=
                    qp_globals.g_opr_create;
                l_pricing_attr_tbl (ln_array).list_line_id   :=
                    ln_list_line_seq;
                l_pricing_attr_tbl (ln_array).product_attribute_context   :=
                    'ITEM';
                l_pricing_attr_tbl (ln_array).product_attribute   :=
                    lc_product_attribute;
                l_pricing_attr_tbl (ln_array).product_attribute_datatype   :=
                    'C';
                l_pricing_attr_tbl (ln_array).product_attr_value   :=
                    lc_product_attr_value;
                l_pricing_attr_tbl (ln_array).product_uom_code   :=
                    lc_uom_code;
                l_pricing_attr_tbl (ln_array).excluder_flag   :=
                    'N';
                l_pricing_attr_tbl (ln_array).attribute_grouping_no   :=
                    ln_attr_group_no_seq;

                qp_price_list_pub.process_price_list (
                    p_api_version_number        => 1.0,
                    p_init_msg_list             => fnd_api.g_false,
                    p_return_values             => fnd_api.g_false,
                    p_commit                    => fnd_api.g_false,
                    x_return_status             => lc_return_status,
                    x_msg_count                 => ln_msg_count,
                    x_msg_data                  => lc_msg_data,
                    p_price_list_rec            => l_price_list_rec,
                    p_price_list_val_rec        => l_price_list_val_rec,
                    p_price_list_line_tbl       => l_price_list_line_tbl,
                    p_price_list_line_val_tbl   => l_price_list_line_val_tbl,
                    p_qualifiers_tbl            => l_qualifiers_tbl,
                    p_qualifiers_val_tbl        => l_qualifiers_val_tbl,
                    p_pricing_attr_tbl          => l_pricing_attr_tbl,
                    p_pricing_attr_val_tbl      => l_pricing_attr_val_tbl,
                    x_price_list_rec            => lx_price_list_rec,
                    x_price_list_val_rec        => lx_price_list_val_rec,
                    x_price_list_line_tbl       => lx_price_list_line_tbl,
                    x_price_list_line_val_tbl   => lx_price_list_line_val_tbl,
                    x_qualifiers_tbl            => lx_qualifiers_tbl,
                    x_qualifiers_val_tbl        => lx_qualifiers_val_tbl,
                    x_pricing_attr_tbl          => lx_pricing_attr_tbl,
                    x_pricing_attr_val_tbl      => lx_pricing_attr_val_tbl);

                IF (lc_return_status <> fnd_api.g_ret_sts_success)
                THEN
                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        lc_msg_data   :=
                            oe_msg_pub.get (
                                p_msg_index   => oe_msg_pub.g_next,
                                p_encoded     => fnd_api.g_false);
                        lc_err_message   :=
                            lc_err_message || SUBSTR (lc_msg_data, 1, 2000);
                    END LOOP;
                END IF;
            -- UPDATE mode
            ELSIF p_list_line_id IS NOT NULL AND lc_err_message IS NULL
            THEN
                ln_array                          := ln_array + 1;
                l_price_list_rec.list_header_id   := ln_list_header_id;
                l_price_list_rec.list_type_code   := 'PRL';
                l_price_list_rec.operation        := qp_globals.g_opr_update;
                l_price_list_line_tbl (ln_array).list_header_id   :=
                    ln_list_header_id;
                l_price_list_line_tbl (ln_array).list_line_id   :=
                    p_list_line_id;
                l_price_list_line_tbl (ln_array).operation   :=
                    qp_globals.g_opr_update;
                l_price_list_line_tbl (ln_array).operand   :=
                    NVL (p_list_price, fnd_api.g_miss_num);
                l_price_list_line_tbl (ln_array).start_date_active   :=
                    NVL (p_start_date, fnd_api.g_miss_date);
                l_price_list_line_tbl (ln_array).end_date_active   :=
                    NVL (p_end_date, fnd_api.g_miss_date);
                l_price_list_line_tbl (ln_array).attribute3   :=
                    NVL (lc_current_mdm_notes, fnd_api.g_miss_char);
                l_pricing_attr_tbl (ln_array).operation   :=
                    qp_globals.g_opr_update;
                l_pricing_attr_tbl (ln_array).pricing_attribute_id   :=
                    ln_pricing_attribute_id;
                l_pricing_attr_tbl (ln_array).product_uom_code   :=
                    NVL (lc_uom_code, fnd_api.g_miss_char);

                qp_price_list_pub.process_price_list (
                    p_api_version_number        => 1.0,
                    p_init_msg_list             => fnd_api.g_false,
                    p_return_values             => fnd_api.g_false,
                    p_commit                    => fnd_api.g_false,
                    x_return_status             => lc_return_status,
                    x_msg_count                 => ln_msg_count,
                    x_msg_data                  => lc_msg_data,
                    p_price_list_rec            => l_price_list_rec,
                    p_price_list_val_rec        => l_price_list_val_rec,
                    p_price_list_line_tbl       => l_price_list_line_tbl,
                    p_price_list_line_val_tbl   => l_price_list_line_val_tbl,
                    p_qualifiers_tbl            => l_qualifiers_tbl,
                    p_qualifiers_val_tbl        => l_qualifiers_val_tbl,
                    p_pricing_attr_tbl          => l_pricing_attr_tbl,
                    p_pricing_attr_val_tbl      => l_pricing_attr_val_tbl,
                    x_price_list_rec            => lx_price_list_rec,
                    x_price_list_val_rec        => lx_price_list_val_rec,
                    x_price_list_line_tbl       => lx_price_list_line_tbl,
                    x_price_list_line_val_tbl   => lx_price_list_line_val_tbl,
                    x_qualifiers_tbl            => lx_qualifiers_tbl,
                    x_qualifiers_val_tbl        => lx_qualifiers_val_tbl,
                    x_pricing_attr_tbl          => lx_pricing_attr_tbl,
                    x_pricing_attr_val_tbl      => lx_pricing_attr_val_tbl);

                IF (lc_return_status <> fnd_api.g_ret_sts_success)
                THEN
                    FOR i IN 1 .. ln_msg_count
                    LOOP
                        lc_msg_data   :=
                            oe_msg_pub.get (
                                p_msg_index   => oe_msg_pub.g_next,
                                p_encoded     => fnd_api.g_false);
                        lc_err_message   :=
                            lc_err_message || SUBSTR (lc_msg_data, 1, 2000);
                    END LOOP;
                END IF;
            END IF;

            -- Insert into Custom Table
            IF lc_err_message IS NOT NULL
            THEN
                RAISE le_webadi_exception;
            ELSE
                INSERT INTO xxd_qp_price_list_upload_t (
                                list_header_id,
                                price_list_name,
                                upload_mode,
                                product_attribute_context,
                                product_attribute,
                                product_attr_value,
                                product_attr_value_disp,
                                product_uom_code,
                                list_price,
                                start_date_active,
                                end_date_active,
                                list_line_id,
                                brand,
                                season,
                                mdm_notes,
                                record_status,
                                error_message,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by,
                                last_update_login,
                                request_id)
                     VALUES (ln_list_header_id, p_price_list, NVL2 (p_list_line_id, 'UPDATE', 'ADD'), 'ITEM', lc_product_attribute, lc_product_attr_value, NVL (p_attribute_value, lc_product_attr_val_disp), lc_uom_code, p_list_price, p_start_date, p_end_date, p_list_line_id, p_brand, p_season, p_mdm_notes, NVL (lc_return_status, 'S'), lc_err_message, SYSDATE, fnd_global.user_id, SYSDATE, fnd_global.user_id
                             , -1, -1);
            END IF;
        END IF;                                         --Added for CCR0010303
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lc_err_message);
            lc_err_message   := fnd_message.get ();
            raise_application_error (-20000, lc_err_message);
        WHEN OTHERS
        THEN
            lc_err_message   := SQLERRM;
            raise_application_error (-20001, lc_err_message);
    END validate_prc;
END xxd_qp_price_list_upload_pkg;
/
