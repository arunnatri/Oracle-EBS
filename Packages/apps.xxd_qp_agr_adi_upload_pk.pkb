--
-- XXD_QP_AGR_ADI_UPLOAD_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_QP_AGR_ADI_UPLOAD_PK"
AS
    /****************************************************************************************
    * Package      : XXD_QP_AGR_ADI_UPLOAD_PK
    * Design       : This package is used for Pricing Agreement WebADI upload
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 07-Jun-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE agr_upload_prc (p_agreement_name IN oe_agreements_vl.name%TYPE, p_inventory_item IN mtl_system_items_b.segment1%TYPE, p_uom_code IN qp_list_lines_v.product_uom_code%TYPE, p_list_price IN qp_list_lines_v.list_price%TYPE, p_start_date IN qp_list_lines_v.start_date_active%TYPE, p_end_date IN qp_list_lines_v.end_date_active%TYPE
                              , p_list_line_id IN qp_list_lines_v.list_line_id%TYPE, p_mdm_notes IN qp_list_lines_v.attribute3%TYPE)
    AS
        CURSOR get_uom_code IS
            SELECT DISTINCT primary_uom_code
              FROM xxd_common_items_v
             WHERE master_org_flag = 'Y' AND item_number = p_inventory_item;

        le_webadi_exception          EXCEPTION;
        ln_list_header_id            qp_list_headers_v.list_header_id%TYPE;
        lc_cust_brand                hz_cust_accounts.attribute1%TYPE;
        ln_inventory_item_id         xxd_common_items_v.inventory_item_id%TYPE;
        lc_item_brand                xxd_common_items_v.brand%TYPE;
        lc_product_attribute         qp_list_lines_v.product_attribute%TYPE;
        lc_uom_code                  qp_list_lines_v.product_uom_code%TYPE;
        lc_product_attr_value        qp_list_lines_v.product_attr_value%TYPE;
        lc_product_attr_val_disp     qp_list_lines_v.product_attr_val_disp%TYPE;
        lc_current_mdm_notes         qp_list_lines_v.attribute3%TYPE;
        ln_pricing_attribute_id      qp_list_lines_v.pricing_attribute_id%TYPE;
        lcu_uom_code                 get_uom_code%ROWTYPE;
        lc_return_status             VARCHAR2 (4000);
        lc_msg_data                  VARCHAR2 (4000);
        lc_err_message               VARCHAR2 (4000);
        ln_msg_count                 NUMBER;
        ln_list_line_seq             NUMBER;
        ln_attr_group_no_seq         NUMBER;
        ln_dummy                     NUMBER := 0;
        ln_array                     NUMBER := 0;
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
    BEGIN
        -- Derive List Header ID
        BEGIN
            SELECT oav.price_list_id, hca.attribute1
              INTO ln_list_header_id, lc_cust_brand
              FROM oe_agreements_vl oav, hz_cust_accounts hca
             WHERE     oav.sold_to_org_id = hca.cust_account_id
                   AND oav.name = p_agreement_name;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_err_message   :=
                    lc_err_message || 'Unable to derive List Header ID. ';
            WHEN OTHERS
            THEN
                lc_err_message   := lc_err_message || SQLERRM;
        END;

        -- SKU is Mandatory for ADD
        IF p_list_line_id IS NULL AND p_inventory_item IS NULL
        THEN
            lc_err_message   :=
                lc_err_message || 'Please specify SKU# for ADD mode. ';
        END IF;

        -- Validate SKU#
        IF p_inventory_item IS NOT NULL
        THEN
            BEGIN
                SELECT inventory_item_id, brand
                  INTO ln_inventory_item_id, lc_item_brand
                  FROM xxd_common_items_v
                 WHERE     master_org_flag = 'Y'
                       AND item_number = p_inventory_item;

                lc_product_attribute    := 'PRICING_ATTRIBUTE1';
                lc_product_attr_value   := ln_inventory_item_id;

                IF lc_item_brand <> lc_cust_brand
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Customer/SKU Brand does not match. ';
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   := lc_err_message || 'Invalid SKU#. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate UOM Code
        IF     p_uom_code IS NULL
           AND p_list_line_id IS NULL
           AND p_inventory_item IS NOT NULL
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
                    || 'Unable to derive UOM Code for the SKU entered. ';
            ELSIF get_uom_code%ROWCOUNT > 1
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'UOM Code is not unique for the SKU entered. ';
            ELSE
                lc_uom_code   := lcu_uom_code.primary_uom_code;
            END IF;

            CLOSE get_uom_code;
        ELSIF     p_uom_code IS NOT NULL
              AND p_list_line_id IS NULL
              AND p_inventory_item IS NOT NULL
        THEN
            SELECT COUNT (DISTINCT primary_uom_code)
              INTO ln_dummy
              FROM xxd_common_items_v
             WHERE     master_org_flag = 'Y'
                   AND item_number = p_inventory_item
                   AND primary_uom_code = p_uom_code;

            IF ln_dummy = 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Invalid UOM or entered UOM Code is not assigned to the SKU entered. ';
            ELSIF ln_dummy > 1
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'UOM Code is not unique for the SKU entered. ';
            ELSE
                lc_uom_code   := p_uom_code;
            END IF;
        ELSIF p_uom_code IS NOT NULL AND p_list_line_id IS NOT NULL
        THEN
            SELECT COUNT (DISTINCT primary_uom_code)
              INTO ln_dummy
              FROM xxd_common_items_v xciv, qp_list_lines_v qllv
             WHERE     master_org_flag = 'Y'
                   AND qllv.product_attribute = 'PRICING_ATTRIBUTE1'
                   AND TO_CHAR (xciv.inventory_item_id) =
                       qllv.product_attr_value
                   AND xciv.primary_uom_code = p_uom_code
                   AND qllv.list_line_id = p_list_line_id;

            IF ln_dummy = 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Invalid UOM or entered UOM Code is not assigned to the SKU entered. ';
            ELSIF ln_dummy > 1
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'UOM Code is not unique for the SKU entered. ';
            END IF;
        END IF;

        -- Validate List Price
        IF p_list_price IS NULL AND p_list_line_id IS NULL
        THEN
            lc_err_message   :=
                lc_err_message || 'Please specify List Price for ADD mode. ';
        ELSIF p_list_price IS NOT NULL
        THEN
            IF p_list_price = 0
            THEN
                lc_err_message   :=
                    lc_err_message || 'List Price cannot be zero. ';
            ELSIF SIGN (p_list_price) < 0
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
                lc_err_message || 'Please specify Start Date for ADD mode. ';
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
            -- Create a New Line
            SELECT qp_list_lines_s.NEXTVAL INTO ln_list_line_seq FROM DUAL;

            ln_array                                                   := ln_array + 1;

            l_price_list_rec.list_header_id                            := ln_list_header_id;
            l_price_list_rec.list_type_code                            := 'AGR';
            l_price_list_rec.operation                                 := qp_globals.g_opr_update;

            l_price_list_line_tbl (ln_array).list_header_id            :=
                ln_list_header_id;
            l_price_list_line_tbl (ln_array).list_line_id              :=
                ln_list_line_seq;
            l_price_list_line_tbl (ln_array).list_line_type_code       := 'PLL';
            l_price_list_line_tbl (ln_array).operation                 :=
                qp_globals.g_opr_create;
            l_price_list_line_tbl (ln_array).operand                   :=
                p_list_price;
            l_price_list_line_tbl (ln_array).attribute3                :=
                p_mdm_notes;
            l_price_list_line_tbl (ln_array).arithmetic_operator       :=
                'UNIT_PRICE';
            l_price_list_line_tbl (ln_array).start_date_active         :=
                p_start_date;
            l_price_list_line_tbl (ln_array).end_date_active           :=
                p_end_date;

            SELECT qp_pricing_attr_group_no_s.NEXTVAL
              INTO ln_attr_group_no_seq
              FROM DUAL;

            l_pricing_attr_tbl (ln_array).operation                    :=
                qp_globals.g_opr_create;
            l_pricing_attr_tbl (ln_array).list_line_id                 :=
                ln_list_line_seq;
            l_pricing_attr_tbl (ln_array).product_attribute_context    :=
                'ITEM';
            l_pricing_attr_tbl (ln_array).product_attribute            :=
                lc_product_attribute;
            l_pricing_attr_tbl (ln_array).product_attribute_datatype   := 'C';
            l_pricing_attr_tbl (ln_array).product_attr_value           :=
                lc_product_attr_value;
            l_pricing_attr_tbl (ln_array).product_uom_code             :=
                lc_uom_code;
            l_pricing_attr_tbl (ln_array).excluder_flag                := 'N';
            l_pricing_attr_tbl (ln_array).attribute_grouping_no        :=
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
                        oe_msg_pub.get (p_msg_index   => oe_msg_pub.g_next,
                                        p_encoded     => fnd_api.g_false);
                    lc_err_message   :=
                        lc_err_message || SUBSTR (lc_msg_data, 1, 50);
                END LOOP;
            END IF;
        -- UPDATE mode
        ELSIF p_list_line_id IS NOT NULL AND lc_err_message IS NULL
        THEN
            ln_array                          := ln_array + 1;
            l_price_list_rec.list_header_id   := ln_list_header_id;
            l_price_list_rec.list_type_code   := 'AGR';
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
                        oe_msg_pub.get (p_msg_index   => oe_msg_pub.g_next,
                                        p_encoded     => fnd_api.g_false);
                    lc_err_message   :=
                        lc_err_message || SUBSTR (lc_msg_data, 1, 50);
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
                            mdm_notes,
                            record_status,
                            error_message,
                            creation_date,
                            created_by,
                            last_update_date,
                            last_updated_by,
                            last_update_login,
                            request_id)
                 VALUES (ln_list_header_id, p_agreement_name, NVL2 (p_list_line_id, 'UPDATE', 'ADD'), 'ITEM', lc_product_attribute, lc_product_attr_value, NVL (p_inventory_item, lc_product_attr_val_disp), lc_uom_code, p_list_price, p_start_date, p_end_date, p_list_line_id, p_mdm_notes, NVL (lc_return_status, 'S'), lc_err_message, SYSDATE, fnd_global.user_id, SYSDATE
                         , fnd_global.user_id, -1, -1);
        END IF;
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
    END agr_upload_prc;
END xxd_qp_agr_adi_upload_pk;
/
