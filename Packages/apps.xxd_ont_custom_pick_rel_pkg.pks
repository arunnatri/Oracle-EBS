--
-- XXD_ONT_CUSTOM_PICK_REL_PKG  (Package) 
--
--  Dependencies: 
--   MTL_PARAMETERS (Synonym)
--   OE_ORDER_HEADERS_ALL (Synonym)
--   RCV_SHIPMENT_HEADERS (Synonym)
--   RCV_SHIPMENT_LINES (Synonym)
--   WSH_UTIL_CORE (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_CUSTOM_PICK_REL_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CUSTOM_PICK_REL_PKG
    * Design       : This package is used for Deckers Custom Pick Release Process
    * Notes        :
    * Modification :
    -- =======================================================================================
    -- Date         Version#   Name                    Comments
    -- =======================================================================================
    -- 29-Apr-2019  1.0        Viswanathan Pandian     Initial Version for Direct Ship Phase 2
    ******************************************************************************************/

    PROCEDURE credit_check (p_header_id IN oe_order_headers_all.header_id%TYPE, x_return_status OUT NOCOPY VARCHAR2, x_return_msg OUT NOCOPY VARCHAR2);

    PROCEDURE autocreate_delivery (
        p_line_rows       IN            wsh_util_core.id_tab_type,
        x_return_status      OUT NOCOPY VARCHAR2,
        x_return_msg         OUT NOCOPY VARCHAR2,
        x_del_rows           OUT NOCOPY wsh_util_core.id_tab_type);

    PROCEDURE create_release_batch (p_organization_id IN mtl_parameters.organization_id%TYPE, p_line_rows IN wsh_util_core.id_tab_type, x_return_status OUT NOCOPY VARCHAR2
                                    , x_return_msg OUT NOCOPY VARCHAR2);

    PROCEDURE pick_release_master (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_factory_invoice_num IN rcv_shipment_headers.packing_slip%TYPE, p_container_num IN rcv_shipment_lines.container_num%TYPE, p_order_header_id IN oe_order_headers_all.header_id%TYPE
                                   , p_partial_order_fulfill IN VARCHAR2, p_threads IN NUMBER, p_debug IN VARCHAR2);

    PROCEDURE pick_release_child (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_from_batch_id IN NUMBER, p_to_batch_id IN NUMBER, p_request_id IN NUMBER, p_threads IN NUMBER
                                  , p_debug IN VARCHAR2);
END xxd_ont_custom_pick_rel_pkg;
/
