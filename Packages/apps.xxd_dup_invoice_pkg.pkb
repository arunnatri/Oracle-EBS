--
-- XXD_DUP_INVOICE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_DUP_INVOICE_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_DUP_INVOICE_PKG
    * Author       : BT Technology Team
    * Created      : 09-SEP-2014
    * Program Name : Deckers Fixed Asset Retire - Web ADI
    * Description  : Package used by custom Web ADIs
    *                     1) Mass Asset Adjustments (Retirements)
    *
    * Modification :
    *--------------------------------------------------------------------------------------
    * Date          Developer           Version    Description
    *--------------------------------------------------------------------------------------
    * 09-SEP-2014   BT Technology Team  1.0       Created package body script for FA Retire
    * 25-NOV-2014   BT Technology Team  1.1       Modified email body for CRP3
    ****************************************************************************************/
    PROCEDURE print_log_prc (p_msg IN VARCHAR2)
    IS
    BEGIN
        IF p_msg IS NOT NULL
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;

        RETURN;
    END print_log_prc;

    FUNCTION get_new_org_name (p_old_org_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lc_attribute1    VARCHAR2 (1000) := NULL;
        lc_attribute2    VARCHAR2 (1000);
        lc_error_code    VARCHAR2 (1000);
        lc_error_msg     VARCHAR2 (1000);
        xc_meaning       VARCHAR2 (1000);
        xc_description   VARCHAR2 (1000);
        xc_lookup_code   VARCHAR2 (1000);
    BEGIN
        xc_lookup_code   := p_old_org_id;

        xxd_common_utils.get_mapping_value (
            p_lookup_type    => 'XXD_1206_OU_MAPPING',
            px_lookup_code   => xc_lookup_code,
            px_meaning       => xc_meaning,
            px_description   => xc_description,
            x_attribute1     => lc_attribute1,
            x_attribute2     => lc_attribute2,
            x_error_code     => lc_error_code,
            x_error_msg      => lc_error_msg);

        print_log_prc ('New Org Name :' || lc_attribute1);
        RETURN lc_attribute1;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_new_org_name;

    PROCEDURE populate_paid_invoices (x_retcode OUT NUMBER, x_errbuff OUT VARCHAR2, p_date_from IN DATE)
    IS
        /****************************************************************************************
        * Procedure : populate_paid_invoices
        * Design    : Mass Asset Adjustments (Retirements)
        * Notes     :
        * Return Values: None
        * Modification :
        * Date          Developer                  Version    Description
        *--------------------------------------------------------------------------------------
        * 07-JUL-2014   BT Technology Team         1.0        Created
        ****************************************************************************************/
        l_org_name                 VARCHAR2 (240 BYTE) := NULL;
        ld_date                    DATE := SYSDATE;
        ln_org_id_curr             NUMBER;
        ln_org_id_new              NUMBER;
        ln_first                   NUMBER := 0;
        ln_commit_count            NUMBER := 0;
        ln_total_count             NUMBER := 0;
        ln_line_num                NUMBER := 0;
        le_org_mapping_not_found   EXCEPTION;

        /* Cursor to fetch paid/closed invoices */
        CURSOR fetch_paid_invoices_cur IS
              SELECT xapi.org_id, -- hou.name org_name,
                                  xapi.vendor_id, aps.vendor_name supplier_name,
                     aps.segment1 supplier_number, apss.vendor_site_code site_name, xapi.vendor_site_id,
                     xapi.invoice_num, xapi.invoice_date, xapi.invoice_currency_code,
                     xapi.invoice_amount
                FROM apps.ap_invoices_all@bt_read_1206 xapi, apps.ap_suppliers@bt_read_1206 aps, apps.ap_supplier_sites_all@bt_read_1206 apss
               --,hr_operating_units@bt_read_1206 hou
               WHERE     xapi.vendor_id = aps.vendor_id
                     AND aps.vendor_id = apss.vendor_id
                     AND xapi.vendor_id = apss.vendor_id
                     AND xapi.vendor_site_id = apss.vendor_site_id
                     --AND xapi.org_id = hou.organization_id
                     AND xapi.invoice_amount =
                         xapi.amount_paid + NVL (xapi.discount_amount_taken, 0)
                     AND TRUNC (xapi.creation_date) >= TRUNC (p_date_from)
                     AND NOT EXISTS
                             (SELECT 1
                                FROM ap_invoices_all aia_1223, ap_suppliers aps_1223, ap_supplier_sites_all apss_1223,
                                     hr_operating_units hou_1223, fnd_lookup_values_vl flv
                               WHERE     aia_1223.vendor_id =
                                         aps_1223.vendor_id
                                     AND aia_1223.vendor_site_id =
                                         apss_1223.vendor_site_id
                                     AND aps_1223.vendor_id =
                                         apss_1223.vendor_id
                                     AND aia_1223.org_id =
                                         hou_1223.organization_id
                                     AND flv.lookup_type =
                                         'XXD_1206_OU_MAPPING'
                                     AND flv.lookup_code =
                                         TO_CHAR (xapi.org_id)
                                     AND hou_1223.name = flv.attribute1
                                     AND aps_1223.segment1 = aps.segment1
                                     AND apss_1223.vendor_site_code =
                                         apss.vendor_site_code
                                     AND aia_1223.invoice_num =
                                         xapi.invoice_num)
            ORDER BY xapi.org_id;
    BEGIN
        print_log_prc ('Begin populate_paid_invoices');

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_1206_paid_ap_invoices_t';

        FOR fetch_paid_invoices_rec IN fetch_paid_invoices_cur
        LOOP
            ln_org_id_curr    := fetch_paid_invoices_rec.org_id;

            IF ln_first = 0
            THEN
                ln_first        := 1;
                ln_org_id_new   := fetch_paid_invoices_rec.org_id;
                l_org_name      := get_new_org_name (ln_org_id_curr);
            END IF;

            IF (ln_org_id_curr <> ln_org_id_new)
            THEN
                ln_org_id_new   := ln_org_id_curr;
                l_org_name      := get_new_org_name (ln_org_id_curr);
            ELSE
                ln_org_id_new   := ln_org_id_curr;
            END IF;

            BEGIN
                ln_line_num      := ln_line_num + 1;

                IF l_org_name IS NULL
                THEN
                    print_log_prc (
                           'OU Mapping not found for Org Id: '
                        || fetch_paid_invoices_rec.org_id);
                --RAISE le_org_mapping_not_found;
                END IF;

                --Insert 1206 Paid AP invoices into Table XXD_1206_PAID_AP_INVOICES_T
                INSERT INTO xxd_1206_paid_ap_invoices_t (operating_unit_name, supplier_name, supplier_number, site_name, invoice_number, invoice_date, invoice_currency, invoice_amount, creation_date, created_by, last_update_date, last_updated_by
                                                         , last_update_login)
                     VALUES (l_org_name, fetch_paid_invoices_rec.supplier_name, fetch_paid_invoices_rec.supplier_number, fetch_paid_invoices_rec.site_name, fetch_paid_invoices_rec.invoice_num, fetch_paid_invoices_rec.invoice_date, fetch_paid_invoices_rec.invoice_currency_code, fetch_paid_invoices_rec.invoice_amount, ld_date, fnd_global.user_id, ld_date, fnd_global.user_id
                             , fnd_global.login_id);

                ln_total_count   := ln_total_count + 1;
            EXCEPTION
                WHEN le_org_mapping_not_found
                THEN
                    print_log_prc (
                           'OU Mapping not found for Org Id: '
                        || fetch_paid_invoices_rec.org_id);
                WHEN OTHERS
                THEN
                    print_log_prc (
                           'For Invoice#: '
                        || fetch_paid_invoices_rec.invoice_num
                        || ' @line '
                        || ln_line_num
                        || ' error is: '
                        || SQLERRM);
            END;

            ln_commit_count   := ln_commit_count + 1;

            IF ln_commit_count = 10000
            THEN
                ln_commit_count   := 0;
                COMMIT;
            END IF;
        END LOOP;

        COMMIT;
        print_log_prc ('Total# of records inserted: ' || ln_total_count);
        print_log_prc ('End populate_paid_invoices');
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log_prc ('Error: ' || SQLERRM);
    END populate_paid_invoices;
END;
/
