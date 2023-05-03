--
-- XXDO_AP_REPORT_UTIL  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:31 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_AP_REPORT_UTIL"
IS
    --  Purpose: Briefly explain the functionality of the package
    --  Active Vendors that have NO AP Invoice or Purchase Order History since :through_date - In this case we're using 31-MAR-2008
    --  Where these vendors also have NO invoices or POs that are open.
    --  Change for Defect:
    --  Exclude any suppliers for which any activities (PO, Invoice, Payment) has happened after the cutoff date irrespective of status
    --  MODIFICATION HISTORY
    --  Person                      Version         Date                    Comments
    ---------                   -------         ------------            -----------------------------------------
    --  Shibu                       V1.0            1/11/11
    --  Srinath                     V1.1            02-OCT-2014             Exclude any suppliers for which any activities (PO, Invoice, Payment) has happened
    --after the cutoff date irrespective of status
    --  Srinath                     V1.2            18-May-2015             Retrofit for BT project
    --  Infosys                     V1.3            10-Aug-2017             CCR0006586 - Changes identified by CCR0006586
    --  ---------                   ------          -----------             ------------------------------------------
    PROCEDURE run_active_vendors (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_through_date IN VARCHAR2, p_upd_yn IN VARCHAR2 DEFAULT 'N', p_level IN VARCHAR2, p_is_level_site IN VARCHAR2, p_operating_unit IN NUMBER, p_incl_supplier_type IN VARCHAR2, p_incl_sup_type_passed IN NUMBER
                                  , p_excl_supplier_type IN VARCHAR2)
    IS
        --      CURSOR c1 (l_date DATE)
        --      IS
        --           SELECT   v.vendor_name, v.segment1 vendor_number, v.vendor_id,
        --                 MAX (max_trx_date) max_ap_or_po_or_pay_trx_date
        --            FROM (SELECT   i.vendor_id, MAX (i.invoice_date) max_trx_date
        --                      FROM apps.ap_invoices_all i,
        --                           --apps.po_vendors v
        --                           apps.ap_suppliers v
        --                     WHERE i.vendor_id = v.vendor_id
        --                       AND v.end_date_active IS NULL                  -- Active vendor
        --                  GROUP BY i.vendor_id
        --                    HAVING MAX (TRUNC (i.invoice_date)) <= l_date
        --                  UNION
        --                  SELECT   poh.vendor_id, MAX (poh.creation_date) max_trx_date
        --                      FROM apps.po_headers_all poh,
        --                           --apps.po_vendors v
        --                           apps.ap_suppliers v
        --                     WHERE poh.vendor_id = v.vendor_id
        --                       AND v.end_date_active IS NULL                  -- Active vendor
        --                  GROUP BY poh.vendor_id
        --                    HAVING MAX (TRUNC (poh.creation_date)) <= l_date
        --                    /*added by srinath for DFCT0010961*/
        --                  UNION
        --                  SELECT   pv.vendor_id, MAX (aipa.creation_date)
        --                      FROM apps.ap_invoice_payments_all aipa,
        --                           --apps.po_vendors pv,
        --                           apps.ap_suppliers pv,
        --                           apps.ap_invoices_all aia
        --                     WHERE aia.vendor_id = pv.vendor_id
        --                       AND aia.invoice_id = aipa.invoice_id
        --                       AND pv.end_date_active IS NULL
        --                  GROUP BY pv.vendor_id
        --                    HAVING MAX (TRUNC (aipa.creation_date)) <= l_date
        --                    /*added by srinath for DFCT0010961*/
        --                    ) old_vdr,
        --                 --apps.po_vendors v
        --                 apps.ap_suppliers v
        --           WHERE old_vdr.vendor_id = v.vendor_id
        --             AND NOT EXISTS (
        --                    SELECT 1                          -- Open Unpaid AP Invoice Exists
        --                      FROM apps.ap_invoices_all i
        --                     WHERE i.vendor_id = old_vdr.vendor_id
        --                       AND (     NVL (i.invoice_amount, 0)
        --                               - NVL (i.amount_paid, 0)
        --                               - NVL (i.discount_amount_taken, 0) <> 0
        --                            OR TRUNC (i.invoice_date) > l_date
        --                           -- added by srinath on 02-OCT-2014 for DFCT0010961
        --                           ))
        --             AND NOT EXISTS (
        --                    SELECT 1                                    -- Open Purchase Order
        --                      FROM apps.po_headers_all poh
        --                     WHERE poh.vendor_id = old_vdr.vendor_id
        --                       AND (   NVL (poh.closed_code, 'OPEN') = 'OPEN'
        --                            OR TRUNC (poh.creation_date) > l_date
        --                           -- added by srinath on 02-OCT-2014 for DFCT0010961
        --                           ))
        --             /*added by srinath for DFCT0010961*/
        --             AND NOT EXISTS (
        --                    SELECT 1
        --                      FROM apps.ap_invoice_payments_all apsa,
        --                           apps.ap_invoices_all aia1
        --                     WHERE aia1.invoice_id = apsa.invoice_id
        --                       AND aia1.vendor_id = old_vdr.vendor_id
        --                       AND TRUNC (apsa.creation_date) > l_date)
        --             /*added by srinath for DFCT0010961*/
        --        GROUP BY v.vendor_name, v.segment1, v.vendor_id
        --        ORDER BY v.vendor_name;


        l_through_date      DATE;
        l_heading           VARCHAR2 (3000);
        l_line              VARCHAR2 (4000);
        l_sysdate           VARCHAR2 (20);
        l_return_status     VARCHAR2 (200);
        l_msg_count         NUMBER;
        l_msg_data          VARCHAR2 (2000);
        l_vendor_rec        apps.ap_vendor_pub_pkg.r_vendor_rec_type;
        l_vendor_site_rec   AP_VENDOR_PUB_PKG.r_vendor_site_rec_type;
        l_msg               VARCHAR2 (2000);


        CURSOR cur_suppliers (l_date                 DATE,
                              l_incl_supplier_type   VARCHAR2,
                              l_excl_supplier_type   VARCHAR2)
        IS
              SELECT v.vendor_name,
                     v.segment1 vendor_number,
                     v.vendor_id,
                     v.vendor_type_lookup_code vendor_type,
                     DECODE (
                         GREATEST (
                             (SELECT NVL (MAX (i.invoice_date), '01-JAN-1990')
                                FROM apps.ap_invoices_all i
                               WHERE i.vendor_id = v.vendor_id),
                             (SELECT NVL (MAX (poh.creation_date), '01-JAN-1990')
                                FROM apps.po_headers_all poh
                               WHERE poh.vendor_id = v.vendor_id),
                             (SELECT NVL (MAX (aipa.creation_date), '01-JAN-1990')
                                FROM apps.ap_invoice_payments_all aipa, apps.ap_invoices_all aia
                               WHERE     aia.vendor_id = v.vendor_id
                                     AND aia.invoice_id = aipa.invoice_id)),
                         '01-JAN-90', NULL,
                         GREATEST (
                             (SELECT NVL (MAX (i.invoice_date), '01-JAN-1990')
                                FROM apps.ap_invoices_all i
                               WHERE i.vendor_id = v.vendor_id),
                             (SELECT NVL (MAX (poh.creation_date), '01-JAN-1990')
                                FROM apps.po_headers_all poh
                               WHERE poh.vendor_id = v.vendor_id),
                             (SELECT NVL (MAX (aipa.creation_date), '01-JAN-1990')
                                FROM apps.ap_invoice_payments_all aipa, apps.ap_invoices_all aia
                               WHERE     aia.vendor_id = v.vendor_id
                                     AND aia.invoice_id = aipa.invoice_id))) max_ap_or_po_or_pay_trx_date
                --                     GREATEST (
                --                         (SELECT MAX (i.invoice_date) max_trx_date
                --                            FROM apps.ap_invoices_all i
                --                           WHERE i.vendor_id = v.vendor_id),
                --                         (SELECT MAX (poh.creation_date) max_trx_date
                --                            FROM apps.po_headers_all poh
                --                           WHERE poh.vendor_id = v.vendor_id),
                --                         (SELECT MAX (aipa.creation_date)
                --                            FROM apps.ap_invoice_payments_all aipa,
                --                                 apps.ap_invoices_all        aia
                --                           WHERE     aia.vendor_id = v.vendor_id
                --                                 AND aia.invoice_id = aipa.invoice_id))
                --                         max_ap_or_po_or_pay_trx_date
                FROM apps.ap_suppliers v
               WHERE     1 = 1
                     AND v.end_date_active IS NULL
                     AND NVL (v.vendor_type_lookup_code, 'X') =
                         NVL (l_incl_supplier_type,
                              NVL (v.vendor_type_lookup_code, 'X'))
                     AND NVL (v.vendor_type_lookup_code, 'X') <>
                         NVL (l_excl_supplier_type, 'Y')
                     AND NOT EXISTS
                             (SELECT 1        -- Open Unpaid AP Invoice Exists
                                FROM apps.ap_invoices_all i
                               WHERE     i.vendor_id = v.vendor_id
                                     AND (NVL (i.invoice_amount, 0) - NVL (i.amount_paid, 0) - NVL (i.discount_amount_taken, 0) <> 0 OR TRUNC (i.invoice_date) > l_date))
                     AND NOT EXISTS
                             (SELECT 1                  -- Open Purchase Order
                                FROM apps.po_headers_all poh
                               WHERE     poh.vendor_id = v.vendor_id
                                     AND (NVL (poh.closed_code, 'OPEN') = 'OPEN' OR TRUNC (poh.creation_date) > l_date))
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.ap_invoice_payments_all apsa, apps.ap_invoices_all aia1
                               WHERE     aia1.invoice_id = apsa.invoice_id
                                     AND aia1.vendor_id = v.vendor_id
                                     AND TRUNC (apsa.creation_date) > l_date)
            ORDER BY v.vendor_name;

        CURSOR cur_supplier_sites (l_date DATE, l_incl_supplier_type VARCHAR2, l_excl_supplier_type VARCHAR2
                                   , l_operating_unit NUMBER)
        IS
              SELECT v.vendor_name,
                     v.segment1 vendor_number,
                     v.vendor_id,
                     v.vendor_type_lookup_code vendor_type,
                     vs.vendor_site_code,
                     hou.name operating_unit,
                     vs.org_id,
                     vs.vendor_site_id,
                     DECODE (
                         GREATEST (
                             (SELECT NVL (MAX (i.invoice_date), '01-JAN-1990')
                                FROM apps.ap_invoices_all i
                               WHERE     i.vendor_id = v.vendor_id
                                     AND i.vendor_site_id = vs.vendor_site_id),
                             (SELECT NVL (MAX (poh.creation_date), '01-JAN-1990')
                                FROM apps.po_headers_all poh
                               WHERE     poh.vendor_id = v.vendor_id
                                     AND poh.vendor_site_id = vs.vendor_site_id),
                             (SELECT NVL (MAX (aipa.creation_date), '01-JAN-1990')
                                FROM apps.ap_invoice_payments_all aipa, apps.ap_invoices_all aia
                               WHERE     aia.vendor_id = v.vendor_id
                                     AND aia.invoice_id = aipa.invoice_id
                                     AND aia.vendor_site_id = vs.vendor_site_id)),
                         '01-JAN-90', NULL,
                         GREATEST (
                             (SELECT NVL (MAX (i.invoice_date), '01-JAN-1990')
                                FROM apps.ap_invoices_all i
                               WHERE     i.vendor_id = v.vendor_id
                                     AND i.vendor_site_id = vs.vendor_site_id),
                             (SELECT NVL (MAX (poh.creation_date), '01-JAN-1990')
                                FROM apps.po_headers_all poh
                               WHERE     poh.vendor_id = v.vendor_id
                                     AND poh.vendor_site_id = vs.vendor_site_id),
                             (SELECT NVL (MAX (aipa.creation_date), '01-JAN-1990')
                                FROM apps.ap_invoice_payments_all aipa, apps.ap_invoices_all aia
                               WHERE     aia.vendor_id = v.vendor_id
                                     AND aia.invoice_id = aipa.invoice_id
                                     AND aia.vendor_site_id = vs.vendor_site_id))) max_ap_or_po_or_pay_trx_date
                FROM apps.ap_suppliers v, ap_supplier_sites_all vs, hr_operating_units hou
               WHERE     1 = 1                           --v.vendor_id= 181022
                     AND v.end_date_active IS NULL
                     AND vs.inactive_date IS NULL
                     AND v.vendor_id = vs.vendor_id
                     AND vs.org_id = NVL (l_operating_unit, vs.org_id)
                     AND vs.org_id = hou.organization_id
                     AND NVL (v.vendor_type_lookup_code, 'X') =
                         NVL (l_incl_supplier_type,
                              NVL (v.vendor_type_lookup_code, 'X'))
                     AND NVL (v.vendor_type_lookup_code, 'X') <>
                         NVL (l_excl_supplier_type, 'Y')
                     AND NOT EXISTS
                             (SELECT 1        -- Open Unpaid AP Invoice Exists
                                FROM apps.ap_invoices_all i
                               WHERE     i.vendor_id = v.vendor_id
                                     AND i.vendor_site_id = vs.vendor_site_id
                                     AND (NVL (i.invoice_amount, 0) - NVL (i.amount_paid, 0) - NVL (i.discount_amount_taken, 0) <> 0 OR TRUNC (i.invoice_date) > l_date))
                     AND NOT EXISTS
                             (SELECT 1                  -- Open Purchase Order
                                FROM apps.po_headers_all poh
                               WHERE     poh.vendor_id = v.vendor_id
                                     AND poh.vendor_site_id = vs.vendor_site_id
                                     AND (NVL (poh.closed_code, 'OPEN') = 'OPEN' OR TRUNC (poh.creation_date) > l_date))
                     AND NOT EXISTS
                             (SELECT 1
                                FROM apps.ap_invoice_payments_all apsa, apps.ap_invoices_all aia1
                               WHERE     aia1.invoice_id = apsa.invoice_id
                                     AND aia1.vendor_id = v.vendor_id
                                     AND aia1.vendor_site_id =
                                         vs.vendor_site_id
                                     AND TRUNC (apsa.creation_date) > l_date)
            ORDER BY hou.name, v.vendor_name;
    BEGIN
        l_through_date   := apps.fnd_date.canonical_to_date (p_through_date);

        SELECT TO_CHAR (TRUNC (SYSDATE), 'DD-MON-RRRR')
          INTO l_sysdate
          FROM DUAL;

        --        IF p_upd_yn = 'Y'
        --        THEN
        --            l_heading :=
        --                'The below vendors got IN-ACTIVE as of:- ' || l_sysdate;
        --            apps.fnd_file.put_line (apps.fnd_file.output, l_heading);
        --        END IF;

        l_heading        :=
               'Vendor Name'
            || CHR (9)
            || 'Vendor Number'
            || CHR (9)
            || 'Vendor Type'
            || CHR (9)
            || 'Vendor Site Code'
            || CHR (9)
            || 'Operating Unit'
            || CHR (9)
            || 'MAX (AP/PO/PAY) TRX DATE';
        apps.fnd_file.put_line (apps.fnd_file.output, l_heading);

        --      FOR i IN c1 (l_through_date)
        --      LOOP
        --         l_line :=
        --               i.vendor_name
        --            || CHR (9)
        --            || i.vendor_number
        --            || CHR (9)
        --            || i.vendor_id
        --            || CHR (9)
        --            || i.max_ap_or_po_or_pay_trx_date;
        --         apps.fnd_file.put_line (apps.fnd_file.output, l_line);
        --      END LOOP;


        --        IF p_upd_yn = 'Y'
        --        THEN
        --         UPDATE apps.ap_suppliers pov
        --            SET pov.end_date_active = l_sysdate,
        --                pov.attribute4 =
        --                      'De-activated vendor '
        --                   || l_sysdate
        --                   || ' - Last AP or PO activity was '
        --                   || l_through_date
        --                   || ' (or prior)',
        --                last_update_date = (SELECT SYSDATE
        --                                      FROM DUAL),
        --                last_updated_by = apps.fnd_profile.VALUE ('USER_ID')
        --          WHERE 1=1
        --          AND EXISTS (
        --                   SELECT pov.vendor_id
        --                     FROM (SELECT   i.vendor_id,
        --                                    MAX (i.invoice_date) max_trx_date
        --                               FROM apps.ap_invoices_all i,
        --                                    --apps.po_vendors v
        --                                    apps.ap_suppliers v
        --                              WHERE i.vendor_id = v.vendor_id
        --                                AND v.end_date_active IS NULL -- Active vendor
        --                           GROUP BY i.vendor_id
        --                             HAVING MAX (TRUNC(i.invoice_date)) <= l_through_date
        --                           UNION
        --                           SELECT   poh.vendor_id,
        --                                    MAX (poh.creation_date) max_trx_date
        --                               FROM apps.po_headers_all poh,
        --                                    --apps.po_vendors v
        --                                    apps.ap_suppliers v
        --                              WHERE poh.vendor_id = v.vendor_id
        --                                AND v.end_date_active IS NULL -- Active vendor
        --                           GROUP BY poh.vendor_id
        --                             HAVING MAX (TRUNC(poh.creation_date)) <= l_through_date
        --                           /*added by srinath for DFCT0010961*/
        --                           UNION
        --                           SELECT   pv.vendor_id, MAX (aipa.creation_date)
        --                              FROM apps.ap_invoice_payments_all aipa,
        --                                   --apps.po_vendors pv,
        --                                   apps.ap_suppliers pv,
        --                                   apps.ap_invoices_all aia
        --                             WHERE aia.vendor_id = pv.vendor_id
        --                               AND aia.invoice_id = aipa.invoice_id
        --                               AND pv.end_date_active IS NULL
        --                          GROUP BY pv.vendor_id
        --                            HAVING MAX (TRUNC (aipa.creation_date)) <= l_through_date
        --                            /*added by srinath for DFCT0010961*/
        --                            ) old_vdr
        --                    WHERE old_vdr.vendor_id = pov.vendor_id
        --                      AND NOT EXISTS (
        --                             SELECT 1         -- Open Unpaid AP Invoice Exists
        --                               FROM apps.ap_invoices_all i
        --                              WHERE i.vendor_id = old_vdr.vendor_id
        --                                AND (     NVL (i.invoice_amount, 0)
        --                                        - NVL (i.amount_paid, 0)
        --                                        - NVL (i.discount_amount_taken, 0) <>
        --                                                                             0
        --                                     OR TRUNC(i.invoice_date) >
        --                                           l_through_date
        --                            -- added by srinath on 02-OCT-2014 for DFCT0010961
        --                                    ))
        --                      AND NOT EXISTS (
        --                             SELECT 1                   -- Open Purchase Order
        --                               FROM apps.po_headers_all poh
        --                              WHERE poh.vendor_id = old_vdr.vendor_id
        --                                AND (   NVL (poh.closed_code, 'OPEN') = 'OPEN'
        --                                     OR TRUNC(poh.creation_date) >
        --                                           l_through_date
        --                            -- added by srinath on 02-OCT-2014 for DFCT0010961
        --                                    ))
        --                        /*added by srinath for DFCT0010961*/
        --                      AND NOT EXISTS (
        --                            SELECT 1
        --                              FROM apps.ap_invoice_payments_all apsa,
        --                                   apps.ap_invoices_all aia1
        --                             WHERE aia1.invoice_id = apsa.invoice_id
        --                               AND aia1.vendor_id = old_vdr.vendor_id
        --                               AND TRUNC (apsa.creation_date) > l_through_date)
        --                               /*added by srinath for DFCT0010961*/
        --                               );
        IF p_level = 'SUPPLIER'
        THEN
            FOR supplier_rec
                IN cur_suppliers (l_through_date,
                                  p_incl_supplier_type,
                                  p_excl_supplier_type)
            LOOP
                IF p_upd_yn = 'Y'
                THEN
                    l_vendor_rec.vendor_id         := supplier_rec.vendor_id;
                    l_vendor_rec.end_date_active   := TRUNC (SYSDATE);
                    --Commneted for CCR0006586
                    --l_vendor_rec.enabled_flag := 'N';
                    --end of changes to CCR0006586
                    ap_vendor_pub_pkg.update_vendor (
                        p_api_version        => 1.0,
                        p_init_msg_list      => fnd_api.g_true,
                        p_commit             => fnd_api.g_false,
                        p_validation_level   => fnd_api.g_valid_level_full,
                        x_return_status      => l_return_status,
                        x_msg_count          => l_msg_count,
                        x_msg_data           => l_msg_data,
                        p_vendor_rec         => l_vendor_rec,
                        p_vendor_id          => supplier_rec.vendor_id);


                    IF (l_return_status <> fnd_api.g_ret_sts_success)
                    THEN
                        FOR i IN 1 .. l_msg_count
                        LOOP
                            l_msg   :=
                                fnd_msg_pub.get (
                                    p_msg_index   => i,
                                    p_encoded     => fnd_api.g_false);
                            apps.fnd_file.put_line (apps.fnd_file.LOG, l_msg);
                        END LOOP;
                    ELSE
                        l_line   :=
                               supplier_rec.vendor_name
                            || CHR (9)
                            || supplier_rec.vendor_number
                            || CHR (9)
                            || supplier_rec.vendor_type
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || supplier_rec.max_ap_or_po_or_pay_trx_date;
                        apps.fnd_file.put_line (apps.fnd_file.output, l_line);
                    END IF;
                ELSE                                         -- if report mode
                    l_line   :=
                           supplier_rec.vendor_name
                        || CHR (9)
                        || supplier_rec.vendor_number
                        || CHR (9)
                        || supplier_rec.vendor_type
                        || CHR (9)
                        || NULL
                        || CHR (9)
                        || NULL
                        || CHR (9)
                        || supplier_rec.max_ap_or_po_or_pay_trx_date;
                    apps.fnd_file.put_line (apps.fnd_file.output, l_line);
                END IF;
            END LOOP;
        ELSE
            FOR supplier_site_rec IN cur_supplier_sites (l_through_date, p_incl_supplier_type, p_excl_supplier_type
                                                         , p_operating_unit)
            LOOP
                IF p_upd_yn = 'Y'
                THEN
                    l_vendor_site_rec.vendor_id       :=
                        supplier_site_rec.vendor_id;
                    l_vendor_site_rec.vendor_site_id   :=
                        supplier_site_rec.vendor_site_id;
                    l_vendor_site_rec.inactive_date   := TRUNC (SYSDATE);
                    l_vendor_site_rec.org_id          :=
                        supplier_site_rec.org_id;

                    ap_vendor_pub_pkg.Update_Vendor_Site (
                        p_api_version        => 1.0,
                        p_init_msg_list      => FND_API.G_TRUE,
                        p_commit             => FND_API.G_FALSE,
                        p_validation_level   => FND_API.G_VALID_LEVEL_FULL,
                        x_return_status      => l_return_status,
                        x_msg_count          => l_msg_count,
                        x_msg_data           => l_msg_data,
                        p_vendor_site_rec    => l_vendor_site_rec,
                        p_vendor_site_id     =>
                            supplier_site_rec.vendor_site_id);

                    IF (l_return_status <> fnd_api.g_ret_sts_success)
                    THEN
                        FOR i IN 1 .. l_msg_count
                        LOOP
                            l_msg   :=
                                fnd_msg_pub.get (
                                    p_msg_index   => i,
                                    p_encoded     => fnd_api.g_false);
                            apps.fnd_file.put_line (apps.fnd_file.LOG, l_msg);
                        END LOOP;
                    ELSE
                        l_line   :=
                               supplier_site_rec.vendor_name
                            || CHR (9)
                            || supplier_site_rec.vendor_number
                            || CHR (9)
                            || supplier_site_rec.vendor_type
                            || CHR (9)
                            || supplier_site_rec.vendor_site_code
                            || CHR (9)
                            || supplier_site_rec.operating_unit
                            || CHR (9)
                            || supplier_site_rec.max_ap_or_po_or_pay_trx_date;
                        apps.fnd_file.put_line (apps.fnd_file.output, l_line);
                    END IF;
                ELSE                                         -- if report mode
                    l_line   :=
                           supplier_site_rec.vendor_name
                        || CHR (9)
                        || supplier_site_rec.vendor_number
                        || CHR (9)
                        || supplier_site_rec.vendor_type
                        || CHR (9)
                        || supplier_site_rec.vendor_site_code
                        || CHR (9)
                        || supplier_site_rec.operating_unit
                        || CHR (9)
                        || supplier_site_rec.max_ap_or_po_or_pay_trx_date;
                    apps.fnd_file.put_line (apps.fnd_file.output, l_line);
                END IF;
            END LOOP;
        END IF;

        --      END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := 'Unhandled Error' || SQLCODE || SQLERRM;
            retcode   := -5;
            -- DBMS_OUTPUT.PUT_LINE('OTHERS' || SQLERRM);
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'Program Terminated Abruptly');
            apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'All Data is Not Processed');
            apps.fnd_file.put_line (apps.fnd_file.LOG, errbuf);
            ROLLBACK;
    END run_active_vendors;
END xxdo_ap_report_util;
/
