--
-- XXDOEC_MANUAL_REFUND_PKG  (Package) 
--
--  Dependencies: 
--   XXDOEC_MANUAL_REFUND_PG_DTLS (Synonym)
--   XXDOEC_ORDER_MANUAL_REFUNDS (Synonym)
--   XXDOEC_REFUND_TBL_TYPE (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_MANUAL_REFUND_PKG"
AS
    -- ***************************************************************************************
    -- Package      : XXDOEC_MANUAL_REFUND_PKG
    -- Design       :
    -- Notes        :
    -- Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 12-Jun-2015  1.0       Keith Copeland          Initial version
    -- 23-Apr-2018  1.1       Vijay Reddy             CCR0007157 Zendesk Manual Refunds
    -- ****************************************************************************************

    TYPE xxdoec_order_manual_refunds
        IS RECORD
    (
        refund_id                 apps.xxdoec_order_manual_refunds.refund_id%TYPE,
        header_id                 apps.xxdoec_order_manual_refunds.header_id%TYPE,
        line_group_id             apps.xxdoec_order_manual_refunds.line_group_id%TYPE,
        line_id                   apps.xxdoec_order_manual_refunds.line_id%TYPE,
        refund_component          apps.xxdoec_order_manual_refunds.refund_component%TYPE,
        refund_quantity           apps.xxdoec_order_manual_refunds.refund_quantity%TYPE,
        refund_unit_amount        apps.xxdoec_order_manual_refunds.refund_unit_amount%TYPE,
        refund_request_date       apps.xxdoec_order_manual_refunds.refund_request_date%TYPE,
        refund_reason             apps.xxdoec_order_manual_refunds.refund_reason%TYPE,
        refund_processed_by       apps.xxdoec_order_manual_refunds.refund_processed_by%TYPE,
        refund_type               apps.xxdoec_order_manual_refunds.refund_type%TYPE,
        comments                  apps.xxdoec_order_manual_refunds.comments%TYPE,
        pg_status                 apps.xxdoec_order_manual_refunds.pg_status%TYPE,
        -- CCR0007157 Zendesk Manual Refunds Start
        p_service_order_number    apps.xxdoec_order_manual_refunds.service_order_number%TYPE,
        p_web_site_id             apps.xxdoec_order_manual_refunds.web_site_id%TYPE,
        p_currency_code           apps.xxdoec_order_manual_refunds.currency_code%TYPE
    -- CCR0007157 Zendesk Manual Refunds End
    );

    TYPE t_refund_cursor IS REF CURSOR
        RETURN xxdoec_order_manual_refunds;

    PROCEDURE get_lines_group_id (x_lines_group_id OUT VARCHAR2);

    PROCEDURE update_refund_payment_status (p_line_group_id apps.xxdoec_order_manual_refunds.line_group_id%TYPE, p_refund_id apps.xxdoec_order_manual_refunds.refund_id%TYPE, -- CCR0007157 Zendesk Manual Refunds
                                                                                                                                                                              x_return_status OUT VARCHAR2
                                            , x_error_text OUT VARCHAR2);

    PROCEDURE get_order_refund_items (p_header_id apps.xxdoec_order_manual_refunds.header_id%TYPE, o_order_refunds OUT t_refund_cursor);

    PROCEDURE insert_order_manual_refund (p_header_id apps.xxdoec_order_manual_refunds.header_id%TYPE, p_line_group_id apps.xxdoec_order_manual_refunds.line_group_id%TYPE, p_line_id apps.xxdoec_order_manual_refunds.line_id%TYPE, p_refund_component apps.xxdoec_order_manual_refunds.refund_component%TYPE, p_refund_quantity apps.xxdoec_order_manual_refunds.refund_quantity%TYPE, p_refund_unit_amount apps.xxdoec_order_manual_refunds.refund_unit_amount%TYPE, p_refund_reason apps.xxdoec_order_manual_refunds.refund_reason%TYPE, p_refund_processed_by apps.xxdoec_order_manual_refunds.refund_processed_by%TYPE, p_refund_type apps.xxdoec_order_manual_refunds.refund_type%TYPE, p_refund_trx_id apps.xxdoec_order_manual_refunds.refund_trx_id%TYPE, p_refund_trx_status apps.xxdoec_order_manual_refunds.refund_trx_status%TYPE, p_comments apps.xxdoec_order_manual_refunds.comments%TYPE, p_pg_status apps.xxdoec_order_manual_refunds.pg_status%TYPE, -- CCR0007157 Zendesk Manual Refunds Start
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         p_service_order_number apps.xxdoec_order_manual_refunds.service_order_number%TYPE, p_web_site_id apps.xxdoec_order_manual_refunds.web_site_id%TYPE, p_currency_code apps.xxdoec_order_manual_refunds.currency_code%TYPE, -- CCR0007157 Zendesk Manual Refunds End
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  x_return_status OUT VARCHAR2, x_error_text OUT VARCHAR2
                                          , x_refund_id OUT NUMBER);

    PROCEDURE insert_manual_refund_array (p_refund_tbl IN apps.xxdoec_Refund_tbl_Type, x_rtn_status OUT VARCHAR2, x_error_msg OUT VARCHAR2);

    PROCEDURE insert_manual_refund_dtls (
        p_header_id                 apps.xxdoec_manual_refund_pg_dtls.header_id%TYPE,
        p_line_group_id             apps.xxdoec_manual_refund_pg_dtls.line_group_id%TYPE,
        p_payment_type              apps.xxdoec_manual_refund_pg_dtls.payment_type%TYPE,
        p_payment_date              apps.xxdoec_manual_refund_pg_dtls.payment_date%TYPE,
        p_payment_amount            apps.xxdoec_manual_refund_pg_dtls.payment_amount%TYPE,
        p_pg_reference_num          apps.xxdoec_manual_refund_pg_dtls.pg_reference_num%TYPE,
        p_unapplied_amount          apps.xxdoec_manual_refund_pg_dtls.unapplied_amount%TYPE,
        p_status                    apps.xxdoec_manual_refund_pg_dtls.status%TYPE,
        -- CCR0007157 Zendesk Manual Refunds Start
        p_refund_id                 apps.xxdoec_manual_refund_pg_dtls.refund_id%TYPE,
        p_payment_tender_type       apps.xxdoec_manual_refund_pg_dtls.payment_tender_type%TYPE,
        p_currency_code             apps.xxdoec_manual_refund_pg_dtls.currency_code%TYPE,
        p_refund_reason             apps.xxdoec_manual_refund_pg_dtls.refund_reason%TYPE,
        -- CCR0007157 Zendesk Manual Refunds End
        x_return_status         OUT VARCHAR2,
        x_error_text            OUT VARCHAR2);
END XXDOEC_MANUAL_REFUND_PKG;
/
