--
-- XXD_ONT_SO_ACK_PKG  (Package) 
--
--  Dependencies: 
--   HR_OPERATING_UNITS (View)
--   HZ_CUST_ACCOUNTS (Synonym)
--   HZ_CUST_SITE_USES_ALL (Synonym)
--   HZ_LOCATIONS (Synonym)
--   JTF_RS_SALESREPS (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_TRANSACTION_TYPES_TL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_SO_ACK_PKG"
AS
    /***********************************************************************************************
    * Package         : XXD_ONT_SO_ACK_PKG
    * Description     : This package is used for SOA and SOC Reports- US\CA\EMEA
    * Notes           :
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    * Date         Version#      Name                       Description
    *-----------------------------------------------------------------------------------------------
    * 07-NOV-2016  1.0           Viswanathan Pandian        Initial Version for CCR0006637
    * 13-APR-2018  1.1           Aravind Kannuri            Updated for CCR0007072
    * 29-NOV-2018  1.2           Aravind Kannuri            Updated for CCR0007586
    * 20-Jul-2020  1.3           Viswanathan Pandian        Updated for CCR0008411
    * 04-Jun-2021  1.4           Aravind Kannuri            Updated for CCR0009343
    ************************************************************************************************/
    gn_master_org_id       NUMBER;
    gc_where_clause        VARCHAR2 (4000);
    p_org_id               hr_operating_units.organization_id%TYPE;
    p_lang_code            VARCHAR2 (10);
    p_brand                oe_order_headers_all.attribute5%TYPE;
    p_send_email           VARCHAR2 (1);
    p_print_new_orders     VARCHAR2 (1);
    p_open_orders          VARCHAR2 (1);
    --Start Added parameters as per CCR0007586
    p_division_gender      VARCHAR2 (100);
    p_hide_promo_disc      VARCHAR2 (1);
    --End Added parameters as per CCR0007586
    p_cust_account_id      hz_cust_accounts.cust_account_id%TYPE;
    p_order_type_id        oe_transaction_types_tl.transaction_type_id%TYPE;
    p_cust_po_num          oe_order_headers_all.cust_po_number%TYPE;
    p_order_number_from    oe_order_headers_all.order_number%TYPE;
    p_order_number_to      oe_order_headers_all.order_number%TYPE;
    p_booked_status        VARCHAR2 (1);
    p_ordered_date_from    VARCHAR2 (50);
    p_ordered_date_to      VARCHAR2 (50);
    p_request_date_from    VARCHAR2 (50);
    p_request_date_to      VARCHAR2 (50);
    p_sch_ship_date_from   VARCHAR2 (50);
    p_sch_ship_date_to     VARCHAR2 (50);
    p_salesrep_id          jtf_rs_salesreps.salesrep_id%TYPE;
    p_mode                 VARCHAR2 (50);
    p_ship_to_org_id       hz_cust_site_uses_all.site_use_id%TYPE;
    p_ship_to_city         hz_locations.city%TYPE;
    p_valid_param          NUMBER;                     -- Added for CCR0008411
    p_department           VARCHAR2 (100);             -- Added for CCR0009343

    FUNCTION validate_parameters
        RETURN BOOLEAN;

    FUNCTION build_where_clause
        RETURN BOOLEAN;

    FUNCTION lang_code (
        p_site_use_id IN hz_cust_site_uses_all.site_use_id%TYPE)
        RETURN VARCHAR2;

    FUNCTION format_address (
        p_site_use_id IN hz_cust_site_uses_all.site_use_id%TYPE)
        RETURN VARCHAR2;

    FUNCTION get_vat (p_bill_to_site_use_id hz_cust_site_uses_all.site_use_id%TYPE, p_ship_to_site_use_id hz_cust_site_uses_all.site_use_id%TYPE)
        RETURN VARCHAR2;

    FUNCTION get_buyer_group_details (p_cust_account_id IN hz_cust_accounts.cust_account_id%TYPE, p_output_type IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION submit_bursting
        RETURN BOOLEAN;
END xxd_ont_so_ack_pkg;
/
