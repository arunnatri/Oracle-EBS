--
-- XXDOASCP_PLAN_ATTR_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:41:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOASCP_PLAN_ATTR_PKG"
AS
    FUNCTION xxdo_get_japan_intransit_time (p_category_id NUMBER)
        RETURN NUMBER
    IS
        lc_transit_days_US_JP   VARCHAR2 (100) := 0;
        lc_transit_days_APAC    VARCHAR2 (100) := 0;
        l_vendor_name           mrp_sr_source_org_v.vendor_name%TYPE;
        l_vendor_site           mrp_sr_source_org_v.vendor_site%TYPE;
        lc_vendor_type          ap_suppliers.VENDOR_TYPE_LOOKUP_CODE%TYPE;
        lc_transit_time         NUMBER;
    BEGIN
        --Finding Vendor Name and Vendor Site for US-JP
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
                   AND SYSDATE BETWEEN msrov.effective_date
                                   AND TRUNC (
                                           NVL (msrov.disable_date,
                                                SYSDATE + 1))
                   AND mrp.attribute1 = 'US-JP';
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_transit_days_US_JP   := 0;
        END;

        BEGIN
            SELECT VENDOR_TYPE_LOOKUP_CODE
              INTO lc_vendor_type
              FROM ap_suppliers
             WHERE vendor_id = l_vendor_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_vendor_type   := NULL;
        END;

        IF lc_vendor_type = 'TQ PROVIDER'
        THEN
            BEGIN
                SELECT                                --    start changes V2.1
                                                            --      attribute6
                      DECODE (UPPER (attribute8),  'AIR', attribute5,  'OCEAN', attribute6,  'TRUCK', attribute7,  attribute6)
                 --End Changes V2.1
                 INTO lc_transit_days_US_JP
                 FROM fnd_lookup_values
                WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                      AND language = 'US'
                      AND attribute4 = 'Japan'
                      AND attribute1 = l_vendor_name
                      AND attribute2 = l_vendor_site;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_transit_days_US_JP   := 0;
            END;
        ELSE
            lc_transit_days_US_JP   := 0;
        END IF;

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
                   AND SYSDATE BETWEEN msrov.effective_date
                                   AND TRUNC (
                                           NVL (msrov.disable_date,
                                                SYSDATE + 1))
                   AND mrp.attribute1 = 'APAC';
        EXCEPTION
            WHEN OTHERS
            THEN
                RETURN 0;
        END;

        BEGIN
            SELECT                                    --    start changes V2.1
                                                                            --
                                                                  --attribute6
                  DECODE (UPPER (attribute8),  'AIR', attribute5,  'OCEAN', attribute6,  'TRUCK', attribute7,  attribute6)
             --End Changes V2.1
             INTO lc_transit_days_APAC
             FROM fnd_lookup_values
            WHERE     lookup_type = 'XXDO_SUPPLIER_INTRANSIT'
                  AND language = 'US'
                  AND attribute4 = 'Japan'
                  AND attribute1 = l_vendor_name
                  AND attribute2 = l_vendor_site;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_transit_days_APAC   := 0;
        END;

        lc_transit_time   :=
            NVL (lc_transit_days_APAC, 0) + NVL (lc_transit_days_US_JP, 0);
        RETURN lc_transit_time;
    END xxdo_get_japan_intransit_time;
END xxdoascp_plan_attr_pkg;
/
