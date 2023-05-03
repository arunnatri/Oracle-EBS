--
-- XXDOEC_GIFT_CARDS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_GIFT_CARDS_PKG"
AS
    --------------------------------------------------
    -- Get all the gift card lines that need fulfilling for a
    -- particular inventory org.
    --
    -- Author: Lawrence Walters
    -- Created: 7/19/2011
    --
    --------------------------------------------------
    PROCEDURE get_gift_card_lines (pv_inventory_org_code IN VARCHAR2, pv_card_type IN VARCHAR2, pv_card_sub_type IN VARCHAR2
                                   , p_gift_card_line_cur OUT gift_card_line_cur, x_rtn_status OUT VARCHAR2, x_rtn_msg_data OUT VARCHAR2)
    IS
    BEGIN
        x_rtn_status   := fnd_api.g_ret_sts_success;

        OPEN p_gift_card_line_cur FOR
            SELECT inventory_org_code, delivery_id, released_status,
                   actual_shipment_date, order_number, creation_date,
                   brand, ordered_item, item_description,
                   card_type, card_sub_type, ordered_quantity,
                   unit_selling_price, currency_code, customer_name,
                   customer_number, address1, address2,
                   address3, city, state,
                   province, postal_code, country,
                   web_site_id, locale, shipping_instructions,
                   email_address, cust_po_number, delivery_detail_id,
                   line_id, header_id
              FROM xxdoec_card_items_to_fulfill_v
             WHERE     inventory_org_code = pv_inventory_org_code
                   AND card_type = NVL (pv_card_type, card_type)
                   AND card_sub_type = NVL (pv_card_sub_type, card_sub_type);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status     := fnd_api.g_ret_sts_error;
            x_rtn_msg_data   := 'Unable to get gift card lines: ' || SQLERRM;
    END;

    --------------------------------------------------
    -- Get all the gift card lines that need fulfilling for a
    -- particular inventory org.
    --
    -- Author: Lawrence Walters
    -- Created: 7/19/2011
    --
    --------------------------------------------------
    PROCEDURE get_gift_card_lines_history (pv_inventory_org_code IN VARCHAR2, pv_card_type IN VARCHAR2, pv_card_sub_type IN VARCHAR2, pv_start_date IN DATE, p_gift_card_line_cur OUT gift_card_line_hist_cur, x_rtn_status OUT VARCHAR2
                                           , x_rtn_msg_data OUT VARCHAR2)
    IS
    BEGIN
        x_rtn_status   := fnd_api.g_ret_sts_success;

        OPEN p_gift_card_line_cur FOR
            SELECT inventory_org_code, delivery_id, released_status,
                   actual_shipment_date, order_number, creation_date,
                   brand, ordered_item, item_description,
                   card_type, card_sub_type, ordered_quantity,
                   unit_selling_price, currency_code, customer_name,
                   customer_number, address1, address2,
                   address3, city, state,
                   province, postal_code, country,
                   web_site_id, locale, shipping_instructions,
                   email_address
              FROM xxdoec_card_items_history_v
             WHERE     inventory_org_code = pv_inventory_org_code
                   AND creation_date > pv_start_date
                   AND card_type = NVL (pv_card_type, card_type)
                   AND card_sub_type = NVL (pv_card_sub_type, card_sub_type);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status     := fnd_api.g_ret_sts_error;
            x_rtn_msg_data   := 'Unable to get gift card lines: ' || SQLERRM;
    END;

    --------------------------------------------------
    -- Get all the gift card details for a particular
    -- delivery id. Note that a single delivery might
    -- have multiple gift card lines, so that is why
    -- this function returns a cursor instead of a single
    -- record.
    --
    -- Author: Lawrence Walters
    -- Created: 7/19/2011
    --
    --------------------------------------------------
    PROCEDURE get_gift_card_line_detail (pn_delivery_id IN NUMBER, p_gift_card_line_cur OUT gift_card_line_cur, x_rtn_status OUT VARCHAR2
                                         , x_rtn_msg_data OUT VARCHAR2)
    IS
    BEGIN
        x_rtn_status   := fnd_api.g_ret_sts_success;

        OPEN p_gift_card_line_cur FOR SELECT inventory_org_code, delivery_id, released_status,
                                             actual_shipment_date, order_number, creation_date,
                                             brand, ordered_item, item_description,
                                             card_type, card_sub_type, ordered_quantity,
                                             unit_selling_price, currency_code, customer_name,
                                             customer_number, address1, address2,
                                             address3, city, state,
                                             province, postal_code, country,
                                             web_site_id, locale, shipping_instructions,
                                             email_address, cust_po_number, delivery_detail_id,
                                             line_id, header_id
                                        FROM xxdoec_card_items_to_fulfill_v
                                       WHERE delivery_id = pn_delivery_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_rtn_status   := fnd_api.g_ret_sts_error;
            x_rtn_msg_data   :=
                   'Unable to get gift card line details for delivery id: '
                || TO_CHAR (pn_delivery_id)
                || 'Error: '
                || SQLERRM;
    END;
END xxdoec_gift_cards_pkg;
/
