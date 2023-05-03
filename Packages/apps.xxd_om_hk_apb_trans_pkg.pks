--
-- XXD_OM_HK_APB_TRANS_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   HZ_CUST_SITE_USES_ALL (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OM_HK_APB_TRANS_PKG"
AS
    /*****************************************************************************************
      * Package         : XXD_OM_HK_APB_TRANS_PKG
      * Description     : Package is used for APB to HK Transactional Value Report – Deckers
      * Notes           :
      * Modification    :
      *-------------------------------------------------------------------------------------
      * Date         Version#      Name                       Description
      *-------------------------------------------------------------------------------------
      * 10-JAN-2023  1.0           Aravind Kannuri            Initial Version for CCR0009817
      *
      ****************************************************************************************/

    gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    P_ORDER_NUMBER           VARCHAR2 (100);
    P_PICK_TICKET            VARCHAR2 (100);
    P_DATE_FROM              VARCHAR2 (100);
    P_DATE_to                VARCHAR2 (100);

    TYPE item_rec IS RECORD
    (
        inventory_item_id     NUMBER,
        organization_id       NUMBER,
        order_number          NUMBER,
        customer_number       VARCHAR2 (30),
        customer_name         VARCHAR2 (360),
        ship_to_address       VARCHAR2 (1200),
        pick_ticket_number    NUMBER,
        cust_po_number        VARCHAR2 (240),
        shipped_quantity      NUMBER
    );

    TYPE rec_insert_rec IS RECORD
    (
        inventory_item_id       NUMBER,
        commercial_invoice      VARCHAR2 (25),
        po_number               VARCHAR2 (140),
        price                   NUMBER,
        po_receipt_date         DATE,
        po_received_location    VARCHAR2 (100),
        units_received          NUMBER,
        style_number            VARCHAR2 (240),
        order_number            NUMBER,
        color_code              VARCHAR2 (240),
        cust_po_number          VARCHAR2 (240),
        shipped_quantity        NUMBER,
        organization_code       VARCHAR2 (100),
        item_number             VARCHAR2 (240),
        asn_po_exists_flag      VARCHAR2 (1),
        item_exists_lkp         VARCHAR2 (1),
        item_size               VARCHAR2 (240),
        tot_po_qty              NUMBER
    );

    FUNCTION get_email_id
        RETURN VARCHAR2;

    FUNCTION get_ship_to_address (
        p_site_use_id IN hz_cust_site_uses_all.site_use_id%TYPE)
        RETURN VARCHAR2;

    FUNCTION populate_data_main (p_order_number IN VARCHAR2, p_pick_ticket IN VARCHAR2, p_date_from IN VARCHAR2
                                 , p_date_to IN VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION after_report_main (p_order_number IN VARCHAR2, p_pick_ticket IN VARCHAR2, p_date_from IN VARCHAR2
                                , p_date_to IN VARCHAR2)
        RETURN BOOLEAN;
END XXD_OM_HK_APB_TRANS_PKG;
/
