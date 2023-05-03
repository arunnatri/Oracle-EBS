--
-- XXD_INV_COMMON_UTILS_X_PK  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_COMMON_UTILS_X_PK"
AS
    /******************************************************************************************
    -- Modification History:
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 06-Jan-2015  1.0        BT Technology Team      Initial Version
    -- 23-May-2019  1.1        Viswanathan Pandian     Modified for CCR0007687
    ******************************************************************************************/
    -- Global Variables
    gn_user_id             fnd_user.user_id%TYPE;
    gn_responsibility_id   fnd_responsibility.responsibility_id%TYPE;
    gn_application_id      fnd_application.application_id%TYPE;

    /******************************************************************************************
    -- Modification History:
    -- Public Procedure: GET_ATP_DETAILS_PRC
    -- Date         Version#   Name                    Comments
    -- 06-Jan-2015  1.0        BT Technology Team      To derive ATP details
    ******************************************************************************************/
    PROCEDURE get_atp_details_prc (p_inventory_item_id IN mtl_system_items_b.inventory_item_id%TYPE, p_inventory_item_name IN mtl_system_items_b.segment1%TYPE DEFAULT NULL, p_quantity_ordered IN oe_order_lines.ordered_quantity%TYPE, p_quantity_uom IN oe_order_lines.order_quantity_uom%TYPE, p_requested_ship_date IN oe_order_lines.request_date%TYPE, p_source_organization_id IN mtl_system_items_b.organization_id%TYPE, p_demand_class IN oe_order_headers.demand_class_code%TYPE, x_atp_rec OUT NOCOPY mrp_atp_pub.atp_rec_typ, x_atp_supply_demand OUT NOCOPY mrp_atp_pub.atp_supply_demand_typ, x_atp_period OUT NOCOPY mrp_atp_pub.atp_period_typ, x_atp_details OUT NOCOPY mrp_atp_pub.atp_details_typ, x_return_status OUT NOCOPY VARCHAR2
                                   , x_error_message OUT NOCOPY VARCHAR2)
    AS
        l_atp_rec       mrp_atp_pub.atp_rec_typ;
        lc_msg_data     VARCHAR2 (500);
        lc_msg_dummy    VARCHAR2 (1000);
        ln_msg_count    NUMBER;
        ln_session_id   NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Begin Item Availability Results');
        -- Initialize
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_responsibility_id,
                                    resp_appl_id   => gn_application_id);
        msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);
        l_atp_rec.inventory_item_id (1)          := p_inventory_item_id;

        IF p_inventory_item_name IS NOT NULL
        THEN
            l_atp_rec.inventory_item_name (1)   := p_inventory_item_name;
        END IF;

        l_atp_rec.quantity_ordered (1)           := p_quantity_ordered;
        l_atp_rec.quantity_uom (1)               := p_quantity_uom;
        l_atp_rec.requested_ship_date (1)        := p_requested_ship_date;
        l_atp_rec.source_organization_id (1)     := p_source_organization_id;
        l_atp_rec.demand_class (1)               := p_demand_class;
        l_atp_rec.action (1)                     := 100;
        l_atp_rec.instance_id (1)                := 61;
        -- needed when using calling_module = 724, use msc_system_items.sr_instance_id
        l_atp_rec.oe_flag (1)                    := 'N';
        l_atp_rec.insert_flag (1)                := 1;
        -- Hardcoded value for profile MRP:Calculate Supply Demand 0= NO
        l_atp_rec.attribute_04 (1)               := 1;
        -- With this Attribute set to 1 this will enable the Period (Horizontal Plan),
        l_atp_rec.customer_id (1)                := NULL;
        l_atp_rec.customer_site_id (1)           := NULL;
        l_atp_rec.calling_module (1)             := NULL;
        l_atp_rec.row_id (1)                     := NULL;
        l_atp_rec.source_organization_code (1)   := NULL;
        l_atp_rec.organization_id (1)            := NULL;
        l_atp_rec.order_number (1)               := NULL;
        l_atp_rec.line_number (1)                := NULL;
        l_atp_rec.override_flag (1)              := 'N';

        SELECT oe_order_sch_util.get_session_id INTO ln_session_id FROM DUAL;

        apps.mrp_atp_pub.call_atp (ln_session_id,
                                   l_atp_rec,
                                   x_atp_rec,
                                   x_atp_supply_demand,
                                   x_atp_period,
                                   x_atp_details,
                                   x_return_status,
                                   lc_msg_data,
                                   ln_msg_count);

        IF (x_return_status = 'S')
        THEN
            FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
            LOOP
                x_error_message   := '';

                IF (x_atp_rec.ERROR_CODE (i) <> 0)
                THEN
                    SELECT meaning
                      INTO x_error_message
                      FROM mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = x_atp_rec.ERROR_CODE (i);

                    x_return_status                    := 'E';
                    x_atp_rec.available_quantity (i)   := 0;
                    x_atp_rec.arrival_date (i)         := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error Message      : ' || x_error_message);
                END IF;
            END LOOP;
        ELSE
            FOR i IN 1 .. ln_msg_count
            LOOP
                fnd_msg_pub.get (i, fnd_api.g_false, lc_msg_data,
                                 lc_msg_dummy);
                x_error_message   := (TO_CHAR (i) || ': ' || lc_msg_data);
            END LOOP;

            fnd_file.put_line (fnd_file.LOG,
                               'Return Message = ' || x_error_message);
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'Item Availability Results Status - ' || x_return_status);
        fnd_file.put_line (fnd_file.LOG, 'End Item Availability Results');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Others Exception :' || SQLERRM);
            x_return_status   := 'E';
            x_error_message   := SUBSTR (SQLERRM, 1, 2000);
    END get_atp_details_prc;

    PROCEDURE get_atp_batch_prc (p_atp_rec IN mrp_atp_pub.atp_rec_typ, -- p_inventory_item_id     IN              mtl_system_items_b.inventory_item_id%TYPE,
                                                                       --  p_inventory_item_name   IN              mtl_system_items_b.segment1%TYPE
                                                                       --       DEFAULT NULL,
                                                                       x_atp_rec OUT NOCOPY mrp_atp_pub.atp_rec_typ, x_atp_supply_demand OUT NOCOPY mrp_atp_pub.atp_supply_demand_typ, x_atp_period OUT NOCOPY mrp_atp_pub.atp_period_typ, x_atp_details OUT NOCOPY mrp_atp_pub.atp_details_typ, x_return_status OUT NOCOPY VARCHAR2
                                 , x_error_message OUT NOCOPY VARCHAR2)
    AS
        l_atp_rec      mrp_atp_pub.atp_rec_typ;
        lc_msg_data    VARCHAR2 (500);
        lc_msg_dummy   VARCHAR2 (1000);
        ln_msg_count   NUMBER;
        l_session_id   NUMBER;
        lc_var         VARCHAR2 (2000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Begin ATP Results');
        fnd_global.apps_initialize (user_id        => 0,
                                    resp_id        => 21634,
                                    resp_appl_id   => 724);


        l_atp_rec   := p_atp_rec;

        --      msc_atp_global.extend_atp (l_atp_rec,
        --                                 x_return_status,
        --                                 p_atp_rec.inventory_item_id.COUNT
        --                                );
        -- l_atp_rec.inventory_item_id (1) := p_inventory_item_id;

        /* IF p_inventory_item_name IS NOT NULL
         THEN
            l_atp_rec.inventory_item_name (1) := p_inventory_item_name;
         END IF;*/

        SELECT oe_order_sch_util.get_session_id INTO l_session_id FROM DUAL;

        msc_atp_global.get_atp_session_id (l_session_id, lc_var);
        apps.mrp_atp_pub.call_atp (l_session_id,
                                   l_atp_rec,
                                   x_atp_rec,
                                   x_atp_supply_demand,
                                   x_atp_period,
                                   x_atp_details,
                                   x_return_status,
                                   lc_msg_data,
                                   ln_msg_count);

        IF (x_return_status = 'S')
        THEN
            FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
            LOOP
                x_error_message   := '';

                IF (x_atp_rec.ERROR_CODE (i) <> 0)
                THEN
                    SELECT meaning
                      INTO x_error_message
                      FROM mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = x_atp_rec.ERROR_CODE (i);

                    x_return_status                    := 'E';
                    x_atp_rec.available_quantity (i)   := 0;
                    x_atp_rec.arrival_date (i)         := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error Message      : ' || x_error_message);
                END IF;
            END LOOP;
        ELSE
            FOR i IN 1 .. ln_msg_count
            LOOP
                fnd_msg_pub.get (i, fnd_api.g_false, lc_msg_data,
                                 lc_msg_dummy);
                x_error_message   := (TO_CHAR (i) || ': ' || lc_msg_data);
            END LOOP;

            fnd_file.put_line (fnd_file.LOG,
                               'Return Message = ' || x_error_message);
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'ATP Results Status - ' || x_return_status);
        fnd_file.put_line (fnd_file.LOG, 'End ATP Results Status');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Others Exception :' || SQLERRM);
            x_return_status   := 'E';
            x_error_message   := SUBSTR (SQLERRM, 1, 2000);
    END get_atp_batch_prc;

    /******************************************************************************************
    -- Modification History:
    -- Public Procedure: GET_ATR_DETAILS_PRC
    -- Date         Version#   Name                    Comments
    -- 06-Jan-2015  1.0        BT Technology Team      To derive ATR details
    -- 23-May-2019  1.1        Viswanathan Pandian     Modified for CCR0007687
    ******************************************************************************************/
    PROCEDURE get_atr_details_prc (p_inventory_item_id IN mtl_system_items_b.inventory_item_id%TYPE, p_organization_id IN mtl_system_items_b.organization_id%TYPE, p_subinventory_code IN VARCHAR2 DEFAULT NULL
                                   ,           -- Added for 1.1 for CCR0007687
                                     x_qty_atr OUT NOCOPY NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2)
    AS
        ln_qty_oh       NUMBER;
        ln_qty_res_oh   NUMBER;
        ln_qty_res      NUMBER;
        ln_qty_sug      NUMBER;
        ln_qty_att      NUMBER;
        ln_qty_atr      NUMBER;
        ln_msg_count    NUMBER;
        lc_msg_data     VARCHAR2 (1000);
        lc_msg_dummy    VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Begin ATR Results');
        apps.inv_quantity_tree_grp.clear_quantity_cache;
        apps.inv_quantity_tree_pub.query_quantities (
            p_api_version_number    => 1.0,
            p_init_msg_lst          => apps.fnd_api.g_false,
            x_return_status         => x_return_status,
            x_msg_count             => ln_msg_count,
            x_msg_data              => lc_msg_data,
            p_organization_id       => p_organization_id,
            p_inventory_item_id     => p_inventory_item_id,
            p_tree_mode             =>
                apps.inv_quantity_tree_pub.g_transaction_mode,
            p_is_revision_control   => FALSE,
            p_is_lot_control        => FALSE,
            p_is_serial_control     => FALSE,
            p_revision              => NULL,
            p_lot_number            => NULL,
            -- Start changes for 1.1 for CCR0007687
            -- p_subinventory_code     => NULL,
            p_subinventory_code     => p_subinventory_code,
            -- End changes for 1.1 for CCR0007687
            p_locator_id            => NULL,
            x_qoh                   => ln_qty_oh,
            x_rqoh                  => ln_qty_res_oh,
            x_qr                    => ln_qty_res,
            x_qs                    => ln_qty_sug,
            x_att                   => ln_qty_att,
            x_atr                   => ln_qty_atr);

        IF x_return_status = 'S'
        THEN
            x_qty_atr   := ln_qty_atr;
        ELSE
            FOR i IN 1 .. ln_msg_count
            LOOP
                fnd_msg_pub.get (i, fnd_api.g_false, lc_msg_data,
                                 lc_msg_dummy);
                x_error_message   := (TO_CHAR (i) || ': ' || lc_msg_data);
            END LOOP;

            x_qty_atr   := 0;
            fnd_file.put_line (fnd_file.LOG,
                               'Error Message      : ' || x_error_message);
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Item ATR Status - ' || x_return_status);
        fnd_file.put_line (fnd_file.LOG, 'End ATR Results');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Others Exception :' || SQLERRM);
            x_qty_atr         := 0;
            x_return_status   := 'E';
            x_error_message   := SUBSTR (SQLERRM, 1, 2000);
    END get_atr_details_prc;

    /******************************************************************************************
     -- Modification History:
     -- Public Function: GET_ATR_QTY_FNC
     -- Date         Version#   Name                    Comments
     -- 06-Jan-2015  1.0        BT Technology Team      Calls ATR procedure
    ******************************************************************************************/
    FUNCTION get_atr_qty_fnc (p_inventory_item_id IN mtl_system_items_b.inventory_item_id%TYPE, p_organization_id IN mtl_system_items_b.organization_id%TYPE)
        RETURN NUMBER
    AS
        ln_qty_atr         NUMBER;
        lc_return_status   VARCHAR2 (100);
        lc_error_message   VARCHAR2 (4000);
    BEGIN
        get_atr_details_prc (p_inventory_item_id   => p_inventory_item_id,
                             p_organization_id     => p_organization_id,
                             x_qty_atr             => ln_qty_atr,
                             x_return_status       => lc_return_status,
                             x_error_message       => lc_error_message);

        IF lc_return_status <> 'S'
        THEN
            ln_qty_atr   := NULL;
        END IF;

        RETURN ln_qty_atr;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_atr_qty_fnc;

    /******************************************************************************************
     -- Modification History:
     -- Public Function: GET_ATP_QTY_FNC
     -- Date         Version#   Name                    Comments
     -- 06-Jan-2015  1.0        BT Technology Team      Calls ATP procedure
    ******************************************************************************************/
    FUNCTION get_atp_qty_fnc (p_inventory_item_id IN mtl_system_items_b.inventory_item_id%TYPE, p_quantity_ordered IN oe_order_lines.ordered_quantity%TYPE, p_quantity_uom IN oe_order_lines.order_quantity_uom%TYPE
                              , p_requested_ship_date IN oe_order_lines.request_date%TYPE, p_source_organization_id IN mtl_system_items_b.organization_id%TYPE, p_demand_class IN oe_order_headers.demand_class_code%TYPE)
        RETURN NUMBER
    AS
        l_atp_rec             mrp_atp_pub.atp_rec_typ;
        l_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        l_atp_period          mrp_atp_pub.atp_period_typ;
        l_atp_details         mrp_atp_pub.atp_details_typ;
        lc_return_status      VARCHAR2 (100);
        lc_error_message      VARCHAR2 (4000);
        ln_atp_qty            NUMBER;
    BEGIN
        get_atp_details_prc (
            p_inventory_item_id        => p_inventory_item_id,
            p_quantity_ordered         => p_quantity_ordered,
            p_quantity_uom             => p_quantity_uom,
            p_requested_ship_date      => p_requested_ship_date,
            p_source_organization_id   => p_source_organization_id,
            p_demand_class             => p_demand_class,
            x_atp_rec                  => l_atp_rec,
            x_atp_supply_demand        => l_atp_supply_demand,
            x_atp_period               => l_atp_period,
            x_atp_details              => l_atp_details,
            x_return_status            => lc_return_status,
            x_error_message            => lc_error_message);

        FOR i IN 1 .. l_atp_rec.inventory_item_id.COUNT
        LOOP
            ln_atp_qty   := l_atp_rec.available_quantity (i);
        END LOOP;

        RETURN ln_atp_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_atp_qty_fnc;
BEGIN
    gn_user_id   := NVL (fnd_global.user_id, 0);             -- 0 for SYSADMIN

    SELECT responsibility_id
      INTO gn_responsibility_id
      FROM fnd_responsibility_vl
     WHERE responsibility_name LIKE 'Advanced Supply Chain Planner';

    SELECT application_id
      INTO gn_application_id
      FROM fnd_application_vl
     WHERE application_name LIKE 'Advanced Supply Chain Planning';
EXCEPTION
    WHEN OTHERS
    THEN
        gn_user_id             := 0;
        gn_responsibility_id   := -1;
        gn_application_id      := -1;
END xxd_inv_common_utils_x_pk;
/


GRANT EXECUTE ON APPS.XXD_INV_COMMON_UTILS_X_PK TO APPSRO
/
