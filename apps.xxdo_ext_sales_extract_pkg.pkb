--
-- XXDO_EXT_SALES_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_EXT_SALES_EXTRACT_PKG"
IS
    --  ####################################################################################################
    -- Package      : XXDO_EXT_SALES_EXTRACT_PKG
    -- Design       : Used for "External Sales Extract by State - Deckers" report
    -- Notes        :
    -- Modification :
    --  --------------
    --  Date            Name                Ver     Change          Description
    --  ----------      --------------      -----   -------------   ---------------------
    --  18-May-2017     Development Team    1.0     NA              Initial Version
    --  16-Jan-2020     Kranthi Bollam      1.1     CCR0008395      Added parameter p_include_adjustments.
    --                                                              Added Adjustments Query
    --  08-JAN-2021     Srinath Siricilla   1.2                     Added Journal Query
    --  17-Mar-2021    Suraj Valluri       1.3     CCR0008395     Changed old cust tables to R12 TCA standards
    --                                                              Modified query for
    --  10-June-2021    Satyanarayana       1.4     CCR0008395      Query modified for amounts for mismatch with
    --                                                              account analysis report
    --  ####################################################################################################

    FUNCTION get_country_details (p_bill_to_site_use_id NUMBER)
        RETURN VARCHAR2
    IS
        v_details   VARCHAR2 (1000);
    BEGIN
        SELECT cntry.territory_short_name
          INTO v_details
          FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_site_uses_all b,
               apps.hz_cust_acct_sites_all c, apps.fnd_territories_tl cntry
         WHERE     1 = 1
               AND b.cust_acct_site_id = c.cust_acct_site_id(+)
               AND c.party_site_id = hps.party_site_id(+)
               AND hps.location_id = hl.location_id(+)
               AND hl.country = cntry.territory_code(+)
               AND NVL (cntry.LANGUAGE, USERENV ('LANG')) = USERENV ('LANG')
               AND b.site_use_id = p_bill_to_site_use_id;

        RETURN v_details;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_details   := NULL;
    END get_country_details;

    FUNCTION get_state_details (p_bill_to_site_use_id NUMBER)
        RETURN VARCHAR2
    IS
        v_details   VARCHAR2 (1000);
    BEGIN
        SELECT NVL (hl.state, hl.province)
          INTO v_details
          FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_site_uses_all b,
               apps.hz_cust_acct_sites_all c, apps.fnd_territories_tl cntry
         WHERE     1 = 1
               AND b.cust_acct_site_id = c.cust_acct_site_id(+)
               AND c.party_site_id = hps.party_site_id(+)
               AND hps.location_id = hl.location_id(+)
               AND hl.country = cntry.territory_code(+)
               AND NVL (cntry.LANGUAGE, USERENV ('LANG')) = USERENV ('LANG')
               AND b.site_use_id = p_bill_to_site_use_id;

        RETURN v_details;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_details   := NULL;
    END get_state_details;

    FUNCTION get_county_details (p_bill_to_site_use_id NUMBER)
        RETURN VARCHAR2
    IS
        v_details   VARCHAR2 (1000);
    BEGIN
        SELECT hl.county
          INTO v_details
          FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_site_uses_all b,
               apps.hz_cust_acct_sites_all c, apps.fnd_territories_tl cntry
         WHERE     1 = 1
               AND b.cust_acct_site_id = c.cust_acct_site_id(+)
               AND c.party_site_id = hps.party_site_id(+)
               AND hps.location_id = hl.location_id(+)
               AND hl.country = cntry.territory_code(+)
               AND NVL (cntry.LANGUAGE, USERENV ('LANG')) = USERENV ('LANG')
               AND b.site_use_id = p_bill_to_site_use_id;

        RETURN v_details;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_details   := NULL;
    END get_county_details;

    FUNCTION get_city_details (p_bill_to_site_use_id NUMBER)
        RETURN VARCHAR2
    IS
        v_details   VARCHAR2 (1000);
    BEGIN
        SELECT hl.city
          INTO v_details
          FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_site_uses_all b,
               apps.hz_cust_acct_sites_all c, apps.fnd_territories_tl cntry
         WHERE     1 = 1
               AND b.cust_acct_site_id = c.cust_acct_site_id(+)
               AND c.party_site_id = hps.party_site_id(+)
               AND hps.location_id = hl.location_id(+)
               AND hl.country = cntry.territory_code(+)
               AND NVL (cntry.LANGUAGE, USERENV ('LANG')) = USERENV ('LANG')
               AND b.site_use_id = p_bill_to_site_use_id;

        RETURN v_details;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_details   := NULL;
    END get_city_details;


    FUNCTION get_postal_code_details (p_bill_to_site_use_id NUMBER)
        RETURN VARCHAR2
    IS
        v_details   VARCHAR2 (1000);
    BEGIN
        SELECT hl.postal_code
          INTO v_details
          FROM apps.hz_locations hl, apps.hz_party_sites hps, apps.hz_cust_site_uses_all b,
               apps.hz_cust_acct_sites_all c, apps.fnd_territories_tl cntry
         WHERE     1 = 1
               AND b.cust_acct_site_id = c.cust_acct_site_id(+)
               AND c.party_site_id = hps.party_site_id(+)
               AND hps.location_id = hl.location_id(+)
               AND hl.country = cntry.territory_code(+)
               AND NVL (cntry.LANGUAGE, USERENV ('LANG')) = USERENV ('LANG')
               AND b.site_use_id = p_bill_to_site_use_id;

        RETURN v_details;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_details   := NULL;
    END get_postal_code_details;


    PROCEDURE run_sales_extract_query (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_company IN VARCHAR2, p_from_period IN VARCHAR2, p_to_period IN VARCHAR2, p_from_revenue_acct IN VARCHAR2
                                       , p_to_revenue_acct IN VARCHAR2, p_state IN VARCHAR2, p_additional_details IN VARCHAR2) --,     p_include_adjustments   IN    VARCHAR2 )
    IS
        lsql               VARCHAR2 (100);
        l_acc_class_code   VARCHAR2 (4000);
        l_period_name      VARCHAR2 (1000);
        v_count            NUMBER := 0;

        CURSOR c_main_details (l_company IN VARCHAR2, l_from_revenue_acct IN VARCHAR2, l_to_revenue_acct IN VARCHAR2)
        IS
            SELECT HRO.ORGANIZATION_ID, HRO.name, hro.SET_OF_BOOKS_ID,
                   gcc.code_combination_id, gcc.segment1, gcc.segment2,
                   gcc.concatenated_segments rev_acct, gcc.segment6, gcc.enabled_flag
              FROM HR_OPERATING_UNITS HRO, XLE_ENTITY_PROFILES LEP, GL_LEGAL_ENTITIES_BSVS GLEV,
                   apps.gl_code_combinations_kfv gcc
             WHERE     1 = 1                          --hro.organization_id=95
                   AND HRO.DEFAULT_LEGAL_CONTEXT_ID = LEP.LEGAL_ENTITY_ID
                   AND GLEV.LEGAL_ENTITY_ID = LEP.LEGAL_ENTITY_ID
                   AND GLEV.FLEX_SEGMENT_VALUE = gcc.segment1
                   AND gcc.segment1 = l_company
                   AND gcc.segment6 BETWEEN NVL (l_from_revenue_acct,
                                                 gcc.segment6)
                                        AND NVL (l_to_revenue_acct,
                                                 gcc.segment6);



        CURSOR c1 (l_org_id                IN NUMBER,
                   l_org_name              IN VARCHAR2,
                   l_period_from           IN VARCHAR2,
                   l_period_to             IN VARCHAR2,
                   l_code_combination_id      NUMBER,
                   l_ledger_id                VARCHAR2,
                   l_state                 IN VARCHAR2,
                   l_segment6                 VARCHAR2,
                   l_additional_details    IN VARCHAR2,
                   l_rev_acct                 VARCHAR2,
                   l_enabled_flag             VARCHAR2,
                   l_segment2                 VARCHAR2) --,l_include_adjustments IN VARCHAR2)
        IS
              SELECT ad.number1,
                     ad.company,
                     ad.org,
                     ad.brand,
                     ad.ship_country,
                     ad.ship_state,
                     ad.rev_acct,
                     (SELECT period_name
                        FROM gl.gl_periods
                       WHERE     period_set_name = 'DO_FY_CALENDAR'
                             AND ad.gl_date BETWEEN start_date AND end_date)
                         gl_date1,
                     MIN (ad.trx_date)
                         min_trx_date,
                     MAX (ad.trx_date)
                         max_trx_date,
                     SUM (ad.revenue_amt)
                         sum_rev_amt,
                     SUM (ad.tax_amt)
                         sum_tax_amt,
                     SUM (ad.frieght_amt)
                         sum_frieght_amt,
                     ad.ship_county,
                     ad.ship_city,
                     ad.zip_code
                FROM (  SELECT l_org_name org, rct.trx_date, rct.attribute5 brand,
                               cd.accounting_date gl_date, rct.trx_number number1, DECODE (rctl.line_type, 'LINE', SUM (rctl.extended_amount), 0) revenue_amt, --1.3
                               DECODE (rctl.line_type, 'TAX', SUM (rctl.extended_amount), 0) tax_amt, --1.3
                                                                                                      DECODE (rctl.line_type, 'FREIGHT', SUM (rctl.extended_amount), 0) frieght_amt --1.3
                                                                                                                                                                                   , NULL RECEIVABLE_APPLICATION_ID,
                               get_country_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_country, get_state_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_state, get_city_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_county,
                               get_county_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_city, get_postal_code_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) zip_code, l_rev_acct rev_acct,
                               p_company company
                          FROM apps.ra_customer_trx_lines_all rctl, apps.ra_customer_trx_all rct, XXD_AR_EXT_SALES_EXTRACT_GT cd
                         WHERE     1 = 1
                               AND rct.org_id = l_org_id
                               AND rct.complete_flag = 'Y'
                               AND rct.customer_trx_id = rctl.customer_trx_id
                               AND rctl.line_type IN ('LINE', 'TAX', 'FREIGHT')
                               AND rctl.customer_trx_id = cd.source_id_int_1
                               AND l_additional_details = 'Y'
                               AND cd.accounting_class_code IN
                                       (SELECT ffvl.flex_value
                                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                         WHERE     1 = 1
                                               AND ffvs.flex_value_set_name =
                                                   'XXD_AR_EVENT_CLASS_CODE_VS'
                                               AND ffvs.flex_value_set_id =
                                                   ffvl.flex_value_set_id
                                               AND ffvl.enabled_flag = 'Y'
                                               AND SYSDATE BETWEEN NVL (
                                                                       ffvl.start_date_active,
                                                                       SYSDATE)
                                                               AND NVL (
                                                                       ffvl.end_date_active,
                                                                         SYSDATE
                                                                       + 1)) --Added for change 1.1
                               AND EXISTS
                                       (SELECT /*+ index(xdl XLA_DISTRIBUTION_LINKS_N1) */
                                               1
                                          FROM apps.XLA_DISTRIBUTION_LINKS xdl, apps.ra_cust_trx_line_gl_dist_all gld
                                         WHERE     1 = 1
                                               AND xdl.application_id = 222
                                               AND xdl.source_distribution_type =
                                                   UPPER (
                                                       'ra_cust_trx_line_gl_dist_all')
                                               AND gld.cust_trx_line_gl_dist_id =
                                                   xdl.source_distribution_id_num_1
                                               AND cd.event_id = xdl.event_id
                                               AND gld.account_class IN
                                                       ('REV', 'FREIGHT') -- Added as per CCR0008395
                                               AND gld.account_set_flag = 'N'
                                               AND rctl.customer_trx_line_id =
                                                   gld.customer_trx_line_id
                                               AND gld.event_id = cd.event_id
                                               AND gld.set_of_books_id =
                                                   cd.ledger_id
                                               AND xdl.ae_line_num =
                                                   cd.ae_line_num
                                               AND xdl.ae_header_id =
                                                   cd.ae_header_id)
                               AND EXISTS
                                       (SELECT 1
                                          FROM fnd_lookup_values flv
                                         WHERE     flv.lookup_type =
                                                   'XXDOAR036_TAX_ACCOUNTS'
                                               AND flv.language =
                                                   USERENV ('LANG')
                                               AND flv.enabled_flag = 'Y'
                                               AND flv.lookup_code = l_segment6)
                      GROUP BY L_org_NAME, rct.trx_date, rctl.line_type,
                               rct.attribute5, cd.accounting_date, rct.trx_number,
                               rct.bill_to_site_use_id, rct.ship_to_site_use_id
                        HAVING SUM (rctl.extended_amount) <> 0
                      UNION ALL
                      SELECT DISTINCT l_org_name org, rct.trx_date, rct.attribute5 brand,
                                      ara.gl_date gl_date, ara.adjustment_number number1, NVL (ara.line_adjusted, 0) revenue_amt,
                                      NVL (ara.tax_adjusted, 0) tax_amt, NVL (ara.freight_adjusted, 0) frieght_amt, NULL RECEIVABLE_APPLICATION_ID,
                                      get_country_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_country, get_state_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_state, get_city_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_county,
                                      get_county_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_city, get_postal_code_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) zip_code, l_rev_acct rev_acct,
                                      p_company company
                        FROM apps.ar_adjustments_all ara,
                             apps.ra_customer_trx_all rct,
                             (SELECT DISTINCT event_id, ledger_id, accounting_class_code,
                                              source_id_int_1, code_combination_id
                                FROM XXD_AR_EXT_SALES_EXTRACT_GT) cd
                       WHERE     1 = 1
                             AND rct.complete_flag = 'Y'
                             AND cd.code_combination_id =
                                 ara.CODE_COMBINATION_ID
                             AND cd.ledger_id = ara.set_of_books_id
                             AND cd.accounting_class_code = 'ADJ'
                             AND cd.event_id = ARA.EVENT_ID
                             AND l_additional_details = 'Y'
                             AND ara.gl_date >=
                                 (SELECT start_date
                                    FROM gl.gl_periods
                                   WHERE     period_set_name = 'DO_FY_CALENDAR'
                                         AND period_name = l_period_from)
                             AND ara.gl_date <=
                                 (SELECT end_date
                                    FROM gl.gl_periods
                                   WHERE     period_set_name = 'DO_FY_CALENDAR'
                                         AND period_name = l_period_to)
                             AND ara.customer_trx_id = rct.customer_trx_id
                             AND rct.org_id = l_org_id
                             AND ara.adjustment_id = cd.source_id_int_1
                             AND EXISTS
                                     (SELECT 1
                                        FROM fnd_lookup_values flv
                                       WHERE     flv.lookup_type =
                                                 'XXDOAR036_TAX_ACCOUNTS'
                                             AND flv.language =
                                                 USERENV ('LANG')
                                             AND flv.enabled_flag = 'Y'
                                             AND flv.lookup_code = l_segment6)
                      /*UNION ALL
                               SELECT /*+ FULL(apsa) PARALLEL( apsa,4) */
                      /*+ FULL(araa) PARALLEL( araa,4) */
                      /*DISTINCT
                                        l_org_name                         org,
                                          rct.trx_date,
                                          rct.attribute5                    brand,
                                          apsa.gl_date                      gl_date,
                                          acra.receipt_number number1,
                                         (CASE WHEN cd.accounting_class_code ='EDISC'
                                                THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                              WHEN cd.accounting_class_code ='UNEDISC'
                                                THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                              ELSE
                           nvl(araa.line_applied, nvl(araa.amount_applied, 0))
                           END)  revenue_amt, --Line Amount Adjusted
                                          nvl(araa.tax_applied, 0) tax_amt, --Tax Amount Adjusted
                                          nvl(araa.freight_applied, 0) frieght_amt  ,
                           araa.RECEIVABLE_APPLICATION_ID,
                                            get_country_details(NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) ship_country,
                            get_state_details (NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) ship_state,
                            get_city_details (NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) ship_county,
                            get_county_details(NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) ship_city,
                            get_postal_code_details (NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) zip_code ,
                           l_rev_acct rev_acct,
                            p_company company
                                      FROM
                                          apps.ar_cash_receipts_all             acra,
                                          apps.ar_payment_schedules_all         apsa,
                                          apps.ar_receivable_applications_all   araa,
                                            apps.ra_customer_trx_all rct,
                                            (select  distinct event_id,ledger_id,accounting_class_code,code_combination_id from XXD_AR_EXT_SALES_EXTRACT_GT ) cd
                                    WHERE
                                          1 = 1
                                          AND acra.cash_receipt_id = apsa.cash_receipt_id
                                           AND araa.cash_receipt_id = acra.cash_receipt_id
                                             AND araa.status in ('ACC','APP','OTHER ACC','UNAPP','ACTIVITY','UNID')
                                        --  AND nvl(l_include_adjustments, 'N') = 'Y'
                                          AND l_additional_details = 'Y'
                                         AND  rct.complete_flag = 'Y'
                                           AND apsa.gl_date >= (
                                              SELECT start_date FROM  gl.gl_periods  WHERE
                                                  period_set_name = 'DO_FY_CALENDAR'
                                                  AND period_name = l_period_from
                                          )
                                          AND apsa.gl_date <= (
                                              SELECT end_date FROM  gl.gl_periods
                                              WHERE    period_set_name = 'DO_FY_CALENDAR'
                                                  AND period_name = l_period_to
                                          )
                            AND (CASE WHEN cd.accounting_class_code ='EDISC'
                                                THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                              WHEN cd.accounting_class_code ='UNEDISC'
                                                THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                              ELSE
                           nvl(araa.line_applied, nvl(araa.amount_applied, 0))
                           END)<>0
                                          AND araa.org_id = l_org_id
                                          AND araa.applied_customer_trx_id = rct.customer_trx_id
                                          AND araa.event_id = cd.event_id
                                          AND araa.set_of_books_id= cd.ledger_id*/
                      --AND araa.CODE_COMBINATION_ID=cd.code_combination_id
                      UNION ALL
                      /* SELECT /*+ FULL(apsa) PARALLEL( apsa,4) */
                      /*+ FULL(araa) PARALLEL( araa,4) */
                      /*DISTINCT
                                         l_org_name                          org,
                                         acra.receipt_date,
                                         NULL brand,
                                         araa.gl_date                      gl_date,
                                         acra.receipt_number number1,
                                         (CASE WHEN cd.accounting_class_code ='EDISC'
                                               THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                             WHEN cd.accounting_class_code ='UNEDISC'
                                               THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                             ELSE
                          nvl(araa.line_applied, nvl(araa.amount_applied, 0))
                          END) revenue_amt, --Line Amount Adjusted
                                         nvl(araa.tax_applied, 0) tax_amt, --Tax Amount Adjusted
                                         nvl(araa.freight_applied, 0) frieght_amt, --Freight Amount Adjusted
                                         araa.RECEIVABLE_APPLICATION_ID,
                           get_country_details(acra.customer_site_use_id) ship_country,
                           get_state_details (acra.customer_site_use_id) ship_state,
                           get_city_details (acra.customer_site_use_id) ship_county,
                           get_county_details( acra.customer_site_use_id) ship_city,
                           get_postal_code_details (acra.customer_site_use_id) zip_code ,

                          l_rev_acct rev_acct,
                           p_company company
                                 FROM
                                         ar_payment_schedules_all              apsa,
                                          apps.ar_receivable_applications_all   araa,
                                          apps.ar_cash_receipts_all             acra,
                                         ozf_claims_all                        oca,
                                           (select  distinct event_id,ledger_id,accounting_class_code,code_combination_id from XXD_AR_EXT_SALES_EXTRACT_GT ) cd
                                 WHERE 1=1
                                        AND apsa.payment_schedule_id = araa.payment_schedule_id
                                         AND apsa.org_id = araa.org_id
                                          AND  apsa.org_id=l_org_id
                                         AND oca.receipt_id (+) = araa.cash_receipt_id
                                         AND oca.claim_id (+) = araa.secondary_application_ref_id
                                         AND araa.cash_receipt_id = apsa.cash_receipt_id
                                         AND araa.cash_receipt_id = acra.cash_receipt_id
                                         AND acra.org_id = l_org_id
                                         AND oca.status_code (+) = 'CLOSED'
                                         AND oca.org_id (+) = araa.org_id
                                         --AND araa.code_combination_id = gcc.code_combination_id
                                          AND apsa.class = 'PMT'
                                        -- AND apsa.status = 'OP' --1.3
                                         AND araa.status = 'ACTIVITY'
                                        -- AND apsa.gl_date >= (
                                          AND araa.gl_date>=(   SELECT start_date
                                                                 FROM  gl.gl_periods
                                                                 WHERE period_set_name = 'DO_FY_CALENDAR'
                                                                 AND period_name = l_period_from
                                         )
                                       --  AND apsa.gl_date <= (
                                         AND araa.gl_date<=(    SELECT  end_date
                                                                 FROM  gl.gl_periods
                                                                 WHERE period_set_name = 'DO_FY_CALENDAR'
                                                                     AND period_name = l_period_to
                                                            )
                                         AND (CASE WHEN cd.accounting_class_code ='EDISC'
                                               THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                             WHEN cd.accounting_class_code ='UNEDISC'
                                               THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                             ELSE
                          nvl(araa.line_applied, nvl(araa.amount_applied, 0))
                          END)<>0
                           AND (CASE WHEN oca.claim_class='DEDUCTION'
                                       AND araa.status = 'ACTIVITY'
                                               THEN 1
                              WHEN oca.claim_class iS NULL
                                THEN 1
                            ELSE 2
                          END)=1
                            AND oca.claim_class(+) = 'DEDUCTION'
                                         AND araa.cash_receipt_id = acra.cash_receipt_id
                                        AND l_additional_details             ='Y'
                                         AND araa.event_id = cd.event_id
                                         AND araa.set_of_books_id= cd.ledger_id
                                         AND araa.CODE_COMBINATION_ID=cd.code_combination_id
                                      AND NOT EXISTS (
                                             SELECT /*+ FULL(art) PARALLEL( art,4) */
                      /*  1
                    FROM
                        ar_receivables_trx_all   art,
                        fnd_flex_value_sets      ffvs,
                        fnd_flex_values_vl       ffvl
                    WHERE
                        art.name = ffvl.description
                        AND art.org_id = apsa.org_id
                        AND art.receivables_trx_id = araa.receivables_trx_id
                        AND ffvs.flex_value_set_name = 'XXD_ZX_CAN_TAX_EX_REC_ACT_VS'
                        AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                        AND ffvl.enabled_flag = 'Y'
                        AND sysdate BETWEEN decode(ffvl.start_date_active, NULL, sysdate - 1, ffvl.start_date_active) AND decode
                        (ffvl.end_date_active, NULL, sysdate + 1, ffvl.end_date_active)
                        )*/
                      SELECT /*+ FULL(apsa) PARALLEL( apsa,4) */
                             /*+ FULL(araa) PARALLEL( araa,4) */
                              DISTINCT
                             l_org_name
                                 org,
                             acra.receipt_date,
                             NULL
                                 brand,
                             --araa.gl_date                      gl_date,
                             xal.accounting_date
                                 gl_date,
                             acra.receipt_number
                                 number1,
                             (CASE
                                  WHEN    cd.accounting_class_code =
                                          'WRITE_OFF'
                                       OR cd.accounting_class_code =
                                          'REVENUE'
                                       OR cd.accounting_class_code =
                                          'EDISC'
                                       OR cd.accounting_class_code =
                                          'UNEDISC'
                                  THEN
                                      NVL (
                                          NVL (-xal.entered_dr,
                                               xal.entered_cr),
                                          0)
                                  ELSE
                                      0
                              END)
                                 revenue_amt,           --Line Amount Adjusted
                             (CASE
                                  WHEN cd.accounting_class_code =
                                       'TAX'
                                  THEN
                                      NVL (
                                          NVL (-xal.entered_dr,
                                               xal.entered_cr),
                                          0)
                                  ELSE
                                      0
                              END)
                                 tax_amt,                --Tax Amount Adjusted
                             (CASE
                                  WHEN cd.accounting_class_code =
                                       'FREIGHT'
                                  THEN
                                      NVL (
                                          NVL (-xal.entered_dr,
                                               xal.entered_cr),
                                          0)
                                  ELSE
                                      0
                              END)
                                 frieght_amt,        --Freight Amount Adjusted
                             -- araa.RECEIVABLE_APPLICATION_ID,*/
                             xal.GL_SL_LINK_ID,
                             get_country_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 ship_country,
                             get_state_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 ship_state,
                             get_city_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 ship_county,
                             get_county_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 ship_city,
                             get_postal_code_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 zip_code,
                             l_rev_acct
                                 rev_acct,
                             p_company
                                 company
                        FROM     --ar_payment_schedules_all              apsa,
                                 --apps.ar_receivable_applications_all   araa,
                        apps.ar_cash_receipts_all acra,
                        ozf_claims_all oca,
                        (SELECT DISTINCT event_id, ledger_id, accounting_class_code,
                                         code_combination_id, SOURCE_ID_INT_1, ae_line_num,
                                         ae_header_id
                           FROM XXD_AR_EXT_SALES_EXTRACT_GT) cd,
                        xla_ae_lines xal,
                        xla_ae_headers xah,
                        xla_transaction_entities_upg xt
                       WHERE     1 = 1
                             --AND apsa.payment_schedule_id = araa.payment_schedule_id
                             --AND apsa.org_id = araa.org_id
                             --AND acra.receipt_number='031019-80295.84-CK88657'
                             --AND araa.code_combination_id=1715
                             AND acra.org_id = l_org_id
                             AND oca.receipt_id(+) = acra.cash_receipt_id
                             AND xt.entity_id = xah.entity_id
                             AND xt.application_id = 222
                             AND xah.application_id = 222
                             AND xal.application_id = 222
                             AND xt.entity_code <> 'TRANSACTIONS'
                             --AND oca.claim_id (+) = araa.secondary_application_ref_id
                             --AND araa.cash_receipt_id = apsa.cash_receipt_id
                             --AND araa.cash_receipt_id = acra.cash_receipt_id
                             --AND acra.org_id = l_org_id
                             AND oca.status_code(+) = 'CLOSED'
                             AND oca.org_id(+) = acra.org_id
                             --AND araa.code_combination_id = gcc.code_combination_id
                             --AND apsa.class = 'PMT'
                             -- AND apsa.status = 'OP' --1.3
                             --AND araa.status = 'ACTIVITY'
                             AND xal.accounting_date >=
                                 (SELECT start_date
                                    FROM gl.gl_periods
                                   WHERE     period_set_name = 'DO_FY_CALENDAR'
                                         AND period_name = l_period_from)
                             --  AND apsa.gl_date <= (
                             AND xal.accounting_date <=
                                 (SELECT end_date
                                    FROM gl.gl_periods
                                   WHERE     period_set_name = 'DO_FY_CALENDAR'
                                         AND period_name = l_period_to)
                             /*AND (CASE WHEN cd.accounting_class_code ='EDISC'
                                   THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                 WHEN cd.accounting_class_code ='UNEDISC'
                                   THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                 ELSE
              nvl(araa.line_applied, nvl(araa.amount_applied, 0))
              END)<>0
               AND (CASE WHEN oca.claim_class='DEDUCTION'
                           AND araa.status = 'ACTIVITY'
                                   THEN 1
                  WHEN oca.claim_class iS NULL
                    THEN 1
                ELSE 2
              END)=1*/
                             AND oca.claim_class(+) = 'DEDUCTION'
                             --AND araa.cash_receipt_id = acra.cash_receipt_id
                             AND cd.SOURCE_ID_INT_1 = acra.cash_receipt_id
                             AND l_additional_details = 'Y'
                             --AND araa.event_id = cd.event_id
                             --AND araa.set_of_books_id= cd.ledger_id
                             AND cd.ae_header_id = xal.ae_header_id
                             AND cd.ae_line_num = xal.ae_line_num
                             AND xah.ae_header_id = xal.ae_header_id
                             AND xal.CODE_COMBINATION_ID =
                                 cd.code_combination_id) ad --,location loc--, location loc1
               WHERE     1 = 1
                     AND NVL (ad.ship_state, 'X') =
                         NVL (l_state, NVL (ad.ship_state, 'X'))
            --and ad.bill_to_site_use_id=loc.site_use_id
            --    and ad.ship_to_site_use_id=loc1.site_use_id(+)
            GROUP BY ad.number1, ad.company, ad.ship_country,
                     ad.ship_state, ad.ship_county, ad.ship_city,
                     ad.zip_code, ad.org, ad.trx_date,
                     ad.brand, ad.rev_acct, ad.gl_date;

        -- Start of Change for CCR0008395

        CURSOR C3 (l_period_from IN VARCHAR2, l_period_to IN VARCHAR2, l_code_combination_id NUMBER, l_segment6 VARCHAR2, l_additional_details IN VARCHAR2, l_rev_acct VARCHAR2
                   , l_enabled_flag VARCHAR2, l_segment2 VARCHAR2) --,l_include_adjustments IN VARCHAR2)
        IS
            SELECT abc.company,
                   abc.org,
                   abc.brand,
                   abc.ship_country,
                   abc.ship_state,
                   abc.rev_acct,
                   (SELECT period_name
                      FROM gl.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND gl_date BETWEEN start_date AND end_date)
                       gl_date1,
                   NULL
                       min_trx_date,
                   NULL
                       max_trx_date,
                   (abc.revenue_amt) * -1
                       sum_rev_amt,
                   NULL
                       sum_tax_amt,
                   NULL
                       sum_frieght_amt,
                   abc.ship_county,
                   abc.ship_city,
                   NULL
                       zip_code
              FROM (SELECT /*+ FULL(gjh) PARALLEL( gjh,4) */
                           /*+ index(gjl GL_JE_LINES_N1) */
                            /*+ FULL(gjl) PARALLEL(gjl, 4)*/
                           p_company
                               company,
                           NULL
                               ship_to_site_use_id,
                           NULL
                               org,
                           NULL
                               trx_date,
                           (SELECT description
                              FROM fnd_flex_values_vl
                             WHERE     flex_value_set_id = 1015912
                                   AND flex_value = l_segment2
                                   AND enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           start_date_active,
                                                           SYSDATE)
                                                   AND NVL (end_date_active,
                                                            SYSDATE + 1))
                               brand,
                           NULL
                               bill_city,
                           NULL
                               bill_state,
                           NULL
                               bill_county,
                           NULL
                               bill_country_code,
                           NULL
                               bill_postal_code,
                           'MJ'
                               bill_country,
                           (   (SELECT name
                                  FROM gl_ledgers
                                 WHERE ledger_id = gjh.ledger_id)
                            || ' - '
                            || gjh.name
                            || ' - '
                            || gjl.description)
                               ship_city,
                           NULL
                               ship_state,
                           NULL
                               ship_county,
                           NULL
                               ship_country_code,
                           NULL
                               ship_postal_code,
                           'MJ'
                               ship_country,
                           l_rev_acct
                               rev_acct,
                           gjh.default_effective_date
                               gl_date,
                           NVL (gjl.accounted_dr, 0) - NVL (accounted_cr, 0)
                               revenue_amt,
                           NULL
                               tax_amt,
                           NULL
                               frieght_amt
                      FROM apps.gl_je_headers gjh, apps.gl_je_lines gjl
                     WHERE     1 = 1
                           AND EXISTS
                                   (SELECT 1
                                      FROM apps.gl_ledger_config_details gcd
                                     WHERE     gcd.object_id = gjh.ledger_id
                                           AND gcd.object_type_code =
                                               'PRIMARY'
                                           AND gcd.status_code = 'CONFIRMED'
                                           AND gcd.setup_step_code = 'NONE')
                           AND gjh.status = 'P'
                           AND gjh.default_effective_date BETWEEN (SELECT start_date
                                                                     FROM gl.gl_periods
                                                                    WHERE     period_set_name =
                                                                              'DO_FY_CALENDAR'
                                                                          AND period_name =
                                                                              l_period_from)
                                                              AND (SELECT end_date
                                                                     FROM gl.gl_periods
                                                                    WHERE     period_set_name =
                                                                              'DO_FY_CALENDAR'
                                                                          AND period_name =
                                                                              l_period_to)
                           AND gjh.je_header_id = gjl.je_header_id
                           AND gjh.ledger_id IN
                                   (SELECT DISTINCT ledger_id
                                      FROM apps.XLE_ENTITY_PROFILES LEP, apps.XLE_REGISTRATIONS REG, apps.HR_LOCATIONS_ALL HRL,
                                           apps.gl_ledgers gl, apps.HR_OPERATING_UNITS HRO
                                     WHERE     LEP.TRANSACTING_ENTITY_FLAG =
                                               'Y'
                                           AND LEP.LEGAL_ENTITY_ID =
                                               REG.SOURCE_ID
                                           AND REG.SOURCE_TABLE =
                                               'XLE_ENTITY_PROFILES'
                                           AND lep.LEGAL_ENTITY_IDENTIFIER =
                                               p_company
                                           AND HRL.LOCATION_ID =
                                               REG.LOCATION_ID
                                           AND REG.IDENTIFYING_FLAG = 'Y'
                                           AND HRO.SET_OF_BOOKS_ID =
                                               GL.LEDGER_ID
                                           AND LEP.LEGAL_ENTITY_ID =
                                               HRO.DEFAULT_LEGAL_CONTEXT_ID)
                           AND EXISTS
                                   (SELECT 1
                                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                     WHERE     1 = 1
                                           AND ffvs.flex_value_set_id =
                                               ffvl.flex_value_set_id
                                           AND ffvl.enabled_flag = 'Y'
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffvl.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   ffvl.end_date_active,
                                                                     SYSDATE
                                                                   + 1)
                                           AND ffvs.flex_value_set_name =
                                               'XXD_AR_EXT_SALES_ORD_GJE_VS'
                                           AND gjh.je_source =
                                               ffvl.attribute1
                                           AND gjh.je_category =
                                               ffvl.attribute2)
                           AND gjl.code_combination_id =
                               l_code_combination_id
                           AND l_enabled_flag = 'Y'
                           AND l_additional_details = 'Y') abc
             WHERE abc.company = p_company;

        CURSOR c5 (l_period_from          IN VARCHAR2,
                   l_period_to            IN VARCHAR2,
                   l_additional_details   IN VARCHAR2,
                   l_company              IN VARCHAR2,
                   l_from_revenue_acct    IN VARCHAR2,
                   l_to_revenue_acct      IN VARCHAR2) --,l_include_adjustments IN VARCHAR2)
        IS
              SELECT abc.company, abc.org, abc.brand,
                     abc.ship_country, abc.ship_state, abc.rev_acct,
                     abc.gl_date gl_date1, NULL min_trx_date, NULL max_trx_date,
                     SUM (abc.revenue_amt) sum_rev_amt, NULL sum_tax_amt, NULL sum_frieght_amt,
                     abc.ship_county, abc.ship_city, NULL zip_code
                FROM (SELECT p_company
                                 company,
                             NULL
                                 ship_to_site_use_id,
                             NULL
                                 org,
                             NULL
                                 trx_date,
                             (SELECT description
                                FROM fnd_flex_values_vl
                               WHERE     flex_value_set_id = 1015912
                                     AND flex_value = a.segment2
                                     AND enabled_flag = 'Y'
                                     AND SYSDATE BETWEEN NVL (
                                                             start_date_active,
                                                             SYSDATE)
                                                     AND NVL (end_date_active,
                                                              SYSDATE + 1))
                                 brand,
                             NULL
                                 bill_city,
                             NULL
                                 bill_state,
                             NULL
                                 bill_county,
                             NULL
                                 bill_country_code,
                             NULL
                                 bill_postal_code,
                             'VT'
                                 bill_country,
                             NULL
                                 ship_city,
                             NULL
                                 ship_state,
                             NULL
                                 ship_county,
                             NULL
                                 ship_country_code,
                             NULL
                                 ship_postal_code,
                             'VT'
                                 ship_country,
                             (a.segment1 || '.' || a.segment2 || '.' || a.segment3 || '.' || a.segment4 || '.' || a.segment5 || '.' || a.segment6 || '.' || a.segment7 || '.' || a.segment8)
                                 rev_acct,
                             (SELECT period_name
                                FROM gl.gl_periods
                               WHERE     period_set_name = 'DO_FY_CALENDAR'
                                     AND a.accounting_date BETWEEN start_date
                                                               AND end_date)
                                 gl_date,
                             -1 * (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                 revenue_amt,
                             NULL
                                 tax_amt,
                             NULL
                                 frieght_amt
                        FROM xxcp.xxcp_process_history a --, xxcp.xxcp_mtl_material_transactions b, XXCP_TRANSACTION_HEADER c
                       WHERE     1 = 1
                             AND segment6 BETWEEN NVL (p_from_revenue_acct,
                                                       segment6)
                                              AND NVL (p_to_revenue_acct,
                                                       segment6) --in  ('42100','42101')
                             AND segment6 IN ('42100', '42101')
                             --and b.vt_transaction_ref = 103657251
                             AND segment1 = p_company
                             --and a.interface_id = b.vt_interface_id
                             AND l_additional_details = 'Y'
                             --and b.vt_transaction_ref = c.transaction_ref1
                             AND accounting_date BETWEEN (SELECT start_date
                                                            FROM gl.gl_periods
                                                           WHERE     period_set_name =
                                                                     'DO_FY_CALENDAR'
                                                                 AND period_name =
                                                                     l_period_from)
                                                     AND (SELECT end_date
                                                            FROM gl.gl_periods
                                                           WHERE     period_set_name =
                                                                     'DO_FY_CALENDAR'
                                                                 AND period_name =
                                                                     l_period_to))
                     abc
               WHERE abc.company = p_company
            GROUP BY abc.company, abc.brand, abc.rev_acct,
                     abc.ship_country, abc.ship_state, abc.gl_date;

        -- Additional details 'N'
        CURSOR c2 (l_org_id                IN NUMBER,
                   l_org_name              IN VARCHAR2,
                   l_period_from           IN VARCHAR2,
                   l_period_to             IN VARCHAR2,
                   l_code_combination_id      NUMBER,
                   l_ledger_id                NUMBER,
                   l_state                 IN VARCHAR2,
                   l_segment6                 NUMBER,
                   l_additional_details    IN VARCHAR2,
                   l_rev_acct                 VARCHAR2,
                   l_enabled_flag             VARCHAR2,
                   l_segment2                 NUMBER) --,l_include_adjustments IN VARCHAR2)
        IS
              SELECT ad.company, ad.org, ad.brand,
                     ad.ship_country, ad.ship_state, ad.rev_acct,
                     ad.gl_date, SUM (ad.revenue_amt) total_rev_amt, SUM (ad.tax_amt) total_tax_amt,
                     SUM (ad.frieght_amt) total_frieght_amt
                FROM (  SELECT l_org_name org, rct.trx_date, rct.attribute5 brand,
                               cd.accounting_date gl_date, rct.trx_number number1, DECODE (rctl.line_type, 'LINE', SUM (rctl.extended_amount), 0) revenue_amt, --1.3
                               DECODE (rctl.line_type, 'TAX', SUM (rctl.extended_amount), 0) tax_amt, --1.3
                                                                                                      DECODE (rctl.line_type, 'FREIGHT', SUM (rctl.extended_amount), 0) frieght_amt --1.3
                                                                                                                                                                                   , NULL RECEIVABLE_APPLICATION_ID,
                               get_country_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_country, get_state_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_state, get_city_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_county,
                               get_county_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_city, get_postal_code_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) zip_code, l_rev_acct rev_acct,
                               p_company company
                          FROM apps.ra_customer_trx_lines_all rctl, apps.ra_customer_trx_all rct, XXD_AR_EXT_SALES_EXTRACT_GT cd
                         WHERE     1 = 1
                               AND rct.org_id = l_org_id
                               AND rct.complete_flag = 'Y'
                               AND rct.customer_trx_id = rctl.customer_trx_id
                               AND rctl.line_type IN ('LINE', 'TAX', 'FREIGHT')
                               AND rctl.customer_trx_id = cd.source_id_int_1
                               AND l_additional_details = 'N'
                               AND cd.accounting_class_code IN
                                       (SELECT ffvl.flex_value
                                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                         WHERE     1 = 1
                                               AND ffvs.flex_value_set_name =
                                                   'XXD_AR_EVENT_CLASS_CODE_VS'
                                               AND ffvs.flex_value_set_id =
                                                   ffvl.flex_value_set_id
                                               AND ffvl.enabled_flag = 'Y'
                                               AND SYSDATE BETWEEN NVL (
                                                                       ffvl.start_date_active,
                                                                       SYSDATE)
                                                               AND NVL (
                                                                       ffvl.end_date_active,
                                                                         SYSDATE
                                                                       + 1)) --Added for change 1.1
                               AND EXISTS
                                       (SELECT /*+ index(xdl XLA_DISTRIBUTION_LINKS_N1) */
                                               1
                                          FROM apps.XLA_DISTRIBUTION_LINKS xdl, apps.ra_cust_trx_line_gl_dist_all gld
                                         WHERE     1 = 1
                                               AND xdl.application_id = 222
                                               AND xdl.source_distribution_type =
                                                   UPPER (
                                                       'ra_cust_trx_line_gl_dist_all')
                                               AND gld.cust_trx_line_gl_dist_id =
                                                   xdl.source_distribution_id_num_1
                                               AND cd.event_id = xdl.event_id
                                               AND gld.account_class IN
                                                       ('REV', 'FREIGHT') -- Added as per CCR0008395
                                               AND gld.account_set_flag = 'N'
                                               AND rctl.customer_trx_line_id =
                                                   gld.customer_trx_line_id
                                               AND gld.event_id = cd.event_id
                                               AND gld.set_of_books_id =
                                                   cd.ledger_id
                                               AND xdl.ae_line_num =
                                                   cd.ae_line_num
                                               AND xdl.ae_header_id =
                                                   cd.ae_header_id)
                               AND EXISTS
                                       (SELECT 1
                                          FROM fnd_lookup_values flv
                                         WHERE     flv.lookup_type =
                                                   'XXDOAR036_TAX_ACCOUNTS'
                                               AND flv.language =
                                                   USERENV ('LANG')
                                               AND flv.enabled_flag = 'Y'
                                               AND flv.lookup_code = l_segment6)
                      GROUP BY L_org_NAME, rct.trx_date, rctl.line_type,
                               rct.attribute5, cd.accounting_date, rct.trx_number,
                               rct.bill_to_site_use_id, rct.ship_to_site_use_id
                        HAVING SUM (rctl.extended_amount) <> 0
                      UNION ALL
                      SELECT DISTINCT l_org_name org, rct.trx_date, rct.attribute5 brand,
                                      ara.gl_date gl_date, ara.adjustment_number number1, NVL (ara.line_adjusted, 0) revenue_amt,
                                      NVL (ara.tax_adjusted, 0) tax_amt, NVL (ara.freight_adjusted, 0) frieght_amt, NULL RECEIVABLE_APPLICATION_ID,
                                      get_country_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_country, get_state_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_state, get_city_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_county,
                                      get_county_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) ship_city, get_postal_code_details (NVL (rct.ship_to_site_use_id, rct.bill_to_site_use_id)) zip_code, l_rev_acct rev_acct,
                                      p_company company
                        FROM apps.ar_adjustments_all ara,
                             apps.ra_customer_trx_all rct,
                             (SELECT DISTINCT event_id, ledger_id, accounting_class_code,
                                              source_id_int_1, code_combination_id
                                FROM XXD_AR_EXT_SALES_EXTRACT_GT) cd
                       WHERE     1 = 1
                             AND rct.complete_flag = 'Y'
                             AND cd.code_combination_id =
                                 ara.CODE_COMBINATION_ID
                             AND cd.ledger_id = ara.set_of_books_id
                             AND cd.accounting_class_code = 'ADJ'
                             AND cd.event_id = ARA.EVENT_ID
                             AND l_additional_details = 'N'
                             AND ara.gl_date >=
                                 (SELECT start_date
                                    FROM gl.gl_periods
                                   WHERE     period_set_name = 'DO_FY_CALENDAR'
                                         AND period_name = l_period_from)
                             AND ara.gl_date <=
                                 (SELECT end_date
                                    FROM gl.gl_periods
                                   WHERE     period_set_name = 'DO_FY_CALENDAR'
                                         AND period_name = l_period_to)
                             AND ara.customer_trx_id = rct.customer_trx_id
                             AND rct.org_id = l_org_id
                             AND ara.adjustment_id = cd.source_id_int_1
                             AND EXISTS
                                     (SELECT 1
                                        FROM fnd_lookup_values flv
                                       WHERE     flv.lookup_type =
                                                 'XXDOAR036_TAX_ACCOUNTS'
                                             AND flv.language =
                                                 USERENV ('LANG')
                                             AND flv.enabled_flag = 'Y'
                                             AND flv.lookup_code = l_segment6)
                      /*UNION ALL
                               SELECT /*+ FULL(apsa) PARALLEL( apsa,4) */
                      /*+ FULL(araa) PARALLEL( araa,4) */
                      /*DISTINCT
                                        l_org_name                         org,
                                          rct.trx_date,
                                          rct.attribute5                    brand,
                                          apsa.gl_date                      gl_date,
                                          acra.receipt_number number1,
                                         (CASE WHEN cd.accounting_class_code ='EDISC'
                                                THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                              WHEN cd.accounting_class_code ='UNEDISC'
                                                THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                              ELSE
                           nvl(araa.line_applied, nvl(araa.amount_applied, 0))
                           END)  revenue_amt, --Line Amount Adjusted
                                          nvl(araa.tax_applied, 0) tax_amt, --Tax Amount Adjusted
                                          nvl(araa.freight_applied, 0) frieght_amt  ,
                           araa.RECEIVABLE_APPLICATION_ID,
                                            get_country_details(NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) ship_country,
                            get_state_details (NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) ship_state,
                            get_city_details (NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) ship_county,
                            get_county_details(NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) ship_city,
                            get_postal_code_details (NVL(NVL(rct.ship_to_site_use_id,rct.bill_to_site_use_id),acra.customer_site_use_id)) zip_code ,
                           l_rev_acct rev_acct,
                            p_company company
                                      FROM
                                          apps.ar_cash_receipts_all             acra,
                                          apps.ar_payment_schedules_all         apsa,
                                          apps.ar_receivable_applications_all   araa,
                                            apps.ra_customer_trx_all rct,
                                            (select  distinct event_id,ledger_id,accounting_class_code,code_combination_id from XXD_AR_EXT_SALES_EXTRACT_GT ) cd
                                    WHERE
                                          1 = 1
                                          AND acra.cash_receipt_id = apsa.cash_receipt_id
                                           AND araa.cash_receipt_id = acra.cash_receipt_id
                                             AND araa.status in ('ACC','APP','OTHER ACC','UNAPP','ACTIVITY','UNID')
                                        --  AND nvl(l_include_adjustments, 'N') = 'Y'
                                          AND l_additional_details = 'Y'
                                         AND  rct.complete_flag = 'Y'
                                           AND apsa.gl_date >= (
                                              SELECT start_date FROM  gl.gl_periods  WHERE
                                                  period_set_name = 'DO_FY_CALENDAR'
                                                  AND period_name = l_period_from
                                          )
                                          AND apsa.gl_date <= (
                                              SELECT end_date FROM  gl.gl_periods
                                              WHERE    period_set_name = 'DO_FY_CALENDAR'
                                                  AND period_name = l_period_to
                                          )
                            AND (CASE WHEN cd.accounting_class_code ='EDISC'
                                                THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                              WHEN cd.accounting_class_code ='UNEDISC'
                                                THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                              ELSE
                           nvl(araa.line_applied, nvl(araa.amount_applied, 0))
                           END)<>0
                                          AND araa.org_id = l_org_id
                                          AND araa.applied_customer_trx_id = rct.customer_trx_id
                                          AND araa.event_id = cd.event_id
                                          AND araa.set_of_books_id= cd.ledger_id*/
                      --AND araa.CODE_COMBINATION_ID=cd.code_combination_id
                      UNION ALL
                      /* SELECT /*+ FULL(apsa) PARALLEL( apsa,4) */
                      /*+ FULL(araa) PARALLEL( araa,4) */
                      /*DISTINCT
                                         l_org_name                          org,
                                         acra.receipt_date,
                                         NULL brand,
                                         araa.gl_date                      gl_date,
                                         acra.receipt_number number1,
                                         (CASE WHEN cd.accounting_class_code ='EDISC'
                                               THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                             WHEN cd.accounting_class_code ='UNEDISC'
                                               THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                             ELSE
                          nvl(araa.line_applied, nvl(araa.amount_applied, 0))
                          END) revenue_amt, --Line Amount Adjusted
                                         nvl(araa.tax_applied, 0) tax_amt, --Tax Amount Adjusted
                                         nvl(araa.freight_applied, 0) frieght_amt, --Freight Amount Adjusted
                                         araa.RECEIVABLE_APPLICATION_ID,
                           get_country_details(acra.customer_site_use_id) ship_country,
                           get_state_details (acra.customer_site_use_id) ship_state,
                           get_city_details (acra.customer_site_use_id) ship_county,
                           get_county_details( acra.customer_site_use_id) ship_city,
                           get_postal_code_details (acra.customer_site_use_id) zip_code ,

                          l_rev_acct rev_acct,
                           p_company company
                                 FROM
                                         ar_payment_schedules_all              apsa,
                                          apps.ar_receivable_applications_all   araa,
                                          apps.ar_cash_receipts_all             acra,
                                         ozf_claims_all                        oca,
                                           (select  distinct event_id,ledger_id,accounting_class_code,code_combination_id from XXD_AR_EXT_SALES_EXTRACT_GT ) cd
                                 WHERE 1=1
                                        AND apsa.payment_schedule_id = araa.payment_schedule_id
                                         AND apsa.org_id = araa.org_id
                                          AND  apsa.org_id=l_org_id
                                         AND oca.receipt_id (+) = araa.cash_receipt_id
                                         AND oca.claim_id (+) = araa.secondary_application_ref_id
                                         AND araa.cash_receipt_id = apsa.cash_receipt_id
                                         AND araa.cash_receipt_id = acra.cash_receipt_id
                                         AND acra.org_id = l_org_id
                                         AND oca.status_code (+) = 'CLOSED'
                                         AND oca.org_id (+) = araa.org_id
                                         --AND araa.code_combination_id = gcc.code_combination_id
                                          AND apsa.class = 'PMT'
                                        -- AND apsa.status = 'OP' --1.3
                                         AND araa.status = 'ACTIVITY'
                                        -- AND apsa.gl_date >= (
                                          AND araa.gl_date>=(   SELECT start_date
                                                                 FROM  gl.gl_periods
                                                                 WHERE period_set_name = 'DO_FY_CALENDAR'
                                                                 AND period_name = l_period_from
                                         )
                                       --  AND apsa.gl_date <= (
                                         AND araa.gl_date<=(    SELECT  end_date
                                                                 FROM  gl.gl_periods
                                                                 WHERE period_set_name = 'DO_FY_CALENDAR'
                                                                     AND period_name = l_period_to
                                                            )
                                         AND (CASE WHEN cd.accounting_class_code ='EDISC'
                                               THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                             WHEN cd.accounting_class_code ='UNEDISC'
                                               THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                             ELSE
                          nvl(araa.line_applied, nvl(araa.amount_applied, 0))
                          END)<>0
                           AND (CASE WHEN oca.claim_class='DEDUCTION'
                                       AND araa.status = 'ACTIVITY'
                                               THEN 1
                              WHEN oca.claim_class iS NULL
                                THEN 1
                            ELSE 2
                          END)=1
                            AND oca.claim_class(+) = 'DEDUCTION'
                                         AND araa.cash_receipt_id = acra.cash_receipt_id
                                        AND l_additional_details             ='Y'
                                         AND araa.event_id = cd.event_id
                                         AND araa.set_of_books_id= cd.ledger_id
                                         AND araa.CODE_COMBINATION_ID=cd.code_combination_id
                                      AND NOT EXISTS (
                                             SELECT /*+ FULL(art) PARALLEL( art,4) */
                      /*  1
                    FROM
                        ar_receivables_trx_all   art,
                        fnd_flex_value_sets      ffvs,
                        fnd_flex_values_vl       ffvl
                    WHERE
                        art.name = ffvl.description
                        AND art.org_id = apsa.org_id
                        AND art.receivables_trx_id = araa.receivables_trx_id
                        AND ffvs.flex_value_set_name = 'XXD_ZX_CAN_TAX_EX_REC_ACT_VS'
                        AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                        AND ffvl.enabled_flag = 'Y'
                        AND sysdate BETWEEN decode(ffvl.start_date_active, NULL, sysdate - 1, ffvl.start_date_active) AND decode
                        (ffvl.end_date_active, NULL, sysdate + 1, ffvl.end_date_active)
                        )*/
                      SELECT /*+ FULL(apsa) PARALLEL( apsa,4) */
                             /*+ FULL(araa) PARALLEL( araa,4) */
                              DISTINCT
                             l_org_name
                                 org,
                             acra.receipt_date,
                             NULL
                                 brand,
                             --araa.gl_date                      gl_date,
                             xal.accounting_date
                                 gl_date,
                             acra.receipt_number
                                 number1,
                             (CASE
                                  WHEN    cd.accounting_class_code =
                                          'WRITE_OFF'
                                       OR cd.accounting_class_code =
                                          'REVENUE'
                                       OR cd.accounting_class_code =
                                          'EDISC'
                                       OR cd.accounting_class_code =
                                          'UNEDISC'
                                  THEN
                                      NVL (
                                          NVL (-xal.entered_dr,
                                               xal.entered_cr),
                                          0)
                                  ELSE
                                      0
                              END)
                                 revenue_amt,           --Line Amount Adjusted
                             (CASE
                                  WHEN cd.accounting_class_code =
                                       'TAX'
                                  THEN
                                      NVL (
                                          NVL (-xal.entered_dr,
                                               xal.entered_cr),
                                          0)
                                  ELSE
                                      0
                              END)
                                 tax_amt,                --Tax Amount Adjusted
                             (CASE
                                  WHEN cd.accounting_class_code =
                                       'FREIGHT'
                                  THEN
                                      NVL (
                                          NVL (-xal.entered_dr,
                                               xal.entered_cr),
                                          0)
                                  ELSE
                                      0
                              END)
                                 frieght_amt,        --Freight Amount Adjusted
                             -- araa.RECEIVABLE_APPLICATION_ID,*/
                             xal.GL_SL_LINK_ID,
                             get_country_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 ship_country,
                             get_state_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 ship_state,
                             get_city_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 ship_county,
                             get_county_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 ship_city,
                             get_postal_code_details (
                                 NVL (acra.customer_site_use_id,
                                      oca.cust_billto_acct_site_id))
                                 zip_code,
                             l_rev_acct
                                 rev_acct,
                             p_company
                                 company
                        FROM     --ar_payment_schedules_all              apsa,
                                 --apps.ar_receivable_applications_all   araa,
                        apps.ar_cash_receipts_all acra,
                        ozf_claims_all oca,
                        (SELECT DISTINCT event_id, ledger_id, accounting_class_code,
                                         code_combination_id, SOURCE_ID_INT_1, ae_line_num,
                                         ae_header_id
                           FROM XXD_AR_EXT_SALES_EXTRACT_GT) cd,
                        xla_ae_lines xal,
                        xla_ae_headers xah,
                        xla_transaction_entities_upg xt
                       WHERE     1 = 1
                             --AND apsa.payment_schedule_id = araa.payment_schedule_id
                             --AND apsa.org_id = araa.org_id
                             --AND acra.receipt_number='031019-80295.84-CK88657'
                             --AND araa.code_combination_id=1715
                             AND acra.org_id = l_org_id
                             AND oca.receipt_id(+) = acra.cash_receipt_id
                             AND xt.entity_id = xah.entity_id
                             AND xt.application_id = 222
                             AND xah.application_id = 222
                             AND xal.application_id = 222
                             AND xt.entity_code <> 'TRANSACTIONS'
                             --AND oca.claim_id (+) = araa.secondary_application_ref_id
                             --AND araa.cash_receipt_id = apsa.cash_receipt_id
                             --AND araa.cash_receipt_id = acra.cash_receipt_id
                             --AND acra.org_id = l_org_id
                             AND oca.status_code(+) = 'CLOSED'
                             AND oca.org_id(+) = acra.org_id
                             --AND araa.code_combination_id = gcc.code_combination_id
                             --AND apsa.class = 'PMT'
                             -- AND apsa.status = 'OP' --1.3
                             --AND araa.status = 'ACTIVITY'
                             AND xal.accounting_date >=
                                 (SELECT start_date
                                    FROM gl.gl_periods
                                   WHERE     period_set_name = 'DO_FY_CALENDAR'
                                         AND period_name = l_period_from)
                             --  AND apsa.gl_date <= (
                             AND xal.accounting_date <=
                                 (SELECT end_date
                                    FROM gl.gl_periods
                                   WHERE     period_set_name = 'DO_FY_CALENDAR'
                                         AND period_name = l_period_to)
                             /*AND (CASE WHEN cd.accounting_class_code ='EDISC'
                                   THEN NVL(araa.EARNED_DISCOUNT_TAKEN,0)
                 WHEN cd.accounting_class_code ='UNEDISC'
                                   THEN NVL(araa.UNEARNED_DISCOUNT_TAKEN,0)
                 ELSE
              nvl(araa.line_applied, nvl(araa.amount_applied, 0))
              END)<>0
               AND (CASE WHEN oca.claim_class='DEDUCTION'
                           AND araa.status = 'ACTIVITY'
                                   THEN 1
                  WHEN oca.claim_class iS NULL
                    THEN 1
                ELSE 2
              END)=1*/
                             AND oca.claim_class(+) = 'DEDUCTION'
                             --AND araa.cash_receipt_id = acra.cash_receipt_id
                             AND cd.SOURCE_ID_INT_1 = acra.cash_receipt_id
                             AND l_additional_details = 'N'
                             --AND araa.event_id = cd.event_id
                             --AND araa.set_of_books_id= cd.ledger_id
                             AND cd.ae_header_id = xal.ae_header_id
                             AND cd.ae_line_num = xal.ae_line_num
                             AND xah.ae_header_id = xal.ae_header_id
                             AND xal.CODE_COMBINATION_ID =
                                 cd.code_combination_id) ad
               WHERE     1 = 1
                     AND NVL (ad.ship_state, 'X') =
                         NVL (l_state, NVL (ad.ship_state, 'X'))
            GROUP BY ad.company, ad.org, ad.brand,
                     ad.ship_country, ad.ship_state, ad.rev_acct,
                     ad.gl_date;

        -- Start of Change CCR0008395
        CURSOR C4 (l_period_from IN VARCHAR2, l_period_to IN VARCHAR2, l_code_combination_id NUMBER, l_segment6 VARCHAR2, l_additional_details IN VARCHAR2, l_rev_acct VARCHAR2
                   , l_enabled_flag VARCHAR2, l_segment2 VARCHAR2) --,l_include_adjustments IN VARCHAR2)
        IS
            SELECT abc.company,
                   abc.org,
                   abc.brand,
                   abc.ship_country,
                   abc.ship_state,
                   abc.rev_acct,
                   (SELECT period_name
                      FROM gl.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND gl_date BETWEEN start_date AND end_date)
                       gl_date1,
                   (abc.revenue_amt) * -1
                       total_rev_amt,
                   NULL
                       total_tax_amt,
                   NULL
                       total_frieght_amt
              FROM (SELECT /*+ FULL(gjh) PARALLEL( gjh,4) */
                           /*+ index(gjl GL_JE_LINES_N1) */
                            /*+ FULL(gjl) PARALLEL(gjl, 4)*/
                           p_company
                               company,
                           NULL
                               ship_to_site_use_id,
                           NULL
                               org,
                           NULL
                               trx_date,
                           (SELECT description
                              FROM fnd_flex_values_vl
                             WHERE     flex_value_set_id = 1015912
                                   AND flex_value = l_segment2
                                   AND enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           start_date_active,
                                                           SYSDATE)
                                                   AND NVL (end_date_active,
                                                            SYSDATE + 1))
                               brand,
                           NULL
                               bill_city,
                           NULL
                               bill_state,
                           NULL
                               bill_county,
                           NULL
                               bill_country_code,
                           NULL
                               bill_postal_code,
                           'MJ'
                               bill_country,
                           (   (SELECT name
                                  FROM gl_ledgers
                                 WHERE ledger_id = gjh.ledger_id)
                            || ' - '
                            || gjh.name
                            || ' - '
                            || gjl.description)
                               ship_city,
                           NULL
                               ship_state,
                           NULL
                               ship_county,
                           NULL
                               ship_country_code,
                           NULL
                               ship_postal_code,
                           'MJ'
                               ship_country,
                           l_rev_acct
                               rev_acct,
                           gjh.default_effective_date
                               gl_date,
                           NVL (gjl.accounted_dr, 0) - NVL (accounted_cr, 0)
                               revenue_amt,
                           NULL
                               tax_amt,
                           NULL
                               frieght_amt
                      FROM apps.gl_je_headers gjh, apps.gl_je_lines gjl
                     WHERE     1 = 1
                           AND EXISTS
                                   (SELECT 1
                                      FROM apps.gl_ledger_config_details gcd
                                     WHERE     gcd.object_id = gjh.ledger_id
                                           AND gcd.object_type_code =
                                               'PRIMARY'
                                           AND gcd.status_code = 'CONFIRMED'
                                           AND gcd.setup_step_code = 'NONE')
                           AND gjh.status = 'P'
                           AND gjh.default_effective_date BETWEEN (SELECT start_date
                                                                     FROM gl.gl_periods
                                                                    WHERE     period_set_name =
                                                                              'DO_FY_CALENDAR'
                                                                          AND period_name =
                                                                              l_period_from)
                                                              AND (SELECT end_date
                                                                     FROM gl.gl_periods
                                                                    WHERE     period_set_name =
                                                                              'DO_FY_CALENDAR'
                                                                          AND period_name =
                                                                              l_period_to)
                           AND gjh.je_header_id = gjl.je_header_id
                           AND gjh.ledger_id IN
                                   (SELECT DISTINCT ledger_id
                                      FROM apps.XLE_ENTITY_PROFILES LEP, apps.XLE_REGISTRATIONS REG, apps.HR_LOCATIONS_ALL HRL,
                                           apps.gl_ledgers gl, apps.HR_OPERATING_UNITS HRO
                                     WHERE     LEP.TRANSACTING_ENTITY_FLAG =
                                               'Y'
                                           AND LEP.LEGAL_ENTITY_ID =
                                               REG.SOURCE_ID
                                           AND REG.SOURCE_TABLE =
                                               'XLE_ENTITY_PROFILES'
                                           AND lep.LEGAL_ENTITY_IDENTIFIER =
                                               p_company
                                           AND HRL.LOCATION_ID =
                                               REG.LOCATION_ID
                                           AND REG.IDENTIFYING_FLAG = 'Y'
                                           AND HRO.SET_OF_BOOKS_ID =
                                               GL.LEDGER_ID
                                           AND LEP.LEGAL_ENTITY_ID =
                                               HRO.DEFAULT_LEGAL_CONTEXT_ID)
                           AND EXISTS
                                   (SELECT 1
                                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                                     WHERE     1 = 1
                                           AND ffvs.flex_value_set_id =
                                               ffvl.flex_value_set_id
                                           AND ffvl.enabled_flag = 'Y'
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffvl.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   ffvl.end_date_active,
                                                                     SYSDATE
                                                                   + 1)
                                           AND ffvs.flex_value_set_name =
                                               'XXD_AR_EXT_SALES_ORD_GJE_VS'
                                           AND gjh.je_source =
                                               ffvl.attribute1
                                           AND gjh.je_category =
                                               ffvl.attribute2)
                           AND gjl.code_combination_id =
                               l_code_combination_id
                           AND l_enabled_flag = 'Y'
                           AND l_additional_details = 'N') abc
             WHERE abc.company = p_company;

        CURSOR c6 (l_period_from          IN VARCHAR2,
                   l_period_to            IN VARCHAR2,
                   l_additional_details   IN VARCHAR2,
                   l_company              IN VARCHAR2,
                   l_from_revenue_acct    IN VARCHAR2,
                   l_to_revenue_acct      IN VARCHAR2) --,l_include_adjustments IN VARCHAR2)
        IS
              SELECT abc.company, abc.org, abc.brand,
                     abc.ship_country, abc.ship_state, abc.rev_acct,
                     abc.gl_date gl_date1, NULL min_trx_date, NULL max_trx_date,
                     SUM (abc.revenue_amt) sum_rev_amt, NULL sum_tax_amt, NULL sum_frieght_amt,
                     abc.ship_county, abc.ship_city, NULL zip_code
                FROM (SELECT p_company
                                 company,
                             NULL
                                 ship_to_site_use_id,
                             NULL
                                 org,
                             NULL
                                 trx_date,
                             (SELECT description
                                FROM fnd_flex_values_vl
                               WHERE     flex_value_set_id = 1015912
                                     AND flex_value = a.segment2
                                     AND enabled_flag = 'Y'
                                     AND SYSDATE BETWEEN NVL (
                                                             start_date_active,
                                                             SYSDATE)
                                                     AND NVL (end_date_active,
                                                              SYSDATE + 1))
                                 brand,
                             NULL
                                 bill_city,
                             NULL
                                 bill_state,
                             NULL
                                 bill_county,
                             NULL
                                 bill_country_code,
                             NULL
                                 bill_postal_code,
                             'VT'
                                 bill_country,
                             NULL
                                 ship_city,
                             NULL
                                 ship_state,
                             NULL
                                 ship_county,
                             NULL
                                 ship_country_code,
                             NULL
                                 ship_postal_code,
                             'VT'
                                 ship_country,
                             (a.segment1 || '.' || a.segment2 || '.' || a.segment3 || '.' || a.segment4 || '.' || a.segment5 || '.' || a.segment6 || '.' || a.segment7 || '.' || a.segment8)
                                 rev_acct,
                             (SELECT period_name
                                FROM gl.gl_periods
                               WHERE     period_set_name = 'DO_FY_CALENDAR'
                                     AND a.accounting_date BETWEEN start_date
                                                               AND end_date)
                                 gl_date,
                             -1 * (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                                 revenue_amt,
                             NULL
                                 tax_amt,
                             NULL
                                 frieght_amt
                        FROM xxcp.xxcp_process_history a --, xxcp.xxcp_mtl_material_transactions b, XXCP_TRANSACTION_HEADER c
                       WHERE     1 = 1
                             AND segment6 BETWEEN NVL (p_from_revenue_acct,
                                                       segment6)
                                              AND NVL (p_to_revenue_acct,
                                                       segment6) --in  ('42100','42101')
                             AND segment6 IN ('42100', '42101')
                             --and b.vt_transaction_ref = 103657251
                             AND segment1 = p_company
                             --and a.interface_id = b.vt_interface_id
                             AND l_additional_details = 'N'
                             --and b.vt_transaction_ref = c.transaction_ref1
                             AND accounting_date BETWEEN (SELECT start_date
                                                            FROM gl.gl_periods
                                                           WHERE     period_set_name =
                                                                     'DO_FY_CALENDAR'
                                                                 AND period_name =
                                                                     l_period_from)
                                                     AND (SELECT end_date
                                                            FROM gl.gl_periods
                                                           WHERE     period_set_name =
                                                                     'DO_FY_CALENDAR'
                                                                 AND period_name =
                                                                     l_period_to))
                     abc
               WHERE abc.company = p_company
            GROUP BY abc.company, abc.brand, abc.rev_acct,
                     abc.ship_country, abc.ship_state, abc.gl_date;

        l_heading          VARCHAR2 (3000);
        l_line             VARCHAR2 (4000);
        l_sysdate          VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT LISTAGG (ffvl.flex_value, ',') WITHIN GROUP (ORDER BY ffvl.flex_value)
              INTO l_acc_class_code
              FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvl
             WHERE     1 = 1
                   AND ffvs.flex_value_set_name =
                       'XXD_ACCOUNTING_CLASS_CODE_VS'
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND ffvl.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN DECODE (ffvl.start_date_active,
                                               NULL, SYSDATE - 1,
                                               ffvl.start_date_active)
                                   AND DECODE (ffvl.end_date_active,
                                               NULL, SYSDATE + 1,
                                               ffvl.end_date_active);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_acc_class_code   := NULL;
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'error while fetching l_acc_class_code ' || SQLERRM);
                RAISE;
        END;

        BEGIN
            SELECT LISTAGG (period_name, ',') WITHIN GROUP (ORDER BY period_name)
              INTO l_period_name
              FROM gl.gl_periods
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND start_date >=
                       (SELECT start_date
                          FROM gl.gl_periods
                         WHERE     period_set_name = 'DO_FY_CALENDAR'
                               AND period_name = p_from_period)
                   AND end_date <=
                       (SELECT end_date
                          FROM gl.gl_periods
                         WHERE     period_set_name = 'DO_FY_CALENDAR'
                               AND period_name = p_to_period);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_period_name   := NULL;
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'error while fetching Period ' || SQLERRM);
        END;


        IF p_additional_details = 'Y'
        THEN
            l_heading   :=
                   'Company Name'
                || CHR (9)
                || 'Operating Unit'
                || CHR (9)
                || 'Brand'
                || CHR (9)
                || 'Ship To Country'
                || CHR (9)
                || 'Ship To State'
                || CHR (9)
                || 'Revenue Account'
                || CHR (9)
                || 'GL Date'
                || CHR (9)
                || 'Min Transaction Date'
                || CHR (9)
                || 'Max Transaction Date'
                || CHR (9)
                || 'Sum Revenue Amount'
                || CHR (9)
                || 'Sum Tax Amount'
                || CHR (9)
                || 'Sum Freight Amount'
                || CHR (9)
                || 'Ship To County'
                || CHR (9)
                || 'Ship To City'
                || CHR (9)
                || 'Zip Code';
            apps.fnd_file.put_line (apps.fnd_file.output, l_heading);

            FOR j
                IN c_main_details (p_company,
                                   p_from_revenue_acct,
                                   p_to_revenue_acct)
            LOOP
                lsql   := 'truncate table XXDO.XXD_AR_EXT_SALES_EXTRACT_GT';

                EXECUTE IMMEDIATE lsql;


                INSERT INTO XXD_AR_EXT_SALES_EXTRACT_GT
                    SELECT xal.ae_header_id, xal.ae_line_num, xah.ledger_id,
                           xah.event_id, xal.ACCOUNTING_CLASS_CODE, xte.source_id_int_1,
                           xal.code_combination_id, xte.entity_id, xah.accounting_date
                      FROM apps.XLA_AE_LINES xal, apps.XLA_AE_HEADERS xah, xla_transaction_entities_upg xte,
                           XLA_EVENTS xe
                     WHERE     1 = 1
                           AND xte.entity_id = xah.entity_id
                           AND xte.application_id = 222                   --AR
                           AND xe.event_id = xah.event_id
                           AND xe.entity_id = xah.entity_id
                           AND xe.event_status_code = 'P'
                           AND xe.application_id = 222
                           AND xah.application_id = 222
                           AND xal.application_id = 222
                           AND XAH.ae_header_id = XAL.ae_header_id
                           AND xal.application_id = xah.application_id
                           AND xal.ACCOUNTING_CLASS_CODE IN
                                   (    SELECT TRIM (
                                                   REGEXP_SUBSTR (
                                                       l_acc_class_code,
                                                       '[^,]+',
                                                       1,
                                                       LEVEL)) VALUE
                                          FROM DUAL
                                    CONNECT BY REGEXP_SUBSTR (l_acc_class_code, '[^,]+', 1
                                                              , LEVEL)
                                                   IS NOT NULL)
                           /*AND xal.ACCOUNTING_CLASS_CODE in ( SELECT ffvl.flex_value
                                                   FROM
                                                       fnd_flex_value_sets      ffvs,
                                                       fnd_flex_values_vl       ffvl
                                                   WHERE 1=1
                                                       AND ffvs.flex_value_set_name = 'XXD_ACCOUNTING_CLASS_CODE_VS'
                                                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                                                       AND ffvl.enabled_flag = 'Y'
                                                       AND sysdate BETWEEN decode(ffvl.start_date_active, NULL, sysdate - 1, ffvl.start_date_active)
                                                       AND decode (ffvl.end_date_active, NULL, sysdate + 1, ffvl.end_date_active) )*/
                           AND xal.code_combination_id =
                               j.code_combination_id
                           AND xah.ledger_id = j.SET_OF_BOOKS_ID
                           AND xah.period_name IN
                                   (    SELECT TRIM (
                                                   REGEXP_SUBSTR (
                                                       l_period_name,
                                                       '[^,]+',
                                                       1,
                                                       LEVEL)) VALUE
                                          FROM DUAL
                                    CONNECT BY REGEXP_SUBSTR (l_period_name, '[^,]+', 1
                                                              , LEVEL)
                                                   IS NOT NULL)         /*(SELECT period_name FROM gl.gl_periods
WHERE period_set_name = 'DO_FY_CALENDAR'
AND start_date>=(
SELECT start_date
FROM gl.gl_periods
WHERE period_set_name = 'DO_FY_CALENDAR'
AND period_name = p_from_period)
AND end_date <= (
SELECT end_date FROM gl.gl_periods
WHERE period_set_name = 'DO_FY_CALENDAR'
AND period_name = p_to_period))*/
                                                               ;

                COMMIT;

                BEGIN
                    SELECT COUNT (*)
                      INTO v_count
                      FROM XXD_AR_EXT_SALES_EXTRACT_GT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_count   := 0;
                END;



                IF v_count > 0
                THEN
                    FOR i IN c1 (j.ORGANIZATION_ID, j.name, p_from_period,
                                 p_to_period, j.code_combination_id, j.SET_OF_BOOKS_ID, p_state, j.segment6, p_additional_details
                                 , j.rev_acct, j.enabled_flag, j.segment2)
                    LOOP
                        l_line   :=
                               i.company
                            || CHR (9)
                            || i.org
                            || CHR (9)
                            || i.brand
                            || CHR (9)
                            || i.ship_country
                            || CHR (9)
                            || i.ship_state
                            || CHR (9)
                            || i.rev_acct
                            || CHR (9)
                            || i.gl_date1
                            || CHR (9)
                            || i.min_trx_date
                            || CHR (9)
                            || i.max_trx_date
                            || CHR (9)
                            || i.sum_rev_amt
                            || CHR (9)
                            || i.sum_tax_amt
                            || CHR (9)
                            || i.sum_frieght_amt
                            || CHR (9)
                            || i.ship_county
                            || CHR (9)
                            || i.ship_city
                            || CHR (9)
                            || i.zip_code;
                        apps.fnd_file.put_line (apps.fnd_file.output, l_line);
                    END LOOP;
                END IF;                                            -- v_count;

                BEGIN
                    SELECT COUNT (*)
                      INTO v_count
                      FROM fnd_lookup_values flv
                     WHERE     flv.lookup_type = 'XXDOAR036_TAX_ACCOUNTS'
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           AND flv.lookup_code = j.segment6;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_count   := 0;
                END;


                IF v_count > 0
                THEN
                    FOR i IN c3 (p_from_period, p_to_period, j.code_combination_id, j.segment6, p_additional_details, j.rev_acct
                                 , j.enabled_flag, j.segment2)
                    LOOP
                        l_line   :=
                               i.company
                            || CHR (9)
                            || i.org
                            || CHR (9)
                            || i.brand
                            || CHR (9)
                            || i.ship_country
                            || CHR (9)
                            || i.ship_state
                            || CHR (9)
                            || i.rev_acct
                            || CHR (9)
                            || i.gl_date1
                            || CHR (9)
                            || i.min_trx_date
                            || CHR (9)
                            || i.max_trx_date
                            || CHR (9)
                            || i.sum_rev_amt
                            || CHR (9)
                            || i.sum_tax_amt
                            || CHR (9)
                            || i.sum_frieght_amt
                            || CHR (9)
                            || i.ship_county
                            || CHR (9)
                            || i.ship_city
                            || CHR (9)
                            || i.zip_code;
                        apps.fnd_file.put_line (apps.fnd_file.output, l_line);
                    END LOOP;
                END IF;                                             -- v_count
            END LOOP;

            FOR i IN c5 (p_from_period, p_to_period, p_additional_details,
                         p_company, p_from_revenue_acct, p_to_revenue_acct)
            LOOP
                l_line   :=
                       i.company
                    || CHR (9)
                    || i.org
                    || CHR (9)
                    || i.brand
                    || CHR (9)
                    || i.ship_country
                    || CHR (9)
                    || i.ship_state
                    || CHR (9)
                    || i.rev_acct
                    || CHR (9)
                    || i.gl_date1
                    || CHR (9)
                    || i.min_trx_date
                    || CHR (9)
                    || i.max_trx_date
                    || CHR (9)
                    || i.sum_rev_amt
                    || CHR (9)
                    || i.sum_tax_amt
                    || CHR (9)
                    || i.sum_frieght_amt
                    || CHR (9)
                    || i.ship_county
                    || CHR (9)
                    || i.ship_city
                    || CHR (9)
                    || i.zip_code;
                apps.fnd_file.put_line (apps.fnd_file.output, l_line);
            END LOOP;
        END IF;

        IF p_additional_details = 'N'
        THEN
            l_heading   :=
                   'Company Name'
                || CHR (9)
                || 'Operating Unit'
                || CHR (9)
                || 'Brand'
                || CHR (9)
                || 'Ship To Country'
                || CHR (9)
                || 'Ship To State'
                || CHR (9)
                || 'Revenue Account'
                || CHR (9)
                || 'GL Date'
                || CHR (9)
                || 'Sum Revenue Amount'
                || CHR (9)
                || 'Sum Tax Amount'
                || CHR (9)
                || 'Sum Freight Amount';
            apps.fnd_file.put_line (apps.fnd_file.output, l_heading);

            FOR j
                IN c_main_details (p_company,
                                   p_from_revenue_acct,
                                   p_to_revenue_acct)
            LOOP
                lsql   := 'truncate table XXDO.XXD_AR_EXT_SALES_EXTRACT_GT';

                EXECUTE IMMEDIATE lsql;


                INSERT INTO XXD_AR_EXT_SALES_EXTRACT_GT
                    SELECT xal.ae_header_id, xal.ae_line_num, xah.ledger_id,
                           xah.event_id, xal.ACCOUNTING_CLASS_CODE, xte.source_id_int_1,
                           xal.code_combination_id, xte.entity_id, xah.accounting_date
                      FROM apps.XLA_AE_LINES xal, apps.XLA_AE_HEADERS xah, xla_transaction_entities_upg xte,
                           XLA_EVENTS xe
                     WHERE     1 = 1
                           AND xte.entity_id = xah.entity_id
                           AND xte.application_id = 222                   --AR
                           AND xe.event_id = xah.event_id
                           AND xe.entity_id = xah.entity_id
                           AND xe.event_status_code = 'P'
                           AND xe.application_id = 222
                           AND xah.application_id = 222
                           AND xal.application_id = 222
                           AND XAH.ae_header_id = XAL.ae_header_id
                           AND xal.application_id = xah.application_id
                           AND xal.ACCOUNTING_CLASS_CODE IN
                                   (    SELECT TRIM (
                                                   REGEXP_SUBSTR (
                                                       l_acc_class_code,
                                                       '[^,]+',
                                                       1,
                                                       LEVEL)) VALUE
                                          FROM DUAL
                                    CONNECT BY REGEXP_SUBSTR (l_acc_class_code, '[^,]+', 1
                                                              , LEVEL)
                                                   IS NOT NULL)
                           /*AND xal.ACCOUNTING_CLASS_CODE in ( SELECT ffvl.flex_value
                                                   FROM
                                                       fnd_flex_value_sets      ffvs,
                                                       fnd_flex_values_vl       ffvl
                                                   WHERE 1=1
                                                       AND ffvs.flex_value_set_name = 'XXD_ACCOUNTING_CLASS_CODE_VS'
                                                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                                                       AND ffvl.enabled_flag = 'Y'
                                                       AND sysdate BETWEEN decode(ffvl.start_date_active, NULL, sysdate - 1, ffvl.start_date_active)
                                                       AND decode (ffvl.end_date_active, NULL, sysdate + 1, ffvl.end_date_active) )*/
                           AND xal.code_combination_id =
                               j.code_combination_id
                           AND xah.ledger_id = j.SET_OF_BOOKS_ID
                           AND xah.period_name IN
                                   (    SELECT TRIM (
                                                   REGEXP_SUBSTR (
                                                       l_period_name,
                                                       '[^,]+',
                                                       1,
                                                       LEVEL)) VALUE
                                          FROM DUAL
                                    CONNECT BY REGEXP_SUBSTR (l_period_name, '[^,]+', 1
                                                              , LEVEL)
                                                   IS NOT NULL)         /*(SELECT period_name FROM gl.gl_periods
WHERE period_set_name = 'DO_FY_CALENDAR'
AND start_date>=(
SELECT start_date
FROM gl.gl_periods
WHERE period_set_name = 'DO_FY_CALENDAR'
AND period_name = p_from_period)
AND end_date <= (
SELECT end_date FROM gl.gl_periods
WHERE period_set_name = 'DO_FY_CALENDAR'
AND period_name = p_to_period))*/
                                                               ;

                COMMIT;

                BEGIN
                    SELECT COUNT (*)
                      INTO v_count
                      FROM XXD_AR_EXT_SALES_EXTRACT_GT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_count   := 0;
                END;

                IF v_count > 0
                THEN
                    FOR i IN c2 (j.ORGANIZATION_ID, j.name, p_from_period,
                                 p_to_period, j.code_combination_id, j.SET_OF_BOOKS_ID, p_state, j.segment6, p_additional_details
                                 , j.rev_acct, j.enabled_flag, j.segment2)
                    LOOP
                        l_line   :=
                               i.company
                            || CHR (9)
                            || i.org
                            || CHR (9)
                            || i.brand
                            || CHR (9)
                            || i.ship_country
                            || CHR (9)
                            || i.ship_state
                            || CHR (9)
                            || i.rev_acct
                            || CHR (9)
                            || i.gl_date
                            || CHR (9)
                            || i.total_rev_amt
                            || CHR (9)
                            || i.total_tax_amt
                            || CHR (9)
                            || i.total_frieght_amt;
                        apps.fnd_file.put_line (apps.fnd_file.output, l_line);
                    END LOOP;
                END IF;                                            -- v_count;


                BEGIN
                    SELECT COUNT (*)
                      INTO v_count
                      FROM fnd_lookup_values flv
                     WHERE     flv.lookup_type = 'XXDOAR036_TAX_ACCOUNTS'
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           AND flv.lookup_code = j.segment6;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_count   := 0;
                END;


                IF v_count > 0
                THEN
                    FOR i IN c4 (p_from_period, p_to_period, j.code_combination_id, j.segment6, p_additional_details, j.rev_acct
                                 , j.enabled_flag, j.segment2)
                    LOOP
                        l_line   :=
                               i.company
                            || CHR (9)
                            || i.org
                            || CHR (9)
                            || i.brand
                            || CHR (9)
                            || i.ship_country
                            || CHR (9)
                            || i.ship_state
                            || CHR (9)
                            || i.rev_acct
                            || CHR (9)
                            || i.gl_date1
                            || CHR (9)
                            || i.total_rev_amt
                            || CHR (9)
                            || i.total_tax_amt
                            || CHR (9)
                            || i.total_frieght_amt;
                        apps.fnd_file.put_line (apps.fnd_file.output, l_line);
                    END LOOP;
                END IF;                                            -- v_count;
            END LOOP;

            FOR i IN c6 (p_from_period, p_to_period, p_additional_details,
                         p_company, p_from_revenue_acct, p_to_revenue_acct)
            LOOP
                l_line   :=
                       i.company
                    || CHR (9)
                    || i.org
                    || CHR (9)
                    || i.brand
                    || CHR (9)
                    || i.ship_country
                    || CHR (9)
                    || i.ship_state
                    || CHR (9)
                    || i.rev_acct
                    || CHR (9)
                    || i.gl_date1
                    || CHR (9)
                    || i.sum_rev_amt
                    || CHR (9)
                    || i.sum_tax_amt
                    || CHR (9)
                    || i.sum_frieght_amt;
                apps.fnd_file.put_line (apps.fnd_file.output, l_line);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            errbuf    := 'No Data Found' || SQLCODE || SQLERRM;
            retcode   := -1;
            --DBMS_OUTPUT.PUT_LINE('NO DATA FOUND'|| SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, errbuf);
        WHEN INVALID_CURSOR
        THEN
            errbuf    := 'Invalid Cursor' || SQLCODE || SQLERRM;
            retcode   := -2;
            -- DBMS_OUTPUT.PUT_LINE('INVALID CURSOR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, errbuf);
        WHEN TOO_MANY_ROWS
        THEN
            errbuf    := 'Too Many Rows' || SQLCODE || SQLERRM;
            retcode   := -3;
            -- DBMS_OUTPUT.PUT_LINE('TOO MANY ROWS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, errbuf);
        WHEN PROGRAM_ERROR
        THEN
            errbuf    := 'Program Error' || SQLCODE || SQLERRM;
            retcode   := -4;
            -- DBMS_OUTPUT.PUT_LINE('PROGRAM ERROR' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, errbuf);
        WHEN OTHERS
        THEN
            errbuf    := 'Unhandled Error' || SQLCODE || SQLERRM;
            retcode   := -5;
            -- DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, errbuf);
    END run_sales_extract_query;
END XXDO_EXT_SALES_EXTRACT_PKG;
/
