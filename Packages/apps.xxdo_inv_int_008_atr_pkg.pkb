--
-- XXDO_INV_INT_008_ATR_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INV_INT_008_ATR_PKG"
IS
    /**********************************************************************************************************
     File Name    : xxdo_inv_int_008_atr_pkg.sql
     Created On   : 15-Feb-2012
     Created By   : Viswanath and Sivakumar Boothathan
     Purpose      : Package used to calculate the ATR data and insert into the custom table : xxdo_inv_int_008f
                    1. The logic to calculate the ATR is to find out the least of Free ATP + KCO and ATR
                    2. Once we get the ATR value, the values required to insert the table as per the RMS mapping
                       is inserted into the table.
                    3. The status flag "Y" is inserted into the custom table which confirms that the data has been
                       processed by EBS an sent to RMS. -- 142929

    ***********************************************************************************************************
    Modification History:
    Version   SCN#   By              Date             Comments
    1.0              Viswa and Siva    15-Feb-2012       NA
    1.1              C.M.Barath Kumar  12-Dec-2012       Added code fix to include zero quantities
                                                         Changed the code logic to  trigger multiple threads of concurrent program
    1.2              Murali Bachina    12-Feb-2013      Added logic in initial and incremental cursor to look for the item in RMS table
    1.3              Bharath Kumar      15-Jul-2014       Added logic for Japan ATR change #ENHC0012072
    1.4                BT Team         04-nov-2014      For BT dev Retrofit
    1.5                BT Team         25-May-2015      Performance improvement and attribute7 on txn type change
    1.6                BT Team         30-Nov-2015      Removing filter of pricelist Retail - US
    2.0                  BT Team            17-Feb-2016         Replacing the Instance Name from PROD to EBSPROD,wherever applicable.
    2.1                 Infosys        26-OCT-2016
    2.2              Siva B            09-MAR-2017      To Add a logic for China B-grade
    2.3              Gaurav Joshi      18-Apr-2020      Modified to for CCRCCR0007711; Added to bypass code execution
    2.4              Jayarajan A K     06-Jan-2021      Modified for CCR0008870 - Global Inventory Allocation Project
    3.0              Shivanshu Talwar  16-May-2021      Modified for Oracle 19C Upgrade - Integration will be happen through Business Event
    3.1              Jayarajan A K     18-Aug-2021      Modified for CCR0009520 - Performance Fix
    3.2              Aravind Kannuri   10-Mar-2022      Modified for CCR0009863 - RMS ATR feed to include SKUs had shipments in 48 hours
    ************************************************************************************************************
    Parameters: 1. Load Type
                2. Free ATP
                3. Reprocess
                4. Virtual warehouse ID
    *********************************************************************/
    ---------------------------------------------------------------------
    -- Procedure xxdo_inv_int_008_prc which is the main procedure which
    -- is used to select the ATR and insert into the custom table
    --------------------------------------------------------------------
    PROCEDURE xxdo_inv_int_008_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_vm_id IN VARCHAR2, p_load_type IN VARCHAR2, p_reprocess IN VARCHAR2, p_reprocess_from IN VARCHAR2, p_reprocess_to IN VARCHAR2, p_style IN VARCHAR2, p_color IN VARCHAR2
                                    , p_number_of_days IN NUMBER)
    IS
        --Start Changes v2.4
        lv_appl_rms             VARCHAR2 (10) := 'RMS';
        lv_appl_hbsft           VARCHAR2 (10) := 'HUBSOFT';

        --End Changes v2.4
        ------------------------------------------------------
        -- Cursor for loading the data during the initial load
        -- The cursor will retrive the virutal warehouse and
        -- the item id and also the ATR
        -- The ATR is calculated based on the least value between
        -- ATR and ATP. The ATR shouldn't be = 0 or less than zero
        -- hence the free ATR value is passed on to the RMS
        ------------------------------------------------------
        /*
        --Added by BT Technology Team V1.1 30Mar 2015
        CURSOR cur_xxdo_inv_008_ini_load (
           v_ebs_o_id   IN NUMBER,
           v_free_atp   IN VARCHAR2, --v3.1
           v_vm_id      IN NUMBER)
        IS
           SELECT v_vm_id virtual_warehouse_id,
                  inventory_item_id,
                  organization_id,
  -- Start change by BT team on 25-May-15 v1.5
  --                last_update_qty,
  -- End change by BT team on 25-May-15 v1.5
                  DECODE(v_free_atp, 'Y', --v3.1
                  GREATEST (
                       LEAST (
           --Start Changes v2.4
         apps.XXDO_SINGLE_ATP_RESULT_PKG.get_appl_atp (
            flv.attribute3,  --store_type
            data_set.inventory_item_id,
            data_set.organization_id,
            lv_appl_rms),
        /*
                          apps.XXDO_SINGLE_ATP_RESULT_PKG.given_dclass_1 (
                             flv.attribute4                       --demand_class
                                           ,
                             data_set.inventory_item_id,
                             data_set.organization_id), */
        --End Changes v2.4
        --Added  by BT  Team V1.1 25Mar 2015
                  /*
                  apps.do_inv_utils_pub.item_atr_quantity (
                     data_set.organization_id,
                     data_set.inventory_item_id))
             + NVL (
                  (SELECT SUM (
                               NVL (oola.ordered_quantity, 0)
                             - (  NVL (oola.shipped_quantity, 0)
                                + NVL (oola.cancelled_quantity, 0)))
                     FROM apps.oe_order_lines_all oola,
                          apps.oe_order_sources oos,
                          apps.oe_order_headers_all ooh
                    WHERE     1 = 1
                          AND oos.NAME = 'Retail'
                          AND ooh.header_id = oola.header_id
                          AND ooh.salesrep_id IN
                                 (SELECT salesrep_id
                                    FROM xxdo_ebs_rms_vw_map
                                   WHERE virtual_warehouse = p_vm_id)
                          AND oola.order_source_id =
                                 oos.order_source_id
                          AND NVL (oola.open_flag, 'N') = 'Y'
                          AND oola.ship_from_org_id =
                                 data_set.organization_id
                          AND oola.return_reason_code IS NULL
                          -- added by naga 14-FEB-2013
                          AND oola.inventory_item_id =
                                 data_set.inventory_item_id),
                  0),
             0)
,0) --v3.1
             quantity,                                --ebs_availability
          DECODE(v_free_atp, 'Y', 0, --v3.1
          GREATEST (
               LEAST (
--Start Changes v2.4
apps.XXDO_SINGLE_ATP_RESULT_PKG.get_no_free_atp (
   flv.attribute3,  --store_type
   data_set.inventory_item_id,
   data_set.organization_id,
   lv_appl_rms,
   lv_appl_hbsft),
/*
                  apps.xxdo_single_atp_result_pkg.given_dclass (
                     flv.attribute4                       --demand_class
                                   ,
                     data_set.inventory_item_id,
                     data_set.organization_id), */
        --End Changes v2.4
        --Added  by BT  Team V1.1 25Mar 2015
        /*
                                apps.do_inv_utils_pub.item_atr_quantity (
                                   data_set.organization_id,
                                   data_set.inventory_item_id))
                           + NVL (
                                (SELECT SUM (
                                             NVL (oola.ordered_quantity, 0)
                                           - (  NVL (oola.shipped_quantity, 0)
                                              + NVL (oola.cancelled_quantity, 0)))
                                   FROM apps.oe_order_lines_all oola,
                                        apps.oe_order_sources oos,
                                        apps.oe_order_headers_all ooh
                                  WHERE     1 = 1
                                        AND ooh.header_id = oola.header_id
                                        AND ooh.salesrep_id IN
                                               (SELECT salesrep_id
                                                  FROM xxdo_ebs_rms_vw_map
                                                 WHERE virtual_warehouse = p_vm_id)
                                        AND oos.NAME = 'Retail'
                                        AND oola.order_source_id =
                                               oos.order_source_id
                                        AND NVL (oola.open_flag, 'N') = 'Y'
                                        AND oola.ship_from_org_id =
                                               data_set.organization_id
                                        AND oola.return_reason_code IS NULL
                                        -- added by naga 14-FEB-2013
                                        AND oola.inventory_item_id =
                                               data_set.inventory_item_id),
                                0),
                           0)
                ) --v3.1
                            no_free_atp_quantity          --no free ATP temporary value
        -- Start change by BT team on 25-May-15 v1.5

        /*           FROM (  SELECT organization_id,
                                  inventory_item_id,
                                  MAX (last_update_qty) last_update_qty
                             FROM (SELECT v_ebs_o_id organization_id,
                                          TO_NUMBER (item_id) inventory_item_id,
                                          LAST_VALUE (
                                             xii.unit_qty)
                                          OVER (
                                             PARTITION BY xii.dc_dest_id, xii.item_id
                                             ORDER BY seq_no ASC
                                             ROWS BETWEEN UNBOUNDED PRECEDING
                                                  AND     UNBOUNDED FOLLOWING)
                                             last_update_qty
                                     FROM xxdo_inv_int_008 xii
                                    WHERE xii.dc_dest_id = v_vm_id
                                   UNION
                                   SELECT xatp_full.inv_organization_id organization_id,
                                          xatp_full.inventory_item_id,
                                          0 last_update_qty
                                     FROM xxd_master_atp_full_t xatp_full
                                    WHERE     xatp_full.application = 'RMS'
                                          AND TRUNC (available_date) = TRUNC (SYSDATE)
                                          AND inv_organization_id = v_ebs_o_id)
                         GROUP BY organization_id, inventory_item_id) data_set,
        */
        -- Start changes v3.1
        /*
                   FROM (  SELECT organization_id,
                                  inventory_item_id
                                  FROM MTL_SYSTEM_ITEMS_B
                                  WHERE organization_id = v_ebs_o_id) data_set,
        */
        /*
                   FROM (  SELECT DISTINCT xmaf.inv_organization_id organization_id,
                                  xmaf.inventory_item_id
                             FROM xxd_master_atp_full_t xmaf
                            WHERE xmaf.application = 'RMS'
                            --AND xmaf.store_type = flv.attribute3
                              AND xmaf.inv_organization_id = v_ebs_o_id) data_set,
        -- End changes v3.1
        --End change by BT team on 25-May-15 v1.5
                        fnd_lookup_values flv
                  WHERE     flv.lookup_type = 'XXD_EBS_RMS_MAP' --attr1(v_w_id),attr2(inv_org_id),attr3(channel),attr4(demand_class)
                        AND flv.enabled_flag = 'Y'
                        AND TRUNC (SYSDATE) BETWEEN NVL (START_DATE_ACTIVE, SYSDATE)
                                                AND NVL (END_DATE_ACTIVE, SYSDATE)
                        AND flv.language = USERENV ('LANG')
                        AND flv.attribute2 = data_set.organization_id
                        AND flv.attribute1 = v_vm_id
                        AND EXISTS
                               (SELECT 1
                                  FROM apps.xxdo_rms_item_master_mv
                                 WHERE     item =
                                              TO_CHAR (data_set.inventory_item_id)
                                       AND ROWNUM = 1)
        -- Start modification by BT Technology Team on v1.6
        /*
                        AND EXISTS
                               (SELECT 1                             --Added by BT Technology Team V1.1 30Mar 2015
                                  FROM qp.qp_list_headers_b qlhb,
                                       qp.qp_list_headers_tl qlht,
                                       qp.qp_list_lines qll,
                                       qp.qp_pricing_attributes qpa,
                                       apps.mtl_categories_b mc,
                                       apps.mtl_item_categories mic,
                                       apps.mtl_category_sets mcs,
                                       apps.xxd_common_items_v msib,
                                       apps.org_organization_definitions ood
                                 WHERE     qlht.list_header_id = qlhb.list_header_id
                                       AND qlht.LANGUAGE = USERENV ('LANG')
                                       AND qll.list_header_id = qlht.list_header_id
                                       AND qpa.list_line_id = qll.list_line_id
                                       AND msib.inventory_item_id =
                                              data_set.inventory_item_id   --condition
                                       AND qpa.list_header_id = qlht.list_header_id
                                       AND qpa.product_attribute =
                                              'PRICING_ATTRIBUTE2'
                                       AND qpa.product_attribute_context = 'ITEM'
                                       AND qpa.product_attr_value = mc.category_id
                                       AND mic.category_id = mc.category_id
                                       AND mc.structure_id = mcs.structure_id
                                       AND mic.category_set_id = mcs.category_set_id
                                        and  qlht.name = 'Retail - US'
                                        and mcs.category_set_name='OM Sales Category'
                                       AND mic.inventory_item_id =
                                              msib.inventory_item_id
                                       AND mic.organization_id = msib.organization_id
                                       AND ood.organization_code = 'MST'
                                       AND ood.organization_id = msib.organization_id
                                       AND msib.item_type != 'GENERIC'
                                       AND msib.customer_order_enabled_flag = 'Y'
                                       AND CASE
                                              WHEN INSTR (msib.curr_active_season,
                                                          ' ',
                                                          -1) < 1
                                              THEN
                                                 0
                                              ELSE
                                                 TO_NUMBER (
                                                    TRIM (
                                                       SUBSTR (
                                                          msib.curr_active_season,
                                                          INSTR (
                                                             msib.curr_active_season,
                                                             ' ',
                                                             -1))))
                                           END >= 2012)
        */
        -- Start changes v3.1
        /*
                        AND EXISTS
                               (SELECT 1
                               FROM apps.xxd_common_items_v msib
                                       WHERE msib.item_type != 'GENERIC'
                                       AND msib.inventory_item_id =
                                              data_set.inventory_item_id   --condition
                                       AND msib.master_org_flag = 'Y'
                                       AND msib.customer_order_enabled_flag = 'Y'
                                       AND CASE
                                              WHEN INSTR (msib.curr_active_season,
                                                          ' ',
                                                          -1) < 1
                                              THEN
                                                 0
                                              ELSE
                                                 TO_NUMBER (
                                                    TRIM (
                                                       SUBSTR (
                                                          msib.curr_active_season,
                                                          INSTR (
                                                             msib.curr_active_season,
                                                             ' ',
                                                             -1))))
                                           END >= 2012)
        */
        -- End changes v3.1
        -- End modification by BT Technology Team on v1.6
        --                                   ;

        --Start changes v3.1
        CURSOR cur_xxdo_inv_008_ini_load (v_ebs_o_id IN NUMBER, v_free_atp IN VARCHAR2, v_vm_id IN NUMBER)
        IS
            SELECT v_vm_id virtual_warehouse_id,
                   inventory_item_id,
                   inv_organization_id organization_id,
                   DECODE (
                       v_free_atp,
                       'Y', GREATEST (
                                  LEAST (
                                      apps.XXDO_SINGLE_ATP_RESULT_PKG.get_appl_atp (
                                          flv.attribute3,         --store_type
                                          xmaf.inventory_item_id,
                                          xmaf.inv_organization_id,
                                          lv_appl_rms),
                                      apps.do_inv_utils_pub.item_atr_quantity (
                                          xmaf.inv_organization_id,
                                          xmaf.inventory_item_id))
                                + NVL (
                                      (SELECT SUM (NVL (oola.ordered_quantity, 0) - (NVL (oola.shipped_quantity, 0) + NVL (oola.cancelled_quantity, 0)))
                                         FROM apps.oe_order_lines_all oola, apps.oe_order_sources oos, apps.oe_order_headers_all ooh
                                        WHERE     1 = 1
                                              AND oos.NAME = 'Retail'
                                              AND ooh.header_id =
                                                  oola.header_id
                                              AND ooh.salesrep_id IN
                                                      (SELECT salesrep_id
                                                         FROM xxdo_ebs_rms_vw_map
                                                        WHERE virtual_warehouse =
                                                              p_vm_id)
                                              AND oola.order_source_id =
                                                  oos.order_source_id
                                              AND NVL (oola.open_flag, 'N') =
                                                  'Y'
                                              AND oola.ship_from_org_id =
                                                  xmaf.inv_organization_id
                                              AND oola.return_reason_code
                                                      IS NULL
                                              AND oola.inventory_item_id =
                                                  xmaf.inventory_item_id),
                                      0),
                                0),
                       0)                                               --v3.1
                         quantity,                          --ebs_availability
                   DECODE (
                       v_free_atp,
                       'Y', 0,
                       GREATEST (
                             LEAST (
                                 apps.XXDO_SINGLE_ATP_RESULT_PKG.get_no_free_atp (
                                     flv.attribute3,              --store_type
                                     xmaf.inventory_item_id,
                                     xmaf.inv_organization_id,
                                     lv_appl_rms,
                                     lv_appl_hbsft),
                                 apps.do_inv_utils_pub.item_atr_quantity (
                                     xmaf.inv_organization_id,
                                     xmaf.inventory_item_id))
                           + NVL (
                                 (SELECT SUM (NVL (oola.ordered_quantity, 0) - (NVL (oola.shipped_quantity, 0) + NVL (oola.cancelled_quantity, 0)))
                                    FROM apps.oe_order_lines_all oola, apps.oe_order_sources oos, apps.oe_order_headers_all ooh
                                   WHERE     1 = 1
                                         AND ooh.header_id = oola.header_id
                                         AND ooh.salesrep_id IN
                                                 (SELECT salesrep_id
                                                    FROM xxdo_ebs_rms_vw_map
                                                   WHERE virtual_warehouse =
                                                         p_vm_id)
                                         AND oos.NAME = 'Retail'
                                         AND oola.order_source_id =
                                             oos.order_source_id
                                         AND NVL (oola.open_flag, 'N') = 'Y'
                                         AND oola.ship_from_org_id =
                                             xmaf.inv_organization_id
                                         AND oola.return_reason_code IS NULL
                                         AND oola.inventory_item_id =
                                             xmaf.inventory_item_id),
                                 0),
                           0)) no_free_atp_quantity
              FROM xxd_master_atp_full_t xmaf, fnd_lookup_values flv
             WHERE     xmaf.application = 'RMS'
                   AND xmaf.store_type = flv.attribute3
                   AND xmaf.inv_organization_id = v_ebs_o_id
                   AND flv.lookup_type = 'XXD_EBS_RMS_MAP'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (START_DATE_ACTIVE,
                                                    SYSDATE)
                                           AND NVL (END_DATE_ACTIVE, SYSDATE)
                   AND flv.language = USERENV ('LANG')
                   AND flv.attribute2 = xmaf.inv_organization_id
                   AND flv.attribute1 = v_vm_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.xxdo_rms_item_master_mv
                             WHERE     item =
                                       TO_CHAR (xmaf.inventory_item_id)
                                   AND ROWNUM = 1);

        CURSOR cur_ini_additional_load (v_ebs_o_id IN NUMBER, v_free_atp IN VARCHAR2, v_vm_id IN NUMBER)
        IS
            SELECT v_vm_id virtual_warehouse_id,
                   inventory_item_id,
                   organization_id,
                   DECODE (
                       v_free_atp,
                       'Y', GREATEST (
                                  LEAST (
                                      apps.XXDO_SINGLE_ATP_RESULT_PKG.get_appl_atp (
                                          flv.attribute3,         --store_type
                                          data_set.inventory_item_id,
                                          data_set.organization_id,
                                          lv_appl_rms),
                                      apps.do_inv_utils_pub.item_atr_quantity (
                                          data_set.organization_id,
                                          data_set.inventory_item_id))
                                + NVL (
                                      (SELECT SUM (NVL (oola.ordered_quantity, 0) - (NVL (oola.shipped_quantity, 0) + NVL (oola.cancelled_quantity, 0)))
                                         FROM apps.oe_order_lines_all oola, apps.oe_order_sources oos, apps.oe_order_headers_all ooh
                                        WHERE     1 = 1
                                              AND oos.NAME = 'Retail'
                                              AND ooh.header_id =
                                                  oola.header_id
                                              AND ooh.salesrep_id IN
                                                      (SELECT salesrep_id
                                                         FROM xxdo_ebs_rms_vw_map
                                                        WHERE virtual_warehouse =
                                                              p_vm_id)
                                              AND oola.order_source_id =
                                                  oos.order_source_id
                                              AND NVL (oola.open_flag, 'N') =
                                                  'Y'
                                              AND oola.ship_from_org_id =
                                                  data_set.organization_id
                                              AND oola.return_reason_code
                                                      IS NULL
                                              AND oola.inventory_item_id =
                                                  data_set.inventory_item_id),
                                      0),
                                0),
                       0) quantity,                         --ebs_availability
                   DECODE (
                       v_free_atp,
                       'Y', 0,
                       GREATEST (
                             LEAST (
                                 apps.XXDO_SINGLE_ATP_RESULT_PKG.get_no_free_atp (
                                     flv.attribute3,              --store_type
                                     data_set.inventory_item_id,
                                     data_set.organization_id,
                                     lv_appl_rms,
                                     lv_appl_hbsft),
                                 apps.do_inv_utils_pub.item_atr_quantity (
                                     data_set.organization_id,
                                     data_set.inventory_item_id))
                           + NVL (
                                 (SELECT SUM (NVL (oola.ordered_quantity, 0) - (NVL (oola.shipped_quantity, 0) + NVL (oola.cancelled_quantity, 0)))
                                    FROM apps.oe_order_lines_all oola, apps.oe_order_sources oos, apps.oe_order_headers_all ooh
                                   WHERE     1 = 1
                                         AND ooh.header_id = oola.header_id
                                         AND ooh.salesrep_id IN
                                                 (SELECT salesrep_id
                                                    FROM xxdo_ebs_rms_vw_map
                                                   WHERE virtual_warehouse =
                                                         p_vm_id)
                                         AND oos.NAME = 'Retail'
                                         AND oola.order_source_id =
                                             oos.order_source_id
                                         AND NVL (oola.open_flag, 'N') = 'Y'
                                         AND oola.ship_from_org_id =
                                             data_set.organization_id
                                         AND oola.return_reason_code IS NULL
                                         AND oola.inventory_item_id =
                                             data_set.inventory_item_id),
                                 0),
                           0)) no_free_atp_quantity --no free ATP temporary value
              FROM (SELECT v_ebs_o_id organization_id, TO_NUMBER (item_id) inventory_item_id
                      FROM xxdo.xxdo_inv_int_008_archive xia
                     WHERE     xia.dc_dest_id = v_vm_id
                           AND unit_qty > 0
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdo_inv_int_008_archive xia1
                                     WHERE     xia1.item_id = xia.item_id
                                           AND xia1.dc_dest_id =
                                               xia.dc_dest_id
                                           AND xia1.creation_date >
                                               xia.creation_date)
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdo_inv_int_008 xii
                                     WHERE     xii.item_id = xia.item_id
                                           AND xii.dc_dest_id =
                                               xia.dc_dest_id)) data_set,
                   fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_EBS_RMS_MAP'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (START_DATE_ACTIVE,
                                                    SYSDATE)
                                           AND NVL (END_DATE_ACTIVE, SYSDATE)
                   AND flv.language = USERENV ('LANG')
                   AND flv.attribute2 = data_set.organization_id
                   AND flv.attribute1 = v_vm_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.xxdo_rms_item_master_mv
                             WHERE     item =
                                       TO_CHAR (data_set.inventory_item_id)
                                   AND ROWNUM = 1);

        --End changes v3.1

        -- Commented by BT Technology Team V1.1 30Mar 2015
        /*CURSOR cur_xxdo_inv_008_ini_load (
           v_ebs_o_id          IN NUMBER,
           v_kco_header_id     IN NUMBER,
           pn_number_of_days   IN NUMBER)
        IS
           SELECT atr.virtual_warehouse_id virtual_warehouse_id,
                  atr.inventory_item_id inventory_item_id,
                  atr.quantity quantity,
                  atr.quantity1 no_free_atp_quantity,
                  atr.sku sku,
                  atr.item_description item_description,
                  atr.atr1 atr_qty,
                  atr.atp atp
             FROM (  SELECT msi.organization_id || '01' virtual_warehouse_id,
                            msi.inventory_item_id inventory_item_id,
                            ------------------------------------------------------------------------------------------------------------------------------
                            -- Added By Sivakumar Boothathan For ATR Changes, removing the KCO Calculation from the ATR Calculation
                            ------------------------------------------------------------------------------------------------------------------------------
                            --least(sum(nvl(ohq.quantity,0)+nvl(demand.quantity,0)+nvl(open_allocation.quantity,0)),(nvl(sum(atp_kco.quantity),0)+nvl(apps.do_atp_utils_pub.single_atp_result (ohq.inventory_item_id,v_ebs_o_id),0)+nvl(sum(open_allocation.quantity),0))) Quantity,
                            --least(sum(nvl(ohq.quantity,0)+nvl(demand.quantity,0)+nvl(open_allocation.quantity,0)),(nvl(sum(atp_kco.quantity),0)+nvl(sum(open_allocation.quantity),0))) quantity1,
                            ------------------------------------------------------------------------------------------------------------------------------
                            -- End Of Comment
                            -------------------------------------------------------------------------------------------------------------------------------
                            -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
                            -- Including the function, which will get the KCO header based on the outlet, concept and then the minium of ATP and ATR will be sent over to RMS
                            -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
                            LEAST (
                               SUM (
                                    NVL (ohq.quantity, 0)
                                  + NVL (DEMAND.quantity, 0)
                                  + NVL (open_allocation.quantity, 0)),
                               (  NVL (
  --                             apps.do_atp_utils_pub.single_atp_result (
  --                                        msi.inventory_item_id,
  --                                        v_ebs_o_id,
  --                                        TRUNC (SYSDATE),
  --                                        'Y',
  --                                        xxdo_rms_kco_008_atr_fnc (
  --                                           v_ebs_o_id,
  --                                           msi.inventory_item_id,
  --                                           p_vm_id),
  --                                        'N')
                                          25,
                                       0)
                                + NVL (SUM (open_allocation.quantity), 0)))
                               quantity,
                            LEAST (
                               SUM (
                                    NVL (ohq.quantity, 0)
                                  + NVL (DEMAND.quantity, 0)
                                  + NVL (open_allocation.quantity, 0)),
                               (NVL (SUM (open_allocation.quantity), 0)))
                               quantity1,
                            --     msi.segment1                 --Starting commented by BT Technology Team on 03/12/2014
                             -- || '-'
                              --|| msi.segment2
                              --|| '-'
                              --|| msi.segment3 sku,
                          --msi.description item_description,
                            --Ending commented by BT Technology Team on 03/12/2014
                            msi.item_number sku, --Added by BT Technology Team on 03/12/2014
                            msi.item_description item_description, --Added by BT Technology Team on 03/12/2014
                            SUM (
                                 NVL (ohq.quantity, 0)
                               + NVL (DEMAND.quantity, 0)
                               + NVL (open_allocation.quantity, 0))
                               atr1,
                              ---------------------------------------------------------------------------------------------------------------------------
                              -- Commenting out the function which takes the KCO into account
                              ---------------------------------------------------------------------------------------------------------------------------
                              NVL (
  --                            apps.do_atp_utils_pub.single_atp_result (
  --                                    msi.inventory_item_id,
  --                                    v_ebs_o_id,
  --                                    TRUNC (SYSDATE),
  --                                    'Y',
  --                                    xxdo_rms_kco_008_atr_fnc (
  --                                       v_ebs_o_id,
  --                                       msi.inventory_item_id,
  --                                       p_vm_id),
  --                                    'N')
                                      25,
                                   0)
                            + NVL (SUM (open_allocation.quantity), 0)
                               atp
                       FROM (  SELECT xxer.virtual_warehouse virtual_warehouse_id,
                                      moq.inventory_item_id inventory_item_id,
                                      NVL (SUM (transaction_quantity), 0) quantity
                                 FROM apps.mtl_onhand_quantities moq,
                                      apps.mtl_secondary_inventories msi,
                                      xxdo_ebs_rms_vw_map xxer
                                WHERE     moq.subinventory_code(+) =
                                             msi.secondary_inventory_name
                                      AND moq.organization_id(+) =
                                             msi.organization_id
                                      AND moq.organization_id = xxer.ORGANIZATION
                                      AND moq.organization_id = v_ebs_o_id
                                      AND xxer.virtual_warehouse = p_vm_id
                                      AND msi.reservable_type = '1'
                                      AND NVL (UPPER (xxer.channel), 'OUTLET') =
                                             'OUTLET'
                             GROUP BY xxer.virtual_warehouse,
                                      moq.inventory_item_id) ohq,
                            (  SELECT xxer.virtual_warehouse virtual_warehouse_id,
                                      mtd.inventory_item_id inventory_item_id,
                                      -NVL (
                                          (  NVL (SUM (mtd.primary_uom_quantity),
                                                  0)
                                           - NVL (SUM (mtd.completed_quantity), 0)),
                                          0)
                                         quantity
                                 FROM mtl_demand mtd,
                                      xxdo_ebs_rms_vw_map xxer,
                                      mtl_secondary_inventories msi
                                WHERE     mtd.parent_demand_id IS NOT NULL
                                      AND mtd.primary_uom_quantity >
                                             mtd.completed_quantity
                                      AND mtd.organization_id = xxer.ORGANIZATION
                                      AND msi.secondary_inventory_name(+) =
                                             mtd.subinventory
                                      AND msi.organization_id(+) =
                                             mtd.organization_id
                                      AND mtd.organization_id = v_ebs_o_id
                                      AND xxer.virtual_warehouse = p_vm_id
                                      AND NVL (UPPER (xxer.channel), 'OUTLET') =
                                             'OUTLET'
                             GROUP BY xxer.virtual_warehouse,
                                      mtd.inventory_item_id) DEMAND,
                            ----------------------------------------------------------------------------------
                            -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                            ----------------------------------------------------------------------------------
                            (  SELECT xxer.virtual_warehouse virtual_warehouse_id,
                                      ool.inventory_item_id inventory_item_id,
                                        NVL (SUM (ool.ordered_quantity), 0)
                                      - (  NVL (SUM (ool.shipped_quantity), 0)
                                         + NVL (SUM (ool.cancelled_quantity), 0))
                                         quantity
                                 FROM apps.oe_order_lines_all ool,
                                      apps.oe_order_sources oos,
                                      xxdo_ebs_rms_vw_map xxer,
                                      apps.oe_order_headers_all ooh
                                WHERE     ool.order_source_id = oos.order_source_id
                                      AND oos.NAME = 'Retail'
                                      AND ooh.header_id = ool.header_id
                                      AND xxer.virtual_warehouse = p_vm_id
                                      AND ooh.salesrep_id IN
                                             (SELECT salesrep_id
                                                FROM xxdo_ebs_rms_vw_map
                                               WHERE virtual_warehouse = p_vm_id)
                                      AND ool.ship_from_org_id = xxer.ORGANIZATION
                                      AND NVL (ool.open_flag, 'N') = 'Y'
                                      AND ool.ship_from_org_id = v_ebs_o_id
                                      AND NVL (UPPER (xxer.channel), 'OUTLET') =
                                             'OUTLET'
                                      AND ool.return_reason_code IS NULL
                             -- added by naga 14-FEB-2013
                             GROUP BY xxer.virtual_warehouse,
                                      ool.inventory_item_id) open_allocation,
                            ----------------------------------------------------------------------------------
                            -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                            ----------------------------------------------------------------------------------
                            -- apps.mtl_system_items msi,                                     --commented by BT Technology team on 3/12/2014
                            apps.xxd_common_items_v msi, --Added by BT Technology team on 3/12/2014
                            (  SELECT xxer.virtual_warehouse virtual_warehouse_id,
                                      dkl.inventory_item_id inventory_item_id,
                                      SUM (dkl.current_quantity) quantity
                                 FROM do_kco.do_kco_header dkh,
                                      do_kco.do_kco_line dkl,
                                      xxdo_ebs_rms_vw_map xxer
                                WHERE     dkl.enabled_flag = 1
                                      AND dkl.open_flag = 1
                                      AND dkl.atp_flag = 1
                                      AND dkl.scheduled_quantity > 0
                                      AND dkh.kco_header_id = dkl.kco_header_id
                                      AND dkl.organization_id = xxer.ORGANIZATION
                                      AND dkh.enabled_flag = 1
                                      AND dkh.open_flag = 1
                                      AND dkh.atp_flag = 1
                                      AND xxer.virtual_warehouse = p_vm_id
                                      --and    dkh.kco_header_id = v_kco_header_id
                                      AND dkh.salesrep_id IN
                                             (SELECT salesrep_id
                                                FROM xxdo_ebs_rms_vw_map
                                               WHERE ORGANIZATION = v_ebs_o_id)
                                      AND dkl.organization_id = v_ebs_o_id
                                      AND NVL (UPPER (xxer.channel), 'OUTLET') =
                                             'OUTLET'
                                      AND TRUNC (dkl.kco_schedule_date) <=
                                             TRUNC (SYSDATE) + pn_number_of_days
                             GROUP BY xxer.virtual_warehouse,
                                      dkl.inventory_item_id) atp_kco
                      WHERE     ohq.virtual_warehouse_id =
                                   DEMAND.virtual_warehouse_id(+)
                            AND ohq.inventory_item_id =
                                   DEMAND.inventory_item_id(+)
                            AND msi.organization_id = v_ebs_o_id
                            -- For Testing The XML
                            AND ohq.inventory_item_id(+) = msi.inventory_item_id
                            AND atp_kco.virtual_warehouse_id(+) =
                                   ohq.virtual_warehouse_id
                            AND atp_kco.inventory_item_id(+) =
                                   ohq.inventory_item_id
                            --and   msi.inventory_item_status_code = 'Active'
                            --and   msi.attribute13 is not null
                            --and   msi.attribute11 is not null
                            ----------------------------------------------------------------------------------
                            -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                            ----------------------------------------------------------------------------------
                            AND ohq.virtual_warehouse_id =
                                   open_allocation.virtual_warehouse_id(+)
                            AND ohq.inventory_item_id =
                                   open_allocation.inventory_item_id(+)
                            ----------------------------------------------------------------------------------
                            -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                            ----------------------------------------------------------------------------------
                            /* AND UPPER (TRIM (msi.attribute11)) NOT LIKE '%I'                           --starting commented by BT Technology Team on 3/12/2014
                             AND msi.segment1 IN (
                                    SELECT DISTINCT msi.segment1
                                               FROM mtl_system_items msi,
                                                    mtl_item_categories mic,
                                                    mtl_categories mc,
                                                    mtl_category_sets mcs
                                              WHERE mic.inventory_item_id =
                                                                msi.inventory_item_id
                                                AND mic.organization_id =
                                                                  msi.organization_id
                                                AND msi.organization_id = 7
                                                AND mic.category_id = mc.category_id
                                                AND mic.category_set_id =
                                                                  mcs.category_set_id
                                                AND mc.structure_id =
                                                                     mcs.structure_id
                                                AND mcs.category_set_id = 1
                                                AND msi.segment3 <> 'ALL'
                                                -- AND   MC.SEGMENT1='UGG'
                                                AND UPPER (TRIM (mc.segment2)) <>
                                                                             'SAMPLE'
                                                --AND   MSI.INVENTORY_ITEM_STATUS_CODE='Active'
                                                AND msi.segment1 NOT LIKE 'S%L'
                                                AND msi.segment1 NOT LIKE 'S%R'
                                                AND msi.attribute13 IS NOT NULL
                                                AND msi.attribute11 IS NOT NULL)*/
                                                      /*
--Ending commented by BT Technology Team on 3/12/2014
AND UPPER (TRIM (msi.upc_code)) NOT LIKE '%I' --starting Added by BT Technology team on 3/12/2014
AND msi.style_number IN
       (SELECT DISTINCT msi.style_number
          FROM xxd_common_items_v msi
         WHERE     msi.item_type <> 'GENERIC'
               AND UPPER (TRIM (msi.department)) <>
                      'SAMPLE'
               AND msi.style_number NOT LIKE 'S%L'
               AND msi.style_number NOT LIKE 'S%R'
               AND msi.size_scale_id IS NOT NULL
               AND msi.upc_code IS NOT NULL) --Ending Added by BT Technology team on 3/12/2014
AND msi.inventory_item_id IN
       (SELECT DISTINCT msib.inventory_item_id
          FROM qp_pricing_attributes qpa,
               qp_list_lines qll,
               qp_list_headers qlh,
               mtl_categories_b mc,
               mtl_category_sets mcs,
               mtl_item_categories mic,
               --      mtl_system_items_b msib                                                     --commented by BT Technology Team on 3/12/2014
               xxd_common_items_v msib --Added by BT Technology Team on 3/12/2014
         WHERE     qpa.list_line_id =
                      qll.list_line_id
               AND qll.list_header_id =
                      qlh.list_header_id
               AND mic.inventory_item_id =
                      msib.inventory_item_id
               AND mic.organization_id =
                      msib.organization_id
               AND mc.structure_id = mcs.structure_id
               AND qpa.product_attribute =
                      'PRICING_ATTRIBUTE2'
               AND qpa.product_attr_value =
                      mc.category_id
               AND qpa.product_attr_value =
                      TO_CHAR (mc.category_id)
               AND mic.category_id = mc.category_id
               AND mic.category_set_id =
                      mcs.category_set_id
               --  AND msib.organization_id = 7                                                   --commented by BT Technology Team on 3/12/2014
               --and msib.inventory_item_status_code = 'Active'
               AND msib.organization_id IN
                      (SELECT ood.ORGANIZATION_ID
                         FROM fnd_lookup_values flv,
                              org_organization_definitions ood
                        WHERE     lookup_type =
                                     'XXD_1206_INV_ORG_MAPPING'
                              AND lookup_code = 7
                              AND flv.attribute1 =
                                     ood.ORGANIZATION_CODE
                              AND language =
                                     USERENV ('LANG'))
               AND qpa.product_attribute_context =
                      'ITEM'
               /*                and msib.segment1=msi.segment1
                               and msib.organization_id=msi.organization_id */
                                                                                       /*
                        AND qlh.NAME = 'Retail - US'
                        AND mcs.category_set_name =
                               'OM Sales Category')
--  AND mcs.category_set_name = 'Styles')                                          -- --commented by BT Technology Team on 3/12/2014
/*and msi.inventory_item_id in (select distinct(inventory_item_id) from XXDOINV006_INT
where item_type = 'SKU') */
                           /*
--and msi.segment1||'-'||msi.segment2||'-'||msi.segment3 = '5803-CHE-10'
GROUP BY msi.organization_id || '01',
         msi.inventory_item_id,
         /*     msi.segment1
           || '-'
           || msi.segment2
           || '-'
           || msi.segment3,
           msi.description) atr*/
                                        /*
                msi.item_number,
                msi.item_description) atr
WHERE     NVL (atr.quantity, -99) >= 0
      --and atr.inventory_item_id in (100241,4979665  )
      AND EXISTS
             (SELECT 1
                FROM apps.xxdo_rms_item_master_mv
               --rms13prod.item_master@RMSPROD
               WHERE     item = TO_CHAR (atr.inventory_item_id)
                     AND ROWNUM = 1)-- and   rownum <= 2000;
                     */

        ------------------------------------------------------
        -- Cursor for loading the data during the incremental load
        ------------------------------------------------------
        /* cursor cur_xxdo_inv_008_inc_load(v_ebs_o_id in number,
                                          v_item_id in number,
                                          pn_number_of_days in number)
         is
             select atr.virtual_warehouse_id virtual_warehouse_id,
                    atr.inventory_item_id    inventory_item_id,
                    atr.quantity             quantity,
                    atr.quantity1            No_Free_ATP_Quantity,
                    atr.sku                  SKU,
                    atr.item_description     Item_Description,
                    atr.atr1                 ATR_QTY,
                    atr.atp                  ATP
             from (select msi.organization_id||'01' Virtual_Warehouse_ID,
                   msi.inventory_item_id Inventory_Item_ID,
                   ------------------------------------------------------------------------------------------------------------------------------
                   -- Added By Sivakumar Boothathan For ATR Changes, removing the KCO Calculation from the ATR Calculation
                   ------------------------------------------------------------------------------------------------------------------------------
                   --least(sum(nvl(ohq.quantity,0)+nvl(demand.quantity,0)+nvl(open_allocation.quantity,0)),(nvl(sum(atp_kco.quantity),0)+nvl(apps.do_atp_utils_pub.single_atp_result (ohq.inventory_item_id,v_ebs_o_id),0)+nvl(sum(open_allocation.quantity),0))) Quantity,
                   --least(sum(nvl(ohq.quantity,0)+nvl(demand.quantity,0)+nvl(open_allocation.quantity,0)),(nvl(sum(atp_kco.quantity),0)+nvl(sum(open_allocation.quantity),0))) quantity1,
                   ------------------------------------------------------------------------------------------------------------------------------
                   -- End Of Comment
                   -------------------------------------------------------------------------------------------------------------------------------
                   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
                   -- Including the function, which will get the KCO header based on the outlet, concept and then the minium of ATP and ATR will be sent over to RMS
                   -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
                   least(sum(nvl(ohq.quantity,0)+nvl(demand.quantity,0)+nvl(open_allocation.quantity,0)),(nvl(apps.do_atp_utils_pub.single_atp_result (msi.inventory_item_id,v_ebs_o_id,trunc(sysdate),'Y',xxdo_rms_kco_008_atr_fnc(v_ebs_o_id,msi.inventory_item_id),'N'),0)+nvl(sum(open_allocation.quantity),0))) Quantity,
                   least(sum(nvl(ohq.quantity,0)+nvl(demand.quantity,0)+nvl(open_allocation.quantity,0)),(nvl(sum(open_allocation.quantity),0))) quantity1,
                    msi.description          Item_Description,
                    msi.segment1||'-'||msi.segment2||'-'||msi.segment3 SKU,
   sum(nvl(ohq.quantity,0)+nvl(demand.quantity,0)+nvl(open_allocation.quantity,0)) ATR1,
   nvl(apps.do_atp_utils_pub.single_atp_result (msi.inventory_item_id,v_ebs_o_id,trunc(sysdate),'Y',xxdo_rms_kco_008_atr_fnc(v_ebs_o_id,msi.inventory_item_id),'N'),0)+nvl(sum(open_allocation.quantity),0) ATP
            from (select xxer.virtual_warehouse                 Virtual_Warehouse_ID,
                         moq.inventory_item_id                      inventory_item_id,
                        nvl(sum(transaction_quantity),0)              Quantity
                  from apps.mtl_onhand_quantities moq,
                       apps.mtl_secondary_inventories msi,
                       xxdo_ebs_rms_vw_map xxer
                  where moq.subinventory_code(+) = msi.secondary_inventory_name
                  and   moq.organization_id(+) = msi.organization_id
                  and   moq.organization_id = xxer.organization
                  and   msi.reservable_type = '1'
                  and   moq.organization_id = v_ebs_o_id
                  and   moq.inventory_item_id = v_item_id
                 and   nvl(upper(xxer.channel),'OUTLET') = 'OUTLET'
                  group by xxer.virtual_warehouse,
                           moq.inventory_item_id
                 ) OHQ,
                (select xxer.virtual_warehouse                   Virtual_Warehouse_ID  ,
                        mtd.inventory_item_id                   inventory_item_id ,
                        -nvl((nvl(sum(mtd.primary_uom_quantity),0) - nvl(sum(mtd.completed_quantity),0)), 0) Quantity
                 from   mtl_demand mtd,
                        xxdo_ebs_rms_vw_map xxer,
                        mtl_secondary_inventories msi
                where   mtd.parent_demand_id is not null
                and   mtd.primary_uom_quantity > mtd.completed_quantity
                and   mtd.organization_id = xxer.organization
                and   msi.secondary_inventory_name(+) = mtd.subinventory
                and   msi.organization_id(+) = mtd.organization_id
                and   mtd.organization_id = v_ebs_o_id
                and   mtd.inventory_item_id = v_item_id
                and   nvl(upper(xxer.channel),'OUTLET') = 'OUTLET'
                group by xxer.virtual_warehouse,mtd.inventory_item_id
                )Demand,
                ----------------------------------------------------------------------------------
                -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                ----------------------------------------------------------------------------------
                (select xxer.virtual_warehouse                   Virtual_Warehouse_ID  ,
                        ool.inventory_item_id                   inventory_item_id ,
                        nvl(sum(ool.ordered_quantity),0) - (nvl(sum(ool.shipped_quantity),0)+nvl(sum(ool.cancelled_quantity),0)) Quantity
                 from   apps.oe_order_lines_all ool,
                        apps.oe_order_sources   oos,
                        xxdo_ebs_rms_vw_map xxer
                where   ool.order_source_id = oos.order_source_id
                and     oos.name = 'Retail'
                and     ool.ship_from_org_id = xxer.organization
                and     nvl(ool.open_flag,'N') = 'Y'
                and     ool.ship_from_org_id = v_ebs_o_id
                and     ool.inventory_item_id = v_item_id
                and   nvl(upper(xxer.channel),'OUTLET') = 'OUTLET'
                group by xxer.virtual_warehouse,ool.inventory_item_id
                ) Open_allocation,
                ----------------------------------------------------------------------------------
                -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                ----------------------------------------------------------------------------------
                apps.mtl_system_items msi,
                (select xxer.virtual_warehouse Virtual_Warehouse_ID,
                       dkl.inventory_item_id Inventory_Item_ID,
                       sum(dkl.current_quantity) Quantity
                from   do_kco.do_kco_header dkh,
                       do_kco.do_kco_line dkl,
                       xxdo_ebs_rms_vw_map xxer
                where  dkl.enabled_flag = 1
                and    dkl.open_flag = 1
                and    dkl.atp_flag = 1
                and    dkl.scheduled_quantity > 0
                and    dkh.kco_header_id = dkl.kco_header_id
                and    dkl.organization_id = xxer.organization
                and    dkh.enabled_flag = 1
                and    dkh.open_flag = 1
                and    dkh.atp_flag = 1
                and    trunc(dkl.kco_schedule_date) <= trunc(sysdate) + pn_number_of_days
                and    dkl.organization_id = v_ebs_o_id
                and    dkl.inventory_item_id = v_item_id
                and    dkh.salesrep_id in (select salesrep_id
                                           from xxdo_ebs_rms_vw_map
                                           where organization = v_ebs_o_id)
                and    nvl(upper(xxer.channel),'OUTLET') = 'OUTLET'
                group by xxer.virtual_warehouse,
                         dkl.inventory_item_id) ATP_KCO
                where ohq.virtual_warehouse_id = demand.virtual_warehouse_id(+)
                and   ohq.inventory_item_id = demand.inventory_item_id(+)
                and   msi.organization_id = v_ebs_o_id
                and   ohq.inventory_item_id(+) = msi.inventory_item_id
                and   atp_kco.virtual_warehouse_id(+) = ohq.virtual_warehouse_id
                and   atp_kco.inventory_item_id(+) = ohq.inventory_item_id
                ----------------------------------------------------------------------------------
                -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                ----------------------------------------------------------------------------------
                and   ohq.virtual_warehouse_id = open_allocation.virtual_warehouse_id(+)
                and   ohq.inventory_item_id = open_allocation.inventory_item_id(+)
                ----------------------------------------------------------------------------------
                -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                ----------------------------------------------------------------------------------
   --             and   msi.inventory_item_status_code = 'Active'
                --and   msi.attribute13 is not null
                --and   msi.attribute11 is not null
                and   UPPER(TRIM(msi.attribute11)) not like '%I'
                and   msi.segment1 in(SELECT DISTINCT MSI.SEGMENT1
                                     FROM MTL_SYSTEM_ITEMS MSI,
                                          MTL_ITEM_CATEGORIES MIC,
                                          MTL_CATEGORIES MC,
                                          MTL_CATEGORY_SETS MCS
                                    WHERE MIC.INVENTORY_ITEM_ID =MSI.INVENTORY_ITEM_ID
                                    AND   MIC.ORGANIZATION_ID=MSI.ORGANIZATION_ID
                                    AND   MSI.ORGANIZATION_ID=7
                                    AND   MIC.CATEGORY_ID=MC.CATEGORY_ID
                                    AND   MIC.CATEGORY_SET_ID=MCS.CATEGORY_SET_ID
                                    AND   MC.STRUCTURE_ID=MCS.STRUCTURE_ID
                                    AND   MCS.CATEGORY_SET_ID=1
                                    AND   MSI.SEGMENT3 <> 'ALL'
   --                                 AND   MC.SEGMENT1='UGG'
                                    AND   UPPER(TRIM(MC.SEGMENT2)) <> 'SAMPLE'
   --                                 AND   MSI.INVENTORY_ITEM_STATUS_CODE='Active'
                                    AND   MSI.SEGMENT1 NOT LIKE 'S%L'
                                    AND   MSI.SEGMENT1 NOT LIKE 'S%R'
                                    AND   MSI.ATTRIBUTE13 IS NOT NULL
                                    AND   MSI.ATTRIBUTE11 IS NOT NULL)
                 and  msi.inventory_item_id in (select distinct msib.inventory_item_id
   from qp_pricing_attributes qpa,
          qp_list_lines qll,
          qp_list_headers qlh,
          mtl_categories_b mc,
          mtl_category_sets mcs,
          mtl_item_categories mic,
          mtl_system_items_b msib
    where qpa.list_line_id =qll.list_line_id
                   and qll.list_header_id=qlh.list_header_id
                   and mic.inventory_item_id = msib.inventory_item_id
                   and mic.organization_id   = msib.organization_id
                   and mc.structure_id   = mcs.structure_id
                   and qpa.product_attribute = 'PRICING_ATTRIBUTE2'
                   and qpa.product_attr_value = mc.category_id
                   and qpa.product_attr_value = to_char(mc.category_id)
                   and mic.category_id    = mc.category_id
                   and mic.category_set_id = mcs.category_set_id
                   and msib.organization_id = 7
   --                and msib.inventory_item_status_code = 'Active'
                   and qpa.product_attribute_context ='ITEM'
   --              and msib.segment1=msi.segment1
     --              and msib.organization_id=msi.organization_id */
        /*   --            and  qlh.name = 'Retail - US'
             --          and mcs.category_set_name='Styles'
       --)
       --and msi.inventory_item_id in (select distinct(inventory_item_id) from XXDOINV006_INT
       --where item_type = 'SKU')
                     --and msi.segment1||'-'||msi.segment2||'-'||msi.segment3 = '5803-CHE-10'
         --            group by msi.organization_id||'01' ,
           --          msi.inventory_item_id,
             --        msi.segment1||'-'||msi.segment2||'-'||msi.segment3,
               --      msi.description)ATR
                 --    where nvl(atr.quantity,-99) >= 0
                   --  and atr.inventory_item_id = v_item_id
             --;
             */

        --Start Changes for 3.2
        --To get SKUs which had shipments in last 48 hours from ASN to process SKU ATR again to RMS
        CURSOR cur_eligible_asn_008_load (v_ebs_o_id IN NUMBER, v_free_atp IN VARCHAR2, v_vm_id IN NUMBER
                                          , v_asn_fetch_days IN NUMBER)
        IS
            SELECT v_vm_id virtual_warehouse_id,
                   inventory_item_id,
                   organization_id,
                   DECODE (
                       v_free_atp,
                       'Y', GREATEST (
                                  LEAST (
                                      apps.XXDO_SINGLE_ATP_RESULT_PKG.get_appl_atp (
                                          flv.attribute3,         --store_type
                                          asn_data_set.inventory_item_id,
                                          asn_data_set.organization_id,
                                          lv_appl_rms),
                                      apps.do_inv_utils_pub.item_atr_quantity (
                                          asn_data_set.organization_id,
                                          asn_data_set.inventory_item_id))
                                + NVL (
                                      (SELECT SUM (NVL (oola.ordered_quantity, 0) - (NVL (oola.shipped_quantity, 0) + NVL (oola.cancelled_quantity, 0)))
                                         FROM apps.oe_order_lines_all oola, apps.oe_order_sources oos, apps.oe_order_headers_all ooh
                                        WHERE     1 = 1
                                              AND oos.NAME = 'Retail'
                                              AND ooh.header_id =
                                                  oola.header_id
                                              AND ooh.salesrep_id IN
                                                      (SELECT salesrep_id
                                                         FROM xxdo_ebs_rms_vw_map
                                                        WHERE virtual_warehouse =
                                                              p_vm_id)
                                              AND oola.order_source_id =
                                                  oos.order_source_id
                                              AND NVL (oola.open_flag, 'N') =
                                                  'Y'
                                              AND oola.ship_from_org_id =
                                                  asn_data_set.organization_id
                                              AND oola.return_reason_code
                                                      IS NULL
                                              AND oola.inventory_item_id =
                                                  asn_data_set.inventory_item_id),
                                      0),
                                0),
                       0) quantity,                         --ebs_availability
                   DECODE (
                       v_free_atp,
                       'Y', 0,
                       GREATEST (
                             LEAST (
                                 apps.XXDO_SINGLE_ATP_RESULT_PKG.get_no_free_atp (
                                     flv.attribute3,              --store_type
                                     asn_data_set.inventory_item_id,
                                     asn_data_set.organization_id,
                                     lv_appl_rms,
                                     lv_appl_hbsft),
                                 apps.do_inv_utils_pub.item_atr_quantity (
                                     asn_data_set.organization_id,
                                     asn_data_set.inventory_item_id))
                           + NVL (
                                 (SELECT SUM (NVL (oola.ordered_quantity, 0) - (NVL (oola.shipped_quantity, 0) + NVL (oola.cancelled_quantity, 0)))
                                    FROM apps.oe_order_lines_all oola, apps.oe_order_sources oos, apps.oe_order_headers_all ooh
                                   WHERE     1 = 1
                                         AND ooh.header_id = oola.header_id
                                         AND ooh.salesrep_id IN
                                                 (SELECT salesrep_id
                                                    FROM xxdo_ebs_rms_vw_map
                                                   WHERE virtual_warehouse =
                                                         p_vm_id)
                                         AND oos.NAME = 'Retail'
                                         AND oola.order_source_id =
                                             oos.order_source_id
                                         AND NVL (oola.open_flag, 'N') = 'Y'
                                         AND oola.ship_from_org_id =
                                             asn_data_set.organization_id
                                         AND oola.return_reason_code IS NULL
                                         AND oola.inventory_item_id =
                                             asn_data_set.inventory_item_id),
                                 0),
                           0)) no_free_atp_quantity --no free ATP temporary value
              FROM (SELECT DISTINCT v_ebs_o_id organization_id, xsi.item_id inventory_item_id
                      FROM xxdo.xxdo_007_ship_int_stg xsi
                     WHERE     1 = 1
                           AND TO_NUMBER (xsi.virtual_warehouse) = v_vm_id
                           AND xsi.creation_date >
                               SYSDATE - NVL (v_asn_fetch_days, 2)
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxdo_inv_int_008 xii
                                     WHERE     xii.item_id = xsi.item_id
                                           AND NVL (xii.status, 'N') = 'N'
                                           AND xii.processed_flag IS NULL
                                           AND xii.dc_dest_id =
                                               TO_NUMBER (
                                                   xsi.virtual_warehouse)))
                   asn_data_set,
                   fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_EBS_RMS_MAP'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (START_DATE_ACTIVE,
                                                    SYSDATE)
                                           AND NVL (END_DATE_ACTIVE, SYSDATE)
                   AND flv.language = USERENV ('LANG')
                   AND flv.attribute2 = asn_data_set.organization_id
                   AND flv.attribute1 = v_vm_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.xxdo_rms_item_master_mv
                             WHERE     item =
                                       TO_CHAR (
                                           asn_data_set.inventory_item_id)
                                   AND ROWNUM = 1);

        --End Changes for 3.2

        CURSOR cur_xxdo_inv_008_inc_load (v_ebs_o_id IN NUMBER, v_vm_id IN NUMBER, v_free_atp IN VARCHAR2
                                          ,                             --v3.1
                                            v_full_refresh IN VARCHAR2)
        IS
            SELECT organization_id,
                   inventory_item_id,
                   last_update_qty,
                   DECODE (
                       v_free_atp,
                       'Y',                                             --v3.1
                            GREATEST (
                                  LEAST (
                                      --                        apps.do_atp_utils_pub.single_atp_result ( -- Input 3/24 - Add ATP Logic and remove the hard coding 25
                                      --                           data_set.inventory_item_id,
                                      --                           data_set.organization_id,
                                      --                           TRUNC (SYSDATE),
                                      --                           'Y',
                                      --                           apps.xxdo_rms_kco_008_atr_fnc (
                                      --                              data_set.organization_id,
                                      --                              data_set.inventory_item_id,
                                      --                              v_vm_id),
                                      --                           'N')
                                      -- 25,                                                                                    --Commented  by BT  Team V1.1 25Mar 2015
                                      --Start Changes v2.4
                                      apps.XXDO_SINGLE_ATP_RESULT_PKG.get_appl_atp (
                                          flv.attribute3,         --store_type
                                          data_set.inventory_item_id,
                                          data_set.organization_id,
                                          lv_appl_rms),
                                      /*
                                      apps.XXDO_SINGLE_ATP_RESULT_PKG.given_dclass_1 (
                                         flv.attribute4                       --demand_class
                                                       ,
                                         data_set.inventory_item_id,
                                         data_set.organization_id), */
                                      --Added  by BT  Team V1.1 25Mar 2015
                                      --End Changes v2.4
                                      apps.do_inv_utils_pub.item_atr_quantity (
                                          data_set.organization_id,
                                          data_set.inventory_item_id))
                                + NVL (
                                      (SELECT SUM (NVL (oola.ordered_quantity, 0) - (NVL (oola.shipped_quantity, 0) + NVL (oola.cancelled_quantity, 0)))
                                         FROM apps.oe_order_lines_all oola, apps.oe_order_sources oos, apps.oe_order_headers_all ooh
                                        WHERE     1 = 1
                                              AND oos.NAME = 'Retail'
                                              AND ooh.header_id =
                                                  oola.header_id
                                              AND ooh.salesrep_id IN
                                                      (SELECT salesrep_id
                                                         FROM xxdo_ebs_rms_vw_map
                                                        WHERE virtual_warehouse =
                                                              p_vm_id)
                                              AND oola.order_source_id =
                                                  oos.order_source_id
                                              AND NVL (oola.open_flag, 'N') =
                                                  'Y'
                                              AND oola.ship_from_org_id =
                                                  data_set.organization_id
                                              AND oola.return_reason_code
                                                      IS NULL
                                              -- added by naga 14-FEB-2013
                                              AND oola.inventory_item_id =
                                                  data_set.inventory_item_id),
                                      0),
                                0),
                       0)                                               --v3.1
                         ebs_availability,
                   DECODE (
                       v_free_atp,
                       'Y', 0,                                          --v3.1
                       GREATEST (
                             LEAST (
                                 --                        apps.do_atp_utils_pub.single_atp_result ( -- Input 3/24 - Add ATP Logic and remove the hard coding 25
                                 --                           data_set.inventory_item_id,
                                 --                           data_set.organization_id,
                                 --                           TRUNC (SYSDATE),
                                 --                           'Y',
                                 --                           -1,
                                 --                           'N')
                                 -- 25,                                                                     -- Commented  by BT  Team V1.1 25Mar 2015
                                 --Start Changes v2.4
                                 apps.XXDO_SINGLE_ATP_RESULT_PKG.get_no_free_atp (
                                     flv.attribute3,              --store_type
                                     data_set.inventory_item_id,
                                     data_set.organization_id,
                                     lv_appl_rms,
                                     lv_appl_hbsft),
                                 /*
                                 apps.xxdo_single_atp_result_pkg.given_dclass (
                                    flv.attribute4                       --demand_class
                                                  ,
                                    data_set.inventory_item_id,
                                    data_set.organization_id), */
                                 -- Added  by BT  Team V1.1 25Mar 2015
                                 --End Changes v2.4
                                 apps.do_inv_utils_pub.item_atr_quantity (
                                     data_set.organization_id,
                                     data_set.inventory_item_id))
                           + NVL (
                                 (SELECT SUM (NVL (oola.ordered_quantity, 0) - (NVL (oola.shipped_quantity, 0) + NVL (oola.cancelled_quantity, 0)))
                                    FROM apps.oe_order_lines_all oola, apps.oe_order_sources oos, apps.oe_order_headers_all ooh
                                   WHERE     1 = 1
                                         AND ooh.header_id = oola.header_id
                                         AND ooh.salesrep_id IN
                                                 (SELECT salesrep_id
                                                    FROM xxdo_ebs_rms_vw_map
                                                   WHERE virtual_warehouse =
                                                         p_vm_id)
                                         AND oos.NAME = 'Retail'
                                         AND oola.order_source_id =
                                             oos.order_source_id
                                         AND NVL (oola.open_flag, 'N') = 'Y'
                                         AND oola.ship_from_org_id =
                                             data_set.organization_id
                                         AND oola.return_reason_code IS NULL
                                         -- added by naga 14-FEB-2013
                                         AND oola.inventory_item_id =
                                             data_set.inventory_item_id),
                                 0),
                           0))                                          --v3.1
                              no_free_atp_quantity --no free ATP temporary value
              FROM (  SELECT organization_id, inventory_item_id, MAX (last_update_qty) last_update_qty
                        FROM (SELECT v_ebs_o_id organization_id, TO_NUMBER (item_id) inventory_item_id, LAST_VALUE (xii.unit_qty) OVER (PARTITION BY xii.dc_dest_id, xii.item_id ORDER BY seq_no ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) last_update_qty
                                FROM xxdo_inv_int_008 xii
                               WHERE xii.dc_dest_id = v_vm_id
                              UNION
                              /*SELECT DISTINCT -- Input 3/24 - Change this logic to derive organization_id, inventory_item_id from Full load table where application = RMS
                                     ms.organization_id,
                                     apps.msc_to_mtl_iid (ms.inventory_item_id)
                                        inventory_item_id,
                                     0 last_update_qty
                                FROM apps.msc_supplies ms
                               WHERE ms.organization_id = v_ebs_o_id*/
                              -- Commented by BT Team V1.1 25Mar 2015
                              SELECT xatp_full.inv_organization_id organization_id, xatp_full.inventory_item_id, 0 last_update_qty
                                FROM xxd_master_atp_full_t xatp_full
                               WHERE     xatp_full.application = 'RMS'
                                     AND TRUNC (available_date) =
                                         TRUNC (SYSDATE)
                                     AND inv_organization_id = v_ebs_o_id) -- Added by BT Team V1.1 25Mar 2015
                    GROUP BY organization_id, inventory_item_id) data_set --Start of Changes by BT  Team V1.1 30Mar 2015
                                                                         ,
                   fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXD_EBS_RMS_MAP'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (START_DATE_ACTIVE,
                                                    SYSDATE)
                                           AND NVL (END_DATE_ACTIVE, SYSDATE)
                   AND flv.language = USERENV ('LANG')
                   AND flv.attribute2 = data_set.organization_id
                   AND flv.attribute1 = v_vm_id
                   --End of Changes by BT  Team V1.1 30Mar 2015
                   AND EXISTS
                           (SELECT 1
                              FROM apps.xxdo_rms_item_master_mv
                             --item_master@RMSTEST
                             --FROM rms13prod.item_master@RMSPROD
                             WHERE     item =
                                       TO_CHAR (data_set.inventory_item_id)
                                   AND ROWNUM = 1)
                   -- and data_set.inventory_item_id in (100241,4979665  )
                   AND (   NVL (v_full_refresh, 'N') = 'Y'
                        OR last_update_qty !=
                           GREATEST (
                                 LEAST (
                                     --                                   apps.do_atp_utils_pub.single_atp_result (
                                     --                                      data_set.inventory_item_id,
                                     --                                      data_set.organization_id,
                                     --                                      TRUNC (
                                     --                                         SYSDATE),
                                     --                                      'Y',
                                     --                                      apps.xxdo_rms_kco_008_atr_fnc (
                                     --                                         data_set.organization_id,
                                     --                                         data_set.inventory_item_id,
                                     --                                         v_vm_id),
                                     --                                      'N')
                                     -- 25,                                                                    --Commented  by BT  Team V1.1 25Mar 2015
                                     --Start Changes v2.4
                                     apps.XXDO_SINGLE_ATP_RESULT_PKG.get_appl_atp (
                                         flv.attribute3,          --store_type
                                         data_set.inventory_item_id,
                                         data_set.organization_id,
                                         lv_appl_rms),
                                     /*
                                    apps.XXDO_SINGLE_ATP_RESULT_PKG.given_dclass_1 (
                                       flv.attribute4,
                                       data_set.inventory_item_id,
                                       data_set.organization_id), */
                                     --Added  by BT  Team V1.1 25Mar 2015
                                     --End Changes v2.4
                                     apps.do_inv_utils_pub.item_atr_quantity (
                                         data_set.organization_id,
                                         data_set.inventory_item_id))
                               + NVL (
                                     (SELECT SUM (NVL (oola.ordered_quantity, 0) - (NVL (oola.shipped_quantity, 0) + NVL (oola.cancelled_quantity, 0)))
                                        FROM apps.oe_order_lines_all oola, apps.oe_order_sources oos, apps.oe_order_headers_all ooh
                                       WHERE     1 = 1
                                             AND oos.NAME = 'Retail'
                                             AND ooh.header_id =
                                                 oola.header_id
                                             AND ooh.salesrep_id IN
                                                     (SELECT salesrep_id
                                                        FROM xxdo_ebs_rms_vw_map
                                                       WHERE virtual_warehouse =
                                                             p_vm_id)
                                             AND oola.order_source_id =
                                                 oos.order_source_id
                                             AND oola.return_reason_code
                                                     IS NULL
                                             -- added by naga 14-FEB-2013
                                             AND NVL (oola.open_flag, 'N') =
                                                 'Y'
                                             AND oola.ship_from_org_id =
                                                 data_set.organization_id
                                             AND oola.inventory_item_id =
                                                 data_set.inventory_item_id),
                                     0),
                               0));

        CURSOR cur_xxdo_inv_008_inc_bgrd (v_ebs_o_id IN NUMBER, v_vm_id IN NUMBER, v_full_refresh IN VARCHAR2
                                          , v_bg_subinv IN VARCHAR2)
        IS
            SELECT organization_id, inventory_item_id, last_update_qty,
                   apps.do_inv_utils_pub.item_onhand_quantity (organization_id, inventory_item_id, v_bg_subinv) ebs_availability, 0 no_free_atp_quantity
              FROM (  SELECT organization_id, inventory_item_id, MAX (last_update_qty) last_update_qty
                        FROM (SELECT v_ebs_o_id organization_id, TO_NUMBER (item_id) inventory_item_id, LAST_VALUE (xii.unit_qty) OVER (PARTITION BY xii.dc_dest_id, xii.item_id ORDER BY seq_no ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) last_update_qty
                                FROM xxdo_inv_int_008 xii
                               WHERE xii.dc_dest_id = v_vm_id
                              UNION
                              /*SELECT DISTINCT
                                    ms.organization_id,
                                    apps.msc_to_mtl_iid (ms.inventory_item_id)
                                       inventory_item_id,
                                    0 last_update_qty
                               FROM apps.msc_supplies ms
                              WHERE ms.organization_id = v_ebs_o_id*/
                              -- Commented by BT Team V1.1 25Mar 2015
                              /* -- Start modification by BT Team on 21-Jul-15
                                                         SELECT xatp_full.inv_organization_id organization_id,
                                                                xatp_full.inventory_item_id,
                                                                0 last_update_qty
                                                           FROM xxd_master_atp_full_t xatp_full
                                                          WHERE     xatp_full.application = 'RMS'
                                                                AND TRUNC (available_date) = TRUNC (SYSDATE)
                                                                AND inv_organization_id = v_ebs_o_id
                              */
                              SELECT organization_id, inventory_item_id, 0 last_update_qty
                                FROM mtl_system_items_b
                               WHERE     organization_id = v_ebs_o_id
                                     AND apps.do_inv_utils_pub.item_onhand_quantity (
                                             v_ebs_o_id,
                                             inventory_item_id,
                                             v_bg_subinv) >
                                         0--End modification by BT Team on 21-Jul-15*/
                                          ) -- Added by BT Team V1.1 25Mar 2015
                    GROUP BY organization_id, inventory_item_id) data_set
             WHERE     EXISTS
                           (SELECT 1
                              FROM apps.xxdo_rms_item_master_mv
                             --item_master@rmstest
                             WHERE     item =
                                       TO_CHAR (data_set.inventory_item_id)
                                   AND ROWNUM = 1)
                   --and data_set.inventory_item_id in (100241,4979665  )
                   AND (NVL (v_full_refresh, 'Y') = 'Y' OR last_update_qty != apps.do_inv_utils_pub.item_onhand_quantity (organization_id, inventory_item_id, v_bg_subinv));

        -- Added below cursor by Barath for Japan ATR change #ENHC0012072
        CURSOR cur_xxdo_inv_008_inc_dsubinv (v_ebs_o_id IN NUMBER, v_vm_id IN NUMBER, v_full_refresh IN VARCHAR2
                                             , v_subinventory IN VARCHAR2)
        IS
            SELECT organization_id, inventory_item_id, last_update_qty,
                   apps.do_inv_utils_pub.item_onhand_quantity (organization_id, inventory_item_id, v_subinventory) ebs_availability, 0 no_free_atp_quantity
              FROM (  SELECT organization_id, inventory_item_id, MAX (last_update_qty) last_update_qty
                        FROM (SELECT v_ebs_o_id organization_id, TO_NUMBER (item_id) inventory_item_id, LAST_VALUE (xii.unit_qty) OVER (PARTITION BY xii.dc_dest_id, xii.item_id ORDER BY seq_no ASC ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) last_update_qty
                                FROM xxdo_inv_int_008 xii
                               WHERE xii.dc_dest_id = v_vm_id
                              UNION
                              /*SELECT DISTINCT
                                     ms.organization_id,
                                     apps.msc_to_mtl_iid (ms.inventory_item_id)
                                        inventory_item_id,
                                     0 last_update_qty
                                FROM apps.msc_supplies ms
                               WHERE ms.organization_id = v_ebs_o_id*/
                              -- Commented by BT Team V1.1 25Mar 2015
                              SELECT xatp_full.inv_organization_id organization_id, xatp_full.inventory_item_id, 0 last_update_qty
                                FROM xxd_master_atp_full_t xatp_full
                               WHERE     xatp_full.application = 'RMS'
                                     AND TRUNC (available_date) =
                                         TRUNC (SYSDATE)
                                     AND inv_organization_id = v_ebs_o_id) -- Added by BT Team V1.1 25Mar 2015
                    GROUP BY organization_id, inventory_item_id) data_set
             WHERE     EXISTS
                           (SELECT 1
                              FROM apps.xxdo_rms_item_master_mv
                             --item_master@rmstest
                             WHERE     item =
                                       TO_CHAR (data_set.inventory_item_id)
                                   AND ROWNUM = 1)
                   --and data_set.inventory_item_id in (100241,4979665  )
                   AND (NVL (v_full_refresh, 'Y') = 'Y' OR last_update_qty != apps.do_inv_utils_pub.item_onhand_quantity (organization_id, inventory_item_id, v_subinventory));

        /*
        cursor cur_inc_identify(v_run_date in date,
                                v_ebs_o_id in number,
                                pn_number_of_days in number)
        is
        select  moq.inventory_item_id                      item_id
        from apps.mtl_onhand_quantities moq,
             apps.mtl_secondary_inventories msi,
             xxdo_ebs_rms_vw_map xxer
        where moq.subinventory_code(+) = msi.secondary_inventory_name
        and   moq.organization_id(+) = msi.organization_id
        and   moq.organization_id = xxer.organization
        and   msi.reservable_type = '1'
        and   moq.organization_id = v_ebs_o_id
        and   moq.last_update_date >= v_run_date
        and   nvl(upper(xxer.channel),'OUTLET') = 'OUTLET'
        group by xxer.virtual_warehouse,
        moq.inventory_item_id
        union
        select mtd.inventory_item_id                   item_id
        from   mtl_demand mtd,
               xxdo_ebs_rms_vw_map xxer,
               mtl_secondary_inventories msi
        where   mtd.parent_demand_id is not null
        and   mtd.primary_uom_quantity > mtd.completed_quantity
        and   mtd.organization_id = xxer.organization
        and   msi.secondary_inventory_name(+) = mtd.subinventory
        and   msi.organization_id(+) = mtd.organization_id
        and   mtd.organization_id = v_ebs_o_id
        and   mtd.last_update_date >= v_run_date
        and   nvl(upper(xxer.channel),'OUTLET') = 'OUTLET'
        group by xxer.virtual_warehouse,mtd.inventory_item_id
        union
        select  dkl.inventory_item_id item_id
        from   do_kco.do_kco_header dkh,
               do_kco.do_kco_line dkl,
               xxdo_ebs_rms_vw_map xxer
        where  dkl.enabled_flag = 1
        and    dkl.open_flag = 1
        and    dkl.atp_flag = 1
        and    dkl.scheduled_quantity > 0
        and    dkh.kco_header_id = dkl.kco_header_id
        and    dkl.organization_id = xxer.organization
        and    dkh.enabled_flag = 1
        and    dkh.open_flag = 1
        and    dkh.atp_flag = 1
        and    trunc(dkl.kco_schedule_date) <= trunc(sysdate) + pn_number_of_days
        and    dkl.organization_id = v_ebs_o_id
        and    dkl.last_update_date >= v_run_date
        and    dkh.salesrep_id in (select salesrep_id
                                   from xxdo_ebs_rms_vw_map
                                   where organization = v_ebs_o_id)
        and    nvl(upper(xxer.channel),'OUTLET') = 'OUTLET'
        group by xxer.virtual_warehouse,
                 dkl.inventory_item_id
        union
        select ool.inventory_item_id                   item_id
        from   apps.oe_order_lines_all ool,
               xxdo_ebs_rms_vw_map xxer,
               apps.oe_order_sources oos
        where ool.ship_from_org_id = xxer.organization
        and    ool.order_source_id = oos.order_source_id
        and    oos.name = 'Retail'
        and    nvl(ool.open_flag,'N') = 'Y'
        and   ool.ship_from_org_id = v_ebs_o_id
        and   ool.last_update_date >= v_run_date
        and   nvl(upper(xxer.channel),'OUTLET') = 'OUTLET'
        group by xxer.virtual_warehouse,ool.inventory_item_id
        ;
         */
        -------------------------------------------------------- Cursor for loading the data during the initial load
        -- The cursor will retrive the virutal warehouse and
        -- the item id and also the ATR
        -- The ATR is calculated based on the least value between
        -- ATR and ATP. The ATR shouldn't be = 0 or less than zero
        -- hence the free ATR value is passed on to the RMS
        ------------------------------------------------------
        CURSOR cur_xxdo_inv_008_st_load (v_ebs_o_id          IN NUMBER,
                                         v_kco_header_id     IN NUMBER,
                                         v_style             IN VARCHAR2,
                                         v_color             IN VARCHAR2,
                                         pn_number_of_days   IN NUMBER)
        IS
            SELECT atr.virtual_warehouse_id virtual_warehouse_id, atr.inventory_item_id inventory_item_id, atr.quantity quantity,
                   atr.quantity1 no_free_atp_quantity, atr.sku sku, atr.style,
                   atr.color, atr.item_description item_description, atr.atr1 atr_qty,
                   atr.atp atp
              FROM (  SELECT msi.organization_id || '01' virtual_warehouse_id, msi.inventory_item_id inventory_item_id, ------------------------------------------------------------------------------------------------------------------------------
                                                                                                                        -- Added By Sivakumar Boothathan For ATR Changes, removing the KCO Calculation from the ATR Calculation
                                                                                                                        ------------------------------------------------------------------------------------------------------------------------------
                                                                                                                        --least(sum(nvl(ohq.quantity,0)+nvl(demand.quantity,0)+nvl(open_allocation.quantity,0)),(nvl(sum(atp_kco.quantity),0)+nvl(apps.do_atp_utils_pub.single_atp_result (ohq.inventory_item_id,v_ebs_o_id),0)+nvl(sum(open_allocation.quantity),0))) Quantity,
                                                                                                                        --least(sum(nvl(ohq.quantity,0)+nvl(demand.quantity,0)+nvl(open_allocation.quantity,0)),(nvl(sum(atp_kco.quantity),0)+nvl(sum(open_allocation.quantity),0))) quantity1,
                                                                                                                        ------------------------------------------------------------------------------------------------------------------------------
                                                                                                                        -- End Of Comment
                                                                                                                        -------------------------------------------------------------------------------------------------------------------------------
                                                                                                                        -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                                                                        -- Including the function, which will get the KCO header based on the outlet, concept and then the minium of ATP and ATR will be sent over to RMS
                                                                                                                        -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
                                                                                                                        LEAST (SUM (NVL (ohq.quantity, 0) + NVL (DEMAND.quantity, 0) + NVL (open_allocation.quantity, 0)), (NVL ( --                             apps.do_atp_utils_pub.single_atp_result (
                                                                                                                                                                                                                                 --                                        msi.inventory_item_id,
                                                                                                                                                                                                                                 --                                        v_ebs_o_id,
                                                                                                                                                                                                                                 --                                        TRUNC (SYSDATE),
                                                                                                                                                                                                                                 --                                        'Y',
                                                                                                                                                                                                                                 --                                        xxdo_rms_kco_008_atr_fnc (
                                                                                                                                                                                                                                 --                                           v_ebs_o_id,
                                                                                                                                                                                                                                 --                                           msi.inventory_item_id,
                                                                                                                                                                                                                                 --                                           p_vm_id),
                                                                                                                                                                                                                                 --                                        'N')
                                                                                                                                                                                                                                 25, 0) + NVL (SUM (open_allocation.quantity), 0))) quantity,
                             LEAST (SUM (NVL (ohq.quantity, 0) + NVL (DEMAND.quantity, 0) + NVL (open_allocation.quantity, 0)), (NVL (SUM (open_allocation.quantity), 0))) quantity1, /*       msi.segment1               --starting commented by BT Technology team on 03/12/2014
                                                                                                                                                                                          || '-'
                                                                                                                                                                                          || msi.segment2
                                                                                                                                                                                          || '-'
                                                                                                                                                                                          || msi.segment3 sku,
                                                                                                                                                                                          msi.segment1 style, msi.segment2 color,
                                                                                                                                                                                          msi.description item_description,*/
                                                                                                                                                                                      --Ending commented by BT Technology team on 03/12/2014
                                                                                                                                                                                      msi.item_number sku, --starting added by BT Technology team on 03/12/2014
                                                                                                                                                                                                           msi.style_number style,
                             msi.color_code color, msi.item_description item_description, --Ending Added by BT Technology Team on 3/12/2014
                                                                                          SUM (NVL (ohq.quantity, 0) + NVL (DEMAND.quantity, 0) + NVL (open_allocation.quantity, 0)) atr1,
                             NVL ( --                            apps.do_atp_utils_pub.single_atp_result (
                                  --                                    msi.inventory_item_id,
                                  --                                    v_ebs_o_id,
                                  --                                    TRUNC (SYSDATE),
                                    --                                    'Y',
--                                    xxdo_rms_kco_008_atr_fnc (
--                                       v_ebs_o_id,
--                                       msi.inventory_item_id,
--                                       p_vm_id),
                                    --                                    'N')
                                  25, 0) + NVL (SUM (open_allocation.quantity), 0) atp
                        FROM (  SELECT xxer.virtual_warehouse virtual_warehouse_id, moq.inventory_item_id inventory_item_id, NVL (SUM (transaction_quantity), 0) quantity
                                  FROM apps.mtl_onhand_quantities moq, apps.mtl_secondary_inventories msi, xxdo_ebs_rms_vw_map xxer
                                 WHERE     moq.subinventory_code(+) =
                                           msi.secondary_inventory_name
                                       AND moq.organization_id(+) =
                                           msi.organization_id
                                       AND moq.organization_id =
                                           xxer.ORGANIZATION
                                       AND moq.organization_id = v_ebs_o_id
                                       AND msi.reservable_type = '1'
                                       AND NVL (UPPER (xxer.channel), 'OUTLET') =
                                           'OUTLET'
                              GROUP BY xxer.virtual_warehouse, moq.inventory_item_id)
                             ohq,
                             (  SELECT xxer.virtual_warehouse virtual_warehouse_id, mtd.inventory_item_id inventory_item_id, -NVL ((NVL (SUM (mtd.primary_uom_quantity), 0) - NVL (SUM (mtd.completed_quantity), 0)), 0) quantity
                                  FROM mtl_demand mtd, xxdo_ebs_rms_vw_map xxer, mtl_secondary_inventories msi
                                 WHERE     mtd.parent_demand_id IS NOT NULL
                                       AND mtd.primary_uom_quantity >
                                           mtd.completed_quantity
                                       AND mtd.organization_id =
                                           xxer.ORGANIZATION
                                       AND msi.secondary_inventory_name(+) =
                                           mtd.subinventory
                                       AND msi.organization_id(+) =
                                           mtd.organization_id
                                       AND mtd.organization_id = v_ebs_o_id
                                       AND NVL (UPPER (xxer.channel), 'OUTLET') =
                                           'OUTLET'
                              GROUP BY xxer.virtual_warehouse, mtd.inventory_item_id)
                             DEMAND,
                             ----------------------------------------------------------------------------------
                             -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                             ----------------------------------------------------------------------------------
                              (  SELECT xxer.virtual_warehouse virtual_warehouse_id, ool.inventory_item_id inventory_item_id, NVL (SUM (ool.ordered_quantity), 0) - (NVL (SUM (ool.shipped_quantity), 0) + NVL (SUM (ool.cancelled_quantity), 0)) quantity
                                   FROM apps.oe_order_lines_all ool, apps.oe_order_sources oos, xxdo_ebs_rms_vw_map xxer
                                  WHERE     ool.order_source_id =
                                            oos.order_source_id
                                        AND oos.NAME = 'Retail'
                                        AND ool.ship_from_org_id =
                                            xxer.ORGANIZATION
                                        AND NVL (ool.open_flag, 'N') = 'Y'
                                        AND ool.ship_from_org_id = v_ebs_o_id
                                        AND NVL (UPPER (xxer.channel), 'OUTLET') =
                                            'OUTLET'
                               GROUP BY xxer.virtual_warehouse, ool.inventory_item_id)
                             open_allocation,
                             ----------------------------------------------------------------------------------
                             -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                             ----------------------------------------------------------------------------------
                             -- apps.mtl_system_items msi,                                                        --commented by BT Technology Team on 3/12/2014
                             apps.xxd_common_items_v msi, --Added by BT Technology Team on 3/12/2014
                             (  SELECT xxer.virtual_warehouse virtual_warehouse_id, dkl.inventory_item_id inventory_item_id, SUM (dkl.current_quantity) quantity
                                  FROM do_kco.do_kco_header dkh, do_kco.do_kco_line dkl, xxdo_ebs_rms_vw_map xxer
                                 WHERE     dkl.enabled_flag = 1
                                       AND dkl.open_flag = 1
                                       AND dkl.atp_flag = 1
                                       AND dkl.scheduled_quantity > 0
                                       AND dkh.kco_header_id = dkl.kco_header_id
                                       AND dkl.organization_id =
                                           xxer.ORGANIZATION
                                       AND dkh.enabled_flag = 1
                                       AND dkh.open_flag = 1
                                       AND dkh.atp_flag = 1
                                       --and    dkh.kco_header_id = v_kco_header_id
                                       AND dkh.salesrep_id IN
                                               (SELECT salesrep_id
                                                  FROM xxdo_ebs_rms_vw_map
                                                 WHERE ORGANIZATION = v_ebs_o_id)
                                       AND dkl.organization_id = v_ebs_o_id
                                       AND NVL (UPPER (xxer.channel), 'OUTLET') =
                                           'OUTLET'
                                       AND TRUNC (dkl.kco_schedule_date) <=
                                           TRUNC (SYSDATE) + pn_number_of_days
                              GROUP BY xxer.virtual_warehouse, dkl.inventory_item_id)
                             atp_kco
                       WHERE     ohq.virtual_warehouse_id =
                                 DEMAND.virtual_warehouse_id(+)
                             AND ohq.inventory_item_id =
                                 DEMAND.inventory_item_id(+)
                             AND msi.organization_id = v_ebs_o_id
                             -- For Testing The XML
                             /*  AND msi.segment1 = v_style
                               AND msi.segment2 = NVL (v_color, msi.segment2)*/
                             --commented by  BT Technology Team on 3/12/2014
                             AND msi.style_number = v_style
                             AND msi.color_code = NVL (v_color, msi.color_code) --Added by BT Technology Team on 3/12/2014
                             AND ohq.inventory_item_id(+) =
                                 msi.inventory_item_id
                             AND atp_kco.virtual_warehouse_id(+) =
                                 ohq.virtual_warehouse_id
                             AND atp_kco.inventory_item_id(+) =
                                 ohq.inventory_item_id
                             ----------------------------------------------------------------------------------
                             -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                             ----------------------------------------------------------------------------------
                             AND ohq.virtual_warehouse_id =
                                 open_allocation.virtual_warehouse_id(+)
                             AND ohq.inventory_item_id =
                                 open_allocation.inventory_item_id(+)
                             ----------------------------------------------------------------------------------
                             -- Added By Sivakumar Boothathan on 08/21 for ATR changes to add open allocation
                             ----------------------------------------------------------------------------------
                             --             and   msi.inventory_item_status_code = 'Active'
                             /*and   msi.attribute13 is not null
                             and   msi.attribute11 is not null*/
                             /*AND UPPER (TRIM (msi.attribute11)) NOT LIKE '%I'                              --Starting commented by BT Technology Team on 3/12/2014
                             AND msi.segment1 IN (
                                    SELECT DISTINCT msi.segment1
                                               FROM mtl_system_items msi,
                                                    mtl_item_categories mic,
                                                    mtl_categories mc,
                                                    mtl_category_sets mcs
                                              WHERE mic.inventory_item_id =
                                                                msi.inventory_item_id
                                                AND mic.organization_id =
                                                                  msi.organization_id
                                                AND msi.organization_id = 7
                                                AND mic.category_id = mc.category_id
                                                AND mic.category_set_id =
                                                                  mcs.category_set_id
                                                AND mc.structure_id =
                                                                     mcs.structure_id
                                                AND mcs.category_set_id = 1
                                                AND msi.segment3 <> 'ALL'
                                                -- AND   MC.SEGMENT1='UGG'
                                                AND UPPER (TRIM (mc.segment2)) <>
                                                                             'SAMPLE'
       --                                 AND   MSI.INVENTORY_ITEM_STATUS_CODE='Active'
                                                AND msi.segment1 NOT LIKE 'S%L'
                                                AND msi.segment1 NOT LIKE 'S%R'
                                                AND msi.attribute13 IS NOT NULL
                                                AND msi.attribute11 IS NOT NULL)*/
                             --Ending commented by BT Technology Team on 3/12/2014
                             AND UPPER (TRIM (msi.upc_code)) NOT LIKE '%I' --starting Added by BT Technology team on 3/12/2014
                             AND msi.style_number IN
                                     (SELECT DISTINCT msi.style_number
                                        FROM xxd_common_items_v msi
                                       WHERE     msi.item_type <> 'GENERIC'
                                             AND UPPER (TRIM (msi.department)) <>
                                                 'SAMPLE'
                                             AND msi.style_number NOT LIKE
                                                     'S%L'
                                             AND msi.style_number NOT LIKE
                                                     'S%R'
                                             AND msi.size_scale_id IS NOT NULL
                                             AND msi.upc_code IS NOT NULL) --Ending Added by BT Technology team on 3/12/2014
                             AND msi.inventory_item_id IN
                                     (SELECT DISTINCT msib.inventory_item_id
                                        FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                                             mtl_categories_b mc, mtl_category_sets mcs, mtl_item_categories mic,
                                             --  mtl_system_items_b msib          --commented by BT Technology Team on 3/12/2014
                                             xxd_common_items_v msib --Added by BT Technology Team on 3/12/2014
                                       WHERE     qpa.list_line_id =
                                                 qll.list_line_id
                                             AND qll.list_header_id =
                                                 qlh.list_header_id
                                             AND mic.inventory_item_id =
                                                 msib.inventory_item_id
                                             AND mic.organization_id =
                                                 msib.organization_id
                                             AND mc.structure_id =
                                                 mcs.structure_id
                                             AND qpa.product_attribute =
                                                 'PRICING_ATTRIBUTE2'
                                             AND qpa.product_attr_value =
                                                 mc.category_id
                                             AND qpa.product_attr_value =
                                                 TO_CHAR (mc.category_id)
                                             AND mic.category_id =
                                                 mc.category_id
                                             AND mic.category_set_id =
                                                 mcs.category_set_id
                                             --   AND msib.organization_id = 7                                                --commented by BT Technology Team on 3/12/2014
                                             AND msib.organization_id IN
                                                     (SELECT ood.ORGANIZATION_ID
                                                        FROM fnd_lookup_values flv, org_organization_definitions ood
                                                       WHERE     lookup_type =
                                                                 'XXD_1206_INV_ORG_MAPPING'
                                                             AND lookup_code =
                                                                 7
                                                             AND flv.attribute1 =
                                                                 ood.ORGANIZATION_CODE
                                                             AND language =
                                                                 USERENV (
                                                                     'LANG')) --Added by BT Technology Team on 3/12/2014
                                             --                and msib.inventory_item_status_code = 'Active'
                                             AND qpa.product_attribute_context =
                                                 'ITEM'
                                             /*                and msib.segment1=msi.segment1
                                                             and msib.organization_id=msi.organization_id */
                                             AND qlh.NAME = 'Retail - US'
                                             AND mcs.category_set_name =
                                                 'Styles')
                             AND msi.inventory_item_id IN
                                     (SELECT DISTINCT (inventory_item_id)
                                        FROM xxdoinv006_int
                                       WHERE item_type = 'SKU')
                    --and msi.segment1||'-'||msi.segment2||'-'||msi.segment3 = '5803-CHE-10'
                    GROUP BY msi.organization_id || '01', msi.inventory_item_id, /*     msi.segment1                                                              --starting commented by BT Technology team on 3/12/2014
                                                                                   || '-'
                                                                                   || msi.segment2
                                                                                   || '-'
                                                                                   || msi.segment3,
                                                                                   msi.description) atr*/
                                                                                 --Ending commented By BT Technology Team on 3/12/2014
                                                                                 msi.item_number,
                             msi.item_description) atr --Added by BT Technology Team on 3/12/2014
             WHERE     NVL (atr.quantity, -99) >= 0
                   AND atr.style = NVL (v_style, atr.style)
                   AND atr.color = NVL (v_color, atr.color) --and   rownum <= 1000
                                                           ;

        CURSOR xxdo_request_cur IS
              SELECT COUNT (*), request_leg, request_id,
                     load_type
                FROM xxdo_inv_int_008
               WHERE     dc_dest_id = p_vm_id
                     AND load_type = p_load_type
                     AND processed_flag IS NULL
                     AND status = 'N'
            GROUP BY request_leg, request_id, load_type;

        CURSOR l_req_leg_cur IS
            SELECT DISTINCT dc_dest_id, NVL (request_leg, 0) request_leg
              FROM xxdo_inv_int_008
             WHERE status = 'N' AND processed_flag IS NULL; --Added for version 2.1

        -----------------------------------------
        -- Declaring Variables for the procedure
        -----------------------------------------
        v_user_id               NUMBER := 0;
        v_vm_id                 VARCHAR2 (100) := p_vm_id;
        v_organization          NUMBER := 0;
        v_org_code              VARCHAR2 (100) := NULL;
        v_kco_header_id         NUMBER := 0;
        v_free_atp              VARCHAR2 (1) := NULL;
        v_load_type             VARCHAR2 (100) := p_load_type;
        v_reprocess_flag        VARCHAR2 (100) := p_reprocess;
        v_item_id               NUMBER := 0;
        v_quantity              NUMBER := 0;
        v_last_run_date         DATE := SYSDATE;
        v_reprocess_from_date   VARCHAR2 (100) := p_reprocess_from;
        v_reprocess_to_date     VARCHAR2 (100) := p_reprocess_to;
        v_no_free_atp_q         NUMBER := 0;
        v_item_name             VARCHAR2 (100) := NULL;
        v_description           VARCHAR2 (100) := NULL;
        v_request_id            NUMBER := 0;
        v_request_flag          BOOLEAN;
        v_phase                 VARCHAR2 (100) := NULL;
        v_status                VARCHAR2 (100) := NULL;
        v_dev_phase             VARCHAR2 (100) := NULL;
        v_dev_status            VARCHAR2 (100) := NULL;
        v_message               VARCHAR2 (240) := NULL;
        v_s_no                  NUMBER := 0;
        v_identified_item_id    NUMBER := 0;
        v_style                 VARCHAR2 (100) := p_style;
        v_color                 VARCHAR2 (100) := p_color;
        v_req_id                NUMBER := 0;
        v_max_seq_no            NUMBER := 0;
        v_check_qty             NUMBER := 0;
        v_unit_qty_1            NUMBER := 0;
        l_tot_cnt               NUMBER := 0;
        l_cntr                  NUMBER := 0;
        l_re_leg                NUMBER := 1;
        l_thread_cnt            NUMBER := 0;
        ln_request_id           NUMBER := 0;
        lb_concreqcallstat      BOOLEAN := FALSE;
        lv_dev_phase            VARCHAR2 (50);
        lv_dev_status           VARCHAR2 (50);
        lv_status               VARCHAR2 (50);
        lv_phase                VARCHAR2 (50);
        lv_message              VARCHAR2 (240);
        lv_retcode              VARCHAR2 (10);
        v_item_description      VARCHAR2 (240);
        v_sku                   VARCHAR2 (50);
        l_b_grade_flg           VARCHAR2 (1);
        --Start for 3.2
        ln_asn_fetch_days       NUMBER
            := fnd_profile.VALUE ('XXD_INV_ASN_FETCH_DAYS');
        ln_loop_cntr            NUMBER := 0;
        --End for 3.2
        --------------------------------------------------------------------------
        -- Added By Sivakumar boothathan for the ATR changes
        --------------------------------------------------------------------------
        v_kco_header_id1        NUMBER := 0;
        l_subinventory          VARCHAR2 (200) := NULL;
        --Added by Barath for Japan ATR change #ENHC0012072
        l_order_type            NUMBER := 0;
        --Added by Barath for Japan ATR change #ENHC0012072
        ---------------------------------------------------------
        -- Added By Sivakumar Boothathan for China Bgrade V2.2
        ---------------------------------------------------------
        v_bg_subinv             VARCHAR2 (100) := NULL;
    ----------------------------------------------------------------------
    -- End of changes By Sivakumar Boothathan for China Bgrade V2.2
    ----------------------------------------------------------------------
    ------------------------------
    -- Beginning of the procedure
    ------------------------------
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of the program: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));            --v3.1

        IF     p_vm_id IS NOT NULL
           AND p_load_type IS NOT NULL
           AND p_reprocess IS NOT NULL
        THEN -- added ver 2.3 --- code execution only when all three are entered
            BEGIN
                ------------------------------------
                -- Getting the request ID
                ------------------------------------
                SELECT fnd_global.conc_request_id INTO v_req_id FROM DUAL;
            EXCEPTION
                ----------------------
                -- Exception Handler
                ----------------------
                WHEN NO_DATA_FOUND
                THEN
                    v_user_id   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Getting The REQ ID');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
                WHEN OTHERS
                THEN
                    v_user_id   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Others Error Found While Getting The REQ ID');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
            --------------------------------------------
            -- End of the block to retrive the USER ID
            --------------------------------------------
            END;

            ------------------------------------
            -- Select query to get the user ID
            ------------------------------------
            BEGIN
                ---------------------
                -- User name = BATCH
                ---------------------
                SELECT user_id
                  INTO v_user_id
                  FROM apps.fnd_user
                 WHERE UPPER (user_name) = 'BATCH';
            EXCEPTION
                ----------------------
                -- Exception Handler
                ----------------------
                WHEN NO_DATA_FOUND
                THEN
                    v_user_id   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Getting The User ID');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
                WHEN OTHERS
                THEN
                    v_user_id   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Others Error Found While Getting The User ID');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
            --------------------------------------------
            -- End of the block to retrive the USER ID
            --------------------------------------------
            END;

            -- Start changes v3.1
            /*
                  ----------------------------------------------------------
                  -- Query to get the warehouse And organization combination
                  ----------------------------------------------------------
                  BEGIN
                     -------------------------------------------------------------------------
                     -- select query to get the data from the fnd_concurrent_requests_table
                     -- This query is to get the last run date for the concurrent request
                     -- with the 2nd parameter being the virtual warehouse ID
                     -------------------------------------------------------------------------
                     SELECT MAX (actual_completion_date)
                       INTO v_last_run_date
                       FROM apps.fnd_concurrent_requests fcr,
                            apps.fnd_concurrent_programs_tl fcp
                      WHERE     fcr.concurrent_program_id = fcp.concurrent_program_id
                            AND fcp.LANGUAGE = 'US'
                            AND fcp.user_concurrent_program_name =
                                   'XXDO INV INT 008 ATR Retail Integration'
                            AND fcr.phase_code = 'C'
                            AND fcr.status_code = 'C'
                            AND argument1 = v_vm_id;
                  --------------------
                  -- Exception Handler
                  --------------------
                  EXCEPTION
                     WHEN NO_DATA_FOUND
                     THEN
                        v_last_run_date := SYSDATE;
                        fnd_file.put_line (
                           fnd_file.LOG,
                           'No Data Found While Getting The Data from the table fnd_concurrent_requests');
                        fnd_file.put_line (fnd_file.LOG, 'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                     WHEN OTHERS
                     THEN
                        v_last_run_date := SYSDATE;
                        fnd_file.put_line (
                           fnd_file.LOG,
                           'Others Error Found While Getting The Data from the table fnd_concurrent_requests');
                        fnd_file.put_line (fnd_file.LOG, 'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                  --------------------------------------------
                  -- End of the block to retrive the USER ID
                  -------------------------------------------
                  END;
            */
            -- End changes v3.1

            ----------------------------------------------------------
            -- Query to get the warehouse And organization combination
            ----------------------------------------------------------
            BEGIN
                  -------------------------------------------------------
                  -- select query to get the data from the custom table
                  -------------------------------------------------------
                  SELECT ORGANIZATION, organization_code, kco_header_id,
                         NVL (free_atp, 'Y')
                    INTO v_organization, v_org_code, v_kco_header_id, v_free_atp
                    FROM xxdo_ebs_rms_vw_map
                   WHERE virtual_warehouse = v_vm_id
                GROUP BY ORGANIZATION, organization_code, kco_header_id,
                         free_atp;
            --------------------
            -- Exception Handler
            --------------------
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Getting The Data from custom VW table');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Others Error Found While Getting The Data from custom VW table');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
            --------------------------------------------
            -- End of the block to retrive the USER ID
            -------------------------------------------
            END;

            -- Added by Barath for Japan ATR change #ENHC0012072
            BEGIN
                -- Start change by BT team on 25-May-15 v1.5
                --         SELECT ottl.transaction_type_id, otta.attribute11
                SELECT ottl.transaction_type_id, otta.attribute7
                  -- End of change by BT team on 25-May-15 v1.5
                  INTO l_order_type, l_subinventory
                  FROM apps.fnd_lookup_values_vl flv, apps.hr_operating_units hou, apps.oe_transaction_types_tl ottl,
                       apps.oe_transaction_types_all otta
                 WHERE     flv.lookup_type = 'XXDO_RMS_SO_RMA_ALLOCATION'
                       AND ottl.transaction_type_id =
                           otta.transaction_type_id
                       AND UPPER (flv.lookup_code) = UPPER (ottl.NAME)
                       AND hou.NAME = flv.tag
                       AND flv.description = 'SHIP'
                       AND hou.organization_id IN
                               (SELECT operating_unit
                                  FROM apps.org_organization_definitions ood
                                 WHERE organization_id = v_organization)
                       AND ottl.LANGUAGE = 'US'
                       AND flv.enabled_flag = 'Y'
                       -- AND FLV.language = 'US'
                       AND flv.attribute_category =
                           'XXDO_RMS_SO_RMA_ALLOCATION'
                       AND flv.attribute11 = v_vm_id;

                fnd_file.put_line (fnd_file.LOG,
                                   'l_subinventory ' || l_subinventory);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_order_type ' || l_order_type);
                fnd_file.put_line (fnd_file.LOG, 'v_vm_id ' || v_vm_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'v_organization ' || v_organization);
            --------------------
            -- Exception Handler
            --------------------
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Getting The default subinventory from order type');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
                    l_subinventory   := NULL;
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Getting The default subinventory from order type');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code :' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);
                    l_subinventory   := NULL;
            --------------------------------------------
            -- End of the block to retrive the USER ID
            -------------------------------------------
            END;

            -----------------------------------------------
            -- If the load type = INITIAL LOAD then, we need
            -- to call out the cursor :
            -- which will pull the data from the cursor
            -- and push it to the staging table which is used
            -- by RMS to fetch the value and send it to RMS
            -------------------------------------------------
            IF (UPPER (v_load_type) = 'INITIAL LOAD' AND UPPER (v_reprocess_flag) = 'N')
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Initial Load And Reprocess Flag = N');

                --Start changes v3.1
                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Before Archive Delete: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                    DELETE FROM xxdo.xxdo_inv_int_008_archive
                          WHERE dc_dest_id = v_vm_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error While Deleting The Archive Table: '
                            || SQLERRM);
                END;

                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Before Archive Insert: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                    INSERT INTO xxdo.xxdo_inv_int_008_archive
                        SELECT *
                          FROM xxdo_inv_int_008
                         WHERE dc_dest_id = v_vm_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error While Inserting to the Archive Table: '
                            || SQLERRM);
                END;

                COMMIT;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before inv_int_008 Delete: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                --End changes v3.1

                -----------------------------------------------------
                -- Custom table : xxdo_inv_int_008 is truncated
                -----------------------------------------------------
                --execute immediate 'truncate table xxdo_inv_int_008';
                BEGIN
                    DELETE FROM xxdo_inv_int_008
                          WHERE dc_dest_id = v_vm_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'No Data Found While Deleting The Table : XXDO_INV_INT_008');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Others Error While Deleting The Table : XXDO_INV_INT_008');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                END;

                l_b_grade_flg   := 'N';

                BEGIN
                    SELECT 'Y'
                      INTO l_b_grade_flg
                      FROM apps.fnd_lookup_values_vl flv
                     WHERE     flv.lookup_type = 'XXDO_B_GRADE_VW'
                           AND flv.enabled_flag = 'Y'
                           AND meaning = v_vm_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_b_grade_flg   := 'N';
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'No Data Found While Selecting b_grade_flg');
                    --fnd_file.put_line (fnd_file.LOG, 'SQL Error Code :' || SQLCODE);
                    --fnd_file.put_line (fnd_file.LOG, 'SQL Error Message :' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        l_b_grade_flg   := 'N';
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Others Error While Selecting b_grade_flg');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                END;

                -----------------------------------------------------------------
                -- The below command will truncate the table : xxdo_inv_int_008
                -----------------------------------------------------------------
                ----------------------------------------------------------------------------
                -- Begin loop to vary value of the cursor from cur_xxdo_inv_008_ini_load
                ----------------------------------------------------------------------------
                IF l_b_grade_flg = 'N'
                THEN
                    l_cntr     := 0;
                    l_re_leg   := 1;

                    IF l_subinventory IS NULL
                    THEN   --Added by Barath for Japan ATR change #ENHC0012072
                        fnd_file.put_line (fnd_file.output,
                                           'Initial load ' || l_subinventory);

                        --Added by Barath for Japan ATR change #ENHC0012072
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Before Initial Load loop: '
                            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')); --v3.1

                        FOR c_cur_xxdo_inv_008_ini_load
                            IN cur_xxdo_inv_008_ini_load ( /*v_organization,
                                                           v_kco_header_id,
                                                           p_number_of_days*/
                            -- Commented by BT Technology Team V1.1 30Mar 2015
                               v_organization, -- Added by BT Technology Team V1.1 30Mar 2015
                                               v_free_atp,              --v3.1
                                                           p_vm_id -- Added by BT Technology Team V1.1 30Mar 2015
                                                                  )
                        LOOP
                            --Start of Changes by V1.1 30Mar 2015
                            BEGIN
                                SELECT item_number
                                  INTO v_item_name
                                  FROM xxd_common_items_v xci
                                 WHERE     xci.inventory_item_id =
                                           c_cur_xxdo_inv_008_ini_load.inventory_item_id
                                       AND xci.organization_id =
                                           v_organization;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Unable to derive SKU '
                                        || SQLERRM
                                        || SQLCODE);
                            END;

                            BEGIN
                                SELECT item_description
                                  INTO v_description
                                  FROM xxd_common_items_v xci
                                 WHERE     xci.inventory_item_id =
                                           c_cur_xxdo_inv_008_ini_load.inventory_item_id
                                       AND xci.organization_id =
                                           v_organization;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Unable to derive Item Description '
                                        || SQLERRM
                                        || SQLCODE);
                            END;

                            --End of Changes by BT Technology Team V1.1 30Mar 2015


                            --------------------------------------
                            -- Assigning the variables in the loop
                            --------------------------------------
                            v_item_id   :=
                                c_cur_xxdo_inv_008_ini_load.inventory_item_id;
                            v_quantity   :=
                                c_cur_xxdo_inv_008_ini_load.quantity;
                            v_no_free_atp_q   :=
                                c_cur_xxdo_inv_008_ini_load.no_free_atp_quantity;
                            --v_item_name := c_cur_xxdo_inv_008_ini_load.sku;                        -- Commented by BT Technology Team V1.1 30Mar 2015
                            --v_description := c_cur_xxdo_inv_008_ini_load.item_description;        -- Commented by BT Technology Team V1.1 30Mar 2015
                            l_cntr   := 1 + l_cntr;

                            BEGIN
                                SELECT xxdo_int_008_seq.NEXTVAL
                                  INTO v_s_no
                                  FROM DUAL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found When Getting The Value Of The Sequence');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Data Found When Getting The Value Of The Sequence');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            ---------------------------------------------------------
                            -- Insert query to insert the data into xxdo_inv_int_008
                            ---------------------------------------------------------
                            ---------------------------
                            -- Beginning of the code
                            ---------------------------
                            BEGIN
                                --                     fnd_file.put_line (fnd_file.LOG, 'inside loop ');

                                INSERT INTO xxdo_inv_int_008 (
                                                seq_no,
                                                dc_dest_id,
                                                item_id,
                                                adjustment_reason_code,
                                                unit_qty,
                                                transshipment_nbr,
                                                from_disposition,
                                                to_disposition,
                                                from_trouble_code,
                                                to_trouble_code,
                                                from_wip_code,
                                                to_wip_code,
                                                transaction_code,
                                                user_id,
                                                create_date,
                                                po_nbr,
                                                doc_type,
                                                aux_reason_code,
                                                weight,
                                                weight_uom,
                                                unit_cost,
                                                status,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_update_by,
                                                sku,
                                                item_description,
                                                free_atp_q,
                                                no_free_atp_q,
                                                load_type,
                                                request_leg)
                                     VALUES (v_s_no, v_vm_id, v_item_id,
                                             10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                             , 'Initial Load', l_re_leg);

                                -- fnd_file.put_line(fnd_file.log,'l_cntr -1 '||l_cntr);
                                IF l_cntr = 2000
                                THEN
                                    --fnd_file.put_line (fnd_file.LOG,'l_cntr 0 ' || l_cntr);
                                    --fnd_file.put_line (fnd_file.LOG,'l_re_leg  0 ' || l_re_leg);
                                    l_cntr     := 0;
                                    l_re_leg   := 1 + l_re_leg;
                                    --fnd_file.put_line (fnd_file.LOG,'l_cntr 1 ' || l_cntr);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg  1 ' || l_re_leg);
                                END IF;
                            --------------------
                            -- Exception Handler
                            --------------------
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found While Inserting into the custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Data Found While Inserting into the custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;
                        -----------------------
                        -- End Loop
                        -----------------------
                        END LOOP;

                        --Start changes v3.1
                        COMMIT;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Before Additional Load loop: '
                            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                        --Insert Additional records during Initial Load
                        FOR c_cur_ini_additional_load
                            IN cur_ini_additional_load (v_organization,
                                                        v_free_atp,
                                                        p_vm_id)
                        LOOP
                            BEGIN
                                SELECT item_number, item_description
                                  INTO v_item_name, v_description
                                  FROM xxd_common_items_v xci
                                 WHERE     xci.inventory_item_id =
                                           c_cur_ini_additional_load.inventory_item_id
                                       AND xci.organization_id =
                                           v_organization;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Unable to derive SKU and Item Desc: '
                                        || SQLERRM
                                        || SQLCODE);
                            END;

                            --------------------------------------
                            -- Assigning the variables in the loop
                            --------------------------------------
                            v_item_id   :=
                                c_cur_ini_additional_load.inventory_item_id;
                            v_quantity   :=
                                c_cur_ini_additional_load.quantity;
                            v_no_free_atp_q   :=
                                c_cur_ini_additional_load.no_free_atp_quantity;
                            l_cntr   := 1 + l_cntr;

                            BEGIN
                                SELECT xxdo_int_008_seq.NEXTVAL
                                  INTO v_s_no
                                  FROM DUAL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found When Getting Sequence in additional load');
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Error When Getting Sequence in additional load');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code: ' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message: ' || SQLERRM);
                            END;

                            ---------------------------------------------------------
                            -- Insert query to insert the additional data into xxdo_inv_int_008
                            ---------------------------------------------------------
                            BEGIN
                                INSERT INTO xxdo_inv_int_008 (
                                                seq_no,
                                                dc_dest_id,
                                                item_id,
                                                adjustment_reason_code,
                                                unit_qty,
                                                transshipment_nbr,
                                                from_disposition,
                                                to_disposition,
                                                from_trouble_code,
                                                to_trouble_code,
                                                from_wip_code,
                                                to_wip_code,
                                                transaction_code,
                                                user_id,
                                                create_date,
                                                po_nbr,
                                                doc_type,
                                                aux_reason_code,
                                                weight,
                                                weight_uom,
                                                unit_cost,
                                                status,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_update_by,
                                                sku,
                                                item_description,
                                                free_atp_q,
                                                no_free_atp_q,
                                                load_type,
                                                request_leg)
                                     VALUES (v_s_no, v_vm_id, v_item_id,
                                             10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                             , 'Initial Load', l_re_leg);

                                IF l_cntr = 2000
                                THEN
                                    l_cntr     := 0;
                                    l_re_leg   := 1 + l_re_leg;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg value: ' || l_re_leg);
                                END IF;
                            --------------------
                            -- Exception Handler
                            --------------------
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found While Inserting additional data into custom table');
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Error While Inserting additional data into custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code: ' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message: ' || SQLERRM);
                            END;
                        -----------------------
                        -- End Loop
                        -----------------------
                        END LOOP;

                        --End changes v3.1

                        --Start changes for 3.2
                        COMMIT;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Start Eligible ASN Load Initial Loop: '
                            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Profile - XXD_INV_ASN_FETCH_DAYS: '
                            || ln_asn_fetch_days);

                        --Insert Eligible ASN Load records during Initial Load
                        ln_loop_cntr   := 0;

                        FOR r_asn_008_load
                            IN cur_eligible_asn_008_load (v_organization,
                                                          v_free_atp,
                                                          p_vm_id,
                                                          ln_asn_fetch_days)
                        LOOP
                            BEGIN
                                SELECT item_number, item_description
                                  INTO v_item_name, v_description
                                  FROM xxd_common_items_v xci
                                 WHERE     xci.inventory_item_id =
                                           r_asn_008_load.inventory_item_id
                                       AND xci.organization_id =
                                           v_organization;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Unable to derive SKU and Item Desc: '
                                        || SQLERRM
                                        || SQLCODE);
                            END;


                            --Assign variables
                            v_item_id    := r_asn_008_load.inventory_item_id;
                            v_quantity   := r_asn_008_load.quantity;
                            v_no_free_atp_q   :=
                                r_asn_008_load.no_free_atp_quantity;
                            l_cntr       := 1 + l_cntr;

                            BEGIN
                                SELECT xxdo_int_008_seq.NEXTVAL
                                  INTO v_s_no
                                  FROM DUAL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found When Getting Sequence in Eligbile ASN load');
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Error When Getting Sequence in Eligbile ASN  load');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code: ' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message: ' || SQLERRM);
                            END;

                            -- Insert Eligbile ASN records into xxdo_inv_int_008
                            BEGIN
                                INSERT INTO xxdo_inv_int_008 (
                                                seq_no,
                                                dc_dest_id,
                                                item_id,
                                                adjustment_reason_code,
                                                unit_qty,
                                                transshipment_nbr,
                                                from_disposition,
                                                to_disposition,
                                                from_trouble_code,
                                                to_trouble_code,
                                                from_wip_code,
                                                to_wip_code,
                                                transaction_code,
                                                user_id,
                                                create_date,
                                                po_nbr,
                                                doc_type,
                                                aux_reason_code,
                                                weight,
                                                weight_uom,
                                                unit_cost,
                                                status,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_update_by,
                                                sku,
                                                item_description,
                                                free_atp_q,
                                                no_free_atp_q,
                                                load_type,
                                                request_leg)
                                     VALUES (v_s_no, v_vm_id, v_item_id,
                                             10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                             , 'Initial Load', l_re_leg);

                                ln_loop_cntr   := ln_loop_cntr + 1;

                                IF l_cntr = 2000
                                THEN
                                    l_cntr     := 0;
                                    l_re_leg   := 1 + l_re_leg;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg value: ' || l_re_leg);
                                END IF;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found While Inserting additional data into custom table');
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Error While Inserting additional data into custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code: ' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message: ' || SQLERRM);
                            END;
                        END LOOP;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Total ASN SKUs Count: ' || ln_loop_cntr);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'End Eligible ASN Load Initial Loop: '
                            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                    --End changes for 3.2
                    ELSE
                        --Added by Barath for Japan ATR change #ENHC0012072 begin
                        fnd_file.put_line (fnd_file.output,
                                           'Initial load ' || l_subinventory);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Before dsubinv loop: '
                            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')); --v3.1

                        FOR c_cur_xxdo_inv_008_inc_dsubinv
                            IN cur_xxdo_inv_008_inc_dsubinv (v_organization,
                                                             v_vm_id,
                                                             'Y',
                                                             l_subinventory)
                        LOOP
                            -- fnd_file.put_line(fnd_file.log,'b-grade incremental');
                            -- fnd_file.put_line(fnd_file.log,'start incremental load process for item_id :'||c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id);
                            --------------------------------------
                            -- Assigning the variables in the loop
                            --------------------------------------
                            BEGIN
                                /*     SELECT msi.description,                                                               --starting commented by BT Technology Team on 3/12/2014
                                               msi.segment1
                                            || '-'
                                            || msi.segment2
                                            || '-'
                                            || msi.segment3 sku
                                       INTO v_item_description,
                                            v_sku
                                       FROM mtl_system_items msi*/
                                --Ending commented by BT Technology Team on 3/12/2014
                                SELECT msi.item_description, --Staring Added by BT Technology Team on 3/12/2014
                                                             msi.item_number sku
                                  INTO v_item_description, v_sku
                                  FROM xxd_common_items_v msi --Ending Added by BT Technology Team on 3/12/2014
                                 WHERE     msi.organization_id =
                                           v_organization
                                       AND msi.inventory_item_id =
                                           c_cur_xxdo_inv_008_inc_dsubinv.inventory_item_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'could not derive item description and sku for item_id:'
                                        || c_cur_xxdo_inv_008_inc_dsubinv.inventory_item_id);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            v_item_id       :=
                                c_cur_xxdo_inv_008_inc_dsubinv.inventory_item_id;
                            v_quantity      :=
                                c_cur_xxdo_inv_008_inc_dsubinv.ebs_availability;
                            v_no_free_atp_q   :=
                                c_cur_xxdo_inv_008_inc_dsubinv.no_free_atp_quantity;
                            v_item_name     := v_sku;
                            v_description   := v_item_description;

                            BEGIN
                                --fnd_file.put_line(fnd_file.log,'v_vm_id : '||v_vm_id); --For Debugging BT Team
                                --fnd_file.put_line(fnd_file.log,'v_item_id : '||v_item_id);
                                SELECT MAX (seq_no)
                                  INTO v_max_seq_no
                                  FROM xxdo_inv_int_008
                                 WHERE     dc_dest_id = v_vm_id
                                       AND item_id = v_item_id;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    '0.v_max_seq_no : ' || v_max_seq_no);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    v_max_seq_no   := NULL;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found Exception When Getting The Max Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Error When Getting The Max Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            --fnd_file.put_line(fnd_file.log,'Sequence Number Is :'||v_max_seq_no);
                            IF (NVL (v_max_seq_no, 99) > 0)
                            THEN
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Inside The IF Condition');

                                BEGIN
                                    SELECT unit_qty, (DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q))
                                      INTO v_check_qty, v_unit_qty_1
                                      FROM xxdo_inv_int_008
                                     WHERE seq_no = v_max_seq_no;
                                --fnd_file.put_line(fnd_file.log,'QTY 1 :'||v_check_qty);
                                --fnd_file.put_line(fnd_file.log,'QTY 2 :'||v_unit_qty_1);
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        v_check_qty    := NULL;
                                        v_unit_qty_1   := NULL;
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'No Data Found Exception When Getting The Quantity for a MAX Sequence Number');
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Message :' || SQLERRM);
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'Others Error When Getting The Quantity for a MAX Sequence Number');
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Message :' || SQLERRM);
                                END;

                                IF (NVL (v_unit_qty_1, 1) = NVL (v_check_qty, 2))
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Exiting From The Condition');
                                    EXIT;
                                END IF;
                            END IF;

                            l_cntr          := 1 + l_cntr;

                            BEGIN
                                SELECT xxdo_int_008_seq.NEXTVAL
                                  INTO v_s_no
                                  FROM DUAL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found When Getting The Value Of The Sequence');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Data Found When Getting The Value Of The Sequence');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            ---------------------------------------------------------
                            -- Insert query to insert the data into xxdo_inv_int_008
                            ---------------------------------------------------------
                            ---------------------------
                            -- Beginning of the code
                            ---------------------------
                            BEGIN
                                INSERT INTO xxdo_inv_int_008 (
                                                seq_no,
                                                dc_dest_id,
                                                item_id,
                                                adjustment_reason_code,
                                                unit_qty,
                                                transshipment_nbr,
                                                from_disposition,
                                                to_disposition,
                                                from_trouble_code,
                                                to_trouble_code,
                                                from_wip_code,
                                                to_wip_code,
                                                transaction_code,
                                                user_id,
                                                create_date,
                                                po_nbr,
                                                doc_type,
                                                aux_reason_code,
                                                weight,
                                                weight_uom,
                                                unit_cost,
                                                status,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_update_by,
                                                sku,
                                                item_description,
                                                free_atp_q,
                                                no_free_atp_q,
                                                load_type,
                                                request_leg)
                                     VALUES (v_s_no, v_vm_id, v_item_id,
                                             10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                             , 'Initial Load', l_re_leg);

                                NULL;

                                IF l_cntr = 2000
                                THEN
                                    fnd_file.put_line (fnd_file.LOG,
                                                       'l_cntr 0 ' || l_cntr);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg  0 ' || l_re_leg);
                                    l_cntr     := 0;
                                    l_re_leg   := 1 + l_re_leg;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       'l_cntr 1 ' || l_cntr);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg  1 ' || l_re_leg);
                                END IF;
                            --------------------
                            -- Exception Handler
                            --------------------
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found While Inserting into the custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Data Found While Inserting into the custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;
                        END LOOP;
                    END IF;
                ELSE   --Added by Barath for Japan ATR change #ENHC0012072 End
                    ----b-grade change
                    l_cntr     := 0;
                    l_re_leg   := 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'v_organization ' || v_organization);
                    fnd_file.put_line (fnd_file.LOG, 'v_vm_id ' || v_vm_id);
                    fnd_file.put_line (
                        fnd_file.output,
                        'Initial load Bgrade' || l_subinventory);

                    --Added by Barath for Japan ATR change #ENHC0012072
                    ---------------------------------------------------------------
                    -- Changes done by Sivakumar Boothathan for China Bgrade V2.2
                    ---------------------------------------------------------------
                    BEGIN
                        SELECT tag
                          INTO v_bg_subinv
                          FROM apps.fnd_lookup_values
                         WHERE     lookup_type = 'XXDO_B_GRADE_VW'
                               AND language = 'US'
                               AND lookup_code = v_vm_id
                               AND enabled_flag = 'Y'
                               AND NVL (TRUNC (end_date_active),
                                        TRUNC (SYSDATE + 1)) >=
                                   TRUNC (SYSDATE);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Couldnt find the BG Sub inventory');
                    END;

                    -------------------------------------------------------------------
                    -- End of changes By Sivakumar Boothathan for China Bgrade V2.2
                    -------------------------------------------------------------------
                    -------------------------------------------------------------------
                    -- Adding the Sub-Inventory variable to the cursor
                    -------------------------------------------------------------------
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Before bgrd loop: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')); --v3.1

                    FOR c_cur_xxdo_inv_008_inc_bgrd
                        IN cur_xxdo_inv_008_inc_bgrd (v_organization, v_vm_id, 'Y'
                                                      , v_bg_subinv)
                    LOOP
                        -- fnd_file.put_line(fnd_file.log,'b-grade Initial');
                        --  fnd_file.put_line(fnd_file.log,'start incremental load process for item_id :'||c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id);
                        --------------------------------------
                        -- Assigning the variables in the loop
                        --------------------------------------
                        BEGIN
                            /*     SELECT msi.description,                                                               --starting commented by BT Technology Team on 3/12/2014
                                          msi.segment1
                                       || '-'
                                       || msi.segment2
                                       || '-'
                                       || msi.segment3 sku
                                  INTO v_item_description,
                                       v_sku
                                  FROM mtl_system_items msi*/
                            --Ending commented by BT Technology Team on 3/12/2014
                            SELECT msi.item_description, --Staring Added by BT Technology Team on 3/12/2014
                                                         msi.item_number sku
                              INTO v_item_description, v_sku
                              FROM xxd_common_items_v msi --Ending Added by BT Technology Team on 3/12/2014
                             WHERE     msi.organization_id = v_organization
                                   AND msi.inventory_item_id =
                                       c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'could not derive item description and sku for item_id:'
                                    || c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                        END;

                        v_item_id       :=
                            c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id;
                        v_quantity      :=
                            c_cur_xxdo_inv_008_inc_bgrd.ebs_availability;
                        v_no_free_atp_q   :=
                            c_cur_xxdo_inv_008_inc_bgrd.no_free_atp_quantity;
                        v_item_name     := v_sku;
                        v_description   := v_item_description;

                        BEGIN
                            SELECT MAX (seq_no)
                              INTO v_max_seq_no
                              FROM xxdo_inv_int_008
                             WHERE     dc_dest_id = v_vm_id
                                   AND item_id = v_item_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                v_max_seq_no   := NULL;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'No Data Found Exception When Getting The Max Sequence Number');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Others Error When Getting The Max Sequence Number');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                        END;

                        --fnd_file.put_line(fnd_file.log,'Sequence Number Is :'||v_max_seq_no);
                        IF (NVL (v_max_seq_no, 99) > 0)
                        THEN
                            --fnd_file.put_line(fnd_file.log,'Inside The IF Condition');
                            BEGIN
                                SELECT unit_qty, (DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q))
                                  INTO v_check_qty, v_unit_qty_1
                                  FROM xxdo_inv_int_008
                                 WHERE seq_no = v_max_seq_no;
                            --fnd_file.put_line(fnd_file.log,'QTY 1 :'||v_check_qty);
                            --fnd_file.put_line(fnd_file.log,'QTY 2 :'||v_unit_qty_1);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    v_check_qty    := NULL;
                                    v_unit_qty_1   := NULL;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found Exception When Getting The Quantity for a MAX Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Error When Getting The Quantity for a MAX Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            IF (NVL (v_unit_qty_1, 1) = NVL (v_check_qty, 2))
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exiting From The Condition');
                                EXIT;
                            END IF;
                        END IF;

                        l_cntr          := 1 + l_cntr;

                        BEGIN
                            SELECT xxdo_int_008_seq.NEXTVAL
                              INTO v_s_no
                              FROM DUAL;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'No Data Found When Getting The Value Of The Sequence');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Others Data Found When Getting The Value Of The Sequence');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                        END;

                        ---------------------------------------------------------
                        -- Insert query to insert the data into xxdo_inv_int_008
                        ---------------------------------------------------------
                        ---------------------------
                        -- Beginning of the code
                        ---------------------------
                        BEGIN
                            INSERT INTO xxdo_inv_int_008 (
                                            seq_no,
                                            dc_dest_id,
                                            item_id,
                                            adjustment_reason_code,
                                            unit_qty,
                                            transshipment_nbr,
                                            from_disposition,
                                            to_disposition,
                                            from_trouble_code,
                                            to_trouble_code,
                                            from_wip_code,
                                            to_wip_code,
                                            transaction_code,
                                            user_id,
                                            create_date,
                                            po_nbr,
                                            doc_type,
                                            aux_reason_code,
                                            weight,
                                            weight_uom,
                                            unit_cost,
                                            status,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_update_by,
                                            sku,
                                            item_description,
                                            free_atp_q,
                                            no_free_atp_q,
                                            load_type,
                                            request_leg)
                                 VALUES (v_s_no, v_vm_id, v_item_id,
                                         10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                         , 'Initial Load', l_re_leg);

                            NULL; --Added by Barath for Japan ATR change#ENHC0012072

                            IF l_cntr = 2000
                            THEN
                                fnd_file.put_line (fnd_file.LOG,
                                                   'l_cntr 0 ' || l_cntr);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'l_re_leg  0 ' || l_re_leg);
                                l_cntr     := 0;
                                l_re_leg   := 1 + l_re_leg;
                                fnd_file.put_line (fnd_file.LOG,
                                                   'l_cntr 1 ' || l_cntr);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'l_re_leg  1 ' || l_re_leg);
                            END IF;
                        --------------------
                        -- Exception Handler
                        --------------------
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'No Data Found While Inserting into the custom table');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Others Data Found While Inserting into the custom table');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                        END;
                    END LOOP;

                    COMMIT;
                END IF;

                COMMIT;
            -----------------------------------------------
            -- If the load type = INITIAL LOAD then, we need
            -- to call out the cursor :
            -- which will pull the data from the cursor
            -- and push it to the staging table which is used
            -- by RMS to fetch the value and send it to RMS
            -------------------------------------------------
            ELSIF (UPPER (v_load_type) = 'INCREMENTAL LOAD' AND UPPER (v_reprocess_flag) = 'N' AND v_style IS NULL AND v_color IS NULL)
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Incrmental Load And Reprocess Flag = N');
                fnd_file.put_line (fnd_file.LOG, 'test ');
                ----------------------------------------------------------------------------
                -- Begin loop to vary value of the cursor from cur_xxdo_inv_008_ini_load
                ----------------------------------------------------------------------------
                l_b_grade_flg   := 'N';

                BEGIN
                    SELECT 'Y'
                      INTO l_b_grade_flg
                      FROM apps.fnd_lookup_values_vl flv
                     WHERE     flv.lookup_type = 'XXDO_B_GRADE_VW'
                           AND flv.enabled_flag = 'Y'
                           AND meaning = p_vm_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_b_grade_flg   := 'N';
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'No Data Found While Deleting The Table : XXDO_INV_INT_008');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        l_b_grade_flg   := 'N';
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Others Error While Deleting The Table : XXDO_INV_INT_008');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                END;

                IF l_b_grade_flg = 'N'
                THEN
                    l_cntr     := 0;
                    l_re_leg   := 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'v_last_run_date' || v_last_run_date);
                    fnd_file.put_line (fnd_file.LOG,
                                       'v_organization' || v_organization);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'p_number_of_days' || p_number_of_days);

                    --  for c_cur_inc_identify in cur_inc_identify(v_last_run_date,
                    --                                              v_organization,
                    --                                             p_number_of_days)
                    --   loop
                    --   v_identified_item_id := c_cur_inc_identify.item_id;
                    IF l_subinventory IS NULL
                    THEN    --Added by Barath for Japan ATR change#ENHC0012072
                        fnd_file.put_line (
                            fnd_file.output,
                            'Incremental load ' || l_subinventory); --Added by Barath #ENHC0012072

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Before Incremental loop: '
                            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')); --v3.1

                        FOR c_cur_xxdo_inv_008_inc_load
                            --IN cur_xxdo_inv_008_inc_load (v_organization, v_vm_id, 'N')
                            IN cur_xxdo_inv_008_inc_load (v_organization, v_vm_id, v_free_atp
                                                          , 'N')        --v3.1
                        LOOP
                            -- fnd_file.put_line(fnd_file.log,'A-Grade Incremental');
                            --fnd_file.put_line(fnd_file.log,'start incremental load process for item_id :'||c_cur_xxdo_inv_008_inc_load.inventory_item_id);
                            --------------------------------------
                            -- Assigning the variables in the loop
                            --------------------------------------
                            BEGIN
                                /*     SELECT msi.description,                                                               --starting commented by BT Technology Team on 3/12/2014
                                          msi.segment1
                                       || '-'
                                       || msi.segment2
                                       || '-'
                                       || msi.segment3 sku
                                  INTO v_item_description,
                                       v_sku
                                  FROM mtl_system_items msi*/
                                --Ending commented by BT Technology Team on 3/12/2014
                                SELECT msi.item_description, --Staring Added by BT Technology Team on 3/12/2014
                                                             msi.item_number sku
                                  INTO v_item_description, v_sku
                                  FROM xxd_common_items_v msi --Ending Added by BT Technology Team on 3/12/2014
                                 WHERE     msi.organization_id =
                                           v_organization
                                       AND msi.inventory_item_id =
                                           c_cur_xxdo_inv_008_inc_load.inventory_item_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'could not derive item description and sku for item_id:'
                                        || c_cur_xxdo_inv_008_inc_load.inventory_item_id);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            v_item_id       :=
                                c_cur_xxdo_inv_008_inc_load.inventory_item_id;
                            v_quantity      :=
                                c_cur_xxdo_inv_008_inc_load.ebs_availability;
                            v_no_free_atp_q   :=
                                c_cur_xxdo_inv_008_inc_load.no_free_atp_quantity;
                            v_item_name     := v_sku;
                            v_description   := v_item_description;

                            BEGIN
                                SELECT MAX (seq_no)
                                  INTO v_max_seq_no
                                  FROM xxdo_inv_int_008
                                 WHERE     dc_dest_id = v_vm_id
                                       AND item_id = v_item_id;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    v_max_seq_no   := NULL;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found Exception When Getting The Max Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Error When Getting The Max Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            -- fnd_file.put_line(fnd_file.log,'Sequence Number Is :'||v_max_seq_no);
                            IF (NVL (v_max_seq_no, 99) > 0)
                            THEN
                                -- fnd_file.put_line(fnd_file.log,'Inside The IF Condition');
                                BEGIN
                                    SELECT unit_qty, (DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q))
                                      INTO v_check_qty, v_unit_qty_1
                                      FROM xxdo_inv_int_008
                                     WHERE seq_no = v_max_seq_no;
                                --fnd_file.put_line(fnd_file.log,'QTY 1 :'||v_check_qty);
                                --fnd_file.put_line(fnd_file.log,'QTY 2 :'||v_unit_qty_1);
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        v_check_qty    := NULL;
                                        v_unit_qty_1   := NULL;
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'No Data Found Exception When Getting The Quantity for a MAX Sequence Number');
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Message :' || SQLERRM);
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'Others Error When Getting The Quantity for a MAX Sequence Number');
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Message :' || SQLERRM);
                                END;

                                IF (NVL (v_unit_qty_1, 1) = NVL (v_check_qty, 2))
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Exiting From The Condition');
                                    EXIT;
                                END IF;
                            END IF;

                            l_cntr          := 1 + l_cntr;

                            BEGIN
                                SELECT xxdo_int_008_seq.NEXTVAL
                                  INTO v_s_no
                                  FROM DUAL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found When Getting The Value Of The Sequence');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Data Found When Getting The Value Of The Sequence');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            ---------------------------------------------------------
                            -- Insert query to insert the data into xxdo_inv_int_008
                            ---------------------------------------------------------
                            ---------------------------
                            -- Beginning of the code
                            ---------------------------
                            BEGIN
                                INSERT INTO xxdo_inv_int_008 (
                                                seq_no,
                                                dc_dest_id,
                                                item_id,
                                                adjustment_reason_code,
                                                unit_qty,
                                                transshipment_nbr,
                                                from_disposition,
                                                to_disposition,
                                                from_trouble_code,
                                                to_trouble_code,
                                                from_wip_code,
                                                to_wip_code,
                                                transaction_code,
                                                user_id,
                                                create_date,
                                                po_nbr,
                                                doc_type,
                                                aux_reason_code,
                                                weight,
                                                weight_uom,
                                                unit_cost,
                                                status,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_update_by,
                                                sku,
                                                item_description,
                                                free_atp_q,
                                                no_free_atp_q,
                                                load_type,
                                                request_leg)
                                     VALUES (v_s_no, v_vm_id, v_item_id,
                                             10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                             , 'Incremental Load', l_re_leg);

                                NULL;           --Added by Barath #ENHC0012072

                                IF l_cntr = 2000
                                THEN
                                    fnd_file.put_line (fnd_file.LOG,
                                                       'l_cntr 0 ' || l_cntr);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg  0 ' || l_re_leg);
                                    l_cntr     := 0;
                                    l_re_leg   := 1 + l_re_leg;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       'l_cntr 1 ' || l_cntr);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg  1 ' || l_re_leg);
                                END IF;
                            --------------------
                            -- Exception Handler
                            --------------------
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found While Inserting into the custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Data Found While Inserting into the custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;
                        END LOOP;

                        --Start changes for 3.2
                        COMMIT;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Start Eligible ASN Load Incremental loop: '
                            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Profile - XXD_INV_ASN_FETCH_DAYS: '
                            || ln_asn_fetch_days);

                        --Insert Eligible ASN Load records during Incremental Load
                        ln_loop_cntr   := 0;

                        FOR r_asn_008_load
                            IN cur_eligible_asn_008_load (v_organization,
                                                          v_free_atp,
                                                          p_vm_id,
                                                          ln_asn_fetch_days)
                        LOOP
                            BEGIN
                                SELECT item_number, item_description
                                  INTO v_item_name, v_description
                                  FROM xxd_common_items_v xci
                                 WHERE     xci.inventory_item_id =
                                           r_asn_008_load.inventory_item_id
                                       AND xci.organization_id =
                                           v_organization;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Unable to derive SKU and Item Desc: '
                                        || SQLERRM
                                        || SQLCODE);
                            END;


                            --Assign variables
                            v_item_id    := r_asn_008_load.inventory_item_id;
                            v_quantity   := r_asn_008_load.quantity;
                            v_no_free_atp_q   :=
                                r_asn_008_load.no_free_atp_quantity;
                            l_cntr       := 1 + l_cntr;

                            BEGIN
                                SELECT xxdo_int_008_seq.NEXTVAL
                                  INTO v_s_no
                                  FROM DUAL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found When Getting Sequence in Eligbile ASN load');
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Error When Getting Sequence in Eligbile ASN  load');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code: ' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message: ' || SQLERRM);
                            END;

                            -- Insert Eligbile ASN records into xxdo_inv_int_008
                            BEGIN
                                INSERT INTO xxdo_inv_int_008 (
                                                seq_no,
                                                dc_dest_id,
                                                item_id,
                                                adjustment_reason_code,
                                                unit_qty,
                                                transshipment_nbr,
                                                from_disposition,
                                                to_disposition,
                                                from_trouble_code,
                                                to_trouble_code,
                                                from_wip_code,
                                                to_wip_code,
                                                transaction_code,
                                                user_id,
                                                create_date,
                                                po_nbr,
                                                doc_type,
                                                aux_reason_code,
                                                weight,
                                                weight_uom,
                                                unit_cost,
                                                status,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_update_by,
                                                sku,
                                                item_description,
                                                free_atp_q,
                                                no_free_atp_q,
                                                load_type,
                                                request_leg)
                                     VALUES (v_s_no, v_vm_id, v_item_id,
                                             10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                             , 'Incremental Load', l_re_leg);

                                ln_loop_cntr   := ln_loop_cntr + 1;

                                IF l_cntr = 2000
                                THEN
                                    l_cntr     := 0;
                                    l_re_leg   := 1 + l_re_leg;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg value: ' || l_re_leg);
                                END IF;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found While Inserting additional data into custom table');
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Error While Inserting additional data into custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code: ' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message: ' || SQLERRM);
                            END;
                        END LOOP;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Total ASN SKUs Count: ' || ln_loop_cntr);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'End Eligible ASN Load Incremental loop: '
                            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')); --v3.2
                    --End changes for 3.2

                    --Added by Barath #ENHC0012072 begin
                    ELSE
                        fnd_file.put_line (
                            fnd_file.output,
                            'Incremental load ' || l_subinventory);

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Before dsubinv Incr loop: '
                            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')); --v3.1

                        FOR c_cur_xxdo_inv_008_inc_dsubinv
                            IN cur_xxdo_inv_008_inc_dsubinv (v_organization,
                                                             v_vm_id,
                                                             'N',
                                                             l_subinventory)
                        LOOP
                            -- fnd_file.put_line(fnd_file.log,'b-grade incremental');
                            -- fnd_file.put_line(fnd_file.log,'start incremental load process for item_id :'||c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id);
                            --------------------------------------
                            -- Assigning the variables in the loop
                            --------------------------------------
                            BEGIN
                                /*     SELECT msi.description,                                                               --starting commented by BT Technology Team on 3/12/2014
                                         msi.segment1
                                      || '-'
                                      || msi.segment2
                                      || '-'
                                      || msi.segment3 sku
                                 INTO v_item_description,
                                      v_sku
                                 FROM mtl_system_items msi*/
                                --Ending commented by BT Technology Team on 3/12/2014
                                SELECT msi.item_description, --Staring Added by BT Technology Team on 3/12/2014
                                                             msi.item_number sku
                                  INTO v_item_description, v_sku
                                  FROM xxd_common_items_v msi --Ending Added by BT Technology Team on 3/12/2014
                                 WHERE     msi.organization_id =
                                           v_organization
                                       AND msi.inventory_item_id =
                                           c_cur_xxdo_inv_008_inc_dsubinv.inventory_item_id;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'could not derive item description and sku for item_id:'
                                        || c_cur_xxdo_inv_008_inc_dsubinv.inventory_item_id);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            v_item_id       :=
                                c_cur_xxdo_inv_008_inc_dsubinv.inventory_item_id;
                            v_quantity      :=
                                c_cur_xxdo_inv_008_inc_dsubinv.ebs_availability;
                            v_no_free_atp_q   :=
                                c_cur_xxdo_inv_008_inc_dsubinv.no_free_atp_quantity;
                            v_item_name     := v_sku;
                            v_description   := v_item_description;

                            BEGIN
                                SELECT MAX (seq_no)
                                  INTO v_max_seq_no
                                  FROM xxdo_inv_int_008
                                 WHERE     dc_dest_id = v_vm_id
                                       AND item_id = v_item_id;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    v_max_seq_no   := NULL;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found Exception When Getting The Max Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Error When Getting The Max Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            --fnd_file.put_line(fnd_file.log,'Sequence Number Is :'||v_max_seq_no);
                            IF (NVL (v_max_seq_no, 99) > 0)
                            THEN
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Inside The IF Condition');

                                BEGIN
                                    SELECT unit_qty, (DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q))
                                      INTO v_check_qty, v_unit_qty_1
                                      FROM xxdo_inv_int_008
                                     WHERE seq_no = v_max_seq_no;
                                --fnd_file.put_line(fnd_file.log,'QTY 1 :'||v_check_qty);
                                --fnd_file.put_line(fnd_file.log,'QTY 2 :'||v_unit_qty_1);
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        v_check_qty    := NULL;
                                        v_unit_qty_1   := NULL;
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'No Data Found Exception When Getting The Quantity for a MAX Sequence Number');
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Message :' || SQLERRM);
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'Others Error When Getting The Quantity for a MAX Sequence Number');
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Code :' || SQLCODE);
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'SQL Error Message :' || SQLERRM);
                                END;

                                IF (NVL (v_unit_qty_1, 1) = NVL (v_check_qty, 2))
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Exiting From The Condition');
                                    EXIT;
                                END IF;
                            END IF;

                            l_cntr          := 1 + l_cntr;

                            BEGIN
                                SELECT xxdo_int_008_seq.NEXTVAL
                                  INTO v_s_no
                                  FROM DUAL;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found When Getting The Value Of The Sequence');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Data Found When Getting The Value Of The Sequence');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            ---------------------------------------------------------
                            -- Insert query to insert the data into xxdo_inv_int_008
                            ---------------------------------------------------------
                            ---------------------------
                            -- Beginning of the code
                            ---------------------------
                            BEGIN
                                INSERT INTO xxdo_inv_int_008 (
                                                seq_no,
                                                dc_dest_id,
                                                item_id,
                                                adjustment_reason_code,
                                                unit_qty,
                                                transshipment_nbr,
                                                from_disposition,
                                                to_disposition,
                                                from_trouble_code,
                                                to_trouble_code,
                                                from_wip_code,
                                                to_wip_code,
                                                transaction_code,
                                                user_id,
                                                create_date,
                                                po_nbr,
                                                doc_type,
                                                aux_reason_code,
                                                weight,
                                                weight_uom,
                                                unit_cost,
                                                status,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_update_by,
                                                sku,
                                                item_description,
                                                free_atp_q,
                                                no_free_atp_q,
                                                load_type,
                                                request_leg)
                                     VALUES (v_s_no, v_vm_id, v_item_id,
                                             10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                             , 'Incremental Load', l_re_leg);

                                NULL;

                                IF l_cntr = 2000
                                THEN
                                    fnd_file.put_line (fnd_file.LOG,
                                                       'l_cntr 0 ' || l_cntr);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg  0 ' || l_re_leg);
                                    l_cntr     := 0;
                                    l_re_leg   := 1 + l_re_leg;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       'l_cntr 1 ' || l_cntr);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'l_re_leg  1 ' || l_re_leg);
                                END IF;
                            --------------------
                            -- Exception Handler
                            --------------------
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found While Inserting into the custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Data Found While Inserting into the custom table');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;
                        END LOOP;
                    END IF;                 --Added by Barath #ENHC0012072 end
                ELSE
                    ----b-grade change
                    l_cntr     := 0;
                    l_re_leg   := 1;
                    fnd_file.put_line (
                        fnd_file.output,
                        'Incremental load B-grade' || l_subinventory); --Added by Barath #ENHC0012072

                    ---------------------------------------------------------------
                    -- Changes done by Sivakumar Boothathan for China Bgrade V2.2
                    ---------------------------------------------------------------
                    BEGIN
                        SELECT tag
                          INTO v_bg_subinv
                          FROM apps.fnd_lookup_values
                         WHERE     lookup_type = 'XXDO_B_GRADE_VW'
                               AND language = 'US'
                               AND lookup_code = v_vm_id
                               AND enabled_flag = 'Y'
                               AND NVL (TRUNC (end_date_active),
                                        TRUNC (SYSDATE + 1)) >=
                                   TRUNC (SYSDATE);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Couldnt find the BG Sub inventory');
                    END;

                    -------------------------------------------------------------------
                    -- End of changes By Sivakumar Boothathan for China Bgrade V2.2
                    -------------------------------------------------------------------

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Before bgrd Incr loop: '
                        || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')); --v3.1

                    FOR c_cur_xxdo_inv_008_inc_bgrd
                        IN cur_xxdo_inv_008_inc_bgrd (v_organization, v_vm_id, 'N'
                                                      , v_bg_subinv)
                    LOOP
                        -- fnd_file.put_line(fnd_file.log,'b-grade incremental');
                        -- fnd_file.put_line(fnd_file.log,'start incremental load process for item_id :'||c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id);
                        --------------------------------------
                        -- Assigning the variables in the loop
                        --------------------------------------
                        BEGIN
                            /*     SELECT msi.description,                                                               --starting commented by BT Technology Team on 3/12/2014
                                         msi.segment1
                                      || '-'
                                      || msi.segment2
                                      || '-'
                                      || msi.segment3 sku
                                 INTO v_item_description,
                                      v_sku
                                 FROM mtl_system_items msi*/
                            --Ending commented by BT Technology Team on 3/12/2014
                            SELECT msi.item_description, --Staring Added by BT Technology Team on 3/12/2014
                                                         msi.item_number sku
                              INTO v_item_description, v_sku
                              FROM xxd_common_items_v msi --Ending Added by BT Technology Team on 3/12/2014
                             WHERE     msi.organization_id = v_organization
                                   AND msi.inventory_item_id =
                                       c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'could not derive item description and sku for item_id:'
                                    || c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                        END;

                        v_item_id       :=
                            c_cur_xxdo_inv_008_inc_bgrd.inventory_item_id;
                        v_quantity      :=
                            c_cur_xxdo_inv_008_inc_bgrd.ebs_availability;
                        v_no_free_atp_q   :=
                            c_cur_xxdo_inv_008_inc_bgrd.no_free_atp_quantity;
                        v_item_name     := v_sku;
                        v_description   := v_item_description;

                        BEGIN
                            SELECT MAX (seq_no)
                              INTO v_max_seq_no
                              FROM xxdo_inv_int_008
                             WHERE     dc_dest_id = v_vm_id
                                   AND item_id = v_item_id;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                v_max_seq_no   := NULL;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'No Data Found Exception When Getting The Max Sequence Number');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Others Error When Getting The Max Sequence Number');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                        END;

                        --fnd_file.put_line(fnd_file.log,'Sequence Number Is :'||v_max_seq_no);
                        IF (NVL (v_max_seq_no, 99) > 0)
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'Inside The IF Condition');

                            BEGIN
                                SELECT unit_qty, (DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q))
                                  INTO v_check_qty, v_unit_qty_1
                                  FROM xxdo_inv_int_008
                                 WHERE seq_no = v_max_seq_no;
                            --fnd_file.put_line(fnd_file.log,'QTY 1 :'||v_check_qty);
                            --fnd_file.put_line(fnd_file.log,'QTY 2 :'||v_unit_qty_1);
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    v_check_qty    := NULL;
                                    v_unit_qty_1   := NULL;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'No Data Found Exception When Getting The Quantity for a MAX Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Others Error When Getting The Quantity for a MAX Sequence Number');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Code :' || SQLCODE);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'SQL Error Message :' || SQLERRM);
                            END;

                            IF (NVL (v_unit_qty_1, 1) = NVL (v_check_qty, 2))
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Exiting From The Condition');
                                EXIT;
                            END IF;
                        END IF;

                        l_cntr          := 1 + l_cntr;

                        BEGIN
                            SELECT xxdo_int_008_seq.NEXTVAL
                              INTO v_s_no
                              FROM DUAL;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'No Data Found When Getting The Value Of The Sequence');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Others Data Found When Getting The Value Of The Sequence');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                        END;

                        ---------------------------------------------------------
                        -- Insert query to insert the data into xxdo_inv_int_008
                        ---------------------------------------------------------
                        ---------------------------
                        -- Beginning of the code
                        ---------------------------
                        BEGIN
                            INSERT INTO xxdo_inv_int_008 (
                                            seq_no,
                                            dc_dest_id,
                                            item_id,
                                            adjustment_reason_code,
                                            unit_qty,
                                            transshipment_nbr,
                                            from_disposition,
                                            to_disposition,
                                            from_trouble_code,
                                            to_trouble_code,
                                            from_wip_code,
                                            to_wip_code,
                                            transaction_code,
                                            user_id,
                                            create_date,
                                            po_nbr,
                                            doc_type,
                                            aux_reason_code,
                                            weight,
                                            weight_uom,
                                            unit_cost,
                                            status,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_update_by,
                                            sku,
                                            item_description,
                                            free_atp_q,
                                            no_free_atp_q,
                                            load_type,
                                            request_leg)
                                 VALUES (v_s_no, v_vm_id, v_item_id,
                                         10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                         , 'Incremental Load', l_re_leg);

                            NULL;               --Added by Barath #ENHC0012072

                            IF l_cntr = 2000
                            THEN
                                fnd_file.put_line (fnd_file.LOG,
                                                   'l_cntr 0 ' || l_cntr);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'l_re_leg  0 ' || l_re_leg);
                                l_cntr     := 0;
                                l_re_leg   := 1 + l_re_leg;
                                fnd_file.put_line (fnd_file.LOG,
                                                   'l_cntr 1 ' || l_cntr);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'l_re_leg  1 ' || l_re_leg);
                            END IF;
                        --------------------
                        -- Exception Handler
                        --------------------
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'No Data Found While Inserting into the custom table');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Others Data Found While Inserting into the custom table');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                        END;
                    END LOOP;
                END IF;

                COMMIT;
            -----------------------
            -- End Loop
            -----------------------
            -- end loop;   --end loop cursor xxdo cur identify
            ELSIF (UPPER (v_load_type) = 'INCREMENTAL LOAD' AND UPPER (v_reprocess_flag) = 'N' AND v_style IS NOT NULL)
            THEN
                l_cntr     := 0;
                l_re_leg   := 1;

                ----------------------------------------------------------------------------
                -- Begin loop to vary value of the cursor from cur_xxdo_inv_008_ini_load
                ----------------------------------------------------------------------------

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before st_load loop: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));    --v3.1

                FOR c_cur_xxdo_inv_008_st_load
                    IN cur_xxdo_inv_008_st_load (v_organization, v_kco_header_id, v_style
                                                 , v_color, p_number_of_days)
                LOOP
                    --------------------------------------
                    -- Assigning the variables in the loop
                    --------------------------------------
                    v_item_id     :=
                        c_cur_xxdo_inv_008_st_load.inventory_item_id;
                    v_quantity    := c_cur_xxdo_inv_008_st_load.quantity;
                    v_no_free_atp_q   :=
                        c_cur_xxdo_inv_008_st_load.no_free_atp_quantity;
                    v_item_name   := c_cur_xxdo_inv_008_st_load.sku;
                    v_description   :=
                        c_cur_xxdo_inv_008_st_load.item_description;

                    BEGIN
                        SELECT MAX (seq_no)
                          INTO v_max_seq_no
                          FROM xxdo_inv_int_008
                         WHERE dc_dest_id = v_vm_id AND item_id = v_item_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            v_max_seq_no   := NULL;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'No Data Found Exception When Getting The Max Sequence Number');
                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Others Error When Getting The Max Sequence Number');
                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;

                    --fnd_file.put_line(fnd_file.log,'Sequence Number Is :'||v_max_seq_no);
                    IF (NVL (v_max_seq_no, 99) > 0)
                    THEN
                        --fnd_file.put_line(fnd_file.log,'Inside The IF Condition');
                        BEGIN
                            SELECT unit_qty, (DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q))
                              INTO v_check_qty, v_unit_qty_1
                              FROM xxdo_inv_int_008
                             WHERE seq_no = v_max_seq_no;
                        --fnd_file.put_line(fnd_file.log,'QTY 1 :'||v_check_qty);
                        --fnd_file.put_line(fnd_file.log,'QTY 2 :'||v_unit_qty_1);
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                v_check_qty    := NULL;
                                v_unit_qty_1   := NULL;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'No Data Found Exception When Getting The Quantity for a MAX Sequence Number');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Others Error When Getting The Quantity for a MAX Sequence Number');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Code :' || SQLCODE);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'SQL Error Message :' || SQLERRM);
                        END;

                        IF (NVL (v_unit_qty_1, 1) = NVL (v_check_qty, 2))
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'Exiting From The Condition');
                            EXIT;
                        END IF;
                    END IF;

                    l_cntr        := 1 + l_cntr;

                    BEGIN
                        SELECT xxdo_int_008_seq.NEXTVAL INTO v_s_no FROM DUAL;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'No Data Found When Getting The Value Of The Sequence');
                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Others Data Found When Getting The Value Of The Sequence');
                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;

                    ---------------------------------------------------------
                    -- Insert query to insert the data into xxdo_inv_int_008
                    ---------------------------------------------------------
                    ---------------------------
                    -- Beginning of the code
                    ---------------------------
                    BEGIN
                        INSERT INTO xxdo_inv_int_008 (seq_no,
                                                      dc_dest_id,
                                                      item_id,
                                                      adjustment_reason_code,
                                                      unit_qty,
                                                      transshipment_nbr,
                                                      from_disposition,
                                                      to_disposition,
                                                      from_trouble_code,
                                                      to_trouble_code,
                                                      from_wip_code,
                                                      to_wip_code,
                                                      transaction_code,
                                                      user_id,
                                                      create_date,
                                                      po_nbr,
                                                      doc_type,
                                                      aux_reason_code,
                                                      weight,
                                                      weight_uom,
                                                      unit_cost,
                                                      status,
                                                      creation_date,
                                                      created_by,
                                                      last_update_date,
                                                      last_update_by,
                                                      sku,
                                                      item_description,
                                                      free_atp_q,
                                                      no_free_atp_q,
                                                      load_type,
                                                      request_leg)
                             VALUES (v_s_no, v_vm_id, v_item_id,
                                     10, DECODE (v_free_atp,  'Y', v_quantity,  'N', v_no_free_atp_q), NULL, NULL, 'ATS', NULL, NULL, NULL, NULL, NULL, 'RMS13PROD', TRUNC (SYSDATE), NULL, NULL, NULL, NULL, NULL, NULL, 'N', SYSDATE, v_user_id, SYSDATE, v_user_id, v_item_name, v_description, v_quantity, v_no_free_atp_q
                                     , 'Incremental Load', l_re_leg);

                        IF l_cntr = 2000
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'l_cntr 0 ' || l_cntr);
                            fnd_file.put_line (fnd_file.LOG,
                                               'l_re_leg  0 ' || l_re_leg);
                            l_cntr     := 0;
                            l_re_leg   := 1 + l_re_leg;
                            fnd_file.put_line (fnd_file.LOG,
                                               'l_cntr 1 ' || l_cntr);
                            fnd_file.put_line (fnd_file.LOG,
                                               'l_re_leg  1 ' || l_re_leg);
                        END IF;
                    --------------------
                    -- Exception Handler
                    --------------------
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'No Data Found While Inserting into the custom table');
                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Others Data Found While Inserting into the custom table');
                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;
                -----------------------
                -- End Loop
                -----------------------
                END LOOP;

                COMMIT;
            ----------------------------------------------------
            -- If the load type = Incremental Load and if the
            -- reprocess flag = Y then we need to update the
            -- custom table with the status as N, user_id =
            -- v_user_id and in the where condition we need to
            -- make use of the parameters from and to date
            ----------------------------------------------------
            ELSIF (UPPER (v_load_type) = 'INCREMENTAL LOAD' AND UPPER (v_reprocess_flag) = 'Y')
            THEN
                --------------
                -- Log Message
                --------------
                fnd_file.put_line (fnd_file.LOG,
                                   'Incremental Load And Reprocess Flag = Y');

                --------------------------------------------------------------------------------------
                -- Update the custom table : xxdo_inv_int_008 for the date provided for reprocessing
                --------------------------------------------------------------------------------------
                BEGIN
                    UPDATE xxdo_inv_int_008
                       SET status = 'N', processed_flag = NULL, last_update_by = v_user_id
                     WHERE     dc_dest_id = v_vm_id
                           AND processed_flag = 'VE'
                           AND TRUNC (last_update_date) >=
                               TRUNC (
                                   TO_DATE (v_reprocess_from_date,
                                            'YYYY/MM/DD HH24:MI:SS'))
                           AND TRUNC (last_update_date) <=
                               TRUNC (
                                   TO_DATE (v_reprocess_to_date,
                                            'YYYY/MM/DD HH24:MI:SS'));
                --------------------
                -- Exception Handler
                --------------------
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'No Data Found While Updating the custom table');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Others Data Found While Updating the custom table');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                END;

                COMMIT;
            ----------------------------------------------------
            -- If the load type = INITIAL Load and if the
            -- reprocess flag = Y then we need to error out the
            -- concurrent as this is not the right parameters to
            -- select from
            ----------------------------------------------------
            ELSIF (UPPER (v_load_type) = 'INITIAL LOAD' AND UPPER (v_reprocess_flag) = 'Y')
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Initial Load And Reprocess Flag = Y');
                ----------------------------------------------------------------
                -- Assigning retcode = 2 which will error out the concurrent
                ----------------------------------------------------------------
                retcode   := 2;
                fnd_file.put_line (fnd_file.LOG,
                                   'INITIAL Load Cannot be reprocessed');
                fnd_file.put_line (fnd_file.output,
                                   'INITIAL Load Cannot Be Reprocessed');
            END IF;

            -------------
            -- commit
            -------------
            COMMIT;

            ---------------------------------------------------------
            -- If The Load Type = Incremental then we need
            -- Call the procedure which will use a different
            -- name space and then create a file and send it
            -- to a test server
            ---------------------------------------------------------
            IF (UPPER (v_load_type) = 'INCREMENTAL LOAD' OR (UPPER (v_load_type) = 'INITIAL LOAD' AND UPPER (v_reprocess_flag) = 'N'))
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Submitting Threads');

                ------------------------
                -- Calling the procedure
                ------------------------
                /*BEGIN
                   SELECT NVL (MAX (request_leg), 0)
                     INTO l_thread_cnt
                     FROM xxdo_inv_int_008
                    WHERE status = 'N' AND processed_flag IS NULL;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      l_thread_cnt := 0;
                      fnd_file.put_line (fnd_file.LOG,
                                         'Error while finding the no of threads');
                      fnd_file.put_line (fnd_file.LOG,
                                         'SQL Error Code :' || SQLCODE);
                      fnd_file.put_line (fnd_file.LOG,
                                         'SQL Error Message :' || SQLERRM);
                END;

                fnd_file.put_line (fnd_file.LOG, 'l_thread_cnt ' || l_thread_cnt);*/
                ----Commented by Infosys for version 2.1

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before l_req_leg_cur loop: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));    --v3.1

                FOR i IN l_req_leg_cur      --Added By infosys for version 2.1
                LOOP
                    ln_request_id   := xxdo.XXD_OM_RETAIL_ATR_S.NEXTVAL; --start as part of 3.0

                    BEGIN
                        UPDATE xxdo_inv_int_008
                           SET request_id   = ln_request_id
                         WHERE     status = 'N'
                               AND processed_flag IS NULL
                               AND request_leg = i.request_leg
                               AND dc_dest_id = i.dc_dest_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'Error updating request id');
                            fnd_file.put_line (fnd_file.LOG,
                                               'SQL Error Code :' || SQLCODE);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'SQL Error Message :' || SQLERRM);
                    END;

                    BEGIN
                        apps.wf_event.RAISE (p_event_name => 'oracle.apps.xxdo.retail_atr_event', p_event_key => TO_CHAR (ln_request_id), p_event_data => NULL
                                             , p_parameters => NULL);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_retcode   := 2;
                            retcode      := lv_retcode;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error Message from event call :'
                                || apps.fnd_api.g_ret_sts_error
                                || ' SQL Error '
                                || SQLERRM);
                    END;

                    COMMIT;                              -- end as part of 3.0
                /*  FOR i IN 1 .. l_thread_cnt*/
                                        --Commented by Infosys for version 2.1


                /*   --Commented  as part of 3.0

                           ln_request_id :=
                              fnd_request.submit_request (
                                 application   => 'XXDO',
                                 program       => 'XXDOINV011A',
                                 description   => 'XXDO INV INT 008 ATR Retail Integration webservices',
                                 start_time    => SYSDATE,
                                 sub_request   => NULL,
                                 argument1     => 100,
                                 --argument2     => i                     --commented by infosys for version 2.1
                     argument2     => i.request_leg,          --Added By infosys for version 2.1
                     argument3     =>i.dc_dest_id              --Added By infosys for version 2.1
                     );
                           /*fnd_file.put_line (
                              fnd_file.LOG,
                              'Submitted Thread ' || i || 'Request id ' || ln_request_id);*/
                                        --commented by infosys for version 2.1

                /*      fnd_file.put_line (
                               fnd_file.LOG,
                               'Submitted Thread Request id : ' || ln_request_id);  --Added By infosys for version 2.1

                            BEGIN
                               UPDATE xxdo_inv_int_008
                                  SET request_id = ln_request_id
                                WHERE     status = 'N'
                                      AND processed_flag IS NULL
                                      --AND request_leg = i                     --commented by infosys for version 2.1
                       AND request_leg = i.request_leg    --Added By infosys for version 2.1
                       AND dc_dest_id=i.dc_dest_id      --Added By infosys for version 2.1
                       ;
                            EXCEPTION
                               WHEN OTHERS
                               THEN
                                  --l_thread_cnt := 0;     --commented by infosys for version 2.1
                                  fnd_file.put_line (fnd_file.LOG,
                                                     'Error updating request id');
                                  fnd_file.put_line (fnd_file.LOG,
                                                     'SQL Error Code :' || SQLCODE);
                                  fnd_file.put_line (fnd_file.LOG,
                                                     'SQL Error Message :' || SQLERRM);
                            END;

                            BEGIN
                               UPDATE xxdo_inv_int_xml_008
                                  SET request_id = ln_request_id, processed_flag = 'P'
                                WHERE processed_flag = 'Y'
                    --AND request_leg = i                            --commented by infosys for version 2.1
                    AND request_leg = i.request_leg    --Added By infosys for version 2.1
                    AND dc_dest_id=i.dc_dest_id     --Added By infosys for version 2.1
                    ;
                            EXCEPTION
                               WHEN OTHERS
                               THEN
                                  --l_thread_cnt := 0                           --commented by infosys for version 2.1
                                  fnd_file.put_line (fnd_file.LOG,
                                                     'Error updating request id');
                                  fnd_file.put_line (fnd_file.LOG,
                                                     'SQL Error Code :' || SQLCODE);
                                  fnd_file.put_line (fnd_file.LOG,
                                                     'SQL Error Message :' || SQLERRM);
                            END;

                   */

                END LOOP;

                -- xxdo_inv_int_pub_atr_p;
                COMMIT;
            --end if;
            END IF;
        /*  commented as part of 3.0
          -------------------------------------------
          FOR j IN xxdo_request_cur
          LOOP
             IF j.request_id <> 0
             THEN
                /***************************************************************
                  calling   fnd_concurrent.get_request_status to
                  get the status of the request submitted
                *****************************************************************/

          /*  commented as part of 3.0
      lb_concreqcallstat :=
         apps.fnd_concurrent.get_request_status (
            request_id       => j.request_id,
            appl_shortname   => NULL,
            program          => NULL,
            phase            => lv_phase,
            status           => lv_status,
            dev_phase        => lv_dev_phase,
            dev_status       => lv_dev_status,
            MESSAGE          => lv_message);

      LOOP
         lb_concreqcallstat :=
            apps.fnd_concurrent.wait_for_request (
               request_id   => j.request_id,
               INTERVAL     => 10,
               phase        => lv_phase,
               status       => lv_status,
               dev_phase    => lv_dev_phase,
               dev_status   => lv_dev_status,
               MESSAGE      => lv_message);
         EXIT WHEN lv_dev_phase = 'COMPLETE';
      END LOOP;

      IF lv_dev_status <> 'NORMAL'
      THEN
         lv_retcode := 2;
         retcode := lv_retcode;
      END IF;
   END IF;
END LOOP;

 */
        --commented as part of 3.0
        -------------------------
        -- End Of The Procedure
        -------------------------
        END IF;                                      --- gaurav -- changes end

        fnd_file.put_line (
            fnd_file.LOG,
            'End of program: ' || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS')); --v3.1
    END;

    -----------------------------------------------------------------------------
    -- This procedure will be called to publish the data to another custom table
    -- which is used to send the data to RIB
    -----------------------------------------------------------------------------
    PROCEDURE xxdo_inv_int_pub_atr_p (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_cur_limit IN NUMBER
                                      , p_request_leg IN NUMBER)
    IS
        ---------------------------------------------
        -- cursor cur_int_atr_pub is to
        -- retrive the records from the staging table
        -- and then publish it to the 2nd staging tabl
        -- for sending the xml data to RMS
        ---------------------------------------------
        CURSOR cur_int_atr_pub IS
            SELECT seq_no,
                   dc_dest_id,
                   item_id,
                   adjustment_reason_code,
                   unit_qty,
                   transshipment_nbr,
                   from_disposition,
                   to_disposition,
                   from_trouble_code,
                   to_trouble_code,
                   from_wip_code,
                   to_wip_code,
                   transaction_code,
                   user_id,
                   create_date,
                   po_nbr,
                   doc_type,
                   aux_reason_code,
                   weight,
                   weight_uom,
                   unit_cost,
                   status,
                   creation_date,
                   created_by,
                   last_update_date,
                   last_update_by,
                   sku,
                   item_description,
                   free_atp_q,
                   no_free_atp_q,
                   load_type,
                   (SELECT XMLELEMENT (
                               "v1:InvAdjustDesc",
                               XMLELEMENT ("v1:dc_dest_id", dc_dest_id),
                               XMLELEMENT (
                                   "v1:InvAdjustDtl",
                                   XMLELEMENT ("v1:item_id", item_id),
                                   XMLELEMENT ("v1:adjustment_reason_code",
                                               adjustment_reason_code),
                                   XMLELEMENT ("v1:unit_qty", unit_qty),
                                   XMLELEMENT ("v1:transshipment_nbr",
                                               transshipment_nbr),
                                   XMLELEMENT ("v1:from_disposition",
                                               from_disposition),
                                   XMLELEMENT ("v1:to_disposition",
                                               to_disposition),
                                   XMLELEMENT ("v1:from_trouble_code",
                                               from_trouble_code),
                                   XMLELEMENT ("v1:to_trouble_code",
                                               to_trouble_code),
                                   XMLELEMENT ("v1:from_wip_code",
                                               from_wip_code),
                                   XMLELEMENT ("v1:to_wip_code", to_wip_code),
                                   XMLELEMENT ("v1:transaction_code",
                                               transaction_code),
                                   XMLELEMENT ("v1:user_id", user_id),
                                   XMLELEMENT ("v1:create_date", create_date),
                                   XMLELEMENT ("v1:po_nbr", po_nbr),
                                   XMLELEMENT ("v1:doc_type", doc_type),
                                   XMLELEMENT ("v1:aux_reason_code",
                                               aux_reason_code),
                                   XMLELEMENT ("v1:weight", weight),
                                   XMLELEMENT ("v1:weight_uom", weight_uom),
                                   XMLELEMENT ("v1:unit_cost", unit_cost))) xml
                      FROM DUAL) xml_data
              FROM xxdo_inv_int_008
             WHERE     status = 'N'
                   AND processed_flag IS NULL
                   AND request_leg = p_request_leg              --- for update
                                                  ;

        --and    load_type = 'Incremental Load'
        CURSOR cur_int_atr_pub_upd IS
            SELECT *
              FROM xxdo_inv_int_008
             WHERE     status = 'N'
                   AND processed_flag IS NULL
                   AND request_leg = p_request_leg               -- for update
                                                  ;

        ----------------------
        -- Declaring Variables
        ----------------------
        lv_wsdl_ip                 VARCHAR2 (25) := NULL;
        lv_wsdl_url                VARCHAR2 (4000) := NULL;
        lv_namespace               VARCHAR2 (4000) := NULL;
        lv_service                 VARCHAR2 (4000) := NULL;
        lv_port                    VARCHAR2 (4000) := NULL;
        lv_operation               VARCHAR2 (4000) := NULL;
        lv_targetname              VARCHAR2 (4000) := NULL;
        lx_xmltype_in              SYS.XMLTYPE;
        lx_xmltype_out             SYS.XMLTYPE;
        v_xml_data                 CLOB;
        lc_return                  CLOB;
        lv_op_mode                 VARCHAR2 (60) := NULL;
        lv_errmsg                  VARCHAR2 (240) := NULL;
        v_dc_dest_id               VARCHAR2 (240) := NULL;
        v_item_id                  NUMBER := 0;
        v_adjustment_reason_code   VARCHAR2 (240) := NULL;
        v_unit_qty                 NUMBER := 0;
        v_transshipment_nbr        VARCHAR2 (240) := NULL;
        v_from_disposition         VARCHAR2 (240) := NULL;
        v_to_disposition           VARCHAR2 (240) := NULL;
        v_from_trouble_code        VARCHAR2 (240) := NULL;
        v_to_trouble_code          VARCHAR2 (240) := NULL;
        v_from_wip_code            VARCHAR2 (240) := NULL;
        v_to_wip_code              VARCHAR2 (240) := NULL;
        v_transaction_code         VARCHAR2 (240) := NULL;
        v_user_id                  VARCHAR2 (240) := 0;
        v_create_date              DATE;
        v_po_nbr                   VARCHAR2 (240) := NULL;
        v_doc_type                 VARCHAR2 (240) := NULL;
        v_aux_reason_code          VARCHAR2 (240) := NULL;
        v_weight                   NUMBER := 0;
        v_weight_uom               VARCHAR2 (240) := NULL;
        v_unit_cost                NUMBER := 0;
        v_status                   VARCHAR2 (240) := NULL;
        v_creation_date            DATE;
        v_created_by               NUMBER := 0;
        v_last_update_date         DATE;
        v_last_update_by           NUMBER := 0;
        v_sku                      VARCHAR2 (240) := NULL;
        v_item_description         VARCHAR2 (240) := NULL;
        v_free_atp_q               NUMBER := 0;
        v_no_free_atp_q            NUMBER := 0;
        v_load_type                VARCHAR2 (240) := NULL;
        --      v_s_no                     number           := 0                       ;
        v_seq_no                   NUMBER := 0;
        l_cur_limit                NUMBER := 0;

        TYPE atr_type IS TABLE OF cur_int_atr_pub_upd%ROWTYPE
            INDEX BY PLS_INTEGER;

        atr_type_tbl               atr_type;
        l_xmldata                  SYS.XMLTYPE;
        PRAGMA AUTONOMOUS_TRANSACTION;
    ---------------------------------
    -- Beginning of the procedure
    --------------------------------
    BEGIN
        ----------------------------------
        -- To get the profile values
        ----------------------------------
        BEGIN
            SELECT DECODE (applications_system_name,  -- Start of modification by BT Technology Team on 17-Feb-2016 V2.0
                                                      --'PROD', apps.fnd_profile.VALUE ('XXDO: RETAIL PROD'),
                                                      'EBSPROD', apps.fnd_profile.VALUE ('XXDO: RETAIL PROD'),  -- End of modification by BT Technology Team on 17-Feb-2016 V2.0

                                                                                                                'PCLN', apps.fnd_profile.VALUE ('XXDO: RETAIL DEV'),  apps.fnd_profile.VALUE ('XXDO: RETAIL TEST')) file_server_name
              INTO lv_wsdl_ip
              FROM apps.fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (apps.fnd_file.LOG,
                                   'Unable to fetch the File server name');
        END;

        --------------------------------------------------------------
        -- Initializing the variables for calling the webservices
        -- The webservices takes the input parameter as wsd URL,
        -- name space, service, port, operation and target name
        --------------------------------------------------------------
        lv_wsdl_url     :=
               'http://'
            || lv_wsdl_ip
            || '//InvAdjustPublishingBean/InvAdjustPublishingService?WSDL';
        lv_namespace    :=
            'http://www.oracle.com/retail/igs/integration/services/InvAdjustPublishingService/v1';
        lv_service      := 'InvAdjustPublishingService';
        lv_port         := 'InvAdjustPublishingPort';
        lv_operation    := 'publishInvAdjustCreateUsingInvAdjustDesc';
        lv_targetname   :=
               'http://'
            || lv_wsdl_ip
            || '//InvAdjustPublishingBean/InvAdjustPublishingService';

        ------------------------------------------------------------------------
        -- Begin Loop To Vary Value Of The Cursor for the loop : cur_int_atr_pub
        ------------------------------------------------------------------------

        fnd_file.put_line (
            fnd_file.LOG,
               'Before cur_int_atr_pub loop: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));            --v3.1

        FOR c_cur_int_atr IN cur_int_atr_pub
        LOOP
            ----------------------------------
            -- Assigning values to a variables
            ----------------------------------
            v_seq_no   := c_cur_int_atr.seq_no;

            -------------------------------------------------------------------
            -- insert into the custom staging table : xxdo_inv_int_008
            -------------------------------------------------------------------
            BEGIN
                UPDATE xxdo_inv_int_008
                   SET xmldata = XMLTYPE.getclobval (c_cur_int_atr.xml_data)
                 WHERE seq_no = v_seq_no AND request_leg = p_request_leg;
            --------------------
            -- Exception Handler
            --------------------
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'No Data Found While Inserting The Data');
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Code:' || SQLCODE);
                    fnd_file.put_line (fnd_file.LOG,
                                       'SQL Error Message :' || SQLERRM);

                    UPDATE xxdo_inv_int_008
                       SET status = 'VE', errorcode = 'Validation Error'
                     --where current of cur_int_atr_pub
                     WHERE seq_no = v_seq_no AND request_leg = p_request_leg;
            END;
        --  commit;
        END LOOP;

        v_seq_no        := 0;
        COMMIT;

        BEGIN
            SELECT CEIL (COUNT (*) / p_cur_limit * 1) / 1
              INTO l_cur_limit
              FROM xxdo_inv_int_008
             WHERE     status = 'N'
                   AND processed_flag IS NULL
                   AND request_leg = p_request_leg;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_cur_limit   := 0;
                fnd_file.put_line (fnd_file.LOG,
                                   'Error while finding the l_cur_limit ');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        END;

        fnd_file.put_line (fnd_file.LOG, 'l_cur_limit ' || l_cur_limit);

        fnd_file.put_line (
            fnd_file.LOG,
               'Before l_cur_limit loop: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));            --v3.1

        FOR j IN 1 .. l_cur_limit
        LOOP
            fnd_file.put_line (fnd_file.LOG, 'l_cur_limit loop ' || j);

            OPEN cur_int_atr_pub_upd;

            LOOP
                FETCH cur_int_atr_pub_upd
                    BULK COLLECT INTO atr_type_tbl
                    LIMIT p_cur_limit;

                /*  v_dc_dest_id               := c_cur_int_atr_pub.dc_dest_id                ;
                  v_item_id                  := c_cur_int_atr_pub.item_id                   ;
                  v_adjustment_reason_code   := c_cur_int_atr_pub.adjustment_reason_code    ;
                  v_unit_qty                 := c_cur_int_atr_pub.unit_qty                  ;
                  v_transshipment_nbr        := c_cur_int_atr_pub.transshipment_nbr         ;
                  v_from_disposition         := c_cur_int_atr_pub.from_disposition          ;
                  v_to_disposition           := c_cur_int_atr_pub.to_disposition            ;
                  v_from_trouble_code        := c_cur_int_atr_pub.from_trouble_code         ;
                    v_to_trouble_code          := c_cur_int_atr_pub.to_trouble_code           ;
                  v_from_wip_code            := c_cur_int_atr_pub.from_wip_code             ;
                  v_to_wip_code              := c_cur_int_atr_pub.to_wip_code               ;
                  v_transaction_code         := c_cur_int_atr_pub.transaction_code          ;
                  v_user_id                  := c_cur_int_atr_pub.user_id                   ;
                  v_create_date              := c_cur_int_atr_pub.create_date               ;
                  v_po_nbr                   := c_cur_int_atr_pub.po_nbr                    ;
                  v_doc_type                 := c_cur_int_atr_pub.doc_type                  ;
                  v_aux_reason_code          := c_cur_int_atr_pub.aux_reason_code           ;
                  v_weight                   := c_cur_int_atr_pub.weight                    ;
                  v_weight_uom               := c_cur_int_atr_pub.weight_uom                ;
                  v_unit_cost                := c_cur_int_atr_pub.unit_cost                 ;
                  v_creation_date            := c_cur_int_atr_pub.creation_date             ;
                  v_created_by               := c_cur_int_atr_pub.created_by                ;
                  v_last_update_date         := c_cur_int_atr_pub.last_update_date          ;
                  v_last_update_by           := c_cur_int_atr_pub.last_update_by            ;
                  v_SKU                      := c_cur_int_atr_pub.SKU                       ;
                  v_Item_Description         := c_cur_int_atr_pub.Item_Description          ;
                  v_Free_ATP_Q               := c_cur_int_atr_pub.Free_ATP_Q                ;
                  v_No_Free_ATP_Q            := c_cur_int_atr_pub.No_Free_ATP_Q             ;
                  v_load_type                := c_cur_int_atr_pub.load_type                 ;
                  v_seq_no                   := c_cur_int_atr_pub.seq_no                   ;*/

                -------------------------------------------------------------
                -- Assigning the variables to call the webservices function
                -------------------------------------------------------------
                EXIT WHEN atr_type_tbl.COUNT = 0;

                FOR indx IN 1 .. atr_type_tbl.COUNT
                LOOP
                    /* select xmldata into l_xmldata from xxdo_inv_int_008
                     where seq_no = atr_type_tbl(indx).seq_no
                     and rownum=1; */
                    SELECT (SELECT XMLELEMENT (
                                       "v1:InvAdjustDesc",
                                       XMLELEMENT ("v1:dc_dest_id",
                                                   dc_dest_id),
                                       XMLELEMENT (
                                           "v1:InvAdjustDtl",
                                           XMLELEMENT ("v1:item_id", item_id),
                                           XMLELEMENT (
                                               "v1:adjustment_reason_code",
                                               adjustment_reason_code),
                                           XMLELEMENT ("v1:unit_qty",
                                                       unit_qty),
                                           XMLELEMENT (
                                               "v1:transshipment_nbr",
                                               transshipment_nbr),
                                           XMLELEMENT ("v1:from_disposition",
                                                       from_disposition),
                                           XMLELEMENT ("v1:to_disposition",
                                                       to_disposition),
                                           XMLELEMENT (
                                               "v1:from_trouble_code",
                                               from_trouble_code),
                                           XMLELEMENT ("v1:to_trouble_code",
                                                       to_trouble_code),
                                           XMLELEMENT ("v1:from_wip_code",
                                                       from_wip_code),
                                           XMLELEMENT ("v1:to_wip_code",
                                                       to_wip_code),
                                           XMLELEMENT ("v1:transaction_code",
                                                       transaction_code),
                                           XMLELEMENT ("v1:user_id", user_id),
                                           XMLELEMENT ("v1:create_date",
                                                       create_date),
                                           XMLELEMENT ("v1:po_nbr", po_nbr),
                                           XMLELEMENT ("v1:doc_type",
                                                       doc_type),
                                           XMLELEMENT ("v1:aux_reason_code",
                                                       aux_reason_code),
                                           XMLELEMENT ("v1:weight", weight),
                                           XMLELEMENT ("v1:weight_uom",
                                                       weight_uom),
                                           XMLELEMENT ("v1:unit_cost",
                                                       unit_cost))) xml
                              FROM DUAL) xml_data
                      INTO l_xmldata
                      FROM xxdo_inv_int_008
                     WHERE     seq_no = atr_type_tbl (indx).seq_no
                           AND request_leg = p_request_leg;

                    --- l_xmldata :=atr_type_tbl(indx).xmldata;

                    -- fnd_file.put_line(fnd_file.output,'seq_no '||atr_type_tbl(indx).seq_no);
                    lx_xmltype_in   :=
                        SYS.XMLTYPE (
                               '<publishInvAdjustCreateUsingInvAdjustDesc xmlns="http://www.oracle.com/retail/igs/integration/services/InvAdjustPublishingService/v1" xmlns:v1="http://www.oracle.com/retail/integration/base/bo/InvAdjustDesc/v1" xmlns:v11="http://www.oracle.com/retail/integration/custom/bo/ExtOfInvAdjustDesc/v1" xmlns:v12="http://www.oracle.com/retail/integration/base/bo/LocOfInvAdjustDesc/v1" xmlns:v13="http://www.oracle.com/retail/integration/localization/bo/InInvAdjustDesc/v1" xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/EOfInInvAdjustDesc/v1" xmlns:v15="http://www.oracle.com/retail/integration/localization/bo/BrInvAdjustDesc/v1" xmlns:v16="http://www.oracle.com/retail/integration/custom/bo/EOfBrInvAdjustDesc/v1">'
                            || XMLTYPE.getclobval (l_xmldata)
                            || '</publishInvAdjustCreateUsingInvAdjustDesc>');

                    -----------------------------
                    -- Calling the web services
                    -----------------------------
                    BEGIN
                        ------------------------------------
                        -- Calling the web services program
                        ----------------------------------
                        lx_xmltype_out   :=
                            xxdo_invoke_webservice_f (lv_wsdl_url, lv_namespace, lv_targetname, lv_service, lv_port, lv_operation
                                                      , lx_xmltype_in);

                        ----------------------------------------
                        -- If the XML TYPE OUT IS NOT NULL then
                        -- the result is good and debugging the
                        -- same
                        ----------------------------------------
                        IF lx_xmltype_out IS NOT NULL
                        THEN
                            -------------------------
                            -- Debugging the comments
                            -------------------------
                            fnd_file.put_line (
                                fnd_file.output,
                                'Response is stored in the staging table  ');
                            ----------------------------
                            -- Storing the return values
                            ----------------------------
                            lc_return   :=
                                XMLTYPE.getclobval (lx_xmltype_out);

                            ------------------------------------------------------
                            -- update the staging table : xxdo_inv_int_008
                            ------------------------------------------------------
                            UPDATE xxdo_inv_int_008
                               SET retval = lc_return, processed_flag = 'Y', status = 'P',
                                   transmission_date = SYSDATE
                             ---where current of cur_int_atr_pub_upd
                             WHERE     seq_no = atr_type_tbl (indx).seq_no
                                   AND request_leg = p_request_leg;
                        --commit;
                        ---------------------------------------------
                        -- If there is no response from web services
                        ---------------------------------------------
                        ELSE
                            fnd_file.put_line (fnd_file.output,
                                               'Response is NULL  ');
                            lc_return   := NULL;

                            -------------------------------------------------
                            -- Updating the staging table to set the processed
                            -- flag = Validation Error and transmission date
                            --  = sysdate for the sequence number
                            -------------------------------------------------
                            UPDATE xxdo_inv_int_008
                               SET retval = lc_return, processed_flag = 'VE', transmission_date = SYSDATE
                             ---where current of cur_int_atr_pub_upd
                             WHERE     seq_no = atr_type_tbl (indx).seq_no
                                   AND request_leg = p_request_leg;
                        --  commit;
                        ---------------------------------
                        -- Condition END IF
                        ---------------------------------
                        END IF;
                    ---------------------
                    -- Exception HAndler
                    ---------------------
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SQLERRM;

                            --------------------------------
                            -- Updating the staging table
                            --------------------------------
                            UPDATE xxdo_inv_int_008
                               SET status = 'VE', errorcode = lv_errmsg
                             --  where current of cur_int_atr_pub_upd ;
                             WHERE     seq_no = atr_type_tbl (indx).seq_no
                                   AND request_leg = p_request_leg;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'PROBLEM IN SENDING THE MESSAGE DETAILS STORED IN THE ERRORCODE OF THE STAGING TABLE   '
                                || SQLERRM);
                    END;
                END LOOP;
            END LOOP;

            CLOSE cur_int_atr_pub_upd;

            COMMIT;
        END LOOP;
    END;

    -----------------------------------------------------------------------------
    -- This procedure will be called to publish the data to another custom table
    -- which is used to send the data to RIB in Batches
    -----------------------------------------------------------------------------
    PROCEDURE xxdo_inv_int_pub_bth_atr_p (errbuf             OUT VARCHAR2,
                                          retcode            OUT VARCHAR2,
                                          p_cur_limit     IN     NUMBER,
                                          p_request_leg   IN     NUMBER,
                                          p_dc_dest_id    IN     NUMBER --Added by infosys for version 2.1
                                                                       )
    IS
        ---------------------------------------------
        -- cursor cur_int_atr_pub is to
        -- retrive the records from the staging table
        -- and then publish it to the 2nd staging tabl
        -- for sending the xml data to RMS
        ---------------------------------------------
        CURSOR cur_int_atr_pub IS
            SELECT seq_no,
                   dc_dest_id,
                   item_id,
                   adjustment_reason_code,
                   unit_qty,
                   transshipment_nbr,
                   from_disposition,
                   to_disposition,
                   from_trouble_code,
                   to_trouble_code,
                   from_wip_code,
                   to_wip_code,
                   transaction_code,
                   user_id,
                   create_date,
                   po_nbr,
                   doc_type,
                   aux_reason_code,
                   weight,
                   weight_uom,
                   unit_cost,
                   status,
                   creation_date,
                   created_by,
                   last_update_date,
                   last_update_by,
                   sku,
                   item_description,
                   free_atp_q,
                   no_free_atp_q,
                   load_type,
                   (SELECT XMLELEMENT (
                               "v1:InvAdjustDesc",
                               XMLELEMENT ("v1:dc_dest_id", dc_dest_id),
                               XMLELEMENT (
                                   "v1:InvAdjustDtl",
                                   XMLELEMENT ("v1:item_id", item_id),
                                   XMLELEMENT ("v1:adjustment_reason_code",
                                               adjustment_reason_code),
                                   XMLELEMENT ("v1:unit_qty", unit_qty),
                                   XMLELEMENT ("v1:transshipment_nbr",
                                               transshipment_nbr),
                                   XMLELEMENT ("v1:from_disposition",
                                               from_disposition),
                                   XMLELEMENT ("v1:to_disposition",
                                               to_disposition),
                                   XMLELEMENT ("v1:from_trouble_code",
                                               from_trouble_code),
                                   XMLELEMENT ("v1:to_trouble_code",
                                               to_trouble_code),
                                   XMLELEMENT ("v1:from_wip_code",
                                               from_wip_code),
                                   XMLELEMENT ("v1:to_wip_code", to_wip_code),
                                   XMLELEMENT ("v1:transaction_code",
                                               transaction_code),
                                   XMLELEMENT ("v1:user_id", user_id),
                                   XMLELEMENT ("v1:create_date", create_date),
                                   XMLELEMENT ("v1:po_nbr", po_nbr),
                                   XMLELEMENT ("v1:doc_type", doc_type),
                                   XMLELEMENT ("v1:aux_reason_code",
                                               aux_reason_code),
                                   XMLELEMENT ("v1:weight", weight),
                                   XMLELEMENT ("v1:weight_uom", weight_uom),
                                   XMLELEMENT ("v1:unit_cost", unit_cost))) xml
                      FROM DUAL) xml_data
              FROM xxdo_inv_int_008
             WHERE     status = 'N'
                   AND processed_flag IS NULL
                   AND request_leg = p_request_leg              --- for update
                   AND dc_dest_id = p_dc_dest_id --Added by infosys for version 2.1
                                                ;

        --and    load_type = 'Incremental Load'
        CURSOR cur_int_atr_pub_upd IS
            SELECT *
              FROM xxdo_inv_int_008
             WHERE     status = 'N'
                   AND processed_flag IS NULL
                   AND request_leg = p_request_leg               -- for update
                   AND dc_dest_id = p_dc_dest_id --Added by infosys for version 2.1
                                                ;

        ----------------------
        -- Declaring Variables
        ----------------------
        lv_wsdl_ip                 VARCHAR2 (25) := NULL;
        lv_wsdl_url                VARCHAR2 (4000) := NULL;
        lv_namespace               VARCHAR2 (4000) := NULL;
        lv_service                 VARCHAR2 (4000) := NULL;
        lv_port                    VARCHAR2 (4000) := NULL;
        lv_operation               VARCHAR2 (4000) := NULL;
        lv_targetname              VARCHAR2 (4000) := NULL;
        lx_xmltype_in              SYS.XMLTYPE;
        lx_xmltype_out             SYS.XMLTYPE;
        v_xml_data                 CLOB;
        lc_return                  CLOB;
        lv_op_mode                 VARCHAR2 (60) := NULL;
        lv_errmsg                  VARCHAR2 (240) := NULL;
        v_dc_dest_id               VARCHAR2 (240) := NULL;
        v_item_id                  NUMBER := 0;
        v_adjustment_reason_code   VARCHAR2 (240) := NULL;
        v_unit_qty                 NUMBER := 0;
        v_transshipment_nbr        VARCHAR2 (240) := NULL;
        v_from_disposition         VARCHAR2 (240) := NULL;
        v_to_disposition           VARCHAR2 (240) := NULL;
        v_from_trouble_code        VARCHAR2 (240) := NULL;
        v_to_trouble_code          VARCHAR2 (240) := NULL;
        v_from_wip_code            VARCHAR2 (240) := NULL;
        v_to_wip_code              VARCHAR2 (240) := NULL;
        v_transaction_code         VARCHAR2 (240) := NULL;
        v_user_id                  VARCHAR2 (240) := 0;
        v_create_date              DATE;
        v_po_nbr                   VARCHAR2 (240) := NULL;
        v_doc_type                 VARCHAR2 (240) := NULL;
        v_aux_reason_code          VARCHAR2 (240) := NULL;
        v_weight                   NUMBER := 0;
        v_weight_uom               VARCHAR2 (240) := NULL;
        v_unit_cost                NUMBER := 0;
        v_status                   VARCHAR2 (240) := NULL;
        v_creation_date            DATE;
        v_created_by               NUMBER := 0;
        v_last_update_date         DATE;
        v_last_update_by           NUMBER := 0;
        v_sku                      VARCHAR2 (240) := NULL;
        v_item_description         VARCHAR2 (240) := NULL;
        v_free_atp_q               NUMBER := 0;
        v_no_free_atp_q            NUMBER := 0;
        v_load_type                VARCHAR2 (240) := NULL;
        --      v_s_no                     number           := 0                       ;
        v_seq_no                   NUMBER := 0;
        l_cur_limit                NUMBER := 0;
        l_cnt                      NUMBER := 0;
        l_request_id               NUMBER := 0;
        l_request_leg              NUMBER := 0;
        l_dc_dest_id               NUMBER := 0;

        TYPE atr_type IS TABLE OF cur_int_atr_pub_upd%ROWTYPE
            INDEX BY PLS_INTEGER;

        atr_type_tbl               atr_type;
        l_xmldata                  SYS.XMLTYPE;
        PRAGMA AUTONOMOUS_TRANSACTION;
    ---------------------------------
    -- Beginning of the procedure
    --------------------------------
    BEGIN
        ----------------------------------
        -- To get the profile values
        ----------------------------------
        BEGIN
            SELECT DECODE (applications_system_name,  -- Start of modification by BT Technology Team on 17-Feb-2016 V2.0
                                                      --'PROD', apps.fnd_profile.VALUE ('XXDO: RETAIL PROD'),
                                                      'EBSPROD', apps.fnd_profile.VALUE ('XXDO: RETAIL PROD'),  -- End of modification by BT Technology Team on 17-Feb-2016 V2.0

                                                                                                                'PCLN', apps.fnd_profile.VALUE ('XXDO: RETAIL DEV'),  apps.fnd_profile.VALUE ('XXDO: RETAIL TEST')) file_server_name
              INTO lv_wsdl_ip
              FROM apps.fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (apps.fnd_file.LOG,
                                   'Unable to fetch the File server name');
        END;

        --------------------------------------------------------------
        -- Initializing the variables for calling the webservices
        -- The webservices takes the input parameter as wsd URL,
        -- name space, service, port, operation and target name
        --------------------------------------------------------------
        lv_wsdl_url     :=
               'http://'
            || lv_wsdl_ip
            || '//InvAdjustPublishingBean/InvAdjustPublishingService?WSDL';
        lv_namespace    :=
            'http://www.oracle.com/retail/igs/integration/services/InvAdjustPublishingService/v1';
        lv_service      := 'InvAdjustPublishingService';
        lv_port         := 'InvAdjustPublishingPort';
        lv_operation    := 'publishInvAdjustCreateUsingInvAdjustDesc';
        lv_targetname   :=
               'http://'
            || lv_wsdl_ip
            || '//InvAdjustPublishingBean/InvAdjustPublishingService';
        v_seq_no        := 0;

        -- commit;
        BEGIN
            SELECT CEIL (COUNT (*) / p_cur_limit * 1) / 1
              INTO l_cur_limit
              FROM xxdo_inv_int_008
             WHERE     status = 'N'
                   AND processed_flag IS NULL
                   AND request_leg = p_request_leg;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_cur_limit   := 0;
                fnd_file.put_line (fnd_file.LOG,
                                   'Error while finding the l_cur_limit ');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        END;

          /*  fnd_file.put_line(fnd_file.log,'l_cur_limit '||l_cur_limit);

               for j in 1 .. l_cur_limit
               loop

               fnd_file.put_line(fnd_file.log,'l_cur_limit loop '||j);

                OPEN cur_int_atr_pub_upd;
                LOOP
                FETCH cur_int_atr_pub_upd
                BULK COLLECT INTO atr_type_tbl LIMIT p_cur_limit;  */

          /*  v_dc_dest_id               := c_cur_int_atr_pub.dc_dest_id                ;
            v_item_id                  := c_cur_int_atr_pub.item_id                   ;
            v_adjustment_reason_code   := c_cur_int_atr_pub.adjustment_reason_code    ;
            v_unit_qty                 := c_cur_int_atr_pub.unit_qty                  ;
            v_transshipment_nbr        := c_cur_int_atr_pub.transshipment_nbr         ;
            v_from_disposition         := c_cur_int_atr_pub.from_disposition          ;
            v_to_disposition           := c_cur_int_atr_pub.to_disposition            ;
            v_from_trouble_code        := c_cur_int_atr_pub.from_trouble_code         ;
              v_to_trouble_code          := c_cur_int_atr_pub.to_trouble_code           ;
            v_from_wip_code            := c_cur_int_atr_pub.from_wip_code             ;
            v_to_wip_code              := c_cur_int_atr_pub.to_wip_code               ;
            v_transaction_code         := c_cur_int_atr_pub.transaction_code          ;
            v_user_id                  := c_cur_int_atr_pub.user_id                   ;
            v_create_date              := c_cur_int_atr_pub.create_date               ;
            v_po_nbr                   := c_cur_int_atr_pub.po_nbr                    ;
            v_doc_type                 := c_cur_int_atr_pub.doc_type                  ;
            v_aux_reason_code          := c_cur_int_atr_pub.aux_reason_code           ;
            v_weight                   := c_cur_int_atr_pub.weight                    ;
            v_weight_uom               := c_cur_int_atr_pub.weight_uom                ;
            v_unit_cost                := c_cur_int_atr_pub.unit_cost                 ;
            v_creation_date            := c_cur_int_atr_pub.creation_date             ;
            v_created_by               := c_cur_int_atr_pub.created_by                ;
            v_last_update_date         := c_cur_int_atr_pub.last_update_date          ;
            v_last_update_by           := c_cur_int_atr_pub.last_update_by            ;
            v_SKU                      := c_cur_int_atr_pub.SKU                       ;
            v_Item_Description         := c_cur_int_atr_pub.Item_Description          ;
            v_Free_ATP_Q               := c_cur_int_atr_pub.Free_ATP_Q                ;
            v_No_Free_ATP_Q            := c_cur_int_atr_pub.No_Free_ATP_Q             ;
            v_load_type                := c_cur_int_atr_pub.load_type                 ;
            v_seq_no                   := c_cur_int_atr_pub.seq_no                   ;*/

          -------------------------------------------------------------
          -- Assigning the variables to call the webservices function
          -------------------------------------------------------------

          /*    EXIT WHEN atr_type_tbl.count =0;

              FOR indx IN 1 .. atr_type_tbl.COUNT
              LOOP */

          /* select xmldata into l_xmldata from xxdo_inv_int_008
             where seq_no = atr_type_tbl(indx).seq_no
             and rownum=1; */
          /* select
           (
                select XMLELEMENT ("v1:InvAdjustDesc",
                       XMLELEMENT ("v1:dc_dest_id",dc_dest_id),
                       XMLELEMENT ("v1:InvAdjustDtl",
                       XMLELEMENT ("v1:item_id",item_id),
                       XMLELEMENT ("v1:adjustment_reason_code",adjustment_reason_code),
                       XMLELEMENT ("v1:unit_qty",unit_qty),
                       XMLELEMENT ("v1:transshipment_nbr",transshipment_nbr),
                       XMLELEMENT ("v1:from_disposition",from_disposition),
                       XMLELEMENT ("v1:to_disposition",to_disposition),
                       XMLELEMENT ("v1:from_trouble_code",from_trouble_code),
                       XMLELEMENT ("v1:to_trouble_code",to_trouble_code),
                       XMLELEMENT ("v1:from_wip_code",from_wip_code),
                       XMLELEMENT ("v1:to_wip_code",to_wip_code),
                       XMLELEMENT ("v1:transaction_code",transaction_code),
                       XMLELEMENT ("v1:user_id",user_id),
                       XMLELEMENT ("v1:create_date",create_date),
                       XMLELEMENT ("v1:po_nbr",po_nbr),
                       XMLELEMENT ("v1:doc_type",doc_type),
                       XMLELEMENT ("v1:aux_reason_code",aux_reason_code),
                       XMLELEMENT ("v1:weight",weight),
                       XMLELEMENT ("v1:weight_uom",weight_uom),
                       XMLELEMENT ("v1:unit_cost",unit_cost)
                                  )
               )XML
               from
              dual) XML_data into l_xmldata
        from   xxdo_inv_int_008
        where seq_no= atr_type_tbl(indx).seq_no
        and request_leg =p_request_leg;
           */
          SELECT COUNT (*),
                 dc_dest_id,
                 NVL (request_id, 0),
                 request_leg,
                 (XMLELEMENT (
                      "v1:InvAdjustDesc",
                      XMLELEMENT ("v1:dc_dest_id", dc_dest_id),
                      (SELECT XMLAGG (XMLELEMENT (
                                          "v1:InvAdjustDtl",
                                          XMLELEMENT ("v1:item_id", item_id),
                                          XMLELEMENT (
                                              "v1:adjustment_reason_code",
                                              adjustment_reason_code),
                                          XMLELEMENT ("v1:unit_qty", unit_qty),
                                          XMLELEMENT ("v1:transshipment_nbr",
                                                      transshipment_nbr),
                                          XMLELEMENT ("v1:from_disposition",
                                                      from_disposition),
                                          XMLELEMENT ("v1:to_disposition",
                                                      to_disposition),
                                          XMLELEMENT ("v1:from_trouble_code",
                                                      from_trouble_code),
                                          XMLELEMENT ("v1:to_trouble_code",
                                                      to_trouble_code),
                                          XMLELEMENT ("v1:from_wip_code",
                                                      from_wip_code),
                                          XMLELEMENT ("v1:to_wip_code",
                                                      to_wip_code),
                                          XMLELEMENT ("v1:transaction_code",
                                                      transaction_code),
                                          XMLELEMENT ("v1:user_id", user_id),
                                          XMLELEMENT ("v1:create_date",
                                                      create_date),
                                          XMLELEMENT ("v1:po_nbr", po_nbr),
                                          XMLELEMENT ("v1:doc_type", doc_type),
                                          XMLELEMENT ("v1:aux_reason_code",
                                                      aux_reason_code),
                                          XMLELEMENT ("v1:weight", weight),
                                          XMLELEMENT ("v1:weight_uom",
                                                      weight_uom),
                                          XMLELEMENT ("v1:unit_cost",
                                                      unit_cost))
                                      ORDER BY item_id)
                         FROM xxdo_inv_int_008 int1
                        WHERE     int1.request_id = int2.request_id
                              AND int1.request_leg = int2.request_leg))) xml_data
            INTO l_cnt, l_dc_dest_id, l_request_id, l_request_leg,
                      l_xmldata
            FROM xxdo_inv_int_008 int2
           WHERE     1 = 1
                 AND status = 'N'
                 AND processed_flag IS NULL
                 AND request_leg = p_request_leg
                 AND dc_dest_id = p_dc_dest_id --Added by infosys for version 2.1
        --and request_id  =205709568
        GROUP BY dc_dest_id, request_id, request_leg;

        --- l_xmldata :=atr_type_tbl(indx).xmldata;

        -- fnd_file.put_line(fnd_file.output,'seq_no '||atr_type_tbl(indx).seq_no);
        lx_xmltype_in   :=
            SYS.XMLTYPE (
                   '<publishInvAdjustCreateUsingInvAdjustDesc xmlns="http://www.oracle.com/retail/igs/integration/services/InvAdjustPublishingService/v1" xmlns:v1="http://www.oracle.com/retail/integration/base/bo/InvAdjustDesc/v1" xmlns:v11="http://www.oracle.com/retail/integration/custom/bo/ExtOfInvAdjustDesc/v1" xmlns:v12="http://www.oracle.com/retail/integration/base/bo/LocOfInvAdjustDesc/v1" xmlns:v13="http://www.oracle.com/retail/integration/localization/bo/InInvAdjustDesc/v1" xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/EOfInInvAdjustDesc/v1" xmlns:v15="http://www.oracle.com/retail/integration/localization/bo/BrInvAdjustDesc/v1" xmlns:v16="http://www.oracle.com/retail/integration/custom/bo/EOfBrInvAdjustDesc/v1">'
                || XMLTYPE.getclobval (l_xmldata)
                || '</publishInvAdjustCreateUsingInvAdjustDesc>');

        -----------------------------
        -- Calling the web services
        -----------------------------
        BEGIN
            ------------------------------------
            -- Calling the web services program
            ----------------------------------
            lx_xmltype_out   :=
                xxdo_invoke_webservice_f (lv_wsdl_url, lv_namespace, lv_targetname, lv_service, lv_port, lv_operation
                                          , lx_xmltype_in);

            ----------------------------------------
            -- If the XML TYPE OUT IS NOT NULL then
            -- the result is good and debugging the
            -- same
            ----------------------------------------
            IF lx_xmltype_out IS NOT NULL
            THEN
                -------------------------
                -- Debugging the comments
                -------------------------
                fnd_file.put_line (
                    fnd_file.output,
                    'Response is stored in the staging table  ');
                ----------------------------
                -- Storing the return values
                ----------------------------
                lc_return   := XMLTYPE.getclobval (lx_xmltype_out);

                ------------------------------------------------------
                -- update the staging table : xxdo_inv_int_008
                ------------------------------------------------------
                UPDATE xxdo_inv_int_008
                   SET retval = lc_return, processed_flag = 'Y', status = 'P',
                       transmission_date = SYSDATE
                 ---where current of cur_int_atr_pub_upd
                 WHERE     1 = 1          --seq_no = atr_type_tbl(indx).seq_no
                       AND request_leg = p_request_leg
                       AND dc_dest_id = p_dc_dest_id --Added by infosys for version 2.1
                                                    ;

                BEGIN
                    INSERT INTO xxdo_inv_int_xml_008
                         VALUES (l_dc_dest_id, 'Y', SYSDATE,
                                 l_cnt, XMLTYPE.getclobval (l_xmldata), lc_return
                                 , l_request_leg, l_request_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --l_thread_cnt := 0;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Error updating xml rec');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                END;
            --commit;
            ---------------------------------------------
            -- If there is no response from web services
            ---------------------------------------------
            ELSE
                fnd_file.put_line (fnd_file.output, 'Response is NULL  ');
                lc_return   := NULL;

                -------------------------------------------------
                -- Updating the staging table to set the processed
                -- flag = Validation Error and transmission date
                --  = sysdate for the sequence number
                -------------------------------------------------
                UPDATE xxdo_inv_int_008
                   SET retval = lc_return, processed_flag = 'VE', transmission_date = SYSDATE
                 ---where current of cur_int_atr_pub_upd
                 WHERE     1 = 1          --seq_no = atr_type_tbl(indx).seq_no
                       AND request_leg = p_request_leg
                       AND dc_dest_id = p_dc_dest_id --Added by infosys for version 2.1
                                                    ;

                BEGIN
                    INSERT INTO xxdo_inv_int_xml_008
                         VALUES (l_dc_dest_id, 'VE', SYSDATE,
                                 l_cnt, XMLTYPE.getclobval (l_xmldata), lc_return
                                 , l_request_leg, l_request_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --  l_thread_cnt := 0;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Error updating xml rec');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                END;
            --  commit;
            ---------------------------------
            -- Condition END IF
            ---------------------------------
            END IF;
        ---------------------
        -- Exception HAndler
        ---------------------
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_errmsg   := SQLERRM;

                --------------------------------
                -- Updating the staging table
                --------------------------------
                UPDATE xxdo_inv_int_008
                   SET status = 'VE', errorcode = lv_errmsg
                 --  where current of cur_int_atr_pub_upd ;
                 WHERE     1 = 1            --Seq_NO=atr_type_tbl(indx).seq_no
                       AND request_leg = p_request_leg
                       AND dc_dest_id = p_dc_dest_id --Added by infosys for version 2.1
                                                    ;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'PROBLEM IN SENDING THE MESSAGE DETAILS STORED IN THE ERRORCODE OF THE STAGING TABLE   '
                    || SQLERRM);

                BEGIN
                    INSERT INTO xxdo_inv_int_xml_008
                         VALUES (l_dc_dest_id, 'VE', SYSDATE,
                                 l_cnt, XMLTYPE.getclobval (l_xmldata), lv_errmsg
                                 , l_request_leg, l_request_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        --l_thread_cnt := 0;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Error updating xml rec');
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Code :' || SQLCODE);
                        fnd_file.put_line (fnd_file.LOG,
                                           'SQL Error Message :' || SQLERRM);
                END;
        END;

        --  END LOOP;
        --  END LOOP;
        --  CLOSE cur_int_atr_pub_upd;
        COMMIT;
    --  END LOOP;
    END;

    /* New function Updated on 18-April-2013 */
    FUNCTION get_atr_open_allocation_f (pv_item_id NUMBER, pv_org_id NUMBER)
        RETURN NUMBER
    IS
        lv_open_allocation   NUMBER;
    BEGIN
        BEGIN
              SELECT NVL (SUM (ool.ordered_quantity), 0) - (NVL (SUM (ool.shipped_quantity), 0) + NVL (SUM (ool.cancelled_quantity), 0)) quantity
                INTO lv_open_allocation
                FROM apps.oe_order_lines_all ool, apps.oe_order_sources oos, xxdo_ebs_rms_vw_map xxer
               WHERE     ool.order_source_id = oos.order_source_id
                     AND oos.NAME = 'Retail'
                     AND ool.ship_from_org_id = xxer.ORGANIZATION
                     AND NVL (ool.open_flag, 'N') = 'Y'
                     AND ool.return_reason_code IS NULL
                     AND NVL (UPPER (xxer.channel), 'OUTLET') = 'OUTLET'
                     --AND     ool.ship_from_org_id = 292
                     AND ship_from_org_id = pv_org_id
                     AND ool.inventory_item_id = pv_item_id
            GROUP BY xxer.virtual_warehouse, ool.inventory_item_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_open_allocation   := 0;
            WHEN OTHERS
            THEN
                lv_open_allocation   := -1;
        END;

        RETURN lv_open_allocation;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, (SQLERRM));
    END;
-------------------------
-- End Of The Package
-----------------------
END;
/
