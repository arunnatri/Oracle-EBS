--
-- XXDOEC_INVENTORY  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--   XXDOEC_INVENTORY (Table)
--
/* Formatted on 4/26/2023 4:12:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_INVENTORY"
AS
    --  ####################################################################################################
    --  Package      : XXDOEC_INVENTORY
    --  Design       : This package is for ATP calculation.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  13-Aug-2020     1.0        Showkath Ali             CCR0008765 changes
    --  ####################################################################################################


    TYPE inventory_feed
        IS RECORD
    (
        upc                    xxdo.xxdoec_inventory.upc%TYPE,
        atp_quantity           xxdo.xxdoec_inventory.atp_qty%TYPE,
        atp_date               xxdo.xxdoec_inventory.atp_date%TYPE,
        is_perpetual           xxdo.xxdoec_inventory.is_perpetual%TYPE,
        pre_back_order_mode    xxdo.xxdoec_inventory.pre_back_order_mode%TYPE,
        pre_back_order_qty     xxdo.xxdoec_inventory.pre_back_order_qty%TYPE,
        pre_back_order_date    xxdo.xxdoec_inventory.pre_back_order_date%TYPE
    );

    TYPE t_inventory_feed_cursor IS REF CURSOR
        RETURN inventory_feed;

    TYPE inventory_feed_ca IS RECORD
    (
        upc             xxdo.xxdoec_inventory.upc%TYPE,
        sku             xxdo.xxdoec_inventory.sku%TYPE,
        atp_quantity    xxdo.xxdoec_inventory.atp_qty%TYPE,
        atp_date        xxdo.xxdoec_inventory.atp_date%TYPE
    );

    TYPE t_inventory_feed_cursor_ca IS REF CURSOR
        RETURN inventory_feed_ca;

    TYPE inventory_report
        IS RECORD
    (
        upc                    xxdo.xxdoec_inventory.upc%TYPE,
        sku                    xxdo.xxdoec_inventory.sku%TYPE,
        inventory_item_id      xxdo.xxdoec_inventory.inventory_item_id%TYPE,
        atp_qty                xxdo.xxdoec_inventory.atp_qty%TYPE,
        atp_date               xxdo.xxdoec_inventory.atp_date%TYPE,
        pre_back_order_mode    xxdo.xxdoec_inventory.pre_back_order_mode%TYPE,
        pre_back_order_qty     xxdo.xxdoec_inventory.pre_back_order_qty%TYPE,
        pre_back_order_date    xxdo.xxdoec_inventory.pre_back_order_date%TYPE,
        atp_when_atr           xxdo.xxdoec_inventory.atp_when_atr%TYPE,
        kco_remaining_qty      xxdo.xxdoec_inventory.kco_remaining_qty%TYPE,
        consumed_date          xxdo.xxdoec_inventory.consumed_date%TYPE,
        consumed_date_ca       xxdo.xxdoec_inventory.consumed_date_ca%TYPE
    );

    TYPE trec_quantity IS RECORD
    (
        inv_item_id      NUMBER,
        inv_org_id       NUMBER,
        brand            VARCHAR (64),
        quantity         NUMBER,
        quantity_date    DATE
    );                         -- remember order of fields must match query...

    TYPE ttbl_quantity IS TABLE OF trec_quantity;

    TYPE trec_kco_quantity IS RECORD
    (
        kco_hdr_id     NUMBER,
        inv_org_id     NUMBER,
        inv_item_id    NUMBER,
        inv_date       DATE,
        quantity       NUMBER
    );

    TYPE ttbl_kco_quantity IS TABLE OF trec_kco_quantity;

    TYPE item_t IS RECORD
    (
        inventory_item_id       NUMBER,
        sr_inventory_item_id    NUMBER,
        sku                     VARCHAR (64),
        upc                     VARCHAR2 (64),
        stock_buffer            NUMBER,
        preorder                NUMBER
    );

    TYPE inv_atp_t IS RECORD
    (
        INV_ORG_ID            NUMBER,
        ATP_QTY               NUMBER,
        ATP_WHEN_ATR          NUMBER,
        BACK_PRE_ORDER_QTY    NUMBER,
        AVAILABLE_DATE        DATE
    );

    TYPE t_inv_atp_cursor IS REF CURSOR
        RETURN inv_atp_t;

    TYPE ttbl_item IS TABLE OF item_t;

    TYPE ttbl_code IS TABLE OF VARCHAR2 (64);

    -- Associative Arrays
    TYPE tatbl_item IS TABLE OF item_t
        INDEX BY PLS_INTEGER;

    TYPE ttbl_inv_orgs IS TABLE OF NUMBER
        INDEX BY PLS_INTEGER;

    TYPE tatbl_int1 IS TABLE OF NUMBER
        INDEX BY PLS_INTEGER;

    TYPE tatbl_int2 IS TABLE OF tatbl_int1
        INDEX BY PLS_INTEGER;

    TYPE tatbl_int3 IS TABLE OF tatbl_int2
        INDEX BY PLS_INTEGER;

    TYPE tatbl_int4 IS TABLE OF tatbl_int3
        INDEX BY PLS_INTEGER;

    TYPE tatbl_brand IS TABLE OF tatbl_int2
        INDEX BY VARCHAR2 (64);

    TYPE tatbl_inv_org IS TABLE OF tatbl_brand
        INDEX BY PLS_INTEGER;

    TYPE t_upc_array IS TABLE OF xxdo.xxdoec_inventory.upc%TYPE
        INDEX BY BINARY_INTEGER;

    TYPE t_upc_quantity_cursor IS REF CURSOR;

    TYPE t_upc_report_cursor IS REF CURSOR;

    /* Public Routines */
    PROCEDURE xxdoec_update_atp_table (x_ret_status OUT VARCHAR2, x_retcode OUT NUMBER, p_feed_code IN VARCHAR2 DEFAULT NULL
                                       , p_net_change IN VARCHAR2 DEFAULT 'Y', p_generate_control_file IN VARCHAR2 DEFAULT 'N' --1.0
                                                                                                                              );

    PROCEDURE xxdoec_get_inventory (
        p_net_change        IN     CHAR,
        o_inventory_items      OUT t_inventory_feed_cursor,
        p_group_code               VARCHAR2 DEFAULT NULL,
        o_return_code          OUT NUMBER,
        o_return_message       OUT VARCHAR2);


    PROCEDURE xxdoec_get_inventory_ca (p_max_records IN NUMBER, o_inventory_items OUT t_inventory_feed_cursor_ca, p_site_id VARCHAR2
                                       , o_consumed_date OUT DATE, o_return_code OUT NUMBER, o_return_message OUT VARCHAR2);

    PROCEDURE xxdoec_reset_inventory_ca (p_site_id VARCHAR2, o_return_code OUT NUMBER, o_return_message OUT VARCHAR2);

    PROCEDURE xxdoec_reset_inventory_set_ca (p_consumed_date DATE);

    PROCEDURE xxdoec_get_upc_quantity (p_list IN t_upc_array, p_site_id IN VARCHAR2, o_upc_quantity_cursor OUT t_upc_quantity_cursor);

    PROCEDURE get_upc_report (
        p_list                IN     t_upc_array,
        p_site_id             IN     VARCHAR2,
        o_upc_report_cursor      OUT t_upc_report_cursor);

    /* Internal Routines */
    FUNCTION net_qty_crs (p_feed_code   IN VARCHAR2,
                          p_date        IN DATE DEFAULT NULL)
        RETURN SYS_REFCURSOR;

    FUNCTION net_qty_tbl (p_feed_code   IN VARCHAR2,
                          p_date        IN DATE DEFAULT NULL)
        RETURN ttbl_quantity;

    FUNCTION net_qty_atbl (p_feed_code   IN VARCHAR2,
                           p_date        IN DATE DEFAULT NULL)
        RETURN tatbl_inv_org;

    FUNCTION kco_qty_crs (p_feed_code   IN VARCHAR2,
                          p_date        IN DATE DEFAULT NULL)
        RETURN SYS_REFCURSOR;

    FUNCTION kco_qty_tbl (p_feed_code   IN VARCHAR2,
                          p_date        IN DATE DEFAULT NULL)
        RETURN ttbl_kco_quantity;

    FUNCTION kco_qty_atbl (p_feed_code   IN VARCHAR2,
                           p_date        IN DATE DEFAULT NULL)
        RETURN tatbl_int4;

    FUNCTION items_crs (p_feed_code IN VARCHAR2)
        RETURN SYS_REFCURSOR;

    FUNCTION items_tbl (p_feed_code IN VARCHAR2)
        RETURN ttbl_item;

    FUNCTION items_atbl (p_feed_code IN VARCHAR2)
        RETURN tatbl_item;

    FUNCTION get_kco_quantity (p_kco_quantities IN tatbl_int4, p_inv_org_id IN NUMBER, p_item_id IN NUMBER
                               , p_numdate IN NUMBER, p_kco_hdr_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_kco_remaining_quantity (p_kco_quantities   IN tatbl_int4,
                                         p_inv_org_id       IN NUMBER,
                                         p_item_id          IN NUMBER,
                                         p_numdate          IN NUMBER,
                                         p_kco_hdr_id       IN NUMBER)
        RETURN NUMBER;


    PROCEDURE xxdoec_get_atp_for_upc (
        p_item_upc              IN     VARCHAR2,
        p_inv_region            IN     VARCHAR2,
        p_brand                 IN     VARCHAR2,
        p_demand_class_code     IN     VARCHAR2,
        p_inv_org_ids           IN     ttbl_inv_orgs,
        x_ret_status               OUT VARCHAR2,
        o_upc_quantity_cursor      OUT t_inv_atp_cursor);

    --1.0 changes start
    PROCEDURE xxdoec_generate_data_file (
        p_errbuf          OUT VARCHAR2,
        p_retcode         OUT NUMBER,
        p_feed_code    IN     VARCHAR2 DEFAULT NULL,
        p_net_change   IN     VARCHAR2 DEFAULT 'Y');
END XXDOEC_INVENTORY;
/
