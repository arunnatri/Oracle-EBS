--
-- XXDOINV_CONSOL_INV_REPORT  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINV_CONSOL_INV_REPORT"
/********************************************************************************************
  *                                                                                         *
  * History                                                                                 *
  * Vsn     Change Date     Changed By              Change Description                      *
  * -----   -----------     ------------------      ----------------------------------------*
  * 1.0     13-JUN-2014     BT Technology team      Base Version                            *
  * 1.1     21-JAN-2015     BT Technology team      CCR0008682                              *
  * 1.2     12-JUN-2015     BT Technology team      Added Total value column for            *
  *                                                 defect#2322                             *
  * 1.3     22-JUN-2015     BT Technology Team      Added intransit columns for             *
  *                                                 defect#2322                             *
  * 1.4     23-JUN-2015     BT Technology Team      Added currency coversion in I/C         *
  *                                                 profit column for defect#2322           *
  * 1.5     01-JUL-2015     BT Technology Team      Defect #2411 - Global Inventory         *
  *                                                 Report uses both CNY and USD currencies *
  * 1.6     20-NOV-2015     BT Technology Team      Defect#689                              *
  * 1.7     09-DEC-2015     BT Technology Team      Defect#689                              *
  * 1.8     10-DEC-2015     BT Technology Team      Defect#689                              *
  * 1.9     13-JUN-2016     Infosys                 INC0299210                              *
  * 2.1     29-NOV-2017     Arun N Murthy           EU First Sale Project CCR0006823        *
  * 3.0     05-AUG-2020     Srinath Siricilla       CCR0008682                              *
  * 3.1     02-FEB-2021     Showkath Ali            CCR0008986                              *
  * 3.2     21-May-2021     Tejaswi G               CCR0008870                              *
  * 3.3     28-Jul-2021     Tejaswi G               CCR0009491                              *
  * 3.4     17-Feb-2022     Showkath Ali            CCR0009806 Reverting PO Receiving chngs *
  * 3.5     12-Aug-2022     Showkath Ali            CCR0010109
  *******************************************************************************************/
