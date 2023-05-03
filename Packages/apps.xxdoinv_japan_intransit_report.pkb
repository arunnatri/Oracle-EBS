--
-- XXDOINV_JAPAN_INTRANSIT_REPORT  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINV_JAPAN_INTRANSIT_REPORT"
AS
    /******************************************************************************************
    * Package          :xxdoinv_intransit_report
    * Author           : BT Technology Team
    * Program Name     : In-Transit Inventory Report - Deckers
    *
    * Modification  :
    *----------------------------------------------------------------------------------------------
    *     Date         Developer             Version     Description
    *----------------------------------------------------------------------------------------------
    * 22-APR-2015    BT Technology Team      V1.1      Package being used for create journals in the GL.
    * 10-JUN-2015    BT Technology Team      V1.2      Fixed the HPQC Defect#2321
    * 11-Dec-2015    BT Technology Team      V1.3      Fixed the HPQC Defect#799
    ************************************************************************************************/

    G_PKG_NAME   CONSTANT VARCHAR2 (40) := 'XXDOINV_JAPAN_INTRANSIT_REPORT';
    G_CATEGORY_SET_ID     NUMBER;
    G_CATEGORY_SET_NAME   VARCHAR2 (100) := 'OM Sales Category';

    /*procedure load_temp_table(p_as_of_date in date, p_inv_org_id in number, p_cost_type_id in number, x_ret_stat out varchar2, x_error_messages out varchar2) is
      l_proc_name varchar2(80) := G_PKG_NAME || '.LOAD_TEMP_TABLE';
      l_cost_type_id number;
      l_msg_cnt number;
    begin
        do_debug_tools.msg('+' || l_proc_name);
        do_debug_tools.msg('p_as_of_date=' || nvl(to_char(p_as_of_date, 'YYYY-MM-DD'), '{None}') || ', p_inv_org_id=' || p_inv_org_id || ', p_cost_type_id=' || nvl(to_char(p_cost_type_id), '{None}'));

        begin
            l_cost_type_id := p_cost_type_id;
            if l_cost_type_id is null then
                do_debug_tools.msg(' looping up cost type from inventory organization.');

                select primary_cost_method
                into l_cost_type_id
                from mtl_parameters
                where organization_id = p_inv_org_id;

                do_debug_tools.msg(' found cost type ' || l_cost_type_id || ' from inventory organization.');
            end if;

            do_debug_tools.msg(' before call to CST_Inventory_PUB.Calculate_InventoryValue');
            CST_Inventory_PUB.Calculate_InventoryValue(
                 p_api_version          => 1.0
                ,p_init_msg_list        => FND_API.G_FALSE
                ,p_commit               => CST_Utility_PUB.get_true
                ,p_organization_id      => p_inv_org_id
                ,p_onhand_value         => 0
                ,p_intransit_value      => 1
                ,p_receiving_value      => 1
                ,p_valuation_date       => trunc(nvl(p_as_of_date, sysdate)+1)
                ,p_cost_type_id         => l_cost_type_id
                ,p_item_from            => null
                ,p_item_to              => null
                --Start modification by BT Technology Team on 9-march-2015  'Styles'as replacement for 'OM sales Category'
                --,p_category_set_id      => 4
                ,p_category_set_id      =>G_CATEGORY_SET_ID
                --End modification by BT Technology Team on 9-march-2015  'Styles'as replacement for 'OM sales Category'
                ,p_category_from        => null
                ,p_category_to          => null
                ,p_cost_group_from      => null
                ,p_cost_group_to        => null
                ,p_subinventory_from    => null
                ,p_subinventory_to      => null
                ,p_qty_by_revision      => 0
                ,p_zero_cost_only       => 0
                ,p_zero_qty             => 0
                ,p_expense_item         => 0
                ,p_expense_sub          => 0
                ,p_unvalued_txns        => 0
                ,p_receipt              => 1
                ,p_shipment             => 1
                ,p_detail               => 1
                ,p_own                  => 0
                ,p_cost_enabled_only    => 0
                ,p_one_time_item        => 0
                ,p_include_period_end   => null
                ,x_return_status        => x_ret_stat
                ,x_msg_count            => l_msg_cnt
                ,x_msg_data             => x_error_messages
              );
            do_debug_tools.msg(' after call to CST_Inventory_PUB.Calculate_InventoryValue');

    select count(1)
    into l_msg_cnt
    from cst_inv_qty_temp;
    do_debug_tools.msg('count: ' || l_msg_cnt);

        exception
            when others then
                 do_debug_tools.msg(' others exception: ' || sqlerrm);
                  x_ret_stat := fnd_api.g_ret_sts_error;
                  x_error_messages := sqlerrm;
        end;

        do_debug_tools.msg('x_ret_stat=' || x_ret_stat || ', x_error_messages=' || x_error_messages);
        do_debug_tools.msg('-' || l_proc_name);
    end;*/


    PROCEDURE run_japan_intransit_report (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_inv_org_id IN NUMBER, p_region IN VARCHAR2, p_as_of_date IN VARCHAR2, p_cost_type_id IN NUMBER, p_brand IN VARCHAR2, p_show_color IN VARCHAR2, p_show_supplier_details IN VARCHAR2, p_markup_rate_type IN VARCHAR2, p_elimination_org IN VARCHAR2, p_elimination_rate IN VARCHAR2
                                          , p_dummy_elimination_rate IN VARCHAR2, p_user_rate IN NUMBER, p_debug_level IN NUMBER:= NULL)
    IS
        l_proc_name                             VARCHAR2 (80) := G_PKG_NAME || '.RUN_INTRANSIT_REPORT';
        l_ret_stat                              VARCHAR2 (1);
        l_err_messages                          VARCHAR2 (2000);
        l_use_date                              DATE;
        l_cnt                                   NUMBER;
        l_rate_multiplier                       NUMBER;
        l_rate_amt                              NUMBER;
        l_rate                                  NUMBER;
        l_tq_markup                             NUMBER;
        l_Mark_Up_Macau_Cost                    NUMBER;
        l_ext_Mark_Up_Macau_Cost                NUMBER;
        l_JPY_Elimination                       NUMBER;
        l_USD_Elimination                       NUMBER;
        l_fact_invoice_num                      VARCHAR2 (40);
        l_elimination_rate                      NUMBER;
        l_macau_conv_rate                       NUMBER;
        l_inv_org                               VARCHAR2 (2000);

        w_organization_code            CONSTANT NUMBER := 10;
        w_brand                        CONSTANT NUMBER := 10;
        w_style                        CONSTANT NUMBER := 15;
        w_color                        CONSTANT NUMBER := 10;
        w_quantity                     CONSTANT NUMBER := 10;
        w_item_cost                    CONSTANT NUMBER := 10;
        w_material_cost                CONSTANT NUMBER := 10;
        w_material_overhead_cost       CONSTANT NUMBER := 10;
        w_freight_cost                 CONSTANT NUMBER := 10;
        w_duty_cost                    CONSTANT NUMBER := 10;
        w_vendor                       CONSTANT NUMBER := 25;
        w_vendor_reference             CONSTANT NUMBER := 30;
        w_ext_item_cost                CONSTANT NUMBER := 15;
        w_ext_material_cost            CONSTANT NUMBER := 15;
        w_ext_material_overhead_cost   CONSTANT NUMBER := 15;
        w_ext_freight_cost             CONSTANT NUMBER := 15;
        w_ext_duty_cost                CONSTANT NUMBER := 15;
        w_type                         CONSTANT NUMBER := 15;
        w_trx_date                     CONSTANT NUMBER := 10;
        w_sales_order                  CONSTANT NUMBER := 10;

        CURSOR c_inv_orgs IS
            SELECT organization_id, organization_code
              FROM apps.mtl_parameters
             WHERE organization_id = NVL (p_inv_org_id, -1)
            UNION
            SELECT mp.organization_id, mp.organization_code
              FROM apps.mtl_parameters mp, hr_all_organization_units haou
             WHERE     mp.attribute1 = p_region
                   AND p_inv_org_id IS NULL
                   AND haou.organization_id = mp.organization_id
                   AND NVL (haou.date_to, SYSDATE + 1) >= TRUNC (SYSDATE)
                   AND EXISTS
                           (SELECT NULL
                              FROM mtl_secondary_inventories msi
                             WHERE msi.organization_id = mp.organization_id)
            ORDER BY organization_code;

        CURSOR c_rpt_lines (l_curr_inv_org_id NUMBER)
        IS
            -- Start Changes by BT Technology Team on 10-JUN-2015 for Defect#2321
            SELECT organization_code, brand, style,
                   color, color_code, quantity,
                   item_cost, material_cost, DECODE (item_cost, 0, 0, duty_cost) duty_cost,
                   DECODE (item_cost, 0, 0, freight_cost) freight_cost, DECODE (item_cost, 0, 0, freight_du_cost) freight_du_cost, DECODE (item_cost, 0, 0, OH_Duty_Cst) OH_Duty_Cst,
                   DECODE (item_cost, 0, 0, OH_Non_Duty_Cst) OH_Non_Duty_Cst, intransit_type, vendor,
                   vendor_name, vendor_reference, transaction_date,
                   ext_item_cost, ext_material_cost, macau_cost,
                   po_cost, ext_po_cost, so_number,
                   po_header_id, po_line_id, PO_LINE_LOCATION_ID,
                   DECODE (item_cost, 0, 0, ext_duty_cost) ext_duty_cost, DECODE (item_cost, 0, 0, ext_freight_cost) ext_freight_cost, DECODE (item_cost, 0, 0, ext_freight_du_cost) ext_freight_du_cost,
                   DECODE (item_cost, 0, 0, ext_oh_Duty_Cst) ext_oh_Duty_Cst, DECODE (item_cost, 0, 0, ext_oh_Non_Duty_Cst) ext_oh_Non_Duty_Cst
              FROM (SELECT mp.organization_code
                               AS organization_code,
                           citv.BRAND
                               AS brand,
                           citv.style_number
                               AS style,
                           DECODE (p_show_color, 'N', NULL, citv.color_code)
                               AS color,
                           citv.color_code,
                           cost.Quantity
                               AS Quantity,
                           ROUND (xxdoget_item_cost ('ITEMCOST', cost.organization_id, cost.inventory_item_id
                                                     , 'N'),
                                  4)
                               AS item_cost,
                           ROUND (xxdoget_item_cost ('MATERIAL_COST', cost.organization_id, cost.inventory_item_id
                                                     , 'Y'),
                                  4)
                               AS material_cost,
                           ROUND (xxdoget_item_cost ('DUTY', cost.organization_id, cost.inventory_item_id
                                                     , 'Y'),
                                  4)
                               AS duty_cost,
                           ROUND (xxdoget_item_cost ('FREIGHT', cost.organization_id, cost.inventory_item_id
                                                     , 'Y'),
                                  4)
                               AS freight_cost,
                           ROUND (xxdoget_item_cost ('FREIGHT DU', cost.organization_id, cost.inventory_item_id
                                                     , 'Y'),
                                  4)
                               AS Freight_DU_Cost,
                           ROUND (xxdoget_item_cost ('OH DUTY', cost.organization_id, cost.inventory_item_id
                                                     , 'Y'),
                                  4)
                               AS OH_Duty_Cst,
                           ROUND (xxdoget_item_cost ('OH NONDUTY', cost.organization_id, cost.inventory_item_id
                                                     , 'Y'),
                                  4)
                               AS OH_Non_Duty_Cst,
                           'Purchase Order'
                               AS intransit_type,
                           DECODE (p_show_supplier_details,
                                   'N', NULL,
                                   ap.Vendor_name)
                               AS vendor,
                           ap.Vendor_name,
                           DECODE (p_show_supplier_details,
                                   'N', NULL,
                                   'PO#' || cost.po_num)
                               AS vendor_reference,
                           cost.So_number
                               AS So_number,
                           cost.po_header_id,
                           cost.po_line_id,
                           cost.PO_LINE_LOCATION_ID,
                           cost.po_cost
                               AS po_cost,
                           cost.po_cost * cost.quantity
                               AS ext_po_cost,
                           cost.macau_cost
                               AS macau_cost,
                           cost.macau_cost * cost.quantity
                               AS ext_macau_cost,
                           TO_CHAR (cost.asn_creation_date, 'DD/MM/YYYY')
                               AS transaction_date,
                           ROUND ((  cost.Quantity
                                   * (xxdoget_item_cost ('ITEMCOST', cost.organization_id, cost.inventory_item_id
                                                         , 'N'))),
                                  4)
                               AS ext_item_cost,
                           ROUND ((  cost.Quantity
                                   * (xxdoget_item_cost ('MATERIAL_COST', cost.organization_id, cost.inventory_item_id
                                                         , 'Y'))),
                                  4)
                               AS ext_material_cost,
                           ROUND ((  cost.Quantity
                                   * (xxdoget_item_cost ('DUTY', cost.organization_id, cost.inventory_item_id
                                                         , 'Y'))),
                                  4)
                               AS ext_duty_cost,
                           ROUND ((  cost.Quantity
                                   * (xxdoget_item_cost ('FREIGHT', cost.organization_id, cost.inventory_item_id
                                                         , 'Y'))),
                                  4)
                               AS ext_freight_cost,
                           ROUND ((  cost.Quantity
                                   * (xxdoget_item_cost ('FREIGHT DU', cost.organization_id, cost.inventory_item_id
                                                         , 'Y'))),
                                  4)
                               AS ext_freight_du_cost,
                           ROUND ((  cost.Quantity
                                   * (xxdoget_item_cost ('OH DUTY', cost.organization_id, cost.inventory_item_id
                                                         , 'Y'))),
                                  4)
                               AS Ext_OH_Duty_Cst,
                           ROUND ((  cost.Quantity
                                   * (xxdoget_item_cost ('OH NONDUTY', cost.organization_id, cost.inventory_item_id
                                                         , 'Y'))),
                                  4)
                               AS Ext_OH_Non_Duty_Cst
                      FROM (SELECT DISTINCT
                                   rsl.quantity_shipped
                                       AS Quantity,
                                   rsh.creation_date
                                       AS asn_creation_date,
                                   msib.organization_id
                                       AS organization_id,
                                   msib.inventory_item_id
                                       AS inventory_item_id,
                                   poh.segment1
                                       AS po_num,
                                   poh.po_header_id
                                       AS po_header_id,
                                   poh.vendor_Id
                                       AS vendor_Id,
                                   rsl.creation_date
                                       AS creation_date,
                                   ap.vendor_type_lookup_code,
                                   ap.vendor_name,
                                   pla.unit_price
                                       po_cost,
                                   -- Start changes by BT Technology Team on 11-Dec-2015 for defect#799
                                   --msib_macau.list_price_per_unit macau_cost,
                                   NVL (
                                       xxdoget_item_cost ('ITEMCOST', msib.organization_id, msib.inventory_item_id
                                                          , 'N'),
                                       NVL (msib_macau.list_price_per_unit,
                                            0))
                                       macau_cost,
                                   -- End changes by BT Technology Team on 11-Dec-2015 for defect#799
                                   --pla.attribute5  so_line_id,
                                   pla.attribute_category,
                                   ooha.order_number
                                       So_number,
                                   rsh.shipment_header_id,
                                   rsl.shipment_line_id,
                                   rsl.po_line_id,
                                   rsl.PO_LINE_LOCATION_ID
                              FROM apps.rcv_shipment_headers rsh,
                                   apps.rcv_shipment_lines rsl,
                                   apps.rcv_transactions rt,
                                   apps.mtl_system_items_b msib,
                                   apps.po_headers_all poh,
                                   (SELECT *
                                      FROM apps.po_lines_all pla
                                     WHERE attribute_category LIKE
                                               'Intercompany PO%') pla,
                                   apps.ap_suppliers ap,
                                   apps.org_organization_definitions ood,
                                   oe_order_headers_all ooha,
                                   oe_order_lines_all oola,
                                   apps.xxd_common_items_v msib_macau
                             WHERE     rsl.shipment_header_id =
                                       rsh.shipment_header_id
                                   AND rt.shipment_header_id(+) =
                                       rsh.shipment_header_id
                                   --AND rt.shipment_line_id = rsl.shipment_line_id
                                   --AND nvl(rt.transaction_date,sysdate)<= nvl(l_use_date,sysdate)
                                   AND (rsh.shipped_date IS NOT NULL AND rsh.shipped_date < TO_DATE (NVL (l_use_date, SYSDATE)) + 1) --roll forward date added as per Vishwa's confirmation
                                   AND poh.po_header_id = rsl.po_header_id
                                   AND msib.inventory_item_id = rsl.item_id
                                   AND rsl.po_line_id = pla.po_line_id
                                   -- AND ood.organization_id = l_curr_inv_org_id
                                   AND msib.ORGANIZATION_ID =
                                       rsl.TO_ORGANIZATION_ID
                                   AND rsl.shipment_line_status_code =
                                       'EXPECTED'
                                   AND rsl.source_document_code = 'PO'
                                   AND rsh.asn_type = 'ASN'
                                   AND poh.org_id IN
                                           (SELECT organization_id
                                              FROM hr_operating_units
                                             WHERE name = 'Deckers Japan OU')
                                   AND ood.organization_id =
                                       rsl.TO_ORGANIZATION_ID
                                   AND poh.po_header_id = pla.po_header_id
                                   AND poh.vendor_id = ap.vendor_id
                                   AND ooha.header_id = oola.header_id
                                   AND oola.line_id = pla.attribute5
                                   AND ooha.org_id IN
                                           (SELECT organization_id
                                              FROM hr_operating_units
                                             WHERE name = 'Deckers Macau OU')
                                   AND ood.organization_id =
                                       rsl.TO_ORGANIZATION_ID
                                   AND msib_macau.organization_id =
                                       oola.ship_from_org_id
                                   AND msib_macau.inventory_item_id =
                                       oola.inventory_item_id) cost,
                           xxd_common_items_v citv,
                           mtl_parameters mp,
                           ap_suppliers ap
                     WHERE     citv.ORGANIZATION_ID = cost.ORGANIZATION_ID
                           AND citv.INVENTORY_ITEM_ID =
                               cost.INVENTORY_ITEM_ID
                           AND citv.brand LIKE NVL (p_brand, '%')
                           AND mp.ORGANIZATION_ID = citv.ORGANIZATION_ID
                           AND cost.VENDOR_ID = ap.VENDOR_ID);
    BEGIN
        IF NVL (p_debug_level, 0) > 0
        THEN
            do_debug_tools.enable_conc_log (p_debug_level);
        END IF;

        BEGIN
            SELECT category_set_id
              INTO G_CATEGORY_SET_ID
              FROM mtl_category_sets
             WHERE category_set_name = G_CATEGORY_SET_NAME;
        EXCEPTION
            WHEN OTHERS
            THEN
                raise_application_error (-20001,
                                         'Sales Category Not defined.');
        END;

        do_debug_tools.msg ('+' || l_proc_name);
        do_debug_tools.msg (
               'p_inv_org_id='
            || p_inv_org_id
            || ', p_region='
            || p_region
            || ', p_as_of_date='
            || NVL (p_as_of_date, '{None}')
            || ', p_cost_type_id='
            || NVL (TO_CHAR (p_cost_type_id), '{None}')
            || ', p_brand='
            || p_brand
            || ', p_show_color='
            || p_show_color
            || ', p_show_supplier_details='
            || p_show_supplier_details);

        BEGIN
            IF p_inv_org_id IS NULL AND p_region IS NULL
            THEN
                raise_application_error (
                    -20001,
                    'Either an inventory organization or region must be specified');
            END IF;

            IF p_as_of_date IS NOT NULL
            THEN
                l_use_date   :=
                    TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS');
            END IF;


            BEGIN
                SELECT organization_name
                  INTO l_inv_org
                  FROM org_organization_definitions
                 WHERE organization_id = p_inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_inv_org   := p_inv_org_id;
            END;

            fnd_file.put (
                fnd_file.output,
                   'Japan In-Transit Inventory Report - Deckers:'
                || CHR (10)
                || ' Inventory Organization: '
                || l_inv_org
                || CHR (10)
                || ' Region: '
                || p_region
                || CHR (10)
                || ' Roll Back Date: '
                || NVL (p_as_of_date, '{None}')
                || CHR (10)
                || ' Brand: '
                || p_brand
                || CHR (10)
                || ' Show Color: '
                || NVL (p_show_color, '{None}')
                || CHR (10)
                || ' Show Supplier Details:'
                || NVL (TO_CHAR (p_show_supplier_details), '{None}')
                || CHR (10)
                || ' Markup Rate Type: '
                || p_markup_rate_type
                || CHR (10)
                || ' Elimination Org: '
                || p_elimination_org
                || CHR (10)
                || ' Elimination Rate: '
                || p_elimination_rate
                || CHR (10)
                || CHR (10)
                || ' User Rate: '
                || p_user_rate
                || CHR (10)
                || CHR (10));


            fnd_file.put_line (
                fnd_file.output,
                   RPAD ('Warehouse', 15, ' ')
                || RPAD ('Brand', 12, ' ')
                || RPAD ('Style', 15, ' ')
                || RPAD ('Color', 10, ' ')
                || RPAD ('Quantity', 13, ' ')
                || RPAD ('Item Cost', 20, ' ')
                || RPAD ('Material Cost', 20, ' ')
                || RPAD ('Freight Cost', 20, ' ')
                || RPAD ('Duty Cost', 20, ' ')
                || RPAD ('OH Duty ', 20, ' ')
                || RPAD ('OH Non Duty', 20, ' ')
                || RPAD ('Type', 20, ' ')
                || RPAD ('TQ Vendor', 67, ' ')
                || RPAD ('TQ PO Reference', 20, ' ')
                || RPAD ('Factory Invoice Num', 25, ' ')
                || RPAD ('SO Number', 20, ' ')
                || RPAD ('Trx Date', 15, ' ')
                || RPAD ('Ext Item Cost', 20, ' ')
                || RPAD ('Ext Mat Cost', 20, ' ')
                || RPAD ('Ext Freight Cost', 20, ' ')
                || RPAD ('Ext Duty Cost', 20, ' ')
                || RPAD ('Ext OH Duty ', 20, ' ')
                || RPAD ('Ext OH NonDuty ', 20, ' ')
                || RPAD ('PO Cost', 20, ' ')
                || RPAD ('Ext PO Cost', 20, ' ')
                || RPAD ('Macau Cost', 20, ' ')
                || -- Start changes by BT Technology Team on 11-Dec-2015 for defect#799
                   --rpad('TQ Markup',20 , ' ') ||
                   --rpad('Marked Up Macau Cost',25, ' ') ||
                   --rpad('Ext MarkedUp Macau Cost',28, ' ') ||
                   --rpad('JPY Elimination',20, ' ') ||
                   RPAD ('Extended Macau Cost', 20, ' ')
                || RPAD ('Material Cost in USD', 25, ' ')
                || RPAD ('Extended Material Cost in USD', 28, ' ')
                || -- End changes by BT Technology Team on 11-Dec-2015 for defect#799
                   RPAD ('USD Elimination', 20, ' ')
                || CHR (13)
                || CHR (10));

            --);

            fnd_file.put_line (fnd_file.output,
                               RPAD ('=', 640, '=') || CHR (13) || CHR (10));

            do_debug_tools.msg ('  before inventory organization loop');

            FOR c_inv_org IN c_inv_orgs
            LOOP
                do_debug_tools.msg (
                    ' processing inventory organization ' || c_inv_org.organization_code);

                do_debug_tools.msg ('  purging temp tables.');
                /* delete from cst_item_list_temp item;
                 delete from cst_inv_qty_temp;
                 delete from cst_inv_cost_temp;
                 commit;

                 do_debug_tools.msg('  calling load_temp_table.');
                 load_temp_table(p_as_of_date => l_use_date, p_inv_org_id => c_inv_org.organization_id, p_cost_type_id => p_cost_type_id, x_ret_stat => l_ret_stat, x_error_messages => l_err_messages);
                 do_debug_tools.msg('  call to load_temp_table returned ' || l_ret_stat || '.  ' || l_err_messages);

                 if nvl(l_ret_stat, fnd_api.g_ret_sts_error) != fnd_api.g_ret_sts_success then
                     perrproc := 1;
                     psqlstat := 'Failed to load details for ' || c_inv_org.organization_code || '.  ' || l_err_messages;
                 else
                 */
                l_cnt   := 0;
                do_debug_tools.msg (' before report line loop.');

                FOR c_rpt_line IN c_rpt_lines (c_inv_org.organization_id)
                LOOP
                    l_cnt   := l_cnt + 1;
                    do_debug_tools.msg (' counter: ' || l_cnt);

                    BEGIN
                        SELECT CONVERSION_RATE
                          INTO l_rate
                          FROM gl_daily_rates
                         WHERE     conversion_type =
                                   NVL (p_markup_rate_type, '1000') -- budget_id for rate type
                               AND TRUNC (conversion_date) =
                                   NVL (
                                       TO_DATE (p_as_of_date,
                                                'YYYY/MM/DD HH24:MI:SS'),
                                       TRUNC (SYSDATE))
                               AND from_currency = 'USD'
                               AND to_currency = 'JPY';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_rate   := 0;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error while Fetching CONV Rate ' || SQLERRM);
                    END;

                    BEGIN
                        SELECT DISTINCT conversion_rate
                          INTO l_macau_conv_rate
                          FROM gl_daily_rates
                         WHERE     conversion_type =
                                   NVL (p_markup_rate_type, '1000') -- budget_id for rate type
                               AND TRUNC (conversion_date) =
                                   NVL (
                                       TO_DATE (p_as_of_date,
                                                'YYYY/MM/DD HH24:MI:SS'),
                                       TRUNC (SYSDATE))
                               AND from_currency = 'MOP'
                               AND to_currency = 'JPY';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_macau_conv_rate   := 0;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while Fetching  Macau CONV Rate '
                                || SQLERRM);
                    END;

                    BEGIN
                        -- Start changes by BT Technology Team on 11-Dec-2015 for defect#799
                        --SELECT distinct rate_multiplier
                        --     ,rate_amount --xppra.VENDOR_NAME,xppr.po_price_rule
                        SELECT NVL (MAX (rate_multiplier), 1), NVL (MAX (rate_amount), 0)
                          -- End changes by BT Technology Team on 11-Dec-2015 for defect#799
                          INTO l_rate_multiplier, l_rate_amt
                          FROM do_custom.xxdo_po_price_rule xppr, do_custom.xxdo_po_price_rule_assignment xppra--,AP_SUPPLIERS APS
                                                                                                               -- ,HR_ORGANIZATION_UNITS HROU
                                                                                                               , apps.xxd_common_items_v xci
                         WHERE     xppr.po_price_rule = xppra.po_price_rule
                               --AND  xppr.VENDOR_NAME = APS.VENDOR_NAME
                               --AND  APS.VENDOR_ID =  p_vendor_id
                               --AND  xppra.target_item_orgANIZATION = HROU.NAME
                               --AND HROU.ORGANIZATION_ID = 129;
                               AND xppra.item_segment1 = xci.style_number
                               AND xppra.item_segment2 = xci.color_code
                               -- AND xppr.po_price_rule = 'MB-SANUK-NTQ'  --lv_color
                               AND xci.ORG_name =
                                   xppra.target_item_orgANIZATION
                               AND xppr.VENDOR_NAME = c_rpt_line.vendor_name
                               AND xci.style_number = c_rpt_line.style
                               AND xci.color_code = c_rpt_line.color_code;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_rate_multiplier   := 0;
                            l_rate_amt          := 0;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while Fetching Rate Multiplier'
                                || SQLERRM);
                    END;

                    --l_tq_markup:= (NVL(c_rpt_line.ext_material_cost*l_rate, 0)*l_rate_multiplier) + l_rate_amt;

                    --l_Mark_Up_Macau_Cost := l_tq_markup + (c_rpt_line.macau_cost*l_macau_conv_rate);

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'p_markup_rate_type' || p_markup_rate_type);
                    fnd_file.put_line (fnd_file.LOG, 'l_rate' || l_rate);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'c_rpt_line.macau_cost' || c_rpt_line.macau_cost);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'l_rate_multiplier' || l_rate_multiplier);
                    fnd_file.put_line (fnd_file.LOG,
                                       'l_rate_amt' || l_rate_amt);

                    -- Start changes by BT Technology Team on 11-Dec-2015 for defect#799
                    --l_Mark_Up_Macau_Cost := (NVL(c_rpt_line.macau_cost*l_rate, 0)*l_rate_multiplier) + l_rate_amt;

                    --l_tq_markup:= l_Mark_Up_Macau_Cost - NVL(c_rpt_line.macau_cost*l_rate,0);

                    --l_ext_Mark_Up_Macau_Cost :=l_Mark_Up_Macau_Cost*c_rpt_line.quantity;

                    --JPY Elimination logic -- If Ext PO Cost > Ext MarkedUp Macau Cost  then Ext PO Cost- Ext Markedup Macau Cst  else Zero
                    -- Commented l_JPY_Elimination. No longer needed.
                    --IF c_rpt_line.ext_po_cost >= l_ext_Mark_Up_Macau_Cost THEN
                    --   l_JPY_Elimination:=c_rpt_line.ext_po_cost - l_ext_Mark_Up_Macau_Cost;
                    --ELSE
                    --   l_JPY_Elimination:=0;
                    --END IF;

                    -- End changes by BT Technology Team on 11-Dec-2015 for defect#799

                    BEGIN
                        SELECT ds.invoice_num
                          INTO l_fact_invoice_num
                          FROM apps.do_items di, apps.do_containers dc, apps.do_shipments ds
                         WHERE     1 = 1
                               AND di.line_location_id =
                                   c_rpt_line.PO_LINE_LOCATION_ID
                               AND di.order_line_id = c_rpt_line.po_line_id
                               AND di.order_id = c_rpt_line.po_header_id
                               AND di.container_id = dc.container_id
                               AND dc.shipment_id = ds.shipment_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_fact_invoice_num   := 'NA';
                    END;

                    IF p_elimination_rate <> 'USER'
                    THEN
                        l_elimination_rate   :=
                            TO_NUMBER (SUBSTR (p_elimination_rate, 4, 2));

                        BEGIN
                            SELECT AVG (CONVERSION_RATE)
                              INTO l_USD_Elimination
                              FROM gl_daily_rates
                             WHERE     conversion_type =
                                       NVL (p_markup_rate_type, '1000') -- budget_id for rate type
                                   -- Start changes by BT Technology Team on 11-Dec-2015 for defect#799
                                   --AND TRUNC(conversion_date) between  add_months(SYSDATE,-(l_elimination_rate)) AND  sysdate
                                   AND TRUNC (conversion_date) BETWEEN   ADD_MONTHS (
                                                                             fnd_date.canonical_to_date (
                                                                                 p_as_of_date),
                                                                             -(l_elimination_rate))
                                                                       + 1
                                                                   AND fnd_date.canonical_to_date (
                                                                           p_as_of_date)
                                   -- End changes by BT Technology Team on 11-Dec-2015 for defect#799
                                   AND from_currency = 'JPY'
                                   AND to_currency = 'USD';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_USD_Elimination   := 0;
                        END;
                    ELSE
                        l_USD_Elimination   := NVL (p_user_rate, 0);
                    END IF;

                    -- Start changes by BT Technology Team on 11-Dec-2015 for defect#799
                    l_mark_up_macau_cost   :=
                        ROUND (
                              (NVL (c_rpt_line.po_cost - l_rate_amt, 0) / l_rate_multiplier)
                            * l_usd_elimination,
                            2);
                    l_ext_mark_up_macau_cost   :=
                        l_mark_up_macau_cost * c_rpt_line.quantity;
                    --l_tq_markup is reused for Extended Macau Cost
                    l_tq_markup   :=
                        ROUND (
                            NVL (c_rpt_line.macau_cost * c_rpt_line.quantity,
                                 0),
                            2);
                    l_jpy_elimination   :=
                        CASE
                            WHEN l_ext_mark_up_macau_cost > l_tq_markup
                            THEN
                                l_ext_mark_up_macau_cost - l_tq_markup
                            ELSE
                                0
                        END;

                    -- End changes by BT Technology Team on 11-Dec-2015 for defect#799

                    fnd_file.put_line (
                        fnd_file.output,
                           RPAD (c_rpt_line.organization_code, 15, ' ')
                        || RPAD (NVL (c_rpt_line.brand, ' '), 12, ' ')
                        || RPAD (NVL (c_rpt_line.style, ' '), 15, ' ')
                        || RPAD (NVL (c_rpt_line.color, ' '), 10, ' ')
                        || RPAD (NVL (c_rpt_line.quantity, 0), 13, ' ')
                        || RPAD (NVL (c_rpt_line.item_cost, 0), 20, ' ')
                        || RPAD (NVL (c_rpt_line.material_cost, 0), 20, ' ')
                        || RPAD (NVL (c_rpt_line.freight_cost, 0), 20, ' ')
                        || RPAD (NVL (c_rpt_line.duty_cost, 0), 20, ' ')
                        || RPAD (NVL (c_rpt_line.OH_Duty_Cst, 0), 20, ' ')
                        || RPAD (NVL (c_rpt_line.OH_Non_Duty_Cst, 0),
                                 20,
                                 ' ')
                        || RPAD (NVL (c_rpt_line.intransit_type, ' '),
                                 20,
                                 ' ')
                        || RPAD (NVL (c_rpt_line.vendor, ' '), 67, ' ')
                        || RPAD (NVL (c_rpt_line.vendor_reference, ' '),
                                 25,
                                 ' ')
                        || RPAD (NVL (l_fact_invoice_num, ''), 20, ' ')
                        || RPAD (NVL (TO_CHAR (c_rpt_line.so_number), ' '),
                                 20,
                                 ' ')
                        || RPAD (
                               NVL (TO_CHAR (c_rpt_line.transaction_date),
                                    ' '),
                               15,
                               ' ')
                        || RPAD (NVL (c_rpt_line.ext_item_cost, 0), 20, ' ')
                        || RPAD (NVL (c_rpt_line.ext_material_cost, 0),
                                 20,
                                 ' ')
                        || RPAD (NVL (c_rpt_line.ext_freight_cost, 0),
                                 20,
                                 ' ')
                        || RPAD (NVL (c_rpt_line.ext_duty_cost, 0), 20, ' ')
                        || RPAD (NVL (c_rpt_line.ext_oh_Duty_Cst, 0),
                                 20,
                                 ' ')
                        || RPAD (NVL (c_rpt_line.ext_oh_Non_Duty_Cst, 0),
                                 20,
                                 ' ')
                        || RPAD (NVL (c_rpt_line.po_cost, 0), 20, ' ')
                        || RPAD (NVL (c_rpt_line.ext_po_cost, 0), 20, ' ')
                        || RPAD (NVL (c_rpt_line.macau_cost, 0), 20, ' ')
                        || RPAD (ROUND (NVL (l_tq_markup, 0), 3), 20, ' ')
                        || RPAD (ROUND (NVL (l_Mark_Up_Macau_Cost, 0), 3),
                                 25,
                                 ' ')
                        || RPAD (
                               ROUND (NVL (l_ext_Mark_Up_Macau_Cost, 0), 3),
                               28,
                               ' ')
                        || -- Start changes by BT Technology Team on 11-Dec-2015 for defect#799
                           --rpad(round(nvl(l_JPY_Elimination, 0),3),20, ' ') ||
                           --rpad(round(nvl((l_JPY_Elimination/l_USD_Elimination), 0),5),20, ' ') ||CHR (13) || CHR (10));
                           RPAD (ROUND (NVL (l_jpy_elimination, 0), 5),
                                 20,
                                 ' ')
                        || CHR (13)
                        || CHR (10));
                -- End changes by BT Technology Team on 11-Dec-2015 for defect#799
                END LOOP;

                do_debug_tools.msg (' after report line loop.');
            --end if;

            END LOOP;

            do_debug_tools.msg ('  done inventory organization loop');
        EXCEPTION
            WHEN OTHERS
            THEN
                do_debug_tools.msg (' others exception: ' || SQLERRM);
                perrproc   := 2;
                psqlstat   := SQLERRM;
        END;

        do_debug_tools.msg (
            'perrproc=' || perrproc || ', psqlstat=' || psqlstat);
        do_debug_tools.msg ('-' || l_proc_name);
    END;
END;
/
