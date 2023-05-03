--
-- XXD_SALES_ORDER_DEFAULT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_SALES_ORDER_DEFAULT_PKG"
IS
    /******************************************************
    * Function:   init
    *
    * Synopsis: This function is for initializing.
    * Design:
    *END get_order_hire_default
    * Notes:
    *
    * Modifications:
    *
    * AT Header record type p_header_rec.attribute3 is using for Vas Code
    *                       p_header_rec.attribute1 is using for freight terms
    * At Line record type   p_line_tbl.attribute1 is using for  Shipping Instruction
    *                       p_line_tbl.attribute2 is using for  Packing Instruction
    *                       p_line_tbl.attribute3 is using for  Vas Code
    *                       p_line_tbl.attribute4 is using for  Deliver to org id
    *                       p_line_tbl.attribute5 is using for  cust po number
    *                       p_line_tbl.attribute6 is using for  freight terms
    *---------------------------------------------------------------------------
    *  Date           Author         Version        Description
    *--------------------------------------------------------------------------
    * 30-MAY-2016        Infosys          1.1               Change for CCR0004991
    * 31-MAY-2016        Infosys          1.2               Change for INC0294675
    * 12-JUL-2016        Infosys          1.3               Change for INC0303220
    * 01-SEP-2016        Infosys          1.4               Change for PRB0040802
    * 14-DEC-2017        Infosys          1.5               Change for CCR0006829
    * 02-Apr-2018        Arun N Murthy    2.0               Change for CCR0007043
    * 20-Jun-2020        Gaurav Joshi     2.1               Change for CCR0008696 - Pricelist defaulting
    * 17-Aug-2021        Gaurav Joshi     2.2               Change for CCR0009483 - shipping and packing
    * 14-Sep-2021        Gaurav joshi     2.3               Changes for CCR0009598 - added default params
    * 14-Sep-2021        Gaurav joshi     2.4               Changes for CCR0009546 - Sales Rep Defaulting in DOE Screen by Style-Colo
    * 03-Mar-2022        Gaurav Joshi     2.5               Changes for CCR0009841   - US6 defaulting rule
    *****************************************************************************/
    -- begin 2.2
    FUNCTION get_vas_code (p_level IN VARCHAR2, p_cust_account_id IN NUMBER, p_site_use_id IN NUMBER
                           , p_style IN VARCHAR2, p_color IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_vas_code   VARCHAR2 (240) := NULL;
        l_style      VARCHAR (240);
    -- adf pass style in this format 1008402-CHESTER and vas store style as 1008402, so doing substr
    BEGIN
        SELECT DECODE (INSTR (p_style, '-'), 0, p_style, SUBSTR (p_style, 1, INSTR (p_style, '-') - 1))
          INTO l_style
          FROM DUAL;

        IF p_level = 'HEADER'
        THEN
            SELECT SUBSTR (LISTAGG (vas_code, '+') WITHIN GROUP (ORDER BY vas_code), 1, 240)
              INTO l_vas_code
              FROM (SELECT DISTINCT vas_code
                      FROM XXD_ONT_VAS_ASSIGNMENT_DTLS_T
                     WHERE     1 = 1
                           AND cust_account_id = p_cust_account_id
                           AND attribute_level IN ('CUSTOMER'));
        ELSIF p_level = 'LINE'
        THEN
            SELECT SUBSTR (LISTAGG (vas_code, '+') WITHIN GROUP (ORDER BY vas_code), 1, 240)
              INTO l_vas_code
              FROM (SELECT vas_code
                      FROM XXD_ONT_VAS_ASSIGNMENT_DTLS_T a
                     WHERE     a.attribute_level = 'STYLE'
                           AND a.ATTRIBUTE_VALUE = l_style
                           AND cust_account_id = p_cust_account_id --- for style
                    UNION
                    SELECT vas_code
                      FROM XXD_ONT_VAS_ASSIGNMENT_DTLS_T a
                     WHERE     a.attribute_level = 'STYLE_COLOR'
                           AND a.ATTRIBUTE_VALUE = l_style || '-' || p_color
                           AND cust_account_id = p_cust_account_id --- style color
                    UNION
                    SELECT vas_code
                      FROM XXD_ONT_VAS_ASSIGNMENT_DTLS_T a, hz_cust_site_uses_all b
                     WHERE     1 = 1
                           AND cust_account_id = p_cust_account_id
                           AND b.site_use_id = p_site_use_id
                           AND b.cust_acct_site_id = a.attribute_value
                           AND attribute_level IN ('SITE'));
        END IF;

        RETURN l_vas_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN l_vas_code;
    END get_vas_code;

    PROCEDURE get_hdr_ship_pack_instr (
        p_in_cust_account_id   IN     NUMBER,
        p_in_st_site_use_id    IN     NUMBER,
        p_in_bt_site_use_id    IN     NUMBER,
        p_out_ship_instr          OUT VARCHAR2,
        p_out_pack_instr          OUT VARCHAR2)
    IS
        l_ship_instr_site   VARCHAR2 (2000);
        l_pack_instr_site   VARCHAR2 (2000);
        l_ship_instr_cust   VARCHAR2 (2000);
        l_pack_instr_cust   VARCHAR2 (2000);
    BEGIN                          -- FIRST AT customer and SHIP TO SITE LEVEL
        BEGIN
            SELECT SUBSTR (shipping_instructions, 1, 2000), SUBSTR (packing_instructions, 1, 2000)
              INTO l_ship_instr_site, l_pack_instr_site
              FROM XXD_ONT_CUSTOMER_SHIPTO_INFO_T
             WHERE     cust_account_id = p_in_cust_account_id
                   AND ship_to_site_id = p_in_st_site_use_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_pack_instr_site   := NULL;
                l_ship_instr_site   := NULL;
            WHEN OTHERS
            THEN
                l_ship_instr_site   := NULL;
                l_pack_instr_site   := NULL;
        END;

        IF l_pack_instr_site IS NULL OR l_ship_instr_site IS NULL
        THEN
            BEGIN                                    -- THEN AT CUSTOMER LEVEL
                SELECT SUBSTR (shipping_instructions, 1, 2000), SUBSTR (packing_instructions, 1, 2000)
                  INTO l_ship_instr_cust, l_pack_instr_cust
                  FROM XXD_ONT_CUSTOMER_HEADER_INFO_T
                 WHERE cust_account_id = p_in_cust_account_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_ship_instr_cust   := NULL;
                    l_pack_instr_cust   := NULL;
            END;
        END IF;

        p_out_ship_instr   := NVL (l_ship_instr_site, l_ship_instr_cust);
        p_out_pack_instr   := NVL (l_pack_instr_site, l_pack_instr_cust);
    END get_hdr_ship_pack_instr;

    /*
       PROCEDURE get_line_ship_pack_instr (
          p_in_cust_account_id   IN     NUMBER,
          p_in_st_site_use_id    IN     NUMBER,
          p_in_bt_site_use_id    IN     NUMBER,
          p_out_ship_instr          OUT VARCHAR2,
          p_out_pack_instr          OUT VARCHAR2)
       IS
       BEGIN
          -- CHECK FOR SHIP TO SITE FIRST; IF FOUND RETURN OTHERWISE CHECK AT CUSTOMER LEVEL
          BEGIN
             SELECT SUBSTR (shipping_instructions, 1, 2000),
                    SUBSTR (packing_instructions, 1, 2000)
               INTO p_out_ship_instr, p_out_pack_instr
               FROM XXD_ONT_CUSTOMER_SHIPTO_INFO_T
              WHERE     cust_account_id = p_in_cust_account_id
                    AND (   ship_to_site_id = p_in_st_site_use_id
                         OR ship_to_site_id = p_in_bt_site_use_id);
          EXCEPTION
             WHEN NO_DATA_FOUND
             THEN
                -- NO SHIPPING AND PACKING INSTRUCTION AT CUST SITE LEVEL; CHECK AT CUSTOMER LEVEL
                BEGIN
                   SELECT SUBSTR (shipping_instructions, 1, 2000),
                          SUBSTR (packing_instructions, 1, 2000)
                     INTO p_out_ship_instr, p_out_pack_instr
                     FROM XXD_ONT_CUSTOMER_HEADER_INFO_T
                    WHERE cust_account_id = p_in_cust_account_id;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      NULL;
                END;
             WHEN OTHERS
             THEN
                NULL;
          END;
       EXCEPTION
          WHEN OTHERS
          THEN
             NULL;
       END get_line_ship_pack_instr;
    */
    -- end  2.2
    PROCEDURE init (p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER
                    , p_resp_appl_id IN NUMBER)
    IS
    BEGIN
        --Initialize the global security context for current database session.
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_appl_id);
        mo_global.set_policy_context ('S', p_org_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('Error while init:' || SQLERRM);
    END init;

    /******************************************************
    * Procedure:   get_shipping_method
    *
    * Synopsis: This Procedure is for getting shipping method.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    PROCEDURE get_shipping_method (lc_ship_via          IN     VARCHAR2,
                                   p_ship_method           OUT VARCHAR2,
                                   p_ship_method_code      OUT VARCHAR2,
                                   x_error_flag            OUT VARCHAR2,
                                   x_error_message         OUT VARCHAR2)
    IS
        lc_lookup_type   VARCHAR2 (30) := 'SHIP_METHOD';
    BEGIN
        BEGIN
            SELECT meaning
              INTO p_ship_method
              FROM oe_ship_methods_v
             WHERE     lookup_type = lc_lookup_type
                   AND lookup_code = lc_ship_via
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE);

            p_ship_method_code   := lc_ship_via;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                p_ship_method        := NULL;
                p_ship_method_code   := NULL;
            WHEN OTHERS
            THEN
                p_ship_method        := NULL;
                p_ship_method_code   := NULL;
                x_error_flag         := 'E';
                x_error_message      :=
                       'Exception while fetching Shipping Method - '
                    || SUBSTR (SQLERRM, 1, 2000);
        END;
    END get_shipping_method;

    /******************************************************
    * Function:   get_order_type
    *
    * Synopsis: This function is for getting order type.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    FUNCTION get_order_type (ln_order_type_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lc_order_type   VARCHAR2 (30);
    BEGIN
        IF ln_order_type_id IS NULL
        THEN
            RETURN NULL;
        END IF;

        BEGIN
            SELECT NAME
              INTO lc_order_type
              FROM oe_transaction_types_tl
             WHERE     transaction_type_id = ln_order_type_id
                   AND LANGUAGE = USERENV ('LANG');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_order_type   := NULL;
                DBMS_OUTPUT.put_line (
                    'Error when calling func get_order_type:' || SQLERRM);
        END;

        RETURN lc_order_type;
    END get_order_type;

    /******************************************************
    * Function:   get_payment_name
    *
    * Synopsis: This function is for getting payment name.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    FUNCTION get_payment_name (p_payment_term_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lc_payment_name   VARCHAR2 (15);
    BEGIN
        BEGIN
            SELECT rterms.NAME
              INTO lc_payment_name
              FROM ra_terms rterms
             WHERE     rterms.term_id = p_payment_term_id
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE);
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_payment_name   := NULL;
                DBMS_OUTPUT.put_line (
                    'Error when calling func get_payment_name:' || SQLERRM);
        END;

        RETURN lc_payment_name;
    END get_payment_name;

    /******************************************************
    * Function:   get_freight_terms
    *
    * Synopsis: This function is for getting freight terms.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    FUNCTION get_freight_terms (p_lookup_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lc_freight_name   VARCHAR2 (15);
    BEGIN
        BEGIN
            SELECT ol.meaning
              INTO lc_freight_name
              FROM oe_lookups ol
             WHERE     ol.lookup_type = 'FREIGHT_TERMS'
                   AND ol.enabled_flag = 'Y'
                   AND ol.lookup_code = p_lookup_code
                   AND SYSDATE BETWEEN NVL (ol.start_date_active, SYSDATE)
                                   AND NVL (ol.end_date_active, SYSDATE);
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_freight_name   := NULL;
                DBMS_OUTPUT.put_line (
                    'Error when calling func get_freight_terms:' || SQLERRM);
        END;

        RETURN lc_freight_name;
    END get_freight_terms;

    /******************************************************
    * Function:   get_warehosue_name
    *
    * Synopsis: This function is for getting payment name.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    FUNCTION get_warehosue_name (p_warehosue_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lc_warehouse_name   VARCHAR2 (60);
    BEGIN
        BEGIN
            DBMS_OUTPUT.put_line ('Inside get_warehosue_name ');

            SELECT ood.organization_name
              INTO lc_warehouse_name
              FROM org_organization_definitions ood
             WHERE ood.organization_id = p_warehosue_id;

            DBMS_OUTPUT.put_line (
                   'Inside get_warehosue_name lc_warehouse_Name - '
                || lc_warehouse_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_warehouse_name   := NULL;
                DBMS_OUTPUT.put_line (
                    'Error when calling func get_warehosue_name:' || SQLERRM);
        END;

        RETURN lc_warehouse_name;
    END get_warehosue_name;

    /******************************************************
    * Procedure:  prep_default_by_ship_to
    *
    * Synopsis: This function is for getting default ship to related information.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    PROCEDURE prep_default_by_ship_to (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        CURSOR lcu_get_actual_cust_ship_to (p_cust_acct_id NUMBER)
        IS
            SELECT hcsu.LOCATION, loc.address1, loc.address2,
                   loc.state, loc.country, hcsu.org_id,
                   hcsu.site_use_id, hcsu.bill_to_site_use_id, loc.city || ',' || loc.state || ',' || loc.postal_code || ',' || loc.country
              FROM hz_cust_accounts hca, hz_cust_acct_sites hcas, hz_cust_site_uses hcsu,
                   hz_party_sites party_site, hz_locations loc
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hca.cust_account_id = p_cust_acct_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = party_site.party_site_id
                   AND party_site.location_id = loc.location_id
                   AND hcsu.site_use_code = 'SHIP_TO'
                   AND hcsu.primary_flag = 'Y'
                   AND hca.status = 'A'
                   AND hcas.status = 'A'
                   AND hcsu.status = 'A';

        CURSOR lcu_get_related_cust_ship_to (p_cust_acct_id NUMBER)
        IS
            SELECT hcsu.LOCATION, loc.address1, loc.address2,
                   loc.state, loc.country, hcsu.org_id,
                   hcsu.site_use_id, hcsu.bill_to_site_use_id, loc.city || ',' || loc.state || ',' || loc.postal_code || ',' || loc.country
              FROM                                   --hz_cust_accounts   hca,
                   (SELECT NVL (hcar.related_cust_account_id, hca.cust_account_id) related_cust_account_id, hca.status, hca.cust_account_id
                      FROM hz_cust_accounts hca, hz_cust_acct_relate hcar
                     WHERE     hca.cust_account_id = hcar.cust_account_id(+)
                           AND hcar.status(+) = 'A'
                           AND hca.cust_account_id = p_cust_acct_id
                           AND hca.party_id =
                               (SELECT party_id
                                  FROM apps.hz_cust_accounts_all b
                                 WHERE b.cust_account_id =
                                       NVL (HCAR.related_cust_account_id,
                                            HCA.cust_account_id))) hca,
                   hz_cust_acct_sites hcas,
                   hz_cust_site_uses hcsu,
                   hz_party_sites party_site,
                   hz_locations loc
             WHERE     hca.related_cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = party_site.party_site_id
                   AND party_site.location_id = loc.location_id
                   AND hcsu.site_use_code = 'SHIP_TO'
                   AND hcsu.primary_flag = 'Y'
                   AND hca.status = 'A'
                   AND hcas.status = 'A'
                   AND hcsu.status = 'A';
    BEGIN
        OPEN lcu_get_actual_cust_ship_to (px_header_rec (1).customer_id);

        FETCH lcu_get_actual_cust_ship_to
            INTO px_header_rec (1).ship_to, px_header_rec (1).ship_to_address1, px_header_rec (1).ship_to_address2, px_header_rec (1).ship_to_state,
                 px_header_rec (1).ship_to_country, px_header_rec (1).org_id, px_header_rec (1).ship_to_address_id,
                 px_header_rec (1).bill_to_address_id, px_header_rec (1).ship_to_addressess;

        CLOSE lcu_get_actual_cust_ship_to;

        IF px_header_rec (1).ship_to_address_id IS NULL
        THEN
            OPEN lcu_get_related_cust_ship_to (px_header_rec (1).customer_id);

            FETCH lcu_get_related_cust_ship_to
                INTO px_header_rec (1).ship_to, px_header_rec (1).ship_to_address1, px_header_rec (1).ship_to_address2, px_header_rec (1).ship_to_state,
                     px_header_rec (1).ship_to_country, px_header_rec (1).org_id, px_header_rec (1).ship_to_address_id,
                     px_header_rec (1).bill_to_address_id, px_header_rec (1).ship_to_addressess;

            CLOSE lcu_get_related_cust_ship_to;
        END IF;

        DBMS_OUTPUT.put_line (
            'px_header_rec(1).ship_to 1 - ' || px_header_rec (1).ship_to);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_error_flag   := NULL;
        WHEN OTHERS
        THEN
            x_error_flag   := 'E';
            x_error_message   :=
                   'Exception occurs when retrieving ship to information:'
                || SUBSTR (SQLERRM, 1, 2000);
    END prep_default_by_ship_to;

    /******************************************************
    * Procedure:  prep_default_by_bill_to
    *
    * Synopsis: This function is for getting default bill to related information.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    PROCEDURE prep_default_by_bill_to (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        CURSOR lcu_get_actual_cust_bill_to (p_cust_acct_id NUMBER)
        IS
            SELECT hcsu.LOCATION, loc.address1, loc.address2,
                   loc.state, loc.country, hcsu.site_use_id,
                   loc.city || ',' || loc.state || ',' || loc.postal_code || ',' || loc.country
              FROM hz_cust_accounts hca, hz_cust_acct_sites hcas, hz_cust_site_uses hcsu,
                   hz_party_sites party_site, hz_locations loc
             WHERE     hca.cust_account_id = hcas.cust_account_id
                   AND hca.cust_account_id = p_cust_acct_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = party_site.party_site_id
                   AND party_site.location_id = loc.location_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hcsu.primary_flag = 'Y'
                   AND hca.status = 'A'
                   AND hcas.status = 'A'
                   AND hcsu.status = 'A';

        CURSOR lcu_get_related_cust_bill_to (p_cust_acct_id NUMBER)
        IS
            SELECT hcsu.LOCATION, loc.address1, loc.address2,
                   loc.state, loc.country, hcsu.site_use_id,
                   loc.city || ',' || loc.state || ',' || loc.postal_code || ',' || loc.country
              FROM                                   --hz_cust_accounts   hca,
                   (SELECT NVL (hcar.related_cust_account_id, hca.cust_account_id) related_cust_account_id, hca.status, hca.cust_account_id
                      FROM hz_cust_accounts hca, hz_cust_acct_relate hcar
                     WHERE     hca.cust_account_id = hcar.cust_account_id(+)
                           AND hcar.status(+) = 'A'
                           AND hca.cust_account_id = p_cust_acct_id
                           AND hca.party_id =
                               (SELECT party_id
                                  FROM apps.hz_cust_accounts_all b
                                 WHERE b.cust_account_id =
                                       NVL (HCAR.related_cust_account_id,
                                            HCA.cust_account_id))) hca,
                   hz_cust_acct_sites hcas,
                   hz_cust_site_uses hcsu,
                   hz_party_sites party_site,
                   hz_locations loc
             WHERE     hca.related_cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = party_site.party_site_id
                   AND party_site.location_id = loc.location_id
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hcsu.primary_flag = 'Y'
                   AND hca.status = 'A'
                   AND hcas.status = 'A'
                   AND hcsu.status = 'A';
    BEGIN
        --Fetch Bill To Location
        OPEN lcu_get_actual_cust_bill_to (px_header_rec (1).customer_id);

        FETCH lcu_get_actual_cust_bill_to
            INTO px_header_rec (1).bill_to, px_header_rec (1).bill_to_address1, px_header_rec (1).bill_to_address2, px_header_rec (1).bill_to_state,
                 px_header_rec (1).bill_to_country, px_header_rec (1).bill_to_address_id, px_header_rec (1).bill_to_addressess;

        CLOSE lcu_get_actual_cust_bill_to;

        IF px_header_rec (1).bill_to_address_id IS NULL
        THEN
            OPEN lcu_get_related_cust_bill_to (px_header_rec (1).customer_id);

            FETCH lcu_get_related_cust_bill_to
                INTO px_header_rec (1).bill_to, px_header_rec (1).bill_to_address1, px_header_rec (1).bill_to_address2, px_header_rec (1).bill_to_state,
                     px_header_rec (1).bill_to_country, px_header_rec (1).bill_to_address_id, px_header_rec (1).bill_to_addressess;

            CLOSE lcu_get_related_cust_bill_to;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_error_flag   := NULL;
        WHEN OTHERS
        THEN
            x_error_flag   := 'E';
            x_error_message   :=
                   'Exception occurs when retrieving bill to information :- '
                || SUBSTR (SQLERRM, 1, 2000);
    END prep_default_by_bill_to;

    /******************************************************
    * Procedure:  prep_default_by_bill_to
    *
    * Synopsis: This function is for getting default bill to related information.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    PROCEDURE prep_default_by_deliver_to (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
    BEGIN
        --Fetch Bill To Location
        SELECT hcsu.LOCATION, loc.address1, loc.address2,
               loc.state, loc.country, hcsu.site_use_id,
               loc.city || ',' || loc.state || ',' || loc.postal_code || ',' || loc.country
          INTO px_header_rec (1).deliver_to, px_header_rec (1).deliver_to_address1, px_header_rec (1).deliver_to_address2, px_header_rec (1).deliver_to_state,
                                           px_header_rec (1).deliver_to_country, px_header_rec (1).deliver_to_address_id, px_header_rec (1).deliver_to_addressess
          FROM                                       --hz_cust_accounts   hca,
               (SELECT NVL (hcar.related_cust_account_id, hca.cust_account_id) related_cust_account_id, hca.status, hca.cust_account_id
                  FROM hz_cust_accounts hca, hz_cust_acct_relate hcar
                 WHERE     hca.cust_account_id = hcar.cust_account_id(+)
                       AND hcar.status(+) = 'A'
                       AND hca.cust_account_id =
                           px_header_rec (1).customer_id
                       AND hca.party_id =
                           (SELECT party_id
                              FROM apps.hz_cust_accounts_all b
                             WHERE b.cust_account_id =
                                   NVL (HCAR.related_cust_account_id,
                                        HCA.cust_account_id))) hca,
               hz_cust_acct_sites hcas,
               hz_cust_site_uses hcsu,
               hz_party_sites party_site,
               hz_locations loc
         WHERE     hca.related_cust_account_id = hcas.cust_account_id
               AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
               AND hcas.party_site_id = party_site.party_site_id
               AND party_site.location_id = loc.location_id
               AND hcsu.site_use_code = 'DELIVER_TO'
               AND hcsu.primary_flag = 'Y'
               AND hca.status = 'A'
               AND hcas.status = 'A'
               AND hcsu.status = 'A';
    --        AND hca.cust_account_id = px_header_rec(1).customer_id
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_error_flag   := NULL;
        WHEN OTHERS
        THEN
            x_error_flag   := 'E';
            x_error_message   :=
                   'Exception occurs when retrieving bill to information :- '
                || SUBSTR (SQLERRM, 1, 2000);
    END prep_default_by_deliver_to;

    /******************************************************
    * Procedure:  prep_customer_info
    *
    * Synopsis: This function is for getting default customer related information.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    PROCEDURE prep_customer_info (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        ln_party_id          NUMBER;
        lc_ship_via          VARCHAR2 (30);
        ln_order_type_id     NUMBER (15);
        ln_payment_term_id   NUMBER (15);
        lc_freight_term      VARCHAR2 (30);
        lc_fob_point         VARCHAR2 (30);
        ln_price_list_id     NUMBER (15);
    BEGIN
        -- Fetch Customer Name,FOB point,freight term,order type id
        SELECT hp.party_name, hp.party_id, hca.account_number
          INTO px_header_rec (1).customer_name, ln_party_id, px_header_rec (1).customer_number
          FROM hz_parties hp, hz_cust_accounts hca
         WHERE     hp.party_id = hca.party_id
               AND hca.cust_account_id = px_header_rec (1).customer_id;

        -- Fetch Primary Contact from customer level
        SELECT hp.party_name
          INTO px_header_rec (1).customer_contact
          FROM hz_parties hp, hz_relationships rel, hz_org_contacts hoc,
               hz_org_contact_roles hocr
         WHERE     hp.party_id = rel.object_id
               AND rel.relationship_id = hoc.party_relationship_id
               AND hoc.org_contact_id = hocr.org_contact_id
               AND rel.relationship_code = 'CONTACT'
               AND rel.status = 'A'
               AND SYSDATE BETWEEN rel.start_date
                               AND NVL (rel.end_date, SYSDATE)
               AND hoc.status = 'A'
               AND hoc.party_site_id IS NULL
               AND hocr.status = 'A'
               AND hocr.primary_flag = 'Y'
               AND rel.subject_id = ln_party_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_error_flag   := NULL;
        WHEN OTHERS
        THEN
            x_error_flag   := 'E';
            x_error_message   :=
                   'Exception occurs when retrieving customer information :- '
                || SQLERRM;
    END prep_customer_info;

    PROCEDURE get_ship_to_hire_default (
        p_customer_id                   NUMBER,
        p_site_to_id                    NUMBER,
        px_header_rec     IN OUT NOCOPY xxd_btom_oeheader_tbltype,
        x_error_flag         OUT        VARCHAR2,
        x_error_message      OUT        VARCHAR2)
    IS
        lc_ship_via          VARCHAR2 (30);
        ln_order_type_id     NUMBER (15);
        ln_payment_term_id   NUMBER (15);
        lc_freight_term      VARCHAR2 (30);
        lc_fob_point         VARCHAR2 (30);
        ln_warehouse_id      NUMBER;
        lc_error_flag        VARCHAR2 (10);
        ln_price_list_id     NUMBER;
        lc_error_message     VARCHAR2 (4000) := NULL;
    BEGIN
        BEGIN
            DBMS_OUTPUT.put_line ('Inside get_ship_to_hire_default - ');

            /* SELECT hcsu.freight_term,
                    hcsu.fob_point,
                    hcsu.ship_via,
                    hcsu.order_type_id,
                    hcsu.payment_term_id,
                    hcsu.location,
                    loc.address1,
                    loc.address2,
                    loc.state,
                    loc.country,
                    hcsu.bill_to_site_use_id,
                    hcsu.warehouse_id,
                    loc.city||','||loc.state||','||loc.postal_code||','||loc.country
              INTO  lc_freight_term,
                    lc_fob_point,
                    lc_ship_via,
                    ln_order_type_id,
                    ln_payment_term_id,
                    px_header_rec(1).ship_to,
                    px_header_rec(1).ship_to_address1,
                    px_header_rec(1).ship_to_address2,
                    px_header_rec(1).ship_to_state,
                    px_header_rec(1).ship_to_country,
                    px_header_rec(1).bill_to_address_id,
                    ln_warehouse_id,
                    px_header_rec(1).ship_to_addressess
              FROM  hz_cust_accounts   hca,
                   hz_cust_acct_sites hcas,
                   hz_cust_site_uses  hcsu,
                   hz_party_sites     party_site,
                   hz_locations       loc
             WHERE hca.cust_account_id    = hcas.cust_account_id
               AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
               AND hcas.party_site_id     = party_site.party_site_id
               AND party_site.location_id = loc.location_id
               AND hcsu.site_use_id       = p_site_to_id
               AND hca.cust_account_id    = p_customer_id
               AND hcsu.site_use_code     = 'SHIP_TO'
               AND hcsu.status            = 'A' ;
            */
            SELECT hcsu.freight_term, hcsu.fob_point, hcsu.ship_via,
                   hcsu.order_type_id, hcsu.payment_term_id, hcsu.LOCATION,
                   loc.address1, loc.address2, loc.state,
                   loc.country, hcsu.bill_to_site_use_id, hcsu.warehouse_id,
                   hcsu.price_list_id, loc.city || ',' || loc.state || ',' || loc.postal_code || ',' || loc.country
              INTO lc_freight_term, lc_fob_point, lc_ship_via, ln_order_type_id,
                                  ln_payment_term_id, px_header_rec (1).ship_to, px_header_rec (1).ship_to_address1,
                                  px_header_rec (1).ship_to_address2, px_header_rec (1).ship_to_state, px_header_rec (1).ship_to_country,
                                  px_header_rec (1).bill_to_address_id, ln_warehouse_id, ln_price_list_id,
                                  px_header_rec (1).ship_to_addressess
              FROM hz_cust_acct_sites hcas, hz_cust_site_uses hcsu, hz_party_sites party_site,
                   hz_locations loc
             WHERE     hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = party_site.party_site_id
                   AND party_site.location_id = loc.location_id
                   AND hcsu.site_use_id = p_site_to_id
                   AND hcsu.site_use_code = 'SHIP_TO'
                   AND hcsu.status = 'A';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'NO Data Found Exception occurs when retrieving ship to information :- '
                    || SUBSTR (SQLERRM, 1, 2000);
            WHEN OTHERS
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'Exception occurs when retrieving ship to information :- '
                    || SUBSTR (SQLERRM, 1, 2000);
        END;

        DBMS_OUTPUT.put_line (
               'Inside get_ship_to_hire_default x_error_message - '
            || x_error_message
            || ' - '
            || x_error_flag);
        DBMS_OUTPUT.put_line (
            'px_header_rec(1).ship_to 2 - ' || px_header_rec (1).ship_to);

        IF NVL (x_error_flag, 'X') != 'E'
        THEN
            DBMS_OUTPUT.put_line ('IF x_error_flag != ');

            -- Set Shipping Method
            IF     lc_ship_via IS NOT NULL
               AND px_header_rec (1).shipping_method IS NULL
            THEN
                get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                     , lc_error_flag, lc_error_message);
                x_error_message   := x_error_message || lc_error_message;
                x_error_flag      := lc_error_flag;
            END IF;

            -- Set Payment Terms
            IF     ln_payment_term_id IS NOT NULL
               AND px_header_rec (1).payment_terms_id IS NULL
            THEN
                px_header_rec (1).payment_terms   :=
                    get_payment_name (ln_payment_term_id);

                IF px_header_rec (1).payment_terms IS NOT NULL
                THEN
                    px_header_rec (1).payment_terms_id   :=
                        ln_payment_term_id;
                END IF;
            END IF;

            -- Set Order Type
            IF     ln_order_type_id IS NOT NULL
               AND px_header_rec (1).order_type IS NULL
            THEN
                px_header_rec (1).order_type   :=
                    get_order_type (ln_order_type_id);

                IF px_header_rec (1).order_type IS NOT NULL
                THEN
                    px_header_rec (1).order_type_id   := ln_order_type_id;
                END IF;
            END IF;

            -- Set WareHouse
            DBMS_OUTPUT.put_line (
                   'px_header_rec(1).Warehouse_Id - '
                || px_header_rec (1).warehouse_id);

            IF     ln_warehouse_id IS NOT NULL
               AND px_header_rec (1).warehouse_id IS NULL
            THEN
                DBMS_OUTPUT.put_line ('calling get_warehosue_name ');
                px_header_rec (1).warehouse   :=
                    get_warehosue_name (ln_warehouse_id);

                IF px_header_rec (1).warehouse IS NOT NULL
                THEN
                    px_header_rec (1).warehouse_id   := ln_warehouse_id;
                END IF;
            END IF;

            -- Setup Freight Terms
            IF     lc_freight_term IS NOT NULL
               AND px_header_rec (1).freight_terms IS NULL
            THEN
                px_header_rec (1).freight_terms   := lc_freight_term;
                px_header_rec (1).attribute1      :=
                    get_freight_terms (lc_freight_term);
            END IF;
        /*-- Setup FOB Point
        IF lc_fob_point IS NOT NULL AND px_header_rec(1).fob_point_code IS NULL THEN
          px_header_rec(1).fob_point_code := lc_fob_point;
        END IF;*/
        END IF;

        IF px_header_rec (1).requested_date IS NOT NULL
        THEN
            IF     ln_price_list_id IS NOT NULL
               AND px_header_rec (1).price_list IS NULL
            THEN
                SELECT NAME
                  INTO px_header_rec (1).price_list
                  FROM qp_list_headers_tl ql
                 WHERE     list_header_id = ln_price_list_id
                       AND LANGUAGE = USERENV ('LANG');

                px_header_rec (1).price_list_id   := ln_price_list_id;
            END IF;
        END IF;
    END get_ship_to_hire_default;

    PROCEDURE get_ship_to_hire_default_line (
        p_customer_id                   NUMBER,
        p_site_to_id                    NUMBER,
        px_header_rec     IN OUT NOCOPY xxd_btom_oeline_tbltype,
        x_error_flag         OUT        VARCHAR2,
        x_error_message      OUT        VARCHAR2)
    IS
        lc_ship_via          VARCHAR2 (30);
        ln_order_type_id     NUMBER (15);
        ln_payment_term_id   NUMBER (15);
        lc_freight_term      VARCHAR2 (30);
        lc_fob_point         VARCHAR2 (30);
        ln_warehouse_id      NUMBER;
        lc_error_flag        VARCHAR2 (10);
        lc_error_message     VARCHAR2 (4000) := NULL;
    BEGIN
        BEGIN
            DBMS_OUTPUT.put_line ('Inside get_ship_to_hire_default Line- ');

            SELECT hcsu.freight_term, hcsu.fob_point, hcsu.ship_via,
                   hcsu.order_type_id, hcsu.payment_term_id, hcsu.LOCATION,
                   loc.address1, loc.address2, loc.state,
                   loc.country, hcsu.bill_to_site_use_id, hcsu.warehouse_id,
                   loc.city || ',' || loc.state || ',' || loc.postal_code || ',' || loc.country
              INTO lc_freight_term, lc_fob_point, lc_ship_via, ln_order_type_id,
                                  ln_payment_term_id, px_header_rec (1).ship_to, px_header_rec (1).ship_to_address1,
                                  px_header_rec (1).ship_to_address2, px_header_rec (1).ship_to_state, px_header_rec (1).ship_to_country,
                                  px_header_rec (1).bill_to_address_id, ln_warehouse_id, px_header_rec (1).ship_to_addressess
              FROM hz_cust_acct_sites hcas, hz_cust_site_uses hcsu, hz_party_sites party_site,
                   hz_locations loc
             WHERE     hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = party_site.party_site_id
                   AND party_site.location_id = loc.location_id
                   AND hcsu.site_use_id = p_site_to_id
                   AND hcsu.site_use_code = 'SHIP_TO'
                   AND hcsu.status = 'A';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'NO Data Found Exception occurs when retrieving ship to information at Line level :- '
                    || SUBSTR (SQLERRM, 1, 2000);
            WHEN OTHERS
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'Exception occurs when retrieving ship to information at Line level  :- '
                    || SUBSTR (SQLERRM, 1, 2000);
        END;

        DBMS_OUTPUT.put_line (
               'Inside get_ship_to_hire_default at Line level  x_error_message - '
            || x_error_message
            || ' - '
            || x_error_flag);

        IF NVL (x_error_flag, 'X') != 'E'
        THEN
            DBMS_OUTPUT.put_line ('IF x_error_flag != ');

            -- Set Shipping Method
            IF     lc_ship_via IS NOT NULL
               AND px_header_rec (1).shipping_method IS NULL
            THEN
                get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                     , lc_error_flag, lc_error_message);
                x_error_message   := x_error_message || lc_error_message;
                x_error_flag      := lc_error_flag;
            END IF;

            -- Set Payment Terms
            IF     ln_payment_term_id IS NOT NULL
               AND px_header_rec (1).payment_terms_id IS NULL
            THEN
                px_header_rec (1).payment_terms   :=
                    get_payment_name (ln_payment_term_id);

                IF px_header_rec (1).payment_terms IS NOT NULL
                THEN
                    px_header_rec (1).payment_terms_id   :=
                        ln_payment_term_id;
                END IF;
            END IF;

            -- Set WareHouse
            IF     ln_warehouse_id IS NOT NULL
               AND px_header_rec (1).warehouse_id IS NULL
            THEN
                px_header_rec (1).warehouse   :=
                    get_warehosue_name (ln_warehouse_id);

                IF px_header_rec (1).warehouse IS NOT NULL
                THEN
                    px_header_rec (1).warehouse_id   := ln_warehouse_id;
                END IF;
            END IF;

            -- Setup Freight Terms
            IF     lc_freight_term IS NOT NULL
               AND px_header_rec (1).freight_terms IS NULL
            THEN
                px_header_rec (1).freight_terms   := lc_freight_term;
                px_header_rec (1).attribute6      :=
                    get_freight_terms (lc_freight_term);
            END IF;
        END IF;
    END get_ship_to_hire_default_line;

    PROCEDURE get_bill_to_hire_default (
        p_customer_id                   NUMBER,
        p_bill_to_id                    NUMBER,
        px_header_rec     IN OUT NOCOPY xxd_btom_oeheader_tbltype,
        x_error_flag         OUT        VARCHAR2,
        x_error_message      OUT        VARCHAR2)
    IS
        lc_ship_via          VARCHAR2 (30);
        ln_order_type_id     NUMBER (15);
        ln_payment_term_id   NUMBER (15);
        lc_freight_term      VARCHAR2 (30);
        lc_fob_point         VARCHAR2 (30);
        lc_error_flag        VARCHAR2 (10);
        ln_price_list_id     NUMBER;
        lc_error_message     VARCHAR2 (4000) := NULL;
    BEGIN
        BEGIN
            /* SELECT hcsu.freight_term,
            hcsu.fob_point,
            hcsu.ship_via,
            hcsu.order_type_id,
            hcsu.payment_term_id,
            hcsu.location,
            loc.address1,
            loc.address2,
            loc.state,
            loc.country,
            loc.city||','||loc.state||','||loc.postal_code||','||loc.country
            INTO  lc_freight_term,
            lc_fob_point,
            lc_ship_via,
            ln_order_type_id,
            ln_payment_term_id,
            px_header_rec(1).bill_to,
            px_header_rec(1).bill_to_address1,
            px_header_rec(1).bill_to_address2,
            px_header_rec(1).bill_to_state,
            px_header_rec(1).bill_to_country,
            px_header_rec(1).bill_to_addressess
            FROM  hz_cust_accounts   hca,
            hz_cust_acct_sites hcas,
            hz_cust_site_uses  hcsu,
            hz_party_sites     party_site,
            hz_locations       loc
            WHERE hca.cust_account_id    = hcas.cust_account_id
            AND hcas.cust_acct_site_id = hcsu.cust_acct_site_id
            AND hcas.party_site_id     = party_site.party_site_id
            AND party_site.location_id = loc.location_id
            AND hcsu.site_use_id       = p_bill_to_id
            AND hca.cust_account_id    = p_customer_id
            AND hcsu.site_use_code     = 'BILL_TO'
            AND hcsu.status            = 'A';
            */
            SELECT hcsu.site_use_id, hcsu.freight_term, hcsu.fob_point,
                   hcsu.ship_via, hcsu.order_type_id, hcsu.payment_term_id,
                   hcsu.LOCATION, loc.address1, loc.address2,
                   loc.state, loc.country, hcsu.price_list_id,
                   loc.city || ',' || loc.state || ',' || loc.postal_code || ',' || loc.country
              INTO px_header_rec (1).bill_to_address_id, lc_freight_term, lc_fob_point, lc_ship_via,
                                                       ln_order_type_id, ln_payment_term_id, px_header_rec (1).bill_to,
                                                       px_header_rec (1).bill_to_address1, px_header_rec (1).bill_to_address2, px_header_rec (1).bill_to_state,
                                                       px_header_rec (1).bill_to_country, ln_price_list_id, px_header_rec (1).bill_to_addressess
              FROM hz_cust_acct_sites hcas, hz_cust_site_uses hcsu, hz_party_sites party_site,
                   hz_locations loc
             WHERE     hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = party_site.party_site_id
                   AND party_site.location_id = loc.location_id
                   AND hcsu.site_use_id = p_bill_to_id
                   --AND hcsu.location = (SELECT location||'_'||px_header_rec(1).brand FROM  hz_cust_site_uses WHERE site_use_id = p_bill_to_id)
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hcsu.status = 'A';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                px_header_rec (1).bill_to_address_id   := NULL;
                x_error_flag                           := 'E';
                x_error_message                        :=
                       'NO Data Found Exception occurs when retrieving Bill to information :- '
                    || SUBSTR (SQLERRM, 1, 2000);
            WHEN OTHERS
            THEN
                px_header_rec (1).bill_to_address_id   := NULL;
                x_error_flag                           := 'E';
                x_error_message                        :=
                       'Exception occurs when retrieving Bill to information :- '
                    || SUBSTR (SQLERRM, 1, 2000);
        END;

        IF NVL (x_error_flag, 'X') != 'E'
        THEN
            -- Set Shipping Method
            IF     lc_ship_via IS NOT NULL
               AND px_header_rec (1).shipping_method IS NULL
            THEN
                get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                     , lc_error_flag, lc_error_message);
                x_error_message   := x_error_message || lc_error_message;
                x_error_flag      := lc_error_flag;
            END IF;

            -- Set Order Type
            IF     ln_order_type_id IS NOT NULL
               AND px_header_rec (1).order_type IS NULL
            THEN
                px_header_rec (1).order_type   :=
                    get_order_type (ln_order_type_id);

                IF px_header_rec (1).order_type IS NOT NULL
                THEN
                    px_header_rec (1).order_type_id   := ln_order_type_id;
                END IF;
            END IF;

            -- Set Payment Terms
            IF     ln_payment_term_id IS NOT NULL
               AND px_header_rec (1).payment_terms_id IS NULL
            THEN
                px_header_rec (1).payment_terms   :=
                    get_payment_name (ln_payment_term_id);

                IF px_header_rec (1).payment_terms IS NOT NULL
                THEN
                    px_header_rec (1).payment_terms_id   :=
                        ln_payment_term_id;
                END IF;
            END IF;

            -- Setup Freight Terms
            IF     lc_freight_term IS NOT NULL
               AND px_header_rec (1).freight_terms IS NULL
            THEN
                px_header_rec (1).freight_terms   := lc_freight_term;
                px_header_rec (1).attribute1      :=
                    get_freight_terms (lc_freight_term);
            END IF;
        /* -- Setup FOB Point
        IF lc_fob_point IS NOT NULL AND px_header_rec(1).fob_point_code IS NULL THEN
        px_header_rec(1).fob_point_code := lc_fob_point;
        END IF; */
        END IF;

        IF px_header_rec (1).requested_date IS NOT NULL
        THEN
            IF     ln_price_list_id IS NOT NULL
               AND px_header_rec (1).price_list IS NULL
            THEN
                SELECT NAME
                  INTO px_header_rec (1).price_list
                  FROM qp_list_headers_tl ql
                 WHERE     list_header_id = ln_price_list_id
                       AND LANGUAGE = USERENV ('LANG');

                px_header_rec (1).price_list_id   := ln_price_list_id;
            END IF;
        END IF;
    END get_bill_to_hire_default;

    PROCEDURE get_bill_to_hire_default_line (
        p_customer_id                   NUMBER,
        p_bill_to_id                    NUMBER,
        px_header_rec     IN OUT NOCOPY xxd_btom_oeline_tbltype,
        x_error_flag         OUT        VARCHAR2,
        x_error_message      OUT        VARCHAR2)
    IS
        lc_ship_via          VARCHAR2 (30);
        ln_order_type_id     NUMBER (15);
        ln_payment_term_id   NUMBER (15);
        lc_freight_term      VARCHAR2 (30);
        lc_fob_point         VARCHAR2 (30);
        lc_error_flag        VARCHAR2 (10);
        lc_error_message     VARCHAR2 (4000) := NULL;
    BEGIN
        BEGIN
            SELECT hcsu.site_use_id, hcsu.freight_term, hcsu.fob_point,
                   hcsu.ship_via, hcsu.order_type_id, hcsu.payment_term_id,
                   hcsu.LOCATION, loc.address1, loc.address2,
                   loc.state, loc.country, loc.city || ',' || loc.state || ',' || loc.postal_code || ',' || loc.country
              INTO px_header_rec (1).bill_to_address_id, lc_freight_term, lc_fob_point, lc_ship_via,
                                                       ln_order_type_id, ln_payment_term_id, px_header_rec (1).bill_to,
                                                       px_header_rec (1).bill_to_address1, px_header_rec (1).bill_to_address2, px_header_rec (1).bill_to_state,
                                                       px_header_rec (1).bill_to_country, px_header_rec (1).bill_to_addressess
              FROM hz_cust_acct_sites hcas, hz_cust_site_uses hcsu, hz_party_sites party_site,
                   hz_locations loc
             WHERE     hcas.cust_acct_site_id = hcsu.cust_acct_site_id
                   AND hcas.party_site_id = party_site.party_site_id
                   AND party_site.location_id = loc.location_id
                   AND hcsu.site_use_id = p_bill_to_id
                   --AND hcsu.location = (SELECT location||'_'||px_header_rec(1).brand FROM  hz_cust_site_uses WHERE site_use_id = p_bill_to_id)
                   AND hcsu.site_use_code = 'BILL_TO'
                   AND hcsu.status = 'A';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                px_header_rec (1).bill_to_address_id   := NULL;
                x_error_flag                           := 'E';
                x_error_message                        :=
                       'NO Data Found Exception occurs when retrieving Bill to information at line level :- '
                    || SUBSTR (SQLERRM, 1, 2000);
            WHEN OTHERS
            THEN
                px_header_rec (1).bill_to_address_id   := NULL;
                x_error_flag                           := 'E';
                x_error_message                        :=
                       'Exception occurs when retrieving Bill to information at line level :- '
                    || SUBSTR (SQLERRM, 1, 2000);
        END;

        IF NVL (x_error_flag, 'X') != 'E'
        THEN
            -- Set Shipping Method
            IF     lc_ship_via IS NOT NULL
               AND px_header_rec (1).shipping_method IS NULL
            THEN
                get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                     , lc_error_flag, lc_error_message);
                x_error_message   := x_error_message || lc_error_message;
                x_error_flag      := lc_error_flag;
            END IF;

            -- Set Payment Terms
            IF     ln_payment_term_id IS NOT NULL
               AND px_header_rec (1).payment_terms_id IS NULL
            THEN
                px_header_rec (1).payment_terms   :=
                    get_payment_name (ln_payment_term_id);

                IF px_header_rec (1).payment_terms IS NOT NULL
                THEN
                    px_header_rec (1).payment_terms_id   :=
                        ln_payment_term_id;
                END IF;
            END IF;

            -- Setup Freight Terms
            IF     lc_freight_term IS NOT NULL
               AND px_header_rec (1).freight_terms IS NULL
            THEN
                px_header_rec (1).freight_terms   := lc_freight_term;
                px_header_rec (1).attribute6      :=
                    get_freight_terms (lc_freight_term);
            END IF;
        END IF;
    END get_bill_to_hire_default_line;

    PROCEDURE get_cust_to_hire_default (p_customer_id NUMBER, px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2
                                        , x_error_message OUT VARCHAR2)
    IS
        lc_ship_via          VARCHAR2 (30);
        ln_order_type_id     NUMBER (15);
        ln_payment_term_id   NUMBER (15);
        lc_freight_term      VARCHAR2 (30);
        lc_fob_point         VARCHAR2 (30);
        lc_error_flag        VARCHAR2 (10);
        ln_price_list_id     NUMBER;
        lc_error_message     VARCHAR2 (4000) := NULL;
    BEGIN
        BEGIN
            SELECT hca.fob_point, hca.freight_term, hca.ship_via,
                   hca.order_type_id, hca.payment_term_id, hca.price_list_id
              INTO lc_fob_point, lc_freight_term, lc_ship_via, ln_order_type_id,
                               ln_payment_term_id, ln_price_list_id
              FROM hz_parties hp, hz_cust_accounts hca
             WHERE     hp.party_id = hca.party_id
                   AND hca.cust_account_id = p_customer_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_error_flag   := 'E';
            WHEN OTHERS
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'Exception occurs when retrieving ship to information:'
                    || SQLERRM;
        END;

        IF NVL (x_error_flag, 'X') != 'E'
        THEN
            -- Set Shipping Method
            IF     lc_ship_via IS NOT NULL
               AND px_header_rec (1).shipping_method IS NULL
            THEN
                get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                     , lc_error_flag, lc_error_message);
                x_error_message   := x_error_message || lc_error_message;
                x_error_flag      := lc_error_flag;
            END IF;

            IF ln_payment_term_id IS NULL           -- START W.r.t version 1.2
            THEN
                BEGIN
                    SELECT standard_terms
                      INTO ln_payment_term_id
                      FROM HZ_CUSTOMER_PROFILES
                     WHERE cust_account_id = p_customer_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_payment_term_id   := NULL;
                        DBMS_OUTPUT.put_line (
                            'Exception while retreiving payment_id from customer profile.');
                END;
            END IF;                                   -- END W.r.t version 1.2

            -- Set Order Type
            IF     ln_order_type_id IS NOT NULL
               AND px_header_rec (1).order_type IS NULL
            THEN
                px_header_rec (1).order_type   :=
                    get_order_type (ln_order_type_id);

                IF px_header_rec (1).order_type IS NOT NULL
                THEN
                    px_header_rec (1).order_type_id   := ln_order_type_id;
                END IF;
            END IF;

            -- Set Payment Terms
            IF     ln_payment_term_id IS NOT NULL
               AND px_header_rec (1).payment_terms_id IS NULL
            THEN
                px_header_rec (1).payment_terms   :=
                    get_payment_name (ln_payment_term_id);

                IF px_header_rec (1).payment_terms IS NOT NULL
                THEN
                    px_header_rec (1).payment_terms_id   :=
                        ln_payment_term_id;
                END IF;
            END IF;

            -- Setup Freight Terms
            IF     lc_freight_term IS NOT NULL
               AND px_header_rec (1).freight_terms IS NULL
            THEN
                px_header_rec (1).freight_terms   := lc_freight_term;
                px_header_rec (1).attribute1      :=
                    get_freight_terms (lc_freight_term);
            END IF;
        /*-- Setup FOB Point
        IF lc_fob_point IS NOT NULL AND px_header_rec(1).fob_point_code IS NULL THEN
        px_header_rec(1).fob_point_code := lc_fob_point;
        END IF; */
        END IF;

        IF px_header_rec (1).requested_date IS NOT NULL
        THEN
            IF     ln_price_list_id IS NOT NULL
               AND px_header_rec (1).price_list IS NULL
            THEN
                SELECT NAME
                  INTO px_header_rec (1).price_list
                  FROM qp_list_headers_tl ql
                 WHERE     list_header_id = ln_price_list_id
                       AND LANGUAGE = USERENV ('LANG');

                px_header_rec (1).price_list_id   := ln_price_list_id;
            END IF;
        END IF;
    END get_cust_to_hire_default;

    PROCEDURE get_cust_to_hire_default_line (p_customer_id NUMBER, px_header_rec IN OUT NOCOPY xxd_btom_oeline_tbltype, x_error_flag OUT VARCHAR2
                                             , x_error_message OUT VARCHAR2)
    IS
        lc_ship_via          VARCHAR2 (30);
        ln_order_type_id     NUMBER (15);
        ln_payment_term_id   NUMBER (15);
        lc_freight_term      VARCHAR2 (30);
        lc_fob_point         VARCHAR2 (30);
        lc_error_flag        VARCHAR2 (10);
        lc_error_message     VARCHAR2 (4000) := NULL;
    BEGIN
        BEGIN
            SELECT hca.fob_point, hca.freight_term, hca.ship_via,
                   hca.order_type_id, hca.payment_term_id
              INTO lc_fob_point, lc_freight_term, lc_ship_via, ln_order_type_id,
                               ln_payment_term_id
              FROM hz_parties hp, hz_cust_accounts hca
             WHERE     hp.party_id = hca.party_id
                   AND hca.cust_account_id = p_customer_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_error_flag   := 'E';
            WHEN OTHERS
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'Exception occurs when retrieving ship to information:'
                    || SQLERRM;
        END;

        IF NVL (x_error_flag, 'X') != 'E'
        THEN
            -- Set Shipping Method
            IF     lc_ship_via IS NOT NULL
               AND px_header_rec (1).shipping_method IS NULL
            THEN
                get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                     , lc_error_flag, lc_error_message);
                x_error_message   := x_error_message || lc_error_message;
                x_error_flag      := lc_error_flag;
            END IF;

            -- Set Payment Terms
            IF     ln_payment_term_id IS NOT NULL
               AND px_header_rec (1).payment_terms_id IS NULL
            THEN
                px_header_rec (1).payment_terms   :=
                    get_payment_name (ln_payment_term_id);

                IF px_header_rec (1).payment_terms IS NOT NULL
                THEN
                    px_header_rec (1).payment_terms_id   :=
                        ln_payment_term_id;
                END IF;
            END IF;

            -- Setup Freight Terms
            IF     lc_freight_term IS NOT NULL
               AND px_header_rec (1).freight_terms IS NULL
            THEN
                px_header_rec (1).freight_terms   := lc_freight_term;
                px_header_rec (1).attribute6      :=
                    get_freight_terms (lc_freight_term);
            END IF;
        END IF;
    END get_cust_to_hire_default_line;

    PROCEDURE get_order_hire_default (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        lc_ship_via        VARCHAR2 (30);
        lc_freight_term    VARCHAR2 (30);
        lc_fob_point       VARCHAR2 (30);
        ln_warehouse_id    NUMBER;
        lc_error_flag      VARCHAR2 (10);
        lc_error_message   VARCHAR2 (4000) := NULL;
        ln_price_list_id   NUMBER;
    BEGIN
        BEGIN
            SELECT b.transaction_type_id, a.shipping_method_code, a.freight_terms_code,
                   a.fob_point_code, a.order_category_code, a.warehouse_id,
                   a.price_list_id
              INTO px_header_rec (1).order_type_id, lc_ship_via, lc_freight_term, lc_fob_point,
                                                  px_header_rec (1).order_category, ln_warehouse_id, ln_price_list_id
              FROM oe_transaction_types_all a, oe_transaction_types_tl b
             WHERE     a.transaction_type_id = b.transaction_type_id
                   AND b.LANGUAGE = USERENV ('LANG')
                   AND b.NAME = px_header_rec (1).order_type;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'NO DATA FOUND Exception occurs when retrieving Order type information:'
                    || SUBSTR (SQLERRM, 1, 2000);
            WHEN OTHERS
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'Exception occurs when retrieving ship to information:'
                    || SUBSTR (SQLERRM, 1, 2000);
        END;

        IF NVL (x_error_flag, 'X') != 'E'
        THEN
            -- Set Shipping Method
            IF     lc_ship_via IS NOT NULL
               AND px_header_rec (1).shipping_method IS NULL
            THEN
                get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                     , lc_error_flag, lc_error_message);
                x_error_message   := x_error_message || lc_error_message;
                x_error_flag      := lc_error_flag;
            END IF;

            -- Setup Freight Terms
            IF     lc_freight_term IS NOT NULL
               AND px_header_rec (1).freight_terms IS NULL
            THEN
                px_header_rec (1).freight_terms   := lc_freight_term;
                px_header_rec (1).attribute1      :=
                    get_freight_terms (lc_freight_term);
            END IF;

            /* -- Setup FOB Point
            IF lc_fob_point IS NOT NULL AND px_header_rec(1).fob_point_code IS NULL THEN
            px_header_rec(1).fob_point_code := lc_fob_point;
            END IF;
            */
            -- Set WareHouse
            IF     ln_warehouse_id IS NOT NULL
               AND px_header_rec (1).warehouse_id IS NULL
            THEN
                px_header_rec (1).warehouse   :=
                    get_warehosue_name (ln_warehouse_id);

                IF px_header_rec (1).warehouse IS NOT NULL
                THEN
                    px_header_rec (1).warehouse_id   := ln_warehouse_id;
                END IF;
            END IF;
        END IF;

        -- ver 2.1 commented as price list default is not dependent on RD
        --  IF px_header_rec (1).requested_date IS NOT NULL
        --  THEN
        IF     ln_price_list_id IS NOT NULL
           AND px_header_rec (1).price_list IS NULL
        THEN
            SELECT NAME
              INTO px_header_rec (1).price_list
              FROM qp_list_headers_tl ql
             WHERE     list_header_id = ln_price_list_id
                   AND LANGUAGE = USERENV ('LANG');

            px_header_rec (1).price_list_id   := ln_price_list_id;
        END IF;
    --  END IF;
    END get_order_hire_default;

    PROCEDURE get_order_hire_default_line (
        px_header_rec     IN OUT NOCOPY xxd_btom_oeline_tbltype,
        p_flag            IN            VARCHAR2,
        p_call_from       IN            VARCHAR2,
        x_error_flag         OUT        VARCHAR2,
        x_error_message      OUT        VARCHAR2)
    IS
        lc_ship_via        VARCHAR2 (30);
        lc_freight_term    VARCHAR2 (30);
        lc_fob_point       VARCHAR2 (30);
        ln_warehouse_id    NUMBER;
        lc_error_flag      VARCHAR2 (10);
        lc_error_message   VARCHAR2 (4000) := NULL;
    BEGIN
        BEGIN
            IF p_call_from = 'CREATE_ORDER'
            THEN
                SELECT ottt.NAME, otta.transaction_type_id, otta.shipping_method_code,
                       otta.freight_terms_code, otta.warehouse_id
                  INTO px_header_rec (1).line_type, px_header_rec (1).line_type_id, lc_ship_via, lc_freight_term,
                                                  ln_warehouse_id
                  FROM oe_transaction_types_all otta, oe_transaction_types_tl ottt
                 WHERE     otta.transaction_type_code = 'LINE'
                       AND otta.transaction_type_id =
                           ottt.transaction_type_id
                       AND ottt.LANGUAGE = USERENV ('LANG')
                       AND EXISTS
                               (SELECT 1
                                  FROM oe_transaction_types_all a, oe_transaction_types_tl b
                                 WHERE     a.transaction_type_id =
                                           b.transaction_type_id
                                       AND otta.transaction_type_id =
                                           a.default_outbound_line_type_id
                                       AND b.LANGUAGE = USERENV ('LANG')
                                       AND b.NAME =
                                           px_header_rec (1).order_type
                                       AND a.transaction_type_code = 'ORDER');
            ELSIF p_call_from = 'RETURN'
            THEN
                SELECT ottt.NAME, otta.transaction_type_id, otta.shipping_method_code,
                       otta.freight_terms_code, otta.warehouse_id
                  INTO px_header_rec (1).line_type, px_header_rec (1).line_type_id, lc_ship_via, lc_freight_term,
                                                  ln_warehouse_id
                  FROM oe_transaction_types_all otta, oe_transaction_types_tl ottt
                 WHERE     otta.transaction_type_code = 'LINE'
                       AND otta.transaction_type_id =
                           ottt.transaction_type_id
                       AND ottt.LANGUAGE = USERENV ('LANG')
                       AND EXISTS
                               (SELECT 1
                                  FROM oe_transaction_types_all a, oe_transaction_types_tl b
                                 WHERE     a.transaction_type_id =
                                           b.transaction_type_id
                                       AND otta.transaction_type_id =
                                           a.default_inbound_line_type_id
                                       AND b.LANGUAGE = USERENV ('LANG')
                                       AND b.NAME =
                                           px_header_rec (1).order_type
                                       AND a.transaction_type_code = 'ORDER');
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'NO DATA FOUND Exception occurs when retrieving Order type information:'
                    || SUBSTR (SQLERRM, 1, 2000);
            WHEN OTHERS
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'Exception occurs when retrieving ship to information:'
                    || SUBSTR (SQLERRM, 1, 2000);
        END;

        IF p_flag = 'Y'
        THEN
            IF NVL (x_error_flag, 'X') != 'E'
            THEN
                -- Set Shipping Method
                IF     lc_ship_via IS NOT NULL
                   AND px_header_rec (1).shipping_method IS NULL
                THEN
                    get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                         , lc_error_flag, lc_error_message);
                    x_error_message   := x_error_message || lc_error_message;
                    x_error_flag      := lc_error_flag;
                END IF;

                -- Setup Freight Terms
                IF     lc_freight_term IS NOT NULL
                   AND px_header_rec (1).freight_terms IS NULL
                THEN
                    px_header_rec (1).freight_terms   := lc_freight_term;
                    px_header_rec (1).attribute6      :=
                        get_freight_terms (lc_freight_term);
                END IF;

                -- Set WareHouse
                IF     ln_warehouse_id IS NOT NULL
                   AND px_header_rec (1).warehouse_id IS NULL
                THEN
                    px_header_rec (1).warehouse   :=
                        get_warehosue_name (ln_warehouse_id);

                    IF px_header_rec (1).warehouse IS NOT NULL
                    THEN
                        px_header_rec (1).warehouse_id   := ln_warehouse_id;
                    END IF;
                END IF;
            END IF;
        END IF;                                              --IF p_flag = 'Y'
    END get_order_hire_default_line;

    PROCEDURE get_price_hire_default (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        lc_ship_via          VARCHAR2 (30);
        ln_order_type_id     NUMBER (15);
        ln_payment_term_id   NUMBER (15);
        lc_freight_term      VARCHAR2 (30);
        lc_fob_point         VARCHAR2 (30);
        lc_error_flag        VARCHAR2 (10);
        lc_error_message     VARCHAR2 (4000) := NULL;
    BEGIN
        BEGIN
            SELECT a.list_header_id, a.ship_method_code, a.freight_terms_code,
                   a.terms_id, a.currency_code
              INTO px_header_rec (1).price_list_id, lc_ship_via, lc_freight_term, ln_payment_term_id,
                                                  px_header_rec (1).currency
              FROM qp_list_headers_b a, qp_list_headers_tl b
             WHERE     b.NAME = px_header_rec (1).price_list
                   AND a.list_header_id = b.list_header_id
                   AND b.LANGUAGE = USERENV ('LANG');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_error_flag                      := 'E';
                x_error_message                   :=
                       'No Data Found for the Price List :- '
                    || px_header_rec (1).price_list;
                px_header_rec (1).price_list      := NULL;
                px_header_rec (1).price_list_id   := NULL;
            WHEN OTHERS
            THEN
                px_header_rec (1).price_list      := NULL;
                px_header_rec (1).price_list_id   := NULL;
                x_error_flag                      := 'E';
                x_error_message                   :=
                       'Exception occurs when retrieving ship to information:'
                    || SQLERRM;
        END;

        IF NVL (x_error_flag, 'X') != 'E'
        THEN
            -- Set Shipping Method
            IF     lc_ship_via IS NOT NULL
               AND px_header_rec (1).shipping_method IS NULL
            THEN
                get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                     , lc_error_flag, lc_error_message);
                x_error_message   := x_error_message || lc_error_message;
                x_error_flag      := lc_error_flag;
            END IF;

            -- Set Payment Terms
            IF     ln_payment_term_id IS NOT NULL
               AND px_header_rec (1).payment_terms_id IS NULL
            THEN
                px_header_rec (1).payment_terms   :=
                    get_payment_name (ln_payment_term_id);

                IF px_header_rec (1).payment_terms IS NOT NULL
                THEN
                    px_header_rec (1).payment_terms_id   :=
                        ln_payment_term_id;
                END IF;
            END IF;

            -- Setup Freight Terms
            IF     lc_freight_term IS NOT NULL
               AND px_header_rec (1).freight_terms IS NULL
            THEN
                px_header_rec (1).freight_terms   := lc_freight_term;
                px_header_rec (1).attribute1      :=
                    get_freight_terms (lc_freight_term);
            END IF;
        /* -- Setup FOB Point
        IF lc_fob_point IS NOT NULL AND px_header_rec(1).fob_point_code IS NULL THEN
        px_header_rec(1).fob_point_code := lc_fob_point;
        END IF; */
        END IF;
    END get_price_hire_default;

    PROCEDURE get_price_hire_default_line (px_header_rec IN OUT NOCOPY xxd_btom_oeline_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        lc_ship_via          VARCHAR2 (30);
        ln_order_type_id     NUMBER (15);
        ln_payment_term_id   NUMBER (15);
        lc_freight_term      VARCHAR2 (30);
        lc_fob_point         VARCHAR2 (30);
        lc_error_flag        VARCHAR2 (10);
        lc_error_message     VARCHAR2 (4000) := NULL;
    BEGIN
        BEGIN
            SELECT a.ship_method_code, a.freight_terms_code, a.terms_id
              INTO lc_ship_via, lc_freight_term, ln_payment_term_id
              FROM qp_list_headers_b a, qp_list_headers_tl b
             WHERE     b.NAME = px_header_rec (1).price_list
                   AND a.list_header_id = b.list_header_id
                   AND b.LANGUAGE = USERENV ('LANG');
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                x_error_flag                   := 'E';
                px_header_rec (1).price_list   := NULL;
            WHEN OTHERS
            THEN
                px_header_rec (1).price_list   := NULL;
                x_error_flag                   := 'E';
                x_error_message                :=
                       'Exception occurs when retrieving ship to information:'
                    || SQLERRM;
        END;

        IF NVL (x_error_flag, 'X') != 'E'
        THEN
            -- Set Shipping Method
            IF     lc_ship_via IS NOT NULL
               AND px_header_rec (1).shipping_method IS NULL
            THEN
                get_shipping_method (lc_ship_via, px_header_rec (1).shipping_method, px_header_rec (1).shipping_method_code
                                     , lc_error_flag, lc_error_message);
                x_error_message   := x_error_message || lc_error_message;
                x_error_flag      := lc_error_flag;
            END IF;

            -- Set Payment Terms
            IF     ln_payment_term_id IS NOT NULL
               AND px_header_rec (1).payment_terms_id IS NULL
            THEN
                px_header_rec (1).payment_terms   :=
                    get_payment_name (ln_payment_term_id);

                IF px_header_rec (1).payment_terms IS NOT NULL
                THEN
                    px_header_rec (1).payment_terms_id   :=
                        ln_payment_term_id;
                END IF;
            END IF;

            -- Setup Freight Terms
            IF     lc_freight_term IS NOT NULL
               AND px_header_rec (1).freight_terms IS NULL
            THEN
                px_header_rec (1).freight_terms   := lc_freight_term;
                px_header_rec (1).attribute6      :=
                    get_freight_terms (lc_freight_term);
            END IF;
        END IF;
    END get_price_hire_default_line;

    /******************************************************
    * Procedure:  prep_currency
    *
    * Synopsis: This function is for getting default currency.
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    PROCEDURE prep_currency (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        lc_currency_code   VARCHAR2 (15);
    BEGIN
        BEGIN
            lc_currency_code   :=
                oe_default_pvt.get_sob_currency_code (
                    'OE_DEFAULT_PVT',
                    'Get_SOB_Currency_Code');
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.put_line (
                       'Error when calling func OE_Default_Pvt.Get_SOB_currency_Code.'
                    || ' '
                    || SQLCODE
                    || SQLERRM);
                x_error_flag   := 'E';
                x_error_message   :=
                       ' Exception while fetching the Currency Code - '
                    || SUBSTR (SQLERRM, 1, 2000);
        END;

        IF lc_currency_code IS NOT NULL
        THEN
            px_header_rec (1).currency   := lc_currency_code;
        END IF;
    END prep_currency;

    /******************************************************
    * Procedure:   prep_shipinstr
    *
    * Synopsis: This procedure is for preparing shipping instructions. Should be called after proc prep_default_by_ship_to (org_id)
    * Design:
    *
    * Notes:
    *
    * Modifications:
    *
    ******************************************************/
    /* PROCEDURE prep_shipinstr( px_header_rec IN OUT NOCOPY XXD_BTOM_OEHEADER_TBLTYPE
    ,x_error_flag     OUT VARCHAR2
    ,x_error_message  OUT VARCHAR2)
    IS
    CURSOR lcu_get_long_text(p_rule_id IN NUMBER
    ,p_user_name    IN VARCHAR2
    )
    IS
    SELECT long_text
    FROM oe_attachment_rules        OAR,
    fnd_documents_vl           FDV,
    fnd_documents_long_text    FDL,
    fnd_document_categories_vl FDC
    WHERE OAR.rule_id        = p_rule_id
    AND OAR.document_id    = FDV.document_id
    AND FDV.datatype_name  = 'Long Text'
    AND FDV.media_id       = FDL.media_id
    AND FDC.CATEGORY_ID    = FDV.CATEGORY_id
    AND FDC.application_id = 660
    AND FDC.user_name      = p_user_name;
    ln_rule_id  NUMBER       := NULL;
    lc_shipping VARCHAR2(30) := 'Shipping Instructions';
    lc_packing  VARCHAR2(30) := 'Packing Instructions';
    BEGIN
    BEGIN
    SELECT rule_id
    INTO ln_rule_id
    FROM oe_attachment_rule_elements_v
    WHERE attribute_name = 'Ship To'
    AND attribute_value = px_header_rec(1).ship_to_address_id;
    EXCEPTION
    WHEN OTHERS THEN
    ln_rule_id := NULL;
    END;
    BEGIN
    IF ln_rule_id IS NULL THEN
    SELECT rule_id
    INTO ln_rule_id
    FROM oe_attachment_rule_elements_v
    WHERE attribute_name = 'Customer'
    AND attribute_value = px_header_rec(1).customer_id;
    END IF;
    EXCEPTION
    WHEN OTHERS THEN
    ln_rule_id := NULL;
    END;
    IF ln_rule_id IS NOT NULL THEN
    OPEN  lcu_get_long_text(ln_rule_id,lc_shipping);
    FETCH lcu_get_long_text INTO px_header_rec(1).shipping_instructions;
    CLOSE lcu_get_long_text;
    OPEN  lcu_get_long_text(ln_rule_id,lc_packing);
    FETCH lcu_get_long_text INTO px_header_rec(1).packing_instructions;
    CLOSE lcu_get_long_text;
    END IF;
    END prep_shipinstr;
    */
    PROCEDURE prep_shipinstr (px_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        CURSOR lcu_get_long_text (p_cust_account_id   IN NUMBER,
                                  p_user_name         IN VARCHAR2)
        IS
            SELECT long_text
              FROM oe_attachment_rules oar, fnd_documents_vl fdv, fnd_documents_long_text fdl,
                   fnd_document_categories_vl fdc, hz_parties party, hz_cust_accounts cust,
                   oe_attachment_rule_elements_v oare
             WHERE     1 = 1
                   --AND OAR.rule_id        = p_rule_id
                   AND oar.document_id = fdv.document_id
                   AND fdv.datatype_name = 'Long Text'
                   AND fdv.media_id = fdl.media_id
                   AND fdc.category_id = fdv.category_id
                   AND fdc.application_id = 660
                   AND fdc.user_name = p_user_name
                   AND party_name = fdv.title
                   AND party.party_id = cust.party_id
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

        ln_rule_id    NUMBER := NULL;
        lc_shipping   VARCHAR2 (30) := 'Shipping Instructions';
        lc_packing    VARCHAR2 (30) := 'Packing Instructions';
        l_hdr_vas     VARCHAR2 (240);                               -- ver 2.2
    BEGIN
        -- begin 2.2
        -- look for ship and pack intruction in vas configuration custom table; if data found there then go with the existing logic
        get_hdr_ship_pack_instr (px_header_rec (1).customer_id,
                                 px_header_rec (1).ship_to_address_id,
                                 px_header_rec (1).bill_to_address_id,
                                 px_header_rec (1).shipping_instructions,
                                 px_header_rec (1).packing_instructions);

        -- end   2.2
        IF px_header_rec (1).shipping_instructions IS NULL
        THEN                                                        -- ver 2.2
            OPEN lcu_get_long_text (px_header_rec (1).customer_id,
                                    lc_shipping);

            FETCH lcu_get_long_text
                INTO px_header_rec (1).shipping_instructions;

            CLOSE lcu_get_long_text;
        END IF;                                                     -- ver 2.2

        IF px_header_rec (1).packing_instructions IS NULL
        THEN                                                        -- ver 2.2
            OPEN lcu_get_long_text (px_header_rec (1).customer_id,
                                    lc_packing);

            FETCH lcu_get_long_text
                INTO px_header_rec (1).packing_instructions;

            CLOSE lcu_get_long_text;
        END IF;                                                     -- ver 2.2

        --  begin 2.2 vas code at hdr level
        l_hdr_vas   :=
            get_vas_code ('HEADER', px_header_rec (1).customer_id, NULL,
                          NULL, NULL);

        IF l_hdr_vas IS NULL
        THEN -- vas from custom vas solution is null then only go with the std logic
            FOR lr_get_vas_code_text
                IN lcu_get_vas_code_text (px_header_rec (1).customer_id)
            LOOP
                IF px_header_rec (1).attribute3 IS NULL
                THEN
                    px_header_rec (1).attribute3   :=
                        lr_get_vas_code_text.short_text;
                ELSE
                    px_header_rec (1).attribute3   :=
                           px_header_rec (1).attribute3
                        || '+'
                        || lr_get_vas_code_text.short_text;
                END IF;
            END LOOP;
        ELSE
            px_header_rec (1).attribute3   := l_hdr_vas;
        END IF;
    /* OPEN lcu_get_vas_code_text(px_header_rec (1).customer_id);
    FETCH lcu_get_vas_code_text INTO px_header_rec (1).attribute3;
    CLOSE lcu_get_vas_code_text;
    */
    END prep_shipinstr;

    PROCEDURE get_salesrep_name_header (p_customer_id IN NUMBER, p_ship_to_id IN NUMBER, p_bill_to_id IN NUMBER
                                        , px_header_rec IN OUT NOCOPY XXD_BTOM_OEHEADER_TBLTYPE, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        CURSOR lcu_get_site_salerep_id (p_site_id NUMBER)
        IS
            SELECT name, salesrep_id
              FROM ra_salesreps RS
             WHERE EXISTS
                       (SELECT 1
                          FROM hz_cust_site_uses HCSU
                         WHERE     site_use_id = p_site_id
                               AND HCSU.primary_salesrep_id = RS.salesrep_id);

        lc_multiSale_rep    VARCHAR2 (30) := NULL;
        lc_noSales_credit   VARCHAR2 (30) := NULL;
    BEGIN
        SELECT DISTINCT attribute3, attribute4
          INTO lc_multiSale_rep, lc_noSales_credit
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXDO_SALESREP_DEFAULTS'
               AND language = USERENV ('LANG');

        BEGIN
            --Add start and end condition to be added
            SELECT salesrep_name
              INTO px_header_rec (1).sales_rep
              FROM do_custom.do_rep_cust_assignment
             WHERE     org_id = px_header_rec (1).org_id
                   --AND customer_id = p_cust_account_id1
                   AND site_use_id = p_bill_to_id
                   AND brand = NVL (px_header_rec (1).brand, brand)
                   AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (START_DATE),
                                                    TRUNC (SYSDATE))
                                           AND NVL (TRUNC (END_DATE),
                                                    TRUNC (SYSDATE));
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                px_header_rec (1).sales_rep   := lc_multiSale_rep;
            WHEN NO_DATA_FOUND
            THEN
                px_header_rec (1).sales_rep   := NULL;
            WHEN OTHERS
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       'Exception occurs when retrieving salesrep at header level: '
                    || SUBSTR (SQLERRM, 1, 2000);
        END;

        IF px_header_rec (1).sales_rep IS NULL
        THEN
            BEGIN
                --Add start and end condition to be added
                SELECT salesrep_name
                  INTO px_header_rec (1).sales_rep
                  FROM do_custom.do_rep_cust_assignment
                 WHERE     org_id = px_header_rec (1).org_id
                       --AND customer_id = p_cust_account_id1
                       AND site_use_id = p_ship_to_id
                       AND brand = NVL (px_header_rec (1).brand, brand)
                       AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (START_DATE),
                                                        TRUNC (SYSDATE))
                                               AND NVL (TRUNC (END_DATE),
                                                        TRUNC (SYSDATE));
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    px_header_rec (1).sales_rep   := lc_multiSale_rep;
                WHEN NO_DATA_FOUND
                THEN
                    px_header_rec (1).sales_rep   := NULL;
                WHEN OTHERS
                THEN
                    x_error_flag   := 'E';
                    x_error_message   :=
                           'Exception occurs when retrieving salesrep at header level: '
                        || SUBSTR (SQLERRM, 1, 2000);
            END;
        END IF;

        IF NVL (x_error_flag, 'S') != 'E'
        THEN
            IF px_header_rec (1).sales_rep IS NULL
            THEN
                OPEN lcu_get_site_salerep_id (p_ship_to_id);

                FETCH lcu_get_site_salerep_id
                    INTO px_header_rec (1).sales_rep, px_header_rec (1).sales_rep_id;

                CLOSE lcu_get_site_salerep_id;

                IF px_header_rec (1).sales_rep IS NULL
                THEN
                    OPEN lcu_get_site_salerep_id (p_bill_to_id);

                    FETCH lcu_get_site_salerep_id
                        INTO px_header_rec (1).sales_rep, px_header_rec (1).sales_rep_id;

                    CLOSE lcu_get_site_salerep_id;
                END IF;

                /* IF px_header_rec(1).sales_rep IS NULL THEN
                OPEN  lcu_get_acct_salerep_id (p_customer_id);
                FETCH lcu_get_acct_salerep_id INTO px_header_rec(1).sales_rep,px_header_rec(1).sales_rep_id;
                CLOSE lcu_get_acct_salerep_id;
                END IF;
                */
                IF px_header_rec (1).sales_rep IS NULL
                THEN
                    px_header_rec (1).sales_rep   := lc_noSales_credit;
                END IF;
            END IF;

            SELECT salesrep_id
              INTO px_header_rec (1).sales_rep_id
              FROM ra_salesreps
             WHERE     name = px_header_rec (1).sales_rep
                   AND status = 'A'
                   AND SYSDATE BETWEEN start_date_active
                                   AND NVL (end_date_active, SYSDATE);
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            px_header_rec (1).sales_rep      := NULL;
            px_header_rec (1).sales_rep_id   := NULL;
        WHEN OTHERS
        THEN
            px_header_rec (1).sales_rep      := NULL;
            px_header_rec (1).sales_rep_id   := NULL;
            x_error_flag                     := 'E';
            x_error_message                  :=
                   'Exception occurs when retrieving salesrep at header level: '
                || SUBSTR (SQLERRM, 1, 2000);
    END get_salesrep_name_header;

    PROCEDURE get_salesrep_name_line (p_customer_id IN NUMBER, p_site_to_id IN NUMBER, p_bill_to_id IN NUMBER, P_site_uses IN VARCHAR2, px_header_rec IN OUT NOCOPY XXD_BTOM_OELINE_TBLTYPE, x_error_flag OUT VARCHAR2
                                      , x_error_message OUT VARCHAR2)
    IS
        CURSOR lcu_get_site_salerep_id (p_site_id NUMBER)
        IS
            SELECT name, salesrep_id
              FROM ra_salesreps RS
             WHERE EXISTS
                       (SELECT 1
                          FROM hz_cust_site_uses HCSU
                         WHERE     site_use_id = p_site_id
                               AND HCSU.primary_salesrep_id = RS.salesrep_id);

        lc_multiSale_rep    VARCHAR2 (30) := NULL;
        lc_noSales_credit   VARCHAR2 (30) := NULL;
        ln_salesrep_id      NUMBER;                                 -- ver 2.4
        l_style             VARCHAR2 (240);                         -- ver 2.4
        l_color             VARCHAR2 (240);                         -- ver 2.4
    BEGIN
        SELECT DISTINCT attribute3, attribute4
          INTO lc_multiSale_rep, lc_noSales_credit
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXDO_SALESREP_DEFAULTS'
               AND language = USERENV ('LANG');


        BEGIN
            SELECT salesrep_name
              INTO px_header_rec (1).sales_rep
              FROM do_custom.do_rep_cust_assignment
             WHERE     site_use_id = p_site_to_id
                   AND org_id = px_header_rec (1).org_id
                   AND brand = px_header_rec (1).brand
                   AND division = px_header_rec (1).division
                   AND department = px_header_rec (1).department
                   AND class = px_header_rec (1).class
                   AND sub_class = px_header_rec (1).sub_class
                   AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (START_DATE),
                                                    TRUNC (SYSDATE))
                                           AND NVL (TRUNC (END_DATE),
                                                    TRUNC (SYSDATE));
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                px_header_rec (1).sales_rep   := lc_multiSale_rep;
            WHEN NO_DATA_FOUND
            THEN
                px_header_rec (1).sales_rep   := NULL;
            WHEN OTHERS
            THEN
                px_header_rec (1).sales_rep   := NULL;
                x_error_flag                  := 'E';
                x_error_message               :=
                       'Exception occurs when retrieving salesrep : '
                    || SUBSTR (SQLERRM, 1, 2000);
        END;

        BEGIN
            IF px_header_rec (1).sales_rep IS NULL
            THEN
                SELECT salesrep_name
                  INTO px_header_rec (1).sales_rep
                  FROM do_custom.do_rep_cust_assignment
                 WHERE     site_use_id = p_site_to_id
                       AND org_id = px_header_rec (1).org_id
                       AND brand = px_header_rec (1).brand
                       AND division = px_header_rec (1).division
                       AND department = px_header_rec (1).department
                       AND class = px_header_rec (1).class
                       AND sub_class IS NULL
                       AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (START_DATE),
                                                        TRUNC (SYSDATE))
                                               AND NVL (TRUNC (END_DATE),
                                                        TRUNC (SYSDATE));
            END IF;
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                px_header_rec (1).sales_rep   := lc_multiSale_rep;
            WHEN NO_DATA_FOUND
            THEN
                px_header_rec (1).sales_rep   := NULL;
        END;

        BEGIN
            IF px_header_rec (1).sales_rep IS NULL
            THEN
                SELECT salesrep_name
                  INTO px_header_rec (1).sales_rep
                  FROM do_custom.do_rep_cust_assignment
                 WHERE     site_use_id = p_site_to_id
                       AND org_id = px_header_rec (1).org_id
                       AND brand = px_header_rec (1).brand
                       AND division = px_header_rec (1).division
                       AND department = px_header_rec (1).department
                       AND class IS NULL
                       AND sub_class IS NULL
                       AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (START_DATE),
                                                        TRUNC (SYSDATE))
                                               AND NVL (TRUNC (END_DATE),
                                                        TRUNC (SYSDATE));
            END IF;
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                px_header_rec (1).sales_rep   := lc_multiSale_rep;
            WHEN NO_DATA_FOUND
            THEN
                px_header_rec (1).sales_rep   := NULL;
        END;

        BEGIN
            IF px_header_rec (1).sales_rep IS NULL
            THEN
                SELECT salesrep_name
                  INTO px_header_rec (1).sales_rep
                  FROM do_custom.do_rep_cust_assignment
                 WHERE     site_use_id = p_site_to_id
                       AND org_id = px_header_rec (1).org_id
                       AND brand = px_header_rec (1).brand
                       AND division = px_header_rec (1).division
                       AND department IS NULL
                       AND class IS NULL
                       AND sub_class IS NULL
                       AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (START_DATE),
                                                        TRUNC (SYSDATE))
                                               AND NVL (TRUNC (END_DATE),
                                                        TRUNC (SYSDATE));
            END IF;
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                px_header_rec (1).sales_rep   := lc_multiSale_rep;
            WHEN NO_DATA_FOUND
            THEN
                px_header_rec (1).sales_rep   := NULL;
        END;

        BEGIN
            IF px_header_rec (1).sales_rep IS NULL
            THEN
                SELECT salesrep_name
                  INTO px_header_rec (1).sales_rep
                  FROM do_custom.do_rep_cust_assignment
                 WHERE     site_use_id = p_site_to_id
                       AND org_id = px_header_rec (1).org_id
                       AND brand = px_header_rec (1).brand
                       AND division IS NULL
                       AND department IS NULL
                       AND class IS NULL
                       AND sub_class IS NULL
                       AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (START_DATE),
                                                        TRUNC (SYSDATE))
                                               AND NVL (TRUNC (END_DATE),
                                                        TRUNC (SYSDATE));
            END IF;
        EXCEPTION
            WHEN TOO_MANY_ROWS
            THEN
                px_header_rec (1).sales_rep   := lc_multiSale_rep;
            WHEN NO_DATA_FOUND
            THEN
                px_header_rec (1).sales_rep   := NULL;
        END;

        IF NVL (x_error_flag, 'S') != 'E' AND P_site_uses = 'SHIP_TO'
        THEN
            IF px_header_rec (1).sales_rep IS NULL
            THEN
                OPEN lcu_get_site_salerep_id (p_site_to_id);

                FETCH lcu_get_site_salerep_id
                    INTO px_header_rec (1).sales_rep, px_header_rec (1).sales_rep_id;

                CLOSE lcu_get_site_salerep_id;

                IF px_header_rec (1).sales_rep IS NULL
                THEN
                    OPEN lcu_get_site_salerep_id (p_bill_to_id);

                    FETCH lcu_get_site_salerep_id
                        INTO px_header_rec (1).sales_rep, px_header_rec (1).sales_rep_id;

                    CLOSE lcu_get_site_salerep_id;
                END IF;

                /* IF px_header_rec(1).sales_rep IS NULL THEN
                OPEN  lcu_get_acct_salerep_id (p_customer_id);
                FETCH lcu_get_acct_salerep_id INTO px_header_rec(1).sales_rep,px_header_rec(1).sales_rep_id;
                CLOSE lcu_get_acct_salerep_id;
                END IF;
                */
                IF px_header_rec (1).sales_rep IS NULL
                THEN
                    px_header_rec (1).sales_rep   := lc_noSales_credit;
                END IF;
            END IF;
        END IF;

        -- ver 2.4
        -- adf pass style in this format 1008402-CHESTER and vas store style as 1008402, so doing substr

        SELECT DECODE (INSTR (px_header_rec (1).attribute9, '-'), 0, px_header_rec (1).attribute9, SUBSTR (px_header_rec (1).attribute9, 1, INSTR (px_header_rec (1).attribute9, '-') - 1))
          INTO l_style
          FROM DUAL;

        SELECT DECODE (px_header_rec (1).attribute10, 'NA', NULL, px_header_rec (1).attribute10)
          INTO l_color
          FROM DUAL;

        ln_salesrep_id   :=
            xxd_oe_salesrep_assn_pkg.get_sales_rep (px_header_rec (1).org_id, p_customer_id, p_site_to_id, px_header_rec (1).brand, px_header_rec (1).division, px_header_rec (1).department, px_header_rec (1).class, px_header_rec (1).sub_class, l_style
                                                    , l_color);

        -- defaulting rule package is able to return the salesrep
        IF ln_salesrep_id IS NOT NULL
        THEN
            px_header_rec (1).sales_rep_id   := ln_salesrep_id;

            SELECT name
              INTO px_header_rec (1).sales_rep
              FROM ra_salesreps
             WHERE     salesrep_id = ln_salesrep_id
                   AND status = 'A'
                   AND SYSDATE BETWEEN start_date_active
                                   AND NVL (end_date_active, SYSDATE);
        END IF;

        -- end  ver 2.4

        SELECT salesrep_id
          INTO px_header_rec (1).sales_rep_id
          FROM ra_salesreps
         WHERE     name = px_header_rec (1).sales_rep
               AND status = 'A'
               AND SYSDATE BETWEEN start_date_active
                               AND NVL (end_date_active, SYSDATE);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            px_header_rec (1).sales_rep      := NULL;
            px_header_rec (1).sales_rep_id   := NULL;
        WHEN OTHERS
        THEN
            px_header_rec (1).sales_rep      := NULL;
            px_header_rec (1).sales_rep_id   := NULL;
            x_error_flag                     := 'E';
            x_error_message                  :=
                   'Exception occurs when retrieving salesrep at header level: '
                || SUBSTR (SQLERRM, 1, 2000);
    END get_salesrep_name_line;

    FUNCTION check_ship_bill_to_relation (p_bill_to_id   NUMBER,
                                          p_brand        VARCHAR2)
        RETURN NUMBER
    IS
        ln_bill_to_id   NUMBER;
    BEGIN
        SELECT hcsu.site_use_id
          INTO ln_bill_to_id
          FROM hz_cust_site_uses hcsu
         WHERE     1 = 1                    -- hcsu.site_use_id = p_bill_to_id
               AND hcsu.location = (SELECT location || '_' || p_brand
                                      FROM hz_cust_site_uses
                                     WHERE site_use_id = p_bill_to_id)
               AND hcsu.site_use_code = 'BILL_TO'
               AND hcsu.status = 'A';

        RETURN ln_bill_to_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END check_ship_bill_to_relation;

    PROCEDURE default_main_sales_order_dls (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER, p_call_form IN VARCHAR2, p_brand IN VARCHAR2, p_order_type IN VARCHAR2, p_order_date IN DATE, p_requested_date IN DATE, p_header_rec OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2
                                            , x_error_message OUT VARCHAR2)
    IS
        CURSOR lcu_get_demand_class (p_cust_acct_id NUMBER)
        IS
            SELECT flv.lookup_code, flv.meaning
              FROM fnd_lookup_values flv, hz_cust_accounts hca
             WHERE     flv.lookup_type = 'DEMAND_CLASS'
                   AND flv.enabled_flag = 'Y'
                   AND flv.LANGUAGE = USERENV ('LANG')
                   AND hca.cust_account_id = p_cust_acct_id
                   AND hca.attribute13 = flv.meaning
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE);

        lc_demand_class_code   VARCHAR2 (60);
        lc_demand_class        VARCHAR2 (60);
        lc_error_message       VARCHAR2 (4000);
        lc_error_flag          VARCHAR2 (10);
        lc_order_type          VARCHAR2 (10);               -- Added w.r.t 1.5
    BEGIN
        DBMS_OUTPUT.put_line (' Inside default_main_sales_order_dls ');
        /* Init */
        init (p_org_id, p_user_id, p_resp_id,
              p_resp_appl_id);
        p_header_rec   := xxd_btom_oeheader_tbltype ();
        p_header_rec.EXTEND (1);
        p_header_rec (1)   :=
            xxd_btom_oe_header_type (NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL);

        IF p_customer_id IS NOT NULL
        THEN
            p_header_rec (1).customer_id      := p_customer_id;
            p_header_rec (1).CALL_FORM        := p_call_form;
            p_header_rec (1).order_date       := p_order_date;
            p_header_rec (1).requested_date   := p_requested_date;
            p_header_rec (1).brand            := p_brand;
            --p_header_rec (1).order_type := p_order_type;
            p_header_rec (1).order_type       := NULL;
            DBMS_OUTPUT.put_line (
                ' customer_id - ' || p_header_rec (1).customer_id);
            default_customer_details (p_customer_id, p_org_id, p_header_rec,
                                      lc_error_flag, lc_error_message);
            x_error_flag                      := lc_error_flag;
            x_error_message                   := lc_error_message;

            IF NVL (x_error_flag, 'X') != 'E'
            THEN
                DBMS_OUTPUT.put_line (
                       ' bill_to_address_id 3 - '
                    || p_header_rec (1).bill_to_address_id);
                lc_error_flag      := NULL;
                lc_error_message   := NULL;
                default_header_details (p_header_rec (1).customer_id, p_header_rec (1).org_id, p_user_id, p_resp_id, p_resp_appl_id, p_header_rec (1).ship_to_address_id, p_header_rec (1).bill_to_address_id, p_order_type, NULL, p_header_rec, 'N', p_header_rec (1).order_date, p_header_rec (1).requested_date, p_header_rec (1).brand, NULL
                                        , lc_error_flag, lc_error_message);
                DBMS_OUTPUT.put_line (
                    ' default_header_details - ' || lc_error_message);
                x_error_flag       := lc_error_flag;
                x_error_message    :=
                    x_error_message || ' - ' || lc_error_message;
                DBMS_OUTPUT.put_line (
                    ' default_header_details - ' || x_error_message);
            END IF;
        ELSE
            x_error_flag      := 'E';
            x_error_message   := 'Customer Id sholud be passed from UI ';
        END IF;

        DBMS_OUTPUT.put_line (
            ' p_header_rec(1).currency - ' || p_header_rec (1).currency);

        IF p_header_rec (1).currency IS NULL
        THEN
            prep_currency (p_header_rec, lc_error_flag, lc_error_message);
            x_error_flag      := lc_error_flag;
            x_error_message   := x_error_message || ' - ' || lc_error_message;
            DBMS_OUTPUT.put_line (
                ' p_header_rec(1).currency - ' || p_header_rec (1).currency);
            DBMS_OUTPUT.put_line (
                   ' p_header_rec(1).currency x_error_message - '
                || x_error_message);
        END IF;

        OPEN lcu_get_demand_class (p_header_rec (1).customer_id);

        FETCH lcu_get_demand_class INTO lc_demand_class_code, lc_demand_class;

        CLOSE lcu_get_demand_class;

        DBMS_OUTPUT.put_line (
            ' lc_demand_class_code - ' || lc_demand_class_code);
        DBMS_OUTPUT.put_line (' lc_demand_class - ' || lc_demand_class);

        IF lc_demand_class_code IS NOT NULL
        THEN
            p_header_rec (1).demand_class_code   := lc_demand_class_code;
            p_header_rec (1).demand_class        := lc_demand_class;
        ELSE
            x_error_message   :=
                x_error_message || ' - ' || 'Demand Class Is Not Defined. ';
            x_error_flag   := 'E';
        END IF;

        -- Start Added by Infosys w.r.t 1.5
        SELECT NVL (otta.ATTRIBUTE1, 'Y')
          INTO lc_order_type
          FROM oe_transaction_types_tl ottt, oe_transaction_types_all otta
         WHERE     ottt.transaction_type_id = p_header_rec (1).ORDER_TYPE_ID
               AND otta.transaction_type_id = ottt.transaction_type_id
               AND ottt.LANGUAGE = USERENV ('LANG');

        IF (lc_order_type != 'Y')
        THEN
            p_header_rec (1).ORDER_TYPE   := NULL;
        END IF;
    -- End Added by Infosys w.r.t 1.5
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error_flag   := 'E';
            x_error_message   :=
                   'Exception in main call to defualt package -  '
                || SUBSTR (SQLERRM, 1, 2000);
    END default_main_sales_order_dls;

    PROCEDURE default_customer_details (
        p_customer_id     IN            NUMBER,
        p_org_id          IN            NUMBER,
        p_header_rec      IN OUT NOCOPY xxd_btom_oeheader_tbltype,
        x_error_flag         OUT        VARCHAR2,
        x_error_message      OUT        VARCHAR2)
    IS
        ex_default_ship_to     EXCEPTION;
        ex_default_bill_to     EXCEPTION;
        ex_default_cust_info   EXCEPTION;
        ln_bill_to             NUMBER := 0;
    BEGIN
        prep_default_by_ship_to (p_header_rec, x_error_flag, x_error_message);

        IF NVL (x_error_flag, 'X') = 'E'
        THEN
            RAISE ex_default_ship_to;
        END IF;

        -- Checking If the bill to is tagged to ship to
        x_error_flag   := NULL;
        DBMS_OUTPUT.put_line (
            ' bill_to_address_id 1 - ' || p_header_rec (1).bill_to_address_id);

        IF p_header_rec (1).bill_to_address_id IS NULL
        THEN
            prep_default_by_bill_to (p_header_rec,
                                     x_error_flag,
                                     x_error_message);
        ELSE
            ln_bill_to   :=
                check_ship_bill_to_relation (
                    p_header_rec (1).bill_to_address_id,
                    p_header_rec (1).brand);

            IF ln_bill_to != 0
            THEN
                p_header_rec (1).bill_to_address_id   := ln_bill_to;
                get_bill_to_hire_default (p_customer_id, p_header_rec (1).bill_to_address_id, p_header_rec
                                          , x_error_flag, x_error_message);
            ELSE
                prep_default_by_bill_to (p_header_rec,
                                         x_error_flag,
                                         x_error_message);
            END IF;
        END IF;

        --prep_default_by_deliver_to (p_header_rec, x_error_flag, x_error_message);
        IF NVL (x_error_flag, 'X') = 'E'
        THEN
            RAISE ex_default_bill_to;
        END IF;

        x_error_flag   := NULL;
        prep_customer_info (p_header_rec, x_error_flag, x_error_message);

        IF NVL (x_error_flag, 'X') = 'E'
        THEN
            RAISE ex_default_cust_info;
        END IF;
    EXCEPTION
        WHEN ex_default_ship_to
        THEN
            x_error_message   :=
                'Error while defaulting by Ship To :- ' || x_error_message;
        WHEN ex_default_bill_to
        THEN
            x_error_message   :=
                'Error while defaulting by Bill To :- ' || x_error_message;
        WHEN ex_default_cust_info
        THEN
            x_error_message   :=
                   'Error while defaulting by Customer information :- '
                || x_error_message;
    END default_customer_details;

    PROCEDURE default_header_details (
        p_customer_id      IN            NUMBER,
        p_org_id           IN            NUMBER,
        p_user_id          IN            NUMBER,
        p_resp_id          IN            NUMBER,
        p_resp_appl_id     IN            NUMBER,
        p_site_to_id       IN            NUMBER,
        p_bill_to_id       IN            NUMBER,
        p_order_type       IN            VARCHAR2,
        p_price_type       IN            VARCHAR2,
        p_header_rec       IN OUT NOCOPY xxd_btom_oeheader_tbltype,
        p_flag             IN            VARCHAR2,
        p_order_date       IN            DATE,
        p_requested_date   IN            DATE,
        p_brand            IN            VARCHAR2,
        p_call_from        IN            VARCHAR2,
        x_error_flag          OUT        VARCHAR2,
        x_error_message       OUT        VARCHAR2)
    IS
        ln_bill_to_id      NUMBER;
        lc_error_flag      VARCHAR2 (10);
        lc_error_message   VARCHAR2 (4000);
        lc_err_msg         VARCHAR2 (4000);
        ln_bill_to_value   NUMBER := 0;

        CURSOR lcu_get_customer_class (p_cust_acct_id NUMBER)
        IS
            SELECT customer_class_code
              FROM hz_cust_accounts
             WHERE cust_account_id = p_cust_acct_id;
    BEGIN
        DBMS_OUTPUT.put_line ('Inside default_header_details - ');

        IF p_flag = 'Y'
        THEN
            /* Init */
            init (p_org_id, p_user_id, p_resp_id,
                  p_resp_appl_id);
            p_header_rec                          := xxd_btom_oeheader_tbltype ();
            p_header_rec.EXTEND (1);
            p_header_rec (1)                      :=
                xxd_btom_oe_header_type (NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL);
            p_header_rec (1).customer_id          := p_customer_id;
            p_header_rec (1).order_date           := p_order_date;
            p_header_rec (1).requested_date       := p_requested_date;
            p_header_rec (1).brand                := p_brand;
            p_header_rec (1).ship_to_address_id   := p_site_to_id;
            p_header_rec (1).bill_to_address_id   := p_bill_to_id;
            p_header_rec (1).org_id               := p_org_id;
            p_header_rec (1).order_type           := p_order_type;
            p_header_rec (1).price_list           := p_price_type;
        END IF;

        ln_bill_to_id     := p_bill_to_id;

        OPEN lcu_get_customer_class (p_customer_id);

        FETCH lcu_get_customer_class INTO p_header_rec (1).customer_class;

        CLOSE lcu_get_customer_class;

        IF     p_header_rec (1).requested_date IS NOT NULL
           AND p_header_rec (1).price_list IS NULL
        THEN
            default_price_list_details (p_header_rec,
                                        x_error_flag,
                                        lc_err_msg);
            lc_error_message   := lc_err_msg;
        END IF;

        IF p_site_to_id IS NOT NULL
        THEN
            get_ship_to_hire_default (p_customer_id, p_site_to_id, p_header_rec
                                      , x_error_flag, lc_err_msg);
            lc_error_message   := lc_error_message || ' - ' || lc_err_msg;
        END IF;

        IF NVL (x_error_flag, 'X') != 'E'
        THEN                                  -- If Ship to Hierarchy is Error
            IF p_header_rec (1).bill_to_address_id IS NULL
            THEN
                p_header_rec (1).bill_to_address_id   := ln_bill_to_id;
            END IF;

            IF p_header_rec (1).bill_to_address_id IS NOT NULL
            THEN
                IF p_call_from = 'BILL_TO'
                THEN
                    p_header_rec (1).bill_to_address_id   := ln_bill_to_id;
                ELSE
                    ln_bill_to_value   :=
                        check_ship_bill_to_relation (
                            p_header_rec (1).bill_to_address_id,
                            p_header_rec (1).brand);

                    IF ln_bill_to_value != 0
                    THEN
                        p_header_rec (1).bill_to_address_id   :=
                            ln_bill_to_value;
                    ELSE
                        p_header_rec (1).bill_to_address_id   :=
                            ln_bill_to_id;
                    END IF;
                END IF;

                get_bill_to_hire_default (p_customer_id, p_header_rec (1).bill_to_address_id, p_header_rec
                                          , x_error_flag, lc_err_msg);
            END IF;

            IF NVL (x_error_flag, 'X') != 'E'
            THEN                              -- If Bill to Hierarchy is Error
                IF p_customer_id IS NOT NULL
                THEN
                    get_cust_to_hire_default (p_customer_id, p_header_rec, x_error_flag
                                              , lc_err_msg);
                    lc_error_message   :=
                        lc_error_message || ' - ' || lc_err_msg;
                END IF;

                IF p_header_rec (1).order_type IS NULL
                THEN
                    p_header_rec (1).order_type   := p_order_type;
                END IF;

                IF p_header_rec (1).order_type IS NOT NULL
                THEN
                    get_order_hire_default (p_header_rec,
                                            x_error_flag,
                                            lc_err_msg);
                    lc_error_message   :=
                        lc_error_message || ' - ' || lc_err_msg;
                END IF;

                /* default_price_list_details(p_header_rec
                ,x_error_flag
                ,x_error_message
                );
                */
                IF p_header_rec (1).price_list IS NOT NULL
                THEN
                    get_price_hire_default (p_header_rec,
                                            x_error_flag,
                                            lc_err_msg);
                    lc_error_message   :=
                        lc_error_message || ' - ' || lc_err_msg;
                END IF;
            END IF;                           -- If Bill to Hierarchy is Error
        END IF;                               -- If Ship to Hierarchy is Error

        x_error_message   := lc_error_message;
        --IF p_site_to_id IS NOT NULL THEN
        /*  IF p_header_rec (1).brand IS NOT NULL
        THEN
        IF p_bill_to_id IS NOT NULL
        THEN
        get_salesrep_name_header (p_customer_id,
        p_bill_to_id,
        'BILL_TO',
        p_header_rec,
        x_error_flag,
        x_error_message
        );
        DBMS_OUTPUT.put_line (   ' p_header_rec(1).sales_rep_id - '
        || p_header_rec (1).sales_rep_id
        );
        DBMS_OUTPUT.put_line
        (   ' IF p_bill_to_id IS NOT NULL THEN  x_error_message - '
        || x_error_message
        );
        END IF;
        IF p_site_to_id IS NOT NULL AND p_header_rec (1).sales_rep_id IS NULL
        THEN
        get_salesrep_name_header (p_customer_id,
        p_site_to_id,
        'SHIP_TO',
        p_header_rec,
        x_error_flag,
        x_error_message
        );
        DBMS_OUTPUT.put_line
        (   ' IF p_site_to_id IS NOT NULL THEN  x_error_message - '
        || x_error_message
        );
        DBMS_OUTPUT.put_line (   ' p_header_rec(1).sales_rep_id - '
        || p_header_rec (1).sales_rep_id
        );
        END IF;
        */
        get_salesrep_name_header (p_customer_id,
                                  p_site_to_id,
                                  p_header_rec (1).bill_to_address_id,
                                  p_header_rec,
                                  x_error_flag,
                                  lc_error_message);
        x_error_message   := x_error_message || lc_error_message;
        prep_shipinstr (p_header_rec, x_error_flag, lc_error_message);
        x_error_message   := x_error_message || lc_error_message;
        -- END IF;
        DBMS_OUTPUT.put_line (' Before complete default_header_details ');
    END default_header_details;

    PROCEDURE default_price_list_details (p_header_rec IN OUT NOCOPY xxd_btom_oeheader_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        lc_price_list_name   VARCHAR2 (150);
        lc_customer_clas     VARCHAR2 (60);
    BEGIN
        SELECT customer_class_code
          INTO lc_customer_clas
          FROM hz_cust_accounts
         WHERE cust_account_id = p_header_rec (1).customer_id;

        SELECT ql.list_header_id, NAME, qlb.currency_code
          INTO p_header_rec (1).price_list_id, p_header_rec (1).price_list, p_header_rec (1).currency
          FROM qp_list_headers_tl ql, qp_list_headers_b qlb
         WHERE     EXISTS
                       (SELECT 1
                          FROM xxd_default_pricelist_matrix pl
                         WHERE     TRUNC (p_header_rec (1).order_date) BETWEEN TRUNC (
                                                                                   pl.order_start_date)
                                                                           AND TRUNC (
                                                                                   pl.order_end_date)
                               AND TRUNC (p_header_rec (1).requested_date) BETWEEN TRUNC (
                                                                                       pl.requested_start_date)
                                                                               AND TRUNC (
                                                                                       pl.requested_end_date)
                               AND pl.brand = p_header_rec (1).brand
                               AND pl.customer_class = lc_customer_clas
                               --p_header_rec(1).customer_class_code
                               AND pl.org_id = p_header_rec (1).org_id
                               AND pl.price_list_name = ql.NAME)
               AND ql.LANGUAGE = USERENV ('LANG')
               AND qlb.list_header_id = ql.list_header_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            x_error_message   :=
                   'No Data In The Price List Matrix For The Requested Date - '
                || TRUNC (p_header_rec (1).requested_date);
        WHEN OTHERS
        THEN
            p_header_rec (1).price_list   := NULL;
    END default_price_list_details;

    PROCEDURE default_line_details (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER, p_ship_to_id IN NUMBER, p_bill_to_id IN NUMBER, p_brand IN VARCHAR2, p_division IN VARCHAR2, p_department IN VARCHAR2, p_class IN VARCHAR2, p_sub_class IN VARCHAR2, p_flag IN VARCHAR2, -- Pass Y, IF the Bill_to OR Ship_to is changed at line level
                                                                                                                                                                                                                                                                                                                                              p_price_list IN VARCHAR2, p_order_type IN VARCHAR2, p_call_from IN VARCHAR2, p_ship_or_bill_to IN VARCHAR2, p_style IN VARCHAR2 DEFAULT NULL, -- VER 2.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_color IN VARCHAR2 DEFAULT NULL, -- VER 2.3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              p_header_rec OUT NOCOPY xxd_btom_oeline_tbltype, x_error_flag OUT VARCHAR2
                                    , x_error_message OUT VARCHAR2)
    IS
        CURSOR lcu_get_demand_class (p_cust_acct_id NUMBER)
        IS
            SELECT flv.lookup_code, flv.meaning
              FROM fnd_lookup_values flv, hz_cust_accounts hca
             WHERE     flv.lookup_type = 'DEMAND_CLASS'
                   AND flv.enabled_flag = 'Y'
                   AND flv.LANGUAGE = USERENV ('LANG')
                   AND hca.cust_account_id = p_cust_acct_id
                   AND hca.attribute13 = flv.meaning
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE);

        lc_demand_class_code   VARCHAR2 (60);
        lc_demand_class        VARCHAR2 (60);
        ln_bill_to_id          NUMBER;
        ln_bill_to_value       NUMBER := 0;
        l_ship_instr           VARCHAR2 (2000);                     -- ver 2.2
        l_pack_instr           VARCHAR2 (2000);                     -- ver 2.2
        l_line_vas             VARCHAR2 (240);                      -- ver 2.2
    BEGIN
        init (p_org_id, p_user_id, p_resp_id,
              p_resp_appl_id);
        p_header_rec                          := xxd_btom_oeline_tbltype ();
        p_header_rec.EXTEND (1);
        p_header_rec (1)                      :=
            xxd_btom_oe_line_type (NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL, NULL,
                                   NULL, NULL);
        p_header_rec (1).brand                := p_brand;
        p_header_rec (1).division             := p_division;
        p_header_rec (1).department           := p_department;
        p_header_rec (1).CLASS                := p_class;
        p_header_rec (1).sub_class            := p_sub_class;
        p_header_rec (1).org_id               := p_org_id;
        p_header_rec (1).ship_to_address_id   := p_ship_to_id;
        p_header_rec (1).bill_to_address_id   := p_bill_to_id;
        p_header_rec (1).price_list           := p_price_list;
        p_header_rec (1).order_type           := p_order_type;
        p_header_rec (1).attribute9           := p_style;           -- ver 2.4
        p_header_rec (1).attribute10          := p_color;           -- ver 2.4

        /*  BEGIN
        SELECT attribute13
        INTO   p_header_rec(1).demand_class
        FROM   hz_cust_accounts
        WHERE cust_account_id = p_customer_id;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
        p_header_rec(1).demand_class := NULL;
        WHEN OTHERS THEN
        x_error_message := 'Exception occurs when retrieving demand class information:'
        ||SUBSTR(SQLERRM,1,1500);
        END;
        */
        OPEN lcu_get_demand_class (p_customer_id);

        FETCH lcu_get_demand_class INTO lc_demand_class_code, lc_demand_class;

        CLOSE lcu_get_demand_class;

        IF lc_demand_class_code IS NOT NULL
        THEN
            p_header_rec (1).demand_class_code   := lc_demand_class_code;
            p_header_rec (1).demand_class        := lc_demand_class;
        ELSE
            x_error_message   :=
                x_error_message || ' - ' || 'Demand Class Is Not Defined. ';
            x_error_flag   := 'E';
        END IF;

        IF    p_header_rec (1).ship_to_address_id IS NOT NULL
           OR p_header_rec (1).bill_to_address_id IS NOT NULL
        THEN
            IF     p_header_rec (1).brand IS NOT NULL
               AND p_header_rec (1).division IS NOT NULL
               AND p_header_rec (1).department IS NOT NULL
               AND p_header_rec (1).CLASS IS NOT NULL
               AND p_header_rec (1).sub_class IS NOT NULL
            THEN
                get_salesrep_name_line (p_customer_id, p_header_rec (1).bill_to_address_id, p_header_rec (1).bill_to_address_id, 'BILL_TO', p_header_rec, x_error_flag
                                        , x_error_message);

                IF p_header_rec (1).sales_rep_id IS NULL
                THEN
                    get_salesrep_name_line (p_customer_id, p_ship_to_id, p_header_rec (1).bill_to_address_id, 'SHIP_TO', p_header_rec, x_error_flag
                                            , x_error_message);
                END IF;
            ELSE
                x_error_flag   := 'E';
                x_error_message   :=
                       x_error_message
                    || ' Brand OR Division OR Department OR Class OR Sub Class values are not provided from UI ';
            END IF;

            /*        IF p_header_rec (1).order_type IS NOT NULL
            THEN
            get_order_hire_default_line (p_header_rec,
            p_flag,
            p_call_from,
            x_error_flag,
            x_error_message
            );
            END IF;
            */
            --IF Ship to OR Bill to changed at line level
            IF p_flag = 'Y'
            THEN
                ln_bill_to_id   := p_bill_to_id;

                /*            IF p_header_rec (1).order_type IS NOT NULL
                THEN
                get_order_hire_default_line (p_header_rec,
                p_flag,
                p_call_from,
                x_error_flag,
                x_error_message
                );
                END IF; */
                IF p_ship_to_id IS NOT NULL
                THEN
                    get_ship_to_hire_default_line (p_customer_id,
                                                   p_ship_to_id,
                                                   p_header_rec,
                                                   x_error_flag,
                                                   x_error_message);
                END IF;

                IF NVL (x_error_flag, 'X') != 'E'
                THEN                          -- If Ship to Hierarchy is Error
                    IF p_header_rec (1).bill_to_address_id IS NULL
                    THEN
                        p_header_rec (1).bill_to_address_id   :=
                            ln_bill_to_id;
                    END IF;

                    IF p_header_rec (1).bill_to_address_id IS NOT NULL
                    THEN
                        IF p_ship_or_bill_to = 'BILL_TO'
                        THEN
                            p_header_rec (1).bill_to_address_id   :=
                                ln_bill_to_id;
                        ELSE
                            ln_bill_to_value   :=
                                check_ship_bill_to_relation (
                                    p_header_rec (1).bill_to_address_id,
                                    p_header_rec (1).brand);

                            IF ln_bill_to_value != 0
                            THEN
                                p_header_rec (1).bill_to_address_id   :=
                                    ln_bill_to_value;
                            ELSE
                                p_header_rec (1).bill_to_address_id   :=
                                    ln_bill_to_id;
                            END IF;
                        END IF;

                        get_bill_to_hire_default_line (
                            p_customer_id,
                            p_header_rec (1).bill_to_address_id,
                            p_header_rec,
                            x_error_flag,
                            x_error_message);
                    END IF;

                    IF NVL (x_error_flag, 'X') != 'E'
                    THEN                      -- If Bill to Hierarchy is Error
                        IF p_customer_id IS NOT NULL
                        THEN
                            get_cust_to_hire_default_line (p_customer_id, p_header_rec, x_error_flag
                                                           , x_error_message);
                        END IF;
                    /*                  IF p_price_list IS NOT NULL
                    THEN
                    get_price_hire_default_line (p_header_rec,
                    x_error_flag,
                    x_error_message
                    );
                    END IF;                   --IF p_price_list IS NOT NULL THEN */
                    END IF;                   -- If Bill to Hierarchy is Error
                END IF;                       -- If Ship to Hierarchy is Error
            END IF;                                     --IF p_flag = 'Y' THEN
        END IF;

        IF p_header_rec (1).order_type IS NOT NULL
        THEN
            get_order_hire_default_line (p_header_rec, p_flag, p_call_from,
                                         x_error_flag, x_error_message);
        END IF;

        IF p_price_list IS NOT NULL
        THEN
            get_price_hire_default_line (p_header_rec,
                                         x_error_flag,
                                         x_error_message);
        END IF;                             --IF p_price_list IS NOT NULL THEN

        -- ver 2.2
        l_ship_instr                          := p_header_rec (1).attribute1;
        l_pack_instr                          := p_header_rec (1).attribute2;
        get_hdr_ship_pack_instr (p_customer_id,
                                 p_ship_to_id,
                                 p_bill_to_id,
                                 p_header_rec (1).attribute1,
                                 p_header_rec (1).attribute2);

        IF p_header_rec (1).attribute1 IS NULL
        THEN
            p_header_rec (1).attribute1   := l_ship_instr;
        END IF;

        IF p_header_rec (1).attribute2 IS NULL
        THEN
            p_header_rec (1).attribute2   := l_pack_instr;
        END IF;

        l_line_vas                            := NULL;
        l_line_vas                            :=
            get_vas_code ('LINE', p_customer_id, p_ship_to_id,
                          p_style, p_color);
        p_header_rec (1).attribute3           := l_line_vas; -- line level vas
    -- END VER 2.2
    END default_line_details;

    PROCEDURE doe_profile_value (p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER, p_profile_name IN VARCHAR2, x_error_flag OUT VARCHAR2
                                 , x_error_message OUT VARCHAR2)
    IS
    BEGIN
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_appl_id);
        x_error_flag   := fnd_profile.VALUE (p_profile_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error_flag      := NULL;
            x_error_message   := SQLERRM;
    END doe_profile_value;

    PROCEDURE assign_default_values (
        p_org_id                       IN     NUMBER,
        p_user_id                      IN     NUMBER,
        p_resp_id                      IN     NUMBER,
        p_resp_appl_id                 IN     NUMBER,
        x_currency_code                   OUT VARCHAR2,
        x_transaction_type_id             OUT NUMBER,
        x_transaction_type                OUT VARCHAR2,
        x_return_transaction_type_id      OUT NUMBER,
        x_return_transaction_type         OUT VARCHAR2,
        x_error_flag                      OUT VARCHAR2,
        x_error_message                   OUT VARCHAR2)
    IS
        CURSOR lcu_get_oe_trxn_type IS
            SELECT transaction_type_id, NAME
              FROM (  SELECT ottvl.transaction_type_id, ottvl.transaction_type_code, ottvl.NAME,
                             ottvl.description
                        FROM oe_transaction_types_vl ottvl
                       WHERE     ottvl.attribute1 = 'Y'
                             AND ottvl.attribute2 = 'Y'
                             AND ottvl.order_category_code IN
                                     ('MIXED', 'ORDER')
                             AND SYSDATE BETWEEN NVL (ottvl.start_date_active,
                                                      SYSDATE)
                                             AND NVL (ottvl.end_date_active,
                                                      SYSDATE)
                    ORDER BY ottvl.NAME DESC)
             WHERE ROWNUM = 1;

        CURSOR lcu_get_return_trxn_type IS
            SELECT transaction_type_id, NAME
              FROM (  SELECT ottvl.transaction_type_id, ottvl.transaction_type_code, ottvl.NAME,
                             ottvl.description
                        FROM oe_transaction_types_vl ottvl
                       WHERE     ottvl.attribute1 = 'Y'
                             AND ottvl.attribute2 = 'Y'
                             AND ottvl.order_category_code = 'RETURN'
                             AND SYSDATE BETWEEN NVL (ottvl.start_date_active,
                                                      SYSDATE)
                                             AND NVL (ottvl.end_date_active,
                                                      SYSDATE)
                    ORDER BY ottvl.NAME DESC)
             WHERE ROWNUM = 1;

        CURSOR lcu_get_default_currency (p_org_id NUMBER)
        IS
            SELECT gs.currency_code
              FROM gl_sets_of_books gs, hr_operating_units ho
             WHERE     ho.set_of_books_id = gs.set_of_books_id
                   AND ho.organization_id = p_org_id;
    BEGIN
        init (p_org_id, p_user_id, p_resp_id,
              p_resp_appl_id);

        OPEN lcu_get_oe_trxn_type;

        FETCH lcu_get_oe_trxn_type INTO x_transaction_type_id, x_transaction_type;

        CLOSE lcu_get_oe_trxn_type;

        OPEN lcu_get_return_trxn_type;

        FETCH lcu_get_return_trxn_type INTO x_return_transaction_type_id, x_return_transaction_type;

        CLOSE lcu_get_return_trxn_type;

        OPEN lcu_get_default_currency (p_org_id);

        FETCH lcu_get_default_currency INTO x_currency_code;

        CLOSE lcu_get_default_currency;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error_flag      := 'E';
            x_error_message   := SQLERRM;
    END assign_default_values;

    PROCEDURE check_cust_po_number (p_header_id IN NUMBER, p_cust_acct_id IN NUMBER, p_org_id IN NUMBER
                                    , p_cust_po_no IN VARCHAR2, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2)
    IS
        ln_cnt          NUMBER;
        ln_exists_cnt   NUMBER;

        CURSOR lcu_get_custpo_exists (pheader_id    NUMBER,
                                      pcust_po_no   VARCHAR2)
        IS
            SELECT COUNT (*)
              FROM oe_order_headers_all
             WHERE     header_id = pheader_id
                   AND UPPER (cust_po_number) = UPPER (pcust_po_no);
    BEGIN
        OPEN lcu_get_custpo_exists (p_header_id, p_cust_po_no);

        FETCH lcu_get_custpo_exists INTO ln_exists_cnt;

        CLOSE lcu_get_custpo_exists;

        IF ln_exists_cnt = 0
        THEN
            SELECT COUNT (*)
              INTO ln_cnt
              FROM oe_order_headers_all
             WHERE     header_id != p_header_id
                   AND sold_to_org_id = p_cust_acct_id
                   AND org_id = p_org_id
                   AND UPPER (cust_po_number) = UPPER (p_cust_po_no);

            IF ln_cnt > 0
            THEN
                x_error_flag   := 'E';
                x_error_message   :=
                       ' The customer PO number - '
                    || p_cust_po_no
                    || ' already exists for this customer. ';
            ELSE
                x_error_flag      := 'S';
                x_error_message   := NULL;
            END IF;
        ELSE
            x_error_flag      := 'S';
            x_error_message   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error_flag   := 'E';
            x_error_message   :=
                   'Exception while chekcing cust_po_number - '
                || SUBSTR (SQLERRM, 1, 1500);
    END check_cust_po_number;

    PROCEDURE check_enable_apply_price_adj (p_user_id NUMBER, p_resp_id NUMBER, p_resp_appl_id NUMBER, p_orgid NUMBER, p_order_type_id NUMBER, p_call_from VARCHAR2
                                            , p_status_flag OUT VARCHAR, p_error_flag OUT VARCHAR2, p_error_message OUT VARCHAR2)
    IS
        lc_discount_value   VARCHAR2 (30);
        lc_enforce_flag     VARCHAR2 (10);
    BEGIN
        fnd_global.apps_initialize (user_id        => p_user_id,
                                    resp_id        => p_resp_id,
                                    resp_appl_id   => p_resp_appl_id);
        mo_global.set_policy_context ('S', p_orgid);

        SELECT NVL (fnd_profile.VALUE ('ONT_DISCOUNTING_PRIVILEGE'), 'NONE')
          INTO lc_discount_value
          FROM DUAL;

        IF p_call_from = 'HEADER'
        THEN
            SELECT NVL (enforce_line_prices_flag, 'N')
              INTO lc_enforce_flag
              FROM oe_transaction_types_all
             WHERE transaction_type_id = p_order_type_id;
        ELSIF p_call_from = 'LINE'
        THEN
            lc_enforce_flag   := 'N';
        END IF;

        IF lc_discount_value = 'FULL' AND lc_enforce_flag = 'Y'
        THEN
            p_status_flag   := 'N';
        ELSIF lc_discount_value = 'FULL' AND lc_enforce_flag = 'N'
        THEN
            p_status_flag   := 'Y';
        ELSIF lc_discount_value = 'UNLIMITED'
        THEN
            p_status_flag   := 'Y';
        ELSIF     lc_discount_value = 'NON-OVERRIDABLE ONLY'
              AND lc_enforce_flag = 'Y'
        THEN
            p_status_flag   := 'N';
        ELSIF     lc_discount_value = 'NON-OVERRIDABLE ONLY'
              AND lc_enforce_flag = 'N'
        THEN
            p_status_flag   := 'Y';
        ELSIF lc_discount_value = 'NONE'
        THEN
            p_status_flag   := 'N';
        END IF;

        IF p_status_flag = 'N'
        THEN
            p_error_message   :=
                'You are not authorized to apply manual price adjustment.';
        END IF;

        p_error_flag   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_flag    := 'E';
            p_status_flag   := 'N';
            p_error_message   :=
                   'Exception while checking the role based asscess for Apply Price Adjustment - '
                || SUBSTR (SQLERRM, 1, 1000);
    END check_enable_apply_price_adj;

    FUNCTION get_line_status_value (p_line_id            NUMBER,
                                    P_flow_status_code   VARCHAR2)
        RETURN VARCHAR2
    IS
        lc_line_status   VARCHAR2 (30);
    BEGIN
        IF p_line_id IS NOT NULL
        THEN
            SELECT OE_LINE_STATUS_PUB.Get_Line_Status (p_line_id, P_flow_status_code)
              INTO lc_line_status
              FROM DUAL;

            RETURN lc_line_status;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_line_status_value;

    PROCEDURE default_warehouse (p_ou_id IN NUMBER, p_brand IN VARCHAR2, p_division IN VARCHAR2, p_department IN VARCHAR2, --Start Changes V2.0
                                                                                                                           pd_request_date IN DATE, pn_order_type_id IN NUMBER, --End Changes V2.0
                                                                                                                                                                                p_style_desc IN VARCHAR2, -- ver 2.5
                                                                                                                                                                                                          x_warehouse OUT VARCHAR2, x_org_id OUT NUMBER
                                 , x_error_msg OUT VARCHAR2)
    IS
        lc_ou_name            VARCHAR2 (100);
        lc_line_type          VARCHAR2 (300);
        l_exception           EXCEPTION;
        l_inventory_item_id   NUMBER;
    BEGIN
        --Start Changes V2.0
        x_org_id   :=
            xxd_do_om_default_rules.ret_org_move_warehouse (p_ou_id,
                                                            p_brand,
                                                            pn_order_type_id,
                                                            pd_request_date);

        --ver 2.5 begin
        IF x_org_id IS NULL
        THEN
            BEGIN
                SELECT inventory_item_id
                  INTO l_inventory_item_id
                  FROM apps.xxd_common_items_v
                 WHERE     1 = 1
                       AND department = p_department
                       AND brand = p_brand
                       AND division = p_division
                       AND style_desc = p_style_desc
                       AND organization_id = 106
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            x_org_id   :=
                xxd_do_om_default_rules.ret_inv_warehouse (
                    p_ou_id,
                    pn_order_type_id,
                    NULL,
                    pd_request_date,
                    l_inventory_item_id);
        END IF;

        -- ver 2.5 end

        IF x_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT ood.organization_name
                  INTO x_warehouse
                  FROM org_organization_definitions ood
                 WHERE 1 = 1 AND ood.organization_id = x_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_org_id      := NULL;
                    x_warehouse   := NULL;
            END;
        END IF;

        IF x_org_id IS NULL
        THEN
            --End Changes V2.0
            --get OU name
            SELECT NAME
              INTO lc_ou_name
              FROM hr_operating_units
             WHERE     organization_id = p_ou_id
                   AND TRUNC (SYSDATE) BETWEEN NVL (date_from,
                                                    TRUNC (SYSDATE))
                                           AND NVL (date_to, TRUNC (SYSDATE));

            /*lc_line_type := '';
            --get line type
            IF ont_line_def_hdlr.g_record.line_type_id IS NOT NULL THEN
            SELECT t.name
            INTO   lc_line_type
            FROM   oe_transaction_types_tl  t
            ,oe_transaction_types_all b
            WHERE  b.transaction_type_id = t.transaction_type_id
            AND    t.language = userenv('LANG')
            AND    trunc(SYSDATE) BETWEEN b.start_date_active AND
            nvl(b.end_date_active, trunc(SYSDATE))
            AND    b.transaction_type_code = 'LINE'
            AND    b.transaction_type_id =
            ont_line_def_hdlr.g_record.line_type_id;
            END IF;*/
            /* START 27-MAY-2016 - Commented the code to fix warehouse default issue for CCR0004991
            --get warehouse from mapping lookup
            BEGIN
            SELECT ood.organization_id,ood.organization_name
            INTO   x_org_id,x_warehouse
            FROM   fnd_lookup_values_vl         flv
            ,org_organization_definitions ood
            WHERE  flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
            AND    flv.enabled_flag = 'Y'
            AND    TRUNC(SYSDATE) BETWEEN flv.start_date_active AND
            NVL(flv.end_date_active, TRUNC(SYSDATE))
            AND    flv.description = lc_ou_name
            --AND    nvl(attribute1, lc_line_type) = lc_line_type
            AND    flv.attribute2 = p_brand
            AND    NVL(flv.attribute3, p_division) = p_division
            AND    NVL(flv.attribute4, p_department) = p_department
            AND    flv.attribute5 = ood.organization_code;
            END Changes 27-MAY-2016 for CCR0004991*/
            -- START 27-MAY-2016- Added to fix the warehouse defaulting issue for for CCR0004991
            BEGIN
                SELECT ood.organization_id, ood.organization_name
                  INTO x_org_id, x_warehouse
                  FROM fnd_lookup_values_vl flv, org_organization_definitions ood
                 WHERE     flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
                       AND flv.enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                               AND NVL (flv.end_date_active,
                                                        TRUNC (SYSDATE))
                       AND flv.description = lc_ou_name
                       --AND NVL (attribute1, lc_line_type) = lc_line_type -- Commented INC0303220
                       AND flv.attribute2 = p_brand
                       AND flv.attribute3 = p_division
                       AND flv.attribute4 = p_department
                       AND flv.attribute5 = ood.organization_code;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_org_id      := NULL;
                    x_warehouse   := NULL;
                WHEN OTHERS
                THEN
                    x_org_id      := NULL;
                    x_warehouse   := NULL;
                    x_error_msg   :=
                           'Exception while fetching warehouse- '
                        || SUBSTR (SQLERRM, 1, 2000);
            END;

            BEGIN
                IF x_org_id IS NULL
                THEN
                    SELECT ood.organization_id, ood.organization_name
                      INTO x_org_id, x_warehouse
                      FROM fnd_lookup_values_vl flv, org_organization_definitions ood
                     WHERE     flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           TRUNC (SYSDATE))
                           AND flv.description = lc_ou_name
                           --AND NVL (attribute1, lc_line_type) = lc_line_type -- Commented INC0303220
                           AND flv.attribute2 = p_brand
                           AND flv.attribute3 = p_division
                           AND flv.attribute4 IS NULL
                           AND flv.attribute5 = ood.organization_code;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_org_id      := NULL;
                    x_warehouse   := NULL;
                WHEN OTHERS
                THEN
                    x_org_id      := NULL;
                    x_warehouse   := NULL;
            END;

            BEGIN
                IF x_org_id IS NULL
                THEN
                    SELECT ood.organization_id, ood.organization_name
                      INTO x_org_id, x_warehouse
                      FROM fnd_lookup_values_vl flv, org_organization_definitions ood
                     WHERE     flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           TRUNC (SYSDATE))
                           AND flv.description = lc_ou_name
                           --AND NVL (attribute1, lc_line_type) = lc_line_type -- Commented INC0303220
                           AND flv.attribute2 = p_brand
                           AND flv.attribute3 IS NULL
                           AND flv.attribute4 IS NULL
                           AND flv.attribute5 = ood.organization_code;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    x_org_id      := NULL;
                    x_warehouse   := NULL;
                WHEN OTHERS
                THEN
                    x_org_id      := NULL;
                    x_warehouse   := NULL;
            END;
        END IF;
    -- END Changes 27-MAY-2016 for CCR0004991
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error_msg   :=
                   'Exception while fetching warehouse- '
                || SUBSTR (SQLERRM, 1, 2000);
            x_org_id      := NULL;
            x_warehouse   := NULL;
    END default_warehouse;

    FUNCTION get_line_reserved_quantity (p_header_id   NUMBER,
                                         p_line_id     NUMBER)
        RETURN VARCHAR2
    IS
        l_open_quantity        NUMBER := 0;
        l_reserved_quantity    NUMBER := 0;
        l_mtl_sales_order_id   NUMBER;
        l_return_status        VARCHAR2 (1);
        l_msg_count            NUMBER;
        l_msg_data             VARCHAR2 (240);
        l_rsv_rec              inv_reservation_global.mtl_reservation_rec_type;
        l_rsv_tbl              inv_reservation_global.mtl_reservation_tbl_type;
        l_count                NUMBER;
        l_x_error_code         NUMBER;
        l_lock_records         VARCHAR2 (1);
        l_sort_by_req_date     NUMBER;
        l_converted_qty        NUMBER;
        l_inventory_item_id    NUMBER;
        l_order_quantity_uom   VARCHAR2 (30);
    BEGIN
        IF p_line_id IS NOT NULL
        THEN
            l_mtl_sales_order_id                :=
                OE_HEADER_UTIL.Get_Mtl_Sales_Order_Id (
                    p_header_id => p_header_id);
            l_rsv_rec.demand_source_header_id   := l_mtl_sales_order_id;
            l_rsv_rec.demand_source_line_id     := p_line_id;
            l_rsv_rec.organization_id           := NULL;
            INV_RESERVATION_PUB.QUERY_RESERVATION_OM_HDR_LINE (
                p_api_version_number          => 1.0,
                p_init_msg_lst                => fnd_api.g_true,
                x_return_status               => l_return_status,
                x_msg_count                   => l_msg_count,
                x_msg_data                    => l_msg_data,
                p_query_input                 => l_rsv_rec,
                x_mtl_reservation_tbl         => l_rsv_tbl,
                x_mtl_reservation_tbl_count   => l_count,
                x_error_code                  => l_x_error_code,
                p_lock_records                => l_lock_records,
                p_sort_by_req_date            => l_sort_by_req_date);

            BEGIN
                SELECT order_quantity_uom, inventory_item_id
                  INTO l_order_quantity_uom, l_inventory_item_id
                  FROM oe_order_lines_all
                 WHERE line_id = p_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_order_quantity_uom   := NULL;
            END;

            FOR I IN 1 .. l_rsv_tbl.COUNT
            LOOP
                l_rsv_rec   := l_rsv_tbl (I);

                IF NVL (l_order_quantity_uom, l_rsv_rec.reservation_uom_code) <>
                   l_rsv_rec.reservation_uom_code
                THEN
                    l_converted_qty   :=
                        Oe_Order_Misc_Util.convert_uom (
                            l_inventory_item_id,
                            l_rsv_rec.reservation_uom_code,
                            l_order_quantity_uom,
                            l_rsv_rec.reservation_quantity);
                    l_reserved_quantity   :=
                        l_reserved_quantity + l_converted_qty;
                ELSE
                    l_reserved_quantity   :=
                        l_reserved_quantity + l_rsv_rec.reservation_quantity;
                END IF;
            END LOOP;
        END IF;

        IF l_reserved_quantity > 0
        THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END get_line_reserved_quantity;

    FUNCTION get_line_reserved_qty_value (p_header_id   NUMBER,
                                          p_line_id     NUMBER)
        RETURN NUMBER
    IS
        l_open_quantity        NUMBER := 0;
        l_reserved_quantity    NUMBER := 0;
        l_mtl_sales_order_id   NUMBER;
        l_return_status        VARCHAR2 (1);
        l_msg_count            NUMBER;
        l_msg_data             VARCHAR2 (240);
        l_rsv_rec              inv_reservation_global.mtl_reservation_rec_type;
        l_rsv_tbl              inv_reservation_global.mtl_reservation_tbl_type;
        l_count                NUMBER;
        l_x_error_code         NUMBER;
        l_lock_records         VARCHAR2 (1);
        l_sort_by_req_date     NUMBER;
        l_converted_qty        NUMBER;
        l_inventory_item_id    NUMBER;
        l_order_quantity_uom   VARCHAR2 (30);
    BEGIN
        IF p_line_id IS NOT NULL
        THEN
            l_mtl_sales_order_id                :=
                OE_HEADER_UTIL.Get_Mtl_Sales_Order_Id (
                    p_header_id => p_header_id);
            l_rsv_rec.demand_source_header_id   := l_mtl_sales_order_id;
            l_rsv_rec.demand_source_line_id     := p_line_id;
            l_rsv_rec.organization_id           := NULL;
            INV_RESERVATION_PUB.QUERY_RESERVATION_OM_HDR_LINE (
                p_api_version_number          => 1.0,
                p_init_msg_lst                => fnd_api.g_true,
                x_return_status               => l_return_status,
                x_msg_count                   => l_msg_count,
                x_msg_data                    => l_msg_data,
                p_query_input                 => l_rsv_rec,
                x_mtl_reservation_tbl         => l_rsv_tbl,
                x_mtl_reservation_tbl_count   => l_count,
                x_error_code                  => l_x_error_code,
                p_lock_records                => l_lock_records,
                p_sort_by_req_date            => l_sort_by_req_date);

            BEGIN
                SELECT order_quantity_uom, inventory_item_id
                  INTO l_order_quantity_uom, l_inventory_item_id
                  FROM oe_order_lines_all
                 WHERE line_id = p_line_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_order_quantity_uom   := NULL;
            END;

            FOR I IN 1 .. l_rsv_tbl.COUNT
            LOOP
                l_rsv_rec   := l_rsv_tbl (I);

                IF NVL (l_order_quantity_uom, l_rsv_rec.reservation_uom_code) <>
                   l_rsv_rec.reservation_uom_code
                THEN
                    l_converted_qty   :=
                        Oe_Order_Misc_Util.convert_uom (
                            l_inventory_item_id,
                            l_rsv_rec.reservation_uom_code,
                            l_order_quantity_uom,
                            l_rsv_rec.reservation_quantity);
                    l_reserved_quantity   :=
                        l_reserved_quantity + l_converted_qty;
                ELSE
                    l_reserved_quantity   :=
                        l_reserved_quantity + l_rsv_rec.reservation_quantity;
                END IF;
            END LOOP;
        END IF;

        IF l_reserved_quantity > 0
        THEN
            RETURN l_reserved_quantity;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END get_line_reserved_qty_value;

    FUNCTION get_blanket_unschedule_line (p_header_id   NUMBER,
                                          p_org_id      NUMBER)
        RETURN VARCHAR2
    IS
        CURSOR lcu_get_schedule_date IS
            SELECT COUNT (*)
              FROM oe_order_lines_all OOL
             WHERE     org_id = p_org_id
                   AND schedule_ship_date IS NOT NULL
                   AND EXISTS
                           (SELECT 1
                              FROM oe_blanket_headers_all OBH
                             WHERE     OBH.header_id = p_header_id
                                   AND OBH.org_id = p_org_id
                                   AND OBH.order_number = OOL.blanket_number);

        lc_schedule_date_cnt   NUMBER;
    BEGIN
        OPEN lcu_get_schedule_date;

        FETCH lcu_get_schedule_date INTO lc_schedule_date_cnt;

        CLOSE lcu_get_schedule_date;

        IF lc_schedule_date_cnt = 0
        THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END get_blanket_unschedule_line;

    FUNCTION get_wsh_shipping_oe_header_id (p_delivery_detail_id NUMBER)
        RETURN NUMBER
    IS
        CURSOR lcu_get_header_id IS
            SELECT DISTINCT WDD2.source_header_id
              FROM wsh_delivery_assignments wda2, wsh_delivery_details wdd2
             WHERE     parent_delivery_detail_id = p_delivery_detail_id
                   AND WDD2.source_code = 'OE'
                   AND wda2.delivery_detail_id = wdd2.delivery_detail_id
                   AND wda2.parent_delivery_detail_id IS NOT NULL;

        ln_header_id   NUMBER;
    BEGIN
        OPEN lcu_get_header_id;

        FETCH lcu_get_header_id INTO ln_header_id;

        CLOSE lcu_get_header_id;

        RETURN ln_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_wsh_shipping_oe_header_id;

    FUNCTION get_wsh_shipping_oe_line_id (p_delivery_detail_id NUMBER)
        RETURN NUMBER
    IS
        CURSOR lcu_get_line_id IS
            SELECT DISTINCT WDD2.source_line_id
              FROM wsh_delivery_assignments wda2, wsh_delivery_details wdd2
             WHERE     parent_delivery_detail_id = p_delivery_detail_id
                   AND WDD2.source_code = 'OE'
                   AND wda2.delivery_detail_id = wdd2.delivery_detail_id
                   AND wda2.parent_delivery_detail_id IS NOT NULL;

        ln_line_id   NUMBER;
    BEGIN
        OPEN lcu_get_line_id;

        FETCH lcu_get_line_id INTO ln_line_id;

        CLOSE lcu_get_line_id;

        RETURN ln_line_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_wsh_shipping_oe_line_id;

    PROCEDURE get_pick_rlease_status (P_header_id NUMBER, p_pick_release OUT XXD_BTOM_PICK_RELEASE_TBLTYPE, x_err_msg OUT VARCHAR2)
    IS
        CURSOR lcu_get_pick_release_status (ln_header_id NUMBER)
        IS
              SELECT order_number, line_number, order_quantity_uom,
                     ordered_quantity, delivery_id, sku,
                     SUM (requested_quantity) requested_quantity, wms_enabled_flag, is_ready_to_release,
                     is_pre_picked, is_released_to_warehouse, is_task_accepted,
                     is_staged, is_dock_door, is_shipped,
                     ready_to_release_on, ready_to_release_datetime, ready_to_release_at,
                     pre_picked_on, pre_picked_datetime, pre_picked_at,
                     released_to_warehouse_on, released_to_warehouse_datetime, released_to_warehouse_at,
                     task_accepted_on, task_accepted_datetime, task_accepted_at,
                     staged_on, staged_datetime, staged_at,
                     loaded_to_door_on, loaded_to_door_at, shipped_on,
                     shipped_datetime, shipped_at
                FROM (SELECT ooha.order_number,
                             oola.line_number || '.' || oola.shipment_number
                                 line_number,
                             oola.order_quantity_uom,
                             oola.ordered_quantity,
                             wnd.delivery_id,
                                msib.segment1
                             || '-'
                             || msib.segment2
                             || '-'
                             || msib.segment3
                                 AS sku,
                             wdd.requested_quantity,
                             org_params.wms_enabled_flag,
                             'Y'
                                 AS is_ready_to_release,
                             CASE
                                 WHEN wdd.released_status IN ('R', 'B')
                                 THEN
                                     DECODE (
                                         (SELECT MIN (reservation_id)
                                            FROM apps.mtl_reservations
                                           WHERE     demand_source_line_id =
                                                     oola.line_id
                                                 AND staged_flag IS NULL),
                                         NULL, 'N',
                                         'Y')
                                 WHEN wdd.released_status IN ('S', 'Y', 'C')
                                 THEN
                                     'Y'
                                 ELSE
                                     'N'
                             END
                                 AS is_pre_picked,
                             CASE
                                 WHEN wdd.released_status IN ('S', 'Y', 'C')
                                 THEN
                                     'Y'
                                 ELSE
                                     'N'
                             END
                                 AS is_released_to_warehouse,
                             CASE
                                 WHEN wdd.released_status IN ('S')
                                 THEN
                                     DECODE (
                                         (SELECT MIN (transfer_lpn_id)
                                            FROM mtl_material_transactions_temp
                                           WHERE move_order_line_id =
                                                 wdd.move_order_line_id),
                                         NULL, 'N',
                                         'Y')
                                 WHEN wdd.released_status IN ('Y', 'C')
                                 THEN
                                     'Y'
                                 ELSE
                                     'N'
                             END
                                 AS is_task_accepted,
                             CASE
                                 WHEN wdd.released_status IN ('Y', 'C')
                                 THEN
                                     'Y'
                                 ELSE
                                     'N'
                             END
                                 AS is_staged,
                             CASE
                                 WHEN wdd.released_status = 'C'
                                 THEN
                                     'Y'
                                 WHEN wdd.released_status = 'Y'
                                 THEN
                                     DECODE (
                                         (SELECT MIN (dock_door_id)
                                            FROM apps.wms_shipping_transaction_temp
                                           WHERE delivery_detail_id =
                                                 wdd.delivery_detail_id),
                                         NULL, 'N',
                                         'Y')
                                 ELSE
                                     'N'
                             END
                                 AS is_dock_door,
                             CASE
                                 WHEN wdd.released_status IN ('C') THEN 'Y'
                                 ELSE 'N'
                             END
                                 AS is_shipped,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         oola.creation_date,
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY'),
                                 'DD-MON-YYYY')
                                 AS ready_to_release_on,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         oola.creation_date,
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY hh12:mi AM'),
                                 'DD-MON-YYYY hh12:mi AM')
                                 AS ready_to_release_datetime,
                             TO_CHAR (
                                 apps.fnd_timezone_pub.adjust_datetime (
                                     oola.creation_date,
                                     apps.fnd_timezones.get_server_timezone_code,
                                     apps.fnd_timezones.get_client_timezone_code),
                                 'hh12:mi AM')
                                 AS ready_to_release_at,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         NVL (
                                             TO_DATE (
                                                 oola.attribute11,
                                                 'MM/DD/RRRR HH:MI:SS AM'), -- Added for 1.4.
                                             (SELECT MAX (last_update_date)
                                                FROM apps.mtl_reservations
                                               WHERE demand_source_line_id =
                                                     oola.line_id)) -- Added for 1.4.
                                                                   ,
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY'),
                                 'DD-MON-YYYY')
                                 AS pre_picked_on,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         NVL (
                                             TO_DATE (
                                                 oola.attribute11,
                                                 'MM/DD/RRRR HH:MI:SS AM'), -- Added for 1.4.
                                             (SELECT MAX (last_update_date)
                                                FROM apps.mtl_reservations
                                               WHERE demand_source_line_id =
                                                     oola.line_id)) -- Added for 1.4.
                                                                   ,
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY hh12:mi AM'),
                                 'DD-MON-YYYY hh12:mi AM')
                                 AS pre_picked_datetime,
                             TO_CHAR (
                                 apps.fnd_timezone_pub.adjust_datetime (
                                     NVL (
                                         TO_DATE (
                                             oola.attribute11,
                                             'MM/DD/RRRR HH:MI:SS AM'), -- Added for 1.4.
                                         (SELECT MAX (last_update_date)
                                            FROM apps.mtl_reservations
                                           WHERE demand_source_line_id =
                                                 oola.line_id)) -- Added for 1.4.
                                                               ,
                                     apps.fnd_timezones.get_server_timezone_code,
                                     apps.fnd_timezones.get_client_timezone_code),
                                 'hh12:mi AM')
                                 AS pre_picked_at,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         wnd.creation_date,
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY'),
                                 'DD-MON-YYYY')
                                 AS released_to_warehouse_on,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         wnd.creation_date,
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY hh12:mi AM'),
                                 'DD-MON-YYYY hh12:mi AM')
                                 AS released_to_warehouse_datetime,
                             TO_CHAR (
                                 apps.fnd_timezone_pub.adjust_datetime (
                                     wnd.creation_date,
                                     apps.fnd_timezones.get_server_timezone_code,
                                     apps.fnd_timezones.get_client_timezone_code),
                                 'hh12:mi AM')
                                 AS released_to_warehouse_at,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         NVL (
                                             (SELECT MAX (NVL (dispatched_time, creation_date))
                                                FROM wms_dispatched_tasks
                                               WHERE move_order_line_id =
                                                     wdd.move_order_line_id),
                                             (SELECT MAX (NVL (dispatched_time, creation_date))
                                                FROM wms_dispatched_tasks_history
                                               WHERE move_order_line_id =
                                                     wdd.move_order_line_id)),
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY'),
                                 'DD-MON-YYYY')
                                 AS task_accepted_on,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         NVL (
                                             (SELECT MAX (NVL (dispatched_time, creation_date))
                                                FROM wms_dispatched_tasks
                                               WHERE move_order_line_id =
                                                     wdd.move_order_line_id),
                                             (SELECT MAX (NVL (dispatched_time, creation_date))
                                                FROM wms_dispatched_tasks_history
                                               WHERE move_order_line_id =
                                                     wdd.move_order_line_id)),
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY hh12:mi AM'),
                                 'DD-MON-YYYY hh12:mi AM')
                                 AS task_accepted_datetime,
                             TO_CHAR (
                                 apps.fnd_timezone_pub.adjust_datetime (
                                     NVL (
                                         (SELECT MAX (NVL (dispatched_time, creation_date))
                                            FROM wms_dispatched_tasks
                                           WHERE move_order_line_id =
                                                 wdd.move_order_line_id),
                                         (SELECT MAX (NVL (dispatched_time, creation_date))
                                            FROM wms_dispatched_tasks_history
                                           WHERE move_order_line_id =
                                                 wdd.move_order_line_id)),
                                     apps.fnd_timezones.get_server_timezone_code,
                                     apps.fnd_timezones.get_client_timezone_code),
                                 'hh12:mi AM')
                                 AS task_accepted_at,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         (SELECT MAX (creation_date)
                                            FROM apps.mtl_material_transactions
                                           WHERE     trx_source_line_id =
                                                     wdd.source_line_id
                                                 AND move_order_line_id =
                                                     wdd.move_order_line_id
                                                 AND transaction_type_id =
                                                     52
                                                 AND transaction_action_id =
                                                     28
                                                 AND transaction_source_type_id =
                                                     2
                                                 AND transaction_quantity >
                                                     0),
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY'),
                                 'DD-MON-YYYY')
                                 AS staged_on,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         (SELECT MAX (creation_date)
                                            FROM apps.mtl_material_transactions
                                           WHERE     trx_source_line_id =
                                                     wdd.source_line_id
                                                 AND move_order_line_id =
                                                     wdd.move_order_line_id
                                                 AND transaction_type_id =
                                                     52
                                                 AND transaction_action_id =
                                                     28
                                                 AND transaction_source_type_id =
                                                     2
                                                 AND transaction_quantity >
                                                     0),
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY hh12:mi AM'),
                                 'DD-MON-YYYY hh12:mi AM')
                                 AS staged_datetime,
                             TO_CHAR (
                                 apps.fnd_timezone_pub.adjust_datetime (
                                     (SELECT MAX (creation_date)
                                        FROM apps.mtl_material_transactions
                                       WHERE     trx_source_line_id =
                                                 wdd.source_line_id
                                             AND move_order_line_id =
                                                 wdd.move_order_line_id
                                             AND transaction_type_id = 52
                                             AND transaction_action_id =
                                                 28
                                             AND transaction_source_type_id =
                                                 2
                                             AND transaction_quantity > 0),
                                     apps.fnd_timezones.get_server_timezone_code,
                                     apps.fnd_timezones.get_client_timezone_code),
                                 'hh12:mi AM')
                                 AS staged_at,
                             NULL
                                 AS loaded_to_door_on,
                             NULL
                                 AS loaded_to_door_at,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         oola.actual_shipment_date,
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY'),
                                 'DD-MON-YYYY')
                                 AS shipped_on,
                             TO_DATE (
                                 TO_CHAR (
                                     apps.fnd_timezone_pub.adjust_datetime (
                                         oola.actual_shipment_date,
                                         apps.fnd_timezones.get_server_timezone_code,
                                         apps.fnd_timezones.get_client_timezone_code),
                                     'DD-Mon-YYYY hh12:mi AM'),
                                 'DD-MON-YYYY hh12:mi AM')
                                 AS shipped_datetime,
                             TO_CHAR (
                                 apps.fnd_timezone_pub.adjust_datetime (
                                     oola.actual_shipment_date,
                                     apps.fnd_timezones.get_server_timezone_code,
                                     apps.fnd_timezones.get_client_timezone_code),
                                 'hh12:mi AM')
                                 AS shipped_at
                        FROM apps.mtl_system_items_b msib, ont.oe_order_lines_all oola, inv.mtl_parameters org_params,
                             apps.wsh_lookups pick_lookup, wsh.wsh_new_deliveries wnd, wsh.wsh_delivery_assignments wda,
                             wsh.wsh_delivery_details wdd, ont.oe_order_headers_all ooha
                       WHERE     wdd.container_flag = 'N'
                             AND wdd.source_header_id = ooha.header_id
                             AND pick_lookup.lookup_type = 'PICK_STATUS'
                             AND pick_lookup.lookup_code = wdd.released_status
                             AND org_params.organization_id =
                                 wdd.organization_id
                             AND oola.line_id = wdd.source_line_id
                             AND oola.ordered_quantity > 0
                             AND msib.organization_id = wdd.organization_id
                             AND msib.inventory_item_id = wdd.inventory_item_id
                             AND wda.delivery_detail_id(+) =
                                 wdd.delivery_detail_id
                             AND wnd.delivery_id(+) = wda.delivery_id
                             AND Ooha.Header_Id = ln_header_id)
            GROUP BY order_number, line_number, order_quantity_uom,
                     ordered_quantity, delivery_id, sku,
                     wms_enabled_flag, is_ready_to_release, is_pre_picked,
                     is_released_to_warehouse, is_task_accepted, is_staged,
                     is_dock_door, is_shipped, ready_to_release_on,
                     ready_to_release_datetime, ready_to_release_at, pre_picked_on,
                     pre_picked_datetime, pre_picked_at, released_to_warehouse_on,
                     released_to_warehouse_datetime, released_to_warehouse_at, task_accepted_on,
                     task_accepted_datetime, task_accepted_at, staged_on,
                     staged_datetime, staged_at, loaded_to_door_on,
                     loaded_to_door_at, shipped_on, shipped_datetime,
                     shipped_at
            ORDER BY line_number, sku;

        ln_order_qty                  NUMBER := 0;
        ln_requested_qty              NUMBER := 0;
        lc_ready_to_release_yes       NUMBER := 0;
        lc_ready_to_release_no        NUMBER := 0;
        lc_pre_picked_yes             NUMBER := 0;
        lc_pre_picked_no              NUMBER := 0;
        lc_rel_to_warehouse_yes       NUMBER := 0;
        lc_rel_to_warehouse_no        NUMBER := 0;
        lc_task_accepted_yes          NUMBER := 0;
        lc_task_accepted_no           NUMBER := 0;
        lc_staged_yes                 NUMBER := 0;
        lc_staged_no                  NUMBER := 0;
        lc_dock_door_yes              NUMBER := 0;
        lc_dock_door_no               NUMBER := 0;
        lc_shipped_yes                NUMBER := 0;
        lc_shipped_no                 NUMBER := 0;
        ld_ready_to_rel_datetime      DATE := NULL;
        ld_ready_to_release_on        DATE := NULL;
        lc_ready_to_release_at        VARCHAR2 (30);
        ld_pre_picked_datetime        DATE := NULL;
        ld_pre_picked_on              DATE := NULL;
        lc_pre_picked_at              VARCHAR2 (30);
        ld_released_to_wrh_datetime   DATE := NULL;
        ld_released_to_warehouse_on   DATE := NULL;
        lc_released_to_warehouse_at   VARCHAR2 (30);
        ld_task_accepted_datetime     DATE := NULL;
        ld_task_accepted_on           DATE := NULL;
        lc_task_accepted_at           VARCHAR2 (30);
        ld_staged_datetime            DATE := NULL;
        ld_staged_on                  DATE := NULL;
        lc_staged_at                  VARCHAR2 (30);
        ld_loaded_to_door_on          DATE := NULL;
        lc_loaded_to_door_at          VARCHAR2 (30);
        ld_shipped_datetime           DATE := NULL;
        ld_shipped_on                 DATE := NULL;
        lc_shipped_at                 VARCHAR2 (30);
    BEGIN
        p_pick_release                                    := XXD_BTOM_PICK_RELEASE_TBLTYPE ();
        p_pick_release.EXTEND (1);
        p_pick_release (1)                                :=
            XXD_BTOM_PICK_RELEASE_TYPE (NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL);

        FOR lr_get_pick_release_status
            IN lcu_get_pick_release_status (P_header_id)
        LOOP
            p_pick_release (1).order_number   :=
                lr_get_pick_release_status.order_number;
            p_pick_release (1).order_quantity_uom   :=
                lr_get_pick_release_status.order_quantity_uom;
            p_pick_release (1).wms_enabled_flag   :=
                lr_get_pick_release_status.wms_enabled_flag;
            ln_order_qty   :=
                ln_order_qty + lr_get_pick_release_status.ordered_quantity;

            IF lr_get_pick_release_status.is_ready_to_release = 'Y'
            THEN
                lc_ready_to_release_yes   :=
                      lc_ready_to_release_yes
                    + lr_get_pick_release_status.requested_quantity;
            ELSIF lr_get_pick_release_status.is_ready_to_release = 'N'
            THEN
                lc_ready_to_release_no   :=
                      lc_ready_to_release_no
                    + lr_get_pick_release_status.requested_quantity;
            END IF;

            IF lr_get_pick_release_status.is_pre_picked = 'Y'
            THEN
                lc_pre_picked_yes   :=
                      lc_pre_picked_yes
                    + lr_get_pick_release_status.requested_quantity;
            ELSIF lr_get_pick_release_status.is_pre_picked = 'N'
            THEN
                lc_pre_picked_no   :=
                      lc_pre_picked_no
                    + lr_get_pick_release_status.requested_quantity;
            END IF;

            IF lr_get_pick_release_status.is_released_to_warehouse = 'Y'
            THEN
                lc_rel_to_warehouse_yes   :=
                      lc_rel_to_warehouse_yes
                    + lr_get_pick_release_status.requested_quantity;
            ELSIF lr_get_pick_release_status.is_released_to_warehouse = 'N'
            THEN
                lc_rel_to_warehouse_no   :=
                      lc_rel_to_warehouse_no
                    + lr_get_pick_release_status.requested_quantity;
            END IF;

            IF lr_get_pick_release_status.is_task_accepted = 'Y'
            THEN
                lc_task_accepted_yes   :=
                      lc_task_accepted_yes
                    + lr_get_pick_release_status.requested_quantity;
            ELSIF lr_get_pick_release_status.is_task_accepted = 'N'
            THEN
                lc_task_accepted_no   :=
                      lc_task_accepted_no
                    + lr_get_pick_release_status.requested_quantity;
            END IF;

            IF lr_get_pick_release_status.is_staged = 'Y'
            THEN
                lc_staged_yes   :=
                      lc_staged_yes
                    + lr_get_pick_release_status.requested_quantity;
            ELSIF lr_get_pick_release_status.is_staged = 'N'
            THEN
                lc_staged_no   :=
                      lc_staged_no
                    + lr_get_pick_release_status.requested_quantity;
            END IF;

            IF lr_get_pick_release_status.is_dock_door = 'Y'
            THEN
                lc_dock_door_yes   :=
                      lc_dock_door_yes
                    + lr_get_pick_release_status.requested_quantity;
            ELSIF lr_get_pick_release_status.is_dock_door = 'N'
            THEN
                lc_dock_door_no   :=
                      lc_dock_door_no
                    + lr_get_pick_release_status.requested_quantity;
            END IF;

            IF lr_get_pick_release_status.is_shipped = 'Y'
            THEN
                lc_shipped_yes   :=
                      lc_shipped_yes
                    + lr_get_pick_release_status.requested_quantity;
            ELSIF lr_get_pick_release_status.is_shipped = 'N'
            THEN
                lc_shipped_no   :=
                      lc_shipped_no
                    + lr_get_pick_release_status.requested_quantity;
            END IF;

            IF lr_get_pick_release_status.ready_to_release_on IS NOT NULL
            THEN
                IF ld_ready_to_rel_datetime IS NULL
                THEN
                    ld_ready_to_release_on   :=
                        lr_get_pick_release_status.ready_to_release_on;
                    lc_ready_to_release_at   :=
                        lr_get_pick_release_status.ready_to_release_at;
                    ld_ready_to_rel_datetime   :=
                        lr_get_pick_release_status.ready_to_release_datetime;
                ELSIF TO_CHAR (ld_ready_to_rel_datetime,
                               'DD-Mon-YYYY hh12:mi AM') <
                      TO_CHAR (
                          lr_get_pick_release_status.ready_to_release_datetime,
                          'DD-Mon-YYYY hh12:mi AM')
                THEN
                    ld_ready_to_release_on   :=
                        lr_get_pick_release_status.ready_to_release_on;
                    lc_ready_to_release_at   :=
                        lr_get_pick_release_status.ready_to_release_at;
                    ld_ready_to_rel_datetime   :=
                        lr_get_pick_release_status.ready_to_release_datetime;
                END IF;
            END IF;

            IF lr_get_pick_release_status.pre_picked_on IS NOT NULL
            THEN
                IF ld_pre_picked_datetime IS NULL
                THEN
                    ld_pre_picked_on   :=
                        lr_get_pick_release_status.pre_picked_on;
                    lc_pre_picked_at   :=
                        lr_get_pick_release_status.pre_picked_at;
                    ld_pre_picked_datetime   :=
                        lr_get_pick_release_status.pre_picked_datetime;
                ELSIF TO_CHAR (ld_pre_picked_datetime,
                               'DD-Mon-YYYY hh12:mi AM') <
                      TO_CHAR (
                          lr_get_pick_release_status.pre_picked_datetime,
                          'DD-Mon-YYYY hh12:mi AM')
                THEN
                    ld_pre_picked_on   :=
                        lr_get_pick_release_status.pre_picked_on;
                    lc_pre_picked_at   :=
                        lr_get_pick_release_status.pre_picked_at;
                    ld_pre_picked_datetime   :=
                        lr_get_pick_release_status.pre_picked_datetime;
                END IF;
            END IF;

            IF lr_get_pick_release_status.released_to_warehouse_on
                   IS NOT NULL
            THEN
                IF ld_released_to_wrh_datetime IS NULL
                THEN
                    ld_released_to_warehouse_on   :=
                        lr_get_pick_release_status.released_to_warehouse_on;
                    lc_released_to_warehouse_at   :=
                        lr_get_pick_release_status.released_to_warehouse_at;
                    ld_released_to_wrh_datetime   :=
                        lr_get_pick_release_status.released_to_warehouse_datetime;
                ELSIF TO_CHAR (ld_released_to_wrh_datetime,
                               'DD-Mon-YYYY hh12:mi AM') <
                      TO_CHAR (
                          lr_get_pick_release_status.released_to_warehouse_datetime,
                          'DD-Mon-YYYY hh12:mi AM')
                THEN
                    ld_released_to_warehouse_on   :=
                        lr_get_pick_release_status.released_to_warehouse_on;
                    lc_released_to_warehouse_at   :=
                        lr_get_pick_release_status.released_to_warehouse_at;
                    ld_released_to_wrh_datetime   :=
                        lr_get_pick_release_status.released_to_warehouse_datetime;
                END IF;
            END IF;

            IF lr_get_pick_release_status.task_accepted_on IS NOT NULL
            THEN
                IF ld_task_accepted_datetime IS NULL
                THEN
                    ld_task_accepted_on   :=
                        lr_get_pick_release_status.task_accepted_on;
                    lc_task_accepted_at   :=
                        lr_get_pick_release_status.task_accepted_at;
                    ld_task_accepted_datetime   :=
                        lr_get_pick_release_status.task_accepted_datetime;
                ELSIF TO_CHAR (ld_task_accepted_datetime,
                               'DD-Mon-YYYY hh12:mi AM') <
                      TO_CHAR (
                          lr_get_pick_release_status.task_accepted_datetime,
                          'DD-Mon-YYYY hh12:mi AM')
                THEN
                    ld_task_accepted_on   :=
                        lr_get_pick_release_status.task_accepted_on;
                    lc_task_accepted_at   :=
                        lr_get_pick_release_status.task_accepted_at;
                    ld_task_accepted_datetime   :=
                        lr_get_pick_release_status.task_accepted_datetime;
                END IF;
            END IF;

            IF lr_get_pick_release_status.staged_on IS NOT NULL
            THEN
                IF ld_staged_datetime IS NULL
                THEN
                    ld_staged_on   := lr_get_pick_release_status.staged_on;
                    lc_staged_at   := lr_get_pick_release_status.staged_at;
                    ld_staged_datetime   :=
                        lr_get_pick_release_status.staged_datetime;
                ELSIF TO_CHAR (ld_staged_datetime, 'DD-Mon-YYYY hh12:mi AM') <
                      TO_CHAR (lr_get_pick_release_status.staged_datetime,
                               'DD-Mon-YYYY hh12:mi AM')
                THEN
                    ld_staged_on   := lr_get_pick_release_status.staged_on;
                    lc_staged_at   := lr_get_pick_release_status.staged_at;
                    ld_staged_datetime   :=
                        lr_get_pick_release_status.staged_datetime;
                END IF;
            END IF;

            IF lr_get_pick_release_status.loaded_to_door_on IS NOT NULL
            THEN
                IF ld_loaded_to_door_on IS NULL
                THEN
                    ld_loaded_to_door_on   :=
                        lr_get_pick_release_status.loaded_to_door_on;
                    lc_loaded_to_door_at   :=
                        lr_get_pick_release_status.loaded_to_door_at;
                ELSIF TRUNC (TO_DATE (ld_loaded_to_door_on)) <
                      TRUNC (
                          TO_DATE (
                              lr_get_pick_release_status.loaded_to_door_on))
                THEN
                    ld_loaded_to_door_on   :=
                        lr_get_pick_release_status.loaded_to_door_on;
                    lc_loaded_to_door_at   :=
                        lr_get_pick_release_status.loaded_to_door_at;
                END IF;
            END IF;

            IF lr_get_pick_release_status.shipped_on IS NOT NULL
            THEN
                IF ld_shipped_datetime IS NULL
                THEN
                    ld_shipped_on   := lr_get_pick_release_status.shipped_on;
                    lc_shipped_at   := lr_get_pick_release_status.shipped_at;
                    ld_shipped_datetime   :=
                        lr_get_pick_release_status.shipped_datetime;
                ELSIF TO_CHAR (ld_shipped_datetime, 'DD-Mon-YYYY hh12:mi AM') <
                      TO_CHAR (lr_get_pick_release_status.shipped_datetime,
                               'DD-Mon-YYYY hh12:mi AM')
                THEN
                    ld_shipped_on   := lr_get_pick_release_status.shipped_on;
                    lc_shipped_at   := lr_get_pick_release_status.shipped_at;
                    ld_shipped_datetime   :=
                        lr_get_pick_release_status.shipped_datetime;
                END IF;
            END IF;
        END LOOP;

        p_pick_release (1).ordered_quantity               := ln_order_qty;
        p_pick_release (1).is_ready_to_release_yes        :=
            lc_ready_to_release_yes;
        p_pick_release (1).is_ready_to_release_no         :=
            lc_ready_to_release_no;
        p_pick_release (1).is_pre_picked_yes              := lc_pre_picked_yes;
        p_pick_release (1).is_pre_picked_no               := lc_pre_picked_no;
        p_pick_release (1).is_released_to_warehouse_yes   :=
            lc_rel_to_warehouse_yes;
        p_pick_release (1).is_released_to_warehouse_no    :=
            lc_rel_to_warehouse_no;
        p_pick_release (1).is_task_accepted_yes           :=
            lc_task_accepted_yes;
        p_pick_release (1).is_task_accepted_no            :=
            lc_task_accepted_no;
        p_pick_release (1).is_staged_yes                  := lc_staged_yes;
        p_pick_release (1).is_staged_no                   := lc_staged_no;
        p_pick_release (1).is_dock_door_yes               := lc_dock_door_yes;
        p_pick_release (1).is_dock_door_no                := lc_dock_door_no;
        p_pick_release (1).is_shipped_yes                 := lc_shipped_yes;
        p_pick_release (1).is_shipped_no                  := lc_shipped_no;
        p_pick_release (1).ready_to_release_on            :=
            ld_ready_to_release_on;
        p_pick_release (1).ready_to_release_at            :=
            lc_ready_to_release_at;
        p_pick_release (1).pre_picked_on                  := ld_pre_picked_on;
        p_pick_release (1).pre_picked_at                  := lc_pre_picked_at;
        p_pick_release (1).released_to_warehouse_on       :=
            ld_released_to_warehouse_on;
        p_pick_release (1).released_to_warehouse_at       :=
            lc_released_to_warehouse_at;
        p_pick_release (1).task_accepted_on               :=
            ld_task_accepted_on;
        p_pick_release (1).task_accepted_at               :=
            lc_task_accepted_at;
        p_pick_release (1).staged_on                      := ld_staged_on;
        p_pick_release (1).staged_at                      := lc_staged_at;
        p_pick_release (1).loaded_to_door_on              :=
            ld_loaded_to_door_on;
        p_pick_release (1).loaded_to_door_at              :=
            lc_loaded_to_door_at;
        p_pick_release (1).shipped_on                     := ld_shipped_on;
        p_pick_release (1).shipped_at                     := lc_shipped_at;

        IF lc_ready_to_release_yes <> 0
        THEN
            p_pick_release (1).Per_ready_to_release   :=
                (TO_CHAR (((lc_ready_to_release_yes / ln_order_qty) * 100), '990.99') || '%');
        ELSE
            p_pick_release (1).Per_ready_to_release   := '0.00';
        END IF;

        IF lc_pre_picked_yes <> 0
        THEN
            p_pick_release (1).Per_is_pre_picked   :=
                (TO_CHAR (((lc_pre_picked_yes / ln_order_qty) * 100), '990.99') || '%');
        ELSE
            p_pick_release (1).Per_is_pre_picked   := '0.00';
        END IF;

        IF lc_rel_to_warehouse_yes <> 0
        THEN
            p_pick_release (1).Per_pick_released   :=
                (TO_CHAR (((lc_rel_to_warehouse_yes / ln_order_qty) * 100), '990.99') || '%');
        ELSE
            p_pick_release (1).Per_pick_released   := '0.00';
        END IF;

        IF lc_task_accepted_yes <> 0
        THEN
            p_pick_release (1).Per_in_process   :=
                (TO_CHAR (((lc_task_accepted_yes / ln_order_qty) * 100), '990.99') || '%');
        ELSE
            p_pick_release (1).Per_in_process   := '0.00';
        END IF;

        IF lc_staged_yes <> 0
        THEN
            p_pick_release (1).Per_staged   :=
                (TO_CHAR (((lc_staged_yes / ln_order_qty) * 100), '990.99') || '%');
        ELSE
            p_pick_release (1).Per_staged   := '0.00';
        END IF;

        IF lc_dock_door_yes <> 0
        THEN
            p_pick_release (1).Per_is_dock_door   :=
                (TO_CHAR (((lc_dock_door_yes / ln_order_qty) * 100), '990.99') || '%');
        ELSE
            p_pick_release (1).Per_is_dock_door   := '0.00';
        END IF;

        IF lc_shipped_yes <> 0
        THEN
            p_pick_release (1).Per_is_shipped   :=
                (TO_CHAR (((lc_shipped_yes / ln_order_qty) * 100), '990.99') || '%');
        ELSE
            p_pick_release (1).Per_is_shipped   := '0.00';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_err_msg   := SUBSTR (SQLERRM, 1, 1500);
    END;
END xxd_sales_order_default_pkg;
/
