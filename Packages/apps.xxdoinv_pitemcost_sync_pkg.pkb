--
-- XXDOINV_PITEMCOST_SYNC_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:39:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoinv_pitemcost_sync_pkg
IS
    /***************************************************************************
    Package Name : XXDOINV_PITEMCOST_PKG
    Description: This package is used for to get all items which costmissmatch between EBS and RMS and publish cost in RMS.

    a.  PUBLISH_ITEMCOSTCHANGE_P

        This procedure is used to get all items which costmismatch between EBS and RMS and insert into XXDOINV010_INT

         with RMS using WebService call including the   Vertex tax logic
    b. RMS_BATCH_ITEMCOSTCHANGE_P

        This procedure is used to publish item cost from Staging table to RMS by using WEB services.


                Creation on 10/15/2013
                Created by : Nagapratap

      -------------------------------------------------------

       -------------------------------------------------------
      Changes made Reddeiah on 11 -Jul-2014 for Cost change for POP Items -ENHC0012047
    changes made BT TEAM on 10-dec-2014 for retrofit
      -------------------------------------------------------


    **************************************************************************/
    FUNCTION get_no_of_items_inpack_f (pn_item_id NUMBER)
        --Commented by Reddeiah - ENHC0012047
        RETURN NUMBER
    IS
        lv_no_ofitems   NUMBER;
    BEGIN
        SELECT TO_NUMBER (tag)
          INTO lv_no_ofitems
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'XXDOINV007_STYLE'
               AND meaning = pn_item_id
               AND LANGUAGE = 'US'
               AND enabled_flag = 'Y';

        IF lv_no_ofitems <> 0
        THEN
            RETURN lv_no_ofitems;
        ELSE
            RETURN 1;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 1;
    END;

    FUNCTION check_pop_item_f (pn_item_id NUMBER)
        -- Added by Reddeiah -ENHC0012047
        RETURN CHAR
    IS
        lv_count   VARCHAR2 (50);
    BEGIN
        SELECT COUNT (*)
          INTO lv_count
          --FROM rms13prod.packitem@rmsprod -- Removed by Sreenath for BT
          FROM rms13prod.packitem@xxdo_retail_rms  -- Added by Sreenath for BT
         WHERE pack_no = TO_CHAR (pn_item_id);

        IF lv_count > 0
        THEN
            RETURN 'Y';
        ELSE
            RETURN 'N';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'N';
    END;

    FUNCTION get_no_of_pop_items_f (pn_item_id NUMBER)
        -- Added by Reddeiah -ENHC0012047
        RETURN NUMBER
    IS
        lv_no_ofitems   NUMBER;
    BEGIN
        SELECT pack_qty
          INTO lv_no_ofitems
          --FROM rms13prod.packitem@rmsprod -- Removed by Sreenath for BT
          FROM rms13prod.packitem@xxdo_retail_rms  -- Added by Sreenath for BT
         WHERE pack_no = TO_CHAR (pn_item_id);

        IF lv_no_ofitems <> 0
        THEN
            RETURN lv_no_ofitems;
        ELSE
            RETURN 1;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 1;
    END;

    FUNCTION get_pack_item_f (pn_item_id NUMBER)
        -- Added by Reddeiah -ENHC0012047
        RETURN NUMBER
    IS
        lv_item   NUMBER;
    BEGIN
        SELECT TO_NUMBER (item)
          INTO lv_item
          --FROM rms13prod.packitem@rmsprod -- Removed by Sreenath for BT
          FROM rms13prod.packitem@xxdo_retail_rms  -- Added by Sreenath for BT
         WHERE pack_no = TO_CHAR (pn_item_id);

        IF lv_item IS NOT NULL
        THEN
            RETURN lv_item;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    /* FUNCTION get_pack_item_cost_f (pn_item_id NUMBER, pn_region VARCHAR2)
        RETURN NUMBER
     IS
        lv_item_cost   NUMBER := 0;
     BEGIN
        SELECT ROUND (qll.operand, 2)
          INTO lv_item_cost
          FROM apps.qp_pricing_attributes qpa,
               apps.qp_list_lines qll,
               apps.qp_list_headers qlh
         WHERE qpa.list_line_id = qll.list_line_id
           AND qll.list_header_id = qlh.list_header_id
           AND qpa.list_header_id = qlh.list_header_id
           AND qpa.product_attribute_context = 'ITEM'
           AND SYSDATE BETWEEN NVL (qll.start_date_active, SYSDATE)
                           AND NVL (qll.end_date_active, SYSDATE)
           AND qlh.NAME =
                  (SELECT meaning
                     FROM apps.fnd_lookup_values_vl a
                    WHERE lookup_type = 'XXDOINV_PRICE_LIST_NAME'
                      AND lookup_code = pn_region
                      AND enabled_flag = 'Y')
           AND qpa.product_attr_value = TO_CHAR (pn_item_id);

        IF lv_item_cost IS NOT NULL
        THEN
           RETURN lv_item_cost;
        ELSE
           RETURN 0;
        END IF;
     EXCEPTION
        WHEN OTHERS
        THEN
           RETURN 0;
     END;*/
    PROCEDURE rms_publish_itemcostchange_p (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_rundate VARCHAR2
                                            , -- pv_reprocess         VARCHAR2,
                                              -- pv_fromdate          VARCHAR2,
                                              --pv_todate            VARCHAR2,
                                              pv_region VARCHAR2)
    IS
        /***************************************************************************************


         (Modified the procedure by Naga Sunera on 10/17/2012)
            1. Modified the UK,Canada,Japan XML Data cursors to fetch the cost
            information from either Retail Tables or EBS Pricing Tables.

        Coding part is aaded to the stores part of japan region



        *******************************************************************************************/
        lv_wsdl_ip             VARCHAR2 (25);
        lv_wsdl_url            VARCHAR2 (4000);
        lv_namespace           VARCHAR2 (4000);
        lv_service             VARCHAR2 (4000);
        lv_port                VARCHAR2 (4000);
        lv_operation           VARCHAR2 (4000);
        lv_targetname          VARCHAR2 (4000);
        lx_xmltype_in          SYS.XMLTYPE;
        lx_xmltype_out         SYS.XMLTYPE;
        lc_return              CLOB;
        lv_reg_val             VARCHAR2 (10);
        lv_op_mode             VARCHAR2 (60);
        lv_errmsg              VARCHAR2 (240);
        lv_brand               VARCHAR2 (30);
        lv_concept             VARCHAR2 (30);
        lv_shoka               VARCHAR2 (30);
        ln_itemcost            NUMBER (10, 2);
        ln_us_cost             NUMBER (10, 2);
        ln_uk_cost             NUMBER (10, 2);
        ln_jp_cost             NUMBER (10, 2);
        ln_ca_cost             NUMBER (10, 2);
        ln_cn_cost             NUMBER (10, 2);
        ln_fr_cost             NUMBER (10, 2);
        lv_region_us           VARCHAR2 (10);
        lv_region_uk           VARCHAR2 (10);
        lv_region_jp           VARCHAR2 (10);
        lv_region_ca           VARCHAR2 (10);
        lv_region_cn           VARCHAR2 (10);
        lv_region_fr           VARCHAR2 (10);
        lv_region_hk           VARCHAR2 (10);
        lv_alu                 VARCHAR2 (100);
        lv_counter             NUMBER := 0;
        ln_count1              NUMBER := 0;
        ln_count2              NUMBER := 0;
        ln_cad_exchange        NUMBER;
        lv_rec_count           NUMBER;
        lv_min_slno            NUMBER;
        lv_batch_count         NUMBER;
        ln_request_id          NUMBER;
        lv_request_id          NUMBER := fnd_global.conc_request_id;
        lv_noof_items          NUMBER := 0;
        lv_status              VARCHAR2 (5);
        lv_pack_item           VARCHAR2 (100);
        lv_cmp_item_id         NUMBER := 0;
        lv_item_cost           NUMBER := 0;
        lv_cmp_item_cost       NUMBER := 0;
        lv_pk_item_cost        NUMBER := 0;
        lv_style               VARCHAR2 (100);
        lv_color               VARCHAR2 (100);
        lv_sze                 VARCHAR2 (100);
        lv_req_phase           VARCHAR2 (100);
        lv_req_status          VARCHAR2 (100);
        lv_req_dev_phase       VARCHAR2 (1000);
        lv_req_dev_status      VARCHAR2 (100);
        lv_req_message         VARCHAR2 (2400);
        lv_req_return_status   BOOLEAN;

        CURSOR c_itemcost IS
            SELECT ebs.inventory_item_id, ebs.organization_id, ebs.style,
                   ebs.color, ebs.sze, ebs.ebs_unit_cost,
                   rms1.unit_cost
              FROM (SELECT msi.inventory_item_id,
                           msi.organization_id,
                           --  msi.segment1 style, msi.segment2 color, msi.segment3 sze,            --commented by BT Team on 10/12/2014
                           msi.style_number style,
                           msi.color_code color,
                           msi.item_size sze, --Added by BT Team on 10/12/2014
                           NVL (
                               (SELECT DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2))
                                  FROM apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh
                                 WHERE     qpa.list_line_id =
                                           qll.list_line_id
                                       AND qll.list_header_id =
                                           qlh.list_header_id
                                       AND qpa.list_header_id =
                                           qlh.list_header_id
                                       AND qpa.product_attribute =
                                           'PRICING_ATTRIBUTE1'
                                       AND qpa.product_attribute_context =
                                           'ITEM'
                                       AND (CASE
                                                WHEN pv_rundate IS NOT NULL
                                                THEN
                                                    TRUNC (
                                                        qll.last_update_date)
                                                ELSE
                                                    TRUNC (SYSDATE)
                                            END) =
                                           DECODE (
                                               pv_rundate,
                                               NULL, TRUNC (SYSDATE),
                                               TRUNC (
                                                   fnd_date.canonical_to_date (
                                                       pv_rundate)))
                                       --AND qpa.product_uom_code = msi.primary_uom_code
                                       AND SYSDATE BETWEEN NVL (
                                                               qll.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               qll.end_date_active,
                                                               SYSDATE)
                                       -- AND qlh.list_header_id = 26756
                                       AND qlh.NAME =
                                           (SELECT meaning
                                              FROM apps.fnd_lookup_values_vl a
                                             WHERE     lookup_type =
                                                       'XXDOINV_PRICE_LIST_NAME'
                                                   AND lookup_code = 'USRO'
                                                   AND enabled_flag = 'Y')
                                       AND qpa.product_attr_value =
                                           TO_CHAR (msi.inventory_item_id)),
                               NVL (
                                   (SELECT DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2))
                                      FROM apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh
                                     WHERE     qpa.list_line_id =
                                               qll.list_line_id
                                           AND qll.list_header_id =
                                               qlh.list_header_id
                                           AND qpa.list_header_id =
                                               qlh.list_header_id
                                           AND qpa.product_attribute =
                                               'PRICING_ATTRIBUTE2'
                                           AND qpa.product_attribute_context =
                                               'ITEM'
                                           AND (CASE
                                                    WHEN pv_rundate IS NOT NULL
                                                    THEN
                                                        TRUNC (qll.last_update_date)
                                                    ELSE
                                                        TRUNC (SYSDATE)
                                                END) =
                                               DECODE (
                                                   pv_rundate,
                                                   NULL, TRUNC (SYSDATE),
                                                   TRUNC (
                                                       fnd_date.canonical_to_date (
                                                           pv_rundate)))
                                           --AND qpa.product_uom_code = msi.primary_uom_code
                                           AND SYSDATE BETWEEN NVL (
                                                                   qll.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   qll.end_date_active,
                                                                   SYSDATE)
                                           --                AND qlh.list_header_id = 26756
                                           AND qlh.NAME =
                                               (SELECT meaning
                                                  FROM apps.fnd_lookup_values_vl a
                                                 WHERE     lookup_type =
                                                           'XXDOINV_PRICE_LIST_NAME'
                                                       AND lookup_code =
                                                           'USRO'
                                                       AND enabled_flag = 'Y')
                                           AND qpa.product_attr_value =
                                               TO_CHAR (mc.category_id)),
                                   (SELECT DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2))
                                      FROM apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh
                                     WHERE     qpa.list_line_id =
                                               qll.list_line_id
                                           AND qll.list_header_id =
                                               qlh.list_header_id
                                           AND qpa.list_header_id =
                                               qlh.list_header_id
                                           AND qpa.product_attribute =
                                               'PRICING_ATTRIBUTE2'
                                           AND qpa.product_attribute_context =
                                               'ITEM'
                                           AND (CASE
                                                    WHEN pv_rundate IS NOT NULL
                                                    THEN
                                                        TRUNC (qll.last_update_date)
                                                    ELSE
                                                        TRUNC (SYSDATE)
                                                END) =
                                               DECODE (
                                                   pv_rundate,
                                                   NULL, TRUNC (SYSDATE),
                                                   TRUNC (
                                                       fnd_date.canonical_to_date (
                                                           pv_rundate)))
                                           AND qpa.product_uom_code =
                                               msi.primary_uom_code
                                           AND SYSDATE BETWEEN NVL (
                                                                   qll.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   qll.end_date_active,
                                                                   SYSDATE)
                                           --                AND qlh.list_header_id = 6021
                                           AND qlh.NAME =
                                               (SELECT meaning
                                                  FROM apps.fnd_lookup_values_vl a
                                                 WHERE     lookup_type =
                                                           'XXDOINV_PRICE_LIST_NAME'
                                                       AND lookup_code =
                                                           'USW'
                                                       AND enabled_flag = 'Y')
                                           AND qpa.product_attr_value =
                                               TO_CHAR (mc.category_id)))) ebs_unit_cost
                      --FROM apps.mtl_system_items msi,                                    --commented by BT Team on 10/12/2014
                      FROM apps.xxd_common_items_v msi, --Added  by BT Team on 10/12/2014
                                                        apps.mtl_item_categories mic, apps.mtl_categories mc
                     WHERE     mc.category_id = mic.category_id
                           AND mic.organization_id = msi.organization_id
                           --AND msi.item_number = '1010467-BLK-04'
                           AND mic.inventory_item_id = msi.inventory_item_id
                           --AND mc.structure_id = 50202  -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           AND mc.structure_id =
                               (SELECT structure_id
                                  FROM mtl_category_sets_v
                                 WHERE UPPER (category_set_name) =
                                       'OM SALES CATEGORY')
                           -- Added by Sreenath for BT - End
                           --AND mic.category_set_id = 4 --Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           AND mic.category_set_id =
                               (SELECT category_set_id
                                  FROM mtl_category_sets_v
                                 WHERE UPPER (category_set_name) =
                                       'OM SALES CATEGORY')
                           -- Added by Sreenath for BT - End
                           --  AND msi.segment3 <> 'ALL'                                               --commented by BT Team on 12/10/2014
                           AND msi.item_type <> 'GENERIC' --Added by BT Team on 12/10/2014
                           --                    AND not exists (select 1 from rms13prod.packitem@rmsprod where item= to_char(msi.inventory_item_id))
                           --AND msi.organization_id = 7 -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           /* AND msi.organization_id =
                                   (SELECT organization_id
                                      FROM org_organization_definitions
                                     WHERE organization_name =
                                                             'MST_Deckers_Item_Master')
                                                                                       -- Added by Sreenath for BT - End*/
                                          --commented by BT Team on 10/12/2014
                           AND msi.organization_id IN
                                   (SELECT ood.ORGANIZATION_ID
                                      FROM fnd_lookup_values flv, org_organization_definitions ood
                                     WHERE     lookup_type =
                                               'XXD_1206_INV_ORG_MAPPING'
                                           AND lookup_code = 7
                                           AND flv.attribute1 =
                                               ood.ORGANIZATION_CODE
                                           AND language = USERENV ('LANG')) --Added bY BT Team on 10/12/2014
                                                                           )
                   ebs,
                   (  SELECT item, ROUND (AVG (unit_cost), 2) unit_cost
                        FROM --rms13prod.item_loc_soh@rmsprod rms, -- Removed by Sreenath for BT
                             rms13prod.item_loc_soh@xxdo_retail_rms rms,
                             -- Added by Sreenath for BT
                              (SELECT TO_CHAR (STORE) loc
                                 --FROM rms13prod.STORE@rmsprod   -- Removed by Sreenath for BT
                                 FROM rms13prod.STORE@xxdo_retail_rms
                                -- Added by Sreenath for BT
                                WHERE     currency_code = 'USD'
                                      AND store_class <> 'D'
                                      AND TRUNC (store_open_date) <= SYSDATE
                               UNION
                               SELECT lookup_code loc
                                 FROM apps.fnd_lookup_values a
                                WHERE     lookup_type = 'XXDOINV007_WH'
                                      AND tag = 'USD'
                                      AND LANGUAGE = 'US'
                                      AND enabled_flag = 'Y') whs
                       WHERE     whs.loc = rms.loc
                             AND rms.primary_cntry = 'US'
                             AND rms.loc <> 15205
                    GROUP BY rms.item) rms1
             WHERE     TO_CHAR (ebs.inventory_item_id) = rms1.item
                   AND ebs.ebs_unit_cost <> rms1.unit_cost;

        CURSOR c_itemcostchange_us (pn_itemid    NUMBER,
                                    pn_orgnid    NUMBER,
                                    pn_us_cost   NUMBER)
        IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('US')),
                       XMLELEMENT ("v1:origin_country_id", 'US'),
                       XMLELEMENT ("v1:diff_id", ''),
                       --XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_cost_us_f(msib.inventory_item_id,msib.organization_id)),
                       XMLELEMENT ("v1:unit_cost", pn_us_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code",
                                   xxdoinv006_pkg.get_curr_code_f ('US')),
                       XMLELEMENT ("v1:hier_level", 'W'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", lookup_code)))
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXDOINV007_WH'
                               AND lookup_code IN
                                       (SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'W'
                                               AND loc <> 15205
                                               AND primary_cntry = 'US')
                               AND LANGUAGE = 'US'
                               AND description = 'US'
                               AND enabled_flag = 'Y')) itemcost
              --FROM apps.mtl_system_items msib                           --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     msib.inventory_item_id = pn_itemid
                   AND msib.organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              -- FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'W'
                                   AND loc <> 15205
                                   AND primary_cntry = 'US');

        CURSOR c_itemcost_uk IS
            SELECT ebs.inventory_item_id, ebs.organization_id, ebs.style,
                   color, ebs.sze, ebs.uk_region_cost,
                   ebs.list_header_id, rms1.rms_unit_cost
              FROM (SELECT ROWNUM, msib.inventory_item_id, msib.organization_id,
                           --  msi.segment1 style, msi.segment2 color, msi.segment3 sze,            --commented by BT Team on 10/12/2014
                           msib.style_number style, msib.color_code color, msib.item_size sze, --Added by BT Team on 10/12/2014
                           DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2)) uk_region_cost, qlh.list_header_id
                      --  FROM apps.mtl_system_items_b msib,                               --commented by BT Team on 10/12/2014
                      FROM apps.xxd_common_items_v msib, --Added by BT Team on 10/12/2014
                                                         apps.qp_list_headers qlh, apps.qp_list_lines qll,
                           apps.qp_pricing_attributes qpa
                     --WHERE msib.segment3 <> 'ALL'                                         --commented by BT Team on 10/12/2014
                     WHERE     msib.item_type <> 'GENERIC' --Added by BT Team on 10/12/2014
                           AND (CASE
                                    WHEN pv_rundate IS NOT NULL
                                    THEN
                                        TRUNC (qll.last_update_date)
                                    ELSE
                                        TRUNC (SYSDATE)
                                END) =
                               DECODE (
                                   pv_rundate,
                                   NULL, TRUNC (SYSDATE),
                                   TRUNC (
                                       fnd_date.canonical_to_date (
                                           pv_rundate)))       --ADDED BY NAGA
                           AND qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                           AND qpa.product_attr_value =
                               msib.inventory_item_id
                           --and msib.inventory_item_status_code = 'Active'
                           --AND msib.organization_id = 7 -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           /* AND msib.organization_id =
                                   (SELECT organization_id
                                      FROM org_organization_definitions
                                     WHERE organization_name =
                                                             'MST_Deckers_Item_Master')
                            -- Added by Sreenath for BT - End*/
                           -- commented by BT Team on 12/10/2014
                           AND msib.organization_id IN
                                   (SELECT ood.ORGANIZATION_ID
                                      FROM fnd_lookup_values flv, org_organization_definitions ood
                                     WHERE     lookup_type =
                                               'XXD_1206_INV_ORG_MAPPING'
                                           AND lookup_code = 7
                                           AND flv.attribute1 =
                                               ood.ORGANIZATION_CODE
                                           AND language = USERENV ('LANG')) --Added bY BT Team on 10/12/2014
                           --                    AND not exists (select 1 from rms13prod.packitem@rmsprod where item= to_char(msib.inventory_item_id))
                           AND SYSDATE BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE)
                           --AND qlh.name  = 'DEL GBP Inter Company Price list'
                           AND qlh.NAME =
                               (SELECT meaning
                                  FROM apps.fnd_lookup_values_vl a
                                 WHERE     lookup_type =
                                           'XXDOINV_PRICE_LIST_NAME'
                                       AND lookup_code = 'UK'
                                       AND enabled_flag = 'Y') -- ADDED BY NAGA
                           AND apps.xxdoinv006_pkg.get_brand_f (
                                   NULL,
                                   msib.inventory_item_id,
                                   msib.organization_id) =
                               'UGG') ebs,
                   (  SELECT /*+ DRIVING_SITE(rms) */
                             item, ROUND (AVG (unit_cost), 2) rms_unit_cost
                        FROM --rms13prod.item_loc_soh@rmsprod rms, -- Removed by Sreenath for BT
                             rms13prod.item_loc_soh@xxdo_retail_rms rms,
                             -- Added by Sreenath for BT
                              (SELECT TO_CHAR (STORE) loc
                                 -- FROM rms13prod.STORE@rmsprod - Removed by Sreenath for BT
                                 FROM rms13prod.STORE@xxdo_retail_rms
                                -- Added by Sreenath for BT
                                WHERE     currency_code = 'GBP'
                                      AND store_class <> 'D'
                                      AND TRUNC (store_open_date) <= SYSDATE
                               UNION
                               SELECT lookup_code loc
                                 FROM apps.fnd_lookup_values a
                                WHERE     lookup_type = 'XXDOINV007_WH'
                                      AND tag = 'GBP'
                                      AND LANGUAGE = 'US'
                                      AND enabled_flag = 'Y') whs
                       WHERE whs.loc = rms.loc AND rms.primary_cntry = 'GB'
                    GROUP BY rms.item) rms1
             WHERE     TO_CHAR (ebs.inventory_item_id) = rms1.item
                   AND ebs.uk_region_cost <> rms1.rms_unit_cost;

        CURSOR c_itemcostchange_uk (pn_itemid    NUMBER,
                                    pn_orgnid    NUMBER,
                                    pn_uk_cost   NUMBER)
        IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('UK')),
                       XMLELEMENT ("v1:origin_country_id", 'GB'),
                       XMLELEMENT ("v1:diff_id", ''),
                       --XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'UK')),
                       XMLELEMENT ("v1:unit_cost", pn_uk_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'GBP'),
                       XMLELEMENT ("v1:hier_level", 'W'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", lookup_code)))
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXDOINV007_WH'
                               AND lookup_code IN
                                       (SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'W'
                                               AND primary_cntry = 'GB')
                               AND enabled_flag = 'Y'
                               AND LANGUAGE = 'US'
                               AND description = 'UK')) itemcost
              --  FROM mtl_system_items_b msib                                                   --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'W'
                                   AND primary_cntry = 'GB');

        CURSOR c_itemcost_jp IS
            SELECT ebs.inventory_item_id, ebs.organization_id, ebs.style,
                   ebs.color, ebs.sze, ebs.ebs_unit_cost,
                   ebs.list_header_id, rms1.rms_unit_cost
              FROM (SELECT ROWNUM, msi.inventory_item_id, msi.organization_id,
                           --  msi.segment1 style, msi.segment2 color, msi.segment3 sze,            --commented by BT Team on 10/12/2014
                           msi.style_number style, msi.color_code color, msi.item_size sze, --Added by BT Team on 10/12/2014
                           DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2)) ebs_unit_cost, qlh.list_header_id
                      -- FROM apps.mtl_system_items msi,                                           --commented by BT Team on 10/12/2014
                      FROM apps.xxd_common_items_v msi, --Added by BT Team on 10/12/2014
                                                        apps.qp_pricing_attributes qpa, apps.qp_list_lines qll,
                           apps.qp_list_headers qlh
                     WHERE     msi.inventory_item_id = qpa.product_attr_value
                           AND qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           AND qpa.list_header_id = qlh.list_header_id
                           AND (CASE
                                    WHEN pv_rundate IS NOT NULL
                                    THEN
                                        TRUNC (qll.last_update_date)
                                    ELSE
                                        TRUNC (SYSDATE)
                                END) =
                               DECODE (
                                   pv_rundate,
                                   NULL, TRUNC (SYSDATE),
                                   TRUNC (
                                       fnd_date.canonical_to_date (
                                           pv_rundate)))
                           --        and qlh.name = 'Japan Retail Replenishment JPY'
                           AND qlh.NAME =
                               (SELECT meaning
                                  FROM apps.fnd_lookup_values_vl a
                                 WHERE     lookup_type =
                                           'XXDOINV_PRICE_LIST_NAME'
                                       AND lookup_code = 'JP'
                                       AND enabled_flag = 'Y')
                           --AND msi.segment3 <> 'ALL'                                  --commented by BT Team on 10/12/2014
                           AND msi.item_type <> 'GENERIC' --Added by BT Team on 10/12/2014
                           --AND msi.organization_id = 7   -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           /*   AND msi.organization_id =
                                     (SELECT organization_id
                                        FROM org_organization_definitions
                                       WHERE organization_name =
                                                               'MST_Deckers_Item_Master')*/
                                          --commented by BT team on 10/12/2014
                           AND msi.organization_id IN
                                   (SELECT ood.ORGANIZATION_ID
                                      FROM fnd_lookup_values flv, org_organization_definitions ood
                                     WHERE     lookup_type =
                                               'XXD_1206_INV_ORG_MAPPING'
                                           AND lookup_code = 7
                                           AND flv.attribute1 =
                                               ood.ORGANIZATION_CODE
                                           AND language = USERENV ('LANG')) --Added bY BT Team on 10/12/2014
                           -- Added by Sreenath for BT - End
                           --                    AND not exists (select 1 from rms13prod.packitem@rmsprod where item= to_char(msi.inventory_item_id))
                           AND SYSDATE BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE)
                           AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                           AND qpa.product_attribute_context = 'ITEM'
                    UNION
                    SELECT ROWNUM, msi.inventory_item_id, msi.organization_id,
                           --  msi.segment1 style, msi.segment2 color, msi.segment3 sze,            --commented by BT Team on 10/12/2014
                           msi.style_number style, msi.color_code color, msi.item_size sze, --Added by BT Team on 10/12/2014
                           DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2)) ebs_unit_cost, qlh.list_header_id
                      --FROM apps.mtl_system_items msi,                                                    --commented by BT Team on 10/12/2014
                      FROM apps.xxd_common_items_v msi, --added by BT Team on 10/12/2014
                                                        apps.mtl_item_categories mic, apps.mtl_categories mc,
                           apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh
                     WHERE     mc.category_id = mic.category_id
                           AND mic.organization_id = msi.organization_id
                           AND mic.inventory_item_id = msi.inventory_item_id
                           AND mc.category_id = qpa.product_attr_value
                           AND (CASE
                                    WHEN pv_rundate IS NOT NULL
                                    THEN
                                        TRUNC (qll.last_update_date)
                                    ELSE
                                        TRUNC (SYSDATE)
                                END) =
                               DECODE (
                                   pv_rundate,
                                   NULL, TRUNC (SYSDATE),
                                   TRUNC (
                                       fnd_date.canonical_to_date (
                                           pv_rundate)))
                           --AND mc.structure_id = 50202 -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           AND mc.structure_id =
                               (SELECT structure_id
                                  FROM mtl_category_sets_v
                                 WHERE UPPER (category_set_name) =
                                       'OM SALES CATEGORY')
                           -- Added by Sreenath for BT - End
                           --AND mic.category_set_id = 4  -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           AND mic.category_set_id =
                               (SELECT category_set_id
                                  FROM mtl_category_sets_v
                                 WHERE UPPER (category_set_name) =
                                       'OM SALES CATEGORY')
                           -- Added by Sreenath for BT - End
                           AND qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           AND qpa.list_header_id = qlh.list_header_id
                           -- AND qlh.NAME = 'Japan Retail Replenishment JPY'
                           AND qlh.NAME =
                               (SELECT meaning
                                  FROM apps.fnd_lookup_values_vl a
                                 WHERE     lookup_type =
                                           'XXDOINV_PRICE_LIST_NAME'
                                       AND lookup_code = 'JP'
                                       AND enabled_flag = 'Y')
                           --AND msi.organization_id = 7 -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           /* AND msi.organization_id =
                                   (SELECT organization_id
                                      FROM org_organization_definitions
                                     WHERE organization_name =
                                                             'MST_Deckers_Item_Master')*/
                           --commented by BT TEam on 12/10/2014
                           AND msi.organization_id IN
                                   (SELECT ood.ORGANIZATION_ID
                                      FROM fnd_lookup_values flv, org_organization_definitions ood
                                     WHERE     lookup_type =
                                               'XXD_1206_INV_ORG_MAPPING'
                                           AND lookup_code = 7
                                           AND flv.attribute1 =
                                               ood.ORGANIZATION_CODE
                                           AND language = USERENV ('LANG')) --Added bY BT Team on 09/12/2014
                           -- Added by Sreenath for BT - End
                           --                    AND not exists (select 1 from rms13prod.packitem@rmsprod where item= to_char(msi.inventory_item_id))
                           --AND msi.segment3 <> 'ALL'                                                   --commented by BT Team on 10/12/2014
                           AND msi.item_type <> 'GENERIC' --Added by BT Team on 10/12/2014
                           AND SYSDATE BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE)
                           AND qpa.product_attribute = 'PRICING_ATTRIBUTE2'
                           AND qpa.product_attribute_context = 'ITEM'
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM apps.qp_pricing_attributes qp1
                                     WHERE     qp1.product_attribute =
                                               'PRICING_ATTRIBUTE1'
                                           AND list_header_id =
                                               (SELECT list_header_id
                                                  FROM apps.qp_list_headers
                                                 WHERE NAME =
                                                       (SELECT meaning
                                                          FROM apps.fnd_lookup_values_vl a
                                                         WHERE     lookup_type =
                                                                   'XXDOINV_PRICE_LIST_NAME'
                                                               AND lookup_code =
                                                                   'JP'
                                                               AND enabled_flag =
                                                                   'Y'))
                                           --AND list_header_id = 1030120
                                           AND qp1.product_attr_value =
                                               msi.inventory_item_id)) ebs,
                   (  SELECT /*+ DRIVING_SITE(rms) */
                             item, ROUND (AVG (unit_cost), 2) rms_unit_cost
                        FROM --rms13prod.item_loc_soh@rmsprod rms, -- Removed by Sreenath for BT
                             rms13prod.item_loc_soh@xxdo_retail_rms rms,
                             -- Added by Sreenath for BT
                              (SELECT TO_CHAR (STORE) loc
                                 --FROM rms13prod.STORE@rmsprod  -- Removed by Sreenath for BT
                                 FROM rms13prod.STORE@xxdo_retail_rms
                                -- Added by Sreenath for BT
                                WHERE     currency_code = 'JPY'
                                      AND store_class <> 'D'
                                      AND TRUNC (store_open_date) <= SYSDATE
                               UNION
                               SELECT lookup_code loc
                                 FROM apps.fnd_lookup_values a
                                WHERE     lookup_type = 'XXDOINV007_WH'
                                      AND tag = 'JPY'
                                      AND LANGUAGE = 'US'
                                      AND enabled_flag = 'Y') whs
                       WHERE whs.loc = rms.loc AND rms.primary_cntry = 'JP'
                    GROUP BY rms.item) rms1
             WHERE     TO_CHAR (ebs.inventory_item_id) = rms1.item
                   AND apps.xxdoinv006_pkg.get_brand_f (
                           NULL,
                           ebs.inventory_item_id,
                           --7 -- Removed by Sreenath for BT
                           ebs.inventory_item_id-- Added by Sreenath for BT
                                                ) =
                       'UGG'
                   AND ebs.ebs_unit_cost <> rms1.rms_unit_cost;

        CURSOR c_itemcostchange_jp (pn_itemid    NUMBER,
                                    pn_orgnid    NUMBER,
                                    pn_jp_cost   NUMBER)
        IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('JP')),
                       XMLELEMENT ("v1:origin_country_id", 'JP'),
                       XMLELEMENT ("v1:diff_id", ''),
                       --XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'JP')),
                       XMLELEMENT ("v1:unit_cost", pn_jp_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'JPY'),
                       XMLELEMENT ("v1:hier_level", 'W'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", lookup_code)))
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXDOINV007_WH'
                               AND lookup_code IN
                                       (SELECT loc
                                          -- FROM rms13prod.item_loc_soh@rmsprod  -- removed by sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- added by sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'W'
                                               AND primary_cntry = 'JP') -- Added by Naga
                               AND LANGUAGE = 'US'
                               AND enabled_flag = 'Y'
                               AND description = 'JP')) itemcost
              --FROM mtl_system_items_b msib                                        --commented by BT team on 10/12/2014
              FROM xxd_common_items_v msib    --added by BT team on 10/12/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- removed by sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'W'
                                   AND primary_cntry = 'JP');

        CURSOR c_itemcost_ca (pn_cad_exchange NUMBER)
        IS
            SELECT msib.inventory_item_id, msib.organization_id, --  msib.segment1 style, msib.segment2 color, msib.segment3 sze,            --commented by BT Team on 10/12/2014
                                                                 msib.style_number style,
                   msib.color_code color, msib.item_size sze, --Added by BT Team on 10/12/2014
                                                              DECODE (ROUND ((qll.operand * pn_cad_exchange), 2), 0, 0.01, ROUND ((qll.operand * pn_cad_exchange), 2)) ca_region_cost,
                   qlh.list_header_id
              --FROM mtl_system_items_b msib,                                        --commented by BT team on 10/12/2014
              FROM xxd_common_items_v msib,   --added by BT team on 10/12/2014
                                            apps.qp_list_headers qlh, apps.qp_list_lines qll,
                   apps.qp_pricing_attributes qpa
             -- WHERE msib.segment3 <> 'ALL'                                                          --commented by BT Team on 12/10/2014
             WHERE     msib.item_type <> 'GENERIC' --Added by BT Team on 12/10/2014
                   AND (CASE
                            WHEN pv_rundate IS NOT NULL
                            THEN
                                TRUNC (qll.last_update_date)
                            ELSE
                                TRUNC (SYSDATE)
                        END) =
                       DECODE (
                           pv_rundate,
                           NULL, TRUNC (SYSDATE),
                           TRUNC (fnd_date.canonical_to_date (pv_rundate)))
                   AND qpa.list_line_id = qll.list_line_id
                   AND qll.list_header_id = qlh.list_header_id
                   AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                   AND qpa.product_attr_value = msib.inventory_item_id
                   -- AND msib.inventory_item_status_code = 'Active'
                   --AND msib.organization_id = 7 -- Removed by Sreenath for BT
                   -- Added by Sreenath for BT - Begin
                   /* AND msib.organization_id =
                                (SELECT organization_id
                                   FROM org_organization_definitions
                                  WHERE organization_name = 'MST_Deckers_Item_Master')*/
                   --commented by BT Team on 12/10/2014
                   AND msib.organization_id IN
                           (SELECT ood.ORGANIZATION_ID
                              FROM fnd_lookup_values flv, org_organization_definitions ood
                             WHERE     lookup_type =
                                       'XXD_1206_INV_ORG_MAPPING'
                                   AND lookup_code = 7
                                   AND flv.attribute1 = ood.ORGANIZATION_CODE
                                   AND language = USERENV ('LANG')) --Added bY BT Team on 09/12/2014
                   -- Added by Sreenath for BT - End
                   --            AND not exists (select 1 from packitem@rmsprod where item= to_char(msib.inventory_item_id))
                   AND SYSDATE BETWEEN NVL (qll.start_date_active, SYSDATE)
                                   AND NVL (qll.end_date_active, SYSDATE)
                   -- AND qlh.name  = 'Retail Canada Replenishment'
                   AND qlh.NAME =
                       (SELECT meaning
                          FROM apps.fnd_lookup_values_vl a
                         WHERE     lookup_type = 'XXDOINV_PRICE_LIST_NAME'
                               AND lookup_code = 'CA'
                               AND enabled_flag = 'Y')
                   AND xxdoinv006_pkg.get_brand_f (NULL,
                                                   msib.inventory_item_id,
                                                   msib.organization_id) =
                       'UGG'
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod ca -- removed by sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms ca
                             -- added by sreenath for BT
                             WHERE     primary_cntry = 'US'
                                   AND loc = 15205
                                   AND ROUND (ca.unit_cost, 2) <>
                                       ROUND (
                                           (qll.operand * pn_cad_exchange),
                                           2)
                                   AND item = qpa.product_attr_value);

        CURSOR c_itemcostchange_ca (pn_itemid        NUMBER,
                                    pn_orgnid        NUMBER,
                                    pn_region_cost   NUMBER)
        IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('US')),
                       XMLELEMENT ("v1:origin_country_id", 'US'),
                       XMLELEMENT ("v1:diff_id", ''),
                       XMLELEMENT ("v1:unit_cost", pn_region_cost),
                       --XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'CA')),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'USD'),
                       XMLELEMENT ("v1:hier_level", 'W'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", lookup_code)))
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXDOINV007_WH'
                               AND LANGUAGE = 'US'
                               AND enabled_flag = 'Y'
                               -- AND DESCRIPTION = 'CA'
                               AND lookup_code = 15205)) itemcost
              --FROM mtl_system_items_b msib                                                 --commented by BT Team on 12/10/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 12/10/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid;

        CURSOR c_itemcost_ca_s IS
            SELECT ebs.inventory_item_id, ebs.organization_id, ebs.style,
                   color, ebs.sze, ebs.ca_region_cost,
                   ebs.list_header_id, rms1.rms_unit_cost
              FROM (SELECT msib.inventory_item_id, msib.organization_id, -- msib.segment1 style, msib.segment2 color, msib.segment3 sze,                         --commented by BT Team on 10/12/2014
                                                                         msib.style_number style,
                           msib.color_code color, msib.item_size sze, --Added by BT Team on 10/12/2014
                                                                      DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2)) ca_region_cost,
                           qlh.list_header_id
                      --   FROM apps.mtl_system_items_b msib,                                                             --commented by BT Team on 10/12/2014
                      FROM xxd_common_items_v msib, --Added by BT Team on 10/12/2014
                                                    apps.qp_list_headers qlh, apps.qp_list_lines qll,
                           apps.qp_pricing_attributes qpa
                     --WHERE msib.segment3 <> 'ALL'                                                                     --commented by BT Team on 10/12/2014
                     WHERE     msib.item_type <> 'GENERIC' --Added by BT Team on 10/12/2014
                           AND (CASE
                                    WHEN pv_rundate IS NOT NULL
                                    THEN
                                        TRUNC (qll.last_update_date)
                                    ELSE
                                        TRUNC (SYSDATE)
                                END) =
                               DECODE (
                                   pv_rundate,
                                   NULL, TRUNC (SYSDATE),
                                   TRUNC (
                                       fnd_date.canonical_to_date (
                                           pv_rundate)))       --ADDED BY NAGA
                           AND qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                           AND qpa.product_attr_value =
                               msib.inventory_item_id
                           AND SYSDATE BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE)
                           --and msib.inventory_item_status_code = 'Active'
                           --AND msib.organization_id = 7 -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           /*  AND msib.organization_id =
                                    (SELECT organization_id
                                       FROM org_organization_definitions
                                      WHERE organization_name =
                                                              'MST_Deckers_Item_Master')*/
                           --commented by BT Team on 10/12/2014
                           AND msib.organization_id IN
                                   (SELECT ood.ORGANIZATION_ID
                                      FROM fnd_lookup_values flv, org_organization_definitions ood
                                     WHERE     lookup_type =
                                               'XXD_1206_INV_ORG_MAPPING'
                                           AND lookup_code = 7
                                           AND flv.attribute1 =
                                               ood.ORGANIZATION_CODE
                                           AND language = USERENV ('LANG')) --Added bY BT Team on 09/12/2014
                           -- Added by Sreenath for BT - End
                           --                    AND not exists (select 1 from rms13prod.packitem@rmsprod where item= to_char(msib.inventory_item_id))
                           -- and qlh.name  = 'Retail Canada Replenishment'
                           AND qlh.NAME =
                               (SELECT meaning
                                  FROM apps.fnd_lookup_values_vl a
                                 WHERE     lookup_type =
                                           'XXDOINV_PRICE_LIST_NAME'
                                       AND lookup_code = 'CA'
                                       AND enabled_flag = 'Y') -- ADDED NY NAGA
                           AND apps.xxdoinv006_pkg.get_brand_f (
                                   NULL,
                                   msib.inventory_item_id,
                                   msib.organization_id) =
                               'UGG') ebs,
                   (  SELECT /*+ DRIVING_SITE(rms) */
                             item, ROUND (AVG (unit_cost), 2) rms_unit_cost
                        --FROM rms13prod.item_loc_soh@rmsprod rms, -- Removed by Sreenath for BT
                        FROM rms13prod.item_loc_soh@xxdo_retail_rms rms,
                             -- Added by Sreenath for BT
                              (SELECT TO_CHAR (STORE) loc
                                 --FROM rms13prod.STORE@rmsprod -- Removed by Sreenath for BT
                                 FROM rms13prod.STORE@xxdo_retail_rms
                                -- Added by Sreenath for BT
                                WHERE     currency_code = 'CAD'
                                      AND store_class <> 'D'
                                      AND TRUNC (store_open_date) <= SYSDATE)
                             whs
                       WHERE     whs.loc = rms.loc
                             AND rms.loc <> 14031
                             AND rms.primary_cntry = 'CA'
                             AND loc_type = 'S'
                    GROUP BY rms.item) rms1
             WHERE     TO_CHAR (ebs.inventory_item_id) = rms1.item
                   AND ebs.ca_region_cost <> rms1.rms_unit_cost;

        CURSOR c_itemcost_s_ca (pn_itemid NUMBER, pn_orgnid NUMBER, pv_region1 VARCHAR2
                                , pn_region_cost NUMBER)
        IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('CA')),
                       XMLELEMENT ("v1:origin_country_id", 'CA'),
                       XMLELEMENT ("v1:diff_id", ''),
                       XMLELEMENT ("v1:unit_cost", pn_region_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'CAD'),
                       XMLELEMENT ("v1:hier_level", 'S'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", --  rms_store_id                                  --commented by BT Team on 10/12/2014
                                                                                                    lookup_code --Added by BT Team on 10/12/2014
                                                                                                               )))
                          --FROM stores@do_retail_datamart -- Removed for Sreenath for BT
                          --   FROM   xxd_retail_stores_v    -- Added by Sreenath for BT                       --commented by BT Team on 10/12/2014
                          FROM apps.fnd_lookup_values --Added by BT Team on 10/12/2014-START
                         WHERE     lookup_type = 'XXD_RETAIL_STORES'
                               AND enabled_flag = 'Y'
                               AND LANGUAGE = 'US' --Added by BT Team on 10/12/2014-END
                               /* WHERE region = pv_region1                                                    --commented by BT Team on 10/12/2014-START
                                  AND rms_store_id IS NOT NULL
                                  AND rms_store_id IN (*/
                                      --commented by BT Team on 10/12/2014-END
                               AND attribute3 = pv_region1 --commented by BT Team on 10/12/2014
                               AND lookup_code IS NOT NULL
                               AND lookup_code IN
                                       (  --Added by BT Team on 10/12/2014-END
                                        SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'S'
                                               AND primary_cntry = 'CA')
                               -- and (  UPPER(TRIM(store_type))     = PV_OUTLET  OR UPPER(TRIM(STORE_TYPE))  = PV_SHOKA OR UPPER(TRIM(STORE_TYPE))  = PV_CONCEPT )
                               --  AND brand IN ('ALL', 'UGG'))                                        --commented by BT Team on 10/12/2014
                               AND attribute9 IN ('ALL BRAND', 'UGG')) --Added by BT Team on 10/12/2014
                                                                      ) itemcost
              --  FROM mtl_system_items_b msib                         --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'S'
                                   AND primary_cntry = 'CA');

        -------------------------------------------------------------------------------
        CURSOR c_itemcost_cn IS
            SELECT ebs.inventory_item_id, ebs.organization_id, ebs.style,
                   color, ebs.sze, ebs.cn_region_cost,
                   ebs.list_header_id, rms1.rms_unit_cost
              FROM (SELECT ROWNUM, msib.inventory_item_id, msib.organization_id,
                           -- msib.segment1 style, msib.segment2 color, msib.segment3 sze,                         --commented by BT Team on 10/12/2014
                           msib.style_number style, msib.color_code color, msib.item_size sze, --Added by BT Team on 10/12/2014
                           DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2)) cn_region_cost, qlh.list_header_id
                      -- FROM apps.mtl_system_items_b msib,                                         --commented by BT Team on 10/12/2014
                      FROM apps.xxd_common_items_v msib, --Added by BT Team on 10/12/2014
                                                         apps.qp_list_headers qlh, apps.qp_list_lines qll,
                           apps.qp_pricing_attributes qpa
                     --WHERE msib.segment3 <> 'ALL'                                               --commented by BT Team on 10/12/2014
                     WHERE     msib.item_type <> 'GENERIC' --Added by BT Team on 10/12/2014
                           AND (CASE
                                    WHEN pv_rundate IS NOT NULL
                                    THEN
                                        TRUNC (qll.last_update_date)
                                    ELSE
                                        TRUNC (SYSDATE)
                                END) =
                               DECODE (
                                   pv_rundate,
                                   NULL, TRUNC (SYSDATE),
                                   TRUNC (
                                       fnd_date.canonical_to_date (
                                           pv_rundate)))       --ADDED BY NAGA
                           AND qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                           AND qpa.product_attr_value =
                               msib.inventory_item_id
                           AND SYSDATE BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE)
                           --and msib.inventory_item_status_code = 'Active'
                           --AND msib.organization_id = 7 -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           /*  AND msib.organization_id =
                                    (SELECT organization_id
                                       FROM org_organization_definitions
                                      WHERE organization_name =
                                                              'MST_Deckers_Item_Master')*/
                           --commented by BT Team on 10/12/2014
                           AND msib.organization_id IN
                                   (SELECT ood.organization_id
                                      FROM fnd_lookup_values flv, org_organization_definitions ood
                                     WHERE     lookup_type =
                                               'XXD_1206_INV_ORG_MAPPING'
                                           AND lookup_code = 7
                                           AND flv.attribute1 =
                                               ood.organization_code
                                           AND LANGUAGE = USERENV ('LANG'))
                           --Added by BT Technology team on 10/12/2014
                           -- Added by Sreenath for BT - End
                           --                    AND not exists (select 1 from rms13prod.packitem@rmsprod where item= to_char(msib.inventory_item_id))
                           --and qlh.name  = 'Retail China Replenishment'
                           AND qlh.NAME =
                               (SELECT meaning
                                  FROM apps.fnd_lookup_values_vl a
                                 WHERE     lookup_type =
                                           'XXDOINV_PRICE_LIST_NAME'
                                       AND lookup_code = 'CN'
                                       AND enabled_flag = 'Y')
                           AND apps.xxdoinv006_pkg.get_brand_f (
                                   NULL,
                                   msib.inventory_item_id,
                                   msib.organization_id) =
                               'UGG') ebs,
                   (  SELECT /*+ DRIVING_SITE(rms) */
                             item, ROUND (AVG (unit_cost), 2) rms_unit_cost
                        --FROM rms13prod.item_loc_soh@rmsprod rms, --Removed by Sreenath for BT
                        FROM rms13prod.item_loc_soh@xxdo_retail_rms rms,
                             --Added by Sreenath for BT
                              (SELECT TO_CHAR (STORE) loc
                                 -- FROM rms13prod.STORE@rmsprod -- Removed by Sreenath for BT
                                 FROM rms13prod.STORE@xxdo_retail_rms
                                -- added by sreenath for BT
                                WHERE     currency_code = 'CNY'
                                      AND store_class <> 'D'
                                      AND TRUNC (store_open_date) <= SYSDATE
                               UNION
                               SELECT lookup_code loc
                                 FROM apps.fnd_lookup_values a
                                WHERE     lookup_type = 'XXDOINV007_WH'
                                      AND tag = 'CNY'
                                      AND LANGUAGE = 'US'
                                      AND enabled_flag = 'Y') whs
                       WHERE     whs.loc = rms.loc
                             AND rms.loc <> 14031
                             AND rms.primary_cntry = 'CN'
                    GROUP BY rms.item) rms1
             WHERE     TO_CHAR (ebs.inventory_item_id) = rms1.item
                   AND ebs.cn_region_cost <> rms1.rms_unit_cost;

        CURSOR c_itemcostchange_cn (pn_itemid    NUMBER,
                                    pn_orgnid    NUMBER,
                                    pn_cn_cost   NUMBER)
        IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('CN')),
                       XMLELEMENT ("v1:origin_country_id", 'CN'),
                       XMLELEMENT ("v1:diff_id", ''),
                       --XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'CN')),
                       XMLELEMENT ("v1:unit_cost", pn_cn_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'CNY'),
                       XMLELEMENT ("v1:hier_level", 'W'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", lookup_code)))
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXDOINV007_WH'
                               AND lookup_code IN
                                       (SELECT loc
                                          -- FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'W'
                                               AND primary_cntry = 'CN') -- Added by Naga
                               AND enabled_flag = 'Y'
                               AND LANGUAGE = 'US'
                               AND description = 'CN')) itemcost
              -- FROM mtl_system_items_b msib                                         --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Srenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'W'
                                   AND primary_cntry = 'CN');

        CURSOR c_itemcost_fr IS
            SELECT ebs.inventory_item_id, ebs.organization_id, ebs.style,
                   color, ebs.sze, ebs.fr_region_cost,
                   ebs.list_header_id, rms1.rms_unit_cost
              FROM (SELECT ROWNUM, msib.inventory_item_id, msib.organization_id,
                           -- msib.segment1 style, msib.segment2 color, msib.segment3 sze,                     --commented by BT Team on 10/12/2014
                           msib.style_number style, msib.color_code color, msib.item_size sze, --Added by BT Team on 10/12/2014
                           DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2)) fr_region_cost, qlh.list_header_id
                      -- FROM apps.mtl_system_items_b msib,                                                   --commented by BT Team on 10/12/2014
                      FROM xxd_common_items_v msib, --Added by BT Team on 10/12/2014
                                                    apps.qp_list_headers qlh, apps.qp_list_lines qll,
                           apps.qp_pricing_attributes qpa
                     --WHERE msib.segment3 <> 'ALL'                                                          --commented by BT Team on 10/12/2014
                     WHERE     msib.item_type <> 'GENERIC' --Added by BT Team on 10/12/2014
                           AND (CASE
                                    WHEN pv_rundate IS NOT NULL
                                    THEN
                                        TRUNC (qll.last_update_date)
                                    ELSE
                                        TRUNC (SYSDATE)
                                END) =
                               DECODE (
                                   pv_rundate,
                                   NULL, TRUNC (SYSDATE),
                                   TRUNC (
                                       fnd_date.canonical_to_date (
                                           pv_rundate)))       --ADDED BY NAGA
                           AND qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                           AND qpa.product_attr_value =
                               msib.inventory_item_id
                           AND SYSDATE BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE)
                           -- AND msib.organization_id = 7 -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           /*AND msib.organization_id =
                                  (SELECT organization_id
                                     FROM org_organization_definitions
                                    WHERE organization_name =
                                                            'MST_Deckers_Item_Master')*/
                           --commented by BT Team on 10/12/2014
                           AND msib.organization_id IN
                                   (SELECT ood.organization_id
                                      FROM fnd_lookup_values flv, org_organization_definitions ood
                                     WHERE     lookup_type =
                                               'XXD_1206_INV_ORG_MAPPING'
                                           AND lookup_code = 7
                                           AND flv.attribute1 =
                                               ood.organization_code
                                           AND LANGUAGE = USERENV ('LANG'))
                           --Added by BT Technology team on 05/12/2014
                           -- Added by Sreenath for BT - End
                           --                    AND not exists (select 1 from rms13prod.packitem@rmsprod where item= to_char(msib.inventory_item_id))
                           -- AND qlh.name  = 'EUR Retail Inter-company Price List (UK2)'
                           AND qlh.NAME =
                               (SELECT meaning
                                  FROM apps.fnd_lookup_values_vl a
                                 WHERE     lookup_type =
                                           'XXDOINV_PRICE_LIST_NAME'
                                       AND lookup_code = 'FR'
                                       AND enabled_flag = 'Y') -- ADDED NY NAGA
                           AND apps.xxdoinv006_pkg.get_brand_f (
                                   NULL,
                                   msib.inventory_item_id,
                                   msib.organization_id) =
                               'UGG') ebs,
                   (  SELECT /*+ DRIVING_SITE(rms) */
                             item, ROUND (AVG (unit_cost), 2) rms_unit_cost
                        --FROM rms13prod.item_loc_soh@rmsprod rms,  -- Removed by Sreenath for BT
                        FROM rms13prod.item_loc_soh@xxdo_retail_rms rms,
                             -- Added by Sreenath for BT
                              (SELECT TO_CHAR (STORE) loc
                                 --FROM rms13prod.STORE@rmsprod  -- Removed by Sreenath for BT
                                 FROM rms13prod.STORE@xxdo_retail_rms
                                -- Added by Sreenath for BT
                                WHERE     currency_code = 'EUR'
                                      AND store_class <> 'D'
                                      AND TRUNC (store_open_date) <= SYSDATE
                               UNION
                               SELECT lookup_code loc
                                 FROM apps.fnd_lookup_values a
                                WHERE     lookup_type = 'XXDOINV007_WH'
                                      AND tag = 'EUR'
                                      AND LANGUAGE = 'US'
                                      AND enabled_flag = 'Y') whs
                       WHERE whs.loc = rms.loc AND primary_cntry = 'FR'
                    GROUP BY rms.item) rms1
             WHERE     TO_CHAR (ebs.inventory_item_id) = rms1.item
                   AND ebs.fr_region_cost <> rms1.rms_unit_cost;

        CURSOR c_itemcostchange_fr (pn_itemid    NUMBER,
                                    pn_orgnid    NUMBER,
                                    pn_fr_cost   NUMBER)
        IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('FR')),
                       XMLELEMENT ("v1:origin_country_id", 'FR'),
                       XMLELEMENT ("v1:diff_id", ''),
                       --XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'FR')),
                       XMLELEMENT ("v1:unit_cost", pn_fr_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'EUR'),
                       XMLELEMENT ("v1:hier_level", 'W'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", lookup_code)))
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXDOINV007_WH'
                               AND lookup_code IN
                                       (SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'W'
                                               AND primary_cntry = 'FR')
                               AND LANGUAGE = 'US'
                               AND enabled_flag = 'Y'
                               AND description = 'FR')) itemcost
              -- FROM mtl_system_items_b msib                                          --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              -- FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'W'
                                   AND primary_cntry = 'FR');

        CURSOR c_itemcost_hk IS
            SELECT ebs.inventory_item_id, ebs.organization_id, ebs.style,
                   color, ebs.sze, ebs.hk_region_cost,
                   ebs.list_header_id, rms1.rms_unit_cost
              FROM (SELECT ROWNUM, msib.inventory_item_id, msib.organization_id,
                           -- msib.segment1 style, msib.segment2 color, msib.segment3 sze,                     --commented by BT Team on 10/12/2014
                           msib.style_number style, msib.color_code color, msib.item_size sze, --Added by BT Team on 10/12/2014
                           DECODE (ROUND (qll.operand, 2), 0, 0.01, ROUND (qll.operand, 2)) hk_region_cost, qlh.list_header_id
                      --  FROM apps.mtl_system_items_b msib,                                                        --commented by BT Team on 10/12/2014
                      FROM xxd_common_items_v msib, --Added by BT team on 10/12/2014
                                                    apps.qp_list_headers qlh, apps.qp_list_lines qll,
                           apps.qp_pricing_attributes qpa
                     --WHERE msib.segment3 <> 'ALL'                                                            --commented by BT Team on 10/12/2014
                     WHERE     msib.item_type <> 'GENERIC' --Added by BT Team on 10/12/2014
                           AND (CASE
                                    WHEN pv_rundate IS NOT NULL
                                    THEN
                                        TRUNC (qll.last_update_date)
                                    ELSE
                                        TRUNC (SYSDATE)
                                END) =
                               DECODE (
                                   pv_rundate,
                                   NULL, TRUNC (SYSDATE),
                                   TRUNC (
                                       fnd_date.canonical_to_date (
                                           pv_rundate)))
                           AND qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                           AND qpa.product_attr_value =
                               msib.inventory_item_id
                           --AND msib.organization_id = 7 -- Removed by Sreenath for BT
                           -- Added by Sreenath for BT - Begin
                           /* AND msib.organization_id =
                                   (SELECT organization_id
                                      FROM org_organization_definitions
                                     WHERE organization_name =
                                                             'MST_Deckers_Item_Master')*/
                           --commented by BT Team on 10/12/2014
                           AND msib.organization_id IN
                                   (SELECT ood.organization_id
                                      FROM fnd_lookup_values flv, org_organization_definitions ood
                                     WHERE     lookup_type =
                                               'XXD_1206_INV_ORG_MAPPING'
                                           AND lookup_code = 7
                                           AND flv.attribute1 =
                                               ood.organization_code
                                           AND LANGUAGE = USERENV ('LANG'))
                           --Added by BT Technology team on 10/12/2014
                           -- Added by Sreenath for BT - End
                           --                    AND not exists (select 1 from rms13prod.packitem@rmsprod where item= to_char(msib.inventory_item_id))
                           AND SYSDATE BETWEEN NVL (qll.start_date_active,
                                                    SYSDATE)
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE)
                           AND qlh.NAME =
                               (SELECT meaning
                                  FROM apps.fnd_lookup_values_vl a
                                 WHERE     lookup_type =
                                           'XXDOINV_PRICE_LIST_NAME'
                                       AND lookup_code = 'HK'
                                       AND enabled_flag = 'Y')
                           AND xxdoinv006_pkg.get_brand_f (
                                   NULL,
                                   msib.inventory_item_id,
                                   msib.organization_id) =
                               'UGG') ebs,
                   (  SELECT /*+ DRIVING_SITE(rms) */
                             item, ROUND (AVG (unit_cost), 2) rms_unit_cost
                        --FROM rms13prod.item_loc_soh@rmsprod rms,  -- Removed by Sreenath for BT
                        FROM rms13prod.item_loc_soh@xxdo_retail_rms rms,
                             -- Added by Sreenath for BT
                              (SELECT TO_CHAR (STORE) loc
                                 --FROM rms13prod.STORE@rmsprod -- Removed by Sreenath for BT
                                 FROM rms13prod.STORE@xxdo_retail_rms
                                -- added by Sreenath for BT
                                WHERE     currency_code = 'HKD'
                                      AND store_class <> 'D'
                                      AND TRUNC (store_open_date) <= SYSDATE
                               UNION
                               SELECT lookup_code loc
                                 FROM apps.fnd_lookup_values a
                                WHERE     lookup_type = 'XXDOINV007_WH'
                                      AND tag = 'HKD'
                                      AND LANGUAGE = 'US'
                                      AND enabled_flag = 'Y') whs
                       WHERE whs.loc = rms.loc AND primary_cntry = 'HK'
                    GROUP BY rms.item) rms1
             WHERE     TO_CHAR (ebs.inventory_item_id) = rms1.item
                   AND ebs.hk_region_cost <> rms1.rms_unit_cost;

        CURSOR c_itemcostchange_hk (pn_itemid    NUMBER,
                                    pn_orgnid    NUMBER,
                                    pn_hk_cost   NUMBER)
        IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('HK')),
                       XMLELEMENT ("v1:origin_country_id", 'HK'),
                       XMLELEMENT ("v1:diff_id", ''),
                       --XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'HK')),
                       XMLELEMENT ("v1:unit_cost", pn_hk_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'HKD'),
                       XMLELEMENT ("v1:hier_level", 'W'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", lookup_code)))
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXDOINV007_WH'
                               AND lookup_code IN
                                       (SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'W'
                                               AND primary_cntry = 'HK')
                               AND LANGUAGE = 'US'
                               AND enabled_flag = 'Y'
                               AND description = 'HK')) itemcost
              --  FROM mtl_system_items_b msib                                               --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'W'
                                   AND primary_cntry = 'HK');

        CURSOR c_itemcost_s_us (pn_item_id NUMBER, pn_orgnid NUMBER, pv_brand VARCHAR2
                                , pv_region1 VARCHAR2, pn_us_cost NUMBER)
        IS      --PV_OUTLET VARCHAR2,PV_SHOKA VARCHAR2,PV_CONCEPT VARCHAR2) IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('US')),
                       XMLELEMENT ("v1:origin_country_id", 'US'),
                       XMLELEMENT ("v1:diff_id", ''),
                       XMLELEMENT ("v1:unit_cost", pn_us_cost--                         xxdoinv006_pkg.get_cost_us_f (msib.inventory_item_id,
                                                             --                                                       msib.organization_id
                                                             --                                                      )
                                                             ),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code",
                                   xxdoinv006_pkg.get_curr_code_f ('US')),
                       XMLELEMENT ("v1:hier_level", 'S'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", --rms_store_id                            --commented by BT Team on 10/12/2014
                                                                                                    lookup_code --Added by BT Team on 10/12/2014
                                                                                                               )))
                          --FROM stores@do_retail_datamart -- Removed by Sreenath for BT
                          /* FROM   xxd_retail_stores_v    -- Added by Sreenath for BT                 --commented by BT Team on 10/12/2014-START
                            WHERE region = pv_region1
                              AND rms_store_id IN (*/
                          --commented by BT Team on 10/12/2014-END
                          FROM apps.fnd_lookup_values --Added by BT Team on 10/12/2014-START
                         WHERE     lookup_type = 'XXD_RETAIL_STORES'
                               AND enabled_flag = 'Y'
                               AND LANGUAGE = 'US'
                               AND attribute3 = pv_region1
                               AND lookup_code IN
                                       (  --Added by BT Team on 10/12/2014-END
                                        SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod  -- Removed for Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added for Sreenath for BT
                                         WHERE     item =
                                                   TO_CHAR (pn_item_id)
                                               AND loc_type = 'S'
                                               AND primary_cntry = 'US')
                               --   AND rms_store_id IS NOT NULL                                          --commented by BT Team on 10/12/2014
                               AND lookup_code IS NOT NULL --Added by BT Team on 10/12/2014
                               -- AND  (  UPPER(TRIM(store_type))     = PV_OUTLET  OR UPPER(TRIM(STORE_TYPE))  = PV_SHOKA OR UPPER(TRIM(STORE_TYPE))  = PV_CONCEPT )
                               --AND brand IN ('ALL', pv_brand))                                      --commented by BT Team on 10/12/2014
                               AND attribute9 IN ('ALL BRAND', pv_brand)) --Added by BT Team on 10/12/2014
                                                                         ) itemcost
              --FROM mtl_system_items_b msib                                                       --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     msib.inventory_item_id = pn_item_id
                   AND msib.organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- Removed for Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added for Sreenath for BT
                             WHERE     item = TO_CHAR (pn_item_id)
                                   AND loc_type = 'S'
                                   AND primary_cntry = 'US');

        CURSOR c_itemcost_s_uk (pn_itemid NUMBER, pn_orgnid NUMBER, pv_region1 VARCHAR2
                                , pn_uk_cost NUMBER)
        IS      --PV_OUTLET VARCHAR2,PV_SHOKA VARCHAR2,PV_CONCEPT VARCHAR2) IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('UK')),
                       XMLELEMENT ("v1:origin_country_id", 'GB'),
                       XMLELEMENT ("v1:diff_id", ''),
                       XMLELEMENT ("v1:unit_cost", pn_uk_cost),
                       --                              xxdoinv006_pkg.get_region_cost_f (msib.segment1,
                       --                                                                msib.segment2,
                       --                                                                msib.segment3,
                       --                                                                'UK'
                       --                                                               )),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'GBP'),
                       XMLELEMENT ("v1:hier_level", 'S'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", --rms_store_id                            --commented by BT Team on 10/12/2014
                                                                                                    lookup_code --Added by BT Team on 10/12/2014
                                                                                                               )))
                          --FROM stores@do_retail_datamart -- Removed by Sreenath for BT
                          /* FROM   xxd_retail_stores_v    -- Added by Sreenath for BT                                     --commented by BT Team on 10/12/2014-START
                            WHERE region = pv_region1
                              AND rms_store_id IN (*/
                          --commented by BT Team on 10/12/2014-END
                          FROM apps.fnd_lookup_values --Added by BT Team on 10/12/2014-START
                         WHERE     lookup_type = 'XXD_RETAIL_STORES'
                               AND enabled_flag = 'Y'
                               AND LANGUAGE = 'US'
                               AND attribute3 = pv_region1
                               AND lookup_code IN
                                       (  --Added by BT Team on 10/12/2014-END
                                        SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod -- Removed By sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'S'
                                               AND primary_cntry = 'GB')
                               --AND rms_store_id IS NOT NULL                                      --commented by BT Team on 10/12/2014
                               AND lookup_code IS NOT NULL --Added by BT Team on 10/12/2014
                               -- and (  UPPER(TRIM(store_type))     = PV_OUTLET  OR UPPER(TRIM(STORE_TYPE))  = PV_SHOKA OR UPPER(TRIM(STORE_TYPE))  = PV_CONCEPT )
                               --AND brand IN ('ALL', 'UGG'))                                                        --commented by BT Team on 10/12/2014
                               AND attribute9 IN ('ALL BRAND', 'UGG')) --Added by BT Team on 10/12/2014
                                                                      ) itemcost
              -- FROM mtl_system_items_b msib                                                      --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     msib.inventory_item_id = pn_itemid
                   AND msib.organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'S'
                                   AND primary_cntry = 'GB');

        CURSOR c_itemcost_s_jp (pn_itemid NUMBER, pn_orgnid NUMBER, pv_region1 VARCHAR2
                                , pn_jp_cost NUMBER)
        IS      --PV_OUTLET VARCHAR2,PV_SHOKA VARCHAR2,PV_CONCEPT VARCHAR2) IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('JP')),
                       XMLELEMENT ("v1:origin_country_id", 'JP'),
                       XMLELEMENT ("v1:diff_id", ''),
                       -- XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'JP')),
                       XMLELEMENT ("v1:unit_cost", pn_jp_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'JPY'),
                       XMLELEMENT ("v1:hier_level", 'S'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", --rms_store_id                            --commented by BT Team on 10/12/2014
                                                                                                    lookup_code --Added by BT Team on 10/12/2014
                                                                                                               )))
                          --FROM stores@do_retail_datamart -- Removed by Sreenath for BT
                          /* FROM   xxd_retail_stores_v    -- Added by Sreenath for BT                                     --commented by BT Team on 10/12/2014-START
                            WHERE region = pv_region1
                              AND rms_store_id IN (*/
                          --commented by BT Team on 10/12/2014-END
                          FROM apps.fnd_lookup_values --Added by BT Team on 10/12/2014-START
                         WHERE     lookup_type = 'XXD_RETAIL_STORES'
                               AND enabled_flag = 'Y'
                               AND LANGUAGE = 'US'
                               AND attribute3 = pv_region1
                               AND lookup_code IN
                                       (  --Added by BT Team on 10/12/2014-END
                                        SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added By Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'S'
                                               AND primary_cntry = 'JP')
                               --AND rms_store_id IS NOT NULL                                      --commented by BT Team on 10/12/2014
                               AND lookup_code IS NOT NULL --Added by BT Team on 10/12/2014
                               --   and (  UPPER(TRIM(store_type))     = PV_OUTLET OR UPPER(TRIM(STORE_TYPE))  = PV_SHOKA  OR UPPER(TRIM(STORE_TYPE))  = PV_CONCEPT )
                               --AND brand IN ('ALL', 'UGG'))                                                        --commented by BT Team on 10/12/2014
                               AND attribute9 IN ('ALL BRAND', 'UGG')) --Added by BT Team on 10/12/2014
                                                                      ) itemcost
              -- FROM mtl_system_items_b msib                                                      --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     msib.inventory_item_id = pn_itemid
                   AND msib.organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'S'
                                   AND primary_cntry = 'JP');

        CURSOR c_itemcost_s_cn (pn_itemid NUMBER, pn_orgnid NUMBER, pv_region1 VARCHAR2
                                , pn_cn_cost NUMBER)
        IS     --,PV_OUTLET VARCHAR2,PV_SHOKA VARCHAR2,PV_CONCEPT VARCHAR2) IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('CN')),
                       XMLELEMENT ("v1:origin_country_id", 'CN'),
                       XMLELEMENT ("v1:diff_id", ''),
                       --XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'CN')),
                       XMLELEMENT ("v1:unit_cost", pn_cn_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'CNY'),
                       XMLELEMENT ("v1:hier_level", 'S'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", --rms_store_id                            --commented by BT Team on 10/12/2014
                                                                                                    lookup_code --Added by BT Team on 10/12/2014
                                                                                                               )))
                          --FROM stores@do_retail_datamart -- Removed by Sreenath for BT
                          /* FROM   xxd_retail_stores_v    -- Added by Sreenath for BT                                     --commented by BT Team on 10/12/2014-START
                            WHERE region = pv_region1
                              AND rms_store_id IN (*/
                          --commented by BT Team on 10/12/2014-END
                          FROM apps.fnd_lookup_values --Added by BT Team on 10/12/2014-START
                         WHERE     lookup_type = 'XXD_RETAIL_STORES'
                               AND enabled_flag = 'Y'
                               AND LANGUAGE = 'US'
                               AND attribute3 = pv_region1
                               AND lookup_code IN
                                       (  --Added by BT Team on 10/12/2014-END
                                        SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'S'
                                               AND primary_cntry = 'CN')
                               --AND rms_store_id IS NOT NULL                                      --commented by BT Team on 10/12/2014
                               AND lookup_code IS NOT NULL --Added by BT Team on 10/12/2014
                               -- and (  UPPER(TRIM(store_type))     = PV_OUTLET OR UPPER(TRIM(STORE_TYPE))  = PV_SHOKA    OR UPPER(TRIM(STORE_TYPE))  = PV_CONCEPT )
                               --AND brand IN ('ALL', 'UGG'))                                                        --commented by BT Team on 10/12/2014
                               AND attribute9 IN ('ALL BRAND', 'UGG')) --Added by BT Team on 10/12/2014
                                                                      ) itemcost
              -- FROM mtl_system_items_b msib                                                      --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added By Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'S'
                                   AND primary_cntry = 'CN');

        /*AND xxdoinv006_pkg.get_brand_f (NULL,
                                        msib.inventory_item_id,
                                        msib.organization_id
                                       ) = 'UGG';*/
        CURSOR c_itemcost_s_fr (pn_itemid NUMBER, pn_orgnid NUMBER, pv_region1 VARCHAR2
                                , pn_fr_cost NUMBER)
        IS      --PV_OUTLET VARCHAR2,PV_SHOKA VARCHAR2,PV_CONCEPT VARCHAR2) IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('FR')),
                       XMLELEMENT ("v1:origin_country_id", 'FR'),
                       XMLELEMENT ("v1:diff_id", ''),
                       --XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'FR')),
                       XMLELEMENT ("v1:unit_cost", pn_fr_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'EUR'),
                       XMLELEMENT ("v1:hier_level", 'S'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", --rms_store_id                            --commented by BT Team on 10/12/2014
                                                                                                    lookup_code --Added by BT Team on 10/12/2014
                                                                                                               )))
                          --FROM stores@do_retail_datamart -- Removed by Sreenath for BT
                          /* FROM   xxd_retail_stores_v    -- Added by Sreenath for BT                                     --commented by BT Team on 10/12/2014-START
                           WHERE region = pv_region1
                             AND rms_store_id IN (*/
                          --commented by BT Team on 10/12/2014-END
                          FROM apps.fnd_lookup_values --Added by BT Team on 10/12/2014-START
                         WHERE     lookup_type = 'XXD_RETAIL_STORES'
                               AND enabled_flag = 'Y'
                               AND LANGUAGE = 'US'
                               AND attribute3 = pv_region1
                               AND lookup_code IN
                                       (  --Added by BT Team on 10/12/2014-END
                                        SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod  -- Removed by Sreenath foro BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'S'
                                               AND primary_cntry = 'FR')
                               --AND rms_store_id IS NOT NULL                                      --commented by BT Team on 10/12/2014
                               AND lookup_code IS NOT NULL --Added by BT Team on 10/12/2014
                               -- and (  UPPER(TRIM(store_type))     = PV_OUTLET OR UPPER(TRIM(STORE_TYPE))  = PV_SHOKA    OR UPPER(TRIM(STORE_TYPE))  = PV_CONCEPT )
                               --AND brand IN ('ALL', 'UGG'))                                                        --commented by BT Team on 10/12/2014
                               AND attribute9 IN ('ALL BRAND', 'UGG')) --Added by BT Team on 10/12/2014
                                                                      ) itemcost
              -- FROM mtl_system_items_b msib                                                      --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod  -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'S'
                                   AND primary_cntry = 'FR');

        CURSOR c_itemcost_s_hk (pn_itemid NUMBER, pn_orgnid NUMBER, pv_region1 VARCHAR2
                                , pn_hk_cost NUMBER)
        IS      --PV_OUTLET VARCHAR2,PV_SHOKA VARCHAR2,PV_CONCEPT VARCHAR2) IS
            SELECT XMLELEMENT (
                       "v1:XCostChgDesc",
                       XMLELEMENT ("v1:item", msib.inventory_item_id),
                       XMLELEMENT ("v1:supplier",
                                   xxdoinv006_pkg.get_vendor_id_f ('HK')),
                       XMLELEMENT ("v1:origin_country_id", 'HK'),
                       XMLELEMENT ("v1:diff_id", ''),
                       --XMLELEMENT ("v1:unit_cost", XXDOINV006_PKG.get_region_cost_f(msib.segment1,msib.segment2,msib.segment3,'HK')),
                       XMLELEMENT ("v1:unit_cost", pn_hk_cost),
                       XMLELEMENT ("v1:recalc_ord_ind", 'N'),
                       XMLELEMENT ("v1:currency_code", 'HKD'),
                       XMLELEMENT ("v1:hier_level", 'S'),
                       (SELECT XMLAGG (XMLELEMENT ("v1:XCostChgHrDtl", XMLELEMENT ("v1:hier_value", --rms_store_id                            --commented by BT Team on 10/12/2014
                                                                                                    lookup_code --Added by BT Team on 10/12/2014
                                                                                                               )))
                          --FROM stores@do_retail_datamart --removed by sreenath for BT
                          /* FROM   xxd_retail_stores_v    -- Added by Sreenath for BT                                     --commented by BT Team on 10/12/2014-START
                             WHERE region = pv_region1
                               AND rms_store_id IN (*/
                          --commented by BT Team on 10/12/2014-END
                          FROM apps.fnd_lookup_values --Added by BT Team on 10/12/2014-START
                         WHERE     lookup_type = 'XXD_RETAIL_STORES'
                               AND enabled_flag = 'Y'
                               AND LANGUAGE = 'US'
                               AND attribute3 = pv_region1
                               AND lookup_code IN
                                       (  --Added by BT Team on 10/12/2014-END
                                        SELECT loc
                                          --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                                          FROM rms13prod.item_loc_soh@xxdo_retail_rms
                                         -- Added by Sreenath for BT
                                         WHERE     item = TO_CHAR (pn_itemid)
                                               AND loc_type = 'S'
                                               AND primary_cntry = 'HK')
                               --AND rms_store_id IS NOT NULL                                      --commented by BT Team on 10/12/2014
                               AND lookup_code IS NOT NULL --Added by BT Team on 10/12/2014
                               -- and (  UPPER(TRIM(store_type))     = PV_OUTLET OR UPPER(TRIM(STORE_TYPE))  = PV_SHOKA    OR UPPER(TRIM(STORE_TYPE))  = PV_CONCEPT )
                               --AND brand IN ('ALL', 'UGG'))                                                        --commented by BT Team on 10/12/2014
                               AND attribute9 IN ('ALL BRAND', 'UGG')) --Added by BT Team on 10/12/2014
                                                                      ) itemcost
              -- FROM mtl_system_items_b msib                                                      --commented by BT Team on 10/12/2014
              FROM xxd_common_items_v msib    --Added by BT Team on 10/12/2014
             WHERE     inventory_item_id = pn_itemid
                   AND organization_id = pn_orgnid
                   AND EXISTS
                           (SELECT 1
                              --FROM rms13prod.item_loc_soh@rmsprod -- Removed by Sreenath for BT
                              FROM rms13prod.item_loc_soh@xxdo_retail_rms
                             -- Added by Sreenath for BT
                             WHERE     item = TO_CHAR (pn_itemid)
                                   AND loc_type = 'S'
                                   AND primary_cntry = 'HK');

        /***************************************************************************************************************************************************

        *******/
        CURSOR c_itemcostpublish IS
            SELECT *
              FROM xxdoinv010_int
             WHERE status_flag = 'N';

        CURSOR c_costrepublish (pv_fdate             VARCHAR2,
                                pv_tdate             VARCHAR2,
                                pv_store_warehouse   VARCHAR2)
        IS
            SELECT *
              FROM xxdoinv010_int
             WHERE     status_flag IN ('VE', 'P')
                   AND store_warehouse = pv_store_warehouse
                   AND TRUNC (transmission_date) BETWEEN TRUNC (
                                                             fnd_date.canonical_to_date (
                                                                 pv_fdate))
                                                     AND TRUNC (
                                                             fnd_date.canonical_to_date (
                                                                 pv_tdate));
    BEGIN
        /* Query to fetch the conversion rate for Canada.  */
        ln_cad_exchange    := NULL;

        --EXECUTE IMMEDIATE 'TRUNCATE TABLE  xxdoinv010_int';
        DELETE xxdoinv010_int
         WHERE transmission_date <= (SYSDATE - 90);

        COMMIT;

        BEGIN
            SELECT exchange_rate
              INTO ln_cad_exchange
              --FROM rms13prod.currency_rates@rmsprod  -- Removed by Sreenath for BT
              FROM rms13prod.currency_rates@xxdo_retail_rms
             -- Added by Sreenath for BT
             WHERE     exchange_type = 'C'
                   AND currency_code = 'CAD'
                   AND effective_date =
                       (SELECT MAX (effective_date)
                          --FROM rms13prod.currency_rates@rmsprod   -- Removed by Sreenath for BT
                          FROM rms13prod.currency_rates@xxdo_retail_rms
                         -- Added by Sreenath for BT
                         WHERE exchange_type = 'C' AND currency_code = 'CAD');

            fnd_file.put_line (fnd_file.LOG,
                               'Canada Exchange' || ln_cad_exchange);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error occured while fetching Canada Exchange Rate in Cost Change');
        END;

        /* Setting the Retail PROD/DEV Environment based on Oracle Prod / Dev Instances */
        BEGIN
            SELECT DECODE (applications_system_name, 'PROD', apps.fnd_profile.VALUE ('XXDO: RETAIL PROD'), apps.fnd_profile.VALUE ('XXDO: RETAIL TEST')) file_server_name
              INTO lv_wsdl_ip
              FROM apps.fnd_product_groups;

            fnd_file.put_line (fnd_file.LOG,
                               'Setting PROD/DEV Environment ' || lv_wsdl_ip);
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Unable to fetch the File server name');
                pv_retcode   := 2;
        END;

        /* Initializing the Item cost web service variables */
        lv_wsdl_url        :=
               'http://'
            || lv_wsdl_ip
            || '/XCostChgPublishingBean/XCostChgPublishingService?WSDL';
        lv_namespace       :=
            'http://www.oracle.com/retail/igs/integration/services/XCostChgPublishingService/v1';
        lv_service         := 'XCostChgPublishingService';
        lv_port            := 'XCostChgPublishingPort';
        lv_operation       := 'publishXCostChgModifyUsingXCostChgDesc';
        lv_targetname      :=
               'http://'
            || lv_wsdl_ip
            || '/XCostChgPublishingBean/XCostChgPublishingService';
        /*******************************************************************************************************/
        -- Add logic to insert records into XXDOINV010_INT both warehouse and store  instead of Two different loops warehouse and store.
        lv_item_cost       := 0;
        lv_cmp_item_cost   := 0;
        lv_noof_items      := 0;
        --lv_item_id := NULL;
        lv_status          := NULL;

        IF NVL (pv_region, 'US') = 'US'
        THEN
            FOR rec_itemcost IN c_itemcost
            LOOP
                --Added by Reddeiah Cost change for POP Items -ENHC0012047
                lv_status    :=
                    check_pop_item_f (rec_itemcost.inventory_item_id);

                IF lv_status = 'Y'
                THEN
                    lv_cmp_item_id   :=
                        get_pack_item_f (rec_itemcost.inventory_item_id);
                    lv_cmp_item_cost   :=
                        xxdoinv006_pkg.get_cost_us_f (
                            lv_cmp_item_id,
                            rec_itemcost.organization_id);
                    lv_noof_items   :=
                        get_no_of_pop_items_f (
                            rec_itemcost.inventory_item_id);

                    IF lv_cmp_item_cost <> 0
                    THEN
                        lv_item_cost   := lv_cmp_item_cost;
                    ELSIF lv_noof_items <> 0
                    THEN
                        IF    rec_itemcost.ebs_unit_cost = 0
                           OR rec_itemcost.ebs_unit_cost = 0.01
                        THEN
                            lv_item_cost   := 0.01;
                        ELSE
                            lv_item_cost   :=
                                ROUND (
                                      rec_itemcost.ebs_unit_cost
                                    / lv_noof_items,
                                    2);
                        END IF;
                    END IF;

                    BEGIN
                        -- SELECT segment1, segment2, segment3                                      --commented by BT TEam on 10/12/2014
                        SELECT style_number, color_code, item_size --Added by BT Team on 10/12/2014
                          INTO lv_style, lv_color, lv_sze
                          --FROM apps.mtl_system_items_b                                                    --commented by BT Team on 10/12/2014
                          FROM xxd_common_items_v --Added by BT Team on 10/12/2014
                         WHERE     inventory_item_id = lv_cmp_item_id
                               --AND organization_id = 7 -- Removed by Sreenath for BT
                               -- Added by Sreenath for BT - Begin
                               /*  AND organization_id =                                                    --commented by BT Team on 10/12/2014-START
                                        (SELECT organization_id
                                           FROM org_organization_definitions
                                          WHERE organization_name =
                                                                 'MST_Deckers_Item_Master');*/
                               --commented by BT Team on 10/12/2014-END
                               AND organization_id IN
                                       ( --Added by BT Technology team on 10/12/2014-START
                                        SELECT ood.organization_id
                                          FROM fnd_lookup_values flv, org_organization_definitions ood
                                         WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                               AND lookup_code = 7
                                               AND flv.attribute1 =
                                                   ood.organization_code
                                               AND LANGUAGE =
                                                   USERENV ('LANG'));
                    --Added by BT Technology team on 10/12/2014-END/12/2014
                    -- Added by Sreenath for BT - End
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured');
                    END;

                    BEGIN
                        SELECT xxdoinv006_pkg.get_brand_f (NULL, rec_itemcost.inventory_item_id, rec_itemcost.organization_id)
                          INTO lv_brand
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured');
                    END;

                    FOR us_cur
                        IN c_itemcostchange_us (lv_cmp_item_id,
                                                rec_itemcost.organization_id,
                                                lv_item_cost)
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        region_cost,
                                                        xdata,
                                                        store_warehouse,
                                                        parent_request_id)
                                     VALUES (
                                                xxdoinv010_int_s.NEXTVAL,
                                                lv_cmp_item_id,
                                                rec_itemcost.organization_id,
                                                lv_style,
                                                lv_color,
                                                lv_sze,
                                                'US',
                                                'N',
                                                lv_item_cost,
                                                XMLTYPE.getclobval (
                                                    us_cur.itemcost),
                                                'WH',
                                                lv_request_id);

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 1:  Exception occured and verify the table data with error ');
                        END;
                    --end;
                    END LOOP;                           /* For WH US CURSOR */

                    FOR store_cur IN c_itemcost_s_us (lv_cmp_item_id, rec_itemcost.organization_id, lv_brand
                                                      , 'US', lv_item_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT) Added by Naga
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        xdata,
                                                        store_warehouse,
                                                        region_cost,
                                                        parent_request_id)
                                 VALUES (xxdoinv010_int_s.NEXTVAL, lv_cmp_item_id, rec_itemcost.organization_id, lv_style, lv_color, lv_sze, 'US', 'N', XMLTYPE.getclobval (store_cur.itemcost)
                                         , 'S', lv_item_cost, lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 2:  Exception occured and verify the table data with error ');
                        END;
                    -- END;
                    END LOOP;
                END IF;

                SELECT xxdoinv006_pkg.get_brand_f (NULL, rec_itemcost.inventory_item_id, rec_itemcost.organization_id)
                  INTO lv_brand
                  FROM DUAL;

                FOR us_cur
                    IN c_itemcostchange_us (rec_itemcost.inventory_item_id,
                                            rec_itemcost.organization_id,
                                            rec_itemcost.ebs_unit_cost)
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    region_cost,
                                                    xdata,
                                                    store_warehouse,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost.inventory_item_id,
                                            rec_itemcost.organization_id,
                                            rec_itemcost.style,
                                            rec_itemcost.color,
                                            rec_itemcost.sze,
                                            'US',
                                            'N',
                                            rec_itemcost.ebs_unit_cost,
                                            XMLTYPE.getclobval (
                                                us_cur.itemcost),
                                            'WH',
                                            lv_request_id);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured and verify the table data with error ');
                    END;
                --end;
                END LOOP;                               /* For WH US CURSOR */

                FOR store_cur
                    IN c_itemcost_s_us (rec_itemcost.inventory_item_id, rec_itemcost.organization_id, lv_brand
                                        , 'US', rec_itemcost.ebs_unit_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT) Added by Naga
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    xdata,
                                                    store_warehouse,
                                                    region_cost,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost.inventory_item_id,
                                            rec_itemcost.organization_id,
                                            rec_itemcost.style,
                                            rec_itemcost.color,
                                            rec_itemcost.sze,
                                            'US',
                                            'N',
                                            XMLTYPE.getclobval (
                                                store_cur.itemcost),
                                            'S',
                                            rec_itemcost.ebs_unit_cost,
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 2:  Exception occured and verify the table data with error ');
                    END;
                -- END;
                END LOOP;                                  /* For  STORE US */

                lv_counter   := lv_counter + 1;

                IF (lv_counter = 500)
                THEN
                    COMMIT;
                    lv_counter   := 0;
                END IF;
            END LOOP;                                      -- FOR REC_ITEMCOST

            COMMIT;
        END IF;

        lv_counter         := 0;
        lv_item_cost       := 0;
        lv_pk_item_cost    := 0;
        lv_noof_items      := 0;
        lv_pack_item       := NULL;
        lv_status          := NULL;

        IF NVL (pv_region, 'UK') = 'UK'
        THEN
            FOR rec_itemcost_uk IN c_itemcost_uk
            LOOP
                --Added by Reddeiah Cost change for POP Items -ENHC0012047
                lv_status    :=
                    check_pop_item_f (rec_itemcost_uk.inventory_item_id);

                IF lv_status = 'Y'
                THEN
                    lv_cmp_item_id   :=
                        get_pack_item_f (rec_itemcost_uk.inventory_item_id);
                    lv_cmp_item_cost   :=
                        hsoe.get_price_list_value (
                            rec_itemcost_uk.list_header_id,
                            lv_cmp_item_id);
                    lv_noof_items   :=
                        get_no_of_pop_items_f (
                            rec_itemcost_uk.inventory_item_id);

                    IF lv_cmp_item_cost <> 0
                    THEN
                        lv_item_cost   := lv_cmp_item_cost;
                    ELSIF lv_noof_items <> 0
                    THEN
                        IF    rec_itemcost_uk.uk_region_cost = 0
                           OR rec_itemcost_uk.uk_region_cost = 0.01
                        THEN
                            lv_item_cost   := 0.01;
                        ELSE
                            lv_item_cost   :=
                                ROUND (
                                      rec_itemcost_uk.uk_region_cost
                                    / lv_noof_items,
                                    2);
                        END IF;
                    END IF;

                    BEGIN
                        --  SELECT segment1, segment2, segment3                                             --commented by BT Team on 10/12/2014
                        SELECT style_number, color_code, item_size --Added by BT Team on 10/12/2014
                          INTO lv_style, lv_color, lv_sze
                          --FROM apps.mtl_system_items_b                                           --commented by BT team on 10/12/2014
                          FROM xxd_common_items_v --added by BT Team on 10/12/2014
                         WHERE     inventory_item_id = lv_cmp_item_id
                               --AND organization_id = 7; -- Removed by sreenath for BT
                               -- Added by Sreenath for BT - Begin
                               /*  AND organization_id =                                                    --commented by BT Team on 10/12/2014-START
                                      (SELECT organization_id
                                         FROM org_organization_definitions
                                        WHERE organization_name =
                                                               'MST_Deckers_Item_Master');*/
                               --commented by BT Team on 10/12/2014-END
                               AND organization_id IN
                                       ( --Added by BT Technology team on 10/12/2014-START
                                        SELECT ood.organization_id
                                          FROM fnd_lookup_values flv, org_organization_definitions ood
                                         WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                               AND lookup_code = 7
                                               AND flv.attribute1 =
                                                   ood.organization_code
                                               AND LANGUAGE =
                                                   USERENV ('LANG'));
                    --Added by BT Technology team on 10/12/2014-END/12/2014
                    -- Added by Sreenath for BT - End
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured');
                    END;

                    FOR uk_cur
                        IN c_itemcostchange_uk (
                               lv_cmp_item_id,
                               rec_itemcost_uk.organization_id,
                               lv_item_cost) --Added uk region cost parameter by Naga
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        region_cost,
                                                        xdata,
                                                        store_warehouse,
                                                        parent_request_id)
                                     VALUES (
                                                xxdoinv010_int_s.NEXTVAL,
                                                lv_cmp_item_id,
                                                rec_itemcost_uk.organization_id,
                                                lv_style,
                                                lv_color,
                                                lv_sze,
                                                'UK',
                                                'N',
                                                lv_item_cost,
                                                XMLTYPE.getclobval (
                                                    uk_cur.itemcost),
                                                'WH',
                                                lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 3:  Exception occured and verify the table data with error ');
                        END;
                    --END;
                    END LOOP;                             /* For  Uk CURSOR */

                    FOR store_cur IN c_itemcost_s_uk (lv_cmp_item_id, rec_itemcost_uk.organization_id, 'UK'
                                                      , lv_item_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT) --Added by Naga
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        xdata,
                                                        store_warehouse,
                                                        region_cost,
                                                        parent_request_id)
                                 VALUES (xxdoinv010_int_s.NEXTVAL, lv_cmp_item_id, rec_itemcost_uk.organization_id, lv_style, lv_color, lv_sze, 'UK', 'N', XMLTYPE.getclobval (store_cur.itemcost)
                                         , 'S', lv_item_cost, lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                -- COMMIT;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 4:  Exception occured and verify the table data with error ');
                        END;
                    --  END;
                    END LOOP;                               /* For  STORE UK*/
                END IF;

                FOR uk_cur
                    IN c_itemcostchange_uk (
                           rec_itemcost_uk.inventory_item_id,
                           rec_itemcost_uk.organization_id,
                           rec_itemcost_uk.uk_region_cost) --Added uk region cost parameter by Naga
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    region_cost,
                                                    xdata,
                                                    store_warehouse,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_uk.inventory_item_id,
                                            rec_itemcost_uk.organization_id,
                                            rec_itemcost_uk.style,
                                            rec_itemcost_uk.color,
                                            rec_itemcost_uk.sze,
                                            'UK',
                                            'N',
                                            rec_itemcost_uk.uk_region_cost,
                                            XMLTYPE.getclobval (
                                                uk_cur.itemcost),
                                            'WH',
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 3:  Exception occured and verify the table data with error ');
                    END;

                    --END;
                    COMMIT;
                END LOOP;                                 /* For  Uk CURSOR */

                FOR store_cur
                    IN c_itemcost_s_uk (rec_itemcost_uk.inventory_item_id, rec_itemcost_uk.organization_id, 'UK'
                                        , rec_itemcost_uk.uk_region_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT) --Added by Naga
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    xdata,
                                                    store_warehouse,
                                                    region_cost,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_uk.inventory_item_id,
                                            rec_itemcost_uk.organization_id,
                                            rec_itemcost_uk.style,
                                            rec_itemcost_uk.color,
                                            rec_itemcost_uk.sze,
                                            'UK',
                                            'N',
                                            XMLTYPE.getclobval (
                                                store_cur.itemcost),
                                            'S',
                                            rec_itemcost_uk.uk_region_cost,
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            -- COMMIT;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 4:  Exception occured and verify the table data with error ');
                    END;
                --  END;
                END LOOP;                                   /* For  STORE UK*/

                lv_counter   := lv_counter + 1;

                --fnd_file.put_line(fnd_file.log,'HALF');

                /* CURSOR TO INSERT DATA FOR US  */
                IF (lv_counter = 500)
                THEN
                    COMMIT;
                    lv_counter   := 0;
                END IF;
            END LOOP;                           -- FOR  REC_ITEMCOST_UK CURSOR
        END IF;

        lv_counter         := 0;
        lv_item_cost       := 0;
        lv_pk_item_cost    := 0;
        lv_noof_items      := 0;
        lv_pack_item       := NULL;
        lv_status          := NULL;

        IF NVL (pv_region, 'HK') = 'HK'
        THEN
            FOR rec_itemcost_hk IN c_itemcost_hk
            LOOP
                --Added by Reddeiah Cost change for POP Items -ENHC0012047
                lv_status    :=
                    check_pop_item_f (rec_itemcost_hk.inventory_item_id);

                IF lv_status = 'Y'
                THEN
                    lv_cmp_item_id   :=
                        get_pack_item_f (rec_itemcost_hk.inventory_item_id);
                    lv_cmp_item_cost   :=
                        hsoe.get_price_list_value (
                            rec_itemcost_hk.list_header_id,
                            lv_cmp_item_id);
                    /*get_pack_item_cost_f (lv_cmp_item_id, 'HK');*/
                    lv_noof_items   :=
                        get_no_of_pop_items_f (
                            rec_itemcost_hk.inventory_item_id);

                    IF lv_cmp_item_cost <> 0
                    THEN
                        lv_item_cost   := lv_cmp_item_cost;
                    ELSIF lv_noof_items <> 0
                    THEN
                        IF    rec_itemcost_hk.hk_region_cost = 0
                           OR rec_itemcost_hk.hk_region_cost = 0.01
                        THEN
                            lv_item_cost   := 0.01;
                        ELSE
                            lv_item_cost   :=
                                ROUND (
                                      rec_itemcost_hk.hk_region_cost
                                    / lv_noof_items,
                                    2);
                        END IF;
                    END IF;

                    BEGIN
                        -- SELECT segment1, segment2, segment3                                 --commented by BT Team on 10/12/2014
                        SELECT style_number, color_code, item_size --Added by BT Team on 10/12/2014
                          INTO lv_style, lv_color, lv_sze
                          --FROM apps.mtl_system_items_b                                            --commented by BT Team on 10/12/2014
                          FROM xxd_common_items_v --Added by BT Team on 10/12/2014
                         WHERE     inventory_item_id = lv_cmp_item_id
                               -- AND organization_id = 7; -- Removed by Sreenath for BT
                               -- Added by Sreenath for BT - Begin
                               /*  AND organization_id =                                                    --commented by BT Team on 10/12/2014-START
                                     (SELECT organization_id
                                        FROM org_organization_definitions
                                       WHERE organization_name =
                                                              'MST_Deckers_Item_Master');*/
                               --commented by BT Team on 10/12/2014-END
                               AND organization_id IN
                                       ( --Added by BT Technology team on 10/12/2014-START
                                        SELECT ood.organization_id
                                          FROM fnd_lookup_values flv, org_organization_definitions ood
                                         WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                               AND lookup_code = 7
                                               AND flv.attribute1 =
                                                   ood.organization_code
                                               AND LANGUAGE =
                                                   USERENV ('LANG'));
                    --Added by BT Technology team on 10/12/2014-END/12/2014
                    -- Added by Sreenath for BT - End
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured');
                    END;

                    FOR hk_cur
                        IN c_itemcostchange_hk (
                               lv_cmp_item_id,
                               rec_itemcost_hk.organization_id,
                               lv_item_cost)                   --Added by Naga
                    LOOP
                        /* CURSOR TO INSERT DATA FOR HK */
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        region_cost,
                                                        xdata,
                                                        store_warehouse,
                                                        parent_request_id)
                                     VALUES (
                                                xxdoinv010_int_s.NEXTVAL,
                                                lv_cmp_item_id,
                                                rec_itemcost_hk.organization_id,
                                                lv_style,
                                                lv_color,
                                                lv_sze,
                                                'HK',
                                                'N',
                                                lv_item_cost,
                                                XMLTYPE.getclobval (
                                                    hk_cur.itemcost),
                                                'WH',
                                                lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 5:  Exception occured and verify the table data with error ');
                        END;
                    -- END;
                    END LOOP;                             /* For  Hk CURSOR */

                    FOR store_cur IN c_itemcost_s_hk (lv_cmp_item_id, rec_itemcost_hk.organization_id, 'HK'
                                                      , lv_item_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT) -- Added by Naga
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        xdata,
                                                        store_warehouse,
                                                        region_cost,
                                                        parent_request_id)
                                 VALUES (xxdoinv010_int_s.NEXTVAL, lv_cmp_item_id, rec_itemcost_hk.organization_id, lv_style, lv_color, lv_sze, 'HK', 'N', XMLTYPE.getclobval (store_cur.itemcost)
                                         , 'S', lv_item_cost, lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 6:  Exception occured and verify the table data with error ');
                        END;
                    --  END;
                    END LOOP;                               /* For  STORE HK*/
                END IF;

                FOR hk_cur
                    IN c_itemcostchange_hk (
                           rec_itemcost_hk.inventory_item_id,
                           rec_itemcost_hk.organization_id,
                           rec_itemcost_hk.hk_region_cost)     --Added by Naga
                LOOP
                    /* CURSOR TO INSERT DATA FOR HK */
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    region_cost,
                                                    xdata,
                                                    store_warehouse,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_hk.inventory_item_id,
                                            rec_itemcost_hk.organization_id,
                                            rec_itemcost_hk.style,
                                            rec_itemcost_hk.color,
                                            rec_itemcost_hk.sze,
                                            'HK',
                                            'N',
                                            rec_itemcost_hk.hk_region_cost,
                                            XMLTYPE.getclobval (
                                                hk_cur.itemcost),
                                            'WH',
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 5:  Exception occured and verify the table data with error ');
                    END;
                -- END;
                END LOOP;                                 /* For  Hk CURSOR */

                FOR store_cur
                    IN c_itemcost_s_hk (rec_itemcost_hk.inventory_item_id, rec_itemcost_hk.organization_id, 'HK'
                                        , rec_itemcost_hk.hk_region_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT) -- Added by Naga
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    xdata,
                                                    store_warehouse,
                                                    region_cost,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_hk.inventory_item_id,
                                            rec_itemcost_hk.organization_id,
                                            rec_itemcost_hk.style,
                                            rec_itemcost_hk.color,
                                            rec_itemcost_hk.sze,
                                            'HK',
                                            'N',
                                            XMLTYPE.getclobval (
                                                store_cur.itemcost),
                                            'S',
                                            rec_itemcost_hk.hk_region_cost,
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 6:  Exception occured and verify the table data with error ');
                    END;
                --  END;
                END LOOP;                                   /* For  STORE HK*/

                lv_counter   := lv_counter + 1;

                --fnd_file.put_line(fnd_file.log,'HALF');

                /* CURSOR TO INSERT DATA FOR HK */
                IF (lv_counter = 500)
                THEN
                    COMMIT;
                    lv_counter   := 0;
                END IF;
            END LOOP;                           -- FOR  REC_ITEMCOST_HK CURSOR

            COMMIT;
        END IF;

        lv_counter         := 0;
        lv_item_cost       := 0;
        lv_pk_item_cost    := 0;
        lv_noof_items      := 0;
        lv_pack_item       := NULL;
        lv_status          := NULL;

        IF NVL (pv_region, 'CN') = 'CN'
        THEN
            FOR rec_itemcost_cn IN c_itemcost_cn
            LOOP
                --Added by Reddeiah Cost change for POP Items -ENHC0012047
                lv_status    :=
                    check_pop_item_f (rec_itemcost_cn.inventory_item_id);

                IF lv_status = 'Y'
                THEN
                    lv_cmp_item_id   :=
                        get_pack_item_f (rec_itemcost_cn.inventory_item_id);
                    lv_cmp_item_cost   :=
                        hsoe.get_price_list_value (
                            rec_itemcost_cn.list_header_id,
                            lv_cmp_item_id);
                    /* get_pack_item_cost_f (lv_cmp_item_id, 'CN');*/
                    lv_noof_items   :=
                        get_no_of_pop_items_f (
                            rec_itemcost_cn.inventory_item_id);

                    IF lv_cmp_item_cost <> 0
                    THEN
                        lv_item_cost   := lv_cmp_item_cost;
                    ELSIF lv_noof_items <> 0
                    THEN
                        IF    rec_itemcost_cn.cn_region_cost = 0
                           OR rec_itemcost_cn.cn_region_cost = 0.01
                        THEN
                            lv_item_cost   := 0.01;
                        ELSE
                            lv_item_cost   :=
                                ROUND (
                                      rec_itemcost_cn.cn_region_cost
                                    / lv_noof_items,
                                    2);
                        END IF;
                    END IF;

                    BEGIN
                        --  SELECT segment1, segment2, segment3                                   --commented by BT Team on 10/12/2014
                        SELECT style_number, color_code, item_size --added by BT Team on 10/12/2014
                          INTO lv_style, lv_color, lv_sze
                          --FROM apps.mtl_system_items_b                                               --commented by BT TEam on 10/12/2014
                          FROM xxd_common_items_v --Added by  BT Team on 10/12/2014
                         WHERE     inventory_item_id = lv_cmp_item_id
                               --AND organization_id = 7; -- Removed by Sreenath for BT
                               -- Added by Sreenath for BT - Begin
                               /*  AND organization_id =                                                    --commented by BT Team on 10/12/2014-START
                                       (SELECT organization_id
                                          FROM org_organization_definitions
                                         WHERE organization_name =
                                                                'MST_Deckers_Item_Master');*/
                               --commented by BT Team on 10/12/2014-END
                               AND organization_id IN
                                       ( --Added by BT Technology team on 10/12/2014-START
                                        SELECT ood.organization_id
                                          FROM fnd_lookup_values flv, org_organization_definitions ood
                                         WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                               AND lookup_code = 7
                                               AND flv.attribute1 =
                                                   ood.organization_code
                                               AND LANGUAGE =
                                                   USERENV ('LANG'));
                    --Added by BT Technology team on 10/12/2014-END/12/2014
                    -- Added by Sreenath for BT - End
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured');
                    END;

                    FOR cn_cur
                        IN c_itemcostchange_cn (
                               lv_cmp_item_id,
                               rec_itemcost_cn.organization_id,
                               lv_item_cost)                   --Added by Naga
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        region_cost,
                                                        xdata,
                                                        store_warehouse,
                                                        parent_request_id)
                                     VALUES (
                                                xxdoinv010_int_s.NEXTVAL,
                                                lv_cmp_item_id,
                                                rec_itemcost_cn.organization_id,
                                                lv_style,
                                                lv_color,
                                                lv_sze,
                                                'CN',
                                                'N',
                                                lv_item_cost,
                                                XMLTYPE.getclobval (
                                                    cn_cur.itemcost),
                                                'WH',
                                                lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 7:  Exception occured and verify the table data with error ');
                        END;
                    --  END;
                    END LOOP;                             /* For  CN CURSOR */

                    FOR store_cur IN c_itemcost_s_cn (lv_cmp_item_id, rec_itemcost_cn.organization_id, 'CN'
                                                      , lv_item_cost) --'OUTLET',LV_SHOKA,LV_CONCEPT) --Added by Naga
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        xdata,
                                                        store_warehouse,
                                                        region_cost,
                                                        parent_request_id)
                                 VALUES (xxdoinv010_int_s.NEXTVAL, lv_cmp_item_id, rec_itemcost_cn.organization_id, lv_style, lv_color, lv_sze, 'CN', 'N', XMLTYPE.getclobval (store_cur.itemcost)
                                         , 'S', lv_item_cost, lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 8:  Exception occured and verify the table data with error ');
                        END;
                    --  END;
                    END LOOP;
                END IF;                                     /* For  STORE CN*/

                FOR cn_cur
                    IN c_itemcostchange_cn (
                           rec_itemcost_cn.inventory_item_id,
                           rec_itemcost_cn.organization_id,
                           rec_itemcost_cn.cn_region_cost)     --Added by Naga
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    region_cost,
                                                    xdata,
                                                    store_warehouse,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_cn.inventory_item_id,
                                            rec_itemcost_cn.organization_id,
                                            rec_itemcost_cn.style,
                                            rec_itemcost_cn.color,
                                            rec_itemcost_cn.sze,
                                            'CN',
                                            'N',
                                            rec_itemcost_cn.cn_region_cost,
                                            XMLTYPE.getclobval (
                                                cn_cur.itemcost),
                                            'WH',
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 7:  Exception occured and verify the table data with error ');
                    END;
                --  END;
                END LOOP;                                 /* For  CN CURSOR */

                FOR store_cur
                    IN c_itemcost_s_cn (rec_itemcost_cn.inventory_item_id, rec_itemcost_cn.organization_id, 'CN'
                                        , rec_itemcost_cn.cn_region_cost) --'OUTLET',LV_SHOKA,LV_CONCEPT) --Added by Naga
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    xdata,
                                                    store_warehouse,
                                                    region_cost,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_cn.inventory_item_id,
                                            rec_itemcost_cn.organization_id,
                                            rec_itemcost_cn.style,
                                            rec_itemcost_cn.color,
                                            rec_itemcost_cn.sze,
                                            'CN',
                                            'N',
                                            XMLTYPE.getclobval (
                                                store_cur.itemcost),
                                            'S',
                                            rec_itemcost_cn.cn_region_cost,
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 8:  Exception occured and verify the table data with error ');
                    END;
                --  END;
                END LOOP;                                   /* For  STORE CN*/

                lv_counter   := lv_counter + 1;

                /* CURSOR TO INSERT DATA FOR CN */
                IF (lv_counter = 500)
                THEN
                    COMMIT;
                    lv_counter   := 0;
                END IF;
            END LOOP;                           -- FOR  REC_ITEMCOST_CN CURSOR

            COMMIT;
        END IF;

        lv_counter         := 0;
        lv_item_cost       := 0;
        lv_pk_item_cost    := 0;
        lv_noof_items      := 0;
        lv_pack_item       := NULL;
        lv_status          := NULL;

        IF NVL (pv_region, 'JP') = 'JP'
        THEN
            FOR rec_itemcost_jp IN c_itemcost_jp
            LOOP
                --Added by Reddeiah Cost change for POP Items -ENHC0012047
                lv_status    :=
                    check_pop_item_f (rec_itemcost_jp.inventory_item_id);

                IF lv_status = 'Y'
                THEN
                    lv_cmp_item_id   :=
                        get_pack_item_f (rec_itemcost_jp.inventory_item_id);
                    lv_cmp_item_cost   :=
                        hsoe.get_price_list_value (
                            rec_itemcost_jp.list_header_id,
                            lv_cmp_item_id);
                    /* get_pack_item_cost_f (lv_cmp_item_id, 'JP');*/
                    lv_noof_items   :=
                        get_no_of_pop_items_f (
                            rec_itemcost_jp.inventory_item_id);

                    IF lv_cmp_item_cost <> 0
                    THEN
                        lv_item_cost   := lv_cmp_item_cost;
                    ELSIF lv_noof_items <> 0
                    THEN
                        IF    rec_itemcost_jp.ebs_unit_cost = 0
                           OR rec_itemcost_jp.ebs_unit_cost = 0.01
                        THEN
                            lv_item_cost   := 0.01;
                        ELSE
                            lv_item_cost   :=
                                ROUND (
                                      rec_itemcost_jp.ebs_unit_cost
                                    / lv_noof_items,
                                    2);
                        END IF;
                    END IF;

                    BEGIN
                        SELECT segment1, segment2, segment3
                          INTO lv_style, lv_color, lv_sze
                          FROM apps.mtl_system_items_b
                         WHERE     inventory_item_id = lv_cmp_item_id
                               --AND organization_id = 7; -- Removed by Sreenath for BT
                               -- Added by Sreenath for BT - Begin
                               AND organization_id =
                                   (SELECT organization_id
                                      FROM org_organization_definitions
                                     WHERE organization_name =
                                           'MST_Deckers_Item_Master');
                    -- Added by Sreenath for BT - End
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured');
                    END;

                    FOR jp_cur
                        IN c_itemcostchange_jp (
                               lv_cmp_item_id,
                               rec_itemcost_jp.organization_id,
                               lv_item_cost)                  -- Added by Naga
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        region_cost,
                                                        xdata,
                                                        store_warehouse,
                                                        parent_request_id)
                                     VALUES (
                                                xxdoinv010_int_s.NEXTVAL,
                                                lv_cmp_item_id,
                                                rec_itemcost_jp.organization_id,
                                                lv_style,
                                                lv_color,
                                                lv_sze,
                                                'JP',
                                                'N',
                                                lv_item_cost,
                                                XMLTYPE.getclobval (
                                                    jp_cur.itemcost),
                                                'WH',
                                                lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 9:  Exception occured and verify the table data with error ');
                        END;
                    --             END;
                    END LOOP;                             /* For  jp CURSOR */

                    FOR store_cur IN c_itemcost_s_jp (lv_cmp_item_id, rec_itemcost_jp.organization_id, 'JP'
                                                      , lv_item_cost)
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        xdata,
                                                        store_warehouse,
                                                        region_cost,
                                                        parent_request_id)
                                 VALUES (xxdoinv010_int_s.NEXTVAL, lv_cmp_item_id, rec_itemcost_jp.organization_id, lv_style, lv_color, lv_sze, 'JP', 'N', XMLTYPE.getclobval (store_cur.itemcost)
                                         , 'S', lv_item_cost, lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 10:  Exception occured and verify the table data with error ');
                        END;
                    --             END;
                    END LOOP;
                END IF;                                     /* For  STORE JP*/

                FOR jp_cur
                    IN c_itemcostchange_jp (
                           rec_itemcost_jp.inventory_item_id,
                           rec_itemcost_jp.organization_id,
                           rec_itemcost_jp.ebs_unit_cost)     -- Added by Naga
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    region_cost,
                                                    xdata,
                                                    store_warehouse,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_jp.inventory_item_id,
                                            rec_itemcost_jp.organization_id,
                                            rec_itemcost_jp.style,
                                            rec_itemcost_jp.color,
                                            rec_itemcost_jp.sze,
                                            'JP',
                                            'N',
                                            rec_itemcost_jp.ebs_unit_cost,
                                            XMLTYPE.getclobval (
                                                jp_cur.itemcost),
                                            'WH',
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 9:  Exception occured and verify the table data with error ');
                    END;
                --             END;
                END LOOP;                                 /* For  jp CURSOR */

                FOR store_cur
                    IN c_itemcost_s_jp (rec_itemcost_jp.inventory_item_id, rec_itemcost_jp.organization_id, 'JP'
                                        , rec_itemcost_jp.ebs_unit_cost)
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    xdata,
                                                    store_warehouse,
                                                    region_cost,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_jp.inventory_item_id,
                                            rec_itemcost_jp.organization_id,
                                            rec_itemcost_jp.style,
                                            rec_itemcost_jp.color,
                                            rec_itemcost_jp.sze,
                                            'JP',
                                            'N',
                                            XMLTYPE.getclobval (
                                                store_cur.itemcost),
                                            'S',
                                            rec_itemcost_jp.ebs_unit_cost,
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 10:  Exception occured and verify the table data with error ');
                    END;
                --             END;
                END LOOP;                                   /* For  STORE JP*/

                lv_counter   := lv_counter + 1;

                --fnd_file.put_line(fnd_file.log,'HALF');

                /* CURSOR TO INSERT DATA FOR US  */
                IF (lv_counter = 500)
                THEN
                    COMMIT;
                    lv_counter   := 0;
                END IF;
            END LOOP;                            -- FOR REC_ITEMCOST_JP CURSOR

            COMMIT;
        END IF;

        lv_counter         := 0;
        lv_item_cost       := 0;
        lv_pk_item_cost    := 0;
        lv_noof_items      := 0;
        lv_pack_item       := NULL;
        lv_status          := NULL;

        IF NVL (pv_region, 'CA') = 'CA'
        THEN
            FOR rec_itemcost_ca IN c_itemcost_ca (ln_cad_exchange)
            LOOP
                --Added by Reddeiah Cost change for POP Items -ENHC0012047
                lv_status    :=
                    check_pop_item_f (rec_itemcost_ca.inventory_item_id);

                IF lv_status = 'Y'
                THEN
                    lv_cmp_item_id   :=
                        get_pack_item_f (rec_itemcost_ca.inventory_item_id);
                    lv_cmp_item_cost   :=
                        hsoe.get_price_list_value (
                            rec_itemcost_ca.list_header_id,
                            lv_cmp_item_id);
                    /*  get_pack_item_cost_f (lv_cmp_item_id, 'CA');*/
                    lv_noof_items   :=
                        get_no_of_pop_items_f (
                            rec_itemcost_ca.inventory_item_id);

                    IF lv_cmp_item_cost <> 0
                    THEN
                        lv_item_cost   :=
                            ROUND (lv_cmp_item_cost * ln_cad_exchange, 2);
                    ELSIF lv_noof_items <> 0
                    THEN
                        IF    rec_itemcost_ca.ca_region_cost = 0
                           OR rec_itemcost_ca.ca_region_cost = 0.01
                        THEN
                            lv_item_cost   := 0.01;
                        ELSE
                            lv_item_cost   :=
                                ROUND (
                                      rec_itemcost_ca.ca_region_cost
                                    / lv_noof_items,
                                    2);
                        END IF;
                    END IF;

                    BEGIN
                        --   SELECT segment1, segment2, segment3                                      --commented by BT Team on 10/12/2014
                        SELECT style_number, color_code, item_size --Added by BT Team  on 10/12/2014
                          INTO lv_style, lv_color, lv_sze
                          --FROM apps.mtl_system_items_b                                                 --commented by BT Team on 10/12/2014
                          FROM xxd_common_items_v --Added by BT Team on 10/12/2014
                         WHERE     inventory_item_id = lv_cmp_item_id
                               --AND organization_id = 7;  -- Removed by Sreenath for BT
                               -- Added by Sreenath for BT - Begin
                               /*  AND organization_id =                                                    --commented by BT Team on 10/12/2014-START
                                        (SELECT organization_id
                                           FROM org_organization_definitions
                                          WHERE organization_name =
                                                                 'MST_Deckers_Item_Master');*/
                               --commented by BT Team on 10/12/2014-END
                               AND organization_id IN
                                       ( --Added by BT Technology team on 10/12/2014-START
                                        SELECT ood.organization_id
                                          FROM fnd_lookup_values flv, org_organization_definitions ood
                                         WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                               AND lookup_code = 7
                                               AND flv.attribute1 =
                                                   ood.organization_code
                                               AND LANGUAGE =
                                                   USERENV ('LANG'));
                    --Added by BT Technology team on 10/12/2014-END/12/2014
                    -- Added by Sreenath for BT - End
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured');
                    END;

                    FOR can_cur
                        IN c_itemcostchange_ca (
                               lv_cmp_item_id,
                               rec_itemcost_ca.organization_id,
                               lv_item_cost)               --,LN_CAD_EXCHANGE)
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        region_cost,
                                                        xdata,
                                                        store_warehouse,
                                                        parent_request_id)
                                     VALUES (
                                                xxdoinv010_int_s.NEXTVAL,
                                                lv_cmp_item_id,
                                                rec_itemcost_ca.organization_id,
                                                lv_style,
                                                lv_color,
                                                lv_sze,
                                                'CA',
                                                'N',
                                                lv_item_cost,
                                                XMLTYPE.getclobval (
                                                    can_cur.itemcost),
                                                'WH',
                                                lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 11:  Exception occured and verify the table data with error ');
                        END;
                    --   END;
                    END LOOP;
                END IF;

                FOR can_cur
                    IN c_itemcostchange_ca (
                           rec_itemcost_ca.inventory_item_id,
                           rec_itemcost_ca.organization_id,
                           rec_itemcost_ca.ca_region_cost) --,LN_CAD_EXCHANGE)
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    region_cost,
                                                    xdata,
                                                    store_warehouse,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_ca.inventory_item_id,
                                            rec_itemcost_ca.organization_id,
                                            rec_itemcost_ca.style,
                                            rec_itemcost_ca.color,
                                            rec_itemcost_ca.sze,
                                            'CA',
                                            'N',
                                            rec_itemcost_ca.ca_region_cost,
                                            XMLTYPE.getclobval (
                                                can_cur.itemcost),
                                            'WH',
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 11:  Exception occured and verify the table data with error ');
                    END;
                --   END;
                END LOOP;

                lv_counter   := lv_counter + 1;

                --fnd_file.put_line(fnd_file.log,'HALF');

                /* CURSOR TO INSERT DATA FOR US  */
                IF (lv_counter = 500)
                THEN
                    COMMIT;
                    lv_counter   := 0;
                END IF;
            /* For  CAN CURSOR */
            END LOOP;

            COMMIT;
            lv_counter        := 0;
            lv_item_cost      := 0;
            lv_pk_item_cost   := 0;
            lv_noof_items     := 0;
            lv_pack_item      := NULL;
            lv_status         := NULL;

            FOR rec_ca IN c_itemcost_ca_s                  --(LN_CAD_EXCHANGE)
            LOOP
                --Added by Reddeiah Cost change for POP Items -ENHC0012047
                lv_status    := check_pop_item_f (rec_ca.inventory_item_id);

                IF lv_status = 'Y'
                THEN
                    lv_cmp_item_id   :=
                        get_pack_item_f (rec_ca.inventory_item_id);
                    lv_cmp_item_cost   :=
                        hsoe.get_price_list_value (rec_ca.list_header_id,
                                                   lv_cmp_item_id);
                    /* get_pack_item_cost_f (lv_cmp_item_id, 'CA');*/
                    lv_noof_items   :=
                        get_no_of_pop_items_f (rec_ca.inventory_item_id);

                    IF lv_cmp_item_cost <> 0
                    THEN
                        lv_item_cost   := lv_cmp_item_cost;
                    ELSIF lv_noof_items <> 0
                    THEN
                        IF    rec_ca.ca_region_cost = 0
                           OR rec_ca.ca_region_cost = 0.01
                        THEN
                            lv_item_cost   := 0.01;
                        ELSE
                            lv_item_cost   :=
                                ROUND (rec_ca.ca_region_cost / lv_noof_items,
                                       2);
                        END IF;
                    END IF;

                    BEGIN
                        -- SELECT segment1, segment2, segment3                                          --commented by BT Team on 10/12/2014
                        SELECT style_number, color_code, item_size
                          INTO lv_style, lv_color, lv_sze
                          --   FROM apps.mtl_system_items_b                                               --commented by BT Team on 10/12/2014
                          FROM xxd_common_items_v --Added by BT Team on 10/12/2014
                         WHERE     inventory_item_id = lv_cmp_item_id
                               --AND organization_id = 7; -- Removed by Sreenath for BT
                               -- Added by Sreenath for BT - Begin
                               /*  AND organization_id =                                                    --commented by BT Team on 10/12/2014-START
                                       (SELECT organization_id
                                          FROM org_organization_definitions
                                         WHERE organization_name =
                                                                'MST_Deckers_Item_Master');*/
                               --commented by BT Team on 10/12/2014-END
                               AND organization_id IN
                                       ( --Added by BT Technology team on 10/12/2014-START
                                        SELECT ood.organization_id
                                          FROM fnd_lookup_values flv, org_organization_definitions ood
                                         WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                               AND lookup_code = 7
                                               AND flv.attribute1 =
                                                   ood.organization_code
                                               AND LANGUAGE =
                                                   USERENV ('LANG'));
                    --Added by BT Technology team on 10/12/2014-END/12/2014
                    -- Added by Sreenath for BT - End
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured');
                    END;

                    FOR store_cur IN c_itemcost_s_ca (lv_cmp_item_id, rec_ca.organization_id, 'CA'
                                                      , lv_item_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT)
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        xdata,
                                                        store_warehouse,
                                                        region_cost,
                                                        parent_request_id)
                                 VALUES (xxdoinv010_int_s.NEXTVAL, lv_cmp_item_id, rec_ca.organization_id, lv_style, lv_color, lv_sze, 'CA', 'N', XMLTYPE.getclobval (store_cur.itemcost)
                                         , 'S', lv_item_cost, lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                -- COMMIT;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 12:  Exception occured and verify the table data with error ');
                        END;
                    --            END;
                    END LOOP;
                END IF;

                FOR store_cur IN c_itemcost_s_ca (rec_ca.inventory_item_id, rec_ca.organization_id, 'CA'
                                                  , rec_ca.ca_region_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT)
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    xdata,
                                                    store_warehouse,
                                                    region_cost,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_ca.inventory_item_id,
                                            rec_ca.organization_id,
                                            rec_ca.style,
                                            rec_ca.color,
                                            rec_ca.sze,
                                            'CA',
                                            'N',
                                            XMLTYPE.getclobval (
                                                store_cur.itemcost),
                                            'S',
                                            rec_ca.ca_region_cost,
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            -- COMMIT;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 12:  Exception occured and verify the table data with error ');
                    END;
                --            END;
                END LOOP;                                   /* For  STORE CA*/

                lv_counter   := lv_counter + 1;

                IF (lv_counter = 500)
                THEN
                    COMMIT;
                    lv_counter   := 0;
                END IF;
            END LOOP;                                   -- FOR STORE CURSOR */

            COMMIT;
        END IF;

        lv_counter         := 0;
        lv_item_cost       := 0;
        lv_pk_item_cost    := 0;
        lv_noof_items      := 0;
        lv_pack_item       := NULL;
        lv_status          := NULL;

        IF NVL (pv_region, 'FR') = 'FR'
        THEN
            /* cursor for France region Stores */
            FOR rec_itemcost_fr IN c_itemcost_fr
            LOOP
                --Added by Reddeiah Cost change for POP Items -ENHC0012047
                lv_status    :=
                    check_pop_item_f (rec_itemcost_fr.inventory_item_id);

                IF lv_status = 'Y'
                THEN
                    lv_cmp_item_id   :=
                        get_pack_item_f (rec_itemcost_fr.inventory_item_id);
                    lv_cmp_item_cost   :=
                        hsoe.get_price_list_value (
                            rec_itemcost_fr.list_header_id,
                            lv_cmp_item_id);
                    /* get_pack_item_cost_f (lv_cmp_item_id, 'FR');*/
                    lv_noof_items   :=
                        get_no_of_pop_items_f (
                            rec_itemcost_fr.inventory_item_id);

                    IF lv_cmp_item_cost <> 0
                    THEN
                        lv_item_cost   := lv_cmp_item_cost;
                    ELSIF lv_noof_items <> 0
                    THEN
                        IF    rec_itemcost_fr.fr_region_cost = 0
                           OR rec_itemcost_fr.fr_region_cost = 0.01
                        THEN
                            lv_item_cost   := 0.01;
                        ELSE
                            lv_item_cost   :=
                                ROUND (
                                      rec_itemcost_fr.fr_region_cost
                                    / lv_noof_items,
                                    2);
                        END IF;
                    END IF;

                    BEGIN
                        --SELECT segment1, segment2, segment3                                         --commented by BT Team on 10/12/2014
                        SELECT style_number, color_code, item_size --Added by BT Team on 10/12/2014
                          INTO lv_style, lv_color, lv_sze
                          --FROM apps.mtl_system_items_b                                                    --commented By BT Team on 10/12/2014
                          FROM xxd_common_items_v --Added by BT Team on 10/12/2014
                         WHERE     inventory_item_id = lv_cmp_item_id
                               --AND organization_id = 7; -- Removed for BT
                               -- Added by Sreenath for BT - Begin
                               /*  AND organization_id =                                                    --commented by BT Team on 10/12/2014-START
                                       (SELECT organization_id
                                          FROM org_organization_definitions
                                         WHERE organization_name =
                                                                'MST_Deckers_Item_Master');*/
                               --commented by BT Team on 10/12/2014-END
                               AND organization_id IN
                                       ( --Added by BT Technology team on 10/12/2014-START
                                        SELECT ood.organization_id
                                          FROM fnd_lookup_values flv, org_organization_definitions ood
                                         WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                               AND lookup_code = 7
                                               AND flv.attribute1 =
                                                   ood.organization_code
                                               AND LANGUAGE =
                                                   USERENV ('LANG'));
                    --Added by BT Technology team on 10/12/2014-END/12/2014
                    -- Added by Sreenath for BT - End
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 1:  Exception occured');
                    END;

                    FOR fr_cur
                        IN c_itemcostchange_fr (
                               lv_cmp_item_id,
                               rec_itemcost_fr.organization_id,
                               lv_item_cost) -- Added by Fr Region cost paramenter in cursor
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        region_cost,
                                                        xdata,
                                                        store_warehouse,
                                                        parent_request_id)
                                     VALUES (
                                                xxdoinv010_int_s.NEXTVAL,
                                                lv_cmp_item_id,
                                                rec_itemcost_fr.organization_id,
                                                lv_style,
                                                lv_color,
                                                lv_sze,
                                                'FR',
                                                'N',
                                                lv_item_cost,
                                                XMLTYPE.getclobval (
                                                    fr_cur.itemcost),
                                                'WH',
                                                lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 13:  Exception occured and verify the table data with error ');
                        END;
                    --   END;
                    END LOOP;                             /* For  FR CURSOR */

                    FOR store_cur IN c_itemcost_s_fr (lv_cmp_item_id, rec_itemcost_fr.organization_id, 'FR'
                                                      , lv_item_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT) --Added by Naga
                    LOOP
                        BEGIN
                            INSERT INTO xxdoinv010_int (slno,
                                                        inventory_item_id,
                                                        organization_id,
                                                        style,
                                                        color,
                                                        sze,
                                                        region_code,
                                                        status_flag,
                                                        xdata,
                                                        store_warehouse,
                                                        region_cost,
                                                        parent_request_id)
                                 VALUES (xxdoinv010_int_s.NEXTVAL, lv_cmp_item_id, rec_itemcost_fr.organization_id, lv_style, lv_color, lv_sze, 'FR', 'N', XMLTYPE.getclobval (store_cur.itemcost)
                                         , 'S', lv_item_cost, lv_request_id);
                        --COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Debug point 14:  Exception occured and verify the table data with error ');
                        END;
                    --             END;
                    END LOOP;                               /* For  STORE FR*/
                END IF;

                FOR fr_cur
                    IN c_itemcostchange_fr (
                           rec_itemcost_fr.inventory_item_id,
                           rec_itemcost_fr.organization_id,
                           rec_itemcost_fr.fr_region_cost) -- Added by Fr Region cost paramenter in cursor
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    region_cost,
                                                    xdata,
                                                    store_warehouse,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_fr.inventory_item_id,
                                            rec_itemcost_fr.organization_id,
                                            rec_itemcost_fr.style,
                                            rec_itemcost_fr.color,
                                            rec_itemcost_fr.sze,
                                            'FR',
                                            'N',
                                            rec_itemcost_fr.fr_region_cost,
                                            XMLTYPE.getclobval (
                                                fr_cur.itemcost),
                                            'WH',
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 13:  Exception occured and verify the table data with error ');
                    END;
                --   END;
                END LOOP;                                 /* For  FR CURSOR */

                FOR store_cur
                    IN c_itemcost_s_fr (rec_itemcost_fr.inventory_item_id, rec_itemcost_fr.organization_id, 'FR'
                                        , rec_itemcost_fr.fr_region_cost) --,'OUTLET',LV_SHOKA,LV_CONCEPT) --Added by Naga
                LOOP
                    BEGIN
                        INSERT INTO xxdoinv010_int (slno,
                                                    inventory_item_id,
                                                    organization_id,
                                                    style,
                                                    color,
                                                    sze,
                                                    region_code,
                                                    status_flag,
                                                    xdata,
                                                    store_warehouse,
                                                    region_cost,
                                                    parent_request_id)
                                 VALUES (
                                            xxdoinv010_int_s.NEXTVAL,
                                            rec_itemcost_fr.inventory_item_id,
                                            rec_itemcost_fr.organization_id,
                                            rec_itemcost_fr.style,
                                            rec_itemcost_fr.color,
                                            rec_itemcost_fr.sze,
                                            'FR',
                                            'N',
                                            XMLTYPE.getclobval (
                                                store_cur.itemcost),
                                            'S',
                                            rec_itemcost_fr.fr_region_cost,
                                            lv_request_id);
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_errmsg   := SUBSTR (SQLERRM, 1, 200);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Debug point 14:  Exception occured and verify the table data with error ');
                    END;
                --             END;
                END LOOP;                                   /* For  STORE FR*/

                lv_counter   := lv_counter + 1;

                --fnd_file.put_line(fnd_file.log,'HALF');
                IF (lv_counter = 500)
                THEN
                    COMMIT;
                    lv_counter   := 0;
                END IF;
            END LOOP;                            -- FOR REC_ITEMCOST_FR CURSOR

            COMMIT;
        END IF;

        -- END INSERT RECORDS INTO STAGING WH AND S INFORMARION IN ONE PLACE

        /***********************************************************************************************************************************/
        BEGIN
            SELECT COUNT (*)
              INTO lv_rec_count
              FROM xxdoinv010_int
             WHERE status_flag = 'N' AND parent_request_id = lv_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_rec_count   := 0;
                fnd_file.put_line (fnd_file.LOG,
                                   'Error while finding the no of records');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        END;

        BEGIN
            SELECT MIN (slno)
              INTO lv_min_slno
              FROM xxdoinv010_int
             WHERE status_flag = 'N' AND parent_request_id = lv_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_rec_count   := 0;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while finding the min no of records');
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'SQL Error Message :' || SQLERRM);
        END;

        lv_batch_count     := CEIL (lv_rec_count / 1000);
        ln_count1          := 0;
        ln_count2          := 0;

        FOR i IN 1 .. lv_batch_count
        LOOP
            ln_count1     := ln_count1 + 1;
            ln_count2     := ln_count1 + 1;
            fnd_file.put_line (fnd_file.LOG,
                               ' no of records' || lv_rec_count);
            fnd_file.put_line (fnd_file.LOG,
                               ' min no of records' || lv_min_slno);
            fnd_file.put_line (fnd_file.LOG,
                               'Batch Count of records' || lv_batch_count);
            ln_request_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXDOINV010A_CALL_WEBSRV',
                    description   =>
                        'Item Retail Integration Call WEB Service - Deckers',
                    start_time    => SYSDATE,
                    sub_request   => NULL,
                    argument1     => lv_min_slno,
                    argument2     => lv_min_slno + 1000,
                    argument3     => lv_request_id);
            fnd_file.put_line (
                fnd_file.LOG,
                'Submitted BATCH ' || i || 'Request id ' || ln_request_id);
            lv_min_slno   := lv_min_slno + 1001;

            IF ln_request_id IS NOT NULL
            THEN
                COMMIT;
            ELSE
                ROLLBACK;
            END IF;

            IF ln_count2 = 5
            THEN
                LOOP
                    lv_req_return_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_request_id,
                            INTERVAL     => 60,
                            max_wait     => NULL,
                            phase        => lv_req_phase,
                            status       => lv_req_status,
                            dev_phase    => lv_req_dev_phase,
                            dev_status   => lv_req_dev_status,
                            MESSAGE      => lv_req_message);
                    EXIT WHEN    UPPER (lv_req_phase) = 'COMPLETED'
                              OR UPPER (lv_req_status) IN
                                     ('CANCELLED', 'ERROR', 'TERMINATED');
                END LOOP;

                ln_count2   := 0;
            END IF;
        END LOOP;

        IF ln_count1 < 5
        THEN
            LOOP
                lv_req_return_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => ln_request_id,
                        INTERVAL     => 60,
                        max_wait     => NULL,
                        phase        => lv_req_phase,
                        status       => lv_req_status,
                        dev_phase    => lv_req_dev_phase,
                        dev_status   => lv_req_dev_status,
                        MESSAGE      => lv_req_message);
                EXIT WHEN    UPPER (lv_req_phase) = 'COMPLETED'
                          OR UPPER (lv_req_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception Occured in Item Cost Procedure and it is    '
                || SQLERRM);
    END;

    ----------------------------------------------------------------------------------------------------------
    PROCEDURE rms_batch_itemcostchange_p (
        errbuf                   OUT VARCHAR2,
        retcode                  OUT VARCHAR2,
        p_slno_from           IN     NUMBER,
        p_slno_to             IN     NUMBER,
        p_parent_request_id   IN     NUMBER)
    IS
        ---------------------------------------------
        -- cursor cur_int_atr_pub is to
        -- retrive the records from the staging table
        -- and then publish it to the 2nd staging tabl
        -- for sending the xml data to RMS
        ---------------------------------------------
        CURSOR c_itemcostpublish IS
            SELECT *
              FROM xxdoinv010_int
             WHERE     status_flag = 'N'
                   AND slno BETWEEN p_slno_from AND p_slno_to;

        CURSOR c_costrepublish (pv_fdate             VARCHAR2,
                                pv_tdate             VARCHAR2,
                                pv_store_warehouse   VARCHAR2)
        IS
            SELECT *
              FROM xxdoinv010_int
             WHERE     status_flag IN ('VE', 'P')
                   AND store_warehouse = pv_store_warehouse
                   AND TRUNC (transmission_date) BETWEEN TRUNC (
                                                             fnd_date.canonical_to_date (
                                                                 pv_fdate))
                                                     AND TRUNC (
                                                             fnd_date.canonical_to_date (
                                                                 pv_tdate));

        ----------------------
        -- Declaring Variables
        ----------------------
        lv_wsdl_ip           VARCHAR2 (25) := NULL;
        lv_wsdl_url          VARCHAR2 (4000) := NULL;
        lv_namespace         VARCHAR2 (4000) := NULL;
        lv_service           VARCHAR2 (4000) := NULL;
        lv_port              VARCHAR2 (4000) := NULL;
        lv_operation         VARCHAR2 (4000) := NULL;
        lv_targetname        VARCHAR2 (4000) := NULL;
        lx_xmltype_in        SYS.XMLTYPE;
        lx_xmltype_out       SYS.XMLTYPE;
        v_xml_data           CLOB;
        lc_return            CLOB;
        lv_errmsg            VARCHAR2 (240) := NULL;
        v_item_id            NUMBER := 0;
        v_user_id            VARCHAR2 (240) := 0;
        v_po_nbr             VARCHAR2 (240) := NULL;
        v_doc_type           VARCHAR2 (240) := NULL;
        v_aux_reason_code    VARCHAR2 (240) := NULL;
        v_weight             NUMBER := 0;
        v_weight_uom         VARCHAR2 (240) := NULL;
        v_unit_cost          NUMBER := 0;
        v_status             VARCHAR2 (240) := NULL;
        v_creation_date      DATE;
        v_created_by         NUMBER := 0;
        v_last_update_date   DATE;
        v_last_update_by     NUMBER := 0;
        --      v_s_no                     number           := 0                       ;
        v_seq_no             NUMBER := 0;
        l_cur_limit          NUMBER := 0;
        l_cnt                NUMBER := 0;
        l_request_id         NUMBER := fnd_global.conc_request_id;
        l_dc_dest_id         NUMBER := 0;
        ln_cad_exchange      NUMBER;
        l_xmldata            SYS.XMLTYPE;
    -- pragma autonomous_transaction;

    ---------------------------------
    -- Beginning of the procedure
    --------------------------------
    BEGIN
        /* Query to fetch the conversion rate for Canada.  */
        ln_cad_exchange   := NULL;

        BEGIN
            SELECT exchange_rate
              INTO ln_cad_exchange
              --FROM rms13prod.currency_rates@rmsprod -- Removed by Sreenath for BT
              FROM rms13prod.currency_rates@xxdo_retail_rms
             -- Added by Sreenath for BT
             WHERE     exchange_type = 'C'
                   AND currency_code = 'CAD'
                   AND effective_date =
                       (SELECT MAX (effective_date)
                          --FROM rms13prod.currency_rates@rmsprod -- Removed by Sreenath for BT
                          FROM rms13prod.currency_rates@xxdo_retail_rms
                         -- Added by Sreenath for BT
                         WHERE exchange_type = 'C' AND currency_code = 'CAD');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error occured while fetching Canada Exchange Rate in Cost Change');
        END;

        /* Setting the Retail PROD/DEV Environment based on Oracle Prod / Dev Instances */
        BEGIN
            SELECT DECODE (applications_system_name, 'PROD', apps.fnd_profile.VALUE ('XXDO: RETAIL PROD'), apps.fnd_profile.VALUE ('XXDO: RETAIL TEST')) file_server_name
              INTO lv_wsdl_ip
              FROM apps.fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Unable to fetch the File server name');
                retcode   := 2;
        END;

        /* Initializing the Item cost web service variables */
        lv_wsdl_url       :=
               'http://'
            || lv_wsdl_ip
            || '/XCostChgPublishingBean/XCostChgPublishingService?WSDL';
        lv_namespace      :=
            'http://www.oracle.com/retail/igs/integration/services/XCostChgPublishingService/v1';
        lv_service        := 'XCostChgPublishingService';
        lv_port           := 'XCostChgPublishingPort';
        lv_operation      := 'publishXCostChgModifyUsingXCostChgDesc';
        lv_targetname     :=
               'http://'
            || lv_wsdl_ip
            || '/XCostChgPublishingBean/XCostChgPublishingService';

        FOR j IN c_itemcostpublish
        LOOP
            --FND_FILE.PUT_LINE(FND_FILE.log,'after opening cursor');
            lx_xmltype_in   :=
                SYS.XMLTYPE (
                       '<publishXCostChgModifyUsingXCostChgDesc xmlns="http://www.oracle.com/retail/igs/integration/services/XCostChgPublishingService/v1"
     xmlns:v1="http://www.oracle.com/retail/integration/base/bo/XCostChgDesc/v1"
     xmlns:v11="http://www.oracle.com/retail/integration/custom/bo/ExtOfXCostChgDesc/v1"
      xmlns:v12="http://www.oracle.com/retail/integration/base/bo/LocOfXCostChgDesc/v1"
      xmlns:v13="http://www.oracle.com/retail/integration/localization/bo/InXCostChgDesc/v1"
       xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/EOfInXCostChgDesc/v1"
        xmlns:v15="http://www.oracle.com/retail/integration/localization/bo/BrXCostChgDesc/v1"
        xmlns:v16="http://www.oracle.com/retail/integration/custom/bo/EOfBrXCostChgDesc/v1">'
                    || j.xdata
                    || '</publishXCostChgModifyUsingXCostChgDesc>');

            BEGIN
                lx_xmltype_out   :=
                    xxdo_invoke_webservice_f (lv_wsdl_url, lv_namespace, lv_targetname, lv_service, lv_port, lv_operation
                                              , lx_xmltype_in);

                IF lx_xmltype_out IS NOT NULL
                THEN
                    --FND_FILE.PUT_LINE(FND_FILE.log,'Response is stored in the staging table  ');
                    lc_return   := XMLTYPE.getclobval (lx_xmltype_out);

                    UPDATE xxdoinv010_int
                       SET retval = lc_return, processed_flag = 'Y', status_flag = 'P',
                           transmission_date = SYSDATE, child_request_id = l_request_id
                     WHERE slno = j.slno;
                ELSE
                    fnd_file.put_line (fnd_file.LOG, 'Response is NULL  ');
                    lc_return   := NULL;

                    UPDATE xxdoinv010_int
                       SET retval = lc_return, status_flag = 'VE', transmission_date = SYSDATE
                     WHERE slno = j.slno;
                END IF;
            --COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_errmsg   := SQLERRM;

                    /* Updating the existing record to validation error and storing the error code */
                    UPDATE xxdoinv010_int
                       SET status_flag = 'VE', errorcode = lv_errmsg
                     WHERE slno = j.slno;

                    -- COMMIT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'PROBLEM IN SENDING THE MESSAGE DETAILS STORED IN THE ERRORCODE OF THE STAGING TABLE   '
                        || SQLERRM);
            END;                            /* End calling the webservice   */
        END LOOP;                                       /* For Publish cost */

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception Occured in Item Cost Procedure and it is    '
                || SQLERRM);
    END rms_batch_itemcostchange_p;
END;
/
