--
-- XXDO_PO_LISTING_BY_SIZE  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_LISTING_BY_SIZE"
IS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Subsystem       : SCP
    --  Project         : Supply Chain Planning
    --  Description     : Package for
    --  Module          : XXDO_PO_LISTING_BY_SIZE
    --  File            : XXDO_PO_LISTING_BY_SIZE.pkb
    --  Schema          : XXDO
    --  Date            : 12-Sep-2013
    --  Version         : 1.0
    --  Author(s)       : Tejaswi Gangumalla[ Suneratech Consulting]
    --  Purpose         : This package is called for the PO Listing Report by Size
    --
    --
    --  dependency      :
    --  Change History
    --  --------------
    --  Date            Name                     Ver        Change         Description
    --  ----------      --------------          -----     ---------    ------------------
    --  12-Sep-2013     Tejaswi Gangumalla       1.0                      Initial Version
    --  05-May-2014     Anil Suddapalli          1.1                      ENHC0011973
    --  04-Apr-2015     BT Technology Team v1.2  1.2                      Retrofitted
    --  17-NOV-2015     BT Technology Team v1.3  1.3                      Defect # 3486 fix
    --  17-MAY-2016     Infosys deckers support  1.4                      INC0293852
    --  23-JAN-2017     Infosys                  1.5      CCR0005924   i) Condition Changed for Parameter p_sample; Identified by ITEM_TYPE
    --                                                                ii) Extra Spaces were getting generated in the report;
    --                                                                    Identified by EXTRA_SPACES
    --                                                               iii) Added Condition Buyer not as "SFS BUYER"; Identified by SFS_BUYER
    --  07-JUN-2017     Infosys                  1.6      PRB0041345      When Distinct Sizes count is greater than 100, then report is not
    --                                                                    getting generated. IDENTIFIED by PRB0041345
    --  22-JUN-2017     Infosys                  1.7      CCR0006426      Report is modified for Performance Issues; IDENTIFIED by CCR0006426
    --  25-JUL-2017     Infosys                  1.8      CCR0006536      revert back the old cursor item_sizes_cur to increase the performance
    --  13-MAR-2018     Infosys                  1.9      CCR0007113      PO Listing Report with Size is showing some sizes as dates instead of sizes
    --  09-May-2018     Arun N Murthy            1.91     CCR0007275      Adding lookup for "SFS BUYER"
    --  21-Aug-2018     Srinath Siricilla        2.0      CCR0007335      Added Item_Type category segment
    --  26-Aug-2019     Srinath Siricilla        2.1      CCR0008126
    --  27-APR-2020     Srinath Siricilla        2.2      CCR0008549
    --  03-JUN-2020     Aravind Kannuri          2.3      CCR0008693
    --  10-Oct-2020     Gaurav Joshi             2.4      CCR0008786  Modified Unit price and Blended FOB logic
    --  14-OCT-2021     Showkath ALi             2.5      CCR0009609
    --  ###################################################################################

    -- Start of Change 2.2

    -- End of Change 2.2

    FUNCTION get_dest_name (pv_dest_name   IN VARCHAR2,
                            pn_vendor_id   IN NUMBER,
                            pv_po_number   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_dest_name    VARCHAR2 (100) := NULL;
        lv_party_name   VARCHAR2 (100) := NULL;
        ln_count        NUMBER := NULL;
    BEGIN
        IF pv_dest_name IS NOT NULL
        THEN
            BEGIN
                SELECT DISTINCT party_name              --Added as per ver 2.3
                  -- SELECT party_name        --Commented as per ver 2.3
                  INTO lv_dest_name
                  FROM apps.hz_parties
                 WHERE party_name = pv_dest_name;

                RETURN lv_dest_name;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_dest_name   := NULL;
            END;

            IF lv_dest_name IS NULL
            THEN
                BEGIN
                    SELECT meaning
                      INTO lv_dest_name
                      FROM fnd_lookup_values
                     WHERE     lookup_type = 'XXD_PO_TRADE_ORGS'
                           AND meaning = pv_dest_name
                           AND tag = 'DP'
                           AND language = 'US'
                           AND enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (start_date_active,
                                                    SYSDATE)
                                           AND NVL (end_date_active, SYSDATE);

                    RETURN lv_dest_name;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_dest_name   := NULL;
                END;

                IF lv_dest_name IS NULL
                THEN
                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_count
                          FROM apps.ap_suppliers
                         WHERE     vendor_id = pn_vendor_id
                               AND vendor_type_lookup_code = 'TQ PROVIDER';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_count   := 0;
                    END;

                    IF ln_count > 0
                    THEN
                        lv_dest_name   := pv_dest_name;
                        RETURN lv_dest_name;
                    END IF;

                    IF ln_count = 0
                    THEN
                        BEGIN
                            SELECT DISTINCT hp.party_name
                              INTO lv_dest_name
                              FROM hz_cust_accounts hca, hz_parties hp, oe_order_headers_all ooha,
                                   oe_drop_ship_sources odss, po_headers_all poh
                             WHERE     1 = 1
                                   AND hca.cust_account_id =
                                       ooha.sold_to_org_id
                                   AND hca.party_id = hp.party_id
                                   AND ooha.header_id = odss.header_id
                                   AND odss.po_header_id = poh.po_header_id
                                   AND poh.segment1 = pv_po_number;

                            RETURN lv_dest_name;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                BEGIN
                                    SELECT DISTINCT hp.party_name
                                      INTO lv_dest_name
                                      FROM oe_order_lines_all oola, oe_order_headers_all ooha, hz_cust_accounts hca,
                                           hz_parties hp, po_line_locations_all plla, po_headers_all poh
                                     WHERE     oola.header_id =
                                               ooha.header_id
                                           AND ooha.sold_to_org_id =
                                               hca.cust_account_id
                                           AND hca.party_id = hp.party_id
                                           AND oola.attribute16 =
                                               TO_CHAR (
                                                   plla.line_location_id)
                                           AND NVL (oola.context, 'X') !=
                                               'DO eCommerce'
                                           AND plla.po_header_id =
                                               poh.po_header_id
                                           AND poh.segment1 = pv_po_number;

                                    RETURN lv_dest_name;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        lv_dest_name   := NULL;
                                END;
                            WHEN OTHERS
                            THEN
                                lv_dest_name   := NULL;
                        END;

                        RETURN lv_dest_name;            --Added as per ver 2.3
                    END IF;
                END IF;
            END IF;
        ELSE
            RETURN NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_dest_name;

    -- Start of Change 2.1

    FUNCTION get_region (p_country IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_region   VARCHAR2 (100) := NULL;
    BEGIN
        SELECT tag
          INTO lv_region
          FROM apps.fnd_lookup_values
         WHERE     lookup_type = 'XXD_PO_COUNTRY_REGION_MAPPING'
               AND lookup_code = p_country
               AND language = USERENV ('lang')
               AND enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                               AND NVL (end_date_active, SYSDATE + 1);

        RETURN lv_region;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_region   := NULL;
            RETURN lv_region;
    END;

    -- End of Change

    PROCEDURE main_data (pv_errbuff OUT VARCHAR2, pn_retcode OUT VARCHAR2, p_po_date_lo IN VARCHAR2, p_po_date_hi IN VARCHAR2, p_po_number_lo IN VARCHAR2, p_po_number_hi IN VARCHAR2, p_vendor_name IN VARCHAR2, p_sort_by IN VARCHAR2, p_sample IN VARCHAR2, p_brand IN VARCHAR2, p_style IN VARCHAR2, p_color IN VARCHAR2, p_sales_region IN VARCHAR2, p_sizes IN VARCHAR2, p_product_group IN VARCHAR2, p_buy_month IN VARCHAR2, p_buy_season IN VARCHAR2, p_conf_ex_fact_date_lo IN VARCHAR2
                         , p_conf_ex_fact_date_hi IN VARCHAR2)
    IS
        CURSOR main_data_cur IS
              SELECT vendor_name,
                     po_date,
                     po_number,
                     ship_to_location_id ship_loc_id,
                     style,
                     style_name,
                     color,
                     ex_factory_date requested_xf_date,
                     conf_ex_factory_date confirmed_xf_date,
                     promised_date,
                     dest,
                     brand,
                     SUM (po_qty) po_shipment_qty,
                     SUM (rcv_qty) rcv_qty,
                     SUM (bal_qty) bal_qty,
                     unit_price,
                     buy_month,
                     buy_season,
                     facility,
                     etd_port,
                     SUM (total_price) total_price,
                     -- Start changes for CCR0007335
                     (SELECT mc.segment1
                        FROM apps.mtl_categories_b mc
                       WHERE mc.category_id =
                             (SELECT mic.category_id
                                FROM apps.mtl_item_categories mic, apps.mtl_category_sets mcs, apps.xxd_common_items_v xciv,
                                     apps.mtl_parameters mp
                               WHERE     mic.category_set_id =
                                         mcs.category_set_id
                                     AND mcs.category_set_name = 'ITEM_TYPE'
                                     AND mic.organization_id =
                                         xciv.organization_id
                                     AND mic.inventory_item_id =
                                         xciv.inventory_item_id
                                     AND mic.organization_id =
                                         mp.organization_id
                                     AND mp.organization_code = 'MST'
                                     AND xciv.style_number = style
                                     AND xciv.color_code = color
                                     AND xciv.item_type <> 'GENERIC' -- Added for Change 2.1
                                     AND ROWNUM = 1)) item_type-- End changes for CCR0007335
                                                               ,
                     product_category                  -- Added for Change 2.1
                                     ,
                     po_type                           -- Added for Change 2.1
                            ,
                     country                           -- Added for Change 2.1
                            ,
                     get_region (country) region       -- Added for Change 2.1
                                                -- Start of Change 2.2
                                                ,
                     global_surcharge,
                     ship_to_id_surcharge,
                     blended_fob-- End of Change 2.2
                                ,
                     gtn_transfer_flag                                  -- 2.5
                                      ,
                     so_number                                          -- 2.5
                FROM xxdo_main_data
            GROUP BY vendor_name, po_date, po_number,
                     ship_to_location_id, style, style_name,
                     color, ex_factory_date, conf_ex_factory_date,
                     promised_date, dest, brand,
                     unit_price, buy_month, buy_season,
                     facility, etd_port, -- Start of Change 2.1
                                         product_category,
                     po_type, country, -- End of Change
                                       -- Start of Change 2.2
                                       global_surcharge,
                     ship_to_id_surcharge, blended_fob, -- End of change
                                                        gtn_transfer_flag, --2.5
                     so_number;                                          --2.5

        CURSOR item_sizes_cur IS
              SELECT DISTINCT item_size
                FROM xxdo_main_data
            ORDER BY item_size;

        CURSOR report_data_cur IS
            SELECT abc.ROWID, abc.*
              FROM xxdo_po_listing_headers abc
             WHERE attribute1 <> 'Vendor Name';

        -- Start CCR0006426

        CURSOR po_item_sizes (pv_po_number   IN VARCHAR2,
                              pv_style       IN VARCHAR2,
                              pv_color       IN VARCHAR2)
        IS
              SELECT DISTINCT item_size
                FROM xxdo_main_data av
               WHERE     1 = 1
                     AND EXISTS
                             (SELECT 1
                                FROM mtl_system_items_b msib, po_lines_all pla, po_headers_all pha,
                                     mtl_parameters mpa
                               WHERE     msib.organization_id =
                                         mpa.organization_id
                                     AND mpa.organization_code = 'MST'
                                     AND SUBSTR (
                                             msib.segment1,
                                             1,
                                             INSTR (msib.segment1, '-', 1) - 1) =
                                         pv_style
                                     AND SUBSTR (
                                             msib.segment1,
                                             INSTR (msib.segment1, '-', 1) + 1,
                                             (  (INSTR (msib.segment1, '-', 1,
                                                        2))
                                              - (  INSTR (msib.segment1, '-', 1
                                                          , 1)
                                                 + 1))) =
                                         pv_color
                                     AND SUBSTR (msib.segment1,
                                                   INSTR (msib.segment1, '-', 1
                                                          , 2)
                                                 + 1) = av.item_size
                                     AND pla.item_id = msib.inventory_item_id
                                     AND pla.po_header_id = pha.po_header_id
                                     AND pha.segment1 = pv_po_number)
            ORDER BY av.item_size;

        -- End CCR0006426

        CURSOR total_cur IS
            SELECT *
              FROM xxdo_po_listing_headers
             WHERE attribute12 = 'Total:';

        ln_count_num     NUMBER;
        lv_column_name   VARCHAR2 (100);
        lv_query         VARCHAR2 (1000);
        ln_po_qty        NUMBER;
        ln_tot_qty       NUMBER;
        ex_from_date     DATE
            := apps.fnd_date.canonical_to_date (p_conf_ex_fact_date_lo);
        ex_to_date       DATE
            := apps.fnd_date.canonical_to_date (p_conf_ex_fact_date_hi);
        po_from_date     DATE
            := apps.fnd_date.canonical_to_date (p_po_date_lo);
        po_to_date       DATE
            := apps.fnd_date.canonical_to_date (p_po_date_hi);
        /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
        lv_destname      VARCHAR2 (2000);
        /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
        l_count          NUMBER := 0;                            -- CCR0006426
        ln_qty           NUMBER := 0;
    BEGIN
        COMMIT;

        IF p_sample = 'BOTH'
        THEN
            IF ((p_conf_ex_fact_date_lo IS NULL) AND (p_conf_ex_fact_date_hi IS NULL))
            THEN
                INSERT INTO xxdo_main_data
                    (  SELECT dpd.vendor_name,
                              dpd.po_date,
                              dpd.po_number,
                              dpd.ship_to_location_id,
                              dpd.style,
                              --dpd.style_name, -- Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                              dpd.color,
                              dpd.item_size,
                              TO_CHAR (dpd.ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.conf_ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.promised_date, 'DD-MON-YYYY') --,dpd.country dest
                                                                        ,
                              -- Start CCR0006426
                              /*DECODE (
                                 rc.customer_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 rc.customer_name)
                                 dest*/
                              -- Start of change 2.2
                              /*DECODE (
                                 hp.party_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 hp.party_name)
                                 dest */
                              -- End CCR0006426
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --,mcb.segment1 brand
                              /* --START Commented as per ver 2.3
                              get_dest_name(
                              DECODE (
                                 hp.party_name,
                                 '', mp.organization_code,
                                 hp.party_name),pha.vendor_id,pha.segment1)
                                 dest
                              -- End of change
            */
                              --END Commented as per ver 2.3
                              --START Added as per ver 2.3
                              NVL (
                                  get_dest_name (
                                      DECODE (hp.party_name,
                                              '', mp.organization_code,
                                              hp.party_name),
                                      pha.vendor_id,
                                      pha.segment1),
                                  dpd.location_code)
                                  dest,
                              --END Added as per ver 2.3
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --,mcb.segment1 brand
                              xci.brand
                                  brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                       ,
                                NVL (SUM (dpd.line_quantity), 0)
                              - NVL (SUM (dpd.cancelled_quantity), 0)
                                  po_qty,
                              NVL (SUM (dpd.received_quantity), 0)
                                  rcv_qty,
                              ((NVL (SUM (dpd.line_quantity), 0) - NVL (SUM (dpd.cancelled_quantity), 0)) - (NVL (SUM (dpd.received_quantity), 0)))
                                  bal_qty,
                              --pol.unit_price,  -- commented ver 2.4
                              NVL (pol.attribute11, pol.unit_price)
                                  unit_price,                  --added ver 2.4
                              dpd.buy_month,
                              dpd.buy_season  --,dpsd.comments_5 facility_site
                                            ,
                              --pvsa.vendor_site_code facility_site, -- added by Anil as part of ENHC0011973
                              NVL (pol.attribute7, pvsa.vendor_site_code)
                                  facility_site,     -- Aded as per Change 2.1
                              -- Start of Change 2.2
                              NULL
                                  etd_port,
                              /*DECODE (
                                 (SELECT msa.attribute1
                                    FROM apps.mrp_sourcing_rules msr,
                                         apps.mrp_sr_assignments msa,
                                         apps.mrp_assignment_sets msas,
                                         apps.fnd_lookup_values fnl
                                         --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                         --,apps.mtl_item_categories mic
                                         --,apps.mtl_categories_b mcb
                                         ,xxd_common_items_v xci
                                         --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                                         ,apps.mtl_parameters mtp
                                   WHERE     msr.sourcing_rule_id =
                                                msa.sourcing_rule_id
                                         AND msas.assignment_set_id =
                                                msa.assignment_set_id
                                         AND msa.inventory_item_id IS NULL
                                         AND msas.assignment_set_name = 'AS - US'
                                         AND msr.status = 1
                                         AND fnl.lookup_code = msa.assignment_type
                                         AND NVL (fnl.end_date_active,
                                                  TRUNC (SYSDATE + 1)) >=
                                                TRUNC (SYSDATE)
                                         AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                         AND fnl.lookup_type = 'MRP_ASSIGNMENT_TYPE'
                                         AND fnl.language = 'US'
                                         --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                         --AND    mic.category_id = mcb.category_id
                                         --AND    mic.category_id = msa.category_id
                                         -- AND    mic.category_set_id = msa.category_set_id
                                         -- AND    mtp.organization_id = mic.organization_id
                                         AND xci.category_id = msa.category_id
                                         AND xci.category_set_id =
                                                msa.category_set_id
                                         AND mtp.organization_id =
                                                xci.organization_id
                                         --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                                         AND mtp.organization_code = 'VNT'
                                         AND fnl.meaning = 'Category'
                                         AND ROWNUM <= 1),
                                 NULL, (SELECT msa.attribute1
                                          FROM apps.mrp_sourcing_rules msr,
                                               apps.mrp_sr_assignments msa,
                                               apps.mrp_assignment_sets msas,
                                               apps.fnd_lookup_values fnl
                                         WHERE     msa.sourcing_rule_id =
                                                      msr.sourcing_rule_id
                                               AND msas.assignment_set_id =
                                                      msa.assignment_set_id
                                               AND msa.inventory_item_id IS NOT NULL
                                               AND msas.assignment_set_name =
                                                      'AS - US'
                                               AND msr.status = 1
                                               AND fnl.lookup_code =
                                                      msa.assignment_type
                                               AND NVL (fnl.end_date_active,
                                                        TRUNC (SYSDATE + 1)) >=
                                                      TRUNC (SYSDATE)
                                               AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                               AND fnl.lookup_type =
                                                      'MRP_ASSIGNMENT_TYPE'
                                               AND fnl.language = 'US'
                                               AND fnl.meaning = 'Item'
                                               AND ROWNUM <= 1),
                                 NULL)
                                 etd_port,*/
                              -- End of Change
                              SUM (pol.quantity * pol.unit_price)
                                  total_price,
                              -- Start of Change 2.1
                              xci.department
                                  product_category,
                              pha.attribute10
                                  po_type,
                              dpd.country
                                  country,
                              -- End of Change 2.1
                              -- Start of change 2.2
                              pol.attribute8
                                  global_surcharge,
                              pol.attribute9
                                  ship_to_id_surcharge,
                              --    NVL(pol.unit_price,0) blended_fob  -- commented ver 2.4
                              (NVL (pol.attribute11, pol.unit_price) + NVL (pol.attribute8, 0) + NVL (pol.attribute9, 0))
                                  blended_fob,                -- added ver 2.4
                              -- End of change 2.2
                              pha.attribute11
                                  gtn_transfer_flag,                     --2.5
                              DECODE (
                                  pha.attribute10,
                                  'XDOCK', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                              FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                             WHERE     ooha.header_id =
                                                       oola.header_id
                                                   AND oola.attribute15 =
                                                       TO_CHAR (
                                                           plla.line_location_id)
                                                   AND NVL (
                                                           oola.cancelled_flag,
                                                           'N') <>
                                                       'Y'
                                                   AND NVL (oola.context, 'X') !=
                                                       'DO eCommerce'
                                                   AND plla.po_line_id =
                                                       pol.po_line_id),
                                  'DIRECT_SHIP', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                                    FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                                   WHERE     ooha.header_id =
                                                             oola.header_id
                                                         AND oola.attribute16 =
                                                             TO_CHAR (
                                                                 plla.line_location_id)
                                                         AND NVL (
                                                                 oola.cancelled_flag,
                                                                 'N') <>
                                                             'Y'
                                                         AND NVL (oola.context,
                                                                  'X') !=
                                                             'DO eCommerce'
                                                         AND plla.po_line_id =
                                                             pol.po_line_id),
                                  NULL)
                                  so_number                              --2.5
                         FROM /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                              -- apps.do_po_details_v dpd
                                              --,apps.mtl_categories_b mcb
                                              --,apps.mtl_item_categories mic
                                               --,apps.ra_customers rc
                                                -- ,apps.fnd_lookup_values_vl sales_reg
                                                 --  ,do_custom.do_po_shipment_details dpsd
                                                 --,apps.po_vendor_sites_all pvsa   -- Commented the above line and added this table by Anil as part of ENHC0011973
                              */
                              apps.do_po_details dpd, apps.po_lines_all pol, apps.xxd_common_items_v xci,
                              --xxd_ra_customers_v rc,   -- Commented CCR0006426
                              apps.hz_cust_accounts hca,   -- Added CCR0006426
                                                         apps.hz_parties hp, -- Added CCR0006426
                                                                             apps.oe_order_headers_all oeh,
                              apps.mtl_parameters mp, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                              apps.po_headers_all pha, ap_supplier_sites_all pvsa, apps.po_agents_v pav -- SFS_BUYER
                        /*----------------------------------------------------------------------------------------
                        End changes by BT Technology Team v1.2 on 02-APR-2015
                        ----------------------------------------------------------------------------------------*/
                        WHERE --mic.inventory_item_id = dpd.item_id --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                  xci.inventory_item_id = dpd.item_id --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                              AND pol.po_line_id = dpd.po_line_id
                              --AND pol.attribute_category = 'PO Data Elements'    -- Aded as per Change 2.1
                              /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                              AND      mcb.structure_id = 101
                                              AND      mic.category_set_id = 1
                                              AND      mic.organization_id = dpd.ship_to_organization_id
                                              AND      mic.organization_id = mp.organization_id
                                              */
                              AND xci.organization_id = mp.organization_id
                              AND xci.organization_id =
                                  dpd.ship_to_organization_id
                              /*----------------------------------------------------------------------------------------
                              End changes by BT Technology Team v1.2 on 02-APR-2015
                              ----------------------------------------------------------------------------------------*/
                              --AND      mp.attribute1 = sales_reg.lookup_code(+)
                              AND mp.attribute1 = ffv.flex_value(+)
                              /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                              --AND      sales_reg.lookup_type(+) = 'DO_SALES_REGIONS'
                                              --AND      mcb.segment2 = NVL (p_product_group, mcb.segment2)
                                              --AND      mcb.category_id = mic.category_id
                               */
                              AND ffvs.flex_value_set_name = 'DO_SALES_REGION'
                              AND ffv.flex_value_set_id =
                                  ffvs.flex_value_set_id
                              AND mp.attribute1 =
                                  NVL (p_sales_region, mp.attribute1)
                              AND xci.department =
                                  NVL (p_product_group, xci.department)
                              /*----------------------------------------------------------------------------------------
                              End changes by BT Technology Team v1.2 on 02-APR-2015
                              ----------------------------------------------------------------------------------------*/
                              AND dpd.order_header_id = oeh.header_id(+)
                              --AND oeh.sold_to_org_id = rc.customer_id(+) -- Commented CCR0006426
                              AND oeh.sold_to_org_id = hca.cust_account_id(+) -- Added CCR0006426
                              AND hca.party_id = hp.party_id(+) -- Added CCR0006426
                              AND dpd.po_header_id = pha.po_header_id
                              AND dpd.org_id = pha.org_id
                              --                AND      dpd.po_header_id = dpsd.po_header_id(+)
                              --                AND      dpd.color = dpsd.color(+)
                              --                AND      dpd.ship_to_location_id = dpsd.ship_to_location_id(+)
                              --                AND      dpd.style = dpsd.style(+)
                              AND pha.vendor_site_id = pvsa.vendor_site_id -- Commented above lines added this condition by Anil as part of ENHC0011973
                              --AND dpd.buy_season =
                              --       NVL (p_buy_season, dpd.buy_season)  -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_season, 'XXX') =
                                  NVL (p_buy_season,
                                       NVL (dpd.buy_season, 'XXX')) -- CCR0005924 ITEM_TYPE
                              --AND dpd.buy_month = NVL (p_buy_month, dpd.buy_month) -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_month, 'XXX') =
                                  NVL (p_buy_month, NVL (dpd.buy_month, 'XXX')) -- CCR0005924 ITEM_TYPE
                              --AND dpd.po_date >= NVL (po_from_date, dpd.po_date) -- Commented CCR0006426
                              AND dpd.po_date >=
                                  NVL (po_from_date, '06-APR-2016') -- Added CCR0006426
                              --AND dpd.po_date <= NVL (po_to_date, dpd.po_date) -- Commented CCR0006426
                              AND dpd.po_date <= NVL (po_to_date, SYSDATE) -- Added CCR0006426
                              --AND NVL(dpd.cancelled_quantity,0) = 0  -- Added as per change 2.2 -- Commented as per ver 2.3
                              AND (NVL (dpd.line_quantity, 0) - NVL (dpd.cancelled_quantity, 0)) >
                                  0                    -- Added as per ver 2.3
                              AND NVL (dpd.conf_ex_factory_date, '1-JAN-13') >=
                                  NVL (
                                      ex_from_date,
                                      NVL (dpd.conf_ex_factory_date,
                                           '1-JAN-13'))
                              AND NVL (dpd.conf_ex_factory_date, '1-JAN-13') <=
                                  NVL (
                                      ex_to_date,
                                      NVL (dpd.conf_ex_factory_date,
                                           '1-JAN-13'))
                              AND (dpd.po_number BETWEEN NVL (p_po_number_lo, dpd.po_number) AND NVL (p_po_number_hi, dpd.po_number))
                              AND dpd.vendor_name =
                                  NVL (p_vendor_name, dpd.vendor_name)
                              AND dpd.style = NVL (p_style, dpd.style)
                              AND dpd.color = NVL (p_color, dpd.color)
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --AND      mcb.segment1 = NVL (p_brand, mcb.segment1)
                              AND xci.brand = NVL (p_brand, xci.brand)
                              AND pha.agent_id = pav.agent_id     -- SFS_BUYER
                              --Start changes by V1.91 Arun N Murthy
                              --       AND pav.agent_name <> 'SFS-US, BUYER' -- SFS_BUYER
                              AND pav.agent_name NOT IN
                                      (SELECT description
                                         FROM fnd_lookup_values
                                        WHERE     1 = 1
                                              AND lookup_type LIKE
                                                      'XXD_PO_SFS_BUYER_LKP'
                                              AND language = USERENV ('LANG')
                                              AND SYSDATE BETWEEN start_date_active
                                                              AND   NVL (
                                                                        end_date_active,
                                                                        SYSDATE)
                                                                  + 1
                                              AND tag =
                                                  'XXDO_PO_LISTING_BY_SIZE'
                                              AND enabled_flag = 'Y')
                     -- END changes by V1.91 Arun N Murthy    -- SFS_BUYER
                     /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                     GROUP BY                              -- Start CCR0006426
                              --rc.customer_name,
                              hp.party_name, -- End CCR0006426
                                             dpd.country, dpd.po_date,
                              dpd.po_number, dpd.vendor_name, dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                                                    dpd.color, dpd.item_size,
                              dpd.ship_to_location_id, dpd.ex_factory_date, dpd.conf_ex_factory_date,
                              dpd.promised_date /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                               --,mcb.segment1
                              , xci.brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                         , dpd.item_id,
                              pol.unit_price, dpd.buy_month, dpd.buy_season --,dpsd.comments_5
                                                                           -- Start of Change 2.1
                                                                           ,
                              pol.attribute7, pha.attribute10, xci.department,
                              -- End of Change
                              -- Start of change 2.2
                              pol.attribute8, pol.attribute9, pol.attribute11, -- ver 2.4
                              pol.unit_price, pha.vendor_id, mp.organization_code,
                              dpd.location_code,        --Added as per ver 2.3
                                                 pha.segment1, -- End of change 2.2
                                                               pha.attribute11, --2.5
                              pol.po_line_id,                           -- 2.5
                                              pvsa.vendor_site_code); -- Commented the above line and added this table by Anil as part of ENHC0011973
            ELSE
                INSERT INTO xxdo_main_data
                    (  SELECT dpd.vendor_name,
                              dpd.po_date,
                              dpd.po_number,
                              dpd.ship_to_location_id,
                              dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                              dpd.color,
                              dpd.item_size,
                              TO_CHAR (dpd.ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.conf_ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.promised_date, 'DD-MON-YYYY') -- ,dpd.country dest
                                                                        ,
                              -- Start CCR0006426
                              /*DECODE (
                                 rc.customer_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 rc.customer_name)
                                 dest*/
                              -- Start of Change 2.2
                              /*DECODE (
                                 hp.party_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 hp.party_name)
                                 dest                             -- End CCR0006426
                                     /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --,mcb.segment1 brand
                              /* -- START Commented as per ver 2.3
            get_dest_name(
                              DECODE (
                                 hp.party_name,
                                 '', mp.organization_code,
                                 hp.party_name),pha.vendor_id,pha.segment1)
                                 dest
                              -- End of change
                              ,
            */
                              -- END Commented as per ver 2.3
                              --START Added as per ver 2.3
                              NVL (
                                  get_dest_name (
                                      DECODE (hp.party_name,
                                              '', mp.organization_code,
                                              hp.party_name),
                                      pha.vendor_id,
                                      pha.segment1),
                                  dpd.location_code)
                                  dest,
                              --END Added as per ver 2.3
                              xci.brand
                                  brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                       ,
                                NVL (SUM (dpd.line_quantity), 0)
                              - NVL (SUM (dpd.cancelled_quantity), 0)
                                  po_qty,
                              NVL (SUM (dpd.received_quantity), 0)
                                  rcv_qty,
                              ((NVL (SUM (dpd.line_quantity), 0) - NVL (SUM (dpd.cancelled_quantity), 0)) - (NVL (SUM (dpd.received_quantity), 0)))
                                  bal_qty,
                              --  pol.unit_price, -- commented 2.4
                              NVL (pol.attribute11, pol.unit_price)
                                  unit_price,             --added for  ver 2.4
                              dpd.buy_month,
                              dpd.buy_season  --,dpsd.comments_5 facility_site
                                            ,
                              --pvsa.vendor_site_code facility_site, -- added by Anil as part of ENHC0011973
                              NVL (pol.attribute7, pvsa.vendor_site_code)
                                  facility_site,     -- Aded as per Change 2.1
                              -- Start of Change 2.2
                              NULL
                                  etd_port,
                              /*DECODE (
                                 (SELECT msa.attribute1
                                    FROM apps.mrp_sourcing_rules msr,
                                         apps.mrp_sr_assignments msa,
                                         apps.mrp_assignment_sets msas,
                                         apps.fnd_lookup_values fnl
                                         --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                         --,apps.mtl_item_categories mic
                                         --,apps.mtl_categories_b mcb
                                         ,xxd_common_items_v xci
                                         --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                                         ,apps.mtl_parameters mtp
                                   WHERE     msr.sourcing_rule_id =
                                                msa.sourcing_rule_id
                                         AND msas.assignment_set_id =
                                                msa.assignment_set_id
                                         AND msa.inventory_item_id IS NULL
                                         AND msas.assignment_set_name = 'AS - US'
                                         AND msr.status = 1
                                         AND fnl.lookup_code = msa.assignment_type
                                         AND NVL (fnl.end_date_active,
                                                  TRUNC (SYSDATE + 1)) >=
                                                TRUNC (SYSDATE)
                                         AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                         AND fnl.lookup_type = 'MRP_ASSIGNMENT_TYPE'
                                         AND fnl.language = 'US'
                                         --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                         -- AND    mic.category_id = mcb.category_id
                                         -- AND    mic.category_id = msa.category_id
                                         -- AND    mic.category_set_id = msa.category_set_id
                                         -- AND    mtp.organization_id = mic.organization_id
                                         AND xci.category_id = msa.category_id
                                         AND xci.category_set_id =
                                                msa.category_set_id
                                         AND mtp.organization_id =
                                                xci.organization_id
                                         --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                         AND mtp.organization_code = 'VNT'
                                         AND fnl.meaning = 'Category'
                                         AND ROWNUM <= 1),
                                 NULL, (SELECT msa.attribute1
                                          FROM apps.mrp_sourcing_rules msr,
                                               apps.mrp_sr_assignments msa,
                                               apps.mrp_assignment_sets msas,
                                               apps.fnd_lookup_values fnl
                                         WHERE     msa.sourcing_rule_id =
                                                      msr.sourcing_rule_id
                                               AND msas.assignment_set_id =
                                                      msa.assignment_set_id
                                               AND msa.inventory_item_id IS NOT NULL
                                               AND msas.assignment_set_name =
                                                      'AS - US'
                                               AND msr.status = 1
                                               AND fnl.lookup_code =
                                                      msa.assignment_type
                                               AND NVL (fnl.end_date_active,
                                                        TRUNC (SYSDATE + 1)) >=
                                                      TRUNC (SYSDATE)
                                               AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                               AND fnl.lookup_type =
                                                      'MRP_ASSIGNMENT_TYPE'
                                               AND fnl.language = 'US'
                                               AND fnl.meaning = 'Item'
                                               AND ROWNUM <= 1),
                                 NULL)
                                 etd_port,*/
                              -- End of Change 2.2
                              SUM (pol.quantity * pol.unit_price)
                                  total_price,
                              -- Start of Change 2.1
                              xci.department
                                  product_category,
                              pha.attribute10
                                  po_type,
                              dpd.country
                                  country,
                              -- End of Change 2.1
                              -- Start of change 2.2
                              pol.attribute8
                                  global_surcharge,
                              pol.attribute9
                                  ship_to_id_surcharge,
                              -- NVL(pol.unit_price,0) blended_fob  -- commented for 2.4
                              (NVL (pol.attribute11, pol.unit_price) + NVL (pol.attribute8, 0) + NVL (pol.attribute9, 0))
                                  blended_fob,                -- added ver 2.4
                              -- End of change 2.2
                              pha.attribute11
                                  gtn_transfer_flag,                     --2.5
                              DECODE (
                                  pha.attribute10,
                                  'XDOCK', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                              FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                             WHERE     ooha.header_id =
                                                       oola.header_id
                                                   AND oola.attribute15 =
                                                       TO_CHAR (
                                                           plla.line_location_id)
                                                   AND NVL (
                                                           oola.cancelled_flag,
                                                           'N') <>
                                                       'Y'
                                                   AND NVL (oola.context, 'X') !=
                                                       'DO eCommerce'
                                                   AND plla.po_line_id =
                                                       pol.po_line_id),
                                  'DIRECT_SHIP', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                                    FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                                   WHERE     ooha.header_id =
                                                             oola.header_id
                                                         AND oola.attribute16 =
                                                             TO_CHAR (
                                                                 plla.line_location_id)
                                                         AND NVL (
                                                                 oola.cancelled_flag,
                                                                 'N') <>
                                                             'Y'
                                                         AND NVL (oola.context,
                                                                  'X') !=
                                                             'DO eCommerce'
                                                         AND plla.po_line_id =
                                                             pol.po_line_id),
                                  NULL)
                                  so_number                              --2.5
                         FROM /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                                      --apps.do_po_details_v dpd
                                                       -- ,apps.mtl_categories_b mcb
                                                        --,apps.mtl_item_categories mic
                                                        --,apps.ra_customers rc
                                                         --  ,apps.fnd_lookup_values_vl sales_reg
                                                         -- ,apps.po_vendor_sites_all pvsa   -- Commented above line and added this table by Anil as part of ENHC0011973
                              */
                              apps.do_po_details dpd, apps.po_lines_all pol, xxd_common_items_v xci,
                              -- Start CCR0006426
                              --apps.xxd_ra_customers_v rc,
                              apps.hz_cust_accounts hca, apps.hz_parties hp, -- End CCR0006426
                                                                             apps.oe_order_headers_all oeh,
                              apps.mtl_parameters mp, apps.fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                              apps.po_headers_all pha -- ,do_custom.do_po_shipment_details dpsd
                                                     , ap_supplier_sites_all pvsa, apps.po_agents_v pav -- SFS_BUYER
                        /*----------------------------------------------------------------------------------------------------
                        End changes by BT Technology Team v1.2 on 02-APR-2015
                        ------------------------------------------------------------------------------------------------------*/
                        WHERE --mic.inventory_item_id = dpd.item_id  --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                  xci.inventory_item_id = dpd.item_id --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                              AND pol.po_line_id = dpd.po_line_id
                              --AND pol.attribute_category = 'PO Data Elements'         -- Aded as per Change 2.1
                              /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                              AND      mcb.structure_id = 101
                                              AND      mic.category_set_id = 1
                                              AND      mic.organization_id = dpd.ship_to_organization_id
                                              AND      mic.organization_id = mp.organization_id
                              */
                              AND xci.organization_id = mp.organization_id
                              AND xci.organization_id =
                                  dpd.ship_to_organization_id
                              /*----------------------------------------------------------------------------------------------------
                              End changes by BT Technology Team v1.2 on 02-APR-2015
                              ------------------------------------------------------------------------------------------------------*/
                              --   AND      mp.attribute1 = sales_reg.lookup_code(+)
                              AND mp.attribute1 = ffv.flex_value(+)
                              /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                             -- AND      sales_reg.lookup_type(+) = 'DO_SALES_REGIONS'
                                              -- AND      mcb.category_id = mic.category_id
                                               --AND      mcb.segment2  = NVL (p_product_group, mcb.segment2)
                              */
                              AND ffvs.flex_value_set_name = 'DO_SALES_REGION'
                              AND ffv.flex_value_set_id =
                                  ffvs.flex_value_set_id
                              AND mp.attribute1 =
                                  NVL (p_sales_region, mp.attribute1)
                              AND xci.department =
                                  NVL (p_product_group, xci.department)
                              /*----------------------------------------------------------------------------------------------------
                             End changes by BT Technology Team v1.2 on 02-APR-2015
                             ------------------------------------------------------------------------------------------------------*/
                              AND dpd.order_header_id = oeh.header_id(+)
                              -- Start CCR0006426
                              --AND oeh.sold_to_org_id = rc.customer_id(+)
                              AND oeh.sold_to_org_id = hca.cust_account_id(+)
                              AND hca.party_id = hp.party_id(+)
                              -- End CCR0006426
                              AND dpd.po_header_id = pha.po_header_id
                              AND dpd.org_id = pha.org_id
                              --                AND      dpd.po_header_id = dpsd.po_header_id(+)
                              --                AND      dpd.color = dpsd.color(+)
                              --                AND      dpd.ship_to_location_id = dpsd.ship_to_location_id(+)
                              --                AND      dpd.style = dpsd.style(+)
                              AND pha.vendor_site_id = pvsa.vendor_site_id -- Commented above lines added this condition by Anil as part of ENHC0011973
                              --AND dpd.buy_season =
                              --       NVL (p_buy_season, dpd.buy_season)  -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_season, 'XXX') =
                                  NVL (p_buy_season,
                                       NVL (dpd.buy_season, 'XXX')) -- -- CCR0005924 ITEM_TYPE
                              --AND dpd.buy_month = NVL (p_buy_month, dpd.buy_month) -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_month, 'XXX') =
                                  NVL (p_buy_month, NVL (dpd.buy_month, 'XXX')) -- CCR0005924 ITEM_TYPE
                              -- Start CCR0006426
                              --AND dpd.po_date >= NVL (po_from_date, dpd.po_date)
                              AND dpd.po_date >=
                                  NVL (po_from_date, '06-APR-2016')
                              --AND dpd.po_date <= NVL (po_to_date, dpd.po_date)
                              AND dpd.po_date <= NVL (po_to_date, SYSDATE)
                              -- End CCR0006426
                              --AND NVL(dpd.cancelled_quantity,0) = 0  -- Added as per change 2.2 -- Commented as per ver 2.3
                              AND (NVL (dpd.line_quantity, 0) - NVL (dpd.cancelled_quantity, 0)) >
                                  0                    -- Added as per ver 2.3
                              AND dpd.conf_ex_factory_date >=
                                  NVL (ex_from_date, dpd.conf_ex_factory_date)
                              AND dpd.conf_ex_factory_date <=
                                  NVL (ex_to_date, dpd.conf_ex_factory_date)
                              AND (dpd.po_number BETWEEN NVL (p_po_number_lo, dpd.po_number) AND NVL (p_po_number_hi, dpd.po_number))
                              AND dpd.vendor_name =
                                  NVL (p_vendor_name, dpd.vendor_name)
                              AND dpd.style = NVL (p_style, dpd.style)
                              AND dpd.color = NVL (p_color, dpd.color)
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --AND      mcb.segment1 = NVL (p_brand, mcb.segment1)
                              AND xci.brand = NVL (p_brand, xci.brand)
                              AND pha.agent_id = pav.agent_id     -- SFS_BUYER
                              --Start changes by V1.91 Arun N Murthy
                              --       AND pav.agent_name <> 'SFS-US, BUYER' -- SFS_BUYER
                              AND pav.agent_name NOT IN
                                      (SELECT description
                                         FROM fnd_lookup_values
                                        WHERE     1 = 1
                                              AND lookup_type LIKE
                                                      'XXD_PO_SFS_BUYER_LKP'
                                              AND language = USERENV ('LANG')
                                              AND SYSDATE BETWEEN start_date_active
                                                              AND   NVL (
                                                                        end_date_active,
                                                                        SYSDATE)
                                                                  + 1
                                              AND tag =
                                                  'XXDO_PO_LISTING_BY_SIZE'
                                              AND enabled_flag = 'Y')
                     -- END changes by V1.91 Arun N Murthy    -- SFS_BUYER
                     /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                     GROUP BY                              -- Start CCR0006426
                              --rc.customer_name,
                              hp.party_name, -- End CCR0006426
                                             dpd.country, dpd.po_date,
                              dpd.po_number, dpd.vendor_name, dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                                                    dpd.color, dpd.item_size,
                              dpd.ship_to_location_id, dpd.ex_factory_date, dpd.conf_ex_factory_date,
                              dpd.promised_date /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                               --,mcb.segment1
                              , xci.brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                         , dpd.item_id,
                              pol.unit_price, dpd.buy_month, dpd.buy_season --,dpsd.comments_5
                                                                           -- Start of Change 2.1
                                                                           ,
                              pol.attribute7, pha.attribute10, xci.department,
                              -- End of Change
                              -- Start of change 2.2
                              pol.attribute8, pol.attribute9, pol.attribute11,
                              pol.unit_price, pha.vendor_id, mp.organization_code,
                              dpd.location_code,        --Added as per ver 2.3
                                                 pha.attribute11,        --2.5
                                                                  pol.po_line_id, -- 2.5
                              pha.segment1, -- End of Change
                                            pvsa.vendor_site_code); -- Commented the above line and added this table by Anil as part of ENHC0011973
            END IF;
        ELSIF p_sample = 'MASS'
        THEN
            IF ((p_conf_ex_fact_date_lo IS NULL) AND (p_conf_ex_fact_date_hi IS NULL))
            THEN
                INSERT INTO xxdo_main_data
                    (  SELECT dpd.vendor_name,
                              dpd.po_date,
                              dpd.po_number,
                              dpd.ship_to_location_id,
                              dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                              dpd.color,
                              dpd.item_size,
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              /*dpd.ex_factory_date,
                              dpd.conf_ex_factory_date,
                              dpd.promised_date*/
                              -- ,dpd.country dest
                              TO_CHAR (dpd.ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.conf_ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.promised_date, 'DD-MON-YYYY') /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                                        ,
                              -- Start CCR0006426
                              /*DECODE (
                                 rc.customer_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 rc.customer_name)
                                 dest*/
                              -- Start of Change 2.2
                              /*
                              DECODE (
                                 hp.party_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 hp.party_name)
                                 dest                             -- End CCR0006426
                                     /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --,mcb.segment1 brand
                              /* --START Commented as per ver 2.3
                               get_dest_name(
                               DECODE (
                                  hp.party_name,
                                  '', mp.organization_code,
                                  hp.party_name),pha.vendor_id,pha.segment1)
                                  dest,
            */
                              --END Commented as per ver 2.3
                              --START Added as per ver 2.3
                              NVL (
                                  get_dest_name (
                                      DECODE (hp.party_name,
                                              '', mp.organization_code,
                                              hp.party_name),
                                      pha.vendor_id,
                                      pha.segment1),
                                  dpd.location_code)
                                  dest,
                              --END Added as per ver 2.3
                              -- End of change
                              xci.brand
                                  brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                       ,
                                NVL (SUM (dpd.line_quantity), 0)
                              - NVL (SUM (dpd.cancelled_quantity), 0)
                                  po_qty,
                              NVL (SUM (dpd.received_quantity), 0)
                                  rcv_qty,
                              ((NVL (SUM (dpd.line_quantity), 0) - NVL (SUM (dpd.cancelled_quantity), 0)) - (NVL (SUM (dpd.received_quantity), 0)))
                                  bal_qty,
                              --  pol.unit_price,  -- commented for 2.4
                              NVL (pol.attribute11, pol.unit_price)
                                  unit_price,             --added for  ver 2.4
                              dpd.buy_month,
                              dpd.buy_season  --,dpsd.comments_5 facility_site
                                            ,
                              --pvsa.vendor_site_code facility_site, -- added by Anil as part of ENHC0011973
                              NVL (pol.attribute7, pvsa.vendor_site_code)
                                  facility_site,     -- Aded as per Change 2.1
                              -- Start of Change 2.2
                              NULL
                                  etd_port,
                              /*DECODE (
                                 (SELECT msa.attribute1
                                    FROM apps.mrp_sourcing_rules msr,
                                         apps.mrp_sr_assignments msa,
                                         apps.mrp_assignment_sets msas,
                                         apps.fnd_lookup_values fnl,
                                         apps.mtl_item_categories mic,
                                         apps.mtl_categories_b mcb,
                                         apps.mtl_parameters mtp
                                   WHERE     msr.sourcing_rule_id =
                                                msa.sourcing_rule_id
                                         AND msas.assignment_set_id =
                                                msa.assignment_set_id
                                         AND msa.inventory_item_id IS NULL
                                         AND msas.assignment_set_name = 'AS - US'
                                         AND msr.status = 1
                                         AND fnl.lookup_code = msa.assignment_type
                                         AND NVL (fnl.end_date_active,
                                                  TRUNC (SYSDATE + 1)) >=
                                                TRUNC (SYSDATE)
                                         AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                         AND fnl.lookup_type = 'MRP_ASSIGNMENT_TYPE'
                                         AND fnl.language = 'US'
                                         AND mic.category_id = mcb.category_id
                                         AND mic.category_id = msa.category_id
                                         AND mic.category_set_id =
                                                msa.category_set_id
                                         AND mtp.organization_id =
                                                mic.organization_id
                                         AND mtp.organization_code = 'VNT'
                                         AND fnl.meaning = 'Category'
                                         AND ROWNUM <= 1),
                                 NULL, (SELECT msa.attribute1
                                          FROM apps.mrp_sourcing_rules msr,
                                               apps.mrp_sr_assignments msa,
                                               apps.mrp_assignment_sets msas,
                                               apps.fnd_lookup_values fnl
                                         WHERE     msa.sourcing_rule_id =
                                                      msr.sourcing_rule_id
                                               AND msas.assignment_set_id =
                                                      msa.assignment_set_id
                                               AND msa.inventory_item_id IS NOT NULL
                                               AND msas.assignment_set_name =
                                                      'AS - US'
                                               AND msr.status = 1
                                               AND fnl.lookup_code =
                                                      msa.assignment_type
                                               AND NVL (fnl.end_date_active,
                                                        TRUNC (SYSDATE + 1)) >=
                                                      TRUNC (SYSDATE)
                                               AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                               AND fnl.lookup_type =
                                                      'MRP_ASSIGNMENT_TYPE'
                                               AND fnl.language = 'US'
                                               AND fnl.meaning = 'Item'
                                               AND ROWNUM <= 1),
                                 NULL)
                                 etd_port,*/
                              -- End of Chnage 2.2
                              SUM (pol.quantity * pol.unit_price)
                                  total_price,
                              -- Start of Change 2.1
                              xci.department
                                  product_category,
                              pha.attribute10
                                  po_type,
                              dpd.country
                                  country,
                              -- End of Change 2.1
                              -- Start of change 2.2
                              pol.attribute8
                                  global_surcharge,
                              pol.attribute9
                                  ship_to_id_surcharge,
                              --  NVL(pol.unit_price,0) blended_fob  -- commented for 2.4
                              (NVL (pol.attribute11, pol.unit_price) + NVL (pol.attribute8, 0) + NVL (pol.attribute9, 0))
                                  blended_fob,                -- added ver 2.4
                              -- End of change 2.2
                              pha.attribute11
                                  gtn_transfer_flag,                     --2.5
                              DECODE (
                                  pha.attribute10,
                                  'XDOCK', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                              FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                             WHERE     ooha.header_id =
                                                       oola.header_id
                                                   AND oola.attribute15 =
                                                       TO_CHAR (
                                                           plla.line_location_id)
                                                   AND NVL (
                                                           oola.cancelled_flag,
                                                           'N') <>
                                                       'Y'
                                                   AND NVL (oola.context, 'X') !=
                                                       'DO eCommerce'
                                                   AND plla.po_line_id =
                                                       pol.po_line_id),
                                  'DIRECT_SHIP', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                                    FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                                   WHERE     ooha.header_id =
                                                             oola.header_id
                                                         AND oola.attribute16 =
                                                             TO_CHAR (
                                                                 plla.line_location_id)
                                                         AND NVL (
                                                                 oola.cancelled_flag,
                                                                 'N') <>
                                                             'Y'
                                                         AND NVL (oola.context,
                                                                  'X') !=
                                                             'DO eCommerce'
                                                         AND plla.po_line_id =
                                                             pol.po_line_id),
                                  NULL)
                                  so_number                              --2.5
                         FROM /*-------------------------------------------------------------------------------------
                             Start Changes by BT Technology Team v1.2 on 02-APR-2015
                             ---------------------------------------------------------------------------------------
                                                     --apps.do_po_details_v dpd
                                                     --,apps.ra_customers rc
                                                      -- ,apps.fnd_lookup_values_vl sales_reg
                                                       --,apps.po_vendor_sites_all pvsa   -- Commented above and line added this table by Anil as part of ENHC0011973
                                                       --  ,apps.mtl_categories_b mcb
                                                    -- ,apps.mtl_item_categories mic*/
                              apps.do_po_details dpd, apps.po_lines_all pol, xxd_common_items_v xci,
                              -- Start CCR0006426
                              --xxd_ra_customers_v rc,
                              hz_cust_accounts hca, hz_parties hp, -- End CCR0006426
                                                                   apps.oe_order_headers_all oeh,
                              fnd_flex_value_sets ffvs, fnd_flex_values ffv, apps.po_headers_all pha --, do_custom.do_po_shipment_details dpsd
                                                                                                    ,
                              ap_supplier_sites_all pvsa /*----------------------------------------------------------------------------------------------------
                                                    End changes by BT Technology Team v1.2 on 02-APR-2015
                                                    ------------------------------------------------------------------------------------------------------*/
                                                        , apps.mtl_parameters mp, apps.po_agents_v pav -- SFS_BUYER
                        WHERE --mic.inventory_item_id = dpd.item_id --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                  xci.inventory_item_id = dpd.item_id --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                              AND pol.po_line_id = dpd.po_line_id
                              --AND pol.attribute_category = 'PO Data Elements'         -- Aded as per Change 2.1
                              /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                              AND      mcb.structure_id = 101
                                              AND      mic.category_set_id = 1
                                              AND      mic.organization_id = dpd.ship_to_organization_id
                                              AND      mic.organization_id = mp.organization_id
                              */
                              AND xci.organization_id = mp.organization_id
                              AND xci.organization_id =
                                  dpd.ship_to_organization_id
                              /*----------------------------------------------------------------------------------------------------
                              End changes by BT Technology Team v1.2 on 02-APR-2015
                              ------------------------------------------------------------------------------------------------------*/
                              -- AND      mp.attribute1 = sales_reg.lookup_code(+)
                              AND mp.attribute1 = ffv.flex_value(+)
                              /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                            --  AND      sales_reg.lookup_type(+) = 'DO_SALES_REGIONS'
                                            --AND      mcb.segment2 = NVL (p_product_group, mcb.segment2)
                                             -- AND      mcb.category_id = mic.category_id
                              */
                              AND ffvs.flex_value_set_name = 'DO_SALES_REGION'
                              AND ffv.flex_value_set_id =
                                  ffvs.flex_value_set_id
                              AND mp.attribute1 =
                                  NVL (p_sales_region, mp.attribute1)
                              AND xci.department =
                                  NVL (p_product_group, xci.department)
                              /*----------------------------------------------------------------------------------------------------
                              End changes by BT Technology Team v1.2 on 02-APR-2015
                              ------------------------------------------------------------------------------------------------------*/
                              AND dpd.order_header_id = oeh.header_id(+)
                              -- Start CCR0006426
                              --AND oeh.sold_to_org_id = rc.customer_id(+)
                              AND oeh.sold_to_org_id = hca.cust_account_id(+)
                              AND hca.party_id = hp.party_id(+)
                              -- End CCR0006426
                              AND dpd.po_header_id = pha.po_header_id
                              AND dpd.org_id = pha.org_id
                              --                AND      dpd.po_header_id = dpsd.po_header_id(+)
                              --                AND      dpd.color = dpsd.color(+)
                              --                AND      dpd.ship_to_location_id = dpsd.ship_to_location_id(+)
                              --                AND      dpd.style = dpsd.style(+)
                              AND pha.vendor_site_id = pvsa.vendor_site_id -- Commented above lines added this condition by Anil as part of ENHC0011973
                              --AND dpd.buy_season =
                              --       NVL (p_buy_season, dpd.buy_season)  -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_season, 'XXX') =
                                  NVL (p_buy_season,
                                       NVL (dpd.buy_season, 'XXX')) -- -- CCR0005924 ITEM_TYPE
                              --AND dpd.buy_month = NVL (p_buy_month, dpd.buy_month) -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_month, 'XXX') =
                                  NVL (p_buy_month, NVL (dpd.buy_month, 'XXX')) -- CCR0005924 ITEM_TYPE
                              -- Start CCR0006426
                              --AND dpd.po_date >= NVL (po_from_date, dpd.po_date)
                              AND dpd.po_date >=
                                  NVL (po_from_date, '06-APR-2016')
                              --AND dpd.po_date <= NVL (po_to_date, dpd.po_date)
                              AND dpd.po_date <= NVL (po_to_date, SYSDATE)
                              -- End CCR0006426
                              -- AND NVL(dpd.cancelled_quantity,0) = 0  -- Added as per change 2.2 -- Commented as per ver 2.3
                              AND (NVL (dpd.line_quantity, 0) - NVL (dpd.cancelled_quantity, 0)) >
                                  0                    -- Added as per ver 2.3
                              AND NVL (dpd.conf_ex_factory_date, '1-JAN-13') >=
                                  NVL (
                                      ex_from_date,
                                      NVL (dpd.conf_ex_factory_date,
                                           '1-JAN-13'))
                              AND NVL (dpd.conf_ex_factory_date, '1-JAN-13') <=
                                  NVL (
                                      ex_to_date,
                                      NVL (dpd.conf_ex_factory_date,
                                           '1-JAN-13'))
                              AND (dpd.po_number BETWEEN NVL (p_po_number_lo, dpd.po_number) AND NVL (p_po_number_hi, dpd.po_number))
                              AND dpd.vendor_name =
                                  NVL (p_vendor_name, dpd.vendor_name)
                              AND dpd.style = NVL (p_style, dpd.style)
                              AND dpd.color = NVL (p_color, dpd.color)
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --AND      mcb.segment1 = NVL (p_brand, mcb.segment1)
                              AND xci.brand = NVL (p_brand, xci.brand)
                              /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              /*AND dpd.style NOT LIKE 'S%'*/
                              -- CCR0005924 ITEM_TYPE
                              AND xci.user_item_type NOT IN ('SAMPLE') -- CCR0005924 ITEM_TYPE
                              AND pha.agent_id = pav.agent_id     -- SFS_BUYER
                              --Start changes by V1.91 Arun N Murthy
                              --       AND pav.agent_name <> 'SFS-US, BUYER' -- SFS_BUYER
                              AND pav.agent_name NOT IN
                                      (SELECT description
                                         FROM fnd_lookup_values
                                        WHERE     1 = 1
                                              AND lookup_type LIKE
                                                      'XXD_PO_SFS_BUYER_LKP'
                                              AND language = USERENV ('LANG')
                                              AND SYSDATE BETWEEN start_date_active
                                                              AND   NVL (
                                                                        end_date_active,
                                                                        SYSDATE)
                                                                  + 1
                                              AND tag =
                                                  'XXDO_PO_LISTING_BY_SIZE'
                                              AND enabled_flag = 'Y')
                     -- END changes by V1.91 Arun N Murthy    -- SFS_BUYER
                     GROUP BY                              -- Start CCR0006426
                              --rc.customer_name,
                              hp.party_name, -- End CCR0006426
                                             dpd.country, dpd.po_date,
                              dpd.po_number, dpd.vendor_name, dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                                                    dpd.color, dpd.item_size,
                              dpd.ship_to_location_id, dpd.ex_factory_date, dpd.conf_ex_factory_date,
                              dpd.promised_date /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                               --,mcb.segment1
                              , xci.brand /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                         , dpd.item_id,
                              pol.unit_price, dpd.buy_month, dpd.buy_season --,dpsd.comments_5
                                                                           -- Start of Change 2.1
                                                                           ,
                              pol.attribute7, pha.attribute10, xci.department,
                              -- End of Change
                              -- Start of change 2.2
                              pol.attribute8, pol.attribute9, pol.attribute11, -- ver 2.4
                              pol.unit_price, pha.vendor_id, mp.organization_code,
                              dpd.location_code,        --Added as per ver 2.3
                                                 pha.segment1, -- End of Change
                                                               pha.attribute11, -- 2.5
                              pol.po_line_id,                           -- 2.5
                                              pvsa.vendor_site_code); -- Commented the above line and added this table by Anil as part of ENHC0011973
            ELSE
                INSERT INTO xxdo_main_data
                    (  SELECT dpd.vendor_name,
                              dpd.po_date,
                              dpd.po_number,
                              dpd.ship_to_location_id,
                              dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                              dpd.color,
                              dpd.item_size,
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              /*dpd.ex_factory_date,
                              dpd.conf_ex_factory_date,
                              dpd.promised_date*/
                              -- ,dpd.country dest
                              TO_CHAR (dpd.ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.conf_ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.promised_date, 'DD-MON-YYYY') /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                                        ,
                              -- Start CCR0006426
                              /*DECODE (
                                 rc.customer_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 rc.customer_name)
                                 dest*/
                              -- Start of Change 2.2
                              /*DECODE (
                                 hp.party_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 hp.party_name)
                                 dest                             -- End CCR0006426
                                     /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --,mcb.segment1 brand
                              /* --START Commented as per ver 2.3
            get_dest_name(
                              DECODE (
                                 hp.party_name,
                                 '', mp.organization_code,
                                 hp.party_name),pha.vendor_id,pha.segment1)
                                 dest,
                              -- End of change
            */
                              --END Commented as per ver 2.3
                              --START Added as per ver 2.3
                              NVL (
                                  get_dest_name (
                                      DECODE (hp.party_name,
                                              '', mp.organization_code,
                                              hp.party_name),
                                      pha.vendor_id,
                                      pha.segment1),
                                  dpd.location_code)
                                  dest,
                              --END Added as per ver 2.3
                              xci.brand
                                  brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                       ,
                                NVL (SUM (dpd.line_quantity), 0)
                              - NVL (SUM (dpd.cancelled_quantity), 0)
                                  po_qty,
                              NVL (SUM (dpd.received_quantity), 0)
                                  rcv_qty,
                              ((NVL (SUM (dpd.line_quantity), 0) - NVL (SUM (dpd.cancelled_quantity), 0)) - (NVL (SUM (dpd.received_quantity), 0)))
                                  bal_qty,
                              --  pol.unit_price,  -- commented for 2.4
                              NVL (pol.attribute11, pol.unit_price)
                                  unit_price,             --added for  ver 2.4
                              dpd.buy_month,
                              dpd.buy_season  --,dpsd.comments_5 facility_site
                                            ,
                              --pvsa.vendor_site_code facility_site, -- added by Anil as part of ENHC0011973
                              NVL (pol.attribute7, pvsa.vendor_site_code)
                                  facility_site,     -- Aded as per Change 2.1
                              NULL
                                  etd_port,
                              -- Start of change 2.2
                              /*DECODE (
                                 (SELECT msa.attribute1
                                    FROM apps.mrp_sourcing_rules msr,
                                         apps.mrp_sr_assignments msa,
                                         apps.mrp_assignment_sets msas,
                                         apps.fnd_lookup_values fnl,
                                         apps.mtl_item_categories mic,
                                         apps.mtl_categories_b mcb,
                                         apps.mtl_parameters mtp
                                   WHERE     msr.sourcing_rule_id =
                                                msa.sourcing_rule_id
                                         AND msas.assignment_set_id =
                                                msa.assignment_set_id
                                         AND msa.inventory_item_id IS NULL
                                         AND msas.assignment_set_name = 'AS - US'
                                         AND msr.status = 1
                                         AND fnl.lookup_code = msa.assignment_type
                                         AND NVL (fnl.end_date_active,
                                                  TRUNC (SYSDATE + 1)) >=
                                                TRUNC (SYSDATE)
                                         AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                         AND fnl.lookup_type = 'MRP_ASSIGNMENT_TYPE'
                                         AND fnl.language = 'US'
                                         AND mic.category_id = mcb.category_id
                                         AND mic.category_id = msa.category_id
                                         AND mic.category_set_id =
                                                msa.category_set_id
                                         AND mtp.organization_id =
                                                mic.organization_id
                                         AND mtp.organization_code = 'VNT'
                                         AND fnl.meaning = 'Category'
                                         AND ROWNUM <= 1),
                                 NULL, (SELECT msa.attribute1
                                          FROM apps.mrp_sourcing_rules msr,
                                               apps.mrp_sr_assignments msa,
                                               apps.mrp_assignment_sets msas,
                                               apps.fnd_lookup_values fnl
                                         WHERE     msa.sourcing_rule_id =
                                                      msr.sourcing_rule_id
                                               AND msas.assignment_set_id =
                                                      msa.assignment_set_id
                                               AND msa.inventory_item_id IS NOT NULL
                                               AND msas.assignment_set_name =
                                                      'AS - US'
                                               AND msr.status = 1
                                               AND fnl.lookup_code =
                                                      msa.assignment_type
                                               AND NVL (fnl.end_date_active,
                                                        TRUNC (SYSDATE + 1)) >=
                                                      TRUNC (SYSDATE)
                                               AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                               AND fnl.lookup_type =
                                                      'MRP_ASSIGNMENT_TYPE'
                                               AND fnl.language = 'US'
                                               AND fnl.meaning = 'Item'
                                               AND ROWNUM <= 1),
                                 NULL)
                                 etd_port,*/
                              -- End of Change 2.2
                              SUM (pol.quantity * pol.unit_price)
                                  total_price,
                              -- Start of Change 2.1
                              xci.department
                                  product_category,
                              pha.attribute10
                                  po_type,
                              dpd.country
                                  country,
                              -- End of Change 2.1
                              -- Start of change 2.2
                              pol.attribute8
                                  global_surcharge,
                              pol.attribute9
                                  ship_to_id_surcharge,
                              --  NVL(pol.unit_price,0) blended_fob  -- commented for ver 2.4
                              (NVL (pol.attribute11, pol.unit_price) + NVL (pol.attribute8, 0) + NVL (pol.attribute9, 0))
                                  blended_fob,                -- added ver 2.4
                              -- End of change 2.2
                              pha.attribute11
                                  gtn_transfer_flag,                     --2.5
                              DECODE (
                                  pha.attribute10,
                                  'XDOCK', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                              FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                             WHERE     ooha.header_id =
                                                       oola.header_id
                                                   AND oola.attribute15 =
                                                       TO_CHAR (
                                                           plla.line_location_id)
                                                   AND NVL (
                                                           oola.cancelled_flag,
                                                           'N') <>
                                                       'Y'
                                                   AND NVL (oola.context, 'X') !=
                                                       'DO eCommerce'
                                                   AND plla.po_line_id =
                                                       pol.po_line_id),
                                  'DIRECT_SHIP', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                                    FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                                   WHERE     ooha.header_id =
                                                             oola.header_id
                                                         AND oola.attribute16 =
                                                             TO_CHAR (
                                                                 plla.line_location_id)
                                                         AND NVL (
                                                                 oola.cancelled_flag,
                                                                 'N') <>
                                                             'Y'
                                                         AND NVL (oola.context,
                                                                  'X') !=
                                                             'DO eCommerce'
                                                         AND plla.po_line_id =
                                                             pol.po_line_id),
                                  NULL)
                                  so_number                              --2.5
                         FROM /*-------------------------------------------------------------------------------------
                             Start Changes by BT Technology Team v1.2 on 02-APR-2015
                             ---------------------------------------------------------------------------------------
                                             --apps.do_po_details_v dpd
                                             --  ,apps.mtl_categories_b mcb
                                                    -- ,apps.mtl_item_categories mic
                                                    --,apps.ra_customers rc
                                                     --,apps.fnd_lookup_values_vl sales_reg
                                                      --,apps.po_vendor_sites_all pvsa   -- Commented the above line and added this table by Anil as part of ENHC0011973
                             */
                              apps.do_po_details dpd, apps.po_lines_all pol, xxd_common_items_v xci,
                              -- Start CCR0006426
                              --xxd_ra_customers_v rc,
                              hz_cust_accounts hca, hz_parties hp, -- End CCR0006426
                                                                   apps.oe_order_headers_all oeh,
                              apps.mtl_parameters mp, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                              apps.po_headers_all pha --,do_custom.do_po_shipment_details dpsd
                                                     , ap_supplier_sites_all pvsa, apps.po_agents_v pav -- SFS_BUYER
                        /*----------------------------------------------------------------------------------------------------
                        End changes by BT Technology Team v1.2 on 02-APR-2015
                        ------------------------------------------------------------------------------------------------------*/
                        WHERE --mic.inventory_item_id = dpd.item_id  --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                  xci.inventory_item_id = dpd.item_id --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                              AND pol.po_line_id = dpd.po_line_id
                              --AND pol.attribute_category = 'PO Data Elements'         -- Aded as per Change 2.1
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                              AND      mcb.structure_id = 101
                                              AND      mic.category_set_id = 1
                                              AND      mic.organization_id = dpd.ship_to_organization_id
                                              AND      mic.organization_id = mp.organization_id
                              */
                              AND xci.organization_id = mp.organization_id
                              AND xci.organization_id =
                                  dpd.ship_to_organization_id
                              /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --AND      mp.attribute1 = sales_reg.lookup_code(+)
                              AND mp.attribute1 = ffv.flex_value(+)
                              /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                             -- AND      sales_reg.lookup_type(+) = 'DO_SALES_REGIONS'
                                              --AND      mcb.segment2 = NVL (p_product_group, mcb.segment2)
                                               -- AND      mcb.category_id = mic.category_id
                              */
                              AND ffvs.flex_value_set_name = 'DO_SALES_REGION'
                              AND ffv.flex_value_set_id =
                                  ffvs.flex_value_set_id
                              AND mp.attribute1 =
                                  NVL (p_sales_region, mp.attribute1)
                              AND xci.department =
                                  NVL (p_product_group, xci.department)
                              /*----------------------------------------------------------------------------------------------------
                              End changes by BT Technology Team v1.2 on 02-APR-2015
                              ------------------------------------------------------------------------------------------------------*/
                              AND dpd.order_header_id = oeh.header_id(+)
                              -- Start CCR0006426
                              --AND oeh.sold_to_org_id = rc.customer_id(+)
                              AND oeh.sold_to_org_id = hca.cust_account_id(+)
                              AND hca.party_id = hp.party_id(+)
                              -- End CCR0006426
                              AND dpd.po_header_id = pha.po_header_id
                              AND dpd.org_id = pha.org_id
                              --                AND      dpd.po_header_id = dpsd.po_header_id(+)
                              --                AND      dpd.color = dpsd.color(+)
                              --                AND      dpd.ship_to_location_id = dpsd.ship_to_location_id(+)
                              --                AND      dpd.style = dpsd.style(+)
                              AND pha.vendor_site_id = pvsa.vendor_site_id -- Commented above lines added this condition by Anil as part of ENHC0011973
                              --AND dpd.buy_season =
                              --       NVL (p_buy_season, dpd.buy_season)  -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_season, 'XXX') =
                                  NVL (p_buy_season,
                                       NVL (dpd.buy_season, 'XXX')) -- CCR0005924 ITEM_TYPE
                              --AND dpd.buy_month = NVL (p_buy_month, dpd.buy_month) -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_month, 'XXX') =
                                  NVL (p_buy_month, NVL (dpd.buy_month, 'XXX')) -- CCR0005924 ITEM_TYPE
                              -- Start CCR0006426
                              --AND dpd.po_date >= NVL (po_from_date, dpd.po_date)
                              AND dpd.po_date >=
                                  NVL (po_from_date, '06-APR-2016')
                              --AND dpd.po_date <= NVL (po_to_date, dpd.po_date)
                              AND dpd.po_date <= NVL (po_to_date, SYSDATE)
                              -- End CCR0006426
                              --AND NVL(dpd.cancelled_quantity,0) = 0  -- Added as per change 2.2 -- Commented as per ver 2.3
                              AND (NVL (dpd.line_quantity, 0) - NVL (dpd.cancelled_quantity, 0)) >
                                  0                    -- Added as per ver 2.3
                              AND dpd.conf_ex_factory_date >=
                                  NVL (ex_from_date, dpd.conf_ex_factory_date)
                              AND dpd.conf_ex_factory_date <=
                                  NVL (ex_to_date, dpd.conf_ex_factory_date)
                              AND (dpd.po_number BETWEEN NVL (p_po_number_lo, dpd.po_number) AND NVL (p_po_number_hi, dpd.po_number))
                              AND dpd.vendor_name =
                                  NVL (p_vendor_name, dpd.vendor_name)
                              AND dpd.style = NVL (p_style, dpd.style)
                              AND dpd.color = NVL (p_color, dpd.color)
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --AND      mcb.segment1 = NVL (p_brand, mcb.segment1)
                              AND xci.brand = NVL (p_brand, xci.brand)
                              /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              /*AND dpd.style NOT LIKE 'S%'*/
                              -- CCR0005924 ITEM_TYPE
                              AND xci.user_item_type NOT IN ('SAMPLE') -- CCR0005924 ITEM_TYPE
                              AND pha.agent_id = pav.agent_id     -- SFS_BUYER
                              --Start changes by V1.91 Arun N Murthy
                              --       AND pav.agent_name <> 'SFS-US, BUYER' -- SFS_BUYER
                              AND pav.agent_name NOT IN
                                      (SELECT description
                                         FROM fnd_lookup_values
                                        WHERE     1 = 1
                                              AND lookup_type LIKE
                                                      'XXD_PO_SFS_BUYER_LKP'
                                              AND language = USERENV ('LANG')
                                              AND SYSDATE BETWEEN start_date_active
                                                              AND   NVL (
                                                                        end_date_active,
                                                                        SYSDATE)
                                                                  + 1
                                              AND tag =
                                                  'XXDO_PO_LISTING_BY_SIZE'
                                              AND enabled_flag = 'Y')
                     -- END changes by V1.91 Arun N Murthy    -- SFS_BUYER
                     GROUP BY                              -- Start CCR0006426
                              --rc.customer_name,
                              hp.party_name, -- End CCR0006426
                                             dpd.country, dpd.po_date,
                              dpd.po_number, dpd.vendor_name, dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                                                    dpd.color, dpd.item_size,
                              dpd.ship_to_location_id, dpd.ex_factory_date, dpd.conf_ex_factory_date,
                              dpd.promised_date /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                               --,mcb.segment1
                              , xci.brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                         , dpd.item_id,
                              pol.unit_price, dpd.buy_month, dpd.buy_season --,dpsd.comments_5
                                                                           -- Start of Change 2.1
                                                                           ,
                              pol.attribute7, pha.attribute10, xci.department,
                              -- End of Change
                              -- Start of change 2.2
                              pol.attribute8, pol.attribute9, pol.attribute11, -- ver 2.4
                              pol.unit_price, pha.vendor_id, mp.organization_code,
                              dpd.location_code,        --Added as per ver 2.3
                                                 pha.segment1, -- End of Change
                                                               pha.attribute11, --2.5
                              pol.po_line_id,                            --2.5
                                              pvsa.vendor_site_code); -- Commented the above line and added this table by Anil as part of ENHC0011973
            END IF;
        ELSIF p_sample = 'SAMPLE'
        THEN
            IF ((p_conf_ex_fact_date_lo IS NULL) AND (p_conf_ex_fact_date_hi IS NULL))
            THEN
                INSERT INTO xxdo_main_data
                    (  SELECT dpd.vendor_name,
                              dpd.po_date,
                              dpd.po_number,
                              dpd.ship_to_location_id,
                              dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                              dpd.color,
                              dpd.item_size,
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              /*dpd.ex_factory_date,
                              dpd.conf_ex_factory_date,
                              dpd.promised_date*/
                              -- ,dpd.country dest
                              TO_CHAR (dpd.ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.conf_ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.promised_date, 'DD-MON-YYYY') /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                                        ,
                              -- Start CCR0006426
                              /*DECODE (
                                 rc.customer_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 rc.customer_name)
                                 dest*/
                              -- Start of Change 2.2
                              /*DECODE (
                                 hp.party_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 hp.party_name)
                                 dest                             -- End CCR0006426
                                     /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --,mcb.segment1 brand
                              /* --START Commented as per ver 2.3
            get_dest_name(
                              DECODE (
                                 hp.party_name,
                                 '', mp.organization_code,
                                 hp.party_name),pha.vendor_id,pha.segment1)
                                 dest
                              -- End of change
                              ,
            */
                              --END Commented as per ver 2.3
                              --START Added as per ver 2.3
                              NVL (
                                  get_dest_name (
                                      DECODE (hp.party_name,
                                              '', mp.organization_code,
                                              hp.party_name),
                                      pha.vendor_id,
                                      pha.segment1),
                                  dpd.location_code)
                                  dest,
                              --END Added as per ver 2.3
                              xci.brand
                                  brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                       ,
                                NVL (SUM (dpd.line_quantity), 0)
                              - NVL (SUM (dpd.cancelled_quantity), 0)
                                  po_qty,
                              NVL (SUM (dpd.received_quantity), 0)
                                  rcv_qty,
                              ((NVL (SUM (dpd.line_quantity), 0) - NVL (SUM (dpd.cancelled_quantity), 0)) - (NVL (SUM (dpd.received_quantity), 0)))
                                  bal_qty,
                              --pol.unit_price,  -- commented for ver 2.4
                              NVL (pol.attribute11, pol.unit_price)
                                  unit_price,             --added for  ver 2.4
                              dpd.buy_month,
                              dpd.buy_season  --,dpsd.comments_5 facility_site
                                            ,
                              --pvsa.vendor_site_code facility_site, -- added by Anil as part of ENHC0011973
                              NVL (pol.attribute7, pvsa.vendor_site_code)
                                  facility_site,     -- Aded as per Change 2.1
                              -- Start of Change 2.2
                              NULL
                                  etd_port,
                              /*DECODE (
                                 (SELECT msa.attribute1
                                    FROM apps.mrp_sourcing_rules msr,
                                         apps.mrp_sr_assignments msa,
                                         apps.mrp_assignment_sets msas,
                                         apps.fnd_lookup_values fnl,
                                         apps.mtl_item_categories mic,
                                         apps.mtl_categories_b mcb,
                                         apps.mtl_parameters mtp
                                   WHERE     msr.sourcing_rule_id =
                                                msa.sourcing_rule_id
                                         AND msas.assignment_set_id =
                                                msa.assignment_set_id
                                         AND msa.inventory_item_id IS NULL
                                         AND msas.assignment_set_name = 'AS - US'
                                         AND msr.status = 1
                                         AND fnl.lookup_code = msa.assignment_type
                                         AND NVL (fnl.end_date_active,
                                                  TRUNC (SYSDATE + 1)) >=
                                                TRUNC (SYSDATE)
                                         AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                         AND fnl.lookup_type = 'MRP_ASSIGNMENT_TYPE'
                                         AND fnl.language = 'US'
                                         AND mic.category_id = mcb.category_id
                                         AND mic.category_id = msa.category_id
                                         AND mic.category_set_id =
                                                msa.category_set_id
                                         AND mtp.organization_id =
                                                mic.organization_id
                                         AND mtp.organization_code = 'VNT'
                                         AND fnl.meaning = 'Category'
                                         AND ROWNUM <= 1),
                                 NULL, (SELECT msa.attribute1
                                          FROM apps.mrp_sourcing_rules msr,
                                               apps.mrp_sr_assignments msa,
                                               apps.mrp_assignment_sets msas,
                                               apps.fnd_lookup_values fnl
                                         WHERE     msa.sourcing_rule_id =
                                                      msr.sourcing_rule_id
                                               AND msas.assignment_set_id =
                                                      msa.assignment_set_id
                                               AND msa.inventory_item_id IS NOT NULL
                                               AND msas.assignment_set_name =
                                                      'AS - US'
                                               AND msr.status = 1
                                               AND fnl.lookup_code =
                                                      msa.assignment_type
                                               AND NVL (fnl.end_date_active,
                                                        TRUNC (SYSDATE + 1)) >=
                                                      TRUNC (SYSDATE)
                                               AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                               AND fnl.lookup_type =
                                                      'MRP_ASSIGNMENT_TYPE'
                                               AND fnl.language = 'US'
                                               AND fnl.meaning = 'Item'
                                               AND ROWNUM <= 1),
                                 NULL)
                                 etd_port,*/
                              -- End of Change 2.2
                              SUM (pol.quantity * pol.unit_price)
                                  total_price,
                              -- Start of Change 2.1
                              xci.department
                                  product_category,
                              pha.attribute10
                                  po_type,
                              dpd.country
                                  country,
                              -- End of Change 2.1
                              -- Start of change 2.2
                              pol.attribute8
                                  global_surcharge,
                              pol.attribute9
                                  ship_to_id_surcharge,
                              -- NVL(pol.unit_price,0) blended_fob  -- co for ver 2.4
                              (NVL (pol.attribute11, pol.unit_price) + NVL (pol.attribute8, 0) + NVL (pol.attribute9, 0))
                                  blended_fob,                -- added ver 2.4
                              -- End of change 2.2
                              pha.attribute11
                                  gtn_transfer_flag,                     --2.5
                              DECODE (
                                  pha.attribute10,
                                  'XDOCK', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                              FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                             WHERE     ooha.header_id =
                                                       oola.header_id
                                                   AND oola.attribute15 =
                                                       TO_CHAR (
                                                           plla.line_location_id)
                                                   AND NVL (
                                                           oola.cancelled_flag,
                                                           'N') <>
                                                       'Y'
                                                   AND NVL (oola.context, 'X') !=
                                                       'DO eCommerce'
                                                   AND plla.po_line_id =
                                                       pol.po_line_id),
                                  'DIRECT_SHIP', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                                    FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                                   WHERE     ooha.header_id =
                                                             oola.header_id
                                                         AND oola.attribute16 =
                                                             TO_CHAR (
                                                                 plla.line_location_id)
                                                         AND NVL (
                                                                 oola.cancelled_flag,
                                                                 'N') <>
                                                             'Y'
                                                         AND NVL (oola.context,
                                                                  'X') !=
                                                             'DO eCommerce'
                                                         AND plla.po_line_id =
                                                             pol.po_line_id),
                                  NULL)
                                  so_number                              --2.5
                         FROM /*-------------------------------------------------------------------------------------
                             Start Changes by BT Technology Team v1.2 on 02-APR-2015
                             ---------------------------------------------------------------------------------------
                                             --apps.do_po_details_v dpd
                                             --  ,apps.mtl_categories_b mcb
                                                    -- ,apps.mtl_item_categories mic
                                                     --,apps.ra_customers rc
                                                      --,apps.fnd_lookup_values_vl sales_reg
                                                      --,apps.po_vendor_sites_all pvsa   -- Commented the above line and added this table by Anil as part of ENHC0011973
                             */
                              apps.do_po_details dpd, apps.po_lines_all pol, xxd_common_items_v xci, --Ravi
                              -- Start CCR0006426
                              --xxd_ra_customers_v rc,
                              hz_cust_accounts hca, hz_parties hp, -- End CCR0006426
                                                                   apps.oe_order_headers_all oeh,
                              apps.mtl_parameters mp, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                              apps.po_headers_all pha --, do_custom.do_po_shipment_details dpsd
                                                     , ap_supplier_sites_all pvsa, apps.po_agents_v pav -- SFS_BUYER
                        /*----------------------------------------------------------------------------------------------------
                        End changes by BT Technology Team v1.2 on 02-APR-2015
                        ------------------------------------------------------------------------------------------------------*/
                        WHERE --mic.inventory_item_id = dpd.item_id --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                  xci.inventory_item_id = dpd.item_id --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                              AND pol.po_line_id = dpd.po_line_id
                              --AND pol.attribute_category = 'PO Data Elements'         -- Aded as per Change 2.1
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                              AND      mcb.structure_id = 101
                                              AND      mic.category_set_id = 1
                                              AND      mic.organization_id = dpd.ship_to_organization_id
                                              AND      mic.organization_id = mp.organization_id
                              */
                              AND xci.organization_id = mp.organization_id
                              AND xci.organization_id =
                                  dpd.ship_to_organization_id
                              /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --AND      mp.attribute1 = sales_reg.lookup_code(+)
                              AND mp.attribute1 = ffv.flex_value(+)
                              /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                              --AND      sales_reg.lookup_type(+) = 'DO_SALES_REGIONS'
                                              --AND      mcb.segment2 = NVL (p_product_group, mcb.segment2)
                                               -- AND      mcb.category_id = mic.category_id
                              */
                              AND ffvs.flex_value_set_name = 'DO_SALES_REGION'
                              AND ffv.flex_value_set_id =
                                  ffvs.flex_value_set_id
                              AND mp.attribute1 =
                                  NVL (p_sales_region, mp.attribute1)
                              AND xci.department =
                                  NVL (p_product_group, xci.department)
                              /*----------------------------------------------------------------------------------------------------
                              End changes by BT Technology Team v1.2 on 02-APR-2015
                              ------------------------------------------------------------------------------------------------------*/
                              AND dpd.order_header_id = oeh.header_id(+)
                              -- Start CCR0006426
                              --AND oeh.sold_to_org_id = rc.customer_id(+)
                              AND oeh.sold_to_org_id = hca.cust_account_id(+)
                              AND hca.party_id = hp.party_id(+)
                              -- End CCR0006426
                              AND dpd.po_header_id = pha.po_header_id
                              AND dpd.org_id = pha.org_id
                              --                AND      dpd.po_header_id = dpsd.po_header_id(+)
                              --                AND      dpd.color = dpsd.color(+)
                              --                AND      dpd.ship_to_location_id = dpsd.ship_to_location_id(+)
                              --                AND      dpd.style = dpsd.style(+)
                              AND pha.vendor_site_id = pvsa.vendor_site_id -- Commented above lines added this condition by Anil as part of ENHC0011973
                              --AND dpd.buy_season =
                              --       NVL (p_buy_season, dpd.buy_season)  -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_season, 'XXX') =
                                  NVL (p_buy_season,
                                       NVL (dpd.buy_season, 'XXX')) -- CCR0005924 ITEM_TYPE
                              --AND dpd.buy_month = NVL (p_buy_month, dpd.buy_month) -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_month, 'XXX') =
                                  NVL (p_buy_month, NVL (dpd.buy_month, 'XXX')) -- CCR0005924 ITEM_TYPE
                              -- Start CCR0006426
                              --AND dpd.po_date >= NVL (po_from_date, dpd.po_date)
                              AND dpd.po_date >=
                                  NVL (po_from_date, '06-APR-2016')
                              --AND dpd.po_date <= NVL (po_to_date, dpd.po_date)
                              AND dpd.po_date <= NVL (po_to_date, SYSDATE)
                              -- End CCR0006426
                              --AND NVL(dpd.cancelled_quantity,0) = 0  -- Added as per change 2.2 -- Commented as per ver 2.3
                              AND (NVL (dpd.line_quantity, 0) - NVL (dpd.cancelled_quantity, 0)) >
                                  0                    -- Added as per ver 2.3
                              AND NVL (dpd.conf_ex_factory_date, '1-JAN-13') >=
                                  NVL (
                                      ex_from_date,
                                      NVL (dpd.conf_ex_factory_date,
                                           '1-JAN-13'))
                              AND NVL (dpd.conf_ex_factory_date, '1-JAN-13') <=
                                  NVL (
                                      ex_to_date,
                                      NVL (dpd.conf_ex_factory_date,
                                           '1-JAN-13'))
                              AND (dpd.po_number BETWEEN NVL (p_po_number_lo, dpd.po_number) AND NVL (p_po_number_hi, dpd.po_number))
                              AND dpd.vendor_name =
                                  NVL (p_vendor_name, dpd.vendor_name)
                              AND dpd.style = NVL (p_style, dpd.style)
                              AND dpd.color = NVL (p_color, dpd.color)
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              -- AND      mcb.segment1 = NVL (p_brand, mcb.segment1)
                              AND xci.brand = NVL (p_brand, xci.brand)
                              /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              /*AND dpd.style LIKE 'S%'*/
                              -- CCR0005924 ITEM_TYPE
                              AND xci.user_item_type IN ('SAMPLE') -- CCR0005924 ITEM_TYPE
                              AND pha.agent_id = pav.agent_id     -- SFS_BUYER
                              --Start changes by V1.91 Arun N Murthy
                              --       AND pav.agent_name <> 'SFS-US, BUYER' -- SFS_BUYER
                              AND pav.agent_name NOT IN
                                      (SELECT description
                                         FROM fnd_lookup_values
                                        WHERE     1 = 1
                                              AND lookup_type LIKE
                                                      'XXD_PO_SFS_BUYER_LKP'
                                              AND language = USERENV ('LANG')
                                              AND SYSDATE BETWEEN start_date_active
                                                              AND   NVL (
                                                                        end_date_active,
                                                                        SYSDATE)
                                                                  + 1
                                              AND tag =
                                                  'XXDO_PO_LISTING_BY_SIZE'
                                              AND enabled_flag = 'Y')
                     -- END changes by V1.91 Arun N Murthy   -- SFS_BUYER
                     GROUP BY                              -- Start CCR0006426
                              --rc.customer_name,
                              hp.party_name, -- End CCR0006426
                                             dpd.country, dpd.po_date,
                              dpd.po_number, dpd.vendor_name, dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                                                    dpd.color, dpd.item_size,
                              dpd.ship_to_location_id, dpd.ex_factory_date, dpd.conf_ex_factory_date,
                              dpd.promised_date /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                               --,mcb.segment1
                              , xci.brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                         , dpd.item_id,
                              pol.unit_price, dpd.buy_month, dpd.buy_season --,dpsd.comments_5
                                                                           -- Start of Change 2.1
                                                                           ,
                              pol.attribute7, pha.attribute10, xci.department-- End of Change
                                                                             -- Start of change 2.2
                                                                             ,
                              pol.attribute8, pol.attribute9, pol.attribute11, -- ver 2.4
                              pol.unit_price, pha.vendor_id, mp.organization_code,
                              dpd.location_code,        --Added as per ver 2.3
                                                 pha.segment1, -- End of Change
                                                               pha.attribute11 --2.5
                                                                              ,
                              pol.po_line_id,                            --2.5
                                              pvsa.vendor_site_code); -- Commented the above line and added this table by Anil as part of ENHC0011973
            ELSE
                INSERT INTO xxdo_main_data
                    (  SELECT dpd.vendor_name,
                              dpd.po_date,
                              dpd.po_number,
                              dpd.ship_to_location_id,
                              dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                              dpd.color,
                              dpd.item_size,
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              /*dpd.ex_factory_date,
                              dpd.conf_ex_factory_date,
                              dpd.promised_date*/
                              -- ,dpd.country dest
                              TO_CHAR (dpd.ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.conf_ex_factory_date, 'DD-MON-YYYY'),
                              TO_CHAR (dpd.promised_date, 'DD-MON-YYYY') /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                                        ,
                              -- Start CCR0006426
                              /*DECODE (
                                 rc.customer_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 rc.customer_name)
                                 dest*/
                              -- Start of Change 2.2
                              /*DECODE (
                                 hp.party_name,
                                 '', DECODE (dpd.country, 'US', 'USA', dpd.country),
                                 hp.party_name)
                                 dest                             -- End CCR0006426
                                     /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --,mcb.segment1 brand
                              /* --START Commented as per ver 2.3
            get_dest_name(
                              DECODE (
                                 hp.party_name,
                                 '', mp.organization_code,
                                 hp.party_name),pha.vendor_id,pha.segment1)
                                 dest,
                              -- End of change
            */
                              --END Commented as per ver 2.3
                              --START Added as per ver 2.3
                              NVL (
                                  get_dest_name (
                                      DECODE (hp.party_name,
                                              '', mp.organization_code,
                                              hp.party_name),
                                      pha.vendor_id,
                                      pha.segment1),
                                  dpd.location_code)
                                  dest,
                              --END Added as per ver 2.3
                              xci.brand
                                  brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                       ,
                                NVL (SUM (dpd.line_quantity), 0)
                              - NVL (SUM (dpd.cancelled_quantity), 0)
                                  po_qty,
                              NVL (SUM (dpd.received_quantity), 0)
                                  rcv_qty,
                              ((NVL (SUM (dpd.line_quantity), 0) - NVL (SUM (dpd.cancelled_quantity), 0)) - (NVL (SUM (dpd.received_quantity), 0)))
                                  bal_qty,
                              --  pol.unit_price,  -- ver 2.4
                              NVL (pol.attribute11, pol.unit_price)
                                  unit_price,             --added for  ver 2.4
                              dpd.buy_month,
                              dpd.buy_season  --,dpsd.comments_5 facility_site
                                            ,
                              -- pvsa.vendor_site_code facility_site, -- added by Anil as part of ENHC0011973
                              NVL (pol.attribute7, pvsa.vendor_site_code)
                                  facility_site,     -- Aded as per Change 2.1
                              -- Start of Change 2.2
                              NULL
                                  etd_port,
                              /*
                              DECODE (
                                 (SELECT msa.attribute1
                                    FROM apps.mrp_sourcing_rules msr,
                                         apps.mrp_sr_assignments msa,
                                         apps.mrp_assignment_sets msas,
                                         apps.fnd_lookup_values fnl,
                                         apps.mtl_item_categories mic,
                                         apps.mtl_categories_b mcb,
                                         apps.mtl_parameters mtp
                                   WHERE     msr.sourcing_rule_id =
                                                msa.sourcing_rule_id
                                         AND msas.assignment_set_id =
                                                msa.assignment_set_id
                                         AND msa.inventory_item_id IS NULL
                                         AND msas.assignment_set_name = 'AS - US'
                                         AND msr.status = 1
                                         AND fnl.lookup_code = msa.assignment_type
                                         AND NVL (fnl.end_date_active,
                                                  TRUNC (SYSDATE + 1)) >=
                                                TRUNC (SYSDATE)
                                         AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                         AND fnl.lookup_type = 'MRP_ASSIGNMENT_TYPE'
                                         AND fnl.language = 'US'
                                         AND mic.category_id = mcb.category_id
                                         AND mic.category_id = msa.category_id
                                         AND mic.category_set_id =
                                                msa.category_set_id
                                         AND mtp.organization_id =
                                                mic.organization_id
                                         AND mtp.organization_code = 'VNT'
                                         AND fnl.meaning = 'Category'
                                         AND ROWNUM <= 1),
                                 NULL, (SELECT msa.attribute1
                                          FROM apps.mrp_sourcing_rules msr,
                                               apps.mrp_sr_assignments msa,
                                               apps.mrp_assignment_sets msas,
                                               apps.fnd_lookup_values fnl
                                         WHERE     msa.sourcing_rule_id =
                                                      msr.sourcing_rule_id
                                               AND msas.assignment_set_id =
                                                      msa.assignment_set_id
                                               AND msa.inventory_item_id IS NOT NULL
                                               AND msas.assignment_set_name =
                                                      'AS - US'
                                               AND msr.status = 1
                                               AND fnl.lookup_code =
                                                      msa.assignment_type
                                               AND NVL (fnl.end_date_active,
                                                        TRUNC (SYSDATE + 1)) >=
                                                      TRUNC (SYSDATE)
                                               AND NVL (fnl.enabled_flag, 'N') = 'Y'
                                               AND fnl.lookup_type =
                                                      'MRP_ASSIGNMENT_TYPE'
                                               AND fnl.language = 'US'
                                               AND fnl.meaning = 'Item'
                                               AND ROWNUM <= 1),
                                 NULL)
                                 etd_port,*/
                              -- End of Change 2.2
                              SUM (pol.quantity * pol.unit_price)
                                  total_price,
                              -- Start of Change 2.1
                              xci.department
                                  product_category,
                              pha.attribute10
                                  po_type,
                              dpd.country
                                  country,
                              -- End of Change 2.1
                              -- Start of change 2.2
                              pol.attribute8
                                  global_surcharge,
                              pol.attribute9
                                  ship_to_id_surcharge,
                              --  NVL(pol.unit_price,0) blended_fob  -- ver 2.4
                              (NVL (pol.attribute11, pol.unit_price) + NVL (pol.attribute8, 0) + NVL (pol.attribute9, 0))
                                  blended_fob,                -- added ver 2.4
                              -- End of change 2.2
                              pha.attribute11
                                  gtn_transfer_flag,                     --2.5
                              DECODE (
                                  pha.attribute10,
                                  'XDOCK', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                              FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                             WHERE     ooha.header_id =
                                                       oola.header_id
                                                   AND oola.attribute15 =
                                                       TO_CHAR (
                                                           plla.line_location_id)
                                                   AND NVL (
                                                           oola.cancelled_flag,
                                                           'N') <>
                                                       'Y'
                                                   AND NVL (oola.context, 'X') !=
                                                       'DO eCommerce'
                                                   AND plla.po_line_id =
                                                       pol.po_line_id),
                                  'DIRECT_SHIP', (SELECT LISTAGG (DISTINCT ooha.order_number, ', ') WITHIN GROUP (ORDER BY ooha.order_number)
                                                    FROM oe_order_headers_all ooha, apps.oe_order_lines_all oola, apps.po_line_locations_all plla
                                                   WHERE     ooha.header_id =
                                                             oola.header_id
                                                         AND oola.attribute16 =
                                                             TO_CHAR (
                                                                 plla.line_location_id)
                                                         AND NVL (
                                                                 oola.cancelled_flag,
                                                                 'N') <>
                                                             'Y'
                                                         AND NVL (oola.context,
                                                                  'X') !=
                                                             'DO eCommerce'
                                                         AND plla.po_line_id =
                                                             pol.po_line_id),
                                  NULL)
                                  so_number                              --2.5
                         FROM /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                              --apps.do_po_details_v dpd
                                              -- ,apps.mtl_categories_b mcb
                                                     -- ,apps.mtl_item_categories mic
                                                     --,apps.ra_customers rc
                                                     -- ,apps.fnd_lookup_values_vl sales_reg
                                                     --,apps.po_vendor_sites_all pvsa   -- Commented the above line and added this table by Anil as part of ENHC0011973
                              */
                              apps.do_po_details dpd, apps.po_lines_all pol, xxd_common_items_v xci,
                              -- Start CCR0006426
                              --xxd_ra_customers_v rc,
                              hz_cust_accounts hca, hz_parties hp, -- End CCR0006426
                                                                   apps.oe_order_headers_all oeh,
                              apps.mtl_parameters mp, fnd_flex_value_sets ffvs, fnd_flex_values ffv,
                              apps.po_headers_all pha --  ,do_custom.do_po_shipment_details dpsd
                                                     , ap_supplier_sites_all pvsa, apps.po_agents_v pav -- SFS_BUYER
                        /*----------------------------------------------------------------------------------------------------
                        End changes by BT Technology Team v1.2 on 02-APR-2015
                        ------------------------------------------------------------------------------------------------------*/
                        WHERE --mic.inventory_item_id = dpd.item_id --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                  xci.inventory_item_id = dpd.item_id --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                              AND pol.po_line_id = dpd.po_line_id
                              --AND pol.attribute_category = 'PO Data Elements'         -- Aded as per Change 2.1
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                              AND      mcb.structure_id = 101
                                              AND      mic.category_set_id = 1
                                              AND      mic.organization_id = dpd.ship_to_organization_id
                                              AND      mic.organization_id = mp.organization_id
                              */
                              AND xci.organization_id = mp.organization_id
                              AND xci.organization_id =
                                  dpd.ship_to_organization_id
                              /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              --AND      mp.attribute1 = sales_reg.lookup_code(+)
                              AND mp.attribute1 = ffv.flex_value(+)
                              /*-------------------------------------------------------------------------------------
                              Start Changes by BT Technology Team v1.2 on 02-APR-2015
                              ---------------------------------------------------------------------------------------
                                             -- AND      sales_reg.lookup_type(+) = 'DO_SALES_REGIONS'
                                              -- AND      mcb.segment2 = NVL (p_product_group, mcb.segment2)
                                              --AND      mcb.category_id = mic.category_id
                              */
                              AND ffvs.flex_value_set_name = 'DO_SALES_REGION'
                              AND ffv.flex_value_set_id =
                                  ffvs.flex_value_set_id
                              AND mp.attribute1 =
                                  NVL (p_sales_region, mp.attribute1)
                              AND xci.department =
                                  NVL (p_product_group, xci.department)
                              /*----------------------------------------------------------------------------------------------------
                              End changes by BT Technology Team v1.2 on 02-APR-2015
                              ------------------------------------------------------------------------------------------------------*/
                              AND dpd.order_header_id = oeh.header_id(+)
                              -- Start CCR0006426
                              --AND oeh.sold_to_org_id = rc.customer_id(+)
                              AND oeh.sold_to_org_id = hca.cust_account_id(+)
                              AND hca.party_id = hp.party_id(+)
                              -- End CCR0006426
                              AND dpd.po_header_id = pha.po_header_id
                              AND dpd.org_id = pha.org_id
                              --                AND      dpd.po_header_id = dpsd.po_header_id(+)
                              --                AND      dpd.color = dpsd.color(+)
                              --                AND      dpd.ship_to_location_id = dpsd.ship_to_location_id(+)
                              --                AND      dpd.style = dpsd.style(+)
                              AND pha.vendor_site_id = pvsa.vendor_site_id -- Commented above lines added this condition by Anil as part of ENHC0011973
                              --AND dpd.buy_season =
                              --       NVL (p_buy_season, dpd.buy_season)  -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_season, 'XXX') =
                                  NVL (p_buy_season,
                                       NVL (dpd.buy_season, 'XXX')) -- CCR0005924 ITEM_TYPE
                              --AND dpd.buy_month = NVL (p_buy_month, dpd.buy_month) -- CCR0005924 ITEM_TYPE
                              AND NVL (dpd.buy_month, 'XXX') =
                                  NVL (p_buy_month, NVL (dpd.buy_month, 'XXX')) -- CCR0005924 ITEM_TYPE
                              -- Start CCR0006426
                              --AND dpd.po_date >= NVL (po_from_date, dpd.po_date)
                              AND dpd.po_date >=
                                  NVL (po_from_date, '06-APR-2016')
                              --AND dpd.po_date <= NVL (po_to_date, dpd.po_date)
                              AND dpd.po_date <= NVL (po_to_date, SYSDATE)
                              -- End CCR0006426
                              --AND NVL(dpd.cancelled_quantity,0) = 0  -- Added as per change 2.2 -- Commented as per ver 2.3
                              AND (NVL (dpd.line_quantity, 0) - NVL (dpd.cancelled_quantity, 0)) >
                                  0                    -- Added as per ver 2.3
                              AND dpd.conf_ex_factory_date >=
                                  NVL (ex_from_date, dpd.conf_ex_factory_date)
                              AND dpd.conf_ex_factory_date <=
                                  NVL (ex_to_date, dpd.conf_ex_factory_date)
                              AND (dpd.po_number BETWEEN NVL (p_po_number_lo, dpd.po_number) AND NVL (p_po_number_hi, dpd.po_number))
                              AND dpd.vendor_name =
                                  NVL (p_vendor_name, dpd.vendor_name)
                              AND dpd.style = NVL (p_style, dpd.style)
                              AND dpd.color = NVL (p_color, dpd.color)
                              /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              -- AND      mcb.segment1 = NVL (p_brand, mcb.segment1)
                              AND xci.brand = NVL (p_brand, xci.brand)
                              /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                              /*AND dpd.style LIKE 'S%'*/
                              -- CCR0005924 ITEM_TYPE
                              AND xci.user_item_type IN ('SAMPLE') -- CCR0005924 ITEM_TYPE
                              AND pha.agent_id = pav.agent_id     -- SFS_BUYER
                              --Start changes by V1.91 Arun N Murthy
                              --       AND pav.agent_name <> 'SFS-US, BUYER' -- SFS_BUYER
                              AND pav.agent_name NOT IN
                                      (SELECT description
                                         FROM fnd_lookup_values
                                        WHERE     1 = 1
                                              AND lookup_type LIKE
                                                      'XXD_PO_SFS_BUYER_LKP'
                                              AND language = USERENV ('LANG')
                                              AND SYSDATE BETWEEN start_date_active
                                                              AND   NVL (
                                                                        end_date_active,
                                                                        SYSDATE)
                                                                  + 1
                                              AND tag =
                                                  'XXDO_PO_LISTING_BY_SIZE'
                                              AND enabled_flag = 'Y')
                     -- END changes by V1.91 Arun N Murthy
                     GROUP BY                              -- Start CCR0006426
                              --rc.customer_name,
                              hp.party_name, -- End CCR0006426
                                             dpd.country, dpd.po_date,
                              dpd.po_number, dpd.vendor_name, dpd.style,
                              --dpd.style_name, --Commenting it out as part of INC0293852
                              xci.item_description, --Adding the column as part of INC0293852
                                                    dpd.color, dpd.item_size,
                              dpd.ship_to_location_id, dpd.ex_factory_date, dpd.conf_ex_factory_date,
                              dpd.promised_date /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                                               --,mcb.segment1
                              , xci.brand /*End Changes  by BT Technology Team v1.2 on 02-APR-2015 */
                                         , dpd.item_id,
                              pol.unit_price, dpd.buy_month, dpd.buy_season --,dpsd.comments_5
                                                                           -- Start of Change 2.1
                                                                           ,
                              pol.attribute7, pha.attribute10, xci.department,
                              -- End of Change
                              -- Start of change 2.2
                              pol.attribute8, pol.attribute9, pol.attribute11, -- ver 2.4
                              pol.unit_price, pha.vendor_id, mp.organization_code,
                              dpd.location_code,        --Added as per ver 2.3
                                                 pha.segment1, -- End of Change
                                                               pvsa.vendor_site_code,
                              pha.attribute11,                           --2.5
                                               pol.po_line_id            --2.5
                                                             ); -- Commented the above line and added this table by Anil as part of ENHC0011973
            END IF;
        END IF;

        BEGIN
            SELECT SUM (po_qty) INTO ln_qty FROM xxdo.xxdo_main_data;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_qty   := 0;
        END;

        INSERT INTO xxdo_po_listing_headers (attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, attribute21, attribute22, -- Added as a part of CCR0007335
                                                        -- Start of Change 2.1
                                              attribute23, attribute24,
                                             attribute25, attribute26, -- End of Change
                                                                       -- Start of Change 2.2
                                                                       attribute27, attribute28, attribute29, -- End of Change
                                                                                                              attribute251
                                             ,                           --2.5
                                               attribute252              --2.5
                                                           )
             VALUES ('Vendor Name', 'PO Rcv Date', 'PO NO#',
                     'Ship Loc ID', 'Style NO', 'Style Name',
                     'Color', 'Ex Fact Date', 'Conf Ex Fact',
                     'Promised Date', 'Dest', 'Brand',
                     'PO Qty', 'Rcv Qty', 'Bal Qty',
                     'Unit Price', 'Buy Month', 'Buy Season',
                     'Facility Site', 'ETD Port', 'Total Price',
                     'Item Type',             -- Added as a part of CCR0007335
                                  -- Start of Change 2.1
                                  'Product Category', 'PO Type',
                     'Destination Country', 'Destination Region', -- End of Change
                                                                  -- Start of Change 2.2
                                                                  'Global Surcharge', 'Ship to ID Surcharge', 'Blended FOB', -- End of Change 2.2
                                                                                                                             'GTN Transfer Flag'
                     ,                                                   --2.5
                       'SO Number'                                      -- 2.5
                                  );

        -- ln_count_num := 21; -- Commented as part of CCR0007335
        -- ln_count_num := 22;                       -- Commented as per change 2.1
        --ln_count_num := 26;                          -- Added as per Change 2.1

        ln_count_num   := 29;                       -- Added as per change 2.2

        --ln_count_num := 30; -- Added as per change 2.5
        IF p_sizes = 'Y'
        THEN
            FOR item_sizes_rec IN item_sizes_cur
            LOOP
                ln_count_num     := ln_count_num + 1;
                lv_column_name   := 'attribute' || ln_count_num;
                lv_query         :=
                       'update xxdo_po_listing_headers
               set '
                    || lv_column_name
                    || '='
                    || ''''
                    || item_sizes_rec.item_size
                    || ''''
                    || ' where attribute1=''Vendor Name''';

                EXECUTE IMMEDIATE lv_query;
            END LOOP;
        END IF;

        l_count        := 0;                                     -- CCR0006426

        FOR main_data_rec IN main_data_cur
        LOOP
            /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */
            --         lv_destname := NULL;
            --
            --         IF (NVL (main_data_rec.dest, '-XXX') <> 'USA')          -- CCR0007113
            --         THEN
            --            BEGIN
            --               SELECT DISTINCT                             --xrc.customer_name
            --                              hp.party_name
            --                 INTO lv_destname
            --                 FROM                                      -- Start CCR0006426
            --                      --xxd_ra_customers_v xrc,
            --                      hz_cust_accounts hca,
            --                      hz_parties hp,
            --                      -- End CCR0006426
            --                      oe_order_headers_all ooha,
            --                      oe_drop_ship_sources odss,
            --                      po_headers_all poh
            --                WHERE                                      -- Start CCR0006426
            --                          --xrc.customer_id = ooha.sold_to_org_id
            --                          hca.cust_account_id = ooha.sold_to_org_id
            --                      AND hca.party_id = hp.party_id
            --                      -- End CCR0006426
            --                      AND ooha.header_id = odss.header_id
            --                      AND odss.po_header_id = poh.po_header_id
            --                      AND poh.segment1 = main_data_rec.po_number;
            --            EXCEPTION
            --               WHEN NO_DATA_FOUND
            --               THEN
            --                  BEGIN
            --                     SELECT DISTINCT                         --c.customer_name
            --                                    hp.party_name
            --                       INTO lv_destname
            --                       FROM oe_order_lines_all oola,
            --                            oe_order_headers_all ooha,
            --                            --Start CCR0006426
            --                            --xxd_ra_customers_v c,
            --                            hz_cust_accounts hca,
            --                            hz_parties hp,
            --                            -- End CCR0006426
            --                            po_line_locations_all plla,
            --                            po_headers_all poh
            --                      WHERE     oola.header_id = ooha.header_id
            --                            --Start CCR0006426
            --                            --AND ooha.sold_to_org_id = c.customer_id
            --                            AND ooha.sold_to_org_id = hca.cust_account_id
            --                            AND hca.party_id = hp.party_id
            --                            --End CCR0006426
            --                            -- Start modificiation by BT Technology Team for V1.3 on 17-NOV-2015
            --                            --AND oola.attribute16 = plla.line_location_id
            --                            AND oola.attribute16 =
            --                                   TO_CHAR (plla.line_location_id)
            --                            -- End modificiation by BT Technology Team for V1.3 on 17-NOV-2015
            --                            AND plla.po_header_id = poh.po_header_id
            --                            AND poh.segment1 = main_data_rec.po_number;
            --                  EXCEPTION
            --                     WHEN OTHERS
            --                     THEN
            --                        lv_destname := NULL;
            --                  END;
            --               WHEN OTHERS
            --               THEN
            --                  lv_destname := NULL;
            --            END;
            --         END IF;                                                 -- CCR0007113
            --
            --         IF lv_destname IS NULL
            --         THEN
            --            lv_destname := main_data_rec.dest;
            --         END IF;
            --
            --         IF LENGTH (lv_destname) > 50
            --         THEN
            --            DBMS_OUTPUT.put_line (
            --                  'main_data_rec.po_number-'
            --               || main_data_rec.po_number
            --               || 'lv_destname -'
            --               || lv_destname);
            --         END IF;
            INSERT INTO xxdo_po_listing_headers (attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, attribute21, attribute22, -- added as part of CCR0007335
                                                        -- Start of Change 2.1
                                                  attribute23, attribute24,
                                                 attribute25, attribute26, -- End of Change
                                                                           -- Start of change 2.2
                                                                           attribute27, attribute28, attribute29, -- End of change
                                                                                                                  attribute251
                                                 ,                      -- 2.5
                                                   attribute252          --2.5
                                                               )
                 VALUES (main_data_rec.vendor_name, main_data_rec.po_date, main_data_rec.po_number, main_data_rec.ship_loc_id, main_data_rec.style, main_data_rec.style_name, main_data_rec.color, main_data_rec.requested_xf_date, main_data_rec.confirmed_xf_date, main_data_rec.promised_date, --main_data_rec.dest --Start Changes  by BT Technology Team v1.2 on 02-APR-2015
                                                                                                                                                                                                                                                                                                  --lv_destname, --End Changes  by BT Technology Team v1.2 on 02-APR-2015
                                                                                                                                                                                                                                                                                                  main_data_rec.dest, -- Added for Change 2.2
                                                                                                                                                                                                                                                                                                                      main_data_rec.brand, main_data_rec.po_shipment_qty, main_data_rec.rcv_qty, main_data_rec.bal_qty, main_data_rec.unit_price, main_data_rec.buy_month, main_data_rec.buy_season, main_data_rec.facility, main_data_rec.etd_port, main_data_rec.total_price, main_data_rec.item_type, -- added as part of CCR0007335
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         -- Start of Change 2.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         main_data_rec.product_category, main_data_rec.po_type, main_data_rec.country, main_data_rec.region, -- End of Change 2.0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             -- Start of Change 2.2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             main_data_rec.global_surcharge, main_data_rec.ship_to_id_surcharge, main_data_rec.blended_fob, -- End of Change
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            main_data_rec.gtn_transfer_flag
                         ,                                              -- 2.5
                           main_data_rec.so_number                       --2.5
                                                  );
        END LOOP;

        l_count        := 0;                                     -- CCR0006426

        /*Start Changes  by BT Technology Team v1.2 on 02-APR-2015 */

        -- Start of Change 2.2
        /*INSERT INTO xxdo_po_listing_headers (attribute12)
             VALUES ('Total:');*/
        -- End of Change 2.2
        IF p_sizes = 'Y'
        THEN
            -- Start of Change 2.2
            INSERT INTO xxdo_po_listing_headers (attribute12)
                 VALUES ('Total:');

            -- End of Change

            FOR report_data_rec IN report_data_cur
            LOOP
                -- ln_count_num := 21; -- Commented as part of CCR0007335
                -- ln_count_num := 22;                    -- commented as part of change 2.0
                --ln_count_num := 26;                     -- added as part of change 2.0
                ln_count_num   := 29;               -- added as per change 2.2

                FOR item_sizes_rec IN item_sizes_cur   -- Commented CCR0006426
                --commented below cursor call for CCR0006536
                /*FOR item_sizes_rec IN po_item_sizes(report_data_rec.attribute3,
                                              report_data_rec.attribute5,
                   report_data_rec.attribute7)*/
                LOOP
                    ln_count_num     := ln_count_num + 1;
                    lv_column_name   := 'attribute' || ln_count_num;
                    ln_po_qty        := 0;

                    BEGIN
                        SELECT SUM (po_qty)
                          INTO ln_po_qty
                          FROM xxdo_main_data
                         WHERE     po_number = report_data_rec.attribute3
                               AND style = report_data_rec.attribute5
                               AND color = report_data_rec.attribute7
                               AND item_size = item_sizes_rec.item_size
                               AND NVL (ex_factory_date, '1-JAN-2013') =
                                   NVL (report_data_rec.attribute8,
                                        '1-JAN-2013')
                               AND NVL (conf_ex_factory_date, '1-JAN-2013') =
                                   NVL (report_data_rec.attribute9,
                                        '1-JAN-2013')
                               AND NVL (promised_date, '1-JAN-2013') =
                                   NVL (report_data_rec.attribute10,
                                        '1-JAN-2013')
                               AND ship_to_location_id =
                                   report_data_rec.attribute4
                               -- Start changes for CCR0007335
                               -- AND unit_price = report_data_rec.attribute16;
                               AND TO_CHAR (
                                       unit_price,
                                       'FM999990D0000000000000000000000000000000000000') =
                                   TO_CHAR (
                                       report_data_rec.attribute16,
                                       'FM999990D0000000000000000000000000000000000000');
                    -- End changes for CCR0007335

                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_query   :=
                                   'update xxdo_po_listing_headers
                            set '
                                || lv_column_name
                                || '='
                                || 0
                                || '
                           where attribute1<>''Vendor Name'' and
                          attribute3='
                                || ''''
                                || report_data_rec.attribute3
                                || ''''
                                || ' and attribute5='
                                || ''''
                                || report_data_rec.attribute5
                                || ''''
                                || ' and attribute7='
                                || ''''
                                || report_data_rec.attribute7
                                || ''''
                                || ' and attribute8='
                                || ''''
                                || report_data_rec.attribute8
                                || ''''
                                || ' and attribute9='
                                || ''''
                                || report_data_rec.attribute9
                                || ''''
                                || ' and attribute10='
                                || ''''
                                || report_data_rec.attribute10
                                || '''';

                            EXECUTE IMMEDIATE lv_query;
                    END;

                    IF ln_po_qty > 0
                    THEN
                        lv_query   :=
                               'update xxdo_po_listing_headers
                        set '
                            || lv_column_name
                            || '='
                            || ln_po_qty
                            || '
                        where attribute1<>''Vendor Name'' and
                        rowid='
                            || ''''
                            || report_data_rec.ROWID
                            || '''';

                        EXECUTE IMMEDIATE lv_query;
                    END IF;
                END LOOP;
            END LOOP;

            -- Commented and placed same outside the IF statement
            /*INSERT INTO xxdo_po_listing_headers (attribute12)
                 VALUES ('Total:');*/
            -- End of Change

            -- ln_count_num := 21; -- Commented as part of CCR0007335
            -- ln_count_num := 22;                       -- commented as part of CCR0007335
            --ln_count_num := 26;                          -- added as part of Change 2.0

            ln_count_num   := 29;                   -- Added as per change 2.2

            FOR item_sizes_rec IN item_sizes_cur
            LOOP
                ln_count_num     := ln_count_num + 1;
                lv_column_name   := 'attribute' || ln_count_num;
                lv_query         :=
                       'update xxdo_po_listing_headers
                 set '
                    || lv_column_name
                    || '='
                    || '(select sum('
                    || lv_column_name
                    || ') from xxdo_po_listing_headers where attribute1<>'
                    || ''''
                    || 'Vendor Name'
                    || ''''
                    || ')'
                    || ' where attribute12='
                    || ''''
                    || 'Total:'
                    || '''';

                EXECUTE IMMEDIATE lv_query;
            END LOOP;

            FOR total_rec IN total_cur
            LOOP
                ln_tot_qty   := 0;
                ln_tot_qty   :=
                      --  NVL (total_rec.attribute22, 0) -- Commented as part of CCR0007335
                      -- Start of Change 2.0
                      --   NVL (total_rec.attribute23, 0)
                      --   NVL (total_rec.attribute24, 0)
                      --   NVL (total_rec.attribute25, 0)
                      --    NVL (total_rec.attribute26, 0)
                      -- End of Change
                      -- Start of Change 2.2
                      --  NVL (total_rec.attribute27, 0)
                      -- + NVL (total_rec.attribute28, 0)
                      -- + NVL (total_rec.attribute29, 0)
                      -- End of Change 2.2
                      NVL (total_rec.attribute30, 0)
                    + NVL (total_rec.attribute31, 0)
                    + NVL (total_rec.attribute32, 0)
                    + NVL (total_rec.attribute33, 0)
                    + NVL (total_rec.attribute34, 0)
                    + NVL (total_rec.attribute35, 0)
                    + NVL (total_rec.attribute36, 0)
                    + NVL (total_rec.attribute37, 0)
                    + NVL (total_rec.attribute38, 0)
                    + NVL (total_rec.attribute39, 0)
                    + NVL (total_rec.attribute40, 0)
                    + NVL (total_rec.attribute41, 0)
                    + NVL (total_rec.attribute42, 0)
                    + NVL (total_rec.attribute43, 0)
                    + NVL (total_rec.attribute44, 0)
                    + NVL (total_rec.attribute45, 0)
                    + NVL (total_rec.attribute46, 0)
                    + NVL (total_rec.attribute47, 0)
                    + NVL (total_rec.attribute48, 0)
                    + NVL (total_rec.attribute49, 0)
                    + NVL (total_rec.attribute50, 0)
                    + NVL (total_rec.attribute51, 0)
                    + NVL (total_rec.attribute52, 0)
                    + NVL (total_rec.attribute53, 0)
                    + NVL (total_rec.attribute54, 0)
                    + NVL (total_rec.attribute55, 0)
                    + NVL (total_rec.attribute56, 0)
                    + NVL (total_rec.attribute57, 0)
                    + NVL (total_rec.attribute58, 0)
                    + NVL (total_rec.attribute59, 0)
                    + NVL (total_rec.attribute60, 0)
                    + NVL (total_rec.attribute61, 0)
                    + NVL (total_rec.attribute62, 0)
                    + NVL (total_rec.attribute63, 0)
                    + NVL (total_rec.attribute64, 0)
                    + NVL (total_rec.attribute65, 0)
                    + NVL (total_rec.attribute66, 0)
                    + NVL (total_rec.attribute67, 0)
                    + NVL (total_rec.attribute68, 0)
                    + NVL (total_rec.attribute69, 0)
                    + NVL (total_rec.attribute70, 0)
                    + NVL (total_rec.attribute71, 0)
                    + NVL (total_rec.attribute72, 0)
                    + NVL (total_rec.attribute73, 0)
                    + NVL (total_rec.attribute74, 0)
                    + NVL (total_rec.attribute75, 0)
                    + NVL (total_rec.attribute76, 0)
                    + NVL (total_rec.attribute77, 0)
                    + NVL (total_rec.attribute78, 0)
                    + NVL (total_rec.attribute79, 0)
                    + NVL (total_rec.attribute80, 0)
                    + NVL (total_rec.attribute81, 0)
                    + NVL (total_rec.attribute82, 0)
                    + NVL (total_rec.attribute83, 0)
                    + NVL (total_rec.attribute84, 0)
                    + NVL (total_rec.attribute85, 0)
                    + NVL (total_rec.attribute86, 0)
                    + NVL (total_rec.attribute87, 0)
                    + NVL (total_rec.attribute88, 0)
                    + NVL (total_rec.attribute89, 0)
                    + NVL (total_rec.attribute90, 0)
                    + NVL (total_rec.attribute91, 0)
                    + NVL (total_rec.attribute92, 0)
                    + NVL (total_rec.attribute93, 0)
                    + NVL (total_rec.attribute94, 0)
                    + NVL (total_rec.attribute95, 0)
                    + NVL (total_rec.attribute96, 0)
                    + NVL (total_rec.attribute97, 0)
                    + NVL (total_rec.attribute98, 0)
                    + NVL (total_rec.attribute99, 0)
                    + NVL (total_rec.attribute100, 0)
                    + NVL (total_rec.attribute101, 0)
                    + NVL (total_rec.attribute102, 0)
                    + NVL (total_rec.attribute103, 0)
                    + NVL (total_rec.attribute104, 0)
                    + NVL (total_rec.attribute105, 0)
                    + NVL (total_rec.attribute106, 0)
                    + NVL (total_rec.attribute107, 0)
                    + NVL (total_rec.attribute108, 0)
                    + NVL (total_rec.attribute109, 0)
                    + NVL (total_rec.attribute110, 0)
                    + NVL (total_rec.attribute111, 0)
                    + NVL (total_rec.attribute112, 0)
                    + NVL (total_rec.attribute113, 0)
                    + NVL (total_rec.attribute114, 0)
                    + NVL (total_rec.attribute115, 0)
                    + NVL (total_rec.attribute116, 0)
                    + NVL (total_rec.attribute117, 0)
                    + NVL (total_rec.attribute118, 0)
                    + NVL (total_rec.attribute119, 0)
                    + NVL (total_rec.attribute120, 0)
                    -- START PRB0041345
                    + NVL (total_rec.attribute121, 0)
                    + NVL (total_rec.attribute122, 0)
                    + NVL (total_rec.attribute123, 0)
                    + NVL (total_rec.attribute124, 0)
                    + NVL (total_rec.attribute125, 0)
                    + NVL (total_rec.attribute126, 0)
                    + NVL (total_rec.attribute127, 0)
                    + NVL (total_rec.attribute128, 0)
                    + NVL (total_rec.attribute129, 0)
                    + NVL (total_rec.attribute130, 0)
                    + NVL (total_rec.attribute131, 0)
                    + NVL (total_rec.attribute132, 0)
                    + NVL (total_rec.attribute133, 0)
                    + NVL (total_rec.attribute134, 0)
                    + NVL (total_rec.attribute135, 0)
                    + NVL (total_rec.attribute136, 0)
                    + NVL (total_rec.attribute137, 0)
                    + NVL (total_rec.attribute138, 0)
                    + NVL (total_rec.attribute139, 0)
                    + NVL (total_rec.attribute140, 0)
                    + NVL (total_rec.attribute141, 0)
                    + NVL (total_rec.attribute142, 0)
                    + NVL (total_rec.attribute143, 0)
                    + NVL (total_rec.attribute144, 0)
                    + NVL (total_rec.attribute145, 0)
                    + NVL (total_rec.attribute146, 0)
                    + NVL (total_rec.attribute147, 0)
                    + NVL (total_rec.attribute148, 0)
                    + NVL (total_rec.attribute149, 0)
                    + NVL (total_rec.attribute150, 0)
                    + NVL (total_rec.attribute151, 0)
                    + NVL (total_rec.attribute152, 0)
                    + NVL (total_rec.attribute153, 0)
                    + NVL (total_rec.attribute154, 0)
                    + NVL (total_rec.attribute155, 0)
                    + NVL (total_rec.attribute156, 0)
                    + NVL (total_rec.attribute157, 0)
                    + NVL (total_rec.attribute158, 0)
                    + NVL (total_rec.attribute159, 0)
                    + NVL (total_rec.attribute160, 0)
                    + NVL (total_rec.attribute161, 0)
                    + NVL (total_rec.attribute162, 0)
                    + NVL (total_rec.attribute163, 0)
                    + NVL (total_rec.attribute164, 0)
                    + NVL (total_rec.attribute165, 0)
                    + NVL (total_rec.attribute166, 0)
                    + NVL (total_rec.attribute167, 0)
                    + NVL (total_rec.attribute168, 0)
                    + NVL (total_rec.attribute169, 0)
                    + NVL (total_rec.attribute170, 0)
                    + NVL (total_rec.attribute171, 0)
                    + NVL (total_rec.attribute172, 0)
                    + NVL (total_rec.attribute173, 0)
                    + NVL (total_rec.attribute174, 0)
                    + NVL (total_rec.attribute175, 0)
                    + NVL (total_rec.attribute176, 0)
                    + NVL (total_rec.attribute177, 0)
                    + NVL (total_rec.attribute178, 0)
                    + NVL (total_rec.attribute179, 0)
                    + NVL (total_rec.attribute180, 0)
                    + NVL (total_rec.attribute181, 0)
                    + NVL (total_rec.attribute182, 0)
                    + NVL (total_rec.attribute183, 0)
                    + NVL (total_rec.attribute184, 0)
                    + NVL (total_rec.attribute185, 0)
                    + NVL (total_rec.attribute186, 0)
                    + NVL (total_rec.attribute187, 0)
                    + NVL (total_rec.attribute188, 0)
                    + NVL (total_rec.attribute189, 0)
                    + NVL (total_rec.attribute190, 0)
                    + NVL (total_rec.attribute191, 0)
                    + NVL (total_rec.attribute192, 0)
                    + NVL (total_rec.attribute193, 0)
                    + NVL (total_rec.attribute194, 0)
                    + NVL (total_rec.attribute195, 0)
                    + NVL (total_rec.attribute196, 0)
                    + NVL (total_rec.attribute197, 0)
                    + NVL (total_rec.attribute198, 0)
                    + NVL (total_rec.attribute199, 0)
                    + NVL (total_rec.attribute200, 0)
                    + NVL (total_rec.attribute201, 0)
                    + NVL (total_rec.attribute202, 0)
                    + NVL (total_rec.attribute203, 0)
                    + NVL (total_rec.attribute204, 0)
                    + NVL (total_rec.attribute205, 0)
                    + NVL (total_rec.attribute206, 0)
                    + NVL (total_rec.attribute207, 0)
                    + NVL (total_rec.attribute208, 0)
                    + NVL (total_rec.attribute209, 0)
                    + NVL (total_rec.attribute210, 0)
                    + NVL (total_rec.attribute211, 0)
                    + NVL (total_rec.attribute212, 0)
                    + NVL (total_rec.attribute213, 0)
                    + NVL (total_rec.attribute214, 0)
                    + NVL (total_rec.attribute215, 0)
                    + NVL (total_rec.attribute216, 0)
                    + NVL (total_rec.attribute217, 0)
                    + NVL (total_rec.attribute218, 0)
                    + NVL (total_rec.attribute219, 0)
                    + NVL (total_rec.attribute220, 0)
                    + NVL (total_rec.attribute221, 0)
                    + NVL (total_rec.attribute222, 0)
                    + NVL (total_rec.attribute201, 0)
                    + NVL (total_rec.attribute223, 0)
                    + NVL (total_rec.attribute224, 0)
                    + NVL (total_rec.attribute225, 0)
                    + NVL (total_rec.attribute226, 0)
                    + NVL (total_rec.attribute227, 0)
                    + NVL (total_rec.attribute228, 0)
                    + NVL (total_rec.attribute229, 0)
                    + NVL (total_rec.attribute230, 0)
                    + NVL (total_rec.attribute231, 0)
                    + NVL (total_rec.attribute232, 0)
                    + NVL (total_rec.attribute233, 0)
                    + NVL (total_rec.attribute234, 0)
                    + NVL (total_rec.attribute235, 0)
                    + NVL (total_rec.attribute236, 0)
                    + NVL (total_rec.attribute237, 0)
                    + NVL (total_rec.attribute238, 0)
                    + NVL (total_rec.attribute239, 0)
                    + NVL (total_rec.attribute240, 0)
                    + NVL (total_rec.attribute241, 0)
                    + NVL (total_rec.attribute242, 0)
                    + NVL (total_rec.attribute243, 0)
                    + NVL (total_rec.attribute244, 0)
                    + NVL (total_rec.attribute245, 0)
                    + NVL (total_rec.attribute246, 0)
                    + NVL (total_rec.attribute247, 0)
                    + NVL (total_rec.attribute248, 0)
                    + NVL (total_rec.attribute249, 0)
                    + NVL (total_rec.attribute250, 0);
            -- END PRB0041345;

            END LOOP;
        END IF;

        IF p_sizes = 'Y'
        THEN
            UPDATE xxdo_po_listing_headers
               SET attribute13   = ln_tot_qty
             WHERE attribute12 = 'Total:';
        -- Start of Change 2.2
        /*
        ELSE
        UPDATE xxdo_po_listing_headers
           SET attribute13 = ln_qty
         WHERE attribute12 = 'Total:';
         */
        -- End of Change 2.2

        END IF;

        audit_report (p_sort_by);
    -- Start changes for CCR0007335
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in MAIN_DATA = ' || SQLERRM);
    -- End changes for CCR0007335
    END main_data;

    PROCEDURE audit_report (p_sort_by IN VARCHAR2)
    IS
        CURSOR headers_cur IS
            SELECT *
              FROM xxdo_po_listing_headers
             WHERE attribute1 = 'Vendor Name';

        CURSOR lines_cur IS
              SELECT *
                FROM xxdo_po_listing_headers
               WHERE attribute1 <> 'Vendor Name'
            ORDER BY attribute1, attribute3, attribute5;

        CURSOR lines_vendor_cur IS
              SELECT *
                FROM xxdo_po_listing_headers
               WHERE attribute1 <> 'Vendor Name'
            ORDER BY attribute1;

        CURSOR lines_style_cur IS
              SELECT *
                FROM xxdo_po_listing_headers
               WHERE attribute1 <> 'Vendor Name'
            ORDER BY attribute5;

        CURSOR lines_po_number_cur IS
              SELECT *
                FROM xxdo_po_listing_headers
               WHERE attribute1 <> 'Vendor Name'
            ORDER BY attribute3;

        CURSOR lines_po_date_cur IS
              SELECT *
                FROM xxdo_po_listing_headers
               WHERE attribute1 <> 'Vendor Name'
            ORDER BY attribute2;

        CURSOR tot_cur IS
              SELECT *
                FROM xxdo_po_listing_headers
               WHERE attribute12 = 'Total:'
            ORDER BY attribute3;
    BEGIN
        FOR headers_rec IN headers_cur
        LOOP
            -- Commented RPAD EXTRA_SPACES
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   --RPAD (headers_rec.attribute1, 40, ' ')
                   headers_rec.attribute1
                || CHR (9)
                --|| RPAD (headers_rec.attribute2, 15, ' ')
                || headers_rec.attribute2
                || CHR (9)
                --|| RPAD (headers_rec.attribute3, 15, ' ')
                || headers_rec.attribute3
                || CHR (9)
                --|| RPAD (headers_rec.attribute4, 15, ' ')
                || headers_rec.attribute24            -- As part of Change 2.2
                || CHR (9)
                || headers_rec.attribute252                             -- 2.5
                || CHR (9)
                || headers_rec.attribute4
                || CHR (9)
                --|| RPAD (headers_rec.attribute5, 15, ' ')
                || headers_rec.attribute5
                || CHR (9)
                --|| RPAD (headers_rec.attribute6, 30, ' ')
                || headers_rec.attribute6
                || CHR (9)
                --|| RPAD (headers_rec.attribute7, 10, ' ')
                || headers_rec.attribute7
                || CHR (9)
                -- Start changes for CCR0007335
                || headers_rec.attribute22
                || CHR (9)
                -- End changes for CCR0007335
                --|| RPAD (headers_rec.attribute8, 15, ' ')
                || headers_rec.attribute23            -- As part of Change 2.2
                || CHR (9)
                || headers_rec.attribute8
                || CHR (9)
                --|| RPAD (headers_rec.attribute9, 15, ' ')
                || headers_rec.attribute9
                || CHR (9)
                --|| RPAD (headers_rec.attribute10, 15, ' ')
                || headers_rec.attribute10
                || CHR (9)
                --|| RPAD (headers_rec.attribute11, 40, ' ')
                -- 2.5
                || headers_rec.attribute251
                || CHR (9)
                -- 2.5
                || headers_rec.attribute11
                || CHR (9)
                --|| RPAD (headers_rec.attribute12, 10, ' ')

                -- Start of Change 2.2
                || headers_rec.attribute25
                || CHR (9)
                || headers_rec.attribute26
                || CHR (9)
                -- End of Change
                || headers_rec.attribute12
                || CHR (9)
                --|| RPAD (headers_rec.attribute13, 10, ' ')
                || headers_rec.attribute13
                || CHR (9)
                --|| RPAD (headers_rec.attribute14, 10, ' ')
                || headers_rec.attribute14
                || CHR (9)
                --|| RPAD (headers_rec.attribute15, 10, ' ')
                || headers_rec.attribute15
                || CHR (9)
                --|| RPAD (headers_rec.attribute16, 15, ' ')
                || headers_rec.attribute16
                || CHR (9)
                -- Start of Change 2.2
                || headers_rec.attribute27
                || CHR (9)
                || headers_rec.attribute28
                || CHR (9)
                || headers_rec.attribute29
                || CHR (9)
                || headers_rec.attribute21
                || CHR (9)
                -- End of Change
                --|| RPAD (headers_rec.attribute17, 15, ' ')
                || headers_rec.attribute17
                || CHR (9)
                --|| RPAD (headers_rec.attribute18, 15, ' ')
                || headers_rec.attribute18
                || CHR (9)
                --|| RPAD (headers_rec.attribute19, 15, ' ')
                || headers_rec.attribute19
                || CHR (9)
                --|| RPAD (headers_rec.attribute20, 10, ' ')
                -- Start of Change 2.2
                /*
                || headers_rec.attribute20
                || CHR (9)
                --|| RPAD (headers_rec.attribute21, 15, ' ')
                || headers_rec.attribute21 -- Commented as per Change 2.2
                || CHR (9)
                || RPAD (headers_rec.attribute22, 12, ' ')
                -- Start changes for CCR0007335
                --|| CHR (29)
                --|| headers_rec.attribute22    -- Start Changes done for CCR0007113
                --|| CHR (9)
                -- End changes for CCR0007335
                --|| RPAD (headers_rec.attribute23, 12, ' ')
    --            || CHR (29)
                || headers_rec.attribute23   -- Commented as per Change 2.2
                || CHR (9)
                --|| RPAD (headers_rec.attribute24, 12, ' ')
    --            || CHR (29)
                || headers_rec.attribute24        -- Commented as per Change 2.2
                || CHR (9)
                --|| RPAD (headers_rec.attribute25, 12, ' ')
                 || CHR (29)
                || headers_rec.attribute25
                || CHR (9)
                --|| RPAD (headers_rec.attribute26, 12, ' ')
                || CHR (29)
                || headers_rec.attribute26
                || CHR (9)
                || RPAD (headers_rec.attribute27, 12, ' ')
                || CHR (29)
                || headers_rec.attribute27
                || CHR (9)
                || RPAD (headers_rec.attribute28, 12, ' ')
                || CHR (29)
                || headers_rec.attribute28
                || CHR (9)
                || RPAD (headers_rec.attribute29, 12, ' ')
                || CHR (29)
                || headers_rec.attribute29
                || CHR (9)*/
                --end of Change
                --|| RPAD (headers_rec.attribute30, 12, ' ')
                --|| CHR (29)
                || headers_rec.attribute30
                || CHR (9)
                --|| RPAD (headers_rec.attribute31, 12, ' ')
                || CHR (29)
                || headers_rec.attribute31
                || CHR (9)
                --|| RPAD (headers_rec.attribute32, 12, ' ')
                || CHR (29)
                || headers_rec.attribute32
                || CHR (9)
                --|| RPAD (headers_rec.attribute33, 12, ' ')
                || CHR (29)
                || headers_rec.attribute33
                || CHR (9)
                --|| RPAD (headers_rec.attribute34, 12, ' ')
                || CHR (29)
                || headers_rec.attribute34
                || CHR (9)
                --|| RPAD (headers_rec.attribute35, 12, ' ')
                || CHR (29)
                || headers_rec.attribute35
                || CHR (9)
                --|| RPAD (headers_rec.attribute36, 12, ' ')
                || CHR (29)
                || headers_rec.attribute36
                || CHR (9)
                --|| RPAD (headers_rec.attribute37, 12, ' ')
                || CHR (29)
                || headers_rec.attribute37
                || CHR (9)
                --|| RPAD (headers_rec.attribute38, 12, ' ')
                || CHR (29)
                || headers_rec.attribute38
                || CHR (9)
                --|| RPAD (headers_rec.attribute39, 12, ' ')
                || CHR (29)
                || headers_rec.attribute39
                || CHR (9)
                --|| RPAD (headers_rec.attribute40, 12, ' ')
                || CHR (29)
                || headers_rec.attribute40
                || CHR (9)
                --|| RPAD (headers_rec.attribute41, 12, ' ')
                || CHR (29)
                || headers_rec.attribute41
                || CHR (9)
                --|| RPAD (headers_rec.attribute42, 12, ' ')
                || CHR (29)
                || headers_rec.attribute42
                || CHR (9)
                --|| RPAD (headers_rec.attribute43, 12, ' ')
                || CHR (29)
                || headers_rec.attribute43
                || CHR (9)
                --|| RPAD (headers_rec.attribute44, 12, ' ')
                || CHR (29)
                || headers_rec.attribute44
                || CHR (9)
                --|| RPAD (headers_rec.attribute45, 12, ' ')
                || CHR (29)
                || headers_rec.attribute45
                || CHR (9)
                --|| RPAD (headers_rec.attribute46, 12, ' ')
                || CHR (29)
                || headers_rec.attribute46
                || CHR (9)
                --|| RPAD (headers_rec.attribute47, 12, ' ')
                || CHR (29)
                || headers_rec.attribute47
                || CHR (9)
                --|| RPAD (headers_rec.attribute48, 12, ' ')
                || CHR (29)
                || headers_rec.attribute48
                || CHR (9)
                --|| RPAD (headers_rec.attribute49, 12, ' ')
                || CHR (29)
                || headers_rec.attribute49
                || CHR (9)
                --|| RPAD (headers_rec.attribute50, 12, ' ')
                || CHR (29)
                || headers_rec.attribute50
                || CHR (9)
                --|| RPAD (headers_rec.attribute51, 12, ' ')
                || CHR (29)
                || headers_rec.attribute51
                || CHR (9)
                --|| RPAD (headers_rec.attribute52, 12, ' ')
                || CHR (29)
                || headers_rec.attribute52
                || CHR (9)
                --|| RPAD (headers_rec.attribute53, 12, ' ')
                || CHR (29)
                || headers_rec.attribute53
                || CHR (9)
                --|| RPAD (headers_rec.attribute54, 12, ' ')
                || CHR (29)
                || headers_rec.attribute54
                || CHR (9)
                --|| RPAD (headers_rec.attribute55, 12, ' ')
                || CHR (29)
                || headers_rec.attribute55
                || CHR (9)
                --|| RPAD (headers_rec.attribute56, 12, ' ')
                || CHR (29)
                || headers_rec.attribute56
                || CHR (9)
                --|| RPAD (headers_rec.attribute57, 12, ' ')
                || CHR (29)
                || headers_rec.attribute57
                || CHR (9)
                --|| RPAD (headers_rec.attribute58, 12, ' ')
                || CHR (29)
                || headers_rec.attribute58
                || CHR (9)
                --|| RPAD (headers_rec.attribute59, 12, ' ')
                || CHR (29)
                || headers_rec.attribute59
                || CHR (9)
                --|| RPAD (headers_rec.attribute60, 12, ' ')
                || CHR (29)
                || headers_rec.attribute60
                || CHR (9)
                --|| RPAD (headers_rec.attribute61, 12, ' ')
                || CHR (29)
                || headers_rec.attribute61
                || CHR (9)
                --|| RPAD (headers_rec.attribute62, 12, ' ')
                || CHR (29)
                || headers_rec.attribute62
                || CHR (9)
                --|| RPAD (headers_rec.attribute63, 12, ' ')
                || CHR (29)
                || headers_rec.attribute63
                || CHR (9)
                --|| RPAD (headers_rec.attribute64, 12, ' ')
                || CHR (29)
                || headers_rec.attribute64
                || CHR (9)
                --|| RPAD (headers_rec.attribute65, 12, ' ')
                || CHR (29)
                || headers_rec.attribute65
                || CHR (9)
                --|| RPAD (headers_rec.attribute66, 12, ' ')
                || CHR (29)
                || headers_rec.attribute66
                || CHR (9)
                --|| RPAD (headers_rec.attribute67, 12, ' ')
                || CHR (29)
                || headers_rec.attribute67
                || CHR (9)
                --|| RPAD (headers_rec.attribute68, 12, ' ')
                || CHR (29)
                || headers_rec.attribute68
                || CHR (9)
                --|| RPAD (headers_rec.attribute69, 12, ' ')
                || CHR (29)
                || headers_rec.attribute69
                || CHR (9)
                --|| RPAD (headers_rec.attribute70, 12, ' ')
                || CHR (29)
                || headers_rec.attribute70
                || CHR (9)
                --|| RPAD (headers_rec.attribute71, 12, ' ')
                || CHR (29)
                || headers_rec.attribute71
                || CHR (9)
                --|| RPAD (headers_rec.attribute72, 12, ' ')
                || CHR (29)
                || headers_rec.attribute72
                || CHR (9)
                --|| RPAD (headers_rec.attribute73, 12, ' ')
                || CHR (29)
                || headers_rec.attribute73
                || CHR (9)
                --|| RPAD (headers_rec.attribute74, 12, ' ')
                || CHR (29)
                || headers_rec.attribute74
                || CHR (9)
                --|| RPAD (headers_rec.attribute75, 12, ' ')
                || CHR (29)
                || headers_rec.attribute75
                || CHR (9)
                --|| RPAD (headers_rec.attribute76, 12, ' ')
                || CHR (29)
                || headers_rec.attribute76
                || CHR (9)
                --|| RPAD (headers_rec.attribute77, 12, ' ')
                || CHR (29)
                || headers_rec.attribute77
                || CHR (9)
                --|| RPAD (headers_rec.attribute78, 12, ' ')
                || CHR (29)
                || headers_rec.attribute78
                || CHR (9)
                --|| RPAD (headers_rec.attribute79, 12, ' ')
                || CHR (29)
                || headers_rec.attribute79
                || CHR (9)
                --|| RPAD (headers_rec.attribute80, 12, ' ')
                || CHR (29)
                || headers_rec.attribute80
                || CHR (9)
                --|| RPAD (headers_rec.attribute81, 12, ' ')
                || CHR (29)
                || headers_rec.attribute81
                || CHR (9)
                --|| RPAD (headers_rec.attribute82, 12, ' ')
                || CHR (29)
                || headers_rec.attribute82
                || CHR (9)
                --|| RPAD (headers_rec.attribute83, 12, ' ')
                || CHR (29)
                || headers_rec.attribute83
                || CHR (9)
                --|| RPAD (headers_rec.attribute84, 12, ' ')
                || CHR (29)
                || headers_rec.attribute84
                || CHR (9)
                --|| RPAD (headers_rec.attribute85, 12, ' ')
                || CHR (29)
                || headers_rec.attribute85
                || CHR (9)
                --|| RPAD (headers_rec.attribute86, 12, ' ')
                || CHR (29)
                || headers_rec.attribute86
                || CHR (9)
                --|| RPAD (headers_rec.attribute87, 12, ' ')
                || CHR (29)
                || headers_rec.attribute87
                || CHR (9)
                --|| RPAD (headers_rec.attribute88, 12, ' ')
                || CHR (29)
                || headers_rec.attribute88
                || CHR (9)
                --|| RPAD (headers_rec.attribute89, 12, ' ')
                || CHR (29)
                || headers_rec.attribute89
                || CHR (9)
                --|| RPAD (headers_rec.attribute90, 12, ' ')
                || CHR (29)
                || headers_rec.attribute90
                || CHR (9)
                --|| RPAD (headers_rec.attribute91, 12, ' ')
                || CHR (29)
                || headers_rec.attribute91
                || CHR (9)
                --|| RPAD (headers_rec.attribute92, 12, ' ')
                || CHR (29)
                || headers_rec.attribute92
                || CHR (9)
                --|| RPAD (headers_rec.attribute93, 12, ' ')
                || CHR (29)
                || headers_rec.attribute93
                || CHR (9)
                --|| RPAD (headers_rec.attribute94, 12, ' ')
                || CHR (29)
                || headers_rec.attribute94
                || CHR (9)
                --|| RPAD (headers_rec.attribute95, 12, ' ')
                || CHR (29)
                || headers_rec.attribute95
                || CHR (9)
                --|| RPAD (headers_rec.attribute96, 12, ' ')
                || CHR (29)
                || headers_rec.attribute96
                || CHR (9)
                --|| RPAD (headers_rec.attribute97, 12, ' ')
                || CHR (29)
                || headers_rec.attribute97
                || CHR (9)
                --|| RPAD (headers_rec.attribute98, 12, ' ')
                || CHR (29)
                || headers_rec.attribute98
                || CHR (9)
                --|| RPAD (headers_rec.attribute99, 12, ' ')
                || CHR (29)
                || headers_rec.attribute99
                || CHR (9)
                --|| RPAD (headers_rec.attribute100, 12, ' ')
                || CHR (29)
                || headers_rec.attribute100
                || CHR (9)
                --|| RPAD (headers_rec.attribute101, 12, ' ')
                || CHR (29)
                || headers_rec.attribute101
                || CHR (9)
                --|| RPAD (headers_rec.attribute102, 12, ' ')
                || CHR (29)
                || headers_rec.attribute102
                || CHR (9)
                --|| RPAD (headers_rec.attribute103, 12, ' ')
                || CHR (29)
                || headers_rec.attribute103
                || CHR (9)
                --|| RPAD (headers_rec.attribute104, 12, ' ')
                || CHR (29)
                || headers_rec.attribute104
                || CHR (9)
                --|| RPAD (headers_rec.attribute105, 12, ' ')
                || CHR (29)
                || headers_rec.attribute105
                || CHR (9)
                --|| RPAD (headers_rec.attribute106, 12, ' ')
                || CHR (29)
                || headers_rec.attribute106
                || CHR (9)
                --|| RPAD (headers_rec.attribute107, 12, ' ')
                || CHR (29)
                || headers_rec.attribute107
                || CHR (9)
                --|| RPAD (headers_rec.attribute108, 12, ' ')
                || CHR (29)
                || headers_rec.attribute108
                || CHR (9)
                --|| RPAD (headers_rec.attribute109, 12, ' ')
                || CHR (29)
                || headers_rec.attribute109
                || CHR (9)
                --|| RPAD (headers_rec.attribute110, 12, ' ')
                || CHR (29)
                || headers_rec.attribute110
                || CHR (9)
                --|| RPAD (headers_rec.attribute111, 12, ' ')
                || CHR (29)
                || headers_rec.attribute111
                || CHR (9)
                --|| RPAD (headers_rec.attribute112, 12, ' ')
                || CHR (29)
                || headers_rec.attribute112
                || CHR (9)
                --|| RPAD (headers_rec.attribute113, 12, ' ')
                || CHR (29)
                || headers_rec.attribute113
                || CHR (9)
                --|| RPAD (headers_rec.attribute114, 12, ' ')
                || CHR (29)
                || headers_rec.attribute114
                || CHR (9)
                --|| RPAD (headers_rec.attribute115, 12, ' ')
                || CHR (29)
                || headers_rec.attribute115
                || CHR (9)
                --|| RPAD (headers_rec.attribute116, 12, ' ')
                || CHR (29)
                || headers_rec.attribute116
                || CHR (9)
                ----|| RPAD (headers_rec.attribute117, 12, ' ')
                || CHR (29)
                || headers_rec.attribute117
                || CHR (9)
                --|| RPAD (headers_rec.attribute118, 12, ' ')
                || CHR (29)
                || headers_rec.attribute118
                || CHR (9)
                --|| RPAD (headers_rec.attribute119, 12, ' ')
                || CHR (29)
                || headers_rec.attribute119
                || CHR (9)
                --|| RPAD (headers_rec.attribute120, 12, ' '));
                || CHR (29)
                || headers_rec.attribute120
                -- START PRB0041345
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute121
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute122
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute123
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute124
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute125
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute126
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute127
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute128
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute129
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute130
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute131
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute132
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute133
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute134
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute135
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute136
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute137
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute138
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute139
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute140
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute141
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute142
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute143
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute144
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute145
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute146
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute147
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute148
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute149
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute150
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute151
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute152
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute153
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute154
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute155
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute156
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute157
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute158
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute159
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute160
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute161
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute162
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute163
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute164
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute165
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute166
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute167
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute168
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute169
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute170
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute171
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute172
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute173
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute174
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute175
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute176
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute177
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute178
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute179
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute180
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute181
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute182
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute183
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute184
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute185
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute186
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute187
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute188
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute189
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute190
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute191
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute192
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute193
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute194
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute195
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute196
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute197
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute198
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute199
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute200
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute201
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute202
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute203
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute204
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute205
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute206
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute207
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute208
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute209
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute210
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute211
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute212
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute213
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute214
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute215
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute216
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute217
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute218
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute219
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute220
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute221
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute222
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute223
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute224
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute225
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute226
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute227
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute228
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute229
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute230
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute231
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute232
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute233
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute234
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute235
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute236
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute237
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute238
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute239
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute240
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute241
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute242
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute243
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute244
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute245
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute246
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute247
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute248
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute249
                || CHR (9)
                || CHR (29)
                || headers_rec.attribute250 -- End Changes done for CCR0007113
                                           -- END PRB0041345
                                           );
        END LOOP;

        IF p_sort_by = 'VENDOR_NAME'
        THEN
            FOR lines_rec IN lines_vendor_cur
            LOOP
                -- Commented RPAD EXTRA_SPACES
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       --RPAD (NVL (lines_rec.attribute1, ' '), 40, ' ')
                       lines_rec.attribute1
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute2, ' '), 15, ' ')
                    || lines_rec.attribute2
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute3, ' '), 15, ' ')
                    || lines_rec.attribute3
                    || CHR (9)
                    || lines_rec.attribute24        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    --|| RPAD (NVL (lines_rec.attribute4, ' '), 15, ' ')
                    || lines_rec.attribute252                           -- 2.5
                    || CHR (9)
                    || lines_rec.attribute4
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute5, ' '), 15, ' ')
                    || lines_rec.attribute5
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute6, ' '), 30, ' ')
                    || lines_rec.attribute6
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute7, ' '), 10, ' ')
                    || lines_rec.attribute7
                    || CHR (9)
                    -- Start changes for CCR0007335
                    || lines_rec.attribute22
                    || CHR (9)
                    || lines_rec.attribute23        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    -- End changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute8, ' '), 15, ' ')
                    || lines_rec.attribute8
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute9, ' '), 15, ' ')
                    || lines_rec.attribute9
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute10, ' '), 15, ' ')
                    || lines_rec.attribute10
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute11, ' '), 40, ' ')
                    || lines_rec.attribute11
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute12, ' '), 10, ' ')
                    -- Start of Change 2.2
                    || lines_rec.attribute25
                    || CHR (9)
                    || lines_rec.attribute26
                    || CHR (9)
                    -- End of Chage
                    || lines_rec.attribute12
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute13, ' '), 10, ' ')
                    || lines_rec.attribute13
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute14, ' '), 10, ' ')
                    || lines_rec.attribute14
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute15, ' '), 10, ' ')
                    || lines_rec.attribute15
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute16, ' '), 15, ' ')
                    || lines_rec.attribute16
                    || CHR (9)
                    -- Start of Change 2.2
                    || lines_rec.attribute27
                    || CHR (9)
                    || lines_rec.attribute28
                    || CHR (9)
                    || lines_rec.attribute29
                    || CHR (9)
                    || lines_rec.attribute21
                    || CHR (9)
                    -- End of Chage
                    --|| RPAD (NVL (lines_rec.attribute17, ' '), 15, ' ')
                    || lines_rec.attribute17
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute18, ' '), 15, ' ')
                    || lines_rec.attribute18
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute19, ' '), 15, ' ')
                    || lines_rec.attribute19
                    || CHR (9)
                    -- Start of Change 2.2
                    /*
                   || RPAD (NVL (lines_rec.attribute20, ' '), 10, ' ')
                   || lines_rec.attribute20
                   || CHR (9)
                   || RPAD (NVL (lines_rec.attribute21, ' '), 15, ' ')
                   || lines_rec.attribute21
                   || CHR (9)
                   -- Start changes for CCR0007335
                   --|| RPAD (NVL (lines_rec.attribute22, ' '), 12, ' ')
                   --|| lines_rec.attribute22
                   --|| CHR (9)
                   -- En changes for CCR0007335
                   --|| RPAD (NVL (lines_rec.attribute23, ' '), 12, ' ')
                   || lines_rec.attribute23
                   || CHR (9)
                   --|| RPAD (NVL (lines_rec.attribute24, ' '), 12, ' ')
                   || lines_rec.attribute24
                   || CHR (9)
                   --|| RPAD (NVL (lines_rec.attribute25, ' '), 12, ' ')
                   || lines_rec.attribute25
                   || CHR (9)
                   --|| RPAD (NVL (lines_rec.attribute26, ' '), 12, ' ')
                   || lines_rec.attribute26
                   || CHR (9)
                   --|| RPAD (NVL (lines_rec.attribute27, ' '), 12, ' ')
                   || lines_rec.attribute27
                   || CHR (9)
                   --|| RPAD (NVL (lines_rec.attribute28, ' '), 12, ' ')
                   || lines_rec.attribute28
                   || CHR (9)
                   --|| RPAD (NVL (lines_rec.attribute29, ' '), 12, ' ')
                   || lines_rec.attribute29
                   || CHR (9)*/
                    --|| RPAD (NVL (lines_rec.attribute30, ' '), 12, ' ')
                    || lines_rec.attribute30
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute31, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute32, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute33, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute34, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute35, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute36, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute37, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute38, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute39, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute40, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute41, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute42, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute43, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute44, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute45, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute46, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute47, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute48, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute49, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute50, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute51, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute52, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute53, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute54, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute55, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute56, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute57, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute58, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute59, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute60, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute61, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute62, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute63, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute64, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute65, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute66, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute67, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute68, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute69, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute70, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute71, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute72, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute73, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute74, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute75, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute76, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute77, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute78, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute79, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute80, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute81, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute82, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute83, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute84, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute85, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute86, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute87, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute88, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute89, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute90, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute91, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute92, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute93, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute94, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute95, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute96, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute97, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute98, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute99, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute100, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute101, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute102, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute103, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute104, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute105, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute106, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute107, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute108, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute109, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute110, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute111, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute112, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute113, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute114, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute115, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute116, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute117, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute118, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute119, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute120, ' '), 12, ' ')
                    -- START PRB0041345
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute121, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute122, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute123, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute124, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute125, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute126, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute127, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute128, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute129, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute130, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute131, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute132, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute133, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute134, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute135, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute136, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute137, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute138, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute139, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute140, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute141, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute142, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute143, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute144, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute145, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute146, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute147, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute148, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute149, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute150, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute151, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute152, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute153, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute154, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute155, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute156, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute157, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute158, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute159, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute160, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute161, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute162, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute163, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute164, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute165, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute166, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute167, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute168, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute169, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute170, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute171, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute172, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute173, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute174, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute175, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute176, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute177, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute178, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute179, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute180, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute181, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute182, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute183, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute184, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute185, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute186, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute187, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute188, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute189, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute190, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute191, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute192, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute193, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute194, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute195, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute196, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute197, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute198, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute199, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute200, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute201, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute202, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute203, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute204, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute205, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute206, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute207, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute208, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute209, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute210, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute211, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute212, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute213, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute214, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute215, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute216, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute217, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute218, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute219, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute220, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute221, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute222, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute223, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute224, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute225, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute226, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute227, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute228, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute229, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute230, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute231, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute232, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute233, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute234, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute235, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute236, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute237, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute238, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute239, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute240, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute241, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute242, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute243, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute244, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute245, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute246, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute247, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute248, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute249, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute250, ' '), 12, ' ') --END PRB0041345
                                                                        );
            END LOOP;
        ELSIF p_sort_by = 'STYLE'
        THEN
            FOR lines_rec IN lines_style_cur
            LOOP
                -- Commented RPAD EXTRA_SPACES
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       --RPAD (NVL (lines_rec.attribute1, ' '), 40, ' ')
                       lines_rec.attribute1
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute2, ' '), 15, ' ')
                    || lines_rec.attribute2
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute3, ' '), 15, ' ')
                    || lines_rec.attribute3
                    || CHR (9)
                    || lines_rec.attribute24        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    --|| RPAD (NVL (lines_rec.attribute4, ' '), 15, ' ')
                    || lines_rec.attribute252                           -- 2.5
                    || CHR (9)
                    || lines_rec.attribute4
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute5, ' '), 15, ' ')
                    || lines_rec.attribute5
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute6, ' '), 30, ' ')
                    || lines_rec.attribute6
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute7, ' '), 10, ' ')
                    || lines_rec.attribute7
                    || CHR (9)
                    -- Start changes for CCR0007335
                    || lines_rec.attribute22
                    || CHR (9)
                    || lines_rec.attribute23        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    -- End changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute8, ' '), 15, ' ')
                    || lines_rec.attribute8
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute9, ' '), 15, ' ')
                    || lines_rec.attribute9
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute10, ' '), 15, ' ')
                    || lines_rec.attribute10
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute11, ' '), 40, ' ')
                    -- 2.5
                    || lines_rec.attribute251
                    || CHR (9)
                    --2.5
                    || lines_rec.attribute11
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute12, ' '), 10, ' ')
                    -- Start of Change 2.2
                    || lines_rec.attribute25
                    || CHR (9)
                    || lines_rec.attribute26
                    || CHR (9)
                    -- End of Chage
                    || lines_rec.attribute12
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute13, ' '), 10, ' ')
                    || lines_rec.attribute13
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute14, ' '), 10, ' ')
                    || lines_rec.attribute14
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute15, ' '), 10, ' ')
                    || lines_rec.attribute15
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute16, ' '), 15, ' ')
                    || lines_rec.attribute16
                    || CHR (9)
                    -- Start of Change 2.2
                    || lines_rec.attribute27
                    || CHR (9)
                    || lines_rec.attribute28
                    || CHR (9)
                    || lines_rec.attribute29
                    || CHR (9)
                    || lines_rec.attribute21
                    || CHR (9)
                    -- End of Chage
                    --|| RPAD (NVL (lines_rec.attribute17, ' '), 15, ' ')
                    || lines_rec.attribute17
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute18, ' '), 15, ' ')
                    || lines_rec.attribute18
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute19, ' '), 15, ' ')
                    || lines_rec.attribute19
                    || CHR (9)
                    /* Start of Change 2.2
                    --|| RPAD (NVL (lines_rec.attribute20, ' '), 10, ' ')
                    || lines_rec.attribute20
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute21, ' '), 15, ' ')
                    || lines_rec.attribute21
                    || CHR (9)
                    -- Start changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute22, ' '), 12, ' ')
                    --|| lines_rec.attribute22
                    --|| CHR (9)
                    -- En changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute23, ' '), 12, ' ')
                    || lines_rec.attribute23
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute24, ' '), 12, ' ')
                    || lines_rec.attribute24
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute25, ' '), 12, ' ')
                    || lines_rec.attribute25
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute26, ' '), 12, ' ')
                    || lines_rec.attribute26
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute27, ' '), 12, ' ')
                    || lines_rec.attribute27
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute28, ' '), 12, ' ')
                    || lines_rec.attribute28
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute29, ' '), 12, ' ')
                    || lines_rec.attribute29
                    || CHR (9)*/
                    --|| RPAD (NVL (lines_rec.attribute30, ' '), 12, ' ')
                    || lines_rec.attribute30
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute31, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute32, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute33, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute34, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute35, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute36, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute37, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute38, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute39, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute40, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute41, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute42, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute43, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute44, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute45, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute46, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute47, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute48, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute49, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute50, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute51, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute52, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute53, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute54, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute55, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute56, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute57, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute58, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute59, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute60, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute61, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute62, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute63, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute64, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute65, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute66, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute67, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute68, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute69, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute70, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute71, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute72, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute73, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute74, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute75, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute76, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute77, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute78, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute79, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute80, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute81, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute82, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute83, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute84, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute85, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute86, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute87, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute88, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute89, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute90, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute91, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute92, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute93, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute94, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute95, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute96, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute97, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute98, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute99, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute100, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute101, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute102, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute103, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute104, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute105, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute106, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute107, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute108, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute109, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute110, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute111, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute112, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute113, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute114, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute115, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute116, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute117, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute118, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute119, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute120, ' '), 12, ' ')
                    -- START PRB0041345
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute121, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute122, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute123, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute124, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute125, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute126, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute127, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute128, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute129, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute130, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute131, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute132, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute133, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute134, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute135, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute136, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute137, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute138, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute139, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute140, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute141, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute142, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute143, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute144, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute145, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute146, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute147, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute148, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute149, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute150, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute151, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute152, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute153, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute154, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute155, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute156, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute157, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute158, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute159, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute160, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute161, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute162, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute163, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute164, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute165, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute166, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute167, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute168, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute169, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute170, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute171, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute172, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute173, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute174, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute175, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute176, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute177, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute178, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute179, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute180, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute181, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute182, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute183, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute184, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute185, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute186, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute187, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute188, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute189, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute190, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute191, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute192, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute193, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute194, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute195, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute196, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute197, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute198, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute199, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute200, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute201, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute202, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute203, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute204, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute205, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute206, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute207, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute208, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute209, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute210, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute211, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute212, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute213, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute214, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute215, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute216, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute217, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute218, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute219, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute220, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute221, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute222, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute223, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute224, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute225, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute226, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute227, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute228, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute229, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute230, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute231, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute232, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute233, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute234, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute235, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute236, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute237, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute238, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute239, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute240, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute241, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute242, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute243, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute244, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute245, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute246, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute247, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute248, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute249, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute250, ' '), 12, ' ') --END PRB0041345
                                                                        );
            END LOOP;
        ELSIF p_sort_by = 'PO_NUMBER'
        THEN
            FOR lines_rec IN lines_po_number_cur
            LOOP
                -- Commented RPAD EXTRA_SPACES
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       --RPAD (NVL (lines_rec.attribute1, ' '), 40, ' ')
                       lines_rec.attribute1
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute2, ' '), 15, ' ')
                    || lines_rec.attribute2
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute3, ' '), 15, ' ')
                    || lines_rec.attribute3
                    || CHR (9)
                    || lines_rec.attribute24        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    --|| RPAD (NVL (lines_rec.attribute4, ' '), 15, ' ')
                    || lines_rec.attribute252                           -- 2.5
                    || CHR (9)
                    || lines_rec.attribute4
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute5, ' '), 15, ' ')
                    || lines_rec.attribute5
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute6, ' '), 30, ' ')
                    || lines_rec.attribute6
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute7, ' '), 10, ' ')
                    || lines_rec.attribute7
                    || CHR (9)
                    -- Start changes for CCR0007335
                    || lines_rec.attribute22
                    || CHR (9)
                    || lines_rec.attribute23        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    -- End changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute8, ' '), 15, ' ')
                    || lines_rec.attribute8
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute9, ' '), 15, ' ')
                    || lines_rec.attribute9
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute10, ' '), 15, ' ')
                    || lines_rec.attribute10
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute11, ' '), 40, ' ')
                    -- 2.5
                    || lines_rec.attribute251
                    || CHR (9)
                    -- 2.5
                    || lines_rec.attribute11
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute12, ' '), 10, ' ')
                    -- Start of Change 2.2
                    || lines_rec.attribute25
                    || CHR (9)
                    || lines_rec.attribute26
                    || CHR (9)
                    -- End of Chage
                    || lines_rec.attribute12
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute13, ' '), 10, ' ')
                    || lines_rec.attribute13
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute14, ' '), 10, ' ')
                    || lines_rec.attribute14
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute15, ' '), 10, ' ')
                    || lines_rec.attribute15
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute16, ' '), 15, ' ')
                    || lines_rec.attribute16
                    || CHR (9)
                    -- Start of Change 2.2
                    || lines_rec.attribute27
                    || CHR (9)
                    || lines_rec.attribute28
                    || CHR (9)
                    || lines_rec.attribute29
                    || CHR (9)
                    || lines_rec.attribute21
                    || CHR (9)
                    -- End of Chage
                    --|| RPAD (NVL (lines_rec.attribute17, ' '), 15, ' ')
                    || lines_rec.attribute17
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute18, ' '), 15, ' ')
                    || lines_rec.attribute18
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute19, ' '), 15, ' ')
                    || lines_rec.attribute19
                    || CHR (9)
                    /* Start of Change 2.2
                    --|| RPAD (NVL (lines_rec.attribute20, ' '), 10, ' ')
                    || lines_rec.attribute20
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute21, ' '), 15, ' ')
                    || lines_rec.attribute21
                    || CHR (9)
                    -- Start changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute22, ' '), 12, ' ')
                    --|| lines_rec.attribute22
                    --|| CHR (9)
                    -- En changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute23, ' '), 12, ' ')
                    || lines_rec.attribute23
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute24, ' '), 12, ' ')
                    || lines_rec.attribute24
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute25, ' '), 12, ' ')
                    || lines_rec.attribute25
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute26, ' '), 12, ' ')
                    || lines_rec.attribute26
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute27, ' '), 12, ' ')
                    || lines_rec.attribute27
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute28, ' '), 12, ' ')
                    || lines_rec.attribute28
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute29, ' '), 12, ' ')
                    || lines_rec.attribute29
                    || CHR (9)*/
                    --|| RPAD (NVL (lines_rec.attribute30, ' '), 12, ' ')
                    || lines_rec.attribute30
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute31, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute32, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute33, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute34, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute35, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute36, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute37, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute38, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute39, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute40, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute41, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute42, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute43, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute44, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute45, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute46, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute47, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute48, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute49, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute50, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute51, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute52, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute53, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute54, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute55, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute56, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute57, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute58, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute59, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute60, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute61, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute62, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute63, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute64, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute65, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute66, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute67, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute68, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute69, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute70, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute71, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute72, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute73, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute74, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute75, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute76, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute77, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute78, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute79, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute80, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute81, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute82, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute83, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute84, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute85, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute86, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute87, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute88, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute89, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute90, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute91, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute92, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute93, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute94, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute95, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute96, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute97, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute98, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute99, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute100, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute101, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute102, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute103, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute104, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute105, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute106, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute107, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute108, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute109, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute110, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute111, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute112, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute113, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute114, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute115, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute116, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute117, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute118, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute119, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute120, ' '), 12, ' ')
                    -- START PRB0041345
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute121, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute122, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute123, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute124, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute125, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute126, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute127, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute128, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute129, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute130, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute131, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute132, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute133, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute134, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute135, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute136, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute137, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute138, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute139, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute140, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute141, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute142, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute143, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute144, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute145, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute146, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute147, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute148, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute149, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute150, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute151, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute152, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute153, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute154, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute155, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute156, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute157, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute158, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute159, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute160, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute161, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute162, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute163, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute164, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute165, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute166, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute167, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute168, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute169, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute170, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute171, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute172, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute173, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute174, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute175, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute176, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute177, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute178, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute179, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute180, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute181, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute182, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute183, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute184, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute185, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute186, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute187, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute188, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute189, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute190, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute191, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute192, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute193, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute194, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute195, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute196, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute197, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute198, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute199, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute200, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute201, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute202, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute203, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute204, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute205, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute206, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute207, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute208, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute209, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute210, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute211, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute212, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute213, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute214, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute215, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute216, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute217, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute218, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute219, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute220, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute221, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute222, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute223, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute224, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute225, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute226, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute227, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute228, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute229, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute230, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute231, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute232, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute233, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute234, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute235, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute236, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute237, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute238, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute239, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute240, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute241, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute242, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute243, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute244, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute245, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute246, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute247, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute248, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute249, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute250, ' '), 12, ' ') --END PRB0041345
                                                                        );
            END LOOP;
        ELSIF p_sort_by = 'PO_DATE'
        THEN
            FOR lines_rec IN lines_po_date_cur
            LOOP
                -- Commented RPAD EXTRA_SPACES
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       --RPAD (NVL (lines_rec.attribute1, ' '), 40, ' ')
                       lines_rec.attribute1
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute2, ' '), 15, ' ')
                    || lines_rec.attribute2
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute3, ' '), 15, ' ')
                    || lines_rec.attribute3
                    || CHR (9)
                    || lines_rec.attribute24        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    --|| RPAD (NVL (lines_rec.attribute4, ' '), 15, ' ')
                    || lines_rec.attribute252                            --2.5
                    || CHR (9)
                    || lines_rec.attribute4
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute5, ' '), 15, ' ')
                    || lines_rec.attribute5
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute6, ' '), 30, ' ')
                    || lines_rec.attribute6
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute7, ' '), 10, ' ')
                    || lines_rec.attribute7
                    || CHR (9)
                    -- Start changes for CCR0007335
                    || lines_rec.attribute22
                    || CHR (9)
                    || lines_rec.attribute23        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    -- End changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute8, ' '), 15, ' ')
                    || lines_rec.attribute8
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute9, ' '), 15, ' ')
                    || lines_rec.attribute9
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute10, ' '), 15, ' ')
                    || lines_rec.attribute10
                    || CHR (9)
                    -- 2.5
                    || lines_rec.attribute251
                    || CHR (9)
                    -- 2.5
                    --|| RPAD (NVL (lines_rec.attribute11, ' '), 40, ' ')
                    || lines_rec.attribute11
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute12, ' '), 10, ' ')
                    -- Start of Change 2.2
                    || lines_rec.attribute25
                    || CHR (9)
                    || lines_rec.attribute26
                    || CHR (9)
                    -- End of Chage
                    || lines_rec.attribute12
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute13, ' '), 10, ' ')
                    || lines_rec.attribute13
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute14, ' '), 10, ' ')
                    || lines_rec.attribute14
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute15, ' '), 10, ' ')
                    || lines_rec.attribute15
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute16, ' '), 15, ' ')
                    || lines_rec.attribute16
                    || CHR (9)
                    -- Start of Change 2.2
                    || lines_rec.attribute27
                    || CHR (9)
                    || lines_rec.attribute28
                    || CHR (9)
                    || lines_rec.attribute29
                    || CHR (9)
                    || lines_rec.attribute21
                    || CHR (9)
                    -- End of Chage
                    --|| RPAD (NVL (lines_rec.attribute17, ' '), 15, ' ')
                    || lines_rec.attribute17
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute18, ' '), 15, ' ')
                    || lines_rec.attribute18
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute19, ' '), 15, ' ')
                    || lines_rec.attribute19
                    || CHR (9)
                    /* Start of Change 2.2
                    --|| RPAD (NVL (lines_rec.attribute20, ' '), 10, ' ')
                    || lines_rec.attribute20
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute21, ' '), 15, ' ')
                    || lines_rec.attribute21
                    || CHR (9)
                    -- Start changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute22, ' '), 12, ' ')
                    --|| lines_rec.attribute22
                    --|| CHR (9)
                    -- En changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute23, ' '), 12, ' ')
                    || lines_rec.attribute23
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute24, ' '), 12, ' ')
                    || lines_rec.attribute24
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute25, ' '), 12, ' ')
                    || lines_rec.attribute25
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute26, ' '), 12, ' ')
                    || lines_rec.attribute26
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute27, ' '), 12, ' ')
                    || lines_rec.attribute27
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute28, ' '), 12, ' ')
                    || lines_rec.attribute28
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute29, ' '), 12, ' ')
                    || lines_rec.attribute29
                    || CHR (9)*/
                    --|| RPAD (NVL (lines_rec.attribute30, ' '), 12, ' ')
                    || lines_rec.attribute30
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute31, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute32, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute33, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute34, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute35, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute36, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute37, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute38, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute39, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute40, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute41, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute42, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute43, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute44, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute45, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute46, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute47, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute48, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute49, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute50, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute51, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute52, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute53, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute54, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute55, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute56, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute57, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute58, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute59, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute60, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute61, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute62, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute63, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute64, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute65, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute66, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute67, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute68, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute69, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute70, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute71, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute72, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute73, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute74, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute75, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute76, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute77, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute78, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute79, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute80, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute81, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute82, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute83, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute84, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute85, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute86, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute87, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute88, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute89, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute90, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute91, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute92, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute93, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute94, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute95, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute96, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute97, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute98, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute99, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute100, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute101, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute102, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute103, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute104, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute105, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute106, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute107, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute108, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute109, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute110, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute111, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute112, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute113, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute114, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute115, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute116, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute117, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute118, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute119, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute120, ' '), 12, ' ')
                    -- START PRB0041345
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute121, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute122, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute123, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute124, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute125, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute126, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute127, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute128, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute129, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute130, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute131, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute132, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute133, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute134, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute135, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute136, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute137, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute138, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute139, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute140, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute141, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute142, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute143, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute144, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute145, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute146, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute147, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute148, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute149, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute150, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute151, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute152, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute153, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute154, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute155, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute156, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute157, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute158, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute159, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute160, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute161, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute162, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute163, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute164, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute165, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute166, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute167, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute168, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute169, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute170, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute171, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute172, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute173, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute174, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute175, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute176, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute177, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute178, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute179, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute180, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute181, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute182, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute183, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute184, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute185, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute186, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute187, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute188, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute189, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute190, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute191, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute192, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute193, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute194, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute195, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute196, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute197, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute198, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute199, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute200, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute201, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute202, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute203, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute204, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute205, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute206, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute207, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute208, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute209, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute210, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute211, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute212, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute213, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute214, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute215, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute216, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute217, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute218, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute219, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute220, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute221, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute222, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute223, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute224, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute225, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute226, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute227, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute228, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute229, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute230, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute231, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute232, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute233, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute234, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute235, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute236, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute237, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute238, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute239, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute240, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute241, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute242, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute243, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute244, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute245, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute246, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute247, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute248, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute249, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute250, ' '), 12, ' ') --END PRB0041345
                                                                        );
            END LOOP;
        ELSIF p_sort_by IS NULL
        THEN
            FOR lines_rec IN lines_cur
            LOOP
                -- Commented RPAD EXTRA_SPACES
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       --RPAD (NVL (lines_rec.attribute1, ' '), 40, ' ')
                       lines_rec.attribute1
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute2, ' '), 15, ' ')
                    || lines_rec.attribute2
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute3, ' '), 15, ' ')
                    || lines_rec.attribute3
                    || CHR (9)
                    || lines_rec.attribute24        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    --|| RPAD (NVL (lines_rec.attribute4, ' '), 15, ' ')
                    || lines_rec.attribute252                           -- 2.5
                    || CHR (9)
                    || lines_rec.attribute4
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute5, ' '), 15, ' ')
                    || lines_rec.attribute5
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute6, ' '), 30, ' ')
                    || lines_rec.attribute6
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute7, ' '), 10, ' ')
                    || lines_rec.attribute7
                    || CHR (9)
                    -- Start changes for CCR0007335
                    || lines_rec.attribute22
                    || CHR (9)
                    || lines_rec.attribute23        -- Added as per Change 2.2
                    || CHR (9)                      -- Added as per Change 2.2
                    -- End changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute8, ' '), 15, ' ')
                    || lines_rec.attribute8
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute9, ' '), 15, ' ')
                    || lines_rec.attribute9
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute10, ' '), 15, ' ')
                    || lines_rec.attribute10
                    || CHR (9)
                    -- 2.5
                    || lines_rec.attribute251
                    || CHR (9)
                    -- 2.5
                    --|| RPAD (NVL (lines_rec.attribute11, ' '), 40, ' ')
                    || lines_rec.attribute11
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute12, ' '), 10, ' ')
                    -- Start of Change 2.2
                    || lines_rec.attribute25
                    || CHR (9)
                    || lines_rec.attribute26
                    || CHR (9)
                    -- End of Chage
                    || lines_rec.attribute12
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute13, ' '), 10, ' ')
                    || lines_rec.attribute13
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute14, ' '), 10, ' ')
                    || lines_rec.attribute14
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute15, ' '), 10, ' ')
                    || lines_rec.attribute15
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute16, ' '), 15, ' ')
                    || lines_rec.attribute16
                    || CHR (9)
                    -- Start of Change 2.2
                    || lines_rec.attribute27
                    || CHR (9)
                    || lines_rec.attribute28
                    || CHR (9)
                    || lines_rec.attribute29
                    || CHR (9)
                    || lines_rec.attribute21
                    || CHR (9)
                    -- End of Chage
                    --|| RPAD (NVL (lines_rec.attribute17, ' '), 15, ' ')
                    || lines_rec.attribute17
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute18, ' '), 15, ' ')
                    || lines_rec.attribute18
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute19, ' '), 15, ' ')
                    || lines_rec.attribute19
                    || CHR (9)
                    /* Start of Change 2.2
                    --|| RPAD (NVL (lines_rec.attribute20, ' '), 10, ' ')
                    || lines_rec.attribute20
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute21, ' '), 15, ' ')
                    || lines_rec.attribute21
                    || CHR (9)
                    -- Start changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute22, ' '), 12, ' ')
                    --|| lines_rec.attribute22
                    --|| CHR (9)
                    -- En changes for CCR0007335
                    --|| RPAD (NVL (lines_rec.attribute23, ' '), 12, ' ')
                    || lines_rec.attribute23
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute24, ' '), 12, ' ')
                    || lines_rec.attribute24
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute25, ' '), 12, ' ')
                    || lines_rec.attribute25
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute26, ' '), 12, ' ')
                    || lines_rec.attribute26
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute27, ' '), 12, ' ')
                    || lines_rec.attribute27
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute28, ' '), 12, ' ')
                    || lines_rec.attribute28
                    || CHR (9)
                    --|| RPAD (NVL (lines_rec.attribute29, ' '), 12, ' ')
                    || lines_rec.attribute29
                    || CHR (9)*/
                    --|| RPAD (NVL (lines_rec.attribute30, ' '), 12, ' ')
                    || lines_rec.attribute30
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute31, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute32, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute33, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute34, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute35, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute36, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute37, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute38, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute39, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute40, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute41, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute42, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute43, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute44, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute45, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute46, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute47, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute48, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute49, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute50, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute51, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute52, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute53, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute54, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute55, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute56, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute57, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute58, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute59, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute60, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute61, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute62, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute63, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute64, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute65, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute66, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute67, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute68, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute69, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute70, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute71, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute72, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute73, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute74, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute75, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute76, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute77, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute78, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute79, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute80, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute81, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute82, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute83, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute84, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute85, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute86, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute87, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute88, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute89, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute90, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute91, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute92, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute93, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute94, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute95, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute96, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute97, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute98, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute99, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute100, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute101, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute102, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute103, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute104, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute105, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute106, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute107, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute108, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute109, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute110, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute111, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute112, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute113, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute114, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute115, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute116, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute117, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute118, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute119, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute120, ' '), 12, ' ')
                    -- START PRB0041345
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute121, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute122, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute123, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute124, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute125, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute126, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute127, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute128, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute129, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute130, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute131, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute132, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute133, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute134, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute135, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute136, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute137, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute138, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute139, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute140, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute141, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute142, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute143, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute144, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute145, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute146, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute147, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute148, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute149, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute150, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute151, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute152, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute153, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute154, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute155, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute156, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute157, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute158, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute159, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute160, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute161, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute162, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute163, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute164, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute165, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute166, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute167, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute168, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute169, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute170, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute171, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute172, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute173, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute174, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute175, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute176, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute177, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute178, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute179, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute180, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute181, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute182, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute183, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute184, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute185, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute186, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute187, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute188, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute189, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute190, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute191, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute192, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute193, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute194, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute195, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute196, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute197, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute198, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute199, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute200, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute201, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute202, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute203, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute204, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute205, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute206, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute207, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute208, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute209, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute210, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute211, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute212, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute213, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute214, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute215, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute216, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute217, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute218, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute219, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute220, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute221, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute222, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute223, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute224, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute225, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute226, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute227, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute228, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute229, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute230, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute231, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute232, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute233, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute234, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute235, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute236, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute237, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute238, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute239, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute240, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute241, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute242, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute243, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute244, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute245, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute246, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute247, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute248, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute249, ' '), 12, ' ')
                    || CHR (9)
                    || RPAD (NVL (lines_rec.attribute250, ' '), 12, ' ') --END PRB0041345
                                                                        );
            END LOOP;
        END IF;

        -- Commented RPAD EXTRA_SPACES

        FOR tot_rec IN tot_cur
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   --RPAD (NVL (tot_rec.attribute1, ' '), 40, ' ')

                   tot_rec.attribute1
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute2, ' '), 15, ' ')
                || tot_rec.attribute2
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute3, ' '), 15, ' ')
                || tot_rec.attribute3
                || CHR (9)
                || tot_rec.attribute24              -- Added as per Change 2.2
                || CHR (9)                          -- Added as per Change 2.2
                --|| RPAD (NVL (tot_rec.attribute4, ' '), 15, ' ')
                || tot_rec.attribute252                                  --2.5
                || CHR (9)
                || tot_rec.attribute4
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute5, ' '), 15, ' ')
                || tot_rec.attribute5
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute6, ' '), 30, ' ')
                || tot_rec.attribute6
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute7, ' '), 10, ' ')
                || tot_rec.attribute7
                || CHR (9)
                -- Start changes for CCR0007335
                || tot_rec.attribute22
                || CHR (9)
                || tot_rec.attribute23              -- Added as per Change 2.2
                || CHR (9)                          -- Added as per Change 2.2
                -- End changes for CCR0007335
                --|| RPAD (NVL (tot_rec.attribute8, ' '), 15, ' ')
                || tot_rec.attribute8
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute9, ' '), 15, ' ')
                || tot_rec.attribute9
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute10, ' '), 15, ' ')
                || tot_rec.attribute10
                || CHR (9)
                -- 2.5 changes
                || tot_rec.attribute251
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute11, ' '), 40, ' ')
                || tot_rec.attribute11
                || CHR (9)
                -- Start of Change 2.2
                || tot_rec.attribute25
                || CHR (9)
                || tot_rec.attribute26
                || CHR (9)
                -- End of Change
                --|| RPAD (NVL (tot_rec.attribute12, ' '), 10, ' ')
                || tot_rec.attribute12
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute13, ' '), 10, ' ')
                || tot_rec.attribute13
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute14, ' '), 10, ' ')
                || tot_rec.attribute14
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute15, ' '), 10, ' ')
                || tot_rec.attribute15
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute16, ' '), 15, ' ')
                || tot_rec.attribute16
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute17, ' '), 15, ' ')
                -- Start of Change 2.2
                || tot_rec.attribute27
                || CHR (9)
                || tot_rec.attribute28
                || CHR (9)
                || tot_rec.attribute29
                || CHR (9)
                || tot_rec.attribute21
                || CHR (9)
                -- End of Change
                || tot_rec.attribute17
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute18, ' '), 15, ' ')
                || tot_rec.attribute18
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute19, ' '), 15, ' ')
                || tot_rec.attribute19
                || CHR (9)
                /* Start of Change 2.2
                --|| RPAD (NVL (tot_rec.attribute20, ' '), 10, ' ')
                || tot_rec.attribute20
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute21, ' '), 15, ' ')
                || tot_rec.attribute21
                || CHR (9)
                -- Start changes for CCR0007335
                --|| RPAD (NVL (tot_rec.attribute22, ' '), 12, ' ')
                --|| tot_rec.attribute22
                --|| CHR (9)
                -- End changes for CCR0007335
                --|| RPAD (NVL (tot_rec.attribute23, ' '), 12, ' ')
                || tot_rec.attribute23
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute24, ' '), 12, ' ')
                || tot_rec.attribute24
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute25, ' '), 12, ' ')
                || tot_rec.attribute25
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute26, ' '), 12, ' ')
                || tot_rec.attribute26
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute27, ' '), 12, ' ')
                || tot_rec.attribute27
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute28, ' '), 12, ' ')
                || tot_rec.attribute28
                || CHR (9)
                --|| RPAD (NVL (tot_rec.attribute29, ' '), 12, ' ')
                || tot_rec.attribute29
                || CHR (9)*/
                -- End of Change
                --|| RPAD (NVL (tot_rec.attribute30, ' '), 12, ' ')
                || tot_rec.attribute30
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute31, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute32, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute33, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute34, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute35, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute36, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute37, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute38, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute39, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute40, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute41, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute42, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute43, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute44, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute45, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute46, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute47, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute48, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute49, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute50, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute51, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute52, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute53, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute54, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute55, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute56, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute57, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute58, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute59, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute60, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute61, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute62, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute63, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute64, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute65, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute66, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute67, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute68, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute69, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute70, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute71, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute72, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute73, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute74, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute75, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute76, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute77, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute78, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute79, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute80, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute81, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute82, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute83, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute84, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute85, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute86, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute87, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute88, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute89, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute90, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute91, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute92, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute93, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute94, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute95, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute96, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute97, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute98, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute99, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute100, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute101, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute102, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute103, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute104, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute105, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute106, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute107, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute108, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute109, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute110, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute111, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute112, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute113, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute114, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute115, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute116, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute117, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute118, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute119, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute120, ' '), 12, ' ')
                -- START PRB0041345
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute121, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute122, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute123, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute124, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute125, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute126, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute127, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute128, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute129, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute130, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute131, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute132, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute133, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute134, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute135, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute136, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute137, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute138, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute139, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute140, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute141, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute142, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute143, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute144, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute145, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute146, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute147, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute148, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute149, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute150, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute151, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute152, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute153, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute154, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute155, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute156, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute157, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute158, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute159, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute160, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute161, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute162, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute163, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute164, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute165, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute166, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute167, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute168, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute169, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute170, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute171, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute172, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute173, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute174, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute175, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute176, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute177, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute178, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute179, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute180, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute181, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute182, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute183, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute184, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute185, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute186, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute187, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute188, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute189, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute190, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute191, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute192, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute193, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute194, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute195, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute196, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute197, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute198, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute199, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute200, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute201, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute202, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute203, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute204, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute205, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute206, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute207, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute208, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute209, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute210, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute211, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute212, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute213, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute214, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute215, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute216, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute217, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute218, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute219, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute220, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute221, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute222, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute223, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute224, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute225, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute226, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute227, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute228, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute229, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute230, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute231, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute232, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute233, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute234, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute235, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute236, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute237, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute238, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute239, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute240, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute241, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute242, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute243, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute244, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute245, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute246, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute247, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute248, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute249, ' '), 12, ' ')
                || CHR (9)
                || RPAD (NVL (tot_rec.attribute250, ' '), 12, ' ') --END PRB0041345
                                                                  );
        END LOOP;
    -- Start changes for CCR0007335

    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in AUDIT_REPORT= ' || SQLERRM);
    -- End changes for CCR0007335
    END audit_report;
END xxdo_po_listing_by_size;
/
