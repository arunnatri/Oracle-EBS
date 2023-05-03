--
-- XXDO_WMS_INVENTORY_CONVERSION  (Package) 
--
--  Dependencies: 
--   MTL_TRANSACTIONS_INTERFACE (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_WMS_INVENTORY_CONVERSION"
AS
    /******************************************************************************************
    -- Modification History:
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 05-NOV-2017  1.0        Krishna Lavu            Initial Version
    ******************************************************************************************/

    PROCEDURE extract_main (pv_errbuf           OUT VARCHAR2,
                            pv_retcode          OUT VARCHAR2,
                            pv_brand         IN     VARCHAR2,
                            pv_src_org       IN     NUMBER,
                            pv_src_subinv    IN     VARCHAR2,
                            pv_src_locator   IN     VARCHAR2,
                            pv_dest_org      IN     NUMBER,
                            pv_dest_subinv   IN     VARCHAR2);

    FUNCTION validate_data (pv_brand         IN VARCHAR2,
                            pn_src_org_id    IN NUMBER,
                            pn_dest_org_id   IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE onhand_insert (pn_src_org_id    IN NUMBER,
                             pv_src_subinv    IN VARCHAR2,
                             pv_src_locator   IN VARCHAR2,
                             pn_dest_org_id   IN NUMBER,
                             pv_dest_subinv   IN VARCHAR2);

    PROCEDURE onhand_extract (pn_src_org_id    IN NUMBER,
                              pv_src_subinv    IN VARCHAR2,
                              pv_src_locator   IN VARCHAR2,
                              pn_dest_org_id   IN NUMBER,
                              pv_dest_subinv   IN VARCHAR2);

    PROCEDURE pack_unpack_lpn (pn_src_org_id IN NUMBER, pv_src_subinventory IN VARCHAR2, pv_src_locator IN VARCHAR2);

    PROCEDURE insert_mti_record (p_mti_rec IN MTL_TRANSACTIONS_INTERFACE%ROWTYPE, p_return_status OUT VARCHAR2);

    PROCEDURE process_transaction (p_transaction_header_id IN NUMBER, p_return_status OUT VARCHAR2, pv_error_message OUT VARCHAR2);

    PROCEDURE create_internal_requisition (pn_src_org_id    IN NUMBER,
                                           pv_src_subinv    IN VARCHAR2,
                                           pv_src_locator   IN VARCHAR2,
                                           pn_dest_org_id   IN NUMBER,
                                           pv_dest_subinv   IN VARCHAR2);

    PROCEDURE receive_shipment (pv_errbuf            OUT VARCHAR2,
                                pv_retcode           OUT VARCHAR2,
                                pv_shipment_num   IN     VARCHAR2,
                                pv_org            IN     NUMBER,
                                pv_dest_subinv    IN     VARCHAR2);

    PROCEDURE receive_req_shipment (pv_shipment_num IN VARCHAR2, pv_org IN NUMBER, pv_dest_subinv IN VARCHAR2
                                    , pv_retcode OUT NUMBER);

    PROCEDURE receive_po_shipment (pv_shipment_num IN VARCHAR2, pv_org IN NUMBER, pv_dest_subinv IN VARCHAR2
                                   , pv_retcode OUT NUMBER);

    PROCEDURE create_asn_requisition (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_asn_number IN VARCHAR2, pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pn_dest_org_id IN NUMBER
                                      , pv_dest_subinv IN VARCHAR2);
END XXDO_WMS_INVENTORY_CONVERSION;
/
