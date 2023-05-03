--
-- XXD_ONT_SHIP_CONFIRM_INT_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   HZ_LOCATIONS (Synonym)
--   MTL_TXN_REQUEST_LINES (Synonym)
--   OE_HOLD_SOURCES_ALL (Synonym)
--   OE_ORDER_HEADERS (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   OE_ORDER_LINES (Synonym)
--   OE_ORDER_LINES_ALL (Synonym)
--   WMS_LICENSE_PLATE_NUMBERS (Synonym)
--   WSH_DELIVERY_DETAILS (Synonym)
--   WSH_NEW_DELIVERIES (Synonym)
--   WSH_UTIL_CORE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_SHIP_CONFIRM_INT_PKG"
AS
    /****************************************************************************************
    * Change#      : CCR0007832
    * Package      : XXD_ONT_SHIP_CONFIRM_INT_PKG
    * Description  : This is package for WMS(Highjump) to OM Ship Confirm Interface
    * Notes        :
    * Modification :
    -- ===========  ========    ======================= =====================================
    -- Date         Version#    Name                    Comments
    -- ===========  ========    ======================= =======================================
    -- 15-Apr-2019  1.0         Kranthi Bollam          Initial Version
    -- 11-Mar-2020  1.1         Tejaswi Gangumalla      Updated for CCR CCR0008227
    -- 05-Aug-2022  1.2         Gaurav Joshi            Updated for CCR0010086
    -- ===========  ========    ======================= =======================================
    ******************************************************************************************/

    gn_api_version_number      NUMBER := 1.0;
    gn_user_id                 NUMBER := fnd_global.user_id;
    gn_login_id                NUMBER := fnd_global.login_id;
    gn_request_id              NUMBER := fnd_global.conc_request_id;
    gn_program_id              NUMBER := fnd_global.conc_program_id;
    gn_program_appl_id         NUMBER := fnd_global.prog_appl_id;
    gn_resp_appl_id            NUMBER := fnd_global.resp_appl_id;
    gn_resp_id                 NUMBER := fnd_global.resp_id;
    gn_org_id                  NUMBER := fnd_profile.VALUE ('ORG_ID');
    gv_ship_confirm_msg_type   VARCHAR2 (30) := '720';
    gn_container_item_id       NUMBER := 160489;

    TYPE tabtype_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE g_ids_tab_type IS TABLE OF NUMBER
        INDEX BY VARCHAR2 (100);

    g_inv_ids_tab              g_ids_tab_type;
    g_carrier_ids_tab          g_ids_tab_type;

    TYPE g_delivery_dtl_rec_type
        IS RECORD
    (
        delivery_name              wsh_new_deliveries.name%TYPE,
        delivery_id                wsh_new_deliveries.delivery_id%TYPE,
        header_id                  oe_order_headers_all.header_id%TYPE,
        order_number               oe_order_headers_all.order_number%TYPE,
        line_id                    oe_order_lines_all.line_id%TYPE,
        line_number                oe_order_lines_all.line_number%TYPE,
        ordered_item               oe_order_lines_all.ordered_item%TYPE,
        inventory_item_id          oe_order_lines_all.inventory_item_id%TYPE,
        order_quantity_uom         oe_order_lines_all.order_quantity_uom%TYPE,
        ship_from_org_id           oe_order_lines_all.ship_from_org_id%TYPE,
        ship_from_loc_id           hz_locations.location_id%TYPE,
        invoice_to_org_id          oe_order_lines_all.invoice_to_org_id%TYPE,
        ship_to_org_id             oe_order_lines_all.ship_to_org_id%TYPE,
        ship_to_loc_id             hz_locations.location_id%TYPE,
        requested_quantity         wsh_delivery_details.requested_quantity%TYPE,
        released_status            wsh_delivery_details.released_status%TYPE,
        mo_line_id                 mtl_txn_request_lines.line_id%TYPE,
        transaction_header_id      mtl_txn_request_lines.transaction_header_id%TYPE,
        shipped_quantity           wsh_delivery_details.shipped_quantity%TYPE,
        delivery_detail_id         wsh_delivery_details.delivery_detail_id%TYPE,
        organization_id            wsh_delivery_details.organization_id%TYPE,
        customer_id                wsh_delivery_details.customer_id%TYPE,
        ship_method_code           wsh_delivery_details.ship_method_code%TYPE,
        carton                     wms_license_plate_numbers.license_plate_number%TYPE,
        orig_delivery_detail_id    wsh_delivery_details.delivery_detail_id%TYPE
    );

    TYPE g_delivery_dtl_tab_type IS TABLE OF g_delivery_dtl_rec_type
        INDEX BY BINARY_INTEGER;

    TYPE g_shipment_rec_type IS RECORD
    (
        delivery_detail_id    NUMBER,
        inventory_item_id     NUMBER,
        quantity              NUMBER,
        carton                VARCHAR (60)
    );

    TYPE g_shipments_tab_type IS TABLE OF g_shipment_rec_type
        INDEX BY BINARY_INTEGER;

    TYPE g_hold_source_rec_type IS RECORD
    (
        hold_id             oe_hold_sources_all.hold_id%TYPE,
        hold_entity_code    oe_hold_sources_all.hold_entity_code%TYPE,
        hold_entity_id      oe_hold_sources_all.hold_entity_id%TYPE,
        header_id           oe_order_headers.header_id%TYPE,
        line_id             oe_order_lines.line_id%TYPE,
        hold_type           VARCHAR2 (60),
        hold_name           VARCHAR2 (240)
    );

    TYPE g_hold_source_tbl_type IS TABLE OF g_hold_source_rec_type
        INDEX BY BINARY_INTEGER;

    TYPE g_subinv_xfer_rec_type IS RECORD
    (
        delivery_id          NUMBER,
        organization_id      NUMBER,
        inventory_item_id    NUMBER,
        subinventory         VARCHAR2 (10),
        quantity             NUMBER
    );

    TYPE g_subinv_xfer_tbl_type IS TABLE OF g_subinv_xfer_rec_type
        INDEX BY BINARY_INTEGER;

    PROCEDURE ship_confirm_main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2);


    PROCEDURE purge (pv_errbuf            OUT VARCHAR2,
                     pv_retcode           OUT VARCHAR2,
                     pv_purge_option   IN     VARCHAR2);

    PROCEDURE lock_records (pv_errbuf           OUT VARCHAR2,
                            pv_retcode          OUT VARCHAR2,
                            pv_shipment_no   IN     VARCHAR2);

    PROCEDURE reset_error_records (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2);

    PROCEDURE update_error_records (pv_errbuf             OUT VARCHAR2,
                                    pv_retcode            OUT VARCHAR2,
                                    pv_shipment_no     IN     VARCHAR2,
                                    pv_delivery_no     IN     VARCHAR2,
                                    pv_carton_no       IN     VARCHAR2,
                                    pv_line_no         IN     VARCHAR2,
                                    pv_item_number     IN     VARCHAR2,
                                    pv_error_level     IN     VARCHAR2,
                                    pv_error_message   IN     VARCHAR2,
                                    pv_status          IN     VARCHAR2,
                                    pv_source          IN     VARCHAR2);

    PROCEDURE pick_line (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_mo_line_id IN NUMBER
                         , pn_txn_hdr_id IN NUMBER);

    PROCEDURE create_trip (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_trip IN VARCHAR2, pv_carrier IN VARCHAR2, pn_carrier_id IN NUMBER, pv_ship_method_code IN VARCHAR2, -- Added by Krishna
                                                                                                                                                                                   pv_vehicle_number IN VARCHAR2, pv_mode_of_transport IN VARCHAR2, pv_master_bol_number IN VARCHAR2
                           , xn_trip_id OUT NUMBER);

    PROCEDURE create_stop (pv_errbuf                OUT VARCHAR2,
                           pv_retcode               OUT VARCHAR2,
                           pv_ship_type          IN     VARCHAR2,
                           pn_trip_id            IN     VARCHAR2,
                           pn_stop_seq           IN     NUMBER,
                           pn_stop_location_id   IN     VARCHAR2,
                           pv_dep_seal_code      IN     VARCHAR2,
                           xn_stop_id               OUT NUMBER);

    PROCEDURE generate_error_report (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2
                                     , pn_request_id IN NUMBER);

    PROCEDURE shipment_thread (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2
                               , pn_parent_req_id IN NUMBER);


    PROCEDURE delivery_thread (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2, pv_delivery_no IN VARCHAR2, pn_trip_id IN NUMBER, pv_carrier IN VARCHAR2
                               , pn_parent_req_id IN NUMBER);


    PROCEDURE main (pv_errbuf           OUT VARCHAR2,
                    pv_retcode          OUT VARCHAR2,
                    pv_shipment_no   IN     VARCHAR2);

    PROCEDURE assign_detail_to_delivery (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_id IN NUMBER
                                         , pv_delivery_name IN VARCHAR2, p_delivery_detail_ids IN tabtype_id, pv_action IN VARCHAR2 DEFAULT 'ASSIGN');

    PROCEDURE pack_container (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_header_id IN NUMBER, pn_delivery_id IN NUMBER, pv_container_name IN VARCHAR2, p_shipments_tab IN g_shipments_tab_type, pn_freight_cost IN NUMBER, pn_container_weight IN NUMBER, pv_tracking_number IN VARCHAR2, pv_carrier IN VARCHAR2, --pd_shipment_date      IN     DATE,
                                                                                                                                                                                                                                                                                                                           pn_org_id IN NUMBER, pv_warehouse IN VARCHAR2
                              , xn_container_id OUT NUMBER);

    PROCEDURE create_container (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_id IN NUMBER, pn_container_item_id IN NUMBER, pv_container_name IN VARCHAR2, pn_organization_id IN NUMBER
                                , xn_container_inst_id OUT NUMBER);

    PROCEDURE process_delivery_freight (
        pv_errbuf                  OUT VARCHAR2,
        pv_retcode                 OUT VARCHAR2,
        pn_header_id            IN     NUMBER,
        pn_delivery_id          IN     NUMBER,
        pn_freight_charge       IN     NUMBER,
        pn_delivery_detail_id   IN     NUMBER,
        pv_carrier              IN     VARCHAR2,
        pv_warehouse            IN     VARCHAR2);

    PROCEDURE process_container_tracking (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_detail_id IN NUMBER
                                          , pv_tracking_number IN VARCHAR2, pn_container_weight IN NUMBER, pv_carrier IN VARCHAR2);

    PROCEDURE pack_into_container (
        pv_errbuf               OUT VARCHAR2,
        pv_retcode              OUT VARCHAR2,
        pn_delivery_id       IN     NUMBER,
        pn_container_id      IN     NUMBER,
        p_delivery_ids_tab   IN     WSH_UTIL_CORE.ID_TAB_TYPE);

    FUNCTION get_requested_quantity (pn_delivery_detail_id IN NUMBER)
        RETURN NUMBER;

    PROCEDURE assign_del_to_trip (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_trip_id IN NUMBER
                                  , pn_delivery_id IN NUMBER, pn_from_stop_id IN NUMBER, pn_to_stop_id IN NUMBER);

    PROCEDURE update_shipping_attributes (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_detail_id IN NUMBER
                                          , pn_shipped_quantity IN NUMBER, pn_order_line_id IN NUMBER, pd_ship_date IN DATE);

    PROCEDURE split_delivery_detail (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_detail_id IN NUMBER
                                     , pn_split_quantity IN NUMBER, pv_delivery_name IN VARCHAR2, xn_delivery_detail_id OUT NUMBER);

    PROCEDURE reapply_holds (
        pv_errbuf              OUT VARCHAR2,
        pv_retcode             OUT VARCHAR2,
        p_hold_source_tbl   IN     g_hold_source_tbl_type);

    PROCEDURE release_holds (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, p_io_hold_source_tbl IN OUT g_hold_source_tbl_type
                             , pn_header_id IN NUMBER);

    PROCEDURE update_trip (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_trip_id IN VARCHAR2
                           , pv_trip_name IN VARCHAR2);

    PROCEDURE interface_edi_asns (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2);

    PROCEDURE ship_confirm_trip (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_org_id IN NUMBER
                                 , pn_trip_id IN NUMBER);

    PROCEDURE update_ship_method (pn_delivery_id        IN NUMBER,
                                  pv_ship_method_code   IN VARCHAR2);

    PROCEDURE split_order_line (pv_errbuf           OUT VARCHAR2,
                                pv_retcode          OUT VARCHAR2,
                                pv_shipment_no   IN     VARCHAR2,
                                pv_delivery_no   IN     VARCHAR2,
                                pn_order_line    IN     NUMBER);

    PROCEDURE back_order_delivery (pn_delivery_id IN VARCHAR2, pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2);

    -- begin 1.2
    PROCEDURE progress_stuck_wf (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, p_org_id IN NUMBER
                                 , p_date_from IN VARCHAR2, p_date_to IN VARCHAR2, p_order_number IN NUMBER);

    FUNCTION order_has_hold (p_header_id IN NUMBER)
        RETURN VARCHAR2;
-- end 1.2
END xxd_ont_ship_confirm_int_pkg;
/
