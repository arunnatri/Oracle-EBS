--
-- XXDO_PO_ISO_DFF_UPDADE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_ISO_DFF_UPDADE_PKG"
AS
    -- ###################################################################################
    -- File : XXDO_PO_ISO_DFF_UPDADE_PKG.pkb
    -- Purpose : To update the PO Line Location and ISO Line DFFs
    -- Change History
    -- --------------
    -- Date            Name              Ver    Change Description
    -- ----------  --------------------  ----- -------------------- ------------------
    -- 19-DEC-2014  BT Technology Team   1.0    Initial Version
    -- 09-FEB-2015  BT Technology Team   1.1    Handled multiple row returns from custom table.
    -- 16-NOV-2015  BT Technology Team   1.2    UAT2 Defect 598. Redesign on selection criteria.
    -- 29-FEB-2016  BT Technology Team   1.3    Mock Defect . Modified Frieght DU and OH DUTY SQLs.
    -- 01-AUG-2017  Infosys              1.4    Changing PO SHipments and SO Lines Last update Date if the cost values differ from the -
    -- 28-AUG-2017  Infosys              1.5    CCR0006546 duty rate variance
    -- 19-NOV-2019  GJensen              1.6    CCR0008186 Macau CI
    -- 19-APR-2022  Viswanathan Pandian  1.7    Updated for CCR0009906 to fix performance
    -- ###################################################################################
    -- Global Variables/Cursors
    gn_org_id        NUMBER;
    gn_num_of_days   NUMBER;
    gn_dest_org_id   NUMBER;                      --  Added as part of Ver 1.5
    gn_count         NUMBER DEFAULT 0;

    CURSOR item_details_c (gn_org_id        IN NUMBER,
                           gn_dest_org_id   IN NUMBER, --Added as part of Ver 1.5
                           gn_num_of_days   IN NUMBER)
    IS
        SELECT /*+ FIRST_ROWS 100 */
               msib.inventory_item_id, msib.organization_id
          FROM mtl_system_items_b msib, org_organization_definitions ood, mtl_parameters mp
         WHERE     mp.organization_id = msib.organization_id
               AND ood.organization_id = mp.organization_id
               AND mp.attribute13 = 2                        -- Trade Inv Orgs
               /*Start of change as part of Ver 1.5*/
               --  AND ood.operating_unit = gn_org_id
               AND ood.operating_unit = NVL (gn_dest_org_id, gn_org_id)
               /*End  of change as part of Ver 1.5*/
               AND msib.inventory_item_status_code IN ('Active', 'CloseOut')
               AND EXISTS
                       (SELECT 1
                          FROM bom.cst_item_cost_details cisd
                         WHERE     cisd.inventory_item_id =
                                   msib.inventory_item_id
                               AND cisd.organization_id =
                                   msib.organization_id
                               AND TRUNC (cisd.last_update_date) >=
                                   TRUNC (SYSDATE) - gn_num_of_days)
        UNION
        SELECT /*+ FIRST_ROWS 100 */
               msib.inventory_item_id, msib.organization_id
          FROM mtl_system_items_b msib, org_organization_definitions ood, mtl_parameters mp
         WHERE     mp.organization_id = msib.organization_id
               AND ood.organization_id = mp.organization_id
               AND mp.attribute13 = 2                        -- Trade Inv Orgs
               /*Start of change as part of Ver 1.5*/
               --AND ood.operating_unit = gn_org_id
               AND ood.operating_unit = NVL (gn_dest_org_id, gn_org_id)
               /*End of change as part of Ver 1.5*/
               AND msib.inventory_item_status_code IN ('Active', 'CloseOut')
               AND EXISTS
                       (SELECT 1
                          FROM xxdo.xxdo_invval_duty_cost xidc
                         WHERE     xidc.inventory_item_id =
                                   msib.inventory_item_id
                               AND xidc.inventory_org = msib.organization_id
                               AND primary_duty_flag = 'N'
                               AND TRUNC (xidc.last_update_date) >=
                                   TRUNC (SYSDATE) - gn_num_of_days)
        UNION
        SELECT /*+ FIRST_ROWS 100 */
               pla.item_id, plla.ship_to_organization_id
          FROM po_lines_all pla, po_line_locations_all plla
         WHERE     pla.po_line_id = plla.po_line_id
               AND plla.closed_code = 'OPEN'
               AND plla.attribute11 IS NULL                             --Duty
               AND pla.org_id = gn_org_id
        UNION
        SELECT /*+ FIRST_ROWS 100 */
               oola.inventory_item_id, prla.destination_organization_id
          FROM oe_order_lines_all oola, oe_order_headers_all ooha, -- Added for 1.7
                                                                   po_requisition_headers_all prha,
               po_requisition_lines_all prla
         WHERE     oola.source_document_line_id = prla.requisition_line_id
               -- Start changes for 1.7
               AND ooha.header_id = oola.header_id
               AND oola.source_document_id = prha.requisition_header_id
               AND prha.requisition_header_id = prla.requisition_header_id
               AND ooha.open_flag = 'Y'
               AND ooha.org_id = gn_org_id
               -- End changes for 1.7
               AND oola.source_type_code = 'INTERNAL'
               AND oola.open_flag = 'Y'
               AND oola.attribute20 IS NULL                             --Duty
               AND oola.org_id = gn_org_id;

    PROCEDURE update_poline_locdff_prc (errbuf             OUT VARCHAR2,
                                        retcode            OUT VARCHAR2,
                                        p_org_id        IN     NUMBER,
                                        p_num_of_days   IN     NUMBER,
                                        p_debug         IN     VARCHAR2)
    IS
        CURSOR c_po_deatils (p_inventory_item_id   IN NUMBER,
                             p_organization_id     IN NUMBER)
        IS
            SELECT pla.po_line_id,
                   pha.po_header_id,
                   pha.segment1 po_number,
                   pll.line_location_id,
                   pll.closed_code,
                   pll.ship_to_organization_id destination,
                   CASE
                       WHEN pla.attribute7 IS NULL
                       THEN
                           (SELECT aps.country
                              FROM ap_supplier_sites_all aps
                             WHERE     vendor_site_id = pha.vendor_site_id
                                   AND aps.vendor_id = pha.vendor_id)
                       ELSE
                           (SELECT aps.country
                              FROM ap_supplier_sites_all aps
                             WHERE     vendor_site_code = pla.attribute7
                                   AND aps.vendor_id = pha.vendor_id
                                   AND aps.org_id = p_org_id)
                   END sourceorg,
                   pla.item_id,
                   pha.org_id,
                   NVL (pla.attribute12, pla.unit_price) po_price
              FROM po_headers_all pha, po_lines_all pla, po_line_locations_all pll
             WHERE     pha.po_header_id = pla.po_header_id
                   AND pha.po_header_id = pll.po_header_id
                   AND pla.po_line_id = pll.po_line_id
                   AND pll.closed_code = 'OPEN'
                   AND pla.item_id = p_inventory_item_id
                   AND pll.ship_to_organization_id = p_organization_id
                   AND pha.org_id = p_org_id;

        v_duty                NUMBER;
        v_ohduty              NUMBER;
        v_addduty             NUMBER;
        v_frieght_du          NUMBER;
        l_org_id              NUMBER;
        v_duty_calculated     NUMBER;
        v_duty_found          VARCHAR2 (1) := 'Y';
        v_max_creation_date   DATE;
        -- Start CCR0006479
        lv_old_duty           NUMBER := NULL;
        lv_old_addduty        NUMBER := NULL;
        lv_old_ohduty         NUMBER := NULL;
        lv_old_freightdu      NUMBER := NULL;
    -- End CCR0006479

    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Start Time = ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        fnd_file.put_line (
            fnd_file.LOG,
            '========================================================================');

        /*Start of change as part of Ver 1.5*/
        --     FOR rec_item_details IN item_details_c (p_org_id,p_num_of_days)
        FOR rec_item_details
            IN item_details_c (p_org_id, NULL, p_num_of_days)
        /*End of change as part of Ver 1.5*/
        LOOP
            FOR rec_po_details
                IN c_po_deatils (rec_item_details.inventory_item_id,
                                 rec_item_details.organization_id)
            LOOP
                v_duty_found   := 'Y';

                BEGIN
                    SELECT usage_rate_or_amount frieght_du
                      INTO v_frieght_du
                      FROM cst_item_cost_details_v
                     WHERE     cost_element = 'Material Overhead'
                           AND inventory_item_id = rec_po_details.item_id
                           AND organization_id = rec_po_details.destination
                           AND resource_code = 'FREIGHT DU';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_frieght_du   := NULL;
                END;

                BEGIN
                    SELECT usage_rate_or_amount ohduty
                      INTO v_ohduty
                      FROM cst_item_cost_details_v
                     WHERE     cost_element = 'Material Overhead'
                           AND inventory_item_id = rec_po_details.item_id
                           AND organization_id = rec_po_details.destination
                           AND resource_code = 'OH DUTY';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_ohduty   := NULL;
                END;

                BEGIN
                    SELECT duty, additional_duty
                      INTO v_duty, v_addduty
                      FROM xxdo.xxdo_invval_duty_cost
                     WHERE     country_of_origin = rec_po_details.sourceorg
                           AND primary_duty_flag = 'N'
                           AND inventory_org = rec_po_details.destination
                           AND inventory_item_id = rec_po_details.item_id
                           AND operating_unit = rec_po_details.org_id
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                           NVL (
                                                               duty_start_date,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               duty_end_date,
                                                               SYSDATE));
                EXCEPTION
                    WHEN TOO_MANY_ROWS
                    THEN
                          SELECT duty, additional_duty, MAX (creation_date)
                            INTO v_duty, v_addduty, v_max_creation_date
                            FROM xxdo.xxdo_invval_duty_cost
                           WHERE     country_of_origin =
                                     rec_po_details.sourceorg
                                 AND inventory_org = rec_po_details.destination
                                 AND inventory_item_id = rec_po_details.item_id
                                 AND operating_unit = rec_po_details.org_id
                                 AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                 NVL (
                                                                     duty_start_date,
                                                                     SYSDATE))
                                                         AND TRUNC (
                                                                 NVL (
                                                                     duty_end_date,
                                                                     SYSDATE))
                        GROUP BY duty, additional_duty;
                    WHEN NO_DATA_FOUND
                    THEN
                        BEGIN
                            SELECT duty, additional_duty
                              INTO v_duty, v_addduty
                              FROM xxdo.xxdo_invval_duty_cost
                             WHERE     inventory_org =
                                       rec_po_details.destination
                                   AND inventory_item_id =
                                       rec_po_details.item_id
                                   AND operating_unit = rec_po_details.org_id
                                   AND primary_duty_flag = 'Y'
                                   AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                   NVL (
                                                                       duty_start_date,
                                                                       SYSDATE))
                                                           AND TRUNC (
                                                                   NVL (
                                                                       duty_end_date,
                                                                       SYSDATE));
                        EXCEPTION
                            WHEN TOO_MANY_ROWS
                            THEN
                                  SELECT duty, additional_duty, MAX (creation_date)
                                    INTO v_duty, v_addduty, v_max_creation_date
                                    FROM xxdo.xxdo_invval_duty_cost
                                   WHERE     inventory_org =
                                             rec_po_details.destination
                                         AND inventory_item_id =
                                             rec_po_details.item_id
                                         AND operating_unit =
                                             rec_po_details.org_id
                                         AND primary_duty_flag = 'Y'
                                         AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                         NVL (
                                                                             duty_start_date,
                                                                             SYSDATE))
                                                                 AND TRUNC (
                                                                         NVL (
                                                                             duty_end_date,
                                                                             SYSDATE))
                                GROUP BY duty, additional_duty;
                            WHEN OTHERS
                            THEN
                                v_duty_found   := 'N';
                        END;
                    WHEN OTHERS
                    THEN
                        v_duty_found   := 'N';
                END;

                IF v_duty_found = 'Y'
                THEN
                    -- Start CCR0006479
                    lv_old_duty        := NULL;
                    lv_old_addduty     := NULL;
                    lv_old_ohduty      := NULL;
                    lv_old_freightdu   := NULL;

                    BEGIN
                        SELECT attribute11, attribute12, attribute13,
                               attribute14
                          INTO lv_old_duty, lv_old_addduty, lv_old_ohduty, lv_old_freightdu
                          FROM po_line_locations_all
                         WHERE line_location_id =
                               rec_po_details.line_location_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_old_duty        := NULL;
                            lv_old_addduty     := NULL;
                            lv_old_ohduty      := NULL;
                            lv_old_freightdu   := NULL;
                    END;

                    -- end CCR0006479

                    UPDATE po_line_locations_all
                       SET attribute11 = v_duty, attribute12 = v_addduty, attribute13 = v_ohduty,
                           attribute14 = v_frieght_du, attribute_category = 'PO Line Locations Elements', -- last_update_date = SYSDATE,  commented for CCR0006479
                                                                                                          last_updated_by = fnd_global.user_id,
                           last_update_login = fnd_global.login_id
                     WHERE line_location_id = rec_po_details.line_location_id;

                    -- Start CCR0006479
                    IF    NVL (lv_old_duty, -999) <> NVL (v_duty, -999)
                       OR NVL (lv_old_addduty, -999) <> NVL (v_addduty, -999)
                       OR NVL (lv_old_ohduty, -999) <> NVL (v_ohduty, -999)
                       OR NVL (lv_old_freightdu, -999) <>
                          NVL (v_frieght_du, -999)
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'All the PO Duty Attributes were not same, hence last update date is updated
				                                   for the line location id :: '
                            || rec_po_details.line_location_id);

                        BEGIN
                            -- End of CCR0006479
                            UPDATE po_line_locations_all
                               SET last_update_date = SYSDATE, attribute6 = 'Y' --CCR0008186
                             WHERE line_location_id =
                                   rec_po_details.line_location_id;
                        -- START of CCR0006479
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'error while update the line_location_id '
                                    || rec_po_details.line_location_id
                                    || SUBSTR (SQLERRM, 1, 200));
                                NULL;
                        END;
                    END IF;

                    -- END of CCR0006479

                    gn_count           := gn_count + SQL%ROWCOUNT;

                    IF MOD (gn_count, 2000) = 0
                    THEN
                        COMMIT;
                    END IF;

                    IF p_debug = 'Y'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Updated PO : ' || rec_po_details.po_number);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Organization Id : ' || rec_po_details.org_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Destination Inv Org Id: ' || rec_po_details.destination);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Item id: ' || rec_po_details.item_id);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Duty Rate: ' || v_duty);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Duty Factor: ' || v_addduty);
                        fnd_file.put_line (fnd_file.LOG,
                                           'OH Duty : ' || v_ohduty);
                        fnd_file.put_line (fnd_file.LOG,
                                           'FREIGHT DU : ' || v_frieght_du);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '========================================================================');
                    END IF;
                ELSE
                    IF p_debug = 'Y'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Duty and Additional Duty not found in XXDO.XXDO_INVVAL_DUTY_COST for PO : '
                            || rec_po_details.po_number
                            || ' for inventory_item_id - '
                            || rec_po_details.item_id);
                    END IF;
                END IF;
            END LOOP;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'Total No. of Lines Updated = ' || gn_count);
        fnd_file.put_line (
            fnd_file.LOG,
            'End Time = ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'When others  exception:'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END update_poline_locdff_prc;

    FUNCTION xxdo_om_country_code (p_location_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_country   VARCHAR2 (20);
    BEGIN
        SELECT apsl.country
          INTO l_country
          FROM po_line_locations_all plla, po_headers_all pha, ap_supplier_sites_all apsl
         WHERE     1 = 1
               AND plla.line_location_id = p_location_id
               AND plla.po_header_id = pha.po_header_id
               AND pha.vendor_site_id = apsl.vendor_site_id;

        RETURN l_country;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_country   := NULL;
            RETURN l_country;
    END xxdo_om_country_code;

    PROCEDURE update_soline_dff_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER
                                     , p_num_of_days IN NUMBER, p_dest_org_id IN NUMBER, -- Added as part of Ver 1.5
                                                                                         p_debug IN VARCHAR2)
    IS
        CURSOR c_iso_deatils (p_inventory_item_id   IN NUMBER,
                              p_organization_id     IN NUMBER)
        IS
            SELECT oha.order_number, ola.line_id, prha.segment1,
                   prla.destination_organization_id destination, oha.flow_status_code, prha.org_id,
                   ola.ordered_item, ola.attribute16 source_org, ola.inventory_item_id item_id
              FROM oe_order_headers_all oha, oe_order_lines_all ola, po_requisition_headers_all prha,
                   po_requisition_lines_all prla, oe_order_sources oos
             WHERE     oha.header_id = ola.header_id
                   AND ola.source_document_id = prha.requisition_header_id
                   AND ola.source_document_line_id = prla.requisition_line_id
                   AND prha.requisition_header_id =
                       prla.requisition_header_id
                   AND ola.source_type_code = 'INTERNAL'
                   AND ola.open_flag = 'Y'
                   AND prha.type_lookup_code = 'INTERNAL'
                   AND oha.order_source_id = oos.order_source_id
                   AND oos.NAME = 'Internal'
                   AND oha.open_flag = 'Y'
                   AND ola.inventory_item_id = p_inventory_item_id
                   AND prla.destination_organization_id = p_organization_id
                   AND oha.org_id = p_org_id;

        v_duty                NUMBER;
        v_ohduty              NUMBER;
        v_addduty             NUMBER;
        v_frieght_du          NUMBER;
        v_country             VARCHAR2 (20);
        v_duty_found          VARCHAR2 (1);
        v_max_creation_date   DATE;
        -- Start CCR0006479
        lv_old_duty           NUMBER := NULL;
        lv_old_addduty        NUMBER := NULL;
        lv_old_ohduty         NUMBER := NULL;
        lv_old_freightdu      NUMBER := NULL;
    -- End CCR0006479
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Start Time = ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        fnd_file.put_line (
            fnd_file.LOG,
            '========================================================================');

        /*Start of change as part of Ver 1.5*/
        --FOR rec_item_details IN item_details_c (p_org_id, p_num_of_days)
        FOR rec_item_details
            IN item_details_c (p_org_id, p_dest_org_id, p_num_of_days)
        /*End of change as part of Ver 1.5*/
        LOOP
            FOR rec_iso_deatils
                IN c_iso_deatils (rec_item_details.inventory_item_id,
                                  rec_item_details.organization_id)
            LOOP
                v_duty_found   := 'Y';

                BEGIN
                    SELECT usage_rate_or_amount frieght_du
                      INTO v_frieght_du
                      FROM cst_item_cost_details_v
                     WHERE     cost_element = 'Material Overhead'
                           AND inventory_item_id =
                               rec_item_details.inventory_item_id
                           AND organization_id =
                               rec_item_details.organization_id
                           AND resource_code = 'FREIGHT DU';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_frieght_du   := NULL;
                        v_duty_found   := 'N';
                END;

                BEGIN
                    SELECT usage_rate_or_amount ohduty
                      INTO v_ohduty
                      FROM cst_item_cost_details_v
                     WHERE     cost_element = 'Material Overhead'
                           AND inventory_item_id =
                               rec_item_details.inventory_item_id
                           AND organization_id =
                               rec_item_details.organization_id
                           AND resource_code = 'OH DUTY';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_ohduty       := NULL;
                        v_duty_found   := 'N';
                END;

                v_country      :=
                    xxdo_om_country_code (
                        TO_NUMBER (rec_iso_deatils.source_org));

                IF v_country IS NOT NULL
                THEN
                    BEGIN
                        SELECT duty, additional_duty
                          INTO v_duty, v_addduty
                          FROM xxdo.xxdo_invval_duty_cost
                         WHERE     country_of_origin = v_country
                               AND inventory_org =
                                   rec_iso_deatils.destination
                               AND inventory_item_id =
                                   rec_iso_deatils.item_id
                               AND operating_unit = rec_iso_deatils.org_id
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   duty_start_date,
                                                                   SYSDATE))
                                                       AND TRUNC (
                                                               NVL (
                                                                   duty_end_date,
                                                                   SYSDATE));
                    EXCEPTION
                        WHEN TOO_MANY_ROWS
                        THEN
                              SELECT duty, additional_duty, MAX (creation_date)
                                INTO v_duty, v_addduty, v_max_creation_date
                                FROM xxdo.xxdo_invval_duty_cost
                               WHERE     country_of_origin = v_country
                                     AND inventory_org =
                                         rec_iso_deatils.destination
                                     AND inventory_item_id =
                                         rec_iso_deatils.item_id
                                     AND operating_unit =
                                         rec_iso_deatils.org_id
                                     AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                     NVL (
                                                                         duty_start_date,
                                                                         SYSDATE))
                                                             AND TRUNC (
                                                                     NVL (
                                                                         duty_end_date,
                                                                         SYSDATE))
                            GROUP BY duty, additional_duty;
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                SELECT duty, additional_duty
                                  INTO v_duty, v_addduty
                                  FROM xxdo.xxdo_invval_duty_cost
                                 WHERE     inventory_org =
                                           rec_iso_deatils.destination
                                       AND inventory_item_id =
                                           rec_iso_deatils.item_id
                                       AND operating_unit =
                                           rec_iso_deatils.org_id
                                       AND primary_duty_flag = 'Y'
                                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                       NVL (
                                                                           duty_start_date,
                                                                           SYSDATE))
                                                               AND TRUNC (
                                                                       NVL (
                                                                           duty_end_date,
                                                                           SYSDATE));
                            EXCEPTION
                                WHEN TOO_MANY_ROWS
                                THEN
                                      SELECT duty, additional_duty, MAX (creation_date)
                                        INTO v_duty, v_addduty, v_max_creation_date
                                        FROM xxdo.xxdo_invval_duty_cost
                                       WHERE     inventory_org =
                                                 rec_iso_deatils.destination
                                             AND inventory_item_id =
                                                 rec_iso_deatils.item_id
                                             AND operating_unit =
                                                 rec_iso_deatils.org_id
                                             AND primary_duty_flag = 'Y'
                                             AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                             NVL (
                                                                                 duty_start_date,
                                                                                 SYSDATE))
                                                                     AND TRUNC (
                                                                             NVL (
                                                                                 duty_end_date,
                                                                                 SYSDATE))
                                    GROUP BY duty, additional_duty;
                                WHEN OTHERS
                                THEN
                                    v_duty_found   := 'N';
                            END;
                        WHEN OTHERS
                        THEN
                            v_duty_found   := 'N';
                    END;
                ELSE
                    BEGIN
                        SELECT duty, additional_duty
                          INTO v_duty, v_addduty
                          FROM xxdo.xxdo_invval_duty_cost
                         WHERE     inventory_org =
                                   rec_iso_deatils.destination
                               AND inventory_item_id =
                                   rec_iso_deatils.item_id
                               AND operating_unit = rec_iso_deatils.org_id
                               AND primary_duty_flag = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                               NVL (
                                                                   duty_start_date,
                                                                   SYSDATE))
                                                       AND TRUNC (
                                                               NVL (
                                                                   duty_end_date,
                                                                   SYSDATE));
                    EXCEPTION
                        WHEN TOO_MANY_ROWS
                        THEN
                              SELECT duty, additional_duty, MAX (creation_date)
                                INTO v_duty, v_addduty, v_max_creation_date
                                FROM xxdo.xxdo_invval_duty_cost
                               WHERE     inventory_org =
                                         rec_iso_deatils.destination
                                     AND inventory_item_id =
                                         rec_iso_deatils.item_id
                                     AND operating_unit =
                                         rec_iso_deatils.org_id
                                     AND primary_duty_flag = 'Y'
                                     AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                                     NVL (
                                                                         duty_start_date,
                                                                         SYSDATE))
                                                             AND TRUNC (
                                                                     NVL (
                                                                         duty_end_date,
                                                                         SYSDATE))
                            GROUP BY duty, additional_duty;
                        WHEN OTHERS
                        THEN
                            v_duty_found   := 'N';
                    END;
                END IF;

                IF v_duty_found = 'Y'
                THEN
                    -- Start CCR0006479
                    lv_old_duty        := NULL;
                    lv_old_addduty     := NULL;
                    lv_old_ohduty      := NULL;
                    lv_old_freightdu   := NULL;

                    BEGIN
                        SELECT attribute20, attribute17, attribute18,
                               attribute19
                          INTO lv_old_duty, lv_old_addduty, lv_old_ohduty, lv_old_freightdu
                          FROM oe_order_lines_all
                         WHERE line_id = rec_iso_deatils.line_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_old_duty        := NULL;
                            lv_old_addduty     := NULL;
                            lv_old_ohduty      := NULL;
                            lv_old_freightdu   := NULL;
                    END;

                    -- End CCR0006479
                    UPDATE oe_order_lines_all
                       SET attribute20 = v_duty, attribute17 = v_addduty, attribute18 = v_ohduty,
                           attribute19 = v_frieght_du, CONTEXT = 'INTERNAL_SALES_ORDER', --last_update_date = SYSDATE,   -- commented for CCR0006479
                                                                                         last_updated_by = fnd_global.user_id,
                           last_update_login = fnd_global.login_id
                     WHERE line_id = rec_iso_deatils.line_id;

                    -- Start of CCR0006479
                    IF    NVL (lv_old_duty, -999) <> NVL (v_duty, -999)
                       OR NVL (lv_old_addduty, -999) <> NVL (v_addduty, -999)
                       OR NVL (lv_old_ohduty, -999) <> NVL (v_ohduty, -999)
                       OR NVL (lv_old_freightdu, -999) <>
                          NVL (v_frieght_du, -999)
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'All the SO Duty Attributes were not same, hence last update date is updated
				                                   for the line id :: '
                            || rec_iso_deatils.line_id);

                        BEGIN
                            -- End of CCR0006479
                            UPDATE oe_order_lines_all
                               SET last_update_date   = SYSDATE
                             WHERE line_id = rec_iso_deatils.line_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'error while updating the rec_iso_deatils.line_id '
                                    || rec_iso_deatils.line_id
                                    || SUBSTR (SQLERRM, 1, 200));
                                NULL;
                        END;
                    END IF;

                    -- End of CCR0006479

                    gn_count           := gn_count + SQL%ROWCOUNT;

                    IF MOD (gn_count, 2000) = 0
                    THEN
                        COMMIT;
                    END IF;

                    IF p_debug = 'Y'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '========================================================================');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Updated SO : ' || rec_iso_deatils.order_number);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Organization Id : ' || rec_iso_deatils.org_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Destination Inv Org Id: ' || rec_iso_deatils.destination);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Item id: ' || rec_iso_deatils.item_id);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Duty Rate: ' || v_duty);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Duty Factor: ' || v_addduty);
                        fnd_file.put_line (fnd_file.LOG,
                                           'OH Duty : ' || v_ohduty);
                        fnd_file.put_line (fnd_file.LOG,
                                           'FREIGHT DU : ' || v_frieght_du);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '========================================================================');
                    END IF;
                ELSE
                    IF p_debug = 'Y'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Duty and Additional Duty not found in XXDO.XXDO_INVVAL_DUTY_COST for SO : '
                            || rec_iso_deatils.order_number
                            || ' for inventory_item_id - '
                            || rec_iso_deatils.item_id);
                    END IF;
                END IF;
            END LOOP;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'Total No. of Lines Updated = ' || gn_count);
        fnd_file.put_line (
            fnd_file.LOG,
            'End Time = ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'When others  exception:'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END update_soline_dff_prc;
END xxdo_po_iso_dff_updade_pkg;
/
