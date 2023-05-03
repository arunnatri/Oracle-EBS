--
-- XXDOINV006_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxdoinv006_pkg
IS
    /*******************************************************************************
    * Program Name : XXDOINV006_PKG
    * Language     : PL/SQL
    *
    * History      :
    *
    * WHO                    WHAT                  Desc                             WHEN
    * -------------- ---------------------------------------------- -------------------------
    * BT Technology Team     Ver1.0                                                  17-JUL-2014
    * BT Technology Team     Ver1.1  Added new Function  get_country_code_f      09-MAR-2015
    * Infosys                Ver1.2      Added the profile for wholesale price list  27-MAR-2015
    *****************************************************************************************/

    -- Start of Changes by BT Technology team #V1.1 09/Mar/2015
    FUNCTION get_country_code_f (pv_region VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_region_code   VARCHAR2 (10) := NULL;
    BEGIN
        SELECT flv.meaning
          INTO lv_region_code
          FROM fnd_lookup_values flv
         WHERE     flv.lookup_type = 'XXD_RMS_COUNTRY_MAPPING'
               AND flv.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (flv.start_date_active,
                                                SYSDATE)
                                       AND NVL (flv.end_date_active, SYSDATE)
               AND LANGUAGE = USERENV ('LANG')
               AND flv.lookup_code = pv_region;

        RETURN lv_region_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_region_code   := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                   'EXCEPTION 0 - Error occure while retreiving Region_ID for the Country Code'
                || pv_region
                || ' , '
                || SQLERRM);

            RETURN lv_region_code;
    END get_country_code_f;

    -- End of Changes by BT Technology team #V1.1 09/Mar/2015

    FUNCTION get_curr_code_f (pv_region VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_curr_code   VARCHAR2 (50);
    BEGIN
        /* Start modification by BT technology team on 12/20
        Commented by BT Technology Team to move it to lookup
                  SELECT DISTINCT currency_code
                         INTO lv_curr_code
                         FROM stores_do_retail_datamart
                        WHERE ((region)) = ((pv_region)) AND ROWNUM = 1;
        */

        SELECT DISTINCT attribute4
          INTO lv_curr_code
          FROM FND_LOOKUP_VALUES flv
         WHERE     flv.lookup_type = 'XXD_RETAIL_STORES'
               AND flv.enabled_flag = 'Y'
               AND TRUNC (NVL (flv.start_date_active, SYSDATE)) >= SYSDATE
               AND TRUNC (NVL (flv.end_date_active, SYSDATE)) <= SYSDATE
               AND ROWNUM = 1;

        RETURN lv_curr_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF pv_region = 'US'
            THEN
                RETURN 'USD';
            ELSIF pv_region = 'UK'
            THEN
                RETURN 'GBP';
            ELSIF pv_region = 'CA'
            THEN
                RETURN 'CAD';
            ELSIF pv_region = 'JP'
            THEN
                RETURN 'JPY';
            ELSIF pv_region = 'CN'
            THEN
                RETURN 'CNY';
            ELSIF pv_region = 'FR'
            THEN
                RETURN 'EUR';
            ELSIF pv_region = 'HK'
            THEN
                RETURN 'HKD';
            ELSE
                RETURN 'USD';
            END IF;
    END;

    FUNCTION get_dept_num_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN NUMBER
    IS
        ln_item_id         NUMBER;
        ln_style_cat_id    NUMBER;
        ln_inv_cat_id      NUMBER;
        lv_gender_cat      VARCHAR2 (200);
        lv_brand           VARCHAR2 (60);
        lv_product_group   VARCHAR2 (30);
        ln_brand_dept_no   NUMBER;
        ln_dept_num        NUMBER;
    BEGIN
        /* Retreiving gender for item provided */
        BEGIN
            /*  SELECT mc.segment3, mc.segment2, mc.segment1                                     --Starting commented by BT Technology team on 1/12/2014
                --    INTO lv_gender_cat, lv_product_group, lv_brand
              INTO   lv_product_group, lv_gender_cat, lv_brand
                FROM mtl_item_categories mic,
                     mtl_categories mc,
                     mtl_category_sets mcs
               WHERE mic.category_set_id = mcs.category_set_id
                 AND mic.category_id = mc.category_id
                 AND mc.structure_id = mcs.structure_id
                 --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                 AND mc.enabled_flag = 'Y'
                 AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                  TRUNC (SYSDATE)
                                                 )
                                         AND NVL (TRUNC (mc.end_date_active),
                                                  TRUNC (SYSDATE)
                                                 )
                 --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                 AND mcs.category_set_name = 'Inventory'

                 AND mic.inventory_item_id = pn_item_id
                 AND mic.organization_id = pn_org_id;*/
            --Ending commented by BT Technology team on 1/12/2014
            SELECT msib.brand, msib.division, msib.department
              --Starting Added by BT Technology team on 1/12/2014
              INTO lv_brand, lv_gender_cat, lv_product_group
              FROM xxd_common_items_v msib
             WHERE     msib.inventory_item_id = pn_item_id
                   AND msib.organization_id = pn_org_id;
        --Ending Added by BT Technology team on 1/12/2014
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_gender_cat   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 1 - error occure while retreiving Category segments '
                    || SQLERRM);
        END;

        /* Retreiving  dept  for given item
                 BEGIN
                     SELECT attribute5
                        INTO ln_dept_num
                     FROM fnd_flex_values
                     WHERE flex_value_set_id = 1003725
                     AND flex_value = ln_gender_cat
                     AND ROWNUM<=1;
                 EXCEPTION
                    WHEN OTHERS   THEN
                            ln_dept_num:=NULL;
                             fnd_file.put_line(fnd_file.log ,'EXCEPTION 1 - error occure while retreiving  attribute5' || SQLERRM);
                 END; */

        /* Retrieving the Brand dept no from the Lookup type XXDOINV_BRANDDEPT */
        BEGIN
            SELECT lookup_code
              INTO ln_brand_dept_no
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDOINV_DEPT'
                   AND (((meaning)) = lv_brand || ' ' || lv_gender_cat || ' ' || lv_product_group OR ((description)) = lv_brand || ' ' || lv_gender_cat || ' ' || lv_product_group)
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_brand_dept_no   := NULL;
        END;

        RETURN ln_brand_dept_no;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 1 - ' || SQLERRM);
            ln_dept_num   := NULL;
            RETURN ln_brand_dept_no;
    END;

    /*********************************************************************************/
    FUNCTION get_class_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN NUMBER
    IS
        ln_item_id        NUMBER;
        ln_style_cat_id   NUMBER;
        ln_inv_cat_id     NUMBER;
        lv_subgrp_cat     VARCHAR2 (200);
        ln_class          NUMBER;
    BEGIN
        /* Retreiving category id for inventory_category_set for  given item*/
        BEGIN
            lv_subgrp_cat   := NULL;

            /* SELECT mc.segment4                                                     --Starting commented by BT Technology team on 1/12/2014
               INTO lv_subgrp_cat
               FROM mtl_item_categories mic,
                    mtl_categories mc,
                    mtl_category_sets mcs
              WHERE mic.category_set_id = mcs.category_set_id
                AND mic.category_id = mc.category_id
                AND mc.structure_id = mcs.structure_id
                AND mcs.category_set_name =
                       'Inventory'
                     --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                AND mc.enabled_flag = 'Y'
                AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                 TRUNC (SYSDATE)
                                                )
                                        AND NVL (TRUNC (mc.end_date_active),
                                                 TRUNC (SYSDATE)
                                                )
                --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                AND mic.inventory_item_id = pn_item_id
                AND mic.organization_id = pn_org_id;*/
            --Ending commented by BT Technology team on 1/12/2014
            SELECT msib.master_class
              --Starting Added by BT Technology team on 1/12/2014
              INTO lv_subgrp_cat
              FROM xxd_common_items_v msib
             WHERE     msib.inventory_item_id = pn_item_id
                   AND msib.organization_id = pn_org_id;
        --Ending Added by BT Technology team on 1/12/2014
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_subgrp_cat   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 2 - error occure while retreiving Subgroup value '
                    || SQLERRM);
        END;

        /* Retreiving  class for given item*/
        BEGIN
            ln_class   := NULL;

            SELECT attribute5
              INTO ln_class
              FROM fnd_flex_values
             WHERE --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                 --flex_value_set_id = 1003730
                       enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date_active),
                                                    TRUNC (SYSDATE))
                   AND flex_value_set_id =
                       (SELECT flex_value_set_id
                          FROM fnd_flex_value_sets
                         WHERE flex_value_set_name = 'DO_CLASS_CAT')
                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND UPPER (flex_value) = UPPER (lv_subgrp_cat)
                   AND ROWNUM <= 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_class   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 2 - error occure while retreiving  attribute5'
                    || SQLERRM);
        END;

        RETURN ln_class;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_class   := NULL;
            fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 2 - ' || SQLERRM);
            RETURN ln_class;
    END;

    /*********************************************************************************/
    FUNCTION get_sub_class_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN NUMBER
    IS
        ln_item_id         NUMBER;
        ln_style_cat_id    NUMBER;
        ln_inv_cat_id      NUMBER;
        lv_subgrp_cat      VARCHAR2 (200);
        -- Start modification by BT Technology Team on 01/07/15
        lc_sub_class       VARCHAR2 (200);
        lc_sub_class_val   VARCHAR2 (200);
    -- End modification by BT Technology Team on 01/07/15

    BEGIN
        /* Retreiving category id for inventory_category_set for  given item*/

        fnd_file.put_line (fnd_file.LOG,
                           'Temp msg1: ' || pn_item_id || '-' || pn_org_id);

        BEGIN
            lc_sub_class   := NULL;

            SELECT msib.sub_class
              --Starting Added by BT Technology team on 1/12/2014
              INTO lc_sub_class
              FROM xxd_common_items_v msib
             WHERE     msib.inventory_item_id = pn_item_id
                   AND msib.organization_id = pn_org_id;
        --Ending Added by BT Technology team on 1/12/2014
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_sub_class   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 2 - error occure while retreiving sub class value '
                    || SQLERRM);
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'Temp msg2: lc_sub_class ' || lc_sub_class);

        /* Retreiving  class for given item*/
        BEGIN
            SELECT attribute5
              INTO lc_sub_class_val
              FROM fnd_flex_values
             WHERE --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                 --flex_value_set_id = 1003730
                       enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date_active),
                                                    TRUNC (SYSDATE))
                   AND flex_value_set_id =
                       (SELECT flex_value_set_id
                          FROM fnd_flex_value_sets
                         WHERE flex_value_set_name = 'DO_SUBCLASS_CAT')
                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND UPPER (flex_value) = UPPER (lc_sub_class)
                   AND ROWNUM <= 1;

            fnd_file.put_line (
                fnd_file.LOG,
                'Temp msg3: lc_sub_class_val ' || lc_sub_class_val);
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_sub_class_val   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 2 - error occure while retreiving  attribute5'
                    || SQLERRM);
        END;

        RETURN lc_sub_class_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            lc_sub_class_val   := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                   'EXCEPTION 2 - Sub class could not be derived for inventory_item_id - '
                || ln_item_id
                || ' - '
                || SQLERRM);
            RETURN lc_sub_class_val;
    END;

    /***************************************************************************************************/
    FUNCTION get_vendor_id_f (pv_region VARCHAR2)
        RETURN NUMBER
    IS
        lv_vendor   VARCHAR2 (30);
    BEGIN
        /*   SELECT nvl(attribute29,'US')
           INTO
           lv_country
           FROM mtl_system_items
           WHERE inventory_item_id=pn_itemid
           AND organization_id=pn_orgid;

           EXCEPTION
           WHEN OTHERS THEN
           lv_country:='US';
           END; */
        BEGIN
            SELECT tag
              INTO lv_vendor
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDOINV_REGIONVENDOR'
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND ((meaning)) = ((pv_region));

            RETURN 9 || LPAD (lv_vendor, 9, 0);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_vendor   := '1991';
                RETURN 9 || LPAD (lv_vendor, 9, 0);
        END;
    END;

    /***************************************************************************************************/
    FUNCTION get_round_case_pct_f (pv_style VARCHAR2)
        RETURN NUMBER
    IS
        ln_case_pct   NUMBER (10, 2);
    BEGIN
        BEGIN
            SELECT TO_NUMBER (attribute42)
              INTO ln_case_pct
              FROM fnd_flex_values
             WHERE --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                 --flex_value_set_id = 1003729
                       flex_value_set_id =
                       (SELECT flex_value_set_id
                          FROM fnd_flex_value_sets
                         WHERE flex_value_set_name = 'DO_STYLES_CAT')
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date_active),
                                                    TRUNC (SYSDATE))
                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND flex_value = pv_style
                   AND ROWNUM <= 1;

            RETURN (ln_case_pct);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN NULL;
            WHEN OTHERS
            THEN
                RETURN ('Error');
        END;
    END;

    /**************************************************************************************************************/
    FUNCTION get_color_flex_value_f (pn_itemid NUMBER, pn_orgid NUMBER)
        RETURN NUMBER
    IS
        ln_flex_value_id   NUMBER (10, 2);
    BEGIN
        BEGIN
            SELECT --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   -- flex_value_id
                   -- Start modification by BT Team on 27-May-15
                   --          attribute5
                   NVL (attribute5, flex_value_id)
              -- Start modification by BT Team on 27-May-15
              --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
              INTO ln_flex_value_id
              FROM fnd_flex_values
             WHERE --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                 --flex_value_set_id = 1003724
                       flex_value_set_id =
                       (SELECT flex_value_set_id
                          FROM fnd_flex_value_sets
                         WHERE flex_value_set_name = 'DO_COLOR_CODE')
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date_active),
                                                    TRUNC (SYSDATE))
                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND flex_value = --start changes by BT tech Team on 09/12/2014
                                                           -- (SELECT segment2
                                                   --  FROM mtl_system_items_b
                        (SELECT color_code
                           FROM xxd_common_items_v
                          --End changes by BT Tech Team on 09/12/2014
                          WHERE inventory_item_id = pn_itemid --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
 /*  AND enabled_flag = 'Y'
   AND TRUNC (SYSDATE)
          BETWEEN NVL (TRUNC (start_date_active),
                       TRUNC (SYSDATE)
                      )
              AND NVL (TRUNC (end_date_active),
                       TRUNC (SYSDATE)
                      )*/
                                          --commented by BT Team on 09/12/2014
                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                 AND organization_id = pn_orgid);

            RETURN (ln_flex_value_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN NULL;
            WHEN OTHERS
            THEN
                RETURN ('Error');
        END;
    END;

    /***************************************************************************/
    FUNCTION get_sup_country_f (pv_region VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_country   VARCHAR2 (10);
        lv_vendor    VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT tag
              INTO lv_vendor
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDOINV_REGIONVENDOR'
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND ((meaning)) = ((pv_region));
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_vendor   := '1991';
        END;

        BEGIN
            SELECT DISTINCT country
              INTO lv_country
              FROM ap_supplier_sites
             WHERE     vendor_id = lv_vendor
                   AND country IS NOT NULL
                   AND ROWNUM = 1;

            RETURN lv_country;
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN 'US';
        END;
    END;

    FUNCTION get_color_flex_id_f (pv_color VARCHAR2)
        RETURN NUMBER
    IS
        ln_fv_id   NUMBER;
    BEGIN
        -- Start modification by BT Team on 27-May-15
        --      SELECT attribute5 -- flex_value_id Commented by BT Technology Team on 1/23/15
        SELECT NVL (attribute5, flex_value_id)
          -- End modification by BT Team on 27-May-15
          INTO ln_fv_id
          FROM fnd_flex_values
         WHERE     flex_value = pv_color
               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
               --flex_value_set_id = 1003724
               AND flex_value_set_id =
                   (SELECT flex_value_set_id
                      FROM fnd_flex_value_sets
                     WHERE flex_value_set_name = 'DO_COLOR_CODE')
               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND enabled_flag = 'Y';

        RETURN ln_fv_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    /********************************************************************************/
    FUNCTION get_sub_group_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_sub_group    VARCHAR2 (100);
        lv_flex_value   VARCHAR2 (60);
    /* Retreiving gender for item provided */
    BEGIN
        /* BEGIN
            SELECT mc.segment4                                                              --Starting commented by BT Technology team on 1/12/2014
              INTO lv_sub_group
              FROM mtl_item_categories mic,
                   mtl_categories mc,
                   mtl_category_sets mcs
             WHERE mic.category_set_id = mcs.category_set_id
               AND mic.category_id = mc.category_id
               AND mc.structure_id = mcs.structure_id
               AND mcs.category_set_name = 'Inventory'
               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND mc.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                TRUNC (SYSDATE)
                                               )
                                       AND NVL (TRUNC (mc.end_date_active),
                                                TRUNC (SYSDATE)
                                               )
               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND mic.inventory_item_id = pn_item_id
               AND mic.organization_id = pn_org_id;*/
        --Ending commented by BT Technology team on 1/12/2014
        BEGIN
            SELECT msib.master_class
              --Starting Added by BT Technology team on 1/12/2014
              INTO lv_sub_group
              FROM xxd_common_items_v msib
             WHERE     msib.inventory_item_id = pn_item_id
                   AND msib.organization_id = pn_org_id;
        --Ending Added by BT Technology team on 1/12/2014
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_sub_group   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 1 - error occure while retreiving Category Sub Group '
                    || SQLERRM);
        END;

        BEGIN
            SELECT flex_value
              INTO lv_flex_value
              FROM fnd_flex_values
             WHERE     UPPER (flex_value) = UPPER (lv_sub_group)
                   AND --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                 --flex_value_set_id = 1003730
                    flex_value_set_id =
                    (SELECT flex_value_set_id
                       FROM fnd_flex_value_sets
                      --Starting Added by BT Technology team on 1/12/2014
                      --WHERE flex_value_set_name = 'DO_PRODUCT_SUB_GROUPS_CAT')
                      WHERE flex_value_set_name = 'DO_CLASS_CAT')
                   --End Added by BT Technology team on 1/12/2014
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date_active),
                                                    TRUNC (SYSDATE)) --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND ROWNUM <= 1;

            RETURN lv_flex_value;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 1 - ' || SQLERRM);
                lv_flex_value   := NULL;
                RETURN lv_flex_value;
        END;
    END;

    /******************************************************************************************************************/
    FUNCTION get_sub_group_createdate_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_sub_group     VARCHAR2 (100);
        lv_create_date   DATE;
    BEGIN
        /* Retreiving gender for item provided */
        BEGIN
            /* BEGIN
             SELECT mc.segment4                                                              --Starting commented by BT Technology team on 1/12/2014
               INTO lv_sub_group
               FROM mtl_item_categories mic,
                    mtl_categories mc,
                    mtl_category_sets mcs
              WHERE mic.category_set_id = mcs.category_set_id
                AND mic.category_id = mc.category_id
                AND mc.structure_id = mcs.structure_id
                AND mcs.category_set_name = 'Inventory'
                --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                AND mc.enabled_flag = 'Y'
                AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                 TRUNC (SYSDATE)
                                                )
                                        AND NVL (TRUNC (mc.end_date_active),
                                                 TRUNC (SYSDATE)
                                                )
                --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                AND mic.inventory_item_id = pn_item_id
                AND mic.organization_id = pn_org_id;*/
            --Ending commented by BT Technology team on 1/12/2014
            SELECT msib.master_class
              --Starting Added by BT Technology team on 1/12/2014
              INTO lv_sub_group
              FROM xxd_common_items_v msib
             WHERE     msib.inventory_item_id = pn_item_id
                   AND msib.organization_id = pn_org_id;
        --Ending Added by BT Technology team on 1/12/2014
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_sub_group   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 1 - error occure while retreiving creation date of Category Sub Group '
                    || SQLERRM);
        END;

        BEGIN
            SELECT creation_date
              INTO lv_create_date
              FROM fnd_flex_values
             WHERE     flex_value = lv_sub_group
                   AND --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                 --flex_value_set_id = 1003730
                    flex_value_set_id =
                    (SELECT flex_value_set_id
                       FROM fnd_flex_value_sets
                      --Starting Added by BT Technology team on 1/12/2014
                      --WHERE flex_value_set_name = 'DO_PRODUCT_SUB_GROUPS_CAT')
                      WHERE flex_value_set_name = 'DO_CLASS_CAT')
                   --Starting Added by BT Technology team on 1/12/2014
                   --End Added by BT Technology team on 1/12/2014
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date_active),
                                                    TRUNC (SYSDATE)) --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND ROWNUM <= 1;

            RETURN    TO_CHAR (lv_create_date, 'YYYY-MM-DD')
                   || 'T'
                   || TO_CHAR (lv_create_date, 'HH24:MI:SS');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 1 - ' || SQLERRM);
                lv_create_date   := NULL;
                RETURN lv_create_date;
        END;
    END;

    /******************************************************************************************************************/
    FUNCTION get_sub_group_updatedate_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_sub_group     VARCHAR2 (100);
        lv_update_date   DATE;
        ln_update_by     NUMBER (10);
    BEGIN
        /* Retreiving gender for item provided */
        BEGIN
            /* BEGIN
             SELECT mc.segment4                                                              --Starting commented by BT Technology team on 1/12/2014
               INTO lv_sub_group
               FROM mtl_item_categories mic,
                    mtl_categories mc,
                    mtl_category_sets mcs
              WHERE mic.category_set_id = mcs.category_set_id
                AND mic.category_id = mc.category_id
                AND mc.structure_id = mcs.structure_id
                AND mcs.category_set_name = 'Inventory'
                --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                AND mc.enabled_flag = 'Y'
                AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                 TRUNC (SYSDATE)
                                                )
                                        AND NVL (TRUNC (mc.end_date_active),
                                                 TRUNC (SYSDATE)
                                                )
                --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                AND mic.inventory_item_id = pn_item_id
                AND mic.organization_id = pn_org_id;*/
            --Ending commented by BT Technology team on 1/12/2014
            SELECT msib.master_class
              --Starting Added by BT Technology team on 1/12/2014
              INTO lv_sub_group
              FROM xxd_common_items_v msib
             WHERE     msib.inventory_item_id = pn_item_id
                   AND msib.organization_id = pn_org_id;
        --Ending Added by BT Technology team on 1/12/2014
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_sub_group   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 1 - error occured while retreiving last update date of Category Sub Group '
                    || SQLERRM);
        END;

        BEGIN
            SELECT last_update_date
              INTO lv_update_date
              FROM fnd_flex_values
             WHERE     flex_value = lv_sub_group
                   AND --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                 --flex_value_set_id = 1003730
                    flex_value_set_id =
                    (SELECT flex_value_set_id
                       FROM fnd_flex_value_sets
                      --Starting Added by BT Technology team on 1/12/2014
                      --WHERE flex_value_set_name = 'DO_PRODUCT_SUB_GROUPS_CAT')
                      WHERE flex_value_set_name = 'DO_CLASS_CAT')
                   --End Added by BT Technology team on 1/12/2014
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date_active),
                                                    TRUNC (SYSDATE)) --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND ROWNUM <= 1;

            RETURN    TO_CHAR (lv_update_date, 'YYYY-MM-DD')
                   || 'T'
                   || TO_CHAR (lv_update_date, 'HH24:MI:SS');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 1 - ' || SQLERRM);
                lv_update_date   := NULL;
                RETURN lv_update_date;
        END;
    END;

    /******************************************************************************************************/
    FUNCTION get_sub_group_updatedby_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_sub_group     VARCHAR2 (100);
        ln_update_by     NUMBER (10);
        lv_update_name   VARCHAR2 (30);
    BEGIN
        /* Retreiving gender for item provided */
        BEGIN
            /* BEGIN
             SELECT mc.segment4                                                              --Starting commented by BT Technology team on 1/12/2014
               INTO lv_sub_group
               FROM mtl_item_categories mic,
                    mtl_categories mc,
                    mtl_category_sets mcs
              WHERE mic.category_set_id = mcs.category_set_id
                AND mic.category_id = mc.category_id
                AND mc.structure_id = mcs.structure_id
                AND mcs.category_set_name = 'Inventory'
                --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                AND mc.enabled_flag = 'Y'
                AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                 TRUNC (SYSDATE)
                                                )
                                        AND NVL (TRUNC (mc.end_date_active),
                                                 TRUNC (SYSDATE)
                                                )
                --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                AND mic.inventory_item_id = pn_item_id
                AND mic.organization_id = pn_org_id;*/
            --Ending commented by BT Technology team on 1/12/2014
            SELECT msib.master_class
              --Starting Added by BT Technology team on 1/12/2014
              INTO lv_sub_group
              FROM xxd_common_items_v msib
             WHERE     msib.inventory_item_id = pn_item_id
                   AND msib.organization_id = pn_org_id;
        --Ending Added by BT Technology team on 1/12/2014
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_sub_group   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 1 - error occure while retreiving last update date of Category Sub Group '
                    || SQLERRM);
        END;

        BEGIN
            SELECT last_updated_by
              INTO ln_update_by
              FROM fnd_flex_values
             WHERE     flex_value = lv_sub_group
                   AND --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                 --flex_value_set_id = 1003730
                    flex_value_set_id =
                    (SELECT flex_value_set_id
                       FROM fnd_flex_value_sets
                      --Starting Added by BT Technology team on 1/12/2014
                      --WHERE flex_value_set_name = 'DO_PRODUCT_SUB_GROUPS_CAT')
                      WHERE flex_value_set_name = 'DO_CLASS_CAT')
                   --End Added by BT Technology team on 1/12/2014
                   AND enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date_active),
                                                    TRUNC (SYSDATE)) --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND ROWNUM <= 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 1 - ' || SQLERRM);
                ln_update_by   := NULL;
        END;

        BEGIN
            SELECT user_name
              INTO lv_update_name
              FROM fnd_user
             WHERE     user_id = ln_update_by
                   --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (start_date),
                                                    TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date),
                                                    TRUNC (SYSDATE)) --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                                    ;

            RETURN lv_update_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 1 - ' || SQLERRM);
                lv_update_name   := NULL;
                RETURN lv_update_name;
        END;
    END;

    /******************************************************************************/
    FUNCTION get_cost_us_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN NUMBER
    IS
        lv_style_cat     VARCHAR2 (30);
        ln_base_cost     NUMBER (10, 2);
        ln_category_id   NUMBER;
    BEGIN
        /*
        BEGIN

        select mc.category_id
        into   ln_category_id
        from    apps.mtl_system_items msib,
                apps.mtl_item_categories mic,
                apps.mtl_categories      mc
        where  msib.inventory_item_id  =  mic.inventory_item_id
        and    msib.organization_id    = mic.organization_id
        and    mic.category_id         = mc.category_id
        and    mc.structure_id = 50202
        and    msib.inventory_item_id = pn_item_id
        and    msib.organization_id   = pn_org_id;

        Exception

         WHEN OTHERS THEN
            ln_category_id := NULL;
        END;  */
        BEGIN
            ln_base_cost   := NULL;

            SELECT qll.operand
              INTO ln_base_cost
              FROM qp_list_headers qlh, qp_list_lines qll, qp_pricing_attributes qpa
             WHERE     qlh.list_header_id = qll.list_header_id
                   AND qll.list_line_id = qpa.list_line_id
                   AND qlh.list_header_id = qpa.list_header_id
                   AND qlh.NAME = 'Retail - Outlet'
                   --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (
                                                       qlh.start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (
                                                   TRUNC (
                                                       qlh.end_date_active),
                                                   TRUNC (SYSDATE))
                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND SYSDATE BETWEEN qll.start_date_active
                                   AND NVL (qll.end_date_active, SYSDATE)
                   AND product_attribute = 'PRICING_ATTRIBUTE1'
                   AND qpa.product_attr_value = pn_item_id;

            RETURN ln_base_cost;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    ln_base_cost   := NULL;

                    SELECT qll.operand
                      INTO ln_base_cost
                      -- FROM apps.mtl_system_items msi,
                      FROM xxd_common_items_v msi, apps.mtl_item_categories mic, apps.mtl_categories mc,
                           apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh
                     WHERE     mc.category_id = mic.category_id
                           AND mic.organization_id = msi.organization_id
                           AND mic.inventory_item_id = msi.inventory_item_id
                           AND mc.category_id = qpa.product_attr_value
                           --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                           AND mc.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           TRUNC (
                                                               mc.start_date_active),
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           TRUNC (
                                                               mc.end_date_active),
                                                           TRUNC (SYSDATE))
                           AND TRUNC (SYSDATE) BETWEEN NVL (
                                                           TRUNC (
                                                               qlh.start_date_active),
                                                           TRUNC (SYSDATE))
                                                   AND NVL (
                                                           TRUNC (
                                                               qlh.end_date_active),
                                                           TRUNC (SYSDATE))
                           --                      AND mc.structure_id = 50202
                           --                    AND mic.category_Set_id = 4
                           AND mic.category_set_id =
                               (SELECT category_set_id
                                  FROM mtl_category_sets
                                 --WHERE category_set_name = 'Styles')
                                 WHERE category_set_name =
                                       'OM Sales Category')
                           -- Added by Sreenath BT
                           AND mc.structure_id =
                               (SELECT structure_id
                                  FROM mtl_category_sets
                                 --WHERE category_set_name = 'Styles')
                                 WHERE category_set_name =
                                       'OM Sales Category')
                           -- Added by Sreenath BT
                           --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                           AND qpa.list_line_id = qll.list_line_id
                           AND qll.list_header_id = qlh.list_header_id
                           AND qpa.list_header_id = qlh.list_header_id
                           AND qlh.NAME = 'Retail - Outlet'
                           --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                           --AND msi.organization_id = 7
                           /* AND msi.organization_id =
                                   (SELECT organization_id
                                      FROM org_organization_definitions
                                     WHERE organization_name = 'MST_Deckers_Item_Master')*/
                           --commented by BT Team on 09/12/2014
                           AND msi.organization_id IN
                                   (SELECT ood.ORGANIZATION_ID
                                      FROM fnd_lookup_values flv, org_organization_definitions ood
                                     WHERE     lookup_type =
                                               'XXD_1206_INV_ORG_MAPPING'
                                           AND lookup_code = 7
                                           AND flv.attribute1 =
                                               ood.ORGANIZATION_CODE
                                           AND language = USERENV ('LANG')) --Added bY BT Team on 09/12/2014
                           --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                           /*AND msi.segment3 <> 'ALL'
                            AND msi.segment1 NOT LIKE 'S%L'
                            AND msi.segment1 NOT LIKE 'S%R'*/
                           --commented by BT Team on 09/12/2014
                           AND msi.item_type <> 'GENERIC' --Added bY BT Team on 09/12/2014 START
                           AND msi.style_number NOT LIKE 'S%L'
                           AND msi.style_number NOT LIKE 'S%R' --Added bY BT Team on 09/12/2014 END
                           --and   msi.attribute11 is not null
                           -- and   msi.attribute13 is not null
                           AND SYSDATE BETWEEN qll.start_date_active
                                           AND NVL (qll.end_date_active,
                                                    SYSDATE)
                           AND qpa.product_attribute = 'PRICING_ATTRIBUTE2'
                           AND qpa.product_attribute_context = 'ITEM'
                           AND msi.inventory_item_id = pn_item_id;

                    RETURN ln_base_cost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        BEGIN
                            ln_base_cost   := NULL;

                            SELECT qll.operand
                              INTO ln_base_cost
                              -- FROM apps.mtl_system_items msi,                    --commented by BT Team on 09/12/2014
                              FROM xxd_common_items_v msi, --Added by BT Team on 09/12/2014
                                                           apps.mtl_item_categories mic, apps.mtl_categories mc,
                                   apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh
                             WHERE     mc.category_id = mic.category_id
                                   AND mic.organization_id =
                                       msi.organization_id
                                   AND mic.inventory_item_id =
                                       msi.inventory_item_id
                                   AND mc.category_id =
                                       qpa.product_attr_value
                                   --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                   --AND mc.structure_id = 50202
                                   AND mc.structure_id =
                                       (SELECT structure_id
                                          FROM mtl_category_sets
                                         --WHERE category_set_name = 'Styles')                       --commented BY BT Team on 09/12/2014
                                         WHERE category_set_name =
                                               'OM Sales Category') --added by BT Team on 09/12/2014
                                   -- Added by Sreenath BT
                                   AND mc.enabled_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   TRUNC (
                                                                       mc.start_date_active),
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   TRUNC (
                                                                       mc.end_date_active),
                                                                   TRUNC (
                                                                       SYSDATE))
                                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                   TRUNC (
                                                                       qlh.start_date_active),
                                                                   TRUNC (
                                                                       SYSDATE))
                                                           AND NVL (
                                                                   TRUNC (
                                                                       qlh.end_date_active),
                                                                   TRUNC (
                                                                       SYSDATE))
                                   --AND mic.category_Set_id = 4
                                   AND mic.category_set_id =
                                       (SELECT category_set_id
                                          FROM mtl_category_sets
                                         --WHERE category_set_name = 'Styles')                                     --commented BY BT Team on 09/12/2014
                                         WHERE category_set_name =
                                               'OM Sales Category') --added by BT Team on 09/12/2014
                                   -- Added by Sreenath BT
                                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                   AND qpa.list_line_id = qll.list_line_id
                                   AND qll.list_header_id =
                                       qlh.list_header_id
                                   AND qpa.list_header_id =
                                       qlh.list_header_id
                                   -- AND qlh.NAME = 'Wholesale - US' -- Version 1.2
                                   AND qlh.NAME =
                                       fnd_profile.VALUE (
                                           'XXDO_WHOLESALE_PRICELIST') -- Version 1.2
                                   --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                   --AND msi.organization_id = 7
                                   AND msi.organization_id IN
                                           (SELECT ood.ORGANIZATION_ID
                                              FROM fnd_lookup_values flv, org_organization_definitions ood
                                             WHERE     lookup_type =
                                                       'XXD_1206_INV_ORG_MAPPING'
                                                   AND lookup_code = 7
                                                   AND flv.attribute1 =
                                                       ood.ORGANIZATION_CODE
                                                   AND language =
                                                       USERENV ('LANG')) --Added bY BT Team on 09/12/2014
                                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                   /*AND msi.segment3 <> 'ALL'
                             AND msi.segment1 NOT LIKE 'S%L'
                             AND msi.segment1 NOT LIKE 'S%R'*/
                                   --commented by BT Team on 09/12/2014
                                   AND msi.item_type <> 'GENERIC' --Added bY BT Team on 09/12/2014 START
                                   AND msi.style_number NOT LIKE 'S%L'
                                   AND msi.style_number NOT LIKE 'S%R' --Added bY BT Team on 09/12/2014 END
                                   --and   msi.attribute11 is not null
                                   --and   msi.attribute13 is not null
                                   AND SYSDATE BETWEEN qll.start_date_active
                                                   AND NVL (
                                                           qll.end_date_active,
                                                           SYSDATE)
                                   AND qpa.product_attribute =
                                       'PRICING_ATTRIBUTE2'
                                   AND qpa.product_attribute_context = 'ITEM'
                                   AND msi.inventory_item_id = pn_item_id;

                            RETURN ln_base_cost;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_base_cost   := 0.01;
                                RETURN ln_base_cost;
                        END;
                    WHEN OTHERS
                    THEN
                        ln_base_cost   := 0.01;
                        RETURN ln_base_cost;
                END;
            WHEN OTHERS
            THEN
                ln_base_cost   := 0.01;
                RETURN ln_base_cost;
        END;
    END;

    /*******************************************************************************************************/
    FUNCTION get_region_cost_f (pv_style VARCHAR2, pv_color VARCHAR2, pv_size VARCHAR2
                                , pv_region VARCHAR2)
        RETURN NUMBER
    IS
        ln_cost   NUMBER (10, 2);
    BEGIN
        IF pv_region = 'UK'
        THEN
            /* retreiving cost info for UK */
            BEGIN
                SELECT NVL (qll.operand, 0)
                  INTO ln_cost
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --mtl_system_items_b msib                           --commented by BT Technology Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Technology Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --AND msib.organization_id = 7
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')  */
                       --commented by BT Technology Team on 09/12/2014
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'DEL GBP Inter Company Price list'
                       AND SYSDATE BETWEEN qll.start_date_active
                                       AND NVL (qll.end_date_active, SYSDATE)
                       /* AND msib.segment1 = pv_style
                        AND msib.segment2 = pv_color
                        AND msib.segment3 = pv_size*/
                       --commented by BT Team on 09/12/2014
                       AND msib.style_number = pv_style --added by BT Team on 09/12/2014 START
                       AND msib.color_code = pv_color
                       AND msib.item_size = pv_size --added by BT Team on 09/12/2014 END
                       AND ROWNUM <= 1;

                RETURN ln_cost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_cost   := 0.01;
                    RETURN ln_cost;
            END;
        --- Added By Sivakumar Boothathan for adding the region cost FR
        ELSIF pv_region = 'FR'
        THEN
            /* retreiving cost info for FR*/
            BEGIN
                ln_cost   := NULL;

                SELECT NVL (qll.operand, 0)
                  INTO ln_cost
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --mtl_system_items_b msib                           --commented by BT Technology Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Technology Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME =
                           'EUR Retail Inter-company Price List (UK2)'
                       AND SYSDATE BETWEEN qll.start_date_active
                                       AND NVL (qll.end_date_active, SYSDATE)
                       /* AND msib.segment1 = pv_style
                        AND msib.segment2 = pv_color
                        AND msib.segment3 = pv_size*/
                       --commented by BT Team on 09/12/2014
                       AND msib.style_number = pv_style --added by BT Team on 09/12/2014 START
                       AND msib.color_code = pv_color
                       AND msib.item_size = pv_size --added by BT Team on 09/12/2014 END
                       AND ROWNUM <= 1;

                IF ln_cost = 0
                THEN
                    ln_cost   := 0.01;
                END IF;

                RETURN ln_cost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_cost   := 0.01;
                    RETURN ln_cost;
            END;
        ELSIF pv_region = 'CA'
        THEN
            /* retreiving cost info for CA*/
            BEGIN
                SELECT NVL (qll.operand, 0)
                  INTO ln_cost
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --mtl_system_items_b msib                           --commented by BT Technology Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Technology Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'Retail Canada Replenishment ? DC3'
                       AND SYSDATE BETWEEN qll.start_date_active
                                       AND NVL (qll.end_date_active, SYSDATE)
                       /* AND msib.segment1 = pv_style
                       AND msib.segment2 = pv_color
                       AND msib.segment3 = pv_size*/
                       --commented by BT Team on 09/12/2014
                       AND msib.style_number = pv_style --added by BT Team on 09/12/2014 START
                       AND msib.color_code = pv_color
                       AND msib.item_size = pv_size --added by BT Team on 09/12/2014 END
                       AND ROWNUM <= 1;

                RETURN ln_cost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_cost   := 0.01;
                    RETURN ln_cost;
            END;
        ELSIF pv_region = 'HK'
        THEN
            /* retreiving cost info for CA*/
            BEGIN
                SELECT NVL (qll.operand, 0)
                  INTO ln_cost
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --mtl_system_items_b msib                           --commented by BT Technology Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Technology Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       --and msib.inventory_item_status_code = 'Active'
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'Retail Hong Kong Replenishment'
                       AND SYSDATE BETWEEN qll.start_date_active
                                       AND NVL (qll.end_date_active, SYSDATE)
                       /* AND msib.segment1 = pv_style
                        AND msib.segment2 = pv_color
                        AND msib.segment3 = pv_size*/
                       --commented by BT Team on 09/12/2014
                       AND msib.style_number = pv_style --added by BT Team on 09/12/2014 START
                       AND msib.color_code = pv_color
                       AND msib.item_size = pv_size --added by BT Team on 09/12/2014 END
                       AND ROWNUM <= 1;

                RETURN ln_cost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_cost   := 0.01;
                    RETURN ln_cost;
            END;
        ELSIF pv_region = 'JP'
        THEN
            /* retreiving cost info for JP*/
            BEGIN
                SELECT NVL (qll.operand, 0)
                  INTO ln_cost
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --mtl_system_items_b msib                           --commented by BT Technology Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Technology Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'Japan Retail Replenishment JPY'
                       AND SYSDATE BETWEEN qll.start_date_active
                                       AND NVL (qll.end_date_active, SYSDATE)
                       /* AND msib.segment1 = pv_style
                       AND msib.segment2 = pv_color
                       AND msib.segment3 = pv_size*/
                       --commented by BT Team on 09/12/2014
                       AND msib.style_number = pv_style --added by BT Team on 09/12/2014 START
                       AND msib.color_code = pv_color
                       AND msib.item_size = pv_size --added by BT Team on 09/12/2014 END
                       AND ROWNUM <= 1;

                RETURN ln_cost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        SELECT NVL (qll.operand, 0)
                          INTO ln_cost
                          FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                               mtl_categories_b mc, --mtl_category_sets mcs,
                                                    mtl_item_categories mic, --mtl_system_items_b msib                           --commented by BT Technology Team on 09/12/2014
                                                                             xxd_common_items_v msib --Added by BT Technology Team on 09/12/2014
                         WHERE     qpa.list_line_id = qll.list_line_id
                               AND qll.list_header_id = qlh.list_header_id
                               AND qpa.list_header_id = qlh.list_header_id
                               AND mic.inventory_item_id =
                                   msib.inventory_item_id
                               AND mic.organization_id = msib.organization_id
                               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               /*
                                                        AND msib.enabled_flag = 'Y'
                                                        AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                                       TRUNC (
                                                                                          msib.start_date_active),
                                                                                       TRUNC (SYSDATE))
                                                                                AND NVL (
                                                                                       TRUNC (
                                                                                          msib.end_date_active),
                                                                                       TRUNC (SYSDATE))
                                                        AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                                       TRUNC (
                                                                                          qlh.start_date_active),
                                                                                       TRUNC (SYSDATE))
                                                                                AND NVL (
                                                                                       TRUNC (
                                                                                          qlh.end_date_active),
                                                                                       TRUNC (SYSDATE))
                               */
                               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               --    and mc.structure_id   = mcs.structure_id
                               AND qpa.product_attribute =
                                   'PRICING_ATTRIBUTE2'
                               AND qpa.product_attr_value = mc.category_id
                               --and qpa.product_attr_value = to_char(mc.category_id)
                               AND mic.category_id = mc.category_id
                               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               --AND mc.structure_id = 50202
                               --AND mic.category_Set_id = 4
                               AND mc.structure_id =
                                   (SELECT structure_id
                                      FROM mtl_category_sets
                                     --WHERE category_set_name = 'Styles')                                        --commented BY BT Technology Team on 09/12/2014
                                     WHERE category_set_name =
                                           'OM Sales Category') --Added by BT Technology Team on 09/12/2014
                               -- Added by Sreenath BT
                               AND mic.category_set_id =
                                   (SELECT category_set_id
                                      FROM mtl_category_sets
                                     --WHERE category_set_name = 'Styles')                                --commented BY BT Technology Team on 09/12/2014
                                     WHERE category_set_name =
                                           'OM Sales Category') --Added by BT Technology Team on 09/12/2014
                               -- Added by Sreenath BT
                               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               --  and mic.category_set_id = mcs.category_set_id
                               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               /* AND msib.organization_id =
                                         (SELECT organization_id
                                            FROM org_organization_definitions
                                           WHERE organization_name = 'MST_Deckers_Item_Master')*/
                               --commented by BT Technology Team on 09/12/2014
                               --AND msib.organization_id = 7
                               AND msib.organization_id IN
                                       (SELECT ood.ORGANIZATION_ID
                                          FROM fnd_lookup_values flv, org_organization_definitions ood
                                         WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                               AND lookup_code = 7
                                               AND flv.attribute1 =
                                                   ood.ORGANIZATION_CODE
                                               AND language =
                                                   USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               --and msib.inventory_item_status_code = 'Active'
                               AND qpa.product_attribute_context = 'ITEM'
                               AND qlh.NAME =
                                   'Japan Retail Replenishment JPY'
                               AND SYSDATE BETWEEN qll.start_date_active
                                               AND NVL (qll.end_date_active,
                                                        SYSDATE)
                               --   and mcs.category_set_name='Styles'
                               /* AND msib.segment1 = pv_style
                           AND msib.segment2 = pv_color
                           AND msib.segment3 = pv_size*/
                               --commented by BT Team on 09/12/2014
                               AND msib.style_number = pv_style --added by BT Team on 09/12/2014 START
                               AND msib.color_code = pv_color
                               AND msib.item_size = pv_size --added by BT Team on 09/12/2014 END
                               AND ROWNUM <= 1;

                        IF ln_cost = 0
                        THEN
                            ln_cost   := 0.01;
                        END IF;

                        RETURN ln_cost;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            RETURN 0.01;
                    END;
            END;
        ELSIF pv_region = 'CN'
        THEN
            /* retreiving cost info for CN */
            BEGIN
                ln_cost   := NULL;

                SELECT NVL (qll.operand, 0)
                  INTO ln_cost
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --mtl_system_items_b msib                           --commented by BT Technology Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Technology Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'Retail China Replenishment'
                       AND SYSDATE BETWEEN qll.start_date_active
                                       AND NVL (qll.end_date_active, SYSDATE)
                       /* AND msib.segment1 = pv_style
                     AND msib.segment2 = pv_color
                     AND msib.segment3 = pv_size*/
                       --commented by BT Team on 09/12/2014
                       AND msib.style_number = pv_style --added by BT Team on 09/12/2014 START
                       AND msib.color_code = pv_color
                       AND msib.item_size = pv_size --added by BT Team on 09/12/2014 END
                       AND ROWNUM <= 1;

                RETURN ln_cost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_cost   := 0.01;
                    RETURN ln_cost;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'EXCEPTION 1 - error occured while retreiving base cost for CN'
                        || SQLERRM);
            END;
        END IF;

        RETURN ln_cost;
    END;

    /**************************************************************************************************************/
    FUNCTION get_region_price_f (pv_style VARCHAR2, pv_color VARCHAR2, pv_size VARCHAR2
                                 , pv_region VARCHAR2)
        RETURN NUMBER
    IS
        ln_price   NUMBER (10, 2);
    BEGIN
        IF pv_region = 'UK'
        THEN
            /* retreiving cost info for UK */
            BEGIN
                ln_price   := NULL;

                /* Commented the code as this logic is not used - As per Retail team 12/20
                            SELECT NVL (price_orig, 0)
                              INTO ln_price
                              FROM     --Start modfication by BT Technology for BT version 1.0
                                                       --uk_inventory_items@do_retail_datamart
                                   uk_inv_itm_do_retail_datamart
                             --End modfication by BT Technology for BT version 1.0
                             WHERE style = pv_style AND color = pv_color AND sze = pv_size;
                */
                RETURN ln_price;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_price   := 0.01;
                    RETURN ln_price;
            END;
        ELSIF pv_region = 'CA'
        THEN
            /* retreiving cost info for CA */
            BEGIN
                ln_price   := NULL;

                /* Commented the code as this logic is not used - As per Retail team 12/20
                            SELECT NVL (price_orig, 0)
                              INTO ln_price
                              FROM     --Start modfication by BT Technology for BT version 1.0
                                                      --can_inventory_items@do_retail_datamart
                                   can_inventory_items
                             --End modfication by BT Technology for BT version 1.0
                             WHERE style = pv_style AND color = pv_color AND sze = pv_size;
                */
                RETURN ln_price;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_price   := 0.01;
                    RETURN ln_price;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'EXCEPTION 1 - error occured while retreiving price for CA'
                        || SQLERRM);
            END;
        ELSIF pv_region = 'JP'
        THEN
            /* retreiving cost info for JP*/
            BEGIN
                ln_price   := NULL;

                /* Commented the code as this logic is not used - As per Retail team 12/20
                            SELECT NVL (price_orig, 0)
                              INTO ln_price
                              FROM     --Start modfication by BT Technology for BT version 1.0
                                                       --jp_inventory_items@do_retail_datamart
                                   jp_inventory_items
                             --End modfication by BT Technology for BT version 1.0
                             WHERE style = pv_style AND color = pv_color AND sze = pv_size;
                */

                RETURN ln_price;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_price   := 0.01;
                    RETURN ln_price;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'EXCEPTION 1 - error occured while retreiving price for JP'
                        || SQLERRM);
            END;
        ELSIF pv_region = 'CN'
        THEN
            /* retreiving cost info for CN */
            BEGIN
                ln_price   := NULL;

                /* Commented the code as this logic is not used - As per Retail team 12/20
                            SELECT NVL (price_orig, 0)
                              INTO ln_price
                              FROM     --Start modfication by BT Technology for BT version 1.0
                                  cn_inventory_items
                             --cn_inventory_items@do_retail_datamart
                             --End modfication by BT Technology for BT version 1.0
                             WHERE style = pv_style AND color = pv_color AND sze = pv_size;
                */
                RETURN ln_price;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_price   := 0.01;
                    RETURN ln_price;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'EXCEPTION 1 - error occured while retreiving price for CN'
                        || SQLERRM);
            END;
        ELSIF pv_region = 'HK'
        THEN
            ln_price   := 0.01;
            RETURN ln_price;
        ELSIF pv_region = 'FR'
        THEN
            ln_price   := 0.01;
            RETURN ln_price;
        END IF;

        RETURN ln_price;
    END;

    /***************************************************************************************/
    FUNCTION get_vertex_tax_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_tax_cat   VARCHAR2 (60);
    /* Retreiving Vertex Tax for item provided */
    BEGIN
        SELECT mc.segment1
          INTO lv_tax_cat
          FROM mtl_item_categories mic, mtl_categories mc, mtl_category_sets mcs
         WHERE     mic.category_set_id = mcs.category_set_id
               AND mic.category_id = mc.category_id
               AND mc.structure_id = mcs.structure_id
               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND mc.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                TRUNC (SYSDATE))
                                       AND NVL (TRUNC (mc.end_date_active),
                                                TRUNC (SYSDATE))
               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND mcs.category_set_name = 'Tax Class'
               AND mic.inventory_item_id = pn_item_id
               AND mic.organization_id = pn_org_id;

        fnd_file.put_line (
            fnd_file.LOG,
               'Test msg vertex tax derivation pn item id: '
            || pn_item_id
            || 'pn_org_id - '
            || pn_org_id
            || 'lv_tax_cat - '
            || lv_tax_cat);

        RETURN lv_tax_cat;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_tax_cat   := '9999';
            /*  fnd_file.put_line
                 (fnd_file.LOG,'EXCEPTION 1 - error occure while retreiving Tax Category segment '
                  || SQLERRM
                 ); */
            RETURN lv_tax_cat;
    END;

    FUNCTION get_vertex_createdate_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_tax_creation_date   VARCHAR2 (60);
    /* Retreiving Vertex Tax for item provided */
    BEGIN
        SELECT TO_CHAR (mc.creation_date, 'RRRR-MM-DD') || 'T' || TO_CHAR (mc.creation_date, 'HH24:MI:SS')
          INTO lv_tax_creation_date
          FROM mtl_item_categories mic, mtl_categories mc, mtl_category_sets mcs
         WHERE     mic.category_set_id = mcs.category_set_id
               AND mic.category_id = mc.category_id
               AND mc.structure_id = mcs.structure_id
               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND mc.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                TRUNC (SYSDATE))
                                       AND NVL (TRUNC (mc.end_date_active),
                                                TRUNC (SYSDATE))
               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND mcs.category_set_name = 'Tax Class'
               AND mic.inventory_item_id = pn_item_id
               AND mic.organization_id = pn_org_id;

        RETURN lv_tax_creation_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                SELECT TO_CHAR (SYSDATE, 'RRRR-MM-DD') || 'T' || TO_CHAR (SYSDATE, 'HH24:MI:SS')
                  INTO lv_tax_creation_date
                  FROM DUAL;

                RETURN lv_tax_creation_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;

            /* fnd_file.put_line
                (fnd_file.LOG,'EXCEPTION 1 - error occure while retreiving Tax Category segment '
                 || SQLERRM
                );*/
            RETURN lv_tax_creation_date;
    END;

    FUNCTION get_vertex_updatedate_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_tax_update_date   VARCHAR2 (60);
    /* Retreiving Vertex Tax for item provided */
    BEGIN
        SELECT TO_CHAR (mc.last_update_date, 'RRRR-MM-DD') || 'T' || TO_CHAR (mc.last_update_date, 'HH24:MI:SS')
          INTO lv_tax_update_date
          FROM mtl_item_categories mic, mtl_categories mc, mtl_category_sets mcs
         WHERE     mic.category_set_id = mcs.category_set_id
               AND mic.category_id = mc.category_id
               AND mc.structure_id = mcs.structure_id
               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND mc.enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                TRUNC (SYSDATE))
                                       AND NVL (TRUNC (mc.end_date_active),
                                                TRUNC (SYSDATE))
               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND mcs.category_set_name = 'Tax Class'
               AND mic.inventory_item_id = pn_item_id
               AND mic.organization_id = pn_org_id;

        RETURN lv_tax_update_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                SELECT TO_CHAR (SYSDATE, 'RRRR-MM-DD') || 'T' || TO_CHAR (SYSDATE, 'HH24:MI:SS')
                  INTO lv_tax_update_date
                  FROM DUAL;

                RETURN lv_tax_update_date;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;

            /* lv_tax_update_date:=NULL;
             fnd_file.put_line
                (fnd_file.LOG,'EXCEPTION 1 - error occure while retreiving Tax Category segment '
                 || SQLERRM
                ); */
            RETURN lv_tax_update_date;
    END;

    FUNCTION get_vertex_updatedby_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
    IS
        ln_update_by     NUMBER (10);
        lv_update_name   VARCHAR2 (30);
    BEGIN
        /* Retreiving gender for item provided */
        BEGIN
            SELECT mc.last_updated_by
              INTO ln_update_by
              FROM mtl_item_categories mic, mtl_categories mc, mtl_category_sets mcs
             WHERE     mic.category_set_id = mcs.category_set_id
                   AND mic.category_id = mc.category_id
                   AND mc.structure_id = mcs.structure_id
                   AND mcs.category_set_name = 'Tax Class'
                   --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND mc.enabled_flag = 'Y'
                   AND TRUNC (SYSDATE) BETWEEN NVL (
                                                   TRUNC (
                                                       mc.start_date_active),
                                                   TRUNC (SYSDATE))
                                           AND NVL (
                                                   TRUNC (mc.end_date_active),
                                                   TRUNC (SYSDATE))
                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND mic.inventory_item_id = pn_item_id
                   AND mic.organization_id = pn_org_id;

            RETURN ln_update_by;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_update_by   := NULL;
                /*   fnd_file.put_line
                      (fnd_file.LOG,
                          'EXCEPTION 1 - error occure while retreiving last update date of Tax Class Category  '
                       || SQLERRM
                      );*/
                RETURN ln_update_by;
        END;

        BEGIN
            SELECT user_name
              INTO lv_update_name
              FROM fnd_user
             WHERE     user_id = ln_update_by
                   --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (start_date),
                                                    TRUNC (SYSDATE))
                                           AND NVL (TRUNC (end_date),
                                                    TRUNC (SYSDATE)) --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                                    ;

            RETURN lv_update_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 1 - ' || SQLERRM);
                lv_update_name   := NULL;
                RETURN lv_update_name;
        END;
    END;

    FUNCTION get_item_id_f (pv_style   VARCHAR2,
                            pv_color   VARCHAR2,
                            pv_size    VARCHAR2)
        RETURN NUMBER
    IS
        ln_item_id   NUMBER (20);
    BEGIN
        BEGIN
            SELECT inventory_item_id
              INTO ln_item_id
              FROM xxd_common_items_v
             WHERE     style_number = pv_style
                   AND color_code = pv_color
                   AND item_size = pv_size
                   /* FROM mtl_system_items
                   WHERE segment1 = pv_style
                     AND segment2 = pv_color
                     AND segment3 = pv_size*/
                   --commented by BT Team on 09/12/2014
                   --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   /* AND organization_id =
                                (SELECT organization_id
                                   FROM org_organization_definitions
                                  WHERE organization_name = 'MST_Deckers_Item_Master')*/
                   --commented by BT Technology Team on 09/12/2014
                   --AND organization_id = 7
                   AND organization_id IN
                           (SELECT ood.ORGANIZATION_ID
                              FROM fnd_lookup_values flv, org_organization_definitions ood
                             WHERE     lookup_type =
                                       'XXD_1206_INV_ORG_MAPPING'
                                   AND lookup_code = 7
                                   AND flv.attribute1 = ood.ORGANIZATION_CODE
                                   AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                                                                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                                                   ;

            RETURN (ln_item_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    ' Error occure infunction GET_ITEM_ID_F while retrieving inventory item id');
                RETURN NULL;
        END;
    END;

    FUNCTION get_item_status (pv_style              VARCHAR2,
                              pn_inventory_itemid   NUMBER,
                              pn_organization_id    NUMBER)
        RETURN VARCHAR2
    IS
        lv_itemstatus   VARCHAR2 (100);
    BEGIN
        SELECT inventory_item_status_code
          INTO lv_itemstatus
          --  FROM mtl_system_items                 --commented by BT Team on 09/12/2014
          FROM xxd_common_items_v          --added by BT Team on 0n 09/12/2014
         -- WHERE segment1 = pv_style              --commented by BT Team on 09/12/2014
         WHERE     style_number = pv_style    --added by BT Team on 09/12/2014
               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
               /* AND organization_id =
                         (SELECT organization_id
                            FROM org_organization_definitions
                           WHERE organization_name = 'MST_Deckers_Item_Master')*/
               --commented by BT Technology Team on 09/12/2014
               --AND organization_id = 7
               AND organization_id IN
                       (SELECT ood.ORGANIZATION_ID
                          FROM fnd_lookup_values flv, org_organization_definitions ood
                         WHERE     lookup_type = 'XXD_1206_INV_ORG_MAPPING'
                               AND lookup_code = 7
                               AND flv.attribute1 = ood.ORGANIZATION_CODE
                               AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
               AND inventory_item_status_code = 'Active'
               AND ROWNUM = 1;

        IF lv_itemstatus IS NOT NULL
        THEN
            RETURN 'A';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            SELECT DECODE (INITCAP (inventory_item_status_code), 'Inactive', 'I', 'C')
              INTO lv_itemstatus
              --  FROM mtl_system_items                                              --commented by BT Team on 09/12/2014
              FROM xxd_common_items_v         --Added by BT Team on 09/12/2014
             WHERE     inventory_item_id = pn_inventory_itemid
                   --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   /* AND organization_id =
                               (SELECT organization_id
                                  FROM org_organization_definitions
                                 WHERE organization_name = 'MST_Deckers_Item_Master')*/
                   --commented by BT Technology Team on 09/12/2014
                   --AND organization_id = 7
                   AND organization_id IN
                           (SELECT ood.ORGANIZATION_ID
                              FROM fnd_lookup_values flv, org_organization_definitions ood
                             WHERE     lookup_type =
                                       'XXD_1206_INV_ORG_MAPPING'
                                   AND lookup_code = 7
                                   AND flv.attribute1 = ood.ORGANIZATION_CODE
                                   AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                   --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                   AND ROWNUM = 1;

            RETURN lv_itemstatus;
    END;

    FUNCTION get_brand_f (pv_style     VARCHAR2,
                          pn_item_id   NUMBER,
                          pn_org_id    NUMBER)
        RETURN VARCHAR2
    IS
        ln_item_id   NUMBER (20) := NULL;
        lv_brand     VARCHAR2 (30) := NULL;
    BEGIN
        IF pv_style IS NOT NULL
        THEN
            BEGIN
                /* SELECT mc.segment1
                   INTO lv_brand
                   FROM mtl_system_items_b msib,
                        mtl_item_categories mic,
                        mtl_categories mc
                  --   mtl_category_sets   mcs
                 WHERE  msib.inventory_item_id = mic.inventory_item_id
                    AND msib.organization_id = mic.organization_id
                    AND mic.category_id = mc.category_id
                    --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    AND mc.enabled_flag = 'Y'
                    AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                     TRUNC (SYSDATE)
                                                    )
                                            AND NVL (TRUNC (mc.end_date_active),
                                                     TRUNC (SYSDATE)
                                                    )
                    --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    --    and    mic.category_set_id    = 1
                    --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    --AND mc.structure_id = 101
                    AND mc.structure_id = (SELECT structure_id
                                             FROM mtl_category_sets
                                            WHERE category_set_name = 'Inventory')
                    --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    --  and    mc.structure_id        = mcs.STRUCTURE_ID
                    --  and    mcs.category_set_name  = 'Inventory'
                    AND msib.segment1 = pv_style
                    --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    --AND MSIB.ORGANIZATION_ID = 7
                    AND msib.organization_id =
                             (SELECT organization_id
                                FROM org_organization_definitions
                               WHERE organization_name = 'MST_Deckers_Item_Master')
                    --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    AND msib.enabled_flag = 'Y'
                    AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (msib.start_date_active),
                                                     TRUNC (SYSDATE)
                                                    )
                                            AND NVL (TRUNC (msib.end_date_active),
                                                     TRUNC (SYSDATE)
                                                    )*/

                --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                SELECT msib.brand
                  INTO lv_brand
                  FROM xxd_common_items_v msib
                 WHERE     msib.organization_id IN
                               (SELECT ood.organization_id
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.organization_code
                                       AND LANGUAGE = USERENV ('LANG'))
                       --Added by BT Technology team on 05/12/2014
                       AND ROWNUM = 1;

                RETURN lv_brand;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DBMS_OUTPUT.put_line (
                           'Error occured while retriving brand for Item loc in excep'
                        || SQLCODE
                        || SQLERRM);
            END;
        ELSIF pn_item_id IS NOT NULL
        THEN
            BEGIN
                /* SELECT mc.segment1
                   INTO lv_brand
                   FROM mtl_system_items_b msib,
                        mtl_item_categories mic,
                        mtl_categories mc
                  --         mtl_category_sets   mcs
                 WHERE  msib.inventory_item_id = mic.inventory_item_id
                    AND msib.organization_id = mic.organization_id
                    AND mic.category_id = mc.category_id
                    --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    --AND mc.structure_id = 101
                    AND mc.structure_id = (SELECT structure_id
                                             FROM mtl_category_sets
                                            WHERE category_set_name = 'Inventory')
                    AND mc.enabled_flag = 'Y'
                    AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (mc.start_date_active),
                                                     TRUNC (SYSDATE)
                                                    )
                                            AND NVL (TRUNC (mc.end_date_active),
                                                     TRUNC (SYSDATE)
                                                    )
                    --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    --   and    mic.category_set_id    = 1
                    --    and    mc.structure_id        = mcs.STRUCTURE_ID
                    --  and    mcs.category_set_name  = 'Inventory'
                    AND msib.inventory_item_id = pn_item_id
                    --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    --AND MSIB.ORGANIZATION_ID = 7
                    AND msib.organization_id =
                             (SELECT organization_id
                                FROM org_organization_definitions
                               WHERE organization_name = 'MST_Deckers_Item_Master')
                    --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                    AND msib.enabled_flag = 'Y'
                    AND TRUNC (SYSDATE) BETWEEN NVL (TRUNC (msib.start_date_active),
                                                     TRUNC (SYSDATE)
                                                    )
                                            AND NVL (TRUNC (msib.end_date_active),
                                                     TRUNC (SYSDATE)
                                                    )
                    --End changes by BT Technology for BT on 22-JUL-2014,  v1.0*/
                --commented by BT technology team on 05/12/2014
                SELECT msib.brand
                  INTO lv_brand
                  FROM xxd_common_items_v msib
                 WHERE     msib.organization_id IN
                               (SELECT ood.organization_id
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.organization_code
                                       AND LANGUAGE = USERENV ('LANG'))
                       --Added by BT Technology team on 05/12/2014
                       AND ROWNUM = 1;

                RETURN lv_brand;
            EXCEPTION
                WHEN OTHERS
                THEN
                    DBMS_OUTPUT.put_line (
                           'Error occured while retriving brand for Item loc in excep'
                        || SQLCODE
                        || SQLERRM);
            END;
        END IF;
    END;

    FUNCTION get_uom_conv_f (pn_item_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_conv_rate   NUMBER;
    BEGIN
        SELECT conversion_rate
          INTO ln_conv_rate
          FROM mtl_uom_conversions
         WHERE unit_of_measure = 'Case' AND inventory_item_id = pn_item_id;

        RETURN (ln_conv_rate * 2);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 1;
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error Occured while retrieving converson rate');
    END;

    FUNCTION get_region_cost_f (pn_item_id   NUMBER,
                                pn_org_id    NUMBER,
                                pv_region    VARCHAR2)
        RETURN NUMBER
    IS
        -- RETURN NUMBER IS
        ln_cost          NUMBER (10, 2);
        lv_exists        VARCHAR2 (1);
        ln_category_id   NUMBER;
    BEGIN
        IF pv_region = 'UK'
        THEN
            /* retreiving cost info for UK */
            BEGIN
                lv_exists   := NULL;

                SELECT 'X'
                  INTO lv_exists
                  FROM apps.qp_pricing_attributes qpa, apps.qp_list_lines qll, apps.qp_list_headers qlh,
                       --  apps.mtl_system_items_b msib                           --commented by BT Team on 09/12/2014
                       apps.xxd_common_items_v msib --added by BT Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qll.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qll.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'DEL GBP Inter Company Price list'
                       AND msib.inventory_item_id = pn_item_id
                       --                                    and msib.segment1 = pv_style
                       --                                    and msib.segment2 =pv_color
                       --                                    and msib.segment3 = pv_size
                       AND ROWNUM <= 1;

                IF lv_exists IS NOT NULL
                THEN
                    RETURN 1;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    RETURN 0;
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF pv_region = 'US'
        THEN
            BEGIN
                SELECT mc.category_id
                  INTO ln_category_id
                  -- FROM apps.mtl_system_items msib,                              --commented by BT Team on 09/12/2014
                  FROM apps.xxd_common_items_v msib, --Added by BT Team on 09/12/2014
                                                     apps.mtl_item_categories mic, apps.mtl_categories mc
                 WHERE     msib.inventory_item_id = mic.inventory_item_id
                       AND msib.organization_id = mic.organization_id
                       AND mic.category_id = mc.category_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       AND mc.enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       TRUNC (
                                                           mc.start_date_active),
                                                       TRUNC (SYSDATE))
                                               AND NVL (
                                                       TRUNC (
                                                           mc.end_date_active),
                                                       TRUNC (SYSDATE))
                       --AND mc.structure_id = 50202
                       AND mc.structure_id =
                           (SELECT structure_id
                              FROM mtl_category_sets
                             --WHERE category_set_name = 'Styles')  --  Removed by Sreenath for BT
                             WHERE category_set_name = 'OM Sales Category')
                       -- Added by Sreenath BT
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       AND msib.inventory_item_id = pn_item_id
                       AND msib.organization_id = pn_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_category_id   := NULL;
                    RETURN 0;
            END;

            BEGIN
                lv_exists   := NULL;

                SELECT 'X'
                  INTO lv_exists
                  FROM qp_list_headers qlh, qp_list_lines qll, qp_pricing_attributes qpa
                 WHERE     qlh.list_header_id = qll.list_header_id
                       AND qll.list_line_id = qpa.list_line_id
                       AND qlh.list_header_id = qpa.list_header_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       TRUNC (
                                                           qlh.start_date_active),
                                                       TRUNC (SYSDATE))
                                               AND NVL (
                                                       TRUNC (
                                                           qlh.end_date_active),
                                                       TRUNC (SYSDATE))
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       TRUNC (
                                                           qll.start_date_active),
                                                       TRUNC (SYSDATE))
                                               AND NVL (
                                                       TRUNC (
                                                           qll.end_date_active),
                                                       TRUNC (SYSDATE))
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       AND qlh.NAME = 'Retail - Outlet'
                       AND product_attribute = 'PRICING_ATTRIBUTE2'
                       AND qpa.product_attr_value = ln_category_id;

                IF lv_exists IS NOT NULL
                THEN
                    RETURN 1;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        lv_exists   := NULL;

                        SELECT 'X'
                          INTO lv_exists
                          FROM qp_list_headers qlh, qp_list_lines qll, qp_pricing_attributes qpa
                         WHERE     qlh.list_header_id = qll.list_header_id
                               AND qll.list_line_id = qpa.list_line_id
                               AND qlh.list_header_id = qpa.list_header_id
                               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               TRUNC (
                                                                   qlh.start_date_active),
                                                               TRUNC (
                                                                   SYSDATE))
                                                       AND NVL (
                                                               TRUNC (
                                                                   qlh.end_date_active),
                                                               TRUNC (
                                                                   SYSDATE))
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               TRUNC (
                                                                   qll.start_date_active),
                                                               TRUNC (
                                                                   SYSDATE))
                                                       AND NVL (
                                                               TRUNC (
                                                                   qll.end_date_active),
                                                               TRUNC (
                                                                   SYSDATE))
                               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               AND qlh.NAME = 'Retail - Outlet'
                               AND product_attribute = 'PRICING_ATTRIBUTE1'
                               AND qpa.product_attr_value = pn_item_id;

                        IF lv_exists IS NOT NULL
                        THEN
                            RETURN 1;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                lv_exists   := NULL;

                                SELECT 'X'
                                  INTO lv_exists
                                  FROM qp_list_headers qlh, qp_list_lines qll, qp_pricing_attributes qpa
                                 WHERE     qlh.list_header_id =
                                           qll.list_header_id
                                       AND qll.list_line_id =
                                           qpa.list_line_id
                                       AND qlh.list_header_id =
                                           qpa.list_header_id
                                       -- AND qlh.NAME = 'Wholesale - US' -- Version 1.2
                                       AND qlh.NAME =
                                           fnd_profile.VALUE (
                                               'XXDO_WHOLESALE_PRICELIST') -- Version 1.2
                                       -- Added By Sreenath
                                       --   AND qlh.NAME = 'Wholesale US USD' -- Removed by Sreenath for BT
                                       AND product_attribute =
                                           'PRICING_ATTRIBUTE2'
                                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       TRUNC (
                                                                           qlh.start_date_active),
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       TRUNC (
                                                                           qlh.end_date_active),
                                                                       TRUNC (
                                                                           SYSDATE))
                                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                       TRUNC (
                                                                           qll.start_date_active),
                                                                       TRUNC (
                                                                           SYSDATE))
                                                               AND NVL (
                                                                       TRUNC (
                                                                           qll.end_date_active),
                                                                       TRUNC (
                                                                           SYSDATE))
                                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                       AND qpa.product_attr_value =
                                           ln_category_id;

                                IF lv_exists IS NOT NULL
                                THEN
                                    RETURN 1;
                                END IF;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    RETURN 0;
                            END;
                        WHEN OTHERS
                        THEN
                            RETURN 0;
                    END;
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF pv_region = 'FR'
        THEN
            /* retreiving cost info for FR*/
            BEGIN
                lv_exists   := NULL;

                SELECT 'X'
                  INTO lv_exists
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --  mtl_system_items_b msib                                    --commented by BT Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qll.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qll.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME =
                           'EUR Retail Inter-company Price List (UK2)'
                       AND msib.inventory_item_id = pn_item_id
                       --                                    and  msib.segment1 =  pv_style
                       --                                    and  msib.segment2 =  pv_color
                       --                                    and  msib.segment3 =  pv_size
                       AND ROWNUM <= 1;

                IF lv_exists IS NOT NULL
                THEN
                    RETURN 1;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF pv_region = 'CA'
        THEN
            /* retreiving cost info for CA*/
            BEGIN
                lv_exists   := NULL;

                SELECT 'X'
                  INTO lv_exists
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --  mtl_system_items_b msib                                    --commented by BT Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qll.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qll.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'Retail Canada Replenishment ? DC3'
                       AND msib.inventory_item_id = pn_item_id
                       --                                    and  msib.segment1 =  pv_style
                       --                                    and  msib.segment2 =  pv_color
                       --                                    and  msib.segment3 =  pv_size
                       AND ROWNUM <= 1;

                IF lv_exists IS NOT NULL
                THEN
                    RETURN 1;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF pv_region = 'HK'
        THEN
            /* retreiving cost info for CA*/
            BEGIN
                lv_exists   := NULL;

                SELECT 'X'
                  INTO lv_exists
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --  mtl_system_items_b msib                                    --commented by BT Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qll.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qll.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'Retail Hong Kong Replenishment'
                       AND msib.inventory_item_id = pn_item_id
                       --                                    and  msib.segment1 =  pv_style
                       --                                    and  msib.segment2 =  pv_color
                       --                                    and  msib.segment3 =  pv_size
                       AND ROWNUM <= 1;

                IF lv_exists IS NOT NULL
                THEN
                    RETURN 1;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF pv_region = 'JP'
        THEN
            /* retreiving cost info for JP*/
            BEGIN
                lv_exists   := NULL;

                SELECT 'X'
                  INTO lv_exists
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       --  mtl_system_items_b msib                                    --commented by BT Team on 09/12/2014
                       xxd_common_items_v msib --Added by BT Team on 09/12/2014
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       /*
                                          AND msib.enabled_flag = 'Y'
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            msib.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (
                                                                            msib.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qlh.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qlh.end_date_active),
                                                                         TRUNC (SYSDATE))
                                          AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                         TRUNC (
                                                                            qll.start_date_active),
                                                                         TRUNC (SYSDATE))
                                                                  AND NVL (
                                                                         TRUNC (qll.end_date_active),
                                                                         TRUNC (SYSDATE))
                       */
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'Japan Retail Replenishment JPY'
                       AND msib.inventory_item_id = pn_item_id
                       --                                    and msib.segment1 = pv_style
                       --                                    and msib.segment2 = pv_color
                       --                                    and msib.segment3 = pv_size
                       AND ROWNUM <= 1;

                IF lv_exists IS NOT NULL
                THEN
                    RETURN 1;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    BEGIN
                        lv_exists   := NULL;

                        SELECT 'X'
                          INTO lv_exists
                          FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                               mtl_categories_b mc, --mtl_category_sets mcs,
                                                    mtl_item_categories mic, --mtl_system_items_b msib                          --commented by BT Tech Team on 09/12/2014
                                                                             xxd_common_items_v msib --added by BT Team on 09/12/2014
                         WHERE     qpa.list_line_id = qll.list_line_id
                               AND qll.list_header_id = qlh.list_header_id
                               AND mic.inventory_item_id =
                                   msib.inventory_item_id
                               AND mic.organization_id = msib.organization_id
                               --    and mc.structure_id   = mcs.structure_id
                               AND qpa.product_attribute =
                                   'PRICING_ATTRIBUTE2'
                               AND qpa.product_attr_value = mc.category_id
                               --    and qpa.product_attr_value = mc.category_id
                               --and qpa.product_attr_value = to_char(mc.category_id)
                               AND mic.category_id = mc.category_id
                               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               /*
                                                        AND msib.enabled_flag = 'Y'
                                                        AND TRUNC (SYSDATE) BETWEEN NVL (
                                                                                       TRUNC (
                                                                                          msib.start_date_active),
                                                                                       TRUNC (SYSDATE))
                                                                                AND NVL (
                                                                                       TRUNC (
                                                                                          msib.end_date_active),
                                                                                       TRUNC (SYSDATE))
                               */
                               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               TRUNC (
                                                                   qlh.start_date_active),
                                                               TRUNC (
                                                                   SYSDATE))
                                                       AND NVL (
                                                               TRUNC (
                                                                   qlh.end_date_active),
                                                               TRUNC (
                                                                   SYSDATE))
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               TRUNC (
                                                                   qll.start_date_active),
                                                               TRUNC (
                                                                   SYSDATE))
                                                       AND NVL (
                                                               TRUNC (
                                                                   qll.end_date_active),
                                                               TRUNC (
                                                                   SYSDATE))
                               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               --AND mc.structure_id = 50202
                               AND mc.structure_id =
                                   (SELECT structure_id
                                      FROM mtl_category_sets
                                     --WHERE category_set_name = 'Styles')
                                     WHERE category_set_name =
                                           'OM Sales Category')
                               -- Added by Sreenath BT
                               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               --  and mic.category_set_id = mcs.category_set_id
                               --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               /* AND msib.organization_id =
                                         (SELECT organization_id
                                            FROM org_organization_definitions
                                           WHERE organization_name = 'MST_Deckers_Item_Master')*/
                               --commented by BT Technology Team on 09/12/2014
                               --AND msib.organization_id = 7
                               AND msib.organization_id IN
                                       (SELECT ood.ORGANIZATION_ID
                                          FROM fnd_lookup_values flv, org_organization_definitions ood
                                         WHERE     lookup_type =
                                                   'XXD_1206_INV_ORG_MAPPING'
                                               AND lookup_code = 7
                                               AND flv.attribute1 =
                                                   ood.ORGANIZATION_CODE
                                               AND language =
                                                   USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                               --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                               --and msib.inventory_item_status_code = 'Active'
                               AND qpa.product_attribute_context = 'ITEM'
                               AND qlh.NAME =
                                   'Japan Retail Replenishment JPY'
                               AND msib.inventory_item_id = pn_item_id
                               --   and mcs.category_set_name='Styles'
                               --                                and msib.segment1 = pv_style
                               --                                and msib.segment2 = pv_color
                               --                                and msib.segment3  = pv_size
                               AND ROWNUM <= 1;

                        IF lv_exists IS NOT NULL
                        THEN
                            RETURN 1;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            RETURN 0;
                    END;
            END;
        ELSIF pv_region = 'CN'
        THEN
            /* retreiving cost info for CN */
            BEGIN
                lv_exists   := NULL;

                SELECT 'X'
                  INTO lv_exists
                  FROM qp_pricing_attributes qpa, qp_list_lines qll, qp_list_headers qlh,
                       mtl_system_items_b msib
                 WHERE     qpa.list_line_id = qll.list_line_id
                       AND qll.list_header_id = qlh.list_header_id
                       AND qpa.product_attribute = 'PRICING_ATTRIBUTE1'
                       AND qpa.product_attr_value = msib.inventory_item_id
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       /* AND msib.organization_id =
                                 (SELECT organization_id
                                    FROM org_organization_definitions
                                   WHERE organization_name = 'MST_Deckers_Item_Master')*/
                       --commented by BT Technology Team on 09/12/2014
                       --AND msib.organization_id = 7
                       AND msib.organization_id IN
                               (SELECT ood.ORGANIZATION_ID
                                  FROM fnd_lookup_values flv, org_organization_definitions ood
                                 WHERE     lookup_type =
                                           'XXD_1206_INV_ORG_MAPPING'
                                       AND lookup_code = 7
                                       AND flv.attribute1 =
                                           ood.ORGANIZATION_CODE
                                       AND language = USERENV ('LANG')) --added by BT Technology TEam on 09/12/2014
                       AND msib.enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       TRUNC (
                                                           msib.start_date_active),
                                                       TRUNC (SYSDATE))
                                               AND NVL (
                                                       TRUNC (
                                                           msib.end_date_active),
                                                       TRUNC (SYSDATE))
                       --Start changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       TRUNC (
                                                           qlh.start_date_active),
                                                       TRUNC (SYSDATE))
                                               AND NVL (
                                                       TRUNC (
                                                           qlh.end_date_active),
                                                       TRUNC (SYSDATE))
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       TRUNC (
                                                           qll.start_date_active),
                                                       TRUNC (SYSDATE))
                                               AND NVL (
                                                       TRUNC (
                                                           qll.end_date_active),
                                                       TRUNC (SYSDATE))
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --End changes by BT Technology for BT on 22-JUL-2014,  v1.0
                       --and msib.inventory_item_status_code = 'Active'
                       AND qpa.product_attribute_context = 'ITEM'
                       AND qlh.NAME = 'Retail China Replenishment'
                       AND msib.inventory_item_id = pn_item_id
                       --                                    and  msib.segment1 =  pv_style
                       --                                    and  msib.segment2 =  pv_color
                       --                                    and  msib.segment3 =  pv_size
                       AND ROWNUM <= 1;

                IF lv_exists IS NOT NULL
                THEN
                    RETURN 1;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'EXCEPTION 1 - error occured while retreiving base cost for CN'
                        || SQLERRM);
            END;
        END IF;
    END;

    FUNCTION get_ebs_gender_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
        DETERMINISTIC
    IS
        ln_item_id        NUMBER;
        ln_style_cat_id   NUMBER;
        ln_inv_cat_id     NUMBER;
        lv_subgrp_cat     VARCHAR2 (200);
        ln_gender         VARCHAR2 (1000);
    BEGIN
        /* Retreiving category id for inventory_category_set for  given item*/
        BEGIN
            ln_gender   := NULL;

            /* SELECT mc.segment3                                                    --commented by BT Team -START
               INTO ln_gender
               FROM mtl_item_categories mic,
                    mtl_categories mc,
                    mtl_category_sets mcs
              WHERE mic.category_set_id = mcs.category_set_id
                AND mic.category_id = mc.category_id
                AND mc.structure_id = mcs.structure_id
                AND mcs.category_set_name = 'Inventory'
                AND mic.inventory_item_id = pn_item_id
                AND mic.organization_id = pn_org_id;*/
            --commented by BT Team -END
            SELECT mic.division
              INTO ln_gender
              FROM xxd_common_items_v mic
             WHERE     mic.organization_id = pn_org_id
                   AND mic.inventory_item_id = pn_item_id; --Added by BT Team om 09/12/2014
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_gender   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 2 - error occure while retreiving Subgroup value '
                    || SQLERRM);
        END;

        RETURN ln_gender;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_gender   := NULL;
            fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 2 - ' || SQLERRM);
            RETURN ln_gender;
    END;

    FUNCTION get_ebs_class_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
        DETERMINISTIC
    IS
        ln_item_id        NUMBER;
        ln_style_cat_id   NUMBER;
        ln_inv_cat_id     NUMBER;
        ln_class          VARCHAR2 (200);
    BEGIN
        /* Retreiving category id for inventory_category_set for  given item*/
        BEGIN
            ln_class   := NULL;

            /*SELECT mc.segment4                                                    --commented by BT Team -START
              INTO ln_class
              FROM mtl_item_categories mic,
                   mtl_categories mc,
                   mtl_category_sets mcs
             WHERE mic.category_set_id = mcs.category_set_id
               AND mic.category_id = mc.category_id
               AND mc.structure_id = mcs.structure_id
               AND mcs.category_set_name = 'Inventory'
               AND mic.inventory_item_id = pn_item_id
               AND mic.organization_id = pn_org_id;*/
            --commented by BT Team -END
            SELECT mic.master_class
              INTO ln_class
              FROM xxd_common_items_v mic
             WHERE     mic.inventory_item_id = pn_item_id
                   AND mic.organization_id = pn_org_id; --Added by BT Team on 09/12/2014
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_class   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'EXCEPTION 2 - error occure while retreiving Subgroup value '
                    || SQLERRM);
        END;

        RETURN ln_class;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_class   := NULL;
            fnd_file.put_line (fnd_file.LOG, 'EXCEPTION 2 - ' || SQLERRM);
            RETURN ln_class;
    END;
END xxdoinv006_pkg;
/
