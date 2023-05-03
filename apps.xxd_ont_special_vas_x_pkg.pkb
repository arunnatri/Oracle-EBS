--
-- XXD_ONT_SPECIAL_VAS_X_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SPECIAL_VAS_X_PKG"
AS
    /******************************************************************************************************
    * Program Name : XXD_ONT_SPECIAL_VAS_X_PKG
    * Description  : This package will be called from "Special VAS Supply and Demand Management - Deckers"
    *                Concurrent Program.
    *
    * History      :
    *
    * ===================================================================================================
    * Who                   Version    Comments                                              When
    * ===================================================================================================
    * BT Technology Team    1.0        Initial Version                                       09-Mar-2015
    * Bala Murugesan        2.0        Modified to consider post processing lead time
    *                                   while populating PO Promised date and Need by date   14-Apr-2017
    *                                   Changes identified by CONSIDER_LEAD_TIME
    * Aravind Kannuri       3.0        Changes as per CCR0008045                             13-Sep-2019
    ******************************************************************************************************/

    --Global Variables
    gn_assignment_set_id     mrp_assignment_sets.assignment_set_id%TYPE;
    gn_user_id               NUMBER := fnd_global.user_id;
    gn_request_id            NUMBER := fnd_global.conc_request_id;
    gd_sysdate               DATE := SYSDATE;
    gn_org_id                NUMBER := fnd_global.org_id;
    gn_application_id        NUMBER;
    gn_responsibility_id     NUMBER;
    gv_responsibility_name   VARCHAR2 (50) := 'Inventory';

    /*
    -------------------------------------------------
     Custom Table Status and their Description
    -------------------------------------------------
    N - New
    V - Validated
    C - PO Created
    R - PO Received
    P - SO Shipped/Processed completely
    E - Error records
    X - Cancelled
    */

    FUNCTION is_special_vas (p_order_type IN VARCHAR2, p_header_id IN NUMBER)
        RETURN VARCHAR2
    AS
        lc_special_vas_flag   VARCHAR2 (1) DEFAULT 'N';
    BEGIN
        SELECT CASE p_order_type
                   WHEN 'SO'
                   THEN
                       (SELECT DECODE (COUNT (1), 1, 'Y', 'N')
                          FROM oe_order_headers ooha, oe_transaction_types_v otta
                         WHERE     ooha.order_type_id =
                                   otta.transaction_type_id
                               --Commented as per CCR0008045
                               /*AND (   otta.name = 'Special VAS - US'
                                    OR NVL (ooha.attribute9, 'N') = 'Y') */
                               --START Added as per CCR0008045
                               AND (otta.name = 'Special VAS - US' AND NVL (ooha.attribute9, 'N') = 'Y')
                               --END Added as per CCR0008045
                               AND ooha.header_id = p_header_id)
                   ELSE
                       (SELECT DECODE (COUNT (1), 1, 'Y', 'N')
                          FROM po_headers pha, po_line_locations plla
                         WHERE     pha.po_header_id = plla.po_header_id
                               AND pha.po_header_id = p_header_id
                               AND EXISTS
                                       (SELECT 1
                                          FROM oe_order_headers ooha, oe_order_lines oola, oe_transaction_types_v otta
                                         WHERE     ooha.header_id =
                                                   oola.header_id
                                               AND ooha.order_type_id =
                                                   otta.transaction_type_id
                                               --Commented as per CCR0008045
                                               /* AND (   otta.name LIKE 'Special VAS - US'
                                                     OR NVL (ooha.attribute9, 'N') = 'Y') */
                                               --START Added as per CCR0008045
                                               AND (otta.name LIKE 'Special VAS - US' AND NVL (ooha.attribute9, 'N') = 'Y')
                                               --END Added as per CCR0008045
                                               AND plla.line_location_id =
                                                   oola.attribute15))
               END result
          INTO lc_special_vas_flag
          FROM DUAL;

        RETURN lc_special_vas_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exception in IS_SPECIAL_VAS. ' || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                DBMS_UTILITY.format_error_stack () || DBMS_UTILITY.format_error_backtrace ());

            RETURN 'N';
    END is_special_vas;

    FUNCTION get_intransit_days (p_vendor_id NUMBER, p_vendor_site VARCHAR2)
        RETURN NUMBER
    IS
        ln_intransit_days   VARCHAR2 (10);
    BEGIN
        -- Intransit days on Ocean
        SELECT attribute6
          INTO ln_intransit_days
          FROM fnd_lookup_values
         WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
               AND language = 'US'
               AND attribute4 = 'United States'
               AND attribute1 = TO_NUMBER (p_vendor_id)
               AND attribute2 = p_vendor_site;

        RETURN TO_NUMBER (ln_intransit_days);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in GET_INTRANSIT_DAYS. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());

            RETURN 0;
    END get_intransit_days;

    PROCEDURE insert_records_prc (p_err_msg OUT NOCOPY VARCHAR2, p_from_order IN VARCHAR2, p_to_order IN VARCHAR2
                                  , p_from_date IN DATE, p_to_date IN DATE)
    AS
    BEGIN
        INSERT INTO xxd_ont_special_vas_info_t (vas_id,
                                                order_header_id,
                                                order_number,
                                                ordered_date,
                                                order_status,
                                                org_id,
                                                ship_to_org_id,
                                                customer_name,
                                                brand,
                                                currency_code,
                                                order_line_id,
                                                order_line_num,
                                                inventory_item_id,
                                                ordered_item,
                                                ordered_quantity,
                                                request_date,
                                                schedule_ship_date,
                                                order_line_status,
                                                order_line_cancel_date,
                                                order_quantity_uom,
                                                need_by_date,
                                                attachments_count,
                                                inventory_org_code,
                                                inventory_org_id,
                                                vas_status,
                                                error_message,
                                                buyer_id,
                                                buyer_name,
                                                demand_subinventory,
                                                ship_to_location_id,
                                                list_price_per_unit,
                                                request_id,
                                                creation_date,
                                                created_by,
                                                last_update_date,
                                                last_updated_by)
            (SELECT xxdo.xxd_ont_special_vas_info_s.NEXTVAL,
                    ooha.header_id,
                    ooha.order_number,
                    ordered_date,
                    ooha.flow_status_code,
                    ooha.org_id,
                    ooha.ship_to_org_id,
                    xrcv.customer_name,
                    ooha.attribute5,
                    ooha.transactional_curr_code currency_code,
                    oola.line_id,
                    oola.line_number,
                    oola.inventory_item_id,
                    oola.ordered_item,
                    oola.ordered_quantity,
                    oola.request_date,
                    oola.schedule_ship_date,
                    oola.flow_status_code,
                    TO_DATE (fnd_date.canonical_to_date (oola.attribute1)),
                    oola.order_quantity_uom,
                    oola.request_date,
                    0,
                    mp.organization_code,
                    mp.organization_id,
                    CASE
                        WHEN (pav.agent_id IS NOT NULL) THEN 'N'
                        ELSE 'E'
                    END,
                    CASE
                        WHEN (pav.agent_id IS NOT NULL) THEN NULL
                        ELSE 'Buyer not found'
                    END,
                    pav.agent_id,
                    pav.agent_name,
                    'XDOCK',
                    hr.ship_to_location_id,
                    msib.list_price_per_unit,
                    gn_request_id,
                    gd_sysdate,
                    gn_user_id,
                    gd_sysdate,
                    gn_user_id
               FROM oe_order_headers ooha, oe_order_lines oola, --  wsh_delivery_details wdd,
                                                                mtl_parameters mp,
                    hr_locations hr, mtl_system_items_b msib, po_agents_v pav,
                    xxd_ra_customers_v xrcv
              WHERE     ooha.header_id = oola.header_id
                    AND oola.flow_status_code = 'AWAITING_SHIPPING'
                    -- AND wdd.source_line_id = oola.line_id
                    AND oola.ship_from_org_id = mp.organization_id
                    -- AND wdd.released_status IN ('R', 'B')
                    AND oola.open_flag = 'Y'
                    AND xxd_ont_special_vas_x_pkg.is_special_vas (
                            p_order_type   => 'SO',
                            p_header_id    => ooha.header_id) =
                        'Y'                               -- Special VAS Order
                    AND oola.attribute15 IS NULL        -- Supplier Identifier
                    AND NOT EXISTS
                            (SELECT 1
                               FROM xxd_ont_special_vas_info_t xosvit
                              WHERE     ooha.header_id =
                                        xosvit.order_header_id
                                    AND oola.line_id = xosvit.order_line_id)
                    AND oola.ship_from_org_id = hr.inventory_organization_id
                    AND hr.ship_to_site_flag = 'Y'
                    AND oola.inventory_item_id = msib.inventory_item_id
                    AND msib.organization_id = oola.ship_from_org_id
                    AND pav.agent_name(+) =
                        'VAS - ' || ooha.attribute5 || ','
                    AND xrcv.customer_id = ooha.sold_to_org_id
                    AND ooha.order_number BETWEEN NVL (p_from_order,
                                                       ooha.order_number)
                                              AND NVL (p_to_order,
                                                       ooha.order_number)
                    AND TRUNC (ooha.ordered_date) BETWEEN NVL (
                                                              p_from_date,
                                                              TRUNC (
                                                                  ooha.ordered_date))
                                                      AND NVL (
                                                              p_to_date,
                                                              TRUNC (
                                                                  ooha.ordered_date)));

        fnd_file.put_line (
            fnd_file.LOG,
               SQL%ROWCOUNT
            || ' records inserted into table xxd_ont_special_vas_info_t');

        COMMIT;

        p_err_msg   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            p_err_msg   := 'Exception in insert_records_prc';
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception in insert_records_prc. ' || SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                DBMS_UTILITY.format_error_stack () || DBMS_UTILITY.format_error_backtrace ());
    END insert_records_prc;

    PROCEDURE get_locator (p_org_id IN NUMBER, p_locator_id OUT NOCOPY NUMBER, p_locator OUT NOCOPY VARCHAR2
                           , p_error OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        SELECT MIN (inventory_location_id)
          INTO p_locator_id
          FROM mtl_item_locations
         WHERE     subinventory_code = 'XDOCK'
               AND organization_id = p_org_id
               AND empty_flag = 'Y'
               AND enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (end_date_active, SYSDATE))
               --Locator Reservation
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxd_ont_special_vas_info_t
                         WHERE     vas_status IN ('N', 'C')
                               AND inventory_org_id = p_org_id
                               AND demand_locator_id = inventory_location_id);

        BEGIN
            SELECT concatenated_segments
              INTO p_locator
              FROM mtl_item_locations_kfv
             WHERE inventory_location_id = p_locator_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error   := 'Unable to derive the Demand Locator';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'In get_locator excep. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error   := 'Unable to derive the Demand Locator';
            fnd_file.put_line (
                fnd_file.LOG,
                   'In get_locator excep. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END get_locator;

    PROCEDURE get_supplier_details (p_item_id IN NUMBER, p_org_id IN NUMBER, x_vendor_id OUT NOCOPY NUMBER, x_vendor_name OUT NOCOPY VARCHAR2, x_vendor_site OUT NOCOPY VARCHAR2, x_vendor_site_id OUT NOCOPY NUMBER
                                    , x_error OUT NOCOPY VARCHAR2)
    IS
        ln_category_id   NUMBER;
    BEGIN
        BEGIN
            SELECT category_id
              INTO ln_category_id
              FROM mtl_item_categories_v
             WHERE     category_set_name = 'Inventory'
                   AND organization_id = p_org_id
                   AND inventory_item_id = p_item_id;

            BEGIN
                SELECT mso.vendor_id, mso.vendor_name, mso.vendor_site_id,
                       mso.vendor_site
                  INTO x_vendor_id, x_vendor_name, x_vendor_site_id, x_vendor_site
                  FROM mrp_assignment_sets mrp, mrp_sr_assignments msra, mrp_sourcing_rules msr,
                       mrp_sr_source_org_v mso, mrp_sr_receipt_org_v msrov
                 WHERE     mrp.assignment_set_id = gn_assignment_set_id -- 'Deckers Default Set-US/JP'
                       AND mrp.assignment_set_id = msra.assignment_set_id
                       AND msr.sourcing_rule_id = msra.sourcing_rule_id
                       AND msrov.sourcing_rule_id = msr.sourcing_rule_id
                       AND msra.category_id = ln_category_id
                       AND msra.organization_id = p_org_id
                       AND msra.assignment_type = 5
                       AND mso.sr_receipt_id = msrov.sr_receipt_id
                       AND SYSDATE BETWEEN msrov.effective_date
                                       AND TRUNC (
                                               NVL (msrov.disable_date,
                                                    SYSDATE + 1));
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    SELECT mso.vendor_id, mso.vendor_name, mso.vendor_site_id,
                           mso.vendor_site
                      INTO x_vendor_id, x_vendor_name, x_vendor_site_id, x_vendor_site
                      FROM mrp_assignment_sets mrp, mrp_sr_assignments msra, mrp_sourcing_rules msr,
                           mrp_sr_source_org_v mso, mrp_sr_receipt_org_v msrov
                     WHERE     mrp.assignment_set_id = gn_assignment_set_id -- 'Deckers Default Set-US/JP'
                           AND mrp.assignment_set_id = msra.assignment_set_id
                           AND msr.sourcing_rule_id = msra.sourcing_rule_id
                           AND msrov.sourcing_rule_id = msr.sourcing_rule_id
                           AND msra.organization_id = p_org_id
                           AND msra.assignment_type = 4
                           AND mso.sr_receipt_id = msrov.sr_receipt_id
                           AND SYSDATE BETWEEN msrov.effective_date
                                           AND TRUNC (
                                                   NVL (msrov.disable_date,
                                                        SYSDATE + 1));
                WHEN OTHERS
                THEN
                    x_error   :=
                        'No Default Sourcing Rule Available for the Inventory Org. Unable to derive Vendor and Vendor Site. ';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Others error in get_supplier_details supplier details derivation. '
                        || SQLERRM
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());
            END;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_error   := 'Error while deriving item category.';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Others error in get_supplier_details category derivation.'
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_error   := 'Error while deriving supplier details';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others error in get_supplier_details.'
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END get_supplier_details;

    PROCEDURE validate_record_prc (p_errbuff OUT NOCOPY VARCHAR2, p_from_order IN VARCHAR2, p_to_order IN VARCHAR2
                                   , p_from_date IN DATE, p_to_date IN DATE)
    IS
        ln_locator_id            NUMBER;
        lc_locator               VARCHAR2 (4000);
        lc_locator_error         VARCHAR2 (4000);
        ln_vendor_id             NUMBER;
        lc_vendor_name           VARCHAR2 (400);
        ln_vendor_site_id        NUMBER;
        lc_vendor_site           VARCHAR2 (4000);
        lc_vendor_error          VARCHAR2 (4000);

        CURSOR cur_validate IS
            SELECT *
              FROM xxd_ont_special_vas_info_t
             WHERE     vas_status IN ('N', 'E')
                   AND order_number BETWEEN NVL (p_from_order, order_number)
                                        AND NVL (p_to_order, order_number)
                   AND TRUNC (ordered_date) BETWEEN NVL (
                                                        p_from_date,
                                                        TRUNC (ordered_date))
                                                AND NVL (
                                                        p_to_date,
                                                        TRUNC (ordered_date));

        CURSOR get_wms_orgs_c (
            p_org_id IN mtl_parameters.organization_id%TYPE)
        IS
            SELECT COUNT (1)
              FROM mtl_parameters
             WHERE wms_enabled_flag = 'Y' AND organization_id = p_org_id;

        lc_assignment_set_name   VARCHAR2 (100);
        ln_wms_org               NUMBER;
    BEGIN
        FOR rec_validate IN cur_validate
        LOOP
            ln_locator_id       := NULL;
            lc_locator          := NULL;
            lc_locator_error    := NULL;
            ln_vendor_id        := NULL;
            lc_vendor_name      := NULL;
            ln_vendor_site_id   := NULL;
            lc_vendor_site      := NULL;
            lc_vendor_error     := NULL;

            -- Supplier/Site Validation
            get_supplier_details (rec_validate.inventory_item_id, rec_validate.inventory_org_id, ln_vendor_id, lc_vendor_name, lc_vendor_site, ln_vendor_site_id
                                  , lc_vendor_error);

            IF lc_vendor_error IS NULL
            THEN
                UPDATE xxd_ont_special_vas_info_t
                   SET vendor_id = ln_vendor_id, vendor_name = lc_vendor_name, vendor_site_id = ln_vendor_site_id,
                       vendor_site = lc_vendor_site, last_update_date = gd_sysdate, request_id = gn_request_id,
                       last_updated_by = gn_user_id
                 WHERE vas_id = rec_validate.vas_id;
            ELSE
                UPDATE xxd_ont_special_vas_info_t
                   SET vas_status = 'E', error_message = lc_vendor_error, last_update_date = gd_sysdate,
                       request_id = gn_request_id, last_updated_by = gn_user_id
                 WHERE vas_id = rec_validate.vas_id;
            END IF;

            OPEN get_wms_orgs_c (rec_validate.inventory_org_id);

            FETCH get_wms_orgs_c INTO ln_wms_org;

            CLOSE get_wms_orgs_c;

            -- Locator Assignment is only for WMS Orgs
            IF ln_wms_org > 0
            THEN
                get_locator (rec_validate.inventory_org_id, ln_locator_id, lc_locator
                             , lc_locator_error);

                -- One Locator for One SO
                IF lc_locator_error IS NULL
                THEN
                    UPDATE xxd_ont_special_vas_info_t
                       SET demand_locator_id = ln_locator_id, demand_locator = lc_locator
                     WHERE     order_header_id = rec_validate.order_header_id
                           AND demand_locator_id IS NULL;
                ELSE
                    UPDATE xxd_ont_special_vas_info_t
                       SET vas_status = 'E', error_message = lc_locator_error, last_update_date = gd_sysdate,
                           request_id = gn_request_id, last_updated_by = gn_user_id
                     WHERE     order_header_id = rec_validate.order_header_id
                           AND vas_status <> 'E';
                END IF;
            END IF;
        END LOOP;

        -- Updated Validated Status
        UPDATE xxd_ont_special_vas_info_t
           SET vas_status = 'V', last_update_date = gd_sysdate, request_id = gn_request_id,
               last_updated_by = gn_user_id
         WHERE vas_status = 'N';

        -- if any of the SO line is in Error all the lines should be in error
        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET x.vas_status = 'E', x.last_update_date = gd_sysdate, x.last_updated_by = gn_user_id,
                   x.request_id = gn_request_id, x.error_message = 'Not eligible for PO, as one or more SO lines are in error'
             WHERE     order_header_id IN (SELECT order_header_id
                                             FROM xxd_ont_special_vas_info_t
                                            WHERE vas_status = 'E')
                   AND x.vas_status = 'V';

            fnd_file.put_line (
                fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' records error out due to SO with one or more error lines');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception while updating error status for SO with one more error lines. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- If Suppliers or sites are different for SO lines,all lines should be in error
        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET x.vas_status = 'E', x.last_update_date = gd_sysdate, x.last_updated_by = gn_user_id,
                   x.request_id = gn_request_id, x.error_message = 'Not eligible for PO, as multiple supplier or sites found.'
             WHERE     x.order_header_id IN
                           (  SELECT order_header_id
                                FROM xxd_ont_special_vas_info_t
                               WHERE vas_status = 'V'
                              HAVING COUNT (DISTINCT vendor_id) > 1
                            GROUP BY order_header_id
                            UNION
                              SELECT order_header_id
                                FROM xxd_ont_special_vas_info_t
                               WHERE vas_status = 'V'
                              HAVING COUNT (DISTINCT vendor_site_id) > 1
                            GROUP BY order_header_id)
                   AND x.vas_status = 'V';

            fnd_file.put_line (
                fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' records error out due to SO with multiple vendor or site');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception while updating error status for SO with multiple vendor or vendor site. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- If buyer is different for SO lines,all lines should be in error
        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET x.vas_status = 'E', x.last_update_date = gd_sysdate, x.last_updated_by = gn_user_id,
                   x.request_id = gn_request_id, x.error_message = 'Not eligible for PO, as multiple buyers found.'
             WHERE     x.order_header_id IN
                           (  SELECT order_header_id
                                FROM xxd_ont_special_vas_info_t
                               WHERE vas_status = 'V'
                              HAVING COUNT (DISTINCT buyer_id) > 1
                            GROUP BY order_header_id)
                   AND x.vas_status = 'V';

            fnd_file.put_line (
                fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' records error out due to SO with multiple buyers');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception while updating error status for SO with multiple buyers. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- If ship from organizations are different for SO lines, all lines should be in error
        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET x.vas_status = 'E', x.last_update_date = gd_sysdate, x.last_updated_by = gn_user_id,
                   x.request_id = gn_request_id, x.error_message = 'Not eligible for PO, as multiple ship from organizations found.'
             WHERE     x.order_header_id IN
                           (  SELECT order_header_id
                                FROM xxd_ont_special_vas_info_t
                               WHERE vas_status = 'V'
                              HAVING COUNT (DISTINCT ship_to_location_id) > 1
                            GROUP BY order_header_id)
                   AND x.vas_status = 'V';

            fnd_file.put_line (
                fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' records error out due to SO with multiple ship from organizations');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception while updating error status for SO with multiple ship from organizations. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- If SCHEDULE_SHIP_DATE are different for SO lines,all lines should be in error
        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET x.vas_status = 'E', x.last_update_date = gd_sysdate, x.last_updated_by = gn_user_id,
                   x.request_id = gn_request_id, x.error_message = 'Not eligible for PO as multiple request dates found.'
             WHERE     x.order_header_id IN
                           (  SELECT order_header_id
                                FROM xxd_ont_special_vas_info_t
                               WHERE vas_status = 'V'
                              HAVING COUNT (DISTINCT request_date) > 1
                            GROUP BY order_header_id)
                   AND x.vas_status = 'V';

            fnd_file.put_line (
                fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' records error out due to SO with multiple request dates');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception while updating error status for SO with multiple request dates. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        --Start: Added by Infosys for CCR0006770
        -- if any line in Booked status,all lines should be in error
        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET x.vas_status = 'E', x.last_update_date = gd_sysdate, x.last_updated_by = gn_user_id,
                   x.request_id = gn_request_id, x.error_message = 'Not eligible for PO, as lines are in Booked Status'
             WHERE     EXISTS
                           (SELECT 1
                              FROM oe_order_lines_all oola
                             WHERE     oola.flow_status_code = 'BOOKED'
                                   AND oola.header_id = x.order_header_id)
                   AND x.vas_status = 'V';

            fnd_file.put_line (
                fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' records error out due to SO with lines in Booked Status');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception while updating error status for SO with lines in Booked Status. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- if  same item number exists on more than one line all lines should be in error

        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET x.vas_status = 'E', x.last_update_date = gd_sysdate, x.last_updated_by = gn_user_id,
                   x.request_id = gn_request_id, x.error_message = 'Not eligible for PO, as same item number exists on more than one line'
             WHERE     EXISTS
                           (  SELECT inventory_item_id, COUNT (inventory_item_id)
                                FROM oe_order_lines_all oola
                               WHERE     oola.flow_status_code NOT IN
                                             ('CLOSED', 'CANCELLED')
                                     AND oola.header_id = x.order_header_id
                            GROUP BY inventory_item_id
                              HAVING COUNT (inventory_item_id) > 1)
                   AND x.vas_status = 'V';

            fnd_file.put_line (
                fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' records error out due to same item number exists for more than one line');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception while updating error status for SO where same item number exists for more than one line'
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        --END: Added by Infosys for CCR0006770

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_errbuff   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in validate_record_prc. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END validate_record_prc;

    PROCEDURE create_po_prc (p_po_count OUT NOCOPY NUMBER)
    IS
        CURSOR cur_valid_po_header IS
            SELECT DISTINCT order_header_id, buyer_id, ship_to_location_id,
                            vendor_id, vendor_site_id, vendor_site,
                            order_number, currency_code, org_id,
                            request_date
              FROM xxd_ont_special_vas_info_t
             WHERE vas_status = 'V';

        CURSOR cur_valid_po_lines (p_so_header_id IN NUMBER)
        IS                                       -- CONSIDER_LEAD_TIME - Start
            --SELECT xosv.*, xciv.department
            SELECT xosv.*, xciv.department, NVL (msi.postprocessing_lead_time, 0) postprocessing_lead_time
              -- CONSIDER_LEAD_TIME - End
              FROM xxd_ont_special_vas_info_t xosv, apps.xxd_common_items_v xciv, apps.mtl_system_items_b msi
             WHERE     vas_status = 'V'
                   AND order_header_id = p_so_header_id
                   AND xciv.inventory_item_id = xosv.inventory_item_id
                   AND xciv.organization_id = xosv.inventory_org_id
                   AND msi.organization_id = xciv.organization_id
                   AND msi.inventory_item_id = xciv.inventory_item_id;

        ln_interface_line_id     NUMBER;
        ln_interface_header_id   NUMBER;
        ln_po_count              NUMBER := 0;

        -- CONSIDER_LEAD_TIME - Start
        ld_promised_date         DATE;
        ld_need_by_date          DATE;
        ln_so_header_id          NUMBER := -1;
    -- CONSIDER_LEAD_TIME - End
    BEGIN
        FOR rec_valid_po_header IN cur_valid_po_header
        LOOP
            BEGIN
                -- CONSIDER_LEAD_TIME - Start
                /*
                ln_interface_header_id := po_headers_interface_s.NEXTVAL;

                INSERT INTO po_headers_interface (action,
                                                  process_code,
                                                  batch_id,
                                                  document_type_code,
                                                  interface_header_id,
                                                  agent_id,
                                                  created_by,
                                                  vendor_id,
                                                  vendor_site_id,
                                                  creation_date,
                                                  currency_code,
                                                  ship_to_location_id,
                                                  org_id,
                                                  attribute_category,
                                                  attribute1, -- Req. Ex-Factory Date
                                                  attribute4, -- Sales Order Number
                                                  attribute8,        -- Buy Season
                                                  attribute9,         -- Buy Month
                                                  attribute10,          -- PO Type
                                                  attribute11 -- GTN Transfer Flag
                                                             )
                     VALUES (
                               'ORIGINAL',
                               'PENDING',                          -- Pre Approved
                               gn_request_id,
                               'STANDARD',
                               ln_interface_header_id,
                               rec_valid_po_header.buyer_id,
                               gn_user_id,
                               rec_valid_po_header.vendor_id,
                               rec_valid_po_header.vendor_site_id,
                               gd_sysdate,
                               rec_valid_po_header.currency_code,
                               rec_valid_po_header.ship_to_location_id,
                               rec_valid_po_header.org_id,
                               'PO Data Elements',
                               fnd_date.date_to_canonical (
                                  (  TRUNC (rec_valid_po_header.request_date)
                                   - NVL (
                                        get_intransit_days (
                                           rec_valid_po_header.vendor_id,
                                           rec_valid_po_header.vendor_site),
                                        0))),
                               rec_valid_po_header.order_number,
                               (SELECT ffv.attribute1
                                  FROM fnd_flex_values ffv,
                                       fnd_flex_value_sets ffvs
                                 WHERE     ffvs.flex_value_set_id =
                                              ffv.flex_value_set_id
                                       AND ffvs.flex_value_set_name =
                                              'DO_BUY_MONTH_YEAR'
                                       AND value_category = 'DO_BUY_MONTH_YEAR'
                                       AND ffv.flex_value =
                                              (   (SELECT UPPER (
                                                             TO_CHAR (gd_sysdate,
                                                                      'Mon'))
                                                     FROM DUAL)
                                               || ' '
                                               || (SELECT EXTRACT (
                                                             YEAR FROM gd_sysdate)
                                                     FROM DUAL))),
                                  TO_CHAR (gd_sysdate, 'MON')
                               || ' '
                               || EXTRACT (YEAR FROM gd_sysdate),
                               'XDOCK',
                               'N');
                */

                FOR rec_valid_po_lines
                    IN cur_valid_po_lines (
                           rec_valid_po_header.order_header_id)
                LOOP
                    BEGIN
                        -- CONSIDER_LEAD_TIME - Start

                        ld_promised_date   := rec_valid_po_lines.request_date;
                        ld_need_by_date    := rec_valid_po_lines.request_date;

                        IF rec_valid_po_lines.postprocessing_lead_time > 0
                        THEN
                            ld_promised_date   :=
                                  ld_promised_date
                                - rec_valid_po_lines.postprocessing_lead_time;
                            ld_need_by_date   :=
                                  ld_need_by_date
                                - rec_valid_po_lines.postprocessing_lead_time;
                        END IF;

                        IF TRIM (TO_CHAR (ld_promised_date, 'DAY')) =
                           'SATURDAY'
                        THEN
                            ld_promised_date   := ld_promised_date - 1;
                            ld_need_by_date    := ld_need_by_date - 1;
                        ELSIF TRIM (TO_CHAR (ld_promised_date, 'DAY')) =
                              'SUNDAY'
                        THEN
                            ld_promised_date   := ld_promised_date - 2;
                            ld_need_by_date    := ld_need_by_date - 2;
                        END IF;


                        IF ln_so_header_id <>
                           rec_valid_po_header.order_header_id
                        THEN
                            ln_interface_header_id   :=
                                po_headers_interface_s.NEXTVAL;

                            INSERT INTO po_headers_interface (
                                            action,
                                            process_code,
                                            batch_id,
                                            document_type_code,
                                            interface_header_id,
                                            agent_id,
                                            created_by,
                                            vendor_id,
                                            vendor_site_id,
                                            creation_date,
                                            currency_code,
                                            ship_to_location_id,
                                            org_id,
                                            attribute_category,
                                            attribute1, -- Req. Ex-Factory Date
                                            attribute4,  -- Sales Order Number
                                            attribute8,          -- Buy Season
                                            attribute9,           -- Buy Month
                                            attribute10,            -- PO Type
                                            attribute11   -- GTN Transfer Flag
                                                       )
                                     VALUES (
                                                'ORIGINAL',
                                                'PENDING',     -- Pre Approved
                                                gn_request_id,
                                                'STANDARD',
                                                ln_interface_header_id,
                                                rec_valid_po_header.buyer_id,
                                                gn_user_id,
                                                rec_valid_po_header.vendor_id,
                                                rec_valid_po_header.vendor_site_id,
                                                gd_sysdate,
                                                rec_valid_po_header.currency_code,
                                                rec_valid_po_header.ship_to_location_id,
                                                rec_valid_po_header.org_id,
                                                'PO Data Elements',
                                                fnd_date.date_to_canonical (
                                                    (TRUNC (ld_promised_date) - NVL (get_intransit_days (rec_valid_po_header.vendor_id, rec_valid_po_header.vendor_site), 0))),
                                                rec_valid_po_header.order_number,
                                                (SELECT ffv.attribute1
                                                   FROM fnd_flex_values ffv, fnd_flex_value_sets ffvs
                                                  WHERE     ffvs.flex_value_set_id =
                                                            ffv.flex_value_set_id
                                                        AND ffvs.flex_value_set_name =
                                                            'DO_BUY_MONTH_YEAR'
                                                        AND value_category =
                                                            'DO_BUY_MONTH_YEAR'
                                                        AND ffv.flex_value =
                                                            ((SELECT UPPER (TO_CHAR (gd_sysdate, 'Mon')) FROM DUAL) || ' ' || (SELECT EXTRACT (YEAR FROM gd_sysdate) FROM DUAL))),
                                                   TO_CHAR (gd_sysdate,
                                                            'MON')
                                                || ' '
                                                || EXTRACT (
                                                       YEAR FROM gd_sysdate),
                                                'XDOCK',
                                                'N');

                            ln_so_header_id   :=
                                rec_valid_po_header.order_header_id;
                        END IF;

                        -- CONSIDER_LEAD_TIME - End

                        INSERT INTO po_lines_interface (
                                        action,
                                        interface_line_id,
                                        interface_header_id,
                                        unit_price,
                                        quantity,
                                        item_id,
                                        uom_code,
                                        promised_date,
                                        need_by_date,
                                        line_attribute_category_lines,
                                        line_attribute1,              -- Brand
                                        line_attribute2,      -- Product Group
                                        line_attribute7,      -- Supplier Site
                                        shipment_attribute_category,
                                        shipment_attribute4, -- Req. Ex-Factory Date
                                        shipment_attribute10,   -- Ship Method
                                        shipment_attribute15 -- Demand Identifier
                                                            )
                                 VALUES (
                                            'ORIGINAL',
                                            po_lines_interface_s.NEXTVAL,
                                            ln_interface_header_id,
                                            rec_valid_po_lines.list_price_per_unit,
                                            rec_valid_po_lines.ordered_quantity,
                                            rec_valid_po_lines.inventory_item_id,
                                            rec_valid_po_lines.order_quantity_uom,
                                            -- CONSIDER_LEAD_TIME - Start
                                            --rec_valid_po_lines.request_date,
                                            --rec_valid_po_lines.request_date,
                                            ld_promised_date,
                                            ld_need_by_date,
                                            -- CONSIDER_LEAD_TIME - End
                                            'PO Data Elements',
                                            rec_valid_po_lines.brand,
                                            rec_valid_po_lines.department,
                                            rec_valid_po_lines.vendor_site,
                                            'PO Line Locations Elements',
                                            fnd_date.date_to_canonical (
                                                -- CONSIDER_LEAD_TIME - Start
                                                --                               (  TRUNC (rec_valid_po_lines.request_date)
                                                (TRUNC (ld_promised_date) -- CONSIDER_LEAD_TIME - End
                                                                          - NVL (get_intransit_days (rec_valid_po_lines.vendor_id, rec_valid_po_lines.vendor_site), 0))),
                                            'Ocean',
                                            rec_valid_po_lines.order_line_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while inserting record into po_lines_interface table. '
                                || SQLERRM);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error while inserting record into po_lines_interface table for vas_id - '
                                || rec_valid_po_lines.vas_id
                                || '   '
                                || DBMS_UTILITY.format_error_stack ()
                                || DBMS_UTILITY.format_error_backtrace ());

                            UPDATE xxd_ont_special_vas_info_t
                               SET vas_status = 'E', error_message = 'not interfaced', last_update_date = gd_sysdate,
                                   request_id = gn_request_id, last_updated_by = gn_user_id
                             WHERE vas_id = rec_valid_po_lines.vas_id;
                    END;
                END LOOP;                                    -- Lines Loop End
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while inserting record into po_lines_interface table. '
                        || SQLERRM);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while inserting record into po_header_interface table for order_number - '
                        || rec_valid_po_header.order_number
                        || '   '
                        || DBMS_UTILITY.format_error_stack ()
                        || DBMS_UTILITY.format_error_backtrace ());

                    UPDATE xxd_ont_special_vas_info_t
                       SET vas_status = 'E', error_message = 'not interfaced', last_update_date = gd_sysdate,
                           request_id = gn_request_id, last_updated_by = gn_user_id
                     WHERE vas_id = rec_valid_po_header.order_header_id;
            END;

            ln_po_count   := ln_po_count + 1;
        END LOOP;                                          -- Headers Loop End

        p_po_count   := ln_po_count;

        fnd_file.put_line (fnd_file.LOG,
                           ln_po_count || ' records succesfully interfaced');

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_po_count   := 0;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in CREATE_PO_PRC. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END create_po_prc;


    PROCEDURE submit_po_import_program (p_batch_id     IN            NUMBER,
                                        p_request_id      OUT NOCOPY NUMBER)
    IS
        ln_req_id        NUMBER;
        ln_wfbg_req_id   NUMBER;
        lc_phase         VARCHAR2 (100);
        lc_status        VARCHAR2 (30);
        lc_dev_phase     VARCHAR2 (100);
        lc_dev_status    VARCHAR2 (100);
        lb_wait_req      BOOLEAN;
        lc_message       VARCHAR2 (2000);
    BEGIN
        mo_global.init ('PO');
        mo_global.set_policy_context ('S', gn_org_id);
        fnd_request.set_org_id (gn_org_id);
        -- Submit PDOI
        ln_req_id      :=
            fnd_request.submit_request (application   => 'PO',
                                        program       => 'POXPOPDOI',
                                        description   => NULL,
                                        start_time    => NULL,
                                        sub_request   => FALSE,
                                        argument1     => NULL,        -- Buyer
                                        argument2     => 'STANDARD', -- Document Type
                                        argument3     => NULL,
                                        argument4     => 'N',
                                        argument5     => NULL,
                                        argument6     => 'APPROVED',
                                        argument7     => NULL,
                                        argument8     => p_batch_id,
                                        argument9     => gn_org_id,
                                        argument10    => NULL,
                                        argument11    => NULL,
                                        argument12    => NULL,
                                        argument13    => NULL);
        COMMIT;

        IF ln_req_id = 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                ' Unable to submit Import Standard Purchase Orders program ');
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Import Standard Purchase Orders concurrent request submitted successfully.');
            lb_wait_req   :=
                fnd_concurrent.wait_for_request (request_id => ln_req_id, interval => 5, phase => lc_phase, status => lc_status, dev_phase => lc_dev_phase, dev_status => lc_dev_status
                                                 , MESSAGE => lc_message);

            IF lc_dev_phase = 'COMPLETE' AND lc_dev_status = 'NORMAL'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Import Standard Purchase Orders concurrent request with the request id '
                    || ln_req_id
                    || ' completed with NORMAL status.');
                ln_wfbg_req_id   :=
                    -- Submit Workflow Background Process for PO Approval
                     fnd_request.submit_request (application   => 'FND',
                                                 program       => 'FNDWFBG',
                                                 description   => NULL,
                                                 start_time    => NULL,
                                                 sub_request   => FALSE,
                                                 argument1     => 'POAPPRV', -- Item Type
                                                 argument2     => NULL,
                                                 argument3     => NULL,
                                                 argument4     => 'Y', -- Process Deferred
                                                 argument5     => 'Y', -- Process Timeout
                                                 argument6     => NULL,
                                                 argument7     => NULL);
                COMMIT;

                IF ln_wfbg_req_id = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Unable to submit Workflow Background Process for PO Approval.');
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Workflow Background Process for PO Approval concurrent request submitted successfully.');
                    lb_wait_req   :=
                        fnd_concurrent.wait_for_request (
                            --   request_id   => ln_req_id, --Commented by Infosys for CCR0006770
                            request_id   => ln_wfbg_req_id, --Added by Infosys for CCR0006770
                            interval     => 5,
                            phase        => lc_phase,
                            status       => lc_status,
                            dev_phase    => lc_dev_phase,
                            dev_status   => lc_dev_status,
                            MESSAGE      => lc_message);

                    IF lc_dev_phase = 'COMPLETE' AND lc_dev_status = 'NORMAL'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Workflow Background Process for PO Approval concurrent request with the request id '
                            || ln_wfbg_req_id
                            || ' completed with NORMAL status.');
                    END IF;
                END IF;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Import Standard Purchase Orderst concurrent request with the request id '
                    || ln_req_id
                    || ' did not complete with NORMAL status.');
            END IF;                               -- lc_dev_phase = 'COMPLETE'
        END IF;                                               -- ln_req_id = 0

        COMMIT;
        p_request_id   := ln_req_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_request_id   := 0;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error in SUBMIT_PO_IMPORT_PROGRAM program. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END submit_po_import_program;

    PROCEDURE update_interface_status (p_int_request_id NUMBER, p_batch_id NUMBER, p_error OUT NOCOPY VARCHAR2)
    IS
        CURSOR cur_interfaced_records IS
            SELECT phi.interface_header_id,
                   phi.attribute4 order_number,
                   CASE
                       WHEN phi.process_code = 'ACCEPTED' THEN 'C'
                       ELSE 'E'
                   END status,
                   CASE
                       WHEN phi.process_code = 'ACCEPTED' THEN NULL
                       ELSE 'import failed'
                   END error_msg,
                   phi.po_header_id,
                   pli.po_line_id,
                   pli.shipment_attribute15
              FROM po_lines_interface pli, po_headers_interface phi
             WHERE     pli.interface_header_id = phi.interface_header_id
                   AND phi.request_id = p_int_request_id
                   AND batch_id = p_batch_id;
    BEGIN
        FOR rec_interfaced_records IN cur_interfaced_records
        LOOP
            UPDATE xxd_ont_special_vas_info_t
               SET vas_status = rec_interfaced_records.status, error_message = rec_interfaced_records.error_msg, po_header_id = rec_interfaced_records.po_header_id,
                   po_line_id = rec_interfaced_records.po_line_id, last_update_date = gd_sysdate, request_id = gn_request_id,
                   last_updated_by = gn_user_id
             WHERE     order_number = rec_interfaced_records.order_number
                   AND order_line_id =
                       rec_interfaced_records.shipment_attribute15;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error   :=
                   'Others Exception in UPDATE_INTERFACE_STATUS. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ();

            fnd_file.put_line (fnd_file.LOG, p_error);
    END update_interface_status;

    PROCEDURE update_po_details (p_errbuff OUT NOCOPY VARCHAR2)
    IS
        ln_custom_count   NUMBER := 0;

        CURSOR cur_po_details IS
            SELECT poh.segment1, pol.line_num, pol.quantity,
                   poll.line_location_id, poh.attribute1, x.vas_id,
                   x.order_header_id, x.order_line_id
              FROM xxd_ont_special_vas_info_t x, po_headers_all poh, po_lines_all pol,
                   po_line_locations_all poll
             WHERE     x.po_header_id = poh.po_header_id
                   AND poh.po_header_id = pol.po_header_id
                   AND poh.po_header_id = poll.po_header_id
                   AND NVL (poh.cancel_flag, 'N') = 'N'
                   AND NVL (pol.cancel_flag, 'N') = 'N'
                   AND x.po_line_id = pol.po_line_id
                   AND pol.po_line_id = poll.po_line_id
                   AND x.vas_status = 'C'
                   AND x.request_id = gn_request_id
                   AND (   supply_identifier IS NULL
                        OR po_number IS NULL
                        OR EXISTS
                               (SELECT 1
                                  FROM oe_order_lines_all oola
                                 WHERE     oola.header_id = x.order_header_id
                                       AND oola.line_id = x.order_line_id
                                       AND oola.attribute15 IS NULL));
    BEGIN
        FOR rec_po_details IN cur_po_details
        LOOP
            BEGIN
                UPDATE xxd_ont_special_vas_info_t
                   SET po_number = rec_po_details.segment1, po_line_num = rec_po_details.line_num, po_ordered_qty = rec_po_details.quantity,
                       supply_identifier = rec_po_details.line_location_id, xfactory_date = fnd_date.canonical_to_date (rec_po_details.attribute1), last_update_date = gd_sysdate,
                       request_id = gn_request_id, last_updated_by = gn_user_id
                 WHERE vas_id = rec_po_details.vas_id;

                UPDATE oe_order_lines_all
                   SET attribute15 = rec_po_details.line_location_id, last_update_date = gd_sysdate, request_id = gn_request_id,
                       last_updated_by = gn_user_id
                 WHERE     header_id = rec_po_details.order_header_id
                       AND line_id = rec_po_details.order_line_id;

                ln_custom_count   := ln_custom_count + 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_errbuff   := SQLERRM;

                    fnd_file.put_line (fnd_file.LOG, p_errbuff);

                    UPDATE xxd_ont_special_vas_info_t
                       SET vas_status = 'E', error_message = 'Error while update PO-SO details', last_update_date = gd_sysdate,
                           request_id = gn_request_id, last_updated_by = gn_user_id
                     WHERE vas_id = rec_po_details.vas_id;
            END;
        END LOOP;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
            ln_custom_count || ' records updated with PO and SO details.');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_errbuff   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in UPDATE_PO_DETAILS. '
                || p_errbuff
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END update_po_details;

    PROCEDURE create_supply_reservation (x_errbuff OUT NOCOPY VARCHAR2)
    IS
        CURSOR cur_new_pos IS
            SELECT xosv.order_number, mso.sales_order_id, xosv.inventory_item_id,
                   xosv.inventory_org_id, xosv.order_line_id, xosv.po_header_id,
                   xosv.po_number, xosv.supply_identifier, xosv.order_quantity_uom,
                   xosv.ordered_quantity, xosv.request_date, xosv.vas_id,
                   pha.authorization_status
              FROM xxdo.xxd_ont_special_vas_info_t xosv, mtl_sales_orders mso, po_headers_all pha
             WHERE     xosv.order_number = mso.segment1
                   AND pha.po_header_id = xosv.po_header_id
                   AND mso.segment3 = 'ORDER ENTRY'
                   AND vas_status = 'C'
                   --AND NVL (cancelled_status, 'N') <> 'X' --Commented by Infosys for CCR0006770
                   AND NVL (cancelled_status, 'N') <> 'CANCELLED' --Added by Infosys for CCR0006770
                   AND reservation_id IS NULL;

        ln_api_version                  NUMBER := 1.0;
        lc_init_msg_list                VARCHAR2 (2) := fnd_api.g_true;
        x_return_status                 VARCHAR2 (2);
        x_msg_count                     NUMBER := 0;
        x_msg_data                      VARCHAR2 (255);
        lc_message                      VARCHAR2 (4000);
        l_rsv_rec                       inv_reservation_global.mtl_reservation_rec_type;
        ln_serial_number                inv_reservation_global.serial_number_tbl_type;
        x_serial_number                 inv_reservation_global.serial_number_tbl_type;
        lc_partial_reservation_flag     VARCHAR2 (2) := fnd_api.g_false;
        lc_force_reservation_flag       VARCHAR2 (2) := fnd_api.g_false;
        lc_validation_flag              VARCHAR2 (2) := fnd_api.g_true;
        lb_partial_reservation_exists   BOOLEAN := FALSE;
        x_quantity_reserved             NUMBER := 0;
        x_reservation_id                NUMBER := 0;
    BEGIN
        -- Get the application_id and responsibility_id
        BEGIN
            SELECT application_id, responsibility_id
              INTO gn_application_id, gn_responsibility_id
              FROM fnd_responsibility_vl
             WHERE responsibility_name = gv_responsibility_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_errbuff   :=
                       'Error while fetching responsibility for creating reservation. '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, x_errbuff);
        END;

        fnd_global.apps_initialize (gn_user_id,
                                    gn_responsibility_id,
                                    gn_application_id);

        FOR rec_new_pos IN cur_new_pos
        LOOP
            lc_message        := NULL;
            x_return_status   := NULL;
            x_msg_count       := 0;
            x_msg_data        := NULL;

            IF rec_new_pos.authorization_status = 'APPROVED'
            THEN
                l_rsv_rec.requirement_date               := rec_new_pos.request_date;
                l_rsv_rec.organization_id                := rec_new_pos.inventory_org_id;
                l_rsv_rec.inventory_item_id              :=
                    rec_new_pos.inventory_item_id;
                l_rsv_rec.demand_source_type_id          :=
                    inv_reservation_global.g_source_type_oe;
                l_rsv_rec.demand_source_name             := NULL;
                l_rsv_rec.demand_source_header_id        :=
                    rec_new_pos.sales_order_id;
                l_rsv_rec.demand_source_line_id          :=
                    rec_new_pos.order_line_id;
                l_rsv_rec.primary_uom_code               :=
                    rec_new_pos.order_quantity_uom;
                l_rsv_rec.primary_uom_id                 := NULL;
                l_rsv_rec.reservation_uom_code           :=
                    rec_new_pos.order_quantity_uom;
                l_rsv_rec.reservation_uom_id             := NULL;
                l_rsv_rec.reservation_quantity           :=
                    rec_new_pos.ordered_quantity;
                l_rsv_rec.primary_reservation_quantity   :=
                    rec_new_pos.ordered_quantity;
                l_rsv_rec.autodetail_group_id            := NULL;
                l_rsv_rec.external_source_code           := NULL;
                l_rsv_rec.external_source_line_id        := NULL;
                l_rsv_rec.supply_source_type_id          :=
                    inv_reservation_global.g_source_type_po;
                l_rsv_rec.supply_source_header_id        :=
                    rec_new_pos.po_header_id;
                l_rsv_rec.supply_source_line_id          :=
                    rec_new_pos.supply_identifier;
                l_rsv_rec.supply_source_line_detail      := NULL;
                l_rsv_rec.subinventory_code              := NULL;
                l_rsv_rec.subinventory_id                := NULL;
                l_rsv_rec.supply_source_name             := NULL;
                l_rsv_rec.revision                       := NULL;
                l_rsv_rec.locator_id                     := NULL;
                l_rsv_rec.lot_number                     := NULL;
                l_rsv_rec.lot_number_id                  := NULL;
                l_rsv_rec.pick_slip_number               := NULL;
                l_rsv_rec.lpn_id                         := NULL;
                l_rsv_rec.attribute_category             := NULL;
                l_rsv_rec.attribute1                     := NULL;
                l_rsv_rec.attribute2                     := NULL;
                l_rsv_rec.attribute3                     := NULL;
                l_rsv_rec.attribute4                     := NULL;
                l_rsv_rec.attribute5                     := NULL;
                l_rsv_rec.attribute6                     := NULL;
                l_rsv_rec.attribute7                     := NULL;
                l_rsv_rec.attribute8                     := NULL;
                l_rsv_rec.attribute9                     := NULL;
                l_rsv_rec.attribute10                    := NULL;
                l_rsv_rec.attribute11                    := NULL;
                l_rsv_rec.attribute12                    := NULL;
                l_rsv_rec.attribute13                    := NULL;
                l_rsv_rec.attribute14                    := NULL;
                l_rsv_rec.attribute15                    := NULL;
                l_rsv_rec.ship_ready_flag                := NULL;
                l_rsv_rec.demand_source_delivery         := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Calling INV_RESERVATION_PUB.CREATE_RESERVATION API');

                -- API to create reservation
                inv_reservation_pub.create_reservation (
                    p_api_version_number       => ln_api_version,
                    p_init_msg_lst             => lc_init_msg_list,
                    p_rsv_rec                  => l_rsv_rec,
                    p_serial_number            => ln_serial_number,
                    p_partial_reservation_flag   =>
                        lc_partial_reservation_flag,
                    p_force_reservation_flag   => lc_force_reservation_flag,
                    p_partial_rsv_exists       =>
                        lb_partial_reservation_exists,
                    p_validation_flag          => lc_validation_flag,
                    x_serial_number            => x_serial_number,
                    x_return_status            => x_return_status,
                    x_msg_count                => x_msg_count,
                    x_msg_data                 => x_msg_data,
                    x_quantity_reserved        => x_quantity_reserved,
                    x_reservation_id           => x_reservation_id);
            ELSE
                x_return_status   := 'E';
                lc_message        :=
                       'PO '
                    || rec_new_pos.po_number
                    || ' is not in Approved status.';
            END IF;

            IF x_return_status = fnd_api.g_ret_sts_success
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Successfully Created the Reservation for SO '
                    || rec_new_pos.order_number
                    || '. Reservation ID = '
                    || x_reservation_id);

                UPDATE xxdo.xxd_ont_special_vas_info_t
                   SET reservation_id = x_reservation_id, error_message = NULL
                 WHERE vas_id = rec_new_pos.vas_id;
            ELSE
                FOR i IN 1 .. (x_msg_count)
                LOOP
                    lc_message   := fnd_msg_pub.get (i, 'F');
                    lc_message   := REPLACE (lc_message, CHR (0), ' ');
                END LOOP;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error while creating supply based reservation for SO '
                    || rec_new_pos.order_number
                    || '. '
                    || lc_message);

                UPDATE xxdo.xxd_ont_special_vas_info_t
                   SET error_message = SUBSTR ('Error while creating supply based reservation. ' || lc_message, 1, 4000)
                 WHERE vas_id = rec_new_pos.vas_id;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuff   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in create_supply_reservation. '
                || x_errbuff
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END create_supply_reservation;

    PROCEDURE update_supply_reservation (x_errbuff OUT NOCOPY VARCHAR2)
    AS
        CURSOR supply_res_c IS
            SELECT xosv.reservation_id
              FROM xxdo.xxd_ont_special_vas_info_t xosv
             WHERE     xosv.vas_status = 'R'
                   AND NVL (xosv.cancelled_status, 'N') <> 'X'
                   AND xosv.reservation_id IS NOT NULL
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE     mr.supply_source_type_id =
                                       inv_reservation_global.g_source_type_inv
                                   AND xosv.reservation_id =
                                       mr.reservation_id);

        ln_api_version                  NUMBER := 1.0;
        lc_init_msg_list                VARCHAR2 (2) := fnd_api.g_true;
        x_return_status                 VARCHAR2 (2);
        x_msg_count                     NUMBER := 0;
        x_msg_data                      VARCHAR2 (255);
        l_rsv_rec                       inv_reservation_global.mtl_reservation_rec_type;
        x_rsv_rec                       inv_reservation_global.mtl_reservation_rec_type;
        ln_serial_number                inv_reservation_global.serial_number_tbl_type;
        x_serial_number                 inv_reservation_global.serial_number_tbl_type;
        x_quantity_reserved             NUMBER;
        x_secondary_quantity_reserved   NUMBER;
        lc_message                      VARCHAR2 (4000);
    BEGIN
        BEGIN
            SELECT application_id, responsibility_id
              INTO gn_application_id, gn_responsibility_id
              FROM fnd_responsibility_vl
             WHERE responsibility_name = gv_responsibility_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_errbuff   :=
                       'Error while fetching responsibility for updaitng reservation. '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, x_errbuff);
        END;

        fnd_global.apps_initialize (gn_user_id,
                                    gn_responsibility_id,
                                    gn_application_id);

        FOR rec_supply_res IN supply_res_c
        LOOP
            l_rsv_rec.reservation_id   := rec_supply_res.reservation_id;
            x_rsv_rec.supply_source_type_id   :=
                inv_reservation_global.g_source_type_inv;
            fnd_file.put_line (
                fnd_file.LOG,
                'Calling INV_RESERVATION_PUB.UPDATE_RESERVATION API');

            inv_reservation_pub.update_reservation (
                p_api_version_number       => ln_api_version,
                p_init_msg_lst             => lc_init_msg_list,
                x_return_status            => x_return_status,
                x_msg_count                => x_msg_count,
                x_msg_data                 => x_msg_data,
                p_original_rsv_rec         => l_rsv_rec,
                p_to_rsv_rec               => x_rsv_rec,
                p_original_serial_number   => ln_serial_number,
                p_to_serial_number         => x_serial_number);

            IF x_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR i IN 1 .. (x_msg_count)
                LOOP
                    lc_message   := fnd_msg_pub.get (i, 'F');
                    lc_message   := REPLACE (lc_message, CHR (0), ' ');
                END LOOP;

                UPDATE xxdo.xxd_ont_special_vas_info_t
                   SET error_message = SUBSTR ('Error while updating supply to inventory reservation. ' || lc_message, 1, 4000)
                 WHERE reservation_id = rec_supply_res.reservation_id;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Successfully Updated the Reservation. Reservation ID = '
                    || rec_supply_res.reservation_id);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuff   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in update_supply_reservation. '
                || x_errbuff
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END update_supply_reservation;

    PROCEDURE create_attachments (x_errbuff OUT NOCOPY VARCHAR2)
    AS
        CURSOR po_details_c IS
            SELECT DISTINCT po_header_id, order_header_id, order_number
              FROM xxd_ont_special_vas_info_t
             WHERE vas_status IN ('C', 'R', 'P');

        CURSOR fnd_att_docs_c (p_order_header_id   IN VARCHAR2,
                               p_po_header_id      IN VARCHAR2)
        IS
            SELECT fad.document_id, fd.datatype_id, fd.category_id,
                   fd.security_type, fd.security_id, fd.publish_flag,
                   fd.image_type, fd.storage_type, fd.usage_type,
                   fd.media_id, fd.file_name
              FROM fnd_attached_documents fad, fnd_documents fd, fnd_document_categories_vl fdcv
             WHERE     fad.document_id = fd.document_id
                   AND fd.category_id = fdcv.category_id
                   AND fdcv.user_name = 'PO Attachments'
                   AND fad.pk1_value = p_order_header_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM fnd_documents fd_po, fnd_attached_documents fad_po, fnd_document_categories_vl fdcv_po
                             WHERE     fd_po.document_id = fad_po.document_id
                                   AND fd_po.category_id =
                                       fdcv_po.category_id
                                   AND fd_po.document_id = fd.document_id
                                   AND fdcv_po.user_name = 'PO Attachments'
                                   AND fad_po.entity_name = 'PO_HEADERS'
                                   AND fad_po.pk1_value = p_po_header_id);

        CURSOR max_seq_num_c (p_po_header_id IN VARCHAR2)
        IS
            SELECT MAX (seq_num) + 10
              FROM fnd_attached_documents
             WHERE pk1_value = p_po_header_id;

        lc_rowid                      VARCHAR2 (1000);
        ln_attached_document_id       NUMBER;
        ln_document_id                NUMBER;
        ln_seq_num                    NUMBER;
        lc_entity_name                VARCHAR2 (1000) := 'PO_HEADERS';
        lc_column1                    VARCHAR2 (1000);
        lc_pk_value                   VARCHAR2 (1000);
        lc_automatically_added_flag   VARCHAR2 (1000) := 'N';
        lc_language                   VARCHAR2 (1000) := USERENV ('LANG');
        lc_file_name                  VARCHAR2 (1000);
        lc_media_id                   VARCHAR2 (1000);
        ln_attachments_count          NUMBER := 0;
    BEGIN
        FOR rec_po_details IN po_details_c
        LOOP
            ln_attachments_count   := 0;

            FOR rec_fnd_att_docs
                IN fnd_att_docs_c (rec_po_details.order_header_id,
                                   rec_po_details.po_header_id)
            LOOP
                BEGIN
                    SELECT fnd_attached_documents_s.NEXTVAL
                      INTO ln_attached_document_id
                      FROM DUAL;

                    ln_seq_num   := NULL;

                    OPEN max_seq_num_c (rec_po_details.po_header_id);

                    FETCH max_seq_num_c INTO ln_seq_num;

                    CLOSE max_seq_num_c;

                    ln_seq_num   := NVL (ln_seq_num, 10);

                    fnd_file.put_line (fnd_file.LOG,
                                       'Calling FND Attachment API');
                    fnd_attached_documents_pkg.insert_row (
                        x_rowid                    => lc_rowid,
                        x_attached_document_id     => ln_attached_document_id,
                        x_document_id              =>
                            rec_fnd_att_docs.document_id,
                        x_creation_date            => gd_sysdate,
                        x_created_by               => gn_user_id,
                        x_last_update_date         => gd_sysdate,
                        x_last_updated_by          => gn_user_id,
                        x_last_update_login        => gn_user_id,
                        x_seq_num                  => ln_seq_num,
                        x_entity_name              => lc_entity_name,
                        x_column1                  => lc_column1,
                        x_pk1_value                =>
                            rec_po_details.po_header_id,
                        x_pk2_value                => lc_pk_value,
                        x_pk3_value                => lc_pk_value,
                        x_pk4_value                => lc_pk_value,
                        x_pk5_value                => lc_pk_value,
                        x_automatically_added_flag   =>
                            lc_automatically_added_flag,
                        x_request_id               => gn_request_id,
                        x_program_application_id   => gn_application_id,
                        x_program_id               => NULL,
                        x_program_update_date      => gd_sysdate,
                        x_attribute_category       => NULL,
                        x_attribute1               => NULL,
                        x_attribute2               => NULL,
                        x_attribute3               => NULL,
                        x_attribute4               => NULL,
                        x_attribute5               => NULL,
                        x_attribute6               => NULL,
                        x_attribute7               => NULL,
                        x_attribute8               => NULL,
                        x_attribute9               => NULL,
                        x_attribute10              => NULL,
                        x_attribute11              => NULL,
                        x_attribute12              => NULL,
                        x_attribute13              => NULL,
                        x_attribute14              => NULL,
                        x_attribute15              => NULL,
                        x_datatype_id              =>
                            rec_fnd_att_docs.datatype_id,
                        x_category_id              =>
                            rec_fnd_att_docs.category_id,
                        x_security_type            =>
                            rec_fnd_att_docs.security_type,
                        x_security_id              =>
                            rec_fnd_att_docs.security_id,
                        x_publish_flag             =>
                            rec_fnd_att_docs.publish_flag,
                        x_image_type               =>
                            rec_fnd_att_docs.image_type,
                        x_storage_type             =>
                            rec_fnd_att_docs.storage_type,
                        x_usage_type               =>
                            rec_fnd_att_docs.usage_type,
                        x_language                 => lc_language,
                        x_description              => NULL,
                        x_file_name                =>
                            rec_fnd_att_docs.file_name,
                        x_media_id                 =>
                            rec_fnd_att_docs.media_id,
                        x_doc_attribute_category   => NULL,
                        x_doc_attribute1           => NULL,
                        x_doc_attribute2           => NULL,
                        x_doc_attribute3           => NULL,
                        x_doc_attribute4           => NULL,
                        x_doc_attribute5           => NULL,
                        x_doc_attribute6           => NULL,
                        x_doc_attribute7           => NULL,
                        x_doc_attribute8           => NULL,
                        x_doc_attribute9           => NULL,
                        x_doc_attribute10          => NULL,
                        x_doc_attribute11          => NULL,
                        x_doc_attribute12          => NULL,
                        x_doc_attribute13          => NULL,
                        x_doc_attribute14          => NULL,
                        x_doc_attribute15          => NULL);

                    ln_attachments_count   :=
                        ln_attachments_count + SQL%ROWCOUNT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        x_errbuff   := SUBSTR (SQLERRM, 1, 2000);

                        UPDATE xxd_ont_special_vas_info_t
                           SET error_message = 'FND Attachment API Failed for Order ' || rec_po_details.order_number || ' for document ' || rec_fnd_att_docs.file_name || '. ' || x_errbuff, last_update_date = gd_sysdate, last_updated_by = gn_user_id,
                               request_id = gn_request_id
                         WHERE     order_header_id =
                                   rec_po_details.order_header_id
                               AND po_header_id = rec_po_details.po_header_id;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Others Exception in create_attachments. '
                            || SQLERRM
                            || DBMS_UTILITY.format_error_stack ()
                            || DBMS_UTILITY.format_error_backtrace ());
                END;
            END LOOP;                                        -- fnd_att_docs_c

            IF ln_attachments_count > 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ln_attachments_count
                    || ' documents attached to the related PO of Order '
                    || rec_po_details.order_number);

                UPDATE xxd_ont_special_vas_info_t
                   SET attachments_count = NVL (attachments_count, 0) + ln_attachments_count, last_update_date = gd_sysdate, last_updated_by = gn_user_id,
                       request_id = gn_request_id
                 WHERE     order_header_id = rec_po_details.order_header_id
                       AND po_header_id = rec_po_details.po_header_id;
            END IF;
        END LOOP;                                              -- po_details_c
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuff   := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in create_attachments'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END create_attachments;

    PROCEDURE update_error_records
    IS
        CURSOR cur_interface_err_records IS
            SELECT x.vas_id, poh.po_header_id, pll.po_line_id
              FROM xxd_ont_special_vas_info_t x, po_headers_all poh, po_line_locations_all pll
             WHERE     x.vas_status = 'E'
                   AND x.error_message = 'import failed'
                   AND poh.attribute_category = 'PO Data Elements'
                   --AND TRIM (poh.attribute4) = x.order_number --Commented by Infosys for CCR0006770
                   AND TRIM (poh.attribute4) = TO_CHAR (x.order_number) --Added by Infosys for CCR0006770
                   AND poh.po_header_id = pll.po_header_id
                   AND NVL (poh.cancel_flag, 'N') = 'N'
                   AND pll.attribute_category = 'PO Line Locations Elements'
                   AND TRIM (pll.attribute15) = TO_CHAR (x.order_line_id);

        ln_update_count       NUMBER := 0;
        ln_err_update_count   NUMBER := 0;
    BEGIN
        -- Update Manually created PO details
        FOR rec_interface_err_records IN cur_interface_err_records
        LOOP
            UPDATE xxd_ont_special_vas_info_t
               SET vas_status = 'C', error_message = NULL, po_header_id = rec_interface_err_records.po_header_id,
                   po_line_id = rec_interface_err_records.po_line_id, last_update_date = gd_sysdate, last_updated_by = gn_user_id,
                   request_id = gn_request_id
             WHERE vas_id = rec_interface_err_records.vas_id;

            ln_update_count   := ln_update_count + 1;
        END LOOP;

        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
               ln_update_count
            || ' interface error records updated with PO header and Line Ids ');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in UPDATE_ERROR_RECORDS. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END update_error_records;

    PROCEDURE main (p_retcode         OUT NOCOPY VARCHAR2,
                    p_errbuff         OUT NOCOPY VARCHAR2,
                    p_from_order   IN            VARCHAR2,
                    p_to_order     IN            VARCHAR2,
                    p_from_date    IN            VARCHAR2,
                    p_to_date      IN            VARCHAR2)
    IS
        lc_insert_prc_err          VARCHAR2 (4000);
        user_exception             EXCEPTION;
        ln_import_request_id       NUMBER;
        lc_assignment_set_name     VARCHAR2 (100);
        lc_upd_intf_status_error   VARCHAR2 (4000);
        ld_start_date              DATE;
        ld_end_date                DATE;
        ln_interfaced_records      NUMBER;
        ln_qty_received            NUMBER;
        ln_line_qty                NUMBER;
        lc_retcode                 VARCHAR2 (4000);
        lc_errbuff                 VARCHAR2 (4000);

        CURSOR cur_output_records IS
              SELECT order_number, order_line_id, order_line_num,
                     supply_identifier, ordered_item, po_number,
                     po_line_id, demand_locator, DECODE (cancelled_status, 'CANCELLED', ' Y', 'N') cancelled_status,
                     error_message, DECODE (vas_status,  'E', 'ERROR',  'C', 'PO CREATED',  'R', 'PO RECEIVED',  'P', 'SO SHIPPED',  'N', 'NEW',  'V', 'VALIDATED',  'X', 'CANCELLED',  vas_status) vas_status, vendor_name,
                     vendor_site, ordered_quantity
                FROM xxd_ont_special_vas_info_t x
               WHERE     request_id = gn_request_id
                     AND x.order_number BETWEEN NVL (p_from_order,
                                                     x.order_number)
                                            AND NVL (p_to_order,
                                                     x.order_number)
                     AND TRUNC (x.ordered_date) BETWEEN NVL (
                                                            ld_start_date,
                                                            TRUNC (
                                                                x.ordered_date))
                                                    AND NVL (
                                                            ld_end_date,
                                                            TRUNC (
                                                                x.ordered_date))
                     AND cancelled_status IS NULL
            ORDER BY x.order_number;

        CURSOR get_rcv_ship_details_c IS
            SELECT DISTINCT po_header_id
              FROM xxd_ont_special_vas_info_t x
             WHERE vas_status = 'C' AND reservation_id IS NOT NULL;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'gn_org_id is - ' || gn_org_id);
        fnd_file.put_line (fnd_file.LOG,
                           'From Order number - ' || p_from_order);
        fnd_file.put_line (fnd_file.LOG, 'To Order number- ' || p_to_order);
        fnd_file.put_line (fnd_file.LOG, 'From Date - ' || p_from_date);
        fnd_file.put_line (fnd_file.LOG, 'To Date - ' || p_to_date);

        IF p_from_date IS NOT NULL
        THEN
            ld_start_date   :=
                TRUNC (fnd_date.canonical_to_date (p_from_date));
            fnd_file.put_line (fnd_file.LOG,
                               'ld_start_date - ' || ld_start_date);
        ELSE
            ld_start_date   := NULL;
        END IF;

        IF p_to_date IS NOT NULL
        THEN
            ld_end_date   := TRUNC (fnd_date.canonical_to_date (p_to_date));
            fnd_file.put_line (fnd_file.LOG, 'ld_end_date - ' || ld_end_date);
        ELSE
            ld_end_date   := NULL;
        END IF;

        BEGIN
            SELECT assignment_set_id, assignment_set_name
              INTO gn_assignment_set_id, lc_assignment_set_name
              FROM mrp_assignment_sets
             WHERE assignment_set_id =
                   NVL (fnd_profile.VALUE ('MRP_DEFAULT_ASSIGNMENT_SET'),
                        -999);

            fnd_file.put_line (
                fnd_file.LOG,
                   'Begin Processing with Default Assignment Set - '
                || lc_assignment_set_name);
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_errbuff   :=
                    'No Default Assignment Set defined. ' || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, lc_errbuff);
                RAISE user_exception;
        END;

        -- 1. Delete SOs which failed and with no PO association, to reprocess it, the next time
        DELETE xxd_ont_special_vas_info_t
         WHERE     vas_status = 'E'
               AND po_header_id IS NULL
               AND order_number BETWEEN NVL (p_from_order, order_number)
                                    AND NVL (p_to_order, order_number)
               AND TRUNC (ordered_date) BETWEEN NVL (ld_start_date,
                                                     TRUNC (ordered_date))
                                            AND NVL (ld_end_date,
                                                     TRUNC (ordered_date));

        fnd_file.put_line (
            fnd_file.LOG,
               SQL%ROWCOUNT
            || ' error records deleted (with no PO association) to reprocess them.');

        -- 2. Updating Sales order line status in custom table for successfully shipped records
        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET vas_status = 'P', error_message = NULL, last_update_date = gd_sysdate,
                   request_id = gn_request_id, last_updated_by = gn_user_id
             WHERE     (order_header_id, order_line_id) IN
                           (SELECT source_header_id, source_line_id
                              FROM wsh_delivery_details
                             WHERE     source_code = 'OE'
                                   AND released_status = 'C')
                   AND vas_status = 'R';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error Updating shipped status in custom table xxd_ont_special_vas_info_t. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- 3. Updating Sales order line status in custom table for PO received status
        BEGIN
            FOR i IN get_rcv_ship_details_c
            LOOP
                ln_qty_received   := 0;
                ln_line_qty       := 0;

                SELECT SUM (quantity_received)
                  INTO ln_qty_received
                  FROM rcv_shipment_lines
                 WHERE     shipment_line_status_code = 'FULLY RECEIVED'
                       AND po_header_id = i.po_header_id;

                SELECT SUM (quantity)
                  INTO ln_line_qty
                  FROM po_lines_all
                 WHERE     po_header_id = i.po_header_id
                       AND NVL (cancel_flag, 'N') = 'N';

                IF ln_qty_received >= ln_line_qty
                THEN
                    UPDATE xxd_ont_special_vas_info_t x
                       SET vas_status = 'R', error_message = NULL, last_update_date = gd_sysdate,
                           last_updated_by = gn_user_id, request_id = gn_request_id
                     WHERE po_header_id = i.po_header_id;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error Updating PO Received status in custom table xxd_ont_special_vas_info_t. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- 4. Update other error status
        update_error_records ();

        -- 5. Cancelled Order Lines Update
        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET vas_status = 'X', error_message = 'Line Cancelled', cancelled_status = 'CANCELLED',
                   last_update_date = gd_sysdate, last_updated_by = gn_user_id, request_id = gn_request_id
             WHERE     order_line_status = 'CANCELLED'
                   AND NVL (cancelled_status, -1) <> 'CANCELLED'
                   AND vas_status <> 'X';

            fnd_file.put_line (
                fnd_file.LOG,
                SQL%ROWCOUNT || ' records updated with Line Cancelled status');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error Updating Line cancelled error in custom table xxd_ont_special_vas_info_t. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- 6. Cancelled Orders Update
        BEGIN
            UPDATE xxd_ont_special_vas_info_t x
               SET vas_status = 'X', error_message = 'Order Cancelled', cancelled_status = 'CANCELLED',
                   last_update_date = gd_sysdate, last_updated_by = gn_user_id, request_id = gn_request_id
             WHERE     order_status = 'CANCELLED'
                   AND NVL (cancelled_status, -1) <> 'CANCELLED'
                   AND vas_status <> 'X';

            fnd_file.put_line (
                fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' records updated with Order Cancelled status');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error Updating Order cancelled error in custom table xxd_ont_special_vas_info_t. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- 7. Already Processed Orders When Cancelled - Update
        BEGIN
            UPDATE xxd_ont_special_vas_info_t
               SET cancelled_status = 'CANCELLED', vas_status = 'X', --Added by Infosys for CCR0006770
                                                                     error_message = 'Line Cancelled', --Added by Infosys for CCR0006770
                   last_update_date = gd_sysdate, request_id = gn_request_id, last_updated_by = gn_user_id
             WHERE     order_line_id IN
                           (SELECT oola.line_id
                              FROM oe_order_lines_all oola
                             WHERE     oola.flow_status_code = 'CANCELLED'
                                   AND EXISTS
                                           (SELECT 1
                                              FROM xxd_ont_special_vas_info_t xosvit
                                             WHERE     oola.header_id =
                                                       xosvit.order_header_id
                                                   AND oola.line_id =
                                                       xosvit.order_line_id))
                   AND NVL (cancelled_status, -1) <> 'CANCELLED';

            fnd_file.put_line (
                fnd_file.LOG,
                   SQL%ROWCOUNT
                || ' already progressed records updated as Cancelled. ');
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error Updating progressed Order with cancellation status in custom table xxd_ont_special_vas_info_t. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;

        -- 8. Insert New Records
        insert_records_prc (lc_insert_prc_err, p_from_order, p_to_order,
                            ld_start_date, ld_end_date);

        IF lc_insert_prc_err IS NOT NULL
        THEN
            lc_errbuff   := 'Insertion into custom table failed.';
            fnd_file.put_line (fnd_file.LOG, lc_errbuff);
            RAISE user_exception;
        END IF;

        -- 9. Validate Special VAS Records
        validate_record_prc (lc_errbuff, p_from_order, p_to_order,
                             ld_start_date, ld_end_date);

        -- 10. PO Interface Insert
        create_po_prc (ln_interfaced_records);

        -- 11. PO Import
        IF ln_interfaced_records <> 0
        THEN
            submit_po_import_program (gn_request_id, ln_import_request_id);
        END IF;

        -- 12. PO Interface Status Update
        IF NVL (ln_import_request_id, 0) <> 0
        THEN
            update_interface_status (ln_import_request_id,
                                     gn_request_id,
                                     lc_upd_intf_status_error);
        END IF;

        -- 13. Successful PO Creation Update
        update_po_details (lc_errbuff);

        -- 14. Create Supply based Reservation
        create_supply_reservation (lc_errbuff);

        -- 15. Update Supply based Reservation to Demand based
        update_supply_reservation (lc_errbuff);

        -- 16. Port Attachments from SO to PO, if exists
        create_attachments (lc_errbuff);

        -- 17. Special VAS Report
        fnd_file.put_line (
            fnd_file.output,
               ' Special VAS Supply and Demand Management - Deckers '
            || CHR (10));

        fnd_file.put_line (
            fnd_file.output,
               'SALES ORDER NUMBER'
            || CHR (9)
            || 'LINE#'
            || CHR (9)
            || 'ITEM NUMBER'
            || CHR (9)
            || 'ORDERED QUANTITY'
            || CHR (9)
            || 'PO NUMBER'
            || CHR (9)
            || 'SUPPLIER'
            || CHR (9)
            || 'SUPPLIER SITE'
            || CHR (9)
            || 'DEMAND LOCATOR'
            || CHR (9)
            || 'SUPPLY IDENTIFIER'
            || CHR (9)
            || 'STATUS'
            || CHR (9)
            || 'ERROR MESSAGE');

        FOR rec_output_records IN cur_output_records
        LOOP
            fnd_file.put_line (
                fnd_file.output,
                   rec_output_records.order_number
                || CHR (9)
                || rec_output_records.order_line_num
                || CHR (9)
                || rec_output_records.ordered_item
                || CHR (9)
                || rec_output_records.ordered_quantity
                || CHR (9)
                || rec_output_records.po_number
                || CHR (9)
                || rec_output_records.vendor_name
                || CHR (9)
                || rec_output_records.vendor_site
                || CHR (9)
                || rec_output_records.demand_locator
                || CHR (9)
                || rec_output_records.supply_identifier
                || CHR (9)
                || rec_output_records.vas_status
                || CHR (9)
                || rec_output_records.error_message);
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN user_exception
        THEN
            p_retcode   := NVL (lc_retcode, 2);
            p_errbuff   := NVL (lc_errbuff, SQLERRM);
        WHEN OTHERS
        THEN
            p_retcode   := NVL (lc_retcode, 2);
            p_errbuff   := NVL (lc_errbuff, SQLERRM);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in Main.'
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
            fnd_file.put_line (fnd_file.LOG, 'SQLERRM=' || SQLERRM);
    END main;

    PROCEDURE special_vas_pur_report_prc (p_retcode OUT NOCOPY VARCHAR2, p_errbuff OUT NOCOPY VARCHAR2, p_start_date IN VARCHAR2
                                          , p_end_date IN VARCHAR2, p_buyer_id IN NUMBER, p_gtn_flag IN VARCHAR2)
    IS
        CURSOR get_details_c IS
              SELECT pha.creation_date,
                     xosv.po_number,
                     xosv.vendor_name,
                     xosv.vendor_site,
                     xosv.brand,
                     xosv.buyer_name,
                     xciv.style_number,
                     xciv.item_number,           --Added as part of PRB0041148
                     xciv.color_code,
                     xosv.ordered_quantity,
                     fnd_date.canonical_to_date (plla.attribute4)
                         xfactory_date,
                     plla.promised_date,
                     /*     TO_CHAR (gd_sysdate, 'MON')  -- --commented as part of PRB0041148
                       || ' '
                       || EXTRACT (YEAR FROM gd_sysdate) */
                     pha.attribute9              --Added as part of PRB0041148
                         buy_month,
                     DECODE (pha.attribute11, 'Y', 'Yes', 'No')
                         gtn_flag,
                     CASE
                         WHEN xosv.attachments_count > 0 THEN 'Yes'
                         ELSE 'No'
                     END
                         attachments,
                     xosv.order_number,
                     xosv.customer_name
                FROM xxd_ont_special_vas_info_t xosv, po_headers_all pha, po_line_locations_all plla,
                     xxd_common_items_v xciv
               WHERE     xosv.po_header_id = pha.po_header_id
                     AND pha.po_header_id = plla.po_header_id
                     AND plla.line_location_id = xosv.supply_identifier
                     AND NVL (pha.cancel_flag, 'N') = 'N'
                     AND xosv.inventory_item_id = xciv.inventory_item_id
                     AND xosv.inventory_org_id = xciv.organization_id
                     AND ((p_gtn_flag IS NOT NULL AND pha.attribute11 = p_gtn_flag) OR (p_gtn_flag IS NULL AND 1 = 1))
                     AND ((p_buyer_id IS NOT NULL AND pha.agent_id = p_buyer_id) OR (p_buyer_id IS NULL AND 1 = 1))
                     AND TRUNC (pha.creation_date) BETWEEN fnd_date.canonical_to_date (
                                                               p_start_date)
                                                       AND fnd_date.canonical_to_date (
                                                               p_end_date)
                     AND NVL (cancelled_status, 'n') <> 'CANCELLED'
            ORDER BY pha.creation_date, order_number, order_line_num;

        rec_details   get_details_c%ROWTYPE;
        lc_flag       VARCHAR2 (1) DEFAULT 'N';
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'PO Creation Date From - ' || fnd_date.canonical_to_date (p_start_date));
        fnd_file.put_line (
            fnd_file.LOG,
            'PO Creation Date To - ' || fnd_date.canonical_to_date (p_end_date));

        FOR rec_details IN get_details_c
        LOOP
            IF lc_flag = 'N'
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                       'PO_CREATION_DATE'
                    || CHR (9)
                    || 'PO_NUMBER'
                    || CHR (9)
                    || 'VENDOR_NAME'
                    || CHR (9)
                    || 'VENDOR_SITE'
                    || CHR (9)
                    || 'BRAND'
                    || CHR (9)
                    || 'BUYER_NAME'
                    || CHR (9)
                    || 'STYLE'
                    || CHR (9)
                    || 'COLOR'
                    || CHR (9)
                    || 'SKU'                     --Added as part of PRB0041148
                    || CHR (9)
                    || 'ORDERED_QUANTITY'
                    || CHR (9)
                    || 'XFACTORY_DATE'
                    || CHR (9)
                    || 'PROMISED_DATE'
                    || CHR (9)
                    || 'BUY_MONTH'
                    || CHR (9)
                    || 'GTN_TRANSFER_FLAG'
                    || CHR (9)
                    || 'ATTACHMENTS?'
                    || CHR (9)
                    || 'SALES_ORDER_NUMBER'
                    || CHR (9)
                    || 'CUSTOMER_NAME'
                    || CHR (9));
                lc_flag   := 'Y';
            END IF;

            fnd_file.put_line (
                fnd_file.output,
                   rec_details.creation_date
                || CHR (9)
                || rec_details.po_number
                || CHR (9)
                || rec_details.vendor_name
                || CHR (9)
                || rec_details.vendor_site
                || CHR (9)
                || rec_details.brand
                || CHR (9)
                || rec_details.buyer_name
                || CHR (9)
                || rec_details.style_number
                || CHR (9)
                || rec_details.color_code
                || CHR (9)
                || rec_details.item_number       --Added as part of PRB0041148
                || CHR (9)
                || rec_details.ordered_quantity
                || CHR (9)
                || rec_details.xfactory_date
                || CHR (9)
                || rec_details.promised_date
                || CHR (9)
                || rec_details.buy_month
                || CHR (9)
                || rec_details.gtn_flag
                || CHR (9)
                || rec_details.attachments
                || CHR (9)
                || rec_details.order_number
                || CHR (9)
                || rec_details.customer_name
                || CHR (9));
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'Report completed Successfully');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in special_vas_pur_report_prc procedure. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END special_vas_pur_report_prc;

    PROCEDURE special_vas_cs_report_prc (p_retcode OUT NOCOPY VARCHAR2, p_errbuff OUT NOCOPY VARCHAR2, p_start_date IN VARCHAR2, p_end_date IN VARCHAR2, p_customer_name IN VARCHAR2, p_customer_number IN VARCHAR2
                                         , p_cust_po_number IN VARCHAR2, p_brand IN VARCHAR2, p_style IN VARCHAR2)
    AS
        CURSOR get_details_c IS
              SELECT xosv.order_number,
                     ooha.flow_status_code
                         order_status,
                     ooha.ordered_date
                         order_date,
                     hca.account_number
                         cust_num,
                     hp.party_name
                         cust_name,
                     xosv.brand,
                     oola.request_date
                         start_ship_date,
                     oola.schedule_ship_date
                         schedule_date,
                     fnd_date.canonical_to_date (
                         NVL (oola.attribute1, ooha.attribute1))
                         cancel_date,
                     oola.line_number
                         order_line_num,
                     xciv.style_number
                         style,
                     xciv.color_code
                         color,
                     xciv.item_size
                         item_size,
                     xosv.ordered_quantity
                         order_qty,
                     xosv.order_quantity_uom
                         order_qty_uom,
                     xosv.inventory_org_code
                         inv_org_code,
                     pha.segment1
                         factory_po_num,
                     ooha.cust_po_number
                         cust_po_num,
                     fnd_date.canonical_to_date (plla.attribute4)
                         xfactory_date,
                     pla.line_num
                         factory_po_line_num,
                     pla.quantity
                         factory_po_qty,
                     plla.need_by_date,
                     plla.promised_date,
                     CASE
                         WHEN xosv.attachments_count > 0 THEN 'Yes'
                         ELSE 'No'
                     END
                         attachments,
                     xosv.error_message
                FROM xxd_ont_special_vas_info_t xosv, oe_order_headers_all ooha, oe_order_lines_all oola,
                     po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                     xxd_common_items_v xciv, hz_cust_accounts hca, hz_parties hp
               WHERE     xosv.order_header_id = ooha.header_id
                     AND ooha.header_id = oola.header_id
                     AND xosv.order_line_id = oola.line_id
                     AND xosv.po_header_id = pha.po_header_id
                     AND pha.po_header_id = pla.po_header_id
                     AND pla.po_line_id = plla.po_line_id
                     AND pha.po_header_id = plla.po_header_id
                     AND plla.line_location_id = xosv.supply_identifier
                     AND hca.cust_account_id = ooha.sold_to_org_id
                     AND hca.party_id = hp.party_id
                     AND NVL (pha.cancel_flag, 'N') = 'N'
                     AND xosv.inventory_item_id = xciv.inventory_item_id
                     AND xosv.inventory_org_id = xciv.organization_id
                     AND ((p_style IS NOT NULL AND xciv.style_number = p_style) OR (p_style IS NULL AND 1 = 1))
                     AND ((p_brand IS NOT NULL AND xciv.brand = p_brand) OR (p_brand IS NULL AND 1 = 1))
                     AND ((p_cust_po_number IS NOT NULL AND UPPER (ooha.cust_po_number) LIKE UPPER (p_cust_po_number)) OR (p_cust_po_number IS NULL AND 1 = 1))
                     AND ((p_customer_number IS NOT NULL AND hca.account_number = p_customer_number) OR (p_customer_number IS NULL AND 1 = 1))
                     AND ((p_customer_name IS NOT NULL AND UPPER (hp.party_name) LIKE UPPER (p_customer_name)) OR (p_customer_name IS NULL AND 1 = 1))
                     AND TRUNC (oola.request_date) BETWEEN fnd_date.canonical_to_date (
                                                               p_start_date)
                                                       AND fnd_date.canonical_to_date (
                                                               p_end_date)
                     AND NVL (cancelled_status, 'n') <> 'CANCELLED'
            ORDER BY oola.request_date, ooha.header_id, oola.line_number;

        rec_details   get_details_c%ROWTYPE;
        lc_flag       VARCHAR2 (1) DEFAULT 'N';
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Customer Start Ship Date From - ' || fnd_date.canonical_to_date (p_start_date));
        fnd_file.put_line (
            fnd_file.LOG,
            'Customer Start Ship Date To - ' || fnd_date.canonical_to_date (p_end_date));

        FOR rec_details IN get_details_c
        LOOP
            IF lc_flag = 'N'
            THEN
                fnd_file.put_line (
                    fnd_file.output,
                       'ORDER_NUM'
                    || CHR (9)
                    || 'ORDER_STATUS'
                    || CHR (9)
                    || 'ORDER_DATE'
                    || CHR (9)
                    || 'CUST_NUM'
                    || CHR (9)
                    || 'CUST_NAME'
                    || CHR (9)
                    || 'BRAND'
                    || CHR (9)
                    || 'START_SHIP_DATE'
                    || CHR (9)
                    || 'SCHEDULE_DATE'
                    || CHR (9)
                    || 'CANCEL_DATE'
                    || CHR (9)
                    || 'ORDER_LINE_NUM'
                    || CHR (9)
                    || 'STYLE'
                    || CHR (9)
                    || 'COLOR'
                    || CHR (9)
                    || 'SIZE'
                    || CHR (9)
                    || 'ORDER_QTY'
                    || CHR (9)
                    || 'ORDER_QTY_UOM'
                    || CHR (9)
                    || 'INV_ORG_CODE'
                    || CHR (9)
                    || 'FACTORY_PO_NUM'
                    || CHR (9)
                    || 'CUST_PO_NUM'
                    || CHR (9)
                    || 'XFACTORY_DATE'
                    || CHR (9)
                    || 'FACTORY_PO_LINE_NUM'
                    || CHR (9)
                    || 'FACTORY_PO_QTY'
                    || CHR (9)
                    || 'NEED_BY_DATE'
                    || CHR (9)
                    || 'PROMISE_DATE'
                    || CHR (9)
                    || 'ATTACHMENTS?'
                    || CHR (9)
                    || 'ERROR_MESSAGE'
                    || CHR (9));
                lc_flag   := 'Y';
            END IF;

            fnd_file.put_line (
                fnd_file.output,
                   rec_details.order_number
                || CHR (9)
                || rec_details.order_status
                || CHR (9)
                || rec_details.order_date
                || CHR (9)
                || rec_details.cust_num
                || CHR (9)
                || rec_details.cust_name
                || CHR (9)
                || rec_details.brand
                || CHR (9)
                || rec_details.start_ship_date
                || CHR (9)
                || rec_details.schedule_date
                || CHR (9)
                || rec_details.cancel_date
                || CHR (9)
                || rec_details.order_line_num
                || CHR (9)
                || rec_details.style
                || CHR (9)
                || rec_details.color
                || CHR (9)
                || rec_details.item_size
                || CHR (9)
                || rec_details.order_qty
                || CHR (9)
                || rec_details.order_qty_uom
                || CHR (9)
                || rec_details.inv_org_code
                || CHR (9)
                || rec_details.factory_po_num
                || CHR (9)
                || rec_details.cust_po_num
                || CHR (9)
                || rec_details.xfactory_date
                || CHR (9)
                || rec_details.factory_po_line_num
                || CHR (9)
                || rec_details.factory_po_qty
                || CHR (9)
                || rec_details.need_by_date
                || CHR (9)
                || rec_details.promised_date
                || CHR (9)
                || rec_details.attachments
                || CHR (9)
                || rec_details.error_message
                || CHR (9));
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'Report completed Successfully');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in special_vas_cs_report_prc procedure. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END special_vas_cs_report_prc;
END xxd_ont_special_vas_x_pkg;
/
