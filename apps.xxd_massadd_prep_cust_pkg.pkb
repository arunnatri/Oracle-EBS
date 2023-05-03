--
-- XXD_MASSADD_PREP_CUST_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_massadd_prep_cust_pkg
AS
    /* $Header: XXD_MASSADD_PREP_CUST_PKG.pkb 120.2.12010000.2 2014/10/10 09:44:58 btdev ship

      -- Purpose :
      -- Public function and procedures
    ***************************************************************************************
      Program    : XXD_MASSADD_PREP_CUST_PKG
      Author     :
      Owner      : APPS
      Modifications:
      -------------------------------------------------------------------------------
      Date           version    Author          Description
      -------------  ------- ----------     -----------------------------------------
      10-Oct-2014     1.0     BTDEV Team       Added custom code called by FA_MASSADD_PREP_CUSTOM_PKG
                                                        to handle merge split functionality.

    ***************************************************************************************/

    /*+==========================================================================+
 | Procedure name                                                             |
 |     GET_SPLT_MRG_PRNT_REC                                                   |
 |                                                                            |
 | DESCRIPTION                                                                |
 |     Procedure to split the parent record which is PO related to child      |
 |      records,these are merged records                                       |
 +===========================================================================*/
    PROCEDURE get_splt_mrg_prnt_rec (p_mass_add_rec IN OUT NOCOPY fa_massadd_prepare_pkg.mass_add_rec, p_location_id IN NUMBER, p_custodian_id IN NUMBER)
    IS
        l_mass_add_in_rec        fa_massadd_prepare_pkg.mass_add_rec := NULL;
        ln_actual_cost           NUMBER;
        ln_period                NUMBER;
        ln_prd_length            NUMBER;
        ln_tot_length            NUMBER;
        lc_child_status          VARCHAR2 (10);
        lc_child_queue           VARCHAR2 (10);
        ln_cost                  NUMBER;
        ln_location_id           NUMBER;
        ln_total_actual_cost     NUMBER;
        ln_payable_actual_cost   NUMBER;
        ln_pay_period            NUMBER;
        ln_pay_prd_length        NUMBER;
        ln_pay_tot_length        NUMBER;
        ln_total_pay_cost        NUMBER;
        ln_payable_cost          NUMBER;
        lc_po_match_flag         VARCHAR2 (10);
    BEGIN
        -- Assigning input paramemeter values to local rec type variable
        l_mass_add_in_rec                     := p_mass_add_rec;
        --Start of inserting child records  if fixed_assets_units quantity is more than one
        l_mass_add_in_rec.posting_status      :=
            fa_massadd_prep_custom_pkg.lc_status_split;

        IF ln_location_id IS NULL AND l_mass_add_in_rec.location_id IS NULL
        THEN
            l_mass_add_in_rec.queue_name   :=
                fa_massadd_prep_custom_pkg.lc_status_rip;
            lc_child_status   := fa_massadd_prep_custom_pkg.lc_status_rip;
            lc_child_queue    := fa_massadd_prep_custom_pkg.lc_status_rip;
        ELSIF     l_mass_add_in_rec.location_id IS NOT NULL
              AND l_mass_add_in_rec.asset_category_id IS NOT NULL
              AND l_mass_add_in_rec.expense_code_combination_id IS NOT NULL
        THEN
            l_mass_add_in_rec.queue_name   :=
                fa_massadd_prep_custom_pkg.lc_status_post;
            lc_child_status   := fa_massadd_prep_custom_pkg.lc_status_post;
            lc_child_queue    := fa_massadd_prep_custom_pkg.lc_status_post;
        ELSE
            l_mass_add_in_rec.queue_name   :=
                fa_massadd_prep_custom_pkg.lc_status_post;
            lc_child_status   := fa_massadd_prep_custom_pkg.lc_status_post;
            lc_child_queue    := fa_massadd_prep_custom_pkg.lc_status_post;
        END IF;

        l_mass_add_in_rec.payables_units      :=
            l_mass_add_in_rec.fixed_assets_units;
        l_mass_add_in_rec.split_merged_code   := 'MP';
        l_mass_add_in_rec.merged_code         := 'MP';
        l_mass_add_in_rec.split_code          := 'SP';
        ln_cost                               := 0;
        ln_period                             := 0;
        ln_prd_length                         := 0;
        ln_tot_length                         := 0;
        ln_actual_cost                        := 0;
        ln_total_actual_cost                  := 0;
        ln_cost                               :=
              l_mass_add_in_rec.fixed_assets_cost
            / l_mass_add_in_rec.fixed_assets_units;
        ln_period                             := INSTR (ln_cost, '.', 1);
        --Added for payable cost
        ln_payable_cost                       := 0;
        ln_pay_period                         := 0;
        ln_pay_prd_length                     := 0;
        ln_pay_tot_length                     := 0;
        ln_payable_actual_cost                := 0;
        ln_total_pay_cost                     := 0;
        ln_payable_cost                       :=
              l_mass_add_in_rec.payables_cost
            / l_mass_add_in_rec.payables_units;
        ln_pay_period                         :=
            INSTR (ln_payable_cost, '.', 1);

        --End for payable cost
        IF ln_period != 0
        THEN
            ln_prd_length   := LENGTH (SUBSTR (ln_cost, ln_period + 1));
            ln_tot_length   := LENGTH (SUBSTR (ln_cost, 1, ln_period));
        END IF;

        IF ln_prd_length > 2
        THEN
            ln_actual_cost   := SUBSTR (ln_cost, 1, ln_tot_length + 2);
        ELSE
            ln_actual_cost   := ln_cost;
        END IF;

        FOR i IN 1 .. l_mass_add_in_rec.fixed_assets_units
        LOOP
            IF ln_prd_length > 2
            THEN
                IF i < l_mass_add_in_rec.fixed_assets_units
                THEN
                    ln_total_actual_cost   :=
                        ln_total_actual_cost + ln_actual_cost;
                END IF;

                IF i = l_mass_add_in_rec.fixed_assets_units
                THEN
                    ln_actual_cost   :=
                          l_mass_add_in_rec.fixed_assets_cost
                        - ln_total_actual_cost;
                END IF;
            END IF;

            --Added for payable
            IF ln_pay_period != 0
            THEN
                ln_pay_prd_length   :=
                    LENGTH (SUBSTR (ln_payable_cost, ln_pay_period + 1));
                ln_pay_tot_length   :=
                    LENGTH (SUBSTR (ln_payable_cost, 1, ln_pay_period));
            END IF;

            IF ln_pay_prd_length > 2
            THEN
                ln_payable_actual_cost   :=
                    SUBSTR (ln_payable_cost, 1, ln_pay_tot_length + 2);
            ELSE
                ln_payable_actual_cost   := ln_payable_cost;
            END IF;

            IF ln_pay_prd_length > 2
            THEN
                IF i < l_mass_add_in_rec.payables_units
                THEN
                    ln_total_pay_cost   :=
                        ln_total_pay_cost + ln_payable_actual_cost;
                END IF;

                IF i = l_mass_add_in_rec.payables_units
                THEN
                    ln_payable_actual_cost   :=
                        l_mass_add_in_rec.payables_cost - ln_total_pay_cost;
                END IF;
            END IF;

            --End for payable

            --Inserting child records based on fixed asset units quantity
            BEGIN
                INSERT INTO fa_mass_additions (
                                mass_addition_id,
                                asset_number,
                                tag_number,
                                description,
                                asset_category_id,
                                manufacturer_name,
                                serial_number,
                                model_number,
                                book_type_code,
                                date_placed_in_service,
                                fixed_assets_cost,
                                payables_units,
                                fixed_assets_units,
                                payables_code_combination_id,
                                expense_code_combination_id,
                                location_id,
                                assigned_to,
                                feeder_system_name,
                                create_batch_date,
                                create_batch_id,
                                last_update_date,
                                last_updated_by,
                                reviewer_comments,
                                invoice_number,
                                invoice_line_number,
                                invoice_distribution_id,
                                vendor_number,
                                po_vendor_id,
                                po_number,
                                posting_status,
                                queue_name,
                                invoice_date,
                                invoice_created_by,
                                invoice_updated_by,
                                payables_cost,
                                invoice_id,
                                payables_batch_name,
                                depreciate_flag,
                                parent_mass_addition_id,
                                parent_asset_id,
                                split_merged_code,
                                ap_distribution_line_number,
                                post_batch_id,
                                add_to_asset_id,
                                amortize_flag,
                                new_master_flag,
                                asset_key_ccid,
                                asset_type,
                                deprn_reserve,
                                ytd_deprn,
                                beginning_nbv,
                                created_by,
                                creation_date,
                                last_update_login,
                                salvage_value,
                                accounting_date,
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
                                attribute_category_code,
                                fully_rsvd_revals_counter,
                                merge_invoice_number,
                                merge_vendor_number,
                                production_capacity,
                                reval_amortization_basis,
                                reval_reserve,
                                unit_of_measure,
                                unrevalued_cost,
                                ytd_reval_deprn_expense,
                                attribute16,
                                attribute17,
                                attribute18,
                                attribute19,
                                attribute20,
                                attribute21,
                                attribute22,
                                attribute23,
                                attribute24,
                                attribute25,
                                attribute26,
                                attribute27,
                                attribute28,
                                attribute29,
                                attribute30,
                                merged_code,
                                split_code,
                                merge_parent_mass_additions_id,
                                split_parent_mass_additions_id,
                                project_asset_line_id,
                                project_id,
                                task_id,
                                sum_units,
                                dist_name,
                                global_attribute1,
                                global_attribute2,
                                global_attribute3,
                                global_attribute4,
                                global_attribute5,
                                global_attribute6,
                                global_attribute7,
                                global_attribute8,
                                global_attribute9,
                                global_attribute10,
                                global_attribute11,
                                global_attribute12,
                                global_attribute13,
                                global_attribute14,
                                global_attribute15,
                                global_attribute16,
                                global_attribute17,
                                global_attribute18,
                                global_attribute19,
                                global_attribute20,
                                global_attribute_category,
                                CONTEXT,
                                inventorial,
                                short_fiscal_year_flag,
                                conversion_date,
                                original_deprn_start_date,
                                group_asset_id,
                                cua_parent_hierarchy_id,
                                units_to_adjust,
                                bonus_ytd_deprn,
                                bonus_deprn_reserve,
                                amortize_nbv_flag,
                                amortization_start_date,
                                transaction_type_code,
                                transaction_date,
                                warranty_id,
                                lease_id,
                                lessor_id,
                                property_type_code,
                                property_1245_1250_code,
                                in_use_flag,
                                owned_leased,
                                new_used,
                                asset_id,
                                material_indicator_flag)
                         VALUES (
                                    fa_mass_additions_s.NEXTVAL,
                                    l_mass_add_in_rec.asset_number,
                                    NULL,
                                    l_mass_add_in_rec.description,
                                    l_mass_add_in_rec.asset_category_id,
                                    l_mass_add_in_rec.manufacturer_name,
                                    NULL,
                                    l_mass_add_in_rec.model_number,
                                    l_mass_add_in_rec.book_type_code,
                                    l_mass_add_in_rec.date_placed_in_service,
                                    ln_actual_cost,
                                    1,
                                    1,
                                    l_mass_add_in_rec.payables_code_combination_id,
                                    l_mass_add_in_rec.expense_code_combination_id,
                                    l_mass_add_in_rec.location_id,
                                    l_mass_add_in_rec.assigned_to,
                                    l_mass_add_in_rec.feeder_system_name,
                                    l_mass_add_in_rec.create_batch_date,
                                    l_mass_add_in_rec.create_batch_id,
                                    SYSDATE,
                                    l_mass_add_in_rec.last_updated_by,
                                    l_mass_add_in_rec.reviewer_comments,
                                    l_mass_add_in_rec.invoice_number,
                                    l_mass_add_in_rec.invoice_line_number,
                                    l_mass_add_in_rec.invoice_distribution_id,
                                    l_mass_add_in_rec.vendor_number,
                                    l_mass_add_in_rec.po_vendor_id,
                                    l_mass_add_in_rec.po_number,
                                    lc_child_status,
                                    lc_child_queue,
                                    l_mass_add_in_rec.invoice_date,
                                    l_mass_add_in_rec.invoice_created_by,
                                    l_mass_add_in_rec.invoice_updated_by,
                                    ln_payable_actual_cost,
                                    --l_mass_add_in_rec.PAYABLES_COST,
                                    l_mass_add_in_rec.invoice_id,
                                    l_mass_add_in_rec.payables_batch_name,
                                    l_mass_add_in_rec.depreciate_flag,
                                    '',
                                    --l_mass_add_in_rec.PARENT_MASS_ADDITION_ID,
                                    l_mass_add_in_rec.parent_asset_id,
                                    'MP',
                                    l_mass_add_in_rec.ap_distribution_line_number,
                                    l_mass_add_in_rec.post_batch_id,
                                    l_mass_add_in_rec.add_to_asset_id,
                                    l_mass_add_in_rec.amortize_flag,
                                    l_mass_add_in_rec.new_master_flag,
                                    l_mass_add_in_rec.asset_key_ccid,
                                    l_mass_add_in_rec.asset_type,
                                    l_mass_add_in_rec.deprn_reserve,
                                    l_mass_add_in_rec.ytd_deprn,
                                    l_mass_add_in_rec.beginning_nbv,
                                    l_mass_add_in_rec.created_by,
                                    l_mass_add_in_rec.creation_date,
                                    l_mass_add_in_rec.last_update_login,
                                    l_mass_add_in_rec.salvage_value,
                                    l_mass_add_in_rec.accounting_date,
                                    l_mass_add_in_rec.attribute1,
                                    l_mass_add_in_rec.attribute2,
                                    l_mass_add_in_rec.attribute3,
                                    l_mass_add_in_rec.attribute4,
                                    l_mass_add_in_rec.attribute5,
                                    l_mass_add_in_rec.attribute6,
                                    l_mass_add_in_rec.attribute7,
                                    l_mass_add_in_rec.attribute8,
                                    l_mass_add_in_rec.attribute9,
                                    l_mass_add_in_rec.attribute10,
                                    l_mass_add_in_rec.attribute11,
                                    l_mass_add_in_rec.attribute12,
                                    l_mass_add_in_rec.attribute13,
                                    l_mass_add_in_rec.attribute14,
                                    l_mass_add_in_rec.attribute15,
                                    l_mass_add_in_rec.attribute_category_code,
                                    l_mass_add_in_rec.fully_rsvd_revals_counter,
                                    l_mass_add_in_rec.merge_invoice_number,
                                    l_mass_add_in_rec.merge_vendor_number,
                                    l_mass_add_in_rec.production_capacity,
                                    l_mass_add_in_rec.reval_amortization_basis,
                                    l_mass_add_in_rec.reval_reserve,
                                    l_mass_add_in_rec.unit_of_measure,
                                    l_mass_add_in_rec.unrevalued_cost,
                                    l_mass_add_in_rec.ytd_reval_deprn_expense,
                                    l_mass_add_in_rec.attribute16,
                                    l_mass_add_in_rec.attribute17,
                                    l_mass_add_in_rec.attribute18,
                                    l_mass_add_in_rec.attribute19,
                                    l_mass_add_in_rec.attribute20,
                                    l_mass_add_in_rec.attribute21,
                                    l_mass_add_in_rec.attribute22,
                                    l_mass_add_in_rec.attribute23,
                                    l_mass_add_in_rec.attribute24,
                                    l_mass_add_in_rec.attribute25,
                                    l_mass_add_in_rec.attribute26,
                                    l_mass_add_in_rec.attribute27,
                                    l_mass_add_in_rec.attribute28,
                                    l_mass_add_in_rec.attribute29,
                                    l_mass_add_in_rec.attribute30,
                                    l_mass_add_in_rec.merged_code,
                                    'SC',
                                    '',
                                    --l_mass_add_in_rec.MERGE_PARENT_MASS_ADDITIONS_ID,
                                    l_mass_add_in_rec.mass_addition_id,
                                    l_mass_add_in_rec.project_asset_line_id,
                                    l_mass_add_in_rec.project_id,
                                    l_mass_add_in_rec.task_id,
                                    'NO',
                                    l_mass_add_in_rec.dist_name,
                                    l_mass_add_in_rec.global_attribute1,
                                    l_mass_add_in_rec.global_attribute2,
                                    l_mass_add_in_rec.global_attribute3,
                                    l_mass_add_in_rec.global_attribute4,
                                    l_mass_add_in_rec.global_attribute5,
                                    l_mass_add_in_rec.global_attribute6,
                                    l_mass_add_in_rec.global_attribute7,
                                    l_mass_add_in_rec.global_attribute8,
                                    l_mass_add_in_rec.global_attribute9,
                                    l_mass_add_in_rec.global_attribute10,
                                    l_mass_add_in_rec.global_attribute11,
                                    l_mass_add_in_rec.global_attribute12,
                                    l_mass_add_in_rec.global_attribute13,
                                    l_mass_add_in_rec.global_attribute14,
                                    l_mass_add_in_rec.global_attribute15,
                                    l_mass_add_in_rec.global_attribute16,
                                    l_mass_add_in_rec.global_attribute17,
                                    l_mass_add_in_rec.global_attribute18,
                                    l_mass_add_in_rec.global_attribute19,
                                    l_mass_add_in_rec.global_attribute20,
                                    l_mass_add_in_rec.global_attribute_category,
                                    l_mass_add_in_rec.CONTEXT,
                                    l_mass_add_in_rec.inventorial,
                                    l_mass_add_in_rec.short_fiscal_year_flag,
                                    l_mass_add_in_rec.conversion_date,
                                    l_mass_add_in_rec.original_deprn_start_date,
                                    l_mass_add_in_rec.group_asset_id,
                                    l_mass_add_in_rec.cua_parent_hierarchy_id,
                                    l_mass_add_in_rec.units_to_adjust,
                                    l_mass_add_in_rec.bonus_ytd_deprn,
                                    l_mass_add_in_rec.bonus_deprn_reserve,
                                    l_mass_add_in_rec.amortize_nbv_flag,
                                    l_mass_add_in_rec.amortization_start_date,
                                    l_mass_add_in_rec.transaction_type_code,
                                    l_mass_add_in_rec.transaction_date,
                                    l_mass_add_in_rec.warranty_id,
                                    l_mass_add_in_rec.lease_id,
                                    l_mass_add_in_rec.lessor_id,
                                    l_mass_add_in_rec.property_type_code,
                                    l_mass_add_in_rec.property_1245_1250_code,
                                    l_mass_add_in_rec.in_use_flag,
                                    l_mass_add_in_rec.owned_leased,
                                    l_mass_add_in_rec.new_used,
                                    l_mass_add_in_rec.asset_id,
                                    l_mass_add_in_rec.material_indicator_flag);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception occured while inserting into fa_mass_additions table '
                        || SQLERRM);
            END;

            BEGIN
                INSERT INTO fa_massadd_distributions (massadd_dist_id,
                                                      mass_addition_id,
                                                      units,
                                                      deprn_expense_ccid,
                                                      location_id,
                                                      employee_id)
                         VALUES (
                                    fa_massadd_distributions_s.NEXTVAL,
                                    fa_mass_additions_s.CURRVAL,
                                    1,
                                    l_mass_add_in_rec.expense_code_combination_id,
                                    l_mass_add_in_rec.location_id,
                                    p_custodian_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception occured while inserting into fa_massadd_distributions table '
                        || SQLERRM);
            END;
        END LOOP;

        COMMIT;
        p_mass_add_rec                        := l_mass_add_in_rec;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception occured get_splt_mrg_prnt_rec procedure '
                || SQLERRM);
    END get_splt_mrg_prnt_rec;

    /*+==========================================================================+
    | Procedure name                                                             |
    |     GET_SPLT_MRG_CH_REC                                                       |
    |                                                                            |
    | DESCRIPTION                                                                |
    |     Procedure to split the  record which is non-PO related to child        |
    |      records,these are merged records                                       |
    +===========================================================================*/
    PROCEDURE get_splt_mrg_ch_rec (p_mass_add_rec IN fa_massadd_prepare_pkg.mass_add_rec, p_location_id IN NUMBER, p_custodian_id IN NUMBER)
    IS
        l_mass_add_in_rec              fa_massadd_prepare_pkg.mass_add_rec := NULL;
        ln_actual_cost                 NUMBER;
        ln_period                      NUMBER;
        ln_prd_length                  NUMBER;
        ln_tot_length                  NUMBER;
        lc_child_status                VARCHAR2 (10);
        lc_child_queue                 VARCHAR2 (10);
        ln_cost                        NUMBER;
        ln_location_id                 NUMBER;
        ln_parent_fixed_assets_units   NUMBER;
        ln_merge_mass_additions_id     NUMBER;
        ln_total_actual_cost           NUMBER;
        ln_payable_actual_cost         NUMBER;
        ln_pay_period                  NUMBER;
        ln_pay_prd_length              NUMBER;
        ln_pay_tot_length              NUMBER;
        ln_total_pay_cost              NUMBER;
        ln_payable_cost                NUMBER;
        ln_parent_payables_units       NUMBER;

        CURSOR get_merge_parent_mass_id (cp_parent_mass_addition_id IN NUMBER, cp_rownum IN NUMBER)
        IS
            SELECT aa.mass_addition_id
              FROM (  SELECT mass_addition_id, ROWNUM rm
                        FROM fa_mass_additions fma
                       WHERE fma.split_parent_mass_additions_id =
                             cp_parent_mass_addition_id
                    ORDER BY mass_addition_id) aa
             WHERE aa.rm = cp_rownum;
    BEGIN
        -- Assigning input paramemeter values to local rec type variable
        l_mass_add_in_rec                     := p_mass_add_rec;
        --Start of inserting child records  if fixed_assets_units quantity is more than one
        l_mass_add_in_rec.queue_name          :=
            fa_massadd_prep_custom_pkg.lc_status_validate;
        lc_child_status                       :=
            fa_massadd_prep_custom_pkg.lc_status_merged;
        lc_child_queue                        :=
            fa_massadd_prep_custom_pkg.lc_status_validate;
        l_mass_add_in_rec.payables_units      :=
            l_mass_add_in_rec.fixed_assets_units;
        l_mass_add_in_rec.split_merged_code   := 'MC';
        l_mass_add_in_rec.merged_code         := 'MC';

        BEGIN
            UPDATE fa_mass_additions
               SET split_code = 'SP', posting_status = fa_massadd_prep_custom_pkg.lc_status_split
             WHERE mass_addition_id = l_mass_add_in_rec.mass_addition_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception occured while updating split code  '
                    || SQLERRM);
        END;

        --Number of child records to be inserted should based on the fixed assets unit of the parent record.
        BEGIN
            SELECT fixed_assets_units, payables_units
              INTO ln_parent_fixed_assets_units, ln_parent_payables_units
              FROM fa_mass_additions
             WHERE mass_addition_id =
                   l_mass_add_in_rec.parent_mass_addition_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'No data found while checking parent fixed assets units '
                    || l_mass_add_in_rec.mass_addition_id);
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception occured while checking parent fixed assets units  '
                    || SQLERRM);
        END;

        ln_cost                               := 0;
        ln_period                             := 0;
        ln_prd_length                         := 0;
        ln_tot_length                         := 0;
        ln_actual_cost                        := 0;
        ln_total_actual_cost                  := 0;
        ln_cost                               :=
              l_mass_add_in_rec.fixed_assets_cost
            / ln_parent_fixed_assets_units;
        ln_period                             := INSTR (ln_cost, '.', 1);
        --Added for payable cost
        ln_payable_cost                       := 0;
        ln_pay_period                         := 0;
        ln_pay_prd_length                     := 0;
        ln_pay_tot_length                     := 0;
        ln_payable_actual_cost                := 0;
        ln_total_pay_cost                     := 0;
        ln_payable_cost                       :=
            l_mass_add_in_rec.payables_cost / ln_parent_payables_units;
        ln_pay_period                         :=
            INSTR (ln_payable_cost, '.', 1);

        --End for payable cost
        IF ln_period != 0
        THEN
            ln_prd_length   := LENGTH (SUBSTR (ln_cost, ln_period + 1));
            ln_tot_length   := LENGTH (SUBSTR (ln_cost, 1, ln_period));
        END IF;

        IF ln_pay_period != 0
        THEN
            ln_pay_prd_length   :=
                LENGTH (SUBSTR (ln_payable_cost, ln_pay_period + 1));
            ln_pay_tot_length   :=
                LENGTH (SUBSTR (ln_payable_cost, 1, ln_pay_period));
        END IF;

        IF ln_prd_length > 2
        THEN
            ln_actual_cost   := SUBSTR (ln_cost, 1, ln_tot_length + 2);
        ELSE
            ln_actual_cost   := ln_cost;
        END IF;

        IF ln_pay_prd_length > 2
        THEN
            ln_payable_actual_cost   :=
                SUBSTR (ln_payable_cost, 1, ln_pay_tot_length + 2);
        ELSE
            ln_payable_actual_cost   := ln_payable_cost;
        END IF;

        FOR i IN 1 .. ln_parent_fixed_assets_units
        LOOP
            IF ln_prd_length > 2
            THEN
                IF i < ln_parent_fixed_assets_units
                THEN
                    ln_total_actual_cost   :=
                        ln_total_actual_cost + ln_actual_cost;
                END IF;

                IF i = ln_parent_fixed_assets_units
                THEN
                    ln_actual_cost   :=
                          l_mass_add_in_rec.fixed_assets_cost
                        - ln_total_actual_cost;
                END IF;
            END IF;

            --Added for payable
            IF ln_pay_prd_length > 2
            THEN
                IF i < ln_parent_fixed_assets_units
                THEN
                    ln_total_pay_cost   :=
                        ln_total_pay_cost + ln_payable_actual_cost;
                END IF;

                IF i = ln_parent_fixed_assets_units
                THEN
                    ln_payable_actual_cost   :=
                        l_mass_add_in_rec.payables_cost - ln_total_pay_cost;
                END IF;
            END IF;

            --End for payable
            OPEN get_merge_parent_mass_id (
                cp_parent_mass_addition_id   =>
                    l_mass_add_in_rec.parent_mass_addition_id,
                cp_rownum   => i);

            FETCH get_merge_parent_mass_id INTO ln_merge_mass_additions_id;

            CLOSE get_merge_parent_mass_id;

            --Inserting child records based on fixed asset units quantity
            BEGIN
                INSERT INTO fa_mass_additions (
                                mass_addition_id,
                                asset_number,
                                tag_number,
                                description,
                                asset_category_id,
                                manufacturer_name,
                                serial_number,
                                model_number,
                                book_type_code,
                                date_placed_in_service,
                                fixed_assets_cost,
                                payables_units,
                                fixed_assets_units,
                                payables_code_combination_id,
                                expense_code_combination_id,
                                location_id,
                                assigned_to,
                                feeder_system_name,
                                create_batch_date,
                                create_batch_id,
                                last_update_date,
                                last_updated_by,
                                reviewer_comments,
                                invoice_number,
                                invoice_line_number,
                                invoice_distribution_id,
                                vendor_number,
                                po_vendor_id,
                                po_number,
                                posting_status,
                                queue_name,
                                invoice_date,
                                invoice_created_by,
                                invoice_updated_by,
                                payables_cost,
                                invoice_id,
                                payables_batch_name,
                                depreciate_flag,
                                parent_mass_addition_id,
                                parent_asset_id,
                                split_merged_code,
                                ap_distribution_line_number,
                                post_batch_id,
                                add_to_asset_id,
                                amortize_flag,
                                new_master_flag,
                                asset_key_ccid,
                                asset_type,
                                deprn_reserve,
                                ytd_deprn,
                                beginning_nbv,
                                created_by,
                                creation_date,
                                last_update_login,
                                salvage_value,
                                accounting_date,
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
                                attribute_category_code,
                                fully_rsvd_revals_counter,
                                merge_invoice_number,
                                merge_vendor_number,
                                production_capacity,
                                reval_amortization_basis,
                                reval_reserve,
                                unit_of_measure,
                                unrevalued_cost,
                                ytd_reval_deprn_expense,
                                attribute16,
                                attribute17,
                                attribute18,
                                attribute19,
                                attribute20,
                                attribute21,
                                attribute22,
                                attribute23,
                                attribute24,
                                attribute25,
                                attribute26,
                                attribute27,
                                attribute28,
                                attribute29,
                                attribute30,
                                merged_code,
                                split_code,
                                merge_parent_mass_additions_id,
                                split_parent_mass_additions_id,
                                project_asset_line_id,
                                project_id,
                                task_id,
                                sum_units,
                                dist_name,
                                global_attribute1,
                                global_attribute2,
                                global_attribute3,
                                global_attribute4,
                                global_attribute5,
                                global_attribute6,
                                global_attribute7,
                                global_attribute8,
                                global_attribute9,
                                global_attribute10,
                                global_attribute11,
                                global_attribute12,
                                global_attribute13,
                                global_attribute14,
                                global_attribute15,
                                global_attribute16,
                                global_attribute17,
                                global_attribute18,
                                global_attribute19,
                                global_attribute20,
                                global_attribute_category,
                                CONTEXT,
                                inventorial,
                                short_fiscal_year_flag,
                                conversion_date,
                                original_deprn_start_date,
                                group_asset_id,
                                cua_parent_hierarchy_id,
                                units_to_adjust,
                                bonus_ytd_deprn,
                                bonus_deprn_reserve,
                                amortize_nbv_flag,
                                amortization_start_date,
                                transaction_type_code,
                                transaction_date,
                                warranty_id,
                                lease_id,
                                lessor_id,
                                property_type_code,
                                property_1245_1250_code,
                                in_use_flag,
                                owned_leased,
                                new_used,
                                asset_id,
                                material_indicator_flag)
                         VALUES (
                                    fa_mass_additions_s.NEXTVAL,
                                    l_mass_add_in_rec.asset_number,
                                    l_mass_add_in_rec.tag_number,
                                    l_mass_add_in_rec.description,
                                    l_mass_add_in_rec.asset_category_id,
                                    l_mass_add_in_rec.manufacturer_name,
                                    l_mass_add_in_rec.serial_number,
                                    l_mass_add_in_rec.model_number,
                                    l_mass_add_in_rec.book_type_code,
                                    l_mass_add_in_rec.date_placed_in_service,
                                    ln_actual_cost,
                                    1,
                                    1,
                                    l_mass_add_in_rec.payables_code_combination_id,
                                    l_mass_add_in_rec.expense_code_combination_id,
                                    l_mass_add_in_rec.location_id,
                                    l_mass_add_in_rec.assigned_to,
                                    l_mass_add_in_rec.feeder_system_name,
                                    l_mass_add_in_rec.create_batch_date,
                                    l_mass_add_in_rec.create_batch_id,
                                    SYSDATE,
                                    l_mass_add_in_rec.last_updated_by,
                                    l_mass_add_in_rec.reviewer_comments,
                                    l_mass_add_in_rec.invoice_number,
                                    l_mass_add_in_rec.invoice_line_number,
                                    l_mass_add_in_rec.invoice_distribution_id,
                                    l_mass_add_in_rec.vendor_number,
                                    l_mass_add_in_rec.po_vendor_id,
                                    l_mass_add_in_rec.po_number,
                                    lc_child_status,
                                    lc_child_queue,
                                    l_mass_add_in_rec.invoice_date,
                                    l_mass_add_in_rec.invoice_created_by,
                                    l_mass_add_in_rec.invoice_updated_by,
                                    ln_payable_actual_cost,
                                    --l_mass_add_in_rec.PAYABLES_COST,
                                    l_mass_add_in_rec.invoice_id,
                                    l_mass_add_in_rec.payables_batch_name,
                                    l_mass_add_in_rec.depreciate_flag,
                                    '',
                                    --l_mass_add_in_rec.PARENT_MASS_ADDITION_ID,
                                    l_mass_add_in_rec.parent_asset_id,
                                    'MC',
                                    l_mass_add_in_rec.ap_distribution_line_number,
                                    l_mass_add_in_rec.post_batch_id,
                                    l_mass_add_in_rec.add_to_asset_id,
                                    l_mass_add_in_rec.amortize_flag,
                                    l_mass_add_in_rec.new_master_flag,
                                    l_mass_add_in_rec.asset_key_ccid,
                                    l_mass_add_in_rec.asset_type,
                                    l_mass_add_in_rec.deprn_reserve,
                                    l_mass_add_in_rec.ytd_deprn,
                                    l_mass_add_in_rec.beginning_nbv,
                                    l_mass_add_in_rec.created_by,
                                    l_mass_add_in_rec.creation_date,
                                    l_mass_add_in_rec.last_update_login,
                                    l_mass_add_in_rec.salvage_value,
                                    l_mass_add_in_rec.accounting_date,
                                    l_mass_add_in_rec.attribute1,
                                    l_mass_add_in_rec.attribute2,
                                    l_mass_add_in_rec.attribute3,
                                    l_mass_add_in_rec.attribute4,
                                    l_mass_add_in_rec.attribute5,
                                    l_mass_add_in_rec.attribute6,
                                    l_mass_add_in_rec.attribute7,
                                    l_mass_add_in_rec.attribute8,
                                    l_mass_add_in_rec.attribute9,
                                    l_mass_add_in_rec.attribute10,
                                    l_mass_add_in_rec.attribute11,
                                    l_mass_add_in_rec.attribute12,
                                    l_mass_add_in_rec.attribute13,
                                    l_mass_add_in_rec.attribute14,
                                    l_mass_add_in_rec.attribute15,
                                    l_mass_add_in_rec.attribute_category_code,
                                    l_mass_add_in_rec.fully_rsvd_revals_counter,
                                    l_mass_add_in_rec.merge_invoice_number,
                                    l_mass_add_in_rec.merge_vendor_number,
                                    l_mass_add_in_rec.production_capacity,
                                    l_mass_add_in_rec.reval_amortization_basis,
                                    l_mass_add_in_rec.reval_reserve,
                                    l_mass_add_in_rec.unit_of_measure,
                                    l_mass_add_in_rec.unrevalued_cost,
                                    l_mass_add_in_rec.ytd_reval_deprn_expense,
                                    l_mass_add_in_rec.attribute16,
                                    l_mass_add_in_rec.attribute17,
                                    l_mass_add_in_rec.attribute18,
                                    l_mass_add_in_rec.attribute19,
                                    l_mass_add_in_rec.attribute20,
                                    l_mass_add_in_rec.attribute21,
                                    l_mass_add_in_rec.attribute22,
                                    l_mass_add_in_rec.attribute23,
                                    l_mass_add_in_rec.attribute24,
                                    l_mass_add_in_rec.attribute25,
                                    l_mass_add_in_rec.attribute26,
                                    l_mass_add_in_rec.attribute27,
                                    l_mass_add_in_rec.attribute28,
                                    l_mass_add_in_rec.attribute29,
                                    l_mass_add_in_rec.attribute30,
                                    l_mass_add_in_rec.merged_code,
                                    'SC',
                                    ln_merge_mass_additions_id,
                                    l_mass_add_in_rec.mass_addition_id,
                                    l_mass_add_in_rec.project_asset_line_id,
                                    l_mass_add_in_rec.project_id,
                                    l_mass_add_in_rec.task_id,
                                    'NO',
                                    l_mass_add_in_rec.dist_name,
                                    l_mass_add_in_rec.global_attribute1,
                                    l_mass_add_in_rec.global_attribute2,
                                    l_mass_add_in_rec.global_attribute3,
                                    l_mass_add_in_rec.global_attribute4,
                                    l_mass_add_in_rec.global_attribute5,
                                    l_mass_add_in_rec.global_attribute6,
                                    l_mass_add_in_rec.global_attribute7,
                                    l_mass_add_in_rec.global_attribute8,
                                    l_mass_add_in_rec.global_attribute9,
                                    l_mass_add_in_rec.global_attribute10,
                                    l_mass_add_in_rec.global_attribute11,
                                    l_mass_add_in_rec.global_attribute12,
                                    l_mass_add_in_rec.global_attribute13,
                                    l_mass_add_in_rec.global_attribute14,
                                    l_mass_add_in_rec.global_attribute15,
                                    l_mass_add_in_rec.global_attribute16,
                                    l_mass_add_in_rec.global_attribute17,
                                    l_mass_add_in_rec.global_attribute18,
                                    l_mass_add_in_rec.global_attribute19,
                                    l_mass_add_in_rec.global_attribute20,
                                    l_mass_add_in_rec.global_attribute_category,
                                    l_mass_add_in_rec.CONTEXT,
                                    l_mass_add_in_rec.inventorial,
                                    l_mass_add_in_rec.short_fiscal_year_flag,
                                    l_mass_add_in_rec.conversion_date,
                                    l_mass_add_in_rec.original_deprn_start_date,
                                    l_mass_add_in_rec.group_asset_id,
                                    l_mass_add_in_rec.cua_parent_hierarchy_id,
                                    l_mass_add_in_rec.units_to_adjust,
                                    l_mass_add_in_rec.bonus_ytd_deprn,
                                    l_mass_add_in_rec.bonus_deprn_reserve,
                                    l_mass_add_in_rec.amortize_nbv_flag,
                                    l_mass_add_in_rec.amortization_start_date,
                                    l_mass_add_in_rec.transaction_type_code,
                                    l_mass_add_in_rec.transaction_date,
                                    l_mass_add_in_rec.warranty_id,
                                    l_mass_add_in_rec.lease_id,
                                    l_mass_add_in_rec.lessor_id,
                                    l_mass_add_in_rec.property_type_code,
                                    l_mass_add_in_rec.property_1245_1250_code,
                                    l_mass_add_in_rec.in_use_flag,
                                    l_mass_add_in_rec.owned_leased,
                                    l_mass_add_in_rec.new_used,
                                    l_mass_add_in_rec.asset_id,
                                    l_mass_add_in_rec.material_indicator_flag);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception occured while inserting into fa_mass_additions table '
                        || SQLERRM);
            END;

            BEGIN
                INSERT INTO fa_massadd_distributions (massadd_dist_id,
                                                      mass_addition_id,
                                                      units,
                                                      deprn_expense_ccid,
                                                      location_id,
                                                      employee_id)
                         VALUES (
                                    fa_massadd_distributions_s.NEXTVAL,
                                    fa_mass_additions_s.CURRVAL,
                                    1,
                                    l_mass_add_in_rec.expense_code_combination_id,
                                    l_mass_add_in_rec.location_id,
                                    p_custodian_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception occured while inserting into fa_massadd_distributions table '
                        || SQLERRM);
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception occured get_splt_mrg_ch_rec procedure ' || SQLERRM);
    END get_splt_mrg_ch_rec;

    /*+==========================================================================+
    | Procedure name                                                             |
    |     GET_SPLIT_RECORDS                                                       |
    |                                                                            |
    | DESCRIPTION                                                                |
    |     Procedure to split the  record which has split merge code as SP        |
    +===========================================================================*/
    PROCEDURE get_split_records (p_mass_add_rec IN OUT NOCOPY fa_massadd_prepare_pkg.mass_add_rec, p_location_id IN NUMBER, p_custodian_id IN NUMBER)
    IS
        l_mass_add_in_rec        fa_massadd_prepare_pkg.mass_add_rec := NULL;
        ln_actual_cost           NUMBER;
        ln_period                NUMBER;
        ln_prd_length            NUMBER;
        ln_tot_length            NUMBER;
        lc_child_status          VARCHAR2 (10);
        lc_child_queue           VARCHAR2 (10);
        ln_cost                  NUMBER;
        ln_location_id           NUMBER;
        ln_total_actual_cost     NUMBER;
        ln_payable_actual_cost   NUMBER;
        ln_pay_period            NUMBER;
        ln_pay_prd_length        NUMBER;
        ln_pay_tot_length        NUMBER;
        ln_total_pay_cost        NUMBER;
        ln_payable_cost          NUMBER;
        lc_po_match_flag         VARCHAR2 (10);
    BEGIN
        -- Assigning input paramemeter values to local rec type variable
        l_mass_add_in_rec                     := p_mass_add_rec;
        --Start of inserting child records  if fixed_assets_units quantity is more than one
        l_mass_add_in_rec.posting_status      :=
            fa_massadd_prep_custom_pkg.lc_status_hold;

        IF ln_location_id IS NULL AND l_mass_add_in_rec.location_id IS NULL
        THEN
            l_mass_add_in_rec.queue_name   :=
                fa_massadd_prep_custom_pkg.lc_status_rip;
            lc_child_status   := fa_massadd_prep_custom_pkg.lc_status_rip;
            lc_child_queue    := fa_massadd_prep_custom_pkg.lc_status_rip;
        ELSE
            l_mass_add_in_rec.posting_status   :=
                fa_massadd_prep_custom_pkg.lc_status_split;
            l_mass_add_in_rec.queue_name   :=
                fa_massadd_prep_custom_pkg.lc_status_post;
            lc_child_status   := fa_massadd_prep_custom_pkg.lc_status_post;
            lc_child_queue    := fa_massadd_prep_custom_pkg.lc_status_post;
        END IF;

        l_mass_add_in_rec.payables_units      :=
            l_mass_add_in_rec.fixed_assets_units;
        l_mass_add_in_rec.split_merged_code   := 'SP';
        l_mass_add_in_rec.split_code          := 'SP';
        ln_cost                               := 0;
        ln_period                             := 0;
        ln_prd_length                         := 0;
        ln_tot_length                         := 0;
        ln_actual_cost                        := 0;
        ln_total_actual_cost                  := 0;
        ln_cost                               :=
              l_mass_add_in_rec.fixed_assets_cost
            / l_mass_add_in_rec.fixed_assets_units;
        ln_period                             := INSTR (ln_cost, '.', 1);
        --Added for payable cost
        ln_payable_cost                       := 0;
        ln_pay_period                         := 0;
        ln_pay_prd_length                     := 0;
        ln_pay_tot_length                     := 0;
        ln_payable_actual_cost                := 0;
        ln_total_pay_cost                     := 0;
        ln_payable_cost                       :=
              l_mass_add_in_rec.payables_cost
            / l_mass_add_in_rec.payables_units;
        ln_pay_period                         :=
            INSTR (ln_payable_cost, '.', 1);

        --End for payable cost
        IF ln_period != 0
        THEN
            ln_prd_length   := LENGTH (SUBSTR (ln_cost, ln_period + 1));
            ln_tot_length   := LENGTH (SUBSTR (ln_cost, 1, ln_period));
        END IF;

        IF ln_prd_length > 2
        THEN
            ln_actual_cost   := SUBSTR (ln_cost, 1, ln_tot_length + 2);
        ELSE
            ln_actual_cost   := ln_cost;
        END IF;

        FOR i IN 1 .. l_mass_add_in_rec.fixed_assets_units
        LOOP
            IF ln_prd_length > 2
            THEN
                IF i < l_mass_add_in_rec.fixed_assets_units
                THEN
                    ln_total_actual_cost   :=
                        ln_total_actual_cost + ln_actual_cost;
                END IF;

                IF i = l_mass_add_in_rec.fixed_assets_units
                THEN
                    ln_actual_cost   :=
                          l_mass_add_in_rec.fixed_assets_cost
                        - ln_total_actual_cost;
                END IF;
            END IF;

            --Added for payable
            IF ln_pay_period != 0
            THEN
                ln_pay_prd_length   :=
                    LENGTH (SUBSTR (ln_payable_cost, ln_pay_period + 1));
                ln_pay_tot_length   :=
                    LENGTH (SUBSTR (ln_payable_cost, 1, ln_pay_period));
            END IF;

            IF ln_pay_prd_length > 2
            THEN
                ln_payable_actual_cost   :=
                    SUBSTR (ln_payable_cost, 1, ln_pay_tot_length + 2);
            ELSE
                ln_payable_actual_cost   := ln_payable_cost;
            END IF;

            IF ln_pay_prd_length > 2
            THEN
                IF i < l_mass_add_in_rec.payables_units
                THEN
                    ln_total_pay_cost   :=
                        ln_total_pay_cost + ln_payable_actual_cost;
                END IF;

                IF i = l_mass_add_in_rec.payables_units
                THEN
                    ln_payable_actual_cost   :=
                        l_mass_add_in_rec.payables_cost - ln_total_pay_cost;
                END IF;
            END IF;

            --End for payable

            --Inserting child records based on fixed asset units quantity
            BEGIN
                INSERT INTO fa_mass_additions (
                                mass_addition_id,
                                asset_number,
                                tag_number,
                                description,
                                asset_category_id,
                                manufacturer_name,
                                serial_number,
                                model_number,
                                book_type_code,
                                date_placed_in_service,
                                fixed_assets_cost,
                                payables_units,
                                fixed_assets_units,
                                payables_code_combination_id,
                                expense_code_combination_id,
                                location_id,
                                assigned_to,
                                feeder_system_name,
                                create_batch_date,
                                create_batch_id,
                                last_update_date,
                                last_updated_by,
                                reviewer_comments,
                                invoice_number,
                                invoice_line_number,
                                invoice_distribution_id,
                                vendor_number,
                                po_vendor_id,
                                po_number,
                                posting_status,
                                queue_name,
                                invoice_date,
                                invoice_created_by,
                                invoice_updated_by,
                                payables_cost,
                                invoice_id,
                                payables_batch_name,
                                depreciate_flag,
                                parent_mass_addition_id,
                                parent_asset_id,
                                split_merged_code,
                                ap_distribution_line_number,
                                post_batch_id,
                                add_to_asset_id,
                                amortize_flag,
                                new_master_flag,
                                asset_key_ccid,
                                asset_type,
                                deprn_reserve,
                                ytd_deprn,
                                beginning_nbv,
                                created_by,
                                creation_date,
                                last_update_login,
                                salvage_value,
                                accounting_date,
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
                                attribute_category_code,
                                fully_rsvd_revals_counter,
                                merge_invoice_number,
                                merge_vendor_number,
                                production_capacity,
                                reval_amortization_basis,
                                reval_reserve,
                                unit_of_measure,
                                unrevalued_cost,
                                ytd_reval_deprn_expense,
                                attribute16,
                                attribute17,
                                attribute18,
                                attribute19,
                                attribute20,
                                attribute21,
                                attribute22,
                                attribute23,
                                attribute24,
                                attribute25,
                                attribute26,
                                attribute27,
                                attribute28,
                                attribute29,
                                attribute30,
                                merged_code,
                                split_code,
                                merge_parent_mass_additions_id,
                                split_parent_mass_additions_id,
                                project_asset_line_id,
                                project_id,
                                task_id,
                                sum_units,
                                dist_name,
                                global_attribute1,
                                global_attribute2,
                                global_attribute3,
                                global_attribute4,
                                global_attribute5,
                                global_attribute6,
                                global_attribute7,
                                global_attribute8,
                                global_attribute9,
                                global_attribute10,
                                global_attribute11,
                                global_attribute12,
                                global_attribute13,
                                global_attribute14,
                                global_attribute15,
                                global_attribute16,
                                global_attribute17,
                                global_attribute18,
                                global_attribute19,
                                global_attribute20,
                                global_attribute_category,
                                CONTEXT,
                                inventorial,
                                short_fiscal_year_flag,
                                conversion_date,
                                original_deprn_start_date,
                                group_asset_id,
                                cua_parent_hierarchy_id,
                                units_to_adjust,
                                bonus_ytd_deprn,
                                bonus_deprn_reserve,
                                amortize_nbv_flag,
                                amortization_start_date,
                                transaction_type_code,
                                transaction_date,
                                warranty_id,
                                lease_id,
                                lessor_id,
                                property_type_code,
                                property_1245_1250_code,
                                in_use_flag,
                                owned_leased,
                                new_used,
                                asset_id,
                                material_indicator_flag)
                         VALUES (
                                    fa_mass_additions_s.NEXTVAL,
                                    l_mass_add_in_rec.asset_number,
                                    NULL,
                                    l_mass_add_in_rec.description,
                                    l_mass_add_in_rec.asset_category_id,
                                    l_mass_add_in_rec.manufacturer_name,
                                    NULL,
                                    l_mass_add_in_rec.model_number,
                                    l_mass_add_in_rec.book_type_code,
                                    l_mass_add_in_rec.date_placed_in_service,
                                    ln_actual_cost,
                                    1,
                                    1,
                                    l_mass_add_in_rec.payables_code_combination_id,
                                    l_mass_add_in_rec.expense_code_combination_id,
                                    l_mass_add_in_rec.location_id,
                                    l_mass_add_in_rec.assigned_to,
                                    l_mass_add_in_rec.feeder_system_name,
                                    l_mass_add_in_rec.create_batch_date,
                                    l_mass_add_in_rec.create_batch_id,
                                    SYSDATE,
                                    l_mass_add_in_rec.last_updated_by,
                                    l_mass_add_in_rec.reviewer_comments,
                                    l_mass_add_in_rec.invoice_number,
                                    l_mass_add_in_rec.invoice_line_number,
                                    l_mass_add_in_rec.invoice_distribution_id,
                                    l_mass_add_in_rec.vendor_number,
                                    l_mass_add_in_rec.po_vendor_id,
                                    l_mass_add_in_rec.po_number,
                                    lc_child_status,
                                    lc_child_queue,
                                    l_mass_add_in_rec.invoice_date,
                                    l_mass_add_in_rec.invoice_created_by,
                                    l_mass_add_in_rec.invoice_updated_by,
                                    ln_payable_actual_cost,
                                    --l_mass_add_in_rec.PAYABLES_COST,
                                    l_mass_add_in_rec.invoice_id,
                                    l_mass_add_in_rec.payables_batch_name,
                                    l_mass_add_in_rec.depreciate_flag,
                                    l_mass_add_in_rec.parent_mass_addition_id,
                                    l_mass_add_in_rec.parent_asset_id,
                                    'SC',
                                    l_mass_add_in_rec.ap_distribution_line_number,
                                    l_mass_add_in_rec.post_batch_id,
                                    l_mass_add_in_rec.add_to_asset_id,
                                    l_mass_add_in_rec.amortize_flag,
                                    l_mass_add_in_rec.new_master_flag,
                                    l_mass_add_in_rec.asset_key_ccid,
                                    l_mass_add_in_rec.asset_type,
                                    l_mass_add_in_rec.deprn_reserve,
                                    l_mass_add_in_rec.ytd_deprn,
                                    l_mass_add_in_rec.beginning_nbv,
                                    l_mass_add_in_rec.created_by,
                                    l_mass_add_in_rec.creation_date,
                                    l_mass_add_in_rec.last_update_login,
                                    l_mass_add_in_rec.salvage_value,
                                    l_mass_add_in_rec.accounting_date,
                                    l_mass_add_in_rec.attribute1,
                                    l_mass_add_in_rec.attribute2,
                                    l_mass_add_in_rec.attribute3,
                                    l_mass_add_in_rec.attribute4,
                                    l_mass_add_in_rec.attribute5,
                                    l_mass_add_in_rec.attribute6,
                                    l_mass_add_in_rec.attribute7,
                                    l_mass_add_in_rec.attribute8,
                                    l_mass_add_in_rec.attribute9,
                                    l_mass_add_in_rec.attribute10,
                                    l_mass_add_in_rec.attribute11,
                                    l_mass_add_in_rec.attribute12,
                                    l_mass_add_in_rec.attribute13,
                                    l_mass_add_in_rec.attribute14,
                                    l_mass_add_in_rec.attribute15,
                                    l_mass_add_in_rec.attribute_category_code,
                                    l_mass_add_in_rec.fully_rsvd_revals_counter,
                                    l_mass_add_in_rec.merge_invoice_number,
                                    l_mass_add_in_rec.merge_vendor_number,
                                    l_mass_add_in_rec.production_capacity,
                                    l_mass_add_in_rec.reval_amortization_basis,
                                    l_mass_add_in_rec.reval_reserve,
                                    l_mass_add_in_rec.unit_of_measure,
                                    l_mass_add_in_rec.unrevalued_cost,
                                    l_mass_add_in_rec.ytd_reval_deprn_expense,
                                    l_mass_add_in_rec.attribute16,
                                    l_mass_add_in_rec.attribute17,
                                    l_mass_add_in_rec.attribute18,
                                    l_mass_add_in_rec.attribute19,
                                    l_mass_add_in_rec.attribute20,
                                    l_mass_add_in_rec.attribute21,
                                    l_mass_add_in_rec.attribute22,
                                    l_mass_add_in_rec.attribute23,
                                    l_mass_add_in_rec.attribute24,
                                    l_mass_add_in_rec.attribute25,
                                    l_mass_add_in_rec.attribute26,
                                    l_mass_add_in_rec.attribute27,
                                    l_mass_add_in_rec.attribute28,
                                    l_mass_add_in_rec.attribute29,
                                    l_mass_add_in_rec.attribute30,
                                    l_mass_add_in_rec.merged_code,
                                    'SC',
                                    '',
                                    --l_mass_add_in_rec.MERGE_PARENT_MASS_ADDITIONS_ID,
                                    l_mass_add_in_rec.mass_addition_id,
                                    l_mass_add_in_rec.project_asset_line_id,
                                    l_mass_add_in_rec.project_id,
                                    l_mass_add_in_rec.task_id,
                                    'NO',
                                    l_mass_add_in_rec.dist_name,
                                    l_mass_add_in_rec.global_attribute1,
                                    l_mass_add_in_rec.global_attribute2,
                                    l_mass_add_in_rec.global_attribute3,
                                    l_mass_add_in_rec.global_attribute4,
                                    l_mass_add_in_rec.global_attribute5,
                                    l_mass_add_in_rec.global_attribute6,
                                    l_mass_add_in_rec.global_attribute7,
                                    l_mass_add_in_rec.global_attribute8,
                                    l_mass_add_in_rec.global_attribute9,
                                    l_mass_add_in_rec.global_attribute10,
                                    l_mass_add_in_rec.global_attribute11,
                                    l_mass_add_in_rec.global_attribute12,
                                    l_mass_add_in_rec.global_attribute13,
                                    l_mass_add_in_rec.global_attribute14,
                                    l_mass_add_in_rec.global_attribute15,
                                    l_mass_add_in_rec.global_attribute16,
                                    l_mass_add_in_rec.global_attribute17,
                                    l_mass_add_in_rec.global_attribute18,
                                    l_mass_add_in_rec.global_attribute19,
                                    l_mass_add_in_rec.global_attribute20,
                                    l_mass_add_in_rec.global_attribute_category,
                                    l_mass_add_in_rec.CONTEXT,
                                    l_mass_add_in_rec.inventorial,
                                    l_mass_add_in_rec.short_fiscal_year_flag,
                                    l_mass_add_in_rec.conversion_date,
                                    l_mass_add_in_rec.original_deprn_start_date,
                                    l_mass_add_in_rec.group_asset_id,
                                    l_mass_add_in_rec.cua_parent_hierarchy_id,
                                    l_mass_add_in_rec.units_to_adjust,
                                    l_mass_add_in_rec.bonus_ytd_deprn,
                                    l_mass_add_in_rec.bonus_deprn_reserve,
                                    l_mass_add_in_rec.amortize_nbv_flag,
                                    l_mass_add_in_rec.amortization_start_date,
                                    l_mass_add_in_rec.transaction_type_code,
                                    l_mass_add_in_rec.transaction_date,
                                    l_mass_add_in_rec.warranty_id,
                                    l_mass_add_in_rec.lease_id,
                                    l_mass_add_in_rec.lessor_id,
                                    l_mass_add_in_rec.property_type_code,
                                    l_mass_add_in_rec.property_1245_1250_code,
                                    l_mass_add_in_rec.in_use_flag,
                                    l_mass_add_in_rec.owned_leased,
                                    l_mass_add_in_rec.new_used,
                                    l_mass_add_in_rec.asset_id,
                                    l_mass_add_in_rec.material_indicator_flag);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception occured while insering into fa_mass_additions table '
                        || SQLERRM);
            END;

            BEGIN
                INSERT INTO fa_massadd_distributions (massadd_dist_id,
                                                      mass_addition_id,
                                                      units,
                                                      deprn_expense_ccid,
                                                      location_id,
                                                      employee_id)
                         VALUES (
                                    fa_massadd_distributions_s.NEXTVAL,
                                    fa_mass_additions_s.CURRVAL,
                                    1,
                                    l_mass_add_in_rec.expense_code_combination_id,
                                    l_mass_add_in_rec.location_id,
                                    p_custodian_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception occured while inserting into fa_massadd_distributions table '
                        || SQLERRM);
            END;
        END LOOP;

        COMMIT;
        p_mass_add_rec                        := l_mass_add_in_rec;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception occured get_split_records procedure ' || SQLERRM);
    END get_split_records;
END xxd_massadd_prep_cust_pkg;
/
