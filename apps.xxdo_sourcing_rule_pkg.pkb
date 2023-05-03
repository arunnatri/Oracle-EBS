--
-- XXDO_SOURCING_RULE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_SOURCING_RULE_PKG"
AS
    -- =============================================
    -- Deckers- Business Transformation
    -- Description:
    -- This package is used to create sourcing rule and sourcing assignment
    -- =============================================
    -------------------------------------------------
    -------------------------------------------------
    --Author:
    /******************************************************************************
    1.Components: main_conv_proc
       Purpose:  Main procedure which does validation and calls API wrapper procs if needed
                For initial conversion purpose,takes sourcing rule stg records in new/null status from stage
                Performs validation against each record
                Calls API wrappers to create the sourcing rule and assignment for validated records
                Updates API return status in stage table for initial conversion purpose


       Execution Method: As a script for initial converison purpose and through custom web ADI for user upload purpose

       Note:Initial package version designed primarily for conversion purpose. Needs modification for usage in custom web ADI

     2.Components: main_conv_proc
       Purpose:  Main procedure which does validation and calls API wrapper procs if needed
                 Parameters to mimic the web ADI fields
                Performs validation against each record
                Calls API wrappers to create the sourcing rule and assignment for validated records
                Returns status as out parameter


       Execution Method: As a script for initial converison purpose and through custom web ADI for user upload purpose

       Note:Initial package version designed primarily for conversion purpose. Needs modification for usage in custom web ADI

    3.Components: sourcing_rule_upload
       Purpose: Takes sourcing rule stg records in new/null status from stage
                Performs validation against each record
                Calls sourcing rule API to create the sourcing rule for validated records
                Updates API return status in stage table

       Execution Method:

       Note:

    4.Components: sourcing_rule_assignment
       Purpose: Takes stage table records for which the rules have been created successfully
                Calls sourcing rule API to create the sourcing rule assignment
                Updates status in stage tables

       Execution Method:

       Note:


       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        3/6/2015             1.     Created this package.Initial package version designed primarily for conversion purpose.
                                              Needs modification for usage in custom web ADI
       2.0        08/20/2015  BT Tech Team    Changes to the logic for updating sourcing rule for source PLM as per CR# 118
       3.0        05/18/2016  Sunera Tech     Changes to add additional parameter to reprocess error records;
                                              Identified by REPROCESS_PARAM
       3.0        05/19/2016  Sunera Tech     If multiple users upload data using WebADI almost during same time,
                                              records of later runs are marked as VALIDATION SUCCESS wihtout any validations
                                              Changes to fix this issue;
                                              Identified by FIX_VALIDATIONS
       3.0       05/20/2016   Sunera Tech     Changes to populate WHO columns;
                                              Identified by WHO_COLUMNS
       3.0       05/20/2016   Sunera Tech     Changes to add a validation to check whether the style/color is active in Oracle;
                                              Identified by ACTIVE_STYLE
       4.0       10/19/2016   Infosys         Changes For Updating Sourcing Rule.
       5.0       01/30/2017   Bala Murugesan  Modified to pass the start date from PLM;
                                               Changes identified by PLM_START_DATE
       5.0       01/30/2017   Bala Murugesan  Modified to fix bug not creating the SR assignments for PLM source;
                                               Changes identified by SRA_CREATION_PLM
       5.0       01/30/2017   Bala Murugesan  Modified to stop updating the sourcing rules if the supplier and site are same;
                                               Changes identified by STOP_PLM_RULE_UPDATE
       5.0       01/30/2017   Bala Murugesan  Modified to fix the bug in WebADI upload - Start Date is sysdate + 1 but end date is sysdate -1
                                               HPQC Bug #: 372
                                               Changes identified by SOURCING_RULE_GAP
       6.0       07/10/2019   Kranthi Bollam  Modified for CCR0007979(Deckers Macau Project)
    ******************************************************************************/

    -- Define Program Units
    PROCEDURE main_conv_proc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, extract_data_flag VARCHAR2, -- Valid values 'Y' and 'N'
                                                                                                     validation_only_mode VARCHAR2, -- Valid values 'Y' and 'N'
                                                                                                                                    ip_assignment_set_id NUMBER DEFAULT NULL, ip_db_link_name VARCHAR2 DEFAULT NULL
                              , reprocess_err_records VARCHAR2 DEFAULT 'N') -- REPROCESS_PARAM
    IS                                                     -- Define Variables
        v_message                  VARCHAR2 (4000);
        v_return_status            VARCHAR2 (1);
        v_delete_count             NUMBER := 0;
        v_commit_counter           NUMBER := 0;
        v_ou_org_id                NUMBER;
        v_organization_id          NUMBER;
        v_assignment_set_id        NUMBER;
        v_planning_active_flag     NUMBER;
        v_source_type              NUMBER;
        v_source_org_id            NUMBER;
        v_vendor_id                NUMBER;
        v_vendor_site_id           NUMBER;
        v_sl                       NUMBER;
        v_sourcing_rule_id         NUMBER;
        V_SR_RECEIPT_ID            NUMBER;
        v_count                    NUMBER := 1;
        v_assignment_id            NUMBER;
        V_2ND_MAX_END_DATE         DATE;
        V_ASSSIGNMENT_SET_NAME     VARCHAR2 (50);
        v_plm_update_count         NUMBER; --Added by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
        v_inv_org_id               NUMBER;                     -- ACTIVE_STYLE
        V_SKP_SRC_ASSN             VARCHAR2 (10);
        l_num_rule_exists          NUMBER := 0;

        -- Sourcing Rule Creation API Input Variables
        v_sourcing_rule_rec        mrp_sourcing_rule_pub.sourcing_rule_rec_type;
        v_sourcing_rule_val_rec    mrp_sourcing_rule_pub.sourcing_rule_val_rec_type;
        v_receiving_org_tbl        mrp_sourcing_rule_pub.receiving_org_tbl_type;
        v_receiving_org_val_tbl    mrp_sourcing_rule_pub.receiving_org_val_tbl_type;
        v_shipping_org_tbl         mrp_sourcing_rule_pub.shipping_org_tbl_type;
        v_shipping_org_val_tbl     mrp_sourcing_rule_pub.shipping_org_val_tbl_type;
        x_sourcing_rule_rec        mrp_sourcing_rule_pub.sourcing_rule_rec_type;
        x_sourcing_rule_val_rec    mrp_sourcing_rule_pub.sourcing_rule_val_rec_type;
        x_receiving_org_tbl        mrp_sourcing_rule_pub.receiving_org_tbl_type;
        x_receiving_org_val_tbl    mrp_sourcing_rule_pub.receiving_org_val_tbl_type;
        x_shipping_org_tbl         mrp_sourcing_rule_pub.shipping_org_tbl_type;
        x_shipping_org_val_tbl     mrp_sourcing_rule_pub.shipping_org_val_tbl_type;
        -- Sourcing Rule Assignment API Input Variables
        v_assignment_set_rec       mrp_src_assignment_pub.assignment_set_rec_type;
        v_assignment_set_val_rec   mrp_src_assignment_pub.assignment_set_val_rec_type;
        v_assignment_tbl           mrp_src_assignment_pub.assignment_tbl_type;
        v_assignment_val_tbl       mrp_src_assignment_pub.assignment_val_tbl_type;
        x_assignment_set_rec       mrp_src_assignment_pub.assignment_set_rec_type;
        x_assignment_set_val_rec   mrp_src_assignment_pub.assignment_set_val_rec_type;
        x_assignment_tbl           mrp_src_assignment_pub.assignment_tbl_type;
        x_assignment_val_tbl       mrp_src_assignment_pub.assignment_val_tbl_type;

        -- Define Cursors
        -- Cursor to validate region
        CURSOR c_region IS
              SELECT --region --commented after staging table structure change
                     oracle_region region
                FROM xxdo_sourcing_rule_stg
               WHERE     NVL (record_status, g_new_status) IN --(g_new_status, g_valid_error_status);
                             (g_new_status, g_valid_reprocess_status) -- REPROCESS_PARAM
                     AND UPPER (oracle_region) != 'GLOBAL'
            GROUP BY oracle_region;

        -- Cursor to check if rule already exists
        CURSOR c_val IS
            SELECT --style, color, region  --commented after staging table structure change
                   ROWID rowxx, style, color,
                   oracle_region region, start_date, END_DATE,
                   RECORD_STATUS
              FROM xxdo_sourcing_rule_stg
             WHERE     NVL (record_status, g_new_status) IN
                           (g_new_status, --g_valid_error_status,  -- REPROCESS_PARAM
                                          g_valid_reprocess_status, --REPROCESS_PARAM
                                                                    g_sr_error_status,
                            g_sr_update_error_status)
                   -- AND run_id IS NOT NULL                           --for testing
                   AND UPPER (oracle_region) != 'GLOBAL';

        --GROUP BY style, color, oracle_region; commented to have multiple shipping org with different effective dates

        -- Cursor to validate supplier and site
        CURSOR c_sup IS
              SELECT org_id, supplier_name, supplier_site_code,
                     start_date
                FROM xxdo_sourcing_rule_stg
               WHERE     NVL (record_status, g_new_status) IN --(g_new_status, g_valid_error_status)
                             (g_new_status, g_valid_reprocess_status) -- REPROCESS_PARAM
                     AND UPPER (oracle_region) != 'GLOBAL'
                     AND org_id IS NOT NULL
            GROUP BY org_id, supplier_name, supplier_site_code,
                     start_date;


        -- Cursor to validate supplier and site -- ACTIVE_STYLE
        CURSOR c_style_colors (cv_region VARCHAR2)
        IS
              SELECT style, color, oracle_region
                FROM xxdo_sourcing_rule_stg
               WHERE     NVL (record_status, g_new_status) IN --(g_new_status, g_valid_error_status)
                             (g_new_status, g_valid_reprocess_status) -- REPROCESS_PARAM
                     AND UPPER (oracle_region) != 'GLOBAL'
                     AND UPPER (oracle_region) = cv_region
            GROUP BY style, color, oracle_region;

        -- Cursor to find duplicate record in stage table
        CURSOR c_stg_dup IS
              SELECT style, color, --region --commented after staging table structure change,
                                   oracle_region region,
                     start_date, end_date, supplier_name,
                     supplier_site_code, COUNT (*)
                FROM xxdo_sourcing_rule_stg
               WHERE NVL (record_status, g_new_status) = g_new_status
            GROUP BY style, color, oracle_region,
                     start_date, end_date, supplier_name,
                     supplier_site_code
              HAVING COUNT (*) > 1;

        -- Cursor to retrieve sourcing rule stage records which are new, failed validation or failed API call
        CURSOR c_sr_creation IS
            SELECT ROWID rowxx, style, color,
                   --region --commented after staging table structure change,
                   oracle_region region, org_id, --Start Modification by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
                                                 --start_date,
                                                 --end_date,
                                                 -- PLM_START_DATE -- Start
                                                 --DECODE (source, 'PLM', TRUNC (SYSDATE), start_date)
                                                 start_date,
                   -- PLM_START_DATE -- End
                   DECODE (source, 'PLM', NULL, end_date) end_date, --End Modification by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
                                                                    supplier_name, vendor_id,
                   supplier_site_code, vendor_site_id, sourcing_rule_id,
                   source --Added by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
              FROM xxdo_sourcing_rule_stg
             WHERE     NVL (record_status, g_new_status) IN
                           (g_valid_success_status, g_sr_error_status, g_sr_update_error_status)
                   -- AND run_id IS NOT NULL                           --for testing
                   AND UPPER (oracle_region) != 'GLOBAL';

        -- Cursor to retrieve  stage records for assignment creation; records which are in rule created or failed API call status
        CURSOR c_sra_creation IS
            SELECT ROWID rowxx, style, color,
                   --region --commented after staging table structure change,
                   oracle_region region, org_id, start_date,
                   end_date, supplier_name, vendor_id,
                   supplier_site_code, vendor_site_id, assignment_set_id,
                   sourcing_rule_id
              FROM xxdo_sourcing_rule_stg STG
             WHERE     NVL (record_status, g_new_status) IN
                           (g_sr_success_status, g_sr_update_success_status, g_assign_error_status)
                   AND UPPER (oracle_region) != 'GLOBAL';



        -- Cursor to loop through all inv orgs for a given region
        CURSOR c_rg_io (ip_region VARCHAR2)
        IS
            /*--Commented below query for change 6.0
            SELECT DISTINCT ood.organization_id, ood.organization_code
              FROM po_lookup_types typ,
                   po_lookup_codes cd,
                   org_organization_definitions ood
             WHERE     typ.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
                   AND typ.lookup_type = cd.lookup_type
                   AND cd.attribute1 = ip_region
                   AND UPPER (cd.attribute2) = 'INVENTORY ORGANIZATION'
                   AND cd.attribute3 = ood.organization_code
                   ;
             */
            --Added below query for change 6.0
            SELECT DISTINCT mp.organization_id, mp.organization_code
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
                   AND flv.language = 'US'
                   AND flv.attribute1 = ip_region
                   AND UPPER (flv.attribute2) = 'INVENTORY ORGANIZATION'
                   AND flv.attribute3 = mp.organization_code
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1);

        -- Cursor to loop through all inventory categories for a given style and color
        CURSOR c_cat (ip_style             VARCHAR2,
                      ip_color             VARCHAR2,
                      ip_rule_start_date   DATE)
        IS
            SELECT mc.category_id
              FROM mtl_categories mc
             WHERE     mc.structure_id = 101         -- Inventory Category Set
                   AND mc.attribute7 = ip_style
                   AND mc.attribute8 = ip_color
                   AND NVL (ip_rule_start_date, SYSDATE) <
                       NVL (mc.disable_date,
                            NVL (ip_rule_start_date, SYSDATE) + 1);

        -- Cursor to summarize count by record status for printing purpose
        CURSOR c_op IS
              SELECT record_status, COUNT (*) record_count
                FROM xxdo_sourcing_rule_stg
            GROUP BY record_status;

        CURSOR C_ERR_REC IS
            SELECT *
              FROM xxdo_sourcing_rule_stg
             WHERE record_status IN (g_valid_error_status, g_sr_error_status, g_assign_error_status,
                                     g_sr_update_error_status);

        -- AND run_id IS NOT NULL;

        CURSOR C_OUTPUT_REC IS SELECT * FROM xxdo_sourcing_rule_stg;

        --Start Modification by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
        CURSOR C_CHECK_PLM_UPDATE (p_style            IN VARCHAR2,
                                   p_color            IN VARCHAR2,
                                   p_region           IN VARCHAR2,
                                   p_vendor_id        IN NUMBER,
                                   p_vendor_site_id   IN NUMBER)
        IS
            SELECT COUNT (*)
              FROM mrp_sr_source_org_v msso, mrp_sourcing_rules msr, mrp_sr_receipt_org msro
             WHERE     msr.sourcing_rule_id = msro.sourcing_rule_id
                   AND msro.sr_receipt_id = msso.sr_receipt_id
                   AND msso.vendor_id = p_vendor_id
                   AND msso.vendor_site_id = p_vendor_site_id
                   AND sourcing_rule_name =
                       p_style || '-' || p_color || '-' || p_region
                   AND TRUNC (SYSDATE) BETWEEN effective_date
                                           AND NVL (disable_date, SYSDATE);

        -- STOP_PLM_RULE_UPDATE -- Start
        CURSOR cur_plm_sourcing IS
            SELECT ROWID rowxx, style, color,
                   oracle_region region, start_date, END_DATE,
                   vendor_id, vendor_site_id, sourcing_rule_id,
                   supplier_name, supplier_site_code
              FROM xxdo_sourcing_rule_stg
             WHERE     NVL (record_status, g_new_status) IN (g_new_status)
                   -- AND run_id IS NOT NULL                           --for testing
                   AND UPPER (oracle_region) != 'GLOBAL'
                   AND source = 'PLM';
    -- STOP_PLM_RULE_UPDATE -- End

    --End Modification by BT Technology Team v2.0 for CR 118 on 20-AUG-2015

    BEGIN
        -- *********** Pseudo Logic ***********
        -- Check for extraction mode, if Y then call extraction routine
        -- Delete duplicate stage records in new status
        -- Loop through stage table
        -- Do validation
        -- Update stage table
        -- End validation
        -- End loop
        -- Check whether this is run in validation mode
        -- If in validation mode then quit program
        -- Else
        -- Loop through validated record
        -- Invoke sourcing rule creation wrapper
        -- Update stage table
        -- for records with successful rule creation call assignment wrapper
        -- Update stage table
        -- end loop
        -- **************************************

        -- **************************************
        --  Find and delete duplicate records in stage table
        print_message ('Extraction Mode = ' || extract_data_flag);

        IF extract_data_flag = 'Y'
        THEN
            IF ip_assignment_set_id IS NULL OR ip_db_link_name IS NULL
            THEN
                print_message (
                    'DB Link Name and Legacy Assignment Set ID must be provided. Exiting program!');
                RAISE_APPLICATION_ERROR (-20001, 'Missing Parameter');
            ELSE
                extract_data (ip_assignment_set_id   => ip_assignment_set_id,
                              ip_db_link_name        => ip_db_link_name);
            END IF;
        END IF;

        --********************************************************
        FEED_ORACLE_REGION (errbuf, retcode);       --to populate orcle region

        POPULATE_GLOBAL_RG_RECORDS; -----TO POPULATE RECORDS FOR 'GLOBAL' REGION


        --*******************************************************
        --  Find and delete duplicate records in stage table
        --print_message ('Starting delete of duplicate records');

        FOR c_sd IN c_stg_dup
        LOOP
            -- Delete all duplicate records first
            DELETE FROM
                xxdo_sourcing_rule_stg
                  WHERE     NVL (style, 'XX') = NVL (c_sd.style, 'XX')
                        AND NVL (color, 'XX') = NVL (c_sd.color, 'XX')
                        AND NVL (oracle_region, 'XX') =
                            NVL (c_sd.region, 'XX')
                        AND NVL (start_date, SYSDATE) =
                            NVL (c_sd.start_date, SYSDATE)
                        AND NVL (end_date, SYSDATE) =
                            NVL (c_sd.end_date, SYSDATE)
                        AND NVL (supplier_name, 'XX') =
                            NVL (c_sd.supplier_name, 'XX')
                        AND NVL (supplier_site_code, 'XX') =
                            NVL (c_sd.supplier_site_code, 'XX');

            --v_delete_count := v_delete_count + SQL%ROWCOUNT;

            -- Now insert only one record
            INSERT INTO xxdo_sourcing_rule_stg (style, color, oracle_region,
                                                start_date, end_date, supplier_name, supplier_site_code, creation_date, --WHO_COLUMNS
                                                                                                                        created_by, last_update_date, last_updated_by, last_update_login
                                                , request_id)
                 VALUES (c_sd.style, c_sd.color, c_sd.region,
                         c_sd.start_date, c_sd.end_date, c_sd.supplier_name,
                         c_sd.supplier_site_code, SYSDATE, g_num_user_id,
                         SYSDATE, g_num_user_id, g_num_login_id,
                         g_num_request_id);

            COMMIT;
        END LOOP;

        -- END removing duplicate record in stage table

        --*******************************************************
        print_message ('Starting validation of stage records');

        -- **************************************
        -- Start validation
        -- Reset all previously failed validation record to new status

        IF reprocess_err_records = 'Y'
        THEN                                       -- REPROCESS_PARAM -- Start
            UPDATE xxdo_sourcing_rule_stg
               SET record_status = g_new_status, last_update_date = SYSDATE, -- WHO_COLUMNS
                                                                             last_updated_by = g_num_user_id,
                   last_update_login = g_num_login_id, request_id = g_num_request_id
             WHERE     NVL (record_status, g_new_status) IN
                           (g_valid_error_status)
                   AND ORACLE_region != 'GLOBAL';

            COMMIT;

            g_valid_reprocess_status   := 'VALIDATION ERROR';
        ELSE
            g_valid_reprocess_status   := 'NEW';
        END IF;                                      -- REPROCESS_PARAM -- End

        -- Reset complete

        -- **************************************
        -- Validation 1.1 - Check region against lookup to find OU and assignment set
        FOR c_rg IN c_region
        LOOP
            BEGIN
                -- Get orgID of mapped region from lookup
                v_ou_org_id   := get_org_id_for_region (c_rg.region);

                UPDATE xxdo_sourcing_rule_stg
                   SET error_message = '', last_update_date = SYSDATE, -- WHO_COLUMNS
                                                                       last_updated_by = g_num_user_id,
                       last_update_login = g_num_login_id, request_id = g_num_request_id
                 WHERE     oracle_region = c_rg.region
                       AND NVL (record_status, g_new_status) IN --(g_new_status, g_valid_error_status);
                               (g_new_status, g_valid_reprocess_status); -- REPROCESS_PARAM

                IF NOT v_ou_org_id = -999
                THEN
                    -- Mapping found, update stage table with the found ID
                    UPDATE xxdo_sourcing_rule_stg
                       SET org_id = v_ou_org_id, last_update_date = SYSDATE, -- WHO_COLUMNS
                                                                             last_updated_by = g_num_user_id,
                           last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE     oracle_region = c_rg.region
                           AND NVL (record_status, g_new_status) IN --(g_new_status, g_valid_error_status);
                                   (g_new_status, g_valid_reprocess_status); -- REPROCESS_PARAM

                    COMMIT;
                ELSE
                    v_message   :=
                           'OU Mapping not found in PO lookup XXDO_SOURCING_RULE_REGION_MAP for region = '
                        || c_rg.region;

                    -- Mapping not found or other problems, update stage status
                    UPDATE xxdo_sourcing_rule_stg
                       SET record_status = g_valid_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE     oracle_region = c_rg.region
                           AND NVL (record_status, g_new_status) IN --(g_new_status, g_valid_error_status);
                                   (g_new_status, g_valid_reprocess_status); -- REPROCESS_PARAM

                    COMMIT;
                END IF;
            END;
        END LOOP;

        -- END Validation 1.1 - Check region against lookup
        --*******************************************************

        --*******************************************************
        -- Validation 1.2 - Check region against lookup for inv org
        FOR c_rg IN c_region
        LOOP
            BEGIN
                --            IF NOT inv_org_found_for_region (c_rg.region) -- ACTIVE_STYLE
                IF NOT get_inv_org_id_for_region (c_rg.region, v_inv_org_id) -- ACTIVE_STYLE
                THEN
                    v_message   :=
                           'No valid inventory org mapping found in PO lookup XXDO_SOURCING_RULE_REGION_MAP for region = '
                        || c_rg.region;

                    -- Mapping not found or other problems, update stage status
                    UPDATE xxdo_sourcing_rule_stg
                       SET record_status = g_valid_error_status, error_message = ERROR_MESSAGE || ' ,' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE     oracle_region = c_rg.region
                           AND NVL (record_status, g_new_status) IN --  (g_new_status, g_valid_error_status);
                                   (g_new_status, g_valid_reprocess_status); -- REPROCESS_PARAM


                    COMMIT;
                ELSE
                    --START Validate whether the style colors are Active or Planned in Oracle
                    FOR style_colors_rec IN c_style_colors (c_rg.region)
                    LOOP
                        IF NOT is_valid_style_color (style_colors_rec.style,
                                                     style_colors_rec.color,
                                                     v_inv_org_id)
                        THEN
                            v_message   :=
                                   'Style/Color is not valid in Oracle for the region = '
                                || c_rg.region;


                            UPDATE xxdo_sourcing_rule_stg
                               SET record_status = g_valid_error_status, error_message = ERROR_MESSAGE || ' ,' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                                   last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                             WHERE     oracle_region = c_rg.region
                                   AND style = style_colors_rec.style
                                   AND color = style_colors_rec.color
                                   AND NVL (record_status, g_new_status) IN --  (g_new_status, g_valid_error_status);
                                           (g_new_status, g_valid_reprocess_status); -- REPROCESS_PARAM
                        END IF;
                    END LOOP;

                    -- Commit the changes
                    COMMIT;
                END IF;
            END;
        END LOOP;


        -- END Validation 1.2 - Check region against lookup for inv org
        --*******************************************************

        --*******************************************************
        -- Validation 1.3 - Check region for mapped assignment set
        FOR c_rg IN c_region
        LOOP
            BEGIN
                -- Get orgID of mapped region from lookup
                v_assignment_set_id   :=
                    get_assignment_id_for_region (c_rg.region);

                IF NOT v_assignment_set_id = -999
                THEN
                    -- Mapping found, update stage table with the found ID
                    UPDATE xxdo_sourcing_rule_stg
                       SET assignment_set_id = v_assignment_set_id, last_update_date = SYSDATE, -- WHO_COLUMNS
                                                                                                last_updated_by = g_num_user_id,
                           last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE     oracle_region = c_rg.region
                           AND NVL (record_status, g_new_status) IN -- (g_new_status, g_valid_error_status);
                                   (g_new_status, g_valid_reprocess_status); -- REPROCESS_PARAM


                    COMMIT;
                ELSE
                    v_message   :=
                           'No assignment set found or more than 1 found for region = '
                        || c_rg.region;

                    -- Mapping not found or other problems, update stage status
                    UPDATE xxdo_sourcing_rule_stg
                       SET record_status = g_valid_error_status, error_message = ERROR_MESSAGE || ' ,' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE     oracle_region = c_rg.region
                           AND NVL (record_status, g_new_status) IN -- (g_new_status, g_valid_error_status);
                                   (g_new_status, g_valid_reprocess_status); -- REPROCESS_PARAM


                    COMMIT;
                END IF;
            END;
        END LOOP;

        -- Validation 1.3 - Check region for mapped assignment set
        --*******************************************************

        --*******************************************************
        -- Validation 2 - Check supplier and site for given region/OU
        FOR c_s IN c_sup
        LOOP
            -- Reset variables
            v_vendor_id        := NULL;
            v_vendor_site_id   := NULL;

            BEGIN
                -- Get ID of given supplier and site
                IF get_supplier_and_site_id (c_s.supplier_name,
                                             c_s.supplier_site_code,
                                             c_s.org_id,
                                             c_s.start_date,
                                             v_vendor_id,
                                             v_vendor_site_id)
                THEN
                    -- Success, update stage table
                    UPDATE xxdo_sourcing_rule_stg
                       SET vendor_id = v_vendor_id, vendor_site_id = v_vendor_site_id, last_update_date = SYSDATE, -- WHO_COLUMNS
                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE     supplier_name = c_s.supplier_name
                           AND supplier_site_code = c_s.supplier_site_code
                           AND org_id = c_s.org_id
                           AND NVL (record_status, g_new_status) IN -- (g_new_status, g_valid_error_status);
                                   (g_new_status, g_valid_reprocess_status); -- REPROCESS_PARAM


                    COMMIT;
                ELSE
                    -- Problem with supplier or site
                    v_message   :=
                           'Supplier or site not found. Validated against org_id = '
                        || c_s.org_id;

                    -- Mapping not found or other problems, update stage status
                    UPDATE xxdo_sourcing_rule_stg
                       SET record_status = g_valid_error_status, error_message = ERROR_MESSAGE || ' ,' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE     supplier_name = c_s.supplier_name
                           AND supplier_site_code = c_s.supplier_site_code
                           AND org_id = c_s.org_id
                           AND NVL (record_status, g_new_status) IN -- (g_new_status, g_valid_error_status);
                                   (g_new_status, g_valid_reprocess_status); -- REPROCESS_PARAM

                    COMMIT;
                END IF;
            END;
        END LOOP;

        -- END Validation 2 - Check supplier and site for given region/OU
        --*******************************************************

        --*******************************************************
        --Validation 3 - Check if rule already exists
        /* FOR c_re IN c_rule_exists
         LOOP
            BEGIN
               IF rule_exists (c_re.style, c_re.color, c_re.region)
               THEN
                  v_message :=
                        'Rule already exists in system for rule name = '
                     || format_char (c_re.style)
                     || '-'
                     || format_char (c_re.color)
                     || '-'
                     || format_char (c_re.region);

                  UPDATE xxdo_sourcing_rule_stg
                     SET record_status = g_valid_error_status,
                         error_message = v_message
                   WHERE     format_char (style) = format_char (c_re.style)
                         AND format_char (color) = format_char (c_re.color)
                         AND format_char (region) = format_char (c_re.region)
                         AND NVL (record_status, g_new_status) IN
                                (g_new_status, g_valid_error_status);

                  COMMIT;
               END IF;
            END;
         END LOOP;*/
        --commented to run program in update mode

        --*******************************************************
        ---added to run program in update mode and to add more validation on dates
        FOR c_re IN c_val
        LOOP
            BEGIN
                IF TRUNC (C_RE.START_DATE) > TRUNC (C_RE.END_DATE)
                THEN
                    v_message   := 'Start date is greater than End Date';

                    IF C_RE.record_status IN
                           (g_sr_error_status, g_sr_update_error_status)
                    THEN
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_valid_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                         WHERE ROWID = c_re.rowxx;
                    ELSE
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_valid_error_status, error_message = ERROR_MESSAGE || ' ,' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                         WHERE ROWID = c_re.rowxx;
                    END IF;
                END IF;

                IF TRUNC (C_RE.START_DATE) < TRUNC (SYSDATE)
                THEN
                    v_message   := 'Start date is less than sysdate';

                    IF C_RE.record_status IN
                           (g_sr_error_status, g_sr_update_error_status)
                    THEN
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_valid_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                         WHERE ROWID = c_re.rowxx;
                    ELSE
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_valid_error_status, error_message = ERROR_MESSAGE || ' ,' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                         WHERE ROWID = c_re.rowxx;
                    END IF;
                END IF;

                IF rule_exists (c_re.style, c_re.color, c_re.region)
                THEN
                    BEGIN
                        SELECT sourcing_rule_id
                          INTO v_sourcing_rule_id
                          FROM mrp_sourcing_rules
                         WHERE sourcing_rule_name =
                                  c_re.style
                               || '-'
                               || c_re.color
                               || '-'
                               || c_re.region;

                        UPDATE xxdo_sourcing_rule_stg
                           SET sourcing_rule_id = v_sourcing_rule_id, last_update_date = SYSDATE, -- WHO_COLUMNS
                                                                                                  last_updated_by = g_num_user_id,
                               last_update_login = g_num_login_id, request_id = g_num_request_id
                         WHERE ROWID = c_re.rowxx;

                        /*  IF    GET_END_DATE (c_re.style, c_re.color, c_re.region,c_re.START_DATE) >
                                   TRUNC (NVL (c_re.START_DATE, SYSDATE + 1))
                             OR c_re.START_DATE < SYSDATE
                          THEN
                             v_message :=
                                'start date is past date or less than end date/start date of old active sourcing rule receiving org';

                             UPDATE xxdo_sourcing_rule_stg
                                SET record_status = g_valid_error_status,
                                    error_message = ERROR_MESSAGE || ' ,' || v_message
                              WHERE     ROWID = c_re.rowxx
                                    AND NVL (record_status, g_new_status) IN
                                           (g_new_status, g_valid_error_status);
                          END IF;*/

                        -- Commented by Infosys on 19Oct2016 (Start) -- Ver 4.0

                        -- Uncommented since these validations are required for PLM source
                        -- PLM_START_DATE - Start

                        IF     GET_END_DATE (c_re.style, c_re.color, c_re.region
                                             , c_re.START_DATE) >=
                               TRUNC (SYSDATE)
                           AND TRUNC (c_re.START_DATE) < TRUNC (SYSDATE + 1)
                        THEN
                            v_message   :=
                                'can not end date old active sourcing rule receiving org at less than sysdate';

                            IF C_RE.record_status IN
                                   (g_sr_error_status, g_sr_update_error_status)
                            THEN
                                UPDATE xxdo_sourcing_rule_stg
                                   SET record_status = g_valid_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                                       last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                                 WHERE ROWID = c_re.rowxx;
                            ELSE
                                UPDATE xxdo_sourcing_rule_stg
                                   SET record_status = g_valid_error_status, error_message = ERROR_MESSAGE || ' ,' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                                       last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                                 WHERE ROWID = c_re.rowxx;
                            END IF;
                        END IF;



                        IF NOT GET_START_VALIDATION (c_re.style, c_re.color, c_re.region
                                                     , c_re.START_DATE)
                        THEN
                            v_message   := 'This start date already exist';

                            IF C_RE.record_status IN
                                   (g_sr_error_status, g_sr_update_error_status)
                            THEN
                                UPDATE xxdo_sourcing_rule_stg
                                   SET record_status = g_valid_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                                       last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                                 WHERE ROWID = c_re.rowxx;
                            ELSE
                                UPDATE xxdo_sourcing_rule_stg
                                   SET record_status = g_valid_error_status, error_message = ERROR_MESSAGE || ' ,' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                                       last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                                 WHERE ROWID = c_re.rowxx;
                            END IF;
                        END IF;
                    -- PLM_START_DATE - End

                    -- Commented by Infosys on 19Oct2016(End) -- Ver 4.0

                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            v_message   :=
                                   'Rule already exists in system for rule name = '
                                || c_re.style
                                || '-'
                                || c_re.color
                                || '-'
                                || c_re.region
                                || ' but no_data_found exception';

                            UPDATE xxdo_sourcing_rule_stg
                               SET record_status = g_valid_error_status, error_message = ERROR_MESSAGE || ' ,' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                                   last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                             WHERE ROWID = c_re.rowxx;

                            COMMIT;
                    END;
                END IF;
            END;
        END LOOP;

        -- END Validation 3 - Check if rule already exists

        -- STOP_PLM_RULE_UPDATE -- Start
        -- Check whether the sourcing rule exists for the same supplier and site
        l_num_rule_exists   := 0;

        FOR plm_sourcing_rec IN cur_plm_sourcing
        LOOP
            BEGIN
                l_num_rule_exists   := 0;

                BEGIN
                    SELECT COUNT (1)
                      INTO l_num_rule_exists
                      FROM apps.mrp_sr_source_org source_org, apps.mrp_sr_receipt_org receipt_org, apps.mrp_sr_assignments msa
                     WHERE     msa.sourcing_rule_id =
                               plm_sourcing_rec.sourcing_rule_id
                           AND receipt_org.sourcing_rule_id(+) =
                               msa.sourcing_rule_id
                           AND receipt_org.receipt_organization_id IS NULL
                           AND plm_sourcing_rec.start_date BETWEEN NVL (
                                                                       receipt_org.effective_date,
                                                                         plm_sourcing_rec.start_date
                                                                       - 1)
                                                               AND NVL (
                                                                       receipt_org.disable_date,
                                                                         plm_sourcing_rec.start_date
                                                                       + 1)
                           AND source_org.sr_receipt_id(+) =
                               receipt_org.sr_receipt_id
                           AND source_org.source_organization_id IS NULL
                           AND source_org.vendor_id =
                               plm_sourcing_rec.vendor_id
                           AND source_org.vendor_site_id =
                               plm_sourcing_rec.vendor_site_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_rule_exists   := 0;
                END;

                IF l_num_rule_exists > 0
                THEN
                    v_message   :=
                        'Rule already exists in system for the same supplier and site';

                    UPDATE xxdo_sourcing_rule_stg
                       SET record_status = g_valid_error_status, error_message = v_message
                     WHERE ROWID = plm_sourcing_rec.rowxx;

                    COMMIT;
                END IF;
            END;
        END LOOP;

        --commented to run program in update mode


        -- STOP_PLM_RULE_UPDATE -- End


        --*******************************************************
        -- End of all validations, mark the rest of the records as validated
        -- --FIX_VALIDATIONS -- If all the validations are successful, the vendor and vendor site ids will be populated
        -- Markd only those records as Validation success
        UPDATE xxdo_sourcing_rule_stg
           SET record_status = g_valid_success_status, error_message = NULL, last_update_date = SYSDATE, -- WHO_COLUMNS
               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
         WHERE     NVL (record_status, g_new_status) = g_new_status
               AND vendor_id IS NOT NULL             --FIX_VALIDATIONS - Start
               AND vendor_site_id IS NOT NULL         --FIX_VALIDATIONS -- End
               AND ORACLE_REGION != 'GLOBAL';

        COMMIT;

        --*******************************************************

        print_message ('End validation. Check for validation mode');

        IF validation_only_mode = 'Y'
        THEN
            -- Running in validation only mode, do not call API
            print_message ('Validation only mode. Exiting program');
        ELSE
            -- ***************************************
            -- Not in validation only mode
            -- Start looping through all validated records and call API

            print_message (
                'Not in validation only mode. Starting loop to go through all validated records to create sourcing rules');



            fnd_global.apps_initialize (fnd_global.user_id,
                                        fnd_global.resp_id,
                                        fnd_global.resp_appl_id);
            mo_global.init ('PO');

            printmessage ('Run program :');

            V_SKP_SRC_ASSN   := NULL;                                --Ver 4.0

            -- First complete all rule creation
            FOR c IN c_sr_creation
            LOOP
                IF rule_exists (c.style, c.color, c.region)
                -- AND c.source <> 'PLM' --Added by BT Technology Team v2.0 for CR 118 on 20-AUG-2015  -- Commented by Infosys on 19Oct2016 -- Ver 4.0
                --ADDED IF clause to add UPDATE mode
                THEN
                    print_message ('INSIDE LOOP');



                    -- Increment commit counter
                    v_commit_counter                                := v_commit_counter + 1;
                    v_count                                         := 1;
                    -- Reset Variables
                    v_message                                       := NULL;
                    v_organization_id                               := NULL;
                    v_source_type                                   := NULL;
                    v_source_org_id                                 := NULL;
                    V_2ND_MAX_END_DATE                              := NULL;

                    -- ***************************************
                    -- Initialize variables and types
                    v_receiving_org_tbl                             :=
                        mrp_sourcing_rule_pub.g_miss_receiving_org_tbl;
                    v_shipping_org_tbl                              :=
                        mrp_sourcing_rule_pub.g_miss_shipping_org_tbl;

                    -- Set Planning Active Flag
                    v_planning_active_flag                          := 1; -- Planning active = 'Y'

                    --===========================================
                    -- Set Header Level API Variables
                    v_sourcing_rule_rec                             :=
                        mrp_sourcing_rule_pub.g_miss_sourcing_rule_rec;

                    /*v_sourcing_rule_rec.sourcing_rule_name :=
                          format_char (c.style)
                       || '-'
                       || format_char (c.color)
                       || '-'
                       || format_char (c.region);
                    v_sourcing_rule_rec.description := NULL;
                    v_sourcing_rule_rec.organization_id := NULL; -- All Orgs, not required
                    v_sourcing_rule_rec.planning_active := v_planning_active_flag;
                    v_sourcing_rule_rec.status := 1;              -- Update record
                    v_sourcing_rule_rec.sourcing_rule_type := 1;*/
                    -- 1:Sourcing Rule 2:Bill Of Distribution


                    v_sourcing_rule_rec.sourcing_rule_id            :=
                        c.sourcing_rule_id;
                    v_sourcing_rule_rec.operation                   := 'UPDATE';



                    --===============================================
                    print_message (
                           'BEFORE IF'
                        || c.color
                        || ', '
                        || c.style
                        || ', '
                        || c.region);

                    /* IF rule_source_exists (
                           c.sourcing_rule_id,
                           c.vendor_id,
                           c.vendor_site_id,
                           GET_END_DATE (c.style, c.color, c.region,c.start_date))
                     THEN
                        BEGIN
                           print_message ('INSIDE IF'||GET_END_DATE (c.style, c.color, c.region,c.start_date));

                           SELECT NVL((SELECT SR_RECEIPT_ID

                             FROM MRP_SR_RECEIPT_ORG
                            WHERE     sourcing_rule_id =
                                         v_sourcing_rule_rec.sourcing_rule_id
                                  AND DISABLE_DATE IS NULL),

                          ( SELECT SR_RECEIPT_ID

                             FROM MRP_SR_RECEIPT_ORG
                            WHERE     sourcing_rule_id =
                                         v_sourcing_rule_rec.sourcing_rule_id
                                  AND TRUNC (DISABLE_DATE) =
                                         GET_END_DATE (c.style, c.color, c.region,c.start_date)))
                                         INTO V_SR_RECEIPT_ID
                                         FROM DUAL;

                           v_receiving_org_tbl (v_count).SR_RECEIPT_ID :=
                              V_SR_RECEIPT_ID;
                           v_receiving_org_tbl (v_count).disable_date := c.end_date;
                           v_receiving_org_tbl (v_count).operation := 'UPDATE';
                        EXCEPTION
                           WHEN NO_DATA_FOUND
                           THEN
                           v_message := sqlerrm || 'l_1';
                              UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_sr_update_error_status,
                               error_message = v_message
                         WHERE ROWID = c.rowxx;
                        END;
                     ELSE*/
                    print_message (   'INSIDE ELSE END DATE'
                                   || GET_END_DATE (c.style, c.color, c.region
                                                    , c.start_date));

                    --===============================================
                    -- Set Receive Level API Variables
                    -- Since it is for All Orgs, only 1 record will be UPDATED
                    /* v_receiving_org_tbl (1).receipt_organization_id := NULL; -- All Orgs, not required
                     v_receiving_org_tbl (1).effective_date :=
                        NVL (c_UPDATE.start_date, SYSDATE);*/
                    BEGIN
                        SELECT NVL (
                                   (SELECT SR_RECEIPT_ID
                                      FROM MRP_SR_RECEIPT_ORG
                                     WHERE     sourcing_rule_id =
                                               v_sourcing_rule_rec.sourcing_rule_id
                                           AND DISABLE_DATE IS NULL),
                                   (SELECT SR_RECEIPT_ID
                                      FROM MRP_SR_RECEIPT_ORG
                                     WHERE     sourcing_rule_id =
                                               v_sourcing_rule_rec.sourcing_rule_id
                                           AND TRUNC (DISABLE_DATE) =
                                               GET_END_DATE (c.style, c.color, c.region
                                                             , c.start_date)))
                          INTO V_SR_RECEIPT_ID
                          FROM DUAL;



                        IF GET_END_DATE (c.style, c.color, c.region,
                                         c.start_date) > TRUNC (SYSDATE)
                        THEN
                            IF TRUNC (c.start_date) <
                               GET_MAX_START_DATE (c.style,
                                                   c.color,
                                                   c.region)
                            THEN
                                SELECT TRUNC (MAX (MSRO.disable_date))
                                  INTO V_2ND_MAX_END_DATE
                                  FROM MRP_SR_RECEIPT_ORG msro, mrp_sourcing_rules msr
                                 WHERE     msro.sourcing_rule_id =
                                           v_sourcing_rule_rec.sourcing_rule_id
                                       AND MSRO.disable_date !=
                                           (SELECT TRUNC (MAX (MSRO.disable_date))
                                              FROM MRP_SR_RECEIPT_ORG msro, mrp_sourcing_rules msr
                                             WHERE msro.sourcing_rule_id =
                                                   v_sourcing_rule_rec.sourcing_rule_id);


                                v_receiving_org_tbl (v_count).effective_date   :=
                                    V_2ND_MAX_END_DATE + 1;
                            END IF;

                            v_receiving_org_tbl (v_count).disable_date   :=
                                TRUNC (c.start_date) - 1;
                        ELSE
                            -- PLM_START_DATE -- Start
                            -- SOURCING_RULE_GAP --Start

                            IF c.source IN ('PLM', 'WEBADI')
                            THEN
                                v_receiving_org_tbl (v_count).disable_date   :=
                                    TRUNC (c.start_date) - 1;
                            ELSE
                                -- PLM_START_DATE -- End
                                -- SOURCING_RULE_GAP -- End
                                v_receiving_org_tbl (v_count).disable_date   :=
                                      GET_END_DATE (c.style, c.color, c.region
                                                    , c.start_date)
                                    - 1;
                            END IF;
                        END IF;


                        v_receiving_org_tbl (v_count).SR_RECEIPT_ID   :=
                            V_SR_RECEIPT_ID;


                        v_receiving_org_tbl (v_count).operation   := 'UPDATE';
                        v_count                                   :=
                            v_count + 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            v_message   := SQLERRM || 'l_1';

                            UPDATE xxdo_sourcing_rule_stg
                               SET record_status = g_sr_update_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                                   last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                             WHERE ROWID = c.rowxx;

                            print_message ('INSIDE EXCEPTION');
                    END;

                    print_message ('AFTER BEGIN');


                    --===============================================
                    /*
                      --============================================
                      -- Set Shipping Level API Variables
                      v_source_type := 3;                                    -- Buy-From
                      v_shipping_org_tbl (1).RANK := 1;
                      v_shipping_org_tbl (1).allocation_percent := 100;
                      v_shipping_org_tbl (1).source_type := v_source_type;
                      v_shipping_org_tbl (1).source_organization_id := NULL; -- All Orgs, not required
                      v_shipping_org_tbl (1).vendor_id := c_UPDATE.vendor_id;
                      v_shipping_org_tbl (1).vendor_site_id := c_UPDATE.vendor_site_id;
                      v_shipping_org_tbl (1).receiving_org_index := 1;
                      v_shipping_org_tbl (1).operation := 'UPDATE';

                      --==============================================
                      */

                    --===============================================
                    -- Set Receive Level API Variables
                    -- Since it is for All Orgs, only 1 record will be created
                    --   v_receiving_org_tbl (v_count).receipt_organization_id := NULL; -- All Orgs, not required
                    v_receiving_org_tbl (v_count).effective_date    :=
                        CASE
                            WHEN GET_END_DATE (c.style, c.color, c.region,
                                               c.start_date) =
                                 TRUNC (SYSDATE)
                            THEN
                                NVL (c.start_date, SYSDATE + 1)
                            ELSE
                                --NVL (c.start_date, SYSDATE) --commented on 5thaug15
                                NVL (c.start_date, SYSDATE + 1)
                        END;



                    print_message (
                           'START DATE FOR CEATE'
                        || v_receiving_org_tbl (v_count).effective_date);
                    v_receiving_org_tbl (v_count).disable_date      :=
                        c.end_date;
                    v_receiving_org_tbl (v_count).operation         := 'CREATE';


                    --===============================================

                    --============================================
                    -- Set Shipping Level API Variables
                    v_source_type                                   := 3; -- Buy-From
                    v_shipping_org_tbl (1).RANK                     := 1;
                    v_shipping_org_tbl (1).allocation_percent       := 100;
                    v_shipping_org_tbl (1).source_type              :=
                        v_source_type;
                    v_shipping_org_tbl (1).source_organization_id   := NULL; -- All Orgs, not required
                    v_shipping_org_tbl (1).vendor_id                :=
                        c.vendor_id;
                    v_shipping_org_tbl (1).vendor_site_id           :=
                        c.vendor_site_id;
                    v_shipping_org_tbl (1).receiving_org_index      :=
                        v_count;
                    v_shipping_org_tbl (1).operation                :=
                        'CREATE';
                    -- END IF; --rule_source_exits end if


                    --==============================================

                    -- End Initializing variables and types
                    -- ***************************************

                    -- Invoke API wrapper procedure
                    sourcing_rule_upload (
                        ip_sourcing_rule_rec       => v_sourcing_rule_rec,
                        ip_sourcing_rule_val_rec   => v_sourcing_rule_val_rec,
                        ip_receiving_org_tbl       => v_receiving_org_tbl,
                        ip_receiving_org_val_tbl   => v_receiving_org_val_tbl,
                        ip_shipping_org_tbl        => v_shipping_org_tbl,
                        ip_shipping_org_val_tbl    => v_shipping_org_val_tbl,
                        x_sourcing_rule_rec        => x_sourcing_rule_rec,
                        x_sourcing_rule_val_rec    => x_sourcing_rule_val_rec,
                        x_receiving_org_tbl        => x_receiving_org_tbl,
                        x_receiving_org_val_tbl    => x_receiving_org_val_tbl,
                        x_shipping_org_tbl         => x_shipping_org_tbl,
                        x_shipping_org_val_tbl     => x_shipping_org_val_tbl,
                        x_return_status            => v_return_status,
                        x_api_message              => v_message);

                    IF v_return_status = fnd_api.g_ret_sts_success
                    THEN
                        -- API Success! Update stage
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_sr_update_success_status, sourcing_rule_id = x_sourcing_rule_rec.sourcing_rule_id, error_message = NULL,
                               last_update_date = SYSDATE,      -- WHO_COLUMNS
                                                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id,
                               request_id = g_num_request_id
                         WHERE ROWID = c.rowxx;

                        IF c.source = 'PLM'                         -- Ver 4.0
                        THEN
                            V_SKP_SRC_ASSN   := 'Y';
                        END IF;
                    ELSE
                        -- API Issue, update stage
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_sr_update_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                         WHERE ROWID = c.rowxx;
                    END IF;

                    -- Commit if the counter has reached the threshold
                    IF v_commit_counter = g_commit_count
                    THEN
                        COMMIT;
                        v_commit_counter   := 0;
                    END IF;

                    COMMIT;
                    print_message (
                        'End calling API for sourcing rule updation');
                -- End sourcing UPDATION
                --**************************************************************

                --**************************************************************
                --Start Modification by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
                ELSIF     rule_exists (c.style, c.color, c.region)
                      AND c.source = 'PLM'
                THEN
                    v_plm_update_count   := 0;
                -- Commented by Infosys on 19Oct2016 (Start) -- Ver 4.0

                /*   OPEN C_CHECK_PLM_UPDATE(c.style,
                                           c.color,
                                           c.region,
                                           c.vendor_id,
                                           c.vendor_site_id);
                   FETCH C_CHECK_PLM_UPDATE INTO v_plm_update_count;
                   CLOSE C_CHECK_PLM_UPDATE;

                   IF v_plm_update_count = 1 THEN
                     UPDATE xxdo_sourcing_rule_stg
                            SET record_status = g_sr_update_success_plm,
                                error_message = 'Success, Sourcing rule exist for the supplier and site combination in active status so not updating the record',
                              last_update_date = SYSDATE, -- WHO_COLUMNS
                              last_updated_by = g_num_user_id,
                              last_update_login = g_num_login_id,
                              request_id = g_num_request_id
                          WHERE ROWID = c.rowxx;
                   ELSE
                     UPDATE xxdo_sourcing_rule_stg
                            SET record_status = g_sr_update_error_plm,
                                error_message = 'Error, Sourcing rule exist for different supplier and site combination in active status so not updating the record',
                              last_update_date = SYSDATE, -- WHO_COLUMNS
                              last_updated_by = g_num_user_id,
                              last_update_login = g_num_login_id,
                              request_id = g_num_request_id
                          WHERE ROWID = c.rowxx;
                   END IF; */
                -- Commented by Infosys on 19Oct2016 (End) -- Ver 4.0


                --End Modification by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
                ELSE
                    -- Increment commit counter
                    v_commit_counter                                  := v_commit_counter + 1;
                    -- Reset Variables
                    v_message                                         := NULL;
                    v_organization_id                                 := NULL;
                    v_source_type                                     := NULL;
                    v_source_org_id                                   := NULL;

                    -- ***************************************
                    -- Initialize variables and types
                    v_receiving_org_tbl                               :=
                        mrp_sourcing_rule_pub.g_miss_receiving_org_tbl;
                    v_shipping_org_tbl                                :=
                        mrp_sourcing_rule_pub.g_miss_shipping_org_tbl;

                    -- Set Planning Active Flag
                    v_planning_active_flag                            := 1; -- Planning active = 'Y'

                    --===========================================
                    -- Set Header Level API Variables
                    v_sourcing_rule_rec                               :=
                        mrp_sourcing_rule_pub.g_miss_sourcing_rule_rec;
                    v_sourcing_rule_rec.sourcing_rule_name            :=
                        c.style || '-' || c.color || '-' || c.region;
                    v_sourcing_rule_rec.description                   := NULL;
                    v_sourcing_rule_rec.organization_id               := NULL; -- All Orgs, not required
                    v_sourcing_rule_rec.planning_active               :=
                        v_planning_active_flag;
                    v_sourcing_rule_rec.status                        := 1; -- Create New record
                    v_sourcing_rule_rec.sourcing_rule_type            := 1;
                    -- 1:Sourcing Rule 2:Bill Of Distribution
                    v_sourcing_rule_rec.operation                     := 'CREATE';
                    --===============================================

                    --===============================================
                    -- Set Receive Level API Variables
                    -- Since it is for All Orgs, only 1 record will be created
                    v_receiving_org_tbl (1).receipt_organization_id   := NULL; -- All Orgs, not required
                    v_receiving_org_tbl (1).effective_date            :=
                        -- NVL (c.start_date, SYSDATE);--commented on 5thaug15
                         NVL (c.start_date, SYSDATE + 1);
                    v_receiving_org_tbl (1).disable_date              :=
                        c.end_date;
                    v_receiving_org_tbl (1).operation                 :=
                        'CREATE';
                    --===============================================

                    --============================================
                    -- Set Shipping Level API Variables
                    v_source_type                                     := 3; -- Buy-From
                    v_shipping_org_tbl (1).RANK                       := 1;
                    v_shipping_org_tbl (1).allocation_percent         := 100;
                    v_shipping_org_tbl (1).source_type                :=
                        v_source_type;
                    v_shipping_org_tbl (1).source_organization_id     := NULL; -- All Orgs, not required
                    v_shipping_org_tbl (1).vendor_id                  :=
                        c.vendor_id;
                    v_shipping_org_tbl (1).vendor_site_id             :=
                        c.vendor_site_id;
                    v_shipping_org_tbl (1).receiving_org_index        := 1;
                    v_shipping_org_tbl (1).operation                  :=
                        'CREATE';
                    --==============================================

                    -- End Initializing variables and types
                    -- ***************************************

                    -- Invoke API wrapper procedure
                    sourcing_rule_upload (
                        ip_sourcing_rule_rec       => v_sourcing_rule_rec,
                        ip_sourcing_rule_val_rec   => v_sourcing_rule_val_rec,
                        ip_receiving_org_tbl       => v_receiving_org_tbl,
                        ip_receiving_org_val_tbl   => v_receiving_org_val_tbl,
                        ip_shipping_org_tbl        => v_shipping_org_tbl,
                        ip_shipping_org_val_tbl    => v_shipping_org_val_tbl,
                        x_sourcing_rule_rec        => x_sourcing_rule_rec,
                        x_sourcing_rule_val_rec    => x_sourcing_rule_val_rec,
                        x_receiving_org_tbl        => x_receiving_org_tbl,
                        x_receiving_org_val_tbl    => x_receiving_org_val_tbl,
                        x_shipping_org_tbl         => x_shipping_org_tbl,
                        x_shipping_org_val_tbl     => x_shipping_org_val_tbl,
                        x_return_status            => v_return_status,
                        x_api_message              => v_message);

                    IF v_return_status = fnd_api.g_ret_sts_success
                    THEN
                        -- API Success! Update stage
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_sr_success_status, sourcing_rule_id = x_sourcing_rule_rec.sourcing_rule_id, error_message = NULL,
                               last_update_date = SYSDATE,      -- WHO_COLUMNS
                                                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id,
                               request_id = g_num_request_id
                         WHERE ROWID = c.rowxx;
                    ELSE
                        -- API Issue, update stage
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_sr_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                         WHERE ROWID = c.rowxx;
                    END IF;

                    -- Commit if the counter has reached the threshold
                    IF v_commit_counter = g_commit_count
                    THEN
                        COMMIT;
                        v_commit_counter   := 0;
                    END IF;

                    print_message (
                        'End calling API for sourcing rule creation');
                END IF; ---------added to run in sourcing rule in 'UPDATE' mode
            END LOOP;

            COMMIT;

            -- End sourcing creation
            --**************************************************************

            --**************************************************************
            -- Now begin sourcing assignment creation
            print_message (
                'Starting loop to go through all validated records to create sourcing assignments');

            -- Commented since SR Assignment is not working for PLM source
            -- SRA_CREATION_PLM - Start
            --         IF NVL (V_SKP_SRC_ASSN, 'N') <> 'Y'
            --         THEN                                                        --Ver 4.0
            FOR ca IN c_sra_creation
            LOOP
                -- Reset Variables
                v_sl               := 0;
                v_message          := NULL;
                v_return_status    := NULL;
                v_assignment_tbl   :=
                    mrp_src_assignment_pub.G_MISS_ASSIGNMENT_TBL;
                -- Increment commit counter
                v_commit_counter   := v_commit_counter + 1;

                -- First loop through all possible inventory orgs for this region
                FOR c_io IN c_rg_io (ca.region)
                LOOP
                    -- Now for each of these inventory orgs, loop through all categories for this given style and color
                    FOR c_mc IN c_cat (ca.style, ca.color, ca.start_date)
                    LOOP
                        BEGIN
                            SELECT assignment_id
                              INTO v_assignment_id
                              FROM MRP_SR_ASSIGNMENTS
                             WHERE     category_set_id = 1
                                   AND assignment_type = 5
                                   AND sourcing_rule_type = 1
                                   AND organization_id = c_io.organization_id
                                   AND sourcing_rule_id = ca.sourcing_rule_id
                                   AND category_id = c_mc.category_id
                                   AND assignment_set_id =
                                       ca.assignment_set_id; --- ADDED FOR SOURCING RULE UPDATION LOGIC
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                BEGIN
                                    v_sl   := v_sl + 1;

                                    SELECT assignment_id
                                      INTO v_assignment_id
                                      FROM MRP_SR_ASSIGNMENTS
                                     WHERE     category_set_id = 1
                                           AND assignment_type = 5
                                           AND sourcing_rule_type = 1
                                           AND organization_id =
                                               c_io.organization_id
                                           AND category_id = c_mc.category_id
                                           AND assignment_set_id =
                                               ca.assignment_set_id; --- ADDED FOR assignment is there but sourcing rule is not assigned or updated

                                    v_assignment_tbl (v_sl).operation   :=
                                        'UPDATE';
                                    v_assignment_tbl (v_sl).assignment_id   :=
                                        v_assignment_id;
                                --====================================================
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        v_assignment_tbl (v_sl).operation   :=
                                            'CREATE';
                                END;

                                -- Set API Parameter values

                                v_assignment_tbl (v_sl).assignment_set_id   :=
                                    ca.assignment_set_id;
                                v_assignment_tbl (v_sl).assignment_type   :=
                                    5;                -- Category-Organization
                                --  v_assignment_tbl (v_sl).operation := 'CREATE';
                                v_assignment_tbl (v_sl).organization_id   :=
                                    c_io.organization_id;
                                v_assignment_tbl (v_sl).category_set_id   :=
                                    1;                --Inventory Category Set
                                v_assignment_tbl (v_sl).category_id   :=
                                    c_mc.category_id;
                                v_assignment_tbl (v_sl).sourcing_rule_id   :=
                                    ca.sourcing_rule_id;
                                v_assignment_tbl (v_sl).sourcing_rule_type   :=
                                    1;                      -- "Sourcing Rule"
                        END;
                    END LOOP;
                END LOOP;

                -- End setting all parameter values for this stage record, call API
                -- End Initializing variables and types
                -- ***************************************

                IF v_sl != 0
                THEN
                    -- Invoke API wrapper procedure
                    sourcing_rule_assignment (ip_assignment_set_rec => v_assignment_set_rec, ip_assignment_set_val_rec => v_assignment_set_val_rec, ip_assignment_tbl => v_assignment_tbl, ip_assignment_val_tbl => v_assignment_val_tbl, x_assignment_set_rec => x_assignment_set_rec, x_assignment_set_val_rec => x_assignment_set_val_rec, x_assignment_tbl => x_assignment_tbl, x_assignment_val_tbl => x_assignment_val_tbl, x_return_status => v_return_status
                                              , x_api_message => v_message);

                    -- print_message ('Return Status :'||nvl(v_return_status,'Blank')|| ' Last serial no :'||v_sl);

                    IF NVL (v_return_status, 'X') IN
                           (fnd_api.g_ret_sts_error, fnd_api.g_ret_sts_unexp_error)
                    THEN
                        -- API Issue, update stage
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_assign_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                         WHERE ROWID = ca.rowxx;
                    ELSE
                        -- API Success! Update stage
                        UPDATE xxdo_sourcing_rule_stg
                           SET record_status = g_assign_success_status, error_message = NULL, last_update_date = SYSDATE, -- WHO_COLUMNS
                               last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                         WHERE ROWID = ca.rowxx;
                    END IF;

                    -- Commit if the counter has reached the threshold
                    IF v_commit_counter = g_commit_count
                    THEN
                        COMMIT;
                        v_commit_counter   := 0;
                    END IF;
                ELSE
                    UPDATE xxdo_sourcing_rule_stg
                       SET record_status = g_assign_success_status, error_message = NULL, last_update_date = SYSDATE, -- WHO_COLUMNS
                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE ROWID = ca.rowxx;
                END IF;
            END LOOP;


            COMMIT;
            print_message ('End calling API for sourcing rule assignment');
        -- End sourcing assignment
        --**************************************************************
        --         END IF;                          -- <IF NVL(V_SKP_SRC_ASSN,'N')<>'Y'>
        -- SRA_CREATION_PLM - End

        END IF;

        FOR c1 IN c_op
        LOOP
            print_message (
                   'Record Status = '
                || c1.record_status
                || ', Count = '
                || c1.record_count
                || CHR (10));
        END LOOP;

        FOR C2 IN C_ERR_REC
        LOOP
            print_message (
                   'Record Status = '
                || c2.record_status
                || ' Error Message: '
                || c2.error_message
                || CHR (10)
                || ' for style, color, region, supplier, supplier site ,start date, end date and source: '
                || c2.style
                || ', '
                || c2.color
                || ', '
                || c2.oracle_region
                || ', '
                || c2.supplier_name
                || ', '
                || c2.supplier_site_code
                || ', '
                || c2.start_date
                || ', '
                || c2.end_date
                || ' and '
                || c2.source
                || CHR (10));
            NULL;
        END LOOP;

        FND_FILE.PUT_LINE (
            FND_FILE.OUTPUT,
               'Style'
            || '|'
            || 'Color'
            || '|'
            || 'Oracle_region'
            || '|'
            || 'Supplier_name'
            || '|'
            || 'Supplier_site_code'
            || '|'
            || 'Start_date'
            || '|'
            || 'End_date'
            || '|'
            || 'Source'
            || '|'
            || 'Record_status'
            || '|'
            || 'Error_message'
            || '|'
            || 'ASSSIGNMENT_SET_NAME');

        FOR C3 IN C_OUTPUT_REC
        LOOP
            BEGIN
                SELECT ASSIGNMENT_SET_NAME
                  INTO V_ASSSIGNMENT_SET_NAME
                  FROM MRP_ASSIGNMENT_SETS
                 WHERE ASSIGNMENT_SET_ID = C3.ASSIGNMENT_SET_ID;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    V_ASSSIGNMENT_SET_NAME   := NULL;
            END;

            FND_FILE.PUT_LINE (
                FND_FILE.OUTPUT,
                   c3.style
                || '|'
                || c3.color
                || '|'
                || c3.oracle_region
                || '|'
                || c3.supplier_name
                || '|'
                || c3.supplier_site_code
                || '|'
                || c3.start_date
                || '|'
                || c3.end_date
                || '|'
                || c3.source
                || '|'
                || c3.record_status
                || '|'
                || V_ASSSIGNMENT_SET_NAME
                || '|'
                || TRIM (c3.error_message));
        END LOOP;

        SEND_EMAIL_REPORT; --Added by BT Technology Team v2.0 for CR 118 on 20-AUG-2015
    EXCEPTION
        WHEN OTHERS
        THEN
            ERRBUF    := SQLERRM;
            RETCODE   := 2;
            print_message ('WHEN OTHERS IN MAIN CONV PROC :' || SQLERRM);
    END main_conv_proc;

    PROCEDURE sourcing_rule_upload (
        ip_sourcing_rule_rec           mrp_sourcing_rule_pub.sourcing_rule_rec_type,
        ip_sourcing_rule_val_rec       mrp_sourcing_rule_pub.sourcing_rule_val_rec_type,
        ip_receiving_org_tbl           mrp_sourcing_rule_pub.receiving_org_tbl_type,
        ip_receiving_org_val_tbl       mrp_sourcing_rule_pub.receiving_org_val_tbl_type,
        ip_shipping_org_tbl            mrp_sourcing_rule_pub.shipping_org_tbl_type,
        ip_shipping_org_val_tbl        mrp_sourcing_rule_pub.shipping_org_val_tbl_type,
        x_sourcing_rule_rec        OUT mrp_sourcing_rule_pub.sourcing_rule_rec_type,
        x_sourcing_rule_val_rec    OUT mrp_sourcing_rule_pub.sourcing_rule_val_rec_type,
        x_receiving_org_tbl        OUT mrp_sourcing_rule_pub.receiving_org_tbl_type,
        x_receiving_org_val_tbl    OUT mrp_sourcing_rule_pub.receiving_org_val_tbl_type,
        x_shipping_org_tbl         OUT mrp_sourcing_rule_pub.shipping_org_tbl_type,
        x_shipping_org_val_tbl     OUT mrp_sourcing_rule_pub.shipping_org_val_tbl_type,
        x_return_status            OUT VARCHAR2,
        x_api_message              OUT VARCHAR2)
    IS
        -- Define variables
        x_msg_count   NUMBER := 0;
        x_msg_data    VARCHAR2 (1000);
    BEGIN
        -- Clear message stack
        fnd_message.CLEAR;

        -- Call API
        mrp_sourcing_rule_pub.process_sourcing_rule (
            p_api_version_number      => 1.0,
            p_init_msg_list           => g_init_msg_list_flag,
            p_commit                  => g_api_commit_flag,
            x_return_status           => x_return_status,
            x_msg_count               => x_msg_count,
            x_msg_data                => x_msg_data,
            p_sourcing_rule_rec       => ip_sourcing_rule_rec,
            p_sourcing_rule_val_rec   => ip_sourcing_rule_val_rec,
            p_receiving_org_tbl       => ip_receiving_org_tbl,
            p_receiving_org_val_tbl   => ip_receiving_org_val_tbl,
            p_shipping_org_tbl        => ip_shipping_org_tbl,
            p_shipping_org_val_tbl    => ip_shipping_org_val_tbl,
            x_sourcing_rule_rec       => x_sourcing_rule_rec,
            x_sourcing_rule_val_rec   => x_sourcing_rule_val_rec,
            x_receiving_org_tbl       => x_receiving_org_tbl,
            x_receiving_org_val_tbl   => x_receiving_org_val_tbl,
            x_shipping_org_tbl        => x_shipping_org_tbl,
            x_shipping_org_val_tbl    => x_shipping_org_val_tbl);

        -- Check API Return Status
        IF NVL (x_return_status, fnd_api.g_ret_sts_error) !=
           fnd_api.g_ret_sts_success
        THEN
            -- API Failed, Get msg
            FOR i IN 1 .. x_msg_count
            LOOP
                x_api_message   :=
                       x_api_message
                    || ','
                    || fnd_msg_pub.get (p_msg_index   => i,
                                        p_encoded     => fnd_api.g_false);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- Unexpected Error
            x_api_message     :=
                   'Unexpected Error in Rule Creation API call : '
                || SUBSTR (SQLERRM, 1, 200);

            x_return_status   := fnd_api.g_ret_sts_error;
    END sourcing_rule_upload;

    PROCEDURE sourcing_rule_assignment (ip_assignment_set_rec mrp_src_assignment_pub.assignment_set_rec_type, ip_assignment_set_val_rec mrp_src_assignment_pub.assignment_set_val_rec_type, ip_assignment_tbl mrp_src_assignment_pub.assignment_tbl_type, ip_assignment_val_tbl mrp_src_assignment_pub.assignment_val_tbl_type, x_assignment_set_rec OUT mrp_src_assignment_pub.assignment_set_rec_type, x_assignment_set_val_rec OUT mrp_src_assignment_pub.assignment_set_val_rec_type, x_assignment_tbl OUT mrp_src_assignment_pub.assignment_tbl_type, x_assignment_val_tbl OUT mrp_src_assignment_pub.assignment_val_tbl_type, x_return_status OUT VARCHAR2
                                        , x_api_message OUT VARCHAR2)
    IS
        -- Define Variables
        -- For Standard API Parameters
        x_msg_count   NUMBER := 0;
        x_msg_data    VARCHAR2 (1000);
    BEGIN
        -- Clear Message stack
        fnd_message.CLEAR;

        -- Invoke standard API

        mrp_src_assignment_pub.process_assignment (
            p_api_version_number       => 1.0,
            p_init_msg_list            => g_init_msg_list_flag,
            p_return_values            => fnd_api.g_false,
            p_commit                   => g_api_commit_flag,
            x_return_status            => x_return_status,
            x_msg_count                => x_msg_count,
            x_msg_data                 => x_msg_data,
            p_assignment_set_rec       => ip_assignment_set_rec,
            p_assignment_set_val_rec   => ip_assignment_set_val_rec,
            p_assignment_tbl           => ip_assignment_tbl,
            p_assignment_val_tbl       => ip_assignment_val_tbl,
            x_assignment_set_rec       => x_assignment_set_rec,
            x_assignment_set_val_rec   => x_assignment_set_val_rec,
            x_assignment_tbl           => x_assignment_tbl,
            x_assignment_val_tbl       => x_assignment_val_tbl);

        -- Check API Return Status
        IF NVL (x_return_status, fnd_api.g_ret_sts_error) !=
           fnd_api.g_ret_sts_success
        THEN
            -- API Failed, Get msg
            FOR i IN 1 .. x_msg_count
            LOOP
                x_api_message   :=
                       x_api_message
                    || ','
                    || fnd_msg_pub.get (p_msg_index   => i,
                                        p_encoded     => fnd_api.g_false);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- Unexpected Error
            x_api_message     :=
                   'Unexpected Error in assignment creation API call : '
                || SUBSTR (SQLERRM, 1, 200);

            x_return_status   := fnd_api.g_ret_sts_error;
    END sourcing_rule_assignment;

    -- Function to validate region

    FUNCTION get_org_id_for_region (ip_region VARCHAR2)
        RETURN NUMBER
    IS
        v_ou_org_id   NUMBER;
    BEGIN
        --Commented the below query for change 6.0
        /*
        SELECT hou.organization_id
          INTO v_ou_org_id
          FROM po_lookup_types typ, PO_LOOKUP_CODES cd, hr_operating_units hou
         WHERE     typ.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
               AND typ.lookup_type = cd.lookup_type
               AND cd.attribute1 = ip_region
               AND UPPER (cd.attribute2) = 'OPERATING UNIT'
               AND cd.attribute3 = hou.name;
         */
        --Added below query for change 6.0
        SELECT hou.organization_id
          INTO v_ou_org_id
          FROM fnd_lookup_values flv, hr_operating_units hou
         WHERE     1 = 1
               AND flv.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
               AND flv.language = 'US'
               AND flv.attribute1 = ip_region
               AND UPPER (flv.attribute2) = 'OPERATING UNIT'
               AND flv.attribute3 = hou.name
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        RETURN v_ou_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN -999;
    END get_org_id_for_region;

    -- Function to validate region for assignment set

    FUNCTION get_assignment_id_for_region (ip_region VARCHAR2)
        RETURN NUMBER
    IS
        v_assignment_set_id   NUMBER;
        V_REGION              VARCHAR2 (20);
    BEGIN
        --------ADDED TO GET SAME ASSIGNMENT SET FOR 'US' AND 'JP' REGION--
        --IF ip_region IN ('US', 'JP') --Commented for change 6.0
        IF ip_region IN ('US', 'JP', 'MACAUEMEA')       --Added for change 6.0
        THEN
            V_REGION   := 'US-JP';
        ELSE
            V_REGION   := ip_region;
        END IF;

        ---------------------------------------------------------
        SELECT assignment_set_id
          INTO v_assignment_set_id
          FROM mrp_assignment_sets
         WHERE attribute1 = V_REGION;

        RETURN v_assignment_set_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN -999;
    END get_assignment_id_for_region;

    -- Function to validate region for Inv Org

    FUNCTION inv_org_found_for_region (ip_region VARCHAR2)
        RETURN BOOLEAN
    IS
        v_inv_count   NUMBER;
    BEGIN
        --Commented the below query for change 6.0
        /*
        SELECT COUNT (ood.organization_id)
          INTO v_inv_count
          FROM po_lookup_types typ,
               PO_LOOKUP_CODES cd,
               org_organization_definitions ood
         WHERE     typ.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
               AND typ.lookup_type = cd.lookup_type
               AND cd.attribute1 = ip_region
               AND UPPER (cd.attribute2) = 'INVENTORY ORGANIZATION'
               AND cd.attribute3 = ood.organization_code;
        */
        --Added below query for change 6.0
        SELECT COUNT (mp.organization_id)
          INTO v_inv_count
          FROM fnd_lookup_values flv, mtl_parameters mp
         WHERE     1 = 1
               AND flv.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
               AND flv.language = 'US'
               AND flv.attribute1 = ip_region
               AND UPPER (flv.attribute2) = 'INVENTORY ORGANIZATION'
               AND flv.attribute3 = mp.organization_code
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1);

        IF v_inv_count != 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END inv_org_found_for_region;

    -- Function to validate region for Inv Org

    FUNCTION get_inv_org_id_for_region (ip_region       VARCHAR2,
                                        op_org_id   OUT NUMBER)
        RETURN BOOLEAN
    IS
    BEGIN
        op_org_id   := 0;

        --Commented the below query for change 6.0
        /*
        SELECT ood.organization_id
          INTO op_org_id
          FROM po_lookup_types typ,
               PO_LOOKUP_CODES cd,
               org_organization_definitions ood
         WHERE     typ.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
               AND typ.lookup_type = cd.lookup_type
               AND cd.attribute1 = ip_region
               AND UPPER (cd.attribute2) = 'INVENTORY ORGANIZATION'
               AND cd.attribute3 = ood.organization_code
               AND ROWNUM < 2;
        */
        --Added below query for change 6.0
        SELECT mp.organization_id
          INTO op_org_id
          FROM fnd_lookup_values flv, mtl_parameters mp
         WHERE     1 = 1
               AND flv.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
               AND flv.language = 'US'
               AND flv.attribute1 = ip_region
               AND UPPER (flv.attribute2) = 'INVENTORY ORGANIZATION'
               AND flv.attribute3 = mp.organization_code
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE + 1)
               AND ROWNUM < 2;

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN FALSE;
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END get_inv_org_id_for_region;

    FUNCTION is_valid_style_color (ip_style        VARCHAR2,
                                   ip_color        VARCHAR2,
                                   ip_inv_org_id   NUMBER)
        RETURN BOOLEAN
    IS
        v_item_count   NUMBER;
    BEGIN
        SELECT COUNT (1)
          INTO v_item_count
          FROM mtl_categories mc, mtl_item_categories mic, mtl_system_items_b msi
         WHERE     1 = 1
               AND mc.structure_id = 101
               AND mc.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (mc.start_date_active, SYSDATE - 1)
                               AND NVL (mc.end_date_active, SYSDATE + 1)
               AND mc.attribute7 = ip_style
               AND mc.attribute8 = ip_color
               AND msi.organization_id = mic.organization_id
               AND msi.inventory_item_id = mic.inventory_item_id
               AND msi.organization_id = ip_inv_org_id
               AND mic.category_set_id = 1
               AND mc.category_id = mic.category_id
               AND msi.segment1 NOT LIKE '%ALL'
               AND msi.inventory_item_status_code IN ('Active', 'Planned');

        IF v_item_count > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END is_valid_style_color;

    -- Function to validate supplier and site

    FUNCTION get_supplier_and_site_id (ip_supplier_name VARCHAR2, ip_site_code VARCHAR2, ip_org_id NUMBER
                                       , ip_start_date DATE, x_vendor_id OUT NUMBER, x_vendor_site_id OUT NUMBER)
        RETURN BOOLEAN
    IS
    BEGIN
        SELECT aps.vendor_id, ass.vendor_site_id
          INTO x_vendor_id, x_vendor_site_id
          FROM ap_suppliers aps, ap_supplier_sites_all ass
         WHERE     aps.enabled_flag = 'Y'
               AND NVL (ip_start_date, SYSDATE) BETWEEN aps.start_date_active
                                                    AND NVL (
                                                            aps.end_date_active,
                                                              NVL (
                                                                  ip_start_date,
                                                                  SYSDATE)
                                                            + 1)
               AND aps.vendor_id = ass.vendor_id
               AND ass.org_id = ip_org_id
               AND NVL (ip_start_date, SYSDATE) <
                   NVL (ass.inactive_date, NVL (ip_start_date, SYSDATE) + 1)
               AND aps.vendor_name = ip_supplier_name
               AND ass.vendor_site_code = ip_site_code;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_vendor_id        := NULL;
            x_vendor_site_id   := NULL;
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'When others :' || SQLERRM);

            RETURN FALSE;
    END get_supplier_and_site_id;

    -- Function to check if rule already exists

    FUNCTION rule_exists (ip_style    VARCHAR2,
                          ip_color    VARCHAR2,
                          ip_region   VARCHAR2)
        RETURN BOOLEAN
    IS
        v_count   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO v_count
          FROM mrp_sourcing_rules
         WHERE sourcing_rule_name =
               ip_style || '-' || ip_color || '-' || ip_region;

        IF v_count != 0
        THEN
            -- Rule already exists
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    END rule_exists;

    --Procedure to be used for the custom web ADI for sourcing rule upload
    -- Needs to be updated; as of 3/7/2015

    FUNCTION GET_END_DATE (ip_style VARCHAR2, ip_color VARCHAR2, ip_region VARCHAR2
                           , P_START_DATE DATE)
        RETURN DATE
    IS
        V_DATE   DATE;
    BEGIN
        SELECT NVL (
                   (SELECT CASE
                               WHEN P_START_DATE IS NOT NULL
                               THEN
                                   TRUNC (
                                       GREATEST (P_START_DATE - 1, SYSDATE))
                               ELSE
                                   TRUNC (SYSDATE)
                           END
                      FROM MRP_SR_RECEIPT_ORG msro, mrp_sourcing_rules msr
                     WHERE     msro.sourcing_rule_id = msr.sourcing_rule_id
                           AND MSRO.disable_date IS NULL
                           AND sourcing_rule_name =
                                  ip_style
                               || '-'
                               || ip_color
                               || '-'
                               || ip_region),
                   (SELECT TRUNC (MAX (MSRO.disable_date))
                      FROM MRP_SR_RECEIPT_ORG msro, mrp_sourcing_rules msr
                     WHERE     msro.sourcing_rule_id = msr.sourcing_rule_id
                           AND sourcing_rule_name =
                                  ip_style
                               || '-'
                               || ip_color
                               || '-'
                               || ip_region))
          INTO V_DATE
          FROM DUAL;

        RETURN V_DATE;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN SYSDATE;
    END;

    FUNCTION GET_MAX_START_DATE (ip_style    VARCHAR2,
                                 ip_color    VARCHAR2,
                                 ip_region   VARCHAR2)
        RETURN DATE
    IS
        V_DATE   DATE;
    BEGIN
        SELECT TRUNC (MAX (MSRO.EFFECTIVE_date))
          INTO V_DATE
          FROM MRP_SR_RECEIPT_ORG msro, mrp_sourcing_rules msr
         WHERE     msro.sourcing_rule_id = msr.sourcing_rule_id
               AND sourcing_rule_name =
                   ip_style || '-' || ip_color || '-' || ip_region;


        RETURN V_DATE;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN SYSDATE;
    END;

    FUNCTION GET_START_VALIDATION (ip_style VARCHAR2, ip_color VARCHAR2, ip_region VARCHAR2
                                   , P_START_DATE DATE)
        RETURN BOOLEAN
    IS
        V_COUNT   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO V_COUNT
          FROM (SELECT TRUNC (MSRO.EFFECTIVE_DATE) EFFECTIVE_DATE
                  FROM MRP_SR_RECEIPT_ORG msro, mrp_sourcing_rules msr
                 WHERE     msro.sourcing_rule_id = msr.sourcing_rule_id
                       AND sourcing_rule_name =
                           ip_style || '-' || ip_color || '-' || ip_region
                       AND TRUNC (MSRO.EFFECTIVE_DATE) !=
                           GET_MAX_START_DATE (ip_style, ip_color, ip_region))
         WHERE EFFECTIVE_DATE = TRUNC (P_START_DATE);

        IF V_COUNT = 0 AND TRUNC (P_START_DATE) >= SYSDATE
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END;

    FUNCTION RULE_SOURCE_EXISTS (p_sourcing_rule_id IN NUMBER, P_VENDOR_ID IN NUMBER, P_VENDOR_SITE_ID IN NUMBER
                                 , p_end_date IN DATE)
        RETURN BOOLEAN
    IS
        v_count   NUMBER;
    BEGIN
        SELECT COUNT (*)
          INTO v_count
          FROM MRP_SR_SOURCE_ORG MSS, MRP_SR_RECEIPT_ORG MSRO
         WHERE     MSRO.SOURCING_RULE_ID = P_SOURCING_RULE_ID
               AND MSRO.SR_RECEIPT_ID = MSS.SR_RECEIPT_ID
               AND MSS.VENDOR_ID = P_VENDOR_ID
               AND MSS.VENDOR_SITE_ID = P_VENDOR_SITE_ID
               AND DISABLE_DATE IS NULL;

        IF v_count = 0
        THEN
            SELECT COUNT (*)
              INTO v_count
              FROM MRP_SR_SOURCE_ORG MSS, MRP_SR_RECEIPT_ORG MSRO
             WHERE     MSRO.SOURCING_RULE_ID = P_SOURCING_RULE_ID
                   AND MSRO.SR_RECEIPT_ID = MSS.SR_RECEIPT_ID
                   AND MSS.VENDOR_ID = P_VENDOR_ID
                   AND MSS.VENDOR_SITE_ID = P_VENDOR_SITE_ID
                   AND MSRO.DISABLE_DATE = p_end_date;
        END IF;


        IF v_count > 0
        THEN
            RETURN TRUE;
        ELSE
            RETURN FALSE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END;


    PROCEDURE main_webadi_proc
    IS
        ln_request_id              NUMBER;
        ln_req_id                  NUMBER;
        ln_count                   NUMBER;
        lv_dummy                   VARCHAR2 (100);
        lx_dummy                   VARCHAR2 (250);
        lv_dphase                  VARCHAR2 (100);
        lv_dstatus                 VARCHAR2 (100);
        lv_status                  VARCHAR2 (1);
        lv_message                 VARCHAR2 (240);
        ln_org_id                  NUMBER := fnd_global.org_id;

        ln_responsibility_id       NUMBER;
        ln_application_id          NUMBER;
        ln_user_id                 NUMBER;
        ln_order_source_id         NUMBER;
        lv_orig_sys_document_ref   oe_headers_iface_all.orig_sys_document_ref%TYPE;
        lx_message                 VARCHAR2 (4000);
    BEGIN
        printmessage ('Run import test: ' || ln_org_id);

        SELECT responsibility_id, application_id
          INTO ln_responsibility_id, ln_application_id
          FROM fnd_responsibility_vl
         WHERE responsibility_id = fnd_global.resp_id;

        printmessage ('ln_responsibility_id :' || ln_responsibility_id);
        printmessage ('ln_application_id :' || ln_application_id);

        SELECT user_id
          INTO ln_user_id
          FROM fnd_user
         WHERE user_id = fnd_global.user_id;

        printmessage ('ln_user_id :' || ln_user_id);
        printmessage ('ln_org_id :' || ln_org_id);


        fnd_global.apps_initialize (ln_user_id,
                                    ln_responsibility_id,
                                    ln_application_id);
        printmessage ('Run program :');
        ln_request_id   :=
            apps.fnd_request.submit_request (application => 'XXDO', program => 'XXDO_SOURCING_RULE_CONV', argument1 => 'N', argument2 => 'N', argument3 => NULL, argument4 => NULL
                                             , argument5 => 'N'); --      REPROCESS_PARAM

        COMMIT;
        printmessage ('ln_request_id :' || ln_request_id);

        IF NVL (ln_request_id, 0) = 0
        THEN
            lx_message   := 'Error in Sourcing Rule Import Program';
        END IF;
    END main_webadi_proc;

    PROCEDURE FEED_ORACLE_REGION (v_errbuf    OUT VARCHAR2,
                                  v_retcode   OUT NUMBER)
    IS
        CURSOR STG_DATA_CUR IS
                SELECT *
                  FROM xxdo_sourcing_rule_stg
                 WHERE oracle_region IS NULL OR run_id IS NULL
            FOR UPDATE OF ORACLE_REGION, RUN_ID;

        V_RUN_ID   NUMBER;
    BEGIN
        SELECT APPS.xxdo_sourcing_rule_runID_S.NEXTVAL
          INTO V_RUN_ID
          FROM DUAL;

        FOR C_REC IN STG_DATA_CUR
        LOOP
            UPDATE xxdo_sourcing_rule_stg
               SET ORACLE_REGION = NVL (PLM_REGION, ORACLE_REGION), RUN_ID = V_RUN_ID
             WHERE CURRENT OF STG_DATA_CUR;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            v_errbuf    :=
                'when others while populating oracle region ' || SQLERRM;
            v_retcode   := 2;
    END;

    PROCEDURE POPULATE_GLOBAL_RG_RECORDS
    IS
        CURSOR global_rg_cur IS
            SELECT ROWID rowxx, style, color,
                   --region --commented after staging table structure change,
                   PLM_REGION region, start_date, end_date,
                   supplier_name, supplier_site_code, run_id,
                   source
              FROM xxdo_sourcing_rule_stg
             WHERE     UPPER (PLM_region) = 'GLOBAL'
                   AND ORACLE_REGION = PLM_region
                   AND NVL (record_status, g_new_status) != 'PASSED'
                   AND SOURCE != 'WEBADI';

        CURSOR GET_REGION_CUR IS
            SELECT DISTINCT flv.attribute1 region
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
                   AND flv.language = 'US'
                   AND flv.enabled_flag = 'Y'           --Added for change 6.0
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1) --Added for change 6.0
                                                                             ;

        global_rg_REC      global_rg_cur%ROWTYPE;
        v_count1           NUMBER := 0;
        v_org_id           NUMBER;
        V_VENDOR_ID        NUMBER;
        V_VENDOR_SITE_ID   NUMBER;
        v_message          VARCHAR2 (4000);
    BEGIN
        OPEN global_rg_cur;

        LOOP
            FETCH global_rg_cur INTO global_rg_REC;

            EXIT WHEN global_rg_cur%NOTFOUND;

            v_count1   := 0;

            BEGIN
                ---OPEN GET_REGION_CUR;

                FOR GET_REGION_rec IN GET_REGION_CUR
                LOOP
                    SELECT get_org_id_for_region (GET_REGION_rec.REGION)
                      INTO v_org_id
                      FROM DUAL;


                    IF GET_SUPPLIER_AND_SITE_ID (
                           global_rg_REC.supplier_name,
                           global_rg_REC.supplier_site_code,
                           v_org_id,
                           global_rg_REC.start_date,
                           V_VENDOR_ID,
                           V_VENDOR_SITE_ID)
                    THEN
                        v_count1   := v_count1 + 1;

                        INSERT INTO xxdo_sourcing_rule_stg (
                                        style,
                                        color,
                                        oracle_region,
                                        PLM_REGION,
                                        start_date,
                                        end_date,
                                        supplier_name,
                                        supplier_site_code,
                                        run_id,
                                        SOURCE,
                                        RECORD_STATUS,
                                        seq_id,
                                        creation_date,           --WHO_COLUMNS
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        last_update_login,
                                        request_id)
                                 VALUES (global_rg_REC.style,
                                         global_rg_REC.color,
                                         GET_REGION_rec.REGION,
                                         global_rg_REC.REGION,
                                         global_rg_REC.start_date,
                                         global_rg_REC.end_date,
                                         global_rg_REC.supplier_name,
                                         global_rg_REC.supplier_site_code,
                                         global_rg_REC.run_id,
                                         global_rg_REC.source,
                                         'NEW',
                                         xxdo_sourcing_rule_stg_S.NEXTVAL,
                                         SYSDATE,
                                         g_num_user_id,
                                         SYSDATE,
                                         g_num_user_id,
                                         g_num_login_id,
                                         g_num_request_id);
                    END IF;
                END LOOP;

                IF V_COUNT1 = 0
                THEN
                    v_message   :=
                        'Site does not exist in any of the APAC,EMEA,JP,EMEA region records for ''''GLOBAL'''' region: ';

                    UPDATE xxdo_sourcing_rule_stg
                       SET record_status = g_valid_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE ROWID = global_rg_REC.rowxx;
                ELSE
                    UPDATE xxdo_sourcing_rule_stg
                       SET record_status = 'PASSED', error_message = NULL, last_update_date = SYSDATE, -- WHO_COLUMNS
                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE ROWID = global_rg_REC.rowxx;
                END IF;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    v_message   :=
                           'Error while inserting new records for ''''GLOBAL'''' region: '
                        || SQLERRM;

                    UPDATE xxdo_sourcing_rule_stg
                       SET record_status = g_valid_error_status, error_message = v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                           last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
                     WHERE ROWID = global_rg_REC.rowxx;

                    COMMIT;
            END;
        END LOOP;

        CLOSE global_rg_cur;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            v_message   := SQLERRM;

            UPDATE xxdo_sourcing_rule_stg
               SET record_status = g_valid_error_status, error_message = 'WHEN OTHERS WHILE POPULATE RECORDS FOR ''''GLOBAL'''' REGION' || v_message, last_update_date = SYSDATE, -- WHO_COLUMNS
                   last_updated_by = g_num_user_id, last_update_login = g_num_login_id, request_id = g_num_request_id
             WHERE     UPPER (oracle_region) = 'GLOBAL'
                   AND NVL (record_status, g_new_status) IN
                           (g_new_status, g_valid_error_status);

            COMMIT;
    END;


    PROCEDURE STAGING_WEBADI_UPLOAD (P_style VARCHAR2 DEFAULT NULL, P_color VARCHAR2 DEFAULT NULL, P_region VARCHAR2 DEFAULT NULL, P_start_date DATE DEFAULT NULL, P_end_date DATE DEFAULT NULL, P_supplier_name VARCHAR2 DEFAULT NULL
                                     , P_supplier_site_code VARCHAR2 DEFAULT NULL, P_RUN_ID NUMBER)
    IS
        CURSOR GET_REGION_CUR IS
            SELECT DISTINCT flv.attribute1 region
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
                   AND flv.language = 'US'
                   AND flv.enabled_flag = 'Y'           --Added for change 6.0
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1) --Added for change 6.0
                                                                             ;

        GET_REGION_rec        GET_REGION_CUR%ROWTYPE;



        l_err_message         VARCHAR2 (4000) := NULL;
        l_ret_message         VARCHAR2 (4000) := NULL;
        le_webadi_exception   EXCEPTION;
        V_COUNT1              NUMBER := 0;
        v_org_id              NUMBER;
        V_VENDOR_ID           NUMBER;
        V_VENDOR_SITE_ID      NUMBER;
        v_ou_org_id           NUMBER;
        v_assignment_set_id   NUMBER;
    BEGIN
        g_run_id   := P_RUN_ID;

        IF UPPER (P_region) != 'GLOBAL'
        THEN
            IF NOT inv_org_found_for_region (P_region)
            THEN
                L_ERR_MESSAGE   :=
                       'No valid inventory org mapping found in PO lookup XXDO_SOURCING_RULE_REGION_MAP for region = '
                    || P_region;

                RAISE le_webadi_exception;
            END IF;

            v_ou_org_id           := get_org_id_for_region (P_region);

            IF v_ou_org_id = -999
            THEN
                L_ERR_MESSAGE   :=
                       'OU Mapping not found in PO lookup XXDO_SOURCING_RULE_REGION_MAP for region = '
                    || P_region;

                RAISE le_webadi_exception;
            END IF;

            v_assignment_set_id   := get_assignment_id_for_region (P_region);

            IF v_assignment_set_id = -999
            THEN
                L_ERR_MESSAGE   :=
                       'No assignment set found or more than 1 found for region = '
                    || P_region;

                RAISE le_webadi_exception;
            END IF;

            IF TRUNC (P_START_DATE) > TRUNC (P_END_DATE)
            THEN
                L_ERR_MESSAGE   := 'Start date is greater than End Date';
                RAISE le_webadi_exception;
            END IF;

            IF TRUNC (P_START_DATE) < TRUNC (SYSDATE)
            THEN
                L_ERR_MESSAGE   := 'Start date is less than sysdate';
                RAISE le_webadi_exception;
            END IF;

            IF rule_exists (P_style, P_color, P_region)
            THEN
                /* IF    GET_END_DATE (P_style, P_color, P_region,p_start_date) >
                          TRUNC (NVL (P_START_DATE, SYSDATE + 1))

                 THEN
                    L_ERR_MESSAGE :=
                       'start date is less than end date of old active sourcing rule receiving org ';

                    RAISE le_webadi_exception;
                 END IF;*/

                IF     GET_END_DATE (P_style, P_color, P_region,
                                     P_START_DATE) >= TRUNC (SYSDATE)
                   AND TRUNC (P_START_DATE) < TRUNC (SYSDATE + 1)
                THEN
                    L_ERR_MESSAGE   :=
                        'can not end date old active sourcing rule receiving org at less than sysdate';

                    RAISE le_webadi_exception;
                END IF;

                IF NOT GET_START_VALIDATION (P_style, P_color, P_region,
                                             p_start_date)
                THEN
                    L_ERR_MESSAGE   := 'This start date already exist';

                    RAISE le_webadi_exception;
                END IF;
            END IF;



            IF NOT get_supplier_and_site_id (p_supplier_name,
                                             p_supplier_site_code,
                                             v_ou_org_id,
                                             NVL (P_START_DATE, SYSDATE + 1),
                                             V_VENDOR_ID,
                                             V_VENDOR_SITE_ID)
            THEN
                L_ERR_MESSAGE   :=
                       'Supplier or site not found. Validated against org_id = '
                    || v_ou_org_id;

                RAISE le_webadi_exception;
            END IF;

            IF L_ERR_MESSAGE IS NULL
            THEN
                INSERT INTO xxdo_sourcing_rule_stg (style,
                                                    color,
                                                    oracle_region,
                                                    plm_region,
                                                    SOURCE,
                                                    start_date,
                                                    end_date,
                                                    supplier_name,
                                                    supplier_site_code,
                                                    seq_id,
                                                    run_id,
                                                    RECORD_STATUS,
                                                    creation_date, --WHO_COLUMNS
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    request_id)
                         VALUES (p_style,
                                 p_color,
                                 p_region,
                                 p_region,
                                 'WEBADI',
                                 P_START_DATE,
                                 P_end_date,
                                 P_supplier_name,
                                 P_supplier_site_code,
                                 xxdo_sourcing_rule_stg_S.NEXTVAL,
                                 p_run_id,
                                 'NEW',
                                 SYSDATE,
                                 g_num_user_id,
                                 SYSDATE,
                                 g_num_user_id,
                                 g_num_login_id,
                                 g_num_request_id);
            END IF;
        ELSE
            OPEN GET_REGION_CUR;


            LOOP
                FETCH GET_REGION_CUR INTO GET_REGION_rec;

                EXIT WHEN GET_REGION_CUR%NOTFOUND;

                SELECT GET_ORG_ID_FOR_REGION (GET_REGION_rec.REGION)
                  INTO V_ORG_ID
                  FROM DUAL;

                IF V_ORG_ID = -999
                THEN
                    L_ERR_MESSAGE   :=
                           'OU Mapping not found in PO lookup XXDO_SOURCING_RULE_REGION_MAP for region = '
                        || GET_REGION_rec.REGION;
                    RAISE le_webadi_exception;
                END IF;

                IF TRUNC (P_START_DATE) > TRUNC (P_END_DATE)
                THEN
                    L_ERR_MESSAGE   := 'Start date is greater than End Date';
                    RAISE le_webadi_exception;
                END IF;

                IF P_START_DATE < SYSDATE
                THEN
                    L_ERR_MESSAGE   := 'Start date is less than sysdate';
                    RAISE le_webadi_exception;
                END IF;

                IF rule_exists (P_style, P_color, GET_REGION_rec.REGION)
                THEN
                    /* IF    GET_END_DATE (P_style, P_color, GET_REGION_rec.REGION,p_start_date) >
                              TRUNC (NVL (P_START_DATE, SYSDATE + 1))

                     THEN
                        L_ERR_MESSAGE :=
                           'start date is less than end date of old active sourcing rule receiving org ';

                        RAISE le_webadi_exception;
                     END IF;*/


                    IF     GET_END_DATE (P_style, P_color, GET_REGION_rec.REGION
                                         , P_START_DATE) >= TRUNC (SYSDATE)
                       AND TRUNC (P_START_DATE) < TRUNC (SYSDATE + 1)
                    THEN
                        L_ERR_MESSAGE   :=
                            'can not end date old active sourcing rule receiving org at less than sysdate';

                        RAISE le_webadi_exception;
                    END IF;

                    IF NOT GET_START_VALIDATION (P_style, P_color, GET_REGION_rec.REGION
                                                 , p_start_date)
                    THEN
                        L_ERR_MESSAGE   := 'This start date already exist';

                        RAISE le_webadi_exception;
                    END IF;
                END IF;



                IF GET_SUPPLIER_AND_SITE_ID (p_supplier_name,
                                             p_supplier_site_code,
                                             v_org_id,
                                             NVL (P_START_DATE, SYSDATE + 1),
                                             V_VENDOR_ID,
                                             V_VENDOR_SITE_ID)
                THEN
                    v_count1   := v_count1 + 1;

                    IF NOT inv_org_found_for_region (GET_REGION_rec.REGION)
                    THEN
                        L_ERR_MESSAGE   :=
                               'No valid inventory org mapping found in PO lookup XXDO_SOURCING_RULE_REGION_MAP for region = '
                            || GET_REGION_rec.REGION;

                        RAISE le_webadi_exception;
                    END IF;

                    v_assignment_set_id   :=
                        get_assignment_id_for_region (GET_REGION_rec.REGION);

                    IF v_assignment_set_id = -999
                    THEN
                        L_ERR_MESSAGE   :=
                               'No assignment set found or more than 1 found for region = '
                            || GET_REGION_rec.REGION;
                        RAISE le_webadi_exception;
                    END IF;



                    INSERT INTO xxdo_sourcing_rule_stg (style,
                                                        color,
                                                        plm_region,
                                                        oracle_region,
                                                        SOURCE,
                                                        start_date,
                                                        end_date,
                                                        supplier_name,
                                                        supplier_site_code,
                                                        seq_id,
                                                        run_id,
                                                        RECORD_STATUS,
                                                        creation_date, --WHO_COLUMNS
                                                        created_by,
                                                        last_update_date,
                                                        last_updated_by,
                                                        last_update_login,
                                                        request_id)
                             VALUES (p_style,
                                     p_color,
                                     p_region,
                                     GET_REGION_rec.REGION,
                                     'WEBADI',
                                     P_START_DATE,
                                     p_end_date,
                                     p_supplier_name,
                                     p_supplier_site_code,
                                     xxdo_sourcing_rule_stg_S.NEXTVAL,
                                     p_run_id,
                                     'NEW',
                                     SYSDATE,
                                     g_num_user_id,
                                     SYSDATE,
                                     g_num_user_id,
                                     g_num_login_id,
                                     g_num_request_id);
                END IF;
            END LOOP;

            CLOSE GET_REGION_CUR;

            IF V_COUNT1 = 0
            THEN
                l_err_message   :=
                    'Site does not exist in any of the APAC,EMEA,JP,EMEA region records for ''''GLOBAL'''' region: ';

                RAISE le_webadi_exception;
            ELSE
                INSERT INTO xxdo_sourcing_rule_stg (style,
                                                    color,
                                                    plm_region,
                                                    oracle_region,
                                                    SOURCE,
                                                    start_date,
                                                    end_date,
                                                    supplier_name,
                                                    supplier_site_code,
                                                    seq_id,
                                                    run_id,
                                                    RECORD_STATUS,
                                                    creation_date, --WHO_COLUMNS
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    last_update_login,
                                                    request_id)
                         VALUES (p_style,
                                 p_color,
                                 p_region,
                                 p_region,
                                 'WEBADI',
                                 NVL (P_START_DATE, SYSDATE + 1),
                                 p_end_date,
                                 p_supplier_name,
                                 p_supplier_site_code,
                                 xxdo_sourcing_rule_stg_S.NEXTVAL,
                                 p_run_id,
                                 'PASSED',
                                 SYSDATE,
                                 g_num_user_id,
                                 SYSDATE,
                                 g_num_user_id,
                                 g_num_login_id,
                                 g_num_request_id);
            END IF;
        END IF;
    EXCEPTION
        WHEN le_webadi_exception
        THEN
            IF GET_REGION_CUR%ISOPEN
            THEN
                CLOSE GET_REGION_CUR;
            END IF;

            --DBMS_OUTPUT.PUT_LINE('WEBADI MESSAGE'||l_err_message);
            fnd_message.clear ();
            fnd_message.set_name ('XXDO', 'XXD_SOURCING_RULE_WEBADI_MSG');
            fnd_message.set_token ('ERROR_MESSAGE', l_err_message);
            l_ret_message   := fnd_message.get ();
            raise_application_error (-20000, l_ret_message);
        WHEN OTHERS
        THEN
            l_ret_message   := SQLERRM;
            raise_application_error (-20001, l_ret_message);
    END;


    -- Format character fields

    FUNCTION format_char (ip_text VARCHAR2)
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN LTRIM (RTRIM (UPPER (ip_text)));
    END format_char;

    -- Print given message on DBMS output and FND Log

    PROCEDURE print_message (ip_text VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (ip_text);
        fnd_file.put_line (fnd_file.LOG, ip_text);
    END print_message;

    PROCEDURE printmessage (p_msgtoken IN VARCHAR2)
    IS
    BEGIN
        IF p_msgtoken IS NOT NULL
        THEN
            NULL;
        --debugging_deepa (p_msgtoken);
        END IF;

        RETURN;
    END printmessage;

    -- Procedure to extract data from 12.0.6 into 12.2.3 stage table
    PROCEDURE extract_data (ip_assignment_set_id   NUMBER,
                            ip_db_link_name        VARCHAR2)
    IS
        v_sql             VARCHAR2 (4000);
        v_extract_count   NUMBER;
        v_delete_count    NUMBER := 0;
        v_insert_count    NUMBER := 0;
        v_stage_count     NUMBER := 0;

        -- Cursor to find duplicate record in stage table
        CURSOR c_stg_dup IS
              SELECT style, color, oracle_region region,
                     start_date, end_date, supplier_name,
                     supplier_site_code, COUNT (*)
                FROM xxdo_sourcing_rule_stg
               WHERE NVL (record_status, g_new_status) = g_new_status
            GROUP BY style, color, oracle_region,
                     start_date, end_date, supplier_name,
                     supplier_site_code
              HAVING COUNT (*) > 1;
    BEGIN
        IF 1 = 1
        THEN
            v_stage_count   := 0;
        END IF;

        -- Commented by INFOSYS for 1206 DB issue

        /*
        INSERT INTO xxdo_sourcing_rule_stg (oracle_region,
                                              style,
                                              color,
                                              supplier_name,
                                              supplier_site_code,
                                                 creation_date, --WHO_COLUMNS
                                                 created_by,
                                                 last_update_date,
                                                 last_updated_by,
                                                 last_update_login,
                                                 request_id
                                                 )
             SELECT DECODE (SUBSTR (a.organization_code, 1, 2),
                            'DC', 'US',
                            'US', 'US',
                            'EU', 'EMEA',
                            'UK', 'EMEA',
                            'IM', 'APAC',
                            'HK', 'APAC',
                            'CH', 'APAC',
                            'JP', 'JP',
                            'XX')
                       region,
                    SUBSTR (a.entity_name, 1, INSTR (a.entity_name, '-') - 1)
                       style,
                    SUBSTR (a.entity_name,
                            INSTR (a.entity_name, '-') + 1,
                            (  INSTR (a.entity_name,
                                      '-',
                                      1,
                                      2)
                             - INSTR (a.entity_name, '-')
                             - 1))
                       color,
                    c.vendor_name,
                    c.vendor_site,
                    SYSDATE,
                      g_num_user_id,
                      SYSDATE,
                      g_num_user_id,
                      g_num_login_id,
                      g_num_request_id
               FROM apps.mrp_sr_assignments_v@bt_read_1206.us.oracle.com a,
                    apps.mrp_sr_receipt_org@bt_read_1206.us.oracle.com b,
                    apps.mrp_sr_source_org_v@bt_read_1206.us.oracle.com c
              WHERE     a.assignment_set_id = 445961
                    AND a.sourcing_rule_id = b.sourcing_rule_id
                    AND b.sr_receipt_id = c.sr_receipt_id
                    -- AND a.entity_name = '1006491-OYS-11'
                    AND a.organization_code != 'VNT'; */



        -- Commented by INFOSYS for 1206 DB issue

        -- Generate dynamic statement using assignment_set_id and db link name

        /*v_sql :=
              'INSERT INTO xxdo_sourcing_rule_stg
               (region, style, color, supplier_name, supplier_site_code)
               SELECT to_char(region),to_char(style), to_char(color), vendor_name, vendor_site FROM (
               SELECT DECODE (SUBSTR (a.organization_code, 1, 2),
                  ''DC'', ''US'',
                  ''US'', ''US'',
                  ''EU'', ''EMEA'',
                  ''UK'', ''EMEA'',
                  ''IM'', ''APAC'',
                  ''HK'', ''APAC'',
                  ''CH'', ''APAC'',
                  ''JP'', ''JP'',
                  ''XX'')
             region,
          SUBSTR (a.entity_name, 1, INSTR (a.entity_name, ''
            - '') - 1) style,
          SUBSTR (a.entity_name,
                  INSTR (a.entity_name, ''
            - '') + 1,
                  (  INSTR (a.entity_name,
                            ''
            - '',
                            1,
                            2)
                   - INSTR (a.entity_name, ''
            - '')
                   - 1))
             color,
          c.vendor_name,
          c.vendor_site
     FROM mrp_sr_assignments_v@bt_read_1206.us.oracle.com a,
          mrp_sr_receipt_org@bt_read_1206.us.oracle.com b,
          mrp_sr_source_org_v@bt_read_1206.us.oracle.com c
    WHERE     a.assignment_set_id = 445961
          AND a.sourcing_rule_id = b.sourcing_rule_id
          AND b.sr_receipt_id = c.sr_receipt_id
          AND a.entity_name = ''1006491-OYS-11''
          AND a.organization_code != ''VNT'');';*/

        -- Execute dynamic statement
        --EXECUTE IMMEDIATE v_sql
        -- USING ip_db_link_name, ip_assignment_set_id;

        COMMIT;

        --print_message (v_sql);

        SELECT COUNT (*) INTO v_extract_count FROM xxdo_sourcing_rule_stg;

        print_message (
               'End extraction of records, No. of records extracted = '
            || v_extract_count);

        --  Find and delete duplicate records in stage table
        print_message ('Starting delete of duplicate records');

        FOR c_sd IN c_stg_dup
        LOOP
            -- Delete all duplicate records first
            DELETE FROM
                xxdo_sourcing_rule_stg
                  WHERE     NVL (style, 'XX') = NVL (c_sd.style, 'XX')
                        AND NVL (color, 'XX') = NVL (c_sd.color, 'XX')
                        AND NVL (oracle_region, 'XX') =
                            NVL (c_sd.region, 'XX')
                        AND NVL (start_date, SYSDATE) =
                            NVL (c_sd.start_date, SYSDATE)
                        AND NVL (end_date, SYSDATE) =
                            NVL (c_sd.end_date, SYSDATE)
                        AND NVL (supplier_name, 'XX') =
                            NVL (c_sd.supplier_name, 'XX')
                        AND NVL (supplier_site_code, 'XX') =
                            NVL (c_sd.supplier_site_code, 'XX');

            v_delete_count   := v_delete_count + SQL%ROWCOUNT;

            -- Now insert only one record
            INSERT INTO xxdo_sourcing_rule_stg (style, color, oracle_region,
                                                start_date, end_date, supplier_name, supplier_site_code, creation_date, --WHO_COLUMNS
                                                                                                                        created_by, last_update_date, last_updated_by, last_update_login
                                                , request_id)
                 VALUES (c_sd.style, c_sd.color, c_sd.region,
                         c_sd.start_date, c_sd.end_date, c_sd.supplier_name,
                         c_sd.supplier_site_code, SYSDATE, g_num_user_id,
                         SYSDATE, g_num_user_id, g_num_login_id,
                         g_num_request_id);


            v_insert_count   := v_insert_count + 1;

            COMMIT;
        END LOOP;

        print_message (
               'Number of duplicate records removed = '
            || (v_delete_count - v_insert_count));

        -- END removing duplicate record in stage table
        --*******************************************************

        SELECT COUNT (*) INTO v_stage_count FROM xxdo_sourcing_rule_stg;

        print_message (
            'Number of records remaining in stage = ' || v_stage_count);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            print_message (
                'Unexpected error in extraction routine. Error = ' || SQLERRM);
    END extract_data;

    PROCEDURE get_email_address_list (
        p_lookup_type            VARCHAR2,
        x_users_email_list   OUT do_mail_utils.tbl_recips)
    IS
        lr_users_email_lst   do_mail_utils.tbl_recips;
    BEGIN
        lr_users_email_lst.DELETE;

        BEGIN
            SELECT meaning
              BULK COLLECT INTO lr_users_email_lst
              FROM fnd_lookup_values
             WHERE     lookup_type = p_lookup_type
                   AND enabled_flag = 'Y'
                   AND LANGUAGE = USERENV ('LANG')
                   AND SYSDATE BETWEEN TRUNC (
                                           NVL (start_date_active, SYSDATE))
                                   AND TRUNC (
                                           NVL (end_date_active, SYSDATE) + 1);

            x_users_email_list   := lr_users_email_lst;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lr_users_email_lst.DELETE;
                x_users_email_list   := lr_users_email_lst;
            WHEN OTHERS
            THEN
                lr_users_email_lst.DELETE;
                x_users_email_list   := lr_users_email_lst;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Setup 99: Error in Get uesrs Email List: ' || SQLERRM);
        END;
    END get_email_address_list;

    PROCEDURE SEND_EMAIL_REPORT
    IS
        v_out_line               VARCHAR2 (1000);
        l_counter                NUMBER := 0;
        l_ret_val                NUMBER := 0;
        v_def_mail_recips        do_mail_utils.tbl_recips;

        CURSOR c_output_rec (p_run_id IN NUMBER)
        IS
            SELECT xsrs.*, TO_CHAR (SYSDATE, 'DD-MON-YYYY') START_DATE1, NULL END_DATE1
              FROM xxdo_sourcing_rule_stg xsrs
             WHERE source = 'PLM' AND run_id = p_run_id;

        TYPE t_output_rec IS TABLE OF c_output_rec%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_output_rec             t_output_rec;

        v_asssignment_set_name   VARCHAR2 (300);
        v_run_id                 NUMBER;
    BEGIN
        SELECT xxdo_sourcing_rule_runID_S.CURRVAL INTO v_run_id FROM DUAL;

        print_message ('sTART');
        l_output_rec.DELETE;

        OPEN c_output_rec (v_run_id);

        FETCH c_output_rec BULK COLLECT INTO l_output_rec;

        CLOSE c_output_rec;

        IF l_output_rec.COUNT > 0
        THEN
            do_debug_utils.set_level (1);

            get_email_address_list ('SOURCING_RULE_UPLOAD_DL',
                                    v_def_mail_recips);
            print_message ('After get_email_address_list');

            print_message (
                'Before Send email header ' || '  ' || v_def_mail_recips (1));


            do_mail_utils.send_mail_header ('erp@deckers.com', v_def_mail_recips, 'Sourcing Rule Status Report  ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY')
                                            , l_ret_val);
            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                l_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/plain',
                                          l_ret_val);
            do_mail_utils.send_mail_line ('', l_ret_val);
            do_mail_utils.send_mail_line (
                'See attachment for report details.',
                l_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', l_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          l_ret_val);
            do_mail_utils.send_mail_line (
                'Content-Disposition: attachment; filename="Sourcing Rule Status Report.xls"',
                l_ret_val);
            do_mail_utils.send_mail_line ('', l_ret_val);
            print_message ('Before heading');
            do_mail_utils.send_mail_line (
                   'Style'
                || CHR (9)
                || 'Color'
                || CHR (9)
                || 'Oracle Region'
                || CHR (9)
                || 'Supplier Name'
                || CHR (9)
                || 'Supplier Site Code'
                || CHR (9)
                || 'Start Date'
                || CHR (9)
                || 'End Date'
                || CHR (9)
                || 'Source'
                || CHR (9)
                || 'Record Status'
                || CHR (9)
                || 'Error Message'
                || CHR (9)
                || 'Assignment Set Name'
                || CHR (9),
                l_ret_val);

            FOR r_output_rec IN 1 .. l_output_rec.COUNT
            LOOP
                BEGIN
                    SELECT assignment_set_name
                      INTO v_asssignment_set_name
                      FROM mrp_assignment_sets
                     WHERE assignment_set_id =
                           l_output_rec (r_output_rec).assignment_set_id;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        v_asssignment_set_name   := NULL;
                END;

                v_out_line   := NULL;
                print_message ('Before Details');
                v_out_line   :=
                       l_output_rec (r_output_rec).style
                    || CHR (9)
                    || l_output_rec (r_output_rec).color
                    || CHR (9)
                    || l_output_rec (r_output_rec).oracle_region
                    || CHR (9)
                    || l_output_rec (r_output_rec).supplier_name
                    || CHR (9)
                    || l_output_rec (r_output_rec).supplier_site_code
                    || CHR (9)
                    || l_output_rec (r_output_rec).start_date1
                    || CHR (9)
                    || l_output_rec (r_output_rec).end_date1
                    || CHR (9)
                    || l_output_rec (r_output_rec).source
                    || CHR (9)
                    || l_output_rec (r_output_rec).record_status
                    || CHR (9)
                    || l_output_rec (r_output_rec).error_message
                    || CHR (9)
                    || v_asssignment_set_name
                    || CHR (9);
                do_mail_utils.send_mail_line (v_out_line, l_ret_val);
                fnd_file.put_line (fnd_file.output, v_out_line);
                l_counter    := l_counter + 1;
            END LOOP;

            print_message ('Before Close');
            do_mail_utils.send_mail_close (l_ret_val);
        END IF;

        print_message ('After  Close');
    EXCEPTION
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (l_ret_val);
            print_message ('Exception ' || SQLERRM);                 --Be Safe
    END SEND_EMAIL_REPORT;
END xxdo_sourcing_rule_pkg;
/
