--
-- XXDOINT_PO_ORDER_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:38 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOINT_PO_ORDER_UTILS"
AS
    /**********************************************************************************************************
       file name    : XXDOINT_PO_ORDER_UTILS.pkb
       created on   : 10-NOV-2014
       created by   :
       purpose      : package specification used for the following
      ****************************************************************************
      Modification history:
     *****************************************************************************
         NAME:        XXDOINT_PO_ORDER_UTILS
         PURPOSE:      MIAN PROCEDURE
         REVISIONS:
         Version        Date        Author           Description
         ---------  ----------  ---------------  ------------------------------------
         1.1         9/11/2014                   1. Created this package body.
         1.2         9/11/2014      INFOSYS       modified procedures to replace view with the base tables.
         1.3         3/20/2018     GJensen        Added checks for POs altered for the NH move to provided corrected line IDs  CCR0007046
         1.4         1/23/2020     GJensen        Added functions to get vendor site ID/OU Name based on either PO Number or Inv Number CCR0008186
      **************************************************************************************************************/

    G_PKG_NAME   CONSTANT VARCHAR2 (40) := 'xxdoint_po_order_utils';
    g_n_temp              NUMBER;
    l_buffer_number       NUMBER;


    PROCEDURE msg (p_message IN VARCHAR2, p_debug_level IN NUMBER:= 10000)
    IS
    BEGIN
        apps.do_debug_tools.msg (p_msg           => p_message,
                                 p_debug_level   => p_debug_level);
    END;

    FUNCTION in_conc_request
        RETURN BOOLEAN
    IS
    BEGIN
        RETURN apps.fnd_global.conc_request_id != -1;
    END;


    FUNCTION get_po_header_id (p_po_number IN VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name   VARCHAR2 (240) := 'get_po_header_id';
        l_header_id   NUMBER;
    BEGIN
        /* -- Start W.r.t Version 1.2
          select po_header_id
          into l_header_id
          from xxdo.xxdoint_po_header_v
          where po_number = p_po_number;
          */
        SELECT po_header_id
          INTO l_header_id
          FROM po_headers_all
         WHERE segment1 = p_po_number;

        --End W.r.t version 1.2

        RETURN l_header_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_po_line_id (p_po_number IN VARCHAR2, p_line_number IN NUMBER, p_shipment_number IN NUMBER
                             , p_distribution_number IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name       VARCHAR2 (240) := 'get_po_line_id';
        l_line_id         NUMBER;
        l_mv_batch_name   VARCHAR2 (50);
    BEGIN
        --Begin CCR0007046
        --Added for PO Move

        BEGIN
            --Check for Batch_name in attribute13 of PO Header.
            SELECT attribute13
              INTO l_mv_batch_name
              FROM po_headers_all
             WHERE segment1 = p_po_number;

            --Try to find translated value for PO move
            IF l_mv_batch_name IS NOT NULL
            THEN
                SELECT pla1.po_line_id
                  INTO l_line_id
                  FROM apps.po_lines_all pla1, apps.po_headers_all pha, apps.po_lines_all pla
                 WHERE     pha.segment1 = p_po_number
                       AND pha.po_header_id = pla.po_header_id
                       AND pla1.attribute10 = pla.po_line_id --Link between closed PO line and new PO line
                       AND pla.po_header_id = pla1.po_header_id
                       AND NVL (pla.closed_code, 'OPEN') = 'CLOSED'
                       AND NVL (pla1.closed_code, 'OPEN') = 'OPEN'
                       AND pla.line_num = p_line_number;

                --return if alternate value found otherwise defer to current process
                IF l_line_id IS NOT NULL
                THEN
                    RETURN l_line_id;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        --End CCR0007046

        SELECT pla.po_line_id
          INTO l_line_id
          FROM apps.po_headers_all pha, apps.po_lines_all pla
         WHERE     pha.segment1 = p_po_number
               AND pha.po_header_id = pla.po_header_id
               AND pla.line_num = p_line_number;

        RETURN l_line_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;


    FUNCTION get_po_line_location_id (p_po_number IN VARCHAR2, p_line_number IN NUMBER, p_shipment_number IN NUMBER
                                      , p_distribution_number IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name       VARCHAR2 (240) := 'get_po_line_location_id';
        l_line_loc_id     NUMBER;
        l_mv_batch_name   VARCHAR2 (50);
    BEGIN
        /* --Start W.r.t version 1.2
         select line_location_id
          into l_line_loc_id
          from xxdo.xxdoint_po_lines_v pla
          where pla.po_number = p_po_number
            and pla.line_num = p_line_number
            and pla.shipment_num = p_shipment_number
            and pla.distribution_num = p_distribution_number;
        */

        --begin CCR0007046
        --Added for PO Move
        BEGIN
            --Check for Batch_name in attribute13 of PO Header.
            SELECT attribute13
              INTO l_mv_batch_name
              FROM po_headers_all
             WHERE segment1 = p_po_number;

            --Try to find translated value for PO move
            IF l_mv_batch_name IS NOT NULL
            THEN
                SELECT plla1.line_location_id
                  INTO l_line_loc_id
                  FROM apps.po_lines_all pla1, apps.po_line_locations_all plla1, apps.po_headers_all pha,
                       apps.po_lines_all pla, apps.po_line_locations_all plla
                 WHERE     pha.segment1 = p_po_number
                       AND pha.po_header_id = pla.po_header_id
                       AND pla1.attribute10 = pla.po_line_id --Link between closed PO line and new PO line
                       AND plla1.po_line_id = pla1.po_line_id
                       AND pla.po_line_id = plla.po_line_id
                       AND pla.po_header_id = pla1.po_header_id
                       AND plla.shipment_num = p_shipment_number
                       AND NVL (pla.closed_code, 'OPEN') = 'CLOSED'
                       AND NVL (pla1.closed_code, 'OPEN') = 'OPEN'
                       AND pla.line_num = p_line_number;

                --return if alternate value found  otherwise defer to current process
                IF l_line_loc_id IS NOT NULL
                THEN
                    RETURN l_line_loc_id;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        --End CCR0007046
        SELECT plla.line_location_id
          INTO l_line_loc_id
          FROM po_lines_all pla, po_headers_all pha, po_line_locations_all plla
         WHERE     pla.po_line_id = plla.po_line_id
               AND pha.po_header_id = pla.po_header_id
               AND pha.segment1 = p_po_number
               AND pla.line_num = p_line_number
               AND plla.shipment_num = p_shipment_number;

        --End W.r.t version 1.2

        RETURN l_line_loc_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_po_line_unit_price (p_po_number IN VARCHAR2, p_line_number IN NUMBER, p_shipment_number IN NUMBER
                                     , p_distribution_number IN NUMBER)
        RETURN NUMBER
    IS
        l_proc_name       VARCHAR2 (240) := 'get_po_line_unit_price';
        l_price           NUMBER;
        l_mv_batch_name   VARCHAR2 (50);
    BEGIN
        /*  --Start W.r.t version 1.2
         select unit_price
          into l_price
          from xxdo.     pla
          where pla.po_number = p_po_number
            and pla.line_num = p_line_number
            and pla.shipment_num = p_shipment_number
            and pla.distribution_num = p_distribution_number;
            */
        --Begin CCR0007046
        --Added for PO Move

        BEGIN
            --Check for Batch_name in attribute13 of PO Header.
            SELECT attribute13
              INTO l_mv_batch_name
              FROM po_headers_all
             WHERE segment1 = p_po_number;


            --Try to find translated value for PO move
            IF l_mv_batch_name IS NOT NULL
            THEN
                SELECT pla1.unit_price
                  INTO l_price
                  FROM apps.po_lines_all pla1, apps.po_headers_all pha, apps.po_lines_all pla
                 WHERE     pha.segment1 = p_po_number
                       AND pha.po_header_id = pla.po_header_id
                       AND pla1.attribute10 = pla.po_line_id --Link between closed PO line and new PO line
                       AND pla.po_header_id = pla1.po_header_id
                       AND NVL (pla.closed_code, 'OPEN') = 'CLOSED'
                       AND NVL (pla1.closed_code, 'OPEN') = 'OPEN'
                       AND pla.line_num = p_line_number;

                --return if alternate value found  otherwise defer to current process
                IF l_price IS NOT NULL
                THEN
                    RETURN l_price;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        --End CCR0007046

        SELECT unit_price
          INTO l_price
          FROM po_lines_all pla, po_headers_all pha
         WHERE     1 = 1
               AND pha.po_header_id = pla.po_header_id
               AND pha.segment1 = p_po_number
               AND pla.line_num = p_line_number;

        --End W.r.t version 1.2

        RETURN l_price;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    --Start CCR0008186
    FUNCTION get_po_ship_to_name (p_po_number    IN VARCHAR2 := NULL,
                                  p_inv_number   IN VARCHAR2 := NULL)
        RETURN VARCHAR2
    IS
        ln_po_header_id        NUMBER;
        lv_organization_code   VARCHAR2 (10);
        lv_account_name        VARCHAR2 (240);
        lv_ship_to_org         VARCHAR2 (10);
    BEGIN
        IF p_po_number IS NOT NULL
        THEN
            SELECT pha.po_header_id
              INTO ln_po_header_id
              FROM po_headers_all pha
             WHERE pha.segment1 = p_po_number;
        ELSIF p_inv_number IS NOT NULL
        THEN
            SELECT MIN (pha.po_header_id)
              INTO ln_po_header_id
              FROM custom.do_shipments s, custom.do_containers c, custom.do_orders o,
                   po_headers_all pha
             WHERE     o.order_id = pha.po_header_id
                   AND o.container_id = c.container_id
                   AND c.shipment_id = s.shipment_id
                   AND s.invoice_num = p_inv_number;
        END IF;

        IF ln_po_header_id IS NOT NULL
        THEN
            BEGIN
                --DSS/Japan TQ (Drop ship link)
                SELECT DISTINCT hzp.party_name
                  INTO lv_account_name
                  FROM oe_drop_ship_sources dss, oe_order_lines_all oola, hz_cust_accounts hzca,
                       hz_parties hzp
                 WHERE     dss.line_id = oola.line_id
                       AND oola.sold_to_org_id = hzca.cust_account_id
                       AND hzca.party_id = hzp.party_id
                       AND dss.po_header_id = ln_po_header_id;


                RETURN lv_account_name;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    BEGIN
                        --Interco/Direct Ship (Attribute16 link )
                        SELECT DISTINCT hzp.party_name, mp.organization_code
                          INTO lv_account_name, lv_ship_to_org
                          FROM po_line_locations_all plla,
                               (SELECT *
                                  FROM oe_order_lines_all
                                 WHERE NVL (context, '-NONE-') !=
                                       'DO eCommerce') oola,
                               hz_cust_accounts hzca,
                               hz_parties hzp,
                               po_requisition_lines_all prla,
                               mtl_parameters mp
                         WHERE     oola.attribute16 =
                                   TO_CHAR (plla.line_location_id)
                               AND oola.sold_to_org_id = hzca.cust_account_id
                               AND hzca.party_id = hzp.party_id
                               AND prla.destination_organization_id =
                                   mp.organization_id(+)
                               AND prla.requisition_line_id(+) =
                                   oola.source_document_line_id
                               AND plla.po_header_id = ln_po_header_id;

                        IF lv_ship_to_org IS NOT NULL
                        THEN
                            RETURN lv_ship_to_org;
                        ELSE
                            RETURN lv_account_name;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            BEGIN
                                --Special vas link
                                SELECT DISTINCT hzca.account_name
                                  INTO lv_account_name
                                  FROM po_line_locations_all plla,
                                       (SELECT *
                                          FROM oe_order_lines_all
                                         WHERE NVL (context, '-NONE-') !=
                                               'DO eCommerce') oola,
                                       hz_cust_accounts hzca
                                 WHERE     oola.attribute15 =
                                           TO_CHAR (plla.line_location_id)
                                       AND oola.sold_to_org_id =
                                           hzca.cust_account_id
                                       AND plla.po_header_id =
                                           ln_po_header_id;

                                RETURN lv_account_name;
                            EXCEPTION
                                WHEN NO_DATA_FOUND
                                THEN
                                    BEGIN
                                        SELECT DISTINCT mp.organization_code
                                          INTO lv_ship_to_org
                                          FROM po_line_locations_all plla, mtl_parameters mp
                                         WHERE     plla.ship_to_organization_id =
                                                   mp.organization_id
                                               AND plla.po_header_id =
                                                   ln_po_header_id;

                                        RETURN lv_ship_to_org;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            RETURN NULL;
                                    END;
                            END;
                        WHEN OTHERS
                        THEN
                            RETURN NULL;
                    END;
                WHEN OTHERS
                THEN
                    RETURN NULL;
            END;
        END IF;

        RETURN NULL;
    EXCEPTION                                  --Any type of error return null
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_po_vendor_site_id (p_po_number    IN VARCHAR2 := NULL,
                                    p_inv_number   IN VARCHAR2 := NULL)
        RETURN NUMBER
    IS
        ln_vendor_site_id   NUMBER;
    BEGIN
        IF p_po_number IS NOT NULL
        THEN                --Most specific case. Get OU from custom.do_orders
            SELECT DISTINCT pha.vendor_site_id
              INTO ln_vendor_site_id
              FROM po_headers_all pha
             WHERE pha.segment1 = p_po_number;
        ELSIF p_inv_number IS NOT NULL
        THEN
            SELECT DISTINCT pha.vendor_site_id
              INTO ln_vendor_site_id
              FROM custom.do_shipments s, custom.do_containers c, custom.do_orders o,
                   po_headers_all pha
             WHERE     o.order_id = pha.po_header_id
                   AND o.container_id = c.container_id
                   AND c.shipment_id = s.shipment_id
                   AND s.invoice_num = p_inv_number;
        ELSE                          --neither parameter passed / return null
            RETURN NULL;
        END IF;

        RETURN ln_vendor_site_id;
    EXCEPTION                                  --Any type of error return null
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_po_ou_name (p_po_number IN VARCHAR2:= NULL, p_inv_number IN VARCHAR2:= NULL, p_le_name IN VARCHAR2:= NULL)
        RETURN VARCHAR2
    IS
        lv_ou_name   VARCHAR2 (100);
    BEGIN
        IF p_po_number IS NOT NULL
        THEN                --Most specific case. Get OU from custom.do_orders
            SELECT DISTINCT hr.name
              INTO lv_ou_name
              FROM po_headers_all pha, hr_all_organization_units hr
             WHERE     pha.segment1 = p_po_number
                   AND pha.org_id = hr.organization_id;
        ELSIF p_inv_number IS NOT NULL
        THEN
            SELECT DISTINCT hr.name
              INTO lv_ou_name
              FROM custom.do_shipments s, custom.do_containers c, custom.do_orders o,
                   po_headers_all pha, hr_all_organization_units hr
             WHERE     o.order_id = pha.po_header_id
                   AND o.container_id = c.container_id
                   AND c.shipment_id = s.shipment_id
                   AND s.invoice_num = p_inv_number
                   AND pha.org_id = hr.organization_id;
        ELSE                          --neither parameter passed / return null
            IF p_le_name IS NOT NULL
            THEN
                SELECT DISTINCT hr.name ou_name
                  INTO lv_ou_name
                  --  INTO lv_le_name
                  FROM apps.xle_entity_profiles xep, apps.xle_registrations reg, --
                                                                                 apps.hr_operating_units hou,
                       -- hr_all_organization_units      hr_ou,
                       apps.hr_all_organization_units_tl hr_outl, apps.hr_all_organization_units hr, apps.hr_locations_all hr_loc,
                       --
                       apps.gl_legal_entities_bsvs glev
                 WHERE     1 = 1
                       AND xep.transacting_entity_flag = 'Y'
                       AND xep.legal_entity_id = reg.source_id
                       AND reg.source_table = 'XLE_ENTITY_PROFILES'
                       AND reg.identifying_flag = 'Y'
                       AND xep.legal_entity_id = hou.default_legal_context_id
                       AND reg.location_id = hr_loc.location_id
                       AND xep.legal_entity_id = glev.legal_entity_id
                       AND hr_outl.organization_id = hou.organization_id
                       AND hr_outl.organization_id = hr.organization_id
                       AND NVL2 (hr.attribute7,
                                 xep.name || '-' || hr.attribute7,
                                 xep.name) =
                           p_le_name;
            ELSE
                RETURN NULL;
            END IF;
        END IF;

        RETURN lv_ou_name;
    EXCEPTION                                  --Any type of error return null
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --End CCR0008186


    FUNCTION get_vendor_site_id (p_vendor_number IN VARCHAR2, p_vendor_site_code IN VARCHAR2, p_business_unit IN VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name   VARCHAR2 (240) := 'get_vendor_site_id';
        l_vs_id       NUMBER;
    BEGIN
        SELECT vs.vendor_site_id
          INTO l_vs_id
          FROM apps.po_vendors v, apps.po_vendor_sites_all vs, apps.hr_all_organization_units hr_ou
         WHERE     v.vendor_id = vs.vendor_id
               AND vs.org_id = hr_ou.organization_id
               AND v.segment1 = p_vendor_number
               AND vs.vendor_site_code = p_vendor_site_code
               AND hr_ou.name = p_business_unit;

        RETURN l_vs_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;


    FUNCTION get_vendor_id (p_vendor_number IN VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name   VARCHAR2 (240) := 'get_vendor_id';
        l_v_id        NUMBER;
    BEGIN
        SELECT v.vendor_id
          INTO l_v_id
          FROM apps.po_vendors v
         WHERE v.segment1 = p_vendor_number;

        RETURN l_v_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;


    FUNCTION business_name_to_org_id (p_bu_name IN VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name   VARCHAR2 (240) := 'business_name_to_org_id';
        l_org_id      NUMBER;
    BEGIN
        SELECT hr_ou.organization_id
          INTO l_org_id
          FROM apps.hr_all_organization_units hr_ou
         WHERE hr_ou.name = p_bu_name;

        RETURN l_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION org_code_to_org_id (p_org_code IN VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name   VARCHAR2 (240) := 'org_code_to_org_id';
        l_org_id      NUMBER;
    BEGIN
        SELECT organization_id
          INTO l_org_id
          FROM apps.mtl_parameters
         WHERE organization_code = p_org_code;

        RETURN l_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;


    FUNCTION get_dest_org_id (p_po_number IN VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name       VARCHAR2 (240) := 'get_dest_org_id';
        l_org_code        VARCHAR2 (240);
        l_org_id          NUMBER;
        l_mv_batch_name   VARCHAR2 (50);
    BEGIN
        --Begin CCR0007046
        --Added for PO Move

        BEGIN
            --Check for Batch_name in attribute13 of PO Header.
            SELECT attribute13
              INTO l_mv_batch_name
              FROM po_headers_all
             WHERE segment1 = p_po_number;

            --Try to find translated value for PO move
            IF l_mv_batch_name IS NOT NULL
            THEN
                SELECT DISTINCT mp.organization_id
                  INTO l_org_id
                  FROM apps.po_lines_all pla1, apps.po_line_locations_all plla1, apps.po_headers_all pha,
                       apps.po_lines_all pla, apps.po_line_locations_all plla, apps.mtl_parameters mp
                 WHERE     pha.segment1 = p_po_number
                       AND pha.po_header_id = pla.po_header_id
                       AND pla1.attribute10 = pla.po_line_id --Link between closed PO line and new PO line
                       AND plla1.po_line_id = pla1.po_line_id
                       AND pla.po_line_id = plla.po_line_id
                       AND plla1.ship_to_organization_id = mp.organization_id
                       AND NVL (pla.closed_code, 'OPEN') = 'CLOSED'
                       AND NVL (pla1.closed_code, 'OPEN') = 'OPEN';


                --return if alternate value found otherwise defer to current process
                IF l_org_id IS NOT NULL
                THEN
                    RETURN l_org_id;
                END IF;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

          --End CCR0007046

          SELECT mp.organization_id
            INTO l_org_id
            FROM po_headers_all ph, po_line_locations_all pll, apps.mtl_parameters mp
           WHERE     ph.po_header_id = pll.po_header_id
                 AND pll.ship_to_organization_id = mp.organization_id
                 AND ph.segment1 = p_po_number
        GROUP BY mp.organization_id;

        RETURN l_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;

    FUNCTION get_dest_org_location_id (p_org_id IN VARCHAR2)
        RETURN NUMBER
    IS
        l_proc_name     VARCHAR2 (240) := 'get_destination_org_location_id';
        l_location_id   NUMBER;
    BEGIN
        SELECT hr_ou.location_id
          INTO l_location_id
          FROM apps.hr_all_organization_units hr_ou
         WHERE hr_ou.organization_id = p_org_id;

        RETURN l_location_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            msg (
                   'Unhandled exception in function '
                || G_PKG_NAME
                || '.'
                || l_proc_name);
            msg ('-' || G_PKG_NAME || '.' || l_proc_name);
            RETURN NULL;
    END;
END;
/


GRANT EXECUTE ON APPS.XXDOINT_PO_ORDER_UTILS TO SOA_INT
/
