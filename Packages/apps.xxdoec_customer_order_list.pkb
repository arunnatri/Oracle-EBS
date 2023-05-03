--
-- XXDOEC_CUSTOMER_ORDER_LIST  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_CUSTOMER_ORDER_LIST"
AS
    PROCEDURE get_customer_list (
        p_customer_number        IN     VARCHAR2,
        p_party_name             IN     VARCHAR2,
        p_email_address          IN     VARCHAR2,
        p_customer_postal_code   IN     VARCHAR2,
        p_customer_state         IN     VARCHAR2,
        p_phone_number           IN     VARCHAR2,
        p_rownum                 IN     VARCHAR2,
        o_customer_lst              OUT SYS_REFCURSOR)
    IS
        --v_party_name          VARCHAR2 (360);
        v_email_address   VARCHAR2 (2000);
    BEGIN
        --v_party_name :=    '%'||UPPER(p_party_name)||'%';
        --v_email_address := '%'||UPPER(p_email_address)||'%';
        v_email_address   := UPPER (p_email_address);

        OPEN o_customer_lst FOR
            SELECT DISTINCT CASE
                                WHEN SUBSTR (
                                         hca.account_number,
                                         1,
                                         2) =
                                     'DW'
                                THEN
                                    SUBSTR (
                                        hca.account_number,
                                        3)
                                WHEN SUBSTR (
                                         hca.account_number,
                                         1,
                                         2) =
                                     '90'
                                THEN
                                    SUBSTR (
                                        hca.account_number,
                                        3)
                                WHEN SUBSTR (
                                         hca.account_number,
                                         1,
                                         2) =
                                     '99'
                                THEN
                                    SUBSTR (
                                        hca.account_number,
                                        3)
                                ELSE
                                    hca.account_number
                            END customer_number,
                            hp.party_name,
                            hp.party_type,
                            hp.person_first_name,
                            hp.person_last_name,
                            hl.state,
                            hl.postal_code,
                            hp.email_address,
                            hp.primary_phone_number phone,
                            SUBSTR (hca.attribute18,
                                    1,
                                      INSTR (hca.attribute18, '-', 1,
                                             1)
                                    - 1) Brand
              FROM hz_parties hp, hz_party_sites hps, hz_locations hl,
                   hz_cust_accounts_all hca, hz_cust_acct_sites_all hcsa, hz_cust_site_uses_all hcsu
             WHERE     hp.party_id = hps.party_id
                   AND hps.location_id = hl.location_id
                   AND hp.party_id = hca.party_id
                   AND hcsa.party_site_id = hps.party_site_id
                   AND hcsu.cust_acct_site_id = hcsa.cust_acct_site_id
                   AND hca.cust_account_id = hcsa.cust_account_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hca.account_number = p_customer_number
                   AND p_party_name IS NULL
                   AND p_email_address IS NULL
                   AND p_customer_postal_code IS NULL
                   AND p_customer_state IS NULL
                   AND p_phone_number IS NULL
            UNION ALL
            SELECT DISTINCT CASE
                                WHEN SUBSTR (hca.account_number, 1, 2) = 'DW'
                                THEN
                                    SUBSTR (hca.account_number, 3)
                                WHEN SUBSTR (hca.account_number, 1, 2) = '90'
                                THEN
                                    SUBSTR (hca.account_number, 3)
                                WHEN SUBSTR (hca.account_number, 1, 2) = '99'
                                THEN
                                    SUBSTR (hca.account_number, 3)
                                ELSE
                                    hca.account_number
                            END customer_number,
                            hp.party_name,
                            hp.party_type,
                            hp.person_first_name,
                            hp.person_last_name,
                            hl.state,
                            hl.postal_code,
                            hp.email_address,
                            hp.primary_phone_number phone,
                            SUBSTR (hca.attribute18,
                                    1,
                                      INSTR (hca.attribute18, '-', 1,
                                             1)
                                    - 1) Brand
              FROM hz_parties hp, hz_party_sites hps, hz_locations hl,
                   hz_cust_accounts_all hca, hz_cust_acct_sites_all hcsa, hz_cust_site_uses_all hcsu
             WHERE     hp.party_id = hps.party_id
                   AND hps.location_id = hl.location_id
                   AND hp.party_id = hca.party_id
                   AND hcsa.party_site_id = hps.party_site_id
                   AND hcsu.cust_acct_site_id = hcsa.cust_acct_site_id
                   AND hca.cust_account_id = hcsa.cust_account_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND p_customer_number IS NULL
                   --AND  UPPER(hp.party_name) LIKE  v_party_name
                   AND UPPER (hp.party_name) LIKE UPPER (p_party_name)
                   AND NVL (UPPER (hp.email_address), 'X') =
                       NVL (UPPER (v_email_address),
                            (SELECT NVL (UPPER (hp1.email_address), 'X')
                               FROM hz_parties hp1
                              WHERE hp1.party_id = hp.party_id))
                   AND NVL (UPPER (hl.postal_code), 'X') =
                       NVL (UPPER (p_customer_postal_code),
                            (SELECT NVL (UPPER (hp1.postal_code), 'X')
                               FROM hz_parties hp1
                              WHERE hp1.party_id = hp.party_id))
                   AND NVL (UPPER (hp.state), 'X') =
                       NVL (p_customer_state,
                            (SELECT NVL (UPPER (hp1.state), 'X')
                               FROM hz_parties hp1
                              WHERE hp1.party_id = hp.party_id))
                   AND NVL (
                           UPPER (
                               REGEXP_REPLACE (hp.primary_phone_number, '-')),
                           'X') =
                       NVL (
                           UPPER (REGEXP_REPLACE (p_phone_number, '-')),
                           (SELECT NVL (UPPER (REGEXP_REPLACE (hp1.primary_phone_number, '-')), 'X')
                              FROM hz_parties hp1
                             WHERE hp1.party_id = hp.party_id))
                   AND ROWNUM <= p_rownum
            UNION ALL
            SELECT DISTINCT CASE
                                WHEN SUBSTR (hca.account_number, 1, 2) = 'DW'
                                THEN
                                    SUBSTR (hca.account_number, 3)
                                WHEN SUBSTR (hca.account_number, 1, 2) = '90'
                                THEN
                                    SUBSTR (hca.account_number, 3)
                                WHEN SUBSTR (hca.account_number, 1, 2) = '99'
                                THEN
                                    SUBSTR (hca.account_number, 3)
                                ELSE
                                    hca.account_number
                            END customer_number,
                            hp.party_name,
                            hp.party_type,
                            hp.person_first_name,
                            hp.person_last_name,
                            hl.state,
                            hl.postal_code,
                            hp.email_address,
                            hp.primary_phone_number phone,
                            SUBSTR (hca.attribute18,
                                    1,
                                      INSTR (hca.attribute18, '-', 1,
                                             1)
                                    - 1) Brand
              FROM hz_parties hp, hz_party_sites hps, hz_locations hl,
                   hz_cust_accounts_all hca, hz_cust_acct_sites_all hcsa, hz_cust_site_uses_all hcsu
             WHERE     hp.party_id = hps.party_id
                   AND hps.location_id = hl.location_id
                   AND hp.party_id = hca.party_id
                   AND hcsa.party_site_id = hps.party_site_id
                   AND hcsu.cust_acct_site_id = hcsa.cust_acct_site_id
                   AND hca.cust_account_id = hcsa.cust_account_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND p_customer_number IS NULL
                   AND p_party_name IS NULL
                   AND UPPER (hp.email_address) = UPPER (p_email_address)
                   --NVL (UPPER(v_email_address),
                   --    (SELECT NVL(UPPER (hp1.email_address),'X')
                   --      FROM hz_parties hp1
                   -- WHERE hp1.party_id = hp.party_id))
                   AND NVL (UPPER (hl.postal_code), 'X') =
                       NVL (UPPER (p_customer_postal_code),
                            (SELECT NVL (UPPER (hp1.postal_code), 'X')
                               FROM hz_parties hp1
                              WHERE hp1.party_id = hp.party_id))
                   AND NVL (UPPER (hp.state), 'X') =
                       NVL (p_customer_state,
                            (SELECT NVL (UPPER (hp1.state), 'X')
                               FROM hz_parties hp1
                              WHERE hp1.party_id = hp.party_id))
                   /*AND NVL(UPPER(hp.primary_phone_number),'X') =
                    NVL(p_phone_number,
                         (SELECT NVL(UPPER (hp1.primary_phone_number),'X')
                            FROM hz_parties hp1
                           WHERE hp1.party_id = hp.party_id))*/
                   AND NVL (
                           UPPER (
                               REGEXP_REPLACE (hp.primary_phone_number, '-')),
                           'X') =
                       NVL (
                           UPPER (REGEXP_REPLACE (p_phone_number, '-')),
                           (SELECT NVL (UPPER (REGEXP_REPLACE (hp1.primary_phone_number, '-')), 'X')
                              FROM hz_parties hp1
                             WHERE hp1.party_id = hp.party_id))
            ORDER BY 2, 1;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE (SQLERRM);
    END;

    PROCEDURE get_customer_order_lst (
        p_customer_number    IN     VARCHAR2,
        o_cus_order_detail      OUT t_cus_order_detail_cursor)
    IS
    BEGIN
        OPEN o_cus_order_detail FOR
            SELECT CASE                              -- un-prefix order number
                       WHEN SUBSTR (
                                ooh.orig_sys_document_ref,
                                1,
                                2) =
                            'DW'
                       THEN
                           SUBSTR (
                               ooh.orig_sys_document_ref,
                               3)
                       WHEN SUBSTR (
                                ooh.orig_sys_document_ref,
                                1,
                                2) =
                            '90'
                       THEN
                           SUBSTR (
                               ooh.orig_sys_document_ref,
                               3)
                       WHEN SUBSTR (
                                ooh.orig_sys_document_ref,
                                1,
                                2) =
                            '99'
                       THEN
                           SUBSTR (
                               ooh.orig_sys_document_ref,
                               3)
                       ELSE
                           ooh.orig_sys_document_ref
                   END order_number,
                   ooh.ordered_date ord_date,
                   CASE                           -- un-prefix customer number
                       WHEN SUBSTR (
                                hca.account_number,
                                1,
                                2) =
                            'DW'
                       THEN
                           SUBSTR (
                               hca.account_number,
                               3)
                       WHEN SUBSTR (
                                hca.account_number,
                                1,
                                2) =
                            '90'
                       THEN
                           SUBSTR (
                               hca.account_number,
                               3)
                       WHEN SUBSTR (
                                hca.account_number,
                                1,
                                2) =
                            '99'
                       THEN
                           SUBSTR (
                               hca.account_number,
                               3)
                       ELSE
                           hca.account_number
                   END customer_number,
                      msi.segment1
                   || '-'
                   || msi.segment2
                   || '-'
                   || msi.segment3 product_name,
                   ool.line_number line_num,
                   CASE
                       WHEN (ool.line_category_code = 'RETURN')
                       THEN
                           ((ool.unit_selling_price * -1) * ool.ordered_quantity)
                       ELSE
                           (ool.unit_selling_price * ool.ordered_quantity)
                   END amount,
                   ool.flow_status_code line_status,
                   --ool.line_category_code line_cat_code,
                   (SELECT hp.state
                      FROM apps.hz_parties hp
                     WHERE hp.party_id = hca.party_id) state
              FROM apps.oe_order_headers_all ooh
                   LEFT JOIN apps.oe_order_lines_all ool
                       ON ool.header_id = ooh.header_id
                   LEFT JOIN apps.hz_cust_accounts hca
                       ON hca.cust_account_id = ooh.sold_to_org_id
                   LEFT JOIN apps.mtl_system_items_b msi
                       ON     msi.inventory_item_id = ool.inventory_item_id
                          AND msi.organization_id = ool.ship_from_org_id
                   LEFT JOIN apps.oe_order_lines_all ool_r
                       ON ool_r.reference_line_id = ool.Line_id
                   LEFT JOIN apps.oe_order_headers_all ooh_r
                       ON ooh_r.header_id = ool_r.header_id
             WHERE     hca.account_number = p_customer_number ---- specific Customer fetched from first query
                   --                AND ooh.order_source_id = 1044;
                   AND ooh.order_source_id = (SELECT order_source_id
                                                FROM oe_order_sources
                                               WHERE name = 'Flagstaff');
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.PUT_LINE (SQLERRM);
    END;
END XXDOEC_CUSTOMER_ORDER_LIST;
/
