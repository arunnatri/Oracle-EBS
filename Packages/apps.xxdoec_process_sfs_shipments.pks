--
-- XXDOEC_PROCESS_SFS_SHIPMENTS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_PROCESS_SFS_SHIPMENTS"
AS
    PROCEDURE receive_po_lines (x_errbuf               OUT VARCHAR2,
                                x_retcode              OUT NUMBER,
                                p_sfs_shipment_id   IN     NUMBER);

    PROCEDURE populate_sfs_shipment_dtls (
        P_WEB_ORDER_NUMBER      IN     VARCHAR2,
        P_LINE_ID               IN     NUMBER,
        P_ITEM_CODE             IN     VARCHAR2,
        P_STATUS                IN     VARCHAR2,
        P_STORE_NUMBER          IN     VARCHAR2,
        P_SHIPPED_DATE          IN     DATE,
        P_SHIPPED_QUANTITY      IN     NUMBER,
        P_UNIT_PRICE            IN     NUMBER,
        P_SHIP_METHOD_CODE      IN     VARCHAR2,
        P_TRACKING_NUMBER       IN     VARCHAR2,
        P_PROCESS_FLAG          IN     VARCHAR2,
        P_ERROR_MESSAGE         IN     VARCHAR2,
        P_PO_LINE_LOCATION_ID   IN     NUMBER,
        P_CREATION_DATE         IN     DATE,
        P_LAST_UPDATE_DATE      IN     DATE,
        X_RTN_STATUS               OUT VARCHAR2,
        X_RTN_MESSAGE              OUT VARCHAR2);
END xxdoec_process_sfs_shipments;
/
