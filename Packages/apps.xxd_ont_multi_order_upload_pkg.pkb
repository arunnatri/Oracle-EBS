--
-- XXD_ONT_MULTI_ORDER_UPLOAD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_MULTI_ORDER_UPLOAD_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_MULTI_ORDER_UPLOAD_PKG
    * Design       : This package is used for Multi Sales Order WebADI upload
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 16-May-2017  1.0        Viswanathan Pandian     Initial Version
    -- 03-Oct-2017  1.1        Viswanathan Pandian     Modified for Bulk Orders CCR0006663
    -- 11-Dec-2017  1.2        Viswanathan Pandian     Modified for CCR0006653
    -- 02-Mar-2018  1.3        Infosys                 Modified for CCR0007082
    -- 29-Jan-2018  1.4        Viswanathan Pandian     Modified for CCR0006889 to revert code
    --                                                 changes done as part of CCR0006663
    -- 11-Jan-2019  1.5        Viswanathan Pandian     Modified for CCR0007557
    -- 07-Apr-2019  1.6        Viswanathan Pandian     Modified for CCR0007844
    -- 24-Feb-2021  1.7        Viswanathan Pandian     Modified for CCR0008870
    -- 21-Jul-2021  1.8        Aravind Kannuri         Modified for CCR0009429
    -- 05-OCT-2021  1.9        Laltu                   Updated for CCR0009629
    -- 10-Jan-2022  2.0        Gaurav                  CCR0009808 - peformance issue due to vas code
    -- 14-Mar-2022  2.1        Viswanathan Pandian     Modified for CCR0009886
    ******************************************************************************************/
    --begin ver 2.0 added this procedure to get vas code; earlier this procedure was in SOMT package but brought it here for the segregation purpose.
    -- at the same time, fixed the performance issue also by removing to_char on cust_account_id
    FUNCTION get_vas_code (p_level IN VARCHAR2, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER
                           , p_style IN VARCHAR2, p_color IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_vas_code   VARCHAR2 (240) := NULL;
        l_style      VARCHAR (240);

        CURSOR lcu_get_vas_code_text (p_cust_account_id IN NUMBER)
        IS
            SELECT title short_text
              FROM oe_attachment_rules oar, fnd_documents_vl fdv, fnd_documents_short_text fdl,
                   fnd_document_categories_vl fdc, hz_cust_accounts cust, oe_attachment_rule_elements_v oare
             WHERE     1 = 1
                   AND oar.document_id = fdv.document_id
                   AND fdv.datatype_name = 'Short Text'
                   AND fdv.media_id = fdl.media_id
                   AND fdc.category_id = fdv.category_id
                   AND fdc.application_id = 660
                   AND fdc.user_name = 'VAS Codes'
                   AND oare.rule_id = oar.rule_id
                   AND oare.attribute_name = 'Customer'
                   AND cust.cust_account_id = oare.attribute_value
                   AND oare.attribute_value = TO_CHAR (p_cust_account_id)
                   AND TRUNC (SYSDATE) BETWEEN NVL (fdv.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (fdv.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND TRUNC (SYSDATE) BETWEEN NVL (fdc.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (fdc.end_date_active,
                                                    TRUNC (SYSDATE));
    BEGIN
        SELECT DECODE (INSTR (p_style, '-'), 0, p_style, SUBSTR (p_style, 1, INSTR (p_style, '-') - 1))
          INTO l_style
          FROM DUAL;

        IF p_level = 'HEADER'
        THEN
            SELECT SUBSTR (LISTAGG (vas_code, '+') WITHIN GROUP (ORDER BY vas_code), 1, 240)
              INTO l_vas_code
              FROM (SELECT DISTINCT vas_code
                      FROM xxd_ont_vas_assignment_dtls_t
                     WHERE     1 = 1
                           AND cust_account_id = p_cust_account_id
                           AND attribute_level IN ('CUSTOMER'));
        ELSIF p_level = 'LINE'
        THEN
            SELECT SUBSTR (LISTAGG (vas_code, '+') WITHIN GROUP (ORDER BY vas_code), 1, 240)
              INTO l_vas_code
              FROM (SELECT vas_code
                      FROM xxd_ont_vas_assignment_dtls_t a
                     WHERE     a.attribute_level = 'STYLE'
                           AND a.attribute_value = l_style
                           AND cust_account_id = p_cust_account_id --- for style
                    UNION
                    SELECT vas_code
                      FROM xxd_ont_vas_assignment_dtls_t a
                     WHERE     a.attribute_level = 'STYLE_COLOR'
                           AND a.attribute_value = l_style || '-' || p_color
                           AND cust_account_id = p_cust_account_id --- style color
                    UNION
                    SELECT vas_code
                      FROM xxd_ont_vas_assignment_dtls_t a, hz_cust_site_uses_all b
                     WHERE     1 = 1
                           AND cust_account_id = p_cust_account_id
                           AND b.site_use_id = p_site_use_id
                           AND b.cust_acct_site_id = a.attribute_value
                           AND attribute_level IN ('SITE'));
        END IF;

        IF l_vas_code IS NULL AND p_level = 'HEADER'
        THEN
            FOR lr_get_vas_code_text
                IN lcu_get_vas_code_text (p_cust_account_id)
            LOOP
                IF l_vas_code IS NULL
                THEN
                    l_vas_code   := lr_get_vas_code_text.short_text;
                ELSE
                    l_vas_code   :=
                        l_vas_code || '+' || lr_get_vas_code_text.short_text;
                END IF;
            END LOOP;
        END IF;

        RETURN l_vas_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN l_vas_code;
    END get_vas_code;

    -- end ver 2.0
    PROCEDURE validate_prc (
        p_header_request_date     oe_order_headers_all.request_date%TYPE,
        -- Start changes for CCR0007557
        -- p_price_list               qp_list_headers_v.name%TYPE,
        p_return_reason_code      oe_headers_iface_all.return_reason_code%TYPE,
        -- End changes for CCR0007557
        p_warehouse               mtl_parameters.organization_code%TYPE,
        p_subinventory            mtl_secondary_inventories.secondary_inventory_name%TYPE,
        p_header_cancel_date      oe_order_headers_all.request_date%TYPE,
        p_order_type              oe_transaction_types_tl.name%TYPE,
        p_book_order              VARCHAR2,
        p_brand                   oe_order_headers_all.attribute5%TYPE,
        p_customer_number         hz_cust_accounts.account_number%TYPE,
        p_ship_to_location        hz_cust_site_uses_all.location%TYPE,
        p_bill_to_location        hz_cust_site_uses_all.location%TYPE,
        p_deliver_to_location     hz_cust_site_uses_all.location%TYPE,
        p_cust_po_number          oe_order_headers_all.cust_po_number%TYPE,
        p_packing_instructions    oe_order_headers_all.packing_instructions%TYPE, -- Added for CCR0007844
        p_shipping_instructions   oe_order_headers_all.shipping_instructions%TYPE,
        p_comments1               oe_order_headers_all.attribute6%TYPE,
        p_comments2               oe_order_headers_all.attribute7%TYPE,
        p_pricing_agreement       oe_agreements_tl.name%TYPE,
        p_sales_agreement         oe_blanket_headers_all.order_number%TYPE,
        p_customer_item           mtl_customer_items.customer_item_number%TYPE,
        p_inventory_item          mtl_system_items_b.segment1%TYPE,
        p_ordered_qty             oe_order_lines_all.ordered_quantity%TYPE,
        p_line_request_date       oe_order_lines_all.request_date%TYPE,
        p_line_cancel_date        oe_order_lines_all.request_date%TYPE,
        p_unit_selling_price      oe_order_lines_all.unit_selling_price%TYPE,
        -- Start changes for CCR0007844
        p_additional_column1      VARCHAR2,
        p_additional_column2      VARCHAR2,
        p_additional_column3      VARCHAR2,
        p_additional_column4      VARCHAR2,
        p_additional_column5      VARCHAR2,
        p_additional_column6      VARCHAR2,
        p_additional_column7      VARCHAR2,
        p_additional_column8      VARCHAR2,
        p_additional_column9      VARCHAR2,
        p_additional_column10     VARCHAR2)      -- End changes for CCR0007844
    AS
        ln_inventory_item_id        mtl_system_items_b.inventory_item_id%TYPE;
        ln_cust_inventory_item_id   mtl_system_items_b.inventory_item_id%TYPE;
        ln_inv_org_id               mtl_parameters.organization_id%TYPE;
        ln_ship_to_org_id           oe_headers_iface_all.ship_to_org_id%TYPE;
        ln_invoice_to_org_id        oe_headers_iface_all.invoice_to_org_id%TYPE;
        ln_deliver_to_org_id        oe_headers_iface_all.deliver_to_org_id%TYPE;
        ln_cust_account_id          hz_cust_accounts.cust_account_id%TYPE;
        ln_list_header_id           qp_list_headers.list_header_id%TYPE;
        ln_sa_header_id             oe_blanket_headers_all.header_id%TYPE;
        lc_inventory_item_brand     oe_order_headers_all.attribute5%TYPE;
        lc_customer_item_brand      oe_order_headers_all.attribute5%TYPE;
        lc_cust_item_type           oe_lines_iface_all.customer_item_id_type%TYPE;
        ld_request_date             oe_headers_iface_all.request_date%TYPE;
        ln_exists                   NUMBER DEFAULT 0;
        lc_err_message              VARCHAR2 (4000);
        lc_ret_message              VARCHAR2 (4000);
        le_webadi_exception         EXCEPTION;
        -- Start commenting for CCR0006889 on 08-Mar-2018
        -- Start changes for CCR0006663
        -- lc_bulk_order               VARCHAR2 (1);
        -- ld_cancel_date              DATE;
        -- End changes for CCR0006663
        -- End commenting for CCR0006889 on 08-Mar-2018
        gn_master_org_id            NUMBER; -- 1.3 Added by Infosys for CCR0007082
        ld_intro_date               DATE; -- 1.3 Added by Infosys for CCR0007082
        ld_ats_date                 DATE; -- 1.3 Added by Infosys for CCR0007082
        ln_org_exist_cnt            NUMBER;
        -- Start changes for CCR0007557
        lc_order_category_code      oe_transaction_types_all.order_category_code%TYPE;
        lc_return_reason_code       oe_headers_iface_all.return_reason_code%TYPE;
        -- End changes for CCR0007557
        -- Start changes for CCR0009429
        ld_ats_intro_date           DATE;
        lv_ats_day                  VARCHAR2 (50) := NULL;
        ln_buffer_days              NUMBER := 0;
        ln_ats_wknd_exists          NUMBER := 0;
        ln_cust_eligible_exists     NUMBER := 0;
        -- End changes for CCR0009429
        lv_color                    VARCHAR2 (1000);   -- Added for CCR0009629
        lv_style                    VARCHAR2 (1000);   -- Added for CCR0009629
    BEGIN
        SELECT organization_id          -- 1.3 Added by Infosys for CCR0007082
          INTO gn_master_org_id
          FROM mtl_parameters
         WHERE organization_code = 'MST';

        -- Derive Cust Account ID
        IF p_customer_number IS NOT NULL
        THEN
            BEGIN
                SELECT cust_account_id
                  INTO ln_cust_account_id
                  FROM hz_cust_accounts
                 WHERE     NVL (attribute1, -1) = p_brand
                       AND account_number = p_customer_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Invalid Customer Or the Customer is not associated with the brand. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Derive Inv Org ID
        IF p_warehouse IS NOT NULL
        THEN
            BEGIN
                SELECT organization_id
                  INTO ln_inv_org_id
                  FROM mtl_parameters
                 WHERE organization_code = p_warehouse;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Invalid Warehouse. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Start changes for CCR0007557
        -- Validate Return Reason if Return Order
        BEGIN
            lc_return_reason_code   := p_return_reason_code;

            SELECT order_category_code
              INTO lc_order_category_code
              FROM oe_transaction_types_all otta, oe_transaction_types_tl ottt
             WHERE     otta.transaction_type_id = ottt.transaction_type_id
                   AND ottt.language = USERENV ('LANG')
                   AND ottt.name = p_order_type;

            IF     lc_order_category_code = 'RETURN'
               AND p_return_reason_code IS NULL
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Return Reason is mandatory for Return Orders. ';
            ELSIF lc_order_category_code <> 'RETURN'
            THEN
                lc_return_reason_code   := NULL; -- If value is passed for an regular order, make it null.
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Unable to derive Order Category Code. ';
            WHEN OTHERS
            THEN
                lc_err_message   := lc_err_message || SQLERRM;
        END;

        -- End changes for CCR0007557
        -- Validate Subinventory
        IF p_subinventory IS NOT NULL AND ln_inv_org_id IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_exists
              FROM mtl_secondary_inventories
             WHERE     secondary_inventory_name = p_subinventory
                   AND organization_id = ln_inv_org_id;

            IF ln_exists = 0
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Subinventory is not valid for this Warehouse. ';
            END IF;
        END IF;

        -- Validate Inventory/Customer Item
        IF p_customer_item IS NOT NULL AND p_inventory_item IS NOT NULL
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Customer Item and Inventory Item cannot be populated on the same line. ';
        ELSIF p_customer_item IS NULL AND p_inventory_item IS NULL
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Either Customer Item or Inventory Item is mandatory. ';
        ELSE
            -- Derive Inventory Item ID
            IF p_inventory_item IS NOT NULL
            THEN
                -- Start changes for CCR0007844
                -- Item has to be active in both current and master org
                ln_exists   := 0;

                SELECT COUNT (1)
                  INTO ln_exists
                  FROM xxd_common_items_v
                 WHERE     organization_id IN
                               (ln_inv_org_id, gn_master_org_id)
                       AND inventory_item_status_code <> 'Inactive'
                       AND customer_order_enabled_flag = 'Y'
                       AND item_number = p_inventory_item;

                IF ln_exists < 2
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'SKU is Inactive either in the selected wareshouse or Master Org. ';
                ELSE
                    -- End changes for CCR0007844
                    BEGIN
                        SELECT inventory_item_id, brand
                          INTO ln_inventory_item_id, lc_inventory_item_brand
                          FROM xxd_common_items_v
                         WHERE     organization_id = ln_inv_org_id
                               AND item_number = p_inventory_item;

                        -- Validate Customer and Inventory Item's Brand
                        IF lc_inventory_item_brand <> p_brand
                        THEN
                            lc_err_message   :=
                                   lc_err_message
                                || 'Customer/SKU Brand do not match. ';
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lc_err_message   :=
                                   lc_err_message
                                || 'SKU is invalid or not assigned to Warehouse. ';
                        WHEN OTHERS
                        THEN
                            lc_err_message   := lc_err_message || SQLERRM;
                    END;
                END IF;                                -- Added for CCR0007844
            END IF;

            -- Derive Customer Item's XREF
            IF p_customer_item IS NOT NULL
            THEN
                BEGIN
                    SELECT xcix.inventory_item_id, xciv.brand, 'CUST'
                      INTO ln_cust_inventory_item_id, lc_customer_item_brand, lc_cust_item_type
                      FROM mtl_customer_items mci, mtl_customer_item_xrefs xcix, xxd_common_items_v xciv
                     WHERE     mci.customer_item_id = xcix.customer_item_id
                           AND xciv.inventory_item_id =
                               xcix.inventory_item_id
                           AND xciv.inventory_item_status_code <> 'Inactive'
                           AND xciv.master_org_flag = 'Y'
                           AND mci.inactive_flag = 'N'
                           AND mci.customer_id = ln_cust_account_id
                           AND mci.customer_item_number = p_customer_item;

                    -- Validate Customer and Customer Item's Brand
                    IF lc_customer_item_brand <> p_brand
                    THEN
                        lc_err_message   :=
                               lc_err_message
                            || 'Customer/Customer Item Brand do not match. ';
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lc_err_message   :=
                               lc_err_message
                            || 'Customer Item is invalid or not assigned to Customer. ';
                    WHEN OTHERS
                    THEN
                        lc_err_message   := lc_err_message || SQLERRM;
                END;
            END IF;
        END IF;

        -- Validate Ship To
        IF p_ship_to_location IS NOT NULL AND ln_cust_account_id IS NOT NULL
        THEN
            BEGIN
                SELECT site_use_id
                  INTO ln_ship_to_org_id
                  FROM xxd_ont_mou_cust_shipto_v
                 WHERE     location = p_ship_to_location
                       AND cust_account_id = ln_cust_account_id;

                IF ln_ship_to_org_id IS NULL
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Ship to location is invalid. ';
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Ship to location is invalid. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Bill To
        IF p_bill_to_location IS NOT NULL AND ln_cust_account_id IS NOT NULL
        THEN
            BEGIN
                SELECT site_use_id
                  INTO ln_invoice_to_org_id
                  FROM xxd_ont_mou_brandcust_sites_v
                 WHERE     site_use_code = 'BILL_TO'
                       AND location = p_bill_to_location
                       AND cust_account_id = ln_cust_account_id;

                IF ln_invoice_to_org_id IS NULL
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Bill to location is invalid. ';
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Bill to location is invalid. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Validate Deliver To
        IF     p_deliver_to_location IS NOT NULL
           AND ln_cust_account_id IS NOT NULL
        THEN
            BEGIN
                SELECT site_use_id
                  INTO ln_deliver_to_org_id
                  FROM xxd_ont_mou_brandcust_sites_v
                 WHERE     site_use_code = 'DELIVER_TO'
                       AND location = p_deliver_to_location
                       AND cust_account_id = ln_cust_account_id;

                IF ln_deliver_to_org_id IS NULL
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Deliver to location is invalid. ';
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_err_message   :=
                        lc_err_message || 'Deliver to location is invalid. ';
                WHEN OTHERS
                THEN
                    lc_err_message   := lc_err_message || SQLERRM;
            END;
        END IF;

        -- Start commenting for CCR0006889 on 08-Mar-2018
        -- Start changes for CCR0006663
        -- Validate if Bulk Order
        -- SELECT DECODE (COUNT (1), 0, 'N', 'Y')
        --   INTO lc_bulk_order
        --   FROM fnd_lookup_values
        --  WHERE     lookup_type = 'XXD_ONT_PICK_REL_ORD_TYP_EXCL'
        --        AND tag = 'Bulk Order'
        --        AND enabled_flag = 'Y'
        --        AND TRUNC (SYSDATE) BETWEEN TRUNC (
        --                                       NVL (start_date_active, SYSDATE))
        --                                AND TRUNC (
        --                                       NVL (end_date_active, SYSDATE))
        --        AND meaning = p_order_type;

        -- End changes for CCR0006663
        -- End commenting for CCR0006889 on 08-Mar-2018

        -- Validate Request Date
        IF p_line_request_date IS NULL AND p_header_request_date IS NULL
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Either Header or Line Request Date is mandatory. ';
        ELSE
            ld_request_date   :=
                NVL (p_line_request_date, p_header_request_date);

            -- Validate Header Cancel Date
            IF     p_header_cancel_date IS NOT NULL
               AND p_header_cancel_date <= ld_request_date
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Header Cancel Date cannot be less than or equal to Request Date. ';
            END IF;

            -- Validate Line Cancel Date
            IF     p_line_cancel_date IS NOT NULL
               AND p_line_cancel_date <= ld_request_date
            THEN
                lc_err_message   :=
                       lc_err_message
                    || 'Line Cancel Date cannot be less than or equal to Request Date. ';
            END IF;
        END IF;

        -- Validate Cancel Date
        IF p_line_cancel_date IS NULL AND p_header_cancel_date IS NULL
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Either Header or Line Cancel Date is mandatory. ';
        END IF;

        -- Start commenting for CCR0006889 on 08-Mar-2018
        -- Start changes for CCR0006663
        -- If Bulk Order then
        -- Request Date should be First of that month
        -- Cancel Date should be Last Day of Request Date's Month
        -- ld_cancel_date := NVL (p_line_cancel_date, p_header_cancel_date);

        -- IF     lc_bulk_order = 'Y'
        --    AND (   TO_DATE (TRUNC (p_header_request_date, 'MM')) <>
        --               p_header_request_date
        --         OR TO_DATE (TRUNC (ld_request_date, 'MM')) <> ld_request_date
        --         OR TO_DATE (LAST_DAY (p_header_request_date)) <>
        --               p_header_cancel_date
        --         OR TO_DATE (LAST_DAY (ld_request_date)) <> ld_cancel_date)
        -- THEN
        --    lc_err_message :=
        --          lc_err_message
        --       || 'Bulk orders must be placed for a specific calendar month; with the request date set as the first of the month and cancel date as the last day of the month. ';
        -- END IF;

        -- End changes for CCR0006663
        -- End commenting for CCR0006889 on 08-Mar-2018

        -- Start changes for CCR0007844
        -- 1.3: Start: Added by Infosys for CCR0007082
        /*SELECT COUNT (1)
          INTO ln_org_exist_cnt
          FROM fnd_lookup_values_vl
         WHERE     lookup_type = 'XXD_ONT_SO_WEBADI_ATS_INTRO_OU'
               AND enabled_flag = 'Y'
               AND MEANING = gn_org_id;

        IF ln_org_exist_cnt <> 0
        THEN
            BEGIN
                SELECT TRUNC (TO_DATE (msi.attribute24, 'YYYY/MM/DD'), 'MM'),
                       TO_DATE (msi.attribute25, 'YYYY/MM/DD')
                  INTO ld_intro_Date, ld_ats_Date
                  FROM apps.mtl_system_items_b msi
                 WHERE     segment1 = p_inventory_item
                       AND organization_id = gn_master_org_id;

                IF TRUNC (ld_request_date) <
                   NVL (NVL (ld_ats_date, ld_intro_date),
                        TRUNC (ld_request_date))
                THEN
                    lc_err_message :=
                           lc_err_message
                        || 'ATS or Intro validation error, please check the Request Date';
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message :=
                           'Exception raised in Intro date validation'
                        || SQLERRM;
            END;
        END IF;*/

        -- 1.3: END: Added by Infosys for CCR0007082
        -- End changes for CCR0007844

        -- Validate Pricing and Sales Agreement
        IF p_pricing_agreement IS NOT NULL AND p_sales_agreement IS NOT NULL
        THEN
            lc_err_message   :=
                   lc_err_message
                || 'Pricing Agreement cannot be specified along with Sales Agreement. ';
        ELSIF    p_pricing_agreement IS NOT NULL
              OR p_sales_agreement IS NOT NULL
        THEN
            -- Validate Price Agreement
            IF     p_pricing_agreement IS NOT NULL
               AND ln_cust_account_id IS NOT NULL
            THEN
                BEGIN
                    SELECT price_list_id
                      INTO ln_list_header_id
                      FROM oe_agreements_vl
                     WHERE     name = p_pricing_agreement
                           AND sold_to_org_id = ln_cust_account_id
                           AND ld_request_date BETWEEN TRUNC (
                                                           NVL (
                                                               start_date_active,
                                                               ld_request_date))
                                                   AND TRUNC (
                                                           NVL (
                                                               end_date_active,
                                                               ld_request_date));

                    -- Validate Item
                    IF     (ln_inventory_item_id IS NOT NULL OR ln_cust_inventory_item_id IS NOT NULL)
                       AND ld_request_date IS NOT NULL
                    THEN
                        SELECT COUNT (1)
                          INTO ln_exists
                          FROM qp_list_lines_v
                         WHERE     list_header_id = ln_list_header_id
                               AND product_attribute_context = 'ITEM'
                               AND product_attribute = 'PRICING_ATTRIBUTE1'
                               AND ((ln_inventory_item_id IS NOT NULL AND product_attr_value = TO_CHAR (ln_inventory_item_id)) OR (ln_cust_inventory_item_id IS NOT NULL AND product_attr_value = TO_CHAR (ln_cust_inventory_item_id)))
                               AND ld_request_date BETWEEN TRUNC (
                                                               NVL (
                                                                   start_date_active,
                                                                   ld_request_date))
                                                       AND TRUNC (
                                                               NVL (
                                                                   end_date_active,
                                                                   ld_request_date));

                        IF ln_exists = 0
                        THEN
                            lc_err_message   :=
                                   lc_err_message
                                || 'SKU is not valid for this Pricing Agreement. ';
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lc_err_message   :=
                               lc_err_message
                            || 'Pricing Agreement is not valid for this Customer or not active. ';
                    WHEN OTHERS
                    THEN
                        lc_err_message   := lc_err_message || SQLERRM;
                END;
            END IF;

            -- Validate Sales Agreement
            IF     p_sales_agreement IS NOT NULL
               AND ln_cust_account_id IS NOT NULL
            THEN
                BEGIN
                    SELECT header_id
                      INTO ln_sa_header_id
                      FROM oe_blanket_headers_all obha
                     WHERE     order_number = p_sales_agreement
                           AND sold_to_org_id = ln_cust_account_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM oe_blanket_headers_ext obhe
                                     WHERE     obhe.order_number =
                                               obha.order_number
                                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                           TRUNC (
                                                                               obhe.start_date_active),
                                                                           TRUNC (
                                                                               SYSDATE))
                                                                   AND NVL (
                                                                           TRUNC (
                                                                               obhe.end_date_active),
                                                                           TRUNC (
                                                                               SYSDATE)));

                    -- Validate Item
                    IF    ln_inventory_item_id IS NOT NULL
                       OR ln_cust_inventory_item_id IS NOT NULL
                    THEN
                        SELECT COUNT (1)
                          INTO ln_exists
                          FROM oe_blanket_lines_all obla
                         WHERE     obla.header_id = ln_sa_header_id
                               AND ((ln_inventory_item_id IS NOT NULL AND obla.inventory_item_id = TO_CHAR (ln_inventory_item_id)) OR (ln_cust_inventory_item_id IS NOT NULL AND obla.inventory_item_id = TO_CHAR (ln_cust_inventory_item_id)))
                               AND EXISTS
                                       (SELECT 1
                                          FROM oe_blanket_lines_ext oble
                                         WHERE     oble.line_id =
                                                   obla.line_id
                                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                               TRUNC (
                                                                                   oble.start_date_active),
                                                                               TRUNC (
                                                                                   SYSDATE))
                                                                       AND NVL (
                                                                               TRUNC (
                                                                                   oble.end_date_active),
                                                                               TRUNC (
                                                                                   SYSDATE)));

                        IF ln_exists = 0
                        THEN
                            lc_err_message   :=
                                   lc_err_message
                                || 'SKU is not valid for this Sales Agreement. ';
                        END IF;
                    END IF;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        lc_err_message   :=
                               lc_err_message
                            || 'Sales Agreement is not valid for this Customer or Inactive. ';
                    WHEN OTHERS
                    THEN
                        lc_err_message   := lc_err_message || SQLERRM;
                END;
            END IF;
        END IF;

        -- Start changes for CCR0007844
        IF ln_inventory_item_id IS NOT NULL AND ld_request_date IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_org_exist_cnt
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'XXD_ONT_SO_WEBADI_ATS_INTRO_OU'
                   AND enabled_flag = 'Y'
                   AND meaning = gn_org_id;

            IF ln_org_exist_cnt <> 0
            THEN
                BEGIN
                    SELECT TRUNC (fnd_date.canonical_to_date (attribute24), 'MM'), TRUNC (fnd_date.canonical_to_date (attribute25))
                      INTO ld_intro_date, ld_ats_date
                      FROM mtl_system_items_b
                     WHERE     inventory_item_id = ln_inventory_item_id
                           AND organization_id = ln_inv_org_id;

                    IF ld_intro_date IS NULL AND ld_ats_date IS NULL
                    THEN
                        SELECT TRUNC (fnd_date.canonical_to_date (attribute24), 'MM'), TRUNC (fnd_date.canonical_to_date (attribute25))
                          INTO ld_intro_date, ld_ats_date
                          FROM mtl_system_items_b
                         WHERE     inventory_item_id = ln_inventory_item_id
                               AND organization_id = gn_master_org_id;
                    END IF;

                    --Start Changes for CCR0009429
                    ld_ats_intro_date   := NVL (ld_ats_date, ld_intro_date);

                    IF ld_ats_intro_date IS NOT NULL
                    THEN
                        -- Rule1: ATS Date Weekend Check
                        BEGIN
                            SELECT CASE
                                       WHEN TO_CHAR (ld_ats_intro_date, 'DY') IN
                                                ('SAT')
                                       THEN
                                           'WKND_SAT'
                                       WHEN TO_CHAR (ld_ats_intro_date, 'DY') IN
                                                ('SUN')
                                       THEN
                                           'WKND_SUN'
                                       ELSE
                                           'WK_DAY'
                                   END ats_dt_day
                              INTO lv_ats_day
                              FROM DUAL;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_ats_day   := 'WK_DAY';
                        END;

                        IF lv_ats_day IN ('WKND_SAT')
                        THEN
                            IF ld_request_date = ld_ats_intro_date - 1
                            THEN
                                ln_ats_wknd_exists   := 1;
                            END IF;
                        ELSIF lv_ats_day IN ('WKND_SUN')
                        THEN
                            IF ld_request_date = ld_ats_intro_date - 2
                            THEN
                                ln_ats_wknd_exists   := 1;
                            END IF;
                        ELSE
                            ln_ats_wknd_exists   := 0;
                        END IF;

                        -- Rule2 and 3: Customer with Buffer Days\Null in lookup
                        BEGIN
                            SELECT NVL (flv.attribute2, 0)
                              INTO ln_buffer_days
                              FROM fnd_lookup_values flv
                             WHERE     flv.lookup_type =
                                       'XXD_ONT_ATS_CHECK_CUSTOMERS'
                                   AND flv.language = USERENV ('LANG')
                                   AND enabled_flag = 'Y'
                                   AND TO_NUMBER (flv.attribute1) =
                                       ln_cust_account_id
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   flv.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   flv.end_date_active,
                                                                     TRUNC (
                                                                         SYSDATE)
                                                                   + 1);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_buffer_days   := -1;
                        END;

                        /*
                                    IF NVL(ln_buffer_days,0) > 0          --If customer buffer days is NOT NULL
                                    THEN
                                        IF (ld_request_date >= (ld_ats_intro_date - ln_buffer_days))
                                        THEN
                                          ln_cust_eligible_exists := 1;
                                        ELSE
                                          ln_cust_eligible_exists := 0;
                                        END IF;
                                    ELSIF NVL(ln_buffer_days,0) = 0       --If customer buffer days is NULL(Eligible)
                                    THEN
                                        ln_cust_eligible_exists := 1;
                                        ln_ats_wknd_exists := 1;          --customer buffer days is NULL then Ignore ats_weekend_check
                                    ELSE                                  --If customer not-exists in lookup(Not Eligible)
                                        ln_cust_eligible_exists := 0;
                                    END IF;


                                    IF ( (NVL(ln_ats_wknd_exists, 0) = 0)
                                        OR (NVL(ln_cust_eligible_exists, 0) = 0) )
                                    THEN
                                        lc_err_message :=
                                        lc_err_message
                                            || 'ATS or Intro validation error, please check the Request Date';
                                            --'ATS Weekend exists\Customer Bufferdays error, please check the Request Date';
                                    END IF;    */

                        IF ln_ats_wknd_exists = 1
                        THEN --BYPASS VALIDATION ERROR IF ATS date falls weekend (Sat or Sun) and Request Date is on Friday (1 day before)
                            NULL;                                 --do nothing
                        ELSIF     NVL (ln_ats_wknd_exists, 0) = 0
                              AND NVL (ln_buffer_days, 0) > 0
                              AND ld_request_date >=
                                  (ld_ats_intro_date - ln_buffer_days)
                        THEN -- this is the case when its a weekday and customer buffer day is a non zero value
                            NULL;                    --do nothing --do nothing
                        ELSIF (NVL (ln_ats_wknd_exists, 0) = 0 AND NVL (ln_buffer_days, 0) = 0)
                        THEN               -- no restriction for this customer
                            NULL;                    --do nothing --do nothing
                        ELSIF     NVL (ln_ats_wknd_exists, 0) = 0
                              AND ln_buffer_days = -1
                              AND ld_request_date >= ld_ats_intro_date
                        THEN
                            --If customer not-exists in lookup;allow orders if REQ Date after ATS Date ;don’t import the order if REQ Date is before ATS Date
                            NULL;                                 --do nothing
                        ELSE
                            -- throw ats validation error
                            lc_err_message   :=
                                   lc_err_message
                                || 'ATS or Intro validation error, please check the Request Date';
                        END IF;
                    END IF;                 --IF ld_ats_intro_date IS NOT NULL
                --End Changes for CCR0009429

                /* --Commented for CCR0009429
                IF TRUNC (ld_request_date) <
                   NVL (NVL (ld_ats_date, ld_intro_date), TRUNC (ld_request_date))
                THEN
                  lc_err_message :=
                       lc_err_message
                    || 'ATS or Intro validation error, please check the Request Date';
                END IF;
                */
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_err_message   :=
                               'Exception raised in Intro date validation'
                            || SQLERRM;
                END;
            END IF;
        END IF;

        -- End changes for CCR0007844

        -- Validate Ordered Quantity
        IF p_ordered_qty = 0
        THEN
            lc_err_message   := lc_err_message || 'Quantity cannot be zero. ';
        /* ELSIF SIGN (p_ordered_qty) = -1  --as part of version 1.3
         THEN
            lc_err_message := lc_err_message || 'Quantity cannot be negative. '; */
        ELSE
            BEGIN
                SELECT TO_NUMBER (p_ordered_qty, '999999999')
                  INTO ln_exists
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_message   :=
                           lc_err_message
                        || 'Quantity Should be a whole number. ';
            END;
        END IF;

        -- Validate Unit Selling Price
        IF p_unit_selling_price = 0
        THEN
            lc_err_message   :=
                lc_err_message || 'Unit Selling Price cannot be zero. ';
        ELSIF SIGN (p_unit_selling_price) = -1
        THEN
            lc_err_message   :=
                lc_err_message || 'Unit Selling Price cannot be negative. ';
        END IF;

        -- If no error Insert into Staging Table
        IF lc_err_message IS NULL
        THEN
            INSERT INTO xxd_ont_multi_order_upload_t (org_id, order_source_id, order_type, orig_sys_document_ref, orig_sys_line_ref, brand, header_request_date, header_cancel_date, book_order, customer_number, cust_po_number, -- Start changes for CCR0007557
                                                                                                                                                                                                                                  -- price_list,
                                                                                                                                                                                                                                  return_reason_code, -- End changes for CCR0007557
                                                                                                                                                                                                                                                      ship_from_org, ship_from_org_id, ship_to_org_id, invoice_to_org_id, deliver_to_org_id, inventory_item, inventory_item_id, customer_item, cust_inventory_item_id, ordered_quantity, line_request_date, line_cancel_date, unit_selling_price, subinventory, shipping_instructions, comments1, comments2, pricing_agreement, sales_agreement, status, created_by, creation_date, last_updated_by, last_update_date, -- Start changes for CCR0007844
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       packing_instructions, additional_column1, additional_column2, additional_column3, additional_column4, additional_column5, additional_column6, additional_column7, additional_column8, additional_column9, additional_column10, -- End changes for CCR0007844
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      cust_account_id
                                                      , -- Added for CCR0009629
                                                        style, -- Added for CCR0009629
                                                               color -- Added for CCR0009629
                                                                    )
                 VALUES (gn_org_id, gn_order_source_id, p_order_type,
                         NULL, 'DO_OE_LINE_UPLOAD_' || xxd_ont_multi_order_upload_s.NEXTVAL, p_brand, p_header_request_date, p_header_cancel_date, p_book_order, p_customer_number, p_cust_po_number, -- Start changes for CCR0007557
                                                                                                                                                                                                      -- p_price_list,
                                                                                                                                                                                                      lc_return_reason_code, -- End changes for CCR0007557
                                                                                                                                                                                                                             p_warehouse, ln_inv_org_id, ln_ship_to_org_id, ln_invoice_to_org_id, ln_deliver_to_org_id, p_inventory_item, ln_inventory_item_id, p_customer_item, ln_cust_inventory_item_id, p_ordered_qty, NVL (p_line_request_date, p_header_request_date), NVL (p_line_cancel_date, p_header_cancel_date), p_unit_selling_price, p_subinventory, p_shipping_instructions, p_comments1, p_comments2, p_pricing_agreement, p_sales_agreement, 'N', gn_user_id, SYSDATE, gn_user_id, SYSDATE, -- Start changes for CCR0007844
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_packing_instructions, p_additional_column1, p_additional_column2, p_additional_column3, p_additional_column4, p_additional_column5, p_additional_column6, p_additional_column7, p_additional_column8, p_additional_column9, p_additional_column10, -- End changes for CCR0007844
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  ln_cust_account_id
                         ,                             -- Added for CCR0009629
                           lv_style,                   -- Added for CCR0009629
                                     lv_color          -- Added for CCR0009629
                                             );
        ELSE
            RAISE le_webadi_exception;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            fnd_message.set_name ('XXDO', 'XXD_ORDER_UPLOAD_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', lc_err_message);
            lc_ret_message   := fnd_message.get ();
            raise_application_error (-20000, lc_ret_message);
        WHEN OTHERS
        THEN
            lc_ret_message   := SQLERRM;
            raise_application_error (-20001, lc_ret_message);
    END validate_prc;

    PROCEDURE import_data_prc
    AS
        ln_request_id    NUMBER;
        lc_err_message   VARCHAR2 (4000);
        --Start changes for CCR0009629
        lv_vas_code      VARCHAR2 (1000);

        CURSOR c_dist_cust IS
            SELECT DISTINCT cust_account_id
              FROM xxdo.xxd_ont_multi_order_upload_t
             WHERE     org_id = gn_org_id
                   AND status = 'N'
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE);

        CURSOR c_dist_sty_col IS
            SELECT DISTINCT cust_account_id, ship_to_org_id, style,
                            color
              FROM xxdo.xxd_ont_multi_order_upload_t
             WHERE     org_id = gn_org_id
                   AND status = 'N'
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE);
    --End changes for CCR0009629
    BEGIN
        --Start changes for CCR0009629
        BEGIN
            FOR c_dist_cust_rec IN c_dist_cust
            LOOP
                lv_vas_code   := NULL;
                lv_vas_code   :=
                    get_vas_code ('HEADER', c_dist_cust_rec.cust_account_id, NULL
                                  , NULL, NULL);

                UPDATE xxdo.xxd_ont_multi_order_upload_t
                   SET hdr_vas_code   = lv_vas_code
                 WHERE     org_id = gn_org_id
                       AND status = 'N'
                       AND created_by = gn_user_id
                       AND TRUNC (creation_date) = TRUNC (SYSDATE)
                       AND cust_account_id = c_dist_cust_rec.cust_account_id;
            END LOOP;
        END;

        -- COMMIT; -- Commented for CCR0009886

        BEGIN
            FOR c_dist_sty_col_rec IN c_dist_sty_col
            LOOP
                lv_vas_code   := NULL;
                lv_vas_code   :=
                    get_vas_code ('LINE',
                                  c_dist_sty_col_rec.cust_account_id,
                                  c_dist_sty_col_rec.ship_to_org_id,
                                  c_dist_sty_col_rec.style,
                                  c_dist_sty_col_rec.color);

                UPDATE xxdo.xxd_ont_multi_order_upload_t
                   SET line_vas_code   = lv_vas_code
                 WHERE     org_id = gn_org_id
                       AND status = 'N'
                       AND created_by = gn_user_id
                       AND TRUNC (creation_date) = TRUNC (SYSDATE)
                       AND cust_account_id =
                           c_dist_sty_col_rec.cust_account_id
                       AND NVL (ship_to_org_id, -1) =
                           NVL (c_dist_sty_col_rec.ship_to_org_id, -1)
                       AND NVL (style, 'XXXXXXXXXX') =
                           NVL (c_dist_sty_col_rec.style, 'XXXXXXXXXX')
                       AND NVL (color, 'XXXXXXXXXX') =
                           NVL (c_dist_sty_col_rec.color, 'XXXXXXXXXX');
            END LOOP;
        END;

        -- COMMIT; -- Commented for CCR0009886

        --End changes for CCR0009629
        -- Update Orig Sys Document Ref
        FOR lcu_records
            IN (SELECT xmou.*, 'DO_OE_HEADER_UPLOAD_' || xxd_ont_multi_order_upload_s.NEXTVAL orig_sys_document_ref
                  FROM (  SELECT org_id, -- Start changes for CCR0007557
                                         -- price_list,
                                         return_reason_code, -- End changes for CCR0007557
                                                             ship_from_org_id,
                                 order_type, brand, customer_number,
                                 ship_to_org_id, invoice_to_org_id, deliver_to_org_id,
                                 cust_po_number, pricing_agreement, sales_agreement
                            FROM xxd_ont_multi_order_upload_t
                           WHERE     org_id = gn_org_id
                                 AND status = 'N'
                                 AND created_by = gn_user_id
                                 AND TRUNC (creation_date) = TRUNC (SYSDATE)
                        GROUP BY org_id, -- Start changes for CCR0007557
                                         -- price_list,
                                         return_reason_code, -- End changes for CCR0007557
                                                             ship_from_org_id,
                                 order_type, brand, customer_number,
                                 ship_to_org_id, invoice_to_org_id, deliver_to_org_id,
                                 cust_po_number, pricing_agreement, sales_agreement)
                       xmou)
        LOOP
            UPDATE xxd_ont_multi_order_upload_t
               SET orig_sys_document_ref = lcu_records.orig_sys_document_ref
             WHERE     org_id = lcu_records.org_id
                   -- Start changes for CCR0007557
                   -- AND price_list = lcu_records.price_list
                   AND NVL (return_reason_code, 'XX') =
                       NVL (lcu_records.return_reason_code, 'XX')
                   -- End changes for CCR0007557
                   AND ship_from_org_id = lcu_records.ship_from_org_id
                   AND order_type = lcu_records.order_type
                   AND brand = lcu_records.brand
                   AND customer_number = lcu_records.customer_number
                   AND NVL (ship_to_org_id, -99) =
                       NVL (lcu_records.ship_to_org_id, -99)
                   AND NVL (invoice_to_org_id, -99) =
                       NVL (lcu_records.invoice_to_org_id, -99)
                   AND NVL (deliver_to_org_id, -99) =
                       NVL (lcu_records.deliver_to_org_id, -99)
                   AND cust_po_number = lcu_records.cust_po_number
                   AND NVL (pricing_agreement, 'XX') =
                       NVL (lcu_records.pricing_agreement, 'XX')
                   AND NVL (sales_agreement, -99) =
                       NVL (lcu_records.sales_agreement, -99);
        END LOOP;

        -- Update Header's Request Date
        UPDATE xxd_ont_multi_order_upload_t xmou
           SET header_request_date   =
                   (  SELECT MIN (line_request_date)
                        FROM xxd_ont_multi_order_upload_t xmou1
                       WHERE xmou.orig_sys_document_ref =
                             xmou1.orig_sys_document_ref
                    GROUP BY orig_sys_document_ref)
         WHERE     org_id = gn_org_id
               AND status = 'N'
               AND created_by = gn_user_id
               AND TRUNC (creation_date) = TRUNC (SYSDATE)
               AND header_request_date IS NULL;

        -- Update Header's Cancel Date
        UPDATE xxd_ont_multi_order_upload_t xmou
           SET header_cancel_date   =
                   (  SELECT MAX (line_cancel_date)
                        FROM xxd_ont_multi_order_upload_t xmou1
                       WHERE xmou.orig_sys_document_ref =
                             xmou1.orig_sys_document_ref
                    GROUP BY orig_sys_document_ref)
         WHERE     org_id = gn_org_id
               AND status = 'N'
               AND created_by = gn_user_id
               AND TRUNC (creation_date) = TRUNC (SYSDATE)
               AND header_cancel_date IS NULL;

        -- Insert into Headers IFACE
        INSERT INTO oe_headers_iface_all (order_source_id, order_type, orig_sys_document_ref, created_by, creation_date, last_updated_by, last_update_date, request_date, operation_code, booked_flag, customer_number, sold_to_org, customer_po_number, -- Start changes for CCR0007557
                                                                                                                                                                                                                                                         -- price_list,
                                                                                                                                                                                                                                                         return_reason_code, -- End changes for CCR0007557
                                                                                                                                                                                                                                                                             ship_from_org, ship_to_org_id, invoice_to_org_id, deliver_to_org_id, attribute1, attribute5, org_id, packing_instructions, -- Added for CCR0007844
                                                                                                                                                                                                                                                                                                                                                                                                        shipping_instructions, attribute6, attribute7, agreement, blanket_number
                                          , attribute14 -- Added for CCR0009629
                                                       )
            SELECT DISTINCT order_source_id, order_type, orig_sys_document_ref,
                            created_by, SYSDATE, last_updated_by,
                            SYSDATE, header_request_date, 'INSERT',
                            book_order, customer_number, customer_number,
                            cust_po_number, -- Start changes for CCR0007557
                                            -- price_list,
                                            return_reason_code, -- End changes for CCR0007557
                                                                ship_from_org,
                            ship_to_org_id, invoice_to_org_id, deliver_to_org_id,
                            fnd_date.date_to_canonical (header_cancel_date), brand, org_id,
                            packing_instructions,      -- Added for CCR0007844
                                                  shipping_instructions, comments1,
                            comments2, pricing_agreement, sales_agreement,
                            hdr_vas_code               -- Added for CCR0009629
              FROM xxd_ont_multi_order_upload_t
             WHERE     org_id = gn_org_id
                   AND status = 'N'
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE);

        -- Insert into Lines IFACE
        INSERT INTO oe_lines_iface_all (order_source_id,
                                        orig_sys_document_ref,
                                        orig_sys_line_ref,
                                        inventory_item,
                                        inventory_item_id,
                                        ordered_quantity,
                                        request_date,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date,
                                        ship_from_org,
                                        attribute1,
                                        unit_selling_price,
                                        unit_list_price,
                                        calculate_price_flag,
                                        subinventory,
                                        org_id,
                                        blanket_number,
                                        customer_item_id_type,
                                        customer_item_name,
                                        latest_acceptable_date,
                                        attribute14    -- Added for CCR0009629
                                                   )
            SELECT DISTINCT order_source_id, orig_sys_document_ref, orig_sys_line_ref,
                            inventory_item, inventory_item_id, ordered_quantity,
                            line_request_date, created_by, SYSDATE,
                            last_updated_by, SYSDATE, ship_from_org,
                            fnd_date.date_to_canonical (line_cancel_date), unit_selling_price, unit_selling_price,
                            NVL2 (unit_selling_price, 'P', 'Y'), subinventory, org_id,
                            sales_agreement, NVL2 (customer_item, 'CUST', NULL), NVL2 (customer_item, customer_item, NULL),
                            line_cancel_date, line_vas_code -- Added for CCR0009629
              FROM xxd_ont_multi_order_upload_t
             WHERE     org_id = gn_org_id
                   AND status = 'N'
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE);

        -- Start changes for CCR0009886
        UPDATE xxd_ont_multi_order_upload_t
           SET status   = 'I'
         WHERE     org_id = gn_org_id
               AND status = 'N'
               AND created_by = gn_user_id
               AND TRUNC (creation_date) = TRUNC (SYSDATE);

        -- End changes for CCR0009886

        --Initialize
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', gn_org_id);
        fnd_global.apps_initialize (gn_user_id,
                                    fnd_global.resp_id,
                                    gn_application_id);

        -- Start changes for CCR0006653
        -- Submit Order Import
        /*ln_request_id :=
           apps.fnd_request.submit_request (application   => 'ONT',
                                            program       => 'OEOIMP',
                                            argument1     => gn_org_id, -- Operating Unit
                                            argument2     => gn_order_source_id, -- Order Source
                                            argument3     => NULL, -- Order Reference
                                            argument4     => NULL, -- Operation Code
                                            argument5     => 'N', -- Validate Only?
                                            argument6     => NULL, -- Debug Level
                                            argument7     => 4,     -- Instances
                                            argument8     => NULL, -- Sold To Org Id
                                            argument9     => NULL, -- Sold To Org
                                            argument10    => NULL, -- Change Sequence
                                            argument11    => NULL, -- Enable Single Line Queue for Instances
                                            argument12    => 'N', -- Trim Trailing Blanks
                                            argument13    => NULL, -- Process Orders With No Org Specified
                                            argument14    => NULL, -- Default Operating Unit
                                            argument15    => 'Y'); -- Validate Descriptive Flexfield

        IF NVL (ln_request_id, 0) = 0
        THEN
           lc_err_message := 'Error in Order Import Program';
        END IF;

        -- Update Status
        UPDATE xxd_ont_multi_order_upload_t
           SET status = NVL2 (lc_err_message, 'E', 'S'),
               error_message = lc_err_message
         WHERE     org_id = gn_org_id
               AND status = 'N'
               AND created_by = gn_user_id
               AND TRUNC (creation_date) = TRUNC (SYSDATE);
     -- Delete Processed Records
     /*DELETE xxd_ont_multi_order_upload_t xmou
      WHERE EXISTS
               (SELECT 1
                  FROM oe_order_headers_all ooha
                 WHERE ooha.orig_sys_document_ref =
                          xmou.orig_sys_document_ref);*/

        ln_request_id   :=
            apps.fnd_request.submit_request (application => 'XXDO', program => 'XXDOEOIMPWEBADI', argument1 => NULL
                                             ,        -- Orig Sys Document Ref
                                               argument2 => gn_user_id); -- Added for CCR0009886

        IF NVL (ln_request_id, 0) = 0
        THEN
            lc_err_message   :=
                'Error in Deckers Order Import - Pre Validation for WebADI Program';
        END IF;
    -- End changes for CCR0006653
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (-20000, SQLERRM);
    END import_data_prc;

    -- Start changes for CCR0006653
    PROCEDURE pre_validation_prc (p_errbuf IN OUT VARCHAR2, p_retcode IN OUT VARCHAR2, p_orig_sys_document_ref IN oe_lines_iface_all.orig_sys_document_ref%TYPE
                                  , p_user_id IN fnd_user.user_id%TYPE) -- Added for CCR0009886
    AS
        ln_request_id    NUMBER;
        ln_instances     NUMBER;                       -- Added for CCR0008870
        lc_phase         VARCHAR2 (50);
        lc_status        VARCHAR2 (50);
        lc_dev_phase     VARCHAR2 (50);
        lc_dev_status    VARCHAR2 (50);
        lc_err_message   VARCHAR2 (50);
        lc_proceed       VARCHAR2 (1) := 'Y';
        lb_req_status    BOOLEAN;
    BEGIN
        FOR i
            IN (SELECT fcr.request_id
                  FROM fnd_concurrent_requests fcr, fnd_concurrent_programs fcp
                 WHERE     fcp.concurrent_program_id =
                           fcr.concurrent_program_id
                       AND ((fcp.concurrent_program_name = 'OEOIMP' AND fcr.argument1 = TO_CHAR (gn_org_id) AND fcr.argument2 = TO_CHAR (gn_order_source_id)) OR (fcp.concurrent_program_name = 'XXDOEOIMPWEBADI' AND fcr.argument1 = p_orig_sys_document_ref AND fcr.request_id < fnd_global.conc_request_id))
                       AND fcr.phase_code IN ('P', 'R')
                       AND (                               -- Single SO Upload
                               (    p_orig_sys_document_ref IS NOT NULL
                                AND EXISTS
                                        (SELECT 1
                                           FROM oe_headers_iface_all ohia, xxdo.xxd_om_order_upload_gt xoou
                                          WHERE     ohia.orig_sys_document_ref =
                                                    xoou.orig_sys_document_ref
                                                AND ohia.blanket_number =
                                                    xoou.sa_number
                                                AND ohia.org_id = gn_org_id
                                                AND ohia.order_source_id =
                                                    gn_order_source_id
                                                AND ohia.operation_code =
                                                    'INSERT'
                                                AND NVL (ohia.error_flag,
                                                         'N') =
                                                    'N'))
                            -- Multi SO Upload
                            OR (    p_orig_sys_document_ref IS NULL
                                AND EXISTS
                                        (SELECT 1
                                           FROM oe_headers_iface_all ohia, xxd_ont_multi_order_upload_t xomo
                                          WHERE     ohia.orig_sys_document_ref =
                                                    xomo.orig_sys_document_ref
                                                AND ohia.org_id = xomo.org_id
                                                AND ohia.blanket_number =
                                                    xomo.sales_agreement
                                                AND xomo.status = 'I' -- Changed from N to I for CCR0009886
                                                AND ohia.org_id = gn_org_id
                                                AND ohia.order_source_id =
                                                    gn_order_source_id
                                                AND ohia.operation_code =
                                                    'INSERT'
                                                AND NVL (ohia.error_flag,
                                                         'N') =
                                                    'N'))))
        LOOP
            LOOP
                lc_proceed   := 'N';
                lb_req_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => i.request_id,
                        interval     => 5,
                        max_wait     => 300,
                        phase        => lc_phase,
                        status       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_err_message);
                EXIT WHEN UPPER (lc_phase) = 'COMPLETED';
            END LOOP;

            lc_proceed   := 'Y';
        END LOOP;

        IF lc_proceed = 'Y'
        THEN
            -- Start changes for CCR0008870
            BEGIN
                SELECT TO_NUMBER (description)
                  INTO ln_instances
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXD_SO_WEBADI_OI_INSTANCES'
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_code = TO_CHAR (gn_org_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_instances   := 1;
            END;

            -- End changes for CCR0008870
            ln_request_id   :=
                apps.fnd_request.submit_request (
                    application   => 'ONT',
                    program       => 'OEOIMP',
                    argument1     => gn_org_id,              -- Operating Unit
                    argument2     => gn_order_source_id,       -- Order Source
                    argument3     => NVL (p_orig_sys_document_ref, NULL), -- Order Reference
                    argument4     => NULL,                   -- Operation Code
                    argument5     => 'N',                    -- Validate Only?
                    argument6     => NULL,                      -- Debug Level
                    -- Start changes for CCR0008870
                    --argument7     => 1,                           -- Instances
                    argument7     => ln_instances,                -- Instances
                    -- End changes for CCR0008870
                    argument8     => NULL,                   -- Sold To Org Id
                    argument9     => NULL,                      -- Sold To Org
                    argument10    => NULL,                  -- Change Sequence
                    argument11    => NULL, -- Enable Single Line Queue for Instances
                    argument12    => 'N',              -- Trim Trailing Blanks
                    argument13    => NULL, -- Process Orders With No Org Specified
                    argument14    => NULL,           -- Default Operating Unit
                    argument15    => 'Y');   -- Validate Descriptive Flexfield

            IF NVL (ln_request_id, 0) = 0
            THEN
                lc_err_message   :=
                    'Error in Deckers Order Import - Pre Validation for WebADI Program';
            END IF;

            -- Delete Single Sales Order record
            DELETE FROM xxdo.xxd_om_order_upload_gt
                  WHERE orig_sys_document_ref = p_orig_sys_document_ref;

            -- Update Multi Sales Order Program Status
            UPDATE xxd_ont_multi_order_upload_t
               SET status = NVL2 (lc_err_message, 'E', 'S'), error_message = lc_err_message
             WHERE     org_id = gn_org_id
                   AND status = 'I'      -- Changed from N to I for CCR0009886
                   AND created_by = gn_user_id
                   AND TRUNC (creation_date) = TRUNC (SYSDATE);

            -- Start changes for CCR0007557
            DELETE xxd_ont_multi_order_upload_t
             WHERE creation_date <= SYSDATE - 30;
        -- End changes for CCR0007557
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Exception: ' || SQLERRM);
    END pre_validation_prc;
-- End changes for CCR0006653
BEGIN
    -- Derive Order Source ID
    SELECT order_source_id
      INTO gn_order_source_id
      FROM oe_order_sources
     WHERE enabled_flag = 'Y' AND name = 'Order Upload';

    SELECT application_id
      INTO gn_application_id
      FROM fnd_responsibility_vl
     WHERE responsibility_id = fnd_global.resp_id;
EXCEPTION
    WHEN OTHERS
    THEN
        gn_order_source_id   := -1;
END xxd_ont_multi_order_upload_pkg;
/
