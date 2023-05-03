--
-- XXDOEC_INVENTORY  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_INVENTORY"
AS
    --  ####################################################################################################
    --  Package      : XXDOEC_INVENTORY
    --  Design       : This package is for ATP calculation.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  13-Aug-2020     1.0        Showkath Ali             CCR0008765 changes
    --  11-Feb-2021     1.2        Jayarajan A K            Modified for CCR0008870 - Global Inventory Allocation Project
    --  21-Feb-2022     1.3        Jayarajan A K            Modified for CCR0009849 - Next ATP Date Qty should be >0
    --  ####################################################################################################
    /*
        WTF Inventory
            This package (xxdoec_inventory) is derived from a pre-existing package (do_edi_805_processing)
            The strategy is to reuse the ATP calculation logic without impacting the legacy package.
            Inventory data is periodically recorded in a table from which it's periodically consumed by the WTF web service.
            No EDI files are created here.
        Features:
            Inventory Table - Item ATP is recorded in the table XXDO.xxdoec_inventory.
                When consumed by WTF, the consumed_date field is set from null to the job timestamp.
                When ATP is updated, the consumed_date is set to null.
            Inventory Buffer - To help prevent oversell, we subtract a specified value from the reported ATP.
                The buffer value is maintained as a DFF via Oracle apps at the organization-item level
                and stored in attribute7 of table mtl_system_items_b.
            Item Exclusion - this feature is retained, so items defined in table custom.do_edi_805_exclusions
                are excluded from the 805 AND the inventory data.
            Item UPC is captured and available to WTF.
            Backorder and Preorder quantities are not supported in this phase.
                All that's missing is to populate the table XXDO.xxdoec_inventory with the correct information;
                WTF is already propogating these fields.
            Configuration - The table XXDO.xxdoec_inventory_config records values per op unit (warehouse group).
                The default_atp_buffer value is applied whenever an item's inventory_buffer is NULL.
                The list name is not implemented in phase I, the list name is currently set by the CF layer.
        Modifications:
            11-16-2010 - rkinsel - creation date
                - Added table XXDO.xxdoec_inventory to store ATP data consumed by WTF.
                - Added brand to atp_record
                    Brand is stored in the mtl_categories table.
                    When reporting to WTF, inventory_buffer is subtracted from the ATP (minimum is zero).
                - Added inventory_buffer to atp_record with supporting DFF in Oracle Apps.
                - Added config table, XXDO.xxdoec_inventory_config
            12-21-2010 - rkinsel - modified query in the 'net_changes' cursor to
                incorporate changes from the do_edi_805_processing package.
            01-01-2010 -rkinsel - removed v_nad_time, use v_next_bizday to detect backordered ATP because this date must come from msc_calendar_dates.
            03-09-2011 - kcopeland - added procedure xxdoec_get_upc_quantity
            07-11-2011 - rkinsel - CCR0001720 - Refactor : this release contains the following modifications:
                 1. inventory calculations rewritten to support multiple business orgs in same inventory org
                     and calculation of next available ATP count (in addition to date)
                     and broken down to allow more granular debugging
                 2. added erp_org_id lookup to xxdoec_get_upc_quantity
                 3. added p_feed_code to xxdoec_get_inventory
             09/29/2011 - rkinsel - INC0094876 - Add PDP process check to inventory process
                 Replicated behavior from do_edi_805_processing.batch_run to exit immediately if PDP request if running.
                 Added a count of consecutive calls when PDP is running
              10/25/2011 - rkinsel - INC0095267 - Add improved PDP check to inventory process
                 Recognize (3) different PDP process status: ready, running, error.
                 xxdoec_update_atp_table() - disable inventory update when PDP is not ready.
                 xxdoec_get_inventory() - added return code and message to report when PDP is not ready. Data is not returned if PDP status is error.
                 Note: xxdoec_get_upc_quantity() must always return data.
                 Removed count of consecutive calls.
              01/09/2012 - rkinsel - fixed bug in exeption handler
              02/08/2012 - rkinsel, rmccarter - changes for channel advisor
                 added columns SKU and CONSUMED_DATE_CA to table xxdoec_inventory
                 added procedures, xxdoec_get_inventory_ca, xxdoec_reset_inventory_set_ca
              04/13/2012 - rkinsel - performance improvements
                 added index, XXDOEC_INVENTORY_IDX, to table, xxdo.xxdoec_inventory
                 changed data type of tatbl_int1 from table of pls_integer to table of number
                 changed INSERT statements in procedure, xxdoec_update_atp_table()
             04-27-1012 - rkinsel - INC0110714 - error-handling improvements and addition of DCDLogging
                 - storage for all varchar2 data is increased to 64 bytes
                 - UPCs of length > 12 are excluded from catalog data
                 - xxdoec_update_atp_table returns error status (2) instead of warning (1) for unexpected exceptions,
                   also the status message includes SQLERRM, FORMAT_ERROR_BACKTRACE and FORMAT_CALL_STACK
                   to identify the exact point of failure
                 - xxdoec_update_atp_table logs start/finish, errors, and metrics for key processing steps
                 - xxdoec_update_atp_table logs ATP analysis data each time it is run
             04-27-2017 - kcopeland - OGIKB-28 Added new method for returning current inventory for a given upc within all available DC's
       10-04-2019 - kcopeland - OMS-2568 (CCR0008239) Added cleanup of global temp table to beginning of xxdoec_get_atp_for_upc
    */

    /* Private Package Constants */
    g_package_title              CONSTANT VARCHAR2 (30) := 'XXDOEC_INVENTORY';
    g_application                CONSTANT VARCHAR2 (30) := 'apps.xxdoec_inventory';
    g_newline                    CONSTANT VARCHAR2 (4) := CHR (13) || CHR (10);

    /* g_inventory_buffer_default - Default inventory buffer value; use only when item buffer is defined */
    g_inventory_buffer_default   CONSTANT NUMBER := 0;

    /* defaults */
    g_default_num                         NUMBER := -1;
    g_default_date                        DATE
        := TO_DATE ('01/01/1900', 'mm/dd/yyyy');

    g_msg_pdp_running            CONSTANT VARCHAR2 (128)
        := 'Inventory Update Disabled in Oracle: PDP status is running.' ;
    g_msg_pdp_error              CONSTANT VARCHAR2 (128)
        := 'Inventory Update Disabled in Oracle: PDP status is error.' ;
    g_num_pdp_running                     NUMBER := -20902;
    g_num_pdp_error                       NUMBER := -20903;
    gc_ou_name                            hr_operating_units.name%TYPE;

    /* DCDLogCodes */
    TYPE DCDLogCodeRec IS RECORD
    (
        AppUpdateStart                    NUMBER := -101001,
        AppUpdateEnd                      NUMBER := -101002,
        ErrPdpRunning                     NUMBER := -101101,
        ErrPdpError                       NUMBER := -101102,
        ErrUnexpectedException            NUMBER := -101103,
        MetUpdateProcedure                NUMBER := -101201,
        MetProcessFeed                    NUMBER := -101202,
        MetGetSupplyDemandData            NUMBER := -101203,
        MetGetKcoData                     NUMBER := -101204,
        MetGetCatalogData                 NUMBER := -101205,
        MetCalculateInventoryForSource    NUMBER := -101206,
        MetModifyFeedData                 NUMBER := -101207,
        MetInventorySourceAnalysis        NUMBER := -101208
    );

    DCDLogCodes                           DCDLogCodeRec;

    /* Private Data Types */
    -- TYPE atp_t2 IS TABLE OF xxdo.xxdoec_inventory%ROWTYPE;
    -- TYPE atp_t2 IS TABLE OF xxdoec_inv_atp_ot;

    /* Routines */

    PROCEDURE xxdoec_get_upc_quantity (p_list IN t_upc_array, p_site_id IN VARCHAR2, o_upc_quantity_cursor OUT t_upc_quantity_cursor)
    IS
        l_list         xxdoec_upc_list := xxdoec_upc_list ();
        l_inv_org_id   NUMBER := -1;
        l_erp_org_id   NUMBER := -1;
    BEGIN
        --Get the inventory org id for the passed site_id
        SELECT inv_org_id, erp_org_id
          INTO l_inv_org_id, l_erp_org_id
          FROM xxdo.xxdoec_country_brand_params
         WHERE website_id = p_site_id;

        IF (l_inv_org_id >= 0 AND l_inv_org_id >= 0)
        THEN
            l_list.EXTEND (p_list.COUNT);

            FOR i IN p_list.FIRST .. p_list.LAST
            LOOP
                l_list (i)   := p_list (i);
            END LOOP;

            OPEN o_upc_quantity_cursor FOR
                  SELECT xxdo.xxdoec_inventory.upc upc, GREATEST (xxdo.xxdoec_inventory.atp_qty - xxdo.xxdoec_inventory.atp_buffer, 0) quantity, xxdo.xxdoec_inventory.pre_back_order_mode prebackstatus,
                         xxdo.xxdoec_inventory.pre_back_order_qty prebackqty, xxdo.xxdoec_inventory.pre_back_order_date prebackdate
                    FROM xxdo.xxdoec_inventory
                   WHERE     xxdo.xxdoec_inventory.erp_org_id = l_erp_org_id
                         AND xxdo.xxdoec_inventory.inv_org_id = l_inv_org_id
                         AND xxdo.xxdoec_inventory.upc IN
                                 (SELECT * FROM TABLE (l_list))
                ORDER BY xxdo.xxdoec_inventory.upc ASC;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_upc_quantity_cursor   := NULL;
    END xxdoec_get_upc_quantity;


    PROCEDURE get_upc_report (
        p_list                IN     t_upc_array,
        p_site_id             IN     VARCHAR2,
        o_upc_report_cursor      OUT t_upc_report_cursor)
    IS
        l_list         xxdoec_upc_list := xxdoec_upc_list ();
        l_inv_org_id   NUMBER := -1;
        l_erp_org_id   NUMBER := -1;
    BEGIN
        --Get the inventory org id for the passed site_id
        SELECT inv_org_id, erp_org_id
          INTO l_inv_org_id, l_erp_org_id
          FROM xxdo.xxdoec_country_brand_params
         WHERE website_id = p_site_id;

        IF (l_inv_org_id >= 0 AND l_inv_org_id >= 0)
        THEN
            l_list.EXTEND (p_list.COUNT);

            FOR i IN p_list.FIRST .. p_list.LAST
            LOOP
                l_list (i)   := p_list (i);
            END LOOP;

            OPEN o_upc_report_cursor FOR
                  SELECT xxdo.xxdoec_inventory.upc upc, xxdo.xxdoec_inventory.sku sku, xxdo.xxdoec_inventory.inventory_item_id inventory_item_id,
                         GREATEST (xxdo.xxdoec_inventory.atp_qty - xxdo.xxdoec_inventory.atp_buffer, 0) site_atp_qty, xxdo.xxdoec_inventory.atp_date atp_date, xxdo.xxdoec_inventory.pre_back_order_mode pre_back_order_mode,
                         xxdo.xxdoec_inventory.pre_back_order_qty pre_back_order_qty, xxdo.xxdoec_inventory.pre_back_order_date pre_back_order_date, xxdo.xxdoec_inventory.atp_when_atr atp_when_atr,
                         xxdo.xxdoec_inventory.kco_remaining_qty kco_remaining_qty, xxdo.xxdoec_inventory.consumed_date consumed_date, xxdo.xxdoec_inventory.consumed_date_ca consumed_date_ca
                    FROM xxdo.xxdoec_inventory
                   WHERE     xxdo.xxdoec_inventory.erp_org_id = l_erp_org_id
                         AND xxdo.xxdoec_inventory.inv_org_id = l_inv_org_id
                         AND xxdo.xxdoec_inventory.upc IN
                                 (SELECT * FROM TABLE (l_list))
                ORDER BY xxdo.xxdoec_inventory.upc ASC;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            o_upc_report_cursor   := NULL;
    END get_upc_report;


    /* xxdoec_get_inventory
         Supports requests for inventory levels from webservice.
         Inventory groups of type, FEED, control the granularity of updates to the xxdoec_inventory table
         Inventory groups of other types may be created to control the granularity of consumption.
    */
    PROCEDURE xxdoec_get_inventory (
        p_net_change        IN     CHAR,
        o_inventory_items      OUT t_inventory_feed_cursor,
        p_group_code               VARCHAR2 DEFAULT NULL,
        o_return_code          OUT NUMBER,
        o_return_message       OUT VARCHAR2)
    IS
        v_found        NUMBER;
        v_group_code   VARCHAR2 (8192);
        v_pdp_status   VARCHAR2 (8192);
    BEGIN
        o_return_code      := 0;                                    -- success
        o_return_message   := 'Success';

        v_group_code       := NVL (UPPER (TRIM (p_group_code)), '%');

        IF v_group_code = ''
        THEN
            v_group_code   := '%';
        END IF;

        SELECT NVL (MAX (1), 0)
          INTO v_found
          FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
         WHERE UPPER (code) LIKE v_group_code;

        IF v_found <> 1
        THEN
            o_return_code   := -20901;
            o_return_message   :=
                'Inventory: Unkown group_code: [' || p_group_code || '].';
            raise_application_error (-20901, o_return_message);
        END IF;

        /* Check PDP Flag, if PDP is in error, return immediately and DO NOT return any data ******/
        -- Commented by BT Team on 4/2
        --      v_pdp_status := xxdo_pdp_utils_pub.get_current_state;

        /*
              IF v_pdp_status = xxdo_pdp_utils_pub.get_error_status_code
              THEN
                 o_return_code := g_num_pdp_error;
                 o_return_message := g_msg_pdp_error;
                 DO_DEBUG_UTILS.WRITE (
                    l_debug_loc        => DO_EDI_UTILS_PUB.G_DEBUG_LOCATION,
                    v_application_id   => g_package_title || '.XXDOEC_GET_INVENTORY',
                    v_debug_text       => o_return_message,
                    l_debug_level      => 1);
                 RETURN;
              END IF;
        */

        IF p_net_change = 'N'
        THEN
            -- return all inventory matching the feed_code, do not change consumed_date
            OPEN o_inventory_items FOR
                SELECT upc AS upc, GREATEST (atp_qty - atp_buffer, 0) AS atp_quantity, atp_date AS atp_date,
                       is_perpetual AS is_perpetual, pre_back_order_mode AS pre_back_order_mode, pre_back_order_qty AS pre_back_order_qty,
                       pre_back_order_date AS pre_back_order_date
                  FROM xxdo.xxdoec_inventory
                 WHERE (erp_org_id, inv_org_id) IN
                           (SELECT erp_org_id, inv_org_id
                              FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                             WHERE UPPER (code) LIKE v_group_code);
        ELSE
            -- return net changes matching the feed_code  only:
            --    select all unconsumed records and set their consumed date
            LOCK TABLE xxdo.xxdoec_inventory IN EXCLUSIVE MODE NOWAIT; -- lock table before we start work... don't allow inventory update while we work

            OPEN o_inventory_items FOR
                SELECT upc AS upc, GREATEST (atp_qty - atp_buffer, 0) AS atp_quantity, atp_date AS atp_date,
                       is_perpetual AS is_perpetual, pre_back_order_mode AS pre_back_order_mode, pre_back_order_qty AS pre_back_order_qty,
                       pre_back_order_date AS pre_back_order_date
                  FROM xxdo.xxdoec_inventory
                 WHERE     consumed_date IS NULL
                       AND (erp_org_id, inv_org_id) IN
                               (SELECT erp_org_id, inv_org_id
                                  FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                                 WHERE UPPER (code) LIKE v_group_code);

            -- set records' consumed date
            UPDATE xxdo.xxdoec_inventory
               SET consumed_date   = SYSDATE
             WHERE     consumed_date IS NULL
                   AND (erp_org_id, inv_org_id) IN
                           (SELECT erp_org_id, inv_org_id
                              FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                             WHERE UPPER (code) LIKE v_group_code);

            COMMIT;
        END IF;
    /* Check PDP Flag again and report running or error status ******/
    --      v_pdp_status := xxdo_pdp_utils_pub.get_current_state;

    /*
          IF v_pdp_status = xxdo_pdp_utils_pub.get_running_status_code
          THEN
             o_return_code := g_num_pdp_running;
             o_return_message := g_msg_pdp_running;
             DO_DEBUG_UTILS.WRITE (
                l_debug_loc        => DO_EDI_UTILS_PUB.G_DEBUG_LOCATION,
                v_application_id   => g_package_title || '.XXDOEC_GET_INVENTORY',
                v_debug_text       => o_return_message,
                l_debug_level      => 1);
          ELSIF v_pdp_status = xxdo_pdp_utils_pub.get_error_status_code
          THEN
             o_return_code := g_num_pdp_error;
             o_return_message := g_msg_pdp_error || '(on exit)';
             DO_DEBUG_UTILS.WRITE (
                l_debug_loc        => DO_EDI_UTILS_PUB.G_DEBUG_LOCATION,
                v_application_id   => g_package_title || '.XXDOEC_GET_INVENTORY',
                v_debug_text       => o_return_message,
                l_debug_level      => 1);
          END IF;
    */
    END xxdoec_get_inventory;



    /* xxdoec_get_inventory_ca
         Gets invenotry information for Channel Adivisor by group (country) and brand
    */
    PROCEDURE xxdoec_get_inventory_ca (p_max_records IN NUMBER, o_inventory_items OUT t_inventory_feed_cursor_ca, p_site_id VARCHAR2
                                       , o_consumed_date OUT DATE, o_return_code OUT NUMBER, o_return_message OUT VARCHAR2)
    IS
        v_found        NUMBER;
        v_site_id      VARCHAR2 (64);
        v_erp_org_id   NUMBER;
        v_brand        VARCHAR2 (64);
        v_pdp_status   VARCHAR2 (128);
    BEGIN
        /* Inits */
        o_return_code      := 0;                                    -- success
        o_return_message   := 'Success';

        v_site_id          := NVL (UPPER (TRIM (p_site_id)), '');

        /* Validate parms */
        SELECT DISTINCT NVL (erp_org_id, 0), brand_name
          INTO v_erp_org_id, v_brand
          FROM xxdo.xxdoec_country_brand_params
         WHERE UPPER (website_id) = v_site_id;

        IF v_erp_org_id <= 0
        THEN
            o_return_code   := -20901;
            o_return_message   :=
                'Inventory: Unkown site id: [' || p_site_id || '].';
            raise_application_error (-20901, o_return_message);
        END IF;

        /* Check PDP Flag, if PDP is in error, return immediately and DO NOT return any data ******/
        --      v_pdp_status := xxdo_pdp_utils_pub.get_current_state;

        /*
              IF v_pdp_status = xxdo_pdp_utils_pub.get_error_status_code
              THEN
                 o_return_code := g_num_pdp_error;
                 o_return_message := g_msg_pdp_error;
                 DO_DEBUG_UTILS.WRITE (
                    l_debug_loc        => DO_EDI_UTILS_PUB.G_DEBUG_LOCATION,
                    v_application_id   =>    g_package_title
                                          || '.xxdoec_get_inventory_ca',
                    v_debug_text       => o_return_message,
                    l_debug_level      => 1);
                 RETURN;
              END IF;
        */
        /* Get the data */
        LOCK TABLE xxdo.xxdoec_inventory IN EXCLUSIVE MODE NOWAIT; -- lock table before we start work... don't allow inventory update while we work

        -- Get the data
        OPEN o_inventory_items FOR
            SELECT upc AS upc, sku AS sku, GREATEST (atp_qty - atp_buffer, 0) AS atp_quantity,
                   atp_date AS atp_date
              FROM xxdo.xxdoec_inventory
             WHERE     consumed_date_ca IS NULL
                   AND erp_org_id = v_erp_org_id
                   AND brand = v_brand
                   AND ROWNUM < p_max_records;

        -- Set records' consumed date
        o_consumed_date    := SYSDATE;

        --SELECT SYSDATE INTO o_consumed_date FROM dual;
        UPDATE xxdo.xxdoec_inventory
           SET consumed_date_ca   = o_consumed_date
         WHERE     consumed_date_ca IS NULL
               AND erp_org_id = v_erp_org_id
               AND brand = v_brand
               AND ROWNUM < p_max_records;

        COMMIT;
    END xxdoec_get_inventory_ca;


    /*
        xxdoec_get_reset_inventory_ca
        Reset the consumed_date for all records for a site
    */
    PROCEDURE xxdoec_reset_inventory_ca (p_site_id VARCHAR2, o_return_code OUT NUMBER, o_return_message OUT VARCHAR2)
    IS
        v_site_id      VARCHAR2 (64);
        v_erp_org_id   NUMBER;
        v_brand        VARCHAR2 (64);
    BEGIN
        /* Inits */
        o_return_code      := 0;                                    -- success
        o_return_message   := 'Success';

        v_site_id          := NVL (UPPER (TRIM (p_site_id)), '');

        /* Validate parms */
        SELECT DISTINCT NVL (erp_org_id, 0), brand_name
          INTO v_erp_org_id, v_brand
          FROM xxdo.xxdoec_country_brand_params
         WHERE UPPER (website_id) = v_site_id;

        IF v_erp_org_id <= 0
        THEN
            o_return_code   := -20901;
            o_return_message   :=
                   'Inventory: Unkown group_code and brand: ['
                || p_site_id
                || '].';
            raise_application_error (-20901, o_return_message);
        END IF;

        -- Clear records' consumed date
        UPDATE xxdo.xxdoec_inventory
           SET consumed_date_ca   = NULL
         WHERE     NOT consumed_date_ca IS NULL
               AND erp_org_id = v_erp_org_id
               AND brand = v_brand;

        COMMIT;
    END xxdoec_reset_inventory_ca;

    /*
        xxdoec_get_reset_inventory_set_ca
        Reset the consumed_date for all records with the give consumed_date
        Used for cases when we need to restart
    */
    PROCEDURE xxdoec_reset_inventory_set_ca (p_consumed_date DATE)
    IS
    BEGIN
        -- Clear records' consumed date
        UPDATE xxdo.xxdoec_inventory
           SET consumed_date_ca   = NULL
         WHERE consumed_date_ca = p_consumed_date;

        COMMIT;
    END xxdoec_reset_inventory_set_ca;


    --------------------------------------------------------------------------------
    -- Start of Changes by BT Technology Team 11Mar2015    V1.1
    --------------------------------------------------------------------------------

    /* net_qty_crs
        Returns a cursor on Supply  salesOrder datarows (itemID, invOrgID, brand, quantity, date), using the given feed_code and date
    */
    FUNCTION net_qty_crs (p_feed_code   IN VARCHAR2,
                          p_date        IN DATE DEFAULT NULL)
        RETURN SYS_REFCURSOR
    IS
        v_cursor        SYS_REFCURSOR;
        v_next_bizday   DATE;
    BEGIN
        NULL;
    /* Commented by BT Team
          v_next_bizday := NVL (p_date, XXDOEC_INV_UTILS.NEXT_CALENDAR_DATE);

          OPEN v_cursor FOR
               SELECT -- note:  the order of these columns must match the record, trec_quantity
                     quantities.inventory_item_id,
                      quantities.organization_id,
                      SUBSTR (inv_org_brand_items.brand_name, 1, 64) brand_name,
                      SUM (quantities.qty) qty,
                      mcd_sd.calendar_date AS qty_date
                 FROM (SELECT xicv.inv_org_id,
                              xicv.brand_name,
                              mic.inventory_item_id
                         FROM apps.mtl_categories_b mcb,
                              apps.mtl_item_categories mic,
                              (SELECT DISTINCT inv_org_id, brand_name
                                 FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                                WHERE code = p_feed_code) xicv
                        WHERE     mcb.segment1 = xicv.brand_name
                              -- AND mic.category_set_id = 1    commented by BT Tech team
                              AND mic.category_set_id IN
                                     (SELECT CATEGORY_SET_ID
                                        FROM mtl_category_sets
                                       WHERE CATEGORY_SET_NAME = 'Inventory') -- added by BT Tech team
                              AND mic.category_id = mcb.category_id
                              AND mic.organization_id = xicv.inv_org_id) inv_org_brand_items,
                      (SELECT organization_id,
                              inventory_item_id,
                              TRUNC (GREATEST (day, v_next_bizday)) AS qty_date,
                              qty
                         FROM do_atp_supply_v
                       UNION ALL
                       SELECT organization_id,
                              inventory_item_id,
                              TRUNC (GREATEST (day, v_next_bizday)) AS qty_date,
                              qty
                         FROM do_atp_sales_order_v -- note: view returns NEGATIVE qty
                                                  ) quantities,
                      msc_calendar_dates mcd_sd,
                      msc_calendar_dates mcd_sd1,
                      msc_system_items msci
                WHERE     msci.sr_instance_id = 1
                      AND msci.plan_id = -1
                      AND msci.organization_id = quantities.organization_id
                      AND msci.inventory_item_id = quantities.inventory_item_id
                      AND mcd_sd.sr_instance_id = 1
                      AND mcd_sd.calendar_date = TRUNC (quantities.qty_date)
                      AND mcd_sd.calendar_code = 'DEK:US 2000-30'
                      AND mcd_sd.exception_set_id = -1
                      AND mcd_sd1.sr_instance_id = 1
                      AND mcd_sd1.calendar_date = TRUNC (v_next_bizday)
                      AND mcd_sd1.calendar_code = 'DEK:US 2000-30'
                      AND mcd_sd1.exception_set_id = -1
                      AND mcd_sd.next_seq_num <
                               mcd_sd1.next_seq_num
                             + NVL (msci.cumulative_total_lead_time, 9999)
                      AND inv_org_brand_items.inv_org_id = msci.organization_id
                      AND inv_org_brand_items.inventory_item_id =
                             msci.sr_inventory_item_id
             --and quantities.inventory_item_id = 326890
             -- throttle back result set because MTO can't handle any volume
             --and msci.sr_inventory_item_id  in (3058117,3058116,3058115,3058114,3058119,3058129,3058128,3058127,3058130,3058126,3058131,3058135,3058134,3058133,3058136,3058132,3058137,3058231,3058230,3058229,3058232)   -- xxxxx
             GROUP BY quantities.organization_id,
                      inv_org_brand_items.brand_name,
                      quantities.inventory_item_id,
                      mcd_sd.calendar_date
             ORDER BY quantities.organization_id,
                      inv_org_brand_items.brand_name,
                      quantities.inventory_item_id,
                      mcd_sd.calendar_date;

          RETURN v_cursor;
    */
    END net_qty_crs;

    /* net_qty_tbl
        Returns a collection, created from a cursor on Supply salesOrder datarows (itemID, invOrgID, brand, quantity, date), using the given feed_code and date
    */

    FUNCTION net_qty_tbl (p_feed_code   IN VARCHAR2,
                          p_date        IN DATE DEFAULT NULL)
        RETURN ttbl_quantity
    IS
        v_cursor   SYS_REFCURSOR;
        v_table    ttbl_quantity;
    BEGIN
        v_cursor   := net_qty_crs (p_feed_code, p_date);

        FETCH v_cursor BULK COLLECT INTO v_table;

        --dbms_output.put_line('> Qty Table Count: ' || v_table.COUNT);
        RETURN v_table;
    END net_qty_tbl;

    /* net_qty_atbl
        Returns an associative array, created from a collection of Supply  salesOrder datarows (itemID, invOrgID, brand, quantity, date), using the given feed_code and date
    */
    FUNCTION net_qty_atbl (p_feed_code   IN VARCHAR2,
                           p_date        IN DATE DEFAULT NULL)
        RETURN tatbl_inv_org
    IS
        v_table        ttbl_quantity;
        v_quantities   tatbl_inv_org;
        v_numdate      NUMBER := g_default_num;
    BEGIN
        v_table   := net_qty_tbl (p_feed_code, p_date);

        FOR n IN v_table.FIRST .. v_table.LAST
        LOOP
            v_numdate   :=
                xxdoec_inv_utils.TO_NUMBER (v_table (n).quantity_date);
            v_quantities (v_table (n).inv_org_id) (v_table (n).brand) (
                v_table (n).inv_item_id) (v_numdate)   :=
                v_table (n).quantity;
        END LOOP;

        --dbms_output.put_line('> Qty aTable Count: ' || v_quantities.COUNT);

        RETURN v_quantities;
    END net_qty_atbl;

    /* kco_qty_crs
        Returns a cursor on KCO datarows (itemID, invOrgID, quantity, date), using the given feed_code and date
    */
    FUNCTION kco_qty_crs (p_feed_code   IN VARCHAR2,
                          p_date        IN DATE DEFAULT NULL)
        RETURN SYS_REFCURSOR
    IS
        v_cursor        SYS_REFCURSOR;
        v_next_bizday   DATE;
    BEGIN
        v_next_bizday   := NVL (p_date, XXDOEC_INV_UTILS.NEXT_CALENDAR_DATE);

        OPEN v_cursor FOR
              SELECT kco_header_id, organization_id           -- inventory org
                                                   , inventory_item_id,
                     day, SUM (qty)
                FROM (  SELECT dkh.kco_header_id, dkl.organization_id, msci.inventory_item_id,
                               TRUNC (GREATEST (dkl.kco_schedule_date, v_next_bizday)) AS day, dkl.scheduled_quantity AS qty
                          FROM apps.msc_system_items msci, do_kco.do_kco_header dkh, do_kco.do_kco_line dkl
                         WHERE     dkl.enabled_flag = 1
                               -- throttle back result set because MTO can't handle any volume
                               -- and dkl.inventory_item_id  in (3058117,3058116,3058115,3058114,3058119,3058129,3058128,3058127,3058130,3058126,3058131,3058135,3058134,3058133,3058136,3058132,3058137,3058231,3058230,3058229,3058232)   -- xxxxx
                               AND dkl.open_flag = 1
                               AND dkl.atp_flag = 1
                               AND dkl.scheduled_quantity > 0
                               AND dkh.kco_header_id = dkl.kco_header_id
                               AND dkh.enabled_flag = 1
                               AND dkh.open_flag = 1
                               AND dkh.atp_flag = 1
                               AND msci.plan_id = -1
                               AND msci.sr_instance_id = 1
                               AND msci.organization_id = dkl.organization_id
                               AND msci.sr_inventory_item_id =
                                   dkl.inventory_item_id
                               -- assume feed is for ONE WAREHOUSE,
                               -- collect all KCO's for that warehouse/brands
                               --and dkh.org_id in (select distinct erp_org_id from XXDO.XXDOEC_INV_FEED_CONFIG_V where code = p_feed_code)
                               AND dkl.organization_id IN
                                       (SELECT DISTINCT inv_org_id
                                          FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                                         WHERE code = p_feed_code)
                               AND dkh.brand IN
                                       (SELECT DISTINCT (brand_name)
                                          FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                                         WHERE code = p_feed_code)
                      ORDER BY dkh.kco_header_id, msci.inventory_item_id, dkl.kco_schedule_date)
            GROUP BY kco_header_id, organization_id, inventory_item_id,
                     day;

        RETURN v_cursor;
    END kco_qty_crs;

    /* kco_qty_tbl
        Returns a collection, created from a cursor on KCO datarows (itemID, invOrgID, quantity, date), using the given feed_code and date
    */

    FUNCTION kco_qty_tbl (p_feed_code   IN VARCHAR2,
                          p_date        IN DATE DEFAULT NULL)
        RETURN ttbl_kco_quantity
    IS
        v_cursor   SYS_REFCURSOR;
        v_table    ttbl_kco_quantity;
    BEGIN
        v_cursor   := kco_qty_crs (p_feed_code, p_date);

        FETCH v_cursor BULK COLLECT INTO v_table;

        --dbms_output.put_line('> KCO Table Count: ' || v_table.COUNT);
        RETURN v_table;
    END kco_qty_tbl;


    /* kco_qty_atbl
        Returns an associative array, created from a collection of KCO datarows (itemID, invOrgID, quantity, date), using the given feed_code and date
    */

    FUNCTION kco_qty_atbl (p_feed_code   IN VARCHAR2,
                           p_date        IN DATE DEFAULT NULL)
        RETURN tatbl_int4
    IS
        v_table            ttbl_kco_quantity;
        v_kco_quantities   tatbl_int4;
        v_numdate          NUMBER := g_default_num;
    BEGIN
        v_table   := kco_qty_tbl (p_feed_code, p_date);

        IF v_table.COUNT > 0
        THEN
            FOR n IN v_table.FIRST .. v_table.LAST
            LOOP
                v_numdate   :=
                    xxdoec_inv_utils.TO_NUMBER (v_table (n).inv_date);
                v_kco_quantities (v_table (n).inv_org_id) (
                    v_table (n).inv_item_id) (v_numdate) (
                    v_table (n).kco_hdr_id)   :=
                    v_table (n).quantity;
            END LOOP;
        END IF;

        --dbms_output.put_line('> KCO aTable Count: ' || v_kco_quantities.COUNT);

        RETURN v_kco_quantities;
    END kco_qty_atbl;

    /* items_crs
        Returns a cursor on item catalog data for the given feed_code
    */
    FUNCTION items_crs (p_feed_code IN VARCHAR2)
        RETURN SYS_REFCURSOR
    IS
        v_cursor        SYS_REFCURSOR;
        v_next_bizday   DATE;
    BEGIN
        /* Commented by BT Team on 15-May
              OPEN v_cursor FOR
                 SELECT -- note:  the order of these columns must match the record, item_t
                       msci.inventory_item_id,
                        msci.sr_inventory_item_id --, substr(trim(msib.segment1) || '-' || trim(msib.segment2) || '-' || trim(msib.segment3), 1, 64) sku           -- commented by BT Tech team
                                                 ,
                        SUBSTR (
                              TRIM (msib.style_number)
                           || '-'
                           || TRIM (msib.color_code)
                           || '-'
                           || TRIM (msib.item_size),
                           1,
                           64)
                           sku                                -- added by BT Tech team
                              --, trim(msib.attribute11) upc                -- commented by BT Tech team
                        ,
                        msib.upc_code upc                     -- added by BT Tech team
                                         --, CAST(NVL(msib.attribute7, -1) AS NUMBER) stock_buffer            -- commented by BT Tech team
                        ,
                        msib.inv_buffer                       -- added by BT Tech team
                                       --, DECODE(msib.attribute8, 'Y', 1, 0) preorder                        -- commented by BT Tech team
                        ,
                        msib.inv_preorder                     -- added by BT Tech team
                   FROM DO_ATP_ITEM_ORGANIZATIONS_MV daiom,
                        msc_system_items msci --, mtl_system_items_b msib                        -- commented by BT Tech team
                                             ,
                        xxd_common_items_v msib               -- added by BT Tech team
                                               ,
                        (SELECT DISTINCT erp_org_id, inv_org_id
                           FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                          WHERE code = p_feed_code) xicv
                  WHERE                         -- msci.inventory_item_id = 268144 and
                            -- throttle back result set because MTO can't handle any volume
                            --msci.sr_inventory_item_id  in (3058117,3058116,3058115,3058114,3058119,3058129,3058128,3058127,3058130,3058126,3058131,3058135,3058134,3058133,3058136,3058132,3058137,3058231,3058230,3058229,3058232) and   -- xxxxx
                            msci.sr_instance_id = 1
                        AND msci.plan_id = -1
                        AND msci.organization_id = xicv.inv_org_id
                        AND msib.organization_id = msci.organization_id
                        AND msib.inventory_item_id = msci.sr_inventory_item_id
                        AND daiom.org_id = xicv.erp_org_id
                        AND daiom.item_org_purpose = 'ORDER'
                        AND daiom.warehouse_id = msci.organization_id
                        AND daiom.inventory_item_id = msci.sr_inventory_item_id
                        --AND msib.attribute11 is not null                        -- commented by BT Tech team
                        AND msib.upc_code IS NOT NULL         -- added by BT Tech team
                        --AND length(msib.attribute11)  <= 12                     -- commented by BT Tech team
                        AND LENGTH (msib.upc_code) <= 12      -- added by BT Tech team
                        AND DAIOM.ORG_ID IN (SELECT DISTINCT erp_org_id
                                               FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                                              WHERE code = p_feed_code)
                        AND DAIOM.WAREHOUSE_ID IN (SELECT DISTINCT inv_org_id
                                                     FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                                                    WHERE code = p_feed_code);

        */
        RETURN v_cursor;
    --EXCEPTION
    --WHEN OTHERS THEN
    --dbms_output.put_line( 'An exception occurred while updating ATP records.  The exception was: ' || SQLERRM);

    END items_crs;



    /* items_tbl
        Returns a colllection, created from a cursor on item catalog data for the given feed_code
    */
    FUNCTION items_tbl (p_feed_code IN VARCHAR2)
        RETURN ttbl_item
    IS
        v_cursor   SYS_REFCURSOR;
        v_table    ttbl_item;
    BEGIN
        v_cursor   := items_crs (p_feed_code);

        FETCH v_cursor BULK COLLECT INTO v_table;

        --dbms_output.put_line('> Item Table Count: ' || v_table.COUNT);
        RETURN v_table;
    END items_tbl;

    /* items_atbl
        Returns an associative array, created from a colllection of item catalog data for the given feed_code
    */
    FUNCTION items_atbl (p_feed_code IN VARCHAR2)
        RETURN tatbl_item
    IS
        v_table   ttbl_item;
        v_items   tatbl_item;
        v_item    item_t;
    BEGIN
        v_table   := items_tbl (p_feed_code);

        IF v_table.COUNT > 0
        THEN
            FOR n IN v_table.FIRST .. v_table.LAST
            LOOP
                v_items (v_table (n).inventory_item_id)   := v_table (n);
            END LOOP;
        END IF;

        --dbms_output.put_line('> Item aTable Count: ' || v_items.COUNT);
        RETURN v_items;
    END items_atbl;

    /* get_kco_quantity
            Returns the sum of KCO all quantities for the given item and date, excluding those for the given KCO ID.
    */
    FUNCTION get_kco_quantity (p_kco_quantities IN tatbl_int4, p_inv_org_id IN NUMBER, p_item_id IN NUMBER
                               , p_numdate IN NUMBER, p_kco_hdr_id IN NUMBER)
        RETURN NUMBER
    IS
        v_qty   NUMBER := 0;
        v_kco   NUMBER;
    BEGIN
        IF (p_kco_quantities.EXISTS (p_inv_org_id) AND p_kco_quantities (p_inv_org_id).EXISTS (p_item_id) AND p_kco_quantities (p_inv_org_id) (p_item_id).EXISTS (p_numdate))
        THEN
            v_kco   :=
                p_kco_quantities (p_inv_org_id) (p_item_id) (p_numdate).FIRST;

            WHILE v_kco IS NOT NULL
            LOOP
                IF v_kco <> NVL (p_kco_hdr_id, -1)
                THEN
                    v_qty   :=
                          v_qty
                        + p_kco_quantities (p_inv_org_id) (p_item_id) (
                              p_numdate) (v_kco);
                END IF;

                v_kco   :=
                    p_kco_quantities (p_inv_org_id) (p_item_id) (p_numdate).NEXT (
                        v_kco);
            END LOOP;
        END IF;

        RETURN v_qty;
    END get_kco_quantity;


    /* get_kco_remaining_quantity
            Returns the sum of quantities (remaining) for the given KCO and item on and after the given date.
    */
    FUNCTION get_kco_remaining_quantity (p_kco_quantities   IN tatbl_int4,
                                         p_inv_org_id       IN NUMBER,
                                         p_item_id          IN NUMBER,
                                         p_numdate          IN NUMBER,
                                         p_kco_hdr_id       IN NUMBER)
        RETURN NUMBER
    IS
        v_qty    NUMBER := 0;
        v_kco    NUMBER;
        v_date   NUMBER;
    BEGIN
        IF (p_kco_hdr_id = NULL)
        THEN
            RETURN 0;
        ELSE
            IF (p_kco_quantities.EXISTS (p_inv_org_id) AND p_kco_quantities (p_inv_org_id).EXISTS (p_item_id))
            THEN
                -- loop over dates for the given item
                v_date   := p_kco_quantities (p_inv_org_id) (p_item_id).FIRST;

                WHILE v_date IS NOT NULL
                LOOP
                    IF (v_date >= p_numdate)
                    THEN
                        -- loop over KCOs on this date
                        v_kco   :=
                            p_kco_quantities (p_inv_org_id) (p_item_id) (
                                v_date).FIRST;

                        WHILE v_kco IS NOT NULL
                        LOOP
                            IF v_kco = NVL (p_kco_hdr_id, -1)
                            THEN
                                v_qty   :=
                                      v_qty
                                    + p_kco_quantities (p_inv_org_id) (
                                          p_item_id) (v_date) (v_kco);
                            END IF;

                            v_kco   :=
                                p_kco_quantities (p_inv_org_id) (p_item_id) (
                                    v_date).NEXT (v_kco);
                        END LOOP;
                    END IF;

                    v_date   :=
                        p_kco_quantities (p_inv_org_id) (p_item_id).NEXT (
                            v_date);
                END LOOP;
            END IF;

            RETURN v_qty;
        END IF;
    END get_kco_remaining_quantity;

    /* next_numdate
             Return the next smallest numdate from the two associative arrays provided
             Handles the fact that an item may not be in both arrays.
    */
    FUNCTION next_numdate (p_kco_quantities   IN tatbl_int4,
                           p_net_quantities   IN tatbl_inv_org,
                           p_inv_org_id       IN NUMBER,
                           p_brand            IN VARCHAR2,
                           p_item             IN NUMBER,
                           p_numdate          IN NUMBER)
        RETURN NUMBER
    IS
        v_kco_numdate   NUMBER := NULL;
        v_net_numdate   NUMBER := NULL;
    BEGIN
        IF     p_kco_quantities.EXISTS (p_inv_org_id)
           AND p_kco_quantities (p_inv_org_id).EXISTS (p_item)
        THEN
            v_kco_numdate   :=
                p_kco_quantities (p_inv_org_id) (p_item).NEXT (p_numdate);
        END IF;

        IF p_net_quantities (p_inv_org_id) (p_brand).EXISTS (p_item)
        THEN
            v_net_numdate   :=
                p_net_quantities (p_inv_org_id) (p_brand) (p_item).NEXT (
                    p_numdate);
        END IF;

        RETURN apps.XXDOEC_INV_UTILS.least_not_null (v_kco_numdate,
                                                     v_net_numdate);
    END next_numdate;

    ---------------------------------------------------------------------------------
    -- End of Changes by BT Technology Team 11Mar2015    V1.1
    --------------------------------------------------------------------------------

    /* process_supply_demand

    */
    PROCEDURE process_supply_demand (p_kco_quantities IN tatbl_int4, p_net_quantities IN tatbl_inv_org, p_inv_org_id IN NUMBER, p_brand IN VARCHAR2, p_kco_hdr NUMBER, p_item IN NUMBER, p_sr_item IN NUMBER, p_nextbizday IN DATE, p_demand IN NUMBER DEFAULT 0
                                     , p_atp IN OUT NUMBER, p_na_qty OUT NUMBER, p_na_date OUT DATE)
    IS
        v_num_nextbizday   NUMBER;
        v_numdate          NUMBER := 0;
        v_qty_running      NUMBER := 0;
        v_atp_qty          NUMBER := NULL; -- ATP reported will always be equal or less than today's onhand quantity
        v_nad_day          NUMBER := NULL;
        v_nad_onhand       NUMBER := NULL;
    --v_rec APPS.XXDOEC_TEST_INV_CALC%rowtype;  -- helpful for debugging
    BEGIN
        -- calculate the current and next available ATP for the item
        -- by combiining net and kco quantities but excluding default kco
        v_num_nextbizday   := xxdoec_inv_utils.TO_NUMBER (p_nextbizday);
        v_qty_running      := v_qty_running - p_demand; -- start with "today's" qty AND subtract the given ATP (to simulate a demand)

        -- simultaneously: loop over date indexes from both v_quantities and kco_qty_atbl
        v_numdate          :=
            next_numdate (p_kco_quantities, p_net_quantities, p_inv_org_id,
                          p_brand, p_item, 0);

        WHILE v_numdate IS NOT NULL
        LOOP
            -- running count: subtract KCO quantity
            v_qty_running   :=
                  v_qty_running
                - get_kco_quantity (p_kco_quantities, p_inv_org_id, p_item,
                                    v_numdate, p_kco_hdr);

            -- running count: add Planned and SalesOrder quantity (values are negative for SalesOrder quantities)
            IF p_net_quantities (p_inv_org_id) (p_brand) (p_item).EXISTS (
                   v_numdate)
            THEN
                v_qty_running   :=
                      v_qty_running
                    + p_net_quantities (p_inv_org_id) (p_brand) (p_item) (
                          v_numdate);
            END IF;

            IF v_atp_qty IS NULL
            THEN
                -- initialization:
                IF v_numdate > v_num_nextbizday AND v_qty_running >= 0
                THEN
                    v_atp_qty   := 0; -- start with zero when first date is in the future
                ELSE
                    v_atp_qty   := v_qty_running;
                END IF;
            ELSE
                v_atp_qty   := LEAST (v_atp_qty, v_qty_running); -- lower onhand to reflect demand
            END IF;

            -- pre_back_order watch: remember the date and count onhand from when the running count turned positive
            IF     v_qty_running > 0
               AND v_nad_day IS NULL
               AND v_numdate > v_num_nextbizday
            THEN
                -- initialize with today's date/qty
                v_nad_day      := v_numdate;
                v_nad_onhand   := v_qty_running;
            ELSIF v_qty_running <= 0
            THEN
                v_nad_day      := NULL; -- demand has exceeded supply, so reset
                v_nad_onhand   := 0;
            ELSIF v_nad_day IS NOT NULL
            THEN
                v_nad_onhand   := LEAST (v_nad_onhand, v_qty_running);
            END IF;

            --v_rec.source_pk := 'Refactor'; v_rec.inv_org := p_inv_org_id; v_rec.brand := p_brand; v_rec.item_id := p_item; v_rec.sr_item_id := p_sr_item;
            --v_rec.delta_day := to_date(v_numdate, 'yyyymmdd'); v_rec.delta_qty := null; v_rec.sum_qty := v_qty_running; v_rec.atp_qty := v_atp_qty; v_rec.next_date := to_date(v_nad_day, 'yyyymmdd'); v_rec.next_qty := v_nad_onhand;  v_rec.atp_offset := p_demand;
            --insert into APPS.XXDOEC_TEST_INV_CALC values v_rec;
            --dbms_output.put_line(p_inv_org_id || ',' || p_item || ' ,' ||  to_date(v_numdate, 'yyyymmdd') || ' ,' || '0' ||  ',' || v_qty_running ||  ',' || v_atp_qty  ||  ',' || to_date(v_nad_day, 'yyyymmdd') ||  ',' ||  v_nad_onhand  );
            v_numdate   :=
                next_numdate (p_kco_quantities, p_net_quantities, p_inv_org_id
                              , p_brand, p_item, v_numdate);
        END LOOP;                          -- WHILE v_numdate IS NOT NULL LOOP

        IF p_demand = 0
        THEN
            p_atp   := v_atp_qty; -- only set ATP when no demand is being simulated
        END IF;

        p_na_qty           := v_nad_onhand;
        p_na_date          := TO_DATE (v_nad_day, 'yyyymmdd');
    --EXCEPTION
    --   WHEN OTHERS THEN
    --DBMS_OUTPUT.PUT_LINE (DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);

    END process_supply_demand;

    PROCEDURE log_atp_analysis (batchTimeString IN VARCHAR2)
    IS
        v_logval   NUMBER;
        DCDLog     apps.DCDLog_type
            := apps.DCDLog_type (
                   P_CODE           => DCDLogCodes.MetInventorySourceAnalysis,
                   P_APPLICATION    => G_APPLICATION,
                   P_LOGEVENTTYPE   => 4);

        CURSOR atp_query IS
              SELECT feed_code,
                     brand,
                     erp_org_id,
                     inv_org_id,
                     COUNT (1) AS COUNT,
                     COUNT (CASE
                                WHEN atp_qty > 0 THEN 1
                            END) AS positive,
                       COUNT (CASE
                                  WHEN atp_qty > 0 THEN 1
                              END)
                     / COUNT (1) AS percent_positive,
                     COUNT (CASE
                                WHEN atp_qty = 0 THEN 1
                            END) AS zero,
                       COUNT (CASE
                                  WHEN atp_qty = 0 THEN 1
                              END)
                     / COUNT (1) AS percent_zero,
                     COUNT (CASE
                                WHEN atp_qty < 0 THEN 1
                            END) AS negative,
                       COUNT (CASE
                                  WHEN atp_qty < 0 THEN 1
                              END)
                     / COUNT (1) AS percent_negative,
                     COUNT (CASE
                                WHEN atp_qty = 0 AND atp_when_atr > 0 THEN 1
                            END) AS zero_atr,
                       COUNT (CASE
                                  WHEN atp_qty = 0 AND atp_when_atr > 0 THEN 1
                              END)
                     / COUNT (1) AS percent_zero_atr
                FROM xxdo.xxdoec_inventory
               WHERE inv_org_id <> 632              -- 632 excludes gift cards
            GROUP BY erp_org_id, inv_org_id, brand,
                     feed_code
            ORDER BY feed_code, brand DESC;
    BEGIN
        FOR rec IN atp_query
        LOOP
            -- log ATP Analysisi (metric)
            DCDLog.ChangeCode (
                P_CODE           => DCDLogCodes.MetInventorySourceAnalysis,
                P_APPLICATION    => G_APPLICATION,
                P_LOGEVENTTYPE   => 4);
            DCDLog.AddParameter ('BatchTime', batchTimeString, 'VARCHAR2');
            DCDLog.AddParameter ('FeedCode', rec.feed_code, 'VARCHAR2');
            DCDLog.AddParameter ('Brand', rec.brand, 'VARCHAR2');
            DCDLog.AddParameter ('ErpOrgID', rec.erp_org_id, 'NUMBER');
            DCDLog.AddParameter ('InvOrgID', rec.inv_org_id, 'NUMBER');
            DCDLog.AddParameter ('Count', rec.COUNT, 'VARCHAR2');
            DCDLog.AddParameter ('PositiveATP', rec.positive, 'VARCHAR2');
            DCDLog.AddParameter ('PercentPositiveATP',
                                 TO_CHAR (rec.percent_positive, '0.999'),
                                 'VARCHAR2');
            DCDLog.AddParameter ('ZeroATP', rec.zero, 'VARCHAR2');
            DCDLog.AddParameter ('PercentZeroATP',
                                 TO_CHAR (rec.percent_zero, '0.999'),
                                 'VARCHAR2');
            DCDLog.AddParameter ('NegativeATP', rec.negative, 'VARCHAR2');
            DCDLog.AddParameter ('PercentNegativeATP',
                                 TO_CHAR (rec.percent_negative, '0.999'),
                                 'VARCHAR2');
            DCDLog.AddParameter ('ZeroATR', rec.zero_atr, 'VARCHAR2');
            DCDLog.AddParameter ('PercentZeroATR',
                                 TO_CHAR (rec.percent_zero_atr, '0.999'),
                                 'VARCHAR2');
            v_logval   := DCDLog.LogInsert ();
        END LOOP;
    END log_atp_analysis;

    -- 1.0 changes start
    --Procedure to generate the data file and send to DOMS SFTP along with retaining the current process of populating XXDOEC_INVENTORY table
    PROCEDURE xxdoec_generate_data_file (
        p_errbuf          OUT VARCHAR2,
        p_retcode         OUT NUMBER,
        p_feed_code    IN     VARCHAR2 DEFAULT NULL,
        p_net_change   IN     VARCHAR2 DEFAULT 'Y')
    IS
        CURSOR fetch_inv_org_cur (p_file_type IN VARCHAR2)
        IS
            SELECT DISTINCT xxi.inv_org_id, xxi.feed_code
              FROM xxdo.xxdoec_inventory xxi
             WHERE     xxi.feed_code = NVL (p_feed_code, xxi.feed_code)
                   AND xxi.filetype = p_file_type;



        CURSOR fetch_eligible_records (p_inv_org_id IN NUMBER, p_file_type IN VARCHAR2, p_feed_code IN VARCHAR2)
        IS
            SELECT xxi.inv_org_id, xxi.feed_code, xxi.brand,
                   xxi.sku, xxi.upc, xxi.atp_qty,
                   xxi.atp_date, xxi.atp_buffer, xxi.pre_back_order_mode,
                   xxi.pre_back_order_qty, xxi.pre_back_order_date, xxi.is_perpetual,
                   xxi.filetype
              FROM xxdo.xxdoec_inventory xxi
             WHERE     xxi.inv_org_id = p_inv_org_id
                   AND xxi.filetype = p_file_type
                   AND xxi.feed_code = p_feed_code;

        l_file_type          VARCHAR2 (100);
        lv_inst_name         VARCHAR2 (30) := NULL;
        lv_msg               VARCHAR2 (4000) := NULL;
        lv_file_name         VARCHAR2 (200);
        v_file_handle        UTL_FILE.file_type;
        v_file_handle1       UTL_FILE.file_type;
        v_string             VARCHAR2 (4000);
        lv_path              VARCHAR2 (1000);
        lv_file_dir          VARCHAR2 (1000) := 'XXD_ONT_INV_FEED';
        ln_org_count         NUMBER := 0;
        l_org_record_count   NUMBER := 0;
        lv_org_code          VARCHAR2 (10);
    BEGIN
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Deckers Inventory File Generation for WTF Web Service Program STarts here......');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            '*******************************************************************************');
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Program Parameters:');
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'p_feed_code:' || p_feed_code);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'p_net_change:' || p_net_change);

        IF NVL (p_net_change, 'Y') = 'Y'
        THEN
            l_file_type   := 'UPDATE';
        ELSIF NVL (p_net_change, 'Y') = 'N'
        THEN
            l_file_type   := 'REPLACE';
        END IF;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'l_file_type:' || l_file_type);

        -- query to fetch instance name
        BEGIN
            SELECT applications_system_name
              INTO lv_inst_name
              FROM fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inst_name   := '';
                lv_msg         :=
                       'Error getting the instance name in send_email_proc procedure. Error is '
                    || SQLERRM;
                raise_application_error (-20010, lv_msg);
        END;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'lv_inst_name:' || lv_inst_name);

        -- query to fetch directory path
        BEGIN
            SELECT directory_path
              INTO lv_path
              FROM dba_directories
             WHERE directory_name = lv_file_dir;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No Data Found While Getting The Path, Directory might not exist');
                fnd_file.put_line (fnd_file.LOG, 'Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error Message :' || SQLERRM);
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'No Data Found While Getting The Path, Directory might not exist');
                fnd_file.put_line (fnd_file.LOG, 'Error Code :' || SQLCODE);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error Message :' || SQLERRM);
        END;

        FOR i IN fetch_inv_org_cur (l_file_type)
        LOOP
            ln_org_count   := ln_org_count + 1;

            --Query to get inventory org code
            BEGIN
                SELECT organization_code
                  INTO lv_org_code
                  FROM org_organization_definitions
                 WHERE organization_id = i.inv_org_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_org_code   := NULL;
            END;

            -- query to derive file name
            BEGIN
                SELECT 'INVENTORY-LIST' || '_' || l_file_type || '_' || lv_org_code || '_' || lv_inst_name || '_' || TO_CHAR (SYSDATE, 'YYYYMMDDHHMISS') || '.csv'
                  INTO lv_file_name
                  FROM DUAL;

                fnd_file.put_line (fnd_file.LOG, 'File Name' || lv_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_file_name   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to derive file Name' || SQLERRM);
            END;

            -- open file to write the data
            BEGIN
                v_file_handle   :=
                    UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W');
                v_string   :=
                       'INV_ORG'
                    || ','
                    || 'FEED_CODE'
                    || ','
                    || 'BRAND'
                    || ','
                    || 'SKU'
                    || ','
                    || 'UPC'
                    || ','
                    || 'ATP_QTY'
                    || ','
                    || 'ATP_DATE'
                    || ','
                    || 'ATP_BUFFER'
                    || ','
                    || 'PRE_BACK_ORDER_MODE'
                    || ','
                    || 'PRE_BACK_ORDER_QTY'
                    || ','
                    || 'PRE_BACK_ORDER_DATE'
                    || ','
                    || 'IS_PERPETUAL'
                    || ','
                    || 'FILETYPE';
                UTL_FILE.put_line (v_file_handle, v_string);

                FOR j
                    IN fetch_eligible_records (i.inv_org_id,
                                               l_file_type,
                                               i.feed_code)
                LOOP
                    v_string   := NULL;
                    v_string   :=
                           lv_org_code
                        || ','
                        || j.FEED_CODE
                        || ','
                        || j.BRAND
                        || ','
                        || j.SKU
                        || ','
                        || j.UPC
                        || ','
                        || j.ATP_QTY
                        || ','
                        || j.ATP_DATE
                        || ','
                        || j.ATP_BUFFER
                        || ','
                        || j.PRE_BACK_ORDER_MODE
                        || ','
                        || j.PRE_BACK_ORDER_QTY
                        || ','
                        || j.PRE_BACK_ORDER_DATE
                        || ','
                        || j.IS_PERPETUAL
                        || ','
                        || j.FILETYPE;
                    UTL_FILE.put_line (v_file_handle, v_string);
                END LOOP;

                UTL_FILE.fclose (v_file_handle);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Successfully generated File for org:' || i.inv_org_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    IF UTL_FILE.is_open (v_file_handle)
                    THEN
                        UTL_FILE.fclose (v_file_handle);
                    END IF;
            END;

            IF l_file_type = 'UPDATE'
            THEN
                -- Update statement to restrict the transfer of duplication file
                BEGIN
                    UPDATE xxdo.xxdoec_inventory
                       SET filetype   = 'SENT'
                     WHERE     inv_org_id = i.inv_org_id
                           AND filetype = l_file_type;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'Failed to update xxdoec_inventory table:'
                            || SQLERRM);
                END;
            END IF;
        END LOOP;


        v_file_handle1   :=
            UTL_FILE.fopen (lv_file_dir, 'inv_feed_ctl.txt', 'W');
        UTL_FILE.put_line (v_file_handle1, 'READY');
        UTL_FILE.fclose (v_file_handle1);

        IF ln_org_count = 0
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'There is no eligible record to generate the files');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Failed to generate the file' || SQLERRM);
    END xxdoec_generate_data_file;

    -- 1.0 changes end

    /* net_tables_init
         A process to update inventory numbers for a given feed_code
    */
    PROCEDURE xxdoec_update_atp_table (x_ret_status OUT VARCHAR2, x_retcode OUT NUMBER, p_feed_code IN VARCHAR2 DEFAULT NULL
                                       , p_net_change IN VARCHAR2 DEFAULT 'Y', p_generate_control_file IN VARCHAR2 DEFAULT 'N')
    IS
        v_batchdate              DATE;
        v_batchdate_string       VARCHAR2 (64);
        v_nextbizday             DATE;
        v_quantities             tatbl_inv_org;          -- supply/demand data
        v_kco_quantities         tatbl_int4;                       -- kco data
        v_items                  tatbl_item;                   -- catalog data
        v_item                   NUMBER;                              -- index
        v_atr                    NUMBER;
        v_num                    NUMBER;
        v_date                   DATE;
        v_pdp_status             VARCHAR (128);
        v_feed_results           VARCHAR2 (8192);
        v_codes                  ttbl_code := ttbl_code ();
        v_atp                    atp_t2 := atp_t2 ();
        v_start_time             DATE;
        v_feed_start_time        DATE;
        v_source_start_time      DATE;
        v_modify_start_time      DATE;
        v_end_time               DATE;
        v_logval                 NUMBER := 0;
        ex_full_pdp_running      EXCEPTION;
        ex_full_pdp_error        EXCEPTION;
        ln_stock_buffer          NUMBER;                              --by NRK
        ln_atp_buffer            NUMBER;                              --by NRK
        ln_pre_back_order_mode   NUMBER;                              --by NRK
        lv_upc_code              VARCHAR2 (30);                       --by NRK
        ln_inv_preorder          NUMBER;                              --BY NRK
        ln_pre_back_order_qty    NUMBER;                              --BY nrk
        ld_back_order_date       DATE;                                --BY nrk
        lv_sku                   VARCHAR2 (50);                       --by NRK
        ln_atp_when_atr          NUMBER;                              --by NRK
        ln_atp                   NUMBER;                              --by NRK
        ln_atr                   NUMBER;                              --by NRK
        ln_cnt                   NUMBER := 0;                         --by NRK
        ln_cnt_dt                NUMBER := 0;
        ld_available_date        DATE;
        lv_errbuf                VARCHAR2 (4000);                       -- 1.0
        ln_retcode               NUMBER;                                 --1.0
        l_request_id             NUMBER := 0;

        -- CURSOR         v_inv_configs (p_feed_code VARCHAR2) IS
        CURSOR inv_feed_config_cur (p_feed_code VARCHAR2)
        IS
            SELECT erp_org_id, inv_org_id, brand_name,
                   --                kco_header_id,
                   code, default_atp_buffer, pre_back_order_days,
                   NVL (put_away_days, 0) put_away_days
              FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
             WHERE code = p_feed_code;

        /*CURSOR v_feed_codes (p_feed_code VARCHAR2)  IS
            select distinct code from XXDO.XXDOEC_INV_FEED_CONFIG_V where code like p_feed_code;*/
        -- Commented by NRK

        --******************************************************************************************
        -- Added by BT Tech Team to extract the ATP details from common staging ATP table
        --*****************************************************************************************

        CURSOR full_load_cur (p_inv_org_id   NUMBER,
                              p_brand        VARCHAR2,
                              p_ou_name      VARCHAR2)
        IS
              SELECT *
                FROM (SELECT SLNO, SKU, INVENTORY_ITEM_ID,
                             INV_ORGANIZATION_ID, DEMAND_CLASS_CODE, BRAND,
                             UOM_CODE, REQUESTED_SHIP_DATE, AVAILABLE_QUANTITY,
                             AVAILABLE_DATE
                        FROM XXD_MASTER_ATP_FULL_T xmat1
                       WHERE     INV_ORGANIZATION_ID = p_inv_org_id
                             --                         AND inventory_item_id = 11254257
                             AND BRAND = p_brand
                             AND application = 'ECOMM'
                             AND available_date IS NOT NULL
                             -- AND available_quantity > 0  --W.r.t Ecom Atp meaningful Zeros
                             AND available_quantity >= 0 --W.r.t Ecom Atp meaningful Zeros
                             AND available_Quantity < 1000000
                             --                          AND SKU = '1006205-CBBJ-08'
                             --Commented by BT Team on 22-Sep Defect 3123
                             /*
                                                       AND DECODE (p_ou_name,
                                                                   'Deckers eCommerce OU', 'US',
                                                                   'Deckers Canada eCommerce OU', 'CA',
                                                                   xmat1.demand_class_code) =
                                                              DECODE (
                                                                 p_ou_name,
                                                                 'Deckers eCommerce OU', REGEXP_SUBSTR (
                                                                                            xmat1.demand_class_code,
                                                                                            '[^-]+',
                                                                                            1,
                                                                                            3),
                                                                 'Deckers Canada eCommerce OU', REGEXP_SUBSTR (
                                                                                                   xmat1.demand_class_code,
                                                                                                   '[^-]+',
                                                                                                   1,
                                                                                                   3),
                                                                 xmat1.demand_class_code)
                             */
                             AND TRUNC (available_date) > TRUNC (SYSDATE) -- Added on 23Apr15 BT Technology Team
                      UNION ALL
                      SELECT SLNO, SKU, INVENTORY_ITEM_ID,
                             INV_ORGANIZATION_ID, DEMAND_CLASS_CODE, BRAND,
                             UOM_CODE, REQUESTED_SHIP_DATE, AVAILABLE_QUANTITY,
                             AVAILABLE_DATE
                        FROM XXD_MASTER_ATP_FULL_T xmat2
                       WHERE     INV_ORGANIZATION_ID = p_inv_org_id
                             --                         AND inventory_item_id = 11254257
                             AND BRAND = p_brand
                             AND application = 'ECOMM'
                             AND available_date IS NOT NULL
                             --AND available_quantity > 0 --W.r.t Ecom Atp meaningful Zeros
                             AND available_quantity >= 0 --W.r.t Ecom Atp meaningful Zeros
                             AND available_Quantity < 1000000
                             --Commented by BT Team on 22-Sep Defect 3123
                             /*
                                                       AND DECODE (p_ou_name,
                                                                   'Deckers eCommerce OU', 'US',
                                                                   'Deckers Canada eCommerce OU', 'CA',
                                                                   xmat2.demand_class_code) =
                                                              DECODE (
                                                                 p_ou_name,
                                                                 'Deckers eCommerce OU', REGEXP_SUBSTR (
                                                                                            xmat2.demand_class_code,
                                                                                            '[^-]+',
                                                                                            1,
                                                                                            3),
                                                                 'Deckers Canada eCommerce OU', REGEXP_SUBSTR (
                                                                                                   xmat2.demand_class_code,
                                                                                                   '[^-]+',
                                                                                                   1,
                                                                                                   3),
                                                                 xmat2.demand_class_code)
                             */
                             AND TRUNC (AVAILABLE_DATE) =
                                 -- Code change by BT Team on 22-Sep for defect 3123
                                 --                                 (SELECT MAX (AVAILABLE_DATE) -- Added on 23Apr15 BT Technology Team
                                 (SELECT MAX (TRUNC (AVAILABLE_DATE)) -- Added on 23Apr15 BT Technology Team
                                    --End of Code change by BT Team on 22-Sep for defect 3123
                                    FROM XXD_MASTER_ATP_FULL_T xmat3
                                   WHERE     INV_ORGANIZATION_ID = p_inv_org_id
                                         AND BRAND = p_brand
                                         AND application = 'ECOMM'
                                         AND xmat3.inventory_item_id =
                                             xmat2.inventory_item_id
                                         AND xmat3.inv_organization_id =
                                             xmat2.inv_organization_id
                                         AND xmat3.demand_class_code =
                                             xmat2.demand_class_code
                                         AND available_date IS NOT NULL
                                         --Commented by BT Team on 22-Sep Defect 3123
                                         /*
                                                                                  AND DECODE (
                                                                                         p_ou_name,
                                                                                         'Deckers eCommerce OU', 'US',
                                                                                         'Deckers Canada eCommerce OU', 'CA',
                                                                                         xmat3.demand_class_code) =
                                                                                         DECODE (
                                                                                            p_ou_name,
                                                                                            'Deckers eCommerce OU', REGEXP_SUBSTR (
                                                                                                                       xmat3.demand_class_code,
                                                                                                                       '[^-]+',
                                                                                                                       1,
                                                                                                                       3),
                                                                                            'Deckers Canada eCommerce OU', REGEXP_SUBSTR (
                                                                                                                              xmat3.demand_class_code,
                                                                                                                              '[^-]+',
                                                                                                                              1,
                                                                                                                              3),
                                                                                            xmat3.demand_class_code)
                                         */
                                         AND TRUNC (available_date) <=
                                             TRUNC (SYSDATE)
                                         --AND available_quantity > 0 --W.r.t Ecom Atp meaningful Zeros
                                         AND available_quantity >= 0)) --W.r.t Ecom Atp meaningful Zeros
            ORDER BY INVENTORY_ITEM_ID, INV_ORGANIZATION_ID, AVAILABLE_DATE;


        DCDLog                   apps.DCDLog_type
            := apps.DCDLog_type (P_CODE           => DCDLogCodes.AppUpdateStart,
                                 P_APPLICATION    => G_APPLICATION,
                                 P_LOGEVENTTYPE   => 2);
    BEGIN
        x_retcode            := 1;
        x_ret_status         := '';
        v_feed_results       := '';
        v_start_time         := SYSDATE;

        -- get dates driving this process
        v_batchdate          := SYSDATE ();
        v_batchdate_string   :=
            TO_CHAR (v_batchdate, 'MM-DD-YYYY HH24:MI:SS'); -- use this to tag all log entries
        --v_nextbizday         := xxdoec_inv_utils.next_calendar_date;                -- Commented by NRK

        -- log: Update Start (application)
        DCDLog.AddParameter ('FeedCodes', p_feed_code, 'VARCHAR2');
        DCDLog.AddParameter ('NetChangesOnly', p_net_change, 'VARCHAR2');
        DCDLog.AddParameter ('BatchTime', v_batchdate_string, 'VARCHAR2');
        v_logval             := DCDLog.LogInsert ();

        /* Check PDP Flag, if PDP not ready, return and do not update data *****/
        --        v_pdp_status := xxdo_pdp_utils_pub.get_current_state;
        --        IF v_pdp_status = xxdo_pdp_utils_pub.get_error_status_code THEN
        --            raise ex_full_pdp_error;
        --        ELSIF v_pdp_status = xxdo_pdp_utils_pub.get_running_status_code THEN
        --            raise ex_full_pdp_running;
        --        END IF;                                                                            -- Need to check NRK

        -- process all codes if none are given
        SELECT DISTINCT code
          BULK COLLECT INTO v_codes
          FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
         WHERE code LIKE NVL (p_feed_code, '%');

        fnd_file.put_line (
            fnd_file.LOG,
               'At start of the program, date is '
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh24 mi ss'));

        --dbms_output.put_line('>>' || v_codes.count);
        IF v_codes.COUNT > 0
        THEN
            LOCK TABLE xxdo.xxdoec_inventory IN EXCLUSIVE MODE NOWAIT;
            -- lock table before we start work... don't let WTF procedures lock us out

            fnd_file.put_line (fnd_file.LOG, 'After locking the table ');

            FOR n IN v_codes.FIRST .. v_codes.LAST
            LOOP
                v_feed_start_time   := SYSDATE;

                fnd_file.put_line (fnd_file.LOG,
                                   'Inside loop  ' || v_codes (n));

                -- create three associative arrays: net Supply  SalesOrders quantities, KCO quantities, Item Calalog data
                /*  v_quantities := net_qty_atbl(v_codes(n), v_nextbizday);
                  v_kco_quantities := kco_qty_atbl(v_codes(n), v_nextbizday);
                  v_items := items_atbl(v_codes(n));*/
                --Commented by NRK

                -- log: Get Catalog Data, for all data retrieval in one entry (metric)
                v_end_time          := SYSDATE;
                DCDLog.ChangeCode (P_CODE           => DCDLogCodes.MetGetCatalogData,
                                   P_APPLICATION    => G_APPLICATION,
                                   P_LOGEVENTTYPE   => 4);
                DCDLog.AddParameter (
                    'Start',
                    TO_CHAR (v_feed_start_time, 'MM-DD-YYYY HH24:MI:SS'),
                    'VARCHAR2');
                DCDLog.AddParameter (
                    'End',
                    TO_CHAR (v_end_time, 'MM-DD-YYYY HH24:MI:SS'),
                    'VARCHAR2');
                DCDLog.AddParameter (
                    'ElapsedTime',
                    APPS.XXDOEC_INV_UTILS.TO_SECONDS (v_end_time,
                                                      v_feed_start_time),
                    'VARCHAR2');
                DCDLog.AddParameter ('FeedCode', v_codes (n), 'VARCHAR2');
                DCDLog.AddParameter ('BatchTime',
                                     v_batchdate_string,
                                     'VARCHAR2');
                v_logval            := DCDLog.LogInsert ();

                --dbms_output.put_line('net_tables_init');
                --dbms_output.put_line('1) ' || to_char(round((sysdate - v_batchdate) * 1440 * 60, 2)) || ' sec. elapsed');

                -- build atp table by adding a record for each item in each inventory source...
                -- FOR rec IN v_inv_configs(v_codes(n)) LOOP   --                                     --commented BY NRK

                IF p_net_change = 'N'
                THEN
                    -- delete all atp records and create new rows from scratch
                    DELETE FROM xxdo.xxdoec_inventory
                          WHERE feed_code = v_codes (n);

                    fnd_file.put_line (fnd_file.LOG, 'Delete successfull');
                END IF;

                FOR inv_feed_config_rec IN inv_feed_config_cur (v_codes (n))
                LOOP       -- process each (erp_org, inv_org, brand_name, kco)
                    --******************************************************************************************
                    -- BT Tech Team: Commented the existing current production logic
                    --******************************************************************************************
                    /*  v_source_start_time := sysdate;                                            -- Commented by NRK ( Start)

                       v_item :=  v_quantities(rec.inv_org_id)(rec.brand_name).FIRST;
                       WHILE v_item IS NOT NULL LOOP  -- loop over items

                           -- process this item to calculate atp and pre/backorder

                           -- skip excluded items
                           IF v_items.exists(v_item) AND XXDOEC_INV_UTILS.IS_EXCLUDED(v_items(v_item).sr_inventory_item_id) <> 1 THEN

                               -- quantity summation is complete, create row for this item...
                              v_atp.extend;
                              v_num := v_atp.last;
                              v_atp(v_num) := xxdoec_inv_atp_ot(null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null);

                               process_supply_demand(v_kco_quantities, v_quantities,
                                   rec.inv_org_id, rec.brand_name, rec.kco_header_id, v_item, v_items(v_item).sr_inventory_item_id, v_nextbizday,
                                   0,
                                   v_atp(v_num).atp_qty, v_atp(v_num).pre_back_order_qty, v_atp(v_num).pre_back_order_date );

                               -- if ATP is > 0, recalculate to simulate a demand for this ATP and get the next qty/date for backorder
                               IF v_atp(v_num).atp_qty > 0 THEN
                                   process_supply_demand(v_kco_quantities, v_quantities,
                                       rec.inv_org_id, rec.brand_name, rec.kco_header_id, v_item, v_items(v_item).sr_inventory_item_id, v_nextbizday,
                                       v_atp(v_num).atp_qty,
                                       v_atp(v_num).atp_qty, v_atp(v_num).pre_back_order_qty, v_atp(v_num).pre_back_order_date );
                               END IF;

                               -- calculate remaining KCO
                               v_atp(v_num).kco_remaining_qty := get_kco_remaining_quantity(v_kco_quantities,  rec.inv_org_id, v_item, xxdoec_inv_utils.to_number(v_nextbizday), rec.kco_header_id);

                               -- initialize record values
                               v_atp(v_num).erp_org_id := rec.erp_org_id;
                               v_atp(v_num).inv_org_id := rec.inv_org_id;
                               v_atp(v_num).brand := rec.brand_name;
                               v_atp(v_num).kco_hdr_id := rec.kco_header_id;
                               v_atp(v_num).feed_code := rec.code;
                               v_atp(v_num).inventory_item_id := v_items(v_item).sr_inventory_item_id; -- legacy process store sr_inventory_item_id
                               v_atp(v_num).sku := v_items(v_item).sku;
                               v_atp(v_num).upc := v_items(v_item).upc;
                               v_atp(v_num).atp_date := v_batchdate;
                               v_atp(v_num).is_perpetual := 0;
                               v_atp(v_num).consumed_date := null;
                               v_atp(v_num).consumed_date_ca := null;

                               -- assign stock buffer from DFF (or default)
                               IF v_items(v_item).stock_buffer <> -1 THEN
                                   v_atp(v_num).atp_buffer := v_items(v_item).stock_buffer;
                               ELSE
                                   v_atp(v_num).atp_buffer := rec.default_atp_buffer;
                               END IF;

                               -- use ATR if it's smaller the ATP
                               IF v_atp(v_num).atp_qty > 0 THEN
                                   v_atr := do_inv_utils_pub.item_atr_quantity(p_organization_id => rec.inv_org_id, p_inventory_item_id => v_items(v_item).sr_inventory_item_id);
                                   IF v_atr < v_atp(v_num).atp_qty THEN
                                       v_atp(v_num).atp_when_atr := v_atp(v_num).atp_qty; -- remember the value we replaced
                                       v_atp(v_num).atp_qty := v_atr;
                                   END IF;
                               END IF;

       --v_atp(v_num).pre_back_order_qty := do_atp_utils_pub.single_atp_result( v_items(v_item).sr_inventory_item_id, rec.inv_org_id, v_nextbizday, 'Y', rec.kco_header_id);

                               -- assign pre/back order mode
                               IF v_atp(v_num).pre_back_order_qty > 0
                                   AND v_atp(v_num).pre_back_order_date <= v_nextbizday + rec.pre_back_order_days  -- do not report NAD beyond configured limit
                               THEN
                                   -- add day(s) for DC to unpack new inventory
                                   FOR n IN 1..nvl(rec.PUT_AWAY_DAYS, 0) LOOP
                                       v_atp(v_num).pre_back_order_date := XXDOEC_INV_UTILS.NEXT_CALENDAR_DATE( v_atp(v_num).pre_back_order_date+1);
                                   END LOOP;

                                   -- assign preorders according to DFF, otherwise, mode is backorder
                                   IF v_items(v_item).preorder = 1 and v_atp(v_num).atp_qty = 0 THEN
                                       v_atp(v_num).pre_back_order_mode := 1;  -- preorder, requires atp_qty of zero
                                   ELSE
                                       v_atp(v_num).pre_back_order_mode := 2;  -- 2=backorder,
                                   END IF;
                               ELSE
                                   v_atp(v_num).pre_back_order_mode := 0;  -- none
                                   v_atp(v_num).pre_back_order_qty := 0;
                                   v_atp(v_num).pre_back_order_date := null;
                               END IF;

                           END IF;  -- IF is_excluded(v_item) <> 1 THEN

                           v_item :=  v_quantities(rec.inv_org_id)(rec.brand_name).next(v_item);
                       END LOOP;  -- WHILE v_item IS NOT NULL LOOP

                  -- log: Calculate Inventory For Source (metric)
                   v_end_time := sysdate;
                   DCDLog.ChangeCode (P_CODE => DCDLogCodes.MetCalculateInventoryForSource  , P_APPLICATION => G_APPLICATION, P_LOGEVENTTYPE => 4);
                   DCDLog.AddParameter('Start', TO_CHAR(v_source_start_time, 'MM-DD-YYYY HH24:MI:SS'), 'VARCHAR2');
                   DCDLog.AddParameter('End', TO_CHAR(v_end_time, 'MM-DD-YYYY HH24:MI:SS'), 'VARCHAR2');
                   DCDLog.AddParameter('ElapsedTime', APPS.XXDOEC_INV_UTILS.TO_SECONDS(v_end_time, v_source_start_time), 'VARCHAR2');
                   DCDLog.AddParameter('FeedCode', v_codes(n), 'VARCHAR2');
                   DCDLog.AddParameter('Brand', rec.brand_name, 'VARCHAR2');
                   DCDLog.AddParameter('ErpOrgID', rec.erp_org_id, 'NUMBER');
                   DCDLog.AddParameter('InvOrgID', rec.inv_org_id, 'NUMBER');
                   DCDLog.AddParameter('BatchTime', v_batchdate_string, 'VARCHAR2');
                   v_logval := DCDLog.LogInsert();

                   END LOOP;  -- FOR rec IN v_inv_configs LOOP  PRE_BACK_ORDER_DAYS

       --dbms_output.put_line('2) ' || to_char(round((sysdate - v_batchdate) * 1440 * 60, 2)) || ' sec. elapsed')--;
       --dbms_output.put_line ('> ATP Row Count: ' || v_atp.count);

                   v_modify_start_time := sysdate(); */
                    -- Commented by NRK ( End)

                    -- calculations are complete, update the inventory table

                    --******************************************************************************************
                    -- Loop to get the data from Full load ATP staging table based on brand and inventory org
                    --******************************************************************************************

                    gc_ou_name   := NULL;

                    BEGIN
                        SELECT NAME
                          INTO gc_ou_name
                          FROM HR_OPERATING_UNITS
                         WHERE Organization_id =
                               inv_feed_config_rec.erp_org_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Could not derive operating unit name from EBS base table ');
                    END;

                    FOR full_load_rec
                        IN full_load_cur (inv_feed_config_rec.inv_org_id,
                                          inv_feed_config_rec.brand_name,
                                          gc_ou_name)
                    LOOP
                        ln_stock_buffer          := 0;
                        ln_atp_buffer            := 0;
                        ln_pre_back_order_mode   := 0;
                        lv_upc_code              := NULL;
                        ln_inv_preorder          := 0;
                        ln_pre_back_order_qty    := 0;
                        ld_back_order_date       := NULL;
                        lv_sku                   := NULL;
                        ln_atp_when_atr          := 0;
                        ln_atp                   := 0;
                        ln_atr                   := 0;
                        ln_cnt                   := 0;
                        ln_cnt_dt                := 0;
                        ld_available_date        := NULL;

                        -- fnd_file.put_line (fnd_file.LOG, 'Tmp msg: Inv ID , Org ID' || full_load_rec.inventory_item_id || '-' || full_load_rec.inv_organization_id);

                        -- Deriving  ATP_BUFFER and other item level details

                        BEGIN
                            SELECT xci.inv_buffer, xci.inv_preorder, xci.upc_code,
                                   xci.item_number
                              INTO ln_stock_buffer, ln_inv_preorder, lv_upc_code, lv_sku
                              FROM xxd_common_items_v xci
                             WHERE     xci.inventory_item_id =
                                       full_load_rec.inventory_item_id
                                   AND organization_id =
                                       full_load_rec.inv_organization_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'In Exception while deriving ATP Buffer/UPC Code..'
                                    || SQLERRM
                                    || SQLCODE
                                    || '--'
                                    || full_load_rec.inventory_item_id
                                    || '--'
                                    || inv_feed_config_rec.inv_org_id);
                        END;


                        IF ln_stock_buffer <> -1
                        THEN
                            ln_atp_buffer   := ln_stock_buffer;
                        ELSE
                            ln_atp_buffer   :=
                                inv_feed_config_rec.default_atp_buffer;
                        END IF;

                        -- Condition to check if data is for today's date

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'full_load_rec.available_date - '
                            || full_load_rec.available_date
                            || ' full_load_rec.requested_ship_date - '
                            || full_load_rec.requested_ship_date
                            || ' full_load_rec.AVAILABLE_QUANTITY -  '
                            || full_load_rec.AVAILABLE_QUANTITY);

                        IF TRUNC (
                               NVL (full_load_rec.available_date,
                                    SYSDATE + 1000)) <= --(added LessThan< 23Apr15)
                           TRUNC (SYSDATE)
                        THEN
                            ln_atp              := full_load_rec.AVAILABLE_QUANTITY;
                            -- Changed by BT Team on 04-May-15
                            --                     ld_available_date := TRUNC (full_load_rec.available_date);
                            ld_available_date   := SYSDATE;
                            --End of Changes by BT Team on 04-May-15

                            --Deriving the ATP WHEN ATR
                            ln_atr              := 0;
                            ln_atp_when_atr     := 0;

                            IF ln_atp > 0
                            THEN
                                ln_atr   :=
                                    do_inv_utils_pub.item_atr_quantity (
                                        p_organization_id   =>
                                            full_load_rec.inv_organization_id,
                                        p_inventory_item_id   =>
                                            full_load_rec.inventory_item_id);

                                IF ln_atr < ln_atp
                                THEN
                                    ln_atp_when_atr   := ln_atp; -- remember the value we replaced
                                    ln_atp            := ln_atr;
                                END IF;
                            END IF;
                        ELSIF TRUNC (
                                  NVL (full_load_rec.available_date,
                                       SYSDATE - 1)) >
                              TRUNC (SYSDATE)
                        THEN
                            ln_atp              := 0;
                            -- Changed by BT Team on 04-May-15
                            --                    ld_available_date := TRUNC (SYSDATE);
                            ld_available_date   := SYSDATE;
                            --End of Changes by BT Team on 04-May-15
                            ld_back_order_date   :=
                                full_load_rec.available_date;
                            ln_pre_back_order_qty   :=
                                full_load_rec.AVAILABLE_QUANTITY;
                        ELSE
                            ln_atp                  := 0;
                            -- Changed by BT Team on 04-May-15
                            --                     ld_available_date := TRUNC (SYSDATE);
                            ld_available_date       := SYSDATE;
                            --End of Changes by BT Team on 04-May-15
                            ld_back_order_date      := NULL;
                            ln_pre_back_order_qty   := 0;
                        END IF;

                        IF    ld_back_order_date IS NULL
                           OR ln_pre_back_order_qty <= 0
                        THEN
                            BEGIN
                                SELECT full_t1.available_date, full_t1.available_quantity
                                  INTO ld_back_order_date, ln_pre_back_order_qty
                                  FROM XXD_MASTER_ATP_FULL_T full_t1
                                 WHERE     full_t1.inventory_item_id =
                                           full_load_rec.inventory_item_id
                                       AND full_t1.inv_organization_id =
                                           full_load_rec.inv_organization_id
                                       AND full_t1.demand_class_code =
                                           full_load_rec.demand_class_code
                                       -- Start modification by BT Team on 20-Nov-15
                                       AND full_t1.application = 'ECOMM'
                                       -- End modification by BT Team on 20-Nov-15
                                       AND full_t1.available_date =
                                           (SELECT MIN (available_date)
                                              FROM XXD_MASTER_ATP_FULL_T full_t2
                                             WHERE     full_t2.inventory_item_id =
                                                       full_t1.inventory_item_id
                                                   AND full_t2.inv_organization_id =
                                                       full_t1.inv_organization_id
                                                   AND full_t2.demand_class_code =
                                                       full_t1.demand_class_code
                                                   -- Start modification by BT Team on 20-Nov-15
                                                   AND full_t2.application =
                                                       'ECOMM'
                                                   -- End modification by BT Team on 20-Nov-15
                                                   -- Start changes v1.3
                                                   AND full_t2.available_quantity >
                                                       0
                                                   -- End changes v1.3
                                                   AND TRUNC (
                                                           NVL (
                                                               full_t2.available_date,
                                                               SYSDATE - 2)) >
                                                       TRUNC (SYSDATE));
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'In Exception while deriving Back Order Details..'
                                        || SQLERRM
                                        || SQLCODE);
                            END;
                        END IF;

                        --    Deriving ln_pre_back_order_mode details
                        IF ln_pre_back_order_qty > 0
                        THEN
                            IF ln_inv_preorder = 1 AND ln_atp = 0
                            THEN
                                ln_pre_back_order_mode   := 1; -- Preorder, requires atp_qty of zero
                            ELSE
                                ln_pre_back_order_mode   := 2; -- 2=backorder,
                            END IF;
                        ELSE
                            ln_pre_back_order_mode   := 0;             -- none
                            ln_pre_back_order_qty    := 0;        --nrk modify
                            ld_back_order_date       := NULL;     --nrk modify
                        END IF;

                        IF ld_back_order_date >
                           SYSDATE + inv_feed_config_rec.pre_back_order_days
                        THEN
                            ln_pre_back_order_mode   := 0;             -- none
                            ln_pre_back_order_qty    := 0;        --nrk modify
                            ld_back_order_date       := NULL;     --nrk modify
                        END IF;


                        BEGIN
                            ln_cnt   := 0;

                            SELECT COUNT (1)
                              INTO ln_cnt
                              FROM xxdo.xxdoec_inventory xdi
                             WHERE     xdi.inventory_item_id =
                                       full_load_rec.inventory_item_id
                                   AND xdi.inv_org_id =
                                       full_load_rec.inv_organization_id
                                   AND xdi.feed_code = v_codes (n);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                -- Data does not exist in XXDOEC_INVENTORY table
                                ln_cnt   := 0;
                        END;

                        BEGIN
                            ln_cnt_dt   := 0;

                            SELECT COUNT (1)
                              INTO ln_cnt_dt
                              FROM xxdo.xxdoec_inventory xdi
                             WHERE     xdi.inventory_item_id =
                                       full_load_rec.inventory_item_id
                                   AND xdi.inv_org_id =
                                       full_load_rec.inv_organization_id
                                   AND TRUNC (xdi.atp_date) =
                                       TRUNC (ld_available_date)
                                   AND xdi.feed_code = v_codes (n);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                -- Data does not exist in XXDOEC_INVENTORY table
                                ln_cnt   := 0;
                        END;


                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Variables - '
                            || ln_stock_buffer
                            || '-'
                            || ln_atp_buffer
                            || '-'
                            || ln_pre_back_order_mode
                            || '-'
                            || lv_upc_code
                            || '-'
                            || ln_inv_preorder
                            || '-'
                            || ln_pre_back_order_qty
                            || '-'
                            || ld_back_order_date
                            || '-'
                            || lv_sku
                            || '-'
                            || ln_atp_when_atr
                            || '-'
                            || ln_atp
                            || '-'
                            || ln_atr
                            || '-'
                            || ln_cnt
                            || '-'
                            || ln_cnt_dt
                            || '-'
                            || ld_available_date);


                        IF p_net_change = 'Y'
                        THEN
                            -- keep unchanged records, only make modifications
                            -- step 1, update existing, changed records
                            /*FORALL n IN v_atp.FIRST..v_atp.LAST
                                UPDATE xxdo.xxdoec_inventory
                                    SET consumed_date = null
                                        , consumed_date_ca = null
                                        , atp_qty = treat( v_atp(n) as xxdoec_inv_atp_ot).ATP_QTY
                                        , atp_date = treat( v_atp(n) as xxdoec_inv_atp_ot).ATP_DATE
                                        , atp_buffer = treat( v_atp(n) as xxdoec_inv_atp_ot).ATP_BUFFER
                                        , pre_back_order_mode = treat( v_atp(n) as xxdoec_inv_atp_ot).PRE_BACK_ORDER_MODE
                                        , pre_back_order_date = treat( v_atp(n) as xxdoec_inv_atp_ot).PRE_BACK_ORDER_DATE
                                        , pre_back_order_qty = treat( v_atp(n) as xxdoec_inv_atp_ot).PRE_BACK_ORDER_QTY
                                    WHERE inventory_item_id = treat( v_atp(n) as xxdoec_inv_atp_ot).INVENTORY_ITEM_ID
                                        AND erp_org_id =  treat( v_atp(n) as xxdoec_inv_atp_ot).ERP_ORG_ID
                                        AND inv_org_id =  treat( v_atp(n) as xxdoec_inv_atp_ot).INV_ORG_ID
                                        AND feed_code = treat( v_atp(n) as xxdoec_inv_atp_ot).FEED_CODE
                                        AND ( atp_qty <> treat( v_atp(n) as xxdoec_inv_atp_ot).ATP_QTY
                                                OR atp_buffer <> treat( v_atp(n) as xxdoec_inv_atp_ot).ATP_BUFFER
                                                OR pre_back_order_mode <> treat( v_atp(n) as xxdoec_inv_atp_ot).PRE_BACK_ORDER_MODE
                                                OR pre_back_order_date <> treat( v_atp(n) as xxdoec_inv_atp_ot).PRE_BACK_ORDER_DATE
                                                OR pre_back_order_qty <> treat( v_atp(n) as xxdoec_inv_atp_ot).PRE_BACK_ORDER_QTY
                                              );*/
                            --Commented by NRK

                            IF     ln_cnt_dt > 0
                               AND TRUNC (full_load_rec.available_date) <=
                                   TRUNC (SYSDATE)
                            THEN
                                UPDATE xxdo.xxdoec_inventory
                                   SET consumed_date = NULL, consumed_date_ca = NULL, atp_qty = ln_atp,
                                       atp_date = ld_available_date, atp_buffer = ln_atp_buffer, pre_back_order_mode = ln_pre_back_order_mode,
                                       pre_back_order_date = ld_back_order_date, pre_back_order_qty = ln_pre_back_order_qty, filetype = 'UPDATE' -- 1.0
                                 WHERE     inventory_item_id =
                                           full_load_rec.INVENTORY_ITEM_ID
                                       -- AND     erp_org_id             =  NULL--treat( v_atp(n) as xxdoec_inv_atp_ot).ERP_ORG_ID         -- Have to derive..How to derive? NRK
                                       AND TRUNC (atp_date) =
                                           TRUNC (ld_available_date)
                                       AND inv_org_id =
                                           full_load_rec.INV_ORGANIZATION_ID
                                       -- AND     feed_code             =  treat( v_atp(n) as xxdoec_inv_atp_ot).FEED_CODE             -- Can't Compare NRK
                                       AND (atp_qty <> ln_atp OR atp_buffer <> ln_atp_buffer OR pre_back_order_mode <> ln_pre_back_order_mode OR pre_back_order_date <> ld_back_order_date OR pre_back_order_qty <> ln_pre_back_order_qty);
                            ELSIF ln_cnt = 0
                            THEN
                                --Start Added by NRK
                                BEGIN
                                    --                        ln_cnt := 0;
                                    --
                                    --                        SELECT COUNT (1)
                                    --                          INTO ln_cnt
                                    --                          FROM XXD_MASTER_ATP_FULL_T full_t
                                    --                         WHERE     full_t.inventory_item_id =
                                    --                                      full_load_rec.INVENTORY_ITEM_ID
                                    --                               AND full_t.inv_organization_id =
                                    --                                      full_load_rec.INV_ORGANIZATION_ID
                                    --                               AND NOT EXISTS
                                    --                                          (SELECT *
                                    --                                             FROM xxdo.xxdoec_inventory xdi
                                    --                                            WHERE     xdi.inventory_item_id =
                                    --                                                         full_t.inventory_item_id
                                    --                                                  AND xdi.inv_org_id =
                                    --                                                         full_t.inv_organization_id);

                                    INSERT INTO xxdo.xxdoec_inventory (
                                                    ERP_ORG_ID,
                                                    INV_ORG_ID,
                                                    FEED_CODE,
                                                    BRAND,
                                                    INVENTORY_ITEM_ID,
                                                    KCO_HDR_ID,
                                                    SKU,
                                                    UPC,
                                                    ATP_QTY,
                                                    ATP_DATE,
                                                    ATP_BUFFER,
                                                    ATP_WHEN_ATR,
                                                    PRE_BACK_ORDER_MODE,
                                                    PRE_BACK_ORDER_QTY,
                                                    PRE_BACK_ORDER_DATE,
                                                    IS_PERPETUAL,
                                                    CONSUMED_DATE,
                                                    CONSUMED_DATE_CA,
                                                    kco_remaining_qty,
                                                    filetype            -- 1.0
                                                            )
                                         VALUES (inv_feed_config_rec.erp_org_id, full_load_rec.INV_ORGANIZATION_ID, v_codes (n), inv_feed_config_rec.brand_name, full_load_rec.INVENTORY_ITEM_ID, NULL, --KCO HEADER_ID should be null NRK
                                                                                                                                                                                                        lv_sku, NVL (lv_upc_code, '99999'), -- tempoarary NVL condition for data issue in SIT
                                                                                                                                                                                                                                            ln_atp, ld_available_date, ln_atp_buffer, --  ATP_BUFFER,
                                                                                                                                                                                                                                                                                      ln_atr, --ATP_WHEN_ATR,
                                                                                                                                                                                                                                                                                              ln_pre_back_order_mode, --                                           PRE_BACK_ORDER_MODE,
                                                                                                                                                                                                                                                                                                                      ln_pre_back_order_qty, --                                           PRE_BACK_ORDER_QTY,
                                                                                                                                                                                                                                                                                                                                             ld_back_order_date, --                                           PRE_BACK_ORDER_DATE,
                                                                                                                                                                                                                                                                                                                                                                 '0', --  IS_PERPETUAL,
                                                                                                                                                                                                                                                                                                                                                                      NULL, --  CONSUMED_DATE,
                                                                                                                                                                                                                                                                                                                                                                            NULL
                                                 ,       --  CONSUMED_DATE_CA,
                                                   NULL, -- kco_remaining_qty);
                                                         'REPLACE'      -- 1.0
                                                                  );
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'In Exception of Net Change Insert..'
                                            || SQLERRM
                                            || SQLCODE);
                                END;
                            END IF;
                        --End Added by NRK

                        -- Step 2, add new records
                        /*INSERT INTO xxdo.xxdoec_inventory (
                           select
                              x.ERP_ORG_ID,
                              x.INV_ORG_ID,
                              x.FEED_CODE,
                              x.BRAND,
                              x.INVENTORY_ITEM_ID,
                              x.KCO_HDR_ID,
                              x.SKU ,
                              x.UPC,
                              x.ATP_QTY,
                              x.ATP_DATE,
                              x.ATP_BUFFER,
                              x.ATP_WHEN_ATR,
                              x.PRE_BACK_ORDER_MODE,
                              x.PRE_BACK_ORDER_QTY,
                              x.PRE_BACK_ORDER_DATE,
                              x.IS_PERPETUAL,
                              x.CONSUMED_DATE,
                              x.CONSUMED_DATE_CA,
                              x.kco_remaining_qty
                            from (
                               select t.*
                               ,       i.inventory_item_id as right_item_id
                               from   table(cast(v_atp as atp_t2)) t left outer join XXDO.XXDOEC_INVENTORY i
                               on     t.inventory_item_id     = i.inventory_item_id
                               and       t.erp_org_id               = i.erp_org_id
                               and       t.inv_org_id             = i.inv_org_id
                               and       t.feed_code             = i.feed_code
                                   ) x where right_item_id is null
                             );*/
                        -- Commented by NRK
                        --
                        --                     INSERT INTO xxdo.xxdoec_inventory
                        --                        (SELECT x.ERP_ORG_ID,
                        --                                x.INV_ORG_ID,
                        --                                x.FEED_CODE,
                        --                                x.BRAND,
                        --                                x.INVENTORY_ITEM_ID,
                        --                                x.KCO_HDR_ID,
                        --                                x.SKU,
                        --                                x.UPC,
                        --                                x.ATP_QTY,
                        --                                x.ATP_DATE,
                        --                                x.ATP_BUFFER,
                        --                                x.ATP_WHEN_ATR,
                        --                                x.PRE_BACK_ORDER_MODE,
                        --                                x.PRE_BACK_ORDER_QTY,
                        --                                x.PRE_BACK_ORDER_DATE,
                        --                                x.IS_PERPETUAL,
                        --                                x.CONSUMED_DATE,
                        --                                x.CONSUMED_DATE_CA,
                        --                                x.kco_remaining_qty
                        --                           FROM (SELECT NULL ERP_ORG_ID,
                        --                                        t.INV_ORGANIZATION_ID INV_ORG_ID,
                        --                                        v_codes (n) FEED_CODE,
                        --                                        inv_feed_config_rec.brand_name,
                        --                                        full_load_rec.INVENTORY_ITEM_ID,
                        --                                        NULL KCO_HDR_ID --KCO HEADER_ID should be null NRK
                        --                                                       ,
                        --                                        iid_to_sku (t.inventory_item_id) SKU,
                        --                                        lv_upc_code UPC,
                        --                                        full_load_rec.available_quantity,
                        --                                        full_load_rec.available_date ATP_DATE,
                        --                                        ln_atp_buffer ATP_BUFFER,
                        --                                        ln_atr ATP_WHEN_ATR,
                        --                                        ln_pre_back_order_mode
                        --                                           PRE_BACK_ORDER_MODE,
                        --                                        ln_pre_back_order_qty
                        --                                           PRE_BACK_ORDER_QTY,
                        --                                        ld_back_order_date
                        --                                           PRE_BACK_ORDER_DATE,
                        --                                        '0' IS_PERPETUAL,
                        --                                        NULL CONSUMED_DATE,
                        --                                        NULL CONSUMED_DATE_CA,
                        --                                        NULL kco_remaining_qty,
                        --                                        i.inventory_item_id right_item_id
                        --                                   FROM XXD_MASTER_ATP_FULL_T t,
                        --                                        XXDO.XXDOEC_INVENTORY i
                        --                                  WHERE     t.inventory_item_id(+) =
                        --                                               i.inventory_item_id
                        --                                        --and       t.erp_org_id               = i.erp_org_id                 -- Can't Compare
                        --                                        AND t.inv_organization_id =
                        --                                               i.inv_org_id --and       t.feed_code              = i.feed_code                     --Can't Compare
                        --                                                           ) x
                        --                          WHERE right_item_id IS NULL);        -- Added by NRK
                        ELSE
                            /*INSERT INTO xxdo.xxdoec_inventory (
                               select
                                  x.ERP_ORG_ID,
                                  x.INV_ORG_ID,
                                  x.FEED_CODE,
                                  x.BRAND,
                                  x.INVENTORY_ITEM_ID,
                                  x.KCO_HDR_ID,
                                  x.SKU ,
                                  x.UPC,
                                  x.ATP_QTY,
                                  x.ATP_DATE,
                                  x.ATP_BUFFER,
                                  x.ATP_WHEN_ATR,
                                  x.PRE_BACK_ORDER_MODE,
                                  x.PRE_BACK_ORDER_QTY,
                                  x.PRE_BACK_ORDER_DATE,
                                  x.IS_PERPETUAL,
                                  x.CONSUMED_DATE,
                                  x.CONSUMED_DATE_CA,
                                  x.kco_remaining_qty
                                from (
                                   select t.*
                                   ,        i.inventory_item_id as right_item_id
                                   from     table(cast(v_atp as atp_t2)) t left outer join XXDO.XXDOEC_INVENTORY i
                                   on      t.inventory_item_id = i.inventory_item_id
                                   and         t.erp_org_id = i.erp_org_id
                                   and         t.inv_org_id = i.inv_org_id
                                   and         t.feed_code = i.feed_code  ) x where right_item_id is null
                                 );*/
                            --Commented by NRK
                            IF ln_cnt = 0
                            THEN
                                INSERT INTO xxdo.xxdoec_inventory (
                                                ERP_ORG_ID,
                                                INV_ORG_ID,
                                                FEED_CODE,
                                                BRAND,
                                                INVENTORY_ITEM_ID,
                                                KCO_HDR_ID,
                                                SKU,
                                                UPC,
                                                ATP_QTY,
                                                ATP_DATE,
                                                ATP_BUFFER,
                                                ATP_WHEN_ATR,
                                                PRE_BACK_ORDER_MODE,
                                                PRE_BACK_ORDER_QTY,
                                                PRE_BACK_ORDER_DATE,
                                                IS_PERPETUAL,
                                                CONSUMED_DATE,
                                                CONSUMED_DATE_CA,
                                                kco_remaining_qty,
                                                filetype                -- 1.0
                                                        )
                                     VALUES (inv_feed_config_rec.erp_org_id, full_load_rec.INV_ORGANIZATION_ID, v_codes (n), inv_feed_config_rec.brand_name, full_load_rec.INVENTORY_ITEM_ID, NULL, --KCO HEADER_ID should be null NRK
                                                                                                                                                                                                    lv_sku, NVL (lv_upc_code, '99999'), -- tempoarary NVL condition for data issue in SIT
                                                                                                                                                                                                                                        ln_atp, ld_available_date, ln_atp_buffer, --  ATP_BUFFER,
                                                                                                                                                                                                                                                                                  ln_atp_when_atr, --ATP_WHEN_ATR,
                                                                                                                                                                                                                                                                                                   ln_pre_back_order_mode, --                                           PRE_BACK_ORDER_MODE,
                                                                                                                                                                                                                                                                                                                           ln_pre_back_order_qty, --                                           PRE_BACK_ORDER_QTY,
                                                                                                                                                                                                                                                                                                                                                  ld_back_order_date, --                                           PRE_BACK_ORDER_DATE,
                                                                                                                                                                                                                                                                                                                                                                      '0', --  IS_PERPETUAL,
                                                                                                                                                                                                                                                                                                                                                                           NULL, --  CONSUMED_DATE,
                                                                                                                                                                                                                                                                                                                                                                                 NULL
                                             ,           --  CONSUMED_DATE_CA,
                                               NULL, 'REPLACE'          -- 1.0
                                                              ); -- kco_remaining_qty);
                            END IF;
                        END IF;
                    END LOOP;
                END LOOP;

                COMMIT;

                --added 4/25/2016 kcopeland
                -- having just updated inventory data, store the raw data to inventory history before applying overrides
                xxdo.xxdoec_inv_history.update_history;

                -- having just updated inventory data, maintain auto overrides to catch new duplicates before applying overrides
                xxdo.xxdoec_inv_override.maintain_auto_overrides;

                -- now apply overrides (delete excluded records and add virtual records)
                xxdo.xxdoec_inv_override.apply_overrides;
                --kcopeland 4/25/2016 add complete

                -- log: Metric Modify Feed Data
                v_end_time          := SYSDATE;
                DCDLog.ChangeCode (P_CODE           => DCDLogCodes.MetModifyFeedData,
                                   P_APPLICATION    => G_APPLICATION,
                                   P_LOGEVENTTYPE   => 4);
                DCDLog.AddParameter (
                    'Start',
                    TO_CHAR (v_modify_start_time, 'MM-DD-YYYY HH24:MI:SS'),
                    'VARCHAR2');
                DCDLog.AddParameter (
                    'End',
                    TO_CHAR (v_end_time, 'MM-DD-YYYY HH24:MI:SS'),
                    'VARCHAR2');
                DCDLog.AddParameter (
                    'ElapsedTime',
                    APPS.XXDOEC_INV_UTILS.TO_SECONDS (v_end_time,
                                                      v_modify_start_time),
                    'VARCHAR2');
                DCDLog.AddParameter ('FeedCode', v_codes (n), 'VARCHAR2');
                DCDLog.AddParameter ('NetChangesOnly',
                                     p_net_change,
                                     'VARCHAR2');
                DCDLog.AddParameter ('BatchTime',
                                     v_batchdate_string,
                                     'VARCHAR2');
                v_logval            := DCDLog.LogInsert ();

                -- v_atp := atp_t2(); -- COMMITTED by NRK

                -- log: Process Feed (metric)
                v_end_time          := SYSDATE;
                DCDLog.ChangeCode (P_CODE           => DCDLogCodes.MetProcessFeed,
                                   P_APPLICATION    => G_APPLICATION,
                                   P_LOGEVENTTYPE   => 4);
                DCDLog.AddParameter (
                    'Start',
                    TO_CHAR (v_feed_start_time, 'MM-DD-YYYY HH24:MI:SS'),
                    'VARCHAR2');
                DCDLog.AddParameter (
                    'End',
                    TO_CHAR (v_end_time, 'MM-DD-YYYY HH24:MI:SS'),
                    'VARCHAR2');
                DCDLog.AddParameter (
                    'ElapsedTime',
                    APPS.XXDOEC_INV_UTILS.TO_SECONDS (v_end_time,
                                                      v_feed_start_time),
                    'VARCHAR2');
                DCDLog.AddParameter ('FeedCode', v_codes (n), 'VARCHAR2');
                DCDLog.AddParameter ('NetChangesOnly',
                                     p_net_change,
                                     'VARCHAR2');
                DCDLog.AddParameter ('BatchTime',
                                     v_batchdate_string,
                                     'VARCHAR2');
                v_logval            := DCDLog.LogInsert ();
            END LOOP;
        END IF;

        --dbms_output.put_line('Rows: ' || SQL%ROWCOUNT);
        --dbms_output.put_line('3) ' || to_char(round((sysdate - v_batchdate) * 1440 * 60, 2)) || ' sec. elapsed');

        x_ret_status         := v_feed_results || g_newline || 'Success.';
        x_retcode            := 0;

        -- log: Entire Update Routine (metric)
        v_end_time           := SYSDATE;
        DCDLog.ChangeCode (P_CODE           => DCDLogCodes.MetUpdateProcedure,
                           P_APPLICATION    => G_APPLICATION,
                           P_LOGEVENTTYPE   => 4);
        DCDLog.AddParameter ('Start',
                             TO_CHAR (v_start_time, 'MM-DD-YYYY HH24:MI:SS'),
                             'VARCHAR2');
        DCDLog.AddParameter ('End',
                             TO_CHAR (v_end_time, 'MM-DD-YYYY HH24:MI:SS'),
                             'VARCHAR2');
        DCDLog.AddParameter (
            'ElapsedTime',
            APPS.XXDOEC_INV_UTILS.TO_SECONDS (v_end_time, v_start_time),
            'VARCHAR2');
        DCDLog.AddParameter ('FeedCodes', p_feed_code, 'VARCHAR2');
        DCDLog.AddParameter ('BatchTime', v_batchdate_string, 'VARCHAR2');
        v_logval             := DCDLog.LogInsert ();

        -- log: Update End
        DCDLog.ChangeCode (P_CODE           => DCDLogCodes.AppUpdateEnd,
                           P_APPLICATION    => G_APPLICATION,
                           P_LOGEVENTTYPE   => 2);
        DCDLog.AddParameter ('BatchTime', v_batchdate_string, 'VARCHAR2');
        v_logval             := DCDLog.LogInsert;

        log_atp_analysis (v_batchdate_string);

        --DBMS_OUTPUT.put_line(x_ret_status);
        --1.0 changes start
        -- Script to call the Deckers Inventory File Generation for WTF Web Service program.
        BEGIN
            IF NVL (p_generate_control_file, 'N') = 'N'
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'p_generate_control_file parameter selected as N...Skipping the file generation');
            ELSE
                l_request_id   :=
                    fnd_request.submit_request ('XXDO', 'XXDOEC_INV_WTF_FILE_GEN', 'Deckers Inventory File Generation for WTF Web Service', SYSDATE, FALSE, p_feed_code
                                                , p_net_change);
                COMMIT;

                IF l_request_id = 0
                THEN
                    DBMS_OUTPUT.put_line (
                        'Request not submitted error: ' || fnd_message.get);
                ELSE
                    DBMS_OUTPUT.put_line (
                           'Request submitted successfully request id: '
                        || l_request_id);
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                DBMS_OUTPUT.put_line ('Unexpected error:' || SQLERRM);
        END;
    --1.0 changes end
    --
    EXCEPTION
        WHEN ex_full_pdp_running
        THEN
            x_ret_status   := g_msg_pdp_running;
            x_retcode      := g_num_pdp_running;
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_EDI_UTILS_PUB.G_DEBUG_LOCATION, v_application_id => g_package_title || '.XXDOEC_UPDATE_ATP_TABLE', v_debug_text => x_ret_status
                                  , l_debug_level => 1);

            -- log: PDP Running (error)
            DCDLog.ChangeCode (P_CODE           => DCDLogCodes.ErrPdpRunning,
                               P_APPLICATION    => G_APPLICATION,
                               P_LOGEVENTTYPE   => 1);
            DCDLog.AddParameter ('ErrorMessage', x_ret_status, 'VARCHAR2');
            v_logval       := DCDLog.LogInsert ();
        WHEN ex_full_pdp_error
        THEN
            x_ret_status   := g_msg_pdp_error;
            x_retcode      := g_num_pdp_error;
            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_EDI_UTILS_PUB.G_DEBUG_LOCATION, v_application_id => g_package_title || '.XXDOEC_UPDATE_ATP_TABLE', v_debug_text => x_ret_status
                                  , l_debug_level => 1);

            -- log: PDP Error (error)
            DCDLog.ChangeCode (P_CODE           => DCDLogCodes.ErrPdpError,
                               P_APPLICATION    => G_APPLICATION,
                               P_LOGEVENTTYPE   => 1);
            DCDLog.AddParameter ('ErrorMessage', x_ret_status, 'VARCHAR2');
            v_logval       := DCDLog.LogInsert ();
        WHEN OTHERS
        THEN
            x_ret_status   :=
                   'An exception occurred while updating ATP records.'
                || g_newline;
            x_ret_status   :=
                x_ret_status || g_newline || ' SQLERRM: ' || SQLERRM;
            x_ret_status   :=
                   x_ret_status
                || g_newline
                || ' FORMAT_ERROR_BACKTRACE: '
                || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            x_ret_status   :=
                   x_ret_status
                || g_newline
                || ' FORMAT_CALL_STACK: '
                || DBMS_UTILITY.FORMAT_CALL_STACK;

            x_retcode    := 2;                          -- return error status

            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_EDI_UTILS_PUB.G_DEBUG_LOCATION, v_application_id => g_package_title || '.XXDOEC_UPDATE_ATP_TABLE', v_debug_text => x_ret_status
                                  , l_debug_level => 1);

            -- log: Unexpected Exception (error)
            DCDLog.ChangeCode (P_CODE           => DCDLogCodes.ErrUnexpectedException,
                               P_APPLICATION    => G_APPLICATION,
                               P_LOGEVENTTYPE   => 1);
            DCDLog.AddParameter ('ErrorMessage', x_ret_status, 'VARCHAR2');
            v_logval     := DCDLog.LogInsert ();

            -- log: Entire Update Routine (metric)
            v_end_time   := SYSDATE;
            DCDLog.ChangeCode (P_CODE           => DCDLogCodes.MetUpdateProcedure,
                               P_APPLICATION    => G_APPLICATION,
                               P_LOGEVENTTYPE   => 4);
            DCDLog.AddParameter (
                'Start',
                TO_CHAR (v_start_time, 'MM-DD-YYYY HH24:MI:SS'),
                'VARCHAR2');
            DCDLog.AddParameter (
                'End',
                TO_CHAR (v_end_time, 'MM-DD-YYYY HH24:MI:SS'),
                'VARCHAR2');
            DCDLog.AddParameter (
                'ElapsedTime',
                APPS.XXDOEC_INV_UTILS.TO_SECONDS (v_end_time, v_start_time),
                'VARCHAR2');
            DCDLog.AddParameter ('FeedCodes', p_feed_code, 'VARCHAR2');
            DCDLog.AddParameter ('BatchTime', v_batchdate_string, 'VARCHAR2');
            v_logval     := DCDLog.LogInsert ();
            fnd_file.put_line (fnd_file.LOG,
                               'Unexpected Error - ' || SQLERRM);
    END xxdoec_update_atp_table;

    PROCEDURE xxdoec_get_atp_for_upc (
        p_item_upc              IN     VARCHAR2,
        p_inv_region            IN     VARCHAR2,
        p_brand                 IN     VARCHAR2,
        p_demand_class_code     IN     VARCHAR2,
        p_inv_org_ids           IN     ttbl_inv_orgs,
        x_ret_status               OUT VARCHAR2,
        o_upc_quantity_cursor      OUT t_inv_atp_cursor)
    IS
        ln_stock_buffer               NUMBER;
        ln_atp_buffer                 NUMBER;
        ln_pre_back_order_mode        NUMBER;
        lv_upc_code                   VARCHAR2 (30);
        ln_inv_preorder               NUMBER;
        ln_pre_back_order_qty         NUMBER;
        ld_back_order_date            DATE;
        lv_sku                        VARCHAR2 (50);
        ln_atp_when_atr               NUMBER;
        ln_atp                        NUMBER;
        ln_atr                        NUMBER;
        ln_cnt                        NUMBER := 0;
        ln_cnt_dt                     NUMBER := 0;
        ld_available_date             DATE;
        ln_default_atp_buffer         NUMBER := 0;
        ln_epr_org                    NUMBER;
        ln_pre_back_order_days        NUMBER := 0;
        ln_put_away_days              NUMBER := 0;
        ln_inventory_item_id          NUMBER;
        --Start changes v1.2
        --lv_demand_class          VARCHAR2 (100) := p_demand_class_code;
        lv_demand_class               VARCHAR2 (10) := '-1';
        --End changes v1.2
        ln_pre_back_order_qty_final   NUMBER;

        --******************************************************************************************
        -- Added by extract the ATP details from common staging ATP table for upc/inv_org_id
        --*****************************************************************************************

        CURSOR full_load_cur (p_inv_org_id NUMBER, p_inventory_item_id NUMBER, p_demand_class VARCHAR2)
        IS
              SELECT *
                FROM (SELECT SLNO, SKU, INVENTORY_ITEM_ID,
                             INV_ORGANIZATION_ID, DEMAND_CLASS_CODE, BRAND,
                             UOM_CODE, REQUESTED_SHIP_DATE, AVAILABLE_QUANTITY,
                             AVAILABLE_DATE
                        FROM XXD_MASTER_ATP_FULL_T xmat1
                       WHERE     INV_ORGANIZATION_ID = p_inv_org_id
                             AND inventory_item_id = p_inventory_item_id
                             AND application = 'ECOMM'
                             AND available_date IS NOT NULL
                             AND available_quantity >= 0
                             AND available_Quantity < 1000000
                             AND TRUNC (available_date) > TRUNC (SYSDATE)
                             AND DEMAND_CLASS_CODE = p_demand_class
                      UNION ALL
                      SELECT SLNO, SKU, INVENTORY_ITEM_ID,
                             INV_ORGANIZATION_ID, DEMAND_CLASS_CODE, BRAND,
                             UOM_CODE, REQUESTED_SHIP_DATE, AVAILABLE_QUANTITY,
                             AVAILABLE_DATE
                        FROM XXD_MASTER_ATP_FULL_T xmat2
                       WHERE     INV_ORGANIZATION_ID = p_inv_org_id
                             AND inventory_item_id = p_inventory_item_id
                             AND application = 'ECOMM'
                             AND available_date IS NOT NULL
                             AND available_quantity >= 0
                             AND available_Quantity < 1000000
                             AND DEMAND_CLASS_CODE = p_demand_class
                             AND TRUNC (AVAILABLE_DATE) =
                                 (SELECT MAX (TRUNC (AVAILABLE_DATE))
                                    FROM XXD_MASTER_ATP_FULL_T xmat3
                                   WHERE     INV_ORGANIZATION_ID = p_inv_org_id
                                         AND inventory_item_id =
                                             p_inventory_item_id
                                         AND application = 'ECOMM'
                                         AND xmat3.inventory_item_id =
                                             xmat2.inventory_item_id
                                         AND xmat3.inv_organization_id =
                                             xmat2.inv_organization_id
                                         AND xmat3.demand_class_code =
                                             xmat2.demand_class_code
                                         AND available_date IS NOT NULL
                                         AND TRUNC (available_date) <=
                                             TRUNC (SYSDATE)
                                         AND available_quantity >= 0
                                         AND DEMAND_CLASS_CODE = p_demand_class))
            ORDER BY INVENTORY_ITEM_ID, INV_ORGANIZATION_ID, AVAILABLE_DATE;
    BEGIN
        --Clear out the global temp tables from any previous run
        DELETE FROM APPS.GTT_INV_ATP;

        x_ret_status   := '';

        --Get the inventory_item_id from upc
        SELECT upc_to_iid (p_item_upc) INTO ln_inventory_item_id FROM DUAL;

        --Loop over each inventory org
        FOR n IN p_inv_org_ids.FIRST .. p_inv_org_ids.LAST
        LOOP
            BEGIN
                SELECT erp_org_id, pre_back_order_days, NVL (put_away_days, 0) put_away_days
                  INTO ln_epr_org, ln_pre_back_order_days, ln_put_away_days
                  FROM XXDO.XXDOEC_INV_FEED_CONFIG_V
                 WHERE     code = p_inv_region
                       AND inv_org_id = p_inv_org_ids (n)
                       AND brand_name = p_brand
                       AND ROWNUM <= 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    DBMS_OUTPUT.put_line (
                           'No Data found in XXDO.XXDOEC_INV_FEED_CONFIG_V for InvOrgId'
                        || p_inv_org_ids (n));
            END;

            ln_pre_back_order_mode        := 0;
            lv_upc_code                   := NULL;
            ln_inv_preorder               := 0;
            ln_pre_back_order_qty         := 0;
            ld_back_order_date            := NULL;
            lv_sku                        := NULL;
            ln_atp_when_atr               := 0;
            ln_atp                        := 0;
            ln_atr                        := 0;
            ln_pre_back_order_qty_final   := 0;

            FOR full_load_rec
                IN full_load_cur (p_inv_org_ids (n),
                                  ln_inventory_item_id,
                                  lv_demand_class)
            LOOP
                BEGIN
                    SELECT xci.inv_preorder, xci.upc_code, xci.item_number
                      INTO ln_inv_preorder, lv_upc_code, lv_sku
                      FROM xxd_common_items_v xci
                     WHERE     xci.inventory_item_id = ln_inventory_item_id
                           AND organization_id = p_inv_org_ids (n);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'In Exception while deriving ATP Buffer/UPC Code..'
                            || SQLERRM
                            || SQLCODE
                            || '--'
                            || full_load_rec.inventory_item_id
                            || '--'
                            || p_inv_org_ids (n));
                END;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'full_load_rec.available_date - '
                    || full_load_rec.available_date
                    || ' full_load_rec.requested_ship_date - '
                    || full_load_rec.requested_ship_date
                    || ' full_load_rec.AVAILABLE_QUANTITY -  '
                    || full_load_rec.AVAILABLE_QUANTITY);

                IF TRUNC (NVL (full_load_rec.available_date, SYSDATE + 1000)) <=
                   TRUNC (SYSDATE)
                THEN
                    ln_atp              := full_load_rec.AVAILABLE_QUANTITY;
                    ld_available_date   := SYSDATE;
                    ln_atr              := 0;
                    ln_atp_when_atr     := 0;

                    IF ln_atp > 0
                    THEN
                        ln_atr   :=
                            do_inv_utils_pub.item_atr_quantity (
                                p_organization_id   =>
                                    full_load_rec.inv_organization_id,
                                p_inventory_item_id   =>
                                    full_load_rec.inventory_item_id);

                        IF ln_atr < ln_atp
                        THEN
                            ln_atp_when_atr   := ln_atp; -- remember the value we replaced
                            ln_atp            := ln_atr;
                        END IF;
                    END IF;
                ELSIF TRUNC (NVL (full_load_rec.available_date, SYSDATE - 1)) >
                      TRUNC (SYSDATE)
                THEN
                    ld_back_order_date   := full_load_rec.available_date;
                    ln_pre_back_order_qty   :=
                        full_load_rec.AVAILABLE_QUANTITY;
                ELSE
                    ld_back_order_date      := NULL;
                    ln_pre_back_order_qty   := 0;
                END IF;

                IF ld_back_order_date IS NULL OR ln_pre_back_order_qty <= 0
                THEN
                    BEGIN
                        SELECT full_t1.available_date, full_t1.available_quantity
                          INTO ld_back_order_date, ln_pre_back_order_qty
                          FROM XXD_MASTER_ATP_FULL_T full_t1
                         WHERE     full_t1.inventory_item_id =
                                   full_load_rec.inventory_item_id
                               AND full_t1.inv_organization_id =
                                   full_load_rec.inv_organization_id
                               AND full_t1.demand_class_code =
                                   full_load_rec.demand_class_code
                               AND full_t1.application = 'ECOMM'
                               AND full_t1.available_date =
                                   (SELECT MIN (available_date)
                                      FROM XXD_MASTER_ATP_FULL_T full_t2
                                     WHERE     full_t2.inventory_item_id =
                                               full_t1.inventory_item_id
                                           AND full_t2.inv_organization_id =
                                               full_t1.inv_organization_id
                                           AND full_t2.demand_class_code =
                                               full_t1.demand_class_code
                                           AND full_t2.application = 'ECOMM'
                                           -- Start changes v1.3
                                           AND full_t2.available_quantity > 0
                                           -- End changes v1.3
                                           AND TRUNC (
                                                   NVL (
                                                       full_t2.available_date,
                                                       SYSDATE - 2)) >
                                               TRUNC (SYSDATE));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'In Exception while deriving Back Order Details..'
                                || SQLERRM
                                || SQLCODE);
                    END;
                END IF;

                IF ld_back_order_date <= SYSDATE + ln_pre_back_order_days
                THEN
                    ln_pre_back_order_qty_final   :=
                        ln_pre_back_order_qty_final + ln_pre_back_order_qty;
                END IF;
            END LOOP;

            --Insert Inventory Org Specific values to global temp table
            INSERT INTO APPS.GTT_INV_ATP (INV_ORG_ID, ATP_QTY, AVAILABLE_DATE
                                          , ATP_WHEN_ATR, PRE_BACK_ORDER_QTY)
                 VALUES (p_inv_org_ids (n), ln_atp, ld_available_date,
                         ln_atp_when_atr, ln_pre_back_order_qty_final);
        END LOOP;

        --populate returning cursor
        OPEN o_upc_quantity_cursor FOR SELECT * FROM APPS.GTT_INV_ATP;

        x_ret_status   := 'SUCCESS';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_status   :=
                   'An exception occurred while retrieving ATP records.'
                || g_newline;
            x_ret_status   := g_newline || ' SQLERRM: ' || SQLERRM;
            x_ret_status   :=
                   x_ret_status
                || g_newline
                || ' FORMAT_ERROR_BACKTRACE: '
                || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
            x_ret_status   :=
                   x_ret_status
                || g_newline
                || ' FORMAT_CALL_STACK: '
                || DBMS_UTILITY.FORMAT_CALL_STACK;

            DO_DEBUG_UTILS.WRITE (l_debug_loc => DO_EDI_UTILS_PUB.G_DEBUG_LOCATION, v_application_id => g_package_title || '.XXDOEC_UPDATE_ATP_TABLE', v_debug_text => x_ret_status
                                  , l_debug_level => 1);
            fnd_file.put_line (fnd_file.LOG,
                               'Unexpected Error - ' || SQLERRM);
    END xxdoec_get_atp_for_upc;
END XXDOEC_INVENTORY;
/
