--
-- XXD_BTOM_AVAILABILITY_PKG  (Package) 
--
--  Dependencies: 
--   ATP_COLOR_TABLE_TYPE (Type)
--   ATP_SIZE_TABLETYPE (Type)
--   MRP_ATP_PUB (Package)
--   XXD_ATP_ATR_TAB (Type)
--   XXD_ATP_STYLE_TAB (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_BTOM_AVAILABILITY_PKG"
    AUTHID CURRENT_USER
AS
    PROCEDURE get_atp_prc (p_atp_rec IN mrp_atp_pub.atp_rec_typ, x_atp_rec OUT NOCOPY mrp_atp_pub.atp_rec_typ, x_atp_supply_demand OUT NOCOPY mrp_atp_pub.atp_supply_demand_typ, x_atp_period OUT NOCOPY mrp_atp_pub.atp_period_typ, x_atp_details OUT NOCOPY mrp_atp_pub.atp_details_typ, x_return_status OUT NOCOPY VARCHAR2
                           , x_error_message OUT NOCOPY VARCHAR2);

    PROCEDURE get_atr_onhand_prc (x_qty_atr                OUT NUMBER,
                                  v_qty_oh                 OUT NUMBER,
                                  p_msg_data               OUT VARCHAR2,
                                  p_inventory_item_id   IN     NUMBER,
                                  p_organization_id     IN     NUMBER);

    PROCEDURE get_price_list_prc (p_inventory_item_id   IN     NUMBER,
                                  p_price_list_name     IN     VARCHAR2,
                                  p_org_id              IN     NUMBER,
                                  p_req_ship_date       IN     DATE,
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
                    x_primary_uom            OUT VARCHAR2, --added 10-Nov-2014
                    x_category_id            OUT NUMBER,
                    x_total_onhand_qty       OUT NUMBER,
                    x_total_atr_value        OUT NUMBER,
                    x_total_atp_value        OUT NUMBER,
                    y_operand                OUT NUMBER, -- Added by INFOSYS on 19thJul
                    z_operand                OUT NUMBER, -- Added by INFOSYS on 19thJul
                    P_OU                  IN     NUMBER -- Added by INFOSYS on 19thJul
                                                       );

    FUNCTION single_atp_result (x_qty_atr                OUT NUMBER,
                                v_qty_oh                 OUT NUMBER,
                                p_msg_data               OUT VARCHAR2,
                                p_inventory_item_id   IN     NUMBER,
                                p_organization_id     IN     NUMBER)
        RETURN NUMBER;

    PROCEDURE get_atp_future_dates (x_atp_style_out OUT xxd_atp_style_tab, x_atp_size_tabletype OUT atp_size_tabletype, x_atp_color_tabletype OUT atp_color_table_type, x_errflag OUT VARCHAR2, x_errmessage OUT VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER, p_style IN VARCHAR2, p_color IN VARCHAR2, p_org_id IN NUMBER, p_item_type IN VARCHAR2
                                    , p_qty_ordered IN NUMBER, p_req_ship_date IN DATE, p_demand_class_code IN VARCHAR2);
END XXD_BTOM_AVAILABILITY_PKG;
/
