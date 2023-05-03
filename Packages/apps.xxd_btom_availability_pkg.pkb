--
-- XXD_BTOM_AVAILABILITY_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_BTOM_AVAILABILITY_PKG"
AS
    /****************************************************************************************************************************************
      Modification History:
      Version       By                      Date              Comments
      1.1          Infosys               14-Feb-2017      Changes done related to "INC0340792/PRB0041192"
      1.2                INFOSYS                        23-Feb-2017      Added sorting logic for Sizes in Procedure main
      1.3                 INFOSYS                        24-Feb-2017       Added the SAVEPOINT and Rollback as part of     "INC0340792/PRB0041192"
      1.4                 INFOSYS                        24-May-2017       Replaced Query, for fixing future ATP issue as part of INC0354060
      1.5            Infosys             03-Oct-2017       Changes done for ATP by Future Date as part of CCR0006659
      1.6            Jayarajan A K       18-Dec-2020      Modified ATP by Future Date logic for CCR0008870 - Global Inventory Allocation Project
     ****************************************************************************************************************************************/

    PROCEDURE get_atp_prc (p_atp_rec IN mrp_atp_pub.atp_rec_typ, x_atp_rec OUT NOCOPY mrp_atp_pub.atp_rec_typ, x_atp_supply_demand OUT NOCOPY mrp_atp_pub.atp_supply_demand_typ, x_atp_period OUT NOCOPY mrp_atp_pub.atp_period_typ, x_atp_details OUT NOCOPY mrp_atp_pub.atp_details_typ, x_return_status OUT NOCOPY VARCHAR2
                           , x_error_message OUT NOCOPY VARCHAR2)
    IS
        l_atp_rec      mrp_atp_pub.atp_rec_typ;
        lc_msg_data    VARCHAR2 (500);
        lc_msg_dummy   VARCHAR2 (1000);
        ln_msg_count   NUMBER;
        l_session_id   NUMBER;
        lc_var         VARCHAR2 (2000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Begin ATP Results');

        l_atp_rec   := p_atp_rec;

        SELECT oe_order_sch_util.get_session_id INTO l_session_id FROM DUAL;

        SAVEPOINT ATPROLLBACK;                                 ----1.3 Version

        msc_atp_global.get_atp_session_id (l_session_id, lc_var);
        --Commented this procedure as part of 1.1 version
        /* apps.mrp_atp_pub.call_atp (l_session_id,
                                       l_atp_rec,
                                       x_atp_rec,
                                       x_atp_supply_demand,
                                       x_atp_period,
                                       x_atp_details,
                                       x_return_status,
                                       lc_msg_data,
                                       ln_msg_count
                                       );*/
        ---Added this procedure of no_commit as part of 1.1 version
        apps.mrp_atp_pub.call_atp_no_commit (l_session_id,
                                             l_atp_rec,
                                             x_atp_rec,
                                             x_atp_supply_demand,
                                             x_atp_period,
                                             x_atp_details,
                                             x_return_status,
                                             lc_msg_data,
                                             ln_msg_count);

        DBMS_OUTPUT.put_line ('Return Status = ' || x_return_status);

        ROLLBACK TO ATPROLLBACK;                                ---1.3 Version
        COMMIT;                                                  --1.3 Version

        IF (x_return_status = 'E')
        THEN
            FOR i IN 1 .. ln_msg_count
            LOOP
                fnd_msg_pub.get (i, fnd_api.g_false, lc_msg_data,
                                 lc_msg_dummy);
                x_error_message   := (TO_CHAR (i) || ': ' || lc_msg_data);
            END LOOP;

            fnd_file.put_line (fnd_file.LOG,
                               'Return Message = ' || x_error_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Others Exception :' || SQLERRM);
            x_return_status   := 'E';
            x_error_message   := SUBSTR (SQLERRM, 1, 2000);
    END;

    --***********SUMIT ADDED**********************

    FUNCTION single_atp_result (x_qty_atr                OUT NUMBER,
                                v_qty_oh                 OUT NUMBER,
                                p_msg_data               OUT VARCHAR2,
                                p_inventory_item_id   IN     NUMBER,
                                p_organization_id     IN     NUMBER)
        RETURN NUMBER
    IS
        l_atp   NUMBER;
        l_nad   DATE;
    BEGIN
        get_atr_onhand_prc (x_qty_atr             => x_qty_atr,
                            v_qty_oh              => v_qty_oh,
                            p_msg_data            => p_msg_data,
                            p_inventory_item_id   => p_inventory_item_id,
                            p_organization_id     => p_organization_id);
        RETURN x_qty_atr;
    END;

    --***************ADDED***********************

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
            p_tree_mode             =>
                apps.inv_quantity_tree_pub.g_transaction_mode,
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
            p_msg_data   :=
                NVL (v_msg_data, 'Error in procedure get_atp_prc');
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
                                  p_req_ship_date       IN     DATE,
                                  p_operand                OUT NUMBER)
    IS
        ln_price        NUMBER;
        l_category_id   NUMBER;
        cat_excep       EXCEPTION;

        CURSOR cur_get_operand (p_item_id             NUMBER,
                                p_product_attribute   VARCHAR2)
        IS
            SELECT qll.operand
              FROM qp_list_lines qll, qp_pricing_attributes qpp, qp_list_headers_b qphh,
                   qp_list_headers_tl qph
             WHERE     qph.list_header_id = qphh.list_header_id
                   AND qph.list_header_id = qll.list_header_id
                   AND qph.list_header_id = qpp.list_header_id
                   AND qll.list_line_id = qpp.list_line_id
                   AND qpp.product_attr_value = TO_CHAR (p_item_id)
                   AND qpp.product_attribute = p_product_attribute
                   AND qph.NAME = p_price_list_name
                   AND qph.LANGUAGE = 'US'
                   AND TRUNC (p_req_ship_date) BETWEEN TRUNC (
                                                           NVL (
                                                               qll.start_date_active,
                                                                 p_req_ship_date
                                                               - 1))
                                                   AND TRUNC (
                                                           NVL (
                                                               qll.end_date_active,
                                                                 p_req_ship_date
                                                               + 1))
                   AND TRUNC (p_req_ship_date) BETWEEN TRUNC (
                                                           NVL (
                                                               qphh.start_date_active,
                                                                 p_req_ship_date
                                                               - 1))
                                                   AND TRUNC (
                                                           NVL (
                                                               qphh.end_date_active,
                                                                 p_req_ship_date
                                                               + 1));

        CURSOR cur_get_operand_attr3 (p_product_attribute VARCHAR2)
        IS
            SELECT qll.operand
              FROM qp_list_lines qll, qp_pricing_attributes qpp, qp_list_headers_b qphh,
                   qp_list_headers_tl qph
             WHERE     qph.list_header_id = qphh.list_header_id
                   AND qph.list_header_id = qll.list_header_id
                   AND qph.list_header_id = qpp.list_header_id
                   AND qll.list_line_id = qpp.list_line_id
                   AND qpp.product_attr_value = 'ALL'
                   AND qpp.product_attribute = p_product_attribute
                   AND qpp.product_uom_code =
                       (SELECT primary_uom_code
                          FROM XXD_COMMON_ITEMS_V
                         WHERE     inventory_item_id = p_inventory_item_id
                               AND organization_id = p_org_id
                               AND ROWNUM = 1)
                   AND qph.NAME = p_price_list_name
                   AND qll.list_line_type_code = 'PLL'
                   AND qph.LANGUAGE = 'US'
                   AND TRUNC (p_req_ship_date) BETWEEN TRUNC (
                                                           NVL (
                                                               qll.start_date_active,
                                                                 p_req_ship_date
                                                               - 1))
                                                   AND TRUNC (
                                                           NVL (
                                                               qll.end_date_active,
                                                                 p_req_ship_date
                                                               + 1))
                   AND TRUNC (p_req_ship_date) BETWEEN TRUNC (
                                                           NVL (
                                                               qphh.start_date_active,
                                                                 p_req_ship_date
                                                               - 1))
                                                   AND TRUNC (
                                                           NVL (
                                                               qphh.end_date_active,
                                                                 p_req_ship_date
                                                               + 1));
    BEGIN
        OPEN cur_get_operand (p_inventory_item_id, 'PRICING_ATTRIBUTE1');

        FETCH cur_get_operand INTO ln_price;

        CLOSE cur_get_operand;

        IF ln_price IS NULL
        THEN
            DBMS_OUTPUT.put_line ('ln_price IS NULL');

            SELECT micat.category_id
              INTO l_category_id
              FROM mtl_item_categories micat, mtl_category_sets mcats, mtl_categories mcat,
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

            IF ln_price IS NULL
            THEN
                OPEN cur_get_operand_attr3 ('PRICING_ATTRIBUTE3');

                FETCH cur_get_operand_attr3 INTO ln_price;

                CLOSE cur_get_operand_attr3;
            END IF;
        END IF;

        p_operand   := ln_price;
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

        CURSOR cur_get_color (p_style VARCHAR2, p_org_id NUMBER, p_item_type VARCHAR2
                              , p_inv_item_id NUMBER)
        IS
              SELECT mcat.segment7 style, msi.attribute27 l_size, mcat.segment8 color_description,
                     msi.inventory_item_id inventory_item_id, msi.organization_id warehouse_id, msi.primary_uom_code primary_uom_code
                FROM mtl_system_items_b msi, mtl_item_categories micat, mtl_categories mcat,
                     mtl_category_sets mcats
               WHERE     mcats.category_set_name LIKE 'Inventory'
                     AND micat.category_set_id = mcats.category_set_id
                     AND micat.category_id = mcat.category_id
                     AND msi.inventory_item_id = micat.inventory_item_id
                     AND msi.inventory_item_id =
                         NVL (p_inv_item_id, msi.inventory_item_id)
                     AND mcats.structure_id = mcat.structure_id
                     AND msi.organization_id = micat.organization_id
                     AND mcat.segment7 = p_style
                     AND msi.organization_id = p_org_id
                     AND NVL (msi.attribute28, 'PROD') =
                         NVL (p_item_type, 'PROD')
            ORDER BY msi.attribute27;                    --added order by size

        TYPE get_size_tbl_type IS TABLE OF cur_get_color%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_inv_items_rec       get_size_tbl_type;

        l_cnt                 NUMBER := 0;
        l_var                 NUMBER := 0;
    BEGIN
        x_atp_style_out   := xxd_atp_style_tab ();
        fnd_global.apps_initialize (p_user_id, p_resp_id, p_resp_appl_id);

        BEGIN
            l_demand_class_code   := NULL;

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
                l_demand_class_code   := 'UGG-DILLARDS';
                DBMS_OUTPUT.put_line (
                    'DEFAUTL Demand Class Code :- ' || l_demand_class_code);
        END;

        OPEN cur_get_color (p_style, p_org_id, p_item_type,
                            NULL);

        LOOP
            FETCH cur_get_color BULK COLLECT INTO l_inv_items_rec;

            l_var   := 1;
            DBMS_OUTPUT.PUT_LINE (
                ' Number of rows fetched : ' || l_inv_items_rec.COUNT);
            -- BEGIN LOGIC TO POPULATE THE RECORD TYPE FOR WHICH WE NEED TO FETCH THE ATP
            msc_atp_global.extend_atp (l_atp_rec,
                                       x_return_status,
                                       l_inv_items_rec.COUNT);

            FOR indx IN 1 .. l_inv_items_rec.COUNT
            LOOP
                l_atp_rec.inventory_item_id (indx)          :=
                    l_inv_items_rec (indx).inventory_item_id;
                l_atp_rec.inventory_item_name (indx)        := NULL;
                --l_atp_rec.quantity_ordered (indx) := 1;               --p_qty_ordered;
                l_atp_rec.quantity_ordered (indx)           :=
                    NVL (fnd_profile.VALUE ('XXDO_DOE_ATP_DEFAULT_REQ_QTY'),
                         999999999);
                l_atp_rec.quantity_uom (indx)               :=
                    l_inv_items_rec (indx).primary_uom_code;
                l_atp_rec.requested_ship_date (indx)        := p_req_ship_date;
                l_atp_rec.action (indx)                     := 100;
                --100 ATP Inquiry   110Scheduling   120Rescheduling
                l_atp_rec.instance_id (indx)                := NULL;
                l_atp_rec.source_organization_id (indx)     := p_org_id;
                --l_rec_size.ORGANIZATION_ID;
                l_atp_rec.demand_class (indx)               :=
                    l_demand_class_code;
                l_atp_rec.oe_flag (indx)                    := 'N';
                --Flag to indicate if supply/demand and period details are calculated or not. If this field is
                --set to 1 then ATP calculates supply/demand and period details.
                l_atp_rec.insert_flag (indx)                := 0;
                l_atp_rec.attribute_04 (indx)               := 1;
                l_atp_rec.customer_id (indx)                := NULL;
                l_atp_rec.customer_site_id (indx)           := NULL;
                l_atp_rec.calling_module (indx)             := 660; --'724' indicates planning server
                --'660' indicates OM
                --'708' indicates configurator
                --'-1' indicates backlog scheduling workbench
                l_atp_rec.row_id (indx)                     := NULL;
                l_atp_rec.source_organization_code (indx)   := NULL;
                l_atp_rec.organization_id (indx)            := p_org_id;
                --l_rec_size.ORGANIZATION_ID;
                l_atp_rec.order_number (indx)               := NULL;
                l_atp_rec.line_number (indx)                := NULL;
                l_atp_rec.override_flag (indx)              := NULL;
                l_atp_rec.Identifier (indx)                 :=
                    XXDO_BULK_ATP_IDENTIFIER_S.NEXTVAL;          -- Ram: Added
            END LOOP;

            EXIT WHEN cur_get_color%NOTFOUND;
        END LOOP;

        CLOSE cur_get_color;

        get_atp_prc (p_atp_rec => l_atp_rec, x_atp_rec => x_atp_rec, x_atp_supply_demand => x_atp_supply_demand, x_atp_period => x_atp_period, x_atp_details => x_atp_details, x_return_status => x_errflag
                     , x_error_message => x_errmessage);

        IF (x_errflag = 'S')
        THEN
            FOR i IN 1 .. x_atp_rec.inventory_item_id.COUNT
            LOOP
                x_atp_style_out.EXTEND (1);
                x_atp_style_out (i)   :=
                    xxd_atp_for_style (NULL, NULL, NULL,
                                       NULL, NULL);

                IF (x_atp_rec.ERROR_CODE (i) <> 0)
                THEN
                    SELECT meaning
                      INTO x_error_message
                      FROM mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = x_atp_rec.ERROR_CODE (i);
                --x_atp_rec.available_quantity (i) := 0;
                END IF;

                FOR lc_rec_color_cur
                    IN cur_get_color (p_style, p_org_id, p_item_type
                                      , x_atp_rec.inventory_item_id (i))
                LOOP
                    x_error_message                    := '';
                    x_atp_style_out (i).style          := lc_rec_color_cur.style;
                    x_atp_style_out (i).color          :=
                        lc_rec_color_cur.color_description;
                    x_atp_style_out (i).request_date   := p_req_ship_date;
                    x_atp_style_out (i).SIZES          :=
                        lc_rec_color_cur.l_size;
                    x_atp_style_out (i).atp            :=
                        x_atp_rec.requested_date_quantity (i);
                END LOOP;
            END LOOP;

            x_atp_color_tabletype   := atp_color_table_type ();
            l_cnt                   := 0;

            FOR j IN (  SELECT DISTINCT color
                          FROM TABLE (x_atp_style_out)
                      ORDER BY color DESC)
            LOOP
                x_atp_color_tabletype.EXTEND (1);
                l_cnt                                 := l_cnt + 1;
                x_atp_color_tabletype (l_cnt)         :=
                    xxd_atp_color_rcrd_type (NULL, NULL);
                x_atp_color_tabletype (l_cnt).color   := j.color;
            END LOOP;

            x_atp_size_tabletype    := atp_size_tabletype ();
            l_cnt                   := 0;

            FOR k IN (  SELECT DISTINCT SIZES
                          FROM TABLE (x_atp_style_out)
                      ORDER BY SIZES)
            LOOP
                x_atp_size_tabletype.EXTEND (1);
                l_cnt                                    := l_cnt + 1;
                x_atp_size_tabletype (l_cnt)             :=
                    xxd_atp_size_rcrd_type (NULL);
                x_atp_size_tabletype (l_cnt).item_size   := k.SIZES;
            END LOOP;

            IF l_var = 0
            THEN
                RAISE not_found_excep;
            END IF;
        END IF;
    EXCEPTION
        WHEN not_found_excep
        THEN
            x_errflag      := 'E';
            x_errmessage   := 'No Item available for this Sub-Style';
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

    PROCEDURE get_atp_future_dates (x_atp_style_out OUT xxd_atp_style_tab, x_atp_size_tabletype OUT atp_size_tabletype, x_atp_color_tabletype OUT atp_color_table_type, x_errflag OUT VARCHAR2, x_errmessage OUT VARCHAR2, p_user_id IN NUMBER, p_resp_id IN NUMBER, p_resp_appl_id IN NUMBER, p_style IN VARCHAR2, p_color IN VARCHAR2, p_org_id IN NUMBER, p_item_type IN VARCHAR2
                                    , p_qty_ordered IN NUMBER, p_req_ship_date IN DATE, p_demand_class_code IN VARCHAR2)
    IS
        l_atp_rec               mrp_atp_pub.atp_rec_typ;
        l_atp_rec_out           mrp_atp_pub.atp_rec_typ;
        x_atp_rec               mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand     mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period            mrp_atp_pub.atp_period_typ;
        x_atp_details           mrp_atp_pub.atp_details_typ;
        x_return_status         VARCHAR2 (2000);
        x_msg_data              VARCHAR2 (500);
        x_msg_count             NUMBER;
        l_session_id            NUMBER;
        l_error_message         VARCHAR2 (250);
        x_error_message         VARCHAR2 (80);
        i                       NUMBER;
        v_file_dir              VARCHAR2 (80);
        v_inventory_item_id     NUMBER;
        v_organization_id       NUMBER;
        l_qty_uom               VARCHAR2 (10);
        l_req_date              DATE;
        l_demand_class          VARCHAR2 (80);
        v_api_return_status     VARCHAR2 (1);
        v_qty_oh                NUMBER;
        v_qty_res_oh            NUMBER;
        v_qty_res               NUMBER;
        v_qty_sug               NUMBER;
        v_qty_att               NUMBER;
        v_qty_atr               NUMBER;
        v_msg_count             NUMBER;
        v_msg_data              VARCHAR2 (1000);
        l_demand_class_code     VARCHAR2 (60);
        lc_var                  VARCHAR2 (2000);
        not_found_excep         EXCEPTION;
        v_req_ship_date         DATE;


        CURSOR cur_get_color (p_style VARCHAR2, p_color VARCHAR2, p_org_id NUMBER
                              , p_item_type VARCHAR2, p_inv_item_id NUMBER)
        IS
              SELECT mcat.segment7 style, msi.attribute27 l_size, mcat.segment8 color_description,
                     msi.inventory_item_id inventory_item_id, msi.organization_id warehouse_id, msi.primary_uom_code primary_uom_code
                FROM mtl_system_items_b msi, mtl_item_categories micat, mtl_categories mcat,
                     mtl_category_sets mcats
               WHERE     mcats.category_set_name LIKE 'Inventory'
                     AND micat.category_set_id = mcats.category_set_id
                     AND micat.category_id = mcat.category_id
                     AND msi.inventory_item_id = micat.inventory_item_id
                     AND msi.inventory_item_id =
                         NVL (p_inv_item_id, msi.inventory_item_id)
                     AND mcats.structure_id = mcat.structure_id
                     AND msi.organization_id = micat.organization_id
                     AND mcat.attribute_category = 'Item Categories'
                     AND mcat.segment7 = p_style
                     AND mcat.segment8 = p_color
                     AND msi.organization_id = p_org_id
                     AND NVL (msi.attribute28, 'PROD') =
                         NVL (p_item_type, 'PROD')
            -- AND MSI.INVENTORY_ITEM_ID = 5351
            ORDER BY msi.attribute27;                    --added order by size

        --Start v1.6 Changes
        CURSOR cur_get_atp (l_session_id NUMBER)
        IS
              SELECT inventory_item_id, organization_id, uom_code,
                     period_start_date, SUM (cumulative_quantity) qty
                FROM (SELECT DISTINCT md_qty.inventory_item_id, md_qty.organization_id, md_qty.uom_code,
                                      dt_qry.period_start_date, cumulative_quantity
                        FROM mrp_atp_details_temp md_qty,
                             (SELECT DISTINCT inventory_item_id, organization_id, supply_demand_date period_start_date
                                -- ,period_start_date
                                FROM mrp_atp_details_temp md_date
                               WHERE     Session_id = l_session_id --AND    record_type = 1
                                     AND supply_demand_type = 2
                                     AND record_type = 2) dt_qry
                       WHERE     md_qty.INVENTORY_ITEM_ID =
                                 dt_qry.INVENTORY_ITEM_ID
                             AND md_qty.ORGANIZATION_ID =
                                 dt_qry.organization_id
                             AND md_qty.session_id = l_session_id
                             AND MD_QTY.RECORD_TYPE = 1
                             AND TRUNC (DT_QRY.PERIOD_START_DATE) BETWEEN TRUNC (
                                                                              md_qty.period_start_date)
                                                                      AND TRUNC (
                                                                              md_qty.period_end_date))
            GROUP BY inventory_item_id, organization_id, uom_code,
                     period_start_date;

        /*
              CURSOR cur_get_atp (
                 l_session_id NUMBER)
              IS
                   SELECT md_qty.inventory_item_id,
                          md_qty.organization_id,
                          md_qty.uom_code,
                          dt_qry.period_start_date,
                          SUM (cumulative_quantity) qty
                     FROM mrp_atp_details_temp md_qty,
                          (SELECT DISTINCT
                                  inventory_item_id,
                                  organization_id,
                                  supply_demand_date period_start_date
                             -- ,period_start_date
                             FROM mrp_atp_details_temp md_date
                            WHERE Session_id = l_session_id --AND    record_type = 1
                                  AND supply_demand_type = 2 AND record_type = 2) dt_qry
                    WHERE     md_qty.INVENTORY_ITEM_ID = dt_qry.INVENTORY_ITEM_ID
                          AND md_qty.ORGANIZATION_ID = dt_qry.organization_id
                          AND md_qty.session_id = l_session_id
                          AND MD_QTY.RECORD_TYPE = 1
                          AND TRUNC (DT_QRY.PERIOD_START_DATE) BETWEEN TRUNC (
                                                                          md_qty.period_start_date)
                                                                   AND TRUNC (
                                                                          md_qty.period_end_date)
                 GROUP BY md_qty.inventory_item_id,
                          md_qty.organization_id,
                          md_qty.uom_code,
                          dt_qry.period_start_date;
        */
        --End v1.6 Changes

        l_cnt                   NUMBER := 0;
        l_var                   NUMBER := 0;

        TYPE get_size_tbl_type IS TABLE OF cur_get_color%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_inv_items_rec         get_size_tbl_type;
        x_atp_style_out_temp    xxd_atp_style_tab;
        x_atp_style_out_temp1   xxd_atp_style_tab;
        future_qty              NUMBER;
    BEGIN
        DBMS_OUTPUT.put_line ('0');
        x_atp_style_out         := xxd_atp_style_tab ();
        x_atp_style_out_temp    := xxd_atp_style_tab ();
        x_atp_style_out_temp1   := xxd_atp_style_tab ();
        fnd_global.apps_initialize (p_user_id, p_resp_id, p_resp_appl_id);

        -- ====================================================
        -- IF using 11.5.9 and above, Use MSC_ATP_GLOBAL.Extend_ATP
        -- API to extend record structure as per standards. This
        -- will ensure future compatibility.

        --msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);

        -- IF using 11.5.8 code, Use MSC_SATP_FUNC.Extend_ATP
        -- API to avoid any issues with Extending ATP record
        -- type.
        -- ====================================================

        BEGIN
            l_demand_class_code   := NULL;
            DBMS_OUTPUT.put_line ('1');

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
                l_demand_class_code   := 'UGG-DILLARDS';
                DBMS_OUTPUT.put_line (
                    'DEFAULT Demand Class Code :- ' || l_demand_class_code);
        END;

        DBMS_OUTPUT.put_line ('2');


        OPEN cur_get_color (p_style, p_color, p_org_id,
                            p_item_type, NULL);

        LOOP
            FETCH cur_get_color BULK COLLECT INTO l_inv_items_rec;

            DBMS_OUTPUT.PUT_LINE (
                ' Number of rows fetched : ' || l_inv_items_rec.COUNT);
            -- BEGIN LOGIC TO POPULATE THE RECORD TYPE FOR WHICH WE NEED TO FETCH THE ATP
            msc_atp_global.extend_atp (l_atp_rec,
                                       x_errmessage,
                                       l_inv_items_rec.COUNT);

            FOR indx IN 1 .. l_inv_items_rec.COUNT
            LOOP
                -- l_var := 1; --Commented for version 1.4

                -- Start:Added as part of version 1.4
                IF l_var = 0
                THEN
                    SELECT oe_order_sch_util.get_session_id
                      INTO l_session_id
                      FROM DUAL;

                    DBMS_OUTPUT.put_line ('l_session_id1 = ' || l_session_id);
                    msc_atp_global.get_atp_session_id (l_session_id, lc_var);
                    DBMS_OUTPUT.put_line ('l_session_id2 = ' || l_session_id);
                    DBMS_OUTPUT.put_line ('lc_var = ' || lc_var);

                    l_var   := 1;
                END IF;

                -- End :Added as part of version 1.4


                l_atp_rec.inventory_item_id (indx)          :=
                    l_inv_items_rec (indx).inventory_item_id;
                l_atp_rec.inventory_item_name (indx)        := NULL;
                l_atp_rec.quantity_ordered (indx)           :=
                    NVL (fnd_profile.VALUE ('XXDO_DOE_ATP_DEFAULT_REQ_QTY'),
                         999999999);                          --p_qty_ordered;
                --l_atp_rec.quantity_ordered (indx) := 1;
                l_atp_rec.quantity_uom (indx)               :=
                    l_inv_items_rec (indx).primary_uom_code;
                -- l_atp_rec.requested_ship_date (indx) := p_req_ship_date;Commented by Infosys-02-Sep-2016
                l_atp_rec.action (indx)                     := 100;
                --100 ATP Inquiry   110Scheduling   120Rescheduling
                l_atp_rec.instance_id (indx)                := NULL;
                l_atp_rec.source_organization_id (indx)     :=
                    l_inv_items_rec (indx).warehouse_id;
                --l_rec_size.ORGANIZATION_ID;
                l_atp_rec.demand_class (indx)               :=
                    l_demand_class_code;
                l_atp_rec.oe_flag (indx)                    := 'N';
                --Flag to indicate if supply/demand and period details are calculated or not. If this field is
                --set to 1 then ATP calculates supply/demand and period details.
                l_atp_rec.insert_flag (indx)                := 1;
                l_atp_rec.attribute_04 (indx)               := 1;
                l_atp_rec.customer_id (indx)                := NULL;
                l_atp_rec.customer_site_id (indx)           := NULL;
                l_atp_rec.calling_module (indx)             := 660; --'724' indicates planning server
                --'660' indicates OM
                --'708' indicates configurator
                --'-1' indicates backlog scheduling workbench
                l_atp_rec.row_id (indx)                     := NULL;
                l_atp_rec.source_organization_code (indx)   := NULL;
                l_atp_rec.organization_id (indx)            :=
                    l_inv_items_rec (indx).warehouse_id;
                --l_rec_size.ORGANIZATION_ID;
                l_atp_rec.order_number (indx)               := NULL;
                l_atp_rec.line_number (indx)                := NULL;
                l_atp_rec.override_flag (indx)              := NULL;
                l_atp_rec.Identifier (indx)                 :=
                    XXDO_BULK_ATP_IDENTIFIER_S.NEXTVAL;          -- Ram: Added



                --Start :Added by Infosys-02-Sep-2016
                BEGIN
                    -- Start:Commented as part of version 1.4
                    /*
                    SELECT MAX(EXPECTED_DELIVERY_DATE)
                    INTO v_req_ship_date
                    FROM MTL_SUPPLY
                    WHERE item_id=l_inv_items_rec(indx).inventory_item_id
                    AND TO_ORGANIZATION_ID=l_inv_items_rec(indx).warehouse_id
                    AND SUPPLY_TYPE_CODE='PO';*/
                    -- End:Commented as part of version 1.4

                    -- Start:Added as part of version 1.4
                    SELECT MAX (new_schedule_date)
                      INTO v_req_ship_date
                      FROM apps.msc_supplies@BT_EBS_TO_ASCP.US.ORACLE.COM msp, apps.msc_plans@BT_EBS_TO_ASCP.US.ORACLE.COM mp, apps.msc_system_items@BT_EBS_TO_ASCP.US.ORACLE.COM msi
                     WHERE     msi.inventory_item_id = msp.inventory_item_id
                           AND msi.organization_id = msp.organization_id
                           AND msp.plan_id = mp.plan_id
                           AND msi.plan_id = mp.plan_id
                           AND mp.compile_designator = 'ATP'
                           AND msp.new_order_quantity < 100000000000
                           AND msi.sr_inventory_item_id =
                               l_inv_items_rec (indx).inventory_item_id
                           AND msi.organization_id =
                               l_inv_items_rec (indx).warehouse_id;
                -- End :Added as part of version 1.4
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_req_ship_date   := p_req_ship_date;
                END;


                IF TRUNC (p_req_ship_date) >=
                   TRUNC (NVL (v_req_ship_date, p_req_ship_date))
                THEN
                    l_atp_rec.requested_ship_date (indx)   := p_req_ship_date;
                ELSE
                    l_atp_rec.requested_ship_date (indx)   := v_req_ship_date;
                END IF;
            --End :Added by Infosys-02-Sep-2016

            END LOOP;

            EXIT WHEN cur_get_color%NOTFOUND;
        END LOOP;

        CLOSE cur_get_color;

        IF l_var > 0
        THEN
            -- Call get ATP package
            /*get_atp_prc(  p_atp_rec            => l_atp_rec
                         ,x_atp_rec            => l_atp_rec_out
                         ,x_atp_supply_demand  => x_atp_supply_demand
                         ,x_atp_period         => x_atp_period
                         ,x_atp_details        => x_atp_details
                         ,x_return_status      => x_errflag
                         ,x_error_message      => x_errmessage
                         );    */
            -- Start:Commented as part of version 1.4
            /*
             SELECT oe_order_sch_util.get_session_id
             INTO l_session_id
             FROM DUAL;

             DBMS_OUTPUT.put_line ('l_session_id1 = ' || l_session_id);
             msc_atp_global.get_atp_session_id (l_session_id, lc_var);
             DBMS_OUTPUT.put_line ('l_session_id2 = ' || l_session_id);*/
            -- End :Commented as part of version 1.4
            --Commented this part of change 1.1 version
            /*    apps.mrp_atp_pub.call_atp (l_session_id,
                                           l_atp_rec,
                                           l_atp_rec_out,
                                           x_atp_supply_demand,
                                           x_atp_period,
                                           x_atp_details,
                                           x_errflag,
                                           x_msg_data,
                                           x_msg_count
                                          );*/
            ---Added this procedure of no_commit as part of 1.1 version

            SAVEPOINT ATPROLLBACK_FUTUREDATE;                  ----1.3 Version

            apps.mrp_atp_pub.call_atp_no_commit (l_session_id,
                                                 l_atp_rec,
                                                 l_atp_rec_out,
                                                 x_atp_supply_demand,
                                                 x_atp_period,
                                                 x_atp_details,
                                                 x_errflag,
                                                 x_msg_data,
                                                 x_msg_count);

            IF (x_errflag = 'S')
            THEN
                /*FOR i IN 1 .. x_atp_period.inventory_item_id.COUNT
                LOOP*/
                FOR lc_future_atp IN cur_get_atp (l_session_id)
                LOOP
                    x_atp_style_out_temp1.EXTEND (1);
                    l_cnt   := l_cnt + 1;
                    --initializing record type with NULL
                    x_atp_style_out_temp1 (l_cnt)   :=
                        xxd_atp_for_style (NULL, NULL, NULL,
                                           NULL, NULL);

                    --Calling procedure get_atr_onhand_prc to get ATR and OnHand Qty values for an Item
                    FOR lc_rec_size_cur
                        IN cur_get_color (p_style,
                                          p_color,
                                          p_org_id,
                                          p_item_type,
                                          lc_future_atp.inventory_item_id)
                    LOOP
                        DBMS_OUTPUT.put_line (
                               'Inventory Item ID from ATP API  :'
                            || lc_future_atp.inventory_item_id);
                        x_atp_style_out_temp1 (l_cnt).style   :=
                            lc_rec_size_cur.style;
                        x_atp_style_out_temp1 (l_cnt).color   :=
                            lc_rec_size_cur.color_description;
                        x_atp_style_out_temp1 (l_cnt).request_date   :=
                            lc_future_atp.Period_Start_Date;
                        x_atp_style_out_temp1 (l_cnt).sizes   :=
                            lc_rec_size_cur.l_size;
                        x_atp_style_out_temp1 (l_cnt).atp   :=
                            lc_future_atp.qty;
                    END LOOP;
                END LOOP;

                l_cnt                   := 0;

                FOR j
                    IN (  SELECT STYLE, COLOR, REQUEST_DATE
                            FROM TABLE (x_atp_style_out_temp1)
                           WHERE TRUNC (REQUEST_DATE) >=
                                 TRUNC (p_req_ship_date)
                        GROUP BY REQUEST_DATE, STYLE, COLOR
                        ORDER BY REQUEST_DATE)
                LOOP
                    FOR p IN (  SELECT DISTINCT SIZES
                                  FROM TABLE (x_atp_style_out_temp1)
                              ORDER BY SIZES)
                    LOOP
                        future_qty                             := 0;
                        x_atp_style_out.EXTEND (1);
                        l_cnt                                  := l_cnt + 1;
                        x_atp_style_out (l_cnt)                :=
                            xxd_atp_for_style (NULL, NULL, NULL,
                                               NULL, NULL);
                        x_atp_style_out (l_cnt).style          := j.style;
                        x_atp_style_out (l_cnt).color          := j.COLOR;
                        x_atp_style_out (l_cnt).request_date   :=
                            j.request_date;
                        x_atp_style_out (l_cnt).sizes          := p.sizes;
                        DBMS_OUTPUT.put_line ('sizes  :' || p.sizes);
                        DBMS_OUTPUT.put_line (
                            'request_date  :' || j.request_date);

                        BEGIN
                            future_qty   := 0;
                            DBMS_OUTPUT.put_line (
                                'Inside Begin for ATP Quantity');

                            SELECT ATP
                              INTO future_qty
                              FROM TABLE (x_atp_style_out_temp1)
                             WHERE     TRUNC (request_date) =
                                       TRUNC (j.request_date)
                                   AND SIZES = p.sizes;

                            DBMS_OUTPUT.put_line (
                                'future_qty ' || future_qty);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                DBMS_OUTPUT.put_line ('When others');

                                BEGIN
                                    SELECT ATP
                                      INTO future_qty
                                      FROM TABLE (x_atp_style_out_temp1)
                                     WHERE     TRUNC (request_date) =
                                               TRUNC (
                                                   (SELECT MAX (request_date)
                                                      FROM TABLE (x_atp_style_out_temp1)
                                                     WHERE     TRUNC (
                                                                   request_date) <
                                                               TRUNC (
                                                                   j.request_date)
                                                           AND SIZES =
                                                               p.sizes))
                                           AND SIZES = p.sizes;

                                    DBMS_OUTPUT.put_line (
                                           'When others future_qty'
                                        || future_qty);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        DBMS_OUTPUT.put_line (
                                            'When others 2');
                                END;
                        END;

                        x_atp_style_out (l_cnt).atp            :=
                            NVL (future_qty, 0);
                    END LOOP;
                END LOOP;

                x_atp_color_tabletype   := atp_color_table_type ();
                l_cnt                   := 0;

                FOR j IN (  SELECT DISTINCT COLOR, REQUEST_DATE
                              FROM TABLE (x_atp_style_out)
                          ORDER BY REQUEST_DATE)
                --  ORDER BY REQUEST_DATE DESC)       --   Version 1.5
                LOOP
                    x_atp_color_tabletype.EXTEND (1);
                    l_cnt                                 := l_cnt + 1;
                    x_atp_color_tabletype (l_cnt)         :=
                        xxd_atp_color_rcrd_type (NULL, NULL);
                    x_atp_color_tabletype (l_cnt).color   := j.color;
                    x_atp_color_tabletype (l_cnt).Request_Date   :=
                        j.REQUEST_DATE;
                END LOOP;

                x_atp_size_tabletype    := atp_size_tabletype ();
                l_cnt                   := 0;

                FOR k IN (  SELECT DISTINCT SIZES
                              FROM TABLE (x_atp_style_out)
                          ORDER BY SIZES)
                LOOP
                    x_atp_size_tabletype.EXTEND (1);
                    l_cnt                                    := l_cnt + 1;
                    x_atp_size_tabletype (l_cnt)             :=
                        xxd_atp_size_rcrd_type (NULL);
                    x_atp_size_tabletype (l_cnt).item_size   := k.SIZES;
                END LOOP;
            END IF;

            ROLLBACK TO ATPROLLBACK_FUTUREDATE;                 ---1.3 Version
            COMMIT;                                              --1.3 Version
        ELSE
            RAISE not_found_excep;
        END IF;
    EXCEPTION
        WHEN not_found_excep
        THEN
            x_errflag      := 'E';
            x_errmessage   := 'No Item available for this Sub-Style';
            DBMS_OUTPUT.put_line ('No Item available for this Sub-Style');
        WHEN OTHERS
        THEN
            x_errflag   := 'E';
            raise_application_error (
                -20001,
                   'An error was encountered in procedure get_atp_future_dates'
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
                    x_primary_uom            OUT VARCHAR2, --added 10-Nov-2014
                    x_category_id            OUT NUMBER,
                    x_total_onhand_qty       OUT NUMBER,
                    x_total_atr_value        OUT NUMBER,
                    x_total_atp_value        OUT NUMBER,
                    y_operand                OUT NUMBER, -- Added by INFOSYS on 19thJul
                    z_operand                OUT NUMBER, -- Added by INFOSYS on 19thJul
                    p_ou                  IN     NUMBER)
    IS
        l_atp_rec               mrp_atp_pub.atp_rec_typ;
        l_atp_rec_out           mrp_atp_pub.atp_rec_typ;
        x_atp_supply_demand     mrp_atp_pub.atp_supply_demand_typ;
        x_atp_period            mrp_atp_pub.atp_period_typ;
        x_atp_details           mrp_atp_pub.atp_details_typ;
        x_atp_atr_tab_temp      xxd_atp_atr_tab;                ---1.2 Version
        ln_atp_qty              NUMBER;
        ln_req_date_qty         NUMBER;
        ld_available_date       DATE;
        ln_qty_atr              NUMBER;
        ln_onhand_qty           NUMBER;
        ln_cnt                  NUMBER := 0;
        l_inv_id                NUMBER := 0;
        l_org_id                NUMBER;
        l_operand               NUMBER;
        lv_err_msg              VARCHAR2 (4000);
        v_errmsg                VARCHAR2 (4000);
        lv_err_code             VARCHAR2 (30);
        get_atp_prc_excep       EXCEPTION;
        get_atr_onhand_excep    EXCEPTION;
        not_found_excep         EXCEPTION;
        l_operand_wsv           NUMBER;         -- Added by INFOSYS on 19thJul
        l_operand_rv            NUMBER;         -- Added by INFOSYS on 19thJul
        p_price_list_name_wsv   VARCHAR2 (400); -- Added by INFOSYS on 19thJul
        p_price_list_name_rv    VARCHAR2 (400); -- Added by INFOSYS on 19thJul
        i                       NUMBER := 0;

        CURSOR cur_get_size (p_style VARCHAR2, p_color VARCHAR2, p_org_id NUMBER
                             , p_item_type VARCHAR2, p_inv_item_id NUMBER)
        IS
              SELECT msi.attribute27 l_size, micat.category_id category_id, msi.inventory_item_id inventory_item_id,
                     msi.organization_id organization_id, msi.primary_uom_code primary_uom_code
                FROM mtl_system_items_b msi, mtl_item_categories micat, mtl_categories mcat,
                     mtl_category_sets mcats
               WHERE     mcats.category_set_name LIKE 'Inventory'
                     AND micat.category_set_id = mcats.category_set_id
                     AND micat.category_id = mcat.category_id
                     AND msi.inventory_item_id = micat.inventory_item_id
                     AND msi.inventory_item_id =
                         NVL (p_inv_item_id, msi.inventory_item_id)
                     AND mcats.structure_id = mcat.structure_id
                     AND mcat.attribute_category = 'Item Categories'
                     --included Structure ID join
                     AND msi.organization_id = micat.organization_id
                     AND mcat.segment7 = p_style
                     --modified because SubStyle will be passed in place of MasterStyle
                     AND mcat.segment8 = p_color
                     --modified because Color Desc would be passed in place of ColorCode
                     AND msi.organization_id = p_org_id
                     AND NVL (msi.attribute28, 'PROD') =
                         NVL (p_item_type, 'PROD')
            --Added item type as new input
            ORDER BY msi.attribute27;                    --added order by size

        l_demand_class_code     VARCHAR2 (60);

        TYPE get_size_tbl_type IS TABLE OF cur_get_size%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_inv_items_rec         get_size_tbl_type;
    BEGIN
        x_atp_atr_tab_out    := xxd_atp_atr_tab ();
        x_atp_atr_tab_temp   := xxd_atp_atr_tab ();             ---1.2 Version
        fnd_global.apps_initialize (p_user_id, p_resp_id, p_resp_appl_id);
        x_total_onhand_qty   := 0;
        x_total_atr_value    := 0;
        x_total_atp_value    := 0;
        x_errflag            := 'S';
        x_errmessage         := '';

        --test_prc('Before Lookup Input paramer for Demand Class : '||p_demand_class_code);

        BEGIN
            l_demand_class_code   := NULL;

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
                l_demand_class_code   := 'UGG-DILLARDS';
                DBMS_OUTPUT.put_line (
                    'DEFAUTL Demand Class Code :- ' || l_demand_class_code);
        END;

        --test_prc('After Lookup Input paramer for Demand Class : '||l_demand_class_code);

        OPEN cur_get_size (p_style, p_color, p_org_id,
                           p_item_type, NULL);

        LOOP
            --FETCH cur_get_size INTO l_rec_size;
            -- EXIT WHEN cur_get_size%NOTFOUND;
            FETCH cur_get_size BULK COLLECT INTO l_inv_items_rec;

            DBMS_OUTPUT.PUT_LINE (
                ' Number of rows fetched : ' || l_inv_items_rec.COUNT);
            -- BEGIN LOGIC TO POPULATE THE RECORD TYPE FOR WHICH WE NEED TO FETCH THE ATP
            msc_atp_global.extend_atp (l_atp_rec,
                                       x_errmessage,
                                       l_inv_items_rec.COUNT);

            FOR indx IN 1 .. l_inv_items_rec.COUNT
            LOOP
                l_inv_id                                    := l_inv_items_rec (indx).inventory_item_id;
                l_atp_rec.inventory_item_id (indx)          :=
                    l_inv_items_rec (indx).inventory_item_id;
                l_atp_rec.inventory_item_name (indx)        := NULL;
                l_atp_rec.quantity_ordered (indx)           :=
                    NVL (fnd_profile.VALUE ('XXDO_DOE_ATP_DEFAULT_REQ_QTY'),
                         999999999);                          --p_qty_ordered;
                l_atp_rec.quantity_uom (indx)               :=
                    l_inv_items_rec (indx).primary_uom_code;
                l_atp_rec.requested_ship_date (indx)        := p_req_ship_date;
                l_atp_rec.action (indx)                     := 100;
                --100 ATP Inquiry   110Scheduling   120Rescheduling
                l_atp_rec.instance_id (indx)                := NULL;
                l_atp_rec.source_organization_id (indx)     := p_source_org_id;
                --l_rec_size.ORGANIZATION_ID;
                l_atp_rec.demand_class (indx)               :=
                    l_demand_class_code;
                l_atp_rec.oe_flag (indx)                    := 'N';
                --Flag to indicate if supply/demand and period details are calculated or not. If this field is
                --set to 1 then ATP calculates supply/demand and period details.
                l_atp_rec.insert_flag (indx)                := 0;
                l_atp_rec.attribute_04 (indx)               := 1;
                l_atp_rec.customer_id (indx)                := NULL;
                l_atp_rec.customer_site_id (indx)           := NULL;
                l_atp_rec.calling_module (indx)             := 660; --'724' indicates planning server
                --'660' indicates OM
                --'708' indicates configurator
                --'-1' indicates backlog scheduling workbench
                l_atp_rec.row_id (indx)                     := NULL;
                l_atp_rec.source_organization_code (indx)   := NULL;
                l_atp_rec.organization_id (indx)            :=
                    p_source_org_id;
                --l_rec_size.ORGANIZATION_ID;
                l_atp_rec.order_number (indx)               := NULL;
                l_atp_rec.line_number (indx)                := NULL;
                l_atp_rec.override_flag (indx)              := NULL;
                l_atp_rec.Identifier (indx)                 :=
                    XXDO_BULK_ATP_IDENTIFIER_S.NEXTVAL;          -- Ram: Added
            END LOOP;

            EXIT WHEN cur_get_size%NOTFOUND;
        END LOOP;

        CLOSE cur_get_size;

        -- Call get ATP package
        get_atp_prc (p_atp_rec => l_atp_rec, x_atp_rec => l_atp_rec_out, x_atp_supply_demand => x_atp_supply_demand, x_atp_period => x_atp_period, x_atp_details => x_atp_details, x_return_status => x_errflag
                     , x_error_message => x_errmessage);

        IF (x_errflag = 'S')
        THEN
            FOR i IN 1 .. l_atp_rec_out.inventory_item_id.COUNT
            LOOP
                DBMS_OUTPUT.put_line (
                    'ATP from ATP API  :' || l_atp_rec_out.available_quantity (i));
                x_atp_atr_tab_temp.EXTEND (1);                  ---1.2 Version
                ln_cnt        := ln_cnt + 1;
                x_atp_atr_tab_temp (ln_cnt)   :=                ---1.2 Version
                    xxd_atp_atr_onhand_size (NULL, NULL, NULL,
                                             NULL, NULL, NULL,
                                             NULL, NULL, NULL,
                                             NULL);
                lv_err_msg    := NULL;
                lv_err_code   := NULL;

                IF (l_atp_rec_out.ERROR_CODE (i) <> 0)
                THEN
                    SELECT meaning
                      INTO lv_err_msg
                      FROM mfg_lookups
                     WHERE     lookup_type = 'MTL_DEMAND_INTERFACE_ERRORS'
                           AND lookup_code = l_atp_rec_out.ERROR_CODE (i);

                    -- assign the error code to E
                    lv_err_code         := 'E';
                    --l_atp_rec_out.available_quantity(i)  :=  0;
                    ln_req_date_qty     :=
                        l_atp_rec_out.requested_date_quantity (i);
                    ld_available_date   := l_atp_rec_out.Ship_Date (i);
                ELSE
                    lv_err_code   := 'S';
                END IF;

                DBMS_OUTPUT.put_line (
                    'Inventory Item ID from ATP API  :' || l_atp_rec_out.inventory_item_id (i));

                --Calling procedure get_atr_onhand_prc to get ATR and OnHand Qty values for an Item
                FOR lc_rec_size_cur
                    IN cur_get_size (p_style,
                                     p_color,
                                     p_org_id,
                                     p_item_type,
                                     l_atp_rec_out.inventory_item_id (i))
                LOOP
                    get_atr_onhand_prc (ln_qty_atr,
                                        ln_onhand_qty,
                                        v_errmsg,
                                        lc_rec_size_cur.inventory_item_id,
                                        lc_rec_size_cur.organization_id);
                    ---1.2 Version Start
                    x_atp_atr_tab_temp (ln_cnt).inventory_item_id   :=
                        lc_rec_size_cur.inventory_item_id;
                    --x_atp_atr_tab_out (ln_cnt).atp := l_atp_rec_out.available_quantity(i);
                    x_atp_atr_tab_temp (ln_cnt).atp             :=
                        l_atp_rec_out.requested_date_quantity (i);
                    --test_prc('ATP Value for Demand Class '||l_demand_class_code||' is '||l_atp_rec_out.requested_date_quantity(i));
                    x_atp_atr_tab_temp (ln_cnt).atr             := ln_qty_atr;
                    x_atp_atr_tab_temp (ln_cnt).onhand          := ln_onhand_qty;
                    x_atp_atr_tab_temp (ln_cnt).SIZES           :=
                        lc_rec_size_cur.l_size;
                    x_atp_atr_tab_temp (ln_cnt).ERROR_CODE      := lv_err_code;
                    x_atp_atr_tab_temp (ln_cnt).error_message   := lv_err_msg; --x_errmessage;
                    x_atp_atr_tab_temp (ln_cnt).requested_date_quantity   :=
                        l_atp_rec_out.requested_date_quantity (i);
                    x_atp_atr_tab_temp (ln_cnt).req_item_available_date   :=
                        l_atp_rec_out.Ship_Date (i);

                    ---1.2 Version end

                    x_category_id                               :=
                        lc_rec_size_cur.category_id;
                    x_total_onhand_qty                          :=
                        x_total_onhand_qty + ln_onhand_qty;
                    x_total_atr_value                           :=
                        x_total_atr_value + ln_qty_atr;
                    x_total_atp_value                           :=
                          x_total_atp_value
                        + l_atp_rec_out.requested_date_quantity (i);
                    x_primary_uom                               :=
                        lc_rec_size_cur.primary_uom_code;  --added 10-Nov-2014
                END LOOP;
            END LOOP;

            ---1.2 Version Start
            ln_cnt   := 0;

            FOR k IN (  SELECT inventory_item_id, atp, SIZES,
                               ATR, ONHAND, ERROR_CODE,
                               ERROR_MESSAGE, requested_date_quantity, req_item_available_date
                          FROM TABLE (x_atp_atr_tab_temp)
                      ORDER BY SIZES)
            LOOP
                x_atp_atr_tab_out.EXTEND (1);
                ln_cnt                                               := ln_cnt + 1;
                x_atp_atr_tab_out (ln_cnt)                           :=
                    xxd_atp_atr_onhand_size (NULL, NULL, NULL,
                                             NULL, NULL, NULL,
                                             NULL, NULL, NULL,
                                             NULL);
                x_atp_atr_tab_out (ln_cnt).atr                       := k.ATR;
                x_atp_atr_tab_out (ln_cnt).onhand                    := k.onhand;
                x_atp_atr_tab_out (ln_cnt).SIZES                     := k.sizes;
                x_atp_atr_tab_out (ln_cnt).ERROR_CODE                := k.ERROR_CODE;
                x_atp_atr_tab_out (ln_cnt).error_message             := k.error_message; --x_errmessage;
                x_atp_atr_tab_out (ln_cnt).requested_date_quantity   :=
                    k.requested_date_quantity;
                x_atp_atr_tab_out (ln_cnt).req_item_available_date   :=
                    k.req_item_available_date;
                x_atp_atr_tab_out (ln_cnt).inventory_item_id         :=
                    k.inventory_item_id;
                x_atp_atr_tab_out (ln_cnt).atp                       := k.atp;
            END LOOP;

            ---1.2 Version End



            IF l_inv_id != 0
            THEN
                DBMS_OUTPUT.put_line ('l_inv_id :' || l_inv_id);
                DBMS_OUTPUT.put_line (
                    'p_price_list_name  ' || p_price_list_name);
                DBMS_OUTPUT.put_line ('p_org_id :' || p_org_id);


                BEGIN                         -- Added by LN on 19thJul(Start)
                    /*   select
                       ATTRIBUTE1,
                       ATTRIBUTE2
                       INTO
                       p_price_list_name_wsv,
                       p_price_list_name_rv
                       from fnd_lookup_values flv,
                       hr_operating_units hr,
                       org_organization_definitions ood
                       where flv.lookup_type='XXDOM_WHOLERETAIL_PLISTS'
                       and flv.language=userenv('LANG')
                       and flv.meaning=hr.name
                       and hr.organization_id=ood.operating_unit
                       and ood.organization_id=p_org_id
                       and enabled_flag='Y'
                       and (trunc(start_date_active)<=trunc(sysdate) and trunc(nvl(end_date_active,sysdate))>=trunc(sysdate)); */
                    SELECT ATTRIBUTE1, ATTRIBUTE2
                      INTO p_price_list_name_wsv, p_price_list_name_rv
                      FROM fnd_lookup_values flv, hr_operating_units hr
                     -- org_organization_definitions ood
                     WHERE     flv.lookup_type = 'XXDOM_WHOLERETAIL_PLISTS'
                           AND flv.language = USERENV ('LANG')
                           AND flv.meaning = hr.name
                           AND hr.organization_id = p_ou
                           --    and hr.organization_id=ood.operating_unit
                           --and ood.organization_id=p_org_id
                           AND enabled_flag = 'Y'
                           AND (TRUNC (start_date_active) <= TRUNC (SYSDATE) AND TRUNC (NVL (end_date_active, SYSDATE)) >= TRUNC (SYSDATE));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'While fetching Price list names Entered into the Exception');
                        p_price_list_name_wsv   := NULL;
                        p_price_list_name_rv    := NULL;
                END; -- Added by INFOSYS on 19thJul(End) /*IF p_price_list_name IS NOT NULL THEN BEGIN*/

                IF p_price_list_name_wsv IS NOT NULL -- Added by INFOSYS on 19thJul(Start)
                THEN
                    BEGIN
                        get_price_list_prc (l_inv_id, p_price_list_name_wsv, p_org_id
                                            , p_req_ship_date, l_operand_wsv);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Entered into the excetpion while fetching operand values for wsv and rv');
                            l_operand_wsv   := NULL;
                    END;
                END IF; -- Added by INFOSYS on 19thJul(End) --/*IF p_price_list_name_wsv IS NOT NULL*/

                IF p_price_list_name_rv IS NOT NULL -- Added by INFOSYS on 19thJul(Start)
                THEN
                    BEGIN
                        get_price_list_prc (l_inv_id, p_price_list_name_rv, p_org_id
                                            , p_req_ship_date, l_operand_rv);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Entered into the excetpion while fetching operand values for wsv and rv');
                            l_operand_rv   := NULL;
                    END;
                END IF; -- Added by INFOSYS on 19thJul(End) --/*IF p_price_list_name_rv IS NOT NULL*/

                y_operand   := l_operand_wsv;   -- Added by INFOSYS on 19thJul
                z_operand   := l_operand_rv;    -- Added by INFOSYS on 19thJul

                IF y_operand IS NULL
                THEN
                    y_operand   := NULL;
                END IF;

                IF z_operand IS NULL
                THEN
                    z_operand   := NULL;
                END IF;

                IF p_price_list_name IS NOT NULL
                THEN
                    --Start of Calling procedure to get the Price List of an Item--
                    get_price_list_prc (l_inv_id, p_price_list_name, p_org_id
                                        , p_req_ship_date, l_operand);
                    --End of Calling procedure to get the Price List of an Item--
                    x_operand   := l_operand;
                ELSE
                    x_operand   := 0;
                END IF;
            ELSE
                RAISE not_found_excep;
            END IF;
        END IF;
    EXCEPTION
        WHEN not_found_excep
        THEN
            x_errflag   := 'E';
            x_errmessage   :=
                'No Item Found for a given combination of Sub-Style and Color';
        WHEN OTHERS
        THEN
            raise_application_error (
                -20001,
                   'An error was encountered in procedure MAIN '
                || SQLCODE
                || ' -ERROR- '
                || SQLERRM);
            x_errflag      := 'E';
            x_errmessage   := 'An error was encountered in procedure MAIN';
    END;
END XXD_BTOM_AVAILABILITY_PKG;
/
