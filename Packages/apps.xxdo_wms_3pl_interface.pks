--
-- XXDO_WMS_3PL_INTERFACE  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   INV_MOVE_ORDER_PUB (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_WMS_3PL_INTERFACE"
    AUTHID DEFINER
AS
    /********************************************************************************************
      Modification History:
    Version    By                     Date           Comments

    1.0      BT-Technology Team      22-Nov-2014    Updated for  BT
    1.1      Aravind Kannuri         12-Jun-2019    Changes as per CCR0007979(Macau-EMEA)
    1.2      Greg Jensen             19-May-2020    Changes as per CCR0008621
    1.3      Chandra                 1-MAR-2020     CHnages for CCR CCR0008870
    1.4      Aravind Kannuri         16-Aug-2021    Changes as per CCR0009513
    1.5      Aravind Kannuri         25-May-2022    Changes as per CCR0009887
    1.6      Ramesh Reddy            06-Feb-2023    Changes as per CCR0010325
    ******************************************************************************************/
    --  DEFAULTS
    g_miss_num                   CONSTANT NUMBER := apps.fnd_api.g_miss_num;
    g_miss_char                  CONSTANT VARCHAR2 (1) := apps.fnd_api.g_miss_char;
    g_miss_date                  CONSTANT DATE := apps.fnd_api.g_miss_date;
    -- RETURN STATUSES
    g_ret_success                CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_success;
    g_ret_error                  CONSTANT VARCHAR2 (1) := apps.fnd_api.g_ret_sts_error;
    g_ret_unexp_error            CONSTANT VARCHAR2 (1)
                                              := apps.fnd_api.g_ret_sts_unexp_error ;
    g_ret_warning                CONSTANT VARCHAR2 (1) := 'W';
    g_ret_init                   CONSTANT VARCHAR2 (1) := 'I';
    g_proc_status_acknowledged   CONSTANT VARCHAR2 (1) := 'A';
    -- CONCURRENT STATUSES
    g_fnd_normal                 CONSTANT VARCHAR2 (20) := 'NORMAL';
    g_fnd_warning                CONSTANT VARCHAR2 (20) := 'WARNING';
    g_fnd_error                  CONSTANT VARCHAR2 (20) := 'ERROR';

    PROCEDURE start_debugging;

    PROCEDURE update_asn_status (p_organization_id NUMBER, x_ret_stat OUT VARCHAR2, x_message OUT VARCHAR2
                                 , p_source_document_code VARCHAR2:= NULL, p_source_header_id NUMBER:= NULL, p_asn_status VARCHAR2:= NULL);

    PROCEDURE rcv_line (p_source_document_code        VARCHAR2,
                        p_source_line_id              NUMBER,
                        p_quantity                    NUMBER,
                        x_ret_stat                OUT VARCHAR2,
                        x_message                 OUT VARCHAR2,
                        p_subinventory                VARCHAR2 := NULL,
                        p_receipt_date                DATE := SYSDATE,
                        p_parent_transaction_id       NUMBER := NULL,
                        p_duty_paid_flag              VARCHAR2 := NULL, --Added as per ver 1.1
                        p_carton_code                 VARCHAR2 := NULL,
                        p_receipt_type                VARCHAR2 --Added as per ver 1.3
                                                              ); --Added to support 3PL carton receiving

    PROCEDURE process_grn;

    PROCEDURE update_ats_status (p_organization_id        NUMBER,
                                 x_ret_stat           OUT VARCHAR2,
                                 x_message            OUT VARCHAR2,
                                 p_source_header_id       NUMBER := NULL,
                                 p_asn_status             VARCHAR2 := NULL);

    PROCEDURE process_load_confirmation;

    PROCEDURE process_adjustments;

    PROCEDURE process_transfers;

    PROCEDURE update_itm_status (p_organization_id         NUMBER,
                                 x_ret_stat            OUT VARCHAR2,
                                 x_message             OUT VARCHAR2,
                                 p_inventory_item_id       NUMBER := NULL,
                                 p_confirmed_flag          VARCHAR2 := NULL);

    PROCEDURE process_order_tracking;

    FUNCTION get_delivery_container (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_shipment_num IN VARCHAR2)
        RETURN VARCHAR2;

    --Begin CCR0008621
    FUNCTION get_line_hts_code (p_style_number      IN VARCHAR2,
                                p_organization_id   IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_asn_line_factory_price (p_shipment_line_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_asn_line_country_of_origin (p_shipment_line_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_shipment_bol (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_shipment_invoice (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2;

    --End CCR0008621
    FUNCTION get_shipment_po_number (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_delivery_sender (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_shipment_num IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_shipment_container (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_shipment_sender (p_shipment_type IN VARCHAR2, p_organization_id IN NUMBER, p_grouping_id IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE log_error (p_operation_type   IN VARCHAR2,
                         p_operation_code   IN VARCHAR2,
                         p_error_message    IN VARCHAR2,
                         p_file_name        IN VARCHAR2 := NULL,
                         p_logging_id       IN VARCHAR2 := NULL);

    FUNCTION mti_source_code
        RETURN VARCHAR2;

    --Start Added for 1.4
    FUNCTION get_rcv_rti_qty (p_shipment_line_id   IN NUMBER,
                              p_inv_item_id        IN NUMBER DEFAULT NULL)
        RETURN NUMBER;

    FUNCTION get_parenttrxid_qty (p_shipment_line_id IN NUMBER, p_inv_item_id IN NUMBER, p_qty_deliver IN NUMBER
                                  , p_type IN VARCHAR2 --QUANTITY \ PARENT_TRANS_ID
                                                      )
        RETURN NUMBER;

    FUNCTION get_least_max_trx_id (p_shipment_line_id IN NUMBER, p_qty_deliver IN NUMBER, p_inv_item_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_remaining_deliver_qty (p_shipment_line_id IN NUMBER, p_parent_trx_id IN NUMBER, p_qty_deliver IN NUMBER)
        RETURN NUMBER;

    --End Added for 1.4

    PROCEDURE resubmit_interface (p_user_id IN NUMBER, p_message_type IN VARCHAR2, p_header_id IN NUMBER
                                  , p_comments IN VARCHAR2:= NULL, x_ret_stat OUT VARCHAR2, x_message OUT VARCHAR2);

    PROCEDURE acknowledge_interface (p_user_id IN NUMBER, p_message_type IN VARCHAR2, p_header_id IN NUMBER
                                     , p_comments IN VARCHAR2:= NULL, x_ret_stat OUT VARCHAR2, x_message OUT VARCHAR2);

    PROCEDURE update_in_process_status (p_created_by IN NUMBER, p_message_type IN VARCHAR2, p_header_id IN NUMBER, p_in_process_flag IN VARCHAR2, p_comments IN VARCHAR2, x_ret_stat OUT VARCHAR2
                                        , x_message OUT VARCHAR2);

    /*
    Added by CC for Canada project
    New OHR interface for Inventory Sync processing
    */

    PROCEDURE process_inventory_sync;

    /*
 Added by CC for the CCR #CCR0006013
 */

    FUNCTION VALID_LOADID_REQ (p_cust_id IN NUMBER)
        RETURN BOOLEAN;

    /*
 Added by CC for the CCR #CCR0006357
 */
    FUNCTION return_open_ra_line (p_so_header_id IN NUMBER, p_inventory_item_id IN NUMBER, p_qty_received IN NUMBER)
        RETURN NUMBER;

    PROCEDURE Process_auto_receipt (p_org_id        IN     NUMBER,
                                    p_record_id     IN     VARCHAR, -- ORDER NUMBER for Return, SHIPMENT NUM for return
                                    p_record_type   IN     VARCHAR2, --REQ (ASN), RET (RETURN)
                                    p_error_stat       OUT VARCHAR2,
                                    p_error_msg        OUT VARCHAR2);

    PROCEDURE msg (p_message VARCHAR2, p_severity NUMBER:= 10000);

    --Start Added for 1.5
    FUNCTION pick_confirm (
        l_mo_lin_tbl IN OUT inv_move_order_pub.trolin_tbl_type)
        RETURN BOOLEAN;

    --End Added for 1.5

    PROCEDURE get_shipment_line_id;                    -- Added for CCR0010325
END XXDO_WMS_3PL_INTERFACE;
/


GRANT EXECUTE ON APPS.XXDO_WMS_3PL_INTERFACE TO XXDO
/
