--
-- XXD_BTOM_MULTI_ATP  (Package) 
--
--  Dependencies: 
--   XXD_BTOM_MULTI_ATP_TBLTYPE (Type)
--   XXD_BTOM_OEHEADER_TBLTYPE (Type)
--   XXD_BTOM_OELINE_ATP_TBLTYPE (Type)
--   XXD_BTOM_OELINE_TBLTYPE (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_BTOM_MULTI_ATP"
AS
    PROCEDURE get_multi_atp_check (
        p_multi_atp_tbl   IN     XXD_BTOM_MULTI_ATP_TBLTYPE,
        p_org_id          IN     NUMBER,
        p_user_id         IN     NUMBER,
        p_resp_id         IN     NUMBER,
        p_resp_app_id     IN     NUMBER,
        x_multi_atp_tbl      OUT xxd_btom_multi_atp_tbltype,
        x_sum_atp            OUT NUMBER,
        x_sum_atr            OUT NUMBER,
        x_sum_onhand         OUT NUMBER,
        x_error_message      OUT VARCHAR2,
        x_error_code         OUT VARCHAR2);

    PROCEDURE get_atr_onhand_prc (x_qty_atr                OUT NUMBER,
                                  v_qty_oh                 OUT NUMBER,
                                  p_msg_data               OUT VARCHAR2,
                                  p_inventory_item_id   IN     NUMBER,
                                  p_organization_id     IN     NUMBER);

    PROCEDURE get_oe_lines_record (p_header_id IN NUMBER, x_multi_atp_tbl OUT XXD_BTOM_OELINE_ATP_TBLTYPE, p_style IN VARCHAR2
                                   ,            --Added by Infosys-26-Aug-2016
                                     p_color IN VARCHAR2 --Added by Infosys-26-Aug-2016
                                                        );

    PROCEDURE modify_order (p_header_rec      IN     XXD_BTOM_OEHEADER_TBLTYPE,
                            p_line_tbl        IN     XXD_BTOM_OELINE_TBLTYPE,
                            p_user_id         IN     NUMBER,
                            p_resp_id         IN     NUMBER,
                            p_resp_app_id     IN     NUMBER,
                            p_action          IN     VARCHAR2,
                            p_call_from       IN     VARCHAR2,
                            x_error_flag         OUT VARCHAR2,
                            x_error_message      OUT VARCHAR2,
                            p_cancel_code     IN     VARCHAR2 --Added by Infosys-26-Aug-2016
                                                             ,
                            p_cancel_reason   IN     VARCHAR2 --Added by Infosys-26-Aug-2016
                                                             );

    PROCEDURE check_invorg_item_define (p_multi_atp_tbl IN XXD_BTOM_MULTI_ATP_TBLTYPE, x_error_message OUT VARCHAR2, x_error_code OUT VARCHAR2);
END XXD_BTOM_MULTI_ATP;
/
