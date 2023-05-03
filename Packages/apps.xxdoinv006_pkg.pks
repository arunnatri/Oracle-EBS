--
-- XXDOINV006_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoinv006_pkg
AS
    /*******************************************************************************
    * Program Name : XXDOINV006_PKG
    * Language     : PL/SQL
    *
    * History      :
    *
    * WHO                    WHAT                     Desc                          WHEN
    * -------------- ---------------------------------------------- ----------------------------
    * BT Technology Team     Ver 1.0                                              17-JUN-2014
    * BT Technology Team     Ver1.1  Added new Function  get_country_code_f   09-MAR-2015
    ********************************************************************************************/

    -- Start of Changes by BT Technology team #V1.1 09/Mar/2015
    FUNCTION get_country_code_f (pv_region VARCHAR2)
        RETURN VARCHAR2;

    -- End of Changes by BT Technology team #V1.1 09/Mar/2015

    FUNCTION get_curr_code_f (pv_region VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_dept_num_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_class_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN NUMBER;

    -- Start modification by BT Technology Team on 01/07/15

    FUNCTION get_sub_class_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN NUMBER;

    -- End modification by BT Technology Team on 01/07/15

    FUNCTION get_vendor_id_f (pv_region VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_round_case_pct_f (pv_style VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_color_flex_value_f (pn_itemid NUMBER, pn_orgid NUMBER)
        RETURN NUMBER;

    FUNCTION get_sup_country_f (pv_region VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_color_flex_id_f (pv_color VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_sub_group_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_sub_group_createdate_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_sub_group_updatedate_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_sub_group_updatedby_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_cost_us_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN NUMBER;

    FUNCTION get_region_cost_f (pv_style VARCHAR2, pv_color VARCHAR2, pv_size VARCHAR2
                                , pv_region VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_region_price_f (pv_style VARCHAR2, pv_color VARCHAR2, pv_size VARCHAR2
                                 , pv_region VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_vertex_tax_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_vertex_createdate_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_vertex_updatedate_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_vertex_updatedby_f (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_item_id_f (pv_style   VARCHAR2,
                            pv_color   VARCHAR2,
                            pv_size    VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_item_status (pv_style              VARCHAR2,
                              pn_inventory_itemid   NUMBER,
                              pn_organization_id    NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_brand_f (pv_style     VARCHAR2,
                          pn_item_id   NUMBER,
                          pn_org_id    NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_uom_conv_f (pn_item_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_region_cost_f (pn_item_id   NUMBER,
                                pn_org_id    NUMBER,
                                pv_region    VARCHAR2)
        RETURN NUMBER;

    FUNCTION GET_EBS_CLASS_F (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
        DETERMINISTIC;

    FUNCTION GET_EBS_GENDER_F (pn_item_id NUMBER, pn_org_id NUMBER)
        RETURN VARCHAR2
        DETERMINISTIC;
END xxdoinv006_pkg;
/
