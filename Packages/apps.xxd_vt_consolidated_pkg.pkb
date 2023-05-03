--
-- XXD_VT_CONSOLIDATED_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_VT_CONSOLIDATED_PKG"
IS
    /***********************************************************************************
    *$header :                                                                         *
    *                                                                                  *
    * AUTHORS :Suraj Valluri                                                           *
    *                                                                                  *
    * PURPOSE : Deckers Virtual Tax Consolidated Report                                *
    *                                                                                  *
    * PARAMETERS :                                                                     *
    *                                                                                  *
    * DATE : 18-MAR-2021                                                               *
    *                                                                                  *
    * Assumptions:                                                                     *
    *                                                                                  *
    *                                                                                  *
    * History                                                                          *
    * Vsn    Change Date Changed By          Change Description                        *
    * ----- ----------- ------------------ ------------------------------------        *
    * 1.0    18-MAR-2021 Suraj Valluri       Initial Creation CCR0009031               *
    * 1.1    13-OCT-2021 Showkath Ali        CCR0009638                                *
    * 1.2    30-NOV-2021 Srinath Siricilla   CCR0009638 -Redesign and UAT Changes      *
    * 1.3    28-SEP-2022 Kishan Reddy        CCR0009604 -Removed Hard coded values and *
    *                                        Include Italy OU                          *
    ***********************************************************************************/

    -- Added as per CCR0009638

    FUNCTION remove_junk_fnc (pv_data IN VARCHAR2)
        RETURN VARCHAR2
    IS
    BEGIN
        IF pv_data IS NOT NULL
        THEN
            RETURN REPLACE (
                       REPLACE (
                           REPLACE (
                               REPLACE (
                                   REPLACE (RTRIM (pv_data), CHR (10), ' '),
                                   CHR (13),
                                   ' '),
                               CHR (09),
                               ' '),
                           ',',
                           ' '),
                       '~',
                       ' ');
        ELSE
            RETURN NULL;
        END IF;
    END remove_junk_fnc;

    -- End of Change

    PROCEDURE MAIN (errbuf                   OUT VARCHAR2,
                    retcode                  OUT VARCHAR2,
                    p_invoice_date_from   IN     VARCHAR2,
                    p_invoice_date_to     IN     VARCHAR2,
                    p_gl_date_from        IN     VARCHAR2,
                    p_gl_date_to          IN     VARCHAR2,
                    p_posting_status      IN     VARCHAR2,
                    pv_final_mode         IN     VARCHAR2)
    IS
        lv_invoice_date_from    DATE;
        lv_invoice_date_to      DATE;
        lv_gl_date_from         DATE;
        lv_gl_date_to           DATE;

        ln_mat_cnt              NUMBER := 0;
        ln_pay_cnt              NUMBER := 0;
        ln_manual_cnt           NUMBER := 0;
        ln_proj_cnt             NUMBER := 0;
        ln_asset_cnt            NUMBER := 0;

        lv_delimiter            VARCHAR2 (1);
        lv_heading              VARCHAR2 (4000);
        lv_data                 VARCHAR2 (4000);

        -------------------
        --MATERIAL Extract
        -------------------
        CURSOR c_material (cp_gl_date_from DATE, cp_gl_date_to DATE, cp_invoice_date_from DATE
                           , cp_invoice_date_to DATE)
        IS
            SELECT /*+ LEADING(xmmt) index(xmmt XXCP_MTL_MATERIAL_TRXNS_A8) */
                   --/*+ LEADING(xmmt) parallel(16)*/
                    DISTINCT
                   'Material'
                       vt_source,
                   h.invoice_number
                       invoice_number,
                   hou.name
                       organization_name,
                   xmmt.vt_transaction_id
                       vt_transaction_ref,
                   ooha.order_number
                       oracle_ref,
                   h.attribute2
                       sold_by_ou_code,
                   h.attribute3
                       sold_to_ou_code,
                   comp_tax.tax_registration_ref
                       vat_seller,
                   cust_tax.tax_registration_ref
                       vat_buyer,
                   (SELECT ottl.name
                      FROM apps.oe_transaction_types_tl ottl
                     WHERE     ottl.transaction_type_id =
                               ooha.order_type_id
                           AND ottl.language = USERENV ('LANG'))
                       order_type_user_category,
                   NULL
                       customer_vendor_number,
                   NULL
                       customer_vendor_name,
                   --hca.account_number              customer_vendor_number,   -- Commented as per CCR0009638
                   --replace(replace(replace(replace(replace(rtrim(hp_bill.party_name), CHR(10), ' '), CHR(13), ' '), CHR(09), ' '), ',', ' '), '~'
                   --, ' ') customer_vendor_name,                              -- Commented as per CCR0009638
                   h.invoice_date
                       invoice_date,
                   oola.line_number
                       line_number,
                   xmmt.vt_transaction_date
                       vt_transaction_date,
                   xmmt.vt_transaction_id
                       vt_transaction_id,
                   xmmt.actual_cost
                       actual_cost,
                   NULL
                       bill_to_address_line1,
                   NULL
                       bill_to_address_line2,
                   NULL
                       bill_to_city,
                   NULL
                       bill_to_state,
                   NULL
                       bill_to_country,
                   NULL
                       bill_to_address_key,
                   NULL
                       ship_to_address_line1,
                   NULL
                       ship_to_address_line2,
                   NULL
                       ship_to_city,
                   NULL
                       ship_to_state,
                   NULL
                       ship_to_country,
                   NULL
                       ship_to_address_key,
                   -- Commented as per CCR0009638
                   --   replace(replace(replace(replace(replace(rtrim(hl_bill.address1), CHR(10), ' '), CHR(13), ' '), CHR(09), ' '), ',', ' '), '~',
                   --   ' ') bill_to_address_line1,
                   --   replace(replace(replace(replace(replace(rtrim(hl_bill.address2), CHR(10), ' '), CHR(13), ' '), CHR(09), ' '), ',', ' '), '~',
                   --   ' ') bill_to_address_line2,
                   --   hl_bill.city                    bill_to_city,
                   --   hl_bill.state                   bill_to_state,
                   --   hl_bill.country                 bill_to_country,
                   --   replace(replace(replace(replace(replace(rtrim(hl_bill.address_key), CHR(10), ' '), CHR(13), ' '), CHR(09), ' '), ',', ' '), '~'
                   --   , ' ') bill_to_address_key,
                   --   replace(replace(replace(replace(replace(rtrim(hl_ship.address1), CHR(10), ' '), CHR(13), ' '), CHR(09), ' '), ',', ' '), '~',
                   --   ' ') ship_to_address_line1,
                   --   replace(replace(replace(replace(replace(rtrim(hl_ship.address2), CHR(10), ' '), CHR(13), ' '), CHR(09), ' '), ',', ' '), '~',
                   --   ' ') ship_to_address_line2,
                   --   hl_ship.city                    ship_to_city,
                   --   hl_ship.state                   ship_to_state,
                   --   hl_ship.country                 ship_to_country,
                   --   replace(replace(replace(replace(replace(rtrim(hl_ship.address_key), CHR(10), ' '), CHR(13), ' '), CHR(09), ' '), ',', ' '), '~'
                   --   , ' ') ship_to_address_key,
                   -- End of Change as per CCR0009638
                   org.organization_name
                       warehouse_name,
                   l.ic_unit_price
                       ic_unit_price,
                   l.quantity
                       quantity,
                   l.ic_currency_code
                       ic_currency_code,
                   NVL (
                       (SELECT ph.attribute1
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id = l.attribute_id
                               AND ph.status = 'GLI'
                               AND ph.segment6 IN ('21801', '21802')
                               AND ph.segment1 = h.attribute2),
                       (SELECT ph.attribute1
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id = l.attribute_id
                               AND ph.status = 'GLI'
                               AND ph.segment6 IN ('21801', '21802')
                               AND ph.segment1 = h.attribute3))
                       seller_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = l.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('21801'--'21802'
                                                      )
                           AND ph.segment1 = h.attribute2)
                       seller_vat_account_code,
                   (SELECT ph.attribute3                       --ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = l.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('21801'-- '21802'
                                                      )
                           AND ph.segment1 = h.attribute2)
                       seller_vat_rate,
                   (SELECT ph.attribute4                       --ph.attribute3
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = l.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.segment1 = h.attribute3)
                       buyer_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = l.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.segment1 = h.attribute3)
                       buyer_vat_acccount_code,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = l.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.segment1 = h.attribute3)
                       buyer_vat_rate,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = l.attribute_id
                           AND ph.status = 'GLI'
                           --                 AND ph.segment6 = '11901'
                           AND ph.segment6 IN (--'21801',
                                               '21802') -- Check whether this should be 11901 or 21801
                           AND ph.segment1 = h.attribute3)
                       rev_buyer_pay_vat_rate,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = l.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN (--'21801',
                                               '21802')
                           AND ph.segment1 = h.attribute3)
                       rev_buyer_rec_vat_acct_code,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = l.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN (--'21801',
                                               '21802')
                           AND ph.segment1 = h.attribute3)
                       rev_buyer_rec_vat_rate,
                   (l.ic_unit_price * quantity * 1--                nvl((
                                                  --    SELECT
                                                  --     conversion_rate
                                                  --    FROM
                                                  --     apps.gl_daily_rates
                                                  --    WHERE
                                                  --     conversion_type = 'Corporate'
                                                  --     AND from_currency = l.ic_currency_code
                                                  --     AND to_currency = 'GBP'
                                                  --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                                                  --   ), 1)
                                                  )
                       invoice_total,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = l.attribute_id
                              AND ph.status = 'GLI'
                              AND ph.segment6 IN ('21801'--'21802'
                                                         )
                              AND ph.segment1 = h.attribute2)
                    * 1
                    --                nvl((
                    --    SELECT
                    --     conversion_rate
                    --    FROM
                    --     apps.gl_daily_rates
                    --    WHERE
                    --     conversion_type = 'Corporate'
                    --     AND from_currency = l.ic_currency_code
                    --     AND to_currency = 'GBP'
                    --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                    --   ), 1)
                    * SIGN (quantity))
                       seller_output_vat_amount,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = l.attribute_id
                              AND ph.status = 'GLI'
                              AND ph.segment6 IN ('11901', '11902')
                              AND ph.segment1 = h.attribute3)
                    * 1
                    --   nvl((
                    --    SELECT
                    --     conversion_rate
                    --    FROM
                    --     apps.gl_daily_rates
                    --    WHERE
                    --     conversion_type = 'Corporate'
                    --     AND from_currency = l.ic_currency_code
                    --     AND to_currency = 'GBP'
                    --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                    --   ), 1)
                    * SIGN (quantity))
                       buyer_input_vat_amount,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = l.attribute_id
                              AND ph.status = 'GLI'
                              AND ph.segment6 IN (-- '21801',
                                                  '21802')
                              AND ph.segment1 = h.attribute3)
                    * 1
                    --   nvl((
                    --    SELECT
                    --     conversion_rate
                    --    FROM
                    --     apps.gl_daily_rates
                    --    WHERE
                    --     conversion_type = 'Corporate'
                    --     AND from_currency = l.ic_currency_code
                    --     AND to_currency = 'GBP'
                    --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                    --   ), 1)
                    * SIGN (quantity))
                       buyer_output_vat_amount,
                   NULL
                       invoice_total_gbp,
                   NULL
                       seller_output_vat_amount_gbp,
                   NULL
                       buyer_input_vat_amount_gbp,
                   NULL
                       buyer_output_vat_amount_gbp,
                   NULL
                       invoice_total_eur,
                   NULL
                       seller_output_vat_amount_eur,
                   NULL
                       buyer_input_vat_amount_eur,
                   NULL
                       buyer_output_vat_amount_eur,
                   NULL
                       invoice_total_usd,
                   NULL
                       seller_output_vat_amount_usd,
                   NULL
                       buyer_input_vat_amount_usd,
                   NULL
                       buyer_output_vat_amount_usd,
                     -- Commented as per CCR0009638

                     --   ( l.ic_unit_price * quantity * nvl((
                     --    SELECT
                     --     conversion_rate
                     --    FROM
                     --     apps.gl_daily_rates
                     --    WHERE
                     --     conversion_type = 'Corporate'
                     --     AND from_currency = l.ic_currency_code
                     --     AND to_currency = 'EUR'
                     --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                     --   ), 1) )                                                             invoice_total_eur,
                     --   ( (
                     --    SELECT
                     --     nvl(entered_cr, 0) + nvl(entered_dr, 0)
                     --    FROM
                     --     apps.xxcp_process_history ph
                     --    WHERE
                     --     ph.attribute_id = l.attribute_id
                     --     AND ph.status = 'GLI'
                     --     AND ph.segment6 IN (
                     --      '21801'
                     --      --'21802'
                     --     )
                     --     AND ph.segment1 = h.attribute2
                     --   ) * nvl((
                     --    SELECT
                     --     conversion_rate
                     --    FROM
                     --     apps.gl_daily_rates
                     --    WHERE
                     --     conversion_type = 'Corporate'
                     --     AND from_currency = l.ic_currency_code
                     --     AND to_currency = 'EUR'
                     --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                     --   ), 1) * sign(quantity) )                                            seller_output_vat_amount_eur,
                     --   ( (SELECT
                     --     nvl(entered_cr, 0) + nvl(entered_dr, 0)
                     --    FROM
                     --     apps.xxcp_process_history ph
                     --    WHERE
                     --     ph.attribute_id = l.attribute_id
                     --     AND ph.status = 'GLI'
                     --     AND ph.segment6 IN(
                     --      '11901', '11902'
                     --     )
                     --     AND ph.segment1 = h.attribute3)
                     --            * nvl((
                     --    SELECT
                     --     conversion_rate
                     --    FROM
                     --     apps.gl_daily_rates
                     --    WHERE
                     --     conversion_type = 'Corporate'
                     --     AND from_currency = l.ic_currency_code
                     --     AND to_currency = 'EUR'
                     --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                     --   ), 1) * sign(quantity) )                                            buyer_input_vat_amount_eur,
                     --   ( (
                     --    SELECT
                     --     nvl(entered_dr, 0) + nvl(entered_cr, 0)
                     --    FROM
                     --     apps.xxcp_process_history ph
                     --    WHERE
                     --     ph.attribute_id = l.attribute_id
                     --     AND ph.status = 'GLI'
                     --     AND ph.segment6 IN (
                     --      --'21801',
                     --      '21802'
                     --     )
                     --     AND ph.segment1 = h.attribute3
                     --   ) * nvl((
                     --    SELECT
                     --     conversion_rate
                     --    FROM
                     --     apps.gl_daily_rates
                     --    WHERE
                     --     conversion_type = 'Corporate'
                     --     AND from_currency = l.ic_currency_code
                     --     AND to_currency = 'EUR'
                     --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                     --   ), 1) * sign(quantity) )                                            buyer_output_vat_amount_eur,
                     --   ( l.ic_unit_price * quantity * nvl((
                     --    SELECT
                     --     conversion_rate
                     --    FROM
                     --     apps.gl_daily_rates
                     --    WHERE
                     --     conversion_type = 'Corporate'
                     --     AND from_currency = l.ic_currency_code
                     --     AND to_currency = 'USD'
                     --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                     --   ), 1) )                                                             invoice_total_usd,
                     --   ( (
                     --    SELECT
                     --     nvl(entered_cr, 0) + nvl(entered_dr, 0)
                     --    FROM
                     --     apps.xxcp_process_history ph
                     --    WHERE
                     --     ph.attribute_id = l.attribute_id
                     --     AND ph.status = 'GLI'
                     --     AND ph.segment6 IN (
                     --      '21801'
                     --      --'21802'
                     --     )
                     --     AND ph.segment1 = h.attribute2
                     --   ) * nvl((
                     --    SELECT
                     --     conversion_rate
                     --    FROM
                     --     apps.gl_daily_rates
                     --    WHERE
                     --     conversion_type = 'Corporate'
                     --     AND from_currency = l.ic_currency_code
                     --     AND to_currency = 'USD'
                     --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                     --   ), 1) * sign(quantity) )                                            seller_output_vat_amount_usd,
                     --   ( (
                     --    SELECT
                     --     nvl(entered_dr, 0) + nvl(entered_cr, 0)
                     --    FROM
                     --     apps.xxcp_process_history ph
                     --    WHERE
                     --     ph.attribute_id = l.attribute_id
                     --     AND ph.status = 'GLI'
                     --     AND ph.segment6 IN(
                     --      '11901', '11902'
                     --     )
                     --     AND ph.segment1 = h.attribute3
                     --   ) * nvl((
                     --    SELECT
                     --     conversion_rate
                     --    FROM
                     --     apps.gl_daily_rates
                     --    WHERE
                     --     conversion_type = 'Corporate'
                     --     AND from_currency = l.ic_currency_code
                     --     AND to_currency = 'USD'
                     --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                     --   ), 1) * sign(quantity) )                                            buyer_input_vat_amount_usd,
                     --   ( (
                     --    SELECT
                     --     nvl(entered_dr, 0) + nvl(entered_cr, 0)
                     --    FROM
                     --     apps.xxcp_process_history ph
                     --    WHERE
                     --     ph.attribute_id = l.attribute_id
                     --     AND ph.status = 'GLI'
                     --     AND ph.segment6 IN (
                     --      --'21801',
                     --      '21802'
                     --     )
                     --     AND ph.segment1 = h.attribute3
                     --   ) * nvl((
                     --    SELECT
                     --     conversion_rate
                     --    FROM
                     --     apps.gl_daily_rates
                     --    WHERE
                     --     conversion_type = 'Corporate'
                     --     AND from_currency = l.ic_currency_code
                     --     AND to_currency = 'USD'
                     --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                     --   ), 1) * sign(quantity) )                                            buyer_output_vat_amount_usd,
                     -- End of Change as per CCR0009638
                     DECODE (
                         h.attribute2,
                         500, (SELECT MAX (NVL (cic.item_cost, 0))
                                 FROM apps.cst_item_costs cic, apps.mtl_parameters mp
                                WHERE     cic.inventory_item_id =
                                          oola.inventory_item_id
                                      AND cic.organization_id =
                                          oola.ship_from_org_id
                                      AND cic.organization_id =
                                          mp.organization_id
                                      AND cic.cost_type_id =
                                          mp.primary_cost_method),
                         l.ic_unit_price)
                   * l.quantity
                       shipment_landed_cost,
                   -- Commented as per CCR0009638
                   --   DECODE(h.attribute2, 500,(
                   --    SELECT
                   --     MAX(nvl(cic.item_cost, 0))
                   --    FROM
                   --     apps.cst_item_costs   cic, apps.mtl_parameters   mp
                   --    WHERE
                   --     cic.inventory_item_id = oola.inventory_item_id
                   --     AND cic.organization_id = oola.ship_from_org_id
                   --     AND cic.organization_id = mp.organization_id
                   --     AND cic.cost_type_id = mp.primary_cost_method
                   --   ), l.ic_unit_price) * l.quantity * nvl((
                   --    SELECT
                   --     conversion_rate
                   --    FROM
                   --     apps.gl_daily_rates
                   --    WHERE
                   --     conversion_type = 'Corporate'
                   --     AND from_currency = l.ic_currency_code
                   --     AND to_currency = 'GBP'
                   --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                   --   ), 1)                                                               shipment_landed_cost_gbp,
                   --   DECODE(h.attribute2, 500,(
                   --    SELECT
                   --     MAX(nvl(cic.item_cost, 0))
                   --    FROM
                   --     apps.cst_item_costs   cic, apps.mtl_parameters   mp
                   --    WHERE
                   --     cic.inventory_item_id = oola.inventory_item_id
                   --     AND cic.organization_id = oola.ship_from_org_id
                   --     AND cic.organization_id = mp.organization_id
                   --     AND cic.cost_type_id = mp.primary_cost_method
                   --   ), l.ic_unit_price) * l.quantity * nvl((
                   --    SELECT
                   --     conversion_rate
                   --    FROM
                   --     apps.gl_daily_rates
                   --    WHERE
                   --     conversion_type = 'Corporate'
                   --     AND from_currency = l.ic_currency_code
                   --     AND to_currency = 'EUR'
                   --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                   --   ), 1)                                                               shipment_landed_cost_eur,
                   --   DECODE(h.attribute2, 500,(
                   --    SELECT
                   --     MAX(nvl(cic.item_cost, 0))
                   --    FROM
                   --     apps.cst_item_costs   cic, apps.mtl_parameters   mp
                   --    WHERE
                   --     cic.inventory_item_id = oola.inventory_item_id
                   --     AND cic.organization_id = oola.ship_from_org_id
                   --     AND cic.organization_id = mp.organization_id
                   --     AND cic.cost_type_id = mp.primary_cost_method
                   --   ), l.ic_unit_price) * l.quantity * nvl((
                   --    SELECT
                   --     conversion_rate
                   --    FROM
                   --     apps.gl_daily_rates
                   --    WHERE
                   --     conversion_type = 'Corporate'
                   --     AND from_currency = l.ic_currency_code
                   --     AND to_currency = 'USD'
                   --     AND conversion_date = trunc(xmmt.vt_transaction_date)
                   --   ), 1)                                                               shipment_landed_cost_usd,
                   -- End of Change as per CCR0009638
                   (SELECT MIN (tc.harmonized_tariff_code)
                      FROM do_custom.do_harmonized_tariff_codes tc
                     WHERE     tc.country = 'EU'
                           AND tc.style_number = REGEXP_SUBSTR (oola.ordered_item, '[^-]+', 1
                                                                , 1))
                       commodity_code,
                   NULL
                       unit_weight,
                   NULL
                       style,
                   NULL
                       color,
                   NULL
                       product_group,
                   NULL
                       gender,
                   NULL
                       ship_to_zip,
                   NULL
                       seller_revenue_account,
                   NULL
                       buyer_expense_account,
                   ooha.sold_to_org_id,
                   ooha.ship_to_org_id,
                   ooha.invoice_to_org_id,
                   oola.inventory_item_id
              FROM apps.mtl_material_transactions mmt, apps.xxcp_mtl_material_transactions xmmt, apps.xxcp_tax_registrations comp_tax,
                   apps.xxcp_tax_registrations cust_tax, apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha,
                   apps.xxcp_process_history ph, apps.xxcp_ic_inv_lines l, apps.xxcp_ic_inv_header h,
                   apps.org_organization_definitions org, apps.hr_all_organization_units hou
             -- Commented as per CCR0009638
             --    apps.hr_operating_units hou,
             --   apps.hz_cust_accounts_all        hca,
             --   apps.hz_cust_site_uses_all       hcsua_bill,
             --   apps.hz_cust_site_uses_all       hcsua_ship,
             --   apps.hz_cust_acct_sites_all      hcasa_bill,
             --   apps.hz_party_sites              hps_bill,
             --   apps.hz_parties                  hp_bill,
             --   apps.hz_locations                hl_bill,
             --   apps.hz_cust_acct_sites_all      hcasa_ship,
             --   apps.hz_party_sites              hps_ship,
             --   apps.hz_parties                  hp_ship,
             --   apps.hz_locations                hl_ship
             -- End of Change as per CCR0009638
             WHERE     1 = 1
                   AND comp_tax.tax_registration_id = h.invoice_tax_reg_id
                   AND cust_tax.tax_registration_id = h.customer_tax_reg_id
                   AND mmt.transaction_id = xmmt.vt_transaction_id
                   AND ooha.header_id = oola.header_id
                   AND ooha.org_id = oola.org_id
                   AND oola.line_id = mmt.trx_source_line_id
                   AND l.attribute10 = 'S'
                   AND mmt.organization_id = oola.ship_from_org_id
                   AND xmmt.vt_transaction_date BETWEEN (cp_gl_date_from)
                                                    AND (cp_gl_date_to)
                   AND h.invoice_date BETWEEN NVL (cp_invoice_date_from,
                                                   h.invoice_date)
                                          AND NVL (cp_invoice_date_to,
                                                   h.invoice_date)
                   AND (   (h.attribute2 IN
                                (SELECT lookup_code
                                   FROM apps.fnd_lookup_values
                                  WHERE     lookup_type =
                                            'XXD_VT_CONSOLIDATED_OU_VS'
                                        AND language = USERENV ('LANG')))
                        OR (h.attribute3 IN
                                (SELECT lookup_code
                                   FROM apps.fnd_lookup_values
                                  WHERE     lookup_type =
                                            'XXD_VT_CONSOLIDATED_OU_VS'
                                        AND language = USERENV ('LANG'))))
                   AND ooha.org_id = hou.organization_id
                   -- as part of this CCR0009604, commented hard coded OU's
                   /*AND hou.name IN (
             'Deckers Austria GmbH OU',
             'Deckers Belgium BVBA OU',
             'Deckers Benelux OU',
             'Deckers EMEA eCommerce OU',
             'Deckers Europe Ltd OU',
             'Deckers France SAS OU',
             'Deckers Germany OU',
             'Deckers Inventory Consolidation OU',
             'Deckers UK OU',
             'Deckers Switzerland GMBH OU'
            )*/
                   -- as part of this CCR0009604, OU's were fetching from value set
                   AND hou.name IN
                           (SELECT ffv.flex_value
                              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                             WHERE     ffvs.flex_value_set_name =
                                       'XXD_VT_CONSOLIDATED_OU_LIST_VS'
                                   AND ffvs.flex_value_set_id =
                                       ffv.flex_value_set_id
                                   AND ffv.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           ffv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           ffv.end_date_active,
                                                           SYSDATE + 1))
                   AND xmmt.vt_interface_id = ph.interface_id
                   -- Start of Change as per CCR0009638
                   AND mmt.transaction_type_id IN (15, 33, 62)
                   --   AND ooha.sold_to_org_id = hca.cust_account_id
                   --   AND hcsua_bill.site_use_id = ooha.invoice_to_org_id
                   --   AND hcasa_bill.cust_acct_site_id = hcsua_bill.cust_acct_site_id
                   --   AND hps_bill.party_site_id = hcasa_bill.party_site_id
                   --   AND hp_bill.party_id = hps_bill.party_id
                   --   AND hps_bill.location_id = hl_bill.location_id
                   --   AND hcasa_ship.cust_acct_site_id = hcsua_ship.cust_acct_site_id
                   --   AND hps_ship.party_site_id = hcasa_ship.party_site_id
                   --   AND hp_ship.party_id = hps_ship.party_id
                   --   AND hps_ship.location_id = hl_ship.location_id
                   --   AND hcsua_ship.site_use_id = ooha.ship_to_org_id
                   -- End of Change as per CCR0009638
                   AND ph.process_history_id = l.process_history_id
                   AND l.invoice_header_id = h.invoice_header_id
                   AND oola.ship_from_org_id = org.organization_id;


        -------------------
        --PAYABLES Extract
        -------------------
        CURSOR c_payables (cp_gl_date_from DATE, cp_gl_date_to DATE, cp_invoice_date_from DATE
                           , cp_invoice_date_to DATE)
        IS
            SELECT DISTINCT                                --/*+ parallel(4)*/
                   'Payables'
                       vt_source,
                   xih.invoice_number
                       invoice_number,
                   NULL
                       organization_name,
                   xgi.vt_transaction_ref
                       vt_transaction_ref,
                   xil.transaction_ref
                       oracle_ref,
                   xih.attribute2
                       sold_by_ou_code,
                   xih.attribute3
                       sold_to_ou_code,
                   NVL (xih.attribute4, comp_tax.tax_registration_ref)
                       vat_seller,
                   NVL (xih.attribute5, cust_tax.tax_registration_ref)
                       vat_buyer,
                   user_je_category_name
                       order_type_user_category,
                   (SELECT aps.segment1
                      FROM ap_suppliers aps, fnd_user fu
                     WHERE     aps.vendor_name =
                               xth.transaction_ref2
                           AND aps.enabled_flag = 'Y'
                           AND aps.employee_id = fu.employee_id
                           AND NVL (fu.end_date, SYSDATE + 1) >=
                               SYSDATE
                           AND NVL (aps.end_date_active,
                                    SYSDATE + 1) >=
                               SYSDATE)
                       customer_vendor_number,
                   xth.transaction_ref2
                       customer_vendor_name,
                   TRUNC (xih.invoice_date)
                       invoice_date,
                   NULL
                       line_number,
                   xgi.vt_transaction_date
                       vt_transaction_date,
                   xgi.vt_transaction_id
                       vt_transaction_id,
                   NULL
                       actual_cost,
                   NULL
                       bill_to_address_line1,
                   NULL
                       bill_to_address_line2,
                   NULL
                       bill_to_city,
                   NULL
                       bill_to_state,
                   NULL
                       bill_to_country,
                   NULL
                       bill_to_address_key,
                   NULL
                       ship_to_address_line1,
                   NULL
                       ship_to_address_line2,
                   NULL
                       ship_to_city,
                   NULL
                       ship_to_state,
                   NULL
                       ship_to_country,
                   NULL
                       ship_to_address_key,
                   NULL
                       warehouse_name,
                   xil.ic_unit_price,
                   xil.quantity,
                   xil.ic_currency_code,
                   (SELECT ph.attribute1
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('21801'--'21802'
                                                      )-- AND ph.attribute4 IS NULL
                                                       )
                       seller_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           -- AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801'--'21802'
                                                      )--AND ph.attribute4 IS NULL
                                                       )
                       seller_vat_account_code,
                   (SELECT ph.attribute2                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           -- AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801'--'21802'
                                                      )-- AND ph.attribute4 IS NULL
                                                       )
                       seller_vat_rate,
                   (SELECT ph.attribute3
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.segment1 = xih.attribute3
                           AND ph.status = 'GLI'
                           -- AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902'))
                       buyer_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment1 = xih.attribute3
                           -- AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902'))
                       buyer_vat_acccount_code,
                   (SELECT ph.attribute4                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --  AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.segment1 = xih.attribute3-- AND ph.attribute4 IS NULL
                                                           )
                       buyer_vat_rate,
                   NVL (
                       (SELECT ph.attribute5
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id = xil.attribute_id
                               AND ph.status = 'GLI'
                               AND ph.segment6 IN ('21802')
                               AND ph.segment1 = xih.attribute3),
                       0)
                       rev_buyer_pay_vat_rate,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment6 IN ('21802')
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_rec_vat_acct_code,
                   NVL (
                       (SELECT ph.attribute5
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id = xil.attribute_id
                               AND ph.status = 'GLI'
                               AND ph.segment6 IN ('21802')
                               AND ph.segment1 = xih.attribute3),
                       0)
                       rev_buyer_rec_vat_rate,
                   ROUND (NVL (p.entered_dr, 0) - NVL (p.entered_cr, 0) * 1--            NVL (
                                                                           --               (SELECT conversion_rate
                                                                           --                  FROM apps.gl_daily_rates
                                                                           --                 WHERE     conversion_type = 'Corporate'
                                                                           --                       AND from_currency = p.CURRENCY_CODE
                                                                           --                       AND to_currency = 'GBP'
                                                                           --                       AND conversion_date = TRUNC (xgi.accounting_date)),1)
                                                                           ,
                          2)
                       invoice_total,
                   NVL (
                       ROUND (
                             (SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                                FROM apps.xxcp_process_history ph
                               WHERE     ph.attribute_id = xil.attribute_id
                                     AND ph.status = 'GLI'
                                     AND ph.segment6 IN ('21801'))
                           * 1--            NVL (
                              --               (SELECT conversion_rate
                              --                  FROM apps.gl_daily_rates
                              --                 WHERE     conversion_type = 'Corporate'
                              --                       AND from_currency = xil.ic_currency_code
                              --                       AND to_currency = 'GBP'
                              --                       AND conversion_date
                              --                       = TRUNC (xgi.accounting_date)), 1)
                              ,
                           2),
                       0)
                       seller_output_vat_amount,
                   ROUND (
                         (SELECT NVL (entered_dr, 0) - NVL (entered_cr, 0)
                            FROM apps.xxcp_process_history ph
                           WHERE     ph.attribute_id = xil.attribute_id
                                 AND ph.status = 'GLI'
                                 AND ph.segment6 IN ('11901', '11902')
                                 AND ph.segment1 = xih.attribute3)
                       * 1--            NVL (
                          --               (SELECT conversion_rate
                          --                  FROM apps.gl_daily_rates
                          --                 WHERE     conversion_type = 'Corporate'
                          --                       AND from_currency = xil.ic_currency_code
                          --                       AND to_currency = 'GBP'
                          --                       AND conversion_date
                          --                       = TRUNC (xgi.accounting_date)),
                          --                        1)
                          ,
                       2)
                       buyer_input_vat_amount,
                   NVL (
                       ROUND (
                             (SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                                FROM apps.xxcp_process_history ph
                               WHERE     ph.attribute_id = xil.attribute_id
                                     AND ph.status = 'GLI'
                                     AND ph.segment6 IN ('21802')
                                     AND ph.segment1 = xih.attribute3)
                           * 1--          * NVL (
                              --               (SELECT conversion_rate
                              --                  FROM apps.gl_daily_rates
                              --                 WHERE     conversion_type = 'Corporate'
                              --                       AND from_currency = xil.ic_currency_code
                              --                       AND to_currency = 'GBP'
                              --                       AND conversion_date =
                              --                       TRUNC (xgi.accounting_date)),
                              --               1)
                              ,
                           2),
                       0)
                       buyer_output_vat_amount,
                   -- Commented as per CCR0009638
                   --          ROUND (NVL(p.entered_dr,0) - NVL(p.entered_cr,0)
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = p.CURRENCY_CODE
                   --                       AND to_currency = 'GBP'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --               1),2)                                                            invoice_total_gbp,
                   --       NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                    AND ph.segment6 in ('21801')
                   --      )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'GBP'
                   --                       AND conversion_date
                   --                       = TRUNC (xgi.accounting_date)), 1),2),0)                 seller_output_vat_amount_GBP,
                   --         ROUND  ((SELECT NVL (entered_dr, 0) - NVL (entered_cr, 0)
                   --                  FROM apps.xxcp_process_history ph
                   --                 WHERE     ph.attribute_id = xil.attribute_id
                   --                       AND ph.status = 'GLI'
                   --                       AND ph.segment6 in ( '11901', '11902')
                   --                       AND ph.segment1 = xih.attribute3
                   --                       )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'GBP'
                   --                       AND conversion_date
                   --                       = TRUNC (xgi.accounting_date)),
                   --                        1),2)                                                   buyer_input_vat_amount_GBP,
                   --         NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                   AND ph.segment6 in ('21802')
                   --                    AND ph.segment1 = xih.attribute3
                   --                      )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'GBP'
                   --                       AND conversion_date =
                   --                       TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                           buyer_output_vat_amount_GBP,
                   --
                   --      ROUND (NVL(p.entered_dr,0) - NVL(p.entered_cr,0)
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = p.CURRENCY_CODE
                   --                       AND to_currency = 'EUR'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --               1),2)                                                            invoice_total_eur    ,
                   --       NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                    AND ph.segment6 in ('21801')
                   --      )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'EUR'
                   --                       AND conversion_date
                   --                       = TRUNC (xgi.accounting_date)), 1),2),0)                 seller_output_vat_amount_EUR,
                   --         ROUND  ((SELECT NVL (entered_dr, 0) - NVL (entered_cr, 0)
                   --                  FROM apps.xxcp_process_history ph
                   --                 WHERE     ph.attribute_id = xil.attribute_id
                   --                       AND ph.status = 'GLI'
                   --                       AND ph.segment6 in ( '11901', '11902')
                   --                       AND ph.segment1 = xih.attribute3
                   --                       )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'EUR'
                   --                       AND conversion_date
                   --                       = TRUNC (xgi.accounting_date)),
                   --                        1),2)                                                   buyer_input_vat_amount_EUR,
                   --         NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                   AND ph.segment6 in ('21802')
                   --                    AND ph.segment1 = xih.attribute3
                   --                      )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'EUR'
                   --                       AND conversion_date =
                   --                       TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                           buyer_output_vat_amount_EUR,
                   --         ROUND (NVL(p.entered_dr,0) - NVL(p.entered_cr,0)
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = p.CURRENCY_CODE
                   --                       AND to_currency = 'USD'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --               1),2)                                                            invoice_total_usd,
                   --      NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                    AND ph.segment6 in ('21801')
                   --      )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'USD'
                   --                       AND conversion_date
                   --                       = TRUNC (xgi.accounting_date)), 1),2),0)                 seller_output_vat_amount_USD,
                   --         ROUND  ((SELECT NVL (entered_dr, 0) - NVL (entered_cr, 0)
                   --                  FROM apps.xxcp_process_history ph
                   --                 WHERE     ph.attribute_id = xil.attribute_id
                   --                       AND ph.status = 'GLI'
                   --                       AND ph.segment6 in ( '11901', '11902')
                   --                       AND ph.segment1 = xih.attribute3
                   --                       )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'USD'
                   --                       AND conversion_date
                   --                       = TRUNC (xgi.accounting_date)),
                   --                        1),2)                                                   buyer_input_vat_amount_USD,
                   --         NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                   AND ph.segment6 in ('21802')
                   --                    AND ph.segment1 = xih.attribute3
                   --                      )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'USD'
                   --                       AND conversion_date =
                   --                       TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                         buyer_output_vat_amount_USD,
                   -- End of Change as per CCR0009638
                   NULL
                       shipment_landed_cost_gbp,
                   NULL
                       shipment_landed_cost_eur,
                   NULL
                       shipment_landed_cost_usd,
                   NULL
                       commodity_code,
                   NULL
                       unit_weight,
                   NULL
                       style,
                   NULL
                       color,
                   NULL
                       product_group,
                   NULL
                       gender,
                   NULL
                       ship_to_zip,
                   NULL
                       seller_revenue_account,
                   NULL
                       buyer_expense_account,
                   xgi.accounting_date
                       accounting_date              -- Added as per CCR0009638
              FROM apps.xxcp_ic_inv_header xih,
                   apps.xxcp_ic_inv_lines xil,
                   apps.xxcp_gl_interface xgi,
                   apps.xxcp_transaction_header xth,
                   apps.xxcp_transaction_attributes xph,
                   (SELECT /*+ FULL(p) PARALLEL(p, 4)*/
                           p.*
                      FROM apps.xxcp_process_history p
                     WHERE     p.source = 'Virtual Trader'
                           AND p.category = 'VT Payables'
                           AND p.rule_id IN (58, 213)) p,
                   apps.xxcp_tax_registrations comp_tax,
                   apps.xxcp_tax_registrations cust_tax,
                   (SELECT invoice_header_id, transaction_ref, ic_tax_rate,
                           ic_tax_code, ic_tax_description
                      FROM apps.xxcp_ic_inv_lines
                     WHERE attribute10 = 'T') tax_details
             WHERE     1 = 1
                   AND xih.invoice_header_id = xil.invoice_header_id
                   AND xil.transaction_ref = xgi.vt_transaction_ref
                   AND xgi.vt_parent_trx_id = xth.parent_trx_id
                   AND comp_tax.tax_registration_id = xih.invoice_tax_reg_id
                   AND cust_tax.tax_registration_id = xih.customer_tax_reg_id
                   AND xil.parent_trx_id = xgi.vt_parent_trx_id
                   AND xgi.vt_parent_trx_id = xph.parent_trx_id
                   AND xph.attribute_id = p.attribute_id
                   AND tax_details.invoice_header_id(+) =
                       xil.invoice_header_id
                   AND tax_details.transaction_ref(+) = xil.transaction_ref
                   --   AND p.TRANSACTION_TABLE='AP_INVOICES'
                   AND xgi.vt_transaction_table = 'AP_INVOICES'
                   --AND xgi.vt_transaction_ref IN ('2165289','B70BA1621DB64E15B213-1','2165287')
                   AND xgi.accounting_date BETWEEN cp_gl_date_from
                                               AND cp_gl_date_to
                   -- as part of this CCR0009604, ,commented hard coded customer tax reg id's
                   /*AND xih.customer_tax_reg_id IN (
              128,
              126,
              112,
              115,
              120,
              101,
              106,
              114
             )*/
                   -- as part of this CCR0009604, customer tax reg id's were fetching from value set
                   AND xih.customer_tax_reg_id IN
                           (SELECT TO_NUMBER (ffv.flex_value)
                              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                             WHERE     ffvs.flex_value_set_name =
                                       'XXD_VT_CONSOLIDATED_CUST_TAX_REG_ID_VS'
                                   AND ffvs.flex_value_set_id =
                                       ffv.flex_value_set_id
                                   AND ffv.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           ffv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           ffv.end_date_active,
                                                           SYSDATE + 1))
                   AND xih.invoice_date BETWEEN NVL (cp_invoice_date_from,
                                                     xih.invoice_date)
                                            AND NVL (cp_invoice_date_to,
                                                     xih.invoice_date)
                   AND (   xih.attribute2 IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_VT_CONSOLIDATED_OU_VS'
                                       AND language = USERENV ('LANG'))
                        OR     xih.attribute3 IN
                                   (SELECT lookup_code
                                      FROM fnd_lookup_values
                                     WHERE     lookup_type =
                                               'XXD_VT_CONSOLIDATED_OU_VS'
                                           AND language = USERENV ('LANG'))
                           AND xil.attribute10 = 'S');

        -------------------
        --MANUAL Extract
        -------------------
        CURSOR c_manual (cp_gl_date_from DATE, cp_gl_date_to DATE, cp_invoice_date_from DATE
                         , cp_invoice_date_to DATE)
        IS
            SELECT DISTINCT                           --xep.name legal_entity,
                   'Manual'
                       vt_source,
                   xih.invoice_number
                       invoice_number,
                   NULL
                       organization_name,
                   xil.transaction_ref
                       vt_transaction_ref,
                   xil.transaction_ref
                       oracle_ref,
                   xih.attribute2
                       sold_by_ou_code,
                   xih.attribute3
                       sold_to_ou_code,
                   NVL (xih.attribute4, comp_tax.tax_registration_ref)
                       vat_seller,
                   NVL (xih.attribute5, cust_tax.tax_registration_ref)
                       vat_buyer,
                   user_je_source_name
                       order_type_user_category,
                   NULL
                       customer_vendor_number,
                   NULL
                       customer_vendor_name,
                   TRUNC (xih.invoice_date)
                       invoice_date,
                   NULL
                       line_number,
                   xgi.vt_transaction_date
                       vt_transaction_date,
                   xgi.vt_transaction_id
                       vt_transaction_id,
                   NULL
                       actual_cost,
                   NULL
                       bill_to_address_line1,
                   NULL
                       bill_to_address_line2,
                   NULL
                       bill_to_city,
                   NULL
                       bill_to_state,
                   NULL
                       bill_to_country,
                   NULL
                       bill_to_address_key,
                   NULL
                       ship_to_address_line1,
                   NULL
                       ship_to_address_line2,
                   NULL
                       ship_to_city,
                   NULL
                       ship_to_state,
                   NULL
                       ship_to_country,
                   NULL
                       ship_to_address_key,
                   NULL
                       warehouse_name,
                   xil.ic_unit_price,
                   xil.quantity,
                   xil.ic_currency_code,
                   COALESCE (
                       (SELECT ph.attribute2
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id =
                                   xil.attribute_id
                               AND ph.status = 'GLI'
                               --AND ph.record_type = 'T'
                               --                 AND ph.segment6 in ('21801','21802')
                               --                 AND ph.attribute4 IS NULL
                               AND ph.segment6 = '21801'),
                       (SELECT ph.attribute2
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id =
                                   xil.attribute_id
                               AND ph.status = 'GLI'
                               --AND ph.record_type = 'T'
                               --                 AND ph.segment6 in ('21801','21802')
                               --                 AND ph.attribute4 IS NULL
                               AND ph.segment6 = '11301'),
                       (SELECT ph.attribute2
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id =
                                   xil.attribute_id
                               AND ph.status = 'GLI'
                               --AND ph.record_type = 'T'
                               --                 AND ph.segment6 in ('21801','21802')
                               --                 AND ph.attribute4 IS NULL
                               AND ph.rule_id = 10))
                       seller_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           --                 AND ph.segment6 in ('21801','21802')
                           --                 AND ph.attribute4 IS NULL
                           AND ph.segment6 = '21801')
                       seller_vat_account_code,
                   (SELECT ph.attribute3                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           --                 AND ph.segment6 in ('21801','21802')
                           --                   AND ph.attribute4 IS NULL
                           AND ph.segment6 = '21801')
                       seller_vat_rate,
                   --  (
                   --   SELECT
                   --    ph.attribute4
                   --   FROM
                   --    apps.xxcp_process_history ph
                   --   WHERE
                   --    ph.attribute_id = xil.attribute_id
                   --    AND ph.status = 'GLI'
                   --      --AND ph.record_type = 'T'
                   --    AND ph.segment6 IN (
                   --     '11901',
                   --     '11902'
                   --    )
                   --  ) buyer_vat_code,
                   COALESCE (
                       (SELECT ph.attribute4
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id = xil.attribute_id
                               AND ph.status = 'GLI'
                               AND ph.segment6 IN ('11901', '11902')),
                       (SELECT ph.attribute4
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id = xil.attribute_id
                               AND ph.status = 'GLI'
                               AND ph.segment6 = '11301'),
                       (SELECT ph.attribute4
                          FROM apps.xxcp_process_history ph
                         WHERE     ph.attribute_id = xil.attribute_id
                               AND ph.status = 'GLI'
                               AND ph.rule_id = 10))
                       buyer_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           AND ph.segment1 = xih.attribute3
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902'))
                       buyer_vat_acccount_code,
                   (SELECT ph.attribute5                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.segment1 = xih.attribute3--                 AND ph.attribute4 IS NULL
                                                           )
                       buyer_vat_rate,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           --                 AND ph.segment6 in ( '11901', '11902')
                           --                 AND ph.attribute4 IS NOT NULL
                           AND ph.segment6 = '21802'
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_pay_vat_rate,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           --                 AND ph.segment6 in ('21801','21802')
                           --                 AND ph.attribute4 IS NOT NULL
                           AND ph.segment6 = '21802'
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_rec_vat_acct_code,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           --                 AND ph.segment6 in ('21801','21802')
                           --                 AND ph.attribute4 IS NOT NULL
                           AND ph.segment6 = '21802'
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_rec_vat_rate,
                   ROUND (
                         (NVL (xph.entered_dr, 0) - NVL (xph.entered_cr, 0))
                       * 1--             NVL (
                          --               (SELECT conversion_rate
                          --                  FROM apps.gl_daily_rates
                          --                 WHERE     conversion_type = xgi.USER_CURRENCY_CONVERSION_TYPE
                          --                       AND from_currency = xph.CURRENCY_CODE
                          --                       AND to_currency = 'GBP'
                          --                       AND conversion_date = TRUNC (xgi.accounting_date)),1)
                          ,
                       2)
                       invoice_total,
                   NVL (
                       ROUND (
                             (SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                                FROM apps.xxcp_process_history ph
                               WHERE     ph.attribute_id = xil.attribute_id
                                     AND ph.status = 'GLI'
                                     AND ph.segment6 IN ('21801'))
                           * 1--              NVL (
                              --               (SELECT conversion_rate
                              --                  FROM apps.gl_daily_rates
                              --                 WHERE     conversion_type =  xgi.user_currency_conversion_type
                              --                       AND from_currency = xil.ic_currency_code
                              --                       AND to_currency = 'GBP'
                              --                       AND conversion_date
                              --                       = TRUNC (xgi.accounting_date)), 1)
                              ,
                           2),
                       0)
                       seller_output_vat_amount,
                   NVL (
                       ROUND (
                             (SELECT NVL (entered_dr, 0) - NVL (entered_cr, 0)
                                FROM apps.xxcp_process_history ph
                               WHERE     ph.attribute_id = xil.attribute_id
                                     AND ph.status = 'GLI'
                                     AND ph.segment6 IN ('11901', '11902')
                                     AND ph.segment1 = xih.attribute3)
                           * 1--             NVL (
                              --               (SELECT conversion_rate
                              --                  FROM apps.gl_daily_rates
                              --                 WHERE     conversion_type =  xgi.user_currency_conversion_type
                              --                       AND from_currency = xil.ic_currency_code
                              --                       AND to_currency = 'GBP'
                              --                       AND conversion_date
                              --                       = TRUNC (xgi.accounting_date)),1)
                              ,
                           2),
                       0)
                       buyer_input_vat_amount,
                   NVL (
                       ROUND (
                             (SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                                FROM apps.xxcp_process_history ph
                               WHERE     ph.attribute_id = xil.attribute_id
                                     AND ph.status = 'GLI'
                                     AND ph.segment6 IN ('21802')
                                     AND ph.segment1 = xih.attribute3)
                           * 1--   NVL (
                              --               (SELECT conversion_rate
                              --                  FROM apps.gl_daily_rates
                              --                 WHERE     conversion_type =  xgi.user_currency_conversion_type
                              --                       AND from_currency = xil.ic_currency_code
                              --                       AND to_currency = 'GBP'
                              --                       AND conversion_date =
                              --                       TRUNC (xgi.accounting_date)),1)
                              ,
                           2),
                       0)
                       buyer_output_vat_amount,
                   -- Commented as per CCR0009638

                   --        ROUND(NVL(xph.entered_dr,0) - NVL(xph.entered_cr,0),2) check_the_value,
                   --  ROUND((NVL(xph.entered_dr,0) - NVL(xph.entered_cr,0))
                   --            * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = xgi.USER_CURRENCY_CONVERSION_TYPE
                   --                       AND from_currency = xph.CURRENCY_CODE
                   --                       AND to_currency = 'GBP'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --                1),2)                                                           invoice_total_gbp,
                   --  NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                    AND ph.segment6 in ('21801')
                   --                     )
                   --   * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type =  xgi.user_currency_conversion_type
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'GBP'
                   --                       AND conversion_date
                   --                       = TRUNC (xgi.accounting_date)), 1),2),0)                 seller_output_vat_amount_gbp,
                   --  NVL(ROUND((SELECT NVL (entered_dr, 0) - NVL (entered_cr, 0)
                   --                  FROM apps.xxcp_process_history ph
                   --                 WHERE     ph.attribute_id = xil.attribute_id
                   --                       AND ph.status = 'GLI'
                   --                       AND ph.segment6 in ( '11901', '11902')
                   --                       AND ph.segment1 = xih.attribute3)
                   --            * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type =  xgi.user_currency_conversion_type
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'GBP'
                   --                       AND conversion_date
                   --                       = TRUNC (xgi.accounting_date)),
                   --                        1),2),0)                                                buyer_input_vat_amount_gbp,
                   --  NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                    AND ph.segment6 in ('21802')
                   --                    AND ph.segment1 = xih.attribute3
                   --                      )
                   --   * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type =  xgi.user_currency_conversion_type
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'GBP'
                   --                       AND conversion_date =
                   --                       TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                         buyer_output_vat_amount_gbp,
                   --  ROUND((NVL(xph.entered_dr,0) - NVL(xph.entered_cr,0))
                   --            * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = xgi.user_currency_conversion_type
                   --                       AND from_currency = xph.currency_code
                   --                       AND to_currency = 'EUR'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --                1),2)                                                           invoice_total_eur,
                   --  NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                    AND ph.segment6 in ('21801')
                   --                     )
                   --   * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'EUR'
                   --                       AND conversion_date =
                   --                        TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                         seller_output_vat_amount_eur,
                   --  NVL(ROUND(
                   --               (SELECT NVL (entered_dr, 0) - NVL (entered_cr, 0)
                   --                  FROM apps.xxcp_process_history ph
                   --                 WHERE     ph.attribute_id = xil.attribute_id
                   --                       AND ph.status = 'GLI'
                   --                       AND ph.segment6 in ( '11901', '11902')
                   --                       AND ph.segment1 = xih.attribute3
                   --                        )
                   --   * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'EUR'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                         buyer_input_vat_amount_eur,
                   --  NVL(ROUND (  (SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                    AND ph.segment6 in ('21802')
                   --                    AND ph.segment1 = xih.attribute3
                   --                      )
                   --   * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'EUR'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                         buyer_output_vat_amount_eur,
                   --  ROUND((NVL(xph.entered_dr,0) - NVL(xph.entered_cr,0))
                   --            * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = xgi.user_currency_conversion_type
                   --                       AND from_currency = xph.currency_code
                   --                       AND to_currency = 'USD'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --                1),2)                                                            invoice_total_usd,
                   --  NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                    AND ph.segment6 in ('21801')
                   --                     )
                   --   * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'USD'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                         seller_output_vat_amount_usd,
                   --  NVL(ROUND(
                   --               (SELECT NVL (entered_dr, 0) - NVL (entered_cr, 0)
                   --                  FROM apps.xxcp_process_history ph
                   --                 WHERE     ph.attribute_id = xil.attribute_id
                   --                       AND ph.status = 'GLI'
                   --                       AND ph.segment6 in ( '11901', '11902')
                   --                       AND ph.segment1 = xih.attribute3
                   --                        )
                   --            * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'USD'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                         buyer_input_vat_amount_usd,
                   --  NVL(ROUND((SELECT NVL (entered_cr, 0) - NVL (entered_dr, 0)
                   --               FROM apps.xxcp_process_history ph
                   --              WHERE     ph.attribute_id = xil.attribute_id
                   --                    AND ph.status = 'GLI'
                   --                    AND ph.segment6 in ('21802')
                   --                     )
                   --          * NVL (
                   --               (SELECT conversion_rate
                   --                  FROM apps.gl_daily_rates
                   --                 WHERE     conversion_type = 'Corporate'
                   --                       AND from_currency = xil.ic_currency_code
                   --                       AND to_currency = 'USD'
                   --                       AND conversion_date = TRUNC (xgi.accounting_date)),
                   --               1),2),0)                                                         buyer_output_vat_amount_usd,
                   -- End of Change as per CCR0009638
                   NULL
                       shipment_landed_cost_gbp,
                   NULL
                       shipment_landed_cost_eur,
                   NULL
                       shipment_landed_cost_usd,
                   NULL
                       commodity_code,
                   NULL
                       unit_weight,
                   NULL
                       style,
                   NULL
                       color,
                   NULL
                       product_group,
                   NULL
                       gender,
                   NULL
                       ship_to_zip,
                   NULL
                       seller_revenue_account,
                   NULL
                       buyer_expense_account,
                   xgi.accounting_date
                       accounting_date              -- Added as per CCR0009638
              FROM apps.xxcp_ic_inv_header xih, apps.xxcp_ic_inv_lines xil, apps.xxcp_gl_interface xgi,
                   apps.xxcp_process_history_v xph, apps.xxcp_tax_registrations comp_tax, apps.xxcp_tax_registrations cust_tax
             WHERE     1 = 1
                   AND comp_tax.tax_registration_id = xih.invoice_tax_reg_id
                   AND cust_tax.tax_registration_id = xih.customer_tax_reg_id
                   AND xih.invoice_header_id = xil.invoice_header_id
                   AND xil.transaction_ref = xgi.vt_transaction_ref
                   AND xph.interface_id = xgi.vt_interface_id
                   AND xil.parent_trx_id = xgi.vt_parent_trx_id
                   AND xph.attribute_id = xil.attribute_id
                   AND xph.rule_id IN (11)
                   AND xgi.vt_transaction_table = 'VT_MANUAL_JOURNALS'
                   AND xgi.accounting_date BETWEEN cp_gl_date_from
                                               AND cp_gl_date_to
                   AND (   xih.attribute2 IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_VT_CONSOLIDATED_OU_VS'
                                       AND language = USERENV ('LANG'))
                        OR xih.attribute3 IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_VT_CONSOLIDATED_OU_VS'
                                       AND language = USERENV ('LANG')))
                   AND xih.invoice_date BETWEEN NVL (cp_invoice_date_from,
                                                     xih.invoice_date)
                                            AND NVL (cp_invoice_date_to,
                                                     xih.invoice_date)
                   AND xil.attribute10 = 'S';

        -------------------
        --PROJECT Extract
        -------------------
        CURSOR c_projects (cp_gl_date_from DATE, cp_gl_date_to DATE, cp_invoice_date_from DATE
                           , cp_invoice_date_to DATE)
        IS
            SELECT DISTINCT                           --xep.name LEGAL_ENTITY,
                   'Projects'
                       vt_source,
                   xih.invoice_number
                       invoice_number,
                   xil.transaction_ref
                       vt_transaction_ref,
                   NULL
                       oracle_ref,
                   /*(SELECT name
             FROM apps.xle_entity_profiles
            WHERE 1 = 1 AND LEGAL_ENTITY_IDENTIFIER = TO_NUMBER (xih.attribute2))
             SOLD_BY_OU,*/
                   xih.attribute2
                       sold_by_ou_code,
                   /*(SELECT name
            FROM apps.xle_entity_profiles
           WHERE 1 = 1 AND LEGAL_ENTITY_IDENTIFIER = TO_NUMBER (xih.attribute3))
            SOLD_TO_OU,*/
                   xih.attribute3
                       sold_to_ou_code,
                   DECODE (
                       xxd_vt_ics_invoices_pkg.get_source (
                           xih.invoice_header_id),
                       'Material Transactions', xxd_vt_ics_invoices_pkg.get_comp_tax_reg (
                                                    'INV',
                                                    xih.attribute2,
                                                    xih.invoice_tax_reg_id,
                                                    xih.invoice_header_id),
                       comp_tax.tax_registration_ref)
                       vat_seller,
                   NVL (xih.attribute5,
                        cust_tax.tax_registration_ref)
                       vat_buyer,
                   user_je_source_name
                       order_type_user_category,
                   NULL
                       customer_vendor_number,
                   NULL
                       customer_vendor_name,
                   TRUNC (xih.invoice_date)
                       invoice_date,
                   NULL
                       line_number,
                   --NULL INVENTORY_ITEM_ID,
                   --NULL ORDERED_ITEM,
                   NULL
                       vt_transaction_date,
                   NULL
                       vt_transaction_id,
                   NULL
                       actual_cost,
                   NULL
                       bill_to_address_line1,
                   NULL
                       bill_to_address_line2,
                   NULL
                       bill_to_city,
                   NULL
                       bill_to_state,
                   NULL
                       bill_to_country,
                   NULL
                       bill_to_address_key,
                   NULL
                       ship_to_address_line1,
                   NULL
                       ship_to_address_line2,
                   NULL
                       ship_to_city,
                   NULL
                       ship_to_state,
                   NULL
                       ship_to_country,
                   NULL
                       ship_to_address_key,
                   NULL
                       warehouse_name,
                   xil.ic_unit_price,
                   xil.quantity,
                   xil.ic_currency_code,
                   (SELECT ph.attribute1
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')--  -- AND ph.attribute4 IS NULL
                                                                )
                       seller_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NULL)
                       seller_vat_account_code,
                   (SELECT ph.attribute2                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')--  -- AND ph.attribute4 IS NULL
                                                                )
                       seller_vat_rate,
                   (SELECT ph.attribute3
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902'))
                       buyer_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902'))
                       buyer_vat_acccount_code,
                   (SELECT ph.attribute4                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.segment1 = xih.attribute3
                           AND ph.attribute4 IS NULL)
                       buyer_vat_rate,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.attribute4 IS NOT NULL
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_pay_vat_rate,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NOT NULL
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_rec_vat_acct_code,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NOT NULL
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_rec_vat_rate,
                     NVL (
                         ROUND (
                               xph.entered_dr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'GBP'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                   - NVL (
                         ROUND (
                               xph.entered_cr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'GBP'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                       invoice_total_gbp,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')--  -- AND ph.attribute4 IS NULL
                                                                   )
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'GBP'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       seller_output_vat_amount_gbp,
                   (  NVL (
                          (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.segment1 = xih.attribute3
                                  AND ph.attribute4 IS NULL),
                          (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.attribute4 IS NOT NULL
                                  AND ph.segment1 = xih.attribute3))
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'GBP'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_input_vat_amount_gbp,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NOT NULL
                              AND ph.segment1 = xih.attribute3)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'GBP'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_output_vat_amount_gbp,
                     NVL (
                         ROUND (
                               xph.entered_dr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'EUR'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                   - NVL (
                         ROUND (
                               xph.entered_cr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'EUR'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                       invoice_total_eur,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')--  -- AND ph.attribute4 IS NULL
                                                                   )
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'EUR'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       seller_output_vat_amount_eur,
                   (  NVL (
                          (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.segment1 = xih.attribute3
                                  AND ph.attribute4 IS NULL),
                          (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.attribute4 IS NOT NULL
                                  AND ph.segment1 = xih.attribute3))
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'EUR'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_input_vat_amount_eur,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NOT NULL
                              AND ph.segment1 = xih.attribute3)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'EUR'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_output_vat_amount_eur,
                     NVL (
                         ROUND (
                               xph.entered_dr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'USD'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                   - NVL (
                         ROUND (
                               xph.entered_cr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'USD'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                       invoice_total_usd,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')--  AND ph.attribute4 IS NULL
                                                                   )
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'USD'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       seller_output_vat_amount_usd,
                   (  NVL (
                          (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.segment1 = xih.attribute3
                                  AND ph.attribute4 IS NULL),
                          (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.attribute4 IS NOT NULL
                                  AND ph.segment1 = xih.attribute3))
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'USD'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_input_vat_amount_usd,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NOT NULL
                              AND ph.segment1 = xih.attribute3)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'USD'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_output_vat_amount_usd,
                   NULL
                       shipment_landed_cost_gbp,
                   NULL
                       shipment_landed_cost_eur,
                   NULL
                       shipment_landed_cost_usd,
                   NULL
                       commodity_code,
                   NULL
                       unit_weight,
                   NULL
                       style,
                   NULL
                       color,
                   NULL
                       product_group,
                   NULL
                       gender,
                   NULL
                       ship_to_zip,
                   NULL
                       seller_revenue_account,
                   NULL
                       buyer_expense_account
              /* replace(
            replace(
             replace(RTRIM(xil.attribute2), CHR(10), ' ')
            , CHR(13), ' ')
           , CHR(09), ' ')  attribute2*/
              FROM xxcp.xxcp_ic_inv_header xih,
                   xxcp.xxcp_ic_inv_lines xil,
                   -- xxcp.xxcp_transaction_header xth,
                   xxcp.xxcp_gl_interface xgi,
                   (SELECT /*+ FULL(xph) PARALLEL(xph, 4)*/
                           xph.*
                      FROM apps.xxcp_process_history_v xph
                     WHERE     xph.source = 'Virtual Trader'
                           AND xph.category = 'VT Projects'
                           AND xph.transaction_table = 'PA_EXPENDITURES') xph,
                   /*  ( SELECT  /  p.*
             from
             apps.xxcp_process_history p
             where
              p.SOURCE='Virtual Trader'
               AND p.CATEGORY='VT Projects'
              ) p,*/
                   --  apps.xxcp_account_rules xar,
                   apps.xxcp_tax_registrations comp_tax,
                   apps.xxcp_tax_registrations cust_tax,
                   (SELECT invoice_header_id, transaction_ref, ic_tax_rate,
                           ic_tax_code, ic_tax_description
                      FROM xxcp_ic_inv_lines
                     WHERE attribute10 = 'T') tax_details
             WHERE     1 = 1
                   AND xih.invoice_header_id = xil.invoice_header_id
                   AND xil.transaction_ref = xgi.vt_transaction_ref
                   AND xil.parent_trx_id = xgi.vt_parent_trx_id
                   AND xgi.vt_parent_trx_id = xph.parent_trx_id
                   --  AND xph.process_history_id = p.process_history_id
                   --  AND p.SOURCE='Virtual Trader'
                   --  AND p.CATEGORY='VT Projects'
                   AND xph.rule_id IN (69, 189)
                   --  AND xar.transaction_type = 'LABOR'
                   --  AND xar.rule_id IN (69, 189) --Partner Project CC Credit Labor Cost, Owner Employee CC Capitalized Labor
                   AND xgi.vt_transaction_table = 'PA_EXPENDITURES'
                   AND comp_tax.tax_registration_id = xih.invoice_tax_reg_id
                   AND cust_tax.tax_registration_id = xih.customer_tax_reg_id
                   AND tax_details.invoice_header_id(+) =
                       xil.invoice_header_id
                   AND tax_details.transaction_ref(+) = xil.transaction_ref
                   AND xgi.accounting_date BETWEEN cp_gl_date_from
                                               AND cp_gl_date_to
                   AND (   xih.attribute2 IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_VT_CONSOLIDATED_OU_VS'
                                       AND language = USERENV ('LANG'))
                        OR xih.attribute3 IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_VT_CONSOLIDATED_OU_VS'
                                       AND language = USERENV ('LANG')))
                   AND xil.attribute10 = 'S'
                   AND xih.invoice_date BETWEEN NVL (cp_invoice_date_from,
                                                     xih.invoice_date)
                                            AND NVL (cp_invoice_date_to,
                                                     xih.invoice_date)
            UNION ALL
            SELECT DISTINCT                           --xep.name LEGAL_ENTITY,
                   'Projects'
                       vt_source,
                   xih.invoice_number
                       invoice_number,
                   xil.transaction_ref
                       vt_transaction_ref,
                   NULL
                       oracle_ref,
                   /*(SELECT name
          FROM apps.xle_entity_profiles
         WHERE 1 = 1 AND LEGAL_ENTITY_IDENTIFIER = TO_NUMBER (xih.attribute2))
          SOLD_BY_OU,*/
                   xih.attribute2
                       sold_by_ou_code,
                   /*(SELECT name
         FROM apps.xle_entity_profiles
        WHERE 1 = 1 AND LEGAL_ENTITY_IDENTIFIER = TO_NUMBER (xih.attribute3))
         SOLD_TO_OU,*/
                   xih.attribute3
                       sold_to_ou_code,
                   DECODE (
                       xxd_vt_ics_invoices_pkg.get_source (
                           xih.invoice_header_id),
                       'Material Transactions', xxd_vt_ics_invoices_pkg.get_comp_tax_reg (
                                                    'INV',
                                                    xih.attribute2,
                                                    xih.invoice_tax_reg_id,
                                                    xih.invoice_header_id),
                       comp_tax.tax_registration_ref)
                       vat_seller,
                   NVL (xih.attribute5,
                        cust_tax.tax_registration_ref)
                       vat_buyer,
                   user_je_source_name
                       order_type_user_category,
                   NULL
                       customer_vendor_number,
                   NULL
                       customer_vendor_name,
                   TRUNC (xih.invoice_date)
                       invoice_date,
                   NULL
                       line_number,
                   --NULL INVENTORY_ITEM_ID,
                   --NULL ORDERED_ITEM,
                   NULL
                       vt_transaction_date,
                   NULL
                       vt_transaction_id,
                   NULL
                       actual_cost,
                   NULL
                       bill_to_address_line1,
                   NULL
                       bill_to_address_line2,
                   NULL
                       bill_to_city,
                   NULL
                       bill_to_state,
                   NULL
                       bill_to_country,
                   NULL
                       bill_to_address_key,
                   NULL
                       ship_to_address_line1,
                   NULL
                       ship_to_address_line2,
                   NULL
                       ship_to_city,
                   NULL
                       ship_to_state,
                   NULL
                       ship_to_country,
                   NULL
                       ship_to_address_key,
                   NULL
                       warehouse_name,
                   xil.ic_unit_price,
                   xil.quantity,
                   xil.ic_currency_code,
                   (SELECT ph.attribute1
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')-- AND ph.attribute4 IS NULL
                                                                )
                       seller_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NULL)
                       seller_vat_account_code,
                   (SELECT ph.attribute2                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')-- AND ph.attribute4 IS NULL
                                                                )
                       seller_vat_rate,
                   (SELECT ph.attribute3
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902'))
                       buyer_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902'))
                       buyer_vat_acccount_code,
                   (SELECT ph.attribute4                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.segment1 = xih.attribute3
                           AND ph.attribute4 IS NULL)
                       buyer_vat_rate,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.attribute4 IS NOT NULL
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_pay_vat_rate,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NOT NULL
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_rec_vat_acct_code,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NOT NULL
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_rec_vat_rate,
                     NVL (
                         ROUND (
                               xph.entered_dr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'GBP'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                   - NVL (
                         ROUND (
                               xph.entered_cr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'GBP'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                       invoice_total_gbp,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')-- AND ph.attribute4 IS NULL
                                                                   )
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'GBP'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       seller_output_vat_amount_gbp,
                   (  NVL (
                          (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.segment1 = xih.attribute3
                                  AND ph.attribute4 IS NULL),
                          (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.attribute4 IS NOT NULL
                                  AND ph.segment1 = xih.attribute3))
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'GBP'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_input_vat_amount_gbp,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NOT NULL
                              AND ph.segment1 = xih.attribute3)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'GBP'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_output_vat_amount_gbp,
                     NVL (
                         ROUND (
                               xph.entered_dr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'EUR'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                   - NVL (
                         ROUND (
                               xph.entered_cr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'EUR'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                       invoice_total_eur,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')-- AND ph.attribute4 IS NULL
                                                                   )
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'EUR'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       seller_output_vat_amount_eur,
                   (  NVL (
                          (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.segment1 = xih.attribute3
                                  AND ph.attribute4 IS NULL),
                          (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.attribute4 IS NOT NULL
                                  AND ph.segment1 = xih.attribute3))
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'EUR'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_input_vat_amount_eur,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NOT NULL
                              AND ph.segment1 = xih.attribute3)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'EUR'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_output_vat_amount_eur,
                     NVL (
                         ROUND (
                               xph.entered_dr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'USD'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                   - NVL (
                         ROUND (
                               xph.entered_cr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'USD'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                       invoice_total_usd,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')-- AND ph.attribute4 IS NULL
                                                                   )
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'USD'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       seller_output_vat_amount_usd,
                   (  NVL (
                          (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.segment1 = xih.attribute3
                                  AND ph.attribute4 IS NULL),
                          (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.attribute4 IS NOT NULL
                                  AND ph.segment1 = xih.attribute3))
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'USD'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_input_vat_amount_usd,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NOT NULL
                              AND ph.segment1 = xih.attribute3)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'USD'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_output_vat_amount_usd,
                   NULL
                       shipment_landed_cost_gbp,
                   NULL
                       shipment_landed_cost_eur,
                   NULL
                       shipment_landed_cost_usd,
                   NULL
                       commodity_code,
                   NULL
                       unit_weight,
                   NULL
                       style,
                   NULL
                       color,
                   NULL
                       product_group,
                   NULL
                       gender,
                   NULL
                       ship_to_zip,
                   NULL
                       seller_revenue_account,
                   NULL
                       buyer_expense_account
              /*replace(
    replace(
     replace(RTRIM(xil.attribute2), CHR(10), ' ')
    , CHR(13), ' ')
   , CHR(09), ' ')  attribute2*/
              FROM xxcp.xxcp_ic_inv_header xih,
                   xxcp.xxcp_ic_inv_lines xil,
                   xxcp.xxcp_transaction_header xth,
                   xxcp.xxcp_gl_interface xgi,
                   (SELECT /*+ FULL(xph) PARALLEL(xph, 4)*/
                           xph.*
                      FROM apps.xxcp_process_history_v xph
                     WHERE     xph.source = 'Virtual Trader'
                           AND xph.category = 'VT Projects'
                           AND xph.transaction_table = 'PA_EXPENDITURES') xph,
                   /* ( SELECT    p.*
        from
        apps.xxcp_process_history p
        where
          p.SOURCE='Virtual Trader'
            AND p.CATEGORY='VT Projects'
          ) p,*/
                   --       gl_je_lines gjl,
                   --       gl_je_headers gjh,
                   apps.xxcp_account_rules xar,
                   apps.xxcp_tax_registrations comp_tax,
                   apps.xxcp_tax_registrations cust_tax,
                   (SELECT invoice_header_id, transaction_ref, ic_tax_rate,
                           ic_tax_code, ic_tax_description
                      FROM xxcp_ic_inv_lines
                     WHERE attribute10 = 'T') tax_details
             WHERE     1 = 1
                   AND xih.invoice_header_id = xil.invoice_header_id
                   AND xil.transaction_ref = xgi.vt_transaction_ref
                   AND xil.parent_trx_id = xgi.vt_parent_trx_id
                   AND xgi.vt_parent_trx_id = xph.parent_trx_id
                   AND xgi.vt_parent_trx_id = xth.parent_trx_id
                   --  AND xph.process_history_id = p.process_history_id
                   AND comp_tax.tax_registration_id = xih.invoice_tax_reg_id
                   AND cust_tax.tax_registration_id = xih.customer_tax_reg_id
                   AND tax_details.invoice_header_id(+) =
                       xil.invoice_header_id
                   AND tax_details.transaction_ref(+) = xil.transaction_ref
                   --  AND xph.rule_id =p.rule_id
                   AND xph.rule_id IN (194, 196) ----Owner Source Currency Code Intermmediate Clearing, Partner Destination Currency Code Intermmediate Clearing
                   AND xgi.vt_transaction_table = 'PA_EXPENDITURES'
                   AND xgi.accounting_date BETWEEN cp_gl_date_from
                                               AND cp_gl_date_to
                   AND (   xih.attribute2 IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_VT_CONSOLIDATED_OU_VS'
                                       AND language = USERENV ('LANG'))
                        OR xih.attribute3 IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_VT_CONSOLIDATED_OU_VS'
                                       AND language = USERENV ('LANG')))
                   AND xil.attribute10 = 'S'
                   AND xih.invoice_date BETWEEN NVL (cp_invoice_date_from,
                                                     xih.invoice_date)
                                            AND NVL (cp_invoice_date_to,
                                                     xih.invoice_date);

        -------------------
        --ASSET Extract
        -------------------
        CURSOR c_assets (cp_gl_date_from DATE, cp_gl_date_to DATE, cp_invoice_date_from DATE
                         , cp_invoice_date_to DATE)
        IS
            SELECT DISTINCT
                   'Assets'
                       vt_source,
                   xih.invoice_number
                       invoice_number,
                   xil.transaction_ref
                       vt_transaction_ref,
                   fth.asset_id
                       oracle_ref,
                   /*(SELECT name
             FROM apps.xle_entity_profiles
            WHERE 1 = 1 AND LEGAL_ENTITY_IDENTIFIER = TO_NUMBER (xih.attribute2))
             SOLD_BY_OU,*/
                   xih.attribute2
                       sold_by_ou_code,
                   /*(SELECT name
            FROM apps.xle_entity_profiles
           WHERE 1 = 1 AND LEGAL_ENTITY_IDENTIFIER = TO_NUMBER (xih.attribute3))
            SOLD_TO_OU,*/
                   xih.attribute3
                       sold_to_ou_code,
                   DECODE (
                       xxd_vt_ics_invoices_pkg.get_source (
                           xih.invoice_header_id),
                       'Material Transactions', xxd_vt_ics_invoices_pkg.get_comp_tax_reg (
                                                    'INV',
                                                    xih.attribute2,
                                                    xih.invoice_tax_reg_id,
                                                    xih.invoice_header_id),
                       comp_tax.tax_registration_ref)
                       vat_seller,
                   NVL (xih.attribute5,
                        cust_tax.tax_registration_ref)
                       vat_buyer,
                   user_je_source_name
                       order_type_user_category,
                   NULL
                       customer_vendor_number,
                   NULL
                       customer_vendor_name,
                   TRUNC (xih.invoice_date)
                       invoice_date,
                   NULL
                       line_number,
                   -- NULL INVENTORY_ITEM_ID,
                   -- NULL ORDERED_ITEM,
                   NULL
                       vt_transaction_date,
                   NULL
                       vt_transaction_id,
                   NULL
                       actual_cost,
                   NULL
                       bill_to_address_line1,
                   NULL
                       bill_to_address_line2,
                   NULL
                       bill_to_city,
                   NULL
                       bill_to_state,
                   NULL
                       bill_to_country,
                   NULL
                       bill_to_address_key,
                   NULL
                       ship_to_address_line1,
                   NULL
                       ship_to_address_line2,
                   NULL
                       ship_to_city,
                   NULL
                       ship_to_state,
                   NULL
                       ship_to_country,
                   NULL
                       ship_to_address_key,
                   NULL
                       warehouse_name,
                   xil.ic_unit_price,
                   xil.quantity,
                   xil.ic_currency_code,
                   (SELECT ph.attribute1
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')-- AND ph.attribute4 IS NULL
                                                                )
                       seller_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NULL)
                       seller_vat_account_code,
                   (SELECT ph.attribute2                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NULL)
                       seller_vat_rate,
                   (SELECT ph.attribute3
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902'))
                       buyer_vat_code,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902'))
                       buyer_vat_acccount_code,
                   (SELECT ph.attribute4                      ---ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.segment1 = xih.attribute3
                           AND ph.attribute4 IS NULL)
                       buyer_vat_rate,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('11901', '11902')
                           AND ph.attribute4 IS NOT NULL
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_pay_vat_rate,
                   (SELECT ph.segment1 || '.' || ph.segment2 || '.' || ph.segment3 || '.' || ph.segment4 || '.' || ph.segment5 || '.' || ph.segment6 || '.' || ph.segment7 || '.' || ph.segment8
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NOT NULL
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_rec_vat_acct_code,
                   (SELECT ph.attribute5
                      FROM apps.xxcp_process_history ph
                     WHERE     ph.attribute_id = xil.attribute_id
                           AND ph.status = 'GLI'
                           --AND ph.record_type = 'T'
                           AND ph.segment6 IN ('21801', '21802')
                           AND ph.attribute4 IS NOT NULL
                           AND ph.segment1 = xih.attribute3)
                       rev_buyer_rec_vat_rate,
                     NVL (
                         ROUND (
                               xph.entered_dr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'GBP'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                   - NVL (
                         ROUND (
                               xph.entered_cr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'GBP'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                       invoice_total_gbp,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NULL)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'GBP'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       seller_output_vat_amount_gbp,
                   (  NVL (
                          (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.segment1 = xih.attribute3
                                  AND ph.attribute4 IS NULL),
                          (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.attribute4 IS NOT NULL
                                  AND ph.segment1 = xih.attribute3))
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'GBP'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_input_vat_amount_gbp,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NOT NULL
                              AND ph.segment1 = xih.attribute3)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'GBP'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_output_vat_amount_gbp,
                     NVL (
                         ROUND (
                               xph.entered_dr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'EUR'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                   - NVL (
                         ROUND (
                               xph.entered_cr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'EUR'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                       invoice_total_eur,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')-- AND ph.attribute4 IS NULL
                                                                   )
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'EUR'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       seller_output_vat_amount_eur,
                   (  NVL (
                          (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.segment1 = xih.attribute3
                                  AND ph.attribute4 IS NULL),
                          (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.attribute4 IS NOT NULL
                                  AND ph.segment1 = xih.attribute3))
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'EUR'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_input_vat_amount_eur,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NOT NULL
                              AND ph.segment1 = xih.attribute3)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'EUR'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_output_vat_amount_eur,
                     NVL (
                         ROUND (
                               xph.entered_dr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'USD'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                   - NVL (
                         ROUND (
                               xph.entered_cr
                             * NVL (
                                   (SELECT conversion_rate
                                      FROM apps.gl_daily_rates
                                     WHERE     conversion_type = 'Corporate'
                                           AND from_currency =
                                               xph.currency_code
                                           AND to_currency = 'USD'
                                           AND conversion_date =
                                               TRUNC (xgi.accounting_date)),
                                   1),
                             2),
                         0)
                       invoice_total_usd,
                   (  (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')-- AND ph.attribute4 IS NULL
                                                                   )
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'USD'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       seller_output_vat_amount_usd,
                   (  NVL (
                          (SELECT NVL (entered_cr, 0) + NVL (entered_dr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.segment1 = xih.attribute3
                                  AND ph.attribute4 IS NULL),
                          (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                             FROM apps.xxcp_process_history ph
                            WHERE     ph.attribute_id = xil.attribute_id
                                  AND ph.status = 'GLI'
                                  --AND ph.record_type = 'T'
                                  AND ph.segment6 IN ('11901', '11902')
                                  AND ph.attribute4 IS NOT NULL
                                  AND ph.segment1 = xih.attribute3))
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'USD'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_input_vat_amount_usd,
                   (  (SELECT NVL (entered_dr, 0) + NVL (entered_cr, 0)
                         FROM apps.xxcp_process_history ph
                        WHERE     ph.attribute_id = xil.attribute_id
                              AND ph.status = 'GLI'
                              --AND ph.record_type = 'T'
                              AND ph.segment6 IN ('21801', '21802')
                              AND ph.attribute4 IS NOT NULL
                              AND ph.segment1 = xih.attribute3)
                    * NVL (
                          (SELECT conversion_rate
                             FROM apps.gl_daily_rates
                            WHERE     conversion_type = 'Corporate'
                                  AND from_currency = xil.ic_currency_code
                                  AND to_currency = 'USD'
                                  AND conversion_date =
                                      TRUNC (xgi.accounting_date)),
                          1))
                       buyer_output_vat_amount_usd,
                   NULL
                       shipment_landed_cost_gbp,
                   NULL
                       shipment_landed_cost_eur,
                   NULL
                       shipment_landed_cost_usd,
                   NULL
                       commodity_code,
                   NULL
                       unit_weight,
                   NULL
                       style,
                   NULL
                       color,
                   NULL
                       product_group,
                   NULL
                       gender,
                   NULL
                       ship_to_zip,
                   NULL
                       seller_revenue_account,
                   NULL
                       buyer_expense_account
              /* replace(
         replace(
          replace(RTRIM(xil.attribute2), CHR(10), ' ')
         , CHR(13), ' ')
        , CHR(09), ' ')  attribute2 */
              FROM xxcp.xxcp_ic_inv_header xih,
                   xxcp.xxcp_ic_inv_lines xil,
                   xxcp.xxcp_gl_interface xgi,
                   (SELECT /*+ FULL(xph) PARALLEL(xph, 4)*/
                           xph.*
                      FROM apps.xxcp_process_history_v xph
                     WHERE     xph.source = 'Virtual Trader'
                           AND xph.category = 'VT Fixed Assets'
                           AND xph.transaction_table = 'ASSETS') xph,
                   /*  ( SELECT  /  p.*
             from
             apps.xxcp_process_history p
             where
            p.SOURCE='Virtual Trader'
              AND p.CATEGORY='VT Fixed Assets'
            ) p, */
                   xxcp.xxcp_transaction_header xth,
                   apps.gl_ledgers gll,
                   apps.fa_transaction_headers fth,
                   apps.xla_ae_headers aeh,
                   apps.xla_ae_lines ael,
                   apps.gl_code_combinations_kfv gcc,
                   apps.xxcp_tax_registrations comp_tax,
                   apps.xxcp_tax_registrations cust_tax,
                   (SELECT DISTINCT invoice_header_id, transaction_ref, ic_tax_rate,
                                    ic_tax_code, ic_tax_description
                      FROM xxcp_ic_inv_lines
                     WHERE attribute10 = 'T') tax_details
             WHERE     1 = 1
                   --and xih.invoice_number = '110-00005404'
                   AND xih.invoice_header_id = xil.invoice_header_id
                   AND xil.transaction_ref = xgi.vt_transaction_ref
                   --       AND xil.transaction_ref = '2'
                   --       AND xgi.vt_transaction_ref = '45992'
                   AND xil.parent_trx_id = xgi.vt_parent_trx_id
                   AND xth.parent_trx_id = xgi.vt_parent_trx_id
                   --         and xgi.vt_parent_trx_id = xph.parent_trx_id
                   AND gll.ledger_id = xgi.ledger_id
                   --         AND gll.ledger_id = hou.set_of_books_id
                   AND xth.transaction_ref1 = TO_CHAR (fth.asset_id)
                   AND fth.transaction_type_code = 'ADDITION'
                   AND fth.event_id = aeh.event_id
                   AND aeh.ledger_id = gll.ledger_id
                   AND aeh.ae_header_id = ael.ae_header_id
                   AND ael.code_combination_id = gcc.code_combination_id
                   AND xgi.vt_transaction_table = 'ASSETS'
                   AND comp_tax.tax_registration_id = xih.invoice_tax_reg_id
                   AND cust_tax.tax_registration_id = xih.customer_tax_reg_id
                   AND tax_details.invoice_header_id(+) =
                       xil.invoice_header_id
                   AND tax_details.transaction_ref(+) = xil.transaction_ref
                   --  AND xph.process_history_id = p.process_history_id
                   AND xph.rule_id IN (183, 70)
                   AND xgi.vt_parent_trx_id = xph.parent_trx_id
                   AND xgi.accounting_date BETWEEN cp_gl_date_from
                                               AND cp_gl_date_to
                   AND (   xih.attribute2 IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_VT_CONSOLIDATED_OU_VS'
                                       AND language = USERENV ('LANG'))
                        OR xih.attribute3 IN
                               (SELECT lookup_code
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXD_VT_CONSOLIDATED_OU_VS'
                                       AND language = USERENV ('LANG')))
                   AND xil.attribute10 = 'S'
                   AND xih.invoice_date BETWEEN NVL (cp_invoice_date_from,
                                                     xih.invoice_date)
                                            AND NVL (cp_invoice_date_to,
                                                     xih.invoice_date);

        ----------------
        --Write Out File
        ----------------
        CURSOR c_out IS
              SELECT vt_source || lv_delimiter || invoice_number || lv_delimiter || vt_transaction_ref || lv_delimiter || oracle_ref || lv_delimiter /* ||sold_by_ou
                                                                                                                                          || lv_delimiter*/
                                                                                                                                                     || sold_by_ou_code || lv_delimiter /* ||sold_to_ou
                                                                                                                                                                             || lv_delimiter*/
                                                                                                                                                                                        || sold_to_ou_code || lv_delimiter || vat_seller || lv_delimiter || vat_buyer || lv_delimiter || order_type_user_category || lv_delimiter || customer_vendor_number || lv_delimiter || customer_vendor_name || lv_delimiter || invoice_date || lv_delimiter || line_number || lv_delimiter /*||inventory_item_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                       || lv_delimiter
                                                                                                                                                                                                                                                                                                                                                                                                                                                                       ||ordered_item
                                                                                                                                                                                                                                                                                                                                                                                                                                                                       || lv_delimiter*/
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   || vt_transaction_date || lv_delimiter || vt_transaction_id || lv_delimiter || ROUND (actual_cost, 2) || lv_delimiter || bill_to_address_line1 || lv_delimiter || bill_to_address_line2 || lv_delimiter || bill_to_city || lv_delimiter || bill_to_state || lv_delimiter || bill_to_country || lv_delimiter || bill_to_address_key || lv_delimiter || ship_to_address_line1 || lv_delimiter || ship_to_address_line2 || lv_delimiter || ship_to_city || lv_delimiter || ship_to_state || lv_delimiter || ship_to_country || lv_delimiter || ship_to_address_key || lv_delimiter || warehouse_name || lv_delimiter || ic_unit_price || lv_delimiter || quantity || lv_delimiter || ic_currency_code || lv_delimiter --1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      || SUBSTR (seller_vat_code, 1, 2) || lv_delimiter --1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        || seller_vat_code || lv_delimiter || seller_vat_account_code || lv_delimiter || seller_vat_rate || lv_delimiter --1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         || SUBSTR (buyer_vat_code, 1, 2) || lv_delimiter --1.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          || buyer_vat_code || lv_delimiter || buyer_vat_acccount_code || lv_delimiter || buyer_vat_rate || lv_delimiter || rev_buyer_pay_vat_rate || lv_delimiter || rev_buyer_rec_vat_acct_code || lv_delimiter || rev_buyer_rec_vat_rate || lv_delimiter || ROUND (invoice_total_gbp, 2) || lv_delimiter || ROUND (seller_output_vat_amount_gbp, 2) || lv_delimiter || ROUND (buyer_input_vat_amount_gbp, 2) || lv_delimiter || ROUND (buyer_output_vat_amount_gbp, 2) || lv_delimiter || ROUND (invoice_total_eur, 2) || lv_delimiter || ROUND (seller_output_vat_amount_eur, 2) || lv_delimiter || ROUND (buyer_input_vat_amount_eur, 2) || lv_delimiter || ROUND (buyer_output_vat_amount_eur, 2) || lv_delimiter || ROUND (invoice_total_usd, 2) || lv_delimiter || ROUND (seller_output_vat_amount_usd, 2) || lv_delimiter || ROUND (buyer_input_vat_amount_usd, 2) || lv_delimiter || ROUND (buyer_output_vat_amount_usd, 2) || lv_delimiter || ROUND (shipment_landed_cost_gbp, 2) || lv_delimiter || ROUND (shipment_landed_cost_eur, 2) || lv_delimiter || ROUND (shipment_landed_cost_usd, 2) || lv_delimiter || commodity_code || lv_delimiter || unit_weight || lv_delimiter || style || lv_delimiter || color || lv_delimiter || product_group || lv_delimiter || gender || lv_delimiter || ship_to_zip || lv_delimiter || seller_revenue_account || lv_delimiter || buyer_expense_account /*|| lv_delimiter
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               ||attribute2*/
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           rep_data
                FROM xxdo.xxd_vt_consolidated_ext_t
               WHERE 1 = 1 AND request_id = gn_request_id
            ORDER BY gn_request_id, vt_source;

        --Type variables declaration
        TYPE t_material IS TABLE OF c_material%ROWTYPE;

        rec_material            t_material;

        TYPE t_payables IS TABLE OF c_payables%ROWTYPE;

        rec_payables            t_payables;

        TYPE t_manual IS TABLE OF c_manual%ROWTYPE;

        rec_manual              t_manual;

        TYPE t_projects IS TABLE OF c_projects%ROWTYPE;

        rec_projects            t_projects;

        TYPE t_assets IS TABLE OF c_assets%ROWTYPE;

        rec_assets              t_assets;

        lv_bulk_limit           NUMBER := 1000;
        ln_cnt                  NUMBER := 0;
        lv_seller_tax_country   VARCHAR2 (10);                           --1.2
        lv_buyer_tax_country    VARCHAR2 (10);                           --1.2

        lv_outbound_file        VARCHAR2 (100)
            :=    'VT_CONSOLIDATED_REPORT_'
               || gn_request_id
               || '_'
               || TO_CHAR (SYSDATE, 'DDMONYYHH24MISS')
               || '.txt';
        lv_output_file          UTL_FILE.file_type;
        pv_directory_name       VARCHAR2 (100)
                                    := 'XXD_VT_CONSOL_REPORT_OUT_DIR';
        lv_line                 VARCHAR2 (4000);
        lv_err_msg              VARCHAR2 (4000);
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                '***Input DATE Parameters***');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'p_invoice_date_from :' || p_invoice_date_from);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'p_invoice_date_to :' || p_invoice_date_to);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'p_gl_date_from :' || p_gl_date_from);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'p_gl_date_to :' || p_gl_date_to);

        lv_invoice_date_from   :=
            fnd_conc_date.string_to_date (p_invoice_date_from);
        lv_invoice_date_to   :=
            fnd_conc_date.string_to_date (p_invoice_date_to);
        lv_gl_date_from   := fnd_conc_date.string_to_date (p_gl_date_from);
        lv_gl_date_to     := fnd_conc_date.string_to_date (p_gl_date_to);

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                '***Post Conversion of DATE Parameters***');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'lv_invoice_date_from :' || lv_invoice_date_from);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'lv_invoice_date_to :' || lv_invoice_date_to);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'lv_gl_date_from :' || lv_gl_date_from);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'lv_gl_date_to :' || lv_gl_date_to);

        --Deleting existing records in Table prior Insertion
        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_vt_consolidated_ext_t';

        --MATERIAL
        fnd_file.put_line (
            fnd_file.LOG,
               'Material Extract - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        OPEN c_material (lv_gl_date_from, lv_gl_date_to, lv_invoice_date_from
                         , lv_invoice_date_to);

        LOOP
            FETCH c_material
                BULK COLLECT INTO rec_material
                LIMIT lv_bulk_limit;

            BEGIN
                FORALL i IN 1 .. rec_material.COUNT
                    INSERT INTO xxdo.xxd_vt_consolidated_ext_t (
                                    vt_source,
                                    invoice_number,
                                    vt_transaction_ref,
                                    oracle_ref,
                                    sold_by_ou_code,
                                    sold_to_ou_code,
                                    vat_seller,
                                    vat_buyer,
                                    order_type_user_category,
                                    --           customer_vendor_number, -- Commented as per CCR0009638
                                    --           customer_vendor_name,   -- Commented as per CCR0009638
                                    invoice_date,
                                    line_number,
                                    --inventory_item_id,
                                    --ordered_item,
                                    vt_transaction_date,
                                    vt_transaction_id,
                                    actual_cost,
                                    -- Commented as per CCR0009638
                                    --           bill_to_address_line1,
                                    --           bill_to_address_line2,
                                    --           bill_to_city,
                                    --           bill_to_state,
                                    --           bill_to_country,
                                    --           bill_to_address_key,
                                    --           ship_to_address_line1,
                                    --           ship_to_address_line2,
                                    --           ship_to_city,
                                    --           ship_to_state,
                                    --           ship_to_country,
                                    --           ship_to_address_key,
                                    -- Commented as per CCR0009638
                                    warehouse_name,
                                    ic_unit_price,
                                    quantity,
                                    ic_currency_code,
                                    seller_vat_code,
                                    seller_vat_account_code,
                                    seller_vat_rate,
                                    buyer_vat_code,
                                    buyer_vat_acccount_code,
                                    buyer_vat_rate,
                                    rev_buyer_pay_vat_rate,
                                    rev_buyer_rec_vat_acct_code,
                                    rev_buyer_rec_vat_rate,
                                    -- Start of Change as per CCR0009638
                                    invoice_total,
                                    seller_output_vat_amount,
                                    buyer_input_vat_amount,
                                    buyer_output_vat_amount,
                                    shipment_landed_cost,
                                    --           invoice_total_gbp,
                                    --           seller_output_vat_amount_gbp,
                                    --           buyer_input_vat_amount_gbp,
                                    --           buyer_output_vat_amount_gbp,
                                    --           invoice_total_eur,
                                    --           seller_output_vat_amount_eur,
                                    --           buyer_input_vat_amount_eur,
                                    --           buyer_output_vat_amount_eur,
                                    --           invoice_total_usd,
                                    --           seller_output_vat_amount_usd,
                                    --           buyer_input_vat_amount_usd,
                                    --           buyer_output_vat_amount_usd,
                                    --           shipment_landed_cost_gbp,
                                    --           shipment_landed_cost_eur,
                                    --           shipment_landed_cost_usd,
                                    -- Commented as per CCR0009638
                                    commodity_code,
                                    unit_weight,
                                    style,
                                    color,
                                    product_group,
                                    gender,
                                    ship_to_zip,
                                    seller_revenue_account,
                                    buyer_expense_account,
                                    --attribute2,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    request_id,
                                    -- Added as per CCR0009638
                                    sold_to_org_id,
                                    ship_to_org_id,
                                    invoice_to_org_id,
                                    inventory_item_id-- End as per CCR0009638
                                                     )
                             VALUES (
                                        rec_material (i).vt_source,
                                        TRIM (
                                            rec_material (i).invoice_number),
                                        rec_material (i).vt_transaction_ref,
                                        rec_material (i).oracle_ref,
                                        TRIM (
                                            rec_material (i).sold_by_ou_code),
                                        TRIM (
                                            rec_material (i).sold_to_ou_code),
                                        rec_material (i).vat_seller,
                                        rec_material (i).vat_buyer,
                                        TRIM (
                                            rec_material (i).order_type_user_category),
                                        -- Commented as per CCR0009638
                                        --             trim(rec_material (i).customer_vendor_number),
                                        --             trim(rec_material (i).customer_vendor_name),
                                        -- Commented as per CCR0009638
                                        rec_material (i).invoice_date,
                                        rec_material (i).line_number,
                                        --rec_material (i).inventory_item_id,
                                        --rec_material (i).ordered_item,
                                        rec_material (i).vt_transaction_date,
                                        rec_material (i).vt_transaction_id,
                                        ROUND (rec_material (i).actual_cost,
                                               2),
                                        -- Commented as per CCR0009638
                                        --             trim(rec_material (i).bill_to_address_line1),
                                        --             trim(rec_material (i).bill_to_address_line2),
                                        --             trim(rec_material (i).bill_to_city),
                                        --             trim(rec_material (i).bill_to_state),
                                        --             trim(rec_material (i).bill_to_country),
                                        --             trim(rec_material (i).bill_to_address_key),
                                        --             trim(rec_material (i).ship_to_address_line1),
                                        --             trim(rec_material (i).ship_to_address_line2),
                                        --             trim(rec_material (i).ship_to_city),
                                        --             trim(rec_material (i).ship_to_state),
                                        --             trim(rec_material (i).ship_to_country),
                                        --             trim(rec_material (i).ship_to_address_key),
                                        -- Commented as per CCR0009638
                                        TRIM (
                                            rec_material (i).warehouse_name),
                                        rec_material (i).ic_unit_price,
                                        rec_material (i).quantity,
                                        rec_material (i).ic_currency_code,
                                        TRIM (
                                            rec_material (i).seller_vat_code),
                                        TRIM (
                                            rec_material (i).seller_vat_account_code),
                                        rec_material (i).seller_vat_rate,
                                        TRIM (
                                            rec_material (i).buyer_vat_code),
                                        TRIM (
                                            rec_material (i).buyer_vat_acccount_code),
                                        rec_material (i).buyer_vat_rate,
                                        rec_material (i).rev_buyer_pay_vat_rate,
                                        TRIM (
                                            rec_material (i).rev_buyer_rec_vat_acct_code),
                                        rec_material (i).rev_buyer_rec_vat_rate,
                                        -- Start of Change as per CCR0009638
                                        ROUND (
                                            rec_material (i).invoice_total,
                                            2),
                                        ROUND (
                                            rec_material (i).seller_output_vat_amount,
                                            2),
                                        ROUND (
                                            rec_material (i).buyer_input_vat_amount,
                                            2),
                                        ROUND (
                                            rec_material (i).buyer_output_vat_amount,
                                            2),
                                        ROUND (
                                            rec_material (i).shipment_landed_cost,
                                            2),
                                        --             round(rec_material (i).invoice_total_gbp,2),
                                        --             round(rec_material (i).seller_output_vat_amount_gbp,2),
                                        --             round(rec_material (i).buyer_input_vat_amount_gbp,2),
                                        --             round(rec_material (i).buyer_output_vat_amount_gbp,2),
                                        --             round(rec_material (i).invoice_total_eur,2),
                                        --             round(rec_material (i).seller_output_vat_amount_eur,2),
                                        --             round(rec_material (i).buyer_input_vat_amount_eur,2),
                                        --             round(rec_material (i).buyer_output_vat_amount_eur,2),
                                        --             round(rec_material (i).invoice_total_usd,2),
                                        --             round(rec_material (i).seller_output_vat_amount_usd,2),
                                        --             round(rec_material (i).buyer_input_vat_amount_usd,2),
                                        --             round(rec_material (i).buyer_output_vat_amount_usd,2),
                                        --             round(rec_material (i).shipment_landed_cost,4),
                                        --             round(rec_material (i).shipment_landed_cost,4),
                                        --             round(rec_material (i).shipment_landed_cost,4),
                                        -- Commented as per CCR0009638
                                        TRIM (
                                            rec_material (i).commodity_code),
                                        rec_material (i).unit_weight,
                                        rec_material (i).style,
                                        rec_material (i).color,
                                        TRIM (rec_material (i).product_group),
                                        rec_material (i).gender,
                                        TRIM (rec_material (i).ship_to_zip),
                                        rec_material (i).seller_revenue_account,
                                        rec_material (i).buyer_expense_account,
                                        --rec_material (i).attribute2,
                                        gd_date,
                                        gn_user_id,
                                        gd_date,
                                        gn_user_id,
                                        gn_request_id,
                                        -- Added as per CCR0009638
                                        rec_material (i).sold_to_org_id,
                                        rec_material (i).ship_to_org_id,
                                        rec_material (i).invoice_to_org_id,
                                        rec_material (i).inventory_item_id-- End as per CCR0009638
                                                                          );
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'insertion failed for  Table' || SQLERRM);
            END;

            COMMIT;
            EXIT WHEN c_material%NOTFOUND;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Material Extract - End Time of For Loop :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');

        -- Start of Change as per CCR0009638

        BEGIN
            UPDATE xxdo.xxd_vt_consolidated_ext_t xx
               SET (customer_vendor_number, customer_vendor_name, bill_to_address_line1, bill_to_address_line2, bill_to_city, bill_to_state
                    , bill_to_country, bill_to_address_key)   =
                       (SELECT hca.account_number, remove_junk_fnc (hp_bill.party_name), remove_junk_fnc (hl_bill.address1),
                               remove_junk_fnc (hl_bill.address2), remove_junk_fnc (hl_bill.city), remove_junk_fnc (hl_bill.state),
                               remove_junk_fnc (hl_bill.country), remove_junk_fnc (hl_bill.address_key)
                          FROM apps.hz_cust_accounts_all hca, apps.hz_cust_site_uses_all hcsua_bill, apps.hz_cust_acct_sites_all hcasa_bill,
                               apps.hz_party_sites hps_bill, apps.hz_parties hp_bill, apps.hz_locations hl_bill
                         WHERE     1 = 1
                               AND hcsua_bill.site_use_id =
                                   xx.invoice_to_org_id
                               AND hcasa_bill.cust_acct_site_id =
                                   hcsua_bill.cust_acct_site_id
                               AND hps_bill.party_site_id =
                                   hcasa_bill.party_site_id
                               AND hp_bill.party_id = hps_bill.party_id
                               AND hps_bill.location_id = hl_bill.location_id
                               AND xx.sold_to_org_id = hca.cust_account_id),
                   (ship_to_address_line1, ship_to_address_line2, ship_to_city, ship_to_state, ship_to_country, ship_to_address_key
                    , ship_to_zip)   =
                       (SELECT remove_junk_fnc (hl_ship.address1), remove_junk_fnc (hl_ship.address2), remove_junk_fnc (hl_ship.city),
                               remove_junk_fnc (hl_ship.state), remove_junk_fnc (hl_ship.country), remove_junk_fnc (hl_ship.address_key),
                               remove_junk_fnc (hl_ship.postal_code)
                          FROM apps.hz_cust_acct_sites_all hcasa_ship, apps.hz_cust_site_uses_all hcsua_ship, apps.hz_party_sites hps_ship,
                               apps.hz_parties hp_ship, apps.hz_locations hl_ship
                         WHERE     1 = 1
                               AND hcsua_ship.site_use_id = xx.ship_to_org_id
                               AND hcasa_ship.cust_acct_site_id =
                                   hcsua_ship.cust_acct_site_id
                               AND hps_ship.party_site_id =
                                   hcasa_ship.party_site_id
                               AND hp_ship.party_id = hps_ship.party_id
                               AND hps_ship.location_id = hl_ship.location_id)
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND vt_source = 'Material';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;


        fnd_file.put_line (
            fnd_file.LOG,
               'Material Extract - End Time of Address :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');

        BEGIN
            UPDATE xxdo.xxd_vt_consolidated_ext_t xvc
               SET (unit_weight, style, color,
                    product_group, gender)   =
                       (SELECT msib.unit_weight, mcb.attribute7, mcb.attribute8,
                               mcb.segment3, mcb.segment2
                          FROM mtl_system_items_b msib, mtl_item_categories mic, mtl_categories_b mcb
                         WHERE     msib.inventory_item_id =
                                   mic.inventory_item_id
                               AND msib.organization_id = mic.organization_id
                               AND mic.category_id = mcb.category_id
                               AND mic.category_set_id = 1
                               AND msib.inventory_item_id =
                                   xvc.inventory_item_id
                               AND msib.organization_id = 106)
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND vt_source = 'Material';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
               'Material Extract - End Time of Item :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');

        --    ln_conv_rate_usd := NULL;
        --    ln_conv_rate_eur := NULL;
        --    ln_conv_rate_usd := NULL;

        BEGIN
            UPDATE xxdo.xxd_vt_consolidated_ext_t xvc
               SET invoice_total_eur   =
                         invoice_total
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   seller_output_vat_amount_eur   =
                         seller_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   buyer_output_vat_amount_eur   =
                         buyer_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   buyer_input_vat_amount_eur   =
                         buyer_input_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   shipment_landed_cost_EUR   =
                         shipment_landed_cost
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   invoice_total_GBP   =
                         invoice_total
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   seller_output_vat_amount_GBP   =
                         seller_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   buyer_output_vat_amount_GBP   =
                         buyer_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   buyer_input_vat_amount_GBP   =
                         buyer_input_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   shipment_landed_cost_GBP   =
                         shipment_landed_cost
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   invoice_total_USD   =
                         invoice_total
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   seller_output_vat_amount_USD   =
                         seller_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   buyer_output_vat_amount_USD   =
                         buyer_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   buyer_input_vat_amount_USD   =
                         buyer_input_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1),
                   shipment_landed_cost_USD   =
                         shipment_landed_cost
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.vt_transaction_date)),
                             1)
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND vt_source = 'Material';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        -- End of Change as per CCR0009638


        fnd_file.put_line (
            fnd_file.LOG,
               'Material Extract - End Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');

        --PAYABLES
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
               'Payables Extract - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        OPEN c_payables (lv_gl_date_from, lv_gl_date_to, lv_invoice_date_from
                         , lv_invoice_date_to);

        LOOP
            FETCH c_payables
                BULK COLLECT INTO rec_payables
                LIMIT lv_bulk_limit;

            BEGIN
                FORALL i IN 1 .. rec_payables.COUNT
                    INSERT INTO xxdo.xxd_vt_consolidated_ext_t (
                                    vt_source,
                                    invoice_number,
                                    vt_transaction_ref,
                                    oracle_ref,
                                    sold_by_ou_code,
                                    sold_to_ou_code,
                                    vat_seller,
                                    vat_buyer,
                                    order_type_user_category,
                                    customer_vendor_number,
                                    customer_vendor_name,
                                    invoice_date,
                                    line_number,
                                    --inventory_item_id,
                                    --ordered_item,
                                    vt_transaction_date,
                                    vt_transaction_id,
                                    actual_cost,
                                    bill_to_address_line1,
                                    bill_to_address_line2,
                                    bill_to_city,
                                    bill_to_state,
                                    bill_to_country,
                                    bill_to_address_key,
                                    ship_to_address_line1,
                                    ship_to_address_line2,
                                    ship_to_city,
                                    ship_to_state,
                                    ship_to_country,
                                    ship_to_address_key,
                                    warehouse_name,
                                    ic_unit_price,
                                    quantity,
                                    ic_currency_code,
                                    seller_vat_code,
                                    seller_vat_account_code,
                                    seller_vat_rate,
                                    buyer_vat_code,
                                    buyer_vat_acccount_code,
                                    buyer_vat_rate,
                                    rev_buyer_pay_vat_rate,
                                    rev_buyer_rec_vat_acct_code,
                                    rev_buyer_rec_vat_rate,
                                    invoice_total,
                                    seller_output_vat_amount,
                                    buyer_input_vat_amount,
                                    buyer_output_vat_amount,
                                    -- Start of Change as per CCR0009638
                                    --           invoice_total_gbp,
                                    --           seller_output_vat_amount_gbp,
                                    --           buyer_input_vat_amount_gbp,
                                    --           buyer_output_vat_amount_gbp,
                                    --           invoice_total_eur,
                                    --           seller_output_vat_amount_eur,
                                    --           buyer_input_vat_amount_eur,
                                    --           buyer_output_vat_amount_eur,
                                    --           invoice_total_usd,
                                    --           seller_output_vat_amount_usd,
                                    --           buyer_input_vat_amount_usd,
                                    --           buyer_output_vat_amount_usd,
                                    -- End of Change as per CCR0009638
                                    shipment_landed_cost_gbp,
                                    shipment_landed_cost_eur,
                                    shipment_landed_cost_usd,
                                    commodity_code,
                                    unit_weight,
                                    style,
                                    color,
                                    product_group,
                                    gender,
                                    ship_to_zip,
                                    seller_revenue_account,
                                    buyer_expense_account,
                                    --attribute2,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    request_id,
                                    accounting_date -- Added as per CCR0009638
                                                   )
                             VALUES (
                                        rec_payables (i).vt_source,
                                        TRIM (
                                            rec_payables (i).invoice_number),
                                        rec_payables (i).vt_transaction_ref,
                                        rec_payables (i).oracle_ref,
                                        TRIM (
                                            rec_payables (i).sold_by_ou_code),
                                        TRIM (
                                            rec_payables (i).sold_to_ou_code),
                                        rec_payables (i).vat_seller,
                                        rec_payables (i).vat_buyer,
                                        TRIM (
                                            rec_payables (i).order_type_user_category),
                                        TRIM (
                                            rec_payables (i).customer_vendor_number),
                                        TRIM (
                                            rec_payables (i).customer_vendor_name),
                                        rec_payables (i).invoice_date,
                                        rec_payables (i).line_number,
                                        --rec_payables (i).inventory_item_id,
                                        --rec_payables (i).ordered_item,
                                        rec_payables (i).vt_transaction_date,
                                        rec_payables (i).vt_transaction_id,
                                        ROUND (rec_payables (i).actual_cost,
                                               2),
                                        TRIM (
                                            rec_payables (i).bill_to_address_line1),
                                        TRIM (
                                            rec_payables (i).bill_to_address_line2),
                                        TRIM (rec_payables (i).bill_to_city),
                                        TRIM (rec_payables (i).bill_to_state),
                                        TRIM (
                                            rec_payables (i).bill_to_country),
                                        TRIM (
                                            rec_payables (i).bill_to_address_key),
                                        TRIM (
                                            rec_payables (i).ship_to_address_line1),
                                        TRIM (
                                            rec_payables (i).ship_to_address_line2),
                                        TRIM (rec_payables (i).ship_to_city),
                                        TRIM (rec_payables (i).ship_to_state),
                                        TRIM (
                                            rec_payables (i).ship_to_country),
                                        TRIM (
                                            rec_payables (i).ship_to_address_key),
                                        TRIM (
                                            rec_payables (i).warehouse_name),
                                        rec_payables (i).ic_unit_price,
                                        rec_payables (i).quantity,
                                        rec_payables (i).ic_currency_code,
                                        TRIM (
                                            rec_payables (i).seller_vat_code),
                                        TRIM (
                                            rec_payables (i).seller_vat_account_code),
                                        rec_payables (i).seller_vat_rate,
                                        TRIM (
                                            rec_payables (i).buyer_vat_code),
                                        TRIM (
                                            rec_payables (i).buyer_vat_acccount_code),
                                        rec_payables (i).buyer_vat_rate,
                                        rec_payables (i).rev_buyer_pay_vat_rate,
                                        TRIM (
                                            rec_payables (i).rev_buyer_rec_vat_acct_code),
                                        rec_payables (i).rev_buyer_rec_vat_rate,
                                        ROUND (
                                            rec_payables (i).invoice_total,
                                            4),
                                        ROUND (
                                            rec_payables (i).seller_output_vat_amount,
                                            4),
                                        ROUND (
                                            rec_payables (i).buyer_input_vat_amount,
                                            4),
                                        ROUND (
                                            rec_payables (i).buyer_output_vat_amount,
                                            4),
                                        -- Start of Change as per CCR0009638
                                        --             round(rec_payables (i).invoice_total_gbp,2),
                                        --             round(rec_payables (i).seller_output_vat_amount_gbp,2),
                                        --             round(rec_payables (i).buyer_input_vat_amount_gbp,2),
                                        --             round(rec_payables (i).buyer_output_vat_amount_gbp,2),
                                        --             round(rec_payables (i).invoice_total_eur,2),
                                        --             round(rec_payables (i).seller_output_vat_amount_eur,2),
                                        --             round(rec_payables (i).buyer_input_vat_amount_eur,2),
                                        --             round(rec_payables (i).buyer_output_vat_amount_eur,2),
                                        --             round(rec_payables (i).invoice_total_usd,2),
                                        --             round(rec_payables (i).seller_output_vat_amount_usd,2),
                                        --             round(rec_payables (i).buyer_input_vat_amount_usd,2),
                                        --             round(rec_payables (i).buyer_output_vat_amount_usd,2),
                                        -- End of Change as per CCR0009638
                                        ROUND (
                                            rec_payables (i).shipment_landed_cost_gbp,
                                            2),
                                        ROUND (
                                            rec_payables (i).shipment_landed_cost_eur,
                                            2),
                                        ROUND (
                                            rec_payables (i).shipment_landed_cost_usd,
                                            2),
                                        TRIM (
                                            rec_payables (i).commodity_code),
                                        rec_payables (i).unit_weight,
                                        rec_payables (i).style,
                                        rec_payables (i).color,
                                        TRIM (rec_payables (i).product_group),
                                        rec_payables (i).gender,
                                        TRIM (rec_payables (i).ship_to_zip),
                                        rec_payables (i).seller_revenue_account,
                                        rec_payables (i).buyer_expense_account,
                                        --rec_payables (i).attribute2,
                                        gd_date,
                                        gn_user_id,
                                        gd_date,
                                        gn_user_id,
                                        gn_request_id,
                                        rec_payables (i).accounting_date -- Added as per CCR0009638
                                                                        );
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'insertion failed for  Table' || SQLERRM);
            END;

            COMMIT;
            EXIT WHEN c_payables%NOTFOUND;
        END LOOP;

        -- Start of Change as per CCR0009638

        BEGIN
            UPDATE xxdo.xxd_vt_consolidated_ext_t xvc
               SET invoice_total_eur   =
                         invoice_total
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   seller_output_vat_amount_eur   =
                         seller_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_output_vat_amount_eur   =
                         buyer_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_input_vat_amount_eur   =
                         buyer_input_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   shipment_landed_cost_EUR   =
                         shipment_landed_cost
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   invoice_total_GBP   =
                         invoice_total
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   seller_output_vat_amount_GBP   =
                         seller_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_output_vat_amount_GBP   =
                         buyer_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_input_vat_amount_GBP   =
                         buyer_input_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   shipment_landed_cost_GBP   =
                         shipment_landed_cost
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   invoice_total_USD   =
                         invoice_total
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   seller_output_vat_amount_USD   =
                         seller_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_output_vat_amount_USD   =
                         buyer_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_input_vat_amount_USD   =
                         buyer_input_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   shipment_landed_cost_USD   =
                         shipment_landed_cost
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1)
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND vt_source = 'Payables';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        -- End of Change as per CCR0009638


        fnd_file.put_line (
            fnd_file.LOG,
               'Payables Extract - End Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');

        --MANUAL
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
               'Manual Extract - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        OPEN c_manual (lv_gl_date_from, lv_gl_date_to, lv_invoice_date_from,
                       lv_invoice_date_to);

        LOOP
            FETCH c_manual BULK COLLECT INTO rec_manual LIMIT lv_bulk_limit;

            BEGIN
                FORALL i IN 1 .. rec_manual.COUNT
                    INSERT INTO xxdo.xxd_vt_consolidated_ext_t (
                                    vt_source,
                                    invoice_number,
                                    vt_transaction_ref,
                                    oracle_ref,
                                    sold_by_ou_code,
                                    sold_to_ou_code,
                                    vat_seller,
                                    vat_buyer,
                                    order_type_user_category,
                                    customer_vendor_number,
                                    customer_vendor_name,
                                    invoice_date,
                                    line_number,
                                    --inventory_item_id,
                                    --ordered_item,
                                    vt_transaction_date,
                                    vt_transaction_id,
                                    actual_cost,
                                    bill_to_address_line1,
                                    bill_to_address_line2,
                                    bill_to_city,
                                    bill_to_state,
                                    bill_to_country,
                                    bill_to_address_key,
                                    ship_to_address_line1,
                                    ship_to_address_line2,
                                    ship_to_city,
                                    ship_to_state,
                                    ship_to_country,
                                    ship_to_address_key,
                                    warehouse_name,
                                    ic_unit_price,
                                    quantity,
                                    ic_currency_code,
                                    seller_vat_code,
                                    seller_vat_account_code,
                                    seller_vat_rate,
                                    buyer_vat_code,
                                    buyer_vat_acccount_code,
                                    buyer_vat_rate,
                                    rev_buyer_pay_vat_rate,
                                    rev_buyer_rec_vat_acct_code,
                                    rev_buyer_rec_vat_rate,
                                    invoice_total,
                                    seller_output_vat_amount,
                                    buyer_input_vat_amount,
                                    buyer_output_vat_amount,
                                    -- Start of Change as per CCR0009638
                                    --           invoice_total_gbp,
                                    --           seller_output_vat_amount_gbp,
                                    --           buyer_input_vat_amount_gbp,
                                    --           buyer_output_vat_amount_gbp,
                                    --           invoice_total_eur,
                                    --           seller_output_vat_amount_eur,
                                    --           buyer_input_vat_amount_eur,
                                    --           buyer_output_vat_amount_eur,
                                    --           invoice_total_usd,
                                    --           seller_output_vat_amount_usd,
                                    --           buyer_input_vat_amount_usd,
                                    --           buyer_output_vat_amount_usd,
                                    -- End of Change as per CCR0009638
                                    shipment_landed_cost_gbp,
                                    shipment_landed_cost_eur,
                                    shipment_landed_cost_usd,
                                    commodity_code,
                                    unit_weight,
                                    style,
                                    color,
                                    product_group,
                                    gender,
                                    ship_to_zip,
                                    seller_revenue_account,
                                    buyer_expense_account,
                                    --attribute2,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by,
                                    request_id,
                                    accounting_date -- Added as per CCR0009638
                                                   )
                             VALUES (
                                        rec_manual (i).vt_source,
                                        TRIM (rec_manual (i).invoice_number),
                                        rec_manual (i).vt_transaction_ref,
                                        rec_manual (i).oracle_ref,
                                        TRIM (rec_manual (i).sold_by_ou_code),
                                        TRIM (rec_manual (i).sold_to_ou_code),
                                        rec_manual (i).vat_seller,
                                        rec_manual (i).vat_buyer,
                                        TRIM (
                                            rec_manual (i).order_type_user_category),
                                        TRIM (
                                            rec_manual (i).customer_vendor_number),
                                        TRIM (
                                            rec_manual (i).customer_vendor_name),
                                        rec_manual (i).invoice_date,
                                        rec_manual (i).line_number,
                                        --rec_manual (i).inventory_item_id,
                                        --rec_manual (i).ordered_item,
                                        rec_manual (i).vt_transaction_date,
                                        rec_manual (i).vt_transaction_id,
                                        ROUND (rec_manual (i).actual_cost, 2),
                                        TRIM (
                                            rec_manual (i).bill_to_address_line1),
                                        TRIM (
                                            rec_manual (i).bill_to_address_line2),
                                        TRIM (rec_manual (i).bill_to_city),
                                        TRIM (rec_manual (i).bill_to_state),
                                        TRIM (rec_manual (i).bill_to_country),
                                        TRIM (
                                            rec_manual (i).bill_to_address_key),
                                        TRIM (
                                            rec_manual (i).ship_to_address_line1),
                                        TRIM (
                                            rec_manual (i).ship_to_address_line2),
                                        TRIM (rec_manual (i).ship_to_city),
                                        TRIM (rec_manual (i).ship_to_state),
                                        TRIM (rec_manual (i).ship_to_country),
                                        TRIM (
                                            rec_manual (i).ship_to_address_key),
                                        TRIM (rec_manual (i).warehouse_name),
                                        rec_manual (i).ic_unit_price,
                                        rec_manual (i).quantity,
                                        rec_manual (i).ic_currency_code,
                                        TRIM (rec_manual (i).seller_vat_code),
                                        TRIM (
                                            rec_manual (i).seller_vat_account_code),
                                        rec_manual (i).seller_vat_rate,
                                        TRIM (rec_manual (i).buyer_vat_code),
                                        TRIM (
                                            rec_manual (i).buyer_vat_acccount_code),
                                        rec_manual (i).buyer_vat_rate,
                                        rec_manual (i).rev_buyer_pay_vat_rate,
                                        TRIM (
                                            rec_manual (i).rev_buyer_rec_vat_acct_code),
                                        rec_manual (i).rev_buyer_rec_vat_rate,
                                        ROUND (rec_manual (i).invoice_total,
                                               2),
                                        ROUND (
                                            rec_manual (i).seller_output_vat_amount,
                                            2),
                                        ROUND (
                                            rec_manual (i).buyer_input_vat_amount,
                                            2),
                                        ROUND (
                                            rec_manual (i).buyer_output_vat_amount,
                                            2),
                                        -- Start of Change as per CCR0009638
                                        --             round(rec_manual (i).invoice_total_gbp,2),
                                        --             round(rec_manual (i).seller_output_vat_amount_gbp,2),
                                        --             round(rec_manual (i).buyer_input_vat_amount_gbp,2),
                                        --             round(rec_manual (i).buyer_output_vat_amount_gbp,2),
                                        --             round(rec_manual (i).invoice_total_eur,2),
                                        --             round(rec_manual (i).seller_output_vat_amount_eur,2),
                                        --             round(rec_manual (i).buyer_input_vat_amount_eur,2),
                                        --             round(rec_manual (i).buyer_output_vat_amount_eur,2),
                                        --             round(rec_manual (i).invoice_total_usd,2),
                                        --             round(rec_manual (i).seller_output_vat_amount_usd,2),
                                        --             round(rec_manual (i).buyer_input_vat_amount_usd,2),
                                        --             round(rec_manual (i).buyer_output_vat_amount_usd,2),
                                        -- End of Change as per CCR0009638
                                        ROUND (
                                            rec_manual (i).shipment_landed_cost_gbp,
                                            2),
                                        ROUND (
                                            rec_manual (i).shipment_landed_cost_eur,
                                            2),
                                        ROUND (
                                            rec_manual (i).shipment_landed_cost_usd,
                                            2),
                                        TRIM (rec_manual (i).commodity_code),
                                        rec_manual (i).unit_weight,
                                        rec_manual (i).style,
                                        rec_manual (i).color,
                                        TRIM (rec_manual (i).product_group),
                                        rec_manual (i).gender,
                                        TRIM (rec_manual (i).ship_to_zip),
                                        rec_manual (i).seller_revenue_account,
                                        rec_manual (i).buyer_expense_account,
                                        --rec_manual (i).attribute2,
                                        gd_date,
                                        gn_user_id,
                                        gd_date,
                                        gn_user_id,
                                        gn_request_id,
                                        rec_manual (i).accounting_date -- Added as per CCR0009638
                                                                      );
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'insertion failed for  Table' || SQLERRM);
            END;

            COMMIT;
            EXIT WHEN c_manual%NOTFOUND;
        END LOOP;

        -- Start of Change as per CCR0009638

        BEGIN
            UPDATE xxdo.xxd_vt_consolidated_ext_t xvc
               SET invoice_total_eur   =
                         invoice_total
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   seller_output_vat_amount_eur   =
                         seller_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_output_vat_amount_eur   =
                         buyer_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_input_vat_amount_eur   =
                         buyer_input_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   shipment_landed_cost_EUR   =
                         shipment_landed_cost
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'EUR'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   invoice_total_GBP   =
                         invoice_total
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   seller_output_vat_amount_GBP   =
                         seller_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_output_vat_amount_GBP   =
                         buyer_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_input_vat_amount_GBP   =
                         buyer_input_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   shipment_landed_cost_GBP   =
                         shipment_landed_cost
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'GBP'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   invoice_total_USD   =
                         invoice_total
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   seller_output_vat_amount_USD   =
                         seller_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_output_vat_amount_USD   =
                         buyer_output_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   buyer_input_vat_amount_USD   =
                         buyer_input_vat_amount
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1),
                   shipment_landed_cost_USD   =
                         shipment_landed_cost
                       * NVL (
                             (SELECT conversion_rate
                                FROM apps.gl_daily_rates
                               WHERE     conversion_type = 'Corporate'
                                     AND from_currency = xvc.ic_currency_code
                                     AND to_currency = 'USD'
                                     AND conversion_date =
                                         TRUNC (xvc.accounting_date)),
                             1)
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND vt_source = 'Manual';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        COMMIT;

        -- End of Change as per CCR0009638

        fnd_file.put_line (
            fnd_file.LOG,
               'Manual Extract - End Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');

        --PROJECT
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
               'Project Extract - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        OPEN c_projects (lv_gl_date_from, lv_gl_date_to, lv_invoice_date_from
                         , lv_invoice_date_to);

        LOOP
            FETCH c_projects
                BULK COLLECT INTO rec_projects
                LIMIT lv_bulk_limit;

            BEGIN
                FORALL i IN 1 .. rec_projects.COUNT
                    INSERT INTO xxdo.xxd_vt_consolidated_ext_t (vt_source, invoice_number, vt_transaction_ref, oracle_ref, sold_by_ou_code, sold_to_ou_code, vat_seller, vat_buyer, order_type_user_category, customer_vendor_number, customer_vendor_name, invoice_date, line_number, --inventory_item_id,
                                                                                                                                                                                                                                                                                       --ordered_item,
                                                                                                                                                                                                                                                                                       vt_transaction_date, vt_transaction_id, actual_cost, bill_to_address_line1, bill_to_address_line2, bill_to_city, bill_to_state, bill_to_country, bill_to_address_key, ship_to_address_line1, ship_to_address_line2, ship_to_city, ship_to_state, ship_to_country, ship_to_address_key, warehouse_name, ic_unit_price, quantity, ic_currency_code, seller_vat_code, seller_vat_account_code, seller_vat_rate, buyer_vat_code, buyer_vat_acccount_code, buyer_vat_rate, rev_buyer_pay_vat_rate, rev_buyer_rec_vat_acct_code, rev_buyer_rec_vat_rate, invoice_total_gbp, seller_output_vat_amount_gbp, buyer_input_vat_amount_gbp, buyer_output_vat_amount_gbp, invoice_total_eur, seller_output_vat_amount_eur, buyer_input_vat_amount_eur, buyer_output_vat_amount_eur, invoice_total_usd, seller_output_vat_amount_usd, buyer_input_vat_amount_usd, buyer_output_vat_amount_usd, shipment_landed_cost_gbp, shipment_landed_cost_eur, shipment_landed_cost_usd, commodity_code, unit_weight, style, color, product_group, gender, ship_to_zip, seller_revenue_account, buyer_expense_account, --attribute2,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    creation_date, created_by, last_update_date, last_updated_by
                                                                , request_id)
                         VALUES (rec_projects (i).vt_source, TRIM (rec_projects (i).invoice_number), rec_projects (i).vt_transaction_ref, rec_projects (i).oracle_ref, TRIM (rec_projects (i).sold_by_ou_code), TRIM (rec_projects (i).sold_to_ou_code), rec_projects (i).vat_seller, rec_projects (i).vat_buyer, TRIM (rec_projects (i).order_type_user_category), TRIM (rec_projects (i).customer_vendor_number), TRIM (rec_projects (i).customer_vendor_name), rec_projects (i).invoice_date, rec_projects (i).line_number, --rec_projects (i).inventory_item_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               --rec_projects (i).ordered_item,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               rec_projects (i).vt_transaction_date, rec_projects (i).vt_transaction_id, ROUND (rec_projects (i).actual_cost, 2), TRIM (rec_projects (i).bill_to_address_line1), TRIM (rec_projects (i).bill_to_address_line2), TRIM (rec_projects (i).bill_to_city), TRIM (rec_projects (i).bill_to_state), TRIM (rec_projects (i).bill_to_country), TRIM (rec_projects (i).bill_to_address_key), TRIM (rec_projects (i).ship_to_address_line1), TRIM (rec_projects (i).ship_to_address_line2), TRIM (rec_projects (i).ship_to_city), TRIM (rec_projects (i).ship_to_state), TRIM (rec_projects (i).ship_to_country), TRIM (rec_projects (i).ship_to_address_key), TRIM (rec_projects (i).warehouse_name), rec_projects (i).ic_unit_price, rec_projects (i).quantity, rec_projects (i).ic_currency_code, TRIM (rec_projects (i).seller_vat_code), TRIM (rec_projects (i).seller_vat_account_code), rec_projects (i).seller_vat_rate, TRIM (rec_projects (i).buyer_vat_code), TRIM (rec_projects (i).buyer_vat_acccount_code), rec_projects (i).buyer_vat_rate, rec_projects (i).rev_buyer_pay_vat_rate, TRIM (rec_projects (i).rev_buyer_rec_vat_acct_code), rec_projects (i).rev_buyer_rec_vat_rate, ROUND (rec_projects (i).invoice_total_gbp, 2), ROUND (rec_projects (i).seller_output_vat_amount_gbp, 2), ROUND (rec_projects (i).buyer_input_vat_amount_gbp, 2), ROUND (rec_projects (i).buyer_output_vat_amount_gbp, 2), ROUND (rec_projects (i).invoice_total_eur, 2), ROUND (rec_projects (i).seller_output_vat_amount_eur, 2), ROUND (rec_projects (i).buyer_input_vat_amount_eur, 2), ROUND (rec_projects (i).buyer_output_vat_amount_eur, 2), ROUND (rec_projects (i).invoice_total_usd, 2), ROUND (rec_projects (i).seller_output_vat_amount_usd, 2), ROUND (rec_projects (i).buyer_input_vat_amount_usd, 2), ROUND (rec_projects (i).buyer_output_vat_amount_usd, 2), ROUND (rec_projects (i).shipment_landed_cost_gbp, 2), ROUND (rec_projects (i).shipment_landed_cost_eur, 2), ROUND (rec_projects (i).shipment_landed_cost_usd, 2), TRIM (rec_projects (i).commodity_code), rec_projects (i).unit_weight, rec_projects (i).style, rec_projects (i).color, TRIM (rec_projects (i).product_group), rec_projects (i).gender, TRIM (rec_projects (i).ship_to_zip), rec_projects (i).seller_revenue_account, rec_projects (i).buyer_expense_account, --rec_projects (i).attribute2,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   gd_date, gn_user_id, gd_date, gn_user_id
                                 , gn_request_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'insertion failed for  Table' || SQLERRM);
            END;

            COMMIT;
            EXIT WHEN c_projects%NOTFOUND;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Project Extract - End Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');

        --ASSETS
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
               'Assets Extract - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        OPEN c_assets (lv_gl_date_from, lv_gl_date_to, lv_invoice_date_from,
                       lv_invoice_date_to);

        LOOP
            FETCH c_assets BULK COLLECT INTO rec_assets LIMIT lv_bulk_limit;

            BEGIN
                FORALL i IN 1 .. rec_assets.COUNT
                    INSERT INTO xxdo.xxd_vt_consolidated_ext_t (vt_source, invoice_number, vt_transaction_ref, oracle_ref, sold_by_ou_code, sold_to_ou_code, vat_seller, vat_buyer, order_type_user_category, customer_vendor_number, customer_vendor_name, invoice_date, line_number, --inventory_item_id,
                                                                                                                                                                                                                                                                                       --ordered_item,
                                                                                                                                                                                                                                                                                       vt_transaction_date, vt_transaction_id, actual_cost, bill_to_address_line1, bill_to_address_line2, bill_to_city, bill_to_state, bill_to_country, bill_to_address_key, ship_to_address_line1, ship_to_address_line2, ship_to_city, ship_to_state, ship_to_country, ship_to_address_key, warehouse_name, ic_unit_price, quantity, ic_currency_code, seller_vat_code, seller_vat_account_code, seller_vat_rate, buyer_vat_code, buyer_vat_acccount_code, buyer_vat_rate, rev_buyer_pay_vat_rate, rev_buyer_rec_vat_acct_code, rev_buyer_rec_vat_rate, invoice_total_gbp, seller_output_vat_amount_gbp, buyer_input_vat_amount_gbp, buyer_output_vat_amount_gbp, invoice_total_eur, seller_output_vat_amount_eur, buyer_input_vat_amount_eur, buyer_output_vat_amount_eur, invoice_total_usd, seller_output_vat_amount_usd, buyer_input_vat_amount_usd, buyer_output_vat_amount_usd, shipment_landed_cost_gbp, shipment_landed_cost_eur, shipment_landed_cost_usd, commodity_code, unit_weight, style, color, product_group, gender, ship_to_zip, seller_revenue_account, buyer_expense_account, --attribute2,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    creation_date, created_by, last_update_date, last_updated_by
                                                                , request_id)
                         VALUES (rec_assets (i).vt_source, TRIM (rec_assets (i).invoice_number), rec_assets (i).vt_transaction_ref, rec_assets (i).oracle_ref, TRIM (rec_assets (i).sold_by_ou_code), TRIM (rec_assets (i).sold_to_ou_code), rec_assets (i).vat_seller, rec_assets (i).vat_buyer, TRIM (rec_assets (i).order_type_user_category), TRIM (rec_assets (i).customer_vendor_number), TRIM (rec_assets (i).customer_vendor_name), rec_assets (i).invoice_date, rec_assets (i).line_number, --rec_assets (i).inventory_item_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     --rec_assets (i).ordered_item,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     rec_assets (i).vt_transaction_date, rec_assets (i).vt_transaction_id, ROUND (rec_assets (i).actual_cost, 2), TRIM (rec_assets (i).bill_to_address_line1), TRIM (rec_assets (i).bill_to_address_line2), TRIM (rec_assets (i).bill_to_city), TRIM (rec_assets (i).bill_to_state), TRIM (rec_assets (i).bill_to_country), TRIM (rec_assets (i).bill_to_address_key), TRIM (rec_assets (i).ship_to_address_line1), TRIM (rec_assets (i).ship_to_address_line2), TRIM (rec_assets (i).ship_to_city), TRIM (rec_assets (i).ship_to_state), TRIM (rec_assets (i).ship_to_country), TRIM (rec_assets (i).ship_to_address_key), TRIM (rec_assets (i).warehouse_name), rec_assets (i).ic_unit_price, rec_assets (i).quantity, rec_assets (i).ic_currency_code, TRIM (rec_assets (i).seller_vat_code), TRIM (rec_assets (i).seller_vat_account_code), rec_assets (i).seller_vat_rate, TRIM (rec_assets (i).buyer_vat_code), TRIM (rec_assets (i).buyer_vat_acccount_code), rec_assets (i).buyer_vat_rate, rec_assets (i).rev_buyer_pay_vat_rate, TRIM (rec_assets (i).rev_buyer_rec_vat_acct_code), rec_assets (i).rev_buyer_rec_vat_rate, ROUND (rec_assets (i).invoice_total_gbp, 2), ROUND (rec_assets (i).seller_output_vat_amount_gbp, 2), ROUND (rec_assets (i).buyer_input_vat_amount_gbp, 2), ROUND (rec_assets (i).buyer_output_vat_amount_gbp, 2), ROUND (rec_assets (i).invoice_total_eur, 2), ROUND (rec_assets (i).seller_output_vat_amount_eur, 2), ROUND (rec_assets (i).buyer_input_vat_amount_eur, 2), ROUND (rec_assets (i).buyer_output_vat_amount_eur, 2), ROUND (rec_assets (i).invoice_total_usd, 2), ROUND (rec_assets (i).seller_output_vat_amount_usd, 2), ROUND (rec_assets (i).buyer_input_vat_amount_usd, 2), ROUND (rec_assets (i).buyer_output_vat_amount_usd, 2), ROUND (rec_assets (i).shipment_landed_cost_gbp, 2), ROUND (rec_assets (i).shipment_landed_cost_eur, 2), ROUND (rec_assets (i).shipment_landed_cost_usd, 2), TRIM (rec_assets (i).commodity_code), rec_assets (i).unit_weight, rec_assets (i).style, rec_assets (i).color, TRIM (rec_assets (i).product_group), rec_assets (i).gender, TRIM (rec_assets (i).ship_to_zip), rec_assets (i).seller_revenue_account, rec_assets (i).buyer_expense_account, --rec_assets (i).attribute2,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 gd_date, gn_user_id, gd_date, gn_user_id
                                 , gn_request_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'insertion failed for  Table' || SQLERRM);
            END;

            COMMIT;
            EXIT WHEN c_assets%NOTFOUND;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Assets Extract - End Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');

        ---------------------
        --WRITE OUT FILE
        ---------------------
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');
        fnd_file.put_line (
            fnd_file.LOG,
               'Write Outfile - Start Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));

        --HEADING
        lv_delimiter      := '~';
        lv_heading        :=
               'VT_SOURCE'
            || lv_delimiter
            || 'INVOICE_NUMBER'
            || lv_delimiter
            || 'VT_TRANSACTION_REF'
            || lv_delimiter
            || 'ORACLE_REF'
            /*||
            lv_delimiter
            ||
            'SOLD_BY_OU'*/
            || lv_delimiter
            || 'SOLD_BY_OU_CODE'
            || /*lv_delimiter
               ||
               'SOLD_TO_OU'
               || */
               lv_delimiter
            || 'SOLD_TO_OU_CODE'
            || lv_delimiter
            || 'VAT_SELLER'
            || lv_delimiter
            || 'VAT_BUYER'
            || lv_delimiter
            || 'ORDER_TYPE_USER_CATEGORY'
            || lv_delimiter
            || 'CUSTOMER_VENDOR_NUMBER'
            || lv_delimiter
            || 'CUSTOMER_VENDOR_NAME'
            || lv_delimiter
            || 'INVOICE_DATE'
            || lv_delimiter
            || 'LINE_NUMBER'
            || lv_delimiter
            /*||
            'INVENTORY_ITEM_ID'
            ||
            lv_delimiter
            ||
            'ORDERED_ITEM'
            ||
            lv_delimiter*/
            || 'VT_TRANSACTION_DATE'
            || lv_delimiter
            || 'VT_TRANSACTION_ID'
            || lv_delimiter
            || 'ACTUAL_COST'
            || lv_delimiter
            || 'BILL_TO_ADDRESS_LINE1'
            || lv_delimiter
            || 'BILL_TO_ADDRESS_LINE2'
            || lv_delimiter
            || 'BILL_TO_CITY'
            || lv_delimiter
            || 'BILL_TO_STATE'
            || lv_delimiter
            || 'BILL_TO_COUNTRY'
            || lv_delimiter
            || 'BILL_TO_ADDRESS_KEY'
            || lv_delimiter
            || 'SHIP_TO_ADDRESS_LINE1'
            || lv_delimiter
            || 'SHIP_TO_ADDRESS_LINE2'
            || lv_delimiter
            || 'SHIP_TO_CITY'
            || lv_delimiter
            || 'SHIP_TO_STATE'
            || lv_delimiter
            || 'SHIP_TO_COUNTRY'
            || lv_delimiter
            || 'SHIP_TO_ADDRESS_KEY'
            || lv_delimiter
            || 'WAREHOUSE_NAME'
            || lv_delimiter
            || 'IC_UNIT_PRICE'
            || lv_delimiter
            || 'QUANTITY'
            || lv_delimiter
            || 'IC_CURRENCY_CODE'
            || --1.2
               lv_delimiter
            || 'SELLER_TAX_COUNTRY'
            || --1.2
               lv_delimiter
            || 'SELLER_VAT_CODE'
            || lv_delimiter
            || 'SELLER_VAT_ACCOUNT_CODE'
            || lv_delimiter
            || 'SELLER_VAT_RATE'
            || lv_delimiter
            --1.2
            || 'BUYER_TAX_COUNTRY'
            || lv_delimiter
            --1.2
            || 'BUYER_VAT_CODE'
            || lv_delimiter
            || 'BUYER_VAT_ACCCOUNT_CODE'
            || lv_delimiter
            || 'BUYER_VAT_RATE'
            || lv_delimiter
            || -- REV_BUYER_PAY_VAT_RATE  is same as rev_buyer_rec_vat_rate
               --Start Uncommented for CCR0009638
               'REV_BUYER_PAY_VAT_RATE'
            || lv_delimiter
            || --End Uncommented for CCR0009638
               'REV_BUYER_REC_VAT_ACCT_CODE'
            || lv_delimiter
            || 'REV_BUYER_REC_VAT_RATE'
            || lv_delimiter
            || 'INVOICE_TOTAL_GBP'
            || lv_delimiter
            || 'SELLER_OUTPUT_VAT_AMOUNT_GBP'
            || lv_delimiter
            || 'BUYER_INPUT_VAT_AMOUNT_GBP'
            || lv_delimiter
            || 'BUYER_OUTPUT_VAT_AMOUNT_GBP'
            || lv_delimiter
            || 'INVOICE_TOTAL_EUR'
            || lv_delimiter
            || 'SELLER_OUTPUT_VAT_AMOUNT_EUR'
            || lv_delimiter
            || 'BUYER_INPUT_VAT_AMOUNT_EUR'
            || lv_delimiter
            || 'BUYER_OUTPUT_VAT_AMOUNT_EUR'
            || lv_delimiter
            || 'INVOICE_TOTAL_USD'
            || lv_delimiter
            || 'SELLER_OUTPUT_VAT_AMOUNT_USD'
            || lv_delimiter
            || 'BUYER_INPUT_VAT_AMOUNT_USD'
            || lv_delimiter
            || 'BUYER_OUTPUT_VAT_AMOUNT_USD'
            || lv_delimiter
            || 'SHIPMENT_LANDED_COST_GBP'
            || lv_delimiter
            || 'SHIPMENT_LANDED_COST_EUR'
            || lv_delimiter
            || 'SHIPMENT_LANDED_COST_USD'
            || lv_delimiter
            || 'COMMODITY_CODE'
            || lv_delimiter
            || 'UNIT_WEIGHT'
            || lv_delimiter
            || 'STYLE'
            || lv_delimiter
            || 'COLOR'
            || lv_delimiter
            || 'PRODUCT_GROUP'
            || lv_delimiter
            || 'GENDER'
            || lv_delimiter
            || 'SHIP_TO_ZIP'
            || lv_delimiter
            || 'SELLER_REVENUE_ACCOUNT'
            || lv_delimiter
            || 'BUYER_EXPENSE_ACCOUNT'/*||
                                      lv_delimiter
                                      ||
                                      'ATTRIBUTE2'*/
                                      ;

        --PRINT OUTFILE

        IF pv_final_mode = 'N'
        THEN
            fnd_file.put_line (apps.fnd_file.OUTPUT, lv_heading);

            ln_cnt   := 0;

            FOR r_out IN c_out
            LOOP
                apps.fnd_file.put_line (apps.fnd_file.output, r_out.rep_data);
                ln_cnt   := ln_cnt + 1;
            END LOOP;
        END IF;

        IF pv_final_mode = 'Y'
        THEN
            BEGIN
                lv_output_file   :=
                    UTL_FILE.fopen (pv_directory_name, lv_outbound_file, 'W', --opening the file in write mode
                                    32000);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    UTL_FILE.put_line (lv_output_file, lv_heading);

                    FOR r_out IN c_out
                    LOOP
                        ln_cnt    := 0;
                        lv_line   := r_out.rep_data;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                        ln_cnt    := ln_cnt + 1;
                    END LOOP;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                        SUBSTR (
                               'Error in Opening the VAT Consolidated Report file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000));
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

        --fnd_file.put_line (apps.fnd_file.OUTPUT, lv_heading);



        BEGIN
            SELECT COUNT (1)
              INTO ln_mat_cnt
              FROM xxdo.xxd_vt_consolidated_ext_t
             WHERE vt_source = 'Material' AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_mat_cnt   := -1;
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_pay_cnt
              FROM xxdo.xxd_vt_consolidated_ext_t
             WHERE vt_source = 'Payables' AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_pay_cnt   := -1;
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_manual_cnt
              FROM xxdo.xxd_vt_consolidated_ext_t
             WHERE vt_source = 'Manual' AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_manual_cnt   := -1;
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_proj_cnt
              FROM xxdo.xxd_vt_consolidated_ext_t
             WHERE vt_source = 'Projects' AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_proj_cnt   := -1;
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_asset_cnt
              FROM xxdo.xxd_vt_consolidated_ext_t
             WHERE vt_source = 'Assets' AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_asset_cnt   := -1;
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'Material Extract Count : ' || ln_mat_cnt);
        fnd_file.put_line (fnd_file.LOG,
                           'Payables Extract  Count : ' || ln_pay_cnt);
        fnd_file.put_line (fnd_file.LOG,
                           'Manual Extract Count : ' || ln_manual_cnt);
        fnd_file.put_line (fnd_file.LOG,
                           'Project Extract Count : ' || ln_proj_cnt);
        fnd_file.put_line (fnd_file.LOG,
                           'Assets Extract Count : ' || ln_asset_cnt);

        fnd_file.put_line (fnd_file.LOG, 'Total Records Count : ' || ln_cnt);
        fnd_file.put_line (
            fnd_file.LOG,
               'Write Outfile - End Time :'
            || TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, '-------------------------------');
    EXCEPTION
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    := SQLERRM;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Program got error out due to:' || SQLERRM);
    END MAIN;
END XXD_VT_CONSOLIDATED_PKG;
/
