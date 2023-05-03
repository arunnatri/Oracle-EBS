--
-- XXD_MSC_ONT_ATP_LEVEL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_MSC_ONT_ATP_LEVEL_PKG"
AS
    PROCEDURE XXD_UPDATE_ERROR_LOG (p_session_id NUMBER, p_order_header_id NUMBER, p_action_type VARCHAR2
                                    , p_error_message VARCHAR2);

    PROCEDURE prc_insert_atp_level_header (pn_session_id IN NUMBER, xn_status OUT NUMBER, xv_message OUT VARCHAR2);

    PROCEDURE proc_update_xxd_headers (pn_session_id NUMBER, xn_status OUT NUMBER, xv_message OUT VARCHAR2);

    --   PROCEDURE insert_xxd_msc_temp_proc (p_session_id NUMBER);
    --
    TYPE xxd_cancel_line_rec IS RECORD
    (
        header_id           NUMBER,
        line_id             NUMBER,
        ordered_quantity    NUMBER,
        cancelled_flag      CHAR,
        change_reason       VARCHAR2 (300)
    );

    PROCEDURE proc_call_reschdl_report (pn_session_id       NUMBER,
                                        xn_request_id   OUT NUMBER);

    PROCEDURE proc_call_exception_report (pn_session_id NUMBER, pn_no_of_days NUMBER DEFAULT 1, xn_request_id OUT NUMBER);

    TYPE v_cancel_line_tbl_type IS TABLE OF xxd_cancel_line_rec
        INDEX BY BINARY_INTEGER;

    xxd_v_cancel_line_tbl    v_cancel_line_tbl_type;

    TYPE xxd_update_line_rec IS RECORD
    (
        header_id           NUMBER,
        line_id             NUMBER,
        ordered_quantity    NUMBER,
        --cancelled_flag     CHAR,
        change_reason       VARCHAR2 (300)
    );

    TYPE v_update_line_tbl_type IS TABLE OF xxd_update_line_rec
        INDEX BY BINARY_INTEGER;

    xxd_v_update_line_tbl    v_update_line_tbl_type;

    TYPE xxd_unschdl_line_rec IS RECORD
    (
        header_id              NUMBER,
        line_id                NUMBER,
        scheduled_ship_date    DATE,
        requested_ship_date    DATE,
        schedule_type          VARCHAR2 (300)
    );

    TYPE v_unschdl_line_tbl_type IS TABLE OF xxd_unschdl_line_rec
        INDEX BY BINARY_INTEGER;

    xxd_v_unschdl_line_tbl   v_unschdl_line_tbl_type;

    TYPE xxd_updt_lad_line_rec IS RECORD
    (
        header_id                 NUMBER,
        line_id                   NUMBER,
        latest_acceptable_date    DATE
    --      requested_ship_date   DATE,
    );

    TYPE v_xxd_updt_lad_tbl_type IS TABLE OF xxd_updt_lad_line_rec
        INDEX BY BINARY_INTEGER;

    v_xxd_updt_lad_tbl       v_xxd_updt_lad_tbl_type;

    PROCEDURE proc_update_latest_accpbl_date (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                              , pn_org_id NUMBER     --      ,
                                                                --      x_msg_data        OUT          VARCHAR2
                                                                );

    PROCEDURE proc_cancel_order_lines (
        x_errbuf             OUT NOCOPY VARCHAR2,
        x_retcode            OUT NOCOPY NUMBER,
        pn_session_id                   NUMBER,
        pn_user_id                      NUMBER,
        pn_resp_id                      NUMBER,
        pn_resp_appl_id                 NUMBER,
        pn_org_id                       NUMBER,
        x_msg_data           OUT        VARCHAR2);

    PROCEDURE proc_unschedule_order_lines (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                           , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2);

    PROCEDURE proc_call_cancel_order_lines (x_errbuff OUT VARCHAR2, x_retcode OUT NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                            , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2);

    PROCEDURE proc_call_updt_lad_order_lines (x_errbuff         OUT VARCHAR2,
                                              x_retcode         OUT NUMBER,
                                              pn_session_id         NUMBER,
                                              pn_user_id            NUMBER,
                                              pn_resp_id            NUMBER,
                                              pn_resp_appl_id       NUMBER,
                                              pn_org_id             NUMBER,
                                              x_msg_data        OUT VARCHAR2,
                                              x_err_msg         OUT VARCHAR2,
                                              x_return_status   OUT VARCHAR2,
                                              xn_request_id     OUT NUMBER);

    PROCEDURE proc_call_unschdl_order_lines (x_errbuff OUT VARCHAR2, x_retcode OUT NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                             , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2);

    PROCEDURE proc_unschedule_split_oe_lines (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                              , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2);

    PROCEDURE proc_unschdl_cancl_split_lines (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                              , pn_org_id NUMBER, x_msg_data OUT VARCHAR2, x_err_msg OUT VARCHAR2);

    FUNCTION from_details_temp (p_session_id NUMBER, p_order_line_id NUMBER)
        RETURN NUMBER;  -- Added by NRK ( Determines Negative ATP on Screen-3)

    PROCEDURE update_atp_temp_screen3 (p_session_id IN NUMBER);

    -- Added by NRK ( Updates the Negative ATP to the column on Screen-3)

    ------------------------------------------------------------------------
    -- Added by NRK -- START of Changes
    ------------------------------------------------------------------------
    TYPE xxd_split_line_rec IS RECORD
    (
        order_header_id        NUMBER,
        order_line_id          NUMBER,
        scheduled_ship_date    DATE,
        requested_ship_date    DATE,
        schedule_type          VARCHAR2 (300),
        split_from_oe_line     NUMBER,
        new_quantity           NUMBER,
        inventory_item_id      NUMBER,
        sequence_number        NUMBER,
        atp_level_type         NUMBER
    );

    TYPE v_split_line_tbl_type IS TABLE OF xxd_split_line_rec
        INDEX BY BINARY_INTEGER;

    xxd_v_split_line_tbl     v_split_line_tbl_type;


    TYPE xxd_schdl_line_rec IS RECORD
    (
        header_id             NUMBER,
        line_id               NUMBER,
        inventory_item_id     NUMBER,
        ship_from_org_id      NUMBER,
        schedule_ship_date    DATE,
        REQUEST_DATE          DATE,
        schedule_type         VARCHAR2 (50)
    );

    TYPE v_schdl_line_tbl_type IS TABLE OF xxd_schdl_line_rec
        INDEX BY BINARY_INTEGER;

    xxd_v_schdl_line_tbl     v_schdl_line_tbl_type;

    PROCEDURE proc_split_order_lines (pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER, pn_org_id NUMBER, x_msg_data OUT VARCHAR2
                                      , x_err_msg OUT VARCHAR2);

    PROCEDURE proc_set_override_atp_to_n (pn_session_id NUMBER);

    PROCEDURE proc_set_override_atp_to_y (pn_session_id NUMBER);

    PROCEDURE proc_schdl_duplicate_lines (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, pn_session_id NUMBER, pn_user_id NUMBER, pn_resp_id NUMBER, pn_resp_appl_id NUMBER
                                          , pn_org_id NUMBER);

    PROCEDURE proc_new_sales_oe_line_report (pn_session_id       NUMBER,
                                             xn_request_id   OUT NUMBER);
--------------------------------------------------------------------------
-- Added by NRK -- END of Changes
----------------------------------------------------------------------------
END xxd_msc_ont_atp_level_pkg;
/
