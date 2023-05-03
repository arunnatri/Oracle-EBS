--
-- XXD_SALES_ORDER_PKG  (Package) 
--
--  Dependencies: 
--   XXD_BTOM_APPLY_PRICE_ADJ_TBL (Type)
--   XXD_BTOM_OEHEADER_TBLTYPE (Type)
--   XXD_BTOM_OELINE_TBLTYPE (Type)
--   XXD_DOE_PRICE_ADJTMNT_TBLTYPE (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:33 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_SALES_ORDER_PKG"
IS
    --This procedure is used to create sales order
    PROCEDURE create_order (p_header_rec IN xxd_btom_oeheader_tbltype, p_line_tbl IN xxd_btom_oeline_tbltype, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, p_action IN VARCHAR2, p_call_from IN VARCHAR2, x_header_id OUT VARCHAR2, x_error_flag OUT VARCHAR2
                            , x_error_message OUT VARCHAR2, x_atp_error_message OUT VARCHAR2, x_atp_error_flag OUT VARCHAR2);

    --This procedure is used to book sales order
    PROCEDURE book_order (p_header_id       IN     NUMBER,
                          p_org_id          IN     NUMBER,
                          p_user_id         IN     NUMBER,
                          p_resp_id         IN     NUMBER,
                          p_resp_app_id     IN     NUMBER,
                          p_call_from       IN     VARCHAR2,
                          x_error_flag         OUT VARCHAR2,
                          x_error_message      OUT VARCHAR2);

    --This procedure is used to modify sales order
    PROCEDURE modify_order (p_header_rec          IN     xxd_btom_oeheader_tbltype,
                            p_line_tbl            IN     xxd_btom_oeline_tbltype,
                            p_user_id             IN     NUMBER,
                            p_resp_id             IN     NUMBER,
                            p_resp_app_id         IN     NUMBER,
                            p_action              IN     VARCHAR2,
                            p_call_from           IN     VARCHAR2,
                            x_error_flag             OUT VARCHAR2,
                            x_error_message          OUT VARCHAR2,
                            x_atp_error_message      OUT VARCHAR2,
                            x_atp_error_flag         OUT VARCHAR2);

    --This procedure is used to cancel sales order
    PROCEDURE cancel_order_header_line (p_header_rec IN xxd_btom_oeheader_tbltype, p_line_tbl IN xxd_btom_oeline_tbltype, p_org_id IN NUMBER, p_call_form IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                        , p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE apply_hold_header_line (p_header_rec IN xxd_btom_oeheader_tbltype, p_line_tbl IN xxd_btom_oeline_tbltype, p_org_id IN NUMBER, p_call_form IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                      , p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE release_hold_header_line (p_header_rec IN xxd_btom_oeheader_tbltype, p_line_tbl IN xxd_btom_oeline_tbltype, p_org_id IN NUMBER, p_call_form IN VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER
                                        , p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE check_atp_qty (p_inv_item_id          NUMBER,
                             p_requested_date       DATE,
                             p_warehouse_id         NUMBER,
                             p_demand_class         VARCHAR2,
                             p_quantity             NUMBER,
                             p_order_line_id        NUMBER,
                             p_uom                  VARCHAR2,
                             x_error_message    OUT VARCHAR2,
                             x_atp_error_flag   OUT VARCHAR2);

    PROCEDURE delete_order_header (p_header_id IN NUMBER, p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2
                                   , x_error_message OUT VARCHAR2);

    PROCEDURE delete_order_line (p_line_tbl IN xxd_btom_oeline_tbltype, p_org_id IN NUMBER, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_app_id IN NUMBER, x_error_flag OUT VARCHAR2
                                 , x_error_message OUT VARCHAR2);

    PROCEDURE apply_header_price_adjustment (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER
                                             , p_price_adjment_tbl IN xxd_doe_price_adjtmnt_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE apply_line_price_adjustment (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER
                                           , p_price_adjment_tbl IN xxd_doe_price_adjtmnt_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);

    PROCEDURE get_line_price_adj_details (
        p_user_id             IN            NUMBER,
        p_resp_id             IN            NUMBER,
        p_resp_appl_id        IN            NUMBER,
        p_level               IN            VARCHAR2,
        p_entity_id           IN            NUMBER,
        x_modifier_line_tbl      OUT NOCOPY xxd_btom_apply_price_adj_tbl,
        x_error_flag             OUT        VARCHAR2,
        x_error_message          OUT        VARCHAR2);

    PROCEDURE delete_order_price_adjustment (p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER
                                             , p_price_adjment_tbl IN xxd_doe_price_adjtmnt_tbltype, x_error_flag OUT VARCHAR2, x_error_message OUT VARCHAR2);
END XXD_SALES_ORDER_PKG;
/