IS
    g_pkg_name      CONSTANT VARCHAR2 (40) := 'XXDOINV_CONSOL_INV_REPORT';
    -- Start Changes by BT Technology Team on 23/01/2014
    --g_def_macau_inv_org_id   CONSTANT NUMBER        := 113;
    g_def_macau_inv_org_id   NUMBER;
    -- End Changes by BT Technology Team on 23/01/2014
    g_delim_char    CONSTANT VARCHAR2 (1) := '|';
    g_category_set_id        NUMBER;
    g_category_set_name      VARCHAR2 (100) := 'OM Sales Category';
    gc_delimiter             VARCHAR2 (100);

    /*
        Table Creation Scripts

        drop table xxdo.xxdoinv_cir_orgs;

        drop table xxdo.xxdoinv_cir_data;

        drop table xxdo.xxdoinv_cir_master_item_cst;

        create global temporary table xxdo.xxdoinv_cir_orgs (
            organization_id                 number                          not null
          , is_master_org_id              number
          , primary_cost_method        number                           not null
          , constraint xxdoinv_cir_orgs_pk primary key (organization_id)
        ) on commit preserve rows;

        create unique index xxdo.xxdoinv_cir_orgs_u1 on xxdo.xxdoinv_cir_orgs (is_master_org_id);

        create global temporary table xxdo.xxdoinv_cir_data (
            tpe                                  varchar2(20)   not null
          , organization_id                 number          not null
          , inventory_item_id              number         not null
          , quantity                            number
    --      , ship_date                          date
    --      , shipment_line_id                number
          , rcv_transaction_Id              number
          , trx_material_cost               number
          , trx_freight_cost                 number
          , trx_duty_cost                     number
          , trx_item_cost                     number
          , itm_material_cost               number
          , itm_freight_cost                 number
          , itm_duty_cost                     number
          , itm_item_cost                     number
          , sys_item_cost                     number
          , sys_item_non_mat_cost             number
          , accrual_missing                 number      default 0 not null
        ) on commit preserve rows;

        create index xxdo.xxdoinv_cir_data_n1 on xxdo.xxdoinv_cir_data(organization_id, inventory_item_id);

        create global temporary table xxdo.xxdoinv_cir_master_item_cst (
            inventory_item_id              number                          not null
          , organization_id                 number                          not null
          , material_cost                    number
          , freight_cost                       number
          , duty_cost                          number
          , item_cost                          number
          , duty_rate                          number
          , macau_cost                      number
          , is_direct_import_sku         varchar2(1)
          , constraint xxdoinv_cir_master_item_cst_pk primary key (inventory_item_id)
        ) on commit preserve rows;

    */
    -- procedure to load the data in temp tables for intransit quantity  -- 3.5

    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, gc_delimiter || p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    -- 3.5 changes start
    PROCEDURE load_temp_table (p_as_of_date       IN     DATE,
                               p_inv_org_id       IN     NUMBER,
                               p_cost_type_id     IN     NUMBER,
                               x_ret_stat            OUT VARCHAR2,
                               x_error_messages      OUT VARCHAR2)
    IS
        l_proc_name      VARCHAR2 (80) := g_pkg_name || '.LOAD_TEMP_TABLE';
        l_cost_type_id   NUMBER;
        l_msg_cnt        NUMBER;
    BEGIN
        do_debug_tools.msg ('+' || l_proc_name);
        do_debug_tools.msg (
               'p_as_of_date='
            || NVL (TO_CHAR (p_as_of_date, 'YYYY-MM-DD'), '{None}')
            || ', p_inv_org_id='
            || p_inv_org_id
            || ', p_cost_type_id='
            || NVL (TO_CHAR (p_cost_type_id), '{None}'));

        BEGIN
            l_cost_type_id   := p_cost_type_id;

            IF l_cost_type_id IS NULL
            THEN
                do_debug_tools.msg (
                    ' looping up cost type from inventory organization.');

                SELECT primary_cost_method
                  INTO l_cost_type_id
                  FROM mtl_parameters
                 WHERE organization_id = p_inv_org_id;

                do_debug_tools.msg (
                       ' found cost type '
                    || l_cost_type_id
                    || ' from inventory organization.');
            END IF;

            do_debug_tools.msg (
                ' before call to CST_Inventory_PUB.Calculate_InventoryValue');
            cst_inventory_pub.calculate_inventoryvalue (
                p_api_version          => 1.0,
                p_init_msg_list        => fnd_api.g_false,
                p_commit               => cst_utility_pub.get_true,
                p_organization_id      => p_inv_org_id,
                p_onhand_value         => 0,
                p_intransit_value      => 1,
                p_receiving_value      => 1,
                p_valuation_date       => TRUNC (NVL (p_as_of_date, SYSDATE) + 1),
                p_cost_type_id         => l_cost_type_id,
                p_item_from            => NULL,
                p_item_to              => NULL--Start modification by BT Technology Team on 9-march-2015  'Styles'as replacement for 'OM sales Category'
                                              --,p_category_set_id      => 4
                                              ,
                p_category_set_id      => g_category_set_id--End modification by BT Technology Team on 9-march-2015  'Styles'as replacement for 'OM sales Category'
                                                           ,
                p_category_from        => NULL,
                p_category_to          => NULL,
                p_cost_group_from      => NULL,
                p_cost_group_to        => NULL,
                p_subinventory_from    => NULL,
                p_subinventory_to      => NULL,
                p_qty_by_revision      => 0,
                p_zero_cost_only       => 0,
                p_zero_qty             => 0,
                p_expense_item         => 0,
                p_expense_sub          => 0,
                p_unvalued_txns        => 0,
                p_receipt              => 1,
                p_shipment             => 1,
                p_detail               => 1,
                p_own                  => 0,
                p_cost_enabled_only    => 0,
                p_one_time_item        => 0,
                p_include_period_end   => NULL,
                x_return_status        => x_ret_stat,
                x_msg_count            => l_msg_cnt,
                x_msg_data             => x_error_messages);
            do_debug_tools.msg (
                ' after call to CST_Inventory_PUB.Calculate_InventoryValue');

            SELECT COUNT (1) INTO l_msg_cnt FROM cst_inv_qty_temp;

            do_debug_tools.msg ('count: ' || l_msg_cnt);
        EXCEPTION
            WHEN OTHERS
            THEN
                do_debug_tools.msg (' others exception: ' || SQLERRM);
                x_ret_stat         := fnd_api.g_ret_sts_error;
                x_error_messages   := SQLERRM;
        END;

        do_debug_tools.msg (
               'x_ret_stat='
            || x_ret_stat
            || ', x_error_messages='
            || x_error_messages);
        do_debug_tools.msg ('-' || l_proc_name);
    END;

    -- 3.5 changes end
    FUNCTION scrub_value (p_value IN VARCHAR2)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN REPLACE (p_value, g_delim_char, ' ');
    END;

    FUNCTION default_duty_rate (p_inv_id IN NUMBER, p_org_id NUMBER)
        RETURN NUMBER
    IS
        l_duty   NUMBER;
    BEGIN
        SELECT DISTINCT duty
          INTO l_duty
          FROM xxdo_invval_duty_cost
         WHERE     inventory_item_id = p_inv_id
               AND inventory_org = p_org_id
               AND primary_duty_flag = 'Y'
               --Start changes by BT Technology Team on 20-Nov-2015 for defect#689
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (duty_start_date, SYSDATE))
                                       AND TRUNC (
                                               NVL (duty_end_date, SYSDATE));

        --End changes by BT Technology Team on 20-Nov-2015 for defect#689
        RETURN l_duty;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_duty   := 0;
            RETURN l_duty;
    END;

    --Start changes for V2.1
    FUNCTION get_max_seq_value (pn_inventory_item_id NUMBER, pn_organization_id NUMBER, p_as_of_date DATE)
        RETURN NUMBER
    IS
        ln_max_seq_no   NUMBER;
    BEGIN
          SELECT MAX (xop1.sequence_number) sequence_number
            INTO ln_max_seq_no
            FROM xxd_ont_po_margin_calc_t xop1
           WHERE     1 = 1
                 AND xop1.inventory_item_id = pn_inventory_item_id
                 AND xop1.destination_organization_id = pn_organization_id
                 AND xop1.SOURCE <> 'TQ_SO_SHIPMENT'
                 AND NVL (xop1.mmt_creation_date, '01-DEC-2017') <
                     NVL (p_as_of_date, SYSDATE + 1)
        GROUP BY inventory_item_id, destination_organization_id;

        RETURN ln_max_seq_no;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN OTHERS
        THEN
            fnd_file.put (
                fnd_file.LOG,
                'Error While getting Latest Transaction from the custom table @get_max_seq_value');
    END;

    --Procedure for onhand Intransit Margin
    PROCEDURE get_rollback_trx_onhand_qty (
        pn_inventory_item_id                 NUMBER,
        pv_style                             VARCHAR2,
        pv_color                             VARCHAR2,
        pv_size                              VARCHAR2,
        pn_organization_id                   NUMBER,
        p_as_of_date                         DATE,
        pn_diff_qty                          NUMBER,
        pv_source                            VARCHAR2,
        pn_seq_number                        NUMBER,
        xn_seq_number                    OUT NUMBER,
        xv_source                        OUT VARCHAR2,
        xn_inventory_item_id             OUT NUMBER,
        xn_destination_organization_id   OUT NUMBER,
        xd_transaction_date              OUT DATE,
        xn_transaction_quantity          OUT NUMBER,
        xn_trx_mrgn_cst_usd              OUT NUMBER,
        xn_trx_mrgn_cst_local            OUT NUMBER)
    IS
    BEGIN
        SELECT sequence_number, SOURCE, inventory_item_id,
               destination_organization_id, mmt_creation_date transaction_date, --taking mmt_creation_date as trx date
                                                                                transaction_quantity,
               NVL (LEAST (pn_diff_qty, transaction_quantity), pn_diff_qty) * trx_mrgn_cst_usd trx_mrgn_cst_usd, NVL (LEAST (pn_diff_qty, transaction_quantity), pn_diff_qty) * trx_mrgn_cst_local trx_mrgn_cst_local
          INTO xn_seq_number, xv_source, xn_inventory_item_id, xn_destination_organization_id,
                            xd_transaction_date, xn_transaction_quantity, xn_trx_mrgn_cst_usd,
                            xn_trx_mrgn_cst_local
          FROM ((SELECT xop.mmt_transaction_id, NVL (xop.mmt_creation_date, '01-DEC-2017') mmt_creation_date, xop.sequence_number,
                        xop.SOURCE, xop.inventory_item_id, xop.destination_organization_id,
                        xop.transaction_date, NVL (xop.transaction_quantity, 99999999999999999999) transaction_quantity, xop.trx_mrgn_cst_usd,
                        xop.trx_mrgn_cst_local
                   FROM xxd_ont_po_margin_calc_t xop, mtl_system_items_b msib, mtl_item_categories mic,
                        mtl_categories_b mc
                  WHERE     1 = 1
                        AND xop.SOURCE = 'TQ_PO_RECEIVING'
                        AND mic.category_id = mc.category_id
                        AND msib.inventory_item_id = mic.inventory_item_id
                        AND xop.inventory_item_id = msib.inventory_item_id
                        AND msib.organization_id = mic.organization_id
                        AND mic.category_set_id = 1
                        AND xop.destination_organization_id =
                            mic.organization_id
                        AND mc.attribute7 = pv_style
                        AND mc.attribute8 = pv_color
                        AND msib.attribute27 =
                            NVL (pv_size, msib.attribute27)
                        AND destination_organization_id = pn_organization_id
                        --                     AND creation_date < p_as_of_date
                        AND CASE
                                WHEN pv_source = 'TQ_PO_RECEIVING'
                                THEN
                                    TO_DATE (SYSDATE - 1)
                                ELSE
                                    NVL (xop.mmt_creation_date,
                                         '01-DEC-2017')
                            END <
                            CASE
                                WHEN pv_source = 'TQ_PO_RECEIVING'
                                THEN
                                    TO_DATE (SYSDATE + 1)
                                ELSE
                                    p_as_of_date       --TO_DATE (SYSDATE + 1)
                            END
                        AND CASE
                                WHEN pv_source = 'TQ_PO_RECEIVING'
                                THEN
                                    xop.sequence_number
                                ELSE
                                    0
                            END <
                            CASE
                                WHEN pv_source = 'TQ_PO_RECEIVING'
                                THEN
                                    pn_seq_number
                                ELSE
                                    1
                            END
                 UNION
                 SELECT xop.mmt_transaction_id, NVL (xop.mmt_creation_date, '01-DEC-2017') mmt_creation_date, xop.sequence_number,
                        xop.SOURCE, xop.inventory_item_id, xop.destination_organization_id,
                        xop.transaction_date, NVL (xop.transaction_quantity, 99999999999999999999) transaction_quantity, xop.trx_mrgn_cst_usd,
                        xop.trx_mrgn_cst_local
                   FROM xxd_ont_po_ir_margin_calc_t xop, mtl_system_items_b msib, mtl_item_categories mic,
                        mtl_categories_b mc
                  WHERE     1 = 1
                        AND mic.category_id = mc.category_id
                        AND msib.inventory_item_id = mic.inventory_item_id
                        AND xop.inventory_item_id = msib.inventory_item_id
                        AND msib.organization_id = mic.organization_id
                        AND mic.category_set_id = 1
                        AND xop.destination_organization_id =
                            mic.organization_id
                        AND mc.attribute7 = pv_style
                        AND mc.attribute8 = pv_color
                        AND msib.attribute27 =
                            NVL (pv_size, msib.attribute27)
                        AND destination_organization_id = pn_organization_id
                        AND CASE
                                WHEN NVL (pv_source, 'ABC') =
                                     'IR_PO_RECEIVING'
                                THEN
                                    SYSDATE - 1
                                ELSE
                                    NVL (xop.mmt_creation_date,
                                         '01-DEC-2017')
                            END <
                            CASE
                                WHEN NVL (pv_source, 'ABC') =
                                     'IR_PO_RECEIVING'
                                THEN
                                    SYSDATE + 1
                                ELSE
                                    p_as_of_date
                            END
                        --                     AND creation_date < p_as_of_date
                        AND CASE
                                WHEN NVL (pv_source, 'ABC') =
                                     'IR_PO_RECEIVING'
                                THEN
                                    sequence_number
                                ELSE
                                    0
                            END <
                            CASE
                                WHEN NVL (pv_source, 'ABC') =
                                     'IR_PO_RECEIVING'
                                THEN
                                    pn_seq_number
                                ELSE
                                    1
                            END
                 UNION
                 SELECT xop.mmt_transaction_id, NVL (xop.mmt_creation_date, '01-DEC-2017') mmt_creation_date, xop.sequence_number,
                        xop.SOURCE, xop.inventory_item_id, xop.destination_organization_id,
                        xop.transaction_date, NVL (xop.transaction_quantity, 99999999999999999999) transaction_quantity, xop.trx_mrgn_cst_usd,
                        xop.trx_mrgn_cst_local
                   FROM xxd_ont_po_margin_calc_t xop, mtl_system_items_b msib, mtl_item_categories mic,
                        mtl_categories_b mc
                  WHERE     1 = 1
                        AND xop.SOURCE = 'ONE_TIME_UPLOAD'
                        AND mic.category_id = mc.category_id
                        AND msib.inventory_item_id = mic.inventory_item_id
                        AND xop.inventory_item_id = msib.inventory_item_id
                        AND msib.organization_id = mic.organization_id
                        AND mic.category_set_id = 1
                        AND xop.destination_organization_id =
                            mic.organization_id
                        AND mc.attribute7 = pv_style
                        AND mc.attribute8 = pv_color
                        AND msib.attribute27 =
                            NVL (pv_size, msib.attribute27)
                        AND destination_organization_id = pn_organization_id
                        AND CASE
                                WHEN NVL (pv_source, 'ABC') =
                                     'ONE_TIME_UPLOAD'
                                THEN
                                    SYSDATE - 1
                                ELSE
                                    NVL (xop.mmt_creation_date,
                                         '01-DEC-2017')
                            END <
                            CASE
                                WHEN NVL (pv_source, 'ABC') =
                                     'IR_PO_RECEIVING'
                                THEN
                                    SYSDATE + 1
                                ELSE
                                    p_as_of_date
                            END
                        --                     AND creation_date < p_as_of_date
                        AND CASE
                                WHEN NVL (pv_source, 'ABC') =
                                     'ONE_TIME_UPLOAD'
                                THEN
                                    sequence_number
                                ELSE
                                    0
                            END <
                            CASE
                                WHEN NVL (pv_source, 'ABC') =
                                     'ONE_TIME_UPLOAD'
                                THEN
                                    pn_seq_number
                                ELSE
                                    1
                            END)
                ORDER BY mmt_transaction_id DESC, mmt_creation_date DESC, sequence_number DESC)
         WHERE 1 = 1 AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            xv_source                        := NULL;
            xn_seq_number                    := pn_seq_number;
            xn_inventory_item_id             := pn_inventory_item_id;
            xn_destination_organization_id   := pn_organization_id;
            xd_transaction_date              := p_as_of_date;
            xn_transaction_quantity          := 99999999999999999999;
            xn_trx_mrgn_cst_usd              := 0;
            xn_trx_mrgn_cst_local            := 0;
        WHEN OTHERS
        THEN
            fnd_file.put (
                fnd_file.LOG,
                'Error While getting Latest Transaction from the custom table @get_rollback_trx_onhand_qty');
            xv_source                        := NULL;
            xn_seq_number                    := pn_seq_number;
            xn_inventory_item_id             := pn_inventory_item_id;
            xn_destination_organization_id   := pn_organization_id;
            xd_transaction_date              := p_as_of_date;
            xn_transaction_quantity          := 99999999999999999999;
            xn_trx_mrgn_cst_usd              := 0;
            xn_trx_mrgn_cst_local            := 0;
    END;

    --Procedure for Layered Intransit Margin
    PROCEDURE get_rollback_trx_intransit_qty (
        pn_inventory_item_id                 NUMBER,
        pv_style                             VARCHAR2,
        pv_color                             VARCHAR2,
        pv_size                              VARCHAR2,
        pn_organization_id                   NUMBER,
        p_as_of_date                         DATE,
        pn_diff_qty                          NUMBER,
        pn_sequence_number                   NUMBER,
        xv_intst_source                  OUT VARCHAR2,
        xn_sequence_number               OUT NUMBER,
        xn_intst_inventory_item_id       OUT NUMBER,
        xn_intst_destn_organization_id   OUT NUMBER,
        xd_intst_transaction_date        OUT DATE,
        xn_intst_transaction_quantity    OUT NUMBER,
        xn_intst_trx_mrgn_cst_usd        OUT NUMBER,
        xn_intst_trx_mrgn_cst_local      OUT NUMBER)
    IS
    BEGIN
        SELECT SOURCE, sequence_number, inventory_item_id,
               destination_organization_id, transaction_date, transaction_quantity,
               NVL (LEAST (pn_diff_qty, transaction_quantity), pn_diff_qty) * trx_mrgn_cst_usd trx_mrgn_cst_usd, NVL (LEAST (pn_diff_qty, transaction_quantity), pn_diff_qty) * trx_mrgn_cst_local trx_mrgn_cst_local
          INTO xv_intst_source, xn_sequence_number, xn_intst_inventory_item_id, xn_intst_destn_organization_id,
                              xd_intst_transaction_date, xn_intst_transaction_quantity, xn_intst_trx_mrgn_cst_usd,
                              xn_intst_trx_mrgn_cst_local
          FROM (  SELECT xop.SOURCE, xop.sequence_number, xop.inventory_item_id,
                         xop.destination_organization_id, NVL (xop.mmt_creation_date, '01-DEC-2017') transaction_date, --taking mmt_creation_date as trx_date
                                                                                                                       NVL (xop.transaction_quantity, 99999999999999999999) transaction_quantity,
                         xop.trx_mrgn_cst_usd, xop.trx_mrgn_cst_local
                    FROM xxd_ont_po_margin_calc_t xop, mtl_system_items_b msib, mtl_item_categories mic,
                         mtl_categories_b mc
                   WHERE     1 = 1
                         AND SOURCE != 'TQ_PO_RECEIVING'
                         AND mic.category_id = mc.category_id
                         AND msib.inventory_item_id = mic.inventory_item_id
                         AND xop.inventory_item_id = msib.inventory_item_id
                         AND msib.organization_id = mic.organization_id
                         AND mic.category_set_id = 1
                         AND NVL (xop.destination_organization_id,
                                  xop.source_organization_id) =
                             mic.organization_id
                         AND mc.attribute7 = pv_style
                         AND mc.attribute8 = pv_color
                         AND msib.attribute27 = NVL (pv_size, msib.attribute27)
                         AND NVL (destination_organization_id,
                                  xop.source_organization_id) =
                             NVL (pn_organization_id,
                                  xop.source_organization_id)
                         AND CASE
                                 WHEN pn_sequence_number IS NULL THEN 0
                                 ELSE sequence_number
                             END < CASE
                                       WHEN pn_sequence_number IS NULL THEN 1
                                       ELSE pn_sequence_number
                                   END
                         AND CASE
                                 WHEN pn_sequence_number IS NULL
                                 THEN
                                     NVL (xop.mmt_creation_date, '01-DEC-2017')
                                 ELSE
                                     SYSDATE - 1
                             END <
                             CASE
                                 WHEN pn_sequence_number IS NULL
                                 THEN
                                     p_as_of_date
                                 ELSE
                                     SYSDATE + 1
                             END
                ORDER BY sequence_number DESC)
         WHERE 1 = 1 AND ROWNUM = 1;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            xv_intst_source                  := NULL;
            xn_sequence_number               := pn_sequence_number;
            xn_intst_inventory_item_id       := pn_inventory_item_id;
            xn_intst_destn_organization_id   := pn_organization_id;
            xd_intst_transaction_date        := p_as_of_date;
            xn_intst_transaction_quantity    := 99999999999999999999;
            xn_intst_trx_mrgn_cst_usd        := 0;
            xn_intst_trx_mrgn_cst_local      := 0;
        WHEN OTHERS
        THEN
            fnd_file.put (
                fnd_file.LOG,
                'Error While getting Latest Transaction from the custom table @get_rollback_trx_intst_qty');
            xv_intst_source                  := NULL;
            xn_sequence_number               := pn_sequence_number;
            xn_intst_inventory_item_id       := pn_inventory_item_id;
            xn_intst_destn_organization_id   := pn_organization_id;
            xd_intst_transaction_date        := p_as_of_date;
            xn_intst_transaction_quantity    := 99999999999999999999;
            xn_intst_trx_mrgn_cst_usd        := 0;
            xn_intst_trx_mrgn_cst_local      := 0;
    END;

    --End Changes for V2.1
    PROCEDURE run_cir_report (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_retrieve_from IN VARCHAR2, -- Added as per CCR0008682
                                                                                                         p_inv_org_id IN NUMBER, p_region IN VARCHAR2, p_as_of_date IN VARCHAR2, p_brand IN VARCHAR2, p_master_inv_org_id IN NUMBER, p_xfer_price_list_id IN NUMBER, p_duty_override IN NUMBER:= 0, p_summary IN VARCHAR2, p_include_analysis IN VARCHAR2, p_use_accrual_vals IN VARCHAR2:= 'Y', p_from_currency IN VARCHAR2, p_elimination_rate_type IN VARCHAR2, p_elimination_rate IN VARCHAR2, p_dummy_elimination_rate IN VARCHAR2, p_user_rate IN NUMBER, p_tq_japan IN VARCHAR2, p_dummy_tq IN VARCHAR2, p_markup_rate_type IN VARCHAR2
                              , --p_dummy_markup_rate    IN       VARCHAR2,
                                p_jpy_user_rate IN NUMBER, p_debug_level IN NUMBER:= NULL, p_layered_mrgn IN VARCHAR2)
    IS
        l_proc_name                      VARCHAR2 (80) := g_pkg_name || '.RUN_CIR_REPORT';
        l_org_code                       mtl_parameters.organization_code%TYPE;
        l_det_cnt                        NUMBER;
        l_counter                        NUMBER;
        l_total                          NUMBER;
        l_qty_total                      NUMBER;
        l_total_mat                      NUMBER;
        l_total_profit_elim              NUMBER;
        l_use_accrual_vals               VARCHAR2 (1);
        l_macau_inv_org_id               NUMBER;
        l_use_date                       DATE;
        -- Start changes by BT Technology Team on  23/01/2014
        l_material_cost                  NUMBER;
        -- l_duty_rate           NUMBER;
        l_freight_du                     NUMBER;
        l_freight                        NUMBER;
        l_oh_duty                        NUMBER;
        l_oh_nonduty                     NUMBER;
        l_duty_cost                      NUMBER;
        l_ext_mat_cost                   NUMBER;
        l_ext_mac_cost                   NUMBER;
        l_tot_onhand_qty                 NUMBER;
        l_tot_ext_mat_cost               NUMBER;
        l_tot_ext_mac_cost               NUMBER;
        l_ext_macau_cost                 NUMBER;
        l_tot_iprofit                    NUMBER;
        l_default_duty                   NUMBER;
        l_total_cost                     NUMBER;
        -- End changes by BT Technology Team on  23/01/2014
        l_total_value                    NUMBER;
        -- Added by BT Technology Team on 12-Jun-2015 for defect#2322
        --Start changes by BT Technology Team 22-JUN-2015 for defect#2322
        l_intrans_val                    NUMBER;
        l_intrans_rec_val                NUMBER;        --Added for change 3.2
        l_intrans_mat_val                NUMBER;
        l_intrans_duty_val               NUMBER;
        l_intrans_frt_val                NUMBER;
        l_intrans_frt_du_val             NUMBER;
        l_intrans_oh_duty_val            NUMBER;
        l_intrans_nonoh_duty_val         NUMBER;
        --End changes by BT Technology Team 22-JUN-2015 for defect#2322
        -- Start changes by BT technology Team on 23-Jun-2015 for defect#2322
        l_iprofit                        NUMBER := 0;
        l_conv_rate                      NUMBER := 0;
        l_rate                           NUMBER := 0;
        l_tq_markup                      NUMBER := 0;
        l_tot_tqmarkup                   NUMBER := 0;
        l_rate_multiplier                NUMBER := 0;
        l_rate_amt                       NUMBER := 0;
        l_tot_inv_qty                    NUMBER := 0;
        l_tot_inv_val                    NUMBER := 0;
        l_ext_markup_mac_cost            NUMBER := 0;
        ln_total_overhead                NUMBER := 0;
        l_inv_org                        VARCHAR2 (80);
        l_inv_mst_org                    VARCHAR2 (80);
        --Start changes for V2.1
        --Onhand Layered Margin declaration
        xn_inventory_item_id             NUMBER;
        xn_destination_organization_id   NUMBER;
        xd_transaction_date              DATE;
        xn_transaction_quantity          NUMBER;
        xn_trx_mrgn_cst_usd              NUMBER;
        xn_trx_mrgn_cst_local            NUMBER;
        xv_source                        VARCHAR2 (100);
        lv_source                        VARCHAR2 (100);
        ln_transaction_quantity          NUMBER;
        ln_trx_mrgn_cst_usd              NUMBER;
        ln_trx_mrgn_cst_local            NUMBER;
        ln_diff_qty                      NUMBER;
        ld_trx_date                      DATE;
        ln_seq_number                    NUMBER;
        xn_seq_number                    NUMBER;
        -- Intransit Layered Margin
        xn_intst_inventory_item_id       NUMBER;
        xn_intst_destn_organization_id   NUMBER;
        xd_intst_transaction_date        DATE;
        xn_intst_transaction_quantity    NUMBER;
        xn_intst_trx_mrgn_cst_usd        NUMBER;
        xn_intst_trx_mrgn_cst_local      NUMBER;
        ln_intst_transaction_quantity    NUMBER;
        ln_intst_trx_mrgn_cst_usd        NUMBER;
        ln_intst_trx_mrgn_cst_local      NUMBER;
        ld_snapshot_date                 VARCHAR2 (100);
        l_ret_stat                       VARCHAR2 (1);
        l_err_messages                   VARCHAR2 (2000);

        -- Added as per CCR0008682

        --End Changes for V2.1

        --End changes by BT technology Team on 23-Jun-2015 for defect#2322
        CURSOR c_products IS
              SELECT /*+ INDEX(msib MTL_SYSTEM_ITEMS_B_U1) INDEX(mic MTL_ITEM_CATEGORIES_U1) INDEX(mcb MTL_CATEGORIES_B_U1) */
                                 --Starting commented by BT Team on 02/01/2015
                     /*mcb.segment1 AS brand, msib.segment1 AS style, msib.segment2 AS color,
                                        DECODE (:p_summary, 'Y', NULL, msib.segment3) AS sze,
                       MAX (msib.description) AS style_description,
                       MAX (ffv_colors.description) AS color_description,
                       MAX (mcb.segment2) AS series, MAX (mcb.segment4)
                                                                       AS product,
                       MAX (mcb.segment3) AS gender,
                       MAX (mcb.segment5) AS intro_season,
                       MAX (msib.attribute1) AS current_season,*/
                                   --Ending commented by BT Team on 02/01/2015
                     DISTINCT      -- Added by BT Tecnology Team on 20/02/2015
                              msib.brand AS brand, --Starting Added by BT Team on 02/01/2015
                                                   msib.style_number AS style, msib.color_code AS color,
                              msib.item_type AS item_type, -- CR#92 added Item Type BT Technology Team
                                                           MAX (msib.inventory_item_id) AS inventory_item_id, MAX (msib.item_number) AS item_number,
                              MAX (msib.organization_id) AS organization_id, MAX (msib.master_style) AS master_style, DECODE (p_summary, 'Y', NULL, msib.item_size) AS sze,
                              MAX (msib.style_desc) AS style_description, MAX (msib.item_description) AS item_description, MAX (msib.department) AS department,
                              MAX (msib.master_class) AS master_class, MAX (msib.sub_class) AS sub_class, MAX (msib.division) AS division,
                              MAX (msib.intro_season) AS intro_season, MAX (msib.curr_active_season) AS current_season, --End Added by BT Team on 02/01/2015

                                                                                                                        /* ROUND                                          --Starting commented by BT Team on 21/01/2015
                                                                                                                            (DECODE
                                                                                                                                (:p_summary,
                                                                                                                                 'Y', CASE
                                                                                                                                    WHEN SUM (DECODE (xco.is_master_org_id,
                                                                                                                                                      1, xcd.quantity,
                                                                                                                                                      0
                                                                                                                                                     )
                                                                                                                                             ) > 0
                                                                                                                                       THEN   SUM
                                                                                                                                                 (  xcmic.duty_rate
                                                                                                                                                  * DECODE
                                                                                                                                                         (xcmic.is_direct_import_sku,
                                                                                                                                                          'Y', xcmic.material_cost,
                                                                                                                                                            xcmic.macau_cost
                                                                                                                                                          + xcmic.freight_cost
                                                                                                                                                         )
                                                                                                                                                  * DECODE (xco.is_master_org_id,
                                                                                                                                                            1, xcd.quantity,
                                                                                                                                                            0
                                                                                                                                                           )
                                                                                                                                                 )
                                                                                                                                            / SUM (DECODE (xco.is_master_org_id,
                                                                                                                                                           1, xcd.quantity,
                                                                                                                                                           0
                                                                                                                                                          )
                                                                                                                                                  )
                                                                                                                                    WHEN SUM (xcd.quantity) > 0
                                                                                                                                       THEN   SUM
                                                                                                                                                 (  xcmic.duty_rate
                                                                                                                                                  * DECODE
                                                                                                                                                         (xcmic.is_direct_import_sku,
                                                                                                                                                          'Y', xcmic.material_cost,
                                                                                                                                                            xcmic.macau_cost
                                                                                                                                                          + xcmic.freight_cost
                                                                                                                                                         )
                                                                                                                                                  * xcd.quantity
                                                                                                                                                 )
                                                                                                                                            / SUM (xcd.quantity)
                                                                                                                                    ELSE 0
                                                                                                                                 END,
                                                                                                                                 MAX (  xcmic.duty_rate
                                                                                                                                      * DECODE (xcmic.is_direct_import_sku,
                                                                                                                                                'Y', xcmic.material_cost,
                                                                                                                                                xcmic.macau_cost + xcmic.freight_cost
                                                                                                                                               )
                                                                                                                                     )
                                                                                                                                ),
                                                                                                                             2
                                                                                                                            ) AS first_cost_duty,*/
                                                                                                                        --END commented by BT Team on 21/01/2015
                                                                                                                        ROUND (AVG (xcmic.duty_rate) * 100, 2) AS duty_rate,
                              ROUND (AVG (xcmic.item_cost), 2) AS master_item_cost, ROUND (AVG (xcmic.duty_cost), 2) AS master_duty_cost, ROUND (AVG (xcmic.macau_cost), 2) AS macau_cost
                /*ROUND                                                 -- commented by BT Team on 21/01/2015
                   (AVG
                       (apps.do_oe_utils.do_get_price_list_value
                                                    (p_xfer_price_list_id,
                                                     xcmic.inventory_item_id
                                                    )
                       ),
                    2
                   ) AS transfer_price,
                (SELECT NVL (cicd.item_cost, 0)
                   FROM cst_item_cost_type_v cict,
                        cst_item_cost_details_v cicd,
                        cst_cost_types cct1
                  WHERE cict.cost_type_id = cicd.cost_type_id
                    AND cict.inventory_item_id = cicd.inventory_item_id
                    AND cict.organization_id = cicd.organization_id
                    AND cicd.cost_type_id = cct1.cost_type_id
                    AND cct1.cost_type = 'Average'
                    AND cict.inventory_item_id = xcd.inventory_item_id
                    AND cict.organization_id = xcd.organization_id)
                                                          AS material_cost,
                (SELECT CASE
                           WHEN cicd.basis_type_dsp = 'Total Value'
                              THEN NVL
                                      (  cicd1.item_cost
                                       * cicd.usage_rate_or_amount
                                       / 100,
                                       0
                                      )
                           ELSE NVL (cicd.usage_rate_or_amount, 0)
                        END freight
                   FROM cst_item_cost_type_v cict,
                        cst_item_cost_details_v cicd,
                        cst_item_cost_details_v cicd1,
                        cst_cost_types cct1,
                        cst_cost_types cct2
                  WHERE cict.cost_type_id = cicd.cost_type_id
                    AND cict.inventory_item_id = cicd.inventory_item_id
                    AND cict.organization_id = cicd.organization_id
                    AND cicd1.cost_type_id = cct1.cost_type_id
                    AND cct1.cost_type = 'Average'
                    AND cicd.cost_type_id = cct2.cost_type_id
                    AND cct2.cost_type = 'AvgRates'
                    AND cicd1.inventory_item_id = cicd.inventory_item_id
                    AND cicd1.organization_id = cicd.organization_id
                    AND cict.inventory_item_id = xcd.inventory_item_id
                    AND cict.organization_id = xcd.organization_id
                    AND cicd.resource_code = 'FREIGHT') AS frieght,
                (SELECT CASE
                           WHEN cicd.basis_type_dsp =
                                                   'Total Value'
                              THEN NVL
                                     (  cicd1.item_cost
                                      * cicd.usage_rate_or_amount
                                      / 100,
                                      0
                                     )
                           ELSE NVL (cicd.usage_rate_or_amount, 0)
                        END frieght_du
                   FROM cst_item_cost_type_v cict,
                        cst_item_cost_details_v cicd,
                        cst_item_cost_details_v cicd1,
                        cst_cost_types cct1,
                        cst_cost_types cct2
                  WHERE cict.cost_type_id = cicd.cost_type_id
                    AND cict.inventory_item_id = cicd.inventory_item_id
                    AND cict.organization_id = cicd.organization_id
                    AND cicd1.cost_type_id = cct1.cost_type_id
                    AND cct1.cost_type = 'Average'
                    AND cicd.cost_type_id = cct2.cost_type_id
                    AND cct2.cost_type = 'AvgRates'
                    AND cicd1.inventory_item_id = cicd.inventory_item_id
                    AND cicd1.organization_id = cicd.organization_id
                    AND cict.inventory_item_id = xcd.inventory_item_id
                    AND cict.organization_id = xcd.organization_id
                    AND cicd.resource_code = 'FREIGHT DU') AS frieght_du,
                (SELECT CASE
                           WHEN cicd.basis_type_dsp = 'Total Value'
                              THEN NVL (  cicd1.item_cost
                                        * cicd.usage_rate_or_amount
                                        / 100,
                                        0
                                       )
                           ELSE NVL (cicd.usage_rate_or_amount, 0)
                        END duty
                   FROM cst_item_cost_type_v cict,
                        cst_item_cost_details_v cicd,
                        cst_item_cost_details_v cicd1,
                        cst_cost_types cct1,
                        cst_cost_types cct2
                  WHERE cict.cost_type_id = cicd.cost_type_id
                    AND cict.inventory_item_id = cicd.inventory_item_id
                    AND cict.organization_id = cicd.organization_id
                    AND cicd1.cost_type_id = cct1.cost_type_id
                    AND cct1.cost_type = 'Average'
                    AND cicd.cost_type_id = cct2.cost_type_id
                    AND cct2.cost_type = 'AvgRates'
                    AND cicd1.inventory_item_id = cicd.inventory_item_id
                    AND cicd1.organization_id = cicd.organization_id
                    AND cict.inventory_item_id = xcd.inventory_item_id
                    AND cict.organization_id = xcd.organization_id
                    AND cicd.resource_code = 'DUTY') AS duty,
                (SELECT CASE
                           WHEN cicd.basis_type_dsp = 'Total Value'
                              THEN NVL
                                      (  cicd1.item_cost
                                       * cicd.usage_rate_or_amount
                                       / 100,
                                       0
                                      )
                           ELSE NVL (cicd.usage_rate_or_amount, 0)
                        END oh_duty
                   FROM cst_item_cost_type_v cict,
                        cst_item_cost_details_v cicd,
                        cst_item_cost_details_v cicd1,
                        cst_cost_types cct1,
                        cst_cost_types cct2
                  WHERE cict.cost_type_id = cicd.cost_type_id
                    AND cict.inventory_item_id = cicd.inventory_item_id
                    AND cict.organization_id = cicd.organization_id
                    AND cicd1.cost_type_id = cct1.cost_type_id
                    AND cct1.cost_type = 'Average'
                    AND cicd.cost_type_id = cct2.cost_type_id
                    AND cct2.cost_type = 'AvgRates'
                    AND cicd1.inventory_item_id = cicd.inventory_item_id
                    AND cicd1.organization_id = cicd.organization_id
                    AND cict.inventory_item_id = xcd.inventory_item_id
                    AND cict.organization_id = xcd.organization_id
                    AND cicd.resource_code = 'OH DUTY') AS oh_duty,
                (SELECT CASE
                           WHEN cicd.basis_type_dsp =
                                                   'Total Value'
                              THEN NVL
                                     (  cicd1.item_cost
                                      * cicd.usage_rate_or_amount
                                      / 100,
                                      0
                                     )
                           ELSE NVL (cicd.usage_rate_or_amount, 0)
                        END oh_nonduty
                   FROM cst_item_cost_type_v cict,
                        cst_item_cost_details_v cicd,
                        cst_item_cost_details_v cicd1,
                        cst_cost_types cct1,
                        cst_cost_types cct2
                  WHERE cict.cost_type_id = cicd.cost_type_id
                    AND cict.inventory_item_id = cicd.inventory_item_id
                    AND cict.organization_id = cicd.organization_id
                    AND cicd1.cost_type_id = cct1.cost_type_id
                    AND cct1.cost_type = 'Average'
                    AND cicd.cost_type_id = cct2.cost_type_id
                    AND cct2.cost_type = 'AvgRates'
                    AND cicd1.inventory_item_id = cicd.inventory_item_id
                    AND cicd1.organization_id = cicd.organization_id
                    AND cict.inventory_item_id = xcd.inventory_item_id
                    AND cict.organization_id = xcd.organization_id
                    AND cicd.resource_code = 'OH NONDUTY') AS oh_nonduty*/
                FROM xxdo.xxdoinv_cir_master_item_cst xcmic, xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco,
                     --starting commented by BT Team on 02/01/2015
                     /*   apps.fnd_flex_values_vl ffv_colors,
                     apps.mtl_item_categories mic,
                     apps.mtl_categories_b mcb,
                     apps.mtl_system_items_b msib*/
                     --Ending commeted by BT Team on 02/01/2015
                     --Starting added by BT Team on 02/01/2015
                     apps.xxd_common_items_v msib
               WHERE     xcd.inventory_item_id = xcmic.inventory_item_id
                     AND xco.organization_id = xcd.organization_id
                     AND msib.organization_id = xcmic.organization_id
                     AND msib.inventory_item_id = xcmic.inventory_item_id
            GROUP BY msib.brand, msib.style_number, msib.color_code,
                     msib.item_type, DECODE (p_summary, 'Y', NULL, msib.item_size), xcd.inventory_item_id,
                     xcd.organization_id
            ORDER BY brand, style, color,
                     sze;

        --starting commented by BT Team on 02/01/2015
        /* AND mic.category_set_id = 1
          AND mic.organization_id = msib.organization_id
          AND mic.inventory_item_id = msib.inventory_item_id
           AND mcb.category_id = mic.category_id
           AND mcb.segment1 LIKE NVL (p_brand, '%')
           AND ffv_colors.flex_value = msib.segment2
           AND ffv_colors.flex_value_set_id = 1003724
      GROUP BY mcb.segment1,
               msib.segment1,
               msib.segment2,
               DECODE (p_summary, 'Y', NULL, msib.segment3)
      ORDER BY brand, style, color, sze;*/
        --Ending commeted by BT Team on 02/01/2015
        CURSOR c_orgs IS
              SELECT mp.organization_id, mp.organization_code, xco.is_master_org_id
                FROM xxdo.xxdoinv_cir_orgs xco, mtl_parameters mp
               WHERE     mp.organization_id = xco.organization_id
                     AND mp.organization_id <> p_master_inv_org_id
            ORDER BY DECODE (xco.is_master_org_id, 1, 0, 1), mp.organization_code;

        /* CURSOR c_details_analysis (      --Cursor commented by BT Team on 21/01/2015
            p_organization_id   NUMBER,
            p_style             VARCHAR2,
            p_color             VARCHAR2,
            p_size              VARCHAR2
         )
         IS
            SELECT                                                 -- Analysis --
                   ROUND (  SUM (xcd.quantity * xcd.sys_item_cost)
                          / DECODE (SUM (xcd.quantity),
                                    0, 1,
                                    SUM (xcd.quantity)
                                   ),
                          2
                         ) AS sys_item_cost,
                   ROUND
                        (  SUM (  xcd.quantity
                                * (  NVL (xcd.trx_freight_cost, 0)
                                   + NVL (xcd.trx_duty_cost, 0)
                                  )
                               )
                         / DECODE (SUM (xcd.quantity), 0, 1, SUM (xcd.quantity)),
                         2
                        ) AS rpt_non_mat_cost,
                   ROUND (  SUM (xcd.quantity * xcd.sys_item_non_mat_cost)
                          / DECODE (SUM (xcd.quantity),
                                    0, 1,
                                    SUM (xcd.quantity)
                                   ),
                          2
                         ) AS sys_non_mat_cost,
                   ROUND
                      (MAX (  apps.xxdoget_item_cost ('FREIGHTRATE',
                                                      xcd.organization_id,
                                                      xcd.inventory_item_id,
                                                      'N'
                                                     )
                            * 100
                           ),
                       2
                      ) AS sys_freight_pct,
                   ROUND
                      (  SUM (DECODE (xcd.tpe,
                                      'B2B', xcd.quantity * xcd.sys_item_cost,
                                      'RD', xcd.quantity
                                       * DECODE (xcd.accrual_missing,
                                                 0, xcd.trx_item_cost,
                                                 xcd.sys_item_cost
                                                ),
                                      0
                                     )
                             )
                       / GREATEST (SUM (DECODE (xcd.tpe,
                                                'B2B', xcd.quantity,
                                                'RD', xcd.quantity,
                                                0
                                               )
                                       ),
                                   1
                                  ),
                       2
                      ) AS sys_macau_intrans_cost,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'B2B', xcd.quantity * xcd.sys_item_cost,
                                    'RD', xcd.quantity
                                     * DECODE (xcd.accrual_missing,
                                               0, xcd.trx_item_cost,
                                               xcd.sys_item_cost
                                              ),
                                    0
                                   )
                           ),
                       2
                      ) AS sys_macau_intrans_val,
                   ROUND (SUM (  DECODE (xcd.tpe, 'ONHAND', xcd.quantity, 0)
                               * xcd.sys_item_cost
                              ),
                          2
                         ) AS sys_macau_onhand_val,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'ONHAND', xcd.quantity * xcd.sys_item_cost,
                                    'B2B', xcd.quantity * xcd.sys_item_cost,
                                    'RD', xcd.quantity
                                     * DECODE (xcd.accrual_missing,
                                               0, xcd.trx_item_cost,
                                               xcd.sys_item_cost
                                              ),
                                    0
                                   )
                           ),
                       2
                      ) AS sys_macau_total_val
              FROM xxdo.xxdoinv_cir_data xcd,
                   xxdo.xxdoinv_cir_orgs xco,
                   xxdo.xxdoinv_cir_master_item_cst xcmic,
                      --start changes by BT Team on 02/01/2015
                   --   apps.mtl_system_items_b msib
                   apps.xxd_common_items_v msib
             --end change by BT Team on 02/01/2015
            WHERE  xco.organization_id = xcd.organization_id
               AND xcmic.inventory_item_id = xcd.inventory_item_id
               --and exists (select null from mtl_system_items_b where organization_id=l_macau_inv_org_id and inventory_item_id=xcd.inventory_item_id)
               AND xcd.organization_id = msib.organization_id
               AND xcd.inventory_item_id = msib.inventory_item_id
               AND msib.organization_id = p_organization_id
                  --start changes by BT Team on 02/01/2015
               /* AND msib.segment1 = p_style
                  AND msib.segment2 = p_color
                  AND msib.segment3 LIKE NVL (p_size, '%');*/
        /* AND msib.style_number = p_style
         AND msib.color_code = p_color
         AND msib.item_size LIKE NVL (p_size, '%');*/

        --end change by BT Team on 02/01/2015
        /* CURSOR c_details_rpt_old (                --Cursor commented by BT Team on 21/01/2015
            p_organization_id   NUMBER,
            p_style             VARCHAR2,
            p_color             VARCHAR2,
            p_size              VARCHAR2
         )
         IS
            SELECT                                                -- Remainder --
                   ROUND (  SUM (  xcd.quantity
                                 * DECODE (l_use_accrual_vals,
                                           'Y', xcd.trx_item_cost,
                                           xcd.itm_item_cost
                                          )
                                )
                          / DECODE (SUM (xcd.quantity),
                                    0, 1,
                                    SUM (xcd.quantity)
                                   ),
                          2
                         ) AS rpt_item_cost,
                   ROUND (  SUM (  xcd.quantity
                                 * DECODE (l_use_accrual_vals,
                                           'Y', xcd.trx_material_cost,
                                           xcd.itm_material_cost
                                          )
                                )
                          / DECODE (SUM (xcd.quantity),
                                    0, 1,
                                    SUM (xcd.quantity)
                                   ),
                          2
                         ) AS rpt_mat_cost,
                   ROUND
                       (  SUM (  xcd.quantity
                               * DECODE (l_use_accrual_vals,
                                         'Y', xcd.trx_freight_cost,
                                         xcd.itm_freight_cost
                                        )
                              )
                        / DECODE (SUM (xcd.quantity), 0, 1, SUM (xcd.quantity)),
                        2
                       ) AS rpt_freight_cost,
                   ROUND (  SUM (  xcd.quantity
                                 * DECODE (l_use_accrual_vals,
                                           'Y', xcd.trx_duty_cost,
                                           xcd.itm_duty_cost
                                          )
                                )
                          / DECODE (SUM (xcd.quantity),
                                    0, 1,
                                    SUM (xcd.quantity)
                                   ),
                          2
                         ) AS rpt_duty_cost,
                   SUM (DECODE (xcd.tpe, 'ONHAND', 0, xcd.quantity)
                       ) AS rpt_intrans_qty,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'ONHAND', 0,
                                      xcd.quantity
                                    * DECODE (l_use_accrual_vals,
                                              'Y', xcd.trx_item_cost,
                                              xcd.itm_item_cost
                                             )
                                   )
                           ),
                       2
                      ) AS rpt_intrans_val,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'ONHAND', 0,
                                      xcd.quantity
                                    * DECODE (l_use_accrual_vals,
                                              'Y', xcd.trx_material_cost,
                                              xcd.itm_material_cost
                                             )
                                   )
                           ),
                       2
                      ) AS rpt_intrans_mat_val,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'ONHAND', 0,
                                      xcd.quantity
                                    * DECODE (l_use_accrual_vals,
                                              'Y', xcd.trx_freight_cost,
                                              xcd.itm_freight_cost
                                             )
                                   )
                           ),
                       2
                      ) AS rpt_intrans_freight_val,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'ONHAND', 0,
                                      xcd.quantity
                                    * DECODE (l_use_accrual_vals,
                                              'Y', xcd.trx_duty_cost,
                                              xcd.itm_duty_cost
                                             )
                                   )
                           ),
                       2
                      ) AS rpt_intrans_duty_val,
                   SUM (DECODE (xcd.tpe, 'ONHAND', xcd.quantity, 0)
                       ) AS rpt_onhand_qty,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'ONHAND', xcd.quantity
                                     * DECODE (l_use_accrual_vals,
                                               'Y', xcd.trx_item_cost,
                                               xcd.itm_item_cost
                                              ),
                                    0
                                   )
                           ),
                       2
                      ) AS rpt_onhand_val,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'ONHAND', xcd.quantity
                                     * DECODE (l_use_accrual_vals,
                                               'Y', xcd.trx_material_cost,
                                               xcd.itm_material_cost
                                              ),
                                    0
                                   )
                           ),
                       2
                      ) AS rpt_onhand_mat_val,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'ONHAND', xcd.quantity
                                     * DECODE (l_use_accrual_vals,
                                               'Y', xcd.trx_freight_cost,
                                               xcd.itm_freight_cost
                                              ),
                                    0
                                   )
                           ),
                       2
                      ) AS rpt_onhand_freight_val,
                   ROUND
                      (SUM (DECODE (xcd.tpe,
                                    'ONHAND', xcd.quantity
                                     * DECODE (l_use_accrual_vals,
                                               'Y', xcd.trx_duty_cost,
                                               xcd.itm_duty_cost
                                              ),
                                    0
                                   )
                           ),
                       2
                      ) AS rpt_onhand_duty_val,
                   SUM (xcd.quantity) AS rpt_total_qty,
                   ROUND (SUM (  xcd.quantity
                               * DECODE (l_use_accrual_vals,
                                         'Y', xcd.trx_item_cost,
                                         xcd.itm_item_cost
                                        )
                              ),
                          2
                         ) AS rpt_total_val,
                   ROUND
                      (SUM (  xcd.quantity
                            * DECODE (l_use_accrual_vals,
                                      'Y', xcd.trx_material_cost,
                                      xcd.itm_material_cost
                                     )
                           ),
                       2
                      ) AS rpt_total_mat_val,
                   ROUND (SUM (xcd.quantity * xcmic.macau_cost),
                          2
                         ) AS rpt_total_macau_val,
                   ROUND
                      (SUM (  xcd.quantity
                            * (  DECODE (l_use_accrual_vals,
                                         'Y', xcd.trx_material_cost,
                                         xcd.itm_material_cost
                                        )
                               - xcmic.macau_cost
                              )
                           ),
                       2
                      ) AS rpt_macau_prof_elim
              FROM xxdo.xxdoinv_cir_data xcd,
                   xxdo.xxdoinv_cir_orgs xco,
                   xxdo.xxdoinv_cir_master_item_cst xcmic,
                   --start changes by BT Team on 02/01/2015
                   --apps.mtl_system_items_b msib
                     apps.xxd_common_items_v msib
                   --end change by BT Team on 02/01/2015
            WHERE  xco.organization_id = xcd.organization_id
               AND xcmic.inventory_item_id = xcd.inventory_item_id
               --and exists (select null from mtl_system_items_b where organization_id=l_macau_inv_org_id and inventory_item_id=xcd.inventory_item_id)
               AND xcd.organization_id = msib.organization_id
               AND xcd.inventory_item_id = msib.inventory_item_id
               AND msib.organization_id = p_organization_id
                 --start changes by BT Team on 02/01/2015
               /* AND msib.segment1 = p_style
                  AND msib.segment2 = p_color
                  AND msib.segment3 LIKE NVL (p_size, '%');*/
        /* AND msib.style_number = p_style
         AND msib.color_code = p_color
         AND msib.item_size LIKE NVL (p_size, '%');*/
        --end change by BT Team on 02/01/2015
        CURSOR c_details_rpt (          --Start Added by BT Team on 14/01/2015
                              p_organization_id NUMBER, p_style VARCHAR2, p_color VARCHAR2
                              , p_size VARCHAR2, p_as_of_date DATE)
        IS
              /* --Start Changes by Arun N Murthy for V2.1

                   SELECT SUM (DECODE (xcd.tpe, 'ONHAND', xcd.quantity, 0))
                             AS onhand_qty,
                          ROUND (AVG (xcmic.macau_cost), 2) AS macau_cost,
                          -- Start changes by BT Technology Team on 22-Jun-2015 for defect#2322
                          SUM (DECODE (xcd.tpe, 'ONHAND', 0, xcd.quantity))
                             AS rpt_intrans_qty -- End changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                               ,
                          gsob.currency_code -- Added by BT Technology Team on 23-Jun-2015 for defect#2322
                     FROM xxdo.xxdoinv_cir_data xcd,
                          xxdo.xxdoinv_cir_orgs xco,
                          xxdo.xxdoinv_cir_master_item_cst xcmic,
                          apps.xxd_common_items_v msib,
                          org_organization_definitions ood,
                          gl_sets_of_books gsob
                    WHERE     xco.organization_id(+) = xcd.organization_id
                          AND xcmic.inventory_item_id(+) = xcd.inventory_item_id
                          AND xcd.organization_id(+) = msib.organization_id
                          AND xcd.inventory_item_id(+) = msib.inventory_item_id
                          -- Added outer Join as per the Defect#615 to get the data for all the orgs if  Region param passed
                          AND msib.organization_id = p_organization_id
                          AND msib.style_number = p_style
                          AND msib.color_code = p_color
                          AND msib.item_size LIKE NVL (p_size, '%')
                          AND ood.organization_id = msib.organization_id
                          AND ood.set_of_books_id = gsob.set_of_books_id
                 GROUP BY gsob.currency_code;     --END Added by BT Team on 14/01/2015
                 */
              SELECT SUM (DECODE (xcd.tpe, 'ONHAND', xcd.quantity, 0)) AS onhand_qty, ROUND (AVG (xcmic.macau_cost), 2) AS macau_cost, -- Start changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                                                                                                                       -- SUM (DECODE (xcd.tpe, 'ONHAND', 0, xcd.quantity))
                                                                                                                                       -- AS rpt_intrans_qty,  --Commented for change 3.2
                                                                                                                                       -- End changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                                                                                                                       SUM (DECODE (xcd.tpe,  'ONHAND', 0,  'RD', 0,  xcd.quantity) -- showkath
                                                                                                                                                                                                   ) AS rpt_intrans_qty, --Added for change 3.2--3.4
                     SUM (DECODE (xcd.tpe, 'RD', xcd.quantity, 0)) AS rec_intrans_qty, --Added for change 3.2
                                                                                       gsob.currency_code-- Added by BT Technology Team on 23-Jun-2015 for defect#2322
                                                                                                         , NVL (SUM (xcd.quantity * xop.avg_mrgn_cst_usd), 0) avg_mrgn_cst_usd,
                     NVL (SUM (xcd.quantity * xop.avg_mrgn_cst_local), 0) avg_mrgn_cst_local
                FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco, xxdo.xxdoinv_cir_master_item_cst xcmic,
                     apps.xxd_common_items_v msib, org_organization_definitions ood, gl_sets_of_books gsob,
                     xxdo.xxd_ont_po_margin_calc_t xop
               WHERE     xco.organization_id(+) = xcd.organization_id
                     AND xcmic.inventory_item_id(+) = xcd.inventory_item_id
                     AND xcd.organization_id(+) = msib.organization_id
                     AND xcd.inventory_item_id(+) = msib.inventory_item_id
                     -- Added outer Join as per the Defect#615 to get the data for all the orgs if  Region param passed
                     AND msib.organization_id = p_organization_id
                     AND msib.style_number = p_style
                     AND msib.color_code = p_color
                     AND msib.item_size LIKE NVL (p_size, '%')
                     AND ood.organization_id = msib.organization_id
                     AND ood.set_of_books_id = gsob.set_of_books_id
                     AND xop.inventory_item_id(+) = xcd.inventory_item_id
                     AND xop.destination_organization_id(+) =
                         xcd.organization_id
                     --                  and xop.transaction_date(+) < p_as_of_date
                     AND NVL (xop.mmt_creation_date(+), '01-DEC-2017') <
                         NVL (p_as_of_date, SYSDATE + 1)
                     AND xop.sequence_number(+) =
                         get_max_seq_value (xop.inventory_item_id(+),
                                            xop.destination_organization_id(+),
                                            p_as_of_date)
                     AND xop.SOURCE(+) <> 'TQ_SO_SHIPMENT'
            GROUP BY gsob.currency_code;
    --END Changes by Arun N Murthy for V2.1
    BEGIN
        IF p_retrieve_from = 'CURRENT'              -- Added as per CCR0008682
        THEN
            IF NVL (p_debug_level, 0) > 0
            THEN
                do_debug_tools.enable_conc_log (p_debug_level);
            END IF;

            do_debug_tools.msg ('+' || l_proc_name);
            do_debug_tools.msg (
                   'p_inv_org_id='
                || p_inv_org_id
                || ', p_region='
                || p_region
                || ', p_as_of_date='
                || NVL (p_as_of_date, '{None}')
                || ', p_brand='
                || p_brand
                || ', p_master_inv_org_id='
                || NVL (TO_CHAR (p_master_inv_org_id), '{None}')
                || ', p_xfer_price_list_id='
                || NVL (TO_CHAR (p_xfer_price_list_id), '{None}')
                || ', p_duty_override='
                || NVL (TO_CHAR (p_duty_override), '{None}')
                || ', p_summary='
                || p_summary
                || ', p_include_analysis='
                || p_include_analysis
                || ', p_use_accrual_vals='
                || p_use_accrual_vals);

            BEGIN
                -- Start Changes by BT Technology Team on 23/01/2014
                SELECT organization_id
                  INTO g_def_macau_inv_org_id
                  FROM mtl_parameters
                 WHERE organization_code = 'MC1';

                -- End Changes by BT Technology Team on 23/01/2014
                IF p_inv_org_id IS NULL AND p_region IS NULL
                THEN
                    raise_application_error (
                        -20001,
                        'Either an inventory organization or region must be specified');
                END IF;

                l_use_accrual_vals   :=
                    NVL (SUBSTR (p_use_accrual_vals, 1, 1), 'Y');

                IF p_as_of_date IS NOT NULL
                THEN
                    l_use_date   :=
                        TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS') + 1;
                ELSE
                    l_use_date   := TRUNC (SYSDATE) + 1;
                END IF;

                IF l_macau_inv_org_id IS NULL
                THEN
                    do_debug_tools.msg (
                        ' obtaining Macau inventory organization');
                    l_macau_inv_org_id   :=
                        TO_NUMBER (
                            fnd_profile.VALUE ('XXDOINV_MACAU_INV_ORG_ID'));

                    IF l_macau_inv_org_id IS NULL
                    THEN
                        l_macau_inv_org_id   := g_def_macau_inv_org_id;
                    END IF;
                END IF;

                do_debug_tools.msg (
                       ' using '
                    || l_macau_inv_org_id
                    || ' for Macau inventory organization');
                do_debug_tools.msg (' loading inventory organizations');

                INSERT INTO xxdo.xxdoinv_cir_orgs (organization_id,
                                                   is_master_org_id,
                                                   primary_cost_method)
                    (SELECT organization_id, 1, primary_cost_method
                       FROM apps.mtl_parameters
                      WHERE organization_id = p_master_inv_org_id);

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' record(s) for the master inventory organization '
                    || p_master_inv_org_id);

                INSERT INTO xxdo.xxdoinv_cir_orgs (organization_id,
                                                   is_master_org_id,
                                                   primary_cost_method)
                    (SELECT organization_id, NULL, primary_cost_method
                       FROM apps.mtl_parameters
                      WHERE     organization_id = NVL (p_inv_org_id, -1)
                            AND organization_id != p_master_inv_org_id
                     UNION
                     SELECT mp.organization_id, NULL, mp.primary_cost_method
                       FROM apps.mtl_parameters mp, hr_all_organization_units haou
                      WHERE     mp.attribute1 = p_region
                            AND mp.organization_id != p_master_inv_org_id
                            AND haou.organization_id = mp.organization_id
                            AND NVL (haou.date_to, SYSDATE + 1) >=
                                TRUNC (SYSDATE)
                            AND p_inv_org_id IS NULL
                            AND EXISTS
                                    (SELECT NULL
                                       FROM mtl_secondary_inventories msi
                                      WHERE msi.organization_id =
                                            mp.organization_id));

                --         fnd_file.put_line (fnd_file.LOG, 'DATE NOT INSERTED INTO THE TABLE');
                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' non-master inventory organization record(s)');
                do_debug_tools.msg (' loading inventory values');

                -- 3.5 calling the load temp table
                IF p_inv_org_id = 126
                THEN
                    BEGIN
                        SELECT category_set_id
                          INTO g_category_set_id
                          FROM mtl_category_sets
                         WHERE category_set_name = g_category_set_name;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            raise_application_error (
                                -20001,
                                'Sales Category Not defined.');
                    END;

                    debug_msg (
                           ' Start temp At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                    do_debug_tools.msg ('  calling load_temp_table.');
                    load_temp_table (p_as_of_date       => l_use_date - 1,
                                     p_inv_org_id       => p_inv_org_id,
                                     p_cost_type_id     => NULL,
                                     x_ret_stat         => l_ret_stat,
                                     x_error_messages   => l_err_messages);
                    do_debug_tools.msg (
                           '  call to load_temp_table returned '
                        || l_ret_stat
                        || '.  '
                        || l_err_messages);
                    debug_msg (
                           ' End temp At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    debug_msg (
                           ' Start Insert At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    debug_msg (
                           ' End Insert At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                END IF;                                --added V1.9 CCR0009519


                --3.5 changes end


                INSERT INTO xxdo.xxdoinv_cir_data (tpe,
                                                   organization_id,
                                                   inventory_item_id,
                                                   quantity,
                                                   rcv_transaction_id,
                                                   trx_material_cost,
                                                   trx_freight_cost,
                                                   trx_duty_cost,
                                                   itm_material_cost)
                    (                                            -- On-Hand --
                       SELECT 'ONHAND'
                                  AS tpe,
                              moqd.organization_id,
                              moqd.inventory_item_id,
                              SUM (moqd.transaction_quantity)
                                  AS quantity,
                              TO_NUMBER (NULL)
                                  AS rcv_transaction_id,
                              apps.xxdoget_item_cost ('MATERIAL', moqd.organization_id, moqd.inventory_item_id
                                                      , 'N')
                                  AS trx_material_cost,
                              TO_NUMBER (NULL)
                                  AS trx_freight_cost,
                              TO_NUMBER (NULL)
                                  AS trx_duty_cost,
                              apps.xxdoget_item_cost ('MATERIAL', moqd.organization_id, moqd.inventory_item_id
                                                      , 'N')
                                  AS itm_material_cost
                         FROM apps.mtl_secondary_inventories msi, apps.mtl_onhand_quantities moqd, xxdo.xxdoinv_cir_orgs xco
                        WHERE     moqd.organization_id = xco.organization_id
                              AND msi.organization_id = moqd.organization_id
                              --                      AND moqd.inventory_item_id = 900326186
                              AND msi.secondary_inventory_name =
                                  moqd.subinventory_code
                              AND msi.asset_inventory = 1
                              AND msi.secondary_inventory_name NOT IN
                                      -- Start Changes by BT Technology Team on 23/01/2014

                                      -- ('QCFAIL', 'QCB', 'REJ', 'REJECTS', 'QCFAIL')
                                      (SELECT ff2.flex_value
                                         FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ff2
                                        WHERE     ff1.flex_value_set_id =
                                                  ff2.flex_value_set_id
                                              AND UPPER (
                                                      ff1.flex_value_set_name) =
                                                  UPPER (
                                                      'XXDO_SECONDARY_INV_NAME')
                                              AND SYSDATE BETWEEN NVL (
                                                                      ff2.start_date_active,
                                                                        SYSDATE
                                                                      - 1)
                                                              AND NVL (
                                                                      ff2.end_date_active,
                                                                        SYSDATE
                                                                      + 1)
                                              AND ff2.enabled_flag = 'Y')
                     -- End changes by BT Technology Team On 23/01/2014
                     GROUP BY moqd.inventory_item_id, moqd.organization_id
                     UNION ALL
                       SELECT 'ONHAND'
                                  AS tpe,
                              mmt.organization_id,
                              mmt.inventory_item_id,
                              SUM (-mmt.primary_quantity)
                                  AS quantity,
                              TO_NUMBER (NULL)
                                  AS rcv_transaction_id,
                              apps.xxdoget_item_cost ('MATERIAL', mmt.organization_id, mmt.inventory_item_id
                                                      , 'N')
                                  AS trx_material_cost,
                              TO_NUMBER (NULL)
                                  AS trx_freight_cost,
                              TO_NUMBER (NULL)
                                  AS trx_duty_cost,
                              apps.xxdoget_item_cost ('MATERIAL', mmt.organization_id, mmt.inventory_item_id
                                                      , 'N')
                                  AS itm_material_cost
                         FROM apps.mtl_secondary_inventories msi, apps.mtl_material_transactions mmt, xxdo.xxdoinv_cir_orgs xco
                        WHERE     mmt.organization_id = xco.organization_id
                              AND mmt.transaction_date >= l_use_date
                              AND msi.organization_id = mmt.organization_id
                              --                      AND mmt.inventory_item_id = 900326186
                              AND msi.secondary_inventory_name =
                                  mmt.subinventory_code
                              AND msi.asset_inventory = 1
                              AND msi.secondary_inventory_name NOT IN
                                      -- Start changes by BT Technology Team On 23/01/2014

                                      -- ('QCFAIL', 'QCB', 'REJ', 'REJECTS', 'QCFAIL')
                                      (SELECT ff2.flex_value
                                         FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ff2
                                        WHERE     ff1.flex_value_set_id =
                                                  ff2.flex_value_set_id
                                              AND UPPER (
                                                      ff1.flex_value_set_name) =
                                                  UPPER (
                                                      'XXDO_SECONDARY_INV_NAME')
                                              AND SYSDATE BETWEEN NVL (
                                                                      ff2.start_date_active,
                                                                        SYSDATE
                                                                      - 1)
                                                              AND NVL (
                                                                      ff2.end_date_active,
                                                                        SYSDATE
                                                                      + 1)
                                              AND ff2.enabled_flag = 'Y')
                     -- End changes by BT Technology Team On 23/01/2014
                     GROUP BY mmt.organization_id, mmt.inventory_item_id
                     UNION ALL
                     SELECT 'B2B'
                                AS tpe,
                            rsl.to_organization_id,
                            rsl.item_id
                                AS inventory_item_id,
                            NVL (
                                (SELECT SUM (rt.quantity)
                                   FROM apps.rcv_transactions rt
                                  WHERE     rt.transaction_type = 'DELIVER'
                                        AND rt.shipment_line_id =
                                            rsl.shipment_line_id
                                        AND rt.transaction_date >= l_use_date),
                                0)
                                AS quantity,
                            TO_NUMBER (NULL)
                                AS rcv_transaction_id,
                            apps.xxdoget_item_cost ('MATERIAL', rsl.to_organization_id, rsl.item_id
                                                    , 'N')
                                AS trx_material_cost,
                            TO_NUMBER (NULL)
                                AS trx_freight_cost,
                            TO_NUMBER (NULL)
                                AS trx_duty_cost,
                            apps.xxdoget_item_cost ('MATERIAL', rsl.to_organization_id, rsl.item_id
                                                    , 'N')
                                AS itm_material_cost
                       FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, xxdo.xxdoinv_cir_orgs xco
                      WHERE     rsl.to_organization_id = xco.organization_id
                            AND rsl.source_document_code = 'REQ'
                            --                    AND rsl.item_id = 900326186
                            AND rsl.shipment_header_id =
                                rsh.shipment_header_id
                            AND rsh.shipped_date < l_use_date
                            AND EXISTS
                                    (SELECT NULL
                                       FROM apps.rcv_transactions rt
                                      WHERE     rt.transaction_type =
                                                'DELIVER'
                                            AND rt.shipment_line_id =
                                                rsl.shipment_line_id
                                            AND rt.transaction_date >=
                                                l_use_date)
                            -- 3.5 changes start
                            AND rsl.to_organization_id NOT IN
                                    (SELECT ood.organization_id
                                       FROM fnd_lookup_values fl, org_organization_definitions ood
                                      WHERE     fl.lookup_type =
                                                'XDO_PO_STAND_RECEIPT_ORGS'
                                            AND fl.meaning =
                                                ood.organization_code) --Added for change 3.3
                     -- 3.5 changes end
                     --   and not exists (select null from do_custom.do_ora_items_all_v doiav where doiav.organization_id = rsl.to_organization_id and doiav.inventory_item_id = rsl.item_id and doiav.product = 'FOWNES')
                     UNION ALL
                     SELECT 'B2B'
                                AS tpe,
                            rsl.to_organization_id,
                            rsl.item_id
                                AS inventory_item_id,
                            rsl.quantity_shipped - rsl.quantity_received
                                AS quantity,
                            TO_NUMBER (NULL)
                                AS rcv_transaction_id,
                            apps.xxdoget_item_cost ('MATERIAL', rsl.to_organization_id, rsl.item_id
                                                    , 'N')
                                AS trx_material_cost,
                            TO_NUMBER (NULL)
                                AS trx_freight_cost,
                            TO_NUMBER (NULL)
                                AS trx_duty_cost,
                            apps.xxdoget_item_cost ('MATERIAL', rsl.to_organization_id, rsl.item_id
                                                    , 'N')
                                AS itm_material_cost
                       FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, xxdo.xxdoinv_cir_orgs xco
                      WHERE     rsl.to_organization_id = xco.organization_id
                            AND rsl.source_document_code = 'REQ'
                            --                    AND rsl.item_id = 900326186
                            AND rsh.shipment_header_id =
                                rsl.shipment_header_id
                            AND rsh.shipped_date < l_use_date
                            AND quantity_received < quantity_shipped
                            -- 3.5 changes start
                            AND rsl.to_organization_id NOT IN
                                    (SELECT ood.organization_id
                                       FROM fnd_lookup_values fl, org_organization_definitions ood
                                      WHERE     fl.lookup_type =
                                                'XDO_PO_STAND_RECEIPT_ORGS'
                                            AND fl.meaning =
                                                ood.organization_code)
                     -- 3.5 changes end
                     --   and not exists (select null from do_custom.do_ora_items_all_v doiav where doiav.organization_id = rsl.to_organization_id and doiav.inventory_item_id = rsl.item_id and doiav.product = 'FOWNES')
                     UNION ALL
                       SELECT 'RD'
                                  AS tpe,
                              organization_id,
                              inventory_item_id,
                              SUM (quantity)
                                  AS quantity,
                              rcv_transaction_id,
                              NVL (
                                  (SELECT MAX (po_unit_price)
                                     FROM xxdo.xxdopo_accrual_lines xal
                                    WHERE xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id),
                                  apps.xxdoget_item_cost ('MATERIAL', alpha.organization_id, alpha.inventory_item_id
                                                          , 'N'))
                                  AS trx_material_cost,
                              (SELECT amount_total / quantity_total
                                 FROM xxdo.xxdopo_accrual_lines xal
                                WHERE     xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id
                                      AND xal.accrual_type = 'Freight')
                                  AS trx_freight_cost,
                              (SELECT amount_total / quantity_total
                                 FROM xxdo.xxdopo_accrual_lines xal
                                WHERE     xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id
                                      AND xal.accrual_type = 'Duty')
                                  AS trx_duty_cost,
                              apps.xxdoget_item_cost ('MATERIAL', alpha.organization_id, alpha.inventory_item_id
                                                      , 'N')
                                  AS itm_material_cost
                         FROM (  SELECT ms.to_organization_id AS organization_id,
                                        pol.item_id AS inventory_item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('ACCEPT', 'REJECT', 'TRANSFER')
                                            THEN
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    ms.rcv_transaction_id)
                                            ELSE
                                                ms.rcv_transaction_id
                                        END AS rcv_transaction_id,
                                        SUM (ms.to_org_primary_quantity) AS quantity
                                   FROM mtl_supply ms, rcv_transactions rt, po_lines_all pol,
                                        xxdo.xxdoinv_cir_orgs xco
                                  WHERE     ms.to_organization_id =
                                            xco.organization_id
                                        AND ms.supply_type_code = 'RECEIVING'
                                        --                                AND pol.item_id = 900326186
                                        AND rt.transaction_id =
                                            ms.rcv_transaction_id
                                        AND NVL (rt.consigned_flag, 'N') = 'N'
                                        AND rt.source_document_code = 'PO'
                                        AND pol.po_line_id = rt.po_line_id
                               GROUP BY ms.to_organization_id,
                                        pol.item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('ACCEPT', 'REJECT', 'TRANSFER')
                                            THEN
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    ms.rcv_transaction_id)
                                            ELSE
                                                ms.rcv_transaction_id
                                        END
                               UNION ALL
                                 SELECT rt.organization_id,
                                        pol.item_id AS inventory_item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('RECEIVE', 'MATCH')
                                            THEN
                                                rt.transaction_id
                                            ELSE
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    rt.transaction_id)
                                        END AS rcv_transaction_id,
                                        SUM (
                                            DECODE (
                                                rt.transaction_type,
                                                'RECEIVE', -1 * rt.primary_quantity,
                                                'DELIVER', 1 * rt.primary_quantity,
                                                'RETURN TO RECEIVING', -1 * rt.primary_quantity,
                                                'RETURN TO VENDOR', DECODE (
                                                                        parent_rt.transaction_type,
                                                                        'UNORDERED', 0,
                                                                        1 * rt.primary_quantity),
                                                'MATCH', -1 * rt.primary_quantity,
                                                'CORRECT', DECODE (
                                                               parent_rt.transaction_type,
                                                               'UNORDERED', 0,
                                                               'RECEIVE', -1 * rt.primary_quantity,
                                                               'DELIVER', 1 * rt.primary_quantity,
                                                               'RETURN TO RECEIVING',   -1
                                                                                      * rt.primary_quantity,
                                                               'RETURN TO VENDOR', DECODE (
                                                                                       grparent_rt.transaction_type,
                                                                                       'UNORDERED', 0,
                                                                                         1
                                                                                       * rt.primary_quantity),
                                                               'MATCH', -1 * rt.primary_quantity,
                                                               0),
                                                0)) quantity
                                   FROM rcv_transactions rt, rcv_transactions parent_rt, rcv_transactions grparent_rt,
                                        po_lines_all pol, xxdo.xxdoinv_cir_orgs xco
                                  WHERE     rt.organization_id =
                                            xco.organization_id
                                        AND NVL (rt.consigned_flag, 'N') = 'N'
                                        AND NVL (rt.dropship_type_code, 3) = 3
                                        --                                AND pol.item_id = 900326186
                                        AND rt.transaction_date > l_use_date
                                        AND rt.transaction_type IN
                                                ('RECEIVE', 'DELIVER', 'RETURN TO RECEIVING',
                                                 'RETURN TO VENDOR', 'CORRECT', 'MATCH')
                                        AND rt.source_document_code = 'PO'
                                        AND DECODE (rt.parent_transaction_id,
                                                    -1, NULL,
                                                    0, NULL,
                                                    rt.parent_transaction_id) =
                                            parent_rt.transaction_id(+)
                                        AND DECODE (
                                                parent_rt.parent_transaction_id,
                                                -1, NULL,
                                                0, NULL,
                                                parent_rt.parent_transaction_id) =
                                            grparent_rt.transaction_id(+)
                                        AND pol.po_line_id = rt.po_line_id
                                        AND rt.organization_id NOT IN
                                                (SELECT ood.organization_id
                                                   FROM fnd_lookup_values fl, org_organization_definitions ood
                                                  WHERE     fl.lookup_type =
                                                            'XDO_PO_STAND_RECEIPT_ORGS'
                                                        AND fl.meaning =
                                                            ood.organization_code)
                               --Added for change 3.3
                               GROUP BY rt.organization_id,
                                        pol.item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('RECEIVE', 'MATCH')
                                            THEN
                                                rt.transaction_id
                                            ELSE
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    rt.transaction_id)
                                        END
                                 HAVING SUM (
                                            DECODE (
                                                rt.transaction_type,
                                                'RECEIVE', -1 * rt.primary_quantity,
                                                'DELIVER', 1 * rt.primary_quantity,
                                                'RETURN TO RECEIVING', -1 * rt.primary_quantity,
                                                'RETURN TO VENDOR', DECODE (
                                                                        parent_rt.transaction_type,
                                                                        'UNORDERED', 0,
                                                                        1 * rt.primary_quantity),
                                                'MATCH', -1 * rt.primary_quantity,
                                                'CORRECT', DECODE (
                                                               parent_rt.transaction_type,
                                                               'UNORDERED', 0,
                                                               'RECEIVE',   -1
                                                                          * rt.primary_quantity,
                                                               'DELIVER',   1
                                                                          * rt.primary_quantity,
                                                               'RETURN TO RECEIVING',   -1
                                                                                      * rt.primary_quantity,
                                                               'RETURN TO VENDOR', DECODE (
                                                                                       grparent_rt.transaction_type,
                                                                                       'UNORDERED', 0,
                                                                                         1
                                                                                       * rt.primary_quantity),
                                                               'MATCH', -1 * rt.primary_quantity,
                                                               0),
                                                0)) <>
                                        0) alpha
                     GROUP BY organization_id, inventory_item_id, rcv_transaction_id
                       HAVING SUM (quantity) != 0
                     /*Added below for change 3.2*/
                     UNION ALL
                       SELECT 'B2B'
                                  AS tpe,
                              organization_id,
                              inventory_item_id,
                              SUM (quantity)
                                  AS quantity,
                              rcv_transaction_id,
                              NVL (
                                  (SELECT MAX (po_unit_price)
                                     FROM xxdo.xxdopo_accrual_lines xal
                                    WHERE xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id),
                                  apps.xxdoget_item_cost ('MATERIAL', alpha.organization_id, alpha.inventory_item_id
                                                          , 'N'))
                                  AS trx_material_cost,
                              (SELECT amount_total / quantity_total
                                 FROM xxdo.xxdopo_accrual_lines xal
                                WHERE     xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id
                                      AND xal.accrual_type = 'Freight')
                                  AS trx_freight_cost,
                              (SELECT amount_total / quantity_total
                                 FROM xxdo.xxdopo_accrual_lines xal
                                WHERE     xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id
                                      AND xal.accrual_type = 'Duty')
                                  AS trx_duty_cost,
                              apps.xxdoget_item_cost ('MATERIAL', alpha.organization_id, alpha.inventory_item_id
                                                      , 'N')
                                  AS itm_material_cost
                         FROM (  SELECT ms.to_organization_id AS organization_id,
                                        pol.item_id AS inventory_item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('ACCEPT', 'REJECT', 'TRANSFER')
                                            THEN
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    ms.rcv_transaction_id)
                                            ELSE
                                                ms.rcv_transaction_id
                                        END AS rcv_transaction_id,
                                        SUM (ms.to_org_primary_quantity) AS quantity
                                   FROM mtl_supply ms, rcv_transactions rt, po_requisition_lines_all pol,
                                        xxdo.xxdoinv_cir_orgs xco
                                  WHERE     ms.to_organization_id =
                                            xco.organization_id
                                        AND ms.supply_type_code = 'RECEIVING'
                                        --                                AND pol.item_id = 900326186
                                        AND rt.transaction_id =
                                            ms.rcv_transaction_id
                                        AND NVL (rt.consigned_flag, 'N') = 'N'
                                        AND rt.source_document_code = 'REQ'
                                        AND pol.requisition_line_id =
                                            rt.requisition_line_id
                                        -- 3.5 changes start
                                        AND rt.organization_id NOT IN
                                                (SELECT ood.organization_id
                                                   FROM fnd_lookup_values fl, org_organization_definitions ood
                                                  WHERE     fl.lookup_type =
                                                            'XDO_PO_STAND_RECEIPT_ORGS'
                                                        AND fl.meaning =
                                                            ood.organization_code)
                               -- 3.5 changes end
                               GROUP BY ms.to_organization_id,
                                        pol.item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('ACCEPT', 'REJECT', 'TRANSFER')
                                            THEN
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    ms.rcv_transaction_id)
                                            ELSE
                                                ms.rcv_transaction_id
                                        END/* UNION ALL
                                              SELECT rt.organization_id,
                                                     pol.item_id AS inventory_item_id,
                                                     CASE
                                                        WHEN NVL (rt.transaction_type, ' ') IN
                                                                ('RECEIVE', 'MATCH')
                                                        THEN
                                                           rt.transaction_id
                                                        ELSE
                                                           apps.cst_inventory_pvt.get_parentreceivetxn (
                                                              rt.transaction_id)
                                                     END
                                                        AS rcv_transaction_id,
                                                     SUM (
                                                        DECODE (
                                                           rt.transaction_type,
                                                           'RECEIVE', -1 * rt.primary_quantity,
                                                           'DELIVER', 1 * rt.primary_quantity,
                                                           'RETURN TO RECEIVING',   -1
                                                                                  * rt.primary_quantity,
                                                           'RETURN TO VENDOR', DECODE (
                                                                                  parent_rt.transaction_type,
                                                                                  'UNORDERED', 0,
                                                                                    1
                                                                                  * rt.primary_quantity),
                                                           'MATCH', -1 * rt.primary_quantity,
                                                           'CORRECT', DECODE (
                                                                         parent_rt.transaction_type,
                                                                         'UNORDERED', 0,
                                                                         'RECEIVE',   -1
                                                                                    * rt.primary_quantity,
                                                                         'DELIVER',   1
                                                                                    * rt.primary_quantity,
                                                                         'RETURN TO RECEIVING',   -1
                                                                                                * rt.primary_quantity,
                                                                         'RETURN TO VENDOR', DECODE (
                                                                                                grparent_rt.transaction_type,
                                                                                                'UNORDERED', 0,
                                                                                                  1
                                                                                                * rt.primary_quantity),
                                                                         'MATCH',   -1
                                                                                  * rt.primary_quantity,
                                                                         0),
                                                           0))
                                                        quantity
                                                FROM rcv_transactions rt,
                                                     rcv_transactions parent_rt,
                                                     rcv_transactions grparent_rt,
                                                     po_requisition_lines_all pol,
                                                     xxdo.xxdoinv_cir_orgs xco
                                               WHERE     rt.organization_id = xco.organization_id
                                                     AND NVL (rt.consigned_flag, 'N') = 'N'
                                                     AND NVL (rt.dropship_type_code, 3) = 3
                     --                                AND pol.item_id = 900326186
                                                     AND rt.transaction_date > l_use_date
                                                     AND rt.transaction_type IN
                                                            (--'RECEIVE',
                                                             'DELIVER',
                                                             'RETURN TO RECEIVING',
                                                             'RETURN TO VENDOR',
                                                             'CORRECT',
                                                             'MATCH')
                                                     AND rt.source_document_code = 'REQ'
                                                     AND DECODE (rt.parent_transaction_id,
                                                                 -1, NULL,
                                                                 0, NULL,
                                                                 rt.parent_transaction_id) =
                                                            parent_rt.transaction_id(+)
                                                     AND DECODE (parent_rt.parent_transaction_id,
                                                                 -1, NULL,
                                                                 0, NULL,
                                                                 parent_rt.parent_transaction_id) =
                                                            grparent_rt.transaction_id(+)
                                                     AND pol.requisition_line_id = rt.requisition_line_id
                                            GROUP BY rt.organization_id,
                                                     pol.item_id,
                                                     CASE
                                                        WHEN NVL (rt.transaction_type, ' ') IN
                                                                ('RECEIVE', 'MATCH')
                                                        THEN
                                                           rt.transaction_id
                                                        ELSE
                                                           apps.cst_inventory_pvt.get_parentreceivetxn (
                                                              rt.transaction_id)
                                                     END
                                              HAVING SUM (
                                                        DECODE (
                                                           rt.transaction_type,
                                                           'RECEIVE', -1 * rt.primary_quantity,
                                                           'DELIVER', 1 * rt.primary_quantity,
                                                           'RETURN TO RECEIVING',   -1
                                                                                  * rt.primary_quantity,
                                                           'RETURN TO VENDOR', DECODE (
                                                                                  parent_rt.transaction_type,
                                                                                  'UNORDERED', 0,
                                                                                    1
                                                                                  * rt.primary_quantity),
                                                           'MATCH', -1 * rt.primary_quantity,
                                                           'CORRECT', DECODE (
                                                                         parent_rt.transaction_type,
                                                                         'UNORDERED', 0,
                                                                         'RECEIVE',   -1
                                                                                    * rt.primary_quantity,
                                                                         'DELIVER',   1
                                                                                    * rt.primary_quantity,
                                                                         'RETURN TO RECEIVING',   -1
                                                                                                * rt.primary_quantity,
                                                                         'RETURN TO VENDOR', DECODE (
                                                                                                grparent_rt.transaction_type,
                                                                                                'UNORDERED', 0,
                                                                                                  1
                                                                                                * rt.primary_quantity),
                                                                         'MATCH',   -1
                                                                                  * rt.primary_quantity,
                                                                         0),
                                                           0)) <> 0*/
                                           --Commneted for change 3.3
                                           ) alpha
                     GROUP BY organization_id, inventory_item_id, rcv_transaction_id
                       HAVING SUM (quantity) != 0
                     -- )
                     -- 3.5 changes start
                     UNION ALL
                     SELECT 'B2B'
                                AS tpe,
                            rsl.to_organization_id,
                            rsl.item_id
                                AS inventory_item_id,
                            qty.rollback_qty
                                AS quantity,
                            TO_NUMBER (NULL)
                                AS rcv_transaction_id,
                            apps.xxdoget_item_cost ('MATERIAL', rsl.to_organization_id, rsl.item_id
                                                    , 'N')
                                AS trx_material_cost,
                            TO_NUMBER (NULL)
                                AS trx_freight_cost,
                            TO_NUMBER (NULL)
                                AS trx_duty_cost,
                            apps.xxdoget_item_cost ('MATERIAL', rsl.to_organization_id, rsl.item_id
                                                    , 'N')
                                AS itm_material_cost
                       FROM cst_item_list_temp item, cst_inv_qty_temp qty, xxd_common_items_v citv,
                            mtl_parameters mp, cst_inv_cost_temp COST, rcv_shipment_lines rsl,
                            rcv_shipment_headers rsh, xxdo.xxdoinv_cir_orgs xco
                      WHERE     qty.inventory_item_id =
                                item.inventory_item_id
                            AND qty.cost_type_id = item.cost_type_id
                            AND qty.organization_id = xco.organization_id
                            AND citv.organization_id = qty.organization_id
                            AND citv.inventory_item_id =
                                qty.inventory_item_id
                            AND citv.category_set_id = 1
                            AND mp.organization_id = qty.organization_id
                            AND COST.organization_id(+) = qty.organization_id
                            AND COST.inventory_item_id(+) =
                                qty.inventory_item_id
                            AND COST.cost_type_id(+) = qty.cost_type_id
                            AND rsl.shipment_line_id = qty.shipment_line_id
                            AND rsh.shipment_header_id =
                                rsl.shipment_header_id
                            AND (rsh.shipped_date IS NOT NULL AND rsh.shipped_date < TO_DATE (NVL (l_use_date, SYSDATE)))
                            AND rsl.creation_date <
                                TO_DATE (NVL (l_use_date, TRUNC (SYSDATE)))
                            AND rsl.to_organization_id IN
                                    (SELECT ood.organization_id
                                       FROM fnd_lookup_values fl, org_organization_definitions ood
                                      WHERE     fl.lookup_type =
                                                'XDO_PO_STAND_RECEIPT_ORGS'
                                            AND fl.meaning =
                                                ood.organization_code)-- 3.5 changes end

                                                                      );


                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' inventory value record(s)');

                UPDATE xxdo.xxdoinv_cir_data
                   SET accrual_missing   = 1
                 WHERE     tpe = 'RD'
                       AND (trx_freight_cost IS NULL OR trx_duty_cost IS NULL);

                do_debug_tools.msg (
                       ' updated '
                    || SQL%ROWCOUNT
                    || ' receive/deliver record(s) with missing accruals');
                do_debug_tools.msg (
                    ' loading master organization item costs');

                INSERT INTO xxdo.xxdoinv_cir_master_item_cst (
                                organization_id,
                                inventory_item_id,
                                material_cost,
                                freight_cost,
                                duty_cost,
                                duty_rate,
                                macau_cost,
                                is_direct_import_sku)
                    (SELECT DISTINCT
                            xco.organization_id,
                            xcd.inventory_item_id,
                            apps.xxdoget_item_cost ('MATERIAL', xco.organization_id, xcd.inventory_item_id
                                                    , 'N')
                                AS material_cost,
                            CASE
                                WHEN xco.primary_cost_method = 1
                                THEN
                                    -- Standard Cost --
                                    apps.xxdoget_item_cost ('STDFREIGHT', xco.organization_id, xcd.inventory_item_id
                                                            , 'N')
                                ELSE
                                    -- Layered Cost --
                                    DECODE (apps.xxdoget_item_cost ('FIFOFREIGHT', xco.organization_id, xcd.inventory_item_id
                                                                    , 'N'),
                                            0,   apps.xxdoget_item_cost (
                                                     'FREIGHTRATE',
                                                     xco.organization_id,
                                                     xcd.inventory_item_id,
                                                     'N')
                                               * apps.xxdoget_item_cost (
                                                     'MATERIAL',
                                                     xco.organization_id,
                                                     xcd.inventory_item_id,
                                                     'N'),
                                            apps.xxdoget_item_cost ('FIFOFREIGHT', xco.organization_id, xcd.inventory_item_id
                                                                    , 'N'))
                            END
                                AS freight_cost,
                            CASE
                                WHEN xco.primary_cost_method = 1
                                THEN
                                    -- Standard Cost --
                                    DECODE (apps.xxdoget_item_cost ('STDDUTY', xco.organization_id, xcd.inventory_item_id
                                                                    , 'N'),
                                            0,   (p_duty_override / 100)
                                               * apps.xxdoget_item_cost (
                                                     'MATERIAL',
                                                     xco.organization_id,
                                                     xcd.inventory_item_id,
                                                     'N'),
                                            apps.xxdoget_item_cost ('STDDUTY', xco.organization_id, xcd.inventory_item_id
                                                                    , 'N'))
                                ELSE
                                    -- Layered Cost --
                                    DECODE (apps.xxdoget_item_cost ('FIFODUTY', xco.organization_id, xcd.inventory_item_id
                                                                    , 'N'),
                                            0,   (p_duty_override / 100)
                                               * apps.xxdoget_item_cost (
                                                     'MATERIAL',
                                                     xco.organization_id,
                                                     xcd.inventory_item_id,
                                                     'N'),
                                            apps.xxdoget_item_cost ('FIFODUTY', xco.organization_id, xcd.inventory_item_id
                                                                    , 'N'))
                            END
                                AS duty_cost,
                            DECODE (apps.xxdoget_item_cost ('EURATE', xco.organization_id, xcd.inventory_item_id
                                                            , 'N'),
                                    0, (p_duty_override / 100),
                                    apps.xxdoget_item_cost ('EURATE', xco.organization_id, xcd.inventory_item_id
                                                            , 'N'))
                                AS duty_rate,
                            -- Start Commented for Incident INC0299210
                            --NVL (
                            --   (SELECT msib_macau.list_price_per_unit
                            --      -- FROM apps.mtl_system_items_b msib_macau                    --commented by BT Team on 02/01/2015
                            --      FROM apps.xxd_common_items_v msib_macau
                            --     WHERE     msib_macau.organization_id =
                            --                  l_macau_inv_org_id
                            --           AND msib_macau.inventory_item_id =
                            --                  xcd.inventory_item_id),
                            --   0)
                            --   AS macau_cost,
                            -- End Commented for Incident INC0299210
                            -- Start for Incident INC0299210
                            DECODE (
                                apps.xxdoget_item_cost ('ITEMCOST', l_macau_inv_org_id, xcd.inventory_item_id
                                                        , 'N'),
                                0, NVL (
                                       (SELECT msib_macau.list_price_per_unit
                                          FROM apps.mtl_system_items_b msib_macau
                                         WHERE     msib_macau.organization_id =
                                                   l_macau_inv_org_id
                                               AND msib_macau.inventory_item_id =
                                                   xcd.inventory_item_id),
                                       0),
                                apps.xxdoget_item_cost ('ITEMCOST', l_macau_inv_org_id, xcd.inventory_item_id
                                                        , 'N'))
                                AS macau_cost,
                            -- End for Incident INC0299210
                            NVL (
                                (SELECT MAX ('Y')
                                   -- FROM apps.mtl_system_items_b msib                             --commented by BT Team on 02/01/2015
                                   FROM apps.xxd_common_items_v msib
                                  --added by BT team on 02/01/2015
                                  WHERE     msib.organization_id =
                                            xcd.organization_id
                                        AND msib.inventory_item_id =
                                            xcd.inventory_item_id
                                        --  AND SUBSTR (msib.segment1, 1, 2) IN                                             --commented by BT Team on 02/01/2015
                                        AND SUBSTR (msib.style_number, 1, 2) IN
                                                ('U0', 'U1', 'U2',
                                                 'U3', 'U4', 'U5',
                                                 'U6', 'U7', 'U8',
                                                 'U9')-- Replicated from old CIR logic to identify FOWNES SKU's --
                                                      ),
                                'N')
                                AS is_direct_import_sku
                       FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco
                      WHERE xco.is_master_org_id = 1);

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' master organization item cost record(s)');
                do_debug_tools.msg (' loading transaction freight costs');

                UPDATE (SELECT xcd.trx_freight_cost
                                   AS trx_freight_cost,
                               apps.xxdoget_item_cost (DECODE (xco.primary_cost_method, 1, 'STDFREIGHT', 'FIFOFREIGHT'), xcd.organization_id, xcd.inventory_item_id
                                                       , 'N')
                                   AS org_freight_cost,
                               xcmic.freight_cost
                                   AS master_freight_cost,
                                 apps.xxdoget_item_cost ('FREIGHTRATE', xcmic.organization_id, xcmic.inventory_item_id
                                                         , 'N')
                               * xcd.trx_material_cost
                                   AS calc_trx_freight_cost
                          FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco, xxdo.xxdoinv_cir_master_item_cst xcmic
                         WHERE     xcmic.inventory_item_id =
                                   xcd.inventory_item_id
                               AND NVL (xcd.trx_freight_cost, 0) <= 0
                               AND xco.organization_id = xcd.organization_id)
                   SET trx_freight_cost   =
                           CASE
                               WHEN org_freight_cost > master_freight_cost
                               THEN
                                   org_freight_cost
                               ELSE
                                   DECODE (master_freight_cost,
                                           0, calc_trx_freight_cost,
                                           master_freight_cost)
                           END;

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' transaction freight cost record(s)');
                do_debug_tools.msg (' loading transaction duty costs');

                UPDATE (SELECT xcd.trx_duty_cost
                                   AS trx_duty_cost,
                               apps.xxdoget_item_cost (DECODE (xco.primary_cost_method, 1, 'STDDUTY', 'FIFODUTY'), xcd.organization_id, xcd.inventory_item_id
                                                       , 'N')
                                   AS org_duty_cost,
                               xcmic.duty_cost
                                   AS master_duty_cost,
                                 xcmic.duty_rate
                               * DECODE (
                                     xcmic.is_direct_import_sku,
                                     'Y', xcmic.material_cost,
                                     xcmic.macau_cost + xcmic.freight_cost)
                                   AS calc_trx_duty_cost
                          FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco, xxdo.xxdoinv_cir_master_item_cst xcmic
                         WHERE     xcmic.inventory_item_id =
                                   xcd.inventory_item_id
                               AND NVL (xcd.trx_duty_cost, 0) <= 0
                               AND xco.organization_id = xcd.organization_id)
                   SET trx_duty_cost   =
                           CASE
                               WHEN org_duty_cost > master_duty_cost
                               THEN
                                   org_duty_cost
                               ELSE
                                   DECODE (master_duty_cost,
                                           0, calc_trx_duty_cost,
                                           master_duty_cost)
                           END;

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' transaction duty cost record(s)');
                do_debug_tools.msg (' loading item freight costs');

                UPDATE (SELECT xcd.itm_freight_cost
                                   AS itm_freight_cost,
                               apps.xxdoget_item_cost (DECODE (xco.primary_cost_method, 1, 'STDFREIGHT', 'FIFOFREIGHT'), xcd.organization_id, xcd.inventory_item_id
                                                       , 'N')
                                   AS org_freight_cost,
                               xcmic.freight_cost
                                   AS master_freight_cost,
                                 apps.xxdoget_item_cost ('FREIGHTRATE', xcmic.organization_id, xcmic.inventory_item_id
                                                         , 'N')
                               * xcd.itm_material_cost
                                   AS calc_itm_freight_cost
                          FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco, xxdo.xxdoinv_cir_master_item_cst xcmic
                         WHERE     xcmic.inventory_item_id =
                                   xcd.inventory_item_id
                               AND NVL (xcd.itm_freight_cost, 0) <= 0
                               AND xco.organization_id = xcd.organization_id)
                   SET itm_freight_cost   =
                           CASE
                               WHEN org_freight_cost > master_freight_cost
                               THEN
                                   org_freight_cost
                               ELSE
                                   DECODE (master_freight_cost,
                                           0, calc_itm_freight_cost,
                                           master_freight_cost)
                           END;

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' item freight cost record(s)');
                do_debug_tools.msg (' loading item duty costs');

                UPDATE (SELECT xcd.itm_duty_cost
                                   AS itm_duty_cost,
                               apps.xxdoget_item_cost (DECODE (xco.primary_cost_method, 1, 'STDDUTY', 'FIFODUTY'), xcd.organization_id, xcd.inventory_item_id
                                                       , 'N')
                                   AS org_duty_cost,
                               xcmic.duty_cost
                                   AS master_duty_cost,
                                 xcmic.duty_rate
                               * DECODE (
                                     xcmic.is_direct_import_sku,
                                     'Y', xcmic.material_cost,
                                     xcmic.macau_cost + xcmic.freight_cost)
                                   AS calc_itm_duty_cost
                          FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco, xxdo.xxdoinv_cir_master_item_cst xcmic
                         WHERE     xcmic.inventory_item_id =
                                   xcd.inventory_item_id
                               AND NVL (xcd.itm_duty_cost, 0) <= 0
                               AND xco.organization_id = xcd.organization_id)
                   SET itm_duty_cost   =
                           CASE
                               WHEN org_duty_cost > master_duty_cost
                               THEN
                                   org_duty_cost
                               ELSE
                                   DECODE (master_duty_cost,
                                           0, calc_itm_duty_cost,
                                           master_duty_cost)
                           END;

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' item freight duty cost record(s)');
                do_debug_tools.msg (' calculating landed costs');

                UPDATE xxdo.xxdoinv_cir_data
                   SET trx_item_cost   =
                             NVL (trx_material_cost, 0)
                           + NVL (trx_freight_cost, 0)
                           + NVL (trx_duty_cost, 0),
                       itm_item_cost   =
                             NVL (itm_material_cost, 0)
                           + NVL (itm_freight_cost, 0)
                           + NVL (itm_duty_cost, 0),
                       sys_item_cost   =
                             NVL (itm_material_cost, 0)
                           + NVL (apps.xxdoget_item_cost ('NONMATERIAL', organization_id, inventory_item_id
                                                          , 'N'),
                                  0),
                       sys_item_non_mat_cost   =
                           NVL (apps.xxdoget_item_cost ('NONMATERIAL', organization_id, inventory_item_id
                                                        , 'N'),
                                0);

                UPDATE xxdo.xxdoinv_cir_master_item_cst
                   SET item_cost = NVL (material_cost, 0) + NVL (freight_cost, 0) + NVL (duty_cost, 0);

                do_debug_tools.msg (' gathering statistics');
                SYS.DBMS_STATS.gather_table_stats (
                    ownname   => 'XXDO',
                    tabname   => 'XXDOINV_CIR_ORGS',
                    CASCADE   => TRUE);
                SYS.DBMS_STATS.gather_table_stats (
                    ownname   => 'XXDO',
                    tabname   => 'XXDOINV_CIR_DATA',
                    CASCADE   => TRUE);
                SYS.DBMS_STATS.gather_table_stats (
                    ownname   => 'XXDO',
                    tabname   => 'XXDOINV_CIR_MASTER_ITEM_CST',
                    CASCADE   => TRUE);
                do_debug_tools.msg (
                    ' obtaining organization code for master inventory organization');

                SELECT mp.organization_code
                  INTO l_org_code
                  FROM xxdo.xxdoinv_cir_orgs xco, mtl_parameters mp
                 WHERE     mp.organization_id = xco.organization_id
                       AND xco.is_master_org_id = 1;

                do_debug_tools.msg (
                       ' found organization code '
                    || l_org_code
                    || ' for master inventory organization');

                BEGIN
                    SELECT organization_name
                      INTO l_inv_org
                      FROM org_organization_definitions
                     WHERE organization_id = p_inv_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_inv_org   := p_inv_org_id;
                END;

                BEGIN
                    SELECT organization_name
                      INTO l_inv_mst_org
                      FROM org_organization_definitions
                     WHERE organization_id = p_master_inv_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_inv_mst_org   := p_master_inv_org_id;
                END;

                fnd_file.put (
                    fnd_file.output,
                       'Global Inventory Value Report-Deckers :'
                    || CHR (10)
                    || ' Retrive From : '
                    || p_retrieve_from
                    || CHR (10)
                    || ' Inventory Organization: '
                    || l_inv_org
                    || CHR (10)
                    || ' Region: '
                    || p_region
                    || CHR (10)
                    || ' Roll Back Date: '
                    || NVL (p_as_of_date, '{None}')
                    || CHR (10)
                    || ' Brand: '
                    || p_brand
                    || CHR (10)
                    || ' Master Inventory organization: '
                    || NVL (l_inv_mst_org, '{None}')
                    || CHR (10)
                    || ' Transfer price List:'
                    || NVL (TO_CHAR (p_xfer_price_list_id), '{None}')
                    || CHR (10)
                    || ' Summary: '
                    || p_summary
                    || CHR (10)
                    || ' From Currency (TO USD): '
                    || p_from_currency
                    || CHR (10)
                    || ' Elimination Rate Type: '
                    || p_elimination_rate_type
                    || CHR (10)
                    || ' Elimination Rate : '
                    || p_elimination_rate
                    || CHR (10)
                    || ' USER Rate (TO USD) : '
                    || p_user_rate
                    || CHR (10)
                    || ' TQ (For Japan): '
                    || p_tq_japan
                    || CHR (10)
                    || ' Markup Rate Type: '
                    || p_markup_rate_type
                    || CHR (10)
                    || ' USER Rate  (JPY TO USD)  : '
                    || p_jpy_user_rate
                    || CHR (10)
                    || 'Include Layered Margin : '
                    || p_layered_mrgn
                    || CHR (10));
                fnd_file.put (
                    fnd_file.output,
                       'Style'
                    || g_delim_char
                    || 'Color code'
                    || g_delim_char
                    || 'Size'
                    || g_delim_char
                    || 'Description'
                    || g_delim_char
                    --|| 'Division'
                    --|| g_delim_char
                    || 'Brand'
                    || g_delim_char
                    || 'Department'
                    || g_delim_char
                    || 'Class'
                    || g_delim_char
                    || 'Sub class'
                    || g_delim_char
                    -- CR#92 added Item Type BT Technology Team
                    || 'Item Type'
                    --|| g_delim_char
                    --|| 'Master Style'
                    --|| g_delim_char
                    --|| 'style Option'
                    || g_delim_char
                    || 'Intro Season'
                    || g_delim_char
                    || 'Current Season');

                -- Start Changes by BT Tecgnology Team as below columns are not required in the new output format
                /*
                    IF p_include_analysis = 'Y'
                   THEN
                      l_total := 0;

                      FOR c_org IN c_orgs
                      LOOP
                         l_det_cnt := 0;

                         FOR c_detail IN c_details_analysis (c_org.organization_id,
                                                             c_product.style,
                                                             c_product.color,
                                                             c_product.sze
                                                            )
                         LOOP
                            IF l_det_cnt != 0
                            THEN
                               raise_application_error
                                  (-20001,
                                      'More than one analysis detail record was found.  Organization ID='
                                   || c_org.organization_id
                                   || ', Style='
                                   || c_product.style
                                   || ', Color='
                                   || c_product.color
                                  );
                            END IF;

                            l_det_cnt := l_det_cnt + 1;

                            IF c_org.is_master_org_id IS NULL
                            THEN
                               -- Only add value for System Item Cost if the current org is not the master --
                               fnd_file.put (fnd_file.output,
                                                g_delim_char
                                             || NVL (c_detail.sys_item_cost, 0)
                                            );
                            END IF;

                            fnd_file.put (fnd_file.output,
                                             g_delim_char
                                          || NVL (c_detail.rpt_non_mat_cost, 0)
                                          || g_delim_char
                                          || NVL (c_detail.sys_non_mat_cost, 0)
                                          || g_delim_char
                                          || NVL (c_detail.sys_freight_pct, 0)
                                          || g_delim_char
                                          || NVL (c_detail.sys_macau_intrans_cost, 0)
                                          || g_delim_char
                                          || NVL (c_detail.sys_macau_intrans_val, 0)
                                          || g_delim_char
                                          || NVL (c_detail.sys_macau_onhand_val, 0)
                                          || g_delim_char
                                          || NVL (c_detail.sys_macau_total_val, 0)
                                         );
                            l_total :=
                                      l_total + NVL (c_detail.sys_macau_total_val, 0);
                         END LOOP;

                         IF l_det_cnt = 0
                         THEN
                            IF c_org.is_master_org_id IS NULL
                            THEN
                               -- Only add value for System Item Cost if the current org is not the master --
                               fnd_file.put (fnd_file.output, g_delim_char || '0');
                            END IF;

                            fnd_file.put (fnd_file.output,
                                             g_delim_char
                                          || '0'
                                          || g_delim_char
                                          || '0'
                                          || g_delim_char
                                          || '0'
                                          || g_delim_char
                                          || '0'
                                          || g_delim_char
                                          || '0'
                                          || g_delim_char
                                          || '0'
                                          || g_delim_char
                                          || '0'
                                         );
                         END IF;
                      END LOOP;

                      fnd_file.put (fnd_file.output, g_delim_char || l_total);
                   END IF;


                   l_total := 0;
                   l_qty_total := 0;
                   l_total_mat := 0;
                   l_total_profit_elim := 0;

                */
                FOR c_org IN c_orgs
                LOOP
                    --Start Changes V2.1
                    IF NVL (p_layered_mrgn, 'N') = 'Y'
                    THEN
                        --End Changes V2.1
                        fnd_file.put (
                            fnd_file.output,
                               g_delim_char
                            || c_org.organization_code
                            || ' Default Duty Rate'
                            || g_delim_char
                            || c_org.organization_code
                            || ' On Hand Qty'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Material Cost'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Duty Amount'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Freight Dutiable(Freight DU )'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Freight'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Dutiable OH (OH DUTY)'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Non-dutiable OH(OH NONDUTY)'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Total Cost'
                            || g_delim_char
                            || c_org.organization_code
                            -- Added by BT Technology Team on 12-JUn-2015 for defect#2322
                            || ' On Hand Value'
                            || g_delim_char
                            --start changes by BT Technology Team on 22-Jun-2015 for defect#2322
                            || c_org.organization_code
                            || ' Intransit Qty'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Material val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Duty Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Freight Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Freight DU Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit OH DUTY val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit OH NONDUTY Val'
                            || g_delim_char
                            --|| c_org.organization_code -- 3.4
                            --|| ' Intransit Qty (PO Receiving)'  --Added forc change 3.2 -- 3.4
                            --|| g_delim_char                  --Added forc change 3.2  -- 3.4
                            --|| c_org.organization_code       --Added forc change 3.2  -- 3.4
                            --|| ' Intransit Value (PO Receiving)' --Added forc change 3.2  -- 3.4
                            --|| g_delim_char-- 3.4
                            || c_org.organization_code
                            || ' Total Inventory QTY'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Total Inventory Value'
                            || g_delim_char
                            --End changes by BT Technology Team on 22-Jun-2015 for defect#2322
                            || c_org.organization_code
                            || ' Extended Material Cost'
                            || g_delim_char
                            --|| c_org.organization_code
                            || ' Macau Cost'
                            || g_delim_char
                            || ' Extended Macau Cost'
                            --Start Changes V2.1
                            || g_delim_char
                            || ' Avg. Margin Value - USD'
                            || g_delim_char
                            || ' Avg. Margin Value - Local'
                            || g_delim_char
                            || ' Layered Margin Onhand Cost (USD)'
                            || g_delim_char
                            || '  Layered Margin Onhand Cost (Local)'
                            || g_delim_char
                            || ' Layered Margin Intransit Cost (USD)'
                            || g_delim_char
                            || '  Layered Margin Intransit Cost (Local)');
                    ELSE
                        fnd_file.put (
                            fnd_file.output,
                               g_delim_char
                            || c_org.organization_code
                            || ' Default Duty Rate'
                            || g_delim_char
                            || c_org.organization_code
                            || ' On Hand Qty'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Material Cost'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Duty Amount'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Freight Dutiable(Freight DU )'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Freight'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Dutiable OH (OH DUTY)'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Non-dutiable OH(OH NONDUTY)'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Total Cost'
                            || g_delim_char
                            || c_org.organization_code
                            -- Added by BT Technology Team on 12-JUn-2015 for defect#2322
                            || ' On Hand Value'
                            || g_delim_char
                            --start changes by BT Technology Team on 22-Jun-2015 for defect#2322
                            || c_org.organization_code
                            || ' Intransit Qty'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Material val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Duty Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Freight Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Freight DU Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit OH DUTY val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit OH NONDUTY Val'
                            || g_delim_char
                            --|| c_org.organization_code -- 3.4
                            --|| ' Intransit Qty (PO Receiving)' --Added for change 3.2-- 3.4
                            --|| g_delim_char   -- 3.4
                            --|| c_org.organization_code  -- 3.4
                            --|| ' Intransit Value (PO Receiving)'
                            --Added for change 3.2 -- 3.4
                            --|| g_delim_char -- 3.4
                            || c_org.organization_code
                            || ' Total Inventory QTY'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Total Inventory Value'
                            || g_delim_char
                            --End changes by BT Technology Team on 22-Jun-2015 for defect#2322
                            || c_org.organization_code
                            || ' Extended Material Cost'
                            || g_delim_char
                            --|| c_org.organization_code
                            || ' Macau Cost'
                            || g_delim_char
                            || ' Extended Macau Cost'
                            --Start Changes V2.1
                            || g_delim_char
                            || ' Avg. Margin Value - USD'
                            || g_delim_char
                            || '  Avg. Margin Value - Local');
                    END IF;

                    IF p_tq_japan = 'Y'
                    THEN
                        fnd_file.put (
                            fnd_file.output,
                               g_delim_char
                            -- Start changes by BT Technology Team on 09-Dec-2015 for defect#689
                            --|| 'Marked Up Macau Cost'
                            --|| g_delim_char
                            --|| 'Extended Marked Up Macau Cost');
                            || 'Material Cost in USD'
                            || g_delim_char
                            || 'Extended Material Cost in USD');
                    -- End changes by BT Technology Team on 09-Dec-2015 for defect#689
                    END IF;
                --Start changes V3.1 on 05 Jan 2018
                --            fnd_file.put (
                --               fnd_file.output,
                --               g_delim_char || c_org.organization_code || ' I/C Profit');
                --End changes V3.1 on 05 Jan 2018
                END LOOP;

                --Start changes V3.1 on 05 Jan 2018
                --         fnd_file.put_line (
                --            fnd_file.output,
                --               g_delim_char
                --            || 'Report Total Onhand Qty'
                --            || g_delim_char
                --            || 'Report Total Extended Material cost'
                --            || g_delim_char
                --            || 'Report Macau Extended Cost'
                --            || g_delim_char
                --            || 'Total Report I/C Profit'
                --            );
                fnd_file.put_line (fnd_file.output, '');
                --End changes V3.1 on 05 Jan 2018
                -- End Changes by BT Technology Team
                l_counter   := 0;

                FOR c_product IN c_products
                LOOP                             --Printing Item Level Records
                    l_counter            := l_counter + 1;
                    -- Start Changes by BT Technology Team on 15/01/2014
                    /*
                       fnd_file.put (fnd_file.output,
                                       scrub_value (c_product.brand)
                                    || g_delim_char
                                    || scrub_value (c_product.style)
                                    || g_delim_char
                                    || scrub_value (c_product.color)
                                    || g_delim_char
                                    || scrub_value (c_product.sze)
                                    || g_delim_char
                                    || scrub_value (c_product.style_description)
                                    || g_delim_char
                                    || scrub_value (c_product.color_description)
                                    || g_delim_char
                                    || scrub_value (c_product.series)
                                    || g_delim_char
                                    || scrub_value (c_product.product)
                                    || g_delim_char
                                    || scrub_value (c_product.gender)
                                    || g_delim_char
                                    || scrub_value (c_product.intro_season)
                                    || g_delim_char
                                    || scrub_value (c_product.current_season)
                                    || g_delim_char
                                    || c_product.first_cost_duty
                                    || g_delim_char
                                    || TO_CHAR (c_product.duty_rate)
                                    || '%'
                                    || g_delim_char
                                    || c_product.master_item_cost
                                    || g_delim_char
                                    || c_product.master_duty_cost
                                   );

                    */
                    fnd_file.put (
                        fnd_file.output,
                           scrub_value (c_product.style)
                        || g_delim_char
                        || scrub_value (c_product.color)
                        || g_delim_char
                        || scrub_value (c_product.sze)
                        || g_delim_char
                        || scrub_value (c_product.item_description)
                        || g_delim_char
                        || scrub_value (c_product.brand)
                        || g_delim_char
                        --|| scrub_value (c_product.division)
                        --|| g_delim_char
                        || scrub_value (c_product.department)
                        || g_delim_char
                        || scrub_value (c_product.master_class)
                        || g_delim_char
                        || scrub_value (c_product.sub_class)
                        || g_delim_char
                        || scrub_value (c_product.item_type)
                        -- CR#92 added Item Type BT Technology Team
                        -- || g_delim_char
                        -- || scrub_value (c_product.master_style)
                        --|| g_delim_char
                        --|| scrub_value (c_product.style_option)
                        || g_delim_char
                        || scrub_value (c_product.intro_season)
                        || g_delim_char
                        || scrub_value (c_product.current_season));
                    /*l_total := 0;
                    l_qty_total := 0;
                    l_total_mat := 0;
                    l_total_profit_elim := 0;*/
                    l_tot_onhand_qty     := 0;
                    l_tot_ext_mat_cost   := 0;
                    l_tot_ext_mac_cost   := 0;
                    l_ext_macau_cost     := 0;
                    l_tot_iprofit        := 0;

                    --IF p_include_analysis = 'Y'
                    -- THEN
                    --   l_total := 0;
                    -- End changes by BT Technology Team On 15/01/2014
                    FOR c_org IN c_orgs
                    LOOP
                        l_det_cnt           := 0;
                        l_material_cost     := 0;
                        -- Start Added by BT Technology Team On 15/01/2014
                        --  l_duty_rate  :=0;
                        l_freight_du        := 0;
                        l_freight           := 0;
                        l_oh_duty           := 0;
                        l_oh_nonduty        := 0;
                        l_duty_cost         := 0;
                        l_default_duty      := 0;
                        l_ext_mat_cost      := 0;
                        l_ext_mac_cost      := 0;
                        -- End Added by BT Technology Team On 15/01/2014
                        l_total_cost        := 0;
                        l_total_value       := 0;
                        l_iprofit           := 0;
                        l_tq_markup         := 0;
                        l_conv_rate         := 1;
                        ln_total_overhead   := 0;

                        FOR c_detail
                            IN c_details_rpt (c_org.organization_id, c_product.style, c_product.color
                                              , c_product.sze, l_use_date)
                        LOOP
                            IF l_det_cnt != 0
                            THEN
                                raise_application_error (
                                    -20001,
                                       'More than one report detail record was found.  Organization ID='
                                    || c_org.organization_id
                                    || ', Style='
                                    || c_product.style
                                    || ', Color='
                                    || c_product.color);
                            END IF;

                            --Start changes for V2.1
                            IF NVL (p_layered_mrgn, 'N') = 'Y'
                            THEN
                                --Onhand Layered Margin
                                xv_source                        := NULL;
                                xn_inventory_item_id             := 0;
                                xn_destination_organization_id   := 0;
                                xd_transaction_date              := NULL;
                                xn_transaction_quantity          := 0;
                                xn_trx_mrgn_cst_usd              := 0;
                                xn_trx_mrgn_cst_local            := 0;
                                ln_transaction_quantity          := 0;
                                ln_trx_mrgn_cst_usd              := 0;
                                ln_trx_mrgn_cst_local            := 0;
                                ln_diff_qty                      :=
                                    c_detail.onhand_qty;
                                ld_trx_date                      :=
                                    l_use_date;
                                ln_seq_number                    := 0;
                                lv_source                        := NULL;

                                BEGIN
                                    WHILE (c_detail.onhand_qty > ln_transaction_quantity)
                                    LOOP
                                        --                           fnd_file.put_LINE (
                                        --                              fnd_file.LOG,
                                        --                                 'inventory_item_id - '
                                        --                              || c_product.inventory_item_id
                                        --                              || 'organization_id - '
                                        --                              || c_org.organization_id
                                        --                              || 'ln_seq_number - '
                                        --                              || ln_seq_number
                                        --                              || 'ln_diff_qty - '
                                        --                              || ln_diff_qty
                                        --                              || 'lv_source - '
                                        --                              || lv_source
                                        --                              || 'ln_seq_number - '
                                        --                              || ln_seq_number
                                        --                              || 'c_detail.onhand_qty > ln_transaction_quantity'
                                        --                              || c_detail.onhand_qty
                                        --                              || '--- '
                                        --                              || ln_transaction_quantity);
                                        get_rollback_trx_onhand_qty (
                                            c_product.inventory_item_id,
                                            c_product.style,
                                            c_product.color,
                                            c_product.sze,
                                            c_org.organization_id,
                                            ld_trx_date,
                                            ln_diff_qty,
                                            lv_source,
                                            ln_seq_number,
                                            xn_seq_number,
                                            xv_source,
                                            xn_inventory_item_id,
                                            xn_destination_organization_id,
                                            xd_transaction_date,
                                            xn_transaction_quantity,
                                            xn_trx_mrgn_cst_usd,
                                            xn_trx_mrgn_cst_local);
                                        lv_source       := xv_source;
                                        ld_trx_date     := xd_transaction_date;
                                        ln_seq_number   := xn_seq_number;
                                        ln_transaction_quantity   :=
                                              ln_transaction_quantity
                                            + xn_transaction_quantity;
                                        ln_diff_qty     :=
                                              c_detail.onhand_qty
                                            - ln_transaction_quantity;
                                        ln_trx_mrgn_cst_usd   :=
                                              ln_trx_mrgn_cst_usd
                                            + xn_trx_mrgn_cst_usd;
                                        ln_trx_mrgn_cst_local   :=
                                              ln_trx_mrgn_cst_local
                                            + xn_trx_mrgn_cst_local;
                                    --                           fnd_file.put_line (
                                    --                              fnd_file.LOG,
                                    --                                 'ln_intst_trx_mrgn_cst_usd - - '
                                    --                              || ln_trx_mrgn_cst_usd
                                    --                              || ' -- '
                                    --                              || ln_trx_mrgn_cst_local);
                                    END LOOP;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put (
                                            fnd_file.LOG,
                                               'Error while fetching the layered Margin - '
                                            || SQLERRM);
                                END;

                                -- Intransit Layered Margin
                                BEGIN
                                    xv_source                        := NULL;
                                    ln_seq_number                    := NULL;
                                    --                        lv_source
                                    xn_intst_inventory_item_id       := 0;
                                    xn_intst_destn_organization_id   := 0;
                                    xd_intst_transaction_date        := NULL;
                                    xn_intst_transaction_quantity    := 0;
                                    xn_intst_trx_mrgn_cst_usd        := 0;
                                    xn_intst_trx_mrgn_cst_local      := 0;
                                    ln_transaction_quantity          := 0;
                                    ln_intst_trx_mrgn_cst_usd        := 0;
                                    ln_intst_trx_mrgn_cst_local      := 0;
                                    ln_diff_qty                      :=
                                        c_detail.rpt_intrans_qty;
                                    ld_trx_date                      :=
                                        l_use_date;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'c_detail.rpt_intrans_qty'
                                        || c_detail.rpt_intrans_qty);

                                    WHILE (c_detail.rpt_intrans_qty > ln_transaction_quantity)
                                    LOOP
                                        --                           fnd_file.put_LINE (
                                        --                              fnd_file.LOG,
                                        --                                 ' Intransit inventory_item_id - '
                                        --                              || c_product.inventory_item_id
                                        --                              || 'organization_id - '
                                        --                              || c_org.organization_id
                                        --                              || 'ln_seq_number - '
                                        --                              || ln_seq_number
                                        --                              || 'ln_diff_qty - '
                                        --                              || ln_diff_qty
                                        --                              || 'lv_source - '
                                        --                              || lv_source
                                        --                              || 'ln_seq_number - '
                                        --                              || ln_seq_number
                                        --                              || 'c_detail.rpt_intrans_qty > ln_transaction_quantity'
                                        --                              || c_detail.rpt_intrans_qty
                                        --                              || '--- '
                                        --                              || ln_transaction_quantity);
                                        get_rollback_trx_intransit_qty (
                                            c_product.inventory_item_id,
                                            c_product.style,
                                            c_product.color,
                                            c_product.sze,
                                            c_org.organization_id,
                                            ld_trx_date,
                                            ln_diff_qty,
                                            ln_seq_number,
                                            xv_source,
                                            xn_seq_number,
                                            xn_intst_inventory_item_id,
                                            xn_intst_destn_organization_id,
                                            xd_intst_transaction_date,
                                            xn_intst_transaction_quantity,
                                            xn_intst_trx_mrgn_cst_usd,
                                            xn_intst_trx_mrgn_cst_local);
                                        ld_trx_date     := xd_transaction_date;
                                        ln_seq_number   := xn_seq_number;
                                        ln_transaction_quantity   :=
                                              ln_transaction_quantity
                                            + xn_intst_transaction_quantity;
                                        ln_diff_qty     :=
                                              c_detail.rpt_intrans_qty
                                            - ln_transaction_quantity;
                                        ln_intst_trx_mrgn_cst_usd   :=
                                              ln_intst_trx_mrgn_cst_usd
                                            + xn_intst_trx_mrgn_cst_usd;
                                        ln_intst_trx_mrgn_cst_local   :=
                                              ln_intst_trx_mrgn_cst_local
                                            + xn_intst_trx_mrgn_cst_local;
                                    --                           fnd_file.put_line (
                                    --                              fnd_file.LOG,
                                    --                                 'ln_intst_trx_mrgn_cst_local - - '
                                    --                              || ln_intst_trx_mrgn_cst_local
                                    --                              || ' -- '
                                    --                              || ln_intst_trx_mrgn_cst_usd);
                                    END LOOP;

                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Parent ln_intst_trx_mrgn_cst_local - - '
                                        || ln_intst_trx_mrgn_cst_local
                                        || ' -- '
                                        || ln_intst_trx_mrgn_cst_usd);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put (
                                            fnd_file.LOG,
                                               'Error while fetching the layered Margin - '
                                            || SQLERRM);
                                END;
                            END IF;

                            --END Changes for V2.1

                            --Start Changes by BT Technology Team on 15/01/2014
                            /*
                             l_det_cnt := l_det_cnt + 1;

                               IF c_org.is_master_org_id IS NULL
                               THEN
                                  -- Only add value for System Item Cost if the current org is not the master --
                                  fnd_file.put (fnd_file.output,
                                                   g_delim_char
                                                || NVL (c_detail.sys_item_cost, 0)
                                               );
                               END IF;

                               fnd_file.put (fnd_file.output,
                                                g_delim_char
                                             || NVL (c_detail.rpt_non_mat_cost, 0)
                                             || g_delim_char
                                             || NVL (c_detail.sys_non_mat_cost, 0)
                                             || g_delim_char
                                             || NVL (c_detail.sys_freight_pct, 0)
                                             || g_delim_char
                                             || NVL (c_detail.sys_macau_intrans_cost, 0)
                                             || g_delim_char
                                             || NVL (c_detail.sys_macau_intrans_val, 0)
                                             || g_delim_char
                                             || NVL (c_detail.sys_macau_onhand_val, 0)
                                             || g_delim_char
                                             || NVL (c_detail.sys_macau_total_val, 0)
                                            );
                               l_total :=
                                         l_total + NVL (c_detail.sys_macau_total_val, 0);
                            */
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                   'Item Number'
                                || c_product.item_number
                                || 'Organization ID '
                                || c_org.organization_id);
                            l_default_duty   :=
                                default_duty_rate (
                                    c_product.inventory_item_id,
                                    c_org.organization_id);

                            --commented by BT Technology team as per  CR#TBD and Defect#689 for all the calculation 26-Nov-2015
                            /*l_material_cost :=
                               xxdoget_item_cost ('MATERIAL',
                                                  c_org.organization_id,
                                                  c_product.inventory_item_id,
                                                  'N');*/

                            --l_duty_rate     :=xxdoget_item_cost('DUTYRATE',c_org.organization_id,c_product.inventory_item_id,'N');

                            --Start changes by BT Technology Team on 20-Nov-2015 for defect#689
                            IF l_default_duty = 0
                            THEN
                                l_default_duty   :=
                                    xxdoget_item_cost ('DUTY RATE', c_org.organization_id, c_product.inventory_item_id
                                                       , 'Y');
                            END IF;

                            --End changes by BT Technology Team on 20-Nov-2015 for defect#689

                            -- Start Changes  CR#TBD and Defect#689 for all the calculation 26-Nov-2015
                            ln_total_overhead   :=
                                xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_oh_val_fnc (
                                    c_product.inventory_item_id,
                                    c_org.organization_id,
                                    l_use_date - 1); -- Added as per CCR0008682
                            --                  fnd_file.put_line (fnd_file.LOG, 'ln_total_overhead for Current is - '||ln_total_overhead);
                            l_material_cost   :=
                                xxd_fg_inv_val_rpt_pkg.xxdo_cst_mat_val_fnc (
                                    c_product.inventory_item_id,
                                    c_org.organization_id,
                                    l_use_date - 1); -- Added as per CCR0008682
                            --                  fnd_file.put_line (fnd_file.LOG, 'l_material_cost for Current is - '||l_material_cost);

                            /*l_freight_du :=
                               xxdoget_item_cost ('FREIGHT DU',
                                                  c_org.organization_id,
                                                  c_product.inventory_item_id,
                                                  'Y');*/
                            l_freight_du     :=
                                NVL ((  xxdoget_item_cost ('FREIGHT DU FACTOR', c_org.organization_id, c_product.inventory_item_id
                                                           , 'Y')
                                      * xxdoget_item_cost ('FREIGHT DU RATE', c_org.organization_id, c_product.inventory_item_id
                                                           , 'Y')
                                      * l_material_cost),
                                     NVL (xxdoget_item_cost ('FREIGHT DU', c_org.organization_id, c_product.inventory_item_id
                                                             , 'Y'),
                                          0));
                            --                   fnd_file.put_line (fnd_file.LOG, 'first l_freight_du for Current is - '||l_freight_du);
                            l_freight_du     :=
                                CASE
                                    WHEN ln_total_overhead > l_freight_du
                                    THEN
                                        l_freight_du
                                    ELSE
                                        ln_total_overhead
                                END;
                            --                  fnd_file.put_line (fnd_file.LOG, 'Final l_freight_du for Current is - '||l_freight_du);

                            /*l_freight :=
                               xxdoget_item_cost ('FREIGHT',
                                                  c_org.organization_id,
                                                  c_product.inventory_item_id,
                                                  'Y');*/
                            l_freight        :=
                                --start viswa
                                 NVL ((  xxdoget_item_cost ('FREIGHT FACTOR', c_org.organization_id, c_product.inventory_item_id
                                                            , 'Y')
                                       * xxdoget_item_cost ('FREIGHT RATE', c_org.organization_id, c_product.inventory_item_id
                                                            , 'Y')
                                       * l_material_cost),
                                      NVL (xxdoget_item_cost ('FREIGHT', c_org.organization_id, c_product.inventory_item_id
                                                              , 'Y'),
                                           0));
                            --                  fnd_file.put_line (fnd_file.LOG, 'first l_freight for Current is - '||l_freight);
                            l_freight        :=
                                CASE
                                    WHEN l_freight >
                                         (ln_total_overhead - l_freight_du)
                                    THEN
                                        ln_total_overhead - l_freight_du
                                    ELSE
                                        l_freight
                                END;
                            --                  fnd_file.put_line (fnd_file.LOG, 'Final l_freight for Current is - '||l_freight);

                            /* l_oh_duty :=
                                xxdoget_item_cost ('OH DUTY',
                                                   c_org.organization_id,
                                                   c_product.inventory_item_id,
                                                   'Y');*/
                            l_oh_duty        :=
                                NVL ((  xxdoget_item_cost ('OH DUTY FACTOR', c_org.organization_id, c_product.inventory_item_id
                                                           , 'Y')
                                      * xxdoget_item_cost ('OH DUTY RATE', c_org.organization_id, c_product.inventory_item_id
                                                           , 'Y')
                                      * l_material_cost),
                                     NVL (xxdoget_item_cost ('OH DUTY', c_org.organization_id, c_product.inventory_item_id
                                                             , 'Y'),
                                          0));
                            --                  fnd_file.put_line (fnd_file.LOG, 'first l_oh_duty for Current is - '||l_oh_duty);
                            l_oh_duty        :=
                                CASE
                                    WHEN l_oh_duty >
                                         (ln_total_overhead - l_freight_du - l_freight)
                                    THEN
                                        (ln_total_overhead - l_freight_du - l_freight)
                                    ELSE
                                        l_oh_duty
                                END;
                            --                  fnd_file.put_line (fnd_file.LOG, 'Final l_oh_duty for Current is - '||l_oh_duty);

                            /*l_oh_nonduty :=
                               xxdoget_item_cost ('OH NONDUTY',
                                                  c_org.organization_id,
                                                  c_product.inventory_item_id,
                                                  'Y');*/
                            l_oh_nonduty     :=
                                NVL ((  xxdoget_item_cost ('OH NONDUTY FACTOR', c_org.organization_id, c_product.inventory_item_id
                                                           , 'Y')
                                      * xxdoget_item_cost ('OH NONDUTY RATE', c_org.organization_id, c_product.inventory_item_id
                                                           , 'Y')
                                      * l_material_cost),
                                     NVL (xxdoget_item_cost ('OH NONDUTY', c_org.organization_id, c_product.inventory_item_id
                                                             , 'Y'),
                                          0));
                            --                  fnd_file.put_line (fnd_file.LOG, 'first l_oh_nonduty for Current is - '||l_oh_nonduty);
                            l_oh_nonduty     :=
                                CASE
                                    WHEN l_oh_nonduty >
                                         (ln_total_overhead - l_freight_du - l_freight - l_oh_duty)
                                    THEN
                                        (ln_total_overhead - l_freight_du - l_freight - l_oh_duty)
                                    ELSE
                                        l_oh_nonduty
                                END;
                            --                     fnd_file.put_line (fnd_file.LOG, 'Final l_oh_nonduty for Current is - '||l_oh_nonduty);

                            /* l_duty_cost :=
                                (  xxdoget_item_cost ('TOTAL OVERHEAD',
                                                      c_org.organization_id,
                                                      c_product.inventory_item_id,
                                                      'Y')
                                 - (l_freight_du + l_freight + l_oh_duty + l_oh_nonduty));*/
                            l_duty_cost      :=
                                  ln_total_overhead
                                - (l_freight_du + l_freight + l_oh_duty + l_oh_nonduty);

                            --                   fnd_file.put_line (fnd_file.LOG, 'Calculated l_duty_cost for Current is - '||l_duty_cost);

                            --Start changes by BT Technology Team on 20-Nov-2015 for defect#689
                            --Added IF condi for duty cost not to display negative
                            IF l_duty_cost < 0
                            THEN
                                l_duty_cost   := 0;
                            END IF;

                            --                  fnd_file.put_line (fnd_file.LOG, 'Final l_duty_cost for Current is - '||l_duty_cost);

                            --End changes by BT Technology Team on 20-Nov-2015 for defect#689
                            -- l_ext_mat_cost  :=c_detail.onhand_qty*l_material_cost; logic changed in new MD050 On Hand Qty* On Hand Material Cost + Intransit Qty * Intransit Material Cost
                            --l_ext_mac_cost  :=c_detail.macau_cost*c_detail.onhand_qty;
                            l_total_cost     :=
                                  l_material_cost
                                + l_duty_cost
                                + l_freight_du
                                + l_freight
                                + l_oh_duty
                                + l_oh_nonduty;
                            --                  fnd_file.put_line (fnd_file.LOG, 'Calculated l_total_cost for Current is - '||l_total_cost);
                            l_total_value    :=
                                (l_total_cost * NVL (c_detail.onhand_qty, 0));
                            --Added BY BT Technology on 12-Jun-2015 for defect#2322
                            -- Start Changes by BT Technology Team on 22-Jun-2015 for defect#2322
                            l_intrans_val    :=
                                -- Start changes by BT Technology Team on 10-Dec-2015 for defect#689
                                /*c_detail.rpt_intrans_qty
                              * (xxdoget_item_cost ('ITEMCOST',
                                                    c_org.organization_id,
                                                    c_product.inventory_item_id,
                                                    'N'));*/
                                 ROUND (
                                    c_detail.rpt_intrans_qty * l_total_cost,
                                    2);
                            l_intrans_rec_val   :=
                                ROUND (
                                    c_detail.rec_intrans_qty * l_total_cost,
                                    2);
                            --Added for change 3.2
                            -- End changes by BT Technology Team on 10-Dec-2015 for defect#689
                            l_intrans_mat_val   :=
                                c_detail.rpt_intrans_qty * l_material_cost;
                            l_intrans_duty_val   :=
                                c_detail.rpt_intrans_qty * l_duty_cost;
                            l_intrans_frt_val   :=
                                c_detail.rpt_intrans_qty * l_freight;
                            l_intrans_frt_du_val   :=
                                c_detail.rpt_intrans_qty * l_freight_du;
                            l_intrans_oh_duty_val   :=
                                c_detail.rpt_intrans_qty * l_oh_duty;
                            l_intrans_nonoh_duty_val   :=
                                c_detail.rpt_intrans_qty * l_oh_nonduty;
                            --End changes by BT Technology Team on 22-Jun-2015 for defect#2322

                            l_tot_inv_qty    :=
                                  c_detail.onhand_qty
                                + c_detail.rpt_intrans_qty; --Commented for change 3.2 -- 3.4 uncommented
                            /*l_tot_inv_qty :=
                                 c_detail.onhand_qty
                               + c_detail.rpt_intrans_qty
                               + c_detail.rec_intrans_qty;*/
                            -- Added for change 3.2 -- 3.4
                            l_tot_inv_val    := l_total_value + l_intrans_val; --Commented for change 3.2 -- 3.4
                            /*l_tot_inv_val :=
                                    l_total_value + l_intrans_val + l_intrans_rec_val;*/
                            -- Added for change 3.2-- 3.4
                            l_ext_mat_cost   :=
                                  (c_detail.onhand_qty * l_material_cost)
                                + l_intrans_mat_val;
                            --l_ext_mat_cost  :=(c_detail.onhand_qty*l_material_cost)+ (c_detail.rpt_intrans_qty*l_intrans_mat_val); --Commented by BT Technology Team on 20-Nov-2015 for defect#689
                            l_ext_mac_cost   :=
                                c_detail.macau_cost * l_tot_inv_qty;
                            l_det_cnt        := l_det_cnt + 1;

                            /*fnd_file.put_line (fnd_file.LOG, 'Final l_total_value for Current is - '||l_total_value);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_val for Current is - '||l_intrans_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_mat_val for Current is - '||l_intrans_mat_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_duty_val for Current is - '||l_intrans_duty_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_frt_val for Current is - '||l_intrans_frt_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_frt_du_val for Current is - '||l_intrans_frt_du_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_oh_duty_val for Current is - '||l_intrans_oh_duty_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_nonoh_duty_val for Current is - '||l_intrans_nonoh_duty_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_tot_inv_qty for Current is - '||l_tot_inv_qty);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_tot_inv_val for Current is - '||l_tot_inv_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_ext_mat_cost for Current is - '||l_ext_mat_cost);
                            fnd_file.put_line (fnd_file.LOG, 'Final1 l_ext_mac_cost for Current is - '||l_ext_mac_cost);*/

                            --Start Changes by BT Technology Team on 23-Jun-2015 for defect#2322
                            IF p_elimination_rate = 'USER'
                            THEN
                                l_conv_rate   := NVL (p_user_rate, 0);
                            ELSE
                                BEGIN
                                    /* SELECT round(conversion_rate,2) CONVERSION_RATE
                                       INTO l_conv_rate
                                       FROM gl_daily_rates
                                      WHERE     from_currency = c_detail.currency_code
                                            AND to_currency = 'USD'
                                            AND conversion_type = nvl(decode(p_elimination_rate,'Budget','1000',p_elimination_rate),'Corporate')
                                            AND TRUNC (conversion_date) = TRUNC (SYSDATE);*/
                                    SELECT AVG (conversion_rate)
                                      INTO l_conv_rate
                                      FROM gl_daily_rates
                                     WHERE     conversion_type =
                                               NVL (p_elimination_rate_type,
                                                    '1000')
                                           -- budget_id for rate type
                                           AND TRUNC (conversion_date) BETWEEN   ADD_MONTHS (
                                                                                     -- Start changes by BT Technology Team on 10-Dec-2015 for defect#689
                                                                                     --SYSDATE,
                                                                                     fnd_date.canonical_to_date (
                                                                                         p_as_of_date),
                                                                                     -- End changes by BT Technology Team on 10-Dec-2015 for defect#689
                                                                                     -(TO_NUMBER (SUBSTR (p_elimination_rate, 4, 2))))
                                                                               + 1
                                                                           -- Start changes by BT Technology Team on 10-Dec-2015 for defect#689
                                                                           -- AND SYSDATE
                                                                           AND fnd_date.canonical_to_date (
                                                                                   p_as_of_date)
                                           -- End changes by BT Technology Team on 10-Dec-2015 for defect#689
                                           AND from_currency =
                                               NVL (p_from_currency,
                                                    c_detail.currency_code)
                                           AND to_currency = 'USD';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_conv_rate   := 0;
                                END;
                            END IF;

                            -- code added for DEFECT#2322 TQ MARKUP Eliminaton Logic
                            IF     p_jpy_user_rate IS NOT NULL
                               AND p_markup_rate_type IS NULL
                            THEN
                                l_rate   := NVL (p_jpy_user_rate, 0);
                            ELSE
                                BEGIN
                                    SELECT conversion_rate
                                      INTO l_rate
                                      FROM gl_daily_rates
                                     WHERE     conversion_type =
                                               NVL (p_markup_rate_type,
                                                    '1000')
                                           -- budget_id for rate type
                                           AND TRUNC (conversion_date) =
                                               NVL (
                                                   TO_DATE (p_as_of_date,
                                                            'YYYY/MM/DD'),
                                                   TRUNC (SYSDATE))
                                           AND from_currency = 'USD'
                                           AND to_currency = 'JPY';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_rate   := 0;
                                END;
                            END IF;

                            BEGIN
                                -- Start changes by BT Technology Team on 10-Dec-2015 for defect#689
                                --SELECT DISTINCT rate_multiplier, rate_amount --xppra.VENDOR_NAME,xppr.po_price_rule
                                SELECT MAX (rate_multiplier), MAX (rate_amount)
                                  -- End changes by BT Technology Team on 10-Dec-2015 for defect#689
                                  INTO l_rate_multiplier, l_rate_amt
                                  FROM do_custom.xxdo_po_price_rule xppr, do_custom.xxdo_po_price_rule_assignment xppra--,AP_SUPPLIERS APS
                                                                                                                       -- ,HR_ORGANIZATION_UNITS HROU
                                                                                                                       , apps.xxd_common_items_v xci
                                 WHERE     xppr.po_price_rule =
                                           xppra.po_price_rule
                                       --AND  xppr.VENDOR_NAME = APS.VENDOR_NAME
                                       --AND  APS.VENDOR_ID =  p_vendor_id
                                       --AND  xppra.target_item_orgANIZATION = HROU.NAME
                                       --AND HROU.ORGANIZATION_ID = 129;
                                       AND xppra.item_segment1 =
                                           xci.style_number
                                       AND xppra.item_segment2 =
                                           xci.color_code
                                       -- AND xppr.po_price_rule = 'MB-SANUK-NTQ'  --lv_color
                                       AND xci.org_name =
                                           xppra.target_item_organization
                                       AND xci.style_number = c_product.style
                                       AND xci.color_code = c_product.color;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_rate_multiplier   := 0;
                                    l_rate_amt          := 0;
                            END;

                            -- Commented by BT Technology Team on 01-Jul-2015 for defect#2411
                            --l_iprofit :=  NVL (l_ext_mat_cost*l_conv_rate-l_ext_mac_cost*l_conv_rate, 0);
                            -- l_iprofit :=  NVL (l_ext_mat_cost*l_conv_rate-l_ext_mac_cost, 0); -- Added by BT Technology Team on 01-Jul-2015 for defect#2411
                            --End Changes by BT Technology Team on 23-Jun-2015 for defect#2322

                            --TQ Markup Logic
                            fnd_file.put (
                                fnd_file.LOG,
                                'c_detail.currency_code:' || c_detail.currency_code);
                            fnd_file.put (fnd_file.LOG,
                                          'l_conv_rate:' || l_conv_rate);
                            fnd_file.put (
                                fnd_file.LOG,
                                'l_ext_mac_cost:' || l_ext_mac_cost);
                            --fnd_file.put (fnd_file.log, 'l_ext_mat_cost:'||l_ext_mat_cost );
                            --fnd_file.put (fnd_file.log, 'l_ext_markup_mac_cost:'||round(to_number(l_ext_markup_mac_cost)));
                            --fnd_file.put (fnd_file.log, 'minus:'||(to_number(l_ext_mat_cost) - round(to_number(l_ext_markup_mac_cost))));

                            -- Start changes by BT Technology Team on 09-Dec-2015 for defect#689
                            /*l_tq_markup :=
                                 (  NVL (c_detail.macau_cost * l_rate, 0)
                                  * l_rate_multiplier)
                               + l_rate_amt; -- Added by BT Technology Team on 22-JUL-2015 for DEFECT#2322 and CR#90

                            l_ext_markup_mac_cost :=
                               NVL (l_tot_inv_qty * l_tq_markup, 0);*/
                            l_rate_multiplier   :=
                                CASE
                                    WHEN    l_rate_multiplier = 0
                                         OR l_rate_multiplier IS NULL
                                    THEN
                                        1
                                    ELSE
                                        l_rate_multiplier
                                END;
                            l_rate_amt       := NVL (l_rate_amt, 0);
                            l_tq_markup      :=
                                ROUND (
                                    (((l_material_cost - l_rate_amt) / l_rate_multiplier) * l_conv_rate),
                                    2);
                            l_ext_markup_mac_cost   :=
                                NVL (l_tot_inv_qty * l_tq_markup, 0);

                            -- End changes by BT Technology Team on 09-Dec-2015 for defect#689
                            IF     c_org.organization_code NOT LIKE 'JP%'
                               AND (l_ext_mat_cost * l_conv_rate) >
                                   l_ext_mac_cost
                            THEN
                                l_iprofit   :=
                                    NVL (
                                          (l_ext_mat_cost * l_conv_rate)
                                        - l_ext_mac_cost,
                                        0);
                            --fnd_file.put (fnd_file.log, 'IN IF c_org.organization_code:'||c_org.organization_code);
                            ELSIF     c_org.organization_code LIKE 'JP%'
                                  -- Start changes by BT Technology Team on 09-Dec-2015 for defect#689
                                  --AND (TO_NUMBER (l_ext_mat_cost) >=
                                  --ROUND (TO_NUMBER (l_ext_markup_mac_cost)))
                                  AND TO_NUMBER (l_ext_markup_mac_cost) >=
                                      ROUND (
                                          TO_NUMBER (NVL (l_ext_mac_cost, 0)))
                            -- End changes by BT Technology Team on 09-Dec-2015 for defect#689
                            THEN
                                l_iprofit   :=
                                      -- Start changes by BT Technology Team on 09-Dec-2015 for defect#689
                                      --(  (TO_NUMBER (l_ext_mat_cost) * l_conv_rate)
                                      -- - ROUND (TO_NUMBER (l_ext_markup_mac_cost)));
                                      TO_NUMBER (l_ext_markup_mac_cost)
                                    - ROUND (
                                          TO_NUMBER (NVL (l_ext_mac_cost, 0)));
                            -- End changes by BT Technology Team on 09-Dec-2015 for defect#689
                            --fnd_file.put (fnd_file.log, 'IN ELSIF c_org.organization_code:'||c_org.organization_code);
                            ELSE
                                l_iprofit   := 0;
                            --fnd_file.put (fnd_file.log, 'IN ELSE c_org.organization_code:'||c_org.organization_code);
                            END IF;

                            --END  code added for DEFECT#2322 TQ MARKUP Eliminaton Logic
                            --Start Changes V2.1
                            IF NVL (p_layered_mrgn, 'N') = 'Y'
                            -- End Changes V2.1
                            THEN
                                fnd_file.put (
                                    fnd_file.output, --Printing Organizational Records
                                       g_delim_char
                                    || NVL (l_default_duty, 0)
                                    || g_delim_char
                                    || NVL (c_detail.onhand_qty, 0)
                                    || g_delim_char
                                    || NVL (l_material_cost, 0)
                                    || g_delim_char
                                    || NVL (l_duty_cost, 0)
                                    || g_delim_char
                                    || NVL (l_freight_du, 0)
                                    || g_delim_char
                                    || NVL (l_freight, 0)
                                    || g_delim_char
                                    || NVL (l_oh_duty, 0)
                                    || g_delim_char
                                    || NVL (l_oh_nonduty, 0)
                                    || g_delim_char
                                    || NVL (l_total_cost, 0)
                                    || g_delim_char
                                    || NVL (l_total_value, 0)
                                    -- Added by BT Technology Team on 12-Jun-2015 for defect#2322
                                    || g_delim_char
                                    --Start Changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                    || NVL (c_detail.rpt_intrans_qty, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_mat_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_duty_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_frt_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_frt_du_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_oh_duty_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_nonoh_duty_val, 0)
                                    || g_delim_char
                                    --End Changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                    --|| NVL (c_detail.rec_intrans_qty, 0) --Added for change 3.2 -- 3.4
                                    --|| g_delim_char             --Added for change 3.2 -- 3.4
                                    --|| l_intrans_rec_val        --Added for change 3.2 -- 3.4
                                    --|| g_delim_char             --Added for change 3.2 -- 3.4
                                    || NVL (l_tot_inv_qty, 0)
                                    || g_delim_char
                                    || NVL (l_tot_inv_val, 0)
                                    || g_delim_char
                                    || NVL (l_ext_mat_cost, 0)
                                    || g_delim_char
                                    || NVL (c_detail.macau_cost, 0)
                                    || g_delim_char
                                    || NVL (l_ext_mac_cost, 0)
                                    --Start Changes V2.1
                                    || g_delim_char
                                    || ROUND (c_detail.avg_mrgn_cst_usd, 2)
                                    || g_delim_char
                                    || ROUND (c_detail.avg_mrgn_cst_local, 2)
                                    || g_delim_char
                                    || ROUND (ln_trx_mrgn_cst_usd, 2)
                                    || g_delim_char
                                    || ROUND (ln_trx_mrgn_cst_local, 2)
                                    || g_delim_char
                                    || ROUND (ln_intst_trx_mrgn_cst_usd, 2)
                                    || g_delim_char
                                    || ROUND (ln_intst_trx_mrgn_cst_local, 2));
                            ELSE
                                fnd_file.put (
                                    fnd_file.output, --Printing Organizational Records
                                       g_delim_char
                                    || NVL (l_default_duty, 0)
                                    || g_delim_char
                                    || NVL (c_detail.onhand_qty, 0)
                                    || g_delim_char
                                    || NVL (l_material_cost, 0)
                                    || g_delim_char
                                    || NVL (l_duty_cost, 0)
                                    || g_delim_char
                                    || NVL (l_freight_du, 0)
                                    || g_delim_char
                                    || NVL (l_freight, 0)
                                    || g_delim_char
                                    || NVL (l_oh_duty, 0)
                                    || g_delim_char
                                    || NVL (l_oh_nonduty, 0)
                                    || g_delim_char
                                    || NVL (l_total_cost, 0)
                                    || g_delim_char
                                    || NVL (l_total_value, 0)
                                    -- Added by BT Technology Team on 12-Jun-2015 for defect#2322
                                    || g_delim_char
                                    --Start Changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                    || NVL (c_detail.rpt_intrans_qty, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_mat_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_duty_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_frt_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_frt_du_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_oh_duty_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_nonoh_duty_val, 0)
                                    || g_delim_char
                                    --End Changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                    --|| NVL(c_detail.rec_intrans_qty, 0) -- Added for change 3.2 -- 3.4
                                    --|| g_delim_char            -- Added for change 3.2 -- 3.4
                                    --|| l_intrans_rec_val       -- Added for change 3.2 -- 3.4
                                    --|| g_delim_char            -- Added for change 3.2 -- 3.4
                                    || NVL (l_tot_inv_qty, 0)
                                    || g_delim_char
                                    || NVL (l_tot_inv_val, 0)
                                    || g_delim_char
                                    || NVL (l_ext_mat_cost, 0)
                                    || g_delim_char
                                    || NVL (c_detail.macau_cost, 0)
                                    || g_delim_char
                                    || NVL (l_ext_mac_cost, 0)
                                    || g_delim_char
                                    || c_detail.avg_mrgn_cst_usd
                                    || g_delim_char
                                    || c_detail.avg_mrgn_cst_local);
                            END IF;

                            --END CHANGES V2.1

                            --Start Changes by BT Technology Team on 23-Jun-2015 for defect#2322
                            -- || NVL (l_ext_mat_cost-l_ext_mac_cost, 0)

                            --End Changes by BT Technology Team on 23-Jun-2015 for defect#2322
                            IF p_tq_japan = 'Y'
                            THEN
                                fnd_file.put (
                                    fnd_file.output,
                                       g_delim_char
                                    || NVL (l_tq_markup, 0)
                                    || g_delim_char
                                    || NVL (l_ext_markup_mac_cost, 0));
                            END IF;
                        --Start changes V3.1 on 05 Jan 2018
                        --                  fnd_file.put (fnd_file.output,
                        --                                g_delim_char || NVL (l_iprofit, 0));
                        --Start changes V3.1 on 05 Jan 2018

                        --  END IF;

                        -- l_total := l_total + NVL (c_detail.onhand_qty, 0);
                        --l_qty_total := l_qty_total + NVL (c_detail.rpt_total_qty, 0);
                        --l_total_mat :=l_total_mat + NVL (c_detail.rpt_total_mat_val, 0);
                        -- l_total_profit_elim :=l_total_profit_elim+ NVL (c_detail.rpt_macau_prof_elim, 0);
                        --Start changes V3.1 on 05 Jan 2018 /**/
                        /*l_tot_onhand_qty :=
                           l_tot_onhand_qty + NVL (c_detail.onhand_qty, 0);
                        l_tot_ext_mat_cost :=
                           l_tot_ext_mat_cost + NVL (l_ext_mat_cost, 0);
                        l_tot_ext_mac_cost :=
                           l_tot_ext_mac_cost + NVL (l_ext_mac_cost, 0);*/
                        --Start Changes by BT Technology Team on 23-Jun-2015 for defect#2322
                        --l_tot_iprofit := l_tot_iprofit + NVL (l_ext_mat_cost-l_ext_mac_cost, 0);
                        /*l_tot_iprofit := l_tot_iprofit + NVL (l_iprofit, 0);*/
                        --End changes V3.1 on 05 Jan 2018
                        --l_tot_tqmarkup := l_tot_tqmarkup + NVL (l_tq_markup,0);
                        --End Changes by BT Technology Team on 23-Jun-2015 for defect#2322
                        END LOOP;

                        -- END Changes by BT Technology Team On 15/01/2015
                        IF l_det_cnt = 0
                        THEN
                            --Start Changes V2.1
                            IF NVL (p_layered_mrgn, 'N') = 'Y'
                            THEN
                                --End Changes V2.1
                                -- Commented by BT Technology Team on 15/01/2015
                                /*IF c_org.is_master_org_id IS NULL
                                  THEN
                                     -- Only add value for System Item Cost if the current org is not the master --
                                     fnd_file.put (fnd_file.output, g_delim_char || '0');
                                  END IF;

                                  fnd_file.put (fnd_file.output,
                                                   g_delim_char
                                                || '0'
                                                || g_delim_char
                                                || '0'
                                                || g_delim_char
                                                || '0'
                                                || g_delim_char
                                                || '0'
                                                || g_delim_char
                                                || '0'
                                                || g_delim_char
                                                || '0'
                                                || g_delim_char
                                                || '0'
                                               );
                                  */
                                fnd_file.put (
                                    fnd_file.output,
                                       g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    --Start Changes V2.1
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''                   --End Changes V2.1
                                         );
                            ELSE
                                fnd_file.put (
                                    fnd_file.output,
                                       g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    --Start Changes V2.1
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || '');
                            --End Changes V2.1
                            END IF;
                        END IF;
                    END LOOP;

                    --Start changes V3.1 on 05 Jan 2018
                    --            fnd_file.put_line (
                    --               fnd_file.output,
                    --                  g_delim_char
                    --               || l_tot_onhand_qty
                    --               || g_delim_char
                    --               || l_tot_ext_mat_cost
                    --               || g_delim_char
                    --               || l_tot_ext_mac_cost
                    --               --|| g_delim_char
                    --               -- || l_tot_tqmarkup
                    --               || g_delim_char
                    --               || l_tot_iprofit);
                    fnd_file.put_line (fnd_file.output, '');
                --End changes V3.1 on 05 Jan 2018
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    do_debug_tools.msg (' others exception: ' || SQLERRM);
                    perrproc   := 2;
                    psqlstat   := SQLERRM;
            END;
        -- Start of Change CCR0008682
        ELSIF p_retrieve_from = 'SNAPSHOT'
        THEN
            ld_snapshot_date   := NULL;

            --      select to_char(max(snapshot_date),'DD-MON-RRRR')
            --        INTO ld_snapshot_date
            --        FROM xxdo.xxd_cst_item_cost_details_t;
            IF NVL (p_debug_level, 0) > 0
            THEN
                do_debug_tools.enable_conc_log (p_debug_level);
            END IF;

            do_debug_tools.msg ('+' || l_proc_name);
            do_debug_tools.msg (
                   'p_inv_org_id='
                || p_inv_org_id
                || ', p_region='
                || p_region
                || ', p_as_of_date='
                || NVL (p_as_of_date, '{None}')
                || ', p_brand='
                || p_brand
                || ', p_master_inv_org_id='
                || NVL (TO_CHAR (p_master_inv_org_id), '{None}')
                || ', p_xfer_price_list_id='
                || NVL (TO_CHAR (p_xfer_price_list_id), '{None}')
                || ', p_duty_override='
                || NVL (TO_CHAR (p_duty_override), '{None}')
                || ', p_summary='
                || p_summary
                || ', p_include_analysis='
                || p_include_analysis
                || ', p_use_accrual_vals='
                || p_use_accrual_vals);

            BEGIN
                -- Start Changes by BT Technology Team on 23/01/2014
                SELECT organization_id
                  INTO g_def_macau_inv_org_id
                  FROM mtl_parameters
                 WHERE organization_code = 'MC1';

                -- End Changes by BT Technology Team on 23/01/2014
                IF p_inv_org_id IS NULL AND p_region IS NULL
                THEN
                    raise_application_error (
                        -20001,
                        'Either an inventory organization or region must be specified');
                END IF;

                l_use_accrual_vals   :=
                    NVL (SUBSTR (p_use_accrual_vals, 1, 1), 'Y');

                IF p_as_of_date IS NOT NULL
                THEN
                    l_use_date   :=
                        TO_DATE (p_as_of_date, 'RRRR/MM/DD HH24:MI:SS') + 1;
                ELSE
                    l_use_date   := TRUNC (SYSDATE) + 1;
                END IF;

                ld_snapshot_date   :=
                    TO_CHAR (TO_DATE (l_use_date - 1), 'DD-MON-YYYY');

                IF l_macau_inv_org_id IS NULL
                THEN
                    do_debug_tools.msg (
                        ' obtaining Macau inventory organization');
                    l_macau_inv_org_id   :=
                        TO_NUMBER (
                            fnd_profile.VALUE ('XXDOINV_MACAU_INV_ORG_ID'));

                    IF l_macau_inv_org_id IS NULL
                    THEN
                        l_macau_inv_org_id   := g_def_macau_inv_org_id;
                    END IF;
                END IF;

                do_debug_tools.msg (
                       ' using '
                    || l_macau_inv_org_id
                    || ' for Macau inventory organization');
                do_debug_tools.msg (' loading inventory organizations');

                INSERT INTO xxdo.xxdoinv_cir_orgs (organization_id,
                                                   is_master_org_id,
                                                   primary_cost_method)
                    (SELECT organization_id, 1, primary_cost_method
                       FROM apps.mtl_parameters
                      WHERE organization_id = p_master_inv_org_id);

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' record(s) for the master inventory organization '
                    || p_master_inv_org_id);

                INSERT INTO xxdo.xxdoinv_cir_orgs (organization_id,
                                                   is_master_org_id,
                                                   primary_cost_method)
                    (SELECT organization_id, NULL, primary_cost_method
                       FROM apps.mtl_parameters
                      WHERE     organization_id = NVL (p_inv_org_id, -1)
                            AND organization_id != p_master_inv_org_id
                     UNION
                     SELECT mp.organization_id, NULL, mp.primary_cost_method
                       FROM apps.mtl_parameters mp, hr_all_organization_units haou
                      WHERE     mp.attribute1 = p_region
                            AND mp.organization_id != p_master_inv_org_id
                            AND haou.organization_id = mp.organization_id
                            AND NVL (haou.date_to, SYSDATE + 1) >=
                                TRUNC (SYSDATE)
                            AND p_inv_org_id IS NULL
                            AND EXISTS
                                    (SELECT NULL
                                       FROM mtl_secondary_inventories msi
                                      WHERE msi.organization_id =
                                            mp.organization_id));

                --         fnd_file.put_line (fnd_file.LOG, 'DATE NOT INSERTED INTO THE TABLE');
                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' non-master inventory organization record(s)');
                do_debug_tools.msg (' loading inventory values');

                -- 3.5 calling the load temp table
                IF p_inv_org_id = 126
                THEN
                    BEGIN
                        SELECT category_set_id
                          INTO g_category_set_id
                          FROM mtl_category_sets
                         WHERE category_set_name = g_category_set_name;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            raise_application_error (
                                -20001,
                                'Sales Category Not defined.');
                    END;

                    debug_msg (
                           ' Start temp At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                    do_debug_tools.msg ('  calling load_temp_table.');
                    load_temp_table (p_as_of_date       => l_use_date - 1,
                                     p_inv_org_id       => p_inv_org_id,
                                     p_cost_type_id     => NULL,
                                     x_ret_stat         => l_ret_stat,
                                     x_error_messages   => l_err_messages);
                    do_debug_tools.msg (
                           '  call to load_temp_table returned '
                        || l_ret_stat
                        || '.  '
                        || l_err_messages);
                    debug_msg (
                           ' End temp At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    debug_msg (
                           ' Start Insert At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

                    debug_msg (
                           ' End Insert At '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
                END IF;                                --added V1.9 CCR0009519


                --3.5 changes end

                INSERT INTO xxdo.xxdoinv_cir_data (tpe,
                                                   organization_id,
                                                   inventory_item_id,
                                                   quantity,
                                                   rcv_transaction_id,
                                                   trx_material_cost,
                                                   trx_freight_cost,
                                                   trx_duty_cost,
                                                   itm_material_cost)
                    (                                            -- On-Hand --
                       SELECT 'ONHAND' AS tpe,
                              moqd.organization_id,
                              moqd.inventory_item_id,
                              SUM (moqd.transaction_quantity) AS quantity,
                              TO_NUMBER (NULL) AS rcv_transaction_id,
                              xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                  'MATERIAL',
                                  moqd.organization_id,
                                  moqd.inventory_item_id,
                                  'N',
                                  l_use_date - 1                         --3.1
                                                ) AS trx_material_cost,
                              TO_NUMBER (NULL) AS trx_freight_cost,
                              TO_NUMBER (NULL) AS trx_duty_cost,
                              xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                  'MATERIAL',
                                  moqd.organization_id,
                                  moqd.inventory_item_id,
                                  'N',
                                  l_use_date - 1                         --3.1
                                                ) AS itm_material_cost
                         FROM apps.mtl_secondary_inventories msi, apps.mtl_onhand_quantities moqd, xxdo.xxdoinv_cir_orgs xco
                        WHERE     moqd.organization_id = xco.organization_id
                              AND msi.organization_id = moqd.organization_id
                              AND msi.secondary_inventory_name =
                                  moqd.subinventory_code
                              AND msi.asset_inventory = 1
                              --                      AND moqd.inventory_item_id = 900326186
                              AND msi.secondary_inventory_name NOT IN
                                      -- Start Changes by BT Technology Team on 23/01/2014

                                      -- ('QCFAIL', 'QCB', 'REJ', 'REJECTS', 'QCFAIL')
                                      (SELECT ff2.flex_value
                                         FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ff2
                                        WHERE     ff1.flex_value_set_id =
                                                  ff2.flex_value_set_id
                                              AND UPPER (
                                                      ff1.flex_value_set_name) =
                                                  UPPER (
                                                      'XXDO_SECONDARY_INV_NAME')
                                              AND SYSDATE BETWEEN NVL (
                                                                      ff2.start_date_active,
                                                                        SYSDATE
                                                                      - 1)
                                                              AND NVL (
                                                                      ff2.end_date_active,
                                                                        SYSDATE
                                                                      + 1)
                                              AND ff2.enabled_flag = 'Y')
                     -- End changes by BT Technology Team On 23/01/2014
                     GROUP BY moqd.inventory_item_id, moqd.organization_id
                     UNION ALL
                       SELECT 'ONHAND' AS tpe,
                              mmt.organization_id,
                              mmt.inventory_item_id,
                              SUM (-mmt.primary_quantity) AS quantity,
                              TO_NUMBER (NULL) AS rcv_transaction_id,
                              xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                  'MATERIAL',
                                  mmt.organization_id,
                                  mmt.inventory_item_id,
                                  'N',
                                  l_use_date - 1                         --3.1
                                                ) AS trx_material_cost,
                              TO_NUMBER (NULL) AS trx_freight_cost,
                              TO_NUMBER (NULL) AS trx_duty_cost,
                              xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                  'MATERIAL',
                                  mmt.organization_id,
                                  mmt.inventory_item_id,
                                  'N',
                                  l_use_date - 1                         --3.1
                                                ) AS itm_material_cost
                         FROM apps.mtl_secondary_inventories msi, apps.mtl_material_transactions mmt, xxdo.xxdoinv_cir_orgs xco
                        WHERE     mmt.organization_id = xco.organization_id
                              AND mmt.transaction_date >= l_use_date
                              --                      AND mmt.inventory_item_id = 900326186
                              AND msi.organization_id = mmt.organization_id
                              AND msi.secondary_inventory_name =
                                  mmt.subinventory_code
                              AND msi.asset_inventory = 1
                              AND msi.secondary_inventory_name NOT IN
                                      -- Start changes by BT Technology Team On 23/01/2014

                                      -- ('QCFAIL', 'QCB', 'REJ', 'REJECTS', 'QCFAIL')
                                      (SELECT ff2.flex_value
                                         FROM fnd_flex_value_sets ff1, fnd_flex_values_vl ff2
                                        WHERE     ff1.flex_value_set_id =
                                                  ff2.flex_value_set_id
                                              AND UPPER (
                                                      ff1.flex_value_set_name) =
                                                  UPPER (
                                                      'XXDO_SECONDARY_INV_NAME')
                                              AND SYSDATE BETWEEN NVL (
                                                                      ff2.start_date_active,
                                                                        SYSDATE
                                                                      - 1)
                                                              AND NVL (
                                                                      ff2.end_date_active,
                                                                        SYSDATE
                                                                      + 1)
                                              AND ff2.enabled_flag = 'Y')
                     -- End changes by BT Technology Team On 23/01/2014
                     GROUP BY mmt.organization_id, mmt.inventory_item_id
                     UNION ALL
                     SELECT 'B2B' AS tpe,
                            rsl.to_organization_id,
                            rsl.item_id AS inventory_item_id,
                            NVL (
                                (SELECT SUM (rt.quantity)
                                   FROM apps.rcv_transactions rt
                                  WHERE     rt.transaction_type = 'DELIVER'
                                        AND rt.shipment_line_id =
                                            rsl.shipment_line_id
                                        AND rt.transaction_date >= l_use_date),
                                0) AS quantity,
                            TO_NUMBER (NULL) AS rcv_transaction_id,
                            xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                'MATERIAL',
                                rsl.to_organization_id,
                                rsl.item_id,
                                'N',
                                l_use_date - 1                           --3.1
                                              ) AS trx_material_cost,
                            TO_NUMBER (NULL) AS trx_freight_cost,
                            TO_NUMBER (NULL) AS trx_duty_cost,
                            xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                'MATERIAL',
                                rsl.to_organization_id,
                                rsl.item_id,
                                'N',
                                l_use_date - 1                           --3.1
                                              ) AS itm_material_cost
                       FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, xxdo.xxdoinv_cir_orgs xco
                      WHERE     rsl.to_organization_id = xco.organization_id
                            AND rsl.source_document_code = 'REQ'
                            --                    AND rsl.item_id = 900326186
                            AND rsl.shipment_header_id =
                                rsh.shipment_header_id
                            AND rsh.shipped_date < l_use_date
                            AND EXISTS
                                    (SELECT NULL
                                       FROM apps.rcv_transactions rt
                                      WHERE     rt.transaction_type =
                                                'DELIVER'
                                            AND rt.shipment_line_id =
                                                rsl.shipment_line_id
                                            AND rt.transaction_date >=
                                                l_use_date)
                            -- 3.5 changes start
                            AND rsl.to_organization_id NOT IN
                                    (SELECT ood.organization_id
                                       FROM fnd_lookup_values fl, org_organization_definitions ood
                                      WHERE     fl.lookup_type =
                                                'XDO_PO_STAND_RECEIPT_ORGS'
                                            AND fl.meaning =
                                                ood.organization_code) --Added for change 3.3
                     -- 3.5 changes end
                     --   and not exists (select null from do_custom.do_ora_items_all_v doiav where doiav.organization_id = rsl.to_organization_id and doiav.inventory_item_id = rsl.item_id and doiav.product = 'FOWNES')
                     UNION ALL
                     SELECT 'B2B'
                                AS tpe,
                            rsl.to_organization_id,
                            rsl.item_id
                                AS inventory_item_id,
                            rsl.quantity_shipped - rsl.quantity_received
                                AS quantity,
                            TO_NUMBER (NULL)
                                AS rcv_transaction_id,
                            xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                'MATERIAL',
                                rsl.to_organization_id,
                                rsl.item_id,
                                'N',
                                l_use_date - 1                           --3.1
                                              )
                                AS trx_material_cost,
                            TO_NUMBER (NULL)
                                AS trx_freight_cost,
                            TO_NUMBER (NULL)
                                AS trx_duty_cost,
                            xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                'MATERIAL',
                                rsl.to_organization_id,
                                rsl.item_id,
                                'N',
                                l_use_date - 1                           --3.1
                                              )
                                AS itm_material_cost
                       FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, xxdo.xxdoinv_cir_orgs xco
                      WHERE     rsl.to_organization_id = xco.organization_id
                            AND rsl.source_document_code = 'REQ'
                            --                    AND rsl.item_id = 900326186
                            AND rsh.shipment_header_id =
                                rsl.shipment_header_id
                            AND rsh.shipped_date < l_use_date
                            AND quantity_received < quantity_shipped
                            -- 3.5 changes start
                            AND rsl.to_organization_id NOT IN
                                    (SELECT ood.organization_id
                                       FROM fnd_lookup_values fl, org_organization_definitions ood
                                      WHERE     fl.lookup_type =
                                                'XDO_PO_STAND_RECEIPT_ORGS'
                                            AND fl.meaning =
                                                ood.organization_code)
                     -- 3.5 changes end
                     --   and not exists (select null from do_custom.do_ora_items_all_v doiav where doiav.organization_id = rsl.to_organization_id and doiav.inventory_item_id = rsl.item_id and doiav.product = 'FOWNES')
                     UNION ALL
                       SELECT 'RD'
                                  AS tpe,
                              organization_id,
                              inventory_item_id,
                              SUM (quantity)
                                  AS quantity,
                              rcv_transaction_id,
                              NVL (
                                  (SELECT MAX (po_unit_price)
                                     FROM xxdo.xxdopo_accrual_lines xal
                                    WHERE xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id),
                                  xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                      'MATERIAL',
                                      alpha.organization_id,
                                      alpha.inventory_item_id,
                                      'N',
                                      l_use_date - 1                     --3.1
                                                    ))
                                  AS trx_material_cost,
                              (SELECT amount_total / quantity_total
                                 FROM xxdo.xxdopo_accrual_lines xal
                                WHERE     xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id
                                      AND xal.accrual_type = 'Freight')
                                  AS trx_freight_cost,
                              (SELECT amount_total / quantity_total
                                 FROM xxdo.xxdopo_accrual_lines xal
                                WHERE     xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id
                                      AND xal.accrual_type = 'Duty')
                                  AS trx_duty_cost,
                              xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                  'MATERIAL',
                                  alpha.organization_id,
                                  alpha.inventory_item_id,
                                  'N',
                                  l_use_date - 1                         --3.1
                                                )
                                  AS itm_material_cost
                         FROM (  SELECT ms.to_organization_id AS organization_id,
                                        pol.item_id AS inventory_item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('ACCEPT', 'REJECT', 'TRANSFER')
                                            THEN
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    ms.rcv_transaction_id)
                                            ELSE
                                                ms.rcv_transaction_id
                                        END AS rcv_transaction_id,
                                        SUM (ms.to_org_primary_quantity) AS quantity
                                   FROM mtl_supply ms, rcv_transactions rt, po_lines_all pol,
                                        xxdo.xxdoinv_cir_orgs xco
                                  WHERE     ms.to_organization_id =
                                            xco.organization_id
                                        AND ms.supply_type_code = 'RECEIVING'
                                        AND rt.transaction_id =
                                            ms.rcv_transaction_id
                                        AND NVL (rt.consigned_flag, 'N') = 'N'
                                        --                                AND pol.item_id = 900326186
                                        AND rt.source_document_code = 'PO'
                                        AND pol.po_line_id = rt.po_line_id
                               GROUP BY ms.to_organization_id,
                                        pol.item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('ACCEPT', 'REJECT', 'TRANSFER')
                                            THEN
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    ms.rcv_transaction_id)
                                            ELSE
                                                ms.rcv_transaction_id
                                        END
                               UNION ALL
                                 SELECT rt.organization_id,
                                        pol.item_id AS inventory_item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('RECEIVE', 'MATCH')
                                            THEN
                                                rt.transaction_id
                                            ELSE
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    rt.transaction_id)
                                        END AS rcv_transaction_id,
                                        SUM (
                                            DECODE (
                                                rt.transaction_type,
                                                'RECEIVE', -1 * rt.primary_quantity,
                                                'DELIVER', 1 * rt.primary_quantity,
                                                'RETURN TO RECEIVING', -1 * rt.primary_quantity,
                                                'RETURN TO VENDOR', DECODE (
                                                                        parent_rt.transaction_type,
                                                                        'UNORDERED', 0,
                                                                        1 * rt.primary_quantity),
                                                'MATCH', -1 * rt.primary_quantity,
                                                'CORRECT', DECODE (
                                                               parent_rt.transaction_type,
                                                               'UNORDERED', 0,
                                                               'RECEIVE', -1 * rt.primary_quantity,
                                                               'DELIVER', 1 * rt.primary_quantity,
                                                               'RETURN TO RECEIVING',   -1
                                                                                      * rt.primary_quantity,
                                                               'RETURN TO VENDOR', DECODE (
                                                                                       grparent_rt.transaction_type,
                                                                                       'UNORDERED', 0,
                                                                                         1
                                                                                       * rt.primary_quantity),
                                                               'MATCH', -1 * rt.primary_quantity,
                                                               0),
                                                0)) quantity
                                   FROM rcv_transactions rt, rcv_transactions parent_rt, rcv_transactions grparent_rt,
                                        po_lines_all pol, xxdo.xxdoinv_cir_orgs xco
                                  WHERE     rt.organization_id =
                                            xco.organization_id
                                        AND NVL (rt.consigned_flag, 'N') = 'N'
                                        AND NVL (rt.dropship_type_code, 3) = 3
                                        AND rt.transaction_date > l_use_date
                                        --                                AND pol.item_id = 900326186
                                        AND rt.transaction_type IN
                                                (                 --'RECEIVE',
                                                 'RECEIVE', --Added for change 3.3
                                                            'DELIVER', 'RETURN TO RECEIVING',
                                                 'RETURN TO VENDOR', 'CORRECT', 'MATCH')
                                        AND rt.source_document_code = 'PO'
                                        AND DECODE (rt.parent_transaction_id,
                                                    -1, NULL,
                                                    0, NULL,
                                                    rt.parent_transaction_id) =
                                            parent_rt.transaction_id(+)
                                        AND DECODE (
                                                parent_rt.parent_transaction_id,
                                                -1, NULL,
                                                0, NULL,
                                                parent_rt.parent_transaction_id) =
                                            grparent_rt.transaction_id(+)
                                        AND pol.po_line_id = rt.po_line_id
                                        AND rt.organization_id NOT IN
                                                (SELECT ood.organization_id
                                                   FROM fnd_lookup_values fl, org_organization_definitions ood
                                                  WHERE     fl.lookup_type =
                                                            'XDO_PO_STAND_RECEIPT_ORGS'
                                                        AND fl.meaning =
                                                            ood.organization_code)
                               --Added for change 3.3
                               GROUP BY rt.organization_id,
                                        pol.item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('RECEIVE', 'MATCH')
                                            THEN
                                                rt.transaction_id
                                            ELSE
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    rt.transaction_id)
                                        END
                                 HAVING SUM (
                                            DECODE (
                                                rt.transaction_type,
                                                'RECEIVE', -1 * rt.primary_quantity,
                                                'DELIVER', 1 * rt.primary_quantity,
                                                'RETURN TO RECEIVING', -1 * rt.primary_quantity,
                                                'RETURN TO VENDOR', DECODE (
                                                                        parent_rt.transaction_type,
                                                                        'UNORDERED', 0,
                                                                        1 * rt.primary_quantity),
                                                'MATCH', -1 * rt.primary_quantity,
                                                'CORRECT', DECODE (
                                                               parent_rt.transaction_type,
                                                               'UNORDERED', 0,
                                                               'RECEIVE',   -1
                                                                          * rt.primary_quantity,
                                                               'DELIVER',   1
                                                                          * rt.primary_quantity,
                                                               'RETURN TO RECEIVING',   -1
                                                                                      * rt.primary_quantity,
                                                               'RETURN TO VENDOR', DECODE (
                                                                                       grparent_rt.transaction_type,
                                                                                       'UNORDERED', 0,
                                                                                         1
                                                                                       * rt.primary_quantity),
                                                               'MATCH', -1 * rt.primary_quantity,
                                                               0),
                                                0)) <>
                                        0) alpha
                     GROUP BY organization_id, inventory_item_id, rcv_transaction_id
                       HAVING SUM (quantity) != 0
                     UNION ALL
                       /*Start of changes for 3.2*/
                       SELECT 'B2B'
                                  AS tpe,
                              organization_id,
                              inventory_item_id,
                              SUM (quantity)
                                  AS quantity,
                              rcv_transaction_id,
                              NVL (
                                  (SELECT MAX (po_unit_price)
                                     FROM xxdo.xxdopo_accrual_lines xal
                                    WHERE xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id),
                                  apps.xxdoget_item_cost ('MATERIAL', alpha.organization_id, alpha.inventory_item_id
                                                          , 'N'))
                                  AS trx_material_cost,
                              (SELECT amount_total / quantity_total
                                 FROM xxdo.xxdopo_accrual_lines xal
                                WHERE     xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id
                                      AND xal.accrual_type = 'Freight')
                                  AS trx_freight_cost,
                              (SELECT amount_total / quantity_total
                                 FROM xxdo.xxdopo_accrual_lines xal
                                WHERE     xal.rcv_transaction_id =
                                          alpha.rcv_transaction_id
                                      AND xal.accrual_type = 'Duty')
                                  AS trx_duty_cost,
                              apps.xxdoget_item_cost ('MATERIAL', alpha.organization_id, alpha.inventory_item_id
                                                      , 'N')
                                  AS itm_material_cost
                         FROM (  SELECT ms.to_organization_id AS organization_id,
                                        pol.item_id AS inventory_item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('ACCEPT', 'REJECT', 'TRANSFER')
                                            THEN
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    ms.rcv_transaction_id)
                                            ELSE
                                                ms.rcv_transaction_id
                                        END AS rcv_transaction_id,
                                        SUM (ms.to_org_primary_quantity) AS quantity
                                   FROM mtl_supply ms, rcv_transactions rt, po_requisition_lines_all pol,
                                        xxdo.xxdoinv_cir_orgs xco
                                  WHERE     ms.to_organization_id =
                                            xco.organization_id
                                        AND ms.supply_type_code = 'RECEIVING'
                                        --                                AND pol.item_id = 900326186
                                        AND rt.transaction_id =
                                            ms.rcv_transaction_id
                                        AND NVL (rt.consigned_flag, 'N') = 'N'
                                        AND rt.source_document_code = 'REQ'
                                        AND pol.requisition_line_id =
                                            rt.requisition_line_id
                                        -- 3.5 changes start
                                        AND rt.organization_id NOT IN
                                                (SELECT ood.organization_id
                                                   FROM fnd_lookup_values fl, org_organization_definitions ood
                                                  WHERE     fl.lookup_type =
                                                            'XDO_PO_STAND_RECEIPT_ORGS'
                                                        AND fl.meaning =
                                                            ood.organization_code)
                               -- 3.5 changes end
                               GROUP BY ms.to_organization_id,
                                        pol.item_id,
                                        CASE
                                            WHEN NVL (rt.transaction_type, ' ') IN
                                                     ('ACCEPT', 'REJECT', 'TRANSFER')
                                            THEN
                                                apps.cst_inventory_pvt.get_parentreceivetxn (
                                                    ms.rcv_transaction_id)
                                            ELSE
                                                ms.rcv_transaction_id
                                        END/*UNION ALL
                                             SELECT rt.organization_id,
                                                    pol.item_id AS inventory_item_id,
                                                    CASE
                                                      WHEN NVL (rt.transaction_type, ' ') IN
                                                               ('RECEIVE', 'MATCH')
                                                       THEN
                                                          rt.transaction_id
                                                       ELSE
                                                          apps.cst_inventory_pvt.get_parentreceivetxn (
                                                             rt.transaction_id)
                                                    END
                                                       AS rcv_transaction_id,
                                                    SUM (
                                                       DECODE (
                                                          rt.transaction_type,
                                                          'RECEIVE', -1 * rt.primary_quantity,
                                                          'DELIVER', 1 * rt.primary_quantity,
                                                          'RETURN TO RECEIVING',   -1
                                                                                 * rt.primary_quantity,
                                                          'RETURN TO VENDOR', DECODE (
                                                                                 parent_rt.transaction_type,
                                                                                 'UNORDERED', 0,
                                                                                   1
                                                                                 * rt.primary_quantity),
                                                          'MATCH', -1 * rt.primary_quantity,
                                                          'CORRECT', DECODE (
                                                                        parent_rt.transaction_type,
                                                                        'UNORDERED', 0,
                                                                        'RECEIVE',   -1
                                                                                   * rt.primary_quantity,
                                                                        'DELIVER',   1
                                                                                   * rt.primary_quantity,
                                                                        'RETURN TO RECEIVING',   -1
                                                                                               * rt.primary_quantity,
                                                                        'RETURN TO VENDOR', DECODE (
                                                                                               grparent_rt.transaction_type,
                                                                                               'UNORDERED', 0,
                                                                                                 1
                                                                                               * rt.primary_quantity),
                                                                        'MATCH',   -1
                                                                                 * rt.primary_quantity,
                                                                        0),
                                                          0))
                                                       quantity
                                               FROM rcv_transactions rt,
                                                    rcv_transactions parent_rt,
                                                    rcv_transactions grparent_rt,
                                                    po_requisition_lines_all pol,
                                                    xxdo.xxdoinv_cir_orgs xco
                                              WHERE     rt.organization_id = xco.organization_id
                                                    AND NVL (rt.consigned_flag, 'N') = 'N'
                                                    AND NVL (rt.dropship_type_code, 3) = 3
                    --                                AND pol.item_id = 900326186
                                                    AND rt.transaction_date > l_use_date
                                                    AND rt.transaction_type IN
                                                           ('RECEIVE',
                                                            'DELIVER',
                                                            'RETURN TO RECEIVING',
                                                            'RETURN TO VENDOR',
                                                            'CORRECT',
                                                            'MATCH')
                                                    AND rt.source_document_code = 'REQ'
                                                    AND DECODE (rt.parent_transaction_id,
                                                                -1, NULL,
                                                                0, NULL,
                                                                rt.parent_transaction_id) =
                                                           parent_rt.transaction_id(+)
                                                    AND DECODE (parent_rt.parent_transaction_id,
                                                                -1, NULL,
                                                                0, NULL,
                                                                parent_rt.parent_transaction_id) =
                                                           grparent_rt.transaction_id(+)
                                                    AND pol.requisition_line_id = rt.requisition_line_id
                                           GROUP BY rt.organization_id,
                                                    pol.item_id,
                                                    CASE
                                                       WHEN NVL (rt.transaction_type, ' ') IN
                                                               ('RECEIVE', 'MATCH')
                                                       THEN
                                                          rt.transaction_id
                                                       ELSE
                                                          apps.cst_inventory_pvt.get_parentreceivetxn (
                                                             rt.transaction_id)
                                                    END
                                             HAVING SUM (
                                                       DECODE (
                                                          rt.transaction_type,
                                                          'RECEIVE', -1 * rt.primary_quantity,
                                                          'DELIVER', 1 * rt.primary_quantity,
                                                          'RETURN TO RECEIVING',   -1
                                                                                 * rt.primary_quantity,
                                                          'RETURN TO VENDOR', DECODE (
                                                                                 parent_rt.transaction_type,
                                                                                 'UNORDERED', 0,
                                                                                   1
                                                                                 * rt.primary_quantity),
                                                          'MATCH', -1 * rt.primary_quantity,
                                                          'CORRECT', DECODE (
                                                                        parent_rt.transaction_type,
                                                                        'UNORDERED', 0,
                                                                        'RECEIVE',   -1
                                                                                   * rt.primary_quantity,
                                                                        'DELIVER',   1
                                                                                   * rt.primary_quantity,
                                                                        'RETURN TO RECEIVING',   -1
                                                                                               * rt.primary_quantity,
                                                                        'RETURN TO VENDOR', DECODE (
                                                                                               grparent_rt.transaction_type,
                                                                                               'UNORDERED', 0,
                                                                                                 1
                                                                                               * rt.primary_quantity),
                                                                        'MATCH',   -1
                                                                                 * rt.primary_quantity,
                                                                        0),
                                                          0)) <> 0*/
                                           --Commented for change 3.3
                                           ) alpha
                     GROUP BY organization_id, inventory_item_id, rcv_transaction_id
                       HAVING SUM (quantity) != 0
                     /*End of changes for 3.2*/
                     -- 3.5 changes start
                     UNION ALL
                     SELECT 'B2B'
                                AS tpe,
                            rsl.to_organization_id,
                            rsl.item_id
                                AS inventory_item_id,
                            qty.rollback_qty
                                AS quantity,
                            TO_NUMBER (NULL)
                                AS rcv_transaction_id,
                            apps.xxdoget_item_cost ('MATERIAL', rsl.to_organization_id, rsl.item_id
                                                    , 'N')
                                AS trx_material_cost,
                            TO_NUMBER (NULL)
                                AS trx_freight_cost,
                            TO_NUMBER (NULL)
                                AS trx_duty_cost,
                            apps.xxdoget_item_cost ('MATERIAL', rsl.to_organization_id, rsl.item_id
                                                    , 'N')
                                AS itm_material_cost
                       FROM cst_item_list_temp item, cst_inv_qty_temp qty, xxd_common_items_v citv,
                            mtl_parameters mp, cst_inv_cost_temp COST, rcv_shipment_lines rsl,
                            rcv_shipment_headers rsh, xxdo.xxdoinv_cir_orgs xco
                      WHERE     qty.inventory_item_id =
                                item.inventory_item_id
                            AND qty.cost_type_id = item.cost_type_id
                            AND qty.organization_id = xco.organization_id
                            AND citv.organization_id = qty.organization_id
                            AND citv.inventory_item_id =
                                qty.inventory_item_id
                            AND citv.category_set_id = 1
                            AND mp.organization_id = qty.organization_id
                            AND COST.organization_id(+) = qty.organization_id
                            AND COST.inventory_item_id(+) =
                                qty.inventory_item_id
                            AND COST.cost_type_id(+) = qty.cost_type_id
                            AND rsl.shipment_line_id = qty.shipment_line_id
                            AND rsh.shipment_header_id =
                                rsl.shipment_header_id
                            AND (rsh.shipped_date IS NOT NULL AND rsh.shipped_date < TO_DATE (NVL (l_use_date, SYSDATE)))
                            AND rsl.creation_date <
                                TO_DATE (NVL (l_use_date, TRUNC (SYSDATE)))
                            AND rsl.to_organization_id IN
                                    (SELECT ood.organization_id
                                       FROM fnd_lookup_values fl, org_organization_definitions ood
                                      WHERE     fl.lookup_type =
                                                'XDO_PO_STAND_RECEIPT_ORGS'
                                            AND fl.meaning =
                                                ood.organization_code)-- 3.5 changes end

                                                                      );

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' inventory value record(s)');

                UPDATE xxdo.xxdoinv_cir_data
                   SET accrual_missing   = 1
                 WHERE     tpe = 'RD'
                       AND (trx_freight_cost IS NULL OR trx_duty_cost IS NULL);

                do_debug_tools.msg (
                       ' updated '
                    || SQL%ROWCOUNT
                    || ' receive/deliver record(s) with missing accruals');
                do_debug_tools.msg (
                    ' loading master organization item costs');

                INSERT INTO xxdo.xxdoinv_cir_master_item_cst (
                                organization_id,
                                inventory_item_id,
                                material_cost,
                                freight_cost,
                                duty_cost,
                                duty_rate,
                                macau_cost,
                                is_direct_import_sku)
                    (SELECT DISTINCT
                            xco.organization_id,
                            xcd.inventory_item_id,
                            xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                'MATERIAL',
                                xco.organization_id,
                                xcd.inventory_item_id,
                                'N',
                                l_use_date - 1                           --3.1
                                              ) AS material_cost,
                            CASE
                                WHEN xco.primary_cost_method = 1
                                THEN
                                    -- Standard Cost --
                                    xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                        'STDFREIGHT',
                                        xco.organization_id,
                                        xcd.inventory_item_id,
                                        'N',
                                        l_use_date - 1                   --3.1
                                                      )
                                ELSE
                                    -- Layered Cost --
                                    DECODE (
                                        xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'FIFOFREIGHT',
                                            xco.organization_id,
                                            xcd.inventory_item_id,
                                            'N',
                                            l_use_date - 1               --3.1
                                                          ),
                                        0,   xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                                 'FREIGHTRATE',
                                                 xco.organization_id,
                                                 xcd.inventory_item_id,
                                                 'N',
                                                 l_use_date - 1          --3.1
                                                               )
                                           * xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                                 'MATERIAL',
                                                 xco.organization_id,
                                                 xcd.inventory_item_id,
                                                 'N',
                                                 l_use_date - 1          --3.1
                                                               ),
                                        xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'FIFOFREIGHT',
                                            xco.organization_id,
                                            xcd.inventory_item_id,
                                            'N',
                                            l_use_date - 1               --3.1
                                                          ))
                            END AS freight_cost,
                            CASE
                                WHEN xco.primary_cost_method = 1
                                THEN
                                    -- Standard Cost --
                                    DECODE (
                                        xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'STDDUTY',
                                            xco.organization_id,
                                            xcd.inventory_item_id,
                                            'N',
                                            l_use_date - 1               --3.1
                                                          ),
                                        0,   (p_duty_override / 100)
                                           * xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                                 'MATERIAL',
                                                 xco.organization_id,
                                                 xcd.inventory_item_id,
                                                 'N',
                                                 l_use_date - 1          --3.1
                                                               ),
                                        xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'STDDUTY',
                                            xco.organization_id,
                                            xcd.inventory_item_id,
                                            'N',
                                            l_use_date - 1               --3.1
                                                          ))
                                ELSE
                                    -- Layered Cost --
                                    DECODE (
                                        xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'FIFODUTY',
                                            xco.organization_id,
                                            xcd.inventory_item_id,
                                            'N',
                                            l_use_date - 1               --3.1
                                                          ),
                                        0,   (p_duty_override / 100)
                                           * xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                                 'MATERIAL',
                                                 xco.organization_id,
                                                 xcd.inventory_item_id,
                                                 'N',
                                                 l_use_date - 1          --3.1
                                                               ),
                                        xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'FIFODUTY',
                                            xco.organization_id,
                                            xcd.inventory_item_id,
                                            'N',
                                            l_use_date - 1               --3.1
                                                          ))
                            END AS duty_cost,
                            DECODE (xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                        'EURATE',
                                        xco.organization_id,
                                        xcd.inventory_item_id,
                                        'N',
                                        l_use_date - 1                   --3.1
                                                      ),
                                    0, (p_duty_override / 100),
                                    xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                        'EURATE',
                                        xco.organization_id,
                                        xcd.inventory_item_id,
                                        'N',
                                        l_use_date - 1                   --3.1
                                                      )) AS duty_rate,
                            DECODE (
                                xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                    'ITEMCOST',
                                    l_macau_inv_org_id,
                                    xcd.inventory_item_id,
                                    'N',
                                    l_use_date - 1                       --3.1
                                                  ),
                                0, NVL (
                                       (SELECT msib_macau.list_price_per_unit
                                          FROM apps.mtl_system_items_b msib_macau
                                         WHERE     msib_macau.organization_id =
                                                   l_macau_inv_org_id
                                               AND msib_macau.inventory_item_id =
                                                   xcd.inventory_item_id),
                                       0),
                                xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                    'ITEMCOST',
                                    l_macau_inv_org_id,
                                    xcd.inventory_item_id,
                                    'N',
                                    l_use_date - 1                       --3.1
                                                  )) AS macau_cost,
                            -- End for Incident INC0299210
                            NVL (
                                (SELECT MAX ('Y')
                                   -- FROM apps.mtl_system_items_b msib                             --commented by BT Team on 02/01/2015
                                   FROM apps.xxd_common_items_v msib
                                  --added by BT team on 02/01/2015
                                  WHERE     msib.organization_id =
                                            xcd.organization_id
                                        AND msib.inventory_item_id =
                                            xcd.inventory_item_id
                                        --  AND SUBSTR (msib.segment1, 1, 2) IN                                             --commented by BT Team on 02/01/2015
                                        AND SUBSTR (msib.style_number, 1, 2) IN
                                                ('U0', 'U1', 'U2',
                                                 'U3', 'U4', 'U5',
                                                 'U6', 'U7', 'U8',
                                                 'U9')-- Replicated from old CIR logic to identify FOWNES SKU's --
                                                      ),
                                'N') AS is_direct_import_sku
                       FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco
                      WHERE xco.is_master_org_id = 1);

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' master organization item cost record(s)');
                do_debug_tools.msg (' loading transaction freight costs');

                UPDATE (SELECT xcd.trx_freight_cost AS trx_freight_cost,
                               xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                   DECODE (xco.primary_cost_method,
                                           1, 'STDFREIGHT',
                                           'FIFOFREIGHT'),
                                   xcd.organization_id,
                                   xcd.inventory_item_id,
                                   'N',
                                   l_use_date - 1                        --3.1
                                                 ) AS org_freight_cost,
                               xcmic.freight_cost AS master_freight_cost,
                                 xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                     'FREIGHTRATE',
                                     xcmic.organization_id,
                                     xcmic.inventory_item_id,
                                     'N',
                                     l_use_date - 1                      --3.1
                                                   )
                               * xcd.trx_material_cost AS calc_trx_freight_cost
                          FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco, xxdo.xxdoinv_cir_master_item_cst xcmic
                         WHERE     xcmic.inventory_item_id =
                                   xcd.inventory_item_id
                               AND NVL (xcd.trx_freight_cost, 0) <= 0
                               AND xco.organization_id = xcd.organization_id)
                   SET trx_freight_cost   =
                           CASE
                               WHEN org_freight_cost > master_freight_cost
                               THEN
                                   org_freight_cost
                               ELSE
                                   DECODE (master_freight_cost,
                                           0, calc_trx_freight_cost,
                                           master_freight_cost)
                           END;

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' transaction freight cost record(s)');
                do_debug_tools.msg (' loading transaction duty costs');

                UPDATE (SELECT xcd.trx_duty_cost AS trx_duty_cost,
                               xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                   DECODE (xco.primary_cost_method,
                                           1, 'STDDUTY',
                                           'FIFODUTY'),
                                   xcd.organization_id,
                                   xcd.inventory_item_id,
                                   'N',
                                   l_use_date - 1                        --3.1
                                                 ) AS org_duty_cost,
                               xcmic.duty_cost AS master_duty_cost,
                                 xcmic.duty_rate
                               * DECODE (
                                     xcmic.is_direct_import_sku,
                                     'Y', xcmic.material_cost,
                                     xcmic.macau_cost + xcmic.freight_cost) AS calc_trx_duty_cost
                          FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco, xxdo.xxdoinv_cir_master_item_cst xcmic
                         WHERE     xcmic.inventory_item_id =
                                   xcd.inventory_item_id
                               AND NVL (xcd.trx_duty_cost, 0) <= 0
                               AND xco.organization_id = xcd.organization_id)
                   SET trx_duty_cost   =
                           CASE
                               WHEN org_duty_cost > master_duty_cost
                               THEN
                                   org_duty_cost
                               ELSE
                                   DECODE (master_duty_cost,
                                           0, calc_trx_duty_cost,
                                           master_duty_cost)
                           END;

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' transaction duty cost record(s)');
                do_debug_tools.msg (' loading item freight costs');

                UPDATE (SELECT xcd.itm_freight_cost AS itm_freight_cost,
                               xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                   DECODE (xco.primary_cost_method,
                                           1, 'STDFREIGHT',
                                           'FIFOFREIGHT'),
                                   xcd.organization_id,
                                   xcd.inventory_item_id,
                                   'N',
                                   l_use_date - 1                        --3.1
                                                 ) AS org_freight_cost,
                               xcmic.freight_cost AS master_freight_cost,
                                 xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                     'FREIGHTRATE',
                                     xcmic.organization_id,
                                     xcmic.inventory_item_id,
                                     'N',
                                     l_use_date - 1                      --3.1
                                                   )
                               * xcd.itm_material_cost AS calc_itm_freight_cost
                          FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco, xxdo.xxdoinv_cir_master_item_cst xcmic
                         WHERE     xcmic.inventory_item_id =
                                   xcd.inventory_item_id
                               AND NVL (xcd.itm_freight_cost, 0) <= 0
                               AND xco.organization_id = xcd.organization_id)
                   SET itm_freight_cost   =
                           CASE
                               WHEN org_freight_cost > master_freight_cost
                               THEN
                                   org_freight_cost
                               ELSE
                                   DECODE (master_freight_cost,
                                           0, calc_itm_freight_cost,
                                           master_freight_cost)
                           END;

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' item freight cost record(s)');
                do_debug_tools.msg (' loading item duty costs');

                UPDATE (SELECT xcd.itm_duty_cost AS itm_duty_cost,
                               xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                   DECODE (xco.primary_cost_method,
                                           1, 'STDDUTY',
                                           'FIFODUTY'),
                                   xcd.organization_id,
                                   xcd.inventory_item_id,
                                   'N',
                                   l_use_date - 1                        --3.1
                                                 ) AS org_duty_cost,
                               xcmic.duty_cost AS master_duty_cost,
                                 xcmic.duty_rate
                               * DECODE (
                                     xcmic.is_direct_import_sku,
                                     'Y', xcmic.material_cost,
                                     xcmic.macau_cost + xcmic.freight_cost) AS calc_itm_duty_cost
                          FROM xxdo.xxdoinv_cir_data xcd, xxdo.xxdoinv_cir_orgs xco, xxdo.xxdoinv_cir_master_item_cst xcmic
                         WHERE     xcmic.inventory_item_id =
                                   xcd.inventory_item_id
                               AND NVL (xcd.itm_duty_cost, 0) <= 0
                               AND xco.organization_id = xcd.organization_id)
                   SET itm_duty_cost   =
                           CASE
                               WHEN org_duty_cost > master_duty_cost
                               THEN
                                   org_duty_cost
                               ELSE
                                   DECODE (master_duty_cost,
                                           0, calc_itm_duty_cost,
                                           master_duty_cost)
                           END;

                do_debug_tools.msg (
                       ' inserted '
                    || SQL%ROWCOUNT
                    || ' item freight duty cost record(s)');
                do_debug_tools.msg (' calculating landed costs');

                UPDATE xxdo.xxdoinv_cir_data
                   SET trx_item_cost   =
                             NVL (trx_material_cost, 0)
                           + NVL (trx_freight_cost, 0)
                           + NVL (trx_duty_cost, 0),
                       itm_item_cost   =
                             NVL (itm_material_cost, 0)
                           + NVL (itm_freight_cost, 0)
                           + NVL (itm_duty_cost, 0),
                       sys_item_cost   =
                             NVL (itm_material_cost, 0)
                           + NVL (xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                      'NONMATERIAL',
                                      organization_id,
                                      inventory_item_id,
                                      'N',
                                      l_use_date - 1                     --3.1
                                                    ),
                                  0),
                       sys_item_non_mat_cost   =
                           NVL (xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                    'NONMATERIAL',
                                    organization_id,
                                    inventory_item_id,
                                    'N',
                                    l_use_date - 1                       --3.1
                                                  ),
                                0);

                UPDATE xxdo.xxdoinv_cir_master_item_cst
                   SET item_cost = NVL (material_cost, 0) + NVL (freight_cost, 0) + NVL (duty_cost, 0);

                do_debug_tools.msg (' gathering statistics');
                SYS.DBMS_STATS.gather_table_stats (
                    ownname   => 'XXDO',
                    tabname   => 'XXDOINV_CIR_ORGS',
                    CASCADE   => TRUE);
                SYS.DBMS_STATS.gather_table_stats (
                    ownname   => 'XXDO',
                    tabname   => 'XXDOINV_CIR_DATA',
                    CASCADE   => TRUE);
                SYS.DBMS_STATS.gather_table_stats (
                    ownname   => 'XXDO',
                    tabname   => 'XXDOINV_CIR_MASTER_ITEM_CST',
                    CASCADE   => TRUE);
                do_debug_tools.msg (
                    ' obtaining organization code for master inventory organization');

                --         fnd_file.put_line (fnd_file.LOG, '4');
                SELECT mp.organization_code
                  INTO l_org_code
                  FROM xxdo.xxdoinv_cir_orgs xco, mtl_parameters mp
                 WHERE     mp.organization_id = xco.organization_id
                       AND xco.is_master_org_id = 1;

                do_debug_tools.msg (
                       ' found organization code '
                    || l_org_code
                    || ' for master inventory organization');

                BEGIN
                    SELECT organization_name
                      INTO l_inv_org
                      FROM org_organization_definitions
                     WHERE organization_id = p_inv_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_inv_org   := p_inv_org_id;
                END;

                BEGIN
                    SELECT organization_name
                      INTO l_inv_mst_org
                      FROM org_organization_definitions
                     WHERE organization_id = p_master_inv_org_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_inv_mst_org   := p_master_inv_org_id;
                END;

                fnd_file.put (
                    fnd_file.output,
                       'Global Inventory Value Report-Deckers :'
                    || CHR (10)
                    || ' Retrieve From: '
                    || p_retrieve_from
                    || CHR (10)
                    || ' Snap Shot Date: '
                    || ld_snapshot_date
                    || CHR (10)
                    || ' Inventory Organization: '
                    || l_inv_org
                    || CHR (10)
                    || ' Region: '
                    || p_region
                    || CHR (10)
                    || ' Roll Back Date: '
                    || NVL (p_as_of_date, '{None}')
                    || CHR (10)
                    || ' Brand: '
                    || p_brand
                    || CHR (10)
                    || ' Master Inventory organization: '
                    || NVL (l_inv_mst_org, '{None}')
                    || CHR (10)
                    || ' Transfer price List:'
                    || NVL (TO_CHAR (p_xfer_price_list_id), '{None}')
                    || CHR (10)
                    || ' Summary: '
                    || p_summary
                    || CHR (10)
                    || ' From Currency (TO USD): '
                    || p_from_currency
                    || CHR (10)
                    || ' Elimination Rate Type: '
                    || p_elimination_rate_type
                    || CHR (10)
                    || ' Elimination Rate : '
                    || p_elimination_rate
                    || CHR (10)
                    || ' USER Rate (TO USD) : '
                    || p_user_rate
                    || CHR (10)
                    || ' TQ (For Japan): '
                    || p_tq_japan
                    || CHR (10)
                    || ' Markup Rate Type: '
                    || p_markup_rate_type
                    || CHR (10)
                    || ' USER Rate  (JPY TO USD)  : '
                    || p_jpy_user_rate
                    || CHR (10)
                    || 'Include Layered Margin : '
                    || p_layered_mrgn
                    || CHR (10));
                fnd_file.put (
                    fnd_file.output,
                       'Style'
                    || g_delim_char
                    || 'Color code'
                    || g_delim_char
                    || 'Size'
                    || g_delim_char
                    || 'Description'
                    || g_delim_char
                    --|| 'Division'
                    --|| g_delim_char
                    || 'Brand'
                    || g_delim_char
                    || 'Department'
                    || g_delim_char
                    || 'Class'
                    || g_delim_char
                    || 'Sub class'
                    || g_delim_char
                    -- CR#92 added Item Type BT Technology Team
                    || 'Item Type'
                    --|| g_delim_char
                    --|| 'Master Style'
                    --|| g_delim_char
                    --|| 'style Option'
                    || g_delim_char
                    || 'Intro Season'
                    || g_delim_char
                    || 'Current Season');

                FOR c_org IN c_orgs
                LOOP
                    --Start Changes V2.1
                    IF NVL (p_layered_mrgn, 'N') = 'Y'
                    THEN
                        --End Changes V2.1
                        fnd_file.put (
                            fnd_file.output,
                               g_delim_char
                            || c_org.organization_code
                            || ' Default Duty Rate'
                            || g_delim_char
                            || c_org.organization_code
                            || ' On Hand Qty'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Material Cost'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Duty Amount'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Freight Dutiable(Freight DU )'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Freight'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Dutiable OH (OH DUTY)'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Non-dutiable OH(OH NONDUTY)'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Total Cost'
                            || g_delim_char
                            || c_org.organization_code
                            -- Added by BT Technology Team on 12-JUn-2015 for defect#2322
                            || ' On Hand Value'
                            || g_delim_char
                            --start changes by BT Technology Team on 22-Jun-2015 for defect#2322
                            || c_org.organization_code
                            || ' Intransit Qty'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Material val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Duty Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Freight Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Freight DU Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit OH DUTY val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit OH NONDUTY Val'
                            || g_delim_char
                            -- || c_org.organization_code       --Added forc change 3.2 -- 3.4
                            --|| ' Intransit Qty (PO Receiving)'
                            --Added forc change 3.2 -- 3.4
                            --|| g_delim_char                  --Added forc change 3.2 -- 3.4
                            --|| c_org.organization_code       --Added forc change 3.2 -- 3.4
                            -- || ' Intransit Value (PO Receiving)'
                            --Added forc change 3.2 -- 3.4
                            -- || g_delim_char
                            || c_org.organization_code
                            || ' Total Inventory QTY'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Total Inventory Value'
                            || g_delim_char
                            --End changes by BT Technology Team on 22-Jun-2015 for defect#2322
                            || c_org.organization_code
                            || ' Extended Material Cost'
                            || g_delim_char
                            --|| c_org.organization_code
                            || ' Macau Cost'
                            || g_delim_char
                            || ' Extended Macau Cost'
                            --Start Changes V2.1
                            || g_delim_char
                            || ' Avg. Margin Value - USD'
                            || g_delim_char
                            || ' Avg. Margin Value - Local'
                            || g_delim_char
                            || ' Layered Margin Onhand Cost (USD)'
                            || g_delim_char
                            || '  Layered Margin Onhand Cost (Local)'
                            || g_delim_char
                            || ' Layered Margin Intransit Cost (USD)'
                            || g_delim_char
                            || '  Layered Margin Intransit Cost (Local)');
                    ELSE
                        fnd_file.put (
                            fnd_file.output,
                               g_delim_char
                            || c_org.organization_code
                            || ' Default Duty Rate'
                            || g_delim_char
                            || c_org.organization_code
                            || ' On Hand Qty'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Material Cost'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Duty Amount'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Freight Dutiable(Freight DU )'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Freight'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Dutiable OH (OH DUTY)'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Non-dutiable OH(OH NONDUTY)'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Total Cost'
                            || g_delim_char
                            || c_org.organization_code
                            -- Added by BT Technology Team on 12-JUn-2015 for defect#2322
                            || ' On Hand Value'
                            || g_delim_char
                            --start changes by BT Technology Team on 22-Jun-2015 for defect#2322
                            || c_org.organization_code
                            || ' Intransit Qty'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Material val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Duty Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Freight Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit Freight DU Val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit OH DUTY val'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Intransit OH NONDUTY Val'
                            --|| g_delim_char
                            --|| c_org.organization_code
                            --|| ' Intransit Qty (PO Receiving)'
                            --|| g_delim_char
                            --|| c_org.organization_code
                            --|| ' Intransit Value (PO Receiving)'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Total Inventory QTY'
                            || g_delim_char
                            || c_org.organization_code
                            || ' Total Inventory Value'
                            || g_delim_char
                            --End changes by BT Technology Team on 22-Jun-2015 for defect#2322
                            || c_org.organization_code
                            || ' Extended Material Cost'
                            || g_delim_char
                            --|| c_org.organization_code
                            || ' Macau Cost'
                            || g_delim_char
                            || ' Extended Macau Cost'
                            --Start Changes V2.1
                            || g_delim_char
                            || ' Avg. Margin Value - USD'
                            || g_delim_char
                            || '  Avg. Margin Value - Local');
                    END IF;

                    IF p_tq_japan = 'Y'
                    THEN
                        fnd_file.put (
                            fnd_file.output,
                               g_delim_char
                            || 'Material Cost in USD'
                            || g_delim_char
                            || 'Extended Material Cost in USD');
                    END IF;
                END LOOP;

                fnd_file.put_line (fnd_file.output, '');
                l_counter   := 0;

                FOR c_product IN c_products
                LOOP                             --Printing Item Level Records
                    l_counter            := l_counter + 1;
                    fnd_file.put (
                        fnd_file.output,
                           scrub_value (c_product.style)
                        || g_delim_char
                        || scrub_value (c_product.color)
                        || g_delim_char
                        || scrub_value (c_product.sze)
                        || g_delim_char
                        || scrub_value (c_product.item_description)
                        || g_delim_char
                        || scrub_value (c_product.brand)
                        || g_delim_char
                        --|| scrub_value (c_product.division)
                        --|| g_delim_char
                        || scrub_value (c_product.department)
                        || g_delim_char
                        || scrub_value (c_product.master_class)
                        || g_delim_char
                        || scrub_value (c_product.sub_class)
                        || g_delim_char
                        || scrub_value (c_product.item_type)
                        -- CR#92 added Item Type BT Technology Team
                        -- || g_delim_char
                        -- || scrub_value (c_product.master_style)
                        --|| g_delim_char
                        --|| scrub_value (c_product.style_option)
                        || g_delim_char
                        || scrub_value (c_product.intro_season)
                        || g_delim_char
                        || scrub_value (c_product.current_season));
                    /*l_total := 0;
                    l_qty_total := 0;
                    l_total_mat := 0;
                    l_total_profit_elim := 0;*/
                    l_tot_onhand_qty     := 0;
                    l_tot_ext_mat_cost   := 0;
                    l_tot_ext_mac_cost   := 0;
                    l_ext_macau_cost     := 0;
                    l_tot_iprofit        := 0;

                    FOR c_org IN c_orgs
                    LOOP
                        l_det_cnt           := 0;
                        l_material_cost     := 0;
                        -- Start Added by BT Technology Team On 15/01/2014
                        --  l_duty_rate  :=0;
                        l_freight_du        := 0;
                        l_freight           := 0;
                        l_oh_duty           := 0;
                        l_oh_nonduty        := 0;
                        l_duty_cost         := 0;
                        l_default_duty      := 0;
                        l_ext_mat_cost      := 0;
                        l_ext_mac_cost      := 0;
                        -- End Added by BT Technology Team On 15/01/2014
                        l_total_cost        := 0;
                        l_total_value       := 0;
                        l_iprofit           := 0;
                        l_tq_markup         := 0;
                        l_conv_rate         := 1;
                        ln_total_overhead   := 0;

                        FOR c_detail
                            IN c_details_rpt (c_org.organization_id, c_product.style, c_product.color
                                              , c_product.sze, l_use_date)
                        LOOP
                            IF l_det_cnt != 0
                            THEN
                                raise_application_error (
                                    -20001,
                                       'More than one report detail record was found.  Organization ID='
                                    || c_org.organization_id
                                    || ', Style='
                                    || c_product.style
                                    || ', Color='
                                    || c_product.color);
                            END IF;

                            --Start changes for V2.1
                            IF NVL (p_layered_mrgn, 'N') = 'Y'
                            THEN
                                --Onhand Layered Margin
                                xv_source                        := NULL;
                                xn_inventory_item_id             := 0;
                                xn_destination_organization_id   := 0;
                                xd_transaction_date              := NULL;
                                xn_transaction_quantity          := 0;
                                xn_trx_mrgn_cst_usd              := 0;
                                xn_trx_mrgn_cst_local            := 0;
                                ln_transaction_quantity          := 0;
                                ln_trx_mrgn_cst_usd              := 0;
                                ln_trx_mrgn_cst_local            := 0;
                                ln_diff_qty                      :=
                                    c_detail.onhand_qty;
                                ld_trx_date                      :=
                                    l_use_date;
                                ln_seq_number                    := 0;
                                lv_source                        := NULL;

                                BEGIN
                                    WHILE (c_detail.onhand_qty > ln_transaction_quantity)
                                    LOOP
                                        get_rollback_trx_onhand_qty (
                                            c_product.inventory_item_id,
                                            c_product.style,
                                            c_product.color,
                                            c_product.sze,
                                            c_org.organization_id,
                                            ld_trx_date,
                                            ln_diff_qty,
                                            lv_source,
                                            ln_seq_number,
                                            xn_seq_number,
                                            xv_source,
                                            xn_inventory_item_id,
                                            xn_destination_organization_id,
                                            xd_transaction_date,
                                            xn_transaction_quantity,
                                            xn_trx_mrgn_cst_usd,
                                            xn_trx_mrgn_cst_local);
                                        lv_source       := xv_source;
                                        ld_trx_date     := xd_transaction_date;
                                        ln_seq_number   := xn_seq_number;
                                        ln_transaction_quantity   :=
                                              ln_transaction_quantity
                                            + xn_transaction_quantity;
                                        ln_diff_qty     :=
                                              c_detail.onhand_qty
                                            - ln_transaction_quantity;
                                        ln_trx_mrgn_cst_usd   :=
                                              ln_trx_mrgn_cst_usd
                                            + xn_trx_mrgn_cst_usd;
                                        ln_trx_mrgn_cst_local   :=
                                              ln_trx_mrgn_cst_local
                                            + xn_trx_mrgn_cst_local;
                                    END LOOP;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put (
                                            fnd_file.LOG,
                                               'Error while fetching the layered Margin - '
                                            || SQLERRM);
                                END;

                                -- Intransit Layered Margin
                                BEGIN
                                    xv_source                        := NULL;
                                    ln_seq_number                    := NULL;
                                    --                        lv_source
                                    xn_intst_inventory_item_id       := 0;
                                    xn_intst_destn_organization_id   := 0;
                                    xd_intst_transaction_date        := NULL;
                                    xn_intst_transaction_quantity    := 0;
                                    xn_intst_trx_mrgn_cst_usd        := 0;
                                    xn_intst_trx_mrgn_cst_local      := 0;
                                    ln_transaction_quantity          := 0;
                                    ln_intst_trx_mrgn_cst_usd        := 0;
                                    ln_intst_trx_mrgn_cst_local      := 0;
                                    ln_diff_qty                      :=
                                        c_detail.rpt_intrans_qty;
                                    ld_trx_date                      :=
                                        l_use_date;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'c_detail.rpt_intrans_qty'
                                        || c_detail.rpt_intrans_qty);

                                    WHILE (c_detail.rpt_intrans_qty > ln_transaction_quantity)
                                    LOOP
                                        get_rollback_trx_intransit_qty (
                                            c_product.inventory_item_id,
                                            c_product.style,
                                            c_product.color,
                                            c_product.sze,
                                            c_org.organization_id,
                                            ld_trx_date,
                                            ln_diff_qty,
                                            ln_seq_number,
                                            xv_source,
                                            xn_seq_number,
                                            xn_intst_inventory_item_id,
                                            xn_intst_destn_organization_id,
                                            xd_intst_transaction_date,
                                            xn_intst_transaction_quantity,
                                            xn_intst_trx_mrgn_cst_usd,
                                            xn_intst_trx_mrgn_cst_local);
                                        ld_trx_date     := xd_transaction_date;
                                        ln_seq_number   := xn_seq_number;
                                        ln_transaction_quantity   :=
                                              ln_transaction_quantity
                                            + xn_intst_transaction_quantity;
                                        ln_diff_qty     :=
                                              c_detail.rpt_intrans_qty
                                            - ln_transaction_quantity;
                                        ln_intst_trx_mrgn_cst_usd   :=
                                              ln_intst_trx_mrgn_cst_usd
                                            + xn_intst_trx_mrgn_cst_usd;
                                        ln_intst_trx_mrgn_cst_local   :=
                                              ln_intst_trx_mrgn_cst_local
                                            + xn_intst_trx_mrgn_cst_local;
                                    END LOOP;

                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Parent ln_intst_trx_mrgn_cst_local - - '
                                        || ln_intst_trx_mrgn_cst_local
                                        || ' -- '
                                        || ln_intst_trx_mrgn_cst_usd);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put (
                                            fnd_file.LOG,
                                               'Error while fetching the layered Margin - '
                                            || SQLERRM);
                                END;
                            END IF;

                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                   'Item Number'
                                || c_product.item_number
                                || 'Organization ID '
                                || c_org.organization_id);
                            l_default_duty   :=
                                default_duty_rate (
                                    c_product.inventory_item_id,
                                    c_org.organization_id);

                            --Start changes by BT Technology Team on 20-Nov-2015 for defect#689
                            IF l_default_duty = 0
                            THEN
                                l_default_duty   :=
                                    xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                        'DUTY RATE',
                                        c_org.organization_id,
                                        c_product.inventory_item_id,
                                        'Y',
                                        l_use_date - 1                   --3.1
                                                      );
                            END IF;

                            --End changes by BT Technology Team on 20-Nov-2015 for defect#689

                            -- Start Changes  CR#TBD and Defect#689 for all the calculation 26-Nov-2015
                            ln_total_overhead   :=
                                xxd_inv_givr_snap_pkg.xxd_cst_mat_oh_fnc (
                                    c_product.inventory_item_id,
                                    c_org.organization_id,
                                    l_use_date - 1);                     --3.1
                            l_material_cost   :=
                                xxd_inv_givr_snap_pkg.xxd_cst_mat_fnc (
                                    c_product.inventory_item_id,
                                    c_org.organization_id,
                                    l_use_date - 1);                     --3.1
                            --                   fnd_file.put_line (fnd_file.LOG, 'Calculated ln_total_overhead for Snap is - '||ln_total_overhead);
                            --                   fnd_file.put_line (fnd_file.LOG, 'Calculated l_material_cost for Snap is - '||l_material_cost);
                            l_freight_du     :=
                                NVL ((  xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'FREIGHT DU FACTOR',
                                            c_org.organization_id,
                                            c_product.inventory_item_id,
                                            'Y',
                                            l_use_date - 1               --3.1
                                                          )
                                      * xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'FREIGHT DU RATE',
                                            c_org.organization_id,
                                            c_product.inventory_item_id,
                                            'Y',
                                            l_use_date - 1               --3.1
                                                          )
                                      * l_material_cost),
                                     NVL (xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                              'FREIGHT DU',
                                              c_org.organization_id,
                                              c_product.inventory_item_id,
                                              'Y',
                                              l_use_date - 1             --3.1
                                                            ),
                                          0));
                            --                     fnd_file.put_line (fnd_file.LOG, 'Calculated l_freight_du for Snap is - '||l_freight_du);
                            l_freight_du     :=
                                CASE
                                    WHEN ln_total_overhead > l_freight_du
                                    THEN
                                        l_freight_du
                                    ELSE
                                        ln_total_overhead
                                END;
                            --                   fnd_file.put_line (fnd_file.LOG, 'Final l_freight_du for Snap is - '||l_freight_du);
                            l_freight        :=
                                --start viswa
                                 NVL ((  xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                             'FREIGHT FACTOR',
                                             c_org.organization_id,
                                             c_product.inventory_item_id,
                                             'Y',
                                             l_use_date - 1              --3.1
                                                           )
                                       * xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                             'FREIGHT RATE',
                                             c_org.organization_id,
                                             c_product.inventory_item_id,
                                             'Y',
                                             l_use_date - 1              --3.1
                                                           )
                                       * l_material_cost),
                                      NVL (xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                               'FREIGHT',
                                               c_org.organization_id,
                                               c_product.inventory_item_id,
                                               'Y',
                                               l_use_date - 1            --3.1
                                                             ),
                                           0));
                            --                  fnd_file.put_line (fnd_file.LOG, 'Calculated l_freight for Snap is - '||l_freight);
                            l_freight        :=
                                CASE
                                    WHEN l_freight >
                                         (ln_total_overhead - l_freight_du)
                                    THEN
                                        ln_total_overhead - l_freight_du
                                    ELSE
                                        l_freight
                                END;
                            --                  fnd_file.put_line (fnd_file.LOG, 'Final l_freight for Snap is - '||l_freight);
                            l_oh_duty        :=
                                NVL ((  xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'OH DUTY FACTOR',
                                            c_org.organization_id,
                                            c_product.inventory_item_id,
                                            'Y',
                                            l_use_date - 1               --3.1
                                                          )
                                      * xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'OH DUTY RATE',
                                            c_org.organization_id,
                                            c_product.inventory_item_id,
                                            'Y',
                                            l_use_date - 1               --3.1
                                                          )
                                      * l_material_cost),
                                     NVL (xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                              'OH DUTY',
                                              c_org.organization_id,
                                              c_product.inventory_item_id,
                                              'Y',
                                              l_use_date - 1             --3.1
                                                            ),
                                          0));
                            --                   fnd_file.put_line (fnd_file.LOG, 'Calculated l_oh_nonduty for snap is - '||l_oh_nonduty);
                            l_oh_duty        :=
                                CASE
                                    WHEN l_oh_duty >
                                         (ln_total_overhead - l_freight_du - l_freight)
                                    THEN
                                        (ln_total_overhead - l_freight_du - l_freight)
                                    ELSE
                                        l_oh_duty
                                END;
                            --                  fnd_file.put_line (fnd_file.LOG, 'Final l_oh_duty for Snap is - '||l_oh_duty);
                            l_oh_nonduty     :=
                                NVL ((  xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'OH NONDUTY FACTOR',
                                            c_org.organization_id,
                                            c_product.inventory_item_id,
                                            'Y',
                                            l_use_date - 1               --3.1
                                                          )
                                      * xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                            'OH NONDUTY RATE',
                                            c_org.organization_id,
                                            c_product.inventory_item_id,
                                            'Y',
                                            l_use_date - 1               --3.1
                                                          )
                                      * l_material_cost),
                                     NVL (xxd_inv_givr_snap_pkg.xxd_get_snap_item_cost_fnc (
                                              'OH NONDUTY',
                                              c_org.organization_id,
                                              c_product.inventory_item_id,
                                              'Y',
                                              l_use_date - 1             --3.1
                                                            ),
                                          0));
                            --                   fnd_file.put_line (fnd_file.LOG, 'Calculated l_oh_nonduty for Snap is - '||l_oh_nonduty);
                            l_oh_nonduty     :=
                                CASE
                                    WHEN l_oh_nonduty >
                                         (ln_total_overhead - l_freight_du - l_freight - l_oh_duty)
                                    THEN
                                        (ln_total_overhead - l_freight_du - l_freight - l_oh_duty)
                                    ELSE
                                        l_oh_nonduty
                                END;
                            --                  fnd_file.put_line (fnd_file.LOG, 'Final l_oh_nonduty for Snap is - '||l_oh_nonduty);
                            l_duty_cost      :=
                                  ln_total_overhead
                                - (l_freight_du + l_freight + l_oh_duty + l_oh_nonduty);

                            --                  fnd_file.put_line (fnd_file.LOG, 'Calculated l_duty_cost for Snap is - '||l_duty_cost);
                            IF l_duty_cost < 0
                            THEN
                                l_duty_cost   := 0;
                            END IF;

                            l_total_cost     :=
                                  l_material_cost
                                + l_duty_cost
                                + l_freight_du
                                + l_freight
                                + l_oh_duty
                                + l_oh_nonduty;
                            --                  fnd_file.put_line (fnd_file.LOG, 'Final l_total_cost for Snap is - '||l_total_cost);
                            l_total_value    :=
                                (l_total_cost * NVL (c_detail.onhand_qty, 0));
                            --Added BY BT Technology on 12-Jun-2015 for defect#2322
                            l_intrans_val    :=
                                ROUND (
                                    c_detail.rpt_intrans_qty * l_total_cost,
                                    2);
                            l_intrans_rec_val   :=
                                ROUND (
                                    c_detail.rec_intrans_qty * l_total_cost,
                                    2);
                            -- Added for change 3.2
                            l_intrans_mat_val   :=
                                c_detail.rpt_intrans_qty * l_material_cost;
                            l_intrans_duty_val   :=
                                c_detail.rpt_intrans_qty * l_duty_cost;
                            l_intrans_frt_val   :=
                                c_detail.rpt_intrans_qty * l_freight;
                            l_intrans_frt_du_val   :=
                                c_detail.rpt_intrans_qty * l_freight_du;
                            l_intrans_oh_duty_val   :=
                                c_detail.rpt_intrans_qty * l_oh_duty;
                            l_intrans_nonoh_duty_val   :=
                                c_detail.rpt_intrans_qty * l_oh_nonduty;
                            l_tot_inv_qty    :=
                                  c_detail.onhand_qty
                                + c_detail.rpt_intrans_qty; --Commneted for change 3.2 -- 3.4 uncommented
                            /*l_tot_inv_qty :=
                                 c_detail.onhand_qty
                               + c_detail.rpt_intrans_qty
                               + c_detail.rec_intrans_qty;  */
                            -- Added for change 3.2 -- 3.4
                            l_tot_inv_val    := l_total_value + l_intrans_val; --Commneted for change 3.2 -- 3.4
                            /*l_tot_inv_val :=
                                    l_total_value + l_intrans_val + l_intrans_rec_val;*/
                            -- Added for change 3.2 -- 3.4
                            l_ext_mat_cost   :=
                                  (c_detail.onhand_qty * l_material_cost)
                                + l_intrans_mat_val;
                            l_ext_mac_cost   :=
                                c_detail.macau_cost * l_tot_inv_qty;
                            l_det_cnt        := l_det_cnt + 1;

                            /*fnd_file.put_line (fnd_file.LOG, 'Final l_total_value for Snap is - '||l_total_value);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_val for Snap is - '||l_intrans_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_mat_val for Snap is - '||l_intrans_mat_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_duty_val for Snap is - '||l_intrans_duty_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_frt_val for Snap is - '||l_intrans_frt_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_frt_du_val for Snap is - '||l_intrans_frt_du_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_oh_duty_val for Snap is - '||l_intrans_oh_duty_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_intrans_nonoh_duty_val for Snap is - '||l_intrans_nonoh_duty_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_tot_inv_qty for Snap is - '||l_tot_inv_qty);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_tot_inv_val for Snap is - '||l_tot_inv_val);
                            fnd_file.put_line (fnd_file.LOG, 'Final l_ext_mat_cost for Snap is - '||l_ext_mat_cost);
                            fnd_file.put_line (fnd_file.LOG, 'Final1 l_ext_mac_cost for Snap is - '||l_ext_mac_cost);*/
                            IF p_elimination_rate = 'USER'
                            THEN
                                l_conv_rate   := NVL (p_user_rate, 0);
                            ELSE
                                BEGIN
                                    SELECT AVG (conversion_rate)
                                      INTO l_conv_rate
                                      FROM gl_daily_rates
                                     WHERE     conversion_type =
                                               NVL (p_elimination_rate_type,
                                                    '1000')
                                           -- budget_id for rate type
                                           AND TRUNC (conversion_date) BETWEEN   ADD_MONTHS (
                                                                                     fnd_date.canonical_to_date (
                                                                                         p_as_of_date),
                                                                                     -(TO_NUMBER (SUBSTR (p_elimination_rate, 4, 2))))
                                                                               + 1
                                                                           AND fnd_date.canonical_to_date (
                                                                                   p_as_of_date)
                                           AND from_currency =
                                               NVL (p_from_currency,
                                                    c_detail.currency_code)
                                           AND to_currency = 'USD';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_conv_rate   := 0;
                                END;
                            END IF;

                            -- code added for DEFECT#2322 TQ MARKUP Eliminaton Logic
                            IF     p_jpy_user_rate IS NOT NULL
                               AND p_markup_rate_type IS NULL
                            THEN
                                l_rate   := NVL (p_jpy_user_rate, 0);
                            ELSE
                                BEGIN
                                    SELECT conversion_rate
                                      INTO l_rate
                                      FROM gl_daily_rates
                                     WHERE     conversion_type =
                                               NVL (p_markup_rate_type,
                                                    '1000')
                                           -- budget_id for rate type
                                           AND TRUNC (conversion_date) =
                                               NVL (
                                                   TO_DATE (p_as_of_date,
                                                            'YYYY/MM/DD'),
                                                   TRUNC (SYSDATE))
                                           AND from_currency = 'USD'
                                           AND to_currency = 'JPY';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_rate   := 0;
                                END;
                            END IF;

                            BEGIN
                                SELECT MAX (rate_multiplier), MAX (rate_amount)
                                  INTO l_rate_multiplier, l_rate_amt
                                  FROM do_custom.xxdo_po_price_rule xppr, do_custom.xxdo_po_price_rule_assignment xppra--,AP_SUPPLIERS APS
                                                                                                                       -- ,HR_ORGANIZATION_UNITS HROU
                                                                                                                       , apps.xxd_common_items_v xci
                                 WHERE     xppr.po_price_rule =
                                           xppra.po_price_rule
                                       AND xppra.item_segment1 =
                                           xci.style_number
                                       AND xppra.item_segment2 =
                                           xci.color_code
                                       AND xci.org_name =
                                           xppra.target_item_organization
                                       AND xci.style_number = c_product.style
                                       AND xci.color_code = c_product.color;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_rate_multiplier   := 0;
                                    l_rate_amt          := 0;
                            END;

                            fnd_file.put (
                                fnd_file.LOG,
                                'c_detail.currency_code:' || c_detail.currency_code);
                            fnd_file.put (fnd_file.LOG,
                                          'l_conv_rate:' || l_conv_rate);
                            fnd_file.put (
                                fnd_file.LOG,
                                'l_ext_mac_cost:' || l_ext_mac_cost);
                            l_rate_multiplier   :=
                                CASE
                                    WHEN    l_rate_multiplier = 0
                                         OR l_rate_multiplier IS NULL
                                    THEN
                                        1
                                    ELSE
                                        l_rate_multiplier
                                END;
                            l_rate_amt       := NVL (l_rate_amt, 0);
                            l_tq_markup      :=
                                ROUND (
                                    (((l_material_cost - l_rate_amt) / l_rate_multiplier) * l_conv_rate),
                                    2);
                            l_ext_markup_mac_cost   :=
                                NVL (l_tot_inv_qty * l_tq_markup, 0);

                            IF     c_org.organization_code NOT LIKE 'JP%'
                               AND (l_ext_mat_cost * l_conv_rate) >
                                   l_ext_mac_cost
                            THEN
                                l_iprofit   :=
                                    NVL (
                                          (l_ext_mat_cost * l_conv_rate)
                                        - l_ext_mac_cost,
                                        0);
                            --fnd_file.put (fnd_file.log, 'IN IF c_org.organization_code:'||c_org.organization_code);
                            ELSIF     c_org.organization_code LIKE 'JP%'
                                  AND TO_NUMBER (l_ext_markup_mac_cost) >=
                                      ROUND (
                                          TO_NUMBER (NVL (l_ext_mac_cost, 0)))
                            THEN
                                l_iprofit   :=
                                      TO_NUMBER (l_ext_markup_mac_cost)
                                    - ROUND (
                                          TO_NUMBER (NVL (l_ext_mac_cost, 0)));
                            --fnd_file.put (fnd_file.log, 'IN ELSIF c_org.organization_code:'||c_org.organization_code);
                            ELSE
                                l_iprofit   := 0;
                            --fnd_file.put (fnd_file.log, 'IN ELSE c_org.organization_code:'||c_org.organization_code);
                            END IF;

                            IF NVL (p_layered_mrgn, 'N') = 'Y'
                            THEN
                                fnd_file.put (
                                    fnd_file.output, --Printing Organizational Records
                                       g_delim_char
                                    || NVL (l_default_duty, 0)
                                    || g_delim_char
                                    || NVL (c_detail.onhand_qty, 0)
                                    || g_delim_char
                                    || NVL (l_material_cost, 0)
                                    || g_delim_char
                                    || NVL (l_duty_cost, 0)
                                    || g_delim_char
                                    || NVL (l_freight_du, 0)
                                    || g_delim_char
                                    || NVL (l_freight, 0)
                                    || g_delim_char
                                    || NVL (l_oh_duty, 0)
                                    || g_delim_char
                                    || NVL (l_oh_nonduty, 0)
                                    || g_delim_char
                                    || NVL (l_total_cost, 0)
                                    || g_delim_char
                                    || NVL (l_total_value, 0)
                                    -- Added by BT Technology Team on 12-Jun-2015 for defect#2322
                                    || g_delim_char
                                    --Start Changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                    || NVL (c_detail.rpt_intrans_qty, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_mat_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_duty_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_frt_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_frt_du_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_oh_duty_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_nonoh_duty_val, 0)
                                    || g_delim_char
                                    --End Changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                    --|| NVL (c_detail.rec_intrans_qty, 0)
                                    -- Added for change 3.2 -- 3.4
                                    --|| g_delim_char            -- Added for change 3.2 -- 3.4
                                    --|| l_intrans_rec_val       -- Added for change 3.2 -- 3.4
                                    --|| g_delim_char            -- Added for change 3.2 -- 3.4
                                    || NVL (l_tot_inv_qty, 0)
                                    || g_delim_char
                                    || NVL (l_tot_inv_val, 0)
                                    || g_delim_char
                                    || NVL (l_ext_mat_cost, 0)
                                    || g_delim_char
                                    || NVL (c_detail.macau_cost, 0)
                                    || g_delim_char
                                    || NVL (l_ext_mac_cost, 0)
                                    --Start Changes V2.1
                                    || g_delim_char
                                    || ROUND (c_detail.avg_mrgn_cst_usd, 2)
                                    || g_delim_char
                                    || ROUND (c_detail.avg_mrgn_cst_local, 2)
                                    || g_delim_char
                                    || ROUND (ln_trx_mrgn_cst_usd, 2)
                                    || g_delim_char
                                    || ROUND (ln_trx_mrgn_cst_local, 2)
                                    || g_delim_char
                                    || ROUND (ln_intst_trx_mrgn_cst_usd, 2)
                                    || g_delim_char
                                    || ROUND (ln_intst_trx_mrgn_cst_local, 2));
                            ELSE
                                fnd_file.put (
                                    fnd_file.output, --Printing Organizational Records
                                       g_delim_char
                                    || NVL (l_default_duty, 0)
                                    || g_delim_char
                                    || NVL (c_detail.onhand_qty, 0)
                                    || g_delim_char
                                    || NVL (l_material_cost, 0)
                                    || g_delim_char
                                    || NVL (l_duty_cost, 0)
                                    || g_delim_char
                                    || NVL (l_freight_du, 0)
                                    || g_delim_char
                                    || NVL (l_freight, 0)
                                    || g_delim_char
                                    || NVL (l_oh_duty, 0)
                                    || g_delim_char
                                    || NVL (l_oh_nonduty, 0)
                                    || g_delim_char
                                    || NVL (l_total_cost, 0)
                                    || g_delim_char
                                    || NVL (l_total_value, 0)
                                    -- Added by BT Technology Team on 12-Jun-2015 for defect#2322
                                    || g_delim_char
                                    --Start Changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                    || NVL (c_detail.rpt_intrans_qty, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_mat_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_duty_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_frt_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_frt_du_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_oh_duty_val, 0)
                                    || g_delim_char
                                    || NVL (l_intrans_nonoh_duty_val, 0)
                                    || g_delim_char
                                    --End Changes by BT Technology Team on 22-Jun-2015 for defect#2322
                                    -- || NVL(c_detail.rec_intrans_qty, 0) -- 3.4
                                    -- Added for change 3.2 -- 3.4
                                    --|| g_delim_char            -- Added for change 3.2 -- 3.4
                                    --|| l_intrans_rec_val       -- Added for change 3.2 -- 3.4
                                    --|| g_delim_char            -- Added for change 3.2 -- 3.4
                                    || NVL (l_tot_inv_qty, 0)
                                    || g_delim_char
                                    || NVL (l_tot_inv_val, 0)
                                    || g_delim_char
                                    || NVL (l_ext_mat_cost, 0)
                                    || g_delim_char
                                    || NVL (c_detail.macau_cost, 0)
                                    || g_delim_char
                                    || NVL (l_ext_mac_cost, 0)
                                    || g_delim_char
                                    || c_detail.avg_mrgn_cst_usd
                                    || g_delim_char
                                    || c_detail.avg_mrgn_cst_local);
                            END IF;

                            IF p_tq_japan = 'Y'
                            THEN
                                fnd_file.put (
                                    fnd_file.output,
                                       g_delim_char
                                    || NVL (l_tq_markup, 0)
                                    || g_delim_char
                                    || NVL (l_ext_markup_mac_cost, 0));
                            END IF;
                        END LOOP;

                        IF l_det_cnt = 0
                        THEN
                            --Start Changes V2.1
                            IF NVL (p_layered_mrgn, 'N') = 'Y'
                            THEN
                                fnd_file.put (
                                    fnd_file.output,
                                       g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    --Start Changes V2.1
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || ''                   --End Changes V2.1
                                         );
                            ELSE
                                fnd_file.put (
                                    fnd_file.output,
                                       g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    || g_delim_char
                                    || '0'
                                    --Start Changes V2.1
                                    || g_delim_char
                                    || ''
                                    || g_delim_char
                                    || '');
                            --End Changes V2.1
                            END IF;
                        END IF;
                    END LOOP;

                    fnd_file.put_line (fnd_file.output, '');
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    do_debug_tools.msg (' others exception: ' || SQLERRM);
                    perrproc   := 2;
                    psqlstat   := SQLERRM;
            END;
        END IF;

        -- End of Change CCR0008682
        do_debug_tools.msg (
            'perrproc=' || perrproc || ', psqlstat=' || psqlstat);
        do_debug_tools.msg ('-' || l_proc_name);
    END;
END xxdoinv_consol_inv_report;
/
