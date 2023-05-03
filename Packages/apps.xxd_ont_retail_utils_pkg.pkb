--
-- XXD_ONT_RETAIL_UTILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_RETAIL_UTILS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_RETAIL_UTILS_PKG
    * Design       : This package will be used for retail Sales Order Integartion
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 05-Mar-2022  1.0        Shivanshu               Initial Version
    -- 06-Jan-2023  1.1        Archana                 CCR Changes CCR0010363
    ******************************************************************************************/


    --Added procedure as part of CCR0010363--
    PROCEDURE xxd_retail_data (pn_store_id IN NUMBER, pv_virtual_warehouse IN VARCHAR2, pn_customer_id OUT NUMBER, pn_org_seq OUT NUMBER, pn_wh_id OUT NUMBER, pv_orig_id OUT VARCHAR2, pn_orgid OUT NUMBER, pv_shipto OUT VARCHAR2, pv_billto OUT VARCHAR2, pn_ord_type_id OUT NUMBER, pv_ord_type_name OUT VARCHAR2, pv_error_msg OUT VARCHAR2
                               , pv_status OUT VARCHAR2)
    AS
        ln_customer_id     NUMBER;
        ln_org_seq         NUMBER;
        ln_wh_id           NUMBER;
        ln_orig_id         VARCHAR2 (100);
        ln_org_id          NUMBER;
        ln_Shipto          VARCHAR2 (30);
        ln_Billto          VARCHAR2 (30);
        ln_ord_type_id     NUMBER;
        lv_ord_type_name   VARCHAR2 (30);
    BEGIN
        pv_status          := 'S';

        BEGIN
            SELECT ra_customer_id
              INTO ln_customer_id
              FROM apps.xxd_retail_stores_v
             WHERE rms_store_id = pn_store_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_customer_id   := NULL;
        END;

        BEGIN
            SELECT apps.xxdo_inv_int_026_seq.NEXTVAL
              INTO ln_org_seq
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_org_seq   := NULL;
        END;

        BEGIN
            SELECT DISTINCT organization
              INTO ln_wh_id
              FROM xxdo.xxdo_ebs_rms_vw_map
             WHERE virtual_warehouse = pv_virtual_warehouse AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_wh_id       := NULL;
                pv_error_msg   := ' Error for WH ID: ' || SQLERRM;
        END;

        BEGIN
            SELECT 'RMS' || '-' || pn_store_id || '-' || ln_wh_id || '-' || ln_org_seq
              INTO ln_orig_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_orig_id     := NULL;
                pv_error_msg   := ' Error for ln_orig_id ' || SQLERRM;
        END;

        BEGIN
            SELECT operating_unit
              INTO ln_org_id
              FROM apps.xxd_retail_stores_v
             WHERE rms_store_id = pn_store_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_org_id      := NULL;
                pv_error_msg   := ' Error for operating_unit ' || SQLERRM;
        END;

        BEGIN
            SELECT a.location
              INTO ln_Shipto
              FROM apps.hz_cust_site_uses_all a, apps.hz_cust_acct_sites_all b, apps.xxd_retail_stores_v c
             WHERE     a.site_use_code = 'SHIP_TO'
                   AND a.org_id = ln_org_id
                   AND a.cust_acct_site_id = b.cust_acct_site_id
                   AND c.ra_customer_id = b.cust_account_id
                   AND a.primary_flag = 'Y'
                   AND c.rms_store_id = pn_store_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_Shipto   := NULL;
        END;

        BEGIN
            SELECT a.location
              INTO ln_Billto
              FROM apps.hz_cust_site_uses_all a, apps.hz_cust_acct_sites_all b, apps.xxd_retail_stores_v c
             WHERE     a.site_use_code = 'BILL_TO'
                   AND a.org_id = ln_org_id
                   AND a.cust_acct_site_id = b.cust_acct_site_id
                   AND c.ra_customer_id = b.cust_account_id
                   AND a.primary_flag = 'Y'
                   AND c.rms_store_id = pn_store_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_Billto   := NULL;
        END;


        BEGIN
            SELECT apps.xxdo_om_int_026_stg_pkg.fetch_order_type (
                       'SHIP',
                       ln_org_id,
                       pv_virtual_warehouse,
                       pn_store_id)
              INTO ln_ord_type_id
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status        := 'E';
                ln_ord_type_id   := NULL;
                pv_error_msg     :=
                    ' Error while fetching Order Type ID ' || SQLERRM;
        END;

        BEGIN
            SELECT name
              INTO lv_ord_type_name
              FROM apps.oe_transaction_types_tl
             WHERE language = 'US' AND transaction_type_id = ln_ord_type_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status          := 'E';
                lv_ord_type_name   := NULL;
                pv_error_msg       :=
                    ' Error while fetching Order Type Name  ' || SQLERRM;
        END;

        pn_customer_id     := ln_customer_id;
        pn_org_seq         := ln_org_seq;
        pn_wh_id           := ln_wh_id;
        pv_orig_id         := ln_orig_id;
        pn_orgid           := ln_org_id;
        pv_shipto          := ln_Shipto;
        pv_billto          := ln_Billto;
        pn_ord_type_id     := ln_ord_type_id;
        pv_ord_type_name   := lv_ord_type_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            pn_customer_id     := NULL;
            pn_org_seq         := NULL;
            pn_wh_id           := NULL;
            pv_orig_id         := NULL;
            pv_shipto          := NULL;
            pv_billto          := NULL;
            pn_ord_type_id     := NULL;
            pv_ord_type_name   := NULL;
    END xxd_retail_data;

    FUNCTION get_order_type (pv_transaction_type_id IN VARCHAR2)
        RETURN VARCHAR2
    AS
        lv_error_message     VARCHAR2 (1000);
        lv_order_type_name   VARCHAR2 (1000);
    BEGIN
        BEGIN
            SELECT name
              INTO lv_order_type_name
              FROM apps.oe_transaction_types_tl
             WHERE     language = 'US'
                   AND transaction_type_id = pv_transaction_type_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   := 'Order Type Not Found';
        END;


        RETURN lv_order_type_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_error_message   :=
                'Error While getting the header Information' || SQLERRM;
    END;

    PROCEDURE get_so_header_details (pv_order_source_name IN VARCHAR2, pv_type_code IN VARCHAR2, pv_customer_number IN VARCHAR2, pv_ship_to_location IN VARCHAR2, pv_bill_to_location IN VARCHAR2, pv_deliver_to_location IN VARCHAR2, pv_brand IN VARCHAR2, pv_bookedflag OUT VARCHAR2, pn_ordersourceid OUT NUMBER, pn_ordertypeid OUT NUMBER, pn_customerid OUT NUMBER, pn_shiptoid OUT NUMBER, pn_billtoid OUT NUMBER, pn_locationid OUT NUMBER, pv_vascodes OUT VARCHAR2
                                     , pv_createdby OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pv_status OUT VARCHAR2)
    AS
        lv_error_message   VARCHAR2 (1000);
    BEGIN
        pv_status      := 'S';

        BEGIN
            SELECT xxdo_edi_utils_pub.get_booked_flag (pv_brand, pv_customer_number)
              INTO pv_bookedflag
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_bookedflag      := 'Y';
                lv_error_message   := 'Invalid Order Name';
        END;

        BEGIN
            SELECT order_source_id
              INTO pn_ordersourceid
              FROM apps.oe_order_sources
             WHERE name = pv_order_source_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status          := 'E';
                lv_error_message   := 'Invalid Order Name';
        END;

        BEGIN
            SELECT xxdo_edi_utils_pub.order_type_name_to_id (pv_type_code)
              INTO pn_ordertypeid
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   := lv_error_message || 'Invalid Type Code';
        END;


        BEGIN
            SELECT xxdo_edi_utils_pub.customer_number_to_customer_id (pv_customer_number)
              INTO pn_customerid
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status          := 'E';
                lv_error_message   := lv_error_message || 'Invalid Customer';
        END;

        BEGIN
            SELECT xxdo_edi_utils_pub.location_to_site_use_id (pv_brand, pv_customer_number, pv_ship_to_location
                                                               , 'SHIP_TO')
              INTO pn_shiptoid
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status   := 'E';
                lv_error_message   :=
                    lv_error_message || 'Invalid inputs for ship to org id';
        END;

        BEGIN
            SELECT xxdo_edi_utils_pub.location_to_site_use_id (pv_brand, pv_customer_number, pv_bill_to_location
                                                               , 'BILL_TO')
              INTO pn_billtoid
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status   := 'E';
                lv_error_message   :=
                    lv_error_message || 'Invalid bill to org id';
        END;

        BEGIN
            SELECT xxdo_edi_utils_pub.location_to_site_use_id (
                       pv_brand,
                       pv_customer_number,
                       pv_deliver_to_location,
                       'DELIVER_TO')
              INTO pn_locationid
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status   := 'E';
                lv_error_message   :=
                    lv_error_message || 'Invalid deliver to org id';
        END;


        BEGIN
            SELECT xxdo_edi_utils_pub.get_vas_codes (pv_customer_number)
              INTO pv_vascodes
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status   := 'E';
                lv_error_message   :=
                    lv_error_message || 'Invalid customer number';
        END;

        BEGIN
            SELECT xxdo_edi_utils_pub.get_created_by (pv_brand, pv_customer_number)
              INTO pv_createdby
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status   := 'E';
                lv_error_message   :=
                    lv_error_message || 'Invalid input for created by ';
        END;

        pv_error_msg   := lv_error_message;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_error_msg   :=
                'Error While getting the header Information' || SQLERRM;
    END;

    PROCEDURE get_so_line_details (pv_sku IN VARCHAR2, pv_type_code IN VARCHAR2, pv_curr_code IN VARCHAR2, pv_brand IN VARCHAR2, pn_pricelist IN NUMBER, pn_unit_price IN NUMBER, pn_org_id IN VARCHAR2, pn_itemid OUT NUMBER, pn_UomId OUT NUMBER, pn_linetypeid OUT NUMBER, pn_adjustmentrequired OUT VARCHAR2, pn_adjustheader OUT NUMBER, pn_adjustline OUT NUMBER, pv_adjustType OUT VARCHAR2, pn_listPrice OUT NUMBER
                                   , pn_adjustpercentage OUT NUMBER, pv_error_msg OUT VARCHAR2, pv_status OUT VARCHAR2)
    AS
        lv_error_message   VARCHAR2 (2000);
    BEGIN
        pv_status          := 'S';
        lv_error_message   := NULL;

        BEGIN
            SELECT sku_to_iid (pv_sku) INTO pn_itemid FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_status          := 'E';
                lv_error_message   := 'Invalid SKU';
        END;

        BEGIN
            SELECT primary_uom_code
              INTO pn_UomId
              FROM apps.MTL_SYSTEM_ITEMS_b
             WHERE inventory_item_id = pn_itemid AND organization_id = 125;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   := 'Invalid UOM for the inputs';
        END;


        BEGIN
            SELECT transaction_type_id
              INTO pn_linetypeid
              FROM ont.oe_transaction_types_tl
             WHERE language = 'US' AND name = pv_type_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   := lv_error_message || 'Invalid type code';
        END;

        BEGIN
            SELECT apps.xxdoint_om_order_import_utils.adj_required (
                       pv_brand,
                       pn_org_id,
                       pv_curr_code,
                       pn_pricelist,
                       pv_sku,
                       pn_unit_price)
              INTO pn_adjustmentrequired
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'Invalid inputs for adjustmentrequired';
        END;

        BEGIN
            SELECT apps.xxdoint_om_order_import_utils.get_adj_list_header_id (
                       pv_brand,
                       pn_org_id,
                       pv_curr_code,
                       pn_pricelist,
                       pv_sku,
                       pn_unit_price)
              INTO pn_adjustheader
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'Invalid inputs for adjustmentrequired';
        END;

        BEGIN
            SELECT apps.xxdoint_om_order_import_utils.get_adj_list_line_id (
                       pv_brand,
                       pn_org_id,
                       pv_curr_code,
                       pn_pricelist,
                       pv_sku,
                       pn_unit_price)
              INTO pn_adjustline
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    lv_error_message || 'Invalid inputs for adjustline';
        END;

        BEGIN
            SELECT apps.xxdoint_om_order_import_utils.get_adj_line_type_code (
                       pv_brand,
                       pn_org_id,
                       pv_curr_code,
                       pn_pricelist,
                       pv_sku,
                       pn_unit_price)
              INTO pv_adjustType
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    lv_error_message || 'Invalid inputs for adjustType';
        END;

        BEGIN
            SELECT apps.xxdoint_om_order_import_utils.get_list_price (
                       pv_brand,
                       pn_org_id,
                       pv_curr_code,
                       pn_pricelist,
                       pv_sku,
                       pn_unit_price)
              INTO pn_listPrice
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                    lv_error_message || 'Invalid inputs for adjustType';
        END;

        BEGIN
            SELECT apps.xxdoint_om_order_import_utils.get_adj_percentage (
                       pv_brand,
                       pn_org_id,
                       pv_curr_code,
                       pn_pricelist,
                       pv_sku,
                       pn_unit_price)
              INTO pn_adjustpercentage
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                       lv_error_message
                    || 'Invalid inputs for adjust percentage ';
        END;



        pv_error_msg       := lv_error_message;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_status   := 'E';
            pv_error_msg   :=
                'Error While getting the lines Information' || SQLERRM;
    END;
END XXD_ONT_RETAIL_UTILS_PKG;
/


GRANT EXECUTE ON APPS.XXD_ONT_RETAIL_UTILS_PKG TO SOA_INT
/
