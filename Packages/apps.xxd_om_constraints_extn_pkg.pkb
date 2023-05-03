--
-- XXD_OM_CONSTRAINTS_EXTN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OM_CONSTRAINTS_EXTN_PKG"
IS
    ----------------------------------------------------------------------------------------------
    -- Created By              : Mithun Mathew
    -- Creation Date           : 1-DEC-2016
    -- Program Name            : XXD_OM_CONSTRAINTS_EXTN_PKG.pkb
    -- Description             : Custom Processing constraints
    -- Language                : PL/SQL
    -- Parameters              : Oracle setup expects below 6 input and 1 output parameters
    --                           by default and it has to be a procedure
    -- Revision History:
    -- ===========================================================================================
    -- Date               Version#    Name                  Remarks
    -- ===========================================================================================
    -- 01-DEC-2016       1.0         Mithun Mathew         Initial development (CCR0005788).
    -- 12-Sep-2017       1.1         Viswanathan Pandian   Updated for CCR0006634
    -- 02-Mar-2018       1.2         Viswanathan Pandian   Updated for CCR0006889
    -- 08-Apr-2020       1.3         Greg Jensen           Updated for CCR0008439
    -- 31-Aug-2020       1.4         Greg Jensen           Updated for CCR0008812
    -- 22-Oct-2020       1.5         Jayarajan AK          Updated for Brexit Changes CCR0009071
    -- 17-Mar-2021       1.6         Jayarajan AK          Modified for CCR0008870 - Global Inventory Allocation Project
    -- 17-Feb-2022       1.7         Mithun Mathew         Updated for CCR0009825
    -- ===========================================================================================

    g_pkg_name   CONSTANT VARCHAR2 (30) := 'XXD_OM_CONSTRAINTS_EXTN_PKG';

    PROCEDURE reservation_exists_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                         , x_result_out OUT NOCOPY NUMBER)
    IS
        l_reservation_exists     VARCHAR2 (1);
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '1,';
        END IF;


        SELECT 'Y'
          INTO l_reservation_exists
          FROM mtl_reservations_all_v
         WHERE     demand_source_line_id = oe_line_security.g_record.line_id
               AND supply_source_type = 'Inventory';

        IF NVL (l_reservation_exists, 'N') = 'Y'
        THEN
            x_result_out   := 1;
        ELSE
            x_result_out   := 0;
        END IF;

        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '2';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('NO DATA FOUND IN VALIDATE RELEASE STATUS',
                                  1);
            END IF;

            x_result_out   := 0;
        WHEN TOO_MANY_ROWS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('TOO MANY ROWS IN VALIDATE RELEASE STATUS',
                                  1);
            END IF;

            x_result_out   := 1;
        WHEN OTHERS
        THEN
            IF oe_msg_pub.check_msg_level (oe_msg_pub.g_msg_lvl_unexp_error)
            THEN
                oe_msg_pub.add_exc_msg (g_pkg_name,
                                        'Validate_Release_Status');
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'ERROR MESSAGE IN VALIDATE RELEASE STATUS : '
                    || SUBSTR (SQLERRM, 1, 100),
                    1);
            END IF;
    END reservation_exists_status;

    -- Start changes for CCR0006634
    PROCEDURE customer_closed_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                      , x_result_out OUT NOCOPY NUMBER)
    IS
        l_closed_account         VARCHAR2 (1);
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '1,';
        END IF;

        SELECT 'Y'
          INTO l_closed_account
          FROM apps.hz_cust_profile_classes hcpc, apps.hz_customer_profiles hcp, apps.hz_cust_accounts hca
         WHERE     hcpc.profile_class_id = hcp.profile_class_id
               AND hcp.cust_account_id = hca.cust_account_id
               AND hca.attribute18 IS NULL
               AND UPPER (hcpc.name) LIKE '%CLOSED%'
               AND hca.cust_account_id =
                   oe_header_security.g_record.sold_to_org_id;

        IF NVL (l_closed_account, 'N') = 'Y'
        THEN
            x_result_out   := 1;
        ELSE
            x_result_out   := 0;
        END IF;

        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '2';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'NO DATA FOUND IN VALIDATE CUSTOMER PROFILE STATUS',
                    1);
            END IF;

            x_result_out   := 0;
        WHEN TOO_MANY_ROWS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'TOO MANY ROWS IN VALIDATE CUSTOMER PROFILE STATUS',
                    1);
            END IF;

            x_result_out   := 1;
        WHEN OTHERS
        THEN
            IF oe_msg_pub.check_msg_level (oe_msg_pub.g_msg_lvl_unexp_error)
            THEN
                oe_msg_pub.add_exc_msg (g_pkg_name, 'Customer_Closed_Status');
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'ERROR MESSAGE IN VALIDATE CUSTOMER PROFILE STATUS : '
                    || SUBSTR (SQLERRM, 1, 100),
                    1);
            END IF;
    END customer_closed_status;

    -- End changes for CCR0006634
    -- Start changes for CCR0006889
    PROCEDURE calloff_line_update_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                          , x_result_out OUT NOCOPY NUMBER)
    IS
        lc_linked_line           VARCHAR2 (1);
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '1,';
        END IF;

        SELECT 'Y'
          INTO lc_linked_line
          FROM oe_order_lines_all oola
         WHERE     oola.line_id = oe_line_security.g_record.line_id
               AND oola.global_attribute19 = 'PROCESSED';

        IF NVL (lc_linked_line, 'N') = 'Y'
        THEN
            x_result_out   := 1;
        ELSE
            x_result_out   := 0;
        END IF;

        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '2';
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'NO DATA FOUND IN VALIDATE BULK LINKED LINE',
                    1);
            END IF;

            x_result_out   := 0;
        WHEN TOO_MANY_ROWS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'TOO MANY ROWS IN VALIDATE BULK LINKED LINE',
                    1);
            END IF;

            x_result_out   := 1;
        WHEN OTHERS
        THEN
            IF oe_msg_pub.check_msg_level (oe_msg_pub.g_msg_lvl_unexp_error)
            THEN
                oe_msg_pub.add_exc_msg (g_pkg_name,
                                        'Calloff_Line_Update_Status');
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'ERROR MESSAGE IN VALIDATE BULK LINKED LINE : '
                    || SUBSTR (SQLERRM, 1, 100),
                    1);
            END IF;
    END calloff_line_update_status;

    -- End changes for CCR0006889
    -- Start changes for CCR0008439
    PROCEDURE customer_class_status (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                     , x_result_out OUT NOCOPY NUMBER)
    IS
        ln_cnt                   NUMBER;
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '1,';
        END IF;

        --Is order type in lookup
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_ORDER_TYPE_CUST_CLASS'
               AND flv.language = 'US'
               AND enabled_flag = 'Y'
               AND flv.attribute1 =
                   TO_CHAR (oe_header_security.g_record.order_type_id)
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        --If order type not in lookup then return success because it is not restricteed.
        IF ln_cnt = 0
        THEN
            x_result_out   := 0;
            RETURN;
        END IF;

        --Check if customer class is in lookup for order type
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv, hz_cust_accounts hzca
         WHERE     flv.lookup_type = 'XXD_ORDER_TYPE_CUST_CLASS'
               AND flv.language = 'US'
               AND flv.attribute1 =
                   TO_CHAR (oe_header_security.g_record.order_type_id)
               AND hzca.cust_account_id =
                   oe_header_security.g_record.sold_to_org_id
               AND (flv.attribute2 = hzca.customer_class_code OR flv.attribute3 = hzca.customer_class_code OR flv.attribute4 = hzca.customer_class_code OR flv.attribute5 = hzca.customer_class_code OR flv.attribute6 = hzca.customer_class_code OR flv.attribute7 = hzca.customer_class_code OR flv.attribute8 = hzca.customer_class_code OR flv.attribute9 = hzca.customer_class_code OR flv.attribute10 = hzca.customer_class_code);

        --If record returned then success
        IF ln_cnt > 0
        THEN
            x_result_out   := 0;
        ELSE
            x_result_out   := 1;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('NO DATA FOUND IN VALIDATE CUSTOMER CLASS',
                                  1);
            END IF;

            x_result_out   := 0;
        WHEN TOO_MANY_ROWS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('TOO MANY ROWS IN VALIDATE CUSTOMER CLASS',
                                  1);
            END IF;

            x_result_out   := 1;
        WHEN OTHERS
        THEN
            IF oe_msg_pub.check_msg_level (oe_msg_pub.g_msg_lvl_unexp_error)
            THEN
                oe_msg_pub.add_exc_msg (g_pkg_name, 'customer_class_status');
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'ERROR MESSAGE IN VALIDATE CUSTOMER CLASS : '
                    || SUBSTR (SQLERRM, 1, 100),
                    1);
            END IF;
    END customer_class_status;

    -- End changes for CCR0008439

    -- Begin changes for CCR0008812
    PROCEDURE line_type_warehouse (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                   , x_result_out OUT NOCOPY NUMBER)
    IS
        ln_cnt                   NUMBER;
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '1,';
        END IF;

        --Is line type in lookup
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_ONT_INVALID_LINE_TYPE_WH'
               AND flv.language = 'US'
               AND enabled_flag = 'Y'
               AND flv.attribute1 =
                   TO_CHAR (oe_line_security.g_record.line_type_id)
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);


        --If line type not in lookup then return success because it is not restricteed.
        IF ln_cnt = 0
        THEN
            x_result_out   := 0;
            RETURN;
        END IF;

        --Check if warehouse is in the lookup for the order line type
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_ONT_INVALID_LINE_TYPE_WH'
               AND flv.language = 'US'
               AND enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1)
               AND flv.attribute1 =
                   TO_CHAR (oe_line_security.g_record.line_type_id)
               AND (flv.attribute2 = oe_line_security.g_record.ship_from_org_id OR flv.attribute3 = oe_line_security.g_record.ship_from_org_id OR flv.attribute4 = oe_line_security.g_record.ship_from_org_id OR flv.attribute5 = oe_line_security.g_record.ship_from_org_id OR flv.attribute6 = oe_line_security.g_record.ship_from_org_id OR flv.attribute7 = oe_line_security.g_record.ship_from_org_id);


        --If record returned then success
        IF ln_cnt > 0
        THEN
            x_result_out   := 0;
        ELSE
            x_result_out   := 1;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'NO DATA FOUND IN VALIDATE LINE TYPE WAREHOUE',
                    1);
            END IF;

            x_result_out   := 0;
        WHEN TOO_MANY_ROWS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                    'TOO MANY ROWS IN VALIDATE LINE TYPE WAREHOUE',
                    1);
            END IF;

            x_result_out   := 1;
        WHEN OTHERS
        THEN
            IF oe_msg_pub.check_msg_level (oe_msg_pub.g_msg_lvl_unexp_error)
            THEN
                oe_msg_pub.add_exc_msg (g_pkg_name, 'line_type_warehouse');
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'ERROR MESSAGE IN VALIDATE LINE TYPE WAREHOUE : '
                    || SUBSTR (SQLERRM, 1, 100),
                    1);
            END IF;
    END;

    -- End changes for CCR0008812

    --Start v1.5 Brexit changes for CCR0009071
    PROCEDURE brexit_org_map_hdr (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                  , x_result_out OUT NOCOPY NUMBER)
    IS
        ln_cnt                   NUMBER;
        ln_cntry                 NUMBER;
        ln_blk_cnt               NUMBER;                                --v1.6
        lv_org_id                VARCHAR2 (30);
        lv_warehouse_id          VARCHAR2 (30);
        lv_country_code          VARCHAR2 (10);
        lv_lookup_country        VARCHAR2 (30);
        lv_brand_code            VARCHAR2 (30);
        lv_source_id             VARCHAR2 (30);
        lv_order_type            VARCHAR2 (30);
        lv_allow                 VARCHAR2 (30) := 'ALLOW ONLY';
        lv_restrict              VARCHAR2 (30) := 'RESTRICT';

        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '1,';
        END IF;

        --assign header variables
        lv_org_id         := TO_CHAR (oe_header_security.g_record.org_id);
        lv_warehouse_id   :=
            NVL (TO_CHAR (oe_header_security.g_record.ship_from_org_id),
                 'XXX');
        lv_brand_code     := oe_header_security.g_record.attribute5;
        lv_source_id      :=
            TO_CHAR (oe_header_security.g_record.order_source_id);
        lv_order_type     :=
            TO_CHAR (oe_header_security.g_record.order_type_id);

        --Start changes v1.6
        SELECT COUNT (*)
          INTO ln_blk_cnt
          FROM oe_transaction_types_all
         WHERE     attribute5 = 'BO'
               AND transaction_type_id =
                   oe_header_security.g_record.order_type_id;

        --End changes v1.6

        --Is org code in lookup
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_BREXIT_ORG_COUNTRY_MAP'
               AND flv.language = 'US'
               AND enabled_flag = 'Y'
               AND flv.attribute1 = lv_org_id
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        --If org code not in lookup then return success because it is not restricted.
        IF ln_cnt = 0 OR lv_source_id = 10                   --internal orders
                                           OR ln_blk_cnt > 0 -- bypass the check for bulk orders --v1.6
        THEN
            x_result_out   := 0;
            RETURN;
        END IF;

        --Get the Country Code
        SELECT hl.country
          INTO lv_country_code
          FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_acct_sites_all hcas,
               apps.hz_cust_site_uses_all hcsu
         WHERE     hl.location_id = hps.location_id
               AND hcas.party_site_id = hps.party_site_id
               AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
               AND hcsu.site_use_code = 'SHIP_TO'
               AND hcsu.status = 'A'
               AND hcsu.site_use_id =
                   oe_header_security.g_record.ship_to_org_id
               AND hcsu.org_id = lv_org_id;

        --Check if OU + WH + Country is in lookup with Restrict
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_BREXIT_ORG_COUNTRY_MAP'
               AND flv.language = 'US'
               AND flv.attribute1 = lv_org_id
               AND flv.attribute2 = lv_warehouse_id --assuming inv org is mandatory in the lookup for RESTRICT
               AND NVL (flv.attribute3, lv_country_code) = lv_country_code
               AND NVL (flv.attribute4, lv_brand_code) = lv_brand_code
               AND NVL (flv.attribute5, lv_source_id) = lv_source_id
               AND NVL (flv.attribute6, lv_order_type) = lv_order_type
               AND flv.attribute7 = lv_restrict
               AND flv.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        --If record is returned then prevent the action and exit
        IF ln_cnt > 0
        THEN
            x_result_out   := 1;
            RETURN;
        END IF;

        --Additional condition to check if allow only exists (get the count);
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_BREXIT_ORG_COUNTRY_MAP'
               AND flv.language = 'US'
               AND flv.attribute1 = lv_org_id
               AND NVL (flv.attribute2, lv_warehouse_id) = lv_warehouse_id
               AND NVL (flv.attribute4, lv_brand_code) = lv_brand_code
               AND NVL (flv.attribute5, lv_source_id) = lv_source_id
               AND NVL (flv.attribute6, lv_order_type) = lv_order_type
               AND flv.attribute7 = lv_allow
               AND flv.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        --If exists, Check if OU + WH + Country is in lookup with Allow Only
        IF ln_cnt > 0
        THEN
            SELECT COUNT (*)
              INTO ln_cntry
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_BREXIT_ORG_COUNTRY_MAP'
                   AND flv.language = 'US'
                   AND flv.attribute1 = lv_org_id
                   AND NVL (flv.attribute2, lv_warehouse_id) =
                       lv_warehouse_id
                   AND NVL (flv.attribute3, lv_country_code) =
                       lv_country_code
                   AND NVL (flv.attribute4, lv_brand_code) = lv_brand_code
                   AND NVL (flv.attribute5, lv_source_id) = lv_source_id
                   AND NVL (flv.attribute6, lv_order_type) = lv_order_type
                   AND flv.attribute7 = lv_allow
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (flv.end_date_active,
                                                    TRUNC (SYSDATE) + 1);

            --If record is returned then return success
            IF ln_cntry > 0
            THEN
                x_result_out   := 0;
                RETURN;
            ELSE
                x_result_out   := 1;
                RETURN;
            END IF;
        ELSE
            x_result_out   := 0;
            RETURN;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('NO DATA FOUND IN BREXIT ORG MAP HEADER',
                                  1);
            END IF;

            x_result_out   := 0;
        WHEN TOO_MANY_ROWS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('TOO MANY ROWS IN BREXIT ORG MAP HEADER',
                                  1);
            END IF;

            x_result_out   := 0;
        WHEN OTHERS
        THEN
            IF oe_msg_pub.check_msg_level (oe_msg_pub.g_msg_lvl_unexp_error)
            THEN
                oe_msg_pub.add_exc_msg (g_pkg_name, 'brexit_org_map_hdr');
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'ERROR MESSAGE IN BREXIT ORG MAP HEADER: '
                    || SUBSTR (SQLERRM, 1, 100),
                    1);
            END IF;

            x_result_out   := 0;
    END brexit_org_map_hdr;


    PROCEDURE brexit_org_map_line (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                   , x_result_out OUT NOCOPY NUMBER)
    IS
        ln_cnt                   NUMBER;
        ln_cntry                 NUMBER;
        ln_blk_cnt               NUMBER;                                --v1.6
        ln_ordr_typ_id           NUMBER;                                --v1.6
        lv_org_id                VARCHAR2 (30);
        lv_warehouse_id          VARCHAR2 (30);
        lv_country_code          VARCHAR2 (10);
        lv_lookup_country        VARCHAR2 (30);
        lv_brand_code            VARCHAR2 (30);
        lv_source_id             VARCHAR2 (30);
        lv_order_type            VARCHAR2 (30);
        lv_allow                 VARCHAR2 (30) := 'ALLOW ONLY';
        lv_restrict              VARCHAR2 (30) := 'RESTRICT';

        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '1,';
        END IF;

        --assign header and line variables
        lv_org_id   := TO_CHAR (oe_line_security.g_record.org_id);
        lv_warehouse_id   :=
            TO_CHAR (oe_line_security.g_record.ship_from_org_id);

        --Is org code in lookup
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_BREXIT_ORG_COUNTRY_MAP'
               AND flv.language = 'US'
               AND enabled_flag = 'Y'
               AND flv.attribute1 = lv_org_id
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        SELECT NVL (attribute5, '~'), NVL (TO_CHAR (order_source_id), '~'), order_type_id, --added for v1.6
               NVL (TO_CHAR (order_type_id), '~')
          INTO lv_brand_code, lv_source_id, ln_ordr_typ_id,   --added for v1.6
                                                            lv_order_type
          FROM oe_order_headers_all
         WHERE header_id = oe_line_security.g_record.header_id;

        --Start changes v1.6
        SELECT COUNT (*)
          INTO ln_blk_cnt
          FROM oe_transaction_types_all
         WHERE attribute5 = 'BO' AND transaction_type_id = ln_ordr_typ_id;

        --End changes v1.6

        --If org code not in lookup then return success because it is not restricted.
        IF ln_cnt = 0 OR lv_source_id = 10                   --internal orders
                                           OR ln_blk_cnt > 0 -- bypass the check for bulk orders --v1.6
        THEN
            x_result_out   := 0;
            RETURN;
        END IF;

        --Get the Country Code
        SELECT hl.country
          INTO lv_country_code
          FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_acct_sites_all hcas,
               apps.hz_cust_site_uses_all hcsu
         WHERE     hl.location_id = hps.location_id
               AND hcas.party_site_id = hps.party_site_id
               AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
               AND hcsu.site_use_code = 'SHIP_TO'
               AND hcsu.status = 'A'
               AND hcsu.site_use_id =
                   oe_line_security.g_record.ship_to_org_id
               AND hcsu.org_id = lv_org_id;

        --Check if OU + WH + Country is in lookup with Restrict
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_BREXIT_ORG_COUNTRY_MAP'
               AND flv.language = 'US'
               AND flv.attribute1 = lv_org_id
               AND flv.attribute2 = lv_warehouse_id --assuming inv org is mandatory in the lookup for RESTRICT
               AND NVL (flv.attribute3, lv_country_code) = lv_country_code
               AND NVL (flv.attribute4, lv_brand_code) = lv_brand_code
               AND NVL (flv.attribute5, lv_source_id) = lv_source_id
               AND NVL (flv.attribute6, lv_order_type) = lv_order_type
               AND flv.attribute7 = lv_restrict
               AND flv.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        --If record is returned then prevent the action and exit
        IF ln_cnt > 0
        THEN
            x_result_out   := 1;
            RETURN;
        END IF;

        --Additional condition to check if allow only exists (get the count);
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_BREXIT_ORG_COUNTRY_MAP'
               AND flv.language = 'US'
               AND flv.attribute1 = lv_org_id
               AND NVL (flv.attribute2, lv_warehouse_id) = lv_warehouse_id
               AND NVL (flv.attribute4, lv_brand_code) = lv_brand_code
               AND NVL (flv.attribute5, lv_source_id) = lv_source_id
               AND NVL (flv.attribute6, lv_order_type) = lv_order_type
               AND flv.attribute7 = lv_allow
               AND flv.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        --If exists, Check if OU + WH + Country is in lookup with Allow Only
        IF ln_cnt > 0
        THEN
            SELECT COUNT (*)
              INTO ln_cntry
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_BREXIT_ORG_COUNTRY_MAP'
                   AND flv.language = 'US'
                   AND flv.attribute1 = lv_org_id
                   AND NVL (flv.attribute2, lv_warehouse_id) =
                       lv_warehouse_id
                   AND NVL (flv.attribute3, lv_country_code) =
                       lv_country_code
                   AND NVL (flv.attribute4, lv_brand_code) = lv_brand_code
                   AND NVL (flv.attribute5, lv_source_id) = lv_source_id
                   AND NVL (flv.attribute6, lv_order_type) = lv_order_type
                   AND flv.attribute7 = lv_allow
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (flv.end_date_active,
                                                    TRUNC (SYSDATE) + 1);

            --If record is returned then return success
            IF ln_cntry > 0
            THEN
                x_result_out   := 0;
                RETURN;
            ELSE
                x_result_out   := 1;
                RETURN;
            END IF;
        ELSE
            x_result_out   := 0;
            RETURN;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('NO DATA FOUND IN BREXIT ORG MAP LINE', 1);
            END IF;

            x_result_out   := 0;
        WHEN TOO_MANY_ROWS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('TOO MANY ROWS IN BREXIT ORG MAP LINE', 1);
            END IF;

            x_result_out   := 0;
        WHEN OTHERS
        THEN
            IF oe_msg_pub.check_msg_level (oe_msg_pub.g_msg_lvl_unexp_error)
            THEN
                oe_msg_pub.add_exc_msg (g_pkg_name, 'brexit_org_map_line');
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'ERROR MESSAGE IN BREXIT ORG MAP LINE: '
                    || SUBSTR (SQLERRM, 1, 100),
                    1);
            END IF;

            x_result_out   := 0;
    END brexit_org_map_line;

    --End v1.5 Brexit changes for CCR0009071
    -- Start changes for CCR00098251
    PROCEDURE orderdate_update_allowed (p_application_id IN NUMBER, p_entity_short_name IN VARCHAR2, p_validation_entity_short_name IN VARCHAR2, p_validation_tmplt_short_name IN VARCHAR2, p_record_set_short_name IN VARCHAR2, p_scope IN VARCHAR2
                                        , x_result_out OUT NOCOPY NUMBER)
    IS
        ln_cnt                   NUMBER;
        l_debug_level   CONSTANT NUMBER := oe_debug_pub.g_debug_level;
    BEGIN
        IF g_debug_call > 0
        THEN
            g_debug_msg   := g_debug_msg || '1,';
        END IF;

        --Skip validation for BATCH and BATCH.O2F accounts
        IF fnd_global.user_id IN (1345, 1875)
        THEN
            x_result_out   := 0;
            RETURN;
        END IF;

        --Check if authorized user is in lookup
        SELECT COUNT (*)
          INTO ln_cnt
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_ONT_ORDER_DATE_AUTH_USER'
               AND flv.language = 'US'
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1)
               AND flv.attribute1 = TO_CHAR (fnd_global.user_id);

        --If record returned then success
        IF ln_cnt > 0
        THEN
            x_result_out   := 0;
        ELSE
            x_result_out   := 1;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('NO DATA FOUND IN AUTH USER LOOKUP', 1);
            END IF;

            x_result_out   := 0;
        WHEN TOO_MANY_ROWS
        THEN
            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD ('TOO MANY ROWS IN AUTH USER LOOKUP', 1);
            END IF;

            x_result_out   := 1;
        WHEN OTHERS
        THEN
            IF oe_msg_pub.check_msg_level (oe_msg_pub.g_msg_lvl_unexp_error)
            THEN
                oe_msg_pub.add_exc_msg (g_pkg_name,
                                        'orderdate_update_allowed');
            END IF;

            IF l_debug_level > 0
            THEN
                oe_debug_pub.ADD (
                       'ERROR MESSAGE IN VALIDATE CUSTOMER CLASS : '
                    || SUBSTR (SQLERRM, 1, 100),
                    1);
            END IF;
    END orderdate_update_allowed;
-- End changes for CCR00098251

END XXD_OM_CONSTRAINTS_EXTN_PKG;
/
