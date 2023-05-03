--
-- XXDOEC_AR_CUSTOMER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_AR_CUSTOMER_PKG"
AS
    -- =======================================================
    -- Author: Vijay Reddy
    -- Create date: 10/18/2010
    -- Description: This package is used to interface customers
    -- and their addresses from DW to Oracle
    -- =======================================================
    -- Modification History
    -- Modified Date/By/Description:
    -- <Modifying Date, Modifying Author, Change Description>
    -- 07/18/2011, Vijay Reddy, Added Province, email address to address rec
    --
    -- =======================================================
    -- Sample Execution
    -- =======================================================
    TYPE customer_rec_type IS RECORD
    (
        customer_number    VARCHAR2 (30),
        first_name         VARCHAR2 (120),
        middle_name        VARCHAR2 (120),
        last_name          VARCHAR2 (120),
        title              VARCHAR2 (60),
        phone_number       VARCHAR2 (60),
        email_address      VARCHAR2 (120),
        web_site_id        VARCHAR2 (30),
        language           VARCHAR2 (30)
    );

    TYPE address_rec_type IS RECORD
    (
        location_name    VARCHAR2 (40),
        address1         VARCHAR2 (240),
        address2         VARCHAR2 (240),
        address3         VARCHAR2 (240),
        city             VARCHAR2 (60),
        state            VARCHAR2 (60),
        province         VARCHAR2 (60),
        postal_code      VARCHAR2 (60),
        country          VARCHAR2 (60),
        phone_number     VARCHAR2 (60),
        email_address    VARCHAR2 (120)
    );

    PROCEDURE create_cust_account (p_customer_rec IN customer_rec_type, p_created_by_module IN VARCHAR2, x_ret_status OUT VARCHAR2, x_ret_msg_data OUT VARCHAR2, x_cust_account_id OUT NUMBER, x_account_number OUT VARCHAR2
                                   , x_party_id OUT NUMBER, x_party_number OUT VARCHAR2, x_profile_id OUT NUMBER);

    PROCEDURE create_cust_site_use (p_customer_rec IN customer_rec_type, p_bill_to_address_rec IN address_rec_type, p_ship_to_address_rec IN address_rec_type, p_tax_code IN VARCHAR2, p_gl_id_rev IN NUMBER, p_created_by_module IN VARCHAR2 DEFAULT NULL, --BEGIN Flexfields
                                                                                                                                                                                                                                                            p_store_number IN VARCHAR2 DEFAULT NULL, p_dc_number IN VARCHAR2 DEFAULT NULL, p_distro_customer_name IN VARCHAR2 DEFAULT NULL, p_ec_non_ec_country IN VARCHAR2 DEFAULT NULL, p_dealer_locator_eligible IN VARCHAR2 DEFAULT NULL, p_sales_region IN VARCHAR2 DEFAULT NULL, p_edi_enabled_flag IN VARCHAR2 DEFAULT NULL, --END Flexfields
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    x_customer_id OUT NUMBER, x_bill_to_site_use_id OUT NUMBER
                                    , x_ship_to_site_use_id OUT NUMBER, x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2);

    PROCEDURE create_customer_addresses (p_customer_number IN VARCHAR2, p_first_name IN VARCHAR2, p_middle_name IN VARCHAR2, p_last_name IN VARCHAR2, p_title IN VARCHAR2, p_phone_number IN VARCHAR2, p_email_address IN VARCHAR2, p_web_site_id IN VARCHAR2, p_language IN VARCHAR2, -- bill to Address
                                                                                                                                                                                                                                                                                       p_bill_to_loc_name IN VARCHAR2, p_bill_to_address1 IN VARCHAR2, p_bill_to_address2 IN VARCHAR2, p_bill_to_address3 IN VARCHAR2, p_bill_to_city IN VARCHAR2, p_bill_to_state IN VARCHAR2, p_bill_to_province IN VARCHAR2:= NULL, p_bill_to_postal_code IN VARCHAR2, p_bill_to_country IN VARCHAR2, p_bill_to_phone IN VARCHAR2, p_bill_to_email IN VARCHAR2:= NULL, -- ship to Address
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_ship_to_loc_name IN VARCHAR2, p_ship_to_address1 IN VARCHAR2, p_ship_to_address2 IN VARCHAR2, p_ship_to_address3 IN VARCHAR2, p_ship_to_city IN VARCHAR2, p_ship_to_state IN VARCHAR2, p_ship_to_province IN VARCHAR2:= NULL, p_ship_to_postal_code IN VARCHAR2, p_ship_to_country IN VARCHAR2, p_ship_to_phone IN VARCHAR2, p_ship_to_email IN VARCHAR2:= NULL, p_tax_code IN VARCHAR2, p_gl_id_rev IN NUMBER, p_created_by_module IN VARCHAR2 DEFAULT NULL, --BEGIN Flexfields
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          p_store_number IN VARCHAR2 DEFAULT NULL, p_dc_number IN VARCHAR2 DEFAULT NULL, p_distro_customer_name IN VARCHAR2 DEFAULT NULL, p_ec_non_ec_country IN VARCHAR2 DEFAULT NULL, p_dealer_locator_eligible IN VARCHAR2 DEFAULT NULL, p_sales_region IN VARCHAR2 DEFAULT NULL, p_edi_enabled_flag IN VARCHAR2 DEFAULT NULL, --END Flexfields
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  x_customer_id OUT NUMBER, x_bill_to_site_use_id OUT NUMBER, x_ship_to_site_use_id OUT NUMBER, x_return_status OUT VARCHAR2
                                         , x_error_text OUT VARCHAR2);

    PROCEDURE update_customer_email (p_customer_number IN VARCHAR2, p_new_email_address IN VARCHAR2, x_return_status OUT VARCHAR2
                                     , x_return_msg OUT VARCHAR2);
END XXDOEC_AR_CUSTOMER_PKG;
/
