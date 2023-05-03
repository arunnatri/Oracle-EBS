--
-- XXD_EDI870_ATP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_EDI870_ATP_PKG"
AS
    PROCEDURE get_atp_val_prc (x_atp_qty OUT NUMBER, p_msg_data OUT VARCHAR2, p_err_code OUT VARCHAR2, p_inventory_item_id IN NUMBER, p_org_id IN NUMBER, p_primary_uom_code IN VARCHAR2, p_source_org_id IN NUMBER, p_qty_ordered IN NUMBER, p_req_ship_date IN DATE
                               , p_demand_class_code IN VARCHAR2, x_req_date_qty OUT NUMBER, x_available_date OUT DATE)
    IS
        l_atp_rec             mrp_atp_pub.atp_rec_typ;
        p_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period          mrp_atp_pub.atp_period_typ;
        x_atp_details         mrp_atp_pub.atp_details_typ;
        x_return_status       VARCHAR2 (2000);
        x_msg_data            VARCHAR2 (500);
        x_msg_count           NUMBER;
        l_session_id          NUMBER;
        l_error_message       VARCHAR2 (250);
        x_error_message       VARCHAR2 (80);
        i                     NUMBER;
        v_file_dir            VARCHAR2 (80);
        v_inventory_item_id   NUMBER;
        v_organization_id     NUMBER;
        l_qty_uom             VARCHAR2 (10);
        l_req_date            DATE;
        l_demand_class        VARCHAR2 (80);
        v_api_return_status   VARCHAR2 (1);
        v_qty_oh              NUMBER;
        v_qty_res_oh          NUMBER;
        v_qty_res             NUMBER;
        v_qty_sug             NUMBER;
        v_qty_att             NUMBER;
        v_qty_atr             NUMBER;
        v_msg_count           NUMBER;
        v_msg_data            VARCHAR2 (1000);
        ln_cnt                NUMBER := 0;
    BEGIN
        -- ====================================================
        -- IF using 11.5.9 and above, Use MSC_ATP_GLOBAL.Extend_ATP
        -- API to extend record structure as per standards. This
        -- will ensure future compatibility.
        msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);
        -- IF using 11.5.8 code, Use MSC_SATP_FUNC.Extend_ATP
        -- API to avoid any issues with Extending ATP record
        -- type.
        -- ====================================================
        ln_cnt                                        := ln_cnt + 1;

        SELECT oe_order_sch_util.get_session_id INTO l_session_id FROM DUAL;

        l_atp_rec.inventory_item_id (ln_cnt)          := p_inventory_item_id;
        l_atp_rec.inventory_item_name (ln_cnt)        := NULL;
        l_atp_rec.quantity_ordered (ln_cnt)           := p_qty_ordered; --1           --p_qty_ordered;
        l_atp_rec.quantity_uom (ln_cnt)               := p_primary_uom_code;
        l_atp_rec.requested_ship_date (ln_cnt)        := p_req_ship_date;
        l_atp_rec.action (ln_cnt)                     := 100;
        --100ATP Inquiry   110Scheduling   120Rescheduling
        l_atp_rec.instance_id (ln_cnt)                := NULL;
        l_atp_rec.source_organization_id (ln_cnt)     := p_source_org_id;
        --l_rec_size.ORGANIZATION_ID;
        l_atp_rec.demand_class (ln_cnt)               := p_demand_class_code;
        l_atp_rec.oe_flag (ln_cnt)                    := 'N';
        l_atp_rec.insert_flag (ln_cnt)                := 1;
        --Flag to indicate if supply/demand and period details are calculated or not. If this field is
        --set to 1 then ATP calculates supply/demand and period details.
        l_atp_rec.attribute_04 (ln_cnt)               := 1;
        l_atp_rec.customer_id (ln_cnt)                := NULL;
        l_atp_rec.customer_site_id (ln_cnt)           := NULL;
        l_atp_rec.calling_module (ln_cnt)             := 660; --'724' indicates planning server;'660' indicates OM;'708' indicates configurator;'-1' indicates backlog scheduling workbench
        l_atp_rec.row_id (ln_cnt)                     := NULL;
        l_atp_rec.source_organization_code (ln_cnt)   := NULL;
        l_atp_rec.organization_id (ln_cnt)            := NULL;
        --l_rec_size.ORGANIZATION_ID;
        l_atp_rec.order_number (ln_cnt)               := NULL;
        l_atp_rec.line_number (ln_cnt)                := NULL;
        l_atp_rec.override_flag (ln_cnt)              := NULL;

        apps.mrp_atp_pub.call_atp (
            p_session_id          => l_session_id,
            p_atp_rec             => l_atp_rec,
            x_atp_rec             => x_atp_rec,
            x_atp_supply_demand   => x_atp_supply_demand,
            x_atp_period          => x_atp_period,
            x_atp_details         => x_atp_details,
            x_return_status       => x_return_status,
            x_msg_data            => x_msg_data,
            x_msg_count           => x_msg_count);

        IF (x_return_status = 'S')
        THEN
            FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
            LOOP
                x_error_message   := '';
                x_atp_qty         := x_atp_rec.available_quantity (i);

                IF (x_atp_rec.ERROR_CODE (i) <> 0)
                THEN
                    SELECT meaning
                      INTO x_error_message
                      FROM mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = x_atp_rec.ERROR_CODE (i);

                    x_atp_qty          := 0;
                    x_req_date_qty     := x_atp_rec.requested_date_quantity (i);
                    x_available_date   := x_atp_rec.Ship_Date (i);
                    p_err_code         := 'E';
                    p_msg_data         := x_error_message;
                END IF;
            END LOOP;
        ELSE
            p_msg_data   := NVL (x_msg_data, 'Error in get_atp_prc');
            p_err_code   := 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (
                -20001,
                   'An error was encountered in procedure get_atp_atr_onhnd_prc'
                || SQLCODE
                || ' -ERROR- '
                || SQLERRM);
    END get_atp_val_prc;

    FUNCTION single_atp_result_test (p_inventory_item_id IN NUMBER, p_org_id IN NUMBER, p_primary_uom_code IN VARCHAR2 DEFAULT 'Y', p_source_org_id IN NUMBER:= NULL, p_qty_ordered IN NUMBER:= NULL, p_req_ship_date IN DATE:= TRUNC (SYSDATE)
                                     , p_demand_class_code IN VARCHAR2 DEFAULT 'Y' --                         , p_request_date in date := trunc(sysdate)
               --                         , p_show_oversold in varchar2 := 'Y'
                --                         , p_kco_header_id in number := null
                --                         , p_use_snapshot in varchar2 := 'N'
                                     )
        RETURN NUMBER
    IS
        l_atp        NUMBER (5);
        p_msg_data   VARCHAR2 (60);
        p_err_code   VARCHAR2 (60);
    --  l_nad date;
    BEGIN
        get_atp_prc (x_atp_qty => l_atp, p_msg_data => p_msg_data, p_err_code => p_err_code, p_inventory_item_id => p_inventory_item_id, p_org_id => p_org_id, p_primary_uom_code => p_primary_uom_code, p_source_org_id => p_source_org_id, p_qty_ordered => p_qty_ordered, p_req_ship_date => p_req_ship_date
                     , p_demand_class_code => p_demand_class_code);
        RETURN l_atp;
    END;

    PROCEDURE get_atp_prc (x_atp_qty OUT NUMBER, p_msg_data OUT VARCHAR2, p_err_code OUT VARCHAR2, p_inventory_item_id IN NUMBER, p_org_id IN NUMBER, p_primary_uom_code IN VARCHAR2, p_source_org_id IN NUMBER, p_qty_ordered IN NUMBER, p_req_ship_date IN DATE
                           , p_demand_class_code IN VARCHAR2)
    IS
        l_atp_rec             mrp_atp_pub.atp_rec_typ;
        p_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_rec             mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period          mrp_atp_pub.atp_period_typ;
        x_atp_details         mrp_atp_pub.atp_details_typ;
        x_return_status       VARCHAR2 (2000);
        x_msg_data            VARCHAR2 (500);
        x_msg_count           NUMBER;
        l_session_id          NUMBER;
        l_error_message       VARCHAR2 (250);
        x_error_message       VARCHAR2 (80);
        i                     NUMBER;
        v_file_dir            VARCHAR2 (80);
        v_inventory_item_id   NUMBER;
        v_organization_id     NUMBER;
        l_qty_uom             VARCHAR2 (10);
        l_req_date            DATE;
        l_demand_class        VARCHAR2 (80);
        v_api_return_status   VARCHAR2 (1);
        v_qty_oh              NUMBER;
        v_qty_res_oh          NUMBER;
        v_qty_res             NUMBER;
        v_qty_sug             NUMBER;
        v_qty_att             NUMBER;
        v_qty_atr             NUMBER;
        v_msg_count           NUMBER;
        v_msg_data            VARCHAR2 (1000);
        ln_cnt                NUMBER := 0;
    BEGIN
        -- ====================================================
        -- IF using 11.5.9 and above, Use MSC_ATP_GLOBAL.Extend_ATP
        -- API to extend record structure as per standards. This
        -- will ensure future compatibility.
        msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);
        -- IF using 11.5.8 code, Use MSC_SATP_FUNC.Extend_ATP
        -- API to avoid any issues with Extending ATP record
        -- type.
        -- ====================================================
        ln_cnt                                        := ln_cnt + 1;

        SELECT apps.oe_order_sch_util.Get_Session_Id
          INTO l_session_id
          FROM DUAL;

        l_atp_rec.inventory_item_id (ln_cnt)          := p_inventory_item_id;
        l_atp_rec.inventory_item_name (ln_cnt)        := NULL;
        l_atp_rec.quantity_ordered (ln_cnt)           := 1;   --p_qty_ordered;
        l_atp_rec.quantity_uom (ln_cnt)               := p_primary_uom_code;
        l_atp_rec.requested_ship_date (ln_cnt)        := p_req_ship_date;
        l_atp_rec.action (ln_cnt)                     := 100;
        --100ATP Inquiry   110Scheduling   120Rescheduling
        l_atp_rec.instance_id (ln_cnt)                := NULL;
        l_atp_rec.source_organization_id (ln_cnt)     := p_source_org_id;
        --l_rec_size.ORGANIZATION_ID;
        l_atp_rec.demand_class (ln_cnt)               := p_demand_class_code;
        l_atp_rec.oe_flag (ln_cnt)                    := 'N';
        l_atp_rec.insert_flag (ln_cnt)                := 1;
        --Flag to indicate if supply/demand and period details are calculated or not. If this field is
        --set to 1 then ATP calculates supply/demand and period details.
        l_atp_rec.attribute_04 (ln_cnt)               := 1;
        l_atp_rec.customer_id (ln_cnt)                := NULL;
        l_atp_rec.customer_site_id (ln_cnt)           := NULL;
        l_atp_rec.calling_module (ln_cnt)             := 660;
        --'724' indicates planning server
        --'660' indicates OM
        -- '708' indicates configurator
        --'-1' indicates backlog scheduling workbench
        l_atp_rec.row_id (ln_cnt)                     := NULL;
        l_atp_rec.source_organization_code (ln_cnt)   := NULL;
        l_atp_rec.organization_id (ln_cnt)            := NULL;
        --l_rec_size.ORGANIZATION_ID;
        l_atp_rec.order_number (ln_cnt)               := NULL;
        l_atp_rec.line_number (ln_cnt)                := NULL;
        l_atp_rec.override_flag (ln_cnt)              := NULL;
        apps.mrp_atp_pub.call_atp (
            p_session_id          => l_session_id,
            p_atp_rec             => l_atp_rec,
            x_atp_rec             => x_atp_rec,
            x_atp_supply_demand   => x_atp_supply_demand,
            x_atp_period          => x_atp_period,
            x_atp_details         => x_atp_details,
            x_return_status       => x_return_status,
            x_msg_data            => x_msg_data,
            x_msg_count           => x_msg_count);
        DBMS_OUTPUT.put_line ('Return Status = ' || x_return_status);

        IF (x_return_status = 'S')
        THEN
            FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
            LOOP
                x_error_message   := '';
                x_atp_qty         := x_atp_rec.available_quantity (i);

                IF (x_atp_rec.ERROR_CODE (i) <> 0)
                THEN
                    SELECT meaning
                      INTO x_error_message
                      FROM apps.mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = x_atp_rec.ERROR_CODE (i);

                    x_atp_qty    := 0;
                    p_err_code   := 'E';
                    p_msg_data   := x_error_message;
                END IF;
            END LOOP;
        ELSE
            p_msg_data   := NVL (x_msg_data, 'Error in get_atp_prc');
            p_err_code   := 'E';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            raise_application_error (
                -20001,
                   'An error was encountered in procedure get_atp_atr_onhnd_prc'
                || SQLCODE
                || ' -ERROR- '
                || SQLERRM);
    END;
   /* This procedures are not in used anywhere in the code. Hence commenting.
   PROCEDURE get_atr_onhand_prc (x_qty_atr                OUT NUMBER,
                                 v_qty_oh                 OUT NUMBER,
                                 p_msg_data               OUT VARCHAR2,
                                 p_inventory_item_id   IN     NUMBER,
                                 p_organization_id     IN     NUMBER)
   IS
      l_qty_uom             VARCHAR2 (10);
      l_req_date            DATE;
      l_demand_class        VARCHAR2 (80);
      v_api_return_status   VARCHAR2 (1);
      v_qty_res_oh          NUMBER;
      v_qty_res             NUMBER;
      v_qty_sug             NUMBER;
      v_qty_att             NUMBER;
      v_msg_count           NUMBER;
      v_msg_data            VARCHAR2 (4000);
   BEGIN
      inv_quantity_tree_grp.clear_quantity_cache;
      apps.inv_quantity_tree_pub.query_quantities (
         p_api_version_number    => 1,
         p_init_msg_lst          => fnd_api.g_false,
         x_return_status         => v_api_return_status,
         x_msg_count             => v_msg_count,
         x_msg_data              => v_msg_data,
         p_organization_id       => p_organization_id,
         p_inventory_item_id     => p_inventory_item_id,
         p_tree_mode             => apps.inv_quantity_tree_pub.g_transaction_mode,
         --p_onhand_source => APPS.INV_QUANTITY_TREE_PVT.g_all_subs, -3,
         p_is_revision_control   => FALSE,
         p_is_lot_control        => FALSE,
         p_is_serial_control     => FALSE,
         p_revision              => NULL,
         p_lot_number            => NULL,
         p_subinventory_code     => NULL,
         p_locator_id            => NULL,
         x_qoh                   => v_qty_oh,
         x_rqoh                  => v_qty_res_oh,
         x_qr                    => v_qty_res,
         x_qs                    => v_qty_sug,
         x_att                   => v_qty_att,
         x_atr                   => x_qty_atr);

      IF (v_api_return_status = 'S')
      THEN
         DBMS_OUTPUT.put_line ('on hand Quantity :' || v_qty_oh);
         DBMS_OUTPUT.put_line (
            'Quantity Available To Reserve :' || x_qty_atr);
      ELSE
         p_msg_data := NVL (v_msg_data, 'Error in procedure get_atp_prc');
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         raise_application_error (
            -20001,
               'An error was encountered in procedure get_atr_onhand_prc '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM);
   END;

   PROCEDURE get_price_list_prc (p_inventory_item_id   IN     NUMBER,
                                 p_price_list_name     IN     VARCHAR2,
                                 p_org_id              IN     NUMBER,
                                 p_operand                OUT NUMBER)
   IS
      ln_price        NUMBER;
      l_category_id   NUMBER;
      cat_excep       EXCEPTION;

      CURSOR cur_get_operand (
         p_item_id              NUMBER,
         p_product_attribute    VARCHAR2)
      IS
         SELECT qll.operand
           FROM qp_list_lines qll,
                qp_pricing_attributes qpp,
                qp_list_headers_b qphh,
                qp_list_headers_tl qph
          WHERE     qph.list_header_id = qphh.list_header_id
                AND qph.list_header_id = qll.list_header_id
                AND qph.list_header_id = qpp.list_header_id
                AND qll.list_line_id = qpp.list_line_id
                AND qpp.product_attr_value = p_item_id
                AND qpp.product_attribute = p_product_attribute
                AND qph.NAME = p_price_list_name
                AND qph.LANGUAGE = 'US'
                AND SYSDATE BETWEEN NVL (qll.start_date_active, SYSDATE)
                                AND NVL (qll.end_date_active, SYSDATE)
                AND SYSDATE BETWEEN NVL (qphh.start_date_active, SYSDATE)
                                AND NVL (qphh.end_date_active, SYSDATE);
   BEGIN
      OPEN cur_get_operand (p_inventory_item_id, 'PRICING_ATTRIBUTE1');

      FETCH cur_get_operand INTO ln_price;

      CLOSE cur_get_operand;

      IF ln_price IS NULL
      THEN
         DBMS_OUTPUT.put_line ('ln_price IS NULL');

         SELECT micat.category_id
           INTO l_category_id
           FROM mtl_item_categories micat,
                mtl_category_sets mcats,
                mtl_categories mcat,
                mtl_parameters morg
          WHERE     micat.category_id = mcat.category_id
                AND mcats.category_set_name LIKE 'OM Sales Category'
                AND micat.category_set_id = mcats.category_set_id
                AND micat.inventory_item_id = p_inventory_item_id
                AND micat.organization_id = morg.organization_id
                AND morg.organization_id = p_org_id;

         IF l_category_id IS NULL
         THEN
            RAISE cat_excep;
         END IF;

         OPEN cur_get_operand (l_category_id, 'PRICING_ATTRIBUTE2');

         FETCH cur_get_operand INTO ln_price;

         CLOSE cur_get_operand;
      END IF;

      p_operand := ln_price;
   EXCEPTION
      WHEN cat_excep
      THEN
         DBMS_OUTPUT.put_line ('Category ID is NULL');
      WHEN OTHERS
      THEN
         raise_application_error (
            -20001,
               'An error was encountered in procedure get_price_list_prc '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM);
   END;

   PROCEDURE get_atp_for_style (
      x_atp_style_out            OUT xxd_atp_style_tab,
      x_atp_size_tabletype       OUT atp_size_tabletype,
      x_atp_color_tabletype      OUT atp_color_table_type,
      x_errflag                  OUT VARCHAR2,
      x_errmessage               OUT VARCHAR2,
      p_user_id               IN     NUMBER,
      p_resp_id               IN     NUMBER,
      p_resp_appl_id          IN     NUMBER,
      p_style                 IN     VARCHAR2,
      p_org_id                IN     NUMBER,
      p_item_type             IN     VARCHAR2,
      p_qty_ordered           IN     NUMBER,
      p_req_ship_date         IN     DATE,
      p_demand_class_code     IN     VARCHAR2)
   IS
      l_atp_rec             mrp_atp_pub.atp_rec_typ;
      p_atp_rec             mrp_atp_pub.atp_rec_typ;
      x_atp_rec             mrp_atp_pub.atp_rec_typ;
      x_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
      x_atp_period          mrp_atp_pub.atp_period_typ;
      x_atp_details         mrp_atp_pub.atp_details_typ;
      x_return_status       VARCHAR2 (2000);
      x_msg_data            VARCHAR2 (500);
      x_msg_count           NUMBER;
      l_session_id          NUMBER;
      l_error_message       VARCHAR2 (250);
      x_error_message       VARCHAR2 (80);
      i                     NUMBER;
      v_file_dir            VARCHAR2 (80);
      v_inventory_item_id   NUMBER;
      v_organization_id     NUMBER;
      l_qty_uom             VARCHAR2 (10);
      l_req_date            DATE;
      l_demand_class        VARCHAR2 (80);
      v_api_return_status   VARCHAR2 (1);
      v_qty_oh              NUMBER;
      v_qty_res_oh          NUMBER;
      v_qty_res             NUMBER;
      v_qty_sug             NUMBER;
      v_qty_att             NUMBER;
      v_qty_atr             NUMBER;
      v_msg_count           NUMBER;
      v_msg_data            VARCHAR2 (1000);
      l_demand_class_code   VARCHAR2 (60);
      not_found_excep       EXCEPTION;

      CURSOR cur_get_color (
         p_style        VARCHAR2,
         p_org_id       NUMBER,
         p_item_type    VARCHAR2)
      IS
           SELECT mcat.segment7 style,
                  msi.attribute27 l_size,
                  mcat.segment8 color_description,
                  msi.inventory_item_id inventory_item_id,
                  msi.organization_id warehouse_id,
                  msi.primary_uom_code primary_uom_code
             FROM mtl_system_items_b msi,
                  mtl_item_categories micat,
                  mtl_categories mcat,
                  mtl_category_sets mcats
            WHERE     mcats.category_set_name LIKE 'Inventory'
                  AND micat.category_set_id = mcats.category_set_id
                  AND micat.category_id = mcat.category_id
                  AND msi.inventory_item_id = micat.inventory_item_id
                  AND mcats.structure_id = mcat.structure_id
                  AND msi.organization_id = micat.organization_id
                  AND mcat.segment7 = p_style
                  AND msi.organization_id = p_org_id
                  AND NVL (msi.attribute28, 'PROD') = NVL (p_item_type, 'PROD')
         ORDER BY msi.attribute27;                       --added order by size

      l_cnt                 NUMBER := 0;
      l_var                 NUMBER := 0;
   BEGIN
      x_atp_style_out := xxd_atp_style_tab ();
      fnd_global.apps_initialize (p_user_id, p_resp_id, p_resp_appl_id);
      -- ====================================================
      -- IF using 11.5.9 and above, Use MSC_ATP_GLOBAL.Extend_ATP
      -- API to extend record structure as per standards. This
      -- will ensure future compatibility.
      msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);

      -- IF using 11.5.8 code, Use MSC_SATP_FUNC.Extend_ATP
      -- API to avoid any issues with Extending ATP record
      -- type.
      -- ====================================================

      BEGIN
         l_demand_class_code := NULL;

         SELECT lookup_code
           INTO l_demand_class_code
           FROM fnd_lookup_values
          WHERE     lookup_type = 'DEMAND_CLASS'
                AND language = USERENV ('LANG')
                AND meaning = p_demand_class_code;

         DBMS_OUTPUT.put_line (
            'Demand Class Code :- ' || l_demand_class_code);
      EXCEPTION
         WHEN OTHERS
         THEN
            l_demand_class_code := 'UGG-DILLARDS';
            DBMS_OUTPUT.put_line (
               'DEFAUTL Demand Class Code :- ' || l_demand_class_code);
      END;



      FOR l_get_atp IN cur_get_color (p_style, p_org_id, p_item_type)
      LOOP
         l_var := 1;
         x_atp_style_out.EXTEND (1);
         l_cnt := l_cnt + 1;
         --initializing record type with NULL
         x_atp_style_out (l_cnt) :=
            xxd_atp_for_style (NULL,
                               NULL,
                               NULL,
                               NULL,
                               NULL);

         SELECT oe_order_sch_util.get_session_id INTO l_session_id FROM DUAL;

         l_atp_rec.inventory_item_id (1) := l_get_atp.inventory_item_id;
         l_atp_rec.inventory_item_name (1) := NULL;
         l_atp_rec.quantity_ordered (1) := 1;                 --p_qty_ordered;
         l_atp_rec.quantity_uom (1) := l_get_atp.primary_uom_code;
         l_atp_rec.requested_ship_date (1) := p_req_ship_date;
         l_atp_rec.action (1) := 100;
         --100ATP Inquiry   110Scheduling   120Rescheduling
         l_atp_rec.instance_id (1) := NULL;
         l_atp_rec.source_organization_id (1) := l_get_atp.warehouse_id;
         l_atp_rec.demand_class (1) := l_demand_class_code;
         l_atp_rec.oe_flag (1) := 'N';
         l_atp_rec.insert_flag (1) := 1;
         --Flag to indicate if supply/demand and period details are calculated or not. If this field is
         --set to 1 then ATP calculates supply/demand and period details.
         l_atp_rec.attribute_04 (1) := 1;
         l_atp_rec.customer_id (1) := NULL;
         l_atp_rec.customer_site_id (1) := NULL;
         l_atp_rec.calling_module (1) := 660;
         --'724' indicates planning server
         --'660' indicates OM
         -- '708' indicates configurator
         --'-1' indicates backlog scheduling workbench
         l_atp_rec.row_id (1) := NULL;
         l_atp_rec.source_organization_code (1) := NULL;
         l_atp_rec.organization_id (1) := NULL;
         l_atp_rec.order_number (1) := NULL;
         l_atp_rec.line_number (1) := NULL;
         l_atp_rec.override_flag (1) := NULL;
         apps.mrp_atp_pub.call_atp (
            p_session_id          => l_session_id,
            p_atp_rec             => l_atp_rec,
            x_atp_rec             => x_atp_rec,
            x_atp_supply_demand   => x_atp_supply_demand,
            x_atp_period          => x_atp_period,
            x_atp_details         => x_atp_details,
            x_return_status       => x_return_status,
            x_msg_data            => x_msg_data,
            x_msg_count           => x_msg_count);

         IF (x_return_status = 'S')
         THEN
            FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
            LOOP
               x_error_message := '';
               x_atp_style_out (l_cnt).style := l_get_atp.style;
               x_atp_style_out (l_cnt).color := l_get_atp.color_description;
               x_atp_style_out (l_cnt).request_date := p_req_ship_date;
               x_atp_style_out (l_cnt).SIZES := l_get_atp.l_size;
               x_atp_style_out (l_cnt).atp := x_atp_rec.available_quantity (i);

               IF (x_atp_rec.ERROR_CODE (i) <> 0)
               THEN
                  SELECT meaning
                    INTO x_error_message
                    FROM mfg_lookups
                   WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                         AND lookup_code = x_atp_rec.ERROR_CODE (i);

                  x_atp_style_out (l_cnt).atp := 0;
               END IF;
            END LOOP;
         END IF;
      END LOOP;

      x_atp_color_tabletype := atp_color_table_type ();
      l_cnt := 0;

      FOR j IN (SELECT DISTINCT color FROM TABLE (x_atp_style_out))
      LOOP
         x_atp_color_tabletype.EXTEND (1);
         l_cnt := l_cnt + 1;
         x_atp_color_tabletype (l_cnt) := xxd_atp_color_rcrd_type (NULL, NULL);
         x_atp_color_tabletype (l_cnt).color := j.color;
      END LOOP;

      x_atp_size_tabletype := atp_size_tabletype ();
      l_cnt := 0;

      FOR k IN (  SELECT DISTINCT SIZES
                    FROM TABLE (x_atp_style_out)
                ORDER BY SIZES)
      LOOP
         x_atp_size_tabletype.EXTEND (1);
         l_cnt := l_cnt + 1;
         x_atp_size_tabletype (l_cnt) := xxd_atp_size_rcrd_type (NULL);
         x_atp_size_tabletype (l_cnt).item_size := k.SIZES;
      END LOOP;

      IF l_var = 0
      THEN
         RAISE not_found_excep;
      END IF;
   EXCEPTION
      WHEN not_found_excep
      THEN
         x_errflag := 'E';
         x_errmessage := 'No Item available for this Sub-Style';
         DBMS_OUTPUT.put_line ('No Item available for this Sub-Style');
      WHEN OTHERS
      THEN
         raise_application_error (
            -20001,
               'An error was encountered in procedure get_atp_for_style'
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM);
   END;

   PROCEDURE main (x_errflag                OUT VARCHAR2,
                   x_errmessage             OUT VARCHAR2,
                   x_operand                OUT NUMBER,
                   x_atp_atr_tab_out        OUT xxd_atp_atr_tab,
                   p_user_id             IN     NUMBER,
                   p_resp_id             IN     NUMBER,
                   p_resp_appl_id        IN     NUMBER,
                   p_style               IN     VARCHAR2,
                   p_color               IN     VARCHAR2,
                   p_org_id              IN     NUMBER,
                   p_item_type           IN     VARCHAR2,
                   p_price_list_name     IN     VARCHAR2,
                   p_source_org_id       IN     NUMBER,
                   p_qty_ordered         IN     NUMBER,
                   p_req_ship_date       IN     DATE,
                   p_demand_class_code   IN     VARCHAR2,
                   x_primary_uom            OUT VARCHAR2,  --added 10-Nov-2014
                   x_category_id            OUT NUMBER,
                   x_total_onhand_qty       OUT NUMBER,
                   x_total_atr_value        OUT NUMBER,
                   x_total_atp_value        OUT NUMBER)
   IS
      x_atp_qty              NUMBER;
      x_qty_atr              NUMBER;
      x_onhand_qty           NUMBER;
      ln_cnt                 NUMBER := 0;
      l_inv_id               NUMBER := 0;
      l_org_id               NUMBER;
      l_operand              NUMBER;
      v_msg_data             VARCHAR2 (4000);
      v_errmsg               VARCHAR2 (4000);
      v_err_code             VARCHAR2 (30);
      get_atp_prc_excep      EXCEPTION;
      get_atr_onhand_excep   EXCEPTION;
      not_found_excep        EXCEPTION;

      CURSOR cur_get_size (
         p_style        VARCHAR2,
         p_color        VARCHAR2,
         p_org_id       NUMBER,
         p_item_type    VARCHAR2)
      IS
           SELECT msi.attribute27 l_size,
                  micat.category_id category_id,
                  msi.inventory_item_id inventory_item_id,
                  msi.organization_id organization_id,
                  msi.primary_uom_code primary_uom_code
             FROM mtl_system_items_b msi,
                  mtl_item_categories micat,
                  mtl_categories mcat,
                  mtl_category_sets mcats
            WHERE     mcats.category_set_name LIKE 'Inventory'
                  AND micat.category_set_id = mcats.category_set_id
                  AND micat.category_id = mcat.category_id
                  AND msi.inventory_item_id = micat.inventory_item_id
                  AND mcats.structure_id = mcat.structure_id
                  --included Structure ID join
                  AND msi.organization_id = micat.organization_id
                  AND mcat.segment7 = p_style
                  --modified because SubStyle will be passed in place of MasterStyle
                  AND mcat.segment8 = p_color
                  --modified because Color Desc would be passed in place of ColorCode
                  AND msi.organization_id = p_org_id
                  AND NVL (msi.attribute28, 'PROD') = NVL (p_item_type, 'PROD')
         --Added item type as new input
         ORDER BY msi.attribute27;                       --added order by size

      l_demand_class_code    VARCHAR2 (60);
   BEGIN
      x_atp_atr_tab_out := xxd_atp_atr_tab ();
      fnd_global.apps_initialize (p_user_id, p_resp_id, p_resp_appl_id);
      x_total_onhand_qty := 0;
      x_total_atr_value := 0;
      x_total_atp_value := 0;
      x_errflag := '';

      BEGIN
         l_demand_class_code := NULL;

         SELECT lookup_code
           INTO l_demand_class_code
           FROM fnd_lookup_values
          WHERE     lookup_type = 'DEMAND_CLASS'
                AND language = USERENV ('LANG')
                AND meaning = p_demand_class_code;

         DBMS_OUTPUT.put_line (
            'Demand Class Code :- ' || l_demand_class_code);
      EXCEPTION
         WHEN OTHERS
         THEN
            l_demand_class_code := 'UGG-DILLARDS';
            DBMS_OUTPUT.put_line (
               'DEFAUTL Demand Class Code :- ' || l_demand_class_code);
      END;

      FOR l_rec_size IN cur_get_size (p_style,
                                      p_color,
                                      p_org_id,
                                      p_item_type)
      LOOP
         v_errmsg := NULL;
         v_err_code := NULL;
         x_atp_atr_tab_out.EXTEND (1);
         ln_cnt := ln_cnt + 1;
         x_atp_atr_tab_out (ln_cnt) :=
            xxd_atp_atr_onhand_size (NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL,
                                     NULL);
         l_inv_id := l_rec_size.inventory_item_id;
         --Calling procedure get_atp_prc to get ATP values for an Item
         get_atp_prc (x_atp_qty,
                      v_msg_data,
                      v_err_code,
                      l_rec_size.inventory_item_id,
                      p_org_id,
                      l_rec_size.primary_uom_code,
                      p_source_org_id,
                      p_qty_ordered,
                      p_req_ship_date,
                      l_demand_class_code);


         IF v_msg_data IS NOT NULL
         THEN
            v_err_code := 'E';
            v_errmsg := v_msg_data;
         ELSE
            x_errflag := 'S';
            v_err_code := 'S';
         END IF;

         --Calling procedure get_atr_onhand_prc to get ATR and OnHand Qty values for an Item
         get_atr_onhand_prc (x_qty_atr,
                             x_onhand_qty,
                             v_msg_data,
                             l_rec_size.inventory_item_id,
                             l_rec_size.organization_id);
         DBMS_OUTPUT.put_line (
               'x_atp_qty - '
            || x_atp_qty
            || ' - x_qty_atr - '
            || x_qty_atr
            || ' - l_rec_size.l_size - '
            || l_rec_size.l_size
            || ' - x_onhand_qty - '
            || x_onhand_qty);

         x_atp_atr_tab_out (ln_cnt).inventory_item_id :=
            l_rec_size.inventory_item_id;
         x_atp_atr_tab_out (ln_cnt).atp := x_atp_qty;
         x_atp_atr_tab_out (ln_cnt).atr := x_qty_atr;
         x_atp_atr_tab_out (ln_cnt).onhand := x_onhand_qty;
         x_atp_atr_tab_out (ln_cnt).SIZES := l_rec_size.l_size;
         x_atp_atr_tab_out (ln_cnt).ERROR_CODE := v_err_code;
         x_atp_atr_tab_out (ln_cnt).error_message := v_errmsg; --x_errmessage;
         x_category_id := l_rec_size.category_id;
         x_total_onhand_qty := x_total_onhand_qty + x_onhand_qty;
         x_total_atr_value := x_total_atr_value + x_qty_atr;
         x_total_atp_value := x_total_atp_value + x_atp_qty;
         x_primary_uom := l_rec_size.primary_uom_code;     --added 10-Nov-2014
         x_errflag := 'S';
      END LOOP;

      IF l_inv_id != 0
      THEN
         DBMS_OUTPUT.put_line ('l_inv_id :' || l_inv_id);
         DBMS_OUTPUT.put_line ('p_price_list_name  ' || p_price_list_name);
         DBMS_OUTPUT.put_line ('p_org_id :' || p_org_id);
         --Start of Calling procedure to get the Price List of an Item--
         get_price_list_prc (l_inv_id,
                             p_price_list_name,
                             p_org_id,
                             l_operand);
         --End of Calling procedure to get the Price List of an Item--
         x_operand := l_operand;
      ELSE
         RAISE not_found_excep;
      END IF;
   EXCEPTION
      WHEN not_found_excep
      THEN
         x_errflag := 'E';
         x_errmessage :=
            'No Item Found for a given combination of Sub-Style and Color';
      WHEN OTHERS
      THEN
         raise_application_error (
            -20001,
               'An error was encountered in procedure MAIN '
            || SQLCODE
            || ' -ERROR- '
            || SQLERRM);
         x_errflag := 'E';
         x_errmessage := 'An error was encountered in procedure MAIN';
   END;
*/
END XXD_EDI870_ATP_PKG;
/
