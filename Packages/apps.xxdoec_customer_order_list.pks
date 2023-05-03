--
-- XXDOEC_CUSTOMER_ORDER_LIST  (Package) 
--
--  Dependencies: 
--   HZ_CUST_ACCOUNTS (Synonym)
--   HZ_CUST_ACCOUNTS_ALL (Synonym)
--   HZ_LOCATIONS (Synonym)
--   HZ_PARTIES (Synonym)
--   MTL_SYSTEM_ITEMS_B (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_ORDER_LINES_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:43 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_CUSTOMER_ORDER_LIST"
AS
    g_error   BOOLEAN := FALSE;

    TYPE customer_list IS RECORD
    (
        customer_number      hz_cust_accounts.account_number%TYPE,
        party_name           hz_parties.party_name%TYPE,
        party_type           hz_parties.party_type%TYPE,
        person_first_name    hz_parties.person_first_name%TYPE,
        person_last_name     hz_parties.person_last_name%TYPE,
        state                hz_locations.state%TYPE,
        postal_code          hz_locations.postal_code%TYPE,
        email_address        hz_parties.email_address%TYPE,
        Phone                hz_parties.primary_phone_number%TYPE,
        Brand                hz_cust_accounts_all.attribute18%TYPE
    );

    TYPE cus_order_detail IS RECORD
    (
        order_number       oe_order_headers_all.orig_sys_document_ref%TYPE,
        ordered_date       oe_order_headers_all.ordered_date%TYPE,
        customer_number    hz_cust_accounts.account_number%TYPE,
        product_name       mtl_system_items_b.description%TYPE,
        line_number        oe_order_lines_all.line_number%TYPE,
        amount             oe_order_lines_all.unit_selling_price%TYPE,
        line_status        oe_order_lines_all.flow_status_code%TYPE,
        state              hz_parties.state%TYPE
    );

    TYPE t_customer_list_cursor IS REF CURSOR
        RETURN customer_list;

    TYPE t_cus_order_detail_cursor IS REF CURSOR
        RETURN cus_order_detail;


    /** commented by AG
    PROCEDURE get_customer_list    ( p_customer_number       IN     VARCHAR2,
                                    p_party_name             IN     VARCHAR2,
                                    p_email_address          IN     VARCHAR2,
                                    p_customer_postal_code   IN     VARCHAR2,
                                    p_customer_state         IN     VARCHAR2,
                                    p_phone_number           IN     VARCHAR2,
                                    o_customer_lst           OUT t_customer_list_cursor);
    ***/

    PROCEDURE get_customer_list (
        p_customer_number        IN     VARCHAR2,
        p_party_name             IN     VARCHAR2,
        p_email_address          IN     VARCHAR2,
        p_customer_postal_code   IN     VARCHAR2,
        p_customer_state         IN     VARCHAR2,
        p_phone_number           IN     VARCHAR2,
        p_rownum                 IN     VARCHAR2,
        o_customer_lst              OUT SYS_REFCURSOR);

    PROCEDURE get_customer_order_lst (
        p_customer_number    IN     VARCHAR2,
        o_cus_order_detail      OUT t_cus_order_detail_cursor);
END XXDOEC_CUSTOMER_ORDER_LIST;
/
