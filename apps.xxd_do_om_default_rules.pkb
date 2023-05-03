--
-- XXD_DO_OM_DEFAULT_RULES  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_DO_OM_DEFAULT_RULES"
AS
    /*******************************************************************************
    * Program Name : XXD_DO_OM_DEFAULT_RULES
    * Language     : PL/SQL
    * Description  : This package will be Used for OM Defaulting Rules
    *
    * History      :
    *
    * WHO                 WHAT              Desc                                               WHEN
    * -------------- ------------------------------------------------------------------- ---------------
    *  BT Tech Team        1.0                                                               12-JAN-2015
    *  Jerry Ni            1.1           Add new procedure ret_warehouse                     30-APR-2015
    *  Infosys             1.2           Added new function get_def_latest_accep_date        06-DEC-2017
    *  Arun N Murthy       1.3           Updated for CCR0007043                              07-MAR-2018
    *  Tejaswi Gangumalla  1.4           Updated for CCR0007850                              18-APR-2019
    *  Viswanathan Pandian 1.5           Updated for CCR0008531                              24-MAR-2020
    *  Greg Jensen         1.6           Updated for CCR0008530                              26-MAR-2020
    *  Gaurav joshi        1.7           Updated for CCR0008657                              21-AUG-2020
    *  Jayarajan A K       1.8           Updated for DXLabs Changes CCR0009018               26-NOV-2020
    *  Gaurav joshi        1.9           Updated for CCR0008870                              29-JUN-2021
    *  Aravind Kannuri   1.10          Updated for CCR0009197                              05-JUL-2021
    *  Laltu               1.11          Updated for CCR0009521                              01-SEP-2021
    * Gaurav Joshi         1.12          Updated for US6 CCR0009841                          28-feb-2022
    * ----------------------------------------------------------------------------------------------------- */

    -- PRICE LIST Header

    FUNCTION ret_hpricelist (p_database_object_name   IN VARCHAR2,
                             p_attribute_code         IN VARCHAR2)
        RETURN NUMBER
    IS
        l_header_rec        oe_ak_order_headers_v%ROWTYPE;
        v_class_code        VARCHAR2 (30) := NULL;
        v_brand             VARCHAR2 (150) := NULL;
        v_price_list_name   VARCHAR2 (150) := NULL;
        v_price_list        NUMBER := NULL;
        -- v_price_list        VARCHAR2 (150)                   := NULL;
        v_org_name          VARCHAR2 (50);
        l_line_rec          oe_ak_order_lines_v%ROWTYPE;
    BEGIN
        l_header_rec   := ont_header_def_hdlr.g_record;
        l_line_rec     := ont_line_def_hdlr.g_record;

        --IF l_header_rec.sold_to_org_id IS NOT NULL
        IF     l_header_rec.request_date IS NOT NULL
           AND l_header_rec.sold_to_org_id IS NOT NULL
        THEN
            BEGIN
                SELECT hca.attribute1, hca.customer_class_code
                  INTO v_brand, v_class_code
                  FROM hz_cust_accounts hca
                 WHERE hca.cust_account_id = l_header_rec.sold_to_org_id; --42054;
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_brand        := NULL;
                    v_class_code   := NULL;
            END;

            SELECT name
              INTO v_org_name
              FROM hr_operating_units
             WHERE organization_id = l_header_rec.org_id;

            /*insert into xx_test1 values('A',v_org_name);
            commit;*/

            /* IF l_header_rec.request_date > SYSDATE
            THEN
               l_header_rec.request_date := SYSDATE;
            END IF;*/

            --Start Commented by BT Technology Team 01-May-2015
            --xxd_default_pricelist_matrix is obselete now. Defaulting will be done now from Oracle Standard Defaulting Rules.
            /*IF v_brand IS NOT NULL AND v_class_code IS NOT NULL
            THEN
               BEGIN

                     SELECT  distinct qlh.list_header_id
                     INTO v_price_list
                     FROM apps.xxd_default_pricelist_matrix xt, apps.qp_list_headers_vl qlh
                     WHERE brand = v_brand
                    AND TO_CHAR(TRUNC(l_header_rec.ordered_date),'DD-MON-YYYY') BETWEEN TO_CHAR(xt.order_start_date,'DD-MON-YYYY') AND TO_CHAR(xt.order_end_date,'DD-MON-YYYY')
                    AND TO_CHAR(TRUNC(l_header_rec.request_date),'DD-MON-YYYY') BETWEEN TO_CHAR(xt.requested_start_date ,'DD-MON-YYYY') AND TO_CHAR(xt.requested_end_date,'DD-MON-YYYY')
                    -- AND TO_DATE (TO_CHAR (order_start_date,  'DD-MON-YYYY')) <= TO_DATE (TO_CHAR (TRUNC ( l_header_rec.ORDERED_DATE), 'DD-MON-YYYY'))
                    -- AND TO_DATE (TO_CHAR (order_end_date,    'DD-MON-YYYY')) >= TO_DATE (TO_CHAR (TRUNC ( l_header_rec.ORDERED_DATE), 'DD-MON-YYYY'))
                    --AND TO_DATE (TO_CHAR (requested_start_date,'DD-MON-YYYY')) <= TO_DATE (TO_CHAR (TRUNC ( l_header_rec.request_date), 'DD-MON-YYYY'))
                    --AND TO_DATE (TO_CHAR (requested_end_date,  'DD-MON-YYYY')) >= TO_DATE (TO_CHAR (TRUNC ( l_header_rec.request_date), 'DD-MON-YYYY'))
                     AND xt.OPERATING_UNIT = v_org_name
                     AND xt.customer_class = v_class_code
                     AND xt.PRICE_LIST_NAME = qlh.NAME;

                    RETURN v_price_list;
               --v_price_list := 6014;
               EXCEPTION
                  WHEN NO_DATA_FOUND THEN
                      RETURN NULL;
                  WHEN OTHERS
                  THEN

                     RETURN NULL;
               END;
            END IF;*/
            --End Commented by BT Technology Team 01-May-2015

            --v_price_list := 6015;

            RETURN v_price_list;
        END IF;

        RETURN v_price_list;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_price_list   := NULL;
            RETURN v_price_list;
    END ret_hpricelist;

    -- PRICE LIST Line

    FUNCTION ret_lpricelist (p_database_object_name   IN VARCHAR2,
                             p_attribute_code         IN VARCHAR2)
        RETURN NUMBER
    IS
        l_header_rec        oe_ak_order_headers_v%ROWTYPE;
        l_line_rec          oe_ak_order_lines_v%ROWTYPE;
        v_class_code        VARCHAR2 (30) := NULL;
        v_brand             VARCHAR2 (150) := NULL;
        v_price_list_name   VARCHAR2 (50) := NULL;
        --   v_price_list        NUMBER                          := NULL;
        v_price_list        VARCHAR2 (150) := NULL;
        v_org               VARCHAR2 (50);
    BEGIN
        l_line_rec     := ont_line_def_hdlr.g_record;
        l_header_rec   := ont_header_def_hdlr.g_record;

        IF l_line_rec.inventory_item_id IS NOT NULL
        THEN
            BEGIN
                SELECT m_c.segment1
                  INTO v_brand
                  FROM mtl_system_items_b item, mtl_item_categories item_c, mtl_categories m_c,
                       mtl_category_sets m_c_s
                 WHERE     item.inventory_item_id =
                           l_line_rec.inventory_item_id                -- 2059
                       AND item.organization_id = item_c.organization_id
                       AND item.inventory_item_id = item_c.inventory_item_id
                       AND item_c.category_id = m_c.category_id
                       AND item_c.category_set_id = m_c_s.category_set_id
                       AND category_set_name = 'Inventory'
                       AND item.organization_id = l_line_rec.ship_from_org_id; --  256
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_brand   := NULL;
            END;

            BEGIN
                SELECT hca.customer_class_code
                  INTO v_class_code
                  FROM hz_cust_accounts hca
                 WHERE hca.cust_account_id = l_line_rec.sold_to_org_id; --42054;
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_class_code   := NULL;
            END;

            SELECT name
              INTO v_org
              FROM hr_operating_units
             WHERE organization_id = l_line_rec.org_id;
        --   INSERT INTO test11
        --      VALUES (v_brand, v_class_code);

        --Start Commented by BT Technology Team 01-May-2015
        --xxd_default_pricelist_matrix is obselete now. Defaulting will be done now from Oracle Standard Defaulting Rules.
        /*IF v_brand IS NOT NULL AND v_class_code IS NOT NULL
        THEN
           SELECT qlh.name--list_header_id
                 INTO v_price_list
                 FROM xxd_default_pricelist_matrix xt, qp_list_headers_vl qlh
                 WHERE brand = v_brand
                 AND TO_CHAR(TRUNC(l_header_rec.request_date),'DD-MON-YYYY') BETWEEN TO_CHAR(xt.requested_start_date ,'DD-MON-YYYY') AND TO_CHAR(xt.requested_end_date,'DD-MON-YYYY')
                 --AND TO_DATE (TO_CHAR (order_start_date,  'DD-MON-YYYY')) <= TO_DATE (TO_CHAR (TRUNC ( l_header_rec.order_date), 'DD-MON-YYYY'))
                 --AND TO_DATE (TO_CHAR (order_end_date,    'DD-MON-YYYY')) >= TO_DATE (TO_CHAR (TRUNC ( l_header_rec.order_date), 'DD-MON-YYYY'))
                 --AND TO_DATE (TO_CHAR (requested_start_date,'DD-MON-YYYY')) <= TO_DATE (TO_CHAR (TRUNC ( l_header_rec.request_date), 'DD-MON-YYYY'))
                 --AND TO_DATE (TO_CHAR (requested_end_date,  'DD-MON-YYYY')) >= TO_DATE (TO_CHAR (TRUNC ( l_header_rec.request_date), 'DD-MON-YYYY'))
                 AND xt.OPERATING_UNIT = v_org
                 AND customer_class =   v_class_code
                 AND xt.PRICE_LIST_NAME = qlh.NAME;
        --v_price_list := 6015;
        END IF;*/
        --End Commented by BT Technology Team 01-May-2015

        END IF;

        --RETURN 6011;

        RETURN v_price_list;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_lpricelist;

    --DEMAND CLASS

    FUNCTION ret_demclass (p_database_object_name   IN VARCHAR2,
                           p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_header_rec   oe_ak_order_headers_v%ROWTYPE;
        v_demclass     VARCHAR2 (150) := NULL;
    BEGIN
        l_header_rec   := ont_header_def_hdlr.g_record;

        IF l_header_rec.sold_to_org_id IS NOT NULL
        THEN
            SELECT attribute13
              INTO v_demclass
              FROM hz_cust_accounts_all
             WHERE cust_account_id = l_header_rec.sold_to_org_id;

            --l_header_rec.sold_to_org_id;           --42054

            /* insert into test11 values('demand1','UGG-The Walking Company');
             commit;
            /* IF OE_MSG_PUB.Check_Msg_Level(OE_MSG_PUB.G_MSG_LVL_ERROR) THEN
                OE_MSG_PUB.Add_Exc_Msg ( 'G_PKG_NAME' , 'Load_Entity_Attributes' );
              END IF;
              RAISE FND_API.G_EXC_UNEXPECTED_ERROR;*/
            /* FND_MESSAGE.SET_NAME ('FND', 'FLEX-USER DEFINED ERROR');
            FND_MESSAGE.SET_TOKEN ('MSG', attribute13);
            FND_MESSAGE.show;*/
            -- v_demclass := 'PRIORITY 1';
            /*     IF OE_MSG_PUB.Check_Msg_Level(OE_MSG_PUB.G_MSG_LVL_UNEXP_ERROR)
            THEN
            OE_MSG_PUB.Add_Exc_Msg
            (   'G_PKG_NAME'
            ,   'Load_Entity_Attributes'
            );
            END IF;*/
            -- RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
            --v_demclass:='UGG-The Walking Company';

            RETURN v_demclass;
        END IF;

        -- insert into test11 values('demand','UGG-The Walking Company');
        -- commit;

        RETURN v_demclass;                        --'UGG-The Walking Company';
    EXCEPTION
        WHEN OTHERS
        THEN
            --RAISE FND_API.G_EXC_UNEXPECTED_ERROR;
            RETURN NULL;
    END ret_demclass;

    FUNCTION ret_request_date (p_database_object_name   IN VARCHAR2,
                               p_attribute_code         IN VARCHAR2)
        RETURN DATE
    IS
        l_header_rec   oe_ak_order_headers_v%ROWTYPE;
        v_orddate      DATE := NULL;
    BEGIN
        l_header_rec   := ont_header_def_hdlr.g_record;

        -- IF  l_header_rec.sold_to_org_id is not null THEN
        SELECT TRUNC (SYSDATE) INTO v_orddate FROM DUAL;

        RETURN v_orddate;
    -- END IF;
    -- return null;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_request_date;

    -- Start modification for defaulting pricing date based on request date post go - live 26-APR-2016

    FUNCTION ret_pricing_date (p_database_object_name   IN VARCHAR2,
                               p_attribute_code         IN VARCHAR2)
        RETURN DATE
    IS
        ln_exists     NUMBER;
        ln_cur_date   DATE;
    BEGIN
        SELECT COUNT (1)
          INTO ln_exists
          FROM fnd_lookup_values_vl
         WHERE     enabled_flag = 'Y'
               AND NVL (end_date_active, SYSDATE + 1) > SYSDATE
               AND lookup_type = 'XXD_ORDER_PRICING_DATE_DEF'
               AND tag = ont_header_def_hdlr.g_record.order_source_id;

        IF ln_exists > 0
        THEN
            RETURN ont_line_def_hdlr.g_record.request_date;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_pricing_date;

    -- End modification for defaulting pricing date based on request date post go - live 26-APR-2016

    /* FUNCTION ret_hsalesrep (                                       -- Start Commented by BT Technology Team 15-01-2015
       p_database_object_name   IN   VARCHAR2,
       p_attribute_code         IN   VARCHAR2
    )
       RETURN NUMBER
    IS
       l_header_rec     oe_ak_order_headers_v%ROWTYPE;
       l_line_rec       oe_ak_order_lines_v%ROWTYPE;
       v_ret_salesrep   VARCHAR2 (50)                   := NULL;
       v_sales_id       NUMBER;
       v_cust_name      VARCHAR2 (360)                  := NULL;
       v_cust_site      VARCHAR2 (240)                  := NULL;
       v_orgname        VARCHAR2 (240)                  := NULL;
       v_class_code     VARCHAR2 (30)                   := NULL;
       v_acct_num       NUMBER;
       v_brand          VARCHAR2 (150)                  := NULL;
    BEGIN
       l_header_rec := ont_header_def_hdlr.g_record;
       l_line_rec := ont_line_def_hdlr.g_record;

       IF l_header_rec.sold_to_org_id IS NOT NULL
       THEN
          BEGIN
             SELECT hp.party_name, hps.party_site_name, hou.NAME,
                    hca.account_number, hca.attribute1
               INTO v_cust_name, v_cust_site, v_orgname,
                    v_acct_num, v_brand
               FROM hz_cust_accounts hca,
                    hz_cust_acct_sites_all hcas,
                    hz_cust_site_uses_all hcasu,
                    hz_parties hp,
                    hz_party_sites hps,
                    hr_operating_units hou
              WHERE hca.party_id = hp.party_id
                AND hca.cust_account_id = hcas.cust_account_id
                AND hcas.party_site_id = hps.party_site_id
                AND hou.organization_id = hcas.org_id
                AND hcas.org_id = l_header_rec.org_id
                AND hca.cust_account_id = l_header_rec.sold_to_org_id
                AND hcas.cust_acct_site_id = hcasu.cust_acct_site_id
                AND hcasu.site_use_id = l_header_rec.ship_to_org_id;
          EXCEPTION
             WHEN OTHERS
             THEN
                v_sales_id := NULL;
          END;

          IF     v_cust_name IS NOT NULL
             AND v_acct_num IS NOT NULL
             AND v_orgname IS NOT NULL
             AND v_brand IS NOT NULL
          THEN
             SELECT salesrep_id
               INTO v_sales_id
               FROM xxd_default_salesrep_matrix xsr,
                    jtf_rs_salesreps jrs,
                    hr_operating_units hou
              WHERE org_name = v_orgname
                AND customer_name = v_cust_name
                AND customer_number = v_acct_num
                AND brand = v_brand
                AND hou.organization_id = jrs.org_id
                AND hou.NAME = xsr.org_name
                AND xsr.salesrep_name = jrs.NAME;
          END IF;

          RETURN v_sales_id;
       END IF;

       RETURN v_sales_id;                                          --100001041;
    EXCEPTION
       WHEN OTHERS
       THEN
          RETURN NULL;
    END ret_hsalesrep;

    FUNCTION ret_lsalesrep (
       p_database_object_name   IN   VARCHAR2,
       p_attribute_code         IN   VARCHAR2
    )
       RETURN NUMBER
    IS
       l_header_rec     oe_ak_order_headers_v%ROWTYPE;
       l_line_rec       oe_ak_order_lines_v%ROWTYPE;
       v_brand          VARCHAR2 (150)                  := NULL;
       v_division       VARCHAR2 (150)                  := NULL;
       v_dept           VARCHAR2 (150)                  := NULL;
       v_class          VARCHAR2 (150)                  := NULL;
       v_subclass       VARCHAR2 (150)                  := NULL;
       v_mst_style      VARCHAR2 (150)                  := NULL;
       v_style          VARCHAR2 (150)                  := NULL;
       v_color          VARCHAR2 (150)                  := NULL;
       v_sku            VARCHAR2 (150)                  := NULL;
       v_ret_salesrep   VARCHAR2 (50)                   := NULL;
       v_cust_name      VARCHAR2 (360)                  := NULL;
       v_cust_site      VARCHAR2 (240)                  := NULL;
       v_orgname        VARCHAR2 (240)                  := NULL;
       v_acct_num       NUMBER;
       v_sales_id       NUMBER;
    BEGIN
       l_line_rec := ont_line_def_hdlr.g_record;
       l_header_rec := ont_header_def_hdlr.g_record;

       IF l_line_rec.inventory_item_id IS NOT NULL
       THEN
          BEGIN
             SELECT m_c.segment1, m_c.segment2, m_c.segment3, m_c.segment4,
                    m_c.segment5
               INTO v_brand, v_division, v_dept, v_class,
                    v_subclass
               FROM mtl_system_items_b item,
                    mtl_item_categories item_c,
                    mtl_categories m_c,
                    mtl_category_sets m_c_s
              WHERE item.inventory_item_id = l_line_rec.inventory_item_id
                AND item.organization_id = item_c.organization_id
                AND item.inventory_item_id = item_c.inventory_item_id
                AND item_c.category_id = m_c.category_id
                AND item_c.category_set_id = m_c_s.category_set_id
                AND category_set_name = 'Inventory'
                AND item.organization_id = 121;  --l_line_rec.ship_from_org_id;
          EXCEPTION
             WHEN OTHERS
             THEN
                v_brand := NULL;
                v_division := NULL;
          END;

          BEGIN
             SELECT hp.party_name, hps.party_site_name, hou.NAME,
                                                      --hca.customer_class_code
                    hca.account_number, hca.attribute1, hca.account_number
               INTO v_cust_name, v_cust_site, v_orgname,
                    v_acct_num, v_brand, v_acct_num
               FROM hz_cust_accounts hca,
                    hz_cust_acct_sites_all hcas,
                    hz_cust_site_uses_all hcasu,
                    hz_parties hp,
                    hz_party_sites hps,
                    hr_operating_units hou
              WHERE hca.party_id = hp.party_id
                AND hca.cust_account_id = hcas.cust_account_id
                AND hcas.party_site_id = hps.party_site_id
                AND hou.organization_id = hcas.org_id
                AND hcas.org_id = l_header_rec.org_id
                AND hca.cust_account_id = l_header_rec.sold_to_org_id
                AND hcas.cust_acct_site_id = hcasu.cust_acct_site_id
                AND hcasu.site_use_id = l_header_rec.ship_to_org_id;
          EXCEPTION
             WHEN OTHERS
             THEN
                v_cust_name := NULL;
                v_cust_site := NULL;
                v_orgname := NULL;
          END;

          IF     v_cust_name IS NOT NULL
             AND v_acct_num IS NOT NULL
             AND l_line_rec.org_id IS NOT NULL
             AND v_brand IS NOT NULL             -- AND v_cust_site IS NOT NULL
          THEN
             BEGIN
                SELECT salesrep_id
                  INTO v_sales_id
                  FROM xxd_default_salesrep_matrix xsr,
                       jtf_rs_salesreps jrs,
                       hr_operating_units hou
                 WHERE org_name = v_orgname
                   AND customer_name = v_cust_name
                   -- AND customer_site    = v_cust_site
                   AND customer_number = v_acct_num
                   AND brand = v_brand
                   AND division = v_division
                   AND department = v_dept
                   AND CLASS = v_class
                   AND sub_class = v_subclass
                   AND hou.organization_id = jrs.org_id
                   AND hou.NAME = xsr.org_name
                   AND xsr.salesrep_name = jrs.NAME;

                --v_sales_id:=100001041;
                RETURN v_sales_id;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                   v_sales_id := NULL;
             END;
          END IF;

          IF v_sales_id IS NULL
          THEN
             BEGIN
                SELECT salesrep_id
                  INTO v_sales_id
                  FROM xxd_default_salesrep_matrix xsr,
                       jtf_rs_salesreps jrs,
                       hr_operating_units hou
                 WHERE org_name = v_orgname
                   AND customer_name = v_cust_name
                   --  AND customer_site    = v_cust_site
                   AND customer_number = v_acct_num
                   AND brand = v_brand
                   AND division = v_division
                   AND department = v_dept
                   AND CLASS = v_class
                   AND hou.organization_id = jrs.org_id
                   AND hou.NAME = xsr.org_name
                   AND xsr.salesrep_name = jrs.NAME;

                RETURN v_sales_id;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                   v_sales_id := NULL;
             END;
          END IF;

          IF v_sales_id IS NULL
          THEN
             BEGIN
                SELECT salesrep_id
                  INTO v_ret_salesrep
                  FROM xxd_default_salesrep_matrix xsr,
                       jtf_rs_salesreps jrs,
                       hr_operating_units hou
                 WHERE org_name = v_orgname
                   AND customer_name = v_cust_name
                   --  AND customer_site    = v_cust_site
                   AND customer_number = v_acct_num
                   AND brand = v_brand
                   AND division = v_division
                   AND department = v_dept
                   AND hou.organization_id = jrs.org_id
                   AND hou.NAME = xsr.org_name
                   AND xsr.salesrep_name = jrs.NAME;

                RETURN v_sales_id;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                   v_sales_id := NULL;
             END;
          END IF;

          IF v_sales_id IS NULL
          THEN
             BEGIN
                SELECT salesrep_id
                  INTO v_sales_id
                  FROM xxd_default_salesrep_matrix xsr,
                       jtf_rs_salesreps jrs,
                       hr_operating_units hou
                 WHERE org_name = v_orgname
                   AND customer_name = v_cust_name
                   --  AND customer_site    = v_cust_site
                   AND customer_number = v_acct_num
                   AND brand = v_brand
                   AND division = v_division
                   AND hou.organization_id = jrs.org_id
                   AND hou.NAME = xsr.org_name
                   AND xsr.salesrep_name = jrs.NAME;

                RETURN v_sales_id;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                   v_sales_id := NULL;
             END;
          END IF;

          IF v_sales_id IS NULL
          THEN
             BEGIN
                SELECT salesrep_id
                  INTO v_sales_id
                  FROM xxd_default_salesrep_matrix xsr,
                       jtf_rs_salesreps jrs,
                       hr_operating_units hou
                 WHERE org_name = v_orgname
                   AND customer_name = v_cust_name
                   -- AND customer_site    = v_cust_site
                   AND customer_number = v_acct_num
                   AND brand = v_brand
                   AND hou.organization_id = jrs.org_id
                   AND hou.NAME = xsr.org_name
                   AND xsr.salesrep_name = jrs.NAME;

                RETURN v_sales_id;
             EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                   v_sales_id := NULL;
             END;
          END IF;

          RETURN v_sales_id;
       END IF;

       RETURN v_sales_id;
    EXCEPTION
       WHEN OTHERS
       THEN
          RETURN NULL;
    END ret_lsalesrep;*/

    /*FUNCTION ret_shipinstr (
       p_database_object_name   IN   VARCHAR2,
       p_attribute_code         IN   VARCHAR2
    )
       RETURN VARCHAR2
    IS
       l_header_rec   oe_ak_order_headers_v%ROWTYPE;
       v_rule_id      NUMBER                          := NULL;
       v_shipinstr    VARCHAR2 (150)                  := NULL;
    BEGIN
       BEGIN
          SELECT NVL (rule_id, 0)
            INTO v_rule_id
            FROM oe_attachment_rule_elements_v
           WHERE attribute_name = 'Ship To'
             AND attribute_value = l_header_rec.ship_to_org_id;

          IF v_rule_id = 0
          THEN
             SELECT rule_id
               INTO v_rule_id
               FROM oe_attachment_rule_elements_v
              WHERE attribute_name = 'Customer'
                AND attribute_value = l_header_rec.sold_to_org_id;
          END IF;
       EXCEPTION
          WHEN OTHERS
          THEN
             v_rule_id := NULL;
       END;

       IF v_rule_id IS NOT NULL
       THEN
          SELECT long_text
            INTO v_shipinstr
            FROM oe_attachment_rules oar,
                 fnd_documents_vl fdv,
                 fnd_documents_long_text fdl
           WHERE oar.rule_id = v_rule_id
             AND oar.document_id = fdv.document_id
             AND fdv.datatype_name = 'Long Text'
             AND fdv.media_id = fdl.media_id;

          RETURN v_shipinstr;
       ELSE
          RETURN NULL;
       END IF;
    EXCEPTION
       WHEN OTHERS
       THEN
          RETURN NULL;
    END ret_shipinstr;*/
    -- End Commented by BT Technology Team 15-01-2015

    -- Shiping Instruction as per BTOM

    FUNCTION ret_shipinstr (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR lcu_get_long_text (p_cust_account_id   IN NUMBER,
                                  p_user_name         IN VARCHAR2)
        IS
            SELECT long_text
              FROM oe_attachment_rules oar, fnd_documents_vl fdv, fnd_documents_long_text fdl,
                   fnd_document_categories_vl fdc, hz_parties party, hz_cust_accounts cust,
                   oe_attachment_rule_elements_v oare
             WHERE     1 = 1
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
                   AND cust.cust_account_id = oare.attribute_value
                   AND oare.attribute_value = p_cust_account_id;

        -- l_header_rec   oe_ak_order_headers_v%ROWTYPE;

        v_shipinstr   VARCHAR2 (3000) := NULL;
        lc_shipping   VARCHAR2 (30) := 'Shipping Instructions';
    --lc_packing  VARCHAR2(30) := 'Packing Instructions';
    BEGIN
        OPEN lcu_get_long_text (ont_header_def_hdlr.g_record.sold_to_org_id,
                                lc_shipping);

        FETCH lcu_get_long_text INTO v_shipinstr;

        CLOSE lcu_get_long_text;

        RETURN v_shipinstr;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_shipinstr;

    --Packing Instruction as per BTOM

    FUNCTION ret_packinstr (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR lcu_get_long_text (p_cust_account_id   IN NUMBER,
                                  p_user_name         IN VARCHAR2)
        IS
            SELECT long_text
              FROM oe_attachment_rules oar, fnd_documents_vl fdv, fnd_documents_long_text fdl,
                   fnd_document_categories_vl fdc, hz_parties party, hz_cust_accounts cust,
                   oe_attachment_rule_elements_v oare
             WHERE     1 = 1
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
                   AND cust.cust_account_id = oare.attribute_value
                   AND oare.attribute_value = p_cust_account_id;

        --l_header_rec   oe_ak_order_headers_v%ROWTYPE;

        v_shipinstr   VARCHAR2 (3000) := NULL;
        --lc_shipping VARCHAR2(30) := 'Shipping Instructions';
        lc_packing    VARCHAR2 (30) := 'Packing Instructions';
    BEGIN
        OPEN lcu_get_long_text (ont_header_def_hdlr.g_record.sold_to_org_id,
                                lc_packing);

        FETCH lcu_get_long_text INTO v_shipinstr;

        CLOSE lcu_get_long_text;

        RETURN v_shipinstr;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_packinstr;

    -- SHIP TO

    FUNCTION ret_ship_to_loc (p_database_object_name   IN VARCHAR2,
                              p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_ship_to              hz_cust_site_uses.location%TYPE;
        l_site_use_id          hz_cust_site_uses.site_use_id%TYPE;
        l_ship_to_address1     hz_locations.address1%TYPE;
        l_ship_to_address2     hz_locations.address2%TYPE;
        l_ship_to_state        hz_locations.state%TYPE;
        l_ship_to_country      hz_locations.country%TYPE;
        l_org_id               hz_cust_site_uses.org_id%TYPE;
        l_ship_to_address_id   hz_cust_site_uses.site_use_id%TYPE;
        l_bill_to_address_id   hz_cust_site_uses.bill_to_site_use_id%TYPE;
        l_ship_to_addressess   VARCHAR2 (500);

        /* Cursor To Pick Parent Ship To For The Customer from reciprocal Table */
        CURSOR lcu_get_related_cust_ship_to (p_cust_acct_id VARCHAR2)
        IS
            SELECT hcsu.location, hcsu.site_use_id
              /*loc.address1,
              loc.address2,
              loc.state,
              loc.country,
              hcsu.org_id,
              hcsu.site_use_id,
              hcsu.bill_to_site_use_id,
              loc.city||','||loc.state||','||loc.postal_ode||','||loc.country */
              FROM                                   --hz_cust_accounts   hca,
                   (SELECT NVL (hcar.related_cust_account_id, hca.cust_account_id) related_cust_account_id, hca.status, hca.cust_account_id
                      FROM hz_cust_accounts hca, hz_cust_acct_relate hcar
                     WHERE     hca.cust_account_id = hcar.cust_account_id(+)
                           AND hcar.status(+) = 'A'
                           AND hca.cust_account_id = p_cust_acct_id
                           --Start changes by BT Tech Team on 6/16/2015
                           AND hca.party_id =
                               (SELECT party_id
                                  FROM apps.hz_cust_accounts_all b
                                 WHERE b.cust_account_id =
                                       NVL (hcar.related_cust_account_id,
                                            hca.cust_account_id)) --End changes by BT Tech Team on 6/16/2015
                                                                 ) hca,
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
        BEGIN
            mo_global.set_policy_context ('S', fnd_global.org_id);
        END;

        /* Cursor To Pick Parent Ship To For The Customer from reciprocal Table */
        OPEN lcu_get_related_cust_ship_to (
            ont_header_def_hdlr.g_record.sold_to_org_id);

        FETCH lcu_get_related_cust_ship_to INTO l_ship_to, l_site_use_id;

        CLOSE lcu_get_related_cust_ship_to;

        RETURN l_site_use_id;
        DBMS_OUTPUT.put_line ('px_header_rec(1).ship_to 1 - ' || l_ship_to);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --x_error_flag :=  NULL;
            RETURN NULL;
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_ship_to_loc;

    -- BILL TO

    FUNCTION ret_bill_to_loc (p_database_object_name   IN VARCHAR2,
                              p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_ship_to              hz_cust_site_uses.location%TYPE;
        l_site_use_id          hz_cust_site_uses.site_use_id%TYPE;
        l_ship_to_address1     hz_locations.address1%TYPE;
        l_ship_to_address2     hz_locations.address2%TYPE;
        l_ship_to_state        hz_locations.state%TYPE;
        l_ship_to_country      hz_locations.country%TYPE;
        l_org_id               hz_cust_site_uses.org_id%TYPE;
        l_ship_to_address_id   hz_cust_site_uses.site_use_id%TYPE;
        l_bill_to_address_id   hz_cust_site_uses.bill_to_site_use_id%TYPE;
        l_ship_to_addressess   VARCHAR2 (500);

        /* Cursor To Pick Parent Bill To For The Customer from reciprocal Table */
        CURSOR lcu_get_related_cust_bill_to (p_cust_acct_id VARCHAR2)
        IS
            SELECT hcsu.location, hcsu.site_use_id
              /* loc.address1,
              loc.address2,
              loc.state,
              loc.country,
              hcsu.org_id,
              hcsu.site_use_id,
              hcsu.bill_to_site_use_id,
              loc.city||','||loc.state||','||loc.postal_code||','||loc.country */
              FROM                                   --hz_cust_accounts   hca,
                   (SELECT NVL (hcar.related_cust_account_id, hca.cust_account_id) related_cust_account_id, hca.status, hca.cust_account_id
                      FROM hz_cust_accounts hca, hz_cust_acct_relate hcar
                     WHERE     hca.cust_account_id = hcar.cust_account_id(+)
                           AND hcar.status(+) = 'A'
                           AND hca.cust_account_id = p_cust_acct_id) hca,
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

        --Start changes by BT Tech Team on 6/16/2015

        CURSOR lcu_get_brand_cust_bill_to (p_cust_acct_id          VARCHAR2,
                                           p_ship_to_site_use_id   NUMBER)
        IS
            SELECT hcsu_brand.location, hcsu_brand.site_use_id
              FROM hz_cust_accounts hca_brand, hz_cust_acct_sites hcas_brand, hz_cust_site_uses hcsu_brand,
                   hz_cust_acct_relate hcar, hz_cust_accounts hca_legacy, hz_cust_acct_sites hcas_legacy_bt,
                   hz_cust_acct_sites hcas_legacy_st, hz_cust_site_uses hcsu_legacy_bt, hz_cust_site_uses hcsu_legacy_st
             WHERE     hca_brand.cust_account_id = hcar.cust_account_id
                   AND hca_brand.cust_account_id = hcas_brand.cust_account_id
                   AND hcas_brand.cust_acct_site_id =
                       hcsu_brand.cust_acct_site_id
                   AND hca_legacy.cust_account_id =
                       hcar.related_cust_account_id
                   AND hca_legacy.cust_account_id =
                       hcas_legacy_bt.cust_account_id
                   AND hcas_legacy_bt.cust_acct_site_id =
                       hcsu_legacy_bt.cust_acct_site_id
                   AND hca_legacy.cust_account_id =
                       hcas_legacy_st.cust_account_id
                   AND hcas_legacy_st.cust_acct_site_id =
                       hcsu_legacy_bt.cust_acct_site_id
                   AND hca_legacy.party_id = hca_brand.party_id
                   AND hcsu_brand.site_use_code = 'BILL_TO'
                   AND hcsu_legacy_bt.site_use_code = 'BILL_TO'
                   AND hcsu_legacy_st.site_use_code = 'SHIP_TO'
                   AND hcsu_legacy_bt.site_use_id =
                       hcsu_legacy_st.bill_to_site_use_id
                   AND hcsu_brand.location =
                       hcsu_legacy_bt.location || '_' || hca_brand.attribute1
                   AND hca_brand.status = 'A'
                   AND hcas_brand.status = 'A'
                   AND hcsu_brand.status = 'A'
                   AND hca_legacy.status = 'A'
                   AND hcas_legacy_bt.status = 'A'
                   AND hcas_legacy_st.status = 'A'
                   AND hcsu_legacy_bt.status = 'A'
                   AND hcsu_legacy_st.status = 'A'
                   AND hca_brand.cust_account_id = p_cust_acct_id
                   AND hcsu_legacy_st.site_use_id = p_ship_to_site_use_id;

        --Start: Added by Infosys for CCR0006627 on 18-Sep-2017--1.1

        CURSOR lcu_get_primary_bill_to (p_cust_acct_id   VARCHAR2,
                                        p_org_id         NUMBER)
        IS
            SELECT hcsu_bt.location, hcsu_bt.site_use_id
              FROM hz_cust_accounts hca, hz_cust_acct_sites_all hcas_bt, hz_cust_site_uses_all hcsu_bt
             WHERE     hca.cust_account_id = hcas_bt.cust_account_id
                   AND hcas_bt.cust_acct_site_id = hcsu_bt.cust_acct_site_id
                   AND hcsu_bt.site_use_code = 'BILL_TO'
                   AND hca.status = 'A'
                   AND hcas_bt.status = 'A'
                   AND hcsu_bt.status = 'A'
                   AND hcsu_bt.primary_flag = 'Y'
                   AND hca.cust_account_id = p_cust_acct_id
                   AND hcas_bt.org_id = p_org_id
                   AND hcsu_bt.org_id = p_org_id;

        --End: Added by Infosys for CCR0006627 on 18-Sep-2017--1.1

        CURSOR lcu_get_legacy_cust_bill_to (p_cust_acct_id          VARCHAR2,
                                            p_ship_to_site_use_id   NUMBER)
        IS
            SELECT hcsu_bt.location, hcsu_bt.site_use_id
              FROM hz_cust_accounts hca, hz_cust_acct_sites hcas_bt, hz_cust_acct_sites hcas_st,
                   hz_cust_site_uses hcsu_bt, hz_cust_site_uses hcsu_st
             WHERE     hca.cust_account_id = hcas_bt.cust_account_id
                   AND hcas_bt.cust_acct_site_id = hcsu_bt.cust_acct_site_id
                   AND hca.cust_account_id = hcas_st.cust_account_id
                   AND hcas_st.cust_acct_site_id = hcsu_bt.cust_acct_site_id
                   AND hcsu_bt.site_use_code = 'BILL_TO'
                   AND hcsu_st.site_use_code = 'SHIP_TO'
                   AND hcsu_bt.site_use_id = hcsu_st.bill_to_site_use_id
                   AND hca.status = 'A'
                   AND hcas_bt.status = 'A'
                   AND hcas_st.status = 'A'
                   AND hcsu_bt.status = 'A'
                   AND hcsu_st.status = 'A'
                   AND hca.cust_account_id = p_cust_acct_id
                   AND hcsu_st.site_use_id = p_ship_to_site_use_id;
    --End changes by BT Tech Team on 6/16/2015

    BEGIN
        BEGIN
            mo_global.set_policy_context ('S', fnd_global.org_id);
        END;

        /* Open The Cursor to check site_use_id in Reciprocal for BILL_TO */

        --Start changes by BT Tech Team on 6/16/2015
        /*OPEN lcu_get_related_cust_bill_to(ont_header_def_hdlr.g_record.sold_to_org_id);
        FETCH lcu_get_related_cust_bill_to
            INTO l_ship_to
                ,l_site_use_id;
        CLOSE lcu_get_related_cust_bill_to;*/
        OPEN lcu_get_brand_cust_bill_to (
            ont_header_def_hdlr.g_record.sold_to_org_id,
            ont_header_def_hdlr.g_record.ship_to_org_id);

        FETCH lcu_get_brand_cust_bill_to INTO l_ship_to, l_site_use_id;

        IF lcu_get_brand_cust_bill_to%NOTFOUND
        THEN
            --Start: Added by Infosys for CCR0006627 on 18-Sep-2017 --1.1
            OPEN lcu_get_primary_bill_to (
                ont_header_def_hdlr.g_record.sold_to_org_id,
                ont_header_def_hdlr.g_record.org_id);

            FETCH lcu_get_primary_bill_to INTO l_ship_to, l_site_use_id;

            IF lcu_get_primary_bill_to%NOTFOUND
            THEN
                OPEN lcu_get_legacy_cust_bill_to (
                    ont_header_def_hdlr.g_record.sold_to_org_id,
                    ont_header_def_hdlr.g_record.ship_to_org_id);

                FETCH lcu_get_legacy_cust_bill_to INTO l_ship_to, l_site_use_id;

                CLOSE lcu_get_legacy_cust_bill_to;
            END IF;

            CLOSE lcu_get_primary_bill_to;
        END IF;

        CLOSE lcu_get_brand_cust_bill_to;

        --End: Added by Infosys for CCR0006627 on 18-Sep-2017 --1.1

        --Start : Commented by Infosys for CCR0006627 on 18-Sep-2017 --1.1
        /*  OPEN lcu_get_legacy_cust_bill_to ( ont_header_def_hdlr.g_record.sold_to_org_id
                                          ,  ont_header_def_hdlr.g_record.ship_to_org_id );

          FETCH lcu_get_legacy_cust_bill_to
          INTO l_ship_to, l_site_use_id;

          CLOSE lcu_get_legacy_cust_bill_to;
      END IF;

      CLOSE lcu_get_brand_cust_bill_to;*/
        --End changes by BT Tech Team on 6/16/2015
        --End : Commented by Infosys for CCR0006627 on 18-Sep-2017 --1.1
        RETURN l_site_use_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --x_error_flag :=  NULL;
            RETURN NULL;
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_bill_to_loc;

    FUNCTION get_default_line_type (p_database_object_name   IN VARCHAR2,
                                    p_attribute_code         IN VARCHAR2)
        RETURN NUMBER
    IS
        --l_proc_name varchar2(240) := G_PKG_NAME || '.get_default_line_type';
        l_ret   NUMBER;
        l_cnt   NUMBER;
    BEGIN
        -- do_debug_tools.msg('+' || l_proc_name);
        do_debug_tools.msg (
               '  p_database_object_name='
            || p_database_object_name
            || ', p_attribute_code='
            || p_attribute_code
            || ', Brand='
            || ont_header_def_hdlr.g_record.attribute5
            || ', Customer='
            || ont_header_def_hdlr.g_record.sold_to_org_id
            || ', Ship-To='
            || ont_header_def_hdlr.g_record.ship_to_org_id
            || ', Bill-To='
            || ont_header_def_hdlr.g_record.invoice_to_org_id
            || ', OU='
            || fnd_global.org_id);

        IF ont_line_def_hdlr.g_record.inventory_item_id IS NOT NULL
        THEN
            SELECT COUNT (*), MIN (ottt.transaction_type_id)
              INTO l_cnt, l_ret
              FROM apps.fnd_lookup_values_vl flv, apps.oe_transaction_types_tl ottt, apps.mtl_system_items_b msi
             WHERE     flv.lookup_type = 'XXDO_GCARD_LINE_TYPE'
                   AND flv.enabled_flag = 'Y'
                   AND NVL (flv.end_date_active, SYSDATE + 1) > SYSDATE
                   AND ottt.name = flv.description
                   AND ottt.language = 'US'
                   --and flv.lookup_code = msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3
                   --and msi.organization_id = 7
                   AND flv.lookup_code = msi.segment1
                   AND msi.organization_id =
                       (SELECT organization_id
                          FROM apps.org_organization_definitions
                         WHERE organization_code = 'MST')
                   AND msi.inventory_item_id =
                       ont_line_def_hdlr.g_record.inventory_item_id;
        ELSE
            l_cnt   := 0;
        END IF;

        do_debug_tools.msg (' l_cnt=' || l_cnt || ', l_ret=' || l_ret);

        IF l_cnt != 1
        THEN
            l_ret   := NULL;
        END IF;

        do_debug_tools.msg (' return=' || l_ret);
        --do_debug_tools.msg('-' || l_proc_name);
        RETURN l_ret;
    END;

    --Start:1.2 Added by Infosys on 06-Dec-2017 for CCR0006679

    FUNCTION get_def_latest_accep_date (p_database_object_name   IN VARCHAR2,
                                        p_attribute_code         IN VARCHAR2)
        RETURN DATE
    IS
        --l_proc_name varchar2(240) := G_PKG_NAME || '.get_default_line_type';
        l_ret    NUMBER;
        l_cnt    NUMBER;
        l_date   DATE;
    BEGIN
        -- do_debug_tools.msg('+' || l_proc_name);
        do_debug_tools.msg (
               '  p_database_object_name='
            || p_database_object_name
            || ', p_attribute_code='
            || p_attribute_code
            || ', Cancel_date='
            || ont_header_def_hdlr.g_record.attribute1
            || ', Customer='
            || ont_header_def_hdlr.g_record.sold_to_org_id
            || ', Ship-To='
            || ont_header_def_hdlr.g_record.ship_to_org_id
            || ', Bill-To='
            || ont_header_def_hdlr.g_record.invoice_to_org_id
            || ', OU='
            || fnd_global.org_id);

        IF     ont_header_def_hdlr.g_record.attribute1 IS NOT NULL
           AND ont_header_def_hdlr.g_record.order_source_id != 1007
        THEN
            l_date   :=
                NVL (
                    TO_DATE (ont_line_def_hdlr.g_record.attribute1,
                             'YYYY/MM/DD HH24:MI:SS'),
                    TO_DATE (ont_header_def_hdlr.g_record.attribute1,
                             'YYYY/MM/DD HH24:MI:SS'));
        END IF;

        do_debug_tools.msg (' Latest Acceptatble Date=' || l_date);
        RETURN l_date;
    END get_def_latest_accep_date;

    --End :1.2 Added by Infosys on 06-Dec-2017 for CCR0006679
    --Start:1.9 Added for CCR0008870

    FUNCTION get_def_calculated_lad (p_database_object_name   IN VARCHAR2,
                                     p_attribute_code         IN VARCHAR2)
        RETURN DATE
    IS
        l_ret         NUMBER;
        l_cnt         NUMBER;
        l_lad_date    DATE;
        ln_add_days   NUMBER := 0;
    BEGIN
        IF ont_header_def_hdlr.g_record.order_source_id != 1007
        THEN
            BEGIN
                SELECT TO_NUMBER (tag)
                  INTO ln_add_days
                  FROM fnd_lookup_values_vl
                 WHERE     enabled_flag = 'Y'
                       AND NVL (end_date_active, SYSDATE + 1) > SYSDATE
                       AND lookup_type = 'XXD_ONT_LAD_CALCULATION'
                       AND lookup_code =
                           ont_header_def_hdlr.g_record.order_type_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_add_days   := 0;
                WHEN OTHERS
                THEN
                    ln_add_days   := 0;
            END;

            IF ln_add_days > 0
            THEN
                l_lad_date   :=
                    ont_line_def_hdlr.g_record.request_date + ln_add_days;
            ELSE
                l_lad_date   :=
                      ont_line_def_hdlr.g_record.request_date
                    + NVL (oe_order_cache.g_header_rec.latest_schedule_limit,
                           0);
            END IF;
        END IF;

        RETURN l_lad_date;
    END get_def_calculated_lad;

    --End :1.9 Added for CCR0008870

    FUNCTION get_default_subinventory (p_database_object_name   IN VARCHAR2,
                                       p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        --l_proc_name varchar2(240) := G_PKG_NAME || '.get_default_subinventory';
        l_ret   oe_order_lines_all.subinventory%TYPE;
    BEGIN
        -- do_debug_tools.msg('+' || l_proc_name);
        do_debug_tools.msg (
               '  p_database_object_name='
            || p_database_object_name
            || ', p_attribute_code='
            || p_attribute_code
            || ', Brand='
            || ont_header_def_hdlr.g_record.attribute5
            || ', Customer='
            || ont_header_def_hdlr.g_record.sold_to_org_id
            || ', Ship-To='
            || ont_header_def_hdlr.g_record.ship_to_org_id
            || ', Bill-To='
            || ont_header_def_hdlr.g_record.invoice_to_org_id
            || ', OU='
            || fnd_global.org_id
            || ', Order Type='
            || ont_header_def_hdlr.g_record.order_type_id);

        l_ret   := NULL;

        IF ont_header_def_hdlr.g_record.order_type_id IS NOT NULL
        THEN
            --Start changes by BT Tech Team 4/8/2015
            --select attribute11
            SELECT attribute7
              -- End Changes by BT Tech tam 4/8/2015
              INTO l_ret
              FROM oe_transaction_types_all
             WHERE transaction_type_id =
                   ont_header_def_hdlr.g_record.order_type_id;
        END IF;

        do_debug_tools.msg (' return=' || l_ret);
        --do_debug_tools.msg('-' || l_proc_name);
        RETURN l_ret;
    END;

    FUNCTION ret_warehouse (p_database_object_name   IN VARCHAR2,
                            p_attribute_code         IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_ou_id         NUMBER := fnd_profile.VALUE ('ORG_ID');
        ln_org_id        NUMBER;
        lc_ou_name       VARCHAR2 (100);
        lc_line_type     VARCHAR2 (300);
        lc_brand         VARCHAR2 (40);
        lc_division      VARCHAR2 (40);
        lc_department    VARCHAR2 (40);
        lc_warehouse     VARCHAR2 (40);
        lc_error_msg     VARCHAR2 (32767);
        lc_masterclass   VARCHAR2 (100);                           -- ver 1.12
        lc_subclass      VARCHAR2 (100);                           -- ver 1.12
        l_exception      EXCEPTION;
    BEGIN
        -- Start Changes V1.3
        ln_org_id   :=
            ret_org_move_warehouse (
                ont_line_def_hdlr.g_record.org_id,
                ont_header_def_hdlr.g_record.attribute5,
                ont_header_def_hdlr.g_record.order_type_id,
                ont_line_def_hdlr.g_record.request_date);

        -- BEGIN 1.12
        SELECT segment1, segment2, segment3,
               segment4, segment5
          INTO lc_brand, lc_division, lc_department, lc_masterclass,
                       lc_subclass
          FROM mtl_item_categories_v
         WHERE     category_set_name = 'Inventory'
               AND inventory_item_id =
                   ont_line_def_hdlr.g_record.inventory_item_id
               AND enabled_flag = 'Y'
               AND ROWNUM = 1;


        IF ln_org_id IS NULL
        THEN
            ln_org_id   :=
                ret_inv_warehouse (
                    ont_line_def_hdlr.g_record.org_id,
                    ont_header_def_hdlr.g_record.order_type_id,
                    ont_line_def_hdlr.g_record.line_type_id,
                    ont_line_def_hdlr.g_record.request_date,
                    ont_line_def_hdlr.g_record.inventory_item_id);
        END IF;

        -- END 1.12

        IF ln_org_id IS NULL
        THEN
            --End Changes V1.3
            --get OU name
            SELECT name
              INTO lc_ou_name
              FROM hr_operating_units
             WHERE     organization_id = ont_line_def_hdlr.g_record.org_id
                   AND TRUNC (SYSDATE) BETWEEN NVL (date_from,
                                                    TRUNC (SYSDATE))
                                           AND NVL (date_to, TRUNC (SYSDATE));

            lc_line_type   := '';

            --get line type
            IF ont_line_def_hdlr.g_record.line_type_id IS NOT NULL
            THEN
                SELECT t.name
                  INTO lc_line_type
                  FROM oe_transaction_types_tl t, oe_transaction_types_all b
                 WHERE     b.transaction_type_id = t.transaction_type_id
                       AND t.language = USERENV ('LANG')
                       AND TRUNC (SYSDATE) BETWEEN b.start_date_active
                                               AND NVL (b.end_date_active,
                                                        TRUNC (SYSDATE))
                       AND b.transaction_type_code = 'LINE'
                       AND b.transaction_type_id =
                           ont_line_def_hdlr.g_record.line_type_id;
            END IF;

            --get brand, division, department
            /*  VER 1.12  BEGIN moving this statementup
                      SELECT segment1,
                             segment2,
                             segment3
                      INTO
                          lc_brand,
                          lc_division,
                          lc_department
                      FROM mtl_item_categories_v
                      WHERE category_set_name = 'Inventory'
                            AND inventory_item_id = ont_line_def_hdlr.g_record.inventory_item_id
                            AND enabled_flag = 'Y'
                            AND ROWNUM = 1;
             VER 1.12  END   */

            /* START APURV AGARWAL 15-JUNE-2015 - Commented the code to fix warehouse default issue for Department APPAREL
            --get warehouse from mapping lookup
            SELECT ood.organization_id
            INTO   ln_org_id
            FROM   fnd_lookup_values_vl         flv
                  ,org_organization_definitions ood
            WHERE  flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
            AND    flv.enabled_flag = 'Y'
            AND    trunc(SYSDATE) BETWEEN flv.start_date_active AND
                   nvl(flv.end_date_active, trunc(SYSDATE))
            AND    flv.description = lc_ou_name
            AND    nvl(attribute1, lc_line_type) = lc_line_type
            AND    flv.attribute2 = lc_brand
            AND    nvl(flv.attribute3, lc_division) = lc_division
            AND    nvl(flv.attribute4, lc_department) = lc_department
            AND    flv.attribute5 = ood.organization_code;
            END Changes 15-JUNE-2015*/
            --START Changes 15-JUNE-2015 - Added to fix the warehouse defaulting issue for Department APPAREL

            BEGIN
                SELECT ood.organization_id
                  INTO ln_org_id
                  FROM fnd_lookup_values_vl flv, org_organization_definitions ood
                 WHERE     flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
                       AND flv.enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                               AND NVL (flv.end_date_active,
                                                        TRUNC (SYSDATE))
                       AND flv.description = lc_ou_name
                       AND NVL (attribute1, lc_line_type) = lc_line_type
                       AND flv.attribute2 = lc_brand
                       AND flv.attribute3 = lc_division
                       AND flv.attribute4 = lc_department
                       AND flv.attribute5 = ood.organization_code;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_org_id   := NULL;
                WHEN OTHERS
                THEN
                    ln_org_id   := NULL;
            END;

            BEGIN
                IF ln_org_id IS NULL
                THEN
                    SELECT ood.organization_id
                      INTO ln_org_id
                      FROM fnd_lookup_values_vl flv, org_organization_definitions ood
                     WHERE     flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           TRUNC (SYSDATE))
                           AND flv.description = lc_ou_name
                           AND NVL (attribute1, lc_line_type) = lc_line_type
                           AND flv.attribute2 = lc_brand
                           AND flv.attribute3 = lc_division
                           AND flv.attribute4 IS NULL
                           AND flv.attribute5 = ood.organization_code;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_org_id   := NULL;
                WHEN OTHERS
                THEN
                    ln_org_id   := NULL;
            END;

            BEGIN
                IF ln_org_id IS NULL
                THEN
                    SELECT ood.organization_id
                      INTO ln_org_id
                      FROM fnd_lookup_values_vl flv, org_organization_definitions ood
                     WHERE     flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                                   AND NVL (
                                                           flv.end_date_active,
                                                           TRUNC (SYSDATE))
                           AND flv.description = lc_ou_name
                           AND NVL (attribute1, lc_line_type) = lc_line_type
                           AND flv.attribute2 = lc_brand
                           AND flv.attribute3 IS NULL
                           AND flv.attribute4 IS NULL
                           AND flv.attribute5 = ood.organization_code;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_org_id   := NULL;
                WHEN OTHERS
                THEN
                    ln_org_id   := NULL;
            END;
        END IF;

        -- END changes 15-JUNE-2015

        RETURN ln_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --start changes v1.3

    FUNCTION ret_org_move_warehouse (pn_org_id IN NUMBER, pv_brand IN VARCHAR2, pn_order_type_id IN NUMBER
                                     , pd_request_date DATE)
        RETURN NUMBER
    IS
        ln_ou_id           NUMBER := fnd_profile.VALUE ('ORG_ID');
        ln_org_id          NUMBER;
        lc_ou_name         VARCHAR2 (100);
        ln_order_type_id   NUMBER;
    BEGIN
        SELECT TO_NUMBER (flv.attribute5)
          INTO ln_org_id
          FROM fnd_lookup_values_vl flv
         WHERE     flv.lookup_type = 'XXD_ORG_MOVE_WH_DEFAULTS'
               AND flv.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE))
               AND TO_NUMBER (flv.attribute1) = pn_org_id
               AND ((TO_NUMBER (attribute2) IS NOT NULL AND TO_NUMBER (attribute2) = pn_order_type_id) OR (TO_NUMBER (attribute2) IS NULL AND 1 = 1))
               AND flv.tag = pv_brand
               AND pd_request_date >=
                   TO_DATE (flv.attribute3, 'YYYY/MM/DD HH24:mi:ss')
               AND ((flv.attribute4 IS NULL AND 1 = 1) OR (flv.attribute4 IS NOT NULL AND pd_request_date <= TO_DATE (flv.attribute4, 'YYYY/MM/DD HH24:mi:ss')));

        RETURN ln_org_id;
    EXCEPTION
        WHEN TOO_MANY_ROWS
        THEN
            SELECT TO_NUMBER (flv.attribute5)
              INTO ln_org_id
              FROM fnd_lookup_values_vl flv
             WHERE     flv.lookup_type = 'XXD_ORG_MOVE_WH_DEFAULTS'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                           AND NVL (flv.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND TO_NUMBER (flv.attribute1) = pn_org_id
                   AND ((TO_NUMBER (attribute2) IS NOT NULL AND TO_NUMBER (attribute2) = pn_order_type_id))
                   AND flv.tag = pv_brand
                   AND pd_request_date >=
                       TO_DATE (flv.attribute3, 'YYYY/MM/DD HH24:mi:ss')
                   AND ((flv.attribute4 IS NULL AND 1 = 1) OR (flv.attribute4 IS NOT NULL AND pd_request_date <= TO_DATE (flv.attribute4, 'YYYY/MM/DD HH24:mi:ss')));

            RETURN ln_org_id;
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --end changes v1.3
    --  Added by Vijay Reddy for eCommerce SFS functionality

    PROCEDURE get_warehouse (p_org_id IN NUMBER, p_line_type_id IN NUMBER, p_inventory_item_id IN NUMBER
                             , p_order_type_id IN NUMBER, --ver 1.12  -- added as default param
                                                          p_request_date IN DATE, -- ver 1.12 --added as default param
                                                                                  x_warehouse_id OUT NUMBER)
    IS
        ln_org_id       NUMBER;
        lc_ou_name      VARCHAR2 (100);
        lc_line_type    VARCHAR2 (300);
        lc_brand        VARCHAR2 (40);
        lc_division     VARCHAR2 (40);
        lc_department   VARCHAR2 (40);
        lc_class        VARCHAR2 (100);                            -- ver 1.12
        lc_subclass     VARCHAR2 (100);                            -- ver 1.12
    BEGIN
        --get OU name
        SELECT name
          INTO lc_ou_name
          FROM hr_operating_units
         WHERE     organization_id = p_org_id
               AND TRUNC (SYSDATE) BETWEEN NVL (date_from, TRUNC (SYSDATE))
                                       AND NVL (date_to, TRUNC (SYSDATE));

        lc_line_type     := '~';

        --get line type
        IF p_line_type_id IS NOT NULL
        THEN
            SELECT t.name
              INTO lc_line_type
              FROM oe_transaction_types_tl t, oe_transaction_types_all b
             WHERE     b.transaction_type_id = t.transaction_type_id
                   AND t.language = USERENV ('LANG')
                   AND TRUNC (SYSDATE) BETWEEN b.start_date_active
                                           AND NVL (b.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND b.transaction_type_code = 'LINE'
                   AND b.transaction_type_id = p_line_type_id;
        END IF;

        --get brand, division, department

        SELECT segment1, segment2, segment3
          INTO lc_brand, lc_division, lc_department
          FROM mtl_item_categories_v
         WHERE     category_set_name = 'Inventory'
               AND inventory_item_id = p_inventory_item_id
               AND enabled_flag = 'Y'
               AND ROWNUM = 1;


        BEGIN
            SELECT ood.organization_id
              INTO ln_org_id
              FROM fnd_lookup_values_vl flv, org_organization_definitions ood
             WHERE     flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                           AND NVL (flv.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND flv.description = lc_ou_name
                   AND NVL (attribute1, lc_line_type) = lc_line_type
                   AND flv.attribute2 = lc_brand
                   AND flv.attribute3 = lc_division
                   AND flv.attribute4 = lc_department
                   AND flv.attribute5 = ood.organization_code;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_org_id   := NULL;
            WHEN OTHERS
            THEN
                ln_org_id   := NULL;
        END;

        BEGIN
            IF ln_org_id IS NULL
            THEN
                SELECT ood.organization_id
                  INTO ln_org_id
                  FROM fnd_lookup_values_vl flv, org_organization_definitions ood
                 WHERE     flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
                       AND flv.enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                               AND NVL (flv.end_date_active,
                                                        TRUNC (SYSDATE))
                       AND flv.description = lc_ou_name
                       AND NVL (attribute1, lc_line_type) = lc_line_type
                       AND flv.attribute2 = lc_brand
                       AND flv.attribute3 = lc_division
                       AND flv.attribute4 IS NULL
                       AND flv.attribute5 = ood.organization_code;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_org_id   := NULL;
            WHEN OTHERS
            THEN
                ln_org_id   := NULL;
        END;

        BEGIN
            IF ln_org_id IS NULL
            THEN
                SELECT ood.organization_id
                  INTO ln_org_id
                  FROM fnd_lookup_values_vl flv, org_organization_definitions ood
                 WHERE     flv.lookup_type = 'XXDO_WAREHOUSE_DEFAULTS'
                       AND flv.enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN flv.start_date_active
                                               AND NVL (flv.end_date_active,
                                                        TRUNC (SYSDATE))
                       AND flv.description = lc_ou_name
                       AND NVL (attribute1, lc_line_type) = lc_line_type
                       AND flv.attribute2 = lc_brand
                       AND flv.attribute3 IS NULL
                       AND flv.attribute4 IS NULL
                       AND flv.attribute5 = ood.organization_code;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_org_id   := NULL;
            WHEN OTHERS
            THEN
                ln_org_id   := NULL;
        END;


        -- END changes 15-JUNE-2015

        x_warehouse_id   := ln_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_warehouse_id   := NULL;
    END get_warehouse;

    --Start of changes for CCR CCR0007850
    --Function return demand_class_code for internal order from lookup XXD_ONT_ISO_DEMAND_CLASS_DEF

    FUNCTION internal_order_demclass (p_database_object_name   IN VARCHAR2,
                                      p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_header_rec     oe_ak_order_headers_v%ROWTYPE;
        lv_demclass      VARCHAR2 (150) := NULL;
        ln_location_id   NUMBER := NULL;
    BEGIN
        l_header_rec   := ont_header_def_hdlr.g_record;

        --get location_id from order ship_to_org_id
        BEGIN
            SELECT hrl.location_id
              INTO ln_location_id
              FROM apps.hz_cust_site_uses_all su, apps.po_location_associations_all pla, apps.hr_locations hrl
             WHERE     su.site_use_id = l_header_rec.ship_to_org_id
                   AND su.site_use_id = pla.site_use_id
                   AND pla.location_id = hrl.location_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_location_id   := NULL;
            WHEN OTHERS
            THEN
                ln_location_id   := NULL;
        END;

        --Get deamand class from lookup XXD_ONT_ISO_DEMAND_CLASS_DEF

        BEGIN
            SELECT attribute5
              INTO lv_demclass
              FROM fnd_lookup_values flv
             WHERE     lookup_type = 'XXD_ONT_ISO_DEMAND_CLASS_DEF'
                   AND language = USERENV ('Lang')
                   AND (TRUNC (SYSDATE) BETWEEN TRUNC (NVL (flv.start_date_active, SYSDATE)) AND TRUNC (NVL (flv.end_date_active, SYSDATE)))
                   AND attribute_category = 'XXD_ONT_ISO_DEMAND_CLASS_DEF'
                   AND enabled_flag = 'Y'
                   AND attribute1 = l_header_rec.order_type_id
                   AND attribute2 = l_header_rec.sold_to_org_id
                   AND attribute3 = ln_location_id
                   AND attribute4 = l_header_rec.attribute5;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_demclass   := NULL;
            WHEN OTHERS
            THEN
                lv_demclass   := NULL;
        END;

        RETURN lv_demclass;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END internal_order_demclass;

    --End of changes for CCR CCR0007850
    -- Start changes for CCR0008531

    FUNCTION ret_ecomm_demand_class (p_database_object_name   IN VARCHAR2,
                                     p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR get_demand_class IS
            SELECT flvv.attribute4 demand_class_code
              FROM fnd_lookup_values_vl flvv
             WHERE     flvv.lookup_type = 'XXD_ONT_ECOMM_DEMAND_CLASS_DEF'
                   AND flvv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN start_date_active
                                           AND NVL (end_date_active,
                                                    TRUNC (SYSDATE) + 1)
                   AND TO_NUMBER (flvv.attribute1) =
                       ont_line_def_hdlr.g_record.org_id
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_common_items_v xciv
                             WHERE     xciv.inventory_item_id =
                                       ont_line_def_hdlr.g_record.inventory_item_id
                                   AND xciv.organization_id =
                                       TO_NUMBER (flvv.attribute3)
                                   AND TO_NUMBER (flvv.attribute3) =
                                       ont_line_def_hdlr.g_record.ship_from_org_id
                                   AND xciv.brand = flvv.attribute2);

        lcu_demand_class_rec   get_demand_class%ROWTYPE;
        lc_demand_class_code   oe_order_lines_all.demand_class_code%TYPE;
    BEGIN
        OPEN get_demand_class;

        FETCH get_demand_class INTO lcu_demand_class_rec;

        lc_demand_class_code   := lcu_demand_class_rec.demand_class_code;

        CLOSE get_demand_class;

        RETURN lc_demand_class_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_ecomm_demand_class;

    -- End changes for CCR0008531
    --ver 1.6 Start Changes for CCR0008530

    FUNCTION ret_globale_tax_code (p_database_object_name   IN VARCHAR2,
                                   p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR get_tax_code IS
            SELECT DISTINCT vl.description tax_code
              FROM fnd_flex_values_vl vl, fnd_flex_value_sets fvs
             WHERE     vl.flex_value_set_id = fvs.flex_value_set_id
                   AND fvs.flex_value_set_name =
                       'XXD_GLOBALE_TAX_CODE_MAPPING'
                   AND vl.flex_value =
                       ont_header_def_hdlr.g_record.shipping_method_code
                   AND vl.enabled_flag = 'Y'
                   AND TO_NUMBER (vl.attribute1) =
                       ont_header_def_hdlr.g_record.org_id
                   AND TRUNC (SYSDATE) BETWEEN NVL (vl.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (vl.end_date_active,
                                                    TRUNC (SYSDATE) + 1);

        lcu_tax_code_rec   get_tax_code%ROWTYPE;
        lc_tax_code        oe_order_lines_all.tax_code%TYPE;
    BEGIN
        OPEN get_tax_code;

        FETCH get_tax_code INTO lcu_tax_code_rec;

        lc_tax_code   := lcu_tax_code_rec.tax_code;

        CLOSE get_tax_code;

        RETURN lc_tax_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_globale_tax_code;

    --End Changes for CCR0008530
    -- begin ver 1.7

    FUNCTION ret_hdrshipinstr (p_database_object_name   IN VARCHAR2,
                               p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_shipinstr   VARCHAR2 (2000) := NULL;

        CURSOR lcu_get_long_text (p_cust_account_id   IN NUMBER,
                                  p_user_name         IN VARCHAR2)
        IS
            SELECT long_text
              FROM oe_attachment_rules oar, fnd_documents_vl fdv, fnd_documents_long_text fdl,
                   fnd_document_categories_vl fdc, hz_parties party, hz_cust_accounts cust,
                   oe_attachment_rule_elements_v oare
             WHERE     1 = 1
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

        lc_shipping   VARCHAR2 (30) := 'Shipping Instructions';
    BEGIN
        BEGIN
            SELECT SUBSTR (shipping_instructions, 1, 2000)
              INTO v_shipinstr
              FROM xxd_ont_customer_shipto_info_t
             WHERE     cust_account_id =
                       ont_header_def_hdlr.g_record.sold_to_org_id
                   AND ship_to_site_id =
                       ont_header_def_hdlr.g_record.ship_to_org_id;
        EXCEPTION
            /*WHEN no_data_found THEN
                BEGIN
                    SELECT substr(
                        shipping_instructions,
                        1,
                        2000
                    )
                    INTO v_shipinstr
                    FROM xxd_ont_customer_header_info_t
                    WHERE cust_account_id = ont_header_def_hdlr.g_record.sold_to_org_id;

                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;*/
            WHEN OTHERS
            THEN
                NULL;
        END;

        ----- Added for CCR0009521 on 01 Sept 2021----

        IF v_shipinstr IS NULL
        THEN
            BEGIN
                SELECT SUBSTR (shipping_instructions, 1, 2000)
                  INTO v_shipinstr
                  FROM xxd_ont_customer_header_info_t
                 WHERE cust_account_id =
                       ont_header_def_hdlr.g_record.sold_to_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        BEGIN
            IF v_shipinstr IS NULL
            THEN
                OPEN lcu_get_long_text (
                    ont_header_def_hdlr.g_record.sold_to_org_id,
                    lc_shipping);

                FETCH lcu_get_long_text INTO v_shipinstr;

                CLOSE lcu_get_long_text;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;


        --RETURN v_shipinstr;
        ----- End of CCR0009521 ----

        RETURN v_shipinstr;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_hdrshipinstr;

    FUNCTION ret_hdrpackinstr (p_database_object_name   IN VARCHAR2,
                               p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_packinstr   VARCHAR2 (2000) := NULL;

        CURSOR lcu_get_long_text (p_cust_account_id   IN NUMBER,
                                  p_user_name         IN VARCHAR2)
        IS
            SELECT long_text
              FROM oe_attachment_rules oar, fnd_documents_vl fdv, fnd_documents_long_text fdl,
                   fnd_document_categories_vl fdc, hz_parties party, hz_cust_accounts cust,
                   oe_attachment_rule_elements_v oare
             WHERE     1 = 1
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

        lc_packing    VARCHAR2 (30) := 'Packing Instructions';
    BEGIN
        BEGIN
            SELECT SUBSTR (packing_instructions, 1, 2000)
              INTO v_packinstr
              FROM xxd_ont_customer_shipto_info_t
             WHERE     cust_account_id =
                       ont_header_def_hdlr.g_record.sold_to_org_id
                   AND ship_to_site_id =
                       ont_header_def_hdlr.g_record.ship_to_org_id;
        EXCEPTION
            /* WHEN no_data_found THEN
                 BEGIN
                     SELECT substr(
                         packing_instructions,
                         1,
                         2000
                     )
                     INTO v_packinstr
                     FROM xxd_ont_customer_header_info_t
                     WHERE cust_account_id = ont_header_def_hdlr.g_record.sold_to_org_id;

                 EXCEPTION
                     WHEN OTHERS THEN
                         NULL;
                 END;*/
            WHEN OTHERS
            THEN
                NULL;
        END;

        ----- Added for CCR0009521 on 01 Sept 2021----

        IF v_packinstr IS NULL
        THEN
            BEGIN
                SELECT SUBSTR (packing_instructions, 1, 2000)
                  INTO v_packinstr
                  FROM xxd_ont_customer_header_info_t
                 WHERE cust_account_id =
                       ont_header_def_hdlr.g_record.sold_to_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        BEGIN
            IF v_packinstr IS NULL
            THEN
                OPEN lcu_get_long_text (
                    ont_header_def_hdlr.g_record.sold_to_org_id,
                    lc_packing);

                FETCH lcu_get_long_text INTO v_packinstr;

                CLOSE lcu_get_long_text;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        --  RETURN v_packinstr;
        ----- End of CCR0009521 ----

        RETURN v_packinstr;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_hdrpackinstr;

    FUNCTION ret_lineshipinstr (p_database_object_name   IN VARCHAR2,
                                p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_shipinstr   VARCHAR2 (2000) := NULL;

        CURSOR lcu_get_long_text (p_cust_account_id   IN NUMBER,
                                  p_user_name         IN VARCHAR2)
        IS
            SELECT long_text
              FROM oe_attachment_rules oar, fnd_documents_vl fdv, fnd_documents_long_text fdl,
                   fnd_document_categories_vl fdc, hz_parties party, hz_cust_accounts cust,
                   oe_attachment_rule_elements_v oare
             WHERE     1 = 1
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

        lc_shipping   VARCHAR2 (30) := 'Shipping Instructions';
    BEGIN
        -- CHECK FOR SHIP TO SITE FIRST; IF FOUND RETURN OTHERWISE CHECK AT CUSTOMER LEVEL
        BEGIN
            SELECT SUBSTR (shipping_instructions, 1, 2000)
              INTO v_shipinstr
              FROM xxd_ont_customer_shipto_info_t
             WHERE     cust_account_id =
                       ont_line_def_hdlr.g_record.sold_to_org_id
                   AND ship_to_site_id =
                       ont_line_def_hdlr.g_record.ship_to_org_id;
        EXCEPTION
            /*   WHEN no_data_found THEN
               -- NO SHIPPING AND PACKING INSTRUCTION AT CUST SITE LEVEL; CHECK AT CUSTOMER LEVEL
                   BEGIN
                       SELECT substr(
                           shipping_instructions,
                           1,
                           2000
                       )
                       INTO v_shipinstr
                       FROM xxd_ont_customer_header_info_t
                       WHERE cust_account_id = ont_line_def_hdlr.g_record.sold_to_org_id;

                   EXCEPTION
                       WHEN OTHERS THEN
                           NULL;
                   END;*/
            WHEN OTHERS
            THEN
                NULL;
        END;

        ----- Added for CCR0009521 on 01 Sept 2021----

        IF v_shipinstr IS NULL
        THEN
            BEGIN
                SELECT SUBSTR (shipping_instructions, 1, 2000)
                  INTO v_shipinstr
                  FROM xxd_ont_customer_header_info_t
                 WHERE cust_account_id =
                       ont_line_def_hdlr.g_record.sold_to_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        BEGIN
            IF v_shipinstr IS NULL
            THEN
                OPEN lcu_get_long_text (
                    ont_line_def_hdlr.g_record.sold_to_org_id,
                    lc_shipping);

                FETCH lcu_get_long_text INTO v_shipinstr;

                CLOSE lcu_get_long_text;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        --RETURN v_shipinstr;
        ----- End of CCR0009521 ----

        RETURN v_shipinstr;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_lineshipinstr;

    FUNCTION ret_linepackinstr (p_database_object_name   IN VARCHAR2,
                                p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_packinstr   VARCHAR2 (2000) := NULL;

        CURSOR lcu_get_long_text (p_cust_account_id   IN NUMBER,
                                  p_user_name         IN VARCHAR2)
        IS
            SELECT long_text
              FROM oe_attachment_rules oar, fnd_documents_vl fdv, fnd_documents_long_text fdl,
                   fnd_document_categories_vl fdc, hz_parties party, hz_cust_accounts cust,
                   oe_attachment_rule_elements_v oare
             WHERE     1 = 1
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

        lc_packing    VARCHAR2 (30) := 'Packing Instructions';
    BEGIN
        -- CHECK FOR SHIP TO SITE FIRST; IF FOUND RETURN OTHERWISE CHECK AT CUSTOMER LEVEL
        BEGIN
            SELECT SUBSTR (packing_instructions, 1, 2000)
              INTO v_packinstr
              FROM xxd_ont_customer_shipto_info_t
             WHERE     cust_account_id =
                       ont_line_def_hdlr.g_record.sold_to_org_id
                   AND ship_to_site_id =
                       ont_line_def_hdlr.g_record.ship_to_org_id;
        EXCEPTION
            /* WHEN no_data_found THEN
             -- NO SHIPPING AND PACKING INSTRUCTION AT CUST SITE LEVEL; CHECK AT CUSTOMER LEVEL
                 BEGIN
                     SELECT substr(
                         packing_instructions,
                         1,
                         2000
                     )
                     INTO v_packinstr
                     FROM xxd_ont_customer_header_info_t
                     WHERE cust_account_id = ont_line_def_hdlr.g_record.sold_to_org_id;

                 EXCEPTION
                     WHEN OTHERS THEN
                         NULL;
                 END;*/
            WHEN OTHERS
            THEN
                NULL;
        END;

        ----- Added for CCR0009521 on 01 Sept 2021----

        IF v_packinstr IS NULL
        THEN
            BEGIN
                SELECT SUBSTR (packing_instructions, 1, 2000)
                  INTO v_packinstr
                  FROM xxd_ont_customer_header_info_t
                 WHERE cust_account_id =
                       ont_line_def_hdlr.g_record.sold_to_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        BEGIN
            IF v_packinstr IS NULL
            THEN
                OPEN lcu_get_long_text (
                    ont_line_def_hdlr.g_record.sold_to_org_id,
                    lc_packing);

                FETCH lcu_get_long_text INTO v_packinstr;

                CLOSE lcu_get_long_text;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        --  RETURN v_packinstr;
        ----- End of CCR0009521 ----

        RETURN v_packinstr;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END ret_linepackinstr;

    -- end ver 1.7

    --Start v1.8 DXLabs Changes

    -- Ship Method Header

    FUNCTION ret_hdr_ship_method (p_database_object_name   IN VARCHAR2,
                                  p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_header_rec     oe_ak_order_headers_v%ROWTYPE;
        ln_cnt           NUMBER;
        lv_org_id        VARCHAR2 (30);
        lv_brand_code    VARCHAR2 (30);
        lv_deliver_to    VARCHAR2 (30);
        lv_ship_to       VARCHAR2 (30);
        lv_ship_method   VARCHAR2 (30);
    BEGIN
        l_header_rec    := ont_header_def_hdlr.g_record;

        --assign header variables
        lv_org_id       := TO_CHAR (l_header_rec.org_id);
        lv_brand_code   := l_header_rec.attribute5;
        lv_deliver_to   := TO_CHAR (l_header_rec.deliver_to_org_id);
        lv_ship_to      := TO_CHAR (l_header_rec.ship_to_org_id);

        --Get the Ship Method for org id and brand from the lookup
        SELECT flv.attribute3
          INTO lv_ship_method
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_ONT_APO_DEFAULTS'
               AND flv.language = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND flv.attribute1 = lv_org_id
               AND flv.attribute2 = lv_brand_code
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        IF lv_ship_method IS NOT NULL
        THEN
            BEGIN
                --Check whether the state is present in the lookup.
                SELECT COUNT (*)
                  INTO ln_cnt
                  FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_acct_sites_all hcas,
                       apps.hz_cust_site_uses_all hcsu
                 WHERE     hl.location_id = hps.location_id
                       AND hcas.party_site_id = hps.party_site_id
                       AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                       --AND hcsu.site_use_code = 'SHIP_TO'
                       AND hcsu.status = 'A'
                       AND hcsu.site_use_id = NVL (lv_deliver_to, lv_ship_to)
                       AND hcsu.org_id = lv_org_id
                       AND hl.country = 'US'
                       AND hl.state IN
                               (SELECT flv.lookup_code
                                  FROM fnd_lookup_values flv
                                 WHERE     flv.lookup_type =
                                           'XXD_ONT_APO_STATES'
                                       AND flv.language = USERENV ('LANG')
                                       AND enabled_flag = 'Y'
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       flv.start_date_active,
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       flv.end_date_active,
                                                                         TRUNC (
                                                                             SYSDATE)
                                                                       + 1));

                IF ln_cnt = 0
                THEN
                    lv_ship_method   := NULL;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ship_method   := NULL;
            END;
        END IF;

        RETURN lv_ship_method;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_ship_method   := NULL;
            RETURN lv_ship_method;
    END ret_hdr_ship_method;

    -- Freight Term Header

    FUNCTION ret_hdr_freight_term (p_database_object_name   IN VARCHAR2,
                                   p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_header_rec      oe_ak_order_headers_v%ROWTYPE;
        ln_cnt            NUMBER;
        lv_org_id         VARCHAR2 (30);
        lv_brand_code     VARCHAR2 (30);
        lv_deliver_to     VARCHAR2 (30);
        lv_ship_to        VARCHAR2 (30);
        lv_freight_term   VARCHAR2 (150);
    BEGIN
        l_header_rec    := ont_header_def_hdlr.g_record;

        --assign header variables
        lv_org_id       := TO_CHAR (l_header_rec.org_id);
        lv_brand_code   := l_header_rec.attribute5;
        lv_deliver_to   := TO_CHAR (l_header_rec.deliver_to_org_id);
        lv_ship_to      := TO_CHAR (l_header_rec.ship_to_org_id);

        --Get the Freight Term for org id and brand from the lookup
        SELECT flv.attribute4
          INTO lv_freight_term
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_ONT_APO_DEFAULTS'
               AND flv.language = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND flv.attribute1 = lv_org_id
               AND flv.attribute2 = lv_brand_code
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        IF lv_freight_term IS NOT NULL
        THEN
            BEGIN
                --Check whether the state is present in the lookup.
                SELECT COUNT (*)
                  INTO ln_cnt
                  FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_acct_sites_all hcas,
                       apps.hz_cust_site_uses_all hcsu
                 WHERE     hl.location_id = hps.location_id
                       AND hcas.party_site_id = hps.party_site_id
                       AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                       --AND hcsu.site_use_code = 'SHIP_TO'
                       AND hcsu.status = 'A'
                       AND hcsu.site_use_id = NVL (lv_deliver_to, lv_ship_to)
                       AND hcsu.org_id = lv_org_id
                       AND hl.country = 'US'
                       AND hl.state IN
                               (SELECT flv.lookup_code
                                  FROM fnd_lookup_values flv
                                 WHERE     flv.lookup_type =
                                           'XXD_ONT_APO_STATES'
                                       AND flv.language = USERENV ('LANG')
                                       AND enabled_flag = 'Y'
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       flv.start_date_active,
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       flv.end_date_active,
                                                                         TRUNC (
                                                                             SYSDATE)
                                                                       + 1));

                IF ln_cnt = 0
                THEN
                    lv_freight_term   := NULL;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_freight_term   := NULL;
            END;
        END IF;

        RETURN lv_freight_term;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_freight_term   := NULL;
            RETURN lv_freight_term;
    END ret_hdr_freight_term;

    -- Ship Method Line

    FUNCTION ret_line_ship_method (p_database_object_name   IN VARCHAR2,
                                   p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_header_rec     oe_ak_order_headers_v%ROWTYPE;
        l_line_rec       oe_ak_order_lines_v%ROWTYPE;
        ln_cnt           NUMBER;
        lv_org_id        VARCHAR2 (30);
        lv_brand_code    VARCHAR2 (30);
        lv_deliver_to    VARCHAR2 (30);
        lv_ship_to       VARCHAR2 (30);
        lv_ship_method   VARCHAR2 (150);
    BEGIN
        l_header_rec    := ont_header_def_hdlr.g_record;
        l_line_rec      := ont_line_def_hdlr.g_record;

        --assign header variables
        lv_org_id       := TO_CHAR (l_line_rec.org_id);
        lv_brand_code   := l_header_rec.attribute5;
        lv_deliver_to   := TO_CHAR (l_line_rec.deliver_to_org_id);
        lv_ship_to      := TO_CHAR (l_line_rec.ship_to_org_id);

        --Get the Ship Method for org id and brand from the lookup
        SELECT flv.attribute3
          INTO lv_ship_method
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_ONT_APO_DEFAULTS'
               AND flv.language = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND flv.attribute1 = lv_org_id
               AND flv.attribute2 = lv_brand_code
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        IF lv_ship_method IS NOT NULL
        THEN
            BEGIN
                --Check whether the state is present in the lookup.
                SELECT COUNT (*)
                  INTO ln_cnt
                  FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_acct_sites_all hcas,
                       apps.hz_cust_site_uses_all hcsu
                 WHERE     hl.location_id = hps.location_id
                       AND hcas.party_site_id = hps.party_site_id
                       AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                       --AND hcsu.site_use_code = 'SHIP_TO'
                       AND hcsu.status = 'A'
                       AND hcsu.site_use_id = NVL (lv_deliver_to, lv_ship_to)
                       AND hcsu.org_id = lv_org_id
                       AND hl.country = 'US'
                       AND hl.state IN
                               (SELECT flv.lookup_code
                                  FROM fnd_lookup_values flv
                                 WHERE     flv.lookup_type =
                                           'XXD_ONT_APO_STATES'
                                       AND flv.language = USERENV ('LANG')
                                       AND enabled_flag = 'Y'
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       flv.start_date_active,
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       flv.end_date_active,
                                                                         TRUNC (
                                                                             SYSDATE)
                                                                       + 1));

                IF ln_cnt = 0
                THEN
                    lv_ship_method   := NULL;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ship_method   := NULL;
            END;
        END IF;

        RETURN lv_ship_method;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_ship_method   := NULL;
            RETURN lv_ship_method;
    END ret_line_ship_method;

    -- Freight Term Line

    FUNCTION ret_line_freight_term (p_database_object_name   IN VARCHAR2,
                                    p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_header_rec      oe_ak_order_headers_v%ROWTYPE;
        l_line_rec        oe_ak_order_lines_v%ROWTYPE;
        ln_cnt            NUMBER;
        lv_org_id         VARCHAR2 (30);
        lv_brand_code     VARCHAR2 (30);
        lv_deliver_to     VARCHAR2 (30);
        lv_ship_to        VARCHAR2 (30);
        lv_freight_term   VARCHAR2 (150);
    BEGIN
        l_header_rec    := ont_header_def_hdlr.g_record;
        l_line_rec      := ont_line_def_hdlr.g_record;

        --assign header variables
        lv_org_id       := TO_CHAR (l_line_rec.org_id);
        lv_brand_code   := l_header_rec.attribute5;
        lv_deliver_to   := TO_CHAR (l_line_rec.deliver_to_org_id);
        lv_ship_to      := TO_CHAR (l_line_rec.ship_to_org_id);

        --Get the Freight Term for org id and brand from the lookup
        SELECT flv.attribute4
          INTO lv_freight_term
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_ONT_APO_DEFAULTS'
               AND flv.language = USERENV ('LANG')
               AND enabled_flag = 'Y'
               AND flv.attribute1 = lv_org_id
               AND flv.attribute2 = lv_brand_code
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                TRUNC (SYSDATE))
                                       AND NVL (flv.end_date_active,
                                                TRUNC (SYSDATE) + 1);

        IF lv_freight_term IS NOT NULL
        THEN
            BEGIN
                --Check whether the state is present in the lookup.
                SELECT COUNT (*)
                  INTO ln_cnt
                  FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_acct_sites_all hcas,
                       apps.hz_cust_site_uses_all hcsu
                 WHERE     hl.location_id = hps.location_id
                       AND hcas.party_site_id = hps.party_site_id
                       AND hcsu.cust_acct_site_id = hcas.cust_acct_site_id
                       --AND hcsu.site_use_code = 'SHIP_TO'
                       AND hcsu.status = 'A'
                       AND hcsu.site_use_id = NVL (lv_deliver_to, lv_ship_to)
                       AND hcsu.org_id = lv_org_id
                       AND hl.country = 'US'
                       AND hl.state IN
                               (SELECT flv.lookup_code
                                  FROM fnd_lookup_values flv
                                 WHERE     flv.lookup_type =
                                           'XXD_ONT_APO_STATES'
                                       AND flv.language = USERENV ('LANG')
                                       AND enabled_flag = 'Y'
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       flv.start_date_active,
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       flv.end_date_active,
                                                                         TRUNC (
                                                                             SYSDATE)
                                                                       + 1));

                IF ln_cnt = 0
                THEN
                    lv_freight_term   := NULL;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_freight_term   := NULL;
            END;
        END IF;

        RETURN lv_freight_term;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_freight_term   := NULL;
            RETURN lv_freight_term;
    END ret_line_freight_term;

    --End v1.8 DXLabs Changes

    --Start changes for v1.10

    FUNCTION ret_jp_bill_to_loc (p_database_object_name   IN VARCHAR2,
                                 p_attribute_code         IN VARCHAR2)
        RETURN VARCHAR2
    IS
        l_site_use_id   hz_cust_site_uses.site_use_id%TYPE;
    BEGIN
        BEGIN
            mo_global.set_policy_context ('S', fnd_global.org_id);
        END;

        l_site_use_id   := NULL;

        --To fetch parent bill to site
        BEGIN
            SELECT flv.attribute2
              INTO l_site_use_id
              FROM fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_JAPAN_WS_PARENT_ACCOUNTS'
                   AND flv.language = USERENV ('LANG')
                   AND enabled_flag = 'Y'
                   AND TO_NUMBER (flv.attribute1) =
                       ont_header_def_hdlr.g_record.sold_to_org_id
                   AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (flv.end_date_active,
                                                    TRUNC (SYSDATE) + 1);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN NULL;
            WHEN OTHERS
            THEN
                RETURN NULL;
        END;

        RETURN l_site_use_id;
    END ret_jp_bill_to_loc;

    --End changes for v1.10
    --begin ver 1.12
    FUNCTION ret_inv_warehouse (p_org_id              IN NUMBER,
                                p_order_type_id       IN NUMBER,
                                p_line_type_id        IN NUMBER,
                                p_request_date        IN DATE,
                                p_inventory_item_id   IN NUMBER)
        RETURN NUMBER
    IS
        l_inv_org        NUMBER;
        lc_brand         VARCHAR2 (100) := NULL;
        lc_division      VARCHAR2 (100) := NULL;
        lc_department    VARCHAR2 (100) := NULL;
        lc_masterclass   VARCHAR2 (100) := NULL;
        lc_subclass      VARCHAR2 (100) := NULL;
    BEGIN
        BEGIN
            SELECT segment1, segment2, segment3,
                   segment4, segment5
              INTO lc_brand, lc_division, lc_department, lc_masterclass,
                           lc_subclass
              FROM mtl_item_categories_v
             WHERE     category_set_name = 'Inventory'
                   AND inventory_item_id =
                       NVL (ont_line_def_hdlr.g_record.inventory_item_id,
                            p_inventory_item_id)
                   AND enabled_flag = 'Y'
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        l_inv_org   :=
            ret_inv_warehouse (p_org_id, p_order_type_id, p_line_type_id,
                               p_request_date, lc_brand, lc_division,
                               lc_department, lc_masterclass, lc_subclass);
        RETURN l_inv_org;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN l_inv_org;
    END ret_inv_warehouse;

    FUNCTION ret_inv_warehouse (pn_org_id IN NUMBER, pn_order_type_id IN NUMBER, pn_line_type_id IN NUMBER, pn_request_date IN DATE, pn_brand IN VARCHAR2, pn_division IN VARCHAR2
                                , pn_department IN VARCHAR2, pn_class IN VARCHAR2, pn_subclass IN VARCHAR2)
        RETURN NUMBER
    IS
        l_inv_org            NUMBER := NULL;
        l_in_clause_cols     VARCHAR2 (240);
        lv_sql               VARCHAR2 (1000);
        ORG_ID               NUMBER;
        LINE_TYPE_ID         NUMBER;
        ORDER_TYPE_ID        NUMBER;
        BRAND                VARCHAR2 (240);
        DIVISION             VARCHAR2 (240);
        DEPARTMENT           VARCHAR2 (240);
        MASTERCLASS          VARCHAR2 (240);
        SUBCLASS             VARCHAR2 (240);
        l_in_clause_values   VARCHAR2 (1000);
    BEGIN
        FOR i
            IN (  SELECT a.*,
                         CASE
                             WHEN org_id IS NOT NULL THEN 1
                             ELSE 0
                         END orgid_count,
                         CASE
                             WHEN order_type_id IS NOT NULL THEN 1
                             ELSE 0
                         END order_type_id_count,
                         CASE
                             WHEN line_type_id IS NOT NULL THEN 1
                             ELSE 0
                         END line_type_id_count,
                         CASE
                             WHEN brand IS NOT NULL THEN 1
                             ELSE 0
                         END brand_count,
                         CASE
                             WHEN division IS NOT NULL THEN 1
                             ELSE 0
                         END divisioncount,
                         CASE
                             WHEN department IS NOT NULL THEN 1
                             ELSE 0
                         END department_count,
                         CASE
                             WHEN class IS NOT NULL THEN 1
                             ELSE 0
                         END class_count,
                         CASE
                             WHEN subclass IS NOT NULL THEN 1
                             ELSE 0
                         END subclass_count
                    FROM XXD_ONT_DEF_RULES_V a
                   WHERE     1 = 1
                         AND org_id = pn_org_id
                         -- AND language = 'US'
                         AND TRUNC (pn_request_date) BETWEEN NVL (
                                                                 request_date_from,
                                                                 TRUNC (
                                                                     pn_request_date))
                                                         AND NVL (
                                                                 request_date_to,
                                                                 TRUNC (
                                                                     pn_request_date))
                --AND NVL (flv.end_date_active, SYSDATE + 1) > SYSDATE
                ORDER BY priority)
        LOOP
            BEGIN
                SELECT NEW_WAREHOUSE
                  INTO l_inv_org
                  FROM XXD_ONT_DEF_RULES_V
                 WHERE     1 = 1
                       AND (i.order_type_id_count = 0 AND order_type_id IS NULL OR (i.order_type_id_count = 1 AND order_type_id = pn_order_type_id))
                       AND (i.orgid_count = 0 AND org_id IS NULL OR (i.orgid_count = 1 AND org_id = pn_org_id))
                       AND (i.line_type_id_count = 0 AND line_type_id IS NULL OR (i.line_type_id_count = 1 AND line_type_id = pn_line_type_id))
                       AND (i.brand_count = 0 AND brand IS NULL OR (i.brand_count = 1 AND brand = pn_brand))
                       AND (i.divisioncount = 0 AND division IS NULL OR (i.divisioncount = 1 AND division = pn_division))
                       AND (i.department_count = 0 AND department IS NULL OR (i.department_count = 1 AND department = pn_department))
                       AND (i.class_count = 0 AND class IS NULL OR (i.class_count = 1 AND class = pn_class))
                       AND (i.subclass_count = 0 AND subclass IS NULL OR (i.subclass_count = 1 AND subclass = pn_subclass))
                       AND TRUNC (pn_request_date) BETWEEN NVL (
                                                               request_date_from,
                                                               TRUNC (
                                                                   pn_request_date))
                                                       AND NVL (
                                                               request_date_to,
                                                               TRUNC (
                                                                   pn_request_date));
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
                    CONTINUE;
            END;

            IF l_inv_org IS NOT NULL
            THEN
                RETURN l_inv_org;
            END IF;
        END LOOP;

        RETURN l_inv_org;
    END ret_inv_warehouse;
--end ver 1.12
END xxd_do_om_default_rules;
/


GRANT EXECUTE ON APPS.XXD_DO_OM_DEFAULT_RULES TO SOA_INT
/
