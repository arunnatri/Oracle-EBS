--
-- XXDOEC_PROCESS_ORDER_LINES  (Package) 
--
--  Dependencies: 
--   FND_LOOKUP_VALUES (Synonym)
--   FND_USER (Synonym)
--   OE_REASONS (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_PROCESS_ORDER_LINES"
AS
    -- type declarations
    -- for REF cursors to return data to C#
    g_application   VARCHAR2 (300) := 'xxdo.xxdoec_process_order_lines';

    TYPE line_group_rectype IS RECORD
    (
        header_id                   NUMBER      --oe_order_lines_all.header_id
                                          ,
        line_grp_id                 VARCHAR2 (240)--oe_order_lines_all.attribute18
                                                  ,
        result_code                 VARCHAR2 (240)--oe_order_lines_all.attribute19
                                                  ,
        status_code                 VARCHAR2 (240)--oe_order_lines_all.attribute20
                                                  ,
        pgc_trans_num               VARCHAR2 (240)-- oe_order_lines_all.attribute16
                                                  ,
        header_id_orig_order        NUMBER-- original order header, referenced on a return
                                          ,
        line_grp_id_orig_order      VARCHAR2 (240)-- original line group, referenced on a return
                                                  ,
        pgc_trans_num_orig_order    VARCHAR2 (240)-- original PGC transaction id, referenced on a return
                                                  ,
        total_lines                 NUMBER
    -- total lines for this header_id (for CA)
    );

    TYPE order_header_rectype IS RECORD
    (
        header_id                      NUMBER --oe_order_headers_all.header_id
                                             ,
        orig_sys_document_ref          VARCHAR2 (50)--oe_order_headers_all.orig_sys_document_ref
                                                    ,
        account_number                 VARCHAR2 (50)--hz_cust_accounts.account_number
                                                    ,
        person_first_name              VARCHAR2 (150)--hz_parties.person_first_name
                                                     ,
        person_last_name               VARCHAR2 (150)--hz_parties.person_last_name
                                                     ,
        email_address                  VARCHAR2 (2000)--hz_parties.email_address
                                                      ,
        bill_to_address1               VARCHAR2 (240)  --hz_locations.address1
                                                     ,
        bill_to_address2               VARCHAR2 (240)  --hz_locations.address2
                                                     ,
        bill_to_city                   VARCHAR2 (60)       --hz_locations.city
                                                    ,
        bill_to_state                  VARCHAR2 (60)      --hz_locations.state
                                                    ,
        bill_to_postal_code            VARCHAR2 (60) --hz_locations.postal_code
                                                    ,
        bill_to_country                VARCHAR2 (60)    --hz_locations.country
                                                    ,
        ship_to_address1               VARCHAR2 (240)  --hz_locations.address1
                                                     ,
        ship_to_address2               VARCHAR2 (240)  --hz_locations.address2
                                                     ,
        ship_to_city                   VARCHAR2 (60)       --hz_locations.city
                                                    ,
        ship_to_state                  VARCHAR2 (60)      --hz_locations.state
                                                    ,
        ship_to_postal_code            VARCHAR2 (60) --hz_locations.postal_code
                                                    ,
        ship_to_country                VARCHAR2 (60)    --hz_locations.country
                                                    ,
        product_list_price_total       NUMBER--xxdoec_oe_order_totals.product_list_price_total
                                             ,
        product_selling_price_total    NUMBER--xxdoec_oe_order_totals.product_selling_price_total
                                             ,
        freight_charge_total           NUMBER--xxdoec_oe_order_totals.freight_charge_total
                                             ,
        gift_wrap_total                NUMBER--xxdoec_oe_order_totals.gift_wrap_total
                                             ,
        tax_total_no_vat               NUMBER--xxdoec_oe_order_totals.tax_total_no_vat
                                             ,
        vat_total                      NUMBER --xxdoec_oe_order_totals.vat_total
                                             ,
        order_total                    NUMBER--xxdoec_oe_order_totals.order_total
                                             ,
        discount_total                 NUMBER--xoopt.product_list_price_total - xoopt.product_selling_price_total
                                             ,
        freight_discount_total         NUMBER  --xooftt.freight_discount_total
                                             ,
        currency                       VARCHAR2 (15)--oe_order_headers_all.transactional_curr_code
                                                    ,
        locale                         VARCHAR2 (240)--hz_cust_accounts.attribute18
                                                     ,
        site                           VARCHAR2 (240)--hz_cust_accounts.attribute17
                                                     ,
        oraclegenerated                VARCHAR2 (1),
        order_type_id                  VARCHAR2 (240)--apps.oe_transaction_types_all.attribute13
                                                     ,
        original_order_number          VARCHAR2 (240),
        line_grp_id                    VARCHAR2 (240),
        --commented start by kcopeland 4/21/2016. This code was not ported from 12.1.3
        --Added 8/4/2014 KAC
        order_subtype                  VARCHAR (25), --oe_order_header_all.global_attribute18
        store_id                       VARCHAR (300), --oe_order_headers_all.global_attribute19
        contact_phone                  VARCHAR (40),
        --commented End by kcopeland 4/21/2016
        is_closet_order                VARCHAR2 (5),
        --Commented start: Added 7/11/2016 kcopeland
        is_emp_purch_order             VARCHAR (1),
        --Commented End

        --Comment Start Comment Added 11/22/2017 kcopeland v1.6
        cod_charge_total               NUMBER --xxdoec_oe_totals.cod_charge_total
    --Comment End

    --oe_order_lines_all.attribute18

    -- returned from xxdoec_order_utils_pkg.get_orig_order_id  -- INC0097749
    );

    TYPE order_line_rectype IS RECORD
    (
        upc                       VARCHAR2 (240)--mtl_system_items_b.attribute11
                                                ,
        model_number              VARCHAR2 (40)  --mtl_system_items_b.segment1
                                               ,
        color_code                VARCHAR2 (40)  --mtl_system_items_b.segment2
                                               ,
        color_name                VARCHAR2 (240)-- fnd_flex_values_vl.description (value_set 'DO_COLOR_CAT')
                                                ,
        product_size              VARCHAR2 (40)  --mtl_system_items_b.segment3
                                               ,
        product_name              VARCHAR2 (240)--mtl_system_items_b.description
                                                ,
        ordered_quantity          NUMBER --oe_order_lines_all.ordered_quantity
                                        ,
        unit_selling_price        NUMBER --oe_order_lines_all.unit_selling_price
                                        ,
        unit_list_price           NUMBER  --oe_order_lines_all.unit_list_price
                                        ,
        selling_price_subtotal    NUMBER--oe_order_lines_all.unit_selling_price * quantity
                                        ,
        list_price_subtotal       NUMBER--oe_order_lines_all.unit_list_price * quantity
                                        ,
        tracking_number           VARCHAR2 (30)--wsh_delivery_details.tracking_number
                                               ,
        carrier                   VARCHAR2 (30)    --wsh_carriers.freight_code
                                               ,
        shipping_method           VARCHAR2 (80)    --fnd_lookup_values.meaning
                                               ,
        line_number               NUMBER      --oe_order_lines_all.line_number
                                        ,
        line_id                   NUMBER          --oe_order_lines_all.line_id
                                        ,
        header_id                 NUMBER        --oe_order_lines_all.header_id
                                        ,
        line_grp_id               VARCHAR2 (240), --Added 02/08/2018 kcopeland v1.8
        inventory_item_id         NUMBER --mtl_system_items_b.inventory_item_id
                                        ,
        fluid_recipe_id           VARCHAR2 (50)-- oe.order_lines_all.customer_job
                                               ,
        organization_id           NUMBER  --mtl_system_items_b.organization_id
                                        ,
        freight_charge            NUMBER -- oe_price_adjustment.adjusted_amount
                                        ,
        freight_tax               NUMBER     --oe_price_adjustments.attribute5
                                        ,
        tax_amount                NUMBER --oe_price_adjustment.adjusted_amount
                                        ,
        gift_wrap_charge          NUMBER --oe_price_adjustment.adjusted_amount
                                        ,
        gift_wrap_tax             NUMBER,
        --return only zero right now - not implemented
        reason_code               apps.oe_reasons.reason_code%TYPE,
        --cancel reason code
        meaning                   apps.fnd_lookup_values.meaning%TYPE,
        --cancel reason meaning
        user_name                 apps.fnd_user.user_name%TYPE,
        --user who cancelled
        cancel_date               apps.oe_reasons.creation_date%TYPE,
        -- ref 2707455 - global_attributes to store localized values
        localized_size            VARCHAR2 (240),
        localized_color           VARCHAR2 (240),
        is_final_sale_item        VARCHAR2 (5),
        ship_to_address1          VARCHAR2 (240), --hz_locations.address1                                                  ,
        ship_to_address2          VARCHAR2 (240),      --hz_locations.address2
        ship_to_city              VARCHAR2 (60),           --hz_locations.city
        ship_to_state             VARCHAR2 (60),          --hz_locations.state
        ship_to_postal_code       VARCHAR2 (60),    --hz_locations.postal_code
        ship_to_country           VARCHAR2 (60),        --hz_locations.country
        site_use_id               NUMBER,
        --Comment Start Comment Added 11/22/2017 kcopeland v1.6
        cod_charge                NUMBER
    --Comment End
    );

    TYPE status_detail_rectype IS RECORD
    (
        header_id                NUMBER       --oe_order_headers_all.header_id
                                       ,
        line_grp_id              VARCHAR2 (240) --oe_order_lines_all.attribute18
                                               ,
        order_number             NUMBER   -- oe_order_headers_all.order_number
                                       ,
        orig_sys_document_ref    VARCHAR2 (50)--oe_order_headers_all.orig_sys_document_ref
                                              ,
        account_number           VARCHAR2 (50) --hz_cust_accounts.account_number
                                              ,
        currency                 VARCHAR2 (15)--oe_order_headers_all.transactional_curr_code
                                              ,
        locale                   VARCHAR2 (240) --hz_cust_accounts.attribute18
                                               ,
        site                     VARCHAR2 (240) --hz_cust_accounts.attribute17
                                               ,
        return_status            VARCHAR2 (240) --oe_order_lines_all.attribute17
    );

    TYPE status_summary_rectype IS RECORD
    (
        action              VARCHAR2 (240)-- oe_order_lines_all.attribute20 aka status_code
                                          ,
        total_count         NUMBER-- total line groups with this action assigned
                                  ,
        error_count         NUMBER         -- total line groups in error state
                                  ,
        manual_count        NUMBER        -- total line groups in manual state
                                  ,
        new_count           NUMBER           -- total line groups in new state
                                  ,
        processing_count    NUMBER    -- total line groups in processing state
                                  ,
        success_count       NUMBER       -- total line groups in success state
    );

    TYPE line_group_cur IS REF CURSOR
        RETURN line_group_rectype;

    TYPE order_header_cur IS REF CURSOR
        RETURN order_header_rectype;

    TYPE order_line_cur IS REF CURSOR
        RETURN order_line_rectype;

    TYPE status_detail_cur IS REF CURSOR
        RETURN status_detail_rectype;

    TYPE status_summary_cur IS REF CURSOR
        RETURN status_summary_rectype;

    TYPE tbl_header_id IS TABLE OF NUMBER
        INDEX BY PLS_INTEGER;

    TYPE ttbl_status_codes IS TABLE OF VARCHAR2 (64)
        INDEX BY BINARY_INTEGER;

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I');

    PROCEDURE cancel_expired_lines (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, --      p_header_id      IN       NUMBER,
                                                                                 p_order_number IN NUMBER
                                    , p_order_source IN VARCHAR2--Added by BT Technology Team on 29-Jan-2015
                                                                );

    PROCEDURE cancel_picked_lines (x_errbuf                OUT VARCHAR2,
                                   x_retcode               OUT NUMBER,
                                   p_delivery_id        IN     NUMBER,
                                   p_web_order_number   IN     VARCHAR2,
                                   p_item_number        IN     VARCHAR2);

    PROCEDURE cancel_line (p_line_id IN NUMBER, p_reason_code IN VARCHAR2, x_rtn_status OUT VARCHAR2
                           , x_rtn_msg_data OUT VARCHAR2);

    PROCEDURE create_cash_receipts_prepaid (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER);

    PROCEDURE apply_prepaid_rct_to_inv (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER);

    PROCEDURE prepaid_receipt_write_off (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_org_id IN NUMBER
                                         , p_order_header_id IN NUMBER);

    PROCEDURE create_cash_receipt (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER);

    PROCEDURE create_cm_adjustment (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_header_id IN NUMBER);

    PROCEDURE ship_confirm_delivery (p_delivery_id IN NUMBER, x_rtn_status OUT VARCHAR2, x_rtn_msg OUT VARCHAR2);

    FUNCTION get_email_ctr_value (p_header_id     IN NUMBER,
                                  p_line_grp_id   IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION evaluate_all_exchanges (p_header_id   IN NUMBER,
                                     p_seq         IN NUMBER,
                                     p_runnum      IN NUMBER)
        RETURN NUMBER;

    FUNCTION update_line_group_id (p_header_id   IN NUMBER,
                                   p_line_id     IN NUMBER := -1)
        RETURN NUMBER;

    FUNCTION get_sequence (p_header_id IN NUMBER)
        RETURN NUMBER;

    --  PROCEDURE get_line_groups_to_process(pn_header_id     IN NUMBER,
    --                                       p_line_group_cur OUT line_group_cur,
    --                                       pv_errbuf        OUT VARCHAR2,
    --                                       pn_retcode       OUT NUMBER);
    PROCEDURE get_line_groups_to_process_or (
        pn_header_id       IN     NUMBER,
        p_order_driver     IN     VARCHAR2,
        p_line_group_cur      OUT line_group_cur,
        pv_errbuf             OUT VARCHAR2,
        pn_retcode            OUT NUMBER);

    PROCEDURE get_line_groups_to_process_orn (pn_header_id IN NUMBER, p_order_driver IN VARCHAR2, p_count IN NUMBER, p_codes IN ttbl_status_codes, p_line_group_cur OUT line_group_cur, p_order_header_cur OUT order_header_cur
                                              , p_order_line_cur OUT order_line_cur, pv_errbuf OUT VARCHAR2, pn_retcode OUT NUMBER);

    PROCEDURE get_line_groups_to_process_re (
        pn_header_id       IN     NUMBER,
        p_order_driver     IN     VARCHAR2,
        p_line_group_cur      OUT line_group_cur,
        pv_errbuf             OUT VARCHAR2,
        pn_retcode            OUT NUMBER);

    PROCEDURE get_lines_in_group (pn_header_id IN NUMBER, pv_line_grp_id IN VARCHAR2, p_order_header_cur OUT order_header_cur
                                  , p_order_line_cur OUT order_line_cur, pv_errbuf OUT VARCHAR2, pn_retcode OUT NUMBER);

    PROCEDURE get_status_detail (
        pv_action             IN     VARCHAR2,
        p_status_detail_cur      OUT status_detail_cur);

    PROCEDURE get_status_summary (
        p_status_summary_cur OUT status_summary_cur);

    PROCEDURE progress_line_id (p_line_id IN NUMBER, p_result_code IN VARCHAR2, x_rtn_status OUT VARCHAR2
                                , x_rtn_msg_data OUT VARCHAR2);

    PROCEDURE progress_line (p_header_id IN NUMBER, p_line_grp_id IN VARCHAR2, p_status_code IN VARCHAR2
                             , p_result_code IN VARCHAR2, x_rtn_status OUT VARCHAR2, x_rtn_msg_data OUT VARCHAR2);

    -- original version
    -- this has been split into cancel_expired_lines and get_line_groups_to_process and get_lines_in_group
    PROCEDURE retry_payment_gateway_action (pn_header_id     IN     NUMBER -- header_id from oe_order_headers_all
                                                                          ,
                                            pv_line_grp_id   IN     VARCHAR2-- line group id, oe_order_lines_all.attribute18
                                                                            ,
                                            pb_is_charge     IN     NUMBER -- 1 to charge, 0 to credit
                                                                          ,
                                            pv_errbuf           OUT VARCHAR2-- any descriptive messages about actions/errors
                                                                            ,
                                            pn_retcode          OUT NUMBER -- 0 for success, 1 for error
                                                                          );

    PROCEDURE upd_pg_action_fail (pn_header_id IN NUMBER -- header_id from oe_order_headers_all
                                                        , pv_line_grp_id IN VARCHAR2-- line group id, oe_order_lines_all.attribute18
                                                                                    , pv_errbuf OUT VARCHAR2
                                  -- any descriptive messages about actions/errors
                                  , pn_retcode OUT NUMBER -- 0 for success, 1 for error
                                                         );

    PROCEDURE upd_pg_action_success (pn_header_id IN NUMBER -- header_id from oe_order_headers_all
                                                           , pv_line_grp_id IN VARCHAR2-- line group id, oe_order_lines_all.attribute18
                                                                                       , pv_errbuf OUT VARCHAR2
                                     -- any descriptive messages about actions/errors
                                     , pn_retcode OUT NUMBER -- 0 for success, 1 for error
                                                            );

    PROCEDURE set_email_ctr_value (p_header_id      IN     NUMBER,
                                   p_line_grp_id    IN     VARCHAR2,
                                   p_ctr_value      IN     NUMBER,
                                   x_rtn_status        OUT VARCHAR2,
                                   x_rtn_msg_data      OUT VARCHAR2);

    PROCEDURE update_line_group_result (pn_header_id       IN     NUMBER,
                                        pv_line_grp_id     IN     VARCHAR2,
                                        pv_status_code     IN     VARCHAR2,
                                        pv_rtn_status      IN     VARCHAR2,
                                        pv_result_code     IN     VARCHAR2,
                                        pv_pgc_trans_num   IN     VARCHAR2-- on PG auth actions: payment gateway PGResponse.FollowupPGResponseId
                                                                          ,
                                        pv_errbuf             OUT VARCHAR2,
                                        pn_retcode            OUT NUMBER);

    PROCEDURE insert_order_payment_detail (pn_header_id IN NUMBER, pv_line_grp_id IN VARCHAR2, pn_payment_amount IN NUMBER, pd_payment_date IN DATE, pn_payment_trx_id IN NUMBER, pv_payment_type IN VARCHAR2, pv_pg_ref_num IN VARCHAR2, pv_status IN VARCHAR2, pv_web_order_number IN VARCHAR2, pv_pg_action IN VARCHAR2, pv_prepaid_flag IN VARCHAR2, pv_payment_tender_type IN VARCHAR2
                                           , pv_transaction_ref_num IN VARCHAR2, pn_retcode OUT NUMBER, pv_errbuf OUT VARCHAR2);

    PROCEDURE get_orig_pgc_trans_num (p_cust_po_number       IN     VARCHAR2,
                                      x_orig_pgc_trans_num      OUT VARCHAR);

    PROCEDURE get_orig_pgc_trans_num_by_line (
        p_line_id              IN     NUMBER,
        x_orig_pgc_trans_num      OUT VARCHAR);

    PROCEDURE upd_line_status_by_line_id (p_line_id IN NUMBER, p_state IN VARCHAR2, p_status IN VARCHAR2
                                          , p_outcome IN VARCHAR2, x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER);

    PROCEDURE upd_line_status_by_group_id (p_line_grp_id IN NUMBER, p_state IN VARCHAR2, p_status IN VARCHAR2
                                           , p_outcome IN VARCHAR2, x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER);

    FUNCTION get_line_id (p_line_num            IN NUMBER,
                          p_cust_order_number   IN VARCHAR2)
        RETURN NUMBER;
END xxdoec_process_order_lines;
/


--
-- XXDOEC_PROCESS_ORDER_LINES  (Synonym) 
--
--  Dependencies: 
--   XXDOEC_PROCESS_ORDER_LINES (Package)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDOEC_PROCESS_ORDER_LINES FOR APPS.XXDOEC_PROCESS_ORDER_LINES
/


GRANT EXECUTE ON APPS.XXDOEC_PROCESS_ORDER_LINES TO SOA_INT
/
