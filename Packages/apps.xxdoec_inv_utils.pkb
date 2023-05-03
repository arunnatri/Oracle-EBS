--
-- XXDOEC_INV_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_INV_UTILS"
AS
    /****************************************************************************************
    * Package      : XXDOEC_INV_UTILS
    * Author       : BT Technology Team
    * Created      : 03-NOV-2014
    * Program Name :
    * Description  : Ecomm-29 - Catalog integration with EBS and E-commerce application
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer     Version    Description
    *--------------------------------------------------------------------------------------
    * 03-NOV-2014   BT Technology Team         1.00       Initial BT Version
    * 13-JUL-2020   Rohit Singh                1.01       CCR0008800 - Fix for UPCs with
                                                          leading zero
    ****************************************************************************************/

    /*
        WTF Inventory Utilities
        This package provides common utility functions for WTF inventory calculations

        Modifications:
            07-11-2011 - rkinsel - CCR0001720 - Refactor : creation
            04-27-1012 - rkinsel - INC0110714 -  Added to_seconds
            04-27-2012 - mbacigalupi - Added 3 new ref cursor routines for catalog processing
            04-24-2012 - mbacigalupi - Added new procedure to return data needed for order
                                         summary report modifications.
            05-29-2013 - mbacigalupi - added optimizer index hint for GetOrderSummaryMods procedure.
            05-29-2014 - rkinsel - AtTask#2722759
                 GetOrderSummaryMods returns four new fields (cancel_code, cancel_reason, ship_method_description, gift_wrap)
 */

    /* is_excluded
            Returns 1 if the given item is in custom.do_edi_805_exclusions and do_custom.do_ora_items_v
            Expects sr_inventory_item_id (from msc_system_items)
    */
    FUNCTION is_excluded (p_inventory_item_id IN NUMBER)
        RETURN NUMBER
    IS
        /* is_excluded is derived from the do_edi_805_processing.build_atp_table package */
        v_ret   NUMBER;
    BEGIN
        SELECT LEAST (NVL (SUM (1), 0), 1)
          INTO v_ret
          -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
          --        FROM custom.do_edi_805_exclusions excl, do_custom.do_ora_items_v itm
          FROM (SELECT flv.description brand, flv.tag color, flv.attribute1 style,
                       flv.attribute2 sze
                  FROM fnd_lookup_values flv
                 WHERE     flv.lookup_type = 'XXD_EDI_805_EXCLUSIONS'
                       AND language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN NVL (
                                                       TRUNC (
                                                           flv.start_date_active),
                                                       TRUNC (SYSDATE))
                                               AND NVL (
                                                       TRUNC (
                                                           flv.end_date_active),
                                                       TRUNC (SYSDATE))) excl,
               do_custom.do_ora_items_v itm
         -- End modification by BT Technology Team on 03-Nov-2014 v1.0
         WHERE     excl.brand = itm.brand
               AND NVL (excl.style, itm.style) = itm.style
               AND NVL (excl.color, itm.color) = itm.color
               AND NVL (excl.sze, itm.sze) = itm.sze
               AND itm.inventory_item_id = p_inventory_item_id;

        RETURN v_ret;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END is_excluded;

    /* next_calendar_date
             Returns the next calendar date following the given date, from apps.msc_calendar_dates
             Uses the current system time if no date is supplied
    */
    FUNCTION next_calendar_date (p_date IN DATE DEFAULT NULL)
        RETURN DATE
    IS
        v_next_calendar_day   DATE;
    BEGIN
        v_next_calendar_day   := NVL (p_date, TRUNC (SYSDATE));

        SELECT next_date
          INTO v_next_calendar_day
          -- Start modification by BT Technology Team on 05-Dec-2014 v1.0
          -- FROM apps.msc_calendar_dates
          FROM apps.msc_calendar_dates@bt_ebs_to_ascp
         -- End modification by BT Technology Team on 05-Dec-2014 v1.0
         WHERE     sr_instance_id = 1
               -- Start modification by BT Technology Team on 05-Dec-2014 v1.0
               --AND calendar_code = 'DEK:US 2000-30'
               AND calendar_code =
                   (SELECT profile_option_value
                      FROM fnd_profile_option_values@bt_ebs_to_ascp fpov, fnd_profile_options_vl@bt_ebs_to_ascp fpo
                     WHERE     fpo.profile_option_id = fpov.profile_option_id
                           AND profile_option_name = 'MSC_HUB_CAL_CODE'
                           AND level_id = 10001)
               AND exception_set_id = -1                   -- BT To be changed
               -- End modification by BT Technology Team on 05-Dec-2014 v1.0
               AND calendar_date = v_next_calendar_day;

        RETURN v_next_calendar_day;
    END next_calendar_date;

    /* kco_header_default
            Returns the KCO associated with an erp_org/inv_org/brand in xxdo.xxdoec_inv_feed_config_v
 ;   */
    /*
       FUNCTION kco_header_default (p_erporg_id      NUMBER,
                                    p_invorg_id   IN NUMBER,
                                    p_brand       IN VARCHAR2)
          RETURN NUMBER
       IS
          v_kco_header_id   NUMBER;
          v_date            DATE;
       BEGIN
          v_date := SYSDATE;

          SELECT MAX (NVL (kco_header_id, -1))
            INTO v_kco_header_id
            FROM xxdo.xxdoec_inv_feed_config_v
           WHERE     erp_org_id = p_erporg_id
                 AND inv_org_id = p_invorg_id
                 AND UPPER (brand_name) = UPPER (p_brand)
                 AND start_date < v_date
                 AND end_date > v_date;

          RETURN v_kco_header_id;
       END kco_header_default;
    /*
       /* least_not_null
                Returns the lesser of two numbers when neither input is null.
                Returns the non-null input is the other is null.
                Returns null if both inputs are null.
       */
    FUNCTION least_not_null (p_num1 IN NUMBER, p_num2 IN NUMBER)
        RETURN NUMBER
    IS
    BEGIN
        IF p_num1 IS NULL
        THEN
            RETURN p_num2;
        ELSIF p_num2 IS NULL
        THEN
            RETURN p_num1;
        ELSE
            RETURN LEAST (p_num1, p_num2);
        END IF;
    END least_not_null;

    /* to_number
             Returns the given date, converted to a number in this format: yyyymmdd
    */
    FUNCTION TO_NUMBER (p_date IN DATE)
        RETURN NUMBER
    IS
        v_date     DATE;
        v_retval   NUMBER;
    BEGIN
        IF p_date = NULL
        THEN
            v_retval   := 0;
        ELSE
            v_date   := TRUNC (p_date);
            v_retval   :=
                  EXTRACT (YEAR FROM v_date) * 10000
                + EXTRACT (MONTH FROM v_date) * 100
                + EXTRACT (DAY FROM v_date);
        END IF;

        RETURN v_retval;
    END TO_NUMBER;

    FUNCTION to_seconds (p_date_left IN DATE, p_date_right IN DATE)
        RETURN VARCHAR2
    IS
    BEGIN
        /*
            calculate the difference between the given dates,
            return the difference as a VARCHAR2, in seconds, to the nearest 1/100th.
        */
        RETURN TO_CHAR (ROUND ((p_date_left - p_date_right) * 86400.0, 1),
                        'TM');
    END to_seconds;

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100, p_runnum NUMBER:= -1
                   , p_header_id NUMBER:= -1, p_category VARCHAR2:= 'I')
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, MESSAGE);

        INSERT INTO xxdo.XXDOEC_PROCESS_ORDER_LOG
                 VALUES (xxdo.XXDOEC_SEQ_PROCESS_ORDER.NEXTVAL,
                         MESSAGE,
                         CURRENT_TIMESTAMP);

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END msg;

    PROCEDURE GetBrands (brand_list OUT t_brand_cursor)
    IS
    BEGIN
        OPEN brand_list FOR
            SELECT DISTINCT (segment1) AS brand
              FROM apps.mtl_categories_b
             -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
             --WHERE structure_id = 101;
             WHERE structure_id IN (SELECT structure_id
                                      FROM mtl_category_sets
                                     WHERE CATEGORY_SET_NAME = 'Inventory');
    --End modification by BT Technology Team on 03-Nov-2014 v1.0
    END;

    PROCEDURE GetSeasons (season_list OUT t_season_cursor)
    IS
    BEGIN
        OPEN season_list FOR SELECT 'FALL 2012' AS season FROM DUAL
                             UNION ALL
                             SELECT 'SPRING 2013' AS season FROM DUAL;
    END;


    PROCEDURE GetSkus (p_brand IN apps.mtl_system_items_b.attribute1%TYPE, p_season IN apps.mtl_categories_b.segment1%TYPE, sku_list OUT t_sku_cursor)
    IS
    BEGIN
        OPEN sku_list FOR
              SELECT DISTINCT      -- LTRIM (mcr.cross_reference, '0') AS upc,
                              --CCR0008800 on 13-July-2020
                              --Below line was commented to fix issues with UPCs having leading zero.
                              --LTRIM was removed and msib.upc_code is check first instead of mcr.cross_reference
                              --LTRIM (NVL(mcr.cross_reference,msib.upc_code), '0') AS upc,
                              NVL (msib.upc_code, mcr.cross_reference) AS upc, --    msib.segment1 || '-' || msib.segment2 || '-' || msib.segment3
                                                                               msib.item_number AS oraclesku, --                  msib.segment1 AS style,
                                                                                                              --                  msib.segment2 AS color,
                                                                                                              --                  msib.segment3 AS sze,
                                                                                                              --                  ffv_colors.description AS color_name,
                                                                                                              msib.style_number AS style,
                              msib.color_code AS color, msib.item_size AS sze, msib.color_desc AS color_name,
                              -- End modification by BT Technology Team on 03-Nov-2014 v1.0
                              msib.item_description AS description
                FROM                             --apps.mtl_system_items msib,
                     xxd_common_items_v msib, apps.mtl_cross_references mcr, -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
                                                                             --                  apps.mtl_categories_b mcb,
                                                                             --                  apps.mtl_item_categories mic,
                                                                             --                  apps.fnd_flex_values_vl ffv_styles,
                                                                             --                  apps.fnd_flex_values_vl ffv_colors,
                                                                             -- End modification by BT Technology Team on 03-Nov-2014 v1.0
                                                                             apps.hr_organization_units horg,
                     apps.mtl_parameters mpar
               WHERE     msib.organization_id = mcr.organization_id(+)
                     AND msib.inventory_item_id = mcr.inventory_item_id(+)
                     -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
                     --                  AND msib.organization_id = mic.organization_id
                     --                  AND msib.inventory_item_id = mic.inventory_item_id
                     --                  AND mic.category_id = mcb.category_id
                     --                  AND ffv_styles.flex_value(+) = msib.segment1
                     --                  AND ffv_colors.flex_value(+) = msib.segment2
                     -- End modification by BT Technology Team on 03-Nov-2014 v1.0
                     AND msib.organization_id = horg.organization_id
                     AND msib.organization_id = mpar.organization_id
                     -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
                     --                  AND msib.segment3 <> 'ALL'
                     AND msib.item_type != 'GENERIC'
                     --                  AND mic.category_set_id = 1
                     --                  AND ffv_styles.flex_value_set_id(+) = 1003729
                     --                  AND ffv_colors.flex_value_set_id(+) = 1003724
                     -- End modification by BT Technology Team on 03-Nov-2014 v1.0
                     AND SYSDATE BETWEEN NVL (horg.date_from, SYSDATE - 1)
                                     AND NVL (horg.date_to, SYSDATE + 1)
                     AND mpar.wms_enabled_flag = 'Y' -- if warehouse is enabled
                     -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
                     --                  AND mcb.segment1 = p_brand                           --'UGG'
                     AND msib.brand = p_brand
                     --                  AND msib.attribute1 = p_season                 --'FALL 2012'
                     AND msib.curr_active_season = p_season
            -- End modification by BT Technology Team on 03-Nov-2014 v1.0
            --                  AND mcr.cross_reference_type = 'UPC Cross Reference'
            --and msib.segment1 IN ('AF1192','AF1157')
            --         ORDER BY msib.segment1, msib.segment2, msib.segment3;
            ORDER BY msib.style_number, msib.color_code, msib.item_size;
    END;


    PROCEDURE GetStyleColorSize (p_upc IN apps.mtl_system_items_b.attribute11%TYPE, styleColorSize_list OUT t_styleColorSize_cursor)
    IS
    BEGIN
        OPEN styleColorSize_list FOR
            -- Start modification by BT Technology Team on 03-Nov-2014 v1.0
            /*
            SELECT segment1, segment2, segment3
              FROM apps.mtl_system_items_b
             WHERE attribute11 = p_upc AND organization_id = 7;
            */
            SELECT style_number, color_code segment2, item_size
              FROM apps.xxd_common_items_v
             WHERE upc_code = p_upc AND master_org_flag = 'Y';
    -- End modification by BT Technology Team on 03-Nov-2014 v1.0
    END;

    PROCEDURE GetOrderSummaryMods (
        p_list                IN     t_order_array,
        orders_shipped_list      OUT t_orders_shipped_list)
    IS
        l_rc        NUMBER := 0;
        l_err_num   NUMBER := -1;                             --error handling
        l_err_msg   VARCHAR2 (100) := '';                     --error handling
        l_message   VARCHAR2 (1000) := '';            --for message processing
        DCDLog      DCDLog_type;
    BEGIN
        --Delete anything this process may have left in the global
        --temporary table.

        DELETE FROM xxdoec_file_worker_table;

        --Mass dump the orderId's into the global temporary table

        FORALL i IN p_list.FIRST .. p_list.LAST
            INSERT INTO apps.xxdoec_file_worker_table (orderId)
                 VALUES (p_list (i));

        --Update the orderId's just in case we were given a quote'"'

        UPDATE apps.xxdoec_file_worker_table
           SET orderId   = TRANSLATE (orderId, 'A"', 'A');

        --Open and return the cursor
        -- Taken from the order summary report as per requirements.
        -- 5-29-2013 For some reason this was doing a full table scan on
        -- oe_order_headers_all and that is a no-no, so added index hint.
        -- testing add of DISTINCT and removal of line_id so we can get
        -- unique values back to put into hash table for faster matchup in c#
        OPEN orders_shipped_list FOR
            SELECT /*+ INDEX(ooh OE_ORDER_HEADERS_U1) */
                   DISTINCT ool.cust_po_number,                 --ool.line_id,
                            ool.attribute20,
                            flv_cls.meaning,
                            (CASE
                                 WHEN     TRUNC (
                                                ool.latest_acceptable_date
                                              - ooh.ordered_date) >=
                                          20
                                      AND ool.actual_shipment_date
                                              IS NULL
                                      AND ool.cancelled_flag =
                                          'N'
                                 THEN
                                     'Yes'
                                 WHEN    TRUNC (
                                               ool.latest_acceptable_date
                                             - ooh.ordered_date) <
                                         20
                                      OR ((ool.actual_shipment_date IS NOT NULL) OR (ool.cancelled_flag = 'Y'))
                                 THEN
                                     'No'
                                 ELSE
                                     'No'
                             END) back_ordered,
                            NVL (ors.reason_code,
                                 '') cancel_code,
                            NVL (flv_can.meaning,
                                 '') cancel_meaning,
                            NVL (
                                flv_smc.description,
                                '') ship_method_description,
                            CASE
                                WHEN EXISTS
                                         (SELECT 1
                                            FROM apps.oe_price_adjustments opa
                                           WHERE     opa.charge_type_code =
                                                     'GIFTWRAP'
                                                 AND opa.line_id =
                                                     ool.line_id)
                                THEN
                                    'Yes'
                                ELSE
                                    'No'
                            END gift_wrap,
                            msib.inventory_item_id,
                            msib.attribute11
              FROM apps.oe_order_lines_all ool
                   JOIN apps.xxdoec_file_worker_table d
                       ON d.orderid = ool.cust_po_number
                   JOIN apps.oe_order_headers_all ooh
                       ON ool.header_id = ooh.header_id
                   LEFT JOIN apps.fnd_lookup_values flv_cls
                       ON     flv_cls.lookup_type =
                              'DOEC_OEOL_CUSTOM_STATUSES'
                          AND flv_cls.LANGUAGE = 'US'
                          AND flv_cls.lookup_code = ool.attribute20
                   LEFT JOIN inv.mtl_system_items_b msib
                       -- Start modification by BT Technology Team on 05-Dec-2014 v1.0
                       --  ON     msib.organization_id = 7                --ool.org_id
                       ON     msib.organization_id IN
                                  (SELECT organization_id
                                     FROM org_organization_definitions
                                    WHERE organization_name =
                                          'MST_Deckers_Item_Master')
                          -- End modification by BT Technology Team on 05-Dec-2014 v1.0
                          AND msib.inventory_item_id = ool.inventory_item_id
                   LEFT JOIN apps.oe_reasons ors
                       ON     ors.entity_code = 'LINE'
                          AND ors.reason_type = 'CANCEL_CODE'
                          AND ors.entity_id = ool.line_id
                   LEFT JOIN apps.fnd_lookup_values flv_can
                       ON     flv_can.lookup_type = 'CANCEL_CODE'
                          AND flv_can.lookup_code = ors.reason_code
                          AND flv_can.language = 'US'
                   LEFT JOIN apps.wsh_delivery_details wdd
                       ON wdd.source_line_id = ool.line_id
                   LEFT JOIN apps.fnd_lookup_values flv_smc
                       ON     flv_smc.lookup_code = wdd.ship_method_code
                          AND wdd.source_code = 'OE'
                          AND flv_smc.lookup_type = 'SHIP_METHOD'
                          AND flv_smc.language = 'US';
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                l_err_num             := SQLCODE;
                l_err_msg             := SUBSTR (SQLERRM, 1, 100);
                l_message             := 'ERROR GetOrderSummaryMods:  ';
                l_message             :=
                       l_message
                    || ' err_num='
                    || TO_CHAR (l_err_num)
                    || ' err_msg='
                    || l_err_msg
                    || '.';
                DCDLog.ChangeCode (P_CODE => -10102, P_APPLICATION => G_APPLICATION, P_LOGEVENTTYPE => 1
                                   , P_TRACELEVEL => 1, P_DEBUG => 0);
                DCDLog.FunctionName   := 'GetOrderSummaryMods';
                DCDLog.AddParameter ('SQLCODE',
                                     TO_CHAR (l_err_num),
                                     'NUMBER');
                DCDLog.AddParameter ('SQLERRM', l_err_msg, 'VARCHAR2');
                l_rc                  := DCDLog.LogInsert ();

                IF (l_rc <> 1)
                THEN
                    msg (DCDLog.l_message);
                END IF;
            END;
    END;
END XXDOEC_INV_UTILS;
/
