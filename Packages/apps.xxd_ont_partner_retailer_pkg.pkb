--
-- XXD_ONT_PARTNER_RETAILER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_PARTNER_RETAILER_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_PARTNER_RETAILER_PKG
    * Design       : This package will be used for Partner Retailer Integration
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 09-Sep-2020  1.0        Viswanathan Pandian     Initial Version
    -- 09-Feb-2021  2.0        Shivanshu Talwar       Changes as part of CCR CCR0009163
    -- 23-Nov-2021  2.1        Archana Kotha          Changes as part of CCR CCR0009671
    -- 18-Jan-2022  2.2        Archana Kotha          Changes as part of CCR CCR0009807
 -- 19- May-2022 3.0     Geeta Rawat     HOKA partner changes (Traffic )
 -- 09-Aug-2022  3.1        Archana Kotha          Changes as part of CCR CCR0010141
    ******************************************************************************************/
    FUNCTION get_inv_org_id (p_org_code IN VARCHAR2)
        RETURN NUMBER
    AS
        ln_inv_org_id   NUMBER;
    BEGIN
        SELECT organization_id
          INTO ln_inv_org_id
          FROM mtl_parameters
         WHERE organization_code = p_org_code;

        RETURN ln_inv_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_inv_org_id;

    FUNCTION check_date (p_date IN VARCHAR2, p_process IN VARCHAR2)
        RETURN VARCHAR2
    AS
        lc_status   VARCHAR2 (1);
        ln_months   NUMBER := 6;                       --as part of CCR0009807
    BEGIN
        lc_status   := 'S';

        --added as part of CCR0009807
        BEGIN
            SELECT TO_NUMBER (tag)
              INTO ln_months
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'XXD_CHINA_PARTNER_DATE_VAL'
                   AND meaning = 'UGG';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_months   := 6;
        END;

        IF p_date IS NULL
        THEN
            lc_status   := 'E';
        ELSIF p_date IS NOT NULL AND p_process <> 'Historical'
        THEN
            IF    TO_DATE (p_date, 'YYYYMMDD') > TRUNC (SYSDATE)
               OR TO_DATE (p_date, 'YYYYMMDD') <
                  --   TRUNC (ADD_MONTHS (SYSDATE, -6)) --Commenetd as part of CCR0009807
                  TRUNC (ADD_MONTHS (SYSDATE, -ln_months)) --as part of CCR0009807
            THEN
                lc_status   := 'E';
            END IF;
        END IF;

        RETURN lc_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'E';
    END check_date;

    FUNCTION check_traffic_date (p_date IN VARCHAR2, p_process IN VARCHAR2)
        RETURN VARCHAR2
    AS
        lc_status   VARCHAR2 (1);
        ln_months   NUMBER := 6;
    BEGIN
        lc_status   := 'S';

        BEGIN
            SELECT TO_NUMBER (tag)
              INTO ln_months
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'XXD_CHINA_PARTNER_DATE_VAL'
                   AND meaning = 'TRAFFIC';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_months   := 6;
        END;

        IF p_date IS NULL
        THEN
            lc_status   := 'E';
        ELSIF p_date IS NOT NULL AND p_process <> 'Historical'
        THEN
            -- IF    TO_DATE (p_date, 'YYYYMMDD') >= TRUNC (SYSDATE)
            IF    TO_DATE (p_date, 'YYYYMMDD') > TRUNC (SYSDATE) --Removed equalto condition as part of CCR0010141
               OR TO_DATE (p_date, 'YYYYMMDD') <
                  TRUNC (ADD_MONTHS (SYSDATE, -ln_months))
            THEN
                lc_status   := 'E';
            END IF;
        END IF;

        RETURN lc_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'E';
    END check_traffic_date;

    PROCEDURE derive_list_price (p_batch_id IN NUMBER)
    AS
        CURSOR get_list_header IS
            SELECT list_header_id
              FROM qp_list_headers_v
             WHERE name = 'CN-MASTER-WHOLESALE-CNY';

        CURSOR get_item_details (p_item_number      IN VARCHAR2,
                                 p_mst_inv_org_id   IN NUMBER)
        IS
            SELECT xciv.inventory_item_id,
                   (SELECT mcb.category_id
                      FROM mtl_categories_b mcb
                     WHERE mcb.segment1 = xciv.style_desc) category_id
              FROM xxd_common_items_v xciv
             WHERE     xciv.organization_id = p_mst_inv_org_id
                   AND xciv.item_number = p_item_number;

        CURSOR get_item_list_price (p_list_header_id      IN NUMBER,
                                    p_inventory_item_id   IN NUMBER)
        IS
            SELECT operand
              FROM qp_list_lines_v
             WHERE     list_header_id = p_list_header_id
                   AND product_attribute = 'PRICING_ATTRIBUTE1'
                   AND product_attr_value = TO_CHAR (p_inventory_item_id)
                   AND NVL (end_date_active, TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE);

        CURSOR get_category_list_price (p_list_header_id   IN NUMBER,
                                        p_category_id      IN NUMBER)
        IS
            SELECT operand
              FROM qp_list_lines_v
             WHERE     list_header_id = p_list_header_id
                   AND product_attribute = 'PRICING_ATTRIBUTE2'
                   AND product_attr_value = TO_CHAR (p_category_id)
                   AND NVL (end_date_active, TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE);

        ln_list_price          NUMBER;
        ln_list_header_id      NUMBER;
        ln_inventory_item_id   NUMBER;
        ln_category_id         NUMBER;
        ln_mst_inv_org_id      NUMBER := get_inv_org_id ('MST');
        lc_error_message       VARCHAR2 (4000);
    BEGIN
        OPEN get_list_header;

        FETCH get_list_header INTO ln_list_header_id;

        CLOSE get_list_header;

        FOR stg_dtls
            IN (SELECT DISTINCT
                       style_number || '-' || color || '-' || item_size item_number
                  FROM xxdo.xxd_ont_partner_retailer_stg_t
                 WHERE overall_status = 'N' AND batch_id = p_batch_id)
        LOOP
            ln_inventory_item_id   := NULL;
            ln_category_id         := NULL;
            ln_list_price          := NULL;

            OPEN get_item_details (stg_dtls.item_number, ln_mst_inv_org_id);

            FETCH get_item_details INTO ln_inventory_item_id, ln_category_id;

            CLOSE get_item_details;

            -- Derive SKU List Pirce
            OPEN get_item_list_price (ln_list_header_id,
                                      ln_inventory_item_id);

            FETCH get_item_list_price INTO ln_list_price;

            CLOSE get_item_list_price;

            IF ln_list_price IS NULL
            THEN
                -- Derive Category List Price
                OPEN get_category_list_price (ln_list_header_id,
                                              ln_category_id);

                FETCH get_category_list_price INTO ln_list_price;

                CLOSE get_category_list_price;
            END IF;

            IF ln_list_price IS NOT NULL
            THEN
                UPDATE xxd_ont_partner_retailer_stg_t
                   SET number_attribute1   = ln_list_price
                 WHERE     style_number || '-' || color || '-' || item_size =
                           stg_dtls.item_number
                       AND overall_status = 'N'
                       AND batch_id = p_batch_id;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_partner_retailer_stg_t
               SET overall_status = 'E', error_message = lc_error_message
             WHERE batch_id = p_batch_id;
    END derive_list_price;



    PROCEDURE derive_inv_list_price (p_batch_id IN NUMBER)
    AS
        CURSOR get_list_header IS
            SELECT list_header_id
              FROM qp_list_headers_v
             WHERE name = 'CN-MASTER-WHOLESALE-CNY';

        CURSOR get_item_details (p_item_number      IN VARCHAR2,
                                 p_mst_inv_org_id   IN NUMBER)
        IS
            SELECT xciv.inventory_item_id,
                   (SELECT mcb.category_id
                      FROM mtl_categories_b mcb
                     WHERE mcb.segment1 = xciv.style_desc) category_id
              FROM xxd_common_items_v xciv
             WHERE     xciv.organization_id = p_mst_inv_org_id
                   AND xciv.item_number = p_item_number;

        CURSOR get_item_list_price (p_list_header_id      IN NUMBER,
                                    p_inventory_item_id   IN NUMBER)
        IS
            SELECT operand
              FROM qp_list_lines_v
             WHERE     list_header_id = p_list_header_id
                   AND product_attribute = 'PRICING_ATTRIBUTE1'
                   AND product_attr_value = TO_CHAR (p_inventory_item_id)
                   AND NVL (end_date_active, TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE);

        CURSOR get_category_list_price (p_list_header_id   IN NUMBER,
                                        p_category_id      IN NUMBER)
        IS
            SELECT operand
              FROM qp_list_lines_v
             WHERE     list_header_id = p_list_header_id
                   AND product_attribute = 'PRICING_ATTRIBUTE2'
                   AND product_attr_value = TO_CHAR (p_category_id)
                   AND NVL (end_date_active, TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE);

        ln_list_price          NUMBER;
        ln_list_header_id      NUMBER;
        ln_inventory_item_id   NUMBER;
        ln_category_id         NUMBER;
        ln_mst_inv_org_id      NUMBER := get_inv_org_id ('MST');
        lc_error_message       VARCHAR2 (4000);
    BEGIN
        OPEN get_list_header;

        FETCH get_list_header INTO ln_list_header_id;

        CLOSE get_list_header;

        FOR stg_dtls
            IN (SELECT DISTINCT
                       style_number || '-' || color || '-' || item_size item_number
                  FROM xxdo.XXD_PARTNER_RET_INV_STG
                 WHERE overall_status = 'N' AND batch_id = p_batch_id)
        LOOP
            ln_inventory_item_id   := NULL;
            ln_category_id         := NULL;
            ln_list_price          := NULL;

            OPEN get_item_details (stg_dtls.item_number, ln_mst_inv_org_id);

            FETCH get_item_details INTO ln_inventory_item_id, ln_category_id;

            CLOSE get_item_details;

            -- Derive SKU List Pirce
            OPEN get_item_list_price (ln_list_header_id,
                                      ln_inventory_item_id);

            FETCH get_item_list_price INTO ln_list_price;

            CLOSE get_item_list_price;

            IF ln_list_price IS NULL
            THEN
                -- Derive Category List Price
                OPEN get_category_list_price (ln_list_header_id,
                                              ln_category_id);

                FETCH get_category_list_price INTO ln_list_price;

                CLOSE get_category_list_price;
            END IF;

            IF ln_list_price IS NOT NULL
            THEN
                UPDATE XXD_PARTNER_RET_INV_STG
                   SET number_attribute1   = ln_list_price
                 WHERE -- style_number || '-' || color || '-' || item_size =stg_dtls.item_number
                           SKU = stg_dtls.item_number
                       AND overall_status = 'N'
                       AND batch_id = p_batch_id;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE XXD_PARTNER_RET_INV_STG
               SET overall_status = 'E', error_message = lc_error_message
             WHERE batch_id = p_batch_id;
    END derive_inv_list_price;



    PROCEDURE derive_sale_list_price (p_batch_id IN NUMBER)
    AS
        CURSOR get_list_header IS
            SELECT list_header_id
              FROM qp_list_headers_v
             WHERE name = 'CN-MASTER-WHOLESALE-CNY';

        CURSOR get_item_details (p_item_number      IN VARCHAR2,
                                 p_mst_inv_org_id   IN NUMBER)
        IS
            SELECT xciv.inventory_item_id,
                   (SELECT mcb.category_id
                      FROM mtl_categories_b mcb
                     WHERE mcb.segment1 = xciv.style_desc) category_id
              FROM xxd_common_items_v xciv
             WHERE     xciv.organization_id = p_mst_inv_org_id
                   AND xciv.item_number = p_item_number;

        CURSOR get_item_list_price (p_list_header_id      IN NUMBER,
                                    p_inventory_item_id   IN NUMBER)
        IS
            SELECT operand
              FROM qp_list_lines_v
             WHERE     list_header_id = p_list_header_id
                   AND product_attribute = 'PRICING_ATTRIBUTE1'
                   AND product_attr_value = TO_CHAR (p_inventory_item_id)
                   AND NVL (end_date_active, TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE);

        CURSOR get_category_list_price (p_list_header_id   IN NUMBER,
                                        p_category_id      IN NUMBER)
        IS
            SELECT operand
              FROM qp_list_lines_v
             WHERE     list_header_id = p_list_header_id
                   AND product_attribute = 'PRICING_ATTRIBUTE2'
                   AND product_attr_value = TO_CHAR (p_category_id)
                   AND NVL (end_date_active, TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE);

        ln_list_price          NUMBER;
        ln_list_header_id      NUMBER;
        ln_inventory_item_id   NUMBER;
        ln_category_id         NUMBER;
        ln_mst_inv_org_id      NUMBER := get_inv_org_id ('MST');
        lc_error_message       VARCHAR2 (4000);
    BEGIN
        OPEN get_list_header;

        FETCH get_list_header INTO ln_list_header_id;

        CLOSE get_list_header;

        FOR stg_dtls
            IN (SELECT DISTINCT
                       style_number || '-' || color || '-' || item_size item_number
                  FROM xxdo.XXD_PARTNER_RET_SALE_STG
                 WHERE overall_status = 'N' AND batch_id = p_batch_id)
        LOOP
            ln_inventory_item_id   := NULL;
            ln_category_id         := NULL;
            ln_list_price          := NULL;

            OPEN get_item_details (stg_dtls.item_number, ln_mst_inv_org_id);

            FETCH get_item_details INTO ln_inventory_item_id, ln_category_id;

            CLOSE get_item_details;

            -- Derive SKU List Pirce
            OPEN get_item_list_price (ln_list_header_id,
                                      ln_inventory_item_id);

            FETCH get_item_list_price INTO ln_list_price;

            CLOSE get_item_list_price;

            IF ln_list_price IS NULL
            THEN
                -- Derive Category List Price
                OPEN get_category_list_price (ln_list_header_id,
                                              ln_category_id);

                FETCH get_category_list_price INTO ln_list_price;

                CLOSE get_category_list_price;
            END IF;

            IF ln_list_price IS NOT NULL
            THEN
                UPDATE XXD_PARTNER_RET_SALE_STG
                   SET number_attribute1   = ln_list_price
                 WHERE     SKU = stg_dtls.item_number
                       AND overall_status = 'N'
                       AND batch_id = p_batch_id;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE XXD_PARTNER_RET_SALE_STG
               SET overall_status = 'E', error_message = lc_error_message
             WHERE batch_id = p_batch_id;
    END derive_sale_list_price;

    PROCEDURE validate_data (p_batch_id IN NUMBER, p_process IN VARCHAR2)
    AS
        lc_account_number   VARCHAR2 (30);
        lc_party_name       VARCHAR2 (360);
        lc_store_type       VARCHAR2 (150);
        lc_error_message    VARCHAR2 (4000);
        lc_store_status     VARCHAR2 (1);
        lc_sku_status       VARCHAR2 (1);
        ln_exists           NUMBER;
        ln_ch3_inv_org_id   NUMBER := get_inv_org_id ('CH3');
    BEGIN
        -- Delete 30 days older records
        DELETE xxd_ont_partner_retailer_stg_t
         WHERE creation_date < SYSDATE - 30;

        -- Validate Store Details
        FOR store_rec
            IN (SELECT DISTINCT store_code, org_id
                  FROM xxd_ont_partner_retailer_stg_t
                 WHERE batch_id = p_batch_id AND overall_status = 'N')
        LOOP
            BEGIN
                lc_store_status     := 'S';
                lc_account_number   := NULL;
                lc_party_name       := NULL;
                lc_store_type       := NULL;

                SELECT hca.account_number, hzp.party_name, hcas.global_attribute15
                  INTO lc_account_number, lc_party_name, lc_store_type
                  FROM hz_cust_acct_sites_all hcas, hz_cust_accounts_all hca, hz_parties hzp
                 WHERE     hcas.cust_account_id = hca.cust_account_id
                       AND hca.party_id = hzp.party_id
                       AND hcas.attribute2 = store_rec.store_code
                       AND hcas.org_id = store_rec.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_store_status   := 'E';
            END;

            -- Update customer fields
            UPDATE xxd_ont_partner_retailer_stg_t
               SET store_status = lc_store_status, account_number = lc_account_number, party_name = lc_party_name,
                   store_type = lc_store_type
             WHERE     store_code = store_rec.store_code
                   AND store_status IS NULL
                   AND overall_status = 'N'
                   AND batch_id = p_batch_id;
        END LOOP;

        -- Validate SKU Details
        /*  FOR sku_rec IN (SELECT DISTINCT style_number, color, item_size
                            FROM xxd_ont_partner_retailer_stg_t
                           WHERE batch_id = p_batch_id AND overall_status = 'N')
          LOOP
            lc_sku_status := NULL;

           SELECT COUNT (1)
              INTO ln_exists
              FROM xxd_common_items_v
             WHERE     style_number = sku_rec.style_number
                   AND color_code = sku_rec.color
                   AND item_size = sku_rec.item_size
                   AND organization_id = ln_ch3_inv_org_id;

            IF ln_exists = 0
            THEN
              lc_sku_status := 'E';
            ELSE
              lc_sku_status := 'S';
            END IF;

            -- Update status
            UPDATE xxd_ont_partner_retailer_stg_t
               SET sku_status = lc_sku_status
             WHERE     style_number = sku_rec.style_number
                   AND color = sku_rec.color
                   AND item_size = sku_rec.item_size
                   AND sku_status IS NULL
                   AND overall_status = 'N'
                   AND batch_id = p_batch_id;
         -- END LOOP; */


        -- SKU Exists Update Status 'S'
        UPDATE xxd_ont_partner_retailer_stg_t retail_t
           SET sku_status   = 'S'
         WHERE     1 = 1
               AND EXISTS
                       (SELECT 1
                          FROM xxd_common_items_v ms
                         WHERE     style_number = retail_t.style_number
                               AND color_code = retail_t.color
                               AND item_size = retail_t.item_size
                               AND organization_id = ln_ch3_inv_org_id)
               AND sku_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        -- SKU Not Exists Update Status 'E'
        /*    UPDATE xxd_ont_partner_retailer_stg_t retail_t
                SET sku_status = 'E'
                WHERE   1=1 AND NOT EXISTS (SELECT 1 FROM xxd_common_items_v ms
                WHERE  style_number = retail_t.style_number
                 AND color_code = retail_t.color
                 AND item_size = retail_t.item_size
                 AND organization_id = ln_ch3_inv_org_id)
                 AND sku_status IS NULL
                 AND overall_status = 'N'
                 AND batch_id = p_batch_id;*/

        ---SKU Not Exists Update Status 'E'
        UPDATE xxd_ont_partner_retailer_stg_t retail_t
           SET sku_status   = 'E'
         WHERE     1 = 1
               AND sku_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;


        -- Update Inventory Date Status
        UPDATE xxd_ont_partner_retailer_stg_t
           SET date_status = xxd_ont_partner_retailer_pkg.check_date (inventory_date, p_process)
         WHERE     file_type = 'Inventory'
               AND date_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        -- Derive Deckers List Price
        derive_list_price (p_batch_id);

        -- Update Transaction Date Status
        UPDATE xxd_ont_partner_retailer_stg_t
           SET date_status = xxd_ont_partner_retailer_pkg.check_date (transaction_date, p_process)
         WHERE     file_type = 'Sales'
               AND date_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        -- Update all records to E, even if one row is in error
        UPDATE xxd_ont_partner_retailer_stg_t
           SET overall_status   = 'E'
         WHERE     EXISTS
                       (SELECT 1
                          FROM xxd_ont_partner_retailer_stg_t
                         WHERE     (store_status = 'E' OR sku_status = 'E' OR date_status = 'E')
                               AND overall_status = 'N'
                               AND batch_id = p_batch_id)
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        -- update as success if no errors
        UPDATE xxd_ont_partner_retailer_stg_t
           SET overall_status = 'S', store_status = 'S', sku_status = 'S',
               date_status = 'S'
         WHERE overall_status = 'N' AND batch_id = p_batch_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_partner_retailer_stg_t
               SET overall_status = 'E', error_message = lc_error_message
             WHERE batch_id = p_batch_id;
    END validate_data;

    PROCEDURE validate_inv_data (p_batch_id      IN     NUMBER,
                                 p_process       IN     VARCHAR2,
                                 p_error_count      OUT NUMBER) -- START As part Verion 2.0
    AS
        lc_account_number             VARCHAR2 (30);
        lc_party_name                 VARCHAR2 (360);
        lc_store_type                 VARCHAR2 (150);
        lc_error_message              VARCHAR2 (4000);
        lv_file_err_message           VARCHAR2 (4000);
        lc_store_status               VARCHAR2 (1);
        lc_sku_status                 VARCHAR2 (1);
        ln_exists                     NUMBER;
        ln_inv_error_cnt              NUMBER;
        ln_file_format                NUMBER;
        ln_blank_status               NUMBER;
        lc_blank_status_err_message   VARCHAR2 (4000);
        lc_store_name                 VARCHAR2 (2000); --Changes as part of CCR CCR0009671
        ln_ch3_inv_org_id             NUMBER := get_inv_org_id ('CH3');
    BEGIN
        -- Delete 30 days older records
        DELETE xxdo.XXD_PARTNER_RET_INV_STG
         WHERE creation_date < SYSDATE - 30;


        --validate the file format--
        SELECT COUNT (1)
          INTO ln_file_format
          FROM XXD_PARTNER_RET_INV_STG
         WHERE INVENTORY_DATE IS NOT NULL AND batch_id = p_batch_id;

        IF ln_file_format = 0
        THEN
            lv_file_err_message   := 'FILE FORMAT IS WRONG';

            BEGIN
                UPDATE XXD_PARTNER_RET_INV_STG
                   SET overall_status = 'E', FILE_FORMAT_STATUS = 'E', error_message = lv_file_err_message
                 WHERE batch_id = p_batch_id;
            END;
        ELSE
            UPDATE XXD_PARTNER_RET_INV_STG
               SET FILE_FORMAT_STATUS = 'S', BLANK_STATUS = 'S', --Changes as part of CCR CCR0009671
                                                                 PRICE_STATUS = 'S' --Changes as part of CCR CCR0009671
             WHERE batch_id = p_batch_id;
        END IF;

        --VALIDATE NULL OR BLANK   --Changes as part of CCR CCR0009671

        UPDATE xxdo.XXD_PARTNER_RET_INV_STG
           SET BLANK_STATUS   = 'E'
         WHERE     (STORE_CODE IS NULL OR STYLE_NUMBER IS NULL OR COLOR IS NULL OR ITEM_SIZE IS NULL OR CUSTOMER_LIST_PRICE IS NULL OR ONHAND_QUANTITY IS NULL OR INTRANSIT_QUANTITY IS NULL OR INVENTORY_DATE IS NULL)
               AND batch_id = p_batch_id;

        --VALIDATE CUSTOMER_LIST_PRICE VALUES IF >=0  --Changes as part of CCR CCR0009671

        UPDATE xxdo.XXD_PARTNER_RET_INV_STG
           SET PRICE_STATUS   = 'E'
         WHERE CUSTOMER_LIST_PRICE < 0 AND batch_id = p_batch_id;



        -- Validate Store Details
        FOR store_rec
            IN (SELECT DISTINCT store_code, org_id
                  FROM xxdo.XXD_PARTNER_RET_INV_STG
                 WHERE batch_id = p_batch_id AND overall_status = 'N')
        LOOP
            BEGIN
                lc_store_status     := 'S';
                lc_account_number   := NULL;
                lc_party_name       := NULL;
                lc_store_type       := NULL;
                lc_store_name       := NULL; --Changes as part of CCR CCR0009671

                SELECT hca.account_number, hzp.party_name, hcas.global_attribute15,
                       hcas.global_attribute14 --Changes as part of CCR CCR0009671
                  INTO lc_account_number, lc_party_name, lc_store_type, lc_store_name --Changes as part of CCR CCR0009671
                  FROM hz_cust_acct_sites_all hcas, hz_cust_accounts_all hca, hz_parties hzp
                 WHERE     hcas.cust_account_id = hca.cust_account_id
                       AND hca.party_id = hzp.party_id
                       AND hcas.STATUS = 'A'
                       AND hca.STATUS = 'A'
                       AND hzp.status = 'A' --Changes as part of CCR CCR0009671
                       AND hcas.attribute2 = store_rec.store_code
                       AND hcas.org_id = store_rec.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_store_status   := 'E';
            END;

            -- Update customer fields
            UPDATE xxdo.XXD_PARTNER_RET_INV_STG
               SET store_status = lc_store_status, account_number = lc_account_number, party_name = lc_party_name,
                   store_type = lc_store_type, store_name = lc_store_name --Changes as part of CCR CCR0009671
             WHERE     store_code = store_rec.store_code
                   AND store_status IS NULL
                   AND overall_status = 'N'
                   AND batch_id = p_batch_id;
        END LOOP;

        -- Update store status
        UPDATE XXDO.XXD_PARTNER_RET_INV_STG
           SET store_status   = 'E'
         WHERE     1 = 1
               AND store_code IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        -- Validate SKU Details
        /*  FOR sku_rec IN (SELECT DISTINCT style_number, color, item_size
                            FROM xxd_ont_partner_retailer_stg_t
                           WHERE batch_id = p_batch_id AND overall_status = 'N')
          LOOP
            lc_sku_status := NULL;

           SELECT COUNT (1)
              INTO ln_exists
              FROM xxd_common_items_v
             WHERE     style_number = sku_rec.style_number
                   AND color_code = sku_rec.color
                   AND item_size = sku_rec.item_size
                   AND organization_id = ln_ch3_inv_org_id;

            IF ln_exists = 0
            THEN
              lc_sku_status := 'E';
            ELSE
              lc_sku_status := 'S';
            END IF;

            -- Update status
            UPDATE xxd_ont_partner_retailer_stg_t
               SET sku_status = lc_sku_status
             WHERE     style_number = sku_rec.style_number
                   AND color = sku_rec.color
                   AND item_size = sku_rec.item_size
                   AND sku_status IS NULL
                   AND overall_status = 'N'
                   AND batch_id = p_batch_id;
         -- END LOOP; */


        -- SKU Exists Update Status 'S'
        UPDATE xxdo.XXD_PARTNER_RET_INV_STG retail_t
           SET sku_status   = 'S'
         WHERE     1 = 1
               AND EXISTS
                       (SELECT 1
                          FROM xxd_common_items_v ms
                         WHERE     style_number = retail_t.style_number
                               AND color_code = retail_t.color
                               AND item_size = retail_t.item_size
                               AND organization_id = ln_ch3_inv_org_id)
               AND sku_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        -- SKU Not Exists Update Status 'E'
        /*
           UPDATE xxdo.XXD_PARTNER_RET_INV_STG retail_t
               SET sku_status = 'E'
               WHERE   1=1 AND NOT EXISTS (SELECT 1 FROM xxd_common_items_v ms
               WHERE  style_number = retail_t.style_number
                AND color_code = retail_t.color
                AND item_size = retail_t.item_size
                AND organization_id = ln_ch3_inv_org_id)
                AND sku_status IS NULL
                AND overall_status = 'N'
                AND batch_id = p_batch_id; */


        -- SKU Not Exists Update Status 'E'
        UPDATE xxdo.XXD_PARTNER_RET_INV_STG retail_t
           SET sku_status   = 'E'
         WHERE     1 = 1
               AND sku_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;



        -- Update Inventory Date Status
        UPDATE xxdo.XXD_PARTNER_RET_INV_STG
           SET date_status = xxd_ont_partner_retailer_pkg.check_date (inventory_date, p_process)
         WHERE     1 = 1
               AND date_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;



        SELECT COUNT (1)
          INTO ln_inv_error_cnt
          FROM xxdo.XXD_PARTNER_RET_INV_STG
         WHERE     (store_status = 'E' OR sku_status = 'E' OR date_status = 'E' OR blank_status = 'E' --Changes as part of CCR CCR0009671
                                                                                                      OR price_status = 'E') --Changes as part of CCR CCR0009671
               AND batch_id = p_batch_id;

        -- Derive Deckers List Price

        IF ln_inv_error_cnt = 0
        THEN
            derive_inv_list_price (p_batch_id);
        END IF;



        -- Update Transaction Date Status
        /*
        UPDATE xxd_ont_partner_retailer_stg_t
           SET date_status =
                 xxd_ont_partner_retailer_pkg.check_date (transaction_date,
                                                          p_process)
         WHERE     file_type = 'Sales'
               AND date_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;*/


        -- Update all records to E, even if one row is in error
        UPDATE xxdo.XXD_PARTNER_RET_INV_STG
           SET overall_status   = 'E'
         WHERE     EXISTS
                       (SELECT 1
                          FROM xxdo.XXD_PARTNER_RET_INV_STG
                         WHERE     (store_status = 'E' OR sku_status = 'E' OR date_status = 'E' OR blank_status = 'E' --Changes as part of CCR CCR0009671
                                                                                                                      OR price_status = 'E') --Changes as part of CCR CCR0009671
                               AND overall_status = 'N'
                               AND batch_id = p_batch_id)
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        p_error_count   := SQL%ROWCOUNT;

        -- update as success if no errors
        UPDATE xxdo.XXD_PARTNER_RET_INV_STG
           SET overall_status = 'S', store_status = 'S', sku_status = 'S',
               date_status = 'S', blank_status = 'S', --Changes as part of CCR CCR0009671
                                                      price_status = 'S' --Changes as part of CCR CCR0009671
         WHERE overall_status = 'N' AND batch_id = p_batch_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE XXD_PARTNER_RET_INV_STG
               SET overall_status = 'E', error_message = lc_error_message
             WHERE batch_id = p_batch_id;
    END validate_inv_data;                           -- END As part Verion 2.0



    PROCEDURE validate_sales_data (p_batch_id IN NUMBER, p_process IN VARCHAR2, p_error_count OUT NUMBER) -- START As part Verion 2.0
    AS
        lc_account_number          VARCHAR2 (30);
        lc_party_name              VARCHAR2 (360);
        lc_store_type              VARCHAR2 (150);
        lc_error_message           VARCHAR2 (4000);
        lc_store_status            VARCHAR2 (1);
        lc_sku_status              VARCHAR2 (1);
        ln_exists                  NUMBER;
        ln_sale_error_cnt          NUMBER;
        ln_sale_file_format        NUMBER; --Changes as part of CCR CCR0009671
        lv_sale_file_err_message   VARCHAR2 (4000); --Changes as part of CCR CCR0009671
        lc_store_name              VARCHAR2 (2000);
        ln_ch3_inv_org_id          NUMBER := get_inv_org_id ('CH3');
    BEGIN
        -- Delete 30 days older records
        DELETE XXDO.XXD_PARTNER_RET_SALE_STG
         WHERE creation_date < SYSDATE - 30;

        --validate the file format  --Changes as part of CCR CCR0009671
        SELECT COUNT (1)
          INTO ln_sale_file_format
          FROM XXD_PARTNER_RET_SALE_STG
         WHERE DISCOUNT IS NOT NULL AND batch_id = p_batch_id;

        IF ln_sale_file_format = 0
        THEN
            lv_sale_file_err_message   := 'FILE FORMAT IS WRONG';

            BEGIN
                UPDATE XXD_PARTNER_RET_SALE_STG
                   SET overall_status = 'E', FILE_FORMAT_STATUS = 'E', error_message = lv_sale_file_err_message
                 WHERE batch_id = p_batch_id;
            END;
        ELSE
            UPDATE XXD_PARTNER_RET_SALE_STG
               SET FILE_FORMAT_STATUS = 'S', BLANK_STATUS = 'S', PRICE_STATUS = 'S'
             WHERE batch_id = p_batch_id;
        END IF;

        --VALIDATE NULL OR BLANK   --Changes as part of CCR CCR0009671
        UPDATE XXDO.XXD_PARTNER_RET_SALE_STG
           SET BLANK_STATUS   = 'E'
         WHERE     (FILE_FREQUENCY IS NULL OR STORE_CODE IS NULL OR TRANSACTION_DATE IS NULL OR TRANSACTION_NUM IS NULL OR STYLE_NUMBER IS NULL OR COLOR IS NULL OR ITEM_SIZE IS NULL OR SALES_QTY IS NULL OR UNIT_PRICE IS NULL OR CUSTOMER_LIST_PRICE IS NULL OR SALES_AMOUNT IS NULL OR DISCOUNT IS NULL)
               AND batch_id = p_batch_id;


        --VALIDATE UNIT PRICE AND CUSTOMER_LIST_PRICE VALUES IF >=0

        UPDATE XXDO.XXD_PARTNER_RET_SALE_STG
           SET PRICE_STATUS   = 'E'
         WHERE     (CUSTOMER_LIST_PRICE < 0 OR UNIT_PRICE < 0)
               AND batch_id = p_batch_id;

        -- Validate Store Details
        FOR store_rec
            IN (SELECT DISTINCT store_code, org_id
                  FROM XXDO.XXD_PARTNER_RET_SALE_STG
                 WHERE batch_id = p_batch_id AND overall_status = 'N')
        LOOP
            BEGIN
                lc_store_status     := 'S';
                lc_account_number   := NULL;
                lc_party_name       := NULL;
                lc_store_type       := NULL;
                lc_store_name       := NULL; --Changes as part of CCR CCR0009671

                SELECT hca.account_number, hzp.party_name, hcas.global_attribute15,
                       hcas.global_attribute14 --Changes as part of CCR CCR0009671
                  INTO lc_account_number, lc_party_name, lc_store_type, lc_store_name --Changes as part of CCR CCR0009671
                  FROM hz_cust_acct_sites_all hcas, hz_cust_accounts_all hca, hz_parties hzp
                 WHERE     hcas.cust_account_id = hca.cust_account_id
                       AND hca.party_id = hzp.party_id
                       AND hcas.STATUS = 'A'
                       AND hca.STATUS = 'A'
                       AND hzp.STATUS = 'A' --Changes as part of CCR CCR0009671
                       AND hcas.attribute2 = store_rec.store_code
                       AND hcas.org_id = store_rec.org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_store_status   := 'E';
            END;

            -- Update customer fields
            UPDATE XXDO.XXD_PARTNER_RET_SALE_STG
               SET store_status = lc_store_status, account_number = lc_account_number, party_name = lc_party_name,
                   store_type = lc_store_type, store_name = lc_store_name --Changes as part of CCR CCR0009671
             WHERE     store_code = store_rec.store_code
                   AND store_status IS NULL
                   AND overall_status = 'N'
                   AND batch_id = p_batch_id;
        END LOOP;


        -- Update store status
        UPDATE XXDO.XXD_PARTNER_RET_SALE_STG
           SET store_status   = 'E'
         WHERE     1 = 1
               AND store_code IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        -- Validate SKU Details
        /*  FOR sku_rec IN (SELECT DISTINCT style_number, color, item_size
                            FROM xxd_ont_partner_retailer_stg_t
                           WHERE batch_id = p_batch_id AND overall_status = 'N')
          LOOP
            lc_sku_status := NULL;

           SELECT COUNT (1)
              INTO ln_exists
              FROM xxd_common_items_v
             WHERE     style_number = sku_rec.style_number
                   AND color_code = sku_rec.color
                   AND item_size = sku_rec.item_size
                   AND organization_id = ln_ch3_inv_org_id;

            IF ln_exists = 0
            THEN
              lc_sku_status := 'E';
            ELSE
              lc_sku_status := 'S';
            END IF;

            -- Update status
            UPDATE xxd_ont_partner_retailer_stg_t
               SET sku_status = lc_sku_status
             WHERE     style_number = sku_rec.style_number
                   AND color = sku_rec.color
                   AND item_size = sku_rec.item_size
                   AND sku_status IS NULL
                   AND overall_status = 'N'
                   AND batch_id = p_batch_id;
         -- END LOOP; */


        -- SKU Exists Update Status 'S'
        UPDATE XXDO.XXD_PARTNER_RET_SALE_STG retail_t
           SET sku_status   = 'S'
         WHERE     1 = 1
               AND EXISTS
                       (SELECT 1
                          FROM xxd_common_items_v ms
                         WHERE     style_number = retail_t.style_number
                               AND color_code = retail_t.color
                               AND item_size = retail_t.item_size
                               AND organization_id = ln_ch3_inv_org_id)
               AND sku_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        -- SKU Not Exists Update Status 'E'
        /*
           UPDATE  XXDO.XXD_PARTNER_RET_SALE_STG retail_t
               SET sku_status = 'E'
               WHERE   1=1 AND NOT EXISTS (SELECT 1 FROM xxd_common_items_v ms
               WHERE  style_number = retail_t.style_number
                AND color_code = retail_t.color
                AND item_size = retail_t.item_size
                AND organization_id = ln_ch3_inv_org_id)
                AND sku_status IS NULL
                AND overall_status = 'N'
                AND batch_id = p_batch_id;*/

        -- SKU Not Exists Update Status 'E'
        UPDATE XXDO.XXD_PARTNER_RET_SALE_STG retail_t
           SET sku_status   = 'E'
         WHERE     1 = 1
               AND sku_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;


        -- Update Inventory Date Status
        /* UPDATE  XXDO.XXD_PARTNER_RET_SALE_STG
            SET date_status =
                  xxd_ont_partner_retailer_pkg.check_date (inventory_date,
                                                           p_process)
          WHERE     file_type = 'Inventory'
                AND date_status IS NULL
                AND overall_status = 'N'
                AND batch_id = p_batch_id;*/


        -- Update Transaction Date Status
        UPDATE XXDO.XXD_PARTNER_RET_SALE_STG
           SET date_status = xxd_ont_partner_retailer_pkg.check_date (transaction_date, p_process)
         WHERE     1 = 1
               AND date_status IS NULL
               AND overall_status = 'N'
               AND batch_id = p_batch_id;


        -- Update File Frequency Status
        UPDATE XXDO.XXD_PARTNER_RET_SALE_STG
           SET file_frequency_status   = 'E'
         WHERE    FILE_FREQUENCY NOT IN ('Daily', 'Monthly')
               OR FILE_FREQUENCY IS NULL AND batch_id = p_batch_id;



        SELECT COUNT (1)
          INTO ln_sale_error_cnt
          FROM XXDO.XXD_PARTNER_RET_SALE_STG
         WHERE     (store_status = 'E' OR sku_status = 'E' OR date_status = 'E' OR file_frequency_status = 'E' OR blank_status = 'E' --Changes as part of CCR CCR0009671
                                                                                                                                     OR price_status = 'E') --Changes as part of CCR CCR0009671
               AND batch_id = p_batch_id;

        IF ln_sale_error_cnt = 0
        THEN
            -- Derive Deckers List Price
            derive_sale_list_price (p_batch_id);
        END IF;


        -- Update all records to E, even if one row is in error
        UPDATE XXDO.XXD_PARTNER_RET_SALE_STG
           SET overall_status   = 'E'
         WHERE     EXISTS
                       (SELECT 1
                          FROM XXDO.XXD_PARTNER_RET_SALE_STG
                         WHERE     (store_status = 'E' OR sku_status = 'E' OR date_status = 'E' OR file_frequency_status = 'E' OR blank_status = 'E' --Changes as part of CCR CCR0009671
                                                                                                                                                     OR price_status = 'E') --Changes as part of CCR CCR0009671
                               AND overall_status = 'N'
                               AND batch_id = p_batch_id)
               AND overall_status = 'N'
               AND batch_id = p_batch_id;

        p_error_count   := SQL%ROWCOUNT;

        -- update as success if no errors
        UPDATE XXDO.XXD_PARTNER_RET_SALE_STG
           SET overall_status = 'S', store_status = 'S', sku_status = 'S',
               date_status = 'S', file_format_status = 'S', file_frequency_status = 'S',
               blank_status = 'S',         --Changes as part of CCR CCR0009671
                                   price_status = 'S' --Changes as part of CCR CCR0009671
         WHERE overall_status = 'N' AND batch_id = p_batch_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE XXDO.XXD_PARTNER_RET_SALE_STG
               SET overall_status = 'E', error_message = lc_error_message
             WHERE batch_id = p_batch_id;
    END validate_sales_data;                         -- END As part Verion 2.0

    PROCEDURE validate_traffic_data (p_batch_id IN NUMBER, p_process IN VARCHAR2, p_error_count OUT NUMBER)
    AS
        lc_store_type                 VARCHAR2 (100);
        lc_store_name                 VARCHAR2 (250);
        LC_CUSTOMER_NAME              VARCHAR2 (250);
        lc_CITY_NAME                  VARCHAR2 (250);
        lc_PROVINCE_NAME              VARCHAR2 (250);
        lc_REGION_NAME                VARCHAR2 (250);
        lc_CHANNEL_NAME               VARCHAR2 (250);
        lc_store_status               VARCHAR2 (1);
        lc_error_message              VARCHAR2 (3000);
        ln_traffic_error_cnt          NUMBER; --Changes as part of CCR CCR0010141
        ln_traffic_file_format        NUMBER; --Changes as part of CCR CCR0010141
        lv_traffic_file_err_message   VARCHAR2 (4000); --Changes as part of CCR CCR0010141
    BEGIN
        --delete old data
        DELETE FROM xxdo.XXD_PARTNER_RET_TRAFFIC_STG
              WHERE creation_Date < SYSDATE - 30;

        --validate the traffic file format
        SELECT COUNT (1)
          INTO ln_traffic_file_format
          FROM xxdo.XXD_PARTNER_RET_TRAFFIC_STG
         WHERE TRAFFIC IS NOT NULL AND batch_id = p_batch_id;

        IF ln_traffic_file_format = 0
        THEN
            lv_traffic_file_err_message   := 'TRAFFIC FILE FORMAT IS WRONG';

            BEGIN
                UPDATE XXDO.XXD_PARTNER_RET_TRAFFIC_STG
                   SET overall_status = 'E', FILE_FORMAT_STATUS = 'E', error_message = lv_traffic_file_err_message
                 WHERE batch_id = p_batch_id;
            END;
        ELSE
            UPDATE XXDO.XXD_PARTNER_RET_TRAFFIC_STG
               SET FILE_FORMAT_STATUS   = 'S'
             --BLANK_STATUS = 'S',
             WHERE batch_id = p_batch_id;
        END IF;

        --VALIDATE NULL OR BLANK   ---Changes as part of CCR CCR0010141
        /*UPDATE XXDO.XXD_PARTNER_RET_TRAFFIC_STG
           SET BLANK_STATUS = 'E'
         WHERE     (   BRAND IS NULL
                    OR STORE_CODE IS NULL
                    OR RECORD_DATE IS NULL
                    OR TRAFFIC IS NULL
                    )
               AND batch_id = p_batch_id;*/

        -- Check traffic length Update Status 'S'
        UPDATE xxdo.XXD_PARTNER_RET_TRAFFIC_STG ---Changes as part of CCR CCR0010141
           SET traffic_status   = 'S'
         WHERE     1 = 1
               AND traffic BETWEEN 0 AND 9999
               AND overall_status = 'N'
               AND batch_id = p_batch_id;


        ---Check traffic length Update status 'E'
        UPDATE xxdo.XXD_PARTNER_RET_TRAFFIC_STG
           SET traffic_status   = 'E'
         WHERE     (traffic > 9999 OR traffic < 0 OR traffic IS NULL)
               AND OVERALL_STATUS = 'N'
               AND batch_id = p_batch_id;


        --Check space in store code
        UPDATE xxdo.XXD_PARTNER_RET_TRAFFIC_STG
           SET store_status   = 'E'
         WHERE     (STORE_CODE LIKE '%' || CHR (32) || '%' OR store_code IS NULL)
               AND OVERALL_STATUS = 'N'
               AND batch_id = p_batch_id;

        --Validate storecode
        FOR store_rec
            IN (SELECT DISTINCT store_code
                  FROM XXDO.XXD_PARTNER_RET_TRAFFIC_STG
                 WHERE OVERALL_STATUS = 'N' AND batch_id = p_batch_id)
        LOOP
            BEGIN
                lc_store_status   := 'S';

                SELECT hcas.global_attribute14 store_name, hcas.global_attribute15 store_type, hzp.party_name customer_name,
                       loc.city city, loc.province province, loc.county region,
                       'WHOLESALE' channel
                  INTO lc_store_name, lc_store_type, lc_customer_name, lc_city_name,
                                    lc_province_name, lc_region_name, lc_channel_name
                  FROM hz_cust_acct_sites_all hcas, hz_cust_accounts_all hca, hz_parties hzp,
                       apps.hz_party_sites hps, apps.hz_locations loc
                 WHERE     hcas.cust_account_id = hca.cust_account_id
                       AND hca.party_id = hzp.party_id
                       AND hcas.status = 'A'
                       AND hca.status = 'A'
                       AND hzp.status = 'A'
                       AND hcas.attribute2 = store_rec.store_code
                       AND hps.location_id = loc.location_id
                       AND hps.party_id = hzp.party_id
                       AND hps.party_site_id = hcas.party_site_id
                       AND UPPER (hcas.global_attribute15) <> 'WAREHOUSE';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lc_store_status   := 'E';
                WHEN OTHERS
                THEN
                    lc_store_status   := 'E';
            END;

            --Update customer fields
            UPDATE XXDO.XXD_PARTNER_RET_TRAFFIC_STG
               SET store_name = lc_store_name, store_status = lc_store_status, customer_name = lc_customer_name,
                   city_name = lc_city_name, province_name = lc_province_name, region = lc_region_name,
                   channel = lc_channel_name
             WHERE     store_code = store_rec.store_code
                   AND overall_status = 'N'
                   AND batch_id = p_batch_id;
        END LOOP;


        --Validate record_date
        /*        UPDATE xxdo.XXD_PARTNER_RET_TRAFFIC_STG
                   SET recorddate_status = 'E', overall_status = 'E'
                 WHERE    TO_DATE (record_date, 'YYYYMMDD') < TRUNC (SYSDATE) - 180
                       OR     TO_DATE (record_date, 'YYYYMMDD') >= TRUNC (SYSDATE)
                          AND OVERALL_STATUS = 'N' AND batch_id = p_batch_id;
        */

        UPDATE xxdo.XXD_PARTNER_RET_TRAFFIC_STG
           SET recorddate_status = xxd_ont_partner_retailer_pkg.check_traffic_date (record_date, p_process)
         --overall_status = xxd_ont_partner_retailer_pkg.check_traffic_date (record_date,p_process) ---Changes as part of CCR CCR0010141
         WHERE overall_status = 'N' AND batch_id = p_batch_id;

        -- Validate brand Update Status 'S'
        UPDATE xxdo.XXD_PARTNER_RET_TRAFFIC_STG ---Changes as part of CCR CCR0010141
           SET brand_status   = 'S'
         WHERE     1 = 1
               AND UPPER (brand) = 'HOKA'
               AND overall_status = 'N'
               AND batch_id = p_batch_id;


        --Validate brand Update Status 'E'
        UPDATE xxdo.XXD_PARTNER_RET_TRAFFIC_STG
           SET brand_status   = 'E'
         WHERE     (UPPER (brand) <> 'HOKA' OR brand IS NULL)
               AND overall_status = 'N'
               AND batch_id = p_batch_id;


        --Update overall error remaining records
        UPDATE xxdo.XXD_PARTNER_RET_TRAFFIC_STG
           SET overall_status   = 'E'
         WHERE     batch_id = p_batch_id
               AND (store_status = 'E' OR recorddate_status = 'E' OR traffic_status = 'E' OR brand_status = 'E' OR FILE_FORMAT_STATUS = 'E');

        -- Update all records to E, even if one row is in error
        /*UPDATE XXDO.XXD_PARTNER_RET_TRAFFIC_STG
           SET overall_status = 'E'
         WHERE  EXISTS
                       (SELECT 1
                          FROM XXDO.XXD_PARTNER_RET_TRAFFIC_STG
                         WHERE     (   store_status = 'E'
                                    OR recorddate_status = 'E'
                                    OR traffic_status = 'E'
                                    OR brand_status = 'E'
                                    OR FILE_FORMAT_STATUS = 'E' ---Changes as part of CCR CCR0010141
                                    )
                              AND overall_status = 'N'
                                batch_id = p_batch_id)
               AND overall_status = 'N'
               AND batch_id = p_batch_id;*/

        p_error_count   := SQL%ROWCOUNT;

        --Update all remaining records
        UPDATE xxdo.XXD_PARTNER_RET_TRAFFIC_STG
           SET store_status = 'S', recorddate_status = 'S', traffic_status = 'S',
               overall_status = 'S', brand_status = 'S', FILE_FORMAT_STATUS = 'S' ---Changes as part of CCR CCR0010141
         WHERE overall_status = 'N' AND batch_id = p_batch_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE XXDO.XXD_PARTNER_RET_TRAFFIC_STG
               SET overall_status = 'E', error_message = lc_error_message
             WHERE batch_id = p_batch_id;
    END validate_traffic_data;
END xxd_ont_partner_retailer_pkg;
/


GRANT EXECUTE, DEBUG ON APPS.XXD_ONT_PARTNER_RETAILER_PKG TO SOA_INT
/
