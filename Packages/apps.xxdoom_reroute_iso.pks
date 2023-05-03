--
-- XXDOOM_REROUTE_ISO  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOOM_REROUTE_ISO"
AS
    OM_Responsibility       CONSTANT VARCHAR2 (100)
        := 'Deckers Order Management Super User - Macau' ;
    PO_Responsibility       CONSTANT VARCHAR2 (100)
                                         := 'Deckers Purchasing User - Global' ;
    DC_XFER_Order_type      CONSTANT NUMBER := 1135;
    Interface_Source_Code   CONSTANT VARCHAR2 (50) := 'IR Copy';
    OS_Internal             CONSTANT NUMBER := 10;

    --Numeric Responsibility constants
    OM_Rresp_id             CONSTANT NUMBER := 50710;
    OM_App_ID               CONSTANT NUMBER := 660;

    PO_Rresp_id             CONSTANT NUMBER := 51406;
    PO_App_ID               CONSTANT NUMBER := 201;

    --Run the Order import concurrent request for the OU and the inv_org specified.
    PROCEDURE run_order_import (p_org_id IN NUMBER, p_inv_org_id IN NUMBER, p_order_source_id IN NUMBER:= OS_Internal, p_user_id IN NUMBER, p_status OUT VARCHAR, p_msg OUT VARCHAR2
                                , p_request_id OUT NUMBER);

    --Run the create internal orders concurrent request
    PROCEDURE run_create_internal_orders (p_org_id IN NUMBER, p_inv_org_id IN NUMBER, p_user_id IN NUMBER
                                          , p_status OUT VARCHAR, p_msg OUT VARCHAR2, p_request_id OUT NUMBER);

    --Run the requisition import concurrent request
    PROCEDURE run_req_import (p_import_source IN VARCHAR2, p_batch_id IN VARCHAR2:= '', p_org_id IN NUMBER, p_inv_org_id IN NUMBER, p_user_id IN NUMBER, p_status OUT VARCHAR
                              , p_msg OUT VARCHAR2, p_request_id OUT NUMBER);

    FUNCTION copy_internal_rec (p_src_req_number IN NUMBER, p_src_org IN NUMBER, p_dest_org IN NUMBER, p_need_by_date IN DATE:= NULL, p_interface_source_code IN VARCHAR2:= Interface_Source_Code, p_undelivered_only IN VARCHAR2:= 'Y'
                                , p_run_req_import IN VARCHAR2:= 'Y', p_user_id IN NUMBER, p_preparer_id IN NUMBER)
        RETURN NUMBER;

    PROCEDURE move_reservations (p_src_order_number IN NUMBER, p_dest_order_number IN NUMBER, p_user_id IN NUMBER
                                 , p_reserv_type IN NUMBER:= 1);

    --procedure cancel_ir(req_number in number);

    --procedure cancel_iso (order_number in number);

    PROCEDURE reroute_internal_so (p_src_order_number IN NUMBER, p_so_source_org IN NUMBER, p_dest_inv_org IN NUMBER, p_need_by_date IN DATE:= NULL, p_interface_source_code IN VARCHAR:= Interface_Source_Code, p_user_id IN NUMBER, p_partial_del_override IN VARCHAR2:= 'N', p_gtn_override IN VARCHAR2:= 'N', p_new_ir_number OUT NUMBER
                                   , p_new_iso_number OUT NUMBER, p_ret_stat OUT VARCHAR2, p_ret_msg OUT VARCHAR2);
END xxdoom_reroute_iso;
/
