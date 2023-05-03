--
-- XXD_AR_CONS_INV_GE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_CONS_INV_GE_PKG"
AS
    /****************************************************************************************
       * Package      : XXD_AR_CONS_GE_PKG
       * Design       : This package is used for GlobalE Consolidated Invoice Printing
       * Notes        :
       * Modification :
       -- ===============================================================================
       -- Date         Version#   Name                    Comments
       -- ===============================================================================
       -- 03-APR-2020  1.0       Srinath Siricilla       Initial Version
     ******************************************************************************************/
    FUNCTION directory_path
        RETURN VARCHAR2
    IS
        lv_path   VARCHAR2 (100);
    BEGIN
        SELECT directory_path
          INTO lv_path
          FROM dba_directories
         WHERE directory_name = 'XXD_AR_CONS_INV_GE_DIR';

        RETURN lv_path;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (
                apps.Fnd_File.LOG,
                'Unable to get the file path for directory');
    END directory_path;

    FUNCTION get_cons_seq (ln_inv_seq IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_value   VARCHAR2 (100);
    BEGIN
        SELECT REPLACE (TO_CHAR (ln_inv_seq, '99999'), ' ', 0)
          INTO lv_value
          FROM DUAL;

        RETURN lv_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_ar_ge_cons_bill_to (p_warehouse IN VARCHAR2, -- remember whether warehouse will be valueset or not
                                                              x_name OUT VARCHAR2, x_add_line1 OUT VARCHAR2, x_add_line2 OUT VARCHAR2, x_add_line3 OUT VARCHAR2, x_add_line4 OUT VARCHAR2, x_company_number OUT VARCHAR2, x_vat_number OUT VARCHAR2, x_email_address OUT VARCHAR2
                                     , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        lv_function_name   VARCHAR2 (100) := 'GET_AR_GE_CONS_BILL_TO';
    BEGIN
        SELECT ffvl.attribute2, ffvl.attribute3, ffvl.attribute4,
               ffvl.attribute5, ffvl.attribute6, ffvl.attribute7,
               ffvl.attribute8, ffvl.attribute9
          INTO x_name, x_add_line1, x_add_line2, x_add_line3,
                     x_add_line4, x_company_number, x_vat_number,
                     x_email_address
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE)
               AND ffvl.value_category = 'XXD_AR_CONS_BILLTO'
               AND ffvl.attribute1 = p_warehouse;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg          :=
                   'Error with Function : '
                || lv_function_name
                || ' and error is : '
                || SUBSTR (SQLERRM, 1, 200);
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in XXD_AR_CONS_BILLTO:' || SQLERRM);
            x_name             := NULL;
            x_add_line1        := NULL;
            x_add_line2        := NULL;
            x_add_line3        := NULL;
            x_add_line4        := NULL;
            x_company_number   := NULL;
            x_vat_number       := NULL;
            x_email_address    := NULL;
            RETURN FALSE;
    END;

    FUNCTION get_ar_ge_cons_bill_from (p_warehouse IN VARCHAR2, x_name OUT VARCHAR2, x_add_line1 OUT VARCHAR2, x_add_line2 OUT VARCHAR2, x_add_line3 OUT VARCHAR2, x_add_line4 OUT VARCHAR2, x_company_number OUT VARCHAR2, x_vat_number OUT VARCHAR2, x_email_address OUT VARCHAR2
                                       , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        lv_function_name   VARCHAR2 (100) := 'GET_AR_GE_CONS_BILL_FROM';
    BEGIN
        SELECT ffvl.attribute2, ffvl.attribute3, ffvl.attribute4,
               ffvl.attribute5, ffvl.attribute6, ffvl.attribute7,
               ffvl.attribute8, ffvl.attribute9
          INTO x_name, x_add_line1, x_add_line2, x_add_line3,
                     x_add_line4, x_company_number, x_vat_number,
                     x_email_address
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE)
               AND ffvl.value_category = 'XXD_AR_CONS_BILLFROM'
               AND ffvl.attribute1 = p_warehouse;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg          :=
                   'Error with Function : '
                || lv_function_name
                || ' and error is : '
                || SUBSTR (SQLERRM, 1, 200);
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in XXD_AR_CONS_BILLFROM:' || SQLERRM);
            x_name             := NULL;
            x_add_line1        := NULL;
            x_add_line2        := NULL;
            x_add_line3        := NULL;
            x_add_line4        := NULL;
            x_company_number   := NULL;
            x_vat_number       := NULL;
            x_email_address    := NULL;
            RETURN FALSE;
    END;

    FUNCTION get_ar_ge_cons_ship_from (p_warehouse   IN     VARCHAR2,
                                       x_name           OUT VARCHAR2,
                                       x_add_line1      OUT VARCHAR2,
                                       x_add_line2      OUT VARCHAR2,
                                       x_add_line3      OUT VARCHAR2,
                                       x_add_line4      OUT VARCHAR2,
                                       x_add_line5      OUT VARCHAR2,
                                       x_ret_msg        OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        lv_function_name   VARCHAR2 (100) := 'GET_AR_GE_CONS_SHIP_FROM';
    BEGIN
        SELECT ffvl.attribute2, ffvl.attribute3, ffvl.attribute4,
               ffvl.attribute5, ffvl.attribute6, ffvl.attribute7
          INTO x_name, x_add_line1, x_add_line2, x_add_line3,
                     x_add_line4, x_add_line5
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE)
               AND ffvl.value_category = 'XXD_AR_CONS_SHIPFROM'
               AND ffvl.attribute1 = p_warehouse;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg     :=
                   'Error with Function : '
                || lv_function_name
                || ' and error is : '
                || SUBSTR (SQLERRM, 1, 200);
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in XXD_AR_CONS_SHIPFROM:' || SQLERRM);
            x_name        := NULL;
            x_add_line1   := NULL;
            x_add_line2   := NULL;
            x_add_line3   := NULL;
            x_add_line4   := NULL;
            x_add_line4   := NULL;
            RETURN FALSE;
    END;

    FUNCTION get_ar_ge_cons_ship_to (p_warehouse   IN     VARCHAR2,
                                     x_name           OUT VARCHAR2,
                                     x_add_line1      OUT VARCHAR2,
                                     x_add_line2      OUT VARCHAR2,
                                     x_add_line3      OUT VARCHAR2,
                                     x_add_line4      OUT VARCHAR2,
                                     x_add_line5      OUT VARCHAR2,
                                     x_ret_msg        OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        lv_function_name   VARCHAR2 (100) := 'GET_AR_GE_CONS_SHIP_TO';
    BEGIN
        SELECT ffvl.attribute2, ffvl.attribute3, ffvl.attribute4,
               ffvl.attribute5, ffvl.attribute6, ffvl.attribute7
          INTO x_name, x_add_line1, x_add_line2, x_add_line3,
                     x_add_line4, x_add_line5
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE)
               AND ffvl.value_category = 'XXD_AR_CONS_SHIPTO'
               AND ffvl.attribute1 = p_warehouse;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg     :=
                   'Error with Function : '
                || lv_function_name
                || ' and error is : '
                || SUBSTR (SQLERRM, 1, 200);
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in XXD_AR_CONS_SHIPTO:' || SQLERRM);
            x_name        := NULL;
            x_add_line1   := NULL;
            x_add_line2   := NULL;
            x_add_line3   := NULL;
            x_add_line4   := NULL;
            x_add_line4   := NULL;
            RETURN FALSE;
    END;

    FUNCTION get_ar_ge_cons_taxstmt (p_warehouse IN VARCHAR2, x_ship_to_country OUT VARCHAR2, x_tax_stmt OUT VARCHAR2
                                     , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        lv_function_name   VARCHAR2 (100) := 'GET_AR_GE_CONS_TAXSTMT';
    BEGIN
        SELECT ffvl.attribute2, ffvl.attribute3
          INTO x_ship_to_country, x_tax_stmt
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE)
               AND ffvl.value_category = 'XXD_AR_CONS_TAXSTMT'
               AND ffvl.attribute1 = p_warehouse;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg           :=
                   'Error with Function : '
                || lv_function_name
                || ' and error is : '
                || SUBSTR (SQLERRM, 1, 200);
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in XXD_AR_CONS_TAXSTMT:' || SQLERRM);
            x_ship_to_country   := NULL;
            x_tax_stmt          := NULL;
            RETURN FALSE;
    END;

    FUNCTION get_ar_ge_cons_taxrate (p_warehouse IN VARCHAR2, x_ship_to_country OUT VARCHAR2, x_tax_rate OUT VARCHAR2
                                     , x_ret_msg OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        lv_function_name   VARCHAR2 (100) := 'GET_AR_GE_CONS_TAXRATE';
    BEGIN
        SELECT ffvl.attribute2, ffvl.attribute3
          INTO x_ship_to_country, x_tax_rate
          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
         WHERE     ffvs.flex_value_set_id = ffvl.flex_value_set_id
               AND ffvl.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                               AND NVL (ffvl.end_date_active, SYSDATE)
               AND ffvl.value_category = 'XXD_AR_CONS_TAXRATE'
               AND ffvl.attribute1 = p_warehouse;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg           :=
                   'Error with Function : '
                || lv_function_name
                || ' and error is : '
                || SUBSTR (SQLERRM, 1, 200);
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception in XXD_AR_CONS_TAXRATE:' || SQLERRM);
            x_ship_to_country   := NULL;
            x_tax_rate          := NULL;
            RETURN FALSE;
    END;

    /*FUNCTION get_line_amount (p_customer_trx_id   IN  NUMBER,
                              p_customer_line_id  IN  NUMBER)
    RETURN NUMBER
    IS
         l_amount   NUMBER;
    BEGIN
       SELECT extended_amount
         INTO l_amount
         FROM apps.ra_customer_trx_lines_all
        WHERE     customer_trx_id = p_customer_trx_id
              AND line_number = p_line_number
              AND line_type = p_line_type;

       RETURN l_amount;
    EXCEPTION
       WHEN OTHERS
       THEN
          l_amount := 0;
          RETURN l_amount;
    END;*/

    FUNCTION get_amount (p_customer_trx_id IN NUMBER, p_line_number IN NUMBER, p_line_type IN VARCHAR2)
        RETURN NUMBER
    IS
        l_amount   NUMBER;
    BEGIN
        SELECT extended_amount
          INTO l_amount
          FROM apps.ra_customer_trx_lines_all
         WHERE     customer_trx_id = p_customer_trx_id
               AND line_number = p_line_number
               AND line_type = p_line_type;

        RETURN l_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_amount   := 0;
            RETURN l_amount;
    END;

    FUNCTION insert_data
        RETURN BOOLEAN
    IS
        CURSOR get_trx_details IS
            SELECT hrou.name operating_unit, rcta.org_id, rcta.trx_number,
                   rctta.TYPE, rctta.name, hca.account_number,
                   hzp.party_name, rcta.customer_trx_id, rctla.customer_trx_line_id,
                   rctla.line_number, rctla.sales_order, rctla.warehouse_id,
                   mp.organization_code, msib.segment1 sku, msib.inventory_item_id,
                   rctla.description, rctla.quantity_ordered, rctla.unit_selling_price unit_price,
                   rcta.trx_date, rcta.creation_date, rcta.attribute5 brand,
                   rctla.interface_line_attribute6 line_id, rctla.interface_line_attribute11 discount_id, NVL (tax_code.extended_amount, 0) tax_amount,
                   tax_code.tax_rate, tax_code.vat_tax_id, tax_code.tax_rate_code,
                   tax_code.tax, rctla.line_type
              FROM apps.ra_customer_trx_all rcta,
                   apps.ra_customer_trx_lines_all rctla,
                   apps.ra_cust_trx_types_all rctta,
                   apps.mtl_parameters mp,
                   apps.mtl_system_items_b msib,
                   apps.hr_operating_units hrou,
                   apps.hz_cust_accounts hca,
                   apps.hz_parties hzp,
                   apps.oe_order_headers_all ooha,
                   apps.oe_order_lines_all oola,
                   (SELECT rctla_tax.link_to_cust_trx_line_id, rctla_tax.customer_trx_id, rctla_tax.extended_amount,
                           rctla_tax.tax_rate, rctla_tax.vat_tax_id, zxb.tax_rate_code,
                           zxb.tax
                      FROM apps.ra_customer_trx_lines_all rctla_tax, apps.zx_rates_b zxb
                     WHERE     1 = 1
                           AND zxb.tax_rate_id = rctla_tax.vat_tax_id
                           AND rctla_tax.line_type = 'TAX') tax_code
             WHERE     1 = 1
                   AND tax_code.link_to_cust_trx_line_id(+) =
                       rctla.customer_trx_line_id
                   AND rcta.bill_to_customer_id = hca.cust_account_id
                   AND hca.party_id = hzp.party_id
                   AND rcta.cust_trx_type_id = rctta.cust_trx_type_id
                   AND rcta.customer_trx_id = rctla.customer_trx_id
                   AND rcta.org_id = rctta.org_id
                   AND rctla.warehouse_id = mp.organization_id
                   AND hrou.organization_id = rcta.org_id
                   AND rctla.inventory_item_id = msib.inventory_item_id
                   AND mp.organization_id = msib.organization_id
                   AND ooha.header_id = oola.header_id
                   AND rcta.interface_header_context = 'ORDER ENTRY'
                   --                AND TO_NUMBER (rctla.interface_line_attribute6) =
                   --                       oola.line_id
                   AND rcta.interface_header_attribute1 = ooha.order_number
                   AND ooha.org_id = oola.org_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                             WHERE     ffvs.flex_value_set_name =
                                       'XXD_AR_CONS_GE_SHIP_MET_VS'
                                   AND ffvl.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           ffvl.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           ffvl.end_date_active,
                                                           SYSDATE)
                                   AND ffvl.flex_value =
                                       ooha.shipping_method_code)
                   AND rcta.org_id = NVL (p_operating_unit, rcta.org_id)
                   -- RePrint and Regenerate as N covers only new transactions where attribute2 IS NULL
                   AND p_reprint = 'N'
                   AND p_regenerate = 'N'
                   AND rcta.attribute2 IS NULL
                   AND rctla.warehouse_id =
                       NVL (p_warehouse, rctla.warehouse_id)
                   AND rcta.trx_date BETWEEN NVL (
                                                 fnd_date.canonical_to_date (
                                                     p_trx_date_from),
                                                 rcta.trx_date)
                                         AND NVL (
                                                 fnd_date.canonical_to_date (
                                                     p_trx_date_to),
                                                 rcta.trx_date)
                   AND TO_DATE (rcta.creation_date) BETWEEN NVL (
                                                                fnd_date.canonical_to_date (
                                                                    p_cr_date_from),
                                                                TO_DATE (
                                                                    rcta.creation_date))
                                                        AND NVL (
                                                                fnd_date.canonical_to_date (
                                                                    p_cr_date_to),
                                                                TO_DATE (
                                                                    rcta.creation_date))
                   AND rcta.attribute5 = NVL (p_brand, rcta.attribute5)
                   AND rctta.TYPE IN ('INV', 'CM')
                   AND rctla.line_type = 'LINE'
            UNION
            SELECT hrou.name, rcta.org_id, rcta.trx_number,
                   rctta.TYPE, rctta.name, hca.account_number,
                   hzp.party_name, rcta.customer_trx_id, rctla.customer_trx_line_id,
                   rctla.line_number, rctla.sales_order, rctla.warehouse_id,
                   mp.organization_code, msib.segment1, msib.inventory_item_id,
                   rctla.description, rctla.quantity_ordered, rctla.unit_selling_price,
                   rcta.trx_date, rcta.creation_date, rcta.attribute5,
                   rctla.interface_line_attribute6, rctla.interface_line_attribute11, NVL (tax_code.extended_amount, 0),
                   tax_code.tax_rate, tax_code.vat_tax_id, tax_code.tax_rate_code,
                   tax_code.tax, rctla.line_type
              FROM apps.ra_customer_trx_all rcta,
                   apps.ra_customer_trx_lines_all rctla,
                   apps.ra_cust_trx_types_all rctta,
                   apps.mtl_parameters mp,
                   apps.mtl_system_items_b msib,
                   apps.hr_operating_units hrou,
                   apps.hz_cust_accounts hca,
                   apps.hz_parties hzp,
                   apps.oe_order_headers_all ooha,
                   apps.oe_order_lines_all oola,
                   (SELECT rctla_tax.link_to_cust_trx_line_id, rctla_tax.customer_trx_id, rctla_tax.extended_amount,
                           rctla_tax.tax_rate, rctla_tax.vat_tax_id, zxb.tax_rate_code,
                           zxb.tax
                      FROM apps.ra_customer_trx_lines_all rctla_tax, apps.zx_rates_b zxb
                     WHERE     1 = 1
                           AND zxb.tax_rate_id = rctla_tax.vat_tax_id
                           AND rctla_tax.line_type = 'TAX') tax_code
             WHERE     1 = 1
                   AND tax_code.link_to_cust_trx_line_id(+) =
                       rctla.customer_trx_line_id
                   AND rcta.bill_to_customer_id = hca.cust_account_id
                   AND hca.party_id = hzp.party_id
                   AND rcta.cust_trx_type_id = rctta.cust_trx_type_id
                   AND rcta.customer_trx_id = rctla.customer_trx_id
                   AND rcta.org_id = rctta.org_id
                   AND rctla.warehouse_id = mp.organization_id
                   AND hrou.organization_id = rcta.org_id
                   AND rctla.inventory_item_id = msib.inventory_item_id
                   AND mp.organization_id = msib.organization_id
                   AND ooha.header_id = oola.header_id
                   AND rcta.interface_header_context = 'ORDER ENTRY'
                   --                AND rctla.interface_line_attribute6 = oola.line_id
                   AND rcta.interface_header_attribute1 = ooha.order_number
                   AND ooha.org_id = oola.org_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                             WHERE     ffvs.flex_value_set_name =
                                       'XXD_AR_CONS_GE_SHIP_MET_VS'
                                   AND ffvl.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           ffvl.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           ffvl.end_date_active,
                                                           SYSDATE)
                                   AND ffvl.flex_value =
                                       ooha.shipping_method_code)
                   AND rcta.org_id = NVL (p_operating_unit, rcta.org_id)
                   -- RePrint as N and Regenerate as Y covers OLD+NEW transactions irrespective of attribute2
                   AND p_reprint = 'N'
                   AND p_regenerate = 'Y'
                   AND rctla.warehouse_id =
                       NVL (p_warehouse, rctla.warehouse_id)
                   AND rcta.trx_date BETWEEN NVL (
                                                 fnd_date.canonical_to_date (
                                                     p_trx_date_from),
                                                 rcta.trx_date)
                                         AND NVL (
                                                 fnd_date.canonical_to_date (
                                                     p_trx_date_to),
                                                 rcta.trx_date)
                   AND TO_DATE (rcta.creation_date) BETWEEN NVL (
                                                                fnd_date.canonical_to_date (
                                                                    p_cr_date_from),
                                                                TO_DATE (
                                                                    rcta.creation_date))
                                                        AND NVL (
                                                                fnd_date.canonical_to_date (
                                                                    p_cr_date_to),
                                                                TO_DATE (
                                                                    rcta.creation_date))
                   AND NVL (rcta.attribute2, 'XYZ') =
                       NVL (p_cons_inv_number, NVL (rcta.attribute2, 'XYZ'))
                   AND rcta.attribute5 = NVL (p_brand, rcta.attribute5)
                   AND rctta.TYPE IN ('INV', 'CM')
                   AND rctla.line_type = 'LINE';

        CURSOR update_tax_cur IS
            SELECT customer_trx_id
              FROM xxdo.xxd_ar_cons_inv_ge_t
             WHERE     line_type = 'FREIGHT'
                   AND vat_tax_id IS NULL
                   AND request_id = fnd_global.conc_request_id;

        CURSOR update_seq_cur IS
            SELECT DISTINCT warehouse, request_id, vat_tax_id
              FROM xxdo.xxd_ar_cons_inv_ge_t
             WHERE request_id = fnd_global.conc_request_id;

        -- Variable declaration

        lv_bill_to_warehouse         VARCHAR2 (50);
        lv_Bill_to_name              VARCHAR2 (100);
        lv_bill_to_addr_line1        VARCHAR2 (100);
        lv_bill_to_addr_line2        VARCHAR2 (100);
        lv_bill_to_addr_line3        VARCHAR2 (100);
        lv_bill_to_addr_line4        VARCHAR2 (100);
        ln_bill_to_comp_number       NUMBER;
        lv_bill_to_vat_number        VARCHAR2 (100);
        lv_bill_to_email             VARCHAR2 (100);
        --
        lv_bill_from_warehouse       VARCHAR2 (50);
        lv_Bill_from_name            VARCHAR2 (100);
        lv_bill_from_addr_line1      VARCHAR2 (100);
        lv_bill_from_addr_line2      VARCHAR2 (100);
        lv_bill_from_addr_line3      VARCHAR2 (100);
        lv_bill_from_addr_line4      VARCHAR2 (100);
        ln_bill_from_comp_number     NUMBER;
        lv_bill_from_vat_number      VARCHAR2 (100);
        lv_bill_from_email           VARCHAR2 (100);
        --
        lv_ship_from_warehouse       VARCHAR2 (50);
        lv_ship_from_name            VARCHAR2 (100);
        lv_ship_from_addr_line1      VARCHAR2 (100);
        lv_ship_from_addr_line2      VARCHAR2 (100);
        lv_ship_from_addr_line3      VARCHAR2 (100);
        lv_ship_from_addr_line4      VARCHAR2 (100);
        lv_ship_from_addr_line5      VARCHAR2 (100);
        --
        lv_ship_to_warehouse         VARCHAR2 (50);
        lv_ship_to_name              VARCHAR2 (100);
        lv_ship_to_addr_line1        VARCHAR2 (100);
        lv_ship_to_addr_line2        VARCHAR2 (100);
        lv_ship_to_addr_line3        VARCHAR2 (100);
        lv_ship_to_addr_line4        VARCHAR2 (100);
        lv_ship_to_addr_line5        VARCHAR2 (100);
        --
        lv_taxstmt_warehouse         VARCHAR2 (50);
        lv_taxstmt_ship_to_country   VARCHAR2 (50);
        lv_taxstmt_stmt              VARCHAR2 (240);
        --
        lv_taxrate_warehouse         VARCHAR2 (50);
        lv_taxrate_ship_to_country   VARCHAR2 (50);
        lv_taxrate_rate              VARCHAR2 (100);

        lv_bill_to_boolean           BOOLEAN;
        lv_bill_to_ret_msg           VARCHAR2 (4000);
        lv_bill_from_boolean         BOOLEAN;
        lv_bill_from_ret_msg         VARCHAR2 (4000);
        lv_ship_from_boolean         BOOLEAN;
        lv_ship_from_ret_msg         VARCHAR2 (4000);
        lv_ship_to_boolean           BOOLEAN;
        lv_ship_to_ret_msg           VARCHAR2 (4000);
        lv_taxstmt_boolean           BOOLEAN;
        lv_taxstmt_ret_msg           VARCHAR2 (4000);
        lv_taxrate_boolean           BOOLEAN;
        lv_taxrate_ret_msg           VARCHAR2 (4000);
        ln_tax_amount                NUMBER;
        ln_freight_amount            NUMBER;
        ln_item_total                NUMBER;
        ln_total_amount              NUMBER;
        ln_cons_inv_seq              NUMBER;
        ln_inv_seq                   NUMBER;
        ln_vat_tax_id                NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Start of the Program');

        fnd_file.put_line (fnd_file.LOG, 'Printing the Program Parameters');

        fnd_file.put_line (fnd_file.LOG, '---------------------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'p_operating_unit - ' || p_operating_unit);
        fnd_file.put_line (fnd_file.LOG, 'p_Reprint - ' || p_Reprint);
        fnd_file.put_line (fnd_file.LOG, 'p_warehouse - ' || p_warehouse);
        fnd_file.put_line (fnd_file.LOG,
                           'p_trx_date_from - ' || p_trx_date_from);
        fnd_file.put_line (fnd_file.LOG, 'p_trx_date_to - ' || p_trx_date_to);
        fnd_file.put_line (fnd_file.LOG, 'p_send_email - ' || p_send_email);
        fnd_file.put_line (fnd_file.LOG,
                           'p_cons_inv_number - ' || p_cons_inv_number);
        fnd_file.put_line (fnd_file.LOG,
                           'p_cr_date_from - ' || p_cr_date_from);
        fnd_file.put_line (fnd_file.LOG, 'p_cr_date_to - ' || p_cr_date_to);
        fnd_file.put_line (fnd_file.LOG, 'p_brand - ' || p_brand);
        fnd_file.put_line (fnd_file.LOG, 'p_cc_email - ' || p_cc_email);
        fnd_file.put_line (fnd_file.LOG, 'p_regenerate - ' || p_regenerate);
        fnd_file.put_line (fnd_file.LOG,
                           'p_line_details - ' || p_line_details);


        IF p_regenerate = 'Y' AND p_Reprint = 'Y'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Invalid Combination of Regenerate and Reprint Flag');
            RETURN FALSE;
        END IF;

        lv_bill_to_warehouse         := NULL;
        lv_Bill_to_name              := NULL;
        lv_bill_to_addr_line1        := NULL;
        lv_bill_to_addr_line2        := NULL;
        lv_bill_to_addr_line3        := NULL;
        lv_bill_to_addr_line4        := NULL;
        ln_bill_to_comp_number       := NULL;
        lv_bill_to_vat_number        := NULL;
        lv_bill_to_email             := NULL;
        --
        lv_bill_from_warehouse       := NULL;
        lv_Bill_from_name            := NULL;
        lv_bill_from_addr_line1      := NULL;
        lv_bill_from_addr_line2      := NULL;
        lv_bill_from_addr_line3      := NULL;
        lv_bill_from_addr_line4      := NULL;
        ln_bill_from_comp_number     := NULL;
        lv_bill_from_vat_number      := NULL;
        lv_bill_from_email           := NULL;
        --
        lv_ship_from_warehouse       := NULL;
        lv_ship_from_name            := NULL;
        lv_ship_from_addr_line1      := NULL;
        lv_ship_from_addr_line2      := NULL;
        lv_ship_from_addr_line3      := NULL;
        lv_ship_from_addr_line4      := NULL;
        lv_ship_from_addr_line5      := NULL;
        --
        lv_ship_to_warehouse         := NULL;
        lv_ship_to_name              := NULL;
        lv_ship_to_addr_line1        := NULL;
        lv_ship_to_addr_line2        := NULL;
        lv_ship_to_addr_line3        := NULL;
        lv_ship_to_addr_line4        := NULL;
        lv_ship_to_addr_line5        := NULL;
        --
        lv_taxstmt_warehouse         := NULL;
        lv_taxstmt_ship_to_country   := NULL;
        lv_taxstmt_stmt              := NULL;
        --
        lv_taxrate_warehouse         := NULL;
        lv_taxrate_ship_to_country   := NULL;
        lv_taxrate_rate              := NULL;
        ln_tax_amount                := NULL;
        ln_freight_amount            := NULL;
        ln_item_total                := NULL;
        ln_total_amount              := NULL;
        ln_cons_inv_seq              := NULL;
        ln_inv_seq                   := NULL;
        ln_vat_tax_id                := NULL;

        FOR i IN get_trx_details
        LOOP
            fnd_file.put_line (fnd_file.LOG,
                               'Start of the Program in the loop');
            lv_Bill_to_name              := NULL;
            lv_bill_to_addr_line1        := NULL;
            lv_bill_to_addr_line2        := NULL;
            lv_bill_to_addr_line3        := NULL;
            lv_bill_to_addr_line4        := NULL;
            ln_bill_to_comp_number       := NULL;
            lv_bill_to_vat_number        := NULL;
            lv_bill_to_email             := NULL;
            lv_bill_to_boolean           := NULL;
            lv_bill_to_ret_msg           := NULL;

            lv_bill_to_boolean           :=
                get_ar_ge_cons_bill_to (p_warehouse => i.organization_code, x_name => lv_Bill_to_name, x_add_line1 => lv_bill_to_addr_line1, x_add_line2 => lv_bill_to_addr_line2, x_add_line3 => lv_bill_to_addr_line3, x_add_line4 => lv_bill_to_addr_line4, x_company_number => ln_bill_to_comp_number, x_vat_number => lv_bill_to_vat_number, x_email_address => lv_bill_to_email
                                        , x_ret_msg => lv_bill_to_ret_msg);


            --         fnd_file.put_line (fnd_file.LOG,
            --                            'lv_bill_to_ret_msg - ' || lv_bill_to_ret_msg);

            lv_bill_from_warehouse       := NULL;
            lv_Bill_from_name            := NULL;
            lv_bill_from_addr_line1      := NULL;
            lv_bill_from_addr_line2      := NULL;
            lv_bill_from_addr_line3      := NULL;
            lv_bill_from_addr_line4      := NULL;
            ln_bill_from_comp_number     := NULL;
            lv_bill_from_vat_number      := NULL;
            lv_bill_from_email           := NULL;
            lv_bill_from_boolean         := NULL;
            lv_bill_from_ret_msg         := NULL;

            lv_bill_from_boolean         :=
                get_ar_ge_cons_bill_from (p_warehouse => i.organization_code, x_name => lv_Bill_from_name, x_add_line1 => lv_bill_from_addr_line1, x_add_line2 => lv_bill_from_addr_line2, x_add_line3 => lv_bill_from_addr_line3, x_add_line4 => lv_bill_from_addr_line4, x_company_number => ln_bill_from_comp_number, x_vat_number => lv_bill_from_vat_number, x_email_address => lv_bill_from_email
                                          , x_ret_msg => lv_bill_from_ret_msg);

            --         fnd_file.put_line (
            --            fnd_file.LOG,
            --            'lv_bill_from_ret_msg - ' || lv_bill_from_ret_msg);

            lv_ship_from_warehouse       := NULL;
            lv_ship_from_name            := NULL;
            lv_ship_from_addr_line1      := NULL;
            lv_ship_from_addr_line2      := NULL;
            lv_ship_from_addr_line3      := NULL;
            lv_ship_from_addr_line4      := NULL;
            lv_ship_from_addr_line5      := NULL;
            lv_ship_from_boolean         := NULL;
            lv_ship_from_ret_msg         := NULL;

            lv_ship_from_boolean         :=
                get_ar_ge_cons_ship_from (
                    p_warehouse   => i.organization_code,
                    x_name        => lv_ship_from_name,
                    x_add_line1   => lv_ship_from_addr_line1,
                    x_add_line2   => lv_ship_from_addr_line2,
                    x_add_line3   => lv_ship_from_addr_line3,
                    x_add_line4   => lv_ship_from_addr_line4,
                    x_add_line5   => lv_ship_from_addr_line5,
                    x_ret_msg     => lv_ship_from_ret_msg);

            --         fnd_file.put_line (
            --            fnd_file.LOG,
            --            'lv_ship_from_ret_msg - ' || lv_ship_from_ret_msg);

            --
            lv_ship_to_warehouse         := NULL;
            lv_ship_to_name              := NULL;
            lv_ship_to_addr_line1        := NULL;
            lv_ship_to_addr_line2        := NULL;
            lv_ship_to_addr_line3        := NULL;
            lv_ship_to_addr_line4        := NULL;
            lv_ship_to_addr_line5        := NULL;
            lv_ship_to_boolean           := NULL;
            lv_ship_to_ret_msg           := NULL;
            --

            lv_ship_to_boolean           :=
                get_ar_ge_cons_ship_to (
                    p_warehouse   => i.organization_code,
                    x_name        => lv_ship_to_name,
                    x_add_line1   => lv_ship_to_addr_line1,
                    x_add_line2   => lv_ship_to_addr_line2,
                    x_add_line3   => lv_ship_to_addr_line3,
                    x_add_line4   => lv_ship_to_addr_line4,
                    x_add_line5   => lv_ship_to_addr_line5,
                    x_ret_msg     => lv_ship_to_ret_msg);

            --         fnd_file.put_line (fnd_file.LOG,
            --                            'lv_ship_to_ret_msg - ' || lv_ship_to_ret_msg);

            lv_taxstmt_warehouse         := NULL;
            lv_taxstmt_ship_to_country   := NULL;
            lv_taxstmt_stmt              := NULL;
            lv_taxstmt_boolean           := NULL;
            lv_taxstmt_ret_msg           := NULL;
            --

            lv_taxstmt_boolean           :=
                get_ar_ge_cons_taxstmt (p_warehouse => i.organization_code, x_ship_to_country => lv_taxstmt_ship_to_country, x_tax_stmt => lv_taxstmt_stmt
                                        , x_ret_msg => lv_taxstmt_ret_msg);

            --         fnd_file.put_line (fnd_file.LOG,
            --                            'lv_taxstmt_ret_msg - ' || lv_taxstmt_ret_msg);

            lv_taxrate_warehouse         := NULL;
            lv_taxrate_ship_to_country   := NULL;
            lv_taxrate_rate              := NULL;
            lv_taxrate_boolean           := NULL;
            lv_taxrate_ret_msg           := NULL;

            lv_taxrate_boolean           :=
                get_ar_ge_cons_taxrate (p_warehouse => i.organization_code, x_ship_to_country => lv_taxrate_ship_to_country, x_tax_rate => lv_taxrate_rate
                                        , x_ret_msg => lv_taxrate_ret_msg);

            --         fnd_file.put_line (fnd_file.LOG,
            --                            'lv_taxrate_ret_msg - ' || lv_taxrate_ret_msg);

            ln_tax_amount                := NULL;

            ln_tax_amount                :=
                get_amount (p_customer_trx_id   => i.customer_trx_id,
                            p_line_number       => i.line_number,
                            p_line_type         => 'TAX');

            ln_freight_amount            := NULL;

            ln_freight_amount            :=
                get_amount (p_customer_trx_id   => i.customer_trx_id,
                            p_line_number       => i.line_number,
                            p_line_type         => 'FREIGHT');
            ln_item_total                := NULL;
            ln_total_amount              := NULL;
            ln_item_total                :=
                NVL (i.quantity_ordered, 0) * NVL (i.Unit_price, 0);
            ln_total_amount              :=
                  NVL (ln_item_total, 0)
                + NVL (ln_tax_amount, 0)
                + NVL (ln_freight_amount, 0);

            IF     lv_bill_to_boolean
               AND lv_bill_from_boolean
               AND lv_ship_from_boolean
               AND lv_ship_to_boolean
            THEN
                BEGIN
                    INSERT INTO XXDO.XXD_AR_CONS_INV_GE_T (
                                    operating_unit,
                                    trx_number,
                                    trx_type,
                                    trx_type_name,
                                    account_number,
                                    party_name,
                                    customer_trx_id,
                                    customer_trx_line_id,
                                    trx_line_number,
                                    sales_order,
                                    warehouse,
                                    inventory_item_id,
                                    sku,
                                    trx_line_desc,
                                    quantity,
                                    unit_selling_price,
                                    freight_amount,
                                    item_total,
                                    total_amount,
                                    org_id,
                                    trx_date,
                                    trx_creation_date,
                                    brand,
                                    order_line_id,
                                    discount_adj_id,
                                    status,
                                    printed,
                                    tax_amount,
                                    tax_rate,
                                    vat_tax_id,
                                    tax_rate_code,
                                    tax_code,
                                    Bill_to_name,
                                    bill_to_addr_line1,
                                    bill_to_addr_line2,
                                    bill_to_addr_line3,
                                    bill_to_addr_line4,
                                    bill_to_comp_number,
                                    bill_to_vat_number,
                                    bill_to_email,
                                    Bill_from_name,
                                    bill_from_addr_line1,
                                    bill_from_addr_line2,
                                    bill_from_addr_line3,
                                    bill_from_addr_line4,
                                    bill_from_comp_number,
                                    bill_from_vat_number,
                                    bill_from_email,
                                    ship_from_name,
                                    ship_from_addr_line1,
                                    ship_from_addr_line2,
                                    ship_from_addr_line3,
                                    ship_from_addr_line4,
                                    ship_from_addr_line5,
                                    ship_to_name,
                                    ship_to_addr_line1,
                                    ship_to_addr_line2,
                                    ship_to_addr_line3,
                                    ship_to_addr_line4,
                                    ship_to_addr_line5,
                                    taxstmt_ship_to_country,
                                    taxstmt_stmt,
                                    taxrate_ship_to_country,
                                    taxrate_rate,
                                    sequence_num,
                                    cons_invoice_num,
                                    date_of_issue,
                                    request_id,
                                    email_address,
                                    creation_date,
                                    Created_by,
                                    updated_by,
                                    updated_date,
                                    line_details,
                                    line_type)
                         VALUES (i.operating_unit, i.trx_number, i.TYPE --i.trx_type
                                                                       ,
                                 i.name                      --i.trx_type_name
                                       , i.account_number, i.party_name,
                                 i.customer_trx_id, i.customer_trx_line_id, i.line_number --i.trx_line_number
                                                                                         , i.sales_order, i.warehouse_id -- ID passed to VARCHAR Column
                                                                                                                        , i.inventory_item_id, i.sku, i.description, i.quantity_ordered, i.unit_price, ln_freight_amount, ln_item_total, ln_total_amount, i.org_id, i.trx_date, i.creation_date, i.brand, i.line_id, i.discount_id, NULL, NULL, i.tax_amount, --ln_tax_amount,
                                                                                                                                                                                                                                                                                                                                                              i.tax_rate, i.vat_tax_id, i.tax_rate_code, i.tax, lv_Bill_to_name, lv_bill_to_addr_line1, lv_bill_to_addr_line2, lv_bill_to_addr_line3, lv_bill_to_addr_line4, ln_bill_to_comp_number, lv_bill_to_vat_number, lv_bill_to_email, lv_Bill_from_name, lv_bill_from_addr_line1, lv_bill_from_addr_line2, lv_bill_from_addr_line3, lv_bill_from_addr_line4, ln_bill_from_comp_number, lv_bill_from_vat_number, lv_bill_from_email, lv_ship_from_name, lv_ship_from_addr_line1, lv_ship_from_addr_line2, lv_ship_from_addr_line3, lv_ship_from_addr_line4, lv_ship_from_addr_line5, lv_ship_to_name, lv_ship_to_addr_line1, lv_ship_to_addr_line2, lv_ship_to_addr_line3, lv_ship_to_addr_line4, lv_ship_to_addr_line5, lv_taxstmt_ship_to_country, lv_taxstmt_stmt, lv_taxrate_ship_to_country, lv_taxrate_rate, NULL --ln_cons_inv_seq                                 --i.sequence_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , NULL --i.cons_invoice_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , TO_CHAR (TO_DATE (SYSDATE, 'DD-MON-RRRR'), 'fmDD MONTH RRRR') --to_char(to_date(SYSDATE,'DDMONRRRR'),'fmDD MONTH RRRR')                              --i.date_of_issue
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   , fnd_global.conc_request_id, lv_bill_to_email, SYSDATE, fnd_global.user_id, fnd_global.user_id
                                 , SYSDATE, p_line_details, i.line_type);
                --RETURN TRUE;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            ' exception error is - : ' || SQLERRM);
                        RETURN FALSE;
                END;
            END IF;
        END LOOP;

        FOR upd_tax_freight IN update_tax_cur
        LOOP
            apps.fnd_file.put_line (
                fnd_file.LOG,
                'Entered to update the VAT ID which is NULL');
            ln_vat_tax_id   := NULL;

            BEGIN
                SELECT vat_tax_id
                  INTO ln_vat_tax_id
                  FROM apps.ra_customer_trx_lines_all
                 WHERE     customer_trx_id = upd_tax_freight.customer_trx_id
                       AND line_type = 'TAX'
                       AND vat_tax_id IS NOT NULL
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_vat_tax_id   := NULL;
            END;

            apps.fnd_file.put_line (
                fnd_file.LOG,
                'VAT ID value for update : ' || ln_vat_tax_id);

            IF ln_vat_tax_id IS NOT NULL
            THEN
                UPDATE xxdo.xxd_ar_cons_inv_ge_t
                   SET vat_tax_id   = ln_vat_tax_id
                 WHERE     customer_trx_id = upd_tax_freight.customer_trx_id
                       AND line_type = 'FREIGHT'
                       AND vat_tax_id IS NULL
                       AND request_id = fnd_global.conc_request_id;
            END IF;
        END LOOP;

        FOR upd IN update_seq_cur
        LOOP
            --         fnd_file.put_line (fnd_file.LOG, ' Looping for seq updation');
            ln_cons_inv_seq   := NULL;
            ln_inv_seq        := NULL;

            SELECT XXDO.XXD_AR_CONS_INV_GE_S.NEXTVAL
              INTO ln_inv_seq
              FROM DUAL;


            ln_cons_inv_seq   := get_cons_seq (ln_inv_seq);

            UPDATE xxdo.xxd_ar_cons_inv_ge_t
               SET cons_invoice_num = 'GE-' || get_cons_seq (ln_inv_seq), sequence_num = ln_inv_seq
             WHERE     warehouse = upd.warehouse
                   AND request_id = upd.request_id
                   AND vat_tax_id = upd.vat_tax_id;
        END LOOP;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               ' Begin Error Exception  : ' || SQLERRM);

            RETURN FALSE;
    END insert_data;

    FUNCTION submit_bursting
        RETURN BOOLEAN
    AS
        CURSOR update_trx_attr_cur IS
              SELECT customer_trx_id, cons_invoice_num
                FROM xxdo.xxd_ar_cons_inv_ge_t
               WHERE request_id = fnd_global.conc_request_id
            GROUP BY customer_trx_id, cons_invoice_num;


        lb_result         BOOLEAN := TRUE;
        ln_req_id         NUMBER;
        ln_data_count     NUMBER;
        lc_flag           VARCHAR2 (2);
        lv_cons_inv_num   VARCHAR2 (100);
    --print_output_rec   print_output_cur%ROWTYPE;
    BEGIN
        SELECT SUM (xx.count_val)
          INTO ln_data_count
          FROM (SELECT COUNT (1) count_val
                  FROM xxdo.xxd_ar_cons_inv_ge_t
                 WHERE request_id = fnd_global.conc_request_id
                UNION
                SELECT COUNT (1) count_val
                  FROM xxdo.xxd_ar_cons_inv_ge_t
                 WHERE     1 = 1
                       AND org_id = NVL (p_operating_unit, org_id)
                       AND p_regenerate = 'N'
                       AND p_reprint = 'Y'
                       AND warehouse = NVL (p_warehouse, warehouse)
                       AND cons_invoice_num =
                           NVL (p_cons_inv_number, cons_invoice_num)
                       AND TRUNC (trx_date) BETWEEN NVL (p_trx_date_from,
                                                         trx_date)
                                                AND NVL (p_trx_date_to,
                                                         trx_date)
                       AND TRUNC (trx_creation_date) BETWEEN NVL (
                                                                 p_cr_date_from,
                                                                 trx_creation_date)
                                                         AND NVL (
                                                                 p_cr_date_to,
                                                                 trx_creation_date)
                       AND brand = NVL (p_brand, brand)) xx;

        IF p_send_email = 'Y' AND ln_data_count > 0
        THEN
            ln_req_id   :=
                fnd_request.submit_request (
                    application   => 'XDO',
                    program       => 'XDOBURSTREP',
                    description   => 'Bursting',
                    argument1     => 'Y',
                    argument2     => fnd_global.conc_request_id,
                    argument3     => 'Y');

            IF ln_req_id != 0
            THEN
                FOR upd_attr IN update_trx_attr_cur
                LOOP
                    UPDATE ra_customer_trx_all
                       SET attribute2 = upd_attr.cons_invoice_num, creation_date = SYSDATE, last_update_date = SYSDATE,
                           last_updated_by = fnd_global.user_id
                     WHERE customer_trx_id = upd_attr.customer_trx_id;
                END LOOP;

                lb_result   := TRUE;
            ELSE
                fnd_file.put_line (fnd_file.LOG,
                                   'Failed to launch bursting request');
                lb_result   := FALSE;
            END IF;
        ELSIF ln_data_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'No Data Found; Skipping Bursting Program');
        END IF;

        RETURN lb_result;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in SUBMIT_BURSTING: ' || SQLERRM);
            RETURN FALSE;
    END submit_bursting;
END XXD_AR_CONS_INV_GE_PKG;
/
