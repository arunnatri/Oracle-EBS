--
-- XXD_ONT_SCH_CONC_REQUESTS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_SCH_CONC_REQUESTS_PKG"
    AUTHID CURRENT_USER
AS
    /* $Header: OEXCSCHS.pls 120.8.12020000.3 2014/10/30 07:05:28 sahvivek ship $ */
    /****************************************************************************************
    * Package      : XXD_ONT_SCH_CONC_REQUESTS_PKG
    * Design       : Custom Schedule Orders Program
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 19-Jan-2022  1.0        Viswanathan Pandian     Initial Version copied from Schedule Orders
    ******************************************************************************************/
    g_process_records     NUMBER;
    g_failed_records      NUMBER;
    g_conc_program        VARCHAR2 (1) := 'N';
    g_recorded            VARCHAR2 (1) := 'N';                       --5166476
    g_checked_for_holds   VARCHAR2 (1) := 'N';                  -- ER 13114460
    g_request_id          NUMBER;                                 --ER18493998

    TYPE id_arr IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    oe_model_id_tbl       id_arr;
    oe_set_id_tbl         id_arr;
    oe_included_id_tbl    id_arr;

    --5166476
    TYPE status_arr IS TABLE OF VARCHAR2 (1)
        INDEX BY BINARY_INTEGER;

    oe_line_status_tbl    status_arr;

    PROCEDURE request (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, /* Moac */
                                                                                p_org_id IN NUMBER, p_order_number_low IN NUMBER, p_order_number_high IN NUMBER, p_request_date_low IN VARCHAR2, p_request_date_high IN VARCHAR2, p_customer_po_number IN VARCHAR2, p_ship_to_location IN VARCHAR2, p_order_type IN VARCHAR2, p_order_source IN VARCHAR2, p_brand IN VARCHAR2, p_customer IN VARCHAR2, p_ordered_date_low IN VARCHAR2, p_ordered_date_high IN VARCHAR2, p_warehouse IN VARCHAR2, p_item IN VARCHAR2, p_demand_class IN VARCHAR2, p_planning_priority IN VARCHAR2, p_shipment_priority IN VARCHAR2, p_line_type IN VARCHAR2, p_line_request_date_low IN VARCHAR2, p_line_request_date_high IN VARCHAR2, p_line_ship_to_location IN VARCHAR2, p_sch_ship_date_low IN VARCHAR2, p_sch_ship_date_high IN VARCHAR2, p_sch_arrival_date_low IN VARCHAR2, p_sch_arrival_date_high IN VARCHAR2, p_booked IN VARCHAR2, p_sch_mode IN VARCHAR2, p_req_date_condition IN VARCHAR2, p_dummy4 IN VARCHAR2 DEFAULT NULL, -- FOTL Bug 18493780
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           p_bulk_processing IN VARCHAR2 DEFAULT 'N', --FOTL Bug 18493780
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      p_dummy1 IN VARCHAR2, p_dummy2 IN VARCHAR2, p_apply_warehouse IN VARCHAR2, p_apply_sch_date IN VARCHAR2, p_order_by_first IN VARCHAR2, p_order_by_sec IN VARCHAR2, p_picked IN VARCHAR2 DEFAULT NULL, --Bug 8813015
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_dummy3 IN VARCHAR2 DEFAULT NULL, -- 12639770
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               p_commit_threshold IN NUMBER DEFAULT NULL
                       ,                                           -- 12639770
                         p_num_instances IN NUMBER DEFAULT NULL --FOTL Bug 18493780
                                                               );

    FUNCTION included_processed (p_inc_item_id IN NUMBER)
        RETURN BOOLEAN;
END xxd_ont_sch_conc_requests_pkg;
/
