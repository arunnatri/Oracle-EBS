--
-- XXDO_INV_ONHAND_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INV_ONHAND_CONV_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_inv_onhand_conv_pkg_b.sql   1.0    2015/03/01    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_inv_onhand_conv_pkg
    --
    -- Description  :  This is package  for onhand conversion
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 01-Mar-15    Infosys            1.0       Created
    -- 24-Mar-15    Infosys            2.0       Sanuk Conversion - UAT bug fixes - Identified by UAT_BUGS
    -- 09-Jun-15     Infosys           3.0       New Parameter is added for Requisition approval;
    --                                                          Identified by APPROVAL_PARAMETER
    --10-Jun-15     Infosys            4.0       User Parameter added
    --                                                     Identified by USER_PARAMETER
    --10-Jun-15     Infosys            5.0       Modified for BT
    --16-Jun-15    Infosys            5.0      Operating Unit ID is derived from org definitions instead of hard coding while creating IR;
    --                                                     Identified by ORG_ID
    -- ***************************************************************************


    PROCEDURE extract_oh (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_summary_level IN VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_src_inv_org_id IN NUMBER, p_in_chr_src_subinv IN VARCHAR2, --                                    p_in_num_tar_inv_org_id IN NUMBER,
                                                                                                                                                                                                                                                          --                                    p_in_chr_tar_subinv IN VARCHAR2, --,
                                                                                                                                                                                                                                                          p_in_chr_product_group IN VARCHAR2, p_in_chr_prod_subgroup IN VARCHAR2
                          , p_in_chr_style IN VARCHAR2, p_in_chr_color IN VARCHAR2, p_in_chr_size IN VARCHAR2)
    AS
        l_num_src_org_id          NUMBER := p_in_num_src_inv_org_id;
        --   l_num_tar_org_id   NUMBER   :=
        l_num_item_id             NUMBER;           --:= p_in_num_inv_item_id;
        l_num_curr_item           NUMBER := -1;
        l_num_prev_item           NUMBER := -1;

        l_num_total_reserve_qty   NUMBER := 0;

        i                         NUMBER := 0;
        j                         NUMBER := 0;
        l_num_rcv_qty             NUMBER := 0;

        l_chr_errbuf              VARCHAR2 (2000);
        l_chr_retcode             VARCHAR2 (1);


        TYPE rcv_txn_rec IS RECORD
        (
            rcv_txn_id          NUMBER,
            item_id             NUMBER,
            transaction_date    DATE,
            quantity            NUMBER
        );

        TYPE rcv_txns IS TABLE OF rcv_txn_rec
            INDEX BY PLS_INTEGER;

        l_cur_rcv_txns            rcv_txns;

        CURSOR rcv_txns_1 (p_num_src_org_id   IN NUMBER,
                           p_num_item_id      IN NUMBER)
        IS
              SELECT transaction_id, item_id, transaction_date,
                     (qty + corrected_qty) quantity
                FROM (SELECT rcvt.transaction_id,
                             rsl.item_id,
                             rcvt.transaction_date transaction_date,
                             NVL (rcvt.quantity, 0) qty,
                             (SELECT NVL (SUM (quantity), 0)
                                FROM apps.rcv_transactions rcvt1
                               WHERE     rcvt1.parent_transaction_id =
                                         rcvt.transaction_id
                                     AND rcvt1.transaction_type = 'CORRECT') corrected_qty
                        FROM apps.rcv_shipment_lines rsl, apps.rcv_transactions rcvt
                       WHERE     rcvt.transaction_type = 'DELIVER'
                             AND rcvt.destination_type_code = 'INVENTORY'
                             AND rsl.source_document_code = 'PO'
                             AND rcvt.transaction_date >=
                                 ADD_MONTHS (TRUNC (SYSDATE), -60)
                             AND rsl.shipment_line_id = rcvt.shipment_line_id
                             AND rsl.item_id = p_num_item_id
                             AND rcvt.organization_id = p_num_src_org_id) x
               WHERE (qty + corrected_qty) > 0
            ORDER BY transaction_date DESC;

        CURSOR cur_item IS
            SELECT DISTINCT moq.inventory_item_id, --                          msi.primary_uom_code,
                                                   --                          msi.segment1 item_number,       --Modified for BT
                                                   mc.segment1 brand, mc.segment2 gender, --Modified for BT
                            mc.segment3 product_group,       --Modified for BT
                                                       mc.segment4 product_subgroup
              FROM mtl_onhand_quantities moq, mtl_categories_b mc, mtl_item_categories mic,
                   mtl_category_sets mcs, --  mtl_system_items_b msi
                                          mtl_system_items_kfv msi, --Modified for BT
                                                                    xxd_common_items_v xciv -- Added for BT Remediation
             WHERE     moq.organization_id =
                       NVL (p_in_num_src_inv_org_id, moq.organization_id)
                   AND moq.subinventory_code =
                       NVL (p_in_chr_src_subinv, moq.subinventory_code)
                   --                  AND moq.inventory_item_id = NVL(p_in_num_inv_item_id, moq.inventory_item_id)
                   AND mc.segment1 = NVL (p_in_chr_brand, mc.segment1)
                   AND mc.segment2 = NVL (p_in_chr_gender, mc.segment2) --Modified for BT
                   AND mc.segment3 =
                       NVL (p_in_chr_product_group, mc.segment3) --Modified for BT
                   AND mc.segment4 =
                       NVL (p_in_chr_prod_subgroup, mc.segment4)
                   AND moq.organization_id = mic.organization_id
                   AND mic.inventory_item_id = moq.inventory_item_id
                   AND mcs.category_set_id = mic.category_set_id
                   AND mcs.category_set_id = 1
                   --                    AND mcs.category_id = mc.category_id
                   AND mic.inventory_item_id = moq.inventory_item_id
                   AND mc.category_id = mic.category_id
                   AND moq.organization_id = msi.organization_id
                   AND msi.inventory_item_id = moq.inventory_item_id
                   AND msi.organization_id =
                       NVL (p_in_num_src_inv_org_id, msi.organization_id)
                   /*Modified for BT*/
                   /*AND msi.segment1 = NVL (p_in_chr_style, msi.segment1)
                   AND msi.segment2 = NVL (p_in_chr_color, msi.segment2)
                   AND msi.segment3 = NVL (p_in_chr_size, msi.segment3)*/
                   AND xciv.inventory_item_id = msi.inventory_item_id
                   AND xciv.organization_id = msi.organization_id
                   AND xciv.category_set_id = mcs.category_set_id
                   AND xciv.category_id = mc.category_id
                   AND xciv.style_number =
                       NVL (p_in_chr_style, xciv.style_number)
                   AND xciv.color_code =
                       NVL (p_in_chr_color, xciv.color_code)
                   AND msi.attribute27 = NVL (p_in_chr_size, msi.attribute27)
                   --                    AND moq.subinventory_code <> 'STAGE'
                   AND moq.subinventory_code IN
                           (SELECT lookup.attribute2
                              FROM mtl_parameters mp_inner, fnd_lookup_values lookup
                             WHERE     mp_inner.organization_id =
                                       p_in_num_src_inv_org_id
                                   AND lookup.attribute1 =
                                       mp_inner.organization_code
                                   AND lookup.lookup_type =
                                       'XXDO_INV_OH_CONV_SRC_TAR_MAP'
                                   AND lookup.language = 'US'
                                   AND lookup.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           lookup.start_date_active,
                                                           SYSDATE - 1)
                                                   AND NVL (
                                                           lookup.end_date_active,
                                                           SYSDATE + 1));


        CURSOR cur_onhand (p_num_inv_item_id IN NUMBER)
        IS
              SELECT SUM (transaction_quantity) quantity,
                     moq.subinventory_code,
                     moq.locator_id,
                     msi.segment1 item_number,               --Modified for BT
                     msi.primary_uom_code,
                     msi.description,
                     /*replace(ffv_styles.description,chr(9), '') style_name,
                      ffv_colors.description color_name,*/
                     xciv.style_desc style_name,
                     xciv.color_desc color_name,
                     DECODE (msi.attribute11,
                             NULL, NULL,
                             '''' || msi.attribute11 || '''') upc,
                     DECODE (
                         subinv.asset_inventory,
                         2, 0,
                         NVL (
                             (SELECT cic.item_cost
                                FROM cst_item_costs cic
                               WHERE     cic.organization_id =
                                         p_in_num_src_inv_org_id
                                     AND cic.inventory_item_id =
                                         p_num_inv_item_id
                                     AND cic.cost_type_id =
                                         mp_cost.primary_cost_method),
                             0)) item_unit_cost,
                     mil.concatenated_segments source_locator,
                     subinv.asset_inventory
                FROM mtl_onhand_quantities moq, -- mtl_system_items_b msi,
                                                mtl_system_items_kfv msi, --Modified for BT
                                                                          mtl_item_locations_kfv mil,
                     fnd_flex_values_vl ffv_styles, fnd_flex_value_sets ffvs_styles, fnd_flex_values_vl ffv_colors,
                     fnd_flex_value_sets ffvs_colors, mtl_parameters mp_cost, fnd_lookup_values lookup,
                     mtl_secondary_inventories subinv, xxd_common_items_v xciv -- Added for BT Remediation
               WHERE     moq.organization_id =
                         NVL (p_in_num_src_inv_org_id, moq.organization_id)
                     AND moq.subinventory_code =
                         NVL (p_in_chr_src_subinv, moq.subinventory_code)
                     AND moq.inventory_item_id = p_num_inv_item_id
                     AND moq.inventory_item_id = msi.inventory_item_id
                     AND moq.organization_id = msi.organization_id
                     --                  AND moq.subinventory_code <> 'STAGE'
                     AND moq.locator_id = mil.inventory_location_id(+)
                     AND moq.organization_id = mil.organization_id(+)
                     /*Commented for BT Remediation BEGIN*/
                     /* AND ffv_styles.flex_value = msi.segment1
                      AND ffv_styles.flex_value_set_id = ffvs_styles.flex_value_set_id
                      AND ffvs_styles.flex_value_set_name = 'DO_STYLES_CAT'
                      AND ffv_colors.flex_value = msi.segment2
                      AND ffv_colors.flex_value_set_id = ffvs_colors.flex_value_set_id
                      AND ffvs_colors.flex_value_set_name = 'DO_COLORS_CAT'*/
                     /*Commented for BT Remediation END*/
                     AND xciv.inventory_item_id = msi.inventory_item_id
                     AND xciv.organization_id = msi.organization_id
                     AND xciv.style_number =
                         NVL (p_in_chr_style, xciv.style_number)
                     AND xciv.color_code =
                         NVL (p_in_chr_color, xciv.color_code)
                     AND msi.attribute27 = NVL (p_in_chr_size, msi.attribute27)
                     AND mp_cost.organization_id = msi.organization_id
                     AND mp_cost.organization_code = lookup.attribute1
                     AND lookup.lookup_type = 'XXDO_INV_OH_CONV_SRC_TAR_MAP'
                     AND lookup.attribute2 = moq.subinventory_code
                     AND lookup.language = 'US'
                     AND lookup.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (lookup.start_date_active,
                                              SYSDATE - 1)
                                     AND NVL (lookup.end_date_active,
                                              SYSDATE + 1)
                     AND subinv.organization_id =
                         NVL (p_in_num_src_inv_org_id, moq.organization_id)
                     AND subinv.secondary_inventory_name =
                         moq.subinventory_code
            GROUP BY msi.segment1, msi.primary_uom_code, moq.subinventory_code,
                     subinv.asset_inventory, moq.locator_id, mil.concatenated_segments,
                     msi.description, msi.attribute11, ffv_styles.description,
                     ffv_colors.description, mp_cost.primary_cost_method, lookup.attribute6
              HAVING SUM (transaction_quantity) > 0
            ORDER BY lookup.attribute6;



        CURSOR cur_reservations IS
              SELECT organization_id, inventory_item_id, SUM (primary_reservation_quantity) reserved_qty
                FROM mtl_reservations
               WHERE     subinventory_Code IS NULL
                     AND organization_id = p_in_num_src_inv_org_id
                     AND inventory_item_id IN
                             (SELECT inventory_item_id FROM xxdo_inv_onhand_conv_stg)
            GROUP BY organization_id, inventory_item_id;


        CURSOR cur_stg_records (p_chr_subinv              IN VARCHAR2,
                                p_num_inventory_item_id   IN NUMBER)
        IS
              SELECT *
                FROM xxdo_inv_onhand_conv_stg
               WHERE     source_org_id = p_in_num_src_inv_org_id
                     AND source_subinventory = p_chr_subinv
                     AND inventory_item_id = p_num_inventory_item_id
                     AND process_status = 'NEW'
            --      AND request_id = g_num_request_id
            ORDER BY aging_date DESC;

        /*
            CURSOR cur_subinv
                    IS
               SELECT secondary_inventory_name
                  FROM mtl_secondary_inventories
               WHERE organization_id =p_in_num_src_inv_org_id
                   AND picking_order IS NOT NULL
               ORDER BY picking_order;
        */

        CURSOR cur_subinv IS
              SELECT lookup.attribute2 secondary_inventory_name
                FROM mtl_parameters mp_inner, fnd_lookup_values lookup
               WHERE     mp_inner.organization_id = p_in_num_src_inv_org_id
                     AND lookup.attribute1 = mp_inner.organization_code
                     AND lookup.lookup_type = 'XXDO_INV_OH_CONV_SRC_TAR_MAP'
                     AND lookup.language = 'US'
                     AND lookup.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (lookup.start_date_active,
                                              SYSDATE - 1)
                                     AND NVL (lookup.end_date_active,
                                              SYSDATE + 1)
            ORDER BY lookup.attribute6;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        IF p_in_chr_summary_level = 'SUBINVENTORY'
        THEN
            extract_req_oh (
                p_out_chr_errbuf          => l_chr_errbuf,
                p_out_chr_retcode         => l_chr_retcode,
                p_in_chr_brand            => p_in_chr_brand,
                p_in_chr_gender           => p_in_chr_gender,
                p_in_num_src_inv_org_id   => p_in_num_src_inv_org_id,
                p_in_chr_src_subinv       => p_in_chr_src_subinv,
                p_in_chr_product_group    => p_in_chr_product_group,
                p_in_chr_prod_subgroup    => p_in_chr_prod_subgroup,
                p_in_chr_style            => p_in_chr_style,
                p_in_chr_color            => p_in_chr_color,
                p_in_chr_size             => p_in_chr_size);

            p_out_chr_errbuf    := l_chr_errbuf;
            p_out_chr_retcode   := l_chr_retcode;
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Archiving the old records...');

            BEGIN
                INSERT INTO xxdo_inv_onhand_conv_log
                    SELECT stg.*, g_num_request_id, SYSDATE
                      FROM xxdo_inv_onhand_conv_stg stg;

                EXECUTE IMMEDIATE('TRUNCATE TABLE XXDO.XXDO_INV_ONHAND_CONV_STG');
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf    :=
                        'Error While archiving the old records : ' || SQLERRM;
                    p_out_chr_retcode   := '1';
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'Extracting the onhand records...');
            fnd_file.put_line (fnd_file.LOG, '');



            FOR cur_item_rec IN cur_item
            LOOP
                IF i > 0
                THEN
                    l_cur_rcv_txns.DELETE;
                    i   := 0;
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Item :' || cur_item_rec.inventory_item_id);

                FOR rcv_txn_rec
                    IN rcv_txns_1 (p_in_num_src_inv_org_id,
                                   cur_item_rec.inventory_item_id)
                LOOP
                    i                            := i + 1;
                    l_cur_rcv_txns (i).rcv_txn_id   :=
                        rcv_txn_rec.transaction_id;
                    l_cur_rcv_txns (i).item_id   := rcv_txn_rec.item_id;
                    l_cur_rcv_txns (i).transaction_date   :=
                        rcv_txn_rec.transaction_date;
                    l_cur_rcv_txns (i).quantity   :=
                        rcv_txn_rec.quantity;
                END LOOP;

                fnd_file.put_line (fnd_file.LOG,
                                   'Total receiving transactions :' || i);

                IF i > 0
                THEN
                    j               := 1;
                    l_num_rcv_qty   := l_cur_rcv_txns (1).quantity;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Transaction id :' || l_cur_rcv_txns (j).rcv_txn_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Transaction Qty :' || l_cur_rcv_txns (j).quantity);
                ELSE
                    l_num_rcv_qty   := 0;
                END IF;

                FOR cur_onhand_rec
                    IN cur_onhand (cur_item_rec.inventory_item_id)
                LOOP
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Onhand Quantity :' || cur_onhand_rec.quantity);

                    WHILE cur_onhand_rec.quantity > 0
                    LOOP
                        IF     (l_num_rcv_qty > 0)
                           AND (cur_onhand_rec.quantity <= l_num_rcv_qty)
                        THEN
                            INSERT INTO xxdo_inv_onhand_conv_stg (
                                            source_org_id,
                                            source_subinventory,
                                            source_locator_id,
                                            --                            target_org_id,
                                            --                            target_subinventory,
                                            inventory_item_id,
                                            quantity,
                                            uom,
                                            aging_date,
                                            rcv_transaction_id,
                                            brand,
                                            gender,
                                            product_group,
                                            product_subgroup,
                                            process_status,
                                            item_number,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            request_id,
                                            conv_seq_id,
                                            reserved_quantity,
                                            conv_quantity,
                                            style_name,
                                            color_name,
                                            upc,
                                            description,
                                            item_unit_cost,
                                            source_locator)
                                 VALUES (p_in_num_src_inv_org_id, cur_onhand_rec.subinventory_code, cur_onhand_rec.locator_id, --                            p_in_num_tar_inv_org_id,
                                                                                                                               --                            p_in_chr_tar_subinv,
                                                                                                                               cur_item_rec.inventory_item_id, cur_onhand_rec.quantity, cur_onhand_rec.primary_uom_code, DECODE (cur_onhand_rec.asset_inventory, 1, l_cur_rcv_txns (j).transaction_date, ADD_MONTHS (TRUNC (SYSDATE), -60)), l_cur_rcv_txns (j).rcv_txn_id, cur_item_rec.brand, cur_item_rec.gender, cur_item_rec.product_group, cur_item_rec.product_subgroup, DECODE (cur_onhand_rec.subinventory_code, 'STAGE', 'IGNORED', 'NEW'), cur_onhand_rec.item_number, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_request_id, xxdo_inv_onhand_conv_stg_s.NEXTVAL, 0, cur_onhand_rec.quantity, cur_onhand_rec.style_name, cur_onhand_rec.color_name, cur_onhand_rec.upc, cur_onhand_rec.description, cur_onhand_rec.item_unit_cost
                                         , cur_onhand_rec.source_locator);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Inserting Quantity1 :' || cur_onhand_rec.quantity);
                            l_num_rcv_qty             :=
                                l_num_rcv_qty - cur_onhand_rec.quantity;
                            cur_onhand_rec.quantity   := 0;
                            EXIT;                   /* exit from while loop */
                        ELSIF     l_num_rcv_qty > 0
                              AND cur_onhand_rec.quantity > l_num_rcv_qty
                        THEN
                            INSERT INTO xxdo_inv_onhand_conv_stg (
                                            source_org_id,
                                            source_subinventory,
                                            source_locator_id,
                                            --                            target_org_id,
                                            --                            target_subinventory,
                                            inventory_item_id,
                                            quantity,
                                            uom,
                                            aging_date,
                                            rcv_transaction_id,
                                            brand,
                                            gender,
                                            product_group,
                                            product_subgroup,
                                            process_status,
                                            item_number,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            request_id,
                                            conv_seq_id,
                                            reserved_quantity,
                                            conv_quantity,
                                            style_name,
                                            color_name,
                                            upc,
                                            description,
                                            item_unit_cost,
                                            source_locator)
                                 VALUES (p_in_num_src_inv_org_id, cur_onhand_rec.subinventory_code, cur_onhand_rec.locator_id, --                            p_in_num_tar_inv_org_id,
                                                                                                                               --                            p_in_chr_tar_subinv,
                                                                                                                               cur_item_rec.inventory_item_id, l_num_rcv_qty, cur_onhand_rec.primary_uom_code, DECODE (cur_onhand_rec.asset_inventory, 1, l_cur_rcv_txns (j).transaction_date, ADD_MONTHS (TRUNC (SYSDATE), -60)), l_cur_rcv_txns (j).rcv_txn_id, cur_item_rec.brand, cur_item_rec.gender, cur_item_rec.product_group, cur_item_rec.product_subgroup, DECODE (cur_onhand_rec.subinventory_code, 'STAGE', 'IGNORED', 'NEW'), cur_onhand_rec.item_number, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_request_id, xxdo_inv_onhand_conv_stg_s.NEXTVAL, 0, l_num_rcv_qty, cur_onhand_rec.style_name, cur_onhand_rec.color_name, cur_onhand_rec.upc, cur_onhand_rec.description, cur_onhand_rec.item_unit_cost
                                         , cur_onhand_rec.source_locator);

                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Inserting Quantity2 :' || l_num_rcv_qty);
                            cur_onhand_rec.quantity   :=
                                cur_onhand_rec.quantity - l_num_rcv_qty;
                            l_num_rcv_qty   := 0;
                        END IF;

                        IF l_num_rcv_qty = 0 AND j < i
                        THEN
                            j               := j + 1;
                            l_num_rcv_qty   := l_cur_rcv_txns (j).quantity;
                        ELSE
                            INSERT INTO xxdo_inv_onhand_conv_stg (
                                            source_org_id,
                                            source_subinventory,
                                            source_locator_id,
                                            --                            target_org_id,
                                            --                            target_subinventory,
                                            inventory_item_id,
                                            quantity,
                                            uom,
                                            aging_date,
                                            brand,
                                            gender,
                                            product_group,
                                            product_subgroup,
                                            process_status,
                                            item_number,
                                            creation_date,
                                            created_by,
                                            last_update_date,
                                            last_updated_by,
                                            request_id,
                                            conv_seq_id,
                                            reserved_quantity,
                                            conv_quantity,
                                            style_name,
                                            color_name,
                                            upc,
                                            description,
                                            item_unit_cost,
                                            source_locator)
                                     VALUES (
                                                p_in_num_src_inv_org_id,
                                                cur_onhand_rec.subinventory_code,
                                                cur_onhand_rec.locator_id,
                                                --                            p_in_num_tar_inv_org_id,
                                                --                            p_in_chr_tar_subinv,
                                                cur_item_rec.inventory_item_id,
                                                cur_onhand_rec.quantity,
                                                cur_onhand_rec.primary_uom_code,
                                                ADD_MONTHS (SYSDATE, -60) - 1,
                                                --DECODE( cur_onhand_rec.asset_inventory, 1, ADD_MONTHS (SYSDATE, -60) - 1, ADD_MONTHS (TRUNC (SYSDATE),-60)),
                                                cur_item_rec.brand,
                                                cur_item_rec.gender,
                                                cur_item_rec.product_group,
                                                cur_item_rec.product_subgroup,
                                                DECODE (
                                                    cur_onhand_rec.subinventory_code,
                                                    'STAGE', 'IGNORED',
                                                    'NEW'),
                                                cur_onhand_rec.item_number,
                                                SYSDATE,
                                                g_num_user_id,
                                                SYSDATE,
                                                g_num_user_id,
                                                g_num_request_id,
                                                xxdo_inv_onhand_conv_stg_s.NEXTVAL,
                                                0,
                                                cur_onhand_rec.quantity,
                                                cur_onhand_rec.style_name,
                                                cur_onhand_rec.color_name,
                                                cur_onhand_rec.upc,
                                                cur_onhand_rec.description,
                                                cur_onhand_rec.item_unit_cost,
                                                cur_onhand_rec.source_locator);

                            COMMIT;
                            cur_onhand_rec.quantity   := 0;
                        END IF;
                    END LOOP;
                END LOOP;
            END LOOP;

            COMMIT;

            fnd_file.put_line (
                fnd_file.LOG,
                'Updating Target Org ID and Target Subinventory...');


            UPDATE xxdo_inv_onhand_conv_stg stg
               SET (stg.target_org_id, stg.target_subinventory)   =
                       (SELECT mp_target.organization_id, flv.attribute4
                          FROM fnd_lookup_values flv, mtl_parameters mp_target, mtl_parameters mp_src
                         WHERE     flv.lookup_type =
                                   'XXDO_INV_OH_CONV_SRC_TAR_MAP'
                               AND flv.language = 'US'
                               AND flv.attribute1 = mp_src.organization_code
                               AND mp_src.organization_id = stg.source_org_id
                               AND flv.attribute2 = stg.source_subinventory
                               AND flv.attribute3 =
                                   mp_target.organization_code);

            COMMIT;


            /*
             fnd_file.put_line ( fnd_file.log, 'Updating Subinventory level reservations...' );

                  UPDATE xxdo_inv_onhand_conv_stg stg
                       SET (stg.reserved_quantity, stg.remarks) =
                       ( SELECT sum(mr.primary_reservation_quantity), 'Subinventory Reservation'
                            FROM mtl_reservations mr
                          WHERE mr.organization_id = stg.source_org_id
                              AND mr.inventory_item_id = stg.inventory_item_id
                              AND mr.subinventory_code = stg.source_subinventory)
                  WHERE stg.rowid IN
                          (
                          SELECT max(stg_inner.rowid)
                            FROM mtl_reservations mr,
                                     xxdo_inv_onhand_conv_stg stg_inner
                          WHERE mr.organization_id = stg.source_org_id
                              AND mr.inventory_item_id = stg.inventory_item_id
                              AND mr.subinventory_code = stg.source_subinventory
                              AND stg_inner.source_org_id = stg.source_org_id
                              AND stg_inner.source_subinventory = stg.source_subinventory
                              AND stg_inner.inventory_item_id = stg.inventory_item_id
                          );

            */
            fnd_file.put_line (fnd_file.LOG,
                               'Updating Org level / Soft reservations...');

            /*
                    UPDATE xxdo_inv_onhand_conv_stg stg
                       SET (stg.reserved_quantity, stg.remarks) =
                       ( SELECT sum(mr.primary_reservation_quantity), 'Soft Reservation'
                            FROM mtl_reservations mr
                          WHERE mr.organization_id = stg.source_org_id
                              AND mr.inventory_item_id = stg.inventory_item_id
                              AND mr.subinventory_code IS NULL )
                  WHERE stg.rowid IN
                          (
                          SELECT max(stg_inner.rowid)
                            FROM mtl_reservations mr,
                                     xxdo_inv_onhand_conv_stg stg_inner
                          WHERE mr.organization_id = stg.source_org_id
                              AND mr.inventory_item_id = stg.inventory_item_id
                              AND mr.subinventory_code IS NULL
                              AND stg_inner.source_org_id = stg.source_org_id
                              AND stg_inner.inventory_item_id = stg.inventory_item_id
                              AND stg_inner.reserved_quantity IS NULL
            --                  AND stg_inner.source_subinventory IN ('FLOW')
                          );
            */

            l_num_total_reserve_qty   := 0;

            FOR reservation_rec IN cur_reservations
            LOOP
                l_num_total_reserve_qty   := reservation_rec.reserved_qty;

                FOR subinv_rec IN cur_subinv
                LOOP
                    FOR stg_record
                        IN cur_stg_records (
                               subinv_rec.secondary_inventory_name,
                               reservation_rec.inventory_item_id)
                    LOOP
                        IF stg_record.quantity >= l_num_total_reserve_qty
                        THEN
                            UPDATE xxdo_inv_onhand_conv_stg
                               SET reserved_quantity = l_num_total_reserve_qty, conv_quantity = quantity - l_num_total_reserve_qty
                             WHERE conv_seq_id = stg_record.conv_seq_id;

                            l_num_total_reserve_qty   := 0;
                            EXIT;
                        ELSE
                            UPDATE xxdo_inv_onhand_conv_stg
                               SET reserved_quantity = quantity, conv_quantity = 0
                             WHERE conv_seq_id = stg_record.conv_seq_id;

                            l_num_total_reserve_qty   :=
                                l_num_total_reserve_qty - stg_record.quantity;
                        END IF;
                    END LOOP;             -- onhand staging table records loop

                    IF l_num_total_reserve_qty = 0
                    THEN
                        EXIT;
                    END IF;
                END LOOP;                                 -- Subinventory Loop

                IF l_num_total_reserve_qty > 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Reservations more than onhand, Inv Id: '
                        || reservation_rec.inventory_item_id);
                END IF;
            END LOOP;                                     -- reservations loop

            COMMIT;

            -- Update all the staging quantities as reserved.

            UPDATE xxdo_inv_onhand_conv_stg
               SET reserved_quantity = quantity, conv_quantity = 0
             WHERE source_subinventory = 'STAGE';

            COMMIT;

            fnd_file.put_line (fnd_file.LOG, 'Extract Completed');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error while extracting onhand :' || SQLERRM);
            ROLLBACK;
    END extract_oh;

    PROCEDURE perform_direct_transfer (
        p_out_chr_errbuf             OUT VARCHAR2,
        p_out_chr_retcode            OUT VARCHAR2,
        p_in_chr_brand            IN     VARCHAR2,
        p_in_chr_gender           IN     VARCHAR2,
        p_in_num_src_inv_org_id   IN     NUMBER,
        p_in_chr_src_subinv       IN     VARCHAR2,
        p_in_num_tar_inv_org_id   IN     NUMBER,
        p_in_chr_tar_subinv       IN     VARCHAR2)
    AS
        l_num_trans_interface_id   NUMBER;
        l_num_item_exists          NUMBER := 0;
        l_chr_error_buff           VARCHAR2 (2000);
        l_chr_error_code           VARCHAR2 (30);
        l_chr_return_status        VARCHAR2 (30);

        CURSOR cur_onhand IS
            SELECT *
              FROM xxdo_inv_onhand_conv_stg
             WHERE     process_status = 'NEW'
                   AND brand = NVL (p_in_chr_brand, brand)
                   AND gender = NVL (p_in_chr_gender, gender)
                   AND source_org_id =
                       NVL (p_in_num_src_inv_org_id, source_org_id)
                   AND source_subinventory =
                       NVL (p_in_chr_src_subinv, source_subinventory)
                   AND target_org_id =
                       NVL (p_in_num_tar_inv_org_id, target_org_id)
                   AND target_subinventory =
                       NVL (p_in_chr_tar_subinv, target_subinventory);

        TYPE l_onhand_tab_type IS TABLE OF cur_onhand%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_onhand_tab               l_onhand_tab_type;


        CURSOR cur_err_onhand IS
            SELECT *
              FROM xxdo_inv_onhand_conv_stg
             WHERE process_status = 'ERROR' AND conv_quantity > 0;


        l_exe_bulk_fetch_failed    EXCEPTION;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        fnd_file.put_line (fnd_file.LOG,
                           'Direct Org Transfer - Process Started...');

        OPEN cur_onhand;

        LOOP
            IF l_onhand_tab.EXISTS (1)
            THEN
                l_onhand_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_onhand BULK COLLECT INTO l_onhand_tab LIMIT 2000;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_onhand;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Onhand records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_onhand_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;


            FOR l_num_ind IN 1 .. l_onhand_tab.COUNT
            LOOP
                l_num_item_exists   := 0;

                BEGIN
                    SELECT COUNT (1)
                      INTO l_num_item_exists
                      FROM mtl_system_items_kfv msi          --Modified for BT
                     WHERE     msi.organization_id =
                               l_onhand_tab (l_num_ind).target_org_id
                           AND msi.inventory_item_id =
                               l_onhand_tab (l_num_ind).inventory_item_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_item_exists   := 0;
                END;

                IF l_num_item_exists = 0
                THEN
                    UPDATE xxdo_inv_onhand_conv_stg
                       SET error_message = 'Item does not exist in the target inventory org', process_status = 'ERROR', last_update_date = SYSDATE,
                           last_updated_by = g_num_user_id
                     WHERE conv_seq_id = l_onhand_tab (l_num_ind).conv_seq_id;
                ELSE
                    IF   l_onhand_tab (l_num_ind).quantity
                       - NVL (l_onhand_tab (l_num_ind).reserved_quantity, 0) <=
                       0
                    THEN
                        UPDATE xxdo_inv_onhand_conv_stg
                           SET error_message = 'Zero or Negative Transaction Qty', process_status = 'ERROR', last_update_date = SYSDATE,
                               last_updated_by = g_num_user_id
                         WHERE conv_seq_id =
                               l_onhand_tab (l_num_ind).conv_seq_id;
                    ELSE
                        SELECT mtl_material_transactions_s.NEXTVAL
                          INTO l_num_trans_interface_id
                          FROM DUAL;


                        INSERT INTO mtl_transactions_interface (
                                        source_code,
                                        source_header_id,
                                        source_line_id,
                                        process_flag,
                                        --lock_flag,
                                        transaction_mode,
                                        last_update_date,
                                        last_updated_by,
                                        creation_date,
                                        created_by,
                                        organization_id,
                                        subinventory_code,
                                        locator_id,
                                        transfer_organization,
                                        transfer_subinventory,
                                        inventory_item_id,
                                        transaction_quantity,
                                        transaction_uom,
                                        transaction_date,
                                        transaction_type_id,
                                        transaction_action_id,
                                        transaction_source_type_id,
                                        transaction_interface_id,
                                        transaction_header_id,
                                        attribute1)
                                 VALUES (
                                            'OH' || g_num_request_id, --Source Code
                                            l_num_trans_interface_id, -- Source Header ID
                                            1,               -- Source Line ID
                                            1,                 -- Process Flag
                                            --2, --Lock Flag
                                            3,     -- Transaction mode - batch
                                            SYSDATE,          -- Creation Date
                                            g_num_user_id,       -- Created by
                                            SYSDATE,       -- Last update date
                                            g_num_user_id,   -- Last Update by
                                            l_onhand_tab (l_num_ind).source_org_id,
                                            l_onhand_tab (l_num_ind).source_subinventory,
                                            l_onhand_tab (l_num_ind).source_locator_id,
                                            l_onhand_tab (l_num_ind).target_org_id,
                                            l_onhand_tab (l_num_ind).target_subinventory,
                                            l_onhand_tab (l_num_ind).inventory_item_id,
                                              --                             l_onhand_tab (l_num_ind).quantity,
                                              l_onhand_tab (l_num_ind).quantity
                                            - NVL (
                                                  l_onhand_tab (l_num_ind).reserved_quantity,
                                                  0),
                                            l_onhand_tab (l_num_ind).uom,
                                            SYSDATE,       -- Transaction Date
                                            3, --  Transaction Type  -- Direct Org Transfer
                                            3,           -- Transaction Action
                                            13,  -- Transaction Source Type id
                                            l_num_trans_interface_id,
                                            l_num_trans_interface_id,
                                            TO_CHAR (
                                                l_onhand_tab (l_num_ind).aging_date,
                                                'DD-MON-YYYY'));

                        UPDATE xxdo_inv_onhand_conv_stg
                           SET transaction_header_id = l_num_trans_interface_id, process_status = 'INPROCESS', last_update_date = SYSDATE,
                               last_updated_by = g_num_user_id
                         WHERE conv_seq_id =
                               l_onhand_tab (l_num_ind).conv_seq_id;
                    END IF;
                END IF;
            END LOOP;
        END LOOP;

        CLOSE cur_onhand;

        COMMIT;

        fnd_file.put_line (fnd_file.LOG,
                           'Direct Org Transfer - Interface table populated');

        processing_oh (p_out_error_buff      => l_chr_error_buff,
                       p_out_error_code      => l_chr_error_code,
                       p_out_return_status   => l_chr_return_status);


        fnd_file.put_line (
            fnd_file.LOG,
            'Direct Org Transfer - Updating the staging table...');

        UPDATE xxdo_inv_onhand_conv_stg stg
           SET (stg.process_status, stg.error_message, stg.last_update_date,
                stg.last_updated_by)   =
                   (SELECT 'ERROR', REPLACE (mti.error_explanation, CHR (10), ';'), SYSDATE,
                           g_num_user_id
                      FROM mtl_transactions_interface mti
                     WHERE     mti.process_flag = 3
                           AND (mti.ERROR_CODE IS NOT NULL OR mti.error_explanation IS NOT NULL)
                           AND mti.transaction_interface_id =
                               stg.transaction_header_id
                           --                        AND mti.transaction_header_id = stg.transaction_header_id
                           AND mti.organization_id = stg.source_org_id
                           AND mti.subinventory_code =
                               stg.source_subinventory
                           AND mti.inventory_item_id = stg.inventory_item_id)
         WHERE     stg.process_status = 'INPROCESS'
               AND EXISTS
                       (SELECT 1
                          FROM mtl_transactions_interface mti
                         WHERE     mti.process_flag = 3
                               AND (mti.ERROR_CODE IS NOT NULL OR mti.error_explanation IS NOT NULL)
                               AND mti.transaction_interface_id =
                                   stg.transaction_header_id
                               --                        AND mti.transaction_header_id = stg.transaction_header_id
                               AND mti.organization_id = stg.source_org_id
                               AND mti.subinventory_code =
                                   stg.source_subinventory
                               AND mti.inventory_item_id =
                                   stg.inventory_item_id);

        UPDATE xxdo_inv_onhand_conv_stg stg
           SET process_status = 'PROCESSED', last_update_date = SYSDATE, last_updated_by = g_num_user_id
         WHERE process_status = 'INPROCESS';

        COMMIT;

        -- Updating the error qty at HJ extract table
        FOR err_onhand_rec IN cur_err_onhand
        LOOP
            UPDATE xxdo_inv_hj_onhand_stg hj_stg
               SET hj_stg.errored_qty = NVL (hj_stg.errored_qty, 0) + err_onhand_rec.conv_quantity
             WHERE     hj_stg.source_org_id = err_onhand_rec.source_org_id
                   AND hj_stg.source_subinventory =
                       err_onhand_rec.source_subinventory
                   AND hj_stg.source_locator_id =
                       err_onhand_rec.source_locator_id
                   AND hj_stg.inventory_item_id =
                       err_onhand_rec.inventory_item_id;
        END LOOP;


        COMMIT;


        /*

                UPDATE xxdo_inv_hj_onhand_stg hj_stg
                     SET process_status = 'ERROR',
                            last_update_date = SYSDATE,
                            last_updated_by = g_num_user_id
                 WHERE process_status = 'NEW'
                     AND EXISTS (
                                        SELECT 1
                                          FROM  xxdo_inv_onhand_conv_stg stg
                                        WHERE stg.source_org_id = hj_stg.source_org_id
                                           AND stg.source_subinventory = hj_stg.source_subinventory
                                           AND stg.source_locator_id = hj_stg.source_locator_id
                                           AND stg.inventory_item_id = hj_stg.inventory_item_id
                                           AND stg.process_status = 'ERROR'
                                           );


                UPDATE xxdo_inv_hj_onhand_stg hj_stg
                     SET process_status = 'PROCESSED',
                            last_update_date = SYSDATE,
                            last_updated_by = g_num_user_id
                 WHERE process_status = 'NEW'
                     AND EXISTS (
                                        SELECT 1
                                          FROM  xxdo_inv_onhand_conv_stg stg
                                        WHERE stg.source_org_id = hj_stg.source_org_id
                                           AND stg.source_subinventory = hj_stg.source_subinventory
                                           AND stg.source_locator_id = hj_stg.source_locator_id
                                           AND stg.inventory_item_id = hj_stg.inventory_item_id
                                           AND stg.process_status = 'PROCESSED'
                                           );

                 COMMIT;

        */


        fnd_file.put_line (fnd_file.LOG,
                           'Direct Org Transfer - Process Ended');
    EXCEPTION
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error while performing direct transfer :'
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            ROLLBACK;
    END perform_direct_transfer;

    /********************************************************************
     * PROCEDURE:        processing_oh                            *
     * PURPOSE:          To launch the concurrent request               *
     *                   Process transaction interface                  *
     *                                                                  *
     * INPUT Parameters: p_in_region_code                               *
     *                   p_in_run_mode                                  *
     * OUTPUT Parametrs: p_out_error_buff                               *
     *                   p_out_error_code                               *
     *                   p_out_return_status                            *
     *                                                                  *
     * Author   Date      Ver   Description                             *
     * ------ ----------  ---   ----------------------------------------*
     * Infosys 02/16/2015 1.00  Created                                 *
     *                                                                  *
     ********************************************************************/
    PROCEDURE processing_oh (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT VARCHAR2, p_out_return_status OUT VARCHAR2)
    IS
        l_chr_phase        VARCHAR2 (120 BYTE);
        l_chr_status       VARCHAR2 (120 BYTE);
        l_chr_dev_phase    VARCHAR2 (120 BYTE);
        l_chr_dev_status   VARCHAR2 (120 BYTE);
        l_chr_message      VARCHAR2 (2000 BYTE);
        l_num_request_id   NUMBER := 0;
        l_bol_result       BOOLEAN;
        l_chr_valid        VARCHAR2 (1);

        CURSOR cur_child_requests IS
            SELECT request_id
              FROM fnd_concurrent_requests
             WHERE parent_request_id = l_num_request_id;
    BEGIN
        p_out_return_status   := 0;
        p_out_error_buff      := NULL;
        p_out_error_code      := '0';

        --Initializing the environment
        --ci_utility_pkg.set_org('$P_ORG_ID');
        --ci_utility_pkg.initialize($FCP_USERID,$FCP_REQID);

        --Submit the Request for Inventory Transactions Processor
        fnd_file.put_line (fnd_file.LOG,
                           'Starting to submit the processor...' || CHR (10));
        l_num_request_id      :=
            fnd_request.submit_request (application   => 'INV',
                                        program       => 'INCTCM');
        fnd_file.put_line (
            fnd_file.LOG,
               'The Inventory Transaction Processor Request id is '
            || l_num_request_id
            || CHR (10));
        COMMIT;

        IF l_num_request_id <> 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Waiting for the request to finish...');
            --Waiting for the request to finish
            l_bol_result   :=
                fnd_concurrent.wait_for_request (l_num_request_id,
                                                 10,
                                                 0,
                                                 l_chr_phase,
                                                 l_chr_status,
                                                 l_chr_dev_phase,
                                                 l_chr_dev_status,
                                                 l_chr_message);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Inventory Transaction Processor completed with '
                || l_chr_dev_phase
                || ':'
                || l_chr_dev_status
                || CHR (10));

            --If request gets completed
            IF l_chr_dev_phase = 'COMPLETE'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Finished Running Request : '
                    || l_num_request_id
                    || CHR (10));

                IF l_chr_dev_status = 'WARNING'
                THEN
                    p_out_return_status   := 2;
                ELSIF l_chr_dev_status = 'ERROR'
                THEN
                    p_out_return_status   := 1;
                END IF;

                FOR l_request_rec IN cur_child_requests
                LOOP
                    l_bol_result   :=
                        fnd_concurrent.wait_for_request (
                            l_request_rec.request_id,
                            10,
                            0,
                            l_chr_phase,
                            l_chr_status,
                            l_chr_dev_phase,
                            l_chr_dev_status,
                            l_chr_message);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Before inventory worker child request');

                    --If request gets completed
                    IF l_chr_dev_phase = 'COMPLETE'
                    THEN
                        IF l_chr_dev_status = 'WARNING'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   '@ERROR :-Inventory worker child request ended in warning, Request ID: '
                                || l_request_rec.request_id
                                || CHR (10));
                            p_out_return_status   := 1;
                            p_out_error_buff      :=
                                   '@ERROR :-Inventory worker child request ended in warning, Request ID: '
                                || l_request_rec.request_id
                                || CHR (10);
                            p_out_error_code      := '2';
                        ELSIF l_chr_dev_status = 'ERROR'
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   '@ERROR :-Inventory worker child request ended in error, Request ID: '
                                || l_request_rec.request_id
                                || CHR (10));
                            p_out_return_status   := 1;
                            p_out_error_buff      :=
                                   '@ERROR :-Inventory worker child request ended in error, Request ID: '
                                || l_request_rec.request_id
                                || CHR (10);
                            p_out_error_code      := '2';
                        END IF;
                    END IF;
                END LOOP;
            END IF;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                   'Failed to submit concurrent request: '
                || SUBSTR (SQLERRM, 1, 150));
            p_out_error_buff      :=
                   'Failed to submit concurrent request: '
                || SUBSTR (SQLERRM, 1, 150);
            p_out_error_code      := '2';
            p_out_return_status   := 1;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'After inventory worker child request');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Occurred while calling Inventory Transaction Processor-'
                || SUBSTR (SQLERRM, 1, 240));
            p_out_return_status   := 1;
            p_out_error_buff      :=
                   'Error Occurred while calling Inventory Transaction Processor-'
                || SUBSTR (SQLERRM, 1, 240);
            p_out_error_code      := '2';
    END processing_oh;



    PROCEDURE extract_req_oh (p_out_chr_errbuf             OUT VARCHAR2,
                              p_out_chr_retcode            OUT VARCHAR2,
                              p_in_chr_brand            IN     VARCHAR2,
                              p_in_chr_gender           IN     VARCHAR2,
                              p_in_num_src_inv_org_id   IN     NUMBER,
                              p_in_chr_src_subinv       IN     VARCHAR2,
                              --                                    p_in_num_tar_inv_org_id IN NUMBER,
                              --                                    p_in_chr_tar_subinv IN VARCHAR2, --,
                              p_in_chr_product_group    IN     VARCHAR2,
                              p_in_chr_prod_subgroup    IN     VARCHAR2,
                              p_in_chr_style            IN     VARCHAR2,
                              p_in_chr_color            IN     VARCHAR2,
                              p_in_chr_size             IN     VARCHAR2)
    AS
        l_num_src_org_id          NUMBER := p_in_num_src_inv_org_id;
        --   l_num_tar_org_id   NUMBER   :=
        l_num_item_id             NUMBER;           --:= p_in_num_inv_item_id;
        l_num_curr_item           NUMBER := -1;
        l_num_prev_item           NUMBER := -1;

        l_num_total_reserve_qty   NUMBER := 0;

        i                         NUMBER := 0;
        j                         NUMBER := 0;
        l_num_rcv_qty             NUMBER := 0;


        TYPE rcv_txn_rec IS RECORD
        (
            rcv_txn_id          NUMBER,
            item_id             NUMBER,
            transaction_date    DATE,
            quantity            NUMBER
        );

        TYPE rcv_txns IS TABLE OF rcv_txn_rec
            INDEX BY PLS_INTEGER;

        l_cur_rcv_txns            rcv_txns;

        CURSOR rcv_txns_1 (p_num_src_org_id   IN NUMBER,
                           p_num_item_id      IN NUMBER)
        IS
            SELECT transaction_id, item_id, transaction_date,
                   (qty + corrected_qty) quantity
              FROM (SELECT rcvt.transaction_id,
                           rsl.item_id,
                           rcvt.transaction_date transaction_date,
                           NVL (rcvt.quantity, 0) qty,
                           (SELECT NVL (SUM (quantity), 0)
                              FROM apps.rcv_transactions rcvt1
                             WHERE     rcvt1.parent_transaction_id =
                                       rcvt.transaction_id
                                   AND rcvt1.transaction_type = 'CORRECT') corrected_qty
                      FROM apps.rcv_shipment_lines rsl, apps.rcv_transactions rcvt
                     WHERE     rcvt.transaction_type = 'DELIVER'
                           AND rcvt.destination_type_code = 'INVENTORY'
                           AND rsl.source_document_code = 'PO'
                           AND rcvt.transaction_date >=
                               ADD_MONTHS (TRUNC (SYSDATE), -60)
                           AND rsl.shipment_line_id = rcvt.shipment_line_id
                           AND rsl.item_id = p_num_item_id
                           AND rcvt.organization_id = p_num_src_org_id) x
             WHERE (qty + corrected_qty) > 0
            UNION ALL
            SELECT transaction_id, item_id, transaction_date,
                   (receipt_quantity + corrected_qty) quantity
              FROM (SELECT rcvt.organization_id,
                           prl.item_id,
                           NVL (
                               TRUNC (
                                   TO_DATE (prl.attribute3, 'DD-MON-YYYY')),
                               TRUNC (rcvt.transaction_date))
                               transaction_date,
                           rcvt.transaction_id,
                           rcvt.quantity
                               receipt_quantity,
                           (SELECT NVL (SUM (quantity), 0)
                              FROM apps.rcv_transactions rcvt1
                             WHERE     rcvt1.parent_transaction_id =
                                       rcvt.transaction_id
                                   AND rcvt1.transaction_type = 'CORRECT')
                               corrected_qty
                      FROM apps.rcv_transactions rcvt, apps.po_requisition_lines_all prl
                     WHERE     prl.item_id = p_num_item_id
                           AND rcvt.organization_id = p_num_src_org_id
                           AND rcvt.requisition_line_id =
                               prl.requisition_line_id
                           AND rcvt.transaction_type = 'DELIVER'
                           AND rcvt.destination_type_code = 'INVENTORY'
                           AND prl.source_type_code = 'INVENTORY'
                           AND rcvt.transaction_date >=
                               ADD_MONTHS (TRUNC (SYSDATE), -12)) y
             WHERE (receipt_quantity + corrected_qty) > 0
            ORDER BY transaction_date DESC;

        CURSOR cur_item IS
            SELECT DISTINCT moq.inventory_item_id, --                          msi.primary_uom_code,
                                                   --                          msi.segment1  item_number,      --Modified for BT
                                                   mc.segment1 brand, mc.segment2 gender, --Modified for BT
                            mc.segment3 product_group,       --Modified for BT
                                                       mc.segment4 product_subgroup
              FROM mtl_onhand_quantities moq, mtl_categories_b mc, mtl_item_categories mic,
                   mtl_category_sets mcs, --  mtl_system_items_b msi               --Modified for BT
                                          mtl_system_items_kfv msi, xxd_common_items_v xciv --Added for BT Remediation
             WHERE     moq.organization_id =
                       NVL (p_in_num_src_inv_org_id, moq.organization_id)
                   AND moq.subinventory_code =
                       NVL (p_in_chr_src_subinv, moq.subinventory_code)
                   --                  AND moq.inventory_item_id = NVL(p_in_num_inv_item_id, moq.inventory_item_id)
                   AND mc.segment1 = NVL (p_in_chr_brand, mc.segment1)
                   AND mc.segment2 = NVL (p_in_chr_gender, mc.segment2)
                   AND mc.segment3 =
                       NVL (p_in_chr_product_group, mc.segment3)
                   AND mc.segment4 =
                       NVL (p_in_chr_prod_subgroup, mc.segment4)
                   AND moq.organization_id = mic.organization_id
                   AND mic.inventory_item_id = moq.inventory_item_id
                   AND mcs.category_set_id = mic.category_set_id
                   AND mcs.category_set_id = 1
                   --                    AND mcs.category_id = mc.category_id
                   AND mic.inventory_item_id = moq.inventory_item_id
                   AND mc.category_id = mic.category_id
                   AND moq.organization_id = msi.organization_id
                   AND msi.inventory_item_id = moq.inventory_item_id
                   AND msi.organization_id =
                       NVL (p_in_num_src_inv_org_id, msi.organization_id)
                   /*AND msi.segment1 = NVL (p_in_chr_style, msi.segment1)
                   AND msi.segment2 = NVL (p_in_chr_color, msi.segment2)
                   AND msi.segment3 = NVL (p_in_chr_size, msi.segment3)*/
                   AND xciv.inventory_item_id = msi.inventory_item_id
                   AND xciv.organization_id = msi.organization_id
                   AND xciv.category_set_id = mcs.category_set_id
                   AND xciv.category_id = mc.category_id
                   AND xciv.style_number =
                       NVL (p_in_chr_style, xciv.style_number)
                   AND xciv.color_code =
                       NVL (p_in_chr_color, xciv.color_code)
                   AND msi.attribute27 = NVL (p_in_chr_size, msi.attribute27)
                   --                    AND moq.subinventory_code <> 'STAGE'
                   AND moq.subinventory_code IN
                           (SELECT lookup.attribute2
                              FROM mtl_parameters mp_inner, fnd_lookup_values lookup
                             WHERE     mp_inner.organization_id =
                                       p_in_num_src_inv_org_id
                                   AND lookup.attribute1 =
                                       mp_inner.organization_code
                                   AND lookup.lookup_type =
                                       'XXDO_INV_OH_CONV_SRC_TAR_MAP'
                                   AND lookup.language = 'US'
                                   AND lookup.enabled_flag = 'Y'
                                   AND SYSDATE BETWEEN NVL (
                                                           lookup.start_date_active,
                                                           SYSDATE - 1)
                                                   AND NVL (
                                                           lookup.end_date_active,
                                                           SYSDATE + 1));


        CURSOR cur_onhand (p_num_inv_item_id IN NUMBER)
        IS
              SELECT SUM (transaction_quantity) quantity,
                     moq.subinventory_code,
                     NULL locator_id,
                     msi.segment1 item_number,               --Modified for BT
                     msi.primary_uom_code,
                     msi.description,
                     /*ffv_styles.description style_name,
                      ffv_colors.description color_name,*/
                     xciv.style_desc style_name,
                     xciv.color_desc color_name,
                     DECODE (msi.attribute11,
                             NULL, NULL,
                             '''' || msi.attribute11 || '''') upc,
                     NVL (
                         (SELECT cic.item_cost
                            FROM cst_item_costs cic
                           WHERE     cic.organization_id =
                                     p_in_num_src_inv_org_id
                                 AND cic.inventory_item_id = p_num_inv_item_id
                                 AND cic.cost_type_id =
                                     mp_cost.primary_cost_method),
                         0) item_unit_cost,
                     --                     mil.concatenated_segments source_locator
                     NULL source_locator,
                     subinv.asset_inventory,
                     subinv.availability_type
                FROM mtl_onhand_quantities moq, --                   mtl_system_items_b msi,               --Modified for BT
                                                --                    mtl_item_locations_kfv mil,
                                                mtl_system_items_kfv msi, fnd_flex_values_vl ffv_styles,
                     fnd_flex_value_sets ffvs_styles, fnd_flex_values_vl ffv_colors, fnd_flex_value_sets ffvs_colors,
                     mtl_parameters mp_cost, fnd_lookup_values lookup, mtl_secondary_inventories subinv,
                     xxd_common_items_v xciv                    --Added for BT
               WHERE     moq.organization_id =
                         NVL (p_in_num_src_inv_org_id, moq.organization_id)
                     AND moq.subinventory_code =
                         NVL (p_in_chr_src_subinv, moq.subinventory_code)
                     AND moq.inventory_item_id = p_num_inv_item_id
                     AND moq.inventory_item_id = msi.inventory_item_id
                     AND moq.organization_id = msi.organization_id
                     --                  AND moq.subinventory_code <> 'STAGE'
                     --                  AND moq.locator_id = mil.inventory_location_id(+)
                     --                  AND moq.organization_id = mil.organization_id(+)
                     /*Commented for BT Remediation START*/
                     /* AND ffv_styles.flex_value = msi.segment1
                      AND ffv_styles.flex_value_set_id = ffvs_styles.flex_value_set_id
                      AND ffvs_styles.flex_value_set_name = 'DO_STYLES_CAT'
                      AND ffv_colors.flex_value = msi.segment2
                      AND ffv_colors.flex_value_set_id = ffvs_colors.flex_value_set_id
                      AND ffvs_colors.flex_value_set_name = 'DO_COLORS_CAT'*/
                     /*Commented for BT Remediation END*/
                     AND xciv.inventory_item_id = msi.inventory_item_id
                     AND xciv.organization_id = msi.organization_id
                     AND xciv.style_number =
                         NVL (p_in_chr_style, xciv.style_number)
                     AND xciv.color_code =
                         NVL (p_in_chr_color, xciv.color_code)
                     AND msi.attribute27 = NVL (p_in_chr_size, msi.attribute27)
                     AND mp_cost.organization_id = msi.organization_id
                     AND mp_cost.organization_code = lookup.attribute1
                     AND lookup.lookup_type = 'XXDO_INV_OH_CONV_SRC_TAR_MAP'
                     AND lookup.attribute2 = moq.subinventory_code
                     AND lookup.language = 'US'
                     AND lookup.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (lookup.start_date_active,
                                              SYSDATE - 1)
                                     AND NVL (lookup.end_date_active,
                                              SYSDATE + 1)
                     AND subinv.organization_id =
                         NVL (p_in_num_src_inv_org_id, moq.organization_id)
                     AND subinv.secondary_inventory_name =
                         moq.subinventory_code
            GROUP BY msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3, msi.primary_uom_code, moq.subinventory_code,
                     --                     moq.locator_id,
                     --                     mil.concatenated_segments,
                     msi.description, msi.attribute11, ffv_styles.description,
                     ffv_colors.description, mp_cost.primary_cost_method, lookup.attribute7,
                     subinv.asset_inventory, subinv.availability_type
              HAVING SUM (transaction_quantity) > 0
            ORDER BY TO_NUMBER (lookup.attribute7) DESC; --- Changed after UGG Kids


        CURSOR cur_reservations IS
              SELECT organization_id, inventory_item_id, SUM (primary_reservation_quantity) reserved_qty
                FROM mtl_reservations
               WHERE     subinventory_Code IS NULL
                     AND organization_id = p_in_num_src_inv_org_id
                     AND inventory_item_id IN
                             (SELECT inventory_item_id
                                FROM xxdo_inv_onhand_conv_stg
                               WHERE request_id = g_num_request_id)
            GROUP BY organization_id, inventory_item_id;

        CURSOR cur_hard_reservations IS
              SELECT organization_id, subinventory_code, inventory_item_id,
                     SUM (primary_reservation_quantity) reserved_qty
                FROM mtl_reservations
               WHERE     subinventory_Code IS NOT NULL
                     AND subinventory_Code <> 'STAGE'
                     AND organization_id = p_in_num_src_inv_org_id
                     AND inventory_item_id IN
                             (SELECT inventory_item_id FROM xxdo_inv_onhand_conv_stg)
            GROUP BY organization_id, subinventory_code, inventory_item_id
            ORDER BY subinventory_code;

        CURSOR cur_stg_records (p_chr_subinv              IN VARCHAR2,
                                p_num_inventory_item_id   IN NUMBER)
        IS
              SELECT *
                FROM xxdo_inv_onhand_conv_stg
               WHERE     source_org_id = p_in_num_src_inv_org_id
                     AND source_subinventory = p_chr_subinv
                     AND inventory_item_id = p_num_inventory_item_id
                     AND process_status = 'NEW'
                     AND conv_quantity > 0
                     AND request_id = g_num_request_id
            ORDER BY aging_date DESC;

        CURSOR cur_subinv IS
              SELECT lookup.attribute2 secondary_inventory_name
                FROM mtl_parameters mp_inner, fnd_lookup_values lookup
               WHERE     mp_inner.organization_id = p_in_num_src_inv_org_id
                     AND lookup.attribute1 = mp_inner.organization_code
                     AND lookup.lookup_type = 'XXDO_INV_OH_CONV_SRC_TAR_MAP'
                     AND lookup.language = 'US'
                     AND lookup.enabled_flag = 'Y'
                     AND SYSDATE BETWEEN NVL (lookup.start_date_active,
                                              SYSDATE - 1)
                                     AND NVL (lookup.end_date_active,
                                              SYSDATE + 1)
            ORDER BY TO_NUMBER (lookup.attribute6);
    BEGIN
        p_out_chr_errbuf          := NULL;
        p_out_chr_retcode         := '0';


        fnd_file.put_line (fnd_file.LOG, 'Extracting the onhand records...');
        fnd_file.put_line (fnd_file.LOG, '');

        FOR cur_item_rec IN cur_item
        LOOP
            IF i > 0
            THEN
                l_cur_rcv_txns.DELETE;
                i   := 0;
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Item :' || cur_item_rec.inventory_item_id);

            FOR rcv_txn_rec
                IN rcv_txns_1 (p_in_num_src_inv_org_id,
                               cur_item_rec.inventory_item_id)
            LOOP
                i                                     := i + 1;
                l_cur_rcv_txns (i).rcv_txn_id         := rcv_txn_rec.transaction_id;
                l_cur_rcv_txns (i).item_id            := rcv_txn_rec.item_id;
                l_cur_rcv_txns (i).transaction_date   :=
                    rcv_txn_rec.transaction_date;
                l_cur_rcv_txns (i).quantity           := rcv_txn_rec.quantity;
            END LOOP;

            fnd_file.put_line (fnd_file.LOG,
                               'Total receiving transactions :' || i);

            IF i > 0
            THEN
                j               := 1;
                l_num_rcv_qty   := l_cur_rcv_txns (1).quantity;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Transaction id :' || l_cur_rcv_txns (j).rcv_txn_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Transaction Qty :' || l_cur_rcv_txns (j).quantity);
            ELSE
                l_num_rcv_qty   := 0;
            END IF;

            FOR cur_onhand_rec IN cur_onhand (cur_item_rec.inventory_item_id)
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Onhand Quantity :' || cur_onhand_rec.quantity);

                WHILE cur_onhand_rec.quantity > 0
                LOOP
                    IF     (l_num_rcv_qty > 0)
                       AND (cur_onhand_rec.quantity <= l_num_rcv_qty)
                    THEN
                        INSERT INTO xxdo_inv_onhand_conv_stg (
                                        source_org_id,
                                        source_subinventory,
                                        source_locator_id,
                                        --                            target_org_id,
                                        --                            target_subinventory,
                                        inventory_item_id,
                                        quantity,
                                        uom,
                                        aging_date,
                                        rcv_transaction_id,
                                        brand,
                                        gender,
                                        product_group,
                                        product_subgroup,
                                        process_status,
                                        item_number,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        request_id,
                                        conv_seq_id,
                                        reserved_quantity,
                                        conv_quantity,
                                        style_name,
                                        color_name,
                                        upc,
                                        description,
                                        item_unit_cost,
                                        source_locator)
                             VALUES (p_in_num_src_inv_org_id, cur_onhand_rec.subinventory_code, cur_onhand_rec.locator_id, --                            p_in_num_tar_inv_org_id,
                                                                                                                           --                            p_in_chr_tar_subinv,
                                                                                                                           cur_item_rec.inventory_item_id, cur_onhand_rec.quantity, cur_onhand_rec.primary_uom_code, --                            l_cur_rcv_txns (j).transaction_date,
                                                                                                                                                                                                                     DECODE (cur_onhand_rec.asset_inventory, 1, DECODE (cur_onhand_rec.availability_type, 1, l_cur_rcv_txns (j).transaction_date, ADD_MONTHS (TRUNC (SYSDATE), -60)), ADD_MONTHS (TRUNC (SYSDATE), -60)), l_cur_rcv_txns (j).rcv_txn_id, cur_item_rec.brand, cur_item_rec.gender, cur_item_rec.product_group, cur_item_rec.product_subgroup, --                            'NEW',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             DECODE (cur_onhand_rec.subinventory_code, 'STAGE', 'IGNORED', 'NEW'), cur_onhand_rec.item_number, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_request_id, xxdo_inv_onhand_conv_stg_s.NEXTVAL, 0, cur_onhand_rec.quantity, cur_onhand_rec.style_name, cur_onhand_rec.color_name, cur_onhand_rec.upc, cur_onhand_rec.description, cur_onhand_rec.item_unit_cost
                                     , cur_onhand_rec.source_locator);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Inserting Quantity1 :' || cur_onhand_rec.quantity);
                        l_num_rcv_qty             :=
                            l_num_rcv_qty - cur_onhand_rec.quantity;
                        cur_onhand_rec.quantity   := 0;
                        EXIT;                       /* exit from while loop */
                    ELSIF     l_num_rcv_qty > 0
                          AND cur_onhand_rec.quantity > l_num_rcv_qty
                    THEN
                        INSERT INTO xxdo_inv_onhand_conv_stg (
                                        source_org_id,
                                        source_subinventory,
                                        source_locator_id,
                                        --                            target_org_id,
                                        --                            target_subinventory,
                                        inventory_item_id,
                                        quantity,
                                        uom,
                                        aging_date,
                                        rcv_transaction_id,
                                        brand,
                                        gender,
                                        product_group,
                                        product_subgroup,
                                        process_status,
                                        item_number,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        request_id,
                                        conv_seq_id,
                                        reserved_quantity,
                                        conv_quantity,
                                        style_name,
                                        color_name,
                                        upc,
                                        description,
                                        item_unit_cost,
                                        source_locator)
                             VALUES (p_in_num_src_inv_org_id, cur_onhand_rec.subinventory_code, cur_onhand_rec.locator_id, --                            p_in_num_tar_inv_org_id,
                                                                                                                           --                            p_in_chr_tar_subinv,
                                                                                                                           cur_item_rec.inventory_item_id, l_num_rcv_qty, cur_onhand_rec.primary_uom_code, --                            l_cur_rcv_txns (j).transaction_date,
                                                                                                                                                                                                           DECODE (cur_onhand_rec.asset_inventory, 1, DECODE (cur_onhand_rec.availability_type, 1, l_cur_rcv_txns (j).transaction_date, ADD_MONTHS (TRUNC (SYSDATE), -60)), ADD_MONTHS (TRUNC (SYSDATE), -60)), l_cur_rcv_txns (j).rcv_txn_id, cur_item_rec.brand, cur_item_rec.gender, cur_item_rec.product_group, cur_item_rec.product_subgroup, --                            'NEW',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   DECODE (cur_onhand_rec.subinventory_code, 'STAGE', 'IGNORED', 'NEW'), cur_onhand_rec.item_number, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id, g_num_request_id, xxdo_inv_onhand_conv_stg_s.NEXTVAL, 0, l_num_rcv_qty, cur_onhand_rec.style_name, cur_onhand_rec.color_name, cur_onhand_rec.upc, cur_onhand_rec.description, cur_onhand_rec.item_unit_cost
                                     , cur_onhand_rec.source_locator);

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Inserting Quantity2 :' || l_num_rcv_qty);
                        cur_onhand_rec.quantity   :=
                            cur_onhand_rec.quantity - l_num_rcv_qty;
                        l_num_rcv_qty   := 0;
                    END IF;

                    IF l_num_rcv_qty = 0 AND j < i
                    THEN
                        j               := j + 1;
                        l_num_rcv_qty   := l_cur_rcv_txns (j).quantity;
                    ELSE
                        INSERT INTO xxdo_inv_onhand_conv_stg (
                                        source_org_id,
                                        source_subinventory,
                                        source_locator_id,
                                        --                            target_org_id,
                                        --                            target_subinventory,
                                        inventory_item_id,
                                        quantity,
                                        uom,
                                        aging_date,
                                        brand,
                                        gender,
                                        product_group,
                                        product_subgroup,
                                        process_status,
                                        item_number,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        request_id,
                                        conv_seq_id,
                                        reserved_quantity,
                                        conv_quantity,
                                        style_name,
                                        color_name,
                                        upc,
                                        description,
                                        item_unit_cost,
                                        source_locator)
                                 VALUES (
                                            p_in_num_src_inv_org_id,
                                            cur_onhand_rec.subinventory_code,
                                            cur_onhand_rec.locator_id,
                                            --                            p_in_num_tar_inv_org_id,
                                            --                            p_in_chr_tar_subinv,
                                            cur_item_rec.inventory_item_id,
                                            cur_onhand_rec.quantity,
                                            cur_onhand_rec.primary_uom_code,
                                            ADD_MONTHS (SYSDATE, -60) - 1,
                                            cur_item_rec.brand,
                                            cur_item_rec.gender,
                                            cur_item_rec.product_group,
                                            cur_item_rec.product_subgroup,
                                            --                            'NEW',
                                            DECODE (
                                                cur_onhand_rec.subinventory_code,
                                                'STAGE', 'IGNORED',
                                                'NEW'),
                                            cur_onhand_rec.item_number,
                                            SYSDATE,
                                            g_num_user_id,
                                            SYSDATE,
                                            g_num_user_id,
                                            g_num_request_id,
                                            xxdo_inv_onhand_conv_stg_s.NEXTVAL,
                                            0,
                                            cur_onhand_rec.quantity,
                                            cur_onhand_rec.style_name,
                                            cur_onhand_rec.color_name,
                                            cur_onhand_rec.upc,
                                            cur_onhand_rec.description,
                                            cur_onhand_rec.item_unit_cost,
                                            cur_onhand_rec.source_locator);

                        COMMIT;
                        cur_onhand_rec.quantity   := 0;
                    END IF;
                END LOOP;
            END LOOP;
        END LOOP;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
            'Updating Target Org ID and Target Subinventory...');


        UPDATE xxdo_inv_onhand_conv_stg stg
           SET (stg.target_org_id, stg.target_subinventory)   =
                   (SELECT mp_target.organization_id, flv.attribute4
                      FROM fnd_lookup_values flv, mtl_parameters mp_target, mtl_parameters mp_src
                     WHERE     flv.lookup_type =
                               'XXDO_INV_OH_CONV_SRC_TAR_MAP'
                           AND flv.language = 'US'
                           AND flv.attribute1 = mp_src.organization_code
                           AND mp_src.organization_id = stg.source_org_id
                           AND flv.attribute2 = stg.source_subinventory
                           AND flv.attribute3 = mp_target.organization_code);

        COMMIT;


        -- Update all the staging quantities as reserved.

        UPDATE xxdo_inv_onhand_conv_stg
           SET reserved_quantity = quantity, conv_quantity = 0
         WHERE source_subinventory = 'STAGE';

        COMMIT;



        fnd_file.put_line (
            fnd_file.LOG,
            'Updating Subinventory level / Hard reservations...');

        l_num_total_reserve_qty   := 0;

        FOR reservation_rec IN cur_hard_reservations
        LOOP
            l_num_total_reserve_qty   := reservation_rec.reserved_qty;

            fnd_file.put_line (
                fnd_file.LOG,
                'Subinventory : ' || reservation_rec.subinventory_code);
            fnd_file.put_line (
                fnd_file.LOG,
                'Inventory Item ID : ' || reservation_rec.inventory_item_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Reserved Qty : ' || l_num_total_reserve_qty);


            FOR stg_record
                IN cur_stg_records (reservation_rec.subinventory_code,
                                    reservation_rec.inventory_item_id)
            LOOP
                IF l_num_total_reserve_qty <> 0
                THEN
                    IF stg_record.quantity >= l_num_total_reserve_qty
                    THEN
                        UPDATE xxdo_inv_onhand_conv_stg
                           SET reserved_quantity = l_num_total_reserve_qty, conv_quantity = quantity - l_num_total_reserve_qty
                         WHERE conv_seq_id = stg_record.conv_seq_id;

                        l_num_total_reserve_qty   := 0;
                        EXIT;
                    ELSE
                        UPDATE xxdo_inv_onhand_conv_stg
                           SET reserved_quantity = quantity, conv_quantity = 0
                         WHERE conv_seq_id = stg_record.conv_seq_id;

                        l_num_total_reserve_qty   :=
                            l_num_total_reserve_qty - stg_record.quantity;
                    END IF;
                END IF;
            END LOOP;                     -- onhand staging table records loop


            IF l_num_total_reserve_qty > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Reservations more than onhand, Inv Id: '
                    || reservation_rec.inventory_item_id);
            END IF;
        END LOOP;                                         -- reservations loop

        COMMIT;


        l_num_total_reserve_qty   := 0;

        FOR reservation_rec IN cur_reservations
        LOOP
            l_num_total_reserve_qty   := reservation_rec.reserved_qty;

            fnd_file.put_line (
                fnd_file.LOG,
                'Inventory Item ID : ' || reservation_rec.inventory_item_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Reserved Qty : ' || l_num_total_reserve_qty);


            FOR subinv_rec IN cur_subinv
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Subinventory : ' || subinv_rec.secondary_inventory_name);

                FOR stg_record
                    IN cur_stg_records (subinv_rec.secondary_inventory_name,
                                        reservation_rec.inventory_item_id)
                LOOP
                    IF   stg_record.quantity
                       - NVL (stg_record.reserved_quantity, 0) >=
                       l_num_total_reserve_qty
                    THEN
                        IF NVL (stg_record.reserved_quantity, 0) = 0
                        THEN                     -- No qty is reserved already
                            UPDATE xxdo_inv_onhand_conv_stg
                               SET reserved_quantity = l_num_total_reserve_qty, conv_quantity = quantity - l_num_total_reserve_qty
                             WHERE conv_seq_id = stg_record.conv_seq_id;
                        ELSE                             -- Partially reserved
                            IF   stg_record.reserved_quantity
                               + l_num_total_reserve_qty =
                               stg_record.quantity
                            THEN              -- Entire Qty has to be reserved
                                UPDATE xxdo_inv_onhand_conv_stg
                                   SET reserved_quantity = stg_record.quantity, conv_quantity = 0
                                 WHERE conv_seq_id = stg_record.conv_seq_id;
                            ELSE          -- There is some qty left to convert
                                UPDATE xxdo_inv_onhand_conv_stg
                                   SET reserved_quantity = reserved_quantity + l_num_total_reserve_qty, conv_quantity = conv_quantity - l_num_total_reserve_qty
                                 WHERE conv_seq_id = stg_record.conv_seq_id;
                            END IF;
                        END IF;

                        l_num_total_reserve_qty   := 0;
                        EXIT;
                    ELSE -- Current record's conv qty is less than reserved qty
                        UPDATE xxdo_inv_onhand_conv_stg
                           SET reserved_quantity = quantity, conv_quantity = 0
                         WHERE conv_seq_id = stg_record.conv_seq_id;

                        l_num_total_reserve_qty   :=
                              l_num_total_reserve_qty
                            - stg_record.quantity
                            + stg_record.reserved_quantity;
                    END IF;
                END LOOP;                 -- onhand staging table records loop

                IF l_num_total_reserve_qty = 0
                THEN
                    EXIT;
                END IF;
            END LOOP;                                     -- Subinventory Loop

            IF l_num_total_reserve_qty > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Reservations more than onhand, Inv Id: '
                    || reservation_rec.inventory_item_id);
            END IF;
        END LOOP;                                         -- reservations loop

        COMMIT;


        fnd_file.put_line (fnd_file.LOG, 'Extract Completed');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error while extracting onhand :' || SQLERRM);
            ROLLBACK;
    END extract_req_oh;



    PROCEDURE onhand_cost_report (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_summary_level IN VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_inv_org_id IN NUMBER, p_in_chr_subinv IN VARCHAR2, p_in_chr_product_group IN VARCHAR2, p_in_chr_prod_subgroup IN VARCHAR2
                                  , p_in_chr_style IN VARCHAR2, p_in_chr_color IN VARCHAR2, p_in_chr_size IN VARCHAR2)
    AS
        l_num_total_reserve_qty   NUMBER;

        CURSOR cur_onhand IS
              SELECT mc.segment1
                         brand,
                     mc.segment2
                         gender,                             --Modified for BT
                     mc.segment3
                         product_group,                      --Modified for BT
                     mc.segment4
                         product_subgroup,
                     REPLACE (ffv_styles.description, CHR (9), '')
                         style_name,
                     ffv_colors.description
                         color_name,
                     DECODE (msi.attribute11,
                             NULL, NULL,
                             '''' || msi.attribute11 || '''')
                         upc,
                     (msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3)
                         sku,
                     msi.description
                         description,
                     msi.primary_uom_code
                         uom,
                     onhand.subinventory_code
                         subinventory,
                     onhand.locator,
                     onhand.onhand_qty,
                     DECODE (
                         subinv.asset_inventory,
                         2, 0,
                         NVL (
                             (SELECT cic.item_cost
                                FROM cst_item_costs cic
                               WHERE     cic.organization_id =
                                         mp_cost.organization_id
                                     AND cic.inventory_item_id =
                                         msi.inventory_item_id
                                     AND cic.cost_type_id =
                                         mp_cost.primary_cost_method),
                             0))
                         item_unit_cost,
                       DECODE (
                           subinv.asset_inventory,
                           2, 0,
                           NVL (
                               (SELECT cic.item_cost
                                  FROM cst_item_costs cic
                                 WHERE     cic.organization_id =
                                           mp_cost.organization_id
                                       AND cic.inventory_item_id =
                                           msi.inventory_item_id
                                       AND cic.cost_type_id =
                                           mp_cost.primary_cost_method),
                               0))
                     * onhand.onhand_qty
                         item_total_cost,
                     mp_cost.organization_id,
                     msi.inventory_item_id,
                     onhand.locator_id
                FROM (  SELECT moh.organization_id, moh.subinventory_code, mil.concatenated_segments locator,
                               moh.locator_id, moh.inventory_item_id, SUM (transaction_quantity) onhand_qty
                          FROM mtl_onhand_quantities moh, mtl_item_locations_kfv mil
                         WHERE     moh.organization_id = p_in_num_inv_org_id
                               AND moh.subinventory_code =
                                   NVL (p_in_chr_subinv, moh.subinventory_code)
                               AND moh.locator_id = mil.inventory_location_id(+)
                               AND moh.organization_id = mil.organization_id(+)
                      --   and moh.subinventory_code <> 'STAGE'
                      --  and moh.inventory_item_id = 3043914
                      GROUP BY moh.organization_id, moh.subinventory_code, mil.concatenated_segments,
                               moh.locator_id, moh.inventory_item_id
                        HAVING SUM (transaction_quantity) > 0) onhand,
                     mtl_system_items_kfv msi,               --Modified for BT
                     mtl_categories_b mc,
                     mtl_item_categories mic,
                     mtl_category_sets mcs,
                     mtl_parameters mp_cost,
                     fnd_flex_values_vl ffv_styles,
                     fnd_flex_value_sets ffvs_styles,
                     fnd_flex_values_vl ffv_colors,
                     fnd_flex_value_sets ffvs_colors,
                     mtl_secondary_inventories subinv,
                     xxd_common_items_v xciv
               WHERE     1 = 1
                     AND msi.organization_id = mic.organization_id
                     AND mic.inventory_item_id = msi.inventory_item_id
                     AND mcs.category_set_id = mic.category_set_id
                     AND mcs.category_set_id = 1
                     --               AND mic.inventory_item_id = msi.inventory_item_id
                     AND mc.category_id = mic.category_id
                     AND msi.inventory_item_id = onhand.inventory_item_id
                     AND msi.organization_id = onhand.organization_id
                     AND onhand.organization_id = mp_cost.organization_id
                     /* AND ffv_styles.flex_value = msi.segment1
                      AND ffv_styles.flex_value_set_id = ffvs_styles.flex_value_set_id
                      AND ffvs_styles.flex_value_set_name = 'DO_STYLES_CAT'
                      AND ffv_colors.flex_value = msi.segment2
                      AND ffv_colors.flex_value_set_id = ffvs_colors.flex_value_set_id
                      AND ffvs_colors.flex_value_set_name = 'DO_COLORS_CAT'*/
                     /*Commented for BT Remediation END*/
                     AND xciv.inventory_item_id = msi.inventory_item_id
                     AND xciv.organization_id = msi.organization_id
                     AND xciv.category_set_id = mcs.category_set_id
                     AND xciv.category_id = mc.category_id
                     AND xciv.style_number =
                         NVL (p_in_chr_style, xciv.style_number)
                     AND xciv.color_code =
                         NVL (p_in_chr_color, xciv.color_code)
                     AND msi.attribute27 = NVL (p_in_chr_size, msi.attribute27)
                     AND mp_cost.organization_id = p_in_num_inv_org_id
                     AND mc.segment1 = NVL (p_in_chr_brand, mc.segment1)
                     AND mc.segment2 = NVL (p_in_chr_gender, mc.segment2)
                     AND mc.segment4 =
                         NVL (p_in_chr_prod_subgroup, mc.segment4)
                     AND mc.segment3 =
                         NVL (p_in_chr_product_group, mc.segment3)
                     /* AND msi.segment1 = NVL (p_in_chr_style, msi.segment1)
                      AND msi.segment2 = NVL (p_in_chr_color, msi.segment2)
                      AND msi.segment3 = NVL (p_in_chr_size, msi.segment3)*/
                     AND onhand.organization_id = subinv.organization_id
                     AND onhand.subinventory_code =
                         subinv.secondary_inventory_name
            ORDER BY msi.inventory_item_id, onhand.subinventory_code;

        CURSOR cur_onhand_no_loc IS
              SELECT mc.segment1
                         brand,
                     mc.segment2
                         gender,
                     mc.segment3
                         product_group,
                     mc.segment4
                         product_subgroup,
                     REPLACE (ffv_styles.description, CHR (9), '')
                         style_name,
                     ffv_colors.description
                         color_name,
                     DECODE (msi.attribute11,
                             NULL, NULL,
                             '''' || msi.attribute11 || '''')
                         upc,
                     (msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3)
                         sku,
                     msi.description
                         description,
                     msi.primary_uom_code
                         uom,
                     onhand.subinventory_code
                         subinventory,
                     NULL
                         locator,
                     onhand.onhand_qty,
                     DECODE (
                         subinv.asset_inventory,
                         2, 0,
                         NVL (
                             (SELECT cic.item_cost
                                FROM cst_item_costs cic
                               WHERE     cic.organization_id =
                                         mp_cost.organization_id
                                     AND cic.inventory_item_id =
                                         msi.inventory_item_id
                                     AND cic.cost_type_id =
                                         mp_cost.primary_cost_method),
                             0))
                         item_unit_cost,
                       DECODE (
                           subinv.asset_inventory,
                           2, 0,
                           NVL (
                               (SELECT cic.item_cost
                                  FROM cst_item_costs cic
                                 WHERE     cic.organization_id =
                                           mp_cost.organization_id
                                       AND cic.inventory_item_id =
                                           msi.inventory_item_id
                                       AND cic.cost_type_id =
                                           mp_cost.primary_cost_method),
                               0))
                     * onhand.onhand_qty
                         item_total_cost,
                     mp_cost.organization_id,
                     msi.inventory_item_id,
                     NULL
                         locator_id
                FROM (  SELECT moh.organization_id, moh.subinventory_code, moh.inventory_item_id,
                               SUM (transaction_quantity) onhand_qty
                          FROM mtl_onhand_quantities moh
                         WHERE     moh.organization_id = p_in_num_inv_org_id
                               AND moh.subinventory_code =
                                   NVL (p_in_chr_subinv, moh.subinventory_code)
                      --   and moh.subinventory_code <> 'STAGE'
                      --  and moh.inventory_item_id = 3043914
                      GROUP BY moh.organization_id, moh.subinventory_code, moh.inventory_item_id
                        HAVING SUM (transaction_quantity) > 0) onhand,
                     mtl_system_items_kfv msi,
                     mtl_categories_b mc,
                     mtl_item_categories mic,
                     mtl_category_sets mcs,
                     mtl_parameters mp_cost,
                     fnd_flex_values_vl ffv_styles,
                     fnd_flex_value_sets ffvs_styles,
                     fnd_flex_values_vl ffv_colors,
                     fnd_flex_value_sets ffvs_colors,
                     mtl_secondary_inventories subinv,
                     xxd_common_items_v xciv
               WHERE     1 = 1
                     AND msi.organization_id = mic.organization_id
                     AND mic.inventory_item_id = msi.inventory_item_id
                     AND mcs.category_set_id = mic.category_set_id
                     AND mcs.category_set_id = 1
                     --               AND mic.inventory_item_id = msi.inventory_item_id
                     AND mc.category_id = mic.category_id
                     AND msi.inventory_item_id = onhand.inventory_item_id
                     AND msi.organization_id = onhand.organization_id
                     AND onhand.organization_id = mp_cost.organization_id
                     /*AND ffv_styles.flex_value = msi.segment1
                     AND ffv_styles.flex_value_set_id = ffvs_styles.flex_value_set_id
                     AND ffvs_styles.flex_value_set_name = 'DO_STYLES_CAT'
                     AND ffv_colors.flex_value = msi.segment2
                     AND ffv_colors.flex_value_set_id = ffvs_colors.flex_value_set_id
                     AND ffvs_colors.flex_value_set_name = 'DO_COLORS_CAT'*/
                     /*Commented for BT Remediation END*/
                     AND xciv.inventory_item_id = msi.inventory_item_id
                     AND xciv.organization_id = msi.organization_id
                     AND xciv.category_set_id = mcs.category_set_id
                     AND xciv.category_id = mc.category_id
                     AND xciv.style_number =
                         NVL (p_in_chr_style, xciv.style_number)
                     AND xciv.color_code =
                         NVL (p_in_chr_color, xciv.color_code)
                     AND msi.attribute27 = NVL (p_in_chr_size, msi.attribute27)
                     AND mp_cost.organization_id = p_in_num_inv_org_id
                     AND mc.segment1 = NVL (p_in_chr_brand, mc.segment1)
                     AND mc.segment3 = NVL (p_in_chr_gender, mc.segment3)
                     AND mc.segment4 =
                         NVL (p_in_chr_prod_subgroup, mc.segment4)
                     AND mc.segment2 =
                         NVL (p_in_chr_product_group, mc.segment2)
                     /* AND msi.segment1 = NVL (p_in_chr_style, msi.segment1)
                      AND msi.segment2 = NVL (p_in_chr_color, msi.segment2)
                      AND msi.segment3 = NVL (p_in_chr_size, msi.segment3)*/
                     AND onhand.organization_id = subinv.organization_id
                     AND onhand.subinventory_code =
                         subinv.secondary_inventory_name
            ORDER BY msi.inventory_item_id, onhand.subinventory_code;

        /*
        CURSOR cur_reservations
                IS
          SELECT organization_id,
                      inventory_item_id,
                      SUM(primary_reservation_quantity) reserved_qty
            FROM mtl_reservations
         WHERE subinventory_Code IS NULL
             AND organization_id = p_in_num_inv_org_id
             AND inventory_item_id IN (  SELECT inventory_item_id
                                                        FROM xxdo_inv_onhand_recon_stg
                                                    )
          GROUP BY organization_id,
                      inventory_item_id;


        CURSOR cur_stg_record( p_chr_subinv IN VARCHAR2, p_num_inventory_item_id IN NUMBER)
                IS
          SELECT stg.rowid, stg.*
            FROM xxdo_inv_onhand_recon_stg stg
          WHERE source_org_id =  p_in_num_inv_org_id
              AND source_subinventory = p_chr_subinv
              AND inventory_item_id = p_num_inventory_item_id
        ORDER BY transaction_date desc;

            CURSOR cur_subinv
                    IS
               SELECT secondary_inventory_name
                  FROM mtl_secondary_inventories
               WHERE organization_id =p_in_num_inv_org_id
                   AND picking_order IS NOT NULL
               ORDER BY picking_order;
        */

        CURSOR cur_stg_records IS
              SELECT *
                FROM xxdo_inv_onhand_recon_stg
               WHERE request_id = g_num_request_id
            ORDER BY inventory_item_id, subinventory;

        TYPE l_onhand_tab_type IS TABLE OF cur_onhand%ROWTYPE
            INDEX BY BINARY_INTEGER;

        TYPE l_onhand_stg_tab_type IS TABLE OF cur_stg_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_onhand_tab              l_onhand_tab_type;
        l_onhand_stg_tab          l_onhand_stg_tab_type;

        l_exe_bulk_fetch_failed   EXCEPTION;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        fnd_file.put_line (fnd_file.LOG,
                           'Truncating the report staging table');

        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXDO_INV_ONHAND_RECON_STG');

        --    select * from XXDO.XXDO_INV_ONHAND_RECON_STG

        fnd_file.put_line (fnd_file.LOG, 'Populating the onhand records');

        IF p_in_chr_summary_level = 'LOCATOR'
        THEN
            OPEN cur_onhand;
        ELSE
            OPEN cur_onhand_no_loc;
        END IF;

        LOOP
            IF l_onhand_tab.EXISTS (1)
            THEN
                l_onhand_tab.DELETE;
            END IF;

            BEGIN
                IF p_in_chr_summary_level = 'LOCATOR'
                THEN
                    FETCH cur_onhand
                        BULK COLLECT INTO l_onhand_tab
                        LIMIT 2000;
                ELSE
                    FETCH cur_onhand_no_loc
                        BULK COLLECT INTO l_onhand_tab
                        LIMIT 2000;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    IF p_in_chr_summary_level = 'LOCATOR'
                    THEN
                        CLOSE cur_onhand;
                    ELSE
                        CLOSE cur_onhand_no_loc;
                    END IF;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Onhand records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_onhand_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'Populating the details record');

            FOR l_num_ind IN 1 .. l_onhand_tab.COUNT
            LOOP
                INSERT INTO xxdo_inv_onhand_recon_stg (brand,
                                                       gender,
                                                       product_group,
                                                       product_subgroup,
                                                       style_name,
                                                       color_name,
                                                       upc,
                                                       sku,
                                                       description,
                                                       uom,
                                                       subinventory,
                                                       Locator,
                                                       Onhand_Qty,
                                                       Item_Unit_Cost,
                                                       Item_Total_Cost,
                                                       organization_id,
                                                       inventory_item_id,
                                                       locator_id,
                                                       creation_date,
                                                       created_by,
                                                       last_update_date,
                                                       last_updated_by,
                                                       request_id)
                     VALUES (l_onhand_tab (l_num_ind).brand, l_onhand_tab (l_num_ind).gender, l_onhand_tab (l_num_ind).product_group, l_onhand_tab (l_num_ind).product_subgroup, l_onhand_tab (l_num_ind).style_name, l_onhand_tab (l_num_ind).color_name, l_onhand_tab (l_num_ind).upc, l_onhand_tab (l_num_ind).sku, l_onhand_tab (l_num_ind).description, l_onhand_tab (l_num_ind).uom, l_onhand_tab (l_num_ind).subinventory, l_onhand_tab (l_num_ind).Locator, l_onhand_tab (l_num_ind).Onhand_Qty, l_onhand_tab (l_num_ind).Item_Unit_Cost, l_onhand_tab (l_num_ind).Item_Total_Cost, l_onhand_tab (l_num_ind).organization_id, l_onhand_tab (l_num_ind).inventory_item_id, l_onhand_tab (l_num_ind).locator_id, SYSDATE, g_num_user_id, SYSDATE
                             , g_num_user_id, g_num_request_id);
            END LOOP;

            COMMIT;
        END LOOP;

        IF p_in_chr_summary_level = 'LOCATOR'
        THEN
            CLOSE cur_onhand;
        ELSE
            CLOSE cur_onhand_no_loc;
        END IF;


        COMMIT;



        --   fnd_file.put_line ( fnd_file.log, 'Updating Subinventory level reservations...' );
        --
        --        UPDATE xxdo_inv_onhand_recon_stg stg
        --           SET (stg.reserved_qty, stg.remarks) =
        --           ( SELECT sum(mr.primary_reservation_quantity), 'Subinventory Reservation'
        --                FROM mtl_reservations mr
        --              WHERE mr.organization_id = stg.organization_id
        --                  AND mr.inventory_item_id = stg.inventory_item_id
        --                  AND mr.subinventory_code = stg.subinventory)
        --      WHERE stg.rowid IN
        --              (
        --              SELECT max(stg_inner.rowid)
        --                FROM mtl_reservations mr,
        --                         xxdo_inv_onhand_recon_stg stg_inner
        --              WHERE mr.organization_id = stg.organization_id
        --                  AND mr.inventory_item_id = stg.inventory_item_id
        --                  AND mr.subinventory_code = stg.subinventory
        --                  AND stg_inner.organization_id = stg.organization_id
        --                  AND stg_inner.subinventory = stg.subinventory
        --                  AND stg_inner.inventory_item_id = stg.inventory_item_id
        --              );
        --
        --
        --   fnd_file.put_line ( fnd_file.log, 'Updating Org level / Soft reservations...' );
        --
        --
        --        UPDATE xxdo_inv_onhand_recon_stg stg
        --           SET (stg.reserved_qty, stg.remarks) =
        --           ( SELECT sum(mr.primary_reservation_quantity), 'Soft Reservation'
        --                FROM mtl_reservations mr
        --              WHERE mr.organization_id = stg.organization_id
        --                  AND mr.inventory_item_id = stg.inventory_item_id
        --                  AND mr.subinventory_code IS NULL )
        --      WHERE stg.rowid IN
        --              (
        --              SELECT max(stg_inner.rowid)
        --                FROM mtl_reservations mr,
        --                         xxdo_inv_onhand_recon_stg stg_inner
        --              WHERE mr.organization_id = stg.organization_id
        --                  AND mr.inventory_item_id = stg.inventory_item_id
        --                  AND mr.subinventory_code IS NULL
        --                  AND stg_inner.organization_id = stg.organization_id
        --                  AND stg_inner.inventory_item_id = stg.inventory_item_id
        --                  AND stg_inner.reserved_qty IS NULL
        ----                  AND stg_inner.subinventory IN ('FLOW')
        --              );


        /*
            l_num_total_reserve_qty := 0;

        FOR reservation_rec IN cur_reservations
        LOOP
        l_num_total_reserve_qty := reservation_rec.reserved_qty;
            FOR subinv_rec IN cur_subinv
            LOOP
                FOR stg_record IN cur_stg_record( subinv_rec.secondary_inventory_name,  reservation_rec.inventory_item_id)
                LOOP

                            IF stg_record.onhand_qty >= l_num_total_reserve_qty THEN

                                UPDATE xxdo_inv_onhand_recon_stg
                                   SET reserved_qty = l_num_total_reserve_qty,
                                       available_qty = onhand_qty - l_num_total_reserve_qty
                                 WHERE rowid = stg_record.rowid;

                                l_num_total_reserve_qty := 0;
                                EXIT;

                            ELSE

                                UPDATE xxdo_inv_onhand_recon_stg
                                   SET reserved_qty = onhand_qty, available_quantity = 0
                                 WHERE rowid = stg_record.rowid;

                                l_num_total_reserve_qty := l_num_total_reserve_qty - stg_record.onhand_qty;

                            END IF;

                END LOOP; -- onhand staging table records loop

                IF l_num_total_reserve_qty = 0 THEN
                    EXIT;
                END IF;

            END LOOP; -- Subinventory Loop

            IF l_num_total_reserve_qty > 0 THEN

                fnd_file.put_line ( fnd_file.log, 'Reservations more than onhand, Inv Id: ' || reservation_rec.inventory_item_id );

            END IF;

        END LOOP; -- reservations loop

        COMMIT;

        */


        fnd_file.put_line (fnd_file.LOG, 'Writing the header record');

        fnd_file.put_line (
            fnd_file.output,
               'Brand'
            || CHR (9)
            || 'Gender'
            || CHR (9)
            || 'Product Group'
            || CHR (9)
            || 'Product Sub Group'
            || CHR (9)
            || 'Style Name'
            || CHR (9)
            || 'Color Name'
            || CHR (9)
            || 'UPC'
            || CHR (9)
            || 'SKU'
            || CHR (9)
            || 'Description'
            || CHR (9)
            || 'UOM'
            || CHR (9)
            || 'Subinventory'
            || CHR (9)
            || 'Locator'
            || CHR (9)
            || 'Onhand Qty'
            || CHR (9)
            || 'Reserved Qty'
            || CHR (9)
            || 'Available Qty'
            || CHR (9)
            || 'Item Unit Cost'
            || CHR (9)
            || 'Item Total Cost'
            || CHR (9)
            || 'Remarks');

        fnd_file.put_line (fnd_file.LOG, 'Writing the details record');


        OPEN cur_stg_records;

        LOOP
            IF l_onhand_stg_tab.EXISTS (1)
            THEN
                l_onhand_stg_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_stg_records
                    BULK COLLECT INTO l_onhand_stg_tab
                    LIMIT 2000;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_stg_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Onhand Staging records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_onhand_stg_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;


            FOR l_num_ind IN 1 .. l_onhand_stg_tab.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.output,
                       l_onhand_stg_tab (l_num_ind).brand
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).gender
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).product_group
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).product_subgroup
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).style_name
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).color_name
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).upc
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).sku
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).description
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).uom
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).subinventory
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).Locator
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).Onhand_Qty
                    || CHR (9)
                    || NULL         --l_onhand_stg_tab(l_num_ind).reserved_qty
                    || CHR (9)
                    --                || to_char(l_onhand_stg_tab(l_num_ind).Onhand_Qty - NVL(l_onhand_stg_tab(l_num_ind).reserved_qty, 0))
                    || NULL                                   -- Available qty
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).Item_Unit_Cost
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).Item_Total_Cost
                    || CHR (9)
                    || l_onhand_stg_tab (l_num_ind).remarks);
            END LOOP;
        END LOOP;

        CLOSE cur_stg_records;
    EXCEPTION
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error while generating report :' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END onhand_cost_report;


    PROCEDURE onhand_cost_report_ext (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_summary_level IN VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_inv_org_id IN NUMBER, p_in_chr_subinv IN VARCHAR2, p_in_chr_product_group IN VARCHAR2, p_in_chr_prod_subgroup IN VARCHAR2
                                      , p_in_chr_style IN VARCHAR2, p_in_chr_color IN VARCHAR2, p_in_chr_size IN VARCHAR2)
    AS
        l_chr_errbuf              VARCHAR2 (2000);
        l_chr_retcode             VARCHAR2 (1);

        CURSOR cur_onhand IS
              SELECT brand, gender, product_group,
                     product_subgroup, style_name, color_name,
                     upc, item_number sku, description,
                     uom, source_subinventory subinventory, source_locator locator,
                     quantity onhand_qty, reserved_quantity reserved_qty, conv_quantity available_qty,
                     NVL (item_unit_cost, 0) item_unit_cost, NVL (item_unit_cost, 0) * quantity item_total_cost
                FROM xxdo_inv_onhand_conv_stg
               WHERE 1 = 1                       --process_Status <> 'IGNORED'
            ORDER BY inventory_item_id, source_subinventory;

        CURSOR cur_onhand_no_loc IS
              SELECT brand, gender, product_group,
                     product_subgroup, style_name, color_name,
                     upc, item_number sku, description,
                     uom, source_subinventory subinventory, NULL locator,
                     SUM (quantity) onhand_qty, SUM (reserved_quantity) reserved_qty, SUM (conv_quantity) available_qty,
                     MIN (NVL (item_unit_cost, 0)) item_unit_cost, MIN (NVL (item_unit_cost, 0)) * SUM (quantity) item_total_cost
                FROM xxdo_inv_onhand_conv_stg
               WHERE 1 = 1                       --process_Status <> 'IGNORED'
            GROUP BY brand, gender, product_group,
                     product_subgroup, style_name, color_name,
                     upc, item_number, description,
                     uom, source_subinventory
            ORDER BY item_number, source_subinventory;

        TYPE l_onhand_tab_type IS TABLE OF cur_onhand%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_onhand_tab              l_onhand_tab_type;

        l_exe_bulk_fetch_failed   EXCEPTION;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';


        IF p_in_chr_summary_level = 'AGING_DATE'
        THEN
            highjump_ext (p_out_chr_errbuf         => l_chr_errbuf,
                          p_out_chr_retcode        => l_chr_retcode,
                          p_in_chr_summary_level   => p_in_chr_summary_level,
                          p_in_chr_brand           => p_in_chr_brand,
                          p_in_chr_gender          => p_in_chr_gender,
                          p_in_num_inv_org_id      => p_in_num_inv_org_id,
                          p_in_chr_subinv          => p_in_chr_subinv,
                          p_in_chr_product_group   => p_in_chr_product_group,
                          p_in_chr_prod_subgroup   => p_in_chr_prod_subgroup,
                          p_in_chr_style           => p_in_chr_style,
                          p_in_chr_color           => p_in_chr_color,
                          p_in_chr_size            => p_in_chr_size);

            p_out_chr_errbuf    := l_chr_errbuf;
            p_out_chr_retcode   := l_chr_retcode;
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Writing the header record');

            fnd_file.put_line (
                fnd_file.output,
                   'Brand'
                || CHR (9)
                || 'Gender'
                || CHR (9)
                || 'Product Group'
                || CHR (9)
                || 'Product Sub Group'
                || CHR (9)
                || 'Style Name'
                || CHR (9)
                || 'Color Name'
                || CHR (9)
                || 'UPC'
                || CHR (9)
                || 'SKU'
                || CHR (9)
                || 'Description'
                || CHR (9)
                || 'UOM'
                || CHR (9)
                || 'Subinventory'
                || CHR (9)
                || 'Locator'
                || CHR (9)
                || 'Onhand Qty'
                || CHR (9)
                || 'Reserved Qty'
                || CHR (9)
                || 'Available Qty'
                || CHR (9)
                || 'Item Unit Cost'
                || CHR (9)
                || 'Item Total Cost'
                || CHR (9)
                || 'Remarks');


            IF p_in_chr_summary_level = 'LOCATOR'
            THEN
                OPEN cur_onhand;
            ELSE
                OPEN cur_onhand_no_loc;
            END IF;

            LOOP
                IF l_onhand_tab.EXISTS (1)
                THEN
                    l_onhand_tab.DELETE;
                END IF;

                BEGIN
                    IF p_in_chr_summary_level = 'LOCATOR'
                    THEN
                        FETCH cur_onhand
                            BULK COLLECT INTO l_onhand_tab
                            LIMIT 2000;
                    ELSE
                        FETCH cur_onhand_no_loc
                            BULK COLLECT INTO l_onhand_tab
                            LIMIT 2000;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        IF p_in_chr_summary_level = 'LOCATOR'
                        THEN
                            CLOSE cur_onhand;
                        ELSE
                            CLOSE cur_onhand_no_loc;
                        END IF;

                        p_out_chr_errbuf   :=
                               'Unexcepted error in BULK Fetch of Onhand records : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RAISE l_exe_bulk_fetch_failed;
                END;                                       --end of bulk fetch

                IF NOT l_onhand_tab.EXISTS (1)
                THEN
                    EXIT;
                END IF;

                fnd_file.put_line (fnd_file.LOG,
                                   'Writing the details record');

                FOR l_num_ind IN 1 .. l_onhand_tab.COUNT
                LOOP
                    fnd_file.put_line (
                        fnd_file.output,
                           l_onhand_tab (l_num_ind).brand
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).gender
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).product_group
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).product_subgroup
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).style_name
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).color_name
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).upc
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).sku
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).description
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).uom
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).subinventory
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).Locator
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).Onhand_Qty
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).reserved_qty
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).available_qty
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).Item_Unit_Cost
                        || CHR (9)
                        || l_onhand_tab (l_num_ind).Item_Total_Cost
                        || CHR (9)
                        || NULL);
                END LOOP;
            END LOOP;

            IF p_in_chr_summary_level = 'LOCATOR'
            THEN
                CLOSE cur_onhand;
            ELSE
                CLOSE cur_onhand_no_loc;
            END IF;
        END IF;
    EXCEPTION
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error while generating report :' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END onhand_cost_report_ext;


    PROCEDURE highjump_ext (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_summary_level IN VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_inv_org_id IN NUMBER, p_in_chr_subinv IN VARCHAR2, p_in_chr_product_group IN VARCHAR2, p_in_chr_prod_subgroup IN VARCHAR2
                            , p_in_chr_style IN VARCHAR2, p_in_chr_color IN VARCHAR2, p_in_chr_size IN VARCHAR2)
    AS
        /*
           CURSOR cur_onhand
                  IS
        select mp.organization_code warehouse,
                stg.item_number item,
                stg.target_subinventory subinventory,
                stg.source_locator locator,
                sum(stg.conv_quantity) quantity,
                stg.uom,
                NULL LPN,
                to_char(trunc(stg.aging_date), 'YYYY-MM-DD HH24:MI:SS') receipt_date
        from xxdo_inv_onhand_conv_stg stg,
               mtl_parameters mp
        where stg.process_status = 'PROCESSED'
           and stg.target_org_id = mp.organization_id
           and mp.organization_id = NVL ( p_in_num_inv_org_id , mp.organization_id)
           and brand = NVL ( p_in_chr_brand, brand)
           and gender = NVL ( p_in_chr_gender, gender)
           and product_group = NVL( p_in_chr_product_group, product_group)
           and product_subgroup = NVL( p_in_chr_prod_subgroup, product_subgroup)
        group by mp.organization_code,
                      stg.item_number,
                    stg.target_subinventory,
                    stg.source_locator,
                    stg.uom,
                    trunc(aging_date)
        ORDER BY stg.item_number,  stg.target_subinventory,trunc(aging_date);
        */

        l_chr_lpn_found           VARCHAR2 (1) := 'N';

        CURSOR cur_onhand IS
              SELECT source_org_id, stg.source_subinventory, stg.source_locator,
                     stg.source_locator_id, target_org_id, mp.organization_code target_org,
                     stg.target_subinventory, stg.item_number, stg.inventory_item_id,
                     s_subinv.lpn_controlled_flag, stg.uom, SUM (stg.conv_quantity) qty,
                     MIN (aging_date) aging_date
                --        stg.uom,
                --        to_char(trunc(stg.aging_date), 'YYYY-MM-DD HH24:MI:SS') receipt_date,
                --        stg.conv_seq_id,
                FROM xxdo_inv_onhand_conv_stg stg, mtl_secondary_inventories s_subinv, mtl_parameters mp
               WHERE     stg.process_status <> 'IGNORED'
                     AND conv_quantity > 0
                     AND stg.source_org_id = s_subinv.organization_id
                     AND stg.source_subinventory =
                         s_subinv.secondary_inventory_name
                     AND stg.source_org_id =
                         NVL (p_in_num_inv_org_id, stg.source_org_id)
                     AND stg.target_org_id = mp.organization_id
                     AND brand = NVL (p_in_chr_brand, brand)
                     AND gender = NVL (p_in_chr_gender, gender)
                     AND product_group =
                         NVL (p_in_chr_product_group, product_group)
                     AND product_subgroup =
                         NVL (p_in_chr_prod_subgroup, product_subgroup)
            GROUP BY source_org_id, stg.source_subinventory, target_org_id,
                     mp.organization_code, stg.target_subinventory, stg.item_number,
                     stg.source_locator, stg.inventory_item_id, stg.source_locator_id,
                     s_subinv.lpn_controlled_flag, stg.uom
            ORDER BY source_subinventory, source_locator, item_number;

        TYPE l_onhand_tab_type IS TABLE OF cur_onhand%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_onhand_tab              l_onhand_tab_type;

        CURSOR cur_lpns (p_num_org_id IN NUMBER, p_chr_subinv IN VARCHAR2, p_num_locator_id IN NUMBER
                         , p_num_inv_item_id IN NUMBER)
        IS
              SELECT lpn.lpn_id, lpn.license_plate_number, SUM (moqd.transaction_quantity) lpn_qty
                FROM mtl_onhand_quantities moq, mtl_onhand_quantities_detail moqd, wms_license_plate_numbers lpn
               WHERE     moq.organization_id = moqd.organization_id
                     AND moq.subinventory_code = moqd.subinventory_code
                     AND NVL (moq.locator_id, -1) = NVL (moqd.locator_id, -1)
                     AND moq.inventory_item_id = moqd.inventory_item_id
                     AND moq.create_transaction_id = moqd.create_transaction_id
                     AND moqd.lpn_id = lpn.lpn_id
                     AND moq.organization_id = p_num_org_id
                     AND moq.subinventory_code = p_chr_subinv
                     AND NVL (moq.locator_id, -1) = NVL (p_num_locator_id, -1)
                     AND moq.inventory_item_id = p_num_inv_item_id
            GROUP BY lpn.lpn_id, lpn.license_plate_number;

        l_exe_bulk_fetch_failed   EXCEPTION;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXDO_INV_HJ_ONHAND_STG');

        /*


            fnd_file.put_line(fnd_file.log, 'Writing the header record');

                       fnd_file.put_line (fnd_file.output,
                                          'Warehouse'
                                          || CHR (9)
                                          || 'Item'
                                          || CHR (9)
                                          || 'Subinventory'
                                          || CHR (9)
                                          || 'Locator'
                                          || CHR (9)
                                          || 'Quantity'
                                          || CHR (9)
                                          || 'UOM'
                                          || CHR (9)
                                          || 'LPN'
                                          || CHR (9)
                                          || 'Receipt Date'
                                         );
        */
        OPEN cur_onhand;

        LOOP
            IF l_onhand_tab.EXISTS (1)
            THEN
                l_onhand_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_onhand BULK COLLECT INTO l_onhand_tab LIMIT 2000;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_onhand;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Onhand records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_onhand_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'Writing the details record');

            FOR l_num_ind IN 1 .. l_onhand_tab.COUNT
            LOOP
                IF l_onhand_tab (l_num_ind).lpn_controlled_flag = 2
                THEN
                    INSERT INTO xxdo_inv_hj_onhand_stg (source_org_id,
                                                        source_subinventory,
                                                        source_locator,
                                                        source_locator_id,
                                                        target_org_id,
                                                        target_org,
                                                        target_subinventory,
                                                        inventory_item_id,
                                                        item_number,
                                                        uom,
                                                        qty,
                                                        aging_date,
                                                        lpn_controlled_flag,
                                                        lpn_id,
                                                        license_plate_number,
                                                        creation_date,
                                                        created_by,
                                                        last_update_date,
                                                        last_updated_by,
                                                        request_id,
                                                        process_status)
                         VALUES (l_onhand_tab (l_num_ind).source_org_id, l_onhand_tab (l_num_ind).source_subinventory, l_onhand_tab (l_num_ind).source_locator, l_onhand_tab (l_num_ind).source_locator_id, l_onhand_tab (l_num_ind).target_org_id, l_onhand_tab (l_num_ind).target_org, l_onhand_tab (l_num_ind).target_subinventory, l_onhand_tab (l_num_ind).inventory_item_id, l_onhand_tab (l_num_ind).item_number, l_onhand_tab (l_num_ind).uom, l_onhand_tab (l_num_ind).qty, l_onhand_tab (l_num_ind).aging_date, l_onhand_tab (l_num_ind).lpn_controlled_flag, NULL, NULL, SYSDATE, g_num_user_id, SYSDATE
                                 , g_num_user_id, g_num_request_id, 'NEW');
                ELSE
                    l_chr_lpn_found   := 'N';

                    FOR lpns_rec
                        IN cur_lpns (
                               l_onhand_tab (l_num_ind).source_org_id,
                               l_onhand_tab (l_num_ind).source_subinventory,
                               l_onhand_tab (l_num_ind).source_locator_id,
                               l_onhand_tab (l_num_ind).inventory_item_id)
                    LOOP
                        l_chr_lpn_found   := 'Y';

                        INSERT INTO xxdo_inv_hj_onhand_stg (
                                        source_org_id,
                                        source_subinventory,
                                        source_locator,
                                        source_locator_id,
                                        target_org_id,
                                        target_org,
                                        target_subinventory,
                                        inventory_item_id,
                                        item_number,
                                        uom,
                                        qty,
                                        aging_date,
                                        lpn_controlled_flag,
                                        lpn_id,
                                        license_plate_number,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        request_id,
                                        process_status)
                                 VALUES (
                                            l_onhand_tab (l_num_ind).source_org_id,
                                            l_onhand_tab (l_num_ind).source_subinventory,
                                            l_onhand_tab (l_num_ind).source_locator,
                                            l_onhand_tab (l_num_ind).source_locator_id,
                                            l_onhand_tab (l_num_ind).target_org_id,
                                            l_onhand_tab (l_num_ind).target_org,
                                            l_onhand_tab (l_num_ind).target_subinventory,
                                            l_onhand_tab (l_num_ind).inventory_item_id,
                                            l_onhand_tab (l_num_ind).item_number,
                                            l_onhand_tab (l_num_ind).uom,
                                            lpns_rec.lpn_qty,
                                            l_onhand_tab (l_num_ind).aging_date,
                                            l_onhand_tab (l_num_ind).lpn_controlled_flag,
                                            lpns_rec.lpn_id,
                                            lpns_rec.license_plate_number,
                                            SYSDATE,
                                            g_num_user_id,
                                            SYSDATE,
                                            g_num_user_id,
                                            g_num_request_id,
                                            'NEW');
                    END LOOP;

                    IF l_chr_lpn_found = 'N'
                    THEN
                        INSERT INTO xxdo_inv_hj_onhand_stg (
                                        source_org_id,
                                        source_subinventory,
                                        source_locator,
                                        source_locator_id,
                                        target_org_id,
                                        target_org,
                                        target_subinventory,
                                        inventory_item_id,
                                        item_number,
                                        uom,
                                        qty,
                                        aging_date,
                                        lpn_controlled_flag,
                                        lpn_id,
                                        license_plate_number,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        request_id,
                                        process_status)
                                 VALUES (
                                            l_onhand_tab (l_num_ind).source_org_id,
                                            l_onhand_tab (l_num_ind).source_subinventory,
                                            l_onhand_tab (l_num_ind).source_locator,
                                            l_onhand_tab (l_num_ind).source_locator_id,
                                            l_onhand_tab (l_num_ind).target_org_id,
                                            l_onhand_tab (l_num_ind).target_org,
                                            l_onhand_tab (l_num_ind).target_subinventory,
                                            l_onhand_tab (l_num_ind).inventory_item_id,
                                            l_onhand_tab (l_num_ind).item_number,
                                            l_onhand_tab (l_num_ind).uom,
                                            l_onhand_tab (l_num_ind).qty,
                                            l_onhand_tab (l_num_ind).aging_date,
                                            l_onhand_tab (l_num_ind).lpn_controlled_flag,
                                            NULL,
                                            NULL,
                                            SYSDATE,
                                            g_num_user_id,
                                            SYSDATE,
                                            g_num_user_id,
                                            g_num_request_id,
                                            'NEW');
                    END IF;
                END IF;
            /*
                  fnd_file.put_line (fnd_file.output,
                            l_onhand_tab(l_num_ind).warehouse
                            || CHR (9)
                            ||l_onhand_tab(l_num_ind).item
                            || CHR (9)
                            ||l_onhand_tab(l_num_ind).subinventory
                            || CHR (9)
                            ||l_onhand_tab(l_num_ind).locator
                            || CHR (9)
                            ||l_onhand_tab(l_num_ind).quantity
                            || CHR (9)
                            ||l_onhand_tab(l_num_ind).uom
                            || CHR (9)
                            ||l_onhand_tab(l_num_ind).lpn
                            || CHR (9)
                            || l_onhand_tab(l_num_ind).receipt_date
                            );
            */

            END LOOP;
        END LOOP;

        CLOSE cur_onhand;

        COMMIT;
    EXCEPTION
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error while generating report :' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END highjump_ext;

    PROCEDURE create_requisitions (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_brand IN VARCHAR2, p_in_chr_gender IN VARCHAR2, p_in_num_src_inv_org_id IN NUMBER, p_in_chr_src_subinv IN VARCHAR2, p_in_num_tar_inv_org_id IN NUMBER, p_in_chr_tar_subinv IN VARCHAR2, p_in_chr_approval_flag IN VARCHAR2
                                   ,                  /* APPROVAL_PARAMETER */
                                     p_in_chr_user IN VARCHAR2) /* USER_PARAMETER */
    AS
        l_num_item_exists          NUMBER := 0;
        l_chr_error_buff           VARCHAR2 (2000);
        l_chr_error_code           VARCHAR2 (30);
        l_chr_return_status        VARCHAR2 (30);

        l_num_person_id            NUMBER;
        l_num_ccid                 NUMBER;
        l_num_del_to_loc_id        NUMBER;
        l_chr_source_code          VARCHAR2 (30);
        l_num_trans_interface_id   NUMBER;
        l_num_org_id               NUMBER;

        -- l_num_person_id          NUMBER; --USER_PARAMETER


        CURSOR cur_inv_subinv IS
            SELECT DISTINCT source_org_id, source_subinventory, target_org_id,
                            target_subinventory, attribute2 batch_id
              FROM xxdo_inv_onhand_conv_stg
             WHERE     process_status = 'NEW'
                   AND brand = NVL (p_in_chr_brand, brand)
                   AND gender = NVL (p_in_chr_gender, gender)
                   AND source_org_id =
                       NVL (p_in_num_src_inv_org_id, source_org_id)
                   AND source_subinventory =
                       NVL (p_in_chr_src_subinv, source_subinventory)
                   AND target_org_id =
                       NVL (p_in_num_tar_inv_org_id, target_org_id)
                   AND target_subinventory =
                       NVL (p_in_chr_tar_subinv, target_subinventory);


        CURSOR cur_onhand (p_num_src_inv_org_id   IN NUMBER,
                           p_chr_src_subinv       IN VARCHAR2,
                           p_num_tar_inv_org_id   IN NUMBER,
                           p_chr_tar_subinv       IN VARCHAR2,
                           p_batch                IN VARCHAR2)
        IS
              SELECT source_org_id, source_subinventory, target_org_id,
                     target_subinventory, inventory_item_id, item_number,
                     uom, TRUNC (aging_date) aging_date, SUM (conv_quantity) conv_quantity,
                     attribute2 batch_id
                FROM xxdo_inv_onhand_conv_stg
               WHERE     process_status = 'NEW'
                     AND brand = NVL (p_in_chr_brand, brand)
                     AND gender = NVL (p_in_chr_gender, gender)
                     AND source_org_id =
                         NVL (p_num_src_inv_org_id, source_org_id)
                     AND source_subinventory =
                         NVL (p_chr_src_subinv, source_subinventory)
                     AND target_org_id =
                         NVL (p_num_tar_inv_org_id, target_org_id)
                     AND target_subinventory =
                         NVL (p_chr_tar_subinv, target_subinventory)
                     AND NVL (attribute2, 'X') =
                         NVL (p_batch, NVL (attribute2, 'X'))
            GROUP BY source_org_id, source_subinventory, target_org_id,
                     target_subinventory, inventory_item_id, item_number,
                     uom, TRUNC (aging_date), attribute2;

        CURSOR cur_items_before_update IS
            SELECT DISTINCT msi.inventory_item_id, msi.ROWID row_id, fixed_lot_multiplier,
                            msi.attribute20
              FROM xxdo_inv_onhand_conv_stg stg, mtl_system_items_kfv msi
             WHERE     stg.process_status = 'INPROCESS'
                   AND stg.source_org_id = msi.organization_id
                   AND stg.inventory_item_id = msi.inventory_item_id
                   AND msi.fixed_lot_multiplier > 1;

        CURSOR cur_items_after_update IS
            SELECT DISTINCT msi.inventory_item_id, msi.ROWID row_id, fixed_lot_multiplier,
                            msi.attribute20
              FROM xxdo_inv_onhand_conv_stg stg, mtl_system_items_kfv msi
             WHERE     stg.process_status = 'INPROCESS'
                   AND stg.source_org_id = msi.organization_id
                   AND stg.inventory_item_id = msi.inventory_item_id
                   AND TO_NUMBER (msi.attribute20) > 1;


        TYPE l_onhand_tab_type IS TABLE OF cur_onhand%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_onhand_tab               l_onhand_tab_type;

        l_req_ids_tab              g_req_ids_tab_type;

        l_exe_bulk_fetch_failed    EXCEPTION;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        fnd_file.put_line (fnd_file.LOG,
                           'Create Requisitions - Process Started...');

        fnd_file.put_line (fnd_file.LOG,
                           'Create Requisitions - Deriving the person id..');

        SELECT employee_id
          INTO l_num_person_id
          FROM fnd_user
         WHERE user_name = p_in_chr_user;   --g_num_user_id;  --USER_PARAMETER


        fnd_file.put_line (
            fnd_file.LOG,
            'Create Requisitions - Updating the records which are not eligible for conversion...');

        -- Updating the records which are not eligible for conversion
        UPDATE xxdo_inv_onhand_conv_stg
           SET error_message = 'Zero or Negative Transaction Qty', process_status = 'ERROR', last_update_date = SYSDATE,
               last_updated_by = g_num_user_id
         WHERE     quantity - NVL (reserved_quantity, 0) <= 0
               AND process_status = 'NEW';



        FOR inv_subinv_rec IN cur_inv_subinv
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                'Create Requisitions - Deriving the Deliver to location id...');

            SELECT location_id
              INTO l_num_del_to_loc_id
              FROM hr_organization_units_v
             WHERE organization_id = inv_subinv_rec.target_org_id;


            SELECT material_account
              INTO l_num_ccid
              FROM mtl_parameters
             WHERE organization_id = inv_subinv_rec.target_org_id;


            l_chr_source_code   := 'HJCONV-' || inv_subinv_rec.batch_id;

            OPEN cur_onhand (inv_subinv_rec.source_org_id,
                             inv_subinv_rec.source_subinventory,
                             inv_subinv_rec.target_org_id,
                             inv_subinv_rec.target_subinventory,
                             inv_subinv_rec.batch_id);

            LOOP
                IF l_onhand_tab.EXISTS (1)
                THEN
                    l_onhand_tab.DELETE;
                END IF;

                BEGIN
                    FETCH cur_onhand
                        BULK COLLECT INTO l_onhand_tab
                        LIMIT 2000;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        CLOSE cur_onhand;

                        p_out_chr_errbuf   :=
                               'Unexcepted error in BULK Fetch of Onhand records : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RAISE l_exe_bulk_fetch_failed;
                END;                                       --end of bulk fetch

                IF NOT l_onhand_tab.EXISTS (1)
                THEN
                    EXIT;
                END IF;


                FOR l_num_ind IN 1 .. l_onhand_tab.COUNT
                LOOP
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Processing the Item : '
                        || l_onhand_tab (l_num_ind).item_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Processing the Item ID : '
                        || l_onhand_tab (l_num_ind).inventory_item_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Source Subinventory : '
                        || l_onhand_tab (l_num_ind).source_subinventory);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Target Subinventory : '
                        || l_onhand_tab (l_num_ind).target_subinventory);

                    l_num_item_exists   := 0;

                    BEGIN
                        SELECT COUNT (1)
                          INTO l_num_item_exists
                          FROM mtl_system_items_kfv msi
                         WHERE     msi.organization_id =
                                   l_onhand_tab (l_num_ind).target_org_id
                               AND msi.inventory_item_id =
                                   l_onhand_tab (l_num_ind).inventory_item_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_num_item_exists   := 0;
                    END;

                    IF l_num_item_exists = 0
                    THEN
                        UPDATE xxdo_inv_onhand_conv_stg
                           SET error_message = 'Item does not exist in the target inventory org', process_status = 'ERROR', last_update_date = SYSDATE,
                               last_updated_by = g_num_user_id
                         WHERE     process_status = 'NEW'
                               AND target_org_id =
                                   l_onhand_tab (l_num_ind).target_org_id
                               AND inventory_item_id =
                                   l_onhand_tab (l_num_ind).inventory_item_id;
                    ELSE
                        /*
                                SELECT variance_ccid
                                    INTO l_num_ccid
                                   FROM mtl_system_items_kfv
                                  WHERE inventory_item_id = l_onhand_tab(l_num_ind).inventory_item_id
                                      AND organization_id = l_onhand_tab(l_num_ind).target_org_id;
                          */

                        /*
                             SELECT po_requisitions_interface_s.nextval
                                             INTO l_num_trans_interface_id
                                      FROM dual;
                        */

                        /* ORG_ID - Start */

                        SELECT operating_unit
                          INTO l_num_org_id
                          FROM apps.org_organization_definitions
                         WHERE organization_id =
                               l_onhand_tab (l_num_ind).source_org_id;

                        /* ORG_ID - End */

                        INSERT INTO po_requisitions_interface_all (
                                        Interface_source_code,
                                        Requisition_type,
                                        Org_id,
                                        Authorization_status,
                                        Charge_account_id,
                                        quantity,
                                        --               secondary_quantity,
                                        uom_code,
                                        group_code,
                                        item_id,
                                        need_by_date,
                                        Preparer_id,
                                        deliver_to_requestor_id,
                                        Source_type_code,
                                        source_organization_id,
                                        source_subinventory,
                                        destination_type_code,
                                        destination_organization_id,
                                        destination_subinventory,
                                        deliver_to_location_id,
                                        --               batch_id
                                        line_attribute3,
                                        --              transaction_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by)
                             VALUES (l_chr_source_code, --'INV', -- interface_source_code
                                                        'INTERNAL', -- Requisition_type
                                                                    --               2,--g_num_org_id , --Org_id of the given operating unit
                                                                    l_num_org_id, /* ORG_ID */
                                                                                  'INCOMPLETE', -- Authorization_Status
                                                                                                l_num_ccid, -- Valid ccid
                                                                                                            l_onhand_tab (l_num_ind).conv_quantity, -- Quantity
                                                                                                                                                    --               1,
                                                                                                                                                    l_onhand_tab (l_num_ind).uom, -- UOm Code
                                                                                                                                                                                  l_chr_source_code, l_onhand_tab (l_num_ind).inventory_item_id, SYSDATE, -- neeed by date
                                                                                                                                                                                                                                                          l_num_person_id, -- Person id of the preparer
                                                                                                                                                                                                                                                                           l_num_person_id, -- Person_id of the requestor
                                                                                                                                                                                                                                                                                            'INVENTORY', -- source_type_code
                                                                                                                                                                                                                                                                                                         l_onhand_tab (l_num_ind).source_org_id, -- Source org id - US4
                                                                                                                                                                                                                                                                                                                                                 l_onhand_tab (l_num_ind).source_subinventory, --- source subinventory
                                                                                                                                                                                                                                                                                                                                                                                               'INVENTORY', -- destination_type_code
                                                                                                                                                                                                                                                                                                                                                                                                            l_onhand_tab (l_num_ind).target_org_id, -- Destination org id - US1
                                                                                                                                                                                                                                                                                                                                                                                                                                                    l_onhand_tab (l_num_ind).target_subinventory, -- destination sub inventory
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  l_num_del_to_loc_id, --                g_num_request_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       TO_CHAR (l_onhand_tab (l_num_ind).aging_date, 'DD-MON-YYYY'), --                 l_num_trans_interface_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     SYSDATE
                                     , g_num_user_id, SYSDATE, g_num_user_id);


                        --        fnd_file.put_line(fnd_file.log,  'Transaction ID : ' || l_num_trans_interface_id);

                        UPDATE xxdo_inv_onhand_conv_stg
                           SET -- transaction_header_id = l_num_trans_interface_id,
                               process_status = 'INPROCESS', last_update_date = SYSDATE, last_updated_by = g_num_user_id
                         WHERE     process_status = 'NEW'
                               AND source_org_id =
                                   l_onhand_tab (l_num_ind).source_org_id
                               AND source_subinventory =
                                   l_onhand_tab (l_num_ind).source_subinventory
                               AND target_org_id =
                                   l_onhand_tab (l_num_ind).target_org_id
                               AND target_subinventory =
                                   l_onhand_tab (l_num_ind).target_subinventory
                               AND inventory_item_id =
                                   l_onhand_tab (l_num_ind).inventory_item_id
                               AND NVL (attribute2, 'X') =
                                   NVL (l_onhand_tab (l_num_ind).batch_id,
                                        NVL (attribute2, 'X'));
                    END IF;
                END LOOP;
            END LOOP;

            CLOSE cur_onhand;

            COMMIT;

            fnd_file.put_line (
                fnd_file.LOG,
                'Create Requisitions - Interface table populated');

            /*

                fnd_file.put_line(fnd_file.log, 'Updating Fixed lot multiplier started...');
                fnd_file.put_line(fnd_file.log, '');
                fnd_file.put_line(fnd_file.log, 'Values before Updating Fixed lot multiplier...');


                    FOR items_before_update_rec IN cur_items_before_update
                    LOOP

                           fnd_file.put_line(fnd_file.log,  'Item Id: ' || items_before_update_rec.inventory_item_id);
                           fnd_file.put_line(fnd_file.log,  'Fixed lot multiplier: ' || items_before_update_rec.fixed_lot_multiplier);
                           fnd_file.put_line(fnd_file.log,  'Attribute20 : ' || items_before_update_rec.attribute20);

                            UPDATE mtl_system_items_kfv
                            SET attribute20 = fixed_lot_multiplier,
                                   fixed_lot_multiplier = NULL
                            WHERE rowid = items_before_update_rec.row_id;
                    END LOOP;

                   COMMIT;
            */

            fnd_file.put_line (
                fnd_file.LOG,
                'Create Requisitions - Launching the Requisition import requests...');


            l_req_ids_tab (l_req_ids_tab.COUNT + 1)   :=
                fnd_request.submit_request (
                    application   => 'PO',           -- application short name
                    program       => 'REQIMPORT',        -- program short name
                    description   => 'Requisition Import',      -- description
                    start_time    => SYSDATE,                    -- start date
                    sub_request   => FALSE,                     -- sub-request
                    argument1     => l_chr_source_code, -- interface source code
                    argument2     => NULL,                         -- Batch Id
                    argument3     => 'ALL',                        -- Group By
                    argument4     => NULL,          -- Last Requisition Number
                    argument5     => NULL,              -- Multi Distributions
                    --                                    argument6 => 'N' -- Initiate Requisition Approval after Requisition Import
                    argument6     => p_in_chr_approval_flag -- Initiate Requisition Approval after Requisition Import    /* APPROVAL_PARAMETER */
                                                           );

            COMMIT;
        END LOOP;


        fnd_file.put_line (
            fnd_file.LOG,
            'Create Requisitions - Waiting for the Requisitions Import requests...');

        wait_for_request (l_req_ids_tab);



        /*
            fnd_file.put_line(fnd_file.log, 'Restoring Fixed lot multiplier started...');
            fnd_file.put_line(fnd_file.log, '');
            fnd_file.put_line(fnd_file.log, 'Values before Restoring Fixed lot multiplier...');


                FOR items_after_update_rec IN cur_items_after_update
                LOOP

                       fnd_file.put_line(fnd_file.log,  'Item Id: ' || items_after_update_rec.inventory_item_id);
                       fnd_file.put_line(fnd_file.log,  'Fixed lot multiplier: ' || items_after_update_rec.fixed_lot_multiplier);
                       fnd_file.put_line(fnd_file.log,  'Attribute20 : ' || items_after_update_rec.attribute20);

                        UPDATE mtl_system_items_kfv
                        SET  fixed_lot_multiplier = to_number(attribute20),
                               attribute20 = NULL
                        WHERE rowid = items_after_update_rec.row_id;

                END LOOP;

                COMMIT;
        */

        fnd_file.put_line (fnd_file.LOG, '');
        fnd_file.put_line (
            fnd_file.LOG,
            'Create Requisitions - Updating the staging table...');

        UPDATE xxdo_inv_onhand_conv_stg stg
           SET (stg.error_message, stg.process_status, stg.last_updated_by,
                stg.last_update_date)   =
                   (SELECT REPLACE (pie.error_message, CHR (10), ';'), 'ERROR', g_num_user_id,
                           SYSDATE
                      FROM po_interface_errors pie, po_requisitions_interface_all pri
                     WHERE     pie.interface_transaction_id =
                               pri.transaction_id
                           AND pri.process_flag = 'ERROR'
                           --                             AND pri.transaction_id = stg.transaction_header_id
                           AND pri.item_id = stg.inventory_item_id
                           AND pri.source_organization_id = stg.source_org_id
                           AND pri.source_subinventory =
                               stg.source_subinventory
                           AND pri.destination_organization_id =
                               stg.target_org_id
                           AND pri.destination_subinventory =
                               stg.target_subinventory
                           AND pri.Interface_source_code =
                               'HJCONV-' || stg.attribute2
                           AND pie.interface_type = 'REQIMPORT'
                           AND ROWNUM < 2)
         WHERE     stg.process_status = 'INPROCESS'
               AND EXISTS
                       (SELECT 1
                          FROM po_interface_errors pie, po_requisitions_interface_all pri
                         WHERE     pie.interface_transaction_id =
                                   pri.transaction_id
                               AND pri.process_flag = 'ERROR'
                               AND pie.interface_type = 'REQIMPORT'
                               --AND pri.transaction_id =  stg.transaction_header_id
                               AND pri.item_id = stg.inventory_item_id
                               AND pri.source_organization_id =
                                   stg.source_org_id
                               AND pri.source_subinventory =
                                   stg.source_subinventory
                               AND pri.destination_organization_id =
                                   stg.target_org_id
                               AND pri.destination_subinventory =
                                   stg.target_subinventory
                               AND pri.Interface_source_code =
                                   'HJCONV-' || stg.attribute2);

        UPDATE xxdo_inv_onhand_conv_stg stg
           SET process_status = 'PROCESSED', last_update_date = SYSDATE, last_updated_by = g_num_user_id
         WHERE process_status = 'INPROCESS';

        COMMIT;

        fnd_file.put_line (fnd_file.LOG,
                           'Create Requisitions - Process Ended');
    EXCEPTION
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error while creating requisitions :' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            ROLLBACK;
    END create_requisitions;

    /*
    ***********************************************************************************
     Procedure/Function Name  :  wait_for_request
     Description              :  This procedure waits for the child concurrent programs
                                 that are spawned by current program
    **********************************************************************************
    */
    PROCEDURE wait_for_request (p_in_req_ids_tab IN g_req_ids_tab_type)
    AS
        ln_count                NUMBER := 0;
        ln_num_intvl            NUMBER := 5;
        ln_data_set_id          NUMBER := NULL;
        ln_num_max_wait         NUMBER := 120000;
        lv_chr_phase            VARCHAR2 (250) := NULL;
        lv_chr_status           VARCHAR2 (250) := NULL;
        lv_chr_dev_phase        VARCHAR2 (250) := NULL;
        lv_chr_dev_status       VARCHAR2 (250) := NULL;
        lv_chr_msg              VARCHAR2 (250) := NULL;
        lb_bol_request_status   BOOLEAN;
    ---------------
    --Begin Block--
    ---------------
    BEGIN
        ------------------------------------------------------
        --Loop for each child request to wait for completion--
        ------------------------------------------------------
        FOR l_num_index IN 1 .. p_in_req_ids_tab.COUNT
        LOOP
            --Wait for request to complete
            lb_bol_request_status   :=
                fnd_concurrent.wait_for_request (
                    p_in_req_ids_tab (l_num_index),
                    ln_num_intvl,
                    ln_num_max_wait,
                    lv_chr_phase,                             -- out parameter
                    lv_chr_status,                            -- out parameter
                    lv_chr_dev_phase,
                    -- out parameter
                    lv_chr_dev_status,
                    -- out parameter
                    lv_chr_msg                                -- out parameter
                              );

            IF    UPPER (lv_chr_dev_status) = 'WARNING'
               OR UPPER (lv_chr_dev_status) = 'ERROR'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in submitting the request, request_id = '
                    || p_in_req_ids_tab (l_num_index));
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_phase =' || lv_chr_phase);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_status =' || lv_chr_status);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error,lv_chr_dev_status =' || lv_chr_dev_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_msg =' || lv_chr_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, 'Request completed ');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'request_id = ' || p_in_req_ids_tab (l_num_index));
                fnd_file.put_line (fnd_file.LOG,
                                   'lv_chr_msg =' || lv_chr_msg);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error:' || SQLERRM);
    END wait_for_request;
END xxdo_inv_onhand_conv_pkg;
/
