--
-- XXD_P2P_INTRASTAT_MTD_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_P2P_INTRASTAT_MTD_REP_PKG"
AS
    /****************************************************************************************
     * Package      : XXD_MTD_REPORTD_PKG
     * Design       : This package will be used for MTD Reports
     * Notes        :
     * Modification :
     -- =====================================================================================
     -- Date         Version#   Name                    Comments
     -- =====================================================================================
     -- 14-Aug-2020  1.0        Tejaswi Gangumalla      Initial Version
     -- 06-Oct-2021  1.1        Aravind Kannuri         Modified for CCR0009638
     -- 12-OCT-2021  1.1        Showkath Ali            Modified for CCR0009638
     -- 23-AUG-2022  1.2        Srinath Siricilla       CCR0009857
    *****************************************************************************************/
    FUNCTION get_nature_transaction (pv_type IN VARCHAR2, trx_line_id IN NUMBER, pv_invoice_type IN VARCHAR2)
        RETURN VARCHAR2
    AS
        lv_transaction   VARCHAR2 (20);
        lv_sales_order   VARCHAR2 (20);
        ln_line_number   NUMBER;
        lv_type          VARCHAR2 (100);
        ln_amount        NUMBER;
    BEGIN
        IF pv_type = 'AP'
        THEN
            IF NVL (pv_invoice_type, 'XXX') = 'CREDIT'
            THEN
                lv_transaction   := 16;
            ELSE
                lv_transaction   := 10;
            END IF;
        ELSIF pv_type = 'AR'
        THEN
            IF NVL (pv_invoice_type, 'XXX') = 'Credit Memo'
            THEN
                lv_transaction   := 16;
            ELSE
                BEGIN
                    SELECT sales_order, sales_order_line, extended_amount
                      INTO lv_sales_order, ln_line_number, ln_amount
                      FROM ra_customer_trx_lines_all
                     WHERE     sales_order_line IS NOT NULL
                           AND customer_trx_line_id = trx_line_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_transaction   := 10;
                END;

                IF ln_amount = 0
                THEN
                    lv_transaction   := 30;
                ELSE
                    BEGIN
                        SELECT line_category_code
                          INTO lv_type
                          FROM oe_order_lines_all
                         WHERE     line_number = ln_line_number
                               AND header_id =
                                   (SELECT header_id
                                      FROM oe_order_headers_all
                                     WHERE order_number = lv_sales_order);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_transaction   := 10;
                    END;

                    IF lv_type = 'RETURN'
                    THEN
                        lv_transaction   := 20;
                    ELSE
                        lv_transaction   := 10;
                    END IF;
                END IF;
            END IF;
        END IF;

        RETURN lv_transaction;
    END;

    FUNCTION get_inco_code (pn_sales_header_id IN NUMBER)
        RETURN VARCHAR2
    AS
        lv_template_type            VARCHAR2 (5) := 'INV';                --p1
        lv_lang                     VARCHAR2 (5) := 'EN';                 --p2
        ln_ship_from_org_id         NUMBER;
        ln_seller_comp              NUMBER;                               --p3
        ln_ship_to_org_id           NUMBER;
        ln_site_use_id              NUMBER;
        ln_buyer_comp               NUMBER;                               --p4
        lv_channel                  VARCHAR2 (200);                       --p6
        lv_so_ship_to               VARCHAR2 (200);
        lv_ship_to_country          VARCHAR2 (200);                       --p7
        ln_count                    NUMBER;
        ln_req_header_id            NUMBER;
        lv_eu_non_eu                VARCHAR2 (200);                       --p8
        ln_ship_from_country_code   VARCHAR2 (200);                       --p9
        ln_ship_from_country        VARCHAR2 (200);
        ln_org_id                   NUMBER;
        ln_dest_org_id              NUMBER;
        lv_into_code                VARCHAR2 (200);
        ln_deliver_loc_id           NUMBER;
    BEGIN
        BEGIN
            SELECT ship_from_org_id, ship_to_org_id, source_document_id,
                   org_id
              INTO ln_ship_from_org_id, ln_site_use_id, ln_req_header_id, ln_org_id
              FROM oe_order_headers_all
             WHERE header_id = pn_sales_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ship_from_org_id   := NULL;
        END;

        BEGIN
            SELECT glev.flex_segment_value
              INTO ln_seller_comp
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
                   AND hroutl_ou.LANGUAGE = 'US'
                   AND hroutl_ou.organization_id = ln_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_seller_comp   := NULL;
        END;

        BEGIN
            SELECT destination_organization_id, org_id, deliver_to_location_id
              INTO ln_ship_to_org_id, ln_dest_org_id, ln_deliver_loc_id
              FROM po_requisition_lines_all
             WHERE requisition_header_id = ln_req_header_id AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ship_to_org_id   := NULL;
        END;

        BEGIN
            SELECT glev.flex_segment_value
              INTO ln_buyer_comp
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
                   AND hroutl_ou.LANGUAGE = 'US'
                   AND hroutl_ou.organization_id = ln_dest_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_buyer_comp   := NULL;
        END;

        BEGIN
            SELECT DECODE (hca.customer_class_code, 'INTERNAL', 'DC TO DC', hca.customer_class_code)
              INTO lv_channel
              FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha, apps.hz_cust_accounts hca
             WHERE     1 = 1
                   AND oola.header_id = ooha.header_id
                   AND ooha.sold_to_org_id = hca.cust_account_id
                   AND ooha.header_id = pn_sales_header_id
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_channel   := NULL;
        END;

        BEGIN
            SELECT ftv.iso_territory_code
              INTO lv_so_ship_to
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
                   AND ooh.header_id = pn_sales_header_id
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_so_ship_to   := NULL;
        END;

        BEGIN
            SELECT UPPER (territory_short_name)
              INTO lv_ship_to_country
              FROM fnd_territories_vl
             WHERE iso_territory_code = lv_so_ship_to;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ship_to_country   := NULL;
        END;

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
               AND ftv.iso_territory_code = lv_so_ship_to;

        IF ln_count > 0
        THEN
            lv_eu_non_eu   := 'EU';
        ELSE
            lv_eu_non_eu   := 'Non-EU';
        END IF;

        BEGIN
            SELECT hou.country
              INTO ln_ship_from_country_code
              FROM org_organization_definitions ood, hr_organization_units_v hou
             WHERE     ood.disable_date IS NULL
                   AND ood.organization_id = hou.organization_id
                   AND ood.organization_id = ln_ship_from_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ship_from_country_code   := NULL;
        END;

        BEGIN
            SELECT UPPER (territory_short_name)
              INTO ln_ship_from_country
              FROM fnd_territories_vl
             WHERE territory_code = ln_ship_from_country_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ship_from_country   := NULL;
        END;

        IF     lv_ship_to_country IS NOT NULL
           AND ln_ship_from_country IS NOT NULL
        THEN
            BEGIN
                SELECT DISTINCT inco_term
                  INTO lv_into_code
                  FROM (SELECT inco_term
                          FROM (SELECT attribute1 template_type, attribute2 LANGUAGE, attribute3 seller_company,
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
                               AND template_type = lv_template_type
                               AND LANGUAGE = lv_lang
                               AND seller_company = ln_seller_comp
                               AND buyer_company = ln_buyer_comp
                               AND final_selling_company = ln_seller_comp
                               AND UPPER (channel) = UPPER (lv_channel)
                               AND CASE
                                       WHEN NVL (ln_ship_from_country, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ln_ship_from_country,
                                                     '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END =
                                   CASE
                                       WHEN NVL (ln_ship_from_country, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ln_ship_from_country,
                                                     '111') <>
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
                                        WHEN (NVL (lv_ship_to_country, '111') = NVL (ship_to_equal, '111') OR (NVL (lv_eu_non_eu, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))
                                        THEN
                                            NVL (ship_to_equal, '111')
                                        WHEN ((NVL (lv_ship_to_country, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))-- OR (DECODE(pv_ship_to,ship_to_unequal,ship_to_unequal,NVL(pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA' ) AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')
                                                                                                                                                                                                            )
                                        THEN
                                            NVL (ship_to_unequal, '111')
                                    END =
                                    CASE
                                        WHEN (NVL (lv_ship_to_country, '111') = NVL (ship_to_equal, '111') OR (NVL (lv_eu_non_eu, '111') = NVL (ship_to_equal, '111') AND ship_to_equal = 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))
                                        THEN
                                            NVL (ship_to_equal, '111')
                                        WHEN ((NVL (lv_ship_to_country, '111') <> NVL (ship_to_unequal, '111') AND ship_to_unequal NOT IN ('NA', 'EU') AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA'))--OR (DECODE(pv_ship_to,ship_to_unequal,ship_to_unequal,NVL(pv_ship_to_reg, '111')) <> ship_to_unequal AND ship_to_unequal <> 'NA' ) AND (ship_to_equal = 'NA' OR ship_to_unequal = 'NA')
                                                                                                                                                                                                            )
                                        THEN
                                            NVL (ship_to_unequal, '111')
                                    END)
                        UNION ALL
                        SELECT inco_term
                          FROM (SELECT attribute1 template_type, attribute2 LANGUAGE, attribute3 seller_company,
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
                               AND template_type = lv_template_type
                               AND LANGUAGE = lv_lang
                               AND seller_company = ln_seller_comp
                               AND buyer_company = ln_buyer_comp
                               AND final_selling_company = ln_seller_comp
                               AND UPPER (channel) = UPPER (lv_channel)
                               AND CASE
                                       WHEN NVL (ln_ship_from_country, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ln_ship_from_country,
                                                     '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END =
                                   CASE
                                       WHEN NVL (ln_ship_from_country, '111') =
                                            NVL (ship_from_equal, '111')
                                       THEN
                                           NVL (ship_from_equal, '111')
                                       WHEN     NVL (ln_ship_from_country,
                                                     '111') <>
                                                NVL (ship_from_unequal,
                                                     '111')
                                            AND ship_from_unequal <> 'NA'
                                       THEN
                                           NVL (ship_from_unequal, '111')
                                   END
                               AND (lv_eu_non_eu = ship_to_equal AND ship_to_unequal NOT LIKE '%' || lv_ship_to_country || '%' AND (ship_to_equal <> 'NA' AND ship_to_unequal <> 'NA') OR (lv_eu_non_eu <> ship_to_unequal AND (ship_to_equal = 'NA' OR ship_to_unequal = 'EU'))));

                RETURN lv_into_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_into_code   := NULL;
                    RETURN lv_into_code;
            END;
        ELSE
            lv_into_code   := NULL;
            RETURN lv_into_code;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    -- Start Added for 1.1
    FUNCTION remove_junk_char (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), ''), ',', '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END remove_junk_char;

    -- End Added for 1.1

    PROCEDURE mtd_intrastat_rep (pv_errbuf OUT NOCOPY VARCHAR2, pn_retcode OUT NOCOPY NUMBER, pv_operating_unit IN VARCHAR2, pv_company_code IN VARCHAR2, pv_invoice_date_from IN VARCHAR2, pv_invoice_date_to IN VARCHAR2, pv_gl_posted_from IN VARCHAR2, pv_gl_posted_to IN VARCHAR2, pv_tax_regime_code IN VARCHAR2
                                 , pv_tax_code IN VARCHAR2, pv_posting_status IN VARCHAR2, pv_final_mode IN VARCHAR2)
    AS
        pd_invoice_date_from   DATE
            := fnd_date.canonical_to_date (pv_invoice_date_from);
        pd_invoice_date_to     DATE
            := fnd_date.canonical_to_date (pv_invoice_date_to);
        pd_gl_posted_from      DATE
            := fnd_date.canonical_to_date (pv_gl_posted_from);
        pd_gl_posted_to        DATE
            := fnd_date.canonical_to_date (pv_gl_posted_to);
        lv_outbound_file       VARCHAR2 (100)
            :=    'INTRASTAT_EMEA_REPORT_'
               || gn_request_id
               || '_'
               || TO_CHAR (SYSDATE, 'DDMONYYHH24MISS')
               || '.txt';
        lv_output_file         UTL_FILE.file_type;
        pv_directory_name      VARCHAR2 (100)
                                   := 'XXD_INTRA_MTD_REPORT_OUT_DIR';

        CURSOR ar_rep_cur IS
            SELECT entitycode || '|' || remove_junk_char (flow) || '|' || remove_junk_char (commoditycode) || '|' || remove_junk_char (partnervatnumber) || '|' || remove_junk_char (partnercountry) || '|' || naturetransaction || '|' || calendarmonth || '|' || calendaryear || '|' || valuesupplylocalcurrency || '|' || remove_junk_char (memberstateofdestination) || '|' || remove_junk_char (memberstateofconsigment) || '|' || remove_junk_char (countryoforigin) || '|' || statisticalvalue || '|' || quantity || '|' || supplementaryunits || '|' || remove_junk_char (regionoforigin) || '|' || remove_junk_char (regionofdestination) || '|' || remove_junk_char (goodsdescription) || '|' || gldate || '|' || remove_junk_char (modetransport) || '|' || remove_junk_char (customervatnumber) || '|' || remove_junk_char (suppliervatnumber) || '|' || invoicedate || '|' || remove_junk_char (invoiceid) || '|' || remove_junk_char (deliveryterms) || '|' || transactionamountgross || '|' || transactionamounttax || '|' --Start Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          || tax_country || '|' --End Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                || remove_junk_char (tax_rate_code) || '|' || accountingdate || '|' || remove_junk_char (currency) || '|' || remove_junk_char (customerjurisdictionid) || '|' || remove_junk_char (supplierjurisdictionid) || '|' || remove_junk_char (suppliername) || '|' || remove_junk_char (customername) || '|' || remove_junk_char (transactioncurrency) || '|' || transactionexrate || '|' || netmass || '|' || gapless_sequence_number -- Added as per CCR0009857
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                rep_data
              FROM (SELECT NVL (
                               (SELECT glc.segment1
                                  FROM xla.xla_ae_lines xal, xla.xla_ae_headers xah, xla.xla_transaction_entities xte,
                                       apps.xla_distribution_links xdl, apps.gl_code_combinations glc
                                 WHERE     xal.ae_header_id =
                                           xah.ae_header_id
                                       AND xal.application_id =
                                           xah.application_id
                                       AND xte.entity_id = xah.entity_id
                                       AND xte.entity_code = 'TRANSACTIONS'
                                       AND xte.ledger_id = xal.ledger_id
                                       AND xte.application_id =
                                           xal.application_id
                                       AND xdl.ae_line_num = xal.ae_line_num
                                       AND xal.code_combination_id =
                                           glc.code_combination_id
                                       AND NVL (xte.source_id_int_1, -99) =
                                           rt.customer_trx_id
                                       AND xal.ae_header_id =
                                           xdl.ae_header_id
                                       AND xah.ae_header_id =
                                           xdl.ae_header_id
                                       AND xdl.source_distribution_id_num_1 =
                                           gl_dist.cust_trx_line_gl_dist_id
                                       AND xal.ledger_id = rt.set_of_books_id),
                               (SELECT glc.segment1
                                  FROM apps.gl_code_combinations glc
                                 WHERE gl_dist.code_combination_id =
                                       glc.code_combination_id))
                               entitycode,
                           'D'
                               flow,
                           (SELECT SUBSTR (MIN (REGEXP_REPLACE (tc.harmonized_tariff_code, '[^a-z_A-Z_0-9]')), 1, 8) --6404.1990.00
                              FROM do_custom.do_harmonized_tariff_codes tc
                             WHERE     tc.country = 'EU'
                                   AND tc.style_number =
                                       xxdo.get_item_details (
                                           'NA',
                                           rtl.inventory_item_id,
                                           'STYLE'))
                               commoditycode,
                           NVL (
                               (SELECT DISTINCT tax_reference
                                  FROM apps.zx_party_tax_profile pro, apps.hz_cust_acct_sites_all sites, apps.hz_cust_site_uses_all uses
                                 WHERE     pro.party_type_code =
                                           'THIRD_PARTY_SITE'
                                       AND pro.party_id = sites.party_site_id
                                       AND sites.cust_acct_site_id =
                                           uses.cust_acct_site_id
                                       AND uses.site_use_code = 'SHIP_TO'
                                       AND sites.cust_acct_site_id =
                                           hcasa_ship.cust_acct_site_id
                                       AND sites.org_id = uses.org_id
                                       AND sites.org_id = hcsua_ship.org_id
                                       AND sites.cust_account_id =
                                           rt.ship_to_customer_id
                                       --Start Added as per 1.1
                                       AND uses.site_use_id =
                                           rt.ship_to_site_use_id--End Added as per 1.1
                                                                 ),
                               (SELECT DISTINCT tax_reference
                                  FROM apps.zx_party_tax_profile pro, apps.hz_cust_acct_sites_all sites, apps.hz_cust_site_uses_all uses
                                 WHERE     pro.party_type_code =
                                           'THIRD_PARTY_SITE'
                                       AND pro.party_id = sites.party_site_id
                                       AND sites.cust_acct_site_id =
                                           uses.cust_acct_site_id
                                       AND uses.site_use_code = 'BILL_TO'
                                       AND sites.cust_acct_site_id =
                                           hcasa_bill.cust_acct_site_id
                                       AND sites.org_id = uses.org_id
                                       AND sites.org_id = hcsua_bill.org_id
                                       AND sites.cust_account_id =
                                           rt.bill_to_customer_id))
                               partnervatnumber,
                           hl_ship.country
                               partnercountry,
                           get_nature_transaction ('AR',
                                                   rtl.customer_trx_line_id,
                                                   rctt.NAME)
                               naturetransaction,
                           EXTRACT (MONTH FROM gl_dist.gl_date)
                               calendarmonth,
                           EXTRACT (YEAR FROM gl_dist.gl_date)
                               calendaryear,
                             (rtl.extended_amount + NVL (rctl_tax.extended_amount, 0))
                           * (NVL (rt.exchange_rate, 1))
                               valuesupplylocalcurrency,
                           hl_ship.country
                               memberstateofdestination,
                           (SELECT DISTINCT hloc.country
                              FROM hr_locations_all hloc
                             WHERE hloc.inventory_organization_id =
                                   rtl.warehouse_id)
                               memberstateofconsigment,
                           (SELECT country
                              FROM ap_supplier_sites_all
                             WHERE vendor_site_id =
                                   (SELECT attribute6
                                      FROM wsh_delivery_details
                                     WHERE     source_line_id =
                                               rtl.interface_line_attribute6
                                           AND ROWNUM = 1))
                               countryoforigin,
                             --from new program
                             (rtl.extended_amount + NVL (rctl_tax.extended_amount, 0))
                           * (NVL (rt.exchange_rate, 1))
                               statisticalvalue,
                           NVL (rtl.quantity_invoiced, 1)
                               quantity,
                           (SELECT tag
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_SUPPL_UNITS'
                                   AND LANGUAGE = USERENV ('LANG')
                                   AND meaning =
                                       ((SELECT SUBSTR (MIN (REGEXP_REPLACE (tc.harmonized_tariff_code, '[^a-z_A-Z_0-9]')), 1, 8) --6404.1990.00
                                           FROM do_custom.do_harmonized_tariff_codes tc
                                          WHERE     tc.country = 'EU'
                                                AND tc.style_number =
                                                    xxdo.get_item_details (
                                                        'NA',
                                                        rtl.inventory_item_id,
                                                        'STYLE'))))
                               supplementaryunits,
                           --this is from value set
                           (SELECT state
                              FROM ap_supplier_sites_all
                             WHERE vendor_site_id =
                                   (SELECT attribute6
                                      FROM wsh_delivery_details
                                     WHERE     source_line_id =
                                               rtl.interface_line_attribute6
                                           AND ROWNUM = 1))
                               regionoforigin,
                           --need calrification
                           ''
                               regionofdestination,
                           NVL (
                               (SELECT description
                                  FROM mtl_system_items_b
                                 WHERE     inventory_item_id =
                                           rtl.inventory_item_id
                                       AND organization_id =
                                           (SELECT organization_id
                                              FROM apps.org_organization_definitions
                                             WHERE organization_code = 'MST')),
                               rtl.description)
                               goodsdescription,
                           gl_dist.gl_date
                               gldate,
                           (SELECT wocs.attribute1
                              FROM apps.wsh_carriers_v wc, apps.wsh_carrier_services_v wcs, apps.wsh_org_carrier_services_v wocs,
                                   apps.wsh_lookups wl
                             WHERE     1 = 1
                                   AND wc.carrier_name = 'Deckers Internal'
                                   AND wocs.organization_code =
                                       (SELECT organization_code
                                          FROM apps.org_organization_definitions
                                         WHERE organization_id =
                                               (SELECT ool.ship_from_org_id
                                                  FROM oe_order_lines_all ool, oe_order_headers_all oha, ra_customer_trx_lines_all rctl
                                                 WHERE     oha.order_number =
                                                           rctl.interface_line_attribute1
                                                       AND oha.header_id =
                                                           ool.header_id
                                                       AND ool.line_id =
                                                           TO_NUMBER (
                                                               rctl.interface_line_attribute6)
                                                       AND rctl.customer_trx_line_id =
                                                           rtl.customer_trx_line_id
                                                       AND rctl.interface_line_context =
                                                           'ORDER ENTRY'))
                                   AND wcs.ship_method_code =
                                       (SELECT ool.shipping_method_code
                                          FROM oe_order_lines_all ool, oe_order_headers_all oha, ra_customer_trx_lines_all rctl
                                         WHERE     oha.order_number =
                                                   rctl.interface_line_attribute1
                                               AND oha.header_id =
                                                   ool.header_id
                                               AND ool.line_id =
                                                   TO_NUMBER (
                                                       rctl.interface_line_attribute6)
                                               AND rctl.customer_trx_line_id =
                                                   rtl.customer_trx_line_id
                                               AND rctl.interface_line_context =
                                                   'ORDER ENTRY')
                                   AND wc.carrier_id = wcs.carrier_id
                                   AND wcs.carrier_service_id =
                                       wocs.carrier_service_id
                                   AND wl.lookup_type = 'WSH_SERVICE_LEVELS'
                                   AND wcs.service_level = wl.lookup_code
                                   AND wocs.attribute1 IS NOT NULL)
                               modetransport,
                           --new_configaration
                           NVL (
                               (SELECT DISTINCT tax_reference
                                  FROM apps.zx_party_tax_profile pro, apps.hz_cust_acct_sites_all sites, apps.hz_cust_site_uses_all uses
                                 WHERE     pro.party_type_code =
                                           'THIRD_PARTY_SITE'
                                       AND pro.party_id = sites.party_site_id
                                       AND sites.cust_acct_site_id =
                                           uses.cust_acct_site_id
                                       AND uses.site_use_code = 'SHIP_TO'
                                       AND sites.cust_acct_site_id =
                                           hcasa_ship.cust_acct_site_id
                                       AND sites.org_id = uses.org_id
                                       AND sites.org_id = hcsua_ship.org_id
                                       AND sites.cust_account_id =
                                           rt.ship_to_customer_id
                                       --Start Added as per 1.1
                                       AND uses.site_use_id =
                                           rt.ship_to_site_use_id--End Added as per 1.1
                                                                 ),
                               (SELECT DISTINCT tax_reference
                                  FROM apps.zx_party_tax_profile pro, apps.hz_cust_acct_sites_all sites, apps.hz_cust_site_uses_all uses
                                 WHERE     pro.party_type_code =
                                           'THIRD_PARTY_SITE'
                                       AND pro.party_id = sites.party_site_id
                                       AND sites.cust_acct_site_id =
                                           uses.cust_acct_site_id
                                       AND uses.site_use_code = 'BILL_TO'
                                       AND sites.cust_acct_site_id =
                                           hcasa_bill.cust_acct_site_id
                                       AND sites.org_id = uses.org_id
                                       AND sites.org_id = hcsua_bill.org_id
                                       AND sites.cust_account_id =
                                           rt.bill_to_customer_id))
                               customervatnumber,
                           ''
                               suppliervatnumber,
                           rt.trx_date
                               invoicedate,
                           rt.trx_number
                               invoiceid,
                           (SELECT ffv.description
                              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                             WHERE     1 = 1
                                   AND ffvs.flex_value_set_id =
                                       ffv.flex_value_set_id
                                   AND ffvs.flex_value_set_name =
                                       'XXDO_CFS_INCO_TERMS_VS'
                                   AND ffv.enabled_flag = 'Y'
                                   AND NVL (ffv.start_date_active, SYSDATE) <=
                                       SYSDATE
                                   AND NVL (ffv.end_date_active, SYSDATE + 1) >
                                       SYSDATE
                                   AND UPPER (RTRIM (LTRIM (ffv.flex_value))) =
                                       UPPER (hou.NAME))
                               deliveryterms,
                             --need info
                             NVL (rtl.extended_amount, 0)
                           + NVL (
                                 (SELECT NVL (ABS (adjusted_amount), 0)
                                    FROM oe_price_adjustments
                                   WHERE price_adjustment_id =
                                         rtl.interface_line_attribute11),
                                 0)
                               transactionamountgross,
                             NVL (rctl_tax.extended_amount, 0)
                           - NVL (
                                 (SELECT NVL (ABS (adjusted_amount), 0)
                                    FROM oe_price_adjustments
                                   WHERE price_adjustment_id =
                                         rtl.interface_line_attribute11),
                                 0)
                               transactionamounttax,
                           TO_CHAR (gl_dist.gl_date, 'DD/MM/YYYY')
                               accountingdate,
                           gl.currency_code
                               currency,
                           hl_bill.country
                               customerjurisdictionid,
                           ''
                               supplierjurisdictionid,
                           ''
                               suppliername,
                           TRANSLATE (hp_bill.party_name,
                                      CHR (10) || CHR (13) || CHR (09),
                                      ' ')
                               customername,
                           rt.invoice_currency_code
                               transactioncurrency,
                           rt.exchange_rate
                               transactionexrate,
                             (SELECT unit_weight
                                FROM mtl_system_items_b
                               WHERE     inventory_item_id =
                                         rtl.inventory_item_id
                                     AND organization_id =
                                         (SELECT organization_id
                                            FROM org_organization_definitions
                                           WHERE organization_code = 'MST'))
                           * NVL (rtl.quantity_invoiced, 1)
                               netmass,
                           --Start Added for 1.1
                           (SELECT SUBSTR (tax_rate_code, 1, 2) tax_country
                              FROM apps.zx_lines
                             WHERE     trx_id = rt.customer_trx_id
                                   AND trx_line_id = rtl.customer_trx_line_id
                                   AND application_id = 222
                                   AND ROWNUM = 1)
                               tax_country,
                           --End Added for 1.1
                           (SELECT tax_rate_code
                              FROM apps.zx_lines
                             WHERE     trx_id = rt.customer_trx_id
                                   AND trx_line_id = rtl.customer_trx_line_id
                                   AND application_id = 222
                                   AND ROWNUM = 1)
                               tax_rate_code,
                           (SELECT tax_regime_code
                              FROM apps.zx_lines
                             WHERE     trx_id = rt.customer_trx_id
                                   AND trx_line_id = rtl.customer_trx_line_id
                                   AND application_id = 222
                                   AND ROWNUM = 1)
                               tax_regime_code,
                           rt.interface_header_attribute14
                               gapless_sequence_number -- Added as per CCR0009857
                      FROM apps.ra_customer_trx_all rt, apps.ra_customer_trx_lines_all rtl, ra_customer_trx_lines_all rctl_tax,
                           apps.ra_cust_trx_line_gl_dist_all gl_dist, apps.ra_cust_trx_types_all rctt, apps.ar_receivable_applications_all ara,
                           apps.ar_lookups al, apps.hz_parties hp_bill, apps.hz_parties hp_ship,
                           apps.hz_party_sites hps_bill, apps.hz_party_sites hps_ship, apps.hz_cust_accounts_all hca_bill,
                           apps.hz_cust_accounts_all hca_ship, apps.hz_cust_acct_sites_all hcasa_ship, apps.hz_cust_acct_sites_all hcasa_bill,
                           apps.hz_cust_site_uses_all hcsua_ship, apps.hz_cust_site_uses_all hcsua_bill, apps.hz_locations hl_bill,
                           apps.hz_locations hl_ship, apps.hr_operating_units hou, apps.gl_ledgers gl,
                           apps.org_organization_definitions ood, apps.gl_code_combinations glc, --Start Added for 1.1
                                                                                                 fnd_flex_value_sets ffvs,
                           fnd_flex_values ffv
                     --End Added for 1.1
                     WHERE     rt.customer_trx_id = rtl.customer_trx_id
                           AND gl_dist.customer_trx_line_id =
                               rtl.customer_trx_line_id
                           AND gl.ledger_id = rt.set_of_books_id
                           AND gl.ledger_category_code = 'PRIMARY'
                           AND rt.org_id = hou.organization_id
                           AND rt.cust_trx_type_id = rctt.cust_trx_type_id
                           AND rt.org_id = rctt.org_id
                           AND ara.customer_trx_id(+) = rt.customer_trx_id
                           AND NVL (rt.complete_flag, 'N') = 'Y'
                           AND al.lookup_type = 'INV/CM'
                           AND ood.organization_id = rtl.warehouse_id
                           AND al.lookup_code = rctt.TYPE
                           AND hp_bill.party_id = hps_bill.party_id
                           AND hps_bill.party_site_id =
                               hcasa_bill.party_site_id
                           AND rt.bill_to_site_use_id =
                               hcsua_bill.site_use_id
                           AND hca_bill.cust_account_id =
                               hcasa_bill.cust_account_id
                           AND hcasa_bill.cust_acct_site_id =
                               hcsua_bill.cust_acct_site_id
                           AND hps_bill.location_id = hl_bill.location_id
                           AND hp_ship.party_id = hps_ship.party_id
                           AND hps_ship.party_site_id =
                               hcasa_ship.party_site_id
                           AND rt.ship_to_site_use_id =
                               hcsua_ship.site_use_id
                           AND hca_ship.cust_account_id =
                               hcasa_ship.cust_account_id
                           AND hcasa_ship.cust_acct_site_id =
                               hcsua_ship.cust_acct_site_id
                           AND hps_ship.location_id = hl_ship.location_id
                           AND rtl.line_type = 'LINE'
                           --IN ('LINE', 'FREIGHT', 'CHARGES')
                           AND rctl_tax.line_type(+) = 'TAX'
                           AND rctl_tax.customer_trx_id(+) =
                               rtl.customer_trx_id
                           AND rctl_tax.link_to_cust_trx_line_id(+) =
                               rtl.customer_trx_line_id
                           AND gl_dist.account_class IN ('REV', 'FREIGHT') --only REV
                           AND gl_dist.account_set_flag = 'N'
                           AND gl_dist.org_id = rtl.org_id
                           AND rt.org_id = hou.organization_id
                           AND gl_dist.code_combination_id =
                               glc.code_combination_id
                           --Start Added for 1.1
                           --AND hou.NAME = pv_operating_unit
                           AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND flex_value_set_name =
                               'XXD_INTRASTAT_MTD_OU_VS'
                           AND ffv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           ffv.start_date_active,
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           ffv.end_date_active,
                                                           TRUNC (SYSDATE))
                           AND ffv.flex_value <> 'ALL EMEA'
                           AND hou.name = ffv.flex_value
                           AND hou.name =
                               DECODE (pv_operating_unit,
                                       'ALL EMEA', ffv.flex_value,
                                       pv_operating_unit)
                           --End Added for 1.1
                           AND glc.segment1 =
                               NVL (pv_company_code, glc.segment1)
                           AND rt.trx_date BETWEEN TO_DATE (
                                                       pd_invoice_date_from)
                                               AND TO_DATE (
                                                       pd_invoice_date_to)
                           AND gl_dist.gl_date BETWEEN NVL (
                                                           TO_DATE (
                                                               pd_gl_posted_from),
                                                           gl_dist.gl_date)
                                                   AND NVL (
                                                           TO_DATE (
                                                               pd_gl_posted_to),
                                                           gl_dist.gl_date))
             WHERE     NVL (tax_rate_code, 'XXXX') =
                       NVL (pv_tax_code, NVL (tax_rate_code, 'XXXX'))
                   AND NVL (tax_regime_code, 'XXXX') =
                       NVL (pv_tax_regime_code,
                            NVL (tax_regime_code, 'XXXX'))
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_EU_COUNTRY_LIST'
                                   AND LANGUAGE = USERENV ('Lang')
                                   AND lookup_code = partnercountry
                                   AND enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE)))
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_EU_COUNTRY_LIST'
                                   AND LANGUAGE = USERENV ('Lang')
                                   AND lookup_code = memberstateofconsigment
                                   AND enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE)))
                   AND memberstateofconsigment <> partnercountry
            UNION
            SELECT entitycode || '|' || remove_junk_char (flow) || '|' || commoditycode || '|' || remove_junk_char (partnervatnumber) || '|' || remove_junk_char (partnercountry) || '|' || naturetransaction || '|' || calendarmonth || '|' || calendaryear || '|' || valuesupplylocalcurrency || '|' || remove_junk_char (memberstateofdestination) || '|' || remove_junk_char (memberstateofconsigment) || '|' || remove_junk_char (countryoforigin) || '|' || statisticalvalue || '|' || quantity || '|' || supplementaryunits || '|' || remove_junk_char (regionoforigin) || '|' || remove_junk_char (regionofdestination) || '|' || remove_junk_char (goodsdescription) || '|' || gldate || '|' || remove_junk_char (modetransport) || '|' || remove_junk_char (customervatnumber) || '|' || remove_junk_char (suppliervatnumber) || '|' || invoicedate || '|' || remove_junk_char (invoiceid) || '|' || remove_junk_char (deliveryterms) || '|' || transactionamountgross || '|' || transactionamounttax || '|' --Start Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       || tax_country || '|' --End Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             || remove_junk_char (tax_rate_code) || '|' || accountingdate || '|' || remove_junk_char (currency) || '|' || remove_junk_char (customerjurisdictionid) || '|' || remove_junk_char (supplierjurisdictionid) || '|' || remove_junk_char (suppliername) || '|' || remove_junk_char (customername) || '|' || remove_junk_char (transactioncurrency) || '|' || transactionexrate || '|' || netmass || '|' || gapless_sequence_number -- Added as per CCR0009857
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             rep_data
              FROM (  SELECT gcc.segment1
                                 entitycode,
                             'A'
                                 flow,
                             (SELECT SUBSTR (MIN (REGEXP_REPLACE (tc.harmonized_tariff_code, '[^a-z_A-Z_0-9]')), 1, 8) --6404.1990.00
                                FROM do_custom.do_harmonized_tariff_codes tc
                               WHERE     tc.country = 'EU'
                                     AND tc.style_number =
                                         xxdo.get_item_details (
                                             'NA',
                                             aila.inventory_item_id,
                                             'STYLE'))
                                 commoditycode,
                             aps.vat_registration_num
                                 partnervatnumber,
                             apsa.country
                                 partnercountry,
                             get_nature_transaction (
                                 'AP',
                                 aila.line_number,
                                 ai.invoice_type_lookup_code)
                                 naturetransaction,
                             --writefuntion
                             EXTRACT (MONTH FROM ai.gl_date)
                                 calendarmonth,
                             EXTRACT (YEAR FROM ai.gl_date)
                                 calendaryear,
                             SUM (aida.amount) * NVL (ai.exchange_rate, 1)
                                 valuesupplylocalcurrency,
                             (SELECT country
                                FROM hr_locations
                               WHERE location_id = aila.ship_to_location_id)
                                 memberstateofdestination,
                             apsa.country
                                 memberstateofconsigment,
                             (SELECT country
                                FROM ap_supplier_sites_all
                               WHERE     vendor_site_code =
                                         (SELECT attribute7
                                            FROM po_lines_all
                                           WHERE     po_line_id =
                                                     aila.po_line_id
                                                 AND attribute_category =
                                                     'PO Data Elements')
                                     AND inactive_date >= SYSDATE)
                                 countryoforigin,
                             SUM (aida.amount) * NVL (ai.exchange_rate, 1)
                                 statisticalvalue, --need info go to market value
                             NVL (SUM (aida.quantity_invoiced), 1)
                                 quantity,
                             (SELECT tag
                                FROM fnd_lookup_values
                               WHERE     lookup_type =
                                         'XXDO_INTRASTAT_SUPPL_UNITS'
                                     AND LANGUAGE = USERENV ('LANG')
                                     AND meaning =
                                         (SELECT SUBSTR (MIN (REGEXP_REPLACE (tc.harmonized_tariff_code, '[^a-z_A-Z_0-9]')), 1, 8) --6404.1990.00
                                            FROM do_custom.do_harmonized_tariff_codes tc
                                           WHERE     tc.country = 'EU'
                                                 AND tc.style_number =
                                                     xxdo.get_item_details (
                                                         'NA',
                                                         aila.inventory_item_id,
                                                         'STYLE')))
                                 supplementaryunits,
                             --from lookup
                             ''
                                 regionoforigin,
                             (SELECT region_1
                                FROM hr_locations
                               WHERE location_id = aila.ship_to_location_id)
                                 regionofdestination,
                             NVL (aila.item_description, aila.description)
                                 goodsdescription,
                             ai.gl_date
                                 gldate,
                             (SELECT attribute10
                                FROM po_line_locations_all
                               WHERE     attribute_category =
                                         'PO Line Locations Elements'
                                     AND line_location_id = po_line_location_id)
                                 modetransport,
                             ''
                                 customervatnumber,
                             aps.vat_registration_num
                                 suppliervatnumber,
                             ai.invoice_date
                                 invoicedate,
                             ai.invoice_num
                                 invoiceid,
                             (SELECT description
                                FROM fnd_lookup_values
                               WHERE     lookup_type =
                                         'XXDO_ONESOURCE_DELIVERY_TERMS'
                                     AND LANGUAGE = 'US'
                                     AND enabled_flag = 'Y'
                                     AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                     start_date_active,
                                                                     TRUNC (
                                                                         SYSDATE))
                                                             AND NVL (
                                                                     end_date_active,
                                                                     TRUNC (
                                                                         SYSDATE))
                                     AND UPPER (meaning) = UPPER (hu.NAME))
                                 deliveryterms,
                             --need info
                             SUM (aida.amount)
                                 transactionamountgross,
                             (SELECT NVL (SUM (amount), 0)
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx
                               --gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id)
                                 transactionamounttax,
                             TO_CHAR (ai.gl_date, 'DD/MM/YYYY')
                                 accountingdate,
                             gl.currency_code
                                 currency,
                             ''
                                 customerjurisdictionid,
                             apsa.country
                                 supplierjurisdictionid,
                             aps.vendor_name
                                 suppliername,
                             ''
                                 customername,
                             ai.invoice_currency_code
                                 transactioncurrency,
                             NVL (ai.exchange_rate, 1)
                                 transactionexrate,
                               (SELECT unit_weight
                                  FROM mtl_system_items_b
                                 WHERE     inventory_item_id =
                                           aila.inventory_item_id
                                       AND organization_id =
                                           (SELECT organization_id
                                              FROM org_organization_definitions
                                             WHERE organization_code = 'MST'))
                             * NVL (SUM (aida.quantity_invoiced), 1)
                                 netmass,
                             (SELECT zx.tax_regime_code
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 tax_regime_code,
                             --Start Added for 1.1
                             (SELECT SUBSTR (zx.tax, 1, 2) tax_country
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 tax_country,
                             --End Added for 1.1
                             (SELECT zx.tax
                                FROM ap_invoice_distributions_all aid, zx_rec_nrec_dist zx, gl_code_combinations gcc
                               WHERE     zx.trx_id = aila.invoice_id
                                     AND zx.trx_line_number = aila.line_number
                                     AND aid.invoice_id = zx.trx_id
                                     AND gcc.code_combination_id =
                                         aid.dist_code_combination_id
                                     AND gcc.segment6 IN (11901, 11902)
                                     AND aid.detail_tax_dist_id =
                                         rec_nrec_tax_dist_id
                                     AND ROWNUM = 1)
                                 tax_rate_code,
                             ai.attribute14
                                 gapless_sequence_number -- Added as per CCR0009857
                        FROM ap_invoices_all ai, ap_invoice_lines_all aila, ap_invoice_distributions_all aida,
                             hr_operating_units hu, apps.ap_suppliers aps, ap_supplier_sites_all apsa,
                             fnd_lookup_values alc, po_headers_all ai_pha, gl_code_combinations_kfv gcc,
                             apps.gl_ledgers gl, --Start Added for 1.1
                                                 fnd_flex_value_sets ffvs, fnd_flex_values ffv
                       --End Added for 1.1
                       WHERE     ai.invoice_id = aila.invoice_id
                             AND aila.invoice_id = aida.invoice_id
                             AND aila.line_number = aida.invoice_line_number
                             AND aila.line_type_lookup_code <> 'TAX'
                             AND hu.organization_id = ai.org_id
                             AND aps.vendor_id = ai.vendor_id
                             AND apsa.vendor_id = aps.vendor_id
                             AND ai.vendor_site_id = apsa.vendor_site_id
                             AND alc.lookup_type = 'INVOICE TYPE'
                             AND alc.lookup_code = ai.invoice_type_lookup_code
                             AND alc.LANGUAGE = USERENV ('Lang')
                             AND ap_invoices_pkg.get_posting_status (
                                     ai.invoice_id) =
                                 'Y'
                             AND aila.po_header_id = ai_pha.po_header_id(+)
                             AND aida.dist_code_combination_id =
                                 gcc.code_combination_id
                             AND gl.ledger_id = aila.set_of_books_id
                             AND gl.ledger_category_code = 'PRIMARY'
                             --Start Added for 1.1
                             --AND hu.NAME = pv_operating_unit
                             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                             AND flex_value_set_name =
                                 'XXD_INTRASTAT_MTD_OU_VS'
                             AND ffv.enabled_flag = 'Y'
                             AND TRUNC (SYSDATE) BETWEEN NVL (
                                                             ffv.start_date_active,
                                                             TRUNC (SYSDATE))
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             TRUNC (SYSDATE))
                             AND ffv.flex_value <> 'ALL EMEA'
                             AND hu.name = ffv.flex_value
                             AND hu.name =
                                 DECODE (pv_operating_unit,
                                         'ALL EMEA', ffv.flex_value,
                                         pv_operating_unit)
                             --End Added for 1.1
                             AND gcc.segment1 =
                                 NVL (pv_company_code, gcc.segment1)
                             AND ai.invoice_date BETWEEN pd_invoice_date_from
                                                     AND pd_invoice_date_to
                             AND ai.gl_date BETWEEN NVL (pd_gl_posted_from,
                                                         ai.gl_date)
                                                AND NVL (pd_gl_posted_to,
                                                         ai.gl_date)
                             AND NVL (aida.posted_flag, 'N') =
                                 NVL (pv_posting_status,
                                      NVL (aida.posted_flag, 'N'))
                    GROUP BY gcc.segment1, aps.vendor_name, aps.vat_registration_num,
                             apsa.country, ai.invoice_num, ai.invoice_date,
                             ai.invoice_currency_code, ai.gl_date, aila.inventory_item_id,
                             aila.item_description, hu.NAME, aila.description,
                             gl.currency_code, aila.ship_to_location_id, aila.po_line_id,
                             aila.line_number, ai.invoice_type_lookup_code, po_line_location_id,
                             NVL (ai.exchange_rate, 1), aila.tax, aila.invoice_id,
                             ai.attribute14         -- Added as per CCR0009857
                                           )
             WHERE     NVL (tax_regime_code, 'XXXX') =
                       NVL (pv_tax_regime_code,
                            NVL (tax_regime_code, 'XXXX'))
                   AND NVL (tax_rate_code, 'XXXX') =
                       NVL (pv_tax_code, NVL (tax_rate_code, 'XXXX'))
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_EU_COUNTRY_LIST'
                                   AND LANGUAGE = USERENV ('Lang')
                                   AND lookup_code = memberstateofdestination
                                   AND enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE)))
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_EU_COUNTRY_LIST'
                                   AND LANGUAGE = USERENV ('Lang')
                                   AND lookup_code = memberstateofconsigment
                                   AND enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE)))
                   AND memberstateofconsigment <> memberstateofdestination
            UNION
            SELECT entitycode || '|' || remove_junk_char (flow) || '|' || remove_junk_char (commoditycode) || '|' || remove_junk_char (partnervatnumber) || '|' || remove_junk_char (partnercountry) || '|' || naturetransaction || '|' || calendarmonth || '|' || calendaryear || '|' || valuesupplylocalcurrency || '|' || remove_junk_char (memberstateofdestination) || '|' || remove_junk_char (memberstateofconsigment) || '|' || remove_junk_char (countryoforigin) || '|' || statisticalvalue || '|' || quantity || '|' || supplementaryunits || '|' || remove_junk_char (regionoforigin) || '|' || remove_junk_char (regionofdestination) || '|' || remove_junk_char (goodsdescription) || '|' || gldate || '|' || remove_junk_char (modetransport) || '|' || remove_junk_char (customervatnumber) || '|' || remove_junk_char (suppliervatnumber) || '|' || invoicedate || '|' || remove_junk_char (invoiceid) || '|' || remove_junk_char (deliveryterms) || '|' || transactionamountgross || '|' || transactionamounttax || '|' --Start Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          || remove_junk_char (tax_country) || '|' --End Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   || remove_junk_char (tax_rate_code) || '|' || accountingdate || '|' || remove_junk_char (currency) || '|' || remove_junk_char (customerjurisdictionid) || '|' || remove_junk_char (supplierjurisdictionid) || '|' || remove_junk_char (suppliername) || '|' || remove_junk_char (customername) || '|' || remove_junk_char (transactioncurrency) || '|' || transactionexrate || '|' || netmass || '|' || gapless_sequence_number -- Added as per CCR0009857
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   rep_data
              FROM (SELECT (SELECT legal_entity_identifier
                              FROM xle_le_ou_ledger_v
                             WHERE     operating_unit_id = ooh.org_id
                                   AND legal_entity_id IN
                                           (SELECT DISTINCT
                                                   xep.legal_entity_id
                                              FROM xle_entity_profiles xep, xle_registrations reg, hr_operating_units hou,
                                                   hr_all_organization_units_tl hr_outl, hr_locations_all hr_loc, gl_legal_entities_bsvs glev
                                             WHERE     1 = 1
                                                   AND xep.transacting_entity_flag =
                                                       'Y'
                                                   AND xep.legal_entity_id =
                                                       reg.source_id
                                                   AND reg.source_table =
                                                       'XLE_ENTITY_PROFILES'
                                                   AND reg.identifying_flag =
                                                       'Y'
                                                   AND hou.organization_id =
                                                       ooh.org_id
                                                   AND xep.legal_entity_id =
                                                       hou.default_legal_context_id
                                                   AND reg.location_id =
                                                       hr_loc.location_id
                                                   AND xep.legal_entity_id =
                                                       glev.legal_entity_id
                                                   AND hr_outl.organization_id =
                                                       hou.organization_id))
                               entitycode,
                           'D'
                               flow,
                           (SELECT SUBSTR (MIN (REGEXP_REPLACE (tc.harmonized_tariff_code, '[^a-z_A-Z_0-9]')), 1, 8) --6404.1990.00
                              FROM do_custom.do_harmonized_tariff_codes tc
                             WHERE     tc.country = 'EU'
                                   AND tc.style_number =
                                       xxdo.get_item_details (
                                           'NA',
                                           ool.inventory_item_id,
                                           'STYLE'))
                               commoditycode,
                           ''
                               partnervatnumber,                       --check
                           hl.country
                               partnercountry,
                           '18'
                               naturetransaction,
                           EXTRACT (MONTH FROM ool.actual_shipment_date)
                               calendarmonth,
                           EXTRACT (YEAR FROM ool.actual_shipment_date)
                               calendaryear,
                             NVL (ool.ordered_quantity, 0)
                           * NVL (ool.unit_selling_price, 0)
                               valuesupplylocalcurrency,
                           hl.country
                               memberstateofdestination,
                           (SELECT DISTINCT hloc.country
                              FROM hr_locations_all hloc
                             WHERE hloc.inventory_organization_id =
                                   ooh.ship_from_org_id)
                               memberstateofconsigment,
                           ''
                               countryoforigin,            --new configaration
                             NVL (ool.ordered_quantity, 0)
                           * NVL (ool.unit_selling_price, 0)
                               statisticalvalue,
                           --need to check if they are zero dolloar orders
                           ool.ordered_quantity
                               quantity,
                           (SELECT tag
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_SUPPL_UNITS'
                                   AND LANGUAGE = USERENV ('LANG')
                                   AND meaning =
                                       (SELECT SUBSTR (MIN (REGEXP_REPLACE (tc.harmonized_tariff_code, '[^a-z_A-Z_0-9]')), 1, 8) --6404.1990.00
                                          FROM do_custom.do_harmonized_tariff_codes tc
                                         WHERE     tc.country = 'EU'
                                               AND tc.style_number =
                                                   xxdo.get_item_details (
                                                       'NA',
                                                       ool.inventory_item_id,
                                                       'STYLE')))
                               supplementaryunits,
                           --from valueset
                           ''
                               regionoforigin,                     --need info
                           ''
                               regionofdestination,
                           (SELECT description
                              FROM mtl_system_items_b
                             WHERE     inventory_item_id =
                                       ool.inventory_item_id
                                   AND organization_id =
                                       (SELECT organization_id
                                          FROM org_organization_definitions
                                         WHERE organization_code = 'MST'))
                               goodsdescription,
                           ool.actual_shipment_date
                               gldate,
                           (SELECT wocs.attribute1
                              FROM apps.wsh_carriers_v wc, apps.wsh_carrier_services_v wcs, apps.wsh_org_carrier_services_v wocs,
                                   apps.wsh_lookups wl
                             WHERE     1 = 1
                                   AND wc.carrier_name = 'Deckers Internal'
                                   AND wocs.organization_code =
                                       (SELECT organization_code
                                          FROM org_organization_definitions
                                         WHERE organization_id =
                                               ool.ship_from_org_id)
                                   AND wcs.ship_method_code =
                                       ool.shipping_method_code
                                   AND wc.carrier_id = wcs.carrier_id
                                   AND wcs.carrier_service_id =
                                       wocs.carrier_service_id
                                   AND wl.lookup_type = 'WSH_SERVICE_LEVELS'
                                   AND wcs.service_level = wl.lookup_code
                                   AND wocs.attribute1 IS NOT NULL)
                               modetransport,
                           --new program
                           ''
                               customervatnumber,
                           ''
                               suppliervatnumber,
                           ooh.creation_date
                               invoicedate,
                           ooh.order_number
                               invoiceid,
                           get_inco_code (ool.header_id)
                               deliveryterms,
                             NVL (ool.ordered_quantity, 0)
                           * NVL (ool.unit_selling_price, 0)
                               transactionamountgross,
                           (SELECT adjusted_amount
                              FROM oe_price_adjustments
                             WHERE     1 = 1
                                   AND list_line_type_code = 'TAX'
                                   AND line_id = ool.line_id
                                   AND ROWNUM = 1)
                               transactionamounttax,
                           ool.actual_shipment_date
                               accountingdate,
                           ooh.transactional_curr_code
                               currency,
                           ''
                               customerjurisdictionid,                   --add
                           ''
                               supplierjurisdictionid,
                           ''
                               suppliername,
                           TRANSLATE (hp.party_name,
                                      CHR (10) || CHR (13) || CHR (09),
                                      ' ')
                               customername,
                           transactional_curr_code
                               transactioncurrency,
                           DECODE (
                               transactional_curr_code,
                               (SELECT currency_code
                                  FROM gl_ledgers gll, hr_operating_units hou
                                 WHERE     hou.set_of_books_id =
                                           gll.ledger_id
                                       AND hou.organization_id = ooh.org_id), 1,
                               (SELECT conversion_rate
                                  FROM apps.gl_daily_rates
                                 WHERE     conversion_type = 'Corporate'
                                       AND from_currency =
                                           transactional_curr_code
                                       AND to_currency =
                                           (SELECT currency_code
                                              FROM gl_ledgers gll, hr_operating_units hou
                                             WHERE     hou.set_of_books_id =
                                                       gll.ledger_id
                                                   AND hou.organization_id =
                                                       ooh.org_id)
                                       AND conversion_date =
                                           TRUNC (ool.creation_date)))
                               transactionexrate,
                             (SELECT unit_weight
                                FROM mtl_system_items_b
                               WHERE     inventory_item_id =
                                         ool.inventory_item_id
                                     AND organization_id =
                                         (SELECT organization_id
                                            FROM org_organization_definitions
                                           WHERE organization_code = 'MST'))
                           * NVL (ool.ordered_quantity, 1)
                               netmass,
                           --Start Added for 1.1
                           (SELECT SUBSTR (tax_rate_code, 1, 2) tax_country
                              FROM zx_rates_b
                             WHERE     tax_rate_id =
                                       (SELECT tax_rate_id
                                          FROM oe_price_adjustments
                                         WHERE     1 = 1
                                               AND list_line_type_code =
                                                   'TAX'
                                               AND line_id = ool.line_id
                                               AND ROWNUM = 1)
                                   AND ROWNUM = 1)
                               tax_country,
                           --End Added for 1.1
                           (SELECT tax_rate_code
                              FROM zx_rates_b
                             WHERE     tax_rate_id =
                                       (SELECT tax_rate_id
                                          FROM oe_price_adjustments
                                         WHERE     1 = 1
                                               AND list_line_type_code =
                                                   'TAX'
                                               AND line_id = ool.line_id
                                               AND ROWNUM = 1)
                                   AND ROWNUM = 1)
                               tax_rate_code,
                           (SELECT tax_regime_code
                              FROM zx_rates_b
                             WHERE     tax_rate_id =
                                       (SELECT tax_rate_id
                                          FROM oe_price_adjustments
                                         WHERE     1 = 1
                                               AND list_line_type_code =
                                                   'TAX'
                                               AND line_id = ool.line_id
                                               AND ROWNUM = 1)
                                   AND ROWNUM = 1)
                               tax_regime_code,
                           NULL
                               gapless_sequence_number -- Added as per CCR0009857
                      FROM oe_order_headers_all ooh, oe_order_lines_all ool, oe_transaction_types_tl ottl,
                           hr_operating_units hou, apps.hz_cust_site_uses_all hcsua_ship, apps.hz_cust_acct_sites_all hcasa_ship,
                           apps.hz_party_sites hps_ship, apps.hz_locations hl, hz_parties hp,
                           org_organization_definitions ood, mtl_system_items_b mtl, --Start Added for 1.1
                                                                                     fnd_flex_value_sets ffvs,
                           fnd_flex_values ffv
                     --End Added for 1.1
                     WHERE     ooh.order_type_id =
                               TO_NUMBER (ottl.transaction_type_id)
                           AND ottl.NAME = 'DC to DC Transfer - Macau EMEA'
                           AND ottl.LANGUAGE = 'US'
                           AND hou.organization_id = ooh.org_id
                           AND ooh.header_id = ool.header_id
                           AND hcsua_ship.site_use_id = ooh.ship_to_org_id
                           AND hcasa_ship.cust_acct_site_id =
                               hcsua_ship.cust_acct_site_id
                           AND hps_ship.party_site_id =
                               hcasa_ship.party_site_id
                           AND hps_ship.party_id = hp.party_id
                           AND hl.location_id = hps_ship.location_id
                           AND ood.organization_id = ool.ship_from_org_id
                           AND mtl.inventory_item_id = ool.inventory_item_id
                           AND mtl.organization_id = ool.ship_from_org_id
                           --Start Added for 1.1
                           --AND hou.NAME = pv_operating_unit
                           AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND flex_value_set_name =
                               'XXD_INTRASTAT_MTD_OU_VS'
                           AND ffv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           ffv.start_date_active,
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           ffv.end_date_active,
                                                           TRUNC (SYSDATE))
                           AND ffv.flex_value <> 'ALL EMEA'
                           AND hou.name = ffv.flex_value
                           AND hou.name =
                               DECODE (pv_operating_unit,
                                       'ALL EMEA', ffv.flex_value,
                                       pv_operating_unit)
                           --End Added for 1.1
                           AND ooh.creation_date BETWEEN pd_invoice_date_from
                                                     AND pd_invoice_date_to
                           AND ool.actual_shipment_date BETWEEN NVL (
                                                                    pd_gl_posted_from,
                                                                    ool.actual_shipment_date)
                                                            AND NVL (
                                                                    pd_gl_posted_to,
                                                                    ool.actual_shipment_date))
             WHERE     entitycode = NVL (pv_company_code, entitycode)
                   AND NVL (tax_rate_code, 'XXX') =
                       NVL (pv_tax_code, NVL (tax_rate_code, 'XXX'))
                   AND NVL (tax_regime_code, 'XXX') =
                       NVL (pv_tax_regime_code, NVL (tax_regime_code, 'XXX'))
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_EU_COUNTRY_LIST'
                                   AND LANGUAGE = USERENV ('Lang')
                                   AND lookup_code = partnercountry
                                   AND enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE)))
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_EU_COUNTRY_LIST'
                                   AND LANGUAGE = USERENV ('Lang')
                                   AND lookup_code = memberstateofconsigment
                                   AND enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE)))
                   AND memberstateofconsigment <> partnercountry
            UNION
            SELECT entitycode || '|' || remove_junk_char (flow) || '|' || remove_junk_char (commoditycode) || '|' || remove_junk_char (partnervatnumber) || '|' || remove_junk_char (partnercountry) || '|' || naturetransaction || '|' || calendarmonth || '|' || calendaryear || '|' || valuesupplylocalcurrency || '|' || remove_junk_char (memberstateofdestination) || '|' || remove_junk_char (memberstateofconsigment) || '|' || remove_junk_char (countryoforigin) || '|' || statisticalvalue || '|' || quantity || '|' || supplementaryunits || '|' || remove_junk_char (regionoforigin) || '|' || remove_junk_char (regionofdestination) || '|' || remove_junk_char (goodsdescription) || '|' || gldate || '|' || remove_junk_char (modetransport) || '|' || remove_junk_char (customervatnumber) || '|' || remove_junk_char (suppliervatnumber) || '|' || invoicedate || '|' || remove_junk_char (invoiceid) || '|' || remove_junk_char (deliveryterms) || '|' || transactionamountgross || '|' || transactionamounttax || '|' --Start Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          || tax_country || '|' --End Added for 1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                || remove_junk_char (tax_rate_code) || '|' || accountingdate || '|' || remove_junk_char (currency) || '|' || remove_junk_char (customerjurisdictionid) || '|' || remove_junk_char (supplierjurisdictionid) || '|' || remove_junk_char (suppliername) || '|' || remove_junk_char (customername) || '|' || remove_junk_char (transactioncurrency) || '|' || transactionexrate || '|' || netmass || '|' || gapless_sequence_number -- Added as per CCR0009857
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                rep_data
              FROM (SELECT (SELECT glc.segment1
                              FROM apps.gl_code_combinations glc
                             WHERE glc.code_combination_id =
                                   (SELECT code_combination_id
                                      FROM po_req_distributions_all
                                     WHERE requisition_line_id =
                                           prl.requisition_line_id))
                               entitycode,
                           'A'
                               flow,
                           (SELECT SUBSTR (MIN (REGEXP_REPLACE (tc.harmonized_tariff_code, '[^a-z_A-Z_0-9]')), 1, 8) --6404.1990.00
                              FROM do_custom.do_harmonized_tariff_codes tc
                             WHERE     tc.country = 'EU'
                                   AND tc.style_number =
                                       xxdo.get_item_details ('NA',
                                                              prl.item_id,
                                                              'STYLE'))
                               commoditycode,
                           aps.vat_registration_num
                               partnervatnumber,
                           (SELECT apsa.country
                              FROM ap_supplier_sites_all apsa
                             WHERE     apsa.vendor_site_id =
                                       prl.vendor_site_id
                                   AND apsa.vendor_id = apsa.vendor_id
                                   AND inactive_date >= TRUNC (SYSDATE))
                               partnercountry,
                           '18'
                               naturetransaction,
                           EXTRACT (MONTH FROM prl.need_by_date)
                               calendarmonth,
                           EXTRACT (YEAR FROM prl.need_by_date)
                               calendaryear,
                           prl.quantity * prl.unit_price
                               valuesupplylocalcurrency,
                           (SELECT country
                              FROM hr_locations
                             WHERE location_id = prl.deliver_to_location_id)
                               memberstateofdestination,
                           (SELECT DISTINCT hloc.country
                              FROM hr_locations_all hloc
                             WHERE hloc.inventory_organization_id =
                                   ooh.ship_from_org_id)
                               memberstateofconsigment,
                           ''
                               countryoforigin,              --this is from po
                           prl.quantity * prl.unit_price
                               statisticalvalue,
                           prl.quantity
                               quantity,
                           (SELECT tag
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_SUPPL_UNITS'
                                   AND LANGUAGE = USERENV ('LANG')
                                   AND meaning =
                                       (SELECT SUBSTR (MIN (REGEXP_REPLACE (tc.harmonized_tariff_code, '[^a-z_A-Z_0-9]')), 1, 8) --6404.1990.00
                                          FROM do_custom.do_harmonized_tariff_codes tc
                                         WHERE     tc.country = 'EU'
                                               AND tc.style_number =
                                                   xxdo.get_item_details (
                                                       'NA',
                                                       prl.item_id,
                                                       'STYLE')))
                               supplementaryunits,
                           --from lookuop
                           ''
                               regionoforigin,                          --null
                           (SELECT region_1
                              FROM hr_locations
                             WHERE location_id = prl.deliver_to_location_id)
                               regionofdestination,
                           --ship_to
                           (SELECT description
                              FROM mtl_system_items_b
                             WHERE     inventory_item_id = prl.item_id
                                   AND organization_id =
                                       (SELECT organization_id
                                          FROM org_organization_definitions
                                         WHERE organization_code = 'MST'))
                               goodsdescription,
                           prl.need_by_date
                               gldate,
                           (SELECT wocs.attribute1
                              FROM apps.wsh_carriers_v wc, apps.wsh_carrier_services_v wcs, apps.wsh_org_carrier_services_v wocs,
                                   apps.wsh_lookups wl
                             WHERE     1 = 1
                                   AND wc.carrier_name = 'Deckers Internal'
                                   AND wocs.organization_code =
                                       (SELECT organization_code
                                          FROM org_organization_definitions
                                         WHERE organization_id =
                                               ool.ship_from_org_id)
                                   AND wcs.ship_method_code =
                                       ool.shipping_method_code
                                   AND wc.carrier_id = wcs.carrier_id
                                   AND wcs.carrier_service_id =
                                       wocs.carrier_service_id
                                   AND wl.lookup_type = 'WSH_SERVICE_LEVELS'
                                   AND wcs.service_level = wl.lookup_code
                                   AND wocs.attribute1 IS NOT NULL)
                               modetransport,
                           ''
                               customervatnumber,
                           aps.num_1099
                               suppliervatnumber,
                           prl.creation_date
                               invoicedate,
                           prh.segment1
                               invoiceid,
                           get_inco_code (ool.header_id)
                               deliveryterms,
                           prl.quantity * prl.unit_price
                               transactionamountgross,
                           (SELECT SUM (taxable_amt)
                              FROM apps.zx_lines
                             WHERE     trx_id = prl.requisition_header_id
                                   AND trx_line_id = prl.requisition_line_id--  AND application_id = 222
                                                                            )
                               transactionamounttax,
                           prl.need_by_date
                               accountingdate,
                           prl.currency_code
                               currency,
                           ''
                               customerjurisdictionid,
                           (SELECT apsa.country
                              FROM ap_supplier_sites_all apsa
                             WHERE     apsa.vendor_id = prl.vendor_id
                                   AND apsa.vendor_site_id =
                                       prl.vendor_site_id
                                   AND NVL (apsa.inactive_date, SYSDATE) >=
                                       SYSDATE)
                               supplierjurisdictionid,
                           aps.vendor_name
                               suppliername,
                           ''
                               customername,
                           (SELECT currency_code
                              FROM gl_ledgers gll, hr_operating_units hou
                             WHERE     hou.set_of_books_id = gll.ledger_id
                                   AND hou.organization_id = prh.org_id)
                               transactioncurrency,
                           DECODE (
                               NVL (
                                   prl.currency_code,
                                   (SELECT currency_code
                                      FROM gl_ledgers gll, hr_operating_units hou
                                     WHERE     hou.set_of_books_id =
                                               gll.ledger_id
                                           AND hou.organization_id =
                                               prh.org_id)),
                               (SELECT currency_code
                                  FROM gl_ledgers gll, hr_operating_units hou
                                 WHERE     hou.set_of_books_id =
                                           gll.ledger_id
                                       AND hou.organization_id = prh.org_id), 1,
                               (SELECT conversion_rate
                                  FROM apps.gl_daily_rates
                                 WHERE     conversion_type = 'Corporate'
                                       AND from_currency = prl.currency_code
                                       AND to_currency =
                                           (SELECT currency_code
                                              FROM gl_ledgers gll, hr_operating_units hou
                                             WHERE     hou.set_of_books_id =
                                                       gll.ledger_id
                                                   AND hou.organization_id =
                                                       prh.org_id)
                                       AND conversion_date =
                                           TRUNC (prl.creation_date)))
                               transactionexrate,
                             (SELECT unit_weight
                                FROM mtl_system_items_b
                               WHERE     inventory_item_id = prl.item_id
                                     AND organization_id =
                                         (SELECT organization_id
                                            FROM org_organization_definitions
                                           WHERE organization_code = 'MST'))
                           * NVL (prl.quantity, 1)
                               netmass,
                           --Start Added for 1.1
                           (SELECT SUBSTR (tax_rate_code, 1, 2) tax_country
                              FROM apps.zx_lines
                             WHERE     trx_id = prl.requisition_header_id
                                   AND trx_line_id = prl.requisition_line_id
                                   --  AND application_id = 222
                                   AND ROWNUM = 1)
                               tax_country,
                           --End Added for 1.1
                           (SELECT tax_rate_code
                              FROM apps.zx_lines
                             WHERE     trx_id = prl.requisition_header_id
                                   AND trx_line_id = prl.requisition_line_id
                                   --  AND application_id = 222
                                   AND ROWNUM = 1)
                               tax_rate_code,
                           (SELECT tax_regime_code
                              FROM apps.zx_lines
                             WHERE     trx_id = prl.requisition_header_id
                                   AND trx_line_id = prl.requisition_line_id
                                   --  AND application_id = 222
                                   AND ROWNUM = 1)
                               tax_regime_code,
                           NULL
                               gapless_sequence_number -- Added as per CCR0009857
                      FROM oe_order_headers_all ooh, oe_order_lines_all ool, oe_transaction_types_tl ottl,
                           po_requisition_lines_all prl, po_requisition_headers_all prh, hr_operating_units hou,
                           org_organization_definitions ood, mtl_system_items_b mtl, apps.ap_suppliers aps,
                           --Start Added for 1.1
                           fnd_flex_value_sets ffvs, fnd_flex_values ffv
                     --End Added for 1.1
                     WHERE     ooh.order_type_id =
                               TO_NUMBER (ottl.transaction_type_id)
                           AND ottl.NAME = 'DC to DC Transfer - Macau EMEA' --1925
                           AND ottl.LANGUAGE = 'US'
                           AND ooh.header_id = ool.header_id
                           AND prl.requisition_line_id =
                               ool.source_document_line_id
                           AND prl.requisition_header_id =
                               ool.source_document_id
                           AND prl.requisition_header_id =
                               prh.requisition_header_id
                           AND hou.organization_id = ooh.org_id
                           AND ood.organization_id = ool.ship_from_org_id
                           AND mtl.inventory_item_id = ool.inventory_item_id
                           AND mtl.organization_id = ool.ship_from_org_id
                           AND aps.vendor_id(+) = prl.vendor_id
                           --Start Added for 1.1
                           --AND hou.NAME = pv_operating_unit
                           AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND flex_value_set_name =
                               'XXD_INTRASTAT_MTD_OU_VS'
                           AND ffv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           ffv.start_date_active,
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           ffv.end_date_active,
                                                           TRUNC (SYSDATE))
                           AND ffv.flex_value <> 'ALL EMEA'
                           AND hou.name = ffv.flex_value
                           AND hou.name =
                               DECODE (pv_operating_unit,
                                       'ALL EMEA', ffv.flex_value,
                                       pv_operating_unit)
                           --End Added for 1.1
                           AND prh.creation_date BETWEEN pd_invoice_date_from
                                                     AND pd_invoice_date_to
                           AND prl.need_by_date BETWEEN NVL (
                                                            pd_gl_posted_from,
                                                            prl.need_by_date)
                                                    AND NVL (
                                                            pd_gl_posted_to,
                                                            prl.need_by_date))
             WHERE     entitycode = NVL (pv_company_code, entitycode)
                   AND NVL (tax_rate_code, 'XXX') =
                       NVL (pv_tax_code, NVL (tax_rate_code, 'XXX'))
                   AND NVL (tax_regime_code, 'XXX') =
                       NVL (pv_tax_regime_code, NVL (tax_regime_code, 'XXX'))
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_EU_COUNTRY_LIST'
                                   AND LANGUAGE = USERENV ('Lang')
                                   AND lookup_code = memberstateofdestination
                                   AND enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE)))
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values
                             WHERE     lookup_type =
                                       'XXDO_INTRASTAT_EU_COUNTRY_LIST'
                                   AND LANGUAGE = USERENV ('Lang')
                                   AND lookup_code = memberstateofconsigment
                                   AND enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   start_date_active,
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   end_date_active,
                                                                   TRUNC (
                                                                       SYSDATE)))
                   AND memberstateofconsigment <> memberstateofdestination;

        TYPE fetch_data IS TABLE OF ar_rep_cur%ROWTYPE;

        fetch_cur_data         fetch_data;
        v_header               VARCHAR2 (2000);
        lv_line                VARCHAR2 (4000);
        ln_cnt                 NUMBER := 0;
        lv_err_msg             VARCHAR2 (4000);
    BEGIN
        IF pv_final_mode = 'N'
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   'EntityCode'
                || '|'
                || 'Flow'
                || '|'
                || 'CommodityCode'
                || '|'
                || 'PartnerVATNumber'
                || '|'
                || 'PartnerCountry'
                || '|'
                || 'NatureTransaction'
                || '|'
                || 'CalendarMonth'
                || '|'
                || 'CalendarYear'
                || '|'
                || 'ValueSupplyLocalCurrency'
                || '|'
                || 'MemberStateOfDestination'
                || '|'
                || 'MemberStateOfConsigment'
                || '|'
                || 'CountryOfOrigin'
                || '|'
                || 'StatisticalValue'
                || '|'
                || 'Quantity'
                || '|'
                || 'SupplementaryUnits'
                || '|'
                || 'RegionOfOrigin'
                || '|'
                || 'RegionOfDestination'
                || '|'
                || 'GoodsDescription'
                || '|'
                || 'GLDate'
                || '|'
                || 'ModeTransport'
                || '|'
                || 'CustomerVATNumber'
                || '|'
                || 'SupplierVATNumber'
                || '|'
                || 'InvoiceDate'
                || '|'
                || 'InvoiceID'
                || '|'
                || 'DeliveryTerms'
                || '|'
                || 'TransactionAmountGross'
                || '|'
                || 'TransactionAmountTax'
                || '|'
                --Start Added for 1.1
                || 'Tax_country'
                || '|'
                --End Added for 1.1
                || 'TaxRateCode'
                || '|'
                || 'AccountingDate'
                || '|'
                || 'Currency'
                || '|'
                || 'CustomerJurisdictionID'
                || '|'
                || 'SupplierJurisdictionID'
                || '|'
                || 'SupplierName'
                || '|'
                || 'CustomerName'
                || '|'
                || 'TransactionCurrency'
                || '|'
                || 'TransactionExRate'
                || '|'
                || 'Net mass'
                || '|'
                || 'Gapless_Sequence_Number'        -- Added as per CCR0009857
                                            );

            FOR i IN ar_rep_cur
            LOOP
                apps.fnd_file.put_line (apps.fnd_file.output, i.rep_data);
            END LOOP;
        END IF;

        IF pv_final_mode = 'Y'
        THEN
            BEGIN
                v_header   :=
                       'EntityCode'
                    || '|'
                    || 'Flow'
                    || '|'
                    || 'CommodityCode'
                    || '|'
                    || 'PartnerVATNumber'
                    || '|'
                    || 'PartnerCountry'
                    || '|'
                    || 'NatureTransaction'
                    || '|'
                    || 'CalendarMonth'
                    || '|'
                    || 'CalendarYear'
                    || '|'
                    || 'ValueSupplyLocalCurrency'
                    || '|'
                    || 'MemberStateOfDestination'
                    || '|'
                    || 'MemberStateOfConsigment'
                    || '|'
                    || 'CountryOfOrigin'
                    || '|'
                    || 'StatisticalValue'
                    || '|'
                    || 'Quantity'
                    || '|'
                    || 'SupplementaryUnits'
                    || '|'
                    || 'RegionOfOrigin'
                    || '|'
                    || 'RegionOfDestination'
                    || '|'
                    || 'GoodsDescription'
                    || '|'
                    || 'GLDate'
                    || '|'
                    || 'ModeTransport'
                    || '|'
                    || 'CustomerVATNumber'
                    || '|'
                    || 'SupplierVATNumber'
                    || '|'
                    || 'InvoiceDate'
                    || '|'
                    || 'InvoiceID'
                    || '|'
                    || 'DeliveryTerms'
                    || '|'
                    || 'TransactionAmountGross'
                    || '|'
                    || 'TransactionAmountTax'
                    || '|'
                    --Start Added for 1.1
                    || 'Tax_country'
                    || '|'
                    --End Added for 1.1
                    || 'TaxRateCode'
                    || '|'
                    || 'AccountingDate'
                    || '|'
                    || 'Currency'
                    || '|'
                    || 'CustomerJurisdictionID'
                    || '|'
                    || 'SupplierJurisdictionID'
                    || '|'
                    || 'SupplierName'
                    || '|'
                    || 'CustomerName'
                    || '|'
                    || 'TransactionCurrency'
                    || '|'
                    || 'TransactionExRate'
                    || '|'
                    || 'Net mass'
                    || '|'
                    || 'Gapless_Sequence_Number'    -- Added as per CCR0009857
                                                ;
                lv_output_file   :=
                    UTL_FILE.fopen (pv_directory_name, lv_outbound_file, 'W' --opening the file in write mode
                                                                            );

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    UTL_FILE.put_line (lv_output_file, v_header);

                    FOR ar_rep IN ar_rep_cur
                    LOOP
                        lv_line   := ar_rep.rep_data;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                        ln_cnt    := ln_cnt + 1;
                    END LOOP;
                ELSE
                    lv_err_msg   :=
                        SUBSTR (
                               'Error in Opening the INTRASTAT_EMEA_Report file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    -- pn_retcode := gn_error;
                    RETURN;
                END IF;

                UTL_FILE.fclose (lv_output_file);
            EXCEPTION
                WHEN UTL_FILE.invalid_path
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_PATH: File location or filename was invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    -- lv_status:='E';
                    raise_application_error (-20001, lv_err_msg);
                WHEN UTL_FILE.invalid_mode
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    -- lv_status:='E';
                    raise_application_error (-20002, lv_err_msg);
                WHEN UTL_FILE.invalid_filehandle
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_FILEHANDLE: The file handle was invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --lv_status:='E';
                    raise_application_error (-20003, lv_err_msg);
                WHEN UTL_FILE.invalid_operation
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_OPERATION: The file could not be opened or operated on as requested.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    -- lv_status:='E';
                    raise_application_error (-20004, lv_err_msg);
                WHEN UTL_FILE.read_error
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'READ_ERROR: An operating system error occurred during the read operation.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --  lv_status:='E';
                    raise_application_error (-20005, lv_err_msg);
                WHEN UTL_FILE.write_error
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'WRITE_ERROR: An operating system error occurred during the write operation.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --    lv_status:='E';
                    raise_application_error (-20006, lv_err_msg);
                WHEN UTL_FILE.internal_error
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INTERNAL_ERROR: An unspecified error in PL/SQL.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --  lv_status:='E';
                    raise_application_error (-20007, lv_err_msg);
                WHEN UTL_FILE.invalid_filename
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'INVALID_FILENAME: The filename parameter is invalid.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --    lv_status:='E';
                    raise_application_error (-20008, lv_err_msg);
                WHEN OTHERS
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        UTL_FILE.fclose (lv_output_file);
                    END IF;

                    lv_err_msg   :=
                        'Error while creating or writing the data into the file.';
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    --  lv_status:='E';
                    raise_application_error (-20009, lv_err_msg);
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Exception While Printing MTD AR Report' || SQLERRM);
    END mtd_intrastat_rep;
END xxd_p2p_intrastat_mtd_rep_pkg;
/
