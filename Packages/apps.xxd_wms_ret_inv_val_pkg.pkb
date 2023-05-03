--
-- XXD_WMS_RET_INV_VAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_RET_INV_VAL_PKG"
AS
    /******************************************************************************
     NAME           : XXDO.XXD_WMS_RET_INV_VAL_PKG
     REPORT NAME    : Deckers WMS Retail Inventory Valuation Report

     REVISIONS:
     Date       Author              Version Description
     ---------  ----------          ------- --------------------------------------------
     06/12/2019 Kranthi Bollam      1.0     Created this package for Retail Inventory
                                            valuation report(CCR0007979 - Deckers Macau
                                             Project)
     03/19/2020 Srinath Siricilla  2.0      Including ME1 and ME2 to DEL Consol as
                                            part of Macau UAT Defect- 512

    ******************************************************************************/

    --Global constants
    -- Return Statuses
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id            CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_conc_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;
    gn_limit_rec         CONSTANT NUMBER := 100;
    gn_commit_rows       CONSTANT NUMBER := 1000;

    FUNCTION before_report
        RETURN BOOLEAN
    IS
        --Cursors Declaration
        --Cursor to get the items for which the Margin has to be calculated and displayed in report
        CURSOR src_cur IS
              SELECT stg.*, xrs.store_type rms_store_type, xrs.currency_code store_currency_code
                FROM xxdo.xxd_wms_ret_inv_val_stg stg, apps.xxd_retail_stores_v xrs
               WHERE     1 = 1
                     AND stg.request_id = gn_conc_request_id
                     AND stg.store_number = xrs.rms_store_id
            ORDER BY stg.store_number;

        --Cursor to get Shipment details
        CURSOR ship_cur (cn_inv_item_id    IN NUMBER,
                         cn_store_number   IN NUMBER,
                         cd_as_of_date     IN DATE)
        IS
              SELECT oola.org_id, oola.ordered_item, mmt.transaction_id,
                     mmt.transaction_date, ABS (mmt.transaction_quantity) shipment_qty, mmt.actual_cost,
                     oola.unit_selling_price, oola.unit_list_price, stv.store_name,
                     mmt.organization_id, ooha.order_number, stv.store_type,
                     stv.currency_code store_currency, ooha.transactional_curr_code sales_ord_curr_code, gl.currency_code inv_org_curr_code
                --,mmt.currency_code inv_org_curr_code
                FROM --apps.hr_all_organization_units haou -- Commented as per change 2.0
                     apps.fnd_flex_value_sets ffvs_ind, apps.fnd_flex_values ffv_ind, apps.fnd_flex_values_tl ffvt_ind,
                     apps.fnd_flex_value_sets ffvs_dep, apps.fnd_flex_values ffv_dep, apps.fnd_flex_values_tl ffvt_dep,
                     apps.hr_operating_units hrou, apps.mtl_parameters mp-- end of change 2.0
                                                                         , apps.hr_organization_information hoi,
                     apps.gl_ledgers gl, apps.mtl_material_transactions mmt, apps.oe_order_lines_all oola,
                     apps.oe_order_headers_all ooha, apps.xxd_retail_stores_v stv
               WHERE     1 = 1
                     --           AND haou.attribute1 = TO_CHAR(pn_ou_id) -- Commented as per change 2.0
                     AND hrou.organization_id = pn_ou_id
                     AND hrou.name = ffv_ind.flex_value
                     AND mp.organization_code = ffv_dep.flex_value
                     --AND (pn_inv_org_id IS NULL OR haou.organization_id = pn_inv_org_id)
                     --AND haou.organization_id = hoi.organization_id
                     AND hoi.organization_id = mp.organization_id
                     AND (pn_inv_org_id IS NULL OR mp.organization_id = pn_inv_org_id)
                     -- End of Change 2.0
                     AND hoi.org_information_context = 'Accounting Information'
                     AND TO_NUMBER (hoi.org_information1) = gl.ledger_id
                     AND mmt.inventory_item_id = cn_inv_item_id
                     --AND mmt.organization_id = haou.organization_id
                     AND mmt.organization_id = mp.organization_id
                     AND mmt.transaction_date <= cd_as_of_date
                     AND mmt.transaction_type_id = 33      --Sales order issue
                     AND mmt.transaction_source_type_id = 2      --Sales order
                     AND mmt.trx_source_line_id = oola.line_id
                     AND mmt.organization_id = oola.ship_from_org_id
                     AND mmt.inventory_item_id = oola.inventory_item_id
                     AND oola.org_id = pn_ou_id
                     AND oola.header_id = ooha.header_id
                     AND ooha.sold_to_org_id = stv.ra_customer_id
                     AND stv.rms_store_id = cn_store_number
                     -- Added as per change 2.0
                     AND ffvs_ind.flex_value_set_id = ffv_ind.flex_value_set_id
                     AND ffv_ind.flex_value_id = ffvt_ind.flex_value_id
                     AND ffvt_ind.language = USERENV ('LANG')
                     AND UPPER (ffvs_ind.flex_value_set_name) =
                         'XXD_WMS_RET_INV_EBS_OU'
                     AND ffvs_ind.flex_value_set_id =
                         ffvs_dep.parent_flex_value_set_id
                     AND ffv_ind.flex_value = ffv_dep.parent_flex_value_low
                     AND ffvs_dep.flex_value_set_id = ffv_dep.flex_value_set_id
                     AND ffv_dep.flex_value_id = ffvt_dep.flex_value_id
                     AND ffvt_dep.language = USERENV ('LANG')
                     AND ffv_ind.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (ffv_ind.start_date_active,
                                              SYSDATE)
                                     AND NVL (ffv_ind.end_date_active, SYSDATE)
                     AND ffv_dep.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (ffv_dep.start_date_active,
                                              SYSDATE)
                                     AND NVL (ffv_dep.end_date_active, SYSDATE)
            -- End of Change 2.0
            ORDER BY mmt.transaction_date DESC, mmt.transaction_id DESC;

        --Local variables
        TYPE ret_onhand_rec_type IS RECORD
        (
            month_year              VARCHAR2 (10),
            soh_date                DATE,
            org_unit_desc_rms       VARCHAR2 (120),
            org_unit_id_rms         NUMBER,
            store_number            NUMBER,
            store_name              VARCHAR2 (150),
            brand                   VARCHAR2 (30),
            style                   VARCHAR2 (30),
            color_id                VARCHAR2 (30),
            color                   VARCHAR2 (30),
            style_color             VARCHAR2 (60),
            sku                     VARCHAR2 (60),
            inventory_item_id       NUMBER,
            class_name              VARCHAR2 (120),
            stock_on_hand           NUMBER (12, 4),
            extended_cost_amount    NUMBER (20, 4),
            unit_cost               NUMBER (20, 4)
        );

        TYPE ret_onhand_type IS TABLE OF ret_onhand_rec_type
            INDEX BY BINARY_INTEGER;

        ret_onhand_rec                ret_onhand_type;

        TYPE ret_onhand_cur_typ IS REF CURSOR;

        ret_onhand_cur                ret_onhand_cur_typ;

        ln_purge_days                 NUMBER := 60;
        lv_err_msg                    VARCHAR2 (4000) := NULL;
        lv_sql_stmt                   VARCHAR2 (32000) := NULL;
        lv_select_clause              VARCHAR2 (5000) := NULL;
        lv_from_clause                VARCHAR2 (5000) := NULL;
        lv_where_clause               VARCHAR2 (5000) := NULL;
        lv_store_cond                 VARCHAR2 (1000) := NULL;
        lv_org_unit_cond              VARCHAR2 (1000) := NULL;
        lv_brand_cond                 VARCHAR2 (1000) := NULL;
        lv_style_cond                 VARCHAR2 (1000) := NULL;
        lv_style_color_cond           VARCHAR2 (1000) := NULL;
        lv_sku_cond                   VARCHAR2 (1000) := NULL;
        lv_ou_name                    VARCHAR2 (120) := NULL;
        ln_remaining_soh              NUMBER := 0;
        ln_qty                        NUMBER := 0;
        ln_chg_qty                    NUMBER := 0;  -- Added as per Change 2.0
        lv_ship_qty_met_soh           VARCHAR2 (1) := 'N';
        ln_conv_rate                  NUMBER := 0;
        ln_conv_rate_usd              NUMBER := 0;
        ln_margin_store_curr          NUMBER := 0;
        ln_margin_usd                 NUMBER := 0;
        ln_margin_store_curr_final    NUMBER := 0;
        ln_margin_usd_final           NUMBER := 0;
        ln_avg_margin_st_curr_final   NUMBER := 0;
        ln_avg_margin_usd_final       NUMBER := 0;
        ln_loop_ctr                   NUMBER := 0;
        lv_shipments_exists           VARCHAR2 (1) := 'N';
        ln_conv_rate_to_trx_curr      NUMBER := 0;
        ln_actual_cost_order_curr     NUMBER := 0;
        ln_fixed_margin_pct           NUMBER := 0;
        ld_as_of_date                 DATE;
        --        ln_org_unit_id_rms          NUMBER          := 0;
        lv_org_unit_id_rms            VARCHAR2 (120) := NULL;
    BEGIN
        write_log (
               'In before_report Trigger - START. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        write_log (
               'Calling Purge Procedure - START. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        purge_prc (pn_purge_days => ln_purge_days);
        write_log (
               'Calling Purge Procedure - END. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        write_log (
               'Building SQL Statement - START. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        ld_as_of_date   :=
            TO_DATE (
                   TO_CHAR (LAST_DAY (TO_DATE (pv_period_name, 'MON-RR')),
                            'RRRR-MM-DD')
                || ' 23:59:59',
                'RRRR-MM-DD HH24:MI:SS');
        write_log ('As of date : ' || ld_as_of_date);
        lv_select_clause   :=
            'SELECT TO_CHAR(src.soh_date, ''MON-RRRR'') month_year
      ,src.soh_date
      ,src.org_unit_desc
      ,src.org_unit_id
      ,src.store store_number
      ,src.store_name
      ,src.brand brand
      ,src.style
      ,src.color color_id
      ,src.color_desc color
      ,src.style||''-''||src.color_desc style_color
      ,src.style||''-''||src.color_desc||''-''||item_size sku
      ,TO_NUMBER(src.item) item_id
      ,src.class_name
      ,src.stock_on_hand stock_on_hand
      ,src.extended_cost_amount extended_cost_amount
      ,ABS(src.unit_cost) unit_cost';
        lv_from_clause   :=
            '
        FROM ben.disco_eom_inv_snapshot_rtl_v@xxdo_retail_rms.us.oracle.com src';

        IF pn_store_number IS NOT NULL AND pn_ou_id IS NOT NULL
        THEN
            lv_store_cond   := '
            AND src.store = ' || pn_store_number;
        ELSIF pn_store_number IS NULL AND pn_ou_id IS NOT NULL
        THEN
            lv_store_cond   :=
                   '
            AND src.store IN (SELECT rms_store_id FROM apps.xxd_retail_stores_v WHERE operating_unit = '
                || pn_ou_id
                || ')';
        END IF;

        IF pn_org_unit_id_rms IS NOT NULL
        THEN
            lv_org_unit_cond   := '
            AND src.org_unit_id = ' || pn_org_unit_id_rms;
        ELSE
            lv_org_unit_id_rms   := get_org_unit_id_rms (pn_ou_id => pn_ou_id);

            IF lv_org_unit_id_rms IS NOT NULL
            THEN
                lv_org_unit_cond   := '
                AND src.org_unit_id IN (' || lv_org_unit_id_rms || ')';
            END IF;
        --            ln_org_unit_id_rms := get_org_unit_id_rms(pn_ou_id      =>  pn_ou_id);
        --            IF ln_org_unit_id_rms <> 0
        --            THEN
        --                lv_org_unit_cond := '
        --                AND src.org_unit_id = '||ln_org_unit_id_rms;
        --            END IF;
        END IF;

        IF pv_brand IS NOT NULL
        THEN
            lv_brand_cond   := '
            AND src.brand = ''' || pv_brand || '''';
        END IF;

        IF pv_style IS NOT NULL
        THEN
            lv_style_cond   := '
            AND src.style = ''' || pv_style || '''';
        END IF;

        IF pv_style_color IS NOT NULL
        THEN
            lv_style_color_cond   :=
                   '
            AND src.style||''-''||src.color_desc = '''
                || pv_style_color
                || '''';
        END IF;

        IF pn_inventory_item_id IS NOT NULL
        THEN
            lv_sku_cond   := '
            AND src.item = ''' || TO_CHAR (pn_inventory_item_id) || '''';
        END IF;

        lv_where_clause   :=
               '
        WHERE 1=1
          AND TO_CHAR(src.soh_date, ''MON-RR'') = '''
            || pv_period_name
            || '''
          AND src.stock_on_hand <> 0'
            || lv_store_cond
            || lv_org_unit_cond
            || lv_brand_cond
            || lv_style_cond
            || lv_style_color_cond
            || lv_sku_cond;

        lv_sql_stmt   :=
            lv_select_clause || lv_from_clause || lv_where_clause;
        write_log (
               'Building SQL Statement - END. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        write_log ('Retail Onhand Data Query');
        write_log ('***************************');
        write_log (lv_sql_stmt);
        write_log ('***************************');

        --Get operating unit name
        BEGIN
            SELECT hou.name
              INTO lv_ou_name
              FROM apps.hr_operating_units hou
             WHERE 1 = 1 AND hou.organization_id = pn_ou_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ou_name   := NULL;
                write_log (
                       'Unable to fetch Operating unit name for OU ID: '
                    || pn_ou_id
                    || ' . Error is: '
                    || SQLERRM);
                RETURN FALSE;
        END;

        write_log (
               'Fetching and Inserting Data into Staging table - START. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        BEGIN
            --Delete the data from the ret_onhand_rec if exists
            IF ret_onhand_rec.COUNT > 0
            THEN
                ret_onhand_rec.DELETE;
            END IF;

            --Opening the Cursor
            OPEN ret_onhand_cur FOR lv_sql_stmt;

            LOOP
                FETCH ret_onhand_cur
                    BULK COLLECT INTO ret_onhand_rec
                    LIMIT gn_limit_rec;

                IF ret_onhand_rec.COUNT > 0
                THEN
                    --Bulk Insert of Retail Onhand Inventory data into staging table
                    FORALL i IN ret_onhand_rec.FIRST .. ret_onhand_rec.LAST
                        INSERT INTO xxdo.xxd_wms_ret_inv_val_stg stg (
                                        seq_id,
                                        month_year,
                                        soh_date,
                                        operating_unit_id,
                                        operating_unit_name,
                                        org_unit_desc_rms,
                                        org_unit_id_rms,
                                        store_number,
                                        store_name,
                                        brand,
                                        style,
                                        color_id,
                                        color,
                                        style_color,
                                        sku,
                                        inventory_item_id,
                                        class_name,
                                        stock_on_hand,
                                        extended_cost_amount,
                                        unit_cost,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        request_id,
                                        last_update_login)
                             VALUES (xxdo.xxd_wms_ret_inv_val_stg_s.NEXTVAL --seq_id
                                                                           , ret_onhand_rec (i).month_year --month_year
                                                                                                          , ret_onhand_rec (i).soh_date --soh_date
                                                                                                                                       , pn_ou_id --operating_unit_id
                                                                                                                                                 , lv_ou_name --operating_unit_name
                                                                                                                                                             , ret_onhand_rec (i).org_unit_desc_rms --org_unit_desc_rms
                                                                                                                                                                                                   , ret_onhand_rec (i).org_unit_id_rms --org_unit_id_rms
                                                                                                                                                                                                                                       , ret_onhand_rec (i).store_number --store_number
                                                                                                                                                                                                                                                                        , ret_onhand_rec (i).store_name --store_name
                                                                                                                                                                                                                                                                                                       , ret_onhand_rec (i).brand --brand
                                                                                                                                                                                                                                                                                                                                 , ret_onhand_rec (i).style --style
                                                                                                                                                                                                                                                                                                                                                           , ret_onhand_rec (i).color_id --color_id
                                                                                                                                                                                                                                                                                                                                                                                        , ret_onhand_rec (i).color --color
                                                                                                                                                                                                                                                                                                                                                                                                                  , ret_onhand_rec (i).style_color --style_color
                                                                                                                                                                                                                                                                                                                                                                                                                                                  , ret_onhand_rec (i).sku --sku
                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , ret_onhand_rec (i).inventory_item_id --inventory_item_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , ret_onhand_rec (i).class_name --class_name
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , ret_onhand_rec (i).stock_on_hand --stock_on_hand
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 , ret_onhand_rec (i).extended_cost_amount --extended_cost_amount
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , ret_onhand_rec (i).unit_cost --unit_cost
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , SYSDATE --creation_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 , gn_user_id --created_by
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , SYSDATE --last_update_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , gn_user_id --last_updated_by
                                     , gn_conc_request_id         --request_id
                                                         , gn_login_id --last_update_login
                                                                      );

                    COMMIT;
                    ret_onhand_rec.DELETE;
                --Retail Onhand Data Cursor records Else
                ELSE
                    lv_err_msg   :=
                        'There are no Retail Onhand records for the Parameters provided.';
                    write_log (lv_err_msg);
                END IF;

                EXIT WHEN ret_onhand_cur%NOTFOUND;
            END LOOP;

            CLOSE ret_onhand_cur;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                    SUBSTR (
                           'Unable to open the cursor. Please check the cursor query.'
                        || SQLERRM,
                        1,
                        2000);
                write_log (lv_err_msg);

                --Close the cursor
                CLOSE ret_onhand_cur;

                RETURN FALSE;           --Return or Exit before_report trigger
        END;

        write_log (
               'Fetching and Inserting Data into Staging table - END. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        pv_sql_stmt   :=
               'SELECT * FROM xxdo.xxd_wms_ret_inv_val_stg stg WHERE stg.request_id = '
            || gn_conc_request_id;
        write_log ('**********Report Query**********');
        write_log (pv_sql_stmt);
        write_log ('********************************');
        write_log (
               'Getting the Margin values and updating Staging table - START. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        ln_loop_ctr   := 0;

        --Process the data that is inserted into the staging table to get Margin Values and update the staging table
        FOR src_rec IN src_cur
        LOOP
            --Assign total stock on hand to ln_remaining_soh variable
            ln_remaining_soh              := ABS (src_rec.stock_on_hand);
            lv_ship_qty_met_soh           := 'N';
            ln_margin_store_curr_final    := 0;
            ln_margin_usd_final           := 0;
            ln_avg_margin_st_curr_final   := 0;
            ln_avg_margin_usd_final       := 0;

            --Open the shipments cursor for the item and the store number and get the shipment details in the descending order of transaction date in MMT
            FOR ship_rec
                IN ship_cur (cn_inv_item_id    => src_rec.inventory_item_id,
                             cn_store_number   => src_rec.store_number,
                             cd_as_of_date     => ld_as_of_date)
            LOOP
                lv_shipments_exists    := 'Y'; --If the Shipment exists(If we enter the ship_cur loop), set to Yes
                ln_qty                 := 0;
                ln_margin_store_curr   := 0;
                ln_margin_usd          := 0;
                ln_chg_qty             := 0;        -- Added as per Change 2.0

                --If shipment quantity is equal to stock on hand in RMS then assign shipment or stock on hand quantity to ln_qty variable
                --and also set lv_ship_qty_met_soh to Yes. If lv_ship_qty_met_soh is yes, then exit the shipment loop as SOH met the shipment qty
                IF ship_rec.shipment_qty = ln_remaining_soh
                THEN
                    ln_qty                := ship_rec.shipment_qty;
                    --Decrease the stock on hand by the shipment qty
                    ln_remaining_soh      :=
                        ln_remaining_soh - ship_rec.shipment_qty;
                    lv_ship_qty_met_soh   := 'Y';
                --If shipment quantity is less than stock on hand in RMS then decrease the SOH by the shipment qty
                --and assign shipment qty to ln_qty variable and calculate the margin for ln_qty. Also loop through the shipments if any until the SOH is met
                ELSIF ship_rec.shipment_qty < ln_remaining_soh
                THEN
                    --Decrease the stock on hand by the shipment qty
                    ln_remaining_soh   :=
                        ln_remaining_soh - ship_rec.shipment_qty;
                    --Assign the shipment quantity to a variable for which qty the margin has to be calculated
                    ln_qty   := ship_rec.shipment_qty;
                --If shipment quantity is greater than stock on hand in RMS then assign stock on hand quantity to ln_qty variable
                --and also set lv_ship_qty_met_soh to Yes. If lv_ship_qty_met_soh is yes, then exit the shipment loop as SOH met the shipment qty
                ELSIF ship_rec.shipment_qty > ln_remaining_soh
                THEN
                    --Assign SOH or remaining SOH to ln_qty variable
                    ln_qty                := ln_remaining_soh;
                    --As the shipment quantity is greater than SOH/remaining SOH then set the shipment met SOH variable to Yes
                    lv_ship_qty_met_soh   := 'Y';
                    --Decrease the stock on hand by the shipment qty
                    ln_remaining_soh      :=
                        ln_remaining_soh - ship_rec.shipment_qty;
                END IF;

                --If Sales Order currency and Warehouse/Inv Org currency are not same, then convert the warehouse currency to sales order currency
                IF ship_rec.sales_ord_curr_code <> ship_rec.inv_org_curr_code
                THEN
                    ln_conv_rate_to_trx_curr   := NULL;
                    ln_conv_rate_to_trx_curr   :=
                        get_conv_rate (
                            pv_from_currency   => ship_rec.inv_org_curr_code --Warehouse Currency
                                                                            ,
                            pv_to_currency     => ship_rec.sales_ord_curr_code --Sales Order Currency
                                                                              ,
                            pd_conversion_date   =>
                                TRUNC (ship_rec.transaction_date) --Shipment/Transaction Date
                                                                 );
                    --Get actual cost in sales order currency and round it to 2 decimals
                    ln_actual_cost_order_curr   :=
                        ROUND (
                            ship_rec.actual_cost * ln_conv_rate_to_trx_curr,
                            2);
                ELSE
                    ln_actual_cost_order_curr   :=
                        ROUND (ship_rec.actual_cost, 2);
                END IF;

                --Margin Calculation in Store Currency(If Sales Order Currency is not equal to store currency, convert the order currency to store currency)
                IF ship_rec.sales_ord_curr_code <> ship_rec.store_currency
                THEN
                    ln_conv_rate   := NULL;
                    ln_conv_rate   :=
                        get_conv_rate (
                            pv_from_currency   => ship_rec.sales_ord_curr_code --Sales order currency
                                                                              ,
                            pv_to_currency     => ship_rec.store_currency --Store Currency Code
                                                                         ,
                            pd_conversion_date   =>
                                TRUNC (ship_rec.transaction_date) --Shipment/Transaction Date
                                                                 );

                    --Margin = unit selling price minus actual cost
                    --ln_margin := (ship_rec.unit_selling_price - ln_actual_cost_order_curr) * ln_qty;

                    -- Added as per Change 2.0

                    IF src_rec.stock_on_hand < 0
                    THEN
                        ln_chg_qty   := -1;
                    ELSE
                        ln_chg_qty   := 1;
                    END IF;

                    IF   ship_rec.unit_selling_price
                       - ln_actual_cost_order_curr <
                       0
                    THEN
                        ln_margin_store_curr   := 0;
                    ELSE
                        ln_margin_store_curr   :=
                              (ship_rec.unit_selling_price - ln_actual_cost_order_curr)
                            * ln_qty
                            * ln_chg_qty;
                    END IF;
                --                    ln_margin_store_curr := ((ship_rec.unit_selling_price - ln_actual_cost_order_curr) * ln_qty*ln_chg_qty) * ln_conv_rate;

                -- End of Change 2.0

                --If sales order currency and store currency are same then conversion is not required
                ELSE
                    --ln_margin := (ship_rec.unit_selling_price - ln_actual_cost_order_curr) * ln_qty;

                    -- Added as per change 2.0

                    IF src_rec.stock_on_hand < 0
                    THEN
                        ln_chg_qty   := -1;
                    ELSE
                        ln_chg_qty   := 1;
                    END IF;

                    IF   ship_rec.unit_selling_price
                       - ln_actual_cost_order_curr <
                       0
                    THEN
                        ln_margin_store_curr   := 0;
                    ELSE
                        ln_margin_store_curr   :=
                              (ship_rec.unit_selling_price - ln_actual_cost_order_curr)
                            * ln_qty
                            * ln_chg_qty;
                    END IF;
                --                    ln_margin_store_curr := (ship_rec.unit_selling_price - ln_actual_cost_order_curr) * ln_qty*ln_chg_qty;

                -- End of Change 2.0

                END IF;

                --Margin Calculation in USD
                IF ship_rec.store_currency <> 'USD'
                THEN
                    ln_conv_rate_usd   :=
                        get_conv_rate (
                            pv_from_currency   => ship_rec.store_currency,
                            pv_to_currency     => 'USD',
                            pd_conversion_date   =>
                                TRUNC (ship_rec.transaction_date));
                    --ln_margin_usd:= (ln_margin_store_curr * ln_qty) * ln_conv_rate_usd; --Commented on 30Jul2019
                    ln_margin_usd   :=
                        (ln_margin_store_curr) * ln_conv_rate_usd; --Added on 30Jul2019
                ELSE
                    --ln_margin_usd:= ln_margin_store_curr * ln_qty;  --Commented on 30Jul2019
                    ln_margin_usd   := ln_margin_store_curr; --Added on 30Jul2019
                END IF;

                --Add margin for current shipment to final margin for the item and store in both Store Currency and USD
                ln_margin_store_curr_final   :=
                    ln_margin_store_curr_final + ln_margin_store_curr;
                ln_margin_usd_final    :=
                    ln_margin_usd_final + ln_margin_usd;

                --If shipment quantity meets the Stock on hand then exit the shipment loop and move to next item in src_cur loop
                IF lv_ship_qty_met_soh = 'Y'
                THEN
                    EXIT; --exit the ship_cur loop and move to next item in src_cur loop
                END IF;
            END LOOP;                                      --ship_cur end loop

            --Check if shipments exists for this item and store in EBS or not
            IF lv_shipments_exists = 'Y'
            THEN
                --Check if remaining stock on hand quantity is negative or zero(ln_remaining_soh = ln_remaining_soh - shipment qty for each shipment record)
                --Negative or zero means, shipment quantity is equal or more than stock on hand
                IF ln_remaining_soh <= 0
                THEN
                    ln_avg_margin_st_curr_final   :=
                        ln_margin_store_curr_final / src_rec.stock_on_hand;
                    ln_avg_margin_usd_final   :=
                        ln_margin_usd_final / src_rec.stock_on_hand;
                --ln_remaining_soh is greater than ZERO then Shipment quantity is less than stock on hand
                --In this case for the remaining Stock on hand, get the fixed margin from value set as there are no more shipment records
                ELSE
                    --Get the fixed margin from lookup for the remaining stock on hand(ln_remaining_soh) and calculate Margins
                    ln_fixed_margin_pct   :=
                        get_fixed_margin_pct (
                            pn_ou_id        => pn_ou_id,
                            pv_brand        => src_rec.brand,
                            pv_store_type   => src_rec.rms_store_type);

                    IF src_rec.store_currency_code <> 'USD'
                    THEN
                        ln_conv_rate_usd   := NULL;
                        ln_conv_rate_usd   :=
                            get_conv_rate (
                                pv_from_currency   =>
                                    src_rec.store_currency_code,
                                pv_to_currency   => 'USD',
                                pd_conversion_date   =>
                                    TRUNC (src_rec.soh_date));
                    ELSE
                        ln_conv_rate_usd   := 1;
                    END IF;

                    ln_margin_store_curr_final   :=
                          ln_margin_store_curr_final
                        + ((ln_remaining_soh * src_rec.unit_cost) * (ln_fixed_margin_pct / 100));
                    ln_margin_usd_final   :=
                          ln_margin_usd_final
                        + ((ln_remaining_soh * src_rec.unit_cost) * (ln_fixed_margin_pct / 100) * ln_conv_rate_usd);
                    ln_avg_margin_st_curr_final   :=
                        ln_margin_store_curr_final / ln_remaining_soh;
                    ln_avg_margin_usd_final   :=
                        ln_margin_usd_final / ln_remaining_soh;
                END IF;
            --If shipments does not exists for an item and store then get the fixed margin from value set and calculate margin values
            ELSE
                --Write the logic to derive fixed margin and calculate the margins
                ln_fixed_margin_pct   :=
                    get_fixed_margin_pct (
                        pn_ou_id        => pn_ou_id,
                        pv_brand        => src_rec.brand,
                        pv_store_type   => src_rec.rms_store_type);

                IF src_rec.store_currency_code <> 'USD'
                THEN
                    ln_conv_rate_usd   := NULL;
                    ln_conv_rate_usd   :=
                        get_conv_rate (
                            pv_from_currency     => src_rec.store_currency_code,
                            pv_to_currency       => 'USD',
                            pd_conversion_date   => TRUNC (src_rec.soh_date));
                ELSE
                    ln_conv_rate_usd   := 1;
                END IF;

                ln_margin_store_curr_final   :=
                      (src_rec.stock_on_hand * src_rec.unit_cost)
                    * (ln_fixed_margin_pct / 100);
                ln_margin_usd_final   :=
                      (src_rec.stock_on_hand * src_rec.unit_cost)
                    * (ln_fixed_margin_pct / 100)
                    * ln_conv_rate_usd;
                ln_avg_margin_st_curr_final   :=
                    ln_margin_store_curr_final / src_rec.stock_on_hand;
                ln_avg_margin_usd_final   :=
                    ln_margin_usd_final / src_rec.stock_on_hand;
            END IF;

            -- Start of Change 2.0

            /* IF NVL(ln_margin_store_curr_final,0) < 0
             THEN
                 ln_margin_store_curr_final := 0;
             END IF;

             IF NVL(ln_margin_usd_final,0) < 0
             THEN
                 ln_margin_usd_final := 0;
             END IF;

             IF NVL(ln_avg_margin_st_curr_final,0) < 0
             THEN
                 ln_avg_margin_st_curr_final := 0;
             END IF;

             IF NVL(ln_avg_margin_usd_final,0) < 0
             THEN
                 ln_avg_margin_usd_final := 0;
             END IF;*/

            -- End of Change

            --Update the staging table with the margin values
            BEGIN
                UPDATE xxdo.xxd_wms_ret_inv_val_stg stg
                   SET stg.avg_margin_store_curr = ln_avg_margin_st_curr_final, stg.ic_margin_store_curr = ln_margin_store_curr_final, stg.avg_margin_usd = ln_avg_margin_usd_final,
                       stg.ic_margin_usd = ln_margin_usd_final, stg.store_type = src_rec.rms_store_type, stg.store_currency = src_rec.store_currency_code,
                       stg.last_update_date = SYSDATE, stg.last_updated_by = gn_user_id, stg.request_id = gn_conc_request_id
                 WHERE 1 = 1 AND stg.seq_id = src_rec.seq_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log (
                           'Error while updating staging table for Sequence ID: '
                        || src_rec.seq_id);
            END;

            ln_loop_ctr                   := ln_loop_ctr + 1;

            --Issue commit for every gn_commit_rows records
            IF MOD (ln_loop_ctr, gn_commit_rows) = 0
            THEN
                COMMIT;
            END IF;
        END LOOP;                                           --src_cur end loop

        COMMIT;
        write_log (
               'Getting the Margin values and updating Staging table - END. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        write_log (
               'In before_report Trigger - END. Timestamp:'
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in before_report trigger - ' || SQLERRM);
            RETURN FALSE;
    END before_report;

    FUNCTION after_report
        RETURN BOOLEAN
    IS
        l_req_id   NUMBER;
    BEGIN
        write_log ('Inside after_report trigger');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in after_report trigger - ' || SQLERRM);
            RETURN FALSE;
    END after_report;

    --To delete the data older than pn_purge_days
    PROCEDURE purge_prc (pn_purge_days IN NUMBER)
    IS
        CURSOR purge_cur IS
            SELECT DISTINCT stg.request_id
              FROM xxdo.xxd_wms_ret_inv_val_stg stg
             WHERE 1 = 1 AND stg.creation_date < (SYSDATE - pn_purge_days);
    BEGIN
        FOR purge_rec IN purge_cur
        LOOP
            DELETE FROM xxdo.xxd_wms_ret_inv_val_stg
                  WHERE 1 = 1 AND request_id = purge_rec.request_id;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in Purge Procedure -' || SQLERRM);
    END purge_prc;

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in WRITE_LOG Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;

    FUNCTION get_conv_rate (pv_from_currency IN VARCHAR2, pv_to_currency IN VARCHAR2, pd_conversion_date IN DATE)
        RETURN NUMBER
    IS
        ln_conversion_rate   NUMBER := 0;
    BEGIN
        SELECT gdr.conversion_rate
          INTO ln_conversion_rate
          FROM apps.gl_daily_rates gdr
         WHERE     1 = 1
               AND gdr.conversion_type = 'Corporate'
               AND gdr.from_currency = pv_from_currency
               AND gdr.to_currency = pv_to_currency
               AND gdr.conversion_date = pd_conversion_date;

        RETURN ln_conversion_rate;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in GET_CONV_RATE Procedure -' || SQLERRM);
            ln_conversion_rate   := 0;
            RETURN ln_conversion_rate;
    END get_conv_rate;

    FUNCTION get_store_currency (pn_store_number IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_store_currency   VARCHAR2 (3) := NULL;
    BEGIN
        SELECT currency_code
          INTO lv_store_currency
          FROM apps.xxd_retail_stores_v st
         WHERE 1 = 1 AND st.rms_store_id = pn_store_number;

        RETURN lv_store_currency;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in GET_STORE_CURRENCY Procedure -' || SQLERRM);
            lv_store_currency   := NULL;
            RETURN lv_store_currency;
    END get_store_currency;

    FUNCTION get_fixed_margin_pct (pn_ou_id        IN NUMBER,
                                   pv_brand        IN VARCHAR2,
                                   pv_store_type   IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_fixed_margin_pct   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT margin_pct
              INTO ln_fixed_margin_pct
              FROM (SELECT TO_NUMBER (ffvl.attribute4) margin_pct, RANK () OVER (PARTITION BY ffvl.attribute1 ORDER BY ffvl.attribute1, ffvl.attribute2, ffvl.attribute3 NULLS LAST) rnk
                      FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                     WHERE     1 = 1
                           AND ffvs.flex_value_set_name =
                               'XXD_WMS_RET_INV_FIXED_MARGIN'
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND TO_NUMBER (ffvl.attribute1) = pn_ou_id
                           -- Added as per change 2.0
                           AND ffvl.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (ffvl.start_date_active,
                                                    SYSDATE)
                                           AND NVL (ffvl.end_date_active,
                                                    SYSDATE)
                           -- End of change 2.0
                           AND CASE
                                   WHEN ffvl.attribute2 IS NOT NULL
                                   THEN
                                       ffvl.attribute2
                                   ELSE
                                       pv_brand
                               END =
                               pv_brand
                           AND CASE
                                   WHEN ffvl.attribute3 IS NOT NULL
                                   THEN
                                       ffvl.attribute3
                                   ELSE
                                       pv_store_type
                               END =
                               pv_store_type) xx
             WHERE rnk = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_fixed_margin_pct   := 0;
                write_log (
                       'OU='
                    || pn_ou_id
                    || ', BRAND='
                    || pv_brand
                    || ' and STORE_TYPE='
                    || pv_store_type
                    || ' combination is not defined in XXD_WMS_RET_INV_FIXED_MARGIN value set.');
            WHEN TOO_MANY_ROWS
            THEN
                ln_fixed_margin_pct   := 0;
                write_log (
                       'OU='
                    || pn_ou_id
                    || ', BRAND='
                    || pv_brand
                    || ' and STORE_TYPE='
                    || pv_store_type
                    || ' combination in XXD_WMS_RET_INV_FIXED_MARGIN value set.');
            WHEN OTHERS
            THEN
                ln_fixed_margin_pct   := 0;
                write_log (
                       'Error in getting margin percent from XXD_WMS_RET_INV_FIXED_MARGIN value set for OU='
                    || pn_ou_id
                    || ', BRAND='
                    || pv_brand
                    || ' and STORE_TYPE='
                    || pv_store_type
                    || '. Error is: '
                    || SQLERRM);
        END;

        RETURN ln_fixed_margin_pct;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log (
                'Error in GET_FIXED_MARGIN_PCT Procedure -' || SQLERRM);
            ln_fixed_margin_pct   := 0;
            RETURN ln_fixed_margin_pct;
    END get_fixed_margin_pct;

    FUNCTION get_org_unit_id_rms (pn_ou_id IN NUMBER)
        RETURN VARCHAR2
    IS
        CURSOR ou_cur IS
            SELECT ou_rms.org_unit_id
              FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl, apps.hr_operating_units hou,
                   rms13prod.org_unit@xxdo_retail_rms ou_rms
             WHERE     1 = 1
                   AND ffvs.flex_value_set_name = 'XXD_WMS_RET_INV_OU_MAP'
                   AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                   -- Added as per change 2.0
                   AND ffvl.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (ffvl.start_date_active, SYSDATE)
                                   AND NVL (ffvl.end_date_active, SYSDATE)
                   -- End of change 2.0
                   AND ffvl.description = hou.name
                   AND hou.organization_id = pn_ou_id
                   AND ffvl.flex_value = ou_rms.description;

        ln_org_unit_id   NUMBER := 0;
        lv_ou_tmp        VARCHAR2 (120) := NULL;
    BEGIN
        FOR ou_rec IN ou_cur
        LOOP
            lv_ou_tmp   := lv_ou_tmp || ',' || ou_rec.org_unit_id;
        END LOOP;

        IF LENGTH (lv_ou_tmp) > 0
        THEN
            lv_ou_tmp   := SUBSTR (lv_ou_tmp, 2);
        ELSE
            lv_ou_tmp   := NULL;
        END IF;

        RETURN lv_ou_tmp;
    --        BEGIN
    --            SELECT ou_rms.org_unit_id
    --              INTO ln_org_unit_id
    --              FROM apps.fnd_flex_value_sets ffvs
    --                  ,apps.fnd_flex_values_vl ffvl
    --                  ,apps.hr_operating_units hou
    --                  ,rms13prod.org_unit@xxdo_retail_rms ou_rms
    --             WHERE 1=1
    --               AND ffvs.flex_value_set_name = 'XXD_WMS_RET_INV_OU_MAP'
    --               AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
    --               AND ffvl.description = hou.name
    --               AND hou.organization_id = pn_ou_id
    --               AND ffvl.flex_value = ou_rms.description
    --            ;
    --        EXCEPTION
    --            WHEN NO_DATA_FOUND THEN
    --                ln_org_unit_id := 0;
    --                write_log('OU ID: '||pn_ou_id||' not mapped in XXD_WMS_RET_INV_OU_MAP value set.');
    --            WHEN TOO_MANY_ROWS THEN
    --                ln_org_unit_id := 0;
    --                write_log('More than one records exists for OU mapping in XXD_WMS_RET_INV_OU_MAP value set. for OU ID: '||pn_ou_id);
    --            WHEN OTHERS THEN
    --                ln_org_unit_id := 0;
    --                write_log('Error in getting OU Mapping from XXD_WMS_RET_INV_OU_MAP value set for OU ID: '||pn_ou_id||'. Error is: '||SQLERRM);
    --        END;
    --        RETURN ln_org_unit_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in GET_ORG_UNIT_ID_RMS Procedure -' || SQLERRM);
            ln_org_unit_id   := 0;
            RETURN ln_org_unit_id;
    END get_org_unit_id_rms;
END XXD_WMS_RET_INV_VAL_PKG;
/
