--
-- XXDOEC_RETURNS_EXCHANGES_PKG  (Package) 
--
--  Dependencies: 
--   XXDOEC_LINE_TBL_TYPE (Type)
--   XXDOEC_RETURN_LINE_TBL_TYPE (Type)
--   STANDARD (Package)
--   XXDOEC_RETURN_HEADER_STAGING (Table)
--
/* Formatted on 4/26/2023 4:13:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_RETURNS_EXCHANGES_PKG"
AS
    -- =======================================================
    -- Author:      Vijay Reddy
    -- Create date: 07/18/2011
    -- Description: This package is used to interface customer
    --              Returns and exchanges to Oracle
    -- =======================================================
    -- Modification History
    -- Modified Date/By/Description:
    -- <Modifying Date, Modifying Author, Change Description>
    -- 10/21/2011   Vijay Reddy    Added add_store_credit procedure
    --                             Added Multi Line Order procedure
    -- 04/15/2014   Robert McCarter Added p_return_operator parameter to returns creation
    -- 11/25/2014   1.0     Infosys Modified for BT
    -- 01/18/2018   1.1 Vijay Reddy CCR0006939 - Receive into Intransit Locators based on Return Source
    -- 20/08/2018   2.0 Vijay Reddy CCR0007457 - Modify Return Order creation to accept warehouse from DOMS
    -- 24/10/2018   2.1  Vijay Reddy    CCR0007571 - Modify create multi line return to consume UPC on DW returns
    -- 21/06/2019   2.2  Vijay Reddy    CCR0008008 - Modify Create multi line order to accept price list id from DOMS
    -- =======================================================
    -- Sample Execution
    -- =======================================================

    TYPE rtn_item_rec_type IS RECORD
    (
        p_returned_item_upc     VARCHAR2 (40),
        p_orig_order_line_id    NUMBER
    );

    TYPE rtn_item_tbl_type IS TABLE OF rtn_item_rec_type
        INDEX BY BINARY_INTEGER;

    G_APPLICATION   VARCHAR2 (300) := 'xxdo.xxdoec_returns_exchanges_pkg';

    -- CCR0006939 Start
    PROCEDURE populate_order_attribute (p_attribute_type IN VARCHAR2, p_attribute_value IN VARCHAR2, p_user_name IN VARCHAR2, p_order_header_id IN NUMBER, p_line_id IN NUMBER, p_creation_date IN DATE
                                        , x_attribute_id OUT NUMBER, x_rtn_status OUT VARCHAR2, x_rtn_msg OUT VARCHAR2);

    -- CCR0006939 end
    PROCEDURE create_return (p_orig_order_line_id IN NUMBER, p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_ship_to_site_use_id IN NUMBER, p_returned_item_upc IN VARCHAR2, p_returned_qty IN NUMBER, p_ship_from_org_id IN NUMBER, -- CCR0007457
                                                                                                                                                                                                                                                 p_price_list_id IN NUMBER, -- CCR0008008
                                                                                                                                                                                                                                                                            p_unit_list_price IN NUMBER, p_unit_selling_price IN NUMBER, p_tax_code IN VARCHAR2, p_tax_date IN DATE, p_tax_value IN NUMBER, p_return_reason_code IN VARCHAR2, p_dam_code IN VARCHAR2, p_factory_code IN VARCHAR2, p_production_code IN VARCHAR2, p_product_received IN VARCHAR2, -- Y/N
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 p_return_type IN VARCHAR2, p_orig_sys_document_ref IN VARCHAR2, p_order_header_id IN OUT NUMBER, p_return_operator IN VARCHAR2 DEFAULT NULL, p_return_source IN VARCHAR2, -- CCR0006939
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           x_order_line_id OUT NUMBER
                             , x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2);

    PROCEDURE create_shipment (p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_ship_to_site_use_id IN NUMBER, p_requested_item_upc IN VARCHAR2, p_ordered_quantity IN NUMBER, p_ship_from_org_id IN NUMBER, p_ship_method_code IN VARCHAR2, p_price_list_id IN NUMBER, -- CCR0008008
                                                                                                                                                                                                                                                                                   p_unit_list_price IN NUMBER, p_unit_selling_price IN NUMBER, p_tax_code IN VARCHAR2, p_tax_date IN DATE, p_tax_value IN NUMBER, p_sfs_flag IN VARCHAR2, p_fluid_recipe_id IN VARCHAR2, p_order_type IN VARCHAR2, p_orig_sys_document_ref IN VARCHAR2, p_order_header_id IN OUT NUMBER, x_order_line_id OUT NUMBER, x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2
                               , x_error_msg OUT VARCHAR2);

    PROCEDURE create_exchange (p_orig_order_line_id IN NUMBER, p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_ship_to_site_use_id IN NUMBER, p_returned_item_upc IN VARCHAR2, p_returned_qty IN NUMBER, p_return_reason_code IN VARCHAR2, p_dam_code IN VARCHAR2, p_factory_code IN VARCHAR2, p_production_code IN VARCHAR2, p_product_received IN VARCHAR2, -- Y/N
                                                                                                                                                                                                                                                                                                                                                                          p_requested_item_upc IN VARCHAR2, p_requested_qty IN NUMBER, p_ship_from_org_id IN NUMBER, p_ship_method_code IN VARCHAR2, p_exchange_type IN VARCHAR2, p_orig_sys_document_ref IN VARCHAR2, p_return_operator IN VARCHAR2 DEFAULT NULL, p_return_source IN VARCHAR2, -- CCR0006939
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                p_price_list_id IN NUMBER, -- CCR0008008
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           x_order_header_id OUT NUMBER
                               , x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2);

    PROCEDURE create_lost_shipment (p_orig_order_line_id IN NUMBER, p_order_type IN VARCHAR2, p_ship_method_code IN VARCHAR2, p_orig_sys_document_ref IN VARCHAR2, p_order_header_id IN OUT NUMBER, p_return_operator IN VARCHAR2 DEFAULT NULL, x_order_line_id OUT NUMBER, x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2
                                    , x_error_msg OUT VARCHAR2);

    PROCEDURE receive_product (p_order_line_id IN NUMBER, p_returned_qty IN NUMBER, p_subinventory IN VARCHAR2
                               , p_locator_id IN NUMBER, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2);

    PROCEDURE create_multi_line_order (p_do_order_type IN VARCHAR2, p_customer_id IN NUMBER, p_bill_to_site_use_id IN NUMBER, p_ship_to_site_use_id IN NUMBER, p_orig_sys_document_ref IN VARCHAR2, p_line_tbl IN xxdoec_Line_Tbl_Type, p_return_operator IN VARCHAR2 DEFAULT NULL, P_return_source IN VARCHAR2, -- CCR0006939
                                                                                                                                                                                                                                                                                                                 p_price_list_id IN NUMBER, -- CCR0008008
                                                                                                                                                                                                                                                                                                                                            x_order_header_id IN OUT NUMBER, x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2
                                       , x_error_msg OUT VARCHAR2);

    PROCEDURE create_multi_line_return (
        P_ORDER_ID               IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORDER_ID%TYPE,
        P_ORIGINAL_DW_ORDER_ID   IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORIGINAL_DW_ORDER_ID%TYPE,
        --P_ORDER_DATE                  IN XXDO.XXDOEC_RETURN_HEADER_STAGING.ORIGINAL_DW_ORDER_ID%TYPE, -- Commented 1.0
        P_ORDER_DATE             IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORDER_DATE%TYPE, -- Modified 1.0
        P_CURRENCY               IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.CURRENCY%TYPE,
        P_DW_CUSTOMER_ID         IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.DW_CUSTOMER_ID%TYPE,
        P_ORACLE_CUSTOMER_ID     IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORACLE_CUSTOMER_ID%TYPE,
        P_BILL_TO_ADDR_ID        IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.BILL_TO_ADDR_ID%TYPE,
        P_SHIP_TO_ADDR_ID        IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.SHIP_TO_ADDR_ID%TYPE,
        P_ORDER_TOTAL            IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.ORDER_TOTAL%TYPE,
        P_NET_ORDER_TOTAL        IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.NET_ORDER_TOTAL%TYPE,
        P_TOTAL_ORDER_TAX        IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.TOTAL_ORDER_TAX%TYPE,
        P_SITE_ID                IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.SITE_ID%TYPE,
        P_RETURN_TYPE            IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.RETURN_TYPE%TYPE,
        P_XMLPAYLOAD             IN     XXDO.XXDOEC_RETURN_HEADER_STAGING.XMLPAYLOAD%TYPE,
        P_LINE_TBL               IN     APPS.XXDOEC_RETURN_LINE_TBL_TYPE,
        X_STATUS                    OUT VARCHAR2,
        X_ERROR_MSG                 OUT VARCHAR2);

    -- Only used on Retail Exchanges when the exchange shoe line got cancelled due to out of stock
    PROCEDURE add_store_credit (p_order_line_id IN NUMBER, p_order_header_id IN OUT NUMBER, x_order_line_id OUT NUMBER
                                , x_order_number OUT NUMBER, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2);

    PROCEDURE get_next_order_number (x_return_number OUT NUMBER);

    PROCEDURE get_next_cust_number (x_return_number OUT NUMBER);

    PROCEDURE update_rtn_staging_line_status (p_order_number IN VARCHAR2, p_line_id IN NUMBER, p_status IN VARCHAR2);

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I');
END xxdoec_returns_exchanges_pkg;
/
