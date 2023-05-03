--
-- XXDOEC_GIFT_CARDS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_GIFT_CARDS_PKG"
AS
    TYPE gift_card_line_rectype IS RECORD
    (
        inventory_org_code       VARCHAR2 (3),
        delivery_id              NUMBER,
        released_status          VARCHAR2 (1),
        actual_shipment_date     DATE,
        order_number             NUMBER,
        creation_date            DATE,
        brand                    VARCHAR2 (240),
        ordered_item             VARCHAR2 (2000),
        item_description         VARCHAR2 (240),
        card_type                VARCHAR2 (40),
        card_sub_type            VARCHAR2 (40),
        ordered_quantity         NUMBER,
        unit_selling_price       NUMBER,
        currency_code            VARCHAR2 (15),
        customer_name            VARCHAR2 (90),
        customer_number          VARCHAR2 (84),
        address1                 VARCHAR2 (240),
        address2                 VARCHAR2 (240),
        address3                 VARCHAR2 (240),
        city                     VARCHAR2 (60),
        state                    VARCHAR2 (60),
        province                 VARCHAR2 (60),
        postal_code              VARCHAR2 (60),
        country                  VARCHAR2 (60),
        web_site_id              VARCHAR2 (150),
        locale                   VARCHAR2 (150),
        shipping_instructions    VARCHAR2 (2000),
        email_address            VARCHAR2 (2000),
        cust_po_number           VARCHAR2 (50),
        delivery_detail_id       NUMBER,
        line_id                  NUMBER,
        header_id                NUMBER
    );

    TYPE gift_card_line_hist_rectype IS RECORD
    (
        inventory_org_code       VARCHAR2 (3),
        delivery_id              NUMBER,
        released_status          VARCHAR2 (1),
        actual_shipment_date     DATE,
        order_number             NUMBER,
        creation_date            DATE,
        brand                    VARCHAR2 (240),
        ordered_item             VARCHAR2 (2000),
        item_description         VARCHAR2 (240),
        card_type                VARCHAR2 (40),
        card_sub_type            VARCHAR2 (40),
        ordered_quantity         NUMBER,
        unit_selling_price       NUMBER,
        currency_code            VARCHAR2 (15),
        customer_name            VARCHAR2 (90),
        customer_number          VARCHAR2 (84),
        address1                 VARCHAR2 (240),
        address2                 VARCHAR2 (240),
        address3                 VARCHAR2 (240),
        city                     VARCHAR2 (60),
        state                    VARCHAR2 (60),
        province                 VARCHAR2 (60),
        postal_code              VARCHAR2 (60),
        country                  VARCHAR2 (60),
        web_site_id              VARCHAR2 (150),
        locale                   VARCHAR2 (150),
        shipping_instructions    VARCHAR2 (2000),
        email_address            VARCHAR2 (2000)
    );

    TYPE gift_card_line_cur IS REF CURSOR
        RETURN gift_card_line_rectype;

    TYPE gift_card_line_hist_cur IS REF CURSOR
        RETURN gift_card_line_hist_rectype;

    PROCEDURE get_gift_card_lines (pv_inventory_org_code IN VARCHAR2, pv_card_type IN VARCHAR2, pv_card_sub_type IN VARCHAR2
                                   , p_gift_card_line_cur OUT gift_card_line_cur, x_rtn_status OUT VARCHAR2, x_rtn_msg_data OUT VARCHAR2);

    PROCEDURE get_gift_card_lines_history (pv_inventory_org_code IN VARCHAR2, pv_card_type IN VARCHAR2, pv_card_sub_type IN VARCHAR2, pv_start_date IN DATE, p_gift_card_line_cur OUT gift_card_line_hist_cur, x_rtn_status OUT VARCHAR2
                                           , x_rtn_msg_data OUT VARCHAR2);

    PROCEDURE get_gift_card_line_detail (pn_delivery_id IN NUMBER, p_gift_card_line_cur OUT gift_card_line_cur, x_rtn_status OUT VARCHAR2
                                         , x_rtn_msg_data OUT VARCHAR2);
END xxdoec_gift_cards_pkg;
/
