--
-- XXD_ONT_RETAIL_UTILS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_RETAIL_UTILS_PKG"
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

    gv_package_title   CONSTANT VARCHAR2 (30) := 'XXD_ONT_RETAIL_UTILS_PKG';
    gn_org_id                   NUMBER;
    gn_user_id                  NUMBER;
    gn_login_id                 NUMBER;
    gn_application_id           NUMBER;
    gn_responsibility_id        NUMBER;
    gv_err_flag                 VARCHAR2 (1) DEFAULT 'N';


    PROCEDURE xxd_retail_data (pn_store_id IN NUMBER, pv_virtual_warehouse IN VARCHAR2, pn_customer_id OUT NUMBER, pn_org_seq OUT NUMBER, pn_wh_id OUT NUMBER, pv_orig_id OUT VARCHAR2, pn_orgid OUT NUMBER, pv_shipto OUT VARCHAR2, pv_billto OUT VARCHAR2, pn_ord_type_id OUT NUMBER, pv_ord_type_name OUT VARCHAR2, pv_error_msg OUT VARCHAR2
                               , pv_status OUT VARCHAR2);


    FUNCTION get_order_type (pv_transaction_type_id IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE get_so_header_details (pv_order_source_name IN VARCHAR2, pv_type_code IN VARCHAR2, pv_customer_number IN VARCHAR2, pv_ship_to_location IN VARCHAR2, pv_bill_to_location IN VARCHAR2, pv_deliver_to_location IN VARCHAR2, pv_brand IN VARCHAR2, pv_bookedflag OUT VARCHAR2, pn_ordersourceid OUT NUMBER, pn_ordertypeid OUT NUMBER, pn_customerid OUT NUMBER, pn_ShipToId OUT NUMBER, pn_BillToId OUT NUMBER, pn_locationid OUT NUMBER, pv_vascodes OUT VARCHAR2
                                     , pv_createdby OUT VARCHAR2, pv_error_msg OUT VARCHAR2, pv_status OUT VARCHAR2);

    PROCEDURE get_so_line_details (pv_sku IN VARCHAR2, pv_type_code IN VARCHAR2, pv_curr_code IN VARCHAR2, pv_brand IN VARCHAR2, pn_pricelist IN NUMBER, pn_unit_price IN NUMBER, pn_org_id IN VARCHAR2, pn_itemid OUT NUMBER, pn_UomId OUT NUMBER, pn_linetypeid OUT NUMBER, pn_adjustmentrequired OUT VARCHAR2, pn_adjustheader OUT NUMBER, pn_adjustline OUT NUMBER, pv_adjustType OUT VARCHAR2, pn_listPrice OUT NUMBER
                                   , pn_adjustpercentage OUT NUMBER, pv_error_msg OUT VARCHAR2, pv_status OUT VARCHAR2);
END XXD_ONT_RETAIL_UTILS_PKG;
/


GRANT EXECUTE ON APPS.XXD_ONT_RETAIL_UTILS_PKG TO SOA_INT
/
