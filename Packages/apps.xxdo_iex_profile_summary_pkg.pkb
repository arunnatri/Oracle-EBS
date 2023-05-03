--
-- XXDO_IEX_PROFILE_SUMMARY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_IEX_PROFILE_SUMMARY_PKG"
AS
    /*******************************************************************************
    * Program Name : XXDO_IEX_PROFILE_SUMMARY_PKG
    * Language     : PL/SQL
    * Description  : This package will generate Amounts for Given Cust_Account_Id
    * History      :
    *
    * WHO               WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------
    * BT Technology Team          1.0 - Initial Version              NOV/24/2014
    * --------------------------------------------------------------------------- */
    gc_module            VARCHAR2 (100) := 'XXDO_IEX_PROFILE_SUMMARY_PKG';
    gn_cust_account_id   NUMBER;
    gn_user_id           NUMBER := fnd_global.user_id;
    gn_resp_id           NUMBER := fnd_global.resp_id;
    gn_org_id            NUMBER := fnd_profile.VALUE ('ORG_ID');

    /*Procedure created to populate the value in DO_IEXRCALL.fmb on 24 Nov 2014 by BT Team*/
    PROCEDURE get_order_tot_ship_value (p_cust_id NUMBER, p_ord_tot_value OUT NUMBER, p_ship_tot_value OUT NUMBER)
    IS
        l_order_tot_value   NUMBER (20, 2);
        l_sihp_tot_value    NUMBER (20, 2);
    BEGIN
        gn_cust_account_id   := p_cust_id;

        BEGIN
              /* Commented for Defect 462
          SELECT SUM (
                          (oola.unit_selling_price * oola.pricing_quantity)
                        + oola.tax_line_value)
                INTO l_order_tot_value*/
              SELECT SUM (ROUND ((oola.unit_selling_price * oola.pricing_quantity) + NVL (oola.tax_line_value, 0), apps.xxdo_iex_profile_summary_pkg.get_precision (oola.header_id)))
                INTO l_order_tot_value
                FROM oe_order_headers_all ooha, hz_cust_accounts hca, oe_order_lines_all oola
               WHERE     ooha.sold_to_org_id = hca.cust_account_id
                     AND ooha.org_id = fnd_profile.VALUE ('ORG_ID')
                     AND ooha.header_id = oola.header_id
                     AND hca.cust_account_id = p_cust_id
                     AND oola.flow_status_code NOT IN ('RETURNED', 'CANCELLED')
            --BTDEV Changes Start 30-Jan-2015
            --              AND ooha.open_flag='Y'
            --BTDEV changes End  30-Jan-2015
            GROUP BY ooha.sold_to_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_ord_tot_value   := NVL (l_order_tot_value, 0);
                LOG (
                    p_module        => 'get_order_tot_ship_value',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_order_tot_ship_value Order Total value : '
                        || SQLERRM);
        END;

        p_ord_tot_value      := NVL (l_order_tot_value, 0);

        BEGIN
              /*Commented for Defect 462
             SELECT SUM (
                          (oola.unit_selling_price * oola.pricing_quantity)
                        + oola.tax_line_value)
                INTO l_sihp_tot_value*/
              SELECT SUM (ROUND ((oola.unit_selling_price * oola.pricing_quantity) + NVL (oola.tax_line_value, 0), apps.xxdo_iex_profile_summary_pkg.get_precision (oola.header_id)))
                INTO l_sihp_tot_value
                FROM oe_order_headers_all ooha, hz_cust_accounts hca, oe_order_lines_all oola
               WHERE     ooha.sold_to_org_id = hca.cust_account_id
                     AND ooha.org_id = fnd_profile.VALUE ('ORG_ID')
                     AND ooha.header_id = oola.header_id
                     AND hca.cust_account_id = p_cust_id
                     --BTDEV Changes Start 30-Jan-2015
                     --AND oola.flow_status_code IN ('SHIPPED')
                     AND oola.flow_status_code IN ('SHIPPED', 'CLOSED')
            --BTDEV changes End  30-Jan-2015

            GROUP BY ooha.sold_to_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_ship_tot_value   := NVL (l_sihp_tot_value, 0);
                LOG (
                    p_module        => 'get_order_tot_ship_value',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_order_tot_ship_value Shipped Total value : '
                        || SQLERRM);
        END;

        p_ship_tot_value     := NVL (l_sihp_tot_value, 0);
    END;

    PROCEDURE get_order_tot_ship_value_cust (p_party_id NUMBER, p_ord_tot_value OUT NUMBER, p_ship_tot_value OUT NUMBER)
    IS
        l_order_tot_value   NUMBER (20, 2);
        l_sihp_tot_value    NUMBER (20, 2);
    BEGIN
        --      gn_cust_account_id := p_cust_id;
        BEGIN
              /* Commented for defect 462
          SELECT SUM (
                          (oola.unit_selling_price * oola.pricing_quantity)
                        + oola.tax_line_value)
                INTO l_order_tot_value*/
              SELECT SUM (ROUND ((oola.unit_selling_price * oola.pricing_quantity) + NVL (oola.tax_line_value, 0), apps.xxdo_iex_profile_summary_pkg.get_precision (oola.header_id)))
                INTO l_order_tot_value
                FROM oe_order_headers_all ooha, hz_cust_accounts hca, oe_order_lines_all oola
               WHERE     ooha.sold_to_org_id = hca.cust_account_id
                     AND ooha.org_id = fnd_profile.VALUE ('ORG_ID')
                     AND ooha.header_id = oola.header_id
                     AND hca.cust_account_id IN (SELECT cust_account_id
                                                   FROM hz_cust_accounts
                                                  WHERE party_id = p_party_id --                                           AND attribute1 IN (
                                --                          SELECT lookup_code
                  --                            FROM apps.fnd_lookup_values_vl
                  --                           WHERE lookup_type = 'DO_BRANDS'
                         --                             AND enabled_flag = 'Y'
                         --                             AND attribute10 = 'Y')
                                                )
                     AND oola.flow_status_code NOT IN ('RETURNED', 'CANCELLED')
            --BTDEV Changes Start 30-Jan-2015
            --              AND ooha.open_flag='Y'
            --BTDEV changes End  30-Jan-2015
            GROUP BY hca.party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_ord_tot_value   := NVL (l_order_tot_value, 0);
                LOG (
                    p_module        => 'get_order_tot_ship_value',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_order_tot_ship_value Order Total value : '
                        || SQLERRM);
        END;

        p_ord_tot_value    := NVL (l_order_tot_value, 0);

        BEGIN
              /* Commented for defect 462
          SELECT SUM (
                          (oola.unit_selling_price * oola.pricing_quantity)
                        + oola.tax_line_value)
                INTO l_sihp_tot_value */
              SELECT SUM (ROUND ((oola.unit_selling_price * oola.pricing_quantity) + NVL (oola.tax_line_value, 0), apps.xxdo_iex_profile_summary_pkg.get_precision (oola.header_id)))
                INTO l_sihp_tot_value
                FROM oe_order_headers_all ooha, hz_cust_accounts hca, oe_order_lines_all oola
               WHERE     ooha.sold_to_org_id = hca.cust_account_id
                     AND ooha.org_id = fnd_profile.VALUE ('ORG_ID')
                     AND ooha.header_id = oola.header_id
                     AND hca.cust_account_id IN (SELECT cust_account_id
                                                   FROM hz_cust_accounts
                                                  WHERE party_id = p_party_id --                                           AND attribute1 IN (
                                --                          SELECT lookup_code
                  --                            FROM apps.fnd_lookup_values_vl
                  --                           WHERE lookup_type = 'DO_BRANDS'
                         --                             AND enabled_flag = 'Y'
                         --                             AND attribute10 = 'Y')
                                                )
                     --BTDEV Changes Start 30-Jan-2015
                     --AND oola.flow_status_code IN ('SHIPPED')
                     AND oola.flow_status_code IN ('SHIPPED', 'CLOSED')
            --BTDEV changes End  30-Jan-2015
            GROUP BY hca.party_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_ship_tot_value   := NVL (l_sihp_tot_value, 0);
                LOG (
                    p_module        => 'get_order_tot_ship_value',
                    p_line_number   => NULL,
                    p_log_message   =>
                           ' get_order_tot_ship_value Shipped Total value : '
                        || SQLERRM);
        END;

        p_ship_tot_value   := NVL (l_sihp_tot_value, 0);
    END;

    PROCEDURE LOG (p_log_message   IN VARCHAR2,
                   p_module        IN VARCHAR2,
                   p_line_number   IN NUMBER)
    IS
    BEGIN
        xxdo_geh_pkg.record_error (gc_module, gn_cust_account_id, p_module,
                                   p_line_number, NULL, gn_user_id,
                                   p_log_message, TO_CHAR (gn_org_id));
    END LOG;


    FUNCTION get_Order_header_tax (p_header_id NUMBER)
        RETURN NUMBER
    IS
        p_subtotal   NUMBER;

        p_discount   NUMBER;

        p_charges    NUMBER;

        p_tax        NUMBER;
    BEGIN
        p_subtotal   := NULL;

        p_discount   := NULL;

        p_charges    := NULL;

        p_tax        := NULL;
        apps.oe_oe_totals_summary.ORDER_TOTALS (p_header_id, p_subtotal, p_discount
                                                , p_charges, p_tax);
        RETURN p_tax;
    END;

    FUNCTION get_Order_header_total (p_header_id NUMBER)
        RETURN NUMBER
    IS
        p_subtotal   NUMBER;

        p_discount   NUMBER;

        p_charges    NUMBER;

        p_tax        NUMBER;
    BEGIN
        p_subtotal   := NULL;

        p_discount   := NULL;

        p_charges    := NULL;

        p_tax        := NULL;
        apps.oe_oe_totals_summary.ORDER_TOTALS (p_header_id, p_subtotal, p_discount
                                                , p_charges, p_tax);
        RETURN p_subtotal;
    END;

    FUNCTION get_precision (p_header_id IN NUMBER)
        RETURN NUMBER
    IS
        CURSOR get_precision_c IS
            SELECT fc.precision
              FROM APPS.oe_order_headers_all ooha, fnd_currencies fc
             WHERE     ooha.transactional_curr_code = fc.currency_code
                   AND header_id = p_header_id;

        ln_precision   NUMBER;
    BEGIN
        OPEN get_precision_c;

        FETCH get_precision_c INTO ln_precision;

        CLOSE get_precision_c;

        RETURN NVL (ln_precision, 2);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 2;
    END get_precision;

    --Start of adding new function by BT Technology Team as part of performance improvement process on 09-Nov-2015


    FUNCTION get_precision_by_curr_code (p_currency_code IN VARCHAR2)
        RETURN NUMBER
    IS
        CURSOR get_precision_c IS
            SELECT fc.precision
              FROM fnd_currencies fc
             WHERE fc.currency_code = p_currency_code;

        ln_precision   NUMBER;
    BEGIN
        OPEN get_precision_c;

        FETCH get_precision_c INTO ln_precision;

        CLOSE get_precision_c;

        RETURN NVL (ln_precision, 2);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 2;
    END get_precision_by_curr_code;
--End of adding new function by BT Technology Team as part of performance improvement process on 09-Nov-2015


END xxdo_iex_profile_summary_pkg;
/
