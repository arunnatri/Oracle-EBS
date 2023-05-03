--
-- XXDOEC_PRODUCT_CUSTOMIZATION  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_PRODUCT_CUSTOMIZATION"
AS
    g_application   VARCHAR2 (300) := 'xxdoec_product_customization';

    PROCEDURE insert_ship_confimation (p_order_id            IN     VARCHAR2,
                                       p_currency_code       IN     VARCHAR2,
                                       p_carrier             IN     VARCHAR2,
                                       p_service_level       IN     VARCHAR2,
                                       p_waybill             IN     VARCHAR2,
                                       p_tracking_number     IN     VARCHAR2,
                                       p_status              IN     VARCHAR2,
                                       p_shipped_date        IN     DATE,
                                       p_fluid_recipe_id     IN     VARCHAR2,
                                       p_order_line_number   IN     NUMBER,
                                       p_item_code           IN     VARCHAR2,
                                       p_shipped_quantity    IN     NUMBER,
                                       p_unit_price          IN     NUMBER,
                                       p_item_description    IN     VARCHAR2,
                                       p_sender_id           IN     VARCHAR2,
                                       p_retCode                OUT NUMBER,
                                       p_errBuf                 OUT VARCHAR2);

    PROCEDURE insert_ship_confimation_bulk (p_shipment_data_tbl IN xxdoec_product_customization.shipment_rec_tbl_type, p_retCode OUT NUMBER, p_errBuf OUT VARCHAR2);

    PROCEDURE update_ship_conf_status (p_shipment_id       IN     NUMBER,
                                       p_tracking_number   IN     VARCHAR2,
                                       p_status            IN     VARCHAR2,
                                       p_retCode              OUT NUMBER,
                                       p_errBuf               OUT VARCHAR2);

    TYPE Shipment_Rec_Type IS RECORD
    (
        SHIPMENT_ID             NUMBER,
        ORDER_ID                VARCHAR2 (40 BYTE),
        CURRENCY_CODE           VARCHAR2 (3 BYTE),
        CARRIER                 VARCHAR2 (120 BYTE),
        SERVICE_LEVEL           VARCHAR2 (120 BYTE),
        WAYBILL                 VARCHAR2 (120 BYTE),
        TRACKING_NUMBER         VARCHAR2 (120 BYTE),
        STATUS                  VARCHAR2 (40 BYTE),
        SHIPPED_DATE            DATE,
        FLUID_RECIPE_ID         VARCHAR2 (50 BYTE),
        ORDER_LINE_NUMBER       NUMBER,
        ITEM_CODE               VARCHAR2 (40 BYTE),
        SHIPPED_QUANTITY        NUMBER,
        UNIT_PRICE              NUMBER,
        ITEM_DESCRIPTION        VARCHAR2 (240 BYTE),
        PO_RECEIVED_FLAG        VARCHAR2 (1 BYTE),
        SO_PICK_RELEASE_FLAG    VARCHAR2 (1 BYTE),
        SO_SHIP_CONFIRM_FLAG    VARCHAR2 (1 BYTE),
        PO_INVOICED_FLAG        VARCHAR2 (1 BYTE),
        ERROR_MESSAGE           VARCHAR2 (2000 BYTE),
        PO_LINE_LOCATION_ID     NUMBER,
        SO_DELIVERY_ID          NUMBER,
        SO_LINE_ID              NUMBER,
        SENDER_ID               VARCHAR2 (120 BYTE)
    );


    TYPE shipment_rec_tbl_type IS TABLE OF Shipment_Rec_Type
        INDEX BY BINARY_INTEGER;

    PROCEDURE insert_invoice_data (
        p_sender_id              IN     VARCHAR2,
        p_invoice_number         IN     VARCHAR2,
        p_invoice_date           IN     DATE,
        p_invoice_currency       IN     VARCHAR2,
        p_period_start_date      IN     DATE,
        p_period_end_date        IN     DATE,
        p_total_units_shipped    IN     NUMBER,
        p_total_invoice_amount   IN     NUMBER,
        p_invoice_data_tbl       IN     xxdoec_product_customization.invoice_rec_tbl_type,
        p_retCode                   OUT NUMBER,
        p_errBuf                    OUT VARCHAR2);

    TYPE Invoice_Rec_Type IS RECORD
    (
        INVOICE_ID              NUMBER,
        ORDER_ID                VARCHAR2 (120 BYTE),
        FLUID_RECIPE_ID         VARCHAR (50 BYTE),
        ORDER_LINE_NUMBER       NUMBER,
        ACTUAL_SHIPMENT_DATE    DATE,
        AWB_NUMBER              VARCHAR2 (120 BYTE),
        TRACKING_NUMBER         VARCHAR2 (120 BYTE),
        ITEM_UPC                VARCHAR2 (40 BYTE),
        ITEM_CODE               VARCHAR2 (120 BYTE),
        ITEM_DESCRIPTION        VARCHAR2 (240 BYTE),
        QUANTITY                NUMBER,
        UNIT_COST               NUMBER
    );

    TYPE invoice_rec_tbl_type IS TABLE OF Invoice_Rec_Type
        INDEX BY BINARY_INTEGER;
END xxdoec_product_customization;
/


--
-- XXDOEC_PRODUCT_CUSTOMIZATION  (Synonym) 
--
--  Dependencies: 
--   XXDOEC_PRODUCT_CUSTOMIZATION (Package)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDOEC_PRODUCT_CUSTOMIZATION FOR APPS.XXDOEC_PRODUCT_CUSTOMIZATION
/


GRANT EXECUTE ON APPS.XXDOEC_PRODUCT_CUSTOMIZATION TO SOA_INT
/
