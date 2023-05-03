--
-- XXDO_EDI_UTILS_PUB  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   FND_APPLICATION (Synonym)
--   FND_RESPONSIBILITY (Synonym)
--   FND_USER (Synonym)
--   HZ_CUST_ACCOUNTS (Synonym)
--   OE_HOLD_SOURCES_ALL (Synonym)
--   OE_ORDER_HEADERS (Synonym)
--   WF_EVENT_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_EDI_UTILS_PUB"
    AUTHID DEFINER
AS
    /*********************************************************************************************
      Modification history:
     *********************************************************************************************

        Version        Date           Author                      Description
       ---------   -----------     ------------             ------------------------------------
         1.0                                                    Initial Version.
         1.1       04-Oct-2019     Viswanathan Pandian          Updated for CCR0008173
         1.2       13-Jul-2020     Shivanshu Talwar             EDI Project
         1.3       10-Nov-2020     Viswanathan Pandian          Updated for CCR0009023
      17.0      08-Dec-2021     Shivanshu                    Modified for CCR0009477 - Dxlab ASN
         *********************************************************************************************/

    --  DEFAULTS
    g_miss_num          CONSTANT NUMBER := apps.fnd_api.g_miss_num;
    g_miss_char         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_miss_char;
    g_miss_date         CONSTANT DATE := apps.fnd_api.g_miss_date;

    -- RETURN STATUSES
    g_ret_success       CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_success;
    g_ret_error         CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_error;
    g_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                     := apps.fnd_api.g_ret_sts_unexp_error ;
    g_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    g_ret_init          CONSTANT VARCHAR2 (1) := 'I';

    -- CONCURRENT STATUSES
    g_fnd_normal        CONSTANT VARCHAR2 (20) := 'NORMAL';
    g_fnd_warning       CONSTANT VARCHAR2 (20) := 'WARNING';
    g_fnd_error         CONSTANT VARCHAR2 (20) := 'ERROR';

    FUNCTION isa_id_to_org_id (p_isa_id VARCHAR2)
        RETURN NUMBER;

    FUNCTION isa_id_to_organization_code (p_isa_id VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION organization_code_to_id (p_organization_code VARCHAR2)
        RETURN NUMBER;

    FUNCTION isa_id_to_brand (p_isa_id VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION order_type_name_to_org_id (p_order_type VARCHAR2)
        RETURN NUMBER;

    FUNCTION customer_number_to_customer_id (p_customer_number VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_ship_to_org_id (p_isa_id            VARCHAR2,
                                 p_customer_number   VARCHAR2,
                                 p_store             VARCHAR2:= NULL,
                                 p_dc                VARCHAR2:= NULL,
                                 p_location          VARCHAR2:= NULL)
        RETURN NUMBER;

    FUNCTION get_ship_to_location (p_isa_id            VARCHAR2,
                                   p_customer_number   VARCHAR2,
                                   p_store             VARCHAR2:= NULL,
                                   p_dc                VARCHAR2:= NULL,
                                   p_location          VARCHAR2:= NULL)
        RETURN VARCHAR2;

    FUNCTION get_bill_to_org_id (p_isa_id            VARCHAR2,
                                 p_customer_number   VARCHAR2,
                                 p_store             VARCHAR2:= NULL,
                                 p_dc                VARCHAR2:= NULL,
                                 p_location          VARCHAR2:= NULL)
        RETURN NUMBER;

    FUNCTION get_bill_to_location (p_isa_id            VARCHAR2,
                                   p_customer_number   VARCHAR2,
                                   p_store             VARCHAR2:= NULL,
                                   p_dc                VARCHAR2:= NULL,
                                   p_location          VARCHAR2:= NULL)
        RETURN VARCHAR2;

    FUNCTION site_use_id_to_location (p_customer_number   VARCHAR2,
                                      p_site_uses_id      NUMBER)
        RETURN VARCHAR2;

    FUNCTION location_to_site_use_id (p_brand VARCHAR2, p_customer_number VARCHAR2, p_location VARCHAR2
                                      , p_location_type VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_booked_flag (p_brand             VARCHAR2,
                              p_customer_number   VARCHAR2:= NULL)
        RETURN VARCHAR2;

    FUNCTION get_order_class (p_isa_id VARCHAR2, p_customer_number VARCHAR2:= NULL, p_request_date DATE:= NULL)
        RETURN VARCHAR2;

    FUNCTION get_kco_header_id (p_brand VARCHAR2, p_customer_number VARCHAR2, p_department VARCHAR2:= NULL, p_first_item_id NUMBER:= NULL, p_store VARCHAR2:= NULL, p_dc VARCHAR2:= NULL
                                , p_location VARCHAR2:= NULL)
        RETURN NUMBER;

    FUNCTION get_created_by (p_brand             VARCHAR2:= NULL,
                             p_customer_number   VARCHAR2:= NULL)
        RETURN NUMBER;

    FUNCTION get_updated_by (p_brand             VARCHAR2:= NULL,
                             p_customer_number   VARCHAR2:= NULL)
        RETURN NUMBER;

    /* Since shipping and packing instruction will be populated based on the setup so commenting this code
    function get_shipping_instructions (p_isa_id varchar2
                                      , p_customer_number varchar2
                                       ) return varchar2;
    function get_packing_instructions (p_isa_id varchar2
                                     , p_customer_number varchar2
                                      ) return varchar2;
    */
    FUNCTION get_conversion_type_code (p_brand           VARCHAR2,
                                       p_currency_code   VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION upc_to_sku (p_upc_code VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION buyer_item_to_sku (p_customer_number   VARCHAR2,
                                p_buyer_item        VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_sku_cross_reference (p_customer_number VARCHAR2, p_upc_code VARCHAR2:= NULL, p_buyer_item VARCHAR2:= NULL
                                      , p_brand VARCHAR2:= NULL)
        RETURN VARCHAR2;

    PROCEDURE edi_invoice_trigger (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t);

    FUNCTION edi_order_book_event (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2;

    FUNCTION edi_order_prchold_amznsplit (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2; --Added Another Subscription for Order Booked Business Event

    FUNCTION edi_dock_door_closed_event (
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2;

    FUNCTION xxd_shopify_asn_event (                     -- added w CCR0009477
        p_subscription_guid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2;

    FUNCTION get_order_type_name (p_isa_id            VARCHAR2,
                                  p_customer_number   VARCHAR2,
                                  p_store             VARCHAR2:= NULL,
                                  p_dc                VARCHAR2:= NULL,
                                  p_location          VARCHAR2:= NULL)
        RETURN VARCHAR2;

    FUNCTION order_type_name_to_id (p_order_type VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_price_list_id (p_brand VARCHAR2, p_order_type_name VARCHAR2, p_ordered_date VARCHAR2
                                , p_request_date VARCHAR2)
        RETURN NUMBER;

    PROCEDURE get_adj_details (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2, p_unit_price IN NUMBER, x_list_header_id OUT NUMBER, x_list_line_id OUT NUMBER
                               , x_line_type_code OUT VARCHAR2, x_percentage OUT NUMBER, x_list_price OUT NUMBER);

    FUNCTION adj_required (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                           , p_unit_price IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_adj_list_header_id (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                                     , p_unit_price IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_adj_list_line_id (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                                   , p_unit_price IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_adj_line_type_code (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                                     , p_unit_price IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_adj_percentage (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                                 , p_unit_price IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_list_price (p_brand IN VARCHAR2, p_order_type_name IN VARCHAR2, p_currency IN VARCHAR2, p_ordered_date IN VARCHAR2, p_request_date IN VARCHAR2, p_sku IN VARCHAR2
                             , p_unit_price IN NUMBER)
        RETURN NUMBER;

    --procedure default_hsoe_headers(p_document_ref in varchar2);

    -- Function to fetch concatenated VAS codes of the customer -- Added by Lakshmi BTDEV Team on 10-FEB-2015
    FUNCTION get_vas_codes (
        p_cust_number hz_cust_accounts.account_number%TYPE)
        RETURN VARCHAR2;

    -- Start by Infosys 19-FEB-2015
    FUNCTION xxdo_oe_apply_hold (p_hold_id oe_hold_sources_all.hold_id%TYPE, p_header_id oe_order_headers.header_id%TYPE, p_user_id fnd_user.user_id%TYPE:= 0
                                 , p_resp_id fnd_responsibility.responsibility_id%TYPE:= 0, p_appl_id fnd_application.application_id%TYPE:= 0)
        RETURN NUMBER;

    -- End Infosys 19-FEB-2015
    -- Start changes for CCR0008173
    FUNCTION jp_get_order_type_id (p_additional_info IN VARCHAR2)
        RETURN NUMBER;

    -- End changes for CCR0008173

    --Start W.r.t Version 1.2
    FUNCTION check_sps_customer (p_customer_number IN VARCHAR2)
        RETURN VARCHAR2;

    --End W.r.t Version 1.2
    -- Start changes for CCR0009023
    FUNCTION get_bill_to_site_id (p_customer_number IN VARCHAR2, p_org_id IN NUMBER, p_store_number IN VARCHAR2)
        RETURN NUMBER;
-- End changes for CCR0009023
END xxdo_edi_utils_pub;
/


--
-- XXDO_EDI_UTILS_PUB  (Synonym) 
--
--  Dependencies: 
--   XXDO_EDI_UTILS_PUB (Package)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDO_EDI_UTILS_PUB FOR APPS.XXDO_EDI_UTILS_PUB
/


GRANT EXECUTE ON APPS.XXDO_EDI_UTILS_PUB TO SOA_INT
/
