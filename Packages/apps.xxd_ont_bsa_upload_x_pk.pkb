--
-- XXD_ONT_BSA_UPLOAD_X_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_BSA_UPLOAD_X_PK"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BSA_UPLOAD_X_PK
    * Design       : This package is used for Blanket Sales Agreement Upload WebADI
    * Notes        : Validate and insert
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 09-Jan-2017  1.0        Viswanathan Pandian     WebADI for Blanket Sales Agreement Upload
    --                                                 for CCR0005549
    ******************************************************************************************/
    --Public Subprograms
    /****************************************************************************************
    * Procedure    : BSA_VALIDATE_PRC
    * Design       : This procedure validates and calls public API to create Blanket Sales Agreement
    * Notes        : This is called from WebADI
    * Return Values: None
    * Modification :
    * ===============================================================================
    * Date         Version#   Name                    Comments
    * ===============================================================================
    * 09-Jan-2017  1.0        Viswanathan Pandian     Initial Version
    ****************************************************************************************/
    PROCEDURE bsa_upload_prc (p_order_number IN oe_blanket_headers_all.order_number%TYPE, p_inventory_item_number IN mtl_system_items_b.segment1%TYPE, p_customer_item_number IN mtl_customer_items.customer_item_number%TYPE, p_blanket_min_quantity IN oe_blanket_lines_ext.blanket_min_quantity%TYPE, p_blanket_max_quantity IN oe_blanket_lines_ext.blanket_max_quantity%TYPE, p_override_rel_controls_flag IN oe_blanket_lines_ext.override_release_controls_flag%TYPE
                              , p_blanket_min_release_quantity IN oe_blanket_lines_ext.min_release_quantity%TYPE, p_blanket_max_release_quantity IN oe_blanket_lines_ext.max_release_quantity%TYPE)
    IS
        ln_header_id              oe_blanket_headers_all.header_id%TYPE;
        lc_order_brand            oe_blanket_headers_all.attribute6%TYPE;
        ln_customer_id            hz_cust_accounts.cust_account_id%TYPE;
        ln_inventory_item_id      xxd_common_items_v.inventory_item_id%TYPE;
        ln_ordered_item_id        xxd_common_items_v.inventory_item_id%TYPE;
        lc_cust_brand             hz_cust_accounts.attribute1%TYPE;
        lc_internal_item_brand    xxd_common_items_v.brand%TYPE;
        lc_customer_item_brand    xxd_common_items_v.brand%TYPE;
        lc_primary_uom_code       xxd_common_items_v.primary_uom_code%TYPE;
        lc_item_identifier_type   VARCHAR2 (20);
        lc_err_message            VARCHAR2 (4000);
        ln_exists                 NUMBER;
        ln_dummy                  NUMBER;
        le_webadi_exception       EXCEPTION;
        ln_org_id                 NUMBER := fnd_global.org_id;
        ln_user_id                NUMBER := fnd_global.user_id;
        l_hdr_rec                 oe_blanket_pub.header_rec_type;
        l_hdr_val_rec             oe_blanket_pub.header_val_rec_type;
        l_line_rec                oe_blanket_pub.line_rec_type;
        l_line_tbl                oe_blanket_pub.line_tbl_type;
        l_line_val_rec            oe_blanket_pub.line_val_rec_type;
        l_line_val_tbl            oe_blanket_pub.line_val_tbl_type;
        l_control_rec             oe_blanket_pub.control_rec_type;
        x_line_tbl                oe_blanket_pub.line_tbl_type;
        x_header_rec              oe_blanket_pub.header_rec_type;
        x_msg_count               NUMBER;
        x_msg_data                VARCHAR2 (2000);
        x_return_status           VARCHAR2 (30);
        ln_index                  NUMBER DEFAULT 1;
    BEGIN
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', ln_org_id);
        oe_msg_pub.initialize;

        -- Validate Order Number
        IF p_order_number IS NULL
        THEN
            lc_err_message   :=
                lc_err_message || 'Agreement Number is null. ';
        ELSE
            BEGIN
                SELECT obha.header_id, obha.sold_to_org_id, NVL (obha.attribute6, -1),
                       NVL (hca.attribute1, -1)
                  INTO ln_header_id, ln_customer_id, lc_order_brand, lc_cust_brand
                  FROM oe_blanket_headers_all obha, hz_cust_accounts hca
                 WHERE     obha.sold_to_org_id = hca.cust_account_id
                       AND obha.order_number = p_order_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Invalid Agreement Number. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Item
        IF     p_inventory_item_number IS NOT NULL
           AND p_customer_item_number IS NOT NULL
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Both Internal Item and Customer Item cannot be given. ';
        ELSIF     p_inventory_item_number IS NULL
              AND p_customer_item_number IS NULL
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Either Internal Item or Customer Item should be given. ';
        END IF;

        -- Validate Inventory Item
        IF     p_inventory_item_number IS NOT NULL
           AND p_customer_item_number IS NULL
        THEN
            BEGIN
                SELECT inventory_item_id, brand, primary_uom_code,
                       'INT'
                  INTO ln_inventory_item_id, lc_internal_item_brand, lc_primary_uom_code, lc_item_identifier_type
                  FROM xxd_common_items_v
                 WHERE     inventory_item_status_code <> 'Inactive'
                       AND master_org_flag = 'Y'
                       AND item_number = p_inventory_item_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Internal Item Number is invalid or inactive. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Customer Item
        IF     p_customer_item_number IS NOT NULL
           AND p_inventory_item_number IS NULL
           AND ln_customer_id IS NOT NULL
        THEN
            BEGIN
                SELECT mci.customer_item_id, xciv.brand, xcix.inventory_item_id,
                       xciv.primary_uom_code, 'CUST'
                  INTO ln_ordered_item_id, lc_customer_item_brand, ln_inventory_item_id, lc_primary_uom_code,
                                         lc_item_identifier_type
                  FROM mtl_customer_items mci, mtl_customer_item_xrefs xcix, xxd_common_items_v xciv
                 WHERE     mci.customer_item_id = xcix.customer_item_id
                       AND xciv.inventory_item_id = xcix.inventory_item_id
                       AND xciv.inventory_item_status_code <> 'Inactive'
                       AND xciv.master_org_flag = 'Y'
                       AND mci.inactive_flag = 'N'
                       AND xcix.preference_number = 1
                       AND mci.customer_id = ln_customer_id
                       AND mci.customer_item_number = p_customer_item_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Customer Item Number is invalid or inactive or not associated with the Customer Number. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Customer, Item and Customer Item's Brand
        IF     lc_order_brand IS NOT NULL
           AND (lc_cust_brand IS NOT NULL OR lc_internal_item_brand IS NOT NULL)
        THEN
            IF lc_cust_brand <> lc_order_brand
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Customer Brand do not match with Agreement Brand. ';
            ELSIF lc_internal_item_brand <> lc_order_brand
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Internal Item Brand do not match with Agreement Brand. ';
            ELSIF lc_customer_item_brand <> lc_order_brand
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Customer Item Brand do not match with Agreement Brand. ';
            END IF;
        END IF;

        -- Validate Min Quantity
        IF p_blanket_min_quantity IS NOT NULL
        THEN
            BEGIN
                SELECT TO_NUMBER (p_blanket_min_quantity, '9999999')
                  INTO ln_dummy
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Min Quantity should be a whole number; No fractions allowed. ';
            END;
        END IF;

        -- Validate Max Quantity
        IF p_blanket_max_quantity IS NOT NULL
        THEN
            BEGIN
                SELECT TO_NUMBER (p_blanket_max_quantity, '9999999')
                  INTO ln_dummy
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Max Quantity should be a whole number; No fractions allowed. ';
            END;
        END IF;

        -- Validate Min Rel Quantity
        IF p_blanket_min_release_quantity IS NOT NULL
        THEN
            BEGIN
                SELECT TO_NUMBER (p_blanket_min_release_quantity, '9999999')
                  INTO ln_dummy
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Min Release Quantity should be a whole number; No fractions allowed. ';
            END;
        END IF;

        -- Validate Max Rel Quantity
        IF p_blanket_max_release_quantity IS NOT NULL
        THEN
            BEGIN
                SELECT TO_NUMBER (p_blanket_max_release_quantity, '9999999')
                  INTO ln_dummy
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Max Release Quantity should be a whole number; No fractions allowed. ';
            END;
        END IF;

        -- Validate Override Release Control Flag

        IF NVL (p_override_rel_controls_flag, 'N') NOT IN ('Y', 'N')
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Override Release Control Flag should be Yes or No. ';
        END IF;

        -- Insert Records
        IF lc_err_message IS NULL
        THEN
            -- Header Record
            l_hdr_rec                                   := oe_blanket_pub.g_miss_header_rec;
            l_hdr_val_rec                               := oe_blanket_pub.g_miss_header_val_rec;
            l_hdr_rec.header_id                         := ln_header_id;

            -- Line Record
            l_line_rec.operation                        := oe_globals.g_opr_create;
            l_line_rec.header_id                        := ln_header_id;
            l_line_rec.sold_to_org_id                   := ln_customer_id;
            l_line_rec.item_identifier_type             := lc_item_identifier_type;
            l_line_rec.ordered_item                     :=
                NVL (p_inventory_item_number, p_customer_item_number);
            l_line_rec.inventory_item_id                := ln_inventory_item_id;
            l_line_rec.ordered_item_id                  := ln_ordered_item_id;
            l_line_rec.order_quantity_uom               := lc_primary_uom_code;
            l_line_rec.blanket_min_quantity             := p_blanket_min_quantity;
            l_line_rec.blanket_max_quantity             := p_blanket_max_quantity;
            l_line_rec.override_release_controls_flag   :=
                p_override_rel_controls_flag;
            l_line_rec.min_release_quantity             :=
                p_blanket_min_release_quantity;
            l_line_rec.max_release_quantity             :=
                p_blanket_max_release_quantity;
            l_line_rec.start_date_active                := SYSDATE;

            l_line_tbl (ln_index)                       := l_line_rec;
            l_line_val_tbl (ln_index)                   := l_line_val_rec;

            oe_blanket_pub.process_blanket (p_org_id => ln_org_id, p_operating_unit => NULL, p_api_version_number => 1.0, x_return_status => x_return_status, x_msg_count => x_msg_count, x_msg_data => x_msg_data, p_header_rec => l_hdr_rec, p_header_val_rec => l_hdr_val_rec, p_line_tbl => l_line_tbl, p_line_val_tbl => l_line_val_tbl, p_control_rec => l_control_rec, x_header_rec => x_header_rec
                                            , x_line_tbl => x_line_tbl);

            IF x_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR i IN 1 .. x_msg_count
                LOOP
                    lc_err_message   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                RAISE le_webadi_exception;
            END IF;
        ELSE
            RAISE le_webadi_exception;
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
    END bsa_upload_prc;
END xxd_ont_bsa_upload_x_pk;
/
