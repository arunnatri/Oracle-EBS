--
-- XXDO_AR_INVOICE_PRINT_CA  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AR_INVOICE_PRINT_CA"
AS
    /*******************************************************************************
    * Program Name : XXDO_AR_INVOICE_PRINT
    * Language     :
    * History      :
    *
    * WHO                           WHAT              Desc                  WHEN
    * -------------- ---------------------------------------------- ---------------
    * BT Technology Team         1.0 - Initial Version                   16-JAN-2015
    * Infosys            2.0 - Modified to implement parellel processing for invoices.  12-May-2016.
    * BT Technology Team             2.1      Changes for INC0305730       01-Aug-2016
    *                                         to add creation_date logic
    * -----------------------------------------------------------------------------*/
    FUNCTION remit_to_address_id (p_customer_trx_id IN NUMBER)
        RETURN VARCHAR
    IS
        l_factored              VARCHAR2 (30);
        l_brand                 VARCHAR2 (80);
        l_remit_to_address_id   NUMBER;
        l_org_id                NUMBER;
        l_final_remit_to        NUMBER;
    BEGIN
        -- 1. Query decision factors for the current transaction: Factored, Brand, Default Remit_to_address_id , Org_id
        l_factored   := factored_flag (p_customer_trx_id);

        BEGIN
            SELECT attribute5 brand, remit_to_address_id, org_id
              INTO l_brand, l_remit_to_address_id, l_org_id
              FROM apps.ra_customer_trx_all t
             WHERE t.customer_trx_id = p_customer_trx_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN ('');
        END;

        -- 2. If transaction is factored, then identify the remit-to site with an addressee of "FACTOR%" (if present) for the current org_id
        -- If found, return this remit_to
        IF l_factored = 'Y'
        THEN
            BEGIN
                SELECT address_id
                  INTO l_final_remit_to
                  FROM --   apps.ra_addresses_all          --COMMENTED BY BT TECHNOLOGY TEAM ON 16-JAN-2015
                       xxd_ra_addresses_morg_v
                 --ADDED BY BT TECHNOLOGY TEAM ON 16-JAN-2015
                 WHERE     org_id = l_org_id
                       AND party_id = -1
                       AND addressee LIKE 'FACTOR%';
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_final_remit_to   := '';
            END;

            IF l_final_remit_to IS NOT NULL
            THEN
                RETURN (l_final_remit_to);
            END IF;
        END IF;

        -- 3. If non-factored, then identify the remit-to site with an address = <transaction brand: attribute5> for the current org_id
        -- If found, return this remit_to
        BEGIN
            SELECT address_id
              INTO l_final_remit_to
              FROM --  apps.ra_addresses_all          --COMMENTED BY BT TECHNOLOGY TEAM ON 16-JAN-2015
                   apps.xxd_ra_addresses_morg_v
             --ADDED BY BT TECHNOLOGY TEAM ON 16-JAN-2015
             WHERE     org_id = l_org_id
                   AND party_id = -1
                   AND addressee = l_brand;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_final_remit_to   := '';
        END;

        IF l_final_remit_to IS NOT NULL
        THEN
            RETURN (l_final_remit_to);
        END IF;

        -- 4. Otherwise, return the current remit_to on the transaction - previously defaulted by the system during entry.
        RETURN (l_remit_to_address_id);
    END;

    FUNCTION factored_flag (p_customer_trx_id IN NUMBER)
        RETURN VARCHAR
    IS
        l_factored   VARCHAR2 (30);
    BEGIN
        SELECT DECODE (tt.TYPE, 'INV', apps.xxdoom_cit_int_pkg.is_fact_cust_f (DECODE (rct.interface_header_context, 'ORDER ENTRY', rct.interface_header_attribute1, ''), rct.bill_to_customer_id, rct.bill_to_site_use_id), 'N') factored
          INTO l_factored
          FROM apps.ra_customer_trx_all rct, apps.ra_cust_trx_types_all tt
         WHERE     rct.customer_trx_id = p_customer_trx_id
               AND rct.cust_trx_type_id = tt.cust_trx_type_id
               AND rct.org_id = tt.org_id;

        RETURN (l_factored);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN ('N');
    END;

    FUNCTION discount_amount_explanation (p_payment_schedule_id IN NUMBER)
        RETURN VARCHAR
    IS
        l_amount_desc       VARCHAR2 (3000) := '';
        l_discount_amount   NUMBER;
        l_discount_date     DATE;
    BEGIN
        -- Should only find 0 or 1 discount record
        FOR d
            IN (SELECT d.discount_percent, d.discount_days, d.discount_date,
                       d.discount_day_of_month, d.discount_months_forward, t.calc_discount_on_lines_flag,
                       ps.trx_date, ps.due_date, ps.amount_line_items_original,
                       ps.amount_due_original, ps.tax_original
                  FROM ra_terms t, ra_terms_lines_discounts d, ar_payment_schedules_all ps
                 WHERE     ps.payment_schedule_id = p_payment_schedule_id
                       AND ps.term_id = t.term_id
                       AND t.term_id = d.term_id
                       AND d.sequence_num = 1
                       AND ps.terms_sequence_number = 1)
        LOOP
            -- For simplicity, this function is limited to only invoices with 1 payment schedule installment (currently, all invoices have only 1 installment
            -- It also is limited to discount details with only 1 discount amount
            -- 1. Calculate Discount Amount
            --    Calc_discount_on_lines_flag has the following potential value:
            --    I   Invoice Amount
            --    L   Lines Only
            --    F   Lines and Tax, not Freight Items and Tax
            --    T   Lines, Freight Items, and Tax
            IF d.calc_discount_on_lines_flag IN ('I', 'T')
            THEN
                l_discount_amount   :=
                      NVL (d.amount_due_original, 0)
                    * (NVL (d.discount_percent, 0) / 100);
            ELSIF d.calc_discount_on_lines_flag = 'L'
            THEN
                l_discount_amount   :=
                      NVL (d.amount_line_items_original, 0)
                    * (NVL (d.discount_percent, 0) / 100);
            ELSE                   -- d.calc_discount_on_lines_flag = 'F' THEN
                l_discount_amount   :=
                      (NVL (d.amount_line_items_original, 0) + NVL (d.tax_original, 0))
                    * (NVL (d.discount_percent, 0) / 100);
            END IF;

            -- 2. Calculate Discount Date
            IF d.discount_days IS NOT NULL
            THEN
                l_discount_date   := d.trx_date + d.discount_days;
            ELSIF d.discount_date IS NOT NULL
            THEN
                l_discount_date   := d.discount_date;
            ELSE
                BEGIN
                    SELECT TO_DATE (NVL (TO_CHAR (NVL (d.discount_day_of_month, 0)), TO_CHAR (ADD_MONTHS (d.trx_date, NVL (d.discount_months_forward, 0)), 'DD')) || TO_CHAR (ADD_MONTHS (d.trx_date, NVL (d.discount_months_forward, 0)), '-MON-YYYY'), 'DD-MON-YYYY')
                      INTO l_discount_date
                      FROM DUAL;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_discount_date   := '';
                END;
            END IF;

            -- 3. Assemble Final Output String
            IF l_discount_amount IS NOT NULL AND l_discount_date IS NOT NULL
            THEN
                l_amount_desc   :=
                       'Eligible to deduct '
                    || TRIM (
                           TO_CHAR (l_discount_amount, '999,999,999,999.99'))
                    || ' if paid by '
                    || TO_CHAR (l_discount_date, 'MM/DD/YYYY');
            ELSE
                l_amount_desc   := '';
            END IF;
        END LOOP;

        RETURN (l_amount_desc);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN ('');
    END;

    FUNCTION address_dsp (p_address1 IN VARCHAR2, p_address2 IN VARCHAR2, p_address3 IN VARCHAR2, p_address4 IN VARCHAR2, p_city IN VARCHAR2, p_state IN VARCHAR2, p_postal_code IN VARCHAR2, p_country IN VARCHAR2, p_country_name IN VARCHAR2
                          , p_org_id IN NUMBER)
        RETURN VARCHAR
    IS
        l_address                   VARCHAR2 (3000);
        l_line_count                NUMBER := 1;
        l_default_country           VARCHAR2 (80);
        l_print_home_country_flag   VARCHAR2 (80);
    BEGIN
        l_address      := NVL (p_address1, ' ') || CHR (13);

        IF p_address2 IS NOT NULL
        THEN
            l_address      := l_address || p_address2 || CHR (13);
            l_line_count   := l_line_count + 1;
        END IF;

        IF p_address3 IS NOT NULL OR p_address4 IS NOT NULL
        THEN
            l_address      := l_address || p_address3;

            IF p_address4 IS NOT NULL
            THEN
                l_address   := l_address || ', ' || p_address4 || CHR (13);
            ELSE
                l_address   := l_address || CHR (13);
            END IF;

            l_line_count   := l_line_count + 1;
        END IF;

        l_address      := l_address || p_city;

        IF p_city IS NOT NULL
        THEN
            l_address   := l_address || ', ';
        END IF;

        l_address      := l_address || p_state || ' ' || p_postal_code;
        l_line_count   := l_line_count + 1;

        BEGIN
            SELECT default_country, print_home_country_flag
              INTO l_default_country, l_print_home_country_flag
              FROM ar_system_parameters_all
             WHERE org_id = p_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_default_country           := '*';
                l_print_home_country_flag   := 'N';
        END;

        IF    l_default_country <> p_country
           OR (l_default_country = p_country AND l_print_home_country_flag = 'Y')
        THEN
            -- Include country name in the output
            l_address      := l_address || CHR (13) || p_country_name;
            l_line_count   := l_line_count + 1;
        END IF;

        IF l_line_count = 2
        THEN
            l_address   :=
                   l_address
                || CHR (13)
                || ' '
                || CHR (13)
                || ' '
                || CHR (13)
                || ' ';
        ELSIF l_line_count = 3
        THEN
            l_address   := l_address || CHR (13) || ' ' || CHR (13) || ' ';
        ELSIF l_line_count = 4
        THEN
            l_address   := l_address || CHR (13) || ' ';
        END IF;

        RETURN (l_address);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN ('');
    END;

    FUNCTION size_quantity_dsp (p_output_option IN VARCHAR, p_customer_trx_id IN NUMBER, p_style IN VARCHAR
                                , p_color IN VARCHAR)
        RETURN VARCHAR
    IS
        CURSOR size_dtl IS
              SELECT rctl.customer_trx_id, /* msi.segment1,
                                            msi.segment2,
                                            msi.segment3 sze,
                                                     NVL (style.description, rctl.description) style_desc,
                                                     color.description color_desc,*/
                                           --commented by BT Team on 16-JAN-2015
                                           msi.style_number, msi.color_code,
                     msi.item_size sze, msi.style_desc, msi.color_desc,
                     --added by BT Tech team on 16-JAN-2015
                     SUM (DECODE (NVL (rctl.interface_line_attribute11, 0), 0, NVL (rctl.quantity_invoiced, rctl.quantity_credited), 0)) qty, DECODE (SUM (DECODE (NVL (rctl.interface_line_attribute11, 0), 0, NVL (rctl.quantity_invoiced, rctl.quantity_credited), 0)), 0, 0, SUM (rctl.extended_amount) / SUM (DECODE (NVL (rctl.interface_line_attribute11, 0), 0, NVL (rctl.quantity_invoiced, rctl.quantity_credited), 0))) avg_unit_price, SUM (rctl.extended_amount) ext_amt
                --FROM mtl_system_items_b msi,                                   --commented by BT Team on 16-JAN-2015
                FROM xxd_common_items_v msi, --added by BT Team on  16-JAN-2015
                     (SELECT NVL (l.warehouse_id, p.parameter_value) inv_org_id, l.*
                        FROM ra_customer_trx_lines_all l, oe_sys_parameters_all p
                       WHERE     l.org_id = p.org_id
                             AND p.parameter_code = 'MASTER_ORGANIZATION_ID'
                             AND l.line_type = 'LINE') rctl
               /*(SELECT flex_value, description
                  FROM apps.fnd_flex_values_vl
                 WHERE flex_value_set_id = 1003729) style       -- Color VS
                                                         ,
               (SELECT flex_value, description
                  FROM apps.fnd_flex_values_vl
                 WHERE flex_value_set_id = 1003724) color       -- Color VS*/
               --commented by BT Team on 16/01/2015
               WHERE     rctl.customer_trx_id = p_customer_trx_id
                     /*   AND msi.segment1 IS NOT NULL
                        AND msi.segment1 = p_style
                        AND msi.segment2 IS NOT NULL
                        AND msi.segment2 = p_color*/
                     --commented BY BT Team on 16/01/2015
                     AND msi.style_number IS NOT NULL
                     AND msi.style_number = p_style
                     AND msi.color_code IS NOT NULL
                     AND msi.color_code = p_color --Added by BT Team on 16/01/2015
                     AND rctl.inventory_item_id = msi.inventory_item_id(+)
                     AND rctl.inv_org_id = msi.organization_id(+)
            /*AND msi.segment1 = style.flex_value(+)
            AND msi.segment2 = color.flex_value(+)*/
            --commented by BT Team on 16/01/2015
            GROUP BY rctl.customer_trx_id, /* msi.segment1,
                                            msi.segment2,
                                            msi.segment3,
                                            NVL (style.description, rctl.description),
                                            color.description*/
                                           --commented by  BT Team on 16/01/2015
                                           msi.style_number, msi.color_code,
                     msi.item_size, msi.style_desc, msi.color_desc --added by BT Tech team on 16/01/2015
            --ORDER BY msi.segment3;                                                             --commented by BT team on 16/01/2015
            ORDER BY msi.item_size;           --Added by BT Team on 16/01/2015

        l_cnt       NUMBER := 0;
        l_qty       VARCHAR2 (3000);
        l_qty_len   NUMBER;
        l_size      VARCHAR2 (3000);
        l_sze_len   NUMBER;
        l_size1     VARCHAR2 (3000);
        l_qty1      VARCHAR2 (3000);
        l_output    VARCHAR2 (3000);
    BEGIN
        FOR i IN size_dtl
        LOOP
            l_cnt   := l_cnt + 1;

            IF LENGTH (i.sze) > LENGTH (i.qty)
            THEN
                l_qty_len   := LENGTH (i.sze) - LENGTH (i.qty);
            END IF;

            IF LENGTH (i.qty) > LENGTH (i.sze)
            THEN
                l_sze_len   := LENGTH (i.qty) - LENGTH (i.sze);
            END IF;

            IF l_cnt <= 8
            THEN
                IF LENGTH (i.sze) > LENGTH (i.qty)
                THEN
                    l_qty   :=
                           l_qty
                        || CHR (9)
                        || RPAD (i.qty, LENGTH (i.sze) + l_qty_len)
                        || ' '
                        || CHR (9);
                ELSE
                    l_qty   := l_qty || CHR (9) || i.qty || ' ' || CHR (9);
                END IF;

                IF LENGTH (i.qty) > LENGTH (i.sze)
                THEN
                    l_size   :=
                           l_size
                        || CHR (9)
                        || RPAD (i.sze, LENGTH (i.qty) + l_sze_len)
                        || ' '
                        || CHR (9);
                ELSE
                    l_size   := l_size || CHR (9) || i.sze || ' ' || CHR (9);
                END IF;
            ELSIF l_cnt > 8
            THEN
                IF LENGTH (i.qty) > LENGTH (i.sze)
                THEN
                    l_size1   :=
                           l_size1
                        || CHR (9)
                        || RPAD (i.sze, LENGTH (i.qty) + l_sze_len)
                        || ' '
                        || CHR (9);
                ELSE
                    l_size1   :=
                        l_size1 || CHR (9) || i.sze || ' ' || CHR (9);
                END IF;

                IF LENGTH (i.sze) > LENGTH (i.qty)
                THEN
                    l_qty1   :=
                           l_qty1
                        || CHR (9)
                        || RPAD (i.qty, LENGTH (i.sze) + l_qty_len)
                        || ' '
                        || CHR (9);
                ELSE
                    l_qty1   := l_qty1 || CHR (9) || i.qty || ' ' || CHR (9);
                END IF;
            END IF;
        END LOOP;

        IF p_output_option = 'SIZE1'
        THEN
            l_output   := (l_size);
        ELSIF p_output_option = 'SIZE2'
        THEN
            l_output   := l_size1;
        ELSIF p_output_option = 'QTY1'
        THEN
            l_output   := l_qty;
        ELSIF p_output_option = 'QTY2'
        THEN
            l_output   := l_qty1;
        ELSE
            l_output   := '';
        END IF;

        RETURN (l_output);
    END;

    FUNCTION org_logo_file_path (p_org_id IN NUMBER)
        RETURN VARCHAR
    IS
    BEGIN
        RETURN (' ');
    END;

    FUNCTION brand_logo_file_path (p_brand IN VARCHAR)
        RETURN VARCHAR
    IS
    BEGIN
        RETURN (' ');
    END;

    PROCEDURE update_print_flag (
        p_customer_id        IN     VARCHAR2 DEFAULT NULL,
        p_trx_class          IN     VARCHAR2 DEFAULT NULL,
        p_re_transmit_flag   IN     VARCHAR2 DEFAULT NULL,
        p_cust_num_from      IN     VARCHAR2 DEFAULT NULL,
        p_cust_num_to        IN     VARCHAR2 DEFAULT NULL,
        p_bill_to_site       IN     VARCHAR2 DEFAULT NULL,
        p_trx_date_low       IN     VARCHAR2 DEFAULT NULL,
        p_trx_date_high      IN     VARCHAR2 DEFAULT NULL,
        p_brand              IN     VARCHAR2 DEFAULT NULL,
        p_invoice_num_from   IN     VARCHAR2 DEFAULT NULL,
        p_invoice_num_to     IN     VARCHAR2 DEFAULT NULL,
        p_org_id             IN     VARCHAR2 DEFAULT NULL,
        x_return_status         OUT VARCHAR2,
        x_return_message        OUT VARCHAR2)
    IS
        l_query   VARCHAR2 (32767);
        l_step    NUMBER := 0;
    BEGIN
        l_step            := l_step + 10;                                 --10
        l_query           :=
               'UPDATE ra_customer_trx_all rtrx
                     SET printing_pending = ''N'',
                         printing_last_printed = SYSDATE,
                         printing_count = NVL(printing_count,0)+1,
                         printing_original_date = DECODE(printing_original_date,NULL, SYSDATE, printing_original_date)
                   WHERE EXISTS (SELECT 1
                                    FROM   apps.ra_customer_trx_all       rct,
                                           apps.ar_payment_schedules_all  ps,
                                          (SELECT c.cust_account_id            customer_id
                                                 ,u.site_use_id                 site_use_id
                                                 ,c.account_number              customer_number
                                                 ,party.party_name              customer_name
                                                 ,loc.address1                  address1
                                                 ,loc.address2                  address2
                                                 ,loc.address3                  address3
                                                 ,loc.address4                  address4
                                                 ,loc.city                      city
                                                 ,nvl(loc.state, loc.province)  state
                                                 ,loc.postal_code               postal_code
                                                 ,loc.country                   country
                                                 ,terr.territory_short_name     country_name
                                                 ,u.tax_reference               site_tax_reference
                                                 ,party.tax_reference           cust_tax_reference
                                                 ,nvl(u.tax_reference,
                                                      party.tax_reference)      tax_reference
                                                ,c.CUSTOMER_CLASS_CODE
                                                ,party_site.attribute1          inv_trans_method
                                                ,party_site.attribute2          cm_trans_method
                                                ,party_site.attribute3          dm_trans_method
                                            FROM hz_cust_accounts       c
                                                ,hz_parties             party
                                                ,hz_cust_acct_sites_all a
                                                ,hz_party_sites         party_site
                                                ,hz_locations           loc
                                                ,hz_cust_site_uses_all  u
                                                ,apps.fnd_territories_tl  terr
                                            WHERE u.cust_acct_site_id   = a.cust_acct_site_id  -- address_id
                                            AND   a.party_site_id       = party_site.party_site_id
                                            AND   loc.location_id       = party_site.location_id
                                            AND   c.party_id            = party.party_id
                                            AND   loc.country           = terr.territory_code
                                            AND   terr.language         = userenv(''LANG'')
                                           --AND   (c.attribute9 is null or c.attribute9 not in (''01'',''11''))
                                           ) bill,
                                          (SELECT c.cust_account_id            customer_id
                                                 ,u.site_use_id                 site_use_id
                                                 ,c.account_number              customer_number
                                                 ,nvl(a.attribute1,party.party_name)              customer_name
                                                 ,loc.address1                  address1
                                                 ,loc.address2                  address2
                                                 ,loc.address3                  address3
                                                 ,loc.address4                  address4
                                                 ,loc.city                      city
                                                 ,nvl(loc.state, loc.province)  state
                                                 ,loc.postal_code               postal_code
                                                 ,loc.country                   country
                                                 ,terr.territory_short_name     country_name
                                                 ,u.tax_reference               site_tax_reference
                                                 ,party.tax_reference           cust_tax_reference
                                                 ,nvl(u.tax_reference,
                                                      party.tax_reference)      tax_reference
                                            FROM hz_cust_accounts       c
                                                ,hz_parties             party
                                                ,hz_cust_acct_sites_all a
                                                ,hz_party_sites         party_site
                                                ,hz_locations           loc
                                                ,hz_cust_site_uses_all  u
                                                ,apps.fnd_territories_tl  terr
                                            WHERE u.cust_acct_site_id   = a.cust_acct_site_id  -- address_id
                                            AND   a.party_site_id       = party_site.party_site_id
                                            AND   loc.location_id       = party_site.location_id
                                            AND   c.party_id            = party.party_id
                                            AND   loc.country           = terr.territory_code
                                            AND   terr.language         = userenv(''LANG'')
                                           ) ship,
                                           (SELECT acct_site.cust_acct_site_id    address_id
                                                  ,loc.address1                   address1
                                                  ,loc.address2                   address2
                                                  ,loc.address3                   address3
                                                  ,loc.ADDRESS4                   address4
                                                  ,loc.CITY                       city
                                                  ,nvl(loc.STATE,loc.province)    state
                                                  ,loc.POSTAL_CODE                postal_code
                                                  ,loc.COUNTRY                    country
                                                  ,terr.territory_short_name      country_name
                                                  ,party_site.addressee
                                                  ,acct_site.attribute2          contact_number
                                             FROM  hz_cust_acct_sites_all acct_site,
                                                   hz_party_sites party_site,
                                                   hz_locations loc,
                                                   apps.fnd_territories_tl  terr
                                             WHERE acct_site.party_site_id = party_site.party_site_id
                                             AND   loc.location_id = party_site.location_id
                                             AND   loc.country = terr.territory_code
                                             AND   terr.language         = userenv(''LANG'')
                                           ) remit,
                                           (SELECT F.freight_code, description
                                                   FROM   APPS.ORG_FREIGHT F,
                                                          APPS.OE_SYSTEM_PARAMETERS_ALL OSP
                                                   WHERE  F.ORGANIZATION_ID = OSP.MASTER_ORGANIZATION_ID
                                                   AND    OSP.ORG_ID = TO_NUMBER('
            || p_org_id
            || ')) ship_via,
                                           apps.ra_cust_trx_types_all     tt,
                                           apps.ra_batch_sources_all      abc,
                                           apps.ar_lookups                arl,
                                           apps.ra_terms                  term
                                          ,apps.jtf_rs_salesreps          rep
                                    WHERE  rct.bill_to_customer_id  = bill.customer_id
                                    AND    rct.bill_to_site_use_id  = bill.site_use_id
                                    AND    rct.ship_to_customer_id  = ship.customer_id (+)
                                    AND    rct.ship_to_site_use_id  = ship.site_use_id (+)
                                    AND    rct.cust_trx_type_id     = tt.cust_trx_type_id
                                    AND    rct.batch_source_id      = abc.batch_source_id(+)
                                    AND    rct.org_id               = abc.org_id(+)
                                    AND    rct.org_id               = tt.org_id
                                    AND    tt.type                  = arl.lookup_code
                                    AND    arl.lookup_type          = ''INV/CM''
                                    AND    rct.customer_trx_id      = ps.customer_trx_id
                                    AND    rct.term_id              = term.term_id (+)
                                    AND    rct.primary_salesrep_id  = rep.salesrep_id (+)
                                    AND    rct.org_id               = rep.org_id (+)
                                    AND    APPS.XXDO_AR_INVOICE_PRINT.remit_to_address_id (rct.customer_trx_id) = remit.address_id (+)
                                    AND    rct.ship_via             = ship_via.freight_code (+)
                                    AND    rct.printing_option = ''PRI''
                                    AND    ps.number_of_due_dates   = 1
                                    AND   NOT EXISTS (SELECT 1
                                                        FROM fnd_lookup_values flv
                                                       WHERE 1=1
                                                         AND flv.LANGUAGE = userenv(''LANG'')
                                                         AND flv.lookup_type = ''XXDOAR035_EXCLUDED_TRX_TYPES''
                                                         AND flv.meaning = tt.name
                                                         AND flv.description = tt.type
                                                         AND DECODE(sign(sysdate - NVL(flv.start_date_active, sysdate - 1)),
                                                                    -1, ''INACTIVE'',
                                                                     DECODE(sign(NVL(flv.end_date_active,sysdate + 1) - sysdate),
                                                                            -1, ''INACTIVE'',
                                                                            DECODE(flv.enabled_flag,
                                                                                   ''N'',''INACTIVE'',
                                                                                   ''ACTIVE''))) = ''ACTIVE'')
                                    AND (CASE  WHEN tt.type = ''CM''
                                                  AND UPPER(abc.name) LIKE ''%MANUAL%'' THEN NVL(SUBSTR(bill.cm_trans_method,1,1),''0'')
                                               WHEN tt.type = ''CM''
                                                  AND UPPER(abc.name) NOT LIKE ''%MANUAL%'' THEN NVL(SUBSTR(bill.cm_trans_method,2,1),''0'')
                                               WHEN tt.type = ''DM''
                                                  AND UPPER(abc.name) LIKE ''%MANUAL%'' THEN NVL(SUBSTR(bill.dm_trans_method,1,1),''0'')
                                               WHEN tt.type = ''DM''
                                                  AND UPPER(abc.name) NOT LIKE ''%MANUAL%'' THEN NVL(SUBSTR(bill.dm_trans_method,2,1),''0'')
                                               WHEN tt.type = ''INV''
                                                  AND UPPER(abc.name) LIKE ''%MANUAL%'' THEN NVL(SUBSTR(bill.inv_trans_method,1,1),''0'')
                                               WHEN tt.type = ''INV''
                                                  AND UPPER(abc.name) NOT LIKE ''%MANUAL%'' THEN NVL(SUBSTR(bill.inv_trans_method,2,1),''0'')
                                               ELSE ''0''
                                               END) != ''0''
                                    AND    rct.customer_trx_id      = rtrx.customer_trx_id
                                    AND    rct.org_id               = TO_NUMBER('''
            || p_org_id
            || ''')';
        l_step            := l_step + 10;                                 --20

        IF p_brand IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND  rct.attribute5           = '''
                || p_brand
                || '''';
        END IF;

        l_step            := l_step + 10;                                 --30

        IF p_invoice_num_from IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND rct.trx_number        >='''
                || p_invoice_num_from
                || '''';
        END IF;

        l_step            := l_step + 10;                                 --40

        IF p_invoice_num_to IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND rct.trx_number        <='''
                || p_invoice_num_to
                || '''';
        END IF;

        l_step            := l_step + 10;                                 --50

        IF p_customer_id IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and rct.bill_to_customer_id   = TO_NUMBER('''
                || p_customer_id
                || ''')';
        END IF;

        l_step            := l_step + 10;                                 --60

        IF p_trx_class IS NOT NULL
        THEN
            l_query   :=
                l_query || ' and tt.type = ''' || p_trx_class || '''';
        END IF;

        l_step            := l_step + 10;                                 --70

        IF p_trx_date_low IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and rct.trx_date >= TO_DATE('''
                || p_trx_date_low
                || ''',''DD-MON-YY'')';
        END IF;

        l_step            := l_step + 10;                                 --80

        IF p_trx_date_high IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and rct.trx_date <= TO_DATE('''
                || p_trx_date_high
                || ''',''DD-MON-YY'')';
        END IF;

        l_step            := l_step + 10;                                 --90

        IF p_bill_to_site IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND rct.bill_to_site_use_id = TO_NUMBER('''
                || p_bill_to_site
                || ''')';
        END IF;

        l_step            := l_step + 10;                                --100

        IF p_cust_num_from IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND bill.customer_number >='''
                || p_cust_num_from
                || '''';
        END IF;

        l_step            := l_step + 10;                                --110

        IF p_cust_num_to IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND bill.customer_number <='''
                || p_cust_num_to
                || '''';
        END IF;

        l_step            := l_step + 10;                                --120

        IF p_re_transmit_flag = 'N'
        THEN
            l_query   := l_query || ' AND rct.printing_pending = ''Y''';
        ELSIF p_re_transmit_flag = 'Y'
        THEN
            l_query   := l_query || ' AND rct.printing_pending = ''N''';
        END IF;

        l_step            := l_step + 10;                                --130
        l_query           := l_query || ')';
        fnd_file.put_line (fnd_file.LOG,
                           '=========================================');
        fnd_file.put_line (fnd_file.LOG, l_query);
        fnd_file.put_line (fnd_file.LOG,
                           '=========================================');

        EXECUTE IMMEDIATE l_query;

        l_step            := l_step + 10;                                --120
        x_return_status   := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status    := 'FAILURE';
            x_return_message   := TO_CHAR (l_step) || ' - ' || SQLERRM;
    END update_print_flag;

    PROCEDURE update_pdf_generated_flag (p_customer_id IN VARCHAR2 DEFAULT NULL, p_trx_class IN VARCHAR2 DEFAULT NULL, p_cust_num IN VARCHAR2 DEFAULT NULL, p_trx_date_low IN VARCHAR2 DEFAULT NULL, p_trx_date_high IN VARCHAR2 DEFAULT NULL, --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                                                                                                                                                                                                               p_creation_date_low IN VARCHAR2 DEFAULT NULL, p_creation_date_high IN VARCHAR2 DEFAULT NULL, --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                                                                                                                                                                                                                                                                                                            p_invoice_num_from IN VARCHAR2 DEFAULT NULL, p_invoice_num_to IN VARCHAR2 DEFAULT NULL, p_org_id IN VARCHAR2 DEFAULT NULL, p_batch_id IN NUMBER DEFAULT NULL, -- Added by Infosys. 12-May-2016.
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          x_return_status OUT VARCHAR2
                                         , x_return_message OUT VARCHAR2)
    IS
        l_query   VARCHAR2 (32767);
        l_step    NUMBER := 0;
    BEGIN
        l_step            := l_step + 10;                                 --10
        l_query           :=
               'UPDATE ra_customer_trx_all rtrx
                     SET global_attribute4 = ''Y''
                   WHERE EXISTS (SELECT 1
                                    FROM   apps.ra_customer_trx_all       rct,
                                           apps.ar_payment_schedules_all  ps,
                                          (SELECT c.cust_account_id            customer_id
                                                 ,u.site_use_id                 site_use_id
                                                 ,c.account_number              customer_number
                                                 ,party.party_name              customer_name
                                                 ,loc.address1                  address1
                                                 ,loc.address2                  address2
                                                 ,loc.address3                  address3
                                                 ,loc.address4                  address4
                                                 ,loc.city                      city
                                                 ,nvl(loc.state, loc.province)  state
                                                 ,loc.postal_code               postal_code
                                                 ,loc.country                   country
                                                 ,terr.territory_short_name     country_name
                                                 ,u.tax_reference               site_tax_reference
                                                 ,party.tax_reference           cust_tax_reference
                                                 ,nvl(u.tax_reference,
                                                      party.tax_reference)      tax_reference
                                                ,c.CUSTOMER_CLASS_CODE
                                                ,party_site.attribute1          inv_trans_method
                                                ,party_site.attribute2          cm_trans_method
                                                ,party_site.attribute3          dm_trans_method
                                            FROM hz_cust_accounts       c
                                                ,hz_parties             party
                                                ,hz_cust_acct_sites_all a
                                                ,hz_party_sites         party_site
                                                ,hz_locations           loc
                                                ,hz_cust_site_uses_all  u
                                                ,apps.fnd_territories_tl  terr
                                            WHERE u.cust_acct_site_id   = a.cust_acct_site_id  -- address_id
                                            AND   a.party_site_id       = party_site.party_site_id
                                            AND   loc.location_id       = party_site.location_id
                                            AND   c.party_id            = party.party_id
                                            AND   loc.country           = terr.territory_code
                                            AND   terr.language         = userenv(''LANG'')
                                           --AND   (c.attribute9 is null or c.attribute9 not in (''01'',''11''))
                                           ) bill,
                                          (SELECT c.cust_account_id            customer_id
                                                 ,u.site_use_id                 site_use_id
                                                 ,c.account_number              customer_number
                                                 ,nvl(a.attribute1,party.party_name)              customer_name
                                                 ,loc.address1                  address1
                                                 ,loc.address2                  address2
                                                 ,loc.address3                  address3
                                                 ,loc.address4                  address4
                                                 ,loc.city                      city
                                                 ,nvl(loc.state, loc.province)  state
                                                 ,loc.postal_code               postal_code
                                                 ,loc.country                   country
                                                 ,terr.territory_short_name     country_name
                                                 ,u.tax_reference               site_tax_reference
                                                 ,party.tax_reference           cust_tax_reference
                                                 ,nvl(u.tax_reference,
                                                      party.tax_reference)      tax_reference
                                            FROM hz_cust_accounts       c
                                                ,hz_parties             party
                                                ,hz_cust_acct_sites_all a
                                                ,hz_party_sites         party_site
                                                ,hz_locations           loc
                                                ,hz_cust_site_uses_all  u
                                                ,apps.fnd_territories_tl  terr
                                            WHERE u.cust_acct_site_id   = a.cust_acct_site_id  -- address_id
                                            AND   a.party_site_id       = party_site.party_site_id
                                            AND   loc.location_id       = party_site.location_id
                                            AND   c.party_id            = party.party_id
                                            AND   loc.country           = terr.territory_code
                                            AND   terr.language         = userenv(''LANG'')
                                           ) ship,
                                           (SELECT acct_site.cust_acct_site_id    address_id
                                                  ,loc.address1                   address1
                                                  ,loc.address2                   address2
                                                  ,loc.address3                   address3
                                                  ,loc.ADDRESS4                   address4
                                                  ,loc.CITY                       city
                                                  ,nvl(loc.STATE,loc.province)    state
                                                  ,loc.POSTAL_CODE                postal_code
                                                  ,loc.COUNTRY                    country
                                                  ,terr.territory_short_name      country_name
                                                  ,party_site.addressee
                                                  ,acct_site.attribute2          contact_number
                                             FROM  hz_cust_acct_sites_all acct_site,
                                                   hz_party_sites party_site,
                                                   hz_locations loc,
                                                   apps.fnd_territories_tl  terr
                                             WHERE acct_site.party_site_id = party_site.party_site_id
                                             AND   loc.location_id = party_site.location_id
                                             AND   loc.country = terr.territory_code
                                             AND   terr.language         = userenv(''LANG'')
                                           ) remit,
                                           (SELECT F.freight_code, description
                                                   FROM   APPS.ORG_FREIGHT F,
                                                          APPS.OE_SYSTEM_PARAMETERS_ALL OSP
                                                   WHERE  F.ORGANIZATION_ID = OSP.MASTER_ORGANIZATION_ID
                                                   AND    OSP.ORG_ID = TO_NUMBER('
            || p_org_id
            || ')) ship_via,
                                           apps.ra_cust_trx_types_all     tt,
                                           apps.ra_batch_sources_all      abc,
                                           apps.ar_lookups                arl,
                                           apps.ra_terms                  term
                                          ,apps.jtf_rs_salesreps          rep
                                    WHERE  rct.bill_to_customer_id  = bill.customer_id
                                    AND    rct.bill_to_site_use_id  = bill.site_use_id
                                    AND    rct.ship_to_customer_id  = ship.customer_id (+)
                                    AND    rct.ship_to_site_use_id  = ship.site_use_id (+)
                                    AND    rct.cust_trx_type_id     = tt.cust_trx_type_id
                                    AND    rct.batch_source_id      = abc.batch_source_id(+)
                                    AND    rct.org_id               = abc.org_id(+)
                                    AND    rct.org_id               = tt.org_id
                                    AND    tt.type                  = arl.lookup_code
                                    AND    arl.lookup_type          = ''INV/CM''
                                    AND    rct.customer_trx_id      = ps.customer_trx_id
                                    AND    rct.term_id              = term.term_id (+)
                                    AND    rct.primary_salesrep_id  = rep.salesrep_id (+)
                                    AND    rct.org_id               = rep.org_id (+)
                                    AND    APPS.XXDO_AR_INVOICE_PRINT.remit_to_address_id (rct.customer_trx_id) = remit.address_id (+)
                                    AND    rct.ship_via             = ship_via.freight_code (+)
                                    AND    rct.printing_option = ''PRI''
                                    AND    ps.number_of_due_dates   = 1
                                    AND   NOT EXISTS (SELECT 1
                                                        FROM fnd_lookup_values flv
                                                       WHERE 1=1
                                                         AND flv.LANGUAGE = userenv(''LANG'')
                                                         AND flv.lookup_type = ''XXDOAR035_EXCLUDED_TRX_TYPES''
                                                         AND flv.meaning = tt.name
                                                         AND flv.description = tt.type
                                                         AND DECODE(sign(sysdate - NVL(flv.start_date_active, sysdate - 1)),
                                                                    -1, ''INACTIVE'',
                                                                     DECODE(sign(NVL(flv.end_date_active,sysdate + 1) - sysdate),
                                                                            -1, ''INACTIVE'',
                                                                            DECODE(flv.enabled_flag,
                                                                                   ''N'',''INACTIVE'',
                                                                                   ''ACTIVE''))) = ''ACTIVE'')
                                    AND    rct.customer_trx_id      = rtrx.customer_trx_id
                                    AND    rct.org_id               = TO_NUMBER('''
            || p_org_id
            || ''')';
        l_step            := l_step + 10;                                 --20

        IF p_invoice_num_from IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND rct.trx_number        >='''
                || p_invoice_num_from
                || '''';
        END IF;

        l_step            := l_step + 10;                                 --30

        IF p_invoice_num_to IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND rct.trx_number        <='''
                || p_invoice_num_to
                || '''';
        END IF;

        l_step            := l_step + 10;                                 --40

        IF p_customer_id IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and rct.bill_to_customer_id   = TO_NUMBER('''
                || p_customer_id
                || ''')';
        END IF;

        l_step            := l_step + 10;                                 --50

        IF p_trx_class IS NOT NULL
        THEN
            l_query   :=
                l_query || ' and tt.type = ''' || p_trx_class || '''';
        END IF;

        l_step            := l_step + 10;                                 --60

        IF p_trx_date_low IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and rct.trx_date >= TO_DATE('''
                || p_trx_date_low                   -- || ''',''DD-MON-YY'')';
                || ''',''RRRR/MM/DD HH24:MI:SS'')'; --Modified by Infosys 16-MAY-2016.
        END IF;

        l_step            := l_step + 10;                                 --70

        IF p_trx_date_high IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and rct.trx_date <= TO_DATE('''
                || p_trx_date_high                 --  || ''',''DD-MON-YY'')';
                || ''',''RRRR/MM/DD HH24:MI:SS'')'; --Modified by Infosys 16-MAY-2016.
        END IF;

        l_step            := l_step + 10;                                 --80

        --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
        IF p_creation_date_low IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and trunc (rct.creation_date) >= TO_DATE('''
                || p_creation_date_low
                || ''',''RRRR/MM/DD HH24:MI:SS'')';
        END IF;

        l_step            := l_step + 4;                                  --84

        IF p_creation_date_high IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and trunc (rct.creation_date) <= TO_DATE('''
                || p_creation_date_high
                || ''',''RRRR/MM/DD HH24:MI:SS'')';
        END IF;

        l_step            := l_step + 4;                                  --88

        --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1

        IF p_cust_num IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND bill.customer_number ='''
                || p_cust_num
                || '''';
        END IF;

        l_step            := l_step + 10;                                 --90


        -- START : Modified by Infosys. 12-May-2016.
        IF p_batch_id IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND rct.customer_trx_id IN (SELECT transaction_id FROM xxd_xxdoar037_ca_invdtl_stg WHERE batch_id = '''
                || p_batch_id
                || ''') ';
        END IF;

        -- END : Modified by Infosys. 12-May-2016.

        l_step            := l_step + 10;                                --100

        l_query           := l_query || ')';
        fnd_file.put_line (fnd_file.LOG,
                           '=========================================');
        fnd_file.put_line (fnd_file.LOG, l_query);
        fnd_file.put_line (fnd_file.LOG,
                           '=========================================');

        EXECUTE IMMEDIATE l_query;

        COMMIT;
        l_step            := l_step + 10;                                --110
        soa_event_update (p_customer_id, p_trx_class, p_cust_num,
                          p_trx_date_low, p_trx_date_high, --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                           p_creation_date_low, p_creation_date_high, --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
                                                                                                      p_invoice_num_from, p_invoice_num_to
                          , p_org_id, p_batch_id -- Added by Infosys. 12-May-2016.
                                                );
        x_return_status   := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status    := 'FAILURE';
            x_return_message   := TO_CHAR (l_step) || ' - ' || SQLERRM;
    END update_pdf_generated_flag;

    PROCEDURE soa_event_update (
        p_customer_id          IN VARCHAR2 DEFAULT NULL,
        p_trx_class            IN VARCHAR2 DEFAULT NULL,
        p_cust_num             IN VARCHAR2 DEFAULT NULL,
        p_trx_date_low         IN VARCHAR2 DEFAULT NULL,
        p_trx_date_high        IN VARCHAR2 DEFAULT NULL,
        --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
        p_creation_date_low    IN VARCHAR2,
        p_creation_date_high   IN VARCHAR2,
        --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
        p_invoice_num_from     IN VARCHAR2 DEFAULT NULL,
        p_invoice_num_to       IN VARCHAR2 DEFAULT NULL,
        p_org_id               IN VARCHAR2 DEFAULT NULL,
        p_batch_id             IN NUMBER DEFAULT NULL -- Added by Infosys. 12-May-2016.
                                                     )
    IS
        g_artrx_update_event   CONSTANT VARCHAR2 (40)
            := 'oracle.apps.xxdo.ar_trx_update' ;
        l_batch_id                      NUMBER;
        l_query                         VARCHAR2 (32767);
        l_step                          NUMBER := 0;
    BEGIN
        --create batch id
        SELECT xxdo.xxdoint_ar_trx_upd_btch_s.NEXTVAL
          INTO l_batch_id
          FROM DUAL;

        l_step    := l_step + 10;                                         --10
        l_query   :=
               'INSERT INTO xxdo.xxdoint_ar_trx_upd_batch
             SELECT '
            || l_batch_id
            || ' , rct.customer_trx_id, SYSDATE
                                    FROM   apps.ra_customer_trx_all       rct,
                                           apps.ar_payment_schedules_all  ps,
                                           apps.ra_cust_trx_types_all     tt,
                                           apps.ar_lookups                arl,
                                           apps.hz_cust_accounts_all      hca
                                    WHERE  rct.cust_trx_type_id     = tt.cust_trx_type_id
                                    AND    rct.org_id               = tt.org_id
                                    AND    tt.type                  = arl.lookup_code
                                    AND    arl.lookup_type          = ''INV/CM''
                                    AND    rct.customer_trx_id      = ps.customer_trx_id
                                    and    hca.cust_account_id = rct.bill_to_customer_id
                                    AND    rct.printing_option = ''PRI''
                                    AND    ps.number_of_due_dates   = 1
                                    AND   NOT EXISTS (SELECT 1
                                                        FROM fnd_lookup_values flv
                                                       WHERE 1=1
                                                         AND flv.LANGUAGE = userenv(''LANG'')
                                                         AND flv.lookup_type = ''XXDOAR035_EXCLUDED_TRX_TYPES''
                                                         AND flv.meaning = tt.name
                                                         AND flv.description = tt.type
                                                         AND DECODE(sign(sysdate - NVL(flv.start_date_active, sysdate - 1)),
                                                                    -1, ''INACTIVE'',
                                                                     DECODE(sign(NVL(flv.end_date_active,sysdate + 1) - sysdate),
                                                                            -1, ''INACTIVE'',
                                                                            DECODE(flv.enabled_flag,
                                                                                   ''N'',''INACTIVE'',
                                                                                   ''ACTIVE''))) = ''ACTIVE'')
                                    AND    rct.org_id               = TO_NUMBER('''
            || p_org_id
            || ''')';
        l_step    := l_step + 10;                                         --20

        IF p_invoice_num_from IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND rct.trx_number        >='''
                || p_invoice_num_from
                || '''';
        END IF;

        l_step    := l_step + 10;                                         --30

        IF p_invoice_num_to IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND rct.trx_number        <='''
                || p_invoice_num_to
                || '''';
        END IF;

        l_step    := l_step + 10;                                         --40

        IF p_customer_id IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and rct.bill_to_customer_id   = TO_NUMBER('''
                || p_customer_id
                || ''')';
        END IF;

        l_step    := l_step + 10;                                         --50

        IF p_trx_class IS NOT NULL
        THEN
            l_query   :=
                l_query || ' and tt.type = ''' || p_trx_class || '''';
        END IF;

        l_step    := l_step + 10;                                         --60

        IF p_trx_date_low IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and rct.trx_date >= TO_DATE('''
                || p_trx_date_low                   -- || ''',''DD-MON-YY'')';
                || ''',''RRRR/MM/DD HH24:MI:SS'')'; --Modified by Infosys 16-MAY-2016.
        END IF;

        l_step    := l_step + 10;                                         --70

        IF p_trx_date_high IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and rct.trx_date <= TO_DATE('''
                || p_trx_date_high                  -- || ''',''DD-MON-YY'')';
                || ''',''RRRR/MM/DD HH24:MI:SS'')'; --Modified by Infosys 16-MAY-2016.
        END IF;

        l_step    := l_step + 10;                                         --80

        --Start changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1
        IF p_creation_date_low IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and trunc (rct.creation_date) >= TO_DATE('''
                || p_creation_date_low
                || ''',''RRRR/MM/DD HH24:MI:SS'')';
        END IF;

        l_step    := l_step + 4;                                          --84

        IF p_creation_date_high IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' and trunc (rct.creation_date) <= TO_DATE('''
                || p_creation_date_high
                || ''',''RRRR/MM/DD HH24:MI:SS'')';
        END IF;

        l_step    := l_step + 4;                                          --88

        --End changes by BT Technology Team for INC0305730 on 01-Aug-2016,  v2.1

        IF p_cust_num IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND hca.account_number ='''
                || p_cust_num
                || '''';
        END IF;

        l_step    := l_step + 10;                                         --90

        -- START : Modified by Infosys. 12-May-2016.
        IF p_batch_id IS NOT NULL
        THEN
            l_query   :=
                   l_query
                || ' AND rct.customer_trx_id IN (SELECT transaction_id FROM xxd_xxdoar037_ca_invdtl_stg WHERE batch_id = '''
                || p_batch_id
                || ''') ';
        END IF;

        -- END : Modified by Infosys. 12-May-2016.

        --l_query := l_query||')';
        fnd_file.put_line (fnd_file.LOG,
                           '=========================================');
        fnd_file.put_line (fnd_file.LOG, l_query);
        fnd_file.put_line (fnd_file.LOG,
                           '=========================================');

        EXECUTE IMMEDIATE l_query;

        apps.wf_event.RAISE (p_event_name => g_artrx_update_event, p_event_key => TO_CHAR (l_batch_id), p_event_data => NULL
                             , p_parameters => NULL);
    END soa_event_update;
END XXDO_AR_INVOICE_PRINT_CA;
/
