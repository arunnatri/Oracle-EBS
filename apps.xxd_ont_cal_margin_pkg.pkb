--
-- XXD_ONT_CAL_MARGIN_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_CAL_MARGIN_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CAL_MARGIN_PKG
    * Design       :
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 01-Dec-2021  1.1       Balavenu Rao        source cost derivation CCR0008574
    ******************************************************************************************/
    gv_debug               VARCHAR2 (3);
    gn_conc_request_id     NUMBER;
    gn_mc1_org_id          NUMBER;
    gn_user_id             NUMBER := fnd_global.USER_ID;
    gn_order_src_id        NUMBER := 0;
    gn_login_id            NUMBER := fnd_global.LOGIN_ID;
    gd_from_cut_off_date   DATE;
    gd_to_cut_off_date     DATE;
    gv_usd_cur_code        VARCHAR2 (5) := 'USD';
    gv_jpy_cur_code        VARCHAR2 (5) := 'JPY';
    gv_mc1_to_any          VARCHAR2 (20) := 'MC1 TO ANY';
    gv_same_ou             VARCHAR2 (20) := 'SAME OU';
    gv_different_ou        VARCHAR2 (20) := 'DIFFERENT OU';
    gn_round_fact          NUMBER := 2;
    ge_raise_exception     EXCEPTION;
    gv_gather_stats        VARCHAR2 (15);

    PROCEDURE LOG (pv_debug VARCHAR2, pv_msgtxt_in IN VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF pv_debug = 'Y'
        THEN
            IF fnd_global.conc_login_id = -1
            THEN
                DBMS_OUTPUT.put_line (pv_msgtxt_in);
            --fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
            ELSE
                fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
            END IF;
        END IF;

        BEGIN
            INSERT INTO XXD_ONT_PO_MARGIN_ERR_LOG_T (request_id,
                                                     error_message_1,
                                                     creation_date,
                                                     created_by,
                                                     last_update_date,
                                                     last_updated_by)
                 VALUES (gn_conc_request_id, pv_msgtxt_in, SYSDATE,
                         gn_user_id, SYSDATE, gn_user_id);

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while inserting record into Error Log table');
        END;
    END LOG;

    FUNCTION func_get_cut_off_date (pv_lookup_code VARCHAR2)
        RETURN DATE
    IS
        ld_cut_off_date   DATE;
    BEGIN
        SELECT MAX (fnd_date.canonical_to_date (attribute2)) cut_off_date
          INTO ld_cut_off_date
          FROM fnd_lookup_values_vl
         WHERE     1 = 1
               AND lookup_type = 'XXD_PROFIT_ELMINATE_CUT_OFF_DT'
               AND lookup_code = pv_lookup_code
               AND SYSDATE BETWEEN NVL (
                                       START_DATE_ACTIVE,
                                       TO_DATE ('01-JAN-2000', 'DD-MON-RRRR'))
                               AND NVL (end_date_active, SYSDATE + 1)
               AND enabled_flag = 'Y';

        RETURN ld_cut_off_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error While getting the cut off date');
            RETURN NULL;
    END;

    PROCEDURE proc_reprocess (pv_mode VARCHAR2, pd_reprocess_date DATE)
    IS
    BEGIN
        UPDATE XXDO.XXD_ONT_PO_MARGIN_CALC_T
           SET process_flag   =                           --start changes v1.1
                   CASE
                       WHEN source = 'TQ_PO_RECEIVING' THEN 'N'
                       ELSE 'C'
                   END
         --end changes v1.1
         WHERE 1 = 1 AND creation_date >= pd_reprocess_date;

        --start changes v1.1
        UPDATE XXDO.XXD_ONT_PO_IR_MARGIN_CALC_T
           SET                                            --start changes v1.1
               --          process_flag = 'N'
               process_flag   = 'C'
         --end changes v1.1
         WHERE 1 = 1 AND creation_date >= pd_reprocess_date;
    --end changes v1.1
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                gv_debug,
                'Error @proc_reprocess while updating the table to reprocess');
    END;


    PROCEDURE proc_update_cutoff_date (pv_lookup_code VARCHAR2, pv_start_time DATE, pv_end_time DATE)
    IS
        lv_start_time   VARCHAR2 (250)
            := TO_CHAR (pv_start_time, 'RRRR/MM/DD HH24:mi:ss');
        lv_end_time     VARCHAR2 (250)
                            := TO_CHAR (pv_end_time, 'RRRR/MM/DD HH24:mi:ss');

        CURSOR c1 IS
            SELECT lookup_type, lookup_code, enabled_flag,
                   security_group_id, view_application_id, tag,
                   lv_start_time attribute1, lv_end_time attribute2, start_date_active,
                   end_date_active, meaning, description
              FROM fnd_lookup_values_vl
             WHERE     lookup_type = 'XXD_PROFIT_ELMINATE_CUT_OFF_DT'
                   AND lookup_code = pv_lookup_code
                   AND ROWNUM = 1;
    BEGIN
        FOR i IN c1
        LOOP
            BEGIN
                fnd_lookup_values_pkg.update_row (
                    x_lookup_type           => i.lookup_type,
                    x_security_group_id     => i.security_group_id,
                    x_view_application_id   => i.view_application_id,
                    x_lookup_code           => i.lookup_code,
                    x_tag                   => i.tag,
                    x_attribute_category    =>
                        'XXD_PROFIT_ELMINATE_CUT_OFF_DT',
                    x_attribute1            => i.attribute1,
                    x_attribute2            => i.attribute2,
                    x_attribute3            => NULL,
                    x_attribute4            => NULL,
                    x_enabled_flag          => 'Y',
                    x_start_date_active     => i.start_date_active,
                    x_end_date_active       => i.end_date_active,
                    x_territory_code        => NULL,
                    x_attribute5            => NULL,
                    x_attribute6            => NULL,
                    x_attribute7            => NULL,
                    x_attribute8            => NULL,
                    x_attribute9            => NULL,
                    x_attribute10           => NULL,
                    x_attribute11           => NULL,
                    x_attribute12           => NULL,
                    x_attribute13           => NULL,
                    x_attribute14           => NULL,
                    x_attribute15           => NULL,
                    x_meaning               => i.meaning,
                    x_description           => i.description,
                    x_last_update_date      => TRUNC (SYSDATE),
                    x_last_updated_by       => fnd_global.user_id,
                    x_last_update_login     => fnd_global.user_id);

                COMMIT;

                LOG (gv_debug, i.lookup_code || ' has been Updated  !!!!');
            EXCEPTION
                WHEN OTHERS
                THEN
                    LOG (
                        gv_debug,
                           i.lookup_code
                        || ' - Inner Exception @proc_update_cutoff_date - '
                        || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error @proc_update_cutoff_date ' || SQLERRM);
    END;

    PROCEDURE proc_gather_table_stats (pv_owner_name VARCHAR2, pv_tab_name VARCHAR2, pb_cascade BOOLEAN)
    IS
        ln_change_factor   NUMBER;
    BEGIN
        IF NVL (gv_gather_stats, 'N') = 'N'
        THEN
            SELECT change_factor
              INTO ln_change_factor
              FROM (  SELECT m.table_owner,
                             m.table_name,
                             t.last_analyzed,
                             m.inserts,
                             m.updates,
                             m.deletes,
                             t.num_rows,
                               (m.inserts + m.updates + m.deletes)
                             / CASE
                                   WHEN t.num_rows IS NULL OR t.num_rows = 0
                                   THEN
                                       1
                                   ELSE
                                       t.num_rows
                               END Change_Factor
                        FROM dba_tab_modifications m, dba_tables t
                       WHERE     t.owner = m.table_owner
                             AND t.table_name = m.table_name
                             AND m.inserts + m.updates + m.deletes > 1
                             AND m.table_owner = pv_owner_name
                             AND m.table_name = pv_tab_name
                    ORDER BY change_factor DESC);

            IF ln_change_factor > 25
            THEN
                sys.DBMS_STATS.gather_table_stats (ownname   => pv_owner_name,
                                                   tabname   => pv_tab_name,
                                                   cascade   => pb_cascade);
            END IF;
        ELSE
            sys.DBMS_STATS.gather_table_stats (ownname   => pv_owner_name,
                                               tabname   => pv_tab_name,
                                               cascade   => pb_cascade);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error @proc_gather_table_stats' || SQLERRM);
    END;

    PROCEDURE proc_purge_custom_table (pd_cut_off_date DATE)
    IS
    BEGIN
        DELETE FROM
            XXDO.XXD_ONT_PO_MARGIN_CALC_T
              WHERE     1 = 1
                    AND creation_date <=
                        NVL (pd_cut_off_date, ADD_MONTHS (SYSDATE, -12));
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error @proc_purge_custom_table - ' || SQLERRM);
    END;

    FUNCTION get_inv_org_currency (pn_organization_id NUMBER)
        RETURN VARCHAR2
    IS
        lv_currency_code   VARCHAR2 (20);
    BEGIN
        SELECT gll.currency_code
          INTO lv_currency_code
          FROM org_organization_definitions ood, gl_ledgers gll
         WHERE     1 = 1
               AND ood.organization_id = pn_organization_id
               AND ood.set_of_books_id = gll.ledger_id;

        RETURN lv_currency_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                gv_debug,
                   'Error while fetching currency code for Inventory Org '
                || pn_organization_id
                || '- '
                || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_corp_rate (pd_rcpt_shpmt_dt   DATE,
                            pv_from_currency   VARCHAR2,
                            pv_to_currency     VARCHAR2)
        RETURN NUMBER
    IS
        ln_conv_rate   NUMBER;
    BEGIN
        SELECT conversion_rate
          INTO ln_conv_rate
          FROM gl_daily_rates
         WHERE     1 = 1
               AND conversion_type = 'Corporate'
               AND from_currency = pv_from_currency
               AND to_currency = pv_to_currency
               AND conversion_date = TRUNC (pd_rcpt_shpmt_dt);

        RETURN ln_conv_rate;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            BEGIN
                IF pv_from_currency = pv_to_currency
                THEN
                    RETURN 1;
                ELSE
                    LOG (
                        gv_debug,
                           'pv_from_currency - '
                        || pv_from_currency
                        || ' pv_to_currency - '
                        || pv_to_currency
                        || ' pd_rcpt_shpmt_dt -  '
                        || pd_rcpt_shpmt_dt);
                    --            x_retcode:=2;
                    RAISE ge_raise_exception;
                    RETURN NULL;
                END IF;
            EXCEPTION
                WHEN ge_raise_exception
                THEN
                    LOG (
                        gv_debug,
                           'Error While fetching conversion rate for pv_from_currency - '
                        || pv_from_currency
                        || ' pv_to_currency - '
                        || pv_to_currency
                        || ' pd_rcpt_shpmt_dt -  '
                        || pd_rcpt_shpmt_dt);
            END;
        WHEN OTHERS
        THEN
            LOG (
                gv_debug,
                   'Error while fetching conversion rate for rcpt_po_date '
                || pd_rcpt_shpmt_dt
                || ' FROM CURRENCY - '
                || pv_from_currency
                || ' and TO CURRENCY'
                || pv_to_currency
                || '- '
                || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_operating_unit (pn_organization_id NUMBER)
        RETURN NUMBER
    IS
        lv_ou   NUMBER;
    BEGIN
        SELECT ood.operating_unit
          INTO lv_ou
          FROM org_organization_definitions ood
         WHERE 1 = 1 AND ood.organization_id = pn_organization_id;

        RETURN lv_ou;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                gv_debug,
                   'Error while fetching get_operating_unit for Inventory Org '
                || pn_organization_id
                || '- '
                || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_macau_to_x_Trans_mrgn (pv_cost IN VARCHAR2, pn_organization_id NUMBER, pn_inventory_item_id NUMBER
                                        , pv_custom_cost IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_total_cost   NUMBER;                                     --ItemCOST
    BEGIN
        ln_total_cost   :=
            apps.XXDOGET_ITEM_COST (pv_cost,                      --'ITEMCOST'
                                             pn_organization_id, pn_inventory_item_id
                                    , 'Y');


        IF NVL (ln_total_cost, 0) = 0
        THEN
            BEGIN
                SELECT NVL (LIST_PRICE_PER_UNIT, 0)
                  INTO ln_total_cost
                  FROM mtl_system_items_b
                 WHERE     1 = 1
                       AND organization_id = pn_organization_id
                       AND inventory_item_id = pn_inventory_item_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_total_cost   := 0;
            END;
        END IF;

        RETURN ln_total_cost;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error @get_macau_to_x_Trans_mrgn' || SQLERRM);
            RETURN 0;
    END;


    FUNCTION get_avg_prior_cst (pn_dstn_organization_id NUMBER, pn_inventory_item_id NUMBER, pn_sequence_number NUMBER
                                , pd_ship_confirm_dt DATE)
        RETURN NUMBER
    IS
        ln_avg_cost   NUMBER;                                       --ItemCOST
    BEGIN
        SELECT AVG_MRGN_CST_USD
          INTO ln_avg_cost
          FROM XXD_ONT_PO_MARGIN_CALC_T
         WHERE     1 = 1
               AND sequence_number =
                   (SELECT MAX (sequence_number)
                      FROM XXD_ONT_PO_MARGIN_CALC_T
                     WHERE     1 = 1
                           AND destination_organization_id =
                               pn_dstn_organization_id
                           AND inventory_item_id = pn_inventory_item_id
                           AND source <> 'TQ_SO_SHIPMENT'
                           AND sequence_number < pn_sequence_number);

        RETURN ln_avg_cost;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 0;
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error @get_avg_prior_cst' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_max_seq_num (pn_oe_line_id          NUMBER,
                              pv_source              VARCHAR2,
                              pn_inventory_item_id   NUMBER)
        RETURN NUMBER
    IS
        ln_max_seq   NUMBER;                                        --ItemCOST
    BEGIN
        SELECT MAX (sequence_number)
          INTO ln_max_seq
          FROM XXD_ONT_PO_MARGIN_CALC_T
         WHERE     1 = 1
               AND source = pv_source
               AND line_id = pn_oe_line_id
               AND inventory_item_id = pn_inventory_item_id --'TQ_SO_SHIPMENT'
                                                           ;

        RETURN ln_max_seq;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error @get_max_seq_num' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION get_unprocessed_lines_count (pn_inventory_item_id   NUMBER,
                                          pn_seq_num             NUMBER)
        RETURN NUMBER
    IS
        ln_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM xxdo.XXD_ONT_PO_MARGIN_CALC_T xop1
         WHERE     1 = 1
               AND xop1.sequence_number < pn_seq_num
               AND xop1.inventory_item_id = pn_inventory_item_id
               AND xop1.process_flag = 'C';

        RETURN ln_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_count   := 0;
            LOG (gv_debug,
                 'Error @get_unprocessed_lines_count - ' || SQLERRM);
    END;



    PROCEDURE proc_copy_trx_margin (pn_oe_line_id              NUMBER,
                                    pn_inventory_item_id       NUMBER,
                                    pv_currency_code           VARCHAR2,
                                    xn_trx_margin_local    OUT NUMBER,
                                    xn_trx_margin_usd      OUT NUMBER)
    IS
        ln_trx_margin_local   NUMBER;
        ln_trx_margin_usd     NUMBER;
    BEGIN
        SELECT ROUND (
                     TRX_MRGN_CST_USD
                   * XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (transaction_date,
                                                           gv_usd_cur_code,
                                                           pv_currency_code),
                   CASE
                       WHEN pv_currency_code = gv_jpy_cur_code THEN 0
                       ELSE gn_round_fact
                   END) TRX_MRGN_CST_LOCAL,
               TRX_MRGN_CST_USD
          INTO ln_trx_margin_local, ln_trx_margin_usd
          FROM XXD_ONT_PO_MARGIN_CALC_T
         WHERE     1 = 1
               AND inventory_item_id = pn_inventory_item_id
               AND line_id = pn_oe_line_id
               AND sequence_number =
                   XXD_ONT_CAL_MARGIN_PKG.get_max_seq_num (
                       pn_oe_line_id,
                       'TQ_SO_SHIPMENT',
                       pn_inventory_item_id)
               AND source <> 'TQ_PO_RECEIVING';

        xn_trx_margin_local   := ln_trx_margin_local;
        xn_trx_margin_usd     := ln_trx_margin_usd;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            xn_trx_margin_local   := 0;
            xn_trx_margin_usd     := 0;
        WHEN OTHERS
        THEN
            xn_trx_margin_local   := NULL;
            xn_trx_margin_usd     := NULL;
            LOG (gv_debug, 'Error @proc_copy_trx_margin' || SQLERRM);
    END;

    FUNCTION get_onhand_eligible (pn_inventory_item_id   NUMBER,
                                  pn_sequence_number     NUMBER)
        RETURN VARCHAR2
    IS
        lv_onhand_eligible   VARCHAR2 (5);                          --ItemCOST
    BEGIN
        SELECT CASE
                   WHEN on_hand_qty_destn IS NOT NULL THEN 'YES'
                   ELSE 'NO'
               END
          INTO lv_onhand_eligible
          FROM XXD_ONT_PO_MARGIN_CALC_T
         WHERE     1 = 1
               AND sequence_number =
                   (SELECT MAX (sequence_number)
                      FROM XXD_ONT_PO_MARGIN_CALC_T
                     WHERE     1 = 1
                           AND inventory_item_id = pn_inventory_item_id
                           AND source <> 'TQ_SO_SHIPMENT'
                           AND sequence_number < pn_sequence_number);

        RETURN lv_onhand_eligible;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'YES';
        WHEN OTHERS
        THEN
            RAISE ge_raise_exception;
            LOG (gv_debug, 'Error @get_onhand_eligible' || SQLERRM);
            RETURN 'NO';
    END;


    FUNCTION get_costing_org (pn_src_organization_id    NUMBER,
                              pn_dstn_organization_id   NUMBER)
        RETURN NUMBER
    IS
        lv_costing_org   NUMBER := NULL;                            --ItemCOST
    BEGIN
        SELECT mp.organization_id
          INTO lv_costing_org
          FROM MTL_SHIPPING_NETWORK_VIEW msnv, mtl_parameters mp
         WHERE     1 = 1
               AND msnv.attribute2 IN ('Yes', 'Y') --Inter Co.s eligible for profit elimination
               AND msnv.from_organization_id = pn_src_organization_id
               AND msnv.attribute3 = mp.organization_code
               AND msnv.to_organization_id = pn_dstn_organization_id;

        IF NVL (lv_costing_org, 9999999) <> 9999999
        THEN
            RETURN lv_costing_org;
        ELSE
            RAISE ge_raise_exception;
        END IF;
    EXCEPTION
        WHEN ge_raise_exception
        THEN
            LOG (
                gv_debug,
                   'Error @get_costing_org for pn_src_organization_id - '
                || pn_src_organization_id
                || ' pn_dstn_organization_id - '
                || pn_dstn_organization_id
                || ' is - '
                || SQLERRM);
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error @get_costing_org' || SQLERRM);

            RETURN NULL;
    END;

    FUNCTION get_onhand_qty (pn_organization_id     NUMBER,
                             pn_inventory_item_id   NUMBER)
        RETURN NUMBER
    IS
        ln_onhand_qty   NUMBER;
    BEGIN
          SELECT SUM (moqd.transaction_quantity) AS quantity
            INTO ln_onhand_qty
            FROM apps.mtl_secondary_inventories msi, apps.mtl_onhand_quantities moqd
           WHERE     moqd.organization_id = pn_organization_id
                 AND msi.organization_id = moqd.organization_id
                 AND moqd.inventory_item_id = pn_inventory_item_id
                 AND msi.secondary_inventory_name = moqd.subinventory_code
                 AND msi.asset_inventory = 1
                 AND msi.secondary_inventory_name NOT IN -- Start Changes by BT Technology Team on 23/01/2014
                         -- ('QCFAIL', 'QCB', 'REJ', 'REJECTS', 'QCFAIL')
                         (SELECT ff2.flex_value
                            FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ff2
                           WHERE     ff1.flex_value_set_id =
                                     ff2.flex_value_set_id
                                 AND UPPER (ff1.flex_value_set_name) =
                                     UPPER ('XXDO_SECONDARY_INV_NAME')
                                 AND SYSDATE BETWEEN NVL (
                                                         ff2.start_date_active,
                                                         SYSDATE - 1)
                                                 AND NVL (ff2.end_date_active,
                                                          SYSDATE + 1)
                                 AND ff2.enabled_flag = 'Y') -- End changes by BT Technology Team On 23/01/2014
        GROUP BY moqd.inventory_item_id, moqd.organization_id;

        RETURN ln_onhand_qty;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            --         LOG (
            --            gv_debug,
            --               'NO_DATA_FOUND Error while fetching get_onhand_qty for Inventory Org '
            --            || pn_organization_id
            --            || ' and Inventory_item_id -  '
            --            || pn_inventory_item_id
            --            || '- '
            --            || SQLERRM);
            RETURN 0;
        WHEN OTHERS
        THEN
            BEGIN
                RAISE ge_raise_exception;
            EXCEPTION
                WHEN ge_raise_exception
                THEN
                    LOG (
                        gv_debug,
                           'Error while fetching get_onhand_qty for Inventory Org '
                        || pn_organization_id
                        || ' and Inventory_item_id -  '
                        || pn_inventory_item_id
                        || '- '
                        || SQLERRM);
            END;
    --         LOG (
    --            gv_debug,
    --               'Error while fetching get_onhand_qty for Inventory Org '
    --            || pn_organization_id
    --            || ' and Inventory_item_id -  '
    --            || pn_inventory_item_id
    --            || '- '
    --            || SQLERRM);
    --         RETURN NULL;
    END;

    FUNCTION get_costed_onhand_qty (pv_source VARCHAR2, pv_custom_source VARCHAR2, pn_organization_id NUMBER
                                    , pn_inventory_item_id NUMBER, pn_source_line_id NUMBER, pn_mmt_trx_id NUMBER)
        RETURN NUMBER
    IS
        ln_onhand_qty   NUMBER := NULL;
    BEGIN
        SELECT CASE pv_source
                   WHEN 'ORDER ENTRY' THEN TRANSFER_PRIOR_COSTED_QUANTITY
                   WHEN 'RCV' THEN PRIOR_COSTED_QUANTITY
                   ELSE 0
               END AS quantity
          INTO ln_onhand_qty
          FROM apps.mtl_material_transactions mmt
         WHERE     1 = 1
               AND mmt.transaction_id = pn_mmt_trx_id
               AND mmt.organization_id = pn_organization_id
               AND mmt.inventory_item_id = pn_inventory_item_id
               AND mmt.source_code = pv_source
               AND mmt.source_line_id = pn_source_line_id;

        IF pv_custom_source <> 'TQ_SO_SHIPMENT'
        THEN
            RETURN ln_onhand_qty;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 0;
        WHEN OTHERS
        THEN
            BEGIN
                RAISE ge_raise_exception;
            EXCEPTION
                WHEN ge_raise_exception
                THEN
                    LOG (
                        gv_debug,
                           'Error while fetching get_onhand_qty for Inventory Org '
                        || pn_organization_id
                        || ' and Inventory_item_id -  '
                        || pn_inventory_item_id
                        || '- '
                        || SQLERRM);
            END;
    END;

    --start changes v1.1
    FUNCTION get_so_max_seq_num (pn_req_line_id         NUMBER,
                                 pv_source              VARCHAR2,
                                 pn_inventory_item_id   NUMBER)
        RETURN NUMBER
    IS
        ln_max_seq   NUMBER;                                        --ItemCOST
    BEGIN
        SELECT MAX (sequence_number)
          INTO ln_max_seq
          FROM XXD_ONT_PO_MARGIN_CALC_T
         WHERE     1 = 1
               AND source = pv_source
               AND requisition_line_id = pn_req_line_id
               AND inventory_item_id = pn_inventory_item_id --'TQ_SO_SHIPMENT'
                                                           ;

        RETURN ln_max_seq;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error @get_max_seq_num' || SQLERRM);
            RETURN NULL;
    END;


    PROCEDURE proc_update_shipped_so
    IS
        ln_count    NUMBER := 0;
        ln_count1   NUMBER := 0;
        ln_count2   NUMBER := 0;
        ln_count3   NUMBER := 0;

        CURSOR cur_sel IS
              SELECT *
                FROM xxdo.XXD_ONT_PO_MARGIN_CALC_T xop
               WHERE     1 = 1
                     AND process_flag = 'C'
                     AND xop.source <> 'TQ_PO_RECEIVING'
            ORDER BY sequence_number;
    BEGIN
        FOR rec_sel IN cur_sel
        LOOP
            ln_count1   := 0;
            ln_count2   := ln_count2 + 1;
            ln_count1   :=
                get_unprocessed_lines_count (rec_sel.inventory_item_id,
                                             rec_sel.sequence_number);

            UPDATE xxdo.XXD_ONT_PO_MARGIN_CALC_T xop
               SET (process_flag,
                    xop.unit_selling_price,
                    xop.unit_selling_price_usd)   =
                       (SELECT 'N',
                               unit_selling_price,
                               CASE
                                   WHEN xop.source_currency <>
                                        gv_usd_cur_code
                                   THEN
                                         ool.unit_selling_price
                                       * XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                             xop.mmt_creation_date,
                                             xop.source_currency,
                                             gv_usd_cur_code)
                                   ELSE
                                       ool.unit_selling_price
                               END unit_selling_price_usd
                          FROM oe_order_lines_all ool
                         WHERE 1 = 1 AND xop.line_id = ool.line_id)
             WHERE     1 = 1
                   AND xop.sequence_number = rec_sel.sequence_number
                   AND EXISTS
                           (SELECT 1
                              FROM oe_order_lines_all ool, fnd_lookup_values flv
                             WHERE     1 = 1
                                   AND xop.line_id = ool.line_id
                                   AND ool.shipped_quantity IS NOT NULL
                                   AND oe_line_status_pub.get_line_status (
                                           ool.line_id,
                                           ool.flow_status_code) =
                                       flv.meaning
                                   AND flv.lookup_type =
                                       'XXD_IC_OE_FLOW_STATUS_CODE_LKP'
                                   AND flv.description = 'FLOW_STATUS_CODE'
                                   AND flv.enabled_flag = 'Y'
                                   AND flv.language = USERENV ('LANG')
                                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                   NVL (
                                                                       flv.start_date_active,
                                                                       SYSDATE))
                                                           AND TRUNC (
                                                                   NVL (
                                                                       flv.end_date_active,
                                                                       SYSDATE)))
                   AND 0 = ln_count1
                   AND EXISTS
                           (SELECT 1
                              FROM mtl_material_transactions mmt
                             WHERE     1 = 1
                                   AND mmt.transaction_id =
                                       xop.mmt_transaction_id
                                   AND mmt.costed_flag IS NULL);


            ln_count    := SQL%ROWCOUNT;
            ln_count3   := ln_count3 + ln_count;
        END LOOP;

        LOG (gv_debug,
             'Total Number of rows chosen for update - ' || ln_count2);
        LOG (gv_debug, 'Total Number of rows updated - ' || ln_count3);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gv_debug, 'Error @proc_update_shipped_so' || SQLERRM);
    END;


    PROCEDURE proc_update_ir_trx (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    IS
        ln_count   NUMBER := 0;

        CURSOR cur_sel IS
              SELECT xopi.*, NVL (xop.TRX_MRGN_CST_USD, 0) xop_TRX_MRGN_CST_USD, NVL (xop.TRX_MRGN_CST_LOCAL, 0) xop_TRX_MRGN_CST_local,
                     NVL (xop.AVG_MRGN_CST_USD, 0) xop_avg_MRGN_CST_USD, NVL (xop.AVG_MRGN_CST_LOCAL, 0) xop_avg_MRGN_CST_local
                FROM xxdo.XXD_ONT_PO_IR_MARGIN_CALC_T xopi, xxdo.XXD_ONT_PO_MARGIN_CALC_T xop
               WHERE     1 = 1
                     AND xopi.process_flag = 'C'
                     AND xopi.requisition_line_id = xop.requisition_line_id(+)
                     AND xopi.inventory_item_id = xop.inventory_item_id(+)
                     AND xop.process_flag(+) = 'P'
                     AND NVL (xop.sequence_number, 0) =
                         NVL (
                             XXD_ONT_CAL_MARGIN_PKG.get_so_max_seq_num (
                                 xop.requisition_line_id,
                                 'ISO_SHIPMENT',
                                 xop.inventory_item_id),
                             0)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxd_ont_po_margin_calc_t xopp
                               WHERE     1 = 1
                                     AND xopp.requisition_line_id =
                                         xopi.requisition_line_id
                                     AND xopp.process_flag = 'C')
            ORDER BY xopi.sequence_number;
    BEGIN
        FOR rec_sel IN cur_sel
        LOOP
            ln_count   := ln_count + 1;

            UPDATE XXD_ONT_PO_IR_MARGIN_CALC_T xopi
               SET PROCESS_FLAG = 'N1', TRX_MRGN_CST_USD = rec_sel.xop_TRX_MRGN_CST_USD, TRX_MRGN_CST_LOCAL = rec_sel.xop_TRX_MRGN_CST_local,
                   AVG_MRGN_CST_USD = rec_sel.xop_avg_MRGN_CST_USD, AVG_MRGN_CST_LOCAL = rec_sel.xop_avg_MRGN_CST_local
             WHERE 1 = 1 AND xopi.sequence_number = rec_sel.sequence_number;
        END LOOP;

        LOG ('Y', 'Total Number of records updated - ' || ln_count);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                'Y',
                   'Error while reprocessing the IRs @ '
                || TO_CHAR (SYSDATE, 'DD/MM/YYYY HH24:mi:ss')
                || ' - '
                || SQLERRM);
            errbuf   := 2;
            retcode   :=
                   'Error while reprocessing the IRs @ '
                || TO_CHAR (SYSDATE, 'DD/MM/YYYY HH24:mi:ss')
                || ' - '
                || SQLERRM;
    END;

    --end changes v1.1


    PROCEDURE proc_update_src_trx (pd_create_from_date VARCHAR2, x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2)
    IS
        ln_prior_avg_cost           NUMBER := 0;
        ln_prior_avg_cost_dstn      NUMBER := 0;
        ln_source_cost              NUMBER := 0;
        ln_source_cost_usd          NUMBER := 0;
        ln_trx_mrgn_cost_local      NUMBER := 0;
        ln_trx_mrgn_cost_usd        NUMBER := 0;
        ln_relation_ship_cost       NUMBER := 0;

        lv_onhand_source            VARCHAR2 (50);
        ln_onhand_organization_id   NUMBER;
        ln_onhand_item_id           NUMBER;
        ln_onhand_source_line_id    NUMBER;
        ln_onhand_qty_destn         NUMBER := NULL;
        lv_onhand_eligible          VARCHAR2 (5);
        xn_trx_margin_local         NUMBER;
        xn_trx_margin_USD           NUMBER;


        CURSOR cur_src_tbl_N IS
              SELECT *
                FROM XXD_ONT_PO_MARGIN_CALC_T
               WHERE 1 = 1 AND process_flag = 'N'
            --             AND creation_date <=
            --                          TO_DATE (
            --                             TO_CHAR (SYSDATE - (1 / 24),
            --                                      'DD-MON-RRRR HH24:MI:SS'),
            --                             'DD-MON-RRRR HH24:MI:SS')
            ORDER BY sequence_number;
    BEGIN
        --start changes v1.1
        proc_update_shipped_so;

        --end changes v1.1
        FOR rec_cur_src_tbl_n IN cur_src_tbl_n
        LOOP
            --Initialization
            ln_prior_avg_cost           := 0;
            ln_prior_avg_cost_dstn      := 0;
            ln_source_cost              := 0;
            ln_source_cost_usd          := 0;
            ln_trx_mrgn_cost_local      := 0;
            ln_trx_mrgn_cost_usd        := 0;
            ln_relation_ship_cost       := 0;
            lv_onhand_source            := NULL;
            ln_onhand_organization_id   := NULL;
            ln_onhand_item_id           := NULL;
            ln_onhand_source_line_id    := NULL;
            ln_onhand_qty_destn         := NULL;
            lv_onhand_eligible          := NULL;
            xn_trx_margin_local         := NULL;
            xn_trx_margin_usd           := NULL;

            --         LOG (gv_debug, 'Entered into the Update loop 1');

            IF rec_cur_src_tbl_n.source <> 'TQ_PO_RECEIVING'
            THEN
                IF NVL (rec_cur_src_tbl_n.trx_relationship, gv_different_ou) =
                   gv_same_ou
                THEN
                    ln_source_cost       :=
                        get_avg_prior_cst (
                            rec_cur_src_tbl_n.source_organization_id,
                            rec_cur_src_tbl_n.inventory_item_id,
                            rec_cur_src_tbl_n.sequence_number,
                            rec_cur_src_tbl_n.transaction_date);
                    ln_source_cost_usd   := ln_source_cost;
                ELSE
                    --Start Changes V1.1
                    --ln_source_cost := rec_cur_src_tbl_n.source_cost;
                    ln_source_cost   :=
                        XXD_MTL_ONT_GET_TRX_COST_F (
                            rec_cur_src_tbl_n.trx_relationship,
                            rec_cur_src_tbl_n.mmt_transaction_id,
                            rec_cur_src_tbl_n.inventory_item_id,
                            rec_cur_src_tbl_n.cst_org,
                            rec_cur_src_tbl_n.mmt_creation_date,
                            rec_cur_src_tbl_n.source_organization_id --Added For CCR0008574
                                                                    );
                    --                  get_macau_to_x_Trans_mrgn (
                    --                     'ITEMCOST',
                    --                     rec_cur_src_tbl_n.cst_org,
                    --                     rec_cur_src_tbl_n.inventory_item_id,
                    --                     'Y');
                    --End Changes V1.1
                    ln_source_cost_usd   :=
                          ln_source_cost
                        * CASE
                              WHEN get_inv_org_currency (
                                       rec_cur_src_tbl_n.cst_org) <>
                                   gv_usd_cur_code
                              THEN
                                  XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                      rec_cur_src_tbl_n.transaction_date,
                                      get_inv_org_currency (
                                          rec_cur_src_tbl_n.cst_org),
                                      gv_usd_cur_code)
                              ELSE
                                  1
                          END;
                END IF;
            --Start Changes V1.1

            --End Changes V1.1

            ELSE
                proc_copy_trx_margin (rec_cur_src_tbl_n.tq_so_line_id,
                                      rec_cur_src_tbl_n.inventory_item_id,
                                      rec_cur_src_tbl_n.destination_currency,
                                      xn_trx_margin_local,
                                      xn_trx_margin_usd);
            END IF;

            --         LOG (gv_debug, 'Entered into the Update loop 2');
            ln_trx_mrgn_cost_usd        :=
                CASE
                    WHEN NVL (rec_cur_src_tbl_n.trx_relationship,
                              gv_different_ou) =
                         gv_same_ou
                    THEN
                        ln_source_cost_usd
                    ELSE
                        GREATEST (
                            ROUND (
                                  rec_cur_src_tbl_n.unit_selling_price_usd
                                - ln_source_cost_usd
                                - (rec_cur_src_tbl_n.over_head_cost + (rec_cur_src_tbl_n.over_head_cost_pcnt * ln_source_cost_usd / 100)),
                                gn_round_fact),
                            0)
                END;
            ln_trx_mrgn_cost_local      :=
                GREATEST (
                    ROUND (
                          ln_trx_mrgn_cost_usd
                        * CASE
                              WHEN --                             get_inv_org_currency (
                                   --                                     rec_cur_src_tbl_n.destination_organization_id) <>
                                   NVL (
                                       rec_cur_src_tbl_n.destination_currency,
                                       rec_cur_src_tbl_n.source_currency) <>
                                   gv_usd_cur_code
                              THEN
                                  XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                      rec_cur_src_tbl_n.transaction_date,
                                      gv_usd_cur_code,
                                      NVL (
                                          rec_cur_src_tbl_n.destination_currency,
                                          rec_cur_src_tbl_n.source_currency))
                              ELSE
                                  1
                          END,
                        CASE
                            WHEN NVL (rec_cur_src_tbl_n.destination_currency,
                                      rec_cur_src_tbl_n.source_currency) =
                                 gv_jpy_cur_code
                            THEN
                                0
                            ELSE
                                gn_round_fact
                        END),
                    0);

            IF rec_cur_src_tbl_n.source = 'TQ_PO_RECEIVING'
            THEN
                lv_onhand_source   := 'RCV';
                ln_onhand_organization_id   :=
                    rec_cur_src_tbl_n.destination_organization_id;
                ln_onhand_item_id   :=
                    rec_cur_src_tbl_n.inventory_item_id;
                ln_onhand_source_line_id   :=
                    rec_cur_src_tbl_n.rcv_transaction_id;
            ELSE
                lv_onhand_source            := 'ORDER ENTRY';
                ln_onhand_organization_id   :=
                    rec_cur_src_tbl_n.source_organization_id;
                ln_onhand_item_id           :=
                    rec_cur_src_tbl_n.inventory_item_id;
                ln_onhand_source_line_id    := rec_cur_src_tbl_n.line_id;
            END IF;

            ln_onhand_qty_destn         :=
                get_costed_onhand_qty (lv_onhand_source,
                                       rec_cur_src_tbl_n.source,
                                       ln_onhand_organization_id,
                                       ln_onhand_item_id,
                                       ln_onhand_source_line_id,
                                       rec_cur_src_tbl_n.mmt_transaction_id);
            lv_onhand_eligible          :=
                get_onhand_eligible (rec_cur_src_tbl_n.inventory_item_id,
                                     rec_cur_src_tbl_n.sequence_number);

            ln_prior_avg_cost_dstn      :=
                get_avg_prior_cst (rec_cur_src_tbl_n.destination_organization_id, rec_cur_src_tbl_n.inventory_item_id, rec_cur_src_tbl_n.sequence_number
                                   , rec_cur_src_tbl_n.transaction_date);


            BEGIN
                --            LOG (gv_debug, 'Entered into the Update loop 3');


                UPDATE xxdo.XXD_ONT_PO_MARGIN_CALC_T
                   SET SOURCE_COST_USD    =
                           CASE
                               WHEN (rec_cur_src_tbl_n.trx_relationship = gv_same_ou OR rec_cur_src_tbl_n.source = 'TQ_PO_RECEIVING')
                               THEN
                                   NULL
                               ELSE
                                   ln_SOURCE_COST_usd
                           END,
                       source_cost        =
                           CASE
                               WHEN (rec_cur_src_tbl_n.trx_relationship = gv_same_ou OR rec_cur_src_tbl_n.source = 'TQ_PO_RECEIVING')
                               THEN
                                   NULL
                               ELSE
                                   ln_SOURCE_COST
                           END,
                       trx_mrgn_cst_usd   =
                           CASE
                               WHEN rec_cur_src_tbl_n.source =
                                    'TQ_PO_RECEIVING'
                               THEN
                                   xn_trx_margin_usd
                               ELSE
                                   ln_trx_mrgn_cost_usd
                           END,
                       trx_mrgn_cst_local   =
                           CASE
                               WHEN rec_cur_src_tbl_n.source =
                                    'TQ_PO_RECEIVING'
                               THEN
                                   xn_trx_margin_local
                               ELSE
                                   ln_trx_mrgn_cost_local
                           END,
                       ON_HAND_QTY_DESTN   = ln_onhand_qty_destn,
                       AVG_MRGN_CST_USD   =
                           ROUND (
                                 (  (  rec_cur_src_tbl_n.TRANSACTION_QUANTITY
                                     * CASE
                                           WHEN rec_cur_src_tbl_n.source =
                                                'TQ_PO_RECEIVING'
                                           THEN
                                               xn_trx_margin_usd
                                           ELSE
                                               ln_trx_mrgn_cost_usd
                                       END)
                                  + (ln_onhand_qty_destn * ln_prior_avg_cost_dstn))
                               / (rec_cur_src_tbl_n.TRANSACTION_QUANTITY + ln_onhand_qty_destn),
                               gn_round_fact),
                       AVG_MRGN_CST_LOCAL   =
                           ROUND (
                                 (  (  (  rec_cur_src_tbl_n.TRANSACTION_QUANTITY
                                        * CASE
                                              WHEN rec_cur_src_tbl_n.source =
                                                   'TQ_PO_RECEIVING'
                                              THEN
                                                  xn_trx_margin_usd
                                              ELSE
                                                  ln_trx_mrgn_cost_usd
                                          END)
                                     + (ln_onhand_qty_destn * ln_prior_avg_cost_dstn))
                                  / (rec_cur_src_tbl_n.TRANSACTION_QUANTITY + ln_onhand_qty_destn))
                               * CASE
                                     WHEN --                           get_inv_org_currency (
                                          --                                   rec_cur_src_tbl_n1.destination_organization_id) <>
                                          rec_cur_src_tbl_n.destination_currency <>
                                          gv_usd_cur_code
                                     THEN
                                         XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                             rec_cur_src_tbl_n.transaction_date,
                                             gv_usd_cur_code,
                                             rec_cur_src_tbl_n.destination_currency)
                                     ELSE
                                         1
                                 END,
                               CASE
                                   WHEN NVL (
                                            rec_cur_src_tbl_n.destination_currency,
                                            rec_cur_src_tbl_n.source_currency) =
                                        gv_jpy_cur_code
                                   THEN
                                       0
                                   ELSE
                                       gn_round_fact
                               END),
                       last_updated_date   = SYSDATE,
                       last_updated_by     = gn_user_id,
                       update_request_id   = gn_conc_request_id,
                       process_flag        = 'P'
                 WHERE     1 = 1
                       AND sequence_number =
                           rec_cur_src_tbl_n.sequence_number
                       AND NVL (ln_onhand_qty_destn, -999999999999999) =
                           CASE
                               WHEN source <> 'TQ_SO_SHIPMENT'
                               THEN
                                   ln_onhand_qty_destn
                               ELSE
                                   -999999999999999
                           END
                       AND 'YES' =
                           CASE
                               WHEN source <> 'TQ_SO_SHIPMENT'
                               THEN
                                   lv_onhand_eligible
                               ELSE
                                   'YES'
                           END;
            EXCEPTION
                WHEN OTHERS
                THEN
                    LOG (
                        gv_debug,
                        'Error While Updating the TRX Margin Cost' || SQLERRM);
                    x_retcode   := 2;
                    x_errbuf    :=
                        'Error While Updating the TRX Margin Cost' || SQLERRM;
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (gv_debug,
                 'Others Exception @proc_update_src_trx ' || SQLERRM);
            x_retcode   := 2;
            x_errbuf    := SQLERRM;
    END;

    PROCEDURE proc_load_trx (pd_create_from_date VARCHAR2, x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2)
    IS
        l_index          NUMBER := 0;
        dml_errors       EXCEPTION;
        PRAGMA EXCEPTION_INIT (dml_errors, -24381);
        lv_err_msg       VARCHAR2 (1000);

        CURSOR cur_insrt_stg IS
              SELECT *
                FROM (                                             --Shipments
                      SELECT gn_conc_request_id
                                 request_id,
                             'ISO_SHIPMENT'
                                 "SOURCE",
                             ooh.order_number
                                 order_number,
                             NULL
                                 rcv_transaction_id,
                             ooh.header_id,
                             ool.line_id,
                             ool.ordered_quantity,
                             ABS (mmt.primary_quantity) --ool.shipped_QUANTITY
                                 transaction_quantity,
                             ool.invoiced_quantity,
                             ool.inventory_item_id,
                             NULL
                                 delivery_detail_id,
                             --start changes v1.1
                             --wnd.delivery_id,
                             NULL
                                 DELIVERY_ID,
                             --End changes v1.1
                             mmt.transaction_date
                                 transaction_date,
                             ool.unit_selling_price,
                             CASE
                                 WHEN ooh.TRANSACTIONAL_CURR_CODE <>
                                      gv_usd_cur_code
                                 THEN
                                       ool.unit_selling_price
                                     * XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                           --start changes v1.1
                                           --wnd.confirm_date,
                                           mmt.creation_date,
                                           --End changes v1.1
                                           ooh.TRANSACTIONAL_CURR_CODE,
                                           gv_usd_cur_code)
                                 ELSE
                                     ool.unit_selling_price
                             END
                                 unit_selling_price_usd,
                             prla.source_organization_id,
                             prla.destination_organization_id,
                             prla.requisition_line_id,
                             NULL
                                 po_line_id,
                             NULL
                                 tq_so_line_id,
                             ooh.TRANSACTIONAL_CURR_CODE
                                 source_currency,
                             XXD_ONT_CAL_MARGIN_PKG.get_inv_org_currency (
                                 prla.destination_organization_id)
                                 destination_currency,
                             XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                 --start changes v1.1
                                 --wnd.confirm_date,
                                 mmt.creation_date,
                                 --End changes v1.1
                                 gv_usd_cur_code, --ooh.TRANSACTIONAL_CURR_CODE,
                                 XXD_ONT_CAL_MARGIN_PKG.get_inv_org_currency (
                                     prla.destination_organization_id))
                                 conversion_rate_local,
                             CASE
                                 WHEN ooh.TRANSACTIONAL_CURR_CODE <>
                                      gv_usd_cur_code
                                 THEN
                                     XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                         --start changes v1.1
                                         --wnd.confirm_date,
                                         mmt.creation_date,
                                         --End changes v1.1
                                         ooh.TRANSACTIONAL_CURR_CODE,
                                         gv_usd_cur_code)
                                 ELSE
                                     1
                             END
                                 conversion_rate_usd,
                             --start changes v1.1
                             --'N' PROCESS_FLAG,
                             'C'
                                 PROCESS_FLAG,
                             --end changes v1.1
                             SYSDATE
                                 creation_date,
                             gn_user_id
                                 created_by,
                             SYSDATE
                                 LAST_UPDATED_DATE,
                             gn_user_id
                                 LAST_UPDATED_BY,
                             gn_login_id
                                 last_login,
                             --                XXD_ONT_CAL_MARGIN_PKG.get_costing_org (
                             --                   prla.source_organization_id,
                             --                   prla.destination_organization_id)
                             TO_NUMBER (msnv.attribute3)
                                 cst_org,
                             NVL (TO_NUMBER (msnv.attribute4), 0)
                                 OVER_HEAD_COST,
                             NVL (TO_NUMBER (msnv.attribute5), 0)
                                 OVER_HEAD_COST_PCNT,
                             XXD_ONT_CAL_MARGIN_PKG.get_operating_unit (
                                 prla.source_organization_id)
                                 source_Operating_unit,
                             XXD_ONT_CAL_MARGIN_PKG.get_operating_unit (
                                 prla.destination_organization_id)
                                 Dstn_oeprating_unit,
                             --Start Changes V1.1
                             NULL             --                          CASE
                                 --                             WHEN XXD_ONT_CAL_MARGIN_PKG.get_operating_unit (
                                 --                                     prla.source_organization_id) =
                                 --                                     XXD_ONT_CAL_MARGIN_PKG.get_operating_unit (
                                 --                                        prla.destination_organization_id)
                                 --                             THEN
                                 --                                NULL
                                 --                             ELSE
                                 --                                --                                get_macau_to_x_Trans_mrgn (
                                 --                                --                                   'ITEMCOST',
                                 --                                --                                   TO_NUMBER (msnv.attribute3),
                                 --                                --                                   ool.inventory_item_id,
                                 --                                --                                   'Y')
                                 --                                XXD_MTL_ONT_GET_TRX_COST_F (
                                 --                                   mmt.inventory_item_id,
                                 --                                   NVL (TO_NUMBER (msnv.attribute3), -999),
                                 --                                   mmt.creation_date)
                                 --                          --End Changes V1.1
                                 --                          END
                                 SOURCE_COST,
                             CASE
                                 WHEN prla.source_organization_id =
                                      gn_mc1_org_id
                                 THEN
                                     gv_mc1_to_any              --'MC1 TO ANY'
                                 WHEN XXD_ONT_CAL_MARGIN_PKG.get_operating_unit (
                                          prla.source_organization_id) =
                                      XXD_ONT_CAL_MARGIN_PKG.get_operating_unit (
                                          prla.destination_organization_id)
                                 THEN
                                     gv_same_ou                    --'SAME OU'
                                 ELSE
                                     gv_different_ou          --'DIFFERENT OU'
                             END
                                 TRX_RELATIONSHIP,
                             NULL
                                 on_hand_quantity,
                             NULL
                                 TRX_MRGN_CST_USD,
                             NULL
                                 TRX_MRGN_CST_LOCAL,
                             mmt.transaction_id
                                 mmt_transaction_id,
                             mmt.creation_date
                                 mmt_creation_date
                        FROM oe_order_headers_all ooh, oe_order_lines_all ool, --start changes v1.1
                                                                               --apps.wsh_new_deliveries wnd,
                                                                               --apps.wsh_delivery_assignments wda,
                                                                               --end changes v1.1
                                                                               apps.po_requisition_lines_all prla,
                             mtl_interorg_parameters msnv, mtl_material_transactions mmt
                       WHERE     ooh.header_Id = ool.header_id
                             AND ooh.order_source_id = gn_order_src_id
                             --         and ooh.transaction_number = 59028100
                             AND ool.source_document_line_id =
                                 prla.requisition_line_id
                             AND ooh.order_source_id = ool.order_source_id
                             AND ooh.source_document_id =
                                 ool.source_document_id
                             --                AND wnd.confirm_date >= gd_cut_off_date
                             AND mmt.creation_date BETWEEN gd_from_cut_off_date
                                                       AND gd_to_cut_off_date
                             AND UPPER (msnv.attribute2) IN ('YES', 'Y') --Inter Co.s eligible for profit elimination
                             AND msnv.from_organization_id =
                                 prla.source_organization_id
                             AND msnv.to_organization_id =
                                 prla.destination_organization_id
                             AND prla.source_organization_id =
                                 ool.ship_from_org_id
                             AND prla.item_id = ool.inventory_item_id
                             AND mmt.organization_id = ool.ship_from_org_id
                             AND mmt.inventory_item_id = ool.inventory_item_id
                             AND mmt.source_line_id = ool.line_id
                             AND mmt.SOURCE_CODE = 'ORDER ENTRY'
                             AND mmt.transaction_type_id = 62 -- Int Order Intr Ship
                             AND NOT EXISTS
                                     (SELECT 1
                                        FROM XXD_ONT_PO_MARGIN_CALC_T stg
                                       WHERE     1 = 1
                                             AND stg.mmt_transaction_id =
                                                 mmt.transaction_id)
                      UNION ALL
                      SELECT gn_conc_request_id
                                 request_id,
                             'TQ_SO_SHIPMENT'
                                 "SOURCE",
                             ooh.order_number
                                 order_number,
                             NULL
                                 rcv_transaction_id,
                             ooh.header_id,
                             ool.line_id,
                             ool.ordered_quantity,
                             ABS (mmt.primary_quantity) --ool.shipped_quantity
                                 transaction_quantity,
                             ool.invoiced_quantity,
                             ool.inventory_item_id,
                             NULL
                                 delivery_detail_id,
                             NULL
                                 delivery_id,
                             --                ool.actual_shipment_date transaction_date,
                             mmt.transaction_date
                                 transaction_date,
                             ool.unit_selling_price,
                             CASE
                                 WHEN ooh.TRANSACTIONAL_CURR_CODE <>
                                      gv_usd_cur_code
                                 THEN
                                       ool.unit_selling_price
                                     * XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                           ool.actual_shipment_date,
                                           ooh.TRANSACTIONAL_CURR_CODE,
                                           gv_usd_cur_code)
                                 ELSE
                                     ool.unit_selling_price
                             END
                                 unit_selling_price_usd,
                             ool.ship_from_org_id
                                 source_organization_id,
                             NULL
                                 destination_organization_id,
                             NULL
                                 requisition_line_id,
                             NULL
                                 po_line_id,
                             NULL
                                 tq_so_line_id,
                             ooh.transactional_curr_code
                                 source_currency,
                             NULL
                                 destination_currency,
                             NULL
                                 conversion_rate_local,
                             CASE
                                 WHEN ooh.TRANSACTIONAL_CURR_CODE <>
                                      gv_usd_cur_code
                                 THEN
                                     XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                         TRUNC (ool.actual_shipment_date),
                                         ooh.TRANSACTIONAL_CURR_CODE,
                                         gv_usd_cur_code)
                                 ELSE
                                     1
                             END
                                 conversion_rate_usd,
                             'C'
                                 PROCESS_FLAG,
                             SYSDATE
                                 creation_date,
                             gn_user_id
                                 created_by,
                             SYSDATE
                                 LAST_UPDATED_DATE,
                             gn_user_id
                                 LAST_UPDATED_BY,
                             gn_login_id
                                 last_login,
                             TO_NUMBER (ffv.attribute3)
                                 cst_org,
                             NVL (TO_NUMBER (ffv.attribute4), 0)
                                 OVER_HEAD_COST,
                             NVL (TO_NUMBER (ffv.attribute5), 0)
                                 OVER_HEAD_COST_PCNT,
                             ool.org_id
                                 source_Operating_unit,
                             NULL
                                 Dstn_oeprating_unit,
                             --start changes V1.1
                             NULL --                          get_macau_to_x_Trans_mrgn (
                                    --                             'ITEMCOST',
                    --                             TO_NUMBER (ffv.attribute3),
                         --                             ool.inventory_item_id,
                                           --                             'Y')
                      --                          XXD_MTL_ONT_GET_TRX_COST_F (
                         --                             mmt.inventory_item_id,
        --                             NVL (TO_NUMBER (ffv.attribute3), -999),
                             --                             mmt.creation_date)
                             --                             --End changes V1.1
                                 SOURCE_COST,
                             CASE
                                 WHEN ool.ship_from_org_id = gn_mc1_org_id
                                 THEN
                                     gv_mc1_to_any --                   WHEN ool.org_id = pol.org_id
                                 --                   THEN
                                 --                      gv_same_ou
                                 ELSE
                                     gv_different_ou
                             END
                                 TRX_RELATIONSHIP,
                             NULL
                                 on_hand_quantity,
                             NULL
                                 TRX_MRGN_CST_USD,
                             NULL
                                 TRX_MRGN_CST_LOCAL,
                             mmt.transaction_id
                                 mmt_transaction_id,
                             mmt.creation_date
                                 mmt_creation_date
                        FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool, fnd_flex_value_sets ffvs,
                             fnd_flex_values ffv, hz_cust_accounts_all hca, hz_parties hp,
                             mtl_material_transactions mmt
                       WHERE     ooh.header_Id = ool.header_id
                             AND ooh.order_source_id = ool.order_source_id
                             --                AND ool.actual_shipment_date BETWEEN gd_from_cut_off_date
                             --                                                 AND gd_to_cut_off_date
                             AND mmt.creation_date BETWEEN gd_from_cut_off_date
                                                       AND gd_to_cut_off_date
                             AND ffvs.FLEX_VALUE_SET_NAME =
                                 'XXD_IC_SALES_ORDER_OU_VS'
                             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                             AND ffv.enabled_flag = 'Y'
                             AND SYSDATE BETWEEN NVL (ffv.start_date_active,
                                                      '01-JAN-2017')
                                             AND NVL (ffv.end_date_active,
                                                      SYSDATE + 1)
                             AND TO_NUMBER (ffv.attribute2) = hp.party_id
                             AND ool.org_id = TO_NUMBER (ffv.attribute1)
                             AND hp.party_id = hca.party_id
                             AND hca.cust_account_id = ool.sold_to_org_id
                             --start changes v1.1
                             /*AND ool.shipped_quantity IS NOT NULL
                             AND oe_line_status_pub.get_line_status (
                                    ool.line_id,
                                    ool.flow_status_code) = flv.meaning
                             AND flv.lookup_type =
                                    'XXD_IC_OE_FLOW_STATUS_CODE_LKP'
                             AND flv.description = 'FLOW_STATUS_CODE'
                             AND flv.enabled_flag = 'Y'
                             AND flv.language = USERENV ('LANG')
                             AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                            NVL (
                                                               flv.start_date_active,
                                                               SYSDATE))
                                                     AND TRUNC (
                                                            NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))*/
                             --end changes v1.1
                             AND mmt.organization_id = ool.ship_from_org_id
                             AND mmt.inventory_item_id = ool.inventory_item_id
                             AND mmt.source_line_id = ool.line_id
                             AND mmt.SOURCE_CODE = 'ORDER ENTRY'
                             AND NOT EXISTS
                                     (SELECT 1
                                        FROM XXD_ONT_PO_MARGIN_CALC_T stg
                                       WHERE     1 = 1
                                             AND stg.line_id = ool.line_id
                                             AND mmt.transaction_id =
                                                 stg.mmt_transaction_id
                                             AND source <> 'TQ_PO_RECEIVING')
                      UNION ALL
                      SELECT gn_conc_request_id request_id,
                             'TQ_PO_RECEIVING' "SOURCE",
                             NULL order_number,
                             rct.transaction_id RCV_TRANSACTION_ID,
                             rct.shipment_header_id,
                             rct.shipment_line_id,
                             NULL ordered_quantity,
                             ABS (mmt.primary_quantity)         --rct.quantity
                                                       transaction_quantity,
                             NULL invoiced_quantity,
                             pol.item_id inventory_item_id,
                             NULL delivery_detail_id,
                             NULL delivery_id,
                             --                rct.transaction_date transaction_date,
                             mmt.transaction_date transaction_date,
                             NULL unit_selling_price,
                             NULL unit_selling_price_usd,
                             xop.source_organization_id,
                             rct.organization_id,
                             rct.requisition_line_id,
                             pol.po_line_id,
                             TO_NUMBER (pol.attribute5) tq_so_line_id,
                             xop.source_currency source_currency,
                             rct.currency_code destination_currency,
                             XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                 rct.transaction_date,
                                 gv_usd_cur_code,       --xop.source_currency,
                                 rct.currency_code) conversion_rate_local,
                             CASE
                                 WHEN rct.currency_code <> gv_usd_cur_code
                                 THEN
                                     XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                         rct.transaction_date,
                                         rct.currency_code,
                                         gv_usd_cur_code)
                                 ELSE
                                     1
                             END conversion_rate_usd,
                             'N' PROCESS_FLAG,
                             SYSDATE creation_date,
                             gn_user_id created_by,
                             SYSDATE LAST_UPDATED_DATE,
                             gn_user_id LAST_UPDATED_BY,
                             gn_login_id last_login,
                             NULL cst_org,
                             NULL OVER_HEAD_COST,
                             NULL OVER_HEAD_COST_PCNT,
                             xop.source_Operating_unit,
                             pol.org_id dstn_oeprating_unit,
                             NULL SOURCE_COST,
                             xop.TRX_RELATIONSHIP,
                             NULL --XXD_ONT_CAL_MARGIN_PKG.get_onhand_qty (rct.organization_id,
                              --                                  pol.item_id)
                                 on_hand_quantity,
                             NULL,           -- NVL (xop.TRX_MRGN_CST_USD, 0),
                             NULL,          -- NVL(xop.TRX_MRGN_CST_LOCAL, 0),
                             mmt.transaction_id mmt_transaction_id,
                             mmt.creation_date mmt_creation_date
                        FROM rcv_transactions rct, XXD_ONT_PO_MARGIN_CALC_T xop, apps.oe_order_lines_all ool,
                             apps.po_lines_all pol, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                             mtl_material_transactions mmt
                       WHERE     1 = 1
                             AND TO_NUMBER (pol.attribute5) = ool.line_id
                             AND rct.po_line_id = pol.po_line_id
                             --                and ool.line_id = 30572793
                             AND xop.line_id(+) = ool.line_id
                             AND NVL (xop.sequence_number(+), 0) =
                                 NVL (
                                     XXD_ONT_CAL_MARGIN_PKG.get_max_seq_num (
                                         xop.line_id(+),
                                         'TQ_SO_SHIPMENT',
                                         xop.inventory_item_id(+)),
                                     0)
                             AND rct.transaction_type = 'DELIVER'
                             AND ffvs.FLEX_VALUE_SET_NAME =
                                 'XXD_IC_PURCHASE_ORDER_OU_VS'
                             AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                             AND ffv.enabled_flag = 'Y'
                             AND SYSDATE BETWEEN NVL (ffv.start_date_active,
                                                      '01-JAN-2000')
                                             AND NVL (ffv.end_date_active,
                                                      SYSDATE + 1)
                             AND TO_NUMBER (ffv.attribute1) = pol.org_id
                             --                AND rct.last_update_date BETWEEN gd_from_cut_off_date
                             --                                             AND gd_to_cut_off_date
                             AND mmt.creation_date BETWEEN gd_from_cut_off_date
                                                       AND gd_to_cut_off_date
                             AND mmt.organization_id = rct.organization_id
                             AND mmt.inventory_item_id = ool.inventory_item_id
                             AND mmt.rcv_transaction_id = rct.transaction_id
                             AND mmt.SOURCE_CODE = 'RCV'
                             AND NOT EXISTS
                                     (SELECT 1
                                        FROM XXD_ONT_PO_MARGIN_CALC_T stg
                                       WHERE     1 = 1
                                             --                                         AND NVL (stg.rcv_transaction_id, -111) =
                                             --                                                rct.transaction_id
                                             AND stg.mmt_transaction_id =
                                                 mmt.transaction_id))
            ORDER BY mmt_transaction_id, mmt_creation_date, inventory_item_id;



        TYPE t_load_tbl_typ IS TABLE OF cur_insrt_stg%ROWTYPE;

        t_load_tbl_tab   t_load_tbl_typ;
    BEGIN
        OPEN cur_insrt_stg;

        LOOP
            FETCH cur_insrt_stg BULK COLLECT INTO t_load_tbl_tab LIMIT 500;


            BEGIN
                FORALL l_index IN 1 .. t_load_tbl_tab.COUNT SAVE EXCEPTIONS
                    INSERT INTO XXD_ONT_PO_MARGIN_CALC_T (
                                    SEQUENCE_NUMBER,
                                    REQUEST_ID,
                                    SOURCE,
                                    ORDER_NUMBER,
                                    rcv_transaction_id,
                                    HEADER_ID,
                                    LINE_ID,
                                    ORDERED_QUANTITY,
                                    TRANSACTION_QUANTITY,
                                    INVOICED_QUANTITY,
                                    INVENTORY_ITEM_ID,
                                    DELIVERY_DETAIL_ID,
                                    DELIVERY_ID,
                                    TRANSACTION_DATE,
                                    UNIT_SELLING_PRICE,
                                    UNIT_SELLING_PRICE_USD,
                                    SOURCE_ORGANIZATION_ID,
                                    DESTINATION_ORGANIZATION_ID,
                                    REQUISITION_LINE_ID,
                                    PO_LINE_ID,
                                    tq_so_line_id,
                                    SOURCE_CURRENCY,
                                    DESTINATION_CURRENCY,
                                    CONVERSION_RATE_LOCAL,
                                    CONVERSION_RATE_USD,
                                    PROCESS_FLAG,
                                    CREATION_DATE,
                                    CREATED_BY,
                                    LAST_UPDATED_DATE,
                                    LAST_UPDATED_BY,
                                    LAST_LOGIN,
                                    CST_ORG,
                                    OVER_HEAD_COST,
                                    OVER_HEAD_COST_PCNT,
                                    SOURCE_OPERATING_UNIT,
                                    DSTN_OEPRATING_UNIT,
                                    SOURCE_COST,
                                    TRX_RELATIONSHIP,
                                    on_hand_quantity,
                                    TRX_MRGN_CST_USD,
                                    TRX_MRGN_CST_LOCAL,
                                    MMT_TRANSACTION_ID,
                                    MMT_CREATION_DATE)
                             VALUES (
                                        XXD_ONT_PO_MARGIN_CALC_S.NEXTVAL,
                                        t_load_tbl_tab (l_index).REQUEST_ID,
                                        t_load_tbl_tab (l_index).SOURCE,
                                        t_load_tbl_tab (l_index).order_number,
                                        t_load_tbl_tab (l_index).rcv_transaction_id,
                                        t_load_tbl_tab (l_index).HEADER_ID,
                                        t_load_tbl_tab (l_index).LINE_ID,
                                        t_load_tbl_tab (l_index).ORDERED_QUANTITY,
                                        t_load_tbl_tab (l_index).TRANSACTION_QUANTITY,
                                        t_load_tbl_tab (l_index).INVOICED_QUANTITY,
                                        t_load_tbl_tab (l_index).INVENTORY_ITEM_ID,
                                        t_load_tbl_tab (l_index).DELIVERY_DETAIL_ID,
                                        t_load_tbl_tab (l_index).DELIVERY_ID,
                                        t_load_tbl_tab (l_index).TRANSACTION_DATE,
                                        t_load_tbl_tab (l_index).UNIT_SELLING_PRICE,
                                        t_load_tbl_tab (l_index).UNIT_SELLING_PRICE_USD,
                                        t_load_tbl_tab (l_index).SOURCE_ORGANIZATION_ID,
                                        t_load_tbl_tab (l_index).DESTINATION_ORGANIZATION_ID,
                                        t_load_tbl_tab (l_index).REQUISITION_LINE_ID,
                                        t_load_tbl_tab (l_index).PO_LINE_ID,
                                        t_load_tbl_tab (l_index).TQ_SO_LINE_ID,
                                        t_load_tbl_tab (l_index).SOURCE_CURRENCY,
                                        t_load_tbl_tab (l_index).DESTINATION_CURRENCY,
                                        t_load_tbl_tab (l_index).CONVERSION_RATE_LOCAL,
                                        t_load_tbl_tab (l_index).CONVERSION_RATE_USD,
                                        t_load_tbl_tab (l_index).PROCESS_FLAG,
                                        t_load_tbl_tab (l_index).CREATION_DATE,
                                        t_load_tbl_tab (l_index).CREATED_BY,
                                        t_load_tbl_tab (l_index).LAST_UPDATED_DATE,
                                        t_load_tbl_tab (l_index).LAST_UPDATED_BY,
                                        t_load_tbl_tab (l_index).LAST_LOGIN,
                                        t_load_tbl_tab (l_index).CST_ORG,
                                        t_load_tbl_tab (l_index).OVER_HEAD_COST,
                                        t_load_tbl_tab (l_index).OVER_HEAD_COST_PCNT,
                                        t_load_tbl_tab (l_index).SOURCE_OPERATING_UNIT,
                                        t_load_tbl_tab (l_index).DSTN_OEPRATING_UNIT,
                                        t_load_tbl_tab (l_index).source_cost,
                                        t_load_tbl_tab (l_index).TRX_RELATIONSHIP,
                                        t_load_tbl_tab (l_index).on_hand_quantity,
                                        t_load_tbl_tab (l_index).TRX_MRGN_CST_USD,
                                        t_load_tbl_tab (l_index).TRX_MRGN_CST_LOCAL,
                                        t_load_tbl_tab (l_index).MMT_TRANSACTION_ID,
                                        t_load_tbl_tab (l_index).MMT_CREATION_DATE);
            EXCEPTION
                WHEN dml_errors
                THEN
                    FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        lv_err_msg   :=
                               'Error while Inserting XXD_ONT_PO_MARGIN_CALC_T Table : '
                            || SQLCODE
                            || ' ---> '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while updating XXD_ONT_PO_MARGIN_CALC_T Table : '
                            || t_load_tbl_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).delivery_detail_id
                            || ' -- '
                            || t_load_tbl_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).ORDER_number
                            || ' -- '
                            || SQLERRM
                            || '-----> '
                            || SQLCODE);
                        x_errbuf    := 2;
                        x_retcode   := lv_err_msg;
                        LOG (gv_debug, 'Exception1' || SQLERRM);
                    --                  lv_status := 3;
                    --                  lv_message := lv_err_msg;
                    END LOOP;
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                           'Error Others while inserting into XXD_ONT_PO_MARGIN_CALC_T table'
                        || SQLERRM;

                    FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        lv_err_msg   :=
                               'When Others exception: Error while inserting XXD_ONT_PO_MARGIN_CALC_T Table : '
                            || SQLCODE
                            || ' ---> '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'When others exception Error while inserting XXD_ONT_PO_MARGIN_CALC_T Table : '
                            || t_load_tbl_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).delivery_detail_id
                            || ' -- '
                            || t_load_tbl_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).order_number
                            || ' -- '
                            || SQLERRM
                            || '-----> '
                            || SQLCODE);
                        LOG (gv_debug, 'Exception2');
                        --                  lv_status := 4;
                        --                  lv_message := lv_err_msg;
                        x_errbuf    := 2;
                        x_retcode   := lv_err_msg;
                    END LOOP;
            END;

            --COMMIT;

            EXIT WHEN cur_insrt_stg%NOTFOUND;
        END LOOP;

        CLOSE cur_insrt_stg;


        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                gv_debug,
                'Error @proc_load_trx while inserting into table' || SQLERRM);
            x_retcode   := 2;
            x_errbuf    :=
                'Error @proc_load_trx while inserting into table' || SQLERRM;
    END;



    PROCEDURE proc_load_ir_trx (pd_create_from_date VARCHAR2, x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2)
    IS
        l_index             NUMBER := 0;
        dml_errors          EXCEPTION;
        PRAGMA EXCEPTION_INIT (dml_errors, -24381);
        lv_err_msg          VARCHAR2 (1000);

        CURSOR cur_insrt_stg_2 IS
              --Receiving
              SELECT gn_conc_request_id request_id,
                     'IR_PO_RECEIVING' "SOURCE",
                     NULL order_number,
                     rct.transaction_id RCV_TRANSACTION_ID,
                     rct.shipment_header_id header_id,
                     rct.shipment_line_id line_id,
                     NULL ordered_quantity,
                     ABS (mmt.primary_quantity) transaction_quantity,
                     NULL invoiced_quantity,
                     mmt.inventory_item_id,
                     NULL delivery_detail_id,
                     xop.delivery_id,
                     --                  rct.transaction_date transaction_date,
                     mmt.transaction_date transaction_date,
                     NULL unit_selling_price,
                     NULL unit_selling_price_usd,
                     xop.source_organization_id,
                     rct.organization_id DESTINATION_ORGANIZATION_ID,
                     rct.requisition_line_id,
                     NULL po_line_id,
                     xop.source_currency source_currency,
                     rct.currency_code destination_currency,
                     XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                         rct.transaction_date,
                         gv_usd_cur_code,               --xop.source_currency,
                         rct.currency_code) conversion_rate_local,
                     CASE
                         WHEN rct.currency_code <> gv_usd_cur_code
                         THEN
                             XXD_ONT_CAL_MARGIN_PKG.get_corp_rate (
                                 rct.transaction_date,
                                 rct.currency_code,
                                 gv_usd_cur_code)
                         ELSE
                             1
                     END conversion_rate_usd,
                     'C' PROCESS_FLAG,
                     SYSDATE creation_date,
                     gn_user_id created_by,
                     SYSDATE LAST_UPDATED_DATE,
                     gn_user_id LAST_UPDATED_BY,
                     gn_login_id last_login,
                     NULL cst_org,
                     NULL over_head_cost,
                     NULL OVER_HEAD_COST_PCNT,
                     xop.source_Operating_unit,
                     xop.dstn_oeprating_unit,
                     xop.TRX_RELATIONSHIP,
                     XXD_ONT_CAL_MARGIN_PKG.get_onhand_qty (
                         rct.organization_id,
                         xop.inventory_item_id) on_hand_quantity,
                     NVL (xop.TRX_MRGN_CST_USD, 0) TRX_MRGN_CST_USD,
                     NVL (xop.TRX_MRGN_CST_LOCAL, 0) TRX_MRGN_CST_LOCAL,
                     NVL (xop.AVG_MRGN_CST_USD, 0) AVG_MRGN_CST_USD,
                     NVL (xop.AVG_MRGN_CST_LOCAL, 0) AVG_MRGN_CST_LOCAL,
                     mmt.transaction_id mmt_transaction_id,
                     mmt.CREATION_DATE mmt_creation_date
                FROM rcv_transactions rct, XXD_ONT_PO_MARGIN_CALC_T xop, mtl_material_transactions mmt
               WHERE     1 = 1
                     AND rct.requisition_line_id = xop.requisition_line_id(+)
                     AND rct.transaction_type = 'DELIVER'
                     AND xop.process_flag(+) = 'P'
                     AND mmt.organization_id = rct.organization_id
                     --                  AND mmt.inventory_item_id = xop.inventory_item_id(+)
                     AND mmt.rcv_transaction_id = rct.transaction_id
                     --                  AND rct.last_update_date BETWEEN gd_from_cut_off_date
                     --                                             AND gd_to_cut_off_date
                     AND mmt.creation_date BETWEEN gd_from_cut_off_date
                                               AND gd_to_cut_off_date
                     AND mmt.SOURCE_CODE = 'RCV'
                     AND NVL (xop.sequence_number(+), 0) =
                         NVL (
                             XXD_ONT_CAL_MARGIN_PKG.get_so_max_seq_num (
                                 xop.requisition_line_id(+),
                                 'ISO_SHIPMENT',
                                 xop.inventory_item_id(+)),
                             0)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM XXD_ONT_PO_IR_MARGIN_CALC_T stg
                               WHERE     1 = 1
                                     AND NVL (stg.rcv_transaction_id, 111) =
                                         NVL (rct.transaction_id, 999))
                     AND EXISTS
                             (SELECT 1
                                FROM po_requisition_lines_all prla, po_requisition_headers_all prha
                               WHERE     1 = 1
                                     AND prla.requisition_line_id =
                                         rct.requisition_line_id
                                     AND prla.requisition_header_id =
                                         prha.requisition_header_id
                                     AND prha.type_lookup_code = 'INTERNAL')
            ORDER BY mmt_transaction_id, mmt_creation_date, inventory_item_id;


        TYPE t_load_tbl_ir_typ IS TABLE OF cur_insrt_stg_2%ROWTYPE;

        t_load_tbl_ir_tab   t_load_tbl_ir_typ;
    BEGIN
        OPEN cur_insrt_stg_2;

        LOOP
            FETCH cur_insrt_stg_2
                BULK COLLECT INTO t_load_tbl_ir_tab
                LIMIT 500;

            BEGIN
                FORALL l_index IN 1 .. t_load_tbl_ir_tab.COUNT
                  SAVE EXCEPTIONS
                    INSERT INTO XXD_ONT_PO_IR_MARGIN_CALC_T (
                                    SEQUENCE_NUMBER,
                                    REQUEST_ID,
                                    SOURCE,
                                    ORDER_NUMBER,
                                    rcv_transaction_id,
                                    HEADER_ID,
                                    LINE_ID,
                                    ORDERED_QUANTITY,
                                    TRANSACTION_QUANTITY,
                                    INVOICED_QUANTITY,
                                    INVENTORY_ITEM_ID,
                                    DELIVERY_DETAIL_ID,
                                    DELIVERY_ID,
                                    TRANSACTION_DATE,
                                    UNIT_SELLING_PRICE,
                                    UNIT_SELLING_PRICE_USD,
                                    SOURCE_ORGANIZATION_ID,
                                    DESTINATION_ORGANIZATION_ID,
                                    REQUISITION_LINE_ID,
                                    PO_LINE_ID,
                                    SOURCE_CURRENCY,
                                    DESTINATION_CURRENCY,
                                    CONVERSION_RATE_LOCAL,
                                    CONVERSION_RATE_USD,
                                    PROCESS_FLAG,
                                    CREATION_DATE,
                                    CREATED_BY,
                                    LAST_UPDATED_DATE,
                                    LAST_UPDATED_BY,
                                    LAST_LOGIN,
                                    CST_ORG,
                                    OVER_HEAD_COST,
                                    OVER_HEAD_COST_PCNT,
                                    SOURCE_OPERATING_UNIT,
                                    DSTN_OEPRATING_UNIT,
                                    TRX_RELATIONSHIP,
                                    on_hand_quantity,
                                    TRX_MRGN_CST_USD,
                                    TRX_MRGN_CST_LOCAL,
                                    AVG_MRGN_CST_USD,
                                    AVG_MRGN_CST_LOCAL,
                                    mmt_transaction_id,
                                    mmt_creation_date)
                             VALUES (
                                        XXD_ONT_PO_IR_MARGIN_CALC_S.NEXTVAL,
                                        t_load_tbl_ir_tab (l_index).REQUEST_ID,
                                        t_load_tbl_ir_tab (l_index).SOURCE,
                                        t_load_tbl_ir_tab (l_index).order_number,
                                        t_load_tbl_ir_tab (l_index).rcv_transaction_id,
                                        t_load_tbl_ir_tab (l_index).HEADER_ID,
                                        t_load_tbl_ir_tab (l_index).LINE_ID,
                                        t_load_tbl_ir_tab (l_index).ORDERED_QUANTITY,
                                        t_load_tbl_ir_tab (l_index).TRANSACTION_QUANTITY,
                                        t_load_tbl_ir_tab (l_index).INVOICED_QUANTITY,
                                        t_load_tbl_ir_tab (l_index).INVENTORY_ITEM_ID,
                                        t_load_tbl_ir_tab (l_index).DELIVERY_DETAIL_ID,
                                        t_load_tbl_ir_tab (l_index).DELIVERY_ID,
                                        t_load_tbl_ir_tab (l_index).TRANSACTION_DATE,
                                        t_load_tbl_ir_tab (l_index).UNIT_SELLING_PRICE,
                                        t_load_tbl_ir_tab (l_index).UNIT_SELLING_PRICE_USD,
                                        t_load_tbl_ir_tab (l_index).SOURCE_ORGANIZATION_ID,
                                        t_load_tbl_ir_tab (l_index).DESTINATION_ORGANIZATION_ID,
                                        t_load_tbl_ir_tab (l_index).REQUISITION_LINE_ID,
                                        t_load_tbl_ir_tab (l_index).PO_LINE_ID,
                                        t_load_tbl_ir_tab (l_index).SOURCE_CURRENCY,
                                        t_load_tbl_ir_tab (l_index).DESTINATION_CURRENCY,
                                        t_load_tbl_ir_tab (l_index).CONVERSION_RATE_LOCAL,
                                        t_load_tbl_ir_tab (l_index).CONVERSION_RATE_USD,
                                        t_load_tbl_ir_tab (l_index).PROCESS_FLAG,
                                        t_load_tbl_ir_tab (l_index).CREATION_DATE,
                                        t_load_tbl_ir_tab (l_index).CREATED_BY,
                                        t_load_tbl_ir_tab (l_index).LAST_UPDATED_DATE,
                                        t_load_tbl_ir_tab (l_index).LAST_UPDATED_BY,
                                        t_load_tbl_ir_tab (l_index).LAST_LOGIN,
                                        t_load_tbl_ir_tab (l_index).CST_ORG,
                                        t_load_tbl_ir_tab (l_index).OVER_HEAD_COST,
                                        t_load_tbl_ir_tab (l_index).OVER_HEAD_COST_PCNT,
                                        t_load_tbl_ir_tab (l_index).SOURCE_OPERATING_UNIT,
                                        t_load_tbl_ir_tab (l_index).DSTN_OEPRATING_UNIT,
                                        t_load_tbl_ir_tab (l_index).TRX_RELATIONSHIP,
                                        t_load_tbl_ir_tab (l_index).on_hand_quantity,
                                        t_load_tbl_ir_tab (l_index).TRX_MRGN_CST_USD,
                                        t_load_tbl_ir_tab (l_index).TRX_MRGN_CST_LOCAL,
                                        t_load_tbl_ir_tab (l_index).AVG_MRGN_CST_USD,
                                        t_load_tbl_ir_tab (l_index).AVG_MRGN_CST_LOCAL,
                                        t_load_tbl_ir_tab (l_index).mmt_transaction_id,
                                        t_load_tbl_ir_tab (l_index).mmt_creation_date);
            EXCEPTION
                WHEN dml_errors
                THEN
                    FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        lv_err_msg   :=
                               'Error while Inserting XXD_ONT_PO_MARGIN_CALC_T Table : '
                            || SQLCODE
                            || ' ---> '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while updating XXD_ONT_PO_MARGIN_CALC_T Table : '
                            || t_load_tbl_ir_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).delivery_detail_id
                            || ' -- '
                            || t_load_tbl_ir_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).ORDER_number
                            || ' -- '
                            || SQLERRM
                            || '-----> '
                            || SQLCODE);
                        x_errbuf    := 2;
                        x_retcode   := lv_err_msg;

                        LOG (gv_debug, 'Exception1' || SQLERRM);
                    --                  lv_status := 3;
                    --                  lv_message := lv_err_msg;
                    END LOOP;
                WHEN OTHERS
                THEN
                    lv_err_msg   :=
                           'Error Others while inserting into XXD_ONT_PO_MARGIN_CALC_T table'
                        || SQLERRM;

                    FOR l_error_index IN 1 .. SQL%BULK_EXCEPTIONS.COUNT
                    LOOP
                        lv_err_msg   :=
                               'When Others exception: Error while inserting IR XXD_ONT_PO_MARGIN_CALC_IR_T Table : '
                            || SQLCODE
                            || ' ---> '
                            || SQLERRM;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'When others exception Error while inserting IR XXD_ONT_PO_MARGIN_CALC_IR_T Table : '
                            || t_load_tbl_ir_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).delivery_detail_id
                            || ' -- '
                            || t_load_tbl_ir_tab (
                                   SQL%BULK_EXCEPTIONS (l_error_index).ERROR_INDEX).order_number
                            || ' -- '
                            || SQLERRM
                            || '-----> '
                            || SQLCODE);
                        LOG (gv_debug, 'Exception2');
                        --                  lv_status := 4;
                        --                  lv_message := lv_err_msg;
                        x_errbuf    := 2;
                        x_retcode   := lv_err_msg;
                    END LOOP;
            END;

            --COMMIT;

            EXIT WHEN cur_insrt_stg_2%NOTFOUND;
        END LOOP;

        CLOSE cur_insrt_stg_2;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                gv_debug,
                   'Error @proc_load_trx while inserting IR into table'
                || SQLERRM);
            x_retcode   := 2;
            x_errbuf    :=
                   'Error @proc_load_trx while inserting IR into table'
                || SQLERRM;
    END;

    PROCEDURE MAIN_LOAD (errbuf                OUT VARCHAR2,
                         retcode               OUT VARCHAR2,
                         pd_create_from_date       VARCHAR2,
                         pv_debug                  VARCHAR2,
                         pv_gather_stats           VARCHAR2,
                         pv_reprocess_flag         VARCHAR2,
                         pd_reprocess_date         VARCHAR2,
                         --start changes v1.1
                         pn_offset_hours           NUMBER   --end changes v1.1
                                                         )
    IS
        x_retcode           VARCHAR2 (1) := 0;
        x_errbuf            VARCHAR2 (1000) := NULL;
        ld_reprocess_date   DATE;
    BEGIN
        gv_debug               := pv_debug;
        gn_conc_request_id     := fnd_global.CONC_REQUEST_ID;
        gv_gather_stats        := pv_gather_stats;

        gd_from_cut_off_date   := func_get_cut_off_date ('1001'); -- 1001 is for critical collection
        --Start Changes V1.1
        --      gd_to_cut_off_date := SYSDATE;
        gd_to_cut_off_date     := SYSDATE - (NVL (pn_offset_hours, 1) / 24);
        --End Changes V1.1
        --gd_to_cut_off_date := TO_DATE ('30-SEP-2017', 'DD-MON-RRRR'); --NVL (func_get_cut_off_date, SYSDATE);

        LOG (
            gv_debug,
               'From Cut Off Date and To Cut Off Date - '
            --Start changes V1.1
            --|| gd_from_cut_off_date
            --         || ' and '
            --         || gd_to_cut_off_date
            || TO_CHAR (gd_from_cut_off_date, 'RRRR/MM/DD HH24:mi:ss')
            || ' and '
            || TO_CHAR (gd_to_cut_off_date, 'RRRR/MM/DD HH24:mi:ss'));

        --End Changes V1.1

        BEGIN
            SELECT ORGANIZATION_ID
              INTO gn_mc1_org_id
              FROM org_organization_definitions
             WHERE 1 = 1 AND organization_code = 'MC1';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_mc1_org_id   := NULL;
                LOG (gv_debug,
                     'Error While getting MC1 Organization' || SQLERRM);
        END;


        BEGIN
            SELECT order_source_id
              INTO gn_order_src_id
              FROM oe_order_sources
             WHERE 1 = 1 AND name = 'Internal';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_mc1_org_id   := NULL;
                LOG (gv_debug,
                     'Error While getting Order Source ID' || SQLERRM);
        END;

        -- Calling Gather Stats for the custom table
        IF NVL (pv_gather_stats, 'N') = 'Y'
        THEN
            proc_gather_table_stats ('XXDO',
                                     'XXD_ONT_PO_MARGIN_CALC_T',
                                     TRUE);
            proc_gather_table_stats ('XXDO',
                                     'XXD_ONT_PO_MARGIN_ERR_LOG_T',
                                     TRUE);
        END IF;

        proc_load_trx (pd_create_from_date, x_errbuf, x_retcode);

        IF x_retcode <> 0 OR NVL (x_errbuf, 'ZZZ') <> 'ZZZ'
        THEN
            LOG (gv_debug, 'Error.!! hence exiting');
            retcode   := x_retcode;
            errbuf    := x_errbuf;
        ELSE
            proc_update_cutoff_date (
                '1001',
                gd_from_cut_off_date,
                TRUNC (LAST_DAY (ADD_MONTHS (gd_to_cut_off_date, -1))));
            retcode   := 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := 'Error @Main_LOAD proc';
            retcode   := 2;
            LOG (gv_debug, 'Error Orrured @Main_LOAD' || SQLERRM);
    END;


    --Only For Internal Requisitions - Receipts
    PROCEDURE MAIN_IR_LOAD (errbuf                OUT VARCHAR2,
                            retcode               OUT VARCHAR2,
                            pd_create_from_date       VARCHAR2,
                            pv_debug                  VARCHAR2,
                            pv_gather_stats           VARCHAR2,
                            pv_reprocess_flag         VARCHAR2,
                            pd_reprocess_date         VARCHAR2,
                            --start changes v1.1
                            pn_offset_hours           NUMBER --end changes v1.1
                                                            )
    IS
        x_retcode           VARCHAR2 (1) := 0;
        x_errbuf            VARCHAR2 (1000) := NULL;
        ld_reprocess_date   DATE;
    BEGIN
        gv_debug               := pv_debug;
        gn_conc_request_id     := fnd_global.CONC_REQUEST_ID;

        gv_gather_stats        := pv_gather_stats;

        gd_from_cut_off_date   := func_get_cut_off_date ('IR');
        --Start Changes V1.1
        --      gd_to_cut_off_date := SYSDATE;
        gd_to_cut_off_date     := SYSDATE - (NVL (pn_offset_hours, 2) / 24);
        --End Changes V1.1
        --gd_to_cut_off_date := TO_DATE ('30-SEP-2017', 'DD-MON-RRRR'); --NVL (func_get_cut_off_date, SYSDATE);

        LOG (
            gv_debug,
               'From Cut Off Date and To Cut Off Date - '
            || gd_from_cut_off_date
            || ' and '
            || gd_to_cut_off_date);

        BEGIN
            SELECT ORGANIZATION_ID
              INTO gn_mc1_org_id
              FROM org_organization_definitions
             WHERE 1 = 1 AND organization_code = 'MC1';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_mc1_org_id   := NULL;
                LOG (gv_debug,
                     'Error While getting MC1 Organization' || SQLERRM);
        END;


        BEGIN
            SELECT order_source_id
              INTO gn_order_src_id
              FROM oe_order_sources
             WHERE 1 = 1 AND name = 'Internal';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_mc1_org_id   := NULL;
                LOG (gv_debug,
                     'Error While getting Order Source ID' || SQLERRM);
        END;

        -- Calling Gather Stats for the custom table
        IF NVL (pv_gather_stats, 'N') = 'Y'
        THEN
            proc_gather_table_stats ('XXDO',
                                     'XXD_ONT_PO_MARGIN_CALC_IR_T',
                                     TRUE);
            proc_gather_table_stats ('XXDO',
                                     'XXD_ONT_PO_MARGIN_ERR_LOG_T',
                                     TRUE);
        END IF;

        proc_load_ir_trx (pd_create_from_date, x_errbuf, x_retcode);

        IF x_retcode <> 0 OR NVL (x_errbuf, 'ZZZ') <> 'ZZZ'
        THEN
            LOG (gv_debug, 'Error.!! hence exiting');
            retcode   := x_retcode;
            errbuf    := x_errbuf;
        ELSE
            proc_update_cutoff_date (
                'IR',
                gd_from_cut_off_date,
                TRUNC (LAST_DAY (ADD_MONTHS (gd_to_cut_off_date, -1))));
            retcode   := 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := 'Error @Main_IR_LOAD proc';
            retcode   := 2;
            LOG (gv_debug, 'Error Orrured @Main_IR_LOAD' || SQLERRM);
    END;


    PROCEDURE MAIN_UPDATE (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pd_create_from_date VARCHAR2, pv_debug VARCHAR2, pv_gather_stats VARCHAR2, pv_reprocess_flag VARCHAR2
                           , pd_reprocess_date VARCHAR2)
    IS
        x_retcode           VARCHAR2 (1);
        x_errbuf            VARCHAR2 (1000) := NULL;
        ld_reprocess_date   DATE;
    BEGIN
        gv_debug               := pv_debug;
        gn_conc_request_id     := fnd_global.CONC_REQUEST_ID;

        gd_from_cut_off_date   := func_get_cut_off_date ('1001');
        gd_to_cut_off_date     := SYSDATE; --NVL (func_get_cut_off_date('1001'), SYSDATE);

        gv_gather_stats        := pv_gather_stats;

        LOG (
            gv_debug,
               'From Cut Off Date and To Cut Off Date - '
            || gd_from_cut_off_date
            || ' and '
            || gd_to_cut_off_date);

        BEGIN
            SELECT ORGANIZATION_ID
              INTO gn_mc1_org_id
              FROM org_organization_definitions
             WHERE 1 = 1 AND organization_code = 'MC1';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_mc1_org_id   := NULL;
                LOG (gv_debug,
                     'Error While getting MC1 Organization' || SQLERRM);
        END;



        BEGIN
            SELECT order_source_id
              INTO gn_order_src_id
              FROM oe_order_sources
             WHERE 1 = 1 AND name = 'Internal';
        EXCEPTION
            WHEN OTHERS
            THEN
                gn_order_src_id   := NULL;
                LOG (gv_debug,
                     'Error While getting Order Source ID' || SQLERRM);
        END;

        -- Calling proc_reprocess
        IF NVL (pv_reprocess_flag, 'N') = 'Y'
        THEN
            ld_reprocess_date   :=
                NVL (fnd_date.canonical_to_date (pd_reprocess_date), SYSDATE);
            proc_reprocess ('UPDATE', ld_reprocess_date);
        END IF;

        -- Calling Gather Stats for the custom table
        IF NVL (pv_gather_stats, 'N') = 'Y'
        THEN
            proc_gather_table_stats ('XXDO',
                                     'XXD_ONT_PO_MARGIN_CALC_T',
                                     TRUE);
            proc_gather_table_stats ('XXDO',
                                     'XXD_ONT_PO_MARGIN_ERR_LOG_T',
                                     TRUE);
        END IF;



        proc_update_src_trx (pd_create_from_date, x_errbuf, x_retcode);


        IF x_retcode <> 0 OR NVL (x_errbuf, 'ZZZ') <> 'ZZZ'
        THEN
            LOG (gv_debug, 'Error.!! hence exiting');
            retcode   := x_retcode;
            errbuf    := x_errbuf;
        END IF;

        retcode                := 0;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := 'Error @Main proc';
            retcode   := 2;
            LOG (gv_debug, 'Error Orrured @Main_UPDATE' || SQLERRM);
    END;
END XXD_ONT_CAL_MARGIN_PKG;
/
