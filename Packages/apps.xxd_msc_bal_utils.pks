--
-- XXD_MSC_BAL_UTILS  (Package) 
--
--  Dependencies: 
--   MRP_ATP_PUB (Package)
--   MRP_BAL_UTILS (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_MSC_BAL_UTILS"
    AUTHID CURRENT_USER
AS
    /* $Header: MSCUBALS.pls 120.3.12020000.2 2014/01/05 12:02:57 neelredd ship $  */

    /*
    TYPE number_arr IS TABLE OF number;
    TYPE char18_arr IS TABLE of varchar2(18);

    TYPE mrp_oe_rec IS RECORD (line_id             number_arr,
                   ship_set_id         number_arr,
                   arrival_set_id      number_arr,
                   seq_num             number_arr);

    TYPE seq_alter IS RECORD(order_line_id       number_arr,
                 ship_set_id         number_arr,
                 arrival_set_id      number_arr,
                 seq_diff            number_arr);
    */


    --bwb
    TYPE number_arr IS TABLE OF NUMBER;

    g_om_status   VARCHAR2 (20);
    g_om_req_id   NUMBER;

    TYPE ATP_QTY_ORDERED_TYP IS RECORD
    (
        quantity_ordered    number_arr := number_arr (),
        order_line_id       number_arr := number_arr (),
        session_id          number_arr := number_arr ()
    );

    -- Start of Changes by BT DEV on 08 Nov 15
    TYPE XXD_ATP_QTY_ORDERED_TYP IS RECORD
    (
        quantity_ordered    number_arr := number_arr (),
        order_line_id       number_arr := number_arr (),
        session_id          number_arr := number_arr (),
        sequence_number     number_arr := number_arr ()
    );

    -- End of Changes by BT DEV on 08 Nov 15

    PROCEDURE populate_temp_table (p_session_id       NUMBER,
                                   p_order_by         VARCHAR2,
                                   p_where            VARCHAR2,
                                   p_overwrite        NUMBER,
                                   p_org_id           NUMBER,
                                   p_exclude_picked   NUMBER DEFAULT 0);

    PROCEDURE cmt_schedule (
        p_user_id         IN            NUMBER,
        p_resp_id         IN            NUMBER,
        p_appl_id         IN            NUMBER,
        p_session_id      IN            NUMBER,
        x_msg_count          OUT NOCOPY NUMBER,
        x_msg_data           OUT NOCOPY VARCHAR2,
        x_return_status      OUT NOCOPY VARCHAR2,
        p_tcf                           BOOLEAN DEFAULT TRUE);


    PROCEDURE undemand_orders (p_session_id NUMBER, x_msg_count IN OUT NOCOPY NUMBER, x_msg_data IN OUT NOCOPY VARCHAR2
                               , x_return_status IN OUT NOCOPY VARCHAR2);

    PROCEDURE update_schedule_qties (p_atp_qty_ordered_temp IN XXD_MSC_BAL_UTILS.XXD_ATP_QTY_ORDERED_TYP, p_return_status OUT NOCOPY VARCHAR2, p_error_message OUT NOCOPY VARCHAR2);

    PROCEDURE reschedule (
        p_session_id                    NUMBER,
        x_msg_count          OUT NOCOPY NUMBER,
        x_msg_data           OUT NOCOPY VARCHAR2,
        x_return_status      OUT NOCOPY VARCHAR2,
        p_tcf                           BOOLEAN DEFAULT TRUE);

    PROCEDURE schedule_orders (
        p_session_id                    NUMBER,
        x_msg_count          OUT NOCOPY NUMBER,
        x_msg_data           OUT NOCOPY VARCHAR2,
        x_return_status      OUT NOCOPY VARCHAR2,
        p_tcf                           BOOLEAN DEFAULT TRUE);

    PROCEDURE call_oe_api (p_session_id NUMBER, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2
                           , x_return_status OUT NOCOPY VARCHAR2);

    PROCEDURE call_oe_api (p_atp_rec MRP_ATP_PUB.atp_rec_typ, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2
                           , x_return_status OUT NOCOPY VARCHAR2);

    PROCEDURE execute_command (p_command VARCHAR2, p_user_command NUMBER, x_msg_data OUT NOCOPY VARCHAR2
                               , x_return_status OUT NOCOPY VARCHAR2);

    PROCEDURE update_seq (
        p_session_id                    NUMBER,
        p_seq_alter       IN OUT NOCOPY MRP_BAL_UTILS.seq_alter,
        x_msg_count          OUT NOCOPY NUMBER,
        x_msg_data           OUT NOCOPY VARCHAR2,
        x_return_status      OUT NOCOPY VARCHAR2);

    PROCEDURE EXTEND (p_nodes         IN OUT NOCOPY MRP_BAL_UTILS.seq_alter,
                      extend_amount                 NUMBER);
END XXD_MSC_BAL_UTILS;
/
