--
-- XXDOEC_ORDER_TESTER  (Package) 
--
--  Dependencies: 
--   HZ_CUST_ACCOUNTS (Synonym)
--   HZ_LOCATIONS (Synonym)
--   HZ_PARTIES (Synonym)
--   STANDARD (Package)
--   XXDOEC_INVENTORY (Table)
--
/* Formatted on 4/26/2023 4:13:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoec_order_tester
AS
    TYPE cust_record IS RECORD
    (
        account_number          VARCHAR2 (150),
        first_name              hz_parties.person_first_name%TYPE,
        last_name               hz_parties.person_last_name%TYPE,
        email_address           hz_parties.email_address%TYPE,
        billing_name            VARCHAR (30),
        billing_address1        hz_locations.address1%TYPE,
        billing_address2        hz_locations.address2%TYPE,
        billing_city            hz_locations.city%TYPE,
        billing_state           hz_locations.state%TYPE,
        bill_province           hz_locations.province%TYPE,
        billing_postal_code     hz_locations.postal_code%TYPE,
        billing_country         hz_locations.country%TYPE,
        shipping_name           VARCHAR (30),
        shipping_address1       hz_locations.address1%TYPE,
        shipping_address2       hz_locations.address2%TYPE,
        shipping_city           hz_locations.city%TYPE,
        shipping_state          hz_locations.state%TYPE,
        shipping_province       hz_locations.province%TYPE,
        shipping_postal_code    hz_locations.postal_code%TYPE,
        shipping_country        hz_locations.country%TYPE,
        website_id              hz_cust_accounts.attribute18%TYPE,
        local_id                hz_cust_accounts.attribute17%TYPE
    );

    TYPE line_item_record IS RECORD
    (
        upc                   xxdo.xxdoec_inventory.upc%TYPE,
        sku                   VARCHAR2 (150),
        cost_per_unit         NUMBER,
        quantity              NUMBER,
        pre_back_order_qty    NUMBER,
        price_list_id         NUMBER,
        description           VARCHAR2 (240)
    );

    TYPE t_cust_records_cursor IS REF CURSOR
        RETURN cust_record;

    TYPE t_line_items_cursor IS REF CURSOR
        RETURN line_item_record;

    PROCEDURE get_customer_records (
        p_max_records       NUMBER,
        o_customers     OUT t_cust_records_cursor);

    PROCEDURE get_customer_records_for_site (p_web_site_id VARCHAR2, p_max_records NUMBER, o_customers OUT t_cust_records_cursor);

    PROCEDURE get_customer_records_by_email (
        p_email_addr       VARCHAR2,
        o_customers    OUT t_cust_records_cursor);

    PROCEDURE get_customer_records_by_id (
        p_customerId       VARCHAR2,
        o_customers    OUT t_cust_records_cursor);

    PROCEDURE get_line_items_by_site (p_site_id VARCHAR2, p_max_records NUMBER, o_line_items OUT t_line_items_cursor);

    PROCEDURE get_line_items_by_site_new (p_site_id VARCHAR2, p_max_records NUMBER, o_line_items OUT t_line_items_cursor
                                          , o_zero_line_items OUT t_line_items_cursor, o_backorder_line_items OUT t_line_items_cursor, o_sale_line_items OUT t_line_items_cursor);

    PROCEDURE get_line_item_by_upc (
        p_upc          IN     VARCHAR2,
        p_site_id      IN     VARCHAR2,
        o_line_items      OUT t_line_items_cursor);

    PROCEDURE get_next_order_number (x_return_number OUT NUMBER);

    PROCEDURE get_next_cust_number (x_return_number OUT NUMBER);

    PROCEDURE get_upc_from_sku (p_sku IN VARCHAR2, x_return_upc OUT VARCHAR);
END;
/
