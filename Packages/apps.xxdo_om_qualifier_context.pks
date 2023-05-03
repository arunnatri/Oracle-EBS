--
-- XXDO_OM_QUALIFIER_CONTEXT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_OM_QUALIFIER_CONTEXT"
AS
    /*----------------------------------------------------------------------------------------------------------------------*/
    /* Ver No     Developer                                Date                             Description                     */
    /*                                                                                                                      */
    /*----------------------------------------------------------------------------------------------------------------------*/
    /* 1.0            BT Technology Team        28-Oct-2014               Used in OraclePricing attribute mapping           */
    /* 1.1            BT Dev Team               25-Jul-2016               Post go live code change                          */
    /* 1.2            Mithun Mathew             6-Jun-2017                CCR0006406 State derivation from Ship-To/Bill-To  */
    /* 1.3            Viswanathan Pandian       06-Sep-2017               CCR0006622 Hoka Program $3 Freight Charge         */
    /* 1.4            Aravind Kannuri           26-Jan-2018               CCR0006849 Added 4 Functions for Promotion Apply  */
    /************************************************************************************************************************/
    FUNCTION get_brand (l_line_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_gender (l_line_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_product_group (l_line_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_product_class (l_line_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_sub_class (l_line_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_master_style (l_line_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_sub_style (l_line_id NUMBER)
        RETURN VARCHAR2;

    -- Start Code change on 25-Jul-2016
    FUNCTION get_style_number (l_line_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_color_code (l_line_id NUMBER)
        RETURN VARCHAR2;

    -- End Code change on 25-Jul-2016
    FUNCTION get_hdr_shipto_state (p_ship_to_org_id NUMBER)
        RETURN VARCHAR2;                                  -- Added for ver 1.2

    FUNCTION get_hdr_billto_state (p_invoice_to_org_id NUMBER)
        RETURN VARCHAR2;                                  -- Added for ver 1.2

    -- Start changes for CCR0006622
    FUNCTION get_order_type_incl
        RETURN VARCHAR2;

    FUNCTION get_ship_to_incl
        RETURN VARCHAR2;

    -- End changes for CCR0006622

    -- Start changes for CCR0006849
    FUNCTION get_customer_spring_tier (p_cust_acct_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_customer_fall_tier (p_cust_acct_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_customer_future1_tier (p_cust_acct_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_customer_future2_tier (p_cust_acct_id NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_distribution_channel (p_cust_acct_id NUMBER)
        RETURN VARCHAR2;
-- End changes for CCR0006849

END xxdo_om_qualifier_context;
/
