--
-- XXDO_ARSALES_TAX_DET_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ARSALES_TAX_DET_PKG"
/*------------------------------------------------------------------------------------*/
/* Ver No Developer  Date             Description */
/* */
/*-----------------------------------------------------------------------------------*/
/* 1.0                    Base Version */
/* 2.0   Infosys    30-Aug-2017      INC0363240 - Performance Improvement
           Changes Identified by 'PERFORMANCE'
/* 3.0   Infosys    24-Jan-2018      INC0363240 - Additional changes
           Changes Identified by 'COL DERV CHANGE','REMOVE COLUMNS','ADD COLUMN'
/*************************************************************************************/
IS
    gc_delimeter   VARCHAR2 (10) := ' | ';

    FUNCTION get_mmt_cost_sales (pn_interface_line_attribute6 IN VARCHAR2, pn_interface_line_attribute7 IN VARCHAR2, pn_organization_id IN NUMBER
                                 , pn_sob_id IN NUMBER, pv_detail IN VARCHAR)
        RETURN NUMBER
    IS
        ln_cost     NUMBER;
        ln_sob_id   NUMBER;
    BEGIN
        IF pn_organization_id IS NOT NULL
        THEN
            BEGIN
                SELECT set_of_books_id
                  INTO ln_sob_id
                  FROM org_organization_definitions
                 WHERE organization_id = pn_organization_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_sob_id   := pn_sob_id;
            END;
        ELSE
            ln_sob_id   := pn_sob_id;
        END IF;

        IF NVL (pn_interface_line_attribute7, 0) = 0
        THEN
            IF pv_detail = 'COGSAMT'
            THEN
                BEGIN
                      SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                        INTO ln_cost
                        FROM apps.xla_ae_lines xal,
                             (SELECT application_id, event_id, ae_header_id,
                                     ae_line_num
                                FROM apps.xla_distribution_links xdl
                               WHERE     xdl.source_distribution_type =
                                         'MTL_TRANSACTION_ACCOUNTS'
                                     AND EXISTS
                                             (SELECT 1
                                                FROM apps.mtl_transaction_accounts mta
                                               WHERE     mta.inv_sub_ledger_id =
                                                         xdl.source_distribution_id_num_1
                                                     AND EXISTS -- transaction_id IN
                                                             (SELECT 1 --transaction_id
                                                                FROM apps.mtl_material_transactions mmto
                                                               WHERE     mmto.transaction_id =
                                                                         mta.transaction_id
                                                                     AND mmto.trx_source_line_id =
                                                                         TO_NUMBER (
                                                                             pn_interface_line_attribute6))))
                             aa                  /*PERFORMANCE - TYPECASTING*/
                       WHERE     aa.application_id = xal.application_id
                             AND aa.ae_header_id = xal.ae_header_id
                             AND aa.ae_line_num = xal.ae_line_num
                             AND xal.accounting_class_code IN
                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                             AND xal.ledger_id = ln_sob_id
                    GROUP BY xal.code_combination_id;

                    RETURN ln_cost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                    WHEN OTHERS
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                END;
            ELSIF pv_detail = 'COGSCCID'
            THEN
                BEGIN
                      SELECT MAX (xal.code_combination_id)
                        INTO ln_cost
                        FROM apps.xla_ae_lines xal,
                             (SELECT application_id, event_id, ae_header_id,
                                     ae_line_num
                                FROM apps.xla_distribution_links xdl
                               WHERE     xdl.source_distribution_type =
                                         'MTL_TRANSACTION_ACCOUNTS'
                                     AND EXISTS
                                             (SELECT 1
                                                FROM apps.mtl_transaction_accounts mta
                                               WHERE     mta.inv_sub_ledger_id =
                                                         xdl.source_distribution_id_num_1
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM apps.mtl_material_transactions mmto
                                                               WHERE     mmto.transaction_id =
                                                                         mta.transaction_id
                                                                     AND mmto.trx_source_line_id =
                                                                         TO_NUMBER (
                                                                             pn_interface_line_attribute6))))
                             aa                  /*PERFORMANCE - TYPECASTING*/
                       WHERE     aa.application_id = xal.application_id
                             AND aa.ae_header_id = xal.ae_header_id
                             AND aa.ae_line_num = xal.ae_line_num
                             AND xal.accounting_class_code IN
                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                             AND xal.ledger_id = ln_sob_id
                    GROUP BY xal.code_combination_id;

                    RETURN ln_cost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                    WHEN OTHERS
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                END;
            ELSIF pv_detail = 'MATAMT'
            THEN
                BEGIN
                      SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                        INTO ln_cost
                        FROM apps.xla_ae_lines xal,
                             (SELECT application_id, event_id, ae_header_id,
                                     ae_line_num
                                FROM apps.xla_distribution_links xdl
                               WHERE     xdl.source_distribution_type =
                                         'MTL_TRANSACTION_ACCOUNTS'
                                     AND EXISTS
                                             (SELECT 1
                                                FROM apps.mtl_transaction_accounts mta
                                               WHERE     mta.cost_element_id =
                                                         1
                                                     AND mta.inv_sub_ledger_id =
                                                         xdl.source_distribution_id_num_1
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM apps.mtl_material_transactions mmto
                                                               WHERE     mmto.trx_source_line_id =
                                                                         TO_NUMBER (
                                                                             pn_interface_line_attribute6) /*PERFORMANCE - TYPECASTING*/
                                                                     AND mmto.transaction_id =
                                                                         mta.transaction_id)))
                             aa
                       WHERE     aa.application_id = xal.application_id
                             AND aa.ae_header_id = xal.ae_header_id
                             AND aa.ae_line_num = xal.ae_line_num
                             AND xal.accounting_class_code IN
                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                             AND xal.ledger_id = ln_sob_id
                    GROUP BY xal.code_combination_id;

                    RETURN ln_cost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                    WHEN OTHERS
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                END;
            END IF;
        ELSE
            IF pv_detail = 'COGSAMT'
            THEN
                BEGIN
                      SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                        INTO ln_cost
                        FROM apps.xla_ae_lines xal,
                             (SELECT application_id, event_id, ae_header_id,
                                     ae_line_num
                                FROM apps.xla_distribution_links xdl
                               WHERE     1 = 1
                                     AND xdl.source_distribution_type =
                                         'MTL_TRANSACTION_ACCOUNTS'
                                     AND EXISTS
                                             (SELECT 1
                                                FROM apps.mtl_transaction_accounts mta
                                               WHERE     mta.transaction_id =
                                                         TO_NUMBER (
                                                             pn_interface_line_attribute7) /*PERFORMANCE - TYPECASTING*/
                                                     AND mta.inv_sub_ledger_id =
                                                         xdl.source_distribution_id_num_1))
                             aa
                       WHERE     aa.application_id = xal.application_id
                             AND aa.ae_header_id = xal.ae_header_id
                             AND aa.ae_line_num = xal.ae_line_num
                             AND xal.accounting_class_code IN
                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                             AND xal.ledger_id = ln_sob_id
                    GROUP BY xal.code_combination_id;

                    RETURN ln_cost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                    WHEN OTHERS
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                END;
            ELSIF pv_detail = 'COGSCCID'
            THEN
                BEGIN
                      SELECT MAX (xal.code_combination_id)
                        INTO ln_cost
                        FROM apps.xla_ae_lines xal,
                             (SELECT application_id, event_id, ae_header_id,
                                     ae_line_num
                                FROM apps.xla_distribution_links xdl
                               WHERE     xdl.source_distribution_type =
                                         'MTL_TRANSACTION_ACCOUNTS'
                                     AND EXISTS
                                             (SELECT 1
                                                FROM apps.mtl_transaction_accounts mta
                                               WHERE     mta.transaction_id =
                                                         TO_NUMBER (
                                                             pn_interface_line_attribute7) /*PERFORMANCE - TYPECASTING*/
                                                     AND mta.inv_sub_ledger_id =
                                                         xdl.source_distribution_id_num_1))
                             aa
                       WHERE     aa.application_id = xal.application_id
                             AND aa.ae_header_id = xal.ae_header_id
                             AND aa.ae_line_num = xal.ae_line_num
                             AND xal.accounting_class_code IN
                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                             AND xal.ledger_id = ln_sob_id
                    GROUP BY xal.code_combination_id;

                    RETURN ln_cost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                    WHEN OTHERS
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                END;
            ELSIF pv_detail = 'MATAMT'
            THEN
                BEGIN
                      SELECT SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                        INTO ln_cost
                        FROM apps.xla_ae_lines xal,
                             (SELECT application_id, event_id, ae_header_id,
                                     ae_line_num
                                FROM apps.xla_distribution_links xdl
                               WHERE     xdl.source_distribution_type =
                                         'MTL_TRANSACTION_ACCOUNTS'
                                     AND EXISTS
                                             (SELECT 1
                                                FROM apps.mtl_transaction_accounts mta
                                               WHERE     mta.transaction_id =
                                                         TO_NUMBER (
                                                             pn_interface_line_attribute7) /*PERFORMANCE - TYPECASTING*/
                                                     AND mta.inv_sub_ledger_id =
                                                         xdl.source_distribution_id_num_1
                                                     AND mta.cost_element_id =
                                                         1)) aa
                       WHERE     aa.application_id = xal.application_id
                             AND aa.ae_header_id = xal.ae_header_id
                             AND aa.ae_line_num = xal.ae_line_num
                             AND xal.accounting_class_code IN
                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                             AND xal.ledger_id = ln_sob_id
                    GROUP BY xal.code_combination_id;

                    RETURN ln_cost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                    WHEN OTHERS
                    THEN
                        ln_cost   := 0;
                        RETURN ln_cost;
                END;
            END IF;
        END IF;
    END get_mmt_cost_sales;

    FUNCTION GET_PRICE_LIST_VALUE (ppricelistid       NUMBER,
                                   pinventoryitemid   NUMBER)
        RETURN NUMBER
    IS
    BEGIN
        RETURN apps.do_oe_utils.do_get_price_list_value (
                   p_price_list_id       => ppricelistid,
                   p_inventory_item_id   => pinventoryitemid);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_price_list_value;

    FUNCTION get_price (pn_so_line_id   VARCHAR2,
                        pn_org_id       NUMBER,
                        pv_col          VARCHAR2)
        RETURN NUMBER
    IS
        ln_unit_selling_price   NUMBER;
        ln_unit_list_price      NUMBER;
    BEGIN
        SELECT NVL (oola.unit_selling_price, 0), NVL (oola.unit_list_price, 0)
          INTO ln_unit_selling_price, ln_unit_list_price
          FROM apps.oe_order_lines_all oola
         WHERE oola.line_id = pn_so_line_id AND oola.org_id = pn_org_id;

        IF pv_col = 'SP'
        THEN
            RETURN ln_unit_selling_price;
        ELSIF pv_col = 'LP'
        THEN
            RETURN ln_unit_list_price;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END get_price;

    FUNCTION get_tax_details (p_trx_id        IN NUMBER,
                              p_trx_line_id   IN NUMBER,
                              p_mode          IN VARCHAR2)
        RETURN VARCHAR2
    AS
        CURSOR get_tax_amt_c IS
            SELECT SUM (tax_amt)
              FROM zx_lines
             WHERE     trx_id = p_trx_id
                   AND trx_line_id = p_trx_line_id
                   AND application_id = 222;

        CURSOR get_tax_rate_c IS
            SELECT SUM (tax_rate)
              FROM zx_lines
             WHERE     trx_id = p_trx_id
                   AND trx_line_id = p_trx_line_id
                   AND application_id = 222;

        CURSOR get_tax_rate_code_c IS
              SELECT tax_rate_code
                FROM zx_lines
               WHERE     trx_id = p_trx_id
                     AND trx_line_id = p_trx_line_id
                     AND application_id = 222
            ORDER BY tax_rate_code;

        ln_ret_value   VARCHAR2 (300);
    BEGIN
        ln_ret_value   := NULL;

        IF p_mode = 'TAX_RATE_CODE'
        THEN
            FOR lc_tax_rate_code IN get_tax_rate_code_c
            LOOP
                ln_ret_value   :=
                       ln_ret_value
                    || gc_delimeter
                    || lc_tax_rate_code.tax_rate_code;
            END LOOP;

            SELECT SUBSTR (ln_ret_value, 4) INTO ln_ret_value FROM DUAL;
        ELSIF p_mode = 'TAX_RATE'
        THEN
            OPEN get_tax_rate_c;

            FETCH get_tax_rate_c INTO ln_ret_value;

            CLOSE get_tax_rate_c;
        ELSIF p_mode = 'TAX_AMOUNT'
        THEN
            OPEN get_tax_amt_c;

            FETCH get_tax_amt_c INTO ln_ret_value;

            CLOSE get_tax_amt_c;

            ln_ret_value   := NVL (ln_ret_value, 0);
        END IF;

        RETURN ln_ret_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in get_tax_details' || SQLERRM);
            RETURN NULL;
    END get_tax_details;

    FUNCTION get_account (p_trx_id       IN NUMBER,
                          p_sob_id       IN NUMBER,
                          p_gl_dist_id   IN NUMBER)
        RETURN VARCHAR2
    AS
        lc_cc   VARCHAR2 (200);
    BEGIN
        SELECT glc.concatenated_segments
          INTO lc_cc
          FROM xla.xla_ae_lines xal, xla.xla_ae_headers xah, xla.xla_transaction_entities xte,
               xla_distribution_links xdl, gl_code_combinations_kfv glc
         WHERE     xal.ae_header_id = xah.ae_header_id
               AND xal.application_id = xah.application_id
               AND xte.entity_id = xah.entity_id
               AND xte.entity_code = 'TRANSACTIONS'
               AND xte.ledger_id = xal.ledger_id
               AND xte.application_id = xal.application_id
               AND xdl.ae_line_num = xal.ae_line_num
               AND xal.code_combination_id = glc.code_combination_id
               AND NVL (xte.source_id_int_1, -99) = p_trx_id
               AND xal.ae_header_id = xdl.ae_header_id
               AND xah.ae_header_id = xdl.ae_header_id
               AND xdl.source_distribution_id_num_1 = p_gl_dist_id
               AND xal.ledger_id = p_sob_id;

        RETURN lc_cc;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Exception in get_account' || SQLERRM);
            RETURN NULL;
    END get_account;

    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_from_date IN VARCHAR2:= NULL, p_to_date IN VARCHAR2:= NULL, pn_ou IN VARCHAR2, pn_price_list IN NUMBER
                    , pn_elimination_org IN NUMBER)
    IS
        CURSOR c_sel_invoices IS
              SELECT brand, operating_unit, invoice_num,
                     invoice_date, ar_type, sales_order,
                     order_type, customer_number, customer_name,
                     --address_name,           /*REMOVE COLUMNS*/
                     ship_to_address1, ship_to_address2, ship_to_city,
                     ship_to_state, ship_to_zipcode, ship_county,
                     ship_country_code, --ship_country,   /*REMOVE COLUMNS*/
                                        bill_city, bill_state,
                     bill_county, bill_postal_code, bill_country_code,
                     --bill_country,   /*REMOVE COLUMNS*/
                     deliver_to,                                /*ADD COLUMN*/
                                 product, sub_group,
                     sub_class, --style,   /*REMOVE COLUMNS*/
                                --sku,   /*REMOVE COLUMNS*/
                                item_type, --color,   /*REMOVE COLUMNS*/
                                           account_class,
                     SUM (usd_revenue_total) usd_revenue_total, SUM (NVL (invoiced_qty, 0)) invoiced_qty, --ROUND (SUM (Current_Landed_Cost), 2) Current_Landed_Cost,   /*REMOVE COLUMNS*/
                                                                                                          ROUND (SUM (transaction_Landed_Cost), 2) transaction_Landed_Cost,
                     /*ROUND (
                        NVL (
                             SUM (unit_selling_price * invoiced_qty)
                           / (DECODE (SUM (invoiced_qty),
                                      0, 1,
                                      SUM (invoiced_qty))),
                           0),
                        2)
                        unit_selling_price,*/
                     /*REMOVE COLUMNS*/
                     ROUND (NVL (SUM (unit_list_price * invoiced_qty) / (DECODE (SUM (invoiced_qty), 0, 1, SUM (invoiced_qty))), 0), 2) unit_list_price, /*ROUND (
                                                                                                                                                            NVL (
                                                                                                                                                                 SUM (unit_list_price * invoiced_qty)
                                                                                                                                                               / (DECODE (SUM (invoiced_qty),
                                                                                                                                                                          0, 1,
                                                                                                                                                                          SUM (invoiced_qty))),
                                                                                                                                                               0),
                                                                                                                                                            2)
                                                                                                                                                       - ROUND (
                                                                                                                                                            NVL (
                                                                                                                                                                 SUM (unit_selling_price * invoiced_qty)
                                                                                                                                                               / (DECODE (SUM (invoiced_qty),
                                                                                                                                                                          0, 1,
                                                                                                                                                                          SUM (invoiced_qty))),
                                                                                                                                                               0),
                                                                                                                                                            2)
                                                                                                                                                          discount,*/
                                                                                                                                                         /*REMOVE COLUMNS*/
                                                                                                                                                         ROUND (NVL (SUM (unit_list_price * invoiced_qty), 0), 2) - ROUND (NVL (SUM (unit_selling_price * invoiced_qty), 0), 2) extra_discount, --tax_rate_code,   /*REMOVE COLUMNS*/
                                                                                                                                                                                                                                                                                                tax_rate,
                     SUM (TAX_RATE_AMOUNT) entered_tax_amt, SUM (Entered_Total_Amt) Entered_Total_Amt, SUM (freight_amt) freight_amt,
                     SUM (freight_tax) freight_tax, SUM (Functional_Total_amt) Functional_Total_amt, /*ROUND (
                                                                                                        NVL (
                                                                                                             SUM (wholesale_price * invoiced_qty)
                                                                                                           / (DECODE (SUM (invoiced_qty),
                                                                                                                      0, 1,
                                                                                                                      SUM (invoiced_qty))),
                                                                                                           0),
                                                                                                        2)
                                                                                                        wholesale_price,*/
                                                                                                     /*REMOVE COLUMNS*/
                                                                                                     Revenue_Account,
                     cogs_account, --purchase_order,   /*REMOVE COLUMNS*/
                                   --ROUND (SUM (NVL (material_cost, 0)), 2) material_cost,   /*REMOVE COLUMNS*/
                                   ROUND (SUM (NVL (macau_cost, 0)), 2) macau_cost -- ,
                /*(CASE
                    WHEN (  SUM (NVL (material_cost, 0))
                          - SUM (NVL (macau_cost, 0))) < 0
                    THEN
                       ROUND (SUM (NVL (Transaction_landed_cost, 0)), 2)
                    ELSE
                       (  ROUND (SUM (NVL (Transaction_landed_cost, 0)), 2)
                        - SUM (NVL (material_cost, 0))
                        + SUM (NVL (macau_cost, 0)))
                 END)
                   consolidated_cost */
                /*REMOVE COLUMNS*/
                FROM xxdo_ar_sales_det_t
            GROUP BY brand, operating_unit, invoice_num,
                     invoice_date, ar_type, sales_order,
                     order_type, customer_number, customer_name,
                     --address_name,   /*REMOVE COLUMNS*/
                     ship_to_address1, ship_to_address2, ship_to_city,
                     ship_to_state, ship_to_zipcode, ship_county,
                     ship_country_code, --ship_country,   /*REMOVE COLUMNS*/
                                        bill_city, bill_state,
                     bill_county, bill_postal_code, bill_country_code,
                     --bill_country,   /*REMOVE COLUMNS*/
                     deliver_to,                                /*ADD COLUMN*/
                                 product, sub_group,
                     sub_class, --style,   /*REMOVE COLUMNS*/
                                --sku,   /*REMOVE COLUMNS*/
                                item_type, --color,    /*REMOVE COLUMNS*/
                                           account_class,
                     --tax_rate_code,   /*REMOVE COLUMNS*/
                     tax_rate, Revenue_Account, cogs_account               --,
            --purchase_order   /*REMOVE COLUMNS*/
            ORDER BY operating_unit, invoice_date, invoice_num;

        --style;   /*REMOVE COLUMNS*/
        --color;   /*REMOVE COLUMNS*/

        CURSOR c_invoices (cp_from_date          IN DATE,
                           cp_to_date            IN DATE,
                           cpn_ou                IN VARCHAR2,
                           cpn_price_list        IN NUMBER,
                           cpn_elimination_org   IN NUMBER)
        IS
            SELECT hou.name operating_unit,
                   hzp.party_name customer_name,
                   hca.account_number Customer_number,
                   rcta.trx_number Invoice_num,
                   rcta.trx_date invoice_date,
                   rtt.NAME ar_type,
                   rcta.interface_header_attribute1 sales_order,
                   rcta.interface_header_attribute2 order_type,
                   --ship_to.location address_name,   /*REMOVE COLUMNS*/
                   ship_to.address1 Ship_to_Address1,
                   ship_to.address2 Ship_to_Address2,
                   ship_to.city Ship_to_city,
                   ship_to.state ship_to_state,
                   ship_to.postal_code Ship_to_zipcode,
                   ship_to.county ship_county,
                   ship_to.country ship_country_code,
                   --ship_to.territory_short_name ship_country,   /*REMOVE COLUMNS*/
                   bill_to.city bill_city,
                   bill_to.state bill_state,
                   bill_to.county bill_county,
                   bill_to.postal_code bill_postal_code,
                   bill_to.country bill_country_code,
                   (SELECT site_uses.location
                      FROM apps.hz_party_sites party_site, apps.hz_locations loc, apps.hz_cust_acct_sites_all acct_site,
                           apps.hz_cust_site_uses_all site_uses, apps.fnd_territories_vl ftl, apps.oe_order_lines_all l
                     WHERE     acct_site.party_site_id =
                               party_site.party_site_id
                           AND loc.location_id = party_site.location_id
                           AND acct_site.cust_acct_site_id =
                               site_uses.cust_acct_site_id
                           AND site_uses.site_use_code = 'DELIVER_TO'
                           AND acct_site.org_id = site_uses.org_id
                           AND loc.country = ftl.territory_code
                           AND l.deliver_to_org_id = site_uses.site_use_id
                           AND rctla.interface_line_attribute6 = l.line_id
                           AND REGEXP_LIKE (rctla.interface_line_attribute6,
                                            '^[0-9]+$')) deliver_to, /*ADD COLUMN*/
                   --bill_to.territory_short_name bill_country,   /*REMOVE COLUMNS*/
                   --NVL2 (msi.department, msi.style_number, 'NA') product, /*COL DERV CHANGE*/
                   msi.department product,
                   NVL (msi.master_class, 'NA') sub_group,
                   NVL (msi.sub_class, 'NA') sub_class,
                   --NVL2 (msi.style_number, rctla.description, 'NA') style, /*COL DERV CHANGE*/
                   --msi.style_number  style,     /*REMOVE COLUMNS*/
                   NVL (msi.item_type, 'NA') item_type,
                   --NVL (msi.color_code, 'NA') color,   /*REMOVE COLUMNS*/
                   gl_dist.account_class,
                   ROUND (
                         NVL (rctla.extended_amount, 0)
                       * (SELECT glr.conversion_rate
                            FROM apps.gl_daily_rates glr
                           WHERE     glr.conversion_type = 'Corporate'
                                 AND glr.from_currency =
                                     rcta.invoice_currency_code
                                 AND glr.to_currency = 'USD'
                                 AND glr.conversion_date =
                                     TRUNC (rcta.trx_date)),
                       2) usd_revenue_total,
                   NVL (
                       DECODE (
                           rctla.line_type,
                           'LINE', DECODE (
                                       NVL (rctla.interface_line_attribute11,
                                            0),
                                       0, NVL (
                                              rctla.quantity_invoiced,
                                              NVL (rctla.quantity_credited,
                                                   0)))),
                       0) AS invoiced_qty,
                   /*NVL (
                        (SELECT MAX (cic.item_cost)
                           FROM apps.cst_item_costs cic, apps.mtl_parameters mp
                          WHERE     cic.organization_id = mp.organization_id
                                AND cic.cost_type_id = mp.primary_cost_method
                                AND cic.inventory_item_id =
                                       rctla.inventory_item_id
                                AND cic.organization_id = rctla.warehouse_id)
                      * DECODE (
                           rctla.line_type,
                           'LINE', DECODE (
                                      NVL (rctla.interface_line_attribute11, 0),
                                      0, NVL (quantity_invoiced,
                                              NVL (rctla.quantity_credited, 0)))),
                      0)
                      Current_Landed_Cost, */
                   /*REMOVE COLUMNS*/
                   rbs.NAME batch_source,
                   rcta.bill_to_customer_id,
                   rcta.ship_to_site_use_id,
                   rcta.org_id,
                   rcta.bill_to_site_use_id,
                   rcta.customer_trx_id,
                   rcta.exchange_rate,
                   NVL (rctla.extended_amount, 0) extended_amount,
                   rctla.line_type,
                   rctla.interface_line_attribute6,
                   rctla.interface_line_attribute7,
                   rctla.interface_line_attribute11,
                   rctla.warehouse_id organization_id,
                   rcta.set_of_books_id,
                   --rcta.purchase_order,   /*REMOVE COLUMNS*/
                   /*NVL (
                      apps.do_oe_utils.do_get_price_list_value (
                         cpn_price_list,
                         rctla.inventory_item_id),
                      0)
                      wholesale_price,*/
                   /*REMOVE COLUMNS*/
                   --NVL (msi.item_number, 'NA') sku,    /*REMOVE COLUMNS*/
                   msi.brand,
                   rctla.customer_trx_line_id,
                   gl_dist.cust_trx_line_gl_dist_id,
                   gl_dist.code_combination_id,
                   gl_dist.amount,
                   DECODE (rctla.line_type,
                           'FREIGHT', rctla.extended_amount,
                           0) Freight_amt,
                   (CASE
                        WHEN rctla.line_type = 'FREIGHT'
                        THEN
                            NVL (
                                (SELECT SUM (attribute5)
                                   FROM apps.oe_price_adjustments_v
                                  WHERE header_id =
                                        (SELECT header_id
                                           FROM apps.oe_order_headers_all
                                          WHERE order_number =
                                                TO_NUMBER (
                                                    rctla.interface_line_attribute1))),
                                0)
                        ELSE
                            0
                    END) Freight_tax,
                   NVL (
                         (SELECT MAX (cic.item_cost)
                            FROM apps.cst_item_costs cic, apps.mtl_parameters mp
                           WHERE     cic.organization_id = mp.organization_id
                                 AND cic.cost_type_id =
                                     mp.primary_cost_method
                                 AND cic.inventory_item_id =
                                     rctla.inventory_item_id
                                 AND cic.organization_id = rctla.warehouse_id
                                 AND cic.organization_id = pn_elimination_org)
                       * DECODE (
                             rctla.line_type,
                             'LINE', DECODE (
                                         NVL (
                                             rctla.interface_line_attribute11,
                                             0),
                                         0, NVL (
                                                quantity_invoiced,
                                                NVL (rctla.quantity_credited,
                                                     0)))),
                       0) macau_cost,
                   /*PERFORMANCE - Added columns -BEGIN*/
                   NULL COGS_ACCOUNT,
                   NULL ENTERED_TOTAL_AMT,
                   NULL FUNCTIONAL_TOTAL_AMT,
                   --NULL MATERIAL_COST,   /*REMOVE COLUMNS*/
                   --NULL PURCHASE_ORD,   /*REMOVE COLUMNS*/
                   NULL REVENUE_ACCOUNT,
                   NULL TRANSACTION_LANDED_COST,
                   NULL TAX_RATE,
                   --NULL TAX_RATE_CODE,   /*REMOVE COLUMNS*/
                   NULL TAX_RATE_AMOUNT,
                   NULL USD_REVENUE_TOT,
                   NULL UNIT_LIST_PRICE                                    --,
              --NULL UNIT_SELLING_PRICE     /*REMOVE COLUMNS*/
              /*PERFORMANCE - Added columns -END*/
              FROM apps.ra_batch_sources_all rbs,
                   apps.ra_customer_trx_all rcta,
                   apps.ra_customer_trx_lines_all rctla,
                   apps.ra_cust_trx_line_gl_dist_all gl_dist,
                   apps.ra_cust_trx_types_all rtt,
                   apps.hr_operating_units hou,
                   apps.xxd_common_items_v msi,
                   apps.hz_parties hzp,
                   apps.hz_cust_accounts hca,
                   (SELECT site_uses.location, loc.address_key, loc.address1,
                           loc.address2, loc.city, loc.state,
                           loc.postal_code, loc.county, loc.country,
                           ftl.territory_short_name, acct_site.cust_account_id, acct_site.org_id,
                           site_uses.site_use_id
                      FROM apps.hz_party_sites party_site, apps.hz_locations loc, apps.hz_cust_acct_sites_all acct_site,
                           apps.hz_cust_site_uses_all site_uses, apps.fnd_territories_vl ftl
                     WHERE     acct_site.party_site_id =
                               party_site.party_site_id
                           AND loc.location_id = party_site.location_id
                           AND acct_site.cust_acct_site_id =
                               site_uses.cust_acct_site_id
                           AND site_uses.site_use_code = 'SHIP_TO'
                           AND acct_site.org_id = site_uses.org_id
                           AND loc.country = ftl.territory_code
                           AND loc.country = 'US') ship_to,
                   (SELECT loc.city, loc.state, loc.postal_code,
                           loc.county, loc.country, ftl.territory_short_name,
                           acct_site.cust_account_id, acct_site.org_id, site_uses.site_use_id
                      FROM apps.hz_party_sites party_site, apps.hz_locations loc, apps.hz_cust_acct_sites_all acct_site,
                           apps.hz_cust_site_uses_all site_uses, apps.fnd_territories_vl ftl
                     WHERE     acct_site.party_site_id =
                               party_site.party_site_id
                           AND loc.location_id = party_site.location_id
                           AND acct_site.cust_acct_site_id =
                               site_uses.cust_acct_site_id
                           AND site_uses.site_use_code = 'BILL_TO'
                           AND acct_site.org_id = site_uses.org_id
                           AND loc.country = ftl.territory_code) bill_to
             /*(SELECT site_uses.location
                FROM apps.hz_party_sites party_site,
                     apps.hz_locations loc,
                     apps.hz_cust_acct_sites_all acct_site,
                     apps.hz_cust_site_uses_all site_uses,
                     apps.fnd_territories_vl ftl
               WHERE     acct_site.party_site_id =
                            party_site.party_site_id
                     AND loc.location_id = party_site.location_id
                     AND acct_site.cust_acct_site_id =
                            site_uses.cust_acct_site_id
                     AND site_uses.site_use_code = 'DELIVER_TO'
                     AND acct_site.org_id = site_uses.org_id
                     AND loc.country = ftl.territory_code)  deliver_to*/
             WHERE     1 = 1
                   AND rcta.org_id = hou.organization_id
                   AND gl_dist.account_class IN ('REV', 'FREIGHT')
                   AND gl_dist.customer_trx_line_id =
                       rctla.customer_trx_line_id
                   AND gl_dist.account_set_flag = 'N'
                   AND gl_dist.org_id = rctla.org_id
                   AND rctla.customer_trx_id = rcta.customer_trx_id
                   AND rctla.line_type IN ('LINE', 'FREIGHT', 'CHARGES')
                   AND rctla.org_id = rcta.org_id
                   AND rctla.set_of_books_id = rcta.set_of_books_id
                   AND rbs.batch_source_id = rcta.batch_source_id
                   AND rbs.org_id = rcta.org_id
                   AND hca.cust_account_id = rcta.bill_to_customer_id
                   AND hca.party_id = hzp.party_id
                   AND rtt.cust_trx_type_id = rcta.cust_trx_type_id
                   AND rtt.org_id = rcta.org_id
                   AND rcta.complete_flag = 'Y'
                   AND rcta.trx_date BETWEEN cp_from_date AND cp_to_date
                   AND rtt.org_id = cpn_ou
                   AND rctla.inventory_item_id = msi.inventory_item_id(+)
                   AND msi.organization_id(+) = 106
                   AND ship_to.site_use_id(+) = rcta.ship_to_site_use_id
                   AND ship_to.org_id(+) = rcta.org_id
                   AND bill_to.site_use_id = rcta.bill_to_site_use_id
                   AND bill_to.org_id = rcta.org_id;

        TYPE c_invoices_tabtype IS TABLE OF c_invoices%ROWTYPE
            INDEX BY PLS_INTEGER;

        invoices_tbl            c_invoices_tabtype;

        l_start_date            DATE;
        l_end_date              DATE;
        ld_date                 DATE;
        ln_sob_id               NUMBER;
        ln_cogs_cost            NUMBER;
        ln_cogs_acct_id         NUMBER;
        ln_cogs_segment         VARCHAR2 (100);
        ln_mat_amt              NUMBER;
        lc_cc                   VARCHAR2 (100);
        ln_unit_selling_price   NUMBER;
        ln_unit_list_price      NUMBER;
        lv_tax_rate_code        VARCHAR2 (240);
        lv_tax_rate             VARCHAR2 (240);
        lv_tax_amount           VARCHAR2 (240);
        l_count                 NUMBER := 0;  /*PERFORMANCE - Added variable*/
    BEGIN
        EXECUTE IMMEDIATE 'truncate table XXDO_AR_SALES_DET_T';

        l_start_date   := fnd_conc_date.string_to_date (p_from_date);
        l_end_date     := fnd_conc_date.string_to_date (p_to_date);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'From Date :' || l_start_date);
        apps.fnd_file.put_line (apps.fnd_file.LOG, 'To Date :' || l_end_date);
        ld_date        := fnd_conc_date.string_to_date (p_from_date);

        WHILE fnd_conc_date.string_to_date (p_to_date) >= ld_date
        LOOP
            IF fnd_conc_date.string_to_date (p_to_date) >= ld_date + 5
            THEN
                l_start_date   := ld_date;
                l_end_date     := ld_date + 5;
            ELSE
                l_start_date   := ld_date;
                l_end_date     := fnd_conc_date.string_to_date (p_to_date);
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Before Cursor : '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')); /*PERFORMANCE - Added log*/

            OPEN c_invoices (cp_from_date          => l_start_date,
                             cp_to_date            => l_end_date,
                             cpn_ou                => pn_ou,
                             cpn_price_list        => pn_price_list,
                             cpn_elimination_org   => pn_elimination_org);

            LOOP
                ln_sob_id               := 0;
                ln_cogs_cost            := 0;
                ln_cogs_acct_id         := 0;
                ln_mat_amt              := 0;
                lc_cc                   := NULL;
                ln_unit_selling_price   := 0;
                ln_unit_list_price      := 0;
                lv_tax_rate_code        := NULL;
                lv_tax_rate             := NULL;
                lv_tax_amount           := NULL;
                ln_cogs_segment         := NULL;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before Fetch : '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')); /*PERFORMANCE - Added log*/

                FETCH c_invoices BULK COLLECT INTO invoices_tbl;

                -- LIMIT 2000000;            /*PERFORMANCE - Removed Limit*/

                fnd_file.put_line (
                    fnd_file.LOG,
                       'After Fetch : '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')); /*PERFORMANCE - Added log*/

                fnd_file.put_line (
                    fnd_file.LOG,
                    'invoices_tbl.COUNT : ' || invoices_tbl.COUNT); /*PERFORMANCE - Added log*/

                IF invoices_tbl.COUNT > 0
                THEN
                    FOR i IN invoices_tbl.FIRST .. invoices_tbl.LAST
                    LOOP
                        BEGIN
                            IF invoices_tbl (i).organization_id IS NOT NULL
                            THEN
                                BEGIN
                                    SELECT set_of_books_id
                                      INTO ln_sob_id
                                      FROM org_organization_definitions
                                     WHERE organization_id =
                                           invoices_tbl (i).organization_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_sob_id   :=
                                            invoices_tbl (i).set_of_books_id;
                                END;
                            ELSE
                                ln_sob_id   :=
                                    invoices_tbl (i).set_of_books_id;
                            END IF;

                            /*SELECT NVL (
                                      get_tax_details (
                                         invoices_tbl (i).customer_trx_id,
                                         invoices_tbl (i).customer_trx_line_id,
                                         'TAX_RATE_CODE'),
                                      0)
                              INTO lv_tax_rate_code
                              FROM DUAL;*/
                            /*REMOVE COLUMNS*/

                            SELECT NVL (get_tax_details (invoices_tbl (i).customer_trx_id, invoices_tbl (i).customer_trx_line_id, 'TAX_RATE'), 0)
                              INTO lv_tax_rate
                              FROM DUAL;

                            SELECT NVL (get_tax_details (invoices_tbl (i).customer_trx_id, invoices_tbl (i).customer_trx_line_id, 'TAX_AMOUNT'), 0)
                              INTO lv_tax_amount
                              FROM DUAL;

                            BEGIN
                                SELECT NVL (oola.unit_selling_price, 0), NVL (oola.unit_list_price, 0)
                                  INTO ln_unit_selling_price, ln_unit_list_price
                                  FROM apps.oe_order_lines_all oola
                                 WHERE     oola.line_id =
                                           TO_NUMBER (
                                               invoices_tbl (i).interface_line_attribute6) -- /*PERFORMANCE - TYPECASTING*/
                                       AND oola.org_id =
                                           invoices_tbl (i).org_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ln_unit_selling_price   := 0;
                                    ln_unit_list_price      := 0;
                            END;

                            BEGIN
                                SELECT glc.concatenated_segments
                                  INTO lc_cc
                                  FROM xla.xla_ae_lines xal, xla.xla_ae_headers xah, xla.xla_transaction_entities xte,
                                       xla_distribution_links xdl, gl_code_combinations_kfv glc
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
                                           invoices_tbl (i).customer_trx_id
                                       AND xal.ae_header_id =
                                           xdl.ae_header_id
                                       AND xah.ae_header_id =
                                           xdl.ae_header_id
                                       AND xdl.source_distribution_id_num_1 =
                                           invoices_tbl (i).cust_trx_line_gl_dist_id
                                       AND xal.ledger_id =
                                           invoices_tbl (i).set_of_books_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    SELECT glc.concatenated_segments
                                      INTO lc_cc
                                      FROM gl_code_combinations_kfv glc
                                     WHERE glc.code_combination_id =
                                           invoices_tbl (i).code_combination_id;
                            END;


                            IF invoices_tbl (i).interface_line_attribute7 =
                               '0'
                            THEN
                                BEGIN
                                      SELECT NVL (SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0)), 0), NVL (MAX (xal.code_combination_id), 0)
                                        INTO ln_cogs_cost, ln_cogs_acct_id
                                        FROM apps.xla_ae_lines xal,
                                             (SELECT application_id, event_id, ae_header_id,
                                                     ae_line_num
                                                FROM apps.xla_distribution_links xdl
                                               WHERE     xdl.source_distribution_type =
                                                         'MTL_TRANSACTION_ACCOUNTS'
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM apps.mtl_transaction_accounts mta, apps.mtl_material_transactions mmto
                                                               WHERE     mta.inv_sub_ledger_id =
                                                                         xdl.source_distribution_id_num_1
                                                                     AND mta.transaction_id =
                                                                         mmto.transaction_id
                                                                     AND mmto.trx_source_line_id =
                                                                         TO_NUMBER (
                                                                             invoices_tbl (
                                                                                 i).interface_line_attribute6)))
                                             aa  /*PERFORMANCE - TYPECASTING*/
                                       WHERE     aa.application_id =
                                                 xal.application_id
                                             AND aa.ae_header_id =
                                                 xal.ae_header_id
                                             AND aa.ae_line_num =
                                                 xal.ae_line_num
                                             AND xal.accounting_class_code IN
                                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                                             AND xal.ledger_id = ln_sob_id
                                    GROUP BY xal.code_combination_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_cogs_cost      := 0;
                                        ln_cogs_acct_id   := 0;
                                END;

                                IF     ln_cogs_acct_id IS NOT NULL
                                   AND ln_cogs_acct_id <> 0
                                THEN
                                    BEGIN
                                        SELECT concatenated_segments
                                          INTO ln_cogs_segment
                                          FROM gl_code_combinations_kfv
                                         WHERE code_combination_id =
                                               ln_cogs_acct_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_cogs_segment   := 'NA';
                                    END;
                                END IF;

                                BEGIN
                                      SELECT NVL (SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0)), 0)
                                        INTO ln_mat_amt
                                        FROM apps.xla_ae_lines xal,
                                             (SELECT application_id, event_id, ae_header_id,
                                                     ae_line_num
                                                FROM apps.xla_distribution_links xdl
                                               WHERE     xdl.source_distribution_type =
                                                         'MTL_TRANSACTION_ACCOUNTS'
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM apps.mtl_transaction_accounts mta, apps.mtl_material_transactions mmto
                                                               WHERE     mta.inv_sub_ledger_id =
                                                                         xdl.source_distribution_id_num_1
                                                                     AND mta.transaction_id =
                                                                         mmto.transaction_id
                                                                     AND mta.cost_element_id =
                                                                         1
                                                                     AND mmto.trx_source_line_id =
                                                                         TO_NUMBER (
                                                                             invoices_tbl (
                                                                                 i).interface_line_attribute6)))
                                             aa  /*PERFORMANCE - TYPECASTING*/
                                       WHERE     aa.application_id =
                                                 xal.application_id
                                             AND aa.ae_header_id =
                                                 xal.ae_header_id
                                             AND aa.ae_line_num =
                                                 xal.ae_line_num
                                             AND xal.accounting_class_code IN
                                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                                             AND xal.ledger_id = ln_sob_id
                                    GROUP BY xal.code_combination_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_mat_amt   := 0;
                                END;
                            ELSE
                                BEGIN
                                      SELECT NVL (SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0)), 0), NVL (MAX (xal.code_combination_id), 0)
                                        INTO ln_cogs_cost, ln_cogs_acct_id
                                        FROM apps.xla_ae_lines xal,
                                             (SELECT application_id, event_id, ae_header_id,
                                                     ae_line_num
                                                FROM apps.xla_distribution_links xdl
                                               WHERE     1 = 1
                                                     AND xdl.source_distribution_type =
                                                         'MTL_TRANSACTION_ACCOUNTS'
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM apps.mtl_transaction_accounts mta
                                                               WHERE     mta.transaction_id =
                                                                         TO_NUMBER (
                                                                             invoices_tbl (
                                                                                 i).interface_line_attribute7) /*PERFORMANCE - TYPECASTING*/
                                                                     AND mta.inv_sub_ledger_id =
                                                                         xdl.source_distribution_id_num_1))
                                             aa
                                       WHERE     aa.application_id =
                                                 xal.application_id
                                             AND aa.ae_header_id =
                                                 xal.ae_header_id
                                             AND aa.ae_line_num =
                                                 xal.ae_line_num
                                             AND xal.accounting_class_code IN
                                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                                             AND xal.ledger_id = ln_sob_id
                                    GROUP BY xal.code_combination_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_cogs_cost      := 0;
                                        ln_cogs_acct_id   := 0;
                                END;

                                IF     ln_cogs_acct_id IS NOT NULL
                                   AND ln_cogs_acct_id <> 0
                                THEN
                                    BEGIN
                                        SELECT concatenated_segments
                                          INTO ln_cogs_segment
                                          FROM gl_code_combinations_kfv
                                         WHERE code_combination_id =
                                               ln_cogs_acct_id;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_cogs_segment   := 'NA';
                                    END;
                                END IF;

                                BEGIN
                                      SELECT NVL (SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0)), 0)
                                        INTO ln_mat_amt
                                        FROM apps.xla_ae_lines xal,
                                             (SELECT application_id, event_id, ae_header_id,
                                                     ae_line_num
                                                FROM apps.xla_distribution_links xdl
                                               WHERE     xdl.source_distribution_type =
                                                         'MTL_TRANSACTION_ACCOUNTS'
                                                     AND EXISTS
                                                             (SELECT 1
                                                                FROM apps.mtl_transaction_accounts mta, apps.mtl_material_transactions mmto
                                                               WHERE     mta.inv_sub_ledger_id =
                                                                         xdl.source_distribution_id_num_1
                                                                     AND mta.transaction_id =
                                                                         mmto.transaction_id
                                                                     AND mta.cost_element_id =
                                                                         1
                                                                     AND mmto.trx_source_line_id =
                                                                         TO_NUMBER (
                                                                             invoices_tbl (
                                                                                 i).interface_line_attribute7)))
                                             aa  /*PERFORMANCE - TYPECASTING*/
                                       WHERE     aa.application_id =
                                                 xal.application_id
                                             AND aa.ae_header_id =
                                                 xal.ae_header_id
                                             AND aa.ae_line_num =
                                                 xal.ae_line_num
                                             AND xal.accounting_class_code IN
                                                     ('OFFSET', 'COST_OF_GOODS_SOLD')
                                             AND xal.ledger_id = ln_sob_id
                                    GROUP BY xal.code_combination_id;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        ln_mat_amt   := 0;
                                END;
                            END IF; -- Moved the End IF from end of c_invoices cursor

                            /*PERFORMANCE - Column Derivation into table type -BEGIN*/
                            BEGIN
                                SELECT DECODE (invoices_tbl (i).line_type, 'LINE', DECODE (NVL (invoices_tbl (i).interface_line_attribute11, 0), 0, NVL (ln_cogs_segment, 'NA'), 0), 0)
                                  INTO invoices_tbl (i).COGS_ACCOUNT
                                  FROM DUAL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    apps.fnd_file.put_line (
                                        apps.fnd_file.LOG,
                                           'Unexpected Error COGS_ACCOUNT : '
                                        || SQLCODE
                                        || '-'
                                        || SQLERRM);
                            END;

                            invoices_tbl (i).ENTERED_TOTAL_AMT   :=
                                  NVL (invoices_tbl (i).amount, 0)
                                + lv_tax_amount;
                            invoices_tbl (i).FUNCTIONAL_TOTAL_AMT   :=
                                  NVL (invoices_tbl (i).amount, 0)
                                +   lv_tax_amount
                                  * NVL (invoices_tbl (i).exchange_rate, 1);
                            /*BEGIN
                            SELECT (  ln_mat_amt
                                    * DECODE (
                                         invoices_tbl (i).line_type,
                                         'LINE', DECODE (
                                                    NVL (
                                                       invoices_tbl (i).interface_line_attribute11,
                                                       0),
                                                    0, 1,
                                                    0),
                                         0))
                              INTO invoices_tbl (i).MATERIAL_COST
                              FROM DUAL;
                              EXCEPTION
                         WHEN OTHERS
                         THEN
                            apps.fnd_file.put_line (
                               apps.fnd_file.LOG,
                                  'Unexpected Error MATERIAL_COST : '
                               || SQLCODE
                               || '-'
                               || SQLERRM);
                      END; */
                            /*REMOVE COLUMNS*/

                            /*invoices_tbl (i).PURCHASE_ORD :=
                               REPLACE (invoices_tbl (i).PURCHASE_ORDER, '"', '');*/
                            /*REMOVE COLUMNS*/
                            invoices_tbl (i).REVENUE_ACCOUNT   := lc_cc;

                            BEGIN
                                SELECT (ln_cogs_cost * DECODE (invoices_tbl (i).line_type, 'LINE', DECODE (NVL (invoices_tbl (i).interface_line_attribute11, 0), 0, 1, 0), 0))
                                  INTO invoices_tbl (i).TRANSACTION_LANDED_COST
                                  FROM DUAL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    apps.fnd_file.put_line (
                                        apps.fnd_file.LOG,
                                           'Unexpected Error TRANSACTION_LANDED_COST : '
                                        || SQLCODE
                                        || '-'
                                        || SQLERRM);
                            END;

                            invoices_tbl (i).TAX_RATE          := LV_TAX_RATE;
                            --invoices_tbl (i).TAX_RATE_CODE := lv_TAX_RATE_CODE;   /*REMOVE COLUMNS*/
                            invoices_tbl (i).TAX_RATE_AMOUNT   :=
                                lv_TAX_AMOUNT;
                            invoices_tbl (i).USD_REVENUE_TOT   :=
                                  NVL (invoices_tbl (i).amount, 0)
                                * NVL (invoices_tbl (i).exchange_rate, 1);
                            invoices_tbl (i).UNIT_LIST_PRICE   :=
                                LN_UNIT_LIST_PRICE;
                        --invoices_tbl (i).UNIT_SELLING_PRICE :=
                        -- LN_UNIT_SELLING_PRICE;   /*REMOVE COLUMNS*/

                        /*PERFORMANCE - Column Derivation into table type - END*/
                        -- END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                apps.fnd_file.put_line (
                                    apps.fnd_file.LOG,
                                       'Unexpected Error Encountered : '
                                    || SQLCODE
                                    || '-'
                                    || SQLERRM);
                        END;
                    END LOOP;
                END IF;

                EXIT WHEN c_invoices%NOTFOUND;
            END LOOP;

            CLOSE c_invoices;

            fnd_file.put_line (
                fnd_file.LOG,
                   'After Cursor : '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')); /*PERFORMANCE - Added log*/


            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Start-Date ' || l_start_date || ' End-Date ' || l_end_date);
            ld_date   := ld_date + 6;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Before Bulk Insert : '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')); /*PERFORMANCE - Added log*/


            BEGIN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'invoices_tbl.COUNT : ' || invoices_tbl.COUNT); /*PERFORMANCE - Added log*/

                /*PERFORMANCE -BULK Insert Login -BEGIN*/

                FORALL i IN invoices_tbl.FIRST .. invoices_tbl.LAST
                    INSERT INTO xxdo_ar_sales_det_t (
                                    ACCOUNT_CLASS,
                                    --ADDRESS_NAME,   /*REMOVE COLUMNS*/
                                    AR_TYPE,
                                    BATCH_SOURCE,
                                    BILL_CITY,
                                    --BILL_COUNTRY,   /*REMOVE COLUMNS*/
                                    BILL_COUNTRY_CODE,
                                    BILL_COUNTY,
                                    BILL_POSTAL_CODE,
                                    BILL_STATE,
                                    BILL_TO_CUSTOMER_ID,
                                    BILL_TO_SITE_USE_ID,
                                    DELIVER_TO,                 /*ADD COLUMN*/
                                    BRAND,
                                    --COLOR,      /*REMOVE COLUMNS*/
                                    CUSTOMER_NAME,
                                    CUSTOMER_NUMBER,
                                    --CURRENT_LANDED_COST,   /*REMOVE COLUMNS*/
                                    CUSTOMER_TRX_ID,
                                    CUSTOMER_TRX_LINE_ID,
                                    CUST_TRX_LINE_GL_DIST_ID,
                                    COGS_ACCOUNT,
                                    CODE_COMBINATION_ID,
                                    EXTENDED_AMOUNT,
                                    ENTERED_TOTAL_AMT,
                                    FREIGHT_AMT,
                                    FREIGHT_TAX,
                                    FUNCTIONAL_TOTAL_AMT,
                                    INTERFACE_LINE_ATTRIBUTE6,
                                    INTERFACE_LINE_ATTRIBUTE7,
                                    INTERFACE_LINE_ATTRIBUTE11,
                                    INVOICED_QTY,
                                    INVOICE_DATE,
                                    INVOICE_NUM,
                                    ITEM_TYPE,
                                    LINE_TYPE,
                                    MACAU_COST,
                                    --MATERIAL_COST,   /*REMOVE COLUMNS*/
                                    OPERATING_UNIT,
                                    ORDER_TYPE,
                                    ORG_ID,
                                    PRODUCT,
                                    --PURCHASE_ORDER,   /*REMOVE COLUMNS*/
                                    REVENUE_ACCOUNT,
                                    SALES_ORDER,
                                    SET_OF_BOOKS_ID,
                                    --SHIP_COUNTRY,   /*REMOVE COLUMNS*/
                                    SHIP_COUNTRY_CODE,
                                    SHIP_COUNTY,
                                    SHIP_TO_ADDRESS1,
                                    SHIP_TO_ADDRESS2,
                                    SHIP_TO_CITY,
                                    SHIP_TO_SITE_USE_ID,
                                    SHIP_TO_STATE,
                                    SHIP_TO_ZIPCODE,
                                    --SKU,    /*REMOVE COLUMNS*/
                                    --STYLE,   /*REMOVE COLUMNS*/
                                    SUB_CLASS,
                                    SUB_GROUP,
                                    TRANSACTION_LANDED_COST,
                                    TAX_RATE,
                                    --TAX_RATE_CODE,   /*REMOVE COLUMNS*/
                                    TAX_RATE_AMOUNT,
                                    USD_REVENUE_TOTAL,
                                    UNIT_LIST_PRICE,
                                    --UNIT_SELLING_PRICE,   /*REMOVE COLUMNS*/
                                    WAREHOUSE_ID)
                             --WHOLESALE_PRICE)   /*REMOVE COLUMNS*/
                             VALUES (
                                        invoices_tbl (i).ACCOUNT_CLASS,
                                        --invoices_tbl (i).ADDRESS_NAME,   /*REMOVE COLUMNS*/
                                        invoices_tbl (i).AR_TYPE,
                                        invoices_tbl (i).BATCH_SOURCE,
                                        invoices_tbl (i).BILL_CITY,
                                        --invoices_tbl (i).BILL_COUNTRY,   /*REMOVE COLUMNS*/
                                        invoices_tbl (i).BILL_COUNTRY_CODE,
                                        invoices_tbl (i).BILL_COUNTY,
                                        invoices_tbl (i).BILL_POSTAL_CODE,
                                        invoices_tbl (i).BILL_STATE,
                                        invoices_tbl (i).BILL_TO_CUSTOMER_ID,
                                        invoices_tbl (i).BILL_TO_SITE_USE_ID,
                                        invoices_tbl (i).DELIVER_TO, /*ADD COLUMN*/
                                        invoices_tbl (i).BRAND,
                                        --invoices_tbl (i).COLOR,      /*REMOVE COLUMNS*/
                                        invoices_tbl (i).CUSTOMER_NAME,
                                        invoices_tbl (i).CUSTOMER_NUMBER,
                                        --invoices_tbl (i).CURRENT_LANDED_COST,   /*REMOVE COLUMNS*/
                                        invoices_tbl (i).CUSTOMER_TRX_ID,
                                        invoices_tbl (i).CUSTOMER_TRX_LINE_ID,
                                        invoices_tbl (i).CUST_TRX_LINE_GL_DIST_ID,
                                        invoices_tbl (i).COGS_ACCOUNT,
                                        invoices_tbl (i).CODE_COMBINATION_ID,
                                        invoices_tbl (i).EXTENDED_AMOUNT,
                                        invoices_tbl (i).ENTERED_TOTAL_AMT,
                                        invoices_tbl (i).FREIGHT_AMT,
                                        invoices_tbl (i).FREIGHT_TAX,
                                        invoices_tbl (i).FUNCTIONAL_TOTAL_AMT,
                                        invoices_tbl (i).INTERFACE_LINE_ATTRIBUTE6,
                                        invoices_tbl (i).INTERFACE_LINE_ATTRIBUTE7,
                                        invoices_tbl (i).INTERFACE_LINE_ATTRIBUTE11,
                                        invoices_tbl (i).INVOICED_QTY,
                                        invoices_tbl (i).INVOICE_DATE,
                                        invoices_tbl (i).INVOICE_NUM,
                                        invoices_tbl (i).ITEM_TYPE,
                                        invoices_tbl (i).LINE_TYPE,
                                        invoices_tbl (i).MACAU_COST,
                                        --invoices_tbl (i).MATERIAL_COST,   /*REMOVE COLUMNS*/
                                        invoices_tbl (i).OPERATING_UNIT,
                                        invoices_tbl (i).ORDER_TYPE,
                                        invoices_tbl (i).ORG_ID,
                                        invoices_tbl (i).PRODUCT,
                                        --invoices_tbl (i).PURCHASE_ORDER,   /*REMOVE COLUMNS*/
                                        invoices_tbl (i).REVENUE_ACCOUNT,
                                        invoices_tbl (i).SALES_ORDER,
                                        invoices_tbl (i).SET_OF_BOOKS_ID,
                                        --invoices_tbl (i).SHIP_COUNTRY,   /*REMOVE COLUMNS*/
                                        invoices_tbl (i).SHIP_COUNTRY_CODE,
                                        invoices_tbl (i).SHIP_COUNTY,
                                        invoices_tbl (i).SHIP_TO_ADDRESS1,
                                        invoices_tbl (i).SHIP_TO_ADDRESS2,
                                        invoices_tbl (i).SHIP_TO_CITY,
                                        invoices_tbl (i).SHIP_TO_SITE_USE_ID,
                                        invoices_tbl (i).SHIP_TO_STATE,
                                        invoices_tbl (i).SHIP_TO_ZIPCODE,
                                        --invoices_tbl (i).SKU,   /*REMOVE COLUMNS*/
                                        --invoices_tbl (i).STYLE,   /*REMOVE COLUMNS*/
                                        invoices_tbl (i).SUB_CLASS,
                                        invoices_tbl (i).SUB_GROUP,
                                        invoices_tbl (i).TRANSACTION_LANDED_COST,
                                        invoices_tbl (i).TAX_RATE,
                                        --invoices_tbl (i).TAX_RATE_CODE,   /*REMOVE COLUMNS*/
                                        invoices_tbl (i).TAX_RATE_AMOUNT,
                                          --invoices_tbl(i).USD_REVENUE_TOTAL,
                                          NVL (invoices_tbl (i).amount, 0)
                                        * NVL (
                                              invoices_tbl (i).exchange_rate,
                                              1),
                                        invoices_tbl (i).UNIT_LIST_PRICE,
                                        --invoices_tbl (i).UNIT_SELLING_PRICE,   /*REMOVE COLUMNS*/
                                        invoices_tbl (i).organization_ID--invoices_tbl (i).wholesale_price   /*REMOVE COLUMNS*/
                                                                        );

                COMMIT;
            /* l_count := l_count + 1;

             IF MOD (l_count, 5000) = 0
             THEN
                fnd_file.put_line (
                   fnd_file.LOG,
                      'Before COMMIT: '
                   || 'l_count: '
                   || l_count
                   || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                COMMIT;
                fnd_file.put_line (
                   fnd_file.LOG,
                      'After COMMIT: '
                   || 'l_count: '
                   || l_count
                   || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
             END IF;*/


            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Unexpected Exception Error Encountered in BULK Insert: '
                        || SQLCODE
                        || '-'
                        || SQLERRM);
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                   'After Bulk Insert : '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')); /*PERFORMANCE -Added log*/
        /*PERFORMANCE -BULK Insert Login -End*/

        END LOOP;                                                -- While Loop


        /* fnd_file.put_line (
            fnd_file.LOG,
               'Before Bulk Insert : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));              /*PERFORMANCE -Added log*/


        /*      BEGIN

             fnd_file.put_line (
                       fnd_file.LOG,
                          'invoices_tbl.COUNT : '
                       || invoices_tbl.COUNT);

                 FORALL i IN invoices_tbl.FIRST .. invoices_tbl.LAST
                    INSERT INTO xxdo_ar_sales_det_t (ACCOUNT_CLASS,
                                                     ADDRESS_NAME,
                                                     AR_TYPE,
                                                     BATCH_SOURCE,
                                                     BILL_CITY,
                                                     BILL_COUNTRY,
                                                     BILL_COUNTRY_CODE,
                                                     BILL_COUNTY,
                                                     BILL_POSTAL_CODE,
                                                     BILL_STATE,
                                                     BILL_TO_CUSTOMER_ID,
                                                     BILL_TO_SITE_USE_ID,
                                                     BRAND,
                                                     COLOR,
                                                     CUSTOMER_NAME,
                                                     CUSTOMER_NUMBER,
                                                     CURRENT_LANDED_COST,
                                                     CUSTOMER_TRX_ID,
                                                     CUSTOMER_TRX_LINE_ID,
                                                     CUST_TRX_LINE_GL_DIST_ID,
                                                     COGS_ACCOUNT,
                                                     CODE_COMBINATION_ID,
                                                     EXTENDED_AMOUNT,
                                                     ENTERED_TOTAL_AMT,
                                                     FREIGHT_AMT,
                                                     FREIGHT_TAX,
                                                     FUNCTIONAL_TOTAL_AMT,
                                                     INTERFACE_LINE_ATTRIBUTE6,
                                                     INTERFACE_LINE_ATTRIBUTE7,
                                                     INTERFACE_LINE_ATTRIBUTE11,
                                                     INVOICED_QTY,
                                                     INVOICE_DATE,
                                                     INVOICE_NUM,
                                                     ITEM_TYPE,
                                                     LINE_TYPE,
                                                     MACAU_COST,
                                                     MATERIAL_COST,
                                                     OPERATING_UNIT,
                                                     ORDER_TYPE,
                                                     ORG_ID,
                                                     PRODUCT,
                                                     PURCHASE_ORDER,
                                                     REVENUE_ACCOUNT,
                                                     SALES_ORDER,
                                                     SET_OF_BOOKS_ID,
                                                     SHIP_COUNTRY,
                                                     SHIP_COUNTRY_CODE,
                                                     SHIP_COUNTY,
                                                     SHIP_TO_ADDRESS1,
                                                     SHIP_TO_ADDRESS2,
                                                     SHIP_TO_CITY,
                                                     SHIP_TO_SITE_USE_ID,
                                                     SHIP_TO_STATE,
                                                     SHIP_TO_ZIPCODE,
                                                     SKU,
                                                     STYLE,
                                                     SUB_CLASS,
                                                     SUB_GROUP,
                                                     TRANSACTION_LANDED_COST,
                                                     TAX_RATE,
                                                     TAX_RATE_CODE,
                                                     TAX_RATE_AMOUNT,
                                                     USD_REVENUE_TOTAL,
                                                     UNIT_LIST_PRICE,
                                                     UNIT_SELLING_PRICE,
                                                     WAREHOUSE_ID,
                                                     WHOLESALE_PRICE)
                         VALUES (invoices_tbl (i).ACCOUNT_CLASS,
                                 invoices_tbl (i).ADDRESS_NAME,
                                 invoices_tbl (i).AR_TYPE,
                                 invoices_tbl (i).BATCH_SOURCE,
                                 invoices_tbl (i).BILL_CITY,
                                 invoices_tbl (i).BILL_COUNTRY,
                                 invoices_tbl (i).BILL_COUNTRY_CODE,
                                 invoices_tbl (i).BILL_COUNTY,
                                 invoices_tbl (i).BILL_POSTAL_CODE,
                                 invoices_tbl (i).BILL_STATE,
                                 invoices_tbl (i).BILL_TO_CUSTOMER_ID,
                                 invoices_tbl (i).BILL_TO_SITE_USE_ID,
                                 invoices_tbl (i).BRAND,
                                 invoices_tbl (i).COLOR,
                                 invoices_tbl (i).CUSTOMER_NAME,
                                 invoices_tbl (i).CUSTOMER_NUMBER,
                                 invoices_tbl (i).CURRENT_LANDED_COST,
                                 invoices_tbl (i).CUSTOMER_TRX_ID,
                                 invoices_tbl (i).CUSTOMER_TRX_LINE_ID,
                                 invoices_tbl (i).CUST_TRX_LINE_GL_DIST_ID,
                                 invoices_tbl (i).COGS_ACCOUNT,
                                 invoices_tbl (i).CODE_COMBINATION_ID,
                                 invoices_tbl (i).EXTENDED_AMOUNT,
                                 invoices_tbl (i).ENTERED_TOTAL_AMT,
                                 invoices_tbl (i).FREIGHT_AMT,
                                 invoices_tbl (i).FREIGHT_TAX,
                                 invoices_tbl (i).FUNCTIONAL_TOTAL_AMT,
                                 invoices_tbl (i).INTERFACE_LINE_ATTRIBUTE6,
                                 invoices_tbl (i).INTERFACE_LINE_ATTRIBUTE7,
                                 invoices_tbl (i).INTERFACE_LINE_ATTRIBUTE11,
                                 invoices_tbl (i).INVOICED_QTY,
                                 invoices_tbl (i).INVOICE_DATE,
                                 invoices_tbl (i).INVOICE_NUM,
                                 invoices_tbl (i).ITEM_TYPE,
                                 invoices_tbl (i).LINE_TYPE,
                                 invoices_tbl (i).MACAU_COST,
                                 invoices_tbl (i).MATERIAL_COST,
                                 invoices_tbl (i).OPERATING_UNIT,
                                 invoices_tbl (i).ORDER_TYPE,
                                 invoices_tbl (i).ORG_ID,
                                 invoices_tbl (i).PRODUCT,
                                 invoices_tbl (i).PURCHASE_ORDER,
                                 invoices_tbl (i).REVENUE_ACCOUNT,
                                 invoices_tbl (i).SALES_ORDER,
                                 invoices_tbl (i).SET_OF_BOOKS_ID,
                                 invoices_tbl (i).SHIP_COUNTRY,
                                 invoices_tbl (i).SHIP_COUNTRY_CODE,
                                 invoices_tbl (i).SHIP_COUNTY,
                                 invoices_tbl (i).SHIP_TO_ADDRESS1,
                                 invoices_tbl (i).SHIP_TO_ADDRESS2,
                                 invoices_tbl (i).SHIP_TO_CITY,
                                 invoices_tbl (i).SHIP_TO_SITE_USE_ID,
                                 invoices_tbl (i).SHIP_TO_STATE,
                                 invoices_tbl (i).SHIP_TO_ZIPCODE,
                                 invoices_tbl (i).SKU,
                                 invoices_tbl (i).STYLE,
                                 invoices_tbl (i).SUB_CLASS,
                                 invoices_tbl (i).SUB_GROUP,
                                 invoices_tbl (i).TRANSACTION_LANDED_COST,
                                 invoices_tbl (i).TAX_RATE,
                                 invoices_tbl (i).TAX_RATE_CODE,
                                 invoices_tbl (i).TAX_RATE_AMOUNT,
                                 --invoices_tbl(i).USD_REVENUE_TOTAL,
                                 invoices_tbl (i).USD_REVENUE_TOTAL,
                                 invoices_tbl (i).UNIT_LIST_PRICE,
                                 invoices_tbl (i).UNIT_SELLING_PRICE,
                                 invoices_tbl (i).organization_ID,
                                 invoices_tbl (i).wholesale_price);

               COMMIT;

                /* l_count := l_count + 1;

                 IF MOD (l_count, 5000) = 0
                 THEN
                    fnd_file.put_line (
                       fnd_file.LOG,
                          'Before COMMIT: '
                       || 'l_count: '
                       || l_count
                       || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                    COMMIT;
                    fnd_file.put_line (
                       fnd_file.LOG,
                          'After COMMIT: '
                       || 'l_count: '
                       || l_count
                       || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                 END IF;*/

        /*  EXCEPTION
       WHEN OTHERS
       THEN
        apps.fnd_file.put_line (
         apps.fnd_file.LOG,
         'Unexpected Exception Error Encountered in BULK Insert: '
        || SQLCODE
        || '-'
        || SQLERRM);

          END;

       fnd_file.put_line (
                fnd_file.LOG,
                   'After Bulk Insert : '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS')); */


        apps.fnd_file.put_line (apps.fnd_file.LOG, 'Begin of Statement');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               'Organization'
            || CHR (9)
            || 'Invoice Num'
            || CHR (9)
            || 'Invoice Date'
            || CHR (9)
            || 'AR Type'
            || CHR (9)
            || 'Order Num'
            || CHR (9)
            || 'Order Type'
            || CHR (9)
            || 'Customer Number'
            || CHR (9)
            || 'Customer'
            || CHR (9)
            --|| 'Address Name'   /*REMOVE COLUMNS*/
            --|| CHR (9)
            || 'Ship To Address1'
            || CHR (9)
            || 'Ship To Address2'
            || CHR (9)
            || 'Ship To City'
            || CHR (9)
            || 'Ship To State'
            || CHR (9)
            || 'Ship To Zip Code'
            || CHR (9)
            || 'Ship County'
            || CHR (9)
            || 'Ship Country Code'
            || CHR (9)
            --|| 'Ship Country'   /*REMOVE COLUMNS*/
            --|| CHR (9)
            || 'Bill City'
            || CHR (9)
            || 'Bill State'
            || CHR (9)
            || 'Bill County'
            || CHR (9)
            || 'Bill Postal Code'
            || CHR (9)
            || 'Bill Country Code'
            || CHR (9)
            --|| 'Bill Country'   /*REMOVE COLUMNS*/
            --|| CHR (9)
            || 'Deliver To'                                     /*ADD COLUMN*/
            || CHR (9)
            || 'Product Group'
            || CHR (9)
            || 'Sub Group'
            || CHR (9)
            || 'Sub Class'
            || CHR (9)
            --|| 'Style'   /*REMOVE COLUMNS*/
            --|| CHR (9)
            --|| 'Color'   /*REMOVE COLUMNS*/
            --|| CHR (9)
            --|| 'Item'   /*REMOVE COLUMNS*/
            --|| CHR (9)
            || 'Item Type'
            || CHR (9)
            || 'Account Type'
            || CHR (9)
            || 'Functional Revenue Amount'
            || CHR (9)
            || 'Quantity'
            || CHR (9)
            --|| 'Current Landed Cost'    /*REMOVE COLUMNS*/
            --|| CHR (9)
            || 'Transaction Landed Cost'
            || CHR (9)
            --|| 'Unit Selling Price'    /*REMOVE COLUMNS*/
            --|| CHR (9)
            || 'Unit List Price'
            || CHR (9)
            --|| 'Discount'    /*REMOVE COLUMNS*/
            --|| CHR (9)
            || 'Ext Discount'
            || CHR (9)
            --|| 'Tax Rate Code'   /*REMOVE COLUMNS*/
            --|| CHR (9)
            || 'Tax Rate'
            || CHR (9)
            || 'Entered Tax Amt'
            || CHR (9)
            || 'Freight Amount'
            || CHR (9)
            || 'Freight Tax'
            || CHR (9)
            || 'Entered Total Amt'
            || CHR (9)
            || 'Functional Total Amt'
            || CHR (9)
            --|| 'Wholesale price'   /*REMOVE COLUMNS*/
            --|| CHR (9)
            || 'Revenue Account'
            || CHR (9)
            || 'COGS Account'--|| CHR (9)
                             --|| 'Purchase Order'   /*REMOVE COLUMNS*/
                             --|| CHR (9)
                             --|| 'Material Cost'   /*REMOVE COLUMNS*/
                             --|| CHR (9)
                             --|| 'Consolidated Cost'  /*REMOVE COLUMNS*/
                             );

        FOR j IN c_sel_invoices
        LOOP
            BEGIN
                NULL;
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       REPLACE (j.operating_unit, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Invoice_num, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (TO_CHAR (j.invoice_date, 'MM/DD/YYYY'),
                                CHR (9),
                                ' ')
                    || CHR (9)
                    || REPLACE (j.ar_type, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.sales_order, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.order_type, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Customer_Number, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Customer_name, CHR (9), ' ')
                    || CHR (9)
                    --|| REPLACE (j.address_name, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    || REPLACE (j.Ship_to_Address1, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Ship_to_Address2, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Ship_to_city, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.ship_to_state, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Ship_to_zipcode, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.ship_county, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.ship_country_code, CHR (9), ' ')
                    || CHR (9)
                    --|| REPLACE (j.ship_country, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    || REPLACE (j.bill_city, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.bill_state, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.bill_county, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.bill_postal_code, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.bill_country_code, CHR (9), ' ')
                    || CHR (9)
                    --|| REPLACE (j.bill_country, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    || REPLACE (j.deliver_to, CHR (9), ' ')     /*ADD COLUMN*/
                    || CHR (9)
                    || REPLACE (j.Product, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.sub_group, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.sub_class, CHR (9), ' ')
                    || CHR (9)
                    --|| REPLACE (j.style, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    --|| REPLACE (j.color, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    --|| REPLACE (j.sku, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    || REPLACE (j.item_type, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.account_class, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.usd_revenue_total, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.invoiced_qty, CHR (9), ' ')
                    || CHR (9)
                    --|| REPLACE (j.Current_Landed_Cost, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    || REPLACE (j.Transaction_landed_cost, CHR (9), ' ')
                    || CHR (9)
                    --|| REPLACE (j.unit_selling_price, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    || REPLACE (j.unit_list_price, CHR (9), ' ')
                    || CHR (9)
                    --|| REPLACE (j.discount, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    || REPLACE (j.extra_discount, CHR (9), ' ')
                    || CHR (9)
                    --|| REPLACE (j.tax_rate_code, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    || REPLACE (j.tax_rate, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.entered_tax_amt, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Freight_Amt, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Freight_Tax, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Entered_Total_Amt, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.Functional_Total_amt, CHR (9), ' ')
                    || CHR (9)
                    --|| REPLACE (j.wholesale_price, CHR (9), ' ')   /*REMOVE COLUMNS*/
                    --|| CHR (9)
                    || REPLACE (j.Revenue_Account, CHR (9), ' ')
                    || CHR (9)
                    || REPLACE (j.cogs_account, CHR (9), ' ')--|| CHR (9)
                                                             --|| REPLACE (j.purchase_order, CHR (9), ' ')   /*REMOVE COLUMNS*/
                                                             --|| CHR (9)
                                                             --|| REPLACE (j.material_cost, CHR (9), ' ')    /*REMOVE COLUMNS*/
                                                             --|| CHR (9)
                                                             --|| REPLACE (j.consolidated_cost, CHR (9), ' ')   /*REMOVE COLUMNS*/
                                                             );
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;                                          --- End of For Loop
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Unexpected Exception Error Encountered : '
                || SQLCODE
                || '-'
                || SQLERRM);
    END main;
END XXDO_ARSALES_TAX_DET_PKG;
/
