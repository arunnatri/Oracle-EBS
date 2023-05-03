--
-- XXD_ONT_SO_ACK_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SO_ACK_PKG"
AS
    /***********************************************************************************************
    * Package         : XXD_ONT_SO_ACK_PKG
    * Description     : This package is used for SOA and SOC Reports- US\CA\EMEA
    * Notes           :
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    * Date         Version#      Name                       Description
    *-----------------------------------------------------------------------------------------------
    * 07-NOV-2017  1.0           Viswanathan Pandian        Initial Version for CCR0006637
    * 07-FEB-2018  1.1           Viswanathan Pandian        Updated for CCR0007056
    * 23-MAR-2018  1.2           Aravind Kannuri            Updated for CCR0007091
    * 13-APR-2018  1.3           Aravind Kannuri            Updated for CCR0007072
    * 08-AUG-2018  1.4           Aravind Kannuri            Updated for CCR0007433
    * 29-NOV-2018  1.5           Aravind Kannuri            Updated for CCR0007586 and Redesign of Parameters
    * 20-Jul-2020  1.6           Viswanathan Pandian        Updated for CCR0008411
    * 20-Jul-2020  1.7           Viswanathan Pandian        Updated for CCR0009148
    * 04-Jun-2021  1.8           Aravind Kannuri            Updated for CCR0009343
    * 08-Nov-2021  1.9           Aravind Kannuri            Updated for CCR0009673
    ************************************************************************************************/
    FUNCTION validate_parameters
        RETURN BOOLEAN
    AS
    BEGIN
        -- Start changes for CCR0008411
        /*IF     p_order_number_from IS NULL
           AND p_order_number_to IS NULL
           AND p_ordered_date_from IS NULL
           AND p_ordered_date_to IS NULL
           AND p_request_date_from IS NULL
           AND p_request_date_to IS NULL
           AND p_sch_ship_date_from IS NULL
           AND p_sch_ship_date_to IS NULL
        THEN
           fnd_file.put_line (fnd_file.LOG,
                              'Please specify Order Range or Date Range');
           RETURN FALSE;
        END IF;*/
        IF NVL (p_valid_param, 0) <> 1
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Please specify Customer or Cust PO Number or Order number range or any one of the date ranges');
            RETURN FALSE;
        END IF;

        -- End changes for CCR0008411

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in VALIDATE_PARAMETERS: ' || SQLERRM);
            RETURN FALSE;
    END validate_parameters;

    FUNCTION build_where_clause
        RETURN BOOLEAN
    AS
        lc_division_gender   VARCHAR2 (100);
    BEGIN
        --Print Parameters in LOG
        fnd_file.put_line (fnd_file.LOG, 'p_org_id => ' || p_org_id);
        fnd_file.put_line (fnd_file.LOG, 'p_brand => ' || p_brand);
        fnd_file.put_line (fnd_file.LOG, 'p_send_email => ' || p_send_email);
        fnd_file.put_line (fnd_file.LOG,
                           'p_print_new_orders => ' || p_print_new_orders);
        fnd_file.put_line (fnd_file.LOG,
                           'p_open_orders => ' || p_open_orders);
        fnd_file.put_line (fnd_file.LOG,
                           'p_cust_account_id => ' || p_cust_account_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_order_type_id => ' || p_order_type_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_cust_po_num => ' || p_cust_po_num);
        fnd_file.put_line (fnd_file.LOG,
                           'p_booked_status => ' || p_booked_status);
        fnd_file.put_line (fnd_file.LOG,
                           'p_salesrep_id => ' || p_salesrep_id);
        fnd_file.put_line (fnd_file.LOG, 'p_department => ' || p_department); --Added for CCR0009343
        fnd_file.put_line (
            fnd_file.LOG,
               'p_order_number_from => '
            || p_order_number_from
            || ' AND p_order_number_to => '
            || p_order_number_to);
        fnd_file.put_line (
            fnd_file.LOG,
               'p_ordered_date_from => '
            || p_ordered_date_from
            || ' AND p_ordered_date_to => '
            || p_ordered_date_to);
        fnd_file.put_line (
            fnd_file.LOG,
               'p_request_date_from => '
            || p_request_date_from
            || ' AND p_request_date_to => '
            || p_request_date_to);
        fnd_file.put_line (
            fnd_file.LOG,
               'p_sch_ship_date_from => '
            || p_sch_ship_date_from
            || ' AND p_sch_ship_date_to => '
            || p_sch_ship_date_to);

        -- Org Id
        gc_where_clause   :=
            gc_where_clause || ' AND ooha.org_id = ' || p_org_id;

        -- Brand
        gc_where_clause   :=
            gc_where_clause || ' AND ooha.attribute5 = ''' || p_brand || '''';

        -- Print New Orders
        IF p_print_new_orders = 'Y' AND p_mode = 'ACK'
        THEN
            gc_where_clause   :=
                gc_where_clause || ' AND ooha.first_ack_date IS NULL';
        ELSIF p_print_new_orders = 'Y' AND p_mode = 'CONF'
        THEN
            gc_where_clause   :=
                gc_where_clause || ' AND ooha.last_ack_date IS NULL';
        END IF;

        -- Open Orders
        IF p_open_orders = 'Y'
        THEN
            gc_where_clause   :=
                gc_where_clause || ' AND ooha.open_flag = ''Y''';
        END IF;

        -- Booked Status
        IF p_booked_status = 'Y'
        THEN
            gc_where_clause   :=
                gc_where_clause || ' AND ooha.flow_status_code = ''BOOKED''';
        END IF;

        -- Order Type
        IF p_order_type_id IS NOT NULL
        THEN
            gc_where_clause   :=
                   gc_where_clause
                || ' AND ooha.order_type_id = '
                || p_order_type_id;
        END IF;

        -- Customer PO Number
        IF p_cust_po_num IS NOT NULL
        THEN
            gc_where_clause   :=
                   gc_where_clause
                || ' AND ooha.cust_po_number = '''
                || p_cust_po_num
                || '''';
        END IF;

        -- Cust Account ID
        IF p_cust_account_id IS NOT NULL
        THEN
            gc_where_clause   :=
                   gc_where_clause
                || ' AND ooha.sold_to_org_id = '
                || p_cust_account_id;
        END IF;

        -- Ship To Org ID
        IF p_ship_to_org_id IS NOT NULL
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'p_ship_to_org_id => ' || p_ship_to_org_id);
            gc_where_clause   :=
                   gc_where_clause
                || ' AND ooha.ship_to_org_id = '
                || p_ship_to_org_id;
        END IF;

        -- Ship To City
        IF p_ship_to_city IS NOT NULL
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'p_ship_to_city => ' || p_ship_to_city);
            gc_where_clause   :=
                   gc_where_clause
                || ' AND ooha.ship_to_org_id IN (SELECT site_use_id '
                || ' FROM XXD_ONT_SOAC_SHIP_LOC_V WHERE cust_account_id = '
                || p_cust_account_id
                || ' AND city = '''
                || p_ship_to_city
                || ''')';                            -- Added ) for CCR0009148
        END IF;

        -- Order Number
        IF p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL
        THEN
            gc_where_clause   :=
                   gc_where_clause
                || ' AND ooha.order_number BETWEEN '
                || p_order_number_from
                || ' AND '
                || p_order_number_to;
        END IF;

        -- Ordered Date
        IF p_ordered_date_from IS NOT NULL AND p_ordered_date_to IS NOT NULL
        THEN
            --Removed TRUNC for ordered_date for CCR0009673(Performance Improvisation)
            gc_where_clause   :=
                   gc_where_clause
                || ' AND ooha.ordered_date BETWEEN fnd_date.canonical_to_date ( '''
                || p_ordered_date_from
                || ''' )  AND fnd_date.canonical_to_date ( '''
                || p_ordered_date_to
                || ''' ) ';
        END IF;

        -- Start changes for CCR0007091
        -- Order Type Exclusion
        gc_where_clause   :=
               gc_where_clause
            || ' AND NOT EXISTS (SELECT 1 FROM fnd_lookup_values flv '
            || ' WHERE flv.lookup_type = ''XXD_ONT_SOA_SOC_ORD_TYPE_EXCL'''
            || ' AND flv.LANGUAGE = USERENV (''LANG'') '
            || ' AND flv.enabled_flag = ''Y'''
            || ' AND flv.attribute_category = ''XXD_ONT_SOA_SOC_ORD_TYPE_EXCL'''
            || ' AND TRUNC (SYSDATE) BETWEEN TRUNC (NVL (flv.start_date_active, SYSDATE)) '
            || ' AND TRUNC (NVL (flv.end_date_active, SYSDATE)) '
            || ' AND ooha.order_type_id = TO_NUMBER (flv.lookup_code) '
            || ' AND (   ( '
            || ''''
            || p_mode
            || ''' = ''ACK'' AND flv.attribute1 = ''Y'') '
            || ' OR ( '
            || ''''
            || p_mode
            || ''' = ''CONF'' AND flv.attribute2 = ''Y'')) ) ';
        -- End changes for CCR0007091

        -- Start changes for CCR0007072
        -- Customer Exclusion
        gc_where_clause   :=
               gc_where_clause
            || ' AND NOT EXISTS (SELECT 1 FROM fnd_lookup_values flv '
            || ' WHERE flv.lookup_type = ''XXD_ONT_SOA_SOC_CUSTOMER_EXCL'''
            || ' AND flv.LANGUAGE = USERENV (''LANG'') '
            || ' AND flv.enabled_flag = ''Y'''
            || ' AND flv.attribute_category = ''XXD_ONT_SOA_SOC_CUSTOMER_EXCL'''
            || ' AND TRUNC (SYSDATE) BETWEEN TRUNC (NVL (flv.start_date_active, SYSDATE)) '
            || ' AND TRUNC (NVL (flv.end_date_active, SYSDATE)) '
            || ' AND ooha.sold_to_org_id = TO_NUMBER (flv.attribute1) '
            || ' AND (   ( '
            || ''''
            || p_mode
            || ''' = ''ACK'' AND flv.attribute2 = ''Y'') '
            || ' OR ( '
            || ''''
            || p_mode
            || ''' = ''CONF'' AND flv.attribute3 = ''Y'')) ) ';

        -- End changes for CCR0007072

        -- Order Line Parameters
        IF    (p_request_date_from IS NOT NULL AND p_request_date_to IS NOT NULL)
           OR (p_sch_ship_date_from IS NOT NULL AND p_sch_ship_date_to IS NOT NULL)
           OR (p_salesrep_id IS NOT NULL)
           OR (p_mode = 'CONF')
           OR (p_department IS NOT NULL)                --Added for CCR0009343
           OR (p_division_gender <> 'ALL')
        THEN
            gc_where_clause      :=
                   gc_where_clause
                || ' AND EXISTS (SELECT 1 FROM oe_order_lines_all oola, xxd_common_items_v xciv '
                || ' WHERE oola.header_id = ooha.header_id '
                || ' AND oola.inventory_item_id = xciv.inventory_item_id '
                || ' AND oola.ship_from_org_id  = xciv.organization_id '
                || ' AND oola.cancelled_flag <> ''Y''';

            -- Request Date
            IF     p_request_date_from IS NOT NULL
               AND p_request_date_to IS NOT NULL
            THEN
                gc_where_clause   :=
                       gc_where_clause
                    || ' AND oola.request_date BETWEEN fnd_date.canonical_to_date ( '''
                    || p_request_date_from
                    || ''' ) AND  fnd_date.canonical_to_date ( '''
                    || p_request_date_to
                    || ''' ) ';
            END IF;

            -- Schedule Ship Date
            IF     p_sch_ship_date_from IS NOT NULL
               AND p_sch_ship_date_to IS NOT NULL
            THEN
                gc_where_clause   :=
                       gc_where_clause
                    || ' AND TRUNC (oola.schedule_ship_date) BETWEEN fnd_date.canonical_to_date ( '''
                    || p_sch_ship_date_from
                    || ''' ) AND  fnd_date.canonical_to_date ( '''
                    || p_sch_ship_date_to
                    || ''' ) ';
            END IF;

            -- Sales Rep
            IF p_salesrep_id IS NOT NULL
            THEN
                gc_where_clause   :=
                       gc_where_clause
                    || ' AND oola.salesrep_id = '
                    || p_salesrep_id;
            END IF;

            -- Start changes for CCR0007433
            -- Exclude NEW Calloff Order Lines is 'In-Complete'
            IF p_mode = 'CONF'
            THEN
                gc_where_clause   :=
                       gc_where_clause
                    || ' AND NVL(oola.global_attribute19, ''N'') <> ''NEW''';
            END IF;

            -- End changes for CCR0007433

            -- Start changes for CCR0009343
            -- Department
            IF p_department IS NOT NULL
            THEN
                gc_where_clause   :=
                       gc_where_clause
                    || ' AND xciv.department = '''
                    || p_department
                    || '''';
            END IF;

            -- End changes for CCR0009343

            -- Start changes for CCR0007586
            lc_division_gender   := REPLACE (p_division_gender, '''', '-');

            -- Division/Gender
            IF p_division_gender <> 'ALL'
            THEN
                gc_where_clause   :=
                       gc_where_clause
                    || ' AND REPLACE (xciv.division, CHR (39), CHR (45)) = '''
                    || lc_division_gender
                    || '''';
            END IF;

            -- End changes for CCR0007586

            -- Add Org
            gc_where_clause      :=
                gc_where_clause || ' AND oola.org_id = ' || p_org_id || ')';
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in BUILD_WHERE_CLAUSE: ' || SQLERRM);
            RETURN FALSE;
    END build_where_clause;

    FUNCTION lang_code (
        p_site_use_id IN hz_cust_site_uses_all.site_use_id%TYPE)
        RETURN VARCHAR2
    AS
        -- Start changes for CCR0007091
        CURSOR get_override_lang IS
            SELECT UPPER (attribute2) override_lang
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_ONT_SOA_SOC_LANG_OVERRIDE'
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND flv.attribute_category =
                       'XXD_ONT_SOA_SOC_LANG_OVERRIDE'
                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                   NVL (
                                                       flv.start_date_active,
                                                       SYSDATE))
                                           AND TRUNC (
                                                   NVL (flv.end_date_active,
                                                        SYSDATE))
                   AND TO_NUMBER (flv.attribute1) IN
                           (SELECT hca.cust_account_id
                              FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcsa, hz_cust_accounts hca
                             WHERE     hcsu.cust_acct_site_id =
                                       hcsa.cust_acct_site_id
                                   AND hcsa.cust_account_id =
                                       hca.cust_account_id
                                   AND hcsa.status = 'A'
                                   AND hcsu.site_use_id = p_site_use_id);

        -- End changes for CCR0007091

        CURSOR get_lang_code IS
            SELECT UPPER (hcsa.attribute9) site_lang, UPPER (hca.attribute17) cust_lang
              FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcsa, hz_cust_accounts hca
             WHERE     hcsu.cust_acct_site_id = hcsa.cust_acct_site_id
                   AND hcsa.cust_account_id = hca.cust_account_id
                   AND hcsa.status = 'A'
                   AND hcsu.site_use_id = p_site_use_id;

        lc_return_value     VARCHAR2 (100);
        lc_site_lang_code   VARCHAR2 (100);
        lc_cust_lang_code   VARCHAR2 (100);
        lc_override_lang    VARCHAR2 (100);            -- Added for CCR0007091
        lcu_lang_code       get_lang_code%ROWTYPE;
    BEGIN
        -- Start changes for CCR0007091
        OPEN get_override_lang;

        FETCH get_override_lang INTO lc_override_lang;

        CLOSE get_override_lang;

        IF lc_override_lang IS NOT NULL
        THEN
            lc_return_value   := lc_override_lang;
        ELSE
            -- End changes for CCR0007091

            OPEN get_lang_code;

            FETCH get_lang_code INTO lcu_lang_code;

            CLOSE get_lang_code;

            -- Cust Site Language
            IF lcu_lang_code.site_lang IN ('EN', 'US', 'EN-US',
                                           'EN_CA', 'EN_GB', 'EN_US')
            THEN
                lc_site_lang_code   := 'EN';
            ELSIF lcu_lang_code.site_lang IN ('FR', 'FR_FR', 'FR_CA')
            THEN
                lc_site_lang_code   := 'FR';
            ELSIF lcu_lang_code.site_lang IN ('DU', 'NL', 'NL_NL')
            THEN
                lc_site_lang_code   := 'DU';
            ELSIF lcu_lang_code.site_lang IN ('DE', 'DE_DE')
            THEN
                lc_site_lang_code   := 'DE';
            END IF;

            -- Cust Language
            IF lcu_lang_code.cust_lang IN ('EN', 'US', 'EN-US',
                                           'EN_CA', 'EN_GB', 'EN_US')
            THEN
                lc_cust_lang_code   := 'EN';
            ELSIF lcu_lang_code.cust_lang IN ('FR', 'FR_FR', 'FR_CA')
            THEN
                lc_cust_lang_code   := 'FR';
            ELSIF lcu_lang_code.cust_lang IN ('DU', 'NL', 'NL_NL')
            THEN
                lc_cust_lang_code   := 'DU';
            ELSIF lcu_lang_code.cust_lang IN ('DE', 'DE_DE')
            THEN
                lc_cust_lang_code   := 'DE';
            END IF;

            lc_return_value   :=
                NVL (lc_site_lang_code, NVL (lc_cust_lang_code, 'EN'));
        END IF;                                        -- Added for CCR0007091

        RETURN lc_return_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END lang_code;

    FUNCTION format_address (
        p_site_use_id IN hz_cust_site_uses_all.site_use_id%TYPE)
        RETURN VARCHAR2
    AS
        CURSOR get_location_id IS
            SELECT hl.location_id
              FROM hz_cust_site_uses_all hcsu, hz_cust_acct_sites_all hcas, hz_party_sites hps,
                   hz_locations hl
             WHERE     hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                   AND hcas.party_site_id = hps.party_site_id
                   AND hps.location_id = hl.location_id
                   AND hcsu.site_use_id = p_site_use_id;

        ln_location_id                hz_locations.location_id%TYPE;
        lx_return_status              VARCHAR2 (1);
        lx_msg_count                  NUMBER;
        lx_msg_data                   VARCHAR2 (4000);
        lx_billto_formatted_address   VARCHAR2 (4000);
        lx_shipto_formatted_address   VARCHAR2 (4000);
        lx_formatted_lines_cnt        NUMBER;
        lx_formatted_address_tbl      hz_format_pub.string_tbl_type;
    BEGIN
        OPEN get_location_id;

        FETCH get_location_id INTO ln_location_id;

        CLOSE get_location_id;

        hz_format_pub.format_address (
            p_location_id             => ln_location_id,
            p_style_code              => 'POSTAL_ADDR',
            p_style_format_code       => 'POSTAL_ADDR_DEF',
            p_line_break              => CHR (10),
            p_space_replace           => NULL,
            p_to_language_code        => NULL,
            p_country_name_lang       => NULL,
            p_from_territory_code     => NULL,
            x_return_status           => lx_return_status,
            x_msg_count               => lx_msg_count,
            x_msg_data                => lx_msg_data,
            x_formatted_address       => lx_billto_formatted_address,
            x_formatted_lines_cnt     => lx_formatted_lines_cnt,
            x_formatted_address_tbl   => lx_formatted_address_tbl);

        IF lx_return_status <> 'S'
        THEN
            lx_billto_formatted_address   := NULL;
        END IF;

        RETURN lx_billto_formatted_address;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in FORMAT_ADDRESS: ' || SQLERRM);
            RETURN NULL;
    END format_address;

    FUNCTION get_vat (p_bill_to_site_use_id hz_cust_site_uses_all.site_use_id%TYPE, p_ship_to_site_use_id hz_cust_site_uses_all.site_use_id%TYPE)
        RETURN VARCHAR2
    AS
        CURSOR get_vat_c IS
            SELECT NVL (hcsu_ship.tax_reference, hcsu_bill.tax_reference)
              FROM hz_parties hp, hz_cust_accounts hca, hz_cust_acct_sites_all hcas,
                   hz_cust_site_uses_all hcsu_bill, hz_cust_site_uses_all hcsu_ship
             WHERE     hp.party_id = hca.party_id
                   AND hca.cust_account_id = hcas.cust_account_id
                   AND hcas.cust_acct_site_id = hcsu_bill.cust_acct_site_id
                   AND hcas.cust_acct_site_id = hcsu_ship.cust_acct_site_id
                   AND hcsu_bill.cust_acct_site_id =
                       hcsu_ship.cust_acct_site_id
                   AND hcsu_bill.site_use_id = p_bill_to_site_use_id
                   AND hcsu_ship.site_use_id = p_ship_to_site_use_id;

        lc_return_value   VARCHAR2 (1000);
    BEGIN
        OPEN get_vat_c;

        FETCH get_vat_c INTO lc_return_value;

        CLOSE get_vat_c;

        RETURN lc_return_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_vat;

    FUNCTION get_buyer_group_details (p_cust_account_id IN hz_cust_accounts.cust_account_id%TYPE, p_output_type IN VARCHAR2)
        RETURN VARCHAR2
    AS
        CURSOR get_buyer_group_details_c IS
            SELECT hca.account_number, hcara.comments member_number
              FROM hz_cust_accounts hca, hz_cust_acct_relate_all hcara, hz_cust_accounts hca_rel
             WHERE     hca.cust_account_id = hcara.cust_account_id
                   AND hca_rel.cust_account_id =
                       hcara.related_cust_account_id
                   AND hcara.status = 'A'
                   AND REGEXP_SUBSTR (hca.account_number, '[^-]+', 1,
                                      1) != REGEXP_SUBSTR (hca_rel.account_number, '[^-]+', 1
                                                           , 1)
                   AND hca.cust_account_id = p_cust_account_id;

        buyer_group_details_rec   get_buyer_group_details_c%ROWTYPE;
        lc_return_value           VARCHAR2 (1000);
    BEGIN
        OPEN get_buyer_group_details_c;

        LOOP
            FETCH get_buyer_group_details_c INTO buyer_group_details_rec;

            EXIT WHEN get_buyer_group_details_c%NOTFOUND;

            IF get_buyer_group_details_c%ROWCOUNT = 1
            THEN
                lc_return_value   :=
                    CASE
                        WHEN p_output_type = 'BUYER'
                        THEN
                            buyer_group_details_rec.account_number
                        ELSE
                            buyer_group_details_rec.member_number
                    END;
            ELSIF get_buyer_group_details_c%ROWCOUNT > 1
            THEN
                lc_return_value   :=
                    CASE
                        WHEN p_output_type = 'BUYER' THEN 'Multiple'
                        ELSE NULL
                    END;
            ELSIF get_buyer_group_details_c%ROWCOUNT = 0
            THEN
                lc_return_value   :=
                    CASE
                        WHEN p_output_type = 'BUYER' THEN 'Unidentified'
                        ELSE NULL
                    END;
            END IF;
        END LOOP;

        CLOSE get_buyer_group_details_c;

        RETURN lc_return_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_buyer_group_details;

    FUNCTION submit_bursting
        RETURN BOOLEAN
    AS
        lb_result   BOOLEAN;
        ln_req_id   NUMBER;
        ln_count    NUMBER := 0;                       -- Added for CCR0007056
    BEGIN
        -- Updating Ack Dates in Order
        --Commented for CCR0007072
        --IF p_mode = 'ACK'

        -- Start changes for CCR0007072
        IF p_mode = 'ACK' AND p_send_email = 'Y'
        -- End changes for CCR0007072
        THEN
            EXECUTE IMMEDIATE   'UPDATE oe_order_headers_all ooha SET ooha.first_ack_date = SYSDATE WHERE 1=1 '
                             || gc_where_clause;
        ELSIF p_mode = 'CONF' AND p_send_email = 'Y'
        THEN
            EXECUTE IMMEDIATE   'UPDATE oe_order_headers_all ooha SET ooha.last_ack_date = SYSDATE WHERE 1=1 '
                             || gc_where_clause;
        END IF;

        -- Start changes for CCR0007056
        ln_count   := SQL%ROWCOUNT;

        --Commented for CCR0007072
        --IF ln_count > 0

        -- Start changes for CCR0007072
        IF ln_count > 0 AND p_send_email = 'Y'
        -- End changes for CCR0007072
        THEN
            -- End changes for CCR0007056
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
                lb_result   := TRUE;
            ELSE
                fnd_file.put_line (fnd_file.LOG,
                                   'Failed to launch bursting request');
                lb_result   := FALSE;
            END IF;

            RETURN lb_result;
        -- Start changes for CCR0007056
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'No Data Found\Send Email set to No');
            RETURN TRUE;
        END IF;
    -- End changes for CCR0007056
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in SUBMIT_BURSTING: ' || SQLERRM);
            RETURN FALSE;
    END submit_bursting;
BEGIN
    --To get Master Organization ID
    SELECT organization_id
      INTO gn_master_org_id
      FROM mtl_parameters
     WHERE organization_code = 'MST';
EXCEPTION
    WHEN OTHERS
    THEN
        gn_master_org_id   := NULL;
END xxd_ont_so_ack_pkg;
/
