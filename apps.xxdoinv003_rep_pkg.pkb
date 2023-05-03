--
-- XXDOINV003_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINV003_REP_PKG"
AS
    /******************************************************************************
       NAME: XXDOINV03_REP_PKG
       PURPOSE:Inventory Aging Details Report - Deckers

       REVISIONS:
       Ver        Date         Author            Description
       ---------  ----------   ---------------   ------------------------------------
       1.0        02/22/2011     Shibu            1. Created this package for AR XXDOINV003 Report
       2.0        09/26/2011     Shibu            Modified this package to include the new column Quater Sales Qty.
       2.1        06/05/2012   Madhav Dhurjaty     1. Added parameter P_format to get_item_detail function
              and INV_AGING_DETAILS procedure for INC0111255
       3.0        01/22/2015   BT Tech Team        1. Updated to retrofit for 12.2.3
       3.1       07/29/2015   BT Tech Team        1. Modified for CR 92
       3.2        16-Nov-2015  BT Tech Team        Modified for defect 678
       3.3        23-NOV-2015   BT Tech Team        Excluded KCO columns as per Defect 712
       4.1        04/27/2018    Arun N Murthy       Modifying the aging buckets as per CCR0007235
       4.2        08/31/2018    Srinath Siricilla   Modified for CCR0007484
    4.3    02/09/2021   Srinath Siricilla Modified for CCR0009537
    4.4    02/09/2022   Aravind Kannuri  Modified for CCR0009851
     ******************************************************************************/

    --Global Variables
    gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id; --Added for 4.4

    --------------------------------------------------------------------------------
    /*Start Changes by BT Technology Team on 12-JAN-2015*/
    --------------------------------------------------------------------------------

    FUNCTION get_server_timezone (pv_date VARCHAR2, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        ln_leid    NUMBER;
        ld_sdate   VARCHAR2 (40) := NULL;
    BEGIN
        BEGIN
            SELECT legal_entity
              INTO ln_leid
              FROM apps.org_organization_definitions ood
             WHERE organization_id = pn_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_leid   := 9999;
        END;

        BEGIN
            SELECT TO_CHAR (apps.xle_le_timezone_grp.get_server_day_time_for_le (TO_DATE (pv_date, 'RRRR/MM/DD HH24:MI:SS'), ln_leid), 'RRRR/MM/DD HH24:MI:SS')
              INTO ld_sdate
              FROM DUAL;
        END;

        RETURN ld_sdate;
    END get_server_timezone;

    --   FUNCTION get_kco_open_qty_amt (
    --      p_inventory_item_id   NUMBER,
    --      p_organization_id     NUMBER,
    --      p_col                 VARCHAR2
    --   )
    --      RETURN NUMBER
    --   IS
    --      ln_open_qty   NUMBER;
    --      ln_open_amt   NUMBER;
    --      ln_return     NUMBER := NULL;
    --
    --

    --         CURSOR c1 (p_organization_id NUMBER, p_inventory_item_id NUMBER)
    --      IS
    --         SELECT   SUM (dkl.scheduled_quantity) kco_units,
    --                  SUM
    --                     (  dkl.scheduled_quantity
    --                      * do_kco.kco_item_price (dkl.kco_header_id,
    --                                               dkl.inventory_item_id
    --                                              )
    --                     ) kco_amount
    --             FROM do_kco.do_kco_line dkl, do_kco.do_kco_header dkh
    --            WHERE dkl.kco_header_id = dkh.kco_header_id
    --              AND dkh.open_flag = 1
    --              AND dkh.enabled_flag = 1
    --              AND dkh.atp_flag = 1
    --              AND dkl.open_flag = 1
    --              AND dkl.enabled_flag = 1
    --              AND dkl.atp_flag = 1
    --              AND (   dkl.kco_line_disable_date IS NULL
    --                   OR dkl.kco_line_disable_date > SYSDATE
    --                  )
    --              AND dkl.kco_schedule_date >= TRUNC (SYSDATE) - 21
    --              AND inventory_item_id = p_inventory_item_id
    --              AND organization_id = p_organization_id
    --         GROUP BY dkl.organization_id, dkl.inventory_item_id;
    --   BEGIN
    --      FOR i IN c1 (p_organization_id, p_inventory_item_id)
    --      LOOP
    --         ln_open_amt := i.kco_amount;
    --         ln_open_qty := i.kco_units;
    --      END LOOP;

    --         IF p_col = 'AMT'
    --      THEN
    --         ln_return := ln_open_amt;
    --      ELSIF p_col = 'QTY'
    --      THEN
    --         ln_return := ln_open_qty;
    --      END IF;

    --         RETURN (ln_return);
    --   EXCEPTION
    --      WHEN NO_DATA_FOUND
    --      THEN
    --         RETURN 0;
    --      WHEN OTHERS
    --      THEN
    --        RETURN 0;
    --   END get_kco_open_qty_amt;
    FUNCTION get_kco_open_qty_amt (p_inventory_item_id NUMBER, p_organization_id NUMBER, p_brand VARCHAR2
                                   , p_col VARCHAR2)
        RETURN NUMBER
    IS
        ln_open_qty   NUMBER;
        ln_open_amt   NUMBER;
    BEGIN
        SELECT (SELECT SUM (using_requirement_quantity)
                  --INTO ln_open_qty
                  FROM apps.msc_demands@bt_ebs_to_ascp.us.oracle.com
                 WHERE     organization_id = p_organization_id
                       AND inventory_item_id = p_inventory_item_id),
               (CASE p_col
                    WHEN 'AMT'
                    THEN
                        (SELECT qpl.operand
                           --INTO ln_open_amt
                           FROM mtl_category_sets mcs, mtl_item_categories mic, qp_pricing_attributes qpa,
                                qp_list_lines qpl, qp_list_headers_v qph, Xxd_default_pricelist_matrix xdpm,
                                org_organization_definitions ood
                          WHERE     mic.category_set_id = mcs.category_set_id
                                AND mic.organization_id = ood.organization_id
                                AND mcs.category_set_name LIKE
                                        'OM Sales Category'
                                AND mic.inventory_item_id =
                                    p_inventory_item_id
                                AND qpa.PRODUCT_ATTR_VALUE = mic.category_id
                                AND qpa.product_attribute =
                                    'PRICING_ATTRIBUTE2'
                                AND qpa.PRODUCT_ATTRIBUTE_CONTEXT = 'ITEM'
                                AND qpa.list_line_id = qpl.list_line_id
                                AND qpl.ARITHMETIC_OPERATOR = 'UNIT_PRICE'
                                AND qph.list_header_id = qpa.list_header_id
                                AND SYSDATE BETWEEN xdpm.ORDER_START_DATE
                                                AND xdpm.ORDER_END_DATE
                                AND SYSDATE BETWEEN xdpm.REQUESTED_START_DATE
                                                AND xdpm.REQUESTED_END_DATE
                                AND xdpm.BRAND = p_brand
                                AND xdpm.org_id = ood.operating_unit
                                AND ood.organization_id = p_organization_id
                                AND qph.name = xdpm.PRICE_LIST_NAME)
                    ELSE
                        1
                END)
          INTO ln_open_qty, ln_open_amt
          FROM DUAL;

        RETURN ln_open_qty * ln_open_amt;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_kco_open_qty_amt;

    --------------------------------------------------------------------------------
    /*END Changes by BT Technology Team on 12-JAN-2015*/
    --------------------------------------------------------------------------------

    FUNCTION get_item_detail (p_item_id NUMBER, p_invorg_id NUMBER, p_col VARCHAR2
                              , p_format VARCHAR2)
        RETURN VARCHAR2
    IS
        --------------------------------------------------------------------------------
        /*Start Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------

        --lv_style          VARCHAR2 (100);        --Commented by BT Technology Team
        --lv_color          VARCHAR2 (100);        --Commented by BT Technology Team
        --lv_sze            VARCHAR2 (100);        --Commented by BT Technology Team
        --lv_sku            VARCHAR2 (100);        --Commented by BT Technology Team
        --lv_item_desc      VARCHAR2 (250);        --Commented by BT Technology Team
        --lv_season         VARCHAR2 (100);        --Commented by BT Technology Team
        --lv_sort_order     VARCHAR2 (100);        --Commented by BT Technology Team
        --lv_intro_season   VARCHAR2 (100);        --Commented by BT Technology Team
        --lv_brand          VARCHAR2 (100);        --Commented by BT Technology Team
        l_return   VARCHAR2 (300);               --Added by BT Technology Team
    BEGIN
        --      SELECT msib.segment1 AS style, msib.segment2 AS color,
        --             msib.segment3 AS sze,
        --                msib.segment1
        --             || '-'
        --             || msib.segment2
        --             || DECODE (p_format, 'SUMMARY', NULL, '-' || msib.segment3)
        --                                                                       AS sku,
        --             msib.description, msib.attribute1 AS current_season,
        --             TO_NUMBER (msib.attribute10) AS item_sort_order
        --        INTO lv_style, lv_color,
        --             lv_sze,
        --             lv_sku,
        --             lv_item_desc, lv_season,
        --             lv_sort_order
        --        FROM apps.mtl_system_items_b msib
        --       WHERE inventory_item_id = p_item_id AND organization_id = p_invorg_id;

        --------------------------------------------------------------------------------
        /*Start Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------
        SELECT CASE p_col
                   WHEN 'STYLE'
                   THEN
                       xci.style_number
                   WHEN 'COLOR'
                   THEN
                       xci.color_code
                   WHEN 'SZE'
                   THEN
                       xci.item_size
                   WHEN 'SKU'
                   THEN
                       DECODE (
                           p_format,
                           'SUMMARY',    xci.style_number
                                      || '-'
                                      || xci.color_code,
                           xci.item_number)
                   WHEN 'DESC'
                   THEN
                       xci.item_description
                   WHEN 'SEASON'
                   THEN
                       xci.curr_active_season
                   WHEN 'SORTORDER'
                   THEN
                       xci.size_sort_code     --TO_NUMBER (xci.size_sort_code)
                   WHEN 'INTRO_SEASON'
                   THEN
                       xci.intro_season
                   WHEN 'BRAND'
                   THEN
                       xci.brand
                   --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                   WHEN 'ITEM_TYPE'
                   THEN
                       xci.item_type
               --End modification for CR 92,on 29-Jul-15,BT Technology Team
               END
          INTO l_return
          FROM apps.xxd_common_items_v xci
         WHERE     inventory_item_id = p_item_id
               AND organization_id = p_invorg_id;


        --------------------------------------------------------------------------------
        /*END Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------
        RETURN l_return;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_return   := NULL;
    END get_item_detail;

    PROCEDURE inv_aging_details (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_organization_id NUMBER, p_as_of_date VARCHAR2, p_region VARCHAR2, p_format VARCHAR2
                                 , p_time_zone VARCHAR2)
    IS
        --------------------------------------------------------------------------------
        /*Start Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------

        --      CURSOR cur_inv_org (p_region VARCHAR2)
        --      IS
        --         SELECT   organization_id
        --             FROM apps.org_organization_definitions
        --            WHERE disable_date IS NULL
        --              AND inventory_enabled_flag = 'Y'
        --              AND operating_unit IN (
        --                     SELECT flex_value
        --                       FROM apps.fnd_flex_values ffv,
        --                            apps.fnd_flex_value_sets fvs
        --                      WHERE ffv.flex_value_set_id = fvs.flex_value_set_id
        --                        AND fvs.flex_value_set_name =
        --                                                  'DO_INVVAL_DUTY_REGION_ORGS'
        --                        AND ffv.parent_flex_value_low = p_region
        --                        AND ffv.enabled_flag = 'Y'
        --                        AND ffv.summary_flag = 'N')
        --         ORDER BY 1;


        --  cursor c_sqty(l_as_of_date date, p_qtr_start_date date,P_ORGANIZATION_ID Number) is
        --       select   mtl.organization_id,mtl.inventory_item_id,
        --                sum(mtl.primary_quantity) primary_quantity
        --                from apps.mtl_material_transactions mtl,
        --                     XXDO.XXDO_MTL_ON_HAND onhand
        --                where
        --                 mtl.organization_id = onhand.organization_id
        --                and mtl.inventory_item_id   = onhand.inventory_item_id
        --                and mtl.transaction_type_id in(33,37) --Sales and returns
        --                and mtl.TRANSACTION_DATE >= p_qtr_start_date
        --                and mtl.TRANSACTION_DATE < NVL(l_as_of_date,SYSDATE- 1)
        --                and mtl.organization_id = P_ORGANIZATION_ID
        --                group by mtl.organization_id,mtl.inventory_item_id;
        --------------------------------------------------------------------------------
        /*END Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------

        -- Detail Cursor
        -- Added Hints for 4.4
        CURSOR c_det IS
              SELECT /*+ full(rcv_shipment_headers, rcv_shipment_lines, po_requisition_lines_all, xxdo_sales_qty) */
                     brand, warehouse AS org_name, sku,
                     description AS item_description, --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                                                      color, item_type,
                     --End modification for CR 92,on 29-Jul-15,BT Technology Team
                     intro_season, current_season, series AS item_category,
                     item_cost AS landed_cost, total_cost, total_units,
                     qtr_sales_qty, --Start Changes V4.1
                                    --                  GREATEST (total_cost - three_cost, 0) AS under4,
                                    --                  GREATEST (three_cost - four_cost, 0) AS four,
                                    --                  GREATEST (four_cost - five_cost, 0) AS five,
                                    --                  GREATEST (five_cost - six_cost, 0) AS six,
                                    --                  six_cost AS over6,
                                    GREATEST (total_cost - zero_to_3months, 0) AS zero_to_3months, GREATEST (zero_to_3months - three_to_6months, 0) AS three_to_6months,
                     GREATEST (three_to_6months - six_to_12months, 0) AS six_to_12months, GREATEST (six_to_12months - tweleve_to_18months, 0) AS tweleve_to_18months, GREATEST ((eighteen_plus_months), 0) AS eighteen_plus_months,
                     --End Changes V4.1
                     ship.shipped_units AS shipped_quantity, oo.open_units AS so_open_quantity, oo.open_amount AS so_open_amount
                --------------------------------------------------------------------------------
                /*Start Changes by BT Technology Team on 12-JAN-2015*/
                --------------------------------------------------------------------------------
                /*, get_kco_open_qty_amt (alpha.inventory_item_id,
                                       alpha.organization_id,
                                       NULL,
                                       'QTY')
                    AS kco_open_quantity,
                 xxdoinv003_rep_pkg.get_kco_open_qty_amt (
                    alpha.inventory_item_id,
                    alpha.organization_id,
                    alpha.brand,
                    'AMT')
                    AS kco_open_amount */
                -- Commented by BT Technology Team as part of DEFCET#712 as per shahn confirmation
                --,kco_open_quantity,        --  Commented by BT Technology Team
                --kco_open_amount            --  Commented by BT Technology Team
                --------------------------------------------------------------------------------
                /*END Changes by BT Technology Team on 12-JAN-2015*/
                --------------------------------------------------------------------------------
                FROM (  SELECT onhand.organization_id,
                               onhand.org_name
                                   AS warehouse,
                               onhand.style,
                               onhand.color,
                               onhand.sze,
                               onhand.sku,
                               onhand.item_description
                                   description,
                               --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                               onhand.item_type,
                               --End modification for CR 92,on 29-Jul-15,BT Technology Team
                               onhand.current_season,
                               onhand.item_sort_order,
                               onhand.intro_season,
                               onhand.series,
                               onhand.brand,
                               onhand.inventory_item_id,
                               onhand.item_cost,
                               onhand.total_units,
                               (SELECT SUM (primary_quantity)
                                  FROM xxdo.xxdo_sales_qty
                                 WHERE     organization_id =
                                           onhand.organization_id
                                       AND inventory_item_id =
                                           onhand.inventory_item_id)
                                   qtr_sales_qty,
                               onhand.total_units * onhand.item_cost
                                   total_cost,
                               --------------------------------------------------------------------------------
                               /*Start Changes by BT Technology Team on 12-JAN-2015*/
                               --------------------------------------------------------------------------------
                               --                            get_kco_open_qty_amt
                               --                                 (onhand.inventory_item_id,
                               --                                  onhand.organization_id,
                               --                                  'QTY'
                               --                                 ) kco_open_quantity,
                               --                            get_kco_open_qty_amt
                               --                                   (onhand.inventory_item_id,
                               --                                    onhand.organization_id,
                               --                                    'AMT'
                               --                                   ) kco_open_amount,
                               --------------------------------------------------------------------------------
                               /*END Changes by BT Technology Team on 12-JAN-2015*/
                               --------------------------------------------------------------------------------
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             --Start Changes V4.1
                                             --                                       WHEN NVL (rcpts.rcpt_months_ago, 9999) <=
                                             --                                               2
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  3         --End Changes V4.1
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   --                               AS three_cost,
                                   AS zero_to_3months,
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             --Start Changes V4.1
                                             --                                       WHEN NVL (rcpts.rcpt_months_ago, 9999) <=
                                             --                                               3
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  6         --End Changes V4.1
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   --                               AS four_cost,
                                   AS three_to_6months,
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             --Start Changes V4.1
                                             --                                       WHEN NVL (rcpts.rcpt_months_ago, 9999) <=
                                             --                                               4
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  12        --End Changes V4.1
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   --                               AS five_cost,
                                   AS six_to_12months,
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             --Start Changes V4.1
                                             --                                       WHEN NVL (rcpts.rcpt_months_ago, 9999) <=
                                             --                                               5
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  18        --End Changes V4.1
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   --                               AS six_cost
                                   AS tweleve_to_18months,
                               --Start changes V4.1
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  18
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   AS eighteen_plus_months
                          --End Changes V4.1
                          FROM (  SELECT (SELECT NAME
                                            FROM apps.hr_all_organization_units
                                           WHERE organization_id =
                                                 oh.organization_id)
                                             AS org_name,
                                         --
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'STYLE'
                                                          , 'DETAIL')
                                             style,
                                         --
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'COLOR'
                                                          , 'DETAIL')
                                             color,
                                         --
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'STSORTORDER'
                                                          , 'DETAIL')
                                             item_sort_order,
                                         --
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'SZE'
                                                          , 'DETAIL')
                                             sze,
                                         --
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'SKU'
                                                          , 'DETAIL')
                                             sku,
                                         --
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'DESC'
                                                          , 'DETAIL')
                                             item_description,
                                         --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'ITEM_TYPE'
                                                          , 'DETAIL')
                                             item_type,
                                         --End modification for CR 92,on 29-Jul-15,BT Technology Team
                                         --
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'SEASON'
                                                          , 'DETAIL')
                                             current_season,
                                         brand,
                                         organization_id,
                                         inventory_item_id,
                                         intro_season,
                                         series,
                                         item_cost,
                                         total_units,
                                         total_cost
                                    FROM xxdo.xxdo_mtl_on_hand oh
                                ORDER BY organization_id) onhand,
                               /*
                               start - HighJump Changes: added IRISO and Inter-org receipts in addition to PO receipts
                               also considered corrections on PO receipts
                               */
                                (  SELECT organization_id, inventory_item_id, rcpt_months_ago,
                                          SUM (quantity) quantity
                                     FROM (                 /* PO receiving */
                                           SELECT organization_id, inventory_item_id, rcpt_months_ago,
                                                  (receipt_quantity + corrected_qty) quantity
                                             FROM (SELECT rcvt.organization_id,
                                                          rsl.item_id
                                                              AS inventory_item_id,
                                                          --Start changes commented as part of V1.9
                                                          --                                                      TRUNC
                                                          --End Changes
                                                          (MONTHS_BETWEEN (--                                                            TRUNC (SYSDATE),
                                                                           TO_DATE (p_as_of_date, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (NVL (TO_DATE (rsh.attribute15), rcvt.transaction_date))))
                                                              AS rcpt_months_ago,
                                                          NVL (rcvt.quantity, 0)
                                                              receipt_quantity,
                                                          (SELECT NVL (SUM (quantity), 0)
                                                             FROM apps.rcv_transactions rcvt1
                                                            WHERE     rcvt1.parent_transaction_id =
                                                                      rcvt.transaction_id
                                                                  AND rcvt1.transaction_type =
                                                                      'CORRECT')
                                                              corrected_qty
                                                     FROM apps.rcv_shipment_headers rsh, apps.rcv_shipment_lines rsl, apps.rcv_transactions rcvt
                                                    WHERE     rcvt.transaction_type =
                                                              'DELIVER'
                                                          AND rcvt.destination_type_code =
                                                              'INVENTORY'
                                                          AND rsh.shipment_header_id =
                                                              rsl.shipment_header_id
                                                          AND rsl.source_document_code =
                                                              'PO'
                                                          AND NVL (
                                                                  TO_DATE (
                                                                      rsh.attribute15),
                                                                  rcvt.transaction_date) <=
                                                              TO_DATE (
                                                                  p_as_of_date,
                                                                  'RRRR/MM/DD HH24:MI:SS')
                                                          AND NVL (
                                                                  TO_DATE (
                                                                      rsh.attribute15),
                                                                  rcvt.transaction_date) >=
                                                              ADD_MONTHS (
                                                                  --                                                            TRUNC (SYSDATE),
                                                                  TO_DATE (
                                                                      p_as_of_date,
                                                                      'RRRR/MM/DD HH24:MI:SS'),
                                                                  -18)
                                                          AND rsl.shipment_line_id =
                                                              rcvt.shipment_line_id
                                                          AND rcvt.requisition_line_id
                                                                  IS NULL) x
                                            WHERE (receipt_quantity + corrected_qty) >
                                                  0
                                           /* corrected qty also conisdered in above WHERE clause - added for HJ project */
                                           UNION ALL
                                           /* IRISO receiving - added for HJ project */
                                           SELECT organization_id, item_id, months,
                                                  (receipt_quantity + corrected_qty) quantity
                                             FROM (SELECT rcvt.organization_id,
                                                          prl.item_id,
                                                          --Start changes commented as part of V1.9
                                                          --                                                      TRUNC
                                                          --End Changes
                                                          (MONTHS_BETWEEN (--                                                            TRUNC (SYSDATE),
                                                                           TO_DATE (p_as_of_date, 'RRRR/MM/DD HH24:MI:SS'), NVL (TRUNC (TO_DATE (prl.attribute11, 'DD-MON-YYYY')), TRUNC (rcvt.transaction_date))))
                                                              months,
                                                          rcvt.quantity
                                                              receipt_quantity,
                                                          (SELECT NVL (SUM (quantity), 0)
                                                             FROM apps.rcv_transactions rcvt1
                                                            WHERE     rcvt1.parent_transaction_id =
                                                                      rcvt.transaction_id
                                                                  AND rcvt1.transaction_type =
                                                                      'CORRECT')
                                                              corrected_qty
                                                     FROM apps.rcv_transactions rcvt, apps.po_requisition_lines_all prl
                                                    WHERE     rcvt.requisition_line_id =
                                                              prl.requisition_line_id
                                                          AND rcvt.transaction_type =
                                                              'DELIVER'
                                                          AND rcvt.destination_type_code =
                                                              'INVENTORY'
                                                          AND prl.source_type_code =
                                                              'INVENTORY'
                                                          AND NVL (
                                                                  TO_DATE (
                                                                      prl.attribute11,
                                                                      'DD-MON-RRRR'),
                                                                  rcvt.transaction_date) <=
                                                              TO_DATE (
                                                                  p_as_of_date,
                                                                  'RRRR/MM/DD HH24:MI:SS')
                                                          AND NVL (
                                                                  TRUNC (
                                                                      TO_DATE (
                                                                          prl.attribute11,
                                                                          'DD-MON-YYYY')),
                                                                  TRUNC (
                                                                      rcvt.transaction_date)) >=
                                                              ADD_MONTHS (
                                                                  --                                                            TRUNC (SYSDATE),
                                                                  TO_DATE (
                                                                      p_as_of_date,
                                                                      'RRRR/MM/DD HH24:MI:SS'),
                                                                  -18)) y
                                            WHERE (receipt_quantity + corrected_qty) >
                                                  0
                                           UNION ALL
                                           /* Inter-org transfers - added for HJ project*/
                                           SELECT organization_id, inventory_item_id, --                                              TRUNC
                                                                                      (MONTHS_BETWEEN (--                                                            TRUNC (SYSDATE),
                                                                                                       TO_DATE (p_as_of_date, 'RRRR/MM/DD HH24:MI:SS'), NVL (TRUNC (TO_DATE (attribute1, 'DD-MON-YYYY')), TRUNC (mmt.transaction_date)))) months,
                                                  transaction_quantity
                                             FROM apps.mtl_material_transactions mmt
                                            WHERE     transaction_type_id = 3
                                                  AND transaction_quantity > 0
                                                  AND NVL (
                                                          TO_DATE (attribute1,
                                                                   'DD-MON-RRRR'),
                                                          mmt.transaction_date) <=
                                                      TO_DATE (
                                                          p_as_of_date,
                                                          'RRRR/MM/DD HH24:MI:SS')
                                                  AND NVL (
                                                          TRUNC (
                                                              TO_DATE (
                                                                  attribute1,
                                                                  'DD-MON-YYYY')),
                                                          TRUNC (
                                                              mmt.transaction_date)) >=
                                                      ADD_MONTHS (
                                                          --                                                            TRUNC (SYSDATE),
                                                          TO_DATE (
                                                              p_as_of_date,
                                                              'RRRR/MM/DD HH24:MI:SS'),
                                                          -18)) rcvt
                                 GROUP BY organization_id, inventory_item_id, rcpt_months_ago)
                               rcpts
                         /* end - HighJump Changes*/
                         WHERE     rcpts.organization_id(+) =
                                   onhand.organization_id
                               AND rcpts.inventory_item_id(+) =
                                   onhand.inventory_item_id
                      --                                   and onhand.inventory_item_id = 14504816
                      GROUP BY onhand.brand, onhand.org_name, onhand.style,
                               onhand.color, onhand.sze, onhand.sku,
                               onhand.item_description, --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                                                        onhand.item_type, --End modification for CR 92,on 29-Jul-15,BT Technology Team
                                                                          onhand.current_season,
                               onhand.item_sort_order, onhand.intro_season, onhand.series,
                               onhand.organization_id, onhand.inventory_item_id, onhand.total_units,
                               onhand.item_cost, onhand.total_cost) alpha,
                     (  SELECT ship_from_org_id, inventory_item_id, SUM (ordered_quantity) AS shipped_units
                          FROM xxdo.xxdo_so_closed_qty
                         WHERE 1 = 1        --and inventory_item_id = 14504816
                      GROUP BY ship_from_org_id, inventory_item_id) ship,
                     (  SELECT ship_from_org_id, inventory_item_id, SUM (ordered_quantity) AS open_units,
                               SUM (ordered_quantity * unit_selling_price) AS open_amount
                          FROM xxdo.xxdo_so_open_qty
                         WHERE 1 = 1        --and inventory_item_id = 14504816
                      GROUP BY ship_from_org_id, inventory_item_id) oo,
                     apps.mtl_parameters mp
               WHERE     alpha.organization_id = mp.organization_id
                     AND ship.inventory_item_id(+) = alpha.inventory_item_id
                     AND ship.ship_from_org_id(+) = alpha.organization_id
                     AND oo.inventory_item_id(+) = alpha.inventory_item_id
                     AND oo.ship_from_org_id(+) = alpha.organization_id
            -- and alpha.organization_id = nvl(p_organization_id, mp.organization_id)
            ORDER BY alpha.brand, alpha.warehouse, alpha.style,
                     alpha.color, alpha.item_sort_order;

        -- Summary Cursor
        -- Added Hints for 4.4
        CURSOR c_summ IS
              SELECT /*+ full(rcv_shipment_headers, rcv_shipment_lines, po_requisition_lines_all, xxdo_sales_qty) */
                     brand, warehouse AS org_name, style,
                     color, sku, description AS item_description,
                     --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                     item_type, --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                                intro_season, current_season,
                     series AS item_category, ROUND (SUM (item_cost * total_units) / NVL (DECODE (SUM (total_units), 0, 1, SUM (total_units)), 1), 2) AS landed_cost, SUM (total_cost) total_cost,
                     SUM (total_units) total_units, SUM (qtr_sales_qty) qtr_sales_qty, --Start Changes V4.1
                                                                                       --                  GREATEST (total_cost - three_cost, 0) AS under4,
                                                                                       --                  GREATEST (three_cost - four_cost, 0) AS four,
                                                                                       --                  GREATEST (four_cost - five_cost, 0) AS five,
                                                                                       --                  GREATEST (five_cost - six_cost, 0) AS six,
                                                                                       --                  six_cost AS over6,
                                                                                       GREATEST (SUM (total_cost - zero_to_3months), 0) AS zero_to_3months,
                     GREATEST (SUM (zero_to_3months - three_to_6months), 0) AS three_to_6months, GREATEST (SUM (three_to_6months - six_to_12months), 0) AS six_to_12months, GREATEST (SUM (six_to_12months - twelve_to_18months), 0) AS twelve_to_18months,
                     SUM (eighteen_plus_months) AS eighteen_plus_months, --End Changes V4.1
                                                                         SUM (ship.shipped_units) AS shipped_quantity, SUM (oo.open_units) AS so_open_quantity,
                     SUM (oo.open_amount) AS so_open_amount --------------------------------------------------------------------------------
                /*Start Changes by BT Technology Team on 12-JAN-2015*/
                --------------------------------------------------------------------------------
                --                  SUM (kco_open_quantity) kco_open_quantity,
                --                  SUM (kco_open_amount) kco_open_amount
                /* ,
                 SUM(get_kco_open_qty_amt (alpha.inventory_item_id,
                                       alpha.organization_id,
                                       NULL,
                                       'QTY'))
                    AS kco_open_quantity,
                 SUM(get_kco_open_qty_amt (
                    alpha.inventory_item_id,
                    alpha.organization_id,
                    alpha.brand,
                    'AMT'))
                    AS kco_open_amount*/
                -- Commented by BT Technology Team as part of DEFCET#712 as per shahn confirmation
                --------------------------------------------------------------------------------
                /*END Changes by BT Technology Team on 12-JAN-2015*/
                --------------------------------------------------------------------------------
                FROM (  SELECT onhand.organization_id,
                               onhand.org_name
                                   AS warehouse,
                               onhand.style,
                               onhand.color,
                               --, onhand.sze        --  Commented by BT Technology Team
                               onhand.sku,
                               onhand.item_description
                                   description,
                               --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                               onhand.item_type,
                               --End modification for CR 92,on 29-Jul-15,BT Technology Team
                               onhand.current_season,
                               onhand.item_sort_order,
                               onhand.intro_season,
                               onhand.series,
                               onhand.brand,
                               onhand.inventory_item_id,
                               onhand.item_cost,
                               onhand.total_units,
                               (SELECT SUM (primary_quantity)
                                  FROM xxdo.xxdo_sales_qty
                                 WHERE     organization_id =
                                           onhand.organization_id
                                       AND inventory_item_id =
                                           onhand.inventory_item_id--and onhand.inventory_item_id = 14504816
                                                                   )
                                   qtr_sales_qty,
                               onhand.total_units * onhand.item_cost
                                   total_cost,
                               --------------------------------------------------------------------------------
                               /*Start Changes by BT Technology Team on 12-JAN-2015*/
                               --------------------------------------------------------------------------------
                               --                            get_kco_open_qty_amt
                               --                                 (onhand.inventory_item_id,
                               --                                  onhand.organization_id,
                               --                                  'QTY'
                               --                                 ) kco_open_quantity,
                               --                            get_kco_open_qty_amt
                               --                                   (onhand.inventory_item_id,
                               --                                    onhand.organization_id,
                               --                                    'AMT'
                               --                                   ) kco_open_amount,
                               --------------------------------------------------------------------------------
                               /*END Changes by BT Technology Team on 12-JAN-2015*/
                               --------------------------------------------------------------------------------
                               --Start Changes V4.1
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             --Start Changes V4.1
                                             --                                       WHEN NVL (rcpts.rcpt_months_ago, 9999) <=
                                             --                                               2
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  3         --End Changes V4.1
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   AS zero_to_3months,
                               --ENd Changes V4.1
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             --Start Changes V4.1
                                             --                                       WHEN NVL (rcpts.rcpt_months_ago, 9999) <=
                                             --                                               5
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  6         --End Changes V4.1
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   AS three_to_6months,
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             --Start Changes V4.1
                                             --                                       WHEN NVL (rcpts.rcpt_months_ago, 9999) <=
                                             --                                               3
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  12        --End Changes V4.1
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   AS six_to_12months,
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             --Start Changes V4.1
                                             --                                       WHEN NVL (rcpts.rcpt_months_ago, 9999) <=
                                             --                                               4
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  18        --End Changes V4.1
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   AS twelve_to_18months,
                               --twelve_to_18 and 18 plus months are redundant. However reatined to differentiate
                               GREATEST (
                                     onhand.total_cost
                                   - SUM (
                                         CASE
                                             --Start Changes V4.1
                                             --                                       WHEN NVL (rcpts.rcpt_months_ago, 9999) <=
                                             --                                               5
                                             WHEN NVL (rcpts.rcpt_months_ago,
                                                       9999) <=
                                                  18        --End Changes V4.1
                                             THEN
                                                   rcpts.quantity
                                                 * onhand.item_cost
                                             ELSE
                                                 0
                                         END),
                                   0)
                                   AS eighteen_plus_months
                          FROM (  SELECT (SELECT NAME
                                            FROM apps.hr_all_organization_units
                                           WHERE organization_id =
                                                 oh.organization_id)
                                             AS org_name,
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'STYLE'
                                                          , 'SUMMARY')
                                             style,
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'COLOR'
                                                          , 'SUMMARY')
                                             color,
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'STSORTORDER'
                                                          , 'SUMMARY')
                                             item_sort_order,
                                         --, get_item_detail(oh.inventory_item_id,oh.organization_id,'SZE','SUMMARY') sze  --  Commented by BT Technology Team
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'SKU'
                                                          , 'SUMMARY')
                                             sku,
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'DESC'
                                                          , 'SUMMARY')
                                             item_description,
                                         --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'ITEM_TYPE'
                                                          , 'SUMMARY')
                                             item_type,
                                         --End modification for CR 92,on 29-Jul-15,BT Technology Team
                                         get_item_detail (oh.inventory_item_id, oh.organization_id, 'SEASON'
                                                          , 'SUMMARY')
                                             current_season,
                                         brand,
                                         organization_id,
                                         inventory_item_id,
                                         intro_season,
                                         series,
                                         item_cost,
                                         total_units,
                                         total_cost
                                    FROM xxdo.xxdo_mtl_on_hand oh
                                   WHERE 1 = 1 --and inventory_item_id = 14504816
                                ORDER BY organization_id) onhand,
                               /*
                               start - HighJump Changes: added IRISO and Inter-org receipts in addition to PO receipts
                               also considered corrections on PO receipts
                               */
                                (  SELECT organization_id, inventory_item_id, rcpt_months_ago,
                                          SUM (quantity) quantity
                                     FROM (                 /* PO receiving */
                                           SELECT organization_id, inventory_item_id, rcpt_months_ago,
                                                  (receipt_quantity + corrected_qty) quantity
                                             FROM (SELECT rcvt.organization_id,
                                                          rsl.item_id
                                                              AS inventory_item_id,
                                                          --Start changes commented as part of V1.9
                                                          --                                                      TRUNC
                                                          --End Changes
                                                          (MONTHS_BETWEEN (--                                                            TRUNC (SYSDATE),
                                                                           TO_DATE (p_as_of_date, 'RRRR/MM/DD HH24:MI:SS'), TRUNC (NVL (TO_DATE (rsh.attribute15), rcvt.transaction_date))))
                                                              AS rcpt_months_ago,
                                                          NVL (rcvt.quantity, 0)
                                                              receipt_quantity,
                                                          (SELECT NVL (SUM (quantity), 0)
                                                             FROM apps.rcv_transactions rcvt1
                                                            WHERE     rcvt1.parent_transaction_id =
                                                                      rcvt.transaction_id
                                                                  AND rcvt1.transaction_type =
                                                                      'CORRECT')
                                                              corrected_qty
                                                     FROM apps.rcv_shipment_lines rsl, apps.rcv_transactions rcvt, apps.rcv_shipment_headers rsh
                                                    WHERE     1 = 1 --and rsl.item_id = 14504816
                                                          AND rcvt.transaction_type =
                                                              'DELIVER'
                                                          AND rcvt.destination_type_code =
                                                              'INVENTORY'
                                                          AND NVL (
                                                                  TO_DATE (
                                                                      rsh.attribute15),
                                                                  rcvt.transaction_date) <=
                                                              TO_DATE (
                                                                  p_as_of_date,
                                                                  'RRRR/MM/DD HH24:MI:SS')
                                                          AND NVL (
                                                                  TO_DATE (
                                                                      rsh.attribute15),
                                                                  rcvt.transaction_date) >=
                                                              ADD_MONTHS (
                                                                  TO_DATE (
                                                                      p_as_of_date,
                                                                      'RRRR/MM/DD HH24:MI:SS'),
                                                                  -18)
                                                          AND rsl.shipment_line_id =
                                                              rcvt.shipment_line_id
                                                          AND rsh.shipment_header_id =
                                                              rsl.shipment_header_id
                                                          AND rsl.source_document_code =
                                                              'PO'
                                                          AND rcvt.requisition_line_id
                                                                  IS NULL) x
                                            WHERE (receipt_quantity + corrected_qty) >
                                                  0
                                           /* corrected qty also conisdered in above WHERE clause - added for HJ project */
                                           UNION ALL
                                           /* IRISO receiving - added for HJ project */
                                           SELECT organization_id, item_id, months,
                                                  (receipt_quantity + corrected_qty) quantity
                                             FROM (SELECT rcvt.organization_id,
                                                          prl.item_id,
                                                          --Start changes commented as part of V1.9
                                                          --                                                      TRUNC
                                                          --End Changes
                                                          (MONTHS_BETWEEN (--                                                            TRUNC (SYSDATE),
                                                                           TO_DATE (p_as_of_date, 'RRRR/MM/DD HH24:MI:SS'), NVL (TRUNC (TO_DATE (prl.attribute11, 'DD-MON-YYYY')), TRUNC (rcvt.transaction_date))))
                                                              months,
                                                          rcvt.quantity
                                                              receipt_quantity,
                                                          (SELECT NVL (SUM (quantity), 0)
                                                             FROM apps.rcv_transactions rcvt1
                                                            WHERE     rcvt1.parent_transaction_id =
                                                                      rcvt.transaction_id
                                                                  AND rcvt1.transaction_type =
                                                                      'CORRECT')
                                                              corrected_qty
                                                     FROM apps.rcv_transactions rcvt, apps.po_requisition_lines_all prl
                                                    WHERE     rcvt.requisition_line_id =
                                                              prl.requisition_line_id
                                                          --and prl.item_id = 14504816
                                                          AND rcvt.transaction_type =
                                                              'DELIVER'
                                                          AND rcvt.destination_type_code =
                                                              'INVENTORY'
                                                          AND prl.source_type_code =
                                                              'INVENTORY'
                                                          AND NVL (
                                                                  TO_DATE (
                                                                      prl.attribute11,
                                                                      'DD-MON-RRRR'),
                                                                  rcvt.transaction_date) <=
                                                              TO_DATE (
                                                                  p_as_of_date,
                                                                  'RRRR/MM/DD HH24:MI:SS')
                                                          AND NVL (
                                                                  TRUNC (
                                                                      TO_DATE (
                                                                          prl.attribute11,
                                                                          'DD-MON-YYYY')),
                                                                  TRUNC (
                                                                      rcvt.transaction_date)) >=
                                                              ADD_MONTHS (
                                                                  --                                                                TRUNC (SYSDATE),
                                                                  TO_DATE (
                                                                      p_as_of_date,
                                                                      'RRRR/MM/DD HH24:MI:SS'),
                                                                  -18)) y
                                            WHERE (receipt_quantity + corrected_qty) >
                                                  0
                                           UNION ALL
                                           /* Inter-org transfers - added for HJ project*/
                                           SELECT organization_id, inventory_item_id, --Start changes commented as part of V1.9
                                                                                      --                                                      TRUNC
                                                                                      --End Changes
                                                                                      (MONTHS_BETWEEN (--                                                            TRUNC (SYSDATE),
                                                                                                       TO_DATE (p_as_of_date, 'RRRR/MM/DD HH24:MI:SS'), NVL (TRUNC (TO_DATE (attribute1, 'DD-MON-YYYY')), TRUNC (mmt.transaction_date)))) months,
                                                  transaction_quantity
                                             FROM apps.mtl_material_transactions mmt
                                            WHERE     transaction_type_id = 3
                                                  --                                        and mmt.inventory_item_id = 14504816
                                                  AND transaction_quantity > 0
                                                  AND NVL (
                                                          TO_DATE (attribute1,
                                                                   'DD-MON-RRRR'),
                                                          mmt.transaction_date) <=
                                                      TO_DATE (
                                                          p_as_of_date,
                                                          'RRRR/MM/DD HH24:MI:SS')
                                                  AND NVL (
                                                          TRUNC (
                                                              TO_DATE (
                                                                  attribute1,
                                                                  'DD-MON-YYYY')),
                                                          TRUNC (
                                                              mmt.transaction_date)) >=
                                                      ADD_MONTHS (
                                                          --                                                     TRUNC (SYSDATE),
                                                          TO_DATE (
                                                              p_as_of_date,
                                                              'RRRR/MM/DD HH24:MI:SS'),
                                                          -18)) rcvt
                                 GROUP BY organization_id, inventory_item_id, rcpt_months_ago)
                               rcpts
                         /* end - HighJump changes */
                         WHERE     rcpts.organization_id(+) =
                                   onhand.organization_id
                               AND rcpts.inventory_item_id(+) =
                                   onhand.inventory_item_id
                      GROUP BY onhand.brand, onhand.org_name, onhand.style,
                               onhand.color --, onhand.sze      -- Commented for BT Technology Team
                                           , onhand.sku, onhand.item_description,
                               --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                               onhand.item_type, --End modification for CR 92,on 29-Jul-15,BT Technology Team
                                                 onhand.current_season, onhand.item_sort_order,
                               onhand.intro_season, onhand.series, onhand.organization_id,
                               onhand.inventory_item_id, onhand.total_units, onhand.item_cost,
                               onhand.total_cost) alpha,
                     (  SELECT ship_from_org_id, inventory_item_id, SUM (ordered_quantity) AS shipped_units
                          FROM xxdo.xxdo_so_closed_qty
                         WHERE 1 = 1        --and inventory_item_id = 14504816
                      GROUP BY ship_from_org_id, inventory_item_id) ship,
                     (  SELECT ship_from_org_id, inventory_item_id, SUM (ordered_quantity) AS open_units,
                               SUM (ordered_quantity * unit_selling_price) AS open_amount
                          FROM xxdo.xxdo_so_open_qty
                         WHERE 1 = 1        --and inventory_item_id = 14504816
                      GROUP BY ship_from_org_id, inventory_item_id) oo,
                     apps.mtl_parameters mp
               WHERE     alpha.organization_id = mp.organization_id
                     AND ship.inventory_item_id(+) = alpha.inventory_item_id
                     AND ship.ship_from_org_id(+) = alpha.organization_id
                     AND oo.inventory_item_id(+) = alpha.inventory_item_id
                     AND oo.ship_from_org_id(+) = alpha.organization_id
            -- and alpha.organization_id = nvl(p_organization_id, mp.organization_id)     --  Commented for BT Technology Team
            GROUP BY brand, warehouse, style,
                     color, sku, description,
                     --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                     item_type, --End modification for CR 92,on 29-Jul-15,BT Technology Team
                                intro_season, current_season,
                     series
            ORDER BY alpha.brand, alpha.warehouse, alpha.style,
                     alpha.color --, alpha.item_sort_order    --  Commented for BT Technology Team
                                ;

        l_as_of_date       DATE;
        l_ret_val          NUMBER := 0;
        l_sales_amt        NUMBER := 0;
        l_cnt              NUMBER := 0;
        l_line             VARCHAR2 (32000) := NULL;
        l_qtr_start_date   DATE;

        TYPE t_sqty IS RECORD
        (
            organization_id      DBMS_SQL.number_table,
            inventory_item_id    DBMS_SQL.number_table,
            primary_quantity     DBMS_SQL.number_table
        );

        tt_sales_qty       t_sqty;
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Format  ' || ' - ' || p_format);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Request ID  ' || ' - ' || gn_request_id);

        BEGIN
            IF p_time_zone = 'Yes'
            THEN
                SELECT quarter_start_date
                  INTO l_qtr_start_date
                  FROM apps.gl_periods
                 WHERE     NVL (
                               TO_DATE (p_as_of_date,
                                        'RRRR/MM/DD HH24:MI:SS'),
                               SYSDATE - 1) BETWEEN start_date
                                                AND end_date
                       AND period_set_name = 'DO_CY_CALENDAR';
            ELSE
                SELECT quarter_start_date
                  INTO l_qtr_start_date
                  FROM apps.gl_periods
                 WHERE     NVL (
                               TO_DATE (p_as_of_date,
                                        'RRRR/MM/DD HH24:MI:SS'),
                               SYSDATE - 1) BETWEEN start_date
                                                AND end_date
                       AND period_set_name = 'DO_FY_CALENDAR';
            END IF;
        END;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '------------------------------------------------------');
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'DELETE TBL- Start Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        /* -- Commented as per 4.4
     DELETE xxdo.xxdo_mtl_on_hand;

     DELETE xxdo.xxdo_so_closed_qty;

        DELETE xxdo.xxdo_so_open_qty;

        DELETE xxdo.xxdo_sales_qty; */

        --Start changes for 4.4
        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxdo_mtl_on_hand';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxdo_so_closed_qty';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxdo_so_open_qty';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxdo_sales_qty';

        --End changes for 4.4

        COMMIT;
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'DELETE TBL- End Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '------------------------------------------------------');

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Program Starts  '
            || ' - '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        -- apps.fnd_file.put_line (apps.fnd_file.LOG,
        --                        'AS OF DATE ' || ' - ' || l_as_of_date);
        -- SO Closed Shipping Units Insert--
        --------------------------------------------------------------------------------
        /*Start Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------
        --      IF p_organization_id IS NULL
        --      THEN
        --         FOR i IN cur_inv_org (p_region)
        --         LOOP
        --
        --         IF (p_time_zone = 'Local Time Zone')
        --            THEN
        --               l_as_of_date :=
        --                  TO_DATE (get_server_timezone (p_as_of_date,
        --                                                i.organization_id
        --                                               ),
        --                           'RRRR/MM/DD HH24:MI:SS'
        --                          );
        --            ELSE
        --               l_as_of_date := apps.fnd_date.canonical_to_date (p_as_of_date);
        --            END IF;
        --            INSERT INTO xxdo.xxdo_so_closed_qty
        --               SELECT ship_from_org_id, inventory_item_id,
        --                      ordered_quantity shipped_units
        --                 FROM apps.oe_order_lines_all
        --                WHERE open_flag = 'N'
        --                  AND source_type_code = 'INTERNAL'
        --                  AND line_category_code = 'ORDER'
        --                  AND actual_shipment_date IS NOT NULL
        --                  AND actual_shipment_date >= ADD_MONTHS (TRUNC (SYSDATE),
        --                                                          -12)
        --                  AND ship_from_org_id = i.organization_id;

        --            COMMIT;
        --         END LOOP;
        --      ELSE
        --
        --      IF (p_time_zone = 'Local Time Zone')
        --            THEN
        --               l_as_of_date :=
        --                  TO_DATE (get_server_timezone (p_as_of_date,
        --                                                p_organization_id
        --                                               ),
        --                           'RRRR/MM/DD HH24:MI:SS'
        --                          );
        --            ELSE
        --               l_as_of_date := apps.fnd_date.canonical_to_date (p_as_of_date);
        --            END IF;
        --         INSERT INTO xxdo.xxdo_so_closed_qty
        --            SELECT ship_from_org_id, inventory_item_id,
        --                   ordered_quantity shipped_units
        --              FROM apps.oe_order_lines_all
        --             WHERE open_flag = 'N'
        --               AND source_type_code = 'INTERNAL'
        --               AND line_category_code = 'ORDER'
        --               AND actual_shipment_date IS NOT NULL
        --               AND actual_shipment_date >= ADD_MONTHS (TRUNC (SYSDATE), -12)
        --               AND ship_from_org_id = p_organization_id;

        --         COMMIT;
        --      END IF;
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'INSERT TBL :xxdo_so_closed_qty - Start Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        INSERT INTO xxdo.xxdo_so_closed_qty
            SELECT /*+ parallel(oe_order_lines_all, 4) */
                   ship_from_org_id,                     --Added Hints for 4.4
                                     inventory_item_id, ordered_quantity shipped_units
              FROM apps.oe_order_lines_all
             WHERE     open_flag = 'N'
                   --                and inventory_item_id = 14504816
                   AND source_type_code = 'INTERNAL'
                   AND line_category_code = 'ORDER'
                   AND actual_shipment_date IS NOT NULL
                   AND actual_shipment_date >=
                       ADD_MONTHS (TRUNC (SYSDATE), -12)
                   /* --Commented as per 4.4
                   AND ship_from_org_id IN (SELECT organization_id
                                              FROM apps.org_organization_definitions
                                             WHERE     disable_date IS NULL
                                                   AND inventory_enabled_flag =
                                                          'Y'
                                                   AND organization_id =
                                                          NVL (
                                                             p_organization_id,
                                                             organization_id)
                                                   AND operating_unit IN (SELECT flex_value
                                                                            FROM apps.fnd_flex_values ffv,
                                                                                 apps.fnd_flex_value_sets fvs
                                                                           WHERE     ffv.flex_value_set_id =
                                                                                        fvs.flex_value_set_id
                                                                                 AND fvs.flex_value_set_name =
                                                                                        'DO_INVVAL_DUTY_REGION_ORGS'
                                                                                 AND ffv.parent_flex_value_low =
                                                                                        p_region
                                                                                 AND ffv.enabled_flag =
                                                                                        'Y'
                                                                                 AND ffv.summary_flag =
                                                                                        'N'));  */
                   --Start changes for 4.4
                   AND ship_from_org_id IN
                           (SELECT mp.organization_id
                              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl, apps.mtl_parameters mp
                             WHERE     fvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND fvs.flex_value_set_name LIKE
                                           'XXD_GIVR_COST_SNPS_ORG'
                                   AND NVL (TRUNC (ffvl.start_date_active),
                                            TRUNC (SYSDATE)) <=
                                       TRUNC (SYSDATE)
                                   AND NVL (TRUNC (ffvl.end_date_active),
                                            TRUNC (SYSDATE)) >=
                                       TRUNC (SYSDATE)
                                   AND ffvl.enabled_flag = 'Y'
                                   AND mp.organization_code = ffvl.flex_value
                                   AND ffvl.description =
                                       NVL (p_region, ffvl.description)
                                   AND mp.organization_id =
                                       NVL (p_organization_id,
                                            mp.organization_id));

        --End changes for 4.4

        COMMIT;
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'INSERT TBL :xxdo_so_closed_qty - End Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --------------------------------------------------------------------------------
        /*END Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------
        /* apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Insert into XXDO_SO_CLOSED_QTY completed' || ' - ' || SYSDATE);*/

        -- SO Open Units Insert--

        --------------------------------------------------------------------------------
        /*Start Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------
        --      IF p_organization_id IS NULL
        --      THEN
        --         FOR i IN cur_inv_org (p_region)
        --         LOOP
        --            IF (p_time_zone = 'Local Time Zone')
        --            THEN
        --               l_as_of_date :=
        --                  TO_DATE (get_server_timezone (p_as_of_date,
        --                                                i.organization_id
        --                                               ),
        --                           'RRRR/MM/DD HH24:MI:SS'
        --                          );
        --            ELSE
        --               l_as_of_date := apps.fnd_date.canonical_to_date (p_as_of_date);
        --            END IF;

        --            INSERT INTO xxdo.xxdo_so_open_qty
        --               SELECT ship_from_org_id, inventory_item_id, ordered_quantity,
        --                      unit_selling_price
        --                 FROM apps.oe_order_lines_all
        --                WHERE open_flag = 'Y'
        --                  AND source_type_code = 'INTERNAL'
        --                  AND line_category_code = 'ORDER'
        --                  AND schedule_ship_date >= TRUNC (SYSDATE) - 21
        --                  AND schedule_ship_date IS NOT NULL
        --                  AND shipment_priority_code = 'Standard'
        --                  AND ship_from_org_id = i.organization_id;

        --            COMMIT;
        --         END LOOP;
        --      ELSE
        --         IF (p_time_zone = 'Local Time Zone')
        --         THEN
        --            l_as_of_date :=
        --               TO_DATE (get_server_timezone (p_as_of_date, p_organization_id),
        --                        'RRRR/MM/DD HH24:MI:SS'
        --                       );
        --         ELSE
        --            l_as_of_date := apps.fnd_date.canonical_to_date (p_as_of_date);
        --         END IF;

        --         INSERT INTO xxdo.xxdo_so_open_qty
        --            SELECT ship_from_org_id, inventory_item_id, ordered_quantity,
        --                   unit_selling_price
        --              FROM apps.oe_order_lines_all
        --             WHERE open_flag = 'Y'
        --               AND source_type_code = 'INTERNAL'
        --               AND line_category_code = 'ORDER'
        --               AND schedule_ship_date >= TRUNC (SYSDATE) - 21
        --               AND schedule_ship_date IS NOT NULL
        --               AND shipment_priority_code = 'Standard'
        --               AND ship_from_org_id = p_organization_id;

        --         COMMIT;
        --      END IF;
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'INSERT TBL :xxdo_so_open_qty - Start Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        INSERT INTO xxdo.xxdo_so_open_qty
            SELECT /*+ parallel(oe_order_lines_all, 4) */
                   oola.ship_from_org_id,               -- Added Hints for 4.4
                                          oola.inventory_item_id, oola.ordered_quantity,
                   oola.unit_selling_price
              FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha -- Added as per CCR0009537
             WHERE     oola.open_flag = 'Y'
                   --          and inventory_item_id = 14504816
                   AND oola.source_type_code = 'INTERNAL'
                   AND oola.line_category_code = 'ORDER'
                   AND oola.schedule_ship_date >= TRUNC (SYSDATE) - 21
                   AND oola.schedule_ship_date IS NOT NULL
                   AND oola.shipment_priority_code = 'Standard'
                   -- Start of Change for CCR0009537
                   AND ooha.header_id = oola.header_id
                   AND ooha.org_id = oola.org_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.fnd_flex_values ffv, apps.fnd_flex_value_sets fvs
                             WHERE     1 = 1
                                   AND ffv.flex_value_set_id =
                                       fvs.flex_value_set_id
                                   AND fvs.flex_value_set_name =
                                       'XXD_INV_EXC_ORDER_TYPES_VS'
                                   AND ffv.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           ffv.start_date_active,
                                                           SYSDATE)
                                                   AND NVL (
                                                           ffv.end_date_active,
                                                           SYSDATE)
                                   AND ffv.flex_value = ooha.order_type_id)
                   -- end of Change for CCR0009537
                   /* --Commented as per 4.4
                   AND oola.ship_from_org_id IN (SELECT organization_id
               FROM apps.org_organization_definitions
                 WHERE 1=1
                AND disable_date IS NULL
                                                    AND inventory_enabled_flag = 'Y'
                                                   AND organization_id = NVL (p_organization_id,organization_id)
                                                   AND operating_unit IN (SELECT flex_value
                                                                            FROM apps.fnd_flex_values ffv,
                                                                                 apps.fnd_flex_value_sets fvs
                                                                           WHERE     ffv.flex_value_set_id =
                                                                                        fvs.flex_value_set_id
                                                                                 AND fvs.flex_value_set_name = 'DO_INVVAL_DUTY_REGION_ORGS'
                                                                                 AND ffv.parent_flex_value_low = p_region
                                                                                 AND ffv.enabled_flag = 'Y'
                                                                                 AND ffv.summary_flag ='N')); */
                   --Start changes for 4.4
                   AND oola.ship_from_org_id IN
                           (SELECT mp.organization_id
                              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl, apps.mtl_parameters mp
                             WHERE     fvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND fvs.flex_value_set_name LIKE
                                           'XXD_GIVR_COST_SNPS_ORG'
                                   AND NVL (TRUNC (ffvl.start_date_active),
                                            TRUNC (SYSDATE)) <=
                                       TRUNC (SYSDATE)
                                   AND NVL (TRUNC (ffvl.end_date_active),
                                            TRUNC (SYSDATE)) >=
                                       TRUNC (SYSDATE)
                                   AND ffvl.enabled_flag = 'Y'
                                   AND mp.organization_code = ffvl.flex_value
                                   AND ffvl.description =
                                       NVL (p_region, ffvl.description)
                                   AND mp.organization_id =
                                       NVL (p_organization_id,
                                            mp.organization_id));

        --End changes for 4.4

        COMMIT;
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'INSERT TBL :xxdo_so_open_qty - End Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --------------------------------------------------------------------------------
        /*End Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------
        /*apps.fnd_file.put_line (
           apps.fnd_file.LOG,
           'Insert into XXDO_SO_OPEN_QTY completed' || ' - ' || SYSDATE);*/

        --ONHAND table insert --

        --------------------------------------------------------------------------------
        /*Start Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------

        --      IF p_organization_id IS NULL
        --      THEN
        --         FOR i IN cur_inv_org (p_region)
        --         LOOP
        --            IF (p_time_zone = 'Local Time Zone')
        --            THEN
        --               l_as_of_date :=
        --                  TO_DATE (get_server_timezone (p_as_of_date,
        --                                                i.organization_id
        --                                               ),
        --                           'RRRR/MM/DD HH24:MI:SS'
        --                          );
        --            ELSE
        --               l_as_of_date := apps.fnd_date.canonical_to_date (p_as_of_date);
        --            END IF;

        --            INSERT INTO xxdo.xxdo_mtl_on_hand
        --                        (brand, organization_id, inventory_item_id,
        --                         intro_season, series, item_cost, total_units,
        --                         total_cost)
        --               SELECT   brand, organization_id, inventory_item_id,
        --                        intro_season, series, item_cost,
        --                        SUM (total_units) total_units,
        --                          SUM (NVL (total_units, 0))
        --                        * NVL (item_cost, 0) total_cost
        --                   FROM (SELECT   mc.segment1 AS brand, moq.organization_id,
        --                                  moq.inventory_item_id,
        --                                  mc.segment5 AS intro_season,
        --                                  mc.segment2 AS series,
        --                                  apps.xxdoget_item_cost
        --                                         ('ITEMCOST',
        --                                          moq.organization_id,
        --                                          moq.inventory_item_id,
        --                                          'N'
        --                                         ) AS item_cost,
        --                                  SUM
        --                                     (moq.transaction_quantity)
        --                                                               AS total_units
        --                             FROM apps.mtl_secondary_inventories sub_inv,
        --                                  apps.mtl_categories_b mc,
        --                                  apps.mtl_item_categories cat,
        --                                  apps.mtl_onhand_quantities moq
        --                            WHERE cat.organization_id = moq.organization_id
        --                              AND cat.category_set_id = 1
        --                              AND cat.inventory_item_id =
        --                                                         moq.inventory_item_id
        --                              AND mc.category_id = cat.category_id
        --                              AND sub_inv.organization_id =
        --                                                           moq.organization_id
        --                              AND sub_inv.secondary_inventory_name =
        --                                                         moq.subinventory_code
        --                              AND sub_inv.asset_inventory = 1
        --                              AND sub_inv.availability_type = 1
        --                              AND moq.organization_id = i.organization_id
        --                         GROUP BY mc.segment1,
        --                                  moq.organization_id,
        --                                  moq.inventory_item_id,
        --                                  mc.segment5,
        --                                  mc.segment2
        --                         UNION ALL
        --                         SELECT   mc.segment1 AS brand, mmt.organization_id,
        --                                  mmt.inventory_item_id,
        --                                  mc.segment5 AS intro_season,
        --                                  mc.segment2 AS series,
        --                                  apps.xxdoget_item_cost
        --                                         ('ITEMCOST',
        --                                          mmt.organization_id,
        --                                          mmt.inventory_item_id,
        --                                          'N'
        --                                         ) AS item_cost,
        --                                  -SUM (mmt.primary_quantity) AS total_units
        --                             FROM apps.mtl_secondary_inventories sub_inv,
        --                                  apps.mtl_categories_b mc,
        --                                  apps.mtl_item_categories cat,
        --                                  apps.mtl_material_transactions mmt
        --                            WHERE cat.organization_id = mmt.organization_id
        --                              AND cat.category_set_id = 1
        --                              AND cat.inventory_item_id =
        --                                                         mmt.inventory_item_id
        --                              AND mc.category_id = cat.category_id
        --                              AND sub_inv.organization_id =
        --                                                           mmt.organization_id
        --                              AND sub_inv.secondary_inventory_name =
        --                                                         mmt.subinventory_code
        --                              AND sub_inv.asset_inventory = 1
        --                              AND sub_inv.availability_type = 1
        --                              AND mmt.organization_id = i.organization_id
        --                              AND mmt.transaction_date >=
        --                                                NVL (l_as_of_date, SYSDATE)
        --                                                + 1
        --                         GROUP BY mc.segment1,
        --                                  mmt.organization_id,
        --                                  mmt.inventory_item_id,
        --                                  mc.segment5,
        --                                  mc.segment2)
        --               GROUP BY brand,
        --                        organization_id,
        --                        inventory_item_id,
        --                        intro_season,
        --                        series,
        --                        item_cost;

        --            COMMIT;
        --         END LOOP;
        --      ELSE
        --         IF (p_time_zone = 'Local Time Zone')
        --         THEN
        --            l_as_of_date :=
        --               TO_DATE (get_server_timezone (p_as_of_date, p_organization_id),
        --                        'RRRR/MM/DD HH24:MI:SS'
        --                       );
        --         ELSE
        --            l_as_of_date := apps.fnd_date.canonical_to_date (p_as_of_date);
        --         END IF;

        --         INSERT INTO xxdo.xxdo_mtl_on_hand
        --                     (brand, organization_id, inventory_item_id, intro_season,
        --                      series, item_cost, total_units, total_cost)
        --            SELECT   brand, organization_id, inventory_item_id, intro_season,
        --                     series, item_cost, SUM (total_units) total_units,
        --                       SUM (NVL (total_units, 0))
        --                     * NVL (item_cost, 0) total_cost
        --                FROM (SELECT   mc.segment1 AS brand, moq.organization_id,
        --                               moq.inventory_item_id,
        --                               mc.segment5 AS intro_season,
        --                               mc.segment2 AS series,
        --                               apps.xxdoget_item_cost
        --                                         ('ITEMCOST',
        --                                          moq.organization_id,
        --                                          moq.inventory_item_id,
        --                                          'N'
        --                                         ) AS item_cost,
        --                               SUM (moq.transaction_quantity) AS total_units
        --                          FROM apps.mtl_secondary_inventories sub_inv,
        --                               apps.mtl_categories_b mc,
        --                               apps.mtl_item_categories cat,
        --                               apps.mtl_onhand_quantities moq
        --                         WHERE cat.organization_id = moq.organization_id
        --                           AND cat.category_set_id = 1
        --                           AND cat.inventory_item_id = moq.inventory_item_id
        --                           AND mc.category_id = cat.category_id
        --                           AND sub_inv.organization_id = moq.organization_id
        --                           AND sub_inv.secondary_inventory_name =
        --                                                         moq.subinventory_code
        --                           AND sub_inv.asset_inventory = 1
        --                           AND sub_inv.availability_type = 1
        --                           AND moq.organization_id =
        --                                  NVL (p_organization_id, moq.organization_id)
        --                      GROUP BY mc.segment1,
        --                               moq.organization_id,
        --                               moq.inventory_item_id,
        --                               mc.segment5,
        --                               mc.segment2
        --                      UNION ALL
        --                      SELECT   mc.segment1 AS brand, mmt.organization_id,
        --                               mmt.inventory_item_id,
        --                               mc.segment5 AS intro_season,
        --                               mc.segment2 AS series,
        --                               apps.xxdoget_item_cost
        --                                         ('ITEMCOST',
        --                                          mmt.organization_id,
        --                                          mmt.inventory_item_id,
        --                                          'N'
        --                                         ) AS item_cost,
        --                               -SUM (mmt.primary_quantity) AS total_units
        --                          FROM apps.mtl_secondary_inventories sub_inv,
        --                               apps.mtl_categories_b mc,
        --                               apps.mtl_item_categories cat,
        --                               apps.mtl_material_transactions mmt
        --                         WHERE cat.organization_id = mmt.organization_id
        --                           AND cat.category_set_id = 1
        --                           AND cat.inventory_item_id = mmt.inventory_item_id
        --                           AND mc.category_id = cat.category_id
        --                           AND sub_inv.organization_id = mmt.organization_id
        --                           AND sub_inv.secondary_inventory_name =
        --                                                         mmt.subinventory_code
        --                           AND sub_inv.asset_inventory = 1
        --                           AND sub_inv.availability_type = 1
        --                           AND mmt.organization_id =
        --                                  NVL (p_organization_id, mmt.organization_id)
        --                           AND mmt.transaction_date >=
        --                                                NVL (l_as_of_date, SYSDATE)
        --                                                + 1
        --                      GROUP BY mc.segment1,
        --                               mmt.organization_id,
        --                               mmt.inventory_item_id,
        --                               mc.segment5,
        --                               mc.segment2)
        --            GROUP BY brand,
        --                     organization_id,
        --                     inventory_item_id,
        --                     intro_season,
        --                     series,
        --                     item_cost;

        --         COMMIT;
        --      END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'INSERT TBL :xxdo_mtl_on_hand - Start Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        INSERT INTO xxdo.xxdo_mtl_on_hand (brand, organization_id, inventory_item_id, intro_season, series, item_cost
                                           , total_units, total_cost)
              SELECT brand, organization_id, inventory_item_id,
                     intro_season, series, item_cost,
                     SUM (total_units) total_units, SUM (NVL (total_units, 0)) * NVL (item_cost, 0) total_cost
                FROM (  SELECT                                              --
                               get_item_detail (moq.inventory_item_id, moq.organization_id, 'BRAND'
                                                , NULL) brand,
                               --              mc.segment1 AS brand,
                               moq.organization_id,
                               moq.inventory_item_id,
                               --
                               get_item_detail (moq.inventory_item_id, moq.organization_id, 'INTRO_SEASON'
                                                , NULL) intro_season,
                               --                            mc.segment5 AS intro_season,
                               mc.segment3 AS series,
                               apps.xxdoget_item_cost ('ITEMCOST', moq.organization_id, moq.inventory_item_id
                                                       , 'N') AS item_cost,
                               SUM (moq.transaction_quantity) AS total_units
                          FROM apps.mtl_secondary_inventories sub_inv, apps.mtl_categories_b mc, apps.mtl_item_categories cat,
                               apps.mtl_onhand_quantities moq
                         WHERE     cat.organization_id = moq.organization_id
                               AND cat.category_set_id = 1
                               AND cat.inventory_item_id = moq.inventory_item_id
                               --                            and moq.inventory_item_id = 14504816
                               AND mc.category_id = cat.category_id
                               AND sub_inv.organization_id = moq.organization_id
                               AND sub_inv.secondary_inventory_name =
                                   moq.subinventory_code
                               AND sub_inv.asset_inventory = 1
                               --Start Changes by ANM
                               -- Commented as part of CCR0007484
                               /*and moq.date_received <=
                                        NVL (
                                           DECODE (
                                              p_time_zone,
                                              'Yes', TO_DATE (
                                                        get_server_timezone (
                                                           p_as_of_date,
                                                           moq.organization_id),
                                                        'RRRR/MM/DD HH24:MI:SS'),
                                              TO_DATE (p_as_of_date,
                                                       'RRRR/MM/DD HH24:MI:SS')),
                                           SYSDATE)*/
                               -- End of Change
                               --End Changes by ANM
                               --AND sub_inv.availability_type = 1 --Commented by BT Technology Team on 16-Nov-2015
                               /* --Commented for 4.4
                               AND moq.organization_id IN (SELECT organization_id
                                                             FROM apps.org_organization_definitions
                                                            WHERE     disable_date
                                                                         IS NULL
                                                                  AND inventory_enabled_flag =
                                                                         'Y'
                                                                  AND organization_id =
                                                                         NVL (
                                                                            p_organization_id,
                                                                            moq.organization_id)
                                                                  AND operating_unit IN (SELECT flex_value
                                                                                           FROM apps.fnd_flex_values ffv,
                                                                                                apps.fnd_flex_value_sets fvs
                                                                                          WHERE     ffv.flex_value_set_id =
                                                                                                       fvs.flex_value_set_id
                                                                                                AND fvs.flex_value_set_name =
                                                                                                       'DO_INVVAL_DUTY_REGION_ORGS'
                                                                                                AND ffv.parent_flex_value_low =
                                                                                                       p_region
                                                                                                AND ffv.enabled_flag =
                                                                                                       'Y'
                                                                                                AND ffv.summary_flag =
                                                                                                       'N')) */
                               --Start changes for 4.4
                               AND moq.organization_id IN
                                       (SELECT mp.organization_id
                                          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl, apps.mtl_parameters mp
                                         WHERE     fvs.flex_value_set_id =
                                                   ffvl.flex_value_set_id
                                               AND fvs.flex_value_set_name LIKE
                                                       'XXD_GIVR_COST_SNPS_ORG'
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.start_date_active),
                                                       TRUNC (SYSDATE)) <=
                                                   TRUNC (SYSDATE)
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.end_date_active),
                                                       TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND ffvl.enabled_flag = 'Y'
                                               AND mp.organization_code =
                                                   ffvl.flex_value
                                               AND ffvl.description =
                                                   NVL (p_region,
                                                        ffvl.description)
                                               AND mp.organization_id =
                                                   NVL (p_organization_id,
                                                        mp.organization_id))
                      --End changes for 4.4
                      GROUP BY mc.segment1, moq.organization_id, moq.inventory_item_id,
                               mc.segment5, mc.segment3
                      UNION ALL
                        SELECT /*+ full(MMT) */
                                  --Added Hint to increase performance for 4.4
                               get_item_detail (mmt.inventory_item_id, mmt.organization_id, 'BRAND'
                                                , NULL) brand,
                               --              mc.segment1 AS brand,
                               mmt.organization_id,
                               mmt.inventory_item_id,
                               --
                               get_item_detail (mmt.inventory_item_id, mmt.organization_id, 'INTRO_SEASON'
                                                , NULL) intro_season,
                               --                            mc.segment5 AS intro_season,
                               mc.segment3 AS series,
                               apps.xxdoget_item_cost ('ITEMCOST', mmt.organization_id, mmt.inventory_item_id
                                                       , 'N') AS item_cost,
                               -SUM (mmt.primary_quantity) AS total_units
                          FROM apps.mtl_secondary_inventories sub_inv, apps.mtl_categories_b mc, apps.mtl_item_categories cat,
                               apps.mtl_material_transactions mmt
                         WHERE     cat.organization_id = mmt.organization_id
                               AND cat.category_set_id = 1
                               AND cat.inventory_item_id = mmt.inventory_item_id
                               --                            and mmt.inventory_item_id = 14504816
                               AND mc.category_id = cat.category_id
                               AND sub_inv.organization_id = mmt.organization_id
                               AND sub_inv.secondary_inventory_name =
                                   mmt.subinventory_code
                               AND sub_inv.asset_inventory = 1
                               --AND sub_inv.availability_type = 1 --Commented by BT Technology Team on 16-Nov-2015
                               /* --Commented as per 4.4
                               AND mmt.organization_id IN (SELECT organization_id
                                                             FROM apps.org_organization_definitions
                                                            WHERE     disable_date
                                                                         IS NULL
                                                                  AND inventory_enabled_flag =
                                                                         'Y'
                                                                  AND organization_id =
                                                                         NVL (
                                                                            p_organization_id,
                                                                            mmt.organization_id)
                                                                  AND operating_unit IN (SELECT flex_value
                                                                                           FROM apps.fnd_flex_values ffv,
                                                                                                apps.fnd_flex_value_sets fvs
                                                                                          WHERE     ffv.flex_value_set_id =
                                                                                                       fvs.flex_value_set_id
                                                                                                AND fvs.flex_value_set_name =
                                                                                                       'DO_INVVAL_DUTY_REGION_ORGS'
                                                                                                AND ffv.parent_flex_value_low =
                                                                                                       p_region
                                                                                                AND ffv.enabled_flag =
                                                                                                       'Y'
                                                                                                AND ffv.summary_flag =
                                                                                                       'N')) */
                               --Start changes for 4.4
                               AND mmt.organization_id IN
                                       (SELECT mp.organization_id
                                          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl, apps.mtl_parameters mp
                                         WHERE     fvs.flex_value_set_id =
                                                   ffvl.flex_value_set_id
                                               AND fvs.flex_value_set_name LIKE
                                                       'XXD_GIVR_COST_SNPS_ORG'
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.start_date_active),
                                                       TRUNC (SYSDATE)) <=
                                                   TRUNC (SYSDATE)
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.end_date_active),
                                                       TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND ffvl.enabled_flag = 'Y'
                                               AND mp.organization_code =
                                                   ffvl.flex_value
                                               AND ffvl.description =
                                                   NVL (p_region,
                                                        ffvl.description)
                                               AND mp.organization_id =
                                                   NVL (p_organization_id,
                                                        mp.organization_id))
                               --End changes for 4.4
                               AND mmt.transaction_date >=
                                     NVL (
                                         DECODE (
                                             p_time_zone,
                                             'Yes', TO_DATE (
                                                        get_server_timezone (
                                                            p_as_of_date,
                                                            mmt.organization_id),
                                                        'RRRR/MM/DD HH24:MI:SS'),
                                             TO_DATE (p_as_of_date,
                                                      'RRRR/MM/DD HH24:MI:SS')),
                                         SYSDATE)
                                   + 1
                      GROUP BY mc.segment1, mmt.organization_id, mmt.inventory_item_id,
                               mc.segment5, mc.segment3)
            GROUP BY brand, organization_id, inventory_item_id,
                     intro_season, series, item_cost;

        COMMIT;
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'INSERT TBL :xxdo_mtl_on_hand - End Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --------------------------------------------------------------------------------
        /*End Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------
        /*apps.fnd_file.put_line (
           apps.fnd_file.LOG,
           'Insert into xxdo_mtl_on_hand completed' || ' - ' || SYSDATE);*/

        --     Sales Amount update
        --     if p_organization_id is null then
        --        For i IN cur_inv_org(P_REGION) Loop
        --            BEGIN
        --              OPEN c_sqty(l_as_of_date , l_qtr_start_date,i.ORGANIZATION_ID);
        --              LOOP
        --                FETCH c_sqty
        --                BULK COLLECT INTO tt_sales_qty.organization_id,
        --                       tt_sales_qty.inventory_item_id,
        --                       tt_sales_qty.primary_quantity LIMIT 10000;
        --
        --                FORALL i IN 1 .. tt_sales_qty.inventory_item_id.COUNT
        --                  UPDATE XXDO.XXDO_MTL_ON_HAND onhand
        --                     SET onhand.QTR_SALES_QTY = tt_sales_qty.primary_quantity(i)
        --                   WHERE onhand.organization_id = tt_sales_qty.organization_id(i)
        --                     AND onhand.inventory_item_id = tt_sales_qty.inventory_item_id(i);
        --                EXIT WHEN c_sqty%NOTFOUND;
        --              END LOOP;
        --             commit;
        --             close c_sqty;
        --            END;
        --
        --        End Loop;
        --     Else
        --          BEGIN
        --              OPEN c_sqty(l_as_of_date , l_qtr_start_date,p_organization_id);
        --              LOOP
        --                FETCH c_sqty
        --                BULK COLLECT INTO tt_sales_qty.organization_id,
        --                       tt_sales_qty.inventory_item_id,
        --                       tt_sales_qty.primary_quantity LIMIT 1000;
        --
        --                FORALL i IN 1 .. tt_sales_qty.inventory_item_id.COUNT
        --                  UPDATE XXDO.XXDO_MTL_ON_HAND onhand
        --                     SET onhand.QTR_SALES_QTY = tt_sales_qty.primary_quantity(i)
        --                   WHERE onhand.organization_id = tt_sales_qty.organization_id(i)
        --                     AND onhand.inventory_item_id = tt_sales_qty.inventory_item_id(i);
        --                EXIT WHEN c_sqty%NOTFOUND;
        --              END LOOP;
        --             commit;
        --            END;
        --     End if;

        --     Sales Amount Insert

        --BTDEV CHANGES END 12-Jan-2015

        --      IF p_organization_id IS NULL
        --      THEN
        --         FOR i IN cur_inv_org (p_region)
        --         LOOP
        --            IF (p_time_zone = 'Local Time Zone')
        --            THEN
        --               l_as_of_date :=
        --                  TO_DATE (get_server_timezone (p_as_of_date,
        --                                                i.organization_id
        --                                               ),
        --                           'RRRR/MM/DD HH24:MI:SS'
        --                          );
        --            ELSE
        --               l_as_of_date := apps.fnd_date.canonical_to_date (p_as_of_date);
        --            END IF;

        --            INSERT INTO xxdo.xxdo_sales_qty
        --               SELECT   mtl.organization_id, mtl.inventory_item_id,
        --                        SUM (mtl.primary_quantity) primary_quantity
        --                   FROM apps.mtl_material_transactions mtl,
        --                        xxdo.xxdo_mtl_on_hand onhand
        --                  WHERE mtl.organization_id = onhand.organization_id
        --                    AND mtl.inventory_item_id = onhand.inventory_item_id
        --                    AND mtl.transaction_type_id IN
        --                                                  (33, 37) --Sales and returns
        --                    AND mtl.transaction_date >= l_qtr_start_date
        --                    AND mtl.transaction_date < NVL (l_as_of_date, SYSDATE - 1)
        --                    AND mtl.organization_id = i.organization_id
        --               GROUP BY mtl.organization_id, mtl.inventory_item_id;

        --            COMMIT;
        --         END LOOP;
        --      ELSE
        --         IF (p_time_zone = 'Local Time Zone')
        --         THEN
        --            l_as_of_date :=
        --               TO_DATE (get_server_timezone (p_as_of_date, p_organization_id),
        --                        'RRRR/MM/DD HH24:MI:SS'
        --                       );
        --         ELSE
        --            l_as_of_date := apps.fnd_date.canonical_to_date (p_as_of_date);
        --         END IF;

        --         INSERT INTO xxdo.xxdo_sales_qty
        --            SELECT   mtl.organization_id, mtl.inventory_item_id,
        --                     SUM (mtl.primary_quantity) primary_quantity
        --                FROM apps.mtl_material_transactions mtl,
        --                     xxdo.xxdo_mtl_on_hand onhand
        --               WHERE mtl.organization_id = onhand.organization_id
        --                 AND mtl.inventory_item_id = onhand.inventory_item_id
        --                 AND mtl.transaction_type_id IN (33, 37)   --Sales and returns
        --                 AND mtl.transaction_date >= l_qtr_start_date
        --                 AND mtl.transaction_date < NVL (l_as_of_date, SYSDATE - 1)
        --                 AND mtl.organization_id = p_organization_id
        --            GROUP BY mtl.organization_id, mtl.inventory_item_id;

        --         COMMIT;
        --      END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'INSERT TBL :xxdo_sales_qty - Start Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        INSERT INTO xxdo.xxdo_sales_qty
              SELECT mtl.organization_id, mtl.inventory_item_id, SUM (mtl.primary_quantity) primary_quantity
                FROM apps.mtl_material_transactions mtl, xxdo.xxdo_mtl_on_hand onhand
               WHERE     mtl.organization_id = onhand.organization_id
                     AND mtl.inventory_item_id = onhand.inventory_item_id
                     --                  and mtl.inventory_item_id = 14504816
                     AND mtl.transaction_type_id IN (33, 37) --Sales and returns
                     AND mtl.transaction_date >= l_qtr_start_date
                     AND mtl.transaction_date <
                         NVL (
                             DECODE (
                                 p_time_zone,
                                 'Yes', TO_DATE (
                                            get_server_timezone (
                                                p_as_of_date,
                                                mtl.organization_id),
                                            'RRRR/MM/DD HH24:MI:SS'),
                                 TO_DATE (p_as_of_date,
                                          'RRRR/MM/DD HH24:MI:SS')),
                             SYSDATE - 1)
                     /* --Commented as per 4.4
                     AND mtl.organization_id IN (SELECT organization_id
                                                   FROM apps.org_organization_definitions
                                                  WHERE     disable_date IS NULL
                                                        AND inventory_enabled_flag =
                                                               'Y'
                                                        AND organization_id =
                                                               NVL (
                                                                  p_organization_id,
                                                                  organization_id)
                                                        AND operating_unit IN (SELECT flex_value
                                                                                 FROM apps.fnd_flex_values ffv,
                                                                                      apps.fnd_flex_value_sets fvs
                                                                                WHERE     ffv.flex_value_set_id =
                                                                                             fvs.flex_value_set_id
                                                                                      AND fvs.flex_value_set_name =
                                                                                             'DO_INVVAL_DUTY_REGION_ORGS'
                                                                                      AND ffv.parent_flex_value_low =
                                                                                             p_region
                                                                                      AND ffv.enabled_flag =
                                                                                             'Y'
                                                                                      AND ffv.summary_flag =
                                                                                             'N')) */
                     --Start changes for 4.4
                     AND mtl.organization_id IN
                             (SELECT mp.organization_id
                                FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl, apps.mtl_parameters mp
                               WHERE     fvs.flex_value_set_id =
                                         ffvl.flex_value_set_id
                                     AND fvs.flex_value_set_name LIKE
                                             'XXD_GIVR_COST_SNPS_ORG'
                                     AND NVL (TRUNC (ffvl.start_date_active),
                                              TRUNC (SYSDATE)) <=
                                         TRUNC (SYSDATE)
                                     AND NVL (TRUNC (ffvl.end_date_active),
                                              TRUNC (SYSDATE)) >=
                                         TRUNC (SYSDATE)
                                     AND ffvl.enabled_flag = 'Y'
                                     AND mp.organization_code = ffvl.flex_value
                                     AND ffvl.description =
                                         NVL (p_region, ffvl.description)
                                     AND mp.organization_id =
                                         NVL (p_organization_id,
                                              mp.organization_id))
            --End changes for 4.4
            GROUP BY mtl.organization_id, mtl.inventory_item_id;

        COMMIT;
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'INSERT TBL :xxdo_sales_qty - End Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --------------------------------------------------------------------------------
        /*End Changes by BT Technology Team on 12-JAN-2015*/
        --------------------------------------------------------------------------------
        --apps.fnd_file.put_line (
        --apps.fnd_file.LOG,
        --'Insert into XXDO_SALES_QTY completed' || ' - ' || SYSDATE);
        --  apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Update Sale Amount completed'||' - '|| sysdate);

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               ' Write OutFile - Start Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        -- Write Header Line
        l_line   :=
               'Brand'
            || CHR (9)
            || 'Org_Name'
            || CHR (9)
            || 'SKU'
            || CHR (9)
            || 'item_description'
            --Start modification for CR 92,on 29-Jul-15,BT Technology Team
            || CHR (9)
            || 'Color'
            || CHR (9)
            || 'item_type'
            --End modification for CR 92,on 29-Jul-15,BT Technology Team
            || CHR (9)
            || 'intro_season'
            || CHR (9)
            || 'current_season'
            || CHR (9)
            || 'item_category'
            || CHR (9)
            || 'landed_cost'
            || CHR (9)
            || 'total_cost'
            || CHR (9)
            || 'total_units'
            || CHR (9)
            || 'QTR_SALES_QTY'
            || CHR (9)
            --Start changes V4.1
            --         || 'under4'
            --         || CHR (9)
            --         || 'four'
            --         || CHR (9)
            --         || 'five'
            --         || CHR (9)
            --         || 'six'
            --         || CHR (9)
            --         || 'over6'
            || '0-3months'
            || CHR (9)
            || '3-6months'
            || CHR (9)
            || '6-12months'
            || CHR (9)
            || '12-18months'
            || CHR (9)
            || '18 plus months'
            --End changes V4.1
            || CHR (9)
            || 'Shipped Units ('
            || TO_CHAR (ADD_MONTHS (SYSDATE, -12), 'MM/DD/YYYY')
            || ' - '
            || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
            || ')'
            || CHR (9)
            || 'Open Order Units (> '
            || TO_CHAR (SYSDATE - 21, 'MM/DD/YYYY')
            || ')'
            || CHR (9)
            || 'Open Orders Amount (> '
            || TO_CHAR (SYSDATE - 21, 'MM/DD/YYYY')
            || ')';
        -- Commented by BT Technology Team as part of DEFCET#712 as per shahn confirmation
        --         || CHR (9)
        --         || 'Open KCO Units (> '
        --         || TO_CHAR (SYSDATE - 21, 'MM/DD/YYYY')
        --         || ')'
        --         || CHR (9)
        --         || 'Open KCO Amount (> '
        --         || TO_CHAR (SYSDATE - 21, 'MM/DD/YYYY');
        -- Write Header Line
        apps.fnd_file.put_line (apps.fnd_file.output, l_line);

        IF p_format = 'DETAIL'
        THEN
            FOR i IN c_det
            LOOP
                l_line   :=
                       i.brand
                    || CHR (9)
                    || i.org_name
                    || CHR (9)
                    || i.sku
                    || CHR (9)
                    || i.item_description
                    --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                    || CHR (9)
                    || i.color
                    || CHR (9)
                    || i.item_type
                    --End modification for CR 92,on 29-Jul-15,BT Technology Team
                    || CHR (9)
                    || i.intro_season
                    || CHR (9)
                    || i.current_season
                    || CHR (9)
                    || i.item_category
                    || CHR (9)
                    || TO_CHAR (i.landed_cost, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.total_cost, 'FML999,999,990.00')
                    || CHR (9)
                    || i.total_units
                    || CHR (9)
                    || i.qtr_sales_qty
                    || CHR (9)
                    --Start changes V4.1
                    --               || TO_CHAR (i.under4, 'FML999,999,990.00')
                    --               || CHR (9)
                    --               || TO_CHAR (i.four, 'FML999,999,990.00')
                    --               || CHR (9)
                    --               || TO_CHAR (i.five, 'FML999,999,990.00')
                    --               || CHR (9)
                    --               || TO_CHAR (i.six, 'FML999,999,990.00')
                    --               || CHR (9)
                    --               || TO_CHAR (i.over6, 'FML999,999,990.00')
                    || TO_CHAR (i.zero_to_3months, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.three_to_6months, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.six_to_12months, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.tweleve_to_18months, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.eighteen_plus_months, 'FML999,999,990.00')
                    --End Changes V4.1
                    || CHR (9)
                    || i.shipped_quantity
                    || CHR (9)
                    || i.so_open_quantity
                    || CHR (9)
                    || TO_CHAR (i.so_open_amount, 'FML999,999,990.00');
                -- Commented by BT Technology Team as part of DEFCET#712 as per shahn confirmation
                --               || CHR (9)
                --               || i.kco_open_quantity
                --               || CHR (9)
                --               || TO_CHAR (i.kco_open_amount, 'FML999,999,990.00');
                -- Write Detail Line
                apps.fnd_file.put_line (apps.fnd_file.output, l_line);
            END LOOP;
        ELSIF p_format = 'SUMMARY'
        THEN
            FOR i IN c_summ
            LOOP
                l_line   :=
                       i.brand
                    || CHR (9)
                    || i.org_name
                    || CHR (9)
                    || i.sku
                    || CHR (9)
                    || i.item_description
                    --Start modification for CR 92,on 29-Jul-15,BT Technology Team
                    || CHR (9)
                    || i.color
                    || CHR (9)
                    || i.item_type
                    --End modification for CR 92,on 29-Jul-15,BT Technology Team
                    || CHR (9)
                    || i.intro_season
                    || CHR (9)
                    || i.current_season
                    || CHR (9)
                    || i.item_category
                    || CHR (9)
                    || TO_CHAR (i.landed_cost, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.total_cost, 'FML999,999,990.00')
                    || CHR (9)
                    || i.total_units
                    || CHR (9)
                    || i.qtr_sales_qty
                    || CHR (9)
                    --Start changes V4.1
                    --               || TO_CHAR (i.under4, 'FML999,999,990.00')
                    --               || CHR (9)
                    --               || TO_CHAR (i.four, 'FML999,999,990.00')
                    --               || CHR (9)
                    --               || TO_CHAR (i.five, 'FML999,999,990.00')
                    --               || CHR (9)
                    --               || TO_CHAR (i.six, 'FML999,999,990.00')
                    --               || CHR (9)
                    --               || TO_CHAR (i.over6, 'FML999,999,990.00')
                    || TO_CHAR (i.zero_to_3months, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.three_to_6months, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.six_to_12months, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.twelve_to_18months, 'FML999,999,990.00')
                    || CHR (9)
                    || TO_CHAR (i.eighteen_plus_months, 'FML999,999,990.00')
                    --End Changes V4.1
                    || CHR (9)
                    || i.shipped_quantity
                    || CHR (9)
                    || i.so_open_quantity
                    || CHR (9)
                    || TO_CHAR (i.so_open_amount, 'FML999,999,990.00');
                -- Commented by BT Technology Team as part of DEFCET#712 as per shahn confirmation
                --               || CHR (9)
                --               || i.kco_open_quantity
                --               || CHR (9)
                --               || TO_CHAR (i.kco_open_amount, 'FML999,999,990.00');
                -- Write Detail Line
                apps.fnd_file.put_line (apps.fnd_file.output, l_line);
            END LOOP;
        END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               ' Write OutFile - End Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Program Ends  '
            || ' - '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            p_errbuf    := 'No Data Found' || SQLCODE || SQLERRM;
            p_retcode   := -1;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'NO_DATA_FOUND  ' || p_errbuf);
        WHEN INVALID_CURSOR
        THEN
            p_errbuf    := 'Invalid Cursor' || SQLCODE || SQLERRM;
            p_retcode   := -2;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'INVALID_CURSOR  ' || p_errbuf);
        WHEN TOO_MANY_ROWS
        THEN
            p_errbuf    := 'Too Many Rows' || SQLCODE || SQLERRM;
            p_retcode   := -3;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'TOO_MANY_ROWS  ' || p_errbuf);
        WHEN PROGRAM_ERROR
        THEN
            p_errbuf    := 'Program Error' || SQLCODE || SQLERRM;
            p_retcode   := -4;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'PROGRAM_ERROR  ' || p_errbuf);
        WHEN OTHERS
        THEN
            p_errbuf    := 'Unhandled Error' || SQLCODE || SQLERRM;
            p_retcode   := -5;
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'OTHERS  '
                || p_errbuf
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END;
END xxdoinv003_rep_pkg;
/
