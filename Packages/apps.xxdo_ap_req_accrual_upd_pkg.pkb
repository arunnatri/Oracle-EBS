--
-- XXDO_AP_REQ_ACCRUAL_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AP_REQ_ACCRUAL_UPD_PKG"
AS
    /******************************************************************************
       NAME: XXDO_AP_REQ_ACCRUAL_UPD_PKG
      This package is called from porgcon.sql
      Program NAme = Create Releases
       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       06/20/2013     Murali        1. Created this package for PO Accrual Report.
       v1.1      12/DEC/2014   BT Technology Team  Retrofit for BT project
    ******************************************************************************/
    FUNCTION get_accrual_seg (p_req_dist_id   NUMBER,
                              p_org_id        NUMBER,
                              p_col           VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR c1 (p_req_dist_id IN NUMBER, p_org_id NUMBER)
        IS
            SELECT distribution_id, accrual_account_id, /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                        --gcc.segment2,
                                                        gcc.segment5,
                   /*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                   lines.item_id, lines.destination_organization_id, party.party_name,
                   oeh.order_number, oeh.attribute5 brand, loc.country || '-' || terr.territory_short_name country
              FROM apps.po_req_distributions_all dist, apps.po_requisition_lines_all lines, apps.po_requisition_headers_all hdr,
                   apps.oe_drop_ship_sources dss, apps.oe_order_lines_all oola, apps.hz_cust_site_uses_all uses,
                   apps.gl_code_combinations gcc, apps.oe_order_headers_all oeh, apps.hz_cust_acct_sites_all sites,
                   apps.hz_cust_accounts cust, apps.hz_parties party, apps.hz_cust_acct_sites_all sites1,
                   apps.hz_cust_site_uses_all uses1, apps.hz_party_sites party_site, apps.hz_locations loc,
                   apps.fnd_territories_tl terr
             WHERE     dist.org_id = p_org_id
                   AND dist.requisition_line_id = lines.requisition_line_id
                   AND lines.requisition_header_id =
                       hdr.requisition_header_id
                   AND dist.distribution_id = p_req_dist_id
                   AND lines.drop_ship_flag = 'Y'
                   AND lines.requisition_line_id = dss.requisition_line_id
                   AND lines.requisition_header_id =
                       dss.requisition_header_id
                   AND dss.header_id = oola.header_id
                   AND dss.line_id = oola.line_id
                   AND oola.invoice_to_org_id = uses.site_use_id
                   AND uses.gl_id_rev = gcc.code_combination_id
                   AND oola.header_id = oeh.header_id
                   AND uses.site_use_code = 'BILL_TO'
                   AND uses.cust_acct_site_id = sites.cust_acct_site_id
                   AND sites.cust_account_id = cust.cust_account_id
                   AND cust.party_id = party.party_id
                   --
                   AND oola.ship_to_org_id = uses1.site_use_id
                   AND uses1.site_use_code = 'SHIP_TO'
                   AND uses1.cust_acct_site_id = sites1.cust_acct_site_id
                   AND sites1.cust_account_id = cust.cust_account_id
                   AND sites1.party_site_id = party_site.party_site_id
                   AND loc.location_id = party_site.location_id
                   AND loc.country = terr.territory_code
                   AND terr.LANGUAGE = USERENV ('LANG');

        CURSOR c2 (p_req_dist_id IN NUMBER, p_org_id NUMBER)
        IS
            SELECT dist.distribution_id, dist.accrual_account_id, /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                                  --gcc.segment2,
                                                                  gcc.segment5,
                   /*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                   lines.item_id, lines.destination_organization_id, party.party_name,
                   oeh.order_number, oeh.attribute5 brand, loc.country || '-' || terr.territory_short_name country
              FROM apps.po_req_distributions_all dist, apps.po_requisition_lines_all lines, -- apps.PO_REQUISITION_headers_all hdr,
                                                                                            apps.oe_order_lines_all oola,
                   apps.hz_cust_site_uses_all uses, apps.gl_code_combinations gcc, apps.oe_order_headers_all oeh,
                   apps.hz_cust_acct_sites_all sites, apps.hz_cust_accounts cust, apps.hz_parties party,
                   apps.po_distributions_all poda, apps.hz_cust_acct_sites_all sites1, apps.hz_cust_site_uses_all uses1,
                   apps.hz_party_sites party_site, apps.hz_locations loc, apps.fnd_territories_tl terr
             WHERE     dist.org_id = p_org_id
                   AND dist.requisition_line_id = lines.requisition_line_id
                   -- and lines.REQUISITION_HEADER_ID =   hdr.REQUISITION_HEADER_ID
                   AND dist.distribution_id = p_req_dist_id
                   AND dist.distribution_id = poda.req_distribution_id
                   -- and hdr.INTERFACE_SOURCE_LINE_ID      =   oola.LINE_ID
                   AND oola.attribute16 = TO_CHAR (poda.line_location_id)
                   AND oola.attribute16 IS NOT NULL
                   AND oola.invoice_to_org_id = uses.site_use_id
                   AND uses.gl_id_rev = gcc.code_combination_id
                   AND oola.header_id = oeh.header_id
                   AND uses.site_use_code = 'BILL_TO'
                   AND uses.cust_acct_site_id = sites.cust_acct_site_id
                   AND sites.cust_account_id = cust.cust_account_id
                   AND cust.party_id = party.party_id
                   --
                   AND oola.ship_to_org_id = uses1.site_use_id
                   AND uses1.site_use_code = 'SHIP_TO'
                   AND uses1.cust_acct_site_id = sites1.cust_acct_site_id
                   AND sites1.cust_account_id = cust.cust_account_id
                   AND sites1.party_site_id = party_site.party_site_id
                   AND loc.location_id = party_site.location_id
                   AND loc.country = terr.territory_code
                   AND terr.LANGUAGE = USERENV ('LANG');

        l_request_id    NUMBER;
        l_prequest_id   NUMBER;
        l_acr_account   NUMBER;
        l_source_code   VARCHAR2 (100);
        l_segment2      NUMBER;
        l_return        VARCHAR2 (200);
        l_cust          VARCHAR2 (200);
        l_order         VARCHAR2 (50);
        l_brand         VARCHAR2 (50);
        l_country       VARCHAR2 (50);
    BEGIN
        --- Getting the accrual account logic starts here and then it updates the REQ Distribution TABLE
        -- WO - 83000 - Modified by Shibu on 19th MAY
        BEGIN
            SELECT hdr.interface_source_code
              INTO l_source_code
              FROM apps.po_req_distributions_all dist, apps.po_requisition_lines_all lines, apps.po_requisition_headers_all hdr
             WHERE     dist.requisition_line_id = lines.requisition_line_id
                   AND lines.requisition_header_id =
                       hdr.requisition_header_id
                   AND dist.org_id = p_org_id
                   AND dist.distribution_id = p_req_dist_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_source_code   := NULL;
        END;

        IF l_source_code = 'CTO'
        THEN
            FOR i IN c2 (p_req_dist_id, p_org_id)
            LOOP
                l_acr_account   :=
                    get_do_accrual_account (i.destination_organization_id, i.item_id, i.accrual_account_id
                                            , /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                              --  i.segment2
                                              i.segment5/*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                        );

                SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                       --gcc.segment2
                       gcc.segment5
                  /*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                  INTO l_segment2
                  FROM apps.gl_code_combinations gcc
                 WHERE gcc.code_combination_id = l_acr_account;

                l_cust      := i.party_name;
                l_order     := i.order_number;
                l_brand     := i.brand;
                l_country   := i.country;
            --apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG,l_source_code ||'CTO'||l_acr_account);
            END LOOP;
        ELSE
            FOR i IN c1 (p_req_dist_id, p_org_id)
            LOOP
                l_acr_account   :=
                    get_do_accrual_account (i.destination_organization_id, i.item_id, i.accrual_account_id
                                            , /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                              --  i.segment2
                                              i.segment5/*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                        );

                SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                       --gcc.segment2
                       gcc.segment5
                  /*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                  INTO l_segment2
                  FROM apps.gl_code_combinations gcc
                 WHERE gcc.code_combination_id = l_acr_account;

                l_cust      := i.party_name;
                l_order     := i.order_number;
                l_brand     := i.brand;
                l_country   := i.country;
            END LOOP;
        -- WO 83000 ends
        END IF;

        IF p_col = 'SEG'
        THEN
            l_return   := l_segment2;
        ELSIF p_col = 'CUST'
        THEN
            l_return   := l_cust;
        ELSIF p_col = 'ORDER'
        THEN
            l_return   := l_order;
        ELSIF p_col = 'BRAND'
        THEN
            l_return   := l_brand;
        ELSIF p_col = 'COUNTRY'
        THEN
            l_return   := l_country;
        END IF;

        RETURN l_return;
    EXCEPTION
        WHEN OTHERS
        THEN
            --apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Program Error' || SQLCODE || SQLERRM);
            RETURN 0;
    END get_accrual_seg;

    FUNCTION get_do_accrual_account (p_inv_org_id IN NUMBER, p_item_id IN NUMBER, p_cc_id IN NUMBER
                                     , p_segment2 IN VARCHAR2)
        RETURN NUMBER
    IS
        /*-------------------------------------------------------------------------------------
        Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
        ---------------------------------------------------------------------------------------
              l_item_sales_brand       apps.gl_code_combinations.segment4%TYPE;
              l_new_accrual_acct       NUMBER;
              l_seg1                   apps.gl_code_combinations.segment1%TYPE;
              l_seg2                   apps.gl_code_combinations.segment2%TYPE;
              l_seg3                   apps.gl_code_combinations.segment3%TYPE;
              l_chart_of_accounts_id   NUMBER;
              l_segment2               apps.gl_code_combinations.segment2%TYPE;
        */

        l_item_sales_brand       apps.gl_code_combinations.segment2%TYPE;
        l_new_accrual_acct       NUMBER;
        l_seg1                   apps.gl_code_combinations.segment1%TYPE;
        l_seg2                   apps.gl_code_combinations.segment5%TYPE;
        l_seg3                   apps.gl_code_combinations.segment6%TYPE;
        l_chart_of_accounts_id   NUMBER;
        l_segment2               apps.gl_code_combinations.segment5%TYPE;
    /*----------------------------------------------------------------------------------------
    End changes by BT Technology Team on 12-DEC-2014  - V 1.1
    ----------------------------------------------------------------------------------------*/

    BEGIN
        -- ---------------------------------------------------------------------------------------------------------------
        -- OVERVIEW:
        -- Deckers Extended Logic for the default PO AP Accrual GL Account.
        -- Overall logic:
        -- Use default AP Accrual Account from the related Ship-to Org Parameters, but overlay the BRAND (gl segment 4)
        -- from the PO Item's default sales account (for the related ship-to org).
        --
        -- If Item Sales Account is not populated OR the newly constructed GL Account Combination is now set-up, then
        -- return the org-level default AP Accrual Account (non-brand specific).
        -- ---------------------------------------------------------------------------------------------------------------

        -- Derive the default AP/PO Accrual Account ID for the deliver-to org
        BEGIN
            SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                   --gcc.segment1, gcc.segment2, gcc.segment3,
                   gcc.segment1, gcc.segment5, gcc.segment6,
                   chart_of_accounts_id
              /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
              INTO l_seg1, l_seg2, l_seg3, l_chart_of_accounts_id
              FROM apps.gl_code_combinations gcc
             WHERE gcc.code_combination_id = p_cc_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN (p_cc_id);
            WHEN OTHERS
            THEN
                RETURN (p_cc_id);
        END;

        -- Derive the default sales account brand for the current Item / Org
        BEGIN
            SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                   --gcc.segment4
                   gcc.segment2
              /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1  */
              INTO l_item_sales_brand
              FROM apps.gl_code_combinations gcc, apps.mtl_system_items msi
             WHERE     msi.inventory_item_id = p_item_id
                   AND msi.organization_id = p_inv_org_id
                   AND msi.sales_account = gcc.code_combination_id
                   AND gcc.enabled_flag = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                RETURN (p_cc_id);
            WHEN OTHERS
            THEN
                RETURN (p_cc_id);
        END;

        -- Derive the new account overlaying the default ap/po accrual account with the item sales brand
        SELECT gcc.code_combination_id
          INTO l_new_accrual_acct
          FROM apps.gl_code_combinations gcc
         WHERE     gcc.chart_of_accounts_id = l_chart_of_accounts_id
               /*-------------------------------------------------------------------------------------
               Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
               ---------------------------------------------------------------------------------------
                        AND NVL (gcc.segment1, '~') = NVL (l_seg1, '~')
                        AND NVL (gcc.segment2, '~') = NVL (p_segment2, l_seg2)
                        AND NVL (gcc.segment3, '~') = NVL (l_seg3, '~')
                        AND NVL (gcc.segment4, '~') = l_item_sales_brand
                        AND gcc.enabled_flag = 'Y';
               */
               AND NVL (gcc.segment1, '~') = NVL (l_seg1, '~')
               AND NVL (gcc.segment5, '~') = NVL (p_segment2, l_seg2)
               AND NVL (gcc.segment6, '~') = NVL (l_seg3, '~')
               AND NVL (gcc.segment2, '~') = l_item_sales_brand
               AND gcc.enabled_flag = 'Y';

        /*----------------------------------------------------------------------------------------
        End changes by BT Technology Team on 12-DEC-2014  - V 1.1
        ----------------------------------------------------------------------------------------*/
        RETURN (l_new_accrual_acct);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN (p_cc_id);
        WHEN OTHERS
        THEN
            RETURN (p_cc_id);
    END get_do_accrual_account;

    FUNCTION xxdo_get_item_details (pv_style IN VARCHAR2, pn_inventory_item_id NUMBER, pv_detail IN VARCHAR2)
        RETURN VARCHAR2
    IS
        ln_details   VARCHAR2 (80);
    BEGIN
        IF pv_detail = 'STYLE'
        THEN
            BEGIN
                ln_details   := NULL;

                /*-------------------------------------------------------------------------------------
                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                ---------------------------------------------------------------------------------------
                            SELECT mtl.segment1
                              INTO ln_details
                              FROM apps.mtl_system_items_b mtl
                             WHERE mtl.inventory_item_id = pn_inventory_item_id
                               AND mtl.organization_id = 7;
                */
                SELECT xci.style_number
                  INTO ln_details
                  FROM apps.xxd_common_items_v xci, mtl_parameters mp
                 WHERE     xci.inventory_item_id = pn_inventory_item_id
                       AND xci.organization_id = mp.organization_id
                       AND mp.organization_code = 'MST';

                /*----------------------------------------------------------------------------------------
                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                ----------------------------------------------------------------------------------------*/
                RETURN ln_details;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_details   := 'NA';
                WHEN OTHERS
                THEN
                    ln_details   := 'NA';
                    RETURN ln_details;
            END;
        ELSE
            IF pv_detail = 'STYLECOLOR'
            THEN
                IF pv_style = 'NA'
                THEN
                    BEGIN
                        ln_details   := NULL;

                        /*------------------------------------------------------------------------------------------------
                        Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                        --------------------------------------------------------------------------------------------------
                                          SELECT mtl.segment1 || '-' || mtl.segment2
                                            INTO ln_details
                                            FROM apps.mtl_system_items_b mtl
                                           WHERE mtl.inventory_item_id = pn_inventory_item_id
                                             AND mtl.organization_id = 7;
                        */

                        SELECT xci.style_number || '-' || xci.color_code
                          INTO ln_details
                          FROM apps.xxd_common_items_v xci, mtl_parameters mp
                         WHERE     xci.inventory_item_id =
                                   pn_inventory_item_id
                               AND xci.organization_id = mp.organization_id
                               AND mp.organization_code = 'MST';

                        /*----------------------------------------------------------------------------------------------------
                        End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                        ------------------------------------------------------------------------------------------------------*/
                        RETURN ln_details;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_details   := 'NA';
                        WHEN OTHERS
                        THEN
                            ln_details   := 'NA';
                            RETURN ln_details;
                    END;
                ELSE
                    BEGIN
                        ln_details   := NULL;

                        /*------------------------------------------------------------------------------------------------
                        Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                        --------------------------------------------------------------------------------------------------
                                          SELECT mtl.segment1 || '-' || mtl.segment2
                                            INTO ln_details
                                            FROM apps.mtl_system_items_b mtl
                                           WHERE mtl.segment1 = pv_style AND mtl.organization_id = 7;
                        */

                        SELECT xci.style_number || '-' || xci.color_code
                          INTO ln_details
                          FROM apps.xxd_common_items_v xci, mtl_parameters mp
                         WHERE     xci.style_number = pv_style
                               AND xci.inventory_item_id =
                                   pn_inventory_item_id
                               AND xci.organization_id = mp.organization_id
                               AND mp.organization_code = 'MST';

                        /*----------------------------------------------------------------------------------------------------
                        End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                        ------------------------------------------------------------------------------------------------------*/
                        RETURN ln_details;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_details   := 'NA';
                        WHEN OTHERS
                        THEN
                            ln_details   := 'NA';
                            RETURN ln_details;
                    END;
                END IF;
            ELSE
                IF pv_detail = 'BRAND'
                THEN
                    IF pv_style = 'NA'
                    THEN
                        BEGIN
                            ln_details   := NULL;

                            /*------------------------------------------------------------------------------------------------
                            Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                            --------------------------------------------------------------------------------------------------
                                                 SELECT DISTINCT mcb.segment1
                                                            INTO ln_details
                                                            FROM apps.mtl_categories_b mcb,
                                                                 apps.mtl_item_categories mic,
                                                                 apps.mtl_system_items_b msi
                                                           WHERE mic.inventory_item_id =
                                                                                     msi.inventory_item_id
                                                             AND mic.organization_id = msi.organization_id
                                                             AND mic.category_set_id = 1
                                                             AND mcb.category_id = mic.category_id
                                                             AND mcb.structure_id = 101
                                                             AND msi.inventory_item_id =
                                                                                      pn_inventory_item_id
                                                             AND msi.organization_id = 7;
                            */

                            SELECT DISTINCT xci.brand
                              INTO ln_details
                              FROM apps.xxd_common_items_v xci, mtl_parameters mp
                             WHERE     xci.inventory_item_id =
                                       pn_inventory_item_id
                                   AND xci.organization_id =
                                       mp.ORGANIZATION_ID
                                   AND mp.organization_code = 'MST';

                            /*----------------------------------------------------------------------------------------------------
                            End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                            ------------------------------------------------------------------------------------------------------*/
                            RETURN ln_details;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_details   := 'NA';
                            WHEN OTHERS
                            THEN
                                ln_details   := 'NA';
                                RETURN ln_details;
                        END;
                    ELSE
                        BEGIN
                            ln_details   := NULL;

                            /*------------------------------------------------------------------------------------------------
                            Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                            --------------------------------------------------------------------------------------------------
                                                 SELECT DISTINCT mcb.segment1
                                                            INTO ln_details
                                                            FROM apps.mtl_categories_b mcb,
                                                                 apps.mtl_item_categories mic,
                                                                 apps.mtl_system_items_b msi
                                                           WHERE mic.inventory_item_id = msi.inventory_item_id
                                                             AND mic.organization_id = msi.organization_id
                                                             AND mic.category_set_id = 1
                                                             AND mcb.category_id = mic.category_id
                                                             AND mcb.structure_id = 101
                                                             AND msi.segment1 = pv_style
                                                             AND msi.organization_id = 7;
                            */

                            SELECT DISTINCT xci.brand
                              INTO ln_details
                              FROM apps.xxd_common_items_v xci, mtl_parameters mp
                             WHERE     xci.inventory_item_id =
                                       pn_inventory_item_id
                                   AND xci.style_number = pv_style
                                   AND xci.organization_id =
                                       mp.ORGANIZATION_ID
                                   AND mp.organization_code = 'MST';

                            /*----------------------------------------------------------------------------------------------------
                            End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                            ------------------------------------------------------------------------------------------------------*/
                            RETURN ln_details;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_details   := 'NA';
                            WHEN OTHERS
                            THEN
                                ln_details   := 'NA';
                                RETURN ln_details;
                        END;
                    END IF;
                ELSE
                    IF pv_detail = 'SKU'
                    THEN
                        BEGIN
                            ln_details   := NULL;

                            /*------------------------------------------------------------------------------------------------
                            Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                            --------------------------------------------------------------------------------------------------
                                                 SELECT    mtl.segment1
                                                        || '-'
                                                        || mtl.segment2
                                                        || '-'
                                                        || mtl.segment3
                                                   INTO ln_details
                                                   FROM apps.mtl_system_items_b mtl
                                                  WHERE mtl.inventory_item_id = pn_inventory_item_id
                                                    AND mtl.organization_id = 7;
                            */

                            SELECT xci.item_number
                              INTO ln_details
                              FROM apps.xxd_common_items_v xci, apps.mtl_parameters mp
                             WHERE     xci.inventory_item_id =
                                       pn_inventory_item_id
                                   AND xci.organization_id =
                                       mp.organization_id
                                   AND mp.organization_code = 'MST';

                            /*----------------------------------------------------------------------------------------------------
                            End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                            ------------------------------------------------------------------------------------------------------*/
                            RETURN ln_details;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_details   := 'NA';
                            WHEN OTHERS
                            THEN
                                ln_details   := 'NA';
                                RETURN ln_details;
                        END;
                    ELSE
                        IF pv_detail = 'INTRO'
                        THEN
                            IF pv_style = 'NA'
                            THEN
                                BEGIN
                                    ln_details   := NULL;

                                    /*------------------------------------------------------------------------------------------------
                                    Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                    --------------------------------------------------------------------------------------------------
                                                               SELECT DISTINCT mcb.segment5
                                                                          INTO ln_details
                                                                          FROM apps.mtl_categories_b mcb,
                                                                               apps.mtl_item_categories mic,
                                                                               apps.mtl_system_items_b msi
                                                                         WHERE mic.inventory_item_id =
                                                                                             msi.inventory_item_id
                                                                           AND mic.organization_id =
                                                                                               msi.organization_id
                                                                           AND mic.category_set_id = 1
                                                                           AND mcb.category_id = mic.category_id
                                                                           AND mcb.structure_id = 101
                                                                           AND msi.inventory_item_id =
                                                                                              pn_inventory_item_id
                                                                           AND msi.organization_id = 7;
                                    */

                                    SELECT DISTINCT xci.curr_active_season
                                      INTO ln_details
                                      FROM apps.xxd_common_items_v xci, mtl_parameters mp
                                     WHERE     xci.inventory_item_id =
                                               pn_inventory_item_id
                                           AND xci.organization_id =
                                               mp.organization_id
                                           AND mp.organization_code = 'MST';

                                    /*----------------------------------------------------------------------------------------------------
                                    End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                    ------------------------------------------------------------------------------------------------------*/

                                    RETURN ln_details;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        ln_details   := 'NA';
                                    WHEN OTHERS
                                    THEN
                                        ln_details   := 'NA';
                                        RETURN ln_details;
                                END;
                            ELSE
                                BEGIN
                                    ln_details   := NULL;

                                    /*------------------------------------------------------------------------------------------------
                                    Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                    --------------------------------------------------------------------------------------------------
                                                               SELECT DISTINCT mcb.segment5
                                                                          INTO ln_details
                                                                          FROM apps.mtl_categories_b mcb,
                                                                               apps.mtl_item_categories mic,
                                                                               apps.mtl_system_items_b msi
                                                                         WHERE mic.inventory_item_id =
                                                                                             msi.inventory_item_id
                                                                           AND mic.organization_id =
                                                                                               msi.organization_id
                                                                           AND mic.category_set_id = 1
                                                                           AND mcb.category_id = mic.category_id
                                                                           AND mcb.structure_id = 101
                                                                           AND msi.segment1 = pv_style
                                                                           AND msi.organization_id = 7;
                                    */

                                    SELECT DISTINCT xci.curr_active_season
                                      INTO ln_details
                                      FROM apps.xxd_common_items_v xci, mtl_parameters mp
                                     WHERE     xci.inventory_item_id =
                                               pn_inventory_item_id
                                           AND xci.style_number = pv_style
                                           AND xci.organization_id =
                                               mp.organization_id
                                           AND mp.organization_code = 'MST';

                                    /*----------------------------------------------------------------------------------------------------
                                    End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                    ------------------------------------------------------------------------------------------------------*/
                                    RETURN ln_details;
                                EXCEPTION
                                    WHEN NO_DATA_FOUND
                                    THEN
                                        ln_details   := 'NA';
                                    WHEN OTHERS
                                    THEN
                                        ln_details   := 'NA';
                                        RETURN ln_details;
                                END;
                            END IF;
                        ELSE
                            IF pv_detail = 'PRODUCT'
                            THEN
                                IF pv_style = 'NA'
                                THEN
                                    BEGIN
                                        ln_details   := NULL;

                                        /*------------------------------------------------------------------------------------------------
                                        Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                        --------------------------------------------------------------------------------------------------
                                                                      SELECT DISTINCT mcb.segment2
                                                                                 INTO ln_details
                                                                                 FROM apps.mtl_categories_b mcb,
                                                                                      apps.mtl_item_categories mic,
                                                                                      apps.mtl_system_items_b msi
                                                                                WHERE mic.inventory_item_id =
                                                                                                 msi.inventory_item_id
                                                                                  AND mic.organization_id =
                                                                                                   msi.organization_id
                                                                                  AND mic.category_set_id = 1
                                                                                  AND mcb.category_id =
                                                                                                       mic.category_id
                                                                                  AND mcb.structure_id = 101
                                                                                  AND msi.inventory_item_id =
                                                                                                  pn_inventory_item_id
                                                                                  AND msi.organization_id = 7;
                                        */

                                        SELECT DISTINCT xci.division
                                          INTO ln_details
                                          FROM apps.xxd_common_items_v xci, mtl_parameters mp
                                         WHERE     xci.inventory_item_id =
                                                   pn_inventory_item_id
                                               AND xci.organization_id =
                                                   mp.organization_id
                                               AND mp.organization_code =
                                                   'MST';

                                        /*----------------------------------------------------------------------------------------------------
                                        End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                        ------------------------------------------------------------------------------------------------------*/
                                        RETURN ln_details;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_details   := 'NA';
                                        WHEN OTHERS
                                        THEN
                                            ln_details   := 'NA';
                                            RETURN ln_details;
                                    END;
                                ELSE
                                    BEGIN
                                        ln_details   := NULL;

                                        /*------------------------------------------------------------------------------------------------
                                        Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                        --------------------------------------------------------------------------------------------------
                                                                      SELECT DISTINCT mcb.segment2
                                                                                 INTO ln_details
                                                                                 FROM apps.mtl_categories_b mcb,
                                                                                      apps.mtl_item_categories mic,
                                                                                      apps.mtl_system_items_b msi
                                                                                WHERE mic.inventory_item_id =
                                                                                                 msi.inventory_item_id
                                                                                  AND mic.organization_id =
                                                                                                   msi.organization_id
                                                                                  AND mic.category_set_id = 1
                                                                                  AND mcb.category_id =
                                                                                                       mic.category_id
                                                                                  AND mcb.structure_id = 101
                                                                                  AND msi.segment1 = pv_style
                                                                                  AND msi.organization_id = 7;
                                        */
                                        SELECT DISTINCT xci.division
                                          INTO ln_details
                                          FROM apps.xxd_common_items_v xci, mtl_parameters mp
                                         WHERE     xci.inventory_item_id =
                                                   pn_inventory_item_id
                                               AND xci.style_number =
                                                   pv_style
                                               AND xci.organization_id =
                                                   mp.organization_id
                                               AND mp.organization_code =
                                                   'MST';

                                        /*----------------------------------------------------------------------------------------------------
                                        End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                        ------------------------------------------------------------------------------------------------------*/

                                        RETURN ln_details;
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_details   := 'NA';
                                        WHEN OTHERS
                                        THEN
                                            ln_details   := 'NA';
                                            RETURN ln_details;
                                    END;
                                END IF;
                            ELSE
                                IF pv_detail = 'GENDER'
                                THEN
                                    IF pv_style = 'NA'
                                    THEN
                                        BEGIN
                                            ln_details   := NULL;

                                            /*------------------------------------------------------------------------------------------------
                                            Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                            --------------------------------------------------------------------------------------------------
                                                                             SELECT DISTINCT mcb.segment3
                                                                                        INTO ln_details
                                                                                        FROM apps.mtl_categories_b mcb,
                                                                                             apps.mtl_item_categories mic,
                                                                                             apps.mtl_system_items_b msi
                                                                                       WHERE mic.inventory_item_id =
                                                                                                     msi.inventory_item_id
                                                                                         AND mic.organization_id =
                                                                                                       msi.organization_id
                                                                                         AND mic.category_set_id = 1
                                                                                         AND mcb.category_id =
                                                                                                           mic.category_id
                                                                                         AND mcb.structure_id = 101
                                                                                         AND msi.inventory_item_id =
                                                                                                      pn_inventory_item_id
                                                                                         AND msi.organization_id = 7;
                                            */

                                            SELECT DISTINCT xci.department
                                              INTO ln_details
                                              FROM apps.xxd_common_items_v xci, mtl_parameters mp
                                             WHERE     xci.inventory_item_id =
                                                       pn_inventory_item_id
                                                   AND xci.organization_id =
                                                       mp.organization_id
                                                   AND mp.organization_code =
                                                       'MST';

                                            /*----------------------------------------------------------------------------------------------------
                                            End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                            ------------------------------------------------------------------------------------------------------*/
                                            RETURN ln_details;
                                        EXCEPTION
                                            WHEN NO_DATA_FOUND
                                            THEN
                                                ln_details   := 'NA';
                                            WHEN OTHERS
                                            THEN
                                                ln_details   := 'NA';
                                                RETURN ln_details;
                                        END;
                                    ELSE
                                        BEGIN
                                            ln_details   := NULL;

                                            /*------------------------------------------------------------------------------------------------
                                            Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                            --------------------------------------------------------------------------------------------------
                                                                             SELECT DISTINCT mcb.segment3
                                                                                        INTO ln_details
                                                                                        FROM apps.mtl_categories_b mcb,
                                                                                             apps.mtl_item_categories mic,
                                                                                             apps.mtl_system_items_b msi
                                                                                       WHERE mic.inventory_item_id =
                                                                                                     msi.inventory_item_id
                                                                                         AND mic.organization_id =
                                                                                                       msi.organization_id
                                                                                         AND mic.category_set_id = 1
                                                                                         AND mcb.category_id =
                                                                                                           mic.category_id
                                                                                         AND mcb.structure_id = 101
                                                                                         AND msi.segment1 = pv_style
                                                                                         AND msi.organization_id = 7;
                                            */

                                            SELECT DISTINCT xci.department
                                              INTO ln_details
                                              FROM apps.xxd_common_items_v xci, mtl_parameters mp
                                             WHERE     xci.inventory_item_id =
                                                       pn_inventory_item_id
                                                   AND xci.style_number =
                                                       pv_style
                                                   AND xci.organization_id =
                                                       mp.organization_id
                                                   AND mp.organization_code =
                                                       'MST';

                                            /*----------------------------------------------------------------------------------------------------
                                            End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                            ------------------------------------------------------------------------------------------------------*/
                                            RETURN ln_details;
                                        EXCEPTION
                                            WHEN NO_DATA_FOUND
                                            THEN
                                                ln_details   := 'NA';
                                            WHEN OTHERS
                                            THEN
                                                ln_details   := 'NA';
                                                RETURN ln_details;
                                        END;
                                    END IF;
                                ELSE
                                    IF pv_detail = 'SUB_GROUP'
                                    THEN
                                        IF pv_style = 'NA'
                                        THEN
                                            BEGIN
                                                ln_details   := NULL;

                                                /*------------------------------------------------------------------------------------------------
                                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                --------------------------------------------------------------------------------------------------
                                                                                    SELECT DISTINCT mcb.segment4
                                                                                               INTO ln_details
                                                                                               FROM apps.mtl_categories_b mcb,
                                                                                                    apps.mtl_item_categories mic,
                                                                                                    apps.mtl_system_items_b msi
                                                                                              WHERE mic.inventory_item_id =
                                                                                                         msi.inventory_item_id
                                                                                                AND mic.organization_id =
                                                                                                           msi.organization_id
                                                                                                AND mic.category_set_id = 1
                                                                                                AND mcb.category_id =
                                                                                                               mic.category_id
                                                                                                AND mcb.structure_id = 101
                                                                                                AND msi.inventory_item_id =
                                                                                                          pn_inventory_item_id
                                                                                                AND msi.organization_id = 7;
                                                */

                                                SELECT DISTINCT
                                                       xci.master_class
                                                  INTO ln_details
                                                  FROM apps.xxd_common_items_v xci, mtl_parameters mp
                                                 WHERE     xci.inventory_item_id =
                                                           pn_inventory_item_id
                                                       AND xci.organization_id =
                                                           mp.organization_id
                                                       AND mp.organization_code =
                                                           'MST';

                                                /*----------------------------------------------------------------------------------------------------
                                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                                ------------------------------------------------------------------------------------------------------*/

                                                RETURN ln_details;
                                            EXCEPTION
                                                WHEN NO_DATA_FOUND
                                                THEN
                                                    ln_details   := 'NA';
                                                WHEN OTHERS
                                                THEN
                                                    ln_details   := 'NA';
                                                    RETURN ln_details;
                                            END;
                                        ELSE
                                            BEGIN
                                                ln_details   := NULL;

                                                /*------------------------------------------------------------------------------------------------
                                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                --------------------------------------------------------------------------------------------------
                                                                                    SELECT DISTINCT mcb.segment4
                                                                                               INTO ln_details
                                                                                               FROM apps.mtl_categories_b mcb,
                                                                                                    apps.mtl_item_categories mic,
                                                                                                    apps.mtl_system_items_b msi
                                                                                              WHERE mic.inventory_item_id =
                                                                                                         msi.inventory_item_id
                                                                                                AND mic.organization_id =
                                                                                                           msi.organization_id
                                                                                                AND mic.category_set_id = 1
                                                                                                AND mcb.category_id =
                                                                                                               mic.category_id
                                                                                                AND mcb.structure_id = 101
                                                                                                AND msi.segment1 = pv_style
                                                                                                AND msi.organization_id = 7;
                                                */

                                                SELECT DISTINCT
                                                       xci.master_class
                                                  INTO ln_details
                                                  FROM apps.xxd_common_items_v xci, mtl_parameters mp
                                                 WHERE     xci.style_number =
                                                           pv_style
                                                       AND xci.inventory_item_id =
                                                           pn_inventory_item_id
                                                       AND xci.organization_id =
                                                           mp.organization_id
                                                       AND mp.organization_code =
                                                           'MST';

                                                /*----------------------------------------------------------------------------------------------------
                                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                                ------------------------------------------------------------------------------------------------------*/

                                                RETURN ln_details;
                                            EXCEPTION
                                                WHEN NO_DATA_FOUND
                                                THEN
                                                    ln_details   := 'NA';
                                                WHEN OTHERS
                                                THEN
                                                    ln_details   := 'NA';
                                                    RETURN ln_details;
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

        RETURN 'NA';
    END;

    /* Function Added by Srinath to fetch Po_number based on Factory Invoice number*/
    FUNCTION xxdo_get_po_num (pn_fty_invc_num IN VARCHAR2)
        RETURN VARCHAR2
    IS
        retval      VARCHAR2 (2000);
        ln_count    NUMBER;
        ln_count1   NUMBER;
        ln_count2   NUMBER;

        CURSOR c1 (pn_fty_invc_num VARCHAR2)
        IS
              SELECT poh.segment1 po_num
                FROM apps.po_headers_all poh, apps.po_lines_all pol, apps.rcv_shipment_headers rsh,
                     apps.rcv_shipment_lines rsl
               WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                     AND rsl.po_header_id = poh.po_header_id
                     AND rsl.po_line_id = pol.po_line_id
                     AND poh.po_header_id = pol.po_header_id
                     AND poh.org_id = pol.org_id
                     AND rsh.packing_slip = pn_fty_invc_num
            GROUP BY poh.segment1;

        CURSOR c2 (pn_fty_invc_num VARCHAR2)
        IS
              SELECT poh.segment1 po_num
                FROM apps.po_headers_all poh, apps.po_lines_all pol, apps.po_distributions_all pda,
                     apps.ap_invoices_all aia, apps.ap_invoice_distributions_all aida
               WHERE     poh.po_header_id = pol.po_header_id
                     AND poh.po_header_id = pda.po_header_id
                     AND pol.po_line_id = pda.po_line_id
                     AND aia.invoice_id = aida.invoice_id
                     AND aida.po_distribution_id = pda.po_distribution_id
                     AND poh.org_id = pol.org_id
                     AND aia.invoice_num = pn_fty_invc_num
                     AND NOT EXISTS
                             (SELECT 1
                                FROM rcv_shipment_headers
                               WHERE packing_slip = pn_fty_invc_num)
                     AND EXISTS
                             (SELECT 1
                                FROM apps.do_shipments
                               WHERE invoice_num = pn_fty_invc_num)
            GROUP BY poh.segment1;

        CURSOR c3 (pn_fty_invc_num VARCHAR2)
        IS
              SELECT poh.segment1 po_num
                FROM apps.po_headers_all poh, apps.po_lines_all pol, apps.po_distributions_all pda,
                     apps.ap_invoices_all aia, apps.ap_invoice_distributions_all aida
               WHERE     poh.po_header_id = pol.po_header_id
                     AND poh.po_header_id = pda.po_header_id
                     AND pol.po_line_id = pda.po_line_id
                     AND aia.invoice_id = aida.invoice_id
                     AND aida.po_distribution_id = pda.po_distribution_id
                     AND poh.org_id = pol.org_id
                     AND aia.invoice_num = pn_fty_invc_num
                     AND NOT EXISTS
                             (SELECT 1
                                FROM rcv_shipment_headers
                               WHERE packing_slip = pn_fty_invc_num)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.do_shipments
                               WHERE invoice_num = pn_fty_invc_num)
            GROUP BY poh.segment1;
    BEGIN
        SELECT COUNT (1)
          INTO ln_count
          FROM rcv_shipment_headers
         WHERE packing_slip = pn_fty_invc_num;

        IF ln_count > 0
        THEN
            retval   := NULL;

            FOR i IN c1 (pn_fty_invc_num)
            LOOP
                IF retval IS NULL
                THEN
                    retval   := i.po_num;
                ELSE
                    retval   := i.po_num || ' ' || ',' || retval;
                END IF;
            END LOOP;
        --return retval;
        ELSE
            SELECT COUNT (1)
              INTO ln_count1
              FROM apps.do_shipments
             WHERE     invoice_num = pn_fty_invc_num
                   AND NOT EXISTS
                           (SELECT 1
                              FROM apps.rcv_shipment_headers
                             WHERE     packing_slip = invoice_num
                                   AND packing_slip = pn_fty_invc_num);

            IF ln_count1 > 0
            THEN
                retval   := NULL;

                FOR j IN c2 (pn_fty_invc_num)
                LOOP
                    IF retval IS NULL
                    THEN
                        retval   := j.po_num;
                    ELSE
                        retval   := j.po_num || ' ' || ',' || retval;
                    END IF;
                END LOOP;
            ELSE
                SELECT COUNT (1)
                  INTO ln_count2
                  FROM apps.ap_invoices_all aia
                 WHERE     aia.invoice_num = pn_fty_invc_num
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM apps.rcv_shipment_headers
                                 WHERE     packing_slip = aia.invoice_num
                                       AND packing_slip = pn_fty_invc_num)
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM apps.do_shipments dos
                                 WHERE     dos.invoice_num = aia.invoice_num
                                       AND dos.invoice_num = pn_fty_invc_num);

                IF ln_count2 > 0
                THEN
                    retval   := NULL;

                    FOR k IN c3 (pn_fty_invc_num)
                    LOOP
                        IF retval IS NULL
                        THEN
                            retval   := k.po_num;
                        ELSE
                            retval   := k.po_num || ' ' || ',' || retval;
                        END IF;
                    END LOOP;
                END IF;
            END IF;
        END IF;

        RETURN retval;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            -- DBMS_OUTPUT.put_line ('In When No Data found exception '||sqlcode||sqlerrm);
            RETURN NULL;
        WHEN OTHERS
        THEN
            --DBMS_OUTPUT.put_line ('In When No Data found exception '||sqlcode||sqlerrm);
            RETURN NULL;
    END xxdo_get_po_num;

    PROCEDURE main (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER
                    , p_start_date IN VARCHAR2, p_end_date IN VARCHAR2)
    IS
        pv_po_num   VARCHAR2 (1000);

        CURSOR report_cur IS SELECT * FROM xxdo.xxdo_po_accrualproj;

        CURSOR fty_cost_center_cur IS
              SELECT po.fty_invc_num fty_invc_num, po.vendor_id vendor_id, po.organization_id organization_id,
                     rsh.ship_to_org_id ship_to_org_id
                FROM xxdo.xxdopo_accrual po, rcv_shipment_headers rsh
               WHERE     rsh.packing_slip = po.fty_invc_num
                     --and po.vendor_id = rsh.vendor_id
                     AND po.cost_center IS NULL
            GROUP BY po.fty_invc_num, po.vendor_id, po.organization_id,
                     rsh.ship_to_org_id;

        CURSOR fty_cost_center_inv_cur IS
              SELECT po.fty_invc_num fty_invc_num, po.vendor_id vendor_id, po.org_id org_id,
                     plla.ship_to_organization_id ship_to_org_id
                FROM xxdo.xxdopo_accrual po, po_headers_all poh, po_line_locations_all plla
               WHERE     po.po_num = poh.segment1
                     AND po.vendor_id = poh.vendor_id
                     AND poh.po_header_id = plla.po_header_id
                     AND po.cost_center IS NULL
                     AND UPPER (po.fty_invc_num) IN
                             (SELECT invoice_num FROM apps.do_shipments)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM rcv_shipment_headers rsh
                               WHERE     UPPER (rsh.packing_slip) =
                                         UPPER (po.fty_invc_num)
                                     AND rsh.ship_to_org_id =
                                         plla.ship_to_organization_id)
            GROUP BY po.fty_invc_num, po.vendor_id, po.org_id,
                     plla.ship_to_organization_id;

        CURSOR fty_cost_center_apinv_cur IS
              SELECT po.fty_invc_num fty_invc_num, po.vendor_id vendor_id, po.org_id org_id,
                     plla.ship_to_organization_id ship_to_org_id
                FROM xxdo.xxdopo_accrual po, ap_invoices_all aia, ap_invoice_distributions_all aid,
                     po_distributions_all pda, po_line_locations_all plla
               WHERE     po.fty_invc_num = aia.invoice_num
                     AND aia.invoice_id = aid.invoice_id
                     AND pda.po_distribution_id = aid.po_distribution_id
                     AND pda.line_location_id = plla.line_location_id
                     AND po.cost_center IS NULL
                     AND po.fty_invc_num NOT IN
                             (SELECT invoice_num
                                FROM apps.do_shipments
                               WHERE invoice_num IS NOT NULL)
                     AND po.fty_invc_num NOT IN
                             (SELECT packing_slip
                                FROM apps.rcv_shipment_headers
                               WHERE packing_slip IS NOT NULL)
            GROUP BY po.fty_invc_num, po.vendor_id, po.org_id,
                     plla.ship_to_organization_id;
    BEGIN
        DELETE FROM xxdo.xxdopo_accrual;

        DELETE FROM xxdo.xxdopo_fty;

        DELETE FROM xxdo.xxdopo_earlier_receipts;

        DELETE FROM xxdo.xxdoap_accrual;

        DELETE FROM xxdo.xxdoap_pre_accrual;

        DELETE FROM xxdo.xxdoinvc_aacrual;

        DELETE FROM xxdo.xxdo_po_accrualproj;

        fnd_file.put_line (fnd_file.LOG, '1');
        fnd_file.put_line (
            fnd_file.LOG,
            'p_start_date  :' || fnd_date.canonical_to_date (p_start_date));
        fnd_file.put_line (
            fnd_file.LOG,
            'p_end_date  :' || fnd_date.canonical_to_date (p_end_date));

        INSERT INTO xxdo.xxdopo_accrual (row_id, receipt_num, receipt_date,
                                         vendor_id, vendor, po_num,
                                         brand, style, color,
                                         inventory_item_id, received_qty, unit_price, received_value, fty_invc_num, sales_region, cost_center, country, org_id
                                         , organization_id, po_type)
            ---
            (  SELECT ROWNUM + NVL ((SELECT MAX (ROWNUM) FROM xxdo.xxdopo_accrual), 0), a.receipt_num, a.txn_date,
                      a.vendor_id, a.vendor, a.po_num,
                      a.brand, a.style, a.color,
                      a.inventory_item_id, SUM (a.quantity), a.unit_price,
                      SUM (a.quantity * a.unit_price), a.invoice, a.sales_region,
                      DECODE (NVL (TO_CHAR (a.cost_center), '1000'), '1000', a.org_cc, a.cost_center) cost_center, a.country, a.org_id,
                      a.organization_id, 'Received'
                 FROM (  SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                --mc.segment1 brand,
                                xci.brand
                                    brand,
                                /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                ven.vendor_id
                                    vendor_id,
                                ven.vendor_name
                                    vendor,
                                TO_CHAR (po.segment1)
                                    po_num,
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                            msi.segment1 style,
                                                            msi.segment2 color,
                                                             msi.segment3 size1,
                                                             msi.inventory_item_id,
                                */
                                xci.style_number
                                    style,
                                xci.color_code
                                    color,
                                xci.item_size,
                                xci.inventory_item_id,
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                rcv.organization_id
                                    inv_org,
                                rcv.transaction_type
                                    transaction_type,
                                SUM (ROUND (NVL (rcv.source_doc_quantity, 0)))
                                    quantity,
                                rcv.transaction_date
                                    txn_date,
                                TRUNC (rcv.creation_date)
                                    create_date,
                                flv.lookup_code
                                    sales_region,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT MAX (poda.req_distribution_id)
                                       FROM apps.po_distributions_all poda
                                      WHERE     poda.line_location_id =
                                                polla.line_location_id
                                            AND poda.po_line_id =
                                                polla.po_line_id),
                                    po.org_id,
                                    'SEG')
                                    cost_center,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT MAX (poda.req_distribution_id)
                                       FROM apps.po_distributions_all poda
                                      WHERE     poda.line_location_id =
                                                polla.line_location_id
                                            AND poda.po_line_id =
                                                polla.po_line_id),
                                    po.org_id,
                                    'COUNTRY')
                                    country-- ,decode(po.org_id,2,trim(rcv.attribute1),rsh.packing_slip) INVOICE
                                           -- ,decode(po.org_id,2,ship.invoice_num,rsh.packing_slip) INVOICE
                                           ,
                                DECODE (
                                    ship_vnt.invoice_num,
                                    NULL, DECODE (ship_dc1.invoice_num,
                                                  NULL, rsh.packing_slip,
                                                  ship_dc1.invoice_num),
                                    ship_vnt.invoice_num)
                                    invoice,
                                pol.unit_price,
                                rsh.receipt_num,
                                po.org_id,
                                rcv.organization_id,
                                (SELECT TO_CHAR (/*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                 -- gcc.segment2
                                                 gcc.segment5/* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                             )
                                   FROM mtl_parameters mp, apps.gl_code_combinations gcc
                                  WHERE     mp.organization_id =
                                            rcv.organization_id
                                        AND gcc.code_combination_id =
                                            mp.material_account)
                                    org_cc
                           -- ,polla.line_location_id
                           FROM custom.do_shipments ship_vnt, apps.do_shipments ship_dc1, apps.do_shipments ship_intl,
                                apps.rcv_transactions rcv, /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                                                           --apps.po_vendors ven,
                                                           apps.ap_suppliers ven, /* End changes by BT Technology Team on 15-JAN-2015  - V 1.1   */
                                                                                  apps.po_headers_all po,
                                apps.po_lines_all pol, apps.rcv_shipment_headers rsh, apps.po_line_locations_all polla,
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                             apps.mtl_system_items_b msi,
                                                             apps.mtl_item_categories mci,
                                                             apps.mtl_categories mc,
                                            */
                                apps.xxd_common_items_v xci, /*----------------------------------------------------------------------------------------------------
                                                             End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                                             ------------------------------------------------------------------------------------------------------*/
                                                             apps.mtl_parameters mp, apps.fnd_lookup_values flv
                          --where rcv.transaction_type in ( 'DELIVER','MATCH')
                          WHERE     rcv.transaction_type IN ('RECEIVE', 'MATCH')
                                AND flv.LANGUAGE = USERENV ('LANG')
                                AND rcv.source_document_code = 'PO'
                                AND rcv.organization_id =
                                    polla.ship_to_organization_id
                                AND rcv.vendor_id = ven.vendor_id
                                AND rcv.po_header_id = po.po_header_id
                                AND rcv.shipment_header_id =
                                    rsh.shipment_header_id
                                AND rcv.organization_id = mp.organization_id
                                AND pol.po_header_id = rcv.po_header_id
                                AND pol.po_line_id = rcv.po_line_id
                                AND pol.po_header_id = po.po_header_id
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                       AND msi.inventory_item_id = pol.item_id
                                                        AND pol.item_id = mci.inventory_item_id
                                                        AND mci.category_set_id = 1
                                                         AND mci.category_id = mc.category_id
                                                         AND mc.structure_id = 101
                                                         AND msi.organization_id = mci.organization_id
                                                         AND msi.organization_id = 7
                                */
                                AND xci.inventory_item_id = pol.item_id
                                AND pol.item_id = xci.inventory_item_id
                                AND xci.organization_id = mp.organization_id --and mp.organization_code='MST'
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                AND po.org_id = NVL (p_org_id, po.org_id)
                                AND polla.po_line_id = pol.po_line_id
                                AND polla.po_line_id = rcv.po_line_id
                                AND polla.line_location_id =
                                    rcv.po_line_location_id
                                AND flv.lookup_type = 'DO_SALES_REGIONS'
                                AND flv.lookup_code = mp.attribute1
                                -- and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship.shipment_id (+)
                                -- and decode(rcv.attribute1, NULL
                                -- ,substr(trim(rsh.shipment_num),1,instr(trim(rsh.shipment_num),'-',1) -1)
                                -- ,substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1)) = ship.shipment_id
                                AND SUBSTR (
                                        TRIM (rcv.attribute1),
                                        1,
                                        INSTR (TRIM (rcv.attribute1), '-', 1) - 1) =
                                    ship_intl.shipment_id(+)
                                AND SUBSTR (
                                        TRIM (rsh.shipment_num),
                                        1,
                                          INSTR (TRIM (rsh.shipment_num), '-', 1)
                                        - 1) =
                                    TO_CHAR (ship_dc1.shipment_id(+))
                                AND SUBSTR (
                                        TRIM (rcv.attribute1),
                                        1,
                                        INSTR (TRIM (rcv.attribute1), '-', 1) - 1) =
                                    ship_vnt.shipment_id(+)
                                AND rcv.transaction_date >=
                                    fnd_date.canonical_to_date (p_start_date)
                                AND rcv.transaction_date <
                                    fnd_date.canonical_to_date (p_end_date) + 1
                       GROUP BY TO_CHAR (po.segment1), ven.vendor_name, rcv.transaction_type,
                                rcv.transaction_date, TRUNC (rcv.creation_date), /*------------------------------------------------------------------------------------------------
                                                                                 Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                                                 --------------------------------------------------------------------------------------------------
                                                                                                              msi.segment1,
                                                                                                              msi.segment2,
                                                                                                              msi.segment3,
                                                                                 */
                                                                                 xci.style_number,
                                xci.color_code, xci.item_size, /*----------------------------------------------------------------------------------------------------
                                                               End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                                               ------------------------------------------------------------------------------------------------------*/
                                                               rcv.organization_id,
                                -- trim(rcv.attribute1),
                                --decode(po.org_id,2,ship.invoice_num,rsh.packing_slip),
                                ship_vnt.invoice_num, ship_dc1.invoice_num, ship_intl.invoice_num,
                                /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                -- mc.segment1,
                                xci.brand, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                           rsh.packing_slip, po.org_id,
                                pol.unit_price, polla.line_location_id, polla.po_line_id,
                                flv.lookup_code, rsh.receipt_num, /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                                  -- msi.inventory_item_id,
                                                                  xci.inventory_item_id,
                                /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                ven.vendor_id, rcv.organization_id
                       UNION
                         SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1*/
                                --mc.segment1 brand,
                                xci.brand
                                    brand,
                                /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                ven.vendor_id
                                    vendor_id,
                                ven.vendor_name
                                    vendor,
                                TO_CHAR (po.segment1)
                                    po_num,
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                             msi.segment1 style,
                                                             msi.segment2 color,
                                                             msi.segment3 size1,
                                                             msi.inventory_item_id,
                                */
                                xci.style_number
                                    style,
                                xci.color_code
                                    color,
                                xci.item_size,
                                xci.inventory_item_id,
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                rcv1.organization_id
                                    inv_org,
                                'DELIVER - CORRECT'
                                    transation_type,
                                SUM (ROUND (NVL (rcv1.source_doc_quantity, 0)))
                                    quantity,
                                rcv1.transaction_date
                                    txn_date,
                                TRUNC (rcv1.creation_date)
                                    create_date,
                                flv.lookup_code
                                    sales_region,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT MAX (req_distribution_id)
                                       FROM apps.po_distributions_all
                                      WHERE     line_location_id =
                                                polla.line_location_id
                                            AND po_line_id = polla.po_line_id),
                                    po.org_id,
                                    'SEG')
                                    cost_center,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT MAX (poda.req_distribution_id)
                                       FROM apps.po_distributions_all poda
                                      WHERE     poda.line_location_id =
                                                polla.line_location_id
                                            AND poda.po_line_id =
                                                polla.po_line_id),
                                    po.org_id,
                                    'COUNTRY')
                                    country-- ,decode(po.org_id,2,trim(rcv.attribute1),rsh.packing_slip) INVOICE
                                           -- ,decode(po.org_id,2,ship.invoice_num,rsh.packing_slip) INVOICE
                                           ,
                                rsh.packing_slip
                                    invoice,
                                pol.unit_price-- ,polla.line_location_id
                                              ,
                                rsh.receipt_num,
                                po.org_id,
                                rcv.organization_id,
                                (SELECT TO_CHAR (/*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1*/
                                                 --gcc.segment2
                                                 gcc.segment5/* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                             )
                                   FROM mtl_parameters mp, apps.gl_code_combinations gcc
                                  WHERE     mp.organization_id =
                                            rcv.organization_id
                                        AND gcc.code_combination_id =
                                            mp.material_account)
                                    org_cc
                           FROM --custom.do_shipments ship_vnt
                                --,custom.do_shipments ship_dc1
                                --,custom.do_shipments ship_intl
                                apps.rcv_transactions rcv1, apps.rcv_transactions rcv, /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                                                                                       -- apps.po_vendors ven,
                                                                                       apps.ap_suppliers ven,
                                /*End Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                                apps.po_headers_all po, apps.po_lines_all pol, apps.rcv_shipment_headers rsh,
                                apps.po_line_locations_all polla, /*------------------------------------------------------------------------------------------------
                                                                  Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                                  --------------------------------------------------------------------------------------------------
                                                                                               apps.mtl_system_items_b msi,
                                                                                               apps.mtl_item_categories mci,
                                                                                               apps.mtl_categories mc,
                                                                  */
                                                                  apps.xxd_common_items_v xci, /*----------------------------------------------------------------------------------------------------
                                                                                               End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                                                                               ------------------------------------------------------------------------------------------------------*/
                                                                                               apps.mtl_parameters mp,
                                apps.fnd_lookup_values flv
                          --where rcv.transaction_type in ( 'DELIVER' ,'MATCH')
                          WHERE     rcv.transaction_type IN ('RECEIVE', 'MATCH')
                                AND flv.LANGUAGE = USERENV ('LANG')
                                AND rcv.source_document_code = 'PO'
                                AND rcv1.transaction_type = 'CORRECT'
                                AND rcv1.parent_transaction_id =
                                    rcv.transaction_id
                                AND rcv.organization_id =
                                    polla.ship_to_organization_id
                                AND rcv.vendor_id = ven.vendor_id
                                AND rcv.po_header_id = po.po_header_id
                                AND rcv.shipment_header_id =
                                    rsh.shipment_header_id
                                AND rcv.organization_id = mp.organization_id
                                AND pol.po_header_id = rcv.po_header_id
                                AND pol.po_line_id = rcv.po_line_id
                                AND pol.po_header_id = po.po_header_id
                                /*------------------------------------------------------------------------------------------------
                               Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                               --------------------------------------------------------------------------------------------------
                                                        AND msi.inventory_item_id = pol.item_id
                                                        AND pol.item_id = mci.inventory_item_id
                                                        AND mci.category_set_id = 1
                                                        AND mci.category_id = mc.category_id
                                                        AND mc.structure_id = 101
                                                        AND msi.organization_id = mci.organization_id
                                                        AND msi.organization_id = 7

                               */
                                AND xci.inventory_item_id = pol.item_id
                                AND pol.item_id = xci.inventory_item_id
                                AND xci.organization_id = mp.organization_id --and mp.organization_code='MST'
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                AND po.org_id = NVL (p_org_id, po.org_id)
                                AND polla.po_line_id = pol.po_line_id
                                AND polla.po_line_id = rcv.po_line_id
                                AND polla.line_location_id =
                                    rcv.po_line_location_id
                                AND flv.lookup_type = 'DO_SALES_REGIONS'
                                AND flv.lookup_code = mp.attribute1
                                -- and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship.shipment_id (+)
                                -- and decode(rcv.attribute1, NULL
                                -- ,substr(trim(rsh.shipment_num),1,instr(trim(rsh.shipment_num),'-',1) -1)
                                -- ,substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1)) = ship.shipment_id
                                --rr--and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship_intl.shipment_id(+)
                                --and substr(trim(rsh.shipment_num),1,instr(trim(rsh.shipment_num),'-',1) -1) = ship_dc1.shipment_id(+)
                                --and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship_vnt.shipment_id(+)
                                AND rcv1.transaction_date >=
                                    fnd_date.canonical_to_date (p_start_date)
                                AND rcv1.transaction_date <
                                    fnd_date.canonical_to_date (p_end_date) + 1
                       GROUP BY TO_CHAR (po.segment1), ven.vendor_name, rcv1.transaction_date,
                                TRUNC (rcv1.creation_date), /*------------------------------------------------------------------------------------------------
                                                            Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                            --------------------------------------------------------------------------------------------------
                                                                                         msi.segment1,
                                                                                         msi.segment2,
                                                                                         msi.segment3,
                                                            */

                                                            xci.style_number, xci.color_code,
                                xci.item_size, /*----------------------------------------------------------------------------------------------------
                                               End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                               ------------------------------------------------------------------------------------------------------*/
                                               rcv1.organization_id, rcv.organization_id,
                                'DELIVER - CORRECT', -- trim(rcv.attribute1),
                                                     -- decode(po.org_id,2,ship.invoice_num,rsh.packing_slip),
                                                     --ship_vnt.invoice_num,
                                                     --ship_dc1.invoice_num,
                                                     --ship_intl.invoice_num,
                                                     /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1*/
                                                     --mc.segment1,
                                                     xci.brand, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                                rsh.packing_slip,
                                po.org_id, pol.unit_price, polla.line_location_id,
                                polla.po_line_id, flv.lookup_code, rsh.receipt_num,
                                /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1*/
                                -- msi.inventory_item_id,
                                xci.inventory_item_id, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1 */
                                                       ven.vendor_id, rcv.organization_id
                       UNION
                         SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                --mc.segment1 brand
                                xci.brand
                                    brand/* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                         ,
                                ven.vendor_id
                                    vendor_id,
                                ven.vendor_name
                                    vendor,
                                TO_CHAR (po.segment1)
                                    po_num,
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                             msi.segment1 style,
                                                             msi.segment2 color,
                                                             msi.segment3 size1,
                                                             msi.inventory_item_id,
                                */
                                xci.style_number
                                    style,
                                xci.color_code
                                    color,
                                xci.item_size
                                    size1,
                                xci.inventory_item_id,
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                rcv1.organization_id
                                    inv_org,
                                'RETURN TO VENDOR - CORRECT'
                                    transation_type,
                                SUM (ROUND (NVL (rcv1.source_doc_quantity, 0)))
                                    quantity,
                                rcv1.transaction_date
                                    txn_date,
                                TRUNC (rcv1.creation_date)
                                    create_date,
                                flv.lookup_code
                                    sales_region,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT MAX (req_distribution_id)
                                       FROM apps.po_distributions_all
                                      WHERE     line_location_id =
                                                polla.line_location_id
                                            AND po_line_id = polla.po_line_id),
                                    po.org_id,
                                    'SEG')
                                    cost_center,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT MAX (poda.req_distribution_id)
                                       FROM apps.po_distributions_all poda
                                      WHERE     poda.line_location_id =
                                                polla.line_location_id
                                            AND poda.po_line_id =
                                                polla.po_line_id),
                                    po.org_id,
                                    'COUNTRY')
                                    country-- ,decode(po.org_id,2,trim(rcv.attribute1),rsh.packing_slip) INVOICE
                                           -- ,decode(po.org_id,2,ship.invoice_num,rsh.packing_slip) INVOICE
                                           ,
                                rsh.packing_slip
                                    invoice,
                                pol.unit_price-- ,polla.line_location_id
                                              ,
                                rsh.receipt_num,
                                po.org_id,
                                rcv.organization_id,
                                (SELECT TO_CHAR (/*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                 --gcc.segment2
                                                 gcc.segment5/* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                             )
                                   FROM mtl_parameters mp, apps.gl_code_combinations gcc
                                  WHERE     mp.organization_id =
                                            rcv.organization_id
                                        AND gcc.code_combination_id =
                                            mp.material_account)
                                    org_cc
                           FROM --custom.do_shipments ship_vnt
                                --,custom.do_shipments ship_dc1
                                --,custom.do_shipments ship_intl,
                                apps.rcv_transactions rcv1, apps.rcv_transactions rcv, /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                                                       -- apps.po_vendors ven,
                                                                                       apps.ap_suppliers ven,
                                /*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                apps.po_headers_all po, apps.po_lines_all pol, apps.rcv_shipment_headers rsh,
                                apps.po_line_locations_all polla, /*------------------------------------------------------------------------------------------------
                                                                  Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                                  --------------------------------------------------------------------------------------------------
                                                                                               apps.mtl_system_items_b msi,
                                                                                               apps.mtl_item_categories mci,
                                                                                               apps.mtl_categories mc,
                                                                  */
                                                                  apps.xxd_common_items_v xci, /*----------------------------------------------------------------------------------------------------
                                                                                               End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                                                                               ------------------------------------------------------------------------------------------------------*/
                                                                                               apps.mtl_parameters mp,
                                apps.fnd_lookup_values flv
                          WHERE     rcv.transaction_type IN ('RETURN TO VENDOR')
                                AND flv.LANGUAGE = USERENV ('LANG')
                                AND rcv.source_document_code = 'PO'
                                AND rcv1.transaction_type = 'CORRECT'
                                AND rcv1.parent_transaction_id =
                                    rcv.transaction_id
                                AND rcv.organization_id =
                                    polla.ship_to_organization_id
                                AND rcv.vendor_id = ven.vendor_id
                                AND rcv.po_header_id = po.po_header_id
                                AND rcv.shipment_header_id =
                                    rsh.shipment_header_id
                                AND rcv.organization_id = mp.organization_id
                                AND pol.po_header_id = rcv.po_header_id
                                AND pol.po_line_id = rcv.po_line_id
                                AND pol.po_header_id = po.po_header_id
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                      AND msi.inventory_item_id = pol.item_id
                                                        AND pol.item_id = mci.inventory_item_id
                                                         AND mci.category_set_id = 1
                                                         AND mci.category_id = mc.category_id
                                                         AND mc.structure_id = 101
                                                         AND msi.organization_id = mci.organization_id
                                                         AND msi.organization_id = 7

                                */
                                AND xci.inventory_item_id = pol.item_id
                                AND pol.item_id = xci.inventory_item_id
                                AND xci.organization_id = mp.organization_id --and mp.organization_code='MST'
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                AND po.org_id = NVL (p_org_id, po.org_id)
                                AND polla.po_line_id = pol.po_line_id
                                AND polla.po_line_id = rcv.po_line_id
                                AND polla.line_location_id =
                                    rcv.po_line_location_id
                                AND flv.lookup_type = 'DO_SALES_REGIONS'
                                AND flv.lookup_code = mp.attribute1
                                -- and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship.shipment_id(+)
                                -- and decode(rcv.attribute1, NULL
                                -- ,substr(trim(rsh.shipment_num),1,instr(trim(rsh.shipment_num),'-',1) -1)
                                -- ,substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1)) = ship.shipment_id
                                --RR--and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship_intl.shipment_id(+)
                                --and substr(trim(rsh.shipment_num),1,instr(trim(rsh.shipment_num),'-',1) -1) = ship_dc1.shipment_id(+)
                                --and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship_vnt.shipment_id(+)
                                AND rcv1.transaction_date >=
                                    fnd_date.canonical_to_date (p_start_date)
                                AND rcv1.transaction_date <
                                    fnd_date.canonical_to_date (p_end_date) + 1
                       GROUP BY TO_CHAR (po.segment1), ven.vendor_name, rcv1.transaction_date,
                                TRUNC (rcv1.creation_date), /*------------------------------------------------------------------------------------------------
                                                            Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                            --------------------------------------------------------------------------------------------------
                                                                                         msi.segment1,
                                                                                         msi.segment2,
                                                                                         msi.segment3,
                                                            */
                                                            xci.style_number, xci.color_code,
                                xci.item_size, /*----------------------------------------------------------------------------------------------------
                                               End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                               ------------------------------------------------------------------------------------------------------*/
                                               rcv1.organization_id, rcv.organization_id,
                                'RETURN TO VENDOR - CORRECT', -- trim(rcv.attribute1),
                                                              -- decode(po.org_id,2,ship.invoice_num,rsh.packing_slip),
                                                              --RR--ship_vnt.invoice_num,
                                                              --ship_dc1.invoice_num,
                                                              --ship_intl.invoice_num,
                                                              /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                              -- mc.segment1,
                                                              xci.brand, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                                         rsh.packing_slip,
                                po.org_id, pol.unit_price, polla.line_location_id,
                                polla.po_line_id, flv.lookup_code, rsh.receipt_num,
                                /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                -- msi.inventory_item_id,
                                XCI.INVENTORY_ITEM_ID, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                       ven.vendor_id, rcv.organization_id)
                      a
             GROUP BY a.receipt_num, a.txn_date, a.vendor,
                      a.po_num, a.brand, a.style,
                      a.color, a.inventory_item_id, a.unit_price,
                      a.invoice, a.sales_region, a.cost_center,
                      a.org_cc, a.country, a.org_id,
                      a.organization_id, a.vendor_id, ROWNUM);

        fnd_file.put_line (fnd_file.LOG, '2');

        INSERT INTO xxdo.xxdopo_fty (--PO_NUM,
                                     invoice, vendor_id, org_id,
                                     TYPE)
            (SELECT DISTINCT --ship_vnto.segment1,
                             xa.fty_invc_num, xa.vendor_id, xa.org_id,
                             'FTY'
               FROM (SELECT DISTINCT xa.fty_invc_num, --to_char( xa.po_num) po_num,
                                                      xa.org_id, xa.vendor_id
                       FROM xxdo.xxdopo_accrual xa
                      WHERE xa.fty_invc_num IS NOT NULL) xa);

        fnd_file.put_line (fnd_file.LOG, '3');

        INSERT INTO xxdo.xxdopo_fty (--PO_NUM,
                                     invoice, org_id, vendor_id,
                                     TYPE)
            (  SELECT --poh.segment1 ,
                      ai.invoice_num, ai.org_id, ai.vendor_id,
                      'AP_PO'
                 FROM apps.ap_invoices_all ai, apps.ap_invoice_distributions_all aid
                WHERE     aid.po_distribution_id IS NOT NULL   -- is important
                      AND aid.invoice_id = ai.invoice_id
                      AND aid.line_type_lookup_code IN ('ACCRUAL', 'ITEM')
                      --                  AND UPPER (ai.invoice_num) not in
                      --                  (select distinct upper(xa.FTY_INVC_NUM) from xxdo.xxdopo_accrual xa where xa.FTY_INVC_NUM is not null)-- and upper(xa.FTY_INVC_NUM) = UPPER (ai.invoice_num) and
                      --                --  xa.org_id = ai.org_id and  xa.vendor_id = ai.vendor_id)
                      --                 AND UPPER (ai.invoice_num) not in
                      --                  (select upper(invoice)  from xxdopo_fty)
                      AND NOT EXISTS
                              (SELECT 1
                                 FROM xxdo.xxdopo_fty xf
                                WHERE     UPPER (ai.invoice_num) =
                                          UPPER (xf.invoice)
                                      AND xf.org_id = ai.org_id
                                      AND xf.vendor_id = ai.vendor_id--and xf.po_num = poh.segment1
                                                                     )
                      AND ai.org_id IN (  SELECT xa.org_id
                                            FROM xxdo.xxdopo_accrual xa
                                        GROUP BY xa.org_id)
                      AND aid.accounting_date >=
                          fnd_date.canonical_to_date (p_start_date)
                      AND aid.accounting_date <
                          fnd_date.canonical_to_date (p_end_date) + 1
                      AND aid.posted_flag = 'Y'
             GROUP BY ai.invoice_num, ai.org_id, ai.vendor_id);

        fnd_file.put_line (fnd_file.LOG, '4');

        INSERT INTO xxdo.xxdopo_fty (invoice, org_id, vendor_id,
                                     TYPE)
            (  SELECT ai.invoice_num, ai.org_id, ai.vendor_id,
                      'AP'
                 FROM apps.ap_invoices_all ai, apps.ap_invoice_distributions_all aid, /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                                                                                      --apps.po_vendors pov
                                                                                      apps.ap_suppliers pov
                /*End Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                WHERE     aid.invoice_id = ai.invoice_id
                      AND aid.line_type_lookup_code IN ('ACCRUAL', 'ITEM')
                      AND aid.po_distribution_id IS NULL
                      --                  AND UPPER (ai.invoice_num) not in
                      --                  (select distinct upper(xa.FTY_INVC_NUM) from xxdo.xxdopo_accrual xa where xa.FTY_INVC_NUM is not null)-- and upper(xa.FTY_INVC_NUM) = UPPER (ai.invoice_num) and
                      --                --  xa.org_id = ai.org_id and  xa.vendor_id = ai.vendor_id)
                      --                 AND UPPER (ai.invoice_num) not in
                      --                  (select upper(invoice)  from xxdopo_fty)
                      AND vendor_type_lookup_code LIKE 'MANUFACTURER'
                      AND pov.vendor_id = ai.vendor_id
                      AND NOT EXISTS
                              (SELECT 1
                                 FROM xxdo.xxdopo_fty xf
                                WHERE     UPPER (ai.invoice_num) =
                                          UPPER (xf.invoice)
                                      AND xf.org_id = ai.org_id
                                      AND xf.vendor_id = ai.vendor_id)
                      AND ai.org_id IN (  SELECT xa.org_id
                                            FROM xxdo.xxdopo_accrual xa
                                        GROUP BY xa.org_id)
                      AND aid.accounting_date >=
                          fnd_date.canonical_to_date (p_start_date)
                      AND aid.accounting_date <
                          fnd_date.canonical_to_date (p_end_date) + 1
                      AND aid.posted_flag = 'Y'
             GROUP BY ai.invoice_num, ai.org_id, ai.vendor_id);

        fnd_file.put_line (fnd_file.LOG, '5');

        INSERT INTO xxdo.xxdopo_earlier_receipts (receipt_num, receipt_date, vendor_id, vendor, po_num, brand, style, color, inventory_item_id, received_qty, unit_price, received_value, fty_invc_num, sales_region, cost_center
                                                  , country, org_id, po_type)
            (  SELECT a.receipt_num, a.txn_date, a.vendor_id,
                      a.vendor, a.po_num, a.brand,
                      a.style, a.color, a.inventory_item_id,
                      SUM (a.quantity), a.unit_price, SUM (a.quantity * a.unit_price),
                      a.invoice, a.sales_region, DECODE (NVL (TO_CHAR (a.cost_center), '1000'), '1000', a.org_cc, a.cost_center) cost_center,
                      a.country, a.org_id, 'Earlier Receipts'
                 FROM (  SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                --mc.segment1 brand
                                xci.brand
                                    brand/* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                         ,
                                ven.vendor_id
                                    vendor_id,
                                ven.vendor_name
                                    vendor,
                                TO_CHAR (po.segment1)
                                    po_num,
                                xci.style_number
                                    style,
                                xci.color_code
                                    color,
                                xci.item_size
                                    size1,
                                /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                -- msi.inventory_item_id,
                                xci.inventory_item_id,
                                /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                rcv.organization_id
                                    inv_org,
                                rcv.transaction_type
                                    transaction_type,
                                SUM (ROUND (NVL (rcv.source_doc_quantity, 0)))
                                    quantity,
                                rcv.transaction_date
                                    txn_date,
                                TRUNC (rcv.creation_date)
                                    create_date,
                                flv.lookup_code
                                    sales_region,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT req_distribution_id
                                       FROM apps.po_distributions_all
                                      WHERE     line_location_id =
                                                polla.line_location_id
                                            AND po_line_id = polla.po_line_id),
                                    po.org_id,
                                    'SEG')
                                    cost_center,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT req_distribution_id
                                       FROM apps.po_distributions_all
                                      WHERE     line_location_id =
                                                polla.line_location_id
                                            AND po_line_id = polla.po_line_id),
                                    po.org_id,
                                    'COUNTRY')
                                    country-- ,decode(po.org_id,2,trim(rcv.attribute1),rsh.packing_slip) INVOICE
                                           -- ,decode(po.org_id,2,ship.invoice_num,rsh.packing_slip) INVOICE
                                           ,
                                DECODE (
                                    ship_vnt.invoice_num,
                                    NULL, DECODE (ship_dc1.invoice_num,
                                                  NULL, rsh.packing_slip,
                                                  ship_dc1.invoice_num),
                                    ship_vnt.invoice_num)
                                    invoice,
                                pol.unit_price,
                                rsh.receipt_num,
                                po.org_id,
                                (SELECT TO_CHAR (/*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1*/
                                                 --gcc.segment2
                                                 gcc.segment5/* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                             )
                                   FROM mtl_parameters mp, apps.gl_code_combinations gcc
                                  WHERE     mp.organization_id =
                                            rcv.organization_id
                                        AND gcc.code_combination_id =
                                            mp.material_account)
                                    org_cc
                           -- ,polla.line_location_id
                           FROM custom.do_shipments ship_vnt,
                                apps.do_shipments ship_dc1,
                                apps.do_shipments ship_intl,
                                apps.rcv_transactions rcv,
                                /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                                -- apps.po_vendors ven,
                                apps.ap_suppliers ven,
                                /*End Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                                apps.po_headers_all po,
                                apps.po_lines_all pol,
                                apps.rcv_shipment_headers rsh,
                                apps.po_line_locations_all polla,
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------

                                                             apps.mtl_system_items_b msi,
                                                             apps.mtl_item_categories mci,
                                                             apps.mtl_categories mc,
                                */
                                apps.xxd_common_items_v xci,
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                apps.mtl_parameters mp,
                                apps.fnd_lookup_values flv,
                                (SELECT DISTINCT xa.invoice, xa.org_id, xa.vendor_id
                                   FROM xxdo.xxdopo_fty xa) xa
                          --where rcv.transaction_type in ( 'DELIVER','MATCH')
                          WHERE     rcv.transaction_type IN ('RECEIVE', 'MATCH')
                                AND flv.LANGUAGE = USERENV ('LANG')
                                AND rcv.source_document_code = 'PO'
                                AND rcv.organization_id =
                                    polla.ship_to_organization_id
                                AND rcv.vendor_id = ven.vendor_id
                                AND rcv.vendor_id = xa.vendor_id
                                AND rcv.po_header_id = po.po_header_id
                                AND rcv.shipment_header_id =
                                    rsh.shipment_header_id
                                AND rcv.organization_id = mp.organization_id
                                AND pol.po_header_id = rcv.po_header_id
                                AND pol.po_line_id = rcv.po_line_id
                                AND pol.po_header_id = po.po_header_id
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                        AND msi.inventory_item_id = pol.item_id
                                                         AND pol.item_id = mci.inventory_item_id
                                                         AND mci.category_set_id = 1
                                                         AND mci.category_id = mc.category_id
                                                         AND mc.structure_id = 101
                                                         AND msi.organization_id = mci.organization_id
                                                         AND msi.organization_id = 7
                                 */
                                AND xci.inventory_item_id = pol.item_id
                                AND pol.item_id = xci.inventory_item_id
                                AND xci.organization_id = mp.organization_id
                                AND mp.organization_code = 'MST'
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                AND po.org_id = xa.org_id
                                AND po.org_id = NVL (p_org_id, po.org_id)
                                --and pol.item_id = xa.inventory_item_id
                                --and po.segment1 = xa.po_num
                                AND xa.invoice =
                                    DECODE (
                                        ship_vnt.invoice_num,
                                        NULL, DECODE (ship_dc1.invoice_num,
                                                      NULL, rsh.packing_slip,
                                                      ship_dc1.invoice_num),
                                        ship_vnt.invoice_num)
                                AND po.type_lookup_code = 'STANDARD'
                                AND polla.po_line_id = pol.po_line_id
                                AND polla.po_line_id = rcv.po_line_id
                                AND polla.line_location_id =
                                    rcv.po_line_location_id
                                AND flv.lookup_type = 'DO_SALES_REGIONS'
                                AND flv.lookup_code = mp.attribute1
                                AND SUBSTR (
                                        TRIM (rcv.attribute1),
                                        1,
                                        INSTR (TRIM (rcv.attribute1), '-', 1) - 1) =
                                    ship_intl.shipment_id(+)
                                AND SUBSTR (
                                        TRIM (rsh.shipment_num),
                                        1,
                                          INSTR (TRIM (rsh.shipment_num), '-', 1)
                                        - 1) =
                                    TO_CHAR (ship_dc1.shipment_id(+))
                                AND SUBSTR (
                                        TRIM (rcv.attribute1),
                                        1,
                                        INSTR (TRIM (rcv.attribute1), '-', 1) - 1) =
                                    ship_vnt.shipment_id(+)
                                AND rcv.transaction_date <
                                    fnd_date.canonical_to_date (p_start_date)
                                AND rcv.transaction_date >
                                      fnd_date.canonical_to_date (p_start_date)
                                    - 365
                       GROUP BY TO_CHAR (po.segment1), ven.vendor_name, rcv.transaction_type,
                                rcv.transaction_date, TRUNC (rcv.creation_date), /*------------------------------------------------------------------------------------------------
                                                                                 Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                                                 --------------------------------------------------------------------------------------------------
                                                                                                              msi.segment1,
                                                                                                              msi.segment2,
                                                                                                              msi.segment3,
                                                                                 */

                                                                                 xci.style_number,
                                xci.color_code, xci.item_size, /*----------------------------------------------------------------------------------------------------
                                                               End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                                               ------------------------------------------------------------------------------------------------------*/
                                                               rcv.organization_id,
                                -- trim(rcv.attribute1),
                                --decode(po.org_id,2,ship.invoice_num,rsh.packing_slip),
                                ship_vnt.invoice_num, ship_dc1.invoice_num, ship_intl.invoice_num,
                                /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1*/
                                --mc.segment1,
                                xci.brand, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                           rsh.packing_slip, po.org_id,
                                pol.unit_price, polla.line_location_id, polla.po_line_id,
                                flv.lookup_code, rsh.receipt_num, /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                                  --msi.inventory_item_id,
                                                                  xci.inventory_item_id,
                                /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                ven.vendor_id
                       UNION
                         SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                --mc.segment1 brand
                                xci.brand
                                    brand,
                                /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                ven.vendor_id
                                    vendor_id,
                                ven.vendor_name
                                    vendor,
                                TO_CHAR (po.segment1)
                                    po_num,
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                             msi.segment1 style,
                                                             msi.segment2 color,
                                                             msi.segment3 size1,
                                                             msi.inventory_item_id,
                                */

                                xci.style_number
                                    style,
                                xci.color_code
                                    color,
                                xci.item_size,
                                xci.inventory_item_id,
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                rcv1.organization_id
                                    inv_org,
                                'DELIVER - CORRECT'
                                    transation_type,
                                SUM (ROUND (NVL (rcv1.source_doc_quantity, 0)))
                                    quantity,
                                rcv1.transaction_date
                                    txn_date,
                                TRUNC (rcv1.creation_date)
                                    create_date,
                                flv.lookup_code
                                    sales_region,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT req_distribution_id
                                       FROM apps.po_distributions_all
                                      WHERE     line_location_id =
                                                polla.line_location_id
                                            AND po_line_id = polla.po_line_id),
                                    po.org_id,
                                    'SEG')
                                    cost_center,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT req_distribution_id
                                       FROM apps.po_distributions_all
                                      WHERE     line_location_id =
                                                polla.line_location_id
                                            AND po_line_id = polla.po_line_id),
                                    po.org_id,
                                    'COUNTRY')
                                    country,
                                rsh.packing_slip
                                    invoice,
                                pol.unit_price-- ,polla.line_location_id
                                              ,
                                rsh.receipt_num,
                                po.org_id,
                                (SELECT TO_CHAR (/*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1*/
                                                 -- gcc.segment2
                                                 gcc.segment5/* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                             )
                                   FROM mtl_parameters mp, apps.gl_code_combinations gcc
                                  WHERE     mp.organization_id =
                                            rcv.organization_id
                                        AND gcc.code_combination_id =
                                            mp.material_account)
                                    org_cc
                           FROM --custom.do_shipments ship_vnt
                                --,custom.do_shipments ship_dc1
                                --,custom.do_shipments ship_intl
                                apps.rcv_transactions rcv1,
                                apps.rcv_transactions rcv,
                                /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                --apps.po_vendors ven,
                                apps.ap_suppliers ven,
                                /*End  Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                apps.po_headers_all po,
                                apps.po_lines_all pol,
                                apps.rcv_shipment_headers rsh,
                                apps.po_line_locations_all polla,
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                             apps.mtl_system_items_b msi,
                                                             apps.mtl_item_categories mci,
                                                             apps.mtl_categories mc,
                                */
                                apps.xxd_common_items_v xci,
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                apps.mtl_parameters mp,
                                apps.fnd_lookup_values flv,
                                (SELECT DISTINCT xa.invoice, xa.org_id, xa.vendor_id
                                   FROM xxdo.xxdopo_fty xa) xa
                          --where rcv.transaction_type in ( 'DELIVER' ,'MATCH')
                          WHERE     rcv.transaction_type IN ('RECEIVE', 'MATCH')
                                AND flv.LANGUAGE = USERENV ('LANG')
                                AND rcv.source_document_code = 'PO'
                                AND rcv1.transaction_type = 'CORRECT'
                                AND rcv1.parent_transaction_id =
                                    rcv.transaction_id
                                AND rcv.organization_id =
                                    polla.ship_to_organization_id
                                AND rcv1.vendor_id = ven.vendor_id
                                AND rcv1.vendor_id = xa.vendor_id
                                AND rcv.po_header_id = po.po_header_id
                                AND rcv.shipment_header_id =
                                    rsh.shipment_header_id
                                AND rcv.organization_id = mp.organization_id
                                AND pol.po_header_id = rcv.po_header_id
                                AND pol.po_line_id = rcv.po_line_id
                                AND pol.po_header_id = po.po_header_id
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                        AND pol.item_id = mci.inventory_item_id
                                                         AND msi.inventory_item_id = pol.item_id
                                                         AND mci.category_set_id = 1
                                                         AND mci.category_id = mc.category_id
                                                         AND mc.structure_id = 101
                                                         AND msi.organization_id = mci.organization_id
                                                         AND msi.organization_id = 7
                                */
                                AND xci.inventory_item_id = pol.item_id
                                AND pol.item_id = xci.inventory_item_id
                                AND xci.organization_id = mp.organization_id
                                AND mp.organization_code = 'MST'
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                AND polla.po_line_id = pol.po_line_id
                                AND polla.po_line_id = rcv.po_line_id
                                AND polla.line_location_id =
                                    rcv.po_line_location_id
                                AND flv.lookup_type = 'DO_SALES_REGIONS'
                                AND flv.lookup_code = mp.attribute1
                                -- and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship.shipment_id (+)
                                -- and decode(rcv.attribute1, NULL
                                -- ,substr(trim(rsh.shipment_num),1,instr(trim(rsh.shipment_num),'-',1) -1)
                                -- ,substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1)) = ship.shipment_id
                                --RR--and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship_intl.shipment_id(+)
                                --and substr(trim(rsh.shipment_num),1,instr(trim(rsh.shipment_num),'-',1) -1) = to_char(ship_dc1.shipment_id(+))
                                --and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship_vnt.shipment_id(+)
                                AND rcv.transaction_date <
                                    fnd_date.canonical_to_date (p_start_date)
                                AND rcv.transaction_date >
                                      fnd_date.canonical_to_date (p_start_date)
                                    - 365
                                AND po.org_id = xa.org_id
                                AND po.org_id = NVL (p_org_id, po.org_id)
                                --and pol.item_id = xa.inventory_item_id
                                --and po.segment1 = xa.po_num
                                AND xa.invoice = rsh.packing_slip
                                AND po.type_lookup_code = 'STANDARD'
                       GROUP BY TO_CHAR (po.segment1), ven.vendor_name, rcv1.transaction_date,
                                TRUNC (rcv1.creation_date), /*------------------------------------------------------------------------------------------------
                                                            Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                            --------------------------------------------------------------------------------------------------
                                                                                         msi.segment1,
                                                                                         msi.segment2,
                                                                                         msi.segment3,
                                                            */

                                                            xci.style_number, xci.color_code,
                                xci.item_size, /*----------------------------------------------------------------------------------------------------
                                               End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                               ------------------------------------------------------------------------------------------------------*/
                                               rcv1.organization_id, rcv.organization_id,
                                'DELIVER - CORRECT', -- trim(rcv.attribute1),
                                                     -- decode(po.org_id,2,ship.invoice_num,rsh.packing_slip),
                                                     --RR--ship_vnt.invoice_num,
                                                     --ship_dc1.invoice_num,
                                                     --ship_intl.invoice_num,
                                                     /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1   */
                                                     --   mc.segment1,
                                                     xci.brand, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                                rsh.packing_slip,
                                po.org_id, pol.unit_price, polla.line_location_id,
                                polla.po_line_id, flv.lookup_code, rsh.receipt_num,
                                /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                --msi.inventory_item_id,
                                xci.inventory_item_id, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                       ven.vendor_id
                       UNION
                         SELECT /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                --   mc.segment1 brand
                                xci.brand
                                    brand/* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                         ,
                                ven.vendor_id
                                    vendor_id,
                                ven.vendor_name
                                    vendor,
                                TO_CHAR (po.segment1)
                                    po_num,
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                             msi.segment1 style,
                                                             msi.segment2 color,
                                                             msi.segment3 size1,
                                                             msi.inventory_item_id,
                                */

                                xci.style_number
                                    style,
                                xci.color_code
                                    color,
                                xci.item_size,
                                xci.inventory_item_id,
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                rcv1.organization_id
                                    inv_org,
                                'RETURN TO VENDOR - CORRECT'
                                    transation_type,
                                SUM (ROUND (NVL (rcv1.source_doc_quantity, 0)))
                                    quantity,
                                TRUNC (rcv1.transaction_date)
                                    txn_date,
                                TRUNC (rcv1.creation_date)
                                    create_date,
                                flv.lookup_code
                                    sales_region,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT req_distribution_id
                                       FROM apps.po_distributions_all
                                      WHERE     line_location_id =
                                                polla.line_location_id
                                            AND po_line_id = polla.po_line_id),
                                    po.org_id,
                                    'SEG')
                                    cost_center,
                                xxdo_ap_req_accrual_upd_pkg.get_accrual_seg (
                                    (SELECT req_distribution_id
                                       FROM apps.po_distributions_all
                                      WHERE     line_location_id =
                                                polla.line_location_id
                                            AND po_line_id = polla.po_line_id),
                                    po.org_id,
                                    'COUNTRY')
                                    country-- ,decode(po.org_id,2,trim(rcv.attribute1),rsh.packing_slip) INVOICE
                                           -- ,decode(po.org_id,2,ship.invoice_num,rsh.packing_slip) INVOICE
                                           ,
                                rsh.packing_slip
                                    invoice,
                                pol.unit_price,
                                rsh.receipt_num,
                                po.org_id,
                                (SELECT TO_CHAR (/*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1  */
                                                 --     gcc.segment2
                                                 gcc.segment5/* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                             )
                                   FROM mtl_parameters mp, apps.gl_code_combinations gcc
                                  WHERE     mp.organization_id =
                                            rcv.organization_id
                                        AND gcc.code_combination_id =
                                            mp.material_account)
                                    org_cc
                           FROM --custom.do_shipments ship_vnt
                                --,custom.do_shipments ship_dc1
                                --,custom.do_shipments ship_intl
                                apps.rcv_transactions rcv1,
                                apps.rcv_transactions rcv,
                                /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                                -- apps.po_vendors ven,
                                apps.ap_suppliers ven,
                                /*End Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                                apps.po_headers_all po,
                                apps.po_lines_all pol,
                                apps.rcv_shipment_headers rsh,
                                apps.po_line_locations_all polla,
                                /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                             apps.mtl_system_items_b msi,
                                                             apps.mtl_item_categories mci,
                                                             apps.mtl_categories mc,
                                */
                                apps.xxd_common_items_v xci,
                                /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                apps.mtl_parameters mp,
                                apps.fnd_lookup_values flv,
                                (SELECT DISTINCT xa.invoice, xa.org_id, xa.vendor_id
                                   FROM xxdo.xxdopo_fty xa) xa
                          WHERE     rcv.transaction_type IN ('RETURN TO VENDOR')
                                AND flv.LANGUAGE = USERENV ('LANG')
                                AND rcv.source_document_code = 'PO'
                                AND rcv1.transaction_type = 'CORRECT'
                                AND rcv1.parent_transaction_id =
                                    rcv.transaction_id
                                AND rcv.organization_id =
                                    polla.ship_to_organization_id
                                AND rcv1.vendor_id = ven.vendor_id
                                AND rcv1.vendor_id = xa.vendor_id
                                AND rcv.po_header_id = po.po_header_id
                                AND rcv.shipment_header_id =
                                    rsh.shipment_header_id
                                AND rcv.organization_id = mp.organization_id
                                AND pol.po_header_id = rcv.po_header_id
                                AND pol.po_line_id = rcv.po_line_id
                                AND pol.po_header_id = po.po_header_id
                                /*------------------------------------------------------------------------------------------------
                                Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                --------------------------------------------------------------------------------------------------
                                                        AND pol.item_id = mci.inventory_item_id
                                                        AND msi.inventory_item_id = pol.item_id
                                                         AND mci.category_set_id = 1
                                                         AND mci.category_id = mc.category_id
                                                         AND mc.structure_id = 101
                                                         AND msi.organization_id = mci.organization_id
                                                         AND msi.organization_id = 7
                                */
                                AND pol.item_id = xci.inventory_item_id
                                AND xci.inventory_item_id = pol.item_id
                                AND xci.organization_id = mp.organization_id
                                AND mp.organization_code = 'MST'
                                /*----------------------------------------------------------------------------------------------------
                                End changes by BT Technology Team on 12-DEC-2014  - V 1.1
                                ------------------------------------------------------------------------------------------------------*/
                                AND polla.po_line_id = pol.po_line_id
                                AND polla.po_line_id = rcv.po_line_id
                                AND polla.line_location_id =
                                    rcv.po_line_location_id
                                AND flv.lookup_type = 'DO_SALES_REGIONS'
                                AND flv.lookup_code = mp.attribute1
                                -- and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship.shipment_id(+)
                                -- and decode(rcv.attribute1, NULL
                                -- ,substr(trim(rsh.shipment_num),1,instr(trim(rsh.shipment_num),'-',1) -1)
                                -- ,substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1)) = ship.shipment_id
                                --rr--and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship_intl.shipment_id(+)
                                --and substr(trim(rsh.shipment_num),1,instr(trim(rsh.shipment_num),'-',1) -1) = ship_dc1.shipment_id(+)
                                --and substr(trim(rcv.attribute1),1,instr(trim(rcv.attribute1),'-',1) -1) = ship_vnt.shipment_id(+)
                                AND rcv.transaction_date <
                                    fnd_date.canonical_to_date (p_start_date)
                                AND rcv.transaction_date >
                                      fnd_date.canonical_to_date (p_start_date)
                                    - 365
                                AND po.org_id = xa.org_id
                                AND po.org_id = NVL (p_org_id, po.org_id)
                                --and pol.item_id = xa.inventory_item_id
                                --and po.segment1 = xa.po_num
                                AND xa.invoice = rsh.packing_slip
                                AND po.type_lookup_code = 'STANDARD'
                       GROUP BY TO_CHAR (po.segment1), ven.vendor_name, TRUNC (rcv1.transaction_date),
                                TRUNC (rcv1.creation_date), /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1
                                                                                         msi.segment1,
                                                                                         msi.segment2,
                                                                                         msi.segment3,
                                                            */

                                                            xci.style_number, xci.color_code,
                                xci.item_size, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                               rcv1.organization_id, rcv.organization_id,
                                'RETURN TO VENDOR - CORRECT', -- trim(rcv.attribute1),
                                                              -- decode(po.org_id,2,ship.invoice_num,rsh.packing_slip),
                                                              --rr--ship_vnt.invoice_num,
                                                              --ship_dc1.invoice_num,
                                                              --ship_intl.invoice_num,
                                                              /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1  */
                                                              --  mc.segment1,
                                                              xci.brand, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                                         rsh.packing_slip,
                                po.org_id, pol.unit_price, polla.line_location_id,
                                polla.po_line_id, flv.lookup_code, rsh.receipt_num,
                                /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                -- msi.inventory_item_id,
                                xci.inventory_item_id, /* End changes by BT Technology Team on 12-DEC-2014  - V 1.1   */
                                                       ven.vendor_id) a
             GROUP BY a.receipt_num, a.txn_date, a.vendor,
                      a.po_num, a.brand, a.style,
                      a.color, a.inventory_item_id, a.unit_price,
                      a.invoice, a.sales_region, a.cost_center,
                      a.org_cc, a.country, a.org_id,
                      a.vendor_id);

        fnd_file.put_line (fnd_file.LOG, '6');

        UPDATE xxdo.xxdopo_earlier_receipts xer
           SET current_month   = 'Y'
         WHERE     EXISTS
                       (SELECT 1
                          FROM xxdo.xxdopo_accrual xa
                         WHERE     xer.inventory_item_id =
                                   xa.inventory_item_id
                               --and  xer.po_num = xa.po_num
                               AND xer.fty_invc_num = xa.fty_invc_num
                               AND xer.org_id = xa.org_id
                               AND xer.vendor_id = xa.vendor_id)
               AND current_month IS NULL;

        fnd_file.put_line (fnd_file.LOG, '7');

        UPDATE xxdo.xxdopo_accrual xa
           SET recvd_earlier   =
                   (  SELECT SUM (xer.received_qty)
                        FROM xxdo.xxdopo_earlier_receipts xer
                       WHERE     xer.inventory_item_id = xa.inventory_item_id
                             --and  xer.po_num = xa.po_num
                             AND xer.fty_invc_num = xa.fty_invc_num
                             AND xer.org_id = xa.org_id
                             AND xer.vendor_id = xa.vendor_id
                             AND current_month IS NOT NULL
                    GROUP BY inventory_item_id, fty_invc_num, xer.vendor_id,
                             xer.org_id)                           --, po_num)
         WHERE     xa.row_id =
                   (  SELECT MAX (row_id)
                        FROM xxdo.xxdopo_accrual xa1
                       WHERE     UPPER (xa1.fty_invc_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xa1.inventory_item_id = xa.inventory_item_id
                             AND xa1.org_id = xa.org_id
                             AND xa1.po_type = xa.po_type
                             -- and xa1.PO_num = xa.po_num
                             AND xa1.vendor_id = xa.vendor_id
                    GROUP BY xa1.inventory_item_id, xa1.fty_invc_num, xa1.vendor_id,
                             xa1.org_id)
               AND EXISTS
                       (SELECT 1
                          FROM xxdo.xxdopo_earlier_receipts xer
                         WHERE     xer.inventory_item_id =
                                   xa.inventory_item_id
                               --and  xer.po_num = xa.po_num
                               AND xer.fty_invc_num = xa.fty_invc_num
                               AND xer.org_id = xa.org_id
                               AND xer.vendor_id = xa.vendor_id
                               AND current_month IS NOT NULL)
               AND recvd_earlier IS NULL;

        fnd_file.put_line (fnd_file.LOG, '7');

        INSERT INTO xxdo.xxdopo_accrual (row_id, vendor_id, vendor,
                                         po_num, brand, style,
                                         color, inventory_item_id, recvd_earlier, unit_price, recvd_earlier_value, fty_invc_num, sales_region, cost_center, country
                                         , org_id, po_type)
            (  SELECT ROWNUM + (SELECT MAX (row_id) FROM xxdo.xxdopo_accrual), a.vendor_id, a.vendor,
                      a.po_num, a.brand, a.style,
                      a.color, a.inventory_item_id, SUM (a.received_qty),
                      a.unit_price, SUM (a.received_qty * a.unit_price), a.fty_invc_num,
                      a.sales_region, a.cost_center, a.country,
                      a.org_id, 'Received Earlier'
                 FROM xxdo.xxdopo_earlier_receipts a
                WHERE a.current_month IS NULL
             GROUP BY a.vendor_id, a.vendor, a.po_num,
                      a.brand, a.style, a.color,
                      a.inventory_item_id, a.unit_price, a.fty_invc_num,
                      a.sales_region, a.cost_center, a.country,
                      a.org_id, ROWNUM);

        fnd_file.put_line (fnd_file.LOG, '8');

        INSERT INTO xxdo.xxdoap_accrual (vendor_id, vendor, invoice_num,
                                         invoice_date, inventory_item_id, quantity_invoiced, unit_price, ext_value, invoice_amount, payment_date, org_id, ap_type
                                         , po_num)
            (  SELECT ai.vendor_id
                          vendor_id,
                      v.vendor_name
                          vendor,
                      ai.invoice_num,
                      ai.invoice_date,
                      -- aid.invoice_distribution_id,
                      pol.item_id
                          inventory_item_id,
                      SUM (aid.quantity_invoiced)
                          quantity_invoiced,
                      NVL (aid.unit_price, 1)
                          unit_price,
                      SUM (NVL (aid.unit_price, 1) * aid.quantity_invoiced)
                          ext_value,
                      ai.invoice_amount,
                      (SELECT MAX (aip.accounting_date)
                         FROM apps.ap_invoice_payments_all aip
                        WHERE     ai.invoice_id = aip.invoice_id
                              AND aip.accounting_date <
                                  fnd_date.canonical_to_date (p_end_date) + 1)
                          payment_date,
                      ai.org_id,
                      (CASE
                           WHEN EXISTS
                                    (SELECT 1
                                       FROM xxdo.xxdopo_accrual xaa
                                      WHERE     xaa.fty_invc_num =
                                                ai.invoice_num
                                            AND xaa.org_id = ai.org_id
                                            AND ai.vendor_id = xaa.vendor_id)
                           THEN
                               'Received'
                           ELSE
                               'Not Received'
                       END)
                          ap_type,
                      poh.segment1
                          po_num
                 FROM apps.ap_invoices_all ai,
                      apps.ap_invoice_distributions_all aid,
                      apps.po_headers_all poh,
                      apps.po_lines_all pol,
                      apps.po_distributions_all pod,
                      --  (select distinct xa.FTY_INVC_NUM,  xa.org_id, xa.vendor_id from xxdo.xxdopo_accrual xa) xa,
                      (  SELECT xa.invoice, xa.org_id, xa.vendor_id
                           FROM xxdo.xxdopo_fty xa
                       GROUP BY xa.invoice, xa.org_id, xa.vendor_id) xa,
                      /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                      --apps.po_vendors v
                      apps.ap_suppliers v
                /*End Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                WHERE     pod.po_header_id = pod.po_header_id
                      AND pod.po_line_id = pol.po_line_id
                      AND ai.vendor_id = v.vendor_id
                      AND pol.po_header_id = poh.po_header_id
                      AND aid.po_distribution_id = pod.po_distribution_id
                      AND aid.invoice_id = ai.invoice_id
                      AND aid.line_type_lookup_code IN ('ACCRUAL', 'ITEM')
                      AND UPPER (ai.invoice_num) = UPPER (xa.invoice)
                      AND xa.org_id = ai.org_id
                      AND ai.vendor_id = xa.vendor_id
                      AND aid.accounting_date <
                          fnd_date.canonical_to_date (p_end_date) + 1
                      AND aid.posted_flag = 'Y'
                      AND NOT EXISTS
                              (SELECT 1
                                 FROM xxdo.xxdoap_accrual xaa
                                WHERE     xaa.invoice_num = ai.invoice_num
                                      AND xaa.org_id = ai.org_id
                                      AND ai.vendor_id = xaa.vendor_id)
             GROUP BY ai.invoice_num, pol.item_id, aid.unit_price,
                      ai.invoice_date, ai.invoice_amount, ai.invoice_id,
                      ai.org_id, poh.segment1, v.vendor_name,
                      ai.vendor_id);

        fnd_file.put_line (fnd_file.LOG, '8');

        UPDATE xxdo.xxdopo_accrual xa
           SET fty_invc_num_in_ap   =
                   (SELECT DISTINCT invoice_num
                      FROM xxdo.xxdoap_accrual xaa
                     WHERE     UPPER (xaa.invoice_num) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.inventory_item_id = xa.inventory_item_id
                           AND xaa.org_id = xa.org_id
                           -- and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id--and xaa.PO_num = xa.po_num
                                                           ),
               invc_qty   =
                   (  SELECT SUM (quantity_invoiced)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             AND xaa.org_id = xa.org_id
                             -- and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    -- and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.inventory_item_id, xaa.org_id,
                             xaa.vendor_id                      --, xaa.PO_num
                                          ),
               unit_price_per_invoice   =
                   (  SELECT ROUND ((SUM (xaa.ext_value) / SUM (quantity_invoiced)), 2)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             AND xaa.org_id = xa.org_id
                             --  and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --   and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.inventory_item_id, xaa.org_id,
                             xaa.vendor_id                      --, xaa.PO_num
                                          ),
               invoice_value   =
                   (  SELECT SUM (xaa.ext_value)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             AND xaa.org_id = xa.org_id
                             --and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --  and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.inventory_item_id, xaa.org_id,
                             xaa.vendor_id                      --, xaa.PO_num
                                          ),
               payment_date   =
                   (  SELECT MAX (xaa.payment_date)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             AND xaa.org_id = xa.org_id
                             --   and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --   and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.inventory_item_id, xaa.org_id,
                             xaa.vendor_id                      --, xaa.PO_num
                                          ),
               total_invoice_amount   =
                   (SELECT DISTINCT (invoice_amount)
                      FROM xxdo.xxdoap_accrual xaa
                     WHERE     UPPER (xaa.invoice_num) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.inventory_item_id = xa.inventory_item_id
                           AND xaa.org_id = xa.org_id
                           --  and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id-- and xaa.PO_num = xa.po_num
                                                           )
         WHERE     xa.row_id =
                   (  SELECT MAX (row_id)
                        FROM xxdo.xxdopo_accrual xa1
                       WHERE     UPPER (xa1.fty_invc_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xa1.inventory_item_id = xa.inventory_item_id
                             AND xa1.org_id = xa.org_id
                             -- and xa1.po_type = xa.po_type
                             AND xa1.vendor_id = xa.vendor_id
                    -- and xa1.PO_num = xa.po_num
                    GROUP BY xa1.fty_invc_num, xa1.inventory_item_id, xa1.org_id,
                             xa1.vendor_id                      --, xaa.PO_num
                                          )
               AND xa.fty_invc_num_in_ap IS NULL;

        fnd_file.put_line (fnd_file.LOG, '9');

        INSERT INTO xxdo.xxdoap_accrual (vendor_id, vendor, invoice_num,
                                         invoice_date, inventory_item_id, quantity_invoiced, unit_price, ext_value, invoice_amount, payment_date, org_id, ap_type
                                         , po_num)
            (  SELECT ai.vendor_id
                          vendor_id,
                      v.vendor_name
                          vendor,
                      ai.invoice_num,
                      ai.invoice_date,
                      -- aid.invoice_distribution_id,
                      pol.item_id
                          inventory_item_id,
                      SUM (aid.quantity_invoiced)
                          quantity_invoiced,
                      NVL (aid.unit_price, 1)
                          unit_price,
                      SUM (NVL (aid.unit_price, 1) * aid.quantity_invoiced)
                          ext_value,
                      ai.invoice_amount,
                      (SELECT MAX (aip.accounting_date)
                         FROM apps.ap_invoice_payments_all aip
                        WHERE     ai.invoice_id = aip.invoice_id
                              AND aip.accounting_date <
                                  fnd_date.canonical_to_date (p_end_date) + 1)
                          payment_date,
                      ai.org_id,
                      (CASE
                           WHEN EXISTS
                                    (SELECT 1
                                       FROM xxdo.xxdopo_accrual xaa
                                      WHERE     xaa.fty_invc_num =
                                                ai.invoice_num
                                            AND xaa.org_id = ai.org_id
                                            AND ai.vendor_id = xaa.vendor_id)
                           THEN
                               'Received'
                           ELSE
                               'Not Received'
                       END)
                          ap_type,
                      poh.segment1
                          po_num
                 FROM apps.ap_invoices_all ai,
                      apps.ap_invoice_distributions_all aid,
                      apps.po_headers_all poh,
                      apps.po_lines_all pol,
                      apps.po_distributions_all pod,
                      --  (select distinct xa.FTY_INVC_NUM,  xa.org_id, xa.vendor_id from xxdo.xxdopo_accrual xa) xa,
                      (  SELECT xa.org_id
                           FROM xxdo.xxdopo_fty xa
                       GROUP BY xa.org_id) xa,
                      /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                      --apps.po_vendors v
                      apps.ap_suppliers v
                /*End Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                WHERE     pod.po_header_id = pod.po_header_id
                      AND pod.po_line_id = pol.po_line_id
                      AND ai.vendor_id = v.vendor_id
                      AND pol.po_header_id = poh.po_header_id
                      AND aid.po_distribution_id = pod.po_distribution_id
                      AND aid.invoice_id = ai.invoice_id
                      AND aid.line_type_lookup_code IN ('ACCRUAL', 'ITEM')
                      --AND vendor_type_lookup_code = 'MANUFACTURER'
                      AND xa.org_id = ai.org_id
                      AND aid.accounting_date >=
                          fnd_date.canonical_to_date (p_start_date)
                      AND aid.accounting_date <
                          fnd_date.canonical_to_date (p_end_date) + 1
                      AND aid.posted_flag = 'Y'
                      AND NOT EXISTS
                              (SELECT 1
                                 FROM xxdo.xxdoap_accrual xaa
                                WHERE     xaa.invoice_num = ai.invoice_num
                                      AND xaa.org_id = ai.org_id
                                      AND ai.vendor_id = xaa.vendor_id)
             GROUP BY ai.invoice_num, pol.item_id, aid.unit_price,
                      ai.invoice_date, ai.invoice_amount, ai.invoice_id,
                      ai.org_id, poh.segment1, v.vendor_name,
                      ai.vendor_id);

        fnd_file.put_line (fnd_file.LOG, '9');

        UPDATE xxdo.xxdopo_accrual xa
           SET fty_invc_num_in_ap   =
                   (SELECT DISTINCT invoice_num
                      FROM xxdo.xxdoap_accrual xaa
                     WHERE     UPPER (xaa.invoice_num) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.inventory_item_id = xa.inventory_item_id
                           AND xaa.org_id = xa.org_id
                           -- and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id--and xaa.PO_num = xa.po_num
                                                           ),
               invc_qty   =
                   (  SELECT SUM (quantity_invoiced)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             AND xaa.org_id = xa.org_id
                             -- and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    -- and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.inventory_item_id, xaa.org_id,
                             xaa.vendor_id                      --, xaa.PO_num
                                          ),
               unit_price_per_invoice   =
                   (  SELECT ROUND ((SUM (xaa.ext_value) / SUM (quantity_invoiced)), 2)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             AND xaa.org_id = xa.org_id
                             --  and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --   and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.inventory_item_id, xaa.org_id,
                             xaa.vendor_id                      --, xaa.PO_num
                                          ),
               invoice_value   =
                   (  SELECT SUM (xaa.ext_value)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             AND xaa.org_id = xa.org_id
                             --and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --  and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.inventory_item_id, xaa.org_id,
                             xaa.vendor_id                      --, xaa.PO_num
                                          ),
               payment_date   =
                   (  SELECT MAX (xaa.payment_date)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             AND xaa.org_id = xa.org_id
                             --   and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --   and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.inventory_item_id, xaa.org_id,
                             xaa.vendor_id                      --, xaa.PO_num
                                          ),
               total_invoice_amount   =
                   (SELECT DISTINCT (invoice_amount)
                      FROM xxdo.xxdoap_accrual xaa
                     WHERE     UPPER (xaa.invoice_num) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.inventory_item_id = xa.inventory_item_id
                           AND xaa.org_id = xa.org_id
                           --  and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id-- and xaa.PO_num = xa.po_num
                                                           )
         WHERE     xa.row_id =
                   (  SELECT MAX (row_id)
                        FROM xxdo.xxdopo_accrual xa1
                       WHERE     UPPER (xa1.fty_invc_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xa1.inventory_item_id = xa.inventory_item_id
                             AND xa1.org_id = xa.org_id
                             -- and xa1.po_type = xa.po_type
                             AND xa1.vendor_id = xa.vendor_id
                    -- and xa1.PO_num = xa.po_num
                    GROUP BY xa1.fty_invc_num, xa1.inventory_item_id, xa1.org_id,
                             xa1.vendor_id                      --, xaa.PO_num
                                          )
               AND xa.fty_invc_num_in_ap IS NULL;

        fnd_file.put_line (fnd_file.LOG, '10');

        INSERT INTO xxdo.xxdoap_accrual (vendor_id, vendor, invoice_num,
                                         invoice_date, invoice_amount, payment_date
                                         , org_id, ap_type)
            (  SELECT ai.vendor_id
                          vendor_id,
                      v.vendor_name
                          vendor,
                      ai.invoice_num,
                      ai.invoice_date,
                      -- aid.invoice_distribution_id,
                      ai.invoice_amount,
                      (SELECT MAX (aip.accounting_date)
                         FROM apps.ap_invoice_payments_all aip
                        WHERE     ai.invoice_id = aip.invoice_id
                              AND aip.accounting_date <
                                  fnd_date.canonical_to_date (p_end_date) + 1)
                          payment_date,
                      ai.org_id,
                      (CASE
                           WHEN EXISTS
                                    (SELECT 1
                                       FROM xxdo.xxdopo_accrual xaa
                                      WHERE     xaa.fty_invc_num =
                                                ai.invoice_num
                                            AND xaa.org_id = ai.org_id
                                            AND ai.vendor_id = xaa.vendor_id)
                           THEN
                               'Received'
                           ELSE
                               'Not Received'
                       END)
                          ap_type
                 FROM apps.ap_invoices_all ai,
                      apps.ap_invoice_distributions_all aid,
                      (  SELECT xa.org_id
                           FROM xxdo.xxdopo_fty xa
                       GROUP BY xa.org_id) xa,
                      /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                      --apps.po_vendors v
                      apps.ap_suppliers v
                /*End Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                WHERE     ai.vendor_id = v.vendor_id
                      AND aid.invoice_id = ai.invoice_id
                      AND aid.line_type_lookup_code IN ('ACCRUAL', 'ITEM')
                      AND vendor_type_lookup_code = 'MANUFACTURER'
                      AND aid.dist_code_combination_id NOT IN
                              (SELECT code_combination_id
                                 FROM apps.gl_code_combinations gcc
                                WHERE     /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                          --     gcc.segment3 = '11570'
                                          gcc.segment6 = '11530'
                                      /*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                      AND xa.org_id = ai.org_id
                                      AND ai.org_id = p_org_id
                                      AND aid.accounting_date >=
                                          fnd_date.canonical_to_date (
                                              p_start_date)
                                      AND aid.accounting_date <
                                            fnd_date.canonical_to_date (
                                                p_end_date)
                                          + 1
                                      AND aid.posted_flag = 'Y'
                                      AND NOT EXISTS
                                              (SELECT 1
                                                 FROM xxdo.xxdoap_accrual xaa
                                                WHERE     xaa.invoice_num =
                                                          ai.invoice_num
                                                      AND xaa.org_id =
                                                          ai.org_id
                                                      AND ai.vendor_id =
                                                          xaa.vendor_id))
             GROUP BY ai.invoice_num, ai.invoice_date, ai.invoice_amount,
                      ai.invoice_id, ai.org_id, v.vendor_name,
                      ai.vendor_id);

        fnd_file.put_line (fnd_file.LOG, '10');

        UPDATE xxdo.xxdopo_accrual xa
           SET fty_invc_num_in_ap   =
                   (SELECT DISTINCT invoice_num
                      FROM xxdo.xxdoap_accrual xaa
                     WHERE     UPPER (xaa.invoice_num) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.org_id = xa.org_id
                           -- and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id
                           --and xaa.PO_num = xa.po_num
                           AND xaa.quantity_invoiced IS NULL
                           AND xaa.inventory_item_id IS NULL),
               payment_date   =
                   (  SELECT MAX (xaa.payment_date)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.org_id = xa.org_id
                             --   and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                             --   and xaa.PO_num = xa.po_num
                             AND xaa.quantity_invoiced IS NULL
                             AND xaa.inventory_item_id IS NULL
                    GROUP BY xaa.invoice_num, xaa.org_id, xaa.vendor_id --, xaa.PO_num
                                                                       ),
               total_invoice_amount   =
                   (SELECT DISTINCT (invoice_amount)
                      FROM xxdo.xxdoap_accrual xaa
                     WHERE     UPPER (xaa.invoice_num) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.org_id = xa.org_id
                           --  and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id
                           -- and xaa.PO_num = xa.po_num
                           AND xaa.quantity_invoiced IS NULL
                           AND xaa.inventory_item_id IS NULL),
               non_matched_ap   =
                   (SELECT DISTINCT (invoice_amount)
                      FROM xxdo.xxdoap_accrual xaa
                     WHERE     UPPER (xaa.invoice_num) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.org_id = xa.org_id
                           --  and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id
                           -- and xaa.PO_num = xa.po_num
                           AND xaa.quantity_invoiced IS NULL
                           AND xaa.inventory_item_id IS NULL)
         WHERE     xa.row_id =
                   (  SELECT MAX (row_id)
                        FROM xxdo.xxdopo_accrual xa1
                       WHERE     UPPER (xa1.fty_invc_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xa1.org_id = xa.org_id
                             -- and xa1.po_type = xa.po_type
                             AND xa1.vendor_id = xa.vendor_id
                    -- and xa1.PO_num = xa.po_num
                    GROUP BY xa1.fty_invc_num, xa1.org_id, xa1.vendor_id --, xaa.PO_num
                                                                        )
               AND xa.fty_invc_num_in_ap IS NULL
               AND xa.inventory_item_id IS NOT NULL
               AND ((NVL (xa.recvd_earlier, 0) <> 0) OR (NVL (xa.received_qty, 0) <> 0));

        fnd_file.put_line (fnd_file.LOG, '11');

        INSERT INTO xxdo.xxdopo_accrual (row_id, inventory_item_id, po_num,
                                         vendor_id, vendor, style,
                                         color, unit_price, fty_invc_num,
                                         fty_invc_num_in_ap, invc_qty, unit_price_per_invoice, invoice_value, payment_date, total_invoice_amount, brand, ap_type, po_type
                                         , org_id)
            (  SELECT ROWNUM + (SELECT MAX (row_id) FROM xxdo.xxdopo_accrual), inventory_item_id, po_num,
                      vendor_id, vendor, xxdo_ap_req_accrual_upd_pkg.xxdo_get_item_details ('NA', inventory_item_id, 'STYLE'),
                      xxdo_ap_req_accrual_upd_pkg.xxdo_get_item_details ('NA', inventory_item_id, 'COLOR'), unit_price, invoice_num,
                      invoice_num, SUM (NVL (quantity_invoiced, 0)), ROUND (SUM (NVL (ext_value, 0)) / DECODE (SUM (NVL (quantity_invoiced, 0)), 0, 1, SUM (NVL (quantity_invoiced, 0))), 2),
                      SUM (NVL (ext_value, 0)), payment_date, invoice_amount,
                      xxdo_ap_req_accrual_upd_pkg.xxdo_get_item_details ('NA', inventory_item_id, 'BRAND'), 'No Direct Receipt', 'Matched',
                      org_id
                 FROM xxdo.xxdoap_accrual xpa
                WHERE NOT EXISTS
                          (SELECT 1
                             FROM xxdo.xxdopo_accrual xa
                            WHERE     xa.fty_invc_num = xpa.invoice_num
                                  AND xpa.vendor_id = xa.vendor_id
                                  AND xpa.org_id = xa.org_id--and
                                                            --xa.po_num = xpa.po_num
                                                            )
             GROUP BY inventory_item_id, po_num, vendor_id,
                      vendor, unit_price, invoice_num,
                      payment_date, invoice_amount, org_id,
                      ROWNUM);

        fnd_file.put_line (fnd_file.LOG, '11');

        INSERT INTO xxdo.xxdoap_pre_accrual (brand, vendor_id, vendor,
                                             invoice_num, invoice_amount, invoice_date, accounting_date, payment_date, org_id
                                             , ap_type)
            (  SELECT (SELECT DISTINCT xpa.brand
                         FROM xxdo.xxdopo_accrual xpa
                        WHERE     xpa.fty_invc_num = ai.invoice_num
                              AND xpa.org_id = ai.org_id
                              AND ai.vendor_id = xpa.vendor_id)
                          brand,
                      ai.vendor_id
                          vendor_id,
                      v.vendor_name
                          vendor,
                      ai.invoice_num,
                      ai.invoice_amount,
                      MAX (ai.invoice_date),
                      MAX (aid.accounting_date),
                      -- aid.invoice_distribution_id,
                      (SELECT MAX (aip.accounting_date)
                         FROM apps.ap_invoice_payments_all aip
                        WHERE     ai.invoice_id = aip.invoice_id
                              AND aip.accounting_date <
                                  fnd_date.canonical_to_date (p_end_date) + 1)
                          payment_date,
                      ai.org_id,
                      (CASE
                           WHEN EXISTS
                                    (SELECT 1
                                       FROM xxdo.xxdopo_accrual xaa
                                      WHERE     xaa.fty_invc_num =
                                                ai.invoice_num
                                            AND xaa.org_id = ai.org_id
                                            AND ai.vendor_id = xaa.vendor_id)
                           THEN
                               'Received'
                           ELSE
                               'Not Received'
                       END)
                          ap_type
                 FROM apps.ap_invoices_all ai,
                      apps.ap_invoice_distributions_all aid,
                      --  (select distinct xa.FTY_INVC_NUM,  xa.org_id, xa.vendor_id from xxdo.xxdopo_accrual xa) xa,
                      (  SELECT xa.org_id
                           FROM xxdo.xxdopo_fty xa
                       GROUP BY xa.org_id) xa,
                      /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                      --apps.po_vendors v
                      apps.ap_suppliers v
                /*End Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                WHERE     ai.vendor_id = v.vendor_id
                      AND aid.invoice_id = ai.invoice_id
                      AND aid.line_type_lookup_code IN ('ACCRUAL', 'ITEM')
                      AND xa.org_id = ai.org_id
                      AND aid.accounting_date >=
                          fnd_date.canonical_to_date (p_start_date)
                      AND aid.accounting_date <
                          fnd_date.canonical_to_date (p_end_date) + 1
                      AND aid.posted_flag = 'Y'
                      AND aid.dist_code_combination_id IN
                              (SELECT code_combination_id
                                 FROM apps.gl_code_combinations gcc
                                WHERE     /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1    */
                                          --     gcc.segment3 = '11570'
                                          gcc.segment6 = '11530'
                                      /*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                      AND NOT EXISTS
                                              (SELECT 1
                                                 FROM xxdo.xxdoap_accrual xaa
                                                WHERE     xaa.invoice_num =
                                                          ai.invoice_num
                                                      AND xaa.org_id =
                                                          ai.org_id
                                                      AND ai.vendor_id =
                                                          xaa.vendor_id))
             --                  and not exists
             --                (select 1 from xxdoap1_accrual xaa where xaa.invoice_num = ai.invoice_num and xaa.org_id = ai.org_id and ai.vendor_id = xaa.vendor_id)
             GROUP BY ai.invoice_num, ai.invoice_date, ai.invoice_amount,
                      ai.invoice_id, ai.org_id, v.vendor_name,
                      ai.vendor_id);

        fnd_file.put_line (fnd_file.LOG, '12');

        INSERT INTO xxdo.xxdoap_pre_accrual (brand, vendor_id, vendor,
                                             invoice_num, invoice_amount, invoice_date, accounting_date, payment_date, org_id
                                             , ap_type)
            (  SELECT (SELECT DISTINCT xpa.brand
                         FROM xxdo.xxdopo_accrual xpa
                        WHERE     xpa.fty_invc_num = ai.invoice_num
                              AND xpa.org_id = ai.org_id
                              AND ai.vendor_id = xpa.vendor_id)
                          brand,
                      ai.vendor_id
                          vendor_id,
                      v.vendor_name
                          vendor,
                      ai.invoice_num,
                      ai.invoice_amount,
                      MAX (ai.invoice_date),
                      MAX (aid.accounting_date),
                      -- aid.invoice_distribution_id,
                      (SELECT MAX (aip.accounting_date)
                         FROM apps.ap_invoice_payments_all aip
                        WHERE     ai.invoice_id = aip.invoice_id
                              AND aip.accounting_date <
                                  fnd_date.canonical_to_date (p_end_date) + 1)
                          payment_date,
                      ai.org_id,
                      'Received'
                          ap_type
                 FROM apps.ap_invoices_all ai,
                      apps.ap_invoice_distributions_all aid,
                      --  (select distinct xa.FTY_INVC_NUM,  xa.org_id, xa.vendor_id from xxdo.xxdopo_accrual xa) xa,
                      (  SELECT xa.org_id
                           FROM xxdo.xxdopo_fty xa
                       GROUP BY xa.org_id) xa,
                      /*Start Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                      --apps.po_vendors v
                      apps.ap_suppliers v
                /*End Changes by BT Technology Team on 15-JAN-2015 - V 1.1 */
                WHERE     ai.vendor_id = v.vendor_id
                      AND aid.invoice_id = ai.invoice_id
                      AND aid.line_type_lookup_code IN ('ACCRUAL', 'ITEM')
                      AND xa.org_id = ai.org_id
                      --     and aid.accounting_date >=  to_date(:pre_start_Date)
                      AND aid.accounting_date <
                          fnd_date.canonical_to_date (p_start_date)
                      AND aid.posted_flag = 'Y'
                      AND aid.dist_code_combination_id IN
                              (SELECT code_combination_id
                                 FROM apps.gl_code_combinations gcc
                                WHERE     /*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                          --     gcc.segment3 = '11570'
                                          gcc.segment6 = '11530'
                                      /*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                      AND NOT EXISTS
                                              (SELECT 1
                                                 FROM xxdo.xxdoap_accrual xaa
                                                WHERE     xaa.invoice_num =
                                                          ai.invoice_num
                                                      AND xaa.org_id =
                                                          ai.org_id
                                                      AND ai.vendor_id =
                                                          xaa.vendor_id)
                                      AND NOT EXISTS
                                              (SELECT 1
                                                 FROM xxdo.xxdoap_pre_accrual xaa
                                                WHERE     xaa.invoice_num =
                                                          ai.invoice_num
                                                      AND xaa.org_id =
                                                          ai.org_id
                                                      AND ai.vendor_id =
                                                          xaa.vendor_id)
                                      AND EXISTS
                                              (SELECT 1
                                                 FROM xxdo.xxdopo_accrual xaa
                                                WHERE     xaa.fty_invc_num =
                                                          ai.invoice_num
                                                      AND xaa.org_id =
                                                          ai.org_id
                                                      AND ai.vendor_id =
                                                          xaa.vendor_id))
             GROUP BY ai.invoice_num, ai.invoice_date, ai.invoice_amount,
                      ai.invoice_id, ai.org_id, v.vendor_name,
                      ai.vendor_id);

        fnd_file.put_line (fnd_file.LOG, '13');

        UPDATE xxdo.xxdopo_accrual xa
           SET fty_invc_num_in_ap   =
                   (SELECT DISTINCT invoice_num
                      FROM xxdo.xxdoap_pre_accrual xaa
                     WHERE     UPPER (xaa.invoice_num) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.org_id = xa.org_id
                           -- and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id--and xaa.PO_num = xa.po_num
                                                           )--      ,invoice_value =
                                                            --        (select  max( invoice_amount) from xxdoap_pre_accrual xaa
                                                            --             where   UPPER (xaa.invoice_num) =  UPPER (xa.FTY_INVC_NUM)
                                                            --                   and  xaa.org_id = xa.org_id
                                                            --                 -- and xaa.ap_type = 'Received'
                                                            --                  and xaa.vendor_id = xa.vendor_id
                                                            --                  --and xaa.PO_num = xa.po_num
                                                            --              group by xaa.invoice_num , xaa.vendor_id , xaa.org_id , xaa.vendor_id --, xaa.PO_num
                                                            --                  )
                                                            ,
               payment_date   =
                   (  SELECT MAX (xaa.payment_date)
                        FROM xxdo.xxdoap_pre_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.org_id = xa.org_id
                             -- and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.vendor_id, xaa.org_id --, xaa.PO_num
                                                                       ),
               pre_invc_date   =
                   (  SELECT MAX (xaa.accounting_date)
                        FROM xxdo.xxdoap_pre_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.org_id = xa.org_id
                             -- and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.vendor_id, xaa.org_id --, xaa.PO_num
                                                                       )--       ,Total_invoice_amount =
                                                                        --        (select  avg(invoice_amount) from xxdoap_pre_accrual xaa
                                                                        --             where   UPPER (xaa.invoice_num) = UPPER (xa.FTY_INVC_NUM)
                                                                        --                   and  xaa.org_id = xa.org_id
                                                                        --                 -- and xaa.ap_type = 'Received'
                                                                        --                  and xaa.vendor_id = xa.vendor_id
                                                                        --                  --and xaa.PO_num = xa.po_num
                                                                        --              group by xaa.invoice_num , xaa.vendor_id , xaa.org_id , xaa.vendor_id --, xaa.PO_num
                                                                        --                  )
                                                                        ,
               ap_type   =
                      'P'
                   || (SELECT DISTINCT (ap_type)
                         FROM xxdo.xxdoap_pre_accrual xaa
                        WHERE     UPPER (xaa.invoice_num) =
                                  UPPER (xa.fty_invc_num)
                              AND xaa.org_id = xa.org_id
                              -- and xaa.ap_type = 'Received'
                              AND xaa.vendor_id = xa.vendor_id--and xaa.PO_num = xa.po_num
                                                              ),
               prepaid_invc   =
                   (  SELECT AVG (invoice_amount)
                        FROM xxdo.xxdoap_pre_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.org_id = xa.org_id
                             -- and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.vendor_id, xaa.org_id --, xaa.PO_num
                                                                       )
         WHERE     xa.row_id =
                   (  SELECT MAX (xa1.row_id)
                        FROM xxdo.xxdopo_accrual xa1
                       WHERE     UPPER (xa1.fty_invc_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xa1.org_id = xa.org_id
                             -- and xa1.po_type = xa.po_type
                             AND xa1.vendor_id = xa.vendor_id
                    -- and xa1.PO_num = xa.po_num
                    GROUP BY xa1.fty_invc_num, xa1.org_id, xa1.vendor_id --, xaa.PO_num
                                                                        )
               AND xa.fty_invc_num_in_ap IS NULL
               AND UPPER (xa.fty_invc_num) IN
                       (SELECT DISTINCT invoice_num
                          FROM xxdo.xxdoap_pre_accrual xaa);

        fnd_file.put_line (fnd_file.LOG, '14');

        INSERT INTO xxdo.xxdopo_accrual (row_id, brand, vendor_id,
                                         vendor, fty_invc_num, fty_invc_num_in_ap, prepaid_invc, payment_date, org_id
                                         , ap_type, pre_invc_date)
            (SELECT ROWNUM + (SELECT MAX (row_id) FROM xxdo.xxdopo_accrual), brand, vendor_id,
                    vendor, invoice_num, invoice_num,
                    invoice_amount, payment_date, org_id,
                    'P' || ap_type, accounting_date
               FROM xxdo.xxdoap_pre_accrual xaa
              WHERE     invoice_num NOT IN (SELECT DISTINCT xaa.fty_invc_num
                                              FROM xxdo.xxdopo_accrual xaa
                                             WHERE prepaid_invc IS NOT NULL)
                    AND xaa.accounting_date >=
                        fnd_date.canonical_to_date (p_start_date));

        fnd_file.put_line (fnd_file.LOG, '15');

        UPDATE xxdo.xxdopo_accrual xa
           SET fty_invc_num_in_ap   =
                   (SELECT DISTINCT invoice_num
                      FROM xxdo.xxdoap_accrual xaa
                     WHERE     UPPER (xaa.invoice_num) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.org_id = xa.org_id
                           -- and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id--and xaa.PO_num = xa.po_num
                                                           ),
               payment_date   =
                   (  SELECT MAX (xaa.payment_date)
                        FROM xxdo.xxdoap_accrual xaa
                       WHERE     UPPER (xaa.invoice_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.org_id = xa.org_id
                             --   and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --   and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_num, xaa.org_id, xaa.vendor_id --, xaa.PO_num
                                                                       )
         WHERE xa.fty_invc_num_in_ap IS NULL;

        fnd_file.put_line (fnd_file.LOG, '15');

        UPDATE xxdo.xxdoinvc_aacrual xaa
           SET existing   =
                   (SELECT DISTINCT 'Y'
                      FROM xxdo.xxdopo_accrual xa
                     WHERE     UPPER (xaa.invoice_number) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.inventory_item_id = xa.inventory_item_id
                           --and  xaa.org_id = xa.org_id
                           -- and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id--and xaa.PO_num = xa.po_num
                                                           )
         WHERE     EXISTS
                       (SELECT 1
                          FROM xxdo.xxdopo_accrual xa
                         WHERE     xaa.inventory_item_id =
                                   xa.inventory_item_id
                               --and  xer.po_num = xa.po_num
                               AND UPPER (xaa.invoice_number) =
                                   UPPER (xa.fty_invc_num)
                               AND xaa.org_id = xa.org_id
                               AND xaa.vendor_id = xa.vendor_id)
               AND existing IS NULL;

        fnd_file.put_line (fnd_file.LOG, '16');

        UPDATE xxdo.xxdopo_accrual xa
           SET fty_invc   =
                   (SELECT DISTINCT invoice_number
                      FROM xxdo.xxdoinvc_aacrual xaa
                     WHERE     UPPER (xaa.invoice_number) =
                               UPPER (xa.fty_invc_num)
                           AND xaa.inventory_item_id = xa.inventory_item_id
                           --and  xaa.org_id = xa.org_id
                           -- and xaa.ap_type = 'Received'
                           AND xaa.vendor_id = xa.vendor_id--and xaa.PO_num = xa.po_num
                                                           ),
               fty_invc_qty   =
                   (  SELECT SUM (invc_quantity)
                        FROM xxdo.xxdoinvc_aacrual xaa
                       WHERE     UPPER (xaa.invoice_number) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             --and  xaa.org_id = xa.org_id
                             -- and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_number, xaa.inventory_item_id, xaa.vendor_id --, xaa.PO_num
                                                                                     ),
               fty_invc_unit_price   =
                   (  SELECT ROUND ((SUM (NVL (xaa.fty_invc_val, 0)) / SUM (NVL (invc_quantity, 0))), 2)
                        FROM xxdo.xxdoinvc_aacrual xaa
                       WHERE     UPPER (xaa.invoice_number) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             --and  xaa.org_id = xa.org_id
                             -- and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_number, xaa.inventory_item_id, xaa.vendor_id --, xaa.PO_num
                                                                                     ),
               fty_invc_total_value   =
                   (  SELECT SUM (NVL (xaa.fty_invc_val, 0))
                        FROM xxdo.xxdoinvc_aacrual xaa
                       WHERE     UPPER (xaa.invoice_number) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             --and  xaa.org_id = xa.org_id
                             -- and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_number, xaa.inventory_item_id, xaa.vendor_id --, xaa.PO_num
                                                                                     ),
               fty_invc_total_invc_amt   =
                   (  SELECT SUM (NVL (xaa.fty_invc_val, 0))
                        FROM xxdo.xxdoinvc_aacrual xaa
                       WHERE     UPPER (xaa.fty_invc_val) =
                                 UPPER (xa.fty_invc_num)
                             AND xaa.inventory_item_id = xa.inventory_item_id
                             --and  xaa.org_id = xa.org_id
                             -- and xaa.ap_type = 'Received'
                             AND xaa.vendor_id = xa.vendor_id
                    --and xaa.PO_num = xa.po_num
                    GROUP BY xaa.invoice_number, xaa.inventory_item_id, xaa.vendor_id --, xaa.PO_num
                                                                                     )
         WHERE     xa.row_id =
                   (  SELECT MAX (row_id)
                        FROM xxdo.xxdopo_accrual xa1
                       WHERE     UPPER (xa1.fty_invc_num) =
                                 UPPER (xa.fty_invc_num)
                             AND xa1.inventory_item_id = xa.inventory_item_id
                             AND xa1.org_id = xa.org_id
                             -- and xa1.po_type = xa.po_type
                             AND xa1.vendor_id = xa.vendor_id
                    -- and xa1.PO_num = xa.po_num
                    GROUP BY xa1.fty_invc_num, xa1.inventory_item_id, xa1.org_id,
                             xa1.vendor_id                      --, xaa.PO_num
                                          )
               AND xa.fty_invc_num IS NOT NULL;

        fnd_file.put_line (fnd_file.LOG, '17');

        INSERT INTO xxdo.xxdopo_accrual xa (row_id,
                                            fty_invc_num,
                                            fty_invc,
                                            fty_invc_qty,
                                            fty_invc_unit_price,
                                            fty_stmnt_total_value,
                                            fty_stmnt_total_invc_amt,
                                            ap_type)
            (  SELECT ROWNUM + (SELECT MAX (row_id) FROM xxdo.xxdopo_accrual), invoice_number, invoice_number,
                      SUM (invc_quantity), ROUND ((SUM (NVL (xaa.fty_invc_val, 0)) / SUM (NVL (invc_quantity, 0))), 2), SUM (NVL (xaa.fty_invc_val, 0)),
                      SUM (NVL (xaa.fty_invc_val, 0)), 'Tradelink'
                 FROM xxdo.xxdoinvc_aacrual xaa
                WHERE NVL (existing, 'N') <> 'Y'
             GROUP BY xaa.invoice_number, xaa.inventory_item_id, xaa.vendor_id,
                      ROWNUM);

        fnd_file.put_line (fnd_file.LOG, '18');

        UPDATE xxdo.xxdopo_accrual xa
           SET fty_invc_num   =
                      'MANUAL PO - '
                   || (SELECT DISTINCT xa1.po_num
                         FROM xxdo.xxdopo_accrual xa1
                        WHERE     xa1.vendor_id = xa.vendor_id
                              AND xa1.org_id = xa.org_id
                              AND xa1.organization_id = xa.organization_id
                              AND xa1.receipt_num = xa.receipt_num
                              AND xa1.po_num IS NOT NULL
                              AND xa1.fty_invc_num IS NULL
                              AND xa1.receipt_num IS NOT NULL)
         WHERE     fty_invc_num IS NULL
               AND po_num IS NOT NULL
               AND receipt_num IS NOT NULL;

        fnd_file.put_line (fnd_file.LOG, '19');

        UPDATE xxdo.xxdopo_accrual xa
           SET sales_region   =
                   (SELECT DISTINCT xa1.sales_region
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.organization_id = xa.organization_id
                           AND xa1.sales_region IS NOT NULL)
         WHERE sales_region IS NULL;

        fnd_file.put_line (fnd_file.LOG, '20');

        UPDATE xxdo.xxdopo_accrual xa
           SET cost_center   =
                   (SELECT DISTINCT xa1.cost_center
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.organization_id = xa.organization_id
                           AND xa1.cost_center IS NOT NULL)
         WHERE cost_center IS NULL;

        fnd_file.put_line (fnd_file.LOG, '21');

        UPDATE xxdo.xxdopo_accrual xa
           SET country   =
                   (SELECT DISTINCT xa1.country
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.organization_id = xa.organization_id
                           AND xa1.country IS NOT NULL)
         WHERE country IS NULL;

        fnd_file.put_line (fnd_file.LOG, '22');

        UPDATE xxdo.xxdopo_accrual xa
           SET brand   =
                   (SELECT DISTINCT xa1.brand
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.brand IS NOT NULL)
         WHERE brand IS NULL;

        fnd_file.put_line (fnd_file.LOG, '22');

        UPDATE xxdo.xxdopo_accrual xa
           SET fty_invc   =
                   (SELECT DISTINCT xa1.fty_invc
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.fty_invc IS NOT NULL)
         WHERE fty_invc IS NULL;

        fnd_file.put_line (fnd_file.LOG, '23');

        UPDATE xxdo.xxdopo_accrual xa
           SET fty_invc_num_in_ap   =
                   (SELECT DISTINCT xa1.fty_invc_num_in_ap
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.fty_invc_num_in_ap IS NOT NULL)
         WHERE fty_invc_num_in_ap IS NULL;

        fnd_file.put_line (fnd_file.LOG, '24');

        UPDATE xxdo.xxdopo_accrual xa
           SET pre_invc_date   =
                   (SELECT DISTINCT xa1.pre_invc_date
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.pre_invc_date IS NOT NULL)
         WHERE pre_invc_date IS NULL;

        fnd_file.put_line (fnd_file.LOG, '25');

        UPDATE xxdo.xxdopo_accrual xa
           SET payment_date   =
                   (SELECT DISTINCT xa1.payment_date
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.payment_date IS NOT NULL)
         WHERE payment_date IS NULL;

        fnd_file.put_line (fnd_file.LOG, '26');

        UPDATE xxdo.xxdopo_accrual xa
           SET ap_type   =
                   (SELECT DISTINCT xa1.ap_type
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.ap_type IS NOT NULL)
         WHERE ap_type IS NULL;

        fnd_file.put_line (fnd_file.LOG, '27');

        /* Changes made by Srinath*/
        UPDATE xxdo.xxdopo_accrual xa
           SET po_info   =
                   (SELECT xxdo_ap_req_accrual_upd_pkg.xxdo_get_po_num (xa1.fty_invc_num)
                      FROM xxdo.xxdopo_accrual xa1
                     WHERE     xa1.fty_invc_num = xa.fty_invc_num
                           AND xa1.vendor = xa.vendor
                           AND xa1.org_id = xa.org_id
                           AND xa1.fty_invc_num IS NOT NULL
                           AND xa.row_id = xa1.row_id)
         WHERE fty_invc_num IS NOT NULL AND po_info IS NULL;

        COMMIT;
        fnd_file.put_line (fnd_file.LOG, '28');

        BEGIN
            FOR fty_cost_rec IN fty_cost_center_cur
            LOOP
                --fnd_file.put_line(fnd_file.log,'27 Updation Cost Center');
                UPDATE xxdo.xxdopo_accrual xxa
                   SET cost_center   =
                           (SELECT TO_CHAR (/*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                            --  gcc.segment2
                                            gcc.segment5/*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                        )
                              FROM mtl_parameters mp, apps.gl_code_combinations gcc
                             WHERE     mp.organization_id =
                                       fty_cost_rec.ship_to_org_id
                                   AND gcc.code_combination_id =
                                       mp.material_account)
                 WHERE     xxa.fty_invc_num = fty_cost_rec.fty_invc_num
                       AND xxa.vendor_id = fty_cost_rec.vendor_id;
            END LOOP;
        --fnd_file.put_line(fnd_file.log,'28 End of Updation Cost Center');

        --COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error Ocuured While Updating Cost Center'
                    || '   '
                    || SQLERRM);
        END;

        BEGIN
            FOR fty_cost_inv_rec IN fty_cost_center_inv_cur
            LOOP
                --fnd_file.put_line(fnd_file.log,'27 Updation Cost Center');
                UPDATE xxdo.xxdopo_accrual xxa
                   SET cost_center   =
                           (SELECT TO_CHAR (/*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                            --gcc.segment2
                                            gcc.segment5/*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                        )
                              FROM mtl_parameters mp, apps.gl_code_combinations gcc
                             WHERE     mp.organization_id =
                                       fty_cost_inv_rec.ship_to_org_id
                                   AND gcc.code_combination_id =
                                       mp.material_account)
                 WHERE     xxa.fty_invc_num = fty_cost_inv_rec.fty_invc_num
                       AND xxa.vendor_id = fty_cost_inv_rec.vendor_id;
            END LOOP;
        --fnd_file.put_line(fnd_file.log,'28 End of Updation Cost Center');

        --COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error Ocuured While Updating Cost Center with inv'
                    || '   '
                    || SQLERRM);
        END;

        BEGIN
            FOR fty_cost_apinv_rec IN fty_cost_center_apinv_cur
            LOOP
                UPDATE xxdo.xxdopo_accrual xxa
                   SET cost_center   =
                           (SELECT TO_CHAR (/*Start Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                            --gcc.segment2
                                            gcc.segment5/*End Changes by BT Technology Team on 12-DEC-2014 - V 1.1 */
                                                        )
                              FROM mtl_parameters mp, apps.gl_code_combinations gcc
                             WHERE     mp.organization_id =
                                       fty_cost_apinv_rec.ship_to_org_id
                                   AND gcc.code_combination_id =
                                       mp.material_account)
                 WHERE     xxa.fty_invc_num = fty_cost_apinv_rec.fty_invc_num
                       AND xxa.vendor_id = fty_cost_apinv_rec.vendor_id;
            END LOOP;
        --fnd_file.put_line(fnd_file.log,'28 End of Updation Cost Center');

        --COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error Ocuured While Updating Cost Center with inv'
                    || '   '
                    || SQLERRM);
        END;

        /* End of changes*/
        INSERT INTO xxdo.xxdo_po_accrualproj (ou, vendor, received_qty,
                                              recvd_earlier, unit_price, received_value, recvd_earlier_value, fty_invc_num, fty_invc_num_in_ap, invoice_qty, unit_price_per_invoice, invoice_value, payment_date, total_invoice_amount, tradelink_invc, fty_invc_qty, fty_invc_total_value, country, cost_center, brand, accrual, prepaid, intransit, pre_invc_date, prepaid_invoice_amt, qty_diff_curr, non_matched_ap
                                              , po_info    -- added by Srinath
                                                       )
              SELECT ou,
                     vendor,
                     received_qty,
                     recvd_earlier,
                     unit_price,
                     received_value,
                     recvd_earlier_value,
                     fty_invc_num,
                     fty_invc_num_in_ap,
                     nvc_qty invoice_qty,
                     unit_price_per_invoice,
                     invoice_value,
                     payment_date,
                     total_invoice_amount,
                     --FTY_STMNT_INVC_NUM,
                     --FTY_STMNT_INVC_QTY,
                     --FTY_STMNT_TOTAL_VALUE,
                     tradelink_invc,
                     fty_invc_qty,
                     fty_invc_total_value,
                     country,
                     cost_center,
                     brand,
                     CASE
                         WHEN net_diff < 0
                         THEN
                               received_value
                             + recvd_earlier_value
                             - total_invoice_amount
                             - prepaid_invoice_amt
                         ELSE
                             0
                     END accrual,
                       (DECODE (
                            payment_date,
                            NULL, 0,
                            CASE
                                WHEN net_diff > 0
                                THEN
                                      total_invoice_amount
                                    + prepaid_invoice_amt
                                    - received_value
                                    - recvd_earlier_value
                                ELSE
                                    0
                            END))
                     + (CASE
                            WHEN net_diff = 0 THEN prepaid_invoice_amt
                            ELSE 0
                        END) prepaid,
                     DECODE (
                         payment_date,
                         NULL, CASE
                                   WHEN net_diff > 0
                                   THEN
                                         total_invoice_amount
                                       + prepaid_invoice_amt
                                       - received_value
                                       - recvd_earlier_value
                                   ELSE
                                       0
                               END,
                         0) intransit,
                     pre_invc_date,
                     --NET_DIFF,
                     prepaid_invoice_amt,
                     (CASE
                          WHEN NVL (received_qty, 0) > 0
                          THEN
                              (CASE
                                   WHEN (received_qty + NVL (recvd_earlier, 0) - NVL (nvc_qty, 0)) =
                                        0
                                   THEN
                                       (received_qty + NVL (recvd_earlier, 0) - NVL (nvc_qty, 0))
                                   ELSE
                                       (received_qty + NVL (recvd_earlier, 0) - NVL (fty_invc_qty, 0))
                               END)
                          ELSE
                              0
                      END) qty_diff_curr--AP_TYPE
                                        ,
                     non_matched_ap,
                     po_info                               -- Added by Srinath
                FROM (  SELECT DECODE (org_id,  2, 'Deckers US',  94, 'Deckers Macau',  org_id) ou, --RECEIPT_DATE,
                                                                                                    --RECEIPT_NUM,
                                                                                                    --PO_NUM,
                                                                                                    vendor, --STYLE,
                                                                                                            --COLOR,
                                                                                                            SUM (NVL (received_qty, 0)) received_qty,
                               SUM (NVL (recvd_earlier, 0)) recvd_earlier, ROUND (SUM (NVL (received_value, 0)) / DECODE (NVL (SUM (received_qty), 0), 0, 1, SUM (received_qty)), 2) unit_price, SUM (NVL (received_value, 0)) received_value,
                               SUM (NVL (recvd_earlier_value, 0)) recvd_earlier_value, fty_invc_num, fty_invc_num_in_ap,
                               SUM (NVL (invc_qty, 0)) nvc_qty, ROUND (SUM (NVL (invoice_value, 0)) / DECODE (NVL (SUM (invc_qty), 0), 0, 1, SUM (invc_qty)), 2) unit_price_per_invoice, SUM (NVL (invoice_value, 0)) invoice_value,
                               payment_date, MAX (NVL (total_invoice_amount, 0)) total_invoice_amount, fty_stmnt_invc_num,
                               --FTY_STMNT_UNIT_PRICE,
                               SUM (NVL (fty_stmnt_invc_qty, 0)) fty_stmnt_invc_qty, SUM (NVL (fty_stmnt_total_value, 0)) fty_stmnt_total_value, --max(FTY_STMNT_TOTAL_INVC_AMT) FTY_STMNT_TOTAL_INVC_AMT,
                                                                                                                                                 fty_invc tradelink_invc,
                               SUM (NVL (fty_invc_qty, 0)) fty_invc_qty, SUM (NVL (fty_invc_total_value, 0)) fty_invc_total_value, --max(FTY_INVC_TOTAL_INVC_AMT),
                                                                                                                                   country,
                               cost_center, brand, pre_invc_date,
                               SUM (NVL (invc_qty, 0)) - SUM (NVL (received_qty, 0)) - SUM (NVL (recvd_earlier, 0)) net_diff, MAX (NVL (prepaid_invc, 0)) prepaid_invoice_amt, MAX (NVL (non_matched_ap, 0)) non_matched_ap,
                               po_info
                          --,(select type from xxdo.xxdopo_fty xf where xf.INVOICE = a.FTY_INVC_NUM_IN_AP  and type is not null) AP_TYPE
                          FROM xxdo.xxdopo_accrual a
                         WHERE org_id = p_org_id
                      --and receipt_date is not null
                      GROUP BY org_id, vendor, fty_invc_num,
                               fty_invc_num_in_ap, payment_date, fty_stmnt_invc_num,
                               fty_invc--FTY_STMNT_UNIT_PRICE,
                                       --FTY_STMNT_INVC_QTY,
                                       --FTY_STMNT_TOTAL_VALUE,
                                       --FTY_STMNT_TOTAL_INVC_AMT,
                                       , country, cost_center,
                               brand, accrual, pre_invc_date,
                               po_info                     -- Added by Srinath
                                      )
            ORDER BY cost_center, brand, vendor,
                     fty_invc_num;

        COMMIT;
        fnd_file.put_line (
            fnd_file.output,
               RPAD ('OU', 20, ' ')
            || CHR (9)
            || RPAD ('VENDOR', 20, ' ')
            || CHR (9)
            || RPAD ('RECEIVED_QTY', 20, ' ')
            || CHR (9)
            || RPAD ('RECVD_EARLIER', 20, ' ')
            || CHR (9)
            || RPAD ('UNIT_PRICE', 20, ' ')
            || CHR (9)
            || RPAD ('RECEIVED_VALUE', 20, ' ')
            || CHR (9)
            || RPAD ('RECVD_EARLIER_VALUE', 20, ' ')
            || CHR (9)
            || RPAD ('FTY_INVC_NUM', 20, ' ')
            || CHR (9)
            || RPAD ('FTY_INVC_NUM_IN_AP', 20, ' ')
            || CHR (9)
            || RPAD ('INVOICE_QTY', 20, ' ')
            || CHR (9)
            || RPAD ('UNIT_PRICE_PER_INVOICE', 20, ' ')
            || CHR (9)
            || RPAD ('INVOICE_VALUE', 20, ' ')
            || CHR (9)
            || RPAD ('PAYMENT_DATE', 20, ' ')
            || CHR (9)
            || RPAD ('TOTAL_INVOICE_AMOUNT', 20, ' ')
            || CHR (9)
            || RPAD ('TRADELINK_INVC', 20, ' ')
            || CHR (9)
            || RPAD ('FTY_INVC_QTY', 20, ' ')
            || CHR (9)
            || RPAD ('FTY_INVC_TOTAL_VALUE', 20, ' ')
            || CHR (9)
            || RPAD ('COUNTRY', 20, ' ')
            || CHR (9)
            || RPAD ('COST_CENTER', 20, ' ')
            || CHR (9)
            || RPAD ('BRAND', 20, ' ')
            || CHR (9)
            || RPAD ('ACCRUAL', 20, ' ')
            || CHR (9)
            || RPAD ('PREPAID', 20, ' ')
            || CHR (9)
            || RPAD ('INTRANSIT', 20, ' ')
            || CHR (9)
            || RPAD ('PRE_INVC_DATE', 20, ' ')
            || CHR (9)
            || RPAD ('PREPAID_INVOICE_AMT', 20, ' ')
            || CHR (9)
            || RPAD ('QTY_DIFF_CURR', 20, ' ')
            || CHR (9)
            || RPAD ('NON_MATCHED_AP', 20, ' ')
            || CHR (9)
            || RPAD ('PO_NUMBER', 20, ' '));

        FOR crec IN report_cur
        LOOP
            --pv_po_num := NULL;
            --pv_po_num := XXDO_AP_REQ_ACCRUAL_UPD_PKG.xxdo_get_po_num(crec.fty_invc_num);
            fnd_file.put_line (
                fnd_file.output,
                   RPAD (crec.ou, 20, ' ')
                || CHR (9)
                || RPAD (crec.vendor, 20, ' ')
                || CHR (9)
                || RPAD (crec.received_qty, 20, ' ')
                || CHR (9)
                || RPAD (crec.recvd_earlier, 20, ' ')
                || CHR (9)
                || RPAD (crec.unit_price, 20, ' ')
                || CHR (9)
                || RPAD (crec.received_value, 20, ' ')
                || CHR (9)
                || RPAD (crec.recvd_earlier_value, 20, ' ')
                || CHR (9)
                || RPAD (crec.fty_invc_num, 20, ' ')
                || CHR (9)
                || RPAD (NVL (crec.fty_invc_num_in_ap, 0), 20, ' ')
                || CHR (9)
                || RPAD (crec.invoice_qty, 20, ' ')
                || CHR (9)
                || RPAD (crec.unit_price_per_invoice, 20, ' ')
                || CHR (9)
                || RPAD (crec.invoice_value, 20, ' ')
                || CHR (9)
                || RPAD (crec.payment_date, 20, ' ')
                || CHR (9)
                || RPAD (NVL (crec.total_invoice_amount, 0), 20, ' ')
                || CHR (9)
                || RPAD (NVL (crec.tradelink_invc, 0), 20, ' ')
                || CHR (9)
                || RPAD (NVL (crec.fty_invc_qty, 0), 20, ' ')
                || CHR (9)
                || RPAD (NVL (crec.fty_invc_total_value, 0), 20, ' ')
                || CHR (9)
                || RPAD (crec.country, 20, ' ')
                || CHR (9)
                || RPAD (crec.cost_center, 20, ' ')
                || CHR (9)
                || RPAD (crec.brand, 20, ' ')
                || CHR (9)
                || RPAD (crec.accrual, 20, ' ')
                || CHR (9)
                || RPAD (crec.prepaid, 20, ' ')
                || CHR (9)
                || RPAD (NVL (crec.intransit, 0), 20, ' ')
                || CHR (9)
                || RPAD (crec.pre_invc_date, 20, ' ')
                || CHR (9)
                || RPAD (crec.prepaid_invoice_amt, 20, ' ')
                || CHR (9)
                || RPAD (crec.qty_diff_curr, 20, ' ')
                || CHR (9)
                || RPAD (crec.non_matched_ap, 20, ' ')
                || CHR (9)
                || RPAD (NVL (crec.po_info, 0), 20, ' ')); --pv_po_num);  -- Added by Srinath
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.output, SQLERRM);
    END;
END XXDO_AP_REQ_ACCRUAL_UPD_PKG;
/
