--
-- XXD_OM_ODC_US_TRAN_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OM_ODC_US_TRAN_PKG"
AS
    /******************************************************************************************
    NAME           : XXD_OM_ODC_US_TRAN_PKG
    REPORT NAME    : DIRECTSHIP – ODC TO US TRANSACTIONAL VALUE

    REVISIONS:
    Date            Author                  Version     Description
    ----------      ----------              -------     ---------------------------------------------------
    10-JUN-2022     Laltu Sah                 1.0         Intitial Version
    *********************************************************************************************/
    gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    p_order_number           VARCHAR2 (100);
    P_DATE_FROM              VARCHAR2 (100);
    P_DATE_to                VARCHAR2 (100);

    FUNCTION get_email_id
        RETURN VARCHAR2;

    TYPE item_rec IS RECORD
    (
        inventory_item_id    NUMBER,
        order_number         NUMBER,
        cust_po_number       VARCHAR2 (240),
        shipped_quantity     NUMBER
    );

    TYPE rec_insert_rec IS RECORD
    (
        inventory_item_id       NUMBER,
        COMMERCIAL_INVOICE      VARCHAR2 (25),
        PO_NUMBER               VARCHAR2 (140),
        price                   NUMBER,
        PO_RECEIPT_DATE         DATE,
        PO_RECEIVED_LOCATION    VARCHAR2 (100),
        UNITS_RECEIVED          NUMBER,
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

    FUNCTION get_po_receipt_det (p_inventory_item_id   IN VARCHAR2,
                                 p_type                   VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION populate_data_main (p_order_number IN VARCHAR2, P_DATE_FROM VARCHAR2, P_DATE_to VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION after_report_main (p_order_number IN VARCHAR2, P_DATE_FROM VARCHAR2, P_DATE_to VARCHAR2)
        RETURN BOOLEAN;
END xxd_om_odc_us_tran_pkg;
/
