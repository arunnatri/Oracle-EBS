--
-- XXDO_ONT_SHIP_CONFIRM_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   HZ_LOCATIONS (Synonym)
--   MTL_TXN_REQUEST_LINES (Synonym)
--   OE_HOLD_SOURCES_ALL (Synonym)
--   OE_ORDER_HEADERS (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   WMS_LICENSE_PLATE_NUMBERS (Synonym)
--   WSH_DELIVERY_DETAILS (Synonym)
--   WSH_NEW_DELIVERIES (Synonym)
--   WSH_UTIL_CORE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_ONT_SHIP_CONFIRM_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_ship_confirm_pkg.sql   1.0    2014/07/15    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_ship_confirm_pkg
    --
    -- Description  :  This is package  for WMS to OMS Ship Confirm Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 15-Jul-14    Infosys            1.0       Created
    -- 23-Dec-14  Infosys            2.0       Modified for BT Remediation
    --04-Jun-15   Infosys            3.0        Added new procedure   interface_edi_asns
    -- ***************************************************************************


    g_num_api_version             NUMBER := 1.0;
    g_num_user_id                 NUMBER := fnd_global.user_id;
    g_num_login_id                NUMBER := fnd_global.login_id;
    g_num_request_id              NUMBER := fnd_global.conc_request_id;
    g_num_program_id              NUMBER := fnd_global.conc_program_id;
    g_num_program_appl_id         NUMBER := fnd_global.prog_appl_id;
    g_num_org_id                  NUMBER := fnd_profile.VALUE ('ORG_ID');

    g_chr_ship_confirm_msg_type   VARCHAR2 (30) := '720';

    g_num_container_item_id       NUMBER := 160489;

    TYPE tabtype_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE g_ids_tab_type IS TABLE OF NUMBER
        INDEX BY VARCHAR2 (100);

    g_inv_ids_tab                 g_ids_tab_type;
    g_carrier_ids_tab             g_ids_tab_type;


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

    /*commented for BT Remediation*/
    --FUNCTION get_sku (p_in_num_inventory_item_id IN NUMBER) RETURN VARCHAR2;

    -- Procedure to archive old / processed records
    PROCEDURE purge (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER);

    PROCEDURE address_correction (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_customer_code IN VARCHAR2);

    PROCEDURE lock_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2);

    PROCEDURE reset_error_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2);

    PROCEDURE update_error_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2, p_in_chr_delivery_no IN VARCHAR2, p_in_chr_carton_no IN VARCHAR2, p_in_chr_error_level IN VARCHAR2
                                    , p_in_chr_error_message IN VARCHAR2, p_in_chr_status IN VARCHAR2, p_in_chr_source IN VARCHAR2);

    PROCEDURE pick_line (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_mo_line_id IN NUMBER
                         , p_in_txn_hdr_id IN NUMBER);

    PROCEDURE create_trip (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_trip IN VARCHAR2, p_in_chr_carrier IN VARCHAR2, p_in_num_carrier_id IN NUMBER, p_in_chr_vehicle_number IN VARCHAR2
                           , p_in_chr_mode_of_transport IN VARCHAR2, p_in_chr_master_bol_number IN VARCHAR2, p_out_num_trip_id OUT NUMBER);

    PROCEDURE create_stop (p_out_chr_errbuf               OUT VARCHAR2,
                           p_out_chr_retcode              OUT VARCHAR2,
                           p_in_chr_ship_type          IN     VARCHAR2,
                           p_in_num_trip_id            IN     VARCHAR2,
                           p_in_num_stop_seq           IN     NUMBER,
                           p_in_num_stop_location_id   IN     VARCHAR2,
                           p_in_chr_dep_seal_code      IN     VARCHAR2,
                           p_out_num_stop_id              OUT NUMBER);

    PROCEDURE create_delivery (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_wdd_org_id IN NUMBER, p_in_num_wdd_cust_id IN NUMBER, p_in_num_wdd_ship_method IN VARCHAR2, p_in_num_ship_from_loc_id IN NUMBER, p_in_num_ship_to_loc_id IN NUMBER, p_in_chr_carrier IN VARCHAR2, p_in_chr_waybill IN VARCHAR2
                               , p_in_chr_orig_del_name IN VARCHAR2, p_in_chr_tracking_number IN VARCHAR2, p_out_num_delivery_id OUT NUMBER);

    PROCEDURE ship_confirm_deliveries (
        p_out_chr_errbuf                OUT VARCHAR2,
        p_out_chr_retcode               OUT VARCHAR2,
        p_in_dt_actual_dep_date      IN     DATE,
        p_in_tabtype_id_deliveries   IN     tabtype_id);

    PROCEDURE generate_error_report (p_out_chr_errbuf    OUT VARCHAR2,
                                     p_out_chr_retcode   OUT VARCHAR2);

    PROCEDURE shipment_thread (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2
                               , p_in_num_parent_req_id IN NUMBER);


    PROCEDURE delivery_thread (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2, p_in_chr_delivery_no IN VARCHAR2, p_in_num_trip_id IN NUMBER, p_in_chr_carrier IN VARCHAR2
                               , --p_in_dte_ship_date      IN DATE,
                                 p_in_num_parent_req_id IN NUMBER);


    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2, p_in_chr_source IN VARCHAR2, p_in_chr_dest IN VARCHAR2, p_in_num_purge_days IN NUMBER
                    , p_in_num_bulk_limit IN NUMBER);

    PROCEDURE assign_detail_to_delivery (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_id IN NUMBER
                                         , p_in_chr_delivery_name IN VARCHAR2, p_in_delivery_detail_ids IN tabtype_id, p_in_chr_action IN VARCHAR2 DEFAULT 'ASSIGN');

    PROCEDURE pack_container (
        p_out_chr_errbuf               OUT VARCHAR2,
        p_out_chr_retcode              OUT VARCHAR2,
        p_in_num_header_id          IN     NUMBER,
        p_in_num_delivery_id        IN     NUMBER,
        p_in_chr_container_name     IN     VARCHAR2,
        p_in_shipments_tab          IN     g_shipments_tab_type,
        p_in_num_freight_cost       IN     NUMBER,
        p_in_num_container_weight   IN     NUMBER,
        p_in_chr_tracking_number    IN     VARCHAR2,
        p_in_chr_carrier            IN     VARCHAR2,
        p_in_dte_shipment_date      IN     DATE,
        p_in_num_org_id             IN     NUMBER,
        p_in_chr_warehouse          IN     VARCHAR2,
        p_out_num_container_id         OUT NUMBER);

    PROCEDURE create_container (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_id IN NUMBER, p_in_num_container_item_id IN NUMBER, p_in_chr_container_name IN VARCHAR2, p_in_num_organization_id IN NUMBER
                                , p_out_num_container_inst_id OUT NUMBER);

    PROCEDURE process_delivery_freight (
        p_out_chr_errbuf                 OUT VARCHAR2,
        p_out_chr_retcode                OUT VARCHAR2,
        p_in_num_header_id            IN     NUMBER,
        p_in_num_delivery_id          IN     NUMBER,
        p_in_num_freight_charge       IN     NUMBER,
        p_in_num_delivery_detail_id   IN     NUMBER,
        p_in_chr_carrier              IN     VARCHAR2,
        p_in_chr_warehouse            IN     VARCHAR2);

    PROCEDURE process_container_tracking (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_detail_id IN NUMBER
                                          , p_in_chr_tracking_number IN VARCHAR2, p_in_num_container_weight IN NUMBER, p_in_chr_carrier IN VARCHAR2);

    PROCEDURE pack_into_container (
        p_out_chr_errbuf           OUT VARCHAR2,
        p_out_chr_retcode          OUT VARCHAR2,
        p_in_num_delivery_id    IN     NUMBER,
        p_in_num_container_id   IN     NUMBER,
        p_in_delivery_ids_tab   IN     WSH_UTIL_CORE.id_tab_type);

    /*
    PROCEDURE split_delivery_detail (p_out_chr_errbuf OUT VARCHAR2,
                                                      p_out_chr_retcode OUT VARCHAR2,
                                                      p_in_num_delivery_detail_id IN NUMBER,
                                                      p_io_num_split_quantity IN OUT NUMBER,
                                                      p_out_num_new_del_dtl_id OUT NUMBER);
*/
    FUNCTION get_requested_quantity (p_in_num_delivery_detail_id IN NUMBER)
        RETURN NUMBER;

    PROCEDURE assign_del_to_trip (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_trip_id IN NUMBER
                                  , p_in_num_delivery_id IN NUMBER);

    PROCEDURE upload_xml (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_inbound_directory VARCHAR2
                          , p_in_chr_file_name VARCHAR2);

    PROCEDURE extract_xml_data (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_bulk_limit IN NUMBER);

    PROCEDURE update_shipping_attributes (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_detail_id IN NUMBER
                                          , p_in_num_shipped_quantity IN NUMBER, p_in_num_order_line_id IN NUMBER, p_in_dte_ship_date IN DATE);

    PROCEDURE split_delivery_detail (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_detail_id IN NUMBER
                                     , p_in_num_split_quantity IN NUMBER, p_in_chr_delivery_name IN VARCHAR2, p_out_num_delivery_detail_id OUT NUMBER);

    PROCEDURE reapply_holds (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_hold_source_tbl IN g_hold_source_tbl_type);

    PROCEDURE release_holds (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_io_hold_source_tbl IN OUT g_hold_source_tbl_type
                             , p_in_num_header_id IN NUMBER);

    PROCEDURE update_trip (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_trip_id IN VARCHAR2
                           , p_in_chr_trip_name IN VARCHAR2);

    /*
        PROCEDURE release_hold(  p_out_chr_errbuf  OUT VARCHAR2,
                                                p_out_chr_retcode OUT VARCHAR2,
                                                 p_in_num_header_id     IN  NUMBER,
                                                 p_in_num_line_id       IN  NUMBER,
                                                 p_in_num_hold_id      IN NUMBER,
                                                 p_in_chr_release_reason     IN VARCHAR2,
                                                 p_in_chr_release_comment     IN VARCHAR2);

        PROCEDURE apply_hold(  p_out_chr_errbuf  OUT VARCHAR2,
                                             p_out_chr_retcode OUT VARCHAR2,
                                             p_in_num_header_id     IN  NUMBER,
                                             p_in_num_line_id       IN  NUMBER,
                                             p_in_num_hold_id      IN NUMBER,
                                             p_in_chr_hold_comment IN VARCHAR2  );

        PROCEDURE validate_shipping_data (p_out_chr_errbuf        OUT VARCHAR2,
                                                            p_out_chr_retcode      OUT VARCHAR2,
                                                            p_in_chr_shipment_no    IN       VARCHAR2,
                                                            p_in_num_ship_index IN NUMBER);

        PROCEDURE process_delivery_line(  p_out_chr_errbuf OUT VARCHAR2,
                                                            p_out_chr_retcode OUT VARCHAR2,
                                                            p_in_num_delivery_detail_id IN NUMBER,
                                                            p_in_dte_ship_date IN DATE,
                                                            p_in_chr_carrier IN VARCHAR2,
                                                            p_out_chr_tracking_number IN VARCHAR2
                                                            );

        PROCEDURE process_delivery_line ( p_out_chr_errbuf OUT VARCHAR2,
                                                            p_out_chr_retcode OUT VARCHAR2,
                                                            p_in_num_delivery_detail_id IN NUMBER,
                                                            p_in_num_ship_qty IN NUMBER,
                                                            p_in_dte_ship_date IN DATE,
                                                            p_in_chr_carrier IN VARCHAR2,
                                                            p_out_chr_tracking_number IN VARCHAR2
                                                            ) ;

        PROCEDURE split_shipments (p_out_chr_errbuf OUT VARCHAR2,
                                                    p_out_chr_retcode OUT VARCHAR2,
                                                    p_in_shipments_tab IN g_shipments_tab_type,
                                                    p_in_chr_carrier IN VARCHAR2,
                                                    p_in_chr_tracking_no IN VARCHAR2,
                                                    p_in_dte_shipment_date IN DATE,
                                                    p_out_delivery_ids_tab OUT WSH_UTIL_CORE.id_tab_type
                                                    );

    */
    PROCEDURE interface_edi_asns (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2);
END xxdo_ont_ship_confirm_pkg;
/
