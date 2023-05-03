--
-- XXD_INV_GIVR_SNAP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_INV_GIVR_SNAP_PKG"
AS
    /***********************************************************************************
      *$header     :                                                                   *
      *                                                                                *
      * AUTHORS    :  Srinath Siricilla                                                *
      *                                                                                *
      * PURPOSE    :  GIVR Capture Cost Snapshot - Deckers                             *
      *                                                                                *
      * PARAMETERS :                                                                   *
      *                                                                                *
      * DATE       :  15-JUL-2020                                                      *
      *                                                                                *
      * Assumptions:                                                                   *
      *                                                                                *
      *                                                                                *
      * History                                                                        *
      * Vsn     Change Date  Changed By            Change Description                  *
      * -----   -----------  ------------------    ------------------------------------*
      * 1.0     15-JUL-2020  Srinath Siricilla     Initial Creation CCR0008682         *
   * 1.1     29-DEC-2020  Showkath Ali          CCR0008986                          *
      * 1.2     2-Jul-2021   Tejaswi                                                   *
   * 1.3     17-SEP-2021  Showkath Ali          CCR0009608                          *
      *********************************************************************************/

    gn_created_by   NUMBER := fnd_global.user_id;
    gn_request_id   NUMBER := fnd_global.conc_request_id;                --1.1
    gd_date         DATE := TRUNC (SYSDATE);

    PROCEDURE load_cst_view_tbl_prc (p_region            IN VARCHAR2,
                                     p_organization_id   IN NUMBER)
    IS                                                                   --1.2
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start Inserting data into xxd_cst_item_cost_details_t with Timestamp '
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));

        INSERT INTO xxdo.xxd_cst_item_cost_details_t (
                        row_id,
                        inventory_item_id,
                        organization_id,
                        cost_type_id,
                        last_update_date,
                        last_updated_by,
                        creation_date,
                        created_by,
                        last_update_login,
                        operation_sequence_id,
                        operation_seq_num,
                        department_id,
                        level_type,
                        level_type_dsp,
                        activity_id,
                        activity,
                        resource_seq_num,
                        resource_id,
                        resource_code,
                        unit_of_measure,
                        resource_rate,
                        item_units,
                        activity_units,
                        usage_rate_or_amount,
                        basis_type,
                        basis_type_dsp,
                        basis_resource_id,
                        basis_factor,
                        net_yield_or_shrinkage_factor,
                        item_cost,
                        cost_element_id,
                        cost_element,
                        source_type,
                        rollup_source_type,
                        activity_context,
                        request_id,
                        program_application_id,
                        program_id,
                        program_update_date,
                        attribute_category,
                        attribute1,
                        attribute2,
                        attribute3,
                        attribute4,
                        attribute5,
                        attribute6,
                        attribute7,
                        attribute8,
                        attribute9,
                        attribute10,
                        attribute11,
                        attribute12,
                        attribute13,
                        attribute14,
                        attribute15,
                        yielded_cost)
            (SELECT *
               FROM cst_item_cost_details_v t
              --1.1 changes start
              WHERE     1 = 1
                    -- cost_type_id IN (
                    --    2,
                    --    1000
                    --)
                    AND EXISTS
                            (SELECT 1
                               FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl, -- apps.org_organization_definitions   ood --1.2
                                                                                                apps.mtl_parameters ood --1.2
                              WHERE     fvs.flex_value_set_id =
                                        ffvl.flex_value_set_id
                                    AND fvs.flex_value_set_name LIKE
                                            'XXD_GIVR_COST_SNPS_ORG'
                                    AND NVL (TRUNC (ffvl.start_date_active),
                                             TRUNC (SYSDATE)) <=
                                        TRUNC (SYSDATE)
                                    AND NVL (TRUNC (ffvl.end_date_active),
                                             TRUNC (SYSDATE)) >=
                                        TRUNC (SYSDATE)
                                    AND ffvl.enabled_flag = 'Y'
                                    AND ood.organization_code =
                                        ffvl.flex_value
                                    AND ood.organization_id =
                                        t.organization_id
                                    AND ffvl.description =
                                        NVL (p_region, ffvl.description) -- 1.2
                                    AND ood.organization_id =
                                        NVL (p_organization_id,
                                             ood.organization_id)        --1.2
                                                                 ));

        --1.1 changes end

        COMMIT;
        fnd_file.put_line (
            fnd_file.LOG,
               'End of Inserting data into xxd_cst_item_cost_details_t with Timestamp '
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));
        -- Gather statistics to improve the performance.

        fnd_stats.gather_table_stats (ownname => 'XXDO', tabname => 'XXD_CST_ITEM_COST_DETAILS_T', degree => 4
                                      , cascade => TRUE);

        fnd_file.put_line (
            fnd_file.LOG,
               'Gather statistics executed on table XXD_CST_ITEM_COST_DETAILS_T on:'
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));

        fnd_stats.gather_table_stats (ownname => 'BOM', tabname => 'CST_ITEM_COST_DETAILS', degree => 4
                                      , cascade => TRUE);

        fnd_file.put_line (
            fnd_file.LOG,
               'Gather statistics executed on table cst_item_cost_details on:'
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));

        fnd_stats.gather_table_stats (ownname => 'BOM', tabname => 'CST_ITEM_COSTS', degree => 4
                                      , cascade => TRUE);

        fnd_file.put_line (
            fnd_file.LOG,
               'Gather statistics executed on table CST_ITEM_COSTS on:'
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));
    END load_cst_view_tbl_prc;

    PROCEDURE load_cst_mmt_tbl_prc (p_date IN DATE)
    IS
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of Inserting data into xxd_cst_mmt_t with Timestamp '
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));

        INSERT INTO xxdo.xxd_cst_mmt_t
            (  SELECT MAX (mmt.transaction_id) transaction_id, MAX (mmt.transaction_date) transaction_date, mmt.inventory_item_id,
                      mmt.organization_id
                 FROM apps.mtl_material_transactions mmt
                WHERE     1 = 1
                      AND mmt.transaction_date <= NVL (p_date, SYSDATE)
                      AND EXISTS
                              (SELECT 1
                                 FROM xxdo.xxd_cst_item_cost_details_t xxd_cst
                                WHERE     1 = 1
                                      AND xxd_cst.inventory_item_id =
                                          mmt.inventory_item_id
                                      AND xxd_cst.organization_id =
                                          mmt.organization_id)
             GROUP BY mmt.inventory_item_id, mmt.organization_id);

        COMMIT;
        fnd_file.put_line (
            fnd_file.LOG,
               'End of Inserting data into xxd_cst_mmt_t with Timestamp '
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));
    END load_cst_mmt_tbl_prc;

    PROCEDURE upd_cst_mmt_tbl_prc
    IS
        v_cur_recs_counter   NUMBER := 0; -- To count total number of records in the cursor
        v_sql_rowcount       NUMBER := 0; -- To count total number of actual rows updated
        v_bulk_limit         NUMBER := 5000;      -- To limit the bulk collect

        --Define a cursor with values from the test table
        CURSOR c_rec IS
              SELECT inventory_item_id, organization_id, transaction_id,
                     transaction_date
                FROM xxdo.xxd_cst_mmt_t
            GROUP BY inventory_item_id, organization_id, transaction_id,
                     transaction_date;

        --Create a table type on the cursor

        TYPE tb_rec IS TABLE OF c_rec%ROWTYPE;

        --Define a variable of that table type
        v_tb_rec             tb_rec;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'Start of Updating Tran. Date and ID into xxd_cst_item_cost_details_t with Timestamp '
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));

        -- Open cursor

        OPEN c_rec;

        LOOP
            -- Fetch records from the cursor by v_bulk_limit records at a time.
            -- "LIMIT v_bulk_limit" condition is optional, but good to have.
            FETCH c_rec BULK COLLECT INTO v_tb_rec LIMIT v_bulk_limit;

            --Run a forall update loop to update the first v_bulk_limit records
            FORALL i IN 1 .. v_tb_rec.COUNT
                UPDATE xxdo.xxd_cst_item_cost_details_t t2
                   SET t2.transaction_id = v_tb_rec (i).transaction_id, t2.transaction_date = v_tb_rec (i).transaction_date, t2.snap_created_by = gn_created_by,
                       t2.snapshot_date = gd_date
                 WHERE     t2.inventory_item_id =
                           v_tb_rec (i).inventory_item_id
                       AND t2.organization_id = v_tb_rec (i).organization_id --Just a logic to filter out some records
                                                                            ;

            -- Count number of actual rows updated

            v_sql_rowcount       := v_sql_rowcount + SQL%ROWCOUNT;
            -- Count number of loop cycles
            v_cur_recs_counter   := v_cur_recs_counter + v_tb_rec.COUNT;
            -- This commit will occur every v_bulk_limit records, since that is the bulk collect limit
            -- This will also happen at the last iteration of Fetch which might be less than v_bulk_limit
            COMMIT;
            EXIT WHEN c_rec%NOTFOUND;
        END LOOP;

        CLOSE c_rec;

        fnd_file.put_line (
            fnd_file.LOG,
               'End of Updating Tran. Date and ID into xxd_cst_item_cost_details_t with Timestamp '
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));

        -- Display total number of loop cycles

        fnd_file.put_line (fnd_file.LOG,
                           'Total loop count: ' || v_cur_recs_counter);
        -- Display number of actual rows updated
        fnd_file.put_line (fnd_file.LOG,
                           'Actual rows updated: ' || v_sql_rowcount);
    END upd_cst_mmt_tbl_prc;

    PROCEDURE ins_cst_hist_dtls_tbl_prc (p_date IN DATE)
    IS
        v_cur_recs_counter   NUMBER := 0; -- To count total number of records in the cursor
        v_sql_rowcount       NUMBER := 0; -- To count total number of actual rows updated
        v_bulk_limit         NUMBER := 5000;      -- To limit the bulk collect

        --Define a cursor with values from the test table
        CURSOR c_rec IS
            SELECT /*+parallel(8) optimizer_features_enable('11.2.0.4')*/
                   --Added optimizer hint for change 1.2, previous it was only parallel(8)
                   new_material, new_material_overhead, transaction_id,
                   transaction_costed_date, transaction_date, organization_id,
                   inventory_item_id
              FROM cst_cg_cost_history_v cg
             WHERE     1 = 1
                   AND transaction_date <= NVL (p_date, SYSDATE)
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_cst_item_cost_details_t xxd
                             WHERE     1 = 1
                                   --AND xxd.transaction_id = cg.transaction_id
                                   AND xxd.inventory_item_id =
                                       cg.inventory_item_id
                                   AND xxd.organization_id =
                                       cg.organization_id);

        --Create a table type on the cursor

        TYPE tb_rec IS TABLE OF c_rec%ROWTYPE;

        --Define a variable of that table type
        v_tb_rec             tb_rec;
    BEGIN
        -- Open cursor
        OPEN c_rec;

        fnd_file.put_line (
            fnd_file.LOG,
               'Start of Inserting data into xxd_actual_cost_hist_details_t with Timestamp '
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));

        LOOP
            -- Fetch records from the cursor by v_bulk_limit records at a time.
            -- "LIMIT v_bulk_limit" condition is optional, but good to have.
            FETCH c_rec BULK COLLECT INTO v_tb_rec LIMIT v_bulk_limit;

            --Run a forall update loop to update the first v_bulk_limit records
            FORALL i IN 1 .. v_tb_rec.COUNT
                INSERT INTO xxdo.xxd_actual_cost_hist_details_t
                         VALUES (v_tb_rec (i).new_material,
                                 v_tb_rec (i).new_material_overhead,
                                 v_tb_rec (i).transaction_id,
                                 v_tb_rec (i).transaction_costed_date,
                                 v_tb_rec (i).transaction_date,
                                 v_tb_rec (i).organization_id,
                                 v_tb_rec (i).inventory_item_id,
                                 gn_created_by,
                                 gd_date);

            -- Count number of actual rows updated

            v_sql_rowcount       := v_sql_rowcount + SQL%ROWCOUNT;
            -- Count number of loop cycles
            v_cur_recs_counter   := v_cur_recs_counter + v_tb_rec.COUNT;
            -- This commit will occur every v_bulk_limit records, since that is the bulk collect limit
            -- This will also happen at the last iteration of Fetch which might be less than v_bulk_limit
            COMMIT;
            EXIT WHEN c_rec%NOTFOUND;
        END LOOP;

        CLOSE c_rec;

        -- Gathering the stats to improve the pwerformance -- 1.2
        fnd_stats.gather_table_stats (ownname => 'XXDO', tabname => 'XXD_ACTUAL_COST_HIST_DETAILS_T', degree => 4
                                      , cascade => TRUE);

        fnd_file.put_line (
            fnd_file.LOG,
               'End of Inserting data into xxd_actual_cost_hist_details_t with Timestamp '
            || TO_CHAR (SYSDATE, 'DD-MON-RR HH24:MI:SSSSS'));

        -- Display total number of loop cycles

        fnd_file.put_line (fnd_file.LOG,
                           'Total loop count: ' || v_cur_recs_counter);
        -- Display number of actual rows updated
        fnd_file.put_line (fnd_file.LOG,
                           'Actual rows inserted: ' || v_sql_rowcount);
    END ins_cst_hist_dtls_tbl_prc;

    --1.1 changes start
    FUNCTION get_item_elements_fnc (pn_inventory_item_id IN NUMBER, pn_organization_id IN NUMBER, P_type IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_itemcost   NUMBER;
    BEGIN
        IF p_type = 'freightbasis'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT bmr.default_basis_type
                  INTO ln_itemcost
                  FROM apps.bom_resources bmr
                 WHERE     bmr.organization_id = pn_organization_id
                       AND UPPER (bmr.resource_code) = 'FREIGHT';

                RETURN ln_itemcost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF p_type = 'fifodutyold'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT ROUND ((CV.usage_rate_or_amount / (cv1.usage_rate_or_amount + CV.usage_rate_or_amount)) * cic.material_overhead_cost, 2)
                  INTO ln_itemcost
                  FROM apps.cst_item_cost_details CV, apps.cst_item_costs cic, apps.bom_resources bmr,
                       apps.cst_item_cost_details cv1, apps.bom_resources bmr1
                 WHERE     pn_organization_id = CV.organization_id
                       AND pn_inventory_item_id = CV.inventory_item_id
                       AND CV.cost_type_id = 1020
                       AND CV.resource_id = bmr.resource_id
                       AND bmr.organization_id = CV.organization_id
                       AND UPPER (bmr.resource_code) = 'DUTY'
                       --
                       AND pn_organization_id = cv1.organization_id
                       AND pn_inventory_item_id = cv1.inventory_item_id
                       AND cv1.cost_type_id = 1020
                       AND cv1.resource_id = bmr1.resource_id
                       AND bmr1.organization_id = cv1.organization_id
                       AND UPPER (bmr1.resource_code) = 'FREIGHT'
                       --
                       AND cic.organization_id = pn_organization_id
                       AND cic.inventory_item_id = pn_inventory_item_id
                       AND cic.cost_type_id = 5;

                RETURN ln_itemcost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF p_type = 'ln_fifofreightold'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT ROUND ((CV.usage_rate_or_amount / (cv1.usage_rate_or_amount + CV.usage_rate_or_amount)) * cic.material_overhead_cost, 2)
                  INTO ln_itemcost
                  FROM apps.cst_item_cost_details CV, apps.cst_item_costs cic, apps.bom_resources bmr,
                       apps.cst_item_cost_details cv1, apps.bom_resources bmr1
                 WHERE     pn_organization_id = CV.organization_id
                       AND pn_inventory_item_id = CV.inventory_item_id
                       AND CV.cost_type_id = 1020
                       AND CV.resource_id = bmr.resource_id
                       AND bmr.organization_id = CV.organization_id
                       AND UPPER (bmr.resource_code) = 'FREIGHT'
                       AND bmr.default_basis_type = 5
                       --
                       AND pn_organization_id = cv1.organization_id
                       AND pn_inventory_item_id = cv1.inventory_item_id
                       AND cv1.cost_type_id = 1020
                       AND cv1.resource_id = bmr1.resource_id
                       AND bmr1.organization_id = cv1.organization_id
                       AND UPPER (bmr1.resource_code) = 'DUTY'
                       AND bmr.default_basis_type = 5
                       --
                       AND cic.organization_id = pn_organization_id
                       AND cic.inventory_item_id = pn_inventory_item_id
                       AND cic.cost_type_id = 5;

                RETURN ln_itemcost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF p_type = 'freight_duty_factor'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT CASE
                           WHEN COUNT (1) > 0 THEN 1
                           ELSE NULL
                       END frieghtdu_factor
                  INTO ln_itemcost
                  FROM xxdo.xxd_cst_item_cost_details_t
                 WHERE     cost_element = 'Material Overhead'
                       AND inventory_item_id = pn_inventory_item_id
                       AND organization_id = pn_organization_id
                       AND basis_type_dsp = 'Total Value'
                       AND resource_code = 'FREIGHT DU';

                RETURN ln_itemcost;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_itemcost   := NULL;
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        ELSIF p_type = 'freight_du_rate'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT cicd.usage_rate_or_amount frieght_du_rate
                  INTO ln_itemcost
                  FROM cst_item_cost_type_v cict, xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1,
                       cst_cost_types cct1, cst_cost_types cct2
                 WHERE     cict.cost_type_id = cicd.cost_type_id
                       AND cict.inventory_item_id = cicd.inventory_item_id
                       AND cict.organization_id = cicd.organization_id
                       AND cicd1.cost_type_id = cct1.cost_type_id
                       AND cct1.cost_type = 'Average'
                       AND cicd.cost_type_id = cct2.cost_type_id
                       AND cct2.cost_type = 'AvgRates'
                       AND cicd1.cost_element = 'Material'
                       AND cicd1.inventory_item_id = cicd.inventory_item_id
                       AND cicd1.organization_id = cicd.organization_id
                       AND cict.inventory_item_id = pn_inventory_item_id
                       AND cict.organization_id = pn_organization_id
                       AND cicd.basis_type_dsp = 'Total Value'
                       AND cicd.resource_code = 'FREIGHT DU';

                RETURN ln_itemcost;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_itemcost   := NULL;
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        ELSIF p_type = 'custom_material_cost'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT cicd1.item_cost
                  INTO ln_itemcost
                  FROM cst_item_cost_type_v cict, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1
                 WHERE     1 = 1
                       AND cicd1.cost_type_id = cct1.cost_type_id
                       AND cct1.cost_type = 'Average'
                       AND cict.cost_type_id = cct1.cost_type_id
                       AND cicd1.cost_element = 'Material'
                       AND cicd1.inventory_item_id = cict.inventory_item_id
                       AND cicd1.organization_id = cict.organization_id
                       AND cict.inventory_item_id = pn_inventory_item_id
                       AND cict.organization_id = pn_organization_id;

                RETURN ln_itemcost;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_itemcost   := 0;
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF p_type = 'ln_freight_du'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT CASE
                           WHEN cicd.basis_type_dsp = 'Total Value'
                           THEN
                               ROUND (
                                   NVL (
                                       cicd1.item_cost * cicd.usage_rate_or_amount,
                                       0),
                                   5)
                           ELSE
                               cicd.usage_rate_or_amount
                       END frieght_du
                  INTO ln_itemcost
                  FROM cst_item_cost_type_v cict, xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1,
                       cst_cost_types cct1, cst_cost_types cct2
                 WHERE     cict.cost_type_id = cicd.cost_type_id
                       AND cict.inventory_item_id = cicd.inventory_item_id
                       AND cict.organization_id = cicd.organization_id
                       AND cicd1.cost_type_id = cct1.cost_type_id
                       AND cct1.cost_type = 'Average'
                       AND cicd.cost_type_id = cct2.cost_type_id
                       AND cct2.cost_type = 'AvgRates'
                       AND cicd1.cost_element = 'Material'
                       AND cicd1.inventory_item_id = cicd.inventory_item_id
                       AND cicd1.organization_id = cicd.organization_id
                       AND cict.inventory_item_id = pn_inventory_item_id
                       AND cict.organization_id = pn_organization_id
                       AND cicd.resource_code = 'FREIGHT DU';

                RETURN ln_itemcost;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_itemcost   := 0;
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF p_type = 'oh_duty_factor'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT CASE
                           WHEN COUNT (1) > 0 THEN 1
                           ELSE NULL
                       END ohduty_factor
                  INTO ln_itemcost
                  FROM xxdo.xxd_cst_item_cost_details_t
                 WHERE     cost_element = 'Material Overhead'
                       AND inventory_item_id = pn_inventory_item_id
                       AND organization_id = pn_organization_id
                       AND basis_type_dsp = 'Total Value'
                       AND resource_code = 'OH DUTY';

                RETURN ln_itemcost;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_itemcost   := NULL;
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        ELSIF p_type = 'ln_oh_duty_rate'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT cicd.usage_rate_or_amount ohduty_rate
                  INTO ln_itemcost
                  FROM cst_item_cost_type_v cict, xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1,
                       cst_cost_types cct1, cst_cost_types cct2
                 WHERE     cict.cost_type_id = cicd.cost_type_id
                       AND cict.inventory_item_id = cicd.inventory_item_id
                       AND cict.organization_id = cicd.organization_id
                       AND cicd1.cost_type_id = cct1.cost_type_id
                       AND cct1.cost_type = 'Average'
                       AND cicd.cost_type_id = cct2.cost_type_id
                       AND cct2.cost_type = 'AvgRates'
                       AND cicd1.cost_element = 'Material'
                       AND cicd1.inventory_item_id = cicd.inventory_item_id
                       AND cicd1.organization_id = cicd.organization_id
                       AND cict.inventory_item_id = pn_inventory_item_id
                       AND cict.organization_id = pn_organization_id
                       AND cicd.basis_type_dsp = 'Total Value'
                       AND cicd.resource_code = 'OH DUTY';

                RETURN ln_itemcost;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_itemcost   := NULL;
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        ELSIF p_type = 'ln_oh_duty'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT CASE
                           WHEN cicd.basis_type_dsp = 'Total Value'
                           THEN
                               ROUND (
                                   NVL (
                                       cicd1.item_cost * cicd.usage_rate_or_amount,
                                       0),
                                   5)
                           ELSE
                               cicd.usage_rate_or_amount
                       END ohduty
                  INTO ln_itemcost
                  FROM cst_item_cost_type_v cict, xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1,
                       cst_cost_types cct1, cst_cost_types cct2
                 WHERE     cict.cost_type_id = cicd.cost_type_id
                       AND cict.inventory_item_id = cicd.inventory_item_id
                       AND cict.organization_id = cicd.organization_id
                       AND cicd1.cost_type_id = cct1.cost_type_id
                       AND cct1.cost_type = 'Average'
                       AND cicd.cost_type_id = cct2.cost_type_id
                       AND cct2.cost_type = 'AvgRates'
                       AND cicd1.cost_element = 'Material'
                       AND cicd1.inventory_item_id = cicd.inventory_item_id
                       AND cicd1.organization_id = cicd.organization_id
                       AND cict.inventory_item_id = pn_inventory_item_id
                       AND cict.organization_id = pn_organization_id
                       AND cicd.resource_code = 'OH DUTY';

                RETURN ln_itemcost;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_itemcost   := 0;
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        ELSIF p_type = 'dutybasis'
        THEN
            BEGIN
                ln_itemcost   := NULL;

                SELECT bmr.default_basis_type
                  INTO ln_itemcost
                  FROM apps.bom_resources bmr
                 WHERE     bmr.organization_id = pn_organization_id
                       AND UPPER (bmr.resource_code) = 'DUTY';

                RETURN ln_itemcost;
            EXCEPTION
                WHEN OTHERS
                THEN
                    RETURN 0;
            END;
        END IF;
    END get_item_elements_fnc;

    PROCEDURE xxd_load_givr_table_data_prc (p_date            IN DATE,
                                            p_snapshot_date   IN DATE    --1.1
                                                                     )
    IS
        CURSOR get_items_to_insert IS
            SELECT (SELECT NVL (new_material_overhead, 0)
                      FROM xxdo.xxd_actual_cost_hist_details_t
                     WHERE     transaction_id =
                               (SELECT MAX (cst2.transaction_id)
                                  FROM xxdo.xxd_actual_cost_hist_details_t cst2
                                 WHERE     1 = 1
                                       AND cst2.organization_id =
                                           i.organization_id
                                       AND cst2.inventory_item_id =
                                           i.inventory_item_id
                                       AND (cst2.transaction_costed_date) =
                                           (SELECT MAX (cst1.transaction_costed_date)
                                              FROM xxdo.xxd_actual_cost_hist_details_t cst1
                                             WHERE     1 = 1
                                                   AND cst1.organization_id =
                                                       i.organization_id
                                                   AND cst1.inventory_item_id =
                                                       i.inventory_item_id
                                                   AND TRUNC (
                                                           cst1.transaction_date) <=
                                                       NVL (p_date, SYSDATE)))
                           AND organization_id = i.organization_id
                           AND inventory_item_id = i.inventory_item_id)
                       ln_material_overhead,
                   (SELECT NVL (usage_rate_or_amount, 0)
                      FROM xxdo.xxd_cst_item_cost_details_t
                     WHERE     1 = 1
                           AND organization_id = i.organization_id
                           AND cost_element_id = 2        -- Material Overhead
                           AND cost_type_id = 2
                           AND inventory_item_id = i.inventory_item_id)
                       ln_material_overhead1,
                   (SELECT NVL (new_material, 0)
                      FROM xxdo.xxd_actual_cost_hist_details_t
                     WHERE     transaction_id =
                               (SELECT MAX (cst2.transaction_id)
                                  FROM xxdo.xxd_actual_cost_hist_details_t cst2
                                 WHERE     1 = 1
                                       AND cst2.organization_id =
                                           i.organization_id
                                       AND cst2.inventory_item_id =
                                           i.inventory_item_id
                                       AND (cst2.transaction_costed_date) =
                                           (SELECT MAX (cst1.transaction_costed_date)
                                              FROM xxdo.xxd_actual_cost_hist_details_t cst1
                                             WHERE     1 = 1
                                                   AND cst1.organization_id =
                                                       i.organization_id
                                                   AND cst1.inventory_item_id =
                                                       i.inventory_item_id
                                                   AND TRUNC (
                                                           cst1.transaction_date) <=
                                                       NVL (p_date, SYSDATE)))
                           AND organization_id = i.organization_id
                           AND inventory_item_id = i.inventory_item_id)
                       ln_material_cost,
                   (SELECT NVL (usage_rate_or_amount, 0)
                      FROM xxdo.xxd_cst_item_cost_details_t
                     WHERE     1 = 1
                           AND organization_id = i.organization_id
                           AND cost_element_id = 1                 -- Material
                           AND cost_type_id = 2
                           AND inventory_item_id = i.inventory_item_id)
                       ln_material_cost1,
                   (SELECT item_cost
                      FROM apps.cst_item_costs
                     WHERE     inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id
                           AND cost_type_id = 2)
                       ln_custom_itemcost,
                   /* (
                        SELECT
                            CASE
                                WHEN cicd.basis_type_dsp = 'Total Value' THEN
                                    round(nvl(cicd1.item_cost * cicd.usage_rate_or_amount, 0), 5)
                                ELSE
                                    cicd.usage_rate_or_amount
                            END frieght_du
                        FROM
                            cst_item_cost_type_v               cict,
                            xxdo.xxd_cst_item_cost_details_t   cicd,
                            xxdo.xxd_cst_item_cost_details_t   cicd1,
                            cst_cost_types                     cct1,
                            cst_cost_types                     cct2
                        WHERE
                            cict.cost_type_id = cicd.cost_type_id
                            AND cict.inventory_item_id = cicd.inventory_item_id
                            AND cict.organization_id = cicd.organization_id
                            AND cicd1.cost_type_id = cct1.cost_type_id
                            AND cct1.cost_type = 'Average'
                            AND cicd.cost_type_id = cct2.cost_type_id
                            AND cct2.cost_type = 'AvgRates'
                            AND cicd1.cost_element = 'Material'
                            AND cicd1.inventory_item_id = cicd.inventory_item_id
                            AND cicd1.organization_id = cicd.organization_id
                            AND cict.inventory_item_id = i.inventory_item_id
                            AND cict.organization_id = i.organization_id
                            AND cicd.resource_code = 'FREIGHT DU'
                    ) ln_freight_du,*/
                   -- 1.2
                   (SELECT CASE
                               WHEN cicd.basis_type_dsp = 'Total Value'
                               THEN
                                   ROUND (
                                       NVL (
                                           cicd1.item_cost * cicd.usage_rate_or_amount,
                                           0),
                                       5)
                               ELSE
                                   cicd.usage_rate_or_amount
                           END frieght_du
                      FROM xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.organization_id = cicd.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.resource_code = 'FREIGHT DU')
                       ln_freight_du,                                   -- 1.2
                   (SELECT CASE
                               WHEN cicd.basis_type_dsp = 'Total Value'
                               THEN
                                   ROUND (
                                       NVL (
                                           cicd1.item_cost * cicd.usage_rate_or_amount,
                                           0),
                                       5)
                               ELSE
                                   cicd.usage_rate_or_amount
                           END frieght
                      FROM --cst_item_cost_type_v               cict, -- 1.2
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           -- cict.cost_type_id = cicd.cost_type_id
                           -- AND cict.inventory_item_id = cicd.inventory_item_id
                           -- AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.organization_id = cicd.organization_id
                           --  AND cict.inventory_item_id = i.inventory_item_id
                           --  AND cict.organization_id = i.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.resource_code = 'FREIGHT')
                       ln_freight,
                   (SELECT CASE
                               WHEN cicd.basis_type_dsp = 'Total Value'
                               THEN
                                   ROUND (
                                       NVL (
                                           cicd1.item_cost * cicd.usage_rate_or_amount,
                                           0),
                                       5)
                               ELSE
                                   cicd.usage_rate_or_amount
                           END duty
                      FROM -- cst_item_cost_type_v               cict,--1.2
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           --cict.cost_type_id = cicd.cost_type_id
                           -- AND cict.inventory_item_id = cicd.inventory_item_id
                           --AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.organization_id = cicd.organization_id
                           -- AND cict.inventory_item_id = i.inventory_item_id
                           -- AND cict.organization_id = i.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.resource_code = 'DUTY')
                       ln_duty,
                   (SELECT CASE
                               WHEN cicd.basis_type_dsp = 'Total Value'
                               THEN
                                   ROUND (
                                       NVL (
                                           cicd1.item_cost * cicd.usage_rate_or_amount,
                                           0),
                                       5)
                               ELSE
                                   cicd.usage_rate_or_amount
                           END ohduty
                      FROM --cst_item_cost_type_v               cict,--1.2
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           --cict.cost_type_id = cicd.cost_type_id
                           -- AND cict.inventory_item_id = cicd.inventory_item_id
                           -- AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.organization_id = cicd.organization_id
                           -- AND cict.inventory_item_id = i.inventory_item_id
                           -- AND cict.organization_id = i.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.resource_code = 'OH DUTY')
                       ln_oh_duty,
                   (SELECT CASE
                               WHEN cicd.basis_type_dsp = 'Total Value'
                               THEN
                                   ROUND (
                                       NVL (
                                           cicd1.item_cost * cicd.usage_rate_or_amount,
                                           0),
                                       5)
                               ELSE
                                   cicd.usage_rate_or_amount
                           END ohnonduty
                      FROM --cst_item_cost_type_v               cict,--1.2
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           -- cict.cost_type_id = cicd.cost_type_id
                           -- AND cict.inventory_item_id = cicd.inventory_item_id
                           -- AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.organization_id = cicd.organization_id
                           -- AND cict.inventory_item_id = i.inventory_item_id
                           -- AND cict.organization_id = i.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.resource_code = 'OH NONDUTY')
                       ln_oh_non_duty,
                   (SELECT cicd.usage_rate_or_amount duty_rate
                      FROM --cst_item_cost_type_v               cict, --1.2
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           --cict.cost_type_id = cicd.cost_type_id
                           -- AND cict.inventory_item_id = cicd.inventory_item_id
                           -- AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.organization_id = cicd.organization_id
                           --  AND cict.inventory_item_id = i.inventory_item_id
                           --  AND cict.organization_id = i.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.basis_type_dsp = 'Total Value'
                           AND cicd.resource_code = 'DUTY')
                       ln_duty_rate,
                   (SELECT cicd.usage_rate_or_amount ohduty_rate
                      FROM --  cst_item_cost_type_v               cict, --1.2
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           --cict.cost_type_id = cicd.cost_type_id
                           -- AND cict.inventory_item_id = cicd.inventory_item_id
                           -- AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.organization_id = cicd.organization_id
                           --  AND cict.inventory_item_id = i.inventory_item_id
                           --  AND cict.organization_id = i.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.basis_type_dsp = 'Total Value'
                           AND cicd.resource_code = 'OH DUTY')
                       ln_oh_duty_rate,
                   (SELECT cicd.usage_rate_or_amount frieght_du_rate
                      FROM --cst_item_cost_type_v               cict,--1.2
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           --cict.cost_type_id = cicd.cost_type_id
                           -- AND cict.inventory_item_id = cicd.inventory_item_id
                           -- AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.organization_id = cicd.organization_id
                           -- AND cict.inventory_item_id = i.inventory_item_id
                           -- AND cict.organization_id = i.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.basis_type_dsp = 'Total Value'
                           AND cicd.resource_code = 'FREIGHT DU')
                       ln_freight_du_rate,
                   (SELECT cicd.usage_rate_or_amount ohnonduty_rate
                      FROM -- cst_item_cost_type_v               cict, --1.2
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           --cict.cost_type_id = cicd.cost_type_id
                           --AND cict.inventory_item_id = cicd.inventory_item_id
                           -- AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.organization_id = cicd.organization_id
                           -- AND cict.inventory_item_id = i.inventory_item_id
                           -- AND cict.organization_id = i.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.basis_type_dsp = 'Total Value'
                           AND cicd.resource_code = 'OH NONDUTY')
                       ln_oh_nonduty_rate,
                   (SELECT cicd.usage_rate_or_amount frieght_rate
                      FROM --cst_item_cost_type_v               cict,--1.2
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1
                           --cict.cost_type_id = cicd.cost_type_id
                           -- AND cict.inventory_item_id = cicd.inventory_item_id
                           -- AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.organization_id = cicd.organization_id
                           --AND cict.inventory_item_id = i.inventory_item_id
                           --AND cict.organization_id = i.organization_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.organization_id
                           AND cicd.basis_type_dsp = 'Total Value'
                           AND cicd.resource_code = 'FREIGHT')
                       ln_freight_rate,
                   (SELECT CASE
                               WHEN COUNT (1) > 0 THEN 1
                               ELSE NULL
                           END duty_factor
                      FROM xxdo.xxd_cst_item_cost_details_t
                     WHERE     cost_element = 'Material Overhead'
                           AND inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id
                           AND basis_type_dsp = 'Total Value'
                           AND resource_code = 'DUTY')
                       ln_duty_factor,
                   (SELECT CASE
                               WHEN COUNT (1) > 0 THEN 1
                               ELSE NULL
                           END ohduty_factor
                      FROM xxdo.xxd_cst_item_cost_details_t
                     WHERE     cost_element = 'Material Overhead'
                           AND inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id
                           AND basis_type_dsp = 'Total Value'
                           AND resource_code = 'OH DUTY')
                       ln_oh_duty_factor,
                   (SELECT CASE
                               WHEN COUNT (1) > 0 THEN 1
                               ELSE NULL
                           END frieghtdu_factor
                      FROM xxdo.xxd_cst_item_cost_details_t
                     WHERE     cost_element = 'Material Overhead'
                           AND inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id
                           AND basis_type_dsp = 'Total Value'
                           AND resource_code = 'FREIGHT DU')
                       ln_freight_duty_factor,
                   (SELECT CASE
                               WHEN COUNT (1) > 0 THEN 1
                               ELSE NULL
                           END oh_nonduty_factor
                      FROM xxdo.xxd_cst_item_cost_details_t
                     WHERE     cost_element = 'Material Overhead'
                           AND inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id
                           AND basis_type_dsp = 'Total Value'
                           AND resource_code = 'OH NONDUTY')
                       ln_oh_nonduty_factor,
                   (SELECT CASE
                               WHEN COUNT (1) > 0 THEN 1
                               ELSE NULL
                           END frieght_factor
                      FROM xxdo.xxd_cst_item_cost_details_t
                     WHERE     cost_element = 'Material Overhead'
                           AND inventory_item_id = i.inventory_item_id
                           AND organization_id = i.organization_id
                           AND basis_type_dsp = 'Total Value'
                           AND resource_code = 'FREIGHT')
                       ln_freight_factor,
                   (SELECT CASE
                               WHEN cicd.basis_type_dsp = 'Total Value'
                               THEN
                                   ROUND (
                                         (NVL (cicd1.item_cost, 0) + NVL (get_item_elements_fnc (i.inventory_item_id, i.organization_id, 'freight_duty_factor') * get_item_elements_fnc (i.inventory_item_id, i.organization_id, 'freight_du_rate') * get_item_elements_fnc (i.inventory_item_id, i.organization_id, 'custom_material_cost'), NVL (get_item_elements_fnc (i.inventory_item_id, i.organization_id, 'freight_du'), 0)) + NVL (get_item_elements_fnc (i.inventory_item_id, i.organization_id, 'oh_duty_factor') * get_item_elements_fnc (i.inventory_item_id, i.organization_id, 'oh_duty_rate') * get_item_elements_fnc (i.inventory_item_id, i.organization_id, 'custom_material_cost'), NVL (get_item_elements_fnc (i.inventory_item_id, i.organization_id, 'oh_duty'), 0)))
                                       * cicd.usage_rate_or_amount,
                                       5)
                               ELSE
                                   cicd.usage_rate_or_amount
                           END duty
                      FROM -- cst_item_cost_type_v cict,
                           xxdo.xxd_cst_item_cost_details_t cicd, xxdo.xxd_cst_item_cost_details_t cicd1, cst_cost_types cct1,
                           cst_cost_types cct2
                     WHERE     1 = 1  -- cict.cost_type_id = cicd.cost_type_id
                           -- AND cict.inventory_item_id = cicd.inventory_item_id
                           -- AND cict.organization_id = cicd.organization_id
                           AND cicd1.cost_type_id = cct1.cost_type_id
                           AND cct1.cost_type = 'Average'
                           AND cicd.cost_type_id = cct2.cost_type_id
                           AND cct2.cost_type = 'AvgRates'
                           AND cicd1.cost_element = 'Material'
                           AND cicd1.inventory_item_id =
                               cicd.inventory_item_id
                           AND cicd1.organization_id = cicd.organization_id
                           --AND cict.inventory_item_id = i.inventory_item_id
                           -- AND cict.organization_id = i.inventory_item_id
                           AND cicd.inventory_item_id = i.inventory_item_id
                           AND cicd.organization_id = i.inventory_item_id
                           AND cicd.resource_code = 'DUTY')
                       in_ic_duty,
                   inventory_item_id,
                   organization_id
              FROM xxdo.xxd_cst_item_cost_details_t i
             WHERE 1 = 1 AND cost_element_id = 1 AND cost_type_id = 2;

        ln_material_cost          NUMBER;
        ln_material_overhead      NUMBER;
        ln_itemcost               NUMBER;
        ln_material               NUMBER;
        ln_nonmaterial            NUMBER;
        ln_stdfreight             NUMBER;
        ln_stdduty                NUMBER;
        ln_freightrate            NUMBER;
        ln_dutyrate               NUMBER;
        ln_fifodutyold            NUMBER;
        ln_fifofreightold         NUMBER;
        ln_eurate                 NUMBER;
        in_listprice              NUMBER;
        ln_fifoduty               NUMBER;
        ln_fifofreight            NUMBER;
        ln_freightbasis           NUMBER;
        ln_dutybasis              NUMBER;
        ln_freight_du             NUMBER;
        ln_freight                NUMBER;
        ln_duty                   NUMBER;
        ln_oh_duty                NUMBER;
        ln_oh_non_duty            NUMBER;
        ln_total_overhead         NUMBER;
        ln_custom_material_cost   NUMBER;
        ln_custom_itemcost        NUMBER;
        ln_duty_rate              NUMBER;
        ln_oh_duty_rate           NUMBER;
        ln_freight_du_rate        NUMBER;
        ln_oh_nonduty_rate        NUMBER;
        ln_freight_rate           NUMBER;
        ln_duty_factor            NUMBER;
        ln_oh_duty_factor         NUMBER;
        ln_freight_duty_factor    NUMBER;
        ln_oh_nonduty_factor      NUMBER;
        ln_freight_factor         NUMBER;
        in_ic_duty                NUMBER;
        ln_count                  NUMBER;
        ln_record_count           NUMBER := 0;
        v_cur_recs_counter        NUMBER := 0; -- To count total number of records in the cursor
        v_sql_rowcount            NUMBER := 0; -- To count total number of actual rows updated
        v_bulk_limit              NUMBER := 20000;

        TYPE tb_rec IS TABLE OF get_items_to_insert%ROWTYPE;

        --Define a variable of that table type
        v_tb_rec                  tb_rec;
    BEGIN
        BEGIN
            SELECT COUNT (*)
              INTO ln_count
              FROM xxdo.xxd_actual_cost_hist_details_t
             WHERE ROWNUM < 2;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_count   := 0;
        END;

        OPEN get_items_to_insert;

        LOOP
            FETCH get_items_to_insert
                BULK COLLECT INTO v_tb_rec
                LIMIT v_bulk_limit;

            BEGIN
                FORALL i IN 1 .. v_tb_rec.COUNT
                    INSERT INTO xxdo.xxd_inv_givr_cost_detls_t
                             VALUES (
                                        v_tb_rec (i).inventory_item_id,
                                        v_tb_rec (i).organization_id,
                                        CASE
                                            WHEN ln_count <> 0
                                            THEN
                                                v_tb_rec (i).ln_material_cost
                                            ELSE
                                                v_tb_rec (i).ln_material_cost1
                                        END,
                                        CASE
                                            WHEN ln_count <> 0
                                            THEN
                                                v_tb_rec (i).ln_material_overhead
                                            ELSE
                                                v_tb_rec (i).ln_material_overhead1
                                        END,
                                        v_tb_rec (i).ln_custom_itemcost,
                                        v_tb_rec (i).ln_freight_du,
                                        v_tb_rec (i).ln_freight,
                                        v_tb_rec (i).ln_duty,
                                        v_tb_rec (i).ln_oh_duty,
                                        v_tb_rec (i).ln_oh_non_duty,
                                        v_tb_rec (i).ln_duty_rate,
                                        v_tb_rec (i).ln_oh_duty_rate,
                                        v_tb_rec (i).ln_freight_du_rate,
                                        v_tb_rec (i).ln_oh_nonduty_rate,
                                        v_tb_rec (i).ln_freight_rate,
                                        v_tb_rec (i).ln_duty_factor,
                                        v_tb_rec (i).ln_oh_duty_factor,
                                        v_tb_rec (i).ln_freight_duty_factor,
                                        v_tb_rec (i).ln_oh_nonduty_factor,
                                        v_tb_rec (i).ln_freight_factor,
                                        v_tb_rec (i).in_ic_duty,
                                        NULL,
                                        gn_request_id,
                                        SYSDATE,
                                        gn_created_by,
                                        SYSDATE,
                                        gn_created_by,
                                        gn_created_by,
                                        p_snapshot_date);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'insertion failed for XXD_INV_GIVR_COST_DETLS_T Table'
                        || SQLERRM);
            END;

            -- Count number of actual rows updated

            v_sql_rowcount       := v_sql_rowcount + SQL%ROWCOUNT;
            -- Count number of loop cycles
            v_cur_recs_counter   := v_cur_recs_counter + v_tb_rec.COUNT;
            -- This commit will occur every v_bulk_limit records, since that is the bulk collect limit
            -- This will also happen at the last iteration of Fetch which might be less than v_bulk_limit
            COMMIT;
            EXIT WHEN get_items_to_insert%NOTFOUND;
        --query to fetch itemcost for pv_custom_cost = 'N'
        --query to fetch Material for pv_custom_cost = 'N'
        --query to fetch NONMaterial for pv_custom_cost = 'N'
        --query to fetch STDFREIGHT for pv_custom_cost = 'N'
        --query to fetch STDDUTY for pv_custom_cost = 'N'
        --query to fetch FREIGHTRATE for pv_custom_cost = 'N'
        --query to fetch DUTYRATE for pv_custom_cost = 'N'
        --query to fetch FIFODUTYOLD for pv_custom_cost = 'N'
        --query to fetch FIFOFREIGHTOLD for pv_custom_cost = 'N'
        --query to fetch EURATE for pv_custom_cost = 'N'
        --query to fetch LISTPRICE for pv_custom_cost = 'N'
        --query to fetch FREIGHTBASIS for pv_custom_cost = 'N'
        --query to fetch DUTYBASIS for pv_custom_cost = 'N'
        --query to fetch FIFODUTY for pv_custom_cost = 'N'
        --query to fetch FIFOFREIGHT for pv_custom_cost = 'N'
        --query to fetch FREIGHT DU for pv_custom_cost = 'Y'
        --query to fetch FREIGHT for pv_custom_cost = 'Y'
        --query to fetch Duty for pv_custom_cost = 'Y'
        --query to fetch OH DUTY for pv_custom_cost = 'Y'
        --query to fetch OH NONDUTY for pv_custom_cost = 'Y'
        --query to fetch MATERIAL_COST for pv_custom_cost = 'Y'
        --query to fetch ITEMCOST for pv_custom_cost = 'Y'
        --query to fetch DUTY RATE for pv_custom_cost = 'Y'
        --query to fetch OH DUTY RATE for pv_custom_cost = 'Y'
        --query to fetch FREIGHT DU RATE for pv_custom_cost = 'Y'
        --query to fetch OH NONDUTY RATE for pv_custom_cost = 'Y'
        --query to fetch FREIGHT RATE for pv_custom_cost = 'Y'
        --query to fetch DUTY FACTOR for pv_custom_cost = 'Y'
        --query to fetch OH DUTY FACTOR for pv_custom_cost = 'Y'
        --query to fetch 'FREIGHT DU FACTOR for pv_custom_cost = 'Y'

        --query to fetch OH NONDUTY FACTOR for pv_custom_cost = 'Y'

        --query to fetch FREIGHT FACTOR for pv_custom_cost = 'Y'



        --query to fetch IC_DUTY for pv_custom_cost = 'Y'



        -- Insert the data into GIVR custom table.
        -- ln_record_count :=ln_record_count+1;
        END LOOP;
    END xxd_load_givr_table_data_prc;

    --1.1 changes end

    FUNCTION xxd_cst_mat_oh_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER
    IS
        ln_val     NUMBER;
        ln_count   NUMBER;
    BEGIN
        BEGIN
            SELECT NVL (material_overhead, 0)
              INTO ln_val
              FROM xxdo.xxd_inv_givr_cost_detls_t
             WHERE     inventory_item_id = p_inventory_item_id
                   AND organization_id = p_organization_id
                   AND snapshot_date = p_date;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_val   := NULL;
        --ln_val := 0;                                       -- Added New
        END;

        RETURN ln_val;
    END xxd_cst_mat_oh_fnc;

    FUNCTION xxd_cst_mat_fnc (p_inventory_item_id IN NUMBER, p_organization_id IN NUMBER, p_date IN DATE)
        RETURN NUMBER
    IS
        ln_val     NUMBER;
        ln_count   NUMBER;
    BEGIN
        BEGIN
            SELECT NVL (material_cost, 0)
              INTO ln_val
              FROM xxdo.xxd_inv_givr_cost_detls_t
             WHERE     inventory_item_id = p_inventory_item_id
                   AND organization_id = p_organization_id
                   AND snapshot_date = p_date;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_val   := NULL;
        --ln_val := 0;                                       -- Added New
        END;

        RETURN ln_val;
    END xxd_cst_mat_fnc;

    FUNCTION xxd_get_snap_item_cost_fnc (pv_cost                IN VARCHAR2,
                                         pn_organization_id        NUMBER,
                                         pn_inventory_item_id      NUMBER,
                                         pv_custom_cost         IN VARCHAR2,
                                         p_date                 IN DATE)
        RETURN NUMBER
    IS
        /*-----------------------------------------------------------------------------------*/
        /* 1.0 BT Technology Team 21-Jan-2015   Added logic for new sub elements for BT.
        /*************************************************************************************/
        ln_itemcost   NUMBER;
    BEGIN
        IF pv_custom_cost = 'N'
        THEN
            IF pv_cost = 'ITEMCOST'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT NVL (ITEMCOST, 0)
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        RETURN 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            ELSE
                IF pv_cost = 'MATERIAL'
                THEN
                    BEGIN
                        ln_itemcost   := NULL;

                        SELECT NVL (material_cost, 0)
                          INTO ln_itemcost
                          FROM xxdo.xxd_inv_givr_cost_detls_t
                         WHERE     inventory_item_id = pn_inventory_item_id
                               AND organization_id = pn_organization_id
                               AND snapshot_date = p_date;

                        RETURN ln_itemcost;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            RETURN 0;
                    END;
                ELSE
                    IF pv_cost = 'NONMATERIAL'
                    THEN
                        BEGIN
                            ln_itemcost   := NULL;

                            SELECT NVL (material_overhead, 0)
                              INTO ln_itemcost
                              FROM xxdo.xxd_inv_givr_cost_detls_t
                             WHERE     inventory_item_id =
                                       pn_inventory_item_id
                                   AND organization_id = pn_organization_id
                                   AND snapshot_date = p_date;

                            RETURN ln_itemcost;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                RETURN 0;
                        END;
                    ELSE
                        IF pv_cost = 'STDFREIGHT'
                        THEN
                            BEGIN
                                ln_itemcost   := NULL;

                                RETURN ln_itemcost;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    RETURN 0;
                            END;
                        ELSE
                            IF pv_cost = 'STDDUTY'
                            THEN
                                BEGIN
                                    ln_itemcost   := NULL;


                                    RETURN ln_itemcost;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        RETURN 0;
                                END;
                            ELSE
                                IF pv_cost = 'FREIGHTRATE'
                                THEN
                                    BEGIN
                                        ln_itemcost   := NULL;


                                        RETURN ln_itemcost;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            RETURN 0;
                                    END;
                                ELSE
                                    IF pv_cost = 'DUTYRATE'
                                    THEN
                                        BEGIN
                                            RETURN 0;
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                RETURN 0;
                                        END;
                                    ELSE
                                        IF pv_cost = 'FIFODUTYOLD'
                                        THEN
                                            BEGIN
                                                ln_itemcost   := NULL;


                                                RETURN ln_itemcost;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    RETURN 0;
                                            END;
                                        ELSE
                                            IF pv_cost = 'FIFOFREIGHTOLD'
                                            THEN
                                                BEGIN
                                                    ln_itemcost   := NULL;


                                                    RETURN ln_itemcost;
                                                EXCEPTION
                                                    WHEN OTHERS
                                                    THEN
                                                        RETURN 0;
                                                END;
                                            ELSE
                                                IF pv_cost = 'EURATE'
                                                THEN
                                                    BEGIN
                                                        ln_itemcost   := NULL;


                                                        RETURN ln_itemcost;
                                                    EXCEPTION
                                                        WHEN OTHERS
                                                        THEN
                                                            RETURN 0;
                                                    END;
                                                ELSE
                                                    IF pv_cost = 'LISTPRICE'
                                                    THEN
                                                        BEGIN
                                                            ln_itemcost   :=
                                                                NULL;


                                                            RETURN ln_itemcost;
                                                        EXCEPTION
                                                            WHEN OTHERS
                                                            THEN
                                                                RETURN 0;
                                                        END;
                                                    ELSE
                                                        IF pv_cost =
                                                           'FIFODUTY'
                                                        THEN
                                                            BEGIN
                                                                ln_itemcost   :=
                                                                    NULL;

                                                                RETURN ln_itemcost;
                                                            EXCEPTION
                                                                WHEN OTHERS
                                                                THEN
                                                                    RETURN 0;
                                                            END;
                                                        ELSE
                                                            IF pv_cost =
                                                               'FIFOFREIGHT'
                                                            THEN
                                                                BEGIN
                                                                    ln_itemcost   :=
                                                                        NULL;


                                                                    RETURN ln_itemcost;
                                                                EXCEPTION
                                                                    WHEN OTHERS
                                                                    THEN
                                                                        RETURN 0;
                                                                END;
                                                            ELSE
                                                                IF pv_cost =
                                                                   'FREIGHTBASIS'
                                                                THEN
                                                                    BEGIN
                                                                        ln_itemcost   :=
                                                                            NULL;


                                                                        RETURN ln_itemcost;
                                                                    EXCEPTION
                                                                        WHEN OTHERS
                                                                        THEN
                                                                            RETURN 0;
                                                                    END;
                                                                ELSE
                                                                    IF pv_cost =
                                                                       'DUTYBASIS'
                                                                    THEN
                                                                        BEGIN
                                                                            ln_itemcost   :=
                                                                                NULL;


                                                                            RETURN ln_itemcost;
                                                                        EXCEPTION
                                                                            WHEN OTHERS
                                                                            THEN
                                                                                RETURN 0;
                                                                        END;
                                                                    END IF;
                                                                END IF;
                                                            END IF;
                                                        END IF;
                                                    END IF;
                                                END IF;
                                            END IF;
                                        END IF;
                                    END IF;
                                END IF;
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
        ELSE
            --Start Changes by BT Technology Team on 23-Jul-2015
            IF pv_cost = 'FREIGHT DU'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT freight_du
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            ELSIF pv_cost = 'FREIGHT'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT freight
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            ELSIF pv_cost = 'DUTY'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT duty
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            ELSIF pv_cost = 'OH DUTY'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT oh_duty
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            ELSIF pv_cost = 'OH NONDUTY'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT oh_non_duty
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            ELSIF pv_cost = 'TOTAL OVERHEAD'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT NVL (material_overhead, 0)
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            ELSIF (pv_cost = 'MATERIAL_COST')
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT NVL (material_cost, 0)
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            ELSIF pv_cost = 'ITEMCOST'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT itemcost
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            ELSIF pv_cost = 'DUTY RATE'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT duty_rate
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'OH DUTY RATE'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT oh_duty_rate
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'FREIGHT DU RATE'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT freight_du_rate
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'OH NONDUTY RATE'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT oh_nonduty_rate
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'FREIGHT RATE'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT freight_rate
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'DUTY FACTOR'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT duty_factor
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'OH DUTY FACTOR'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT oh_duty_factor
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'FREIGHT DU FACTOR'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT reight_du_factor
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'OH NONDUTY FACTOR'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT oh_nonduty_factor
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'FREIGHT FACTOR'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT freight_factor
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := NULL;
                    WHEN OTHERS
                    THEN
                        RETURN NULL;
                END;
            ELSIF pv_cost = 'IC_DUTY'
            THEN
                BEGIN
                    ln_itemcost   := NULL;

                    SELECT ic_duty
                      INTO ln_itemcost
                      FROM xxdo.xxd_inv_givr_cost_detls_t
                     WHERE     inventory_item_id = pn_inventory_item_id
                           AND organization_id = pn_organization_id
                           AND snapshot_date = p_date;

                    RETURN ln_itemcost;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_itemcost   := 0;
                    WHEN OTHERS
                    THEN
                        RETURN 0;
                END;
            --End Changes by BT Technology Team on 23-Jul-2015
            END IF;
        END IF;

        RETURN ln_itemcost; --Updated from 0 to ln_itemcost by BT Technology Team on 23-Jul-2015
    END xxd_get_snap_item_cost_fnc;

    PROCEDURE main (errbuf                 OUT NOCOPY VARCHAR2,
                    retcode                OUT NOCOPY VARCHAR2,
                    p_as_of_date        IN            VARCHAR2,
                    p_snapshot_date     IN            VARCHAR2,          --1.1
                    p_region            IN            VARCHAR2,          --1.2
                    p_organization_id   IN            NUMBER             --1.2
                                                            )
    IS
        lv_action_type     VARCHAR2 (100);
        l_use_date         DATE;
        l_snapshot_date    DATE;                                         --1.1
        ln_count           NUMBER;
        error_ex           EXCEPTION;
        ld_snapshot_date   VARCHAR2 (100);
        ln_data_count      NUMBER;
    BEGIN
        ln_count           := 0;
        lv_action_type     := NULL;
        l_use_date         := NULL;
        ld_snapshot_date   := NULL;
        fnd_file.put_line (fnd_file.LOG, 'Start of Program');

        BEGIN
            SELECT COUNT (1)
              INTO ln_count
              FROM apps.fnd_concurrent_requests
             WHERE     1 = 1
                   AND phase_code = 'R'
                   AND status_code = 'R'
                   AND argument1 = 'SNAPSHOT'
                   AND concurrent_program_id IN
                           (SELECT concurrent_program_id
                              FROM apps.fnd_concurrent_programs_vl
                             WHERE user_concurrent_program_name =
                                   'Global Inventory Value Report-Deckers');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_count   := 0;
        END;

        IF ln_count <> 0
        THEN
            RAISE error_ex;
        --         retcode := 2;
        --         errbuf :=
        --            'There is already SNPASHOT program is in Progress, Please wait till it is complete';
        --         fnd_file.put_line (
        --            fnd_file.LOG,
        --            ' There is already SNPASHOT program is in Progress, Please wait till it is complete ');
        ELSIF ln_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Program execution Begin');
        END IF;

        IF p_as_of_date IS NULL
        THEN
            lv_action_type   := 'INSERT';
            l_use_date       := TRUNC (SYSDATE) + 1;
            l_snapshot_date   :=
                TO_DATE (p_snapshot_date, 'YYYY/MM/DD HH24:MI:SS');      --1.1
        ELSIF p_as_of_date IS NOT NULL
        THEN
            l_use_date       :=
                TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS') + 1;
            lv_action_type   := 'UPDATE';
            l_snapshot_date   :=
                TO_DATE (p_snapshot_date, 'YYYY/MM/DD HH24:MI:SS');      --1.1

            --1.1 changes start
            BEGIN
                SELECT COUNT (1)
                  INTO ln_data_count
                  FROM XXDO.XXD_INV_GIVR_COST_DETLS_T t
                 WHERE     snapshot_date = l_snapshot_date
                       --1.2 changes start
                       AND EXISTS
                               (SELECT 1
                                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl, -- apps.org_organization_definitions   ood --1.2
                                                                                                   apps.mtl_parameters ood --1.2
                                 WHERE     fvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND fvs.flex_value_set_name LIKE
                                               'XXD_GIVR_COST_SNPS_ORG'
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y'
                                       AND ood.organization_code =
                                           ffvl.flex_value
                                       AND ood.organization_id =
                                           t.organization_id
                                       AND ffvl.description =
                                           NVL (p_region, ffvl.description) -- 1.2
                                       AND ood.organization_id =
                                           NVL (p_organization_id,
                                                ood.organization_id)     --1.2
                                                                    );
            -- 1.2 changes end
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_data_count   := 0;
            END;

            IF ln_data_count > 0
            THEN
                BEGIN
                    DELETE FROM
                        XXDO.XXD_INV_GIVR_COST_DETLS_T t
                          WHERE     snapshot_date = l_snapshot_date
                                --1.2 changes start
                                AND EXISTS
                                        (SELECT 1
                                           FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl, -- apps.org_organization_definitions   ood --1.2
                                                                                                            apps.mtl_parameters ood --1.2
                                          WHERE     fvs.flex_value_set_id =
                                                    ffvl.flex_value_set_id
                                                AND fvs.flex_value_set_name LIKE
                                                        'XXD_GIVR_COST_SNPS_ORG'
                                                AND NVL (
                                                        TRUNC (
                                                            ffvl.start_date_active),
                                                        TRUNC (SYSDATE)) <=
                                                    TRUNC (SYSDATE)
                                                AND NVL (
                                                        TRUNC (
                                                            ffvl.end_date_active),
                                                        TRUNC (SYSDATE)) >=
                                                    TRUNC (SYSDATE)
                                                AND ffvl.enabled_flag = 'Y'
                                                AND ood.organization_code =
                                                    ffvl.flex_value
                                                AND ood.organization_id =
                                                    t.organization_id
                                                AND ffvl.description =
                                                    NVL (p_region,
                                                         ffvl.description) -- 1.2
                                                AND ood.organization_id =
                                                    NVL (p_organization_id,
                                                         ood.organization_id) --1.2
                                                                             );

                    -- 1.2 changes end;
                    COMMIT;
                END;
            END IF;
        -- 1.1 changes end
        END IF;

        -- ld_snapshot_date := TO_CHAR (TO_DATE (l_use_date)-1, 'DD-MON-YYYY');

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_cst_item_cost_details_t';

        --EXECUTE IMMEDIATE 'TRUNCATE TABLE  xxdo.xxd_cst_mmt_t';--1.1
        EXECUTE IMMEDIATE 'TRUNCATE TABLE  xxdo.xxd_actual_cost_hist_details_t';

        --DELETE xxdo.xxd_cst_mmt_t;

        --DELETE xxdo.xxd_actual_cost_hist_details_t;

        --COMMIT;
        load_cst_view_tbl_prc (p_region, p_organization_id);            -- 1.2

        -- load_cst_mmt_tbl_prc (l_use_date);--1.1

        -- upd_cst_mmt_tbl_prc;--1.1
        IF lv_action_type = 'UPDATE'
        THEN
            ins_cst_hist_dtls_tbl_prc (l_use_date);
        END IF;

        --1.1 changes start
        xxd_load_givr_table_data_prc (l_use_date, l_snapshot_date);

        --1.1 changes end
        IF lv_action_type = 'INSERT'
        THEN
            fnd_file.put_line (fnd_file.output, 'Program Parameters:');
            fnd_file.put_line (fnd_file.output,
                               'As of Date - ' || p_as_of_date);
            fnd_file.put_line (
                fnd_file.output,
                   'Snapshot creation date is - '
                || TO_CHAR (TO_DATE (l_use_date) - 1, 'DD-MON-YYYY'));

            fnd_file.put_line (
                fnd_file.output,
                ' Snapshot is created on cst_item_cost_details_v and table name is xxdo.xxd_cst_item_cost_details_t');
        ELSIF lv_action_type = 'UPDATE'
        THEN
            fnd_file.put_line (fnd_file.output, 'Program Parameters:');
            fnd_file.put_line (fnd_file.output,
                               'As of Date - ' || p_as_of_date);
            fnd_file.put_line (
                fnd_file.output,
                   'Snapshot creation date is - '
                || TO_CHAR (TO_DATE (l_use_date) - 1, 'DD-MON-YYYY'));

            fnd_file.put_line (
                fnd_file.output,
                ' Snapshot is created on cst_item_cost_details_v and table name is xxdo.xxd_cst_item_cost_details_t');
            fnd_file.put_line (
                fnd_file.output,
                ' Snapshot is created on cg_cst_cost_history_v and table name is xxdo.xxd_actual_cost_hist_details_t');
        END IF;
    EXCEPTION
        WHEN error_ex
        THEN
            retcode   := 2;
            errbuf    :=
                'There is already SNPASHOT program is in Progress, Please wait till it is complete';
            fnd_file.put_line (
                fnd_file.LOG,
                ' There is already SNPASHOT program is in Progress, Please wait till it is complete ');
        WHEN OTHERS
        THEN
            retcode   := 2;
            errbuf    :=
                   'Undefined Exception occurred while running this Program, Error is - '
                || SUBSTR (SQLERRM, 1, 200);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Undefined Exception occurred while running this Program, Error is - '
                || SUBSTR (SQLERRM, 1, 200));
    END main;
END xxd_inv_givr_snap_pkg;
/
