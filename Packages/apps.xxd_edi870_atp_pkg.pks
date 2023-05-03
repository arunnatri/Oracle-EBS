--
-- XXD_EDI870_ATP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_EDI870_ATP_PKG"
    AUTHID CURRENT_USER
AS
    PROCEDURE get_atp_val_prc (x_atp_qty OUT NUMBER, p_msg_data OUT VARCHAR2, p_err_code OUT VARCHAR2, p_inventory_item_id IN NUMBER, p_org_id IN NUMBER, p_primary_uom_code IN VARCHAR2, p_source_org_id IN NUMBER, p_qty_ordered IN NUMBER, p_req_ship_date IN DATE
                               , p_demand_class_code IN VARCHAR2, x_req_date_qty OUT NUMBER, x_available_date OUT DATE);

    FUNCTION single_atp_result_test (
        p_inventory_item_id   IN NUMBER,
        p_org_id              IN NUMBER,
        p_primary_uom_code    IN VARCHAR2 DEFAULT 'Y',
        p_source_org_id       IN NUMBER := NULL,
        p_qty_ordered         IN NUMBER := NULL,
        p_req_ship_date       IN DATE := TRUNC (SYSDATE),
        p_demand_class_code   IN VARCHAR2 DEFAULT 'Y'--                                    , p_msg_data            OUT      VARCHAR2
                                                     --                                    , p_err_code            OUT      VARCHAR2
                                                     --                         , p_request_date in date := trunc(sysdate)
                                                     --                         , p_show_oversold in varchar2 := 'Y'
                                                     --                         , p_kco_header_id in number := null
                                                     --                         , p_use_snapshot in varchar2 := 'N'
                                                     )
        RETURN NUMBER;

    --                          p_msg_data     VARCHAR2;
    --                          p_err_code    VARCHAR2;
    PROCEDURE get_atp_prc (x_atp_qty OUT NUMBER, p_msg_data OUT VARCHAR2, p_err_code OUT VARCHAR2, p_inventory_item_id IN NUMBER, p_org_id IN NUMBER, p_PRIMARY_UOM_CODE IN VARCHAR2, p_source_org_id IN NUMBER, P_qty_ordered IN NUMBER, p_req_ship_date IN DATE
                           , p_demand_class_code IN VARCHAR2);
/* This procedures are not in used anywhere in the code. Hence commenting.
   PROCEDURE get_atr_onhand_prc (x_qty_atr                OUT NUMBER,
                                 v_qty_oh                 OUT NUMBER,
                                 p_msg_data               OUT VARCHAR2,
                                 p_inventory_item_id   IN     NUMBER,
                                 p_organization_id     IN     NUMBER);

   PROCEDURE get_price_list_prc (p_inventory_item_id   IN     NUMBER,
                                 p_price_list_name     IN     VARCHAR2,
                                 p_org_id              IN     NUMBER,
                                 p_operand                OUT NUMBER);



   PROCEDURE get_atp_for_style (
      x_atp_style_out            OUT XXD_ATP_STYLE_TAB,
      x_atp_size_tableType       OUT atp_size_tableType,
      x_atp_color_tableType      OUT atp_color_table_Type,
      x_errflag                  OUT VARCHAR2,
      x_errmessage               OUT VARCHAR2,
      p_user_id               IN     NUMBER,
      p_resp_id               IN     NUMBER,
      p_resp_appl_id          IN     NUMBER,
      p_style                 IN     VARCHAR2,
      p_org_id                IN     NUMBER,
      p_item_type             IN     VARCHAR2,
      P_qty_ordered           IN     NUMBER,
      p_req_ship_date         IN     DATE,
      p_demand_class_code     IN     VARCHAR2);


   PROCEDURE MAIN (x_errflag                OUT VARCHAR2,
                   x_errmessage             OUT VARCHAR2,
                   x_operand                OUT NUMBER,
                   x_atp_atr_tab_out        OUT XXD_ATP_ATR_TAB,
                   p_user_id             IN     NUMBER,
                   p_resp_id             IN     NUMBER,
                   p_resp_appl_id        IN     NUMBER,
                   p_style               IN     VARCHAR2,
                   p_color               IN     VARCHAR2,
                   p_org_id              IN     NUMBER,
                   p_item_type           IN     VARCHAR2,
                   p_price_list_name     IN     VARCHAR2,
                   p_source_org_id       IN     NUMBER,
                   P_qty_ordered         IN     NUMBER,
                   p_req_ship_date       IN     DATE,
                   p_demand_class_code   IN     VARCHAR2,
                   x_primary_uom            OUT VARCHAR2,  --added 10-Nov-2014
                   x_category_id            OUT NUMBER,
                   x_total_onhand_qty       OUT NUMBER,
                   x_total_atr_value        OUT NUMBER,
                   x_total_atp_value        OUT NUMBER);
       */
END XXD_EDI870_ATP_PKG;
/
