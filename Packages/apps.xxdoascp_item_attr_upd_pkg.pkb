--
-- XXDOASCP_ITEM_ATTR_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOASCP_ITEM_ATTR_UPD_PKG"
AS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Subsystem       : ASCP
    --  Project         : [ISC-205] 02003: Supply Planning
    --  Description     : Package for Item Attribute Update Interface
    --  Module          : xxdoascp_item_attr_upd_pkg
    --  File            : xxdoascp_item_attr_upd_pkg.pkb
    --  Schema          : XXDO
    --  Date            : 01-Jun-2012
    --  Version         : 1.0
    --  Author(s)       : Sravan Kumar [ Suneratech Consulting]
    --  Purpose         : Package used to validate the data in the staging table data and load into the item interface table.
    --                        Then calls the item import program to update the item attributes.
    --  dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                  Description
    --  ----------      --------------      -----   --------------------    ------------------
    --  15-Jun-2012     Sravan Kumar       1.0                             Initial Version
    --
    --  02-Jul-2014     Abdul Gaffar       1.1                             Added Procedure del_item_int_stuck_rec to
    --                                                                     delete the Records which are stuck in
    --                                                                     interface errors table and changed the planner_code
    --                                                                     validation logic to allow exclamation mark for planner code
    --                                                                     in the item attribute update program.
    -- 21-01-2015    BT Technology       1.2                              Logic added to insert records for master level fields and child level
    --                                                                     fields seperately.
    --                                                                     validation added for round order quantities,
    --                                                                     create supply flag ,inventory planning method and safety stock method
    --                                                                     Function identify_master_child_attr modified. added few more column in decode statement
    --                                                                     sql to count the no of master controlled items is modified
    --25-04-2015    BT Technology         1.3                              Redesign the extract procedure . Adding function lead_time_cal for Lead Time calculation.
    --                                                                     Adding procedure to extract category records.
    -- 09-JUN-2015  BT Technology Team    1.4                               Changed the design for improving performance.
    -- 24-JUN-2015  BT Technology Team    1.5                              Modified lead_time_cal function for defect#2624
    -- 27-OCT-2015  BT Technology Team    1.6                              Modified lead_time_cal and postprocessing calc for defect#3385 and CR#154
    -- 30-AUG-2016  Bala Murugesan        1.7                              Modified to update item attributes for CA2; Changes identified by CA2_LEAD_TIME
    -- 20-AUG-2016  Bala Murugesan        1.8                              Modified to fix the bug - the program was not updating the item attributes
    --                                                                       If it is run immediately after the source rule update
    --                                                                       Changes identified by SRC_RULE_CORRECT
    -- 09-MAY-2017 Infosys     1.9                               Commented the update the template_id at staging table
    --                                                                     as it was defaulting only one template when there is more than one template in the file
    --                                                                     The change is identified by --commented for PRB0040989
    -- 30-MAY-2017 Infosys        1.10                                     Incorporated the function fetch_transit_lead_time as the query used to fetch the
    --                                                                     lead_transit_days were showing discrepencies. Changes identified by CCR0006305
    -- 22-JUN-2017 Infosys        1.11                                     The item status of an item for a specific warehouse could not be changed,
    --                                                                     without performing the change in Master warehouse. Fixed the same.Changes identified by CCR0006305

    --  ###################################################################################

    --==========================================
    -- Global variables
    --==========================================
    gn_org_id                NUMBER := apps.fnd_profile.VALUE ('ORG_ID');
    gn_login_id              NUMBER := apps.fnd_global.login_id;
    gn_resp_id               NUMBER := apps.fnd_global.resp_id;
    gn_program_id            NUMBER := apps.fnd_global.conc_program_id;
    gn_prog_appl_id          NUMBER := apps.fnd_global.prog_appl_id;
    gv_package_name          VARCHAR2 (240) := 'xxdoascp_item_attr_upd_pkg';
    gn_created_by            NUMBER := apps.fnd_global.user_id;
    gd_creation_date         DATE := SYSDATE;
    gn_updated_by            NUMBER := apps.fnd_global.user_id;
    gd_update_date           DATE := SYSDATE;
    gn_conc_req_id           NUMBER := apps.fnd_global.conc_request_id;
    ln_inv_item_id           apps.mtl_system_items_b.inventory_item_id%TYPE;
    lc_ret_brand_value1      VARCHAR2 (100);
    gn_user_id               NUMBER := fnd_profile.VALUE ('USER_ID');
    gn_request_id            NUMBER := fnd_global.conc_request_id;
    gn_lc_dept_value1        VARCHAR2 (250);
    lc_add_cum_lead_time     NUMBER := 0;

    TYPE tabtype_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    g_item_request_ids_tab   tabtype_id;

    TYPE set_process_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    g_set_process_id_tab     set_process_id;

    /* *****************************************************************************************
    Staging table Status codes and definitions
    *******************************************************************************************
    99  -   Initial load status from flat file into landing Table.
    -1  -   Sucessfully Loaded Into the staging Table.
    0   -   Initial Status  after extraction from Landing Table and before staging table validations.
    1   -   Staging table Errored Records while getting the Necessary ID's
    2   -   Successfully validated and populated the necessary id's to staging table
    3   -   Successfully Processed Records into the Item Interface Tables
    4   -   Records Errored out by API/Interface
    6   -   Data Successfully written into the Base tables
    10  -   Updating the Staging table with the Interface Errors
    50  -   Technical Error Status
    ******************************************************************************************/
    FUNCTION lead_time_cal (                                  --pn_sno NUMBER,
                            pn_organization_id NUMBER, -- Start Added By BT Technology Team
                                                       pn_inventory_id NUMBER, pn_full_lead_time NUMBER
                            , p_sample VARCHAR2)
        RETURN NUMBER
    AS
        --Start modification on 29-APR-2016
        CURSOR Get_style_color_c IS
            SELECT SUBSTR (MSIB.segment1,
                           1,
                             INSTR (MSIB.segment1, '-', 1,
                                    1)
                           - 1) style_code,
                   --MSIB.segment1,
                   SUBSTR (segment1,
                             INSTR (segment1, '-', 1,
                                    1)
                           + 1,
                           (  INSTR (segment1, '-', 1,
                                     2)
                            - INSTR (segment1, '-', 1,
                                     1)
                            - 1)) color_code
              FROM mtl_system_items_b msib
             WHERE     organization_id = 106
                   AND inventory_item_id = pn_inventory_id;

        lc_style                  VARCHAR2 (100);
        lc_color                  VARCHAR2 (100);
        --End modification on 29-APR-2016
        ln_category_id            NUMBER;
        lc_transit_days           VARCHAR2 (100);
        ln_full_lead_time         NUMBER;
        ln_lead_time              NUMBER;
        l_territory_short_name    fnd_territories_vl.territory_short_name%TYPE;
        l_territory_code          fnd_territories_vl.territory_code%TYPE; --added for CCR0006305
        -- lv_attribute             mtl_system_items_b.attribute28%TYPE;
        l_region                  fnd_lookup_values.attribute1%TYPE;
        l_vendor_name             mrp_sr_source_org_v.vendor_name%TYPE;
        l_vendor_site             mrp_sr_source_org_v.vendor_site%TYPE;
        lc_organization_code      mtl_parameters.organization_code%TYPE; -- CR 117 8/24/2015
        ln_japan_intransit_time   NUMBER := 0;             -- CR 117 8/24/2015
    --Calculating Territory
    BEGIN
        --Start modification on 29-APR-2016
        OPEN Get_style_color_c;

        FETCH Get_style_color_c INTO lc_style, lc_color;

        CLOSE Get_style_color_c;

        l_region   := NULL;

        fnd_file.put_line (FND_FILE.LOG, 'lc_style : ' || lc_style);
        fnd_file.put_line (FND_FILE.LOG, 'lc_color : ' || lc_color);

        --End modification on 29-APR-2016

        BEGIN
            --started commenting for CCR0006305
            /*SELECT ft.territory_short_name
              INTO l_territory_short_name
              FROM mtl_parameters mp, hr_locations hl, fnd_territories_vl ft
             WHERE     hl.inventory_organization_id = mp.organization_id
                   AND NVL (mp.attribute13, 2) = 2
                   AND mp.organization_id = pn_organization_id
                   AND hl.country = ft.territory_code;*/
            --ended commenting for CCR0006305
            --started adding for CCR0006305
            SELECT ft.territory_short_name, ft.TERRITORY_CODE
              INTO l_territory_short_name, l_territory_code
              FROM mtl_parameters mp, hr_locations hl, fnd_territories_vl ft
             WHERE     hl.inventory_organization_id = mp.organization_id
                   AND NVL (mp.attribute13, 2) = 2
                   AND mp.organization_id = pn_organization_id
                   AND hl.country = ft.territory_code;
        --completed adding for CCR0006305
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Error in Finding territory Name');
                --Start changes by BT Technology Team on 24-Jun-2015 for defect#2624
                -- RETURN pn_full_lead_time;
                RETURN CEIL (NVL (pn_full_lead_time, 0) * 5 / 7);
        --End changes by BT Technology Team on 24-Jun-2015 for defect#2624
        END;

        fnd_file.put_line (
            FND_FILE.LOG,
            'l_territory_short_name : ' || l_territory_short_name);

        --Calculating Category Value
        BEGIN
            SELECT mic.category_id
              INTO ln_category_id
              FROM mtl_item_categories mic, mtl_category_sets mcs
             WHERE     mcs.category_set_name = 'Inventory'
                   AND mcs.category_set_id = mic.category_set_id
                   AND mic.organization_id = pn_organization_id
                   AND mic.inventory_item_id = pn_inventory_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (FND_FILE.LOG,
                                   'Test Exception : ' || l_region);
                --Start changes by BT Technology Team on 24-Jun-2015 for defect#2624
                -- RETURN pn_full_lead_time;
                RETURN CEIL (NVL (pn_full_lead_time, 0) * 5 / 7);
        --End changes by BT Technology Team on 24-Jun-2015 for defect#2624
        END;

        fnd_file.put_line (FND_FILE.LOG,
                           'ln_category_id : ' || ln_category_id);

        --Finding Region
        BEGIN
            --Start changes by BT Technology team on 23 Feb 2016

            --      SELECT attribute1
            --           INTO l_region
            --           FROM fnd_lookup_values
            --          WHERE     lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
            --                AND language = 'US'
            --                AND attribute2 = 'Inventory Organization'
            --                AND attribute_category = 'XXDO_SOURCING_RULE_REGION_MAP'
            --                AND attribute3 =
            --                       (SELECT organization_code
            --                          FROM mtl_parameters
            --                         WHERE organization_id = pn_organization_id)
            --                AND ROWNUM = 1;
            BEGIN
                SELECT attribute1
                  INTO l_region
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_SOURCING_RULE_REGION_MAP'
                       AND language = 'US'
                       AND attribute2 = 'Inventory Organization'
                       AND attribute_category =
                           'XXDO_SOURCING_RULE_REGION_MAP'
                       AND attribute3 =
                           (SELECT organization_code
                              FROM mtl_parameters
                             WHERE organization_id = pn_organization_id)
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --Start changes by BT Technology Team on 24-Jun-2015 for defect#2624
                    -- RETURN pn_full_lead_time;
                    fnd_file.put_line (FND_FILE.LOG,
                                       'Test Exception 2 : ' || l_region);
            --RETURN CEIL (NVL (pn_full_lead_time, 0) * 5 / 7);

            --End changes by BT Technology Team on 24-Jun-2015 for defect#2624
            END;

            fnd_file.put_line (FND_FILE.LOG, 'l_region1 : ' || l_region);

            IF l_region IS NULL
            THEN
                SELECT attribute1
                  INTO l_region
                  FROM mtl_parameters
                 WHERE organization_id = pn_organization_id AND ROWNUM = 1;
            END IF;

            --End changes by BT Technology team on 23 Feb 2016

            fnd_file.put_line (FND_FILE.LOG, 'l_region2 : ' || l_region);
        EXCEPTION
            WHEN OTHERS
            THEN
                --Start changes by BT Technology Team on 24-Jun-2015 for defect#2624
                -- RETURN pn_full_lead_time;
                RETURN CEIL (NVL (pn_full_lead_time, 0) * 5 / 7);
                fnd_file.put_line (FND_FILE.LOG,
                                   'Test Exception 2 : ' || l_region);
        --End changes by BT Technology Team on 24-Jun-2015 for defect#2624
        END;



        --Finding Vendor Name and Vendor Site
        BEGIN
            SELECT mso.vendor_id, vs.vendor_site_code
              INTO l_vendor_name, l_vendor_site
              FROM mrp_assignment_sets mrp, mrp_sr_assignments msra, mrp_sourcing_rules msr,
                   MRP_SR_SOURCE_ORG mso, PO_VENDOR_SITES_ALL VS, MRP_SR_RECEIPT_ORG msrov
             WHERE     assignment_set_name LIKE '%' || L_REGION || '%' -- 'Deckers Default Set-US/JP'
                   AND mrp.assignment_set_id = msra.assignment_set_id
                   AND msr.sourcing_rule_id = msra.sourcing_rule_id
                   AND msrov.sourcing_rule_id = msr.sourcing_rule_id
                   AND msra.category_id = ln_category_id
                   --                AND msra.organization_id = pn_organization_id
                   --                AND msra.organization_id =
                   --                       DECODE (l_region,
                   --                               'EMEA', 129,
                   --                               'APAC', 129,
                   --                               'CA', 129, -- CA2_LEAD_TIME
                   --                               pn_organization_id
                   --                               ) -- hardcoded to 129 for MC1 org
                   AND msra.organization_id =
                       (SELECT TO_NUMBER (attribute2)
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXDO_ORG_SRC_RULE_MAP'
                               AND TO_NUMBER (attribute1) =
                                   pn_organization_id
                               AND language = 'US')            --CA2_LEAD_TIME
                   AND msra.assignment_type = 5
                   AND mso.allocation_percent = 100
                   AND mso.RANK = 1
                   AND mso.sr_receipt_id = msrov.sr_receipt_id
                   AND VS.VENDOR_SITE_ID(+) = mso.VENDOR_SITE_ID
                   --Start Modification on 22-APR-2016
                   --AND SYSDATE BETWEEN msrov.effective_date  AND TRUNC (NVL (msrov.disable_date, SYSDATE + 1))
                   AND SYSDATE BETWEEN msrov.effective_date - 1
                                   AND TRUNC (
                                           NVL (msrov.disable_date + 1,
                                                SYSDATE + 1));
        --End Modification on 22-APR-2016
        --                AND ROWNUM = 1;


        EXCEPTION
            -- SRC_RULE_CORRECT -- Start
            WHEN TOO_MANY_ROWS
            THEN
                BEGIN
                    SELECT mso.vendor_id, vs.vendor_site_code
                      INTO l_vendor_name, l_vendor_site
                      FROM mrp_assignment_sets mrp, mrp_sr_assignments msra, mrp_sourcing_rules msr,
                           MRP_SR_SOURCE_ORG mso, PO_VENDOR_SITES_ALL VS, MRP_SR_RECEIPT_ORG msrov
                     WHERE     assignment_set_name LIKE
                                   '%' || L_REGION || '%' -- 'Deckers Default Set-US/JP'
                           AND mrp.assignment_set_id = msra.assignment_set_id
                           AND msr.sourcing_rule_id = msra.sourcing_rule_id
                           AND msrov.sourcing_rule_id = msr.sourcing_rule_id
                           AND msra.category_id = ln_category_id
                           --Start changes by BT Technology team on 23 Feb 2016
                           --                AND msra.organization_id = pn_organization_id
                           --                        AND msra.organization_id =
                           --                               DECODE (l_region,
                           --                                       'EMEA', 129,
                           --                                       'APAC', 129,
                           --                                       'CA', 129, -- CA2_LEAD_TIME
                           --                                       pn_organization_id) -- hardcoded to 129 for MC1 org
                           --End changes by BT Technology team on 23 Feb 2016
                           AND msra.organization_id =
                               (SELECT TO_NUMBER (attribute2)
                                  FROM fnd_lookup_values
                                 WHERE     lookup_type =
                                           'XXDO_ORG_SRC_RULE_MAP'
                                       AND TO_NUMBER (attribute1) =
                                           pn_organization_id
                                       AND language = 'US')    --CA2_LEAD_TIME
                           AND msra.assignment_type = 5
                           AND mso.allocation_percent = 100
                           AND mso.RANK = 1
                           AND mso.sr_receipt_id = msrov.sr_receipt_id
                           AND VS.VENDOR_SITE_ID(+) = mso.VENDOR_SITE_ID
                           --Start Modification on 22-APR-2016
                           AND SYSDATE + 1 BETWEEN TRUNC (
                                                       msrov.effective_date)
                                               AND TRUNC (
                                                       NVL (
                                                           msrov.disable_date,
                                                           SYSDATE + 2));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        SELECT organization_code
                          INTO lc_organization_code
                          FROM mtl_parameters
                         WHERE organization_id = pn_organization_id;

                        fnd_file.put_line (
                            FND_FILE.LOG,
                               'IN THE EXCEPTION SECTION @LEAD_TIME_CAL: '
                            || SQLERRM);
                        fnd_file.put_line (fnd_file.LOG,
                                           'l_vendor_name ' || l_vendor_name);
                        fnd_file.put_line (fnd_file.LOG,
                                           'l_vendor_site ' || l_vendor_site);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'pn_INVENTORY_ITEM_ID ' || pn_inventory_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'pn_organization_id ' || pn_organization_id);


                        IF     l_vendor_name IS NULL
                           AND l_vendor_site IS NULL
                           AND lc_organization_code != 'JP5'
                        THEN
                            UPDATE xxdo.xxdoascp_item_attr_upd_stg2
                               SET STATUS = 1, --             ERROR_MESSAGE = 'Sourcing rule not setup for style '||lc_style ||' and color '||lc_color
                                               ERROR_MESSAGE = 'Sourcing rule not setup for style color ' || lc_style || '-' || lc_color
                             WHERE     INVENTORY_ITEM_ID = pn_inventory_id
                                   AND ORGANIZATION_ID = pn_organization_id;
                        END IF;
                END;
            -- SRC_RULE_CORRECT -- End
            WHEN OTHERS
            THEN
                --Start changes by BT Technology Team on 24-Jun-2015 for defect#2624
                -- RETURN pn_full_lead_time;
                SELECT organization_code
                  INTO lc_organization_code
                  FROM mtl_parameters
                 WHERE organization_id = pn_organization_id;

                fnd_file.put_line (
                    FND_FILE.LOG,
                    'IN THE EXCEPTION SECTION @LEAD_TIME_CAL: ' || SQLERRM);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_vendor_name ' || l_vendor_name);
                fnd_file.put_line (fnd_file.LOG,
                                   'l_vendor_site ' || l_vendor_site);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'pn_INVENTORY_ITEM_ID ' || pn_inventory_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'pn_organization_id ' || pn_organization_id);

                --Start modification on 29-APR-2016

                IF     l_vendor_name IS NULL
                   AND l_vendor_site IS NULL
                   AND lc_organization_code != 'JP5'
                THEN
                    UPDATE xxdo.xxdoascp_item_attr_upd_stg2
                       SET STATUS = 1, --             ERROR_MESSAGE = 'Sourcing rule not setup for style '||lc_style ||' and color '||lc_color
                                       ERROR_MESSAGE = 'Sourcing rule not setup for style color ' || lc_style || '-' || lc_color
                     WHERE     INVENTORY_ITEM_ID = pn_inventory_id
                           AND ORGANIZATION_ID = pn_organization_id;
                END IF;
        --End modification on 29-APR-2016
        --End changes by BT Technology Team on  06 Apr 2016
        --End changes by BT Technology Team on 24-Jun-2015 for defect#2624
        END;


        --Start changes by BT Technology Team on06 Apr 2016
        IF lc_organization_code != 'JP5'
        THEN
            RETURN CEIL (NVL (pn_full_lead_time, 0) * 5 / 7);
        ELSE
            fnd_file.put_line (
                FND_FILE.LOG,
                'IN THE EXCEPTION SECTION @LEAD_TIME_CAL: ' || SQLERRM);
        END IF;



        IF p_sample LIKE '%SAMPLE%'
        THEN
            BEGIN
                --started commenting for CCR0006305
                /*SELECT attribute5
                  INTO lc_transit_days
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                       AND language = 'US'
                       AND attribute4 = l_territory_short_name
                       AND attribute1 = l_vendor_name
                       AND attribute2 = l_vendor_site;*/
                --ended commenting for CCR0006305
                lc_transit_days   :=
                    fetch_transit_lead_time (
                        pv_country_code    => l_territory_code,
                        pv_supplier_code   => l_vendor_site); --added for CCR0006305
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_transit_days   := NULL;
            END;
        ELSE
            BEGIN
                --started commenting for CCR0006305
                /*SELECT attribute6
                  INTO lc_transit_days
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                       AND language = 'US'
                       AND attribute4 = l_territory_short_name
                       AND attribute1 = l_vendor_name
                       AND attribute2 = l_vendor_site;*/
                --ended commenting for CCR0006305
                lc_transit_days   :=
                    fetch_transit_lead_time (
                        pv_country_code    => l_territory_code,
                        pv_supplier_code   => l_vendor_site); --added for CCR0006305
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_transit_days   := NULL;
            END;
        END IF;

        fnd_file.put_line (
            FND_FILE.LOG,
            'before calculation lc_transit_days : ' || lc_transit_days);
        fnd_file.put_line (
            FND_FILE.LOG,
               'before calculation pn_full_lead_time : '
            || NVL (pn_full_lead_time, 0));

        ln_lead_time   :=
            CEIL (
                  5
                / 7
                * (NVL (pn_full_lead_time, 0) + NVL (lc_transit_days, 0)));
        fnd_file.put_line (FND_FILE.LOG, 'ln_lead_time : ' || ln_lead_time);

        --Start changes for CR 117
        SELECT organization_code
          INTO lc_organization_code
          FROM mtl_parameters
         WHERE organization_id = pn_organization_id;

        IF lc_organization_code = 'JP5'
        THEN
            ln_japan_intransit_time   :=
                get_japan_intransit_time (ln_category_id, p_sample);
            fnd_file.put_line (
                FND_FILE.LOG,
                'ln_japan_intransit_time : ' || ln_japan_intransit_time);

            ln_lead_time   :=
                CEIL (
                      5
                    / 7
                    * (NVL (pn_full_lead_time, 0) + NVL (ln_japan_intransit_time, 0))); -- + NVL (lc_transit_days, 0)
        END IF;

        -- end Changes for CR 117
        fnd_file.put_line (FND_FILE.LOG, 'ln_lead_time : ' || ln_lead_time);
        RETURN ln_lead_time;
    EXCEPTION
        WHEN OTHERS
        THEN
            --Start changes by BT Technology Team on 24-Jun-2015 for defect#2624
            -- RETURN pn_full_lead_time;
            RETURN CEIL (NVL (pn_full_lead_time, 0) * 5 / 7);
    --End changes by BT Technology Team on 24-Jun-2015 for defect#2624
    END lead_time_cal;

    --started adding for CCR0006305
    FUNCTION fetch_transit_lead_time (pv_country_code    IN VARCHAR2,
                                      pv_supplier_code   IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_transit_days   NUMBER;
    BEGIN
        SELECT DISTINCT
               DECODE (UPPER (ATTRIBUTE8),  'TRUCK', ATTRIBUTE7,  'AIR', ATTRIBUTE5,  ATTRIBUTE6) newval
          INTO ln_transit_days
          FROM fnd_lookup_values_vl
         WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
               AND attribute2 = pv_supplier_code
               AND attribute3 = pv_country_code
               AND NVL (enabled_flag, 'Y') = 'Y';

        --AND attribute8 IS NOT NULL;

        RETURN ln_transit_days;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END fetch_transit_lead_time;

    --ended adding for CCR0006305


    PROCEDURE Update_Make_buy_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_make_buy   = 1
         WHERE UPPER (NVL (make_buy, NULL)) = 'MAKE';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_make_buy   = 2
         WHERE UPPER (NVL (make_buy, NULL)) = 'BUY';

        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for make_buy'
         WHERE make_buy IS NOT NULL AND xxdo_make_buy IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_Make_buy_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_Make_buy_Ids;

    PROCEDURE Update_Mrp_Planning_Method_Ids (pv_retcode OUT VARCHAR2)
    IS
        --Started adding for CCR0006305
        CURSOR cur_xxdo_mrp_planning_method IS
            SELECT xia.ROWID row_id, msib.mrp_planning_code
              FROM mtl_system_items_b msib, xxdoascp_item_attr_upd_stg2 xia, mtl_parameters mpa
             WHERE     xia.request_id = gn_request_id
                   AND xia.inventory_item_id = msib.inventory_item_id
                   AND msib.organization_id = mpa.organization_id
                   AND mpa.organization_code = 'MST';
    --ended adding for CCR0006305
    BEGIN
        --Started adding for CCR0006305
        FOR rec_xxdo_mrp_planning_method IN cur_xxdo_mrp_planning_method
        LOOP
            UPDATE xxdoascp_item_attr_upd_stg2
               SET xxdo_mrp_planning_method = rec_xxdo_mrp_planning_method.mrp_planning_code
             WHERE ROWID = rec_xxdo_mrp_planning_method.row_id;
        END LOOP;

        COMMIT;

        --ended adding for CCR0006305
        --started commenting for CCR0006305
        /*UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_mrp_planning_method = 4
         WHERE UPPER (NVL (mrp_planning_method, NULL)) = 'MPS PLANNING';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_mrp_planning_method = 6
         WHERE UPPER (NVL (mrp_planning_method, NULL)) = 'NOT PLANNED';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_mrp_planning_method = 3
         WHERE UPPER (NVL (mrp_planning_method, NULL)) = 'MRP PLANNING';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_mrp_planning_method = 7
         WHERE UPPER (NVL (mrp_planning_method, NULL)) = 'MRP/MPP PLANNED';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_mrp_planning_method = 8
         WHERE UPPER (NVL (mrp_planning_method, NULL)) = 'MPS/MPP PLANNED';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_mrp_planning_method = 9
         WHERE UPPER (NVL (mrp_planning_method, NULL)) = 'MPP PLANNED';

        COMMIT;
    */
        --ended commenting for CCR0006305
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for mrp_planning_method'
         WHERE     mrp_planning_method IS NOT NULL
               AND xxdo_mrp_planning_method IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_Mrp_Planning_Method_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_Mrp_Planning_Method_Ids;

    PROCEDURE Update_forecast_ctrl_methd_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_forecast_control_method   = 1
         WHERE UPPER (NVL (forecast_control_method, NULL)) = 'CONSUME';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_forecast_control_method   = 2
         WHERE UPPER (NVL (forecast_control_method, NULL)) =
               'CONSUME AND DERIVE';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_forecast_control_method   = 3
         WHERE UPPER (NVL (forecast_control_method, NULL)) = 'NONE';

        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for forecast_control_method'
         WHERE     forecast_control_method IS NOT NULL
               AND xxdo_forecast_control_method IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_forecast_ctrl_methd_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_forecast_ctrl_methd_Ids;

    PROCEDURE Update_end_assem_pegging_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_end_assembly_pegging   = 'A'
         WHERE UPPER (NVL (end_assembly_pegging, NULL)) = 'SOFT PEGGING';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_end_assembly_pegging   = 'Y'
         WHERE UPPER (NVL (end_assembly_pegging, NULL)) =
               'END ASSEMBLY PEGGING';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_end_assembly_pegging   = 'B'
         WHERE UPPER (NVL (end_assembly_pegging, NULL)) =
               'END ASSEMBLY / SOFT PEGGING';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_end_assembly_pegging   = 'I'
         WHERE UPPER (NVL (end_assembly_pegging, NULL)) = 'HARD PEGGING';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_end_assembly_pegging   = 'X'
         WHERE UPPER (NVL (end_assembly_pegging, NULL)) =
               'END ASSEMBLY / HARD PEGGING';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_end_assembly_pegging   = 'X'
         WHERE UPPER (NVL (end_assembly_pegging, NULL)) = 'NONE';

        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for end_assembly_pegging'
         WHERE     end_assembly_pegging IS NOT NULL
               AND xxdo_end_assembly_pegging IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_end_assem_pegging_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_end_assem_pegging_Ids;

    PROCEDURE Update_plan_time_fence_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_planning_time_fence   = 1
         WHERE UPPER (NVL (planning_time_fence, NULL)) =
               'CUMULATIVE TOTAL LEAD TIME';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_planning_time_fence   = 2
         WHERE UPPER (NVL (planning_time_fence, NULL)) =
               'CUMULATIVE MFG. LEAD TIME';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_planning_time_fence   = 3
         WHERE UPPER (NVL (planning_time_fence, NULL)) = 'TOTAL LEAD TIME';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_planning_time_fence   = 4
         WHERE UPPER (NVL (planning_time_fence, NULL)) = 'USER-DEFINED';

        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for planning_time_fence'
         WHERE     planning_time_fence IS NOT NULL
               AND xxdo_planning_time_fence IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_plan_time_fence_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_plan_time_fence_Ids;

    PROCEDURE Update_demand_time_fence_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_demand_time_fence   = 1
         WHERE UPPER (NVL (demand_time_fence, NULL)) =
               'CUMULATIVE TOTAL LEAD TIME';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_demand_time_fence   = 2
         WHERE UPPER (NVL (demand_time_fence, NULL)) =
               'CUMULATIVE MFG. LEAD TIME';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_demand_time_fence   = 3
         WHERE UPPER (NVL (demand_time_fence, NULL)) = 'TOTAL LEAD TIME';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_demand_time_fence   = 4
         WHERE UPPER (NVL (demand_time_fence, NULL)) = 'USER-DEFINED';


        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for demand_time_fence'
         WHERE     demand_time_fence IS NOT NULL
               AND demand_time_fence <> ' '
               AND xxdo_demand_time_fence IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_demand_time_fence_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_demand_time_fence_Ids;

    PROCEDURE Update_check_atp_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_check_atp   = 'Y'
         WHERE UPPER (NVL (check_atp, NULL)) = 'MATERIAL ONLY';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_check_atp   = 'R'
         WHERE UPPER (NVL (check_atp, NULL)) = 'RESOURCE ONLY';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_check_atp   = 'C'
         WHERE UPPER (NVL (check_atp, NULL)) = 'MATERIAL AND RESOURCE';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_check_atp   = 'N'
         WHERE UPPER (NVL (check_atp, NULL)) = 'NONE';


        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for check_atp'
         WHERE check_atp IS NOT NULL AND xxdo_check_atp IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_check_atp_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_check_atp_Ids;

    PROCEDURE Update_atp_components_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_atp_components   = 'Y'
         WHERE UPPER (NVL (atp_components, NULL)) = 'MATERIAL ONLY';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_atp_components   = 'R'
         WHERE UPPER (NVL (atp_components, NULL)) = 'RESOURCE ONLY';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_atp_components   = 'C'
         WHERE UPPER (NVL (atp_components, NULL)) = 'MATERIAL AND RESOURCE';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_atp_components   = 'N'
         WHERE UPPER (NVL (atp_components, NULL)) = 'NONE';


        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for atp_components'
         WHERE atp_components IS NOT NULL AND xxdo_atp_components IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_atp_components_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_atp_components_Ids;

    PROCEDURE Update_round_order_qty_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_round_order_qty   = 1
         WHERE UPPER (NVL (round_order_quantities, NULL)) = 'YES';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_round_order_qty   = 2
         WHERE UPPER (NVL (round_order_quantities, NULL)) = 'NO';


        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for round_order_quantities'
         WHERE     round_order_quantities IS NOT NULL
               AND xxdo_round_order_qty IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_round_order_qty_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_round_order_qty_Ids;

    PROCEDURE Update_create_supply_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_create_supply   = 'Y'
         WHERE UPPER (NVL (create_supply, NULL)) = 'YES';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_create_supply   = 'N'
         WHERE UPPER (NVL (create_supply, NULL)) = 'NO';


        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for create_supply'
         WHERE create_supply IS NOT NULL AND xxdo_create_supply IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_create_supply_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_create_supply_Ids;

    PROCEDURE Update_inv_plan_method_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_inv_planning_method   = 2
         WHERE UPPER (NVL (inventory_planning_method, NULL)) = 'MIN-MAX';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_inv_planning_method   = 6
         WHERE UPPER (NVL (inventory_planning_method, NULL)) = 'NOT PLANNED';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_inv_planning_method   = 1
         WHERE UPPER (NVL (inventory_planning_method, NULL)) =
               'REORDER POINT';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_inv_planning_method   = 7
         WHERE UPPER (NVL (inventory_planning_method, NULL)) =
               'VENDOR MANAGED';


        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for inventory_planning_method'
         WHERE     inventory_planning_method IS NOT NULL
               AND xxdo_inv_planning_method IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_inv_plan_method_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_inv_plan_method_Ids;

    PROCEDURE Update_safety_stock_method_Ids (pv_retcode OUT VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_safety_stock_method   = 2
         WHERE UPPER (NVL (safety_stock_method, NULL)) = 'MRP PLANNED%';

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET xxdo_safety_stock_method   = 1
         WHERE UPPER (NVL (safety_stock_method, NULL)) = 'NON-MRP PLANNED';


        COMMIT;

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET STATUS = 1, ERROR_MESSAGE = 'Invalid value for safety_stock_method'
         WHERE     safety_stock_method IS NOT NULL
               AND xxdo_safety_stock_method IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in Update_safety_stock_method_Ids'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END Update_safety_stock_method_Ids;

    -- **********************************************************************
    -- This procedure is used to extract records from staging table 1 to 2
    -- **********************************************************************

    PROCEDURE p_item_extract (pv_errbuf    OUT VARCHAR2,
                              pv_retcode   OUT VARCHAR2) -- Start Added By BT Technology Team
    IS
        CURSOR items_cur IS
            SELECT a.inv_org_code,
                   a.item_number,
                   a.category_structure,
                   a.category_code,
                   a.item_template,
                   a.default_buyer,
                   a.list_price,
                   a.make_buy,
                   a.planner_code,
                   a.min_order_qty,
                   a.fixed_order_qty,
                   a.mrp_planning_method,
                   a.forecast_control_method,
                   a.end_assembly_pegging,
                   a.planning_time_fence,
                   a.plan_time_fence_days,
                   a.demand_time_fence,
                   a.demand_time_fence_days,
                   a.pre_processing_lead_time,
                   a.processing_lead_time,
                   a.post_processing_lead_time,
                   a.check_atp,
                   a.atp_components,
                   a.atp_rule,
                   a.fixed_days_supply,
                   a.fixed_lot_multiplier,
                   a.round_order_quantities,
                   a.create_supply,
                   a.inventory_planning_method,
                   a.max_order_qty,
                   a.safety_stock_method,
                   a.safety_stock_bucket_days,
                   a.safety_stock_percent,
                   a.sno,
                   NVL (mp.organization_id, NULL) organization_id,
                   gn_request_id,
                   supplier,
                   supplier_site,
                   product_line,
                   (SELECT NVL (inventory_item_id, NULL)
                      FROM mtl_system_items_b
                     WHERE     segment1 = item_number
                           AND organization_id = mp.organization_id) inventory_item_id
              FROM xxdoascp_item_attr_upd_stg a, mtl_parameters mp
             WHERE     mp.organization_code(+) = a.inv_org_code
                   AND a.item_number IS NOT NULL
                   AND status = 99;

        CURSOR style_color_cur IS
            SELECT a.style_color, a.inv_org_code, a.category_structure,
                   a.category_code, msib.segment1 item_number, a.item_template,
                   a.default_buyer, a.list_price, a.make_buy,
                   a.planner_code, a.min_order_qty, a.fixed_order_qty,
                   a.mrp_planning_method, a.forecast_control_method, a.end_assembly_pegging,
                   a.planning_time_fence, a.plan_time_fence_days, a.demand_time_fence,
                   a.demand_time_fence_days, a.pre_processing_lead_time, a.processing_lead_time,
                   a.post_processing_lead_time, a.check_atp, a.atp_components,
                   a.atp_rule, a.fixed_days_supply, a.fixed_lot_multiplier,
                   a.round_order_quantities, a.create_supply, a.inventory_planning_method,
                   a.max_order_qty, a.safety_stock_method, a.safety_stock_bucket_days,
                   a.safety_stock_percent, a.sno, a.supplier,
                   a.supplier_site, a.product_line, msib.organization_id organization_id,
                   msib.inventory_item_id inventory_item_id
              FROM xxdo.xxdoascp_item_attr_upd_stg a, mtl_system_items_b msib, mtl_parameters mp
             WHERE     a.item_number IS NULL
                   AND a.style_color IS NOT NULL
                   AND a.status = 99
                   AND a.STYLE_COLOR = SUBSTR (msib.SEGMENT1,
                                               1,
                                                 INSTR (msib.SEGMENT1, '-', 1
                                                        , 2)
                                               - 1)
                   AND mp.organization_code = a.inv_org_code
                   AND mp.organization_id = msib.organization_id;


        TYPE t_items IS TABLE OF items_cur%ROWTYPE
            INDEX BY BINARY_INTEGER;

        TYPE t_style_color IS TABLE OF style_color_cur%ROWTYPE
            INDEX BY BINARY_INTEGER;

        rec_items_tbl         t_items;

        rec_style_color_tbl   t_style_color;



        l_count               NUMBER := 0;
        l_insert_count        NUMBER := 0;
        e_bulk_errors         EXCEPTION;
        PRAGMA EXCEPTION_INIT (e_bulk_errors, -24381);
        l_indx                NUMBER;
        l_indx2               NUMBER;
        l_error_count         NUMBER := 0;
        l_error_count2        NUMBER := 0;
        l_msg                 VARCHAR2 (4000);
        l_msg2                VARCHAR2 (4000);
        l_idx                 NUMBER;
        l_idx2                NUMBER;
        lv_retcode            VARCHAR2 (100);

        ln_count              NUMBER;
    BEGIN
        SELECT COUNT (1) INTO ln_count FROM xxdo.xxdoascp_item_attr_upd_stg;

        fnd_file.put_line (fnd_file.LOG, 'ln_count ' || ln_count);

        OPEN items_cur;


        LOOP
            rec_items_tbl.DELETE;

            FETCH items_cur BULK COLLECT INTO rec_items_tbl LIMIT 2000;

            EXIT WHEN rec_items_tbl.COUNT = 0;

            BEGIN
                FORALL l_indx IN 1 .. rec_items_tbl.COUNT SAVE EXCEPTIONS
                    INSERT INTO xxdo.xxdoascp_item_attr_upd_stg2 (
                                    inv_org_code,
                                    item_number,
                                    category_structure,
                                    category_code,
                                    item_template,
                                    default_buyer,
                                    list_price,
                                    make_buy,
                                    planner_code,
                                    min_order_qty,
                                    fixed_order_qty,
                                    mrp_planning_method,
                                    forecast_control_method,
                                    end_assembly_pegging,
                                    planning_time_fence,
                                    plan_time_fence_days,
                                    demand_time_fence,
                                    demand_time_fence_days,
                                    pre_processing_lead_time,
                                    processing_lead_time,
                                    post_processing_lead_time,
                                    check_atp,
                                    atp_components,
                                    atp_rule,
                                    fixed_days_supply,
                                    fixed_lot_multiplier,
                                    round_order_quantities,
                                    create_supply,
                                    inventory_planning_method,
                                    max_order_qty,
                                    safety_stock_method,
                                    safety_stock_bucket_days,
                                    safety_stock_percent,
                                    sno,
                                    status,
                                    status_category,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    organization_id,
                                    request_id,
                                    supplier,
                                    supplier_site,
                                    product_line,
                                    inventory_item_id)
                         VALUES (rec_items_tbl (l_indx).inv_org_code, rec_items_tbl (l_indx).item_number, rec_items_tbl (l_indx).category_structure, rec_items_tbl (l_indx).category_code, rec_items_tbl (l_indx).item_template, rec_items_tbl (l_indx).default_buyer, rec_items_tbl (l_indx).list_price, rec_items_tbl (l_indx).make_buy, rec_items_tbl (l_indx).planner_code, rec_items_tbl (l_indx).min_order_qty, rec_items_tbl (l_indx).fixed_order_qty, rec_items_tbl (l_indx).mrp_planning_method, rec_items_tbl (l_indx).forecast_control_method, rec_items_tbl (l_indx).end_assembly_pegging, rec_items_tbl (l_indx).planning_time_fence, rec_items_tbl (l_indx).plan_time_fence_days, rec_items_tbl (l_indx).demand_time_fence, rec_items_tbl (l_indx).demand_time_fence_days, rec_items_tbl (l_indx).pre_processing_lead_time, rec_items_tbl (l_indx).processing_lead_time, rec_items_tbl (l_indx).post_processing_lead_time, rec_items_tbl (l_indx).check_atp, rec_items_tbl (l_indx).atp_components, rec_items_tbl (l_indx).atp_rule, rec_items_tbl (l_indx).fixed_days_supply, rec_items_tbl (l_indx).fixed_lot_multiplier, rec_items_tbl (l_indx).round_order_quantities, rec_items_tbl (l_indx).create_supply, rec_items_tbl (l_indx).inventory_planning_method, rec_items_tbl (l_indx).max_order_qty, rec_items_tbl (l_indx).safety_stock_method, rec_items_tbl (l_indx).safety_stock_bucket_days, rec_items_tbl (l_indx).safety_stock_percent, rec_items_tbl (l_indx).sno, 0, 0, gn_created_by, SYSDATE, gn_created_by, SYSDATE, rec_items_tbl (l_indx).organization_id, gn_request_id, rec_items_tbl (l_indx).supplier, rec_items_tbl (l_indx).supplier_site, rec_items_tbl (l_indx).product_line
                                 , rec_items_tbl (l_indx).inventory_item_id);

                l_insert_count   := l_insert_count + SQL%ROWCOUNT;
                COMMIT;
            EXCEPTION
                WHEN e_bulk_errors
                THEN
                    l_error_count   := SQL%BULK_EXCEPTIONS.COUNT;

                    FOR i IN 1 .. l_error_count
                    LOOP
                        l_msg   :=
                            SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                        l_idx   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;
                        apps.fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to insert item -'
                            || rec_items_tbl (l_idx).item_number
                            || ' for  org  -'
                            || rec_items_tbl (l_idx).inv_org_code
                            || ' with error_code- '
                            || l_msg);
                    END LOOP;
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        fnd_file.LOG,
                           'Inside Others for items_cur insert. '
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
            END;
        END LOOP;

        SELECT COUNT (1) INTO ln_count FROM xxdo.xxdoascp_item_attr_upd_stg2;

        fnd_file.put_line (fnd_file.LOG, 'ln_count ' || ln_count);

        rec_items_tbl.DELETE;

        CLOSE items_cur;

        COMMIT;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               l_insert_count
            || ' Records inserted into table xxdo.xxdoascp_item_attr_upd_stg2 for item_number');

        OPEN style_color_cur;



        LOOP
            rec_style_color_tbl.DELETE;

            FETCH style_color_cur
                BULK COLLECT INTO rec_style_color_tbl
                LIMIT 2000;

            EXIT WHEN rec_style_color_tbl.COUNT = 0;

            BEGIN
                FORALL l_indx2 IN 1 .. rec_style_color_tbl.COUNT
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo.xxdoascp_item_attr_upd_stg2 (
                                    inv_org_code,
                                    item_number,
                                    category_structure,
                                    category_code,
                                    item_template,
                                    default_buyer,
                                    list_price,
                                    make_buy,
                                    planner_code,
                                    min_order_qty,
                                    fixed_order_qty,
                                    mrp_planning_method,
                                    forecast_control_method,
                                    end_assembly_pegging,
                                    planning_time_fence,
                                    plan_time_fence_days,
                                    demand_time_fence,
                                    demand_time_fence_days,
                                    pre_processing_lead_time,
                                    processing_lead_time,
                                    post_processing_lead_time,
                                    check_atp,
                                    atp_components,
                                    atp_rule,
                                    fixed_days_supply,
                                    fixed_lot_multiplier,
                                    round_order_quantities,
                                    create_supply,
                                    inventory_planning_method,
                                    max_order_qty,
                                    safety_stock_method,
                                    safety_stock_bucket_days,
                                    safety_stock_percent,
                                    sno,
                                    status,
                                    status_category,
                                    created_by,
                                    creation_date,
                                    last_updated_by,
                                    last_update_date,
                                    organization_id,
                                    request_id,
                                    supplier,
                                    supplier_site,
                                    product_line,
                                    inventory_item_id)
                             VALUES (
                                        rec_style_color_tbl (l_indx2).inv_org_code,
                                        rec_style_color_tbl (l_indx2).item_number,
                                        rec_style_color_tbl (l_indx2).category_structure,
                                        rec_style_color_tbl (l_indx2).category_code,
                                        rec_style_color_tbl (l_indx2).item_template,
                                        rec_style_color_tbl (l_indx2).default_buyer,
                                        rec_style_color_tbl (l_indx2).list_price,
                                        rec_style_color_tbl (l_indx2).make_buy,
                                        rec_style_color_tbl (l_indx2).planner_code,
                                        rec_style_color_tbl (l_indx2).min_order_qty,
                                        rec_style_color_tbl (l_indx2).fixed_order_qty,
                                        rec_style_color_tbl (l_indx2).mrp_planning_method,
                                        rec_style_color_tbl (l_indx2).forecast_control_method,
                                        rec_style_color_tbl (l_indx2).end_assembly_pegging,
                                        rec_style_color_tbl (l_indx2).planning_time_fence,
                                        rec_style_color_tbl (l_indx2).plan_time_fence_days,
                                        rec_style_color_tbl (l_indx2).demand_time_fence,
                                        rec_style_color_tbl (l_indx2).demand_time_fence_days,
                                        rec_style_color_tbl (l_indx2).pre_processing_lead_time,
                                        rec_style_color_tbl (l_indx2).processing_lead_time,
                                        rec_style_color_tbl (l_indx2).post_processing_lead_time,
                                        rec_style_color_tbl (l_indx2).check_atp,
                                        rec_style_color_tbl (l_indx2).atp_components,
                                        rec_style_color_tbl (l_indx2).atp_rule,
                                        rec_style_color_tbl (l_indx2).fixed_days_supply,
                                        rec_style_color_tbl (l_indx2).fixed_lot_multiplier,
                                        rec_style_color_tbl (l_indx2).round_order_quantities,
                                        rec_style_color_tbl (l_indx2).create_supply,
                                        rec_style_color_tbl (l_indx2).inventory_planning_method,
                                        rec_style_color_tbl (l_indx2).max_order_qty,
                                        rec_style_color_tbl (l_indx2).safety_stock_method,
                                        rec_style_color_tbl (l_indx2).safety_stock_bucket_days,
                                        rec_style_color_tbl (l_indx2).safety_stock_percent,
                                        rec_style_color_tbl (l_indx2).sno,
                                        0,
                                        0,
                                        gn_created_by,
                                        SYSDATE,
                                        gn_created_by,
                                        SYSDATE,
                                        rec_style_color_tbl (l_indx2).organization_id,
                                        gn_request_id,
                                        rec_style_color_tbl (l_indx2).supplier,
                                        rec_style_color_tbl (l_indx2).supplier_site,
                                        rec_style_color_tbl (l_indx2).product_line,
                                        rec_style_color_tbl (l_indx2).inventory_item_id);

                l_count   := l_count + SQL%ROWCOUNT;
                COMMIT;
            EXCEPTION
                WHEN e_bulk_errors
                THEN
                    l_error_count   := SQL%BULK_EXCEPTIONS.COUNT;

                    FOR i IN 1 .. l_error_count
                    LOOP
                        l_msg2   :=
                            SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                        l_idx2   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;
                        apps.fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to insert item -'
                            || rec_style_color_tbl (l_idx2).item_number
                            || ' for  org  -'
                            || rec_style_color_tbl (l_idx2).inv_org_code
                            || ' with error_code- '
                            || l_msg2);
                    END LOOP;
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        fnd_file.LOG,
                           'Inside Others for items_cur insert. '
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
            END;
        END LOOP;

        rec_style_color_tbl.DELETE;

        CLOSE style_color_cur;

        COMMIT;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               l_count
            || ' Records inserted into table xxdo.xxdoascp_item_attr_upd_stg2 for style_color -'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS'));

        BEGIN
            UPDATE xxdo.xxdoascp_item_attr_upd_stg
               SET status   = -1
             WHERE status = 99;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error While Updating records in Staging table xxdoascp_item_attr_upd_stg'
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;


        ---------------------------------------------
        --   Deriving Id for make_buy attribute
        ---------------------------------------------
        lv_retcode   := NULL;
        Update_Make_buy_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;


        ------------------------------------------------------
        --        Deriving Id for MRP_PLANNING_METHOD
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_Mrp_Planning_Method_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;

        ------------------------------------------------------
        --        Deriving Id for FORECAST_CONTROL_METHOD
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_forecast_ctrl_methd_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;


        ------------------------------------------------------
        --        Deriving Id for END_ASSEMBLY_PEGGING
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_end_assem_pegging_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;

        ------------------------------------------------------
        --        Deriving Id for PLANNING_TIME_FENCE
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_plan_time_fence_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;

        ------------------------------------------------------
        --        Deriving Id for DEMAND_TIME_FENCE
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_demand_time_fence_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;

        ------------------------------------------------------
        --        Deriving Id for CHECK_ATP
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_check_atp_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;


        ------------------------------------------------------
        --        Deriving Id for ATP_COMPONENTS
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_atp_components_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;

        ------------------------------------------------------
        --        Deriving Id for ROUND_ORDER_QUANTITIES
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_round_order_qty_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;

        ------------------------------------------------------
        --        Deriving Id for CREATE_SUPPLY
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_create_supply_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;


        ------------------------------------------------------
        --        Deriving Ids for SAFETY_STOCK_METHOD
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_safety_stock_method_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;

        ------------------------------------------------------
        --        Deriving Ids for INVENTORY_PLANNING_METHOD
        ------------------------------------------------------
        lv_retcode   := NULL;
        Update_inv_plan_method_Ids (lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            pv_retcode   := 2;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others exception in p_item_extract'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END p_item_extract;                     -- END Added By BT Technology Team

    --This procedure Validates and Updates the staging table with necessary ID's     -- Start Commented By BT Technology Team
    /* PROCEDURE stg_tbl_upd_proc (
        pv_errbuff       OUT      VARCHAR2,
        pv_retcode       OUT      VARCHAR2,
        pn_conc_req_id   IN       NUMBER
     )
     IS
  ----------------------------------------------------------------------------------------------------
  --local variables declaration
  ----------------------------------------------------------------------------------------------------
        ln_inv_org_id                apps.org_organization_definitions.organization_id%TYPE;
        --   ln_inv_item_id               apps.mtl_system_items_b.inventory_item_id%TYPE;
        ln_category_id               apps.mtl_categories_b.category_id%TYPE;
        ln_id_flex_num               apps.fnd_id_flex_structures_tl.id_flex_num%TYPE;
        lv_id_flex_structure_name    apps.fnd_id_flex_structures_tl.id_flex_structure_name%TYPE;
        ln_template_id               apps.mtl_item_templates.template_id%TYPE;
        ln_category_set_name         apps.mtl_category_sets.category_set_name%TYPE;
        ln_fixed_days_supply         apps.mtl_system_items_b.fixed_days_supply%TYPE;
        ln_fixed_lot_multiplier      apps.mtl_system_items_b.fixed_lot_multiplier%TYPE;
        ln_buyer_id                  apps.po_agents.agent_id%TYPE;
        ln_atp_rule_id               apps.mtl_atp_rules.rule_id%TYPE;
        lv_planner_code              apps.mtl_planners.planner_code%TYPE;
        ln_mrp_planning_code         NUMBER;
        ln_forecast_control_method   NUMBER;
        ln_planning_time_fence       NUMBER;
        ln_demand_time_fence         NUMBER;
        ln_make_buy                  NUMBER;
        ln_parent_conc_req_id        NUMBER;
        lv_end_assembly_pegging      VARCHAR2 (100);
        lv_check_atp                 VARCHAR2 (100);
        lv_atp_components            VARCHAR2 (100);
        lv_errmsg                    VARCHAR2 (240);
        lv_err_msg                   VARCHAR2 (240);
        lv_err_msg1                  VARCHAR2 (240);
        lv_sqlerrm                   VARCHAR2 (1000);
        lv_error_msg                 VARCHAR2 (2000);
        lv_error_msg1                VARCHAR2 (2000);
        lv_round_ord_qty             apps.mtl_system_items_b.rounding_control_type%TYPE;
                                                  --added by BT Technology Team
        lv_create_sup_flag           apps.mtl_system_items_b.create_supply_flag%TYPE;
                                                  --added by BT Technology Team
        ln_inv_planning_code         NUMBER;      --added by BT Technology Team
        ln_safety_stock_code         NUMBER;

  --------------------------------------------------------------------------------------------------
  --Cursor Declarations
  --------------------------------------------------------------------------------------------------
  --------------------------------------------------------------------------------------------------
  --Checking for the duplicate records of Items in the Data file
  --------------------------------------------------------------------------------------------------
        CURSOR dup_cur
        IS
           SELECT *
             FROM xxdo.xxdoascp_item_attr_upd_stg xiau_dup
            WHERE NVL (xiau_dup.status, 0) = 0
              AND xiau_dup.request_id = pn_conc_req_id
              AND xiau_dup.ROWID >
                     ANY (SELECT xiau_dup1.ROWID
                            FROM xxdo.xxdoascp_item_attr_upd_stg xiau_dup1
                           WHERE NVL (xiau_dup1.status, 0) = 0
                             AND xiau_dup.inv_org_code = xiau_dup1.inv_org_code
                             AND xiau_dup.item_number = xiau_dup1.item_number);

  --------------------------------------------------------------------------------------------------
   --Checking for the duplicate records of category codes with structures in the Data file
  --------------------------------------------------------------------------------------------------
        CURSOR dupcat_cur
        IS
           SELECT *
             FROM xxdo.xxdoascp_item_attr_upd_stg xiau_dupcat
            WHERE NVL (xiau_dupcat.status, 0) = 0
              AND xiau_dupcat.request_id = pn_conc_req_id
              AND xiau_dupcat.ROWID >
                     ANY (SELECT xiau_dupcat1.ROWID
                            FROM xxdo.xxdoascp_item_attr_upd_stg xiau_dupcat1
                           WHERE NVL (xiau_dupcat1.status, 0) = 0
                             AND xiau_dupcat.inv_org_code =
                                                       xiau_dupcat1.inv_org_code
                             AND xiau_dupcat.category_code =
                                                      xiau_dupcat1.category_code);

  ----------------------------------------------------------------------------------------------------
  --This Cursor picks up Newly entered Records of Items
  ----------------------------------------------------------------------------------------------------
        CURSOR stg_upd_cur
        IS
           SELECT *
             FROM xxdo.xxdoascp_item_attr_upd_stg xiau_upd
            WHERE category_structure IS NULL
              AND category_code IS NULL
              AND NVL (xiau_upd.status, 0) = 0
              AND xiau_upd.request_id = pn_conc_req_id;

  ----------------------------------------------------------------------------------------------------
  ---This Cursor is to fetch the records which are of with structure ID and category id to be NOT NULL
  ----------------------------------------------------------------------------------------------------
        CURSOR strcat_cur
        IS
           SELECT *
             FROM xxdo.xxdoascp_item_attr_upd_stg xiau_upd
            WHERE category_structure IS NOT NULL
              AND category_code IS NOT NULL
              AND NVL (xiau_upd.status, 0) = 0
              AND xiau_upd.request_id = pn_conc_req_id;

  ----------------------------------------------------------------------------------------------------
  ---Cusror for picking up the Items for the Category_id's with NOT NULL VALUES
  ----------------------------------------------------------------------------------------------------
        CURSOR item_cur (pn_category_id NUMBER, pn_org_code VARCHAR)
        IS
           SELECT msib.organization_id, msib.segment1
                                                     --  || '-'               --commented by bt technology team
                                                     --  || msib.segment2     --commented by bt technology team
                                                     --  || '-'               --commented by bt technology team
                                                     --  || msib.segment3     --commented by bt technology team
                  item_number
             FROM apps.mtl_system_items_b msib,
                  apps.mtl_item_categories mic,
                  apps.mtl_categories mc
            WHERE msib.inventory_item_id = mic.inventory_item_id
              AND msib.organization_id = mic.organization_id
              AND mic.category_id = mc.category_id
              AND mic.category_id = pn_category_id
              AND msib.segment3 <> 'ALL'
              AND msib.organization_id =
                                       (SELECT organization_id
                                          FROM apps.org_organization_definitions
                                         WHERE organization_code = pn_org_code);
  ------------------------------------------------------------------------------------
  --Begin of staging table update procedure execution section
  ------------------------------------------------------------------------------------
     BEGIN
  --------------------------------------------------------------------------------------------------------
  ---Checking for the duplicate records for Items coming from the data file
  --------------------------------------------------------------------------------------------------------
        FOR dup_rec IN dup_cur
        LOOP
           BEGIN
              UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_d
                 SET xiau_d.status = 1,
                     xiau_d.error_message =
                                          'Duplicate Record for item Validation',
                     xiau_d.created_by = gn_created_by,
                     xiau_d.creation_date = gd_creation_date,
                     xiau_d.last_updated_by = gn_updated_by,
                     xiau_d.last_update_date = gd_update_date
               WHERE xiau_d.request_id = pn_conc_req_id
                 AND xiau_d.sno = dup_rec.sno;
           EXCEPTION
              WHEN OTHERS
              THEN
                 lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);

                 UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_de
                    SET xiau_de.status = 50,
                        xiau_de.error_message =
                              'Duplicate Item Record Validation: ' || lv_sqlerrm,
                        xiau_de.created_by = gn_created_by,
                        xiau_de.creation_date = gd_creation_date,
                        xiau_de.last_updated_by = gn_updated_by,
                        xiau_de.last_update_date = gd_update_date
                  WHERE xiau_de.request_id = pn_conc_req_id;

                 COMMIT;
                 pv_retcode := 2;
                 pv_errbuff :=
                              'Duplicate Item Record Validation: ' || lv_sqlerrm;
                 RAISE;
           END;
        END LOOP;                   ---End of Checking for the duplicate records

  ------------------------------------------------------------------------------------------------
  --Checking for the duplicate records for Categories coming from the data file
  ------------------------------------------------------------------------------------------------
        FOR dupcat_rec IN dupcat_cur
        LOOP
           BEGIN
              UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_dc
                 SET xiau_dc.status = 1,
                     xiau_dc.error_message = 'Duplicate Record for Category',
                     xiau_dc.created_by = gn_created_by,
                     xiau_dc.creation_date = gd_creation_date,
                     xiau_dc.last_updated_by = gn_updated_by,
                     xiau_dc.last_update_date = gd_update_date
               WHERE xiau_dc.request_id = pn_conc_req_id
                 AND xiau_dc.sno = dupcat_rec.sno;
           EXCEPTION
              WHEN OTHERS
              THEN
                 lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);

                 UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_dce
                    SET xiau_dce.status = 1,
                        xiau_dce.error_message =
                           'Duplicate Category Record Validation: '
                           || lv_sqlerrm,
                        xiau_dce.created_by = gn_created_by,
                        xiau_dce.creation_date = gd_creation_date,
                        xiau_dce.last_updated_by = gn_updated_by,
                        xiau_dce.last_update_date = gd_update_date
                  WHERE xiau_dce.request_id = pn_conc_req_id;

                 COMMIT;
                 pv_retcode := 2;
                 pv_errbuff :=
                              'Duplicate Item Record Validation: ' || lv_sqlerrm;
                 RAISE;
           END;
        END LOOP;      ---End of Checking for the duplicate records for Category

        COMMIT;                           --Commiting after the duplicate checks

  ----------------------------------------------------------------------------------
  -- Loop to fetch the valid Items to the provided Strcuture and Category Code
  -----------------------------------------------------------------------------------
        FOR strcat_c IN strcat_cur
        LOOP
           lv_error_msg := NULL;
           lv_error_msg1 := NULL;
           ln_inv_org_id := NULL;
           ln_template_id := NULL;
           ln_id_flex_num := NULL;
           lv_id_flex_structure_name := NULL;
           ln_category_set_name := NULL;

           --Validating Whether Organization is NULL
           IF strcat_c.inv_org_code IS NULL
           THEN
              lv_error_msg := ' Organization provided is NULL, Invalid Record ';
           ELSE
              BEGIN
                 SELECT ood.organization_id
                   INTO ln_inv_org_id
                   FROM apps.org_organization_definitions ood
                  WHERE ood.organization_code =
                                            UPPER (TRIM (strcat_c.inv_org_code));
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR
                          (   strcat_c.inv_org_code
                           || ' Invalid Organization Code and Organization does not Exists ',
                           1,
                           1999
                          );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   strcat_c.inv_org_code
                           || ' Invalid Organization Code and Organization doesnot Exists - Exception '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --Validating the Item Template
           IF strcat_c.item_template IS NULL
           THEN
              lv_error_msg :=
                 SUBSTR (   lv_error_msg
                         || ' Item Template provided is NULL, Invalid Record ',
                         1,
                         1999
                        );
           ELSE
              BEGIN
                 SELECT template_id
                   INTO ln_template_id
                   FROM apps.mtl_item_templates mit
                  WHERE UPPER (TRIM (template_name)) =
                                           UPPER (TRIM (strcat_c.item_template));
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ' - '
                               || strcat_c.item_template
                               || ' is not a valid template ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ' Exception occured while validating Item template '
                           || strcat_c.item_template
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --Validating the category structure
           BEGIN
              SELECT id_flex_num, id_flex_structure_name,
                     mcs.category_set_name
                INTO ln_id_flex_num, lv_id_flex_structure_name,
                     ln_category_set_name
                FROM apps.fnd_id_flex_structures_vl f,
                     apps.mtl_category_sets mcs
               WHERE TRIM (UPPER (f.id_flex_structure_name)) =
                                      TRIM (UPPER (strcat_c.category_structure))
                 AND f.id_flex_num = mcs.structure_id;
           EXCEPTION
              WHEN NO_DATA_FOUND
              THEN
                 lv_errmsg :=
                       ' There is no Structure defined with the given structure  - '
                    || strcat_c.category_structure;

                 UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_str
                    SET xiau_str.status = 1,
                        xiau_str.error_message = lv_errmsg,
                        xiau_str.created_by = gn_created_by,
                        xiau_str.creation_date = gd_creation_date,
                        xiau_str.last_updated_by = gn_updated_by,
                        xiau_str.last_update_date = gd_update_date
                  WHERE xiau_str.request_id = pn_conc_req_id
                    AND xiau_str.sno = strcat_c.sno;
              WHEN OTHERS
              THEN
                 lv_error_msg1 :=
                       ' There is an Exception Occured while retreiving the structure  :'
                    || strcat_c.category_structure;
           END;

           IF ln_category_set_name IS NOT NULL
           THEN
              BEGIN
                 SELECT category_id
                   INTO ln_category_id
                   FROM apps.mtl_categories_kfv mck
                  WHERE mck.concatenated_segments =
                                           TRIM (UPPER (strcat_c.category_code))
                    AND mck.structure_id = ln_id_flex_num;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_errmsg :=
                          ' There is no Category Code - '
                       || strcat_c.category_code
                       || ' with the given structure - '
                       || strcat_c.category_structure;

                    UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_cid
                       SET xiau_cid.status = 1,
                           xiau_cid.error_message = lv_errmsg,
                           xiau_cid.created_by = gn_created_by,
                           xiau_cid.creation_date = gd_creation_date,
                           xiau_cid.last_updated_by = gn_updated_by,
                           xiau_cid.last_update_date = gd_update_date
                     WHERE xiau_cid.request_id = pn_conc_req_id
                       AND xiau_cid.sno = strcat_c.sno;
                 WHEN OTHERS
                 THEN
                    lv_error_msg1 :=
                          'There is an exception occured while retreiving the - '
                       || strcat_c.category_code
                       || ' under the given structure - '
                       || strcat_c.category_structure;
              END;
           ELSE
              lv_errmsg := 'The Category Structure is not valid ';

              UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_cid11
                 SET xiau_cid11.status = 1,
                     xiau_cid11.error_message = lv_errmsg,
                     xiau_cid11.created_by = gn_created_by,
                     xiau_cid11.creation_date = gd_creation_date,
                     xiau_cid11.last_updated_by = gn_updated_by,
                     xiau_cid11.last_update_date = gd_update_date
               WHERE xiau_cid11.request_id = pn_conc_req_id
                 AND xiau_cid11.sno = strcat_c.sno;
           END IF;

           IF (lv_error_msg IS NULL) AND (lv_error_msg1 IS NULL)
           THEN
              FOR item_c IN item_cur (ln_category_id, strcat_c.inv_org_code)
              LOOP
                 BEGIN
                    INSERT INTO xxdo.xxdoascp_item_attr_upd_stg
                                (sno,
                                 inv_org_code, item_number,
                                 item_template,
                                 default_buyer, list_price,
                                 make_buy, planner_code,
                                 min_order_qty,
                                 fixed_order_qty,
                                 mrp_planning_method,
                                 forecast_control_method,
                                 end_assembly_pegging,
                                 planning_time_fence,
                                 plan_time_fence_days,
                                 demand_time_fence,
                                 demand_time_fence_days,
                                 pre_processing_lead_time,
                                 processing_lead_time,
                                 post_processing_lead_time,
                                 check_atp, atp_components,
                                 atp_rule,
                                 fixed_days_supply,
                                 fixed_lot_multiplier,
                                 status, pno,
                                 request_id, file_name
                                )
                         VALUES (xxdo.xxdoascp_item_attr_upd_stg_s.NEXTVAL,
                                 strcat_c.inv_org_code, item_c.item_number,
                                 strcat_c.item_template,
                                 strcat_c.default_buyer, strcat_c.list_price,
                                 strcat_c.make_buy, strcat_c.planner_code,
                                 strcat_c.min_order_qty,
                                 strcat_c.fixed_order_qty,
                                 strcat_c.mrp_planning_method,
                                 strcat_c.forecast_control_method,
                                 strcat_c.end_assembly_pegging,
                                 strcat_c.planning_time_fence,
                                 strcat_c.plan_time_fence_days,
                                 strcat_c.demand_time_fence,
                                 strcat_c.demand_time_fence_days,
                                 strcat_c.pre_processing_lead_time,
                                 strcat_c.processing_lead_time,
                                 strcat_c.post_processing_lead_time,
                                 strcat_c.check_atp, strcat_c.atp_components,
                                 strcat_c.atp_rule,
                                 strcat_c.fixed_days_supply,
                                 strcat_c.fixed_lot_multiplier,
                                 strcat_c.status, strcat_c.sno,
                                 pn_conc_req_id, strcat_c.file_name
                                );
                 EXCEPTION
                    WHEN OTHERS
                    THEN
                       apps.fnd_file.put_line
                          (apps.fnd_file.LOG,
                           'Exception Occured while Inserting the Items based on Category'
                          );
                 END;
              END LOOP;

              --Updating the Valid category and the Record status and message as Soft Delete
              BEGIN
                 UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_cv
                    SET xiau_cv.status = 20,
                        xiau_cv.error_message = 'Soft Delete',
                        xiau_cv.created_by = gn_created_by,
                        xiau_cv.creation_date = gd_creation_date,
                        xiau_cv.last_updated_by = gn_updated_by,
                        xiau_cv.last_update_date = gd_update_date
                  WHERE xiau_cv.request_id = pn_conc_req_id
                    AND xiau_cv.sno = strcat_c.sno;

                 COMMIT;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    lv_error_msg1 :=
                       SUBSTR
                            (   ' Category Validation in Exception Section - '
                             || SQLERRM,
                             1,
                             1999
                            );

                    UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_cv1
                       SET xiau_cv1.status = 50,
                           xiau_cv1.error_message =
                                 ' Category Validation in Exception Section - '
                              || lv_sqlerrm,
                           xiau_cv1.created_by = gn_created_by,
                           xiau_cv1.creation_date = gd_creation_date,
                           xiau_cv1.last_updated_by = gn_updated_by,
                           xiau_cv1.last_update_date = gd_update_date
                     WHERE xiau_cv1.request_id = pn_conc_req_id
                       AND xiau_cv1.sno = strcat_c.sno;
              END;
           ELSE
              BEGIN
                 UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_ue
                    SET xiau_ue.status = DECODE (lv_error_msg1, NULL, 1, 50),
                        --If lv_error_msg1 is not null, then status is updated as Technical Error
                        xiau_ue.error_message = lv_error_msg,
                        xiau_ue.ex_message = lv_error_msg1,
                        xiau_ue.created_by = gn_created_by,
                        xiau_ue.creation_date = gd_creation_date,
                        xiau_ue.last_updated_by = gn_updated_by,
                        xiau_ue.last_update_date = gd_update_date
                  WHERE xiau_ue.sno = strcat_c.sno
                    AND xiau_ue.request_id = pn_conc_req_id;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    apps.fnd_file.put_line
                       (apps.fnd_file.LOG,
                           'Error while updating stg table with Records failing Validation : '
                        || SQLERRM
                       );
                    pv_errbuff :=
                       SUBSTR
                          (   pv_errbuff
                           || ' Error while updating stg table with Records failing Validation : '
                           || SQLERRM,
                           1,
                           1999
                          );
                    pv_retcode := 2;
              END;
           END IF;

           IF MOD (strcat_cur%ROWCOUNT, 5000) = 0
           THEN
              COMMIT;
           END IF;
        END LOOP;                                             --strcat_cur ended

        COMMIT;                        --Committing for the strcat_c cursor loop

  ------------------------------------------------------------------------------------
      ---Opening the stg_upd_cur for execution
  ------------------------------------------------------------------------------------
        FOR stg_upd_rec IN stg_upd_cur
        LOOP
           ln_inv_org_id := NULL;
           ln_inv_item_id := NULL;
           ln_template_id := NULL;
           ln_mrp_planning_code := NULL;
           ln_forecast_control_method := NULL;
           lv_end_assembly_pegging := NULL;
           ln_fixed_days_supply := NULL;
           ln_fixed_lot_multiplier := NULL;
           ln_buyer_id := NULL;
           ln_planning_time_fence := NULL;
           ln_demand_time_fence := NULL;
           lv_check_atp := NULL;
           lv_atp_components := NULL;
           ln_atp_rule_id := NULL;
           ln_make_buy := NULL;
           lv_planner_code := NULL;
           lv_sqlerrm := NULL;
           lv_error_msg := NULL;
           lv_error_msg1 := NULL;
           lc_ret_brand_value1 := NULL;
           ln_inv_planning_code := NULL;

           --* ****************** Validating the Organization ID ****************
           IF stg_upd_rec.inv_org_code IS NULL
           THEN
              lv_error_msg := ' Organization provided is NULL, Invalid Record ';
           ELSE
              BEGIN
                 SELECT ood.organization_id
                   INTO ln_inv_org_id
                   FROM apps.org_organization_definitions ood
                  WHERE ood.organization_code =
                                         UPPER (TRIM (stg_upd_rec.inv_org_code));

                 apps.fnd_file.put_line (apps.fnd_file.LOG,
                                         'Organization id ' || ln_inv_org_id
                                        );
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR
                          (   lv_error_msg
                           || ':'
                           || stg_upd_rec.inv_org_code
                           || ' Invalid Organization Code and Organization doesnot Exists ',
                           1,
                           1999
                          );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   stg_upd_rec.inv_org_code
                           || ' Invalid Organization Code and Organization doesnot Exists - Exception '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --*************************** Fetching the Item ID ************************
           IF stg_upd_rec.item_number IS NULL
           THEN
              lv_error_msg :=
                 SUBSTR (   lv_error_msg
                         || ':'
                         || ' Item Number provided is NULL, Invalid Record ',
                         1,
                         1999
                        );
           ELSE
              BEGIN
                 SELECT msib.inventory_item_id
                   INTO ln_inv_item_id
                   FROM apps.mtl_system_items_b msib
                  WHERE msib.segment1 = stg_upd_rec.item_number
                    --    || '-'                                      --commented by bt technology team
                    --    || msib.segment2                            --commented by bt technology team
                    --    || '-'                                      --commented by bt technology team
                    --    || msib.segment3 = stg_upd_rec.item_number  --commented by bt technology team
                    AND msib.organization_id = ln_inv_org_id;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || stg_upd_rec.item_number
                               || ' Item doesnot Exists in '
                               || stg_upd_rec.inv_org_code
                               || ' Organization',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR (   lv_error_msg1
                               || ' Exception occured while loading Item '
                               || stg_upd_rec.item_number
                               || ' - '
                               || lv_sqlerrm,
                               1,
                               1999
                              );
              END;
           END IF;

           --***************Validating the Template ID**********************
           IF stg_upd_rec.item_template IS NULL
           THEN
              lv_error_msg :=
                 SUBSTR (   lv_error_msg
                         || ' Item Template provided is NULL, Invalid Record ',
                         1,
                         1999
                        );
           ELSE
              BEGIN
                 SELECT template_id
                   INTO ln_template_id
                   FROM apps.mtl_item_templates mit
                  WHERE UPPER (TRIM (template_name)) =
                                        UPPER (TRIM (stg_upd_rec.item_template));
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ' - '
                               || stg_upd_rec.item_template
                               || ' is not a valid template ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ' Exception occured while loading Item template '
                           || stg_upd_rec.item_template
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --********* Person_ID Verification **********
           IF stg_upd_rec.default_buyer IS NOT NULL
           -- and ln_buyer_id is null  -- added by ss 0801015
           THEN
              BEGIN
                 ln_buyer_id := NULL;

                 BEGIN
                    SELECT agent_id
                      INTO ln_buyer_id
                      FROM apps.po_agents_v
                     WHERE UPPER (TRIM (agent_name)) =
                                        UPPER (TRIM (stg_upd_rec.default_buyer));
                 END;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no buyer with '
                               || stg_upd_rec.default_buyer
                               || '. Hence doesnot Exists ',
                               1,
                               1999
                              );
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'Buyer into the Exception section'
                                           );
                 WHEN OTHERS
                 THEN
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'Error in Buyer id Information'
                                           );
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR (   lv_error_msg1
                               || ':'
                               || ' Exception occured while loading buyer info'
                               || stg_upd_rec.default_buyer
                               || ' - '
                               || lv_sqlerrm,
                               1,
                               1999
                              );
              END;
           END IF;

           --************** MRP_PLANNING_CODE Validation *********
           IF stg_upd_rec.mrp_planning_method IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE (UPPER (TRIM (stg_upd_rec.mrp_planning_method)),
                                'MPS PLANNING', 4,
                                'NOT PLANNED', 6,
                                'MRP PLANNING', 3,
                                'MRP/MPP PLANNED', 7,
                                'MPS/MPP PLANNED', 8,
                                'MPP PLANNED', 9
                               )
                   INTO ln_mrp_planning_code
                   FROM DUAL;

                 IF ln_mrp_planning_code IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined Planning method '
                               || stg_upd_rec.mrp_planning_method
                               || '. Hence doesnot Exists ',
                               1,
                               1999
                              );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    apps.fnd_file.put_line (apps.fnd_file.LOG,
                                               'MRP Planning data not found '
                                            || stg_upd_rec.mrp_planning_method
                                           );
                    lv_error_msg := 'Not a Valid Planning Method';
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading Planning method '
                           || stg_upd_rec.mrp_planning_method
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --****************************FORECAST_CONTROL_METHOD***************
           IF stg_upd_rec.forecast_control_method IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE
                              (UPPER (TRIM (stg_upd_rec.forecast_control_method)),
                               'CONSUME', 1,
                               'CONSUME AND DERIVE', 2,
                               'NONE', 3
                              )
                   INTO ln_forecast_control_method
                   FROM DUAL;

                 IF ln_forecast_control_method IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR
                           (   lv_error_msg
                            || ':'
                            || ' There is no defined forecast control method '
                            || stg_upd_rec.forecast_control_method
                            || '. Hence doesnot Exists ',
                            1,
                            1999
                           );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined forecast control method ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading forecast control method '
                           || stg_upd_rec.forecast_control_method
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --*********************** End Assembly Pegging *************************
           IF stg_upd_rec.end_assembly_pegging IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE (UPPER (TRIM (stg_upd_rec.end_assembly_pegging)),
                                'SOFT PEGGING', 'A',
                                'END ASSEMBLY PEGGING', 'Y',
                                'END ASSEMBLY / SOFT PEGGING', 'B',
                                'HARD PEGGING', 'I',
                                'END ASSEMBLY / HARD PEGGING', 'X',
                                'NONE', 'N'
                               )
                   INTO lv_end_assembly_pegging
                   FROM DUAL;

                 IF lv_end_assembly_pegging IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR
                          (   lv_error_msg
                           || ':'
                           || ' There is no defined End Assembly Pegging with : '
                           || stg_upd_rec.end_assembly_pegging
                           || '. Hence doesnot Exists ',
                           1,
                           1999
                          );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                                   ' There is no defined End Assembly Pegging ';
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading End Assembly Pegging with : '
                           || stg_upd_rec.end_assembly_pegging
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --***************** Planning time fence Validation******************
           IF stg_upd_rec.planning_time_fence IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE (UPPER (TRIM (stg_upd_rec.planning_time_fence)),
                                'CUMULATIVE TOTAL LEAD TIME', 1,
                                'CUMULATIVE MFG. LEAD TIME', 2,
                                'TOTAL LEAD TIME', 3,
                                'USER-DEFINED', 4
                               )
                   INTO ln_planning_time_fence
                   FROM DUAL;

                 IF ln_planning_time_fence IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined planning time fence '
                               || stg_upd_rec.planning_time_fence
                               || '. Hence doesnot Exists ',
                               1,
                               1999
                              );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined planning time fence ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading planning time fence '
                           || stg_upd_rec.planning_time_fence
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --***************** Demand Time Fence Validation ***********************
           IF stg_upd_rec.demand_time_fence IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE (UPPER (TRIM (stg_upd_rec.demand_time_fence)),
                                'CUMULATIVE TOTAL LEAD TIME', 1,
                                'CUMULATIVE MFG. LEAD TIME', 2,
                                'TOTAL LEAD TIME', 3,
                                'USER-DEFINED', 4,
                                ' ', NULL
                               )
                   INTO ln_demand_time_fence
                   FROM DUAL;

                 IF ln_demand_time_fence IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined demand time fence '
                               || stg_upd_rec.demand_time_fence
                               || '. Hence doesnot Exists ',
                               1,
                               1999
                              );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined demand time fence ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading demand time fence '
                           || stg_upd_rec.demand_time_fence
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

  --******************** CHECK ATP ****************************************
           IF stg_upd_rec.check_atp IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE (UPPER (TRIM (stg_upd_rec.check_atp)),
                                'MATERIAL ONLY', 'Y',
                                'RESOURCE ONLY', 'R',
                                'MATERIAL AND RESOURCE', 'C',
                                'NONE', 'N'
                               )
                   INTO lv_check_atp
                   FROM DUAL;

                 IF lv_check_atp IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined check atp value '
                               || stg_upd_rec.check_atp
                               || '. Hence doesnot Exists ',
                               1,
                               1999
                              );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined check atp value ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading check atp value '
                           || stg_upd_rec.check_atp
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --******************Validating ATP Components **************************
           IF stg_upd_rec.atp_components IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE (UPPER (TRIM (stg_upd_rec.atp_components)),
                                'MATERIAL ONLY', 'Y',
                                'RESOURCE ONLY', 'R',
                                'MATERIAL AND RESOURCE', 'C',
                                'NONE', 'N'
                               )
                   INTO lv_atp_components
                   FROM DUAL;

                 IF lv_atp_components IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined Atp components '
                               || stg_upd_rec.atp_components
                               || '. Hence doesnot Exists ',
                               1,
                               1999
                              );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined Atp components ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading ATP components value '
                           || stg_upd_rec.atp_components
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --********************************** Validating ATP Rule ***********************
           IF stg_upd_rec.atp_rule IS NOT NULL
           THEN
              BEGIN
                 SELECT rule_id
                   INTO ln_atp_rule_id
                   FROM apps.mtl_atp_rules
                  WHERE UPPER (TRIM (rule_name)) =
                                             UPPER (TRIM (stg_upd_rec.atp_rule));
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined Atp rule '
                               || stg_upd_rec.atp_rule
                               || '. Hence doesnot Exists ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading ATP rule value '
                           || stg_upd_rec.atp_rule
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --*********************** Validating the Make_Buy code****************************
           IF stg_upd_rec.make_buy IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE (UPPER (TRIM (stg_upd_rec.make_buy)),
                                'MAKE', 1,
                                'BUY', 2
                               )
                   INTO ln_make_buy
                   FROM DUAL;

                 IF ln_make_buy IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined Make Buy Value '
                               || stg_upd_rec.make_buy
                               || '. Hence doesnot Exists ',
                               1,
                               1999
                              );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined Make Buy Value ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading Make Buy value '
                           || stg_upd_rec.make_buy
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --*******************Validating the Valid Planner Code ***********
           IF (    stg_upd_rec.planner_code IS NOT NULL
               AND stg_upd_rec.planner_code <> '!'       -- Added on 02-JUL-2014
              )            --and lv_planner_code is null  --added by ss 08012015
           THEN
              BEGIN
                 SELECT planner_code
                   INTO lv_planner_code
                   FROM apps.mtl_planners mp
                  WHERE UPPER (TRIM (mp.planner_code)) =
                                         UPPER (TRIM (stg_upd_rec.planner_code))
                    AND mp.organization_id = ln_inv_org_id;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    lv_error_msg :=
                       SUBSTR (   lv_error_msg
                               || ':'
                               || ' There is no defined Planner Code Value '
                               || stg_upd_rec.planner_code
                               || ' for Org '
                               || stg_upd_rec.inv_org_code
                               || '. Hence doesnot Exists ',
                               1,
                               1999
                              );
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading planner code value '
                           || stg_upd_rec.planner_code
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           ELSIF stg_upd_rec.planner_code = '!'
           THEN
              lv_planner_code := '!';
           END IF;

           --******************* Validating the Fixed Days Supply **************************
           IF stg_upd_rec.fixed_days_supply IS NOT NULL
           THEN
              ln_fixed_days_supply := stg_upd_rec.fixed_days_supply;
           END IF;

           --*******************Validating the Fixed Lot Multiplier**************************
           IF stg_upd_rec.fixed_lot_multiplier IS NOT NULL
           THEN
              ln_fixed_lot_multiplier := stg_upd_rec.fixed_lot_multiplier;
           END IF;

           --******************* Validating Round Order Quantities  ****************  -- added be BT Technology Team
           IF stg_upd_rec.round_order_quantities IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE (UPPER (TRIM (stg_upd_rec.round_order_quantities)),
                                'YES', 1,
                                'NO', 2,
                                3
                               )
                   INTO lv_round_ord_qty
                   FROM DUAL;

                 IF lv_round_ord_qty = 3
                 THEN
                    lv_error_msg :=
                       SUBSTR
                          (   lv_error_msg
                           || ':'
                           || ' There is no defined Round Order Quantities, It should be  yes or No !!'
                           || stg_upd_rec.round_order_quantities
                           || '. Hence doesnot Exists ',
                           1,
                           1999
                          );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    apps.fnd_file.put_line
                                  (apps.fnd_file.LOG,
                                      'Valid Round Order Quantities Not Found '
                                   || stg_upd_rec.round_order_quantities
                                  );
                    lv_error_msg :=
                       'Not a Valid Round Order Quantities It should be yes or no';
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading Round Order Quantities '
                           || stg_upd_rec.round_order_quantities
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --******************  Round Order Quantities Validation completed*********************************** ***************

           --******************  Create supply Flag Validation *********************************** **************** -- added be BT Technology Team
           IF stg_upd_rec.create_supply IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE (UPPER (TRIM (stg_upd_rec.create_supply)),
                                'YES', 'Y',
                                'NO', 'N'
                               )
                   INTO lv_create_sup_flag
                   FROM DUAL;

                 IF lv_create_sup_flag IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR
                          (   lv_error_msg
                           || ':'
                           || ' There is no defined create Supply Flag, It should be  Y or N !!'
                           || stg_upd_rec.create_supply
                           || '. Hence doesnot Exists ',
                           1,
                           1999
                          );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    apps.fnd_file.put_line
                                      (apps.fnd_file.LOG,
                                          'Valid Create Supply Flag Not Found '
                                       || stg_upd_rec.create_supply
                                      );
                    lv_error_msg :=
                            'Not a Valid Create Supply Flag It should be Y or N';
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading Create Supply Flag '
                           || stg_upd_rec.create_supply
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --******************  Create supply Flag Validation completed *********************************** ****************

           --****************** Inventory Planning Code Validation ****************************************************** -- added be BT Technology Team
           IF stg_upd_rec.inventory_planning_method IS NOT NULL
           THEN
              BEGIN
                 SELECT DECODE
                            (UPPER (TRIM (stg_upd_rec.inventory_planning_method)),
                             'MIN-MAX', 2,
                             'NOT PLANNED', 6,
                             'REORDER POINT', 1,
                             'VENDOR MANAGED', 7
                            )
                   INTO ln_inv_planning_code
                   FROM DUAL;

                 IF ln_inv_planning_code IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR
                          (   lv_error_msg
                           || ':'
                           || ' There is no defined Inventory Planning method '
                           || stg_upd_rec.inventory_planning_method
                           || '. Hence doesnot Exists ',
                           1,
                           1999
                          );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    apps.fnd_file.put_line
                                     (apps.fnd_file.LOG,
                                         'Inventoary  Planning data not found '
                                      || stg_upd_rec.inventory_planning_method
                                     );
                    lv_error_msg := 'Not a Valid Planning Method';
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading Inventory Planning method '
                           || stg_upd_rec.inventory_planning_method
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;

           --****************** Inventory Planning Code Validation completed ***********************************


             --****************** Safety Stcok Method Validation ***********************************


      IF stg_upd_rec.safety_stock_method IS NOT NULL
              THEN
               BEGIN
                 SELECT DECODE( UPPER (TRIM (stg_upd_rec.safety_stock_method)),
                             'MRP PLANNED%', 2,
                             'NON-MRP PLANNED',1
                            )
                   INTO ln_safety_stock_code
                   FROM DUAL;

                 IF ln_safety_stock_code IS NULL
                 THEN
                    lv_error_msg :=
                       SUBSTR
                          (   lv_error_msg
                           || ':'
                           || ' There is no defined safety_stock_method '
                           || stg_upd_rec.safety_stock_method
                           || '. Hence doesnot Exists ',
                           1,
                           1999
                          );
                 END IF;
              EXCEPTION
                 WHEN NO_DATA_FOUND
                 THEN
                    apps.fnd_file.put_line
                                     (apps.fnd_file.LOG,
                                         'Safety Stock method data not found '
                                      || stg_upd_rec.safety_stock_method
                                     );
                    lv_error_msg := 'Not a Valid Safety Stock Method';
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := NULL;
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);
                    lv_error_msg1 :=
                       SUBSTR
                          (   lv_error_msg1
                           || ':'
                           || ' Exception occured while loading Safety Stock method  '
                           || stg_upd_rec.Safety_Stock_method
                           || ' - '
                           || lv_sqlerrm,
                           1,
                           1999
                          );
              END;
           END IF;


           --*******************************************************************************
           IF (lv_error_msg IS NULL AND lv_error_msg1 IS NULL)
           THEN
              BEGIN
                 UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_u
                    SET xiau_u.organization_id = ln_inv_org_id,
                        xiau_u.inventory_item_id = ln_inv_item_id,
                        xiau_u.buyer_id = ln_buyer_id,
                        xiau_u.template_id = ln_template_id,
                        xiau_u.mrp_planning_code = ln_mrp_planning_code,
                        xiau_u.ato_forecast_control_flag =
                                                      ln_forecast_control_method,
                        xiau_u.end_assembly_pegging_flag =
                                                         lv_end_assembly_pegging,
                        xiau_u.planning_time_fence_code = ln_planning_time_fence,
                        xiau_u.demand_time_fence_flag = ln_demand_time_fence,
                        xiau_u.check_atp_flag = lv_check_atp,
                        xiau_u.atp_components_flag = lv_atp_components,
                        xiau_u.atp_rule_id = ln_atp_rule_id,
                        xiau_u.planning_make_buy_code = ln_make_buy,
                        xiau_u.planner_code = lv_planner_code,
                        xiau_u.fixed_days_supply = ln_fixed_days_supply,
                        xiau_u.fixed_lot_multiplier = ln_fixed_lot_multiplier,
                        xiau_u.rounding_ord_type = lv_round_ord_qty,
                                                   --added by BT Technology Team
                        xiau_u.create_supply_flag = lv_create_sup_flag,
                                                   --added by BT Technology Team
                        xiau_u.status = 2,
                        xiau_u.error_message = NULL,
                        xiau_u.created_by = gn_created_by,
                        xiau_u.creation_date = gd_creation_date,
                        xiau_u.last_updated_by = gn_updated_by,
                        xiau_u.last_update_date = gd_update_date,
                        xiau_u.inventory_planning_code =
                                     ln_inv_planning_code,  --added by BT Technology Team
                        xiau_u.safety_stock_code =ln_safety_stock_code  --added by BT Technology Team
                  WHERE xiau_u.sno = stg_upd_rec.sno
                    AND xiau_u.request_id = pn_conc_req_id;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    lv_sqlerrm := SUBSTR (SQLERRM, 1, 900);

                    UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_ue
                       SET xiau_ue.status = 50,
                           xiau_ue.error_message = lv_sqlerrm,
                           xiau_ue.request_id = gn_conc_req_id
                     WHERE xiau_ue.sno = stg_upd_rec.sno
                       AND xiau_ue.request_id = pn_conc_req_id;
              END;
           ELSE
              UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_u1
                 SET xiau_u1.status = 1,
                     xiau_u1.error_message = lv_error_msg,
                     xiau_u1.ex_message = lv_error_msg1,
                     xiau_u1.created_by = gn_created_by,
                     xiau_u1.creation_date = gd_creation_date,
                     xiau_u1.last_updated_by = gn_updated_by,
                     xiau_u1.last_update_date = gd_update_date
               WHERE xiau_u1.sno = stg_upd_rec.sno
                 AND xiau_u1.request_id = pn_conc_req_id;
           END IF;

           IF MOD (stg_upd_cur%ROWCOUNT, 5000) = 0
           THEN
              COMMIT;
           END IF;
        END LOOP;                                      ---End of the stg_upd_cur

        COMMIT;
     END stg_tbl_upd_proc;   */
    ---End of the stg_tbl_upd_proc-- END Commented By BT Technology Team

    --**********************************************************************
    PROCEDURE stg_tbl_upd_proc (pv_errbuff   OUT VARCHAR2, -- Start Added By BT Technology Team
                                pv_retcode   OUT VARCHAR2)
    IS
        CURSOR itemattr_cur IS
              SELECT *
                FROM xxdo.xxdoascp_item_attr_upd_stg2
               WHERE status = 0
            ORDER BY inv_org_code;

        CURSOR template_cur IS
            SELECT DISTINCT ITEM_TEMPLATE
              FROM xxdo.xxdoascp_item_attr_upd_stg2
             WHERE ITEM_TEMPLATE IS NOT NULL;

        CURSOR buyer_cur IS
            SELECT DISTINCT DEFAULT_BUYER
              FROM xxdo.xxdoascp_item_attr_upd_stg2
             WHERE DEFAULT_BUYER IS NOT NULL;


        TYPE t_itemattr_cur IS TABLE OF itemattr_cur%ROWTYPE
            INDEX BY BINARY_INTEGER;

        r_itemattr_cur          t_itemattr_cur;
        ----------------------------------------------------------------------------------------------------
        --local variables declaration
        ----------------------------------------------------------------------------------------------------
        lv_dimension_uom_code   VARCHAR2 (100);
        lv_weight_uom_code      VARCHAR2 (100);
        ln_unit_length          NUMBER;
        ln_unit_weight          NUMBER;
        ln_unit_width           NUMBER;
        ln_unit_height          NUMBER;
        lv_error_msg            VARCHAR2 (2000);
        ln_template_id          NUMBER;
        ln_buyer_id             NUMBER;
        l_preprocessing_lead    mtl_system_items_interface.preprocessing_lead_time%TYPE;
        --l_full_lead             mtl_system_items_interface.full_lead_time%TYPE;
        l_postprocessing_lead   mtl_system_items_interface.postprocessing_lead_time%TYPE;
        p_sql                   VARCHAR2 (500);
        ln_cum_ld_time          NUMBER;
        ln_lead_time            NUMBER;
        lv_sample               mtl_system_items_b.attribute28%TYPE;
        l_error_msg             VARCHAR2 (100);
        ln_set_process_id       NUMBER;
        lv_sqlerrm              VARCHAR2 (1000);
        v_preprocessing_lead    mtl_system_items_interface.preprocessing_lead_time%TYPE;
        v_postprocessing_lead   mtl_system_items_interface.preprocessing_lead_time%TYPE;
    ------------------------------------------------------------------------------------
    --Begin of staging table update procedure execution section
    ------------------------------------------------------------------------------------
    BEGIN
        l_error_msg   := 'Value sent in the File is not Valid';

        ---------------------------------------------------------
        --Checking for the Organization ID and Inventory Item ID
        ---------------------------------------------------------
        BEGIN
            UPDATE xxdo.xxdoascp_item_attr_upd_stg2
               SET STATUS = 1, ERROR_MESSAGE = l_error_msg
             WHERE (organization_id IS NULL OR inventory_item_id IS NULL);

            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                SQL%ROWCOUNT || 'Invalid records upadted with status 1');
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Inside validation of Organization ID and Inv Item   '
                    || SUBSTR (SQLERRM, 1, 250));
        END;

        COMMIT;

        --------------------------------------------------------------------------
        ---Checking for the duplicate records for Items coming from the data file
        --------------------------------------------------------------------------
        BEGIN
            UPDATE xxdo.xxdoascp_item_attr_upd_stg2 A
               SET status = 1, ERROR_MESSAGE = 'Duplicate Records'
             WHERE     ROWID <>
                       (SELECT MAX (ROWID)
                          FROM xxdo.xxdoascp_item_attr_upd_stg2
                         WHERE     item_number = A.item_number
                               AND inv_org_code = A.inv_org_code
                               AND status = A.status
                               AND request_id = A.request_id)
                   AND status = 0;

            COMMIT;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                SQL%ROWCOUNT || 'Duplicate records upadted with status 1');
        END;

        ----------------------------------------------------------------------------------------
        -- Checking for records without item template from data file
        ----------------------------------------------------------------------------------------
        BEGIN
            UPDATE xxdo.xxdoascp_item_attr_upd_stg2
               SET status = 1, ERROR_MESSAGE = 'Item Template not provided, Invalid Record '
             WHERE item_template IS NULL AND status = 0;

            COMMIT;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' Records with missing item template upadted with status 1 ');
        END;

        --------------------------------------------------------------------------------------------
        -- Loop for updating template ID
        --------------------------------------------------------------------------------------------

        FOR template_rec IN template_cur
        LOOP
            ln_template_id   := NULL;

            BEGIN
                SELECT template_id
                  INTO ln_template_id
                  FROM apps.mtl_item_templates mit
                 WHERE UPPER (TRIM (template_name)) =
                       UPPER (TRIM (template_rec.item_template));

                UPDATE xxdo.xxdoascp_item_attr_upd_stg2
                   SET template_id   = ln_template_id
                 WHERE UPPER (TRIM (item_template)) =
                       UPPER (TRIM (template_rec.item_template));
            EXCEPTION
                WHEN OTHERS
                THEN
                    UPDATE xxdo.xxdoascp_item_attr_upd_stg2
                       SET status = 1, ERROR_MESSAGE = 'Item Template is not valid '
                     WHERE     UPPER (TRIM (item_template)) =
                               UPPER (TRIM (template_rec.item_template))
                           AND status = 0;
            END;

            COMMIT;
        END LOOP;

        --------------------------------------------------------------------------------------------
        -- Loop for updating Buyer ID
        --------------------------------------------------------------------------------------------
        FOR buyer_rec IN buyer_cur
        LOOP
            ln_buyer_id   := NULL;

            BEGIN
                SELECT pa.agent_id
                  INTO ln_buyer_id
                  FROM PO_AGENTS PA, PER_ALL_PEOPLE_F PAPF
                 WHERE     PA.AGENT_ID = PAPF.PERSON_ID
                       AND TRUNC (SYSDATE) BETWEEN PAPF.EFFECTIVE_START_DATE
                                               AND PAPF.EFFECTIVE_END_DATE
                       AND UPPER (TRIM (papf.full_name)) =
                           UPPER (buyer_rec.DEFAULT_BUYER);

                UPDATE xxdo.xxdoascp_item_attr_upd_stg2
                   SET buyer_id   = ln_buyer_id
                 WHERE DEFAULT_BUYER = buyer_rec.DEFAULT_BUYER;
            EXCEPTION
                WHEN OTHERS
                THEN
                    UPDATE xxdo.xxdoascp_item_attr_upd_stg2
                       SET status = 1, ERROR_MESSAGE = 'Invalid Buyer '
                     WHERE     DEFAULT_BUYER = buyer_rec.DEFAULT_BUYER
                           AND status = 0;
            END;
        END LOOP;

        COMMIT;



        BEGIN
            OPEN itemattr_cur;

            LOOP
                r_itemattr_cur.DELETE;

                FETCH itemattr_cur
                    BULK COLLECT INTO r_itemattr_cur
                    LIMIT 5000;

                EXIT WHEN r_itemattr_cur.COUNT = 0;

                SELECT apps.mtl_system_items_intf_sets_s.NEXTVAL
                  INTO ln_set_process_id
                  FROM DUAL;

                FOR i IN 1 .. r_itemattr_cur.COUNT
                LOOP
                    lv_dimension_uom_code   := NULL;
                    ln_unit_length          := NULL;
                    ln_unit_width           := NULL;
                    ln_unit_height          := NULL;
                    lv_weight_uom_code      := NULL;
                    ln_cum_ld_time          := NULL;
                    l_preprocessing_lead    := NULL;
                    l_postprocessing_lead   := NULL;
                    ln_cum_ld_time          := NULL;
                    v_preprocessing_lead    := NULL;
                    v_postprocessing_lead   := NULL;
                    --Start Changes by BT Technology Team on 14 Apr 2016
                    ln_lead_time            := NULL;

                    --End Changes by BT Technology Team on 14 Apr 2016

                    BEGIN
                        SELECT dimension_uom_code, unit_length, weight_uom_code,
                               unit_weight, unit_width, unit_height,
                               preprocessing_lead_time, postprocessing_lead_time, attribute28
                          INTO lv_dimension_uom_code, ln_unit_length, lv_weight_uom_code, ln_unit_weight,
                                                    ln_unit_width, ln_unit_height, l_preprocessing_lead,
                                                    l_postprocessing_lead, lv_sample
                          FROM apps.mtl_system_items_b
                         WHERE     inventory_item_id =
                                   r_itemattr_cur (i).inventory_item_id
                               AND organization_id =
                                   r_itemattr_cur (i).organization_id;

                        IF     NVL (lv_dimension_uom_code, '-') = '-'
                           AND (ln_unit_length IS NOT NULL OR ln_unit_width IS NOT NULL OR ln_unit_height IS NOT NULL)
                        THEN
                            lv_dimension_uom_code   := 'IN';
                        END IF;

                        IF     NVL (lv_weight_uom_code, '-') = '-'
                           AND ln_unit_weight IS NOT NULL
                        THEN
                            lv_weight_uom_code   := 'Lbs';
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                'Exception occured in the retreiving the Values of Dimensions');
                    END;

                    --------------------------------------------------------------------------
                    ---Total Lead Time Calculation using Function lead_time_cal();
                    --------------------------------------------------------------------------
                    IF r_itemattr_cur (i).inv_org_code = 'MST'
                    THEN
                        fnd_file.put_line (FND_FILE.LOG, 'Test11 : ');
                        ln_lead_time   :=
                            NVL (r_itemattr_cur (i).processing_lead_time, 0);
                    ELSE
                        IF NVL (r_itemattr_cur (i).processing_lead_time, 0) !=
                           0
                        THEN
                            fnd_file.put_line (FND_FILE.LOG, 'Test12 : ');
                            ln_lead_time   :=
                                lead_time_cal (--r_itemattr_cur (i).sno,
                                               r_itemattr_cur (i).organization_id, r_itemattr_cur (i).inventory_item_id, r_itemattr_cur (i).processing_lead_time
                                               , lv_sample);
                        END IF;
                    END IF;

                    fnd_file.put_line (
                        FND_FILE.LOG,
                           'Lead Time for  : '
                        || r_itemattr_cur (i).inventory_item_id
                        || ' is '
                        || r_itemattr_cur (i).processing_lead_time);

                    fnd_file.put_line (
                        FND_FILE.LOG,
                           'Ln Lead Time for  : '
                        || r_itemattr_cur (i).inventory_item_id
                        || ' is '
                        || ln_lead_time);

                    --Added As per the  CR#154

                    v_preprocessing_lead    :=
                        CEIL (
                              NVL (
                                  r_itemattr_cur (i).pre_processing_lead_time,
                                  l_preprocessing_lead)
                            * 5
                            / 7);
                    v_postprocessing_lead   :=
                        CEIL (
                              NVL (
                                  r_itemattr_cur (i).post_processing_lead_time,
                                  l_postprocessing_lead)
                            * 5
                            / 7);

                    BEGIN
                        SELECT TO_NUMBER (description)
                          INTO lc_add_cum_lead_time
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'DO_ADD_CUMM_LEAD_TIME' --Lookup created for adding cumulative lead time.
                               AND meaning = r_itemattr_cur (i).inv_org_code
                               AND language = 'US';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lc_add_cum_lead_time   := 0;
                    END;


                    ln_cum_ld_time          :=
                        ln_lead_time -- + NVL (r_itemattr_cur (i).pre_processing_lead_time, Changed for CR117 As per inputs from functional to remove pre preocessing lead time Sep/2/2015
                                                --       l_preprocessing_lead)
                                                    -- Commented as per CR#154
                       -- + NVL (r_itemattr_cur (i).post_processing_lead_time,
                 --       l_postprocessing_lead) --Commented as per the CR#154
                         + v_postprocessing_lead + lc_add_cum_lead_time; -- added +5 As per the  CR#154 inputs from functional to calc cumulative  lead time 20/OCT/2015(The new logic is:  Cumulative lead time  = Processing Lead Time + Post-Processing Lead Time + 5 )

                    ---End CR#154

                    BEGIN
                        UPDATE xxdo.xxdoascp_item_attr_upd_stg2 xiau_uc
                           SET xiau_uc.dimension_uom_code = lv_dimension_uom_code, xiau_uc.weight_uom_code = lv_weight_uom_code, xiau_uc.set_process_id = ln_set_process_id,
                               xiau_uc.buyer_id = ln_buyer_id, --xiau_uc.template_id = ln_template_id,  --commented for PRB0040989
                                                               xiau_uc.pre_processing_lead_time = v_preprocessing_lead, --CR#154
                                                                                                                        xiau_uc.post_processing_lead_time = v_postprocessing_lead, --CR#154
                               xiau_uc.processing_lead_time = ln_lead_time, xiau_uc.cumulative_total_lead_time = ln_cum_ld_time, xiau_uc.status = 2
                         WHERE     xiau_uc.sno = r_itemattr_cur (i).sno
                               AND xiau_uc.inventory_item_id =
                                   r_itemattr_cur (i).inventory_item_id
                               --Start modification on 29-APR-2016
                               AND xiau_uc.error_message IS NULL    --Srinivas
                               --End modification on 29-APR-2016
                               AND xiau_uc.organization_id =
                                   r_itemattr_cur (i).organization_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            UPDATE xxdo.xxdoascp_item_attr_upd_stg2 xiau_uc1
                               SET xiau_uc1.status = 50, xiau_uc1.error_message = r_itemattr_cur (i).item_number || ' is not updated in Stg2 '
                             WHERE     xiau_uc1.sno = r_itemattr_cur (i).sno
                                   AND xiau_uc1.inventory_item_id =
                                       r_itemattr_cur (i).inventory_item_id
                                   AND xiau_uc1.organization_id =
                                       r_itemattr_cur (i).organization_id;
                    END;
                END LOOP;                              --Itemattr_cur Loop End

                COMMIT;
            END LOOP;

            r_itemattr_cur.DELETE;

            COMMIT;

            CLOSE itemattr_cur;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuff   := 'Others Exception in stg_tbl_upd_proc';
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'OTHERS EXCEPTION in stg_tbl_upd_proc'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END stg_tbl_upd_proc; ---End of the stg_tbl_upd_proc  -- END Added By BT Technology Team

    -- ******************************************************************
    --Procedure to extract category records from Stg2 to category table
    --
    --
    --*****************************************************************
    PROCEDURE extract_cat_to_stg (x_errbuf OUT NOCOPY VARCHAR2, -- Start Added By BT Technology Team
                                                                x_retcode OUT NOCOPY NUMBER, p_request_id IN NUMBER)
    AS
        CURSOR c_cat_main IS
            SELECT inv_org_code, organization_id, inventory_item_id,
                   category_structure, category_code, item_number,
                   supplier, supplier_site, product_line,
                   request_id
              FROM xxdo.xxdoascp_item_attr_upd_stg2
             WHERE     supplier IS NOT NULL
                   AND request_id = p_request_id
                   AND status_category = 0;


        TYPE c_main_type IS TABLE OF c_cat_main%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_main_tab      c_main_type;

        ld_date          DATE;
        ln_total_count   NUMBER;
        ln_count         NUMBER;
    BEGIN
        BEGIN
            DELETE xxdo.XXD_INV_ITEM_CAT_STG_T
             WHERE category_set_name = 'PRODUCTION_LINE';

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Exception While deleting  Category Record from Category Staging Table');
        END;

        SELECT SYSDATE INTO ld_date FROM SYS.DUAL;

        apps.fnd_file.put_line (apps.fnd_file.LOG, 'Procedure extract_main');

        OPEN c_cat_main;

        LOOP
            FETCH c_cat_main BULK COLLECT INTO lt_main_tab LIMIT 20000;

            IF lt_main_tab.COUNT = 0
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'No Valid records are present in the Item Staging  table  and SQLERRM'
                    || SQLERRM);
            ELSE
                FORALL i IN 1 .. lt_main_tab.COUNT
                    --Inserting to Staging Table XXD_INV_ITEM_CAT_STG_T
                    INSERT INTO xxdo.xxd_inv_item_cat_stg_t (record_id, batch_number, record_status, item_number, organization_id, category_set_name, segment1, segment2, segment3, --segment4,
                                                                                                                                                                                    inventory_item_id, created_by, creation_date, last_updated_by, last_update_date, error_message
                                                             , GROUP_ID)
                         VALUES (xxdo.xxd_inv_item_cat_stg_t_s.NEXTVAL, NULL, 'N', lt_main_tab (i).item_number, lt_main_tab (i).organization_id, 'PRODUCTION_LINE', lt_main_tab (i).supplier, lt_main_tab (i).supplier_site, TRIM (REPLACE (REPLACE (lt_main_tab (i).product_line, CHR (13), ''), CHR (10), '')), --lt_main_tab (i).SEGMENT4,
                                                                                                                                                                                                                                                                                                                  lt_main_tab (i).inventory_item_id, fnd_global.user_id, ld_date, fnd_global.login_id, ld_date, NULL
                                 , lt_main_tab (i).request_id);


                ln_total_count   := ln_total_count + ln_count;
                ln_count         := ln_count + 1;

                IF ln_total_count = 20000
                THEN
                    ln_total_count   := 0;
                    ln_count         := 0;
                    COMMIT;
                END IF;
            END IF;

            EXIT WHEN lt_main_tab.COUNT < 20000;
        END LOOP;

        CLOSE c_cat_main;

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'End Time:' || TO_CHAR (SYSDATE, 'hh:mi:ss'));

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
           SET status_category   = 3
         WHERE     supplier IS NOT NULL
               AND request_id = p_request_id
               AND status_category = 0;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in extract_cat_to_stg - '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
            x_retcode   := 2;
            x_errbuf    := 'Others Exception in extract_cat_to_stg ';
    END extract_cat_to_stg;                 -- End Added By BT Technology Team


    /* *********************************************************************/
    PROCEDURE submit_item_import (pv_orgid IN VARCHAR2, pv_allorgsflag IN VARCHAR2, pv_validateitemsflag IN VARCHAR2, pv_processitemsflag IN VARCHAR2, pv_deleteprocessedflag IN VARCHAR2, pv_setprocessid IN VARCHAR2, pv_createupdateflag IN VARCHAR2, pn_req_id OUT NUMBER, pv_retcode OUT VARCHAR2
                                  , pv_reterror OUT VARCHAR2)
    /* *************************************************************************************/
    IS
        lv_phasecode         VARCHAR2 (100) := NULL;
        lv_statuscode        VARCHAR2 (100) := NULL;
        lv_devphase          VARCHAR2 (100) := NULL;
        lv_devstatus         VARCHAR2 (100) := NULL;
        lv_returnmsg         VARCHAR2 (2000) := NULL;
        lb_concreqcallstat   BOOLEAN := FALSE;
        ln_resp_id           NUMBER;
        ln_appln_id          NUMBER;
        ln_userid            NUMBER;
        ln_requestid         NUMBER;
        econcreqsuberr       EXCEPTION;
    BEGIN
        ln_requestid   :=
            apps.fnd_request.submit_request (application => 'INV', program => 'INCOIN', description => NULL, start_time => SYSDATE, sub_request => FALSE, argument1 => pv_orgid, argument2 => pv_allorgsflag -- '2'
                                                                                                                                                                                                            , argument3 => pv_validateitemsflag -- '1'
                                                                                                                                                                                                                                               , argument4 => pv_processitemsflag, -- '1'
                                                                                                                                                                                                                                                                                   argument5 => pv_deleteprocessedflag, argument6 => pv_setprocessid, argument7 => pv_createupdateflag
                                             , -- '1' CREATE
                                               argument8 => 1 -- Gather Statistics
                                                             );
        COMMIT;

        IF ln_requestid = 0
        THEN
            RAISE econcreqsuberr;
        ELSE
            pn_req_id   := ln_requestid;
        /*LOOP
           lb_concreqcallstat :=
              apps.fnd_concurrent.wait_for_request (ln_requestid,
                                                    5, -- wait 5 seconds between db checks
                                                    0,
                                                    lv_phasecode,
                                                    lv_statuscode,
                                                    lv_devphase,
                                                    lv_devstatus,
                                                    lv_returnmsg);
           EXIT WHEN lv_devphase = 'COMPLETE';
        END LOOP;*/
        END IF;
    EXCEPTION
        WHEN econcreqsuberr
        THEN
            pv_retcode   := 1;                                    --'Warning';
            pv_reterror   :=
                   'Error in conc.req submission at '
                || SUBSTR (SQLERRM, 1, 1999);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'After Calling item import econcreqsuberr'
                || pv_reterror
                || pv_orgid);
        WHEN OTHERS
        THEN
            pv_retcode   := 2;                                      --SQLCODE;
            pv_reterror   :=
                   'Error in conc.req submission at '
                || SUBSTR (SQLERRM, 1, 1999);
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'After Calling item import when others' || pv_reterror);
    END submit_item_import;

    /* PROCEDURE item_attr_update_proc (                              -- Start Commented By BT Technology Team
        pv_errbuf    OUT   VARCHAR2,
        pv_retcode   OUT   VARCHAR2
     )
     IS
        CURSOR itemattr_cur (pn_conc_req_id NUMBER)
        IS
           SELECT *
             FROM xxdo.xxdoascp_item_attr_upd_stg
            WHERE NVL (status, 0) = 2 AND request_id = pn_conc_req_id;

        --Cursor to Fetch only the Master Records
        CURSOR itemimp_mas_cur (pn_conc_req_id NUMBER)
        IS
           SELECT   COUNT (*), stg.set_process_id,
                    mp.master_organization_id master_organization_id,
                    mp_master.organization_code organization_code
               FROM xxdo.xxdoascp_item_attr_upd_stg stg,
                    apps.mtl_parameters mp,
                    apps.mtl_parameters mp_master
              WHERE stg.organization_id = mp.organization_id
                AND mp.master_organization_id = mp_master.organization_id
                AND NVL (status, 0) = 3
                AND stg.request_id = pn_conc_req_id
                AND stg.organization_id =
                       mp_master.organization_id
                  -- logic added By BT Technolgy to count only master level item
           GROUP BY stg.set_process_id,
                    mp.master_organization_id,
                    mp_master.organization_code
           ORDER BY stg.set_process_id, mp.master_organization_id;

        --Cursor to Fetch all the Child Records
        CURSOR itemimp_child_cur (pn_conc_req_id NUMBER)
        IS
           SELECT   COUNT (*), stg.set_process_id, stg.organization_id,
                    mp.master_organization_id, mp.organization_code
               FROM xxdo.xxdoascp_item_attr_upd_stg stg, apps.mtl_parameters mp
              WHERE stg.organization_id = mp.organization_id
                AND NVL (status, 0) = 3
                AND stg.request_id = pn_conc_req_id
                AND stg.organization_id NOT IN (
                                 SELECT master_organization_id
                                   FROM apps.mtl_parameters mp1
                                  WHERE mp1.organization_id =
                                                             stg.organization_id)
           GROUP BY stg.set_process_id,
                    stg.organization_id,
                    mp.master_organization_id,
                    mp.organization_code
           ORDER BY stg.set_process_id,
                    stg.organization_id,
                    mp.master_organization_id;

        ln_organization_id            NUMBER (20)                        := NULL;
        lv_organization               VARCHAR2 (40)                      := NULL;
        lv_org_code                   VARCHAR2 (100)                     := NULL;
        lv_retcode                    VARCHAR2 (2000);
        lv_reterror                   VARCHAR2 (2000);
        lv_dimension_uom_code         VARCHAR2 (100);
        lv_weight_uom_code            VARCHAR2 (100);
        ln_unit_length                NUMBER;
        ln_unit_weight                NUMBER;
        ln_unit_width                 NUMBER;
        ln_unit_height                NUMBER;
        ln_req_id                     NUMBER;
        ln_current_loop_count         NUMBER                                := 0;
        ln_max_item_per_program       NUMBER                             := 5000;
        ln_set_process_id             NUMBER;
        ln_loop_count                 NUMBER                                := 1;
        ln_item_count                 NUMBER;
        lv_sqlerrm                    VARCHAR2 (1000);
        ln_conc_req_id                NUMBER                                := 0;
        lv_child_req_id               VARCHAR2 (240);
        ln_parent_conc_req_id         NUMBER                                := 0;
        ln_master_count               NUMBER                                := 0;
        ln_master_stg_count           NUMBER                                := 0;
        lv_insert_stmt                VARCHAR2 (22000);
        ln_bom_item_type              NUMBER;
        ln_processing_lead_time       NUMBER;
        ln_preprocessing_lead_time    NUMBER;
        ln_postprocessing_lead_time   NUMBER;
        ln_days                       NUMBER                                := 0;
  --      ln_creation_date              DATE;
        l_item_temp                   apps.mtl_system_items_interface.template_id%TYPE;
        l_buyer_i                     mtl_system_items_interface.buyer_id%TYPE;
        l_planner_c                   mtl_system_items_interface.planner_code%TYPE;
        l_list_price_per_u            mtl_system_items_interface.list_price_per_unit%TYPE;
        l_minimum_order_q             mtl_system_items_interface.minimum_order_quantity%TYPE;
        l_fixed_order_q               mtl_system_items_interface.fixed_order_quantity%TYPE;
        l_planning_make_b             mtl_system_items_interface.planning_make_buy_code%TYPE;
        l_mrp_planning_c              mtl_system_items_interface.mrp_planning_code%TYPE;
        l_ato_forecast_c              mtl_system_items_interface.ato_forecast_control%TYPE;
        l_end_assembly_pegging_f      mtl_system_items_interface.end_assembly_pegging_flag%TYPE;
        l_planning_time_fence_c       mtl_system_items_interface.planning_time_fence_code%TYPE;
        l_planning_time_fence_d       mtl_system_items_interface.planning_time_fence_days%TYPE;
        l_demand_time_fence_c         mtl_system_items_interface.demand_time_fence_code%TYPE;
        l_demand_time_fence_d         mtl_system_items_interface.demand_time_fence_days%TYPE;
        l_preprocessing_lead          mtl_system_items_interface.preprocessing_lead_time%TYPE;
        l_full_lead                   mtl_system_items_interface.full_lead_time%TYPE;
        l_postprocessing_lead         mtl_system_items_interface.postprocessing_lead_time%TYPE;
        l_atp_fl                      mtl_system_items_interface.atp_flag%TYPE;
        l_atp_components_flag         mtl_system_items_interface.atp_components_flag%TYPE;
        l_atp_rule_id                 mtl_system_items_interface.atp_rule_id%TYPE;
        l_fixed_days                  mtl_system_items_interface.fixed_days_supply%TYPE;
        l_fixed_lot                   mtl_system_items_interface.fixed_lot_multiplier%TYPE;
        l_rounding_control            mtl_system_items_interface.rounding_control_type%TYPE;
        l_create_supply               mtl_system_items_interface.create_supply_flag%TYPE;
        l_maximum_order               mtl_system_items_interface.maximum_order_quantity%TYPE;
        l_mrp_safety_sto              mtl_system_items_interface.mrp_safety_stock_code%TYPE;
        l_safety_stock_buc            mtl_system_items_interface.safety_stock_bucket_days%TYPE;
        l_mrp_safety_sto_per          mtl_system_items_interface.mrp_safety_stock_percent%TYPE;
     BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Printing Request_id' || gn_conc_req_id
                               );
        BEGIN
           DELETE FROM xxdo.xxdoascp_item_attr_upd_stg
                 WHERE TRUNC (creation_date) <=
                          TRUNC
                             (ADD_MONTHS
                                 (SYSDATE,
                                    -1
                                  * NVL
                                       (apps.fnd_profile.VALUE
                                            ('XXDO_ASCP_STG_DATA_RETENTION_DAYS'),
                                        30
                                       )
                                 )
                             );
        EXCEPTION
           WHEN OTHERS
           THEN
              apps.fnd_file.put_line
                        (apps.fnd_file.LOG,
                         'Exception Occured while deleting data from stg table'
                        );
              RAISE;
        END;

        COMMIT;
        ln_parent_conc_req_id := gn_conc_req_id;

        BEGIN
           UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau
              SET xiau.created_by = gn_created_by,
                  xiau.creation_date = gd_creation_date,
                  xiau.last_updated_by = gn_updated_by,
                  xiau.last_update_date = gd_update_date,
                  xiau.request_id = gn_conc_req_id,
                  xiau.status = 0
            WHERE 1 = 1
                       --xiau.request_id = xiau.request_id
                  AND xiau.status = 99;

           COMMIT;
        EXCEPTION
           WHEN OTHERS
           THEN
              apps.fnd_file.put_line
                 (apps.fnd_file.LOG,
                     'Exception Occured while updating the Intial Who Columns : '
                  || SQLERRM
                 );
              ROLLBACK;
              pv_retcode := 2;              --To complete the program with Error
              RAISE;
        END;

        lv_retcode := NULL;
        lv_reterror := NULL;
        --Getting the necessary Id's and validating the flat file data
        stg_tbl_upd_proc (lv_reterror, lv_retcode, ln_parent_conc_req_id);

  --set process id
        BEGIN
           SELECT COUNT (*)
             INTO ln_item_count
             FROM xxdo.xxdoascp_item_attr_upd_stg xiau
            WHERE NVL (xiau.status, 0) = 2
                  AND request_id = ln_parent_conc_req_id;

           apps.fnd_file.put_line
                                (apps.fnd_file.LOG,
                                    'Printing Total Records in staging table : '
                                 || ln_item_count
                                );
        END;

        ln_loop_count := CEIL (ln_item_count / ln_max_item_per_program);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Loop Count  = ' || ln_loop_count
                               );

        LOOP
           EXIT WHEN ln_current_loop_count > ln_loop_count;
           ln_set_process_id := NULL;

           SELECT apps.mtl_system_items_intf_sets_s.NEXTVAL
             INTO ln_set_process_id
             FROM DUAL;

           apps.fnd_file.put_line (apps.fnd_file.LOG,
                                   'Process Id : ' || ln_set_process_id
                                  );

           --Setting the set_process_id
           BEGIN
              UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau
                 SET set_process_id = ln_set_process_id
               WHERE ROWNUM <= ln_max_item_per_program
                 AND xiau.status = 2
                 AND xiau.set_process_id IS NULL
                 AND request_id = ln_parent_conc_req_id;

              COMMIT;
           EXCEPTION
              WHEN OTHERS
              THEN
                 pv_retcode := 2;
                 pv_errbuf :=
                       'Error while Updating Staging Table with set process ID :'
                    || SUBSTR (SQLERRM, 1, 2000);
                 apps.fnd_file.put_line
                    (apps.fnd_file.LOG,
                        'Error while Updating Staging Table with set process ID -'
                     || ln_set_process_id
                    );
                 ROLLBACK;

                 UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau
                    SET status = 50,
                        error_message = pv_errbuf
                  WHERE request_id = ln_parent_conc_req_id;

                 COMMIT;
                 RAISE;
           END;

           ln_current_loop_count := ln_current_loop_count + 1;
        END LOOP;

        --COMMIT;
        BEGIN
           FOR i IN itemattr_cur (ln_parent_conc_req_id)
           LOOP
              ln_organization_id := NULL;
              lv_org_code := NULL;
              ln_master_count := 0;
              lv_dimension_uom_code := NULL;
              ln_unit_length := NULL;
              ln_unit_width := NULL;
              ln_unit_height := NULL;
              lv_weight_uom_code := NULL;
              ln_bom_item_type := NULL;

              BEGIN
                 SELECT DISTINCT mp.master_organization_id,
                                 ood.organization_code
                            INTO ln_organization_id,
                                 lv_org_code
                            FROM apps.mtl_parameters mp,
                                 apps.org_organization_definitions ood
                           WHERE mp.master_organization_id = ood.organization_id
                             AND mp.organization_id = i.organization_id;

                 apps.fnd_file.put_line (apps.fnd_file.LOG,
                                            'Master Orgganization code '
                                         || lv_org_code
                                        );
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    apps.fnd_file.put_line
                       (apps.fnd_file.LOG,
                        'No master Organization Found for the given organization'
                       );
                    pv_retcode := 2;
                    pv_errbuf :=
                          'Error getting Master Organization for the given organization : '
                       || SUBSTR (SQLERRM, 1, 1999);
                    RAISE;
              END;

              IF (ln_organization_id = i.organization_id)
              THEN
                 lv_organization := 'MASTER';
              ELSE
                 lv_organization := 'CHILD';
              END IF;

              IF lv_organization = 'MASTER'
              THEN
                 BEGIN
                    SELECT dimension_uom_code, unit_length,
                           weight_uom_code, unit_weight, unit_width,
                           unit_height, bom_item_type
                      INTO lv_dimension_uom_code, ln_unit_length,
                           lv_weight_uom_code, ln_unit_weight, ln_unit_width,
                           ln_unit_height, ln_bom_item_type
                      FROM apps.mtl_system_items
                     WHERE inventory_item_id = i.inventory_item_id
                       AND organization_id = ln_organization_id;

                    IF     NVL (lv_dimension_uom_code, '-') = '-'
                       AND (   ln_unit_length IS NOT NULL
                            OR ln_unit_width IS NOT NULL
                            OR ln_unit_height IS NOT NULL
                           )
                    THEN
                       lv_dimension_uom_code := 'IN';
                    END IF;

                    IF     NVL (lv_weight_uom_code, '-') = '-'
                       AND ln_unit_weight IS NOT NULL
                    THEN
                       lv_weight_uom_code := 'Lbs';
                    END IF;
                 --  IF ln_bom_item_type = 5                                     --commented by bt technology team for remove product family
                 --  THEN                                                        --commented by bt technology team for remove product family
                 --     ln_processing_lead_time := -999999;                      --commented by bt technology team for remove product family
                 --     ln_preprocessing_lead_time := -999999;                   --commented by bt technology team for remove product family
                 --     ln_postprocessing_lead_time := -999999;                  --commented by bt technology team for remove product family
                 --  ELSE                                                        --commented by bt technology team for remove product family
                 --     ln_processing_lead_time := i.processing_lead_time;       --commented by bt technology team for remove product family
                 --     ln_preprocessing_lead_time := i.pre_processing_lead_time;--commented by bt technology team for remove product family
                 --     ln_postprocessing_lead_time :=                           --commented by bt technology team for remove product family
                 --                                  i.post_processing_lead_time;--commented by bt technology team for remove product family
                 -- END IF;                                                      --commented by bt technology team for remove product family
                 EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                       apps.fnd_file.put_line
                          (apps.fnd_file.LOG,
                           'Exception occured in the retreiving thr Values of Dimensions'
                          );
                 END;

                 BEGIN
                    apps.fnd_file.put_line
                              (apps.fnd_file.LOG,
                                  'inserting in interface  For Master Level : '
                               || 'Item Number'
                               || i.item_number
                               || ' Organization id  '
                               || i.organization_id
                               || ' Inventory item Id '
                               || i.inventory_item_id
                               || ' '
                              );
                    lv_insert_stmt :=
                       SUBSTR
                          (   'INSERT INTO apps.mtl_system_items_interface
                                      (ORGANIZATION_CODE,
                                      ORGANIZATION_ID,
                                      ITEM_NUMBER,
                                      INVENTORY_ITEM_ID,
                                      PROCESS_FLAG,
                                      TRANSACTION_TYPE,
                                      SET_PROCESS_ID,
                                      BUYER_ID,      --added bt bt Technology
                                      LIST_PRICE_PER_UNIT,  --added by bt technology team
                                      PLANNER_CODE,
                                      PLANNING_MAKE_BUY_CODE,
                                      MINIMUM_ORDER_QUANTITY,
                                      MAXIMUM_ORDER_QUANTITY,                  --add by bt technology team
                                      ROUNDING_CONTROL_TYPE,                   --add by bt technology team
                                      CREATE_SUPPLY_FLAG,                      --add by bt technology team
                                      INVENTORY_PLANNING_CODE,                  --add by bt technology team
                                      MRP_SAFETY_STOCK_CODE,                   --add by bt technology team
                                      SAFETY_STOCK_BUCKET_DAYS,                --add by bt technology team
                                      MRP_SAFETY_STOCK_PERCENT,                --add by bt technology team
                                      TEMPLATE_ID,                             --add by bt technology team

                                      FIXED_ORDER_QUANTITY,
                                      FIXED_DAYS_SUPPLY,  --added by bt technology team
                                      FIXED_LOT_MULTIPLIER, --added by bt technology team
                                      MRP_PLANNING_CODE,
                                      ATO_FORECAST_CONTROL,
                                      END_ASSEMBLY_PEGGING_FLAG,
                                      PLANNING_TIME_FENCE_CODE,
                                      PLANNING_TIME_FENCE_DAYS,
                                      DEMAND_TIME_FENCE_CODE,
                                      DEMAND_TIME_FENCE_DAYS,
                                      ATP_FLAG,
                                      ATP_COMPONENTS_FLAG,
                                      FULL_LEAD_TIME,
                                      PREPROCESSING_LEAD_TIME,
                                      POSTPROCESSING_LEAD_TIME,
                                      ATP_RULE_ID,
                                      DIMENSION_UOM_CODE,
                                      WEIGHT_UOM_CODE,
                                      CREATED_BY,
                                      CREATION_DATE,
                                      LAST_UPDATED_BY,
                                      LAST_UPDATE_DATE)
                                      VALUES '
                           || '('''
                           || i.inv_org_code
                           || ''','
                           || ''''
                           || i.organization_id
                           || ''','
                           || ''''
                           || i.item_number
                           || ''','
                           || ''''
                           || i.inventory_item_id
                           || ''','
                           || ''''
                           || 1
                           || ''','
                           || '''UPDATE'''
                           || ','
                           || ''''
                           || i.set_process_id
                           || ''','
                           || ''''
                           || i.buyer_id
                           || ''','
                           || ''''
                           || i.list_price
                           || ''','
                           || ''''
                           || i.planner_code
                           || ''','
                           || ''''
                           || identify_master_child_attr
                                                      ('PLANNING_MAKE_BUY_CODE',
                                                       'MASTER',
                                                       'STAGING',
                                                       i.sno,
                                                       i.request_id
                                                      )
                           || ''','
                           ||                        --i.planning_make_buy_code,
                              ''''
                           || identify_master_child_attr
                                                      ('MINIMUM_ORDER_QUANTITY',
                                                       'MASTER',
                                                       'STAGING',
                                                       i.sno,
                                                       i.request_id
                                                      )
                           || ''','
                           ||                                 --i.min_order_qty,
                              ''''
                           --start changes by bt technology team
                           || identify_master_child_attr
                                                      ('MAXIMUN_ORDER_QUANTITY',
                                                       'MASTER',
                                                       'STAGING',
                                                       i.sno,
                                                       i.request_id
                                                      )
                           || ''','
                           ||                                 --i.max_order_qty,
                              ''''
                           || identify_master_child_attr

                                                       --add by bt technology team
                              (                         'ROUNDING_CONTROL_TYPE',
                                                        'MASTER',
                                                        'STAGING',
                                                        i.sno,
                                                        i.request_id
                                                       )
                           || ''','
                           ||                               --i.round_order_qty,
                              ''''
                           || identify_master_child_attr ('CREATE_SUPPLY_FLAG',
                                                          'MASTER',
                                                          'STAGING',
                                                          i.sno,
                                                          i.request_id
                                                         )
                           || ''','
                           ||                                 --i.create_supply,
                              ''''
                           || identify_master_child_attr
                                                     ('INVENTORY_PLANNING_CODE',
                                                      'MASTER',
                                                      'STAGING',
                                                      i.sno,
                                                      i.request_id
                                                     )
                           || ''','
                           ||                     --i.inventory_planning_method,
                              ''''
                           || identify_master_child_attr
                                                       ('MRP_SAFETY_STOCK_CODE',
                                                        'MASTER',
                                                        'STAGING',
                                                        i.sno,
                                                        i.request_id
                                                       )
                           || ''','
                           ||                           --i.safety_stock_method,
                              ''''
                           || identify_master_child_attr
                                                    ('SAFETY_STOCK_BUCKET_DAYS',
                                                     'MASTER',
                                                     'STAGING',
                                                     i.sno,
                                                     i.request_id
                                                    )
                           || ''','
                           ||                      --i.safety_stock_bucket_days,
                              ''''
                           || identify_master_child_attr
                                                    ('MRP_SAFETY_STOCK_PERCENT',
                                                     'MASTER',
                                                     'STAGING',
                                                     i.sno,
                                                     i.request_id
                                                    )
                           || ''','
                           ||                          --i.safety_stock_percent,
                              ''''
                           || i.template_id
                           || ''','
                           || ''''
                           --end changes by  bt technology team
                           || identify_master_child_attr
                                                        ('FIXED_ORDER_QUANTITY',
                                                         'MASTER',
                                                         'STAGING',
                                                         i.sno,
                                                         i.request_id
                                                        )
                           || ''','
                           ||                               --i.fixed_order_qty,
                              ''''
                           || identify_master_child_attr ('FIXED_DAYS_SUPPLY',
                                                          'MASTER',
                                                          'STAGING',
                                                          i.sno,
                                                          i.request_id
                                                         )
                           || ''','
                           ||                          --i.safety_stock_percent,
                              ''''
                           || identify_master_child_attr
                                                        ('FIXED_LOT_MULTIPLIER',
                                                         'MASTER',
                                                         'STAGING',
                                                         i.sno,
                                                         i.request_id
                                                        )
                           || ''','
                           ||                          --i.safety_stock_percent,
                              ''''
                           || identify_master_child_attr
                                                         --add by bt technology team
                              (                           'MRP_PLANNING_CODE',
                                                          'MASTER',
                                                          'STAGING',
                                                          i.sno,
                                                          i.request_id
                                                         )
                           || ''','
                           ||                             --i.mrp_planning_code,
                              ''''
                           || identify_master_child_attr

                                                        --add by bt technology team
                              (                          'ATO_FORECAST_CONTROL',
                                                         'MASTER',
                                                         'STAGING',
                                                         i.sno,
                                                         i.request_id
                                                        )
                           || ''','
                           ||                     --i.ato_forecast_control_flag,
                              ''''
                           || identify_master_child_attr

                                                   --add by bt technology team
                              (                     'END_ASSEMBLY_PEGGING_FLAG',
                                                    'MASTER',
                                                    'STAGING',
                                                    i.sno,
                                                    i.request_id
                                                   )
                           || ''','
                           ||                       --end_assembly_pegging_flag,
                              ''''
                           || identify_master_child_attr
                                                    ('PLANNING_TIME_FENCE_CODE',
                                                     'MASTER',
                                                     'STAGING',
                                                     i.sno,
                                                     i.request_id
                                                    )
                           || ''','
                           ||                      --i.planning_time_fence_code,
                              ''''
                           || identify_master_child_attr
                                                    ('PLANNING_TIME_FENCE_DAYS',
                                                     'MASTER',
                                                     'STAGING',
                                                     i.sno,
                                                     i.request_id
                                                    )
                           || ''','
                           ||                          --i.plan_time_fence_days,
                              ''''
                           || identify_master_child_attr
                                                      ('DEMAND_TIME_FENCE_CODE',
                                                       'MASTER',
                                                       'STAGING',
                                                       i.sno,
                                                       i.request_id
                                                      )
                           || ''','
                           ||                        --i.demand_time_fence_flag,
                              ''''
                           || identify_master_child_attr
                                                      ('DEMAND_TIME_FENCE_DAYS',
                                                       'MASTER',
                                                       'STAGING',
                                                       i.sno,
                                                       i.request_id
                                                      )
                           || ''','
                           ||                        --i.demand_time_fence_days,
                              ''''
                           || identify_master_child_attr ('ATP_FLAG',
                                                          'MASTER',
                                                          'STAGING',
                                                          i.sno,
                                                          i.request_id
                                                         )
                           || ''','
                           ||                        --i.demand_time_fence_days,
                              ''''
                           || identify_master_child_attr ('ATP_COMPONENTS_FLAG',
                                                          'MASTER',
                                                          'STAGING',
                                                          i.sno,
                                                          i.request_id
                                                         )
                           || ''','
                           ||                           --i.atp_components_flag,
                              ''''
                           || NVL
                                 (identify_master_child_attr ('FULL_LEAD_TIME',
                                                              'MASTER',
                                                              'STAGING',
                                                              i.sno,
                                                              i.request_id
                                                             ),
                                  -999999
                                 )
                           || ''','
                           ||                           --i.atp_components_flag,
                              ''''
                           || NVL
                                 (identify_master_child_attr
                                                     ('PREPROCESSING_LEAD_TIME',
                                                      'MASTER',
                                                      'STAGING',
                                                      i.sno,
                                                      i.request_id
                                                     ),
                                  -999999
                                 )
                           || ''','
                           ||                           --i.atp_components_flag,
                              ''''
                           || NVL
                                 (identify_master_child_attr
                                                    ('POSTPROCESSING_LEAD_TIME',
                                                     'MASTER',
                                                     'STAGING',
                                                     i.sno,
                                                     i.request_id
                                                    ),
                                  -999999
                                 )
                           || ''','
                           ||                           --i.atp_components_flag,
                              ''''
                           || identify_master_child_attr ('ATP_RULE_ID',
                                                          'MASTER',
                                                          'STAGING',
                                                          i.sno,
                                                          i.request_id
                                                         )
                           || ''','
                           ||                                   --i.atp_rule_id,
                              ''''
                           || lv_dimension_uom_code
                           || ''','
                           || ''''
                           || lv_weight_uom_code
                           || ''','
                           || ''''
                           || gn_created_by
                           || ''','
                           || ''''
                           || gd_creation_date
                           || ''','
                           || ''''
                           || gn_updated_by
                           || ''','
                           || ''''
                           || gd_update_date
                           || ''')',
                           1,
                           19999
                          );
                    apps.fnd_file.put_line
                                    (apps.fnd_file.LOG,
                                        'inserting  Records for master level : '
                                     || lv_insert_stmt
                                    );

                    BEGIN
                       EXECUTE IMMEDIATE lv_insert_stmt;
                    EXCEPTION
                       WHEN OTHERS
                       THEN
                          ROLLBACK;
                          pv_retcode := 2;
                          pv_errbuf :=
                                'Error while Inserting into  mtl_system_items_interface For Master Organization: '
                             || SUBSTR (SQLERRM, 1, 2000);
                          apps.fnd_file.put_line
                                 (apps.fnd_file.LOG,
                                     'Programe failed Inside execute immediate:'
                                  || pv_errbuf
                                 );

                          UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau
                             SET status = 50,
                                 error_message = pv_errbuf
                           WHERE request_id = ln_parent_conc_req_id;

                          COMMIT;
                          RAISE;
                    END;

                    /*INSERT INTO apps.mtl_system_items_interface
                                 (organization_code, organization_id,
                                  item_number, inventory_item_id, process_flag,
                                  transaction_type, set_process_id,
                                  template_name, buyer_id, list_price_per_unit,
                                  planning_make_buy_code, planner_code,
                                  minimum_order_quantity,
                                  maximum_order_quantity,
                                                         --add by bt technology team
                                                         rounding_control_type,
                                  --add by bt technology team
                                  create_supply_flag,
                                                     --add by bt technology team
                                                     inventory_planning_code,
                                  --add by bt technology team
                                  mrp_safety_stock_code,
                                  --add by bt technology team
                                  safety_stock_bucket_days,
                                  --add by bt technology team
                                  mrp_safety_stock_percent,
                                  --add by bt technology team
                                  fixed_order_quantity, mrp_planning_code,
                                  ato_forecast_control,
                                  end_assembly_pegging_flag,
                                  --planning_time_fence_code,
                                  --planning_time_fence_days,
                                  demand_time_fence_code,
                                  demand_time_fence_days,
                                  preprocessing_lead_time, full_lead_time,
                                  postprocessing_lead_time, atp_flag,
                                  atp_components_flag, atp_rule_id,
                                  dimension_uom_code, weight_uom_code,
                                  fixed_days_supply, fixed_lot_multiplier,
                                  created_by, creation_date,
                                  last_updated_by, last_update_date
                                 )
                          VALUES (i.inv_org_code, i.organization_id,
                                  i.item_number, i.inventory_item_id, 1,
                                  'UPDATE', i.set_process_id,
                                  i.item_template, i.buyer_id, i.list_price,
                                  --   i.planning_make_buy_code,       --commented by bt technology team
                                  2,     --add for make_buy by bt technology team
                                    --   i.planner_code,                 --commented by bt technology team
                                  NULL,
                                     --add for planner_code by bt technology team
                                  --   i.min_order_qty,                --commented by bt technology team
                                  NULL,
                                  --add for min_order_qty by bt technology team
                                  NULL,
                                       --add for max_order_quantity by bt technology team
                                       i.rounding_ord_type,
                        --add for round_order_quantities by BT ss technology team
                                  i.create_supply_flag,
                                                       --add for create_supply by bt technology team
                                  6,
                                  --add for inventory_planning_method by bt technology team
                                  NULL,
                                  --add for safety_stock_method by bt technology team
                                  NULL,
                                  --add for safety_stock_bucket_days by bt technology team
                                  NULL,
                                  --add for safety_stock_percent by bt technology team
                                       --   i.fixed_order_qty,              --commented by bt technology team
                                  NULL,
                                       --add for mrp_planning_code by bt technology team
                                              --   i.mrp_planning_code,            --commented by bt technology team
                                  3,
                                  --add for mrp_planning_code by bt technology team
                                    --   i.ato_forecast_control_flag,    --commented by bt technology team
                                  2,

                                  --add for forecast_control_flag by bt technology team

                                  --   i.end_assembly_pegging_flag,    --commented by bt technology team
                                  'B',    --add for pegging by bt technology team
                                  --i.planning_time_fence_code,     --commented by bt technology team
                                  NULL,
                                  --add for planning_time_fence by bt technology team
                                  NULL,                -- i.plan_time_fence_days,
                                  --  i.demand_time_fence_flag,        --commeneted by bt technology team
                                  --    NULL,             --add for demand_time_fence by bt technology team
                                  --    i.demand_time_fence_days,
                                  --   ln_preprocessing_lead_time,     --commented by bt technology team
                                  10,
                                     --add for preprocssing_lead_time by bt technology team
                                               --   ln_processing_lead_time,        --commented by bt technology team
                                  NULL,
                                  --add for processing_lead_time by bt technology team
                                       --   i.post_processing_lead_time,    --commented by bt technology team
                                  NULL,
                                       --add for post_processing_lead_time by bt tehnology team
                                       i.check_atp_flag,
                                  i.atp_components_flag, i.atp_rule_id,
                                  lv_dimension_uom_code, lv_weight_uom_code,
                                  i.fixed_days_supply,
                                                      --   i.fixed_lot_multiplier,         --commented by bt technology team
                                  NULL,
                                  --add for fixed_lot_multiplier by bt technology team
                                  gn_created_by, gd_creation_date,
                                  gn_updated_by, gd_update_date
                                 ); */
    /*  UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_um
         SET xiau_um.status = 3,
             xiau_um.error_message =
                'Master Items Successfully inserted into the Interface Table',
             xiau_um.created_by = gn_created_by,
             xiau_um.creation_date = gd_creation_date,
             xiau_um.last_updated_by = gn_updated_by,
             xiau_um.last_update_date = gd_update_date
       WHERE xiau_um.sno = i.sno
         AND xiau_um.request_id = ln_parent_conc_req_id;
   EXCEPTION
      WHEN OTHERS
      THEN
         lv_sqlerrm := SUBSTR (SQLERRM, 1, 999);

         UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_um1
            SET xiau_um1.status = 50,
                xiau_um1.error_message =
                   SUBSTR
                      (   'Master Items Not Inserted Into The Interface Table'
                       || lv_sqlerrm,
                       1,
                       3999
                      ),
                xiau_um1.created_by = gn_created_by,
                xiau_um1.creation_date = gd_creation_date,
                xiau_um1.last_updated_by = gn_updated_by,
                xiau_um1.last_update_date = gd_update_date
          WHERE xiau_um1.sno = i.sno
            AND xiau_um1.request_id = ln_parent_conc_req_id;
   END;
ELSE
   lv_insert_stmt := NULL;
   ln_bom_item_type := 0;
   apps.fnd_file.put_line (apps.fnd_file.LOG,
                              'For  Child records : '
                           || ln_bom_item_type
                          );

   BEGIN
      SELECT dimension_uom_code, unit_length,
             weight_uom_code, unit_weight, unit_width,
             unit_height, bom_item_type
        INTO lv_dimension_uom_code, ln_unit_length,
             lv_weight_uom_code, ln_unit_weight, ln_unit_width,
             ln_unit_height, ln_bom_item_type
        FROM apps.mtl_system_items
       WHERE inventory_item_id = i.inventory_item_id
         AND organization_id = ln_organization_id;

      IF     NVL (lv_dimension_uom_code, '-') = '-'
         AND (   ln_unit_length IS NOT NULL
              OR ln_unit_width IS NOT NULL
              OR ln_unit_height IS NOT NULL
             )
      THEN
         lv_dimension_uom_code := 'IN';
      END IF;

      IF     NVL (lv_weight_uom_code, '-') = '-'
         AND ln_unit_weight IS NOT NULL
      THEN
         lv_weight_uom_code := 'Lbs';
      END IF;
   --   IF ln_bom_item_type = 5                                     --commented by bt technology team for remove product family
   --   THEN                                                        --commented by bt technology team for remove product family
   --      ln_processing_lead_time := -999999;                      --commented by bt technology team for remove product family
   --      ln_preprocessing_lead_time := -999999;                   --commented by bt technology team for remove product family
   --      ln_postprocessing_lead_time := -999999;                  --commented by bt technology team for remove product family
   --   ELSE                                                        --commented by bt technology team for remove product family
   --      ln_processing_lead_time := i.processing_lead_time;       --commented by bt technology team for remove product family
   --      ln_preprocessing_lead_time := i.pre_processing_lead_time;--commented by bt technology team for remove product family
   --      ln_postprocessing_lead_time :=                           --commented by bt technology team for remove product family
   --                                   i.post_processing_lead_time;--commented by bt technology team for remove product family
   --   END IF;                                                     --commented by bt technology team for remove product family
   EXCEPTION
      WHEN NO_DATA_FOUND
      THEN
         apps.fnd_file.put_line
            (apps.fnd_file.LOG,
             'Exception occured in the retreiving thr Values of Dimensions'
            );
   END;

   /*Below Condition to check if Master control items exist in data file then inserting a record in interface table for master org*/
    --ln_master_stg_count := 0;
    --ln_master_count := 0;

    /*BEGIN                                                                     --Start commented by bt technology team
       SELECT COUNT (*)
         INTO ln_master_stg_count
         FROM xxdo.xxdoascp_item_attr_upd_stg xi
        WHERE xi.sno = i.sno
          AND xi.request_id = i.request_id
          AND EXISTS (
                 SELECT 1
                   FROM apps.mtl_item_attributes mia
                  WHERE DECODE (control_level,
                                1, 'MASTER',
                                2, 'CHILD'
                               ) = 'MASTER'
                    AND DECODE (user_attribute_name,
                                'Default Buyer', xi.default_buyer,
                                'List Price', xi.list_price,
                                'Make or Buy', xi.make_buy,
                                'Planner', xi.planner_code,
                                'Minimum Order Quantity', xi.min_order_qty,
                                'Fixed Order Quantity', xi.fixed_order_qty,
                                'MRP Planning Method', xi.mrp_planning_method,
                                'Forecast Control', xi.forecast_control_method,
                                'End Assembly Pegging', xi.end_assembly_pegging,
                                'Planning Time Fence', xi.planning_time_fence,
                                'Planning Time Fence Days', xi.plan_time_fence_days,
                                'Demand Time Fence', xi.demand_time_fence,
                                'Demand Time Fence Days', xi.demand_time_fence_days,
                                'Processing Lead Time', xi.processing_lead_time,
                                'Preprocessing Lead Time', xi.pre_processing_lead_time,
                                'Postprocessing Lead Time', xi.post_processing_lead_time,
                                'Check ATP', xi.check_atp,
                                'ATP Components', xi.atp_components,
                                'ATP Rule', xi.atp_rule,
                                'Fixed Days Supply', xi.fixed_days_supply,
                                'Fixed Lot Size Multiplier', xi.fixed_lot_multiplier
                               ) IS NOT NULL
                    AND mia.user_attribute_name IN
                           ('Default Buyer', 'List Price',
                            'Make or Buy', 'Planner',
                            'Minimum Order Quantity',
                            'Fixed Order Quantity',
                            'MRP Planning Method',
                            'Forecast Control',
                            'End Assembly Pegging',
                            'Planning Time Fence',
                            'Planning Time Fence Days',
                            'Demand Time Fence',
                            'Demand Time Fence Days',
                            'Processing Lead Time',
                            'Preprocessing Lead Time',
                            'Postprocessing Lead Time',
                            'Check ATP', 'ATP Components',
                            'ATP Rule', 'Fixed Days Supply',
                            'Fixed Lot Size Multiplier'));

              apps.fnd_file.put_line(apps.fnd_file.LOG,'Inside Child2:'|| ln_master_stg_count);
    EXCEPTION
       WHEN OTHERS
       THEN
          lv_sqlerrm := SUBSTR (SQLERRM, 1, 999);

          UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_um1
             SET xiau_um1.status = 50,
                 xiau_um1.error_message =
                    SUBSTR
                       (   'Error While Checking Master Controlled Items '
                        || lv_sqlerrm,
                        1,
                        3999
                       ),
                 xiau_um1.created_by = gn_created_by,
                 xiau_um1.creation_date = gd_creation_date,
                 xiau_um1.last_updated_by = gn_updated_by,
                 xiau_um1.last_update_date = gd_update_date
           WHERE xiau_um1.sno = i.sno
             AND xiau_um1.request_id = ln_parent_conc_req_id;
    END;

    IF ln_master_stg_count >= 1
    THEN
       BEGIN
          SELECT COUNT (*)
            INTO ln_master_count
            FROM apps.mtl_system_items_interface msi
           WHERE msi.organization_id = ln_organization_id
             AND msi.inventory_item_id = i.inventory_item_id
             AND msi.process_flag = 1
             AND msi.transaction_type = 'UPDATE'
             AND EXISTS (
                    SELECT 1
                      FROM xxdo.xxdoascp_item_attr_upd_stg stg
                     WHERE request_id = ln_parent_conc_req_id
                       AND msi.set_process_id = stg.set_process_id
                       AND stg.status = 3
                       AND stg.inventory_item_id =
                                              msi.inventory_item_id);
             apps.fnd_file.put_line(apps.fnd_file.LOG,'Inside Child3:'|| ln_master_count);
       END;

       IF ln_master_count > 0
       THEN
          NULL;
       ELSE

          lv_insert_stmt := NULL;
           apps.fnd_file.put_line(apps.fnd_file.LOG,'Inside Child3.1:'|| lv_insert_stmt);
           lv_insert_stmt :=
             SUBSTR
                (   'INSERT INTO apps.mtl_system_items_interface
                         (ORGANIZATION_CODE,
                         ORGANIZATION_ID,
                         ITEM_NUMBER,
                         INVENTORY_ITEM_ID,
                         PROCESS_FLAG,
                         TRANSACTION_TYPE,
                         SET_PROCESS_ID,
                         PLANNING_MAKE_BUY_CODE,
                         MINIMUM_ORDER_QUANTITY,
                         MAXIMUM_ORDER_QUANTITY,                  --add by bt technology team
                         ROUNDING_CONTROL_TYPE,                   --add by bt technology team
                         CREATE_SUPPLY_FLAG,                      --add by bt technology team
                         INVENTORY_PLANNING_CODE,                  --add by bt technology team
                         MRP_SAFETY_STOCK_CODE,                   --add by bt technology team
                         SAFETY_STOCK_BUCKET_DAYS,                --add by bt technology team
                         MRP_SAFETY_STOCK_PERCENT,                --add by bt technology team
                         FIXED_ORDER_QUANTITY,
                         MRP_PLANNING_CODE,
                         ATO_FORECAST_CONTROL,
                         END_ASSEMBLY_PEGGING_FLAG,
                         PLANNING_TIME_FENCE_CODE,
                         PLANNING_TIME_FENCE_DAYS,
                         DEMAND_TIME_FENCE_CODE,
                         DEMAND_TIME_FENCE_DAYS,
                         ATP_COMPONENTS_FLAG,
                         FULL_LEAD_TIME,
                         PREPROCESSING_LEAD_TIME,
                         ATP_RULE_ID,
                         DIMENSION_UOM_CODE,
                         WEIGHT_UOM_CODE,
                         CREATED_BY,
                         CREATION_DATE,
                         LAST_UPDATED_BY,
                         LAST_UPDATE_DATE)
                         VALUES '
                 || '('''
                 || lv_org_code
                 || ''','
                 || ''''
                 || ln_organization_id
                 || ''','
                 || ''''
                 || i.item_number
                 || ''','
                 || ''''
                 || i.inventory_item_id
                 || ''','
                 || ''''
                 || 1
                 || ''','
                 || '''UPDATE'''
                 || ','
                 || ''''
                 || i.set_process_id
                 || ''','
                 || ''''
                 || identify_master_child_attr
                                         ('PLANNING_MAKE_BUY_CODE',
                                          'MASTER',
                                          'STAGING',
                                          i.sno,
                                          i.request_id
                                         )
                 || ''','
                 ||                     --i.planning_make_buy_code,
                    ''''
                 || identify_master_child_attr
                                         ('MINIMUM_ORDER_QUANTITY',
                                          'MASTER',
                                          'STAGING',
                                          i.sno,
                                          i.request_id
                                         )
                 || ''','
                 ||                              --i.min_order_qty,
                    ''''
                 --start changes by bt technology team
                 || identify_master_child_attr
                                         ('MAXIMUN_ORDER_QUANTITY',
                                          'MASTER',
                                          'STAGING',
                                          i.sno,
                                          i.request_id
                                         )
                 || ''','
                 ||  --i.max_order_qty,
                    ''''
                 || identify_master_child_attr                --add by bt technology team
                                          ('ROUNDING_CONTROL_TYPE',
                                           'MASTER',
                                           'STAGING',
                                           i.sno,
                                           i.request_id
                                          )
                 || ''','
                 ||                            --i.round_order_qty,
                    ''''
                 || identify_master_child_attr
                                             ('CREATE_SUPPLY_FLAG',
                                              'MASTER',
                                              'STAGING',
                                              i.sno,
                                              i.request_id
                                             )
                 || ''','
                 ||                              --i.create_supply,
                    ''''
                 || identify_master_child_attr
                                        ('INVENTORY_PLANNING_CODE',
                                         'MASTER',
                                         'STAGING',
                                         i.sno,
                                         i.request_id
                                        )
                 || ''','
                 ||                  --i.inventory_planning_method,
                    ''''
                 || identify_master_child_attr
                                          ('MRP_SAFETY_STOCK_CODE',
                                           'MASTER',
                                           'STAGING',
                                           i.sno,
                                           i.request_id
                                          )
                 || ''','
                 ||                        --i.safety_stock_method,
                    ''''
                 || identify_master_child_attr
                                       ('SAFETY_STOCK_BUCKET_DAYS',
                                        'MASTER',
                                        'STAGING',
                                        i.sno,
                                        i.request_id
                                       )
                 || ''','
                 ||                   --i.safety_stock_bucket_days,
                    ''''
                 || identify_master_child_attr
                                       ('MRP_SAFETY_STOCK_PERCENT',
                                        'MASTER',
                                        'STAGING',
                                        i.sno,
                                        i.request_id
                                       )
                 || ''','
                 ||                       --i.safety_stock_percent,
                    ''''
                 --end changes by  bt technology team
                 || identify_master_child_attr
                                           ('FIXED_ORDER_QUANTITY',
                                            'MASTER',
                                            'STAGING',
                                            i.sno,
                                            i.request_id
                                           )
                 || ''','
                 ||                            --i.fixed_order_qty,
                    ''''
                 ||identify_master_child_attr                  --add by bt technology team
                                              ('MRP_PLANNING_CODE',
                                               'MASTER',
                                               'STAGING',
                                               i.sno,
                                               i.request_id
                                              )
                 || ''','
                 ||                          --i.mrp_planning_code,
                    ''''
                 ||identify_master_child_attr                  --add by bt technology team
                                           ('ATO_FORECAST_CONTROL',
                                            'MASTER',
                                            'STAGING',
                                            i.sno,
                                            i.request_id
                                           )
                 || ''','
                 ||                  --i.ato_forecast_control_flag,
                    ''''
                 || identify_master_child_attr           --add by bt technology team
                                      ('END_ASSEMBLY_PEGGING_FLAG',
                                       'MASTER',
                                       'STAGING',
                                       i.sno,
                                       i.request_id
                                      )
                 || ''','
                 ||                    --end_assembly_pegging_flag,
                    ''''
                 || identify_master_child_attr
                                       ('PLANNING_TIME_FENCE_CODE',
                                        'MASTER',
                                        'STAGING',
                                        i.sno,
                                        i.request_id
                                       )
                 || ''','
                 ||                   --i.planning_time_fence_code,
                    ''''
                 || identify_master_child_attr
                                       ('PLANNING_TIME_FENCE_DAYS',
                                        'MASTER',
                                        'STAGING',
                                        i.sno,
                                        i.request_id
                                       )
                 || ''','
                 ||                       --i.plan_time_fence_days,
                    ''''
                 || identify_master_child_attr
                                         ('DEMAND_TIME_FENCE_CODE',
                                          'MASTER',
                                          'STAGING',
                                          i.sno,
                                          i.request_id
                                         )
                 || ''','
                 ||                     --i.demand_time_fence_flag,
                    ''''
                 || identify_master_child_attr
                                         ('DEMAND_TIME_FENCE_DAYS',
                                          'MASTER',
                                          'STAGING',
                                          i.sno,
                                          i.request_id
                                         )
                 || ''','
                 ||                     --i.demand_time_fence_days,
                    ''''
                 || identify_master_child_attr
                                            ('ATP_COMPONENTS_FLAG',
                                             'MASTER',
                                             'STAGING',
                                             i.sno,
                                             i.request_id
                                            )
                 || ''','
                 ||                        --i.atp_components_flag,
                    ''''
                 || NVL
                       (identify_master_child_attr
                                                 ('FULL_LEAD_TIME',
                                                  'MASTER',
                                                  'STAGING',
                                                  i.sno,
                                                  i.request_id
                                                 ),
                        -999999
                       )
                 || ''','
                 ||                        --i.atp_components_flag,
                    ''''
                 || NVL
                       (identify_master_child_attr
                                        ('PREPROCESSING_LEAD_TIME',
                                         'MASTER',
                                         'STAGING',
                                         i.sno,
                                         i.request_id
                                        ),
                        -999999
                       )
                 || ''','
                 ||                        --i.atp_components_flag,
                    ''''
                 || identify_master_child_attr ('ATP_RULE_ID',
                                                'MASTER',
                                                'STAGING',
                                                i.sno,
                                                i.request_id
                                               )
                 || ''','
                 ||                                --i.atp_rule_id,
                    ''''
                 || lv_dimension_uom_code
                 || ''','
                 || ''''
                 || lv_weight_uom_code
                 || ''','
                 || ''''
                 || gn_created_by
                 || ''','
                 || ''''
                 || gd_creation_date
                 || ''','
                 || ''''
                 || gn_updated_by
                 || ''','
                 || ''''
                 || gd_update_date
                 || ''')',
                 1,
                 19999
                );

          BEGIN
             apps.fnd_file.put_line(apps.fnd_file.LOG,'Inside Child4:'|| lv_insert_stmt);
             EXECUTE IMMEDIATE lv_insert_stmt;
             apps.fnd_file.put_line(apps.fnd_file.LOG,'Inside Child5:'|| lv_insert_stmt);
          EXCEPTION
             WHEN OTHERS
             THEN
                ROLLBACK;
                pv_retcode := 2;
                pv_errbuf :='Error while Inserting into  mtl_system_items_interface : '||SUBSTR (SQLERRM, 1, 2000);
                apps.fnd_file.put_line(apps.fnd_file.LOG,'Inside execute immediate:'|| pv_errbuf);
                UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau
                   SET status = 50,
                       error_message = pv_errbuf
                 WHERE request_id = ln_parent_conc_req_id;
                COMMIT;
                RAISE;
          END;
       END IF;
    END IF;*/

    --End commented by bt technology team
    /* BEGIN
        BEGIN
           apps.fnd_file.put_line
              (apps.fnd_file.LOG,
                  'inserting in interface table for  child  level: '
               || i.item_number
               || ' '
               || i.organization_id
               || ' '
               || i.inventory_item_id
               || ' '
              );
           lv_insert_stmt :=
              SUBSTR
                 (   'INSERT INTO apps.mtl_system_items_interface
                          (ORGANIZATION_CODE,
                          ORGANIZATION_ID,
                          ITEM_NUMBER,
                          INVENTORY_ITEM_ID,
                          PROCESS_FLAG,
                          TRANSACTION_TYPE,
                          SET_PROCESS_ID,
                          BUYER_ID,      --added bt bt Technology
                          LIST_PRICE_PER_UNIT,  --added by bt technology team
                          PLANNER_CODE,
                          PLANNING_MAKE_BUY_CODE,
                          MINIMUM_ORDER_QUANTITY,
                          MAXIMUM_ORDER_QUANTITY,                  --add by bt technology team
                          ROUNDING_CONTROL_TYPE,                   --add by bt technology team
                          CREATE_SUPPLY_FLAG,                      --add by bt technology team
                          INVENTORY_PLANNING_CODE,                  --add by bt technology team
                          MRP_SAFETY_STOCK_CODE,                   --add by bt technology team
                          SAFETY_STOCK_BUCKET_DAYS,                --add by bt technology team
                          MRP_SAFETY_STOCK_PERCENT,                --add by bt technology team
                          TEMPLATE_ID,                             --add by bt technology team

                          FIXED_ORDER_QUANTITY,
                          FIXED_DAYS_SUPPLY,  --added by bt technology team
                          FIXED_LOT_MULTIPLIER, --added by bt technology team
                          MRP_PLANNING_CODE,
                          ATO_FORECAST_CONTROL,
                          END_ASSEMBLY_PEGGING_FLAG,
                          PLANNING_TIME_FENCE_CODE,
                          PLANNING_TIME_FENCE_DAYS,
                          DEMAND_TIME_FENCE_CODE,
                          DEMAND_TIME_FENCE_DAYS,
                          ATP_FLAG,
                          ATP_COMPONENTS_FLAG,
                          FULL_LEAD_TIME,
                          PREPROCESSING_LEAD_TIME,
                          POSTPROCESSING_LEAD_TIME,
                          ATP_RULE_ID,
                          DIMENSION_UOM_CODE,
                          WEIGHT_UOM_CODE,
                          CREATED_BY,
                          CREATION_DATE,
                          LAST_UPDATED_BY,
                          LAST_UPDATE_DATE)
                          VALUES '
                  || '('''
                  || i.inv_org_code
                  || ''','
                  || ''''
                  || i.organization_id
                  || ''','
                  || ''''
                  || i.item_number
                  || ''','
                  || ''''
                  || i.inventory_item_id
                  || ''','
                  || ''''
                  || 1
                  || ''','
                  || '''UPDATE'''
                  || ','
                  || ''''
                  || i.set_process_id
                  || ''','
                  || ''''
                  || i.buyer_id
                  || ''','
                  || ''''
                  || i.list_price
                  || ''','
                  || ''''
                  || i.planner_code
                  || ''','
                  || ''''
                  || identify_master_child_attr
                                          ('PLANNING_MAKE_BUY_CODE',
                                           'CHILD',
                                           'STAGING',
                                           i.sno,
                                           i.request_id
                                          )
                  || ''','
                  ||                     --i.planning_make_buy_code,
                     ''''
                  || identify_master_child_attr
                                          ('MINIMUM_ORDER_QUANTITY',
                                           'CHILD',
                                           'STAGING',
                                           i.sno,
                                           i.request_id
                                          )
                  || ''','
                  ||                              --i.min_order_qty,
                     ''''
                  --start changes by bt technology team
                  || identify_master_child_attr
                                          ('MAXIMUN_ORDER_QUANTITY',
                                           'CHILD',
                                           'STAGING',
                                           i.sno,
                                           i.request_id
                                          )
                  || ''','
                  ||                              --i.max_order_qty,
                     ''''
                  || identify_master_child_attr

                                           --add by bt technology team
                     (                      'ROUNDING_CONTROL_TYPE',
                                            'CHILD',
                                            'STAGING',
                                            i.sno,
                                            i.request_id
                                           )
                  || ''','
                  ||                            --i.round_order_qty,
                     ''''
                  || identify_master_child_attr
                                              ('CREATE_SUPPLY_FLAG',
                                               'CHILD',
                                               'STAGING',
                                               i.sno,
                                               i.request_id
                                              )
                  || ''','
                  ||                              --i.create_supply,
                     ''''
                  || identify_master_child_attr
                                         ('INVENTORY_PLANNING_CODE',
                                          'CHILD',
                                          'STAGING',
                                          i.sno,
                                          i.request_id
                                         )
                  || ''','
                  ||                  --i.inventory_planning_method,
                     ''''
                  || identify_master_child_attr
                                           ('MRP_SAFETY_STOCK_CODE',
                                            'CHILD',
                                            'STAGING',
                                            i.sno,
                                            i.request_id
                                           )
                  || ''','
                  ||                        --i.safety_stock_method,
                     ''''
                  || identify_master_child_attr
                                        ('SAFETY_STOCK_BUCKET_DAYS',
                                         'CHILD',
                                         'STAGING',
                                         i.sno,
                                         i.request_id
                                        )
                  || ''','
                  ||                   --i.safety_stock_bucket_days,
                     ''''
                  || identify_master_child_attr
                                        ('MRP_SAFETY_STOCK_PERCENT',
                                         'CHILD',
                                         'STAGING',
                                         i.sno,
                                         i.request_id
                                        )
                  || ''','
                  ||                       --i.safety_stock_percent,
                     ''''
                  || i.template_id
                  || ''','
                  || ''''
                  --end changes by  bt technology team
                  || identify_master_child_attr
                                            ('FIXED_ORDER_QUANTITY',
                                             'CHILD',
                                             'STAGING',
                                             i.sno,
                                             i.request_id
                                            )
                  || ''','
                  ||                            --i.fixed_order_qty,
                     ''''
                  || identify_master_child_attr
                                               ('FIXED_DAYS_SUPPLY',
                                                'CHILD',
                                                'STAGING',
                                                i.sno,
                                                i.request_id
                                               )
                  || ''','
                  ||                       --i.safety_stock_percent,
                     ''''
                  || identify_master_child_attr
                                            ('FIXED_LOT_MULTIPLIER',
                                             'CHILD',
                                             'STAGING',
                                             i.sno,
                                             i.request_id
                                            )
                  || ''','
                  ||                       --i.safety_stock_percent,
                     ''''
                  || identify_master_child_attr

                                               --add by bt technology team
                     (                          'MRP_PLANNING_CODE',
                                                'CHILD',
                                                'STAGING',
                                                i.sno,
                                                i.request_id
                                               )
                  || ''','
                  ||                          --i.mrp_planning_code,
                     ''''
                  || identify_master_child_attr

                                            --add by bt technology team
                     (                       'ATO_FORECAST_CONTROL',
                                             'CHILD',
                                             'STAGING',
                                             i.sno,
                                             i.request_id
                                            )
                  || ''','
                  ||                  --i.ato_forecast_control_flag,
                     ''''
                  || identify_master_child_attr

                                       --add by bt technology team
                     (                  'END_ASSEMBLY_PEGGING_FLAG',
                                        'CHILD',
                                        'STAGING',
                                        i.sno,
                                        i.request_id
                                       )
                  || ''','
                  ||                    --end_assembly_pegging_flag,
                     ''''
                  || identify_master_child_attr
                                        ('PLANNING_TIME_FENCE_CODE',
                                         'CHILD',
                                         'STAGING',
                                         i.sno,
                                         i.request_id
                                        )
                  || ''','
                  ||                   --i.planning_time_fence_code,
                     ''''
                  || identify_master_child_attr
                                        ('PLANNING_TIME_FENCE_DAYS',
                                         'CHILD',
                                         'STAGING',
                                         i.sno,
                                         i.request_id
                                        )
                  || ''','
                  ||                       --i.plan_time_fence_days,
                     ''''
                  || identify_master_child_attr
                                          ('DEMAND_TIME_FENCE_CODE',
                                           'CHILD',
                                           'STAGING',
                                           i.sno,
                                           i.request_id
                                          )
                  || ''','
                  ||                     --i.demand_time_fence_flag,
                     ''''
                  || identify_master_child_attr
                                          ('DEMAND_TIME_FENCE_DAYS',
                                           'CHILD',
                                           'STAGING',
                                           i.sno,
                                           i.request_id
                                          )
                  || ''','
                  ||                     --i.demand_time_fence_days,
                     ''''
                  || identify_master_child_attr ('ATP_FLAG',
                                                 'CHILD',
                                                 'STAGING',
                                                 i.sno,
                                                 i.request_id
                                                )
                  || ''','
                  ||                     --i.demand_time_fence_days,
                     ''''
                  || identify_master_child_attr
                                             ('ATP_COMPONENTS_FLAG',
                                              'CHILD',
                                              'STAGING',
                                              i.sno,
                                              i.request_id
                                             )
                  || ''','
                  ||                        --i.atp_components_flag,
                     ''''
                  || NVL
                        (identify_master_child_attr
                                                  ('FULL_LEAD_TIME',
                                                   'CHILD',
                                                   'STAGING',
                                                   i.sno,
                                                   i.request_id
                                                  ),
                         -999999
                        )
                  || ''','
                  ||                        --i.atp_components_flag,
                     ''''
                  || NVL
                        (identify_master_child_attr
                                         ('PREPROCESSING_LEAD_TIME',
                                          'CHILD',
                                          'STAGING',
                                          i.sno,
                                          i.request_id
                                         ),
                         -999999
                        )
                  || ''','
                  ||                        --i.atp_components_flag,
                     ''''
                  || NVL
                        (identify_master_child_attr
                                        ('POSTPROCESSING_LEAD_TIME',
                                         'CHILD',
                                         'STAGING',
                                         i.sno,
                                         i.request_id
                                        ),
                         -999999
                        )
                  || ''','
                  ||                        --i.atp_components_flag,
                     ''''
                  || identify_master_child_attr ('ATP_RULE_ID',
                                                 'CHILD',
                                                 'STAGING',
                                                 i.sno,
                                                 i.request_id
                                                )
                  || ''','
                  ||                                --i.atp_rule_id,
                     ''''
                  || lv_dimension_uom_code
                  || ''','
                  || ''''
                  || lv_weight_uom_code
                  || ''','
                  || ''''
                  || gn_created_by
                  || ''','
                  || ''''
                  || gd_creation_date
                  || ''','
                  || ''''
                  || gn_updated_by
                  || ''','
                  || ''''
                  || gd_update_date
                  || ''')',
                  1,
                  19999
                 );
           apps.fnd_file.put_line
                        (apps.fnd_file.LOG,
                            'printing in interface  child  string: '
                         || 'Item Number '
                         || i.item_number
                        );

           BEGIN
              apps.fnd_file.put_line
                 (apps.fnd_file.LOG,
                     'Inside Child String Execute immediate starts:'
                  || lv_insert_stmt
                 );

              EXECUTE IMMEDIATE lv_insert_stmt;
           EXCEPTION
              WHEN OTHERS
              THEN
                 ROLLBACK;
                 pv_retcode := 2;
                 pv_errbuf :=
                       'Error while Inserting into  mtl_system_items_interface  for child level: '
                    || SUBSTR (SQLERRM, 1, 2000);
                 apps.fnd_file.put_line
                       (apps.fnd_file.LOG,
                           'Error occured Inside execute immediate:'
                        || pv_errbuf
                       );

                 UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau
                    SET status = 50,
                        error_message = pv_errbuf
                  WHERE request_id = ln_parent_conc_req_id;

                 COMMIT;
                 RAISE;
           END;

           /*INSERT INTO apps.mtl_system_items_interface
                       (organization_code, organization_id,
                        item_number, inventory_item_id,
                        process_flag, transaction_type,
                        set_process_id,
                        template_name,
                        buyer_id,
                        list_price_per_unit,
                        planning_make_buy_code,
                         planner_code,
                        minimum_order_quantity,
                        maximum_order_quantity,
                                               --add by bt technology team
                                                     -- rounding_control_type, --add by bt technology team
                                               create_supply_flag,
                        --add by bt technology team
                        inventory_planning_code,
                        --add by bt technology team
                        mrp_safety_stock_code,
                        --add by bt technology team
                        safety_stock_bucket_days,
                        --add by bt technology team
                        mrp_safety_stock_percent,
                        --add by bt technology team
                        fixed_order_quantity,
                        -- mrp_planning_code,       --add by bt technology team
                        -- ato_forecast_control,    --add by bt technology team
                        --end_assembly_pegging_flag,--add by bt technology team
                        planning_time_fence_code,
                        planning_time_fence_days,
                        demand_time_fence_code,
                        demand_time_fence_days,
                        preprocessing_lead_time, full_lead_time,
                        postprocessing_lead_time, atp_flag,
                        atp_components_flag, atp_rule_id,
                        --dimension_uom_code,
                        fixed_days_supply, fixed_lot_multiplier,
                        created_by, creation_date,
                        last_updated_by, last_update_date
                       )
                VALUES (i.inv_org_code, i.organization_id,
                        i.item_number, i.inventory_item_id,
                        1, 'UPDATE',
                        i.set_process_id, i.item_template,
                        i.buyer_id, i.list_price,
                        --   i.planning_make_buy_code,        --commented by bt technology team
                        2,  --add for make_buy by bt technology team
                          --  i.planner_code,                   --commented by bt technology team
                        NULL,
                        --add for min_order_qty by bt technology team
                         --  i.min_order_qty,                  --commented by bt technology team
                        NULL,            --add by bt technology team
                        NULL,
                             --add for max_order_qty by bt technology team

                             --   1,                               --add for round order quantities by bt technology team
                             i.create_supply_flag,
                    --Add for create supply by bt SS technology team
                        6,
                        --add for inventory planning method by bt technology team
                        NULL,
                        --add for safety stock method by bt technology team
                        NULL,
                        --add for safety stock bucket days by bt technology team
                        NULL,
                        --add for safety stock percent by bt technology team
                                --   i.fixed_order_qty,               --commented by bt technology team
                        NULL,
                        --add for fixed_order_qty by bt technology team
                           --  i.mrp_planning_code,              --commented by bt technology team
                            -- 3,                             --add for mrp_planning_code by bt technology team
                           --   i.ato_forecast_control_flag,     --commented by bt technology team
                            -- 2,                             --add for forecast_control_method by bt technology team
                            -- i.end_assembly_pegging_flag,      --commented by bt technology team
                            --    'B',                             --add for pegging by bt technology team
                            --  i.planning_time_fence_code,      --commented by bt technology team
                        1,
                        --add for planning_time_fence_code by bt technology team
                        i.plan_time_fence_days,
                        -- i.demand_time_fence_flag,     --commented by bt technology team
                        NULL,
                        --add for demand_time_fence_flag by bt technology team
                        i.demand_time_fence_days,
                        -- ln_preprocessing_lead_time,      --commented by bt technology team
                        10,
                           --add for preprocessing_lead_time by bt technology team
                                         --i.pre_processing_lead_time,
                                           -- ln_processing_lead_time,      --commented by bt technology team
                        NULL,
                        --add for processing_lead_time by bt technology team
                                  --i.processing_lead_time,
                                --  ln_postprocessing_lead_time,      --commented by bt technology team
                        NULL,
                             --add for post_processing_lead_time by bt technology team
                             --i.post_processing_lead_time,
                             i.check_atp_flag,
                        i.atp_components_flag, i.atp_rule_id,
                        --lv_dimension_uom_code,
                        i.fixed_days_supply,
                                            -- i.fixed_lot_multiplier,            --commented by bt technology team
                        NULL,
                        --add for fixed lot multiplier by bt technology team
                        gn_created_by, gd_creation_date,
                        gn_updated_by, gd_update_date
                       );
               */
        /*    COMMIT;
         EXCEPTION
            WHEN OTHERS
            THEN
               pv_errbuf :=
                     'Error while Inserting into  mtl_system_items_interface : '
                  || SUBSTR (SQLERRM, 1, 2000);
               apps.fnd_file.put_line (apps.fnd_file.LOG,
                                          'inserting in interface'
                                       || i.item_number
                                       || pv_errbuf
                                      );
         END;

         UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_uc
            SET xiau_uc.status = 3,
                xiau_uc.error_message =
                      i.item_number
                   || ' Child Items Successful into the Interface Tables ',
                xiau_uc.created_by = gn_created_by,
                xiau_uc.creation_date = gd_creation_date,
                xiau_uc.last_updated_by = gn_updated_by,
                xiau_uc.last_update_date = gd_update_date
          WHERE xiau_uc.sno = i.sno
            AND xiau_uc.request_id = ln_parent_conc_req_id;
      EXCEPTION
         WHEN OTHERS
         THEN
            UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_uc1
               SET xiau_uc1.status = 50,
                   xiau_uc1.error_message =
                         i.item_number
                      || ' is not inserted into the interface table ',
                   xiau_uc1.created_by = gn_created_by,
                   xiau_uc1.creation_date = gd_creation_date,
                   xiau_uc1.last_updated_by = gn_updated_by,
                   xiau_uc1.last_update_date = gd_update_date
             WHERE xiau_uc1.sno = i.sno
               AND xiau_uc1.request_id = ln_parent_conc_req_id;
      END;
   END IF;

   IF MOD (itemattr_cur%ROWCOUNT, 5000) = 0
   THEN
      COMMIT;
   END IF;
END LOOP;                                     --Itemattr_cur Loop End

COMMIT;

--Submit Item Import Program
BEGIN
   FOR j IN itemimp_mas_cur (ln_parent_conc_req_id)
   --apps.fnd_file.put_line(apps.fnd_file.LOG, 'Submit Item Import Program'||ln_parent_conc_req_id);
   LOOP
      BEGIN
         lv_retcode := NULL;
         lv_reterror := NULL;
         ln_req_id := 0;
         apps.fnd_file.put_line
            (apps.fnd_file.LOG,
                'Submit Item Import Program Specified Organization  for Master'
             || ln_parent_conc_req_id
            );
         submit_item_import (j.master_organization_id,
                             '2'                   -- Single Org Flag
                                ,
                             '1'               -- Validate Items Flag
                                ,
                             '1'                -- Process Items Flag
                                ,
                             '1'
                                --  Deleting the Processed records from Interface table --CHECKING
         ,
                             j.set_process_id,
                             '2'                -- create/update flag
                                ,
                             ln_req_id,
                             lv_retcode,
                             lv_reterror
                            );
         apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Submit Item Import Program'
                                 || ln_parent_conc_req_id
                                );
         COMMIT;                                   -- added on 31-AUG

         IF (lv_retcode IS NOT NULL OR lv_reterror IS NOT NULL)
         THEN
            BEGIN
               DELETE FROM apps.mtl_system_items_interface
                     WHERE set_process_id IN (
                              SELECT set_process_id
                                FROM xxdo.xxdoascp_item_attr_upd_stg
                               WHERE request_id =
                                               ln_parent_conc_req_id);

               UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_simo
                  SET xiau_simo.status = 50,
                      xiau_simo.error_message =
                         SUBSTR
                            (   'Error occured at submit item import Program '
                             || lv_reterror,
                             1,
                             3999
                            ),
                      xiau_simo.created_by = gn_created_by,
                      xiau_simo.creation_date = gd_creation_date,
                      xiau_simo.last_updated_by = gn_updated_by,
                      xiau_simo.last_update_date = gd_update_date,
                      xiau_simo.item_import_request_id = ln_req_id
                WHERE xiau_simo.organization_id =
                                             j.master_organization_id
                  AND xiau_simo.request_id = ln_parent_conc_req_id;

               COMMIT;
               RETURN;
            EXCEPTION
               WHEN OTHERS
               THEN
                  apps.fnd_file.put_line
                     (apps.fnd_file.LOG,
                      'Updation of stg. table failed at Master Item Import'
                     );
                  pv_retcode := 2;
                  pv_errbuf :=
                     SUBSTR
                        (   'Error occured at submit item import Program: '
                         || SQLERRM,
                         1,
                         1999
                        );
                  RAISE;
            END;
         ELSE
            BEGIN
               UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_simo1
                  SET xiau_simo1.status = 6,
                      xiau_simo1.error_message = NULL,
                      xiau_simo1.created_by = gn_created_by,
                      xiau_simo1.creation_date = gd_creation_date,
                      xiau_simo1.last_updated_by = gn_updated_by,
                      xiau_simo1.last_update_date = gd_update_date,
                      xiau_simo1.item_import_request_id = ln_req_id
                WHERE xiau_simo1.organization_id =
                                             j.master_organization_id
                  AND xiau_simo1.request_id = ln_parent_conc_req_id
                  AND xiau_simo1.status = 3;
            EXCEPTION
               WHEN OTHERS
               THEN
                  apps.fnd_file.put_line
                     (apps.fnd_file.LOG,
                      'Updation of stg. table failed updating the status to 6'
                     );
            END;
         END IF;
      END;

      COMMIT;

      BEGIN
         UPDATE xxdo.xxdoascp_item_attr_upd_stg stg
            SET status = 10,
                error_message =
                   (SELECT a.error_message
                      FROM apps.mtl_interface_errors a,
                           apps.mtl_system_items_interface b
                     WHERE b.transaction_id = a.transaction_id
                       AND b.organization_id =
                                             j.master_organization_id
                       AND b.inventory_item_id =
                                                stg.inventory_item_id
                       AND b.transaction_type = 'UPDATE'
                       AND b.process_flag != 7
                       AND b.set_process_id = stg.set_process_id
                       AND ROWNUM = 1)
          WHERE request_id = ln_parent_conc_req_id
            AND status = '6'
            AND set_process_id = j.set_process_id
            AND EXISTS (
                   SELECT 'x'
                     FROM apps.mtl_system_items_interface msi
                    WHERE stg.inventory_item_id =
                                                msi.inventory_item_id
                      AND msi.process_flag = 3
                      AND msi.transaction_type = 'UPDATE'
                      AND msi.set_process_id = stg.set_process_id);
      END;

      COMMIT;                                      -- added on 31-AUG
   END LOOP;

   --Submit Item Import for the Specified Organization
   FOR k IN itemimp_child_cur (ln_parent_conc_req_id)
   LOOP
      BEGIN
         lv_retcode := NULL;
         lv_reterror := NULL;
         ln_req_id := 0;
         fnd_file.put_line (apps.fnd_file.output,
                            'Running the Submit Item Import  '
                           );
         apps.fnd_file.put_line
            (apps.fnd_file.LOG,
                'Submit Item Import Program Specified Organization  for child '
             || ln_parent_conc_req_id
            );
         submit_item_import (k.organization_id,
                             '2'                   -- Single Org Flag
                                ,
                             '1'               -- Validate Items Flag
                                ,
                             '1'                -- Process Items Flag
                                ,
                             '1'
                                -- NOT deleting the Processed records from Interface table --CHECKING
         ,
                             k.set_process_id,
                             '2'                -- create/update flag
                                ,
                             ln_req_id,
                             lv_retcode,
                             lv_reterror
                            );
         COMMIT;

         IF (lv_retcode IS NOT NULL OR lv_reterror IS NOT NULL)
         THEN
            BEGIN
               DELETE FROM apps.mtl_system_items_interface
                     WHERE set_process_id IN (
                              SELECT set_process_id
                                FROM xxdo.xxdoascp_item_attr_upd_stg
                               WHERE request_id =
                                               ln_parent_conc_req_id);

               UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_simm
                  SET xiau_simm.status = 4,
                      xiau_simm.error_message =
                         'error occured at submit item import Program',
                      xiau_simm.created_by = gn_created_by,
                      xiau_simm.creation_date = gd_creation_date,
                      xiau_simm.last_updated_by = gn_updated_by,
                      xiau_simm.last_update_date = gd_update_date,
                      xiau_simm.item_import_request_id = ln_req_id
                WHERE
                      --    xiau_simm.sno=i.sno,
                      xiau_simm.organization_id = k.organization_id
                  AND xiau_simm.request_id = ln_parent_conc_req_id;

               COMMIT;
            EXCEPTION
               WHEN OTHERS
               THEN
                  pv_retcode := 2;
                  pv_errbuf :=
                        'Error occured at submit item import Program'
                     || SUBSTR (SQLERRM, 1, 1999);
                  RAISE;
            END;
         ELSE
            UPDATE xxdo.xxdoascp_item_attr_upd_stg xiau_simm1
               SET xiau_simm1.status = 6,
                   xiau_simm1.error_message = NULL,
                   --'Data has been inserted into the base tables',
                   xiau_simm1.created_by = gn_created_by,
                   xiau_simm1.creation_date = gd_creation_date,
                   xiau_simm1.last_updated_by = gn_updated_by,
                   xiau_simm1.last_update_date = gd_update_date,
                   xiau_simm1.item_import_request_id = ln_req_id
             WHERE
                   --  xiau_simm1.sno=i.sno,
                   xiau_simm1.organization_id = k.organization_id
               AND xiau_simm1.request_id = ln_parent_conc_req_id
               AND xiau_simm1.status = 3;
         END IF;
      END;

      COMMIT;                                    -- added on 31-AUG*/

               /* Updation of the staging table with child Errored records
               BEGIN
                  UPDATE xxdo.xxdoascp_item_attr_upd_stg stg
                     SET status = 10,
                         error_message =
                            SUBSTR (   stg.error_message
                                    || ' - '
                                    || (SELECT a.error_message
                                          FROM apps.mtl_interface_errors a,
                                               apps.mtl_system_items_interface b
                                         WHERE b.transaction_id =
                                                              a.transaction_id
                                           AND b.organization_id =
                                                           stg.organization_id
                                           AND b.inventory_item_id =
                                                         stg.inventory_item_id
                                           AND b.transaction_type = 'UPDATE'
                                           AND b.process_flag != 7
                                           AND b.request_id =
                                                    stg.item_import_request_id
                                           AND ROWNUM = 1),
                                    1,
                                    1000
                                   )
                   WHERE request_id = ln_parent_conc_req_id
                     AND status IN ('6', '10')
                     AND set_process_id = k.set_process_id
                     AND EXISTS (
                            SELECT 'x'
                              FROM apps.mtl_system_items_interface msi
                             WHERE stg.inventory_item_id =
                                                         msi.inventory_item_id
                               AND stg.organization_id = msi.organization_id
                               AND msi.process_flag = 3
                               AND msi.transaction_type = 'UPDATE'
                               AND msi.request_id = stg.item_import_request_id);
               END;

               COMMIT;                                      -- added on 31-AUG
            END LOOP;                                   --itemimp_cur Loop End

            COMMIT;                                         -- added on 31-AUG
         END;

 ------------------------------------------------------------------------------------
 --calling the AUDIT Report
------------------------------------------------------------------------------------
--ln_conc_req_id  :=  gn_conc_req_id;
         audit_report (ln_parent_conc_req_id);
------------------------------------------------------------------------------------
--End of the AUDIT Report
------------------------------------------------------------------------------------
      END;
   END item_attr_update_proc;*/
    -- End Commented By BT Technology Team

    --*******************************************************
    --*********************MAIN Program**********************
    --
    --
    --*******************************************************
    PROCEDURE item_attr_update_proc (pv_errbuf    OUT VARCHAR2, -- Start Added By BT Technology Team
                                     pv_retcode   OUT VARCHAR2)
    IS
        CURSOR itemattr_cur1 (pn_conc_req_id NUMBER)
        IS
            SELECT *
              FROM xxdo.xxdoascp_item_attr_upd_stg2 xia
             WHERE     NVL (xia.status, 0) = 2
                   AND xia.request_id = pn_conc_req_id;

        TYPE t_itemattr_cur1 IS TABLE OF itemattr_cur1%ROWTYPE
            INDEX BY BINARY_INTEGER;

        r_itemattr_cur1           t_itemattr_cur1;

        /*Cursor to Fetch all the Child Records*/
        CURSOR itemimp_child_cur (pn_conc_req_id NUMBER)
        IS
              SELECT COUNT (*), stg.set_process_id, mp.master_organization_id
                FROM xxdo.xxdoascp_item_attr_upd_stg2 stg, mtl_parameters mp
               WHERE     stg.organization_id = mp.organization_id
                     AND NVL (status, 0) = 3
                     AND stg.request_id = pn_conc_req_id
            GROUP BY stg.set_process_id, mp.master_organization_id
            ORDER BY stg.set_process_id;


        e_bulk_errors             EXCEPTION;
        PRAGMA EXCEPTION_INIT (e_bulk_errors, -24381);
        l_error_count             NUMBER := 0;
        ln_organization_id        NUMBER (20) := NULL;
        lv_organization           VARCHAR2 (40) := NULL;
        lv_org_code               VARCHAR2 (100) := NULL;
        lv_retcode                VARCHAR2 (2000);
        lv_reterror               VARCHAR2 (2000);
        ln_req_id                 NUMBER;
        ln_current_loop_count     NUMBER := 0;
        ln_max_item_per_program   NUMBER := 5000;
        ln_set_process_id         NUMBER;
        lv_sqlerrm                VARCHAR2 (1000);
        ln_conc_req_id            NUMBER := 0;
        lv_child_req_id           VARCHAR2 (240);
        ln_parent_conc_req_id     NUMBER := 0;
        ln_days                   NUMBER := 0;
        --ln_creation_date              DATE;
        l_error_msg               VARCHAR2 (50);
        l_msg                     VARCHAR2 (4000);
        l_idx                     NUMBER;
        l_chr_phase               VARCHAR2 (100) := NULL;
        l_chr_status              VARCHAR2 (100) := NULL;
        l_chr_dev_phase           VARCHAR2 (100) := NULL;
        l_chr_dev_status          VARCHAR2 (100) := NULL;
        l_chr_message             VARCHAR2 (1000) := NULL;
        i                         NUMBER;
        l_bol_req_status          BOOLEAN;
        user_exception            EXCEPTION;
    BEGIN
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Begin - ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS'));



        BEGIN
            DELETE FROM xxdo.xxdoascp_item_attr_upd_stg2;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Exception Occured while deleting data from stg table');
                RAISE user_exception;
        END;

        ln_parent_conc_req_id   := gn_conc_req_id;
        lv_retcode              := NULL;
        lv_reterror             := NULL;
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'Calling Procedure to Extract the records from Landing Table to Staging Table ::'
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS'));
        lv_retcode              := NULL;
        p_item_extract (lv_reterror, lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Exception Occured while extracting data into stage table2');
            RAISE user_exception;
        END IF;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'end p_item_extract '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS'));
        --*****************************************************************
        --****************** Processing Master Child Attribute ************
        --*****************************************************************
        identify_master_child_attr ('Make or Buy',
                                    'XXDO_MAKE_BUY',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('List Price',
                                    'LIST_PRICE',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Planner',
                                    'XXDO_PLANNER_CODE',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Minimum Order Quantity',
                                    'MIN_ORDER_QTY',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Fixed Order Quantity',
                                    'FIXED_ORDER_QTY',
                                    ln_parent_conc_req_id);
        --started commenting for CCR0006305
        /*identify_master_child_attr ('MRP Planning Method',
                                    'XXDO_MRP_PLANNING_METHOD',
                                    ln_parent_conc_req_id);
    */
        --ended commenting for CCR0006305
        identify_master_child_attr ('Forecast Control',
                                    'XXDO_FORECAST_CONTROL_METHOD',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('End Assembly Pegging',
                                    'XXDO_END_ASSEMBLY_PEGGING',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Planning Time Fence',
                                    'XXDO_PLANNING_TIME_FENCE',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Planning Time Fence Days',
                                    'PLAN_TIME_FENCE_DAYS',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Demand Time Fence',
                                    'XXDO_DEMAND_TIME_FENCE',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Demand Time Fence Days',
                                    'DEMAND_TIME_FENCE_DAYS',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Processing Lead Time',
                                    'PROCESSING_LEAD_TIME',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Preprocessing Lead Time',
                                    'PRE_PROCESSING_LEAD_TIME',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Postprocessing Lead Time',
                                    'POST_PROCESSING_LEAD_TIME',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Check ATP',
                                    'XXDO_CHECK_ATP',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('ATP Components',
                                    'XXDO_ATP_COMPONENTS',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('ATP Rule',
                                    'ATP_RULE_ID',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Fixed Days Supply',
                                    'FIXED_DAYS_SUPPLY',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Fixed Lot Size Multiplier',
                                    'FIXED_LOT_MULTIPLIER',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Rounding Control',
                                    'XXDO_ROUND_ORDER_QTY',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Create Supply',
                                    'XXDO_CREATE_SUPPLY',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Maximum Order Quantity',
                                    'max_order_qty',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Safety Stock',
                                    'max_order_qty',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Safety Stock Percent',
                                    'max_order_qty',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Safety Stock Bucket Days',
                                    'max_order_qty',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Inventory Planning Method',
                                    'max_order_qty',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Maximum Order Quantity',
                                    'max_order_qty',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Maximum Order Quantity',
                                    'max_order_qty',
                                    ln_parent_conc_req_id);
        identify_master_child_attr ('Maximum Order Quantity',
                                    'max_order_qty',
                                    ln_parent_conc_req_id);

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'end master child update - '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS'));
        --Updating staging Table
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Calling Procedure to Update the Staging Table2 ::');

        lv_retcode              := NULL;
        stg_tbl_upd_proc (lv_reterror, lv_retcode);

        IF lv_retcode IS NOT NULL
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Exception Occured while updating stage table 2');
            RAISE user_exception;
        END IF;



        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'end stg_tbl_upd_proc - '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS'));
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Calling Procedure To Extract Item categories Value in the Category Staging Table ::');
        extract_cat_to_stg (lv_reterror, lv_retcode, ln_parent_conc_req_id);
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'end extract_cat_to_stg - '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS'));

        OPEN itemattr_cur1 (ln_parent_conc_req_id);

        LOOP
            BEGIN
                FETCH itemattr_cur1
                    BULK COLLECT INTO r_itemattr_cur1
                    LIMIT 5000;

                IF r_itemattr_cur1.COUNT > 0
                THEN
                    FORALL i IN r_itemattr_cur1.FIRST .. r_itemattr_cur1.LAST
                      SAVE EXCEPTIONS
                        INSERT INTO apps.mtl_system_items_interface (
                                        organization_id,
                                        -- item_number,
                                        inventory_item_id,
                                        process_flag,
                                        transaction_type,
                                        set_process_id,
                                        buyer_id,
                                        list_price_per_unit,
                                        planner_code,
                                        planning_make_buy_code,
                                        minimum_order_quantity,
                                        maximum_order_quantity,
                                        rounding_control_type,
                                        create_supply_flag,
                                        inventory_planning_code,
                                        mrp_safety_stock_code,
                                        safety_stock_bucket_days,
                                        mrp_safety_stock_percent,
                                        template_id,
                                        fixed_order_quantity,
                                        fixed_days_supply,
                                        fixed_lot_multiplier,
                                        mrp_planning_code,
                                        ato_forecast_control,
                                        end_assembly_pegging_flag,
                                        planning_time_fence_code,
                                        planning_time_fence_days,
                                        demand_time_fence_code,
                                        demand_time_fence_days,
                                        atp_flag,
                                        atp_components_flag,
                                        full_lead_time,
                                        preprocessing_lead_time,
                                        postprocessing_lead_time,
                                        cumulative_total_lead_time,
                                        atp_rule_id,
                                        dimension_uom_code,
                                        weight_uom_code,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_update_date)
                             VALUES (r_itemattr_cur1 (i).organization_id, --r_itemattr_cur1(i).item_number,
                                                                          r_itemattr_cur1 (i).inventory_item_id, 1, 'UPDATE', r_itemattr_cur1 (i).set_process_id, r_itemattr_cur1 (i).buyer_id, r_itemattr_cur1 (i).list_price, r_itemattr_cur1 (i).planner_code, r_itemattr_cur1 (i).xxdo_make_buy, r_itemattr_cur1 (i).min_order_qty, r_itemattr_cur1 (i).max_order_qty, r_itemattr_cur1 (i).xxdo_round_order_qty, r_itemattr_cur1 (i).xxdo_create_supply, r_itemattr_cur1 (i).xxdo_inv_planning_method, r_itemattr_cur1 (i).xxdo_safety_stock_method, r_itemattr_cur1 (i).safety_stock_bucket_days, r_itemattr_cur1 (i).safety_stock_percent, r_itemattr_cur1 (i).template_id, r_itemattr_cur1 (i).fixed_order_qty, r_itemattr_cur1 (i).fixed_days_supply, r_itemattr_cur1 (i).fixed_lot_multiplier, r_itemattr_cur1 (i).xxdo_mrp_planning_method, r_itemattr_cur1 (i).xxdo_forecast_control_method, r_itemattr_cur1 (i).xxdo_end_assembly_pegging, r_itemattr_cur1 (i).xxdo_planning_time_fence, r_itemattr_cur1 (i).plan_time_fence_days, r_itemattr_cur1 (i).xxdo_demand_time_fence, r_itemattr_cur1 (i).demand_time_fence_days, r_itemattr_cur1 (i).xxdo_check_atp, r_itemattr_cur1 (i).xxdo_atp_components, r_itemattr_cur1 (i).processing_lead_time, r_itemattr_cur1 (i).pre_processing_lead_time, r_itemattr_cur1 (i).post_processing_lead_time, r_itemattr_cur1 (i).cumulative_total_lead_time, r_itemattr_cur1 (i).atp_rule_id, r_itemattr_cur1 (i).dimension_uom_code, r_itemattr_cur1 (i).weight_uom_code, gn_created_by, gd_creation_date
                                     , gn_updated_by, gd_update_date);

                    COMMIT;
                END IF;

                EXIT WHEN itemattr_cur1%NOTFOUND;
            EXCEPTION
                WHEN e_bulk_errors
                THEN
                    l_error_count   := SQL%BULK_EXCEPTIONS.COUNT;

                    FOR i IN 1 .. l_error_count
                    LOOP
                        l_msg   :=
                            SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                        l_idx   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;

                        UPDATE xxdo.xxdoascp_item_attr_upd_stg2 xiau_uc1
                           SET xiau_uc1.status = 50, xiau_uc1.error_message = r_itemattr_cur1 (l_idx).item_number || ' is not inserted into the interface table :' || l_msg, xiau_uc1.created_by = gn_created_by,
                               xiau_uc1.creation_date = gd_creation_date, xiau_uc1.last_updated_by = gn_updated_by, xiau_uc1.last_update_date = gd_update_date
                         WHERE     xiau_uc1.sno = r_itemattr_cur1 (l_idx).sno
                               AND xiau_uc1.inventory_item_id =
                                   r_itemattr_cur1 (l_idx).inventory_item_id
                               AND xiau_uc1.organization_id =
                                   r_itemattr_cur1 (l_idx).organization_id
                               AND xiau_uc1.request_id =
                                   ln_parent_conc_req_id;
                    END LOOP;

                    COMMIT;
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Exception When Others While Inserting Records in Interface '
                        || ln_parent_conc_req_id);
            END;
        END LOOP;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               'end loop for validation - '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS'));

        UPDATE xxdo.xxdoascp_item_attr_upd_stg2 xiau_uc
           SET xiau_uc.status = 3, xiau_uc.error_message = ' Items Successful into the Interface Tables '
         WHERE     xiau_uc.status = 2
               AND xiau_uc.request_id = ln_parent_conc_req_id;

        COMMIT;

        CLOSE itemattr_cur1;

        -------------------------------------------------------------------------
        BEGIN
            --Submit Item Import for the Specified Organization
            i   := 0;

            FOR k IN itemimp_child_cur (ln_parent_conc_req_id)
            LOOP
                BEGIN
                    lv_retcode                 := NULL;
                    lv_reterror                := NULL;
                    ln_req_id                  := 0;
                    i                          := i + 1;
                    g_item_request_ids_tab (i)   :=
                        apps.fnd_request.submit_request (application => 'INV', program => 'INCOIN', description => NULL, start_time => SYSDATE, sub_request => FALSE, argument1 => k.master_organization_id, argument2 => '1', argument3 => '1', argument4 => '1', argument5 => '2', argument6 => k.set_process_id, argument7 => '2'
                                                         , argument8 => 1 -- Gather Statistics
                                                                         );
                    g_set_process_id_tab (i)   := k.set_process_id;
                    COMMIT;

                    IF g_item_request_ids_tab (i) = 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            ' Concurrent Request is not launched');
                        lv_retcode   := '1';
                        lv_reterror   :=
                            'One or more Child requests are not launched. Please refer the log file for more details';
                    ELSE
                        fnd_file.put_line (
                            apps.fnd_file.output,
                               'Running the Submit Item Import : '
                            || g_item_request_ids_tab (i));
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Submit Item Import Program Specified Organization : '
                            || g_item_request_ids_tab (i));
                    END IF;
                END;
            END LOOP;                                   --itemimp_cur Loop End

            FOR i IN 1 .. g_item_request_ids_tab.COUNT
            LOOP
                IF g_item_request_ids_tab (i) = 0
                THEN
                    BEGIN
                        DELETE FROM apps.mtl_system_items_interface
                              WHERE set_process_id = g_set_process_id_tab (i);

                        UPDATE xxdo.xxdoascp_item_attr_upd_stg2 xiau_simm
                           SET xiau_simm.status = 4, xiau_simm.error_message = 'error occured at submit item import Program', xiau_simm.created_by = gn_created_by,
                               xiau_simm.creation_date = gd_creation_date, xiau_simm.last_updated_by = gn_updated_by, xiau_simm.last_update_date = gd_update_date,
                               xiau_simm.item_import_request_id = g_item_request_ids_tab (i)
                         WHERE     xiau_simm.set_process_id =
                                   g_set_process_id_tab (i) --AND xiau_simm.organization_id = k.organization_id
                               AND xiau_simm.request_id =
                                   ln_parent_conc_req_id;

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := 2;
                            pv_errbuf    :=
                                   'Error occured at submit item import Program'
                                || SUBSTR (SQLERRM, 1, 1999);
                            RAISE;
                    END;
                ELSE
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

                    IF ((UPPER (l_chr_dev_phase) = 'COMPLETE') OR (UPPER (l_chr_phase) = 'COMPLETED'))
                    THEN
                        BEGIN
                            UPDATE xxdo.xxdoascp_item_attr_upd_stg2 xiau_simm1
                               SET xiau_simm1.status = 6, xiau_simm1.error_message = NULL, xiau_simm1.created_by = gn_created_by,
                                   xiau_simm1.creation_date = gd_creation_date, xiau_simm1.last_updated_by = gn_updated_by, xiau_simm1.last_update_date = gd_update_date,
                                   xiau_simm1.item_import_request_id = g_item_request_ids_tab (i)
                             WHERE     xiau_simm1.set_process_id =
                                       g_set_process_id_tab (i)
                                   -- AND xiau_simm1.organization_id = k.organization_id
                                   AND xiau_simm1.request_id =
                                       ln_parent_conc_req_id
                                   AND xiau_simm1.status = 3;

                            COMMIT;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := 2;
                                pv_errbuf    :=
                                       'Error occured While Updating records to status = 6 '
                                    || SUBSTR (SQLERRM, 1, 1999);
                                RAISE;
                        END;

                        --Updation of the staging table with child Errored records
                        BEGIN
                            UPDATE xxdo.xxdoascp_item_attr_upd_stg2 stg
                               SET status   = 10,
                                   error_message   =
                                       SUBSTR (
                                              stg.error_message
                                           || ' - '
                                           || (SELECT a.error_message
                                                 FROM apps.mtl_interface_errors a, apps.mtl_system_items_interface b
                                                WHERE     b.transaction_id =
                                                          a.transaction_id
                                                      AND b.organization_id =
                                                          stg.organization_id
                                                      AND b.inventory_item_id =
                                                          stg.inventory_item_id
                                                      AND b.transaction_type =
                                                          'UPDATE'
                                                      AND b.process_flag != 7
                                                      AND b.request_id =
                                                          stg.item_import_request_id
                                                      AND ROWNUM = 1),
                                           1,
                                           1000)
                             WHERE     request_id = ln_parent_conc_req_id
                                   AND status IN ('6', '10')
                                   AND set_process_id =
                                       g_set_process_id_tab (i)
                                   AND EXISTS
                                           (SELECT 'x'
                                              FROM apps.mtl_system_items_interface msi
                                             WHERE     stg.inventory_item_id =
                                                       msi.inventory_item_id
                                                   AND stg.organization_id =
                                                       msi.organization_id
                                                   AND msi.process_flag = 3
                                                   AND msi.transaction_type =
                                                       'UPDATE'
                                                   AND msi.request_id =
                                                       stg.item_import_request_id);
                        END;

                        COMMIT;
                    END IF;
                END IF;
            END LOOP;


            COMMIT;
        END;

        ------------------------------------------------------------------------------------
        --calling the AUDIT Report
        ------------------------------------------------------------------------------------
        audit_report (ln_parent_conc_req_id);
    EXCEPTION
        WHEN user_exception
        THEN
            pv_retcode   := 2;

            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Any of the sub procedures failed. Please check the log file for more details.');
        WHEN OTHERS
        THEN
            pv_retcode   := 2;
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Others Exception in item_attr_update_proc'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END item_attr_update_proc;              -- END Added By BT Technology Team

    PROCEDURE audit_report (pn_conc_request_id IN NUMBER)
    IS
        --------------------------------------------------------------------------------
        --Local Variables Declaration
        --------------------------------------------------------------------------------
        ln_row_cnt_s   NUMBER := 0;
        ln_row_cnt_e   NUMBER := 0;

        ------------------------------------------------------------------------------------
        ---Cursor Declarations
        ------------------------------------------------------------------------------------

        ---Cursor to get the successfully Processed Records
        CURSOR success_cur IS
            SELECT xiau_suc.inv_org_code, xiau_suc.item_number, xiau_suc.category_code,
                   xiau_suc.category_structure, xiau_suc.item_template, xiau_suc.default_buyer,
                   DECODE (xiau_suc.status,  6, 'Success',  1, 'Staging Error',  10, 'Interface Error',  50, 'Critical Error',  'Unhandled Exception') status_desc, xiau_suc.error_message
              FROM xxdo.xxdoascp_item_attr_upd_stg2 xiau_suc
             WHERE     NVL (xiau_suc.status, 0) = 6
                   AND xiau_suc.request_id = pn_conc_request_id;

        ---Cursor to get the Error Records
        CURSOR error_cur IS
              SELECT xiau_err.inv_org_code, xiau_err.item_number, xiau_err.category_code,
                     xiau_err.category_structure, xiau_err.item_template, xiau_err.default_buyer,
                     DECODE (xiau_err.status,  6, 'SUCCESS',  1, 'STAGING ERROR',  10, 'INTERFACE ERROR',  50, 'Critical Error',  'Unhandled Exception') status_desc, xiau_err.error_message, request_id
                FROM xxdo.xxdoascp_item_attr_upd_stg2 xiau_err
               WHERE     NVL (xiau_err.status, 0) <> 6
                     AND xiau_err.request_id = pn_conc_request_id
            ORDER BY xiau_err.status;
    BEGIN
        apps.fnd_file.put_line (apps.fnd_file.LOG, 'Print Audit Details');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD (' ', 30, ' ')
            || ' '
            || RPAD ('Item attribute update report', 30, ' ')
            || ' '
            || RPAD (' ', 30, ' '));
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'item attribute update report - Errored Rows');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 40, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            --|| RPAD ('-', 15, '-')
            --|| '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Organization', 15, ' ')
            || '|'
            || RPAD ('Item Number', 20, ' ')
            || '|'
            || RPAD ('Category Code', 40, ' ')
            || '|'
            || RPAD ('Structure ', 15, ' ')
            || '|'
            || RPAD ('Template Name ', 15, ' ')
            || '|'
            || RPAD ('Buyer Name ', 15, ' ')
            || '|'
            --|| RPAD ('Status', 15, ' ')
            --|| '|'
            --|| RPAD ('Error Message', 50, ' '));
            || RPAD ('Error Message', 50, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 40, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            --|| RPAD ('-', 15, '-')
            --|| '|'
            --|| RPAD ('-', 50, '-'));
            || RPAD ('-', 50, '-'));

        FOR error_rec IN error_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD (NVL (error_rec.inv_org_code, ' '), 15, ' ')
                || '|'
                || RPAD (NVL (error_rec.item_number, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (error_rec.category_code, ' '), 40, ' ')
                || '|'
                || RPAD (NVL (error_rec.category_structure, ' '), 15, ' ')
                || '|'
                || RPAD (NVL (error_rec.item_template, ' '), 15, ' ')
                || '|'
                || RPAD (NVL (error_rec.default_buyer, ' '), 15, ' ')
                || '|'
                --Start modification on 29-APR-2016
                --|| RPAD (NVL (error_rec.status_desc, ' '), 15, ' ')
                --|| '|'
                --End modification on 29-APR-2016
                || RPAD (NVL (error_rec.error_message, ' '), 400, ' '));
            ln_row_cnt_e   := ln_row_cnt_e + 1;
        END LOOP;                                           --end of error_cur

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 50, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Errored Records Row Count: ' || ln_row_cnt_e);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Item Attribute Update - Successfully Processed Rows');
        apps.fnd_file.put_line (apps.fnd_file.output, RPAD ('-', 60, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 50, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('Organization', 15, ' ')
            || '|'
            || RPAD ('Item Number', 20, ' ')
            || '|'
            || RPAD ('Category Code', 50, ' ')
            || '|'
            || RPAD ('Structure ', 15, ' ')
            || '|'
            || RPAD ('Template Name ', 15, ' ')
            || '|'
            || RPAD ('Buyer Name ', 15, ' ')
            || '|'
            --Start modification on 29-APR-2016
            --|| RPAD ('Status', 15, ' ')
            --|| '|'
            --End modification on 29-APR-2016
            || RPAD ('Error Message', 50, ' '));
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 50, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 50, '-'));

        FOR success_rec IN success_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   RPAD (NVL (success_rec.inv_org_code, ' '), 15, ' ')
                || '|'
                || RPAD (NVL (success_rec.item_number, ' '), 20, ' ')
                || '|'
                || RPAD (NVL (success_rec.category_code, ' '), 50, ' ')
                || '|'
                || RPAD (NVL (success_rec.category_structure, ' '), 15, ' ')
                || '|'
                || RPAD (NVL (success_rec.item_template, ' '), 15, ' ')
                || '|'
                || RPAD (NVL (success_rec.default_buyer, ' '), 15, ' ')
                || '|'
                --|| RPAD (NVL (success_rec.status_desc, ' '), 15, ' ')
                --|| '|'
                || RPAD (NVL (success_rec.error_message, ' '), 500, ' '));
            ln_row_cnt_s   := ln_row_cnt_s + 1;
        END LOOP;                                         --end of success_cur

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 20, '-')
            || '|'
            || RPAD ('-', 50, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 15, '-')
            || '|'
            || RPAD ('-', 50, '-'));
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Successfully Processed Row Count: ' || ln_row_cnt_s);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in :- audit_report - > ' || SQLERRM);
    --RAISE;
    END audit_report;

    --******************************************************************************************/
    --This procedure is to identify master level items and insert in interface table
    --*****************************************************************************************/
    /*FUNCTION identify_master_child_attr (                                  -- Start Commented BT Technology Team
       pv_column_name         IN   VARCHAR2,
       pv_master_child        IN   VARCHAR2,
       pv_interface_staging   IN   VARCHAR2,
       pn_sno                 IN   NUMBER,
       pn_request_id          IN   NUMBER
    )
       RETURN VARCHAR2
    AS
       lv_interface_col_name   VARCHAR2 (200);
       lv_master_child         VARCHAR2 (200);
       lv_staging_col_name     VARCHAR2 (200);
       lv_sql_stmt             VARCHAR2 (20000);
       lv_stg_value            VARCHAR2 (100);
    BEGIN
       BEGIN
          SELECT SUBSTR (attribute_name, INSTR (attribute_name, '.') + 1)
                                                            interface_col_name,
                 DECODE (control_level, 1, 'MASTER', 2, 'CHILD') master_child,
                 DECODE
                    (NVL (user_attribute_name, user_attribute_name_gui),
                     'Default Buyer', 'i.buyer_id',
                     'List Price', 'i.list_price',
                     'Make or Buy', 'i.planning_make_buy_code',
                     'Planner', 'i.planner_code',
                     'Minimum Order Quantity', 'i.MIN_ORDER_QTY',
                     'Fixed Order Quantity', 'i.FIXED_ORDER_QTY',
                     'MRP Planning Method', 'i.mrp_planning_code',
                     'Forecast Control', 'i.ato_forecast_control_flag',
                     'End Assembly Pegging', 'i.end_assembly_pegging_flag',
                     'Planning Time Fence', 'i.planning_time_fence_code',
                     'Planning Time Fence Days', 'i.PLAN_TIME_FENCE_DAYS',
                     'Demand Time Fence', 'i.demand_time_fence_flag',
                     'Demand Time Fence Days', 'i.DEMAND_TIME_FENCE_DAYS',
                     'Processing Lead Time', 'i.PROCESSING_LEAD_TIME',
                     'Preprocessing Lead Time', 'i.PRE_PROCESSING_LEAD_TIME',
                     'Postprocessing Lead Time', 'i.POST_PROCESSING_LEAD_TIME',
                     'Check ATP', 'i.check_atp_flag',
                     'ATP Components', 'i.atp_components_flag',
                     'ATP Rule', 'i.atp_rule_id',
                     'Fixed Days Supply', 'i.fixed_days_supply',
                     'Fixed Lot Size Multiplier', 'i.fixed_lot_multiplier',
                     'Rounding Control', 'i.rounding_ord_type',
                                                  --added by Bt technology team
                     'Create Supply', 'i.create_supply_flag',
                                                  --added by Bt technology team
                     'Maximum Order Quantity', 'i.max_order_qty',
                                                  --added by Bt technology team
                     'Safety Stock', 'i.safety_stock_code',
                                                  --added by Bt technology team
                     'Safety Stock Percent', 'i.SAFETY_STOCK_PERCENT',
                                                  --added by Bt technology team
                     'Safety Stock Bucket Days', 'i.SAFETY_STOCK_BUCKET_DAYS',
                                                  --added by Bt technology team
                     'Inventory Planning Method', 'i.INVENTORY_PLANNING_CODE'
                                                  --added by Bt technology team
                    ) stg_col_name
            INTO lv_interface_col_name,
                 lv_master_child,
                 lv_staging_col_name
            FROM apps.mtl_item_attributes mia
           WHERE DECODE (control_level, 1, 'MASTER', 2, 'CHILD') =
                                                                pv_master_child
             AND SUBSTR (attribute_name, INSTR (attribute_name, '.') + 1) =
                                                                 pv_column_name;
       EXCEPTION
          WHEN OTHERS
          THEN
             RETURN NULL;
       END;

       lv_sql_stmt :=
          SUBSTR (   'SELECT '
                  || lv_staging_col_name
                  || ' FROM xxdo.xxdoascp_item_attr_upd_stg i WHERE i.sno = '
                  || pn_sno
                  || ' AND i.request_id = '
                  || pn_request_id,
                  1,
                  19999
                 );

       EXECUTE IMMEDIATE lv_sql_stmt
                    INTO lv_stg_value;

       IF pv_interface_staging = 'INTERFACE'
       THEN
          RETURN lv_interface_col_name;
       ELSIF pv_interface_staging = 'STAGING'
       THEN
          RETURN lv_stg_value;
       END IF;
    END identify_master_child_attr;*/
    -- END Commented BT Technology Team
    /******************************************************************************************/
    --This Function is to identify master,child level items and update the Attribute
    /******************************************************************************************/
    PROCEDURE identify_master_child_attr (pv_column_name IN VARCHAR2, -- Start Added By BT Technology Team
                                                                      pv_actual_column IN VARCHAR2, pn_request_id IN NUMBER)
    IS
        lv_interface_col_name   VARCHAR2 (200);
        lv_master_child         VARCHAR2 (200);
        lv_staging_col_name     VARCHAR2 (200);
        lv_sql_stmt             VARCHAR2 (20000);
        lv_stg_value            VARCHAR2 (100);
        l_error_msg             VARCHAR2 (100);
        l_morg                  VARCHAR2 (3);
        l_null                  VARCHAR2 (10);
        l_status                NUMBER;
        l_value                 VARCHAR2 (10);
        p_sql                   VARCHAR2 (500);
        p_sql2                  VARCHAR2 (500);
    BEGIN
        --Checking Attributes pv_column_name For child Master
        BEGIN
            SELECT --SUBSTR (attribute_name, INSTR (attribute_name, '.') + 1)interface_col_name,
                   DECODE (control_level,  1, 'MASTER',  2, 'CHILD') master_child
              INTO lv_master_child
              FROM apps.mtl_item_attributes mia
             WHERE NVL (user_attribute_name, user_attribute_name_gui) =
                   pv_column_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error in finding Master Child '
                    || SUBSTR (SQLERRM, 1, 250));
        END;

        l_error_msg   := 'Value sent in the File is not Valid';
        l_morg        := 'MST';
        l_null        := NULL;
        l_status      := 1;
        l_value       := -99;

        IF lv_master_child = 'CHILD'
        THEN
            BEGIN
                p_sql   :=
                       'UPDATE xxdo.xxdoascp_item_attr_upd_stg2 set '
                    || pv_actual_column
                    || ' = null  where inv_org_code = '''
                    || l_morg
                    || ''' and request_id = '
                    || pn_request_id;

                EXECUTE IMMEDIATE p_sql;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --ROLLBACK;
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Inside child Exception  '
                        || SUBSTR (SQLERRM, 1, 250));
            END;

            BEGIN
                p_sql2   :=
                       'UPDATE xxdo.xxdoascp_item_attr_upd_stg2 SET STATUS=1 , ERROR_MESSAGE='''
                    || l_error_msg
                    || ''' WHERE inv_org_code <>'''
                    || l_morg
                    || ''' AND '
                    || pv_actual_column
                    || ' =-99 AND request_id='
                    || pn_request_id;

                EXECUTE IMMEDIATE p_sql2;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Inside child Exception2 '
                        || SUBSTR (SQLERRM, 1, 250));
            END;
        END IF;

        IF lv_master_child = 'MASTER'
        THEN
            BEGIN
                p_sql   :=
                       'UPDATE xxdo.xxdoascp_item_attr_upd_stg2 set '
                    || pv_actual_column
                    || ' = null  where inv_org_code <> '''
                    || l_morg
                    || ''' and request_id = '
                    || pn_request_id;

                EXECUTE IMMEDIATE p_sql;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    --ROLLBACK;
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Inside Master EXP1 ' || SUBSTR (SQLERRM, 1, 250));
            END;

            BEGIN
                p_sql2   :=
                       'UPDATE xxdo.xxdoascp_item_attr_upd_stg2 SET STATUS=1 , ERROR_MESSAGE='''
                    || l_error_msg
                    || ''' WHERE inv_org_code ='''
                    || l_morg
                    || ''' AND '
                    || pv_actual_column
                    || ' =-99 AND request_id='
                    || pn_request_id;

                EXECUTE IMMEDIATE p_sql2;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Inside Master EXP2 ' || SUBSTR (SQLERRM, 1, 250));
            END;
        END IF;

        COMMIT;
    END identify_master_child_attr;         -- End Added By BT Technology Team

    /* *****************************************************************************************/
    --This procedure is to Purge the records stuck in Item interface table
    /* *****************************************************************************************/
    PROCEDURE del_item_int_stuck_rec (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_purge_date IN VARCHAR2
                                      , pn_user_id IN NUMBER)
    IS
        ld_date   DATE
            := TRUNC (TO_DATE (pv_purge_date, 'RRRR/MM/DD HH24:MI:SS'));
    BEGIN
        BEGIN
            DELETE FROM
                apps.mtl_system_items_interface msii
                  WHERE     msii.transaction_id IN
                                (SELECT err.transaction_id
                                   FROM apps.mtl_interface_errors err
                                  WHERE     err.created_by = pn_user_id
                                        AND err.creation_date >= ld_date --AND    created_by =18990
                                                                        )
                        AND created_by = pn_user_id;

            COMMIT;
        END;

        BEGIN
            DELETE FROM
                apps.mtl_interface_errors er
                  WHERE     er.created_by = pn_user_id
                        AND er.creation_date >= ld_date;

            COMMIT;
        END;
    --COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error in purge_item_inter_stuck_records procedure'
                || SQLERRM);
    END;



    --Start CR 117 BT TECH TEAM 8/24/2015


    FUNCTION get_japan_intransit_time (p_category_id   NUMBER,
                                       p_sample        VARCHAR2)
        RETURN NUMBER
    IS
        --Start modification on 29-APR-2016
        CURSOR Get_style_color_c IS
            SELECT SUBSTR (MSIB.segment1,
                           1,
                             INSTR (MSIB.segment1, '-', 1,
                                    1)
                           - 1) style_code,
                   --MSIB.segment1,
                   SUBSTR (segment1,
                             INSTR (segment1, '-', 1,
                                    1)
                           + 1,
                           (  INSTR (segment1, '-', 1,
                                     2)
                            - INSTR (segment1, '-', 1,
                                     1)
                            - 1)) color_code,
                   msib.inventory_item_id,
                   SUBSTR (MSIB.segment1,
                           1,
                             INSTR (MSIB.segment1, '-', 1,
                                    2)
                           - 1) style_color
              FROM mtl_system_items_b msib, mtl_item_categories mic
             WHERE     msib.organization_id = 106
                   AND msib.inventory_item_id = mic.inventory_item_id
                   AND mic.inventory_item_id = msib.inventory_item_id
                   AND mic.organization_id = msib.organization_id
                   AND mic.category_id = p_category_id
                   AND mic.category_set_id = 1;

        ln_item_id              NUMBER;
        lc_style                VARCHAR2 (100);
        lc_color                VARCHAR2 (100);
        lc_style_color          VARCHAR2 (100);
        --End modification on 29-APR-2016

        lc_transit_days_US_JP   VARCHAR2 (100);
        lc_transit_days_APAC    VARCHAR2 (100);
        l_vendor_name           mrp_sr_source_org_v.vendor_name%TYPE;
        l_vendor_site           mrp_sr_source_org_v.vendor_site%TYPE;
        lc_vendor_type          ap_suppliers.VENDOR_TYPE_LOOKUP_CODE%TYPE;
        lc_transit_time         NUMBER;
    BEGIN
        --Finding Vendor Name and Vendor Site for US-JP
        fnd_file.put_line (FND_FILE.LOG, 'p_category_id : ' || p_category_id);
        fnd_file.put_line (FND_FILE.LOG, 'p_sample : ' || p_sample);


        OPEN Get_style_color_c;

        FETCH Get_style_color_c INTO lc_style, lc_color, ln_item_id, lc_style_color;

        CLOSE Get_style_color_c;

        --l_region := NULL;

        BEGIN
            SELECT mso.vendor_id, vs.vendor_site_code
              INTO l_vendor_name, l_vendor_site
              FROM mrp_assignment_sets mrp, mrp_sr_assignments msra, mrp_sourcing_rules msr,
                   MRP_SR_SOURCE_ORG mso, PO_VENDOR_SITES_ALL VS, MRP_SR_RECEIPT_ORG msrov,
                   mtl_parameters mp
             WHERE     assignment_set_name LIKE '%' || 'US-JP' || '%' -- 'Deckers Default Set-US/JP'
                   AND mrp.assignment_set_id = msra.assignment_set_id
                   AND msr.sourcing_rule_id = msra.sourcing_rule_id
                   AND msrov.sourcing_rule_id = msr.sourcing_rule_id
                   AND msra.category_id = p_category_id
                   AND msra.organization_id = mp.organization_id
                   AND mp.organization_code = 'JP5'
                   AND msra.assignment_type = 5
                   AND mso.allocation_percent = 100
                   AND mso.RANK = 1
                   AND mso.sr_receipt_id = msrov.sr_receipt_id
                   AND VS.VENDOR_SITE_ID(+) = mso.VENDOR_SITE_ID
                   AND SYSDATE BETWEEN msrov.effective_date - 1
                                   AND TRUNC (
                                           NVL (msrov.disable_date + 1,
                                                SYSDATE + 1))
                   AND mrp.attribute1 = 'US-JP';
        EXCEPTION
            -- SRC_RULE_CORRECT -- Start
            WHEN TOO_MANY_ROWS
            THEN
                BEGIN
                    SELECT mso.vendor_id, vs.vendor_site_code
                      INTO l_vendor_name, l_vendor_site
                      FROM mrp_assignment_sets mrp, mrp_sr_assignments msra, mrp_sourcing_rules msr,
                           MRP_SR_SOURCE_ORG mso, PO_VENDOR_SITES_ALL VS, MRP_SR_RECEIPT_ORG msrov,
                           mtl_parameters mp
                     WHERE     assignment_set_name LIKE '%' || 'US-JP' || '%' -- 'Deckers Default Set-US/JP'
                           AND mrp.assignment_set_id = msra.assignment_set_id
                           AND msr.sourcing_rule_id = msra.sourcing_rule_id
                           AND msrov.sourcing_rule_id = msr.sourcing_rule_id
                           AND msra.category_id = p_category_id
                           AND msra.organization_id = mp.organization_id
                           AND mp.organization_code = 'JP5'
                           AND msra.assignment_type = 5
                           AND mso.allocation_percent = 100
                           AND mso.RANK = 1
                           AND mso.sr_receipt_id = msrov.sr_receipt_id
                           AND VS.VENDOR_SITE_ID(+) = mso.VENDOR_SITE_ID
                           AND SYSDATE + 1 BETWEEN TRUNC (
                                                       msrov.effective_date)
                                               AND TRUNC (
                                                       NVL (
                                                           msrov.disable_date,
                                                           SYSDATE + 2))
                           AND mrp.attribute1 = 'US-JP';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_transit_days_US_JP   := 0;
                END;
            -- SRC_RULE_CORRECT -- End
            WHEN OTHERS
            THEN
                /*     fnd_file.put_line (FND_FILE.LOG,
                                     'ln_item_id : ' || ln_item_id);
                      update xxdo.xxdoascp_item_attr_upd_stg2
                     set STATUS = 1,
                         ERROR_MESSAGE = 'Sourcing rule not setup for style '||lc_style ||' and color '||lc_color
                     where  SUBSTR (ITEM_NUMBER,
                                    1,
                                      INSTR (ITEM_NUMBER,
                                             '-',
                                             1,
                                             2)
                                    - 1)
                      = lc_style_color
                     AND ORGANIZATION_ID = 126;

                                     COMMIT; */

                --Start changes by BT Technology Team on 24-Jun-2015 for defect#2624
                -- RETURN pn_full_lead_time;
                lc_transit_days_US_JP   := 0;
        --End changes by BT Technology Team on 24-Jun-2015 for defect#2624
        END;


        fnd_file.put_line (FND_FILE.LOG,
                           'l_vendor_name US-JP : ' || l_vendor_name);
        fnd_file.put_line (FND_FILE.LOG,
                           'l_vendor_site US-JP : ' || l_vendor_site);

        BEGIN
            SELECT VENDOR_TYPE_LOOKUP_CODE
              INTO lc_vendor_type
              FROM ap_suppliers
             WHERE vendor_id = l_vendor_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                --Start changes by BT Technology Team on 24-Jun-2015 for defect#2624
                -- RETURN pn_full_lead_time;
                lc_vendor_type   := NULL;
        --End changes by BT Technology Team on 24-Jun-2015 for defect#2624
        END;

        fnd_file.put_line (FND_FILE.LOG,
                           'lc_vendor_type US-JP : ' || lc_vendor_type);

        IF lc_vendor_type = 'TQ PROVIDER'
        THEN
            IF p_sample LIKE '%SAMPLE%'
            THEN
                BEGIN
                    --started commenting for CCR0006305
                    /*SELECT attribute5
                      INTO lc_transit_days_US_JP
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                           AND language = 'US'
                           AND attribute4 = 'Japan'
                           AND attribute1 = l_vendor_name
                           AND attribute2 = l_vendor_site;*/
                    --ended commenting for CCR0006305
                    lc_transit_days_US_JP   :=
                        fetch_transit_lead_time (
                            pv_country_code    => 'JP',
                            pv_supplier_code   => l_vendor_site); --added for CCR0006305
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_transit_days_US_JP   := 0;
                END;
            ELSE
                BEGIN
                    --started commenting for CCR0006305
                    /*SELECT attribute6
                      INTO lc_transit_days_US_JP
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                           AND language = 'US'
                           AND attribute4 = 'Japan'
                           AND attribute1 = l_vendor_name
                           AND attribute2 = l_vendor_site;*/
                    --ended commenting for CCR0006305
                    lc_transit_days_US_JP   :=
                        fetch_transit_lead_time (
                            pv_country_code    => 'JP',
                            pv_supplier_code   => l_vendor_site); --added for CCR0006305
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lc_transit_days_US_JP   := 0;
                END;
            END IF;
        ELSE
            lc_transit_days_US_JP   := 0;
        END IF;

        --Finding Vendor Name and Vendor Site for APAC

        BEGIN
            SELECT mso.vendor_id, vs.vendor_site_code
              INTO l_vendor_name, l_vendor_site
              FROM mrp_assignment_sets mrp, mrp_sr_assignments msra, mrp_sourcing_rules msr,
                   MRP_SR_SOURCE_ORG mso, PO_VENDOR_SITES_ALL VS, MRP_SR_RECEIPT_ORG msrov,
                   mtl_parameters mp
             WHERE     assignment_set_name LIKE '%' || 'APAC' || '%' -- 'Deckers Default Set-US/JP'
                   AND mrp.assignment_set_id = msra.assignment_set_id
                   AND msr.sourcing_rule_id = msra.sourcing_rule_id
                   AND msrov.sourcing_rule_id = msr.sourcing_rule_id
                   AND msra.category_id = p_category_id
                   AND msra.organization_id = mp.organization_id
                   AND mp.organization_code = 'MC2'
                   AND msra.assignment_type = 5
                   AND mso.allocation_percent = 100
                   AND mso.RANK = 1
                   AND mso.sr_receipt_id = msrov.sr_receipt_id
                   AND VS.VENDOR_SITE_ID(+) = mso.VENDOR_SITE_ID
                   AND SYSDATE BETWEEN msrov.effective_date - 1
                                   AND TRUNC (
                                           NVL (msrov.disable_date + 1,
                                                SYSDATE + 1))
                   AND mrp.attribute1 = 'APAC';
        EXCEPTION
            -- SRC_RULE_CORRECT -- Start
            WHEN TOO_MANY_ROWS
            THEN
                BEGIN
                    SELECT mso.vendor_id, vs.vendor_site_code
                      INTO l_vendor_name, l_vendor_site
                      FROM mrp_assignment_sets mrp, mrp_sr_assignments msra, mrp_sourcing_rules msr,
                           MRP_SR_SOURCE_ORG mso, PO_VENDOR_SITES_ALL VS, MRP_SR_RECEIPT_ORG msrov,
                           mtl_parameters mp
                     WHERE     assignment_set_name LIKE '%' || 'APAC' || '%' -- 'Deckers Default Set-US/JP'
                           AND mrp.assignment_set_id = msra.assignment_set_id
                           AND msr.sourcing_rule_id = msra.sourcing_rule_id
                           AND msrov.sourcing_rule_id = msr.sourcing_rule_id
                           AND msra.category_id = p_category_id
                           AND msra.organization_id = mp.organization_id
                           AND mp.organization_code = 'MC2'
                           AND msra.assignment_type = 5
                           AND mso.allocation_percent = 100
                           AND mso.RANK = 1
                           AND mso.sr_receipt_id = msrov.sr_receipt_id
                           AND VS.VENDOR_SITE_ID(+) = mso.VENDOR_SITE_ID
                           AND SYSDATE + 1 BETWEEN TRUNC (
                                                       msrov.effective_date)
                                               AND TRUNC (
                                                       NVL (
                                                           msrov.disable_date,
                                                           SYSDATE + 2))
                           AND mrp.attribute1 = 'APAC';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        UPDATE xxdo.xxdoascp_item_attr_upd_stg2
                           SET STATUS = 1, --             ERROR_MESSAGE = 'Sourcing rule not setup for style '||lc_style ||' and color '||lc_color
                                           ERROR_MESSAGE = 'Sourcing rule not setup for style color ' || lc_style || '-' || lc_color
                         WHERE     SUBSTR (ITEM_NUMBER,
                                           1,
                                             INSTR (ITEM_NUMBER, '-', 1,
                                                    2)
                                           - 1) = lc_style_color
                               AND ORGANIZATION_ID = 126;

                        --End  modification on 29-APR-2016
                        RETURN 0;
                END;
            -- SRC_RULE_CORRECT -- End
            WHEN OTHERS
            THEN
                --Start changes by BT Technology Team on 24-Jun-2015 for defect#2624
                -- RETURN pn_full_lead_time;
                --Start modification on 29-APR-2016
                UPDATE xxdo.xxdoascp_item_attr_upd_stg2
                   SET STATUS = 1, --             ERROR_MESSAGE = 'Sourcing rule not setup for style '||lc_style ||' and color '||lc_color
                                   ERROR_MESSAGE = 'Sourcing rule not setup for style color ' || lc_style || '-' || lc_color
                 WHERE     SUBSTR (ITEM_NUMBER,
                                   1,
                                     INSTR (ITEM_NUMBER, '-', 1,
                                            2)
                                   - 1) = lc_style_color
                       AND ORGANIZATION_ID = 126;

                --End  modification on 29-APR-2016
                RETURN 0;
        --End changes by BT Technology Team on 24-Jun-2015 for defect#2624
        END;

        fnd_file.put_line (FND_FILE.LOG,
                           'l_vendor_name APAC : ' || l_vendor_name);
        fnd_file.put_line (FND_FILE.LOG,
                           'l_vendor_site APAC : ' || l_vendor_site);

        IF p_sample LIKE '%SAMPLE%'
        THEN
            BEGIN
                --started commenting for CCR0006305
                /*SELECT attribute5
                  INTO lc_transit_days_APAC
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                       AND language = 'US'
                       AND attribute4 = 'Japan'
                       AND attribute1 = l_vendor_name
                       AND attribute2 = l_vendor_site;*/
                --ended commenting for CCR0006305
                lc_transit_days_APAC   :=
                    fetch_transit_lead_time (
                        pv_country_code    => 'JP',
                        pv_supplier_code   => l_vendor_site); --added for CCR0006305
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_transit_days_APAC   := NULL;
            END;
        ELSE
            BEGIN
                --started commenting for CCR0006305
                /*SELECT attribute6
                  INTO lc_transit_days_APAC
                  FROM fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                       AND language = 'US'
                       AND attribute4 = 'Japan'
                       AND attribute1 = l_vendor_name
                       AND attribute2 = l_vendor_site;*/
                --ended commenting for CCR0006305
                lc_transit_days_APAC   :=
                    fetch_transit_lead_time (
                        pv_country_code    => 'JP',
                        pv_supplier_code   => l_vendor_site); --added for CCR0006305
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_transit_days_APAC   := NULL;
            END;
        END IF;


        fnd_file.put_line (FND_FILE.LOG,
                           'lc_transit_days_APAC : ' || lc_transit_days_APAC);
        fnd_file.put_line (
            FND_FILE.LOG,
            'lc_transit_days_US_JP : ' || lc_transit_days_US_JP);

        lc_transit_time   :=
            NVL (lc_transit_days_APAC, 0) + NVL (lc_transit_days_US_JP, 0);



        RETURN lc_transit_time;
    END get_japan_intransit_time;
--End CR 117 BT TECH TEAM 8/24/2015

END xxdoascp_item_attr_upd_pkg;
/
