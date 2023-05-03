--
-- XXDO_INV_ITEM_ENABLE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INV_ITEM_ENABLE_PKG"
AS
    /******************************************************************************
       NAME:       xxdo_inv_item_enable_pkg
       PURPOSE:    This package contains procedures for One time Item Transmission

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        21-Jul-16   SuneraTech       Initial Creation.
       1.1       25-Aug-16    Sunera Tech      Fix for duplicate item issue
       1.2       28-Mar-16    Bala Murugesan   Modified to include Reprocess Mode
    ******************************************************************************/

    --Global Variables-----
    c_num_debug              NUMBER := 0;
    g_num_request_id         NUMBER := fnd_global.conc_request_id;
    g_item_request_ids_tab   tabtype_id;
    g_item_batch_ids_tab     tabtype_id;
    g_num_operating_unit     NUMBER := fnd_profile.VALUE ('ORG_ID');
    g_chr_status             VARCHAR2 (100) := 'UNPROCESSED';
    g_num_user_id            NUMBER := fnd_global.user_id;
    g_num_resp_id            NUMBER := fnd_global.resp_id;
    g_num_login_id           NUMBER := fnd_global.login_id;
    g_process_step           VARCHAR2 (4) := '0000';

    gv_brand_id              VARCHAR2 (150) := '-1';
    gn_cost_acct             NUMBER := -1;
    gn_sales_acct            NUMBER := -1;
    gn_cost_new_ccid         NUMBER := -1;
    gn_sales_new_ccid        NUMBER := -1;
    gv_cost_required         VARCHAR2 (1) := NULL;

    --------------------------------------------------------------------------------
    -- Procedure  : msg
    -- Description: procedure to print debug messages
    --------------------------------------------------------------------------------
    PROCEDURE msg (in_var_message IN VARCHAR2)
    IS
    BEGIN
        IF c_num_debug = 1
        THEN
            fnd_file.put_line (fnd_file.LOG, in_var_message);
        END IF;
    END msg;

    -- ***************************************************************************
    --
    -- Package Name :  xxdo_inv_item_conv_pkg
    -- PROCEDURE Name :main_extract
    -- Description  :  This is procedure body to insert valid items into the
    --                 staging table
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- DATE          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    --
    -- ***************************************************************************
    PROCEDURE main_extract (p_out_var_errbuf OUT VARCHAR2, p_out_var_retcode OUT NUMBER, p_in_var_source IN VARCHAR2 DEFAULT 'US1', p_in_var_dest IN VARCHAR2, p_in_var_brand IN VARCHAR2, p_in_var_division IN VARCHAR2, p_in_season IN VARCHAR2, p_in_var_mode IN VARCHAR2 DEFAULT 'Copy', p_debug_level IN VARCHAR2, p_in_var_batch_size IN NUMBER, p_in_style IN VARCHAR2, p_in_color IN VARCHAR2, p_in_size IN VARCHAR2, p_in_include_sample IN VARCHAR2 DEFAULT 'N', p_in_include_bgrade IN VARCHAR2 DEFAULT 'N'
                            , p_in_include_org_cats IN VARCHAR2 DEFAULT 'Y')
    AS
        CURSOR cur_item IS
            SELECT mp.organization_id
                       wh_id,
                   msi.inventory_item_id
                       inventory_item_id,
                   mp.organization_code
                       warehouse_code,
                   msi.segment1
                       item_number,
                   msi.description
                       host_description,
                   --                     apps.xxdo_iid_to_serial (msi.inventory_item_id,
                   --                                              msi.organization_id)
                   --                         serial_control,
                   msi.primary_uom_code
                       uom,
                   xciv.style_number
                       style_code,
                   xciv.style_desc
                       style_name,
                   xciv.color_code
                       color_code,
                   xciv.color_desc
                       color_name,
                   msi.attribute27
                       size_code,
                   msi.attribute27
                       size_name,
                   msi.attribute11
                       upc,
                   DECODE (msi.attribute11,
                           NULL, NULL,
                           '''' || msi.attribute11 || '''')
                       upc_rep,
                   NVL (msi.unit_weight, 0)
                       each_weight,
                   NVL (msi.unit_length, 0)
                       each_length,
                   NVL (msi.unit_width, 0)
                       each_width,
                   NVL (msi.unit_height, 0)
                       each_height,
                   mc.segment1
                       brand_code,
                   NULL
                       coo,                                        --COO_BLANK
                   msi.item_type
                       inventory_type,
                   (SELECT meaning
                      FROM apps.fnd_lookup_values
                     WHERE     lookup_type LIKE 'ITEM_TYPE'
                           AND LANGUAGE = 'US'
                           AND lookup_code = msi.item_type)
                       inventory_type_rep,
                   msi.shelf_life_days
                       shelf_life,
                   1
                       alt_item_number,
                   mc.segment2
                       gender,
                   mc.segment3
                       product_class,
                   mc.segment4
                       product_category,
                   msi.inventory_item_status_code
                       host_status,
                   msi.attribute1
                       intro_season,
                   msi.attribute1
                       last_active_season,
                   msi.purchasing_item_flag,
                   msi.summary_flag,
                   msi.enabled_flag,
                   mp.sales_account,
                   mp.cost_of_sales_account,
                   msi.creation_date,
                   NVL (conversion_rate, 0)
                       unit_per_case,
                   NVL (LENGTH, 0)
                       case_length,
                   NVL (width, 0)
                       case_width,
                   NVL (height, 0)
                       case_height,
                   NVL (conversion_rate, 0) * NVL (msi.unit_weight, 0)
                       case_weight,
                   NVL (
                       NVL (
                           (SELECT mcb.segment1 hts_code
                              FROM apps.mtl_categories_b mcb, apps.mtl_item_categories mic2, apps.mtl_category_sets mcs
                             WHERE     mic2.category_set_id =
                                       mcs.category_set_id
                                   AND mic2.category_id = mcb.category_id
                                   AND mic2.organization_id =
                                       msi.organization_id
                                   AND mic2.inventory_item_id =
                                       msi.inventory_item_id
                                   AND mcb.structure_id = mcs.structure_id
                                   AND mcs.category_set_name = 'TARRIF CODE'),
                           (SELECT tag
                              FROM apps.fnd_lookup_values
                             WHERE     lookup_type = 'XXDO_DC2_HTS_CODE'
                                   AND LANGUAGE = 'US'
                                   AND lookup_code = xciv.style_number)),
                       NULL)
                       hts_code,
                   msi.list_price_per_unit,
                   DECODE (msi.item_type,
                           'BGRADE', NULL,
                           msi.preprocessing_lead_time)
                       preprocessing_lead_time,
                   DECODE (msi.item_type, 'BGRADE', NULL, msi.full_lead_time)
                       full_lead_time,
                   DECODE (msi.item_type,
                           'BGRADE', NULL,
                           msi.postprocessing_lead_time)
                       postprocessing_lead_time,
                   DECODE (msi.item_type,
                           'BGRADE', NULL,
                           msi.cumulative_total_lead_time)
                       cumulative_total_lead_time,
                   (SELECT mc_p.category_id
                      FROM mtl_categories mc_p, mtl_item_categories mic_p, mtl_category_sets mcs_p
                     WHERE     mcs_p.category_set_name = 'PRODUCTION_LINE'
                           AND mcs_p.structure_id = mc_p.structure_id
                           AND mcs_p.category_set_id = mic_p.category_set_id
                           AND mc_p.category_id = mic_p.category_id
                           AND mic_p.inventory_item_id =
                               msi.inventory_item_id
                           AND mic_p.organization_id = msi.organization_id
                           AND NVL (mc_p.enabled_flag, 'N') = 'Y'
                           AND NVL (mc_p.disable_date, SYSDATE + 1) > SYSDATE)
                       prod_line_cat_id,
                   (SELECT mc_t.category_id
                      FROM mtl_categories mc_t, mtl_item_categories mic_t, mtl_category_sets mcs_t
                     WHERE     mcs_t.category_set_name = 'TARRIF CODE'
                           AND mcs_t.structure_id = mc_t.structure_id
                           AND mcs_t.category_set_id = mic_t.category_set_id
                           AND mc_t.category_id = mic_t.category_id
                           AND mic_t.inventory_item_id =
                               msi.inventory_item_id
                           AND mic_t.organization_id = msi.organization_id
                           AND NVL (mc_t.enabled_flag, 'N') = 'Y'
                           AND NVL (mc_t.disable_date, SYSDATE + 1) > SYSDATE)
                       tarrif_code_cat_id
              FROM apps.mtl_parameters mp, apps.mtl_system_items_b msi, apps.mtl_categories_b mc,
                   apps.mtl_item_categories mic, apps.mtl_category_sets mcs, apps.mtl_uom_conversions muc,
                   apps.xxd_common_items_v xciv
             WHERE     mp.organization_code = p_in_var_source
                   AND mp.organization_id = msi.organization_id
                   AND msi.organization_id = mic.organization_id
                   AND mic.inventory_item_id = msi.inventory_item_id
                   AND mcs.category_set_id = mic.category_set_id
                   AND mcs.category_set_id = 1
                   --              AND msi.inventory_item_status_code IN
                   --                                                ('Active', 'NAB', 'CloseOut')
                   AND mic.inventory_item_id = msi.inventory_item_id
                   AND xciv.inventory_item_id = msi.inventory_item_id
                   AND xciv.organization_id = msi.organization_id
                   AND xciv.category_set_id = mcs.category_set_id
                   AND xciv.category_id = mc.category_id
                   AND mc.category_id = mic.category_id
                   AND UPPER (mc.segment1) = UPPER (p_in_var_brand)
                   AND UPPER (mc.segment2) =
                       NVL (
                           DECODE (UPPER (p_in_var_division),
                                   'ALL', UPPER (mc.segment2),
                                   UPPER (p_in_var_division)),
                           UPPER (mc.segment2))
                   AND xciv.style_number =
                       NVL (p_in_style, xciv.style_number)
                   AND xciv.color_code = NVL (p_in_color, xciv.color_code)
                   AND msi.attribute27 = NVL (p_in_size, msi.attribute27)
                   AND msi.attribute1 = NVL (p_in_season, msi.attribute1)
                   AND msi.inventory_item_id = muc.inventory_item_id(+)
                   AND muc.unit_of_measure(+) = 'Case'
                   AND msi.item_type IN
                           (SELECT lookup_code
                              FROM apps.fnd_lookup_values
                             WHERE     lookup_type LIKE 'ITEM_TYPE'
                                   AND LANGUAGE = 'US'
                                   AND lookup_code NOT IN
                                           ('SAMPLE', 'BGRADE')
                            UNION ALL
                            SELECT 'SAMPLE'
                              FROM DUAL
                             WHERE p_in_include_sample = 'Y'
                            UNION ALL
                            SELECT 'BGRADE'
                              FROM DUAL
                             WHERE p_in_include_bgrade = 'Y');

        --ORDER BY wh_id, inventory_item_id;

        CURSOR cur_stg IS
            SELECT DISTINCT batch_id
              FROM apps.xxdo_inv_item_enbl_stg
             WHERE request_id = g_num_request_id;

        CURSOR cur_output IS
            SELECT stg.*, msib1.inventory_item_status_code
              FROM apps.xxdo_inv_item_enbl_stg stg, apps.mtl_system_items_b msib1
             WHERE     stg.request_id = g_num_request_id
                   AND msib1.inventory_item_id = stg.inventory_item_id
                   AND msib1.organization_id = stg.dest_wh_id;

        CURSOR cur_cat_stg IS
            SELECT DISTINCT batch_id
              FROM apps.xxdo_inv_item_enbl_stg
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND (prod_line_category_id IS NOT NULL OR tarrif_code_category_id IS NOT NULL);

        l_chr_req_failure           VARCHAR2 (1) := 'N';
        l_chr_phase                 VARCHAR2 (100) := NULL;
        l_chr_status                VARCHAR2 (100) := NULL;
        l_chr_dev_phase             VARCHAR2 (100) := NULL;
        l_chr_dev_status            VARCHAR2 (100) := NULL;
        l_chr_message               VARCHAR2 (1000) := NULL;
        lv_output_record            VARCHAR2 (32767);
        ln_set_process_id           NUMBER := 0;
        ln_batch_size               NUMBER := 1000;
        ln_total_count              NUMBER;
        ln_no_of_batches            NUMBER;
        l_bol_req_status            BOOLEAN;
        ln_or_id                    NUMBER;
        ln_mas_or_id                NUMBER;
        l_num_count                 NUMBER := 0;
        l_num_batch_id              NUMBER := 0;
        l_num_master_org            NUMBER := 0;
        i                           NUMBER;
        l_chr_valid_item_flag       VARCHAR2 (1) := 'N';
        l_num_value                 NUMBER;
        l_num_cogs_ccid_sample      NUMBER := NULL;
        l_num_sales_ccid_sample     NUMBER := NULL;
        l_num_exp_ccid_sample       NUMBER := NULL;
        l_num_cogs_ccid_regular     NUMBER := NULL;
        l_num_sales_ccid_regular    NUMBER := NULL;
        l_num_exp_ccid_regular      NUMBER := NULL;
        l_org_exists                VARCHAR2 (1) := 'N';
        lv_conv_type                VARCHAR2 (20);
        lv_to_curr                  VARCHAR2 (5) := NULL;
        l_from_currency             VARCHAR2 (5);
        l_conversion_rate           NUMBER;
        l_new_list_price            NUMBER;
        l_request_id                NUMBER;
        l_region                    apps.mtl_parameters.attribute1%TYPE;
        l_planner_code              apps.mtl_system_items_b.planner_code%TYPE;
        lv_template_name            fnd_lookup_values.description%TYPE;
        lv_life_cycle               fnd_lookup_values.attribute1%TYPE;
        lv_cost_required            VARCHAR2 (1);
        lv_errbuf                   VARCHAR2 (2000);
        lv_retcode                  VARCHAR2 (30);
        lv_item_status              VARCHAR2 (30);
        lv_prod_line_cat_set_id     NUMBER;
        lv_tarrif_code_cat_set_id   NUMBER;
    BEGIN
        g_process_step   := '0010';
        fnd_file.put_line (
            fnd_file.LOG,
               'Main program started for Item Conv Interface:'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, 'Input Parameters:');
        fnd_file.put_line (fnd_file.LOG, 'Source : ' || p_in_var_source);
        fnd_file.put_line (fnd_file.LOG, 'Destination : ' || p_in_var_dest);
        fnd_file.put_line (fnd_file.LOG, 'Brand : ' || p_in_var_brand);
        fnd_file.put_line (fnd_file.LOG, 'Season : ' || p_in_season);
        fnd_file.put_line (fnd_file.LOG, 'Mode : ' || p_in_var_mode);
        fnd_file.put_line (fnd_file.LOG, 'Debug Flag : ' || p_debug_level);
        fnd_file.put_line (fnd_file.LOG,
                           'Batch Size : ' || p_in_var_batch_size);
        fnd_file.put_line (fnd_file.LOG, 'Style : ' || p_in_style);
        fnd_file.put_line (fnd_file.LOG, 'Color : ' || p_in_color);
        fnd_file.put_line (fnd_file.LOG, 'Brand : ' || p_in_color);
        fnd_file.put_line (fnd_file.LOG, 'Size : ' || p_in_size);
        fnd_file.put_line (fnd_file.LOG,
                           'Include Samples : ' || p_in_include_sample);
        fnd_file.put_line (fnd_file.LOG,
                           'Include Bgrades : ' || p_in_include_bgrade);

        BEGIN
            SELECT 'Y'
              INTO gv_cost_required
              FROM fnd_lookup_values
             WHERE     lookup_type = 'XXDO_ORG_LIST_INCL_COSTING'
                   AND language = 'US'
                   AND description = p_in_var_dest;
        EXCEPTION
            WHEN OTHERS
            THEN
                gv_cost_required   := 'N';
        END;



        IF p_in_var_mode = 'Extract'
        THEN
            fnd_file.put_line (
                fnd_file.output,
                   'Target Org'
                || CHR (9)
                || 'Item Number'
                || CHR (9)
                || 'Item Description'
                || CHR (9)
                || 'UOM'
                || CHR (9)
                || 'Style Code'
                || CHR (9)
                || 'Style Name'
                || CHR (9)
                || 'Color Code'
                || CHR (9)
                || 'Color Name'
                || CHR (9)
                || 'Size Code'
                || CHR (9)
                || 'Size Name'
                || CHR (9)
                || 'UPC'
                || CHR (9)
                || 'Item Type'
                || CHR (9)
                || 'Brand'
                || CHR (9)
                || 'Division'
                || CHR (9)
                || 'Department'
                || CHR (9)
                || 'Class'
                || CHR (9)
                || 'Season'
                || CHR (9)
                || 'Item Status - Source Org');


            FOR rec_cur_item IN cur_item
            LOOP
                lv_output_record   :=
                       --  rec_cur_item.warehouse_code
                       p_in_var_dest
                    || CHR (9)
                    || rec_cur_item.item_number
                    || CHR (9)
                    || rec_cur_item.host_description
                    || CHR (9)
                    || rec_cur_item.uom
                    || CHR (9)
                    || rec_cur_item.style_code
                    || CHR (9)
                    || rec_cur_item.style_name
                    || CHR (9)
                    || rec_cur_item.color_code
                    || CHR (9)
                    || rec_cur_item.color_name
                    || CHR (9)
                    || ''''
                    || rec_cur_item.size_code
                    || ''''
                    || CHR (9)
                    || ''''
                    || rec_cur_item.size_name
                    || ''''
                    || CHR (9)
                    || rec_cur_item.upc_rep
                    || CHR (9)
                    || rec_cur_item.inventory_type_rep
                    || CHR (9)
                    || rec_cur_item.brand_code
                    || CHR (9)
                    || rec_cur_item.gender
                    || CHR (9)
                    || rec_cur_item.product_class
                    || CHR (9)
                    || rec_cur_item.product_category
                    || CHR (9)
                    || rec_cur_item.last_active_season
                    || CHR (9)
                    || rec_cur_item.host_status;
                fnd_file.put_line (fnd_file.output, lv_output_record);
            END LOOP;
        ELSIF p_in_var_mode = 'Activate'
        THEN
            IF gv_cost_required = 'Y'
            THEN -- Only if cost elements are required for the destination org, the activate mode is valid
                activate_items (p_out_var_errbuf      => lv_errbuf,
                                p_out_var_retcode     => lv_retcode,
                                p_in_var_source       => p_in_var_source,
                                p_in_var_dest         => p_in_var_dest,
                                p_in_var_brand        => p_in_var_brand,
                                p_in_var_division     => p_in_var_division,
                                p_in_season           => p_in_season,
                                p_debug_level         => p_debug_level,
                                p_in_var_batch_size   => p_in_var_batch_size,
                                p_in_style            => p_in_style,
                                p_in_color            => p_in_color,
                                p_in_size             => p_in_size,
                                p_in_include_sample   => p_in_include_sample,
                                p_in_include_bgrade   => p_in_include_bgrade);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Activate more is invalid for the Org : '
                    || p_in_var_dest
                    || 'since cost elements are not required for this org');
            END IF;
        ELSE                              -- If mode is Copy, assign the items
            BEGIN
                g_process_step   := '0020';

                --      fnd_file.put_line (fnd_file.LOG,'Reached here : 20');
                SELECT organization_id, master_organization_id, attribute1
                  INTO ln_or_id, l_num_master_org, l_region
                  FROM apps.mtl_parameters
                 WHERE organization_code = p_in_var_dest;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --         fnd_file.put_line (fnd_file.LOG,'Reached here : 30');
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error at Step: ' || g_process_step);
                    g_process_step     := '0030';
                    ln_or_id           := -1;
                    l_num_master_org   := -1;
            END;

            --
            -- ---------------------------------------------------
            -- Get the planner code for the region -- Start
            -- ---------------------------------------------------
            BEGIN
                --fnd_file.put_line (fnd_file.LOG,'Reached here : 0035');
                --fnd_file.put_line (fnd_file.LOG,'Region is : '||l_region);
                SELECT UPPER (meaning)
                  INTO l_planner_code
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'DO_PLANNER_CODE'
                       AND language = 'US'
                       AND description = l_region
                       AND tag = p_in_var_brand;
            --        fnd_file.put_line(fnd_file.LOG,'Planner code is: '||l_planner_code);

            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Planner code is not found ');
                    NULL;
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error while deriving Planner Code');
                    NULL;
            END;

            -- -------------------------------------------------
            -- Get the planner code for the region -- End
            -- -------------------------------------------------

            IF p_in_include_org_cats = 'Y'
            THEN
                BEGIN
                    SELECT category_set_id
                      INTO lv_prod_line_cat_set_id
                      FROM mtl_category_sets mcs
                     WHERE category_set_name = 'PRODUCTION_LINE';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_prod_line_cat_set_id   := NULL;
                END;

                BEGIN
                    SELECT category_set_id
                      INTO lv_tarrif_code_cat_set_id
                      FROM mtl_category_sets mcs
                     WHERE category_set_name = 'TARRIF CODE';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_tarrif_code_cat_set_id   := NULL;
                END;
            END IF;


            IF p_debug_level = 'Y'
            THEN
                c_num_debug   := 1;
            ELSE
                c_num_debug   := 0;
            END IF;

            p_out_var_errbuf    := NULL;
            p_out_var_retcode   := NULL;

            SELECT xxdo_inv_item_s.NEXTVAL INTO l_num_batch_id FROM DUAL;

            l_num_count         := 0;

            FOR rec_cur_item IN cur_item
            LOOP
                /********************************
                VALIDATIONS
                *********************************/
                l_chr_valid_item_flag   := 'N';
                g_process_step          := '0040';

                l_num_count             := l_num_count + 1;

                -- ----------------------------------------------
                -- Deriving Accounts based on the brands
                -- ----------------------------------------------
                IF gv_brand_id = '-1'
                THEN
                    BEGIN
                        --      fnd_file.put_line (fnd_file.LOG,'Reached here : 50');
                        g_process_step   := '0050';

                        SELECT flex_value_meaning
                          INTO gv_brand_id
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                         WHERE     flex_value_set_name = 'DO_GL_BRAND'
                               AND ffvs.flex_value_set_id =
                                   ffv.flex_value_set_id
                               AND UPPER (ffv.description) =
                                   UPPER (rec_cur_item.brand_code);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error at Step: ' || g_process_step);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error in Fetching brand id for brand :: '
                                || rec_cur_item.brand_code
                                || ' :: '
                                || SQLERRM);
                            gv_brand_id   := NULL;
                    END;
                END IF;

                IF gn_cost_acct = -1 OR gn_sales_acct = -1
                THEN
                    BEGIN
                        g_process_step   := '0060';

                        SELECT cost_of_sales_account, sales_account
                          INTO gn_cost_acct, gn_sales_acct
                          FROM apps.mtl_parameters
                         WHERE organization_code = p_in_var_dest;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error at Step: ' || g_process_step);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while fetching cost account for org  '
                                || p_in_var_dest
                                || '  '
                                || SQLERRM);
                    END;

                    g_process_step   := '0070';
                    xxdo_inv_item_enable_pkg.get_conc_code_combn (
                        pn_code_combn_id   => gn_sales_acct,
                        pv_brand           => gv_brand_id,
                        xn_new_ccid        => gn_sales_new_ccid);

                    g_process_step   := '0080';
                    xxdo_inv_item_enable_pkg.get_conc_code_combn (
                        pn_code_combn_id   => gn_cost_acct,
                        pv_brand           => gv_brand_id,
                        xn_new_ccid        => gn_cost_new_ccid);
                END IF;

                -- -----------------------------------------------------
                -- Deriving the currency code and value -- Start
                -- -----------------------------------------------------


                BEGIN
                    g_process_step   := '0090';

                    BEGIN
                        SELECT DISTINCT 'Y', UPPER (tag), UPPER (description)
                          INTO l_org_exists, lv_to_curr, lv_conv_type
                          FROM apps.fnd_lookup_values_vl
                         WHERE     lookup_type = 'LIST_PRICE_CONVERSION'
                               AND NVL (enabled_flag, 'Y') = 'Y'
                               AND lookup_code = p_in_var_dest;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            l_org_exists   := 'N';
                    END;

                    IF l_org_exists = 'Y'
                    THEN
                        BEGIN
                            g_process_step   := '0100';

                            -- Selecting the currency code for the source org
                            SELECT currency_code
                              INTO l_from_currency
                              FROM apps.gl_sets_of_books gsb, apps.org_organization_definitions ood
                             WHERE     gsb.set_of_books_id =
                                       ood.set_of_books_id
                                   AND ood.organization_code =
                                       rec_cur_item.warehouse_code;

                            -- Deriving the exchange rate

                            BEGIN
                                g_process_step   := '0110';

                                SELECT conversion_rate * rec_cur_item.list_price_per_unit
                                  INTO l_new_list_price    --l_conversion_rate
                                  FROM apps.gl_daily_rates gdr
                                 WHERE     from_currency = l_from_currency
                                       AND to_currency = lv_to_curr
                                       AND TRUNC (conversion_date) =
                                           TRUNC (SYSDATE)
                                       AND UPPER (conversion_type) =
                                           lv_conv_type;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Error at Step: ' || g_process_step);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Conversion rate not Found '
                                        || SQLERRM);
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Error at Step: ' || g_process_step);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Error while Currency Rate Conversion '
                                        || SQLERRM);
                            END;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error at Step: ' || g_process_step);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Warehouse is not in LIST_PRICE_CONVERSION lookup '
                                    || SQLERRM);
                        END;
                    ELSE
                        l_new_list_price   :=
                            rec_cur_item.list_price_per_unit;
                    END IF;
                END;

                -- -----------------------------------------------------
                -- Deriving the currency code and value -- End
                -- -----------------------------------------------------
                IF gv_cost_required = 'Y'
                THEN
                    IF rec_cur_item.inventory_type = 'BGRADE'
                    THEN
                        lv_life_cycle   := 'PRODUCTION';
                    ELSIF rec_cur_item.inventory_type = 'GENERIC'
                    THEN
                        lv_life_cycle   := 'ILR';
                    ELSE
                        lv_life_cycle   := 'FLR';
                    END IF;

                    BEGIN
                        SELECT description
                          INTO lv_template_name
                          FROM fnd_lookup_values_vl
                         WHERE     lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
                               AND (attribute1 = lv_life_cycle OR attribute2 = lv_life_cycle OR attribute3 = lv_life_cycle)
                               AND attribute4 = p_in_var_dest
                               AND tag =
                                   DECODE (rec_cur_item.inventory_type,
                                           'P', 'PROD',
                                           'PLANNED', 'PROD',
                                           rec_cur_item.inventory_type)
                               AND NVL (enabled_flag, 'Y') = 'Y';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_template_name   := NULL;
                    END;

                    lv_item_status   := 'Planned';
                ELSE
                    BEGIN
                        SELECT description
                          INTO lv_template_name
                          FROM fnd_lookup_values_vl
                         WHERE     lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
                               AND (attribute1 = 'PRODUCTION' OR attribute2 = 'PRODUCTION' OR attribute3 = 'PRODUCTION')
                               AND attribute4 = p_in_var_dest
                               AND tag =
                                   DECODE (rec_cur_item.inventory_type,
                                           'P', 'PROD',
                                           'PLANNED', 'PROD',
                                           rec_cur_item.inventory_type)
                               AND NVL (enabled_flag, 'Y') = 'Y';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_template_name   := NULL;
                    END;

                    lv_item_status   := 'Active';
                END IF;



                IF MOD (l_num_count, p_in_var_batch_size) = 0
                THEN
                    SELECT xxdo_inv_item_s.NEXTVAL
                      INTO l_num_batch_id
                      FROM DUAL;
                END IF;

                -- -----------------------------------------------------

                /*insert into staging table*/
                -- -----------------------------------------------------
                --
                BEGIN
                    g_process_step   := '0120';

                    INSERT INTO xxdo_inv_item_enbl_stg (
                                    warehouse_code,
                                    item_number,
                                    host_description,
                                    serial_control,
                                    uom,
                                    style_code,
                                    style_name,
                                    color_code,
                                    color_name,
                                    size_code,
                                    size_name,
                                    upc,
                                    each_weight,
                                    each_length,
                                    each_width,
                                    each_height,
                                    brand_code,
                                    coo,
                                    inventory_type,
                                    shelf_life,
                                    alt_item_number,
                                    gender,
                                    product_class,
                                    product_category,
                                    host_status,
                                    intro_season,
                                    last_active_season,
                                    process_status,
                                    request_id,
                                    inventory_item_id,
                                    summary_flag,
                                    enabled_flag,
                                    purchasing_item_flag,
                                    sales_account,
                                    cost_of_sales_account,
                                    record_type,
                                    dest_wh_code,
                                    dest_wh_id,
                                    batch_id,
                                    list_price_per_unit,
                                    planner_code,
                                    flr_item_template,
                                    preprocessing_lead_time,
                                    full_lead_time,
                                    postprocessing_lead_time,
                                    cumulative_total_lead_time,
                                    prod_line_category_id,
                                    tarrif_code_category_id)
                             VALUES (rec_cur_item.warehouse_code,
                                     rec_cur_item.item_number,
                                     rec_cur_item.host_description,
                                     -- NVL (rec_cur_item.serial_control, 'N'),
                                     'N',
                                     rec_cur_item.uom,
                                     rec_cur_item.style_code,
                                     rec_cur_item.style_name,
                                     rec_cur_item.color_code,
                                     rec_cur_item.color_name,
                                     rec_cur_item.size_code,
                                     rec_cur_item.size_name,
                                     rec_cur_item.upc,
                                     NVL (rec_cur_item.each_weight, 0),
                                     NVL (rec_cur_item.each_length, 0),
                                     NVL (rec_cur_item.each_width, 0),
                                     NVL (rec_cur_item.each_height, 0),
                                     rec_cur_item.brand_code,
                                     rec_cur_item.coo,
                                     rec_cur_item.inventory_type,
                                     rec_cur_item.shelf_life,
                                     rec_cur_item.alt_item_number,
                                     rec_cur_item.gender,
                                     rec_cur_item.product_class,
                                     rec_cur_item.product_category,
                                     rec_cur_item.host_status,
                                     rec_cur_item.intro_season,
                                     rec_cur_item.last_active_season,
                                     'INPROCESS',
                                     g_num_request_id,
                                     rec_cur_item.inventory_item_id,
                                     rec_cur_item.summary_flag,
                                     rec_cur_item.enabled_flag,
                                     rec_cur_item.purchasing_item_flag,
                                     gn_sales_new_ccid,
                                     gn_cost_new_ccid,
                                     'CREATE',
                                     p_in_var_dest,
                                     ln_or_id,
                                     l_num_batch_id,
                                     l_new_list_price,
                                     l_planner_code,
                                     lv_template_name,
                                     rec_cur_item.preprocessing_lead_time,
                                     rec_cur_item.full_lead_time,
                                     rec_cur_item.postprocessing_lead_time,
                                     rec_cur_item.cumulative_total_lead_time,
                                     rec_cur_item.prod_line_cat_id,
                                     rec_cur_item.tarrif_code_cat_id);

                    IF MOD (l_num_count, p_in_var_batch_size) = 0
                    THEN
                        COMMIT;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error at Step: ' || g_process_step);
                        --                  fnd_file.put_line (fnd_file.LOG,'Reached here : 100');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error occured for staging table insert '
                            || SQLERRM);
                        p_out_var_retcode   := 2;
                        p_out_var_errbuf    :=
                               'Error occured for staging table insert '
                            || SQLERRM;
                        msg (p_out_var_errbuf);
                        ROLLBACK;
                END;
            END LOOP;



            COMMIT;                              -- Commit the pending changes

            --fnd_file.put_line (fnd_file.LOG,'Reached here : 110');
            g_process_step      := '0130';

            UPDATE xxdo_inv_item_enbl_stg xit
               SET error_message = 'Item already exists', process_status = 'IGNORED'
             WHERE     request_id = g_num_request_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.mtl_system_items msi
                             WHERE     msi.organization_id = xit.dest_wh_id
                                   AND msi.inventory_item_id =
                                       xit.inventory_item_id);

            COMMIT;



            /*insert into interface table (batch wise)*/

            BEGIN
                --fnd_file.put_line (fnd_file.LOG,'Reached here : 120');
                --fnd_file.put_line (fnd_file.LOG,'Reached here : 120 - Request id: '|| g_num_request_id);
                g_process_step   := '0140';

                INSERT INTO mtl_system_items_interface (
                                organization_id,
                                inventory_item_id,
                                item_type,
                                segment1,
                                description,
                                transaction_type,
                                set_process_id,
                                summary_flag,
                                enabled_flag,
                                organization_code,
                                primary_uom_code,
                                process_flag,
                                purchasing_item_flag,
                                sales_account,
                                cost_of_sales_account,
                                expense_account,
                                last_update_date,
                                last_updated_by,
                                creation_date,
                                created_by,
                                last_update_login,
                                planner_code,
                                template_name,
                                preprocessing_lead_time,
                                full_lead_time,
                                postprocessing_lead_time,
                                cumulative_total_lead_time,
                                inventory_item_status_code,
                                list_price_per_unit)
                    SELECT dest_wh_id, inventory_item_id, inventory_type,
                           --             style_code || '-' || color_code || '-' || size_code,
                           --
                           -- Commented to fix duplicate item issue 1.1 -- CCR0005441
                           -- Segment1 should be picked up from the item_number field rather than the concatenated segments
                           item_number, -- Added item_number field to fix duplicate item issue 1.1
                                        host_description, record_type,
                           batch_id, summary_flag, enabled_flag,
                           dest_wh_code, uom, 1,
                           purchasing_item_flag, sales_account, cost_of_sales_account,
                           expense_account, SYSDATE, g_num_user_id,
                           SYSDATE, g_num_user_id, g_num_login_id,
                           planner_code, flr_item_template, preprocessing_lead_time,
                           full_lead_time, postprocessing_lead_time, cumulative_total_lead_time,
                           lv_item_status, list_price_per_unit
                      FROM apps.xxdo_inv_item_enbl_stg
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS';

                l_num_count      := SQL%ROWCOUNT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error at Step: ' || g_process_step);
                    --   fnd_file.put_line (fnd_file.LOG,'Reached here : 130');
                    l_chr_req_failure   := 'Y';
                    p_out_var_retcode   := 2;
                    p_out_var_errbuf    :=
                           'Error occured for interface table insert '
                        || SQLERRM;
                    msg (p_out_var_errbuf);
                    ROLLBACK;
            END;

            COMMIT;


            -- Calling the Item Import request
            g_process_step      := '0150';
            i                   := 0;

            IF l_num_count > 0
            THEN
                FOR cur_stg_rec IN cur_stg
                LOOP
                    i   := i + 1;
                    g_item_request_ids_tab (i)   :=
                        fnd_request.submit_request (
                            application   => 'INV',
                            program       => 'INCOIN',
                            argument1     => ln_or_id,
                            argument2     => 2,
                            argument3     => 1,
                            argument4     => 1,
                            argument5     => 2,
                            argument6     => cur_stg_rec.batch_id,
                            --batch_number
                            argument7     => 1,
                            description   => NULL,
                            start_time    => NULL);
                    COMMIT;

                    IF g_item_request_ids_tab (i) = 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            ' Concurrent Request is not launched');
                        p_out_var_retcode   := '1';
                        p_out_var_errbuf    :=
                            'One or more Child requests are not launched. Please refer the log file for more details';
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Concurrent Request ID : '
                            || g_item_request_ids_tab (i));
                    END IF;
                END LOOP;

                COMMIT;
                l_chr_req_failure   := 'N';
                fnd_file.put_line (fnd_file.LOG, '');
                fnd_file.put_line (
                    fnd_file.LOG,
                    '-------------Concurrent Requests Status Report ---------------');

                FOR i IN 1 .. g_item_request_ids_tab.COUNT
                LOOP
                    l_bol_req_status   :=
                        fnd_concurrent.wait_for_request (
                            g_item_request_ids_tab (i),
                            10,
                            0,
                            l_chr_phase,
                            l_chr_status,
                            l_chr_dev_phase,
                            l_chr_dev_status,
                            l_chr_message);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Concurrent request ID : '
                        || g_item_request_ids_tab (i)
                        || CHR (9)
                        || ' Phase: '
                        || l_chr_phase
                        || CHR (9)
                        || ' Status: '
                        || l_chr_status
                        || CHR (9)
                        || ' Dev Phase: '
                        || l_chr_dev_phase
                        || CHR (9)
                        || ' Dev Status: '
                        || l_chr_dev_status
                        || CHR (9)
                        || ' Message: '
                        || l_chr_message);
                END LOOP;
            END IF;


            /*
                    l_request_id :=
                        fnd_request.submit_request (application   => 'INV',
                                                    program       => 'INCOIN',
                                                    description   => NULL,
                                                    start_time    => SYSDATE,
                                                    sub_request   => FALSE,
                                                    argument1     => ln_or_id, -- Organization id
                                                    argument2     => 2, -- All organizations
                                                    argument3     => 1,  -- Validate Items
                                                    argument4     => 1,   -- Process Items
                                                    argument5     => 2, -- Delete Processed Rows
                                                    argument6     => l_num_batch_id,
                                                    -- Process Set (Null for All)
                                                    argument7     => 1, -- Create or Update Items
                                                    argument8     => 2 -- Gather Statistics
                                                                      );

            */

            g_process_step      := '0160';

            UPDATE xxdo_inv_item_enbl_stg xii
               SET process_status     = 'ERROR',
                   last_update_date   = SYSDATE,
                   error_message     =
                       (SELECT error_message
                          FROM apps.mtl_interface_errors mie, apps.mtl_system_items_interface msii
                         WHERE     msii.set_process_id = xii.batch_id
                               AND msii.organization_id = xii.dest_wh_id
                               AND msii.inventory_item_id =
                                   xii.inventory_item_id
                               AND msii.transaction_id = mie.transaction_id
                               AND msii.process_flag = 3
                               AND ROWNUM = 1)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND EXISTS
                           (SELECT 1
                              FROM apps.mtl_system_items_interface msii
                             WHERE     msii.set_process_id = xii.batch_id
                                   AND msii.organization_id = xii.dest_wh_id
                                   AND msii.inventory_item_id =
                                       xii.inventory_item_id
                                   AND msii.set_process_id = xii.batch_id
                                   AND msii.process_flag = 3);

            g_process_step      := '0170';

            IF NVL (p_in_include_org_cats, 'N') = 'N'
            THEN
                UPDATE xxdo_inv_item_enbl_stg xii
                   SET process_status = DECODE (xii.inventory_type, 'GENERIC', 'SUCCESS', 'LOAD X-REF'), error_message = NULL, last_update_date = SYSDATE
                 WHERE     request_id = g_num_request_id
                       AND process_status = 'INPROCESS';

                COMMIT;
            ELSE                          -- Org Level Categories to be copied
                INSERT INTO apps.mtl_item_categories_interface (
                                inventory_item_id,
                                organization_id,
                                category_set_id,
                                category_id,
                                last_update_date,
                                last_updated_by,
                                creation_date,
                                created_by,
                                process_flag,
                                transaction_type,
                                set_process_id)
                    SELECT inventory_item_id, dest_wh_id, lv_prod_line_cat_set_id,
                           prod_line_category_id, SYSDATE, g_num_user_id,
                           SYSDATE, g_num_user_id, 1,
                           'CREATE', batch_id
                      FROM xxdo_inv_item_enbl_stg xii
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS'
                           AND prod_line_category_id IS NOT NULL;

                l_num_count   := SQL%ROWCOUNT;

                COMMIT;


                INSERT INTO apps.mtl_item_categories_interface (
                                inventory_item_id,
                                organization_id,
                                category_set_id,
                                category_id,
                                last_update_date,
                                last_updated_by,
                                creation_date,
                                created_by,
                                process_flag,
                                transaction_type,
                                set_process_id)
                    SELECT inventory_item_id, dest_wh_id, lv_tarrif_code_cat_set_id,
                           tarrif_code_category_id, SYSDATE, g_num_user_id,
                           SYSDATE, g_num_user_id, 1,
                           'CREATE', batch_id
                      FROM xxdo_inv_item_enbl_stg xii
                     WHERE     request_id = g_num_request_id
                           AND process_status = 'INPROCESS'
                           AND tarrif_code_category_id IS NOT NULL;

                IF NVL (l_num_count, 0) < 1
                THEN
                    l_num_count   := SQL%ROWCOUNT;
                END IF;

                COMMIT;



                IF g_item_request_ids_tab.EXISTS (1)
                THEN
                    g_item_request_ids_tab.DELETE;
                END IF;

                i             := 0;

                IF l_num_count > 0
                THEN
                    FOR cur_cat_stg_rec IN cur_cat_stg
                    LOOP
                        i   := i + 1;
                        g_item_request_ids_tab (i)   :=
                            fnd_request.submit_request (
                                application   => 'INV',
                                program       => 'INV_ITEM_CAT_ASSIGN_OI',
                                description   => '',
                                start_time    =>
                                    TO_CHAR (SYSDATE, 'DD-MON-YY HH24:MI:SS'),
                                sub_request   => FALSE,
                                argument1     => cur_cat_stg_rec.batch_id,
                                argument2     => '1',
                                argument3     => '1');

                        COMMIT;

                        IF g_item_request_ids_tab (i) = 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Item Category Assignment Concurrent Request is not launched');
                            p_out_var_retcode   := '1';
                            p_out_var_errbuf    :=
                                'One or more Item Category Assignment requests are not launched. Please refer the log file for more details';
                        ELSE
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Item Category Assignment Concurrent Request ID : '
                                || g_item_request_ids_tab (i));
                        END IF;
                    END LOOP;

                    COMMIT;
                    l_chr_req_failure   := 'N';
                    fnd_file.put_line (fnd_file.LOG, '');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        '-------------Item Category Assignment Concurrent Requests Status Report ---------------');

                    FOR i IN 1 .. g_item_request_ids_tab.COUNT
                    LOOP
                        l_bol_req_status   :=
                            fnd_concurrent.wait_for_request (
                                g_item_request_ids_tab (i),
                                10,
                                0,
                                l_chr_phase,
                                l_chr_status,
                                l_chr_dev_phase,
                                l_chr_dev_status,
                                l_chr_message);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Item Category Assignment Concurrent request ID : '
                            || g_item_request_ids_tab (i)
                            || CHR (9)
                            || ' Phase: '
                            || l_chr_phase
                            || CHR (9)
                            || ' Status: '
                            || l_chr_status
                            || CHR (9)
                            || ' Dev Phase: '
                            || l_chr_dev_phase
                            || CHR (9)
                            || ' Dev Status: '
                            || l_chr_dev_status
                            || CHR (9)
                            || ' Message: '
                            || l_chr_message);
                    END LOOP;
                END IF;



                UPDATE xxdo.xxdo_inv_item_enbl_stg stg
                   SET process_status     = 'ERROR',
                       last_update_date   = SYSDATE,
                       error_message     =
                           (SELECT a.error_message
                              FROM apps.mtl_interface_errors a, apps.mtl_item_categories_interface b
                             WHERE     b.transaction_id = a.transaction_id
                                   AND b.inventory_item_id =
                                       stg.inventory_item_id
                                   AND b.organization_id = stg.dest_wh_id
                                   AND b.set_process_id = stg.batch_id
                                   AND b.process_flag != 7
                                   AND ROWNUM = 1)
                 WHERE     request_id = g_num_request_id
                       AND process_status = 'INPROCESS'
                       AND EXISTS
                               (SELECT 'x'
                                  FROM apps.mtl_item_categories_interface msi
                                 WHERE     1 = 1
                                       AND stg.dest_wh_id =
                                           msi.organization_id
                                       AND stg.inventory_item_id =
                                           msi.inventory_item_id
                                       AND stg.batch_id = msi.set_process_id
                                       AND msi.process_flag = 3);

                COMMIT;

                UPDATE xxdo_inv_item_enbl_stg xii
                   SET process_status = DECODE (xii.inventory_type, 'GENERIC', 'SUCCESS', 'LOAD X-REF'), error_message = NULL, last_update_date = SYSDATE
                 WHERE     request_id = g_num_request_id
                       AND process_status = 'INPROCESS';

                COMMIT;
            END IF;

            -- -------------------------------------------
            -- Call the procedure for X-Ref creation
            -- -------------------------------------------
            fnd_file.put_line (fnd_file.LOG, 'Calling the X-Ref process');



            g_process_step      := '0180';
            create_mtl_cross_reference (p_in_var_source   => p_in_var_source,
                                        p_in_var_dest     => p_in_var_dest);


            fnd_file.put_line (
                fnd_file.output,
                   'Target Org'
                || CHR (9)
                || 'Item Number'
                || CHR (9)
                || 'Item Description'
                || CHR (9)
                || 'UOM'
                || CHR (9)
                || 'Style Code'
                || CHR (9)
                || 'Style Name'
                || CHR (9)
                || 'Color Code'
                || CHR (9)
                || 'Color Name'
                || CHR (9)
                || 'Size Code'
                || CHR (9)
                || 'Size Name'
                || CHR (9)
                || 'UPC'
                || CHR (9)
                || 'Item Type'
                || CHR (9)
                || 'Brand'
                || CHR (9)
                || 'Division'
                || CHR (9)
                || 'Department'
                || CHR (9)
                || 'Class'
                || CHR (9)
                || 'Season'
                || CHR (9)
                || 'Item Status - Source Org'
                || CHR (9)
                || 'Item Status - Target Org'
                || CHR (9)
                || 'Process Status'
                || CHR (9)
                || 'Error Message');


            FOR output_rec IN cur_output
            LOOP
                lv_output_record   :=
                       --  rec_cur_item.warehouse_code
                       p_in_var_dest
                    || CHR (9)
                    || output_rec.item_number
                    || CHR (9)
                    || output_rec.host_description
                    || CHR (9)
                    || output_rec.uom
                    || CHR (9)
                    || output_rec.style_code
                    || CHR (9)
                    || output_rec.style_name
                    || CHR (9)
                    || output_rec.color_code
                    || CHR (9)
                    || output_rec.color_name
                    || CHR (9)
                    || ''''
                    || output_rec.size_code
                    || ''''
                    || CHR (9)
                    || ''''
                    || output_rec.size_name
                    || ''''
                    || CHR (9)
                    || output_rec.upc
                    || CHR (9)
                    || output_rec.inventory_type
                    || CHR (9)
                    || output_rec.brand_code
                    || CHR (9)
                    || output_rec.gender
                    || CHR (9)
                    || output_rec.product_class
                    || CHR (9)
                    || output_rec.product_category
                    || CHR (9)
                    || output_rec.last_active_season
                    || CHR (9)
                    || output_rec.host_status
                    || CHR (9)
                    || output_rec.inventory_item_status_code
                    || CHR (9)
                    || output_rec.process_status
                    || CHR (9)
                    || output_rec.error_message;

                fnd_file.put_line (fnd_file.output, lv_output_record);
            END LOOP;
        END IF;                                           -- End if Mode Check
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error at Step: ' || g_process_step);
            p_out_var_retcode   := 2;
            p_out_var_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Error occured in item insert due to  ' || SQLERRM);
    END main_extract;

    -- -----------------------------------------------------------
    -- Procedure to derive the GL code combinations
    -- -----------------------------------------------------------
    PROCEDURE get_conc_code_combn (pn_code_combn_id IN NUMBER, pv_brand IN VARCHAR2, xn_new_ccid OUT NUMBER)
    IS
        CURSOR get_conc_code_combn_c IS
            SELECT segment1, NVL (pv_brand, segment2), segment3,
                   segment4, segment5, segment6,
                   segment7, segment8
              FROM apps.gl_code_combinations
             WHERE code_combination_id = pn_code_combn_id;

        lc_conc_code_combn   VARCHAR2 (100);
        l_n_segments         NUMBER := 8;
        l_delim              VARCHAR2 (1) := '.';
        l_segment_array      fnd_flex_ext.segmentarray;
        ln_coa_id            NUMBER;
        l_concat_segs        VARCHAR2 (32000);
    BEGIN
        --fnd_file.put_line (fnd_file.LOG,'Reached here : start of gl proc');
        g_process_step   := '0190';

        OPEN get_conc_code_combn_c;

        FETCH get_conc_code_combn_c
            INTO l_segment_array (1), l_segment_array (2), l_segment_array (3), l_segment_array (4),
                 l_segment_array (5), l_segment_array (6), l_segment_array (7),
                 l_segment_array (8);

        --       RETURN lc_conc_code_combn;
        CLOSE get_conc_code_combn_c;

        g_process_step   := '0200';

        SELECT chart_of_accounts_id
          INTO ln_coa_id
          FROM apps.gl_sets_of_books
         WHERE set_of_books_id = fnd_profile.VALUE ('GL_SET_OF_BKS_ID');

        --fnd_file.put_line (fnd_file.LOG,'Reached here : chart_of_accounts_id: '||ln_coa_id);

        msg ('ln_coa_id    ' || ln_coa_id);
        g_process_step   := '0210';
        l_concat_segs    :=
            fnd_flex_ext.concatenate_segments (l_n_segments,
                                               l_segment_array,
                                               l_delim);
        --fnd_file.put_line (fnd_file.LOG,'Reached here : concatenate_segments: '||l_concat_segs);

        msg ('Concatinated Segments   ' || l_concat_segs);
        g_process_step   := '0220';
        xn_new_ccid      :=
            fnd_flex_ext.get_ccid ('SQLGL',
                                   'GL#',
                                   ln_coa_id,
                                   TO_CHAR (SYSDATE, 'DD-MON-YYYY'),
                                   l_concat_segs);
        msg ('New CCID Segments   ' || xn_new_ccid);

        --fnd_file.put_line (fnd_file.LOG,'Reached here : gl_proc: '||pn_code_combn_id);

        IF xn_new_ccid = 0
        THEN
            xn_new_ccid   := pn_code_combn_id;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error at Step: ' || g_process_step);
            fnd_file.put_line (
                fnd_file.LOG,
                'No data from get_conc_code_combn   ' || SQLERRM);
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error at Step: ' || g_process_step);
            fnd_file.put_line (
                fnd_file.LOG,
                'Unknown error in get_conc_code_combn   ' || SQLERRM);
    END GET_CONC_CODE_COMBN;

    -- =================================================

    -- -----------------------------------------------------------
    -- Procedure to create UPC Cross Reference -- Start
    -- -----------------------------------------------------------

    PROCEDURE create_mtl_cross_reference ( --                                      pv_retcode           OUT VARCHAR2,
    --                                      pv_reterror          OUT VARCHAR2,
    p_in_var_source IN VARCHAR2, p_in_var_dest IN VARCHAR2)
    IS
        CURSOR cross_ref_cur IS
            SELECT msi.inventory_item_id, msi.segment1, mcrb.cross_reference upc,
                   --             msi.attribute11 upc,
                   xiie.process_status, xiie.dest_wh_id organization_id, msi.organization_id org_id,
                   xiie.ROWID
              FROM apps.mtl_system_items_b msi, apps.xxdo_inv_item_enbl_stg xiie, apps.mtl_parameters mp,
                   apps.mtl_cross_references_b mcrb
             WHERE     xiie.process_status = 'LOAD X-REF'
                   AND xiie.error_message IS NULL
                   AND xiie.item_number = msi.segment1
                   AND msi.organization_id = mp.organization_id
                   AND mp.organization_code = p_in_var_source
                   AND xiie.dest_wh_code = p_in_var_dest
                   AND msi.inventory_item_id = mcrb.inventory_item_id
                   AND msi.organization_id = mcrb.organization_id
                   AND mcrb.cross_reference_type = 'UPC Cross Reference'
                   AND xiie.request_id = g_num_request_id
                   --             AND msi.segment1 not like '%ALL'
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.mtl_cross_references_b
                             WHERE     cross_reference_type =
                                       'UPC Cross Reference'
                                   AND inventory_item_id =
                                       msi.inventory_item_id
                                   AND organization_id = xiie.dest_wh_id);

        ln_reference_id   NUMBER;
        x_inv_item_num    VARCHAR2 (50);
        x_org_id          NUMBER;
    BEGIN
        g_process_step   := '0230';

        FOR cross_ref_cur_v IN cross_ref_cur
        LOOP
            x_inv_item_num   := cross_ref_cur_v.segment1;
            x_org_id         := cross_ref_cur_v.organization_id;

            apps.mtl_cross_references_pkg.insert_row (
                p_source_system_id         => NULL,
                p_start_date_active        => NULL,
                p_end_date_active          => NULL,
                p_object_version_number    => 1,
                p_uom_code                 => NULL,
                p_revision_id              => NULL,
                p_epc_gtin_serial          => 0,
                p_inventory_item_id        => cross_ref_cur_v.inventory_item_id,
                p_organization_id          => cross_ref_cur_v.organization_id,
                p_cross_reference_type     => 'UPC Cross Reference',
                p_cross_reference          => LPAD (cross_ref_cur_v.upc, 14, 0),
                p_org_independent_flag     => 'Y',
                p_request_id               => NULL,
                p_attribute1               => NULL,
                p_attribute2               => NULL,
                p_attribute3               => NULL,
                p_attribute4               => NULL,
                p_attribute5               => NULL,
                p_attribute6               => NULL,
                p_attribute7               => NULL,
                p_attribute8               => NULL,
                p_attribute9               => NULL,
                p_attribute10              => NULL,
                p_attribute11              => NULL,
                p_attribute12              => NULL,
                p_attribute13              => NULL,
                p_attribute14              => NULL,
                p_attribute15              => NULL,
                p_attribute_category       => NULL,
                p_description              => NULL,
                p_creation_date            => SYSDATE,
                p_created_by               => fnd_global.user_id,
                p_last_update_date         => SYSDATE,
                p_last_updated_by          => fnd_global.user_id,
                p_last_update_login        => fnd_global.login_id,
                p_program_application_id   => NULL,
                p_program_id               => NULL,
                p_program_update_date      => NULL,
                x_cross_reference_id       => ln_reference_id);

            -- ----------------------------------------------------------
            -- Updating the staging table with the success status
            -- ----------------------------------------------------------
            g_process_step   := '0240';

            UPDATE xxdo_inv_item_enbl_stg xii
               SET process_status = DECODE (gv_cost_required, 'Y', 'C', 'SUCCESS'), error_message = NULL, last_update_date = SYSDATE
             WHERE     inventory_item_id = cross_ref_cur_v.inventory_item_id
                   AND process_status = 'LOAD X-REF'
                   AND xii.ROWID = cross_ref_cur_v.ROWID;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error at Step: ' || g_process_step);
            fnd_file.put_line (fnd_file.LOG, 'Item Id: ' || x_inv_item_num);
            fnd_file.put_line (fnd_file.LOG, 'Org Id: ' || x_org_id);
            ROLLBACK;

            fnd_file.put_line (fnd_file.LOG,
                               'Error in X-Ref creation ' || SQLERRM);
            g_process_step   := '0250';

            UPDATE xxdo_inv_item_enbl_stg xii
               SET process_status = 'ERROR', last_update_date = SYSDATE, error_message = 'Error in X-Ref creation'
             WHERE     request_id = g_num_request_id
                   AND process_status = 'LOAD X-REF';

            COMMIT;
    END create_mtl_cross_reference;

    -- -------------------------------------------------------------
    -- Procedure to create UPC Cross Reference -- End
    -- -----------------------------------------------------------


    PROCEDURE activate_items (
        p_out_var_errbuf         OUT VARCHAR2,
        p_out_var_retcode        OUT NUMBER,
        p_in_var_source       IN     VARCHAR2,
        p_in_var_dest         IN     VARCHAR2,
        p_in_var_brand        IN     VARCHAR2,
        p_in_var_division     IN     VARCHAR2,
        p_in_season           IN     VARCHAR2,
        p_debug_level         IN     VARCHAR2,
        p_in_var_batch_size   IN     NUMBER,
        p_in_style            IN     VARCHAR2,
        p_in_color            IN     VARCHAR2,
        p_in_size             IN     VARCHAR2,
        p_in_include_sample   IN     VARCHAR2 DEFAULT 'N',
        p_in_include_bgrade   IN     VARCHAR2 DEFAULT 'N')
    IS
        CURSOR cur_planned_items IS
            SELECT xii.*, msib1.inventory_item_status_code, xii.ROWID
              FROM xxdo_inv_item_enbl_stg xii, apps.mtl_system_items_b msib1
             WHERE     xii.process_status = 'C'
                   AND xii.dest_wh_code = p_in_var_dest
                   AND xii.brand_code = p_in_var_brand
                   AND xii.last_active_season =
                       NVL (p_in_season, xii.last_active_season)
                   AND xii.style_code = NVL (p_in_style, xii.style_code)
                   AND xii.color_code = NVL (p_in_color, xii.color_code)
                   AND xii.size_code = NVL (p_in_size, xii.size_code)
                   AND xii.gender =
                       NVL (
                           DECODE (p_in_var_division,
                                   'ALL', xii.gender,
                                   p_in_var_division),
                           xii.gender)
                   AND xii.dest_wh_id = msib1.organization_id
                   AND xii.inventory_item_id = msib1.inventory_item_id
                   AND xii.inventory_type IN
                           (SELECT lookup_code
                              FROM apps.fnd_lookup_values
                             WHERE     lookup_type LIKE 'ITEM_TYPE'
                                   AND LANGUAGE = 'US'
                                   AND lookup_code NOT IN
                                           ('SAMPLE', 'BGRADE')
                            UNION ALL
                            SELECT 'SAMPLE'
                              FROM DUAL
                             WHERE p_in_include_sample = 'Y'
                            UNION ALL
                            SELECT 'BGRADE'
                              FROM DUAL
                             WHERE p_in_include_bgrade = 'Y');

        CURSOR cur_output IS
            SELECT stg.*, msib1.inventory_item_status_code
              FROM apps.xxdo_inv_item_enbl_stg stg, apps.mtl_system_items_b msib1
             WHERE     stg.request_id = g_num_request_id
                   AND msib1.inventory_item_id = stg.inventory_item_id
                   AND msib1.organization_id = stg.dest_wh_id;


        CURSOR cur_batch_ids IS
            SELECT DISTINCT batch_id
              FROM xxdo_inv_item_enbl_stg
             WHERE     process_status = 'C_INPROCESS'
                   AND request_id = g_num_request_id;

        l_cost_missing      NUMBER := 0;
        lv_template_name    fnd_lookup_values.description%TYPE;
        l_num_count         NUMBER := 0;
        i                   NUMBER;
        j                   NUMBER;
        l_chr_req_failure   VARCHAR2 (1) := 'N';
        l_chr_phase         VARCHAR2 (100) := NULL;
        l_chr_status        VARCHAR2 (100) := NULL;
        l_chr_dev_phase     VARCHAR2 (100) := NULL;
        l_chr_dev_status    VARCHAR2 (100) := NULL;
        l_chr_message       VARCHAR2 (1000) := NULL;
        l_bol_req_status    BOOLEAN;
        ln_or_id            NUMBER;
        lv_output_record    VARCHAR2 (32767);
    BEGIN
        p_out_var_errbuf    := NULL;
        p_out_var_retcode   := '0';

        SELECT organization_id
          INTO ln_or_id
          FROM apps.mtl_parameters mp1
         WHERE mp1.organization_code = p_in_var_dest;

        --    BEGIN
        --      g_item_batch_ids_tab.DELETE;
        --    EXCEPTION
        --        WHEN OTHERS THEN
        --            NULL;
        --    END;

        FOR planned_items_rec IN cur_planned_items
        LOOP
            IF planned_items_rec.inventory_item_status_code = 'Active'
            THEN
                UPDATE xxdo_inv_item_enbl_stg
                   SET process_status = 'SUCCESS', error_message = 'Item is already Active', request_id = g_num_request_id,
                       last_update_date = SYSDATE, last_updated_by = g_num_user_id
                 WHERE ROWID = planned_items_rec.ROWID;
            ELSE
                BEGIN
                    SELECT COUNT (1)
                      INTO l_cost_missing
                      FROM (SELECT resource_id
                              FROM bom_resources brs, cst_cost_elements cce
                             WHERE     organization_id =
                                       planned_items_rec.dest_wh_id
                                   AND brs.cost_element_id =
                                       cce.cost_element_id
                                   AND cost_element = 'Material Overhead'
                            MINUS
                            SELECT resource_id
                              FROM cst_item_cost_details cid, cst_cost_types cct
                             WHERE     inventory_item_id =
                                       planned_items_rec.inventory_item_id
                                   AND cid.organization_id =
                                       planned_items_rec.dest_wh_id
                                   AND cid.cost_type_id = cct.cost_type_id
                                   AND cost_type = 'AvgRates');
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_cost_missing   := 5;
                    WHEN OTHERS
                    THEN
                        l_cost_missing   := 5;
                END;

                IF l_cost_missing > 0
                THEN
                    UPDATE xxdo_inv_item_enbl_stg
                       SET error_message = 'Cost Elements does not exist', request_id = g_num_request_id, last_update_date = SYSDATE,
                           last_updated_by = g_num_user_id
                     WHERE ROWID = planned_items_rec.ROWID;
                ELSE          -- l_cost_missing = 0 -- All cost elements exist
                    BEGIN
                        SELECT description
                          INTO lv_template_name
                          FROM fnd_lookup_values_vl
                         WHERE     lookup_type = 'DO_ORG_TEMPLATE_ASSIGNMENT'
                               AND (attribute1 = 'PRODUCTION' OR attribute2 = 'PRODUCTION' OR attribute3 = 'PRODUCTION')
                               AND attribute4 = p_in_var_dest
                               AND tag =
                                   DECODE (planned_items_rec.inventory_type,
                                           'P', 'PROD',
                                           'PLANNED', 'PROD',
                                           planned_items_rec.inventory_type)
                               AND NVL (enabled_flag, 'Y') = 'Y';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_template_name   := NULL;
                    END;



                    --    BEGIN
                    --        IF NOT g_item_batch_ids_tab.EXISTS(planned_items_rec.batch_id) THEN
                    --            g_item_batch_ids_tab(planned_items_rec.batch_id) := planned_items_rec.batch_id;
                    --        END IF;
                    --    EXCEPTION
                    --        WHEN OTHERS THEN
                    --         fnd_file.put_line (fnd_file.LOG,
                    --                  'Error : ' || SQLERRM
                    --                 );
                    --
                    --    END;

                    l_num_count   := l_num_count + 1;


                    INSERT INTO mtl_system_items_interface (organization_id, inventory_item_id, transaction_type, set_process_id, process_flag, template_name
                                                            , segment1)
                         VALUES (planned_items_rec.dest_wh_id, planned_items_rec.inventory_item_id, 'UPDATE', planned_items_rec.batch_id, 1, lv_template_name
                                 , planned_items_rec.item_number);

                    UPDATE xxdo_inv_item_enbl_stg
                       SET process_status = 'C_INPROCESS', prod_item_template = lv_template_name, request_id = g_num_request_id,
                           last_update_date = SYSDATE, last_updated_by = g_num_user_id
                     WHERE ROWID = planned_items_rec.ROWID;


                    IF MOD (l_num_count, p_in_var_batch_size) = 0
                    THEN
                        COMMIT;
                    END IF;
                END IF;
            END IF;
        END LOOP;

        COMMIT;


        --         fnd_file.put_line (fnd_file.LOG,
        --                  'g_item_batch_ids_tab.COUNT : ' ||   g_item_batch_ids_tab.COUNT);
        --
        --
        --FOR j IN g_item_batch_ids_tab.FIRST..g_item_batch_ids_tab.LAST
        --             LOOP
        --         fnd_file.put_line (fnd_file.LOG,
        --                  'j : ' ||   j);
        --END LOOP;

        i                   := 0;

        IF l_num_count > 0
        THEN
            FOR batch_ids_rec IN cur_batch_ids
            LOOP
                i   := i + 1;
                g_item_request_ids_tab (i)   :=
                    fnd_request.submit_request (
                        application   => 'INV',
                        program       => 'INCOIN',
                        argument1     => ln_or_id,
                        argument2     => 2,
                        argument3     => 1,
                        argument4     => 1,
                        argument5     => 2,
                        argument6     => batch_ids_rec.batch_id,
                        --batch_number
                        argument7     => 2,
                        description   => NULL,
                        start_time    => NULL);
                COMMIT;

                IF g_item_request_ids_tab (i) = 0
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       ' Concurrent Request is not launched');
                    p_out_var_retcode   := '1';
                    p_out_var_errbuf    :=
                        'One or more Child requests are not launched. Please refer the log file for more details';
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Concurrent Request ID : '
                        || g_item_request_ids_tab (i));
                END IF;
            END LOOP;

            COMMIT;
            l_chr_req_failure   := 'N';
            fnd_file.put_line (fnd_file.LOG, '');
            fnd_file.put_line (
                fnd_file.LOG,
                '-------------Concurrent Requests Status Report ---------------');

            FOR i IN 1 .. g_item_request_ids_tab.COUNT
            LOOP
                l_bol_req_status   :=
                    fnd_concurrent.wait_for_request (
                        g_item_request_ids_tab (i),
                        10,
                        0,
                        l_chr_phase,
                        l_chr_status,
                        l_chr_dev_phase,
                        l_chr_dev_status,
                        l_chr_message);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Concurrent request ID : '
                    || g_item_request_ids_tab (i)
                    || CHR (9)
                    || ' Phase: '
                    || l_chr_phase
                    || CHR (9)
                    || ' Status: '
                    || l_chr_status
                    || CHR (9)
                    || ' Dev Phase: '
                    || l_chr_dev_phase
                    || CHR (9)
                    || ' Dev Status: '
                    || l_chr_dev_status
                    || CHR (9)
                    || ' Message: '
                    || l_chr_message);
            END LOOP;
        END IF;

        UPDATE xxdo_inv_item_enbl_stg xii
           SET process_status     = 'ERROR',
               last_update_date   = SYSDATE,
               error_message     =
                   (SELECT error_message
                      FROM apps.mtl_interface_errors mie, apps.mtl_system_items_interface msii
                     WHERE     msii.set_process_id = xii.batch_id
                           AND msii.organization_id = xii.dest_wh_id
                           AND msii.inventory_item_id = xii.inventory_item_id
                           AND msii.transaction_id = mie.transaction_id
                           AND msii.process_flag = 3
                           AND ROWNUM = 1)
         WHERE     request_id = g_num_request_id
               AND process_status = 'C_INPROCESS'
               AND EXISTS
                       (SELECT 1
                          FROM apps.mtl_system_items_interface msii
                         WHERE     msii.set_process_id = xii.batch_id
                               AND msii.organization_id = xii.dest_wh_id
                               AND msii.inventory_item_id =
                                   xii.inventory_item_id
                               AND msii.set_process_id = xii.batch_id
                               AND msii.process_flag = 3);

        UPDATE xxdo_inv_item_enbl_stg xii
           SET process_status = 'SUCCESS', error_message = NULL, last_update_date = SYSDATE
         WHERE     request_id = g_num_request_id
               AND process_status = 'C_INPROCESS';

        COMMIT;


        fnd_file.put_line (
            fnd_file.output,
               'Target Org'
            || CHR (9)
            || 'Item Number'
            || CHR (9)
            || 'Item Description'
            || CHR (9)
            || 'UOM'
            || CHR (9)
            || 'Style Code'
            || CHR (9)
            || 'Style Name'
            || CHR (9)
            || 'Color Code'
            || CHR (9)
            || 'Color Name'
            || CHR (9)
            || 'Size Code'
            || CHR (9)
            || 'Size Name'
            || CHR (9)
            || 'UPC'
            || CHR (9)
            || 'Item Type'
            || CHR (9)
            || 'Brand'
            || CHR (9)
            || 'Division'
            || CHR (9)
            || 'Department'
            || CHR (9)
            || 'Class'
            || CHR (9)
            || 'Season'
            || CHR (9)
            || 'Item Status - Source Org'
            || CHR (9)
            || 'Item Status - Target Org'
            || CHR (9)
            || 'Process Status'
            || CHR (9)
            || 'Error Message');


        FOR output_rec IN cur_output
        LOOP
            lv_output_record   :=
                   --  rec_cur_item.warehouse_code
                   p_in_var_dest
                || CHR (9)
                || output_rec.item_number
                || CHR (9)
                || output_rec.host_description
                || CHR (9)
                || output_rec.uom
                || CHR (9)
                || output_rec.style_code
                || CHR (9)
                || output_rec.style_name
                || CHR (9)
                || output_rec.color_code
                || CHR (9)
                || output_rec.color_name
                || CHR (9)
                || ''''
                || output_rec.size_code
                || ''''
                || CHR (9)
                || ''''
                || output_rec.size_name
                || ''''
                || CHR (9)
                || output_rec.upc
                || CHR (9)
                || output_rec.inventory_type
                || CHR (9)
                || output_rec.brand_code
                || CHR (9)
                || output_rec.gender
                || CHR (9)
                || output_rec.product_class
                || CHR (9)
                || output_rec.product_category
                || CHR (9)
                || output_rec.last_active_season
                || CHR (9)
                || output_rec.host_status
                || CHR (9)
                || output_rec.inventory_item_status_code
                || CHR (9)
                || output_rec.process_status
                || CHR (9)
                || output_rec.error_message;

            fnd_file.put_line (fnd_file.output, lv_output_record);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_var_errbuf    := 'Unexpected Error Occurred: ' || SQLERRM;
            p_out_var_retcode   := '2';
    END;
END xxdo_inv_item_enable_pkg;
/
