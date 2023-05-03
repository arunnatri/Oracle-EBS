--
-- XXD_AR_MTD_REPORT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_MTD_REPORT_PKG"
AS
    /****************************************************************************************
     * Package      : XXD_MTD_REPORTD_PKG
     * Design       : This package will be used for MTD Reports
     * Notes        :
     * Modification :
     -- ======================================================================================
     -- Date         Version#   Name                    Comments
     -- ======================================================================================
     -- 14-Aug-2020  1.0        Tejaswi Gangumalla      Initial Version
     -- 14-DEC-2020  2.0        Srinath Siricilla       CCR0009071
     -- 01-MAR-2020  3.0        Satyanarayana Kotha     CCR0009103
     -- 08-Oct-2021  4.0        Srinath Siricilla       Modified for CCR0009638
     -- 01-AUG-2022  4.1        Srinath Siricilla       CCR0009857
    ******************************************************************************************/
    -- Start of Change CCR0009071

    FUNCTION get_orig_wh (pn_org_id IN NUMBER, pv_attr_context IN VARCHAR2, pn_so_num IN VARCHAR2
                          , pn_line_id IN VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_org_id        NUMBER;
        ln_header_id     NUMBER;
        ln_ref_line_id   NUMBER;
        lv_wh_name       VARCHAR2 (100);
    BEGIN
        ln_org_id        := NULL;
        ln_header_id     := NULL;
        ln_ref_line_id   := NULL;
        lv_wh_name       := NULL;

        IF pv_attr_context = 'ORDER ENTRY'
        THEN
            BEGIN
                SELECT organization_id
                  INTO ln_org_id
                  FROM hr_all_organization_units hou
                 WHERE     organization_id = pn_org_id
                       AND TYPE = 'ECOMM'
                       AND SYSDATE BETWEEN NVL (date_from, SYSDATE)
                                       AND NVL (date_to, SYSDATE + 1)
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
                                       AND hou.NAME = ffv.flex_value);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_org_id   := NULL;
            END;

            IF ln_org_id IS NOT NULL
            THEN
                BEGIN
                    SELECT header_id
                      INTO ln_header_id
                      FROM oe_order_headers_all ooha
                     WHERE org_id = pn_org_id AND order_number = pn_so_num;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_header_id   := NULL;
                END;

                IF ln_header_id IS NOT NULL
                THEN
                    BEGIN
                        SELECT reference_line_id
                          INTO ln_ref_line_id
                          FROM oe_order_lines_all oola
                         WHERE     header_id = ln_header_id
                               AND line_id = pn_line_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_ref_line_id   := NULL;
                    END;

                    IF ln_ref_line_id IS NOT NULL
                    THEN
                        BEGIN
                            SELECT NAME
                              INTO lv_wh_name
                              FROM apps.hr_all_organization_units_tl wh_name, oe_order_lines_all oola
                             WHERE     1 = 1
                                   AND wh_name.LANGUAGE(+) = USERENV ('LANG')
                                   AND wh_name.organization_id(+) =
                                       oola.ship_from_org_id
                                   AND oola.line_id = ln_ref_line_id;

                            RETURN lv_wh_name;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_wh_name   := NULL;
                                RETURN NULL;
                        END;
                    ELSE
                        RETURN NULL;
                    END IF;
                ELSE
                    RETURN NULL;
                END IF;
            ELSE
                RETURN NULL;
            END IF;
        ELSE
            RETURN NULL;
        END IF;
    END get_orig_wh;

    -- END of Change

    -- Start of Change for CCR0009638
    FUNCTION remove_junk (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), '')
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
    END remove_junk;

    PROCEDURE insert_into_tbl_prc (pv_operating_unit IN VARCHAR2, pv_company_code IN VARCHAR2, pd_invoice_date_from IN DATE, pd_invoice_date_to IN DATE, pd_gl_posted_from IN DATE, pd_gl_posted_to IN DATE
                                   , pv_tax_regime_code IN VARCHAR2, pv_tax_code IN VARCHAR2, pv_account IN VARCHAR2)
    IS
        CURSOR cur_get_adjustments IS
            SELECT /*+ index(AAA AR_ADJUSTMENTS_N7)*/
                   hou.name
                       organization_name,
                   aaa.adjustment_number
                       invoice_number,
                   ''
                       order_type,
                   rt.bill_to_customer_id,
                   rt.bill_to_site_use_id,
                   rt.ship_to_site_use_id,
                   aaa.creation_date
                       invoice_date,
                   TO_NUMBER ('')
                       to_gbp_exchg_rt_corp,
                   TO_NUMBER ('')
                       to_eur_exchg_rt_corp,
                   TO_NUMBER ('')
                       to_usd_exchg_rt_corp,
                   (SELECT wh_name.NAME
                      FROM apps.hr_all_organization_units_tl wh_name
                     WHERE     wh_name.LANGUAGE = USERENV ('LANG')
                           AND wh_name.organization_id =
                               (SELECT warehouse_id
                                  FROM apps.ra_customer_trx_lines_all
                                 WHERE     customer_trx_id =
                                           rt.customer_trx_id
                                       AND warehouse_id IS NOT NULL
                                       AND ROWNUM = 1))
                       warehouse_name,
                   NULL
                       vat_number,
                   aaa.amount
                       invoiced_qty,
                   (SELECT glc.concatenated_segments
                      FROM ra_cust_trx_line_gl_dist_all gl_dist_tax, apps.gl_code_combinations_kfv glc
                     WHERE     gl_dist_tax.customer_trx_line_id IN
                                   (SELECT rtl1.customer_trx_line_id
                                      FROM apps.ra_customer_trx_lines_all rtl1
                                     WHERE     customer_trx_id =
                                               rt.customer_trx_id
                                           AND line_type = 'TAX')
                           AND gl_dist_tax.code_combination_id =
                               glc.code_combination_id
                           AND ROWNUM = 1)
                       gl_tax_account,
                   ''
                       tax_rate_code,
                   ''
                       tax_regime_code,
                   TO_NUMBER ('')
                       invoice_total,
                   TO_NUMBER ('')
                       inventory_item_id,
                   ''
                       style,
                   ''
                       color,
                   ''
                       commodity_code,
                   ''
                       division,
                   ''
                       department,
                   aaa.amount
                       pre_conv_inv_amt,
                   aaa.tax_adjusted
                       pre_conv_tax_amt,
                   rt.invoice_currency_code,
                   artx.NAME
                       description,
                   (SELECT segment1
                      FROM gl_code_combinations
                     WHERE code_combination_id = aaa.code_combination_id)
                       gl_entity_code,
                   al.meaning
                       document_class,
                   aaa.reason_code
                       reason_code,
                   NULL
                       warehouse_id,
                   TO_NUMBER ('')
                       line_number,
                   aaa.gl_date,
                   (SELECT period_name
                      FROM gl_periods
                     WHERE     aaa.gl_date BETWEEN start_date AND end_date
                           AND period_set_name = 'DO_FY_CALENDAR')
                       gl_period,
                   gcc.concatenated_segments
                       gl_account,
                   (SELECT apps.gl_flexfields_pkg.get_concat_description (glc.chart_of_accounts_id, glc.code_combination_id)
                      FROM apps.gl_code_combinations_kfv glc
                     WHERE aaa.code_combination_id = glc.code_combination_id)
                       gl_account_desc,
                   gcc.segment3
                       gl_geo_code,
                   NULL
                       gl_country_desc,
                   rt.trx_number
                       reference_number,
                   NULL
                       orig_wh_name,
                   NULL
                       ship_postal_code,
                   -- Added as per CCR0009103
                   TO_NUMBER ('')
                       tax_rate,
                   hou.organization_id
                       org_id,
                   hou.name
                       org_name,
                   aaa.adjustment_id
                       trx_id,
                   rt.trx_date
                       adj_trx_date,
                   rt.interface_header_attribute14
                       gapless_sequence_number      -- Added as per CCR0009857
              -- Added as per CCR0009103
              FROM apps.ar_adjustments_all aaa, apps.ar_receivables_trx_all artx, apps.ra_customer_trx_all rt,
                   apps.ra_cust_trx_types_all rtt, apps.ar_lookups al, apps.gl_code_combinations_kfv gcc,
                   fnd_flex_value_sets ffvs, fnd_flex_values ffv, apps.hr_operating_units hou
             WHERE     aaa.org_id = hou.organization_id
                   AND rt.customer_trx_id = aaa.customer_trx_id
                   AND gcc.code_combination_id = aaa.code_combination_id
                   AND rt.cust_trx_type_id = rtt.cust_trx_type_id
                   AND rt.org_id = rtt.org_id
                   AND al.lookup_type = 'INV/CM'
                   AND al.lookup_code = rtt.TYPE
                   AND al.lookup_type = 'INV/CM'
                   AND al.lookup_code = rtt.TYPE
                   AND aaa.status <> 'R'
                   AND aaa.TYPE = 'LINE'
                   AND artx.receivables_trx_id = aaa.receivables_trx_id
                   AND aaa.org_id = artx.org_id
                   AND artx.receivables_trx_id <> -15
                   AND aaa.creation_date BETWEEN pd_invoice_date_from
                                             AND pd_invoice_date_to
                   AND aaa.gl_date BETWEEN NVL (pd_gl_posted_from,
                                                aaa.gl_date)
                                       AND NVL (pd_gl_posted_to, aaa.gl_date)
                   AND gcc.segment1 = NVL (pv_company_code, gcc.segment1)
                   AND gcc.segment6 = NVL (pv_account, gcc.segment6)
                   AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                   AND flex_value_set_name = 'XXD_AR_MTD_OU_VS'
                   AND ffv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (ffv.start_date_active,
                                                    TRUNC (SYSDATE))
                                           AND NVL (ffv.end_date_active,
                                                    TRUNC (SYSDATE))
                   AND ffv.flex_value <> 'ALL EMEA'
                   AND hou.NAME = ffv.flex_value
                   AND hou.NAME =
                       DECODE (pv_operating_unit,
                               'ALL EMEA', ffv.flex_value,
                               pv_operating_unit);

        CURSOR get_adj_upd IS
              SELECT xx.trx_id, xx.invoice_number, tax_line.tax_rate_code,
                     tax_line.tax_regime_code, xx.org_id
                FROM xxdo.xxd_ar_vat_rpt_t xx, zx_lines tax_line
               WHERE     source_trxn = 'ADJUSTMENT'
                     AND xx.trx_id = tax_line.trx_id
                     AND xx.org_id = tax_line.internal_organization_id
                     AND (tax_line.tax_rate_code IS NOT NULL OR tax_line.tax_regime_code IS NOT NULL)
            GROUP BY xx.trx_id, xx.invoice_number, tax_line.tax_rate_code,
                     tax_line.tax_regime_code, xx.org_id;

        TYPE t_adjustments IS TABLE OF cur_get_adjustments%ROWTYPE;

        rec_adjustments      t_adjustments;

        --        TYPE t_transactions IS TABLE OF cur_get_transactions%ROWTYPE;
        --
        --        rec_transactions   t_transactions;

        lv_tax_code          VARCHAR2 (100);
        lv_tax_regime_code   VARCHAR2 (100);

        lv_bulk_limit        NUMBER := 1000;
    BEGIN
        lv_tax_code          := NULL;
        lv_tax_regime_code   := NULL;

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ar_vat_rpt_t';

        fnd_file.put_line (
            fnd_file.LOG,
               'Adjustment Extract - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        OPEN cur_get_adjustments;

        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'Adjustment Extract - Start Time :'
                || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

            FETCH cur_get_adjustments
                BULK COLLECT INTO rec_adjustments
                LIMIT lv_bulk_limit;

            BEGIN
                FORALL i IN 1 .. rec_adjustments.COUNT
                    INSERT INTO xxdo.xxd_ar_vat_rpt_t (
                                    source_trxn --                                                ,transaction_type
                                               ,
                                    invoice_number,
                                    order_type,
                                    bill_to_customer_id,
                                    bill_to_site_use_id,
                                    ship_to_site_use_id,
                                    invoice_currency_code,
                                    trx_date,
                                    to_gbp_exchg_rt_corp,
                                    to_eur_exchg_rt_corp,
                                    to_usd_exchg_rt_corp,
                                    warehouse_name,
                                    vat_number,
                                    invoiced_qty,
                                    GL_TAX_ACCOUNT,
                                    tax_rate_code,
                                    tax_regime_code,
                                    invoice_total,
                                    inventory_item_id,
                                    style,
                                    color,
                                    commodity_code,
                                    division,
                                    department,
                                    pre_conv_inv_amt,
                                    pre_conv_tax_amt,
                                    description,
                                    gl_entity_code,
                                    document_class,
                                    reason_code,
                                    warehouse_id,
                                    line_number,
                                    gl_date,
                                    gl_account,
                                    gl_account_desc,
                                    gl_geo_code,
                                    reference_number,
                                    orig_wh_name,
                                    tax_rate,
                                    org_id,
                                    org_name,
                                    customer_number,
                                    sell_to_customer_name,
                                    bill_vat_number,
                                    ship_vat_number,
                                    invoice_date,
                                    ship_to_city,
                                    ship_to_state,
                                    Ship_to_country,
                                    ship_to_postal_code,
                                    bill_to_country,
                                    ship_from_country,
                                    gl_period,
                                    gl_country_desc,
                                    trx_id,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    request_id,
                                    adj_trx_date,
                                    gapless_sequence_number -- Added as per CCR0009857
                                                           )
                             VALUES (
                                        'ADJUSTMENT' --                                                ,rec_adjustments(i).transaction_type
                                                    ,
                                        rec_adjustments (i).invoice_number,
                                        rec_adjustments (i).order_type,
                                        rec_adjustments (i).bill_to_customer_id,
                                        rec_adjustments (i).bill_to_site_use_id,
                                        rec_adjustments (i).ship_to_site_use_id,
                                        rec_adjustments (i).invoice_currency_code,
                                        rec_adjustments (i).invoice_date,
                                        rec_adjustments (i).to_gbp_exchg_rt_corp,
                                        rec_adjustments (i).to_eur_exchg_rt_corp,
                                        rec_adjustments (i).to_usd_exchg_rt_corp,
                                        rec_adjustments (i).warehouse_name,
                                        rec_adjustments (i).VAT_NUMBER,
                                        rec_adjustments (i).invoiced_qty,
                                        rec_adjustments (i).GL_TAX_ACCOUNT,
                                        rec_adjustments (i).tax_rate_code,
                                        rec_adjustments (i).tax_regime_code,
                                        rec_adjustments (i).invoice_total,
                                        rec_adjustments (i).inventory_item_id,
                                        rec_adjustments (i).style,
                                        rec_adjustments (i).color,
                                        rec_adjustments (i).commodity_code,
                                        rec_adjustments (i).division,
                                        rec_adjustments (i).department,
                                        rec_adjustments (i).pre_conv_inv_amt,
                                        rec_adjustments (i).pre_conv_tax_amt,
                                        rec_adjustments (i).description,
                                        rec_adjustments (i).gl_entity_code,
                                        rec_adjustments (i).document_class,
                                        rec_adjustments (i).reason_code,
                                        rec_adjustments (i).warehouse_id,
                                        rec_adjustments (i).line_number,
                                        rec_adjustments (i).gl_date,
                                        rec_adjustments (i).gl_account,
                                        rec_adjustments (i).gl_account_desc,
                                        rec_adjustments (i).gl_geo_code,
                                        rec_adjustments (i).reference_number,
                                        rec_adjustments (i).orig_wh_name,
                                        rec_adjustments (i).tax_rate,
                                        rec_adjustments (i).org_id,
                                        rec_adjustments (i).org_name,
                                        NULL --,rec_adjustments(i).customer_number
                                            ,
                                        NULL --,rec_adjustments(i).sell_to_customer_name
                                            ,
                                        NULL --,rec_adjustments(i).bill_vat_number
                                            ,
                                        NULL --,rec_adjustments(i).ship_vat_number
                                            ,
                                        rec_adjustments (i).invoice_date,
                                        NULL --,rec_adjustments(i).ship_to_city
                                            ,
                                        NULL --,rec_adjustments(i).ship_to_state
                                            ,
                                        NULL --,rec_adjustments(i).Ship_to_country
                                            ,
                                        NULL --,rec_adjustments(i).ship_to_postal_code
                                            ,
                                        NULL --,rec_adjustments(i).bill_to_country
                                            ,
                                        NULL --,rec_adjustments(i).ship_from_country
                                            ,
                                        rec_adjustments (i).gl_period,
                                        rec_adjustments (i).gl_country_desc,
                                        rec_adjustments (i).trx_id,
                                        SYSDATE,
                                        gn_user_id,
                                        SYSDATE,
                                        gn_user_id,
                                        gn_request_id,
                                        rec_adjustments (i).adj_trx_date,
                                        rec_adjustments (i).gapless_sequence_number -- -- Added as per CCR0009857
                                                                                   );
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'insertion failed for  Table' || SQLERRM);
            END;


            EXIT WHEN rec_adjustments.COUNT = 0;
        END LOOP;

        COMMIT;

        FOR i IN get_adj_upd
        LOOP
            BEGIN
                UPDATE xxdo.xxd_ar_vat_rpt_t
                   SET tax_rate_code = i.tax_rate_code, tax_regime_code = i.tax_regime_code
                 WHERE     1 = 1
                       AND org_id = i.org_id
                       AND source_trxn = 'ADJUSTMENT'
                       AND trx_id = i.trx_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;

        COMMIT;

        BEGIN
            UPDATE xxdo.xxd_ar_vat_rpt_t xvc
               SET to_eur_exchg_rt_corp   =
                       NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency =
                                       xvc.invoice_currency_code
                                   AND to_currency = 'EUR'
                                   AND conversion_date =
                                       TRUNC (xvc.adj_trx_date)),
                           1),
                   to_GBP_exchg_rt_corp   =
                       NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency =
                                       xvc.invoice_currency_code
                                   AND to_currency = 'GBP'
                                   AND conversion_date =
                                       TRUNC (xvc.adj_trx_date)),
                           1),
                   to_USD_exchg_rt_corp   =
                       NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency =
                                       xvc.invoice_currency_code
                                   AND to_currency = 'USD'
                                   AND conversion_date =
                                       TRUNC (xvc.adj_trx_date)),
                           1)
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND source_trxn = 'ADJUSTMENT';
        --          AND vt_source = 'Material';

        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
               'END Adjustment Extract - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        INSERT /*+ APPEND */
               INTO xxdo.xxd_ar_vat_rpt_t (org_name, invoice_number, order_type, bill_to_customer_id, bill_to_site_use_id, ship_to_site_use_id, invoice_currency_code, trx_date, to_gbp_exchg_rt_corp, to_eur_exchg_rt_corp, to_usd_exchg_rt_corp, warehouse_name, vat_number, invoiced_qty, gl_tax_account, tax_rate_code, tax_regime_code, invoice_total, inventory_item_id, style, color, commodity_code, division, department, pre_conv_inv_amt, pre_conv_tax_amt, description, gl_entity_code, document_class, reason_code, warehouse_id, line_number, gl_date, gl_period, gl_account, gl_account_desc, gl_geo_code, gl_country_desc, reference_number, orig_wh_name, --ship_postal_code,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           tax_rate, org_id, trx_id, trx_line_id, source_trxn
                                           , gapless_sequence_number -- Added as per CCR0009857
                                                                    )
              SELECT /*+ index(RT RA_CUSTOMER_TRX_N5)*/
                                                      --/*+ PARALLEL(rt, 8) */
                     hou.NAME
                         organization_name,
                     rt.trx_number
                         invoice_number,
                     (SELECT ottl.NAME
                        FROM apps.oe_order_headers_all ooha, apps.oe_transaction_types_tl ottl
                       WHERE     ooha.order_type_id = ottl.transaction_type_id
                             AND ooha.order_number = rtl.sales_order
                             AND ottl.LANGUAGE = USERENV ('LANG'))
                         order_type,
                     rt.bill_to_customer_id,
                     rt.bill_to_site_use_id,
                     rt.ship_to_site_use_id,
                     rt.invoice_currency_code,
                     rt.trx_date,
                     NULL
                         to_gbp_exchg_rt_corp,
                     NULL
                         to_eur_exchg_rt_corp,
                     NULL
                         to_usd_exchg_rt_corp,
                     (SELECT NAME
                        FROM apps.hr_all_organization_units_tl
                       WHERE     organization_id = rtl.warehouse_id
                             AND language = USERENV ('LANG'))
                         warehouse_name,
                     NULL
                         vat_number,
                     SUM (
                         DECODE (
                             rtl.line_type,
                             'LINE', DECODE (
                                         NVL (rtl.interface_line_attribute11, 0),
                                         0, NVL (quantity_invoiced,
                                                 NVL (rtl.quantity_credited, 0)))))
                         AS invoiced_qty,
                     (SELECT glc.concatenated_segments
                        FROM ra_cust_trx_line_gl_dist_all gl_dist_tax, apps.gl_code_combinations_kfv glc
                       WHERE     gl_dist_tax.customer_trx_line_id IN
                                     (SELECT rtl1.customer_trx_line_id
                                        FROM apps.ra_customer_trx_lines_all rtl1
                                       WHERE     customer_trx_id = rt.customer_trx_id
                                             AND rtl1.link_to_cust_trx_line_id =
                                                 rtl.customer_trx_line_id)
                             AND gl_dist_tax.code_combination_id =
                                 glc.code_combination_id
                             AND ROWNUM = 1)
                         gl_tax_account,
                     ''
                         tax_rate_code,
                     ''
                         tax_regime_code,
                     SUM (NVL (gl_dist.amount, 0) * NVL (rt.exchange_rate, 1))
                         AS invoice_total,
                     rtl.inventory_item_id,
                     NULL
                         style,
                     NULL
                         color,
                     NULL
                         commodity_code,
                     NULL
                         division,
                     NULL
                         department,
                     SUM (NVL (gl_dist.amount, 0))
                         pre_conv_inv_amt,
                     (SELECT SUM (tax_amt)
                        FROM apps.zx_lines
                       WHERE     trx_id = rt.customer_trx_id
                             AND trx_line_id = rtl.customer_trx_line_id
                             AND application_id = 222)
                         pre_conv_tax_amt,
                     rtl.description,
                     glc.segment1
                         gl_entity_code,
                     al.meaning
                         document_class,
                     rtl.reason_code,
                     rtl.warehouse_id,
                     rtl.line_number,
                     gl_dist.gl_date,
                     (SELECT period_name
                        FROM gl_periods
                       WHERE     gl_dist.gl_date BETWEEN start_date AND end_date
                             AND period_set_name = 'DO_FY_CALENDAR')
                         gl_period,
                     glc.concatenated_segments
                         gl_account,
                     (SELECT apps.gl_flexfields_pkg.get_concat_description (glc.chart_of_accounts_id, glc.code_combination_id) FROM DUAL)
                         gl_account_desc,
                     glc.segment3
                         gl_geo_code,
                     NULL
                         gl_country_desc,
                     (SELECT rct.trx_number
                        FROM apps.ar_receivable_applications_all ara, apps.ra_customer_trx_all rct
                       WHERE     rct.customer_trx_id = ara.applied_customer_trx_id
                             --AND ara.customer_trx_id(+) = rt.customer_trx_id
                             AND ara.customer_trx_id = rt.customer_trx_id
                             AND ROWNUM = 1)
                         reference_number,
                     NULL
                         orig_wh_name,
                     --                     NULL
                     --                         ship_postal_code,
                     (SELECT tax_rate
                        FROM apps.zx_lines
                       WHERE     trx_id = rt.customer_trx_id
                             AND trx_line_id = rtl.customer_trx_line_id
                             AND application_id = 222
                             AND ROWNUM = 1)
                         tax_rate,
                     hou.organization_id
                         org_id,
                     --                     hou.name
                     --                         org_name,
                     rt.customer_trx_id
                         trx_id,
                     rtl.customer_trx_line_id
                         trx_line_id,
                     'TRANSACTION',
                     rt.interface_header_attribute14 -- Added as per CCR0009857
                -- Added as per CCR0009103
                FROM apps.ra_customer_trx_all rt, apps.ra_customer_trx_lines_all rtl, apps.ra_cust_trx_line_gl_dist_all gl_dist,
                     apps.hr_operating_units hou, apps.ra_batch_sources_all rbs, apps.gl_code_combinations_kfv glc,
                     apps.ar_lookups al, apps.ra_cust_trx_types_all rctt, fnd_flex_value_sets ffvs,
                     fnd_flex_values ffv
               WHERE     rt.customer_trx_id = rtl.customer_trx_id
                     AND gl_dist.customer_trx_line_id = rtl.customer_trx_line_id
                     AND NVL (rt.complete_flag, 'N') = 'Y'
                     AND gl_dist.code_combination_id = glc.code_combination_id
                     AND rtl.line_type IN ('LINE', 'FREIGHT', 'CHARGES')
                     AND gl_dist.account_class IN ('REV', 'FREIGHT')
                     AND gl_dist.account_set_flag = 'N'
                     AND rt.cust_trx_type_id = rctt.cust_trx_type_id
                     AND rt.org_id = rctt.org_id
                     AND al.lookup_type = 'INV/CM'
                     AND al.lookup_code = rctt.TYPE
                     AND gl_dist.org_id = rtl.org_id
                     AND rt.org_id = hou.organization_id
                     AND rbs.batch_source_id = rt.batch_source_id
                     AND rbs.NAME <> 'Trade Management'
                     AND rbs.org_id = rt.org_id
                     AND glc.segment1 = NVL (pv_company_code, glc.segment1)
                     AND glc.segment6 = NVL (pv_account, glc.segment6)
                     AND gl_dist.gl_date BETWEEN NVL (pd_gl_posted_from,
                                                      gl_dist.gl_date)
                                             AND NVL (pd_gl_posted_to,
                                                      gl_dist.gl_date)
                     AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                     AND flex_value_set_name = 'XXD_AR_MTD_OU_VS'
                     AND ffv.enabled_flag = 'Y'
                     AND TRUNC (SYSDATE) BETWEEN NVL (ffv.start_date_active,
                                                      TRUNC (SYSDATE))
                                             AND NVL (ffv.end_date_active,
                                                      TRUNC (SYSDATE))
                     AND ffv.flex_value <> 'ALL EMEA'
                     AND hou.NAME = ffv.flex_value
                     AND hou.NAME =
                         DECODE (pv_operating_unit,
                                 'ALL EMEA', ffv.flex_value,
                                 pv_operating_unit)
                     AND rt.trx_date BETWEEN pd_invoice_date_from
                                         AND pd_invoice_date_to
            GROUP BY hou.NAME, rt.trx_number, rtl.sales_order,
                     --hl_ship.country,
                     rtl.line_number, glc.concatenated_segments, rt.trx_date,
                     rt.invoice_currency_code, rt.exchange_rate, al.meaning,
                     gl_dist.gl_date, rtl.reason_code, glc.chart_of_accounts_id,
                     glc.code_combination_id, rt.customer_trx_id, rtl.customer_trx_line_id,
                     rtl.interface_line_attribute6, rtl.org_id, rtl.inventory_item_id,
                     rtl.description, gl_dist.cust_trx_line_gl_dist_id, rt.set_of_books_id,
                     gl_dist.code_combination_id, rt.bill_to_customer_id, glc.segment1,
                     glc.segment3, rtl.warehouse_id, -- Added as per CCR0009071
                                                     rt.interface_header_attribute1,
                     rt.interface_header_context, rctt.TYPE, -- Added as per CCR0009103
                                                             tax_rate, -- Added as per CCR0009103
                     -- End of Change
                     rt.ship_to_site_use_id,                             -- sh
                                             rt.bill_to_site_use_id, hou.organization_id,
                     rt.interface_header_attribute14 -- Added as per CCR0009857
            UNION ALL
              SELECT /*+ index(RT RA_CUSTOMER_TRX_N5)*/
                     --/*+ PARALLEL(rt, 8) */
                     hou.NAME
                         organization_name,
                     rt.trx_number
                         invoice_number,
                     (SELECT ottl.NAME
                        FROM apps.oe_order_headers_all ooha, apps.oe_transaction_types_tl ottl
                       WHERE     ooha.order_type_id = ottl.transaction_type_id
                             AND ooha.order_number = rtl.sales_order
                             AND ottl.LANGUAGE = USERENV ('LANG'))
                         order_type,
                     rt.bill_to_customer_id,
                     rt.bill_to_site_use_id,
                     rt.ship_to_site_use_id,
                     rt.invoice_currency_code,
                     rt.trx_date,
                     NULL
                         to_gbp_exchg_rt_corp,
                     NULL
                         to_eur_exchg_rt_corp,
                     NULL
                         to_usd_exchg_rt_corp,
                     (SELECT NAME
                        FROM apps.hr_all_organization_units_tl
                       WHERE     organization_id = rtl.warehouse_id
                             AND language = USERENV ('LANG'))
                         warehouse_name,
                     NULL
                         vat_number,
                     SUM (
                         DECODE (
                             rtl.line_type,
                             'LINE', DECODE (
                                         NVL (rtl.interface_line_attribute11,
                                              0),
                                         0, NVL (
                                                quantity_invoiced,
                                                NVL (rtl.quantity_credited, 0))),
                             0))
                         AS invoiced_qty,
                     --   glc.concatenated_segments ACCOUNT,--Commneted for CCR CCR0009103
                     (SELECT glc.concatenated_segments
                        FROM ra_cust_trx_line_gl_dist_all gl_dist_tax, apps.gl_code_combinations_kfv glc
                       WHERE     gl_dist_tax.customer_trx_line_id IN
                                     (SELECT rtl1.customer_trx_line_id
                                        FROM apps.ra_customer_trx_lines_all rtl1
                                       WHERE     customer_trx_id =
                                                 rt.customer_trx_id
                                             AND rtl1.link_to_cust_trx_line_id =
                                                 rtl.customer_trx_line_id)
                             AND gl_dist_tax.code_combination_id =
                                 glc.code_combination_id
                             AND ROWNUM = 1)
                         gl_tax_ACCOUNT,
                     ''
                         tax_rate_code,
                     ''
                         tax_regime_code,
                     SUM (NVL (gl_dist.amount, 0) * NVL (rt.exchange_rate, 1))
                         AS invoice_total,
                     rtl.inventory_item_id,
                     NULL
                         style,
                     NULL
                         color,
                     NULL
                         commodity_code,
                     NULL
                         division,
                     NULL
                         department,
                     SUM (NVL (gl_dist.amount, 0))
                         pre_conv_inv_amt,
                     (SELECT SUM (tax_amt)
                        FROM apps.zx_lines
                       WHERE     trx_id = rt.customer_trx_id
                             AND trx_line_id = rtl.customer_trx_line_id
                             AND application_id = 222)
                         pre_conv_tax_amt,
                     rtl.description,
                     glc.segment1
                         gl_entity_code,
                     al.meaning
                         document_class,
                     rtl.reason_code,
                     rtl.warehouse_id,
                     rtl.line_number,
                     gl_dist.gl_date,
                     (SELECT period_name
                        FROM gl_periods
                       WHERE     gl_dist.gl_date BETWEEN start_date
                                                     AND end_date
                             AND period_set_name = 'DO_FY_CALENDAR')
                         gl_period,
                     glc.concatenated_segments
                         gl_account,
                     (SELECT apps.gl_flexfields_pkg.get_concat_description (glc.chart_of_accounts_id, glc.code_combination_id) FROM DUAL)
                         gl_account_desc,
                     glc.segment3
                         gl_geo_code,
                     NULL
                         gl_country_desc,
                     (SELECT rct.trx_number
                        FROM apps.ar_receivable_applications_all ara, apps.ra_customer_trx_all rct
                       WHERE     rct.customer_trx_id =
                                 ara.applied_customer_trx_id
                             AND ara.customer_trx_id = rt.customer_trx_id
                             AND ROWNUM = 1)
                         reference_number,
                     NULL
                         orig_wh_name,
                     -- Added as per CCR0009071
                     --                                    hl_ship.postal_code ship_postal_code,
                     -- Added as per CCR0009103
                     --                     NULL
                     --                         ship_postal_code,
                     (SELECT tax_rate
                        FROM apps.zx_lines
                       WHERE     trx_id = rt.customer_trx_id
                             AND trx_line_id = rtl.customer_trx_line_id
                             AND application_id = 222
                             AND ROWNUM = 1)
                         tax_rate,
                     hou.organization_id
                         org_id,
                     --                     hou.name
                     --                         org_name,
                     rt.customer_trx_id
                         trx_id,
                     rtl.customer_trx_line_id
                         trx_line_id,
                     'TRANSACTION',
                     rt.interface_header_attribute14 -- Added as per CCR0009857
                -- Added as per CCR0009103
                FROM apps.ra_customer_trx_all rt, apps.ra_customer_trx_lines_all rtl, apps.ra_cust_trx_line_gl_dist_all gl_dist,
                     apps.hr_operating_units hou, apps.ra_batch_sources_all rbs, apps.gl_code_combinations_kfv glc,
                     apps.ar_lookups al, apps.ra_cust_trx_types_all rctt, fnd_flex_value_sets ffvs,
                     fnd_flex_values ffv
               WHERE     rt.customer_trx_id = rtl.customer_trx_id
                     AND gl_dist.customer_trx_id = rt.customer_trx_id
                     AND NVL (rt.complete_flag, 'N') = 'Y'
                     AND gl_dist.customer_trx_line_id =
                         rtl.customer_trx_line_id
                     AND rtl.line_type IN ('LINE', 'FREIGHT', 'CHARGES')
                     AND rt.cust_trx_type_id = rctt.cust_trx_type_id
                     AND rt.org_id = rctt.org_id
                     AND al.lookup_type = 'INV/CM'
                     AND al.lookup_code = rctt.TYPE
                     AND gl_dist.account_class IN ('REV', 'FREIGHT')
                     AND gl_dist.account_set_flag = 'N'
                     AND gl_dist.org_id = rtl.org_id
                     AND rtl.line_type = 'LINE'
                     AND rt.org_id = hou.organization_id
                     AND gl_dist.code_combination_id = glc.code_combination_id
                     AND rbs.batch_source_id = rt.batch_source_id
                     AND rbs.org_id = rt.org_id
                     AND rbs.NAME = 'Trade Management'
                     AND glc.segment1 = NVL (pv_company_code, glc.segment1)
                     AND glc.segment6 = NVL (pv_account, glc.segment6)
                     AND gl_dist.gl_date BETWEEN NVL (pd_gl_posted_from,
                                                      gl_dist.gl_date)
                                             AND NVL (pd_gl_posted_to,
                                                      gl_dist.gl_date)
                     AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                     AND flex_value_set_name = 'XXD_AR_MTD_OU_VS'
                     AND ffv.enabled_flag = 'Y'
                     AND TRUNC (SYSDATE) BETWEEN NVL (ffv.start_date_active,
                                                      TRUNC (SYSDATE))
                                             AND NVL (ffv.end_date_active,
                                                      TRUNC (SYSDATE))
                     AND ffv.flex_value <> 'ALL EMEA'
                     AND hou.NAME = ffv.flex_value
                     AND hou.NAME =
                         DECODE (pv_operating_unit,
                                 'ALL EMEA', ffv.flex_value,
                                 pv_operating_unit)
                     AND rt.trx_date BETWEEN pd_invoice_date_from
                                         AND pd_invoice_date_to
            GROUP BY hou.NAME, rt.trx_number, rtl.sales_order,
                     rt.trx_date, rt.invoice_currency_code, rt.set_of_books_id,
                     al.meaning, glc.segment3, gl_dist.gl_date,
                     rtl.line_number, rtl.reason_code, gl_dist.cust_trx_line_gl_dist_id,
                     gl_dist.event_id, gl_dist.code_combination_id, rt.customer_trx_id,
                     glc.segment1, rtl.customer_trx_line_id, rtl.interface_line_attribute6,
                     rtl.org_id, glc.concatenated_segments, rtl.inventory_item_id,
                     rt.exchange_rate, rtl.description, glc.chart_of_accounts_id,
                     glc.code_combination_id, rtl.warehouse_id, rt.ship_to_site_use_id,
                     tax_rate, rt.bill_to_site_use_id, rt.ship_to_site_use_id,
                     rt.bill_to_customer_id, hou.organization_id, hou.name,
                     rt.interface_header_attribute14 -- Added as per CCR0009857
                                                    ;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
               'END Transaction Extract Insertion into table - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        BEGIN
            UPDATE xxdo.xxd_ar_vat_rpt_t xx
               SET created_by = gn_user_id, creation_date = gd_sysdate, last_update_date = gd_sysdate,
                   last_updated_by = gn_user_id, request_id = gn_request_id
             WHERE 1 = 1 AND source_trxn = 'TRANSACTION';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        BEGIN
            UPDATE xxdo.xxd_ar_vat_rpt_t xx
               SET gl_country_desc   =
                       (SELECT flv.description
                          FROM fnd_flex_value_sets fls, fnd_flex_values_vl flv
                         WHERE     fls.flex_value_set_name = 'DO_GL_GEO'
                               AND fls.flex_value_set_id =
                                   flv.flex_value_set_id
                               AND flex_value = xx.gl_geo_code)
             WHERE 1 = 1 AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        BEGIN
            UPDATE xxdo.xxd_ar_vat_rpt_t xx
               SET (tax_rate_code, tax_regime_code)   =
                       (SELECT tax_rate_code, tax_regime_code
                          FROM zx_lines
                         WHERE     trx_id = xx.trx_id
                               AND trx_line_id = xx.trx_line_id
                               AND internal_organization_id = xx.org_id
                               AND application_id = 222
                               AND ROWNUM = 1)
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND source_trxn = 'TRANSACTION';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
               'END of Country updation into table - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        BEGIN
            UPDATE xxdo.xxd_ar_vat_rpt_t xx
               SET (customer_number, sell_to_customer_name, bill_vat_number,
                    bill_to_country)   =
                       (SELECT hca.account_number, remove_junk (hp_bill.party_name), remove_junk (hcsua_bill.tax_reference),
                               remove_junk (hl_bill.country)
                          FROM apps.hz_cust_accounts_all hca, apps.hz_cust_site_uses_all hcsua_bill, apps.hz_cust_acct_sites_all hcasa_bill,
                               apps.hz_party_sites hps_bill, apps.hz_parties hp_bill, apps.hz_locations hl_bill
                         WHERE     1 = 1
                               AND hcsua_bill.site_use_id =
                                   xx.bill_to_site_use_id
                               AND hcasa_bill.cust_acct_site_id =
                                   hcsua_bill.cust_acct_site_id
                               AND hps_bill.party_site_id =
                                   hcasa_bill.party_site_id
                               AND hp_bill.party_id = hps_bill.party_id
                               AND hps_bill.location_id = hl_bill.location_id
                               AND xx.bill_to_customer_id =
                                   hca.cust_account_id),
                   (ship_vat_number, ship_to_city, ship_to_state,
                    ship_to_country, ship_to_postal_code)   =
                       (SELECT remove_junk (hcsua_ship.tax_reference), remove_junk (hl_ship.city), remove_junk (hl_ship.state),
                               remove_junk (hl_ship.country), remove_junk (hl_ship.postal_code)
                          FROM apps.hz_cust_acct_sites_all hcasa_ship, apps.hz_cust_site_uses_all hcsua_ship, apps.hz_party_sites hps_ship,
                               apps.hz_parties hp_ship, apps.hz_locations hl_ship
                         WHERE     1 = 1
                               AND hcsua_ship.site_use_id =
                                   xx.ship_to_site_use_id
                               AND hcasa_ship.cust_acct_site_id =
                                   hcsua_ship.cust_acct_site_id
                               AND hps_ship.party_site_id =
                                   hcasa_ship.party_site_id
                               AND hp_ship.party_id = hps_ship.party_id
                               AND hps_ship.location_id = hl_ship.location_id)
             WHERE 1 = 1 AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
               'END of Customer updation into table - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        BEGIN
            UPDATE xxdo.xxd_ar_vat_rpt_t xvc
               SET (style, color, division,
                    department)   =
                       (SELECT mcb.attribute7, mcb.attribute8, mcb.segment2,
                               mcb.segment3
                          FROM mtl_system_items_b msib, mtl_item_categories mic, mtl_categories_b mcb
                         WHERE     msib.inventory_item_id =
                                   mic.inventory_item_id
                               AND msib.organization_id = mic.organization_id
                               AND mic.category_id = mcb.category_id
                               AND mic.category_set_id = 1
                               AND msib.inventory_item_id =
                                   xvc.inventory_item_id
                               AND msib.organization_id = 106),
                   commodity_code   =
                       (SELECT MIN (tc.harmonized_tariff_code)
                          FROM do_custom.do_harmonized_tariff_codes tc
                         WHERE     tc.country = 'EU'
                               AND tc.style_number =
                                   (SELECT mcb.attribute7
                                      FROM mtl_system_items_b msib, mtl_item_categories mic, mtl_categories_b mcb
                                     WHERE     msib.inventory_item_id =
                                               mic.inventory_item_id
                                           AND msib.organization_id =
                                               mic.organization_id
                                           AND mic.category_id =
                                               mcb.category_id
                                           AND mic.category_set_id = 1
                                           AND msib.inventory_item_id =
                                               xvc.inventory_item_id
                                           AND msib.organization_id = 106))
             WHERE 1 = 1 AND request_id = gn_request_id;
        --AND vt_source = 'Material';

        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
               'END of Inventory updation into table - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        BEGIN
            UPDATE xxdo.xxd_ar_vat_rpt_t xvc
               SET to_eur_exchg_rt_corp   =
                       NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency =
                                       xvc.invoice_currency_code
                                   AND to_currency = 'EUR'
                                   AND conversion_date = TRUNC (xvc.trx_date)),
                           1),
                   to_GBP_exchg_rt_corp   =
                       NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency =
                                       xvc.invoice_currency_code
                                   AND to_currency = 'GBP'
                                   AND conversion_date = TRUNC (xvc.trx_date)),
                           1),
                   to_USD_exchg_rt_corp   =
                       NVL (
                           (SELECT conversion_rate
                              FROM apps.gl_daily_rates
                             WHERE     conversion_type = 'Corporate'
                                   AND from_currency =
                                       xvc.invoice_currency_code
                                   AND to_currency = 'USD'
                                   AND conversion_date = TRUNC (xvc.trx_date)),
                           1)
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND source_trxn = 'TRANSACTION';
        --          AND vt_source = 'Material';

        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
               'END Transaction Extract - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
    END insert_into_tbl_prc;

    -- End of Change for CCR0009638
    PROCEDURE mtd_ar_rep (pv_errbuf                 OUT NOCOPY VARCHAR2,
                          pn_retcode                OUT NOCOPY NUMBER,
                          pv_operating_unit      IN            VARCHAR2,
                          pv_company_code        IN            VARCHAR2,
                          pv_invoice_date_from   IN            VARCHAR2,
                          pv_invoice_date_to     IN            VARCHAR2,
                          pv_gl_posted_from      IN            VARCHAR2,
                          pv_gl_posted_to        IN            VARCHAR2,
                          pv_tax_regime_code     IN            VARCHAR2,
                          pv_tax_code            IN            VARCHAR2,
                          pv_account             IN            VARCHAR2,
                          pv_final_mode          IN            VARCHAR2)
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
            :=    'AR_VAT_EMEA_REPORT_'
               || gn_request_id
               || '_'
               || TO_CHAR (SYSDATE, 'DDMONYYHH24MISS')
               || '.txt';
        lv_output_file         UTL_FILE.file_type;
        pv_directory_name      VARCHAR2 (100) := 'XXD_AR_MTD_REPORT_OUT_DIR';

        CURSOR ar_rep_cur IS
            SELECT transaction_type || '|' || gl_entity_code || '|' || ou_name || '|' || document_class || '|' || invoice_number || '|' || reference_number || '|' || order_type || '|' || reason_code || '|' || customer_number || '|' || sell_to_customer_name -- Added for CCR0009103
                                                                                                                                                                                                                                                                 || '|' || customer_vat_number || '|' || invoice_date || '|' || customer_addr_city || '|' || customer_addr_state -- Added for CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                 || '|' || customer_addr_country -- Added for CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                 || '|' || ship_to_country -- Added for CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                                           || '|' || bill_to_country -- Added for CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                                                                     || '|' || warehouse_name || '|' || ship_from_country -- Added for CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          || '|' || inv_line_nr || '|' || line_invoiced_qty || '|' --Start Added for 4.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   || line_tax_country || '|' --End Added for 4.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              || line_tax_rate_code || '|' || style || '|' || color || '|' || commodity_code -- Added for CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             || '|' || product_group || '|' || gender || '|' || line_gbp_inv_amt || '|' || line_gbp_tax_amt || '|' || line_eur_inv_amt || '|' || line_eur_tax_amt || '|' || line_usd_inv_amt || '|' || line_usd_tax_amt || '|' || invoice_currency_code || '|' || line_description -- Added for CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   || '|' || ACCOUNT || '|' || gl_period || '|' || gl_date || '|' || gl_account || '|' || gl_account_desc || '|' || gl_geo_code || '|' || gl_country_desc || '|' || orig_wh_name -- added as per CCR0008507
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 || '|' || ship_postal_code -- Added as per CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            || '|' || tax_rate -- Added as per CCR0009103
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               || '|' || gapless_sequence_number -- Added as per CCR0009857
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 rep_data
              FROM (  SELECT DISTINCT 'AR' transaction_type, gl_entity_code, organization_name ou_name,
                                      document_class, invoice_number, reference_number,
                                      order_type, reason_code, customer_number,
                                      sell_to_customer_name, vat_number customer_vat_number, invoice_date,
                                      city customer_addr_city, state customer_addr_state, country customer_addr_country,
                                      ship_to_country, bill_to_country, warehouse_name,
                                      ship_from_country, line_number inv_line_nr, SUM (NVL (invoiced_qty, 0)) line_invoiced_qty,
                                      SUBSTR (tax_rate_code, 1, 2) line_tax_country, --Added for 4.0
                                                                                     tax_rate_code line_tax_rate_code, style,
                                      color, commodity_code, department product_group,
                                      division gender, ROUND (SUM (NVL (invoiced_qty, 0) * NVL (to_gbp_exchg_rt_corp, 1)), 2) line_gbp_inv_amt, ROUND (SUM (NVL (tax_amt, 0) * NVL (to_gbp_exchg_rt_corp, 1)), 2) line_gbp_tax_amt,
                                      ROUND (SUM (NVL (invoiced_qty, 0) * NVL (to_eur_exchg_rt_corp, 1)), 2) line_eur_inv_amt, ROUND (SUM (NVL (tax_amt, 0) * NVL (to_eur_exchg_rt_corp, 1)), 2) line_eur_tax_amt, ROUND (SUM (NVL (invoiced_qty, 0) * NVL (to_usd_exchg_rt_corp, 1)), 2) line_usd_inv_amt,
                                      ROUND (SUM (NVL (tax_amt, 0) * NVL (to_usd_exchg_rt_corp, 1)), 2) line_usd_tax_amt, invoice_currency_code, description line_description,
                                      ACCOUNT, gl_date, gl_period,
                                      gl_account, gl_account_desc, gl_geo_code,
                                      gl_country_desc, orig_wh_name, ship_postal_code, -- Added as per CCR0009103
                                      tax_rate,     -- Added as per CCR0009103
                                                gapless_sequence_number -- Added as per CCR0009857
                        FROM (SELECT 'AR' transaction_type, gl_entity_code, org_name organization_name,
                                     document_class, invoice_number, reference_number,
                                     order_type, reason_code, customer_number,
                                     sell_to_customer_name, BILL_VAT_NUMBER vat_number, invoice_date,
                                     SHIP_TO_CITY city, NVL (ship_to_state, ship_to_province) state, ship_to_country AS country,
                                     --End Changes for 4.0
                                     ship_to_country, bill_to_country, warehouse_name,
                                     ship_from_country, line_number, invoiced_qty,
                                     pre_conv_tax_amt tax_amt, tax_rate_code, tax_regime_code,
                                     style, color, commodity_code,
                                     department, division, to_gbp_exchg_rt_corp,
                                     to_eur_exchg_rt_corp, to_usd_exchg_rt_corp, invoice_currency_code,
                                     description, gl_tax_account ACCOUNT, GL_DATE,
                                     gl_period, gl_account, gl_account_desc,
                                     gl_geo_code, gl_country_desc, orig_wh_name,
                                     ship_to_postal_code ship_postal_code, tax_rate, gapless_sequence_number -- Added as per CCR0009857
                                FROM xxdo.xxd_ar_vat_rpt_t
                               WHERE     1 = 1
                                     AND request_id = gn_request_id
                                     AND source_trxn = 'ADJUSTMENT')
                       WHERE     NVL (tax_rate_code, 'XXXX') =
                                 NVL (pv_tax_code, NVL (tax_rate_code, 'XXXX'))
                             AND NVL (tax_regime_code, 'XXXX') =
                                 NVL (pv_tax_regime_code,
                                      NVL (tax_regime_code, 'XXXX'))
                    GROUP BY transaction_type, gl_entity_code, organization_name,
                             document_class, invoice_number, reference_number,
                             order_type, reason_code, customer_number,
                             sell_to_customer_name, vat_number, invoice_date,
                             city, state,                           --province
                                          country,
                             ship_to_country, bill_to_country, warehouse_name,
                             ship_from_country, line_number, tax_rate_code,
                             style, color, commodity_code,
                             department, division, invoice_currency_code,
                             description, ACCOUNT, gl_date,
                             gl_period, gl_account, gl_account_desc,
                             gl_geo_code, gl_country_desc, orig_wh_name, -- added as per CCR0009071
                             ship_postal_code,      -- Added as per CCR0009103
                                               tax_rate, -- Added as per CCR0009103
                                                         gapless_sequence_number -- Added as per CCR0009857
                    UNION
                      SELECT 'AR'
                                 transaction_type,
                             gl_entity_code,
                             organization_name
                                 ou_name,
                             document_class,
                             invoice_number,
                             reference_number,
                             order_type,
                             reason_code,
                             customer_number,
                             sell_to_customer_name,
                             vat_number
                                 customer_vat_number,
                             invoice_date,
                             city
                                 customer_addr_city,
                             state
                                 customer_addr_state,
                             country
                                 customer_addr_country,
                             ship_to_country,
                             bill_to_country,
                             warehouse_name,
                             (SELECT DISTINCT hloc.country
                                FROM hr_locations_all hloc
                               WHERE hloc.inventory_organization_id =
                                     warehouse_id)
                                 ship_from_country,
                             line_number
                                 inv_line_nr,
                             SUM (NVL (invoiced_qty, 0))
                                 line_invoiced_qty,
                             SUBSTR (tax_rate_code, 1, 2)
                                 line_tax_country,             --Added for 4.0
                             tax_rate_code
                                 line_tax_rate_code,
                             style,
                             color,
                             commodity_code,
                             department
                                 product_group,
                             division
                                 gender,
                             ROUND (
                                 SUM (
                                       NVL (pre_conv_inv_amt, 0)
                                     * NVL (to_gbp_exchg_rt_corp, 1)),
                                 2)
                                 line_gbp_inv_amt,
                             ROUND (
                                 SUM (
                                       NVL (pre_conv_tax_amt, 0)
                                     * NVL (to_gbp_exchg_rt_corp, 1)),
                                 2)
                                 line_gbp_tax_amt,
                             ROUND (
                                 SUM (
                                       NVL (pre_conv_inv_amt, 0)
                                     * NVL (to_eur_exchg_rt_corp, 1)),
                                 2)
                                 line_eur_inv_amt,
                             ROUND (
                                 SUM (
                                       NVL (pre_conv_tax_amt, 0)
                                     * NVL (to_eur_exchg_rt_corp, 1)),
                                 2)
                                 line_eur_tax_amt,
                             ROUND (
                                 SUM (
                                       NVL (pre_conv_inv_amt, 0)
                                     * NVL (to_usd_exchg_rt_corp, 1)),
                                 2)
                                 line_usd_inv_amt,
                             ROUND (
                                 SUM (
                                       NVL (pre_conv_tax_amt, 0)
                                     * NVL (to_usd_exchg_rt_corp, 1)),
                                 2)
                                 line_usd_tax_amt,
                             invoice_currency_code,
                             description
                                 line_description,
                             ACCOUNT,
                             gl_date,
                             (SELECT period_name
                                FROM gl_periods
                               WHERE     gl_date BETWEEN start_date
                                                     AND end_date
                                     AND period_set_name = 'DO_FY_CALENDAR')
                                 gl_period,
                             gl_account,
                             gl_account_desc,
                             gl_geo_code,
                             gl_country_desc,
                             orig_wh_name,          -- added as per CCR0009071
                             ship_postal_code,
                             -- Added as per CCR0009103
                             tax_rate,              -- Added as per CCR0009103
                             gapless_sequence_number -- Added as per CCR0009857
                        FROM (SELECT org_name organization_name, invoice_number, order_type,
                                     customer_number, sell_to_customer_name, trx_date invoice_date,
                                     ship_to_city city, NVL (ship_to_state, ship_to_province) state, ship_to_country AS country,
                                     ship_to_country, bill_to_country, to_gbp_exchg_rt_corp,
                                     to_eur_exchg_rt_corp, to_usd_exchg_rt_corp, warehouse_name,
                                     NVL (ship_vat_number, bill_vat_number) vat_number, invoiced_qty, gl_tax_account ACCOUNT,
                                     tax_rate_code, tax_regime_code, invoice_total,
                                     style, color, commodity_code,
                                     division, department, pre_conv_inv_amt,
                                     pre_conv_tax_amt, invoice_currency_code, description,
                                     gl_entity_code, document_class, reason_code,
                                     warehouse_id, line_number, gl_date,
                                     gl_account, gl_account_desc, gl_geo_code,
                                     gl_country_desc, reference_number, NULL orig_wh_name,
                                     ship_to_postal_code ship_postal_code, tax_rate, gapless_sequence_number -- Added as per CCR0009857
                                FROM xxdo.xxd_ar_vat_rpt_t
                               WHERE     1 = 1
                                     AND request_id = gn_request_id
                                     AND source_trxn = 'TRANSACTION')
                       WHERE     NVL (tax_rate_code, 'XXXX') =
                                 NVL (pv_tax_code, NVL (tax_rate_code, 'XXXX'))
                             AND NVL (tax_regime_code, 'XXXX') =
                                 NVL (pv_tax_regime_code,
                                      NVL (tax_regime_code, 'XXXX'))
                    GROUP BY organization_name, invoice_number, customer_number,
                             sell_to_customer_name, invoice_date, city,
                             state, country, ship_to_country,
                             bill_to_country, warehouse_name, vat_number,
                             ACCOUNT, reference_number, tax_rate_code,
                             invoice_currency_code, to_gbp_exchg_rt_corp, to_eur_exchg_rt_corp,
                             to_usd_exchg_rt_corp, description, style,
                             color, gl_entity_code, commodity_code,
                             department, division, reason_code,
                             line_number, warehouse_id, gl_date,
                             gl_account, gl_account_desc, gl_geo_code,
                             gl_country_desc, document_class, order_type,
                             orig_wh_name,          -- Added as per CCR0009071
                                           ship_postal_code, -- Added as per CCR0009103
                                                             tax_rate, -- Added as per CCR0009103
                             gapless_sequence_number -- Added as per CCR0009857
                                                    );

        TYPE fetch_data IS TABLE OF ar_rep_cur%ROWTYPE;

        fetch_cur_data         fetch_data;
        v_header               VARCHAR2 (2000);
        lv_line                VARCHAR2 (4000);
        ln_cnt                 NUMBER := 0;
        lv_err_msg             VARCHAR2 (4000);
    BEGIN
        -- Added as per CCR0009638
        insert_into_tbl_prc (pv_operating_unit      => pv_operating_unit,
                             pv_company_code        => pv_company_code,
                             pd_invoice_date_from   => pd_invoice_date_from,
                             pd_invoice_date_to     => pd_invoice_date_to,
                             pd_gl_posted_from      => pd_gl_posted_from,
                             pd_gl_posted_to        => pd_gl_posted_to,
                             pv_tax_regime_code     => pv_tax_regime_code,
                             pv_tax_code            => pv_tax_code,
                             pv_account             => pv_account);

        -- End of Change as per CCR0009638

        IF pv_final_mode = 'N'
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   'TRANSACTION_TYPE'
                || '|'
                || 'GL_ENTITY_CODE'
                || '|'
                || 'OU_NAME'
                || '|'
                || 'DOCUMENT_CLASS'
                || '|'
                || 'INVOICE_NUMBER'
                || '|'
                || 'REFERENCE_NUMBER'
                || '|'
                || 'ORDER_TYPE'
                || '|'
                || 'REASON_CODE'
                || '|'
                || 'CUSTOMER_NUMBER'
                || '|'
                || 'SELL_TO_CUSTOMER_NAME'
                || '|'
                || 'CUSTOMER_VAT_NUMBER'
                || '|'
                || 'INVOICE_DATE'
                || '|'
                || 'CUSTOMER_ADDR_CITY'
                || '|'
                || 'CUSTOMER_ADDR_PROVINCE'
                || '|'
                || 'CUSTOMER_ADDR_COUNTRY'
                || '|'
                || 'SHIP_TO_COUNTRY'
                || '|'
                || 'BILL_TO_COUNTRY'
                || '|'
                || 'WAREHOUSE_NAME'
                || '|'
                || 'SHIP_FROM_COUNTRY'
                || '|'
                || 'INV_LINE_NR'
                || '|'
                || 'LINE_INVOICED_QTY'
                || '|'
                --Start Added for 4.0
                || 'TAX_COUNTRY'
                || '|'
                --End Added for 4.0
                || 'LINE_TAX_RATE_CODE'
                || '|'
                || 'STYLE'
                || '|'
                || 'COLOR'
                || '|'
                || 'COMMODITY_CODE'
                || '|'
                || 'PRODUCT_GROUP'
                || '|'
                || 'GENDER'
                || '|'
                || 'LINE_GBP_INV_AMT'
                || '|'
                || 'LINE_GBP_TAX_AMT'
                || '|'
                || 'LINE_EUR_INV_AMT'
                || '|'
                || 'LINE_EUR_TAX_AMT'
                || '|'
                || 'LINE_USD_INV_AMT'
                || '|'
                || 'LINE_USD_TAX_AMT'
                || '|'
                || 'INVOICE_CURRENCY_CODE'
                || '|'
                || 'LINE_DESCRIPTION'
                || '|'
                || 'TAX_GL_ACCOUNT'
                || '|'
                || 'GL_PERIOD'
                || '|'
                || 'GL_DATE'
                || '|'
                || 'GL_ACCOUNT'
                || '|'
                || 'GL_ACCOUNT_DESC'
                || '|'
                || 'GL_GEO_CODE'
                || '|'
                || 'GL_COUNTRY_DESC'
                || '|'
                || 'ORIGINAL_WAREHOUSE'             -- Added as per CCR0009071
                || '|'
                || 'CUSTOMER_ADDR_POSTCODE'
                || '|'
                || 'LINE_TAX_RATE'
                || '|'
                || 'GAPLESS_SEQUENCE_NUMBER'        -- Added as per CCR0009857
                                            );

            /* Commented for CCR CCR0009103 */
            /*OPEN ar_rep_cur;

            LOOP
               FETCH ar_rep_cur
               BULK COLLECT INTO fetch_cur_data LIMIT 10000;

               FOR i IN fetch_cur_data.FIRST .. fetch_cur_data.LAST
               LOOP
                  apps.fnd_file.put_line (apps.fnd_file.output,
                                          fetch_cur_data (i).rep_data
                                         );
               END LOOP;
            END LOOP;*/
            /* Start of changes for CCR CCR0009103 */
            FOR ar_rep IN ar_rep_cur
            LOOP
                apps.fnd_file.put_line (apps.fnd_file.output,
                                        ar_rep.rep_data);
            END LOOP;
        /* END of changes for CCR CCR0009103 */
        END IF;

        IF pv_final_mode = 'Y'
        THEN
            BEGIN
                v_header   :=
                       'TRANSACTION_TYPE'
                    || '|'
                    || 'GL_ENTITY_CODE'
                    || '|'
                    || 'OU_NAME'
                    || '|'
                    || 'DOCUMENT_CLASS'
                    || '|'
                    || 'INVOICE_NUMBER'
                    || '|'
                    || 'REFERENCE_NUMBER'
                    || '|'
                    || 'ORDER_TYPE'
                    || '|'
                    || 'REASON_CODE'
                    || '|'
                    || 'CUSTOMER_NUMBER'
                    || '|'
                    || 'SELL_TO_CUSTOMER_NAME'
                    || '|'
                    || 'CUSTOMER_VAT_NUMBER'
                    || '|'
                    || 'INVOICE_DATE'
                    || '|'
                    || 'CUSTOMER_ADDR_CITY'
                    || '|'
                    || 'CUSTOMER_ADDR_PROVINCE'
                    || '|'
                    || 'CUSTOMER_ADDR_COUNTRY'
                    || '|'
                    || 'SHIP_TO_COUNTRY'
                    || '|'
                    || 'BILL_TO_COUNTRY'
                    || '|'
                    || 'WAREHOUSE_NAME'
                    || '|'
                    || 'SHIP_FROM_COUNTRY'
                    || '|'
                    || 'INV_LINE_NR'
                    || '|'
                    || 'LINE_INVOICED_QTY'
                    || '|'
                    --Start Added for 4.0
                    || 'TAX_COUNTRY'
                    || '|'
                    --End Added for 4.0
                    || 'LINE_TAX_RATE_CODE'
                    || '|'
                    || 'STYLE'
                    || '|'
                    || 'COLOR'
                    || '|'
                    || 'COMMODITY_CODE'
                    || '|'
                    || 'PRODUCT_GROUP'
                    || '|'
                    || 'GENDER'
                    || '|'
                    || 'LINE_GBP_INV_AMT'
                    || '|'
                    || 'LINE_GBP_TAX_AMT'
                    || '|'
                    || 'LINE_EUR_INV_AMT'
                    || '|'
                    || 'LINE_EUR_TAX_AMT'
                    || '|'
                    || 'LINE_USD_INV_AMT'
                    || '|'
                    || 'LINE_USD_TAX_AMT'
                    || '|'
                    || 'INVOICE_CURRENCY_CODE'
                    || '|'
                    || 'LINE_DESCRIPTION'
                    || '|'
                    || 'TAX_GL_ACCOUNT'
                    || '|'
                    || 'GL_PERIOD'
                    || '|'
                    || 'GL_DATE'
                    || '|'
                    || 'GL_ACCOUNT'
                    || '|'
                    || 'GL_ACCOUNT_DESC'
                    || '|'
                    || 'GL_GEO_CODE'
                    || '|'
                    || 'GL_COUNTRY_DESC'
                    || '|'
                    || 'ORIGINAL_WAREHOUSE'         -- Added as per CCR0009071
                    || '|'
                    || 'CUSTOMER_ADDR_POSTCODE'
                    || '|'
                    || 'LINE_TAX_RATE'
                    || '|'
                    || 'GAPLESS_SEQUENCE_NUMBER'    -- Added as per CCR0009857
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
                               'Error in Opening the AP_VAT_EMEA_Report file for writing. Error is : '
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
    END mtd_ar_rep;
END xxd_ar_mtd_report_pkg;
/
