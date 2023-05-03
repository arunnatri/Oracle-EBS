--
-- XXD_ONT_VAS_CODE_UPDT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_VAS_CODE_UPDT_PKG"
AS
    /*******************************************************************************
     * Program Name : XXD_ONT_VAS_CODE_UPDT_PKG
     * Language     : PL/SQL
     * Description  : This package will be Used to update the VAs Code
     *
     * History      :
     *
     * WHO                 WHAT              Desc                                               WHEN
     * -------------- ------------------------------------------------------------------- ---------------
     *  Laltu               1.1           Updated for CCR0009521                              01-SEP-2021
     *  Laltu               1.2           Updated for CCR0009629                              05-OCT-2021
     *  Ramesh BR     1.3   Updated for CCR0010027        28-JUL-2022
     *  Laltu        1.4   Updated for CCR0010205        19-OCT-2022
     *  Pardeep Rohilla   1.5   Updated for CCR0010299        26-DEC-2022
     * ----------------------------------------------------------------------------------------------------- */
    /******************************************************
   * Procedure:   main
   *
   * Synopsis: This Procedure is for update the vas code.
   * Design:
   *
   * Notes:
   *
   * Modifications:
   *
   ******************************************************/

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER, p_tran_type VARCHAR2, p_order_num IN NUMBER, p_order_age IN NUMBER, p_operation_type IN VARCHAR2, P_Hidden_Parameter IN VARCHAR2, p_account_number IN VARCHAR2
                    ,                                  -- Added for CCR0010299
                      p_order_source VARCHAR2          -- Added for CCR0010299
                                             )
    IS
        CURSOR c_hdr_vas_emea IS
            SELECT DISTINCT ooha.header_id, ooha.sold_to_org_id, ooha.ship_to_org_id,
                            ooha.order_number, ooha.attribute14 --Added for CCR0010299
              FROM oe_order_headers_all ooha, apps.oe_order_lines_all ool, --Added for CCR0010299
                                                                           apps.oe_transaction_types_tl ott,
                   apps.oe_order_sources oos, fnd_lookup_values flv, fnd_lookup_values flv1,
                   fnd_lookup_values flv2, apps.hz_cust_accounts hca
             WHERE     1 = 1                           ----- TESTING Condition
                   -- AND p_operation_type = p_operation_type
                   -- AND P_Hidden_Parameter = P_Hidden_Parameter
                   AND ool.open_flag(+) = 'Y'
                   AND (((p_operation_type = 'Assignment') AND ((ool.attribute14 IS NOT NULL) OR (ooha.attribute14 IS NULL))) OR ((p_operation_type = 'Update') AND ((ooha.attribute14 IS NOT NULL))))
                   AND ooha.header_id = ool.header_id(+)
                   AND ott.language = USERENV ('LANG')
                   AND ott.transaction_type_id = ooha.order_type_id
                   AND oos.order_source_id = ooha.order_source_id
                   AND ooha.open_flag = 'Y'
                   AND hca.cust_account_id = ooha.sold_to_org_id -- Added for CCR0010299
                   AND hca.account_number =
                       NVL (p_account_number, hca.account_number) -- Added for CCR0010299
                   -- AND not exists (select 1 from apps.wsh_new_deliveries
                   -- where 1=1
                   -- and ooha.header_id = source_header_id)                      -- Added for CCR0010299
                   AND ooha.order_category_code = 'ORDER'
                   AND ooha.flow_status_code = 'BOOKED'
                   AND ooha.org_id = p_org_id
                   AND flv.lookup_type = 'XXD_VAS_DEFAULT_ORDER_TYPES'
                   AND flv.meaning = ott.name
                   AND flv.meaning = NVL (p_tran_type, flv.meaning)
                   AND flv.enabled_flag = 'Y'
                   AND NVL (flv.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv.language = USERENV ('LANG')
                   --Add changes for CCR0009629
                   AND flv1.lookup_type = 'XXD_VAS_DEFAULT_ORDER_SOURCES'
                   AND flv1.meaning = oos.name
                   AND flv1.meaning = NVL (p_order_source, flv1.meaning)
                   AND flv1.enabled_flag = 'Y'
                   AND NVL (flv1.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv1.language = USERENV ('LANG')
                   --Add changes for CCR0010299
                   AND flv2.lookup_type = 'XXDO_VAS_HEADER_ONLY_OU_LKP'
                   AND flv2.lookup_code = p_org_id
                   AND flv2.enabled_flag = 'Y'
                   AND NVL (flv2.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv2.language = USERENV ('LANG')
                   AND (   (    (p_operation_type = 'Assignment')
                            AND (EXISTS
                                     (SELECT 1
                                        FROM xxd_ont_vas_assignment_dtls_t xovad, hz_cust_site_uses_all csu
                                       WHERE     1 = 1
                                             AND xovad.cust_account_id =
                                                 ooha.sold_to_org_id
                                             AND ooha.ship_to_org_id =
                                                 csu.site_use_id(+)
                                             AND xovad.attribute_value =
                                                 csu.cust_acct_site_id(+)
                                             AND xovad.vas_code IS NOT NULL
                                             AND xovad.attribute_level IN
                                                     ('SITE', 'CUSTOMER')
                                      UNION
                                      SELECT 1
                                        FROM oe_attachment_rule_elements_v oare
                                       WHERE     oare.attribute_name =
                                                 'Customer'
                                             AND oare.attribute_value =
                                                 TO_CHAR (
                                                     ooha.sold_to_org_id))))
                        OR (p_operation_type = 'Update')) ---- Modified the cursor query for CCR0010299
                   AND ((p_operation_type = 'Update') OR (p_order_age IS NOT NULL AND ooha.creation_date > (SYSDATE - p_order_age) AND p_operation_type = 'Assignment') OR (p_order_age IS NULL AND 1 = 1))
                   --End changes for CCR0009629
                   AND ooha.order_number =
                       NVL (p_order_num, ooha.order_number)
            MINUS
            SELECT DISTINCT ooha.header_id, ooha.sold_to_org_id, ooha.ship_to_org_id,
                            ooha.order_number, ooha.attribute14 --Added for CCR0010299
              FROM oe_order_headers_all ooha, apps.oe_order_lines_all ool, --Added for CCR0010299
                                                                           apps.oe_transaction_types_tl ott,
                   apps.oe_order_sources oos, fnd_lookup_values flv, fnd_lookup_values flv1,
                   fnd_lookup_values flv2, apps.hz_cust_accounts hca
             WHERE     1 = 1                           ----- TESTING Condition
                   -- AND p_operation_type = p_operation_type
                   -- AND P_Hidden_Parameter = P_Hidden_Parameter
                   AND ool.open_flag(+) = 'Y'
                   AND (((p_operation_type = 'Assignment') AND ((ool.attribute14 IS NOT NULL) OR (ooha.attribute14 IS NULL))) OR ((p_operation_type = 'Update') AND ((ooha.attribute14 IS NOT NULL))))
                   AND ooha.header_id = ool.header_id(+)
                   AND ott.language = USERENV ('LANG')
                   AND ott.transaction_type_id = ooha.order_type_id
                   AND oos.order_source_id = ooha.order_source_id
                   AND ooha.open_flag = 'Y'
                   AND hca.cust_account_id = ooha.sold_to_org_id -- Added for CCR0010299
                   AND hca.account_number =
                       NVL (p_account_number, hca.account_number) -- Added for CCR0010299
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wsh_new_deliveries
                             WHERE     1 = 1
                                   AND ooha.header_id = source_header_id) -- Added for CCR0010299
                   AND ooha.order_category_code = 'ORDER'
                   AND ooha.flow_status_code = 'BOOKED'
                   AND ooha.org_id = p_org_id
                   AND flv.lookup_type = 'XXD_VAS_DEFAULT_ORDER_TYPES'
                   AND flv.meaning = ott.name
                   AND flv.meaning = NVL (p_tran_type, flv.meaning)
                   AND flv.enabled_flag = 'Y'
                   AND NVL (flv.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv.language = USERENV ('LANG')
                   --Add changes for CCR0009629
                   AND flv1.lookup_type = 'XXD_VAS_DEFAULT_ORDER_SOURCES'
                   AND flv1.meaning = oos.name
                   AND flv1.meaning = NVL (p_order_source, flv1.meaning)
                   AND flv1.enabled_flag = 'Y'
                   AND NVL (flv1.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv1.language = USERENV ('LANG')
                   --Add changes for CCR0010299
                   AND flv2.lookup_type = 'XXDO_VAS_HEADER_ONLY_OU_LKP'
                   AND flv2.lookup_code = p_org_id
                   AND flv2.enabled_flag = 'Y'
                   AND NVL (flv2.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv2.language = USERENV ('LANG')
                   AND (   (    (p_operation_type = 'Assignment')
                            AND (EXISTS
                                     (SELECT 1
                                        FROM xxd_ont_vas_assignment_dtls_t xovad, hz_cust_site_uses_all csu
                                       WHERE     1 = 1
                                             AND xovad.cust_account_id =
                                                 ooha.sold_to_org_id
                                             AND ooha.ship_to_org_id =
                                                 csu.site_use_id(+)
                                             AND xovad.attribute_value =
                                                 csu.cust_acct_site_id(+)
                                             AND xovad.vas_code IS NOT NULL
                                             AND xovad.attribute_level IN
                                                     ('SITE', 'CUSTOMER')
                                      UNION
                                      SELECT 1
                                        FROM oe_attachment_rule_elements_v oare
                                       WHERE     oare.attribute_name =
                                                 'Customer'
                                             AND oare.attribute_value =
                                                 TO_CHAR (
                                                     ooha.sold_to_org_id))))
                        OR (p_operation_type = 'Update')) ---- Modified the cursor query for CCR0010299
                   AND ((p_operation_type = 'Update') OR (p_order_age IS NOT NULL AND ooha.creation_date > (SYSDATE - p_order_age) AND p_operation_type = 'Assignment') OR (p_order_age IS NULL AND 1 = 1))
                   --End changes for CCR0009629
                   AND ooha.order_number =
                       NVL (p_order_num, ooha.order_number);

        CURSOR c_hdr_vas IS
            SELECT ooha.header_id, ooha.sold_to_org_id, ooha.ship_to_org_id,
                   ooha.order_number, ooha.attribute14  --Added for CCR0010299
              FROM oe_order_headers_all ooha, apps.oe_transaction_types_tl ott, apps.oe_order_sources oos,
                   fnd_lookup_values flv, fnd_lookup_values flv1, apps.hz_cust_accounts hca
             WHERE     1 = 1                           ----- TESTING Condition
                   -- AND p_operation_type = p_operation_type
                   -- AND P_Hidden_Parameter = P_Hidden_Parameter
                   AND ott.language = USERENV ('LANG')
                   AND ott.transaction_type_id = ooha.order_type_id
                   AND oos.order_source_id = ooha.order_source_id
                   AND ooha.open_flag = 'Y'
                   AND hca.cust_account_id = ooha.sold_to_org_id -- Added for CCR0010299
                   AND hca.account_number =
                       NVL (p_account_number, hca.account_number) -- Added for CCR0010299
                   AND (   ooha.attribute14 IS NULL
                        OR (    p_account_number IS NOT NULL
                            AND NOT EXISTS
                                    (SELECT 1
                                       FROM apps.wsh_new_deliveries
                                      WHERE     1 = 1
                                            AND source_header_id =
                                                ooha.header_id))) -- Added for CCR0010299
                   AND ooha.order_category_code = 'ORDER'
                   AND ooha.flow_status_code = 'BOOKED'
                   AND ooha.org_id = p_org_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values flv2
                             WHERE     1 = 1
                                   AND flv2.lookup_type =
                                       'XXDO_VAS_HEADER_ONLY_OU_LKP'
                                   AND flv2.lookup_code = p_org_id
                                   AND flv2.enabled_flag = 'Y'
                                   AND NVL (flv2.end_date_active,
                                            SYSDATE + 1) >
                                       SYSDATE
                                   AND flv2.language = USERENV ('LANG'))
                   AND flv.lookup_type = 'XXD_VAS_DEFAULT_ORDER_TYPES'
                   AND flv.meaning = ott.name
                   AND flv.meaning = NVL (p_tran_type, flv.meaning)
                   AND flv.enabled_flag = 'Y'
                   AND NVL (flv.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv.language = USERENV ('LANG')
                   --Add changes for CCR0009629
                   AND flv1.lookup_type = 'XXD_VAS_DEFAULT_ORDER_SOURCES'
                   AND flv1.meaning = oos.name
                   AND flv1.meaning = NVL (p_order_source, flv1.meaning)
                   AND flv1.enabled_flag = 'Y'
                   AND NVL (flv1.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv1.language = USERENV ('LANG')
                   AND (   (    (p_operation_type = 'Assignment')
                            AND (EXISTS
                                     (SELECT 1
                                        FROM xxd_ont_vas_assignment_dtls_t xovad, hz_cust_site_uses_all csu
                                       WHERE     1 = 1
                                             AND xovad.cust_account_id =
                                                 ooha.sold_to_org_id
                                             AND ooha.ship_to_org_id =
                                                 csu.site_use_id(+)
                                             AND xovad.attribute_value =
                                                 csu.cust_acct_site_id(+)
                                             AND xovad.vas_code IS NOT NULL
                                             AND xovad.attribute_level IN
                                                     ('SITE', 'CUSTOMER')
                                      UNION
                                      SELECT 1
                                        FROM oe_attachment_rule_elements_v oare
                                       WHERE     oare.attribute_name =
                                                 'Customer'
                                             AND oare.attribute_value =
                                                 TO_CHAR (
                                                     ooha.sold_to_org_id))))
                        OR (p_operation_type = 'Update')) ---- Modified the cursor query for CCR0010299
                   AND ((p_operation_type = 'Update') OR (p_order_age IS NOT NULL AND ooha.creation_date > (SYSDATE - p_order_age) AND p_operation_type = 'Assignment') OR (p_order_age IS NULL AND 1 = 1))
                   --End changes for CCR0009629
                   AND ooha.order_number =
                       NVL (p_order_num, ooha.order_number);

        CURSOR c_line_vas_emea (c_emea_header_id NUMBER)
        IS
            SELECT DISTINCT ool.line_id, ool.line_number, xciv.style_number,
                            xciv.color_code, xciv.master_class, --Added as per CCR0010027
                                                                --xciv.sub_class   --Added as per CCR0010027 Comment for CCR0010205
                                                                xciv.department, --Added for CCR0010205
                            ool.attribute14             --Added for CCR0010299
              FROM apps.oe_order_lines_all ool, oe_order_headers_all ooha, apps.oe_transaction_types_tl ott,
                   apps.oe_order_sources oos, xxd_common_items_v xciv, fnd_lookup_values flv,
                   fnd_lookup_values flv1
             WHERE     1 = 1                           ----- TESTING Condition
                   AND ool.open_flag = 'Y'
                   AND ooha.header_id = c_emea_header_id
                   AND ool.flow_status_code IN
                           ('BOOKED', 'AWAITING_SHIPPING')
                   ----   AND (( ool.attribute14 IS NULL) or (p_account_number is not null))  --Added for CCR0010299
                   AND ott.language = USERENV ('LANG')
                   AND ott.transaction_type_id = ooha.order_type_id
                   AND oos.order_source_id = ooha.order_source_id
                   AND ooha.open_flag = 'Y'
                   AND ooha.order_category_code = 'ORDER'
                   AND ooha.flow_status_code = 'BOOKED'
                   AND ooha.org_id = p_org_id      ---  this is a cp parameter
                   AND ooha.order_number =
                       NVL (p_order_num, ooha.order_number)
                   AND ooha.header_id = ool.header_id
                   AND xciv.inventory_item_id = ool.inventory_item_id
                   AND xciv.organization_id = ool.ship_from_org_id
                   AND flv.lookup_type = 'XXD_VAS_DEFAULT_ORDER_TYPES'
                   AND flv.meaning = ott.name
                   AND flv.meaning = NVL (p_tran_type, flv.meaning)
                   AND flv.enabled_flag = 'Y'
                   AND NVL (flv.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv.language = USERENV ('LANG')
                   --Add changes for CCR0009629
                   AND flv1.lookup_type = 'XXD_VAS_DEFAULT_ORDER_SOURCES'
                   AND flv1.meaning = oos.name
                   AND flv1.meaning = NVL (p_order_source, flv1.meaning)
                   AND flv1.enabled_flag = 'Y'
                   AND NVL (flv1.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv1.language = USERENV ('LANG')
                   AND (   (    (p_operation_type = 'Assignment')
                            AND (EXISTS
                                     (SELECT 1
                                        FROM xxd_ont_vas_assignment_dtls_t xovad, hz_cust_site_uses_all csu
                                       WHERE     1 = 1
                                             AND xovad.cust_account_id =
                                                 ooha.sold_to_org_id
                                             AND ooha.ship_to_org_id =
                                                 csu.site_use_id(+)
                                             AND xovad.attribute_value =
                                                 csu.cust_acct_site_id(+)
                                             AND xovad.vas_code IS NOT NULL
                                             AND xovad.attribute_level IN
                                                     ('SITE', 'CUSTOMER'))))
                        OR (p_operation_type = 'Update')) ---- Modified the cursor query for CCR0010299
                   AND ((p_operation_type = 'Update') OR (p_order_age IS NOT NULL AND ooha.creation_date > (SYSDATE - p_order_age) AND p_operation_type = 'Assignment') OR (p_order_age IS NULL AND 1 = 1));

        CURSOR c_line_vas (c_header_id NUMBER)
        IS
            SELECT DISTINCT ool.line_id, ool.line_number, xciv.style_number,
                            xciv.color_code, xciv.master_class, --Added as per CCR0010027
                                                                --xciv.sub_class   --Added as per CCR0010027 Comment for CCR0010205
                                                                xciv.department, --Added for CCR0010205
                            ool.attribute14             --Added for CCR0010299
              FROM apps.oe_order_lines_all ool, oe_order_headers_all ooha, apps.oe_transaction_types_tl ott,
                   apps.oe_order_sources oos, xxd_common_items_v xciv, fnd_lookup_values flv,
                   fnd_lookup_values flv1
             WHERE     1 = 1                           ----- TESTING Condition
                   AND ool.open_flag = 'Y'
                   AND ooha.header_id = c_header_id
                   AND ool.flow_status_code IN
                           ('BOOKED', 'AWAITING_SHIPPING')
                   AND ((ool.attribute14 IS NULL) OR (p_account_number IS NOT NULL)) --Added for CCR0010299
                   AND ott.language = USERENV ('LANG')
                   AND ott.transaction_type_id = ooha.order_type_id
                   AND oos.order_source_id = ooha.order_source_id
                   AND ooha.open_flag = 'Y'
                   AND ooha.order_category_code = 'ORDER'
                   AND ooha.flow_status_code = 'BOOKED'
                   AND ooha.org_id = p_org_id      ---  this is a cp parameter
                   AND ooha.order_number =
                       NVL (p_order_num, ooha.order_number)
                   AND ooha.header_id = ool.header_id
                   AND xciv.inventory_item_id = ool.inventory_item_id
                   AND xciv.organization_id = ool.ship_from_org_id
                   AND flv.lookup_type = 'XXD_VAS_DEFAULT_ORDER_TYPES'
                   AND flv.meaning = ott.name
                   AND flv.meaning = NVL (p_tran_type, flv.meaning)
                   AND flv.enabled_flag = 'Y'
                   AND NVL (flv.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv.language = USERENV ('LANG')
                   --Add changes for CCR0009629
                   AND flv1.lookup_type = 'XXD_VAS_DEFAULT_ORDER_SOURCES'
                   AND flv1.meaning = oos.name
                   AND flv1.meaning = NVL (p_order_source, flv1.meaning)
                   AND flv1.enabled_flag = 'Y'
                   AND NVL (flv1.end_date_active, SYSDATE + 1) > SYSDATE
                   AND flv1.language = USERENV ('LANG')
                   AND (   (    (p_operation_type = 'Assignment')
                            AND (EXISTS
                                     (SELECT 1
                                        FROM xxd_ont_vas_assignment_dtls_t xovad, hz_cust_site_uses_all csu
                                       WHERE     1 = 1
                                             AND xovad.cust_account_id =
                                                 ooha.sold_to_org_id
                                             AND ooha.ship_to_org_id =
                                                 csu.site_use_id(+)
                                             AND xovad.attribute_value =
                                                 csu.cust_acct_site_id(+)
                                             AND xovad.vas_code IS NOT NULL
                                             AND xovad.attribute_level IN
                                                     ('SITE', 'CUSTOMER'))))
                        OR ((p_operation_type = 'Update'))) ---- Modified the cursor query for CCR0010299
                   AND ((p_operation_type = 'Update') OR (p_order_age IS NOT NULL AND ooha.creation_date > (SYSDATE - p_order_age) AND p_operation_type = 'Assignment') OR (p_order_age IS NULL AND 1 = 1));

        lv_hdr_vas_code         VARCHAR2 (1000);
        lv_line_vas_code        VARCHAR2 (1000);
        lv_hdr_vas_code_emea    VARCHAR2 (1000);
        lv_line_vas_code_emea   VARCHAR2 (1000);
        ln_hdr_cnt              NUMBER := 0;
        ln_line_cnt             NUMBER := 0;
        ln_hdr_emea_cnt         NUMBER := 0;
        ln_line_emea_cnt        NUMBER := 0;
        --End changes for CCR0009629
        l_header_ids            so_hdr_line_id_tbl_type;
        l_line_ids              so_hdr_line_id_tbl_type;
        lv_cnt_org              NUMBER := 0;          --- Added for CCR0010299
        lv_cnt_org_emea         NUMBER := 0;          --- Added for CCR0010299
        lv_cnt_org_main         NUMBER := 0;          --- Added for CCR0010299
    BEGIN
        fnd_file.put_line (fnd_file.LOG, '------Program Started------');

        FOR c_hdr_vas_emea_rec IN c_hdr_vas_emea
        LOOP
            lv_hdr_vas_code_emea   := NULL;
            lv_hdr_vas_code_emea   :=
                XXD_ONT_VAS_CODE_UPDT_PKG.get_vas_code ('HEADER', c_hdr_vas_emea_rec.sold_to_org_id, NULL, NULL, NULL, NULL
                                                        , --Added as per CCR0010027
                                                          NULL --Added as per CCR0010027
                                                              );

            ---   IF lv_hdr_vas_code_emea IS NOT NULL THEN   --- Commented for deletion operation for CCR0010299
            UPDATE oe_order_headers_all ooha
               SET ooha.attribute14   = lv_hdr_vas_code_emea
             WHERE ooha.header_id = c_hdr_vas_emea_rec.header_id;

            ln_hdr_emea_cnt        := ln_hdr_emea_cnt + 1;

            fnd_file.put_line (
                fnd_file.LOG,
                'Order header update done ' || ln_hdr_emea_cnt); --- Tesing comments


            --- IF p_account_number IS NULL THEN  --- Added for CCR0010299

            IF (p_operation_type = 'Assignment')
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'OrderNumber- '
                    || c_hdr_vas_emea_rec.order_number
                    || ' with HeaderId- '
                    || c_hdr_vas_emea_rec.header_id
                    || ' updated with VAS Code- '
                    || lv_hdr_vas_code_emea);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'OrderNumber- '
                    || c_hdr_vas_emea_rec.order_number
                    || ' with HeaderId- '
                    || c_hdr_vas_emea_rec.header_id
                    || ' updated VAS Code from -'
                    || c_hdr_vas_emea_rec.attribute14
                    || ' to-'
                    || lv_hdr_vas_code_emea);
            END IF;

            ---END IF;      --- Commented for deletion operation for CCR0010299

            FOR c_line_vas_emea_rec
                IN c_line_vas_emea (c_hdr_vas_emea_rec.header_id)
            LOOP
                lv_line_vas_code_emea   := NULL;
                lv_line_vas_code_emea   :=
                    XXD_ONT_VAS_CODE_UPDT_PKG.get_vas_code (
                        'LINE',
                        c_hdr_vas_emea_rec.sold_to_org_id,
                        c_hdr_vas_emea_rec.ship_to_org_id,
                        c_line_vas_emea_rec.style_number,
                        c_line_vas_emea_rec.color_code,
                        c_line_vas_emea_rec.master_class, --Added as per CCR0010027
                        --c_line_vas_emea_rec.sub_class  --Added as per CCR0010027  Comment for CCR0010205
                        c_line_vas_emea_rec.department  --Added for CCR0010205
                                                      );

                ----  IF lv_line_vas_code_emea IS NOT NULL THEN    --- Commented for deletion operation for CCR0010299
                UPDATE oe_order_lines_all oola
                   SET oola.attribute14   = lv_line_vas_code_emea
                 WHERE oola.line_id = c_line_vas_emea_rec.line_id;

                ln_line_emea_cnt        := ln_line_emea_cnt + 1;

                --- IF p_account_number IS NULL THEN  --- Added for CCR0010299

                IF (p_operation_type = 'Assignment')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'OrderNumber- '
                        || c_hdr_vas_emea_rec.order_number
                        || ' with HeaderId- '
                        || c_hdr_vas_emea_rec.header_id
                        || ' with LineId- '
                        || c_line_vas_emea_rec.line_id
                        || ' with LineNumber- '
                        || c_line_vas_emea_rec.line_number
                        || ' updated with VAS Code- '
                        || lv_line_vas_code_emea);
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'OrderNumber- '
                        || c_hdr_vas_emea_rec.order_number
                        || ' with HeaderId- '
                        || c_hdr_vas_emea_rec.header_id
                        || ' with LineId- '
                        || c_line_vas_emea_rec.line_id
                        || ' with LineNumber- '
                        || c_line_vas_emea_rec.line_number
                        || ' updated VAS Code from- '
                        || c_line_vas_emea_rec.attribute14
                        || ' to-'
                        || lv_line_vas_code_emea);
                END IF;
            -----  END IF;  --- Commented for deletion operation for CCR0010299

            END LOOP;

            ---   END IF;    ---- Modified for CCR0010299

            ---  Start changes for CCR0010299

            SELECT COUNT (*)
              INTO lv_cnt_org_emea
              FROM fnd_lookup_values flv2
             WHERE     flv2.lookup_type = 'XXDO_VAS_HEADER_ONLY_OU_LKP'
                   AND flv2.enabled_flag = 'Y'
                   AND language = 'US'
                   AND lookup_code = p_org_id;


            IF (lv_cnt_org_emea > 0)          --- If it is EMEA Operating unit
            THEN
                update_header_vas_code (
                    pv_header_id => c_hdr_vas_emea_rec.header_id);
            END IF;
        ---  End changes for CCR0010299

        END LOOP;

        -------------------------------------------------------------------------------------------------------------------

        FOR c_hdr_vas_rec IN c_hdr_vas
        LOOP
            lv_hdr_vas_code   := NULL;
            lv_hdr_vas_code   :=
                XXD_ONT_VAS_CODE_UPDT_PKG.get_vas_code ('HEADER', c_hdr_vas_rec.sold_to_org_id, NULL, NULL, NULL, NULL
                                                        , --Added as per CCR0010027
                                                          NULL --Added as per CCR0010027
                                                              );

            ---   IF lv_hdr_vas_code IS NOT NULL THEN   --- Commented for deletion operation for CCR0010299
            UPDATE oe_order_headers_all ooha
               SET ooha.attribute14   = lv_hdr_vas_code
             WHERE ooha.header_id = c_hdr_vas_rec.header_id;

            ln_hdr_cnt        := ln_hdr_cnt + 1;

            -- IF p_account_number IS NULL THEN  --- Added for CCR0010299

            IF (p_operation_type = 'Assignment')
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'OrderNumber- '
                    || c_hdr_vas_rec.order_number
                    || ' with HeaderId- '
                    || c_hdr_vas_rec.header_id
                    || ' updated with VAS Code- '
                    || lv_hdr_vas_code);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'OrderNumber- '
                    || c_hdr_vas_rec.order_number
                    || ' with HeaderId- '
                    || c_hdr_vas_rec.header_id
                    || ' updated VAS Code from -'
                    || c_hdr_vas_rec.attribute14
                    || ' to-'
                    || lv_hdr_vas_code);
            END IF;


            ---END IF;      --- Commented for deletion operation for CCR0010299

            FOR c_line_vas_rec IN c_line_vas (c_hdr_vas_rec.header_id)
            LOOP
                lv_line_vas_code   := NULL;
                lv_line_vas_code   :=
                    XXD_ONT_VAS_CODE_UPDT_PKG.get_vas_code (
                        'LINE',
                        c_hdr_vas_rec.sold_to_org_id,
                        c_hdr_vas_rec.ship_to_org_id,
                        c_line_vas_rec.style_number,
                        c_line_vas_rec.color_code,
                        c_line_vas_rec.master_class, --Added as per CCR0010027
                        --c_line_vas_rec.sub_class  --Added as per CCR0010027  Comment for CCR0010205
                        c_line_vas_rec.department       --Added for CCR0010205
                                                 );

                ----  IF lv_line_vas_code IS NOT NULL THEN    --- Commented for deletion operation for CCR0010299
                UPDATE oe_order_lines_all oola
                   SET oola.attribute14   = lv_line_vas_code
                 WHERE oola.line_id = c_line_vas_rec.line_id;

                ln_line_cnt        := ln_line_cnt + 1;

                -- IF p_account_number IS NULL THEN  --- Added for CCR0010299

                IF (p_operation_type = 'Assignment')
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'OrderNumber- '
                        || c_hdr_vas_rec.order_number
                        || ' with HeaderId- '
                        || c_hdr_vas_rec.header_id
                        || ' with LineId- '
                        || c_line_vas_rec.line_id
                        || ' with LineNumber- '
                        || c_line_vas_rec.line_number
                        || ' updated with VAS Code- '
                        || lv_line_vas_code);
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'OrderNumber- '
                        || c_hdr_vas_rec.order_number
                        || ' with HeaderId- '
                        || c_hdr_vas_rec.header_id
                        || ' with LineId- '
                        || c_line_vas_rec.line_id
                        || ' with LineNumber- '
                        || c_line_vas_rec.line_number
                        || ' updated VAS Code from- '
                        || c_line_vas_rec.attribute14
                        || ' to-'
                        || lv_line_vas_code);
                END IF;
            -----  END IF;  --- Commented for deletion operation for CCR0010299

            END LOOP;

            ---   END IF;    ---- Modified for CCR0010299

            ---  Start changes for CCR0010299

            SELECT COUNT (*)
              INTO lv_cnt_org
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_VAS_HEADER_ONLY_OU_LKP'
                   AND language = 'US'
                   AND lookup_code = p_org_id;

            IF (lv_cnt_org > 0)               --- If it is EMEA Operating unit
            THEN
                update_header_vas_code (
                    pv_header_id => c_hdr_vas_rec.header_id);
            END IF;
        ---  End changes for CCR0010299

        END LOOP;

        SELECT COUNT (*)
          INTO lv_cnt_org_main
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXDO_VAS_HEADER_ONLY_OU_LKP'
               AND language = 'US'
               AND lookup_code = p_org_id;

        IF (lv_cnt_org_main > 0)              --- If it is EMEA Operating unit
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Header Vas Code Updated-' || ln_hdr_emea_cnt);
            fnd_file.put_line (fnd_file.LOG,
                               'Line Vas Code Updated-' || ln_line_emea_cnt);
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'Header Vas Code Updated-' || ln_hdr_cnt);
            fnd_file.put_line (fnd_file.LOG,
                               'Line Vas Code Updated-' || ln_line_cnt);
        END IF;

        fnd_file.put_line (fnd_file.LOG, '------Program End------');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in Main Procedure-' || SQLERRM);
    END main;

    --Start Added as per CCR0010027
    FUNCTION get_vas_code (p_level IN VARCHAR2, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER, p_style IN VARCHAR2, p_color IN VARCHAR2, p_master_class IN VARCHAR2 DEFAULT NULL
                           , --p_sub_class      IN VARCHAR2 DEFAULT NULL --  Comment for CCR0010205
                             p_department IN VARCHAR2 DEFAULT NULL --Added for CCR0010205
                                                                  )
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
                   --AND OAR.rule_id        = p_rule_id
                   AND oar.document_id = fdv.document_id
                   AND fdv.datatype_name = 'Short Text'
                   AND fdv.media_id = fdl.media_id
                   AND fdc.category_id = fdv.category_id
                   AND fdc.application_id = 660
                   AND fdc.user_name = 'VAS Codes'
                   AND oare.rule_id = oar.rule_id
                   AND oare.attribute_name = 'Customer'
                   AND TO_CHAR (cust.cust_account_id) = oare.attribute_value
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
                           AND attribute_level IN ('SITE')
                    UNION
                    SELECT a.vas_code
                      FROM xxd_ont_vas_assignment_dtls_t a, hz_cust_site_uses_all b
                     WHERE     a.cust_account_id = p_cust_account_id
                           AND b.site_use_id = p_site_use_id
                           AND a.attribute_level =
                               'SITE-MASTERCLASS-SUBCLASS'
                           AND a.attribute_value = b.site_use_id
                           AND (NVL (a.attribute1, '1') = NVL (l_style, '1') OR NVL (a.attribute2, '1') = NVL (p_master_class, '1') --OR NVL(a.attribute3,'1') = NVL(p_sub_class,'1')--  Comment for CCR0010205
                                                                                                                                    OR NVL (a.attribute4, '1') = NVL (p_department, '1') --Added for CCR0010205
                                                                                                                                                                                        ));
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

    --End Added as per CCR0010027

    --Start Added as per CCR0010299
    PROCEDURE update_header_vas_code (pv_header_id IN NUMBER)
    IS
        lv_vas_code       VARCHAR2 (240) := NULL;
        lv_new_vas_code   VARCHAR2 (240) := NULL;


        CURSOR c_update_hdr_vas IS
            SELECT DISTINCT ooha.header_id, --               ooha.sold_to_org_id,
                                         --               ooha.ship_to_org_id,
                             ooha.order_number, ooha.attribute14
              FROM apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
             WHERE     1 = 1
                   AND ooha.header_id = oola.header_id
                   AND ooha.header_id = pv_header_id
                   AND oola.attribute14 IS NOT NULL
                   AND ooha.open_flag = 'Y'
                   --              AND ooha.attribute14 IS NULL
                   AND ooha.order_category_code = 'ORDER'
                   AND ooha.flow_status_code = 'BOOKED';
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            '------Update header VAS code for EMEA Operating Unit  Started------');

        FOR c_update_hdr_vas_rec IN c_update_hdr_vas
        LOOP
            BEGIN
                SELECT DISTINCT attribute14
                  INTO lv_vas_code
                  FROM apps.oe_order_lines_all
                 WHERE     1 = 1
                       AND header_id = c_update_hdr_vas_rec.header_id
                       AND open_flag = 'Y';
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'OrderNumber- '
                        || c_update_hdr_vas_rec.order_number
                        || ' with HeaderId- '
                        || c_update_hdr_vas_rec.header_id
                        || ' do not have a unique VAS combination ');
            END;

            IF lv_vas_code IS NOT NULL
            THEN
                UPDATE apps.oe_order_headers_all
                   -- SET ATTRIBUTE14 = lv_vas_code
                   SET ATTRIBUTE14 = DECODE (ATTRIBUTE14, NULL, lv_vas_code, ATTRIBUTE14 || '+' || lv_vas_code)
                 WHERE 1 = 1 AND HEADER_ID = c_update_hdr_vas_rec.header_id;

                SELECT DISTINCT attribute14
                  INTO lv_new_vas_code
                  FROM apps.oe_order_headers_all
                 WHERE 1 = 1 AND header_id = c_update_hdr_vas_rec.header_id;

                UPDATE apps.oe_order_lines_all
                   SET ATTRIBUTE14   = NULL
                 WHERE 1 = 1 AND HEADER_ID = c_update_hdr_vas_rec.header_id;


                fnd_file.put_line (
                    fnd_file.LOG,
                       'EMEA OrderNumber- '
                    || c_update_hdr_vas_rec.order_number
                    || ' with HeaderId- '
                    || c_update_hdr_vas_rec.header_id
                    || ' updated with VAS Code from - '
                    || c_update_hdr_vas_rec.attribute14
                    || ' to -'
                    || lv_new_vas_code
                    -- || lv_vas_code
                    || ' The VAS code in order lines have been removed');
            END IF;
        END LOOP;
    END update_header_vas_code;
--End Added as per CCR0010299
END XXD_ONT_VAS_CODE_UPDT_PKG;
/
