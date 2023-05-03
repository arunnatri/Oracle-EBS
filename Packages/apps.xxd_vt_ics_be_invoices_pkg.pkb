--
-- XXD_VT_ICS_BE_INVOICES_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_VT_ICS_BE_INVOICES_PKG"
IS
    /******************************************************************************
       Ver    Date          Author             Description
       -----  -----------   -------            ------------------------------------
       1.0    09-DEC-2020   Srinath Siricilla  CCR0009071 (Retrofit version of
                                               VT Invoices PKG)
    ******************************************************************************/

    -- Customized Virtual Trader IC Invoices Program as per requirement

    gStringBlank               CONSTANT VARCHAR2 (3) := ' ';
    gDefaultFullPostalString   CONSTANT VARCHAR2 (100)
        := 'ADDR1 NL ADDR2 NL ADDR3 NL CITY STATE NL ZIP NL COUNTRY' ;

    -- This PL/SQL table stores all the values of the custom attributes.
    TYPE gCustomAttributesTab IS TABLE OF VARCHAR2 (100)
        INDEX BY BINARY_INTEGER;

    -- This a package global table of custom attributes.
    gCustomAttributes                   gCustomAttributesTab;

    -- This record type contains all fields for an address and is used to by the format address functions and procedures.
    TYPE addr_rec_type
        IS RECORD
    (
        customer_name           VARCHAR2 (200),
        customer_name_base      VARCHAR2 (200),
        alt_customer_name       VARCHAR2 (200),
        account_name            VARCHAR2 (200),
        address1                xxcp_address_details.bill_to_address_line_1%TYPE,
        address2                xxcp_address_details.bill_to_address_line_2%TYPE,
        address3                xxcp_address_details.bill_to_address_line_3%TYPE,
        address4                xxcp_address_details.bill_to_address_line_3%TYPE,
        city                    VARCHAR2 (200),
        postal_code             VARCHAR2 (200),
        state                   VARCHAR2 (200),
        State_Code              xxcp_address_details.bill_to_state_code%TYPE,
        province                VARCHAR2 (200),
        county                  VARCHAR2 (200),
        country                 VARCHAR2 (80),
        country_code            VARCHAR2 (2),
        contact_title           VARCHAR2 (80),
        contact_first_name      VARCHAR2 (100),
        contact_middle_names    VARCHAR2 (100),
        contact_last_name       VARCHAR2 (100),
        contact_job_title       VARCHAR2 (100),
        contact_mail_stop       VARCHAR2 (100)
    );

    --2.3 changes start
    ----------------------------------------------------------------------
    -- Function to get ship to by passing the SO Number
    -----------------------------------------------------------------------
    FUNCTION get_so_ship_to (pv_mmt_trx_id IN VARCHAR2, p_header_id IN NUMBER, pv_type IN VARCHAR2:= NULL -- Added as per CCR0009071
                                                                                                         )
        RETURN VARCHAR2
    IS
        lv_so_ship_to     VARCHAR2 (100);
        lv_source         VARCHAR2 (100);
        lv_so_ship_code   VARCHAR2 (100);           -- Added as per CCR0009071
    BEGIN
        lv_so_ship_to     := NULL;
        lv_source         := NULL;
        lv_so_ship_code   := NULL;

        BEGIN
            SELECT get_source (p_header_id) INTO lv_source FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_source   := NULL;
        END;

        IF NVL (lv_source, 'X') = 'Material Transactions'
        THEN
            BEGIN
                SELECT ftv.iso_territory_code, ftv.territory_code
                  INTO lv_so_ship_to, lv_so_ship_code
                  FROM oe_order_headers_all ooh, oe_order_lines_all ool, mtl_material_transactions mmt,
                       hz_cust_site_uses_all hcs_ship, hz_cust_acct_sites_all hca_ship, hz_party_sites hps_ship,
                       hz_parties hp_ship, hz_locations hl_ship, mtl_parameters mp,
                       fnd_territories_vl ftv
                 WHERE     1 = 1
                       AND ooh.header_id = ool.header_id
                       AND ooh.ship_to_org_id = hcs_ship.site_use_id
                       AND hcs_ship.cust_acct_site_id =
                           hca_ship.cust_acct_site_id
                       AND hca_ship.party_site_id = hps_ship.party_site_id
                       AND hps_ship.party_id = hp_ship.party_id
                       AND hps_ship.location_id = hl_ship.location_id
                       AND mp.organization_id(+) = ooh.ship_from_org_id
                       AND ftv.territory_code = hl_ship.country
                       AND mmt.trx_source_line_id = ool.line_id
                       AND mmt.transaction_id = TO_NUMBER (pv_mmt_trx_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_so_ship_to     := NULL;
                    lv_so_ship_code   := NULL;
            END;
        END IF;

        IF pv_type IS NOT NULL
        THEN
            RETURN lv_so_ship_code;
        ELSE
            RETURN lv_so_ship_to;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_so_ship_to     := NULL;
            lv_so_ship_code   := NULL;

            IF pv_type IS NOT NULL
            THEN
                RETURN lv_so_ship_code;
            ELSE
                RETURN lv_so_ship_to;
            END IF;
    END;

    --2.3 changes end
    --CCR0007979 changes start
    ----------------------------------------------------------------------
    -- Function to get Tax line id by passing the mmt.transaction_id
    -----------------------------------------------------------------------
    FUNCTION get_so_line_id (pv_mmt_trx_id   IN VARCHAR2,
                             p_header_id     IN NUMBER)
        RETURN NUMBER
    IS
        lv_so_line_id   NUMBER;
        lv_source       VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT get_source (p_header_id) INTO lv_source FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_source   := NULL;
        END;

        IF NVL (lv_source, 'X') = 'Material Transactions'
        THEN
            SELECT oola.line_id
              INTO lv_so_line_id
              FROM apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
             WHERE     1 = 1
                   AND oola.header_id = ooha.header_id
                   AND mmt.trx_source_line_id = oola.line_id
                   AND mmt.transaction_id = TO_NUMBER (pv_mmt_trx_id);

            RETURN lv_so_line_id;
        ELSE
            lv_so_line_id   := NULL;
            RETURN lv_so_line_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_so_line_id   := NULL;
            RETURN lv_so_line_id;
    END;

    ----------------------------------------------------------------------
    -- Function to get Tax statement for Inventory Invoices with VT New Logic
    -----------------------------------------------------------------------
    FUNCTION get_tax_stamt_vt_new (pv_template_type IN VARCHAR2, pv_language IN VARCHAR2, pv_seller_comp IN NUMBER, pv_buyer_company IN NUMBER, pv_final_sell_comp IN NUMBER, pv_channel IN VARCHAR2
                                   , pv_ship_to IN VARCHAR2, pv_ship_to_reg IN VARCHAR2, ps_ship_from IN VARCHAR2)
        RETURN VARCHAR2
    IS
        x_tax_stmt   VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Procedure is get_tax_stamt_vt_new');

        fnd_file.put_line (
            fnd_file.LOG,
               ' pv_template_type: '
            || pv_template_type
            || ' pv_language: '
            || pv_language
            || ' pv_seller_comp: '
            || pv_seller_comp
            || ' pv_buyer_company: '
            || pv_buyer_company
            || ' pv_final_sell_comp: '
            || pv_final_sell_comp
            || ' pv_channel: '
            || pv_channel
            || ' pv_ship_to: '
            || pv_ship_to
            || ' pv_ship_to_reg: '
            || pv_ship_to_reg
            || ' ps_ship_from: '
            || ps_ship_from);


        IF pv_ship_to IS NOT NULL AND ps_ship_from IS NOT NULL
        THEN
            BEGIN
                SELECT DISTINCT tax_statement
                  INTO x_tax_stmt
                  FROM (SELECT tax_statement
                          FROM (SELECT attribute1 template_type, attribute2 language, attribute3 seller_company,
                                       attribute4 buyer_company, attribute5 final_selling_company, attribute6 channel,
                                       UPPER (attribute7) ship_to_equal, UPPER (attribute8) ship_to_unequal, UPPER (attribute9) ship_from_equal,
                                       UPPER (attribute10) ship_from_unequal, attribute11 tax_statement
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     1 = 1
                                       AND ffvs.flex_value_set_name =
                                           'XXD_VT_TAX_STMTS_VS'
                                       AND ffvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.start_date_active,
                                                               SYSDATE)
                                                       AND SYSDATE
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.end_date_active,
                                                               SYSDATE)
                                                       AND SYSDATE) xx
                         WHERE     1 = 1
                               AND template_type = pv_template_type
                               AND language = pv_language
                               AND seller_company = pv_seller_comp
                               AND buyer_company = pv_buyer_company
                               AND final_selling_company = pv_final_sell_comp
                               AND UPPER (channel) = UPPER (pv_channel)
                               AND CASE
                                       WHEN NVL (ps_ship_from, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ps_ship_from, '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END =
                                   CASE
                                       WHEN NVL (ps_ship_from, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ps_ship_from, '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END
                               /* OR
                               CASE
                                    WHEN NVL(TRIM(ship_from_unequal), '111') = NVL(TRIM(ship_from_equal), '111') THEN 1
                                END = CASE
                                         WHEN NVL(TRIM(ship_from_unequal), '111') = NVL(TRIM(ship_from_equal), '111') then 1
                                END
                                */
                               AND (CASE
                                        WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))
                                        THEN
                                            NVL (ship_to_equal, '111')
                                        WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')) -- OR (DECODE(pv_ship_to,ship_to_unequal,ship_to_unequal,NVL(pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA' ) AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')
                                                                                                                                                                                                    )
                                        THEN
                                            NVL (ship_to_unequal, '111')
                                    END =
                                    CASE
                                        WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))
                                        THEN
                                            NVL (ship_to_equal, '111')
                                        WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')) --OR (DECODE(pv_ship_to,ship_to_unequal,ship_to_unequal,NVL(pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA' ) AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')
                                                                                                                                                                                                    )
                                        THEN
                                            NVL (ship_to_unequal, '111')
                                    END)
                        UNION ALL
                        SELECT tax_statement
                          FROM (SELECT attribute1 template_type, attribute2 language, attribute3 seller_company,
                                       attribute4 buyer_company, attribute5 final_selling_company, attribute6 channel,
                                       UPPER (attribute7) ship_to_equal, UPPER (attribute8) ship_to_unequal, UPPER (attribute9) ship_from_equal,
                                       UPPER (attribute10) ship_from_unequal, attribute11 tax_statement
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     1 = 1
                                       AND ffvs.flex_value_set_name =
                                           'XXD_VT_TAX_STMTS_VS'
                                       AND ffvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.start_date_active,
                                                               SYSDATE)
                                                       AND SYSDATE
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.end_date_active,
                                                               SYSDATE)
                                                       AND SYSDATE) xx
                         WHERE     1 = 1
                               AND template_type = pv_template_type
                               AND language = pv_language
                               AND seller_company = pv_seller_comp
                               AND buyer_company = pv_buyer_company
                               AND final_selling_company = pv_final_sell_comp
                               AND UPPER (channel) = UPPER (pv_channel)
                               AND CASE
                                       WHEN NVL (ps_ship_from, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ps_ship_from, '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END =
                                   CASE
                                       WHEN NVL (ps_ship_from, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ps_ship_from, '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END
                               AND (pv_ship_to_reg = ship_to_equal AND ship_to_unequal NOT LIKE '%' || pv_ship_to || '%' AND (ship_to_equal <> 'NA' AND ship_to_unequal <> 'NA') OR (pv_ship_to_reg <> ship_to_unequal AND (ship_to_equal = 'NA' OR ship_to_unequal = 'EU'))));

                RETURN x_tax_stmt;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_tax_stmt   := NULL;
                    RETURN x_tax_stmt;
            END;
        ELSE
            x_tax_stmt   := NULL;
            RETURN x_tax_stmt;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_tax_stmt   := NULL;
            RETURN x_tax_stmt;
    END;

    ----------------------------------------------------------------------
    -- Function to get Inco code for Inventory Invoices with VT New Logic
    -----------------------------------------------------------------------
    FUNCTION get_inco_codes_vt_new (pv_template_type IN VARCHAR2, pv_language IN VARCHAR2, pv_seller_comp IN NUMBER, pv_buyer_company IN NUMBER, pv_final_sell_comp IN NUMBER, pv_channel IN VARCHAR2
                                    , pv_ship_to IN VARCHAR2, pv_ship_to_reg IN VARCHAR2, ps_ship_from IN VARCHAR2)
        RETURN VARCHAR2
    IS
        x_inco_code   VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Procedure is get_inco_codes_vt_new');

        fnd_file.put_line (
            fnd_file.LOG,
               ' pv_template_type: '
            || pv_template_type
            || ' pv_language: '
            || pv_language
            || ' pv_seller_comp: '
            || pv_seller_comp
            || ' pv_buyer_company: '
            || pv_buyer_company
            || ' pv_final_sell_comp: '
            || pv_final_sell_comp
            || ' pv_channel: '
            || pv_channel
            || ' pv_ship_to: '
            || pv_ship_to
            || ' pv_ship_to_reg: '
            || pv_ship_to_reg
            || ' ps_ship_from: '
            || ps_ship_from);

        IF pv_ship_to IS NOT NULL AND ps_ship_from IS NOT NULL
        THEN
            BEGIN
                SELECT DISTINCT inco_term
                  INTO x_inco_code
                  FROM (SELECT inco_term
                          FROM (SELECT attribute1 template_type, attribute2 language, attribute3 seller_company,
                                       attribute4 buyer_company, attribute5 final_selling_company, attribute6 channel,
                                       UPPER (attribute7) ship_to_equal, UPPER (attribute8) ship_to_unequal, UPPER (attribute9) ship_from_equal,
                                       UPPER (attribute10) ship_from_unequal, attribute11 inco_term
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     1 = 1
                                       AND ffvs.flex_value_set_name =
                                           'XXD_VT_INCO_TERMS_VS'
                                       AND ffvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.start_date_active,
                                                               SYSDATE)
                                                       AND SYSDATE
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.end_date_active,
                                                               SYSDATE)
                                                       AND SYSDATE) xx
                         WHERE     1 = 1
                               AND template_type = pv_template_type
                               AND language = pv_language
                               AND seller_company = pv_seller_comp
                               AND buyer_company = pv_buyer_company
                               AND final_selling_company = pv_final_sell_comp
                               AND UPPER (channel) = UPPER (pv_channel)
                               AND CASE
                                       WHEN NVL (ps_ship_from, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ps_ship_from, '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END =
                                   CASE
                                       WHEN NVL (ps_ship_from, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ps_ship_from, '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END
                               /* OR
                               CASE
                                    WHEN NVL(TRIM(ship_from_unequal), '111') = NVL(TRIM(ship_from_equal), '111') THEN 1
                                END = CASE
                                         WHEN NVL(TRIM(ship_from_unequal), '111') = NVL(TRIM(ship_from_equal), '111') then 1
                                END
                                */
                               AND (CASE
                                        WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))
                                        THEN
                                            NVL (ship_to_equal, '111')
                                        WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')) -- OR (DECODE(pv_ship_to,ship_to_unequal,ship_to_unequal,NVL(pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA' ) AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')
                                                                                                                                                                                                    )
                                        THEN
                                            NVL (ship_to_unequal, '111')
                                    END =
                                    CASE
                                        WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))
                                        THEN
                                            NVL (ship_to_equal, '111')
                                        WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')) --OR (DECODE(pv_ship_to,ship_to_unequal,ship_to_unequal,NVL(pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA' ) AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')
                                                                                                                                                                                                    )
                                        THEN
                                            NVL (ship_to_unequal, '111')
                                    END)
                        UNION ALL
                        SELECT inco_term
                          FROM (SELECT attribute1 template_type, attribute2 language, attribute3 seller_company,
                                       attribute4 buyer_company, attribute5 final_selling_company, attribute6 channel,
                                       UPPER (attribute7) ship_to_equal, UPPER (attribute8) ship_to_unequal, UPPER (attribute9) ship_from_equal,
                                       UPPER (attribute10) ship_from_unequal, attribute11 inco_term
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     1 = 1
                                       AND ffvs.flex_value_set_name =
                                           'XXD_VT_INCO_TERMS_VS'
                                       AND ffvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.start_date_active,
                                                               SYSDATE)
                                                       AND SYSDATE
                                       AND SYSDATE BETWEEN NVL (
                                                               ffvl.end_date_active,
                                                               SYSDATE)
                                                       AND SYSDATE) xx
                         WHERE     1 = 1
                               AND template_type = pv_template_type
                               AND language = pv_language
                               AND seller_company = pv_seller_comp
                               AND buyer_company = pv_buyer_company
                               AND final_selling_company = pv_final_sell_comp
                               AND UPPER (channel) = UPPER (pv_channel)
                               AND CASE
                                       WHEN NVL (ps_ship_from, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ps_ship_from, '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END =
                                   CASE
                                       WHEN NVL (ps_ship_from, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ps_ship_from, '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END
                               AND (pv_ship_to_reg = ship_to_equal AND ship_to_unequal NOT LIKE '%' || pv_ship_to || '%' AND (ship_to_equal <> 'NA' AND ship_to_unequal <> 'NA') OR (pv_ship_to_reg <> ship_to_unequal AND (ship_to_equal = 'NA' OR ship_to_unequal = 'EU'))));

                RETURN x_inco_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_inco_code   := NULL;
                    RETURN x_inco_code;
            END;
        ELSE
            x_inco_code   := NULL;
            RETURN x_inco_code;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_inco_code   := NULL;
            RETURN x_inco_code;
    END;

    -----------------------------------------------------------------------
    -- Function to get tax codes for Inventory Invoices with VT New Logic
    -----------------------------------------------------------------------
    FUNCTION get_tax_codes_vt_new ( /*pv_org_id        IN VARCHAR2,
                                    pv_ship_to       IN VARCHAR2,
                                    pv_ship_to_reg   IN VARCHAR2,
                                    ps_ship_from     IN VARCHAR2,
                                    pv_channel       IN VARCHAR2,*/
                                   --2.4
                                   pv_template_type IN VARCHAR2, pv_language IN VARCHAR2, pv_seller_comp IN NUMBER, pv_buyer_company IN NUMBER, pv_final_sell_comp IN NUMBER, pv_channel IN VARCHAR2, pv_ship_to IN VARCHAR2, pv_ship_to_reg IN VARCHAR2, ps_ship_from IN VARCHAR2
                                   ,                                     --2.4
                                     pv_line_id IN NUMBER)
        RETURN VARCHAR2
    IS
        x_tax_code             VARCHAR2 (100);
        l_child_cat_count      NUMBER;
        ln_inventory_item_id   NUMBER := NULL;
        ln_country_count       NUMBER;
    BEGIN
        ln_country_count   := 0;
        fnd_file.put_line (fnd_file.LOG, 'Procedure is get_tax_codes_vt_new');

        fnd_file.put_line (
            fnd_file.LOG,
               ' pv_template_type: '
            || pv_template_type
            || ' pv_language: '
            || pv_language
            || ' pv_seller_comp: '
            || pv_seller_comp
            || ' pv_buyer_company: '
            || pv_buyer_company
            || ' pv_final_sell_comp: '
            || pv_final_sell_comp
            || ' pv_channel: '
            || pv_channel
            || ' pv_ship_to: '
            || pv_ship_to
            || ' pv_ship_to_reg: '
            || pv_ship_to_reg
            || ' ps_ship_from: '
            || ps_ship_from
            || ' pv_line_id: '
            || pv_line_id);

        IF ps_ship_from IS NOT NULL
        THEN
            BEGIN
                SELECT COUNT (ffvl.flex_value)
                  INTO ln_country_count
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND ffvs.flex_value_set_name =
                           'XXD_VT_CNTRY_TAX_EXCEPTION_VS'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND UPPER (ffvl.flex_value) = UPPER (ps_ship_from);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_country_count   := 0;
            END;
        ELSE
            ln_country_count   := 0;
        END IF;

        BEGIN
            SELECT oola.inventory_item_id
              INTO ln_inventory_item_id
              FROM oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     ooha.header_id = oola.header_id
                   AND oola.tax_code IS NOT NULL
                   AND oola.line_id = pv_line_id
                   AND EXISTS
                           (SELECT 1
                              FROM zx_exceptions ze
                             WHERE     ze.tax_rate_code = oola.tax_code
                                   AND ze.product_id = oola.inventory_item_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_inventory_item_id   := NULL;
            WHEN OTHERS
            THEN
                ln_inventory_item_id   := NULL;
        END;

        IF ln_inventory_item_id IS NULL
        THEN
            BEGIN
                SELECT COUNT (oola.inventory_item_id)
                  INTO l_child_cat_count
                  FROM oe_order_lines_all oola
                 WHERE     oola.line_id = pv_line_id
                       AND EXISTS
                               (SELECT 1
                                  FROM apps.mtl_categories mc, apps.mtl_item_categories mic
                                 WHERE     mc.category_id = mic.category_id
                                       AND mic.inventory_item_id =
                                           oola.inventory_item_id
                                       AND mic.organization_id =
                                           oola.ship_from_org_id
                                       AND mc.structure_id = 50414
                                       AND mc.segment1 = 1001); --1001 corresponds to Tax Class KIDS
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_child_cat_count   := 0;
            END;
        ELSE
            l_child_cat_count   := 1;           -- Can be treated as KIDS Item
        END IF;

        --fnd_file.put_line(fnd_file.log, 'Child Category Count' || l_child_cat_count);
        IF NVL (l_child_cat_count, 0) > 0 AND NVL (ln_country_count, 0) > 0
        THEN
            x_tax_code   := 'T0';
            RETURN x_tax_code;
        ELSE
            IF pv_ship_to IS NOT NULL AND ps_ship_from IS NOT NULL
            THEN
                BEGIN
                    -- 2.4 changes start
                    SELECT DISTINCT tax_code
                      INTO x_tax_code
                      FROM (SELECT tax_code
                              FROM (SELECT attribute1 template_type, attribute2 language, attribute3 seller_company,
                                           attribute4 buyer_company, attribute5 final_selling_company, attribute6 channel,
                                           UPPER (attribute7) ship_to_equal, UPPER (attribute8) ship_to_unequal, UPPER (attribute9) ship_from_equal,
                                           UPPER (attribute10) ship_from_unequal, attribute11 tax_code
                                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                     WHERE     1 = 1
                                           AND ffvs.flex_value_set_name =
                                               'XXD_VT_NEW_TAX_CODES_VS'
                                           AND ffvs.flex_value_set_id =
                                               ffvl.flex_value_set_id
                                           AND NVL (ffvl.enabled_flag, 'Y') =
                                               'Y'
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffvl.start_date_active,
                                                                   SYSDATE)
                                                           AND SYSDATE
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffvl.end_date_active,
                                                                   SYSDATE)
                                                           AND SYSDATE) xx
                             WHERE     1 = 1
                                   AND template_type = pv_template_type
                                   AND language = pv_language
                                   AND seller_company = pv_seller_comp
                                   AND buyer_company = pv_buyer_company
                                   AND final_selling_company =
                                       pv_final_sell_comp
                                   AND UPPER (channel) = UPPER (pv_channel)
                                   AND CASE
                                           WHEN NVL (ps_ship_from, '111') =
                                                NVL (ship_from_equal, '111')
                                           THEN
                                               NVL (ship_from_equal, '111')
                                           WHEN     NVL (ps_ship_from, '111') <>
                                                    NVL (ship_from_unequal,
                                                         '111')
                                                AND ship_from_unequal <> 'NA'
                                           THEN
                                               NVL (ship_from_unequal, '111')
                                       END =
                                       CASE
                                           WHEN NVL (ps_ship_from, '111') =
                                                NVL (ship_from_equal, '111')
                                           THEN
                                               NVL (ship_from_equal, '111')
                                           WHEN     NVL (ps_ship_from, '111') <>
                                                    NVL (ship_from_unequal,
                                                         '111')
                                                AND ship_from_unequal <> 'NA'
                                           THEN
                                               NVL (ship_from_unequal, '111')
                                       END
                                   /* OR
                                   CASE
                                        WHEN NVL(TRIM(ship_from_unequal), '111') = NVL(TRIM(ship_from_equal), '111') THEN 1
                                    END = CASE
                                             WHEN NVL(TRIM(ship_from_unequal), '111') = NVL(TRIM(ship_from_equal), '111') then 1
                                    END
                                    */
                                   AND (CASE
                                            WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))
                                            THEN
                                                NVL (ship_to_equal, '111')
                                            WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))-- OR (DECODE(pv_ship_to,ship_to_unequal,ship_to_unequal,NVL(pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA' ) AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')
                                                                                                                                                                                                        )
                                            THEN
                                                NVL (ship_to_unequal, '111')
                                        END =
                                        CASE
                                            WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))
                                            THEN
                                                NVL (ship_to_equal, '111')
                                            WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))--OR (DECODE(pv_ship_to,ship_to_unequal,ship_to_unequal,NVL(pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA' ) AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')
                                                                                                                                                                                                        )
                                            THEN
                                                NVL (ship_to_unequal, '111')
                                        END)
                            UNION ALL
                            SELECT tax_code
                              FROM (SELECT attribute1 template_type, attribute2 language, attribute3 seller_company,
                                           attribute4 buyer_company, attribute5 final_selling_company, attribute6 channel,
                                           UPPER (attribute7) ship_to_equal, UPPER (attribute8) ship_to_unequal, UPPER (attribute9) ship_from_equal,
                                           UPPER (attribute10) ship_from_unequal, attribute11 tax_code
                                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                     WHERE     1 = 1
                                           AND ffvs.flex_value_set_name =
                                               'XXD_VT_NEW_TAX_CODES_VS'
                                           AND ffvs.flex_value_set_id =
                                               ffvl.flex_value_set_id
                                           AND NVL (ffvl.enabled_flag, 'Y') =
                                               'Y'
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffvl.start_date_active,
                                                                   SYSDATE)
                                                           AND SYSDATE
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffvl.end_date_active,
                                                                   SYSDATE)
                                                           AND SYSDATE) xx
                             WHERE     1 = 1
                                   AND template_type = pv_template_type
                                   AND language = pv_language
                                   AND seller_company = pv_seller_comp
                                   AND buyer_company = pv_buyer_company
                                   AND final_selling_company =
                                       pv_final_sell_comp
                                   AND UPPER (channel) = UPPER (pv_channel)
                                   AND CASE
                                           WHEN NVL (ps_ship_from, '111') =
                                                NVL (ship_from_equal, '111')
                                           THEN
                                               NVL (ship_from_equal, '111')
                                           WHEN     NVL (ps_ship_from, '111') <>
                                                    NVL (ship_from_unequal,
                                                         '111')
                                                AND ship_from_unequal <> 'NA'
                                           THEN
                                               NVL (ship_from_unequal, '111')
                                       END =
                                       CASE
                                           WHEN NVL (ps_ship_from, '111') =
                                                NVL (ship_from_equal, '111')
                                           THEN
                                               NVL (ship_from_equal, '111')
                                           WHEN     NVL (ps_ship_from, '111') <>
                                                    NVL (ship_from_unequal,
                                                         '111')
                                                AND ship_from_unequal <> 'NA'
                                           THEN
                                               NVL (ship_from_unequal, '111')
                                       END
                                   AND (pv_ship_to_reg = ship_to_equal AND ship_to_unequal NOT LIKE '%' || pv_ship_to || '%' AND (ship_to_equal <> 'NA' AND ship_to_unequal <> 'NA') OR (pv_ship_to_reg <> ship_to_unequal AND (ship_to_equal = 'NA' OR ship_to_unequal = 'EU'))));

                    -- 2.4 changes end

                    RETURN x_tax_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_tax_code   := NULL;
                        RETURN x_tax_code;
                END;
            ELSE
                x_tax_code   := NULL;
                RETURN x_tax_code;
            END IF;
        END IF;

        RETURN x_tax_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_tax_code   := NULL;
            RETURN x_tax_code;
    END;

    ----------------------------------------------------------------
    -- Function to get Legal text for Inventory Invoices.
    ----------------------------------------------------------------
    FUNCTION get_legal_text_mt (p_ComSeg1 IN VARCHAR2, p_ComSeg2 IN VARCHAR2, p_comSeg3 IN VARCHAR2, p_tax1 IN VARCHAR2, p_tax2 IN VARCHAR2, p_type IN VARCHAR2
                                , p_lang IN VARCHAR2, p_inv_header_Id IN NUMBER, p_channel IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_legal_text1   VARCHAR2 (1000);
        lv_legal_text    VARCHAR2 (1000);
        lv_country1      VARCHAR2 (100);
        lv_country2      VARCHAR2 (100);
        lv_ship_from     VARCHAR2 (100);
        lv_ship_to       VARCHAR2 (100);
        lv_type          VARCHAR2 (100);
        lv_lang          VARCHAR2 (100);
        lv_comseg1       VARCHAR2 (100);
        lv_comseg2       VARCHAR2 (100);
        lv_target        VARCHAR2 (100);
        lv_channel       VARCHAR2 (100);
    BEGIN
        IF p_type = 'INV'
        THEN
            BEGIN
                SELECT DECODE (get_source (p_inv_header_id), 'Material Transactions', get_ship_from_country (p_inv_header_id), get_ou_country (p_comseg1, 'COUNTRY'))
                  INTO lv_country1                                 --ship_from
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_country1   := NULL;
            END;

            BEGIN
                SELECT DECODE (get_source (p_inv_header_id), 'Material Transactions', get_ship_to (p_inv_header_id, p_ComSeg2), get_ou_country (p_comseg1, 'COUNTRY'))
                  INTO lv_country2                                   --ship_to
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_country2   := NULL;
            END;

            BEGIN
                SELECT ffvl.attribute1, ffvl.attribute2, ffvl.attribute3,
                       ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                       ffvl.attribute7, ffvl.attribute8, ffvl.attribute9
                  INTO lv_type, lv_lang, lv_comseg1, lv_comseg2,
                              lv_target, lv_ship_from, lv_ship_to,
                              lv_channel, lv_legal_text1
                  FROM apps.fnd_flex_value_sets ffv, apps.fnd_flex_values_vl ffvl
                 WHERE     ffv.flex_value_set_id = ffvl.flex_value_set_id
                       AND ffv.flex_value_set_name = 'XXD_VT_LEGAL_INFO_VS'
                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND ffvl.attribute1 = p_type
                       AND ffvl.attribute2 = p_lang
                       AND ffvl.attribute3 = p_ComSeg1
                       AND ffvl.attribute4 = p_ComSeg2
                       AND ffvl.attribute5 = p_comSeg3
                       AND UPPER (ffvl.attribute6) = UPPER (lv_country1)
                       AND UPPER (ffvl.attribute7) = UPPER (lv_country2)
                       AND UPPER (ffvl.attribute8) = UPPER (p_channel);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ship_from     := NULL;
                    lv_legal_text1   := NULL;
                    lv_comseg1       := NULL;
                    lv_comseg2       := NULL;
                    lv_target        := NULL;
                    lv_type          := NULL;
                    lv_lang          := NULL;
                    lv_ship_to       := NULL;
                    lv_channel       := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'lv_ship_from: ' || lv_ship_from);
            fnd_file.put_line (fnd_file.LOG,
                               'lv_legal_text1: ' || lv_legal_text1);
            fnd_file.put_line (fnd_file.LOG, 'lv_comseg1: ' || lv_comseg1);
            fnd_file.put_line (fnd_file.LOG, 'lv_comseg2: ' || lv_comseg2);
            fnd_file.put_line (fnd_file.LOG, 'lv_type: ' || lv_type);
            fnd_file.put_line (fnd_file.LOG, 'lv_lang: ' || lv_lang);
            fnd_file.put_line (fnd_file.LOG, 'lv_ship_to: ' || lv_ship_to);
            fnd_file.put_line (fnd_file.LOG, 'lv_channel: ' || lv_channel);
            fnd_file.put_line (fnd_file.LOG, 'lv_country1: ' || lv_country1);
            fnd_file.put_line (fnd_file.LOG, 'lv_country2: ' || lv_country2);
            fnd_file.put_line (fnd_file.LOG, 'p_ComSeg1: ' || p_ComSeg1);
            fnd_file.put_line (fnd_file.LOG, 'p_ComSeg2: ' || p_ComSeg2);
            fnd_file.put_line (fnd_file.LOG, 'p_ComSeg3: ' || p_ComSeg3);
            fnd_file.put_line (fnd_file.LOG, 'p_tax1: ' || p_tax1);
            fnd_file.put_line (fnd_file.LOG, 'p_tax2: ' || p_tax2);
            fnd_file.put_line (fnd_file.LOG, 'p_type: ' || p_type);
            fnd_file.put_line (fnd_file.LOG, 'p_lang: ' || p_lang);
            fnd_file.put_line (fnd_file.LOG,
                               'p_inv_header_Id: ' || p_inv_header_Id);
            fnd_file.put_line (fnd_file.LOG, 'p_channel: ' || p_channel);
        ELSIF p_type = 'NONINV'
        THEN
            BEGIN
                SELECT ffvl.attribute1, ffvl.attribute2, ffvl.attribute3,
                       ffvl.attribute4, ffvl.attribute5, ffvl.attribute6
                  INTO lv_type, lv_lang, lv_comseg1, lv_comseg2,
                              lv_ship_from, lv_legal_text1
                  FROM apps.fnd_flex_value_sets ffv, apps.fnd_flex_values_vl ffvl
                 WHERE     ffv.flex_value_set_id = ffvl.flex_value_set_id
                       AND ffv.flex_value_set_name = 'XXD_VT_LEGAL_TEXT'
                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND ffvl.attribute1 = p_type
                       AND ffvl.attribute2 = p_lang
                       AND ffvl.attribute3 = p_ComSeg1
                       AND ffvl.attribute4 = p_ComSeg2
                       AND ffvl.attribute5 IS NULL
                       AND ffvl.attribute6 IS NULL
                       AND UPPER (ffvl.attribute8) = UPPER (lv_channel);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ship_from     := NULL;
                    lv_legal_text1   := NULL;
                    lv_comseg1       := NULL;
                    lv_comseg2       := NULL;
                    lv_type          := NULL;
                    lv_lang          := NULL;
                    lv_ship_to       := NULL;
                    lv_legal_text1   := NULL;
                    lv_channel       := NULL;
            END;
        END IF;

        IF     p_type = 'INV'
           AND p_lang = 'EN'
           AND p_comseg1 IS NOT NULL
           AND p_ComSeg2 IS NOT NULL
           AND p_channel IS NOT NULL
           AND p_ComSeg1 = lv_comseg1
           AND p_ComSeg2 = lv_comseg2
           AND p_comseg3 = lv_target
           AND UPPER (lv_country1) = UPPER (lv_ship_from)
           AND UPPER (lv_country2) = UPPER (lv_ship_to)
           AND UPPER (p_channel) = UPPER (lv_channel)
        THEN
            lv_legal_text   := lv_legal_text1;
        ELSIF     p_type = 'NONINV'
              AND p_lang = 'EN'
              AND p_comseg1 IS NOT NULL
              AND p_ComSeg2 IS NOT NULL
              AND p_channel IS NOT NULL
              AND p_ComSeg1 = lv_comseg1
              AND p_ComSeg2 = lv_comseg2
              AND UPPER (p_channel) = UPPER (lv_channel) --and upper(lv_country1) = upper(lv_ship_from)
        THEN
            lv_legal_text   := lv_legal_text1;
        ELSE
            lv_legal_text   := NULL;
        END IF;

        RETURN lv_legal_text;
    END get_legal_text_mt;

    ----------------------------------------------------------------
    -- Function to get Customer Classification.
    ----------------------------------------------------------------
    /* FUNCTION get_cust_classification (p_attribute   IN VARCHAR2,
                                       p_type        IN VARCHAR2,
                                       p_header_id   IN NUMBER)
        RETURN VARCHAR2
     IS
        ln_classification   VARCHAR2 (100) := NULL;
        ln_org_id           NUMBER := NULL;
        lv_org_comp         VARCHAR2 (100) := NULL;
        lv_source           VARCHAR2 (100);
     BEGIN
        BEGIN
           SELECT get_source (p_header_id) INTO lv_source FROM DUAL;
        EXCEPTION
           WHEN OTHERS
           THEN
              lv_source := NULL;
        END;

        IF NVL (lv_source, 'X') = 'Material Transactions'
        THEN
           IF p_type = 'CLASS'
           THEN
              BEGIN
                 SELECT hca.customer_class_code
                   INTO ln_classification
                   FROM apps.mtl_material_transactions mmt,
                        apps.oe_order_lines_all oola,
                        apps.oe_order_headers_all ooha,
                        apps.hz_cust_accounts hca
                  WHERE     1 = 1
                        AND oola.header_id = ooha.header_id
                        AND mmt.trx_source_line_id = oola.line_id
                        AND ooha.sold_to_org_id = hca.cust_account_id
                        AND mmt.transaction_id = p_attribute;

                 RETURN ln_classification;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    ln_classification := NULL;
                    RETURN ln_classification;
              END;
           ELSIF p_type = 'ORG'
           THEN
              BEGIN
                 BEGIN
                    SELECT ooha.org_id
                      INTO ln_org_id
                      FROM apps.mtl_material_transactions mmt,
                           apps.oe_order_lines_all oola,
                           apps.oe_order_headers_all ooha
                     WHERE     1 = 1
                           AND oola.header_id = ooha.header_id
                           AND mmt.trx_source_line_id = oola.line_id
                           AND mmt.transaction_id = p_attribute;
                 EXCEPTION
                    WHEN OTHERS
                    THEN
                       ln_org_id := 0;
                 END;

                 IF ln_org_id IS NOT NULL
                 THEN
                    BEGIN
                       SELECT glev.flex_segment_value
                         INTO lv_org_comp
                         FROM apps.xle_entity_profiles lep,
                              apps.xle_registrations reg,
                              apps.hr_locations_all hrl,
                              apps.hz_parties hzp,
                              apps.fnd_territories_vl ter,
                              apps.hr_operating_units hro,
                              apps.hr_all_organization_units_tl hroutl_ou,
                              apps.gl_legal_entities_bsvs glev
                        WHERE     1 = 1
                              AND lep.transacting_entity_flag(+) = 'Y'
                              AND lep.party_id = hzp.party_id
                              AND lep.legal_entity_id = reg.source_id
                              AND reg.source_table IN
                                     ('XLE_ENTITY_PROFILES', 'XLE_ETB_PROFILES')
                              AND hrl.location_id = reg.location_id
                              AND reg.identifying_flag = 'Y'
                              AND ter.territory_code = hrl.country
                              AND lep.legal_entity_id =
                                     hro.default_legal_context_id
                              AND hroutl_ou.organization_id =
                                     hro.organization_id
                              AND glev.legal_entity_id = lep.legal_entity_id
                              AND hroutl_ou.language = 'US'
                              AND hroutl_ou.organization_id = ln_org_id;

                       RETURN lv_org_comp;
                    EXCEPTION
                       WHEN OTHERS
                       THEN
                          lv_org_comp := NULL;
                          RETURN NULL;
                    END;
                 ELSE
                    RETURN NULL;
                 END IF;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    ln_org_id := NULL;
                    RETURN NULL;
              END;
           ELSE
              RETURN NULL;
           END IF;
        ELSE              --IF NVL(lv_source,'X') = 'Material Transactions' THEN
           RETURN NULL;
        END IF;
     END;*/
    FUNCTION get_cust_classification (p_attribute IN VARCHAR2, p_type IN VARCHAR2, p_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        ln_classification   VARCHAR2 (100) := NULL;
        ln_org_id           NUMBER := NULL;
        lv_org_comp         VARCHAR2 (100) := NULL;
        lv_source           VARCHAR2 (100);
        lv_retail_comp      VARCHAR2 (100) := NULL;
    BEGIN
        -- Query to get the source from the function
        BEGIN
            SELECT get_source (p_header_id) INTO lv_source FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_source   := NULL;
        END;

        --If source is material transactions then write all the derivations
        IF NVL (lv_source, 'X') = 'Material Transactions'
        THEN
            --Query to fatch customer classification by pasing the material transaction id
            BEGIN
                SELECT hca.customer_class_code
                  INTO ln_classification
                  FROM apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha,
                       apps.hz_cust_accounts hca
                 WHERE     1 = 1
                       AND oola.header_id = ooha.header_id
                       AND mmt.trx_source_line_id = oola.line_id
                       AND ooha.sold_to_org_id = hca.cust_account_id
                       AND mmt.transaction_id = p_attribute;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_classification   := NULL;
            END;

            IF p_type = 'CLASS'
            THEN
                RETURN ln_classification;
            ELSIF p_type = 'ORG'
            THEN
                IF UPPER (ln_classification) = 'RETAIL'
                THEN
                    --query to fetch final selling company if customer is retail.
                    BEGIN
                        SELECT l.partner_short
                          INTO lv_retail_comp
                          FROM apps.xxcp_transaction_attrib_hdr_v l
                         WHERE     1 = 1
                               AND transaction_id = p_attribute
                               AND trading_set = 'IC2';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_retail_comp   := NULL;
                    END;

                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Customer is Retail Customer - Final Selling Org is:'
                        || lv_retail_comp);
                    RETURN lv_retail_comp;
                ELSE                        -- If classification is Not retail
                    -- query to fetch the org id input is material transction id
                    BEGIN
                        BEGIN
                            SELECT ooha.org_id
                              INTO ln_org_id
                              FROM apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                             WHERE     1 = 1
                                   AND oola.header_id = ooha.header_id
                                   AND mmt.trx_source_line_id = oola.line_id
                                   AND mmt.transaction_id = p_attribute;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_org_id   := NULL;
                        END;

                        IF ln_org_id IS NOT NULL
                        THEN
                            BEGIN
                                SELECT glev.flex_segment_value
                                  INTO lv_org_comp
                                  FROM apps.xle_entity_profiles lep, apps.xle_registrations reg, apps.hr_locations_all hrl,
                                       apps.hz_parties hzp, apps.fnd_territories_vl ter, apps.hr_operating_units hro,
                                       apps.hr_all_organization_units_tl hroutl_ou, apps.gl_legal_entities_bsvs glev
                                 WHERE     1 = 1
                                       AND lep.transacting_entity_flag(+) =
                                           'Y'
                                       AND lep.party_id = hzp.party_id
                                       AND lep.legal_entity_id =
                                           reg.source_id
                                       AND reg.source_table IN
                                               ('XLE_ENTITY_PROFILES', 'XLE_ETB_PROFILES')
                                       AND hrl.location_id = reg.location_id
                                       AND reg.identifying_flag = 'Y'
                                       AND ter.territory_code = hrl.country
                                       AND lep.legal_entity_id =
                                           hro.default_legal_context_id
                                       AND hroutl_ou.organization_id =
                                           hro.organization_id
                                       AND glev.legal_entity_id =
                                           lep.legal_entity_id
                                       AND hroutl_ou.language = 'US'
                                       AND hroutl_ou.organization_id =
                                           ln_org_id;

                                FND_FILE.PUT_LINE (
                                    FND_FILE.LOG,
                                       'Customer is Non Retail Customer - Final Selling Org is:'
                                    || lv_org_comp);
                                RETURN lv_org_comp;
                            --FND_FILE.PUT_LINE(FND_FILE.LOG,'Customer is Non Retail Customer - Final Selling Org is:'||lv_org_comp);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_org_comp   := NULL;
                                    FND_FILE.PUT_LINE (
                                        FND_FILE.LOG,
                                           'Customer is Non Retail Customer - Final Selling Org is:'
                                        || lv_org_comp);
                                    RETURN NULL;
                            END;
                        ELSE                           --ln_org_id IS NOT NULL
                            RETURN NULL;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_org_id   := NULL;
                            RETURN NULL;
                    END;
                END IF;                     -- IF ln_classification = 'Retail'
            ELSE                                              --p_type = 'ORG'
                RETURN NULL;
            END IF;
        ELSE            --IF NVL(lv_source,'X') = 'Material Transactions' THEN
            RETURN NULL;
        END IF;
    END;

    --2.5 changes end

    ----------------------------------------------------------------
    -- Function to get sold_to OU ID.
    ----------------------------------------------------------------
    FUNCTION get_sold_to (p_ou IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_sold_to   NUMBER;
    BEGIN
        SELECT organization_id
          INTO ln_sold_to
          FROM hr_operating_units
         WHERE name = p_ou;

        RETURN ln_sold_to;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            ln_sold_to   := 0;

            SELECT hro.organization_id
              INTO ln_sold_to
              FROM apps.xle_entity_profiles lep, apps.xle_registrations reg, apps.hr_locations_all hrl,
                   apps.hz_parties hzp, apps.fnd_territories_vl ter, apps.hr_operating_units hro,
                   apps.hr_all_organization_units_tl hroutl_ou, apps.gl_legal_entities_bsvs glev
             WHERE     1 = 1
                   AND lep.transacting_entity_flag(+) = 'Y'
                   AND lep.party_id = hzp.party_id
                   AND lep.legal_entity_id = reg.source_id
                   AND reg.source_table IN
                           ('XLE_ENTITY_PROFILES', 'XLE_ETB_PROFILES')
                   AND hrl.location_id = reg.location_id
                   AND reg.identifying_flag = 'Y'
                   AND ter.territory_code = hrl.country
                   AND lep.legal_entity_id = hro.default_legal_context_id
                   AND hroutl_ou.organization_id = hro.organization_id
                   AND glev.legal_entity_id = lep.legal_entity_id
                   AND hroutl_ou.language = 'US'
                   AND hzp.party_name = p_ou
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                             WHERE     1 = 1
                                   AND ffvs.flex_value_set_name =
                                       'XXD_VT_TAX_CODES_VS'
                                   AND ffvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND ffvl.attribute1 = hro.organization_id
                                   AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           ffvl.start_date_active,
                                                           SYSDATE)
                                                   AND SYSDATE
                                   AND SYSDATE BETWEEN NVL (
                                                           ffvl.end_date_active,
                                                           SYSDATE)
                                                   AND SYSDATE);

            RETURN ln_sold_to;
        WHEN OTHERS
        THEN
            ln_sold_to   := 0;
            RETURN ln_sold_to;
    END;

    ----------------------------------------------------------------
    -- Function to get ship_from country.
    ----------------------------------------------------------------
    FUNCTION get_ship_from (p_header_id IN NUMBER, p_attribute IN VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_ship_from   VARCHAR2 (100);
    BEGIN
        SELECT DECODE (get_source (p_header_id), 'Material Transactions', get_ship_from_country (p_header_id), get_ou_country (p_attribute, 'COUNTRY'))
          INTO ln_ship_from
          FROM DUAL;

        RETURN ln_ship_from;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_ship_from   := NULL;
            RETURN ln_ship_from;
    END;

    ----------------------------------------------------------------
    -- Function to get ship_to country.
    ----------------------------------------------------------------
    FUNCTION get_ship_to (p_header_id IN NUMBER, p_attribute IN VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_ship_to   VARCHAR2 (100);
    BEGIN
        SELECT CASE
                   WHEN     get_source (p_header_id) =
                            'Material Transactions'
                        AND XXD_VT_ICS_INVOICES_PKG.get_mmt_type (
                                p_header_id) =
                            'Internal Shipments'
                   THEN
                       XXD_VT_ICS_INVOICES_PKG.get_ship_to_country (
                           p_header_id)
                   ELSE
                       get_ou_country (p_attribute, 'COUNTRY')
               END
          INTO ln_ship_to
          FROM DUAL;

        RETURN ln_ship_to;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_ship_to   := NULL;
            RETURN ln_ship_to;
    END;

    ----------------------------------------------------------------
    -- Function to get EU and NON-EU Region.
    ----------------------------------------------------------------
    FUNCTION get_eu_non_eu (p_country_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_eu_non_eu   VARCHAR2 (10) := NULL;
        ln_count       NUMBER := 0;
        x_eu_non_eu    VARCHAR2 (10) := NULL;
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv, fnd_territories_vl ftv
         WHERE     ffvs.flex_value_set_name = 'XXDO_CFS_EU_COUNTRIES_VS'
               AND ffv.flex_value_set_id = ffvs.flex_value_set_id
               AND (ffv.flex_value) = ftv.territory_short_name
               AND NVL (ffv.enabled_flag, 'Y') = 'Y'
               AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                               AND SYSDATE
               AND SYSDATE BETWEEN NVL (ffv.end_date_active, SYSDATE)
                               AND SYSDATE
               AND ftv.iso_territory_code = p_country_code;

        IF ln_count > 0
        THEN
            x_eu_non_eu   := 'EU';
        ELSE
            x_eu_non_eu   := 'Non-EU';
        END IF;

        RETURN x_eu_non_eu;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_eu_non_eu   := 'Non-EU';                                 --NULL;
            RETURN x_eu_non_eu;
    END get_eu_non_eu;

    ----------------------------------------------------------------
    -- Function to get the Ship from and ship to country code.
    ----------------------------------------------------------------

    FUNCTION get_ship_from_country_code (p_country_code IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_ship_from_country   VARCHAR2 (100) := NULL;
    BEGIN
        SELECT territory_short_name
          INTO lv_ship_from_country
          FROM fnd_territories_vl
         WHERE iso_territory_code = p_country_code;

        RETURN lv_ship_from_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    ----------------------------------------------------------------
    -- Function to get the Tax code.
    ----------------------------------------------------------------
    FUNCTION get_tax_codes (pv_org_id        IN VARCHAR2,
                            pv_tax_rate      IN VARCHAR2,
                            pv_ship_to       IN VARCHAR2,
                            pv_ship_to_reg   IN VARCHAR2,
                            pv_ship_from     IN VARCHAR2)
        RETURN VARCHAR2
    IS
        x_tax_code   VARCHAR2 (100);
    BEGIN
        IF     pv_tax_rate IS NOT NULL
           AND pv_ship_to IS NOT NULL
           AND pv_ship_from IS NOT NULL
        THEN
            BEGIN
                SELECT tax_code
                  INTO x_tax_code
                  FROM (SELECT ffvs.flex_value_set_name, ffvl.attribute1 ou_id, ffvl.attribute2 tax_rate_equal,
                               ffvl.attribute3 tax_rate_unequal, ffvl.attribute4 ship_to_equal, ffvl.attribute5 ship_to_unequal,
                               ffvl.attribute6 ship_from_equal, ffvl.attribute7 ship_from_unequal, ffvl.attribute8 tax_code
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                         WHERE     1 = 1
                               AND ffvs.flex_value_set_name =
                                   'XXD_B2B_TAX_CODES_VS'
                               AND ffvs.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                               AND SYSDATE BETWEEN NVL (
                                                       ffvl.start_date_active,
                                                       SYSDATE)
                                               AND SYSDATE
                               AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                        SYSDATE)
                                               AND SYSDATE) xx
                 WHERE     1 = 1
                       AND ou_id = pv_org_id
                       AND CASE
                               WHEN     NVL (pv_tax_rate, 'NA') <> 0
                                    AND tax_rate_unequal <> 'NA'
                               THEN
                                   tax_rate_unequal
                               WHEN     NVL (pv_tax_rate, 'NA') = '0'
                                    AND tax_rate_equal <> 'NA'
                               THEN
                                   tax_rate_equal
                           END =
                           CASE
                               WHEN     NVL (pv_tax_rate, 'NA') <> 0
                                    AND tax_rate_unequal <> 'NA'
                               THEN
                                   tax_rate_unequal
                               WHEN     NVL (pv_tax_rate, 'NA') = '0'
                                    AND tax_rate_equal <> 'NA'
                               THEN
                                   tax_rate_equal
                           END
                       AND (CASE
                                WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU'))
                                THEN
                                    NVL (ship_to_equal, '111')
                                WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU')) OR (DECODE (pv_ship_to, ship_to_unequal, ship_to_unequal, NVL (pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA'))
                                THEN
                                    NVL (ship_to_unequal, '111')
                            END =
                            CASE
                                WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU'))
                                THEN
                                    NVL (ship_to_equal, '111')
                                WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU')) OR (DECODE (pv_ship_to, ship_to_unequal, ship_to_unequal, NVL (pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA'))
                                THEN
                                    NVL (ship_to_unequal, '111')
                            END)
                       AND (   CASE
                                   WHEN NVL (pv_ship_from, '111') =
                                        NVL (ship_from_equal, '111')
                                   THEN
                                       NVL (ship_from_equal, '111')
                                   WHEN     NVL (pv_ship_from, '111') <>
                                            NVL (ship_from_unequal, '111')
                                        AND ship_from_unequal <> 'NA'
                                   THEN
                                       NVL (ship_from_unequal, '111')
                               END =
                               CASE
                                   WHEN NVL (pv_ship_from, '111') =
                                        NVL (ship_from_equal, '111')
                                   THEN
                                       NVL (ship_from_equal, '111')
                                   WHEN     NVL (pv_ship_from, '111') <>
                                            NVL (ship_from_unequal, '111')
                                        AND ship_from_unequal <> 'NA'
                                   THEN
                                       NVL (ship_from_unequal, '111')
                               END
                            OR CASE
                                   WHEN NVL (TRIM (ship_from_unequal), '111') =
                                        NVL (TRIM (ship_from_equal), '111')
                                   THEN
                                       1
                               END =
                               CASE
                                   WHEN NVL (TRIM (ship_from_unequal), '111') =
                                        NVL (TRIM (ship_from_equal), '111')
                                   THEN
                                       1
                               END);

                RETURN x_tax_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_tax_code   := NULL;
                    RETURN x_tax_code;
            END;
        ELSIF     pv_tax_rate IS NOT NULL
              AND pv_ship_to IS NOT NULL
              AND pv_ship_from IS NULL
        THEN
            BEGIN
                SELECT tax_code
                  INTO x_tax_code
                  FROM (SELECT ffvs.flex_value_set_name, ffvl.attribute1 ou_id, ffvl.attribute2 tax_rate_equal,
                               ffvl.attribute3 tax_rate_unequal, ffvl.attribute4 ship_to_equal, ffvl.attribute5 ship_to_unequal,
                               ffvl.attribute6 ship_from_equal, ffvl.attribute7 ship_from_unequal, ffvl.attribute8 tax_code
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                         WHERE     1 = 1
                               AND ffvs.flex_value_set_name =
                                   'XXD_B2B_TAX_CODES_VS'
                               AND ffvs.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                               AND SYSDATE BETWEEN NVL (
                                                       ffvl.start_date_active,
                                                       SYSDATE)
                                               AND SYSDATE
                               AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                        SYSDATE)
                                               AND SYSDATE) xx
                 WHERE     1 = 1
                       AND ou_id = pv_org_id
                       AND CASE
                               WHEN     NVL (pv_tax_rate, 'NA') <> 0
                                    AND tax_rate_unequal <> 'NA'
                               THEN
                                   tax_rate_unequal
                               WHEN     NVL (pv_tax_rate, 'NA') = '0'
                                    AND tax_rate_equal <> 'NA'
                               THEN
                                   tax_rate_equal
                           END =
                           CASE
                               WHEN     NVL (pv_tax_rate, 'NA') <> 0
                                    AND tax_rate_unequal <> 'NA'
                               THEN
                                   tax_rate_unequal
                               WHEN     NVL (pv_tax_rate, 'NA') = '0'
                                    AND tax_rate_equal <> 'NA'
                               THEN
                                   tax_rate_equal
                           END
                       AND (CASE
                                WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU'))
                                THEN
                                    NVL (ship_to_equal, '111')
                                WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU')) OR (DECODE (pv_ship_to, ship_to_unequal, ship_to_unequal, NVL (pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA'))
                                THEN
                                    NVL (ship_to_unequal, '111')
                            END =
                            CASE
                                WHEN (NVL (pv_ship_to, '111') = NVL (ship_to_equal, '111') OR (NVL (pv_ship_to_reg, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU'))
                                THEN
                                    NVL (ship_to_equal, '111')
                                WHEN ((NVL (pv_ship_to, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU')) OR (DECODE (pv_ship_to, ship_to_unequal, ship_to_unequal, NVL (pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA'))
                                THEN
                                    NVL (ship_to_unequal, '111')
                            END);

                RETURN x_tax_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_tax_code   := NULL;
                    RETURN x_tax_code;
            END;
        ELSIF     pv_tax_rate IS NOT NULL
              AND pv_ship_from IS NOT NULL
              AND pv_ship_to IS NULL
        THEN
            BEGIN
                SELECT tax_code
                  INTO x_tax_code
                  FROM (SELECT ffvs.flex_value_set_name, ffvl.attribute1 ou_id, ffvl.attribute2 tax_rate_equal,
                               ffvl.attribute3 tax_rate_unequal, ffvl.attribute4 ship_to_equal, ffvl.attribute5 ship_to_unequal,
                               ffvl.attribute6 ship_from_equal, ffvl.attribute7 ship_from_unequal, ffvl.attribute8 tax_code
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                         WHERE     1 = 1
                               AND ffvs.flex_value_set_name =
                                   'XXD_B2B_TAX_CODES_VS'
                               AND ffvs.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                               AND SYSDATE BETWEEN NVL (
                                                       ffvl.start_date_active,
                                                       SYSDATE)
                                               AND SYSDATE
                               AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                        SYSDATE)
                                               AND SYSDATE) xx
                 WHERE     1 = 1
                       AND ou_id = pv_org_id
                       AND CASE
                               WHEN     NVL (pv_tax_rate, 'NA') <> 0
                                    AND tax_rate_unequal <> 'NA'
                               THEN
                                   tax_rate_unequal
                               WHEN     NVL (pv_tax_rate, 'NA') = '0'
                                    AND tax_rate_equal <> 'NA'
                               THEN
                                   tax_rate_equal
                           END =
                           CASE
                               WHEN     NVL (pv_tax_rate, 'NA') <> 0
                                    AND tax_rate_unequal <> 'NA'
                               THEN
                                   tax_rate_unequal
                               WHEN     NVL (pv_tax_rate, 'NA') = '0'
                                    AND tax_rate_equal <> 'NA'
                               THEN
                                   tax_rate_equal
                           END
                       AND (   CASE
                                   WHEN NVL (pv_ship_from, '111') =
                                        NVL (ship_from_equal, '111')
                                   THEN
                                       NVL (ship_from_equal, '111')
                                   WHEN     NVL (pv_ship_from, '111') <>
                                            NVL (ship_from_unequal, '111')
                                        AND ship_from_unequal <> 'NA'
                                   THEN
                                       NVL (ship_from_unequal, '111')
                               END =
                               CASE
                                   WHEN NVL (pv_ship_from, '111') =
                                        NVL (ship_from_equal, '111')
                                   THEN
                                       NVL (ship_from_equal, '111')
                                   WHEN     NVL (pv_ship_from, '111') <>
                                            NVL (ship_from_unequal, '111')
                                        AND ship_from_unequal <> 'NA'
                                   THEN
                                       NVL (ship_from_unequal, '111')
                               END
                            OR CASE
                                   WHEN NVL (TRIM (ship_from_unequal), '111') =
                                        NVL (TRIM (ship_from_equal), '111')
                                   THEN
                                       1
                               END =
                               CASE
                                   WHEN NVL (TRIM (ship_from_unequal), '111') =
                                        NVL (TRIM (ship_from_equal), '111')
                                   THEN
                                       1
                               END);

                RETURN x_tax_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_tax_code   := NULL;
                    RETURN x_tax_code;
            END;
        ELSE
            x_tax_code   := NULL;
            RETURN x_tax_code;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_tax_code   := NULL;
            RETURN x_tax_code;
    END get_tax_codes;

    --CCR0007979 changes end
    ----------------------------------------------------------------
    -- Converts clob to char.
    ----------------------------------------------------------------
    PROCEDURE printClobOut (cClob         IN CLOB,
                            cHeader_Req   IN VARCHAR2 DEFAULT 'N')
    IS
        vPos         PLS_INTEGER := 1;
        vConst_Amt   NUMBER := 8000;
        vAmt         NUMBER;
        vBuffer      VARCHAR2 (32767);

        vNum         NUMBER := 0;
        vSlash       NUMBER := 0;
        vLessThan    NUMBER := 0;
        tempbuf      VARCHAR2 (32767);
    BEGIN
        IF cClob IS NOT NULL
        THEN
            IF cHeader_Req = 'Y'
            THEN
                fnd_file.put_line (fnd_file.output, '<?xml version="1.0"?>');
            END IF;

            LOOP
                vNum      := vNum + 1;

                -- work out where the last > is in this chunk of XML, so we don't trunc a XML tag.
                vAmt      :=
                    INSTR (DBMS_LOB.SUBSTR (cClob, vConst_Amt, vPos),
                           '>',
                           -1);
                tempbuf   := DBMS_LOB.SUBSTR (cClob, vConst_Amt, vPos);

                -- Start or End Node?
                IF vAmt > 0
                THEN
                    vSlash      := INSTR (SUBSTR (tempbuf, 1, vAmt), '</', -1);
                    vLessThan   := INSTR (SUBSTR (tempbuf, 1, vAmt), '<', -1);

                    IF vSlash < vLessThan
                    THEN
                        --Get previous > tag (so startnode-value-endnode is not split)
                        vAmt   :=
                            INSTR (SUBSTR (tempbuf, 1, vLessThan), '>', -1);
                    END IF;
                END IF;

                -- NCM 14/04/2010 if there is no > character in the next chunck then get
                -- the whole of the next chunk.
                IF vAmt = 0
                THEN
                    vAmt   :=
                        DBMS_LOB.getlength (
                            DBMS_LOB.SUBSTR (cClob, vConst_Amt, vPos));
                END IF;

                --vBuffer := utl_raw.cast_to_raw( dbms_lob.substr( cClob, vAmt, vPos ) );
                vBuffer   := DBMS_LOB.SUBSTR (cClob, vAmt, vPos);

                EXIT WHEN vBuffer IS NULL;

                fnd_file.put_line (fnd_file.output, vBuffer);

                vPos      := vPos + vAmt;
            END LOOP;
        ELSE
            -- Output Dummy XML so Layout is applied
            IF cHeader_Req = 'Y'
            THEN
                fnd_file.put_line (fnd_file.output, '<?xml version="1.0"?>');
            END IF;

            fnd_file.put_line (fnd_file.output, '<ROWSET>');
            fnd_file.put_line (fnd_file.output, '</ROWSET>');
        END IF;
    END printClobOut;



    ----------------------------------------------------------------
    -- Generic Procedure.
    ----------------------------------------------------------------
    PROCEDURE GENERIC (cTable_Name     IN VARCHAR2,
                       cWhere_Clause   IN VARCHAR2 DEFAULT NULL)
    IS
        TYPE tab_varchar IS TABLE OF VARCHAR2 (30)
            INDEX BY BINARY_INTEGER;

        t_column_name   tab_varchar;
        t_result        tab_varchar;
        vSQL            VARCHAR2 (32000);
        vCursor         PLS_INTEGER;
        vRows           PLS_INTEGER;

        vColTemp        VARCHAR2 (1000);

        CURSOR c1 (pTable_Name IN VARCHAR2)
        IS
              SELECT column_name
                FROM xxcp_instance_all_tabcols_v
               WHERE     ((owner = 'XXCP' AND table_name LIKE 'CP%') OR (owner = 'APPS' AND table_name LIKE 'XXCP%'))
                     AND table_name = pTable_Name
                     AND data_type IN ('NUMBER', 'VARCHAR2', 'DATE')
                     AND instance_id = 0
            ORDER BY column_id;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'GENERIC XML GENERATION. START...');

        fnd_file.put_line (fnd_file.output, '<?xml version="1.0"?>');
        fnd_file.put_line (fnd_file.output, '<dt>');

        -- Build Dynamic Query
        FOR c1_rec IN c1 (cTable_Name)
        LOOP
            t_column_name (t_column_name.COUNT + 1)   := c1_rec.column_name;

            IF vSQL IS NULL
            THEN
                vSQL   := 'select ' || c1_rec.column_name;
            ELSE
                vSQL   := vSQL || ',' || c1_rec.column_name;
            END IF;
        END LOOP;

        -- Finalize Query
        IF vSQL IS NOT NULL
        THEN
            vSQL   := vSQL || ' from ' || cTable_Name;

            IF cWhere_Clause IS NOT NULL
            THEN
                vSQL   := vSQL || ' ' || cWhere_Clause;
            END IF;
        END IF;

        -- Now Execute Dynamic SQL
        vCursor   := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE (vCursor, vSQL, DBMS_SQL.native);

        -- Define Cols
        FOR i IN 1 .. t_column_name.COUNT
        LOOP
            DBMS_SQL.DEFINE_COLUMN (vCursor, i, vColTemp,
                                    1000);
        END LOOP;

        vRows     := DBMS_SQL.EXECUTE (vCursor);

        -- Loop Through Records
        LOOP
            IF DBMS_SQL.FETCH_ROWS (vCursor) = 0
            THEN
                EXIT;
            END IF;

            -- Output in XML format
            fnd_file.put_line (fnd_file.output, '<' || cTable_Name || '>');

            FOR i IN 1 .. t_column_name.COUNT
            LOOP
                DBMS_SQL.COLUMN_VALUE (vCursor, i, vColTemp);
                fnd_file.put_line (
                    fnd_file.output,
                       ' <'
                    || t_column_name (i)
                    || '>'
                    || vColTemp
                    || '</'
                    || t_column_name (i)
                    || '>');
            END LOOP;

            fnd_file.put_line (fnd_file.output, '</' || cTable_Name || '>');
        END LOOP;

        fnd_file.put_line (fnd_file.output, '</dt>');
        fnd_file.put_line (fnd_file.LOG, 'GENERIC XML GENERATION. FINISH...');

        DBMS_SQL.CLOSE_CURSOR (vCursor);
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_SQL.CLOSE_CURSOR (vCursor);
            RAISE;
    END GENERIC;

    ---------------------------------
    -- Populate Custom Attributes
    ---------------------------------
    PROCEDURE populate_custom_attribute (cPosition NUMBER, cValue VARCHAR2)
    IS
    BEGIN
        gCustomAttributes (cPosition)   := cValue;
    END populate_custom_attribute;

    --
    -- fetch_custom_attribute
    --
    FUNCTION fetch_custom_attribute (cPosition NUMBER)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN gCustomAttributes (cPosition);
    END fetch_custom_attribute;


    FUNCTION fmt_list (cFmtString IN VARCHAR2, cAddrRec IN addr_rec_type)
        RETURN VARCHAR2
    IS
        nBeginPos         NUMBER := 1;
        nEndPos           NUMBER;
        lnTokCnt          NUMBER := 0;
        nnLnTokCnt        NUMBER := 0;
        vNextToken        VARCHAR2 (60);
        vNextTokenValue   VARCHAR2 (500);
        vLastTokenValue   VARCHAR2 (500);
        vSeparator        VARCHAR2 (60) := gStringBlank;
        vSepTokenFlag     BOOLEAN;
        vResultString     VARCHAR2 (1000);
        vFmtString        VARCHAR2 (500);
    BEGIN
        IF (cFmtString IS NULL)
        THEN
            vFmtString   :=
                'CUST_NAME NL ADDR1 NL ADDR2 NL ADDR3 NL ADDR4 NL CITY STATE ZIP NL COUNTRY';
        ELSE
            vFmtString   := RTRIM (cFmtString);
        END IF;

        LOOP
            vNextTokenValue   := NULL;
            vSepTokenFlag     := FALSE;

            IF INSTR (vFmtString, gStringBlank, nBeginPos) = 0
            THEN
                nEndPos   := (LENGTH (vFmtString) + 1) - nBeginPos;
            ELSIF INSTR (vFmtString, gStringBlank, nBeginPos) > 0
            THEN
                nEndPos   :=
                    INSTR (vFmtString, gStringBlank, nBeginPos) - (nBeginPos);
            END IF;

            vNextToken        := SUBSTR (vFmtString, nBeginPos, nEndPos);

            IF vNextToken = 'CUST_NAME'
            THEN
                vNextTokenValue   := cAddrRec.customer_name;
            ELSIF vNextToken = 'ENTITY_NAME'
            THEN
                vNextTokenValue   := cAddrRec.customer_name;
            ELSIF vNextToken = 'ALT_CUST_NAME'
            THEN
                vNextTokenValue   := cAddrRec.alt_customer_name;
            ELSIF vNextToken = 'CUST_NAME_BASE'
            THEN
                vNextTokenValue   := cAddrRec.customer_name_base;
            ELSIF vNextToken = 'ACCOUNT_NAME'
            THEN
                vNextTokenValue   := cAddrRec.Account_name;
            ELSIF vNextToken = 'ADDR1'
            THEN
                vNextTokenValue   := cAddrRec.address1;
            ELSIF vNextToken = 'ADDR2'
            THEN
                vNextTokenValue   := cAddrRec.address2;
            ELSIF vNextToken = 'ADDR3'
            THEN
                vNextTokenValue   := cAddrRec.address3;
            ELSIF vNextToken = 'ADDR4'
            THEN
                vNextTokenValue   := cAddrRec.address4;
            ELSIF vNextToken = 'ZIP'
            THEN
                vNextTokenValue   := cAddrRec.postal_code;
            ELSIF vNextToken = 'CITY'
            THEN
                vNextTokenValue   := cAddrRec.city;
            ELSIF vNextToken = 'COUNTY'
            THEN
                vNextTokenValue   := cAddrRec.county;
            ELSIF vNextToken = 'COUNTRY_CODE'
            THEN
                vNextTokenValue   := cAddrRec.country_code;
            ELSIF vNextToken = 'STATE'
            THEN
                vNextTokenValue   := cAddrRec.state;
            ELSIF vNextToken = 'STATE_CODE'
            THEN
                vNextTokenValue   := cAddrRec.state_code;
            ELSIF vNextToken = 'PROVINCE'
            THEN
                vNextTokenValue   := cAddrRec.province;
            ELSIF vNextToken = 'COUNTRY'
            THEN
                vNextTokenValue   := cAddrRec.country;
            ELSIF vNextToken = 'CON_TITLE'
            THEN
                vNextTokenValue   := cAddrRec.contact_title;
            ELSIF vNextToken = 'CON_FN'
            THEN
                vNextTokenValue   := cAddrRec.contact_first_name;
            ELSIF vNextToken = 'CON_MN'
            THEN
                vNextTokenValue   := cAddrRec.contact_middle_names;
            ELSIF vNextToken = 'CON_LN'
            THEN
                vNextTokenValue   := cAddrRec.contact_last_name;
            ELSIF vNextToken = 'CON_JOB_TITLE'
            THEN
                vNextTokenValue   := cAddrRec.contact_job_title;
            ELSIF vNextToken = 'CON_MAIL_STOP'
            THEN
                vNextTokenValue   := cAddrRec.contact_mail_stop;
            ELSIF vNextToken = 'CUSTOM_ATTR1'
            THEN
                vNextTokenValue   := fetch_custom_attribute (1);
            ELSIF vNextToken = 'CUSTOM_ATTR2'
            THEN
                vNextTokenValue   := fetch_custom_attribute (2);
            ELSIF vNextToken = 'CUSTOM_ATTR3'
            THEN
                vNextTokenValue   := fetch_custom_attribute (3);
            ELSIF vNextToken = 'CUSTOM_ATTR4'
            THEN
                vNextTokenValue   := fetch_custom_attribute (4);
            ELSIF vNextToken = 'CUSTOM_ATTR5'
            THEN
                vNextTokenValue   := fetch_custom_attribute (5);
            ELSIF vNextToken = 'COMMA'
            THEN
                vSeparator      := ', ';
                vSepTokenFlag   := TRUE;
            ELSIF vNextToken = 'HYPHEN'
            THEN
                vSeparator      := '-';
                vSepTokenFlag   := TRUE;
            ELSIF vNextToken = 'NL'
            THEN
                vSeparator      := CHR (10);
                vSepTokenFlag   := TRUE;
            ELSIF vNextToken = 'XNL'
            THEN
                vSeparator      := CHR (10);
                vSepTokenFlag   := TRUE;
            ELSE
                -- Accepting next token as a literal - it's a feature!
                vNextTokenValue   := vNextToken;
            END IF;

            IF (vNextToken = 'XNL')
            THEN
                -- Special case of a forced new line.
                -- Normally, separators do not cause immediate action.
                vResultString     :=
                    vResultString || vLastTokenValue || vSeparator;
                vLastTokenValue   := NULL;          -- This restarts next line
                nnLnTokCnt        := 0;
                lnTokCnt          := 0;
                vSeparator        := gStringBlank;
            END IF;

            IF (NOT vSepTokenFlag)
            THEN
                IF     SUBSTR (vSeparator, 1, 1) = CHR (10)
                   AND (nnLnTokCnt > 0 OR lnTokCnt = 0)
                THEN
                    vResultString   :=
                        vResultString || vLastTokenValue || vSeparator;
                    nnLnTokCnt   := 0;
                    lnTokCnt     := 0;
                ELSE
                    IF vNextTokenValue IS NULL
                    THEN
                        IF (vLastTokenValue IS NOT NULL)
                        THEN
                            vResultString   :=
                                   vResultString
                                || vLastTokenValue
                                || gStringBlank;
                        END IF;
                    ELSE
                        IF (vLastTokenValue IS NOT NULL)
                        THEN
                            vResultString   :=
                                   vResultString
                                || vLastTokenValue
                                || vSeparator;
                        END IF;
                    END IF;
                END IF;

                vLastTokenValue   := vNextTokenValue;
                vSeparator        := gStringBlank;
                lnTokCnt          := lnTokCnt + 1;

                IF vNextTokenValue IS NOT NULL
                THEN
                    nnLnTokCnt   := nnLnTokCnt + 1;
                END IF;
            END IF;

            EXIT WHEN INSTR (vFmtString, gStringBlank, nBeginPos) = 0;

            nBeginPos         :=
                INSTR (vFmtString, gStringBlank, nBeginPos) + 1;
        END LOOP;

        RETURN (RTRIM (vResultString || vLastTokenValue, CHR (10)));
    END fmt_list;


    --
    --  fmt_standard_addres
    --
    FUNCTION fmt_standard_address (cCompany_name         IN VARCHAR2,
                                   cAddress1             IN VARCHAR2,
                                   cAddress2             IN VARCHAR2,
                                   cAddress3             IN VARCHAR2,
                                   cAddress4             IN VARCHAR2,
                                   cCity                 IN VARCHAR2,
                                   cCounty               IN VARCHAR2,
                                   cCountry              IN VARCHAR2,
                                   cPostalCode           IN VARCHAR2,
                                   cStateCode            IN VARCHAR2,
                                   cPostalFormatString   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        vAddrRec   addr_rec_type;

        vToAddr    VARCHAR2 (5000);
    BEGIN
        vAddrRec.customer_name   := cCompany_Name;
        vAddrRec.address1        := cAddress1;
        vAddrRec.address2        := cAddress2;
        vAddrRec.address3        := cAddress3;
        vAddrRec.address4        := cAddress4;
        vAddrRec.city            := cCity;
        vAddrRec.county          := cCounty;
        vAddrRec.state_code      := cStateCode;
        vAddrRec.country         := cCountry;
        vAddrRec.postal_code     := cPostalCode;

        vToAddr                  :=
            fmt_list (NVL (cPostalFormatString, gDefaultFullPostalString),
                      vAddrRec);

        RETURN (vToAddr);
    END fmt_standard_address;

    FUNCTION get_source (p_inv_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_source_name   XXCP_SOURCES_V.source_name%TYPE;
    BEGIN
        SELECT DISTINCT xsv.source_name
          INTO lv_source_name
          FROM xxcp_ic_inv_lines xil, xxcp_ic_inv_header xih, --xxcp_process_history xph,
                                                              xxcp_source_assignments_v xsav,
               xxcp_sources_v xsv
         WHERE     1 = 1
               --AND  xsv.source_id = xph.source_id
               AND xsv.source_id = xsav.source_id
               AND xsav.SOURCE_ASSIGNMENT_ID = xil.source_assignment_id
               --AND  xph.process_history_id = xil.process_history_id
               AND xil.invoice_header_id = xih.invoice_header_id
               AND xih.invoice_header_id = p_inv_header_id;

        RETURN lv_source_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_source_name   := NULL;
            RETURN lv_source_name;
    END get_source;

    FUNCTION get_country (p_tax1 IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_country1   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT bill_to_country
              INTO lv_country1
              FROM xxcp_address_details
             WHERE tax_registration_id = p_tax1;

            RETURN lv_country1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_country1   := NULL;
                RETURN lv_country1;
        END;

        RETURN lv_country1;
    END;

    FUNCTION get_ship_from_country (p_inv_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_ship_from_country   VARCHAR2 (100) := NULL;
    BEGIN
        SELECT fvl.iso_territory_code
          INTO lv_ship_from_country
          FROM xxcp_source_assignments_v xsav, hr_all_organization_units hou, hr_locations hlv,
               fnd_territories_vl fvl
         WHERE     1 = 1
               AND hou.organization_id = xsav.org_id
               AND hlv.inventory_organization_id = hou.organization_id
               AND hlv.location_id = hou.location_id
               AND fvl.territory_code = hlv.country
               AND EXISTS
                       (SELECT 1
                          FROM xxcp_ic_inv_lines xil
                         WHERE     xil.source_assignment_id =
                                   xsav.source_assignment_id
                               AND xil.invoice_header_id = p_inv_header_id);

        RETURN lv_ship_from_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_const_address (p_comseg1         IN VARCHAR2,
                                p_comseg2         IN VARCHAR2,
                                p_inv_header_id   IN NUMBER,
                                p_tax_reg_id      IN NUMBER,
                                p_inv_add_id      IN NUMBER)
        RETURN VARCHAR2
    IS
        vAddress         VARCHAR2 (3000);
        lv_address1      VARCHAR2 (100);
        lv_address2      VARCHAR2 (100);
        lv_address3      VARCHAR2 (100);
        lv_address4      VARCHAR2 (100);
        lv_city          VARCHAR2 (100);
        lv_county        VARCHAR2 (100);
        lv_country       VARCHAR2 (100);
        lv_postal_code   VARCHAR2 (100);
        lv_state_code    VARCHAR2 (100);
        lv_comp          VARCHAR2 (100);
        ln_count         NUMBER := 0;
        lv_temp          VARCHAR2 (100);
    BEGIN
        ln_count   := 0;

        BEGIN
            SELECT get_source (p_inv_header_id) INTO lv_temp FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_temp   := NULL;
        END;

        IF lv_temp = 'Material Transactions'
        THEN
            BEGIN
                ln_count   := 0;

                BEGIN
                    /*SELECT  bill_to_country
                      INTO  lv_country1
                      FROM  xxcp_address_details
                     WHERE  tax_registration_id = p_inv_tax_reg;*/
                    SELECT DECODE (get_source (p_inv_header_id), 'Material Transactions', get_ship_from_country (p_inv_header_id), get_ou_country (p_comseg1, 'COUNTRY'))
                      INTO lv_country
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_country   := NULL;
                END;

                SELECT ffvl.attribute4, ffvl.attribute5, ffvl.attribute6,
                       ffvl.attribute7, ffvl.attribute8, ffvl.attribute9,
                       ffvl.attribute10, ffvl.attribute11, ffvl.attribute12,
                       ffvl.attribute13
                  INTO lv_comp, lv_address1, lv_address2, lv_address3,
                              lv_address4, lv_city, lv_county,
                              lv_country, lv_postal_code, lv_state_code
                  FROM apps.fnd_flex_value_sets ffv, apps.fnd_flex_values_vl ffvl
                 WHERE     ffv.flex_value_set_name = 'XXD_VT_ADDRESS_VS'
                       AND ffv.flex_value_set_id = ffvl.flex_value_set_id
                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND ffvl.attribute1 = p_comseg1
                       AND ffvl.attribute2 = p_comseg2
                       AND UPPER (lv_country) = UPPER (ffvl.attribute3);

                ln_count   := ln_count + 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_comp          := NULL;
                    lv_address1      := NULL;
                    lv_address2      := NULL;
                    lv_address3      := NULL;
                    lv_address4      := NULL;
                    lv_city          := NULL;
                    lv_county        := NULL;
                    lv_country       := NULL;
                    lv_postal_code   := NULL;
                    lv_state_code    := NULL;
                    ln_count         := 0;
            END;
        END IF;

        IF ln_count > 0
        THEN
            vAddress   :=
                Fmt_Standard_Address (
                    cCompany_Name         => lv_comp,
                    cAddress1             => lv_address1,
                    cAddress2             => lv_address2,
                    cAddress3             => lv_address3,
                    cAddress4             => lv_address4,
                    cCity                 => lv_city,
                    cCounty               => lv_county,
                    cCountry              => lv_country,
                    cPostalCode           => lv_postal_code,
                    cStateCode            => lv_state_code,
                    cPostalFormatString   => gDefaultFullPostalString);
            RETURN (vAddress);
        ELSE
            vAddress   := get_address (p_inv_add_id, 'B');
            RETURN (vAddress);
        END IF;
    /*vAddress := Fmt_Standard_Address(cCompany_Name           => NULL
                                        ,cAddress1           => 'Limited Fiscal Representation '
                                        ,cAddress2           => 'Deckers Benelux BV (BFV) '
                                        ,cAddress3           => 'Danzingerkade 211 1013AP '
                                        ,cAddress4           => NULL
                                        ,cCity               =>  'Deckers Europe Limited'
                                        ,cCounty             => NULL
                                        ,cCountry            => 'GB 886 0623 02/ Deckers Benelux BV (BFV) NL 8212.74.120.B02'
                                        ,cPostalCode         => 'Amsterdam '
                                        ,cStateCode          => NULL
                                        ,cPostalFormatString => gDefaultFullPostalString);
     Return(vAddress);*/

    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_const_address;

    FUNCTION Get_Address (cAddress_Id IN NUMBER, cType IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR st IS
            SELECT DECODE (cType,  'S', ship_to_name,  'B', bill_to_name,  'Error') name, DECODE (cType,  'S', ship_to_address_line_1,  'B', bill_to_address_line_1,  'Error') address_line_1, DECODE (cType,  'S', ship_to_address_line_2,  'B', bill_to_address_line_2,  'Error') address_line_2,
                   DECODE (cType,  'S', ship_to_address_line_3,  'B', bill_to_address_line_3,  'Error') address_line_3, DECODE (cType,  'S', ship_to_town_or_city,  'B', bill_to_town_or_city,  'Error') town_or_city, DECODE (cType,  'S', ship_to_region,  'B', bill_to_region,  'Error') region,
                   DECODE (cType,  'S', ship_to_country,  'B', bill_to_country,  'Error') country, --decode(cType, 'S', ship_to_country,          'B', NULL, 'Error')          country,
                                                                                                   DECODE (cType,  'S', ship_to_postal_code,  'B', bill_to_postal_code,  'Error') postal_code, DECODE (cType,  'S', ship_to_telephone_number,  'B', bill_to_telephone_number,  'Error') telephone_number,
                   DECODE (cType,  'S', ship_to_display_style,  'B', bill_to_display_style,  'Error') display_style, DECODE (cType,  'S', ship_to_state_Code,  'B', bill_to_state_code,  'Error') state_code, x.description address_style
              FROM xxcp_address_details fg, xxcp_lookups_v x
             WHERE     address_id = cAddress_Id
                   AND x.category LIKE 'ADDRESS FORMAT'
                   AND UPPER (
                           DECODE (cType,
                                   'S', ship_to_display_style,
                                   'B', bill_to_display_style)) =
                       UPPER (x.category_subset);


        vAddress   VARCHAR2 (3000);
    BEGIN
        FOR rec IN st
        LOOP
            vAddress   :=
                Fmt_Standard_Address (
                    cCompany_Name   => rec.name,
                    cAddress1       => rec.address_line_1,
                    cAddress2       => rec.address_line_2,
                    cAddress3       => rec.address_line_3,
                    cAddress4       => NULL,
                    cCity           => rec.town_or_city,
                    cCounty         => rec.region,
                    cCountry        => rec.country,
                    cPostalCode     => rec.postal_code,
                    cStateCode      => rec.state_Code,
                    cPostalFormatString   =>
                        NVL (rec.address_style, gDefaultFullPostalString));
        END LOOP;

        IF vAddress IS NULL AND cType = 'S'
        THEN
            vAddress   :=
                Get_Address (cAddress_Id => cAddress_Id, cType => 'B');
        END IF;

        RETURN (vAddress);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END Get_Address;

    FUNCTION get_ship_to_country (p_inv_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_ship_to_country   VARCHAR2 (100) := NULL;
    BEGIN
        SELECT fvl.iso_territory_code
          INTO lv_ship_to_country
          FROM hr_all_organization_units hou, hr_locations hlv, fnd_territories_vl fvl,
               xxcp_transaction_attrib_hdr_v xtah
         WHERE     1 = 1
               AND hlv.inventory_organization_id = hou.organization_id
               AND hlv.location_id = hou.location_id
               AND fvl.territory_code = hlv.country
               AND xtah.location_ref = TO_CHAR (hou.organization_id)
               AND EXISTS
                       (SELECT 1
                          FROM xxcp_mtl_material_transactions xxmmt, xxcp_ic_inv_lines xil, xxcp_process_history xxph
                         WHERE     xxph.interface_id = xxmmt.vt_interface_id
                               AND xxph.process_history_id =
                                   xil.process_history_id
                               AND xil.invoice_header_id = p_inv_header_id
                               AND xxmmt.vt_transaction_id =
                                   xtah.transaction_id
                               AND (xxmmt.attribute2 = 'Internal Shipments' OR xxmmt.vt_transaction_type = 'Internal Order'));

        RETURN lv_ship_to_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    -- Get operating unit based on balancing segment
    FUNCTION get_ou_country (cbal_segment IN VARCHAR2, ctype IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_ou_name        VARCHAR2 (100);
        lv_country_code   FND_TERRITORIES_VL.ISO_TERRITORY_CODE%TYPE;
    BEGIN
        IF ctype = 'OU'
        THEN
            BEGIN
                SELECT hroutl_ou.NAME
                  INTO lv_ou_name
                  FROM apps.xle_entity_profiles lep, apps.xle_registrations reg, apps.hr_locations_all hrl,
                       apps.hz_parties hzp, apps.fnd_territories_vl ter, apps.hr_operating_units hro,
                       apps.hr_all_organization_units_tl hroutl_ou, apps.gl_legal_entities_bsvs glev
                 WHERE     1 = 1
                       AND lep.transacting_entity_flag(+) = 'Y'
                       AND lep.party_id = hzp.party_id
                       AND lep.legal_entity_id = reg.source_id
                       AND reg.source_table IN
                               ('XLE_ENTITY_PROFILES', 'XLE_ETB_PROFILES')
                       AND hrl.location_id = reg.location_id
                       AND reg.identifying_flag = 'Y'
                       AND ter.territory_code = hrl.country
                       AND lep.legal_entity_id = hro.default_legal_context_id
                       AND hroutl_ou.organization_id = hro.organization_id
                       AND glev.legal_entity_id = lep.legal_entity_id
                       AND hroutl_ou.language = 'US'
                       AND glev.flex_segment_value = cbal_segment;
            EXCEPTION
                WHEN TOO_MANY_ROWS
                THEN
                    lv_ou_name   := NULL;

                    SELECT DISTINCT hzp.party_name
                      INTO lv_ou_name
                      FROM apps.xle_entity_profiles lep, apps.xle_registrations reg, apps.hr_locations_all hrl,
                           apps.hz_parties hzp, apps.fnd_territories_vl ter, apps.hr_operating_units hro,
                           apps.hr_all_organization_units_tl hroutl_ou, apps.gl_legal_entities_bsvs glev
                     WHERE     1 = 1
                           AND lep.transacting_entity_flag(+) = 'Y'
                           AND lep.party_id = hzp.party_id
                           AND lep.legal_entity_id = reg.source_id
                           AND reg.source_table IN
                                   ('XLE_ENTITY_PROFILES', 'XLE_ETB_PROFILES')
                           AND hrl.location_id = reg.location_id
                           AND reg.identifying_flag = 'Y'
                           AND ter.territory_code = hrl.country
                           AND lep.legal_entity_id =
                               hro.default_legal_context_id
                           AND hroutl_ou.organization_id =
                               hro.organization_id
                           AND glev.legal_entity_id = lep.legal_entity_id
                           AND hroutl_ou.language = 'US'
                           AND glev.flex_segment_value = cbal_segment;
                WHEN OTHERS
                THEN
                    lv_ou_name   := NULL;
            END;

            RETURN lv_ou_name;
        ELSIF ctype = 'COUNTRY'
        THEN
            BEGIN
                SELECT DISTINCT ter.iso_territory_code
                  INTO lv_country_code
                  FROM apps.xle_entity_profiles lep, apps.xle_registrations reg, apps.hr_locations_all hrl,
                       apps.hz_parties hzp, apps.fnd_territories_vl ter, apps.hr_operating_units hro,
                       apps.hr_all_organization_units_tl hroutl_ou, apps.gl_legal_entities_bsvs glev
                 WHERE     1 = 1
                       AND lep.transacting_entity_flag(+) = 'Y'
                       AND lep.party_id = hzp.party_id
                       AND lep.legal_entity_id = reg.source_id
                       AND reg.source_table IN
                               ('XLE_ENTITY_PROFILES', 'XLE_ETB_PROFILES')
                       AND hrl.location_id = reg.location_id
                       AND reg.identifying_flag = 'Y'
                       AND ter.territory_code = hrl.country
                       AND lep.legal_entity_id = hro.default_legal_context_id
                       AND hroutl_ou.organization_id = hro.organization_id
                       AND glev.legal_entity_id = lep.legal_entity_id
                       AND hroutl_ou.language = 'US'
                       AND glev.flex_segment_value = cbal_segment;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_country_code   := NULL;
            END;

            RETURN lv_country_code;
        END IF;
    END get_ou_country;

    FUNCTION get_lang (p_ComSeg1 IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_language   VARCHAR2 (10) := NULL;
    BEGIN
        IF p_ComSeg1 IS NOT NULL
        THEN
            IF p_ComSeg1 IN (170, 190, 510)
            THEN
                lv_language   := 'CN';
            ELSE
                lv_language   := 'EN';
            END IF;

            RETURN lv_language;
        ELSE
            lv_language   := 'EN';
            RETURN lv_language;
        END IF;
    END get_lang;


    FUNCTION Get_comp_tax_reg (p_type IN VARCHAR2, p_comseg1 IN VARCHAR2, p_inv_tax_reg IN VARCHAR2
                               , p_inv_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_tax_reg_ref     VARCHAR2 (100);
        lv_country1        VARCHAR2 (100);
        lv_type            VARCHAR2 (100);
        lv_comseg1         VARCHAR2 (100);
        --lv_inv_tax_reg    VARCHAR2(100);
        lv_ship_from       VARCHAR2 (100);
        lv_tax_reg         VARCHAR2 (100);
        lv_tax_reg_final   VARCHAR2 (100);
    BEGIN
        BEGIN
            SELECT tax_registration_ref
              INTO lv_tax_reg_ref
              FROM xxcp_tax_registrations tax
             WHERE tax.tax_registration_id = p_inv_tax_reg;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_tax_reg_ref   := NULL;
        END;

        IF p_type = 'INV'
        THEN
            BEGIN
                /*SELECT  bill_to_country
                  INTO  lv_country1
                  FROM  xxcp_address_details
                 WHERE  tax_registration_id = p_inv_tax_reg;*/
                SELECT DECODE (get_source (p_inv_header_id), 'Material Transactions', get_ship_from_country (p_inv_header_id), get_ou_country (p_comseg1, 'COUNTRY'))
                  INTO lv_country1
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_country1   := NULL;
            END;

            BEGIN
                SELECT ffvl.attribute1,                                -- Type
                                        ffvl.attribute2,        -- from entity
                                                         --ffvl.attribute3, --  invoice tax
                                                         ffvl.attribute4, -- Ship From
                       ffvl.attribute5                               -- Tax ID
                  INTO lv_type, lv_comseg1, --lv_inv_tax_reg,
                                            lv_ship_from, lv_tax_reg
                  FROM apps.fnd_flex_value_sets ffv, apps.fnd_flex_values_vl ffvl
                 WHERE     ffv.flex_value_set_id = ffvl.flex_value_set_id
                       AND ffv.flex_value_set_name = 'XXD_VT_TAX_REG'
                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND ffvl.attribute1 = p_type
                       AND ffvl.attribute2 = p_ComSeg1
                       --AND ffvl.attribute3        = p_inv_tax_reg
                       AND UPPER (ffvl.attribute4) = UPPER (lv_country1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_type        := NULL;
                    lv_comseg1     := NULL;
                    --lv_inv_tax_reg := NULL;
                    lv_ship_from   := NULL;
                    lv_tax_reg     := NULL;
            END;
        END IF;

        IF lv_tax_reg IS NOT NULL
        THEN
            lv_tax_reg_final   := lv_tax_reg;
        ELSE
            lv_tax_reg_final   := lv_tax_reg_ref;
        END IF;

        RETURN lv_tax_reg_final;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END Get_comp_tax_reg;

    FUNCTION get_source_lang (p_inv_header_id   IN NUMBER,
                              p_ComSeg1         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_source_lang   VARCHAR2 (100);
        lv_source        VARCHAR2 (100);
    BEGIN
        IF p_inv_header_id IS NOT NULL
        THEN
            BEGIN
                SELECT get_source (p_inv_header_id) INTO lv_source FROM DUAL;

                IF     lv_source IS NOT NULL
                   AND lv_source = 'Material Transactions'
                THEN
                    IF p_ComSeg1 IS NOT NULL AND p_ComSeg1 IN (170, 190, 510)
                    THEN
                        lv_source_lang   := 'INVCN';
                    ELSIF     p_ComSeg1 IS NOT NULL
                          AND p_ComSeg1 NOT IN (170, 190, 510)
                    THEN
                        lv_source_lang   := 'INVEN';
                    ELSIF p_ComSeg1 IS NULL
                    THEN
                        lv_source_lang   := NULL;
                    END IF;

                    RETURN lv_source_lang;
                ELSIF     lv_source IS NOT NULL
                      AND lv_source <> 'Material Transactions'
                THEN
                    IF p_ComSeg1 IS NOT NULL AND p_ComSeg1 IN (170, 190, 510)
                    THEN
                        lv_source_lang   := 'NONINVCN';
                    ELSIF     p_ComSeg1 IS NOT NULL
                          AND p_ComSeg1 NOT IN (170, 190, 510)
                    THEN
                        lv_source_lang   := 'NONINVEN';
                    ELSIF p_ComSeg1 IS NULL
                    THEN
                        lv_source_lang   := NULL;
                    END IF;

                    RETURN lv_source_lang;
                END IF;

                RETURN lv_source_lang;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        ELSE
            lv_source_lang   := NULL;
            RETURN lv_source_lang;
        END IF;
    END get_source_lang;

    FUNCTION get_legal_text (p_ComSeg1 IN VARCHAR2, p_ComSeg2 IN VARCHAR2, p_tax1 IN VARCHAR2, p_tax2 IN VARCHAR2, p_type IN VARCHAR2, p_lang IN VARCHAR2
                             , p_inv_header_Id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_legal_text1   VARCHAR2 (1000);
        lv_legal_text    VARCHAR2 (1000);
        lv_country1      VARCHAR2 (100);
        lv_country2      VARCHAR2 (100);
        lv_ship_from     VARCHAR2 (100);
        lv_type          VARCHAR2 (100);
        lv_lang          VARCHAR2 (100);
        lv_comseg1       VARCHAR2 (100);
        lv_comseg2       VARCHAR2 (100);
    BEGIN
        IF p_type = 'INV'
        THEN
            BEGIN
                /*SELECT  bill_to_country
                  INTO  lv_country1
                  FROM  xxcp_address_details
                 WHERE  tax_registration_id = p_tax1;*/
                SELECT DECODE (get_source (p_inv_header_id), 'Material Transactions', get_ship_from_country (p_inv_header_id), get_ou_country (p_comseg1, 'COUNTRY'))
                  INTO lv_country1
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_country1   := NULL;
            END;

            BEGIN
                SELECT ffvl.attribute1, ffvl.attribute2, ffvl.attribute3,
                       ffvl.attribute4, ffvl.attribute5, ffvl.attribute6
                  INTO lv_type, lv_lang, lv_comseg1, lv_comseg2,
                              lv_ship_from, lv_legal_text1
                  FROM apps.fnd_flex_value_sets ffv, apps.fnd_flex_values_vl ffvl
                 WHERE     ffv.flex_value_set_id = ffvl.flex_value_set_id
                       AND ffv.flex_value_set_name = 'XXD_VT_LEGAL_TEXT'
                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND ffvl.attribute1 = p_type
                       AND ffvl.attribute2 = p_lang
                       AND ffvl.attribute3 = p_ComSeg1
                       AND ffvl.attribute4 = p_ComSeg2
                       AND UPPER (ffvl.attribute5) = UPPER (lv_country1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ship_from     := NULL;
                    lv_legal_text1   := NULL;
                    lv_comseg1       := NULL;
                    lv_comseg2       := NULL;
                    lv_type          := NULL;
                    lv_lang          := NULL;
            END;
        ELSIF p_type = 'NONINV'
        THEN
            BEGIN
                SELECT ffvl.attribute1, ffvl.attribute2, ffvl.attribute3,
                       ffvl.attribute4, ffvl.attribute5, ffvl.attribute6
                  INTO lv_type, lv_lang, lv_comseg1, lv_comseg2,
                              lv_ship_from, lv_legal_text1
                  FROM apps.fnd_flex_value_sets ffv, apps.fnd_flex_values_vl ffvl
                 WHERE     ffv.flex_value_set_id = ffvl.flex_value_set_id
                       AND ffv.flex_value_set_name = 'XXD_VT_LEGAL_TEXT'
                       AND NVL (ffvl.enabled_flag, 'Y') = 'Y'
                       AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND SYSDATE BETWEEN NVL (ffvl.end_date_active,
                                                SYSDATE)
                                       AND SYSDATE
                       AND ffvl.attribute1 = p_type
                       AND ffvl.attribute2 = p_lang
                       AND ffvl.attribute3 = p_ComSeg1
                       AND ffvl.attribute4 = p_ComSeg2
                       AND ffvl.attribute5 IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ship_from     := NULL;
                    lv_legal_text1   := NULL;
                    lv_comseg1       := NULL;
                    lv_comseg2       := NULL;
                    lv_type          := NULL;
                    lv_lang          := NULL;
            END;
        END IF;

        IF     p_type = 'INV'
           AND p_lang = 'EN'
           AND p_comseg1 IS NOT NULL
           AND p_ComSeg2 IS NOT NULL
           AND p_ComSeg1 = lv_comseg1
           AND p_ComSeg2 = lv_comseg2
           AND UPPER (lv_country1) = UPPER (lv_ship_from)
        THEN
            lv_legal_text   := lv_legal_text1;
        ELSIF     p_type = 'NONINV'
              AND p_lang = 'EN'
              AND p_comseg1 IS NOT NULL
              AND p_ComSeg2 IS NOT NULL
              AND p_ComSeg1 = lv_comseg1
              AND p_ComSeg2 = lv_comseg2 --and upper(lv_country1) = upper(lv_ship_from)
        THEN
            lv_legal_text   := lv_legal_text1;
        ELSE
            lv_legal_text   := NULL;
        END IF;

        RETURN lv_legal_text;
    END get_legal_text;

    FUNCTION get_so_ar_number (p_mmt_trx_id IN NUMBER)
        RETURN VARCHAR2
    IS
        --lv_trx_type xxcp_mtl_material_transaction.vt_transaction_type%TYPE;
        l_inv_num   VARCHAR2 (100);
    BEGIN
        SELECT inv_num
          INTO l_inv_num
          FROM (  SELECT 'CI' || wnd.delivery_id || '-' || TO_CHAR (MIN (wnd.confirm_date), 'YYYYMMDD') inv_num
                    FROM oe_order_headers_all ooha, oe_order_lines_all oola, mtl_system_items_b msib,
                         po_location_associations_all plaa, org_organization_definitions ood, wsh_delivery_details wdd,
                         wsh_new_deliveries wnd, wsh_delivery_assignments wda, mtl_material_transactions mmt
                   WHERE     1 = 1
                         AND ooha.header_id = oola.header_id
                         AND oola.inventory_item_id = msib.inventory_item_id
                         AND oola.ship_from_org_id = msib.organization_id
                         AND oola.cancelled_flag = 'N'
                         AND ood.organization_id = plaa.organization_id
                         AND plaa.site_use_id(+) = ooha.ship_to_org_id
                         AND wdd.source_header_id = ooha.header_id
                         AND wdd.source_line_id = oola.line_id
                         AND mmt.trx_source_line_id = oola.line_id
                         AND wdd.source_code = 'OE'
                         AND wdd.delivery_detail_id = wda.delivery_detail_id
                         AND wda.delivery_id = wnd.delivery_id
                         AND mmt.transaction_id = p_mmt_trx_id
                GROUP BY ooha.order_number, ooha.org_id, ooha.transactional_curr_code,
                         ood.operating_unit, ood.organization_id, ooha.invoice_to_org_id,
                         ooha.ship_to_org_id, wnd.delivery_id, oola.unit_selling_price
                UNION
                SELECT rcta.trx_NUMBER
                  FROM apps.ra_customer_trx_all rcta, apps.ra_customer_trx_lines_all rctla, apps.mtl_material_transactions mmt
                 WHERE     1 = 1
                       AND rcta.customer_trx_id = rctla.customer_trx_id
                       AND rctla.interface_line_attribute6 =
                           TO_CHAR (mmt.trx_source_line_id)
                       AND mmt.transaction_id = p_mmt_trx_id);

        RETURN l_inv_num;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_so_cust_po (p_mmt_trx_id IN NUMBER, p_Trx_type IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_so_po_num   VARCHAR2 (100);
    BEGIN
        IF p_trx_type = 'SO'
        THEN
            BEGIN
                SELECT ooha.order_number
                  INTO lv_so_po_num
                  FROM apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                 WHERE     1 = 1
                       AND oola.header_id = ooha.header_id
                       AND mmt.trx_source_line_id = oola.line_id
                       AND mmt.transaction_id = p_mmt_trx_id;

                RETURN lv_so_po_num;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_so_po_num   := NULL;
            END;
        ELSIF p_trx_type = 'PO'
        THEN
            BEGIN
                SELECT ooha.cust_po_number
                  INTO lv_so_po_num
                  FROM apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
                 WHERE     1 = 1
                       AND oola.header_id = ooha.header_id
                       AND mmt.trx_source_line_id = oola.line_id
                       AND mmt.transaction_id = p_mmt_trx_id;

                RETURN lv_so_po_num;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_so_po_num   := NULL;
            END;

            RETURN lv_so_po_num;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_so_po_num   := NULL;
            RETURN lv_so_po_num;
    END;

    --
    -- IC Invoice
    --
    FUNCTION get_mmt_type (p_inv_header_id IN NUMBER)
        RETURN VARCHAR2
    IS
        --pragma autonomous_transaction;

        lv_mmt_type   VARCHAR2 (100);
    BEGIN
        SELECT attribute2
          INTO lv_mmt_type
          FROM xxcp_mtl_material_transactions xxmmt
         WHERE     1 = 1
               --    AND xxmmt.vt_interface_id = p_inv_header_id;
               AND EXISTS
                       (SELECT 1
                          FROM xxcp_ic_inv_lines xil, xxcp_process_history xxph
                         WHERE     xxph.interface_id = xxmmt.vt_interface_id
                               AND xxph.process_history_id =
                                   xil.process_history_id
                               AND xil.invoice_header_id = p_inv_header_id);

        RETURN lv_mmt_type;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_mmt_type;

    -- Added as per CCR0009071


    FUNCTION get_valid_data_display_fnc (pn_inv_header_id IN NUMBER, pv_wh_det IN VARCHAR2:= NULL, pv_type IN VARCHAR2:= NULL)
        RETURN VARCHAR2
    IS
        ln_ship_org_id        NUMBER;
        ln_orig_ship_org_id   NUMBER;
        lv_ret_value          VARCHAR2 (100);
        lv_terr_code          VARCHAR2 (100);
        lv_terr_country       VARCHAR2 (100);
    BEGIN
        ln_ship_org_id        := NULL;
        ln_orig_ship_org_id   := NULL;
        lv_ret_value          := NULL;
        lv_terr_code          := NULL;
        lv_terr_country       := NULL;

        BEGIN
            SELECT DISTINCT oola.ship_from_org_id,
                            (SELECT oolla.ship_from_org_id
                               FROM oe_order_lines_all oolla
                              WHERE     oolla.line_id =
                                        oola.reference_line_id
                                    AND mmt.inventory_item_id =
                                        oolla.inventory_item_id) orig_ship
              INTO ln_ship_org_id, ln_orig_ship_org_id
              FROM apps.mtl_material_transactions mmt, apps.xxcp_mtl_material_transactions xmmt, apps.oe_order_lines_all oola,
                   apps.oe_order_headers_all ooha, apps.oe_transaction_types_tl ottl, apps.xxcp_process_history ph,
                   apps.xxcp_ic_inv_lines l, apps.xxcp_ic_inv_header h, apps.hr_all_organization_units org,
                   apps.hr_operating_units hou
             WHERE     1 = 1
                   AND mmt.transaction_id = xmmt.vt_transaction_id
                   AND ooha.header_id = oola.header_id
                   AND oola.line_id = mmt.trx_source_line_id
                   AND mmt.inventory_item_id = oola.inventory_item_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                             WHERE     ffvs.flex_value_set_id =
                                       ffv.flex_value_set_id
                                   AND flex_value_set_name =
                                       'XXD_AR_MTD_OU_VS'
                                   AND ffv.enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   ffv.start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   ffv.end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                   AND ffv.flex_value <> 'ALL EMEA'
                                   AND hou.NAME = ffv.flex_value)
                   AND ooha.org_id = hou.organization_id
                   AND xmmt.vt_interface_id = ph.interface_id
                   AND ooha.order_type_id = ottl.transaction_type_id
                   AND ottl.language = USERENV ('LANG')
                   AND ph.process_history_id = l.process_history_id
                   AND l.invoice_header_id = h.invoice_header_id
                   AND oola.ship_from_org_id = org.organization_id
                   AND h.invoice_header_id = pn_inv_header_id;
        --                 AND h.invoice_number IN
        --                        ('500-00485426',
        --                         '500-00485437',
        --                         '500-00485433',
        --                         '500-00485441');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ship_org_id        := NULL;
                ln_orig_ship_org_id   := NULL;
        END;

        IF pv_wh_det IS NULL
        THEN
            IF     ln_ship_org_id IS NOT NULL
               AND ln_orig_ship_org_id IS NOT NULL
               AND ln_ship_org_id = ln_orig_ship_org_id
            THEN
                lv_ret_value   := 'INVALID';
                RETURN lv_ret_value;
            ELSIF     ln_ship_org_id IS NOT NULL
                  AND ln_orig_ship_org_id IS NOT NULL
                  AND ln_ship_org_id <> ln_orig_ship_org_id
            THEN
                lv_ret_value   := 'VALID';
                RETURN lv_ret_value;
            ELSE
                lv_ret_value   := 'INVALID';
                RETURN lv_ret_value;
            END IF;
        ELSIF pv_wh_det IS NOT NULL AND ln_ship_org_id IS NOT NULL
        THEN
            lv_terr_code      := NULL;
            lv_terr_country   := NULL;

            BEGIN
                SELECT flv.iso_territory_code, flv.territory_code
                  INTO lv_terr_code, lv_terr_country
                  FROM hr_locations_v hlv, hr_all_organization_units hou, fnd_territories_vl flv
                 WHERE     hlv.inventory_organization_id =
                           hou.organization_id
                       AND hlv.location_id = hou.location_id
                       AND flv.territory_code = hlv.country
                       AND hou.organization_id = ln_ship_org_id;
            -- RETURN lv_terr_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_terr_code      := NULL;
                    lv_terr_country   := NULL;
            --RETURN NULL;
            END;

            IF pv_type IS NOT NULL
            THEN
                RETURN lv_terr_country;
            ELSE
                RETURN lv_terr_code;
            END IF;
        ELSE
            RETURN NULL;
        END IF;
    END get_valid_data_display_fnc;

    FUNCTION get_ship_vat (pn_att IN NUMBER, pv_ship_value IN VARCHAR2)
        RETURN VARCHAR2
    IS
        pv_vat_num   VARCHAR2 (100);
    BEGIN
        SELECT attribute3
          INTO pv_vat_num
          FROM apps.xxcp_cust_data
         WHERE     category_name = 'DECKERS VAT FOR IC PRINT'
               AND attribute1 = pn_att                                 --'110'
               AND attribute2 = pv_ship_value;

        RETURN pv_vat_num;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            BEGIN
                SELECT attribute3
                  INTO pv_vat_num
                  FROM apps.xxcp_cust_data
                 WHERE     category_name = 'DECKERS VAT FOR IC PRINT'
                       AND attribute1 = pn_att                         --'110'
                       AND attribute2 = '*'
                       AND attribute4 =
                           DECODE (pv_ship_value,  'NL', 'ME2',  'GB', 'ME1');

                RETURN pv_vat_num;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        WHEN OTHERS
        THEN
            pv_vat_num   := NULL;
            RETURN pv_vat_num;
    END get_ship_vat;

    -- End of Change CCR0009071

    PROCEDURE IC_Invoice (errbuf OUT VARCHAR2, retcode OUT NUMBER, cInvoiceType IN VARCHAR2, cSource_id IN VARCHAR2, cSource_group_id IN VARCHAR2, cSource_assignment_id IN VARCHAR2, cInvoiceTaxReg IN VARCHAR2, cCustomerTaxReg IN VARCHAR2, cInvoice_Number_From IN VARCHAR2, cInvoice_Number_To IN VARCHAR2, cPurchase_Order IN VARCHAR2, cSales_Order IN VARCHAR2, cInvoice_Date_Low IN VARCHAR2, cInvoice_Date_High IN VARCHAR2, cProduct_Family IN VARCHAR2
                          , cUnPrinted_Flag IN VARCHAR2)
    IS
        vClob      CLOB;
        vDummy     BOOLEAN;
        vCounter   PLS_INTEGER;

        -- OOD-641 capture all un-printed invoices that match given parameters
        CURSOR curNotPrinted (pInvoiceTaxReg IN PLS_INTEGER, pCustomerTaxReg IN PLS_INTEGER, pPurchaseOrder IN VARCHAR2, pSalesOrder IN VARCHAR2, pProductFamily IN VARCHAR2, pUnprintedFlag IN VARCHAR2, pInvoiceDateLow IN VARCHAR2, pInvoiceDateHigh IN VARCHAR2, pInvoice_Number_From IN VARCHAR2
                              , pInvoice_Number_To IN VARCHAR2)
        IS
            SELECT a.invoice_header_id, a.invoice_tax_reg_id, a.customer_tax_reg_id
              FROM xxcp_ic_inv_header a
             WHERE     NVL (a.invoice_tax_reg_id, 0) =
                       NVL (pInvoiceTaxReg, NVL (a.invoice_tax_reg_id, 0))
                   AND NVL (a.customer_tax_reg_id, 0) =
                       NVL (pCustomerTaxReg, NVL (a.customer_tax_reg_id, 0))
                   AND a.invoice_header_id IN
                           (SELECT b.invoice_header_id
                              FROM xxcp_instance_ic_inv_v b
                             WHERE     NVL (b.po_number, '~null~') =
                                       NVL (pPurchaseOrder,
                                            NVL (b.po_number, '~null~'))
                                   AND NVL (b.so_number, '~null~') =
                                       NVL (pSalesOrder,
                                            NVL (b.so_Number, '~null~'))
                                   AND NVL (b.product_family, '~null~') =
                                       NVL (pProductFamily,
                                            NVL (b.product_family, '~null~'))
                                   -- VT273-437 Only select headers that have not been printed for this run
                                   AND a.printed_flag = 'N'
                                   AND NVL (a.release_invoice, 'Y') = 'Y'
                                   AND NVL (b.invoice_number, '~null~') BETWEEN NVL (
                                                                                    cInvoice_Number_From,
                                                                                    NVL (
                                                                                        b.invoice_number,
                                                                                        '~null~'))
                                                                            AND NVL (
                                                                                    cInvoice_Number_To,
                                                                                    NVL (
                                                                                        b.invoice_number,
                                                                                        '~null~'))
                                   AND a.invoice_date BETWEEN NVL (
                                                                  TO_DATE (
                                                                      pInvoiceDateLow,
                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                  TRUNC (
                                                                      b.invoice_date))
                                                          AND NVL (
                                                                  TO_DATE (
                                                                      pInvoiceDateHigh,
                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                  TRUNC (
                                                                      b.invoice_date)))
                   AND a.invoice_header_id IN
                           (SELECT c.header_id
                              FROM xxcp_instance_ic_inv_comp_v c
                             WHERE     NVL (a.invoice_tax_reg_id, 0) =
                                       NVL (pInvoiceTaxReg,
                                            NVL (c.comp_tax_reg_id, 0))
                                   AND NVL (a.customer_tax_reg_id, 0) =
                                       NVL (pCustomerTaxReg,
                                            NVL (c.cust_tax_reg_id, 0)));
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'XXCP_BI_PUB.IC_Invoice Parameters Entered');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice type:       ' || NVL (cInvoiceType, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice tax reg:    ' || NVL (cInvoiceTaxReg, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Customer tax reg:   ' || NVL (cCustomerTaxReg, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice number from:' || NVL (cInvoice_Number_From, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice number to:  ' || NVL (cInvoice_Number_To, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Purchase order:     ' || NVL (cPurchase_Order, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Sales Order         ' || NVL (cSales_Order, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice date from:  ' || NVL (cInvoice_Date_Low, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice date to:    ' || NVL (cInvoice_Date_High, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Product family:     ' || NVL (cProduct_Family, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Unprinted:          ' || NVL (cUnPrinted_Flag, 'ALL'));
        -- 03.06.28 Output the extra parameters
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Source_id:           ' || NVL (cSource_id, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Source_group_id:     ' || NVL (cSource_group_id, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Source_assignment_id:' || NVL (cSource_assignment_id, 'ALL'));
        -- 03.06.28 Set the context so that can be used in the views
        xxcp_context.set_source_id (cSource_id => cSource_id);
        xxcp_context.set_context (cAttribute   => 'source_group_id',
                                  cValue       => cSource_group_id);
        xxcp_context.set_context (cAttribute   => 'source_assignment_id',
                                  cValue       => cSource_assignment_id);

          SELECT XMLELEMENT (
                     "INVOICE_PRINT",
                     XMLELEMENT (
                         "PARAMS",
                         XMLELEMENT (
                             "PARAM_AMALGAM",
                                'Company Reg ID '
                             || NVL (cInvoiceTaxReg, '*')
                             || ' Customer Reg ID '
                             || NVL (cCustomerTaxReg, '*')
                             || CHR (10)
                             || DECODE (
                                    cInvoice_Date_High,
                                    NULL, NULL,
                                       'Invoice Date '
                                    || NVL (SUBSTR (cInvoice_Date_Low, 1, 10),
                                            '*')
                                    || ' - '
                                    || SUBSTR (cInvoice_Date_High, 1, 10)
                                    || CHR (10))
                             || DECODE (
                                    cPurchase_Order,
                                    NULL, NULL,
                                       'PO '
                                    || cPurchase_Order
                                    || DECODE (cSales_Order,
                                               NULL, NULL,
                                               ' SO ' || cSales_Order)
                                    || CHR (10))
                             || DECODE (
                                    cInvoiceType,
                                    NULL, NULL,
                                    'Invoice Type ' || cInvoiceType || CHR (10))
                             || DECODE (
                                    cInvoice_Number_From,
                                    NULL, NULL,
                                       'Invoice Number '
                                    || cInvoice_Number_From
                                    || ' - '
                                    || cInvoice_Number_To
                                    || CHR (10))),
                         XMLELEMENT ("UNPRINTED", NVL (cUnPrinted_Flag, 'N'))),
                     XMLAGG (
                         XMLELEMENT (
                             "HEADER",
                             XMLELEMENT ("HEADER_ID", a.header_id),
                             XMLELEMENT ("COMPANY_TAX_REG_ID",
                                         a.comp_tax_reg_id),
                             XMLELEMENT ("COMPANY_TAX_REF", c.attribute4),
                             XMLELEMENT ("COMPANY_DESC", a.comp_desc),
                             XMLELEMENT ("LANG", get_lang (a.att2)),
                             XMLELEMENT ("SOLD_BY_OU",
                                         get_ou_country (a.att2, 'OU')),
                             XMLELEMENT ("SOLD_TO_OU",
                                         get_ou_country (a.att3, 'OU')),
                             --XMLELEMENT ("SHIP_FROM", get_ship_from (a.header_id, a.att3)),-- Commented for CCR0009071
                             --XMLELEMENT ("SHIP_TO", get_ship_to (a.header_id, a.att3)),    -- Commented for CCR0009071
                             XMLELEMENT (
                                 "BILL_TO_ADDRESS",
                                 get_Address (c.invoice_address_id, 'B')),
                             XMLELEMENT ("SOURCE", get_source (a.header_id)),
                             XMLELEMENT ("TEMP",
                                         get_source_lang (a.header_id, a.att2)),
                             -- Commented as per CCR0009071
                             /*XMLELEMENT (
                                "get_TEXT",
                                DECODE (
                                   get_source (a.header_id),
                                   'Material Transactions', get_legal_text (
                                                               a.att2,
                                                               a.att3,
                                                               a.comp_tax_reg_id,
                                                               a.cust_tax_reg_id,
                                                               'INV',
                                                               'EN',
                                                               a.header_id),
                                   get_legal_text (a.att2,
                                                   a.att3,
                                                   a.comp_tax_reg_id,
                                                   a.cust_tax_reg_id,
                                                   'NONINV',
                                                   'EN',
                                                   a.header_id))),*/
                             -- End of Change
                             XMLELEMENT ("COMPANY_TELEPHONE", a.comp_telephone),
                             XMLELEMENT ("CUSTOMER_TAX_REG_ID",
                                         a.cust_tax_reg_id),
                             XMLELEMENT ("SHIP_TO_ADDRESS", a.SHIP_TO_ADDRESS) --,XMLELement("CUSTOMER_TAX_REF",a.cust_tax_ref) -- Commented as per defect 1879
                                                                              ,
                             XMLELEMENT ("CUSTOMER_TAX_REF", c.attribute5) -- Added as per defect 1879
                                                                          ,
                             XMLELEMENT ("CUSTOMER_BT_DESC", a.cust_BT_desc),
                             XMLELEMENT ("CUSTOMER_BT_TELEPHONE",
                                         a.cust_BT_telephone),
                             XMLELEMENT ("CUSTOMER_ST_DESC", a.cust_ST_desc),
                             XMLELEMENT ("CUSTOMER_ST_TELEPHONE",
                                         a.cust_ST_telephone),
                             XMLELEMENT ("INVOICE_CURRENCY", a.inv_currency),
                             XMLELEMENT ("PAY_TERMS", a.Pay_Terms),
                             XMLELEMENT ("INTERCOMPANY_TERMS",
                                         a.Int_Comp_Terms),
                             XMLELEMENT ("LEGAL_TEXT", a.legal_text),
                             XMLELEMENT ("ATTRIBUTE1", a.att1),
                             XMLELEMENT ("ATTRIBUTE2", a.att2),
                             XMLELEMENT ("ATTRIBUTE3", a.att3),
                             XMLELEMENT ("ATTRIBUTE4", a.att4),
                             XMLELEMENT ("ATTRIBUTE5", a.att5),
                             XMLELEMENT ("ATTRIBUTE6", a.att6),
                             XMLELEMENT ("ATTRIBUTE7", a.att7),
                             XMLELEMENT ("ATTRIBUTE8", a.att8),
                             XMLELEMENT ("ATTRIBUTE9", a.att9),
                             XMLELEMENT ("ATTRIBUTE10", a.att10),
                             XMLELEMENT ("ATTRIBUTE11", a.att11),
                             XMLELEMENT ("ATTRIBUTE12", a.att12),
                             XMLELEMENT ("ATTRIBUTE13", a.att13),
                             XMLELEMENT ("ATTRIBUTE14", a.att14),
                             XMLELEMENT ("ATTRIBUTE15", a.att15),
                             XMLELEMENT ("ATTRIBUTE16", a.att16),
                             XMLELEMENT ("ATTRIBUTE17", a.att17),
                             XMLELEMENT ("ATTRIBUTE18", a.att18),
                             XMLELEMENT ("ATTRIBUTE19", a.att19),
                             XMLELEMENT ("ATTRIBUTE30", a.att20),
                             XMLAGG (XMLELEMENT (
                                         "INVOICE_LINE",
                                         XMLELEMENT ("INVOICE_NUMBER",
                                                     b.INVOICE_NUMBER),
                                         XMLELEMENT ("VOUCHER_NUMBER",
                                                     b.VOUCHER_NUMBER),
                                         XMLELEMENT (
                                             "INVOICE_DATE",
                                             TO_CHAR (b.INVOICE_DATE,
                                                      'DD-MON-YYYY')),
                                         XMLELEMENT ("PO_NUMBER", b.Po_Number),
                                         XMLELEMENT ("SO_NUMBER", b.So_Number),
                                         XMLELEMENT (
                                             "INV_NUM",
                                             DECODE (
                                                 get_source (a.header_id),
                                                 'Material Transactions', get_so_ar_number (
                                                                              b.att1),
                                                 NULL)),
                                         XMLELEMENT (
                                             "SO_NUM",
                                             DECODE (
                                                 get_source (a.header_id),
                                                 'Material Transactions', get_so_cust_po (
                                                                              b.att1,
                                                                              'SO'),
                                                 NULL)),
                                         XMLELEMENT (
                                             "PO_NUM",
                                             DECODE (
                                                 get_source (a.header_id),
                                                 'Material Transactions', get_so_cust_po (
                                                                              b.att1,
                                                                              'PO'),
                                                 NULL)),
                                         XMLELEMENT ("PAYMENT_TERM",
                                                     b.Payment_Term),
                                         XMLELEMENT (
                                             "DUE_DATE",
                                             TO_CHAR (b.Due_Date,
                                                      'DD-MON-YYYY')),
                                         XMLELEMENT ("PAID_FLAG", b.Paid_Flag) -- ,XMLElement("SETTLEMENT_DATE",b.Settlement_Date)
                                                                              ,
                                         XMLELEMENT ("DUE_DATE", b.due_date),
                                         XMLELEMENT ("LINE", b.line_no),
                                         XMLELEMENT ("UOM", b.uom),
                                         XMLELEMENT ("QTY", b.quantity),
                                         XMLELEMENT ("PART_NUMBER",
                                                     b.item_number),
                                         XMLELEMENT ("DESCRIPTION", b.Item),
                                         XMLELEMENT ("TAX_CODE", b.tax_code),
                                         XMLELEMENT ("NEW_TAX_RATE",
                                                     NVL (b.tax_rate, 0)),
                                         XMLELEMENT (
                                             "SHIP_FROM",
                                             get_so_ship_to (b.att1,
                                                             a.header_id)), -- Added as per CCR0009071
                                         XMLELEMENT (
                                             "SHIP_TO",
                                             get_valid_data_display_fnc (
                                                 a.header_id,
                                                 'WH')), -- Added as per CCR0009071
                                         XMLELEMENT (
                                             "SHIP_FROM_VAT",
                                             get_ship_vat (
                                                 a.att3,
                                                 get_so_ship_to (b.att1,
                                                                 a.header_id,
                                                                 'CNTRY'))), -- Added as per CCR0009071
                                         XMLELEMENT (
                                             "SHIP_TO_VAT",
                                             get_ship_vat (
                                                 a.att2,
                                                 get_valid_data_display_fnc (
                                                     a.header_id,
                                                     'WH',
                                                     'CNTRY'))), -- Added as per CCR0009071
                                         --2.4 changes start
                                         /*XMLELEMENT (
                                            "TAX_CODE_INV",
                                            get_tax_codes_vt_new (
                                               (DECODE (get_source (a.header_id),
                                                        'Material Transactions', 'INV',
                                                        'NONINV')),
                                               get_lang (a.att2),
                                               a.att2,
                                               a.att3,
                                               get_cust_classification (b.att1,
                                                                        'ORG',
                                                                        a.header_id),
                                               get_cust_classification (b.att1,
                                                                        'CLASS',
                                                                        a.header_id),
                                               UPPER (
                                                  get_ship_from_country_code (
                                                     --get_ship_to (a.header_id, a.att3)
                                                     get_so_ship_to (b.att1, a.header_id) --2.3
                                                                                         )),
                                               get_eu_non_eu (
                                                  --get_ship_to (a.header_id, a.att3)
                                                  get_so_ship_to (b.att1, a.header_id) --2.3
                                                                                      ),
                                               UPPER (
                                                  get_ship_from_country_code (
                                                     get_ship_from (a.header_id, a.att3))),
                                               DECODE (
                                                  get_source (a.header_id),
                                                  'Material Transactions', get_so_line_id (
                                                                              b.att1,
                                                                              a.header_id),
                                                  NULL))),
                                         XMLELEMENT (
                                            "TAX_DESC_INV",
                                            DECODE (
                                               (get_tax_codes_vt_new (
                                                   (DECODE (
                                                       get_source (a.header_id),
                                                       'Material Transactions', 'INV',
                                                       'NONINV')),
                                                   get_lang (a.att2),
                                                   a.att2,
                                                   a.att3,
                                                   get_cust_classification (b.att1,
                                                                            'ORG',
                                                                            a.header_id),
                                                   get_cust_classification (b.att1,
                                                                            'CLASS',
                                                                            a.header_id),
                                                   UPPER (
                                                      get_ship_from_country_code (
                                                         --get_ship_to (a.header_id, a.att3)
                                                         get_so_ship_to (b.att1,
                                                                         a.header_id) --2.3
                                                                                     )),
                                                   get_eu_non_eu (
                                                      --get_ship_to (a.header_id, a.att3)
                                                      get_so_ship_to (b.att1, a.header_id) --2.3
                                                                                          ),
                                                   UPPER (
                                                      get_ship_from_country_code (
                                                         get_ship_from (a.header_id,
                                                                        a.att3))),
                                                   DECODE (
                                                      get_source (a.header_id),
                                                      'Material Transactions', get_so_line_id (
                                                                                  b.att1,
                                                                                  a.header_id),
                                                      NULL))),
                                               'T0', 'Zero rated',
                                               'T1', 'Standard rated',
                                               'T2', 'Out of scope')),
                                         --2.4 changes end

                                         XMLELEMENT (
                                            "INCO_CODE_INV",
                                            get_inco_codes_vt_new (
                                               (DECODE (get_source (a.header_id),
                                                        'Material Transactions', 'INV',
                                                        'NONINV')),
                                               get_lang (a.att2),
                                               a.att2,
                                               a.att3,
                                               get_cust_classification (b.att1,
                                                                        'ORG',
                                                                        a.header_id),
                                               get_cust_classification (b.att1,
                                                                        'CLASS',
                                                                        a.header_id),
                                               UPPER (
                                                  get_ship_from_country_code (
                                                     --get_ship_to (a.header_id, a.att3)
                                                     get_so_ship_to (b.att1, a.header_id) --2.3
                                                                                         )),
                                               get_eu_non_eu (
                                                  --get_ship_to (a.header_id, a.att3)
                                                  get_so_ship_to (b.att1, a.header_id) --2.3
                                                                                      ),
                                               UPPER (
                                                  get_ship_from_country_code (
                                                     get_ship_from (a.header_id, a.att3))))),
                                         XMLELEMENT (
                                            "TAX_STMT_INV",
                                            get_tax_stamt_vt_new (
                                               (DECODE (get_source (a.header_id),
                                                        'Material Transactions', 'INV',
                                                        'NONINV')),
                                               get_lang (a.att2),
                                               a.att2,
                                               a.att3,
                                               get_cust_classification (b.att1,
                                                                        'ORG',
                                                                        a.header_id),
                                               get_cust_classification (b.att1,
                                                                        'CLASS',
                                                                        a.header_id),
                                               UPPER (
                                                  get_ship_from_country_code (
                                                     --get_ship_to (a.header_id, a.att3)
                                                     get_so_ship_to (b.att1, a.header_id) --2.3
                                                                                         )),
                                               get_eu_non_eu (
                                                  --get_ship_to (a.header_id, a.att3)
                                                  get_so_ship_to (b.att1, a.header_id) --2.3
                                                                                      ),
                                               UPPER (
                                                  get_ship_from_country_code (
                                                     get_ship_from (a.header_id, a.att3))))) */
                                         -- CCR0007979 - Macau changes end
                                         --                                                                                 ,
                                         XMLELEMENT ("INVOICE_CLASS",
                                                     c.invoice_class), --CCR0008987
                                         XMLELEMENT (
                                             "VALID_DATA",
                                             get_valid_data_display_fnc (
                                                 a.header_id)),   --CCR0008987
                                         XMLELEMENT ("UNIT_PRICE",
                                                     b.UNIT_PRICE),
                                         XMLELEMENT ("TOTAL_AMOUNT",
                                                     b.Extended_Amount),
                                         XMLELEMENT ("TAX_AMOUNT",
                                                     b.TAX_AMOUNT),
                                         XMLELEMENT ("LINE_AMOUNT",
                                                     b.Line_Amount),
                                         XMLELEMENT ("PRODUCT_FAMILY",
                                                     b.product_family),
                                         XMLELEMENT ("ATTRIBUTE1", b.att1),
                                         XMLELEMENT ("ATTRIBUTE2", b.att2),
                                         XMLELEMENT ("ATTRIBUTE3", b.att3),
                                         XMLELEMENT ("ATTRIBUTE4", b.att4),
                                         XMLELEMENT ("ATTRIBUTE5", b.att5),
                                         XMLELEMENT ("ATTRIBUTE6", b.att6),
                                         XMLELEMENT ("ATTRIBUTE7", b.att7),
                                         XMLELEMENT ("ATTRIBUTE8", b.att8),
                                         XMLELEMENT ("ATTRIBUTE9", b.att9),
                                         XMLELEMENT ("ATTRIBUTE10", b.att10),
                                         XMLELEMENT ("ATTRIBUTE11", b.att11),
                                         XMLELEMENT ("ATTRIBUTE12", b.att12),
                                         XMLELEMENT ("ATTRIBUTE13", b.att13),
                                         XMLELEMENT ("ATTRIBUTE14", b.att14),
                                         XMLELEMENT ("ATTRIBUTE15", b.att15),
                                         XMLELEMENT ("ATTRIBUTE16", b.att16),
                                         XMLELEMENT ("ATTRIBUTE17", b.att17),
                                         XMLELEMENT ("ATTRIBUTE18", b.att18),
                                         XMLELEMENT ("ATTRIBUTE19", b.att19),
                                         XMLELEMENT ("ATTRIBUTE30", b.att20))
                                     ORDER BY b.invoice_number, TO_NUMBER (b.line_no)),
                             XMLELEMENT (
                                 "HEADER_TOTAL",
                                 (  SELECT XMLAGG (
                                               XMLELEMENT (
                                                   "TOTAL",
                                                   XMLFOREST ( --c.TAX_CODE tax_code
                                                       -- ,
                                                       c.ic_currency curr --, c.tax_rate
                                                                         ,
                                                       SUM (
                                                           c.Unit_Price * c.quantity)
                                                           net_price_tot,
                                                       SUM (
                                                           c.TAX_AMOUNT * c.quantity)
                                                           tax_amount_tot,
                                                       SUM (c.quantity) total_qty,
                                                       SUM (c.Unit_Price)
                                                           tot_price))) -- added sum(c.quantity) as a latest change
                                      FROM xxcp_instance_ic_inv_v c, xxcp_instance_ic_inv_comp_v d
                                     WHERE     c.invoice_header_id = d.header_id
                                           AND c.invoice_header_id = a.header_id
                                           AND c.att10 <> 'T'
                                  GROUP BY                       --c.tax_code,
                                           c.ic_currency         --,c.tax_rate
                                                        )) -- CCR0007979 - Macau changes start
                                                          ,
                             XMLELEMENT (
                                 "NEW_TAX_LOGIC",
                                 (  SELECT XMLAGG (
                                               XMLELEMENT (
                                                   "NEW_LOGIC",
                                                   XMLFOREST (
                                                       NVL (c.tax_rate, 0)
                                                           tax_rate1,
                                                       SUM (
                                                           c.Unit_Price * c.quantity)
                                                           NET,
                                                       SUM (c.TAX_AMOUNT)
                                                           tax_amount_tot,
                                                       get_valid_data_display_fnc (
                                                           d.header_id)
                                                           VALID_DATA, -- CCR0009071
                                                       get_so_ship_to (
                                                           c.att1,
                                                           d.header_id) SHIP_FROM, -- Added as per CCR0009071
                                                       get_valid_data_display_fnc (
                                                           d.header_id,
                                                           'WH') SHIP_TO, -- Added as per CCR0009071
                                                       --2.4 changes start
                                                       /*get_tax_codes_vt_new (
                                                          (DECODE (
                                                              get_source (d.header_id),
                                                              'Material Transactions', 'INV',
                                                              'NONINV')),
                                                          get_lang (d.att2),
                                                          d.att2,
                                                          d.att3,
                                                          get_cust_classification (
                                                             c.att1,
                                                             'ORG',
                                                             d.header_id),
                                                          get_cust_classification (
                                                             c.att1,
                                                             'CLASS',
                                                             d.header_id),
                                                          UPPER (
                                                             get_ship_from_country_code (
                                                                --get_ship_to (d.header_id, d.att3)
                                                                get_so_ship_to (
                                                                   c.att1,
                                                                   d.header_id)   --2.3
                                                                               )),
                                                          get_eu_non_eu (
                                                             --get_ship_to (d.header_id, d.att3)
                                                             get_so_ship_to (c.att1,
                                                                             d.header_id) --2.3
                                                                                         ),
                                                          UPPER (
                                                             get_ship_from_country_code (
                                                                get_ship_from (
                                                                   d.header_id,
                                                                   d.att3))),
                                                          get_so_line_id (c.att1,
                                                                          d.header_id)) TAX_CODE_NEW,
                                                       DECODE (
                                                          (get_tax_codes_vt_new (
                                                              (DECODE (
                                                                  get_source (d.header_id),
                                                                  'Material Transactions', 'INV',
                                                                  'NONINV')),
                                                              get_lang (d.att2),
                                                              d.att2,
                                                              d.att3,
                                                              get_cust_classification (
                                                                 c.att1,
                                                                 'ORG',
                                                                 d.header_id),
                                                              get_cust_classification (
                                                                 c.att1,
                                                                 'CLASS',
                                                                 d.header_id),
                                                              UPPER (
                                                                 get_ship_from_country_code (
                                                                    --get_ship_to (d.header_id, d.att3)
                                                                    get_so_ship_to (
                                                                       c.att1,
                                                                       d.header_id) --2.3
                                                                                   )),
                                                              get_eu_non_eu (
                                                                 --get_ship_to (d.header_id, d.att3)
                                                                 get_so_ship_to (
                                                                    c.att1,
                                                                    d.header_id)  --2.3
                                                                                ),
                                                              UPPER (
                                                                 get_ship_from_country_code (
                                                                    get_ship_from (
                                                                       d.header_id,
                                                                       d.att3))),
                                                              get_so_line_id (c.att1,
                                                                              d.header_id))),
                                                          'T0', 'Zero rated',
                                                          'T1', 'Standard rated',
                                                          'T2', 'Out of scope') TAX_DESC_NEW,*/
                                                       -- 2.4 changes end
                                                       SUM (
                                                             (c.Unit_Price * c.quantity)
                                                           * (NVL (c.tax_rate, 0)))
                                                           TAX_AMOUNT1,
                                                       SUM (
                                                             (c.Unit_Price * c.quantity)
                                                           + ((c.Unit_Price * c.quantity) * (NVL (c.tax_rate, 0))))
                                                           GOODS_VAT))) -- added sum(c.quantity) as a latest change
                                      FROM xxcp_instance_ic_inv_v c, xxcp_instance_ic_inv_comp_v d
                                     WHERE     c.invoice_header_id = d.header_id
                                           AND c.invoice_header_id = a.header_id
                                           AND c.att10 <> 'T'
                                  GROUP BY NVL (c.tax_rate, 0), d.att2, d.att3,
                                           c.att1, d.header_id --2.4 changes start
 /*get_tax_codes_vt_new (
    (DECODE (
        get_source (d.header_id),
        'Material Transactions', 'INV',
        'NONINV')),
    get_lang (d.att2),
    d.att2,
    d.att3,
    get_cust_classification (c.att1,
                             'ORG',
                             d.header_id),
    get_cust_classification (c.att1,
                             'CLASS',
                             d.header_id),
    UPPER (
       get_ship_from_country_code (
          --get_ship_to (d.header_id, d.att3)
          get_so_ship_to (c.att1,
                          d.header_id) --2.3
                                      )),
    get_eu_non_eu (
       --get_ship_to (d.header_id, d.att3)
       get_so_ship_to (c.att1, d.header_id) --2.3
                                           ),
    UPPER (
       get_ship_from_country_code (
          get_ship_from (d.header_id,
                         d.att3))),
    get_so_line_id (c.att1, d.header_id)),
 DECODE (
    (get_tax_codes_vt_new (
        (DECODE (
            get_source (d.header_id),
            'Material Transactions', 'INV',
            'NONINV')),
        get_lang (d.att2),
        d.att2,
        d.att3,
        get_cust_classification (
           c.att1,
           'ORG',
           d.header_id),
        get_cust_classification (
           c.att1,
           'CLASS',
           d.header_id),
        UPPER (
           get_ship_from_country_code (
              --get_ship_to (d.header_id, d.att3)
              get_so_ship_to (c.att1,
                              d.header_id) --2.3
                                          )),
        get_eu_non_eu (
           --get_ship_to (d.header_id, d.att3)
           get_so_ship_to (c.att1,
                           d.header_id) --2.3
                                       ),
        UPPER (
           get_ship_from_country_code (
              get_ship_from (d.header_id,
                             d.att3))),
        get_so_line_id (c.att1,
                        d.header_id))),
    'T0', 'Zero rated',
    'T1', 'Standard rated',
    'T2', 'Out of scope')*/
                                 ))                         -- 2.4 changes end
                                   -- CCR0007979 - Macau changes end
                                   ))).getClobVal () xml
            INTO vClob
            FROM xxcp_instance_ic_inv_comp_v a, xxcp_instance_ic_inv_v b, xxcp_ic_inv_header c
           WHERE     a.header_id = b.invoice_header_id
                 AND c.invoice_header_id = b.invoice_header_id
                 AND NVL (a.comp_tax_REG_ID, 0) =
                     NVL (cInvoiceTaxReg, NVL (a.comp_tax_reg_id, 0))
                 AND NVL (a.cust_tax_reg_id, 0) =
                     NVL (cCustomerTaxReg, NVL (a.cust_tax_reg_id, 0))
                 AND NVL (b.Po_Number, '~null~') =
                     NVL (cPurchase_Order, NVL (b.Po_Number, '~null~'))
                 AND NVL (b.So_Number, '~null~') =
                     NVL (cSales_Order, NVL (b.So_Number, '~null~'))
                 AND NVL (b.product_family, '~null~') =
                     NVL (cProduct_Family, NVL (b.product_family, '~null~'))
                 AND TRUNC (b.INVOICE_DATE) BETWEEN NVL (
                                                        TO_DATE (
                                                            cInvoice_Date_Low,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        TRUNC (b.INVOICE_DATE))
                                                AND NVL (
                                                        TO_DATE (
                                                            cInvoice_Date_High,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        TRUNC (b.INVOICE_DATE))
                 AND NVL (b.INVOICE_NUMBER, '~null~') BETWEEN NVL (
                                                                  cInvoice_Number_from,
                                                                  NVL (
                                                                      b.INVOICE_NUMBER,
                                                                      '~null~'))
                                                          AND NVL (
                                                                  cInvoice_Number_to,
                                                                  NVL (
                                                                      b.INVOICE_NUMBER,
                                                                      '~null~'))
                 AND a.INVOICE_TYPE =
                     NVL (cInvoiceType, NVL (a.Invoice_Type, '~null~'))
                 AND NVL (a.printed_flag, 'N') =
                     DECODE (SUBSTR (cUnPrinted_Flag, 1, 1),
                             'Y', 'N',
                             a.printed_flag)
                 AND NVL (a.release_invoice, 'Y') = 'Y'
                 -- Start of Change CCR0009071
                 AND EXISTS
                         (SELECT 1
                            FROM apps.xxcp_mtl_material_transactions xmmt, apps.xxcp_process_history xph, apps.xxcp_ic_inv_lines xil
                           WHERE     1 = 1
                                 AND xmmt.vt_interface_id = xph.interface_id
                                 AND xph.process_history_id =
                                     xil.process_history_id
                                 AND xil.invoice_header_id =
                                     c.invoice_header_id
                                 AND xmmt.attribute2 IN
                                         ('Return Diff OU Collector', 'Return RMA Same OU Collector')
                                 AND xmmt.vt_transaction_type = 'Return')
                 AND EXISTS
                         (SELECT xtr.*
                            FROM xxcp_tax_registrations xtr, xxcp_entity_associations xea
                           WHERE     1 = 1
                                 AND xtr.tax_registration_id =
                                     c.customer_tax_reg_id
                                 AND xtr.reg_id = xea.reg_id
                                 AND xea.location_ref = c.attribute3
                                 AND xea.trading_entity_type = 'Partner')
                 AND get_valid_data_display_fnc (a.header_id) = 'VALID'
        -- End of Change for CCR0009071
        GROUP BY a.header_id, c.invoice_address_id, c.attribute4 -- Added as per defect 1879
                                                                ,
                 c.attribute5                      -- Added as per defect 1879
                             , a.comp_tax_reg_id --,a.comp_tax_ref  -- Commented as per defect 1879
                                                , a.comp_Desc --,a.BILL_TO_ADDRESS
                                                             ,
                 a.comp_telephone, a.cust_tax_reg_id, a.SHIP_TO_ADDRESS --,a.cust_tax_ref    -- Commented as per defect 1879
                                                                       ,
                 a.cust_BT_desc, a.cust_BT_telephone, a.cust_ST_desc,
                 a.cust_ST_telephone, a.inv_currency, a.pay_terms,
                 a.Int_Comp_Terms, a.Legal_Text, a.att1,
                 a.att2, a.att3, a.att4,
                 a.att5, a.att6, a.att7,
                 a.att8, a.att9, a.att10,
                 a.att11, a.att12, a.att13,
                 a.att14, a.att15, a.att16,
                 a.att17, a.att18, a.att19,
                 a.att20, c.invoice_class, c.customer_tax_reg_id,
                 c.attribute3
        --,b.att1
        ORDER BY b.invoice_number, TO_NUMBER (b.line_no);

        --       Update the printed information for the header
        UPDATE xxcp_ic_inv_header a
           SET printed_flag = 'Y', printed_counter = printed_counter + 1, last_printed_date = SYSDATE
         WHERE     NVL (a.invoice_tax_REG_ID, 0) =
                   NVL (cInvoiceTaxReg, NVL (a.invoice_tax_reg_id, 0))
               AND NVL (a.customer_tax_reg_id, 0) =
                   NVL (cCustomerTaxReg, NVL (a.customer_tax_reg_id, 0))
               AND a.invoice_header_id IN
                       (SELECT b.invoice_header_id
                          FROM xxcp_instance_ic_inv_v b
                         WHERE     NVL (b.Po_Number, '~null~') =
                                   NVL (cPurchase_Order,
                                        NVL (b.Po_Number, '~null~'))
                               AND NVL (b.So_Number, '~null~') =
                                   NVL (cSales_Order,
                                        NVL (b.So_Number, '~null~'))
                               AND NVL (b.product_family, '~null~') =
                                   NVL (cProduct_Family,
                                        NVL (b.product_family, '~null~'))
                               AND a.printed_flag =
                                   DECODE (SUBSTR (cUnprinted_Flag, 1, 1),
                                           'Y', 'N',
                                           a.printed_flag)
                               AND NVL (a.release_invoice, 'Y') = 'Y'
                               AND NVL (b.invoice_number, '~null~') BETWEEN NVL (
                                                                                cInvoice_Number_From,
                                                                                NVL (
                                                                                    b.invoice_number,
                                                                                    '~null~'))
                                                                        AND NVL (
                                                                                cInvoice_Number_To,
                                                                                NVL (
                                                                                    b.invoice_number,
                                                                                    '~null~'))
                               AND a.INVOICE_DATE BETWEEN NVL (
                                                              TO_DATE (
                                                                  cInvoice_Date_Low,
                                                                  'YYYY/MM/DD HH24:MI:SS'),
                                                              TRUNC (
                                                                  b.INVOICE_DATE))
                                                      AND NVL (
                                                              TO_DATE (
                                                                  cInvoice_Date_High,
                                                                  'YYYY/MM/DD HH24:MI:SS'),
                                                              TRUNC (
                                                                  b.INVOICE_DATE)))
               -- OOD-641 ensure header is present in xxcp_instance_ic_inv_comp_v view (complete with address details)
               AND a.invoice_header_id IN
                       (SELECT c.header_id
                          FROM xxcp_instance_ic_inv_comp_v c
                         WHERE     NVL (a.invoice_tax_reg_id, 0) =
                                   NVL (cInvoiceTaxReg,
                                        NVL (c.comp_tax_reg_id, 0))
                               AND NVL (a.customer_tax_reg_id, 0) =
                                   NVL (cCustomerTaxReg,
                                        NVL (c.cust_tax_reg_id, 0)));

        -- OOD-641 issue warning for records not printed due to lack of address
        vCounter   := 0;

        FOR rec IN curNotPrinted (cInvoiceTaxReg, cCustomerTaxReg, cPurchase_Order, cSales_Order, cProduct_Family, cUnprinted_Flag, cInvoice_Date_Low, cInvoice_Date_High, cInvoice_Number_From
                                  , cInvoice_Number_To)
        LOOP
            vCounter   := vCounter + 1;

            IF vCounter = 1
            THEN
                fnd_file.put_line (fnd_file.LOG, '');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'WARNING - The following selected headers were not printed (no address details):');
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Header ID: '
                || rec.invoice_header_id
                || ', Company Tax Reg: '
                || rec.invoice_tax_reg_id
                || ', Customer Tax Reg: '
                || rec.customer_tax_reg_id);
        END LOOP;

        IF vCounter != 0
        THEN
            vDummy   :=
                fnd_concurrent.set_completion_status (
                    'WARNING',
                    'Some header records had no address details defined.');
        END IF;

        -- Send the XML output back
        printClobOut (cClob => vClob, cHeader_Req => 'Y');
    END IC_Invoice;
END XXD_VT_ICS_BE_INVOICES_PKG;
/
